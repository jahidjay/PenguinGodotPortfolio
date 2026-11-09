class_name PlatformDef
extends Resource
## Designer data for a [PatternPlatform]: where the stand-in gun platform sits,
## how it moves, and which authored patterns each of its guns fires.
##
## SCAFFOLDING, but authored scaffolding: it exists so the run scene's content
## lives in `data/run/*.tres` like every other gameplay value, instead of as
## constants in a script. Enemy (10) and Boss (14) replace it with their own
## resources; the [PatternDef]s it points at are the real ones and carry over.

## Where the platform sits before swaying, in canvas px.
@export var anchor := Vector2(180.0, 110.0)
## How far it sways either side of `anchor`, px. 0 holds still.
@export var sway_x := 96.0
## Ticks for one full sway, out and back.
@export var sway_period := 420
## Ticks the intensity ramp takes to reach 1.0, which is what opens the
## intensity-gated patterns (GDD Rule 6). In the real game the driver is the
## owner's: parts destroyed for a boss, wave progress for a wave.
@export var ramp_ticks := 1500
## The guns, in firing order (GDD "Pool and order": registration order).
@export var guns: Array[PlatformGun] = []
