# Applied amendments — wave 4 (2026-11-03, final)

Applier pass over four reports in `production/gdd-reports/`: `plane-kits-sentry-breaker.md` (SB), `tutorial.md` (Tut; full list in `design/gdd/tutorial.md` Dependencies "Amendments to other docs" 1–15), `touch-controls.md` (Tch; full list in `design/gdd/touch-controls.md` 1–14), `online-leaderboards-boss-rush.md` (OL), plus six wave-3b leftover decisions (D1–D6). Status words: **applied**, **adapted** (with a reason), **skipped** (with a reason). Every edit used scripted exact-string replacement with `assert count == 1`. Split: main pass (systems index, registry, Save, Session, ADR-0001), Group A (gameplay GDDs), Group B (UI/data GDDs), Group C (presentation, art bible, game concept, the four new GDDs). Code/project files: not touched.

## Resolution rules used

| Rule | Outcome |
|---|---|
| Owners win | Sentry/Breaker kits own their numbers; `ref_dps` stays 800 (MVP kits). Tutorial owns drills/hints; Touch owns the touch scheme/strip; Leaderboards owns online + boss rush; Save stores keys; Session owns run fields. |
| D1 | `access.chain_cue_audio` default **true** (Accessibility, Save schema, Audio). |
| D2 | Era-transition card effects may draw on layer 11 (no enemy bullets exist during the transition); exception sits next to the CB-flash exception (VFX Rule 1, AC-01; Era shift Rule 21). |
| D3 | `play_top` latched at `stage_started` and `wave_started`; HUD layout follows the latched value; a mid-wave/mid-boss drop-in or N change waits for the next latch (boss: next stage). Gameplay never reads the HUD display mode. In 48 px mode a new/Selecting slot uses the compact 2P column form. Boss OQ5 closed. |
| D4 | ≤ 8 lit flak fuses per scene: Pattern library validator (per owner, F8) + Director cross-owner check (V-D5); runtime skips a volley that would light a 9th (counts as fired, draws RNG). VFX now references it. Registry `flak_fuse_max`. |
| D5 | Stale "no GDD"/"provisional"/"not yet" rows for systems with GDDs fixed (OL GDD, Save, Session and all group files). |
| D6 | Audio OQ11 closed: TATE confirm uses the standard UI countdown tick (`sfx_ui_nav_tick`) + confirm/cancel sounds. |

## Main pass

### `design/gdd/systems-index.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 1 | Row 29: depends `3, 6, 11, 12`; Designed, GDD link | applied | |
| Tut 15 | Row 30: depends `16; soft 1, 2, 6, 7, 9, 10, 11, 12, 13, 14, 15, 17, 18, 20, 22, 26, 27`; Designed | applied | |
| Tch 1 | Row 31: depends `2, 4, 5`; Designed (note: `/ux-design` pass still runs) | applied | |
| OL 10 | Row 32: depends `26, 1, 2, 8, 14, 16, 22, 28`; Designed — Stretch | applied | |
| OL 10 | Save-listing reminder marked satisfied | applied | |
| SB 1, all | Dependency notes | applied | New "Wave 4" bullet (tags 2/3, `cancel_report`, run_kind, touch slot 0, RUSH/BOSS ids, `play_top` latch). "Leaf nodes" now says none left. SB's "17, 19, 20, 24, 25, 28 should list 29" recorded there. |
| Tch 1 | Open items: "Touch controls UX spec" removed | applied | Recorded as closed in the parenthesis. |
| rules | "GDDs written" recount | applied | **32** (34 files − game-concept − systems-index; none contains "[To be designed]"). All 32 systems Designed (pending review). |

