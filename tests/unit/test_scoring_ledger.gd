extends SceneTree
## Unit tests for ScoringLedger (design/gdd/scoring.md).
##
## Every formula is asserted against the worked example the GDD itself states,
## so the implementation is checked against the design and not against itself.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_scoring_ledger.gd
## Exit code 0 = pass, 1 = fail.

var _failures := 0


func _init() -> void:
	test_scoring_hit_matches_gdd_solo_example()
	test_scoring_hit_matches_gdd_team_examples()
	test_scoring_hit_team_percentage_grows_with_members()
	test_scoring_kills_match_gdd_stage_example()
	test_scoring_kills_are_not_chain_scaled()
	test_scoring_items_match_gdd_examples()
	test_scoring_critical_break_matches_gdd_examples()
	test_scoring_critical_break_pays_on_uncapped_raw_chain()
	test_scoring_life_damage_bonus_pays_per_spare_life()
	test_scoring_stage_end_matches_gdd_competent_example()
	test_scoring_stage_end_omits_no_death_bonus_after_a_death()
	test_scoring_cap_hold_first_thirty_seconds_match_gdd()
	test_scoring_cap_hold_long_streak_matches_gdd_example()
	test_scoring_cap_hold_resets_when_the_chain_drops()
	test_scoring_display_clamps_to_nine_digits_but_storage_does_not()
	test_scoring_breakdown_by_source_adds_up_to_the_total()
	test_scoring_team_score_sums_every_slot()
	test_scoring_extends_land_at_the_gdd_thresholds()

	print("ScoringLedger tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _rules() -> ScoringRules:
	var r := ScoringRules.new()
	r.hit_base = 10
	r.team_pct = 120
	r.team_pct_step = 10
	r.kill_value_small = 200
	r.kill_value_medium = 1000
	r.kill_value_large = 5000
	r.part_value = 5000
	r.boss_value = 100000
	r.gem_base = 100
	r.medal_base = 1000
	r.factor_cap_count = 500
	r.factor_step = 50
	r.cb_unit = 1000
	r.ldb_per_life = 50000
	r.clear_bonus = 100000
	r.no_death_bonus = 200000
	r.life_value = 50000
	r.peak_value = 1300
	r.hold_unit = 500
	r.hold_ramp_s = 30
	r.extend_unit = 3000000
	r.display_cap = 999999999
	r.slot_stage_bound = 31000000
	return r


func _chain_rules() -> ChainRules:
	var r := ChainRules.new()
	r.chain_cap = 999
	r.cb_mult = 3
	r.cb_add = 50
	return r


func _make() -> ScoringLedger:
	return ScoringLedger.new(_rules(), _chain_rules(), TickEventLog.new(4096))


func _flags(values: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(4)
	for i: int in range(mini(values.size(), 4)):
		out[i] = values[i]
	return out


func _assert_eq(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		print("  FAIL %s: expected %s, got %s" % [what, expected, actual])
		_failures += 1


func _assert_true(value: bool, what: String) -> void:
	if not value:
		print("  FAIL %s: expected true" % what)
		_failures += 1


# --- tests -------------------------------------------------------------------

func test_scoring_hit_matches_gdd_solo_example() -> void:
	# GDD F1: "count 150 solo -> 160".
	# Arrange
	var ledger := _make()

	# Act
	var points := ledger.award_hit(0, 150, false)

	# Assert
	_assert_eq(points, 160, "hit at count 150, solo")
	_assert_eq(ledger.score_of(0), 160, "ledger total")


func test_scoring_hit_matches_gdd_team_examples() -> void:
	# GDD F1: count 150 in a team chain -> (160 * 120 + 50) / 100 = 192.
	# And count 7 in a team chain -> 2090 / 100 = 20.
	# Arrange
	var ledger := _make()

	# Act
	var at_150 := ledger.award_hit(0, 150, true, 2)
	var at_7 := ledger.award_hit(1, 7, true, 2)

	# Assert
	_assert_eq(at_150, 192, "hit at count 150 in a 2P team chain")
	_assert_eq(at_7, 20, "hit at count 7 in a 2P team chain")


func test_scoring_hit_team_percentage_grows_with_members() -> void:
	# Co-op F1: 2P 120, 3P 130, 4P 140.
	# Arrange
	var ledger := _make()

	# Act: base at count 150 is 160
	var two := ledger.award_hit(0, 150, true, 2)
	var three := ledger.award_hit(1, 150, true, 3)
	var four := ledger.award_hit(2, 150, true, 4)

	# Assert
	_assert_eq(two, 192, "2P: (160 * 120 + 50) / 100")
	_assert_eq(three, 208, "3P: (160 * 130 + 50) / 100")
	_assert_eq(four, 224, "4P: (160 * 140 + 50) / 100")


func test_scoring_kills_match_gdd_stage_example() -> void:
	# GDD F2: 60 small + 20 medium + 4 large = 12,000 + 20,000 + 20,000.
	# Arrange
	var ledger := _make()

	# Act
	for _i: int in range(60):
		ledger.award_kill(0, ScoringLedger.KillClass.SMALL)
	for _i: int in range(20):
		ledger.award_kill(0, ScoringLedger.KillClass.MEDIUM)
	for _i: int in range(4):
		ledger.award_kill(0, ScoringLedger.KillClass.LARGE)

	# Assert
	_assert_eq(ledger.score_of(0), 52000, "stage kill total")


func test_scoring_kills_are_not_chain_scaled() -> void:
	# GDD F2: "These are flat: no chain scaling and no team multiplier."
	# Arrange
	var ledger := _make()

	# Act: the same kill, once with no chain and once at the cap
	var cold := ledger.award_kill(0, ScoringLedger.KillClass.MEDIUM)
	var hot := ledger.award_kill(1, ScoringLedger.KillClass.MEDIUM)

	# Assert
	_assert_eq(cold, 1000, "medium kill value")
	_assert_eq(hot, cold, "kill value does not depend on the chain")
	_assert_eq(
		ledger.award_kill(0, ScoringLedger.KillClass.CORE), 100000, "boss core value"
	)
	_assert_eq(
		ledger.award_kill(0, ScoringLedger.KillClass.PART), 5000, "boss part value"
	)


func test_scoring_items_match_gdd_examples() -> void:
	# GDD F3: a medal at count 237 -> 5,000; at 0 -> 1,000; at 999 -> 11,000.
	# Arrange
	var ledger := _make()
	var medal := ledger.rules.medal_base

	# Act / Assert
	_assert_eq(ledger.award_item(0, medal, 237), 5000, "medal at count 237")
	_assert_eq(ledger.award_item(1, medal, 0), 1000, "medal at count 0")
	_assert_eq(ledger.award_item(2, medal, 999), 11000, "medal at count 999 (factor capped)")
	_assert_eq(ledger.award_item(3, ledger.rules.gem_base, 0), 100, "gem at count 0")


func test_scoring_critical_break_matches_gdd_examples() -> void:
	# GDD F4: before 150 -> raw 500 -> 500,000. before 999 -> 3,047,000.
	# Arrange
	var ledger := _make()

	# Act: one life, so no Life Damage Bonus muddies the figure
	var at_150 := ledger.award_critical_break(0, 150, 1)
	var at_999 := ledger.award_critical_break(1, 999, 1)

	# Assert
	_assert_eq(at_150, 500000, "CB at chain 150")
	_assert_eq(at_999, 3047000, "CB at chain 999")


func test_scoring_critical_break_pays_on_uncapped_raw_chain() -> void:
	# GDD F4: "before 400 -> raw 1,250 -> 1,250,000 (the HUD chain shows 999)".
	# The chain caps at 999 but the payment does not.
	# Arrange
	var ledger := _make()

	# Act
	var points := ledger.award_critical_break(0, 400, 1)

	# Assert
	_assert_eq(points, 1250000, "CB pays on the uncapped raw value")
	_assert_true(
		points > ledger.rules.cb_unit * 999,
		"and so exceeds what the capped count would pay"
	)


func test_scoring_life_damage_bonus_pays_per_spare_life() -> void:
	# GDD F4: with 3 lives, LDB = 2 * 50k = 100,000.
	# Arrange
	var ledger := _make()

	# Act
	ledger.award_critical_break(0, 150, 3)

	# Assert
	_assert_eq(
		ledger.score_from(0, ScoringLedger.Source.LIFE_DAMAGE), 100000, "LDB with 3 lives"
	)
	var one_life := _make()
	one_life.award_critical_break(0, 150, 1)
	_assert_eq(
		one_life.score_from(0, ScoringLedger.Source.LIFE_DAMAGE), 0, "no LDB on the last life"
	)


func test_scoring_stage_end_matches_gdd_competent_example() -> void:
	# GDD F5: 100k + 200k + 3 * 50k + 650 * 1,300 = 1,295,000.
	# Arrange
	var ledger := _make()

	# Act
	var points := ledger.award_stage_end(0, 0, 3, 650)

	# Assert
	_assert_eq(points, 1295000, "competent clean stage-end bonus")


func test_scoring_stage_end_omits_no_death_bonus_after_a_death() -> void:
	# Arrange
	var ledger := _make()

	# Act
	var clean := ledger.award_stage_end(0, 0, 3, 650)
	var died := ledger.award_stage_end(1, 1, 3, 650)

	# Assert
	_assert_eq(clean - died, 200000, "the no-death bonus is exactly the difference")


func test_scoring_cap_hold_first_thirty_seconds_match_gdd() -> void:
	# GDD F6: "the first 30 s pay 500 * (1 + ... + 30) = 232,500".
	# Arrange
	var ledger := _make()
	var at_cap := _flags([1, 0, 0, 0])
	var alive := _flags([1, 0, 0, 0])

	# Act: hold the cap for exactly 30 seconds
	for _i: int in range(30 * 60):
		ledger.tick(at_cap, alive, false)

	# Assert
	_assert_eq(ledger.score_of(0), 232500, "30 s of cap-hold")


func test_scoring_cap_hold_long_streak_matches_gdd_example() -> void:
	# GDD F6: "a 95 s streak = 232,500 + 65 * 15,000 = 1,207,500".
	# Arrange
	var ledger := _make()
	var at_cap := _flags([1, 0, 0, 0])
	var alive := _flags([1, 0, 0, 0])

	# Act
	for _i: int in range(95 * 60):
		ledger.tick(at_cap, alive, false)

	# Assert
	_assert_eq(ledger.score_of(0), 1207500, "95 s of cap-hold")


func test_scoring_cap_hold_resets_when_the_chain_drops() -> void:
	# GDD F6: "A drop at 60 s, then a re-climb, restarts the streak at 500/s."
	# Arrange
	var ledger := _make()
	var holding := _flags([1, 0, 0, 0])
	var dropped := _flags([0, 0, 0, 0])
	var alive := _flags([1, 0, 0, 0])
	for _i: int in range(60 * 60):
		ledger.tick(holding, alive, false)
	var after_60s := ledger.score_of(0)

	# Act: the chain drops for a tick, then climbs back to the cap for 1 s
	ledger.tick(dropped, alive, false)
	_assert_eq(ledger.cap_ticks_of(0), 0, "streak reset by the drop")
	for _i: int in range(60):
		ledger.tick(holding, alive, false)

	# Assert
	_assert_eq(
		ledger.score_of(0) - after_60s, 500, "re-climb restarts the ramp at hold_unit"
	)


func test_scoring_display_clamps_to_nine_digits_but_storage_does_not() -> void:
	# GDD F8: displayed = min(score, 999,999,999); storage is int64.
	# Arrange
	var ledger := _make()

	# Act: 400 maximal Critical Breaks push past the display cap
	for _i: int in range(400):
		ledger.award_critical_break(0, 999, 1)

	# Assert
	_assert_true(ledger.score_of(0) > 999999999, "stored score exceeds 9 digits")
	_assert_eq(ledger.display_score(0), 999999999, "display clamps to 9 digits")


func test_scoring_breakdown_by_source_adds_up_to_the_total() -> void:
	# The stage-end tally shows a per-source breakdown, so it must reconcile.
	# Arrange
	var ledger := _make()

	# Act
	ledger.award_hit(0, 50, false)
	ledger.award_kill(0, ScoringLedger.KillClass.LARGE)
	ledger.award_item(0, ledger.rules.medal_base, 100)
	ledger.award_critical_break(0, 100, 3)
	ledger.award_stage_end(0, 0, 2, 300)

	# Assert
	var summed := 0
	for source: int in range(ScoringLedger.SOURCE_COUNT):
		summed += ledger.score_from(0, source)
	_assert_eq(summed, ledger.score_of(0), "per-source totals reconcile with the total")


func test_scoring_team_score_sums_every_slot() -> void:
	# Arrange
	var ledger := _make()

	# Act
	ledger.award_hit(0, 100, false)
	ledger.award_hit(1, 100, false)
	ledger.award_hit(2, 100, false)

	# Assert
	_assert_eq(ledger.score_of(0), 110, "each slot scored 110")
	_assert_eq(ledger.team_score(), 330, "team score is the sum")


func test_scoring_extends_land_at_the_gdd_thresholds() -> void:
	# GDD F7: extend_unit 3,000,000 with Session multipliers 0.8 and 1.0 puts
	# extends at 2,400,000 and 5,400,000.
	# Arrange
	var ledger := _make()

	# Act / Assert
	_assert_eq(ledger.extends_earned(0), 0, "no extend at zero score")
	ledger.award_stage_end(0, 0, 3, 1)       # a little under 2.4M
	_assert_eq(ledger.extends_earned(0), 0, "still none below 2,400,000")
	ledger.award_critical_break(0, 750, 1)   # pushes well past 2.4M
	_assert_true(ledger.score_of(0) >= 2400000, "score passed the first threshold")
	_assert_true(ledger.extends_earned(0) >= 1, "first extend earned")
