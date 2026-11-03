class_name SimInput
extends RefCounted
## One tick's input for all four local co-op slots (ADR-0002 step 1, ADR-0003).
##
## This is the ONLY way input reaches the simulation. Nothing in SimWorld reads
## Input directly, which is what makes a run replayable: feeding the same
## SimInput sequence to a fresh SimWorld reproduces the run exactly, and a
## headless verifier needs no devices.
##
## Axes are digital: -1, 0 or +1 per slot per axis (the plane is 8-way with no
## inertia, player-plane GDD). Buttons expose both "held this tick" and
## "pressed this tick" so a system can choose level or edge semantics.
##
## Drone and Bomb presses are also BUFFERED for `buffer_ticks` ticks
## (input-and-player-mapping.md Rule 17, F6), so a press made a few ticks
## before the ability was ready still fires. The buffer lives here, on the
## simulation side of the line, because whether a press was accepted is a
## simulation fact: a replay that feeds the same presses rebuilds the same
## buffer (ADR-0003). Fire is never buffered — it is a hold.
##
## Fixed size, allocated once, overwritten each tick — no allocation in the
## tick path.
##
## Usage:
## [codeblock]
## # the sampler fills it at step 1, from device state
## input.begin_tick()
## input.set_move(slot, -1, 0)
## input.set_button(slot, SimInput.Action.FIRE, true)
##
## # systems read it at their own step
## if input.move_x(slot) != 0: ...
## if input.pressed(slot, SimInput.Action.BOMB): drop_bomb(slot)
##
## # a consumer that may not be ready on the press tick takes the buffered
## # press instead, and consumes it only when it actually acts
## if input.consume(slot, SimInput.Action.DRONE): deploy_drones(slot)
##
## # replay: decode a recorded tick straight into the same shape
## input.load_packed(recorded_axes, recorded_buttons)
## [/codeblock]

const MAX_SLOTS := 4

## Player action bits (named Action, not Button: Button is a Godot Control class). Append only — these values are part of the replay format
## (ADR-0003), so never renumber an existing entry.
enum Action {
	FIRE,
	FOCUS,
	BOMB,
	DRONE,
	START,
}

const ACTION_COUNT := 5

## The only actions that buffer. Fire is a hold and is never buffered; Start
## and Focus are never buffered (Input Rule 17).
const BUFFERED_ACTIONS := [Action.DRONE, Action.BOMB]

## -1 / 0 / +1 per slot.
var _move_x := PackedInt32Array()
var _move_y := PackedInt32Array()
## Bitmask per slot, one bit per Action.
var _held := PackedInt32Array()
var _pressed := PackedInt32Array()
## How many consecutive ticks each button has been held, per slot.
var _held_ticks := PackedInt32Array()
## Ticks of life left on a buffered press, per slot per action. Only the
## actions in [constant BUFFERED_ACTIONS] ever get one.
var _buffer := PackedInt32Array()

## Ticks a Drone or Bomb press stays available to a consumer that was not
## ready on the press tick (Input Rule 17: 6 ticks, 0.1 s).
var buffer_ticks := 6


func _init() -> void:
	_move_x.resize(MAX_SLOTS)
	_move_y.resize(MAX_SLOTS)
	_held.resize(MAX_SLOTS)
	_pressed.resize(MAX_SLOTS)
	_held_ticks.resize(MAX_SLOTS * ACTION_COUNT)
	_buffer.resize(MAX_SLOTS * ACTION_COUNT)


## Clears this tick's edges and axes, keeping the held mask so the sampler can
## rebuild it. Call once per tick before setting anything.
func begin_tick() -> void:
	for s: int in range(MAX_SLOTS):
		_move_x[s] = 0
		_move_y[s] = 0
		_pressed[s] = 0
	# Rule 17: a buffered press expires on its own if nothing consumed it.
	for i: int in range(_buffer.size()):
		if _buffer[i] > 0:
			_buffer[i] -= 1


