extends SceneTree
## Lobby / plane select: joining, per-slot cursors, ready-up, the commit
## countdown, duplicate planes and the stall timers
## (design/gdd/menus-title-plane-select.md Rules 18-25).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_lobby_model.gd

var _failures := 0


func _init() -> void:
	test_lobby_model_open_puts_the_titles_slot_straight_into_choosing()
	test_lobby_model_a_press_held_from_the_title_does_not_lock_a_plane()
	test_lobby_model_start_press_joins_an_empty_slot()
	test_lobby_model_nav_wraps_and_moves_only_its_own_slot()
	test_lobby_model_held_direction_repeats_on_the_input_cadence()
	test_lobby_model_confirm_locks_and_cancel_steps_back_out()
	test_lobby_model_last_slot_cancelling_abandons_the_lobby()
	test_lobby_model_commits_only_after_the_start_delay()
	test_lobby_model_a_new_join_resets_the_countdown()
	test_lobby_model_duplicate_planes_get_different_colourways()
	test_lobby_model_selections_carry_slot_kind_and_colourway_in_slot_order()
	test_lobby_model_afk_choosing_slot_is_released_once_someone_is_locked()
	test_lobby_model_a_quiet_lobby_returns_to_title()

	print("LobbyModel tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- tests --------------------------------------------------------------------

func test_lobby_model_open_puts_the_titles_slot_straight_into_choosing() -> void:
	# Arrange / Act
	var lobby := _make()
	lobby.open(0)

	# Assert
	_assert_eq(lobby.state_of(0), LobbyModel.SlotState.CHOOSING, "slot 0 is Choosing")
	_assert_eq(lobby.state_of(1), LobbyModel.SlotState.EMPTY, "slot 1 is still Empty")
	_assert_eq(lobby.joined_count(), 1, "one slot joined")
	_assert_eq(lobby.cursor_of(0), 0, "slot 0 starts on its own row")


func test_lobby_model_a_press_held_from_the_title_does_not_lock_a_plane() -> void:
	# Arrange: the screen opens on the very Fire press that confirmed
	# START GAME, so a fresh SimInput reports it as a press on tick 1.
	var lobby := _make()
	lobby.open(0)
	var input := SimInput.new()

	# Act: hold Fire down for a while, then release and press it properly
	for _t: int in range(30):
		input.begin_tick()
		_release_all(input)
		input.set_button(0, SimInput.Action.FIRE, true)
		lobby.tick(input)
	var locked_by_the_carried_press := lobby.state_of(0) == LobbyModel.SlotState.LOCKED
	var countdown_after_carried_press := lobby.commit_ticks
	_assert(not lobby.is_armed(0), "the slot stays disarmed while the button is down")
	_press(lobby, input, 0, SimInput.Action.FIRE)

	# Assert
	_assert(not locked_by_the_carried_press, "the carried-over press locked nothing")
	_assert_eq(countdown_after_carried_press, 0, "and started no countdown")
	_assert(lobby.is_armed(0), "releasing the button armed the slot")
	_assert_eq(
		lobby.state_of(0), LobbyModel.SlotState.LOCKED, "a fresh press does lock the plane"
	)


func test_lobby_model_start_press_joins_an_empty_slot() -> void:
	# Arrange
	var lobby := _make()
	lobby.open(0)
	var input := SimInput.new()

	# Act
	_press(lobby, input, 1, SimInput.Action.START)

	# Assert
	_assert_eq(lobby.state_of(1), LobbyModel.SlotState.CHOOSING, "slot 1 joined on Start")
	_assert_eq(lobby.cursor_of(1), 1, "slot 1 starts on a different plane from slot 0")
	_assert_eq(lobby.joined_count(), 2, "two slots joined")


func test_lobby_model_nav_wraps_and_moves_only_its_own_slot() -> void:
	# Arrange
	var lobby := _make()
	lobby.open(0)
	lobby.open(1)
	var input := SimInput.new()
	var count := lobby.cards.size()

	# Act: slot 0 steps left off the first card
	_move(lobby, input, 0, -1)
	var wrapped := lobby.cursor_of(0)
	var untouched := lobby.cursor_of(1)

	# Assert
	_assert_eq(wrapped, count - 1, "cursor wrapped from the first card to the last")
	_assert_eq(untouched, 1, "slot 1's cursor did not move")


func test_lobby_model_held_direction_repeats_on_the_input_cadence() -> void:
	# Arrange
	var lobby := _make()
	lobby.open(0)
	var input := SimInput.new()
	var count := lobby.cards.size()

	# Act: hold right for exactly as long as the first repeat needs
	var moves := 0
	var last := lobby.cursor_of(0)
	for _t: int in range(lobby.rules.nav_repeat_first + 1):
		input.begin_tick()
		_release_all(input)
		input.set_move(0, 1, 0)
		lobby.tick(input)
		if lobby.cursor_of(0) != last:
			moves += 1
			last = lobby.cursor_of(0)

	# Assert
	_assert_eq(moves, 2, "one move on the press, one when the first repeat lands")
	_assert_eq(last, 2 % count, "the cursor advanced twice")


func test_lobby_model_confirm_locks_and_cancel_steps_back_out() -> void:
	# Arrange
	var lobby := _make()
	lobby.open(0)
	var input := SimInput.new()

	# Act / Assert: Fire locks
	_press(lobby, input, 0, SimInput.Action.FIRE)
	_assert_eq(lobby.state_of(0), LobbyModel.SlotState.LOCKED, "Fire locked the plane")
	_assert(lobby.is_ready(), "one joined, one locked, so the lobby is ready")

	# Act / Assert: Bomb unlocks, a second Bomb leaves
	_press(lobby, input, 0, SimInput.Action.BOMB)
	_assert_eq(lobby.state_of(0), LobbyModel.SlotState.CHOOSING, "Bomb unlocked")
	_assert(not lobby.is_ready(), "an unlocked slot is not ready")


func test_lobby_model_last_slot_cancelling_abandons_the_lobby() -> void:
	# Arrange
	var lobby := _make()
	lobby.open(0)
	var input := SimInput.new()

	# Act: the only slot cancels out of Choosing
	_press(lobby, input, 0, SimInput.Action.BOMB)

	# Assert
	_assert_eq(lobby.state_of(0), LobbyModel.SlotState.EMPTY, "the slot was released")
	_assert(lobby.abandoned, "an empty lobby goes back to Title")


func test_lobby_model_commits_only_after_the_start_delay() -> void:
	# Arrange
	var lobby := _make()
	lobby.open(0)
	var input := SimInput.new()
	_press(lobby, input, 0, SimInput.Action.FIRE)

	# Act: idle ticks while ready, up to the tick before the bar fills.
	# The Confirm press and its release are already two ready ticks.
	var committed_early := false
	while lobby.commit_ticks < lobby.rules.start_delay_ticks - 1:
		_idle(lobby, input)
		committed_early = committed_early or lobby.committed
	_idle(lobby, input)

	# Assert
	_assert(not committed_early, "no commit before the start delay elapsed")
	_assert(lobby.committed, "committed on the start_delay_ticks-th ready tick")
	_assert_eq(lobby.commit_ticks, lobby.rules.start_delay_ticks, "the bar filled exactly")


func test_lobby_model_a_new_join_resets_the_countdown() -> void:
	# Arrange
	var lobby := _make()
	lobby.open(0)
	var input := SimInput.new()
	_press(lobby, input, 0, SimInput.Action.FIRE)
	for _t: int in range(20):
		_idle(lobby, input)
	var before := lobby.commit_ticks

	# Act: a second player presses Start mid-countdown
	_press(lobby, input, 1, SimInput.Action.START)

	# Assert
	_assert(before > 0, "the countdown had started")
	_assert_eq(lobby.commit_ticks, 0, "a new join reset the countdown")
	_assert(not lobby.is_ready(), "the new slot has not locked yet")


func test_lobby_model_duplicate_planes_get_different_colourways() -> void:
	# Arrange: three slots all pick card 0
	var lobby := _make()
	var input := SimInput.new()
	for slot: int in range(3):
		lobby.open(slot, 0)
		_press(lobby, input, slot, SimInput.Action.FIRE)

	# Act
	var kinds := [lobby.kind_of(0), lobby.kind_of(1), lobby.kind_of(2)]
	var colours := [lobby.colourway_of(0), lobby.colourway_of(1), lobby.colourway_of(2)]

	# Assert
	_assert_eq(kinds[0], kinds[1], "slots 0 and 1 fly the same plane")
	_assert_eq(kinds[1], kinds[2], "slot 2 flies it too")
	_assert_eq(colours, [0, 1, 2], "each duplicate gets its own colourway")
	_assert_eq(lobby.duplicate_rank_of(0), 0, "the first pick is rank 0")
	_assert_eq(lobby.duplicate_rank_of(1), 1, "the second pick is rank 1")
	_assert_eq(lobby.duplicate_rank_of(2), 2, "the third pick is rank 2")
	_assert(lobby.is_shared(0), "the card is shared")


func test_lobby_model_selections_carry_slot_kind_and_colourway_in_slot_order() -> void:
	# Arrange: slot 2 locks card 1, slot 0 locks card 0, slot 1 only hovers
	var lobby := _make()
	var input := SimInput.new()
	lobby.open(2, 1)
	_press(lobby, input, 2, SimInput.Action.FIRE)
	lobby.open(0, 0)
	_press(lobby, input, 0, SimInput.Action.FIRE)
	lobby.open(1, 0)

	# Act
	var picks := lobby.selections()

	# Assert
	_assert_eq(picks.size(), 2, "only locked slots are in the run")
	_assert_eq(int(picks[0]["slot"]), 0, "slot order, not lock order")
	_assert_eq(int(picks[1]["slot"]), 2, "slot 2 second")
	_assert_eq(int(picks[0]["kind"]), lobby.cards[0].kit_kind, "slot 0's kit")
	_assert_eq(int(picks[1]["kind"]), lobby.cards[1].kit_kind, "slot 2's kit")
	_assert_eq(int(picks[1]["colourway"]), 2, "slot 2 flies colourway 2")
	_assert_eq(String(picks[0]["plane_id"]), lobby.cards[0].plane_id, "plane id carried")


func test_lobby_model_afk_choosing_slot_is_released_once_someone_is_locked() -> void:
	# Arrange: slot 0 locked, slot 1 joined and then silent
	var lobby := _make()
	var input := SimInput.new()
	lobby.open(0)
	lobby.open(1)
	_press(lobby, input, 0, SimInput.Action.FIRE)

	# Act
	for _t: int in range(lobby.rules.afk_release_ticks + 1):
		_idle(lobby, input)

	# Assert
	_assert_eq(lobby.state_of(1), LobbyModel.SlotState.EMPTY, "the AFK slot was released")
	_assert_eq(lobby.state_of(0), LobbyModel.SlotState.LOCKED, "the locked slot stayed")


func test_lobby_model_a_quiet_lobby_returns_to_title() -> void:
	# Arrange: one slot Choosing, nobody locked, so no AFK release applies
	var lobby := _make()
	var input := SimInput.new()
	lobby.open(0)

	# Act
	var warned_before_leaving := false
	for _t: int in range(lobby.rules.lobby_idle_ticks):
		_idle(lobby, input)
		if lobby.idle_warning() and not lobby.abandoned:
			warned_before_leaving = true

	# Assert
	_assert(warned_before_leaving, "the warning bar showed before the lobby left")
	_assert(lobby.abandoned, "a lobby nobody touched returns to Title")


# --- helpers ------------------------------------------------------------------

func _make() -> LobbyModel:
	return LobbyModel.new(_cards(), _rules())


## The shipped card set, so the test fails if the data file stops listing four
## planes with distinct kits.
func _cards() -> PlaneCardSet:
	var set := load("res://data/menus/plane_cards.tres") as PlaneCardSet
	assert(set != null, "data/menus/plane_cards.tres is missing")
	assert(set.available_cards().size() == 4, "expected four available planes")
	return set


func _rules() -> LobbyRules:
	return load("res://data/menus/lobby_rules.tres") as LobbyRules


## One tick with nothing held (which arms the slot, see LobbyModel._armed),
## one with the button pressed, then one with it released so the next press is
## a fresh edge.
func _press(lobby: LobbyModel, input: SimInput, slot: int, action: int) -> void:
	_idle(lobby, input)
	input.begin_tick()
	_release_all(input)
	input.set_button(slot, action, true)
	lobby.tick(input)
	_idle(lobby, input)


## One tick with a direction held, then one neutral tick.
func _move(lobby: LobbyModel, input: SimInput, slot: int, dir: int) -> void:
	input.begin_tick()
	_release_all(input)
	input.set_move(slot, dir, 0)
	lobby.tick(input)
	_idle(lobby, input)


func _idle(lobby: LobbyModel, input: SimInput) -> void:
	input.begin_tick()
	_release_all(input)
	lobby.tick(input)


## The sampler writes every button's level every tick, so a test has to write
## the "not held" levels too — `begin_tick` keeps the held mask on purpose.
func _release_all(input: SimInput) -> void:
	for slot: int in range(LobbyModel.MAX_SLOTS):
		for action: int in range(SimInput.ACTION_COUNT):
			input.set_button(slot, action, false)


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
