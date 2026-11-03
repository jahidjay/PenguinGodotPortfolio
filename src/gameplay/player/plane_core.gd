class_name PlaneCore
extends RefCounted
## Node-free player-plane logic for all four local co-op slots.
## Implements design/gdd/player-plane.md and the slot lifecycle of
## design/gdd/collision-damage-lives.md. Runs at step 2 of ADR-0002's tick.
##
## One instance owns all four slots rather than four instances of a
## single-slot class. The tick order calls this "PlaneCore[0..3].tick()"; a
## single multi-slot core satisfies that step, keeps the per-slot state in
## packed arrays, and hands the collision referee its target arrays without
## gathering from four objects every tick.
##
## Holds no scene-tree access and no gameplay constants: movement comes from
## SimInput, tuning from PlaneRules. A thin Node adapter draws it.
##
## Co-op: planes pass through each other (player-plane GDD) — there is no
## plane-vs-plane collision here by design.
##
## Usage:
## [codeblock]
## var cores := PlaneCore.new(load("res://data/plane_rules.tres"), play_area, log)
## cores.join(0)                      # slot 0 enters the run
## cores.set_player_count(2)          # picks the 48 vs 72 px HUD strip
##
## # each tick, step 2
## cores.tick(sim_input)
##
## # step 5: hand the referee this tick's swept-test targets
## field.set_targets(cores.xs(), cores.ys(), cores.prev_xs(), cores.prev_ys(),
##     cores.radii(), cores.hittable_flags())
## [/codeblock]

const MAX_SLOTS := 4

## Slot lifecycle. A slot not in the run is EMPTY; GAME_OVER is terminal until
## a continue is accepted.
enum State {
	EMPTY,
	FLY_IN,
	ACTIVE,
	DEAD,
	GAME_OVER,
}

var rules: PlaneRules
var play_area: Rect2
var _log: TickEventLog

# Per-slot state, one array per component (no per-slot objects in the tick).
var _state := PackedInt32Array()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _prev_x := PackedFloat32Array()
var _prev_y := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _hittable := PackedInt32Array()
var _alive_flags := PackedInt32Array()
var _active_flags := PackedInt32Array()
var _invuln := PackedInt32Array()
var _phase := PackedInt32Array()   ## ticks left in FLY_IN or DEAD
var _lives := PackedInt32Array()
var _focus := PackedInt32Array()   ## 1 while the focus input is held

# Per-tick values derived from `rules` once.
var _move_per_tick: float
var _focus_per_tick: float
var _min_x: float
var _max_x: float
var _min_y: float
var _max_y: float

var _player_count := 1


func _init(p_rules: PlaneRules, p_play_area: Rect2, p_log: TickEventLog) -> void:
	assert(p_rules != null, "PlaneCore needs a PlaneRules (data/plane_rules.tres)")
	rules = p_rules
	play_area = p_play_area
	_log = p_log

	_move_per_tick = p_rules.move_speed / 60.0
	_focus_per_tick = p_rules.focus_speed / 60.0

	_state.resize(MAX_SLOTS)
	_x.resize(MAX_SLOTS)
	_y.resize(MAX_SLOTS)
	_prev_x.resize(MAX_SLOTS)
	_prev_y.resize(MAX_SLOTS)
	_radius.resize(MAX_SLOTS)
	_hittable.resize(MAX_SLOTS)
	_alive_flags.resize(MAX_SLOTS)
	_active_flags.resize(MAX_SLOTS)
	_invuln.resize(MAX_SLOTS)
	_phase.resize(MAX_SLOTS)
	_lives.resize(MAX_SLOTS)
	_focus.resize(MAX_SLOTS)

	for s: int in range(MAX_SLOTS):
		_state[s] = State.EMPTY
		_radius[s] = p_rules.hitbox_radius
		_hittable[s] = 0
		_lives[s] = 0

	set_player_count(1)


## Picks the reserved HUD strip (48 px for 1-2 players, 72 for 3-4) and so the
## top of the flyable area. The director latches this at wave/stage start.
func set_player_count(count: int) -> void:
	_player_count = clampi(count, 1, MAX_SLOTS)
	var strip := rules.hud_strip_1p if _player_count <= 2 else rules.hud_strip_coop
	_min_x = play_area.position.x + rules.edge_margin
	_max_x = play_area.end.x - rules.edge_margin
	_min_y = play_area.position.y + strip + rules.top_padding
	_max_y = play_area.end.y - rules.bottom_margin


