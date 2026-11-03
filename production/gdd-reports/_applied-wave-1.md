# Applied amendments — wave 1 (2026-11-03)

Applier pass over the six report files in `production/gdd-reports/`. Status words: **applied** (as written), **adapted** (applied with a change, reason given), **skipped** (not applied, reason given). All paths are relative to the project root.

## Cross-cutting (resolution rules)

| Item | Status | Notes |
|---|---|---|
| Co-op hp scaling (rule 1) | adapted | `design/gdd/enemy-and-ai.md` F4 now uses Co-op's `coop_hp_scale` verbatim: `(hp_base × (100 + coop_hp_step × (N − 1)) + 50) / 100`, step 50 %. `round10` dropped. The variable table, output range (×2.5 at 4P, 450 → 1,125), examples, decision note, tuning knob (`coop_hp_step`, owned by Co-op), test defaults, AC-19 (1,500/2,250/3,750; 3,760; 900/1,125) and Open Question 4 were all recomputed. A Co-op (18) upstream row was added to Enemy's Dependencies. `enemy_coop_hp_pct` was NOT registered. |
| Systems index count (rule 3) | applied | 13 GDDs listed. `plane-kits-lancer-leech.md` does not exist, so row 11 is unchanged. "Code exists without GDD" is now 3 (14, 17, 20 partly). |
| Rule-file "use delta" (rule 4) | skipped | ADR-0001 wins. No `.claude/` edits. |
| project.godot / src/ (rule 7) | skipped | Listed below as programmer tasks. |

## systems-index.md (`design/gdd/systems-index.md`)

