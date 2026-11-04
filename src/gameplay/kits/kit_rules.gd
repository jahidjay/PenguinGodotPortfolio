class_name KitRules
extends Resource
## Every number the plane kits use (design/gdd/plane-kits-lancer-leech.md
## Tuning Knobs; damage closed 2026-11-03 in collision OQ 3).
##
## Damage is integer and never below 20, because 20 is `armour_damage_min`:
## any value here must be able to hurt a plated enemy (Collision C4).

## Which kit a slot flies. All four are built: Lancer and Leech from GDD 11,
## Sentry and Breaker from GDD 29.
enum Kind { LANCER, LEECH, SENTRY, BREAKER }

@export_group("All kits (Rules 2-9)")
## Ticks of hold before the charge mode starts.
@export var charge_hold_ticks := 18
## Ticks the normal shot keeps firing after a tap is released.
@export var shot_linger_ticks := 12
## Ticks between plane-shot volleys.
@export var shot_interval := 5
## Damage of one plane-shot bullet, and of one drone bullet.
@export var shot_damage := 20
## Bullet speed, px/s.
@export var shot_speed := 900.0
## Ticks between one drone's bullets while it is docked and the gun is on.
@export var drone_interval := 8
## Drones a plane starts the run with. Powerups (13) is what raises it, and
## GDD 13 Rule 2 makes the pod the only source — so this is 0, and a plane
## with no drones is a plane that has not met a carrier yet.
@export var starting_drones := 0
## Hard cap on drones per plane.
@export var max_drones := 4
## Wing slot offsets the docked drones sit at, relative to the plane.
@export var drone_slots: Array[Vector2] = [
	Vector2(-16.0, 6.0), Vector2(16.0, 6.0), Vector2(-24.0, 16.0), Vector2(24.0, 16.0),
]

@export_group("Lancer (Rules 16-25)")
## Bullets per plane volley, and the spread in radians.
@export var lancer_shot_count := 3
@export var lancer_spread_rad := 0.157
## Laser meter, 0 to `meter_max`.
@export var meter_max := 1000
## Meter needed at the charge tick to start the laser. Checked once, on the
## edge: if it fails, this hold is a plain hold for good.
@export var laser_min_meter := 400
## Meter spent per active laser tick.
@export var meter_per_tick := 5
## Meter gained per counted plane-shot hit. Drone bullets do not fill it.
@export var fill_per_hit := 2
## Whether a plain hold becomes a laser the moment the meter is full enough.
##
## GDD 11 Rule 4 checks the charge once, on the edge: a hold that started
## short stays plain until the player lets go. Measured in play, that means a
## player who simply holds Fire NEVER sees the laser, because the meter fills
## while they are already holding. With this true the laser starts as soon as
## the meter reaches `laser_min_meter`, which is what makes the ability
## discoverable. Set it false to get the GDD letter back.
@export var charge_rearms_while_held := true
## Laser damage, dealt every `laser_damage_interval` active ticks.
@export var laser_damage := 60
@export var laser_damage_interval := 3
## Half-width of the beam column, px.
@export var laser_half_width := 7.0
## Invulnerability requested each active tick, including the exit grace.
@export var laser_invuln_ticks := 13
## Plane speed while the laser is on, px/s.
@export var laser_speed := 90.0
## Ticks a parked drone stays parked.
@export var park_ticks := 300
## Damage of one parked-drone beam tick, and its interval.
@export var park_damage := 40
@export var park_interval := 8
@export var park_half_width := 3.0
## Ticks before the drone ability is ready again, counted from the last dock.
@export var lancer_cooldown := 600

@export_group("Leech (Rules 26-38)")
@export var leech_shot_count := 2
@export var leech_spread_rad := 0.07
## Focused shot: fewer, harder, slower.
@export var focus_damage := 30
@export var focus_interval := 6
## Ticks the latch ability runs.
@export var latch_ticks := 360
## Damage of one latch tick, and its interval.
@export var latch_damage := 20
@export var latch_interval := 5
## Flight speed of a latching drone, px/tick.
@export var latch_speed := 14.0
## Distance at which a flying drone counts as latched, px.
@export var latch_radius := 14.0
## Drones allowed on one target before the next one looks elsewhere.
@export var latch_max_per_target := 2
@export var leech_cooldown := 540

@export_group("Sentry (GDD 29 Rules 10-17)")
## Twin parallel guns: a pair of bullets 2 x `sentry_muzzle_dx` apart.
@export var sentry_shot_count := 2
@export var sentry_shot_interval := 5
@export var sentry_muzzle_dx := 8.0
## Entrench: the nose cannon that replaces the twin guns while Fire is held.
@export var entrench_damage := 50
@export var entrench_interval := 6
## Plane speed while entrenched, px/s. Slower than the Leech focus: this is
## what the tracking drones cost.
@export var entrench_speed := 75.0
## Entrench aims the docked drones. Range in px, and the most they may swing
## away from straight up, in degrees.
@export var track_range := 220.0
@export var track_max_deg := 25.0
## Emplace: world-anchored turret posts.
@export var emplace_ticks := 420
@export var post_dx: Array[float] = [-60.0, 60.0, -110.0, 110.0]
@export var post_dy := -110.0
@export var post_speed := 10.0
## Ticks after the press before a second press recalls the turrets.
@export var recall_min_ticks := 60
## A turret fires one aimed diamond every `turret_interval` ticks at anything
## inside `turret_range`.
@export var turret_interval := 7
@export var turret_range := 160.0
@export var turret_damage := 40
@export var sentry_cooldown := 480

@export_group("Breaker (GDD 29 Rules 18-29)")
## Ram shot: one heavy bullet, fast.
@export var breaker_shot_damage := 30
@export var breaker_shot_interval := 3
## Breach: the slug that replaces the ram while Fire is held.
@export var breach_damage := 40
@export var breach_interval := 4
## Return bolts, fired during Breach only, paid for out of the stock.
@export var bolt_cost := 2
@export var bolt_range := 360.0
## Px per tick. 18 px/tick is 1,080 px/s, under the 1,200 px/s player cap.
@export var bolt_speed := 18.0
@export var bolt_damage := 40
@export var bolt_interval := 5
## The stock rises only from erased bullets and never decays.
@export var stock_max := 60
## Erase Net: plane-relative stations that delete enemy bullets.
@export var net_ticks := 300
@export var station_dx: Array[float] = [-24.0, 24.0, -72.0, 72.0]
@export var station_dy := -70.0
@export var station_speed := 12.0
## Radius of one drone's erase zone, px.
@export var net_r := 26.0
@export var net_pulse_interval := 2
## Bullets one drone may erase per activation before it is spent.
@export var net_budget := 30
## The net never covers the plane's own neighbourhood, px.
@export var net_safe_clear := 40.0
## Stock credited per pulse, however many bullets it removed.
@export var credit_per_pulse_cap := 4
## The net also rams: one damage event to the lowest-id target in the zone.
@export var net_ram_damage := 40
@export var net_ram_interval := 6
@export var breaker_cooldown := 600

@export_group("Recall (Rule 31)")
## Px a returning drone moves toward its slot each tick.
@export var return_speed := 10.0
## Ticks after which a drone still out snaps home.
@export var return_cap := 45
