extends SceneTree
## Unit tests for EnemyManager and EnemyPath (design/gdd/enemy-and-ai.md
## Rules 6, 9-13, F1).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_enemy_manager.gd

const PLAY_AREA := Rect2(0.0, 48.0, 360.0, 592.0)

var _failures := 0
## Every rig built here. A PatternScene and its emitters reference each other,
## so a dropped rig would be reported as a leak and hide a real one.
var _rigs: Array = []


func _init() -> void:
	test_enemy_path_straight_is_velocity_times_age()
	test_enemy_path_sine_swings_without_drifting()
	test_enemy_path_enter_hover_exit_settles_then_leaves()
	test_enemy_manager_spawn_places_the_enemy_at_its_origin()
	test_enemy_manager_mirror_flips_the_path_in_x()
	test_enemy_manager_offscreen_enemy_is_not_targetable_and_holds_its_fire()
	test_enemy_manager_damage_kills_at_zero_hp()
	test_enemy_manager_plated_enemy_takes_reduced_damage_and_cannot_die()
	test_enemy_manager_kill_pays_the_size_class_and_cancels_bullets()
	test_enemy_manager_retires_an_enemy_that_outlives_its_limit()
	test_enemy_manager_respawns_an_enemy_that_leaves_the_field()
	test_enemy_manager_thinned_squad_flies_faster_and_lone_survivor_faster_still()
	test_enemy_manager_squad_of_one_never_gets_aggressive()
	test_stage_director_holds_the_wave_until_every_enemy_is_shot_down()
	test_enemy_manager_refuses_a_spawn_past_the_alive_cap()
	test_enemy_manager_same_inputs_produce_the_same_state_hash()

	for rig: Array in _rigs:
		(rig[0] as EnemyManager).clear_all()
		(rig[1] as PatternScene).dispose()
	_rigs.clear()
	print("EnemyManager tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- paths (F1) --------------------------------------------------------------

func test_enemy_path_straight_is_velocity_times_age() -> void:
	# Arrange
	var path := EnemyPathDef.new()
	path.kind = EnemyPathDef.Kind.STRAIGHT
	path.velocity = Vector2(0.0, 120.0)
	# Act / Assert: 120 px/s is 2 px a tick, exactly.
	_assert_close(EnemyPath.offset(path, 0).y, 0.0, "age 0 is the origin")
	_assert_close(EnemyPath.offset(path, 30).y, 60.0, "half a second is 60 px")
	_assert_close(EnemyPath.offset(path, 600).y, 1200.0, "ten seconds is 1,200 px")


func test_enemy_path_sine_swings_without_drifting() -> void:
	var path := EnemyPathDef.new()
	path.kind = EnemyPathDef.Kind.SINE
	path.descent = 60.0
	path.amplitude = 50.0
	path.period = 120
	path.phase = 0.0

	_assert_close(EnemyPath.offset(path, 0).x, 0.0, "the swing starts centred")
	_assert_close(EnemyPath.offset(path, 30).x, 50.0, "a quarter period is the full swing")
	_assert_close(EnemyPath.offset(path, 90).x, -50.0, "three quarters is the other side")
	# The descent is independent of the swing and never accumulates error.
	_assert_close(EnemyPath.offset(path, 600).y, 600.0, "ten seconds of descent")
	# After exactly one period it is back where it started, however long it runs.
	_assert_close(
		EnemyPath.offset(path, 1200).x, EnemyPath.offset(path, 0).x,
		"ten periods later the swing is identical, with no drift"
	)


func test_enemy_path_enter_hover_exit_settles_then_leaves() -> void:
	var path := EnemyPathDef.new()
	path.kind = EnemyPathDef.Kind.ENTER_HOVER_EXIT
	path.hover_offset = Vector2(0.0, 200.0)
	path.enter_ticks = 60
	path.hover_ticks = 120
	path.drift_amplitude = 0.0
	path.exit_velocity = Vector2(0.0, 240.0)

	_assert_close(EnemyPath.offset(path, 0).y, 0.0, "it starts at the origin")
	_assert_close(EnemyPath.offset(path, 60).y, 200.0, "and reaches the hover point")
	_assert_close(EnemyPath.offset(path, 120).y, 200.0, "then holds it")
	_assert_close(EnemyPath.offset(path, 180).y, 200.0, "to the last hover tick")
	# Leaving: 240 px/s for one second past the hover.
	_assert_close(EnemyPath.offset(path, 240).y, 440.0, "then accelerates away")
	# The ease never overshoots.
	var worst := 0.0
	for t: int in range(0, 61):
		worst = maxf(worst, EnemyPath.offset(path, t).y)
	_assert_close(worst, 200.0, "the ease-in never overshoots the hover point")


# --- the manager -------------------------------------------------------------

func test_enemy_manager_spawn_places_the_enemy_at_its_origin() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	var id := manager.spawn(_scout(), Vector2(120.0, 60.0), false, 0.0)
	_assert(id != 0, "the spawn is accepted")
	_assert_eq(manager.count(), 1, "and the enemy is on the field")
	_assert_close(manager.position_of(0).x, 120.0, "at its origin x")
	manager.tick(1)
	_assert(manager.position_of(0).y > 60.0, "and it descends on the next tick")


func test_enemy_manager_mirror_flips_the_path_in_x() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	manager.spawn(_scout(), Vector2(180.0, 60.0), false, 0.0)
	manager.spawn(_scout(), Vector2(180.0, 60.0), true, 0.0)
	for t: int in range(1, 31):
		manager.tick(t)
	var plain := manager.position_of(0).x - 180.0
	var mirrored := manager.position_of(1).x - 180.0
	_assert(absf(plain) > 1.0, "the path really does move sideways")
	_assert_close(mirrored, -plain, "and the mirrored one is its reflection")


func test_enemy_manager_offscreen_enemy_is_not_targetable_and_holds_its_fire() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	var scene: PatternScene = rig[1]
	var def := _scout()
	def.patterns = [load("res://data/patterns/wave_1941_aimed_fan.tres") as PatternDef]
	manager.spawn(def, Vector2(180.0, -60.0), false, 0.0)

	manager.tick(1)
	# A real pool here, because `publish_targets` hands its arrays straight to
	# the field the player's shots live in.
	var shots := BulletField.new(_bullet_rules(), PLAY_AREA)
	manager.publish_targets(shots)
	shots.request_spawn(180.0, -60.0, 0.0, -600.0)
	shots.tick()
	_assert_eq(
		shots.hit_targets.size(), 0, "an enemy off the field cannot be hit (Rule 9)"
	)
	_assert_eq(
		scene.emitters.size(), 0,
		"Rule 18: a gun off the field is not even registered, so its timers have not started"
	)

	# Fly it in. The emitter arms on the tick the body enters the field.
	var armed_at := -1
	for t: int in range(2, 200):
		manager.tick(t)
		if scene.emitters.size() > 0 and armed_at < 0:
			armed_at = t
	_assert(armed_at > 1, "the gun arms once the enemy is on the field (tick %d)" % armed_at)
	_assert_eq(scene.emitters.size(), 1, "and only one emitter is ever registered")


func test_enemy_manager_damage_kills_at_zero_hp() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	manager.spawn(_scout(), Vector2(180.0, 100.0), false, 0.0)
	manager.tick(1)
	_assert(not manager.damage(0, 19), "19 of 20 hp does not kill")
	_assert_eq(manager.hp_of(0), 1, "and leaves 1 hp")
	_assert(manager.damage(0, 1), "the last point kills")


func test_enemy_manager_plated_enemy_takes_reduced_damage_and_cannot_die() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	var def := _scout()
	def.hp = 1000
	def.plating_ticks = 120
	def.plating_armor_pct = 50
	manager.spawn(def, Vector2(180.0, 100.0), false, 0.0)
	manager.tick(1)

	_assert(manager.is_armoured(0), "it is armoured from the tick it is seen")
	_assert(not manager.damage(0, 20000), "an armoured enemy cannot be killed")
	_assert_eq(manager.hp_of(0), 1, "however much damage arrives, it keeps 1 hp")

	# The plating falls after its ticks, and then it dies like anything else.
	for t: int in range(2, 140):
		manager.tick(t)
	_assert(not manager.is_armoured(0), "the plating falls after plating_ticks")
	_assert(manager.damage(0, 20), "and then the next hit can kill it")


func test_enemy_manager_kill_pays_the_size_class_and_cancels_bullets() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	var def := _scout()
	def.size_class = EnemyDef.SizeClass.MEDIUM
	def.cancel_radius = 40.0
	manager.spawn(def, Vector2(180.0, 100.0), false, 0.0)
	manager.tick(1)

	var bullets := BulletField.new(_bullet_rules(), PLAY_AREA)
	bullets.request_spawn(180.0, 110.0, 0.0, 60.0)
	bullets.request_spawn(10.0, 600.0, 0.0, 60.0)

	var kill_class := manager.kill(0, 2, bullets)
	_assert_eq(kill_class, ScoringLedger.KillClass.MEDIUM, "a MEDIUM enemy pays the medium class")
	_assert_eq(manager.count(), 0, "and leaves the field")
	bullets.tick()
	_assert_eq(bullets.count(), 1, "its death cancelled the bullet inside its radius")


func test_enemy_manager_retires_an_enemy_that_outlives_its_limit() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	manager.rules.respawn_on_escape = false
	var def := _scout()
	def.max_life_ticks = 30
	manager.spawn(def, Vector2(180.0, 100.0), false, 0.0)
	for t: int in range(1, 32):
		manager.tick(t)
	_assert_eq(manager.count(), 0, "it is gone after its life runs out")
	_assert_eq(manager.escaped_total, 1, "counted as escaped, not killed")
	_assert_eq(manager.killed_total, 0, "so it pays no score")


func test_enemy_manager_respawns_an_enemy_that_leaves_the_field() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	var def := _scout()
	var origin := Vector2(180.0, 20.0)
	manager.spawn(def, origin, false, 0.0)
	manager.damage(0, 5)
	# 90 px/s from y=20 clears the bottom (640 + margin) in under 8 s.
	var came_back := false
	for t: int in range(1, 600):
		manager.tick(t)
		if manager.escaped_total == 1 and not came_back:
			came_back = true
			_assert_eq(manager.position_of(0), origin, "it is back at its spawn point")
	_assert(came_back, "it flew off the bottom")
	_assert_eq(manager.count(), 1, "and is still on the field, not retired")
	_assert_eq(manager.hp_of(0), 15, "with the damage it already took")


func test_enemy_manager_thinned_squad_flies_faster_and_lone_survivor_faster_still() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	var def := _scout()
	for m: int in range(4):
		manager.spawn(def, Vector2(40.0 + 80.0 * m, 100.0), false, 0.0, 7, m, false, -1, 4)
	_assert_eq(manager.aggro_of(0), EnemyManager.Aggro.NORMAL, "a full squad is calm")
	manager.kill(3, 0, null)
	manager.kill(2, 0, null)
	_assert_eq(manager.aggro_of(0), EnemyManager.Aggro.HALF_SQUAD, "half the squad down")
	var y0 := manager.position_of(0).y
	manager.tick(1)
	_assert_close(manager.position_of(0).y - y0, 1.5 * 1.25, "it descends 1.25x as fast")
	manager.kill(1, 0, null)
	_assert_eq(manager.aggro_of(0), EnemyManager.Aggro.ALONE, "the last one is alone")
	y0 = manager.position_of(0).y
	manager.tick(2)
	_assert_close(manager.position_of(0).y - y0, 1.5 * 1.5, "and descends 1.5x as fast")


func test_enemy_manager_squad_of_one_never_gets_aggressive() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	manager.spawn(_scout(), Vector2(180.0, 100.0), false, 0.0, 3, 0, false, -1, 1)
	_assert_eq(manager.aggro_of(0), EnemyManager.Aggro.NORMAL, "a lone heavy is not 'alone'")


func test_stage_director_holds_the_wave_until_every_enemy_is_shot_down() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	var log: TickEventLog = rig[3]
	var stage := StageDef.new()
	for w: int in range(2):
		var event := SpawnEventDef.new()
		event.enemy = _scout()
		event.at_tick = 0
		event.count = 2
		event.stagger = 0
		event.origin = Vector2(180.0, 100.0)
		var wave := WaveDef.new()
		wave.min_ticks = 10
		wave.events = [event]
		stage.waves.push_back(wave)
	var director := StageDirector.new(stage, manager, log)
	for t: int in range(1, 3000):
		director.tick(t)
		manager.tick(t)
	_assert_eq(director.wave_index, 0, "50 s with survivors flying around: still wave 1")
	_assert_eq(manager.count(), 2, "both survivors keep coming back")
	manager.kill(1, 0, null)
	manager.kill(0, 0, null)
	director.tick(3000)
	_assert_eq(director.wave_index, 1, "shooting the last one down starts wave 2")


func test_enemy_manager_refuses_a_spawn_past_the_alive_cap() -> void:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	for i: int in range(EnemyManager.MAX_ALIVE):
		_assert(manager.spawn(_scout(), Vector2(180.0, 100.0), false, 0.0) != 0, "spawn %d" % i)
	_assert_eq(
		manager.spawn(_scout(), Vector2(180.0, 100.0), false, 0.0), 0,
		"the one past the cap is refused"
	)
	_assert_eq(manager.spawns_refused, 1, "and counted")


func test_enemy_manager_same_inputs_produce_the_same_state_hash() -> void:
	_assert_eq(_scripted(), _scripted(), "two identical 600-tick runs give one hash")


# --- helpers -----------------------------------------------------------------

func _bullet_rules() -> BulletRules:
	return load("res://data/bullet_rules.tres") as BulletRules


## [manager, pattern scene, fake field, event log]
func _rig() -> Array:
	var log := TickEventLog.new(512)
	var field := FakeBulletField.new()
	var scene := PatternScene.new(load("res://data/pattern_rules.tres"), field, log)
	var manager := EnemyManager.new(scene, log, PLAY_AREA)
	var rig := [manager, scene, field, log]
	_rigs.push_back(rig)
	return rig


## A fresh SMALL enemy on a sine path, built in code so a designer retuning
## data/enemies cannot break these tests.
func _scout() -> EnemyDef:
	var def := EnemyDef.new()
	def.id = &"test_scout"
	def.size_class = EnemyDef.SizeClass.SMALL
	def.body_radius = 8.0
	def.hurt_pad = 2.0
	def.hp = 20
	def.max_life_ticks = 1800
	var path := EnemyPathDef.new()
	path.kind = EnemyPathDef.Kind.SINE
	path.descent = 90.0
	path.amplitude = 50.0
	path.period = 120
	def.path = path
	return def


func _scripted() -> int:
	var rig := _rig()
	var manager: EnemyManager = rig[0]
	for t: int in range(600):
		if t % 60 == 0:
			manager.spawn(_scout(), Vector2(60.0 + float(t % 240), -20.0), t % 120 == 0, 0.0)
		manager.tick(t)
		if t % 90 == 0 and manager.count() > 0:
			manager.damage(0, 10)
	return manager.state_hash()


# --- assertions --------------------------------------------------------------

func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])


func _assert_close(got: float, want: float, what: String, tol := 0.05) -> void:
	if absf(got - want) > tol:
		_failures += 1
		print("FAIL: %s -- got %.4f, want %.4f (+/- %.3f)" % [what, got, want, tol])
