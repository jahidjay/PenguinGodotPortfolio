class_name SpiralPattern
extends BulletPattern
## Rotating stream: each volley turns by `step` radians.

@export var arms := 1
## Radians added per volley.
@export var step := 0.33
## Fixed rotation added to every arm (use PI for an opposite arm).
@export var angle_offset := 0.0


func _emit(ctx: PatternContext, state: Dictionary) -> void:
	state.angle += step
	var a: float = state.angle
	for i in arms:
		_shoot(ctx, a + angle_offset + TAU * i / arms)
