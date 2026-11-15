extends SceneTree
## Plane kits: the fire state machine, the Lancer laser and meter, drones,
## shield, latch and recall (design/gdd/plane-kits-lancer-leech.md Rules 4-36).
##
## Run from the project folder:
##   godot --headless --script res://tests/unit/test_plane_kits.gd

const PLAY_AREA := Rect2(0.0, 48.0, 360.0, 592.0)

var _failures := 0
var _rigs: Array = []


func _init() -> void:
	test_plane_kits_tap_fires_and_lingers()
	test_plane_kits_hold_without_meter_is_a_plain_hold()
	test_plane_kits_hold_stays_plain_when_rearming_is_off()
	test_plane_kits_hold_with_meter_starts_the_laser()
	test_plane_kits_meter_fills_only_from_plane_shots()
	test_plane_kits_laser_burns_meter_damages_and_shields()
	test_plane_kits_laser_ends_on_release_and_on_empty_meter()
	test_plane_kits_docked_drones_fire_on_their_own_phase()
	test_plane_kits_lancer_shield_forms_in_front_of_the_plane_and_follows_it()
	test_plane_kits_lancer_shield_blocks_enemy_bullets()
	test_plane_kits_lancer_shield_drone_breaks_after_its_budget()
	test_plane_kits_lancer_shield_fires_with_the_plane_gun()
	test_plane_kits_leech_drones_latch_and_tick_damage()
	test_plane_kits_ability_recalls_and_goes_on_cooldown()
	test_plane_kits_leech_focused_shot_is_slower_and_harder()
	test_plane_kits_death_clears_the_whole_kit()

	for rig: Array in _rigs:
		(rig[2] as EnemyManager).clear_all()
		(rig[3] as PatternScene).dispose()
	print("PlaneKits tests: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# --- Rules 4, 5: the fire state machine --------------------------------------

func test_plane_kits_tap_fires_and_lingers() -> void:
	var rig := _rig()
	# Arrange / Act: one tap, released after 4 ticks.
	_run(rig, 4, {"fire": true})
	var before := _field(rig).count()
	_assert(before > 0, "a tap fires at once")

	# Assert: the gun keeps going for shot_linger_ticks after the release.
	_run(rig, 10, {"fire": false})
	_assert(_field(rig).count() > before, "and lingers for a dozen ticks after release")
	_run(rig, 4, {"fire": false})          # the last of the 12 linger ticks
	var lingered := _field(rig).count()
	_run(rig, 30, {"fire": false})
	_assert_eq(
		_field(rig).count() - lingered, 0, "then stops: no linger beyond its 12 ticks"
	)


func test_plane_kits_hold_without_meter_is_a_plain_hold() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	_run(rig, 40, {"fire": true})
	_assert_eq(kits.fire_state(0), PlaneKits.Fire.HOLD_PLAIN, "no meter: the hold is plain")
	_assert(not kits.is_laser_active(0), "and no laser starts")

	# `charge_rearms_while_held` (the shipped default) starts the laser the
	# moment the meter is full enough, even mid-hold. The GDD's Rule 17 edge
	# check meant a player who simply holds Fire never saw the laser at all,
	# because the meter fills while they are already holding.
	for i: int in range(300):
		kits.report_shot_hit(0)
	_run(rig, 2, {"fire": true})
	_assert(
		kits.is_laser_active(0),
		"a full meter mid-hold starts the laser (charge_rearms_while_held)"
	)


func test_plane_kits_hold_stays_plain_when_rearming_is_off() -> void:
	# The GDD letter, which the data switch can restore: Rule 17 is an EDGE
	# check, so a hold that started short stays plain until the next press.
	var rig := _rig()
	var kits := _kits(rig)
	kits.rules = kits.rules.duplicate()
	kits.rules.charge_rearms_while_held = false
	_run(rig, 40, {"fire": true})
	_assert_eq(kits.fire_state(0), PlaneKits.Fire.HOLD_PLAIN, "no meter: the hold is plain")

	for i: int in range(300):
		kits.report_shot_hit(0)
	_run(rig, 60, {"fire": true})
	_assert(
		not kits.is_laser_active(0),
		"the meter reaching 400 mid-hold does not start it: release and press again"
	)
	_run(rig, 2, {"fire": false})
	_run(rig, 30, {"fire": true})
	_assert(kits.is_laser_active(0), "but the next press does")


func test_plane_kits_hold_with_meter_starts_the_laser() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	_fill_meter(kits, 0)
	_run(rig, 17, {"fire": true})
	_assert(not kits.is_laser_active(0), "nothing happens before the 18th held tick")
	_run(rig, 2, {"fire": true})
	_assert(kits.is_laser_active(0), "the laser starts on the tick the hold reaches 18")
	_assert_eq(kits.fire_state(0), PlaneKits.Fire.CHARGE, "and the state is CHARGE")


# --- Rule 20: the meter ------------------------------------------------------

func test_plane_kits_meter_fills_only_from_plane_shots() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	kits.report_shot_hit(0)
	_assert_eq(
		kits.meter_of(0), kits.rules.fill_per_hit,
		"a counted plane-shot hit is worth fill_per_hit"
	)
	for i: int in range(2000):
		kits.report_shot_hit(0)
	_assert_eq(kits.meter_of(0), kits.rules.meter_max, "and it stops at the cap")

	# Rule 20: not while the laser runs.
	_run(rig, 20, {"fire": true})
	_assert(kits.is_laser_active(0), "the laser is running")
	var during := kits.meter_of(0)
	kits.report_shot_hit(0)
	_assert(kits.meter_of(0) <= during, "a hit landing during the laser adds nothing")

	# A Leech has no meter at all.
	var leech := _rig(KitRules.Kind.LEECH)
	_kits(leech).report_shot_hit(0)
	_assert_eq(_kits(leech).meter_of(0), 0, "a Leech never fills a laser meter")


# --- Rules 18, 19, 22: the laser ---------------------------------------------

func test_plane_kits_laser_burns_meter_damages_and_shields() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	var enemies := _enemies(rig)
	var planes := _planes(rig)
	_fill_meter(kits, 0)
	# An enemy directly above the plane, inside the beam column.
	var at := planes.position_of(0)
	enemies.spawn(_target(4000), Vector2(at.x, at.y - 120.0), false, 0.0)
	enemies.tick(1)
	var hp_before := enemies.hp_of(0)

	_run(rig, 19, {"fire": true})      # 18 to charge, then one active tick
	_assert(kits.is_laser_active(0), "the laser is on")
	_assert_eq(
		kits.meter_of(0), kits.rules.meter_max - kits.rules.meter_per_tick,
		"one active tick burns 5 meter"
	)
	_assert(planes.invuln_of(0) > 0, "and the beam shields the plane while it burns")

	_run(rig, 9, {"fire": true})
	var dealt := hp_before - enemies.hp_of(0)
	# 10 active ticks, damage on every third: ticks 0, 3, 6, 9 = 4 events.
	_assert_eq(dealt, 4 * kits.rules.laser_damage, "damage lands every third active tick")


func test_plane_kits_laser_ends_on_release_and_on_empty_meter() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	_fill_meter(kits, 0)
	_run(rig, 20, {"fire": true})
	_assert(kits.is_laser_active(0), "the laser is on")
	_run(rig, 1, {"fire": false})
	_assert(not kits.is_laser_active(0), "releasing Fire ends it at once")

	# Burning the meter dry ends it too: 1000 meter is exactly 200 ticks.
	var rig2 := _rig()
	var kits2 := _kits(rig2)
	_fill_meter(kits2, 0)
	_run(rig2, 18 + 199, {"fire": true})
	_assert(kits2.is_laser_active(0), "199 active ticks in, it is still burning")
	_run(rig2, 2, {"fire": true})
	_assert(not kits2.is_laser_active(0), "and it stops when the meter hits 0")
	_assert_eq(kits2.meter_of(0), 0, "with nothing left")


# --- Rules 9, 23, 29: drones --------------------------------------------------

func test_plane_kits_docked_drones_fire_on_their_own_phase() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	_assert_eq(kits.drone_count(0), 2, "the rig's two pods became two drones")
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.DOCKED, "docked to begin with")
	var fresh := PlaneKits.new(kits.rules, load("res://data/bullet_rules.tres"), PLAY_AREA)
	_assert_eq(
		fresh.drone_count(0), 0,
		"and a plane that has met no carrier has none (powerups Rule 2)"
	)

	# A docked drone fires only while the gun is on (Rule 9).
	var idle := _field(rig).count()
	_run(rig, 30, {"fire": false})
	_assert_eq(_field(rig).count(), idle, "a drone fires nothing with the gun off")
	_run(rig, 30, {"fire": true})
	_assert(_field(rig).count() > idle, "and fires while the gun is on")


