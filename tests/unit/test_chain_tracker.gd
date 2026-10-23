extends SceneTree
## Unit tests for ChainTracker (no test framework yet; see /test-setup).
## Run from the project folder (after opening the project once in the editor):
##   godot --headless --script res://tests/unit/test_chain_tracker.gd
## Exit code 0 = pass, 1 = fail.

var _failures := 0


func _init() -> void:
	test_chain_tracker_add_hits_increments_count()
	test_chain_tracker_tick_inside_window_keeps_chain()
	test_chain_tracker_hit_refreshes_window()
	test_chain_tracker_window_expires_resets_to_zero()
	test_chain_tracker_critical_break_applies_formula()
	print("ChainTracker tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _make_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.chain_window = 1.0
	rules.break_mult = 3
	rules.break_add = 50
	return rules


func test_chain_tracker_add_hits_increments_count() -> void:
	# Arrange
	var chain := ChainTracker.new(_make_rules())
	# Act
	chain.add_hits()
	chain.add_hits()
	# Assert
	_assert_eq(chain.count, 2, "add_hits increments count")


func test_chain_tracker_tick_inside_window_keeps_chain() -> void:
	# Arrange
	var chain := ChainTracker.new(_make_rules())
	chain.add_hits(2)
	# Act
	chain.tick(0.5)
	# Assert
	_assert_eq(chain.count, 2, "chain survives inside the window")


func test_chain_tracker_hit_refreshes_window() -> void:
	# Arrange
	var chain := ChainTracker.new(_make_rules())
	chain.add_hits()
	chain.tick(0.9)
	# Act
	chain.add_hits()
	chain.tick(0.9)
	# Assert
	_assert_eq(chain.count, 2, "a new hit refreshes the window")


func test_chain_tracker_window_expires_resets_to_zero() -> void:
	# Arrange
	var chain := ChainTracker.new(_make_rules())
	chain.add_hits(3)
	# Act
	chain.tick(1.01)
	# Assert
	_assert_eq(chain.count, 0, "pure reset when the window runs out")
	_assert_eq(chain.last_dropped, 3, "last_dropped remembers the chain")
	_assert_eq(chain.max_count, 3, "max_count survives the reset")


func test_chain_tracker_critical_break_applies_formula() -> void:
	# Arrange
	var chain := ChainTracker.new(_make_rules())
	chain.add_hits(10)
	# Act
	var final_chain := chain.apply_critical_break()
	# Assert
	_assert_eq(final_chain, 80, "10 * 3 + 50")
	_assert_eq(chain.max_count, 80, "max_count updated by the break")


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s (expected %s, got %s)" % [label, expected, actual])
