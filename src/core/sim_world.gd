class_name SimWorld
extends RefCounted
## The whole simulation, node-free. Implements ADR-0002 Decision 1 and 3:
## SimWorld owns every simulation system and runs steps 1-8 in `tick(t)`.
## GameLoop (a Node) is the thin driver that decides whether a physics step
## becomes a game tick, then calls this, then runs presentation step 9.
##
## Nothing here touches the scene tree, Input, or GameEvents. That is what lets
## tests, the replay verifier and Flight School drills drive it directly, and
## what keeps presentation from changing simulation results.
##
## Step numbers below are ADR-0002's and are authoritative; systems from epics
## that have not landed yet are marked and skipped rather than faked, so the
## order stays correct as they slot in.
##
## Usage:
## [codeblock]
## var world := SimWorld.new(SimWorld.Config.new())
## world.add_player(0)
## world.add_player(1)          # local co-op, no extra wiring
##
## # driven by GameLoop each admitted physics step, or directly in a test
## world.tick(world.game_tick)
##
## # presentation reads after the tick, never during
## for i: int in range(world.events.size()):
##     emit(world.events.kind_at(i), world.events.slot_at(i))
## [/codeblock]

## Everything SimWorld needs to be built, so a test can construct one without
## touching res:// paths.
## Which kit each slot flies until Plane select (22) lands. Four different
## planes, which is the concept's third pillar: Four Planes, Four Games.
const DEFAULT_KITS := [
	KitRules.Kind.LANCER,
	KitRules.Kind.LEECH,
	KitRules.Kind.SENTRY,
	KitRules.Kind.BREAKER,
]

class Config extends RefCounted:
	var play_area := Rect2(0, 0, 360, 640)
	var bullet_rules: BulletRules
	var plane_rules: PlaneRules
	var chain_rules: ChainRules
	var scoring_rules: ScoringRules
	## Optional. With it, SimWorld owns a [PatternScene] at step 4; without it
	## (most unit tests) step 4 has only the `emitters` hook.
	var pattern_rules: PatternRules
	## Optional. With it the players can shoot, use drones and charge (step 3),
	## and enemies can be hit (step 6 Phase A).
	var kit_rules: KitRules
	## Optional. With it the Bomb button works (step 3b).
	var bomb_rules: BombRules
	## Optional. With it SimWorld runs a stage: waves at step 3a, enemies at
	## step 3b.
	var stage: StageDef
	## Optional enemy tuning; defaults are used when absent.
	var enemy_rules: EnemyRules
	## Optional. With it carriers drop pods, medals, chain pickups and 1-ups,
	## and cancelled bullets become gems (step 7b).
	var item_rules: ItemRules
	## Which stage this is, 0-based. Seeds the drop stream.
	var stage_index := 0
	## Optional. With it the Critical Break works: charge the wounded boss,
	## then bomb it, and the chain is multiplied instead of halved.
	var critical_rules: CriticalBreakRules
	var event_capacity := 256
	var seed := 20261103

	## Loads the shipped designer data. Tests build Config by hand instead.
	static func from_data() -> Config:
		var c := Config.new()
		c.bullet_rules = load("res://data/bullet_rules.tres")
		c.plane_rules = load("res://data/plane_rules.tres")
		c.chain_rules = load("res://data/chain_rules.tres")
		c.scoring_rules = load("res://data/scoring_rules.tres")
		c.pattern_rules = load("res://data/pattern_rules.tres")
		c.kit_rules = load("res://data/kit_rules.tres")
		c.bomb_rules = load("res://data/bomb_rules.tres")
		c.stage = load("res://data/stages/stage_1_1941.tres")
		c.enemy_rules = load("res://data/enemy_rules.tres")
		c.item_rules = load("res://data/item_rules.tres")
		c.critical_rules = load("res://data/critical_break_rules.tres")
		return c

var play_area: Rect2
var events: TickEventLog
var input: SimInput
var planes: PlaneCore
var enemy_bullets: BulletField
## The players' kits: the main shot, the drones, the laser, the latch.
## Null when no [KitRules] was supplied.
var kits: PlaneKits
## The bomb, per slot. Null when no [BombRules] was supplied.
var bombs: BombCores
## Every live enemy. Null when no [StageDef] was supplied.
var enemies: EnemyManager
## The stage: five waves, then the boss. Null when no [StageDef] was supplied.
var director: StageDirector
## Pods, medals, chain pickups, 1-ups and gems. Null when no [ItemRules] was
## supplied.
var items: ItemField
## The Critical Break. Null when no [CriticalBreakRules] was supplied.
var critical: CriticalBreakCore

