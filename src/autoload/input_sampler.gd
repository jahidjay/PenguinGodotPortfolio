extends Node
## Autoload "InputSampler" — the only bridge from real devices into the
## simulation. ADR-0002 Decision 2 splits input in two:
##
##   service_step()    every physics step, real time, runs while paused:
##                     reads device state and latches presses.
##   commit_sim_tick() at step 1 of a GAME tick: writes the per-slot SimInput
##                     and clears the latches.
##
## The split is what stops a press being missed when a physics step does not
## become a game tick (paused, load discard, speed gate): the press stays
## latched until a tick actually consumes it.
##
## Reads the per-player actions registered by InputSetup (p1_* .. p4_*), so
## local co-op device assignment lives in one place.
##
## PROCESS_MODE_ALWAYS so it keeps sampling while the tree is paused
## (Input Rule 9).
##
## Usage:
## [codeblock]
## # GameLoop calls these; nothing else should.
## InputSampler.service_step()
## InputSampler.commit_sim_tick(world.input)
##
## # a test or replay bypasses this node entirely and writes SimInput directly
## [/codeblock]

const MAX_SLOTS := 4

## Action name suffixes, indexed by SimInput.Action.
const ACTION_NAMES := ["fire", "focus", "bomb", "drone", "start"]

## Latched presses per slot, cleared only when a game tick consumes them.
var _latched := PackedInt32Array()
## Live held state per slot, refreshed every service_step.
var _held := PackedInt32Array()
var _move_x := PackedInt32Array()
var _move_y := PackedInt32Array()

var _serviced_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Run before the GameLoop so priority ordering alone is usually enough;
	# the loop also guards the call, so correctness does not depend on this.
	process_physics_priority = -100
	_latched.resize(MAX_SLOTS)
	_held.resize(MAX_SLOTS)
	_move_x.resize(MAX_SLOTS)
	_move_y.resize(MAX_SLOTS)


func _physics_process(_delta: float) -> void:
	service_step()


## Idempotent per physics frame: the GameLoop may also call this if priority
## ordering does not put this autoload first (ADR-0002 Decision 2).
func service_step() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _serviced_frame:
		return
	_serviced_frame = frame

	for slot: int in range(MAX_SLOTS):
		var prefix := "p%d_" % (slot + 1)

		var x := 0
		if Input.is_action_pressed(StringName(prefix + "right")):
			x += 1
		if Input.is_action_pressed(StringName(prefix + "left")):
			x -= 1
		var y := 0
		if Input.is_action_pressed(StringName(prefix + "down")):
			y += 1
		if Input.is_action_pressed(StringName(prefix + "up")):
			y -= 1
		_move_x[slot] = x
		_move_y[slot] = y

		var held := 0
		for action: int in range(ACTION_NAMES.size()):
			var name := StringName(prefix + ACTION_NAMES[action])
			if not InputMap.has_action(name):
				continue
			if Input.is_action_pressed(name):
				held |= 1 << action
			# Latch the press whether or not this step becomes a game tick.
			if Input.is_action_just_pressed(name):
				_latched[slot] |= 1 << action
		_held[slot] = held


## Writes one tick of input and clears the press latches. Called at step 1 of
## a game tick, and only then.
func commit_sim_tick(input: SimInput) -> void:
	input.begin_tick()
	for slot: int in range(MAX_SLOTS):
		input.set_move(slot, _move_x[slot], _move_y[slot])
		var effective := _held[slot] | _latched[slot]
		for action: int in range(ACTION_NAMES.size()):
			input.set_button(slot, action, (effective & (1 << action)) != 0)
		_latched[slot] = 0


## True if any device has offered input for this slot — used to decide whether
## a slot may join in co-op.
func slot_has_input(slot: int) -> bool:
	return _move_x[slot] != 0 or _move_y[slot] != 0 or _held[slot] != 0 or _latched[slot] != 0
