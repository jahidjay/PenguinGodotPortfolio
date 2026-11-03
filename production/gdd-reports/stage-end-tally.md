# GDD report: Stage-end tally (system 21)

## 1. File written
`design/gdd/stage-end-tally.md` (all required headings, 51 ACs, ASCII mock-ups for 1P/2P/4P at 360x640).

Summary: the tally runs after every stage including the last. It snapshots each slot at `stage_cleared` (tick 0), reveals info rows every 15 ticks (hero Max Chain first, then Critical Break, LDB, 1P source lines, EARNED, co-op team chain), then a SCORE row, then pays the four Scoring S8 lines one at a time (30 ticks apart, order CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK) with an integer count-up. The extend is shown when the displayed score crosses the threshold (competent stage-1 case: pay tick 270, plate tick 280). Skip is per slot on the `pN_fire` press edge (90-tick lockout), second press confirms. It hands off to Session (next stage or Results) with an era-shift hold hook. No name entry, rank or Save writes.

## 2. Key decisions (all auto-approve recommended options)
- Tally on every stage including the last; Session builds the RunRecord after the final tally so S8 points count.
- S8 is paid line by line by the tally via `pay_stage_end_line(slot, line)`; amounts and lives fixed at tick 0 (an extend during the tally does not change LIVES_LEFT). Scoring flushes unpaid lines on `stage_started` as a safety.
- Timeline (defaults): open 30, row_gap 15, countup 30, hero countup 45, bonus_lead 15, bonus_gap 30. Competent 1P: SCORE row 165, bonus starts 180/210/240/270, settle 300. Range 180-315.
- Count-up `shown(k) = from + ((to-from)*k + W/2)/W` (exact at k=W).
- Skip: per slot, fire press edge only (Start pauses per Input Rule 25), 90-tick skip lockout, 30-tick confirm lockout. First press settles that column and pays remaining lines in fixed order; second press confirms. Auto-advance 300 ticks after the last counted column settles; `access.tally_auto_advance` can turn it off.
- Layouts: 1P full-width rows with 96x96 portrait; 2P shared bilingual caption band + two 180 px cells; 3-4P caption band + four 90 px cells (fixed slot order), SCORE in a wide 2x2 treatment, no EARNED row. Per-source breakdown only in 1P.
- Missed bonuses shown dim with a cross glyph. NEW BEST from `get_best_chain` read once at tick 0.
- TIMEOUT boss: BOSS row hidden, "Boss withdrew" plate, clear bonus and boss peak still pay.
- No unused-bomb bonus; no `enemy_escaped` kill ratio.
- Panel opens only at 0 enemy bullets (gate, 120-tick timeout then a cancel).
- Era shift hook: `tally_exit(stage_index, from_era, to_era)` plus `request_exit_hold` / `release_exit_hold` (max 240 ticks). Next-stage start also holds up to 600 ticks while a drop-in is Selecting.
- Continue slot: no S8, a fire press accepts the continue, not a tally key. Drop-in during the tally: JOIN/READY plate, no S8.

## 3. Amendments (apply in the main session)
1. **scoring.md**: Rule 8 / S8 and Dependencies row "Stage tally (21)": S8 amounts computed at `stage_cleared` (lives snapshot) and held as four pending lines per slot; the tally pays each via `pay_stage_end_line(slot, line)`, line in STAGE_CLEAR, NO_DEATH, LIVES_LEFT, BOSS_PEAK; unpaid lines flush in that order on `stage_started` or run end. AC-23/AC-26 stay valid. Add an AC for the flush.
2. **game-events-and-session.md**: (a) AC-05 and the Run flow table: after the final `boss_defeated` the state is Tally then Results (currently AC-05 says "Results (not Tally)"); `run_ended_by = ENDING` set at `boss_defeated`; `run_ended` and the RunRecord at tally Done. (b) Store `critical_breaks` and `len(max_chain_per_boss)` per slot at `stage_started`. (c) Add signals `tally_started`, `tally_row_revealed`, `tally_extend_shown`, `tally_settled`, `tally_new_best`, `tally_exit`, `tally_finished`. (d) Dependencies row "HUD (20), Stage tally (21)": link the tally GDD.
3. **save-settings-high-scores.md**: define `boss_index` = `stage_index` in MVP for `best_chain` / `get_best_chain` (drop-in slots would otherwise misalign); Interactions row 186 and Dependencies row 356: link the GDD ("no GDD" removed).
4. **coop-and-team-chain.md**: Stage tally rows (115, 317): link the GDD; add that stats reset on `stage_started` and are read at tick 0.
5. **input-and-player-mapping.md**: add Stage tally (21) to Dependencies: `pN_fire` press edge is tally skip/confirm; Start/Back pause.
6. **localization.md**: add `tally.*` keys to `ui_tally.csv` (list in the GDD, Visual/Audio); `tally.row.*`, `tally.header.*`, `tally.note.boss_withdrew` bilingual; badges, slot words and prompts single-language. Dependencies row "Stage-end tally (21), no GDD" becomes the GDD link.
7. **design/art/art-bible.md 7.4**: replace "Co-op uses a 2x2 grid of 180 px cells" with the shared-caption layouts; 96x96 portrait is 1P only (36x36 in 2P column heads); "Any button skips" becomes "the fire key skips; Start pauses"; row list adds EARNED, the four S8 lines, TEAM CHAIN.
8. **boss-and-boss-parts.md**: Open Question 4: close for the clear bonus (kept on TIMEOUT); Tally row 445 links the GDD (no longer "not yet").
9. **bombs.md** Open Question 8: closed, no stage-end bomb bonus. **enemy-and-ai.md** Open Question 14 (line 635) and row 411: closed, no kill ratio in MVP.
10. **powerups-and-drops.md**: Open Question 3 (sweep vs tally delay): `stage_cleared` should be `boss_gone` + 30 ticks, which is 210 ticks after `boss_defeated`, above the 75-tick sweep need.
11. **HUD (20) and Audio (24) GDDs when written**: HUD hides while the tally is active and does not present `extend_awarded`; Audio plays the extend cue on `tally_extend_shown`.
12. **Wave director (16) and Era shift (19) when written**: `stage_cleared` timing, `is_last_stage`, next era; `request_exit_hold` / `release_exit_hold` contract.
13. **systems-index.md** row 21: `| 21 | Stage-end tally | P | MVP | 1, 7, 8, 18 (soft), 26 (soft), 27 | **Designed** (pending review) — [GDD](stage-end-tally.md) |`. Progress tracker: GDDs written +1. Bidirectional reminder list: add 21 to Input (2) and Display scaler (4) lists (21 already listed for Save and Localization).
14. **design/registry/entities.yaml**: `stage_end_bonuses` value still says "peak 1000 per point"; update to `peak 1300` (stale vs `peak_value` 1300). Add `stage-end-tally` to `referenced_by` below.

