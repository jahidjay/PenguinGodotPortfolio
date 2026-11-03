extends SceneTree
## Unit tests for the determinism foundation: SimMath, SimHash, SimRng
## (docs/architecture/adr-0003-determinism-and-replays.md).
##
## These three ship BEFORE the pattern, enemy and boss code (ADR-0003's
## Ordering Note) so no banned `sin`/`atan2`/`hash()` call has to be ripped
## out of gameplay code later.
##
## Where a GDD states a worked example (the aim angle in bullet-pattern-
## library.md F5), the test asserts that exact example, so the implementation
## is checked against the design rather than against itself.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_sim_foundation.gd
## Exit code 0 = pass, 1 = fail.

var _failures := 0


func _init() -> void:
	test_sim_math_sin_is_exact_at_the_cardinal_angles()
	test_sim_math_sin_matches_the_platform_sine_within_table_resolution()
	test_sim_math_cos_is_the_sine_a_quarter_turn_ahead()
	test_sim_math_angles_wrap_over_the_whole_int_range()
	test_sim_math_atan2_matches_the_pattern_library_f5_example()
	test_sim_math_atan2_is_correct_in_every_quadrant()
	test_sim_math_atan2_of_the_zero_vector_is_zero()
	test_sim_math_atan2_round_trips_every_angle_within_one_bam()
	test_sim_math_rad_to_bam_round_trips_authored_values()
	test_sim_math_delta_bam_takes_the_short_way_round()
	test_sim_math_quantise_snaps_to_one_sixteenth_of_a_pixel()
	test_sim_math_length_matches_the_pythagorean_result()
	test_sim_hash_the_same_parts_give_the_same_seed()
	test_sim_hash_different_parts_give_different_seeds()
	test_sim_hash_length_prefixes_stop_string_collisions()
	test_sim_hash_digest32_changes_when_any_field_changes()
	test_sim_hash_array_prefix_ignores_rows_past_the_live_count()
	test_sim_rng_a_stream_is_reproducible_from_its_parts()
	test_sim_rng_each_owner_gets_an_independent_stream()
	test_sim_rng_a_stream_advances_only_on_its_own_draws()

	print("SimFoundation tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: %s" % what)


func _close(a: float, b: float, tol: float, what: String) -> void:
	_check(absf(a - b) <= tol, "%s (got %.8f, expected %.8f +/- %.8f)" % [what, a, b, tol])


func _eq_int(a: int, b: int, what: String) -> void:
	_check(a == b, "%s (got %d, expected %d)" % [what, a, b])


# --- SimMath: table lookups --------------------------------------------------

func test_sim_math_sin_is_exact_at_the_cardinal_angles() -> void:
	# Arrange / Act / Assert: the four angles the table must not approximate.
	_close(SimMath.sin_bam(0), 0.0, 0.0, "sin(0)")
	_close(SimMath.sin_bam(SimMath.QUARTER), 1.0, 0.0, "sin(90)")
	_close(SimMath.sin_bam(SimMath.HALF), 0.0, 0.0, "sin(180)")
	_close(SimMath.sin_bam(SimMath.HALF + SimMath.QUARTER), -1.0, 0.0, "sin(270)")
	_close(SimMath.cos_bam(0), 1.0, 0.0, "cos(0)")
	_close(SimMath.cos_bam(SimMath.QUARTER), 0.0, 0.0, "cos(90)")
	_close(SimMath.cos_bam(SimMath.HALF), -1.0, 0.0, "cos(180)")


func test_sim_math_sin_matches_the_platform_sine_within_table_resolution() -> void:
	# The table is a quarter wave of 16,384 float32 entries, so a lookup is
	# within half a step (~4.8e-5 rad) of the true sine. Anything larger means
	# the quadrant folding is wrong.
	var worst := 0.0
	for a: int in range(0, SimMath.TURN, 37):
		var d := absf(SimMath.sin_bam(a) - sin(SimMath.bam_to_rad(a)))
		if d > worst:
			worst = d
	_check(worst <= 1.0e-4, "sin table max error %.8f exceeds 1e-4" % worst)

	worst = 0.0
	for a: int in range(0, SimMath.TURN, 37):
		var d := absf(SimMath.cos_bam(a) - cos(SimMath.bam_to_rad(a)))
		if d > worst:
			worst = d
	_check(worst <= 1.0e-4, "cos table max error %.8f exceeds 1e-4" % worst)


