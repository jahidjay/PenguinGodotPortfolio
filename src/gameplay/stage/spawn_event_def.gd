class_name SpawnEventDef
extends Resource
## One group of enemies a wave sends (design/gdd/wave-and-stage-director.md).
##
## A wave is a list of these. Each one fires once, `at_tick` ticks after the
## wave starts, and puts `count` enemies on the field `stagger` ticks apart —
## which is how a trail, a V or a single heavy are all the same authored thing.

## Which enemy to send.
@export var enemy: EnemyDef
## Ticks after the wave starts that this group spawns.
@export var at_tick := 0
## How many to send.
@export var count := 1
## Ticks between them. 0 puts the whole group on the field at once.
@export var stagger := 12
## Where the first one enters, in canvas px. y below 0 enters from the top.
@export var origin := Vector2(180.0, -20.0)
## Offset added per extra member, px — the shape of the group.
@export var step := Vector2(0.0, 0.0)
## Mirror the path in x (one authored entry serves both sides).
@export var mirror := false
## Frozen intensity for every enemy in the group, 0-1 (Enemy Rule 4).
@export var intensity := 0.0
## Makes this group carriers, whatever its [EnemyDef] says
## (powerups-and-drops.md Rule 3: the WAVE decides what carries).
@export var carrier := false
## Forces exactly this item instead of rolling the drop table (Rule 7a),
## indexed by [enum ItemField.Kind]. -1 rolls as usual.
@export var drop_override := -1
