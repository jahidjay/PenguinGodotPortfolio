class_name BulletField
extends RefCounted
## Node-free bullet pool. Implements design/gdd/bullet-manager.md per
## docs/architecture/adr-0001-gdscript-bullets-multimesh.md (Decisions 2, 3, 7).
##
## Bullets are rows in pre-allocated packed arrays, never Nodes. One
## PackedFloat32Array per component (no PackedVector2Array in the hot loop,
## ADR-0001 D2).
##
## Tick order (bullet-manager GDD): spawn > age > move > cancel > hit > remove.
## Cancel beats hit: a bullet cancelled this tick cannot also register a hit.
##
## Removal is deferred. Dead rows are flagged and compacted ONCE per tick
## (ADR-0001 D3), so the move and hit loops never resize an array.
##
## Fixed-step by design: the simulation advances in whole 60 Hz ticks and holds
## no `delta`. Designer values are authored per second in BulletRules and
## converted to per-tick once, in _init. This is what makes the sim
## frame-rate independent AND bit-deterministic for the replays required by
## ADR-0003 — a delta-driven loop would satisfy the first and break the second.
##
## All tuning comes from BulletRules (data/bullet_rules.tres); this file holds
## no gameplay constants.
##
## Scope: the hot path measured by the ADR-0001 V1 benchmark
## (tests/perf/bullet_bench.gd). GDD behaviour off that path — cancel->score
## items and their FIFO report, era shape swaps, per-emitter seeded streams —
## belongs to the Node adapter and is not implemented here.

## Behaviour buckets. Plain ints so the move loop branches on an integer
## instead of dispatching a Callable per bullet (ADR-0001 D3).
enum Beh {
	LINEAR,   ## constant velocity
	ACCEL,    ## gains speed along its heading, clamped
	CURVE,    ## turns at a fixed rate
	WARP,     ## flies, freezes, then re-aims at its target slot (F4)
}

const TICKS_PER_SECOND := 60.0

var rules: BulletRules
var capacity: int
var play_area: Rect2

# Per-tick values derived from `rules` once, so the hot loop stays arithmetic.
var _hit_radius: float
## Hit radius per shape index (bullet-manager F5). Indexed by `_shape[i]`.
var _shape_radius := PackedFloat32Array()
## Largest entry of `_shape_radius`, for the hit broad phase.
var _max_shape_radius: float
var _max_curve_per_tick: float
var _offscreen_margin: float
var _lifetime_ticks: int
var _accel_per_tick: float
var _max_accel_speed_per_tick: float
var _curve_cos: float
var _curve_sin: float
var _warp_freeze_ticks: int
var _warp_reaim_ticks: int
var _warp_speed_per_tick: float

## Live row count. Rows [0, _n) are live; the arrays stay at `capacity`.
var _n := 0
var _tick_index := 0

# Hot-loop state, one array per component.
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _age := PackedInt32Array()
var _beh := PackedInt32Array()
var _shape := PackedInt32Array()
var _dead := PackedInt32Array()  ## 1 = remove at the compaction step
## Slot the firing pattern aimed this bullet at (bullet-manager Rule 16), so a
## Warp bullet knows whom to re-aim at and VFX can colour by target.
var _target := PackedInt32Array()
## Damage this bullet carries. 0 for an enemy bullet, which is lethal by
## contact rather than by amount.
var _dmg := PackedInt32Array()
## Per-tick rotation for CURVE bullets, precomputed at spawn from the
## pattern's `spin` so the move loop never calls a trig function per bullet.
var _rot_c := PackedFloat32Array()
var _rot_s := PackedFloat32Array()
## Unit heading at spawn, kept for Warp: a frozen bullet has no velocity, so
## without this a bullet with nobody to re-aim at would have no direction left
## (bullet-manager Rule 17).
var _hx := PackedFloat32Array()
var _hy := PackedFloat32Array()

# Targets registered for this tick (slots 0..3).
var _tx := PackedFloat32Array()
var _ty := PackedFloat32Array()
var _tpx := PackedFloat32Array()
var _tpy := PackedFloat32Array()
var _tr := PackedFloat32Array()
var _thit := PackedInt32Array()  ## 1 = hittable this tick
## 1 = Alive this tick. Warp re-aims at an Alive player (bullet-manager
## Rule 17), which includes one who is invulnerable and therefore not hittable.
var _talive := PackedInt32Array()

