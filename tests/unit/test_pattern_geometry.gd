extends SceneTree
## Pattern geometry (design/gdd/bullet-pattern-library.md F6, AC-29 - AC-36).
##
## The acceptance criteria quote the random draw `u` for the seeded shapes, so
## those are asserted against the pure [PatternMetrics] functions the runner
## itself calls — the same copy of the formula, fed the quoted `u`. The shapes
## with no randomness (fan, spiral, radial curve, flak) are asserted through a
## real runner, end to end.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_pattern_geometry.gd

var _failures := 0

const FAN := PatternDef.Kind.AIMED_FAN
const RING := PatternDef.Kind.RING
const SPIRAL := PatternDef.Kind.SPIRAL
const WALL := PatternDef.Kind.WALL
const CURVE := PatternDef.Kind.RADIAL_CURVE
const FLAK := PatternDef.Kind.FLAK_BURST
const SPRAY := PatternDef.Kind.SPRAY

## The GDD's worked aim: O (180, 100) to T (210, 500).
const AIM_RAD := 1.4959


func _init() -> void:
	test_pattern_fan_spreads_evenly_around_the_aim()
	test_pattern_fan_of_one_fires_exactly_the_aim()
	test_pattern_ring_offset_is_a_fraction_of_one_gap()
	test_pattern_ring_divides_the_turn_evenly()
	test_pattern_ring_in_fixed_mode_makes_no_draw()
	test_pattern_spiral_angle_comes_from_the_volley_counter()
	test_pattern_spiral_arms_are_evenly_opposed()
	test_pattern_spiral_does_not_drift_over_ten_thousand_volleys()
	test_pattern_wall_slots_are_centred_on_the_emitter()
	test_pattern_wall_gap_is_chosen_from_the_valid_set()
	test_pattern_wall_always_draws_exactly_once_per_volley()
	test_pattern_wall_with_no_valid_gap_falls_back_to_the_middle()
	test_pattern_radial_curve_fires_outward_from_the_centre()
	test_pattern_radial_curve_spin_alternates_every_volley()
	test_pattern_flak_bursts_along_the_aim_at_the_gdd_point()
	test_pattern_flak_respects_the_standoff_and_the_play_top_clamp()
	test_pattern_spray_spaces_bullets_inside_its_arc()
	test_pattern_spray_draws_angle_then_speed_per_bullet()

	PatternHarness.dispose_all()
	print("PatternGeometry tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- AC-29, F6a --------------------------------------------------------------

func test_pattern_fan_spreads_evenly_around_the_aim() -> void:
	# Arrange / act: the GDD example, n 5 and spread 0.165 around 1.4959.
	var angles := _fire_fan(5, 0.165)
	var want := [1.1659, 1.3309, 1.4959, 1.6609, 1.8259]
	for i: int in range(want.size()):
		_assert_bam(angles[i], SimMath.rad_to_bam(want[i]), "fan bullet %d" % i)

	# An even count straddles the aim at +/- 0.5 and +/- 1.5 spreads.
	var four := _fire_fan(4, 0.165)
	var spread := SimMath.rad_to_bam(0.165)
	var aim := SimMath.rad_to_bam(AIM_RAD)
	for i: int in range(4):
		_assert_bam(
			four[i], aim + (2 * i - 3) * spread / 2, "fan of 4, bullet %d sits off the aim" % i
		)


func test_pattern_fan_of_one_fires_exactly_the_aim() -> void:
	var angles := _fire_fan(1, 0.25)
	_assert_eq(angles.size(), 1, "a fan of one fires one bullet")
	_assert_bam(angles[0], SimMath.rad_to_bam(AIM_RAD), "and ignores the spread")


# --- AC-30, F6b --------------------------------------------------------------

func test_pattern_ring_offset_is_a_fraction_of_one_gap() -> void:
	var step := PatternMetrics.ring_step_bam(24)
	_assert_bam(step, SimMath.rad_to_bam(0.2618), "a 24-bullet ring steps 0.2618 rad")
	_assert_bam(
		PatternMetrics.ring_offset_bam(0.37, 24),
		SimMath.rad_to_bam(0.0969),
		"u 0.37 gives the GDD offset"
	)
	_assert(
		PatternMetrics.ring_offset_bam(0.999999, 24) < step,
		"u just under 1 still gives an offset below one step"
	)
	_assert_eq(PatternMetrics.ring_offset_bam(0.0, 24), 0, "u 0 gives no rotation")


func test_pattern_ring_divides_the_turn_evenly() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true, 0)
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 120, "count": 24, "speed": 120.0,
		"offset_mode": PatternDef.OffsetMode.SEEDED,
	})
	var e := h.add_emitter([ring], 100)
	h.run(e, 100, 150)
	var idx := h.field.indices_at(148)
	_assert_eq(idx.size(), 24, "a 24-bullet ring fires 24 bullets")
	var probe := SimRng.make(SimRng.EMITTER, [h.scene.run_seed, 0, 1, 0])
	var offset := PatternMetrics.ring_offset_bam(probe.randf(), 24)
	_assert(
		offset >= 0 and offset < PatternMetrics.ring_step_bam(24),
		"the seeded rotation stays inside one gap"
	)
	for i: int in range(24):
		_assert_bam(
			h.field.angle_bam(idx[i]),
			PatternMetrics.ring_angle_bam(i, 24, offset),
			"ring bullet %d" % i
		)
	_assert_eq(e.rng.state, probe.state, "and the ring made exactly one draw")

	var one := _ring_count(1)
	_assert_eq(one, 1, "a ring of one fires one bullet")


