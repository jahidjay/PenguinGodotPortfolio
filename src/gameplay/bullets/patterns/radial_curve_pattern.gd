class_name RadialCurvePattern
extends BulletPattern
## Fires outward from the boss center through the part, as CURVE bullets that
## alternate turning left / right each volley.

## Turn rate in radians/second.
@export var spin := 1.3


func _emit(ctx: PatternContext, state: Dictionary) -> void:
	var counter: int = state.counter
	var sign_ := 1.0 if counter % 2 == 0 else -1.0
	var out := (ctx.origin - ctx.center).angle()
	ctx.bullets.spawn(ctx.origin, Vector2.from_angle(out) * speed, BulletManager.Kind.CURVE, spin * sign_)
