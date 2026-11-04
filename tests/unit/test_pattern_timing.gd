extends SceneTree
## Timing, intensity, states, fire hold and flak fuses for the pattern library
## (design/gdd/bullet-pattern-library.md F1-F3, Rules 5-9, AC-05 - AC-19).
##
## Every acceptance criterion that quotes numbers is asserted with those exact
## numbers, so the code is checked against the design rather than itself.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_pattern_timing.gd

var _failures := 0

const FAN := PatternDef.Kind.AIMED_FAN
const SPIRAL := PatternDef.Kind.SPIRAL
const FLAK := PatternDef.Kind.FLAK_BURST


func _init() -> void:
	test_pattern_f1_minimums_clamp_zero_fields_to_one()
	test_pattern_f1_seconds_convert_to_the_gdd_tick_values()
	test_pattern_burst_fires_on_the_exact_gdd_schedule()
	test_pattern_zero_start_delay_fires_one_tick_after_activation()
	test_pattern_overlapping_burst_pushes_the_next_burst_later()
	test_pattern_intensity_scales_interval_and_count()
	test_pattern_gate_is_inclusive_within_one_epsilon()
	test_pattern_gate_agrees_with_the_validator()
	test_pattern_intensity_change_mid_burst_applies_from_the_next_burst()
	test_pattern_leaving_the_gate_drops_the_burst_and_restarts_start_delay()
	test_pattern_gate_toggled_faster_than_start_delay_never_fires()
	test_pattern_states_follow_the_gdd_table()
	test_pattern_fire_hold_skips_volleys_but_keeps_the_rhythm()
	test_pattern_skipped_volley_still_draws_its_randomness()
	test_pattern_flak_fuse_inside_a_hold_is_used_up_and_never_fires_late()
	test_pattern_stop_mid_burst_fires_nothing_more()
	test_pattern_fuse_survives_a_gate_or_a_plain_stop()
	test_pattern_fuse_is_cancelled_when_the_owner_is_destroyed()
	test_pattern_scene_fuse_cap_skips_the_ninth_fuse()

	PatternHarness.dispose_all()
	print("PatternTiming tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- AC-05, F1 ---------------------------------------------------------------

func test_pattern_f1_minimums_clamp_zero_fields_to_one() -> void:
	var d := PatternHarness.make(FAN, {
		"start_delay": 0, "interval": 0, "burst_gap": 0, "burst_count": 0, "flak_delay": 0,
	})
	_assert_eq(PatternMetrics.clamp_start_delay(d.start_delay), 1, "start_delay 0 -> 1")
	_assert_eq(PatternMetrics.clamp_interval(d.interval), 1, "interval 0 -> 1")
	_assert_eq(PatternMetrics.clamp_interval(d.burst_gap), 1, "burst_gap 0 -> 1")
	_assert_eq(PatternMetrics.clamp_burst_count(d.burst_count), 1, "burst_count 0 -> 1")
	_assert_eq(PatternMetrics.clamp_flak_delay(d.flak_delay), 1, "flak_delay 0 -> 1")
	_assert_eq(maxi(0, d.lock_ticks), 0, "lock_ticks 0 stays 0")


func test_pattern_f1_seconds_convert_to_the_gdd_tick_values() -> void:
	_assert_eq(PatternMetrics.seconds_to_ticks(2.3, 1), 138, "2.3 s -> 138 ticks")
	_assert_eq(PatternMetrics.seconds_to_ticks(0.045, 1), 3, "0.045 s -> 3 ticks")
	_assert_eq(PatternMetrics.seconds_to_ticks(0.0, 1), 1, "0 s start delay -> 1 tick")
	_assert_eq(PatternMetrics.seconds_to_ticks(0.8, 1), 48, "0.8 s -> 48 ticks")
	_assert_eq(PatternMetrics.seconds_to_ticks(0.1, 1), 6, "0.1 s -> 6 ticks")


# --- AC-06, AC-07, F2 --------------------------------------------------------

func test_pattern_burst_fires_on_the_exact_gdd_schedule() -> void:
	var h := PatternHarness.new()
	var d := PatternHarness.make(FAN, {
		"start_delay": 48, "burst_count": 6, "burst_gap": 6, "interval": 84, "count": 1,
	})
	var e := h.add_emitter([d], 100)
	h.run(e, 100, 235)
	_assert_ticks(
		h.field.fired_ticks(),
		[148, 154, 160, 166, 172, 178, 232],
		"F2 schedule from T_act 100"
	)


func test_pattern_zero_start_delay_fires_one_tick_after_activation() -> void:
	var h := PatternHarness.new()
	var d := PatternHarness.make(FAN, {"start_delay": 0, "interval": 84, "count": 1})
	var e := h.add_emitter([d], 100)
	h.run(e, 100, 110)
	_assert_ticks(h.field.fired_ticks(), [101], "start_delay 0 -> first volley at T_act + 1")


func test_pattern_overlapping_burst_pushes_the_next_burst_later() -> void:
	var h := PatternHarness.new()
	# interval_eff scales to 20, below the 31 ticks the burst itself spans.
	var d := PatternHarness.make(FAN, {
		"start_delay": 48, "burst_count": 6, "burst_gap": 6,
		"interval": 84, "interval_at_full": 20, "count": 1,
	})
	var e := h.add_emitter([d], 100)
	h.run(e, 100, 200, Vector2(180.0, 100.0), 1.0)
	_assert_ticks(
		h.field.fired_ticks(),
		[148, 154, 160, 166, 172, 178, 179, 185, 191, 197],
		"F2 fallback: all 6 volleys fire and the next burst starts 31 ticks on"
	)


# --- AC-08, AC-09, AC-10, F3 -------------------------------------------------

func test_pattern_intensity_scales_interval_and_count() -> void:
	var d := PatternHarness.make(FAN, {
		"interval": 78, "interval_at_full": 33, "count": 5, "count_at_full": 9,
	})
	_assert_eq(PatternMetrics.interval_eff(d, 0.0), 78, "interval at I 0")
	_assert_eq(PatternMetrics.interval_eff(d, 0.5), 56, "interval 78->33 at I 0.5 (55.5 rounds up)")
	_assert_eq(PatternMetrics.interval_eff(d, 1.0), 33, "interval at I 1")
	_assert_eq(PatternMetrics.count_eff(d, 0.0), 5, "count at I 0")
	_assert_eq(PatternMetrics.count_eff(d, 0.125), 6, "count 5->9 at I 0.125 (5.5 rounds up)")
	_assert_eq(PatternMetrics.count_eff(d, 1.0), 9, "count at I 1")

	var flat := PatternHarness.make(FAN, {"interval": 78, "count": 5})
	_assert_eq(PatternMetrics.interval_eff(flat, 1.0), 78, "negative interval_at_full: no scaling")
	_assert_eq(PatternMetrics.count_eff(flat, 1.0), 5, "negative count_at_full: no scaling")

	var tiny := PatternHarness.make(FAN, {"interval": 1, "interval_at_full": 1, "count": 1})
	_assert_eq(PatternMetrics.interval_eff(tiny, 1.0), 1, "interval never below 1")
	_assert_eq(PatternMetrics.count_eff(tiny, 1.0), 1, "count never below 1")


func test_pattern_gate_is_inclusive_within_one_epsilon() -> void:
	var d := PatternHarness.make(FAN, {"min_intensity": 0.5, "max_intensity": 1.0})
	_assert(PatternMetrics.gate_open(d, 0.5), "gate open at the lower bound")
	_assert(PatternMetrics.gate_open(d, 1.0), "gate open at the upper bound")
	_assert(PatternMetrics.gate_open(d, 0.4999995), "gate open within one epsilon")
	_assert(not PatternMetrics.gate_open(d, 0.49999), "gate shut a hair below")
	_assert(PatternMetrics.gate_open(d, 1.7), "intensity above 1 acts as 1")
	_assert(not PatternMetrics.gate_open(d, -0.2), "intensity below 0 acts as 0")


## The runner checks the gate inline rather than calling
## [method PatternMetrics.gate_open], because that call runs for every runner
## on every tick and the budget is 0.2 ms (AC-53). This test is what keeps the
## two copies of the F3 gate honest: a pattern must never pass the authoring
## checks and then behave differently in the game.
func test_pattern_gate_agrees_with_the_validator() -> void:
	var bounds := [
		Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(0.0, 0.5), Vector2(1.0, 1.0),
		Vector2(0.25, 0.75),
	]
	for b: Vector2 in bounds:
		var d := PatternHarness.make(FAN, {
			"start_delay": 1, "interval": 1, "count": 1, "min_intensity": b.x,
			"max_intensity": b.y,
		})
		for step: int in range(0, 201):
			var i := float(step) / 200.0
			var h := PatternHarness.new()
			h.set_slot(0, Vector2(180.0, 620.0), true, 0)
			var e := h.add_emitter([d], 0)
			h.run(e, 0, 3, Vector2(180.0, 100.0), i)
			var fired := h.field.size() > 0
			if fired != PatternMetrics.gate_open(d, i):
				_failures += 1
				print(
					"FAIL: gate [%.2f, %.2f] at intensity %.3f: runner %s, validator %s"
					% [b.x, b.y, i, fired, PatternMetrics.gate_open(d, i)]
				)
				break


func test_pattern_intensity_change_mid_burst_applies_from_the_next_burst() -> void:
	var h := PatternHarness.new()
	var d := PatternHarness.make(FAN, {
		"start_delay": 48, "burst_count": 2, "burst_gap": 6,
		"interval": 78, "interval_at_full": 33, "count": 5, "count_at_full": 9,
		"spread_rad": 0.165,
	})
	var e := h.add_emitter([d], 100)
	h.run(e, 100, 153, Vector2(180.0, 100.0), 0.0)     # burst 1 starts at 148
	h.run(e, 154, 320, Vector2(180.0, 100.0), 1.0)     # I jumps to 1 for volley 2
	_assert_eq(h.field.indices_at(148).size(), 5, "volley 1 uses count 5")
	_assert_eq(h.field.indices_at(154).size(), 5, "volley 2 of the same burst still uses 5")
	_assert_eq(h.field.indices_at(226).size(), 9, "the next burst (148 + 78) uses count 9")
	_assert_eq(h.field.indices_at(259).size(), 9, "and the burst after that is 33 ticks later")


# --- AC-11, AC-12, states ----------------------------------------------------

func test_pattern_leaving_the_gate_drops_the_burst_and_restarts_start_delay() -> void:
	var h := PatternHarness.new()
	var d := PatternHarness.make(FAN, {
		"start_delay": 48, "burst_count": 6, "burst_gap": 6, "interval": 84, "count": 1,
		"min_intensity": 0.5,
	})
	var e := h.add_emitter([d], 100)
	e.update(Vector2(180.0, 100.0), Vector2(180.0, 100.0), 1.0)
	h.run(e, 100, 159, Vector2(180.0, 100.0), 1.0)
	h.run(e, 160, 199, Vector2(180.0, 100.0), 0.0)   # gate shuts at 160
	h.run(e, 200, 250, Vector2(180.0, 100.0), 1.0)   # and reopens at 200
	_assert_ticks(
		h.field.fired_ticks(),
		[148, 154, 248],
		"the dropped burst does not resume and the next activation waits start_delay"
	)


func test_pattern_gate_toggled_faster_than_start_delay_never_fires() -> void:
	var h := PatternHarness.new()
	var d := PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 84, "count": 1, "min_intensity": 0.5,
	})
	var e := h.add_emitter([d], 0)
	for t: int in range(600):
		h.log.rotate()
		h.field.tick = t
		e.update(Vector2(180.0, 100.0), Vector2(180.0, 100.0), 1.0 if (t / 20) % 2 == 0 else 0.0)
		h.scene.tick(t)
	_assert_eq(h.field.size(), 0, "a gate toggled every 20 ticks never reaches start_delay 48")