| Source | Amendment | Status |
|---|---|---|
| Localization 1–4 | Row 27 Designed; tracker +1; "language split (ADR)" removed from open items; interface note for 20/21/22/26/28 | applied (the note goes in Dependency notes as a "Localization (27)" bullet) |
| Save 5 | Row 26 Designed; Depends stays 1, with a note listing soft providers 2/4/24/27/28; row 28 → `20, 22, 26`; row 22 → `2, 26`; row 21 → `7, 8, 26 (soft)`; tracker; Vertical Slice / Rule 31 note | applied |
| Save 6 | Future GDDs must list Save | applied as a Dependency-notes bullet (the target GDDs don't exist yet) |
| Co-op 9 | Row 18 → `1, 5, 7, 8`, Designed; tracker; note that 10/13/14/16/26 must list Co-op | applied |
| Input 1, 6 | Row 2 Designed; code-without-GDD count 3; GDDs 11/12/18/20/22/26/28/31 must list Input | applied (note bullet). Co-op (18) got an Input row directly; Save (26) already lists Input. |
| Display (systems-index) | Row 4 Designed, Depends `1 (soft), 26 (soft)`; tracker; Foundation leftovers marked done; 20/22/26/28/31 must list Display | applied |
| Enemy 5 | Row 10 → `3, 6, 8, 9`, Designed; tracker | applied |
| Open items | "co-op lives/continues" and "language split (ADR)" removed, with a closing note | applied |

## Registry (`design/registry/entities.yaml`)

| Source | Status | Notes |
|---|---|---|
| Localization: `bn_width_reserve_pct`, `bn_size_s`, `digit_grouping`, `supported_languages`; formulas `format_int`, `digit_cell_width`; `score_display_digits` += localization | applied | |
| Save: `high_score_board_size`, `initials_length`, `score_store_max`, `save_file_version`, `setting_access_reduce_flashing`; formulas `board_id`, `board_placement`; referenced_by += save on `one_credit_clear`, `score_display_digits`, `chain_cap`, `starting_lives` | applied | `board_id` output text was quoted for YAML safety. `board_id.referenced_by` also gained `coop-and-team-chain`. |
| Co-op: `team_pct` updated (value 120 unchanged; unit, note, source and referenced_by updated); `team_pct_step`, `team_window_step`, `team_join_grace`, `coop_hp_step`, `coop_spawn_step`, `team_bonus_share_max`; formulas `team_pct_by_members`, `coop_hp_scale`, `coop_spawn_scale`, `team_window_by_active`; referenced_by += co-op on 8 entries | applied | `coop_hp_step.referenced_by` also gained enemy-and-ai. |
| Input: `max_players`, `dz_enter`, `dz_exit`, `sector_hyst`, `buffer_ticks`; formula `press_edge` | applied | |
| Display: `canvas_size`, `auto_fill_min_pct`, `tate_confirm_seconds`, `bezel_feature_min_px`; formulas `display_scale`, `window_to_canvas`; `play_top` += display | applied | |
| Enemy: `enemy_hurtbox_budget`, `enemy_max_alive`, `enemy_ref_dps`, `kill_cancel_radius`, `enemy_hurt_pad`, `enemy_fire_inset`, `enemy_plating`; `enemy_path_position`; referenced_by += enemy on 14 entries | applied | `enemy_ref_dps.unit` was quoted because it contained ": ". |
| Enemy: `enemy_coop_hp_pct` | skipped | Rule 1: Co-op's `coop_hp_step` is registered instead. |
| Enemy: formula `enemy_spawn_hp` | adapted | It is now `coop_hp_scale(hp_base, N)` for MEDIUM/LARGE, with `inputs_owned_elsewhere: coop_hp_step` and output ×2.5 at 4P. |

Validation (there is no yaml module): every line matches `  - name:` or `    key: value`; there are no duplicate names (100 entries); every entry has value/expression, source and referenced_by; no plain scalar contains ": " or " #"; constants come before `formulas:`.

## ADR-0001 (`docs/architecture/adr-0001-gdscript-bullets-multimesh.md`)

| Source | Status |
|---|---|
| Input 4: step 1 → `InputSampler snapshot (autoload, ALWAYS, ticked before GameLoop)` | applied |
| Enemy 6: steps 3b (EnemyManager.tick) and 6b (EnemyManager.apply_results) | applied |
| Budget rows: Pattern tick ≤ 0.2 ms (≤ 1.7 ms with the bullet update; Pattern AC-53 / Open Q10) and Enemy tick ≤ 0.2 ms (Enemy AC-56) | applied. Status unchanged. |

## Art bible (`design/art/art-bible.md`), additive, dated notes

| Source | Amendment | Status |
|---|---|---|
| Localization 5 | §8.8 digit atlas and the Coverage row gain `,` | applied |
| Localization 6 | §7.5 note: 1.375 rule gives 33, XL fixed at 34; proposed digit cells | applied |
| Co-op 8 | §4.4 shots 50 % → note: superseded by BM V3 (100/75/50 by count); §5.6 drones → note: 100 % (PP V6); §6.8 draw-order line 6 updated; §7.3 new row for the `+20/+30/+40` tag and the 2×2 lamps | applied (§3.6, §7.9 "dim below 50 %" and §8.2 "50 % co-op shots" were left as they are; see inconsistencies) |
| Display | §8.1 stretch settings struck → SubViewport presenter; §8.1.1 Fill → one-pass sharp-bilinear (F5); safe areas "phones only"; §8.9 spike 3 extras | applied |
| Enemy 7 | §5.7 carrier cue and LARGE plating overlay; §6.8 per-class explosion sizes, ground layer 2 with 180-tick scorch; §5.3 tell lead 12 ticks | applied |

## Other files edited by me

| File | Source | Amendment | Status |
|---|---|---|---|
| `docs/project-structure.md` | Display | `src/display/` and `data/display/` added to the folder tree, marked "planned" | applied |
| `design/gdd/save-settings-high-scores.md` Rule 17 | Localization 12 | Save keeps `"auto"` as the default; a dated note says Localization writes the resolved `bn`/`en` back on first run and calls `set_language` on load | adapted (keeps Save's schema and AC-20/AC-27 valid while honouring Localization Rule 3) |
| `design/gdd/coop-and-team-chain.md` Dependencies | Input 6, Enemy | Upstream Input (2) row added; the provisional "Enemy (10), Boss (14)" row now reads Boss only, with a note that Enemy adopted F4 | applied |

## Skipped: target GDDs do not exist yet (carried in systems-index Dependency notes)

- Localization 8–11 and 13 (HUD 20, Boss 14, Critical Break 17, Menus 22, Accessibility 28).
- Save 6 (Input already lists Save; the rest are future GDDs).
- Display "future GDDs 20, 22, 26, 28, 31". Save (26) already lists Display settings.
- Enemy 10 (Boss GDD must confirm bosses are exempt from fire-zone arming). Recorded in Pattern library OQ5 closure (see group B).
- Co-op: Wave director (16) / Powerups (13) / Boss (14) must list Co-op.

## Programmer tasks (not done: code and project files)

- `project.godot`: 480×640 → 360×640; stretch mode `canvas_items` → disabled; portrait orientation on mobile; scene host under the SubViewport (Display scaler).
- `src/autoload/input_setup.gd`: replace it with InputSampler + DeviceAssigner; rename `pN_ability` → `pN_drone`; remove the 0.2 action deadzone and `Input.get_vector` movement; move debug keys to F5–F9 in debug builds only (R collides with KB2 Bomb).
- New `src/display/` (DisplayLayout, DisplayPresenter, sharp_bilinear.gdshader) and `data/display/display_params.tres`; `data/input/input_rules.tres`.
- Boss code float hp → integer hp (Enemy report).
- Session: new `forfeit_slot(slot)` API; `coop_count_changed` signal published by Co-op.

## Group A (session, scoring, collision, game-concept)

### design/gdd/game-events-and-session.md
- Save 1a, Rule 2 (preview_rank / submit_run, not for ABANDONED): applied.
- Save 1b, Rule 4 adds `joined_at_run_start`: applied.
- Save 1c, Run record subsection: applied. It is unnumbered and sits after Rule 10, so the rules keep their numbers. Its table is copied from Save's `RunRecord` table.
- Save 1d, Open Question 6: closed (strike + Closed 2026-11-03).
- Save 1e, AC-06: applied (two calls, name entry between them, initials default on timeout).
- Rule 7 drop-in note: adapted. I replaced the "Provisional: boards may separate drop-in runs" line with the Save decision and added "slot choice = Input F7" (Input amendment 3).
- Co-op 5: Interactions row and Dependencies row now say Co-op owns `N`, the join grace and `coop_count_changed`. Added `coop_count_changed(old, new)` to the Rule 13 signal list. Applied.
- Input 3: added a note under the slot-state table for the Alive/Dead/Continue/Selecting → Inactive transition on `forfeit_slot`. Updated the Input Interactions row and the Downstream row. Closed Open Question 2. Applied.
  - Adapted: the edge case "pad disconnects mid-run" now says the game auto-pauses (Input Rules 28–33).
  - Adapted: AC-03's rejected example "Dead→Inactive" now reads "other than by `forfeit_slot`".
- Display: added a Downstream row for Display scaler and bezel (4) (Soft). Applied.
- Enemy 8: added the five presentation signals to the Rule 13 provisional list. Applied.
- Added "— GDD" tags to the Input, Co-op and Save downstream rows.

### design/gdd/scoring.md
- Save 2: closed Open Question 7. The Save Interactions row and Downstream row now say "stores the true int64, display clamp unaffected". Applied.
- Co-op 2:
  - Test setup now reads `set_team_pct(slot, pct)`.
  - The Interactions Co-op row was adapted to show per-slot `set_team_pct`.
  - F1 `team_pct` row now reads 100 / 120 / 130 / 140.
  - S9 member = a slot in Chain's `M`.
  - The Co-op provisional-contract row was updated.
  - Added `team_bonus_points` as an info-only HIT breakdown line under F8.
  - Closed Open Question 2.
  - Applied.
- Enemy 4: the Collision Interactions row now says the class comes from Enemy `kill_class`. The Powerups row now says kill-cancel items count toward `items_per_cancel_cap`. Also updated the Enemy provisional-contract row. Applied.
- Localization 7: F8 HUD plate now states Western 3-digit `,` grouping in both languages, formatted by `Localization.format_int`. Also updated the `display_score` output row and the HUD downstream row. Applied.

### design/gdd/collision-damage-lives.md
- Save 3: line 379 now names the `access.reduce_flashing` key. Applied.
- Enemy 2:
  - Rule 1 now reads "any lethal enemy body", with the `lethal` flag and its default.
  - Rule 12 adds `hp_after`.
  - The test-setup `set_bodies` record adds `lethal` and `kill_class`.
  - `hit_results` adds `hp_after`.
  - The Enemy Dependencies row was appended.
  - The immune-body edge case now says "(lethal bodies only)".
  - Applied.
  - Not changed: the Player Fantasy line "contact with any enemy body" (line 15) and the Notes line "All bodies kill" (line 22). The report flags these as Enemy Open Question 2, and changing the fantasy text is out of scope.

### design/gdd/game-concept.md
- Save 4: the §12 Target row now reads "solo per plane, co-op per player count". Applied.
- Co-op 7: closed the §14 lives/continues question (per player, no revive). Added the scaling note to the §13 4P risk. Applied.
- Input 5: added a Start/Back note to the "Three buttons" line under Shared rules. Applied.

### Skipped
None.

## Group B (chain-tracker, bullet-manager, bullet-pattern-library, player-plane)

### design/gdd/chain-tracker.md
- Co-op 1a (Rule 11 team test, `M`, `team_members()`, `set_team_exempt`) — **applied** to Rule 11 and the Interactions table Co-op row.
- Co-op 1b (F3 `team_window + team_window_step × (a − 2)`) — **applied** to F3 (formula, variable rows `team_window_step`, `a`, `M`), and Rule 1 (counted hit) so it agrees with F3.
- Co-op 1b knob `team_window_step` 8 (0–15) — **applied** (new Tuning Knobs row; `team_window` row's "consider 75 for 4P" text replaced).
- Co-op 1c Open Question 2 — **applied** (struck, closed "60 / 68 / 76 … (Co-op (18) F3)").
- Co-op 1d Dependencies Co-op row — **applied** ("owns what the bonus pays and the join-grace flag"; adds `team_members()` / `set_team_exempt`).
- Enemy 9 (Dependencies note) — **applied** as a new Upstream row "Enemy and AI (10) — Soft — no interface; kills add no bonus".

### design/gdd/bullet-manager.md
- Co-op 3a fair share — **applied**: Rule 1 player-pool bullet, F10 (extra formula line + `N_p`, `active_slot` variable rows), knobs (`player_share_enabled` row, owned by Co-op), new AC-05a, Test setup (`set_player_count(N)`, `refused_player_share` output). **Adapted:** F10 already uses `N` for steady-state bullet count, so the player count is written `N_p` there.
- Co-op 3b define `N` by Co-op Rule 1 — **applied** in Rule 1 and V3 opacity line.
- Co-op 3c Rule 16 + Co-op row "rotation confirmed by Co-op (18)" — **applied**.
- Enemy 3a cancel requesters — **applied** in Interactions table and Downstream Dependencies (Enemy row + note on Bombs/CB row).
- Enemy 3b hurtbox note (multi-circle `(id, gen)`; 40 = 32 enemy + 8 boss) — **applied** in Rule 11, Downstream Enemy/Boss row, and Test setup `set_hurtboxes`.

### design/gdd/bullet-pattern-library.md
- Co-op 4 (OQ4) — **applied** (closed: rotation kept for MVP).
- Enemy 1a (OQ5) — **applied** (closed: Enemy Rule 18), plus Enemy 10 note "Boss (14) must confirm bosses are exempt from this arming rule".
- Enemy 1b (`next_volley_in`, frozen intensity) — **applied** to Interactions table Enemy/Boss row (arrow now ↔) and Downstream Enemy row (also records the no-off-screen-fire rule).
- Parent request: OQ10 — **applied** (closed: "row added to ADR-0001 budget table (amendment pass)"); AC-53 text "Needs an ADR-0001 budget row" changed to "Budget row in ADR-0001 (added 2026-11-03; Open Question 10 closed)".

### design/gdd/player-plane.md
- Co-op 6 (PF5 + Rule 15: `N` defined in Co-op Rule 1) — **applied** (PF5 variable row, Rule 15).
- Co-op 6 (Co-op dependency Soft → Hard, grace trigger) — **applied**.
- Input 2: Dependencies Input row (GDD exists, `pN_drone` final) — **applied**.
- Input 2: Rule 9 wording (SlotInput snapshot) — **applied**.
- Input 2: Interactions Input row (deadzone values in `data/input/input_rules.tres`) — **applied**.
- Input 2: Rule 10 `clear_buffer(slot)` every non-Active tick — **applied**.
- Input 2: AC-20 replaced — **applied**.
- Input 2: Open Question 5 resolved — **applied** (closed, Input Rules 28–31).
- Input 2: edge case pad disconnect → pauses first — **applied**.

### Inconsistencies noticed (not fixed)
- chain-tracker AC-27 / AC-01 / AC-47 still describe the team test and `boss_hit_left = team_window` in 2P terms; no AC covers `team_window_step` (68/76) or exempt slots. Co-op GDD ACs cover them, but Chain tests need new ACs.
- chain-tracker F3 example and Edge Case "one of two Active players starts Dying" are still correct, but the Edge Case "restart once ≥ 2 Active slots have all hit" should read "|M| ≥ 2 and every non-exempt Active slot is in M".
- player-plane Rule 9 still says `held_time` in seconds; Input `SlotInput` uses `held_ticks` (integer). Units differ (ticks vs seconds) between the two GDDs.
- player-plane test setup `set_input(stick, digital, fire, drone, bomb)` does not mention the SlotInput type or start/back.
- bullet-manager AC-05a numbering inserted as "05a" to avoid renumbering.

## New inconsistencies noticed (for the consistency check)

1. **Deadzone:** Save has `input.pad_deadzone_pct` = 20 ("matches InputSetup.DEADZONE 0.2"). Input removes that constant and uses `dz_enter` 0.30 / `dz_exit` 0.20 in `input_rules.tres`, plus a `dz_preset` from Accessibility.
2. **Pad action name:** Save's binding schema uses the pad suffix `ability`, and its `kbd` overrides are "P1 only". Input renamed the action to `drone` and added a second keyboard scheme (KB2) for 2P.
3. **Language default:** Save's `language` defaults to `"auto"`, while Localization stores an explicit `bn`/`en`. Reconciled with a note in Save Rule 17. The Save AC-20 and AC-27 wording still assume `"auto"` persists.
4. **Chain tracker:** AC-01, AC-27, AC-47 and the team-chain restart edge case still describe the old 2P-only team test. No AC covers the 68 / 76 windows or exempt slots.
5. **Player plane:** Rule 9 `held_time` is in seconds, but Input's `SlotInput` uses `held_ticks`. The test setup `set_input` does not mention `SlotInput`.
6. **Collision:** the Player Fantasy and Notes text still say "all enemy bodies kill", against the Enemy GDD's non-lethal ground targets (Enemy Open Question 2).
7. **Art bible:** §3.6, §7.9 ("dim other players' shots below 50%") and §8.2 ("50% co-op shots") still assume a flat 50 %.
8. **Co-op scaling scope:** Co-op scales PART/CORE hp by `N`, but no Boss GDD exists yet to confirm it. Enemy scales MEDIUM/LARGE only, which matches.
9. **Team pct interface:** the Co-op GDD's Downstream table says Scoring reads `team_pct_for(slot)` (pull). Scoring now has Co-op call `set_team_pct(slot, pct)` (push). One side needs to change.
10. **Session Dependencies:** a stale line still says none of these systems has a GDD yet.
11. **Game concept §13:** still says "other players' shots at reduced opacity". This only loosely matches BM V3 (100 / 75 / 50 % by player count).

## Follow-up fixes (coordinator request, 2026-11-03)

| # | Fix | Files | Status |
|---|---|---|---|
| 1 | `input.pad_deadzone_pct` replaced by `input.dz_preset` (`low`/`default`/`high`; values owned by Input's `input_rules.tres`, default 0.30/0.20). Added `input.fire_toggle` and `input.tap_assist`. Interactions, Dependencies, Owned-elsewhere and AC-20 updated. Save amendment 6 closed. | `design/gdd/save-settings-high-scores.md` | applied |
| 2 | Rule 18 binding schema is now `{version, kb1, kb2, pad}`. Actions are `fire`/`drone`/`bomb` (plus movement keys in kb1/kb2), at most 2 controls each, and no key may sit in both kb1 and kb2. AC-25 and AC-28 were rewritten; `ability` is dropped as unknown. | same | applied (I picked the movement action names `up/down/left/right` myself; the Input GDD doesn't name them) |
| 3 | AC-27 now checks: a fresh store reads `"auto"`, the first boot writes back `bn`/`en`, and a stored explicit value is never overwritten. | same | applied |
| 4 | AC-01 (F3 window), AC-27 (`M`/exempt), AC-28 restart, AC-47 (2 Active stated) and the "one of two Dying" restart edge case all use the new team test. New AC-27a covers the 60/68/76 window by Active count. New AC-27b covers join-grace exemption. | `design/gdd/chain-tracker.md` | applied |
| 5 | Rule 9, Rule 10, test setup (`set_input(slot_input)`, `kit_buttons.held_ticks`), AC-17 and AC-19 now use integer `held_ticks` (30 ticks = 0.5 s). Input's "Owned elsewhere" line also renamed to `held_ticks`. | `design/gdd/player-plane.md`, `design/gdd/input-and-player-mapping.md` | applied |
| 6 | §3.6, §7.9 and §8.2 got dated notes: BM V3 shots 100/75/50 by player count, PP V6 drones 100 %. | `design/art/art-bible.md` | applied |
| 7 | Boss PART/CORE hp scaling | — | left for the Boss GDD, as requested |
