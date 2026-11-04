class_name PlaneKits
extends RefCounted
## The four co-op slots' plane kits: the main shot, the drones, and each
## plane's own charge mode and drone ability.
## Implements design/gdd/plane-kits-lancer-leech.md (Lancer, Leech) and
## design/gdd/plane-kits-sentry-breaker.md (Sentry, Breaker), which inherits
## Rules 1-15 of the first unchanged.
##
## Node-free, integer ticks, no randomness at all — ties break by target
## index, so two players with identical inputs get identical results and a
## replay is exact (Rule 1).
##
## It owns the player bullet pool, because the plane shot and the drone
## bullets are the same pool with different tags (Rule 8). It does NOT own
## damage resolution: the beam, parked beam and latch send damage events out
## through `on_damage`, and Collision decides what they cost.
##
## The four planes, in one sentence each:
##   LANCER  3-way spread; hold to burn a LASER that also shields; drones park
##           and beam columns straight up.
##   LEECH   tight pair; hold to focus into two hard slow bullets; drones fly
##           out and LATCH onto enemies, ticking damage.
##   SENTRY  twin parallel guns; hold to ENTRENCH behind a nose cannon while
##           the docked drones aim themselves; drones EMPLACE as world-anchored
##           turrets you can recall early.
##   BREAKER one heavy ram shot; hold to BREACH with slugs plus seeking return
##           bolts paid for out of a stock; drones hold an ERASE NET that
##           deletes enemy bullets and refills that stock.
##
## Usage:
## [codeblock]
## var kits := PlaneKits.new(rules, bullet_rules, play_area)
## kits.on_damage = func(slot, target, amount): ...
## kits.set_kind(0, KitRules.Kind.LANCER)
##
## # step 3, after the planes have moved
## kits.tick(planes, input, enemies)
## [/codeblock]

const MAX_SLOTS := 4
const MAX_DRONES := 4

## Rule 4's fire state machine.
enum Fire { IDLE, SHOT, CHARGE, HOLD_PLAIN }
## Where a drone is. DOCKED drones fire idle bullets; nothing else does
## (Rule 9). GOING is in transit to a Sentry post or a Breaker station.
enum Drone { DOCKED, GOING, PARKED, FLYING, LATCHED, RETURNING, EMPLACED, NET_ON }
## Rule 30's ability gate.
enum Ability { READY, ACTIVE, COOLDOWN }

var rules: KitRules
## The player bullet pool. Enemies are registered as its targets each tick.
var field: BulletField
## Called for damage that is not a bullet: the laser, parked beams, latches.
## `func(slot: int, target_index: int, amount: int) -> void`.
var on_damage: Callable

var shots_fired := 0

# Per slot.
var _kind := PackedInt32Array()
var _fire := PackedInt32Array()
var _held_ticks := PackedInt32Array()
var _linger := PackedInt32Array()
var _shot_cd := PackedInt32Array()
var _meter := PackedInt32Array()
var _laser_ticks := PackedInt32Array()   ## -1 when the laser is off
var _drone_count := PackedInt32Array()
var _ability := PackedInt32Array()
var _ability_timer := PackedInt32Array()
var _cooldown := PackedInt32Array()
var _return_ticks := PackedInt32Array()
## Where the beam stopped last tick, for the renderer. -1 means "no target".
var _beam_top := PackedFloat32Array()
## Breaker return stock (GDD 29 Rule 21): it rises only from erased bullets,
## never decays, and death takes all of it.
var _stock := PackedInt32Array()
var _bolt_cd := PackedInt32Array()
## Ticks since the drone ability was accepted, for Sentry's early recall.
var _ability_age := PackedInt32Array()
## Consecutive ticks this slot's charge mode has run, 0 when it is not
## charging. The Critical Break (17) needs it and nothing else does.
var _charge_ticks := PackedInt32Array()
## Which drone made each erase pulse this slot requested last tick, in request
## order. The bullet field reports its regions in the same order, so a report
## can be matched back to the drone that earned it (Rule 25).
var _pulse_drone: Array[PackedInt32Array] = []

# Per drone, indexed slot * MAX_DRONES + d.
var _d_state := PackedInt32Array()
var _d_x := PackedFloat32Array()
var _d_y := PackedFloat32Array()
var _d_target := PackedInt32Array()
var _d_phase := PackedInt32Array()
## Sentry: the world-anchored post this drone flies to and stands on.
var _d_post_x := PackedFloat32Array()
var _d_post_y := PackedFloat32Array()
## Breaker: bullets this drone has erased this activation (Rule 23).
var _d_tally := PackedInt32Array()

var _tick := 0