func test_pattern_states_follow_the_gdd_table() -> void:
	var h := PatternHarness.new()
	var d := PatternHarness.make(FAN, {
		"start_delay": 48, "burst_count": 6, "burst_gap": 6, "interval": 84, "count": 1,
		"lock_ticks": 30,
	})
	var e := h.add_emitter([d], 100)
	var runner: PatternRunner = e.runners[0]
	_assert_eq(runner.state, PatternRunner.State.WAITING, "activated -> Waiting")
	h.run(e, 100, 148)
	_assert_eq(runner.state, PatternRunner.State.FIRING, "first volley -> Firing")
	h.run(e, 149, 178)
	_assert_eq(runner.state, PatternRunner.State.COOLING, "last volley of the burst -> Cooling")
	h.run(e, 179, 202)
	_assert_eq(runner.state, PatternRunner.State.LOCKING, "lock_ticks before the burst -> Locking")
	h.run(e, 203, 232)
	_assert_eq(runner.state, PatternRunner.State.FIRING, "the locked burst -> Firing")
	e.stop(false)
	_assert_eq(runner.state, PatternRunner.State.STOPPED, "stop -> Stopped")


# --- AC-13, AC-14, Rule 8 ----------------------------------------------------

func test_pattern_fire_hold_skips_volleys_but_keeps_the_rhythm() -> void:
	var held := _spiral_run(PackedInt32Array([154, 166]))
	var free := _spiral_run(PackedInt32Array())
	var h: PatternHarness = held[0]
	var f: PatternHarness = free[0]
	var runner: PatternRunner = held[1]

	_assert_ticks(h.field.fired_ticks(), [148, 172, 178], "volleys inside the hold fire nothing")
	_assert_eq(runner.volley_counter(), 6, "the volley counter counts skipped volleys too")
	_assert_eq(h.scene.emitters[0].target_cursor, 0, "the cursor advanced once, for the burst")

	# The 172 volley must use phi(4), exactly as in the unheld run.
	var held_172 := h.field.indices_at(172)
	var free_172 := f.field.indices_at(172)
	_assert_eq(held_172.size(), 2, "the 172 volley fires both arms")
	for k: int in range(held_172.size()):
		_assert_bam(
			h.field.angle_bam(held_172[k]),
			f.field.angle_bam(free_172[k]),
			"arm %d of the post-hold volley matches the unheld run" % k
		)


