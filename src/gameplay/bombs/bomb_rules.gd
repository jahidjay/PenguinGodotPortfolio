class_name BombRules
extends Resource
## Bomb tuning (design/gdd/bombs.md Tuning Knobs; decided 2026-11-03).

@export_group("Stock (Rule 3)")
## Bombs a slot starts a life with, and is reset to on death.
@export var bomb_start := 3
## Floor topped up at each stage start.
@export var stage_floor := 3
## Hard cap.
@export var bomb_max := 5

@export_group("The press (Rules 4-6)")
## Invulnerability granted from the accept tick.
@export var invuln_ticks := 90
## Ticks before the slot can bomb again. Equal to the invulnerability, so the
## next bomb is possible exactly when the last one stops protecting.
@export var lockout_ticks := 90
## Percent of the chain count a bomb costs. The price of the panic button:
## at chain 12 it is nothing, at chain 600 it hurts.
@export var chain_toll_pct := 50

@export_group("Lancer sweep (Rules 19-22)")
## Ticks the column holds where it was cast before splitting.
@export var hold_ticks := 24
## Half-width of a column, px.
@export var sweep_half_w := 28.0
## Px each column travels per tick once it splits.
@export var sweep_speed := 8.0
## Damage dealt to everything a column overlaps, every `damage_interval`.
@export var lancer_damage := 100
@export var damage_interval := 4
## Most damage one bomb may deal to one target.
@export var per_target_cap := 1000

@export_group("Sentry: Bastion (GDD 29 Rule 31)")
## A world-anchored dome that grows, cancels every tick and pounds what is
## inside it. Radius goes r0 -> r_max at `grow` px per tick.
@export var bastion_r0 := 40.0
@export var bastion_grow := 4.0
@export var bastion_r_max := 104.0
@export var bastion_ticks := 72
@export var bastion_interval := 6
@export var bastion_damage := 60
## How far above the plane the dome is centred, px.
@export var bastion_rise := 56.0

@export_group("Breaker: Backlash (GDD 29 Rule 32)")
## A full-width wall that climbs from the plane to the top of the field and
## hits everything it passes once, hard.
@export var backlash_half_h := 12.0
@export var backlash_speed := 12.0
@export var backlash_damage := 500

@export_group("Leech hooks (Rules 23-27)")
## Hooks sent out, independent of how many drones the plane has.
@export var hook_count := 4
## Px a hook travels per tick.
@export var hook_speed := 16.0
## Ticks a hook clings before it bursts.
@export var cling_ticks := 18
## Damage of the burst.
@export var hook_damage := 250
## Radius the burst cancels bullets in, px.
@export var burst_radius := 48.0
