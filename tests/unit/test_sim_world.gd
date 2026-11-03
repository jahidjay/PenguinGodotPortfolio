extends SceneTree
## Integration tests for SimWorld — the step order and cross-system wiring from
## ADR-0002. These are the ADR's V2/V3 ordering checks, run on the systems that
## exist (PlaneCore, BulletField, TickEventLog).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_sim_world.gd
## Exit code 0 = pass, 1 = fail.

const PLAY_AREA := Rect2(0, 0, 360, 640)

var _failures := 0


func _init() -> void:
	test_sim_world_ticks_advance_the_game_tick_counter()
	test_sim_world_add_player_joins_a_coop_slot()
	test_sim_world_four_players_all_reach_active()
	test_sim_world_bullet_reaching_a_player_costs_a_life()
	test_sim_world_invulnerable_player_is_not_hit()
	test_sim_world_dead_player_is_not_hit_again_during_death_hold()
	test_sim_world_event_log_rotates_each_tick()
	test_sim_world_consumer_after_producer_sees_event_same_tick()
	test_sim_world_game_over_when_all_slots_are_out()
	test_sim_world_same_inputs_produce_same_state_hash()
	test_sim_world_runs_a_thousand_ticks_without_drift()
	test_sim_world_enemy_hit_raises_chain_and_pays_score()
	test_sim_world_death_drops_that_slots_chain_only()

	print("SimWorld tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- helpers -----------------------------------------------------------------

func _config() -> SimWorld.Config:
	var c := SimWorld.Config.new()
	c.play_area = PLAY_AREA

	var b := BulletRules.new()
	b.enemy_cap = 256
	b.player_cap = 64
	b.hit_radius = 3.0
	b.cell_size = 32
	b.offscreen_margin = 20.0
	b.lifetime_ticks = 600
	b.accel_rate_per_second = 1.6
	b.max_accel_speed = 330.0
	b.curve_rate_per_second = 1.8
	c.bullet_rules = b

	var p := PlaneRules.new()
	p.move_speed = 210.0
	p.focus_speed = 105.0
	p.hud_strip_1p = 48.0
	p.hud_strip_coop = 72.0
	p.top_padding = 4.0
	p.edge_margin = 8.0
	p.bottom_margin = 12.0
	p.hitbox_radius = 3.0
	p.fly_in_ticks = 36
	p.death_hold_ticks = 36
	p.respawn_invuln_ticks = 120
	p.fly_in_from_below = 48.0
	p.start_from_bottom = 70.0
	p.starting_lives = 3
	c.plane_rules = p

	var ch := ChainRules.new()
	ch.chain_window = 60
	ch.team_window = 60
	ch.team_window_step = 8
	ch.chain_cap = 999
	ch.cb_mult = 3
	ch.cb_add = 50
	ch.part_kill_chain = 5
	ch.milestones = PackedInt32Array([50, 100, 200])
	c.chain_rules = ch

	var sc := ScoringRules.new()
	sc.hit_base = 10
	sc.team_pct = 120
	sc.team_pct_step = 10
	sc.kill_value_small = 200
	sc.kill_value_medium = 1000
	sc.kill_value_large = 5000
	sc.part_value = 5000
	sc.boss_value = 100000
	sc.gem_base = 100
	sc.medal_base = 1000
	sc.factor_cap_count = 500
	sc.factor_step = 50
	sc.cb_unit = 1000
	sc.ldb_per_life = 50000
	sc.clear_bonus = 100000
	sc.no_death_bonus = 200000
	sc.life_value = 50000
	sc.peak_value = 1300
	sc.hold_unit = 500
	sc.hold_ramp_s = 30
	sc.extend_unit = 3000000
	sc.display_cap = 999999999
	sc.slot_stage_bound = 31000000
	c.scoring_rules = sc
	return c


func _advance(world: SimWorld, ticks: int) -> void:
	for _i: int in range(ticks):
		world.input.begin_tick()
		world.tick(world.game_tick)


## Runs until the slot is ACTIVE and its respawn invulnerability has expired.
func _settle(world: SimWorld, slot: int) -> void:
	var guard := 0
	while not (world.planes.is_active(slot) and world.planes.invuln_of(slot) == 0):
		_advance(world, 1)
		guard += 1
		if guard > 600:
			print("  FAIL settle: slot %d never became vulnerable" % slot)
			_failures += 1
			return


func _assert_eq(actual: Variant, expected: Variant, what: String) -> void:
	if actual != expected:
		print("  FAIL %s: expected %s, got %s" % [what, expected, actual])
		_failures += 1


func _assert_true(value: bool, what: String) -> void:
	if not value:
		print("  FAIL %s: expected true" % what)
		_failures += 1


# --- tests -------------------------------------------------------------------

func test_sim_world_ticks_advance_the_game_tick_counter() -> void:
	# Arrange
	var world := SimWorld.new(_config())

	# Act
	_advance(world, 10)

	# Assert
	_assert_eq(world.game_tick, 10, "game_tick after 10 ticks")


func test_sim_world_add_player_joins_a_coop_slot() -> void:
	# Arrange
	var world := SimWorld.new(_config())

	# Act
	world.add_player(0)

	# Assert
	_assert_eq(world.player_count(), 1, "one player in the run")
	_assert_true(world.planes.is_in_run(0), "slot 0 is in the run")
	_assert_true(not world.planes.is_in_run(1), "slot 1 is not")


func test_sim_world_four_players_all_reach_active() -> void:
	# Arrange: local co-op needs no wiring beyond joining the slots.
	var world := SimWorld.new(_config())

	# Act
	for s: int in range(4):
		world.add_player(s)
	_advance(world, 40)

	# Assert
	_assert_eq(world.player_count(), 4, "four players in the run")
	_assert_eq(world.planes.active_count(), 4, "four active planes")


func test_sim_world_bullet_reaching_a_player_costs_a_life() -> void:
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)
	_settle(world, 0)
	var at := world.planes.position_of(0)

	# Act: a bullet placed just above the plane, closing at 10 px per tick
	world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
	_advance(world, 1)

	# Assert
	_assert_eq(world.planes.lives_of(0), 2, "one life spent")
	_assert_eq(world.planes.state_of(0), PlaneCore.State.DEAD, "plane is down")
	_assert_true(
		world.events.has_for_slot(TickEventLog.Kind.PLAYER_HIT, 0), "PLAYER_HIT logged"
	)
	_assert_true(
		world.events.has_for_slot(TickEventLog.Kind.PLAYER_DIED, 0), "PLAYER_DIED logged"
	)
	_assert_eq(world.enemy_bullets.count(), 0, "bullet consumed")