func test_plane_kits_lancer_shield_forms_in_front_of_the_plane_and_follows_it() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	var planes := _planes(rig)
	_run(rig, 1, {"fire": false, "drone": true})
	_assert_eq(kits.ability_state(0), PlaneKits.Ability.ACTIVE, "the press is accepted")
	_run(rig, 20, {"fire": false})
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.SHIELD, "the drones reach the shield line")
	var want := planes.position_of(0) + Vector2(kits.rules.shield_dx[0], kits.rules.shield_dy)
	_assert(
		kits.drone_position(0, 0).distance_to(want) < 0.5,
		"drone 1 sits in front of the plane (at %s, want %s)" % [kits.drone_position(0, 0), want]
	)
	_assert(kits.drone_position(0, 0).y < planes.position_of(0).y, "above it, between it and the enemy")

	# It moves WITH the plane: fly left for a while, the wall comes along.
	var input: SimInput = rig[4]
	for t: int in range(20):
		input.begin_tick()
		input.set_move(0, -1, 0)
		planes.tick(input)
		kits.tick(planes, input, _enemies(rig))
	want = planes.position_of(0) + Vector2(kits.rules.shield_dx[0], kits.rules.shield_dy)
	_assert(kits.drone_position(0, 0).distance_to(want) < 0.5, "and follows the plane as it moves")