# Pending cancel regions (bombs, laser, Breaker drones). Circles only.
var _cancel_x := PackedFloat32Array()
var _cancel_y := PackedFloat32Array()
var _cancel_r := PackedFloat32Array()
## Who asked for each region, and whether it pays score items. A cancel with
## `items` reports the position of every bullet it removed, which is what
## Powerups (13) turns into gems (bullet-manager Rule 14, powerups Rule 12).
var _cancel_cause := PackedInt32Array()
var _cancel_items := PackedInt32Array()
## A pending whole-field clear, which a bomb asks for at k = 0. -2 means no
## clear is pending; anything else is the cause slot.
var _clear_cause := -2
var _clear_items := false

## Longest per-axis step any bullet took this tick, for the hit broad phase.
var _max_step := 0.0
## Reused candidate list, so the broad phase allocates nothing per tick.
var _candidates := PackedInt32Array()

# Results, readable after tick().
## One entry per target hit this tick, in target order.
var player_hits := PackedInt32Array()
## How many bullets reached each registered target this tick, indexed by
## target. A player dies once however many bullets arrive, but an enemy takes
## damage per bullet, so the count has to survive the tick (Collision Phase A).
var hits_per_target := PackedInt32Array()
## One entry per BULLET that hit, parallel to [member hit_shooters]: which
## target it reached. `player_hits` lists each target once; this lists every
## impact, which is what damage and chain credit are counted from.
var hit_targets := PackedInt32Array()
## The slot stored on each bullet of [member hit_targets]. For a player shot
## that is its SHOOTER, so a kill pays the player who landed the hit.
var hit_shooters := PackedInt32Array()
var cancelled_this_tick := 0
var spawn_rejected := 0
## Positions of the bullets cancelled this tick by an `items` region, as x, y
## pairs in pool order. Parallel to [member cancel_causes], which holds the
## slot that caused each one. Read after tick(); cleared at the next tick.
var cancel_positions := PackedFloat32Array()
var cancel_causes := PackedInt32Array()
## One entry per cancel REGION resolved this tick, in request order: who asked
## and how many bullets that region removed. The Breaker reads its own entries
## at the start of the next tick to credit its stock (GDD 29 Rule 25).
var cancel_region_cause := PackedInt32Array()
var cancel_region_count := PackedInt32Array()
## The damage each bullet of [member hit_targets] carried. A player pool holds
## bullets of several strengths at once — a Breaker ram is 30, its Breach slug
## 40, a drone diamond 20 — so the damage travels on the bullet rather than
## being looked up from whatever mode the plane happens to be in now.
var hit_damage := PackedInt32Array()


## `p_rules` is required: there is no hardcoded fallback tuning.
func _init(p_rules: BulletRules, p_play_area: Rect2, p_capacity: int = 0) -> void:
	assert(p_rules != null, "BulletField needs a BulletRules (data/bullet_rules.tres)")
	rules = p_rules
	play_area = p_play_area
	capacity = p_capacity if p_capacity > 0 else p_rules.enemy_cap

	_hit_radius = p_rules.hit_radius
	_shape_radius = PackedFloat32Array(p_rules.shape_hit_radii)
	_max_shape_radius = p_rules.hit_radius
	for i: int in range(_shape_radius.size()):
		if _shape_radius[i] > _max_shape_radius:
			_max_shape_radius = _shape_radius[i]
	_max_curve_per_tick = absf(p_rules.max_curve_rate) / TICKS_PER_SECOND
	_offscreen_margin = p_rules.offscreen_margin
	_lifetime_ticks = p_rules.lifetime_ticks
	_accel_per_tick = p_rules.accel_rate_per_second / TICKS_PER_SECOND
	_max_accel_speed_per_tick = p_rules.max_accel_speed / TICKS_PER_SECOND
	# SimMath, not the platform cos/sin: this value feeds simulation state, and
	# libm differs between desktop and the wasm build (ADR-0003 Decision 3).
	var curve_per_tick := p_rules.curve_rate_per_second / TICKS_PER_SECOND
	var curve_bam := SimMath.rad_to_bam(curve_per_tick)
	_curve_cos = SimMath.cos_bam(curve_bam)
	_curve_sin = SimMath.sin_bam(curve_bam)
	# F4: integer tick thresholds, not a float age, so the frozen window is
	# the same length on every machine and never drifts by a tick.
	_warp_freeze_ticks = roundi(p_rules.warp_freeze_at * TICKS_PER_SECOND)
	_warp_reaim_ticks = roundi(p_rules.warp_reaim_at * TICKS_PER_SECOND)
	_warp_speed_per_tick = p_rules.warp_speed / TICKS_PER_SECOND

	_x.resize(capacity)
	_y.resize(capacity)
	_vx.resize(capacity)
	_vy.resize(capacity)
	_age.resize(capacity)
	_beh.resize(capacity)
	_shape.resize(capacity)
	_dead.resize(capacity)
	_target.resize(capacity)
	_dmg.resize(capacity)
	_rot_c.resize(capacity)
	_rot_s.resize(capacity)
	_hx.resize(capacity)
	_hy.resize(capacity)


