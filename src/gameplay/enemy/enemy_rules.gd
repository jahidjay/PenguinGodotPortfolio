class_name EnemyRules
extends Resource
## Enemy tuning that is not per-enemy (design/gdd/enemy-and-ai.md Rules 8, 18).

@export_group("Firing")
## A gun arms when its MUZZLE is this far inside the play field, not when the
## body first touches the edge (Rule 18). Without it a bomber shoots from
## above the top of the screen and the bullets appear from nowhere.
@export var fire_inset := 4.0

@export_group("Spawning")
## Enemies alive at once before a spawn is refused (Rule 8.1).
@export var max_alive := 64
## How far past the field edge an enemy must travel before it is retired, px.
@export var retire_margin := 24.0