func test_pattern_ring_in_fixed_mode_makes_no_draw() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true, 0)
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 60, "count": 12, "speed": 120.0,
		"offset_mode": PatternDef.OffsetMode.FIXED, "fixed_offset_rad": 0.4,
	})
	var e := h.add_emitter([ring], 100)
	var before: int = e.rng.state
	h.run(e, 100, 400)
	_assert_eq(e.rng.state, before, "a fixed ring never touches its random stream")
	var idx := h.field.indices_at(148)
	_assert_bam(
		h.field.angle_bam(idx[0]), SimMath.rad_to_bam(0.4), "and uses the authored offset"
	)


# --- AC-31, F6c --------------------------------------------------------------

func test_pattern_spiral_angle_comes_from_the_volley_counter() -> void:
	var step := SimMath.rad_to_bam(0.33)
	_assert_bam(
		PatternMetrics.spiral_angle_bam(0, 20, step, 0, 1),
		SimMath.rad_to_bam(0.3168),
		"step 0.33 at c 20 gives 0.3168 rad"
	)
	_assert_bam(
		PatternMetrics.spiral_angle_bam(0, 0, step, 0, 1), 0, "c 0 fires at the authored offset"
	)
	_assert_bam(
		PatternMetrics.spiral_angle_bam(0, 1, SimMath.rad_to_bam(-0.33), 0, 1),
		SimMath.rad_to_bam(5.9532),
		"a negative step turns the other way"
	)
	# step 0 is a fixed-direction stream (Edge Cases).
	var fixed := _fire_spiral(0.0, 1, 5)
	for i: int in range(fixed.size()):
		_assert_bam(fixed[i], fixed[0], "a spiral with step 0 fires volley %d the same way" % i)


func test_pattern_spiral_arms_are_evenly_opposed() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true, 0)
	var spiral := PatternHarness.make(SPIRAL, {
		"start_delay": 48, "interval": 60, "arms": 2, "step_rad": 0.33, "speed": 140.0,
	})
	var e := h.add_emitter([spiral], 100)
	h.run(e, 100, 150)
	var idx := h.field.indices_at(148)
	_assert_eq(idx.size(), 2, "two arms fire two bullets")
	_assert_eq(
		absi(SimMath.delta_bam(h.field.angle_bam(idx[0]), h.field.angle_bam(idx[1]))),
		SimMath.HALF,
		"the second arm is exactly pi after the first"
	)


func test_pattern_spiral_does_not_drift_over_ten_thousand_volleys() -> void:
	var step := SimMath.rad_to_bam(0.33)
	var closed := PatternMetrics.spiral_angle_bam(0, 10000, step, 0, 1)
	var accumulated := 0
	for c: int in range(10000):
		accumulated = (accumulated + step) & SimMath.MASK
	_assert_eq(closed, accumulated, "c 10,000 equals the closed form exactly")


# --- AC-32, AC-33, F6d ------------------------------------------------------

func test_pattern_wall_slots_are_centred_on_the_emitter() -> void:
	for i: int in range(7):
		_assert_close(
			PatternMetrics.wall_slot_x(i, 7, 180.0, 16.0),
			132.0 + 16.0 * float(i),
			"wall slot %d of 7 at x 180" % i
		)