func test_plane_kits_lancer_shield_blocks_enemy_bullets() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	var pool := _enemy_pool()
	_run_pool(rig, pool, 1, {"fire": false, "drone": true})
	_run_pool(rig, pool, 20, {"fire": false})
	var at := kits.drone_position(0, 0)
	for i: int in range(5):
		pool.request_spawn(at.x, at.y, 0.0, 0.0)
	# A bullet well away from the shield must survive.
	pool.request_spawn(at.x, at.y + 120.0, 0.0, 0.0)
	pool.tick()
	_assert_eq(pool.count(), 6, "six bullets on the field")
	_run_pool(rig, pool, 3, {"fire": false})
	_assert_eq(pool.count(), 1, "the shield erased the five touching it, not the far one")
	_assert_eq(kits.stock_of(0), 0, "a Lancer has no Breaker stock to fill")


func test_plane_kits_lancer_shield_drone_breaks_after_its_budget() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	var pool := _enemy_pool()
	_run_pool(rig, pool, 1, {"fire": false, "drone": true})
	_run_pool(rig, pool, 20, {"fire": false})
	# Feed both drones more bullets than they can take.
	for t: int in range(12):
		for d: int in range(2):
			var at := kits.drone_position(0, d)
			for k: int in range(4):
				pool.request_spawn(at.x, at.y, 0.0, 0.0)
		_run_pool(rig, pool, 1, {"fire": false})
	_assert(
		kits.drone_state(0, 0) == PlaneKits.Drone.RETURNING
		or kits.drone_state(0, 0) == PlaneKits.Drone.DOCKED,
		"a drone that blocked its share breaks and heads home"
	)
	_assert_eq(
		kits.ability_state(0), PlaneKits.Ability.COOLDOWN,
		"with every drone broken the shield is over and cooling down"
	)


