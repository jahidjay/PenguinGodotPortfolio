class_name BulletPattern
extends Resource
## Base class for boss bullet patterns. Subclasses override _emit().
##
## Patterns are shared data. Per-part runtime state (cooldown, burst, counter,
## angle) lives in a Dictionary from new_state(), owned by the firing BossPart.
##
## Rage (0..1 = fraction of the boss's non-core parts destroyed) can:
##   - gate a pattern on/off  (min_rage / max_rage)
##   - speed it up            (interval -> interval_at_full_rage)
##
## Usage (inside BossPart):
##   var state := pattern.new_state()
##   pattern.update(ctx, state, delta)   # every physics frame

@export_group("Timing")
## Seconds between volleys (or between bursts when burst_count > 1).
@export var interval := 1.0
## Interval at rage 1.0. Negative = no rage scaling.
@export var interval_at_full_rage := -1.0
## Delay before the first volley after the pattern becomes active.
@export var start_delay := 0.8
## Volleys per burst.
@export var burst_count := 1
## Seconds between volleys inside a burst.
@export var burst_gap := 0.1

@export_group("Activation")
## Pattern only fires while rage is within [min_rage, max_rage].
@export_range(0.0, 1.0) var min_rage := 0.0
@export_range(0.0, 1.0) var max_rage := 1.0

@export_group("Bullets")
@export var speed := 150.0
@export var bullet_kind: BulletManager.Kind = BulletManager.Kind.NORMAL


func new_state() -> Dictionary:
	return {"cooldown": start_delay, "burst": 0, "counter": 0, "angle": 0.0}


func is_active(rage: float) -> bool:
	return rage >= min_rage and rage <= max_rage


func current_interval(rage: float) -> float:
	if interval_at_full_rage < 0.0:
		return interval
	return lerpf(interval, interval_at_full_rage, rage)


func update(ctx: PatternContext, state: Dictionary, delta: float) -> void:
	if not is_active(ctx.rage):
		return
	state.cooldown -= delta
	if state.cooldown > 0.0:
		return
	_emit(ctx, state)
	state.counter += 1
	state.burst += 1
	if state.burst < burst_count:
		state.cooldown = burst_gap
	else:
		state.burst = 0
		state.cooldown = current_interval(ctx.rage)


## Override: spawn one volley through ctx.bullets.
func _emit(_ctx: PatternContext, _state: Dictionary) -> void:
	pass


func _shoot(ctx: PatternContext, angle: float, extra: float = 0.0) -> void:
	ctx.bullets.spawn(ctx.origin, Vector2.from_angle(angle) * speed, bullet_kind, extra)
