# UX Spec: Results, Name Entry and Board After Run

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring, pending `/ux-review`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (final doc closeout)**: UI cue ids rewritten to the canonical `sfx_ui_*` form; Open Question 17 closed (`ui.rank` resolves to `sfx_ui_new_best`).
> **Revision 2026-11-03 (UX consistency check, wave 5)**: Open Questions 1, 2, 4, 4a, 4b and 8 updated to **Applied / Closed** now that the Menus, Save and pattern-library amendments have landed; the new string keys are marked registered (Bengali pending native review).
> **Journey Phase(s)**: `design/player-journey.md` steps 11 (Game over or all clear: Results, name wheel) and 12 (Board); end of every run
> **Template**: UX Spec
> **Platform Target**: PC (Steam/itch), Web, iOS/Android, Switch. Gamepad primary and fully supported; keyboard full; touch partial (solo only); pointer on PC/Web for button plates.
> **Sources**: `design/gdd/menus-title-plane-select.md` (Rules 34-38; F4, F5, F10; V/A table and mock-ups; Results/name-entry edge cases; AC-36..AC-44, AC-47, AC-53; Open Questions), `save-settings-high-scores.md` (Rules 4, 5, 9, 12-14, 20, 21, 32; F3; edge cases), `game-events-and-session.md` (RunRecord, `run_ended_by`, F6, F7, `run.assisted`), `scoring.md` (9-digit display clamp), `online-leaderboards-boss-rush.md` (Rules 1, 29, 32, edge cases, UI list; Stretch), `tutorial.md` (Rule 25 offer line), `accessibility-options.md` (Rules 8, 23, 31, `untimed_menus`, PRACTICE edge case), `touch-controls.md` (Rule 2, TF7, TF8), `input-and-player-mapping.md` (Rule 6, `typed_char`), `localization.md` (F3), `.claude/docs/technical-preferences.md`, `stage-tally.md`, `coop-and-team-chain.md` (Rule 18), `design/accessibility-requirements.md` (tier COMPREHENSIVE), `arcade-ui-style.md`. Where this spec and a GDD disagree, the GDD wins; where two GDDs disagree, this spec picks the reading in "Resolved conflicts" below and files an amendment.
> **Patterns used**: P01, P02, P05, P06, P07, P08, P11, P15, P16, P21, P22 (see `interaction-patterns.md`). P15 was written from a skim; the Menus GDD (Rule 36, F4, F5) is the authority and this spec follows it.

> Revised 2026-11-03 after /ux-review: 3-4P score plate rule, 4P/3P name-wheel layout, one team rank for co-op, "not placed" treated as unranked (Save F1), MISSION COMPLETE vs ALL CLEAR settled, unknown-plane handling, untimed pad-loss hold, input carry-over guard, pointer scope, contrast ratios, new states/keys/ACs.

Three screens, one flow: `Tally Done -> RESULTS -> NAME ENTRY (ranked runs only) -> BOARD AFTER RUN -> Lobby | Title`. Each is a section below inside Layout, States and Interaction Map.

