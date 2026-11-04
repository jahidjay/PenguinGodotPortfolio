extends SceneTree
## Spawn safety and pool refusals for the pattern library
## (design/gdd/bullet-pattern-library.md Rule 14, F7, AC-04, AC-37 - AC-39,
## AC-45).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_pattern_safety.gd

var _failures := 0

const FAN := PatternDef.Kind.AIMED_FAN
const RING := PatternDef.Kind.RING
const WALL := PatternDef.Kind.WALL
const FLAK := PatternDef.Kind.FLAK_BURST

## Where the probe emitter sits in every test below.
const ORIGIN := Vector2(180.0, 100.0)


func _init() -> void:
	test_pattern_spawn_safety_skips_a_bullet_inside_the_radius()
	test_pattern_spawn_safety_honours_a_per_pattern_override()
	test_pattern_spawn_safety_ignores_a_player_who_is_not_active()
	test_pattern_spawn_safety_protects_every_active_player()
	test_pattern_fully_skipped_volley_still_advances_everything()
	test_pattern_partial_volley_fires_the_rest_and_sounds_once()
	test_pattern_safety_skip_next_to_a_wall_gap_only_widens_it()
	test_pattern_flak_ring_is_checked_against_every_player_at_burst_time()
	test_pattern_request_carries_every_field_the_bullet_needs()
	test_pattern_pool_refusal_is_not_retried()

	PatternHarness.dispose_all()
	print("PatternSafety tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- AC-37, F7 ---------------------------------------------------------------

func test_pattern_spawn_safety_skips_a_bullet_inside_the_radius() -> void:
	# Arrange: the bullet spawns at the emitter, so the player's distance from
	# the emitter IS the spawn distance.
	_assert_eq(_fired_with_player_at(40.0, -1.0), 0, "a bullet 40 px from a player is skipped")
	_assert_eq(_fired_with_player_at(42.0, -1.0), 1, "one exactly 42 px away spawns (strict <)")
	_assert_eq(_fired_with_player_at(44.0, -1.0), 1, "and one 44 px away spawns")


func test_pattern_spawn_safety_honours_a_per_pattern_override() -> void:
	_assert_eq(
		_fired_with_player_at(70.0, 76.25), 0,
		"with a 76.25 px override, a bullet 70 px away is skipped"
	)
	_assert_eq(
		_fired_with_player_at(80.0, 76.25), 1, "and one 80 px away still spawns"
	)


func test_pattern_spawn_safety_ignores_a_player_who_is_not_active() -> void:
	var h := PatternHarness.new()
	# Alive (so it is targeted) but flying in, 10 px from the muzzle.
	h.set_flying_in(0, ORIGIN + Vector2(0.0, 10.0))
	var e := h.add_emitter([_fan()], 100)
	h.run(e, 100, 150, ORIGIN)
	_assert_eq(
		h.field.indices_at(148).size(), 1,
		"spawn safety ignores a plane that is Alive but not Active"
	)
	_assert_eq(h.scene.total_spawn_safety_skips, 0, "and counts no skip")


func test_pattern_spawn_safety_protects_every_active_player() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(20.0, 600.0), true)          # far away
	h.set_slot(1, ORIGIN + Vector2(0.0, 30.0), true)   # right under the muzzle
	var e := h.add_emitter([_fan()], 100)
	h.run(e, 100, 150, ORIGIN)
	_assert_eq(
		h.field.size(), 0, "a bullet near ANY Active player is skipped, not just the target"
	)


# --- AC-38 -------------------------------------------------------------------

