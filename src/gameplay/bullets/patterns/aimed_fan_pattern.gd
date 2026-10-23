class_name AimedFanPattern
extends BulletPattern
## Fan of bullets centred on the target. count = 1 gives a single aimed shot
## (combine with burst_count for an aimed stream).

@export var count := 3
## Count at rage 1.0. Negative = no rage scaling.
@export var count_at_full_rage := -1
## Radians between neighbouring bullets.
@export var spread := 0.25


func _emit(ctx: PatternContext, _state: Dictionary) -> void:
	var n := count
	if count_at_full_rage >= 0:
		n = roundi(lerpf(count, count_at_full_rage, ctx.rage))
	var base := ctx.aim_angle()
	for i in n:
		_shoot(ctx, base + (i - (n - 1) * 0.5) * spread)
