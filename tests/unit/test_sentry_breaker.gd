extends SceneTree
## The two planes from design/gdd/plane-kits-sentry-breaker.md: the Sentry's
## Entrench and world-anchored turrets, and the Breaker's Breach, return
## bolts and Erase Net.
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_sentry_breaker.gd

const PLAY_AREA := Rect2(0, 0, 360, 640)

var _failures := 0
var _rigs: Array[Array] = []


func _init() -> void:
	test_sentry_normal_shot_is_a_parallel_pair()
	test_sentry_entrench_replaces_the_guns_and_slows_the_plane()
	test_sentry_emplaced_turrets_stay_where_they_were_planted()
	test_sentry_a_second_press_recalls_the_turrets_early()
	test_breaker_ram_shot_is_one_heavy_bullet()
	test_breaker_breach_fires_no_bolts_without_stock()
	test_breaker_bolts_spend_stock_and_seek()
	test_breaker_net_erases_enemy_bullets_and_fills_the_stock()
	test_breaker_net_never_covers_the_plane()
	test_breaker_death_takes_the_whole_stock()

	for rig: Array in _rigs:
		(rig[3] as PatternScene).dispose()
	print("SentryBreaker tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- Sentry (GDD 29 Rules 10-17) ---------------------------------------------

func test_sentry_normal_shot_is_a_parallel_pair() -> void:
	# Arrange
	var rig := _rig(KitRules.Kind.SENTRY)
	var kits: PlaneKits = rig[0]
	kits.set_drone_count(0, 0)

	# Act: Rule 10 is two bullets, 16 px apart, both straight up.
	_run(rig, 1, true)
	var field := kits.field
	var xs := field.x_array()
	var vxs := field.vx_array()

	# Assert
	_assert_eq(field.count(), 2, "the twin guns fire a pair")
	_assert(
		absf(absf(xs[0] - xs[1]) - kits.rules.sentry_muzzle_dx * 2.0) < 0.01,
		"16 px apart (got %.1f)" % absf(xs[0] - xs[1])
	)
	_assert(
		absf(vxs[0]) < 0.001 and absf(vxs[1]) < 0.001,
		"and parallel, not fanned"
	)


func test_sentry_entrench_replaces_the_guns_and_slows_the_plane() -> void:
	# Arrange
	var rig := _rig(KitRules.Kind.SENTRY)
	var kits: PlaneKits = rig[0]
	kits.set_drone_count(0, 0)

	# Act: Rule 11, the charge arrives at hold tick 18 with no resource gate.
	_run(rig, 30, true)

	# Assert
	_assert_eq(kits.fire_state(0), PlaneKits.Fire.CHARGE, "the Sentry always has its charge")
	_assert(
		absf(kits.ability_speed(0) - kits.rules.entrench_speed) < 0.01,
		"and the plane is slowed to the Entrench speed"
	)
	# One shell per volley instead of a pair.
	var before := kits.field.count()
	_run(rig, kits.rules.entrench_interval, true)
	_assert_eq(
		kits.field.count() - before, 1, "Entrench fires one nose shell per volley"
	)


func test_sentry_emplaced_turrets_stay_where_they_were_planted() -> void:
	# Arrange
	var rig := _rig(KitRules.Kind.SENTRY)
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	kits.set_drone_count(0, 2)

	# Act: Rule 13 posts are WORLD-anchored, so flying away leaves them behind.
	_run(rig, 1, true, true)
	_run(rig, 40, true)
	var post := kits.drone_position(0, 0)
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.EMPLACED, "the drone reached its post")
	for t: int in range(60):
		_tick(rig, true, false, -1)

	# Assert
	_assert(
		kits.drone_position(0, 0).distance_to(post) < 0.01,
		"the turret did not follow the plane"
	)
	_assert(
		planes.position_of(0).distance_to(post) > 20.0,
		"even though the plane moved away"
	)


