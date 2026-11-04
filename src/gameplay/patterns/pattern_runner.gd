class_name PatternRunner
extends RefCounted
## One [PatternDef] running on one [PatternEmitter]
## (design/gdd/bullet-pattern-library.md Rules 3-15, F2-F7).
##
## The runner holds ALL the runtime state — timer, burst progress, volley
## counter, spiral angle, lock data, lit flak fuses — so the pattern resource
## stays read-only and shareable (Rule 1). It only ever *requests* bullets; it
## keeps no bullet references (Rule 4).
##
## Integer ticks throughout (ADR-0001 D5) and [SimMath] binary angles
## (ADR-0003 D3): a spiral's angle comes from the integer volley counter, so it
## cannot drift, and two platforms compute the same bullet direction bit for
## bit.
##
## Two behaviours are easy to get wrong and are load-bearing for fairness:
##
## - **A skipped volley still draws its randomness** (Rule 8, Edge Cases,
##   AC-14). Fire hold, spawn safety and the flak fuse cap all suppress
##   bullets, never the random stream, so a pattern stays learnable: what the
##   players did never changes what the pattern does next.
## - **Spawn safety only removes bullets** (F7, Edge Cases). It never adds or
##   moves one, so a volley can get thinner but never more dangerous.
##
## States (GDD "States and Transitions"):
## [codeblock]
## Gated -> Waiting -> Firing -> Cooling -> (Locking) -> Firing -> ...
##   any -> Gated    (intensity left the range; unfinished burst dropped)
##   any -> Stopped  (the owner stopped the emitter; final)
## [/codeblock]

enum State { GATED, WAITING, FIRING, COOLING, LOCKING, STOPPED }

const TICKS_PER_SECOND := 60.0

var emitter: PatternEmitter
var def: PatternDef
## Index in the emitter's pattern list. Fixes the firing order within a tick.
var pattern_index := 0

var state := State.GATED

# Timing, clamped to the F1 minimums once here and never read raw again.
var _start_delay: int
var _burst_count: int
var _burst_gap: int
var _flak_delay: int
var _lock_ticks: int

# Angles converted from authored radians to binary angle units, once.
var _spread_bam: int
var _step_bam: int
var _angle_offset_bam: int
var _fixed_offset_bam: int
var _direction_bam: int
var _arc_bam: int

var _safe_radius: float
var _safe_radius_sq: float

# The F3 gate bounds, copied out of the resource at construction. The gate is
# checked for every runner on every tick, so it is the one formula kept as
# inline arithmetic here as well as in [PatternMetrics] (AC-53 budget).
# `test_pattern_gate_agrees_with_the_validator` pins the two copies together.
var _min_intensity: float
var _max_intensity: float

## Tick the gate last opened: `T_act` in F2.
var _act_tick := -1
## Tick of volley 0 of the current or next burst: `S[j]` in F2.
var _burst_start := -1
## Next volley index within the burst, 0 .. burst_count - 1.
var _volley_index := 0
## Every scheduled volley, skipped ones included: `c` in F2. Never reset, so
## the spiral angle and the radial-curve spin sign stay in step with the
## owner's movement and the music (Rule 8).
var _volley_counter := 0

## Read at the start of each burst and held for the whole burst (F3).
var _interval_eff := 1
var _count_eff := 1

## Aim for the current burst, in binary angle units (F5).
var _aim_bam := SimMath.QUARTER
## The point `_aim_bam` was taken towards: the live target, or `P_lock` for a
## locked burst. Flak measures its standoff from THIS point, not from the
## target's position now, so a locked shell bursts where it was aimed (F6f).
var _aim_x := 0.0
var _aim_y := 0.0
## Slot every bullet of the current burst stores (Rule 10).
var _target_slot := -1

# Aim lock (Rule 13, F5). Chosen at the lock tick for the NEXT burst, which
# may fall inside the current one, so it is staged separately.
var _lock_set := false
var _lock_slot := -1
var _lock_x := 0.0
var _lock_y := 0.0
var _lock_tell := false

