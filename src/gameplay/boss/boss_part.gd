class_name BossPart
extends Node2D
## Runtime node for one BossPartDefinition: HP, hitbox, bullet patterns, placeholder drawing.
## Created by Boss.setup(); positioned by Boss every frame.

signal destroyed(part: BossPart)

enum HitResult { IGNORED, HIT, DESTROYED }

const COLOR_PART := Color(0.85, 0.55, 0.25)
const COLOR_WRECK := Color(0.22, 0.14, 0.12)
const COLOR_CORE := Color(0.85, 0.3, 0.3)
const COLOR_CORE_ARMORED := Color(0.5, 0.2, 0.22)
const COLOR_CORE_SHIELDED := Color(0.45, 0.45, 0.55)
const COLOR_CRITICAL := Color(1.0, 0.9, 0.3)
const COLOR_SHIELD_RING := Color(0.5, 0.8, 1.0, 0.6)
const COLOR_HP_BG := Color(0.2, 0.2, 0.25)
const COLOR_HP := Color(1.0, 0.7, 0.3)

var definition: BossPartDefinition
var boss: Boss
var hp := 0.0
var alive := true

var _pattern_states: Array[Dictionary] = []
var _ctx := PatternContext.new()


func setup(owner_boss: Boss, def: BossPartDefinition) -> void:
	boss = owner_boss
	definition = def
	hp = def.max_hp
	name = def.part_name.validate_node_name()
	for pattern in def.patterns:
		_pattern_states.append(pattern.new_state())


func is_core() -> bool:
	return definition.is_core


## Called by Boss each frame. time = boss elapsed seconds.
func update_placement(time: float) -> void:
	if definition.orbit_radius > 0.0:
		position = Vector2.from_angle(definition.orbit_phase + time * definition.orbit_speed) * definition.orbit_radius
	else:
		position = definition.offset


func _physics_process(delta: float) -> void:
	if not alive or boss.is_defeated or boss.target == null:
		return
	_ctx.origin = global_position
	_ctx.center = boss.global_position
	_ctx.target = boss.target.global_position
	_ctx.rage = boss.rage()
	_ctx.bullets = boss.bullets
	for i in definition.patterns.size():
		definition.patterns[i].update(_ctx, _pattern_states[i], delta)
	queue_redraw()


## Applies damage and returns what happened (the attacker uses it for chain/score).
func apply_damage(amount: float) -> HitResult:
	if not alive:
		return HitResult.IGNORED
	if definition.is_core:
		if boss.is_core_shielded():
			return HitResult.IGNORED
		# The core never dies to normal damage: it must be finished by a Critical Break.
		hp = maxf(hp - amount * boss.core_damage_mult(), 1.0)
		return HitResult.HIT
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		alive = false
		queue_redraw()
		destroyed.emit(self)
		return HitResult.DESTROYED
	return HitResult.HIT


## Instant kill of the core, used by the Critical Break.
func finish() -> void:
	hp = 0.0
	alive = false
	queue_redraw()


func contains(world_point: Vector2, margin: float) -> bool:
	var local := world_point - global_position
	if definition.shape == BossPartDefinition.Shape.CIRCLE:
		return local.length() < definition.size.x + margin
	return Rect2(-definition.size * 0.5, definition.size).grow(margin).has_point(local)


func half_width() -> float:
	if definition.shape == BossPartDefinition.Shape.CIRCLE:
		return definition.size.x
	return definition.size.x * 0.5


## Lowest world Y of the hitbox (where a laser from below hits it).
func bottom_y() -> float:
	if definition.shape == BossPartDefinition.Shape.CIRCLE:
		return global_position.y + definition.size.x
	return global_position.y + definition.size.y * 0.5


func _draw() -> void:
	if not alive:
		if not definition.is_core:
			_draw_shape(COLOR_WRECK)
		return
	_draw_shape(_body_color())
	if definition.is_core and boss.is_core_shielded():
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 32, COLOR_SHIELD_RING, 2.0)
	if not definition.is_core:
		var ratio := hp / definition.max_hp
		draw_rect(Rect2(-14, -24, 28, 3), COLOR_HP_BG)
		draw_rect(Rect2(-14, -24, 28.0 * ratio, 3), COLOR_HP)


func _body_color() -> Color:
	if not definition.is_core:
		return COLOR_PART
	if boss.is_critical() and int(boss.elapsed * 8.0) % 2 == 0:
		return COLOR_CRITICAL
	if boss.is_core_shielded():
		return COLOR_CORE_SHIELDED
	if boss.is_core_armored():
		return COLOR_CORE_ARMORED
	return COLOR_CORE


func _draw_shape(color: Color) -> void:
	if definition.shape == BossPartDefinition.Shape.CIRCLE:
		draw_circle(Vector2.ZERO, definition.size.x, color)
	else:
		draw_rect(Rect2(-definition.size * 0.5, definition.size), color)
