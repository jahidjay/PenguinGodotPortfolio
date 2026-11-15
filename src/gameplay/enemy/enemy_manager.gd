class_name EnemyManager
extends RefCounted
## Every live enemy (design/gdd/enemy-and-ai.md), node-free and in packed
## arrays, at step 3b of the ADR-0002 tick.
##
## What it owns: age, position, hp, armour state, and one [PatternEmitter] per
## armed enemy. What it does NOT own: who shot it (Collision Phase A), what it
## drops (Powerups 13), or which enemies a wave sends (Wave director 16).
##
## Movement is a pure function of the integer age ([EnemyPath]), so no enemy
## accumulates float error and a wave plays identically every run.
##
## Hurtboxes are published as TARGETS of the player-shot pool, so a shot
## reaching an enemy is the same swept test as a bullet reaching a player —
## one implementation, and a 900 px/s shot cannot tunnel through a scout.
##
## Leaving the field is not escaping: with [member EnemyRules.respawn_on_escape]
## an enemy that flies off (or times out) re-enters from its spawn point, so a
## wave ends only when it is shot down. Squads (one spawn group) get faster and
## fire harder as their members fall ([enum Aggro]).
##
## Scope: the MVP subset. One hurtbox circle per enemy (the GDD's 2 and 3 for
## MEDIUM and LARGE are marked below), no formations, no novelty stripping, no
## facing. Those arrive with the systems that drive them.
##
## Usage:
## [codeblock]
## var enemies := EnemyManager.new(world.patterns, world.events, play_area)
## enemies.spawn(def, Vector2(120, -20), false, 0.0)
##
## # step 3b, before the pattern runners fire
## enemies.tick(world.game_tick)
## # step 5: the player shots test against these
## enemies.publish_targets(kits.field)
## [/codeblock]

## Enemies alive at once. A wave that asks for more is refused (Rule 8.1).
const MAX_ALIVE := 64

var play_area: Rect2
var rules: EnemyRules
var patterns: PatternScene
var _log: TickEventLog

var _n := 0
var _def: Array[EnemyDef] = []
var _emitter: Array = []
## Unique id per spawn, so a hit on a dead enemy cannot damage its successor.
var _id := PackedInt32Array()
var _origin_x := PackedFloat32Array()
var _origin_y := PackedFloat32Array()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _prev_x := PackedFloat32Array()
var _prev_y := PackedFloat32Array()
var _age := PackedInt32Array()
var _hp := PackedInt32Array()
var _mirror := PackedInt32Array()
## Pattern-library owner id: `event_id * 16 + member_index` (Rule 15).
var _owner_id := PackedInt32Array()
var _intensity := PackedFloat32Array()
## Tick the enemy first became targetable, or -1. Plating runs from it.
var _seen_tick := PackedInt32Array()
## 1 when this enemy carries an item (powerups-and-drops.md Rule 3). Only a
## carrier ever drops anything, and only when it is SHOT DOWN: an escaped
## carrier drops nothing (Rule 3).
var _carrier := PackedInt32Array()
## Forces one item kind instead of the drop table (Rule 7a). -1 rolls.
var _drop_override := PackedInt32Array()
## Which squad (spawn group) the enemy belongs to, and how big that squad is.
## A squad of 1 never gets aggressive: it has no one to lose.
var _squad := PackedInt32Array()
var _squad_size := PackedInt32Array()
## Path time in 1/[constant EnemyPath.SUBTICKS] ticks. Advances faster than
## `_age` once the squad is aggressive.
var _path_sub := PackedInt32Array()
## Members shot down per squad id. Kept for the life of the stage, so a
## survivor stays aggressive after it respawns.
var _squad_lost := {}

## How aggressive a squad's survivors are (see [EnemyRules] "Squad aggression").
enum Aggro { NORMAL, HALF_SQUAD, ALONE }

