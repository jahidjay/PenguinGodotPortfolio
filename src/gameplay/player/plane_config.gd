class_name PlaneConfig
extends Resource
## Tuning for one plane. One .tres per plane in data/planes/.
## Implements: design/gdd/game-concept.md §5 (Player Planes). Only Lancer exists so far.

@export var plane_name := "Lancer"
@export var color := Color(1.0, 0.7, 0.2)
@export var color_ability := Color(1.0, 1.0, 0.8)

@export_group("Movement")
@export var speed := 280.0
@export var speed_firing := 200.0
@export var speed_ability := 120.0
## The only point that can be hit. Keep tiny (bullet hell).
@export var hitbox_radius := 3.0

@export_group("Shot")
@export var fire_interval := 0.06
@export var shot_speed := 900.0
@export var shot_damage := 1.0
## Horizontal offset of the twin shots from the plane center.
@export var shot_offset := 8.0

@export_group("Laser (Lancer ability)")
## Meter needed to start the laser.
@export var laser_min_meter := 40.0
@export var meter_max := 100.0
## Meter gained per accepted hit from shots/bombs (not from the laser itself).
@export var meter_per_hit := 0.6
## Meter used per second while the laser is on.
@export var meter_burn := 25.0
@export var laser_damage := 3.0
## Each tick counts as one chain hit.
@export var laser_hits_per_second := 20.0
@export var laser_width := 14.0

@export_group("Bomb")
@export var bombs := 3
@export var bomb_damage := 80.0
@export var bomb_invulnerability := 2.0

@export_group("Lives")
@export var lives := 3
@export var respawn_invulnerability := 2.5
