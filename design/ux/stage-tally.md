# UX Spec: Stage-End Tally

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring, pending `/ux-review`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: the Continue row names the single `CONTINUE_ACCEPT` verb (Fire, shared with the HUD Continue plate); Start never accepts.
> **Journey Phase(s)**: First run (first boss), every stage clear, mastery (see `design/player-journey.md`)
> **Platform Target**: PC (Steam/itch), Web, iOS, Android, Switch. Gamepad primary, keyboard first-class, touch partial (Hold button = Fire). No pointer control (GDD UI Requirements)
> **Template**: UX Spec
> **Filename note**: the skill argument was `stage-end-tally`, but the Tally GDD's UX Flag says stories cite `design/ux/stage-tally.md`, so this file uses that name.
> **Sources**: `design/gdd/stage-end-tally.md` (Overview, Player Fantasy, Rules 1-25, States, Visual/Audio and layouts, UI Requirements, ACs, Open Questions), `scoring.md` (S1-S10), `hud.md` (Tally mode), `input-and-player-mapping.md`, `touch-controls.md`, `accessibility-options.md`, `tutorial.md` (tip row), `era-shift-and-plane-evolution.md`, art bible 2, 4.7, 6.8, 7.3-7.5. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P08, P11, P17, P21, P23 (see `interaction-patterns.md`). The tally is the reference implementation of P17.
> **Style**: `arcade-ui-style.md`
> **Revision 2026-11-03 (UX amendments wave 5)**: MAX_CHAIN hero no longer scales (colour step to bright Gold plus a 1 px edge step at count end, art bible 7.3/7.7 and `arcade-ui-style.md` section 4); reduce-motion row and Open Question 6 updated to match.
> **Revision 2026-11-03**: fixes from `/ux-review`. Decided under auto-approve: footer tip band y 600-640 with a fit rule; skip ignores the touch auto-fire pulse; perf/resolution ACs; "—" null case. GDD amendments needed: Tally Rule 1a (fit rule) and Rule 15 (pulse), see Open Questions 3-4.

---

## Purpose & Player Need

The player has just beaten a boss and wants to know **"what did I do, and what was it worth?"** The tally answers in a fixed order: the chain first (the hero number), then Critical Breaks and bonuses, then the four stage-end awards paid one at a time, then the score. It must be calm, readable at a glance, skippable with one press, fair between co-op players, and it must carry the small celebration of an extra life ("1UP") without any flashing. Missed bonuses are shown (dimmed with a cross) so the player sees what they left behind.

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| After a stage boss dies | Relieved, adrenaline dropping | No bullets on screen; sun low, wreckage smoking |
| After the final boss | Triumphant | Header "ALL CLEAR", prompt "continue to results" |
| After a Boss Rush boss | Focused | The standard tally runs once per boss |
| After a TIMEOUT (boss withdrew) | Slightly cheated | Plate "BOSS WITHDREW"; clear bonus still pays |
| Co-op | Competitive, comparing | Columns side by side; each player controls their own skip |

Arrival is forced by the game (no choice); it is a reward moment, so the design must not feel like a wait.

## Navigation Position

`Stage (boss defeated) -> **TALLY** -> Next stage (via Warning / Era shift) | Results`. Not reachable from menus. Pause is available at any tick. Drop-in and Continue prompts can appear inside it.

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Stage | `stage_cleared` (Wave director 16) | Tick-0 snapshot of score, lives, chains, breakdowns, pending S8 lines, best chains |
| Boss Rush | `stage_cleared` per boss | Same, once per boss |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Next stage | All counted columns Settled and (all Confirmed, or `settle_hold` 300 ticks passed with auto-advance on) | 45-tick fade; may be held by Era shift (up to 240 ticks) or a join pick (up to 600 ticks) |
| Results | Final stage tally Done, or game over during the tally | `RunRecord` is built at Done, so S8 points are included |
| Pause | Start/Back or pad disconnect | Clock freezes |

No exit is one-way within the screen; leaving to Results is the end of the run.

---

## Layout Specification

### Information Hierarchy

