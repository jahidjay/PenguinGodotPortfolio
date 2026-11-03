# UX Review: Flight School (`design/ux/flight-school.md`)

**Date**: 2026-11-03 | **Reviewer**: ux-designer (Claude), auto-approve | **Checklist**: Phase 3A (screen spec) | **Tier**: Target (not MVP; ACs judged accordingly, full section set required)

Cross-checked against: `design/gdd/tutorial.md`, `chain-tracker.md` (~1 s window = 60 ticks, pure reset to 0), `critical-break.md`, `plane-kits-lancer-leech.md`, `plane-kits-sentry-breaker.md`, `accessibility-options.md`, `accessibility-requirements.md` (COMPREHENSIVE), `input-and-player-mapping.md`, `design/ux/pause.md`, `design/ux/main-menu.md`.

## Verdict

- **Before fixes: NEEDS REVISION** (strong content, 9 blocking gaps).
- **After fixes: APPROVED with CONCERNS** (concerns are cross-document and listed below; none block the spec itself).

## Completeness

| Item | Before | After |
|---|---|---|
| Header, Purpose, Context, Navigation, Entry/Exit | Present | Present (Title exit now commits) |
| Layout zones + component inventory | Present, Pause geometry wrong | Fixed; new patterns flagged |
| States incl. loading / empty / error | Error (save) only | Loading, Empty, Error(data), Disconnect, Game-speed added |
| Interaction Map, all input methods | Keyboard/pointer cells blank, no focus order | Filled; focus order and Card/Pause nav added |
| Data Requirements with source + owner | No owner column | Owners named per element |
| Events fired / stated null | No null statement, no Title commit | Added |
| Transitions | Present | Unchanged |
| Accessibility | Claimed no a11y doc exists, wrong contrast | Rebased on COMPREHENSIVE, figures computed |
| Localization with char counts | Partial | Limits for all added strings |
| Acceptance Criteria (>= 5) | 21, two wrong | 28, corrected |

## Blocking issues found (before)

1. **`school_seen` would not persist.** Only a completed drill triggered `commit_settings()`; a player who opens the list and goes back to Title would see NEW again after a restart, contradicting AC 5.
2. **Pause geometry contradicted `pause.md`** (panel y 224-432 vs plate bottom-anchored at y 420; never below y 420) and the Pause tip AC still described the rejected separate plate under the panel.
3. **Missing states**: no loading, empty or data-error state; no disconnect-in-drill behaviour.
4. **Interaction Map incomplete**: keyboard and pointer cells blank for 8 rows; no focus order; no Card navigation; hold-to-confirm ignored `confirm_style` DOUBLE_TAP and `confirm_hold` 40/60/90.
5. **Data table had no owner column**; game speed / PRACTICE and glyph binding not listed.
6. **Accessibility section stale**: stated `accessibility-requirements.md` does not exist (it does, COMPREHENSIVE); claimed 7:1 contrast for all text, but dimmed `#A89E8A` on Char is about 6.4:1 and the `#5A5148` edge about 2.2:1; no sound visual twins, background dim, remap or screen-reader stance.
7. **Per-device glyph rule undefined** for a shared Card in mixed-device co-op, and remaps not covered.
8. **Plane-specific tip text**: Coach wireframe said "The laser burns", wrong for Leech, Sentry (Entrench) and Breaker (Breach).
9. **Hidden rows vs header `n / 10`** undefined for planes lacking events (Sentry/Breaker), and AC "nothing flashes faster than 1 Hz" contradicted the 2 Hz focus pulse.

## Quality checklist (after)

Pass: player need specific; timers have durations (45/60/90/120/180/1,800); keyboard and pad fully specified; focus order defined; no data element owned by "UI"; update triggers stated; null handling per element; nothing colour-only; contrast figures given; screen reader stance per section 4; GDD UI Requirements covered (Title item, list, Card, Coach, Lobby SCHOOL, Pause items and tip, Tally tip, HUD bar/stamp/mark, stage card); patterns cited, new ones flagged; ACs include performance and resolution.
Advisory remaining: Tutorial's "required drill" model vs plane kits; strip mark clearances (HUD); `ui_tutorial` Bengali is draft.

## Fixes applied

