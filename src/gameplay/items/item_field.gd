class_name ItemField
extends RefCounted
## Every item in the play field: drone pods, chain pickups, medals, 1-ups and
## the gems a cancelled bullet leaves behind.
## Implements design/gdd/powerups-and-drops.md. Step 7b of the ADR-0002 tick.
##
## Node-free packed arrays, integer ticks, one seeded drop stream per stage
## (ADR-0001 Decision 7, ADR-0003). The only randomness is the drop roll, and
## it consumes exactly four draws per carrier whatever it decides (Rule 9), so
## content never depends on how many draws something else used.
##
## It owns no other system's state. What a pickup does is sent out through the
## four callbacks, and Session, Chain and Scoring decide what it costs.
##
## Usage:
## [codeblock]
## var items := ItemField.new(rules, scoring_rules, run_seed, stage_index, log)
## items.on_pod = func(slot): kits.set_drone_count(slot, kits.drone_count(slot) + 1)
## items.on_oneup = func(slot): return planes.add_life(slot)
## items.on_chain_bonus = func(slot, amount): chain.add_bonus(slot, amount)
## items.on_score = func(slot, base): scoring.award_item(slot, base, chain.count_of(slot))
##
## # a carrier died
## items.drop_requested(pos, killer_slot, EnemyDef.SizeClass.SMALL, -1, n, needy, lives)
## # the bullet field cancelled with items
## items.make_gems(field.cancel_positions, field.cancel_causes)
## # step 7b
## items.tick(planes, drone_counts)
## [/codeblock]

## Rule 1's five kinds. Only these.
enum Kind { POD, CHAIN, MEDAL, ONEUP, GEM }
## Where an item is in its life.
enum State { POP, FALL, REST, HOLD, FLY, DRIFT, SWEEP }

var rules: ItemRules
var scoring_rules: ScoringRules

## func(slot: int) -> void — the plane gains one drone (max_drones applies).
var on_pod: Callable
## func(slot: int) -> bool — the plane gains a life. False means it was full,
## and the 1-up pays a medal instead (Rule 22).
var on_oneup: Callable
## func(slot: int, amount: int) -> void — a chain pickup.
var on_chain_bonus: Callable
## func(slot: int, item_base: int) -> void — a gem or medal was collected.
var on_score: Callable

## Rule 7's team counter. A death sets it to pity_limit, so the next
## SMALL/MEDIUM item is the recovery pod.
var pity_misses := 0
## drop_requested calls this stage, for the fixed 1-up schedule (Rule 11).
var carriers_this_stage := 0

var collected_total := 0
var expired_total := 0
var gems_discarded := 0

var _log: TickEventLog
var _rng: RandomNumberGenerator

var _kind := PackedInt32Array()
var _state := PackedInt32Array()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
## The x a drop item bobs around.
var _x0 := PackedFloat32Array()
var _age := PackedInt32Array()
## Ticks since this gem started flying, for F4's ramp.
var _fly := PackedInt32Array()
## The slot that caused a gem, which it flies to while that slot is Active.
var _cause := PackedInt32Array()
var _n := 0

var _gems := 0
var _drops := 0
var _sweeping := false


func _init(
	p_rules: ItemRules,
	p_scoring: ScoringRules,
	run_seed: int,
	stage_index: int,
	p_log: TickEventLog
) -> void:
	assert(p_rules != null, "ItemField needs an ItemRules (data/item_rules.tres)")
	assert(p_scoring != null, "ItemField needs the ScoringRules for the item bases")
	rules = p_rules
	scoring_rules = p_scoring
	_log = p_log
	# Rule 10: one stream per stage, so the same run always drops the same
	# things in the same order.
	_rng = SimRng.make(&"drops", [run_seed, stage_index])
	var cap := rules.gem_cap + rules.drop_cap
	_kind.resize(cap)
	_state.resize(cap)
	_x.resize(cap)
	_y.resize(cap)
	_x0.resize(cap)
	_age.resize(cap)
	_fly.resize(cap)
	_cause.resize(cap)


# --- Rules 3-11: carrier drops ------------------------------------------------