1. **Best boss chain** (hero number, Gold, largest element) + NEW BEST
2. **Final SCORE** (Gold) and the 1UP moment
3. **The four stage-end bonuses** (clear, no death, lives, boss peak), including missed ones
4. Critical Break and Life Damage Bonus
5. Per-source breakdown (1P only), EARNED
6. Team chain uptime and bonus (co-op)
7. Skip/continue prompt; tip row (when a hint is pending)

### Layout Zones

Canvas 360x640, covering the HUD strip (the HUD is hidden during the tally). Draw layer 11. Three fixed layouts by column count `C`:

| `C` | Layout | Column width | Portrait | Key fixed geometry |
|---|---|---|---|---|
| 1 | 1P: label left, value right | 336 | 96x96 victory portrait | Header 44 (y0-44), hero block 96 (to y148), up to 8 info rows x 32, bonus rows x32 from y404, SCORE 44 (y532-576), prompt 24 |
| 2 | 2P: shared caption band per row, two value cells | 180 | 36x36 in column head | Header 44, heads 40, MAX CHAIN 60, rows 48 each, SCORE 48 at y528, prompt 24 at y576 |
| 3-4 | 4P: shared caption band, four 90 px cells in fixed slot order | 90 | none (slot tag only) | Header 44, heads 28, MAX CHAIN 60, rows 48, LIVES LEFT 64, SCORE wide 2x2 cells (71), prompt 24 at y 555-600 |

Row captions are shared (Bengali on top, English below). Digits follow the chosen language on one fixed grid, so switching language never moves a number.

**Footer and tip band (decided under auto-approve).** Every layout ends its prompt line at or above y 600. The band **y 600-640 (40 px)** is reserved for the Tutorial tip row: 14x14 icon + text at its script's minimum size. The tip is shown on the Tally **only if it fits the band** (Latin: up to 2 lines at 12 px; Bengali: 1 line at 17 px) **and** the layout leaves the band free (the 1P worst case with CAP HOLD visible pushes the prompt to y 632, so no tip). Otherwise the hint stays pending and appears on the next Pause, which always fits a 3-line Bengali tip (`pause.md`). The band never moves the column grid.

The tally has no lower-third restriction because no bullets are on screen: it opens only when the enemy bullet count is 0 (else it waits up to 120 ticks, then cancels all bullets).

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|
| Header | Text | No | P23 | "STAGE n CLEAR" / "ALL CLEAR" (bilingual, XL) |
| BOSS WITHDREW plate | Info | No | — | Only on TIMEOUT; hides BOSS row |
| Column head | Badge | No | P08 | Slot tag tile ("1P".."4P") + slot colour on frame + plane name + lives pips |
| Victory portrait | Art | No | — | 1P only (96x96); 2P 36x36 |
| MAX_CHAIN hero | Number | No | P17 | Gold, L 24 px; count-up 45 ticks; **at count end a colour step to bright Gold with a 1 px edge step - no scaling** (art bible 7.3 and 7.7: digits never enlarge; `arcade-ui-style.md` section 4); shows "—" when the slot has no chain entry this stage (never Active in the fight) |
| NEW BEST stamp | Tile | No | P17 | 28x14 plated tile + star glyph; stamps in 8 ticks after the hero ends |
| CRIT_BREAK, LIFE_BONUS | Info rows | No | P17 | Chip `x n` where the cell is 150 px or wider |
| HITS, KILLS, PARTS, BOSS, ITEMS, CAP_HOLD | Info rows | No | P17 | **1P only**; hidden if zero across all columns |
| EARNED | Info row | No | P17 | 1P and 2P |
| TEAM_CHAIN | Info row | No | P17 | Co-op only: `uptime_pct` + `team_bonus_points` |
| STAGE_CLEAR / NO_DEATH / LIVES_LEFT / BOSS_PEAK | Paying rows | No | P17 | Always visible; missed = 50% opacity + 14x14 cross glyph + word |
| SCORE | Running total | No | P17 | Gold; appears after info rows, sits below bonus rows |
| 1UP plate | Tile | No | P17 | 28x14, Gold frame; `EXTEND - MAX` when lives are at max; merges as `1UP xn` |
| Column state plates | Badge | No | — | JOIN, READY, CONTINUE n, OUT, per slot state |
| Prompt line | Info | No | — | Glyph + "skip" then "continue"; per-slot in co-op |
| Tip row | Info | No (no focus) | — | Footer: 14x14 icon + up to 2 lines (3 in Bengali); only if a hint is pending |