func test_pattern_fully_skipped_volley_still_advances_everything() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, ORIGIN, true)                 # standing on the muzzle
	h.set_slot(1, Vector2(300.0, 600.0), true)
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 84, "count": 12, "speed": 120.0,
		"offset_mode": PatternDef.OffsetMode.SEEDED,
	})
	var e := h.add_emitter([ring], 100)
	h.run(e, 100, 150, ORIGIN)

	_assert_eq(h.field.size(), 0, "a volley entirely inside the radius spawns nothing")
	_assert_eq(h.scene.total_spawn_safety_skips, 12, "every skipped bullet is counted")
	_assert(
		not h.has_event(TickEventLog.Kind.PATTERN_VOLLEY_FIRED),
		"and no volley_fired is sent, so there is no sound"
	)
	_assert_eq(e.runners[0].volley_counter(), 1, "the volley counter advanced")
	_assert_eq(e.target_cursor, 0, "the target cursor advanced")

	# The random stream advanced exactly as it would have with nobody near.
	var probe := SimRng.make(SimRng.EMITTER, [h.scene.run_seed, 0, 1, 0])
	probe.randf()
	_assert_eq(e.rng.state, probe.state, "and the ring still drew its rotation")

	# The next volley is on schedule, not retried early.
	h.set_slot(0, Vector2(20.0, 600.0), true)
	h.run(e, 151, 240, ORIGIN)
	_assert_eq(h.field.indices_at(232).size(), 12, "the next volley fires on schedule")


func test_pattern_partial_volley_fires_the_rest_and_sounds_once() -> void:
	var h := PatternHarness.new()
	# A 7-slot wall at x 132..228; the player sits on the x-180 slot.
	h.set_slot(0, Vector2(180.0, 100.0), true)
	var wall := PatternHarness.make(WALL, {
		"start_delay": 48, "interval": 138, "count": 7, "spacing": 16.0, "speed": 110.0,
	})
	var e := h.add_emitter([wall], 100)
	h.run(e, 100, 148, Vector2(180.0, 100.0))
	var fired := h.field.indices_at(148).size()
	_assert(fired > 0 and fired < 6, "part of the wall fires and part is skipped (got %d)" % fired)
	_assert_eq(
		h.events_of(TickEventLog.Kind.PATTERN_VOLLEY_FIRED).size(), 1,
		"a partial volley still sends exactly one volley_fired"
	)
	_assert(h.scene.total_spawn_safety_skips > 0, "and the skipped bullets are counted")


# --- AC-39 -------------------------------------------------------------------

func test_pattern_safety_skip_next_to_a_wall_gap_only_widens_it() -> void:
	# The same wall volley, with and without a player standing in it. Safety
	# may only REMOVE bullets: every bullet in the guarded run must also be in
	# the clear run, at the same x.
	var clear := _wall_xs(Vector2(20.0, 600.0))
	var guarded := _wall_xs(Vector2(196.0, 100.0))
	_assert(guarded.size() < clear.size(), "a player in the wall removes at least one bullet")
	var subset := true
	for i: int in range(guarded.size()):
		var found := false
		for k: int in range(clear.size()):
			if absf(clear[k] - guarded[i]) < 0.01:
				found = true
		if not found:
			subset = false
	_assert(subset, "and adds or moves none: the corridor can only get wider")


func test_pattern_flak_ring_is_checked_against_every_player_at_burst_time() -> void:
	# Slot 0 is the target, far down the screen; the shell bursts at (180, 340),
	# 240 px along the aim. Slot 1 is NOT the target but stands on that point.
	#
	# A ring spawns every bullet at its centre and differs only in direction
	# (F6b), so a player standing on a burst point loses the whole ring, not a
	# sector of it: AC-39's "only the ring bullets within that player's radius"
	# is all twelve, by construction.
	_assert_eq(
		_flak_ring_size_with_bystander(Vector2(180.0, 340.0)), 0,
		"a bystander on the burst point stops the ring"
	)
	_assert_eq(
		_flak_ring_size_with_bystander(Vector2(180.0, 384.0)), 12,
		"a bystander 44 px from it does not"
	)
	_assert_eq(
		_flak_ring_size_with_bystander(Vector2(20.0, 600.0)), 12,
		"and with nobody near, the whole ring fires"
	)


# --- AC-04, AC-45 ------------------------------------------------------------