### `design/registry/entities.yaml`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB §4 | 6 constants (`net_erase_budget`, `breaker_stock`, `net_safe_clear`, `bastion_bomb`, `backlash_bomb`, `kit_player_bullet_tags`) | applied | New block "Wave 4" before `formulas:`. |
| Tut §4 | 4 constants + 2 formulas (`hint_count_pack`, `chain_drop_streak`) | applied | |
| Tch | 4 constants + 4 formulas (`touch_drag_delta`, `touch_leash_step`, `touch_strip_px`, `min_touch_target_canvas_px`) | applied | |
| OL §4 | 6 constants (incl. `slot_stage_bound` owned by Scoring) + 2 formulas | applied | |
| SB §4 | `drone_ability_cycle` value text adds Sentry 420/480 and Breaker 300/600 | applied | Descriptive string owned by kits; Lancer/Leech numbers unchanged. |
| SB §4 | `drone_phase` note (Sentry (d×7) div 4, Breaker (d×6) div 4) | applied | Added as `note:`; expression unchanged. |
| D3 | `play_top` note: latched at `stage_started`/`wave_started` | applied | Value unchanged (locked). |
| Tch | `board_id` note: `/touch` solo boards; RUSH/BOSS ids | applied | Expression/output unchanged. |
| all | `referenced_by` merges (SB 26 entries, Tut 17, Tch 9, OL 14) | applied | Script merge, no duplicates. |
| rules | Structure check | applied | Script verified: top keys `constants`, `formulas` only; 189 constants / 72 formulas; no duplicate names; every entry has `source` and `referenced_by`; CRLF kept. (PyYAML not installed; regex validator used.) |

### `design/gdd/save-settings-high-scores.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| OL 1 | Rule 4: reject `assisted`/`debug_tainted` records from ranking and upload | applied | Cross-refs Rule 32. |
| OL 1, Tch 5 | Rule 9 + F3: `/touch` suffix (solo only), RUSH `rush{n}/solo|coop/...`, BOSS `boss/{boss_id}/{plane}`; online `r{ruleset}/` prefix | applied | MAIN ids unchanged. |
| OL 1 | Entry optional `online_status`, `replay_ref` | applied | |
| OL 1 | Rule 13 records `endings_count`, `bosses_beaten` | applied | |
| OL 1 | `RunRecord`: `mode`, `boss_ids[]`, `run_seed`, `run_ticks`, `assisted`, `debug_tainted` | adapted | Also added `touch` (bool) so Save can pick the `/touch` board — nothing else carried that fact. `debug_tainted` already existed in Session. |
| Tut 4, Tch 5, OL 1 | Rule 16 schema: 5 `tutorial.*`, 8 `touch.*`, 6 `online.*` keys | applied | Types/defaults from the owner GDDs (`touch.sens` stored as index 0–3). |
| D1 | `access.chain_cue_audio` default **true** | applied | |
| Tut 4 | Rule 20 trigger "Flight School drill complete" | applied | |
| Tut 4 | Rule 30 `reset_settings()` keeps `tutorial.*` | applied | |
| D5, OL, Tut, Tch | Interactions header no longer says "(32) provisional"; rows for 30, 31, 32 | applied | |
| D5 | Dependencies: Online (32) "no GDD" → GDD link; Tutorial, Touch rows added | applied | |
| OL 1 | OQ3 closed (sparse log, online queue only); OQ11 closed; OQ12 stays | applied | Amendment 7 ("to be written" GDDs must list Save) closed. |

### `design/gdd/game-events-and-session.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tut 1 | Rule 1: `run_kind` (`RUN`/`DRILL`), `start_school(selections)`, no rank/Results/Tally/continue in drills, `run_ended_by = DRILL_END` | applied | |
| OL 2 | Run `mode` (MAIN/RUSH/BOSS), stage list (`stage_count` = length), `start_run(selections, mode, stage_list)` | applied | Signature extension is a proposal for the programmer (task list). |
| OL 2 | `ReplayRecorder.tick(inputs_by_slot)` after Input when `online.enabled`; `run_ticks` non-paused | applied | |
| OL 2, Tch | Run record rows `mode`, `boss_ids[]`, `run_seed`, `run_ticks`, `assisted`, `touch` | applied | |
| Tut 1, OL | Interactions rows 30, 31, 32; Dependencies rows 30, 32 | applied | |
| Tut 1 | UI Requirements: Flight School owned by Tutorial (30) through Menus (22) | applied | |