func _init(p_rules: KitRules, bullet_rules: BulletRules, play_area: Rect2) -> void:
	assert(p_rules != null, "PlaneKits needs a KitRules (data/kit_rules.tres)")
	rules = p_rules
	field = BulletField.new(bullet_rules, play_area, bullet_rules.player_cap)
	_kind.resize(MAX_SLOTS)
	_fire.resize(MAX_SLOTS)
	_held_ticks.resize(MAX_SLOTS)
	_linger.resize(MAX_SLOTS)
	_shot_cd.resize(MAX_SLOTS)
	_meter.resize(MAX_SLOTS)
	_laser_ticks.resize(MAX_SLOTS)
	_laser_ticks.fill(-1)
	_drone_count.resize(MAX_SLOTS)
	_drone_count.fill(p_rules.starting_drones)
	_ability.resize(MAX_SLOTS)
	_ability_timer.resize(MAX_SLOTS)
	_cooldown.resize(MAX_SLOTS)
	_return_ticks.resize(MAX_SLOTS)
	_beam_top.resize(MAX_SLOTS)
	_beam_top.fill(-1.0)
	_stock.resize(MAX_SLOTS)
	_bolt_cd.resize(MAX_SLOTS)
	_ability_age.resize(MAX_SLOTS)
	_charge_ticks.resize(MAX_SLOTS)
	_pulse_drone.resize(MAX_SLOTS)
	for s: int in range(MAX_SLOTS):
		_pulse_drone[s] = PackedInt32Array()
	var cells := MAX_SLOTS * MAX_DRONES
	_d_state.resize(cells)
	_d_x.resize(cells)
	_d_y.resize(cells)
	_d_target.resize(cells)
	_d_target.fill(-1)
	_d_phase.resize(cells)
	_d_post_x.resize(cells)
	_d_post_y.resize(cells)
	_d_tally.resize(cells)
	for s: int in range(MAX_SLOTS):
		for d: int in range(MAX_DRONES):
			# Rule 9: a fixed phase per drone, so four drones never fire on
			# the same tick and the hit rate stays inside its cap.
			_d_phase[s * MAX_DRONES + d] = (d * rules.drone_interval) / 4


func set_kind(slot: int, kind: int) -> void:
	_kind[slot] = kind


func kind_of(slot: int) -> int:
	return _kind[slot]


## One tick, for every slot. `enemies` may be null before the stage exists;
## `enemy_bullets` is the enemy pool the Breaker net erases from, and without
## it the net simply removes nothing.
func tick(
	planes: PlaneCore,
	input: SimInput,
	enemies: EnemyManager,
	enemy_bullets: BulletField = null
) -> void:
	_tick += 1
	# Rule 25: last tick's erase reports arrive now, before anything else can
	# spend the stock they credit.
	_credit_erase_reports(enemy_bullets)
	for slot: int in range(MAX_SLOTS):
		if _bolt_cd[slot] > 0:
			_bolt_cd[slot] -= 1
		if _cooldown[slot] > 0:
			_cooldown[slot] -= 1
			if _cooldown[slot] == 0:
				_ability[slot] = Ability.READY
		if _shot_cd[slot] > 0:
			_shot_cd[slot] -= 1

		if not planes.is_active(slot):
			# Rule 3: a plane that is not Active fires nothing and ignores
			# every button. Rule 13: death clears the kit outright.
			if planes.state_of(slot) == PlaneCore.State.DEAD:
				_reset_slot(slot)
			continue

		# A docked drone sits on its wing slot. This has to happen BEFORE the
		# Drone button is read, because "park where you are" (Rule 23) reads
		# the drone's position — and on the first tick of a run it would
		# otherwise still be (0, 0), parking the whole flight in the corner.
		_dock_positions(slot, planes)
		_tick_fire_state(slot, input)
		_tick_drone_button(slot, input, planes, enemies)
		_tick_shot(slot, planes, enemies)
		_tick_drones(slot, planes, enemies, enemy_bullets)
		_tick_laser(slot, planes, enemies)
		_charge_ticks[slot] = _charge_ticks[slot] + 1 if _is_charging(slot) else 0


## GDD 29 Rule 25: a report credits `min(count, credit_per_pulse_cap)` to the
## stock and the whole count to the drone's tally. Reports arrive in request
## order, which is how each one finds the drone that earned it.
func _credit_erase_reports(enemy_bullets: BulletField) -> void:
	for slot: int in range(MAX_SLOTS):
		var queued := _pulse_drone[slot]
		if queued.size() == 0:
			continue
		var seen := 0
		if enemy_bullets != null:
			var causes := enemy_bullets.cancel_region_cause
			var counts := enemy_bullets.cancel_region_count
			for r: int in range(causes.size()):
				if causes[r] != slot:
					continue
				if seen >= queued.size():
					break
				var count := counts[r]
				var d := queued[seen]
				seen += 1
				if d >= 0:
					_d_tally[slot * MAX_DRONES + d] += count
				_stock[slot] = mini(
					rules.stock_max,
					_stock[slot] + mini(count, rules.credit_per_pulse_cap)
				)
		_pulse_drone[slot] = PackedInt32Array()


# --- Rule 4, 5: the fire state machine ---------------------------------------

