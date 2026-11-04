class_name BombCores
extends RefCounted
## The bomb, for all four co-op slots (design/gdd/bombs.md).
##
## The emergency button, with a price: the field clears, the plane is
## untouchable for 90 ticks, and the chain loses half its count. At chain 12
## that is nothing; at chain 600 it hurts — which is the whole design, because
## it makes the player decide what the chain is worth.
##
## Node-free, integer ticks, no randomness (Rule 1). It owns the bomb stock
## and the effect; it does not own bullets (it asks the Bullet manager to
## cancel them), damage resolution, or the chain (it calls the toll and
## nothing else).
##
## Scope: the whole of section A (stock, accept, invulnerability, toll,
## cancel, lockout) and one effect per plane - the Lancer sweep, the Sentry
## Bastion dome and the Breaker Backlash wall. The Leech hooks are modelled
## as the sweep rather than four seeking hooks; marked below.
##
## Rule 35: no effect reads kit state. The kind is set once, at build time,
## because which PLANE is bombing is not the same thing as what its drones,
## meter or stock are doing - a bomb is identical at 0 and 4 drones.
##
## Usage:
## [codeblock]
## var bombs := BombCores.new(rules)
## bombs.on_damage = func(slot, target, amount): ...
##
## # step 3b, after the kits and before collision
## bombs.tick(planes, input, enemies, enemy_bullets, chain)
## [/codeblock]

const MAX_SLOTS := 4

enum State { IDLE, ACTIVE, LOCKOUT }

var rules: BombRules
## `func(slot: int, target_index: int, amount: int) -> void`.
var on_damage: Callable
## `func(slot: int) -> bool` — the Critical Break pure query. Rule 12: a bomb
## accepted while the break is armed pays NO chain toll, because the chain is
## about to be multiplied instead of halved. Absent means never armed.
var cb_armed: Callable
## `func(slot: int) -> void` — the bomb was accepted this tick, so the break
## can decide whether it is committed.
var on_accepted: Callable

var _stock := PackedInt32Array()
var _state := PackedInt32Array()
var _k := PackedInt32Array()            ## ticks since this bomb was accepted
var _lockout := PackedInt32Array()
var _origin_x := PackedFloat32Array()
var _origin_y := PackedFloat32Array()
var _effect_ticks := PackedInt32Array()
## Which plane each slot flies, so the right effect runs. Set by the host.
var _kind := PackedInt32Array()
## Backlash hits each target once and never again (GDD 29 Rule 32).
var _walled := {}
## Damage already dealt to each target by the running bomb, for the per-target
## cap. Indexed slot * 64 + target, which is EnemyManager's own cap.
var _dealt := {}

var _log: TickEventLog


func _init(p_rules: BombRules, p_log: TickEventLog = null) -> void:
	assert(p_rules != null, "BombCores needs a BombRules (data/bomb_rules.tres)")
	rules = p_rules
	_log = p_log
	_stock.resize(MAX_SLOTS)
	_stock.fill(p_rules.bomb_start)
	_state.resize(MAX_SLOTS)
	_k.resize(MAX_SLOTS)
	_lockout.resize(MAX_SLOTS)
	_origin_x.resize(MAX_SLOTS)
	_origin_y.resize(MAX_SLOTS)
	_effect_ticks.resize(MAX_SLOTS)
	_kind.resize(MAX_SLOTS)


## Which plane this slot flies, which decides its bomb. Mirrors
## [method PlaneKits.set_kind] and is set once, before the first tick.
func set_kind(slot: int, kind: int) -> void:
	_kind[slot] = kind


func kind_of(slot: int) -> int:
	return _kind[slot]


func tick(
	planes: PlaneCore,
	input: SimInput,
	enemies: EnemyManager,
	enemy_bullets: BulletField,
	chain: ChainCore
) -> void:
	for slot: int in range(MAX_SLOTS):
		if _lockout[slot] > 0:
			_lockout[slot] -= 1
			if _lockout[slot] == 0 and _state[slot] == State.LOCKOUT:
				_state[slot] = State.IDLE

		if planes.state_of(slot) == PlaneCore.State.DEAD:
			# Rule 3: death is a hard reset, and it refills an empty stock.
			_stock[slot] = rules.bomb_start

		if not planes.is_active(slot):
			continue

		# Rule 4 / Input Rule 17: the press is buffered for 6 ticks and
		# consumed only on the tick the bomb actually goes off, so a press
		# made just before the lockout expired is not thrown away.
		if _state[slot] == State.IDLE and _stock[slot] >= 1:
			if input.consume(slot, SimInput.Action.BOMB):
				_accept(slot, planes, enemy_bullets, chain)

		if _state[slot] == State.ACTIVE:
			_tick_effect(slot, enemies, enemy_bullets)