func test_pattern_skipped_volley_still_draws_its_randomness() -> void:
	for name: String in ["wave_1941_wall", "wave_1941_spray", "fortress_engine_ring"]:
		var held := _seeded_run(name, PackedInt32Array([154, 160]))
		var free := _seeded_run(name, PackedInt32Array())
		_assert_eq(
			held[0], free[0],
			"%s: the RNG state after the burst ignores the fire hold" % name
		)
		_assert_eq(
			held[1], free[1],
			"%s: the post-hold requests are identical to the unheld run" % name
		)


# --- AC-15, AC-18, AC-19, flak fuses -----------------------------------------

func test_pattern_flak_fuse_inside_a_hold_is_used_up_and_never_fires_late() -> void:
	var h := PatternHarness.new()
	var e := h.add_emitter([_flak()], 100)
	h.run(e, 100, 183)
	_assert_eq(h.field.size(), 0, "a flak volley spawns nothing when the fuse is lit")
	_assert_eq(e.runners[0].pending_fuses(), 1, "the fuse is lit at the volley tick")
	h.run(e, 184, 184, Vector2(180.0, 100.0), 0.0, PackedInt32Array([184, 184]))
	_assert_eq(h.field.size(), 0, "the ring is skipped when the burst falls in a hold")
	_assert_eq(e.runners[0].pending_fuses(), 0, "and the fuse is used up, not deferred")
	h.run(e, 185, 240)
	_assert_eq(h.field.size(), 0, "the skipped ring never fires late")

	# A volley fired inside a hold lights no fuse at all.
	var h2 := PatternHarness.new()
	var e2 := h2.add_emitter([_flak()], 100)
	h2.run(e2, 100, 200, Vector2(180.0, 100.0), 0.0, PackedInt32Array([140, 160]))
	_assert_eq(e2.runners[0].pending_fuses(), 0, "a held volley lights no fuse")
	_assert(
		not h2.has_event(TickEventLog.Kind.PATTERN_FLAK_FUSE), "and sends no flak_fuse event"
	)