func _tick_fire_state(slot: int, input: SimInput) -> void:
	var held := input.fire_held(slot)
	var pressed := input.pressed(slot, SimInput.Action.FIRE)

	if pressed:
		_held_ticks[slot] = 0
		_linger[slot] = 0
		_fire[slot] = Fire.SHOT
	elif held and _fire[slot] == Fire.IDLE:
		# Fire was already down before this plane could use it: through the
		# fly-in, through the death hold, or on the tick a slot joined. Rule 3
		# says a plane that is not Active ignores the button, not that it
		# forgets it — so the gun starts now, and the charge is timed from
		# now. Without this, holding Fire across a respawn left the plane
		# disarmed until the player let go and pressed again.
		_held_ticks[slot] = 0
		_linger[slot] = 0
		_fire[slot] = Fire.SHOT
	elif held:
		_held_ticks[slot] += 1
	else:
		# Rule 5: a tap lingers; a released hold stops at once.
		if _fire[slot] == Fire.SHOT and _linger[slot] == 0 and _held_ticks[slot] > 0:
			_linger[slot] = rules.shot_linger_ticks
		if _fire[slot] == Fire.CHARGE or _fire[slot] == Fire.HOLD_PLAIN:
			_end_laser(slot)
			_fire[slot] = Fire.IDLE
		_held_ticks[slot] = 0
		if _linger[slot] > 0:
			_linger[slot] -= 1
			_fire[slot] = Fire.SHOT
		else:
			_fire[slot] = Fire.IDLE

	# Rule 4: the charge edge, checked once, on the tick the hold reaches 18.
	if held and _fire[slot] == Fire.SHOT and _held_ticks[slot] == rules.charge_hold_ticks:
		if _can_charge(slot):
			_begin_charge(slot)
		else:
			_fire[slot] = Fire.HOLD_PLAIN
	# A Lancer whose meter filled up DURING the hold. Without this the laser
	# is unreachable for anyone who holds Fire the way a shmup player does
	# (see `charge_rearms_while_held`).
	elif (
		held
		and _fire[slot] == Fire.HOLD_PLAIN
		and rules.charge_rearms_while_held
		and _can_charge(slot)
	):
		_begin_charge(slot)


func _begin_charge(slot: int) -> void:
	_fire[slot] = Fire.CHARGE
	if _kind[slot] == KitRules.Kind.LANCER:
		_laser_ticks[slot] = 0


## Rule 17: the Lancer needs meter AT the charge tick. Every other kit's
## charge mode costs nothing to start (GDD 29 Rule 1), so HOLD_PLAIN only ever
## happens to a Lancer with a short meter.
func _can_charge(slot: int) -> bool:
	if _kind[slot] != KitRules.Kind.LANCER:
		return true
	return _meter[slot] >= rules.laser_min_meter


func _is_charging(slot: int) -> bool:
	return _fire[slot] == Fire.CHARGE


func _gun_on(slot: int) -> bool:
	return _fire[slot] != Fire.IDLE


# --- Rules 16, 26, 27: the plane shot ----------------------------------------

func _tick_shot(slot: int, planes: PlaneCore, enemies: EnemyManager) -> void:
	if not _gun_on(slot):
		return
	# Rule 19: while the laser burns, the plane shot is off.
	if _laser_ticks[slot] >= 0:
		return
	var at := planes.position_of(slot)
	var charging := _is_charging(slot)

	# The Breaker's bolts have their own cooldown, so they are not gated by
	# the volley cooldown below (GDD 29 Rule 20).
	if charging and _kind[slot] == KitRules.Kind.BREAKER:
		_try_bolt(slot, at, enemies)

	if _shot_cd[slot] > 0:
		return

	match _kind[slot]:
		KitRules.Kind.LANCER:
			_volley(slot, at, rules.lancer_shot_count, rules.lancer_spread_rad, 14.0)
			_shot_cd[slot] = rules.shot_interval
		KitRules.Kind.LEECH:
			if charging:
				# Rule 27: two bullets, 6 px apart, straight up, harder and
				# slower.
				_volley(slot, at, 2, 0.0, 16.0, 3.0, rules.focus_damage)
				_shot_cd[slot] = rules.focus_interval
			else:
				_volley(slot, at, rules.leech_shot_count, rules.leech_spread_rad, 16.0)
				_shot_cd[slot] = rules.shot_interval
		KitRules.Kind.SENTRY:
			if charging:
				# Rule 11: Entrench replaces the twin guns with one nose shell.
				_volley(slot, at, 1, 0.0, 18.0, 6.0, rules.entrench_damage)
				_shot_cd[slot] = rules.entrench_interval
			else:
				# Rule 10: a parallel pair, not a fan.
				_volley(
					slot, at, rules.sentry_shot_count, 0.0, 12.0,
					rules.sentry_muzzle_dx * 2.0
				)
				_shot_cd[slot] = rules.sentry_shot_interval
		KitRules.Kind.BREAKER:
			# Rules 18-19: one bullet either way; Breach only changes what it
			# is worth and how fast it comes.
			_volley(
				slot, at, 1, 0.0, 20.0, 6.0,
				rules.breach_damage if charging else rules.breaker_shot_damage
			)
			_shot_cd[slot] = (
				rules.breach_interval if charging else rules.breaker_shot_interval
			)