func test_pattern_wall_gap_is_chosen_from_the_valid_set() -> void:
	var valid := PackedInt32Array([1, 2, 3, 4, 5])
	_assert_eq(PatternMetrics.wall_gap_choice(0.62, valid), 4, "u 0.62 of {1..5} picks 4")
	_assert_eq(PatternMetrics.wall_gap_choice(0.0, valid), 1, "u 0 picks the first")
	_assert_eq(
		PatternMetrics.wall_gap_choice(0.999999, valid), 5, "u just under 1 picks the last"
	)
	_assert_eq(PatternMetrics.wall_gap_choice(1.0, valid), 5, "u 1 cannot run off the end")
	_assert_eq(PatternMetrics.wall_gap_choice(0.5, PackedInt32Array()), -1, "an empty set reports -1")


func test_pattern_wall_always_draws_exactly_once_per_volley() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 620.0), true, 0)
	var wall := PatternHarness.make(WALL, {
		"start_delay": 1, "interval": 2, "count": 7, "spacing": 16.0, "speed": 110.0,
	})
	var e := h.add_emitter([wall], 0)
	h.run(e, 0, 1999)
	var volleys := h.field.fired_ticks().size()
	_assert_eq(volleys, 1000, "1,000 volleys in 2,000 ticks at interval 2")
	# One draw per volley: the generator advanced exactly `volleys` times.
	var probe := SimRng.make(SimRng.EMITTER, [h.scene.run_seed, 0, 1, 0])
	for i: int in range(volleys):
		probe.randf()
	_assert_eq(e.rng.state, probe.state, "exactly one random draw per wall volley")

	# Every volley leaves the gap inside the valid set and fires both edges.
	var ok := true
	for t: int in h.field.fired_ticks():
		var idx := h.field.indices_at(t)
		if idx.size() != 6:
			ok = false
			break
		if absf(h.field.xs[idx[0]] - 132.0) > 0.01:
			ok = false
			break
		if absf(h.field.xs[idx[idx.size() - 1]] - 228.0) > 0.01:
			ok = false
			break
	_assert(ok, "every volley fires 6 of 7 slots, edges included")


func test_pattern_wall_with_no_valid_gap_falls_back_to_the_middle() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 620.0), true, 0)
	var wall := PatternHarness.make(WALL, {
		"start_delay": 48, "interval": 120, "count": 5, "spacing": 16.0, "speed": 110.0,
	})
	var e := h.add_emitter([wall], 100)
	var before: int = e.rng.state
	h.run(e, 100, 150, Vector2(0.0, 100.0))   # the whole wall is off the left edge
	var idx := h.field.indices_at(148)
	_assert_eq(idx.size(), 4, "4 of 5 slots fire")
	_assert_not(e.rng.state == before, "the draw still happens with nothing to choose")
	# Slots are at -32, -16, 0, 16, 32; the gap goes in slot 3 (x 16), the
	# in-range slot nearest the middle of the screen.
	var missing := true
	for i: int in range(idx.size()):
		if absf(h.field.xs[idx[i]] - 16.0) < 0.01:
			missing = false
	_assert(missing, "the gap lands on the in-range slot nearest x 180")


# --- AC-34, F6e --------------------------------------------------------------

func test_pattern_radial_curve_fires_outward_from_the_centre() -> void:
	var out := _fire_curve(Vector2(220.0, 100.0), Vector2(180.0, 100.0))
	_assert_bam(out[0], 0, "a muzzle right of the centre fires right")

	var same := _fire_curve(Vector2(180.0, 100.0), Vector2(180.0, 100.0))
	_assert_bam(same[0], SimMath.QUARTER, "a muzzle on the centre fires straight down")

	var near := _fire_curve(Vector2(180.4, 100.0), Vector2(180.0, 100.0))
	_assert_bam(near[0], SimMath.QUARTER, "and so does one 0.4 px out")


func test_pattern_radial_curve_spin_alternates_every_volley() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 620.0), true, 0)
	var curve := PatternHarness.make(CURVE, {
		"start_delay": 48, "interval": 10, "count": 1, "speed": 120.0, "spin": 1.3,
		"behaviour": BulletField.Beh.CURVE,
	})
	var e := h.add_emitter([curve], 100)
	h.run(e, 100, 200, Vector2(220.0, 100.0))
	_assert_close(
		h.field.params[h.field.indices_at(148)[0]], 1.3, "volley 0 spins one way"
	)
	_assert_close(
		h.field.params[h.field.indices_at(158)[0]], -1.3, "volley 1 spins the other"
	)
	_assert_close(
		h.field.params[h.field.indices_at(168)[0]], 1.3, "and volley 2 spins back"
	)

	# The same pattern with the 158 volley held: the sign must still have
	# flipped for it, so the volley after it is +1.3 and not -1.3.
	var h2 := PatternHarness.new()
	h2.set_slot(0, Vector2(180.0, 620.0), true, 0)
	var e2 := h2.add_emitter([curve], 100)
	h2.run(e2, 100, 200, Vector2(220.0, 100.0), 0.0, PackedInt32Array([158, 158]))
	_assert_eq(h2.field.indices_at(158).size(), 0, "the held volley fires nothing")
	_assert_close(
		h2.field.params[h2.field.indices_at(168)[0]], 1.3,
		"a volley skipped by the hold still consumed its sign"
	)


