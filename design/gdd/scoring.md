# Scoring

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — lean mode
> **Author**: user + Claude
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts

## Overview

**Scoring** turns what happens in a run into one integer per player: their **score**. It is a pure ledger. It reads events from other systems, applies the point rules and adds the result to that player's score in Session (1).

**Chain-first ranking.** The chain is the main score driver. A hit's value grows with the player's current chain count, so 100 hits at chain 150 are worth far more than 100 hits at chain 5. Kills, boss-part kills, Critical Breaks, score items and stage-clear bonuses add value, but none of them can make up for a dropped chain.

**What it owns:**

- **Point rules.** Per-hit value, kill value, part-kill value, Critical Break value and the Life Damage Bonus.
- **Team Chain Bonus value.** It pays the bonus when Chain (7) reports a team chain. Co-op (18) owns the rest of the co-op rules.
- **`extend_unit`**, the "par score per stage". Session (1) uses it to place score extends.
- **Stage-end bonuses** the tally shows: clear, no-death, lives-left and boss-peak lines. The Stage-end tally (21, `stage-end-tally.md`) pays them line by line through `pay_stage_end_line` (Rule 8).

**What it doesn't own:**

- Which hits count (Collision 6) and the chain count (Chain 7).
- Where the score is stored, extends, lives and continues (Session 1).
- Score item pickup and drops (Powerups 13).
- How the score looks (HUD 20, Tally 21).

**The player impact:** the score is the long-term goal of the genre. It is how the "187 on the Fortress" story becomes a number to beat and a name on a table. It has to reward the chain and nothing else (*Every Hit Counts*), so a player who plays safe and keeps a long chain outscores one who just survives.

> Flagged for Formulas: Chain tracker Open Question 1 — the 999 cap is reachable in ~4.5 s, so Scoring must stay meaningful after the cap.

## Player Fantasy

**Direct: the player watches the number and plays to grow it.**

The anchor moment: **the boss core cracks, charge and bomb land together, and the chain jumps from 150 to 500.** The score leaps by more than the whole stage so far. Then the gold bar drains and the player keeps hitting to hold that 500. Everything they did to build the 150 is in that jump.

- **The score tells the truth about the chain.** A bigger chain always means a bigger score. Nobody can out-score a long chain by farming safe kills or hiding. The number is the record of how well they chained.
- **Earned leaps.** The big jumps are the Critical Break and the end of a clean boss. The player sees them coming and knows what caused them.
- **Readable at a glance.** The score line explains itself. The tally says where the points came from, so "what do I do better next time?" is never a mystery.
- **A number worth bragging about.** In co-op, two scores side by side make an honest rivalry, and a Team Chain Bonus pays for playing together.

It serves **Every Hit Counts** (*"the chain is the game; every system feeds or threatens the hit counter"*): score is where the chain becomes a number you can compare.

> `creative-director` not consulted for this section (lean mode).

## Detailed Design

### Core Rules

**The ledger**

1. Scoring is a **node-free class** that works out points and calls Session's `add_score(slot, points, source)`. It never stores the authoritative score; Session does. It keeps one thing of its own: a per-slot, per-source **breakdown** for the current stage and the whole run, for the tally.
2. **A slot scores only in states Alive or Dead.** *Dead* is the respawn delay: a dead player's shots still in flight earn kills, as Collision C5 requires. Events for Selecting, Continue, Inactive or Empty slots are ignored, with a warning in debug builds. Hit points can only arrive for Alive slots anyway, because Collision sends `chain_hit` for Active planes only.
3. **All score maths is integers.** No float is ever stored or added. Any rounding rule belongs to the formula that uses it (Formulas).

**Score sources (MVP)**

