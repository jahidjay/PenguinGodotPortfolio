class_name BulletRules
extends Resource
## Designer-owned tuning for the bullet pools.
##
## ADR-0001 Decision 7: "Data in .tres — every tuning value lives in a designer
## resource under data/; code and tests read it from there, no magic numbers."
## Implements the Tuning Knobs section of design/gdd/bullet-manager.md.
##
## Speeds and rates are authored in SECONDS (designer-facing). BulletField
## converts them to per-tick once on load, so the hot loop never multiplies by
## a delta (ADR-0001 Decision 5, fixed 60 Hz tick).

@export_group("Capacity")
## Bullet manager GDD F9: enemy pool cap, held on every platform including Web.
@export var enemy_cap := 2000
## Player shot pool cap.
@export var player_cap := 600

@export_group("Shapes")
## The fixed art-bible shape vocabulary (bullet-manager GDD Rule 3). The order
## is part of the replay format and the MultiMesh atlas layout: append only.
enum Shape { ORB, RICE, NEEDLE, RING }

## Hit radius per shape, in the Shape order (bullet-manager GDD F5 and its
## Tuning Knobs row: orb 2.5, rice 1.5, needle 1.25, ring 2.0). Deliberately
## smaller than the sprite, so a bullet that only looks like it touched does
## not kill. Floor 1.0.
@export var shape_hit_radii := PackedFloat32Array([2.5, 1.5, 1.25, 2.0])

@export_group("Collision")
## Fallback bullet radius for a shape with no entry in `shape_hit_radii`.
@export var hit_radius := 3.0
## Uniform grid cell size for the broad phase (GDD F11).
@export var cell_size := 32

@export_group("Lifetime")
## Pixels beyond the play area before a bullet is culled.
@export var offscreen_margin := 20.0
## Ticks before a bullet expires wherever it is (10 s at 60 Hz).
@export var lifetime_ticks := 600

@export_group("Behaviour: accelerate")
## Fraction of current speed gained per second.
@export var accel_rate_per_second := 1.6
## Speed ceiling in pixels per second.
@export var max_accel_speed := 330.0

@export_group("Behaviour: curve")
## Default turn rate in radians per second, used when a spawn request passes
## no per-bullet `param`. A radial-curve pattern passes its own `spin`
## (bullet-pattern-library F6e), clamped to +/- `max_curve_rate`.
@export var curve_rate_per_second := 1.8
## Clamp on a per-bullet curve rate (bullet-manager clamp quoted by Pattern
## library F6e: |spin| <= 3).
@export var max_curve_rate := 3.0

@export_group("Behaviour: warp")
## Seconds of flight before a Warp bullet freezes (bullet-manager F4 `T1`).
@export var warp_freeze_at := 0.7
## Seconds before it re-aims at its target slot (`T2`). Must exceed
## `warp_freeze_at`; the gap between them is the frozen window the player
## reads.
@export var warp_reaim_at := 1.1
## Speed it leaves at after re-aiming, px/s. Exact: `|v| == warp_speed`.
@export var warp_speed := 190.0

@export_group("Speed clamps")
## Slowest enemy bullet (bullet-manager Tuning Knobs: v_min 70).
@export var min_speed := 70.0
## Fastest enemy bullet (bullet-manager Tuning Knobs: v_cap_global 480).
@export var max_speed := 480.0
