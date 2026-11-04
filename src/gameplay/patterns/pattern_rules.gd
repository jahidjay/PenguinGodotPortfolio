class_name PatternRules
extends Resource
## Library-wide tuning for the bullet pattern library
## (design/gdd/bullet-pattern-library.md, Tuning Knobs: "Global library rules").
##
## Per-pattern values live on each [PatternDef]; these are the rules that apply
## to every pattern, including the fairness constants the validator
## ([PatternMetrics]) measures against. Code and tests read them from
## `data/pattern_rules.tres` — never as literals (ADR-0001 Decision 7).
##
## The validator constants are in here rather than in the test so a designer can
## retune fairness in one place and see every pattern re-checked.

@export_group("Spawn safety (F7)")
## A bullet spawning within this radius of an Active player is skipped, so no
## bullet can appear on top of someone with no time to react. A pattern may
## raise it (never lower it) for a faster bullet. Safe range 24-96.
@export var spawn_safe_radius := 42.0
## Reaction allowance in ticks: 6 to see and press, 3 to move clear.
## Used by the F7 authoring check, not at runtime. Safe range 6-15.
@export var react_ticks := 9

@export_group("Fairness validator (F8)")
## Minimum clear lane: 2x the player hitbox plus 4 px either side.
@export var lane_min_clear := 14.0
## Distance at which an aimed fan's lane is measured. Safe range 100-240.
@export var d_ref := 160.0
## Distance at which ring lanes are measured. Safe range 80-200.
@export var lane_measure_distance := 120.0
## A wall corridor below this is a warning (below `lane_min_clear` is an error).
@export var wall_corridor_warn := 20.0
## Screen-edge margin a wall's gap must stay inside. Safe range 0-24.
@export var wall_edge_margin := 8.0
## Reaction allowance used by the wall-reach check, in ticks.
@export var validator_react_ticks := 18
## Walls above this speed cannot be dodged by crossing to the gap, px/s.
@export var wall_speed_max := 205.0
## Player hitbox radius (registry; owned by Player plane (5)). Validator input.
@export var player_hitbox_radius := 3.0
## Player top speed in px per tick, for the wall-reach check (210 px/s / 60).
@export var player_speed_per_tick := 3.5

@export_group("Density budget (F9)")
## One runner above this many live bullets is a warning. Safe range 300-800.
@export var runner_density_warn := 450.0
## All co-active runners above this is an error. 85% of the Bullet manager's
## 2,000-bullet enemy pool; the budget itself is owned by Bullet manager (3).
@export var scene_density_budget := 1700.0
## Path length estimate for patterns that cross the screen (aimed, wall,
## spray, curve), in px.
@export var path_length_crossing := 640.0
## Path length estimate for patterns that spread from a point (ring, spiral,
## flak), in px.
@export var path_length_radial := 320.0
## Effective speed F9 credits a Warp bullet with, px/s. It is an estimate, not
## a speed the bullet ever has: a Warp bullet flies, stops for 0.4 s and then
## leaves at `warp_speed`, so it occupies the field far longer than its speed
## suggests (F9, Open Question 2 — confirm against the profiler counters).
@export var warp_effective_speed := 66.0

@export_group("Flak (F6f)")
## A flak burst point is clamped this far inside the screen edges.
## Safe range 8-24.
@export var flak_clamp_inset := 12.0
## Lit fuses allowed at once across the WHOLE scene, all emitters together
## (decided 2026-11-03, wave 4). A volley that would light one more is skipped
## but still counts as fired and still makes its random draws.
@export var flak_fuse_max := 8

@export_group("Play area")
## Top of the play area for 1-2 players, in canvas px.
@export var play_top_solo := 48.0
## Top of the play area for 3-4 players, in canvas px.
@export var play_top_coop := 72.0
## Canvas width. The 360x640 retune (F10) is baked into the authored data;
## there is no runtime scale factor.
@export var canvas_width := 360.0
## Canvas height.
@export var canvas_height := 640.0