# Lit flak fuses (F6f). Preallocated to the scene cap; never grows.
var _fuse_n := 0
var _fuse_tick := PackedInt32Array()
var _fuse_x := PackedFloat32Array()
var _fuse_y := PackedFloat32Array()
var _fuse_offset := PackedInt32Array()
var _fuse_slot := PackedInt32Array()
## `count_eff` at the tick the fuse was lit. Held per fuse so a burst fires the
## ring that was telegraphed, even if intensity changed during the fuse (F3:
## count is read at burst start and held).
var _fuse_count := PackedInt32Array()

## Reused buffer for the wall's valid gap starts, so a volley allocates
## nothing (F6d).
var _wall_valid := PackedInt32Array()

# The Active players this volley is spawn-checked against, latched once per
# volley instead of read back through the scene for every bullet (AC-53).
var _safe_n := 0
var _safe_x := PackedFloat32Array()
var _safe_y := PackedFloat32Array()
var _field


func _init(p_emitter: PatternEmitter, p_def: PatternDef, p_index: int, at_tick: int) -> void:
	assert(p_def != null, "PatternRunner needs a PatternDef")
	emitter = p_emitter
	def = p_def
	pattern_index = p_index

	_start_delay = PatternMetrics.clamp_start_delay(p_def.start_delay)
	_burst_count = PatternMetrics.clamp_burst_count(p_def.burst_count)
	_burst_gap = PatternMetrics.clamp_interval(p_def.burst_gap)
	_flak_delay = PatternMetrics.clamp_flak_delay(p_def.flak_delay)
	_lock_ticks = maxi(0, p_def.lock_ticks)
	_min_intensity = p_def.min_intensity - PatternMetrics.GATE_EPSILON
	_max_intensity = p_def.max_intensity + PatternMetrics.GATE_EPSILON

	# Authored radians -> binary angle units, at construction only.
	_spread_bam = SimMath.rad_to_bam(p_def.spread_rad)
	_step_bam = SimMath.rad_to_bam(p_def.step_rad)
	_angle_offset_bam = SimMath.rad_to_bam(p_def.angle_offset_rad)
	_fixed_offset_bam = SimMath.rad_to_bam(p_def.fixed_offset_rad)
	_direction_bam = SimMath.rad_to_bam(p_def.direction_rad)
	_arc_bam = SimMath.rad_to_bam(p_def.arc_rad)

	var rules := p_emitter.scene.rules
	_safe_radius = (
		p_def.spawn_safe_radius if p_def.spawn_safe_radius >= 0.0 else rules.spawn_safe_radius
	)
	_safe_radius_sq = _safe_radius * _safe_radius

	var cap := maxi(1, rules.flak_fuse_max)
	_fuse_tick.resize(cap)
	_fuse_x.resize(cap)
	_fuse_y.resize(cap)
	_fuse_offset.resize(cap)
	_fuse_slot.resize(cap)
	_fuse_count.resize(cap)

	# An emitter that starts with its gate already open activates here, so
	# `start_delay` is measured from the tick it was created (F2's T_act).
	if PatternMetrics.gate_open(p_def, p_emitter.intensity):
		_activate(at_tick)


## One 1/60 s step. `t` is the game tick index.
func tick(t: int) -> void:
	# Fuses first: one lit this tick is due at t + flak_delay, so it can never
	# burst on the tick it was lit. Guarded at the call site rather than inside:
	# with 120 runners on the field, a call that only early-returns is still
	# 120 calls a tick (AC-53 budget).
	if _fuse_n > 0:
		_service_fuses(t)

	if state == State.STOPPED:
		return

	# Inlined PatternMetrics.gate_open: `intensity` is already clamped to 0-1
	# by PatternEmitter.update.
	var intensity := emitter.intensity
	if intensity < _min_intensity or intensity > _max_intensity:
		if state != State.GATED:
			# Rule 7 / Edge Cases: the rest of the burst is dropped and the
			# next activation waits `start_delay` again.
			_end_lock(false)
			state = State.GATED
		return

	if state == State.GATED:
		_activate(t)

	emitter.scene.active_runners += 1

	if t == _burst_start + _volley_index * _burst_gap:
		_fire_volley(t)

	# After the volley, because a burst that just ended has already advanced
	# `_burst_start` to the burst this lock belongs to. Most patterns have no
	# lock, so the test is here and not inside the call.
	if _lock_ticks > 0:
		_maybe_begin_lock(t)


