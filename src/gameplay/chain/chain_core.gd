class_name ChainCore
extends RefCounted
## The chain, for all four co-op slots. Node-free, integer ticks.
## Implements design/gdd/chain-tracker.md. Runs at step 8a of ADR-0002's tick.
##
## The chain is the game's central mechanic: hits raise a per-slot counter that
## expires a fixed window after the last counted hit and resets to **zero** —
## there is no decay, it is a pure reset (GDD Rule 5).
##
## Deliberately separate from the legacy `ChainTracker`, which works in float
## seconds and belongs to the old prototype path. This one is tick-exact so a
## run can be replayed (ADR-0003).
##
## Usage:
## [codeblock]
## var chain := ChainCore.new(load("res://data/chain_rules.tres"), event_log)
##
## # step 6 produced hits; the chain consumes them at step 8a
## chain.add_hit(slot, true)              # a hit on the boss
## chain.drop(slot)                       # the slot died
##
## # the Critical Break multiplies it, and returns the UNCAPPED raw value
## # because Scoring F4 pays on that, not on the capped count
## var raw := chain.apply_critical_break(slot)
##
## # end of step 8a
## chain.tick(active_flags, boss_alive)
## [/codeblock]

const MAX_SLOTS := 4

var rules: ChainRules
var _log: TickEventLog

var _count := PackedInt32Array()
var _window_left := PackedInt32Array()
## Set by a hit, bonus or CB this tick; cleared at the end of tick (F2).
var _fresh := PackedInt32Array()
## Frozen chains neither tick down nor drop — used from the stage-end tally.
var _frozen := PackedInt32Array()
## Ticks left for this slot's membership of the team chain (F3).
var _boss_hit_left := PackedInt32Array()
## Peak count reached while the current boss was alive (Rules 8-10).
var _boss_peak := PackedInt32Array()

var _team_chain := false


func _init(p_rules: ChainRules, p_log: TickEventLog) -> void:
	assert(p_rules != null, "ChainCore needs a ChainRules (data/chain_rules.tres)")
	rules = p_rules
	_log = p_log
	_count.resize(MAX_SLOTS)
	_window_left.resize(MAX_SLOTS)
	_fresh.resize(MAX_SLOTS)
	_frozen.resize(MAX_SLOTS)
	_boss_hit_left.resize(MAX_SLOTS)
	_boss_peak.resize(MAX_SLOTS)


## One counted hit. `on_boss` marks it as landing on the boss, which both feeds
## the boss record and refreshes this slot's team-chain membership.
## `active_count` is the number of Active slots at this tick, for F3's window.
func add_hit(slot: int, on_boss: bool = false, active_count: int = 1) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	var before := _count[slot]
	_set_count(slot, mini(rules.chain_cap, before + 1), before)
	_fresh[slot] = 1
	_log.append(TickEventLog.Kind.CHAIN_HIT, slot, _count[slot])
	if on_boss:
		var a := clampi(active_count, 2, 4)
		_boss_hit_left[slot] = rules.team_window + rules.team_window_step * (a - 2)
		if _count[slot] > _boss_peak[slot]:
			_boss_peak[slot] = _count[slot]