func count() -> int:
	return _n


func tick_index() -> int:
	return _tick_index


func hit_radius() -> float:
	return _hit_radius


## Velocity is in pixels per SECOND (designer-facing) and converted on entry.
##
## `param` is the behaviour parameter (bullet-pattern-library Rule 4): the
## signed turn rate in rad/s for CURVE, ignored by the others. 0.0 means "use
## the default from BulletRules". `target_slot` is the slot the firing pattern
## aimed at (bullet-manager Rule 16); the bullet stores it and never reads the
## player again.
##
## Returns false when the pool is full. A refused request is NOT retried by
## the caller and does not change its timing (Pattern library Edge Cases):
## a refusal means the content is too dense, which the density validator is
## there to catch at authoring time.
func request_spawn(
	at_x: float,
	at_y: float,
	vel_x: float,
	vel_y: float,
	beh: int = Beh.LINEAR,
	shape: int = 0,
	param: float = 0.0,
	target_slot: int = 0,
	damage: int = 0,
) -> bool:
	if _n >= capacity:
		spawn_rejected += 1
		return false
	var i := _n
	_x[i] = at_x
	_y[i] = at_y
	_vx[i] = vel_x / TICKS_PER_SECOND
	_vy[i] = vel_y / TICKS_PER_SECOND
	_age[i] = 0
	_beh[i] = beh
	_shape[i] = shape
	_dead[i] = 0
	_target[i] = target_slot
	_dmg[i] = damage
	if beh == Beh.CURVE and param != 0.0:
		var per_tick := clampf(
			param / TICKS_PER_SECOND, -_max_curve_per_tick, _max_curve_per_tick
		)
		var a := SimMath.rad_to_bam(per_tick)
		_rot_c[i] = SimMath.cos_bam(a)
		_rot_s[i] = SimMath.sin_bam(a)
	else:
		_rot_c[i] = _curve_cos
		_rot_s[i] = _curve_sin
	# Stored heading `h` (Rule 17). Taken once, here, because a frozen Warp
	# bullet has a zero velocity to recover a direction from.
	var sp := sqrt(_vx[i] * _vx[i] + _vy[i] * _vy[i])
	if sp > 0.0:
		_hx[i] = _vx[i] / sp
		_hy[i] = _vy[i] / sp
	else:
		_hx[i] = 0.0
		_hy[i] = 1.0  # straight down: the only direction with no information
	_n += 1
	return true


## Register the player slots for this tick. `prev` drives the swept test so a
## fast bullet cannot tunnel through a hitbox between ticks.
func set_targets(
	xs: PackedFloat32Array,
	ys: PackedFloat32Array,
	prev_xs: PackedFloat32Array,
	prev_ys: PackedFloat32Array,
	radii: PackedFloat32Array,
	hittable: PackedInt32Array,
	alive: PackedInt32Array = PackedInt32Array(),
) -> void:
	_tx = xs
	_ty = ys
	_tpx = prev_xs
	_tpy = prev_ys
	_tr = radii
	_thit = hittable
	# Warp needs Alive, which is wider than hittable. A caller that has no
	# separate flags (the bench, the legacy path) gets hittable, which is the
	# conservative choice: it never re-aims at someone who is not in play.
	_talive = alive if alive.size() == PlaneCore.MAX_SLOTS else hittable


func request_cancel_circle(
	at_x: float, at_y: float, radius: float, cause_slot: int = -1, items: bool = false
) -> void:
	_cancel_x.append(at_x)
	_cancel_y.append(at_y)
	_cancel_r.append(radius)
	_cancel_cause.append(cause_slot)
	_cancel_items.append(1 if items else 0)


