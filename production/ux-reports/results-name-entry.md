# UX Review: Results, Name Entry and Board After Run

**Spec**: `design/ux/results-name-entry.md`
**Date**: 2026-11-03
**Reviewer**: ux-designer (Phase 3A, screen spec)
**Tier checked against**: COMPREHENSIVE (`design/accessibility-requirements.md`)
**GDDs cross-checked**: stage-end-tally, scoring, save-settings-high-scores, online-leaderboards-boss-rush, coop-and-team-chain, localization, menus-title-plane-select, accessibility-options; UX: high-scores, stage-tally, player-journey.

## Verdict before fixes: NEEDS REVISION
## Verdict after fixes: APPROVED WITH OPEN QUESTIONS (no blockers left in this file; amendments below must be applied elsewhere)

## Completeness

| Item | Before | After |
|---|---|---|
| Header, purpose, context, navigation, entry/exit | Pass (journey phase said "unknown", file exists) | Pass |
| Layout zones + component inventory | Fail: no 3P/4P name layout, 3-4P score plate unproven | Pass |
| States (loading / empty / error) | Partial: no missing-record, not-placed or untimed pad-loss state | Pass |
| Interaction map, every input | Partial: pointer scope on Name entry unclear, no DROP, no focus order | Pass |
| Data requirements (owner per element) | Pass; two null-handling gaps | Pass |
| Events | Pass; analytics null not stated | Pass |
| Transitions | Pass | Pass |
| Accessibility | Fail: said no requirements doc exists, no contrast ratios, contradicted Accessibility GDD on untimed pad loss | Pass |
| Localization | Partial: no character-set statement for the Bengali/English split | Pass |
| Acceptance criteria (>= 5, perf + resolution) | Pass count; one wrong (step 20 of max 19), one not self-contained | Pass |

## Blocking issues found (all fixed in the spec)

1. 3-4P column: 9-digit score had no committed fit rule.
2. No 3P/4P name-wheel layout (spec had a 2x2 but no 3P cell, no coordinates, no device glyph, mixed-device prompt bar undefined).
3. Co-op rank shown per row (Menus mock) versus one team rank.
4. "Ranked if >= 1" versus "top 10": the spec let a not-placed run into Name entry.
5. MISSION COMPLETE versus ALL CLEAR.
6. Unknown-plane entries: handling absent from States and Data.
7. Untimed pad loss contradicted Accessibility GDD edge case (entry stays open until pad returns or Drop).
8. Press that opens Name entry could mark a slot Done (no carry-over guard); Start semantics in co-op ambiguous.
9. Mouse role in Name entry undefined (chevrons said "tap/click").
10. Accessibility section out of date (no tier, no contrast ratios, screen-reader stance).
11. Bengali-keyboard refusal was silent; character-set rule not stated in Localization.
12. AC "step 20" impossible (max 19 steps); AC referred to F4 in another document.

## Fixes applied

1. **Header / Journey Phase**: pointed to `player-journey.md` steps 11 and 12.
2. **Header / Sources**: added coop-and-team-chain and accessibility-requirements; added the rule for GDD-versus-GDD conflicts.
3. **Revision note** added under the header; new **Resolved conflicts** table (six decisions).
4. **Layout Zones, Results 3P/4P**: score plate rule (D12 78 px mandatory, centred; D10 fallback for all columns together; INDIAN grouping case; team block at S tier; clamp 999,999,999).
5. **Layout Zones, Results rank strip**: one team rank in co-op; added "Not in top {n}" case.
6. **Layout Zones, Name entry**: 2x2 coordinates (y 104 / 264, ends y 400), 3P bottom block centred at x = 100, fixed slot order, device glyph per block, interior height budget, rank line for 3P/4P, prompt bar rule for mixed device families.
7. **Component Inventory**: team-rank wording, Not-placed plate, Controller-lost plate (flagged new pattern), Device glyph.
8. **States**: ENDING row (heading explained, ALL CLEAR is the Tally banner); Results record-missing; Not placed; Co-op rank; Unknown plane id; Pad lost split into timed and untimed (hold + DROP); Name-entry-opening press consumed.
9. **Interaction Map (Name entry)**: Start finishes only the pressing slot; focus order inside a wheel and none between wheels; mouse is not bound, so only a TOUCH slot taps; DROP row.
10. **Events**: Results Confirm covers "not placed"; analytics stated null.
11. **Data Requirements**: `preview_rank` null/not-placed/co-op handling; plane id per slot row; board rows null handling aligned with Menus Rule 40.
12. **Accessibility**: tier cited; contrast ratios computed (Cream/Char 14.4:1, Gold/Char 11.2:1, focus border 14.4:1, edge 2.2:1 decorative); untimed pad-loss row; screen-reader stance per section 4.
13. **Localization**: new keys (`not_placed`, `controller_lost`, `drop`, `latin_only`); Latin-only wheel stated for both languages; Bengali key refused with a hint; ALL CLEAR note replaced.
14. **Acceptance Criteria**: fixed the F4 criterion (self-contained, 19 steps = 120 ticks); added 3-4P plate at text steps 0 and 3, single team rank, not-placed, 4P/3P grid, untimed pad loss, press carry-over, heading pair; clarified timed pad loss.
15. **Open Questions**: closed 1, 2, 4, 8; narrowed 3; added 4a, 4b, 19 (updated), 20.