## Where the run is. The simulation stops advancing once it leaves PLAYING,
## so the scene can hold the last frame under a banner instead of letting
## waves keep arriving over a dead player.
enum RunState { PLAYING, GAME_OVER, STAGE_CLEAR }
var run_state := RunState.PLAYING
## Ticks since the boss died, so the item sweep (powerups Rule 18) finishes
## before the stage is declared clear.
var _clear_delay := 0
## Ticks the sweep is given before the stage ends regardless.
const SWEEP_MIN_TICKS := 90
var chain: ChainCore
var scoring: ScoringLedger
var rng: RandomNumberGenerator

## Step 4 owners. Each must expose `tick(world: SimWorld)`, and runs BEFORE
## `patterns`, because an owner's job is to put its emitters where they are
## this tick (origin, centre, intensity) before the runners fire them.
## Enemy (10) and Boss (14) will take this over; the run scene installs a
## scaffolding platform until then.
var emitters: Array = []

## Step 4 pattern library (9): every live [PatternEmitter] and its runners.
## Null when no [PatternRules] was supplied.
var patterns: PatternScene

## Collision (6) `death_fire_hold`: while it is on, runners keep counting but
## their volleys fire nothing (pattern library Rule 8). Owned by the Collision
## epic; SimWorld carries it so step 4 can read it today.
var death_fire_hold := false

## Completed game ticks. `run_ticks` in the GDDs (ADR-0002 Decision 6).
var game_tick := 0
var _player_count := 1

# Reused flag buffers, so step 8 allocates nothing per tick.
var _flags_active := PackedInt32Array()
var _flags_alive := PackedInt32Array()
var _flags_at_cap := PackedInt32Array()
var _flags_drones := PackedInt32Array()


func _init(config: Config) -> void:
	assert(config.bullet_rules != null, "SimWorld.Config needs bullet_rules")
	assert(config.plane_rules != null, "SimWorld.Config needs plane_rules")
	assert(config.chain_rules != null, "SimWorld.Config needs chain_rules")
	assert(config.scoring_rules != null, "SimWorld.Config needs scoring_rules")

	play_area = config.play_area
	events = TickEventLog.new(config.event_capacity)
	input = SimInput.new()
	planes = PlaneCore.new(config.plane_rules, play_area, events)
	enemy_bullets = BulletField.new(config.bullet_rules, play_area)
	chain = ChainCore.new(config.chain_rules, events)
	scoring = ScoringLedger.new(config.scoring_rules, config.chain_rules, events)
	if config.pattern_rules != null:
		patterns = PatternScene.new(config.pattern_rules, enemy_bullets, events)
		patterns.run_seed = config.seed
	if config.kit_rules != null:
		kits = PlaneKits.new(config.kit_rules, config.bullet_rules, play_area)
		kits.on_damage = _on_kit_damage
		# Four planes, four games (the concept's third pillar): P1 Lancer,
		# P2 Leech, P3 Sentry, P4 Breaker. Plane select (22) will let a player
		# choose; until then the slot decides.
		for slot: int in range(PlaneCore.MAX_SLOTS):
			kits.set_kind(slot, DEFAULT_KITS[slot])
	if config.bomb_rules != null:
		bombs = BombCores.new(config.bomb_rules, events)
		bombs.on_damage = _on_kit_damage
		for slot: int in range(PlaneCore.MAX_SLOTS):
			bombs.set_kind(slot, DEFAULT_KITS[slot])
	if config.stage != null:
		enemies = EnemyManager.new(patterns, events, play_area, config.enemy_rules)
		director = StageDirector.new(config.stage, enemies, events)
	if config.critical_rules != null:
		critical = CriticalBreakCore.new(config.critical_rules, config.chain_rules, events)
		critical.on_break = _on_critical_break
		if bombs != null:
			bombs.cb_armed = func(slot: int) -> bool:
				return critical.is_armed(
					slot, game_tick, _core_id(), _core_is_critical(), planes.is_active(slot)
				)
			bombs.on_accepted = func(slot: int) -> void:
				critical.note_bomb_started(
					slot, game_tick, _core_id() != 0, _core_is_critical()
				)
	if config.item_rules != null:
		items = ItemField.new(
			config.item_rules,
			config.scoring_rules,
			config.seed,
			config.stage_index,
			events
		)
		_wire_items()

	# One seeded generator passed down, never global randf() (ADR-0001 D7).
	rng = RandomNumberGenerator.new()
	rng.seed = config.seed

	events.append(TickEventLog.Kind.RUN_STARTED, -1, 0)


