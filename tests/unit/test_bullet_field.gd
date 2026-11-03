extends SceneTree
## Unit tests for BulletField (design/gdd/bullet-manager.md, ADR-0001).
## No test framework yet; see /test-setup.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_bullet_field.gd
## Exit code 0 = pass, 1 = fail.
##
## Tuning is built in each test rather than loaded from data/bullet_rules.tres,
## so a designer retuning the game cannot break these tests.

const PLAY_AREA := Rect2(0, 0, 360, 640)

var _failures := 0


func _init() -> void:
	test_bullet_field_spawn_increments_count()
	test_bullet_field_spawn_beyond_capacity_is_rejected()
	test_bullet_field_linear_bullet_moves_by_velocity_per_tick()
	test_bullet_field_bullet_leaving_play_area_is_removed()
	test_bullet_field_bullet_past_lifetime_is_removed()
	test_bullet_field_bullet_reaching_hittable_target_registers_hit()
	test_bullet_field_non_hittable_target_registers_no_hit()
	test_bullet_field_fast_bullet_crossing_target_is_caught_by_swept_test()
	test_bullet_field_cancel_circle_removes_bullets_in_radius()
	test_bullet_field_cancel_beats_hit_on_the_same_tick()
	test_bullet_field_clear_all_empties_the_pool()
	test_bullet_field_same_seed_produces_same_state_hash()
	test_bullet_field_warp_flies_then_freezes_then_reaims()
	test_bullet_field_warp_reaim_matches_the_gdd_example_vector()
	test_bullet_field_warp_prefers_its_own_target_slot()
	test_bullet_field_warp_falls_back_to_the_nearest_alive_player()
	test_bullet_field_warp_with_nobody_alive_keeps_its_stored_heading()
	test_bullet_field_warp_on_top_of_its_target_keeps_its_heading()

	print("BulletField tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _rules(capacity: int = 16) -> BulletRules:
	var r := BulletRules.new()
	r.enemy_cap = capacity
	r.player_cap = capacity
	r.hit_radius = 3.0
	r.cell_size = 32
	r.offscreen_margin = 20.0
	r.lifetime_ticks = 600
	r.accel_rate_per_second = 1.6
	r.max_accel_speed = 330.0
	r.curve_rate_per_second = 1.8
	return r


## One target slot at `at`, radius 3, stationary and hittable unless stated.
func _set_one_target(field: BulletField, at: Vector2, hittable: bool = true) -> void:
	field.set_targets(
		PackedFloat32Array([at.x]),
		PackedFloat32Array([at.y]),
		PackedFloat32Array([at.x]),
		PackedFloat32Array([at.y]),
		PackedFloat32Array([3.0]),
		PackedInt32Array([1 if hittable else 0]),
	)


## Four target slots, each with its own Alive flag. Warp re-aims at an Alive
## player, which is wider than hittable (bullet-manager Rule 17).
func _set_four_targets(
	field: BulletField, spots: Array, alive: PackedInt32Array, hittable: PackedInt32Array
) -> void:
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var radii := PackedFloat32Array()
	for i: int in range(4):
		var p: Vector2 = spots[i]
		xs.push_back(p.x)
		ys.push_back(p.y)
		radii.push_back(3.0)
	field.set_targets(xs, ys, xs, ys, radii, hittable, alive)


## Speed in px per SECOND of bullet 0 (the field stores px per tick).
func _speed_of(field: BulletField, i: int) -> float:
	return SimMath.length(field.vx_array()[i], field.vy_array()[i]) * 60.0


## Velocity in px per second of bullet `i`.
func _velocity_of(field: BulletField, i: int) -> Vector2:
	return Vector2(field.vx_array()[i], field.vy_array()[i]) * 60.0


func _assert_eq(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		print("  FAIL %s: expected %s, got %s" % [what, expected, actual])
		_failures += 1


func _assert_approx(actual: float, expected: float, what: String) -> void:
	if absf(actual - expected) > 0.01:
		print("  FAIL %s: expected ~%f, got %f" % [what, expected, actual])
		_failures += 1


## Like [method _assert_approx] with an explicit tolerance, for the values the
## bullet-manager ACs quote to a stated precision.
func _assert_within(actual: float, expected: float, tol: float, what: String) -> void:
	if absf(actual - expected) > tol:
		print("  FAIL %s: expected %f +/- %f, got %f" % [what, expected, tol, actual])
		_failures += 1


func _assert(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL %s" % what)
		_failures += 1


# --- tests -------------------------------------------------------------------

func test_bullet_field_spawn_increments_count() -> void:
	# Arrange
	var field := BulletField.new(_rules(), PLAY_AREA)

	# Act
	var accepted := field.request_spawn(100.0, 100.0, 0.0, 60.0)

	# Assert
	_assert_eq(accepted, true, "spawn accepted")
	_assert_eq(field.count(), 1, "count after one spawn")


func test_bullet_field_spawn_beyond_capacity_is_rejected() -> void:
	# Arrange
	var field := BulletField.new(_rules(2), PLAY_AREA, 2)
	field.request_spawn(10.0, 10.0, 0.0, 60.0)
	field.request_spawn(20.0, 10.0, 0.0, 60.0)

	# Act
	var accepted := field.request_spawn(30.0, 10.0, 0.0, 60.0)

	# Assert
	_assert_eq(accepted, false, "third spawn into a pool of 2")
	_assert_eq(field.count(), 2, "count stays at capacity")
	_assert_eq(field.spawn_rejected, 1, "rejected counter")


func test_bullet_field_linear_bullet_moves_by_velocity_per_tick() -> void:
	# Arrange: 600 px/s is exactly 10 px per 60 Hz tick.
	var field := BulletField.new(_rules(), PLAY_AREA)
	field.request_spawn(100.0, 100.0, 0.0, 600.0)

	# Act
	field.tick()

	# Assert
	_assert_approx(field.y_array()[0], 110.0, "y after one tick")
	_assert_approx(field.x_array()[0], 100.0, "x unchanged")
	_assert_eq(field.count(), 1, "bullet still live")


func test_bullet_field_bullet_leaving_play_area_is_removed() -> void:
	# Arrange: just inside the bottom edge, moving down fast enough to clear
	# the play area and the offscreen margin in one tick.
	var field := BulletField.new(_rules(), PLAY_AREA)
	field.request_spawn(100.0, 630.0, 0.0, 3000.0)

	# Act
	field.tick()

	# Assert
	_assert_eq(field.count(), 0, "bullet culled past the bottom margin")


func test_bullet_field_bullet_past_lifetime_is_removed() -> void:
	# Arrange: a bullet that never leaves the field, with a 3 tick lifetime.
	var rules := _rules()
	rules.lifetime_ticks = 3
	var field := BulletField.new(rules, PLAY_AREA)
	field.request_spawn(180.0, 320.0, 0.0, 0.0)

	# Act
	field.tick()
	field.tick()
	field.tick()
	var alive_at_limit := field.count()
	field.tick()

	# Assert
	_assert_eq(alive_at_limit, 1, "alive while age <= lifetime_ticks")
	_assert_eq(field.count(), 0, "culled once age exceeds lifetime_ticks")


func test_bullet_field_bullet_reaching_hittable_target_registers_hit() -> void:
	# Arrange: bullet 10 px above the target, closing at 10 px per tick.
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_one_target(field, Vector2(180.0, 320.0))
	field.request_spawn(180.0, 310.0, 0.0, 600.0)

	# Act
	field.tick()

	# Assert
	_assert_eq(field.player_hits.size(), 1, "one hit registered")
	_assert_eq(field.player_hits[0], 0, "hit is credited to slot 0")
	_assert_eq(field.count(), 0, "bullet consumed by the hit")


func test_bullet_field_non_hittable_target_registers_no_hit() -> void:
	# Arrange: same geometry, but the slot is invulnerable this tick.
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_one_target(field, Vector2(180.0, 320.0), false)
	field.request_spawn(180.0, 310.0, 0.0, 600.0)

	# Act
	field.tick()

	# Assert
	_assert_eq(field.player_hits.size(), 0, "no hit on a non-hittable slot")
	_assert_eq(field.count(), 1, "bullet passes through and stays live")


func test_bullet_field_fast_bullet_crossing_target_is_caught_by_swept_test() -> void:
	# Regression test for tunnelling, and for the optimisation that derives the
	# previous position as (x - vx) instead of storing it. A bullet 30 px above
	# the target moving 60 px in one tick ends 30 px PAST it, so a position-only
	# test would miss entirely: at the end of the tick it is 30 px away, far
	# outside the 6 px reach.
	# Arrange
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_one_target(field, Vector2(180.0, 320.0))
	field.request_spawn(180.0, 290.0, 0.0, 3600.0)

	# Act
	field.tick()

	# Assert
	_assert_eq(field.player_hits.size(), 1, "swept test catches the crossing")
	_assert_eq(field.count(), 0, "bullet consumed")


func test_bullet_field_cancel_circle_removes_bullets_in_radius() -> void:
	# Arrange
	var field := BulletField.new(_rules(), PLAY_AREA)
	field.request_spawn(100.0, 100.0, 0.0, 0.0)   # inside the cancel circle
	field.request_spawn(300.0, 500.0, 0.0, 0.0)   # well outside it

	# Act
	field.request_cancel_circle(100.0, 100.0, 20.0)
	field.tick()

	# Assert
	_assert_eq(field.count(), 1, "only the bullet outside survives")
	_assert_eq(field.cancelled_this_tick, 1, "one cancellation reported")
	_assert_approx(field.x_array()[0], 300.0, "survivor is the far bullet")


func test_bullet_field_cancel_beats_hit_on_the_same_tick() -> void:
	# Bullet manager GDD tick order: cancel runs before hit, so a bullet
	# cancelled this tick must not also damage the player.
	# Arrange: the bullet would reach the target this tick, and the cancel
	# circle covers the target's position too.
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_one_target(field, Vector2(180.0, 320.0))
	field.request_spawn(180.0, 310.0, 0.0, 600.0)

	# Act
	field.request_cancel_circle(180.0, 320.0, 30.0)
	field.tick()

	# Assert
	_assert_eq(field.player_hits.size(), 0, "cancelled bullet deals no hit")
	_assert_eq(field.cancelled_this_tick, 1, "it was cancelled instead")
	_assert_eq(field.count(), 0, "and removed")


func test_bullet_field_clear_all_empties_the_pool() -> void:
	# Arrange
	var field := BulletField.new(_rules(), PLAY_AREA)
	for i: int in range(5):
		field.request_spawn(float(100 + i), 100.0, 0.0, 60.0)

	# Act: the clear is resolved in the cancel step, so it lands before the
	# hit pass of the same tick (the deathbomb) rather than outside the tick.
	field.request_clear_all()
	field.tick()

	# Assert
	_assert_eq(field.count(), 0, "pool emptied")
	_assert_eq(field.cancelled_this_tick, 5, "and all five counted as cancelled")
	_assert_eq(field.cancel_causes.size(), 0, "a clear with no items pays nothing")


func test_bullet_field_same_seed_produces_same_state_hash() -> void:
	# ADR-0003 determinism: the fixed-step sim must be reproducible.
	# Arrange / Act
	var first := _run_scripted_field()
	var second := _run_scripted_field()

	# Assert
	_assert_eq(first, second, "state_hash across two identical runs")


# --- Warp (bullet-manager F4, Rules 16-17; AC-12, AC-13, AC-34) --------------

func test_bullet_field_warp_flies_then_freezes_then_reaims() -> void:
	# Arrange: the GDD timeline, T1 42 and T2 66 from 0.7 s and 1.1 s.
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_four_targets(
		field,
		[Vector2(180.0, 500.0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
		PackedInt32Array([1, 0, 0, 0]),
		PackedInt32Array([0, 0, 0, 0])
	)
	field.request_spawn(180.0, 100.0, 0.0, 120.0, BulletField.Beh.WARP, 0, 0.0, 0)

	# Act / assert: it flies for 42 ticks.
	for t: int in range(42):
		field.tick()
	_assert_approx(field.y_array()[0], 100.0 + 42.0 * 2.0, "a Warp bullet flies to T1")
	_assert_approx(_speed_of(field, 0), 120.0, "at its spawn speed")

	# Frozen from 43 to 66: no movement at all.
	var frozen_y := field.y_array()[0]
	for t: int in range(42, 66):
		field.tick()
	_assert_approx(field.y_array()[0], frozen_y, "and does not move while frozen")
	_assert_approx(_speed_of(field, 0), 0.0, "with speed 0")

	# Tick 67: it re-aims and leaves at exactly warp_speed.
	field.tick()
	_assert_approx(_speed_of(field, 0), 190.0, "then leaves at warp_speed on tick 67")


func test_bullet_field_warp_reaim_matches_the_gdd_example_vector() -> void:
	var field := _frozen_warp_at(Vector2(100.0, 155.0), Vector2(180.0, 500.0))
	var v := _velocity_of(field, 0)
	_assert_within(v.x, 42.9, 0.05, "the GDD re-aim vector x")
	_assert_within(v.y, 185.1, 0.05, "the GDD re-aim vector y")
	_assert_within(v.length(), 190.0, 0.05, "and its length is exactly warp_speed")


func test_bullet_field_warp_prefers_its_own_target_slot() -> void:
	# Slot 2 is Alive and FAR; slot 0 is Alive and near. Rule 17: the bullet
	# aims at the slot the pattern gave it, however near the others are.
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_four_targets(
		field,
		[Vector2(100.0, 200.0), Vector2.ZERO, Vector2(300.0, 600.0), Vector2.ZERO],
		PackedInt32Array([1, 0, 1, 0]),
		PackedInt32Array([0, 0, 0, 0])
	)
	field.request_spawn(100.0, 155.0, 0.0, 0.0, BulletField.Beh.WARP, 0, 0.0, 2)
	for t: int in range(67):
		field.tick()
	var v := _velocity_of(field, 0)
	_assert(v.x > 0.0, "it turns towards slot 2, which is to its right")


func test_bullet_field_warp_falls_back_to_the_nearest_alive_player() -> void:
	# Slot 2 is its target but not Alive; slots 0 and 3 are. Slot 3 is nearer.
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_four_targets(
		field,
		[Vector2(20.0, 600.0), Vector2.ZERO, Vector2(300.0, 600.0), Vector2(110.0, 200.0)],
		PackedInt32Array([1, 0, 0, 1]),
		PackedInt32Array([0, 0, 0, 0])
	)
	field.request_spawn(100.0, 155.0, 0.0, 0.0, BulletField.Beh.WARP, 0, 0.0, 2)
	for t: int in range(67):
		field.tick()
	var to_slot_3 := (Vector2(110.0, 200.0) - Vector2(100.0, 155.0)).normalized() * 190.0
	var v := _velocity_of(field, 0)
	_assert_within(v.x, to_slot_3.x, 0.1, "it aims at the nearest Alive player (x)")
	_assert_within(v.y, to_slot_3.y, 0.1, "it aims at the nearest Alive player (y)")

	# Equal distance: the lower slot index wins.
	var tie := BulletField.new(_rules(), PLAY_AREA)
	_set_four_targets(
		tie,
		[Vector2(60.0, 155.0), Vector2.ZERO, Vector2(140.0, 155.0), Vector2.ZERO],
		PackedInt32Array([1, 0, 1, 0]),
		PackedInt32Array([0, 0, 0, 0])
	)
	tie.request_spawn(100.0, 155.0, 0.0, 0.0, BulletField.Beh.WARP, 0, 0.0, 1)
	for t: int in range(67):
		tie.tick()
	_assert(_velocity_of(tie, 0).x < 0.0, "on a tie it takes the lower slot index")


func test_bullet_field_warp_with_nobody_alive_keeps_its_stored_heading() -> void:
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_four_targets(
		field,
		[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
		PackedInt32Array([0, 0, 0, 0]),
		PackedInt32Array([0, 0, 0, 0])
	)
	# Spawned heading right and slightly down.
	field.request_spawn(100.0, 300.0, 120.0, 0.0, BulletField.Beh.WARP, 0, 0.0, 0)
	for t: int in range(67):
		field.tick()
	var v := _velocity_of(field, 0)
	_assert_within(v.x, 190.0, 0.05, "with nobody Alive it flies on its stored heading")
	_assert_within(v.y, 0.0, 0.05, "which is the heading it was spawned with")


func test_bullet_field_warp_on_top_of_its_target_keeps_its_heading() -> void:
	# Closer than 1 px: there is no direction to snap to (Edge Cases).
	var field := _frozen_warp_at(Vector2(180.0, 300.0), Vector2(180.4, 300.0))
	var v := _velocity_of(field, 0)
	_assert_within(v.x, 0.0, 0.05, "a bullet on top of its target does not snap (x)")
	_assert_within(v.y, 190.0, 0.05, "it keeps its stored heading, which is down (y)")


## A Warp bullet spawned with zero speed at `at`, ticked just past the re-aim
## tick, with one Alive target at `target`. Spawning it still lets it store a
## heading: with no velocity the stored heading is straight down.
func _frozen_warp_at(at: Vector2, target: Vector2) -> BulletField:
	var field := BulletField.new(_rules(), PLAY_AREA)
	_set_four_targets(
		field,
		[target, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
		PackedInt32Array([1, 0, 0, 0]),
		PackedInt32Array([0, 0, 0, 0])
	)
	field.request_spawn(at.x, at.y, 0.0, 0.0, BulletField.Beh.WARP, 0, 0.0, 0)
	for t: int in range(67):
		field.tick()
	return field


func _run_scripted_field() -> int:
	var field := BulletField.new(_rules(64), PLAY_AREA, 64)
	_set_one_target(field, Vector2(180.0, 560.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for _t: int in range(60):
		field.request_spawn(
			rng.randf_range(20.0, 340.0),
			rng.randf_range(20.0, 200.0),
			rng.randf_range(-60.0, 60.0),
			rng.randf_range(120.0, 240.0),
			rng.randi_range(0, 2),
			rng.randi_range(0, 3),
		)
		field.tick()
	return field.state_hash()
