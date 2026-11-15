extends SceneTree
## Unit tests for StageOutro: the stage-end timeline (boss combo text, then the
## planes climb and shrink past the horizon, then the stage is over).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_stage_outro.gd

var _failures := 0


func _init() -> void:
	test_stage_outro_text_comes_first_then_the_climb()
	test_stage_outro_planes_accelerate_and_shrink_to_the_horizon()
	test_stage_outro_ends_after_the_planes_are_gone()
	print("StageOutro tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func test_stage_outro_text_comes_first_then_the_climb() -> void:
	var o := _outro()
	_assert(not o.shows_text(0.0), "no text on the frame the boss dies")
	_assert(o.shows_text(o.text_delay), "the combo call-out appears after text_delay")
	_assert_eq(o.plane_lift(o.climb_delay), 0.0, "the planes hold under the text")
	_assert_eq(o.plane_scale(o.climb_delay), 1.0, "at full size")


func test_stage_outro_planes_accelerate_and_shrink_to_the_horizon() -> void:
	var o := _outro()
	var a := o.plane_lift(o.climb_delay + 0.5)
	var b := o.plane_lift(o.climb_delay + 1.0) - a
	_assert(a > 0.0, "the planes climb")
	_assert(b > a, "faster and faster (%.1f then %.1f px)" % [a, b])
	_assert(
		absf(o.plane_scale(o.climb_delay + o.shrink_seconds) - o.horizon_scale) < 0.001,
		"and shrink to horizon_scale"
	)


func test_stage_outro_ends_after_the_planes_are_gone() -> void:
	var o := _outro()
	# A plane at the bottom of the 640 px field must be off the top by the end.
	_assert(o.plane_lift(o.end_at) > 700.0, "every plane is past the horizon before the end")
	_assert(not o.is_done(o.end_at - 0.01), "not over a frame early")
	_assert(o.is_done(o.end_at), "over at end_at")


func _outro() -> StageOutro:
	return load("res://data/stages/stage_outro.tres") as StageOutro


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