## Clears the enemy pool. With `items` every bullet removed is reported, which
## is how a bomb turns a curtain into gems (bullet-manager Rule 14); the death
## clear asks for it without items and pays nothing (Rule 15a).
##
## The clear is deferred to the cancel step so it happens BEFORE the hit pass
## (the deathbomb) and so the positions can be reported.
func request_clear_all(cause_slot: int = -1, items: bool = false) -> void:
	_clear_cause = cause_slot
	_clear_items = items


func tick() -> void:
	_tick_index += 1
	player_hits.clear()
	hit_targets.clear()
	hit_shooters.clear()
	hit_damage.clear()
	hits_per_target.resize(_tr.size())
	hits_per_target.fill(0)
	cancelled_this_tick = 0
	cancel_positions.clear()
	cancel_causes.clear()
	cancel_region_cause.clear()
	cancel_region_count.clear()

	_step_move()
	_step_cancel()
	_step_hit()
	_step_compact()


## age > move > bounds, in one pass over the live rows.
func _step_move() -> void:
	var n := _n
	var x := _x
	var y := _y
	var vx := _vx
	var vy := _vy
	var age := _age
	var beh := _beh
	var dead := _dead

	var margin := _offscreen_margin
	var min_x := play_area.position.x - margin
	var min_y := play_area.position.y - margin
	var max_x := play_area.end.x + margin
	var max_y := play_area.end.y + margin
	var max_age := _lifetime_ticks
	var accel := _accel_per_tick
	var max_speed := _max_accel_speed_per_tick
	var rot_c := _rot_c
	var rot_s := _rot_s
	var warp_freeze := _warp_freeze_ticks
	var warp_reaim := _warp_reaim_ticks
	var max_step := 0.0

	for i: int in range(n):
		var a := age[i] + 1
		age[i] = a

		var bvx := vx[i]
		var bvy := vy[i]
		var b := beh[i]
		if b == Beh.ACCEL:
			var s := 1.0 + accel
			bvx *= s
			bvy *= s
			var sp := sqrt(bvx * bvx + bvy * bvy)
			if sp > max_speed:
				var k := max_speed / sp
				bvx *= k
				bvy *= k
			vx[i] = bvx
			vy[i] = bvy
		elif b == Beh.CURVE:
			var rc := rot_c[i]
			var rs := rot_s[i]
			var nvx := bvx * rc - bvy * rs
			var nvy := bvx * rs + bvy * rc
			bvx = nvx
			bvy = nvy
			vx[i] = bvx
			vy[i] = bvy
		elif b == Beh.WARP:
			# F4: fly to T1, hold still to T2, then snap to the target once.
			if a > warp_reaim:
				if a == warp_reaim + 1:
					_reaim(i)
					bvx = vx[i]
					bvy = vy[i]
			elif a > warp_freeze:
				bvx = 0.0
				bvy = 0.0
				vx[i] = 0.0
				vy[i] = 0.0

		var step := absf(bvx)
		var step_y := absf(bvy)
		if step_y > step:
			step = step_y
		if step > max_step:
			max_step = step

		var cx := x[i] + bvx
		var cy := y[i] + bvy
		x[i] = cx
		y[i] = cy

		if a > max_age or cx < min_x or cx > max_x or cy < min_y or cy > max_y:
			dead[i] = 1
	_max_step = max_step


## One Warp bullet's re-aim (F4 step 3, Rule 17). Runs once per bullet, on the
## first tick past `warp_reaim_at`, so the per-bullet cost of the slot search
## is paid once in a bullet's life and never in the straight-line path.
func _reaim(i: int) -> void:
	var slot := _target[i]
	var alive := _talive
	var found := -1
	if slot >= 0 and slot < alive.size() and alive[slot] != 0:
		found = slot
	else:
		# Rule 17: the NEAREST Alive player, lowest slot index on a tie.
		var best := INF
		for s: int in range(alive.size()):
			if alive[s] == 0:
				continue
			var ddx := _tx[s] - _x[i]
			var ddy := _ty[s] - _y[i]
			var d2 := ddx * ddx + ddy * ddy
			if d2 < best:
				best = d2
				found = s
	var ux := _hx[i]
	var uy := _hy[i]
	if found >= 0:
		var dx := _tx[found] - _x[i]
		var dy := _ty[found] - _y[i]
		var d := sqrt(dx * dx + dy * dy)
		# Already on top of the target: there is no direction to snap to, so
		# it keeps the heading it arrived on.
		if d >= 1.0:
			ux = dx / d
			uy = dy / d
	_vx[i] = ux * _warp_speed_per_tick
	_vy[i] = uy * _warp_speed_per_tick


