class_name WallPattern
extends BulletPattern
## Horizontal line of bullets moving in `direction`, with one random gap to slip through.

@export var count := 9
@export var spacing := 16.0
@export var direction := Vector2.DOWN
@export var random_gap := true


func _emit(ctx: PatternContext, _state: Dictionary) -> void:
	var gap := randi() % count if random_gap else -1
	var start_x := ctx.origin.x - spacing * (count - 1) * 0.5
	var vel := direction.normalized() * speed
	for i in count:
		if i == gap:
			continue
		ctx.bullets.spawn(Vector2(start_x + i * spacing, ctx.origin.y), vel, bullet_kind)