func test_plane_kits_lancer_shield_fires_with_the_plane_gun() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	_run(rig, 1, {"fire": false, "drone": true})
	_run(rig, 20, {"fire": false})
	var quiet := kits.shots_fired
	_run(rig, 10, {"fire": false})
	_assert_eq(kits.shots_fired, quiet, "a shield drone holds fire with the gun off")
	# Count only the drone bullets: they start at the drone's x.
	var x := kits.drone_position(0, 0).x
	_run(rig, 10, {"fire": true})
	var from_drone := 0
	var field := _field(rig)
	var xs := field.x_array()
	var vxs := field.vx_array()
	for i: int in range(field.count()):
		if absf(xs[i] - x) < 1.0 and vxs[i] == 0.0:
			from_drone += 1
	_assert(from_drone > 0, "and fires straight up with it (%d drone bullets)" % from_drone)


func test_plane_kits_leech_drones_latch_and_tick_damage() -> void:
	var rig := _rig(KitRules.Kind.LEECH)
	var kits := _kits(rig)
	var enemies := _enemies(rig)
	enemies.spawn(_target(4000), Vector2(180.0, 200.0), false, 0.0)
	enemies.tick(1)

	_run(rig, 1, {"fire": false, "drone": true})
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.FLYING, "the drones launch")
	var hp := enemies.hp_of(0)
	_run(rig, 60, {"fire": false})
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.LATCHED, "and latch onto the target")
	_assert(enemies.hp_of(0) < hp, "a latched drone ticks damage into it")


func test_plane_kits_ability_recalls_and_goes_on_cooldown() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	_run(rig, 1, {"fire": false, "drone": true})
	_run(rig, kits.rules.shield_ticks + 21, {"fire": false})
	_assert_eq(
		kits.ability_state(0), PlaneKits.Ability.COOLDOWN, "the timer ends and the ability cools"
	)
	_run(rig, kits.rules.return_cap + 2, {"fire": false})
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.DOCKED, "every drone comes home")
	_assert(kits.cooldown_left(0) > 0, "and the cooldown is running")

	# A press during the cooldown is refused and changes nothing.
	var left := kits.cooldown_left(0)
	_run(rig, 1, {"fire": false, "drone": true})
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.DOCKED, "a press on cooldown does nothing")
	_assert(kits.cooldown_left(0) < left, "and does not restart the cooldown")


# --- Rules 26, 27: the Leech shot --------------------------------------------

func test_plane_kits_leech_focused_shot_is_slower_and_harder() -> void:
	var rig := _rig(KitRules.Kind.LEECH)
	var kits := _kits(rig)
	kits.set_drone_count(0, 0)          # count the plane shot alone
	# Counted from shots_fired, not the pool, because the pool also loses
	# bullets off the top of the screen while the test runs.
	var before := kits.shots_fired
	_run(rig, 30, {"fire": true})       # normal: 2 bullets every 5 ticks
	var normal := kits.shots_fired - before

	before = kits.shots_fired
	_run(rig, 30, {"fire": true})       # now in CHARGE: 2 every 6 ticks
	_assert_eq(kits.fire_state(0), PlaneKits.Fire.CHARGE, "the Leech always has its charge")
	var focused := kits.shots_fired - before
	_assert(focused < normal, "the focused shot fires fewer bullets (%d vs %d)" % [focused, normal])


# --- Rule 13 ------------------------------------------------------------------

func test_plane_kits_death_clears_the_whole_kit() -> void:
	var rig := _rig()
	var kits := _kits(rig)
	var planes := _planes(rig)
	_fill_meter(kits, 0)
	_run(rig, 20, {"fire": true, "drone": true})
	_assert(kits.is_laser_active(0), "the laser is on before the death")

	# The laser shields the plane every tick it burns (Rule 18a), so it has to
	# be let go of and the grace waited out before anything can kill it. That
	# is the laser working, not the test cheating.
	_run(rig, 1, {"fire": false})
	_run(rig, kits.rules.laser_invuln_ticks + 2, {"fire": false})
	_assert_eq(planes.invuln_of(0), 0, "the exit grace has run out")
	_assert(planes.kill(0), "the plane can now be killed")
	_run(rig, 2, {"fire": false})
	_assert(not kits.is_laser_active(0), "death stops the laser")
	_assert_eq(kits.meter_of(0), 0, "and empties the meter")
	_assert_eq(kits.drone_state(0, 0), PlaneKits.Drone.DOCKED, "and brings every drone home")
	_assert_eq(kits.ability_state(0), PlaneKits.Ability.READY, "and the ability is ready again")