### ASCII Wireframe

1P (competent clear, CAP HOLD hidden):

```
   0 +--------------------------------------------+
     | [bn] পর্ব ১ সম্পন্ন            1P  [pips] |  header 44
     | STAGE 1 CLEAR                              |
  44 +--------------------------------------------+
     | +--------+ [bn]/MAX CHAIN                  |
     | |portrait|        650            [NEW BEST]|  hero block 96
 148 | +--------+                                 |
     | [bn]/CRITICAL BREAK  x1          500,000   |  info rows 32 each
     | [bn]/LIFE DAMAGE BONUS           100,000   |
     | [bn]/HITS .. KILLS .. PARTS .. BOSS .. ITEMS|
     |  - - - - - - - - - - - - - - - - - - - - - |
     | [bn]/EARNED                    1,692,250   |
 404 +--------------------------------------------+
     | [bn]/STAGE CLEAR                 100,000   |  paying rows 32 each
     | [bn]/NO DEATH                    200,000   |
     | [bn]/LIVES LEFT   [pip][pip][pip] 150,000  |
     | [bn]/BOSS PEAK                   845,000   |
 532 +--------------------------------------------+
     | [bn]/SCORE            2,987,250  [1UP]     |  Gold
 576 +--------------------------------------------+
     |  (A) skip                                  |
     +--------------------------------------------+
```

2P (P2 missed NO DEATH):

```
  44 +----------------------+-----------------------+
     | [1P] LANCER [pips]   | [2P] LEECH [pips]     |
     |      [bn]/MAX CHAIN                          |
     |   650   [NEW BEST]   |   412                 |
     |      [bn]/STAGE CLEAR  100,000 | 100,000     |
     |      [bn]/NO DEATH     200,000 | 0  x NO     |
     |      [bn]/SCORE                              |
     | 2,987,250  [1UP]     | 1,850,100             |
     |  P1 (A) skip   P2 (A) skip                   |
```

---

## States & Variants

**Tally states:** Idle -> Waiting (bullets > 0, up to 120 ticks) -> Opening (30-tick fade) -> Revealing -> Settled -> Exiting (45-tick fade, holds) -> Done. Any state -> Done on game over.

**Column states (per slot):** Hidden -> Revealing -> Settled -> Confirmed; Absent for non-counted slots.

| Variant | Trigger | What changes |
|---|---|---|
| 1P / 2P / 4P layout | `C` columns | See Layout Zones |
| ALL CLEAR | Final stage | Header and prompt "continue to results"; hands to Results at Done |
| BOSS WITHDREW | Last `boss_defeated.reason` = TIMEOUT | Plate shown, BOSS row hidden; STAGE_CLEAR and BOSS_PEAK still pay |
| Missed bonus | Amount 0 | Value 50% opacity + cross glyph + word (never colour alone) |
| Continue at tick 0 | Slot in Continue | Dim column "CONTINUE n"; no S8; a **Fire** press by that slot accepts the continue, not a tally skip. This is the single `CONTINUE_ACCEPT` verb shared with the in-stage HUD Continue plate (Input Rule 24b, confirmed 2026-11-03); **Start never accepts** - it pauses |
| Inactive/OUT | Countdown expires or slot forfeited | Column dims "OUT"; not counted |
| Waiting (pad lost) | Disconnect | Game pauses (see `pause.md`); not counted until resolved |
| Drop-in | Free pad presses Start | JOIN placeholder, then READY; no S8, not counted |
| Settled | All numbers final | Underlines turn solid; prompt changes to "continue" |
| Era change | Next stage is a different era | Exit can be held up to 240 ticks by Era shift; panel fade runs inside its Dim phase |
| Reduce flashing | `access.reduce_flashing` | NEW BEST pulse removed (static border + star remain) |
| Reduce motion | `access.reduce_motion` | Row slide off; the hero's end step is a **static** bright-Gold colour and edge state applied on the last count tick (no animated step); counts still run (see Open Question 6) |
| Auto-advance off | `access.tally_auto_advance` false | Screen waits indefinitely for confirms |
| Touch | TOUCH bound | Skip = Hold button on the touch strip (Open Question 3) |
| Boss Rush | RUSH run | Same screen once per boss; 'next' is the rush refit beat |
| Drill | Flight School | No tally |

