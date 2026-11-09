extends Node
## Registers every input action in code (autoload "InputSetup") so the
## per-player device mapping for 1-4 local co-op lives in one readable place.
## Implements the default bindings table of
## `design/gdd/input-and-player-mapping.md` ("Default bindings", Rules 7, 22).
##
## Action set per slot (the contract with the simulation; the sampler reads
## these exact names and writes [SimInput]):
##
##   pN_left pN_right pN_up pN_down   8-way move
##   pN_fire    tap shot / hold charge mode; menu confirm; Continue accept
##   pN_drone   drone ability (buffered 6 ticks, Input Rule 17)
##   pN_bomb    bomb; menu cancel
##   pN_focus   hold to slow the plane to focus speed (precision move)
##   pN_start   join, pause, menu confirm
##   pN_back    menu cancel; pause in a stage
##   pN_ability LEGACY alias of pN_drone, still read by the old prototype
##              scene `src/gameplay/player/laser_ability.gd`
##
## Devices, PC (mobile gets an on-screen button layer later: that is
## `design/gdd/touch-controls.md`, not this file):
##
##   Slot 0  keyboard scheme KB1 "Main" (arrows, Z X C) + gamepad 0
##   Slot 1  keyboard scheme KB2 "Left hand" (WASD, F G R) + gamepad 1
##   Slot 2  gamepad 2
##   Slot 3  gamepad 3
##
## Two players therefore share one keyboard without any setup, which is what
## makes local co-op reachable on a PC with a single pad. KB1 also answers
## WASD while slot 1 is out of the run, so a solo player can use either hand
## position; the moment slot 1 joins, [method release_wasd_from_kb1] takes
## WASD off slot 0 so the two schemes cannot fight over the same keys
## (GDD "Default bindings" note: WASD is KB1's alternate only while KB2 is
## unclaimed).
##
## Debug keys are F5-F9 (GDD Rule 8, correction 9): the old R / N / 1 / 2 / 3
## collided with KB2's Bomb and Start.
##
## Usage:
## [codeblock]
## # the lobby, when slot 1 joins or leaves
## InputSetup.release_wasd_from_kb1()
## InputSetup.restore_wasd_to_kb1()
## [/codeblock]
##
## Known gap (GDD F3): an analog trigger used as a button presses at the
## action deadzone and releases at the same value — the 0.50 / 0.35
## hysteresis needs the sampler and is not implemented yet.

const MAX_PLAYERS := 4
## Stick deadzone for the digital move actions (GDD Rule 15, `dz_enter`). The
## 0.20 exit threshold and the 4 degree sector hysteresis belong to the
## sampler and are not implemented yet.
const MOVE_DEADZONE := 0.3
## Actions that can be driven by an analog trigger press at least half way.
const TRIGGER_DEADZONE := 0.5
## Matches any device. Used for keyboard events: in Godot 4.7 keyboard events
## no longer report device 0 (see docs/engine-reference/godot/breaking-changes.md).
const ALL_DEVICES := -1

## KB1's alternate move keys, held here so they can be taken away again when
## slot 1 claims KB2.
const KB1_ALT_MOVE := {
	"left": KEY_A,
	"right": KEY_D,
	"up": KEY_W,
	"down": KEY_S,
}

var _wasd_on_kb1 := false


func _ready() -> void:
	for i in MAX_PLAYERS:
		_register_pad(i)
	_register_kb1()
	_register_kb2()
	restore_wasd_to_kb1()

	# Pause is global: any Esc / P, or pad 0's Start.
	_key("pause", KEY_ESCAPE)
	_key("pause", KEY_P)
	_joy_button("pause", 0, JOY_BUTTON_START)

	# Debug only (GDD Rule 8). On F-keys so they cannot collide with KB2.
	_key("restart", KEY_F5)
	_key("next_boss", KEY_F6)
	_key("boss_1", KEY_F7)
	_key("boss_2", KEY_F8)
	_key("boss_3", KEY_F9)


# --- gamepads -----------------------------------------------------------------

