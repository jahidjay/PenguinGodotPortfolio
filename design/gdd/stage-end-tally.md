# Stage-End Tally

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (ux-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts · History Accelerates (hand-off to the era shift) · Readable Chaos (calm, no bullets, no flashes)
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: the Continue accept press is named as the single `CONTINUE_ACCEPT` verb, bound to Fire, shared with the HUD Continue plate; Start stays Pause and never accepts (Rule 17).

## Overview

**The data layer:** the **Stage-end tally** is the calm screen that runs after every boss, including the last one. It is a node-free `StageTally` (working name, `RefCounted`, `tick()` at 60 Hz, no `delta`) plus a thin view. It does three jobs:

1. **Shows** what each player did this stage: best boss chain, Critical Breaks, Life Damage Bonus, the score by source, and (co-op) the team-chain uptime.
2. **Pays** the stage-end bonuses (Scoring S8: clear, no-death, lives left, boss peak) **one line at a time** at fixed ticks, so each add is visible and the score-extend moment can be shown.
3. **Hands off**: it tells Session when the stage is done (next stage or Results). It never writes to Save and never owns name entry.

It owns no point values. Every amount comes from Scoring (8). It owns the order, the timing, the layout and the skip rules.

**The player impact:** the player has just survived a boss and wants to see what it was worth. The tally answers "what did I do?" in order: the chain first (the hero number, Gold, big), then the break, then the bonuses, then the score. It counts up fast enough to feel good and can be skipped with one press. A first extend that lands on the BOSS PEAK line (the competent-play case, Scoring F7) is a small celebration the player sees coming. In co-op, columns sit side by side so rivals compare chains and scores at a glance.

## Player Fantasy

**Direct: "look what I did."** The sun is low, the wreckage is still smoking, no bullets are on screen, and your chain number is sitting there in gold: **650**. The rows drop in one at a time, a quarter-second apart. The bonuses count up and the score climbs. On the last line the number crosses the extend line and a small gold "1UP" plate pops in. You see exactly why the score is what it is, and you know what to do better next time.

- **Earned, not given.** Missed bonuses are shown dimmed with a cross ("NO DEATH ✗ 0"), so the player sees the 200,000 they left behind.
- **Always skippable.** An impatient expert presses once to settle and once to go on. A new player can sit and read; the screen waits (auto-advance can be turned off).
- **Fair in co-op.** Every column runs the same rules and the same clock. Nobody's numbers are hidden by another player's skip.
- **Bilingual and calm.** Bengali sits over English on every row label. Nothing flashes.

It serves **Every Hit Counts** (the chain is the hero number and the biggest share of the score) and **History Accelerates** (the end of the tally is the doorway to the next era).

> `creative-director` not consulted (lean mode; auto-approve).

## Detailed Design

### Core Rules

**Start, scope and what is read**

1. The tally runs after **every** stage, including the last. It starts on `stage_cleared` (Wave director 16). Scoring pays S8 only through the tally (Rule 11). A run that ends in GAME_OVER before a boss dies has no tally.
1a. *(Added 2026-11-03, wave 4.)* **Boss Rush** (online-leaderboards-boss-rush.md Rule 39): in a `RUSH` run each boss is a boss-only stage, so the standard tally runs **once per boss** with the same rows, timings and skip rule (skippable after `tally_min_ticks` as usual); the next Warning follows the rush refit beat. **Tip row** (tutorial.md Rule 27): the footer reserves one line for a Tutorial tip (14x14 icon + up to two S-tier lines, three in Bengali), shown only when a hint is pending and absent otherwise; it never moves the column grid. In a `DRILL` run (Flight School) there is no tally.
2. **Tick 0** of the tally is the tick `stage_cleared` is handled. At tick 0 the tally takes an immutable **snapshot** per slot (all later reads use it):
   - Session score; lives; `critical_breaks` (stage count = now minus the value stored at `stage_started`); `max_chain_per_boss` entries appended since `stage_started` (Rule 13).
   - Scoring's stage breakdown by source id (S1–S7, S10; S8 is not paid yet) and the pending S8 amounts.
   - Co-op: `team_on_ticks`, `eligible_ticks`, `team_bonus_points` per slot.
   - Save: `get_best_chain(plane, stage_index)` once per slot (read-only; MVP has one boss per stage, so `boss_index = stage_index`).
   - Boss: the `reason` of the last `boss_defeated`.
3. **Late events are ignored.** After tick 0 hits, kills, items and chain events pay nothing (Scoring Rule 8). The tally numbers never change except by its own S8 pays.
4. **Bullet gate.** The panel opens only when the enemy bullet count is 0. If it is not 0 at tick 0, the tally waits (state Waiting) up to `bullet_wait_max` ticks, then asks Bullet manager for a whole-screen cancel with no cause slot and opens. Bullets always win over UI (art bible 6.8).

**Columns and layouts**

5. A **column** is shown for each slot that is Alive, Dead or Continue at tick 0. A Selecting slot gets a "JOIN" placeholder plate. Inactive and Empty slots get none. `C` is the number of columns.

   | `C` | Layout | Column width | Portrait |
   |---|---|---|---|
   | 1 | **1P**: full-width rows, label left, value right | 336 | 96×96 victory portrait |
   | 2 | **2P**: shared caption band per row, two value cells | 180 | 36×36 in the column head |
   | 3–4 | **4P**: shared caption band per row, four value cells in fixed slot order P1–P4 (an absent slot shows a "join" plate, as the HUD does) | 90 | none (slot tag only) |

6. **Fixed line order** (Rule 7 decides which are visible):

   | # | Line id | Kind | Source | Shows |
   |---|---|---|---|---|
   | 1 | `MAX_CHAIN` | info (hero) | Session entries | the stage's best boss chain; `NEW BEST` stamp |
   | 2 | `CRIT_BREAK` | info | Scoring S5 (stage) | points; chip `×n` where the cell is ≥ 150 px |
   | 3 | `LIFE_BONUS` | info | Scoring S6 (stage) | points |
   | 4 | `HITS` | info, 1P only | S1 | points |
   | 5 | `KILLS` | info, 1P only | S2 | points |
   | 6 | `PARTS` | info, 1P only | S3 | points |
   | 7 | `BOSS` | info, 1P only | S4 | points (hidden on TIMEOUT) |
   | 8 | `ITEMS` | info, 1P only | S7 | points |
   | 9 | `CAP_HOLD` | info, 1P only | S10 | points |
   | 10 | `EARNED` | info, 1P and 2P | sum of S1–S7 and S10 for the stage | points |
   | 11 | `TEAM_CHAIN` | info, co-op only | Co-op F7 | `uptime_pct` and `team_bonus_points` per slot |
   | 12 | `SCORE` | running total | Session | starts at the tick-0 score; moves with each pay |
   | 13 | `STAGE_CLEAR` | **pays** | Scoring S8 | 100,000 |
   | 14 | `NO_DEATH` | **pays** | S8 | 200,000, or 0 dimmed with ✗ |
   | 15 | `LIVES_LEFT` | **pays** | S8 | lives pips and `life_value × lives` |
   | 16 | `BOSS_PEAK` | **pays** | S8 | `peak_value × boss_peak` |

   Rows 13–16 are always visible. Row 12 (`SCORE`) is drawn **after** the info rows and **above** rows 13–16 in time, but sits below them on screen (Visual section), so the eye ends on the number.
7. **Visibility.** `MAX_CHAIN`, `SCORE` and rows 13–16 are always visible. Every other line is hidden if **all** columns are 0 (for `TEAM_CHAIN`: if `eligible_ticks` is 0 or `C` is 1). In a shared layout, a row is shown for everyone and a 0 cell is drawn dim as "0". `n_info` is the number of visible info rows (rows 1–11), `MAX_CHAIN` included.
8. **Info rows are display only.** Their points were already added to the score during the stage. They never call Scoring. They only count up.

**Timing and counting**

9. **Reveal schedule (TF1).** Info row `i` (0-based, visible only) starts at tick `open_ticks + i × row_gap`. The `SCORE` row appears at `open_ticks + n_info × row_gap`. Bonus row `k` (0 = STAGE_CLEAR … 3 = BOSS_PEAK) starts at `t_score + bonus_lead + k × bonus_gap`. The column is **Settled** `countup_ticks` after bonus row 3 starts.
10. **Count-up (TF2).** Every number is shown by an integer rule from `from` to `to` over `W` ticks (`W` = `countup_ticks` for points, `chain_countup_ticks` for the hero chain). No floats. At step `k = W` the shown value is exactly `to`.
11. **Paying S8.** At the **start tick of bonus row `k`**, the tally calls `ScoringLedger.pay_stage_end_line(slot, line)` once per eligible column. Scoring adds that one S8 award with `add_score(slot, points, source)`; Session runs its extend check after it (Scoring Rule 10). Order is fixed: STAGE_CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK. A line whose amount is 0 (a legitimate zero) makes no `add_score` call. The `SCORE` row counts from the previous shown value to the new Session score over `countup_ticks`. S8 amounts are fixed by Scoring at tick 0 (Scoring F5; lives snapshot at tick 0, so a life gained by an extend during the tally does **not** change LIVES_LEFT).
12. **The extend moment (TF3).** `extend_awarded(slot, gained)` fires at the pay tick (Session). The tally holds the presentation until the **shown** `SCORE` value first reaches the extend threshold (Session F2 `extend_threshold(n)`, read from Session). On that tick the column shows a gold **1UP plate** for `extend_plate_ticks` and a new lives pip pops in. If `gained` is 0 (lives at `max_lives`), the plate reads `EXTEND · MAX` and no pip is added. Crossings on the same tick merge into one plate (`1UP ×2`). The extend sound plays on this tick, not on the pay tick (Audio and HUD suppress their own extend feedback while the tally is active; Rule 24).
13. **Hero chain.** `stage_chain = max(entries appended this stage)`; 0 or no entry shows "—" (a slot that was never Active in the fight). The hero is the largest element on screen (Gold, 24 px, art bible 7.3/7.4). `NEW BEST` stamps when `stage_chain > 0` and `stage_chain > get_best_chain(plane, stage_index)` from the tick-0 snapshot, and the run is not assisted (`run.assisted` false; an assisted PRACTICE run never shows NEW BEST, Accessibility 28, 2026-11-03). The stamp appears when the hero count-up ends. Records are written only at Results confirm (Save Rule 14, Rule 20).
14. **Boss withdrew.** If the last `boss_defeated.reason` is TIMEOUT: a bilingual plate "BOSS WITHDREW" shows under the header, the `BOSS` row is hidden (S4 was not paid, Boss Rule 31), and **STAGE_CLEAR and BOSS_PEAK still pay** (chain record is appended and the stage is a clear). *(Decided; closes Boss Open Question 4 for the clear bonus. Final-stage TIMEOUT still ends the run as a clear.)*

**Input: skip and confirm (per slot)**

15. **Skip / confirm key** = the slot's `pN_fire` **press edge** (Input F1), and its keyboard equivalent. *(2026-11-03, ADR-0003)*: the edge is read from the recorded simulation input (`SimInputDecoder`, Fire bit), never from menu verbs or raw devices, so tally length replays exactly. `start` and `back` pause (Input Rule 25) and are not tally keys. Drone and Bomb do nothing.
    - **Skip lockout:** press edges before tick `skip_lockout` (90) are ignored, so a player mashing fire through the boss death cannot skip the first rows by accident.
    - **First valid press** while the player's column is not Settled: **settle that column now**. Every remaining bonus line for that slot is paid on this tick in fixed order (Rule 11), every count snaps to `to`, and the 1UP plates for skipped crossings merge into one plate (`1UP ×n`) shown for `extend_plate_ticks`.
    - **Second valid press** (column Settled for at least `confirm_lockout` = 30 ticks): the slot is **Confirmed**.
    - Skip is **per column**: one player's press never changes another player's column. The caption of a row appears as soon as **any** column reaches it.
16. **Leaving.** The tally moves to Exiting when every **counted** column is Settled and either (a) every counted column is Confirmed, or (b) `settle_hold` (300 ticks) has passed since the **last** counted column settled and `access.tally_auto_advance` is true (default). A *counted* column is a slot that was Alive or Dead at tick 0 and is not now Waiting (pad lost), Inactive or Continue. If there are no counted columns, the tally exits `settle_hold` after settling.
17. **Other slot states.**
    - **Continue at tick 0:** dim column, "CONTINUE n" with `ceil(continue_remaining)`; no S8 (Scoring). A **Fire** press by that slot accepts the continue and is **not** a tally key. *(Amended 2026-11-03, wave 5 batch 2:)* this is the single **`CONTINUE_ACCEPT`** verb defined in [Input (2)](input-and-player-mapping.md) Rule 24b and shared with the in-stage HUD Continue plate ([HUD (20)](hud.md) Rule 24), so both surfaces show the same glyph via `action_glyph(slot, CONTINUE_ACCEPT)`. **Start never accepts a Continue** - it pauses (Input Rule 25) - and only the slot in Continue can accept its own. On accept the column shows "READY" and Scoring has already cleared its breakdown; it is not counted.
    - **Inactive during the tally** (countdown expired, `forfeit_slot`): the column dims to "OUT"; it stops being counted. Rows already shown stay.
    - **Pad disconnect:** the game auto-pauses (Input Rule 28); the slot is Waiting and not counted until it reconnects or is dropped.
    - **Drop-in** during the tally: a "JOIN" placeholder (Selecting), then, once the plane is picked, a "READY" plate. The new slot gets no S8 and is not counted. Session starts it next stage with `starting_lives`.
18. **Exit and hand-off.** In Exiting the panel fades out over `exit_ticks` (45). Before the next stage starts, the tally holds while any slot is Selecting for up to `join_hold_max` (600) ticks; when it expires, the join is cancelled (Session Rule 10). If the next stage is in a **different era**, the tally emits `tally_exit(stage_index, from_era, to_era)` and allows **Era shift (19)** to hold the exit for up to `era_hold_max` (240) ticks through `request_exit_hold(owner)` / `release_exit_hold(owner)` (see Interactions). *(2026-11-03, wave 3b, [Era shift GDD](era-shift-and-plane-evolution.md): Era shift requests the hold on the tick `tally_exit` fires; the tally's 45-tick fade runs inside Era shift's Dim phase (ticks 0-44 of the transition); `from_era` / `to_era` are `era_id` values (`era_1941`); `to_era` is none on the final stage; the transition's pause behaviour follows Rule 21. The Director supplies `is_last_stage` and `next_era` (from Era shift `era_for_stage`) at `stage_cleared`.)* The tally ends in Done with `next = NEXT_STAGE` or `RESULTS`. Session starts the next stage or opens Results through its direct reference (Session Rule 11; the bus event is an announcement only).
19. **Final stage.** The last stage's tally is identical, with header "ALL CLEAR" and the prompt "continue to results". Session sets `run_ended_by = ENDING` at the final `boss_defeated`, but builds the `RunRecord` and fires `run_ended` when the tally is **Done**, so the S8 points are in the record (amendment to Session AC-05).
20. **Game over during the tally** (every remaining slot expires from Continue): the tally aborts to Done with `next = RESULTS`. Points already paid stay.

**Tally versus Results**

| Shown at | Content |
|---|---|
| **Stage tally** (this GDD) | This stage only: best boss chain (and NEW BEST), Critical Break and LDB points, score by source (1P), EARNED, team-chain uptime and team bonus, the four S8 lines, running score, lives and extends. |
| **Results** (Menus 22) | The whole run: final score per slot, score incl. continues (Session F6), per-boss chain list, total Critical Breaks, `life_bonus_total`, team score and team max chain, `1CC` / `C` badges, `preview_rank`, name entry, `submit_run`. |

The tally **never** shows rank, initials, team score, run totals or badges, and **never** calls `submit_run`.

**Other**

21. **Pause** (Start/Back, or a pad disconnect) freezes the tally clock. Pausing is allowed at any tick; the pause owner follows Input Rule 25.
22. **Determinism.** Everything is a function of the tick counter, the tick-0 snapshot and the ordered press edges. No RNG. The tally's score effect is the same whether or not anyone skips (Rule 15): the same four awards in the same order. Only the **tick** of the adds changes with a skip.
23. **No Save writes.** The tally only reads `get_best_chain` once per slot at tick 0.
24. **HUD and Audio while active.** HUD (20) hides its strip and ignores `extend_awarded` presentation from `tally_started` to `tally_finished`. Audio (24) does not play the extend sound from `extend_awarded` in that window; it plays it from `tally_extend_shown`. *(2026-11-03, wave 3b: decided — the HUD strip **is hidden** while the tally panel is up; the tally owns the full 360x640 canvas, and the HUD shows again at the next `stage_started` (HUD Tally mode). The wave-3a "strip kept" note is withdrawn, so the 1P worst case (632 of 640 px) fits as designed.)*
25. **Not shown (MVP).** Unused bombs pay nothing (closes Bombs Open Question 8). `enemy_escaped` is not turned into a kill ratio (closes Enemy Open Question 14).

### States and Transitions

**Tally**

| State | Meaning | → Next |
|---|---|---|
| Idle | no stage clear pending | Waiting (`stage_cleared`) |
| Waiting | tick 0 taken; enemy bullets > 0 | Opening (bullets 0, or `bullet_wait_max`) |
| Opening | panel fades in over `open_ticks` (30) | Revealing |
| Revealing | rows and bonuses run on the schedule | Settled (all counted columns Settled) |
| Settled | all numbers final; waiting for confirm or `settle_hold` | Exiting (Rule 16) |
| Exiting | fade `exit_ticks`; era / join holds | Done |
| Done | result `next = NEXT_STAGE / RESULTS` read by Session | Idle (next `stage_cleared`) |

Any state except Idle → Done on game over (Rule 20).

**Column (per slot)**

| State | Meaning | → Next |
|---|---|---|
| Hidden | row not yet reached | Revealing |
| Revealing | rows appearing and counting | Settled (end of schedule, or skip) |
| Settled | final; accepts confirm after `confirm_lockout` | Confirmed |
| Confirmed | ready | — |
| Absent | Continue / Inactive / Waiting / Selecting-READY (not counted) | Settled only if it was counted and returns |

### Interactions with Other Systems

*(2026-11-03, wave 3b: every system named here now has a GDD — 16, 19, 20, 22, 23, 24, 25 and 28; the contracts below are linked and no longer provisional.)*

| System | Direction | Interface |
|---|---|---|
| Game events and session (1) — GDD | ↔ | ← `stage_started` (store `critical_breaks` and `len(max_chain_per_boss)`), `stage_cleared` (tick 0), `boss_defeated(reason, killer)`, `player_joined`, `player_continued`, `player_slot_inactive`, `extend_awarded`; ← lives, scores, slot states, `extend_threshold(n)`. → `tally_finished(stage_index, next)` read through a direct reference. Session builds the run record after Done (Rule 19). |
| Scoring (8) — GDD | ↔ | ← stage breakdown (S1–S7, S10) and pending S8 amounts at tick 0. → `pay_stage_end_line(slot, line)` at the bonus start ticks. Scoring flushes any unpaid lines in fixed order on `stage_started` or run end as a safety (Amendment 1). |
| Chain tracker (7) — GDD | ← | via Session: `max_chain_per_boss` entries. Chains are already dropped (STAGE_END). |
| Co-op and Team Chain (18) — GDD | ← | `team_on_ticks`, `eligible_ticks`, `uptime_pct` (F7), `team_bonus_points` per slot. |
| Save and high scores (26) — GDD | ← | `get_best_chain(plane, stage_index)` once per slot at tick 0. No writes. |
| Localization (27) — GDD | ← | `text_both(key)` for row labels (`tally.row.*`), `format_int` for every number, `text(key)` for prompts; pre-warm at stage load (Localization Rule 27). |
| Input and player mapping (2) — GDD | ← | `pN_fire` press edge per slot (confirm/skip); `start`/`back` pause; pad disconnect auto-pause. |
| Display scaler and bezel (4) — GDD | ← | The tally lives inside the 360×640 canvas, covers the HUD strip, and is drawn the same at every scale. |
| Boss and boss parts (14) — GDD | ← | `boss_defeated.reason` (TIMEOUT → "withdrew"). |
| Powerups and drops (13) — GDD | ← | Items are swept at `boss_defeated` and removed at `stage_cleared`; the tally sees neither. |
| Bullet manager (3) — GDD | ↔ | ← enemy bullet count (bullet gate). → one whole-screen cancel with no cause if the gate times out. |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | ← | `stage_cleared` fires at `max(boss_gone, boss_defeated + sweep_min_ticks 90)`, watchdog `boss_defeated + 360`, with `despawn_all` + `clear_all` (Director Rules 24-25, owner). *(2026-11-03, wave 3a: replaces the earlier `boss_gone + 30` assumption.)* |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | ↔ | `tally_exit(stage_index, from_era, to_era)` (era ids; `to_era` none on the final stage); `request_exit_hold` / `release_exit_hold`. Era shift's Dim phase contains the 45-tick fade; `era_ready` latches before Done. |
| Player plane (5) — [GDD](player-plane.md) | ← | Planes lose control at `stage_cleared` and fly out (Player plane owns the exit flight). |
| Tutorial (30) — [GDD](tutorial.md) | → | Footer tip row for a pending hint (Rule 1a), e.g. `enrage_icon`. |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | ← | `RUSH` runs: one tally per boss (Rule 1a). |
| HUD (20), Audio (24), VFX (25), Parallax (23) | → | `tally_started`, `tally_row_revealed(slot, line)`, `tally_extend_shown(slot, n)`, `tally_settled(slot)`, `tally_new_best(slot)`, `tally_finished`. Parallax ([GDD](parallax-and-environment.md)) slows scroll to `tally_scroll_pct` (25), a percent of the speed at tally open (25 x 25 div 100 = 6), over `open_ticks`; the boss grade eases out over 60 ticks. Audio ([GDD](audio.md)) and VFX ([GDD](vfx-and-screen-feedback.md)) listen. |
| Menus / Results (22) — [GDD](menus-title-plane-select.md) | → | Receives control after Done. Owns Results, name entry and rank. |

> Decided under auto-approve (2026-11-03): tally on every stage including the last; S8 paid line by line by the tally; per-slot skip on the fire press; two-press skip/confirm; auto-advance 5 s with an off switch; TIMEOUT keeps the clear bonus; no bomb bonus and no kill ratio; extend shown when the displayed score crosses the line.

## Formulas

All integer, 60 ticks/s. Values come from `data/tally_rules.tres` (working name); point values come from Scoring and are not copied.

**TF1. Reveal schedule**

```
info_start(i)  = open_ticks + i × row_gap                      i = 0 … n_info − 1
t_score        = open_ticks + n_info × row_gap
bonus_start(k) = t_score + bonus_lead + k × bonus_gap          k = 0 … 3
settle_tick    = bonus_start(3) + countup_ticks
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Open | open_ticks | int | 15–60 (30) | Panel fade-in |
| Row gap | row_gap | int | 10–30 (15) | 0.25 s per row (art bible 7.4) |
| Visible info rows | n_info | int | 1–10 (1P), 1–5 (2P), 1–4 (3–4P) | Rule 7 |
| Bonus lead | bonus_lead | int | 0–30 (15) | Pause between SCORE and the first bonus |
| Bonus gap | bonus_gap | int | `countup_ticks`–60 (30) | Must be ≥ `countup_ticks` |
| Count-up | countup_ticks | int | 15–60 (30) | Points |

**Output Range:** `settle_tick` 180 (1 info row) to 315 (10 rows, 1P); 3–4P at most 225.
**Example (competent 1P):** `n_info` = 9 (MAX_CHAIN, CRIT_BREAK, LIFE_BONUS, HITS, KILLS, PARTS, BOSS, ITEMS, EARNED; CAP_HOLD hidden) → `t_score` = 30 + 135 = **165**; bonus starts **180, 210, 240, 270**; `settle_tick` = 270 + 30 = **300** (5.0 s).

**TF2. Count-up**

`shown(k) = from + ((to − from) × k + W / 2) / W`, integer division, `k = 0 … W`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| From, To | from, to | int64 | 0 … `score_store_max`; `to ≥ from` | Values at the start and end of the count |
| Window | W | int | 15–90 | `countup_ticks` (30) or `chain_countup_ticks` (45) |
| Step | k | int | 0–W | Ticks since the row start |

**Output Range:** `from` at k = 0; exactly `to` at k = W (the rounding term `W/2` is < W, so it adds 0 at k = W). Never decreases. The display clamp (999,999,999, Scoring F8) is applied to the **shown** value only.
**Example:** from 1,692,250 to 1,792,250 (STAGE_CLEAR), W = 30: k = 15 → 1,692,250 + (100,000 × 15 + 15)/30 = **1,742,250**; k = 30 → **1,792,250**. Hero 0 → 650, W = 45, k = 22 → (650 × 22 + 22)/45 = **318**.

**TF3. Extend crossing tick**

`cross_tick = bonus_start(k) + min{ j in 0…W : shown(j) ≥ T }` where `T = extend_threshold(n)` from Session F2 and the count-up is TF2. If `from ≥ T` already, the extend was shown on an earlier line.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Threshold | T | int64 | > 0 | Session F2, e.g. 2,400,000 |
| Line index | k | int | 0–3 | Bonus row that carries the count |

**Output Range:** `bonus_start(k)` to `bonus_start(k) + W`.
**Example (Scoring F7 competent):** pre-tally 1,692,250; after CLEAR, NO_DEATH, LIVES: 2,142,250; BOSS_PEAK +845,000 (650 × 1,300) → 2,987,250. Pay tick 270 (Session awards the extend then). Shown at j = 9: 2,142,250 + 253,500 = 2,395,750 (< T); j = 10: 2,142,250 + 281,667 = 2,423,917 ≥ 2,400,000. `cross_tick` = **280**: plate, pip and sound at tick 280.

**TF4. Earned**

`earned(slot) = HITS + KILLS + PARTS + BOSS + CRIT_BREAK + LIFE_BONUS + ITEMS + CAP_HOLD` (stage breakdown at tick 0; S8 excluded)

**Output Range:** 0 … stage total. The invariant is `SCORE_at_tick0 − SCORE_at_stage_start = earned` for a slot that did not continue or die and wipe.
**Example:** competent: 872,250 + 172,000 + 600,000 + 48,000 = **1,692,250** (Scoring F7; kills/parts/boss line 172,000 split as KILLS 52,000 + PARTS 20,000 + BOSS 100,000 for the example mix).

**TF5. Hero chain and NEW BEST**

`stage_chain = max(entries[start_len …])`; `new_best = stage_chain > 0 AND stage_chain > best_snapshot`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Entries | entries | int[] | each 0–999 | Session `max_chain_per_boss` |
| Start length | start_len | int | ≥ 0 | Array length stored at `stage_started` |
| Stored best | best_snapshot | int | 0–999 | `get_best_chain(plane, stage_index)` at tick 0 |

**Output Range:** 0–999 (0 draws "—").
**Example:** entries [112, 187], `start_len` 1 → 187; best 112 → NEW BEST; best 187 → no stamp. A slot that dropped in with entries [] → "—".

**TF6. Exit timing**

`exit_start = max(settle_all + (settle_hold if auto else ∞), confirm_all)` · `done_tick = exit_start + exit_ticks + era_hold + join_hold`

**Output Range:** with auto-advance on, a no-skip run exits at `settle_tick + 300`; the first skip may settle at tick 90 at the earliest.
**Example:** competent 1P, no input: settles 300, exits 600, done at 645. With skip at tick 200 and confirm at 235: settled 200, confirm allowed from 230, done at 235 + 45 = 280.

> Formulas are UX timing and display rules; no point value is defined here. Every point value is Scoring F1–F8.

## Edge Cases

**Timing and input**

- **If a fire press arrives before tick `skip_lockout` (90)**, it is ignored and no flag is stored.
- **If fire is held through the boss death into the tally**, nothing happens; only press edges count (Input F1).
- **If a player presses skip on tick 200**, bonus rows not yet paid are paid on tick 200 in the order CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK; the final score equals the no-skip score.
- **If a player presses skip in the same tick as a scheduled pay**, the scheduled pay and the remaining pays all happen that tick in the same fixed order, once each.
- **If one player settles early in co-op**, only that column snaps; the other columns keep counting; the row captions stay visible.
- **If the second press comes before `confirm_lockout` (30) ticks after Settled**, it is ignored.
- **If the game is paused**, the tally clock, `settle_hold` and `exit_ticks` stop; a pad disconnect pauses the same way.
- **If `access.tally_auto_advance` is false**, the tally waits forever for all counted columns to be Confirmed.

**Pay and score**

- **If a slot is Dead at tick 0**, it is paid: lives are the already-lowered count (Scoring edge case).
- **If a slot is in Continue at tick 0**, it has no pending S8, the SCORE cell shows its current score dimmed, and nothing is paid.
- **If a slot accepts a continue mid-tally** after being paid, its score and breakdown are wiped by Session/Scoring; the column goes "READY", shows no further rows and is not counted.
- **If a slot accepts a continue mid-tally before its S8 is paid**, its pending S8 lines are discarded (Scoring clears them); the column goes "READY".
- **If `NO_DEATH` is not earned** (died, continued or dropped in), the row shows 0 dimmed with ✗, and `pay_stage_end_line(NO_DEATH)` makes no `add_score` call.
- **If lives are 0 at tick 0** (Dead on the last life, then Continue is not taken yet), LIVES_LEFT shows 0 dimmed and pays nothing.
- **If an extend raises lives during the tally**, the LIVES_LEFT amount (snapshot at tick 0) does not change; the new pip appears at the crossing tick.
- **If the extend is wasted at `max_lives`**, the plate reads `EXTEND · MAX`; no pip is added.
- **If one award crosses both thresholds**, one plate `1UP ×2` shows at the first crossing tick of the later threshold; with two separate ticks, two plates show 20 ticks apart (the second queued).
- **If the displayed score reaches 999,999,999**, the SCORE cell stays at 999,999,999 while the real score keeps counting (Scoring F8).
- **If an S8 award is paid by the safety flush** (the tally never ran), no row is shown for it; the points are in the score.

**Layout and data**

- **If a stage has no boss entry for a slot**, the hero shows "—", BOSS_PEAK shows 0, and the row is dimmed.
- **If the boss reason is TIMEOUT**, the `BOSS` row is hidden and the "BOSS WITHDREW" plate shows; STAGE_CLEAR and BOSS_PEAK pay.
- **If `eligible_ticks` is 0**, `TEAM_CHAIN` is hidden.
- **If `C` changes during the tally** (a slot goes Inactive), the layout does not change; the column dims to "OUT".
- **If a value would overflow its cell**, that value is a bug: all 4P cells show ≤ 7 digits except SCORE, which uses the wide treatment (Visual section). A debug build asserts on overflow.
- **If a Bengali label has not been pre-shaped**, a debug warning is logged and the English line shows alone for that tick. Release builds pre-warm (Localization Rule 27).
- **If the bullet gate times out**, a whole-screen cancel with no cause slot runs once; no score is paid for it.

**Hand-off**

- **If no slot is counted** (all Continue/OUT), the tally exits `settle_hold` after settling, or aborts at game over.
- **If a slot is Selecting at exit**, the exit holds up to `join_hold_max` (600) ticks; then the join is cancelled.
- **If Era shift never releases its hold**, the exit ends at `era_hold_max` (240) ticks.
- **If `stage_cleared` arrives twice** for one stage, the second is ignored.
- **If the run is ABANDONED from Pause during the tally**, the tally is discarded; no Save call (Session AC-35). Points already paid are irrelevant.
- **If Save is absent** (Vertical Slice not built), `get_best_chain` returns 0 for every slot and every chain > 0 shows NEW BEST; this is a debug-only state.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Events, slot states, scores, lives, extend thresholds; direct reference for hand-off. |
| Scoring (8) — GDD | Hard | Stage breakdown, pending S8 amounts, `pay_stage_end_line`. |
| Localization (27) — GDD | Hard | `text_both`, `format_int`, `text`, `tally.*` keys. |
| Input and player mapping (2) — GDD | Hard | Press edge per slot; pause; disconnect. |
| Chain tracker (7) — GDD | Soft | Entries via Session. |
| Co-op and Team Chain (18) — GDD | Soft | Uptime and team bonus stats. |
| Save and high scores (26) — GDD | Soft | `get_best_chain`. |
| Boss and boss parts (14) — GDD | Soft | `boss_defeated.reason`. |
| Display scaler and bezel (4) — GDD | Soft | Canvas size; inside canvas. |
| Bullet manager (3) — GDD | Soft | Bullet count; one cancel. |
| Powerups and drops (13) — GDD | Soft | Items already removed at `stage_cleared`. |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | Hard | `stage_cleared` timing (Director Rule 24) and stage/era data. |
| Era shift (19) | Soft | Exit-hold hook — [GDD](era-shift-and-plane-evolution.md). |
| Player plane (5) — GDD | Soft | Planes exit at `stage_cleared`. |

**Downstream**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) | Hard | Reads `next` after Done; builds the run record after it. |
| Menus, title and plane select / Results (22) | Hard | Takes over at Done. |
| HUD (20) — [GDD](hud.md) | Soft | HUD enters Tally mode (HUD state table): strip frame, score, lives, bombs, drones stay; boss row and banners hidden; no extend presentation. |
| Tutorial (30) — [GDD](tutorial.md) | Soft | Footer tip row (Rule 1a). |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | Soft | Per-boss tally in RUSH (Rule 1a). |
| Audio (24), VFX (25), Parallax (23) | Soft | Tally events — [Audio](audio.md), [VFX](vfx-and-screen-feedback.md), [Parallax](parallax-and-environment.md). |
| Accessibility (28) | Soft | `run.assisted` (no NEW BEST), `access.tally_auto_advance` — [GDD](accessibility-options.md). |
| Accessibility (28) | Soft | Registers `access.tally_auto_advance`. |

**Amendments to other docs** (the main session applies them)

1. **Scoring (8):** Rule 8 / S8: S8 amounts are computed at `stage_cleared` and held as four pending lines per slot; the tally pays each with `pay_stage_end_line(slot, line)` (line ∈ STAGE_CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK). Without a tally call, unpaid lines flush in that order on `stage_started` or run end. AC-23 is unchanged (four awards, same order). Add `snapshot lives at stage_cleared`. Dependencies: Stage tally (21) row says "Hard; pays S8 line by line".
2. **Game events and session (1):** (a) AC-05 and the Run flow table: after the final `boss_defeated` the state is **Tally** and then Results; `run_ended_by = ENDING` is set at `boss_defeated`; `run_ended` fires and the `RunRecord` is built when the tally is Done. (b) Store `critical_breaks` and `len(max_chain_per_boss)` per slot at `stage_started`. (c) Add events `tally_started`, `tally_row_revealed`, `tally_extend_shown`, `tally_settled`, `tally_new_best`, `tally_exit`, `tally_finished`. (d) Add Stage tally (21) GDD link to the Dependencies row.
3. **Save (26):** define `boss_index` as `stage_index` in MVP (one boss per stage) for `best_chain` and `get_best_chain`; a drop-in slot's entries then align with stages. Change the Tally row from "no GDD" to the GDD link.
4. **Co-op (18):** Stage tally row: link the GDD; add "`team_on_ticks`/`eligible_ticks` reset on `stage_started`, read at `stage_cleared` tick 0".
5. **Input (2):** add Stage tally (21) to Dependencies: "`pN_fire` press edge is the tally skip/confirm; Start/Back pause".
6. **Localization (27):** add the `tally.*` keys (Visual/Audio section) to `ui_tally.csv`; mark which are bilingual (`tally.row.*`, `tally.header.*`, `tally.note.boss_withdrew`).
7. **Art bible 7.4:** the "co-op uses a 2×2 grid of 180 px cells" is replaced by the shared-caption layouts here (Visual section); portrait 96×96 is 1P only; "Any button skips" becomes "the fire key skips (Start pauses)"; the row list gains the S8 lines, EARNED and TEAM CHAIN.
8. **HUD (20) and Audio (24):** suppress extend feedback while the tally is active; tally owns it. *(Done 2026-11-03: HUD Tally mode, Audio event table.)*
9. **Boss (14):** Open Question 4 closed for the clear bonus (kept on TIMEOUT). Tally row in Dependencies links this GDD.
10. **Bombs (12):** close Open Question 8 (no stage-end bomb bonus). **Enemy (10):** close Open Question 14 (no kill ratio in MVP).
11. **Wave director (16) (when written):** `stage_cleared` at `boss_gone` + 30 ticks; supplies `is_last_stage` and the next era. *(2026-11-03, wave 3a: Director written; its timing `max(boss_gone, D + 90)` governs. Wave 3b: the Director now supplies `is_last_stage` and `next_era` (from Era shift `era_for_stage`) at `stage_cleared`.)*
12. **Systems index:** row 21 status `**Designed** (pending review) — [GDD](stage-end-tally.md)`; Depends on `1, 7, 8, 18, 26 (soft), 27`.
13. **Registry:** `stage_end_bonuses` still says "peak 1000 per point"; set it to 1300 (the file has `peak_value` 1300). Add the tally constants (report). *(Done: registry `stage_end_bonuses` reads "peak 1300 per point" since wave 3a; confirmed 2026-11-03, consistency check.)*

## Tuning Knobs

**Owned by this system** (`data/tally_rules.tres`)

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `open_ticks` | 30 | 15–60 | Panel pops in; harsh | Dead time after the boss | `bullet_wait_max`, Parallax |
| `row_gap` | 15 | 10–30 | Rows blur together (art bible 0.25 s) | Tally drags; skip is needed | `n_info`, TF1 |
| `countup_ticks` | 30 | 15–60 | Counts are unreadable | Too slow to feel good | `bonus_gap` |
| `chain_countup_ticks` | 45 | 30–90 | The hero has no weight | The first row stalls the whole tally | `row_gap` |
| `bonus_lead` | 15 | 0–30 | SCORE and the first bonus collide | Awkward pause | TF1 |
| `bonus_gap` | 30 | `countup_ticks`–60 | Counts overlap (invalid) | Bonus section drags (4 lines) | `countup_ticks` |
| `skip_lockout` | 90 | 45–180 | Mashing skips the first rows | The impatient wait too long | Input |
| `confirm_lockout` | 30 | 15–60 | A double-tap skips and leaves | The player is stuck | `settle_hold` |
| `settle_hold` | 300 | 180–900 | Slow readers get cut off | Idle co-op partners stall | `access.tally_auto_advance` |
| `exit_ticks` | 45 | 20–90 | Cut feels abrupt | Dead time | Era shift |
| `era_hold_max` | 240 | 0–480 | Era shift is cut | Run feels stalled | Era shift (19) |
| `join_hold_max` | 600 | 180–1200 | A joiner loses their pick | Stage start stalls | Menus (22) |
| `bullet_wait_max` | 120 | 30–240 | Cancel too early | Dead time if a bug leaves bullets | Bullet manager |
| `extend_plate_ticks` | 90 | 60–180 | Plate missed | Covers the SCORE number | TF3 |
| `new_best_pulses` | 2 | 0–3 | No emphasis | Flash-like | `access.reduce_flashing` |
| `tally_scroll_pct` | 25 | 0–50 | Background freezes | Motion competes with text | Parallax (23) |

**Owned elsewhere (pointers, not duplicated)**

- Point values `clear_bonus`, `no_death_bonus`, `life_value`, `peak_value` (1,300) → Scoring (8). `extend_unit`, `extend_*_mult`, `max_lives` → Scoring / Session.
- `team_pct`, uptime targets → Co-op (18). `access.reduce_flashing` and `access.tally_auto_advance` → Accessibility (28), stored by Save (26).
- `name_entry_seconds`, initials → Save (26) / Menus (22). Digit grouping and `bn_width_reserve_pct` → Localization (27).

**Rationale:** `row_gap` and the count-up window come from the art bible (0.25 s per row); `settle_hold` 5 s is long enough to read 4 numbers and short enough that a co-op round does not stall. The `skip_lockout` guards a mash through the boss death.

## Visual/Audio Requirements

All sizes in px at 1x on the 360×640 canvas. Draw layer 11 (UI). Mood: art bible §2 "Stage tally": soft warm light, low contrast, calm, the era palette in muted form. No flashes.

**Layers and colour roles**

| Element | Spec |
|---|---|
| Backdrop | The last gameplay frame, held; warm overlay at 55% (Cabinet Char tint), 20% era tint on frame edges only (art bible 4.7). Layer 11, bottom. A sunset/dawn gradient band behind the header (era muted). |
| Plates | Rectilinear, chamfered, Cabinet Char with `#5A5148` edges. No orbs, rings, needles. Never Void Indigo or Ink fills. |
| Text | Cream `#F4EBD6`; **Gold `#FFC93C` only for the hero chain, SCORE and S8 points**; 1 px `#14110E` text outline on all 8 sides (art bible 4.7). |
| Tabular digits | From the pre-outlined digit atlas (Western and Bengali on one grid). No text shaping per frame. |
| Dim/miss | Missed bonus: value at 50% opacity with a 14×14 ✗ glyph tile and the word, never colour alone. |
| Slot tags | 14×14 plated tile with the number glyph ("1P"…"4P") and the slot P-colour on the frame edge. Number is the non-colour backup. |
| 1UP plate | 28×14 plated tile, Gold frame, "1UP" glyph text; pip pops over 4 ticks. Not a bullet shape. |

**Label sizes**

| Use | Size |
|---|---|
| Header | XL: 24 px Latin / 34 px Bengali, bilingual |
| Hero chain numerals | L: 24 px (1P, 2P, 3–4P) |
| Row labels | S: 12 px Latin / 17 px Bengali, stacked (Bengali on top), 31 px block |
| Row values | S tier digits (11 px cell at the 17 px Bengali height); SCORE and S8 points in Gold |
| Prompts | S tier, chosen language only |

**Layouts** (y from the top; panel covers the HUD strip)

*1P (C = 1), competent clear, CAP HOLD hidden. Worst case adds one 32 px row.*

```
 y    x=0            x=360
   0 +--------------------------------------------+
     | [bn] পর্ব ১ সম্পন্ন            1P  [pips] |  header 44
     | STAGE 1 CLEAR                              |
  44 +--------------------------------------------+
     | +--------+ [bn]/MAX CHAIN                  |
     | |        |                                 |
     | |portrait|        650            [NEW BEST]|  hero block 96
     | | 96x96  |   (Gold 24 px)                  |
 148 | +--------+                                 |
     | [bn]/CRITICAL BREAK  x1          500,000   |  32 each
     | [bn]/LIFE DAMAGE BONUS           100,000   |
     | [bn]/HITS                        872,250   |
     | [bn]/KILLS                        52,000   |
     | [bn]/PARTS                        20,000   |
     | [bn]/BOSS                        100,000   |
     | [bn]/ITEMS                        48,000   |
     |  - - - - - - - - - - - - - - - - - - - - - |
     | [bn]/EARNED                    1,692,250   |
 404 +--------------------------------------------+
     | [bn]/STAGE CLEAR                 100,000   |  bonus rows
     | [bn]/NO DEATH                    200,000   |  32 each
     | [bn]/LIVES LEFT   [pip][pip][pip] 150,000  |
     | [bn]/BOSS PEAK                   845,000   |
 532 +--------------------------------------------+
     | [bn]/SCORE            2,987,250  [1UP]     |  44, Gold
 576 +--------------------------------------------+
     |  (A) skip                                  |  prompt 24
 632 +--------------------------------------------+
```

*2P (C = 2): shared caption band per row, two 180 px value cells.*

```
 y    x=0                 180                 360
   0 +----------------------------------------------+
     | [bn] পর্ব ১ সম্পন্ন / STAGE 1 CLEAR            |  header 44
  44 +----------------------+-----------------------+
     | [1P] LANCER [pips]   | [2P] LEECH [pips]     |  heads 40
     |  [36x36]             |  [36x36]              |
  84 +----------------------+-----------------------+
     |      [bn]/MAX CHAIN                          |  60
     |   650   [NEW BEST]   |   412                 |
 144 |      [bn]/CRITICAL BREAK                     |  48
     |   500,000  x1        |   0                   |
 192 |      [bn]/LIFE DAMAGE BONUS                  |  48
     |   100,000            |   0                   |
 240 |      [bn]/EARNED                             |  48
     | 1,692,250            | 1,102,000             |
 288 |      [bn]/TEAM CHAIN  62%                    |  48
     |   +41,200            |   +38,900             |
 336 |      [bn]/STAGE CLEAR                        |  bonus bands
     |   100,000            |   100,000             |  48 each
 384 |      [bn]/NO DEATH                           |
     |   200,000            |   0   x               |
 432 |      [bn]/LIVES LEFT                         |
     |   150,000            |   100,000             |
 480 |      [bn]/BOSS PEAK                          |
     |   845,000            |   535,600             |
 528 |      [bn]/SCORE                              |  48, Gold
     | 2,987,250  [1UP]     | 1,850,100             |
 576 +----------------------+-----------------------+
     |  P1 (A) skip   P2 (A) skip                   |  prompt 24
 632 +----------------------------------------------+
```

*4P (C = 3 or 4): four 90 px cells, fixed slot order. Values are ≤ 7 digits (85 px) except SCORE.*

```
 y    x=0     90     180     270     360
   0 +--------------------------------------+
     | [bn] পর্ব ১ সম্পন্ন / STAGE 1 CLEAR    |  44
  44 +-------+-------+-------+-------+------+
     | [1P]  | [2P]  | [3P]  | [4P]  |        heads 28
  72 +-------+-------+-------+-------+
     |         [bn]/MAX CHAIN         |  60
     |  650  |  412  |  233  |  118   |
 132 |         [bn]/CRITICAL BREAK    |  48
     | 500,000|   0  |  0    | 0      |
 180 |         [bn]/LIFE DAMAGE BONUS |  48
     | 100,000|  0   |  0    | 0      |
 228 |         [bn]/TEAM CHAIN  58%   |  48
     | +41,200|+38,900|+30,100|+22,500|
 276 |         [bn]/STAGE CLEAR       |  48
 324 |         [bn]/NO DEATH          |  48
 372 |         [bn]/LIVES LEFT        |  64: caption, pips, value
 436 |         [bn]/BOSS PEAK         |  48
 484 +--------------------------------+
     |         [bn]/SCORE   (wide: 2x2 cells of 180)
     |   P1 2,987,250 [1UP]  |  P2 1,850,100
     |   P3 1,402,300        |  P4   988,000     |  71
 555 +--------------------------------+
     |  (A) skip x4 (slot tags)                 |  prompt 24
 600 +------------------------------------------+
```

Row captions are shared: Bengali on top, English below (Localization Rule 19). Digits follow the chosen language and sit on the same fixed grid (art bible 7.5), so a language switch never moves a number.

**Motion**

| Event | Visual | Ticks |
|---|---|---|
| Panel open | fade in in 4 steps, backdrop warm overlay | `open_ticks` 30 |
| Row reveal | slides 4 px up and fades in over 6 ticks; a 1 px Gold underline for info rows | 6 |
| Count-up | digits change per TF2; hero numeral scale +1 step at the end | `W` |
| NEW BEST | 28×14 plated tile "NEW BEST" with a star glyph stamps in 8 ticks; 2 gentle opacity pulses at ≤ 1.5 Hz; none if reduce flashing | 8 + 80 |
| 1UP plate | pops over 4 ticks; pip pops; stays `extend_plate_ticks` 90 | 90 |
| Missed bonus | value fades to 50% and ✗ glyph | 6 |
| Settled | all underlines turn solid; prompt changes to "continue" | 1 |
| Exit | panel fade-out | `exit_ticks` 45 |

**Audio** (UI bus, owned by Audio 24; never competes with the 8-voice bullet pool). Cues requested: `tally_open` (soft sting, calm loop starts), `tally_row` (soft tick per row), `tally_count` (a quiet tick per 4 shown steps, max 8 per row), `tally_hero_end` (low chime), `tally_new_best` (short rising figure), `tally_extend` (1UP jingle, at the crossing tick), `tally_settled` (soft sting), `tally_skip` (one click), `tally_exit`. In co-op each cue plays once (debounced) even if several columns trigger on one tick.

**Localisation keys** (`ui_tally.csv`, bilingual unless marked)

`tally.header.stage_clear`, `tally.header.all_clear`, `tally.note.boss_withdrew`, `tally.row.max_chain`, `tally.row.critical_break`, `tally.row.life_bonus`, `tally.row.hits`, `tally.row.kills`, `tally.row.parts`, `tally.row.boss`, `tally.row.items`, `tally.row.cap_hold`, `tally.row.earned`, `tally.row.team_chain`, `tally.row.score`, `tally.row.stage_clear`, `tally.row.no_death`, `tally.row.lives_left`, `tally.row.boss_peak`, `tally.badge.new_best`, `tally.badge.extend`, `tally.badge.max` (these three are glyph tiles, chosen-language short word), `tally.slot.join`, `tally.slot.continue`, `tally.slot.out`, `tally.slot.ready` (single-language), `tally.prompt.skip`, `tally.prompt.continue`, `tally.prompt.results` (single-language).

> Decided under auto-approve (2026-11-03): shared captions replace the 2×2 grid of cells; labels bilingual, prompts and badges single-language; SCORE uses a wide 2×2 treatment in 3–4P; no flashes at all; reduce-flashing only removes the NEW BEST pulse.

## UI Requirements

This is a UI screen. Requirements:

| Need | Spec |
|---|---|
| Inputs | `pN_fire` press edge per slot and its keyboard key; `start`/`back` pause. Works with keyboard only or gamepad only. No hover, no mouse. |
| Readability | Min text 12 px Latin / 17 px Bengali; 1 px outline; Bengali width reserve +40%; fixed grids for numbers. |
| Accessibility | Nothing relies on colour alone (✗ glyph and word, slot numbers, star on NEW BEST); no flashing; auto-advance can be turned off; the tally is skippable; layouts are fixed so the text-size step of Accessibility (28) does not apply to the grid (it would break 4P); the prompt line scales. |
| Scale | Pre-fit for 360×640; scales by Display scaler; safe at all supported scales. |
| Tip row | Footer, one row: 14x14 icon + up to two S-tier lines (three Bengali), 1 px `#5A5148` edge (high contrast: Cream); absent when no hint is pending (Tutorial 30). |
| Debug | Dev build: overlay with state, tick, per-column state, `n_info`, shown vs real score, pending S8 lines, and a "force skip" key. |

📌 **UX Flag**: run /ux-design for the Stage tally screen (1P/2P/4P layouts, skip/confirm flow, extend moment) before writing epics. Stories cite `design/ux/stage-tally.md`, not this GDD.

## Acceptance Criteria

Defaults used: `open_ticks` 30, `row_gap` 15, `countup_ticks` 30, `chain_countup_ticks` 45, `bonus_lead` 15, `bonus_gap` 30, `skip_lockout` 90, `confirm_lockout` 30, `settle_hold` 300, `exit_ticks` 45, `era_hold_max` 240, `join_hold_max` 600, `bullet_wait_max` 120, `extend_plate_ticks` 90; Scoring `clear_bonus` 100,000, `no_death_bonus` 200,000, `life_value` 50,000, `peak_value` 1,300, `extend_unit` 3,000,000 (thresholds 2,400,000 / 5,400,000), `max_lives` 6; 60 ticks/s; slots 0-indexed.

**Test setup:** `StageTally` is a plain `RefCounted` class with no nodes and no `delta`; `tick()` advances one step and keeps its own tick counter. Inputs: `begin(snapshot)` where the snapshot is a plain data object built by the test (scores, lives, stage breakdowns by source id, pending S8 amounts, entries, `start_len`, best chains, team stats, boss reason, slot states, `is_last_stage`, next era), `press(slot)` (a press edge on the next tick), `set_slot_state(slot, state)`, `set_bullet_count(n)`, `set_paused(bool)`, `hold_release(owner)`. Stubs: a `ScoringLedger` stub that logs `pay_stage_end_line(slot, line)` and applies amounts; a Session stub with `extend_threshold(n)`, `extend_awarded` log and lives; a Save stub with `get_best_chain`. Outputs: the pay log with ticks, per-column `shown(row)` values, state, extend plates log `(slot, tick, count, max)`, `result` (`next`), `state_hash()`. Tests read all numbers from `data/tally_rules.tres` and the scoring/session resources, never literals; quoted numbers are derived from the defaults. Tests (`extends SceneTree`): `tests/unit/test_tally_schedule.gd`, `tests/unit/test_tally_countup.gd`, `tests/unit/test_tally_pay.gd`, `tests/unit/test_tally_input.gd`, `tests/unit/test_tally_layout.gd`, `tests/unit/test_tally_edges.gd`, `tests/integration/test_tally_scoring_session.gd`, `tests/perf/tally_bench.tscn`; manual evidence in `production/qa/evidence/stage-end-tally/`. Names: `test_tally_[scenario]_[result]`.

Tags: [Unit] pure logic, headless · [Integration] real `ScoringLedger` / Session · [Manual] needs a human · [Perf] REF-WEB.

### Start and data (Rules 1–5)

- **AC-01 [Unit] (Rule 1):** `begin` on `stage_cleared` for stage 0 and for the last stage both run the full tally; a GAME_OVER before any boss never calls `begin`.
- **AC-02 [Unit] (Rule 2):** after tick 0, changing the live Scoring/Session values does not change any shown value; the snapshot lives, score and breakdown are used.
- **AC-03 [Unit] (Rule 3):** hits, kills, items and chain events after tick 0 change no shown value and add no pay-log entry or warning.
- **AC-04 [Unit] (Rule 4):** bullets 5 at tick 0 → state Waiting; bullets reach 0 at tick 40 → Opening at tick 40; bullets stay > 0 → at tick `bullet_wait_max` (120) one screen-cancel request (no cause) and Opening.
- **AC-05 [Unit] (Rule 5):** slots Alive, Dead, Continue, Inactive, Selecting → columns for the first three plus a JOIN placeholder; `C` = 3 → 4P layout with the empty slot as a join plate; `C` = 2 → 2P; `C` = 1 → 1P.

### Lines, order and visibility (Rules 6–8)

- **AC-06 [Unit] (Rule 6):** the line order list is exactly the 16 ids in the table; info rows make no Scoring call.
- **AC-07 [Unit] (Rule 7):** 1P with CAP_HOLD 0 → CAP_HOLD hidden and `n_info` = 9 for the competent example; 2P shows MAX_CHAIN, CRIT_BREAK, LIFE_BONUS, EARNED, TEAM_CHAIN only when non-zero in any column; 3–4P has no EARNED; `TEAM_CHAIN` hidden for `C` = 1 and when `eligible_ticks` = 0.
- **AC-08 [Unit] (TF4):** competent example EARNED = **1,692,250**; in 1P it equals the sum of the visible source rows; `SCORE_at_tick0 − SCORE_at_stage_start = earned` for a slot with no continue.

### Schedule and count-up (Rules 9–10, TF1, TF2)

- **AC-09 [Unit] (TF1 example):** `n_info` = 9 → `t_score` **165**, bonus starts **180, 210, 240, 270**, `settle_tick` **300**.
- **AC-10 [Unit] (TF1 range):** `n_info` 1 → settle **180**; `n_info` 10 → **315**; 3–4P with 4 rows → **225**.
- **AC-11 [Unit] (TF2):** from 1,692,250 to 1,792,250, W 30: k = 0 → 1,692,250; k = 15 → **1,742,250**; k = 29 → 1,788,917; k = 30 → **1,792,250**. Hero 0 → 650, W 45: k = 22 → **318**; k = 45 → 650.
- **AC-12 [Unit] (TF2 property):** for 1,000 random `(from, to, W)` from the injected RNG, `shown` never decreases, starts at `from` and ends at exactly `to`; every value is `TYPE_INT`.
- **AC-13 [Unit] (clamp):** a shown SCORE above 999,999,999 is drawn as 999,999,999 while the internal value keeps counting.

### Paying S8 (Rule 11)

- **AC-14 [Integration] (real Scoring + Session):** competent example (0 deaths, 3 lives, peak 650): pay-log ticks **180, 210, 240, 270** with CLEAR 100,000, NO_DEATH 200,000, LIVES_LEFT 150,000, BOSS_PEAK 845,000; final score 2,987,250; four `add_score` calls and four extend checks.
- **AC-15 [Unit] (zero lines):** NO_DEATH not earned → no `add_score` call, no warning, row dim with ✗; lives 0 → LIVES_LEFT makes no call.
- **AC-16 [Unit] (lives snapshot):** an extend paid on BOSS_PEAK raises lives 3 → 4; LIVES_LEFT stayed 150,000.
- **AC-17 [Unit] (skip pays all):** skip at tick 200 (competent) → NO_DEATH, LIVES_LEFT, BOSS_PEAK paid on tick 200 in that order; final score equals AC-14.
- **AC-18 [Unit] (safety flush):** a tally that never calls the pays → on `stage_started` Scoring flushes the four lines in order; the score equals AC-14 and no row is shown.

### Extend moment (Rule 12, TF3)

- **AC-19 [Integration] (TF3 example):** competent example: `extend_awarded` fires on tick 270 (Session); the plate, pip and `tally_extend_shown` fire on tick **280** (shown 2,423,917 ≥ 2,400,000; at tick 279 shown 2,395,750).
- **AC-20 [Unit] (max lives):** lives 6 at the crossing → plate reads `EXTEND · MAX`, no pip; `gained` 0.
- **AC-21 [Unit] (double crossing):** one award crossing 2,400,000 and 5,400,000 → one plate `1UP ×2`; two crossings on different ticks → two plates, the second queued 20 ticks after the first.
- **AC-22 [Unit] (skip merges):** skip over an extend crossing → one plate `1UP ×n` at the skip tick for 90 ticks.
- **AC-23 [Integration] (suppression):** while the tally is active HUD and Audio stubs receive `extend_awarded` and do not present it; they present on `tally_extend_shown`.

### Hero chain (Rule 13, TF5)

- **AC-24 [Unit] (TF5):** entries [112, 187], `start_len` 1 → hero 187; best 112 → NEW BEST at the end of the hero count-up (tick 30 + 45 = 75); best 187 → no stamp; best 0 and chain 5 → NEW BEST; entries [] → "—" and no stamp.
- **AC-25 [Integration] (Save read-only):** `get_best_chain` called once per slot at tick 0; no Save write during the tally (Save AC-43).

### Boss withdrew (Rule 14)

- **AC-26 [Unit]:** reason TIMEOUT → BOSS row hidden, "BOSS WITHDREW" plate shown, STAGE_CLEAR and BOSS_PEAK pay as in AC-14; reason KILLED shows BOSS 100,000.

### Skip and confirm (Rule 15, 16)

- **AC-27 [Unit] (lockout):** press on tick 89 → ignored; tick 90 → column settles.
- **AC-28 [Unit] (edge only):** fire held from tick 0 to tick 200 with no new press → nothing happens.
- **AC-29 [Unit] (per column):** 2P: slot 0 presses at tick 100 → column 0 Settled at 100, column 1 keeps counting and settles on its schedule; no change to column 1's pay ticks.
- **AC-30 [Unit] (confirm lockout):** Settled at 200; press at 229 → ignored; at 230 → Confirmed.
- **AC-31 [Unit] (exit gate):** 2P, P1 Confirmed, P2 never presses → Exiting at P2's settle tick + 300; with `access.tally_auto_advance` false → never exits; both Confirmed → Exiting on the next tick.
- **AC-32 [Unit] (no counted columns):** all columns Continue → exit `settle_hold` after settling.
- **AC-33 [Unit] (other keys):** `start`/`back` pause; Drone and Bomb presses do nothing; a fire press from a slot in Continue is not a tally key.

### Slot states (Rule 17)

- **AC-34 [Unit]:** Continue at tick 0 → no S8 pay, dim column, countdown shown with `ceil`; accepted mid-tally → "READY", score wiped, not counted.
- **AC-35 [Unit]:** a slot going Inactive mid-tally → "OUT", not counted; a pad disconnect → paused and Waiting, not counted until reconnect.
- **AC-36 [Unit]:** a drop-in during the tally → JOIN then READY; no S8, no breakdown, not counted.

### Exit and hand-off (Rules 18–20, 24–25)

- **AC-37 [Unit] (exit):** Exiting lasts 45 ticks; `result.next` = NEXT_STAGE; the last stage → RESULTS.
- **AC-38 [Unit] (era hook):** `to_era` ≠ `from_era` → `tally_exit` emitted; a hold requested and released at 100 ticks → Done after 100 + 45 ticks; a hold never released → Done at `era_hold_max` + 45.
- **AC-39 [Unit] (join hold):** a slot Selecting at exit → hold up to 600 ticks, then the join is cancelled.
- **AC-40 [Integration] (final stage):** last stage → header ALL CLEAR; Session builds the `RunRecord` after Done and it contains the S8 points; `run_ended` fires once, after Done.
- **AC-41 [Unit] (game over):** every counted slot expires from Continue at tick 300 → Done with `next` = RESULTS; paid points stay.
- **AC-42 [Unit] (abandon):** quitting to Title during the tally → no Save call; no `RunRecord`.

### Layout and text (Rules 5, 6; Visual)

- **AC-43 [Manual] (1P):** competent clear in English then Bengali: every label shows Bengali over English; no number clipped; rows fit in 632 px with CAP_HOLD visible. Evidence: screenshots.
- **AC-44 [Manual] (2P / 4P):** 2P and 4P screenshots in both languages: values fit the 180/90 px cells; the 4P SCORE uses the wide treatment; ✗, NEW BEST star and slot numbers are visible in grayscale. Evidence: screenshots + grayscale pass.
- **AC-45 [Manual] (language switch):** switching language during the tally moves no number (fixed grid).
- **AC-46 [Manual] (bullets win):** no enemy bullet is ever covered by the panel (the gate); a forced timeout at 120 ticks shows one cancel.

### Pause, determinism, performance

- **AC-47 [Unit] (pause):** 30 s paused at tick 150 → still 150; resumes counting; `settle_hold` and `exit_ticks` also frozen.
- **AC-48 [Unit] (determinism):** a scripted 4-slot tally (1 skip at tick 120, 1 continue, 1 drop-in, one extend) run twice → `state_hash()` equal every tick, equal pay logs with ticks, equal plate logs.
- **AC-49 [Unit] (skip-invariant score):** the same slot run with no skip and with skip at tick 100 / 200 / 270 ends with the same Session score and the same order of pays.
- **AC-50 [Perf] (REF-WEB):** 4 columns, full schedule, `tick()` ≤ **0.05 ms p99**; no allocations after warm-up; view updates only on value change (≤ 40 label updates per tick); no Bengali shaping during the tally (pre-warm check).
- **AC-51 [Manual] (accessibility):** gamepad-only and keyboard-only complete a tally; no flashing under reduce flashing; the tally with auto-advance off waits.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Is `settle_hold` 5 s right in co-op, and should an "all counted columns Confirmed or any one Confirmed + 90 ticks" rule replace the all-confirmed rule? | UX / playtest | First playable |
| 2 | 4P and 2P hide the per-source breakdown (Scoring AC-56 is met in 1P only). Add a "details" page (a held key) for co-op? | UX | `/ux-design` |
| 3 | Bengali digits at 17 px and 7 digits (85 px) fit a 90 px cell tightly; confirm in the font spike, else switch 4P to stacked two-line cells. | Localization (27) / art | Font spike |
| 4 | Should a player be able to see the `1UP` plate again (a replay of the last line) if they press skip during the crossing? | UX | `/ux-design` |
| 5 | Is it correct that a TIMEOUT boss keeps the 100,000 clear bonus? (Decided yes.) Revisit if players farm a withdrawn boss. | Designer | Playtest |
| 6 | ~~`stage_cleared` timing (`boss_gone` + 30)~~ **Closed 2026-11-03:** Director Rule 24 owns it (`max(boss_gone, D + 90)`). Still open: the planes' exit flight needs a Player plane owner. | Wave director (16) | Its GDD |
| 7 | ~~Era shift hold hook: does Era shift need the panel gone first, or can it draw under it?~~ **Closed 2026-11-03:** the panel's 45-tick fade runs inside Era shift's Dim phase; the era card draws after it (era-shift-and-plane-evolution.md F1). | Era shift (19) | Its GDD |
| 8 | Should the tally support a "Retry/restart stage" for practice modes? (Out of scope for MVP.) | Designer | Target tier |
| 9 | Run-flow ownership of the tally (Session autoload vs a run-flow controller). | → ADR | Before implementation |
| 10 | Save `boss_index` = `stage_index` (Amendment 3) to be confirmed with Save's author. | Save (26) | Amendment review |

> Decided under auto-approve (2026-11-03): all Open Questions above carry the recommended default and can be changed later.