---

## Interaction Map

The tally is **fire-only**. Input is read from the recorded simulation input (the Fire press edge), never menu verbs or raw devices, so tally length replays exactly.

| Action | Gamepad | Keyboard | Touch / Pointer | Feedback | Outcome |
|---|---|---|---|---|---|
| Skip (first valid press) | `pN_fire` press edge | The slot's fire key (KB1 Z/Space; KB2 F) | Tap the Hold button (touch) / none (pointer) | Numbers snap to final; 1UP plates for skipped crossings merge | The slot's column settles now; all remaining S8 lines are paid on this tick in fixed order |
| Continue (second valid press) | `pN_fire` press edge, 30 ticks after Settled | Same | Same | Column marks Confirmed | When all counted columns are Confirmed, the tally exits |
| Pause | Start / Back | Enter / Esc | Pause button | See `pause.md` | Clock freezes |
| Drone / Bomb | — | — | — | None | Nothing |
| Accept Continue | Fire (on a CONTINUE column) | | | Column shows READY | Not a tally key |

Rules: presses before tick 90 are ignored (skip lockout); skip is **per column**, so one player's press never changes another's column; the caption of a row appears as soon as any column reaches it. **A press edge is an edge of the Fire held bit only.** The touch auto-fire pulse (sim byte bit 7) and Tap Assist's synthetic presses never count as a skip or confirm, so a touch player with auto-fire on, or a pad player with Tap Assist, cannot skip their own tally by holding.

## Events Fired

| Player Action / Moment | Event / Call | Payload | Persistent? |
|---|---|---|---|
| Tally opens | `tally_started`; HUD strip hides | stage index | No |
| Each S8 line start tick (or skip) | `ScoringLedger.pay_stage_end_line(slot, line)` -> `add_score` | slot, line | **Yes** (score changes; S8 included in `RunRecord`) |
| Score crosses an extend threshold | `extend_awarded` (Session); shown plate on first shown crossing; `tally_extend_shown` for audio | slot, gained | **Yes** (lives) |
| Hero count-up ends with a better chain | NEW BEST stamp | slot | No (records written at Results confirm only) |
| Skip / continue press | Column state change | slot | No |
| Exit | `tally_exit(stage_index, from_era, to_era)`; `tally_finished` | | No |
| Done | Session builds `RunRecord` (final stage) | | Yes |

The tally never writes to Save and never calls `submit_run`. It reads `get_best_chain` once per slot at tick 0.

## Transitions & Animations

| Event | Visual | Ticks |
|---|---|---|
| Panel open | Fade in, 4 steps, warm 55% Cabinet Char overlay on the held last gameplay frame | 30 |
| Row reveal | Slides 4 px up and fades in; 1 px Gold underline on info rows | 6 (spaced 15) |
| Count-up | Integer steps to the exact final value | 30 (points) / 45 (hero) |
| Hero end | Colour step to bright Gold + 1 px edge step (**no scaling**, art bible 7.3/7.7) | — |
| NEW BEST | Plated tile with star stamps in; 2 gentle pulses at 1.5 Hz or less | 8 + 80 |
| 1UP plate | Pops over 4 ticks with a pip pop; stays | 90 |
| Missed bonus | Fades to 50% and cross glyph appears | 6 |
| Settled | Underlines go solid; prompt changes | 1 |
| Exit | Panel fade out | 45 |

