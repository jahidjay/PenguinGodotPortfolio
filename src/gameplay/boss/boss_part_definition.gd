class_name BossPartDefinition
extends Resource
## One hittable piece of a boss: the core, a turret, an engine, a shield...
## Each part has its own hitbox, HP and bullet patterns.

enum Shape { CIRCLE, RECT }

@export var part_name := "Part"
## Exactly one part per boss must be the core. The core can only be finished by a Critical Break.
@export var is_core := false
@export var shape: Shape = Shape.CIRCLE
## CIRCLE: x = radius. RECT: full width and height.
@export var size := Vector2(14, 14)
@export var max_hp := 100.0

@export_group("Placement")
## Fixed position relative to the boss center (ignored when orbiting).
@export var offset := Vector2.ZERO
## > 0: the part orbits the boss center at this radius.
@export var orbit_radius := 0.0
## Radians per second.
@export var orbit_speed := 0.0
## Starting angle in radians.
@export var orbit_phase := 0.0

@export_group("Attacks")
@export var patterns: Array[BulletPattern] = []