func test_sentry_a_second_press_recalls_the_turrets_early() -> void:
	# Arrange
	var rig := _rig(KitRules.Kind.SENTRY)
	var kits: PlaneKits = rig[0]
	kits.set_drone_count(0, 2)
	_run(rig, 1, true, true)
	_run(rig, 20, true)

	# Act: Rule 14 refuses a recall before `recall_min_ticks`.
	_tick(rig, true, true)
	_assert_eq(
		kits.ability_state(0), PlaneKits.Ability.ACTIVE,
		"a press before tick 60 is refused"
	)
	_run(rig, kits.rules.recall_min_ticks, true)
	_tick(rig, true, true)

	# Assert
	_assert_eq(
		kits.ability_state(0), PlaneKits.Ability.COOLDOWN,
		"and accepted after it, which shortens the cycle"
	)


# --- Breaker (GDD 29 Rules 18-29) --------------------------------------------

func test_breaker_ram_shot_is_one_heavy_bullet() -> void:
	# Arrange
	var rig := _rig(KitRules.Kind.BREAKER)
	var kits: PlaneKits = rig[0]
	kits.set_drone_count(0, 0)

	# Act: Rule 18, one bullet every 3 ticks.
	_run(rig, 1, true)

	# Assert
	_assert_eq(kits.field.count(), 1, "the ram is a single bullet")
	var before := kits.shots_fired
	_run(rig, 12, true)
	_assert_eq(
		kits.shots_fired - before, 12 / kits.rules.breaker_shot_interval,
		"fired every 3 ticks"
	)


func test_breaker_breach_fires_no_bolts_without_stock() -> void:
	# Arrange: Rule 20, a bolt costs 2 stock and the stock starts at 0.
	var rig := _rig(KitRules.Kind.BREAKER)
	var kits: PlaneKits = rig[0]
	kits.set_drone_count(0, 0)
	var enemies: EnemyManager = rig[2]
	enemies.spawn(_target_def(), Vector2(180.0, 120.0), false, 0.0)

	# Act
	_run(rig, 60, true)

	# Assert
	_assert_eq(kits.fire_state(0), PlaneKits.Fire.CHARGE, "Breach is running")
	_assert_eq(kits.stock_of(0), 0, "with no stock")
	# Every bullet is a straight-up slug: no bolt was ever requested.
	var vxs := kits.field.vx_array()
	var sideways := 0
	for i: int in range(kits.field.count()):
		if absf(vxs[i]) > 0.001:
			sideways += 1
	_assert_eq(sideways, 0, "so nothing seeks: a bolt needs stock")


func test_breaker_bolts_spend_stock_and_seek() -> void:
	# Arrange
	var rig := _rig(KitRules.Kind.BREAKER)
	var kits: PlaneKits = rig[0]
	var enemies: EnemyManager = rig[2]
	kits.set_drone_count(0, 0)
	enemies.spawn(_target_def(), Vector2(120.0, 320.0), false, 0.0)
	kits.set_stock_for_test(0, 20)

	# Act
	_run(rig, 30, true)

	# Assert
	_assert(kits.stock_of(0) < 20, "a bolt spends stock (left %d)" % kits.stock_of(0))
	var vxs := kits.field.vx_array()
	var sideways := 0
	for i: int in range(kits.field.count()):
		if absf(vxs[i]) > 0.001:
			sideways += 1
	_assert(sideways > 0, "and leaves the muzzle aimed at the target")


func test_breaker_net_erases_enemy_bullets_and_fills_the_stock() -> void:
	# Arrange
	var rig := _rig(KitRules.Kind.BREAKER)
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	var enemy_pool: BulletField = rig[4]
	kits.set_drone_count(0, 2)
	_run(rig, 1, true, true)
	_run(rig, 20, true)
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.NET_ON, "the net is up")

	# Act: park bullets inside a zone and let the pulses eat them.
	var zone := kits.drone_position(0, 0)
	for i: int in range(12):
		enemy_pool.request_spawn(zone.x, zone.y, 0.0, 0.0)
	var before := enemy_pool.count()
	_run(rig, 6, true)

	# Assert
	_assert(enemy_pool.count() < before, "the net erased bullets (%d left)" % enemy_pool.count())
	_assert(kits.stock_of(0) > 0, "and the erase filled the stock (%d)" % kits.stock_of(0))
	_assert(
		kits.stock_of(0) <= kits.rules.credit_per_pulse_cap * 4,
		"capped per pulse, so a curtain is not a jackpot"
	)


