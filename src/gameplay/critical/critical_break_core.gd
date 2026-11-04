class_name CriticalBreakCore
extends RefCounted
## The Critical Break: hold your charge on a wounded boss, then bomb it.
## Implements design/gdd/critical-break.md. Step 6b of the ADR-0002 tick.
##
## This is the game highest-value play and the reason the bomb is not only a
## panic button. Charge the core until it is Critical, press Bomb, and the
## chain is multiplied instead of halved: the toll is waived and the count is
## worth `cb_mult x count + cb_add`.
##
## It owns `consumed` and the per-slot commit, and nothing else. The chain
## multiply, the score, the cancel and the kill all belong to other systems,
## which is what keeps one break from paying twice.
##
## Scope deviation, stated plainly: Boss and boss parts (GDD 14) are not
## built, so "the core" is the stage boss enemy and Critical is "hp at or
## below `critical_hp_pct`" rather than "the main pool is destroyed". And
## without per-bullet tags a drone bullet landing while the plane is charging
## counts as a charge hit, where the GDD wants only tag 2 and 3. Both are
## noted in production/session-state and neither changes the payout.
##
## Usage:
## [codeblock]
## var cb := CriticalBreakCore.new(rules, chain_rules, log)
## cb.on_break = func(slot, raw): ...
##
## # while hits resolve
## cb.note_charge_hit(slot, enemy_id, tick)
## cb.note_bomb_landed(slot, enemy_id, tick)
##
## # step 6b
## cb.tick(tick, planes, kits, core_id, core_is_critical)
## [/codeblock]

const MAX_SLOTS := 4

## Rule 29's per-slot feedback for the HUD.
enum Cue { OFF, CRITICAL, ARMED, COMMITTED, DONE }

var rules: CriticalBreakRules
var chain_rules: ChainRules
## `func(slot: int, raw_before: int) -> void` — a break landed. The host does
## the multiply, the score, the cancel and the kill, in that order (Rule 14).
var on_break: Callable

## Rule 4: one break per boss. Cleared when the next boss spawns.
var consumed := false
var breaks_this_run := 0
## Rule 19: a bomb that reached the core without the charge. Counted so a
## playtest can tell "it did not work" from "I did it wrong".
var misses_no_charge := 0

var _log: TickEventLog
## Ticks the current (or most recent) charge run lasted.
var _run_len := PackedInt32Array()
var _last_charge_tick := PackedInt32Array()
## Which enemy id this slot last hit with its charge, and when.
var _hit_id := PackedInt32Array()
var _hit_tick := PackedInt32Array()
## This tick's bomb landing on the core, per slot: the tick it happened.
var _bomb_tick := PackedInt32Array()
var _committed := PackedInt32Array()
var _cue := PackedInt32Array()
## The boss instance the `consumed` flag belongs to.
var _core_generation := 0
var _was_critical := false
var critical_left := 0


func _init(
	p_rules: CriticalBreakRules, p_chain_rules: ChainRules, p_log: TickEventLog
) -> void:
	assert(p_rules != null, "CriticalBreakCore needs a CriticalBreakRules")
	assert(p_chain_rules != null, "CriticalBreakCore needs the ChainRules (cb_mult, cb_add)")
	rules = p_rules
	chain_rules = p_chain_rules
	_log = p_log
	_run_len.resize(MAX_SLOTS)
	_last_charge_tick.resize(MAX_SLOTS)
	_last_charge_tick.fill(-9999)
	_hit_id.resize(MAX_SLOTS)
	_hit_id.fill(-1)
	_hit_tick.resize(MAX_SLOTS)
	_hit_tick.fill(-9999)
	_bomb_tick.resize(MAX_SLOTS)
	_bomb_tick.fill(-9999)
	_committed.resize(MAX_SLOTS)
	_cue.resize(MAX_SLOTS)