## One pad per slot, positional face buttons (South Fire, West Drone, East
## Bomb) with the shoulder and trigger alternates from the defaults table.
##
## Known gap (GDD correction 2): slot N is still hard-bound to joypad N.
## Joypad ids are not stable across hot-plug, so dynamic assignment by Start
## press is still owed (Rules 1-6).
func _register_pad(index: int) -> void:
	var p := "p%d_" % (index + 1)
	var pad := index

	_joy_axis(p + "left", pad, JOY_AXIS_LEFT_X, -1.0, MOVE_DEADZONE)
	_joy_axis(p + "right", pad, JOY_AXIS_LEFT_X, 1.0, MOVE_DEADZONE)
	_joy_axis(p + "up", pad, JOY_AXIS_LEFT_Y, -1.0, MOVE_DEADZONE)
	_joy_axis(p + "down", pad, JOY_AXIS_LEFT_Y, 1.0, MOVE_DEADZONE)
	_joy_button(p + "left", pad, JOY_BUTTON_DPAD_LEFT)
	_joy_button(p + "right", pad, JOY_BUTTON_DPAD_RIGHT)
	_joy_button(p + "up", pad, JOY_BUTTON_DPAD_UP)
	_joy_button(p + "down", pad, JOY_BUTTON_DPAD_DOWN)

	# Fire: South, alternate Right shoulder.
	_joy_button(p + "fire", pad, JOY_BUTTON_A)
	_joy_button(p + "fire", pad, JOY_BUTTON_RIGHT_SHOULDER)
	# Drone: West, alternate Left shoulder.
	_joy_button(p + "drone", pad, JOY_BUTTON_X)
	_joy_button(p + "drone", pad, JOY_BUTTON_LEFT_SHOULDER)
	# Bomb: East, alternate Right trigger.
	_joy_button(p + "bomb", pad, JOY_BUTTON_B)
	_joy_axis(p + "bomb", pad, JOY_AXIS_TRIGGER_RIGHT, 1.0, TRIGGER_DEADZONE)
	# Focus: Left trigger. The defaults table leaves it unbound; this is the
	# only pad control that no other action wants.
	_joy_axis(p + "focus", pad, JOY_AXIS_TRIGGER_LEFT, 1.0, TRIGGER_DEADZONE)
	_joy_button(p + "start", pad, JOY_BUTTON_START)
	_joy_button(p + "back", pad, JOY_BUTTON_BACK)
	# Legacy alias: the prototype boss scene still reads "ability".
	_joy_button(p + "ability", pad, JOY_BUTTON_X)


# --- keyboards ----------------------------------------------------------------

## KB1 "Main": the right-hand position. Arrows to move, Z X C in a row.
func _register_kb1() -> void:
	var p := "p1_"
	_key(p + "left", KEY_LEFT)
	_key(p + "right", KEY_RIGHT)
	_key(p + "up", KEY_UP)
	_key(p + "down", KEY_DOWN)

	_key(p + "fire", KEY_Z)
	_key(p + "fire", KEY_SPACE)
	_key(p + "fire", KEY_COMMA)
	_key(p + "drone", KEY_X)
	_key(p + "drone", KEY_PERIOD)
	_key(p + "ability", KEY_X)
	_key(p + "bomb", KEY_C)
	_key(p + "bomb", KEY_SLASH)
	_key(p + "focus", KEY_SHIFT)
	_key(p + "start", KEY_ENTER)
	_key(p + "start", KEY_KP_ENTER)
	_key(p + "back", KEY_ESCAPE)
	_key(p + "back", KEY_BACKSPACE)


## KB2 "Left hand": WASD to move, F G R under the left hand, 1 to join.
func _register_kb2() -> void:
	var p := "p2_"
	_key(p + "left", KEY_A)
	_key(p + "right", KEY_D)
	_key(p + "up", KEY_W)
	_key(p + "down", KEY_S)

	_key(p + "fire", KEY_F)
	_key(p + "drone", KEY_G)
	_key(p + "ability", KEY_G)
	_key(p + "bomb", KEY_R)
	_key(p + "focus", KEY_Q)
	_key(p + "start", KEY_1)
	_key(p + "back", KEY_2)


## Takes WASD off slot 0. Called when slot 1 enters the run, so the two
## keyboard schemes never answer the same key.
func release_wasd_from_kb1() -> void:
	if not _wasd_on_kb1:
		return
	_wasd_on_kb1 = false
	for direction: String in KB1_ALT_MOVE:
		var action := StringName("p1_" + direction)
		var want: Key = KB1_ALT_MOVE[direction]
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null and key.physical_keycode == want:
				InputMap.action_erase_event(action, event)


## Gives WASD back to slot 0, for a solo player who prefers the left hand.
func restore_wasd_to_kb1() -> void:
	if _wasd_on_kb1:
		return
	_wasd_on_kb1 = true
	for direction: String in KB1_ALT_MOVE:
		_key("p1_" + direction, KB1_ALT_MOVE[direction])


## True while slot 0 still answers WASD as well as the arrows.
func wasd_on_kb1() -> bool:
	return _wasd_on_kb1


# --- registration helpers -----------------------------------------------------

func _ensure(action: StringName, deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		# One action, one deadzone: it ends up the HIGHEST any of its controls
		# asks for, so a trigger bound as a button presses at 0.5 (GDD F3)
		# while the digital controls on the same action, which report full
		# strength, are unaffected.
		InputMap.action_set_deadzone(
			action, maxf(InputMap.action_get_deadzone(action), deadzone)
		)


func _key(action: StringName, keycode: Key) -> void:
	_ensure(action, MOVE_DEADZONE)
	var e := InputEventKey.new()
	# Physical keycodes: WASD stays WASD on an AZERTY keyboard (GDD Rule 22).
	e.physical_keycode = keycode
	e.device = ALL_DEVICES
	InputMap.action_add_event(action, e)


func _joy_button(action: StringName, device: int, button: JoyButton) -> void:
	_ensure(action, MOVE_DEADZONE)
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	InputMap.action_add_event(action, e)


func _joy_axis(
	action: StringName, device: int, axis: JoyAxis, direction: float, deadzone: float
) -> void:
	_ensure(action, deadzone)
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = axis
	e.axis_value = direction
	InputMap.action_add_event(action, e)