func test_pattern_request_carries_every_field_the_bullet_needs() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 520.0), true)
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 84, "count": 24, "speed": 120.0,
		"shape": BulletRules.Shape.RICE, "behaviour": BulletField.Beh.ACCEL,
	})
	var e := h.add_emitter([ring], 100)
	h.run(e, 100, 150, ORIGIN)
	var idx := h.field.indices_at(148)
	_assert_eq(idx.size(), 24, "all 24 bullets are requested")
	for i: int in idx:
		_assert_close(h.field.xs[i], ORIGIN.x, "request x")
		_assert_close(h.field.ys[i], ORIGIN.y, "request y")
		_assert_close(h.field.speed_of(i), 120.0, "request speed", 0.05)
		_assert_eq(h.field.shapes[i], BulletRules.Shape.RICE, "request shape")
		_assert_eq(h.field.behs[i], BulletField.Beh.ACCEL, "request behaviour")
		_assert_eq(h.field.slots[i], 0, "request target slot")


func test_pattern_pool_refusal_is_not_retried() -> void:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 520.0), true)
	h.field.accept_limit = 5
	var ring := PatternHarness.make(RING, {
		"start_delay": 48, "interval": 84, "count": 24, "speed": 120.0,
		"offset_mode": PatternDef.OffsetMode.SEEDED,
	})
	var e := h.add_emitter([ring], 100)
	h.run(e, 100, 150, ORIGIN)
	_assert_eq(h.field.size(), 5, "the field accepted its 5")
	_assert_eq(h.field.refused, 19, "and refused the other 19")

	# The refused bullets are never retried, and nothing about the schedule or
	# the random stream changed.
	h.field.accept_limit = -1
	h.run(e, 151, 240, ORIGIN)
	_assert_eq(h.field.indices_at(232).size(), 24, "the next volley fires in full, on schedule")
	_assert_eq(e.runners[0].volley_counter(), 2, "two volleys were counted, not three")
	var probe := SimRng.make(SimRng.EMITTER, [h.scene.run_seed, 0, 1, 0])
	probe.randf()
	probe.randf()
	_assert_eq(e.rng.state, probe.state, "and exactly two rotations were drawn")


# --- helpers -----------------------------------------------------------------

func _fan() -> PatternDef:
	return PatternHarness.make(FAN, {
		"start_delay": 48, "interval": 84, "count": 1, "speed": 150.0,
	})


## Fires one single-bullet volley with the one Active player `distance` px
## below the muzzle. Returns how many bullets reached the field.
func _fired_with_player_at(distance: float, override_radius: float) -> int:
	var h := PatternHarness.new()
	h.set_slot(0, ORIGIN + Vector2(0.0, distance), true)
	var d := _fan()
	d.spawn_safe_radius = override_radius
	var e := h.add_emitter([d], 100)
	h.run(e, 100, 150, ORIGIN)
	return h.field.indices_at(148).size()


## How many bullets a flak ring spawns with a non-target Active player at
## `bystander`, who arrives after the fuse is lit.
func _flak_ring_size_with_bystander(bystander: Vector2) -> int:
	var h := PatternHarness.new()
	h.set_slot(0, Vector2(180.0, 520.0), true)
	var flak := PatternHarness.make(FLAK, {
		"start_delay": 48, "interval": 150, "count": 12, "speed": 120.0,
		"flak_delay": 36, "flak_distance": 240.0, "standoff": 56.0,
	})
	var e := h.add_emitter([flak], 100)
	h.run(e, 100, 183, ORIGIN)
	h.set_slot(1, bystander, true)
	h.run(e, 184, 184, ORIGIN)
	return h.field.indices_at(184).size()


## The x of every bullet of one wall volley, with one Active player at `player`.
func _wall_xs(player: Vector2) -> PackedFloat32Array:
	var h := PatternHarness.new()
	h.set_slot(0, player, true)
	var wall := PatternHarness.make(WALL, {
		"start_delay": 48, "interval": 138, "count": 7, "spacing": 16.0, "speed": 110.0,
	})
	var e := h.add_emitter([wall], 100)
	h.run(e, 100, 148, Vector2(180.0, 100.0))
	var out := PackedFloat32Array()
	for i: int in h.field.indices_at(148):
		out.push_back(h.field.xs[i])
	return out


# --- assertions --------------------------------------------------------------

func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])


func _assert_close(got: float, want: float, what: String, tol := 0.01) -> void:
	if absf(got - want) > tol:
		_failures += 1
		print("FAIL: %s -- got %.4f, want %.4f (+/- %.3f)" % [what, got, want, tol])
