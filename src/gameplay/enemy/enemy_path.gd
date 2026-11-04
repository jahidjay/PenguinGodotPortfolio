class_name EnemyPath
extends Object
## The F1 path functions as pure static functions
## (design/gdd/enemy-and-ai.md Rule 6, F1).
##
## `offset(def, age)` is the whole of an enemy's movement: it takes the integer
## age in ticks and returns the offset from the spawn origin. No state, no
## `delta`, no player reads — so a wave plays the same way every run, and a
## replay of it is exact.
##
## Static, not a method on [EnemyPathDef], so the Wave director's authoring
## lint can measure a path without instantiating an enemy.

const TICKS_PER_SECOND := 60.0


## Offset from the spawn origin at `age` ticks (age 0 on the spawn tick).
static func offset(def: EnemyPathDef, age: int) -> Vector2:
	match def.kind:
		EnemyPathDef.Kind.SINE:
			return _sine(def, age)
		EnemyPathDef.Kind.ENTER_HOVER_EXIT:
			return _enter_hover_exit(def, age)
		_:
			return def.velocity * (float(age) / TICKS_PER_SECOND)


## A steady descent with a lateral swing. The swing comes from the shipped
## trig table, so it is identical on desktop and on the Web build.
static func _sine(def: EnemyPathDef, age: int) -> Vector2:
	var period := maxi(1, def.period)
	var turns := SimMath.rad_to_bam(def.phase * TAU)
	var angle := turns + (age * SimMath.TURN) / period
	return Vector2(
		SimMath.sin_bam(angle) * def.amplitude,
		def.descent * (float(age) / TICKS_PER_SECOND)
	)


## Ease in, hold (with an optional drift), then accelerate away. The ease is a
## smoothstep on the integer age, so it never overshoots the hover point.
static func _enter_hover_exit(def: EnemyPathDef, age: int) -> Vector2:
	var enter := maxi(1, def.enter_ticks)
	if age < enter:
		var t := float(age) / float(enter)
		var eased := t * t * (3.0 - 2.0 * t)
		return def.hover_offset * eased

	var held := age - enter
	var drift := Vector2.ZERO
	if def.drift_amplitude != 0.0:
		var period := maxi(1, def.drift_period)
		var angle := (held * SimMath.TURN) / period
		drift.x = SimMath.sin_bam(angle) * def.drift_amplitude

	if held < def.hover_ticks:
		return def.hover_offset + drift

	# Leaving: the drift is frozen at the value it had on the last hover tick,
	# so the exit starts from exactly where the enemy was.
	var leaving := held - def.hover_ticks
	return def.hover_offset + drift + def.exit_velocity * (float(leaving) / TICKS_PER_SECOND)


## Ticks after which the path never returns to the field, or -1 if it may
## hover forever. Used by the wave authoring lint, not at runtime.
static func lifetime_hint(def: EnemyPathDef) -> int:
	if def.kind == EnemyPathDef.Kind.ENTER_HOVER_EXIT:
		return maxi(1, def.enter_ticks) + def.hover_ticks + 600
	return -1
