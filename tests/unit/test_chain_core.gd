extends SceneTree
## Unit tests for ChainCore (design/gdd/chain-tracker.md).
##
## Where the GDD states a worked example, the test asserts that exact example,
## so the implementation is checked against the design rather than against
## itself.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_chain_core.gd
## Exit code 0 = pass, 1 = fail.

var _failures := 0


func _init() -> void:
	test_chain_core_hit_increments_count()
	test_chain_core_window_refills_on_every_hit()
	test_chain_core_expires_exactly_w_hit_free_ticks_after_the_last_hit()
	test_chain_core_hit_on_the_drop_tick_saves_the_chain()
	test_chain_core_expiry_is_a_pure_reset_to_zero()
	test_chain_core_count_is_capped()
	test_chain_core_critical_break_matches_gdd_examples()
	test_chain_core_critical_break_at_zero_pays_the_flat_add()
	test_chain_core_critical_break_returns_uncapped_raw_for_scoring()
	test_chain_core_milestones_fire_for_every_threshold_crossed()
	test_chain_core_frozen_chain_neither_ticks_down_nor_expires()
	test_chain_core_team_chain_needs_two_members_and_a_live_boss()
	test_chain_core_team_chain_breaks_if_an_active_slot_is_not_a_member()
	test_chain_core_team_chain_window_grows_with_player_count()
	test_chain_core_boss_peak_records_the_high_water_mark()
	test_chain_core_red_zone_is_the_last_quarter_of_the_window()
	test_chain_core_same_inputs_produce_same_state_hash()

	print("ChainCore tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _rules() -> ChainRules:
	var r := ChainRules.new()
	r.chain_window = 60
	r.team_window = 60
	r.team_window_step = 8
	r.chain_cap = 999
	r.cb_mult = 3
	r.cb_add = 50
	r.part_kill_chain = 5
	r.milestones = PackedInt32Array([50, 100, 200])
	return r


func _make() -> Array:
	var log := TickEventLog.new(512)
	return [ChainCore.new(_rules(), log), log]


## Ticks the chain the way SimWorld does: the event log rotates each tick, so
## it never accumulates more than one tick's events.
func _tick(chain: ChainCore, log: TickEventLog, active: PackedInt32Array,
		boss_alive: bool = false) -> void:
	log.rotate()
	chain.tick(active, boss_alive)


func _solo() -> PackedInt32Array:
	return PackedInt32Array([1, 0, 0, 0])


func _assert_eq(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		print("  FAIL %s: expected %s, got %s" % [what, expected, actual])
		_failures += 1


func _assert_true(value: bool, what: String) -> void:
	if not value:
		print("  FAIL %s: expected true" % what)
		_failures += 1


# --- tests -------------------------------------------------------------------

func test_chain_core_hit_increments_count() -> void:
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]

	# Act
	chain.add_hit(0)
	chain.tick(_solo())

	# Assert
	_assert_eq(chain.count_of(0), 1, "count after one hit")
	_assert_eq(chain.window_left_of(0), 60, "window refilled to W")


func test_chain_core_window_refills_on_every_hit() -> void:
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	chain.add_hit(0)
	chain.tick(_solo())

	# Act: let it run down a little, then hit again
	for _i: int in range(20):
		chain.tick(_solo())
	_assert_eq(chain.window_left_of(0), 40, "window ran down")
	chain.add_hit(0)
	chain.tick(_solo())

	# Assert
	_assert_eq(chain.window_left_of(0), 60, "window refilled by the new hit")
	_assert_eq(chain.count_of(0), 2, "count rose")


func test_chain_core_expires_exactly_w_hit_free_ticks_after_the_last_hit() -> void:
	# GDD F2 worked example: a hit leaves 60 at the end of its tick, 1 at the
	# end of the 59th tick after, and drops at the end of the 60th.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	chain.add_hit(0)
	chain.tick(_solo())

	# Act: 59 hit-free ticks
	for _i: int in range(59):
		chain.tick(_solo())
	var left_before_drop := chain.window_left_of(0)
	var count_before_drop := chain.count_of(0)
	chain.tick(_solo())

	# Assert
	_assert_eq(left_before_drop, 1, "1 tick left after 59 hit-free ticks")
	_assert_eq(count_before_drop, 1, "chain still alive at that point")
	_assert_eq(chain.count_of(0), 0, "drops on the 60th hit-free tick")


func test_chain_core_hit_on_the_drop_tick_saves_the_chain() -> void:
	# GDD F2: "a hit on tick 160 is applied first and saves it."
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	chain.add_hit(0)
	chain.tick(_solo())
	for _i: int in range(59):
		chain.tick(_solo())

	# Act: the hit lands on the very tick the chain would otherwise drop
	chain.add_hit(0)
	chain.tick(_solo())

	# Assert
	_assert_eq(chain.count_of(0), 2, "chain survived and counted the hit")
	_assert_eq(chain.window_left_of(0), 60, "window refilled")


func test_chain_core_expiry_is_a_pure_reset_to_zero() -> void:
	# GDD Rule 5: no decay — it resets to zero outright.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	var log: TickEventLog = parts[1]
	for _i: int in range(200):
		chain.add_hit(0)
		chain.tick(_solo())
	_assert_eq(chain.count_of(0), 200, "built a 200 chain")

	# Act
	log.rotate()
	for _i: int in range(61):
		chain.tick(_solo())

	# Assert
	_assert_eq(chain.count_of(0), 0, "reset straight to zero, not decayed")
	_assert_true(log.has(TickEventLog.Kind.CHAIN_EXPIRED), "CHAIN_EXPIRED logged")


func test_chain_core_count_is_capped() -> void:
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]

	# Act: more hits than the cap
	var log: TickEventLog = parts[1]
	for _i: int in range(1200):
		chain.add_hit(0)
		_tick(chain, log, _solo())

	# Assert
	_assert_eq(chain.count_of(0), 999, "count clamped at chain_cap")
	_assert_true(chain.is_at_cap(0), "reports being at the cap")


