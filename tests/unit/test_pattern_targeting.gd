extends SceneTree
## Co-op targeting, aim and aim lock for the pattern library
## (design/gdd/bullet-pattern-library.md Rules 10-13, F4, F5,
## AC-21 - AC-28).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_pattern_targeting.gd

var _failures := 0

const FAN := PatternDef.Kind.AIMED_FAN
const RING := PatternDef.Kind.RING
const QUARTER := SimMath.QUARTER


func _init() -> void:
	test_pattern_target_rotates_to_the_next_alive_slot_each_burst()
	test_pattern_target_cursor_holds_still_when_nobody_is_alive()
	test_pattern_every_bullet_of_a_burst_stores_the_same_target()
	test_pattern_cursor_advances_once_per_burst_even_when_held()
	test_pattern_join_or_death_mid_burst_changes_nothing_until_the_next_burst()
	test_pattern_aim_matches_the_gdd_worked_example()
	test_pattern_aim_below_half_a_pixel_fires_straight_down()
	test_pattern_aim_has_no_upward_clamp()
	test_pattern_no_target_fires_down_and_stores_slot_zero()
	test_pattern_normal_burst_aims_once_and_reaim_tracks()
	test_pattern_reaim_keeps_its_last_aim_when_the_target_dies()
	test_pattern_lock_samples_the_position_lock_ticks_early()
	test_pattern_locked_burst_fires_even_if_the_target_dies()
	test_pattern_short_start_delay_samples_the_lock_at_activation()
	test_pattern_lock_cursor_advances_at_the_lock_tick()
	test_pattern_lock_ends_unfired_when_the_gate_shuts_during_the_tell()
	test_pattern_lock_with_nobody_alive_shows_no_tell_and_fires_down()

	PatternHarness.dispose_all()
	print("PatternTargeting tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- AC-22, AC-23, F4 --------------------------------------------------------

func test_pattern_target_rotates_to_the_next_alive_slot_each_burst() -> void:
	var h := _coop(PackedInt32Array([1, 0, 1, 1]))
	var e := h.add_emitter([_fan(1)], 100)
	# Four bursts, interval 84: 148, 232, 316, 400.
	h.run(e, 100, 410)
	_assert_slots(h, [148, 232, 316, 400], [0, 2, 3, 0], "Alive {0,2,3} rotates 0, 2, 3, 0")

	# A new emitter with Alive {1, 3} picks the lowest Alive slot first.
	var h2 := _coop(PackedInt32Array([0, 1, 0, 1]))
	var e2 := h2.add_emitter([_fan(1)], 100)
	h2.run(e2, 100, 240)
	_assert_slots(h2, [148, 232], [1, 3], "a new emitter starts at the lowest Alive slot")

	# Solo: always that player.
	var h3 := _coop(PackedInt32Array([0, 0, 1, 0]))
	var e3 := h3.add_emitter([_fan(1)], 100)
	h3.run(e3, 100, 330)
	_assert_slots(h3, [148, 232, 316], [2, 2, 2], "solo always targets the one player")


func test_pattern_target_cursor_holds_still_when_nobody_is_alive() -> void:
	var h := _coop(PackedInt32Array([0, 1, 0, 0]))
	var e := h.add_emitter([_fan(1)], 100)
	h.run(e, 100, 160)                       # burst at 148 targets slot 1
	_assert_eq(e.target_cursor, 1, "the cursor sits on slot 1")
	h.set_nobody_alive()
	h.run(e, 161, 240)                       # burst at 232 has nobody to aim at
	_assert_eq(e.target_cursor, 1, "with nobody Alive the cursor does not move")
	_assert_eq(h.field.slots[h.field.indices_at(232)[0]], 0, "and bullets store slot 0 (Rule 11)")
	h.set_alive(3, true)
	h.run(e, 241, 330)                       # burst at 316
	_assert_eq(
		h.field.slots[h.field.indices_at(316)[0]], 3,
		"the rotation resumes from the cursor and finds slot 3"
	)


func test_pattern_every_bullet_of_a_burst_stores_the_same_target() -> void:
	var h := _coop(PackedInt32Array([1, 1, 0, 0]))
	# A ring is not aimed, but it still stores the burst's target so a Warp
	# ring knows whom to re-aim at (Rule 10).
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 120, "burst_count": 6, "burst_gap": 6, "count": 8,
		"speed": 120.0, "offset_mode": PatternDef.OffsetMode.SEEDED,
	})
	var e := h.add_emitter([ring], 100)
	h.run(e, 100, 185)
	var idx := h.field.indices_at(148)
	_assert_eq(idx.size(), 8, "the ring fires 8 bullets")
	var want: int = h.field.slots[idx[0]]
	var same := true
	for i: int in range(h.field.size()):
		if h.field.slots[i] != want:
			same = false
	_assert(same, "every bullet of the 6-volley burst stores the burst's one target")