func _activate(t: int) -> void:
	_act_tick = t
	_burst_start = t + _start_delay
	_volley_index = 0
	state = State.WAITING
	# F5: a lock that would have started before activation is sampled now.
	if _lock_ticks > 0:
		_maybe_begin_lock(t)


func _maybe_begin_lock(t: int) -> void:
	if _lock_ticks <= 0 or _lock_set or state == State.STOPPED:
		return
	var lock_tick := maxi(_burst_start - _lock_ticks, _act_tick)
	if t != lock_tick:
		return
	_lock_set = true
	_lock_slot = emitter.advance_target()
	if _lock_slot < 0:
		# Nobody Alive: no tell, and the burst will fire straight down with
		# slot 0 (Rule 11, Edge Cases).
		_lock_tell = false
		return
	_lock_x = emitter.scene.slot_x(_lock_slot)
	_lock_y = emitter.scene.slot_y(_lock_slot)
	_lock_tell = true
	state = State.LOCKING
	emitter.scene._append_event(TickEventLog.Kind.PATTERN_LOCK_STARTED, _lock_slot, emitter.owner_id)


func _end_lock(fired: bool) -> void:
	if _lock_tell:
		emitter.scene._append_event(
			TickEventLog.Kind.PATTERN_LOCK_ENDED, _lock_slot, 1 if fired else 0
		)
		_lock_tell = false
	_lock_set = false
	_lock_slot = -1


func _fire_volley(t: int) -> void:
	var scene := emitter.scene
	var held := scene.fire_hold
	# Latched for the whole volley: every bullet of it is checked against the
	# same players and goes to the same field.
	_safe_n = scene.active_count
	_safe_x = scene.active_x
	_safe_y = scene.active_y
	_field = scene.field

	if _volley_index == 0:
		# F3: interval and count are read ONCE per burst and held.
		_interval_eff = PatternMetrics.interval_with_overlap_fallback(
			def, PatternMetrics.interval_eff(def, emitter.intensity)
		)
		_count_eff = PatternMetrics.count_eff(def, emitter.intensity)

		if _lock_ticks > 0:
			if not _lock_set:
				# The gate opened past this burst's lock tick: sample now.
				_lock_set = true
				_lock_slot = emitter.advance_target()
				if _lock_slot >= 0:
					_lock_x = scene.slot_x(_lock_slot)
					_lock_y = scene.slot_y(_lock_slot)
			_target_slot = _lock_slot
			if _lock_slot >= 0:
				_aim_from_point(_lock_x, _lock_y)
			else:
				_aim_bam = SimMath.QUARTER
				_aim_x = emitter.origin.x
				_aim_y = emitter.origin.y + 1.0
			_end_lock(not held)
		else:
			_target_slot = emitter.advance_target()
			_aim_at_target()
	elif def.reaim_each_volley:
		# F5: same target, live position. If it is no longer Alive, the burst
		# keeps its last aim.
		_aim_at_target()

	var spawned := _emit_geometry(t, held)

	_volley_counter += 1
	if held:
		scene.volleys_skipped += 1
	elif spawned > 0:
		scene.volleys_fired += 1
		scene.total_volleys_fired += 1
		scene._append_event(
			TickEventLog.Kind.PATTERN_VOLLEY_FIRED, maxi(_target_slot, 0), emitter.owner_id
		)

	_volley_index += 1
	if _volley_index >= _burst_count:
		_volley_index = 0
		_burst_start += _interval_eff
		state = State.COOLING
	else:
		state = State.FIRING