## Powerups and drops Rule 1: an item writes four things and nothing else —
## a drone, a life, the chain, the score. Wiring them here is what keeps that
## guarantee checkable in one place.
func _wire_items() -> void:
	items.on_pod = func(slot: int) -> void:
		if kits == null:
			return
		kits.set_drone_count(slot, kits.drone_count(slot) + 1)
		events.append(TickEventLog.Kind.DRONE_GAINED, slot, kits.drone_count(slot))
	items.on_oneup = func(slot: int) -> bool:
		return planes.add_life(slot)
	items.on_chain_bonus = func(slot: int, amount: int) -> void:
		# Rule 25: this is not a hit. No hit score, no chain_hit — but it does
		# refill the window, so it can save a chain that was about to expire.
		chain.add_bonus(slot, amount)
	items.on_score = func(slot: int, item_base: int) -> void:
		scoring.award_item(slot, item_base, chain.count_of(slot))


## Brings a local co-op slot into the run. Call before the first tick, or
## mid-run for drop-in.
func add_player(slot: int) -> void:
	planes.join(slot)
	_player_count = 0
	for s: int in range(PlaneCore.MAX_SLOTS):
		if planes.is_in_run(s):
			_player_count += 1
	planes.set_player_count(_player_count)
	if patterns != null:
		# The flak clamp floor follows the HUD strip, which grows at 3 players.
		patterns.set_player_count(_player_count)


## Sets which plane a slot flies, keeping the kit and its bomb in step
## (plane-kits-lancer-leech.md, bombs.md Rule 2: the bomb shape belongs to the
## plane). The Lobby calls this once per joined slot before the first tick;
## `kind` is a [enum KitRules.Kind] value.
func set_slot_kit(slot: int, kind: int) -> void:
	if kits != null:
		kits.set_kind(slot, kind)
	if bombs != null:
		bombs.set_kind(slot, kind)


func kit_kind_of(slot: int) -> int:
	return kits.kind_of(slot) if kits != null else -1


func player_count() -> int:
	return _player_count


## Releases the simulation at the end of a run.
##
## [PatternScene] and its emitters reference each other, and a cycle of
## RefCounted objects is never collected, so a world that is simply dropped
## takes its whole pattern scene with it into the leak report. The scene host
## calls this when it tears the run down.
func dispose() -> void:
	emitters.clear()
	if enemies != null:
		enemies.clear_all()
	if items != null:
		items.clear_all()
	if patterns != null:
		patterns.dispose()
		patterns = null