func test_sim_world_invulnerable_player_is_not_hit() -> void:
	# Arrange: freshly active, respawn invulnerability still running.
	var world := SimWorld.new(_config())
	world.add_player(0)
	_advance(world, 37)
	_assert_true(world.planes.is_active(0), "active after fly-in")
	_assert_true(world.planes.invuln_of(0) > 0, "still invulnerable")
	var at := world.planes.position_of(0)

	# Act
	world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
	_advance(world, 1)

	# Assert
	_assert_eq(world.planes.lives_of(0), 3, "no life spent")
	_assert_eq(world.planes.state_of(0), PlaneCore.State.ACTIVE, "still active")
	_assert_eq(world.enemy_bullets.count(), 1, "bullet passes through")


func test_sim_world_dead_player_is_not_hit_again_during_death_hold() -> void:
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)
	_settle(world, 0)
	var at := world.planes.position_of(0)
	world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
	_advance(world, 1)
	_assert_eq(world.planes.state_of(0), PlaneCore.State.DEAD, "down after the first hit")

	# Act: more bullets arrive while the plane is in its death hold
	for _i: int in range(5):
		world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
		_advance(world, 1)

	# Assert
	_assert_eq(world.planes.lives_of(0), 2, "only the one life was spent")


func test_sim_world_event_log_rotates_each_tick() -> void:
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)
	_settle(world, 0)
	var at := world.planes.position_of(0)

	# Act
	world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
	_advance(world, 1)
	var hit_this_tick := world.events.has_for_slot(TickEventLog.Kind.PLAYER_HIT, 0)
	_advance(world, 1)

	# Assert
	_assert_true(hit_this_tick, "hit visible on the tick it happened")
	_assert_true(
		not world.events.has_for_slot(TickEventLog.Kind.PLAYER_HIT, 0),
		"and gone from this tick's log"
	)
	_assert_true(
		world.events.previous_has_for_slot(TickEventLog.Kind.PLAYER_HIT, 0),
		"but readable as the previous tick's"
	)


func test_sim_world_consumer_after_producer_sees_event_same_tick() -> void:
	# ADR-0002 D5: the referee produces PLAYER_HIT at step 6 and PLAYER_DIED
	# follows from it in the same tick, so both land in one log.
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)
	_settle(world, 0)
	var at := world.planes.position_of(0)

	# Act
	world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
	_advance(world, 1)

	# Assert
	_assert_true(world.events.has(TickEventLog.Kind.PLAYER_HIT), "hit in this tick's log")
	_assert_true(world.events.has(TickEventLog.Kind.PLAYER_DIED), "death in the same log")