func test_pattern_stop_mid_burst_fires_nothing_more() -> void:
	var h := PatternHarness.new()
	var d := PatternHarness.make(FAN, {
		"start_delay": 48, "burst_count": 6, "burst_gap": 6, "interval": 84, "count": 1,
	})
	var e := h.add_emitter([d], 100)
	# Held before the stop: the scene drops a stopped emitter and disposes it,
	# which is what keeps the reference cycle from leaking.
	var runner: PatternRunner = e.runners[0]
	h.run(e, 100, 159)
	e.stop(false)
	h.run(e, 160, 300)
	_assert_ticks(h.field.fired_ticks(), [148, 154], "a stopped emitter fires nothing more")
	_assert_eq(runner.state, PatternRunner.State.STOPPED, "and stays Stopped")


func test_pattern_fuse_survives_a_gate_or_a_plain_stop() -> void:
	# Gated out at 160, with a fuse due at 184.
	var h := PatternHarness.new()
	var gated := _flak()
	gated.min_intensity = 0.5
	var e := h.add_emitter([gated], 100)
	e.update(Vector2(180.0, 100.0), Vector2(180.0, 100.0), 1.0)
	h.run(e, 100, 159, Vector2(180.0, 100.0), 1.0)
	h.run(e, 160, 200, Vector2(180.0, 100.0), 0.0)
	_assert_eq(h.field.indices_at(184).size(), 12, "a lit fuse bursts although the runner is gated")

	# Stopped without being destroyed, same fuse.
	var h2 := PatternHarness.new()
	var e2 := h2.add_emitter([_flak()], 100)
	h2.run(e2, 100, 159)
	e2.stop(false)
	h2.run(e2, 160, 200)
	_assert_eq(h2.field.indices_at(184).size(), 12, "and bursts after a plain stop")