func test_sim_math_cos_is_the_sine_a_quarter_turn_ahead() -> void:
	for a: int in range(0, SimMath.TURN, 101):
		_close(
			SimMath.cos_bam(a),
			SimMath.sin_bam(a + SimMath.QUARTER),
			0.0,
			"cos == sin + 90 at %d" % a
		)


func test_sim_math_angles_wrap_over_the_whole_int_range() -> void:
	# Integer angles must wrap exactly, including negatives and multi-turn
	# values, because runners accumulate volley * step without normalising.
	_close(SimMath.sin_bam(-SimMath.QUARTER), -1.0, 0.0, "sin(-90)")
	_close(SimMath.sin_bam(SimMath.TURN + SimMath.QUARTER), 1.0, 0.0, "sin(450)")
	_close(
		SimMath.sin_bam(17 * SimMath.TURN + 1234),
		SimMath.sin_bam(1234),
		0.0,
		"sin wraps 17 turns"
	)
	_close(
		SimMath.sin_bam(-5 * SimMath.TURN + 777),
		SimMath.sin_bam(777),
		0.0,
		"sin wraps -5 turns"
	)


# --- SimMath: atan2 ----------------------------------------------------------

func test_sim_math_atan2_matches_the_pattern_library_f5_example() -> void:
	# Pattern library F5 worked example: O = (180, 100), T = (210, 500)
	# -> theta = 1.4959 rad. The GDD allows +/-1 bam (its own value is quoted
	# to 4 dp, which is +/-0.5 bam on its own).
	var a := SimMath.atan2_bam(500.0 - 100.0, 210.0 - 180.0)
	var expected := SimMath.rad_to_bam(1.4959)
	_check(absi(a - expected) <= 1, "F5 aim: got %d bam, expected %d +/-1" % [a, expected])


func test_sim_math_atan2_is_correct_in_every_quadrant() -> void:
	# 0 = right, QUARTER = down (+y), per the GDD angle convention.
	_eq_int(SimMath.atan2_bam(0.0, 1.0), 0, "atan2 right")
	_eq_int(SimMath.atan2_bam(1.0, 0.0), SimMath.QUARTER, "atan2 down")
	_eq_int(SimMath.atan2_bam(0.0, -1.0), SimMath.HALF, "atan2 left")
	_eq_int(SimMath.atan2_bam(-1.0, 0.0), SimMath.HALF + SimMath.QUARTER, "atan2 up")
	_eq_int(SimMath.atan2_bam(1.0, 1.0), SimMath.QUARTER / 2, "atan2 down-right (45)")
	_eq_int(
		SimMath.atan2_bam(1.0, -1.0),
		SimMath.HALF - SimMath.QUARTER / 2,
		"atan2 down-left (135)"
	)
	_eq_int(
		SimMath.atan2_bam(-1.0, -1.0),
		SimMath.HALF + SimMath.QUARTER / 2,
		"atan2 up-left (225)"
	)
	_eq_int(
		SimMath.atan2_bam(-1.0, 1.0),
		SimMath.TURN - SimMath.QUARTER / 2,
		"atan2 up-right (315)"
	)
	# Pattern library AC-25: there is no upward clamp.
	_eq_int(
		SimMath.atan2_bam(-50.0, 0.0),
		SimMath.HALF + SimMath.QUARTER,
		"straight up is allowed"
	)


func test_sim_math_atan2_of_the_zero_vector_is_zero() -> void:
	_eq_int(SimMath.atan2_bam(0.0, 0.0), 0, "atan2(0,0)")


func test_sim_math_atan2_round_trips_every_angle_within_one_bam() -> void:
	# Build a direction from an angle, read the angle back: the two must agree
	# to the resolution of the angle type. This is what makes an aimed fan
	# land where the geometry says it does.
	var worst := 0
	for a: int in range(0, SimMath.TURN, 29):
		var back := SimMath.atan2_bam(SimMath.sin_bam(a) * 250.0, SimMath.cos_bam(a) * 250.0)
		var d := absi(SimMath.delta_bam(a, back))
		if d > worst:
			worst = d
	_check(worst <= 1, "atan2 round trip worst error %d bam" % worst)