| # | Source | Trigger | Paid to | Value depends on |
|---|---|---|---|---|
| S1 | **Hit** | each counted hit (`chain_hit`), with that hit's resulting chain count | the shooter | chain count at that hit; team-chain multiplier |
| S2 | **Kill** | Collision `kill_credit(slot)` on a destroyed small, medium or large enemy | the credited slot | enemy class (fixed value) |
| S3 | **Part kill** | destroyed boss part | the credited slot | fixed value |
| S4 | **Boss kill** | `boss_defeated(reason, killer_slot)` with `reason` ≠ TIMEOUT (Boss (14) Rule 33) | every slot that was Alive or Dead during the fight | fixed value |
| S5 | **Critical Break** | `chain_multiplied` from a confirmed break (17) | the breaker | the uncapped raw count `before × cb_mult + cb_add` (F4) |
| S6 | **Life Damage Bonus** | the same Critical Break | the breaker | lives in reserve at the break |
| S7 | **Score item** | Powerups (13) reports a pickup | the collector | item base × a chain factor from the collector's chain |
| S8 | **Stage-end bonuses** | the tally starts (`stage_cleared`) | each scoring slot | clear, no-death, lives left, boss peak chain (set in Formulas) |
| S9 | **Team Chain Bonus** | a multiplier, not its own payment: while Chain (7) reports a team chain, **S1 only** is multiplied | each team member (a slot in Chain's `M`, Co-op (18) Rule 13) | `team_mult` |
| S10 | **Cap hold** | each full second a slot's chain stays at the cap (F6) | the holder | streak length |

4. **Hits (S1).** For each counted hit, in arrival order on that tick: `points = hit_score(count_after_this_hit)`, times the team multiplier if a team chain is on. A hit at the cap (999) still scores at count 999.
5. **Kills and part kills (S2, S3)** are paid once per destroyed target, to the slot Collision credits. They don't scale with the chain, so a chain-free player earns a baseline and a chain adds the large share.
6. **Critical Break (S5, S6)** pays on `chain_multiplied`. The score uses the **uncapped** raw value `before × cb_mult + cb_add` (F4), so a break above chain 317 still pays more than one at 317. The life bonus counts lives in reserve, not the one just lost. **Scoring (not Critical Break) writes** the slot's `critical_breaks` and `life_bonus_total` in Session; CB writes neither (Critical Break 17 Rule 16, 2026-11-03). For CB's popup, Scoring exposes two pure functions using the same code as the payout (F4): `preview_cb_points(before) -> int` (= `cb_unit × (before × cb_mult + cb_add)`, uncapped) and `preview_ldb_points(lives) -> int` (= `ldb_per_life × max(0, lives − 1)`, the lives in reserve).
7. **Score items (S7).** `value = item_base × chain_factor(count)`. The chain count read is the collector's count at pickup time. A count of 0 still pays `item_base × 1`.
8. **Stage-end bonuses (S8)** are computed once per stage at `stage_cleared` (lives snapshot at that tick; an extend during the tally does not change LIVES_LEFT) and held as **four pending lines per slot**: STAGE_CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK. The Stage-end tally (21) pays each line via `pay_stage_end_line(slot, line)`, one at a time, so the extend can be shown when the displayed score crosses it. A line is paid at most once. Unpaid lines are **flushed** in that fixed order on `stage_started` or at run end (safety). By then every chain has dropped (Chain Rule 10), so the boss peak chain is read from `max_chain_per_boss`. *(Amended 2026-11-03, stage-end-tally.md; was "paid once, when the tally starts".)*
9. **Every award is also added to the breakdown** under its source, so the tally can show "Hits 1.2M · Kills 180k · Critical Break 640k…".
10. **Extends.** After every `add_score`, Session checks its extend thresholds (Session F2). Scoring supplies `extend_unit`, the par score of one clean stage; the value is found in Formulas.

### States and Transitions

Scoring has almost no state of its own. Per slot:

| State | Meaning | → Next |
|---|---|---|
| Earning | the stage is running; sources S1–S7 can pay | Tally (`stage_cleared`) |
| Tally | S8 lines pending; paid line by line by the tally (`pay_stage_end_line`), any unpaid lines flushed on exit; no other source pays | Earning (next `stage_started`) |
| Reset | slot continues or drops in: the breakdown is cleared with the score (Session rules 6, 7) | Earning |

On stage start the stage breakdown is cleared; the run breakdown carries over.

### Interactions with Other Systems

| System | Gives to Scoring | Gets from Scoring |
|---|---|---|
| Collision (6) — GDD | `kill_credit(slot, enemy class)` (class comes from Enemy (10) `kill_class`); `chain_hit` events with the target class | — |
| Chain tracker (7) — GDD | **`hit_counted(slot, count_after, on_boss)`** per applied hit; `chain_multiplied`; `team_chain_started` / `ended` | — |
| Session (1) — GDD | Slot states; `lives`; `max_chain_per_boss` | `add_score(slot, points, source)`; `extend_unit` |
| Boss (14) — GDD | Part kill (via Collision `kill_credit(slot, PART)`) and `boss_defeated(reason, killer_slot)`; `boss_cap_hold_allowed()` (false from `enrage_start` to the boss end) | — |
| Critical Break (17) — [GDD](critical-break.md) | Confirmed break (via `chain_multiplied`) | Points (S5, S6); `preview_cb_points(before)`, `preview_ldb_points(lives)` for its popup; Scoring writes `critical_breaks` / `life_bonus_total` |
| Powerups (13) — GDD | `item_collected(slot, kind, count)` (kinds GEM and MEDAL; `count` is the collector's chain count, read by Powerups at the pickup tick); kill-cancel items from MEDIUM/LARGE kills (Enemy (10)) count toward `items_per_cancel_cap` | Points (S7) |
| Co-op (18) — GDD | `set_team_pct(slot, pct)` per slot (100 for non-members; 120 / 130 / 140 for 2 / 3 / 4 members) | `team_mult` value; `team_bonus_points` per slot |
| HUD (20) — [GDD](hud.md), Tally (21) — [GDD](stage-end-tally.md) | Tally calls `pay_stage_end_line(slot, line)` | Score changes, the per-source breakdown and the pending S8 lines |
| Save (26) — GDD | — | Final scores via Session; Save stores the true int64 (up to `score_store_max`), display clamp unaffected |

**Amendments** (✅ applied 2026-11-03): (1) **Chain tracker** must emit a per-hit **`hit_counted(slot, count_after, on_boss)`**; without it, several hits on one tick would all be read at the final count. (2) **Collision** must tag `kill_credit` with the enemy class so S2 can look up the value.

> Specialist agents not consulted for this section (lean mode).

## Formulas

All maths is integer and runs at 60 ticks/s. `/` is integer division. Every value comes from the scoring rules `.tres` (working name `data/scoring_rules.tres`). The chain constants (`cb_mult`, `cb_add`, `chain_cap`) are read from the chain rules resource and never copied.

**F1. Hit score (S1, S9)**

The hit_score formula is defined as:

`hit_points = ((hit_base + count_after) × team_pct + 50) / 100`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Hit base | hit_base | int | 0–50 (default 10) | Flat points per counted hit |
| Count after hit | count_after | int | 1–999 | From `hit_counted(slot, count_after, on_boss)` |
| Team percent | team_pct | int | 100 solo and for non-members; 120 / 130 / 140 for 2 / 3 / 4 members (Co-op F1); range 100–200 | Whole percent per slot, owned by Co-op (18) |
| Hit points | hit_points | int | 11–1,009 solo; 13–1,211 at 120% | Added to the shooter |

**Output Range:** 11–1,009 solo. The extreme is 2,018 (`team_pct` 200, count 999). The `+50` rounds half up, at most once per hit.
**Example:** count 150 solo → 160. In a team chain → (160 × 120 + 50) / 100 = **192**. Count 7 in a team chain → 2,090 / 100 = **20**.

**F2. Kills, parts, boss (S2–S4)**

The kill values formula is defined as:

`kill_points = kill_value[class]`, `part_points = part_value`, `boss_points = boss_value`

These are flat: no chain scaling and no team multiplier.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Small kill | kill_small | int | 100–500 (default 200) | Per small enemy |
| Medium kill | kill_medium | int | default 1,000 | Per medium enemy |
| Large kill | kill_large | int | default 5,000 | Per large enemy |
| Part kill | part_value | int | default 5,000 | Per boss part, to the credited slot |
| Boss kill | boss_value | int | default 100,000 | Paid **in full** to every slot that was Alive or Dead during the fight |

**Output Range:** ~170k per stage at most, which is ~0.5% of an expert's score and ~28% of a novice's.
**Example:** 60 small + 20 medium + 4 large = 12,000 + 20,000 + 20,000 = **52,000**.

**F3. Score items (S7)**

The item_points formula is defined as:

`chain_factor = 1 + min(count, factor_cap_count) / factor_step`
`item_points = item_base × chain_factor`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Collector's count | count | int | 0–999 | The collector's chain at pickup |
| Factor cap | factor_cap_count | int | 300–999 (default 500) | Chain above this adds nothing (limits bomb-cancel farming) |
| Factor step | factor_step | int | 25–100 (default 50) | Chain per +1 factor |
| Chain factor | chain_factor | int | 1–11 | Multiplier |
| Item base | item_base | int | gem 100, medal 1,000 | The item kinds are owned by Powerups (13) |
| Item points | item_points | int | 100–11,000 | Paid to the collector |

**Output Range:** 100 (a gem at chain 0) to 11,000 (a medal at chain ≥ 500).
**Example:** a medal at count 237: 1 + 237 / 50 = 5 → **5,000**. At count 0 → 1,000. At count 999 → 11,000.

**F4. Critical Break and Life Damage Bonus (S5, S6)**

The critical_break_score formula is defined as:

`cb_points = cb_unit × (before × cb_mult + cb_add)` (the **uncapped** raw value; the chain itself still caps at 999)
`ldb_points = ldb_per_life × max(0, lives − 1)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Before | before | int | 0–999 | From `chain_multiplied(slot, before, after)` |
| CB constants | cb_mult, cb_add | int | 3, 50 | Read from the chain rules (Chain F4); not duplicated |
| CB unit | cb_unit | int | 500–2,000 (default 1,000) | Points per raw chain point |
| LDB per life | ldb_per_life | int | 25k–100k (default 50,000) | Per spare life |
| Lives | lives | int | 1–6 | Session lives at the break; the life in play isn't counted |
| CB points | cb_points | int | 50,000–3,047,000 | Paid to the breaker |
| LDB points | ldb_points | int | 0–250,000 | Paid to the breaker |

**Output Range:** 50k (break at chain 0) to 3,047,000 + 250,000.
**Example:**
- before 150 → raw 500 → **500,000**; with 3 lives, LDB = 2 × 50k = **100,000**.
- before 400 → raw 1,250 → **1,250,000** (the HUD chain shows 999).
- before 999 → **3,047,000**.

**F5. Stage-end bonuses (S8)**

The stage_bonus formula is defined as:

`stage_bonus = clear_bonus + (no_death_bonus if deaths_this_stage == 0) + life_value × lives + peak_value × boss_peak`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Clear | clear_bonus | int | default 100,000 | Flat |
| No death | no_death_bonus | int | default 200,000 | Only with 0 deaths this stage |
| Life value | life_value | int | default 50,000 | Per life at tally start; the life in play counts |
| Lives | lives | int | 0–6 | Session lives at tally start |
| Peak value | peak_value | int | 500–2,000 (default 1,300; was 1,000, raised 2026-11-03 in the F7 re-baseline) | Per point of this slot's boss peak |
| Boss peak | boss_peak | int | 0–999 | This slot's `max_chain_per_boss` entries for this stage. With several bosses, the highest is used. |

**Output Range:** 100,000 to 1,898,700. Survival alone pays at most 600,000, which is below a competent stage.
**Example (competent):** 100k + 200k + 3 × 50k + 650 × 1.3k = **1,295,000**.

**F6. Cap-hold streak (S10; the cap fix)**

The cap_hold formula is defined as:

```
per tick, after Chain:  cap_ticks = cap_ticks + 1   if count == chain_cap AND chain not Frozen AND slot Alive
                                                     AND boss_cap_hold_allowed()
                        cap_ticks = 0               otherwise (any drop, or count below the cap)
when cap_ticks > 0 AND cap_ticks mod 60 == 0:
    hold_points = hold_unit × min(cap_ticks / 60, hold_ramp_s)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cap ticks | cap_ticks | int | ≥ 0 | Consecutive ticks at the cap, one counter per slot |
| Hold unit | hold_unit | int | 250–1,000 (default 500) | Pay per streak second |
| Ramp | hold_ramp_s | int | 10–60 (default 30) | Seconds until the pay stops rising |
| Hold points | hold_points | int | 500–15,000 per second | Paid to the holder |
| Cap hold allowed | boss_cap_hold_allowed() | bool | true / false | From Boss (14): false from the boss's `enrage_start` until the boss ends (any reason); true otherwise, including outside boss fights. While false the streak resets and pays nothing (anti-stall; added 2026-11-03). |

The team multiplier doesn't apply to S10.
**Output Range:** the first 30 s pay 500 × (1 + … + 30) = 232,500. After that it pays 15,000/s.
**Example:** a 95 s streak = 232,500 + 65 × 15,000 = **1,207,500**. A drop at 60 s, then a re-climb, restarts the streak at 500/s.

**F7. `extend_unit` and score budget**

`extend_unit = 3,000,000` (one competent clean stage, rounded down). With Session F2 at 0.8 / 1.0, extends land at **2,400,000** and **5,400,000**.

Assumptions per clean stage (300 s = waves 240 s + boss 60 s):

| | Novice | Competent | Expert |
|---|---|---|---|
| Hits waves / boss | 4,000 / 1,500 | 6,300 / 2,700 | 9,600 / 3,600 |
| Average chain waves / boss | 20 / 25 | 70 / 100 → 575 after the CB | 850 / 990 |
| Boss peak, CB at | 45, none | 650, 150 | 999, 999 |
| Deaths | 1 | 0 | 0 |
| Kills (small / medium / large), parts | 50 / 15 / 3, 3 | 60 / 20 / 4, 4 | 60 / 20 / 4, 4 |
| Items (medals + gems, collector chain) | 3 + 100, below 50 | 4 + 200, 80 | 4 + 300, ≥ 500 |

*Re-baselined 2026-11-03.* Hit counts now match what the kits can produce (Plane kits K8/K9: raw maximum 72 counted hits/s, landed about 43–60/s at 4 drones, about 28–40/s at the 2-drone reference): boss 2,700 competent = 45 hits/s and 3,600 expert = 60 hits/s over 60 s (Kits Open Question 1); wave hits scaled by the same factors from the old 12,000 / 20,000 (about 26 and 40 hits/s over 240 s, because enemies are not always on screen). Novice counts were already inside kit capability and are unchanged. Medals come only from carrier enemies, about 3 / 4 / 4 per stage (Powerups and drops); gems keep their counts (cancel cap 100 per cancel). Competent boss hits split 2,550 at chain 100 plus 150 after the break at 575. To keep the competent clean stage at about 3M with `extend_unit` locked, `peak_value` was raised 1,000 → 1,300 (F5).

| Source | Novice | Competent | Expert |
|---|---|---|---|
| S1 hits | 172,500 | 872,250 | 11,856,000 |
| S2–S4 kills, parts, boss | 155,000 | 172,000 | 172,000 |
| S5 + S6 Critical Break, LDB | 0 | 600,000 | 3,147,000 |
| S7 items | 13,000 | 48,000 | 374,000 |
| S8 stage end | 254,000 | 1,295,000 | 1,748,700 |
| S10 cap hold (2 × 95 s) | 0 | 0 | 2,415,000 |
| **Total** | **~0.59M** (594,500) | **~2.99M** (2,987,250) | **~19.71M** (19,712,700) |
| **Share from the chain** | 29% | 71% | 94% |

"From the chain" (strict definition) means the count part of S1 (`hit_points − hit_base`, at solo), plus S5, the S8 boss peak and S10. Items and the LDB are left out. Chain-first holds for skilled play: the health check requires competent ≥ 65% and expert ≥ 90% (AC-48).

How the extends land:

- **Competent:** pre-tally score of a clean stage is 1,692,250, so the first extend (2,400,000) is paid on the **BOSS_PEAK line of the stage 1 tally** (2,142,250 after the other three lines), and the second (5,400,000) on the BOSS_PEAK line of the stage 2 tally. (Before the re-baseline: during the boss fight, and mid-stage 2.)
- **Expert:** both inside stage 1, during the waves (S1 waves alone is 8.26M).
- **Novice:** none (their safety net is 1-ups and continues).

**F8. Bounds and display**

`displayed = min(score, 999,999,999)`

- **Hard bound per slot per stage:** about 31M (every hit at the kit maximum of 72 hits/s, Plane kits K9, at the cap with the team bonus, plus every bonus; amended 2026-11-03, was "under 100M" before the hit-rate re-baseline). *(Named 2026-11-03, wave 4:)* this bound is the constant **`slot_stage_bound` = 31,000,000** (registry), read by Online leaderboards (32) F1 for its plausibility check. Changing it, or any rule that can raise a slot's per-stage score above it, requires an online **ruleset bump**.
- **Run bound:** about 62M for the 2-stage MVP run, about 124M for a 4-stage run (2× / 4× the stage bound); both stay far inside int64 and the 9-digit display clamp is only reached by future content.
- **Storage:** score is int64 in Session and is never clamped there. Only the display clamps.
- **HUD plate:** 9 digits plus separators. Grouping is Western 3-digit with `,` in both languages (`999,999,999`); `display_score` output is formatted by `Localization.format_int` (Localization (27) F1, Rule 18), which maps digits to Bengali numerals when the language is `bn`.
- **Team bonus breakdown:** `team_bonus_points` per slot is an info-only figure inside HIT (not a new source id), for the tally (Co-op (18)). *(Added 2026-11-03.)*

> Formulas proposed by `systems-designer`, decided by the user on 2026-11-03: Critical Break scored on the uncapped raw count, cap-hold streak, `extend_unit` 3M with 0.8 / 1.0, all base values as proposed, 9-digit display.

## Edge Cases

**Same-tick ordering**

- **If several hits land on one tick:** each hit pays from its own `count_after` (via `hit_counted`), in arrival order. Three hits from 49 pay 60, 61 and 62.
- **If a team chain starts or ends during a tick:** Chain checks the team chain at the end of a tick. Hits on tick T therefore use the team state from the end of tick T−1. The tick that starts a team chain pays solo; the next tick pays 120%.
- **If hits and a Critical Break land on the same tick:** they are applied in Chain's arrival order. Hits before the break pay at the pre-break count, and hits after it pay at the new count. The break pays on its own `before`.
- **If a player scores a kill and dies on the same tick:** Collision runs Phase A first, so the kill credit, the hits and their points stay. Nothing is taken back.
- **If the breaker dies on the same tick as the break:** Chain ignores the break because the slot isn't Active, so no `chain_multiplied` is sent and S5/S6 pay nothing.

**Who gets paid**

- **If kill credit arrives for a Dead slot** (shots still in flight): it pays (Rule 2).
- **If it arrives for a slot in Continue, Inactive, Empty or Selecting:** ignored, with a debug warning.
- **If a boss part or the boss core is destroyed:** kill credit carries class PART or CORE. PART pays S3 only; CORE pays nothing (S4 comes from `boss_defeated`). Neither also pays S2.
- **If kill credit has an unknown enemy class:** it pays 0 and logs a data warning.
- **If an award is legitimately 0** (e.g. the LDB with 1 life): no `add_score` call and no warning. Only bad-data values warn.
- **Boss kill (S4)** goes to each slot that is **Alive or Dead at `boss_defeated`** and was in play during the fight (the same rule as Chain's "in play"). A slot in Continue at that moment gets nothing. If `reason = TIMEOUT` (the boss withdrew after its enrage, Boss (14) Rule 33), **S4 is not paid** to anyone; the chain still freezes and the stage clears as usual.
- **In 4P co-op**, each player gets the full boss value. Scores are per player, so it is never split.

**Critical Break**

- **If a break happens at chain 0:** raw 50, so 50,000 points.
- **If a break happens with 1 life:** the LDB is 0. Lives are read on the break tick.
- **If a break happens at a chain of 317 or more:** the chain shows 999 but the score uses the uncapped raw value (F4).

**Score items**

- **If an item is picked up at chain 0:** factor 1, so it pays the base value.
- **If an item pickup is reported for a non-scoring slot:** ignored. Powerups (13) decides who can collect.
- **If a cancel creates more than `items_per_cancel_cap` items:** Powerups (13) caps the count. This is the bomb-farming guard; the cap is 100 (`items_per_cancel_cap`, Powerups (13) F3, stride-sampled; decided 2026-11-03).

**Cap-hold streak (F6)**

- **If the chain drops, the slot dies, or `stage_cleared` arrives:** `cap_ticks` becomes 0.
- **If the chain freezes at `boss_defeated`:** `cap_ticks` becomes 0 and stops. Frozen chains never pay S10.
- **If the game is paused:** no ticks run, and the streak neither grows nor resets.
- **If the chain reaches the cap during a Critical Break:** the streak starts counting from the next tick.

**Stage end (S8)**

- **If a slot is Dead at tally start:** it is paid. Its lives were already reduced, so `life_value × lives` uses the lowered count.
- **If a slot is in Continue at tally start:** it gets no S8. A continue would wipe that score anyway.
- **If a player dropped in mid-stage or continued this stage:** no `no_death_bonus`. It requires the slot to be in play (Alive or Dead) at `stage_started` with 0 deaths this stage. Scoring counts `deaths_this_stage` itself from `player_died` and resets it on `stage_started`. Clear, lives and peak still pay.
- **If hits, kills, items or cap-hold ticks arrive after `stage_cleared`** (the tally is running): they pay nothing and log no warning. The tally numbers never change while shown.
- **If a player drops in during the tally:** S8 has already been paid and isn't paid again. The next stage pays normally.
- **If the slot has no boss peak entry this stage:** `boss_peak` is 0.

**Continue, drop-in and bounds**

- **If a slot continues:** Session wipes the score. Scoring clears that slot's stage and run breakdown and resets `cap_ticks`.
- **If a points value would be ≤ 0** (bad data): nothing is added, and a warning is logged. A data lint also rejects negative values in the `.tres`.
- **If the score passes 999,999,999:** the stored score keeps counting (int64) and the display shows 999,999,999 (F8).
- **If one award crosses both extend thresholds** (a big Critical Break, for example): Session pays both at once (Session F2).

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Slot states (Alive and Dead score). Provides `lives` and `max_chain_per_boss`, plus `stage_started`, `stage_cleared`, `boss_defeated` and `player_died`. Scoring calls `add_score(slot, points, source)` and adds to `critical_breaks` and `life_bonus_total`. Session runs the extend check after each add. |
| Collision, damage and lives (6) — GDD | Hard | `kill_credit(slot, enemy_class)` on *destroyed*. Ghost-shot credit for Dead slots is included. |
| Chain tracker (7) — GDD | Hard | `hit_counted(slot, count_after, on_boss)` per applied hit (**new**). Also `chain_multiplied(slot, before, after)`, `team_chain_started` / `ended`, `count` and Frozen state (for F6), and the chain rules constants `cb_mult`, `cb_add`, `chain_cap`. |

**Inputs from other systems (contracts; rows marked — GDD are confirmed by that GDD, the rest stay provisional)**

| System | What it must provide |
|---|---|
| Boss and boss parts (14) — GDD | Marks targets as boss part or core, so kill credit carries class PART or CORE (S3, or nothing for CORE; S4 comes from `boss_defeated`) rather than S2. Provides the enrage timer: `boss_cap_hold_allowed()` (F6, AC-39) and `boss_defeated(reason, killer_slot)`; S4 skips TIMEOUT. *(Contract confirmed by `boss-and-boss-parts.md`, 2026-11-03.)* |
| Enemy and AI (10) — GDD | An enemy class (small / medium / large) on every enemy (`kill_class`), carried in kill credit. MEDIUM/LARGE kills cancel bullets (40 / 72 px); those items count toward `items_per_cancel_cap`. |
| Powerups and drops (13) — GDD | `item_collected(slot, kind, count)` with kinds GEM and MEDAL (`count` = collector's chain count). Owns `items_per_cancel_cap` (100) and decides who can collect (Active planes only). A POD at 4 drones pays a MEDAL (no new kind). *(Contract confirmed by `powerups-and-drops.md`, 2026-11-03.)* |
| Critical Break (17) — GDD | Confirms breaks through Chain's `apply_critical_break`. Scoring pays on `chain_multiplied`; CB reads `preview_cb_points` / `preview_ldb_points`. *(Contract confirmed by `critical-break.md`, 2026-11-03.)* |
| Co-op and Team Chain (18) — GDD | Owns the `team_pct` value per member count (120 / 130 / 140, Co-op F1); calls `set_team_pct(slot, pct)`; a team member is a slot in Chain's `M`. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Session (1) | Hard | Receives `add_score` and gets `extend_unit` (3,000,000). |
| Powerups and drops (13) | Hard | Calls Scoring for item value (F3). |
| HUD (20) — [GDD](hud.md) | Hard | Score per slot, clamped to 9 digits (F8), formatted by `Localization.format_int`. |
| Stage tally (21) — [GDD](stage-end-tally.md) | Hard | Per-source breakdown for the stage and the run; the four pending S8 lines, paid by the tally via `pay_stage_end_line(slot, line)` (STAGE_CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK); amounts and lives fixed at `stage_cleared`; unpaid lines flush on `stage_started` or run end. |
| Save and high scores (26) — GDD | Soft | Final score through Session; Save stores the true int64, display clamp unaffected. |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | Soft | Reads `slot_stage_bound` (31,000,000) for plausibility (F1); scoring is unchanged in Boss Rush. |
| Audio (24), VFX (25) | Soft | Big-award events (Critical Break, extend) for feedback. [Audio](audio.md), [VFX](vfx-and-screen-feedback.md) |

**Amendments to existing documents** (✅ applied 2026-11-03)

1. **Chain tracker (7):**
   - Add the event `hit_counted(slot, count_after, on_boss)`, sent once per applied hit in arrival order.
   - Update the Scoring row in Interactions and Dependencies.
   - **Close Open Question 1:** cap meaning is solved by Scoring F4 (uncapped Critical Break basis) and F6 (cap-hold streak).
2. **Collision (6):** `kill_credit(slot)` becomes `kill_credit(slot, class)`, class ∈ SMALL, MEDIUM, LARGE, PART, CORE, supplied by Enemy (10) and Boss (14).
3. **Session (1):**
   - **Close Open Question 5:** `extend_unit` = 3,000,000, and the 0.8 / 1.0 multipliers stay.
   - Name the interface `add_score(slot, points, source)`.
   - Make clear that `life_bonus_total` holds points.
4. **Systems index:** Scoring (8) depends on **1, 6, 7** (1 is currently missing). Status becomes Designed at wrap-up.
5. **Registry:** `extend_unit` placeholder 1,000,000 becomes **3,000,000**, owned by Scoring.

**Bidirectional check:** Session, Collision and Chain already list Scoring. Boss (14), Enemy (10), Powerups (13), Critical Break (17), Co-op (18), HUD (20) and Tally (21) must list Scoring when they are written.

## Tuning Knobs

**Owned by this system** (`data/scoring_rules.tres`)

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `hit_base` | 10 | 0–50 | 0: a hit at chain 1 is worth 1, and the early chain feels worthless | Over ~50: the flat part beats the chain part until chain 50, so chain-first weakens | F1; novice score floor |
| `kill_small` / `kill_medium` / `kill_large` | 200 / 1,000 / 5,000 | ×0.5–×2.5 each | Novices see almost no score from waves | Kill-farming rivals chaining (keep kills ≤ ~30% of a novice stage) | Enemy class mix (10, 16) |
| `part_value` | 5,000 | 2,000–20,000 | Part-first play gives no score reason | Parts outweigh the Critical Break and the chain | `part_kill_chain` +5 (Boss 14) |
| `boss_value` | 100,000 | 50k–300k | Boss kill feels flat | Survival-only play scores well; 4P multiplies it per player | S8 clear bonus |
| `factor_cap_count` | 500 | 300–999 | Items stop rewarding chains early | Bomb-cancel farming at the cap pays ~11k per medal | `factor_step`; `items_per_cancel_cap` (13) |
| `factor_step` | 50 | 25–100 | Item value jumps every few hits (noisy) | Items barely change with chain | Milestones 50 / 100 / 200 (Chain) line up at step 50 |
| `item_base` (gem / medal) | 100 / 1,000 | 50–500 / 500–5,000 | Pickups feel pointless | Items rival hits | Powerups (13) drop rates |
| `cb_unit` | 1,000 | 500–2,000 | The Critical Break isn't the run's biggest moment | One break outweighs a whole competent stage | Chain `cb_mult`, `cb_add` (read, not owned) |
| `ldb_per_life` | 50,000 | 25k–100k | Lives don't matter at the break | Players hoard lives instead of risking | `life_value`, extends |
| `clear_bonus` | 100,000 | 50k–200k | — | Dying players catch up through the bonus | — |
| `no_death_bonus` | 200,000 | 100k–500k | Clean play isn't rewarded | It dominates a competent stage | `life_value` |
| `life_value` | 50,000 | 25k–100k | — | Lives left pays more than chaining (survival-only must stay under ~600k) | `max_lives` 6 (Session) |
| `peak_value` | 1,300 | 500–2,000 | The boss peak means nothing in the tally | It double-pays the chain on top of S1 | Chain boss peak record |
| `hold_unit` | 500 | 250–1,000 | Holding the cap is invisible in score | Holding the cap outweighs hits | `hold_ramp_s` |
| `hold_ramp_s` | 30 | 10–60 | A drop at the cap costs little | The full rate is unreachable in one boss | Boss length (14) |
| `extend_unit` | 3,000,000 | 2M–5M | Experts get extends in wave 1 and novices get them easily | Competent players never extend in the MVP | Session `extend_first_mult` 0.8, `extend_step_mult` 1.0 |
| `score_display_digits` | 9 | 9–10 | — | 4P HUD plates overflow | HUD (20) plate width |

**Health check after any change:** recompute the F7 archetype table. The chain share (strict definition, F7) must stay ≥ 65% for competent players and ≥ 90% for experts, and survival-only must stay below a competent stage.

**Owned elsewhere (pointers, not duplicated)**

- `team_pct` 120 → Co-op (18)
- `cb_mult` 3, `cb_add` 50, `chain_cap` 999 → Chain (7)
- `extend_first_mult`, `extend_step_mult`, `max_score_extends` → Session (1)
- `items_per_cancel_cap`, item drop rates → Powerups (13)
- Enemy class per enemy → Enemy (10); part and core tagging, enrage timer → Boss (14)

## Visual/Audio Requirements

Scoring draws nothing. It sends award events, and presentation systems react to them. Visual source of truth: the art bible. All values (P).

| Event | Visual (HUD 20 / VFX 25) | Audio (24) |
|---|---|---|
| HIT, KILL, ITEM, CAP_HOLD (small, frequent awards) | Score numerals on the HUD plate update; **no in-field popups** | None (kits and pickups own their sounds) |
| PART, BOSS | A plate-local "+5,000" / "+100,000" tag for ~1 s, inside the HUD strip | None (Boss 14 owns the destroy sound) |
| CRITICAL_BREAK + LIFE_BONUS | A plate-local award readout, e.g. "+1,250,000 / LIFE +100,000". The break flash and banner are owned by Critical Break (17). | Owned by Critical Break (17) |
| Cap-hold streak at full rate (30 s) | A MAX icon tag (12x8 plated, double chevron over a bar, no text) in the chain-plate lane while the streak pays 15,000/s (HUD 20 Rule 30, 2026-11-03) | A single soft cap-hold chime when the full rate is reached; **on by default** (Audio 24) |
| Extend (`extend_awarded`, Session) | Owned by HUD (20) | `sfx_score_extend_jingle` on `extend_awarded(gained > 0)` (Audio 24) |

- **Readable Chaos:** no score number is ever drawn over the play field. Everything stays in the opaque HUD strip, which sits outside it.
- **Big awards** (break, boss) use the same plate-local readout in co-op, one per player plate, with no screen-wide effect from Scoring.

## UI Requirements

Data Scoring provides, read-only:

| Data | Used by | Notes |
|---|---|---|
| `display_score(score)` per slot | HUD (20) | 9 digits, clamped at 999,999,999, tabular numerals, with separators; passed to `Localization.format_int` (Western 3-digit `,` grouping, both languages) |
| Award events `(slot, points, source)` | HUD (20) | Plate-local tags for PART, BOSS and CRITICAL_BREAK only |
| Stage breakdown per slot, by source id | Stage tally (21) | One line per source: Hits, Kills, Parts, Boss, Critical Break, Life bonus, Items, Clear, No-death, Lives left, Boss peak, Cap hold. Lines with zero may be hidden. |
| Run breakdown per slot | Results screen (22) | Same lines across the whole run |

- Source labels are localisation keys (English + Bengali). Scoring never formats text itself.

> **📌 UX Flag — Scoring:** the score plate and the tally breakdown are UI. Run `/ux-design` for the HUD (20) and Stage tally (21) **before** writing those epics. Stories cite `design/ux/hud.md` and `design/ux/stage-tally.md`, not this GDD.

## Acceptance Criteria

Defaults used: `hit_base` 10, `kill_small/medium/large` 200 / 1,000 / 5,000, `part_value` 5,000, `boss_value` 100,000, `factor_cap_count` 500, `factor_step` 50, `item_base` gem 100 / medal 1,000, `cb_unit` 1,000, `ldb_per_life` 50,000, `clear_bonus` 100,000, `no_death_bonus` 200,000, `life_value` 50,000, `peak_value` 1,300, `hold_unit` 500, `hold_ramp_s` 30, `extend_unit` 3,000,000, `score_display_digits` 9, `team_pct` 120 (Co-op stub), `cb_mult` 3, `cb_add` 50, `chain_cap` 999, 60 ticks/s. Slots 0-indexed. Tests read every number from `data/scoring_rules.tres` (working name) and the chain rules resource, never literals; quoted numbers are derived from the defaults.

**Test setup:** the logic lives in a plain `RefCounted` class `ScoringLedger` (working name) with no nodes and no `delta`; `tick()` advances one 1/60 s step and keeps its own tick counter. Inputs before a tick (queued, arrival order, one ordered stream shared with Chain's events): `set_slot_state(slot, state)`, `set_lives(slot, n)`, `set_team_pct(slot, pct)`, `hit_counted(slot, count_after, on_boss)`, `chain_multiplied(slot, before, after)`, `team_chain_started(slots)`, `team_chain_ended()`, `kill_credit(slot, class)` (class: SMALL, MEDIUM, LARGE, PART, CORE), `boss_defeated()`, `item_collected(slot, kind, count)`, `player_died(slot)`, `stage_started()`, `stage_cleared()`, `slot_continued(slot)`, `slot_dropped_in(slot)`, `set_chain_state(slot, count, frozen)`. Outputs after a tick: a Session stub log of `add_score(slot, points, source)` in order (source enum: HIT, KILL, PART, BOSS, CRITICAL_BREAK, LIFE_BONUS, ITEM, STAGE_CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK, CAP_HOLD), `critical_breaks` and `life_bonus_total` increments, extend-check count, `breakdown_stage(slot)`, `breakdown_run(slot)`, `cap_ticks(slot)`, `display_score(score)`, `extend_unit()`, `warnings`, `state_hash()`. A Node adapter calls `tick()` from `_physics_process` and is tested separately. Tests (`extends SceneTree`): `tests/unit/test_scoring_rules.gd`, `tests/unit/test_scoring_formulas.gd`, `tests/unit/test_scoring_edges.gd`, `tests/unit/test_scoring_budget.gd` (replays built by `tests/unit/support/scoring_replay.gd`), `tests/integration/test_scoring_chain_collision_session.gd`, `tests/perf/scoring_bench.tscn`; manual evidence in `production/qa/evidence/scoring/`. Names: `test_scoring_[scenario]_[result]`.

Tags: [Unit] pure logic, headless · [Integration] real `ChainTracker` / `CollisionReferee` / Session · [Manual] needs a human · [Perf] REF-WEB (ADR-0001).

### Ledger (Rules 1–3, 9, 10)

- **AC-01 [Unit] (Rule 1):** **GIVEN** slot 0 Alive, **WHEN** one counted hit is paid, **THEN** the Session stub receives exactly one `add_score(0, points, HIT)`; Scoring exposes no authoritative score field; only its breakdown changes locally.
- **AC-02 [Unit] (Rule 2):** **GIVEN** a slot in each state (Alive, Dead, Selecting, Continue, Inactive, Empty), **WHEN** a `kill_credit` arrives, **THEN** Alive and Dead pay; the other four make no `add_score` call and add exactly one debug `warnings` entry each.
- **AC-03 [Unit] (Rule 3):** over a 600-tick mixed script (S1–S10) every `points` value and every breakdown value is `TYPE_INT`; a lint over the scoring source finds no float type, float literal or float rounding call in the point maths.
- **AC-04 [Unit] (Rule 9):** after a run using all sources, each source's stage breakdown equals the sum of that source's `add_score` calls; the run breakdown equals the sum of its stage breakdowns; the sum over all sources equals the stub's score for that slot. Every award uses exactly one of the 12 source ids.
- **AC-05 [Unit] (States):** `stage_started` clears the stage breakdown and keeps the run breakdown; after `stage_cleared` the stage breakdown is frozen (repeated reads are equal).
- **AC-06 [Unit] (Rule 10):** 300 `add_score` calls produce exactly 300 extend checks, one after each call, in order.
- **AC-07 [Unit] (F7):** `extend_unit()` returns the resource value 3,000,000; with Session F2 at 0.8 / 1.0 the thresholds are 2,400,000 and 5,400,000.

### Hits and teams (Rule 4, S1, S9, F1)

- **AC-08 [Unit] (F1 examples):** count 150 solo → 160; count 150 at `team_pct` 120 → **192**; count 7 at 120 → **20**.
- **AC-09 [Unit] (F1 range):** count 1 solo → 11; 999 solo → 1,009; 1 at 120 → 13; 999 at 120 → 1,211; 999 at 200 → 2,018.
- **AC-10 [Unit] (F1 rounding):** `team_pct` 150, count 1 → (11 × 150 + 50) / 100 = **17**; solo never rounds.
- **AC-11 [Unit] (Rule 4 order):** three `hit_counted` with `count_after` 50, 51, 52 on one tick → three `add_score` calls of **60, 61, 62** in that order. A hit at 999 pays 1,009 with no warning.
- **AC-12 [Unit] (S9 scope):** during a team chain only HIT is multiplied; KILL, PART, BOSS, CRITICAL_BREAK, LIFE_BONUS, ITEM, all S8 ids and CAP_HOLD equal their solo values.

### Kills, parts, boss (Rule 5, S2–S4, F2)

- **AC-13 [Unit] (F2 example):** 60 SMALL + 20 MEDIUM + 4 LARGE credits → **52,000**, unchanged by the credited slot's chain or a team chain.
- **AC-14 [Unit] (no double pay):** `kill_credit(slot, PART)` pays `part_value` 5,000 only (no KILL); `kill_credit(slot, CORE)` pays nothing; the boss value is paid only via `boss_defeated`.
- **AC-15 [Unit] (S4):** at `boss_defeated`, each slot Alive or Dead that was Active on at least one fight tick gets **100,000**; Continue, Inactive, Empty and Selecting slots get 0. 4P with four eligible slots → four awards of 100,000. `boss_defeated(TIMEOUT, none)` → no S4 award to any slot.
- **AC-16 [Unit] (unknown class):** an unknown class → no `add_score`, one data warning, breakdown unchanged.

### Critical Break (Rule 6, S5, S6, F4)

- **AC-17 [Unit] (F4 table):** with 3 lives: before 0 → **50,000**; before 150 → **500,000** plus LDB **100,000**; before 400 → **1,250,000** (the event's `after` is 999); before 999 → **3,047,000**.
- **AC-18 [Unit] (uncapped basis):** a break at before 400 pays more than one at 317 (1,001,000); the score never uses `after`.
- **AC-19 [Unit] (S6):** lives 3 → 100,000; lives 6 → 250,000; lives 1 → 0 with **no** `add_score` call and **no** warning (a legitimate zero). Lives are read on the break tick.
- **AC-20 [Unit] (Session counters):** each break adds 1 to `critical_breaks` and the LDB points to `life_bonus_total` (0 at lives 1).

### Score items (Rule 7, S7, F3)

- **AC-21 [Unit] (F3 table):** medal at count 237 → **5,000**; at 0 → 1,000; 499 → 10,000; 500 → 11,000; 999 → 11,000. Gem at 0 → 100; at 999 → 1,100.
- **AC-22 [Unit] (item guards):** the count used is the one on `item_collected`; a pickup for a non-scoring slot → ignored with one warning; an unknown kind → 0, one data warning.

### Stage-end bonuses (Rule 8, S8, F5)

- **AC-23 [Unit] (F5 competent):** 0 deaths, 3 lives, peak 650 → 100k + 200k + 150k + 845k = **1,295,000**, as four awards (STAGE_CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK).
- **AC-24 [Unit] (F5 range):** 0 deaths, 6 lives, peak 999 → **1,898,700**; survival only (0 deaths, 6 lives, peak 0) → 600,000; a slot **Dead with 0 lives** at tally start, 1 death, peak 0 → **100,000**.
- **AC-25 [Unit] (peak, once only):** two boss entries 400 and 650 this stage → 650 used; no entry → 0; a second `stage_cleared` for the same stage pays nothing.
- **AC-26 [Unit] (Tally):** after `stage_cleared`, `hit_counted`, `kill_credit`, `item_collected`, `chain_multiplied` and cap-hold ticks pay nothing and log no warning; the stage breakdown and total change only through `pay_stage_end_line` until `stage_started`.
- **AC-26b [Unit] (S8 line pay and flush, added 2026-11-03):** competent case (AC-23) → after `stage_cleared` four pending lines exist and the score is unchanged; `pay_stage_end_line(0, NO_DEATH)` adds 200,000 once (a second call adds 0); an extend awarded during the tally does not change the pending LIVES_LEFT amount; `stage_started` (or run end) with STAGE_CLEAR, LIVES_LEFT and BOSS_PEAK unpaid pays them in that order (100,000, 150,000, 845,000), total S8 1,295,000.

### Cap hold (S10, F6)

- **AC-27 [Unit] (F6 pay):** count at cap, not Frozen, Alive: 59 ticks → no pay; tick 60 → **500**; 120 → 1,000; 1,800 → 15,000; 1,860 → 15,000. No team multiplier.
- **AC-28 [Unit] (F6 totals):** an unbroken 5,700-tick (95 s) streak totals **1,207,500**; the first 1,800 ticks total 232,500.
- **AC-29 [Unit] (restart):** a drop at 60 s → `cap_ticks` 0 that tick; after a re-climb the next pay is **500**, 60 ticks after reaching the cap.
- **AC-30 [Unit] (gates):** a Frozen chain at cap or a Dead slot → no pay, `cap_ticks` 0.

### Edge cases

- **AC-31 [Unit] (hits + CB same tick):** count 40, two hits then a break → hits pay 51, 52; the break uses before 42 (raw 176) → 176,000. Break first then two hits → 170,000, then 181, 182.
- **AC-32 [Unit] (team state from T−1):** `team_chain_started` at the end of tick T → hits on T pay solo (160 at count 150), hits on T+1 pay 192. `team_chain_ended` switches back the same way.
- **AC-33 [Unit] (kill + death same tick):** a KILL award and `player_died` on one tick → the award stays; no negative or reversing `add_score`.
- **AC-34 [Unit] (breaker dies):** no `chain_multiplied` on that tick → no CRITICAL_BREAK or LIFE_BONUS award, counters unchanged.
- **AC-35 [Unit] (S4 joins):** a slot Active from mid-fight gets S4; a slot in Continue at `boss_defeated` gets none; a slot that continued earlier in the fight and is Alive again gets S4; a slot that becomes Alive on the `boss_defeated` tick with no Active fight tick gets none.
- **AC-36 [Unit] (S8 Dead / Continue):** Dead at tally start with 2 lives → LIVES_LEFT uses 2; a slot in Continue → no S8 award at all.
- **AC-37 [Unit] (no-death gate):** a slot that dropped in mid-stage, or continued this stage, gets clear + lives + peak but no NO_DEATH; a slot in play (Alive or Dead) at `stage_started` with 0 `player_died` this stage gets it. `deaths_this_stage` is counted by Scoring and reset on `stage_started`.
- **AC-38 [Unit] (drop-in during tally):** no S8 is paid to it or re-paid to anyone; the next stage pays normally.
- **AC-39 [Unit] (`cap_ticks` resets):** becomes 0 on a chain drop, on `player_died`, on `stage_cleared` and on `boss_defeated`; it stays 0 (no hold pay) on every tick where `boss_cap_hold_allowed()` is false, and with it true again counting restarts from 0; a break that lifts the chain to the cap starts counting on the next tick.
- **AC-40 [Unit] (pause):** `cap_ticks` 45, adapter paused 30 s real time → still 45; after resume it counts 1 per tick and pays at 60.
- **AC-41 [Unit] (continue / drop-in reset):** `slot_continued` clears that slot's stage and run breakdown and `cap_ticks`; other slots untouched. A drop-in starts with an empty breakdown.
- **AC-42 [Unit] (bad data):** a value that computes ≤ 0 from bad data (e.g. negative `kill_small`) → no `add_score`, one warning; a data-lint over `data/scoring_rules.tres` fails on any negative value.
- **AC-43 [Unit] (F8):** `display_score(999,999,999)` → 999,999,999; `display_score(1,000,000,500)` → 999,999,999 while the stored score stays 1,000,000,500; with `score_display_digits` 10 the clamp is 9,999,999,999.

### Determinism

- **AC-44 [Unit]:** a scripted 1,800-tick run (4 slots, hits, team chain, kills, a boss fight, 2 breaks, items, a cap streak, 1 death, 1 continue, a drop-in, a stage clear), run twice → `state_hash()` equal every tick and identical `add_score` logs.

### F7 budget and regression

Replays use `scoring_replay.gd` to build each archetype from the F7 assumptions table (including the kill and item mix). Formula-derived lines must match exactly; totals within 1%.

- **AC-45 [Unit] (novice):** S1 = **172,500**, S2–S4 = 155,000, S7 = 13,000, S8 = **254,000**; total ≈ 594,500; no extend threshold crossed.
- **AC-46 [Unit] (competent):** S1 = **872,250** (6,300 at count 70, 2,550 at 100, 150 at 575), S5 + S6 = **600,000**, S7 = 48,000, S8 = **1,295,000**; total ≈ 2,987,250; the 2,400,000 threshold is crossed on the BOSS_PEAK award of the tally.
- **AC-47 [Unit] (expert):** S1 = **11,856,000** (9,600 at 850, 3,600 at 990), S5 + S6 = **3,147,000**, S7 = 374,000, S8 = **1,748,700**, S10 = **2,415,000**; total ≈ 19,712,700; both thresholds crossed inside the stage.
- **AC-48 [Unit] (chain share, health check):** share = (count part of S1, i.e. `hit_points − hit_base` at solo, + S5 + BOSS_PEAK + S10) / total. Expected novice ≈ 29%, **competent ≥ 65%** (computes 71.2%: 2,127,250 / 2,987,250), **expert ≥ 90%** (computes 93.8%: 18,484,700 / 19,712,700); survival-only S8 (600,000) < competent total. Re-run after any `.tres` change.

### Integration

- **AC-49 [Integration] (real Chain, per-hit):** real `ChainTracker`, three hits on one tick from 49 → three `hit_counted` and HIT awards 60, 61, 62; a same-tick break keeps the AC-31 order.
- **AC-50 [Integration] (real Chain, team and freeze):** 2P boss fight → hits on the tick a team chain starts pay solo, the next tick pays 120%; `team_chain_ended` reverts the same way; a chain Frozen at `boss_defeated` gives no CAP_HOLD.
- **AC-51 [Integration] (real Collision):** slot 1 destroys a small enemy → `kill_credit(1, SMALL)` → KILL 200 plus a HIT for the same hit; a boss part kill → PART 5,000 and no KILL.
- **AC-52 [Integration] (ghost shots, kill + death):** slot 3 Dying destroys an enemy → KILL paid, no HIT (no `chain_hit`); slot 0 kills and is hit on one tick → KILL and HIT stay (Collision AC-29).
- **AC-53 [Integration] (real Session, extends):** score 2,399,999 → 0 extends; +1 → 1 extend; score 2,399,000 plus a 3,047,000 break (5,446,000) → both extends in one evaluation (lives +2, clamped to `max_lives`); at `max_lives` the extend is consumed and `extend_awarded` fires with `gained` 0.
- **AC-54 [Integration] (real Session, continue):** a continue wipes Session score and `extends_awarded`; Scoring clears its breakdown; a later crossing of 2,400,000 awards an extend again; Session `critical_breaks` and `life_bonus_total` match the AC-20 sums.

### Performance

- **AC-55 [Perf] (REF-WEB):** 4 slots, 300 events per tick (mixed hits, kills, items, some cap-hold ticks), Session stub with an extend check after every add, 10,000 ticks → `tick()` ≤ **0.10 ms p99**, no allocations after warm-up (fixed `PackedInt64Array` breakdowns, no per-award `Array` or `Dictionary`). If the first measurement is under 0.03 ms, tighten the budget.

### Manual (evidence in `production/qa/evidence/scoring/`)

- **AC-56 [Manual] (tally readable):** clear a stage with Hits, Kills, Critical Break and stage bonuses non-zero → the tally shows one line per source in English and Bengali; a tester can say where over half the points came from; no number is clipped. Evidence: screenshots + checklist.
- **AC-57 [Manual] (HUD clamp):** debug-set a score to 1,000,000,500 → the plate shows 999,999,999 with separators and fits in 1P, 2P and 4P layouts. Evidence: screenshots.

> Criteria drafted by `qa-lead`; gaps resolved by the user (2026-11-03): events after `stage_cleared` ignored silently, strict chain share with competent ≥ 65% / expert ≥ 90%, 0.10 ms p99 with an extend check after every add. Defaults adopted: legitimate zero is silent, PART/CORE kill classes, Scoring counts `deaths_this_stage`, no-death needs the slot in play at `stage_started`, 12-id source enum, `display_score()` helper, `on_boss` ignored.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Are the placeholder values right (kills, parts, boss, items, stage bonuses, `cb_unit`)? Re-run AC-48 after tuning. (F7 re-baselined 2026-11-03 to Kits hit rates and Powerups medal counts; `peak_value` 1,300; competent first extend now lands on the tally. Check in playtest whether extends should come earlier, e.g. Session `extend_first_mult`.) | Designer | First playable stage |
| 2 | ~~Is `team_pct` 120 enough reward for the team chain? Does 4P need more?~~ **Closed 2026-11-03:** 120 / 130 / 140 for 2 / 3 / 4 members, with the ≤ 10 % stage-share rule (Co-op (18) F1, F8). | Co-op (18) | Done |
| 3 | ~~Item kinds, drop rates, `items_per_cancel_cap` 100, and who can collect~~ **Closed 2026-11-03:** scoring kinds are GEM and MEDAL only; `items_per_cancel_cap` = 100 per cancel (stride-sampled); only Active planes collect (Powerups (13) Rules 1, 20, 24, F3). Bomb cancel items are gems, capped at `items_per_cancel_cap` per bomb; the later area cancels give no items (Bombs (12) B9). | Powerups (13) | Done |
| 4 | ~~A boss enrage timer to stop stalling at 999 for cap-hold pay~~ **Closed 2026-11-03:** enrage at `round100(1.75 × T_fight)`, timeout 1,200 ticks later as `boss_defeated(TIMEOUT)` with no S4; `boss_cap_hold_allowed()` is false from enrage to the boss end (Boss (14) Rule 33, F6). | Boss (14) | Done |
| 5 | Enemy class (small / medium / large) per enemy, and PART / CORE tagging | Enemy (10), Boss (14) | Their GDDs |
| 6 | ~~Should a powerup at 4 drones give score (Session Open Question 4)? If it does, add an S7 item kind.~~ **Closed 2026-11-03:** a POD at 4 drones (no partner needing it) pays a MEDAL; no new item kind (Powerups (13) Rule 22). | Powerups (13) | Done |
| 7 | ~~Should high-score boards separate continued and drop-in runs?~~ **Closed 2026-11-03:** continued and drop-in runs are ranked with badges ("C", no 1CC); co-op boards per player count (Save (26) Rules 6–7). | Save (26) | Done |
| 8 | Migrate the prototype score code (`player.gd`, `combat_rules.tres`: 10+count, part 2000, CB ×100, 5000/life) to `ScoringLedger` and `scoring_rules.tres` | Programmer | Scoring epic |
| 9 | Does `extend_step_mult` 1.0 give experts free extends too early? Fallback: 1.5. | Designer | MVP playtest |