## One game tick. `t` is the game tick index, 0 at run start.
##
## The event log rotates first, so everything appended during this tick belongs
## to this tick and consumers at earlier steps still read the previous tick's
## log (ADR-0002 D5).
func tick(t: int) -> void:
	events.rotate()
	if run_state != RunState.PLAYING:
		# The run is over. Nothing advances, so the last frame stays on screen
		# under the banner and no wave arrives over a dead player.
		return

	# Step 1: input is already committed into `input` by the sampler (or by a
	# test / replay) before this call. SimWorld never reads devices itself.

	# Step 1a: Session.begin_tick() — joins, continues, forfeits.
	# Not implemented: Session epic. add_player() stands in for joins.

	# Step 2: plane movement and lifecycle.
	planes.tick(input)

	# Step 3: the plane kits, after the planes have moved so a shot leaves the
	# nose where the plane actually is.
	if kits != null:
		kits.tick(planes, input, enemies, enemy_bullets)
	# Step 3b: the bomb, after the kits, so a bomb and a charge on the same
	# tick both happen and neither eats the other (Bombs Rule 7).
	if bombs != null:
		bombs.tick(planes, input, enemies, enemy_bullets, chain)

	# Step 3a: the stage: which wave is on, and when the boss arrives.
	if director != null:
		var boss_before := director.boss_id
		director.tick(t)
		boss_alive = director.is_boss_alive()
		if director.boss_id != 0 and director.boss_id != boss_before and critical != null:
			# Rule 4: a new boss means the break is available again.
			critical.on_core_spawned()
	# Step 3b: enemies age, move and arm their guns.
	if enemies != null:
		enemies.tick(t)
	# Step 3c: BossController (parts, phases). Not implemented: Boss epic —
	# the stage boss is one LARGE enemy until it lands.
	# Step 4: owners place their emitters, then the runners request bullets.
	for i: int in range(emitters.size()):
		emitters[i].tick(self)
	if patterns != null:
		# Alive decides who may be TARGETED (a plane flying in counts);
		# Active decides who spawn safety protects (pattern library Rules
		# 10 and 14). PlaneCore owns both, so the library never guesses.
		patterns.set_slots(
			planes.xs(), planes.ys(), planes.alive_flags(), planes.active_flags()
		)
		patterns.fire_hold = death_fire_hold
		patterns.tick(t)

	# Step 5: hand the referee this tick's targets, then run the bullet field.
	# PlaneCore owns hittability, so an invulnerable or dead slot is excluded
	# here rather than being filtered after the fact.
	enemy_bullets.set_targets(
		planes.xs(),
		planes.ys(),
		planes.prev_xs(),
		planes.prev_ys(),
		planes.radii(),
		planes.hittable_flags(),
	)
	enemy_bullets.tick()

	# Step 5b: the players' shots sweep against the enemy hurtboxes. Same pool
	# code, same swept test: a 900 px/s shot cannot tunnel through a scout.
	if kits != null and enemies != null:
		enemies.publish_targets(kits.field)
		kits.field.tick()

	# Step 6: the collision referee. Phase B (bullets reaching players) is all
	# that exists while there are no enemies: the field reports which slots
	# were reached and the plane core decides what that costs.
	var hits := enemy_bullets.player_hits
	for i: int in range(hits.size()):
		var slot := hits[i]
		events.append(TickEventLog.Kind.PLAYER_HIT, slot, 0)
		if planes.kill(slot):
			# Rule 13: death throws every drone away, which is the sting that
			# makes a pod worth the walk.
			if kits != null:
				kits.set_drone_count(slot, 0)
			# Rule 7: and it arms the recovery pod.
			if items != null:
				items.player_died()

	# Step 6a: Phase A — what the players' shots did. Every impact pays its
	# shooter a chain hit, and the killing one pays the kill.
	if kits != null and enemies != null:
		_resolve_shot_hits()
	# Step 6b: the Critical Break, after collision and BEFORE the chain at
	# step 8 — so the multiply works on the count as it was at the start of
	# this tick (critical-break.md Rule 1).
	if critical != null:
		critical.tick(t, planes, kits, _core_id(), _core_is_critical(), chain)
	# Step 6c: boss part results. Not implemented: Boss epic.
	# Step 7b: powerups and drops. The bullet field reported which bullets it
	# cancelled this tick and who caused them, so a bomb's curtain becomes
	# gems here (powerups Rule 12) rather than vanishing for nothing.
	if items != null:
		items.make_gems(enemy_bullets.cancel_positions, enemy_bullets.cancel_causes)
		items.tick(planes, _drone_counts())

	# Step 8a: the chain. Death drops the dying slot's chain to zero
	# (chain-tracker GDD Rule 5 — a pure reset, never a decay).
	for i: int in range(hits.size()):
		chain.drop(hits[i])
	chain.tick(_active_flags(), boss_alive)

	# Step 8b: scoring. Runs after the chain, so a hit's score uses the count
	# AFTER that hit (scoring F1's `count_after`).
	scoring.tick(_at_cap_flags(), _alive_flags(), chain.is_frozen(), boss_alive)

	# Step 8c Co-op, 8d Session, 8e Tally, 8f Era shift: not implemented.
	_tick_run_state()
	game_tick = t + 1


## The two ways a run ends. Until this existed the director went right on
## sending waves at a player with no lives left, which is what made the stage
## look as though it never progressed.
func _tick_run_state() -> void:
	if planes.all_out():
		events.append(TickEventLog.Kind.GAME_OVER, -1, game_tick)
		run_state = RunState.GAME_OVER
		return
	if director == null or not director.is_stage_clear():
		return
	# Powerups Rule 18: the boss is down, so everything left on the field
	# flies in and is paid before the tally.
	if _clear_delay == 0 and items != null:
		items.begin_sweep()
	_clear_delay += 1
	if _clear_delay >= SWEEP_MIN_TICKS or items == null or items.count() == 0:
		for slot: int in range(PlaneCore.MAX_SLOTS):
			if not planes.is_in_run(slot):
				continue
			scoring.award_stage_end(slot, 0, planes.lives_of(slot), chain.boss_peak_of(slot))
		events.append(TickEventLog.Kind.STAGE_CLEARED, -1, game_tick)
		run_state = RunState.STAGE_CLEAR