func test_sim_world_game_over_when_all_slots_are_out() -> void:
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)

	# Act: kill the plane until its lives run out
	var saw_game_over := false
	for _life: int in range(3):
		_settle(world, 0)
		var at := world.planes.position_of(0)
		world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
		_advance(world, 1)
		saw_game_over = saw_game_over or world.events.has(TickEventLog.Kind.GAME_OVER)
	# The last life ends with a death hold, so GAME_OVER lands a few ticks
	# later: watch every tick rather than only the last one.
	for _t: int in range(40):
		_advance(world, 1)
		saw_game_over = saw_game_over or world.events.has(TickEventLog.Kind.GAME_OVER)

	# Assert
	_assert_eq(world.planes.lives_of(0), 0, "no lives left")
	_assert_eq(world.planes.state_of(0), PlaneCore.State.GAME_OVER, "slot is game over")
	_assert_true(world.planes.all_out(), "all slots out")
	_assert_true(saw_game_over, "GAME_OVER logged on the tick it happened")
	# And the run stops advancing, so no wave arrives over a dead player.
	_assert_eq(world.run_state, SimWorld.RunState.GAME_OVER, "the run is over")
	var frozen := world.game_tick
	_advance(world, 20)
	_assert_eq(world.game_tick, frozen, "and the simulation is frozen")


func test_sim_world_same_inputs_produce_same_state_hash() -> void:
	# ADR-0003: the whole simulation must be reproducible, not just one system.
	# Arrange / Act
	var first := _run_scripted()
	var second := _run_scripted()

	# Assert
	_assert_eq(first, second, "SimWorld.state_hash across two identical runs")


func _run_scripted() -> int:
	var world := SimWorld.new(_config())
	world.add_player(0)
	world.add_player(1)
	for t: int in range(300):
		world.input.begin_tick()
		world.input.set_move(0, 1 if (t / 20) % 2 == 0 else -1, 0)
		world.input.set_move(1, 0, 1 if (t / 15) % 2 == 0 else -1)
		if t % 7 == 0:
			world.enemy_bullets.request_spawn(
				float(40 + (t * 13) % 280), 60.0, 0.0, 180.0
			)
		world.tick(world.game_tick)
	return world.state_hash()


func test_sim_world_enemy_hit_raises_chain_and_pays_score() -> void:
	# Steps 8a then 8b: scoring must read the count AFTER the chain counted
	# the hit, so the first hit pays hit_base + 1.
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)
	_settle(world, 0)

	# Act
	world.report_enemy_hit(0, false)

	# Assert
	_assert_eq(world.chain.count_of(0), 1, "chain counted the hit")
	_assert_eq(world.scoring.score_of(0), 11, "scored hit_base + count_after")


func test_sim_world_death_drops_that_slots_chain_only() -> void:
	# chain-tracker Rule 5: death resets the dying slot's chain to zero, and
	# leaves every other co-op slot's chain alone.
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)
	world.add_player(1)
	_settle(world, 0)
	_settle(world, 1)
	for _i: int in range(20):
		world.report_enemy_hit(0, false)
		world.report_enemy_hit(1, false)
	_assert_eq(world.chain.count_of(0), 20, "P1 built a chain")
	_assert_eq(world.chain.count_of(1), 20, "P2 built a chain")

	# Act: kill only slot 0
	var at := world.planes.position_of(0)
	world.enemy_bullets.request_spawn(at.x, at.y - 10.0, 0.0, 600.0)
	_advance(world, 1)

	# Assert
	_assert_eq(world.chain.count_of(0), 0, "dead slot's chain reset to zero")
	_assert_eq(world.chain.count_of(1), 20, "the other slot's chain untouched")


func test_sim_world_runs_a_thousand_ticks_without_drift() -> void:
	# A long run with constant bullet pressure, checking nothing leaks or
	# wedges: the pool must stay bounded and the tick counter exact.
	# Arrange
	var world := SimWorld.new(_config())
	world.add_player(0)
	world.add_player(1)

	# Act
	for t: int in range(1000):
		world.input.begin_tick()
		world.input.set_move(0, (t % 3) - 1, 0)
		# This test is about drift, not survival: the bullets below would
		# otherwise end the run before tick 1000.
		world.planes.request_invuln(0, 2)
		world.planes.request_invuln(1, 2)
		if t % 3 == 0:
			world.enemy_bullets.request_spawn(
				float(20 + (t * 29) % 320), 50.0, 0.0, 240.0
			)
		world.tick(world.game_tick)

	# Assert
	_assert_eq(world.game_tick, 1000, "exactly 1000 ticks ran")
	_assert_true(
		world.enemy_bullets.count() <= world.enemy_bullets.capacity,
		"bullet pool stayed within capacity"
	)
	_assert_eq(world.enemy_bullets.spawn_rejected, 0, "no spawn was rejected")
