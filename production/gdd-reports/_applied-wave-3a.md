# Applied amendments — wave 3a (2026-11-03)

Applier pass over five reports in `production/gdd-reports/`: `critical-break.md` (CB), `wave-and-stage-director.md` (Dir), `stage-end-tally.md` (Tally), `menus-title-plane-select.md` (Menus), `hud.md` (HUD). Audio / VFX / Era shift / Parallax / Accessibility reports are left for wave 3b. Status words: **applied**, **adapted** (with a reason), **skipped** (with a reason). Paths are relative to the project root. Split: main pass (systems index, session, registry, follow-ups), Group A (boss, bombs, plane kits, chain, scoring, collision, bullet manager, game concept), Group B (co-op, localization, enemy, boss power budget, powerups, pattern library, save, input, display scaler), Group C (art bible, ADR-0001, the five new GDDs' cross-references). Every edit used scripted exact-string replacement with `assert count == 1`.

## Resolution rules used

| Rule | Outcome |
|---|---|
| Owners win | Director owns the stage timeline: `stage_cleared = max(boss_gone, boss_defeated + 90)`, watchdog `boss_defeated + 360`. Tally 10 ("`boss_gone` + 30") is **adapted** to this everywhere (powerups, stage-end-tally, session). HUD owns banners: `banner_wait_max` 180 governs the CB banner, and CB's 120 (`cb_banner_wait_max`) is superseded and not registered. Tally owns S8 pay-out sequencing; Scoring provides `pay_stage_end_line`. CB owns trigger/arming. Menus owns Results, pause and lobby. |
| Run flow | Lobby commit → Stage → `stage_cleared` → Tally (every stage, the last one included) → next Stage or Results. GAME_OVER goes Stage → Results with no tally. |
| Signals | All new events are consolidated in one block, `game-events-and-session.md` Rule 13, headed "Signals added 2026-11-03". |
| Code / project files | Not touched. See programmer tasks. |

## Main pass

### `design/gdd/systems-index.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Dir 1 | Row 16: depends on `1, 3, 9, 10, 13, 14, 15, 18`; Designed, GDD link | applied | |
| CB 1 | Row 17: depends on `1, 3, 7, 8, 11, 12, 14`; Designed, GDD link | applied | |
| HUD 1 | Row 20: depends on `1, 4, 7, 8, 11, 12, 14, 18, 27`; Designed, GDD link | applied | |
| Tally 13 | Row 21: depends on `1, 7, 8, 18 (soft), 26 (soft), 27`; Designed, GDD link | applied | |
| Tally 13 | Add 21 to the Input (2) and Display scaler (4) reminder lists | applied | |
| Menus 1 | Row 22: `2, 26; soft 1, 4, 11, 18, 27`; Designed, GDD link | applied | |
| Menus 1 | Note that HUD, Tally, Accessibility and Touch must list Menus | applied | New Dependency-notes bullet, which also records the run flow and points to the signal block. |
| all | "GDDs written" recounted from files | adapted | The count is **28**: 30 files, minus game-concept and systems-index; none contains "[To be designed]". All 28 are listed. Rows 19, 23, 24, 25 and 28 have GDD files, but their index status is left for wave 3b. |
| HUD 1 | "Code exists without GDD" | adapted | The count is **0**, not the report's "2". The cell now notes the pre-GDD prototype code in `src/` that must migrate. |
| CB 1 | Remove "Critical Break formula and Life Damage Bonus" from open items | applied | Moved to the closed list (Chain F4, Scoring F4, critical-break.md). |
| — | Pending-asks bullet | adapted | Added a dated note that the asks to 16 and 17 are answered in their GDDs. |

### `design/gdd/game-events-and-session.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Menus 2 | Rule 1: the run starts on Lobby commit via `start_run(selections)`; `abandon_run()`; `LobbyModel` holds pre-run slots; Selecting stays the drop-in state | applied | |
| Tally 2a | Rule 1, state table and AC-05: the last stage has a Tally, then Results; `run_ended_by = ENDING` is set at `boss_defeated`; `run_ended` fires and the RunRecord is built at tally Done | applied | AC-05 rewritten. |
| Dir 6 | State table: the Stage → Tally trigger is `stage_cleared`, not "boss defeated" | applied | Plane-select trigger is now the Lobby commit. |
| Tally 2b | Store `critical_breaks` and `len(max_chain_per_boss)` per slot at `stage_started` | applied | Rule 9. |
| Menus 2 | Rule 7: drop-in pick auto-cancels after `dropin_pick_ticks` (900) | applied | |
| CB 7, Dir 6, Tally 2c | New events | applied | One block, "Signals added 2026-11-03", under Rule 13. It lists the CB signature that replaces the prototype's, `critical_break_missed` and `_expired`, the Director's wave/warning/scroll/cue/era events plus `stage_started(stage_index, era)` and `stage_cleared(stage_index)`, the seven `tally_*` signals, and notes that Menus and HUD add no bus signals. |
| CB 7 | CB does not write counters (Scoring does); Hard → Soft | applied | Interactions and Dependencies rows. |
| Dir 6, Tally 2d, HUD 7, Menus 2 | Interactions and Dependencies rows link the GDDs and state their interfaces | applied | |
| Menus 2 | UI Requirements: Results and Pause → Menus; Tally → 21; continue prompt and pick plate → HUD | applied | |
| HUD 7 | Open Question 1 closed (MAX icon, HUD Rule 22) | applied | |
| — | AC-31 "all 12 listed signals" | adapted | Now "every signal listed in Rule 13", because the list keeps growing. |
| Dir 12 (via Group B) | `debug_tainted` added to the RunRecord | adapted | Save now refers to it, but the RunRecord had no such field. |

### `design/registry/entities.yaml`

| Source | Item | Status | Notes |
|---|---|---|---|
| CB | `cb_charge_min_ticks`, `cb_charge_lenience`, `cb_hit_window`; formulas `cb_armed`, `cb_winner` | applied | |
| CB | `cb_banner_wait_max` (120) | skipped | Superseded by HUD's `banner_wait_max` 180, since HUD owns banners. The registry entry notes this. |
| Dir | `warning_ticks`, `boss_started_offset`, `sweep_min_ticks`, `early_clear_gap`, `chain_gap_budget`, `wave_curve_cap`, `carrier_plan`, `stage_par_window`; formulas `wave_timeline`, `stage_par_ticks`, `group_size` | applied | Added `hud` to `warning_ticks` and `stage-end-tally` to `sweep_min_ticks`. |
| Tally | `tally_row_gap`, `tally_countup_ticks`, `tally_skip_lockout`, `tally_settle_hold`; formulas `tally_schedule`, `tally_countup` | applied | |
| Tally 14 | `stage_end_bonuses` text: "peak 1000" → "peak 1300 per point (= peak_value)" | applied | Text fix only; the locked value `peak_value` 1300 is unchanged. |
| Menus | 8 constants (`start_delay_ticks` … `name_entry_seconds`); formulas `lobby_ready_gate`, `name_wheel_step`, `hold_confirm_progress`, `plane_card_width` | applied | |
| Menus | `window_to_canvas` referenced_by: `menus` → `menus-title-plane-select` | applied | |
| HUD | `hud_chain_bar_px`, `hud_boss_bar_px`, `hud_digit_tiers`, `score_roll_instant_max`, `banner_wait_max`; formulas `score_roll`, `boss_bar_px` | applied | |
| all | `referenced_by` merges into existing entries (CB 8, Dir 8, Tally 8, HUD 16, Menus 15) | applied | Every name was found; no duplicates. |
| — | Structure check (script) | pass | Top keys are `constants` (140) and `formulas` (52). No duplicate names. Every entry has `source` and `referenced_by`. New constants sit before `formulas:` and new formulas at the end, each under a "Wave 3a" comment header. |

### Follow-ups (main pass)

| File | Change | Status |
|---|---|---|
| `design/gdd/wave-and-stage-director.md` | Open Question 4 closed: the Director emits `stage_cleared`, and Session's table starts the Tally on it | applied |
| `design/gdd/menus-title-plane-select.md` | Flow diagram: game over skips the tally (Stage → Results) | adapted (spotted by Group C) |

## Group A

### `design/gdd/boss-and-boss-parts.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| CB 2 | Rule 23 `core_target_id()` (1000+0); CB at 6b calls `apply_critical_break` before `critical_break_finish`; tick step 6b; Interactions row no longer provisional | applied | |
| Dir 5 | Field clear at E5+60, WARNING at E5+90 (150 ticks), `start_intro` at E5+240, `boss_started` at E5+480; `stage_cleared = max(boss_gone, D+90)`, watchdog D+360; Wave director rows linked | applied | |
| Tally 8 | Open Question 4 closed (clear bonus kept on TIMEOUT; "Boss withdrew"); Tally row linked | applied | |
| HUD 4 | Part-kill and enrage cues are icons plus D10 numbers; keys `boss.part.<id>.down` and `boss.enraged` removed; V3 caption; HUD rows linked | applied | |
| — | Open Questions 2 and 3 closed from the CB and Director GDDs; "No GDD yet" rows linked | adapted | |

### `design/gdd/bombs.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| CB 3 | Rule 12: exact `cb_armed`; Rule 28 points to CB Rules 9–12; Open Question 7 closed | applied | |
| Tally 9 | Open Question 8 closed (no stage-end bomb bonus) | applied | |
| — | CB and HUD rows linked | adapted | |

### `design/gdd/plane-kits-lancer-leech.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| CB 4 | Open Question 8 closed; Rule 40 note (boss part ids, core 1000+0; HOLD_PLAIN shots, drones and the bomb are not charge) | applied | |
| HUD 5 | `kit_bar(slot) -> (num, den)`; drone lamp on the icon row | applied | num/den written out per kit. |
| Menus 8 | Plane-card keys `plane.<id>.*`; Menus Dependencies row | applied | |

### `design/gdd/chain-tracker.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| CB 5 | Rule 7: the multiply arrives before `boss_defeated` (6b); CB row resolved | applied | An edge case still said "step 8"; changed to 6b (adapted). |
| Dir 8 | Validator enforces G ≤ 45; Wave director row linked | applied | |
| HUD 6 | `BAR_PX` 94 / 82; digits shift inside the plate | applied | The AC default 96 was changed to 94 (adapted). |

### `design/gdd/scoring.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| CB 6 | `preview_cb_points(before)` and `preview_ldb_points(lives)`; Scoring writes `critical_breaks` and `life_bonus_total` | applied | |
| Tally 1 | S8 computed at `stage_cleared` as four pending lines; `pay_stage_end_line(slot, line)`; flush on `stage_started` or run end; new AC-26b | applied | |
| HUD 2 | MAX word → MAX icon tag; HUD link | applied | |

### `design/gdd/collision-damage-lives.md`, `bullet-manager.md`, `game-concept.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| CB 8 | Collision Open Question 5 closed; CB row | applied | The report's "Interactions row 270" is a Dependencies row; there is no CB Interactions row (adapted). |
| CB 9 | Bullet manager CB row: `request_cancel(screen, cause_slot, items=true)`, `enemy_bullet_count` | applied | |
| Dir 10 | Bullet manager Wave director rows: `clear_all()` at E5+60 and at `stage_cleared` | applied | |
| CB 13 | Game concept §14 question closed; §4 note on landing on the core | applied | |

## Group B

| File | Source | Amendment | Status | Notes |
|---|---|---|---|---|
| `coop-and-team-chain.md` | CB 10 | Open Question 10: MVP breaker only, rank order | applied | Stays open for the Target tier. |
| same | Dir 7 | Wave director rows; `coop_spawn_cap` is a `spawn_pct` limit | applied | AC-21 changed: cap 140 gives 1,540 bullets (adapted). |
| same | Tally 4, HUD 3, Menus 7 | Tally rows and stat reset; V1 tag in D12 inside plates; Open Question 9 (pause owner) closed | applied | |
| `localization.md` | CB 11, Tally 6, HUD 9, Menus 5 | CB popup has no text; `tally.*` keys; tiers D12 and D10; Open Question 7 closed; chip-label lint exception | applied | `plane.<id>.*` keys go in the existing `plane.csv`, not `ui_menu.csv` (adapted). |
| `enemy-and-ai.md` | Dir 2 | `strip_tags[]`, `max_life_ticks`, `spawn_failed`, `alive_count()`; Open Question 4 closed; F9b → curve caps | adapted | Added an `event_id` spawn param. Open Question 6 skipped: already closed in wave 2. |
| same | Tally 9 | Open Question 14 closed (no kill ratio) | applied | |
| `boss-power-budget.md` | Dir 3 | Rule 22(d) per mechanic; Open Question 1 closed; SMALL-carrier note | adapted | Combination spawns over wave ticks 900–1,060, matching the Director's tables. |
| `powerups-and-drops.md` | Dir 4 | Open Question 3 closed (`sweep_min_ticks` 90); Wave director rows | applied | |
| same | Tally 10 | `stage_cleared` = `boss_gone` + 30 | adapted | The Director's rule wins. |
| same | HUD 8 | 1-up banner → `+gained` tag on the lives display | applied | |
| `bullet-pattern-library.md` | Dir 9 | F9 scope note (V-D5) | applied | |
| `save-settings-high-scores.md` | Dir 12 | `debug_tainted` runs are never ranked | adapted | Tainted runs also update no records. |
| same | Tally 3 | `boss_index` = `stage_index` in MVP; Tally rows linked | applied | |
| same | Menus 4 | New display keys, `profile.last_plane`, `access.confirm_style`, language-chip trigger, 18/6 repeat; Open Questions 4, 7 and 9 closed | applied | `window_size` default is "unset" (adapted). |
| `input-and-player-mapping.md` | Menus 3, Tally 5, HUD 10 | START GAME join binds slot 0; `bind_device`, `typed_char`; Open Question 4 closed; Tally row; HUD glyph interface | applied | |
| `display-scaler-and-bezel.md` | HUD 11, Menus 6 | HUD scale changes `play_top`; Display settings defined by Menus Rules 43–45 | applied | |

## Group C

| File | Source | Amendment | Status | Notes |
|---|---|---|---|---|
| `design/art/art-bible.md` | CB 12, Dir 11, Tally 7, HUD 12, Menus 9 | Dated notes in §4.1, §6.8, §7.2, §7.3, §7.4, §7.5, §7.8 | adapted | Additive notes only. Where a report said "replace", the note says the GDD supersedes the text. `#FFE27A` and the lower-third pause exception are pending an art-director ruling. |
| `docs/architecture/adr-0001-gdscript-bullets-multimesh.md` | CB, HUD, Menus 10 | CB tick placement; HudModel ticks after gameplay; pending ADRs for menu host / `start_run` handshake and for the single-frame CB flash | adapted | The ADR's step 6b is already `EnemyManager.apply_results()`. The note places CB after it and before 6c. |
| `critical-break.md` | HUD owns banners | Wait is 180; `cb_banner_wait_max` retired | adapted | The F5 formula text still names the old constant. |
| same | links | HUD and Tally rows linked; CB visuals are a request to the HUD | applied | Open Question 6 (no bullets after defeat) left open. |
| `wave-and-stage-director.md` | links | Last stage → tally → Results; S8 is paid by the tally; HUD uses `warning_started` and the wave events | applied | |
| `stage-end-tally.md` | Director timing | `stage_cleared` per the Director; Open Question 6 timing part closed | adapted | |
| same | HUD layout | Rule 24: the HUD strip stays (Tally mode) instead of hiding | adapted | |
| `menus-title-plane-select.md` | links | Tally and HUD linked; Rule 1 note | applied | |
| `hud.md` | CB, Director | Armed = `cb_state` ∈ {ARMED, COMMITTED}; banner from `critical_break_landed`; Warning from `warning_started`; Open Question 11 closed | adapted | |

## Programmer tasks (code not touched)

- `src/autoload/game_events.gd`: add the Rule 13 signal set, including the 2026-11-03 blocks, and change `critical_break_landed` to `(slot, before, after, raw, core_pos, breaks_on_run)`.
- `src/autoload/game_session.gd`: add `start_run(selections)`, `abandon_run()`, stage-start marks, `debug_tainted`, Tally-before-Results on the last stage, and the drop-in auto-cancel at 900 ticks.
- `src/gameplay/boss/boss_part.gd` / `src/gameplay/player/laser_ability.gd`: move Critical Break out into a node-free `CriticalBreakCore` at tick step 6b. Remove "core can only be finished by a Critical Break".
- `src/ui/hud/hud.gd`: replace with `HudModel` + `HudView` (no flash, no result panel, no English text, no polling).
- `src/gameplay/chain/chain_tracker.gd`: `BAR_PX` 94 / 82 if it is hard-coded.
- New code: Wave director / `StageValidator`, `StageTally`, menu models, `Scoring.pay_stage_end_line`, `preview_cb_points` and `preview_ldb_points`.

## New inconsistencies (not fixed)

1. **Tick step 6b is claimed twice.** It is both ADR-0001's `EnemyManager.apply_results()` and `CriticalBreakCore.tick()`. Chain applies hits at step 8, so whether the CB multiply sees this tick's hits is undefined. The core tick-order ADR must settle both.
2. **CB vs HUD armed visuals.** CB asks for a core ring with a 420-tick arc in the play field and a Gold outline on the bomb icon. The HUD defines corner ticks only and says "no number in the play field". CB lists HUD as Hard; HUD lists CB as Soft.
3. **Bullet-count name.** The HUD uses `enemy_bullets_alive`; Bullet manager and CB use `enemy_bullet_count`.
4. **Tally 1P layout.** The HUD strip now stays visible during the tally, but the Tally's 1P worst case needs 632 of 640 px, leaving about 592 px usable.
5. **Drop-in pick plate.** Menus wants an 84x44 plate with a cursor; the HUD draws only a join plate, and none in 2P.
6. **HUD scale vs `play_top`.** HUD scale changes `play_top`, which the registry locks at 48 / 72 (HUD Open Question 9).
7. **Director `spawn()` params.** The Director's Rule 6 params need the `event_id` that Enemy added. No one supplies `is_last_stage` or the next era to the Tally.
8. **Stale "no GDD" lines** remain in bullet-manager.md line ~359, boss-and-boss-parts.md line ~181 and the plane-kits Input row. Powerups and Input still call the Audio and VFX interfaces provisional (for wave 3b). Other docs may still use the old display keys `display.integer_scale` and `display.bezel` (Accessibility, for wave 3b).
