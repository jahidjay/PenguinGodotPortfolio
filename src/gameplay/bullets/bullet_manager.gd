class_name BulletManager
extends Node2D
## Owns every enemy bullet.
## Data-oriented: bullets are rows in packed arrays, not nodes, so thousands
## stay cheap. Removal is swap-with-last, so order is not preserved.

enum Kind {
	NORMAL,     ## straight line
	ACCELERATE, ## speeds up to max_accel_speed
	WARP,       ## flies, freezes, then re-aims at target_position
	CURVE,      ## turns at `extra` radians/second
}

@export var play_area := Rect2(0, 0, 360, 640)

@export_group("Behaviour")
@export var accel_rate := 1.6
@export var max_accel_speed := 330.0
@export var warp_freeze_at := 0.7
@export var warp_reaim_at := 1.1
@export var warp_speed := 190.0
@export var lifetime := 10.0
@export var offscreen_margin := 20.0
## Collision radius of a bullet (added to the player's hitbox radius).
@export var hit_radius := 3.0

@export_group("Look")
@export var draw_radius := 3.5
@export var outline_radius := 5.0
@export var outline_color := Color(0.0, 0.0, 0.1)
## Enemy bullets are always cool colours with a dark outline (Visual Identity Anchor).
## One colour per Kind, in enum order.
@export var kind_colors: Array[Color] = [
	Color(0.4, 0.85, 1.0),
	Color(0.6, 0.6, 1.0),
	Color(1.0, 0.6, 1.0),
	Color(0.3, 1.0, 0.85),
]

## WARP bullets re-aim at this point (the player).
var target_position := Vector2.ZERO

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _kind := PackedInt32Array()
var _age := PackedFloat32Array()
## CURVE: spin in rad/s. WARP: stage (0 flying, 1 frozen, 2 re-aimed).
var _extra := PackedFloat32Array()


func spawn(at: Vector2, velocity: Vector2, kind: Kind = Kind.NORMAL, extra: float = 0.0) -> void:
	_pos.append(at)
	_vel.append(velocity)
	_kind.append(kind)
	_age.append(0.0)
	_extra.append(extra)


func count() -> int:
	return _pos.size()


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_kind.clear()
	_age.clear()
	_extra.clear()


func clear_radius(center: Vector2, radius: float) -> void:
	var r2 := radius * radius
	for i in range(_pos.size() - 1, -1, -1):
		if _pos[i].distance_squared_to(center) < r2:
			_remove_at(i)


## True if any bullet touches a circle at `point` with `radius`.
func overlaps(point: Vector2, radius: float) -> bool:
	var reach := radius + hit_radius
	var r2 := reach * reach
	for p in _pos:
		if p.distance_squared_to(point) < r2:
			return true
	return false


func _physics_process(delta: float) -> void:
	var bounds := play_area.grow(offscreen_margin)
	for i in range(_pos.size() - 1, -1, -1):
		_age[i] += delta
		var vel := _vel[i]
		match _kind[i]:
			Kind.ACCELERATE:
				vel = (vel * (1.0 + accel_rate * delta)).limit_length(max_accel_speed)
			Kind.WARP:
				if _extra[i] == 0.0 and _age[i] > warp_freeze_at:
					vel = Vector2.ZERO
					_extra[i] = 1.0
				elif _extra[i] == 1.0 and _age[i] > warp_reaim_at:
					vel = (target_position - _pos[i]).normalized() * warp_speed
					_extra[i] = 2.0
			Kind.CURVE:
				vel = vel.rotated(_extra[i] * delta)
		_vel[i] = vel
		_pos[i] += vel * delta
		if not bounds.has_point(_pos[i]) or _age[i] > lifetime:
			_remove_at(i)
	queue_redraw()


func _remove_at(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_kind[i] = _kind[last]
	_age[i] = _age[last]
	_extra[i] = _extra[last]
	_pos.resize(last)
	_vel.resize(last)
	_kind.resize(last)
	_age.resize(last)
	_extra.resize(last)


func _draw() -> void:
	for i in _pos.size():
		draw_circle(_pos[i], outline_radius, outline_color)
		draw_circle(_pos[i], draw_radius, kind_colors[_kind[i]])
