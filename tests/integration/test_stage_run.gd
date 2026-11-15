extends SceneTree
## The whole run loop through a real [SimWorld]: the stage sends waves, the
## players shoot, enemies die, the chain climbs, and the boss arrives
## (design/gdd/wave-and-stage-director.md, enemy-and-ai.md,
## collision-damage-lives.md Phase A).
##
## This is the test that fails if the game stops being a game — if nothing can
## be shot, if a wave clears with enemies left, or if the boss never comes.
##
## Run from the project folder:
##   godot --headless --script res://tests/integration/test_stage_run.gd

var _failures := 0


func _init() -> void:
	test_stage_run_waves_wait_for_kills_then_progress_to_the_boss()
	test_stage_run_player_shots_kill_enemies_and_climb_the_chain()
	test_stage_run_armoured_hits_count_for_the_chain_without_killing()
	test_stage_run_is_deterministic_across_two_identical_runs()
	test_stage_run_enemy_bullets_can_still_kill_the_player()

	print("StageRun tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func test_stage_run_waves_wait_for_kills_then_progress_to_the_boss() -> void:
	# Arrange: one player who never fires.
	var world := _world(1, false)

	# Act 1: nobody shoots, so wave 1 must never end — its enemies keep
	# coming back around. The probe is kept alive on purpose: this test is
	# about the director, and a dead player stops the run.
	for t: int in range(3600):
		world.planes.request_invuln(0, 2)
		world.tick(world.game_tick)
	_assert_eq(world.director.wave_index, 0, "a minute without a kill: still wave 1")
	_assert(world.enemies.count() > 0, "with its enemies still flying")

	# Act 2: now every enemy is shot down the moment it can be hit.
	var waves_seen := {}
	var boss_tick := -1
	for t: int in range(12000):
		world.planes.request_invuln(0, 2)
		if boss_tick < 0:
			for i: int in range(world.enemies.count() - 1, -1, -1):
				if world.enemies.is_hittable(i):
					world.enemies.kill(i, 0, world.enemy_bullets)
		world.tick(world.game_tick)
		waves_seen[world.director.wave_index] = true
		if world.director.is_boss_alive() and boss_tick < 0:
			boss_tick = t

	# Assert
	_assert_eq(
		waves_seen.size(), world.director.stage.waves.size(),
		"every wave of the stage ran"
	)
	_assert(boss_tick > 0, "and the boss arrived (tick %d)" % boss_tick)
	_assert(world.enemies.spawned_total > 20, "the waves sent real enemies")
	_assert_eq(world.enemy_bullets.spawn_rejected, 0, "without overflowing the bullet pool")
	world.dispose()


func test_stage_run_player_shots_kill_enemies_and_climb_the_chain() -> void:
	var world := _world(2, true)
	var chain_peak := 0

	for t: int in range(5400):
		_chase_nearest(world)
		world.tick(world.game_tick)
		for slot: int in range(2):
			chain_peak = maxi(chain_peak, world.chain.count_of(slot))

	_assert(
		world.kits.shots_fired > 500,
		"the players fired (%d shots)" % world.kits.shots_fired
	)
	_assert(world.enemies.killed_total > 5, "and killed enemies (%d)" % world.enemies.killed_total)
	_assert(chain_peak > 1, "the chain climbed off zero (peak %d)" % chain_peak)
	var total := world.scoring.score_of(0) + world.scoring.score_of(1)
	_assert(total > 0, "and the score moved (%d)" % total)
	world.dispose()


func test_stage_run_armoured_hits_count_for_the_chain_without_killing() -> void:
	# A plated LARGE enemy: C5 says an armoured hit still counts for the chain,
	# which is what makes shooting a bomber's plating worth doing.
	var world := _world(1, true)
	var def := load("res://data/enemies/1941/heavy_bomber.tres") as EnemyDef
	world.enemies.clear_all()
	world.enemies.spawn(def, Vector2(180.0, 60.0), false, 0.0)

	var hp_before := -1
	for t: int in range(60):
		# Sit the plane under the bomber so the shots land.
		world.input.set_move(0, 0, 0)
		world.input.set_button(0, SimInput.Action.FIRE, true)
		world.tick(world.game_tick)
		if world.enemies.count() > 0 and hp_before < 0 and world.enemies.is_armoured(0):
			hp_before = world.enemies.hp_of(0)

	_assert(world.enemies.count() > 0, "the plated bomber survived the volley")
	_assert(world.enemies.is_armoured(0), "and is still armoured")
	_assert(
		world.chain.count_of(0) > 0,
		"while the hits on its plating counted for the chain (count %d)" % world.chain.count_of(0)
	)
	world.dispose()


func test_stage_run_is_deterministic_across_two_identical_runs() -> void:
	_assert_eq(_scripted_hash(), _scripted_hash(), "two identical runs end on one state hash")


func test_stage_run_enemy_bullets_can_still_kill_the_player() -> void:
	# The player sits still and never dodges: the enemies must eventually get
	# through, or nothing on the field is dangerous.
	var world := _world(1, false)
	for t: int in range(9000):
		world.tick(world.game_tick)
		if world.planes.lives_of(0) < 3:
			break
	_assert(world.planes.lives_of(0) < 3, "a player who never moves loses a life")
	world.dispose()


# --- helpers -----------------------------------------------------------------

func _world(players: int, firing: bool) -> SimWorld:
	var world := SimWorld.new(SimWorld.Config.from_data())
	for slot: int in range(players):
		world.add_player(slot)
		if firing:
			world.input.set_button(slot, SimInput.Action.FIRE, true)
	return world


## Walks every Active plane towards the nearest enemy, so the probe actually
## shoots something instead of firing into empty sky.
func _chase_nearest(world: SimWorld) -> void:
	for slot: int in range(PlaneCore.MAX_SLOTS):
		if not world.planes.is_active(slot):
			continue
		var me := world.planes.position_of(slot)
		var best := Vector2.INF
		var best_d := INF
		for i: int in range(world.enemies.count()):
			var p := world.enemies.position_of(i)
			var d := me.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = p
		if best == Vector2.INF:
			world.input.set_move(slot, 0, 0)
			continue
		world.input.set_move(
			slot, signi(roundi(best.x - me.x)), 0
		)


func _scripted_hash() -> int:
	var world := _world(2, true)
	for t: int in range(2400):
		# A fixed, reproducible input pattern rather than a chase, so the only
		# thing under test is the simulation.
		for slot: int in range(2):
			world.input.set_move(slot, 1 if (t / 40) % 2 == 0 else -1, 0)
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