func test_chain_core_critical_break_matches_gdd_examples() -> void:
	# GDD F4 examples: 50 -> 200, 100 -> 350, 150 -> 500, 200 -> 650,
	# and 317 -> 999 (raw 1001, clamped).
	var cases := [[50, 200], [100, 350], [150, 500], [200, 650], [317, 999]]
	for case: Array in cases:
		# Arrange
		var parts := _make()
		var chain: ChainCore = parts[0]
		for _i: int in range(case[0]):
			chain.add_hit(0)
			chain.tick(_solo())

		# Act
		chain.apply_critical_break(0)

		# Assert
		_assert_eq(chain.count_of(0), case[1], "CB from %d" % case[0])


func test_chain_core_critical_break_at_zero_pays_the_flat_add() -> void:
	# GDD Edge Cases: a break at chain 0 gives cb_add.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]

	# Act
	chain.apply_critical_break(0)

	# Assert
	_assert_eq(chain.count_of(0), 50, "CB at 0 gives cb_add")


func test_chain_core_critical_break_returns_uncapped_raw_for_scoring() -> void:
	# Scoring F4 pays on the raw value even past the 999 cap, so the return
	# value must NOT be clamped.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	for _i: int in range(400):
		chain.add_hit(0)
		chain.tick(_solo())

	# Act
	var raw := chain.apply_critical_break(0)

	# Assert
	_assert_eq(raw, 1250, "raw = 400 * 3 + 50, uncapped")
	_assert_eq(chain.count_of(0), 999, "but the chain itself caps at 999")


func test_chain_core_milestones_fire_for_every_threshold_crossed() -> void:
	# GDD F5 example: a Critical Break from 40 to 170 emits 50 then 100,
	# but not 200.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	var log: TickEventLog = parts[1]
	for _i: int in range(40):
		chain.add_hit(0)
		chain.tick(_solo())
	log.rotate()

	# Act: 40 * 3 + 50 = 170
	chain.apply_critical_break(0)

	# Assert: milestone events carry the threshold as their value
	var fired := []
	for i: int in range(log.size()):
		var v := log.value_at(i)
		if log.kind_at(i) == TickEventLog.Kind.CHAIN_HIT and (v == 50 or v == 100 or v == 200):
			fired.append(v)
	_assert_true(fired.has(50), "milestone 50 fired")
	_assert_true(fired.has(100), "milestone 100 fired")
	_assert_true(not fired.has(200), "milestone 200 did not fire")


func test_chain_core_frozen_chain_neither_ticks_down_nor_expires() -> void:
	# GDD Rule 9: the tally freezes the chain, records it, then drops it.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	for _i: int in range(30):
		chain.add_hit(0)
		chain.tick(_solo())

	# Act
	chain.set_frozen(true)
	for _i: int in range(300):
		chain.tick(_solo())

	# Assert
	_assert_eq(chain.count_of(0), 30, "count held while frozen")
	_assert_eq(chain.window_left_of(0), 60, "window did not run down")