func test_sim_math_rad_to_bam_round_trips_authored_values() -> void:
	# Designer data is authored in radians and converted ONCE at load.
	_eq_int(SimMath.rad_to_bam(0.0), 0, "0 rad")
	_eq_int(SimMath.rad_to_bam(TAU), SimMath.TURN, "a full turn")
	_eq_int(SimMath.rad_to_bam(PI), SimMath.HALF, "half a turn")
	_eq_int(SimMath.rad_to_bam(PI * 0.5), SimMath.QUARTER, "a quarter turn")
	# The spiral step from F10's migration table.
	_eq_int(SimMath.rad_to_bam(0.33), 3442, "spiral step 0.33 rad")
	# Fan spreads from the Tuning Knobs table.
	_eq_int(SimMath.rad_to_bam(0.165), 1721, "jet fan spread 0.165 rad")
	_eq_int(SimMath.rad_to_bam(0.21), 2190, "fortress turret spread 0.21 rad")


func test_sim_math_delta_bam_takes_the_short_way_round() -> void:
	_eq_int(SimMath.delta_bam(0, 100), 100, "forward")
	_eq_int(SimMath.delta_bam(100, 0), -100, "backward")
	_eq_int(SimMath.delta_bam(SimMath.MASK, 1), 2, "across the wrap")
	_eq_int(SimMath.delta_bam(0, SimMath.HALF), SimMath.HALF, "exactly opposite resolves forward")


func test_sim_math_quantise_snaps_to_one_sixteenth_of_a_pixel() -> void:
	# ADR-0003 Decision 3: published closed-form positions live on a 1/16 px
	# grid so the bits below it cannot diverge between platforms.
	_close(SimMath.quantise(1.0), 1.0, 0.0, "whole px")
	_close(SimMath.quantise(1.0 / 16.0), 0.0625, 0.0, "exactly one step")
	_close(SimMath.quantise(0.04), 0.0625, 0.0, "just over half a step rounds up")
	_close(SimMath.quantise(0.03), 0.0, 0.0, "just under half a step rounds down")
	_close(SimMath.quantise(-1.04), -1.0625, 0.0, "negative rounds to nearest")
	_close(SimMath.quantise(-1.03), -1.0, 0.0, "negative rounds down in magnitude")
	for v: float in [0.0, 12.3456, -98.7654, 359.99]:
		var q := SimMath.quantise(v)
		_close(q * 16.0, roundf(q * 16.0), 0.0, "quantise(%f) lands on the grid" % v)


func test_sim_math_length_matches_the_pythagorean_result() -> void:
	_close(SimMath.length(3.0, 4.0), 5.0, 0.0, "3-4-5")
	_close(SimMath.length(0.0, 0.0), 0.0, 0.0, "zero")
	_close(
		SimMath.length(30.0, 400.0),
		sqrt(30.0 * 30.0 + 400.0 * 400.0),
		0.0,
		"F5 example distance"
	)


# --- SimHash -----------------------------------------------------------------

func test_sim_hash_the_same_parts_give_the_same_seed() -> void:
	var a := SimHash.seed([20261103, 0, &"fortress_core", 2])
	var b := SimHash.seed([20261103, 0, &"fortress_core", 2])
	_eq_int(a, b, "the same parts hash to the same seed")


func test_sim_hash_different_parts_give_different_seeds() -> void:
	# Rule 15: adding, removing or reordering one emitter must never change
	# another's randomness, which only holds if the seeds really differ.
	var seeds := {}
	for owner_id: int in range(8):
		for emitter_index: int in range(4):
			var s := SimHash.seed([20261103, 0, owner_id, emitter_index])
			_check(
				not seeds.has(s),
				"seed collision at owner %d emitter %d" % [owner_id, emitter_index]
			)
			seeds[s] = true
	_eq_int(seeds.size(), 32, "32 distinct emitter seeds")


func test_sim_hash_length_prefixes_stop_string_collisions() -> void:
	_check(
		SimHash.seed([&"ab", &"c"]) != SimHash.seed([&"a", &"bc"]),
		"two short names must not hash like one long one"
	)
	_check(SimHash.seed([1, 2]) != SimHash.seed([2, 1]), "order matters")
	_check(SimHash.seed([]) != SimHash.seed([0]), "an empty list is not a zero")