## GDD 29 Rule 20: a seeking bolt, paid for out of the return stock. A refused
## request is lost with no retry, exactly as a normal shot would be (Rule 8).
func _try_bolt(slot: int, at: Vector2, enemies: EnemyManager) -> void:
	if _bolt_cd[slot] > 0 or _stock[slot] < rules.bolt_cost or enemies == null:
		return
	var muzzle := at + Vector2(0.0, -20.0)
	var target := enemies.nearest(muzzle)
	if target < 0:
		return
	var to := enemies.position_of(target) - muzzle
	var dist := to.length()
	if dist > rules.bolt_range or dist <= 0.001:
		return
	var unit := to / dist
	# px/tick in the rules, px/s in the pool.
	var speed := rules.bolt_speed * 60.0
	_stock[slot] -= rules.bolt_cost
	_bolt_cd[slot] = rules.bolt_interval
	if field.request_spawn(
		muzzle.x, muzzle.y, unit.x * speed, unit.y * speed,
		BulletField.Beh.LINEAR, BulletRules.Shape.NEEDLE, 0.0, slot,
		rules.bolt_damage
	):
		shots_fired += 1


## One volley of `count` bullets, fanned by `spread` and leaving `muzzle_y`
## above the plane centre. `damage` travels on each bullet, because one pool
## holds shots of several strengths at once.
func _volley(
	slot: int,
	at: Vector2,
	count: int,
	spread: float,
	muzzle_y: float,
	spacing := 6.0,
	damage := -1
) -> void:
	var dmg := damage if damage >= 0 else rules.shot_damage
	var n := maxi(1, count)
	var half := float(n - 1) * 0.5
	var spread_bam := SimMath.rad_to_bam(spread)
	var up := -SimMath.QUARTER
	for i: int in range(n):
		var angle := up + roundi((float(i) - half) * float(spread_bam))
		if field.request_spawn(
			at.x + (float(i) - half) * spacing,
			at.y - muzzle_y,
			SimMath.cos_bam(angle) * rules.shot_speed,
			SimMath.sin_bam(angle) * rules.shot_speed,
			BulletField.Beh.LINEAR,
			BulletRules.Shape.NEEDLE,
			0.0,
			slot,
			dmg
		):
			shots_fired += 1


# --- Rules 9, 23, 28-36: drones ----------------------------------------------

## Pins every docked drone to its wing slot, which moves with the plane.
func _dock_positions(slot: int, planes: PlaneCore) -> void:
	var base := planes.position_of(slot)
	for d: int in range(MAX_DRONES):
		var i := slot * MAX_DRONES + d
		if _d_state[i] == Drone.DOCKED:
			var home: Vector2 = base + rules.drone_slots[d]
			_d_x[i] = home.x
			_d_y[i] = home.y


func _tick_drone_button(
	slot: int, input: SimInput, planes: PlaneCore, enemies: EnemyManager
) -> void:
	# Rule 17 (Input): the press is BUFFERED, so a press made a few ticks
	# before the ability was ready — or on the tick a pod was still in the
	# air — still deploys. It is consumed only on the tick it is accepted,
	# which is what stops "I pressed Drone and nothing happened".
	if not input.buffered(slot, SimInput.Action.DRONE):
		return
	# GDD 29 Rule 14: a Sentry press while its turrets are out is an early
	# recall, not a rejection — but only after `recall_min_ticks`.
	if (
		_kind[slot] == KitRules.Kind.SENTRY
		and _ability[slot] == Ability.ACTIVE
		and _ability_age[slot] >= rules.recall_min_ticks
	):
		input.consume(slot, SimInput.Action.DRONE)
		_recall(slot)
		return
	# Rule 30: the press is accepted only when everything holds. A rejected
	# press starts no cooldown and does nothing at all.
	if _ability[slot] != Ability.READY or _drone_count[slot] < 1:
		return
	# Only the Leech needs something to latch onto. A Sentry pre-places its
	# turrets and a Breaker net works on an empty screen (GDD 29 Rule 4).
	if _kind[slot] == KitRules.Kind.LEECH and (enemies == null or enemies.count() == 0):
		return

	input.consume(slot, SimInput.Action.DRONE)
	_ability[slot] = Ability.ACTIVE
	_return_ticks[slot] = 0
	_ability_age[slot] = 0
	var plane := planes.position_of(slot)
	match _kind[slot]:
		KitRules.Kind.LANCER:
			_ability_timer[slot] = rules.park_ticks
			for d: int in range(_drone_count[slot]):
				var i := slot * MAX_DRONES + d
				# Rule 23: it parks where it IS, clamped inside the screen.
				_d_state[i] = Drone.PARKED
				_d_x[i] = clampf(_d_x[i], 8.0, 352.0)
		KitRules.Kind.LEECH:
			_ability_timer[slot] = rules.latch_ticks
			for d: int in range(_drone_count[slot]):
				var i := slot * MAX_DRONES + d
				_d_state[i] = Drone.FLYING
				_d_target[i] = -1
		KitRules.Kind.SENTRY:
			# GDD 29 Rule 13: the posts are WORLD-anchored. They are fixed
			# here, at the press, and do not follow the plane afterwards.
			_ability_timer[slot] = rules.emplace_ticks
			for d: int in range(_drone_count[slot]):
				var i := slot * MAX_DRONES + d
				var dx: float = rules.post_dx[d] if d < rules.post_dx.size() else 0.0
				_d_post_x[i] = clampf(plane.x + dx, 14.0, 346.0)
				_d_post_y[i] = clampf(plane.y + rules.post_dy, 40.0, 560.0)
				_d_state[i] = Drone.GOING
				_d_target[i] = -1
		KitRules.Kind.BREAKER:
			# GDD 29 Rule 22: the stations are PLANE-relative and recomputed
			# every tick, so the net flies with the player.
			_ability_timer[slot] = rules.net_ticks
			for d: int in range(_drone_count[slot]):
				var i := slot * MAX_DRONES + d
				_d_state[i] = Drone.GOING
				_d_tally[i] = 0
				_d_target[i] = -1


