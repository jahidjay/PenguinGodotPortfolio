class_name EnemyDef
extends Resource
## One kind of enemy (design/gdd/enemy-and-ai.md Rule 1, class table Rule 2).
##
## Read-only at runtime: every enemy of this kind shares one resource, and all
## per-enemy state lives in [EnemyManager]'s packed arrays.
##
## Scope note: this is the MVP subset the first playable needs — class, body,
## hp, path, patterns, kill value and plating. The fields the GDD lists for
## later systems (`novelty_tags` for Era shift, `preview` for Boss power
## budget, the drill overrides for Tutorial) are deliberately absent until
## those systems exist, rather than present and ignored.

## Rule 2's class table. Drives the body size, the hurtbox count and the
## default kill value.
enum SizeClass { SMALL, MEDIUM, LARGE }

## Which layer the enemy flies on. GROUND enemies are not lethal to touch:
## the player flies over them (Rule 11).
enum Layer { AIR, GROUND }

@export_group("Identity")
## Stable authored id, used in debug output and the wave tables.
@export var id := &""
@export var size_class := SizeClass.SMALL
@export var layer := Layer.AIR

@export_group("Body (Rules 9-11)")
## Collision radius of the visible core, px. Rule 2: 7-9 small, 12 medium,
## 18 large.
@export var body_radius := 8.0
## Half the spine length of the body capsule, px. 0 is a circle.
@export var spine_half := 0.0
## Extra radius the player's shots get over the lethal body, px (Rule 10), so
## shooting feels generous while dying stays honest.
@export var hurt_pad := 2.0
## Hurtbox circles published along the spine. Rule 2: 1 small, 2 medium,
## 3 large.
@export var hurtbox_count := 1

@export_group("Health and value")
@export var hp := 20
## Score class paid on death. Indexes [enum ScoringLedger.KillClass]; -1 uses
## the size class.
@export var kill_class := -1
## Ticks it is armoured for from the first tick it is targetable (Rule 12).
## 0 = never armoured. MVP: 120 on LARGE.
@export var plating_ticks := 0
## Damage percentage an armoured hit deals, 0-100 (Rule 12).
@export var plating_armor_pct := 50

@export_group("Art")
## The body sprite, drawn centred on the enemy's position. Null falls back to
## a primitive, so the game still runs with an empty `assets/art/`.
@export var sprite: Texture2D
## Overlay shown while the enemy is armoured, which falls away when the
## plating ends (art bible 5.7).
@export var plating_sprite: Texture2D

@export_group("Drops (powerups-and-drops.md Rule 3)")
## True when every enemy of this kind carries an item. A wave may also flag an
## individual group with [member SpawnEventDef.carrier]; either is enough.
## Nothing else in the game drops anything.
@export var carrier := false

@export_group("Movement and weapons")
@export var path: EnemyPathDef
## Patterns this enemy's emitter fires. Empty = unarmed (the `fodder` role).
@export var patterns: Array[PatternDef] = []
## Offset of the muzzle from the body centre, px.
@export var muzzle_offset := Vector2(0.0, 8.0)
## Ticks after which it despawns whatever its path says, so a stuck enemy can
## never hold a wave open. 0 = no limit.
@export var max_life_ticks := 1800
## Radius of the bullet cancel its death produces, px. 0 = none (Rule 2:
## none small, 40 medium, 72 large).
@export var cancel_radius := 0.0


## The kill class this enemy pays, resolving the size-class default.
func resolved_kill_class() -> int:
	if kill_class >= 0:
		return kill_class
	match size_class:
		SizeClass.MEDIUM:
			return ScoringLedger.KillClass.MEDIUM
		SizeClass.LARGE:
			return ScoringLedger.KillClass.LARGE
		_:
			return ScoringLedger.KillClass.SMALL