# --- aim ---------------------------------------------------------------------

func _aim_at_target() -> void:
	if _target_slot < 0:
		_aim_bam = SimMath.QUARTER  # Rule 11: straight down
		_aim_x = emitter.origin.x
		_aim_y = emitter.origin.y + 1.0
		return
	if not emitter.scene.is_alive(_target_slot):
		return  # keep the last aim (F5)
	_aim_from_point(emitter.scene.slot_x(_target_slot), emitter.scene.slot_y(_target_slot))


func _aim_from_point(px: float, py: float) -> void:
	_aim_x = px
	_aim_y = py
	var dx := px - emitter.origin.x
	var dy := py - emitter.origin.y
	# F5 / AC-25: under half a pixel there is no meaningful direction, so the
	# volley fires straight down instead of snapping to a rounding artefact.
	if SimMath.length(dx, dy) < 0.5:
		_aim_bam = SimMath.QUARTER
	else:
		_aim_bam = SimMath.atan2_bam(dy, dx)


## Slot stored on every bullet. Rule 11: with nobody Alive, bullets store 0.
func _bullet_slot() -> int:
	return _target_slot if _target_slot >= 0 else 0


# --- geometry (F6) -----------------------------------------------------------

## Fires one volley's geometry. Returns how many bullets actually spawned.
## `held` suppresses spawning but NEVER the random draws (Rule 8).
func _emit_geometry(t: int, held: bool) -> int:
	match def.kind:
		PatternDef.Kind.AIMED_FAN:
			return _emit_fan(held)
		PatternDef.Kind.RING:
			return _emit_ring(
				emitter.origin.x, emitter.origin.y, _draw_ring_offset(), _count_eff, held
			)
		PatternDef.Kind.SPIRAL:
			return _emit_spiral(held)
		PatternDef.Kind.WALL:
			return _emit_wall(held)
		PatternDef.Kind.RADIAL_CURVE:
			return _emit_radial_curve(held)
		PatternDef.Kind.FLAK_BURST:
			return _emit_flak(t, held)
		PatternDef.Kind.SPRAY:
			return _emit_spray(held)
	return 0


## F6a: `angle[i] = theta + (i - (n-1)/2) * spread`.
func _emit_fan(held: bool) -> int:
	var n := _count_eff
	var spawned := 0
	for i: int in range(n):
		spawned += _spawn(
			emitter.origin.x,
			emitter.origin.y,
			PatternMetrics.fan_angle_bam(i, n, _aim_bam, _spread_bam),
			def.speed,
			0.0,
			held
		)
	return spawned


## F6b. The offset is drawn by the caller so a flak fuse can draw it at the
## volley tick and use it at the burst tick.
func _draw_ring_offset() -> int:
	if def.offset_mode == PatternDef.OffsetMode.FIXED:
		return _fixed_offset_bam  # no draw: a fixed ring never varies
	return PatternMetrics.ring_offset_bam(emitter.rng.randf(), _count_eff)


func _emit_ring(at_x: float, at_y: float, offset: int, count: int, held: bool) -> int:
	var n := maxi(1, count)
	var spawned := 0
	for i: int in range(n):
		spawned += _spawn(
			at_x,
			at_y,
			PatternMetrics.ring_angle_bam(i, n, offset),
			def.speed,
			0.0,
			held
		)
	return spawned


## F6c: `phi(c) = angle_offset + c * step`, from the integer volley counter.
func _emit_spiral(held: bool) -> int:
	var arms := maxi(1, def.arms)
	var spawned := 0
	for i: int in range(arms):
		spawned += _spawn(
			emitter.origin.x,
			emitter.origin.y,
			PatternMetrics.spiral_angle_bam(
				_angle_offset_bam, _volley_counter, _step_bam, i, arms
			),
			def.speed,
			0.0,
			held
		)
	return spawned


