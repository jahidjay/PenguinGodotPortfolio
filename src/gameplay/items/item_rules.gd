class_name ItemRules
extends Resource
## Every number the item field uses (design/gdd/powerups-and-drops.md Tuning
## Knobs). Code holds no gameplay literal: ADR-0001 Decision 7.

@export_group("Drop tables (Rule 6)")
## Percentage weights of a SMALL carrier's item. MEDAL takes what is left.
@export var small_pod_pct := 55
@export var small_chain_pct := 25
## Percentage weights of a MEDIUM carrier's item. MEDAL takes what is left.
@export var medium_pod_pct := 50
@export var medium_chain_pct := 20
## Non-pod results the team may see before the next item is forced to a POD
## (Rule 7). A death sets the counter straight to this.
@export var pity_limit := 2

@export_group("Caps (Rules 8, 11, 13, 14)")
## Drones one plane may hold. Must match [member KitRules.max_drones].
@export var max_drones := 4
## Lives one plane may hold (Rule 11's 1-up ceiling).
@export var max_lives := 6
## How much a CHAIN pickup adds, and it refills the chain window (Rule 25).
@export var chain_pickup_amount := 10
## The nth carrier of a stage that also drops a 1UP, and the second one for
## 3-or-more-player games. 0 disables.
@export var oneup_carrier_nth := 4
@export var oneup_second_nth := 9
## Gems kept per cancel, by stride sampling (F3).
@export var items_per_cancel_cap := 100
## Separate pools, so a bomb's gems can never push a pod off the field.
@export var gem_cap := 300
@export var drop_cap := 24

@export_group("Drop motion (F5)")
@export var pop_v0 := 1.0
@export var pop_ticks := 18
@export var drop_fall := 0.8
@export var rest_y := 616.0
@export var drop_lifetime := 600
@export var oneup_lifetime := 900
## The last ticks of a life, in which the item pulses (presentation only).
@export var pulse_ticks := 120
@export var bob_amp := 6.0
@export var bob_period := 90
@export var drop_inset := 10.0
## Px between the items of one drop, placed in a row (F6).
@export var row_spacing := 7.0

@export_group("Magnet and gems (Rules 16, 17)")
@export var magnet_radius := 36.0
@export var magnet_speed := 5.0
@export var gem_hold := 6
@export var gem_v0 := 3.0
@export var gem_accel := 0.25
@export var gem_vmax := 10.0
@export var gem_lifetime := 300
## Speed every surviving item flies at once the boss is down (Rule 18).
@export var sweep_speed := 10.0

@export_group("Pickup (F6)")
@export var pickup_radius := 14.0
## Item radii, indexed by [enum ItemField.Kind].
@export var item_radius: Array[float] = [8.0, 7.0, 7.0, 8.0, 4.0]
