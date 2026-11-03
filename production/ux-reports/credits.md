# UX Review: Credits (`design/ux/credits.md`)

Date: 2026-11-03. Checklist: Phase 3A (screen spec). Cross-checked: `menus-title-plane-select.md` (Rules 8, 10-12, 16, 46), `interaction-patterns.md` (P05, P21, P26, Back table, Animation/Sound standards), `localization.md`, `accessibility-options.md`, `accessibility-requirements.md` (Section 4 and Section 5 Credits row), `arcade-ui-style.md`, `main-menu.md`.

## Verdict before fixes: NEEDS REVISION

## Verdict after fixes: APPROVED WITH ADVISORY ITEMS (one dependency on a Menus Rule 46 amendment, see below)

## Completeness (before)

| Item | Result |
|---|---|
| Header, Purpose, Context, Navigation, Entry/Exit | Pass |
| Layout zones + component inventory | Pass (no chevrons, no licence block component) |
| States: loading | FAIL (missing) |
| States: empty | Pass |
| States: error (licence block / parse / glyph) | FAIL (only "missing file") |
| Interaction map, all input methods | FAIL (see Blocking 1-3) |
| Data requirements with owner | FAIL (no owner column; "UI owns no game state" is not an owner) |
| Events fired | Pass |
| Transitions | Pass (end position contradictory) |
| Accessibility | FAIL (contradicts Section 5; no ratios) |
| Localization with char limits | FAIL (no limits, no explicit licence rule) |
| Acceptance criteria (>= 5, perf, resolution) | Pass count; missing coverage of key behaviours |

## Blocking issues found

1. Pad "Wheel" scroll was impossible: a gamepad has no wheel, so a pad/keyboard player had no way to slow, stop or re-read. Violates "keyboard-only fully specified", untimed menus, and `accessibility-requirements.md` Section 5 ("scrollable by input at the user's pace").
2. `Start/Back on a pad exit like Cancel` conflicts with Menus Rule 12 (Start is Confirm, so it should be Fire here).
3. `reduce_motion`: spec said scroll continues; `accessibility-requirements.md` Section 5 says scroll off under reduce motion. P21 requires a declared option.
4. No Loading state; no licence-block failure state (legal credit could vanish silently).
5. "Ended" was contradictory: "last line has left the top edge" with "last page stays" yields a blank viewport.
6. Data table had no owners; "UI owns no game state" is a banned owner.
7. No focus order statement; P02 was cited though nothing is focusable.
8. Localization: no character limits or 40% rule applied numerically; licence text "not localised" was stated but without the rule that it is not a lint miss and how it looks on the Bengali screen; no note about the missing language chip.
9. Accessibility: no contrast ratios, no screen-reader stance, no "no timeout / attract" statement.
10. P26 (chevrons) is listed for Credits in the pattern library but unused.

## Advisory items (not blocking, left open)

- Touch drag scroll, tap-to-resume (OQ 5). Reduce-motion opt back into auto-scroll (OQ 6). Licence body length and source (OQ 7). Name char budgets are proposals pending font integration.

## Fixes applied

1. Header: new `Sources` entry (`accessibility-requirements.md`), pattern list (P26 added, P02 removed), revision note, status line.
2. Layout Zones / Component Inventory: added more-above/more-below chevrons (P26), Licence block, Status line components; licence body left-aligned; noted no new pattern.
3. States & Variants: added Loading (scroll clock starts after the enter wipe), Manual, Partial data, Error: licence block, Error: missing glyph; rewrote Ended (last line at viewport centre, never blank); rewrote Reduce motion (auto-scroll off, opens in Manual); Empty now covers unparsable data and logs once.
4. Interaction Map: removed the pad "Wheel"; added Nav up/down line scroll with repeat 18/6 for pad and keyboard, Resume with Fire/Start press, Start = Confirm (not exit); wheel switches to Manual. Added Focus Order sub-section.
5. Entry & Exit: carries `reduce_motion`; exit works in every state; no timeout, auto-exit or attract on this screen.
6. Events: manual scroll/resume stated as null; failure log line added.
7. Transitions: manual step rule and accumulator reset, end offset formula, recomputed length example (45 s / 23 s), P21 option declaration.
8. Data Requirements: added Owner column to every row, licence-block rows, `access.reduce_motion`, new string keys, local scroll-state row; replaced "UI owns no game state".
9. Accessibility: COMPREHENSIVE reference, contrast (`#F4EBD6` on `#1E1B18`, 7:1 or better), pause/stop/hide answer, untimed by construction, sound visual twins, screen reader out of scope per Section 4.
10. Localization: explicit rule that licence text is never localised and is exempt from lint; no chip on this screen; character limits (title 16, heading 21 = 15 + 40%, name 40, role 30, licence title 40, licence body 600) flagged as proposals; wrap rules.
11. Acceptance Criteria: extended from 10 to 13 (manual scroll hold, reduce_motion, Start behaviour, end position, licence failure, no timeout/attract, licence text identical in both languages); existing performance and resolution criteria kept.
12. Open Questions: re-numbered; added 6, 7, 8.

## Cross-document amendments requested

1. `design/gdd/menus-title-plane-select.md`, Rule 46 (line 135). Current: "...Scroll speed `credits_px_per_s` (24), integer steps; holding Fire doubles it; Cancel exits. Names are proper nouns and are not translated (excluded from the string lint allow-list)." Proposed: append "Nav up/down scrolls one line and pauses the auto-scroll; Fire or Start press resumes it; with `access.reduce_motion` on, the auto-scroll is off and the screen opens in manual mode (Accessibility requirements Section 5). Scrolling stops with the last line at the viewport centre; there is no loop and no auto-exit. Licence text is not translated and is excluded from the string lint allow-list. Start acts as Confirm (faster), not as Cancel." Also add `access.reduce_motion` to the Menus read list.
2. `design/gdd/localization.md`, string key registry (Menus keys section): register `menu.credits.empty` and `menu.credits.licence_missing` (en + bn), and confirm `credits.section.*` keys exist. Proposed English: "No credits available." and "Licence text unavailable."
3. `design/gdd/accessibility-options.md`, Rule on `access.reduce_motion` (Rule 10 and Dependencies row for Menus): add Menus (Credits roll off, Manual mode) to the consumers of `reduce_motion`; the Tuning table's "Used by" column for `access.reduce_motion` currently reads "HUD, Parallax, Warning" and should add "Menus (Credits)".
4. `design/ux/interaction-patterns.md`, P26 and Gaps table row 4: mark Gap 4 closed ("answered in credits.md: Nav steps one line and pauses; Fire resumes; reduce_motion = manual only") and add Credits as a line-step (not whole-row) variation under P26 if the owner wants it recorded. Also add Credits to the Back table note "Start is Confirm, not Cancel" if desired.
5. `design/gdd/menus-title-plane-select.md`, Open Question 15: add that licence entries use a kind LICENCE record (title, body) in `credits.tres`.

## Still open

- Rule 46 amendment is required; until applied the GDD wins and manual scroll is unspecified in the GDD (flagged in the spec's Interaction Map and OQ 1).
- OQ 5 touch gestures, OQ 6 reduce-motion opt-in, OQ 7 licence body length/source, character budgets pending real fonts and content (producer, Menus OQ 15).
