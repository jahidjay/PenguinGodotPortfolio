extends SceneTree
## The Drone / Bomb press buffer and the bindings that carry it
## (design/gdd/input-and-player-mapping.md Rules 7, 17, 18, F1, F6).
##
## Regression cover for the reported bug "the player has drones but cannot
## deploy them": a Drone press was only ever read on its own tick, so a press
## made while the ability was a few ticks from ready was thrown away, and
## nothing on screen said why.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_input_buffer.gd

const PLAY_AREA := Rect2(0.0, 48.0, 360.0, 592.0)

var _failures := 0
var _enemy_managers: Array = []


func _init() -> void:
	test_sim_input_press_buffers_drone_and_bomb_only()
	test_sim_input_buffered_press_expires_after_buffer_ticks()
	test_sim_input_consume_takes_the_press_exactly_once()
	test_sim_input_clear_buffer_drops_every_pending_press()
	test_sim_input_replayed_presses_rebuild_the_same_buffer()
	test_plane_kits_drone_press_during_cooldown_deploys_when_it_ends()
	test_plane_kits_drone_press_with_no_drones_is_not_held_forever()
	test_plane_core_non_active_slot_loses_its_buffered_press()
	test_input_setup_binds_every_action_the_sampler_reads()
	test_input_setup_gives_two_slots_their_own_keyboard_scheme()
	test_input_setup_debug_keys_do_not_collide_with_keyboard_schemes()

	for manager: EnemyManager in _enemy_managers:
		manager.clear_all()
	print("InputBuffer tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- SimInput -----------------------------------------------------------------

func test_sim_input_press_buffers_drone_and_bomb_only() -> void:
	# Arrange
	var input := SimInput.new()

	# Act
	input.begin_tick()
	for action: int in range(SimInput.ACTION_COUNT):
		input.set_button(0, action, true)

	# Assert
	_assert(input.buffered(0, SimInput.Action.DRONE), "a Drone press buffers")
	_assert(input.buffered(0, SimInput.Action.BOMB), "a Bomb press buffers")
	_assert(not input.buffered(0, SimInput.Action.FIRE), "Fire is a hold and never buffers")
	_assert(not input.buffered(0, SimInput.Action.START), "Start never buffers")
	_assert(not input.buffered(0, SimInput.Action.FOCUS), "Focus never buffers")
	_assert(not input.buffered(1, SimInput.Action.DRONE), "another slot's buffer is its own")


func test_sim_input_buffered_press_expires_after_buffer_ticks() -> void:
	# Arrange
	var input := SimInput.new()
	input.begin_tick()
	input.set_button(0, SimInput.Action.DRONE, true)

	# Act: hold nothing for the whole window
	var alive_ticks := 1
	for _t: int in range(input.buffer_ticks + 2):
		input.begin_tick()
		if input.buffered(0, SimInput.Action.DRONE):
			alive_ticks += 1

	# Assert
	_assert_eq(alive_ticks, input.buffer_ticks, "the press lives for buffer_ticks ticks")
	_assert(
		not input.buffered(0, SimInput.Action.DRONE),
		"an unconsumed press expires on its own (F6)"
	)


func test_sim_input_consume_takes_the_press_exactly_once() -> void:
	# Arrange
	var input := SimInput.new()
	input.begin_tick()
	input.set_button(0, SimInput.Action.BOMB, true)

	# Act
	var first := input.consume(0, SimInput.Action.BOMB)
	var second := input.consume(0, SimInput.Action.BOMB)

	# Assert
	_assert(first, "the buffered press was taken")
	_assert(not second, "it cannot be taken twice")
	_assert(not input.buffered(0, SimInput.Action.BOMB), "and it is gone from the buffer")


func test_sim_input_clear_buffer_drops_every_pending_press() -> void:
	# Arrange
	var input := SimInput.new()
	input.begin_tick()
	input.set_button(0, SimInput.Action.DRONE, true)
	input.set_button(0, SimInput.Action.BOMB, true)
	input.set_button(1, SimInput.Action.DRONE, true)

	# Act
	input.clear_buffer(0)

	# Assert
	_assert(not input.buffered(0, SimInput.Action.DRONE), "slot 0's Drone press is gone")
	_assert(not input.buffered(0, SimInput.Action.BOMB), "slot 0's Bomb press is gone")
	_assert(input.buffered(1, SimInput.Action.DRONE), "slot 1 kept its own press")


func test_sim_input_replayed_presses_rebuild_the_same_buffer() -> void:
	# Arrange: record one press tick, then replay it into a fresh SimInput
	var live := SimInput.new()
	live.begin_tick()
	live.set_button(2, SimInput.Action.DRONE, true)
	var axes := live.pack_axes()
	var buttons := live.pack_buttons()

	# Act
	var replay := SimInput.new()
	replay.begin_tick()
	replay.load_packed(axes, buttons)

	# Assert
	_assert(
		replay.buffered(2, SimInput.Action.DRONE),
		"a replayed press buffers exactly like the live one (ADR-0003)"
	)


# --- PlaneKits and PlaneCore --------------------------------------------------

func test_plane_kits_drone_press_during_cooldown_deploys_when_it_ends() -> void:
	# Arrange: a Lancer that has already used its drones once, so the ability
	# is on its real cooldown rather than a forced one
	var rig := _rig(KitRules.Kind.LANCER)
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	var enemies: EnemyManager = rig[2]
	var input := SimInput.new()
	kits.set_drone_count(0, 2)
	_press_drone(kits, planes, enemies, input)
	var guard := 0
	while kits.cooldown_left(0) != 3 and guard < 4000:
		_run(kits, planes, enemies, input, 1)
		guard += 1

	# Act: press Drone with 3 ticks of cooldown left, then hold nothing
	_assert_eq(kits.ability_state(0), PlaneKits.Ability.COOLDOWN, "the ability is on cooldown")
	_press_drone(kits, planes, enemies, input)
	var deployed_on_press := kits.ability_state(0) == PlaneKits.Ability.ACTIVE
	_run(kits, planes, enemies, input, 4)

	# Assert
	_assert(not deployed_on_press, "the press could not be accepted on its own tick")
	_assert_eq(
		kits.ability_state(0), PlaneKits.Ability.ACTIVE,
		"the buffered press deployed the drones as soon as the cooldown ended"
	)


func test_plane_kits_drone_press_with_no_drones_is_not_held_forever() -> void:
	# Arrange: a plane with no drones at all
	var rig := _rig(KitRules.Kind.LANCER)
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	var enemies: EnemyManager = rig[2]
	var input := SimInput.new()
	kits.set_drone_count(0, 0)
	_run(kits, planes, enemies, input, 1)

	# Act: press Drone, let the window expire, then collect a pod
	_press_drone(kits, planes, enemies, input)
	_run(kits, planes, enemies, input, input.buffer_ticks + 2)
	kits.set_drone_count(0, 1)
	_run(kits, planes, enemies, input, 2)

	# Assert
	_assert_eq(
		kits.ability_state(0), PlaneKits.Ability.READY,
		"a press with no drones expires instead of firing when a pod lands"
	)


func test_plane_core_non_active_slot_loses_its_buffered_press() -> void:
	# Arrange: a slot that has joined but is still flying in
	var planes := _planes()
	planes.join(0)
	var input := SimInput.new()

	# Act
	input.begin_tick()
	input.set_button(0, SimInput.Action.DRONE, true)
	planes.tick(input)

	# Assert
	_assert_eq(planes.state_of(0), PlaneCore.State.FLY_IN, "the plane is still flying in")
	_assert(
		not input.buffered(0, SimInput.Action.DRONE),
		"Rule 18: a non-Active plane owns no buffered press"
	)


# --- InputSetup ---------------------------------------------------------------

func test_input_setup_binds_every_action_the_sampler_reads() -> void:
	# Arrange
	var setup := _setup()
	var actions := ["left", "right", "up", "down", "fire", "focus", "bomb", "drone", "start"]

	# Act / Assert
	for slot: int in range(4):
		for action: String in actions:
			var name := StringName("p%d_%s" % [slot + 1, action])
			_assert(InputMap.has_action(name), "%s is bound" % name)
			_assert(
				InputMap.action_get_events(name).size() > 0, "%s has at least one event" % name
			)
	setup.free()


func test_input_setup_gives_two_slots_their_own_keyboard_scheme() -> void:
	# Arrange
	var setup := _setup()

	# Act
	var p1_keys := _keys_of("p1_fire")
	var p2_keys := _keys_of("p2_fire")
	var p1_drone := _keys_of("p1_drone")
	var p2_drone := _keys_of("p2_drone")
	var p3_keys := _keys_of("p3_fire")

	# Assert
	_assert(p1_keys.has(KEY_Z), "KB1 fires with Z")
	_assert(p2_keys.has(KEY_F), "KB2 fires with F")
	_assert(p1_drone.has(KEY_X), "KB1 deploys drones with X")
	_assert(p2_drone.has(KEY_G), "KB2 deploys drones with G")
	_assert(p1_keys.filter(func(k: int) -> bool: return p2_keys.has(k)).is_empty(),
		"the two keyboard schemes share no Fire key")
	_assert(p3_keys.is_empty(), "slots 3 and 4 are gamepad only")

	# Act / Assert: WASD belongs to KB1 only while KB2 is unclaimed
	_assert(_keys_of("p1_up").has(KEY_W), "a solo player may use WASD on slot 0")
	setup.release_wasd_from_kb1()
	_assert(not _keys_of("p1_up").has(KEY_W), "slot 1 joining takes WASD off slot 0")
	_assert(_keys_of("p1_up").has(KEY_UP), "the arrows stay")
	_assert(_keys_of("p2_up").has(KEY_W), "WASD still drives slot 1")
	setup.restore_wasd_to_kb1()
	_assert(_keys_of("p1_up").has(KEY_W), "and comes back when slot 1 leaves")
	setup.free()


func test_input_setup_debug_keys_do_not_collide_with_keyboard_schemes() -> void:
	# Arrange
	var setup := _setup()
	var player_keys := {}
	for slot: int in range(4):
		for action: String in ["left", "right", "up", "down", "fire", "focus", "bomb", "drone", "start", "back"]:
			for key: int in _keys_of("p%d_%s" % [slot + 1, action]):
				player_keys[key] = true

	# Act / Assert: the old R / N / 1 / 2 / 3 debug keys collided with KB2
	for action: String in ["restart", "next_boss", "boss_1", "boss_2", "boss_3"]:
		var keys := _keys_of(action)
		_assert(keys.size() > 0, "%s is bound" % action)
		for key: int in keys:
			_assert(
				not player_keys.has(key),
				"%s does not use a key a player needs (key %d)" % [action, key]
			)
	setup.free()


# --- helpers ------------------------------------------------------------------

func _setup() -> Node:
	# A fresh InputMap, so the test never inherits another suite's bindings.
	InputMap.load_from_project_settings()
	var setup: Node = load("res://src/autoload/input_setup.gd").new()
	setup._ready()
	return setup


func _keys_of(action: String) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			out.append(key.physical_keycode)
	return out


func _kit_rules() -> KitRules:
	return load("res://data/kit_rules.tres") as KitRules


func _planes() -> PlaneCore:
	var log := TickEventLog.new(256)
	return PlaneCore.new(load("res://data/plane_rules.tres") as PlaneRules, PLAY_AREA, log)


func _rig(kind: int) -> Array:
	var log := TickEventLog.new(512)
	var bullet_rules := load("res://data/bullet_rules.tres") as BulletRules
	var kits := PlaneKits.new(_kit_rules(), bullet_rules, PLAY_AREA)
	kits.set_kind(0, kind)
	var planes := PlaneCore.new(
		load("res://data/plane_rules.tres") as PlaneRules, PLAY_AREA, log
	)
	planes.join(0)
	var scene := PatternScene.new(
		load("res://data/pattern_rules.tres") as PatternRules, FakeBulletField.new(), log
	)
	var enemies := EnemyManager.new(scene, log, PLAY_AREA, load("res://data/enemy_rules.tres"))
	_enemy_managers.append(enemies)
	# Fly the plane in and wait out the spawn shield, so it is Active.
	var input := SimInput.new()
	for _t: int in range(200):
		input.begin_tick()
		planes.tick(input)
	return [kits, planes, enemies, scene, log]


## One Drone press and its release, the way the sampler would deliver it.
func _press_drone(
	kits: PlaneKits, planes: PlaneCore, enemies: EnemyManager, input: SimInput
) -> void:
	input.begin_tick()
	input.set_button(0, SimInput.Action.DRONE, true)
	planes.tick(input)
	kits.tick(planes, input, enemies)


func _run(
	kits: PlaneKits, planes: PlaneCore, enemies: EnemyManager, input: SimInput, ticks: int
) -> void:
	for _t: int in range(ticks):
		input.begin_tick()
		# The sampler writes every button's level every tick, so a button
		# nobody is holding has to be written false here too — otherwise the
		# press edge for the next press never happens.
		input.set_button(0, SimInput.Action.DRONE, false)
		planes.tick(input)
		kits.tick(planes, input, enemies)


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