## Cross-document amendments requested

1. **`design/gdd/save-settings-high-scores.md`, Rule 5.**
   Current: "A run is **ranked** if its **board score** is at least `min_ranked_score` (1)."
   Proposed: "A run is **ranked** if its board score is at least `min_ranked_score` (1) **and** it places within the top `board_size` of its board (F1). `preview_rank` returns a rank or `not placed`; a not-placed run asks for no initials and stores nothing." (Aligns with F1, AC-03 and Online Rule 1.)
2. **`design/gdd/menus-title-plane-select.md`, Rule 35 and the Results 2P mock-up (~line 592).**
   Current: "RANK 2 NEW" on P1's row; Rule 35 "Rank ... shows as RANK {n} with a NEW tag, or nothing if unranked."
   Proposed: rank shown once in a strip under the heading; in co-op it is the team rank (Save Rule 5, Co-op Rule 18); add "or `Not in top {n}` when not placed" and move the mock-up's rank line out of P1's row.
3. **`design/gdd/menus-title-plane-select.md`, V/A table row "Name wheel" (~line 520) and Rule 36.**
   Proposed: add "3-4 players: 2x2 grid of 160x136 blocks at x = 16 / 184, y = 104 / 264; 3P centres P3 at x = 100."
4. **`design/gdd/menus-title-plane-select.md`, Rule 36 / edge case (~line 403) versus `accessibility-options.md` edge case (line 296).**
   Current Menus: "pad disconnects -> Done with last-used initials." Accessibility: under `untimed_menus` entry stays open until the pad returns or Drop.
   Proposed Menus text: add "unless `access.untimed_menus` is on: the slot is held (controller-lost plate with DROP)."
5. **`design/gdd/menus-title-plane-select.md`, V/A "Results" column and `localization.md` F3.**
   Proposed: record that 3-4P Results columns use D12 (78 px, Western) with a D10 fallback; confirm D10 plate width and the INDIAN-grouping 81 px case in the font spike.
6. **`design/gdd/menus-title-plane-select.md` string table (~line 698) and `localization.md` Open Question / glossary.**
   Proposed: add `menu.results.not_placed`, `menu.name.controller_lost`, `menu.name.drop`, `menu.name.latin_only`, `menu.results.practice`, `menu.results.not_ranked`, `menu.results.next`, `menu.name.done`, `menu.name.editing`, `menu.name.no_limit`, `menu.results.stage_of`; and record the pair "ALL CLEAR" (Tally banner) and "MISSION COMPLETE" (Results verdict) in the glossary.
7. **`design/ux/high-scores.md`, Open Question 1 and `menus-title-plane-select.md` edge case (~line 408).**
   Proposed: resolve the unknown-plane conflict with an "Other" chip on Solo that exists only when such a board exists (the chip proposal already in `high-scores.md`); fix the Menus edge case which wrongly says those entries appear on co-op boards.
8. **`design/ux/interaction-patterns.md`.**
   Add the controller-lost plate / DROP pattern (untimed pad loss); update P15 and Gap 6 (Results rows) from this spec (existing Open Question 18).
9. **`design/accessibility-requirements.md`, line 205.**
   Current: "pad disconnect holds the entry open when untimed". No change needed; confirmed consistent with the spec after fix 8. T-05 should add "DROP" to the pass condition.
10. **`design/ux/stage-tally.md`** (no change): its "ALL CLEAR" banner stays; the pairing is explained here.

## Still open

- Font spike: 78 px D12 plate, D10 plate width, INDIAN grouping 81 px (OQ 3).
- Writer and art-director confirmation of the ALL CLEAR / MISSION COMPLETE pair and Bengali terms (OQ 1); all Bengali strings are drafts.
- Upload timing, `auto_upload` and settings-write timing (OQ 9, 10): Stretch / Save decisions.
- Timed pad loss: discard or keep edits (OQ 11, now OQ 20 as well).
- Confirm on wheel slots 1-2, touch name-entry variant, text-size step on Results (OQ 5-7): defaults kept, need playtest.
- Double-Confirm guard, idle 3-4P untimed hold, Web tab-away (OQ 12-15).
- Rush/Boss Results meaning of `stage_reached` (OQ 16) and sound id (OQ 17).
- Minimum mobile target frame time for the performance AC is not measured yet.