## Rule 36 / GDD 29 Rule 5: everything out comes home and the cooldown starts.
func _recall(slot: int) -> void:
	for d: int in range(MAX_DRONES):
		var i := slot * MAX_DRONES + d
		if _d_state[i] != Drone.DOCKED:
			_d_state[i] = Drone.RETURNING
			_d_target[i] = -1
	_ability[slot] = Ability.COOLDOWN
	_return_ticks[slot] = 0
	_cooldown[slot] = _cooldown_of(slot)


func _cooldown_of(slot: int) -> int:
	match _kind[slot]:
		KitRules.Kind.LANCER:
			return rules.lancer_cooldown
		KitRules.Kind.SENTRY:
			return rules.sentry_cooldown
		KitRules.Kind.BREAKER:
			return rules.breaker_cooldown
		_:
			return rules.leech_cooldown


func _tick_drones(
	slot: int, planes: PlaneCore, enemies: EnemyManager, enemy_bullets: BulletField
) -> void:
	var base := planes.position_of(slot)
	if _ability[slot] == Ability.ACTIVE:
		_ability_age[slot] += 1
		_ability_timer[slot] -= 1
		if _ability_timer[slot] <= 0:
			_recall(slot)

	var all_home := true
	for d: int in range(MAX_DRONES):
		var i := slot * MAX_DRONES + d
		if d >= _drone_count[slot]:
			_d_state[i] = Drone.DOCKED
			continue
		var home: Vector2 = base + rules.drone_slots[d]
		match _d_state[i]:
			Drone.DOCKED:
				_d_x[i] = home.x
				_d_y[i] = home.y
				if _gun_on(slot) and _tick % rules.drone_interval == _d_phase[i]:
					_fire_idle_drone(slot, i, enemies)
			Drone.GOING:
				all_home = false
				_fly_to_station(slot, i, d, base)
			Drone.EMPLACED:
				all_home = false
				_fire_turret(slot, i, enemies)
			Drone.NET_ON:
				all_home = false
				_tick_net(slot, i, d, base, enemies, enemy_bullets)
			Drone.PARKED:
				all_home = false
				if enemies != null and _tick % rules.park_interval == _d_phase[i]:
					# Rule 23: a thin beam straight up, stopping at the first
					# hurtbox in its column, like the laser.
					var target := enemies.first_in_column(
						_d_x[i], rules.park_half_width, _d_y[i]
					)
					if target >= 0:
						_send_damage(slot, target, rules.park_damage)
			Drone.FLYING:
				all_home = false
				_fly_to_target(slot, i, enemies)
			Drone.LATCHED:
				all_home = false
				_ride_target(slot, i, enemies)
			Drone.RETURNING:
				var to_home := home - Vector2(_d_x[i], _d_y[i])
				if to_home.length() <= rules.return_speed or _return_ticks[slot] >= rules.return_cap:
					_d_state[i] = Drone.DOCKED
				else:
					var step := to_home.normalized() * rules.return_speed
					_d_x[i] += step.x
					_d_y[i] += step.y
					all_home = false

	if _ability[slot] == Ability.COOLDOWN and not all_home:
		_return_ticks[slot] += 1