Schedule: info row `i` starts at tick `30 + i x 15`; SCORE appears after the info rows; bonus row `k` starts at `t_score + 15 + k x 30`; a column Settles 30 ticks after bonus row 3 starts. No flash anywhere.

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Score, lives, critical breaks (stage), boss chains | Session (1) | Read (snapshot at tick 0) | Immutable after tick 0 |
| Breakdown by source S1-S7, S10; pending S8 | Scoring (8) | Read; **Write** (`pay_stage_end_line`) | The only write |
| Team stats (`team_on_ticks`, `eligible_ticks`, `team_bonus_points`) | Co-op (18) | Read | |
| Best chain per plane/stage | Save (26) | Read | Once per slot at tick 0 |
| Boss defeat reason | Boss (14) | Read | TIMEOUT changes layout |
| Enemy bullet count | Bullet manager (3) | Read | Gate; whole-screen cancel after 120 ticks |
| Extend thresholds | Session (1) F2 | Read | Drives the 1UP moment |
| Slot states | Session / Input | Read | Column plates |
| Next era | Wave director / Era shift | Read | Exit hold |
| `run.assisted` | Accessibility (28) | Read | Suppresses NEW BEST in assisted runs |
| Pending hint | Tutorial (30) | Read | Tip row |
| `access.tally_auto_advance` | Accessibility (28) | Read | Default on; sim-relevant |

Update trigger: everything is read once from the tick-0 snapshot except slot states (every tick) and the pending hint (at Opening). Null handling: no chain entry -> "—"; no best chain stored -> NEW BEST shows for any chain above 0; zero-value info rows hidden when all columns are 0 (Rule 7), else a dim "0"; no counted columns -> exits `settle_hold` after settling.

Flag for architecture: the tally mutates score (S8) and is part of the replay; its length depends on recorded Fire presses (ADR-0003).

## Accessibility

- **Gamepad/keyboard only:** fully operable with Fire alone; no hover, no mouse.
- **Skippable and untimed:** one press settles, a second continues; auto-advance can be turned off so a slow reader can take as long as needed.
- **Colour-independent:** missed bonus = dimmed + cross glyph + word; NEW BEST = tile text + star; slots = number tile + frame pattern + colour; Gold marks hero/score but each is also positional and labelled.
- **No flashing:** the only pulse (NEW BEST) is 1.5 Hz or less and is removed by `reduce_flashing`.
- **Text size:** the grid is fixed so the text-size step does not apply (it would break 4P); the prompt line scales. Minimum text 12 px Latin / 17 px Bengali. (Open Question 5: this means low-vision players cannot enlarge the 4P cells.)
- **Contrast:** Cream on Cabinet Char with 1 px outline; high-contrast option swaps plate edges to Cream.
- **Fairness in co-op:** every column runs the same rules and clock; nobody's numbers are hidden by another player's skip.
- **Screen reader:** no stance exists (pattern library gap 7).

## Localization Considerations

- Labels are bilingual and stacked (Bengali on top, 17 px; English below, 12 px) in a 31 px block; prompts and badges are single-language.
- **HIGH PRIORITY:** 7-digit Bengali numerals at 17 px (about 85 px) in a 90 px cell in 4P fit "tightly" (Open Question 3 in the GDD); confirm in the font spike, else stack two lines.
- **HIGH PRIORITY:** NEW BEST (28x14 tile) and 1UP (28x14) text must fit in Bengali.
- `tally.*` keys are in `ui_tally.csv`; Bengali strings are drafts needing native review.
- Digits follow the chosen language on a shared grid; no layout shift when language changes.
- Names (plane names) are proper nouns.

---

## Acceptance Criteria