func test_sim_hash_digest32_changes_when_any_field_changes() -> void:
	var base := _hash_of(7, 1.5, true)
	_check(base == _hash_of(7, 1.5, true), "digest32 is stable")
	_check(base != _hash_of(8, 1.5, true), "digest32 reacts to the int")
	_check(base != _hash_of(7, 1.5625, true), "digest32 reacts to the float")
	_check(base != _hash_of(7, 1.5, false), "digest32 reacts to the bool")
	_check(base >= 0 and base <= 0xFFFFFFFF, "digest32 is an unsigned 32-bit value")


func _hash_of(i: int, f: float, b: bool) -> int:
	var ctx := SimHash.begin()
	SimHash.add_int(ctx, i)
	SimHash.add_float(ctx, f)
	SimHash.add_bool(ctx, b)
	return SimHash.digest32(ctx)


func test_sim_hash_array_prefix_ignores_rows_past_the_live_count() -> void:
	# Pooled arrays keep stale rows past the live count; the hash must not see
	# them, or a replay would depend on garbage left by dead bullets.
	var a := PackedFloat32Array([1.0, 2.0, 3.0, 999.0, -999.0])
	var b := PackedFloat32Array([1.0, 2.0, 3.0, 0.0, 0.0])
	var ctx_a := SimHash.begin()
	SimHash.add_f32_prefix(ctx_a, a, 3)
	var ctx_b := SimHash.begin()
	SimHash.add_f32_prefix(ctx_b, b, 3)
	var hash_a := SimHash.digest32(ctx_a)
	_eq_int(hash_a, SimHash.digest32(ctx_b), "stale rows are not hashed")

	var ctx_c := SimHash.begin()
	SimHash.add_f32_prefix(ctx_c, a, 4)
	_check(hash_a != SimHash.digest32(ctx_c), "the live count is hashed")


# --- SimRng ------------------------------------------------------------------

func test_sim_rng_a_stream_is_reproducible_from_its_parts() -> void:
	var first := _draws(SimRng.make(SimRng.EMITTER, [20261103, 0, 5, 1]), 6)
	var second := _draws(SimRng.make(SimRng.EMITTER, [20261103, 0, 5, 1]), 6)
	for i: int in range(6):
		_close(first[i], second[i], 0.0, "draw %d reproduces" % i)


func test_sim_rng_each_owner_gets_an_independent_stream() -> void:
	var a := _draws(SimRng.make(SimRng.EMITTER, [20261103, 0, 5, 0]), 4)
	var b := _draws(SimRng.make(SimRng.EMITTER, [20261103, 0, 5, 1]), 4)
	var c := _draws(SimRng.make(SimRng.EMITTER, [20261103, 0, 6, 0]), 4)
	var same_ab := true
	var same_ac := true
	for i: int in range(4):
		if a[i] != b[i]:
			same_ab = false
		if a[i] != c[i]:
			same_ac = false
	_check(not same_ab, "a different emitter index is a different stream")
	_check(not same_ac, "a different owner is a different stream")
	# A different stream KEY must also differ, so Powerups draws can never
	# consume an emitter's randomness.
	var d := _draws(SimRng.make(SimRng.DROPS, [20261103, 0, 5, 0]), 1)
	_check(a[0] != d[0], "a different stream key is a different stream")


func test_sim_rng_a_stream_advances_only_on_its_own_draws() -> void:
	# Pattern library Rule 15 / AC-14: one emitter's draws must not be shifted
	# by anything another emitter does.
	var a := SimRng.make(SimRng.EMITTER, [20261103, 0, 5, 0])
	var b := SimRng.make(SimRng.EMITTER, [20261103, 0, 9, 0])
	var expected := _draws(SimRng.make(SimRng.EMITTER, [20261103, 0, 5, 0]), 3)

	var interleaved := PackedFloat32Array()
	for i: int in range(3):
		b.randf()
		b.randi()
		interleaved.push_back(a.randf())
	for i: int in range(3):
		_close(
			interleaved[i],
			expected[i],
			0.0,
			"draw %d is untouched by the other stream" % i
		)


func _draws(rng: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i: int in range(n):
		out.push_back(rng.randf())
	return out