# Target arrays published to the player-shot pool, rebuilt each tick.
var _t_x := PackedFloat32Array()
var _t_y := PackedFloat32Array()
var _t_px := PackedFloat32Array()
var _t_py := PackedFloat32Array()
var _t_r := PackedFloat32Array()
var _t_hit := PackedInt32Array()

var _next_id := 1
var _tick := 0

## Counters the Wave director and the debug readout read.
var spawned_total := 0
var killed_total := 0
var escaped_total := 0
var spawns_refused := 0


func _init(
	p_patterns: PatternScene,
	p_log: TickEventLog,
	p_play_area: Rect2,
	p_rules: EnemyRules = null
) -> void:
	rules = p_rules if p_rules != null else EnemyRules.new()
	patterns = p_patterns
	_log = p_log
	play_area = p_play_area
	_def.resize(MAX_ALIVE)
	_emitter.resize(MAX_ALIVE)
	_id.resize(MAX_ALIVE)
	_origin_x.resize(MAX_ALIVE)
	_origin_y.resize(MAX_ALIVE)
	_x.resize(MAX_ALIVE)
	_y.resize(MAX_ALIVE)
	_prev_x.resize(MAX_ALIVE)
	_prev_y.resize(MAX_ALIVE)
	_age.resize(MAX_ALIVE)
	_hp.resize(MAX_ALIVE)
	_mirror.resize(MAX_ALIVE)
	_owner_id.resize(MAX_ALIVE)
	_intensity.resize(MAX_ALIVE)
	_seen_tick.resize(MAX_ALIVE)
	_carrier.resize(MAX_ALIVE)
	_drop_override.resize(MAX_ALIVE)
	_drop_override.fill(-1)
	_squad.resize(MAX_ALIVE)
	_squad_size.resize(MAX_ALIVE)
	_path_sub.resize(MAX_ALIVE)


## Brings one enemy onto the field. Returns its id, or 0 if refused.
##
## `mirror` flips the path in x about the canvas centre (Rule 6), so one
## authored left entry serves both sides. `intensity` is frozen here for the
## enemy's whole life (Rule 4 / the Pattern library's Rule 6).
## `event_id` also names the enemy's squad, and `squad_size` is how many
## members that squad has in total.
func spawn(
	def: EnemyDef,
	origin: Vector2,
	mirror: bool,
	intensity: float,
	event_id: int = 0,
	member: int = 0,
	carrier: bool = false,
	drop_override: int = -1,
	squad_size: int = 1
) -> int:
	if _n >= mini(MAX_ALIVE, rules.max_alive) or def == null:
		spawns_refused += 1
		return 0
	var i := _n
	var id := _next_id
	_next_id += 1
	_def[i] = def
	_id[i] = id
	_origin_x[i] = origin.x
	_origin_y[i] = origin.y
	_x[i] = origin.x
	_y[i] = origin.y
	_prev_x[i] = origin.x
	_prev_y[i] = origin.y
	_age[i] = 0
	_hp[i] = maxi(1, def.hp)
	_mirror[i] = 1 if mirror else 0
	_intensity[i] = clampf(intensity, 0.0, 1.0)
	_seen_tick[i] = -1
	_carrier[i] = 1 if (carrier or def.carrier) else 0
	_drop_override[i] = drop_override
	_squad[i] = event_id
	_squad_size[i] = maxi(1, squad_size)
	_path_sub[i] = 0
	_emitter[i] = null
	# Rule 15 of the pattern library: the stream is seeded from the owner's
	# authored id, which for a wave enemy is `event_id * 16 + member_index`.
	# The emitter itself is not registered until the enemy is on the field
	# (Rule 18), so an off-screen gun's timers have not started.
	_owner_id[i] = event_id * 16 + (member & 15)
	_n += 1
	spawned_total += 1
	_log.append(TickEventLog.Kind.ENEMY_SPAWNED, -1, id)
	return id


