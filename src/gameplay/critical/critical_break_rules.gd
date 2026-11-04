class_name CriticalBreakRules
extends Resource
## Critical Break tuning (design/gdd/critical-break.md Tuning Knobs).
##
## The multiply itself lives in [ChainRules] (`cb_mult`, `cb_add`) because the
## chain owns the number; these are the windows that decide when a break is
## allowed to happen at all.

## Consecutive ticks of charge a slot needs before a break can arm. Both kits
## enter charge at hold tick 18, so an armed player has held Fire for at least
## half a second: a tap can never break the boss.
@export var charge_min_ticks := 12
## Ticks after the charge stops in which the slot is still counted as charging,
## so letting go of Fire and tapping Bomb still works.
@export var charge_lenience := 12
## Ticks since the last charge hit on the core that still counts.
@export var hit_window := 12
## Fraction of its full hp at or below which the boss enters Critical, 0-100.
@export var critical_hp_pct := 25
## Ticks the critical window is advertised for. The break stays legal while
## the core lives (Rule 21); this is only what the HUD counts down.
@export var critical_ticks := 420
