class_name Boss
extends Node2D
## A boss built from a BossDefinition: moves, owns its BossParts, and answers
## combat queries (what did this shot hit, what does the laser touch).
## Implements: design/gdd/game-concept.md §3 (5-Minute Loop: boss chain, Critical Break).
##
## Usage:
##   var boss := Boss.new()
##   boss.setup(definition, rules, bullet_manager, player)
##   layer.add_child(boss)

signal defeated
signal part_destroyed(part: BossPart)

const HULL_COLOR := Color(0.18, 0.18, 0.22)

var definition: BossDefinition
var rules: CombatRules
var bullets: BulletManager
## Aimed patterns shoot at this node.
var target: Node2D
var core: BossPart
var parts: Array[BossPart] = []   ## includes the core (first)
var elapsed := 0.0
var is_defeated := false

var _others_total := 0


func setup(def: BossDefinition, combat_rules: CombatRules, bullet_manager: BulletManager, aim_target: Node2D) -> void:
	definition = def
	rules = combat_rules
	bullets = bullet_manager
	target = aim_target
	# Core first so it is drawn under the other parts.
	for part_def in def.parts:
		if part_def.is_core:
			core = _add_part(part_def)
	for part_def in def.parts:
		if not part_def.is_core:
			_add_part(part_def)
			_others_total += 1
	assert(core != null, "BossDefinition '%s' needs one part with is_core = true" % def.display_name)
	_update_motion(0.0)


func _add_part(part_def: BossPartDefinition) -> BossPart:
	var part := BossPart.new()
	part.setup(self, part_def)
	part.destroyed.connect(_on_part_destroyed)
	add_child(part, true)
	parts.append(part)
	return part


func _physics_process(delta: float) -> void:
	if is_defeated:
		return
	_update_motion(delta)


func _update_motion(delta: float) -> void:
	elapsed += delta
	var d := definition
	position = d.anchor + Vector2(
		sin(elapsed * d.sway_frequency.x) * d.sway_amplitude.x,
		sin(elapsed * d.sway_frequency.y) * d.sway_amplitude.y)
	for part in parts:
		part.update_placement(elapsed)


# ---------- state queries ----------

func others_alive() -> int:
	var n := 0
	for part in parts:
		if part.alive and not part.is_core():
			n += 1
	return n


## 0..1: fraction of non-core parts destroyed. Patterns escalate with rage.
func rage() -> float:
	if _others_total == 0:
		return 1.0
	return 1.0 - float(others_alive()) / _others_total


func is_core_shielded() -> bool:
	return definition.core_rule == BossDefinition.CoreRule.SHIELDED and others_alive() > 0


func is_core_armored() -> bool:
	return definition.core_rule == BossDefinition.CoreRule.ARMORED and others_alive() > 0


func core_damage_mult() -> float:
	return definition.armor_damage_mult if is_core_armored() else 1.0


func is_critical() -> bool:
	return not is_defeated and core.hp <= definition.critical_hp


# ---------- combat queries ----------

## Topmost living part whose hitbox contains world_point (or null).
func find_part_at(world_point: Vector2, margin: float) -> BossPart:
	if is_defeated:
		return null
	for i in range(parts.size() - 1, -1, -1):
		var part := parts[i]
		if part.alive and part.contains(world_point, margin):
			return part
	return null


## Closest living part above `from` within the beam's column (or null).
func find_laser_target(from: Vector2, beam_half_width: float) -> BossPart:
	if is_defeated:
		return null
	var best: BossPart = null
	var best_y := -INF
	for part in parts:
		if not part.alive or part.global_position.y >= from.y:
			continue
		if absf(part.global_position.x - from.x) >= part.half_width() + beam_half_width:
			continue
		var bottom := part.bottom_y()
		if bottom > best_y:
			best_y = bottom
			best = part
	return best


## Bomb damage to every living part. Returns one HitResult per part touched.
func apply_bomb(damage: float) -> Array[int]:
	var results: Array[int] = []
	for part in parts.duplicate():
		if part.alive:
			var dmg := damage if part.is_core() else damage * rules.bomb_part_mult
			results.append(part.apply_damage(dmg))
	return results


## Finishes the boss. Caller (Player) has already checked is_critical().
func critical_break() -> void:
	core.finish()
	is_defeated = true
	defeated.emit()


func _on_part_destroyed(part: BossPart) -> void:
	bullets.clear_radius(part.global_position, rules.part_kill_cancel_radius)
	var text := "CORE EXPOSED!" if others_alive() == 0 else "%s DOWN" % part.definition.part_name.to_upper()
	GameEvents.popup_requested.emit(part.global_position, text)
	GameEvents.screen_flash_requested.emit(0.12)
	part_destroyed.emit(part)


func _draw() -> void:
	match definition.hull:
		BossDefinition.Hull.WING_BAR:
			draw_rect(Rect2(-90, 0, 180, 18), HULL_COLOR)
		BossDefinition.Hull.DELTA:
			draw_colored_polygon(PackedVector2Array([Vector2(0, 40), Vector2(-95, -20), Vector2(95, -20)]), HULL_COLOR)
		BossDefinition.Hull.RING:
			draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 48, HULL_COLOR, 3.0)