### `docs/architecture/adr-0001-gdscript-bullets-multimesh.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tch 12, OL 12, SB 2, D3, Tut | Additive dated note (wave 4): TouchMapper in step 1, touch-to-mouse emulation off (→ ADR), `ReplayRecorder` after step 1, `cancel_report` next tick + perf scenario, `play_top` latch, `DrillRunner` | applied | No decision text changed. |
| Tch 12 | `docs/project-structure.md`: `src/input/touch/`, `data/input/touch_rules.tres` | skipped | Project file; listed as a programmer task. |

- Also: registry `flak_fuse_max` = 8 (D4, owner Pattern library) added after the Group B report; OL GDD Visual row "BOSS n/N" layer 7 → HUD layer 11 inside the strip (Group B finding).

## Group A

### Group A (gameplay GDDs)

Sources: SB n = `plane-kits-sentry-breaker.md` report §3 item n; Tut n = Tutorial GDD "Amendments to other docs" item n; Tch n = Touch GDD amendments item n; OL n = Online leaderboards report §3 item n; D1–D6 = the six wave-3b leftover decisions. All edits are scripted exact-string replacements with `assert count == 1`.

### `design/gdd/bullet-manager.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 2 | Rule 2 `tag` adds 2 = charge shot/slug, 3 = return bolt (bolt speed 18 px/tick) | applied | |
| SB 2 | Rule 13: kit circle cancels with `items = false` (≤ 2 per slot per tick) carrying a `request_id`; `cancel_report(slot, request_id, count)` at the start of the next tick | applied | Named as a kit-facing report next to the existing VFX `cancel_report`; both describe the same per-tick data. |
| SB 2 | Rule 14: net cancels are outside `items_per_cancel_cap` | applied | |
| SB 2 | Dependencies: new Sentry/Breaker (29) row (tags, net cancels, Sentry 46 / Breaker 40 live bullets) | applied | Added as a separate row. The Plane kits (11) row was left as it is. |
| SB 2 | AC-40: Target scenario of 1,350 bullets + 12 cancel areas per tick, ≤ 2.5 ms p99 | applied | |
| D3 | `play_top` variable row and Visual "HUD strip" bullet: latched at `stage_started` / `wave_started`; never the HUD display mode | applied | |

### `design/gdd/collision-damage-lives.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 3 | Rule 10: hit results carry `tag` 0–3 | applied | |
| SB 3 | Breaker net ram uses source DRONE; no new source | applied | Placed in the new Dependencies row for system 29. |
| Tut 5 | New Rule 15 **Drill mode**: `drill_hit(slot)`, `request_invuln(slot, respawn_invuln)`, chain drop with reason DEATH; no life loss, kill or clear | applied | |
| Tut 5 | Dependencies: Tutorial (30) row | applied | |
| D5 | Bidirectional-check note for wave 4 | applied | |

### `design/gdd/critical-break.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 4 | Rule 5 charge list adds Entrench (`ENTRENCH`) and Breach (`BREACH`); `charge_last_hit` = last counted tag 2/3 result | applied | |
| SB 4, Tut 14, D5 | Dependencies rows 29 and 30: "not yet" → GDD links (row 30 lists `critical_break_landed`) | applied | |

### `design/gdd/bombs.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 5 | New section G with Rules 35 (Bastion) and 36 (Backlash), linking Sentry/Breaker Rules 31–32 and SB7–SB8 | applied | Placed after Rule 34 (section F). |
| SB 5 | `effect_ticks` in the ACTIVE row: Bastion 72, Backlash 2–49 | applied | |
| SB 5, Tut 14 | Dependencies rows 29 and 30 → GDD links (row 30 lists `bomb_used`, `chain_reduced`) | applied | |
| SB 5 | Open Question 16 closed (`BombCore` hosts per-plane effect classes) | applied | Lead-programmer still has to confirm this at architecture. |