## Rule 8: a counted charge hit. The host calls this as hits resolve, so the
## break knows the charge was actually on the core and not on a escort.
func note_charge_hit(slot: int, enemy_id: int, t: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	_hit_id[slot] = enemy_id
	_hit_tick[slot] = t


## Rule 11: this slot bomb reached the core on tick `t`.
func note_bomb_landed(slot: int, enemy_id: int, t: int, core_id: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS or enemy_id != core_id:
		return
	_bomb_tick[slot] = t


## Rule 10: the bomb was accepted this tick. A committed bomb no longer needs
## the charge, which is what lets a player let go of Fire and still break.
func note_bomb_started(slot: int, t: int, core_alive: bool, core_critical: bool) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	if core_alive and core_critical and not consumed and _charge_ok(slot, t) and _hit_ok(slot, t, -1):
		_committed[slot] = 1


## A new boss is on the field: the break is available again (Rule 4).
func on_core_spawned() -> void:
	consumed = false
	_core_generation += 1
	_was_critical = false
	critical_left = 0
	for s: int in range(MAX_SLOTS):
		_committed[s] = 0
		_cue[s] = Cue.OFF


## Rule 9's pure query, which the bomb reads to decide whether to waive the
## toll. No side effects: asking never changes anything.
func is_armed(slot: int, t: int, core_id: int, core_critical: bool, active: bool) -> bool:
	if consumed or not core_critical or not active:
		return false
	return _charge_ok(slot, t) and _hit_ok(slot, t, core_id)


## One tick, at step 6b: after collision has resolved, before the chain
## applies this tick hits — so the multiply works on the count as it was at
## the start of the tick (Rule 1).
func tick(
	t: int,
	planes: PlaneCore,
	kits: PlaneKits,
	core_id: int,
	core_critical: bool,
	chain: ChainCore
) -> void:
	# Rule 6: the charge run, per slot.
	for slot: int in range(MAX_SLOTS):
		if kits != null and kits.is_charging(slot):
			_run_len[slot] = kits.charge_ticks(slot)
			_last_charge_tick[slot] = t

	if core_critical and not _was_critical:
		critical_left = rules.critical_ticks
		if _log != null:
			_log.append(TickEventLog.Kind.BOSS_CRITICAL, -1, core_id)
	_was_critical = core_critical
	if critical_left > 0:
		critical_left -= 1

	# Rule 13: when two slots qualify on one tick, the rotating rank decides,
	# so no slot is favoured over a run.
	var winner := -1
	for r: int in range(MAX_SLOTS):
		var slot := (r + (t % MAX_SLOTS)) % MAX_SLOTS
		if _bomb_tick[slot] != t:
			continue
		if consumed or not core_critical or not planes.is_active(slot) or chain.is_frozen():
			continue
		var qualifies := (
			_committed[slot] != 0
			or (_charge_ok(slot, t) and _hit_ok(slot, t, core_id))
		)
		if not qualifies:
			# Rule 19: the bomb hit the core and did its damage, but there was
			# no charge behind it. The toll was paid in full.
			misses_no_charge += 1
			continue
		winner = slot
		break

	for slot: int in range(MAX_SLOTS):
		_bomb_tick[slot] = -9999
		if not planes.is_active(slot):
			_committed[slot] = 0

	if winner >= 0:
		_fire(winner, core_id)
	else:
		_publish_cues(t, planes, core_id, core_critical)


## Rule 14: one atomic sequence. The flag is set here and everything it pays
## for belongs to another system, which the host callback runs in order: the
## chain multiply, the score, the whole-screen cancel, then the kill.
func _fire(slot: int, core_id: int) -> void:
	consumed = true
	breaks_this_run += 1
	for s: int in range(MAX_SLOTS):
		_committed[s] = 0
		_cue[s] = Cue.DONE
	if on_break.is_valid():
		on_break.call(slot, core_id)


func _publish_cues(t: int, planes: PlaneCore, core_id: int, core_critical: bool) -> void:
	for slot: int in range(MAX_SLOTS):
		if consumed:
			_cue[slot] = Cue.DONE
		elif not core_critical:
			_cue[slot] = Cue.OFF
		elif _committed[slot] != 0:
			_cue[slot] = Cue.COMMITTED
		elif is_armed(slot, t, core_id, core_critical, planes.is_active(slot)):
			_cue[slot] = Cue.ARMED
		else:
			_cue[slot] = Cue.CRITICAL


## Rule 7: charging now with a long enough run, or charging recently enough.
func _charge_ok(slot: int, t: int) -> bool:
	if _run_len[slot] < rules.charge_min_ticks:
		return false
	return t - _last_charge_tick[slot] <= rules.charge_lenience


## Rule 8: the charge has to be ON THE CORE, not on an escort. `core_id` of -1
## accepts any recent charge hit, which is what the commit check wants when
## the host has not resolved this tick core index yet.
func _hit_ok(slot: int, t: int, core_id: int) -> bool:
	if t - _hit_tick[slot] > rules.hit_window:
		return false
	return core_id < 0 or _hit_id[slot] == core_id


func cue_of(slot: int) -> int:
	return _cue[slot]


func is_committed(slot: int) -> bool:
	return _committed[slot] != 0


## What a break would pay right now, for the HUD preview.
func preview_raw(count_before: int) -> int:
	return count_before * chain_rules.cb_mult + chain_rules.cb_add


func state_hash() -> int:
	var h := 1469598103934665603
	h = (h ^ (1 if consumed else 0)) * 1099511628211
	h = (h ^ breaks_this_run) * 1099511628211
	h = (h ^ critical_left) * 1099511628211
	for s: int in range(MAX_SLOTS):
		h = (h ^ _committed[s]) * 1099511628211
		h = (h ^ _run_len[s]) * 1099511628211
	return h
