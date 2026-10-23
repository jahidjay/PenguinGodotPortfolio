class_name RingPattern
extends BulletPattern
## Evenly spaced ring of bullets in all directions.

@export var count := 12
## Random rotation each volley so rings don't line up.
@export var random_offset := true


func _emit(ctx: PatternContext, _state: Dictionary) -> void:
	var offset := randf() * TAU if random_offset else 0.0
	for i in count:
		_shoot(ctx, offset + TAU * i / count)