## Rule 9: a docked drone fires one diamond straight up while the gun is on.
## A Sentry in Entrench aims it instead (GDD 29 Rule 12) — the only case in
## which a drone bullet is not vertical.
func _fire_idle_drone(slot: int, i: int, enemies: EnemyManager) -> void:
	var vx := 0.0
	var vy := -rules.shot_speed
	if _kind[slot] == KitRules.Kind.SENTRY and _is_charging(slot) and enemies != null:
		var target := _nearest_above(enemies, Vector2(_d_x[i], _d_y[i]), rules.track_range)
		if target >= 0:
			var to := enemies.position_of(target) - Vector2(_d_x[i], _d_y[i])
			if to.length() > 0.001:
				# Clamped to `track_max_deg` off vertical, so a tracking drone
				# never fires sideways or down (GDD 29 SB1).
				var up := -SimMath.QUARTER
				var want := SimMath.atan2_bam(to.y, to.x)
				var limit := SimMath.rad_to_bam(deg_to_rad(rules.track_max_deg))
				var off := clampi(SimMath.delta_bam(up, want), -limit, limit)
				var aim := up + off
				vx = SimMath.cos_bam(aim) * rules.shot_speed
				vy = SimMath.sin_bam(aim) * rules.shot_speed
	if field.request_spawn(
		_d_x[i], _d_y[i], vx, vy,
		BulletField.Beh.LINEAR, BulletRules.Shape.RICE, 0.0, slot, rules.shot_damage
	):
		shots_fired += 1


## The nearest hittable enemy above `from` and inside `range_px`, or -1.
func _nearest_above(enemies: EnemyManager, from: Vector2, range_px: float) -> int:
	var best := -1
	var best_d := range_px * range_px
	for t: int in range(enemies.count()):
		if not enemies.is_hittable(t):
			continue
		var at := enemies.position_of(t)
		if at.y >= from.y - 8.0:
			continue
		var d := from.distance_squared_to(at)
		if d <= best_d:
			best_d = d
			best = t
	return best


## GDD 29 Rules 13 and 22: a drone on its way out. The Sentry post is fixed in
## the world; the Breaker station moves with the plane and is recomputed here.
func _fly_to_station(slot: int, i: int, d: int, base: Vector2) -> void:
	var to_target := Vector2(_d_post_x[i], _d_post_y[i])
	var speed := rules.post_speed
	var arrive := Drone.EMPLACED
	if _kind[slot] == KitRules.Kind.BREAKER:
		to_target = _station_of(d, base)
		speed = rules.station_speed
		arrive = Drone.NET_ON
	var to := to_target - Vector2(_d_x[i], _d_y[i])
	if to.length() <= speed:
		_d_x[i] = to_target.x
		_d_y[i] = to_target.y
		_d_state[i] = arrive
		return
	var step := to.normalized() * speed
	_d_x[i] += step.x
	_d_y[i] += step.y


func _station_of(d: int, base: Vector2) -> Vector2:
	var dx: float = rules.station_dx[d] if d < rules.station_dx.size() else 0.0
	return Vector2(clampf(base.x + dx, 26.0, 334.0), maxf(14.0, base.y + rules.station_dy))


## GDD 29 Rule 15: one aimed diamond every `turret_interval` ticks at whatever
## is inside `turret_range`. A turret never moves and cannot be hit.
func _fire_turret(slot: int, i: int, enemies: EnemyManager) -> void:
	if enemies == null:
		return
	if _tick % rules.turret_interval != (_d_phase[i] % rules.turret_interval):
		return
	var post := Vector2(_d_x[i], _d_y[i])
	var target := enemies.nearest(post)
	if target < 0:
		return
	var to := enemies.position_of(target) - post
	var dist := to.length()
	if dist > rules.turret_range or dist <= 0.001:
		return
	var unit := to / dist
	if field.request_spawn(
		post.x, post.y, unit.x * rules.shot_speed, unit.y * rules.shot_speed,
		BulletField.Beh.LINEAR, BulletRules.Shape.RICE, 0.0, slot, rules.turret_damage
	):
		shots_fired += 1


## GDD 29 Rules 22-27: the net. The drone rides its station, erases enemy
## bullets in a 26 px circle, and rams whatever shares that circle.
func _tick_net(
	slot: int,
	i: int,
	d: int,
	base: Vector2,
	enemies: EnemyManager,
	enemy_bullets: BulletField
) -> void:
	var station := _station_of(d, base)
	_d_x[i] = station.x
	_d_y[i] = station.y

	# Rule 24: a spent drone stops erasing but keeps its station and its ram.
	var spent := _d_tally[i] >= rules.net_budget
	var pulse := (_tick + d) % maxi(1, rules.net_pulse_interval) == 0
	# Rule 24: the net never covers the plane's own hitbox neighbourhood.
	var clear_of_plane := station.distance_to(base) - rules.net_r >= rules.net_safe_clear
	if not spent and pulse and clear_of_plane and enemy_bullets != null:
		# Rule 33: a kit cancel NEVER pays score items. A continuous net that
		# did would be a gem farm.
		enemy_bullets.request_cancel_circle(station.x, station.y, rules.net_r, slot, false)
		var queue := _pulse_drone[slot]
		queue.append(d)
		_pulse_drone[slot] = queue

	# Rule 27: the ram, one event to the lowest-id target in the zone.
	if enemies == null:
		return
	if _tick % rules.net_ram_interval != (_d_phase[i] % rules.net_ram_interval):
		return
	for t: int in range(enemies.count()):
		if not enemies.is_hittable(t):
			continue
		if station.distance_to(enemies.position_of(t)) < rules.net_r + enemies.hurt_radius_of(t):
			_send_damage(slot, t, rules.net_ram_damage)
			return