func test_pattern_cursor_advances_once_per_burst_even_when_held() -> void:
	var h := _coop(PackedInt32Array([1, 1, 1, 1]))
	var e := h.add_emitter([_fan(1)], 100)
	# Hold covers the whole first burst; the cursor must still advance.
	h.run(e, 100, 200, Vector2(180.0, 100.0), 0.0, PackedInt32Array([140, 160]))
	_assert_eq(e.target_cursor, 0, "a burst skipped by the fire hold still advanced the cursor")
	h.run(e, 201, 240)
	_assert_eq(
		h.field.slots[h.field.indices_at(232)[0]], 1,
		"so the next burst targets slot 1, not slot 0 again"
	)


func test_pattern_join_or_death_mid_burst_changes_nothing_until_the_next_burst() -> void:
	var h := _coop(PackedInt32Array([1, 0, 0, 0]))
	var stream := PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 120, "burst_count": 6, "burst_gap": 6, "count": 1,
	})
	var e := h.add_emitter([stream], 100)
	h.run(e, 100, 165)                      # volleys 148, 154, 160
	h.set_alive(1, true)                    # slot 1 joins on volley 3
	h.run(e, 166, 185)                      # volleys 166, 172, 178
	for i: int in range(h.field.size()):
		_assert_eq(h.field.slots[i], 0, "the burst keeps targeting slot 0 throughout")
	h.run(e, 186, 275)                      # next burst at 268
	_assert_eq(
		h.field.slots[h.field.indices_at(268)[0]], 1, "the next rotation includes the new slot"
	)


# --- AC-25, AC-26, F5 --------------------------------------------------------

func test_pattern_aim_matches_the_gdd_worked_example() -> void:
	var angle := _single_shot_angle(Vector2(180.0, 100.0), Vector2(210.0, 500.0))
	_assert_bam(angle, SimMath.rad_to_bam(1.4959), "O (180,100) -> T (210,500) is 1.4959 rad")


func test_pattern_aim_below_half_a_pixel_fires_straight_down() -> void:
	var near := _single_shot_angle(Vector2(180.0, 100.0), Vector2(180.3, 100.3))
	_assert_bam(near, QUARTER, "a target 0.424 px away gives pi/2")
	var exact := _single_shot_angle(Vector2(180.0, 100.0), Vector2(180.5, 100.0))
	_assert_bam(exact, 0, "a target exactly 0.5 px to the right gives 0")


func test_pattern_aim_has_no_upward_clamp() -> void:
	var up := _single_shot_angle(Vector2(180.0, 100.0), Vector2(180.0, 50.0))
	_assert_bam(up, -QUARTER & SimMath.MASK, "a player above the emitter is fired at upward")


func test_pattern_no_target_fires_down_and_stores_slot_zero() -> void:
	var h := PatternHarness.new()
	h.set_nobody_alive()
	var e := h.add_emitter([_fan(1)], 100)
	h.run(e, 100, 150)
	var i := h.field.indices_at(148)[0]
	_assert_bam(h.field.angle_bam(i), QUARTER, "with nobody Alive the fan fires straight down")
	_assert_eq(h.field.slots[i], 0, "and the bullet stores slot 0")


func test_pattern_normal_burst_aims_once_and_reaim_tracks() -> void:
	var fixed := _stream_angles(false)
	_assert_bam(fixed[0], fixed[1], "a normal burst keeps volley 0's aim after the target moves")

	var tracking := _stream_angles(true)
	_assert(
		absi(SimMath.delta_bam(tracking[0], tracking[1])) > 1,
		"reaim_each_volley recomputes the aim from the target's new position"
	)