## One tick: age, move, publish, and retire whatever has left or timed out.
func tick(t: int) -> void:
	_tick = t
	var i := 0
	while i < _n:
		var def := _def[i]
		var age := _age[i] + 1
		_age[i] = age
		_prev_x[i] = _x[i]
		_prev_y[i] = _y[i]

		var aggro := aggro_of(i)
		_path_sub[i] += _path_step(aggro)
		var off := EnemyPath.offset_sub(def.path, _path_sub[i])
		if _mirror[i] != 0:
			off.x = -off.x
		_x[i] = _origin_x[i] + off.x
		_y[i] = _origin_y[i] + off.y

		if _is_targetable(i) and _seen_tick[i] < 0:
			_seen_tick[i] = t

		# Rule 18: the gun arms ONCE, when its MUZZLE is inside the fire zone.
		# Arming on the body touching the edge is what let a bomber fire from
		# above the top of the screen, so the bullets came from nowhere.
		if _emitter[i] == null and patterns != null and def.patterns.size() > 0:
			if _muzzle_in_fire_zone(i):
				_emitter[i] = patterns.add_emitter(_owner_id[i], 0, def.patterns, t)

		var e = _emitter[i]
		if e != null:
			e.update(
				Vector2(_x[i], _y[i]) + def.muzzle_offset,
				Vector2(_x[i], _y[i]),
				minf(1.0, _intensity[i] + _intensity_bonus(aggro))
			)

		if _should_retire(i):
			escaped_total += 1
			_log.append(TickEventLog.Kind.ENEMY_ESCAPED, -1, _id[i])
			if rules.respawn_on_escape:
				_respawn(i)
				i += 1
			else:
				_remove(i)
			continue
		i += 1


## Sends enemy `i` back to its spawn point to fly its path again. It keeps its
## hp, its squad and its carrier flag; its gun re-arms when it is back on the
## field (Rule 18).
func _respawn(i: int) -> void:
	var e = _emitter[i]
	if e != null and patterns != null:
		patterns.remove_emitters_of(e.owner_id, false)
	_emitter[i] = null
	_age[i] = 0
	_path_sub[i] = 0
	_seen_tick[i] = -1
	_x[i] = _origin_x[i]
	_y[i] = _origin_y[i]
	# No sweep from the exit point to the entry point.
	_prev_x[i] = _x[i]
	_prev_y[i] = _y[i]


## How aggressive enemy `i` is, from how much of its squad has been shot down.
func aggro_of(i: int) -> int:
	var size := _squad_size[i]
	if size <= 1:
		return Aggro.NORMAL
	var lost: int = _squad_lost.get(_squad[i], 0)
	if size - lost <= 1:
		return Aggro.ALONE
	if lost * 2 >= size:
		return Aggro.HALF_SQUAD
	return Aggro.NORMAL


## Path time advanced per tick, in sub-ticks.
func _path_step(aggro: int) -> int:
	var speed := 1.0
	match aggro:
		Aggro.HALF_SQUAD:
			speed = rules.half_squad_speed
		Aggro.ALONE:
			speed = rules.alone_speed
	return maxi(1, roundi(speed * EnemyPath.SUBTICKS))


func _intensity_bonus(aggro: int) -> float:
	match aggro:
		Aggro.HALF_SQUAD:
			return rules.half_squad_intensity
		Aggro.ALONE:
			return rules.alone_intensity
	return 0.0


## True once the body has entered the play field: only then may it be hit, and
## only then does its plating clock start (Rules 9 and 12).
func _is_targetable(i: int) -> bool:
	var def := _def[i]
	var r := def.body_radius + def.spine_half
	return (
		_x[i] + r >= play_area.position.x
		and _x[i] - r <= play_area.end.x
		and _y[i] + r >= play_area.position.y
		and _y[i] - r <= play_area.end.y
	)