## Rules 33-35: fly at the target's current position, latch on arrival, and
## pick a new target the moment the old one is gone.
func _fly_to_target(slot: int, i: int, enemies: EnemyManager) -> void:
	if enemies == null:
		return
	if not _target_valid(enemies, _d_target[i]):
		_d_target[i] = _pick_target(slot, enemies, Vector2(_d_x[i], _d_y[i]))
	if _d_target[i] < 0:
		return   # SEARCHING: it hovers and re-checks next tick (Rule 34)
	var at := enemies.position_of(_d_target[i])
	var to := at - Vector2(_d_x[i], _d_y[i])
	if to.length() <= rules.latch_radius:
		_d_state[i] = Drone.LATCHED
		return
	var step := to.normalized() * rules.latch_speed
	_d_x[i] += step.x
	_d_y[i] += step.y


func _ride_target(slot: int, i: int, enemies: EnemyManager) -> void:
	if enemies == null or not _target_valid(enemies, _d_target[i]):
		_d_state[i] = Drone.FLYING
		_d_target[i] = -1
		return
	var at := enemies.position_of(_d_target[i])
	_d_x[i] = at.x
	_d_y[i] = at.y
	if _tick % rules.latch_interval == (_d_phase[i] % rules.latch_interval):
		_send_damage(slot, _d_target[i], rules.latch_damage)


func _target_valid(enemies: EnemyManager, index: int) -> bool:
	return index >= 0 and index < enemies.count() and enemies.is_hittable(index)


## Rule 34: the nearest eligible target, skipping any already claimed by
## `latch_max_per_target` drones. Ties break by index, never by chance.
func _pick_target(slot: int, enemies: EnemyManager, from: Vector2) -> int:
	var best := -1
	var best_d := INF
	var fallback := -1
	var fallback_d := INF
	for t: int in range(enemies.count()):
		if not enemies.is_hittable(t):
			continue
		var d := from.distance_squared_to(enemies.position_of(t))
		if d < fallback_d:
			fallback_d = d
			fallback = t
		if _claims_on(slot, t) >= rules.latch_max_per_target:
			continue
		if d < best_d:
			best_d = d
			best = t
	return best if best >= 0 else fallback


func _claims_on(slot: int, target: int) -> int:
	var n := 0
	for d: int in range(MAX_DRONES):
		var i := slot * MAX_DRONES + d
		if _d_target[i] == target and (_d_state[i] == Drone.FLYING or _d_state[i] == Drone.LATCHED):
			n += 1
	return n


# --- Rules 18-22: the laser ---------------------------------------------------

func _tick_laser(slot: int, planes: PlaneCore, enemies: EnemyManager) -> void:
	if _laser_ticks[slot] < 0:
		return
	if _fire[slot] != Fire.CHARGE:
		_end_laser(slot)
		return

	var k := _laser_ticks[slot]
	# (a) invulnerability, every active tick, so the beam is also a shield.
	planes.request_invuln(slot, rules.laser_invuln_ticks)
	# (b) the meter burns whether or not anything is in the beam.
	_meter[slot] = maxi(0, _meter[slot] - rules.meter_per_tick)
	# (c) the beam stops at the first hurtbox in its column.
	var at := planes.position_of(slot)
	var target := -1
	if enemies != null:
		target = enemies.first_in_column(at.x, rules.laser_half_width, at.y - 14.0)
	_beam_top[slot] = enemies.position_of(target).y if target >= 0 else -1.0
	# (d) damage on every third active tick.
	if target >= 0 and k % rules.laser_damage_interval == 0:
		_send_damage(slot, target, rules.laser_damage)

	_laser_ticks[slot] = k + 1
	# (f) out of meter: this was the last tick. The hold becomes a plain hold,
	# so the normal shot comes back AND the meter can arm another laser
	# without the player having to let go (`charge_rearms_while_held`).
	if _meter[slot] <= 0:
		_end_laser(slot)
		if _fire[slot] == Fire.CHARGE:
			_fire[slot] = Fire.HOLD_PLAIN


func _end_laser(slot: int) -> void:
	_laser_ticks[slot] = -1
	_beam_top[slot] = -1.0