# --- AC-35, F6f --------------------------------------------------------------

func test_pattern_flak_bursts_along_the_aim_at_the_gdd_point() -> void:
	var b := _flak_point(Vector2(100.0, 120.0), Vector2(150.0, 520.0), 1)
	_assert_close(b.x, 129.77, "flak burst x", 0.05)
	_assert_close(b.y, 358.15, "flak burst y", 0.05)
	_assert_close(b.distance_to(Vector2(150.0, 520.0)), 163.1, "and stays 163 px off the target", 0.2)


func test_pattern_flak_respects_the_standoff_and_the_play_top_clamp() -> void:
	# Close target: D is only 24 px, and |B - T| is exactly the standoff, so it
	# is kept (the GDD's test is a strict <).
	var near := _flak_point(Vector2(100.0, 120.0), Vector2(100.0, 200.0), 1)
	_assert_close(near.x, 100.0, "a close target bursts straight down the aim")
	_assert_close(near.y, 144.0, "at exactly the standoff")

	# Clamped into the play area, which then puts it inside the standoff, so it
	# bursts at the gun instead.
	var clamped := _flak_point(Vector2(180.0, -20.0), Vector2(180.0, 100.0), 1)
	_assert_close(clamped.x, 180.0, "a shell clamped inside the standoff bursts at the gun (x)")
	_assert_close(clamped.y, -20.0, "a shell clamped inside the standoff bursts at the gun (y)")

	# A shell aimed across the top of the screen is pushed down to the clamp
	# floor, which follows the HUD strip: 48 + 12 solo, 72 + 12 in 3-4P.
	var solo := _flak_point(Vector2(40.0, -80.0), Vector2(340.0, 40.0), 1)
	_assert_close(solo.y, 60.0, "with play_top 48 the clamp floor is 60")
	var coop := _flak_point(Vector2(40.0, -80.0), Vector2(340.0, 40.0), 3)
	_assert_close(coop.y, 84.0, "with play_top 72 the clamp floor is 84")

	# Target inside the standoff: no distance to travel, so it bursts at the gun.
	var hugging := _flak_point(Vector2(180.0, 100.0), Vector2(180.0, 130.0), 1)
	_assert_close(hugging.y, 100.0, "a target 30 px away bursts at the gun")


# --- AC-36, F6g --------------------------------------------------------------

func test_pattern_spray_spaces_bullets_inside_its_arc() -> void:
	var arc := SimMath.rad_to_bam(1.2)
	var base := SimMath.QUARTER - arc / 2
	var want := [1.1208, 1.4208, 1.7208, 2.0208]
	for i: int in range(4):
		_assert_bam(
			PatternMetrics.spray_angle_bam(i, 4, 0.5, arc, base, 0.5),
			SimMath.rad_to_bam(want[i]),
			"spray bullet %d with u 0.5" % i
		)

	# Worst case jitter: neighbours still keep a readable gap.
	var closest := SimMath.TURN
	for i: int in range(3):
		var a := PatternMetrics.spray_angle_bam(i, 4, 1.0, arc, base, 0.5)
		var b := PatternMetrics.spray_angle_bam(i + 1, 4, 0.0, arc, base, 0.5)
		closest = mini(closest, absi(SimMath.delta_bam(a, b)))
	_assert(
		closest >= SimMath.rad_to_bam(0.15),
		"u alternating 1 and 0 still leaves 0.15 rad between neighbours (got %d bam)" % closest
	)

	# Jitter 0 puts every bullet in the middle of its slot.
	_assert_bam(
		PatternMetrics.spray_angle_bam(0, 4, 0.9, arc, base, 0.0),
		PatternMetrics.spray_angle_bam(0, 4, 0.1, arc, base, 0.0),
		"with jitter 0 the draw does not move the bullet"
	)