## Rule 18's fire zone: the muzzle itself, inset from every edge, so the first
## volley always leaves a point the player can see.
func _muzzle_in_fire_zone(i: int) -> bool:
	var muzzle := Vector2(_x[i], _y[i]) + _def[i].muzzle_offset
	var inset := rules.fire_inset
	return (
		muzzle.x >= play_area.position.x + inset
		and muzzle.x <= play_area.end.x - inset
		and muzzle.y >= play_area.position.y + inset
		and muzzle.y <= play_area.end.y - inset
	)


## Leaves the field (respawned or retired, per the rules) when its life runs out, or once it has been on the field and then
## left it for good (down past the bottom, or out the side).
func _should_retire(i: int) -> bool:
	var def := _def[i]
	if def.max_life_ticks > 0 and _age[i] >= def.max_life_ticks:
		return true
	if _seen_tick[i] < 0:
		return false
	var margin := def.body_radius + def.spine_half + rules.retire_margin
	return (
		_y[i] - margin > play_area.end.y
		or _x[i] + margin < play_area.position.x - 40.0
		or _x[i] - margin > play_area.end.x + 40.0
	)


## True while this enemy's hits count but cannot kill it (Rule 12).
func is_armoured(i: int) -> bool:
	var def := _def[i]
	if def.plating_ticks <= 0 or _seen_tick[i] < 0:
		return false
	return _tick - _seen_tick[i] < def.plating_ticks


## Registers every targetable enemy as a target of `field`, so the player's
## shots sweep against them. Index order IS the target order the field reports
## hits in, and it is rebuilt every tick.
##
## One circle per enemy for now; the GDD's `hurtbox_count` of 2 (MEDIUM) and 3
## (LARGE) spreads circles along the spine and is not implemented.
func publish_targets(field: BulletField) -> void:
	_t_x.resize(_n)
	_t_y.resize(_n)
	_t_px.resize(_n)
	_t_py.resize(_n)
	_t_r.resize(_n)
	_t_hit.resize(_n)
	for i: int in range(_n):
		var def := _def[i]
		_t_x[i] = _x[i]
		_t_y[i] = _y[i]
		_t_px[i] = _prev_x[i]
		_t_py[i] = _prev_y[i]
		_t_r[i] = def.body_radius + def.hurt_pad
		_t_hit[i] = 1 if _is_targetable(i) else 0
	field.set_targets(_t_x, _t_y, _t_px, _t_py, _t_r, _t_hit)


## Applies `damage` to enemy `i` and returns true if that killed it. Armoured
## enemies take the reduced damage and cannot drop below 1 hp (Rule 12).
func damage(i: int, amount: int) -> bool:
	if i < 0 or i >= _n:
		return false
	var def := _def[i]
	var dealt := amount
	if is_armoured(i):
		dealt = (amount * def.plating_armor_pct) / 100
		_hp[i] = maxi(1, _hp[i] - dealt)
		return false
	_hp[i] -= dealt
	return _hp[i] <= 0


## Removes enemy `i` as a kill: logs it, cancels bullets if its class does, and
## tells its emitter its gun is destroyed (so lit flak fuses die with it).
func kill(i: int, slot: int, enemy_bullets: BulletField) -> int:
	var def := _def[i]
	var kill_class := def.resolved_kill_class()
	if def.cancel_radius > 0.0 and enemy_bullets != null:
		# Rule 12: a kill-cancel pays score items, credited to the killer.
		enemy_bullets.request_cancel_circle(
			_x[i], _y[i], def.cancel_radius, slot, true
		)
	_log.append(TickEventLog.Kind.ENEMY_KILLED, slot, _id[i])
	killed_total += 1
	if _squad_size[i] > 1:
		_squad_lost[_squad[i]] = _squad_lost.get(_squad[i], 0) + 1
	_remove(i)
	return kill_class


