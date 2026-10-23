class_name CombatRules
extends Resource
## Game-wide chain and scoring rules. Edit values in data/combat_rules.tres.
## Per-plane values live in PlaneConfig, per-boss values in BossDefinition.
## Implements: design/gdd/game-concept.md §4 (Chain System).
##
## Usage:
##   var rules: CombatRules = load("res://data/combat_rules.tres")
##   score += rules.hit_score(chain.count)

@export_group("Chain")
## Seconds a chain survives without a new hit. Strict: when it runs out the chain resets to 0.
@export_range(0.2, 3.0, 0.05) var chain_window := 1.0

@export_group("Critical Break")
## final_chain = chain * break_mult + break_add
@export var break_mult := 3
@export var break_add := 50
@export var break_score_per_hit := 100
@export var life_bonus_per_life := 5000

@export_group("Boss Parts")
@export var part_kill_score := 2000
@export var part_kill_chain := 5
## Enemy bullets within this radius are cancelled when a part is destroyed.
@export var part_kill_cancel_radius := 90.0

@export_group("Bomb")
## Bombs deal this fraction of their damage to non-core parts.
@export_range(0.0, 1.0) var bomb_part_mult := 0.6

@export_group("Score")
@export var hit_score_base := 10


## Score for a single hit at the given chain count.
func hit_score(chain_count: int) -> int:
	return hit_score_base + chain_count