### `design/gdd/plane-kits-lancer-leech.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 6 | Tags 2 and 3 | adapted | Tags are defined in Rule 8 (the report says Rule 2), so the edit went into Rule 8. |
| SB 6 | Rule 40 `charge_kind` adds `ENTRENCH`, `BREACH` | applied | |
| SB 6 | K8 note: Sentry 804.0 / Breaker 777.2; `ref_dps` stays 800 | applied | Added to the "Hp reference" constraint bullet. |
| SB 6 | Open Question 15 closed (shared `DroneBank`); Open Question 5 note (early recall: Sentry only, after 60 ticks) | applied | |
| Tch 9 | Rule 5: touch auto-fire relies on the 12-tick linger; Interactions: kit publishes `drone_state` for the touch button (provisional) | applied | The `drone_state` note is in the new Touch (31) downstream row. |
| Tut 14, D5 | Downstream rows 29, 30, 31 with GDD links; bidirectional note | applied | |

### `design/gdd/player-plane.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 7 | V6: Sentry turret 12x12 and Breaker eraser 16x10 | applied | |
| SB 7 | PF4 offsets for the 45x42 and 42x45 boxes | adapted | Offsets are computed with PF4: Sentry (∓31, +4), (∓45, +10) with `s` 12; Breaker (∓31, +4), (∓49, +10) with `s` 16. Marked "confirm in the kit data". |
| SB 7 | `ability_speed` Sentry 75 (Rule 4.1) | applied | |
| Tch 3 | Rule 2 DRAG note; Rule 4.2 `fire_auto` is not a hold; Rule 9 reads `drag` / `drag_active`; Rule 10 clears `pending` | applied | |
| Tch 3 | New **PF8 Touch leash** (TF4) | applied | Placed after PF7, before the formulas sign-off. |
| Tch 3 | ACs for PF8 | applied | New AC-38 (PF8), AC-39 (`fire_auto`) and AC-40 (latch), which reference Touch AC-21 to AC-27. |
| Tch 3 | Open Question 6 closed | applied | |
| D3 | Rule 5 and the three `play_top` edge cases: latched at `stage_started` / `wave_started` (mid-boss: next stage); gameplay never reads the HUD display mode | applied | |
| D5 | Dependencies rows: Touch (31) upstream; Sentry/Breaker (29) and Tutorial (30) downstream | applied | |

### `design/gdd/coop-and-team-chain.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| D3 | Rule 1: `N` is live and `play_top` is latched, so the two may differ. Rule 2: latch at `stage_started` / `wave_started` (mid-boss: next stage); the HUD layout follows the latched `play_top`; gameplay never reads the HUD display mode | applied | |
| D3 | Edge cases for N 2→3 mid-boss and 3→2; AC-02; AC-39 | applied | Shot opacity still follows `N` at once. Only `play_top` and the layout are latched. |
| D3 | Open Question 6 closed (delay to the latch) | applied | |
| SB 8 | Rule 9: Bastion dome and Breaker net are shared field effects. Rule 11: Sentry 46 / Breaker 40 | applied | |
| Tut 14, D5 | Downstream rows 29 and 30 | applied | |

### `design/gdd/boss-and-boss-parts.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| OL 4 | Rule 11: the `start_intro` stage argument is the home stage | applied | |
| OL 4 | `boss_defeated` with KILLED or CRITICAL_BREAK feeds `bosses_beaten` | applied | New Rule 41. |
| Tut 7 | `TrainingBossDef` (`drill_hp_pct` 25 after `coop_hp_scale`, preview-row fire only, `start_state = CRITICAL`, `cb_only`); stage lint forbids it | applied | New Rule 40. |
| Tut 7 | `boss_enraged` documented as read by Tutorial | applied | Added to the events line. |
| D3 | Edge case "play_top changes during the fight" rewritten (no mid-fight shift); decision note marked superseded; AC-46 extended | applied | |
| D3 | Open Question 5 closed | applied | |
| Tut 7, OL 4 | Downstream rows Tutorial (30) and Online/Boss rush (32) | applied | |

### `design/gdd/enemy-and-ai.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tut 6 | Rule 8 spawn params `hp_override`, `dummy`, `drop_override` (drills only; stage lint rejects them) | applied | |
| Tut 6 | Dependencies: Tutorial (30) row; bidirectional note | applied | |

### `design/gdd/powerups-and-drops.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tut 9 | New Rule 7a `drop_override` (bypasses the drop table and pity; drills only) | applied | |
| Tut 9 | Tutorial (30) row → GDD link | applied | |