func _remove(i: int) -> void:
	var e = _emitter[i]
	if e != null and patterns != null:
		patterns.remove_emitters_of(e.owner_id, true)
	var last := _n - 1
	if i != last:
		_def[i] = _def[last]
		_emitter[i] = _emitter[last]
		_id[i] = _id[last]
		_origin_x[i] = _origin_x[last]
		_origin_y[i] = _origin_y[last]
		_x[i] = _x[last]
		_y[i] = _y[last]
		_prev_x[i] = _prev_x[last]
		_prev_y[i] = _prev_y[last]
		_age[i] = _age[last]
		_hp[i] = _hp[last]
		_mirror[i] = _mirror[last]
		_owner_id[i] = _owner_id[last]
		_intensity[i] = _intensity[last]
		_seen_tick[i] = _seen_tick[last]
		_carrier[i] = _carrier[last]
		_drop_override[i] = _drop_override[last]
		_squad[i] = _squad[last]
		_squad_size[i] = _squad_size[last]
		_path_sub[i] = _path_sub[last]
	_def[last] = null
	_emitter[last] = null
	_n = last


## Clears the field at a stage end: no kill credit, no drops, no cancel.
func clear_all() -> void:
	while _n > 0:
		_remove(_n - 1)
	_squad_lost.clear()


## Plane kits Rule 15: the nearest hurtbox ABOVE `y_from` whose x-range
## overlaps the column, or -1. Ties break by index, never by chance, so a
## laser and anything else aiming up a column always agree on what they are pointing at.
func first_in_column(x: float, half_width: float, y_from: float) -> int:
	var best := -1
	var best_y := -INF
	for i: int in range(_n):
		if not _is_targetable(i):
			continue
		if _y[i] > y_from:
			continue
		var reach := half_width + _def[i].body_radius + _def[i].hurt_pad
		if absf(_x[i] - x) >= reach:
			continue
		if _y[i] > best_y:
			best_y = _y[i]
			best = i
	return best


## Plane kits Rule 15: the nearest targetable enemy to `from`, or -1.
func nearest(from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i: int in range(_n):
		if not _is_targetable(i):
			continue
		var d := from.distance_squared_to(Vector2(_x[i], _y[i]))
		if d < best_d:
			best_d = d
			best = i
	return best


## True if enemy `i` may be damaged this tick.
func is_hittable(i: int) -> bool:
	return i >= 0 and i < _n and _is_targetable(i)


## The radius the player's weapons test against (body plus the generous pad).
func hurt_radius_of(i: int) -> float:
	return _def[i].body_radius + _def[i].hurt_pad


# --- reads -------------------------------------------------------------------

func count() -> int:
	return _n


func alive_count() -> int:
	return _n


func def_of(i: int) -> EnemyDef:
	return _def[i]


func id_of(i: int) -> int:
	return _id[i]


func hp_of(i: int) -> int:
	return _hp[i]


func position_of(i: int) -> Vector2:
	return Vector2(_x[i], _y[i])


func is_lethal(i: int) -> bool:
	return _def[i].layer == EnemyDef.Layer.AIR


## Powerups and drops Rule 3: only a carrier shot down drops anything.
func is_carrier(i: int) -> bool:
	return i >= 0 and i < _n and _carrier[i] != 0


func drop_override_of(i: int) -> int:
	return _drop_override[i] if i >= 0 and i < _n else -1


func size_class_of(i: int) -> int:
	return _def[i].size_class


## Health left as a fraction of this kind's full hp. The Critical Break (17)
## reads it to decide when a boss has entered its critical window.
func hp_ratio_of(i: int) -> float:
	if i < 0 or i >= _n:
		return 0.0
	return float(_hp[i]) / float(maxi(1, _def[i].hp))


func state_hash() -> int:
	var h := 1469598103934665603
	for i: int in range(_n):
		h = (h ^ _id[i]) * 1099511628211
		h = (h ^ int(_x[i] * 64.0)) * 1099511628211
		h = (h ^ int(_y[i] * 64.0)) * 1099511628211
		h = (h ^ _hp[i]) * 1099511628211
		h = (h ^ _age[i]) * 1099511628211
		h = (h ^ _path_sub[i]) * 1099511628211
	return h