## 4. Registry candidates
```yaml
constants:
  - name: tally_row_gap
    value: 15
    unit: ticks (0.25 s per tally row, art bible 7.4)
    range: "10-30"
    source: design/gdd/stage-end-tally.md (TF1)
    referenced_by: [stage-end-tally]
  - name: tally_countup_ticks
    value: 30
    unit: ticks (point count-up window; hero chain 45)
    range: "15-60"
    source: design/gdd/stage-end-tally.md (TF2)
    referenced_by: [stage-end-tally]
  - name: tally_skip_lockout
    value: 90
    unit: ticks from tally start before a skip press counts (confirm lockout 30)
    range: "45-180"
    source: design/gdd/stage-end-tally.md (Rule 15)
    referenced_by: [stage-end-tally]
  - name: tally_settle_hold
    value: 300
    unit: ticks of auto-advance after the last column settles
    range: "180-900"
    source: design/gdd/stage-end-tally.md (Rule 16)
    referenced_by: [stage-end-tally]
formulas:
  - name: tally_schedule
    expression: "info_start(i) = open_ticks + i*row_gap; t_score = open_ticks + n_info*row_gap; bonus_start(k) = t_score + bonus_lead + k*bonus_gap; settle = bonus_start(3) + countup_ticks"
    variables: [open_ticks, row_gap, n_info, bonus_lead, bonus_gap, countup_ticks]
    output: "settle tick 180-315 (competent 1P: 300)"
    source: design/gdd/stage-end-tally.md (TF1)
    referenced_by: [stage-end-tally]
  - name: tally_countup
    expression: "shown(k) = from + ((to - from) * k + W/2) / W, integer division, k = 0..W"
    variables: [from, to, W, k]
    output: "from at k=0, exactly to at k=W, never decreasing"
    source: design/gdd/stage-end-tally.md (TF2)
    referenced_by: [stage-end-tally]
```
`referenced_by` additions (add `stage-end-tally`): `peak_value`, `stage_end_bonuses`, `extend_unit`, `score_display_digits`, `digit_grouping`, `chain_cap`(no, not used), `team_bonus_share_max`(no). Use: `peak_value`, `stage_end_bonuses`, `extend_unit`, `score_display_digits`, `digit_grouping`, `format_int`, `extend_threshold`, `max_lives`.

## 5. Conflicts
- **Session AC-05 / Run flow**: AC-05 says the last stage goes to Results "not Tally", while the Run flow table says Tally then Results; Scoring F7 expects a stage-2 tally. This GDD follows the table (Amendment 2a).
- **Scoring Rule 8**: S8 "paid when the tally starts" as one batch; this GDD needs it paid line by line to show the extend (Amendment 1).
- **Art bible 7.4**: 2x2 grid of 180 px cells for co-op, "any button skips", row list differs (Amendment 7). Reason: repeating bilingual labels per cell does not fit 180 px cells with 4 rows, and Start already pauses.
- **Registry** `stage_end_bonuses` stale (peak 1000).
- **Save** `boss_index` meaning (Amendment 3).
- No locked-value conflicts (no registry value changed).

## 6. Open risks
- Bengali digits at 17 px, 7 digits (85 px) in a 90 px 4P cell is tight; fallback is stacked cells (Open Question 3).
- 1P worst case (all six source rows visible) uses 632 of 640 px; no spare height for a larger font tier.
- 3-4P omit the per-source breakdown, so Scoring AC-56 ("tester can say where over half the points came from") is satisfied in 1P only.
- Extend timing is tied to the shown score crossing; any change to count-up windows moves the cue tick (AC-19 reads the values).
- The tally depends on provisional contracts with Wave director (`stage_cleared` timing), Era shift (hold hook), HUD/Audio (suppression) and Player plane (exit flight).
- Skip-based pay timing makes pay ticks input-dependent (final score and order are not).
