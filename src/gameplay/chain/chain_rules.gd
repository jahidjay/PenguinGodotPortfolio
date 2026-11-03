class_name ChainRules
extends Resource
## Designer-owned tuning for the chain. Values are the locked ones from
## design/registry/entities.yaml; implements the Tuning Knobs of
## design/gdd/chain-tracker.md.
##
## All time is integer ticks at 60/s (ADR-0001 D5) — these are authored in
## ticks, not seconds, because the chain window is a precise gameplay value
## the whole game is balanced around.
##
## Usage:
## [codeblock]
## var chain := ChainCore.new(load("res://data/chain_rules.tres"), event_log)
## [/codeblock]

@export_group("Window")
## F1. Ticks a chain survives with no counted hit. 60 = 1.0 s.
@export var chain_window := 60

@export_group("Team chain")
## F3. How long a boss hit keeps a slot in the team chain.
@export var team_window := 60
## F3. Added per Active player above 2 — 60 / 68 / 76 ticks for 2 / 3 / 4.
## Co-op (18) F3. The registry entry for this carries no value, so the
## chain GDD's stated default is used.
@export var team_window_step := 8

@export_group("Count")
## Rule 3. Locked by the user 2026-11-02.
@export var chain_cap := 999

@export_group("Critical Break")
## F4. after = min(chain_cap, before * cb_mult + cb_add)
@export var cb_mult := 3
@export var cb_add := 50

@export_group("Bonuses")
## Rule 2. Chain added by a boss-part kill. Owned by Boss (14).
@export var part_kill_chain := 5

@export_group("Milestones")
## F5. Thresholds that fire chain_milestone when crossed, ascending.
@export var milestones: PackedInt32Array = PackedInt32Array([50, 100, 200])