## A carrier was destroyed. `needy` is how many slots could still use a pod
## (Rule 8) and `lives_full` is true when no slot can take a 1-up (Rule 11).
##
## Always consumes exactly four draws from the stage stream, whatever it
## decides to drop (Rule 9).
func drop_requested(
	at: Vector2,
	_killer_slot: int,
	size_class: int,
	drop_override: int,
	player_count: int,
	needy: int,
	lives_full: bool
) -> void:
	carriers_this_stage += 1
	var n := clampi(player_count, 1, 4)
	var kinds := PackedInt32Array()

	if drop_override >= 0:
		# Rule 7a: a drill says exactly what drops, and the pity counter does
		# not move. The rolls are still drawn, so the stream stays in step.
		_burn_rolls()
		for _i: int in range(n):
			kinds.append(drop_override)
	elif size_class == EnemyDef.SizeClass.LARGE:
		# Rule 6: a LARGE carrier is a fixed, guaranteed bundle.
		_burn_rolls()
		for _i: int in range(n):
			kinds.append(Kind.POD)
		kinds.append(Kind.MEDAL)
	else:
		var small := size_class == EnemyDef.SizeClass.SMALL
		var pod_pct := rules.small_pod_pct if small else rules.medium_pod_pct
		var chain_pct := rules.small_chain_pct if small else rules.medium_chain_pct
		for i: int in range(4):
			var r := _rng.randi_range(0, 99)
			if i >= n:
				continue
			kinds.append(_roll_kind(r, pod_pct, chain_pct))

	# Rule 8: the need check runs over the whole drop, so a pod never appears
	# when nobody on the team could use it.
	var pods_allowed := maxi(0, needy)
	for i: int in range(kinds.size()):
		if kinds[i] != Kind.POD:
			continue
		if pods_allowed > 0:
			pods_allowed -= 1
		else:
			kinds[i] = Kind.MEDAL

	# Rule 11: the fixed 1-up schedule, not a random roll.
	if _oneup_due(n):
		kinds.append(Kind.MEDAL if lives_full else Kind.ONEUP)

	var m := kinds.size()
	for i: int in range(m):
		var offset := (2.0 * float(i) - float(m - 1)) * rules.row_spacing
		_add_drop(kinds[i], at.x + offset, at.y)


## Rule 9: four draws per request, always.
func _burn_rolls() -> void:
	for _i: int in range(4):
		_rng.randi_range(0, 99)


## F1: the table roll, with the pity override applied first.
func _roll_kind(r: int, pod_pct: int, chain_pct: int) -> int:
	var kind := Kind.MEDAL
	if pity_misses >= rules.pity_limit:
		kind = Kind.POD
	elif r < pod_pct:
		kind = Kind.POD
	elif r < pod_pct + chain_pct:
		kind = Kind.CHAIN
	# The counter follows the ROLL, before the need check downgrades it, so a
	# team already at four drones does not bank pity it cannot spend.
	pity_misses = 0 if kind == Kind.POD else pity_misses + 1
	return kind


func _oneup_due(n: int) -> bool:
	if rules.oneup_carrier_nth > 0 and carriers_this_stage == rules.oneup_carrier_nth:
		return true
	return n >= 3 and rules.oneup_second_nth > 0 and carriers_this_stage == rules.oneup_second_nth


## Rule 7: any death arms the recovery pod.
func player_died() -> void:
	pity_misses = rules.pity_limit


func _add_drop(kind: int, at_x: float, at_y: float) -> int:
	if _drops >= rules.drop_cap or _n >= _kind.size():
		return -1
	var i := _n
	_n += 1
	_drops += 1
	_kind[i] = kind
	_state[i] = State.POP
	_x[i] = clampf(at_x, rules.drop_inset, 360.0 - rules.drop_inset)
	_y[i] = at_y
	_x0[i] = _x[i]
	_age[i] = 0
	_fly[i] = 0
	_cause[i] = -1
	_log.append(TickEventLog.Kind.ITEM_DROPPED, -1, kind)
	return i


# --- Rules 12-14: gems from cancelled bullets --------------------------------

## Turns this tick's cancelled bullets into gems. `positions` is x, y pairs in
## pool order and `causes` is the slot behind each one, exactly as the bullet
## field reports them.
##
## F3's stride sampling keeps at most `items_per_cancel_cap` of them, spread
## evenly over the cancel area rather than clustered at the low indices.
func make_gems(positions: PackedFloat32Array, causes: PackedInt32Array) -> void:
	var total := causes.size()
	if total == 0:
		return
	var cap := maxi(1, rules.items_per_cancel_cap)
	var stride := (total + cap - 1) / cap
	for k: int in range(total):
		if k % stride != 0:
			continue
		if _gems >= rules.gem_cap or _n >= _kind.size():
			gems_discarded += 1
			continue
		var i := _n
		_n += 1
		_gems += 1
		_kind[i] = Kind.GEM
		_state[i] = State.HOLD
		_x[i] = positions[k * 2]
		_y[i] = positions[k * 2 + 1]
		_x0[i] = _x[i]
		_age[i] = 0
		_fly[i] = 0
		_cause[i] = causes[k]


