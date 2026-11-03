extends SceneTree
## Unit tests for PlaneCore (design/gdd/player-plane.md,
## design/gdd/collision-damage-lives.md, ADR-0002 step 2).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_plane_core.gd
## Exit code 0 = pass, 1 = fail.
##
## Tuning is built in the test rather than loaded from data/plane_rules.tres,
## so a designer retuning the game cannot break these tests.

const PLAY_AREA := Rect2(0, 0, 360, 640)

var _failures := 0


func _init() -> void:
	test_plane_core_slot_starts_empty_and_not_hittable()
	test_plane_core_join_starts_fly_in_with_starting_lives()
	test_plane_core_fly_in_is_not_hittable_until_active()
	test_plane_core_fly_in_completes_into_active_with_invulnerability()
	test_plane_core_active_plane_moves_at_move_speed()
	test_plane_core_focus_held_moves_at_focus_speed()
	test_plane_core_diagonal_is_not_faster_than_cardinal()
	test_plane_core_movement_is_clamped_to_play_area()
	test_plane_core_hud_strip_is_taller_for_three_players()
	test_plane_core_kill_spends_a_life_and_starts_death_hold()
	test_plane_core_kill_is_ignored_while_invulnerable()
	test_plane_core_last_life_lost_ends_in_game_over()
	test_plane_core_four_slots_join_in_separate_columns()
	test_plane_core_same_inputs_produce_same_state_hash()

	print("PlaneCore tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _rules() -> PlaneRules:
	var r := PlaneRules.new()
	r.move_speed = 210.0
	r.focus_speed = 105.0
	r.hud_strip_1p = 48.0
	r.hud_strip_coop = 72.0
	r.top_padding = 4.0
	r.edge_margin = 8.0
	r.bottom_margin = 12.0
	r.hitbox_radius = 3.0
	r.fly_in_ticks = 36
	r.death_hold_ticks = 36
	r.respawn_invuln_ticks = 120
	r.fly_in_from_below = 48.0
	r.start_from_bottom = 70.0
	r.starting_lives = 3
	return r


func _make(player_count: int = 1) -> Array:
	var log := TickEventLog.new(64)
	var cores := PlaneCore.new(_rules(), PLAY_AREA, log)
	cores.set_player_count(player_count)
	return [cores, log, SimInput.new()]


## Advances to ACTIVE and burns off the respawn invulnerability, so movement
## tests start from a settled plane.
func _activate(cores: PlaneCore, input: SimInput, slot: int) -> void:
	cores.join(slot)
	for _i: int in range(cores.rules.fly_in_ticks + 1):
		input.begin_tick()
		cores.tick(input)
	for _i: int in range(cores.rules.respawn_invuln_ticks + 1):
		input.begin_tick()
		cores.tick(input)


func _assert_eq(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		print("  FAIL %s: expected %s, got %s" % [what, expected, actual])
		_failures += 1


func _assert_approx(actual: float, expected: float, what: String) -> void:
	if absf(actual - expected) > 0.01:
		print("  FAIL %s: expected ~%f, got %f" % [what, expected, actual])
		_failures += 1


func _assert_true(value: bool, what: String) -> void:
	if not value:
		print("  FAIL %s: expected true" % what)
		_failures += 1


# --- tests -------------------------------------------------------------------

func test_plane_core_slot_starts_empty_and_not_hittable() -> void:
	# Arrange / Act
	var parts := _make()
	var cores: PlaneCore = parts[0]

	# Assert
	_assert_eq(cores.state_of(0), PlaneCore.State.EMPTY, "state of an unjoined slot")
	_assert_eq(cores.hittable_flags()[0], 0, "unjoined slot is not hittable")
	_assert_eq(cores.active_count(), 0, "no active planes")


func test_plane_core_join_starts_fly_in_with_starting_lives() -> void:
	# Arrange
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var log: TickEventLog = parts[1]

	# Act
	cores.join(0)

	# Assert
	_assert_eq(cores.state_of(0), PlaneCore.State.FLY_IN, "state after join")
	_assert_eq(cores.lives_of(0), 3, "starting lives")
	_assert_true(log.has_for_slot(TickEventLog.Kind.SLOT_JOINED, 0), "SLOT_JOINED logged")
	_assert_true(
		log.has_for_slot(TickEventLog.Kind.PLANE_FLY_IN_STARTED, 0),
		"PLANE_FLY_IN_STARTED logged"
	)


func test_plane_core_fly_in_is_not_hittable_until_active() -> void:
	# Arrange: player-plane GDD — FlyIn is targetable but not hittable.
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	cores.join(0)

	# Act: part way through the fly-in
	for _i: int in range(10):
		input.begin_tick()
		cores.tick(input)

	# Assert
	_assert_eq(cores.state_of(0), PlaneCore.State.FLY_IN, "still flying in")
	_assert_eq(cores.hittable_flags()[0], 0, "not hittable during fly-in")


func test_plane_core_fly_in_completes_into_active_with_invulnerability() -> void:
	# Arrange
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var log: TickEventLog = parts[1]
	var input: SimInput = parts[2]
	cores.join(0)

	# Act
	for _i: int in range(cores.rules.fly_in_ticks):
		input.begin_tick()
		cores.tick(input)

	# Assert
	_assert_eq(cores.state_of(0), PlaneCore.State.ACTIVE, "active after fly-in")
	_assert_eq(cores.invuln_of(0), 120, "respawn invulnerability granted")
	_assert_eq(cores.hittable_flags()[0], 0, "invulnerable, so not hittable yet")
	_assert_true(log.has_for_slot(TickEventLog.Kind.PLANE_ACTIVATED, 0), "PLANE_ACTIVATED logged")
	_assert_approx(cores.position_of(0).y, 640.0 - 70.0, "resting y")


func test_plane_core_active_plane_moves_at_move_speed() -> void:
	# Arrange: 210 px/s is 3.5 px per 60 Hz tick.
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	_activate(cores, input, 0)
	var start_x := cores.position_of(0).x

	# Act
	input.begin_tick()
	input.set_move(0, 1, 0)
	cores.tick(input)

	# Assert
	_assert_approx(cores.position_of(0).x - start_x, 3.5, "x travelled in one tick")


func test_plane_core_focus_held_moves_at_focus_speed() -> void:
	# Arrange: 105 px/s is 1.75 px per tick.
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	_activate(cores, input, 0)
	var start_x := cores.position_of(0).x

	# Act
	input.begin_tick()
	input.set_move(0, 1, 0)
	input.set_button(0, SimInput.Action.FOCUS, true)
	cores.tick(input)

	# Assert
	_assert_approx(cores.position_of(0).x - start_x, 1.75, "x travelled while focusing")
	_assert_true(cores.is_focusing(0), "focus flag set")


func test_plane_core_diagonal_is_not_faster_than_cardinal() -> void:
	# Arrange: two planes, one moving right, one moving right+up.
	var parts := _make(2)
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	_activate(cores, input, 0)
	_activate(cores, input, 1)
	var a_start := cores.position_of(0)
	var b_start := cores.position_of(1)

	# Act
	input.begin_tick()
	input.set_move(0, 1, 0)
	input.set_move(1, 1, -1)
	cores.tick(input)

	# Assert
	var cardinal := cores.position_of(0).distance_to(a_start)
	var diagonal := cores.position_of(1).distance_to(b_start)
	_assert_approx(diagonal, cardinal, "diagonal travel matches cardinal travel")


func test_plane_core_movement_is_clamped_to_play_area() -> void:
	# Arrange
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	_activate(cores, input, 0)

	# Act: hold left and up far longer than it takes to cross the field
	for _i: int in range(400):
		input.begin_tick()
		input.set_move(0, -1, -1)
		cores.tick(input)

	# Assert: 1-2P reserves a 48 px HUD strip plus 4 px padding
	_assert_approx(cores.position_of(0).x, 8.0, "clamped to the left edge margin")
	_assert_approx(cores.position_of(0).y, 52.0, "clamped below the 1P HUD strip")


func test_plane_core_hud_strip_is_taller_for_three_players() -> void:
	# Arrange: 3-4P reserves 72 px instead of 48 (art bible 8.1.1).
	var parts := _make(3)
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	_activate(cores, input, 0)

	# Act
	for _i: int in range(400):
		input.begin_tick()
		input.set_move(0, 0, -1)
		cores.tick(input)

	# Assert
	_assert_approx(cores.position_of(0).y, 76.0, "clamped below the 3-4P HUD strip")


func test_plane_core_kill_spends_a_life_and_starts_death_hold() -> void:
	# Arrange
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var log: TickEventLog = parts[1]
	var input: SimInput = parts[2]
	_activate(cores, input, 0)
	log.rotate()

	# Act
	var killed := cores.kill(0)

	# Assert
	_assert_true(killed, "kill accepted on an active, vulnerable plane")
	_assert_eq(cores.state_of(0), PlaneCore.State.DEAD, "state after kill")
	_assert_eq(cores.lives_of(0), 2, "one life spent")
	_assert_eq(cores.hittable_flags()[0], 0, "dead plane is not hittable")
	_assert_true(log.has_for_slot(TickEventLog.Kind.PLAYER_DIED, 0), "PLAYER_DIED logged")


func test_plane_core_kill_is_ignored_while_invulnerable() -> void:
	# Arrange: freshly active, so the respawn invulnerability is still running.
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	cores.join(0)
	for _i: int in range(cores.rules.fly_in_ticks):
		input.begin_tick()
		cores.tick(input)

	# Act
	var killed := cores.kill(0)

	# Assert
	_assert_eq(killed, false, "kill refused while invulnerable")
	_assert_eq(cores.state_of(0), PlaneCore.State.ACTIVE, "still active")
	_assert_eq(cores.lives_of(0), 3, "no life spent")


func test_plane_core_last_life_lost_ends_in_game_over() -> void:
	# Arrange
	var parts := _make()
	var cores: PlaneCore = parts[0]
	var log: TickEventLog = parts[1]
	var input: SimInput = parts[2]

	# Act: die three times, waiting out each death hold and respawn
	_activate(cores, input, 0)
	for _life: int in range(3):
		cores.kill(0)
		for _i: int in range(cores.rules.death_hold_ticks + cores.rules.fly_in_ticks + 2):
			input.begin_tick()
			cores.tick(input)
		if cores.state_of(0) == PlaneCore.State.ACTIVE:
			cores.request_invuln(0, 0)
			# clear invulnerability so the next kill lands
			for _i: int in range(cores.rules.respawn_invuln_ticks + 1):
				input.begin_tick()
				cores.tick(input)

	# Assert
	_assert_eq(cores.lives_of(0), 0, "all lives spent")
	_assert_eq(cores.state_of(0), PlaneCore.State.GAME_OVER, "slot is game over")
	_assert_true(log.has_for_slot(TickEventLog.Kind.GAME_OVER, 0), "GAME_OVER logged")
	_assert_true(cores.all_out(), "all joined slots are out")


func test_plane_core_four_slots_join_in_separate_columns() -> void:
	# Arrange: co-op planes must not fly in on top of each other.
	var parts := _make(4)
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]

	# Act
	for s: int in range(4):
		cores.join(s)
	for _i: int in range(cores.rules.fly_in_ticks):
		input.begin_tick()
		cores.tick(input)

	# Assert
	var seen := {}
	for s: int in range(4):
		var x := cores.position_of(s).x
		_assert_true(not seen.has(x), "slot %d has its own column x" % s)
		seen[x] = true
		_assert_eq(cores.state_of(s), PlaneCore.State.ACTIVE, "slot %d active" % s)
	_assert_eq(cores.active_count(), 4, "four active planes")


func test_plane_core_same_inputs_produce_same_state_hash() -> void:
	# ADR-0003 determinism.
	# Arrange / Act
	var first := _run_scripted()
	var second := _run_scripted()

	# Assert
	_assert_eq(first, second, "state_hash across two identical runs")


func _run_scripted() -> int:
	var parts := _make(2)
	var cores: PlaneCore = parts[0]
	var input: SimInput = parts[2]
	cores.join(0)
	cores.join(1)
	for t: int in range(240):
		input.begin_tick()
		input.set_move(0, 1 if (t / 20) % 2 == 0 else -1, 0)
		input.set_move(1, 0, 1 if (t / 15) % 2 == 0 else -1)
		input.set_button(0, SimInput.Action.FOCUS, (t / 30) % 2 == 0)
		cores.tick(input)
		if t == 150:
			cores.kill(1)
	return cores.state_hash()
