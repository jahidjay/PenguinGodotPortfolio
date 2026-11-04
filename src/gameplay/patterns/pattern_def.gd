class_name PatternDef
extends Resource
## One kind of volley: its geometry, its timing and the bullets it asks for
## (design/gdd/bullet-pattern-library.md Rule 1).
##
## READ-ONLY AT RUNTIME. A pattern holds no runtime state, so many emitters can
## share one resource and none of them can disturb another (Rules 1 and 3,
## AC-01). All runtime state lives in a [PatternRunner].
##
## Timing is authored directly in whole 60 Hz ticks (F1); only the one-time
## 360 px migration converted seconds. Angles are authored in RADIANS for the
## designer and converted to [SimMath] binary angle units once, when a runner
## is built (ADR-0003: no `sin`/`atan2` inside the simulation).
##
## Usage:
## [codeblock]
## var fan := load("res://data/patterns/fortress_turret_fan.tres") as PatternDef
## var emitter := scene.add_emitter(&"fortress_turret", 0, [fan], world_tick)
## [/codeblock]

## The MVP catalogue (GDD "Pattern catalogue"). Append only: the order is part
## of the replay format.
enum Kind {
	AIMED_FAN,     ## `count` bullets centred on the aim, `spread` apart
	RING,          ## `count` bullets evenly round a full turn
	SPIRAL,        ## `arms` per volley, the angle turning `step` each volley
	WALL,          ## a line of slots with one gap, moving in `direction`
	RADIAL_CURVE,  ## outward through the origin, curving, spin alternating
	FLAK_BURST,    ## a fuse, then a small ring out along the aim
	SPRAY,         ## evenly spaced within an arc, with bounded jitter
}

## How a ring picks its rotation.
enum OffsetMode {
	FIXED,   ## always `fixed_offset_rad` — fully learnable
	SEEDED,  ## a seeded fraction of ONE gap, so the answer stays visible
}

@export_group("Identity")
## Stable authored id. Used in debug output and validator reports.
@export var id := &""

## Which geometry this pattern fires.
@export var kind := Kind.AIMED_FAN

@export_group("Timing (ticks, F1/F2)")
## Ticks from activation to the first volley. Minimum 1: a pattern never fires
## on the tick it activates (Rule 7).
@export var start_delay := 48
## Ticks from the start of one burst to the start of the next. Minimum 1.
@export var interval := 84
## `interval` at intensity 1. -1 means no scaling (F3).
@export var interval_at_full := -1
## Volleys in one burst. Minimum 1.
@export var burst_count := 1
## Ticks between volleys inside a burst. Minimum 1.
@export var burst_gap := 6

@export_group("Intensity gate (F3)")
## Lowest intensity at which this pattern fires. Inclusive.
@export var min_intensity := 0.0
## Highest intensity at which this pattern fires. Inclusive.
@export var max_intensity := 1.0

@export_group("Count (F3)")
## Bullets per volley (slots, for a wall). Minimum 1.
@export var count := 1
## `count` at intensity 1. -1 means no scaling.
@export var count_at_full := -1

@export_group("Bullets")
## Speed in px/s, clamped by the Bullet manager to 70-480.
@export var speed := 150.0
## Shape index into [enum BulletRules.Shape] (orb, rice, needle, ring).
@export var shape := 0
## Behaviour index into [enum BulletField.Beh] (linear, accel, curve).
@export var behaviour := 0
## Behaviour parameter: the signed turn rate in rad/s for a curving bullet.
## A radial curve overrides it with its own alternating `spin` (F6e).
@export var behaviour_param := 0.0
## Spawn-safety radius override, px. -1 uses the library default. A pattern may
## only RAISE it (F7); a faster bullet needs a bigger one.
@export var spawn_safe_radius := -1.0

@export_group("Aim (F5)")
## Spread between neighbouring fan bullets, radians. 0 only when `count` is 1,
## otherwise at least 0.12 so a side-step always fits (F8 fan lane).
@export var spread_rad := 0.25
## Re-aim every volley of the burst, turning a burst into a tracking stream.
## Cannot be combined with `lock_ticks` (F5 validator).
@export var reaim_each_volley := false
## Ticks the target position is sampled BEFORE the burst, with a visible tell
## for those ticks: moving after the lock dodges it. 0 means no lock;
## otherwise 18-60 (under 18 the tell is unreadable, over 60 it is a free
## dodge).
@export var lock_ticks := 0

@export_group("Ring (F6b)")
@export var offset_mode := OffsetMode.SEEDED
## Rotation used when `offset_mode` is FIXED, radians.
@export var fixed_offset_rad := 0.0

@export_group("Spiral (F6c)")
## Bullets per volley, spread evenly round the turn. 1-6.
@export var arms := 1
## How far the spiral turns each volley, radians. -1.0 to 1.0. 0 fires a
## fixed-direction stream.
@export var step_rad := 0.33
## Angle of the first volley, radians.
@export var angle_offset_rad := 0.0

@export_group("Wall (F6d)")
## Gap between slots, px. At least 8.
@export var spacing := 16.0
## Width of the gap in slots. At least 1.
@export var gap_width := 1
## Slots at each end that always fire, so bullets always bound the gap.
@export var edge_slots := 1
## Direction the wall travels, radians (pi/2 is straight down).
@export var direction_rad := 1.5707963267948966

@export_group("Radial curve (F6e)")
## Turn rate magnitude, rad/s. The sign alternates each volley; the Bullet
## manager clamps the magnitude to 3.
@export var spin := 1.3

@export_group("Flak burst (F6f)")
## Furthest the burst point can be along the aim, px. 80-400.
@export var flak_distance := 240.0
## The burst centre never comes closer than this to the aim point, px.
## At least `spawn_safe_radius` + 8.
@export var standoff := 56.0
## Fuse length in ticks: the tell the player reacts to. At least 18.
@export var flak_delay := 36

@export_group("Spray (F6g)")
## Width of the spray, radians. 0.3-1.6.
@export var arc_rad := 1.2
## How far a bullet may wander inside its own slot, 0-1. Below 1 the bullets
## never bunch up, so a lane always stays open.
@export var jitter := 0.5
## Slowest bullet of a spray, px/s. At least 70.
@export var speed_min := 120.0
## Fastest bullet of a spray, px/s.
@export var speed_max := 180.0