func set_move(slot: int, x: int, y: int) -> void:
	_move_x[slot] = signi(x)
	_move_y[slot] = signi(y)


## Sets a button's level for this tick and derives its edge and hold count.
func set_button(slot: int, button: int, down: bool) -> void:
	var bit := 1 << button
	var was_down := (_held[slot] & bit) != 0
	var index := slot * ACTION_COUNT + button
	if down:
		if not was_down:
			_pressed[slot] |= bit
			if BUFFERED_ACTIONS.has(button):
				_buffer[index] = buffer_ticks
		_held[slot] |= bit
		_held_ticks[index] += 1
	else:
		_held[slot] &= ~bit
		_held_ticks[index] = 0


func move_x(slot: int) -> int:
	return _move_x[slot]


func move_y(slot: int) -> int:
	return _move_y[slot]


func held(slot: int, button: int) -> bool:
	return (_held[slot] & (1 << button)) != 0


## True only on the tick the button went down.
func pressed(slot: int, button: int) -> bool:
	return (_pressed[slot] & (1 << button)) != 0


func held_ticks(slot: int, button: int) -> int:
	return _held_ticks[slot * ACTION_COUNT + button]


func fire_held(slot: int) -> bool:
	return (_held[slot] & (1 << Action.FIRE)) != 0


func focus_held(slot: int) -> bool:
	return (_held[slot] & (1 << Action.FOCUS)) != 0


func any_input(slot: int) -> bool:
	return _move_x[slot] != 0 or _move_y[slot] != 0 or _held[slot] != 0


## True while a Drone or Bomb press is still inside its buffer window. True on
## the press tick itself, so a consumer that only ever reads this sees the
## press exactly once per press.
func buffered(slot: int, button: int) -> bool:
	return _buffer[slot * ACTION_COUNT + button] > 0


## Takes a buffered press: true once, and the press is gone. A consumer calls
## this only on a tick it actually acts, so a rejected press stays available
## for the rest of its window (Rule 17, F6).
func consume(slot: int, button: int) -> bool:
	var index := slot * ACTION_COUNT + button
	if _buffer[index] <= 0:
		return false
	_buffer[index] = 0
	return true


## Drops every buffered press for one slot. The Player plane calls it on every
## tick the plane is not Active, so a press made during a fly-in or a death
## hold never fires after control returns (Rule 18).
func clear_buffer(slot: int) -> void:
	for b: int in range(ACTION_COUNT):
		_buffer[slot * ACTION_COUNT + b] = 0


# --- replay (ADR-0003) -------------------------------------------------------

## Packs this tick into two ints per slot, for the replay recorder.
func pack_axes() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(MAX_SLOTS)
	for s: int in range(MAX_SLOTS):
		# two signed 2-bit fields, biased to stay non-negative
		out[s] = (_move_x[s] + 1) | ((_move_y[s] + 1) << 2)
	return out


func pack_buttons() -> PackedInt32Array:
	return _held.duplicate()


## Restores a recorded tick. Edges and hold counts are rebuilt from the
## previous held mask, so a replayed run sees the same presses as the live one.
func load_packed(axes: PackedInt32Array, buttons: PackedInt32Array) -> void:
	for s: int in range(MAX_SLOTS):
		var a := axes[s]
		_move_x[s] = (a & 0x3) - 1
		_move_y[s] = ((a >> 2) & 0x3) - 1
		var want := buttons[s]
		_pressed[s] = 0
		for b: int in range(ACTION_COUNT):
			set_button(s, b, (want & (1 << b)) != 0)


func clear_all() -> void:
	for s: int in range(MAX_SLOTS):
		_move_x[s] = 0
		_move_y[s] = 0
		_held[s] = 0
		_pressed[s] = 0
	for i: int in range(_held_ticks.size()):
		_held_ticks[i] = 0
	for i: int in range(_buffer.size()):
		_buffer[i] = 0
