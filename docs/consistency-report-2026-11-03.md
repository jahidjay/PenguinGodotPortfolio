# Consistency Check Report — 2026-11-03

**Scope:** 32 system GDDs in `design/gdd/` (all except `game-concept.md` and `systems-index.md`) against `design/registry/entities.yaml` (262 entries: 190 constants, 72 formulas).
**Method:** a script scan of every registry constant name in every GDD (the number after the name compared to the registry value, with each hit read in context), plus targeted scans for known stale values (`ref_dps` 300, peak 1,000, `extend_unit` 1,000,000, old enemy and boss hp, `enemy_coop_hp_pct`, 60 % co-op hp, `team_pct` ≠ 120, `BAR_PX` 96, `enemy_bullets_alive`, `display.bezel`/`integer_scale`, `pN_ability`, `screen_flash_requested`), then the 7 wave-4 leftovers in `production/gdd-reports/_applied-wave-4.md`.
**Mode:** auto-approve. Edits followed ownership rules (the owning GDD wins). Every edit was a scripted exact-string replacement with `assert count == 1`.

## Conflicts found and fixed (🔴)

| # | Docs | Conflict | Fix (owner wins) |
|---|---|---|---|
| C1 | HUD ↔ VFX, Session | HUD said "VFX 25 owns `screen_flash_requested`". VFX Rule 5 and Session Rule 13 mark that signal deprecated. | HUD now says the signal is deprecated (VFX Rule 5, Session Rule 13). |
| C2 | Bullet manager ↔ VFX, Sentry/Breaker, Powerups | There were two `cancel_report` shapes. VFX used `(cause_slot, area, positions, count)` and the kits used `(slot, request_id, count)`. | BM Rule 13 now defines **one** per-tick `cancel_report[]` with entries `(request_id, cause_slot, area, items, count, positions_in_pool_order[])`. VFX reads it the same tick, Powerups reads the `items = true` entries and the kits read their own entries the next tick. Updated in BM (Rules 13–14, Interactions, Dependencies), VFX, Sentry/Breaker (Rule 25, Interactions, OQ2), Powerups and the systems index. |
| C3 | Touch ↔ Plane kits (LL, SB) | Touch used a "provisional" `drone_state`. LL Rule 40 named it but never defined its fields. | LL Rule 40 now defines `drone_state(slot) = (state READY/ACTIVE/COOLDOWN, cooldown_permille)`. SB Rule 38 uses the same shape. The Touch and LL Interactions rows no longer say provisional. |
| C4 | Touch ↔ Bombs | Touch had "bomb accepted (event name provisional)". | Touch now uses `bomb_used(slot)` (Bombs Rule 5). |
| C5 | Touch, Localization ↔ Save | Touch string keys (`touch.hint.*`, `touch.solo`, …) used the same `touch.` prefix as the Save setting keys. | String keys renamed to `ui.touch.*` in Touch (7 keys) and Localization (Rule 5 file list and Interactions rows). Save keeps the `touch.*` setting keys. Menus had no touch string keys to change. |
| C6 | Audio ↔ Tutorial, Sentry/Breaker, Online/Rush | Cues listed in those GDDs had no Audio IDs. Tutorial used placeholders. | Audio Sound Event List gained 9 kit rows, 2 bomb rows (Bastion, Backlash) and UI rows: `sfx_ui_deny`, `sfx_tut_drill_done`, `sfx_tut_coach_open`, `sfx_ui_upload_tick/ok/error` and `sfx_rush_refit`. Per Tutorial's own cue list, the strip marks, hints, drill start and drill fail stay silent; they are added to Audio's "Not sounds" list. Cross-references updated in Tutorial, SB A1, OL Visual and the Audio Dependencies rows. |
| C7 | Session, Menus ↔ Online leaderboards | Session Rule 1 / Rule 13 / Interactions and Menus Rule 23 / Interactions said `start_run(selections)`. The OL row in Session said `start_run(selections, mode, stage_list)`. | All of them now use `start_run(selections, mode, stage_list)` (MAIN and the main list by default). This is recorded as a decision. |