## F6d: a line of slots with one gap, placed inside the screen edges.
func _emit_wall(held: bool) -> int:
	var rules := emitter.scene.rules
	var n := maxi(3, _count_eff)
	var g := maxi(1, def.gap_width)
	var m := maxi(1, def.edge_slots)
	var e := rules.wall_edge_margin
	var ox := emitter.origin.x
	var sp := def.spacing

	var lo := m
	var hi := n - g - m
	_wall_valid.clear()
	for gs: int in range(lo, hi + 1):
		# The slots either side of the gap must both be on screen, so bullets
		# always bound the corridor the player aims for.
		if (
			PatternMetrics.wall_slot_x(gs - 1, n, ox, sp) >= e
			and PatternMetrics.wall_slot_x(gs + g, n, ox, sp) <= rules.canvas_width - e
		):
			_wall_valid.push_back(gs)

	# The draw ALWAYS happens, even when there is nothing to choose, so the
	# stream stays stable (F6d, Edge Cases).
	var gap_start := PatternMetrics.wall_gap_choice(emitter.rng.randf(), _wall_valid)
	if gap_start < 0:
		# No valid gap fits: the in-range slot whose gap CENTRE is nearest the
		# middle of the screen.
		var mid := rules.canvas_width * 0.5
		gap_start = lo
		var best := INF
		for gs: int in range(lo, maxi(lo, hi) + 1):
			var centre_x := (
				PatternMetrics.wall_slot_x(gs, n, ox, sp) + float(g - 1) * 0.5 * sp
			)
			var d := absf(centre_x - mid)
			if d < best:
				best = d
				gap_start = gs

	var spawned := 0
	for i: int in range(n):
		if i >= gap_start and i < gap_start + g:
			continue
		spawned += _spawn(
			PatternMetrics.wall_slot_x(i, n, ox, sp),
			emitter.origin.y,
			_direction_bam,
			def.speed,
			0.0,
			held
		)
	return spawned


## F6e: outward from the body centre through the origin, spin alternating.
##
## The GDD specifies one outward direction and says nothing about `count` for
## this kind. With `count` 1 (the documented case) this fires that single
## outward bullet; a higher count spreads evenly round the turn from `out`, so
## the pattern degrades into a curving ring rather than stacking bullets on top
## of each other. Flagged for the owner in the session log.
func _emit_radial_curve(held: bool) -> int:
	var dx := emitter.origin.x - emitter.centre.x
	var dy := emitter.origin.y - emitter.centre.y
	var out := SimMath.QUARTER if SimMath.length(dx, dy) < 0.5 else SimMath.atan2_bam(dy, dx)
	# Skipped volleys still flip the sign (F6e), because the counter advances.
	var param := def.spin if _volley_counter % 2 == 0 else -def.spin
	var n := maxi(1, _count_eff)
	var spawned := 0
	for i: int in range(n):
		spawned += _spawn(
			emitter.origin.x,
			emitter.origin.y,
			PatternMetrics.ring_angle_bam(i, n, out),
			def.speed,
			param,
			held
		)
	return spawned