## The index of the boss on the field, or -1. The boss is one more enemy until
## Boss and boss parts (14) lands, so "the core" is that enemy.
func _core_index() -> int:
	if director == null or enemies == null or director.boss_id == 0:
		return -1
	for i: int in range(enemies.count()):
		if enemies.id_of(i) == director.boss_id:
			return i
	return -1


func _core_id() -> int:
	return director.boss_id if director != null else 0


## Critical: the core is wounded past `critical_hp_pct`. Boss phases (14) will
## own this; until then hp is the honest stand-in.
##
## Public because the HUD shows it and the bomb reads it to decide whether a
## Critical Break is on the table.
func core_is_critical() -> bool:
	return _core_is_critical()


func _core_is_critical() -> bool:
	if critical == null:
		return false
	var i := _core_index()
	if i < 0:
		return false
	return enemies.hp_ratio_of(i) * 100.0 <= float(critical.rules.critical_hp_pct)


## critical-break.md Rule 14, in order: multiply the chain, pay, clear the
## screen for the breaker, then finish the core.
func _on_critical_break(slot: int, _core: int) -> void:
	var before := chain.count_of(slot)
	var raw := chain.apply_critical_break(slot)
	scoring.award_critical_break(slot, before, planes.lives_of(slot))
	enemy_bullets.request_clear_all(slot, true)
	var i := _core_index()
	if i >= 0:
		_kill_enemy(i, slot)
	events.append(TickEventLog.Kind.CRITICAL_BREAK_LANDED, slot, raw)


## Reports one counted hit by `slot` on an enemy or boss. Called from step 6
## once the enemy and boss epics land; this is the single path by which the
## chain climbs and hit score is paid, so both stay in step.
func report_enemy_hit(slot: int, on_boss: bool = false) -> void:
	if not planes.is_active(slot):
		return
	var active := planes.active_count()
	chain.add_hit(slot, on_boss, active)
	var members := active if chain.is_team_chain() else 2
	scoring.award_hit(slot, chain.count_of(slot), chain.is_team_chain(), members)


## A kit or a bomb dealt damage that is not a bullet (laser, parked beam,
## latch, bomb column). Collision decides what it costs, and a kill pays the
## player who landed it. Bomb hits never feed the chain (Bombs Rule 1), so
## only kit damage reports a chain hit.
func _on_kit_damage(slot: int, target: int, amount: int) -> void:
	if enemies == null or not enemies.is_hittable(target):
		return
	var from_bomb := bombs != null and bombs.is_active(slot)
	if critical != null and enemies.id_of(target) == _core_id():
		if from_bomb:
			critical.note_bomb_landed(slot, _core_id(), game_tick, _core_id())
		elif kits != null and kits.is_charging(slot):
			critical.note_charge_hit(slot, _core_id(), game_tick)
	if not from_bomb:
		report_enemy_hit(slot, boss_alive)
	if enemies.damage(target, amount):
		_kill_enemy(target, slot)


## The one path by which an enemy dies to a player. It pays the kill and gives
## a carrier its drop (powerups Rule 3: only a carrier SHOT DOWN drops).
func _kill_enemy(target: int, slot: int) -> void:
	var carrier := enemies.is_carrier(target)
	var at := enemies.position_of(target)
	var size_class := enemies.size_class_of(target)
	var override := enemies.drop_override_of(target)
	var kill_class := enemies.kill(target, slot, enemy_bullets)
	scoring.award_kill(slot, kill_class)
	if carrier and items != null:
		items.drop_requested(
			at, slot, size_class, override, _player_count, _needy_slots(), _lives_full()
		)


## Rule 8: how many slots could still use a pod. A pod never appears when
## nobody can take it.
func _needy_slots() -> int:
	if kits == null:
		return 0
	var n := 0
	for s: int in range(PlaneCore.MAX_SLOTS):
		if planes.is_in_run(s) and kits.drone_count(s) < kits.rules.max_drones:
			n += 1
	return n


## Rule 11: a 1-up with nowhere to go is paid as a medal instead.
func _lives_full() -> bool:
	for s: int in range(PlaneCore.MAX_SLOTS):
		if planes.is_in_run(s) and planes.lives_of(s) < planes.rules.max_lives:
			return false
	return true


func _drone_counts() -> PackedInt32Array:
	_flags_drones.resize(PlaneCore.MAX_SLOTS)
	for s: int in range(PlaneCore.MAX_SLOTS):
		_flags_drones[s] = kits.drone_count(s) if kits != null else 0
	return _flags_drones