**Resolved conflicts (this spec's reading; amendments filed in the review report)**

| Conflict | Decision |
|---|---|
| ENDING heading: "MISSION COMPLETE" (Menus) vs "ALL CLEAR" (Tally) | Two different moments, two words, on purpose. **ALL CLEAR** is the final-stage banner on the Tally (bilingual, XL). **MISSION COMPLETE** is the run verdict on Results (single-language, L tier). Both stay; never swap them |
| Co-op rank per row (Menus mock) vs one team rank (Save Rule 5, Co-op Rule 18) | One team rank, in the rank strip, once. Per-player rows never carry a rank |
| "Ranked if >= 1" (Save Rule 5 prose) vs "top 10" (Online Rule 1) | Save F1 is the formula: ranked = score >= `min_ranked_score` AND `rank_index` < `board_size`. `preview_rank` returns a rank or "not placed"; Results treats not placed exactly like unranked (no Name entry) |
| 3-4P column 80 px vs 9-digit score | D12 plate (78 px Western) is mandatory in 3-4P; fallback rule in Layout |
| No 4P name-wheel layout | 2x2 grid, 3P bottom block centred (Layout) |
| Entries for unknown planes unreachable | A live run always has a known plane; unknown ids exist only in loaded entries. Handling in States and Data Requirements; the "Other" chip belongs to `high-scores.md` |

---

## Purpose & Player Need

| Screen | The player wants to know / do | Design answer |
|---|---|---|
| Results | "How did I do, and where does that put me?" | Final numbers per player, the rank, the badges earned (C, 1CC). Cold and quiet after GAME OVER, warm after the ending. Not a second tally: no count-up, no new scoring |
| Name entry | "Put my name on it, fast, without anyone waiting on me" | One 3-letter wheel per player, all editing at once, one shared timer, safe defaults (the last-used initials) so doing nothing never loses the score |
| Board | "Is it really there? Again!" | The run's board with the new row marked, and the next action under the thumb: PLAY AGAIN is the default focus |

Promise to the player (Menus pillar "Honest"): a timeout, a dead pad or a failed write never costs them the score. Game over to a new run is 3 presses: Confirm (Results), Confirm (Board), Start (Lobby) (Menus overview).

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| Results after GAME OVER | Deflated or itching to retry | Cold desaturated dusk, one warm focal light, sober music loop. Must not scold. Hands off quickly |
| Results after ENDING | Proud | Warm tally light, same layout. The 1CC tile is the peak moment |
| Results after a PRACTICE (assisted) run | Learning | Shows "PRACTICE - not ranked" instead of a rank; never shames |
| Name entry | Excited, competitive in co-op | Short, loud-feeling task; wants to finish before the timer, not to read |
| Board after run | Wants "one more go" | PLAY AGAIN default; the highlighted row is the reward |
| Any of them after a Save failure | Anxious | The Board still opens and still shows the row for this session, plus a never-dropped toast |

Arrival is forced by the game. Nothing here is under time pressure except name entry (30 s, shared).

## Navigation Position

`Stage (final boss or game over) -> Tally -> **RESULTS** -> **NAME ENTRY** (ranked only) -> **BOARD** -> Lobby | Title`. ABANDONED (Quit to title) never opens Results. Not reachable from Title; the Board *content* is the same screen as Title > HIGH SCORES (own spec) but opened on the run's board with a different action pair. Pause is not available on Results or Name entry (Accessibility Rule 31).

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Tally Done (final stage) | `tally_finished`, `RunRecord` built (S8 points included) | `RunRecord`, `run_ended_by`, slot states, aggregates (Session F6) |
| Game over during a stage or tally | Last slot out, no continue | Same |
| Drop-in picker open when the run ends | Pick cancelled, Results starts | Same |
| Results -> Name entry | Confirm after lock, `preview_rank` says ranked | Rank, per-slot `last_initials` |
| Results -> Board | Confirm after lock, run unranked (score 0, PRACTICE, or not placed) | `submit_run` already called once |
| Name entry -> Board | All slots Done, or timeout | `submit_run` called once with the initials |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Lobby | PLAY AGAIN (Confirm or Start) | The pressing device is bound to Lobby slot 0 (`bind_device`). Pointer/touch rules in the Interaction Map |
| Title | TITLE (Cancel on pad/keyboard, plate on pointer/touch) | Bindings cleared on Title (AC-43) |

No exit goes back to Results or Name entry. Once a score is submitted, initials cannot be changed.

---

## Layout Specification

### Information Hierarchy

**Results**
1. Result heading (GAME OVER / MISSION COMPLETE) and mood
2. Per-player score and best chain (Gold; best chain is the hero number, 24 px)
3. Rank from `preview_rank` (or "PRACTICE - not ranked"), with NEW tag
4. Badges: C x n, 1CC
5. Critical Breaks, stage reached
6. Co-op team block (team score, team chain, team Critical Breaks), "Before continues"
7. Prompt (Next), lock indicator; tutorial offer line; Upload status (Stretch)

**Name entry**: 1. The player's own wheel and focused slot. 2. Timer. 3. Done state of others. 4. Prompt.

**Board**: 1. The highlighted new row. 2. PLAY AGAIN / TITLE. 3. Tabs and filter. 4. Other rows. 5. Detail strip, toast.

### Layout Zones

Canvas 360x640, menu CanvasLayer, no play-field bullets exist. Positions are integers.

**Results, 1P and 2P** (rows 328x56 from the V/A table; margin 16)

| Zone | y (px) | Contents |
|---|---|---|
| Heading | 16-64 | Result heading, L tier, centred |
| Rank strip | 72-100 | `RANK {n}` + NEW tag (one rank for the whole run, also in co-op: the team rank on the co-op board); or "PRACTICE - not ranked"; or "Not in top {n}" (score >= 1 but not placed); or empty (score 0, no text) |
| Slot rows | 112 + k x 64 | 328x56 each, 8 px gap (1P: one row; 2P: two rows) |
| Team block | after rows + 12 | Co-op only: divider, team score, team chain, team CB, "Before continues" line (only if any slot continued) |
| Footer line | 520-548 | Tutorial offer (GAME_OVER only, once), Upload status (Stretch) |
| Toast | 560-584 | Strip 328x24 (P11) |
| Prompt bar | 600-640 | Glyph + "Next"; lock bar while locked |

Row interior (left to right): P-tag tile 28x20 with slot frame (P08) and plane icon 14x14 (50 px) | score, S tier, Gold, right-aligned in 107 px, with CB and stage `n/N` on the second line (150 px) | badge tiles C / 1CC 14x14 | best chain hero, L 24 px Gold, right edge (80 px, label above in S).

**Results, 3P and 4P** (columns 80x220; margin 8, gap 8; x = 8, 96, 184, 272)

| Zone | y (px) | Contents |
|---|---|---|
| Heading, rank strip | 16-64, 72-100 | As above |
| Columns | 112-332 | One per played slot, in slot order. 3P: three columns centred (x = 52, 140, 228) |
| Column interior | 0-24 tag tile with frame; 28-48 plane icon; 56-76 score (D12 digits, 78 px); 84-128 CHAIN label + hero number; 136-168 CB label + value; 176-192 badge tiles; 196-216 stage `n/N` |
| Team block | 344-420 | Full width: team score, team chain, team CB, "Before continues" |
| Footer, toast, prompt | As 1P/2P | |

**Score plate rule in 3-4P (column budget 80 px).** The score is drawn in the D12 tier: `plate_w = 9 x 8 + 2 x 3 = 78 px` for 9 digits with Western grouping (Localization F3), centred in the column (1 px spare each side; the 1 px text outline is inside the cell). Digits are numerals and stay on the fixed grid whatever the `text_size` step, and Bengali digits use the same widths. If the font spike shows a plate wider than 80 px (for example `digit_grouping = INDIAN` adds one separator, 81 px), the column falls back to D10 for all columns at once (never a mixed row, never clipped, never wrapped). A score shorter than 9 digits uses the same tier so the four columns line up. Team score and "Before continues" sit in the full-width block and use the S tier (107 px plate), clamped at 999,999,999 like every displayed score (Scoring F8).

**Name entry**

| Zone | y (px) | Contents |
|---|---|---|
| Heading + timer | 16-48 | Heading M tier left/centre; timer top right (`ceil(entry_left / 60)` as `00:SS`, F5), or "No time limit" under `untimed_menus` |
| Rank line | 52-72 | `RANK {n}` of the board (read-only) |
| Wheel blocks, 1P | y 120 | One block centred |
| Wheel blocks, 2P | y 120 | Two blocks 160 wide at x = 16 and 184 |
| Wheel blocks, 3P/4P | y 104 and 264 | **2x2 grid** (decided; **applied to the GDD 2026-11-03, wave 5**: Menus Rule 36 and the V/A "Name wheel" row now carry this layout), blocks 160x136 at x = 16 / 184 (P1 P2 on top at y 104, P3 P4 below at y 264, ending at y 400). Four 96 px wheels cannot sit side by side in 328 px. **3P:** P3 is centred in the bottom row at x = 100, so the grid never shows an empty cell. Slot order is fixed (P1 top-left, P2 top-right, P3, P4), never reordered when a slot is Inactive or has no device |
| Wheel block interior | | Slot tag (P08, 90x20) with the slot's device glyph 14x14 to its right; chevron up 12x8; three plated slots 28x36 with 6 px gap (96 px wide); chevron down; state line (EDITING / DONE + check glyph). Interior height about 104 px of the 136 px block, so nothing touches the block edge in Bengali (+25% height) |
| Rank line, 3P/4P | 52-72 | Same as 1P/2P. The 3P/4P grid starts at y 104, so the heading, timer and rank line never overlap a block |
| Toast | 560-584 | |
| Prompt bar | 600-640 | Device glyphs: change, move, OK. With one editing slot the bar shows that slot's device family; with two or more slots on different device families the bar shows verbs only, and each block shows its own device glyph (above), so no glyph is ever wrong for a player |

**Board after run** (High scores layout, shared with the Scores screen)

| Zone | y (px) | Contents |
|---|---|---|
| Tabs | 16-40 | Solo, Co-op, Records (24 px); run's tab active |
| Filter | 44-68 | Plane filter (solo) set to the run's plane; "All" on co-op; TOUCH label chip if the board is a touch board |
| Notice line | 72-92 | Only when nothing was added: "Not ranked" or "PRACTICE - not ranked" |
| Rows | 96-376 | 10 x 28 px; row = rank, initials, "+N" tile, plane icon, score, stage, badges (249 px of 328, F10) |
| Detail strip | 384-440 | Focused row details |
| Actions | 480-512 | PLAY AGAIN and TITLE plates, 156x32 each, 16 px gap |
| Toast | 560-584 | |
| Prompt bar | 600-640 | |

### Component Inventory

| Component | Screen | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|---|
| Result heading | Results | Text | No | - | `menu.results.game_over` / `menu.results.ending`; single-language |
| Slot row / column | Results | Info | No | P08 | Frame pattern + pips + "P{n}" + colour (G3) |
| Best chain hero | Results | Number | No | - | Gold, L 24 px, no count-up |
| C tile | Results, Board | Badge | No | - | "C" + count if more than 1; 14x14 plated tile, never a ring |
| 1CC tile | Results, Board | Badge | No | - | ENDING only, per slot (`one_credit_clear`) |
| Rank plate | Results, Name entry | Info | No | - | `RANK {n}` + NEW tag (text + star glyph, static). One per run; in co-op it is the team rank |
| PRACTICE plate | Results, Board | Info | No | - | "PRACTICE - not ranked"; replaces rank |
| Not-placed plate | Results, Board | Info | No | - | "Not in top {n}"; replaces rank when `preview_rank` says not placed |
| Controller-lost plate | Name entry | Info + action | Yes (untimed only) | **New pattern, flag for `interaction-patterns.md`** | In a block whose pad vanished under `untimed_menus`: "P{n} controller lost" + DROP plate (text + glyph) |
| Device glyph | Name entry | Info | No | - | 14x14, next to the slot tag |
| Team block | Results | Info | No | - | Co-op only |
| Lock bar | Results | Feedback | No | - | 30-tick bar; Confirm ignored until full |
| Offer line | Results | Info | No | - | One line, GAME_OVER only, first time (Tutorial Rule 25) |
| UPLOAD action + status (Stretch) | Results | BUTTON + INFO | Yes | P22 | Hidden unless eligible (see Open Question 9) |
| Name wheel (per slot) | Name entry | Input | Yes | P15 | 3 plated slots 28x36, focus 3 px Cream border + arrow, alphabet of 38 (F4) |
| Chevrons | Name entry | Click targets | Yes | P06 | Visual 12x8, hit area 28x24 (G5); touch variant larger |
| State line | Name entry | Info | No | - | EDITING / DONE with check glyph (text + glyph, not colour) |
| Shared timer | Name entry | Info | No | - | Seconds, plus a 4-step bar in the last 10 s |
| High-score list | Board | List | Yes (focus) | P16 | New row: static 3 px Cream border + arrow + NEW tag |
| PLAY AGAIN | Board | BUTTON | Yes | P01 | Default focus |
| TITLE | Board | LINK | Yes | P05 | |
| Toast strip | All | Feedback | No | P11 | Save notices never dropped |
| Prompt bar | All | Info | No | - | Glyphs per active device |

### ASCII Wireframes

Results, 2P game over, P2 continued once (cold dusk):

```
+----------------------------------------------------------+ y0
|                    GAME OVER                             | y16 heading
|                RANK 2 [*NEW]                             | y72 rank
| +------------------------------------------------------+ | y112
| |[P1]<L>  4,200,000          [1CC?no]            187   | | best chain 24px Gold
| |  CB 2   Stage 2/2                              CHAIN | |
| +------------------------------------------------------+ |
| |[P2]<E>    900,000          [C]                  96   | | y176
| |  CB 0   Stage 2/2                              CHAIN | |
| +------------------------------------------------------+ |
| ---------------------------------------------------------|
|  TEAM 5,100,000    CHAIN 187    CB 2                     |
|  Before continues: 5,700,000                             |
|                                                          |
| New? Try Flight School from the title.                   | y520 offer (once)
| [toast]                                                  |
| [A] Next  [====lock====]                                 | y600
+----------------------------------------------------------+
```

Results, 4P (columns 80 px):

```
| [1P]    | [2P]    | [3P]    | [4P]    |   y112
| <L>     | <E>     | <S>     | <B>     |
| 4200000 | 900000  | ...     | ...     |   D12 digits (grouped in reality)
|  CHAIN  |  CHAIN  |         |         |
|   187   |   96    |         |         |   24 px Gold
|  CB 2   |  CB 0   |         |         |
|  [1CC]  |  [C]    |         |         |
|  2/2    |  2/2    |         |         |
|  TEAM 9,900,000   CHAIN 187   CB 2                  |   y344
```

Name entry, 2P (P1 editing, P2 done):

```
|            ENTER YOUR INITIALS             00:23      |
|                 RANK 2                                |
|   [P1 solid]                [P2 dashed]               |
|    ^   ^   ^                  ^   ^   ^              |
|  [ K ][ A ][ Z ]            [ L ][ E ][ E ]           |
|    v   v   v                  v   v   v              |
|   EDITING                    DONE [v]                 |
| [Up/Down] Change  [Left/Right] Move  [A] OK           |
```

Board after run (Solo / Lancer, third row new):

```
| [Solo*] [Co-op] [Records]                             |
| filter: Lancer                                        |
|   1  AAA  <L>  9,100,000   2  [1CC]                   |
|   2  KAZ  <L>  4,200,000   2  [1CC]                   |
| >[ 3  KAZ  <L>  4,100,000   2  [C] ]<  NEW            | 3 px border + arrow
|   ... (10 rows x 28 px)                               |
|   [ > PLAY AGAIN ]   [ TITLE ]                        | y480
| [A] Play again   [B] Title                            |
```

---

## States & Variants

**Flow states:** `Results (Locked -> Revealing -> Settled) -> [NameEntry (Editing...)] -> Submitting (one tick) -> Board`.

| Variant / State | Trigger | What changes |
|---|---|---|
| Results: Locked | Ticks 0-29 | Confirm ignored (`sfx_ui_deny` is not played; silent). Lock bar fills in 4 steps |
| Results: Revealing | From tick 0 | Heading at 0, rows every 15 ticks in slot order, then team block, then rank (rank sound once) |
| Results: Settled | All shown, or Confirm after lock | First valid Confirm skips to the end state; the next Confirm leaves (Rule 35) |
| GAME OVER | `run_ended_by = GAME_OVER` | Cold desaturated dusk, one warm light; heading text differs from ENDING (not colour alone); sober loop |
| ENDING | `run_ended_by = ENDING` | Warm tally light; heading `menu.results.ending` ("MISSION COMPLETE"; "ALL CLEAR" is the Tally banner that precedes it, not this heading); 1CC tiles possible |
| Results: record missing | `RunRecord` null or a slot's data missing | Heading from `run_ended_by`, "-" in every missing field, no rank, treated as unranked; Confirm still works; never a blank screen or crash |
| 1P / 2P / 3P-4P | Played slot count | Rows or columns as in Layout Zones |
| Continued slot | `continues_used > 0` | "C" tile, "C x n" if n > 1. "Before continues" line (display only) appears once for the team |
| 1CC | `one_credit_clear` | 1CC tile on that slot only; never on GAME_OVER |
| Inactive at end | Slot `final_state = Inactive` | Still a played slot: row shown, dimmed state word "OUT" beside the tag |
| Ranked | `preview_rank` returns a place | Rank plate, then Name entry after Confirm |
| Unranked, score 0 | Board score 0 | No rank text, no Name entry, `submit_run` on Confirm, Board with "Not ranked" notice. Records still update |
| Not placed | Board score >= 1 but `preview_rank` = not placed (full board, Save F1) | Rank strip "Not in top {n}", no Name entry (no initials are asked for a row that will not be stored), `submit_run` on Confirm, Board with "Not in top {n}" notice and no highlight. Records still update. Not uploaded (Online Rule 1) |
| Co-op rank | 2-4 played slots, ranked | One team rank in the rank strip; the row for each slot shows no rank; Name entry asks every played slot for initials and the Board shows one row with the lead player's initials and "+N" |
| Unknown plane id | A loaded entry or record carries a plane id the build does not know | Generic plane icon plus the raw id in Latin (Menus Rule 40). A live run never has one; if the RunRecord does (debug), Results shows the same icon and id and the Board opens on `solo/<id>` |
| PRACTICE | `run.assisted` | "PRACTICE - not ranked" in the rank strip; no Name entry; Board notice repeats it; `last_initials` untouched |
| Touch run | Slot 0 bound to TOUCH | Same layout; plates sized `touch_item_h`; Board is the `/touch` board with a TOUCH chip |
| Offer line | GAME_OVER, `tutorial.offered` false and `tutorial.complete` false | One footer line, then `tutorial.offered` is set |
| Name entry: Editing | Slot with a connected device | Wheel live, focus on first slot |
| Name entry: Done | Confirm on last slot, Start anywhere, timeout, no device, device lost | Wheel locked, DONE + check glyph, initials fixed |
| Name entry: untimed | `access.untimed_menus` | Timer replaced by "No time limit"; no auto-submit; ends when every slot is Done |
| Name entry: last 10 s | `entry_left <= 600` | 4-step bar under the timer; no colour change needed, no flash |
| Pad lost during entry (timed) | Disconnect of a slot's pad | That slot becomes Done with `last_initials`; toast "P{n} controller disconnected"; no pause (Menus edge case) |
| Pad lost during entry (`untimed_menus`) | Disconnect of a slot's pad | The slot is **not** finished (Accessibility edge case: entry stays open until the pad returns or the player chooses Drop). Its block shows "P{n} controller lost" with a DROP plate; the wheel is frozen with its current text. Pad returns: the wheel resumes. DROP (Confirm by any other connected slot, or by any connected device in a solo run) marks the slot Done with `last_initials`. Other slots keep editing. If no device is connected at all, the screen waits (no timeout) |
| Name entry opening | Results Confirm/Start consumed | The press that opened Name entry is consumed; a held button is ignored until released, so it never marks a slot Done or moves a wheel |
| Keyboard typing | Exactly one keyboard slot editing | `typed_char` sets and advances; two keyboard slots (KB1+KB2) disable typing |
| Board: new row | Ranked and stored | Row highlighted, NEW tag, list scrolled so it is visible |
| Board: nothing added | Unranked / PRACTICE | Notice line; no highlight; default focus still PLAY AGAIN |
| Board: Save failed | `save_failed` on submit | Board opens anyway; the entry is shown for this session; error toast with `sfx_ui_save_error`, never dropped |
| Board: no Save | MVP before Vertical Slice | "No scores yet" INFO row |
| Reduce flashing / pulsing | Options | NEW tag and focus pulses off (static border + star remain) |
| Reduce motion | Option | Rows appear in place (stagger kept), wipe becomes a cut, toasts appear without slide |
| Online (Stretch) | Eligible run | UPLOAD action and claim status on Results (Open Question 9) |
| Landscape on touch | Width > height | Game-level rotate prompt (Touch GDD); not designed here |

---

## Interaction Map

Input methods: gamepad (primary), keyboard, touch (solo), pointer (plates only). Verbs per G1, except raw typed characters in Name entry.

### Results (shared: any bound slot, last input wins)

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Screen | Confirm before tick 30 | Fire / Start | Enter, Z, Space | Click Next plate | None (silent) | Ignored |
| Screen | Confirm, rows still revealing | Fire / Start | same | same | Rows snap to final | Settled |
| Screen | Confirm, Settled | Fire / Start | same | same | `sfx_ui_confirm`, wipe | Ranked: Name entry. Else: `submit_run`, Board |
| Screen | Cancel | Bomb / Back | Esc, C | none | None | Nothing. Results is not skippable backward |
| UPLOAD (Stretch) | Activate | Drone | `drone` key | Click / tap | Status tick | Marks the run for upload; status line updates |

Any bound slot can confirm for everyone. Nothing here is per-slot.

### Name entry (owned per slot: each slot reads only its own device)

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Wheel | Next / previous character | Up / Down (repeat 18/6 ticks) | Up / Down | Tap chevron above / below | `sfx_ui_name_tick`, pitch step per slot | `idx +/- 1 mod 38` (F4) |
| Wheel | Move slot | Left / Right | Left / Right | Tap a slot | `sfx_ui_nav_tick` | Left on slot 1 and right on slot 3 do nothing |
| Wheel | Type a character | n/a | Latin letters, digits, `-`, `.` | n/a | Tick | Sets focused char, advances focus. Lowercase stored upper case. `!`, space, Bengali letters: `sfx_ui_deny`, no change |
| Wheel | Done | Fire on last slot; Start anywhere | Enter on last slot; Start anywhere | Tap OK plate | `sfx_ui_confirm`, DONE + check | Slot locked |
| Wheel | Step back | Bomb / Back | Esc, C | Tap back plate | `sfx_ui_cancel` | Focus one slot left; on slot 1 does nothing |
| Slot | Confirm on slot 1 or 2 | Fire | Enter | - | `sfx_ui_nav_tick` | **Assumed:** advances focus right (Open Question 5) |

Start is the "Done" shortcut here and finishes **only the pressing slot's** wheel; Esc/F5/Tab are never used (browser-reserved).

Focus order inside one wheel: slot 1 -> slot 2 -> slot 3 (Right), reverse with Left; Up/Down change the character and never move focus. There is no focus travel between wheels: each slot owns one wheel and reads only its own device. A mouse is not bound to any slot, so mouse clicks on chevrons and slots do nothing; "tap" in the table applies only to a slot bound to TOUCH (solo). Nothing in Name entry needs pointer precision on a pad.

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Controller-lost plate (untimed only) | DROP | Fire / Start on any other connected slot | Enter on KB slot | Tap (touch solo) | `sfx_ui_confirm`, DONE + check | Frozen slot becomes Done with `last_initials` |

### Board after run (shared)

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Actions | Move focus | Left / Right | Left / Right | Hover moves focus | Focus border + arrow | PLAY AGAIN <-> TITLE |
| PLAY AGAIN | Activate | Fire / Start (also on any focus) | Enter, Z, Space | Click / tap | `sfx_ui_confirm`, wipe | Lobby; **pressing device bound to slot 0**. Pointer: Lobby with all slots Empty. Touch: binds TOUCH to slot 0. If a pad has disconnected since, that slot is Empty and a toast shows |
| TITLE | Activate | Fire on TITLE | Enter on TITLE | Click / tap | Wipe | Title; bindings cleared |
| Screen | Cancel | Bomb / Back | Esc, C | TITLE plate | `sfx_ui_cancel` | Title (P05) |
| List | Browse | Up from actions enters rows | Up / Down | Wheel / drag scrolls | Focus tick | Detail strip updates |
| Tabs | Switch | LB / RB | PgUp / PgDn | Click tab | Tick | Other board; the highlight shows only on the run's board |

Joining after PLAY AGAIN happens in the Lobby (P09). Only the pressing device is carried over; 2-4 player groups re-join there.

## Events Fired

| Player Action / Moment | Event / Call | Payload | Persistent state? |
|---|---|---|---|
| Results opens | `SaveStore.preview_rank(record)` (read-only), once | `RunRecord` | No |
| Results Confirm (unranked, incl. not placed) | `submit_run(record, initials)` once (initials = defaults) | record | **Yes**: `scores.json` write; personal records updated (Save Rule 13) |
| Name entry opens | Start of `name_entry_ticks` | - | No |
| Wheel change | `sfx_ui_name_tick` | slot | No |
| Slot Done / timeout / device lost | Slot state change | slot, initials | No |
| All Done or timeout | `submit_run(record, initials)` **once** | per-slot initials | **Yes**: `scores.json`; `profile.last_initials` set and settings marked dirty (flag for Save) |
| Submit result | Board opens with run's `board_id` | board id (with `/touch` suffix on touch runs) | No |
| `save_failed` | Toast (never dropped) + `sfx_ui_save_error` | file, reason | No (retried on next commit) |
| Tutorial offer shown | Sets `tutorial.offered` | - | **Yes** (`settings.json`, `tutorial.*`): flag for Save (Open Question 10) |
| UPLOAD (Stretch) | Mark run for upload | - | Yes, queue file (Online) |
| PLAY AGAIN | `bind_device(device, 0)`, open Lobby | device | No (session) |
| TITLE | Clear bindings, open Title | - | No |

`submit_run` is guarded: at most one call per run, even with double Confirm or timeout racing a final Done.

Analytics: no analytics events exist for these screens (stated null; the `analytics-engineer` may add `results_shown`, `name_entry_done` later without changing this spec).

## Transitions & Animations

Per `arcade-ui-style.md` section 4; ticks at 60 Hz.

| Moment | Motion | Ticks | Reduce motion / flashing |
|---|---|---|---|
| Tally -> Results | 4-step Char wipe | 12 | Cut |
| Row / column reveal | 4 px slide up + fade | 6, spaced 15 | Appear in place (stagger kept) |
| Rank plate, NEW tag | Stamp in 4 steps | 8 | Appear in place; NEW pulse removed under reduce-flashing |
| Lock bar | 4 stepped segments | 30 | Unchanged (functional) |
| Results -> Name entry | 6-frame menu transition | 6 | Cut |
| Wheel character change | Instant swap, chevron nudge 1 px | 1 | Nudge off |
| Slot focus move | Instant | - | - |
| Slot Done | DONE + check stamp | 4-8 | In place |
| Timer last 10 s | 4-step bar | - | Unchanged |
| Name entry -> Board | Char wipe | 12 | Cut |
| New row on Board | Static border + arrow + NEW; optional pulse <= 40%, <= 2 Hz, one element | - | Pulse off |
| Toast | 8-frame in/out, 90 ticks hold | 8 / 90 | No slide |

Mood change: GAME OVER backdrop is cold, others warm. Backdrop is fixed art; no scrolling. No white frame, no flash on any of the three screens.

## Data Requirements

| Data | Source System | Read / Write | Update trigger | Null handling |
|---|---|---|---|---|
| `RunRecord` (per slot score, chain, CB, continues, `pre_continue_score_total`, `is_1cc`, `final_state`; `stage_reached`, `stage_count`) | Session (1) | Read | Once at Results open | Missing slot data: row shows "-" for each field; never crash |
| `run_ended_by` | Session (1) | Read | Results open | ABANDONED must never arrive (screen not opened); if it does, go to Title |
| Aggregates (team score, team chain, team CB, `team_score_incl_continues`) | Session F6 | Read | Results open | Empty `max_chain_per_boss` -> chain 0 shown as "0" |
| `one_credit_clear` | Session F7 / Save | Read | Results open | Treated as false |
| Rank (`preview_rank`) | Save (26) | Read | Once at Results open | No result, "not placed" (Save F1: score >= 1 but outside the top `board_size`) or Save absent: no rank, run treated as unranked, no Name entry. Co-op: one team rank on the `{n}s/coop/{k}` board |
| Plane id per slot | Session `RunRecord` / Save entry | Read | Results and Board open | Unknown id: generic plane icon + raw id in Latin |
| `profile.last_initials[slot]` | Save (26) | Read/Write | Name entry open / submit | Invalid or missing: `AAA` |
| `submit_run` result | Save (26) | Write | Once per run | `save_failed`: keep in-memory entry, toast |
| Board rows by `board_id` | Save (26) | Read | Board open | Empty: "No scores yet" row; unknown plane id: generic icon + raw id (Menus Rule 40) |
| `board_id` (`{n}s/solo/{plane}`, `{n}s/coop/{k}`, `/touch` suffix) | Save F3, Touch TF8 | Read | Board open | Missing: Solo tab, run's plane |
| Score display | Scoring | Read | Results open | Clamped at 999,999,999 for display; stored value is not clamped |
| `run.assisted` | Session / Accessibility | Read | Results open | Missing: false |
| `access.untimed_menus`, `reduce_*` | Accessibility (28) | Read | Screen open and live | Defaults false |
| `name_entry_ticks` | Save `name_entry_seconds` x 60 | Read | Name entry open | 1,800 |
| Device state per slot | Input (2) | Read | Every tick in Name entry | Unknown device: treat as disconnected |
| `tutorial.offered`, `.complete` | Tutorial (30) | Read/Write | Results open | false |
| Upload eligibility, claim status | Online (32) (Stretch) | Read | Results open, async | Offline or no consent: no UPLOAD action |
| Digits, strings | Localization (27) | Read | Open, language change | Fallback to English, never a key |

UI owns no game state; the flow is a node-free `ResultsModel` with `NameEntryModel` slot machines, ticked at 60 Hz.

## Accessibility

Committed tier: **COMPREHENSIVE** (`design/accessibility-requirements.md`); options from `accessibility-options.md`. Test rows T-01, T-05 and T-10 of the requirements document apply to this spec.

| Check | Status |
|---|---|
| Keyboard only | Pass: full flow (AC-53); name entry by wheel or typing |
| Gamepad only | Pass: full flow; wheel by D-pad; no keyboard needed |
| Touch | Partial: tap plates; touch name entry uses a large-wheel variant (see Localization/Layout note below and Open Question 6) |
| Not colour alone | Slot = tag text + ring pattern + pips + colour. Rank = text. New row = border + arrow + NEW text. DONE = word + check glyph. 1CC/C = text tiles |
| No flashing | None on any screen. NEW pulse removed by `reduce_flashing` / `reduce_pulsing` |
| Timing | Lock (30 ticks) is a mash guard, not a challenge. Name entry is 30 s, shared, safe default on expiry. `untimed_menus` removes the limit |
| Contrast | Computed from the art-bible hexes (WCAG relative luminance): Cream `#F4EBD6` on Cabinet Char `#1E1B18` = 14.4:1 (text needs 4.5:1); Ember Gold `#FFC93C` on Cabinet Char = 11.2:1; focus border Cream 3 px on Char = 14.4:1 (non-text needs 3:1). Plate edge `#5A5148` is 2.2:1 and is decoration only, never the sole carrier of state. The dimmed "OUT" word must measure >= 4.5:1 in the spike |
| Untimed + pad loss | Under `untimed_menus` a lost pad holds the entry open (controller-lost plate + DROP), so a player with a failing pad is never forced to submit |
| Readability | Min 12 px Latin / 17 px Bengali; Cream on Cabinet Char, 1 px outline; high-contrast option swaps edges to Cream |
| Text size | `text_size` step applies to S/M labels and prompts; numerals and 3-4P columns stay on the fixed grid; wheel characters are L tier (identity). See Open Question 7 |
| Wheel reach | Worst case 19 steps takes 2.0 s by holding; three characters 6.0 s. Typing is an alternative on keyboards |
| Subtitles | None needed: no dialogue |
| Sound twins | Every cue has a visual twin: rank sound = rank plate; name tick = character change; save error = toast |
| Screen reader | Out of scope at Vertical Slice; reconsider at Target (`accessibility-requirements.md` section 4). Focus order and text are defined above so platform narration can be added later |
| Resolution | Everything inside 360x640; scales with the display scaler; no element below 12 px Latin |

## Localization Considerations

Results, Name entry and Board are **single-language** (style guide 2.1). Bengali: 17 px minimum, +40% width, +25% height, no letter-spacing, no all-caps contrast, no faux bold. Digits follow the language on the shared grid (Western grouping). "P1"-"P4", initials and key names stay Latin. **Name-entry character set:** the wheel is Latin-only in both languages: `A-Z`, `0-9`, `-`, `.` (38; Save Rule 12, Localization Open Question 7 closed). A Bengali-language player edits the same Latin wheel; only the heading, state words and prompts are Bengali. Bengali letters typed on a keyboard are refused with `sfx_ui_deny` and a one-line hint "Latin letters only" (`menu.name.latin_only`, registered 2026-11-03; in Bengali the hint is Bengali) so the refusal is explained, not silent. Board and stored initials are never transliterated.

| String key | English | Bengali (draft, GDD) | Limit (English chars / px box) | Notes |
|---|---|---|---|---|
| `menu.results.game_over` | GAME OVER | খেলা শেষ | 9 chars, 328 px, L tier | Fits easily |
| `menu.results.ending` | MISSION COMPLETE | অভিযান সফল | 16 chars, 328 px, L tier | Deliberately not "ALL CLEAR" (that is the Tally banner, see Resolved conflicts) |
| `menu.results.rank` | RANK {n} | র‍্যাঙ্ক {n} | 7 chars + 2 digits | Zero-width joiner in Bengali: font spike |
| `menu.results.before_continues` | Before continues: {n} | কন্টিনিউর আগে: {n} | 21 chars + 11-digit number; 328 px, S tier | HIGH PRIORITY: Bengali + 9 digits in one line |
| `menu.name.heading` | ENTER YOUR INITIALS | আদ্যক্ষর লিখুন | 19 chars, 232 px box (timer reserves 80 px), M tier | HIGH PRIORITY: Latin fits; check Bengali wraps to 2 lines |
| `menu.scores.empty` | No scores yet | এখনও কোনো স্কোর নেই | 13 chars, 328 px | |
| `menu.scores.play_again` | PLAY AGAIN | আবার খেলুন | 10 chars in a 156 px plate | HIGH PRIORITY: Bengali +40% in 156 px |
| TITLE (existing Title/Board key) | TITLE | শিরোনাম | 5 chars, 156 px plate | Reuse the Title wording; verify the key |
| `menu.results.not_placed` (registered) | Not in top {n} | *pending native review* | 14 chars + 2 digits, 328 px, S tier | New key; `{n}` = `board_size` via `format_int` |
| `menu.name.controller_lost` / `menu.name.drop` (registered) | P{n} controller lost / DROP | *pending native review* | 20 chars in 160 px (S tier, 2 lines allowed; 3 lines Bengali) / 4 chars in a 60 px plate | New keys; untimed only |
| `menu.results.practice` (registered) | PRACTICE - not ranked | *pending native review* | 21 chars, 328 px | New key |
| `menu.results.not_ranked` (registered) | Not ranked | *pending native review* | 10 chars | New key |
| `menu.results.next` (registered, prompt) | Next | *pending native review* | 4 chars | New key |
| `menu.name.done` / `menu.name.editing` (registered) | DONE / EDITING | *pending native review* | 7 chars each, 90 px | New keys |
| `menu.name.no_limit` (registered) | No time limit | *pending native review* | 13 chars, 80 px box | New key; must fit where the timer sits |
| `menu.results.stage_of` (registered) | Stage {a}/{b} | *pending native review* | 9 chars | Digits on the grid |
| Offer line (Tutorial) | New? Try Flight School from the title. | in Tutorial GDD | 38 chars, 2 lines max (3 Bengali) | |

*Key status 2026-11-03 (UX amendments wave 5): every key marked **(registered)** above is now in the Menus GDD string table and in `localization.md` Rule 5a (single-language, `ui_menu.csv`, one `_meta` row each). English is the source; the Bengali cells read "pending native review" by decision and are filled by the localisation lead before the string soft freeze - none was machine-drafted.*

Digits: a 9-digit score plate is 107 px at the 11 px cell (S tier) and 78 px at D12 (8 px cell, 3 px separators); Bengali uses the same widths (Localization F3). Initials are not translated. All Bengali strings are drafts awaiting native review.

---

## Acceptance Criteria

Testable from this document alone; GDD AC numbers in brackets where they overlap.

- [ ] Pressing Confirm at Results tick 29 does nothing; at tick 30 it is accepted. ABANDONED never opens Results. [AC-36]
- [ ] A 1P GAME OVER shows: heading, one row with 9-digit score, best chain in Gold at 24 px, CB count, stage `n/N`, and no 1CC tile. An ENDING run with `one_credit_clear` shows the 1CC tile on that slot only.
- [ ] For P1 4,200,000 / chain 187 / 2 CB and P2 900,000 / chain 96 / 1 continue / `pre_continue_score_total` 600,000: team score 5,100,000, team chain 187, team CB 2, "Before continues: 5,700,000", P2 has "C" and no 1CC. [AC-37]
- [ ] In 3P and 4P every column (80 px) shows 999,999,999 in D12 (78 px plate, Western grouping) and the same score in Bengali digits without clipping, at text-size steps 0 and 3; if a plate measures over 80 px, all columns switch to D10 together.
- [ ] A 2P co-op ranked run shows exactly one `RANK {n}` (the team rank) in the rank strip and none on any slot row; the Board shows one new row with the lead player's initials and "+1".
- [ ] A score of 5 on a full board whose lowest entry is higher (not placed) shows "Not in top 10", skips Name entry, calls `submit_run` once on Confirm, and the Board shows no highlighted row.
- [ ] 4P Name entry shows four blocks in a 2x2 grid at y 104 and 264 inside 360x640 with the timer, heading and rank line unobstructed; 3P centres the third block at x = 100; each block shows its own device glyph.
- [ ] With `untimed_menus` on and a pad unplugged during Name entry, that slot shows "controller lost" and DROP, nothing is submitted, and replugging resumes the wheel; DROP by another slot marks it Done with `last_initials`.
- [ ] The Start or Confirm press that opens Name entry does not mark any slot Done; Start from slot 2's device finishes only slot 2.
- [ ] The Results ENDING heading reads "MISSION COMPLETE" (Bengali `অভিযান সফল`); the Tally banner that precedes it reads "ALL CLEAR".
- [ ] `preview_rank` is called exactly once per Results open; `submit_run` exactly once per run, including double Confirm and timeout racing the last Done. [AC-38]
- [ ] An unranked run (score 0, or assisted) never shows Name entry: Confirm goes straight to the Board, `submit_run` is called, and the Board shows a "Not ranked" or "PRACTICE - not ranked" notice and no highlighted row; `last_initials` is unchanged.
- [ ] In a 2P ranked run both wheels edit at the same time; finishing one locks that wheel (DONE + check glyph) and the other continues; the screen leaves when both are Done.
- [ ] From `Z`, Up gives `0`; from `.`, Up gives `A`; from `A`, Down gives `.`; holding Up moves one character at tick 0, the second at tick 18, then one every 6 ticks, so 19 steps take 120 ticks. [AC-39]
- [ ] The timer shows 5 at elapsed 1,500 ticks and 1 at 1,741; at 1,800 every unfinished slot takes its edited text (or `last_initials` if unchanged) and `submit_run` runs once. [AC-40]
- [ ] With `access.untimed_menus` on, the timer is replaced by "No time limit" and nothing is submitted until every slot is Done.
- [ ] A keyboard player typing `k`, `a`, `z` gets `KAZ` and focus advances each time; `!`, space and a Bengali letter are refused with `sfx_ui_deny`; with KB1 and KB2 both editing, typing is disabled and both use the wheel.
- [ ] With the timer on, if a slot's pad disconnects during Name entry, that slot becomes Done with its `last_initials`, a toast reads "P{n} controller disconnected", and the other slots keep editing and the game does not pause.
- [ ] After submit, the Board opens on the run's `board_id` (with `/touch` for a touch run) with the new row shown with a 3 px border, arrow and NEW text, in greyscale as well as colour. [AC-43]
- [ ] PLAY AGAIN is the default focus; the Confirm or Start that ended Name entry never also activates PLAY AGAIN.
- [ ] PLAY AGAIN binds the pressing device to Lobby slot 0; TITLE returns to Title and clears bindings; if a pad vanished meanwhile, its slot is Empty with a toast. [AC-43]
- [ ] If `submit_run` raises `save_failed`, the Board still opens, shows the entry for this session, and shows the error toast even with three other toasts queued. [AC-44]
- [ ] Empty/error: with Save absent or no rows, the list shows a single "No scores yet" row (never blank) and PLAY AGAIN still works.
- [ ] A keyboard-only tester and a gamepad-only tester each complete Results -> Name entry -> Board -> Title with no mouse. [AC-53]
- [ ] With `reduce_flashing` on, the NEW tag does not pulse; with `reduce_motion` on, rows appear in place and the wipe is a cut.
- [ ] On a touch device every plate and chevron on the three screens is at least `touch_item_h` (9 mm) tall.
- [ ] At 360x640 and at the largest supported window scale, no element is clipped and 3-4P Results and 2x2 Name entry fit inside the canvas.
- [ ] **Performance:** Results and Name entry hold 60 fps (frame under 16.6 ms) on the minimum mobile target with four rows revealing; opening Results adds no hitch of more than one frame beyond the 12-frame wipe.

---

## Open Questions

| # | Question | Where found | Recommended default |
|---|---|---|---|
| 1 | ~~Heading mismatch~~ **Resolved in this spec:** ALL CLEAR = Tally banner, MISSION COMPLETE = Results verdict. **Registered 2026-11-03 (wave 5 batch 2)** as two distinct glossary terms in `localization.md` Rule 30. Remaining: writer/art-director confirm the Bengali term (pending native review) | Menus string table vs `stage-tally.md` | Keep both |
| 2 | ~~Rank placement in co-op~~ **Resolved in this spec:** one team rank in the strip. **Applied 2026-11-03 (wave 5):** Menus Rule 35 and the Results 2P mock-up now show one rank strip under the heading (the team rank by `team_score` in co-op) | Menus mock vs Save Rule 5 | Applied |
| 3 | **Column width.** D12 (78 px) is now the rule with a D10 fallback. Still needs the font spike to confirm 78 px and the D10 plate width, and `digit_grouping = INDIAN` makes 81 px | Menus V/A "Results"; Localization F3 | Spike before freezing |
| 4 | ~~4P name wheel layout~~ **Resolved in this spec:** 2x2 grid. **Applied 2026-11-03 (wave 5):** Menus Rule 36 and the V/A "Name wheel" row carry the grid (160x136 blocks at x 16 / 184, y 104 / 264; 3P centres P3 at x 100) | Menus V/A "Name wheel" | Applied |
| 4a | ~~**Unknown-plane entries on the Scores screen**~~ **CLOSED 2026-11-03 (wave 5).** Menus Rule 40 now makes such a board an **extra Solo sub-tab chip** (generic plane icon + the raw id in Latin, cut to 8 characters + `...`), and the Boards edge case no longer claims those entries appear on co-op boards; `high-scores.md` Open Question 1 is closed with the same answer. After-run Board was never affected | Menus Rule 40, Save edge case | Closed |
| 4b | ~~**Controller-lost plate / DROP**~~ **CLOSED 2026-11-03 (wave 5).** Added to `interaction-patterns.md` as **P31 Controller-lost plate with DROP**, and P15 now carries the untimed pad-loss hold; Menus Rule 36 and `design/accessibility-requirements.md` T-05 state the behaviour | Accessibility edge case | Closed |
| 5 | **Confirm on wheel slots 1-2** is unspecified (Rule 36 only defines the last slot and Start). Assumed to advance focus right | Menus Rule 36 | Advance right |
| 6 | **Touch name entry** is not covered in the Touch GDD. Assumed: a large variant (slots 56x72, chevrons `touch_item_h`) for the single TOUCH slot | Touch TF7 | Accept variant |
| 7 | **Text size** on Results columns and Name entry: fixed grid vs `text_size` step; Menus AC-58 lists Board but not Results | Menus AC-58 | Numerals fixed, labels scale |
| 8 | ~~Rank outside the top 10~~ **Resolved in this spec** by Save F1 (`ranked` needs `rank_index` < `board_size`). **Applied 2026-11-03 (wave 5 batch 2):** Save Rule 5 now states the placement half, `preview_rank` may return `not placed`, a not-placed run asks for no initials and stores nothing, and AC-03a covers it | Save Rules 5, 9, F1; Online Rule 1 | Applied |
| 9 | **Upload timing (Stretch).** Online puts an Upload action on Results, but the claim needs the stored row, and queue writes happen only at Results confirm (Online Rule 32). Also `auto_upload` defaults true, so a manual action may be redundant | Online UI list, Rules 1, 32 | Show status only when `auto_upload`; show UPLOAD button when off; mark the run for upload at submit |
| 10 | **Settings writes.** `profile.last_initials` and `tutorial.offered` live in `settings.json`, but Save Rule 20 lists no write at Results confirm for them; a crash or Web tab close can lose them | Save Rules 20, 12 | Write `settings.json` together with `scores.json` at submit |
| 11 | **Disconnect vs timeout.** Disconnect discards edits and uses `last_initials`; timeout keeps edits. Inconsistent for the same loss of control | Menus edge cases | Make disconnect keep edited text too |
| 12 | **No undo after Done**, and one Done player cannot be corrected if they misclick Start. | Menus edge case "wheel locks" | Accept at MVP; revisit in playtest |
| 13 | **Untimed name entry** can be held up by one idle player in 3-4P; GDD sets no cap | Accessibility `untimed_menus` | Accept; add a "hold Start to finish all" later |
| 14 | **Double Confirm on Results.** Two quick presses after the lock skip rows then leave in under half a second; there is no second guard | Menus Rule 35 | 15-tick guard after the skip press (proposal) |
| 15 | **Board has no idle timeout** and no tab-away behaviour on Web; Name entry timer is real time, so a tab-away on Web submits `last_initials` | Menus F5 | Accept |
| 16 | **TOUCH filter and Boss Rush / Single Boss boards** (Stretch) need controls on the High scores screen; Results for RUSH/BOSS runs (stage_reached meaning) is not designed | Touch TF8; Online F3 | Own spec for High scores |
| 17 | ~~**Sound ids.** The GDD uses `ui.rank`; the style guide uses `ui_new_best`. Audio GDD owns the id~~ **CLOSED 2026-11-03 (final doc closeout, consistency-report C1):** one scheme everywhere - **`sfx_ui_*`**. The rank sting on Results is **`sfx_ui_new_best`** (the cue the style guide already assigns to "NEW BEST stamp, new board entry"); no separate rank sound is minted. The Menus audio table and the style guide both carry the `sfx_ui_*` spelling | Menus audio table; `design/gdd/audio.md` (owner) | Closed |
| 18 | The pattern library's P15 and Gap 6 (Results rows) should be updated from this spec | `interaction-patterns.md` | Update after review |
| 19 | Player journey map and COMPREHENSIVE tier now exist and are cited. No analytics events exist for Results or name entry (stated null) | - | - |
| 20 | **Pad loss under `untimed_menus`** is a hold with DROP here (follows Accessibility edge case); the timed case follows Menus (Done with `last_initials`). Open Question 11 still asks whether the timed case should keep edits | Accessibility GDD vs Menus edge case | Decide with OQ 11 |