# --- Rules 15-23: motion and pickup ------------------------------------------

## Rule 18: the boss is down, so everything still out flies in and is paid.
func begin_sweep() -> void:
	_sweeping = true
	for i: int in range(_n):
		_state[i] = State.SWEEP


## Stage start, stage clear and run reset: the field empties, paying nothing.
func clear_all() -> void:
	_n = 0
	_gems = 0
	_drops = 0
	_sweeping = false


func reset_stage() -> void:
	clear_all()
	pity_misses = 0
	carriers_this_stage = 0


## One tick, in the GDD's order (Rule 23): move, then test pickup. A plane
## that died earlier this tick is no longer Active and collects nothing.
##
## `drone_counts` is one entry per slot, so the pod eligibility of Rule 20 is
## decided without this system reaching into the kits.
func tick(planes: PlaneCore, drone_counts: PackedInt32Array) -> void:
	var i := 0
	while i < _n:
		_age[i] += 1
		if _state[i] == State.SWEEP:
			_step_sweep(i, planes)
		elif _kind[i] == Kind.GEM:
			_step_gem(i, planes)
		else:
			_step_drop(i, planes)

		if _collect(i, planes, drone_counts):
			_remove(i)
			continue
		if not _sweeping and _age[i] >= _lifetime_of(i):
			expired_total += 1
			_log.append(TickEventLog.Kind.ITEM_EXPIRED, -1, _kind[i])
			_remove(i)
			continue
		i += 1


func _lifetime_of(i: int) -> int:
	if _kind[i] == Kind.ONEUP:
		return rules.oneup_lifetime
	if _kind[i] == Kind.GEM:
		return rules.gem_lifetime
	return rules.drop_lifetime


## F5, plus Rule 16's magnet. The bob uses the SimMath table, never the
## platform sin (ADR-0003).
func _step_drop(i: int, planes: PlaneCore) -> void:
	var pull := _magnet_target(i, planes)
	if pull >= 0:
		var to := planes.position_of(pull) - Vector2(_x[i], _y[i])
		if to.length() > 0.001:
			var step := to.normalized() * rules.magnet_speed
			_x[i] += step.x
			_y[i] += step.y
		return

	match _state[i]:
		State.POP:
			var t := _age[i] - 1
			_y[i] -= rules.pop_v0 * (1.0 - float(t) / float(maxi(1, rules.pop_ticks)))
			if _age[i] >= rules.pop_ticks:
				_state[i] = State.FALL
		State.FALL:
			_y[i] += rules.drop_fall
			if _y[i] >= rules.rest_y:
				_y[i] = rules.rest_y
				_state[i] = State.REST
		_:
			pass
	var bam := (_age[i] * SimMath.TURN) / maxi(1, rules.bob_period)
	_x[i] = clampf(
		_x0[i] + rules.bob_amp * SimMath.sin_bam(bam),
		rules.drop_inset,
		360.0 - rules.drop_inset
	)


## Rule 16: the nearest plane that could collect this item right now, if one
## is inside the magnet radius.
func _magnet_target(i: int, planes: PlaneCore) -> int:
	var best := -1
	var best_d := rules.magnet_radius * rules.magnet_radius
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not planes.is_active(slot):
			continue
		var d := planes.position_of(slot).distance_squared_to(Vector2(_x[i], _y[i]))
		if d <= best_d:
			best_d = d
			best = slot
	return best


## Rule 17 and F4. A gem flies to the slot that caused it while that slot is
## Active; otherwise it drifts down and anyone may take it.
func _step_gem(i: int, planes: PlaneCore) -> void:
	if _age[i] <= rules.gem_hold:
		return
	var cause := _cause[i]
	var can_fly := cause >= 0 and cause < PlaneCore.MAX_SLOTS and planes.is_active(cause)
	if not can_fly:
		_state[i] = State.DRIFT
		_fly[i] = 0
		_y[i] += rules.drop_fall
		return
	_state[i] = State.FLY
	var to := planes.position_of(cause) - Vector2(_x[i], _y[i])
	var dist := to.length()
	if dist <= 0.001:
		return
	var speed := minf(rules.gem_vmax, rules.gem_v0 + rules.gem_accel * float(_fly[i]))
	_fly[i] += 1
	var step := to / dist * minf(speed, dist)
	_x[i] += step.x
	_y[i] += step.y