## True while a boss is on the field. Gates the team chain and the cap-hold
## streak. Set by the director each tick.
var boss_alive := false


## Collision Phase A: resolve this tick's shot impacts into damage, chain hits
## and kills (design/gdd/collision-damage-lives.md).
##
## Impacts are handled newest-target-first so removing a dead enemy cannot
## shift the index of one still to be resolved.
func _resolve_shot_hits() -> void:
	var field := kits.field
	var targets := field.hit_targets
	if targets.size() == 0:
		return
	var shooters := field.hit_shooters
	var damages := field.hit_damage
	var default_damage := kits.rules.shot_damage
	# Count the impacts per enemy, keeping the shooter of each one, then apply
	# them from the highest enemy index down.
	var order := targets.duplicate()
	order.sort()
	var i := order.size() - 1
	while i >= 0:
		var target := order[i]
		# Every impact on this enemy, from this tick.
		var hits := 0
		var killer := -1
		var impacts := PackedInt32Array()
		for k: int in range(targets.size()):
			if targets[k] != target:
				continue
			hits += 1
			killer = shooters[k]
			# The damage rides on the bullet, because one pool holds a 20 dmg
			# drone diamond and a 50 dmg Entrench shell at the same time.
			var dmg := damages[k] if k < damages.size() else 0
			impacts.append(dmg if dmg > 0 else default_damage)
			# Rule 20: a counted plane-shot hit is what fills the laser meter.
			kits.report_shot_hit(shooters[k])
			if (
				critical != null
				and kits.is_charging(shooters[k])
				and enemies.id_of(target) == _core_id()
			):
				# Deviation, stated: without per-bullet tags any plane-pool
				# hit while charging counts, where the GDD wants only the
				# charge source (tag 2/3).
				critical.note_charge_hit(shooters[k], _core_id(), game_tick)
			# C5: an armoured hit still counts for the chain, which is what
			# makes shooting a plated bomber worth doing.
			report_enemy_hit(shooters[k], boss_alive)
		if hits > 0:
			var killed := false
			for h: int in range(impacts.size()):
				if enemies.damage(target, impacts[h]):
					killed = true
					break
			if killed and killer >= 0:
				_kill_enemy(target, killer)
		# Skip the rest of this enemy's impacts: they were all just handled.
		while i >= 0 and order[i] == target:
			i -= 1


func _active_flags() -> PackedInt32Array:
	_flags_active.resize(PlaneCore.MAX_SLOTS)
	for s: int in range(PlaneCore.MAX_SLOTS):
		_flags_active[s] = 1 if planes.is_active(s) else 0
	return _flags_active


func _alive_flags() -> PackedInt32Array:
	_flags_alive.resize(PlaneCore.MAX_SLOTS)
	for s: int in range(PlaneCore.MAX_SLOTS):
		_flags_alive[s] = 1 if planes.is_in_run(s) else 0
	return _flags_alive


func _at_cap_flags() -> PackedInt32Array:
	_flags_at_cap.resize(PlaneCore.MAX_SLOTS)
	for s: int in range(PlaneCore.MAX_SLOTS):
		_flags_at_cap[s] = 1 if chain.is_at_cap(s) else 0
	return _flags_at_cap


## Order-dependent hash of the whole simulation, for ADR-0003 replay
## verification. Every system that owns state must contribute.
func state_hash() -> int:
	var h := 1469598103934665603
	h = (h ^ game_tick) * 1099511628211
	h = (h ^ planes.state_hash()) * 1099511628211
	h = (h ^ enemy_bullets.state_hash()) * 1099511628211
	h = (h ^ chain.state_hash()) * 1099511628211
	h = (h ^ scoring.state_hash()) * 1099511628211
	if kits != null:
		h = (h ^ kits.state_hash()) * 1099511628211
	if bombs != null:
		h = (h ^ bombs.state_hash()) * 1099511628211
	if enemies != null:
		h = (h ^ enemies.state_hash()) * 1099511628211
	if director != null:
		h = (h ^ director.state_hash()) * 1099511628211
	if items != null:
		h = (h ^ items.state_hash()) * 1099511628211
	if critical != null:
		h = (h ^ critical.state_hash()) * 1099511628211
	if patterns != null:
		var ctx := SimHash.begin()
		patterns.hash_into(ctx)
		h = (h ^ SimHash.digest64(ctx)) * 1099511628211
	return h