### `design/gdd/chain-tracker.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tut 14 | Downstream Tutorial (30) row (`chain_dropped` EXPIRED, `chain_reduced`, `team_chain_started` / `ended`) | applied | Chain tracker had no row for 30 before. One was added. |


## Group B

## Group B

Scripts: `gB_*.py`, `hud.py`, `menus.py`, `tally.py`, `dir.py` in the scratchpad. Each uses exact-string replacement with `assert count == 1`, and every run printed `ok`.

### `design/gdd/hud.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| D3 | Rule 6: strip height and layout mode follow the `play_top` latched at `stage_started` / `wave_started` | applied | Between latches, only 1P ↔ 2P changes apply (same 48 px strip). A height change waits for the next latch, or the next stage during a boss. Also states "Gameplay never reads the HUD display mode". |
| D3 | Rule 23 Selecting-slot display must fit the latched strip | applied | 48 px mode uses the compact 2P column form for the new slot; 72 px mode uses its fixed 3-4P column. The strip never changes height for a pick. |
| D3 | HF7 note, Edge Cases (join or drop mid-boss / mid-wave), AC-06, Interactions row Player plane | applied | Old "strip becomes 72 px on that tick" edge case replaced. |
| SB 12 | Sentry ability bar + recall glyph; Breaker stock bar + drone lamp | applied | Rule 19 and Rule 20 additions; layout-table drone-lamp row; Interactions and Dependencies rows link the 29 GDD. |
| Tut 3 | `strip_mark`, element ids, drill bar, DONE/SKIPPED stamp | applied | New Rules 30a and 30b. |
| Tut 3 | OQ5, OQ7 closed; Dependencies row Tutorial → GDD | applied | |
| Tch 7 | Dependencies row Touch: Pause button is in the touch strip, no HUD tile; OQ13 closed | applied | Interactions row added too. |
| OL 9 | "BOSS n/N" element in RUSH | adapted | New Rule 30c. It draws in the boss row's left zone outside the fight, on layer 11. The OL V-table says "layer 7"; the HUD draws on layer 11, so the OL GDD needs a fix (Group A or main pass). |

### `design/gdd/menus-title-plane-select.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tut 2a | FLIGHT SCHOOL Title item + NEW tag | applied | Rule 7. |
| OL 5 | Play choice: MAIN / BOSS RUSH / SINGLE BOSS | adapted | Rule 7. Shown only once a mode is unlocked, so a fresh profile still reaches the Lobby in 2 presses. |
| Tch 6 | Rule 9: a START GAME tap binds TOUCH to slot 0; `touch_solo` | applied | The pointer rule still applies on PC and Web desktop. |
| SB 10 | Sentry/Breaker `available = true` at Target; `plane.sentry.*`, `plane.breaker.*` | applied | Note on Rule 15's plane-key paragraph. |
| Tut 2d, 2e | Drill Pause items (Resume, Restart drill, Settings, Skip drill HOLD, Quit to list); Pause tip row | applied | Rule 28. The MVP "no Restart" rule is kept for normal runs. |
| Tut 2b, 2c, 2e, 2f | Lobby SCHOOL mode, school screens, Results offer line, Dependencies | applied | Added as Interactions and Dependencies rows that point to tutorial.md. Not written out as separate Menus rules. |
| OL 5 | Online tab (replaces the reserved slot); Consent / Handle / Delete screens; Rush / Boss tabs | applied | Rule 39 note plus Interactions and Dependencies rows. |
| Tch 6 | Replace "24 px targets" with TF7 (9 mm; 55 px at x3 / 458 dpi); landscape prompt; Touch section; first-run hints | applied | Interactions and Dependencies rows. |
| Tch 6 | OQ11 | applied (partly closed) | Swipe lists and the Android back gesture stay open. |
| Tut 2f | "Open Question 6" | adapted | Menus OQ6 is the Web gamepad gesture question and has nothing to do with Tutorial, so only Dependencies was updated. |

### `design/gdd/stage-end-tally.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tut 11 | Footer tip row, absent when no hint is pending | applied | New Rule 1a and a UI Requirements row. |
| OL 9 | Per-boss tally in RUSH, same skip rule | applied | Rule 1a. |
| D5 | Player plane row "provisional" → GDD link; rows for 30 and 32 added | applied | Both Interactions and Downstream tables. |

