class_name BossDefinition
extends Resource
## Data for one boss. Create new bosses as .tres files in data/bosses/.

enum CoreRule {
	ARMORED,  ## core takes armor_damage_mult damage while other parts live
	SHIELDED, ## core takes no damage (and gives no chain) while other parts live
}
enum Hull { NONE, WING_BAR, DELTA, RING }

@export var display_name := "BOSS"
@export var era := "1941"
@export var core_rule: CoreRule = CoreRule.ARMORED
@export_range(0.0, 1.0) var armor_damage_mult := 0.25
## Core HP at or below this = CRITICAL (Critical Break possible).
@export var critical_hp := 200.0
## Non-hittable silhouette drawn behind the parts (placeholder art).
@export var hull: Hull = Hull.NONE

@export_group("Movement")
## Center of the sway motion.
@export var anchor := Vector2(180, 130)
## position = anchor + (sin(t * freq.x) * amp.x, sin(t * freq.y) * amp.y)
@export var sway_amplitude := Vector2(68, 0)
@export var sway_frequency := Vector2(0.5, 0.0)

@export_group("Parts")
@export var parts: Array[BossPartDefinition] = []
