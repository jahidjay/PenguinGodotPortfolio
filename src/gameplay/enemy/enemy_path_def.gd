class_name EnemyPathDef
extends Resource
## One authored flight path (design/gdd/enemy-and-ai.md Rule 6, F1).
##
## A path is a PURE FUNCTION of the enemy's integer age:
## `position = origin + path(age)`. It never reads where the players are
## (Rule 4), which is what makes a wave learnable and a replay reproducible.
##
## Angles and curves go through [SimMath], so the path is the same on every
## platform (ADR-0003 D3).

## The MVP path types. Append only: the order is part of the replay format.
enum Kind {
	STRAIGHT,            ## constant velocity
	SINE,                ## steady descent with a lateral sine wave
	ENTER_HOVER_EXIT,    ## ease in to a hover point, hold, accelerate away
}

@export var kind := Kind.STRAIGHT

@export_group("Straight")
## Velocity in px per second. Converted to per-tick once, at load.
@export var velocity := Vector2(0.0, 90.0)

@export_group("Sine")
## Descent speed, px/s.
@export var descent := 90.0
## Lateral swing either side of the origin, px.
@export var amplitude := 60.0
## Ticks for one full swing.
@export var period := 180
## Where in the swing the enemy starts, 0-1 of a period.
@export var phase := 0.0

@export_group("Enter, hover, exit")
## Where it hovers, as an offset from its origin, px.
@export var hover_offset := Vector2(0.0, 160.0)
## Ticks to ease in to the hover point.
@export var enter_ticks := 60
## Ticks it holds there.
@export var hover_ticks := 180
## Lateral drift while hovering, px.
@export var drift_amplitude := 24.0
## Ticks for one full drift swing.
@export var drift_period := 120
## Velocity it leaves at, px/s.
@export var exit_velocity := Vector2(0.0, 220.0)
