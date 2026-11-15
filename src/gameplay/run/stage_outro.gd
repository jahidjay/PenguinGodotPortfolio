class_name StageOutro
extends Resource
## How a stage ends once the boss is down: the boss combo is called out in big
## text, then every plane climbs away and shrinks past the horizon.
##
## Presentation only. The simulation is already frozen in STAGE_CLEAR when this
## runs, so nothing here can change a score or a replay. Times are seconds
## since the stage was cleared; the run scene feeds it real frame time.
##
## Usage:
## [codeblock]
## var outro: StageOutro = load("res://data/stages/stage_outro.tres")
## var lift := outro.plane_lift(t)      # px the plane has climbed
## var scale := outro.plane_scale(t)    # 1 -> horizon_scale
## if outro.is_done(t): leave the stage
## [/codeblock]

## Seconds before the STAGE CLEAR / boss combo text appears.
@export var text_delay := 0.4
## Seconds the planes hold position under the text before they climb.
@export var climb_delay := 2.2
## Climb acceleration, px/s^2. The planes start slow and leave fast.
@export var climb_accel := 520.0
## Seconds the climb takes to shrink a plane to `horizon_scale`.
@export var shrink_seconds := 1.6
## How small a plane is when it reaches the horizon.
@export var horizon_scale := 0.3
## Seconds after the clear at which the stage is over and the game moves on.
@export var end_at := 6.0


func shows_text(t: float) -> bool:
	return t >= text_delay


## Px the plane has climbed above where it was when the boss died.
func plane_lift(t: float) -> float:
	var c := maxf(0.0, t - climb_delay)
	return 0.5 * climb_accel * c * c


## Draw scale: 1 until the climb starts, then down to `horizon_scale`.
func plane_scale(t: float) -> float:
	var c := maxf(0.0, t - climb_delay)
	var k := clampf(c / maxf(0.01, shrink_seconds), 0.0, 1.0)
	return lerpf(1.0, horizon_scale, k * k * (3.0 - 2.0 * k))


func is_done(t: float) -> bool:
	return t >= end_at