func _step_cancel() -> void:
	var regions := _cancel_r.size()
	if regions == 0 and _clear_cause == -2:
		return
	var n := _n
	var x := _x
	var y := _y
	var dead := _dead
	var shape := _shape
	var radii := _shape_radius
	var fallback := _hit_radius
	var cancelled := 0
	if _clear_cause != -2:
		for i: int in range(n):
			if dead[i] != 0:
				continue
			dead[i] = 1
			cancelled += 1
			if _clear_items:
				cancel_positions.append(
					clampf(x[i], play_area.position.x + 6.0, play_area.end.x - 6.0)
				)
				cancel_positions.append(
					clampf(y[i], play_area.position.y + 6.0, play_area.end.y - 6.0)
				)
				cancel_causes.append(_clear_cause)
		_clear_cause = -2
		_clear_items = false
	for r: int in range(regions):
		var rx := _cancel_x[r]
		var ry := _cancel_y[r]
		var base := _cancel_r[r]
		var pays_items := r < _cancel_items.size() and _cancel_items[r] != 0
		var cause := _cancel_cause[r] if r < _cancel_cause.size() else -1
		var in_region := 0
		for i: int in range(n):
			if dead[i] != 0:
				continue
			var si := shape[i]
			var rr := base + (radii[si] if si < radii.size() else fallback)
			var rr2 := rr * rr
			var dx := x[i] - rx
			var dy := y[i] - ry
			if dx * dx + dy * dy <= rr2:
				dead[i] = 1
				cancelled += 1
				in_region += 1
				if pays_items:
					# Inset-clamped, so a gem never spawns outside the field
					# (bullet-manager F9).
					cancel_positions.append(
						clampf(x[i], play_area.position.x + 6.0, play_area.end.x - 6.0)
					)
					cancel_positions.append(
						clampf(y[i], play_area.position.y + 6.0, play_area.end.y - 6.0)
					)
					cancel_causes.append(cause)
		cancel_region_cause.append(cause)
		cancel_region_count.append(in_region)
	cancelled_this_tick = cancelled
	_cancel_x.clear()
	_cancel_y.clear()
	_cancel_r.clear()
	_cancel_cause.clear()
	_cancel_items.clear()