### `design/gdd/wave-and-stage-director.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| OL 3 | Boss-only stage `waves = []` + `home_stage`; `start_intro(boss_id, home_stage)` | applied | Rule 1 exception; V-D1 updated. |
| OL 3 | Dependencies row 32 | applied | Interactions and Dependencies tables. |
| Tut 10 | Tutorial row: `stage_started`, `mechanic_previewed`, `lead_in_ticks`, no calls into the Director; link | applied | "Provisional" note replaced. |
| D4 | V-D5 also checks co-active lit flak fuses ≤ 8 | applied | Cross-owner half of the fuse-cap validator. |
| D5 | `run.debug_tainted` "provisional name" → `RunRecord` field | applied | |

### `design/gdd/localization.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tut 13 | `ui_tutorial.csv` (`tut.*`) + glyph-token argument convention | applied | Rule 5. Tokens look like `{g_fire}`, filled through Input `action_glyph`, and are checked by the placeholder lint. |
| Tch 13 | `touch.*` and `opt.touch_*` keys | applied | New file `ui_touch.csv` (file name chosen here). |
| OL 9 | `ui_online.*`, `ui_rush.*` | applied | Files `ui_online.csv` and `ui_rush.csv`. |
| SB 10 | `plane.sentry.*`, `plane.breaker.*` | applied | |
| Tut 13, D5 | Interactions and Dependencies rows for 29, 30, 31, 32 | applied | |

### `design/gdd/input-and-player-mapping.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tch 2 | Rule 2 TOUCH line (GDD, slot 0, solo, `touch_solo`); touch-to-mouse emulation note (→ ADR) | applied | |
| Tch 2 | Rule 13 `SlotInput`: `drag`, `drag_active`, `fire_auto` | applied | |
| Tch 2 | Rule 3: a START GAME tap binds TOUCH to slot 0 | applied | Added at the end of Rule 3. F7 left unchanged (it is the slot formula and TOUCH is always slot 0). |
| Tch 2 | Interactions/Dependencies rows 31 → GDD; OQ7 closed; OQ10 note on touch haptics (Rule 32) | applied | |
| OL 8 | `sim_input_byte(slot)` (4 bits move + 3 bits buttons) | applied | New Rule 13a. OQ8 gets a note that 32 records it. |
| Tut 14 | Tutorial (30) row | applied | No Tutorial row existed, so one was added to both tables. |

### `design/gdd/display-scaler-and-bezel.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tch 4 | Rule 4: effective area = safe rect minus `touch_strip_px`; `get_layout()` adds `touch_strip_rect` | applied | |
| Tch 4 | Rule 19 / W3 text: "nothing in W3 covers the canvas" | applied | Rule 19 also gets the touch forward/consume rule (Touch Rule 29). |
| Tch 4 | Interactions + Dependencies row Touch → GDD; OQ8 closed (points to Touch AC-02..05) | applied | No new AC rows were written here. |

### `design/gdd/accessibility-options.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| D1 | `access.chain_cue_audio` default **true** | applied | Rule 28 and the Tuning table (split into two rows). AC-41 unchanged (it is still valid). |
| Tch 8 | Interactions row Touch; `Touch: one hand` preset | applied | Rule 21 presets list. |
| Tut 12 | `tutorial.hints` in the Settings list; Dependencies → GDD | applied | Interactions row. |
| OL 6, Tut 12 | OQ9 closed (Single Boss + game speed; not part of school); assisted runs never upload | applied | Rule 26 and OQ9. |

### `design/gdd/boss-power-budget.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| SB 11 | Breaker-net authoring note (~120 bullets / 930 ticks) | applied | At the top of Edge Cases. |
| Tut 14 | Tutorial row "not yet" → GDD; `mechanic_previewed` | applied | Plus a Sentry/Breaker (29) Dependencies row. OQ7 (preview hint) left open: the Tutorial GDD does not answer it. |