- [ ] The tally panel opens with no enemy bullet visible, and never covers a live bullet; if bullets are present it waits, then clears them after at most 2 s.
- [ ] A 1P clear shows the chain as the largest number on screen, in Gold, and the rows appear in the fixed order at about a quarter-second apart.
- [ ] Pressing Fire before about 1.5 s after the tally begins does nothing; the first press after that settles all numbers at once and pays the remaining bonuses in order (clear, no death, lives, boss peak).
- [ ] A skipped tally and a fully watched tally end with the **same** final score for every player.
- [ ] In a 2P game P1 skipping does not change P2's column; the caption of a row appears as soon as either column reaches it.
- [ ] A bonus the player missed (for example NO DEATH after dying) shows at half opacity with a cross glyph **and** the word, and adds 0.
- [ ] When the shown score first reaches the extend threshold, a gold 1UP plate and a new lives pip appear and the extend sound plays on that tick; a skip across two thresholds shows one merged "1UP x2".
- [ ] At maximum lives the plate reads "EXTEND - MAX" and no pip is added.
- [ ] A new personal best chain shows NEW BEST (tile text and star); a run with an assist on never shows NEW BEST.
- [ ] If the boss withdrew, the plate "BOSS WITHDREW" appears, the BOSS row is hidden and the clear bonus still pays.
- [ ] With auto-advance on, the tally ends 5 s after the last column settles; with it off, it waits for every counted player to confirm.
- [ ] In 4P with Bengali selected, every 7-digit value fits its 90 px cell without clipping.
- [ ] Pausing mid-count freezes it; after the resume beat the count continues from the same value.
- [ ] After the final stage the header reads ALL CLEAR and the next screen is Results with the S8 points in the final score.
- [ ] With `reduce_flashing` on, the NEW BEST plate does not pulse; the screen never flashes in any setting.
- [ ] The tally is fully operable with a gamepad only and with a keyboard only.
- [ ] Performance: on the REF-WEB reference device the tally keeps 60 fps in 4P with every row counting at once, and opening it adds no frame over 16.6 ms (Tally GDD perf AC).
- [ ] Resolution: at 360x640 x1 and x3, the 1P, 2P and 4P layouts match the wireframes to the pixel, and the prompt line ends at or above y 600 (except the 1P worst case, which ends at y 632).
- [ ] A player who was never active in the boss fight shows "—" as their chain, not 0.
- [ ] Touch with auto-fire on: keeping a finger on the Hold button never skips the tally; a fresh tap does.
- [ ] A pending Bengali tip longer than one line does not appear on the Tally and appears on the next Pause instead.

---

## Open Questions

Carried from the GDD (all carry a recommended default under auto-approve) plus new UX findings.

1. **Co-op leave rule.** `settle_hold` of 5 s plus "all counted columns confirmed" can leave three players waiting on a fourth who has walked away; the GDD proposes "any one Confirmed + 90 ticks". Recommend adopting after first co-op playtest. (GDD OQ 1)
2. **Co-op breakdown detail.** 2P and 4P hide the per-source rows (HITS, KILLS, etc.); a held-key "details" page is unspecced. Recommend not at MVP; revisit with playtests. (GDD OQ 2)
3. **Touch skip (decided under auto-approve, GDD amendment needed).** Skip/confirm count only edges of the Fire held bit; the auto-fire pulse (bit 7) and Tap Assist presses never count. Amend Tally Rule 15 and note it in Touch/Input 13a. Still open: pointer-only players (Web, mouse only) cannot skip, but they also cannot fly (a pointer cannot bind a slot), so this is acceptable.
4. **Tip band (decided under auto-approve, GDD amendment needed).** Footer band y 600-640 with the fit rule above; Tally Rule 1a should add "shown only if it fits the band, otherwise deferred to Pause". The 1P diagram's prompt label (y 576-632) is read as a 24 px prompt at y 576-600 plus the worst-case 32 px row shift; art-director to confirm.
5. **No text enlargement** (fixed grid) conflicts with a low-vision user: min 12 px Latin / 17 px Bengali. Decide whether a high-contrast/large-digit option is needed for the tally.
6. **Reduce motion** is not defined for the tally in the Accessibility GDD (row slide, hero end step). Spec assumes the row slide turns off and the hero's end step becomes a static colour/edge state; counts are functional and stay. *(Updated 2026-11-03, wave 5: there is no hero **scale** step any more - the end accent is colour plus a 1 px edge, which satisfies art bible 7.3/7.7. Only the animation of that step is affected by `reduce_motion`.)*
7. **1UP replay** if the player skips during a crossing: recommended default is no replay, the merged plate shows for 90 ticks after the skip. (GDD OQ 4)
8. Bengali 7-digit width at 17 px in a 90 px cell (font spike). (GDD OQ 3)
9. ~~Journey map / accessibility tier missing~~ **Closed 2026-11-03:** `design/player-journey.md`; tier Comprehensive (`design/accessibility-requirements.md`).
10. No analytics events are defined (for example average skip time, how often NEW BEST is seen).