func test_pattern_reaim_keeps_its_last_aim_when_the_target_dies() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true)
	var stream := PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 120, "burst_count": 3, "burst_gap": 6, "count": 1,
		"reaim_each_volley": true,
	})
	var e := h.add_emitter([stream], 100)
	h.run(e, 100, 153)
	h.set_slot(0, Vector2(300.0, 500.0), false)   # the target dies after volley 1
	h.run(e, 154, 165)
	var a0 := h.field.angle_bam(h.field.indices_at(148)[0])
	var a2 := h.field.angle_bam(h.field.indices_at(160)[0])
	_assert_bam(a2, a0, "a re-aiming burst keeps its last aim once the target is not Alive")


# --- AC-21, AC-27, AC-28, Rule 13 -------------------------------------------

func test_pattern_lock_samples_the_position_lock_ticks_early() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true)
	var e := h.add_emitter([_locked_fan(30, 48)], 100)
	h.run(e, 100, 129)
	var started := h.recorded(TickEventLog.Kind.PATTERN_LOCK_STARTED)
	_assert_eq(started.size(), 1, "one lock tell started")
	_assert_eq(started[0].x, 118, "the tell starts at S - lock_ticks = 118")
	_assert_eq(started[0].y, 0, "and names the locked slot")

	h.set_slot(0, Vector2(60.0, 560.0), true)      # the player moves at 130
	h.run(e, 130, 150)
	var i := h.field.indices_at(148)[0]
	_assert_bam(
		h.field.angle_bam(i),
		SimMath.atan2_bam(500.0 - 100.0, 180.0 - 180.0),
		"the burst still goes to the point locked at 118"
	)
	var ended := h.recorded(TickEventLog.Kind.PATTERN_LOCK_ENDED)
	_assert_eq(ended.size(), 1, "the tell ended once")
	_assert_eq(ended[0].x, 148, "on the burst tick")
	_assert_eq(ended[0].z, 1, "reporting that it fired")


func test_pattern_locked_burst_fires_even_if_the_target_dies() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true)
	var e := h.add_emitter([_locked_fan(30, 48)], 100)
	h.run(e, 100, 129)
	h.set_slot(0, Vector2(180.0, 500.0), false)    # dies between lock and burst
	h.run(e, 130, 150)
	_assert_eq(h.field.indices_at(148).size(), 1, "the locked burst fires anyway")
	_assert_eq(h.field.slots[0], 0, "and its bullets keep the slot chosen at the lock tick")


func test_pattern_short_start_delay_samples_the_lock_at_activation() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true)
	var e := h.add_emitter([_locked_fan(30, 18)], 100)
	h.run(e, 100, 125)
	var started := h.recorded(TickEventLog.Kind.PATTERN_LOCK_STARTED)
	_assert_eq(started.size(), 1, "the tell still starts")
	_assert_eq(started[0].x, 100, "at T_act, because start_delay 18 is shorter than lock_ticks 30")


func test_pattern_lock_cursor_advances_at_the_lock_tick() -> void:
	var h := _coop(PackedInt32Array([1, 1, 0, 0]))
	var e := h.add_emitter([_locked_fan(30, 48)], 100)
	h.run(e, 100, 117)
	_assert_eq(e.target_cursor, -1, "the cursor has not moved before the lock tick")
	h.run(e, 118, 118)
	_assert_eq(e.target_cursor, 0, "it advances at the lock tick, not at the burst tick")
	h.set_alive(2, true)                      # joins between lock and burst
	h.run(e, 119, 150)
	_assert_eq(h.field.slots[0], 0, "the burst keeps the slot locked at 118")


func test_pattern_lock_ends_unfired_when_the_gate_shuts_during_the_tell() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true)
	var gated := _locked_fan(30, 48)
	gated.min_intensity = 0.5
	var e := h.add_emitter([gated], 100)
	e.update(Vector2(180.0, 100.0), Vector2(180.0, 100.0), 1.0)
	h.run(e, 100, 124, Vector2(180.0, 100.0), 1.0)
	h.run(e, 125, 160, Vector2(180.0, 100.0), 0.0)
	var ended := h.recorded(TickEventLog.Kind.PATTERN_LOCK_ENDED)
	_assert_eq(ended.size(), 1, "the tell ended")
	_assert_eq(ended[0].x, 125, "on the tick the gate shut")
	_assert_eq(ended[0].z, 0, "reporting that it did not fire")
	_assert_eq(h.field.size(), 0, "and no bullets followed")