### `design/gdd/bullet-pattern-library.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| D4 | ≤ 8 lit fuses per scene; validator per owner (F8 row) and per scene (Director V-D5); runtime skip of a 9th-fuse volley (counts as fired, draws RNG, no `volley_fired` / `flak_fuse`) | applied | Flak paragraph, F8 table, "Runtime does only these", VFX row (now a reference). New name `flak_fuse_max` (registry candidate). |
| SB 11 | Breaker-net authoring note | applied | At the top of Edge Cases. |

### `design/gdd/scoring.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| OL 7 | Name the bound `slot_stage_bound` = 31,000,000; a change needs a ruleset bump | applied | Edge Cases "Hard bound"; Downstream row 32 added. |


## Group C (presentation docs and the four new GDDs)

Script: `scratchpad/groupc.py`, exact-string replace with `assert count == 1`, all 40 edits passed.

### `design/gdd/audio.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| D1 | `sfx_chain_window_tick` row: `access.chain_cue_audio` **default true** | applied | Matches "chain window tick on by default" in the auto-approve line. Accessibility and Save defaults belong to other groups. |
| D6 | OQ11 closed: TATE confirm uses `sfx_ui_nav_tick` per countdown step, `sfx_ui_confirm` / `sfx_ui_cancel` for Keep / Cancel, and `sfx_ui_cancel` on auto-revert; no new ID | applied | Audio has no separate "countdown" sound, so the standard UI tick is `sfx_ui_nav_tick`. |
| Tch 14, Tut (Audio cue ids) | Upstream rows added: Tutorial (30) (cues `tut.drill_done` / `tut.coach_open` use placeholder UI sounds), Touch (31) (no sound; haptics owned by Touch Rule 32), Sentry/Breaker (29) + Online/Boss Rush (32) (sound IDs still to be assigned) | applied | Placeholders: `sfx_ui_new_best` / `sfx_ui_pause_in`. |

### `design/gdd/vfx-and-screen-feedback.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| D2 | Rule 1: era-card exception added next to the CB-flash / HUD list (time-dust and reveal burst on layer 11, because there are no bullets during the transition; still inside the 150 / 24 caps) | applied | Layer table row 11 and AC-01 updated to match. |
| D4 | Flak fuse edge case now refers to the Pattern library's cap of ≤ 8 lit per scene (validator plus runtime skip that counts as fired and draws RNG); the 9th-fuse draw stays as a guard only; TELL row notes "8 = Pattern library cap" | applied | |
| D4 | OQ6 closed | applied | |

### `design/gdd/era-shift-and-plane-evolution.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| D2 | Rule 21 and VFX Interactions row cite the VFX Rule 1 era-card exception | applied | Era shift keeps the effects as VFX instances. |

### `design/art/art-bible.md` (additive notes headed "Added 2026-11-03 (wave 4, …)")

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Tch 11 | §3.5 touch plates follow the chamfered grammar | applied | |
| SB 9 | §5.6 Breaker: four corner brackets replace "pulse arc"; SPENT look; Sentry base plate, facings, tick marks | applied (note) | The original row is unchanged (additive only). Pending art-director (SB OQ6). |
| SB 9, Tut 8 | §7.2 Sentry ability bar + recall glyph, Breaker stock bar with 25 % ticks; stage-1 primer rows on the stage card; strip-mark brackets; drill bar | applied | |
| Tch 11 | §7.6 touch glyphs (Hold, Fire, Drone, Bomb, Pause) | applied | |
| Tut 8 | §7.8 stopped-game exception extended to the Coach card | applied | |
| Tch 11 | §8.1.1 touch strip reserve; device results use the reduced height | applied | |
| SB 9 | §8.3 Sentry/Breaker sprite sets (turret, base plate, brackets, bolt, dome frames, wall bar) | applied | |

### `design/gdd/game-concept.md` (additive dated notes)

| Source | Amendment | Status | Notes |
|---|---|---|---|
| OL 11 | §12 Stretch detail note (online opt-in + replay-verified; boss rush + Single Boss) | applied (note) | The table row itself is unchanged. |
| Tch 10 | §13 touch-risk mitigation note | applied (note) | The table row itself is unchanged. |

### New GDDs