## F6f: light a fuse out along the aim. No bullets spawn now; the ring spawns
## `flak_delay` ticks later, and spawn safety is checked then, against the
## players' positions on THAT tick.
func _emit_flak(t: int, held: bool) -> int:
	var scene := emitter.scene
	var rules := scene.rules
	var ox := emitter.origin.x
	var oy := emitter.origin.y

	# F6f measures from the AIM point, which is the locked point for a locked
	# pattern and the target's live position otherwise.
	var tx := _aim_x
	var ty := _aim_y

	var dist := SimMath.length(tx - ox, ty - oy)
	var d := clampf(dist - def.standoff, 0.0, def.flak_distance)
	var bx := ox + SimMath.cos_bam(_aim_bam) * d
	var by := oy + SimMath.sin_bam(_aim_bam) * d

	var inset := rules.flak_clamp_inset
	bx = clampf(bx, inset, rules.canvas_width - inset)
	by = clampf(by, scene.play_top + inset, rules.canvas_height - inset)
	# Step 4: too close after the clamp means the shell would burst in the
	# player's lap, so it bursts at the gun instead.
	if SimMath.length(bx - tx, by - ty) < def.standoff:
		bx = ox
		by = oy

	# The ring's offset is drawn NOW, at the volley tick, whether or not the
	# fuse is actually lit.
	var offset := _draw_ring_offset()

	if held or not scene.can_light_fuse() or _fuse_n >= _fuse_tick.size():
		return 0  # counts as fired; no fuse, no sound (Rule 8, fuse cap)

	var i := _fuse_n
	_fuse_tick[i] = t + _flak_delay
	_fuse_x[i] = bx
	_fuse_y[i] = by
	_fuse_offset[i] = offset
	_fuse_slot[i] = _bullet_slot()
	_fuse_count[i] = _count_eff
	_fuse_n += 1
	scene.lit_fuses += 1
	scene._append_event(TickEventLog.Kind.PATTERN_FLAK_FUSE, _bullet_slot(), _flak_delay)
	# A lit fuse is the tell; `volley_fired` is sent for it (GDD "Flak timing").
	return 1


## F6g: evenly spaced inside the arc, with bounded jitter so lanes stay open.
func _emit_spray(held: bool) -> int:
	var n := maxi(1, _count_eff)
	var base := _aim_bam - _arc_bam / 2
	var spawned := 0
	for i: int in range(n):
		# Fixed draw order per bullet: angle, then speed (F6g).
		var u := emitter.rng.randf()
		var u_speed := emitter.rng.randf()
		spawned += _spawn(
			emitter.origin.x,
			emitter.origin.y,
			PatternMetrics.spray_angle_bam(i, n, u, _arc_bam, base, def.jitter),
			PatternMetrics.spray_speed(u_speed, def.speed_min, def.speed_max),
			0.0,
			held
		)
	return spawned


# --- fuses -------------------------------------------------------------------

func _service_fuses(t: int) -> void:
	if _fuse_n == 0:
		return
	var scene := emitter.scene
	var i := 0
	while i < _fuse_n:
		if _fuse_tick[i] != t:
			i += 1
			continue
		# A fuse that runs out during a fire hold is used up and does NOT fire
		# late (Edge Cases).
		if not scene.fire_hold:
			# The ring spawns on THIS tick, so it is checked against the
			# players as they are now (GDD "Flak timing").
			_safe_n = scene.active_count
			_safe_x = scene.active_x
			_safe_y = scene.active_y
			_field = scene.field
			var keep_slot := _target_slot
			_target_slot = _fuse_slot[i]
			var spawned := _emit_ring(
				_fuse_x[i], _fuse_y[i], _fuse_offset[i], _fuse_count[i], false
			)
			_target_slot = keep_slot
			if spawned > 0:
				scene._append_event(
					TickEventLog.Kind.PATTERN_FLAK_BURST, _fuse_slot[i], emitter.owner_id
				)
		_remove_fuse(i)


func _remove_fuse(i: int) -> void:
	var last := _fuse_n - 1
	if i != last:
		_fuse_tick[i] = _fuse_tick[last]
		_fuse_x[i] = _fuse_x[last]
		_fuse_y[i] = _fuse_y[last]
		_fuse_offset[i] = _fuse_offset[last]
		_fuse_slot[i] = _fuse_slot[last]
		_fuse_count[i] = _fuse_count[last]
	_fuse_n = last
	emitter.scene.lit_fuses = maxi(0, emitter.scene.lit_fuses - 1)


func pending_fuses() -> int:
	return _fuse_n


## Where fuse `i` will burst, and the tick it bursts on. VFX (25) draws the
## fuse marker from these: a flak ring that appears with no warning is the
## single most unfair thing this library can do, and the marker is the
## warning (GDD V3).
func fuse_position(i: int) -> Vector2:
	return Vector2(_fuse_x[i], _fuse_y[i])


