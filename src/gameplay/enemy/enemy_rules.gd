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

@export_group("Respawn")
## An enemy that leaves the field (or outlives `max_life_ticks`) flies its path
## again from its spawn point, keeping the damage it took. A wave only ends
## when every enemy in it is shot down, so nothing can slip past.
## Off = the enemy is retired as "escaped" instead.
@export var respawn_on_escape := true

@export_group("Squad aggression")
## When half or more of a squad (one spawn group of 2+) is shot down, the
## survivors fly this much faster...
@export var half_squad_speed := 1.25
## ...and fire at this much more intensity (added, clamped to 1).
@export var half_squad_intensity := 0.35
## The last survivor of a squad flies this much faster...
@export var alone_speed := 1.5
## ...and fires at this much more intensity (added, clamped to 1).
@export var alone_intensity := 0.7