| File | Amendment | Status | Notes |
|---|---|---|---|
| `touch-controls.md` | Rule 33: the touch hints are Touch's (Tutorial does not replace them); Audio/VFX and Tutorial Interactions rows now say "GDD"; Dependencies rows Tutorial / Audio-VFX now say "Yes"; Amendments list marked applied | applied | Also listed in Tutorial and Audio, per Touch item 14. |
| `tutorial.md` | Touch (31) Interactions and Dependencies rows added; Downstream row for 32 now links the GDD (practice = Single Boss); Localization glyph-token "(provisional)" now points at Amendment 13; Amendments list marked applied | applied | |
| `plane-kits-sentry-breaker.md` | "Bullet manager report provisional until Amendment 2" now reads adopted; Downstream rows added for Tutorial 30, Touch 31 and Online/Boss Rush 32; Amendments list marked applied | applied | Rule 38 "Critical Break contract (provisional)" left as is (it is a contract term, not a stale GDD row). |
| `online-leaderboards-boss-rush.md` | D5: Era shift / HUD / Tally rows (Interactions and Dependencies) now say "GDD"; Tutorial row rewritten (own training boss, not Single Boss); Touch (31) row added (`/touch` boards via F5); Amendments list marked applied | applied | |


## Programmer tasks (code not touched)

- Bullet manager: tags 2/3, kit circle cancels with `items = false` (≤ 2 per slot per tick), merge the VFX-facing and kit-facing `cancel_report` into one struct carrying `request_id`; perf scenario 1,350 bullets + 12 cancel areas ≤ 2.5 ms p99.
- `play_top` latch at `stage_started`/`wave_started` (GameLoop/Director/Player plane); HUD reads the latched value.
- Pattern library runtime fuse cap (skip 9th, count as fired, draw RNG) + validator F8 / Director V-D5.
- Session `run_kind`/`start_school`, `mode` + stage list, `ReplayRecorder.tick` after Input; Input `sim_input_byte(slot)`, `SlotInput.drag`/`drag_active`/`fire_auto`.
- `docs/project-structure.md`: add `src/input/touch/` (`TouchMapper`, `TouchLayout`, presenter) and `data/input/touch_rules.tres`; `data/tutorial/tutorial_rules.tres`.
- Carry-overs from wave 3b: remove `screen_flash_requested` emits and `PopupLayer`; renumber GameLoop step 6 sub-order.

## ADRs needed

1. Deterministic replay recording and cross-platform verification (determinism spike, OL AC-14).
2. Online transport/adapters + Steam GDExtension exception to GDScript-only.
3. Hosting and data region (with `/security-audit` legal items).
4. Touch-to-mouse emulation off during gameplay (Godot project setting).
5. Carry-over: game-speed scheduler; blocking-load tick discard.

## Remaining inconsistencies (for the user / next pass)

1. **PF4 wing-slot offsets** for Sentry (∓31/∓45) and Breaker (∓31/∓49) were derived by the applier; confirm in the SB GDD/kit data.
2. **Compact 2P column form** (D3, 48 px strip with a 3rd/Selecting slot) has no exact rects — HUD layout spike / `/ux-design`.
3. **Art bible §5.6** still has the original Breaker "pulse arc" row; a superseding dated note says corner brackets. Art-director to confirm (SB OQ6).
4. **Audio IDs** missing for Tutorial cues (`tut.drill_done`, `tut.coach_open`), Sentry/Breaker and Online/Rush sounds.
5. **Touch Interactions** still mark `drone_state` (kit) and the Bombs "accepted" event name provisional.
6. **String-key prefix:** touch strings (`touch.hint.*`) share `touch.` with Save setting keys; Group B chose `ui_touch.csv` — rename strings to `ui_touch.*` before string freeze.
7. **Menus** Boss Rush / Single Boss Play entries and touch row pitch are prose only (screen table/wireframes pending `/ux-design`).
8. **Session `start_run(selections, mode, stage_list)`** signature extension and the `RunRecord.touch` flag were added by the applier (no source named them); confirm with lead-programmer.
9. Display scaler duplicate "Matched" key note (cosmetic, from wave 3b) untouched.
