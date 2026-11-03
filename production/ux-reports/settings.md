# UX Review: Settings (`design/ux/settings.md`)

Date: 2026-11-03. Checklist: Phase 3A (screen spec). Tier checked against: COMPREHENSIVE (`design/accessibility-requirements.md`, section 1.1), registry `design/gdd/accessibility-options.md` (wins on conflict).

## Verdict

- **Before fixes: NEEDS REVISION** (13 blocking issues).
- **After fixes: APPROVED WITH CONDITIONS.** Conditions: the cross-document amendments A1-A5 below, and the Open Questions 16-20 plus the existing 1-15.

## Completeness

Header, Purpose, Player Context, Navigation, Entry/Exit, Layout and Component Inventory, States, Interaction Map, Data, Events, Transitions, Accessibility, Localization and ACs all existed. Gaps found: no loading, empty or Save-absent states; no spec for the Input test screen (a COMPREHENSIVE item); no stage split (MVP / VS / Target); some actions had no event or null.

## Quality findings (blocking, all fixed unless noted)

1. Accessibility section said `accessibility-requirements.md` does not exist. It does, so the section was stale (including the screen-reader stance).
2. No MVP / VS / Target staging, so the MVP screen content was undefined.
3. Input test screen was only a LINK with no layout, states, exit or update trigger.
4. Help line (y 520-560) overlapped the list viewport (to y 552), and 2 Bengali lines (48 px) did not fit the 24-40 px help line.
5. First-run plate 328x120 cannot hold two dual-script wrapped blocks plus two dual-script buttons (about 240 px needed).
6. Touch: Back plate and stepper arrows were 24x24, which is about 4 mm; Touch Rule 30 requires `min_target_canvas_px` (55).
7. Navigation levels contradicted the layout ("device page" level versus the "Edit controls for" CHOICE on one page).
8. Timing rows showed ticks (jargon); now words and seconds.
9. Game speed PRACTICE warning appeared only when opened from Pause; the saved value silently makes later runs unranked from Title.
10. Inactive rows were "dim" at 2.2:1 and carried information; Alarm Red toast text is about 3.95:1 (below 4.5:1).
11. Start behaviour in holds conflicted with `pause.md` (Fire only); the L1/R1 group jump collides with the Gamepad: one hand preset (Fire on left shoulder).
12. Class names "Keyboard: Left hand" clashed with preset names; presets had no target-class rule.
13. Missing events (per-action reset, Use shared pad map, nulls), missing data rows (Input test, strings), localization line omitted the TATE dual-script title.

Known conflicts:
- **Stretch tab strip (6 tabs): not present in this spec.** Settings has no tabs; a rule was added forbidding a tab strip (index plus scrolling Accessibility list with group jumps). The 6-tab strip is a Board / high-scores matter and must be resolved in `high-scores.md`.
- **`reset_settings`:** resolved in the spec as a keep-list (A1).
- **`display_reset`:** resolved as two distinct controls (A2).

## Fixes applied

1. Header: Status, revision note, added `accessibility-requirements.md` to Sources.
2. Navigation Position and level table: removed the "device page" level, listening is a state, Input test is level 3, no tab strip rule.
3. Entry points: Input test source.
4. Layout Zones: header growth and breadcrumb rule, list viewport tied to help line, help line fixed bottom edge and height by text, touch hit areas.
5. Component Inventory: Delivery staging table (MVP / VS / Target); Accessibility index row tier.
6. Index: Reset settings consequence line; Language value own-script rationale; Reset settings keep-list paragraph.
7. Language page: two-chip CHOICE, initial focus.
8. Display: Reset display hold versus `display_reset` hotkey.
9. Controls: class renaming, preset scoping rule, keycap width, device availability.
10. Accessibility page: Game speed row in every opener, player-facing timing values (seconds / words), Tutorial hints and Reset these options scope and consequence.
11. New section "Input test screen".
12. First-run plate: height by content (about 240).
13. States: loading, empty, Save absent, Assist set from Title, Inactive rows, Save failure with error glyph and Cream text.
14. Interaction Map: focus order, holds Fire-only, Start ignored from Pause, group-jump suppression rule.
15. Events: four rows. Data: two rows.
16. Accessibility section: stale text replaced, contrast figures, screen-reader stance. Wireframe label updated.
17. Localization: TATE dual-script title.
18. Acceptance Criteria: 5 added (Input test, touch targets, layout, reset keep-list, Title assist and Save absent). Open Questions 16-20 added.

## Cross-document amendments requested

- **A1. `design/gdd/save-settings-high-scores.md`, Rule 30.** Current: "`reset_settings()` restores schema defaults for all known keys, keeps unknown keys, and keeps `profile.last_initials` and all `tutorial.*` keys". Proposed: "...keeps unknown keys, and keeps `language`, `access.first_run_prompt_done`, `profile.*` and all `tutorial.*` keys and `touch.hints_seen`." Also update AC-26 to match. Why: stops the photosensitivity plate reappearing and the UI language flipping to an OS guess.
- **A2. `design/gdd/menus-title-plane-select.md`, Rule 43.** Current: "'Reset display' is a `HOLD_BUTTON` equal to `display_reset`." Proposed: "...is a `HOLD_BUTTON` with the same effect as `display_reset` and the normal `confirm_hold` length; `display_reset` is the separate 2 s real-time hotkey." Keep AC-50 (60 ticks, make it "`confirm_hold` ticks, 60 at NORMAL"). **`design/gdd/display-scaler-and-bezel.md`, UI table "Reset display" (line ~390)**: "Same as `display_reset`" becomes "Same result as `display_reset`; hold length is `confirm_hold`."
- **A3. `design/gdd/accessibility-options.md`, Visual/Audio table, "First-run plate" row.** Current: "328x120 px plate, bilingual text, two items". Proposed: "328 px wide, height by content (about 240 px), dual-script text, two items".
- **A4. `design/gdd/menus-title-plane-select.md` F6 / `design/ux/interaction-patterns.md` P04.** Hold counts Fire only everywhere Start has another meaning (already requested by `pause.md`); also Menus AC-52 and Rule 43 should say Settings ignores Start from Pause.
- **A5. `design/gdd/accessibility-options.md` Rule 21 / `input-and-player-mapping.md`.** Add: group jump on pad must not use a shoulder bound to Fire/Drone/Bomb; add a verb `nav_group_prev/next` or accept the suppression rule. Also `design/accessibility-requirements.md` section 5.2 and G4: Settings UX spec now exists. Plus `art-bible.md` / style guide: Alarm Red text on the dark plate is about 3.95:1, so Alarm Red needs a glyph/words rule (style guide owner).

## Still open

OQ 1-15 from the spec remain (1 and 3 now carry resolutions A1/A2 pending central application; 4, 5 (class names resolved, preset target decided), 6, 7, 8-15 unchanged). New: 16 (MVP rows for Input toggles), 17 (keycap short names), 18 (Start in Input test), 19 (inactive-row style, art-director), 20 (Switch rows). Advisory not done: Language as a direct index row; a persistent "not saved" indicator after `save_failed`; PRACTICE hold safeguard (OQ 7).