## Brings `slot` into the run at its column start spot (player-plane GDD) and
## starts its fly-in. Idempotent for a slot already in the run.
func join(slot: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	if _state[slot] != State.EMPTY:
		return
	_lives[slot] = rules.starting_lives
	_log.append(TickEventLog.Kind.SLOT_JOINED, slot, _lives[slot])
	_begin_fly_in(slot)


func _begin_fly_in(slot: int) -> void:
	# Column start spots: the field is split into one column per joined player
	# so planes do not fly in on top of each other.
	var columns := maxi(_player_count, 1)
	var column_width := (_max_x - _min_x) / float(columns)
	var index := mini(slot, columns - 1)
	_x[slot] = _min_x + column_width * (float(index) + 0.5)
	_y[slot] = play_area.end.y + rules.fly_in_from_below
	_prev_x[slot] = _x[slot]
	_prev_y[slot] = _y[slot]
	_state[slot] = State.FLY_IN
	_phase[slot] = rules.fly_in_ticks
	_hittable[slot] = 0
	_focus[slot] = 0
	_log.append(TickEventLog.Kind.PLANE_FLY_IN_STARTED, slot, _phase[slot])


## Step 2 of the tick. `input` supplies one SimInput row per slot.
func tick(input: SimInput) -> void:
	for s: int in range(MAX_SLOTS):
		_prev_x[s] = _x[s]
		_prev_y[s] = _y[s]

		if _invuln[s] > 0:
			_invuln[s] -= 1

		var state := _state[s]
		# Rule 10 / Input Rule 18: a plane that is not Active owns no
		# buffered press. Without this a Drone press made during the death
		# hold would fire the moment control returned, which the player did
		# not ask for.
		if state != State.ACTIVE:
			input.clear_buffer(s)

		if state == State.EMPTY or state == State.GAME_OVER:
			_hittable[s] = 0
			continue

		if state == State.DEAD:
			_tick_dead(s)
			continue

		if state == State.FLY_IN:
			_tick_fly_in(s)
			continue

		_tick_active(s, input)


func _tick_dead(slot: int) -> void:
	_hittable[slot] = 0
	_phase[slot] -= 1
	if _phase[slot] > 0:
		return
	if _lives[slot] <= 0:
		_state[slot] = State.GAME_OVER
		_log.append(TickEventLog.Kind.GAME_OVER, slot, 0)
		return
	_begin_fly_in(slot)


## The plane rises from below the bottom edge to its resting spot. Not
## targetable during the fly-in (player-plane GDD: FlyIn is not hittable).
func _tick_fly_in(slot: int) -> void:
	_hittable[slot] = 0
	var total := maxi(rules.fly_in_ticks, 1)
	_phase[slot] -= 1
	var done := float(total - _phase[slot]) / float(total)
	var from_y := play_area.end.y + rules.fly_in_from_below
	var to_y := play_area.end.y - rules.start_from_bottom
	_y[slot] = from_y + (to_y - from_y) * clampf(done, 0.0, 1.0)
	if _phase[slot] > 0:
		return
	_y[slot] = to_y
	_state[slot] = State.ACTIVE
	_invuln[slot] = maxi(_invuln[slot], rules.respawn_invuln_ticks)
	_hittable[slot] = 1
	_log.append(TickEventLog.Kind.PLANE_ACTIVATED, slot, _invuln[slot])
	_log.append(TickEventLog.Kind.PLAYER_RESPAWNED, slot, _lives[slot])


## 8-way digital movement, no inertia. Diagonals are normalised so a diagonal
## is not faster than a cardinal (player-plane GDD).
func _tick_active(slot: int, input: SimInput) -> void:
	_hittable[slot] = 1
	var focus := input.focus_held(slot)
	_focus[slot] = 1 if focus else 0
	var speed := _focus_per_tick if focus else _move_per_tick

	var dx := float(input.move_x(slot))
	var dy := float(input.move_y(slot))
	if dx != 0.0 and dy != 0.0:
		# 1/sqrt(2), applied so diagonal travel matches cardinal travel.
		const DIAGONAL := 0.70710678
		dx *= DIAGONAL
		dy *= DIAGONAL

	_x[slot] = clampf(_x[slot] + dx * speed, _min_x, _max_x)
	_y[slot] = clampf(_y[slot] + dy * speed, _min_y, _max_y)


## Called by the collision referee at step 6 when a bullet or body reaches this
## slot. Clears the plane, spends a life and starts the death hold.
## Ignored while the slot is invulnerable or already down.
func kill(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	if _state[slot] != State.ACTIVE:
		return false
	if _invuln[slot] > 0:
		return false
	_lives[slot] -= 1
	_state[slot] = State.DEAD
	_phase[slot] = rules.death_hold_ticks
	_hittable[slot] = 0
	_focus[slot] = 0
	_log.append(TickEventLog.Kind.PLAYER_DIED, slot, _lives[slot])
	_log.append(TickEventLog.Kind.LIFE_LOST, slot, _lives[slot])
	return true


## A 1-up (powerups-and-drops.md Rule 22). Returns false when the slot was
## already at `max_lives`, which is what makes the pickup pay a medal instead.
## A slot not in the run gains nothing.
func add_life(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS or not is_in_run(slot):
		return false
	if _lives[slot] >= rules.max_lives:
		return false
	_lives[slot] += 1
	_log.append(TickEventLog.Kind.EXTEND_AWARDED, slot, _lives[slot])
	return true


## Grants invulnerability for at least `ticks` (collision GDD: one timer per
## slot, requests take the maximum, every tick counts).
func request_invuln(slot: int, ticks: int) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	_invuln[slot] = maxi(_invuln[slot], ticks)


# --- reads -------------------------------------------------------------------

func state_of(slot: int) -> int:
	return _state[slot]


func is_active(slot: int) -> bool:
	return _state[slot] == State.ACTIVE


func is_in_run(slot: int) -> bool:
	var s := _state[slot]
	return s != State.EMPTY and s != State.GAME_OVER


func lives_of(slot: int) -> int:
	return _lives[slot]


func invuln_of(slot: int) -> int:
	return _invuln[slot]


func is_focusing(slot: int) -> bool:
	return _focus[slot] == 1


func position_of(slot: int) -> Vector2:
	return Vector2(_x[slot], _y[slot])


func active_count() -> int:
	var n := 0
	for s: int in range(MAX_SLOTS):
		if _state[s] == State.ACTIVE:
			n += 1
	return n


## True once every slot that joined has run out of lives.
func all_out() -> bool:
	var joined := false
	for s: int in range(MAX_SLOTS):
		if _state[s] == State.EMPTY:
			continue
		joined = true
		if _state[s] != State.GAME_OVER:
			return false
	return joined


# Target arrays handed straight to BulletField.set_targets and the collision
# referee. Returned by reference: callers must not mutate them.
func xs() -> PackedFloat32Array:
	return _x


func ys() -> PackedFloat32Array:
	return _y


func prev_xs() -> PackedFloat32Array:
	return _prev_x


func prev_ys() -> PackedFloat32Array:
	return _prev_y


func radii() -> PackedFloat32Array:
	return _radius


## 1 per slot the pattern library may TARGET (bullet-pattern-library Rule 10,
## F4): a plane flying in after a respawn is Alive and can be aimed at, even
## though it cannot be hit yet.
func alive_flags() -> PackedInt32Array:
	for s: int in range(MAX_SLOTS):
		_alive_flags[s] = 1 if (_state[s] == State.FLY_IN or _state[s] == State.ACTIVE) else 0
	return _alive_flags


## 1 per slot spawn safety protects (bullet-pattern-library Rule 14, F7):
## ACTIVE only. A plane in FLY_IN or DEAD is invulnerable anyway, so a bullet
## is allowed to spawn on it.
func active_flags() -> PackedInt32Array:
	for s: int in range(MAX_SLOTS):
		_active_flags[s] = 1 if _state[s] == State.ACTIVE else 0
	return _active_flags


## 1 per slot that may be hit this tick: ACTIVE and not invulnerable.
func hittable_flags() -> PackedInt32Array:
	for s: int in range(MAX_SLOTS):
		_hittable[s] = 1 if (_state[s] == State.ACTIVE and _invuln[s] <= 0) else 0
	return _hittable


func state_hash() -> int:
	var h := 1469598103934665603
	for s: int in range(MAX_SLOTS):
		h = (h ^ int(_x[s] * 64.0)) * 1099511628211
		h = (h ^ int(_y[s] * 64.0)) * 1099511628211
		h = (h ^ _state[s]) * 1099511628211
		h = (h ^ _lives[s]) * 1099511628211
		h = (h ^ _invuln[s]) * 1099511628211
	return h