1. **Header**: Status updated, revision note added (`Last Updated` was already 2026-11-03).
2. **Entry & Exit Points / Events Fired**: leaving to Title commits once if the profile is dirty; null-event row and disconnect row added.
3. **Layout Zones**: Pause panel bottom-anchored at y 420, 208 high at step 0, grows upward, no tip row in drills; Pause wireframe y values corrected.
4. **Component Inventory**: glyph token rule (last-used device, actual remapped binding, key names on keyboard); new patterns flagged (Coach card candidate P29; zone bracket, drill bar, strip mark, "2P" tag).
5. **ASCII Wireframes**: Coach text made plane-neutral; prompt bar content per screen, glyph family noted.
6. **States & Variants**: added Loading, Empty, Error(data), Error(save) pointer, Disconnect in a drill, Game speed below 100; mixed-plane hide rule and `n / N` over visible required rows.
7. **Interaction Map**: all keyboard/pointer cells filled; Card and Pause navigation rows; `confirm_style`/`confirm_hold`/DOUBLE_TAP for Reset and Skip; explicit focus order; scroll arrows are indicators only.
8. **Data Requirements**: owner and system numbers for every row; added confirm options, game speed/PRACTICE, visible-row set.
9. **Accessibility**: COMPREHENSIVE basis, computed contrast (Cream about 14:1, dim about 6.4:1, edge about 2.2:1 decorative), per-slot maps and remaps, sound twins, background dim, touch sizes, screen reader stance.
10. **Localization Considerations**: max character counts for header, group, toast, reset warning, empty line, DONE, SKIPPED, LOADING, buttons.
11. **Acceptance Criteria**: Pause plate and tip AC corrected; NEW-tag persistence AC; flashing AC reworded; added focus order, glyph binding, empty/loading, disconnect, game-speed and text-step ACs.
12. **Open Questions**: added 12 (hidden required rows vs `complete`), 13 (PRACTICE in drills), 14 (Fire toggle wording), 15 (per-plane tips), 16 (Title overflow); fixed stale text in 10 and ordering.

## Cross-document amendments requested

1. **`design/ux/main-menu.md`, Layout Zones row "Menu list" and Open Question 1 (Title overflow, still unresolved).**
   Current: "Menu list | 392 + n x 36 | Plate 216 px wide, centred; item height 32, gap 4; 5 items = 176 px (up to 6 with FLIGHT SCHOOL = 212 px, ends y 604, which collides with the prompt bar at y 600 ...)".
   Proposed: "Menu list top = 372 when FLIGHT SCHOOL is present (Target, 6 items = 212 px, ends y 584, 16 px above the prompt bar at y 600), 392 otherwise (5 items end y 568). Logo ends y 200 so the gap above is not an issue. At text steps 2-3 the list scrolls inside y 372-584 with focused row kept in view. Toast strip (560-584) overlaps the list bottom as it already does at 5 items; toast takes precedence while shown (transient)." Close Open Question 1 with this.
2. **`design/gdd/save-settings-high-scores.md`, Rule 20 (commit triggers)** and **`design/gdd/tutorial.md` Rule 25a / Rule 24**.
   Current trigger list contains "Flight School drill complete (return to the list)" only.
   Proposed: add "leaving the School list to Title while `tutorial.school_seen` or `hint_counts` are dirty", so the NEW tag clears without completing a drill.
3. **`design/gdd/tutorial.md`, F3 and Rule 12** (`required_mask` 1,023 vs hidden rows).
   Current: "`required_mask = 1023` (bits 0 to 9)"; "a plane without one marks its drill `available = false` and the row is hidden".
   Proposed: `required_mask` is computed over the rows available to the profile's planes, or Sentry/Breaker drills get plane-specific equivalents; otherwise `complete` can never be true for those pilots (hints keyed on `drill_ref` bits would also never be suppressed).
4. **`design/gdd/tutorial.md`, Rule 13 / `DrillDef`**: state that `tip_key` and `goal_key` text must be plane-neutral (or add per-kit keys), because the four kits charge differently (laser, focused shot, Entrench, Breach).
5. **`design/ux/hud.md` / `design/gdd/hud.md`** (strip mark clearances, spec Open Question 3, still open): `chain_plate` (262,1,96,34) has 1 px above and 2 px right; `kit_bar` overlaps the drill/boss bar (24,37,312,10). Proposed: strip mark brackets are drawn inset when less than 3 px is free. Also the DONE/SKIPPED stamp rect (spec Open Question 9).
6. **`design/ux/interaction-patterns.md`**: add candidate pattern P29 "single-button modal over a stopped field" (Coach card) or fold into P10.

## Still open

- Spec Open Questions 1-16 remain as design questions; new ones: 12 (hidden rows), 13 (PRACTICE latch in DRILL), 14 (Fire toggle word), 15 (per-plane tips), 16 (Title overflow, awaiting amendment 1).
- Bengali strings are draft pending native review; `tut.school.loading`, `tut.school.empty`, `tut.school.unavailable`, `tut.school.reset_warn`, `tut.school.all_done` are new keys.
- The `drones` drill for Sentry/Breaker (their drone behaviour) depends on Kits GDD 29 events; unverified here.
- Tally tip band (1 Bengali line) still needs a short Bengali variant (spec OQ 1).
- Player journey document does not exist (Journey Phase stays "unknown").
