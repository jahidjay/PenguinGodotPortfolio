class_name ScoringLedger
extends RefCounted
## Per-slot score. Node-free, all-integer. Implements design/gdd/scoring.md.
## Runs at step 8b of ADR-0002's tick, after the chain at 8a — so a hit's score
## uses the count *after* that hit (F1's `count_after`).
##
## The design is chain-first: almost all of a skilled score comes from the
## chain, not from kills. Kill values are flat and unscaled on purpose.
##
## Score is int64 and is never clamped in storage; only the display clamps to
## 9 digits (F8).
##
## Usage:
## [codeblock]
## var ledger := ScoringLedger.new(scoring_rules, chain_rules, event_log)
##
## # step 8b, after the chain has counted this tick's hits
## ledger.award_hit(slot, chain.count_of(slot), chain.is_team_chain(), members)
## ledger.award_kill(slot, ScoringLedger.KillClass.MEDIUM)
## ledger.award_item(slot, ledger.rules.medal_base, chain.count_of(slot))
##
## # a Critical Break pays on the UNCAPPED raw chain value
## ledger.award_critical_break(slot, raw_before, lives)
##
## # end of stage
## ledger.award_stage_end(slot, deaths_this_stage, lives, chain.boss_peak_of(slot))
##
## print(ledger.display_score(slot))     # clamped to 9 digits
## [/codeblock]

const MAX_SLOTS := 4

## Kill classes, matching Collision's kill_credit(slot, class).
enum KillClass { SMALL, MEDIUM, LARGE, PART, CORE }

## Score sources, for the stage-end tally breakdown.
enum Source { HIT, KILL, ITEM, CRITICAL_BREAK, LIFE_DAMAGE, STAGE_END, CAP_HOLD }

var rules: ScoringRules
var chain_rules: ChainRules
var _log: TickEventLog

var _score := PackedInt64Array()
## Per-slot, per-source totals for the tally: slot * SOURCE_COUNT + source.
var _by_source := PackedInt64Array()
## F6 cap-hold streak, in ticks.
var _cap_ticks := PackedInt32Array()
## Info-only figure inside HIT for the co-op tally breakdown.
var _team_bonus := PackedInt64Array()

const SOURCE_COUNT := 7


func _init(p_rules: ScoringRules, p_chain_rules: ChainRules, p_log: TickEventLog) -> void:
	assert(p_rules != null, "ScoringLedger needs a ScoringRules")
	assert(p_chain_rules != null, "ScoringLedger needs the ChainRules (F4 reads cb_mult/cb_add)")
	rules = p_rules
	chain_rules = p_chain_rules
	_log = p_log
	_score.resize(MAX_SLOTS)
	_cap_ticks.resize(MAX_SLOTS)
	_team_bonus.resize(MAX_SLOTS)
	_by_source.resize(MAX_SLOTS * SOURCE_COUNT)


## F1. `hit_points = ((hit_base + count_after) * team_pct + 50) / 100`
## The +50 rounds half up, at most once per hit. `team_members` sets the
## percentage: 2 -> 120, 3 -> 130, 4 -> 140 (Co-op F1).
func award_hit(slot: int, count_after: int, in_team_chain: bool, team_members: int = 2) -> int:
	if slot < 0 or slot >= MAX_SLOTS:
		return 0
	var base := rules.hit_base + count_after
	var points := base
	if in_team_chain:
		var pct := rules.team_pct + rules.team_pct_step * (clampi(team_members, 2, 4) - 2)
		points = (base * pct + 50) / 100
		_team_bonus[slot] += points - base
	_add(slot, points, Source.HIT)
	return points


## F2. Flat values: no chain scaling, no team multiplier.
func award_kill(slot: int, kill_class: int) -> int:
	if slot < 0 or slot >= MAX_SLOTS:
		return 0
	var points := 0
	match kill_class:
		KillClass.SMALL:
			points = rules.kill_value_small
		KillClass.MEDIUM:
			points = rules.kill_value_medium
		KillClass.LARGE:
			points = rules.kill_value_large
		KillClass.PART:
			points = rules.part_value
		KillClass.CORE:
			points = rules.boss_value
	_add(slot, points, Source.KILL)
	return points


## F3. `item_points = item_base * (1 + min(count, factor_cap_count) / factor_step)`
## Integer division, so the factor steps rather than ramping smoothly.
func award_item(slot: int, item_base: int, chain_count: int) -> int:
	if slot < 0 or slot >= MAX_SLOTS:
		return 0
	var factor := 1 + mini(chain_count, rules.factor_cap_count) / rules.factor_step
	var points := item_base * factor
	_add(slot, points, Source.ITEM)
	return points


