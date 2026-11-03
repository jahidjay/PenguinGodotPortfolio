class_name ScoringRules
extends Resource
## Designer-owned scoring values. Every number here is the locked value from
## design/registry/entities.yaml; implements the Tuning Knobs of
## design/gdd/scoring.md.
##
## The chain constants (cb_mult, cb_add, chain_cap) are deliberately NOT
## duplicated here — Scoring F4 reads them from ChainRules so the two can never
## drift apart (scoring GDD, Formulas preamble).
##
## Usage:
## [codeblock]
## var ledger := ScoringLedger.new(
##     load("res://data/scoring_rules.tres"), chain_rules, event_log)
## [/codeblock]

@export_group("Hits (F1)")
## Points per counted hit before the chain count is added.
@export var hit_base := 10
## Percent applied to hit score during a team chain, at 2 members.
@export var team_pct := 120
## Added to team_pct per extra member: 3P 130, 4P 140. Owned by Co-op (18).
@export var team_pct_step := 10

@export_group("Kills (F2)")
## Flat, with no chain scaling and no team multiplier.
@export var kill_value_small := 200
@export var kill_value_medium := 1000
@export var kill_value_large := 5000
@export var part_value := 5000
@export var boss_value := 100000

@export_group("Score items (F3)")
@export var gem_base := 100
@export var medal_base := 1000
## chain_factor = 1 + min(count, factor_cap_count) / factor_step
@export var factor_cap_count := 500
@export var factor_step := 50

@export_group("Critical Break (F4)")
## Points per raw (uncapped) Critical Break chain point.
@export var cb_unit := 1000
## Life Damage Bonus per spare life at the break.
@export var ldb_per_life := 50000

@export_group("Stage end (F5)")
@export var clear_bonus := 100000
@export var no_death_bonus := 200000
@export var life_value := 50000
## Points per point of the slot's boss chain peak. Raised 1000 -> 1300 on
## 2026-11-03 to keep a competent clean stage near extend_unit.
@export var peak_value := 1300

@export_group("Cap-hold streak (F6)")
## Paid every 60 ticks held at chain_cap. No team multiplier.
@export var hold_unit := 500
## Seconds the per-second payment ramps over before going flat.
@export var hold_ramp_s := 30

@export_group("Extends (F7)")
## Par score of one clean stage. Session multiplies this for each extend.
@export var extend_unit := 3000000

@export_group("Bounds (F8)")
## Display clamp only. Score itself is int64 and is never clamped in storage.
@export var display_cap := 999999999
## Plausibility bound for one slot in one stage, read by Online (32).
## Raising any rule above this needs an online ruleset bump.
@export var slot_stage_bound := 31000000