func test_pattern_lock_with_nobody_alive_shows_no_tell_and_fires_down() -> void:
	var h := PatternHarness.new()
	h.set_nobody_alive()
	var e := h.add_emitter([_locked_fan(30, 48)], 100)
	h.run(e, 100, 150)
	_assert_eq(
		h.recorded(TickEventLog.Kind.PATTERN_LOCK_STARTED).size(), 0,
		"no tell is shown when there is nobody to lock"
	)
	var i := h.field.indices_at(148)[0]
	_assert_bam(h.field.angle_bam(i), QUARTER, "the burst fires straight down")
	_assert_eq(h.field.slots[i], 0, "with slot 0 stored")


# --- helpers -----------------------------------------------------------------

func _fan(count: int) -> PatternDef:
	return PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 84, "count": count, "spread_rad": 0.165,
	})


func _locked_fan(lock_ticks: int, start_delay: int) -> PatternDef:
	return PatternHarness.make(FAN, {
		"start_delay": start_delay, "interval": 120, "count": 1, "lock_ticks": lock_ticks,
	})


## A harness with the given Alive mask, all four slots spread across the lower
## half of the canvas so each aim is a different angle.
func _coop(alive: PackedInt32Array) -> PatternHarness:
	var h := PatternHarness.new()
	var spots := [
		Vector2(180.0, 500.0), Vector2(60.0, 520.0), Vector2(300.0, 520.0), Vector2(120.0, 560.0)
	]
	for s: int in range(PatternScene.MAX_SLOTS):
		h.set_slot(s, spots[s], alive[s] != 0)
	return h


## One aimed bullet's angle, with the target at `target` and the emitter at
## `origin`. Spawn safety is out of the way because the emitter and the target
## are far apart in every case the ACs quote.
func _single_shot_angle(origin: Vector2, target: Vector2) -> int:
	var h := PatternHarness.new()
	h.set_slot(0, target, true, 0)   # Alive but not Active: no spawn-safety skip
	var e := h.add_emitter([_fan(1)], 100)
	h.run(e, 100, 150, origin)
	var idx := h.field.indices_at(148)
	if idx.size() == 0:
		_failures += 1
		print("FAIL: the aim probe fired nothing")
		return -1
	return h.field.angle_bam(idx[0])


## Volley 0's and volley 2's angles for a 3-volley stream whose target moves
## between them.
func _stream_angles(reaim: bool) -> PackedInt32Array:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 500.0), true, 0)
	var stream := PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 120, "burst_count": 3, "burst_gap": 6, "count": 1,
		"reaim_each_volley": reaim,
	})
	var e := h.add_emitter([stream], 100)
	h.run(e, 100, 153)
	h.set_slot(0, Vector2(60.0, 560.0), true, 0)
	h.run(e, 154, 165)
	return PackedInt32Array([
		h.field.angle_bam(h.field.indices_at(148)[0]),
		h.field.angle_bam(h.field.indices_at(160)[0]),
	])


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
	if absi(SimMath.delta_bam(want, got)) > 1:
		_failures += 1
		print("FAIL: %s -- got %d bam, want %d bam" % [what, got, want])


## Asserts the target slot stored by the first bullet of each listed tick.
func _assert_slots(h: PatternHarness, ticks: Array, slots: Array, what: String) -> void:
	for k: int in range(ticks.size()):
		var idx := h.field.indices_at(ticks[k])
		if idx.size() == 0:
			_failures += 1
			print("FAIL: %s -- no bullet on tick %d" % [what, ticks[k]])
			continue
		if h.field.slots[idx[0]] != slots[k]:
			_failures += 1
			print(
				"FAIL: %s -- tick %d targeted slot %d, want %d"
				% [what, ticks[k], h.field.slots[idx[0]], slots[k]]
			)