func test_chain_core_team_chain_needs_two_members_and_a_live_boss() -> void:
	# GDD F3 worked example: P1 hits the boss at tick 200, P2 at 240; at the
	# end of 240 both are members, so the team chain starts.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	var active := PackedInt32Array([1, 1, 0, 0])

	# Act
	chain.add_hit(0, true, 2)
	chain.tick(active, true)
	_assert_true(not chain.is_team_chain(), "one member is not a team chain")
	for _i: int in range(39):
		chain.tick(active, true)
	chain.add_hit(1, true, 2)
	chain.tick(active, true)

	# Assert
	_assert_true(chain.is_team_chain(), "two members with a live boss")

	# And it ends when the first member's window lapses
	for _i: int in range(25):
		chain.tick(active, true)
	_assert_true(not chain.is_team_chain(), "ends when P1's membership lapses")


func test_chain_core_team_chain_breaks_if_an_active_slot_is_not_a_member() -> void:
	# GDD F3: EVERY Active slot must be a member — one idle player breaks it.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	var active := PackedInt32Array([1, 1, 1, 0])

	# Act: only two of the three Active slots hit the boss
	chain.add_hit(0, true, 3)
	chain.add_hit(1, true, 3)
	chain.tick(active, true)

	# Assert
	_assert_true(not chain.is_team_chain(), "third Active slot is idle, so no team chain")

	# Once it joins in, the team chain forms
	chain.add_hit(2, true, 3)
	chain.tick(active, true)
	_assert_true(chain.is_team_chain(), "all three Active slots are members")


func test_chain_core_team_chain_window_grows_with_player_count() -> void:
	# Co-op F3: 60 / 68 / 76 ticks for 2 / 3 / 4 Active.
	# Arrange / Act / Assert
	var expected := {2: 60, 3: 68, 4: 76}
	for active_count: int in expected:
		var parts := _make()
		var chain: ChainCore = parts[0]
		var active := PackedInt32Array([0, 0, 0, 0])
		for s: int in range(active_count):
			active[s] = 1
		# Every Active slot hits, so the team chain is live.
		for s: int in range(active_count):
			chain.add_hit(s, true, active_count)
		chain.tick(active, true)
		# It must survive one tick less than the window, and end on it.
		var window: int = expected[active_count]
		for _i: int in range(window - 1):
			chain.tick(active, true)
		_assert_true(
			chain.is_team_chain(), "%dP team chain alive just before %d ticks" % [active_count, window]
		)
		chain.tick(active, true)
		_assert_true(
			not chain.is_team_chain(), "%dP team chain ended at %d ticks" % [active_count, window]
		)


func test_chain_core_boss_peak_records_the_high_water_mark() -> void:
	# GDD Rules 8-10: the boss record is the peak reached while it was alive.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	var active := _solo()

	# Act: climb to 40 on the boss, let it drop, then climb to 25
	for _i: int in range(40):
		chain.add_hit(0, true, 2)
		chain.tick(active, true)
	for _i: int in range(61):
		chain.tick(active, true)
	for _i: int in range(25):
		chain.add_hit(0, true, 2)
		chain.tick(active, true)

	# Assert
	_assert_eq(chain.count_of(0), 25, "current count is the second climb")
	_assert_eq(chain.boss_peak_of(0), 40, "peak kept the high-water mark")


func test_chain_core_red_zone_is_the_last_quarter_of_the_window() -> void:
	# GDD F6: red when window_left * 4 <= W.
	# Arrange
	var parts := _make()
	var chain: ChainCore = parts[0]
	chain.add_hit(0)
	chain.tick(_solo())

	# Act: run down to 16 left, then to 15
	for _i: int in range(44):
		chain.tick(_solo())
	var red_at_16 := chain.is_in_red_zone(0)
	chain.tick(_solo())
	var red_at_15 := chain.is_in_red_zone(0)

	# Assert
	_assert_eq(chain.window_left_of(0), 15, "window ran to 15")
	_assert_true(not red_at_16, "16 left is not yet the red zone")
	_assert_true(red_at_15, "15 left is the red zone (15 * 4 <= 60)")


func test_chain_core_same_inputs_produce_same_state_hash() -> void:
	# Arrange / Act
	var first := _run_scripted()
	var second := _run_scripted()

	# Assert
	_assert_eq(first, second, "state_hash across two identical runs")


func _run_scripted() -> int:
	var parts := _make()
	var chain: ChainCore = parts[0]
	var log: TickEventLog = parts[1]
	var active := PackedInt32Array([1, 1, 0, 0])
	for t: int in range(600):
		log.rotate()
		if t % 3 == 0:
			chain.add_hit(0, t % 2 == 0, 2)
		if t % 5 == 0:
			chain.add_hit(1, true, 2)
		if t == 300:
			chain.apply_critical_break(0)
		if t == 450:
			chain.drop(1)
		chain.tick(active, true)
	return chain.state_hash()
