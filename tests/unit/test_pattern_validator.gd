extends SceneTree
## The F8 fairness validator, the F9 density budget and the F10 migration
## golden table (design/gdd/bullet-pattern-library.md, AC-46 - AC-52).
##
## This is the authoring gate: every pattern shipped in `data/patterns/` must
## pass it with zero errors, or the content is unfair by the design's own
## measures.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_pattern_validator.gd

var _failures := 0

const FAN := PatternDef.Kind.AIMED_FAN
const RING := PatternDef.Kind.RING
const SPIRAL := PatternDef.Kind.SPIRAL
const WALL := PatternDef.Kind.WALL
const CURVE := PatternDef.Kind.RADIAL_CURVE
const FLAK := PatternDef.Kind.FLAK_BURST
const SPRAY := PatternDef.Kind.SPRAY

var _rules: PatternRules
var _bullets: BulletRules


func _init() -> void:
	_rules = load("res://data/pattern_rules.tres")
	_bullets = load("res://data/bullet_rules.tres")

	test_pattern_every_authored_pattern_passes_the_validator()
	test_pattern_validator_catches_closing_lanes()
	test_pattern_validator_catches_unreadable_walls()
	test_pattern_validator_catches_unfair_flak_and_spray()
	test_pattern_validator_catches_burst_overlap_and_bad_locks()
	test_pattern_validator_catches_a_spawn_radius_too_small_for_the_speed()
	test_pattern_authored_data_reports_the_gdd_fairness_margins()
	test_pattern_migrated_data_matches_the_f10_golden_table()
	test_pattern_density_matches_the_f9_worked_examples()
	test_pattern_density_catches_a_runner_and_a_gate_overlap()

	print("PatternValidator tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- AC-46 -------------------------------------------------------------------

func test_pattern_every_authored_pattern_passes_the_validator() -> void:
	var names := _pattern_names()
	_assert(names.size() >= 11, "the F10 table's 11 patterns are authored (found %d)" % names.size())
	var warnings := 0
	for name: String in names:
		var d := PatternHarness.pattern(name)
		if d == null:
			_failures += 1
			print("FAIL: %s did not load" % name)
			continue
		for problem: String in PatternMetrics.validate(d, _rules, _bullets):
			if problem.begins_with("ERROR"):
				_failures += 1
				print("FAIL: %s" % problem)
			else:
				warnings += 1
				print("warn: %s" % problem)
	print("  validator: %d patterns, %d warnings" % [names.size(), warnings])


# --- AC-47 -------------------------------------------------------------------

func test_pattern_validator_catches_closing_lanes() -> void:
	# Fan lane: 0.165 rad at d_ref 160 leaves 21.4 px; 0.11 leaves 12.6.
	_assert_close(
		PatternMetrics.fan_lane_clear(0.165, _rules.d_ref, 2.5), 21.4, "fan lane at spread 0.165"
	)
	_assert_close(
		PatternMetrics.fan_lane_clear(0.11, _rules.d_ref, 2.5), 12.6, "fan lane at spread 0.11"
	)
	_assert_clean(PatternHarness.make(FAN, {"count": 5, "spread_rad": 0.165}), "a 0.165 fan")
	_assert_error(PatternHarness.make(FAN, {"count": 5, "spread_rad": 0.11}), "a 0.11 fan")

	# Ring lane at 120 px: 39 bullets pass, 40 do not.
	_assert_eq(
		PatternMetrics.ring_count_limit(_rules.lane_measure_distance, _rules.lane_min_clear, 2.5),
		39,
		"an orb ring may have 39 bullets at 120 px"
	)
	_assert_clean(_ring(39), "a 39-bullet ring")
	_assert_error(_ring(40), "a 40-bullet ring")

	# Flak ring lanes are measured at the standoff instead: 18 pass, 19 do not.
	_assert_eq(
		PatternMetrics.ring_count_limit(56.0, _rules.lane_min_clear, 2.5), 18,
		"a flak ring at standoff 56 may have 18 bullets"
	)
	_assert_clean(_flak(18), "an 18-bullet flak ring")
	_assert_error(_flak(19), "a 19-bullet flak ring")

	# Spiral arms: a fast, wide-stepped single arm is clear; a slow 6-arm
	# spiral at a full radian per volley closes on itself.
	_assert_close(
		PatternMetrics.spiral_arm_gap(150.0, 7, 0.33, 1, 2.5), 328.2, "spiral arm gap", 0.5
	)
	_assert_close(
		PatternMetrics.spiral_arm_gap(70.0, 3, 1.0, 6, 2.5), -1.3, "a 6-arm spiral's arm gap", 0.1
	)
	_assert_error(
		PatternHarness.make(SPIRAL, {
			"interval": 3, "arms": 6, "step_rad": 1.0, "speed": 70.0,
		}),
		"a 6-arm spiral at step 1.0"
	)


func test_pattern_validator_catches_unreadable_walls() -> void:
	# Corridor: spacing 16 leaves 27 px, 12 warns, 8 is an error.
	_assert_close(PatternMetrics.wall_corridor(1, 16.0, 2.5), 27.0, "wall corridor at spacing 16")
	_assert_close(PatternMetrics.wall_corridor(1, 12.0, 2.5), 19.0, "wall corridor at spacing 12")
	_assert_close(PatternMetrics.wall_corridor(1, 8.0, 2.5), 11.0, "wall corridor at spacing 8")
	_assert_clean(_wall(16.0, 110.0, 138), "a 16 px wall")
	_assert_warn(_wall(12.0, 110.0, 138), "a 12 px wall")
	_assert_error(_wall(8.0, 110.0, 138), "an 8 px wall")

	# Speed: a wall the player cannot outrun to the gap.
	_assert_clean(_wall(16.0, 110.0, 138), "a 110 px/s wall")
	_assert_error(_wall(16.0, 206.0, 138), "a 206 px/s wall")

	# Reach: 18 ticks to react plus 360 px at 3.5 px/tick is 121 ticks.
	_assert_clean(_wall(16.0, 110.0, 121), "a wall with 121 ticks between volleys")
	_assert_error(_wall(16.0, 110.0, 120), "a wall with 120 ticks between volleys")


func test_pattern_validator_catches_unfair_flak_and_spray() -> void:
	var short_fuse := _flak(12)
	short_fuse.flak_delay = 17
	_assert_error(short_fuse, "a 17-tick flak fuse")
	var min_fuse := _flak(12)
	min_fuse.flak_delay = 18
	_assert_clean(min_fuse, "an 18-tick flak fuse")

	var close_burst := _flak(12)
	close_burst.standoff = 49.0
	_assert_error(close_burst, "a standoff of 49 at spawn radius 42")
	var ok_burst := _flak(12)
	ok_burst.standoff = 50.0
	_assert_clean(ok_burst, "a standoff of 50")

	# Spray: arc 1.2 and jitter 0.5 fit 5 bullets, not 6.
	_assert_eq(
		PatternMetrics.spray_count_limit(1.2, 0.5, _rules.d_ref, _rules.lane_min_clear, 2.5), 5,
		"a 1.2 rad spray with jitter 0.5 fits 5 bullets"
	)
	_assert_clean(_spray(5), "a 5-bullet spray")
	_assert_error(_spray(6), "a 6-bullet spray")
	var closing := _spray(4)
	closing.jitter = 1.0
	_assert_error(closing, "a spray with jitter 1.0")


func test_pattern_validator_catches_burst_overlap_and_bad_locks() -> void:
	var fits := PatternHarness.make(FAN, {
		"count": 1, "burst_count": 6, "burst_gap": 6, "interval": 84,
	})
	_assert_clean(fits, "a 6 x 6 burst inside an 84-tick interval")
	var overlaps := PatternHarness.make(FAN, {
		"count": 1, "burst_count": 6, "burst_gap": 6, "interval": 30,
	})
	_assert_error(overlaps, "a 6 x 6 burst inside a 30-tick interval")
	var overlaps_at_full := PatternHarness.make(FAN, {
		"count": 1, "burst_count": 6, "burst_gap": 6, "interval": 84, "interval_at_full": 30,
	})
	_assert_error(overlaps_at_full, "a burst that only overlaps at full intensity")

	var long_lock := PatternHarness.make(FAN, {
		"count": 1, "interval": 30, "lock_ticks": 30, "start_delay": 48,
	})
	_assert_error(long_lock, "a lock as long as the interval")
	var both := PatternHarness.make(FAN, {
		"count": 1, "interval": 120, "lock_ticks": 30, "reaim_each_volley": true,
	})
	_assert_error(both, "a pattern that both locks and re-aims")
	var unreadable := PatternHarness.make(FAN, {
		"count": 1, "interval": 120, "lock_ticks": 12, "start_delay": 48,
	})
	_assert_warn(unreadable, "a 12-tick lock tell")


func test_pattern_validator_catches_a_spawn_radius_too_small_for_the_speed() -> void:
	# F7: a 480 px/s needle needs 76.25 px of warning.
	_assert_close(
		PatternMetrics.required_safe_radius(3.0, 1.25, 480.0, _rules.react_ticks), 76.25,
		"a 480 px/s needle needs 76.25 px"
	)
	var needle := PatternHarness.make(FAN, {
		"count": 1, "speed": 480.0, "shape": BulletRules.Shape.NEEDLE,
	})
	_assert_error(needle, "a 480 px/s needle at the default radius")
	needle.spawn_safe_radius = 76.25
	_assert_clean(needle, "the same needle with a 76.25 px override")

	var orb := PatternHarness.make(FAN, {"count": 1, "speed": 240.0})
	_assert_clean(orb, "a 240 px/s orb at the default radius")
	_assert_close(
		PatternMetrics.required_safe_radius(3.0, 2.5, 240.0, _rules.react_ticks), 41.5,
		"and needs 41.5 px, just inside the 42 px default"
	)

	# A pattern may only RAISE the radius.
	var lowered := PatternHarness.make(FAN, {"count": 1, "speed": 150.0})
	lowered.spawn_safe_radius = 30.0
	_assert_error(lowered, "a pattern lowering the spawn-safe radius")


# --- AC-49 -------------------------------------------------------------------

func test_pattern_authored_data_reports_the_gdd_fairness_margins() -> void:
	var min_fan_lane := INF
	for name: String in _pattern_names():
		var d := PatternHarness.pattern(name)
		if d.kind == FAN and maxi(d.count, d.count_at_full) >= 2:
			min_fan_lane = minf(
				min_fan_lane, PatternMetrics.fan_lane_clear(d.spread_rad, _rules.d_ref, 2.5)
			)
	_assert_close(min_fan_lane, 21.4, "the tightest authored fan lane is the GDD's 21.4 px", 0.05)

	var wall := PatternHarness.pattern("jet_wing_wall")
	_assert_close(
		PatternMetrics.wall_corridor(wall.gap_width, wall.spacing, 2.5), 27.0,
		"the wing wall's corridor is 27 px"
	)
	_assert_close(wall.speed, 110.0, "its speed is 110 px/s")
	_assert_eq(wall.interval, 138, "and 138 ticks is time to cross to the gap")

	# The fortress core spiral's arm gap, measured from the shipped data.
	var spiral := PatternHarness.pattern("fortress_core_spiral")
	var gap := PatternMetrics.spiral_arm_gap(
		spiral.speed, spiral.interval, spiral.step_rad, spiral.arms, 2.5
	)
	_assert_close(gap, 150.5, "the merged 2-arm core spiral leaves a 150 px arm gap", 0.5)


# --- AC-50 -------------------------------------------------------------------

func test_pattern_migrated_data_matches_the_f10_golden_table() -> void:
	# The F10 table IS the spec for these numbers, so they are literals here.
	_check("fortress_core_spiral", {
		"kind": SPIRAL, "interval": 7, "interval_at_full": 3, "start_delay": 30, "arms": 2,
	})
	_assert(
		not FileAccess.file_exists("res://data/patterns/fortress_core_spiral_second_arm.tres"),
		"the second spiral arm is merged into arms 2, not a separate runner"
	)
	_check("fortress_core_rage_ring", {"kind": RING, "interval": 66, "start_delay": 18, "count": 24})
	_check("fortress_turret_fan", {"kind": FAN, "spread_rad": 0.21, "interval": 66})
	_check("fortress_engine_ring", {"kind": RING, "interval": 114})

	_check("jet_core_accel_fan", {
		"kind": FAN, "spread_rad": 0.165, "interval": 78, "interval_at_full": 33, "speed": 70.0,
	})
	_check("jet_pod_stream", {"kind": FAN, "interval": 84, "burst_gap": 6})
	_check("jet_wing_wall", {"kind": WALL, "count": 7, "interval": 138, "spacing": 16.0})

	_check("plasma_core_shielded_warp_ring", {"kind": RING, "interval": 108})
	_check("plasma_core_exposed_warp_ring", {"kind": RING, "interval": 72, "start_delay": 1})
	_check("plasma_core_exposed_fan", {
		"kind": FAN, "spread_rad": 0.1875, "interval": 72, "start_delay": 36,
	})
	_check("plasma_shield_curve", {"kind": CURVE, "interval": 10})

	# Speeds carried over from the prototype unchanged (F10: speeds unchanged,
	# minimum 70).
	_check("fortress_core_spiral", {"speed": 140.0})
	_check("fortress_core_rage_ring", {"speed": 110.0})
	_check("fortress_turret_fan", {"speed": 170.0})
	_check("fortress_engine_ring", {"speed": 100.0})
	_check("jet_pod_stream", {"speed": 240.0, "burst_count": 6})
	_check("plasma_core_shielded_warp_ring", {"speed": 90.0})
	_check("plasma_core_exposed_warp_ring", {"speed": 130.0, "count": 20})
	_check("plasma_core_exposed_fan", {"speed": 180.0, "count": 5})
	_check("plasma_shield_curve", {"speed": 120.0, "spin": 1.3})

	# Era behaviour language (V4): 1941 is Straight only, the 1970s core
	# accelerates, 2100 warps.
	for name: String in ["fortress_core_spiral", "fortress_core_rage_ring",
			"fortress_turret_fan", "fortress_engine_ring", "wave_1941_aimed_fan",
			"wave_1941_flak", "wave_1941_wall", "wave_1941_spray"]:
		_assert_eq(
			PatternHarness.pattern(name).behaviour, BulletField.Beh.LINEAR,
			"%s is Straight: 1941 has no other behaviour" % name
		)
	_assert_eq(
		PatternHarness.pattern("jet_core_accel_fan").behaviour, BulletField.Beh.ACCEL,
		"the jet core fan accelerates"
	)
	for name: String in ["plasma_core_shielded_warp_ring", "plasma_core_exposed_warp_ring"]:
		_assert_eq(
			PatternHarness.pattern(name).behaviour, BulletField.Beh.WARP,
			"%s warps" % name
		)


# --- AC-51 -------------------------------------------------------------------

func test_pattern_density_matches_the_f9_worked_examples() -> void:
	# Jet core fan at full intensity: 9 bullets every 33 ticks, 640 px of path
	# at an average 200 px/s.
	var fan := PatternHarness.pattern("jet_core_accel_fan")
	_assert_close(
		PatternMetrics.pattern_density(fan, _rules, _bullets, 1.0), 52.4,
		"the jet core fan sustains 52.4 bullets", 0.1
	)

	# The whole jet, ignoring gates and part deaths: fan + 3 pods + 2 wings.
	var jet := (
		PatternMetrics.pattern_density(fan, _rules, _bullets, 1.0)
		+ 3.0 * PatternMetrics.pattern_density(
			PatternHarness.pattern("jet_pod_stream"), _rules, _bullets, 1.0
		)
		+ 2.0 * PatternMetrics.pattern_density(
			PatternHarness.pattern("jet_wing_wall"), _rules, _bullets, 1.0
		)
	)
	_assert_close(jet, 116.0, "the jet carrier's gate-ignoring total is about 116", 2.0)

	# The fortress at full intensity is its core's two runners.
	var fortress := (
		PatternMetrics.pattern_density(
			PatternHarness.pattern("fortress_core_spiral"), _rules, _bullets, 1.0
		)
		+ PatternMetrics.pattern_density(
			PatternHarness.pattern("fortress_core_rage_ring"), _rules, _bullets, 1.0
		)
	)
	_assert_close(fortress, 155.0, "the fortress core at full intensity is about 155", 3.0)


func test_pattern_density_catches_a_runner_and_a_gate_overlap() -> void:
	# A 24-bullet ring every 6 ticks: 512 live bullets, over the 450 warning.
	var heavy := PatternHarness.make(RING, {"count": 24, "interval": 6, "speed": 150.0})
	_assert_close(
		PatternMetrics.pattern_density(heavy, _rules, _bullets, 0.0), 512.0,
		"a 24-bullet ring at interval 6 sustains 512 bullets", 1.0
	)
	_assert_warn(heavy, "a ring sustaining 512 bullets")

	# Two runners that share a gate bound are both active at that intensity,
	# so the scene budget is the sum there (F9 scope).
	var low := PatternHarness.make(RING, {
		"count": 24, "interval": 3, "speed": 150.0, "min_intensity": 0.0, "max_intensity": 0.5,
	})
	var high := PatternHarness.make(RING, {
		"count": 24, "interval": 4, "speed": 150.0, "min_intensity": 0.5, "max_intensity": 1.0,
	})
	var at_bound := (
		PatternMetrics.pattern_density(low, _rules, _bullets, 0.5)
		+ PatternMetrics.pattern_density(high, _rules, _bullets, 0.5)
	)
	_assert(
		PatternMetrics.gate_open(low, 0.5) and PatternMetrics.gate_open(high, 0.5),
		"gates are inclusive, so both runners are live at the shared bound"
	)
	_assert(
		at_bound > _rules.scene_density_budget,
		"and together they break the %.0f scene budget (%.0f)" % [_rules.scene_density_budget, at_bound]
	)


# --- helpers -----------------------------------------------------------------

func _pattern_names() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("res://data/patterns")
	if dir == null:
		_failures += 1
		print("FAIL: data/patterns is missing")
		return out
	for f: String in dir.get_files():
		# An exported build serves `x.tres` as `x.tres.remap`, so strip that
		# first: the test must list the same patterns from source and from a
		# build.
		var name := f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		out.push_back(name.trim_suffix(".tres"))
	out.sort()
	return out


func _ring(count: int) -> PatternDef:
	return PatternHarness.make(RING, {"count": count, "interval": 120, "speed": 120.0})


func _flak(count: int) -> PatternDef:
	return PatternHarness.make(FLAK, {
		"count": count, "interval": 150, "speed": 120.0, "flak_delay": 36,
		"flak_distance": 240.0, "standoff": 56.0,
	})


func _wall(spacing: float, speed: float, interval: int) -> PatternDef:
	return PatternHarness.make(WALL, {
		"count": 7, "spacing": spacing, "speed": speed, "interval": interval,
	})


func _spray(count: int) -> PatternDef:
	return PatternHarness.make(SPRAY, {
		"count": count, "interval": 90, "arc_rad": 1.2, "jitter": 0.5,
		"speed": 150.0, "speed_min": 120.0, "speed_max": 180.0,
	})


func _problems(d: PatternDef) -> Array[String]:
	return PatternMetrics.validate(d, _rules, _bullets)


func _check(name: String, want: Dictionary) -> void:
	var d := PatternHarness.pattern(name)
	if d == null:
		_failures += 1
		print("FAIL: %s did not load" % name)
		return
	for key: String in want:
		var got: Variant = d.get(key)
		var expected: Variant = want[key]
		var same := false
		if expected is float:
			same = absf(float(got) - float(expected)) < 0.0001
		else:
			same = got == expected
		if not same:
			_failures += 1
			print("FAIL: %s.%s is %s, F10 says %s" % [name, key, got, expected])


# --- assertions --------------------------------------------------------------

func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])


func _assert_close(got: float, want: float, what: String, tol := 0.05) -> void:
	if absf(got - want) > tol:
		_failures += 1
		print("FAIL: %s -- got %.4f, want %.4f (+/- %.3f)" % [what, got, want, tol])


func _assert_clean(d: PatternDef, what: String) -> void:
	for problem: String in _problems(d):
		if problem.begins_with("ERROR"):
			_failures += 1
			print("FAIL: %s should pass the validator -- %s" % [what, problem])


func _assert_error(d: PatternDef, what: String) -> void:
	for problem: String in _problems(d):
		if problem.begins_with("ERROR"):
			return
	_failures += 1
	print("FAIL: %s should be an ERROR, but the validator passed it" % what)


func _assert_warn(d: PatternDef, what: String) -> void:
	var warned := false
	for problem: String in _problems(d):
		if problem.begins_with("ERROR"):
			_failures += 1
			print("FAIL: %s should only warn -- %s" % [what, problem])
		else:
			warned = true
	if not warned:
		_failures += 1
		print("FAIL: %s should produce a warning, but the validator was silent" % what)
