class_name WaveDef
extends Resource
## One wave of a stage (design/gdd/wave-and-stage-director.md).
##
## A wave ends when every enemy it sent is gone AND its `min_ticks` have
## passed, or when `max_ticks` runs out — so a player who kills fast moves on
## fast, and a wave can never hang on one enemy that refuses to leave.

## Shown in the debug readout and the wave banner.
@export var label := "WAVE"
@export var events: Array[SpawnEventDef] = []
## Shortest the wave may last, ticks. Keeps the pacing from collapsing when
## the players clear it instantly.
@export var min_ticks := 240
## Longest the wave may last before the director moves on regardless, ticks.
@export var max_ticks := 1800