## F4. Pays on the **uncapped** raw chain value, so a break past the 999 cap is
## still worth more. `raw_before` is the count at the break, before multiplying;
## this recomputes the raw value from the chain rules rather than trusting a
## caller's arithmetic.
func award_critical_break(slot: int, raw_before: int, lives: int) -> int:
	if slot < 0 or slot >= MAX_SLOTS:
		return 0
	var raw := raw_before * chain_rules.cb_mult + chain_rules.cb_add
	var cb_points := rules.cb_unit * raw
	_add(slot, cb_points, Source.CRITICAL_BREAK)
	var ldb := rules.ldb_per_life * maxi(0, lives - 1)
	if ldb > 0:
		_add(slot, ldb, Source.LIFE_DAMAGE)
	return cb_points + ldb


## F5. `clear + (no_death if deaths == 0) + life_value * lives + peak_value * peak`
func award_stage_end(slot: int, deaths_this_stage: int, lives: int, boss_peak: int) -> int:
	if slot < 0 or slot >= MAX_SLOTS:
		return 0
	var points := rules.clear_bonus
	if deaths_this_stage == 0:
		points += rules.no_death_bonus
	points += rules.life_value * maxi(0, lives)
	points += rules.peak_value * maxi(0, boss_peak)
	_add(slot, points, Source.STAGE_END)
	return points


## F6. The cap fix: holding the chain at its cap keeps paying, so reaching 999
## is not a dead end. Call once per tick, at step 8b.
##
## `at_cap`, `alive` and `allowed` are 1-per-slot flags. The streak resets the
## moment any of them fails, so a drop costs the whole ramp.
func tick(
	at_cap: PackedInt32Array,
	alive: PackedInt32Array,
	frozen: bool,
	boss_allows_hold: bool = true,
) -> void:
	for s: int in range(MAX_SLOTS):
		var holding := (
			not frozen
			and boss_allows_hold
			and s < at_cap.size()
			and at_cap[s] == 1
			and s < alive.size()
			and alive[s] == 1
		)
		if not holding:
			_cap_ticks[s] = 0
			continue
		_cap_ticks[s] += 1
		if _cap_ticks[s] % 60 != 0:
			continue
		var seconds := _cap_ticks[s] / 60
		var points := rules.hold_unit * mini(seconds, rules.hold_ramp_s)
		_add(s, points, Source.CAP_HOLD)


func _add(slot: int, points: int, source: int) -> void:
	if points == 0:
		return
	_score[slot] += points
	_by_source[slot * SOURCE_COUNT + source] += points
	_log.append(TickEventLog.Kind.SCORE_AWARDED, slot, points)


# --- reads -------------------------------------------------------------------

func score_of(slot: int) -> int:
	return _score[slot]


## F8. Only the display clamps; storage stays int64.
func display_score(slot: int) -> int:
	return mini(_score[slot], rules.display_cap)


func score_from(slot: int, source: int) -> int:
	return _by_source[slot * SOURCE_COUNT + source]


func team_bonus_of(slot: int) -> int:
	return _team_bonus[slot]


func cap_ticks_of(slot: int) -> int:
	return _cap_ticks[slot]


## Sum across every slot in the run — the co-op team score.
func team_score() -> int:
	var total := 0
	for s: int in range(MAX_SLOTS):
		total += _score[s]
	return total


## How many extends this slot has earned, per F7. Session owns awarding them;
## this only reports the threshold arithmetic.
func extends_earned(slot: int, first_mult: float = 0.8, step_mult: float = 1.0) -> int:
	var earned := 0
	var n := 0
	while true:
		var threshold := int(round(float(rules.extend_unit) * (first_mult + float(n) * step_mult)))
		if _score[slot] < threshold:
			break
		earned += 1
		n += 1
		if earned > 64:
			break
	return earned


## True if this slot's score exceeds the plausibility bound Online (32) checks.
func exceeds_stage_bound(slot: int) -> bool:
	return _score[slot] > rules.slot_stage_bound


func state_hash() -> int:
	var h := 1469598103934665603
	for s: int in range(MAX_SLOTS):
		h = (h ^ int(_score[s] & 0x7FFFFFFF)) * 1099511628211
		h = (h ^ _cap_ticks[s]) * 1099511628211
	return h