func test_breaker_net_never_covers_the_plane() -> void:
	# Rule 24 / SB5: the net keeps `net_safe_clear` away from the plane, so a
	# Breaker can never hide its own hitbox behind it.
	# Arrange
	var rig := _rig(KitRules.Kind.BREAKER)
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	kits.set_drone_count(0, 4)
	_run(rig, 1, true, true)
	_run(rig, 20, true)

	# Act / Assert
	var at := planes.position_of(0)
	var zones := kits.net_zones(0)
	var z := 0
	while z + 1 < zones.size():
		var c := Vector2(zones[z], zones[z + 1])
		_assert(
			c.distance_to(at) - kits.net_radius() >= kits.rules.net_safe_clear - 0.01,
			"zone %d clears the plane by %.1f px" % [z / 2, c.distance_to(at) - kits.net_radius()]
		)
		z += 2
	_assert(zones.size() > 0, "and the net is actually up")


func test_breaker_death_takes_the_whole_stock() -> void:
	# Arrange: Rule 21, the stock is a run-only value and death costs all of it.
	var rig := _rig(KitRules.Kind.BREAKER)
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	kits.set_stock_for_test(0, 40)

	# Act
	planes.kill(0)
	_run(rig, 3, false)

	# Assert
	_assert_eq(kits.stock_of(0), 0, "the stock is gone")
	_assert_eq(kits.drone_count(0), 0, "and so are the drones (Rule 6)")


# --- helpers ------------------------------------------------------------------

func _rig(kind: int) -> Array:
	var log := TickEventLog.new(512)
	var bullet_rules: BulletRules = load("res://data/bullet_rules.tres")
	var planes := PlaneCore.new(load("res://data/plane_rules.tres"), PLAY_AREA, log)
	planes.join(0)
	var scene := PatternScene.new(load("res://data/pattern_rules.tres"), FakeBulletField.new(), log)
	var enemies := EnemyManager.new(scene, log, PLAY_AREA, load("res://data/enemy_rules.tres"))
	var enemy_pool := BulletField.new(bullet_rules, PLAY_AREA)
	var kits := PlaneKits.new(load("res://data/kit_rules.tres"), bullet_rules, PLAY_AREA)
	kits.set_kind(0, kind)
	kits.on_damage = func(slot: int, target: int, amount: int) -> void:
		enemies.damage(target, amount)
	var input := SimInput.new()
	var rig: Array = [kits, planes, enemies, scene, enemy_pool, input]
	_rigs.push_back(rig)
	for t: int in range(200):
		input.begin_tick()
		planes.tick(input)
	return rig


func _run(rig: Array, ticks: int, fire: bool, drone := false, move_x := 0) -> void:
	for t: int in range(ticks):
		_tick(rig, fire, drone and t == 0, move_x)


func _tick(rig: Array, fire: bool, drone: bool, move_x := 0) -> void:
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	var enemies: EnemyManager = rig[2]
	var enemy_pool: BulletField = rig[4]
	var input: SimInput = rig[5]
	input.begin_tick()
	input.set_move(0, move_x, 0)
	input.set_button(0, SimInput.Action.FIRE, fire)
	input.set_button(0, SimInput.Action.DRONE, drone)
	planes.tick(input)
	kits.tick(planes, input, enemies, enemy_pool)
	enemies.publish_targets(kits.field)
	kits.field.tick()
	enemy_pool.tick()


## A stationary, tough target to shoot at.
func _target_def() -> EnemyDef:
	var def := EnemyDef.new()
	def.id = &"test_target"
	def.hp = 100000
	def.body_radius = 16.0
	def.hurt_pad = 2.0
	def.max_life_ticks = 0
	return def


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
