class_name WaveDef
extends Resource
## One wave of a stage (design/gdd/wave-and-stage-director.md).
##
## A wave ends when every enemy it sent has been shot down AND its `min_ticks`
## have passed. There is no timeout: an enemy that leaves the field comes back
## from its spawn point, angrier if its squad has been thinned out.

## Shown in the debug readout and the wave banner.
@export var label := "WAVE"
@export var events: Array[SpawnEventDef] = []
## Shortest the wave may last, ticks. Keeps the pacing from collapsing when
## the players clear it instantly.
@export var min_ticks := 240