## Rule 5: everything on the accept tick, in this order.
func _accept(slot: int, planes: PlaneCore, enemy_bullets: BulletField, chain: ChainCore) -> void:
	_stock[slot] -= 1
	planes.request_invuln(slot, rules.invuln_ticks)
	# Rule 12: the toll, paid once, at k = 0 — and waived outright when the
	# Critical Break is armed, which is what makes "laser then bomb" the
	# highest-scoring play in the game instead of the most expensive one.
	var armed := cb_armed.is_valid() and bool(cb_armed.call(slot))
	if chain != null and not armed:
		chain.apply_bomb_toll(slot, rules.chain_toll_pct)
	# Rule 13: a full-screen cancel, before the hit pass, so the deathbomb
	# works — a bullet cancelled this tick can never have hit.
	if enemy_bullets != null:
		enemy_bullets.request_clear_all(slot, true)

	var at := planes.position_of(slot)
	_origin_x[slot] = at.x
	_origin_y[slot] = at.y
	_k[slot] = 0
	_state[slot] = State.ACTIVE
	_dealt[slot] = {}
	_walled[slot] = {}
	match _kind[slot]:
		KitRules.Kind.SENTRY:
			# GDD 29 Rule 31: the dome is world-anchored, above where the
			# plane stood, and always runs for exactly bastion_ticks.
			_origin_y[slot] = maxf(0.0, at.y - rules.bastion_rise)
			_effect_ticks[slot] = rules.bastion_ticks - 1
		KitRules.Kind.BREAKER:
			# SB7: the wall stops when it leaves the top of the field.
			_effect_ticks[slot] = int(
				floor((at.y + rules.backlash_half_h) / rules.backlash_speed)
			)
		_:
			# F5: the sweep runs until the last tick a column still touches
			# the field.
			var reach := maxf(at.x, 360.0 - at.x) + rules.sweep_half_w
			_effect_ticks[slot] = (
				rules.hold_ticks + int(ceil(reach / rules.sweep_speed)) - 1
			)
	if _log != null:
		_log.append(TickEventLog.Kind.BOMB_USED, slot, _stock[slot])
	if on_accepted.is_valid():
		on_accepted.call(slot)


## One tick of whichever effect this plane bomb runs.
func _tick_effect(slot: int, enemies: EnemyManager, enemy_bullets: BulletField) -> void:
	match _kind[slot]:
		KitRules.Kind.SENTRY:
			_tick_bastion(slot, enemies, enemy_bullets)
		KitRules.Kind.BREAKER:
			_tick_backlash(slot, enemies, enemy_bullets)
		_:
			_tick_sweep(slot, enemies, enemy_bullets)
	_k[slot] += 1
	if _k[slot] > _effect_ticks[slot]:
		_state[slot] = State.LOCKOUT
		_lockout[slot] = maxi(1, rules.lockout_ticks - _k[slot])
		_dealt[slot] = {}
		_walled[slot] = {}


## GDD 29 Rule 31: a dome that grows from r0 to r_max, clears every tick and
## pounds what is inside it every sixth. Allies standing in it are safe from
## the bullets it eats; only the bomber is invulnerable.
func _tick_bastion(slot: int, enemies: EnemyManager, enemy_bullets: BulletField) -> void:
	var k := _k[slot]
	var r := bastion_radius(k)
	var c := Vector2(_origin_x[slot], _origin_y[slot])
	if k > 0 and enemy_bullets != null:
		enemy_bullets.request_cancel_circle(c.x, c.y, r, slot, false)
	if k % rules.bastion_interval != 0 or enemies == null:
		return
	for t: int in range(enemies.count()):
		if not enemies.is_hittable(t):
			continue
		if c.distance_to(enemies.position_of(t)) <= r + enemies.hurt_radius_of(t):
			_damage_capped(slot, t, rules.bastion_damage)


func bastion_radius(k: int) -> float:
	return minf(rules.bastion_r_max, rules.bastion_r0 + rules.bastion_grow * float(k))