## Rule 20: the meter fills ONLY from plane-shot bullets that counted, and
## never while the laser is running.
func report_shot_hit(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	if _kind[slot] != KitRules.Kind.LANCER or _laser_ticks[slot] >= 0:
		return
	_meter[slot] = mini(rules.meter_max, _meter[slot] + rules.fill_per_hit)


func _send_damage(slot: int, target: int, amount: int) -> void:
	if on_damage.is_valid():
		on_damage.call(slot, target, amount)


## Rule 13: death clears the kit. Everything goes home, the laser stops, the
## meter is gone.
func _reset_slot(slot: int) -> void:
	for d: int in range(MAX_DRONES):
		var i := slot * MAX_DRONES + d
		_d_state[i] = Drone.DOCKED
		_d_target[i] = -1
		_d_tally[i] = 0
	_end_laser(slot)
	_fire[slot] = Fire.IDLE
	_held_ticks[slot] = 0
	_linger[slot] = 0
	_shot_cd[slot] = 0
	_meter[slot] = 0
	_charge_ticks[slot] = 0
	_ability[slot] = Ability.READY
	_ability_timer[slot] = 0
	_ability_age[slot] = 0
	_cooldown[slot] = 0
	# GDD 29 Rule 21: death takes the whole return stock.
	_stock[slot] = 0
	_bolt_cd[slot] = 0
	_pulse_drone[slot] = PackedInt32Array()


# --- reads for the HUD and the renderer --------------------------------------

func fire_state(slot: int) -> int:
	return _fire[slot]


func is_laser_active(slot: int) -> bool:
	return _laser_ticks[slot] >= 0


## Where the beam ends: the first hurtbox in the column, or the top of the
## field when there is nothing to stop it (Rule 19).
func beam_top(slot: int) -> float:
	return _beam_top[slot]


func meter_of(slot: int) -> int:
	return _meter[slot]


func meter_ratio(slot: int) -> float:
	return float(_meter[slot]) / float(maxi(1, rules.meter_max))


func drone_count(slot: int) -> int:
	return _drone_count[slot]


func set_drone_count(slot: int, count: int) -> void:
	_drone_count[slot] = clampi(count, 0, rules.max_drones)


func drone_state(slot: int, d: int) -> int:
	return _d_state[slot * MAX_DRONES + d]


func drone_position(slot: int, d: int) -> Vector2:
	var i := slot * MAX_DRONES + d
	return Vector2(_d_x[i], _d_y[i])


func ability_state(slot: int) -> int:
	return _ability[slot]


func ability_timer(slot: int) -> int:
	return _ability_timer[slot]


func cooldown_left(slot: int) -> int:
	return _cooldown[slot]


## Rule 22 / GDD 29 Rule 11: the plane crawls while the laser burns, and is
## slowed while a Sentry is entrenched. -1 means "the plane's own speed".
func ability_speed(slot: int) -> float:
	if is_laser_active(slot):
		return rules.laser_speed
	if _kind[slot] == KitRules.Kind.SENTRY and _is_charging(slot):
		return rules.entrench_speed
	return -1.0


## GDD 29 Rule 21: the Breaker's return stock, which only erased bullets fill.
func stock_of(slot: int) -> int:
	return _stock[slot]


## Test seam: the stock normally only rises by erasing bullets, which takes a
## net and a curtain. A bolt test should not have to build one.
func set_stock_for_test(slot: int, amount: int) -> void:
	_stock[slot] = clampi(amount, 0, rules.stock_max)


func stock_ratio(slot: int) -> float:
	return float(_stock[slot]) / float(maxi(1, rules.stock_max))


## Erase zones to draw this tick, as x, y pairs (GDD 29 Rule 34: the net must
## be visible, or a bullet vanishing is unexplained).
func net_zones(slot: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for d: int in range(MAX_DRONES):
		var i := slot * MAX_DRONES + d
		if _d_state[i] == Drone.NET_ON:
			out.append(_d_x[i])
			out.append(_d_y[i])
	return out


func net_radius() -> float:
	return rules.net_r


## True while this slot's charge mode is running: the Lancer laser, the Leech
## focused shot, Entrench or Breach. The Critical Break (17) reads it.
func is_charging(slot: int) -> bool:
	return _is_charging(slot)


## The ticks this slot's charge mode has run without a break, which is what
## the Critical Break's `cb_charge_min_ticks` is measured against.
func charge_ticks(slot: int) -> int:
	return _charge_ticks[slot]


func shooter_of(i: int) -> int:
	return field.target_array()[i]


func count() -> int:
	return field.count()


func state_hash() -> int:
	var h := field.state_hash()
	for s: int in range(MAX_SLOTS):
		h = (h ^ _fire[s]) * 1099511628211
		h = (h ^ _meter[s]) * 1099511628211
		h = (h ^ _stock[s]) * 1099511628211
		h = (h ^ _laser_ticks[s]) * 1099511628211
		h = (h ^ _ability[s]) * 1099511628211
		h = (h ^ _ability_timer[s]) * 1099511628211
	for i: int in range(_d_state.size()):
		h = (h ^ _d_state[i]) * 1099511628211
		h = (h ^ int(_d_x[i] * 16.0)) * 1099511628211
		h = (h ^ int(_d_y[i] * 16.0)) * 1099511628211
	return h