func _step_sweep(i: int, planes: PlaneCore) -> void:
	var best := -1
	var best_d := INF
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not planes.is_active(slot):
			continue
		var d := planes.position_of(slot).distance_squared_to(Vector2(_x[i], _y[i]))
		if d < best_d:
			best_d = d
			best = slot
	if best < 0:
		return
	var to := planes.position_of(best) - Vector2(_x[i], _y[i])
	var dist := to.length()
	if dist <= 0.001:
		return
	var step := to / dist * minf(rules.sweep_speed, dist)
	_x[i] += step.x
	_y[i] += step.y


## Rules 19-22. First come; a tie goes to the plane with fewer drones, then to
## the lowest slot.
func _collect(i: int, planes: PlaneCore, drone_counts: PackedInt32Array) -> bool:
	var kind := _kind[i]
	var reach := rules.pickup_radius + _radius_of(kind)
	var reach2 := reach * reach
	var winner := -1
	var winner_drones := 99
	var pod_wanted := kind == Kind.POD and _someone_needs_a_pod(planes, drone_counts)
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not planes.is_active(slot):
			continue
		var drones := drone_counts[slot] if slot < drone_counts.size() else 0
		# Rule 20: a full plane lets a pod pass while a partner still needs one.
		if pod_wanted and drones >= rules.max_drones:
			continue
		if planes.position_of(slot).distance_squared_to(Vector2(_x[i], _y[i])) > reach2:
			continue
		if drones < winner_drones:
			winner_drones = drones
			winner = slot
	if winner < 0:
		return false
	_pay(kind, winner)
	collected_total += 1
	_log.append(TickEventLog.Kind.ITEM_COLLECTED, winner, kind)
	return true


func _someone_needs_a_pod(planes: PlaneCore, drone_counts: PackedInt32Array) -> bool:
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not planes.is_active(slot):
			continue
		var drones := drone_counts[slot] if slot < drone_counts.size() else 0
		if drones < rules.max_drones:
			return true
	return false


func _pay(kind: int, slot: int) -> void:
	match kind:
		Kind.POD:
			if on_pod.is_valid():
				on_pod.call(slot)
		Kind.CHAIN:
			if on_chain_bonus.is_valid():
				on_chain_bonus.call(slot, rules.chain_pickup_amount)
		Kind.ONEUP:
			# Rule 22: a 1-up at full lives pays a medal instead.
			var gained := true
			if on_oneup.is_valid():
				gained = bool(on_oneup.call(slot))
			if not gained and on_score.is_valid():
				on_score.call(slot, scoring_rules.medal_base)
		Kind.MEDAL:
			if on_score.is_valid():
				on_score.call(slot, scoring_rules.medal_base)
		Kind.GEM:
			if on_score.is_valid():
				on_score.call(slot, scoring_rules.gem_base)


func _radius_of(kind: int) -> float:
	return rules.item_radius[kind] if kind < rules.item_radius.size() else 6.0


func _remove(i: int) -> void:
	if _kind[i] == Kind.GEM:
		_gems -= 1
	else:
		_drops -= 1
	var last := _n - 1
	if i != last:
		_kind[i] = _kind[last]
		_state[i] = _state[last]
		_x[i] = _x[last]
		_y[i] = _y[last]
		_x0[i] = _x0[last]
		_age[i] = _age[last]
		_fly[i] = _fly[last]
		_cause[i] = _cause[last]
	_n = last


# --- reads for the renderer and the tests -------------------------------------

func count() -> int:
	return _n


func gem_count() -> int:
	return _gems


func drop_count() -> int:
	return _drops


func kind_of(i: int) -> int:
	return _kind[i]


func position_of(i: int) -> Vector2:
	return Vector2(_x[i], _y[i])


func state_of(i: int) -> int:
	return _state[i]


## True while this item is inside the last ticks of its life, so the renderer
## can pulse it (Rule 15).
func is_pulsing(i: int) -> bool:
	return _age[i] >= _lifetime_of(i) - rules.pulse_ticks


func count_of_kind(kind: int) -> int:
	var n := 0
	for i: int in range(_n):
		if _kind[i] == kind:
			n += 1
	return n


func state_hash() -> int:
	var h := 1469598103934665603
	h = (h ^ _n) * 1099511628211
	h = (h ^ pity_misses) * 1099511628211
	h = (h ^ carriers_this_stage) * 1099511628211
	for i: int in range(_n):
		h = (h ^ _kind[i]) * 1099511628211
		h = (h ^ _state[i]) * 1099511628211
		h = (h ^ int(_x[i] * 16.0)) * 1099511628211
		h = (h ^ int(_y[i] * 16.0)) * 1099511628211
	return h