## GDD 29 Rule 32: a full-width wall climbing from the plane. It hits each
## target ONCE, for a lot, and never touches anything below where it started.
func _tick_backlash(slot: int, enemies: EnemyManager, enemy_bullets: BulletField) -> void:
	var k := _k[slot]
	var y := backlash_y(slot, k)
	if k > 0 and enemy_bullets != null:
		# A rectangle covered by overlapping discs, because the pool cancels
		# circles (the same trick the Lancer column uses).
		var x := rules.backlash_half_h
		while x < 360.0 + rules.backlash_half_h:
			enemy_bullets.request_cancel_circle(x, y, rules.backlash_half_h, slot, false)
			x += rules.backlash_half_h
	if enemies == null:
		return
	var book: Dictionary = _walled[slot]
	for t: int in range(enemies.count()):
		if not enemies.is_hittable(t):
			continue
		var id := enemies.id_of(t)
		if book.has(id):
			continue
		var at := enemies.position_of(t)
		if absf(at.y - y) < rules.backlash_half_h + enemies.hurt_radius_of(t):
			book[id] = true
			_damage_capped(slot, t, rules.backlash_damage)


func backlash_y(slot: int, k: int) -> float:
	return _origin_y[slot] - rules.backlash_speed * float(k)


## Rules 19-22: hold where it was cast, then sweep both ways.
func _tick_sweep(slot: int, enemies: EnemyManager, enemy_bullets: BulletField) -> void:
	var k := _k[slot]
	var columns := _columns(slot, k)

	# Rule 22: every later tick cancels inside the columns only, no items.
	if k > 0 and enemy_bullets != null:
		for cx: float in columns:
			# A column is a rectangle; the pool cancels circles, so the column
			# is covered by overlapping discs down its length.
			var r := rules.sweep_half_w
			var y := 0.0
			while y < 640.0:
				enemy_bullets.request_cancel_circle(cx, y, r)
				y += r

	if k % rules.damage_interval == 0 and enemies != null:
		for t: int in range(enemies.count()):
			if not enemies.is_hittable(t):
				continue
			var at := enemies.position_of(t)
			var reach: float = rules.sweep_half_w + enemies.hurt_radius_of(t)
			var touched := false
			for cx: float in columns:
				if absf(at.x - cx) < reach:
					touched = true
			# Rule 21: a target in both columns still takes ONE event.
			if touched:
				_damage_capped(slot, t, rules.lancer_damage)


## Where the column centres are on tick `k`: one while it holds, two once it
## splits.
func _columns(slot: int, k: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if k < rules.hold_ticks:
		out.push_back(_origin_x[slot])
		return out
	var d := rules.sweep_speed * float(k - rules.hold_ticks + 1)
	out.push_back(_origin_x[slot] - d)
	out.push_back(_origin_x[slot] + d)
	return out


## Rule 8: one bomb may never deal more than `per_target_cap` to one target.
func _damage_capped(slot: int, target: int, amount: int) -> void:
	var book: Dictionary = _dealt[slot]
	var already: int = book.get(target, 0)
	if already >= rules.per_target_cap:
		return
	var give := mini(amount, rules.per_target_cap - already)
	book[target] = already + give
	if on_damage.is_valid():
		on_damage.call(slot, target, give)


## Rule 3: every stage start tops the stock up to its floor.
func on_stage_started() -> void:
	for slot: int in range(MAX_SLOTS):
		_stock[slot] = maxi(_stock[slot], rules.stage_floor)


# --- reads --------------------------------------------------------------------

func stock_of(slot: int) -> int:
	return _stock[slot]


func is_active(slot: int) -> bool:
	return _state[slot] == State.ACTIVE


## The column centres to draw this tick, or empty when no sweep is running.
func columns_of(slot: int) -> PackedFloat32Array:
	if _state[slot] != State.ACTIVE:
		return PackedFloat32Array()
	if _kind[slot] == KitRules.Kind.SENTRY or _kind[slot] == KitRules.Kind.BREAKER:
		return PackedFloat32Array()
	return _columns(slot, _k[slot])


## The Bastion dome to draw: centre x, centre y, radius. Empty when none.
func dome_of(slot: int) -> PackedFloat32Array:
	if _state[slot] != State.ACTIVE or _kind[slot] != KitRules.Kind.SENTRY:
		return PackedFloat32Array()
	return PackedFloat32Array(
		[_origin_x[slot], _origin_y[slot], bastion_radius(_k[slot])]
	)


## The Backlash wall to draw: its centre y, or -1 when none is running.
func wall_of(slot: int) -> float:
	if _state[slot] != State.ACTIVE or _kind[slot] != KitRules.Kind.BREAKER:
		return -1.0
	return backlash_y(slot, _k[slot])


func wall_half_height() -> float:
	return rules.backlash_half_h


func half_width() -> float:
	return rules.sweep_half_w


func state_hash() -> int:
	var h := 1469598103934665603
	for slot: int in range(MAX_SLOTS):
		h = (h ^ _stock[slot]) * 1099511628211
		h = (h ^ _state[slot]) * 1099511628211
		h = (h ^ _k[slot]) * 1099511628211
		h = (h ^ _lockout[slot]) * 1099511628211
	return h