## A flat chain bonus, e.g. part_kill_chain from a boss-part kill. Counts as a
## fresh event, so it also saves an expiring chain (F2).
func add_bonus(slot: int, amount: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS or amount == 0:
		return
	var before := _count[slot]
	_set_count(slot, mini(rules.chain_cap, before + amount), before)
	_fresh[slot] = 1


## F4. Multiplies the chain and returns the **uncapped** raw value, because
## Scoring F4 pays `cb_unit x raw` while the chain itself still caps at 999.
func apply_critical_break(slot: int) -> int:
	if slot < 0 or slot >= MAX_SLOTS:
		return 0
	var before := _count[slot]
	var raw := before * rules.cb_mult + rules.cb_add
	_set_count(slot, mini(rules.chain_cap, raw), before)
	_fresh[slot] = 1
	_log.append(TickEventLog.Kind.CRITICAL_BREAK_LANDED, slot, raw)
	return raw


## Pure reset to zero (Rule 5). Used when the slot dies or the run ends.
## Bombs Rule 12 / chain F4: a bomb REDUCES the chain, it does not drop it.
## The window is untouched and no `chain_dropped` is sent, because the player
## did not lose the chain — they spent it.
func apply_bomb_toll(slot: int, toll_pct: int) -> void:
	if toll_pct <= 0 or is_frozen():
		return
	var before := count_of(slot)
	if before <= 0:
		return
	var after := before - (before * toll_pct) / 100
	_set_count(slot, after, before)
	_log.append(TickEventLog.Kind.CHAIN_REDUCED, slot, after)


func drop(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	if _count[slot] == 0:
		return
	_log.append(TickEventLog.Kind.CHAIN_DROPPED, slot, _count[slot])
	_count[slot] = 0
	_window_left[slot] = 0
	_boss_hit_left[slot] = 0


## F2: window tick-down and expiry, then F3's team-chain test.
## `active_flags` is 1 per Active slot; `boss_alive` gates the team chain.
func tick(active_flags: PackedInt32Array, boss_alive: bool = false) -> void:
	for s: int in range(MAX_SLOTS):
		if _boss_hit_left[s] > 0 and _fresh[s] == 0:
			_boss_hit_left[s] -= 1

		if _frozen[s] == 1:
			_fresh[s] = 0
			continue

		if _fresh[s] == 1:
			# A hit, bonus or CB this tick refills the window.
			_window_left[s] = rules.chain_window
		elif _count[s] > 0:
			_window_left[s] -= 1
			if _window_left[s] <= 0:
				_log.append(TickEventLog.Kind.CHAIN_EXPIRED, s, _count[s])
				_count[s] = 0
				_window_left[s] = 0
		_fresh[s] = 0

	_team_chain = _compute_team_chain(active_flags, boss_alive)


## F3. A team chain needs the boss alive, at least two members, and EVERY
## Active slot to be a member — one idle co-op player breaks it.
func _compute_team_chain(active_flags: PackedInt32Array, boss_alive: bool) -> bool:
	if not boss_alive:
		return false
	var members := 0
	var active := 0
	for s: int in range(MAX_SLOTS):
		if s >= active_flags.size() or active_flags[s] == 0:
			continue
		active += 1
		if _boss_hit_left[s] > 0:
			members += 1
	return members >= 2 and members == active


## Freezes every chain: it stops ticking down and cannot expire. The stage-end
## tally freezes, records, then drops (GDD Rule 9).
func set_frozen(value: bool) -> void:
	var flag := 1 if value else 0
	for s: int in range(MAX_SLOTS):
		_frozen[s] = flag


## Clears the boss record, at the start of a boss fight.
func reset_boss_record() -> void:
	for s: int in range(MAX_SLOTS):
		_boss_peak[s] = 0
		_boss_hit_left[s] = 0


func _set_count(slot: int, after: int, before: int) -> void:
	_count[slot] = after
	if after > _boss_peak[slot] and _boss_hit_left[slot] > 0:
		_boss_peak[slot] = after
	_emit_milestones(slot, before, after)


## F5. Fires for every threshold crossed by one change, ascending.
func _emit_milestones(slot: int, before: int, after: int) -> void:
	if after <= before:
		return
	for i: int in range(rules.milestones.size()):
		var m := rules.milestones[i]
		if before < m and m <= after:
			_log.append(TickEventLog.Kind.CHAIN_HIT, slot, m)


# --- reads -------------------------------------------------------------------

func count_of(slot: int) -> int:
	return _count[slot]


func window_left_of(slot: int) -> int:
	return _window_left[slot]


func boss_peak_of(slot: int) -> int:
	return _boss_peak[slot]


func is_team_chain() -> bool:
	return _team_chain


func is_frozen() -> bool:
	return _frozen[0] == 1


func is_at_cap(slot: int) -> bool:
	return _count[slot] >= rules.chain_cap


## F6. Fraction of the window left, for the HUD bar. 0 when the chain is dead.
func window_ratio_of(slot: int) -> float:
	if _count[slot] <= 0:
		return 0.0
	return float(_window_left[slot]) / float(rules.chain_window)


## F6. True in the last 25% of the window — the bar's red end-cap.
func is_in_red_zone(slot: int) -> bool:
	return _count[slot] > 0 and _window_left[slot] * 4 <= rules.chain_window


func state_hash() -> int:
	var h := 1469598103934665603
	for s: int in range(MAX_SLOTS):
		h = (h ^ _count[s]) * 1099511628211
		h = (h ^ _window_left[s]) * 1099511628211
		h = (h ^ _boss_hit_left[s]) * 1099511628211
		h = (h ^ _boss_peak[s]) * 1099511628211
	return h
