class_name ShotWeapon
extends Node2D
## The plane's normal twin shot. Shots are data rows (no nodes) in world space,
## so this node is top_level and does not move with the player.

const SHOT_SIZE := Vector2(4, 12)
const SHOT_COLOR := Color(1.0, 0.8, 0.2)   ## player shots are warm (Visual Identity Anchor)
const HIT_MARGIN := 2.0

var player: Player
var is_firing := false

var _shots := PackedVector2Array()
var _cooldown := 0.0


func setup(owner_player: Player) -> void:
	player = owner_player
	top_level = true
	global_position = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var cfg := player.config
	is_firing = not player.is_dead and player.is_action_held("fire") and not player.laser.active
	_cooldown -= delta
	if is_firing and _cooldown <= 0.0:
		_cooldown = cfg.fire_interval
		_shots.append(player.global_position + Vector2(-cfg.shot_offset, -10))
		_shots.append(player.global_position + Vector2(cfg.shot_offset, -10))

	var step := Vector2(0, -cfg.shot_speed * delta)
	for i in range(_shots.size() - 1, -1, -1):
		_shots[i] += step
		var p := _shots[i]
		if p.y < -10.0:
			_remove_at(i)
			continue
		var part := player.boss.find_part_at(p, HIT_MARGIN)
		if part != null:
			_remove_at(i)
			player.register_hit(part.apply_damage(cfg.shot_damage), true)
	queue_redraw()


func _remove_at(i: int) -> void:
	var last := _shots.size() - 1
	_shots[i] = _shots[last]
	_shots.resize(last)


func _draw() -> void:
	for p in _shots:
		draw_rect(Rect2(p - SHOT_SIZE * 0.5, SHOT_SIZE), SHOT_COLOR)
