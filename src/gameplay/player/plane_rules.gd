class_name PlaneRules
extends Resource
## Designer-owned tuning shared by every player plane.
##
## ADR-0001 Decision 7: all tuning lives in a .tres under data/; code holds no
## magic numbers. Implements the Tuning Knobs section of
## design/gdd/player-plane.md and the invulnerability knobs of
## design/gdd/collision-damage-lives.md.
##
## Speeds are authored in pixels per SECOND (designer-facing). PlaneCore
## converts them to per-tick once on load, so the hot loop holds no delta
## (ADR-0001 Decision 5, fixed 60 Hz tick).
##
## Usage:
## [codeblock]
## var rules: PlaneRules = load("res://data/plane_rules.tres")
## var cores := PlaneCore.new(rules, play_area, event_log)
## [/codeblock]

@export_group("Movement")
## Normal speed. 210 px/s crosses the 360 px field in 1.71 s (player-plane GDD).
@export var move_speed := 210.0
## Focus speed, held while the focus/ability input is down.
@export var focus_speed := 105.0

@export_group("Bounds")
## Kept clear at the top for the HUD strip: 48 px for 1-2 players, 72 px for
## 3-4 (art bible 8.1.1). The director latches which applies per stage.
@export var hud_strip_1p := 48.0
@export var hud_strip_coop := 72.0
## Extra clearance below the HUD strip before the plane may fly.
@export var top_padding := 4.0
## How close to each edge the plane's centre may travel.
@export var edge_margin := 8.0
@export var bottom_margin := 12.0

@export_group("Hitbox")
## The plane's lethal radius. Drawn as a 6 px dot (art bible); 3 px of reach.
@export var hitbox_radius := 3.0

@export_group("Lifecycle")
## Fly-in from the bottom on spawn and respawn: 0.6 s (player-plane GDD).
@export var fly_in_ticks := 36
## Death hold before the respawn fly-in starts: 0.6 s.
@export var death_hold_ticks := 36
## Invulnerability granted on becoming Active again (collision GDD).
@export var respawn_invuln_ticks := 120
## Spawn height above the bottom edge where the fly-in begins.
@export var fly_in_from_below := 48.0
## Resting y of a freshly activated plane, measured up from the bottom.
@export var start_from_bottom := 70.0

@export_group("Lives")
@export var starting_lives := 3
## Lives one plane may hold, the ceiling a 1-up stops at
## (powerups-and-drops.md Rule 11).
@export var max_lives := 6