## Gaps closed (wave-4 leftovers, not conflicts)

- **HUD compact 48 px column form (D3):** added an exact rect table with four 90 px columns in the 48 px strip. The pick plate is (5,2,84,44) with `shares_lane` over the boss row, and the chain plate is (44,14,46,22) with `BAR_PX` 42. Also added the data file `hud_layout_compact48.tres`, made the lint cover four layouts (AC-03), and added the `BAR_PX` 42 value to HUD HF2 and the Chain tracker F6 table. Rule 23 now points to the table.
- **Menus structured entries:** added state rows `PlayChoice` and `BossSelect`, a Screens row, and style rows for the Play choice, the Boss select and the **touch row pitch** (`touch_item_h = max(menu_item_h, min_target_canvas_px)`, TF7).
- **Recorded decisions** (dated "decided under auto-approve 2026-11-03, consistency check"):
  - `RunRecord.touch` (Session and Save)
  - `start_run(selections, mode, stage_list)` (Session, Menus; the Leaderboards text already used it)
  - `ui_touch.csv` (Localization)
  - Sentry/Breaker wing offsets: Sentry (∓31, +4), (∓45, +10) and Breaker (∓31, +4), (∓49, +10). PF4 arithmetic re-checked in Player plane and in the SB Interactions row.

## Stale registry fixed (⚠️)

| Entry | Was | Now | Why |
|---|---|---|---|
| `hud_chain_bar_px` | "94 (1-2P), 82 (3-4P)" | "94 (1-2P), 82 (3-4P), 42 (compact 48 px form)" | The owner (HUD) added the compact form. A `# was:` comment is kept. |

No locked value was changed. The constant-by-name scan found 37 numeric differences. All of them are tuning examples in ACs ("with `x` 0 …"), unit conversions (`move_speed` 210 px/s = 3.5 px/tick, `focus_speed`), threshold tests (`sweep_min_ticks` 74/75), derived co-op values (`team_pct` 130/150 for 3 members or a test knob), or historical notes (old `ref_dps` 300, the `extend_unit` 1,000,000 test parameter in the Session test setup, peak 1,000 → 1,300 history). None is a conflict.

## Notes (ℹ️)

- Stage-end tally Amendment 13 still said that the registry had "peak 1000 per point". The registry was fixed in wave 3a, so the amendment is now marked done.
- Old enemy and boss hp (450/560/1,500/1,880; 900/1,200/6,200/700/1,550/7,400) only appear as current hp values (1,200/1,500 are the re-based flak and radar gunners) or as unrelated numbers (density warnings, coordinates, test scores). No leftovers.
- `enemy_coop_hp_pct`, `enemy_bullets_alive`, `BAR_PX 96`, `p?_ability`, `display.bezel`/`integer_scale`: these names appear only in retirement or rename notes.
- Historical amendment lists (for example SB Amendment 2, VFX Amendment 4) still quote the old shapes as history. They were left as is on purpose.

## Unresolved

1. Art bible §5.6 Breaker "pulse arc" row vs the superseding corner-bracket note: the art-director must confirm (SB OQ6). This is outside the GDD scope.
2. Display scaler duplicate "Matched" key note: cosmetic, left as is.
3. All new sound IDs, the compact HUD rects and the Menus rows are design-side choices made under auto-approve. They still need the audio-director, `/ux-design` and lead-programmer reviews (`start_run` signature, `cancel_report[]` cost: SB OQ2).

## Counts

- GDDs checked: 32. GDDs edited: 17 (BM, VFX, SB, LL, Powerups, HUD, Chain, Touch, Localization, Audio, Tutorial, OL, Session, Save, Menus, Player plane, Stage-end tally), plus the systems index and the registry.
- Conflicts found: 7, fixed: 7. Stale registry: 1, fixed. GDDs involved in a conflict: 15 (incl. Bombs, read-only side); clean GDDs: 17.

**Verdict: PASS** (after fixes). All conflicts found were resolved by ownership. The items left open need specialist review, not design changes.
