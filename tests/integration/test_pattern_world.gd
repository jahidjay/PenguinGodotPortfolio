extends SceneTree
## The pattern library inside a real [SimWorld]: step 4 wired to the bullet
## field, the plane core and the event log
## (design/gdd/bullet-pattern-library.md Interactions, AC-42 through the whole
## tick order).
##
## This is the test that would catch the library being correct in isolation and
## wrong in the game: the slot snapshot, the fire hold, the flak clamp and the
## bullet pool all come from the real systems here, not from a harness.
##
## Run from the project folder:
##   godot --headless --script res://tests/integration/test_pattern_world.gd

var _failures := 0

const TICKS := 1800


func _init() -> void:
	test_pattern_world_fires_authored_patterns_at_four_coop_players()
	test_pattern_world_is_deterministic_across_two_identical_runs()
	test_pattern_world_fire_hold_silences_every_runner()
	test_pattern_world_survives_every_shipped_platform()

	print("PatternWorld tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func test_pattern_world_fires_authored_patterns_at_four_coop_players() -> void:
	var world := _build("res://data/run/platform_fortress_1941.tres", 4)
	var peak := 0
	for t: int in range(TICKS):
		world.tick(world.game_tick)
		peak = maxi(peak, world.enemy_bullets.count())

	_assert(world.patterns != null, "the world owns a pattern scene")
	_assert(
		world.patterns.total_volleys_fired > 100,
		"the fortress fired plenty of volleys (got %d)" % world.patterns.total_volleys_fired
	)
	_assert(peak > 50, "and put a real curtain on the field (peak %d bullets)" % peak)
	_assert_eq(
		world.enemy_bullets.spawn_rejected, 0,
		"the authored density never overflows the 2,000-bullet pool"
	)
	# Every bullet carries a target slot in range, which is what Warp needs.
	var slots := world.enemy_bullets.target_array()
	for i: int in range(world.enemy_bullets.count()):
		if slots[i] < 0 or slots[i] >= PlaneCore.MAX_SLOTS:
			_failures += 1
			print("FAIL: bullet %d stored target slot %d" % [i, slots[i]])
			break
	world.dispose()


func test_pattern_world_is_deterministic_across_two_identical_runs() -> void:
	_assert_eq(
		_run_hash("res://data/run/platform_fortress_1941.tres"),
		_run_hash("res://data/run/platform_fortress_1941.tres"),
		"two identical runs end on the same state hash"
	)


func test_pattern_world_fire_hold_silences_every_runner() -> void:
	var world := _build("res://data/run/platform_wave_1941.tres", 2)
	for t: int in range(600):
		world.tick(world.game_tick)
	var before := world.enemy_bullets.count()
	var volleys := world.patterns.total_volleys_fired
	_assert(volleys > 0, "the wave fired before the hold")

	# Collision (6) sets the hold on a death; the library must go quiet.
	world.death_fire_hold = true
	world.enemy_bullets.request_clear_all()
	for t: int in range(30):
		world.tick(world.game_tick)
	_assert_eq(
		world.enemy_bullets.count(), 0, "no bullet is spawned while death_fire_hold is on"
	)
	_assert_eq(
		world.patterns.total_volleys_fired, volleys, "and no volley is counted as fired"
	)

	world.death_fire_hold = false
	for t: int in range(150):
		world.tick(world.game_tick)
	_assert(
		world.patterns.total_volleys_fired > volleys, "firing resumes when the hold lifts"
	)
	_assert(before >= 0, "sanity")
	world.dispose()


func test_pattern_world_survives_every_shipped_platform() -> void:
	var dir := DirAccess.open("res://data/run")
	if dir == null:
		_failures += 1
		print("FAIL: data/run is missing")
		return
	var found := 0
	for f: String in dir.get_files():
		var name := f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		found += 1
		var world := _build("res://data/run/%s" % name, 3)
		for t: int in range(900):
			world.tick(world.game_tick)
		_assert(
			world.patterns.total_volleys_fired > 0, "%s fired something" % name
		)
		_assert_eq(world.enemy_bullets.spawn_rejected, 0, "%s stayed inside the pool" % name)
		world.dispose()
	_assert(found >= 2, "both shipped platforms were exercised (found %d)" % found)


# --- helpers -----------------------------------------------------------------

func _build(platform_path: String, players: int) -> SimWorld:
	var world := SimWorld.new(SimWorld.Config.from_data())
	for slot: int in range(players):
		world.add_player(slot)
	var def := load(platform_path) as PlatformDef
	world.emitters.append(PatternPlatform.new(world, def))
	return world


func _run_hash(platform_path: String) -> int:
	var world := _build(platform_path, 4)
	for t: int in range(TICKS):
		world.tick(world.game_tick)
	var h := world.state_hash()
	world.dispose()
	return h


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