## Swept circle test against every hittable slot. Both the bullet and the
## target move, so the bullet's segment is tested in the target's frame.
## Cancel beats hit: rows flagged by _step_cancel are skipped.
func _step_hit() -> void:
	var slots := _tr.size()
	if slots == 0:
		return
	var n := _n
	if n == 0:
		return
	var x := _x
	var y := _y
	var vx := _vx
	var vy := _vy
	var dead := _dead
	var shape := _shape
	var radii := _shape_radius
	var fallback := _hit_radius

	# Broad phase: one box around every hittable slot, grown by the largest
	# target radius, the bullet radius and the longest step any bullet took
	# this tick. A bullet outside it cannot have swept through any target, so
	# the expensive test runs only for the few candidates inside.
	# This is the cheap stand-in for the uniform grid in bullet-manager F11,
	# which pays off against many enemy hurtboxes rather than <=4 players.
	var any := false
	var box_min_x := 0.0
	var box_min_y := 0.0
	var box_max_x := 0.0
	var box_max_y := 0.0
	var max_reach := 0.0
	for s: int in range(slots):
		if _thit[s] == 0:
			continue
		var cx := _tx[s]
		var cy := _ty[s]
		var pcx := _tpx[s]
		var pcy := _tpy[s]
		var lo_x := minf(cx, pcx)
		var hi_x := maxf(cx, pcx)
		var lo_y := minf(cy, pcy)
		var hi_y := maxf(cy, pcy)
		if not any:
			box_min_x = lo_x
			box_max_x = hi_x
			box_min_y = lo_y
			box_max_y = hi_y
			any = true
		else:
			box_min_x = minf(box_min_x, lo_x)
			box_max_x = maxf(box_max_x, hi_x)
			box_min_y = minf(box_min_y, lo_y)
			box_max_y = maxf(box_max_y, hi_y)
		if _tr[s] > max_reach:
			max_reach = _tr[s]
	if not any:
		return

	var pad := max_reach + _max_shape_radius + _max_step
	box_min_x -= pad
	box_max_x += pad
	box_min_y -= pad
	box_max_y += pad

	var candidates := _candidates
	candidates.clear()
	for i: int in range(n):
		if dead[i] != 0:
			continue
		var bx := x[i]
		if bx < box_min_x or bx > box_max_x:
			continue
		var by := y[i]
		if by < box_min_y or by > box_max_y:
			continue
		candidates.append(i)

	var candidate_count := candidates.size()
	if candidate_count == 0:
		return

	for s: int in range(slots):
		if _thit[s] == 0:
			continue
		var target_radius := _tr[s]
		var t_cx := _tx[s]
		var t_cy := _ty[s]
		var t_px := _tpx[s]
		var t_py := _tpy[s]
		var hit_found := false
		for c: int in range(candidate_count):
			var i := candidates[c]
			if dead[i] != 0:
				continue
			var si := shape[i]
			var reach := target_radius + (radii[si] if si < radii.size() else fallback)
			var reach2 := reach * reach
			# Previous position is exactly the current one minus this tick's
			# velocity, so no prev-position arrays are stored.
			var cur_x := x[i]
			var cur_y := y[i]
			var sx := cur_x - vx[i] - t_px
			var sy := cur_y - vy[i] - t_py
			var ex := cur_x - t_cx
			var ey := cur_y - t_cy
			var dx := ex - sx
			var dy := ey - sy
			var closest2: float
			var len2 := dx * dx + dy * dy
			if len2 <= 0.000001:
				closest2 = sx * sx + sy * sy
			else:
				var t := -(sx * dx + sy * dy) / len2
				t = clampf(t, 0.0, 1.0)
				var qx := sx + dx * t
				var qy := sy + dy * t
				closest2 = qx * qx + qy * qy
			if closest2 <= reach2:
				dead[i] = 1
				hit_found = true
				hits_per_target[s] += 1
				hit_targets.append(s)
				hit_shooters.append(_target[i])
				hit_damage.append(_dmg[i])
		if hit_found:
			player_hits.append(s)


## Swap-with-last compaction, run once per tick (ADR-0001 D3).
func _step_compact() -> void:
	var n := _n
	var dead := _dead
	var i := 0
	while i < n:
		if dead[i] == 0:
			i += 1
			continue
		var last := n - 1
		if i != last:
			_x[i] = _x[last]
			_y[i] = _y[last]
			_vx[i] = _vx[last]
			_vy[i] = _vy[last]
			_age[i] = _age[last]
			_beh[i] = _beh[last]
			_shape[i] = _shape[last]
			_dead[i] = _dead[last]
			_target[i] = _target[last]
			_dmg[i] = _dmg[last]
			_rot_c[i] = _rot_c[last]
			_rot_s[i] = _rot_s[last]
			_hx[i] = _hx[last]
			_hy[i] = _hy[last]
		n = last
	_n = n


# Read-only access for the renderer (ADR-0001 D4: pack straight from these,
# one buffer assignment per pool).
func x_array() -> PackedFloat32Array:
	return _x


func y_array() -> PackedFloat32Array:
	return _y


func shape_array() -> PackedInt32Array:
	return _shape


func target_array() -> PackedInt32Array:
	return _target


func beh_array() -> PackedInt32Array:
	return _beh


func vx_array() -> PackedFloat32Array:
	return _vx


func vy_array() -> PackedFloat32Array:
	return _vy


func age_array() -> PackedInt32Array:
	return _age


## How many bullets reached target `i` this tick.
func hits_on(i: int) -> int:
	return hits_per_target[i] if i < hits_per_target.size() else 0


## Hit radius of one shape (bullet-manager F5). Falls back to `hit_radius` for
## a shape with no authored entry.
func radius_of_shape(shape: int) -> float:
	return _shape_radius[shape] if shape < _shape_radius.size() else _hit_radius


## Order-dependent hash of live state, for the determinism tests in ADR-0003.
func state_hash() -> int:
	var h := 1469598103934665603
	for i: int in range(_n):
		h = (h ^ int(_x[i] * 64.0)) * 1099511628211
		h = (h ^ int(_y[i] * 64.0)) * 1099511628211
		h = (h ^ _age[i]) * 1099511628211
	return h