func test_pattern_fuse_is_cancelled_when_the_owner_is_destroyed() -> void:
	var h := PatternHarness.new()
	var e := h.add_emitter([_flak()], 100)
	h.run(e, 100, 159)
	_assert_eq(e.runners[0].pending_fuses(), 1, "the fuse is lit before the owner dies")
	e.stop(true)
	h.run(e, 160, 220)
	_assert_eq(h.field.size(), 0, "a destroyed gun fires nothing, fuses included")
	_assert_eq(h.scene.lit_fuses, 0, "and the scene's fuse count is released")

	# remove_all_emitters cancels every lit fuse (stage end).
	var h2 := PatternHarness.new()
	var e2 := h2.add_emitter([_flak()], 100)
	h2.run(e2, 100, 159)
	h2.scene.remove_all_emitters()
	_assert_eq(h2.scene.lit_fuses, 0, "clearing the scene cancels every lit fuse")
	h2.run(e2, 160, 220)
	_assert_eq(h2.field.size(), 0, "and none of them bursts")


func test_pattern_scene_fuse_cap_skips_the_ninth_fuse() -> void:
	var h := PatternHarness.new()
	var cap: int = h.rules.flak_fuse_max
	var emitters: Array[PatternEmitter] = []
	for i: int in range(cap + 2):
		var d := _flak()
		d.flak_delay = 600          # long enough that none bursts during the test
		emitters.push_back(h.add_emitter([d], 100, i + 1, 0))
	for t: int in range(100, 150):
		h.log.rotate()
		h.field.tick = t
		for i: int in range(emitters.size()):
			emitters[i].update(Vector2(180.0, 100.0), Vector2(180.0, 100.0), 0.0)
		h.scene.tick(t)
	_assert_eq(h.scene.lit_fuses, cap, "the scene never lights more than flak_fuse_max fuses")
	var lit := 0
	for i: int in range(emitters.size()):
		lit += emitters[i].runners[0].pending_fuses()
	_assert_eq(lit, cap, "the volleys past the cap are skipped, not queued")
	for i: int in range(emitters.size()):
		_assert_eq(
			emitters[i].runners[0].volley_counter(), 1,
			"emitter %d counts its volley as fired even when the cap skipped it" % i
		)


# --- helpers -----------------------------------------------------------------

func _flak() -> PatternDef:
	return PatternHarness.make(FLAK, {
		"start_delay": 48, "interval": 150, "count": 12, "speed": 120.0,
		"flak_delay": 36, "flak_distance": 240.0, "standoff": 56.0,
		"offset_mode": PatternDef.OffsetMode.SEEDED,
	})


## The AC-13 spiral: the AC-06 schedule, with an optional inclusive fire hold.
func _spiral_run(hold: PackedInt32Array) -> Array:
	var h := PatternHarness.new()
	var d := PatternHarness.make(SPIRAL, {
		"start_delay": 48, "burst_count": 6, "burst_gap": 6, "interval": 84,
		"arms": 2, "step_rad": 0.33, "speed": 140.0,
	})
	var e := h.add_emitter([d], 100)
	h.run(e, 100, 178, Vector2(180.0, 100.0), 0.0, hold)
	return [h, e.runners[0]]


## Runs one seeded authored pattern with and without a hold, returning the
## emitter's RNG state and the requests made after the hold.
func _seeded_run(name: String, hold: PackedInt32Array) -> Array:
	var h := PatternHarness.new()
	var d := PatternHarness.pattern(name)
	var e := h.add_emitter([d], 100)
	h.run(e, 100, 600, Vector2(180.0, 100.0), 0.0, hold)
	var after := PackedFloat32Array()
	for i: int in range(h.field.size()):
		if h.field.ticks[i] > 200:
			after.push_back(h.field.xs[i])
			after.push_back(h.field.vxs[i])
			after.push_back(h.field.vys[i])
	return [e.rng.state, after]


# --- assertions --------------------------------------------------------------

func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])


func _assert_bam(got: int, want: int, what: String) -> void:
	# The GDD allows +/- 1 binary angle unit (about 0.0055 degrees).
	if absi(SimMath.delta_bam(want, got)) > 1:
		_failures += 1
		print("FAIL: %s -- got %d bam, want %d bam" % [what, got, want])


func _assert_ticks(got: PackedInt32Array, want: Array, what: String) -> void:
	var want_packed := PackedInt32Array(want)
	if got != want_packed:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want_packed])