func test_pattern_spray_draws_angle_then_speed_per_bullet() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 620.0), true, 0)
	var spray := PatternHarness.pattern("wave_1941_spray")
	var e := h.add_emitter([spray], 100)
	h.run(e, 100, 150)
	var idx := h.field.indices_at(148)
	_assert_eq(idx.size(), 4, "the spray fires its 4 bullets")

	# Two draws per bullet, in the order angle then speed.
	var probe := SimRng.make(SimRng.EMITTER, [h.scene.run_seed, 0, 1, 0])
	var arc := SimMath.rad_to_bam(spray.arc_rad)
	var aim := SimMath.atan2_bam(620.0 - 100.0, 180.0 - 180.0)
	var base := aim - arc / 2
	for i: int in range(4):
		var u := probe.randf()
		var u_speed := probe.randf()
		_assert_bam(
			h.field.angle_bam(idx[i]),
			PatternMetrics.spray_angle_bam(i, 4, u, arc, base, spray.jitter),
			"spray angle %d uses the first draw" % i
		)
		_assert_close(
			h.field.speed_of(idx[i]),
			PatternMetrics.spray_speed(u_speed, spray.speed_min, spray.speed_max),
			"spray speed %d uses the second draw" % i,
			0.05
		)
	_assert_eq(e.rng.state, probe.state, "and makes no other draws")


# --- helpers -----------------------------------------------------------------

## Fires one fan volley at the GDD's worked aim and returns the bullet angles.
func _fire_fan(count: int, spread_rad: float) -> PackedInt32Array:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(210.0, 500.0), true, 0)
	var fan := PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 120, "count": count, "spread_rad": spread_rad,
	})
	var e := h.add_emitter([fan], 100)
	h.run(e, 100, 150)
	var out := PackedInt32Array()
	for i: int in h.field.indices_at(148):
		out.push_back(h.field.angle_bam(i))
	return out


func _ring_count(count: int) -> int:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true, 0)
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 120, "count": count, "speed": 120.0,
	})
	var e := h.add_emitter([ring], 100)
	h.run(e, 100, 150)
	return h.field.indices_at(148).size()


## The first bullet's angle for `volleys` consecutive spiral volleys.
func _fire_spiral(step_rad: float, arms: int, volleys: int) -> PackedInt32Array:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 620.0), true, 0)
	var spiral := PatternHarness.make(SPIRAL, {
		"start_delay": 48, "interval": 10, "arms": arms, "step_rad": step_rad, "speed": 140.0,
	})
	var e := h.add_emitter([spiral], 100)
	h.run(e, 100, 148 + 10 * volleys)
	var out := PackedInt32Array()
	for t: int in h.field.fired_ticks():
		out.push_back(h.field.angle_bam(h.field.indices_at(t)[0]))
	return out


func _fire_curve(muzzle: Vector2, centre: Vector2) -> PackedInt32Array:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(300.0, 620.0), true, 0)
	var curve := PatternHarness.make(CURVE, {
		"start_delay": 48, "interval": 120, "count": 1, "speed": 120.0, "spin": 1.3,
		"behaviour": BulletField.Beh.CURVE,
	})
	var e := h.add_emitter([curve], 100)
	h.run(e, 100, 150, muzzle, 0.0, PackedInt32Array(), centre)
	var out := PackedInt32Array()
	for i: int in h.field.indices_at(148):
		out.push_back(h.field.angle_bam(i))
	return out


## Where a flak shell bursts, read from the position of its ring bullets.
func _flak_point(origin: Vector2, target: Vector2, players: int) -> Vector2:
	var h := PatternHarness.new()
	h.scene.set_player_count(players)
	h.set_slot(0, target, true, 0)
	var flak := PatternHarness.make(FLAK, {
		"start_delay": 48, "interval": 150, "count": 12, "speed": 120.0,
		"flak_delay": 36, "flak_distance": 240.0, "standoff": 56.0,
	})
	var e := h.add_emitter([flak], 100)
	h.run(e, 100, 190, origin)
	var idx := h.field.indices_at(184)
	if idx.size() == 0:
		_failures += 1
		print("FAIL: the flak probe never burst")
		return Vector2.INF
	# Every ring bullet spawns at the burst point.
	return Vector2(h.field.xs[idx[0]], h.field.ys[idx[0]])


# --- assertions --------------------------------------------------------------

func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_not(bad: bool, what: String) -> void:
	_assert(not bad, what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])


func _assert_bam(got: int, want: int, what: String) -> void:
	if absi(SimMath.delta_bam(want, got)) > 1:
		_failures += 1
		print("FAIL: %s -- got %d bam, want %d bam" % [what, got, want])


func _assert_close(got: float, want: float, what: String, tol := 0.01) -> void:
	if absf(got - want) > tol:
		_failures += 1
		print("FAIL: %s -- got %.4f, want %.4f (+/- %.3f)" % [what, got, want, tol])