func fuse_due_tick(i: int) -> int:
	return _fuse_tick[i]


# --- spawning ----------------------------------------------------------------

## One bullet request, with F7 spawn safety. Returns 1 if it spawned.
func _spawn(
	at_x: float, at_y: float, angle_bam: int, speed: float, param: float, held: bool
) -> int:
	if held:
		return 0
	# Only ACTIVE players are protected: a plane flying in or dead is
	# invulnerable anyway (Rule 14, Edge Cases). The list was compacted by the
	# scene and latched at the start of the volley, because this loop runs
	# once per bullet per player.
	var px := _safe_x
	var py := _safe_y
	for s: int in range(_safe_n):
		var dx := at_x - px[s]
		var dy := at_y - py[s]
		if dx * dx + dy * dy < _safe_radius_sq:
			var scene := emitter.scene
			scene.spawn_safety_skips += 1
			scene.total_spawn_safety_skips += 1
			return 0
	var vx := SimMath.cos_bam(angle_bam) * speed
	var vy := SimMath.sin_bam(angle_bam) * speed
	var ok: bool = _field.request_spawn(
		at_x, at_y, vx, vy, def.behaviour, def.shape, param, _bullet_slot()
	)
	return 1 if ok else 0


# --- lifecycle ---------------------------------------------------------------

## Final. `destroyed` true also cancels lit fuses: a dead gun fires nothing.
func stop(destroyed: bool) -> void:
	if state == State.STOPPED:
		return
	_end_lock(false)
	state = State.STOPPED
	if destroyed:
		while _fuse_n > 0:
			_remove_fuse(_fuse_n - 1)


## Breaks the link back to the emitter so the runner can be freed.
##
## [PatternScene] -> [PatternEmitter] -> [PatternRunner] -> emitter is a
## reference CYCLE, and a cycle of RefCounted objects is never collected: left
## alone, every enemy that ever fired would stay in memory for the whole
## session (AC-55 allocation). The scene calls this the moment it drops an
## emitter. Final: a disposed runner is never ticked again.
func dispose() -> void:
	state = State.STOPPED
	emitter = null
	def = null


## Ticks until this runner's next volley, or -1 if none is scheduled.
func next_volley_in(t: int) -> int:
	if state == State.STOPPED or state == State.GATED:
		return -1
	return maxi(0, _burst_start + _volley_index * _burst_gap - t)


func volley_counter() -> int:
	return _volley_counter


func target_slot() -> int:
	return _target_slot


func aim_bam() -> int:
	return _aim_bam


func count_effective() -> int:
	return _count_eff


func interval_effective() -> int:
	return _interval_eff


func is_locking() -> bool:
	return _lock_tell


func hash_into(ctx: HashingContext) -> void:
	SimHash.add_int(ctx, state)
	SimHash.add_int(ctx, _act_tick)
	SimHash.add_int(ctx, _burst_start)
	SimHash.add_int(ctx, _volley_index)
	SimHash.add_int(ctx, _volley_counter)
	SimHash.add_int(ctx, _interval_eff)
	SimHash.add_int(ctx, _count_eff)
	SimHash.add_int(ctx, _aim_bam)
	SimHash.add_int(ctx, _target_slot)
	SimHash.add_bool(ctx, _lock_set)
	SimHash.add_int(ctx, _lock_slot)
	SimHash.add_int(ctx, _fuse_n)
	SimHash.add_i32_prefix(ctx, _fuse_tick, _fuse_n)
	SimHash.add_f32_prefix(ctx, _fuse_x, _fuse_n)
	SimHash.add_f32_prefix(ctx, _fuse_y, _fuse_n)
	SimHash.add_i32_prefix(ctx, _fuse_offset, _fuse_n)
	SimHash.add_i32_prefix(ctx, _fuse_count, _fuse_n)
	SimHash.add_i32_prefix(ctx, _fuse_slot, _fuse_n)