# --- rig ----------------------------------------------------------------------

## [kits, planes, enemies, pattern scene, input]
func _rig(kind := KitRules.Kind.LANCER) -> Array:
	var log := TickEventLog.new(512)
	var kit_rules: KitRules = load("res://data/kit_rules.tres")
	var bullet_rules: BulletRules = load("res://data/bullet_rules.tres")
	var planes := PlaneCore.new(load("res://data/plane_rules.tres"), PLAY_AREA, log)
	planes.join(0)
	var scene := PatternScene.new(load("res://data/pattern_rules.tres"), FakeBulletField.new(), log)
	var enemies := EnemyManager.new(scene, log, PLAY_AREA, load("res://data/enemy_rules.tres"))
	var kits := PlaneKits.new(kit_rules, bullet_rules, PLAY_AREA)
	kits.set_kind(0, kind)
	# Drones come from pods now (powerups-and-drops.md Rule 2), so a plane
	# starts with none. The rig hands this one two, which is what a player
	# flies with a couple of carriers into the stage.
	kits.set_drone_count(0, 2)
	kits.on_damage = func(slot: int, target: int, amount: int) -> void:
		enemies.damage(target, amount)
	var input := SimInput.new()
	var rig := [kits, planes, enemies, scene, input, log]
	_rigs.push_back(rig)
	# Fly the plane in AND wait out the spawn invulnerability, so a test that
	# needs the plane killable is not fighting the 120-tick respawn shield.
	for t: int in range(200):
		input.begin_tick()
		planes.tick(input)
	return rig


func _kits(rig: Array) -> PlaneKits:
	return rig[0]


func _planes(rig: Array) -> PlaneCore:
	return rig[1]


func _enemies(rig: Array) -> EnemyManager:
	return rig[2]


func _field(rig: Array) -> BulletField:
	return (rig[0] as PlaneKits).field


## Runs `ticks` ticks with the given buttons held, the way the sampler would.
func _run(rig: Array, ticks: int, buttons: Dictionary) -> void:
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	var enemies: EnemyManager = rig[2]
	var input: SimInput = rig[4]
	for t: int in range(ticks):
		input.begin_tick()
		input.set_button(0, SimInput.Action.FIRE, buttons.get("fire", false))
		input.set_button(0, SimInput.Action.DRONE, buttons.get("drone", false))
		planes.tick(input)
		kits.tick(planes, input, enemies)


## Like [method _run], with a real enemy bullet pool for the shield to erase.
func _run_pool(rig: Array, pool: BulletField, ticks: int, buttons: Dictionary) -> void:
	var kits: PlaneKits = rig[0]
	var planes: PlaneCore = rig[1]
	var enemies: EnemyManager = rig[2]
	var input: SimInput = rig[4]
	for t: int in range(ticks):
		input.begin_tick()
		input.set_button(0, SimInput.Action.FIRE, buttons.get("fire", false))
		input.set_button(0, SimInput.Action.DRONE, buttons.get("drone", false))
		planes.tick(input)
		kits.tick(planes, input, enemies, pool)
		pool.tick()


func _enemy_pool() -> BulletField:
	return BulletField.new(load("res://data/bullet_rules.tres"), PLAY_AREA)


func _fill_meter(kits: PlaneKits, slot: int) -> void:
	for i: int in range(kits.rules.meter_max / kits.rules.fill_per_hit):
		kits.report_shot_hit(slot)


## A target that will not die to the damage under test.
func _target(hp: int) -> EnemyDef:
	var def := EnemyDef.new()
	def.id = &"kit_test_target"
	def.body_radius = 14.0
	def.hurt_pad = 2.0
	def.hp = hp
	def.max_life_ticks = 0
	var path := EnemyPathDef.new()
	path.kind = EnemyPathDef.Kind.STRAIGHT
	path.velocity = Vector2.ZERO
	def.path = path
	return def


func _assert(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: %s" % what)


func _assert_eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		_failures += 1
		print("FAIL: %s -- got %s, want %s" % [what, got, want])
