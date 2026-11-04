class_name StageDef
extends Resource
## One stage: its waves, then its boss
## (design/gdd/wave-and-stage-director.md; the 5-waves-then-boss shape is the
## game concept's stage structure).

@export var label := "STAGE 1"
## The era this stage is set in, which decides the enemy and pattern language
## (Era shift 19 owns the ladder; this is the label).
@export var era := "1941"
@export var waves: Array[WaveDef] = []
## The boss, sent as one more enemy once the waves are clear. Boss parts and
## phases are Boss (14); until that lands this is a LARGE enemy with the
## boss's own patterns and hp.
@export var boss: EnemyDef
## Where the boss enters.
@export var boss_origin := Vector2(180.0, -40.0)
## Ticks between the last wave clearing and the boss arriving.
@export var boss_delay := 120
