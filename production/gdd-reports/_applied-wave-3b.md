# Applied amendments — wave 3b (2026-11-03)

Applier pass over five reports in `production/gdd-reports/`: `audio.md` (Aud), `vfx-and-screen-feedback.md` (VFX), `era-shift-and-plane-evolution.md` (Era; full list in the GDD's Dependencies "Amendments to other docs" 1–17), `parallax-and-environment.md` (Par), `accessibility-options.md` (Acc), plus the seven wave-3a inconsistency decisions (I1–I7). Status words: **applied**, **adapted** (with a reason), **skipped** (with a reason). Every edit used scripted exact-string replacement with `assert count == 1`. Split: main pass (systems index, Save, Session, registry, ADR-0001), Group A (boss, player plane, scoring, powerups, critical break, bullet manager, collision, plane kits, bombs, chain, enemy, technical preferences), Group B (HUD, tally, menus, director, localization, input, co-op, display scaler, boss power budget, pattern library, game concept), Group C (the five new GDDs and the art bible). Not touched (being written): `plane-kits-sentry-breaker.md`, `tutorial.md`, `touch-controls.md`, `online-leaderboards-boss-rush.md`. Code/project files: not touched.

## Resolution rules used

| Rule | Outcome |
|---|---|
| Owners win | Audio owns buses/voices/music (UI bus follows `audio.sfx`); VFX owns the 150-instance pool, screen policy (no global shake; CB frame is the only flash) and the CB core ring tell; Era shift owns `EraDef`, ladders, strip map and transition; Parallax owns L0–L4, `S`/`ScrollClock`, plates and the boss vignette (VFX `fx_boss_vignette` removed); Accessibility owns the `access.*` registry; Save stores. |
| I1 tick order | 6 CollisionReferee → 6a EnemyManager.apply_results → 6b CriticalBreakCore.tick → 6c Boss.apply_results. CB multiply uses the chain count at the start of the tick; this tick's hits reach Chain at step 8. |
| I2 CB ring | World-space tell owned by VFX (T0, layer 5, below enemy bullets). HUD draws the gold bomb-icon outline + corner ticks when `cb_state` is ARMED/COMMITTED. CB→HUD is Soft. |
| I3 | `enemy_bullet_count` (Bullet manager) everywhere. |
| I4 | HUD strip hidden while the tally panel is up; shows again at next `stage_started`. |
| I5 | Selecting slot → HUD uses the next layout mode for display only; 84x44 pick plate in that column. No HUD scale (Accessibility Rule 20). |
| I6 | Director `spawn()` params include `event_id`; Director supplies `is_last_stage` and `next_era` (`era_for_stage`) to the Tally at `stage_cleared`. |
| I7 | Stale "no GDD"/"provisional" rows for systems 2, 4, 10–28 now link their GDDs. |

## Main pass

### `design/gdd/systems-index.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 17 | Row 19: depends `1, 3, 9, 10, 11, 12, 15, 16, 21`; Designed, GDD link | applied | |
| Par 1 | Row 23: depends `1, 4, 16 (soft: 17, 19, 21, 25, 28)`; Designed | applied | |
| Aud 1 | Row 24: depends `1; listens to 2, 3, 5–18, 26 (soft)`; Designed | applied | |
| VFX 1 | Row 25: depends `1, 3, 5, 6, 9, 10, 11, 12, 13, 14, 17, 18 (soft: 4, 23, 26)`; Designed | applied | |
| Acc 1 | Row 28: depends `1 (soft), 2, 4, 20, 21, 22, 24, 25, 26, 27`; Designed | applied | |
| all | Dependency notes | applied | New "Wave 3b" bullet (ownership, signals, tick order). "Leaf nodes" now lists only Tutorial, Touch, Leaderboards. Pending-asks note: Era shift ask answered. |
| all | "GDDs written" recount | adapted | See count note at the end of this log. |

### `design/gdd/save-settings-high-scores.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Acc 2, VFX 11, Aud 2, Era 13 | Rule 16 schema: full `access.*` key list (26 keys incl. `access.era_transition_short`), `audio.mono`, `input.move_stick` | applied | Old `access.confirm_style` "hold"/"double_tap" row replaced by the registry's `HOLD`/`DOUBLE_TAP`. Heading no longer says "provisional for owners without a GDD". |
| rules | Display keys reconciled | applied (already) | `display.scale_mode`, `window_mode`, `tate_mode`, `bezel_style`, `window_size` were already in place (wave 3a); `display.bezel` / `integer_scale` absent. |
| Aud 2 | F6 "provisional" → "adopted by Audio F1"; UI bus follows `audio.sfx` | applied | |
| Acc 2 | Rule 18: optional `pad_s0`…`pad_s3` per-slot pad classes (VS) | applied | |
| Acc 2 | Assisted runs return "not ranked" | applied | New Rule 32 (Accessibility Rule 23; latch held by Session). |
| I7 | Interactions rows for Input, Display, Audio, Accessibility link GDDs | applied | Online leaderboards (32) row left (GDD being written). |

### `design/gdd/game-events-and-session.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| VFX 6 | `screen_flash_requested`, `popup_requested` deprecated | applied | Struck through in Rule 13; programmer task noted (prototype emits in `player.gd`, `boss.gd`, `PopupLayer`). Visual section now says the CB frame is the only flash. |
| Aud 3 | `run_state_changed`, `pause_changed`, `tally_hero_landed`; Audio listener | applied | `warning_started` and `tally_*` already present (wave 3a). |
| Era 11 | `era_swap_committed`, `era_load_late`, `era_failed`; wait for `era_ready`; `era_failed` ends run unranked; blocking load → ADR | applied | New "Signals added … wave 3b" and "Session additions … wave 3b" blocks under Rule 13. |
| VFX 8 | `hit_feedback(target_id, result, pos, tick)` | applied | Listed in the signal block. |
| Acc 9 | `run.assisted` latch, game-speed gate, `access.continue_timer` override, assisted → not ranked, `one_credit_clear` false | applied | |
| I6 | Director supplies `is_last_stage`, `next_era` to Tally | applied | |
| I7 | Interactions / Dependencies rows for Era shift, Accessibility, VFX, Audio, Parallax with GDD links; "All interfaces are provisional" line replaced | applied | |

### `design/registry/entities.yaml`

| Source | Item | Status | Notes |
|---|---|---|---|
| Aud | `audio_retrigger_gap_ticks`, `bullet_sfx_voice_cap`, `audio_max_global_voices`, `audio_target_lufs`; formulas `audio_volume_gain`, `audio_rate_gate` | applied | |
| VFX | `vfx_particle_cap`, `vfx_effects_levels`, `vfx_density_by_players`, `death_ring_full_max`, `cancel_puff_caps`, `setting_access_effects_level`, `setting_access_reduce_pulsing`; formulas `cancel_puff_sample`, `fx_evict_victim`, `fx_ring_diameter` | applied | `parallax-and-environment` added to `vfx_particle_cap` (weather counts against 150); `accessibility-options` / `hud` added to the setting keys. |
| Era | `era_ladder`, `era_transition_ticks`, `era_luma_step_max_pct`, `era_vram_budget`, `strip_speed_mode`; formulas `era_release_tick`, `strip_speed` | applied | |
| Par | `parallax_factor_pct`, `bg_zone_px`, `bg_overscan_px`, `boss_plate_blend_ticks`, `boss_grade_ticks`, `env_vram_budget_mib`, `stage_fade_levels`; formulas `ground_anchor_dy`, `layer_draw_offset` | applied | |
| Acc | `text_size_steps`, `game_speed_steps`, `bg_dim_pct`, `ally_shot_dim_floor`, `continue_timer_ticks`, `hitbox_ring_sizes`; formulas `assist_tick_gate`, `ally_shot_opacity`, `palette_acceptance` | applied | `assist_tick_gate` primes written `acc1`/`acc_next` (YAML-safe). |
| all | `referenced_by` extensions (VFX 9 entries, Era 8, Par `canvas_size`/`play_top`, Acc `setting_access_reduce_flashing` + hud/critical-break/stage-end-tally; Acc on `play_top`, `continue_seconds`) | applied | |
| verify | Script check | applied | 192 → 233 entries; no duplicate names; every pre-existing `value`/`expression` byte-identical (no locked value changed). |

### `docs/architecture/adr-0001-gdscript-bullets-multimesh.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I1 | Diagram: 6a EnemyManager.apply_results, 6b CriticalBreakCore.tick, 6c Boss | applied | Diagram line renumbered + one line inserted (user decision), plus a dated wave-3b note before "Related Decisions" superseding the wave-3a "6b is already used" remark. |

## Group A

### `design/gdd/critical-break.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I1 | Rule 1 + tick-order line: 6 → 6a Enemy → 6b CB → 6c Boss → 8 Chain; multiply uses the chain count at the start of the tick | applied | |
| I1 | F3 `before` row "start of tick T"; "Timing (wave 3b)" paragraph; new **AC-46** (187 → 611, then two same-tick hits → 613; call order checked) | applied | Old row said "after this tick's hits". |
| I2 | V5, UI Requirements, Rule 21: ring/arc are a VFX world tell (T0, layer 5, under enemy bullets); HUD draws gold bomb-icon outline + corner ticks when ARMED/COMMITTED | applied | |
| I2 | HUD downstream dependency Hard → Soft | applied | |
| Aud 9 | Rule 28, V6: `sfx_cb_sting`; `cb_stab` 12 dB (50/1500/600 ms); boss music fades after the duck | applied | |
| VFX 7 | V1 reduce-flashing burst scales by `level_pct`; V2 CB cancel ≤ 12 puffs, no ring; shake by VFX, off at REDUCED/MINIMAL | applied | |
| Par 7 / VFX 7 | Desaturation via `Parallax.set_desaturation(pct)`: max 60 % (alpha 153), reduce flashing 25 % (alpha 64) | applied | |
| Acc 18 | OQ8 closed (`access.rumble`); V6 rumble line | applied | |
| I7 | VFX/Audio/Save/Accessibility rows link GDDs; "provisional" sentence removed | applied | |

### `design/gdd/boss-and-boss-parts.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I1 | Tick order: 6a `EnemyManager.apply_results`; "3b / 6b" → "3b / 6a" | applied | |
| Aud 5 | A1: Audio owns `sfx_ui_warning_siren_loop`; Director/HUD only emit `warning_started` | applied | |
| VFX 10 / Par 8 | V4: Parallax renders vignette + grade from `warning_started` + 150 (90-tick ease; enrage 125 %); death sequence is VFX class BOSS_DEATH (40) | adapted | Parallax owns the vignette, so VFX's "band B0 unless Parallax" fallback is dropped. |
| VFX 10 / Par 8 | Dependencies: VFX, Audio → yes; Parallax (23) row added | applied | |
| I7 | Plane kits, Era shift (`era_for_stage`), VFX/Audio rows; "undesigned … provisional" sentence | applied | |

### `design/gdd/player-plane.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Aud 6 | A1: PLANE pool 3 (FlyIn, drone pops); death boom in CRIT pool (max 2) | applied | |
| VFX 12 | Position readable on the death tick | adapted | Signal here is `plane_died(slot)`; written as "`get_position(slot)` valid on the death tick". |
| Acc 10 | OQ3 closed (steady 65 % opacity under reduce flashing, V7); ring size/opacity from `access.hitbox_ring_size` (22/30 px) and `access.hitbox_ring_opacity` | applied | |
| Era 8 | V8: bolt-ons + palette LUT at `era_swap_committed` from `EraDef.bolt_ons`; 1941 hardware is base art | applied | |
| I7 | "All interfaces are provisional" line; HUD, VFX/Audio, Era shift, Accessibility rows | applied | |

### `design/gdd/scoring.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Aud 7 | `sfx_score_extend_jingle`; cap-hold chime on by default | applied | |
| I7 | Audio/VFX row links GDDs | applied | |

### `design/gdd/powerups-and-drops.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| VFX 5 | V4 gem sparkle = 1 particle (2 frames, 4 px), ≤ 1 per 2 ticks, 12 live; others keep the cluster of four | applied | |
| Aud 8 | V6: 1UP pickup silent; jingle from `extend_awarded(gained > 0)` | applied | |
| Acc 17 | OQ9 closed (no item pulse) | applied | |
| I7 | "Audio/VFX provisional" note | applied | `add_powerup`/`add_oneup` "(provisional names)" left: function names, not GDD status. |

### `design/gdd/bullet-manager.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| VFX 4 | VFX reads `cancel_report` / `clear_report` each tick; V6 puff cap 40 across sweeps, CB cancel ≤ 12 | applied | |
| Acc 11 | V3 `access.ally_shot_dim` 0/25/50 (F3, floor 25) | applied | |
| Aud 10 | OQ10 closed; VFX OQ7 closed | applied | |
| I3 | `enemy_bullet_count` | applied | No `enemy_bullets_alive` here. |
| I7 | "Every system is undesigned" sentence; Audio, Accessibility rows | applied | |

### `design/gdd/collision-damage-lives.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| VFX 8 | `hit_feedback(target_id, result, pos, tick)`; "oldest dropped first" = SPARK overflow; VFX in Dependencies | applied | |
| Acc 13 / 20 | `fx_clank`/`fx_ping` are T1 visual twins; `will_die(slot)` callback as a Target-tier note | applied | |
| Aud 10 | OQ7 closed (HIT pool 4, `death_dip` 6 dB) | applied | |
| I7 | "Provisional except three" sentence; HUD/Audio/VFX/Accessibility rows | applied | |

### `design/gdd/plane-kits-lancer-leech.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 6 | Rule 41 visual only + `drone_sprites` per era; V5 drone sprites, 1941 base art; OQ14 closed | applied | Creative-director sign-off still flagged in Era shift. |
| Aud 10 | OQ11 closed (KIT pool 8, laser loops ≤ 2) | applied | |
| Acc 15 | OQ2 closed (no auto-tap) | applied | |
| I7 | Input, Era shift, Audio/VFX "no GDD" rows; "provisional" wording | applied | |

### `design/gdd/bombs.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| VFX 14 | V1 BOMB_DUST global cap 40; VFX dependency | applied | |
| Era 7 | `EraBombSkin` by `(bomb, era_index)` at `era_swap_committed`; links | applied | |
| Acc 16 | OQ2/OQ3 closed: `deathbomb_grace`, `auto_bomb` Target ASSISTs needing `will_die` | applied | |
| Aud 10 | OQ14 closed (BOMB pool 6) | applied | |
| I7 | Section D "(provisional)" → `critical-break.md`; rows for 19/24/25/28 | applied | |

### `design/gdd/chain-tracker.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I1 | Same-tick edge case uses the start-of-tick count; this tick's hits applied at step 8 | applied | Old text said "including this tick's hits". |
| Aud 10 | OQ5 closed (pitches → audio.md; rumble → `access.rumble` / `access.chain_cue_rumble`) | applied | |
| I7 | "Undesigned systems" heading; VFX/Audio links | applied | |

### `design/gdd/enemy-and-ai.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I1 | Step 6b → **6a**; ADR item reads 6a / 6b CB / 6c Boss | applied | |
| Era 3 | Accelerate stripped to Straight at `v_strip` (default `V_EFF`, `strip_speed_mode`); OQ12 partly answered | applied | |
| Par 3 | Rule 8 `scroll_v` → `S_spawn`; STRAIGHT SCROLL uses `(S div 100) - (S_spawn div 100)`; OQ5 closed; Parallax row | applied | |
| VFX 9 | V3 cap behaviour names tiers (debris T3, SMALL T2, MEDIUM/LARGE T1) | applied | |
| I6 | `event_id` in `spawn()` | applied (already) | Present since wave 3a. |
| I7 | Era shift, VFX/Audio/HUD rows; "provisional" sentence | applied | |

### `.claude/docs/technical-preferences.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Aud 11 | Audio ≤ 16 MB, 32 voices, ≤ 0.1 ms p99 | applied | Additive, dated. |
| VFX / Par / Era | Proposal bullet: 150 effects ≤ 8 draw calls, VFX tick 0.25 / pack 0.35 ms; parallax 8/10 draw calls, ≤ 28 MiB; era peak 74 MB | adapted | Additive, dated; not asked for by a report but collects the stated budgets. |

## Group B

### `design/gdd/hud.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I3 | `enemy_bullets_alive` → `enemy_bullet_count` | applied | 4 places (Rule 27, Interactions, Dependencies, AC-45). |
| I2 | Rule 28: VFX owns the core ring/arc (world tell, T0, layer 5, below enemy bullets); HUD draws only the Gold bomb-icon outline + corner ticks while `cb_state` ARMED/COMMITTED | applied | AC-28 uses `cb_state`, no longer provisional. |
| I4 | Strip hidden while the tally panel is up; shows again at `stage_started` | applied | State table + Tally row. |
| I5, Acc 3 | Rule 23: Selecting slot → next layout mode for display only (1P→2P, 2P→3-4P); 84x44 pick plate in that column; `N` unchanged; strip heights 48/72 only | applied | OQ6 note. |
| Acc 3 | Rule 34: no HUD scale, `play_top` 48/72; Rule 34a: 12x12 `assist_tag` (lint exempt), optional near-plane chain bar (layer 7), Continue plate reads `access.continue_timer` | applied | OQ9 closed; `hud_scale_pct` knob removed; old Amendment 11 struck as withdrawn. |
| Acc 3, Era 10 | Rule 33: theme via `access.hud_contrast` + `access.player_palette`; era tint on `era_swap_committed` (fallback `stage_started`) | applied | Era shift rows (`ui_tint`). |
| I7, Aud 12 | Accessibility, Audio, VFX rows link GDDs | applied | |

### `design/gdd/stage-end-tally.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 1 | Rule 18: hold requested on the `tally_exit` tick; 45-tick fade inside Dim; era ids; `to_era` none on final stage; pause per Rule 21 | applied | OQ7 closed. |
| I6 | Director supplies `is_last_stage`, `next_era` at `stage_cleared` | applied | |
| I4 | Rule 24: HUD strip hidden; tally owns the full canvas | applied | Replaces the wave-3a "strip kept" note. |
| Acc 12 | No NEW BEST when `run.assisted` | applied | Rule 13; Accessibility in Dependencies. |
| Par 6 | `tally_scroll_pct` is a percent of the speed at tally open (25 x 25 div 100 = 6); grade eases out over 60 ticks | applied | |
| I7 | Provisional note replaced; Era shift, Audio, VFX, Parallax rows linked | applied | |

### `design/gdd/wave-and-stage-director.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I6 | `spawn()` params include `event_id` | applied | Rule 6, Interactions, AC-05. |
| I6, Era 2a | Rule 25 reordered (stage during tally, swap tick 90, `era_ready` before Tally Done, `load_stage` requires it); Director supplies `is_last_stage` / `next_era` (`era_for_stage`) | applied | |
| Era 2b | Rule 19: stripped Accelerate → Straight at `v_strip` (default `V_EFF`) | applied | |
| Par 2a–d, g | `ScrollClock`; ground enemies follow live `S`; AC-28 last clause; V2 static plates + L0/L1 crawl; V5 plate sets; `EnvValidator` V-E1–V-E5 | applied | |
| Par 2e, Acc 17 | OQ5 closed (drift 25); OQ10 closed (no label) | applied | |
| Aud 12 | Emits `warning_started` | applied (already) | Present since wave 3a. |
| I7 | Era shift, Parallax, Audio rows → yes + links | applied | Tutorial row left (being written). |

### `design/gdd/menus-title-plane-select.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I5 | Rule 52 decided (next-layout display mode) | applied | OQ3 closed. |
| Acc 7 | `access.confirm_hold` (rule + knob), `untimed_menus`; OQ8, OQ9 closed; Settings rows from `AccessOptionDef`; first-run prompt after Web gate; Pause status panel; PRACTICE tag on Pause and Results | applied | Rules 42, 51. |
| I7 | Accessibility, Audio, VFX rows linked | applied | Touch/Tutorial/Online rows left (being written). |

### `design/gdd/localization.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 12 | Rule 17a `format_plain(n)` (no grouping); keys `era.name.*`, `era.card.skip`, `era.error.load`; Era shift row | applied | |
| Acc 6 | OQ8 closed (Accessibility F1); Accessibility row not provisional | applied | |
| Aud 4 | OQ12 closed (no voice lines at MVP) | applied | |
| I7 | Save row not provisional | applied | |

### `design/gdd/input-and-player-mapping.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Acc 8 | Rule 23 `access.nav_repeat` (12/4, 18/6, 30/10); Rule 24a latch presses on skipped ticks; Rule 34 `input.move_stick`; Rule 35 `pad_s0..3`; OQ6, OQ10 closed | applied | 24a because Rule 24 is the menu-verb rule. |
| I7 | Provisional note covers only Touch; Accessibility, Audio, VFX rows linked | applied | |

### `design/gdd/coop-and-team-chain.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| VFX 2 | V2: at most 2 full death rings, others compact (VFX Rule 23); VFX dependency with density by `N` | applied | |
| Par 10 | Parallax row: no change at any `N`, no team background pulse | applied | |
| Acc 19 | Assisted co-op runs unranked | applied | Rule 18 + Dependencies. |
| I7 | Provisional note replaced; Save, Audio, VFX rows linked; "Inputs from undesigned systems" heading fixed (main pass) | applied | |

### `design/gdd/display-scaler-and-bezel.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 9 | Rule 12: bezel swap on `era_swap_committed` (fallback `stage_started`); Era shift rows | applied | |
| Acc 4 | All HUD-scale text → "no HUD scale; `play_top` unchanged by accessibility options" | applied | Lines ~114, ~117, ~306, ~309, ~351; grep clean. |
| VFX 3, Par 4 | OQ5 closed: no global shake, boss offset ≤ 4 px, overscan 8 px | applied | |
| Keys | `display.scale_mode`, `window_mode`, `tate_mode`, `bezel_style`, `window_size`; `display.bezel` / `integer_scale` retired | applied | An older "Matched 2026-11-03" note now duplicates it (cosmetic). |
| I7 | Save, Input, Localization rows "No (provisional)" → Yes + links | applied | |

### `design/gdd/boss-power-budget.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 4a–d | `behaviour_ladder` data in `EraDef` (via `EraLadder`); option ladder at Rule 19; Era shift row linked; AC-26 + `V_EFF`; Rule 20 strips to `v_strip` | applied | |

### `design/gdd/bullet-pattern-library.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 5a–c | V4 1941 = Straight only; OQ6/OQ7 → Era shift OQ4/OQ8; rows linked | applied | |
| VFX 15, Aud | VFX row notes the assumed max 8 concurrent flak fuses (open); Audio row notes tail-aligned fuse samples | applied | |

### `design/gdd/game-concept.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Era 15 | §3 "look and ability visuals only; all numbers identical in every era"; §10 note names Era shift (19) | applied | Added as notes. |

## Group C

### `design/gdd/vfx-and-screen-feedback.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Par 7b | OQ5 closed (Parallax renders the vignette); `fx_boss_vignette` removed; B0 / layer-2 = scorch only; screen-policy Vignette row → Parallax Rule 20 | applied | |
| Par 7b | Weather / smoke requests from Parallax are T4 and count against 150; Parallax Interactions row rewritten | applied | |
| Par 7b | Rule 6: any shake capped at `bg_overscan_px` 8 (default 4) | applied | |
| Acc 13 | `fx_clank`, `fx_ping` T2 → T1 (visual twins) | applied | |
| Acc 13 | OQ7 closed: REDUCED removes local shake; no separate toggle | applied | |
| I2 | New catalogue row `fx_cb_core_ring`: world-space, layer 5 / B5, below enemy bullets, never over them; driven by `cb_state`; TELL class, T0. HUD row states the split (HUD: Gold bomb-icon outline + corner ticks while ARMED/COMMITTED) | applied | |
| I2 | CB (17) upstream row reads `cb_state(slot)` | applied | |
| I7 / Aud 12 | "All interfaces are provisional" replaced; HUD, Parallax, Audio, Accessibility, Director / Era shift (`era_swap_committed`) rows → GDD links | applied | |

### `design/gdd/accessibility-options.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Par 7c | Rule 12 "L0-L5" → "L0-L4 plus boss plates and props" | applied | |
| Par 7c | Rule 10: Reduce motion → `set_scroll_scale(50)` on L0/L1/L2/L4; L3 and ground targets stay on `S`; limit stated | adapted | Replaces "layers above L2 at 50 %"; AC-13 updated. |
| Par 7c / I7 | Parallax rows → GDD (DIMMED 166 / PLAIN contract); HUD row "index says no GDD" removed | applied | |
| Era 13 | `access.era_transition_short` added (bool, false, PRESENTATION, EVENT, MVP hook, owner Era shift 19; not in Calm preset); Era shift rows added | applied | Coordinator request so Save and the registry agree. |
| Save reconcile | OQ15 closed: Display/Menus keys adopted; `display.bezel` / `integer_scale` removed | applied | |

### `design/gdd/audio.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Acc 14 | `visual_twin` lint field in `audio_events.tres` (required for P0/P1) | adapted | Rule paragraph above the event table, not a printed column on ~75 rows. |
| Acc 14 | `sfx_chain_window_tick` plays only when `access.chain_cue_audio` is true | adapted | Conflicts with Audio's "on by default" decision; see remaining inconsistencies. |
| Acc 14 | `audio.mono` registered by Accessibility, stored by Save | applied | |
| Acc 14 / VFX | Visual-twin table: clank / ping → `fx_clank` / `fx_ping` (T1); AC-50 exception removed; OQ5 closed | applied | |
| I7 / Aud 12 | "Provisional interface (no GDD yet …)" rewritten; Director, Tally/Menus/HUD, Accessibility, VFX rows → links; Era shift row added | applied | |
| Tally / Director | Signal row matched to real signals: `warning_started(ticks)`, `tally_started`, `tally_row_revealed(slot, line)`, `tally_new_best`, `tally_finished`; hero sound on the max-chain row reveal | adapted | No `tally_hero_landed` signal exists in the Tally GDD (Session lists it as provisional). TALLY music starts on `tally_started`. |
| — | OQ8 (`warning_ticks` 150), OQ9 (rumble → Accessibility), OQ10 (no captions; visual twins) closed | applied | |

### `design/gdd/era-shift-and-plane-evolution.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Par 7a | Parallax row → GDD: `free_set()` at tick 53, `env_prepared` before `era_ready`, overlay z 105, fade levels 85…0 at 4 ticks/step | applied | |
| Par 7a | F5 output range / example → Parallax's sequence (36 ticks; gap 172 ≥ 170) | adapted | Owners win (old draft 85, 75 … 5, 0 at 8 ticks/step). |
| I7 | Audio, VFX, Menus, Accessibility rows → GDD; `access.era_transition_short` no longer provisional | applied | |
| I6 | Director supplies `next_era` and `is_last_stage` to the Tally at `stage_cleared` | applied | |

### `design/gdd/parallax-and-environment.md`

| Source | Amendment | Status | Notes |
|---|---|---|---|
| I7 | Rule 29 no longer "provisional"; Reduce motion calls `set_scroll_scale(50)` | applied | |
| I7 | Downstream VFX row → yes (link); Menus / Tally → yes / yes | applied | |

### `design/art/art-bible.md` (additive notes headed "Added 2026-11-03 (wave 3b, …)")

| Source | Amendment | Status | Notes |
|---|---|---|---|
| Aud 13, Par 5 | §2: Audio follows the State Mood Table; grayscale gate procedure lives in the Parallax GDD | applied | |
| Par 5 | §4.5 1970s accent warm rule (pending art director); §6.4 strips 376 wide, plates 376 x 656; §6.5 factors and zones; §6.9 plates, `boss_rgb`, vignette (Parallax) | applied | |
| VFX 13 | §4.6 Amber `#FFB000` AMBER role (pending); §6.8 `z_index = layer*10+sub` + band table; §8.3 ring bake + sprite families; §8.6 150 hard total, non-additive caps, tiers | applied | |
| Acc 5, VFX 13 | §7.9 note: HUD-scale bullet superseded (no HUD scale, `play_top` 48/72); "screen-shake" = local boss shake; reduce motion, background dim/plain, effects level, game speed = PRACTICE | applied | Old bullet kept, marked superseded. |
| Era 16, Par 5 | §5.5 1941 hardware is base art, first bolt-on set 1970s, visual-only evolution; §8.6 staged loading (peak 74 MB), parallax 8/10 draw calls, env VRAM 28 MiB (22.5 planned) | applied | |

## Final pass

| Item | Status | Notes |
|---|---|---|
| Systems index "GDDs written" | applied | **32**: 34 files in `design/gdd/` minus game-concept and systems-index; none contains "[To be designed]". This includes the four GDDs being written during this pass (29 Sentry/Breaker, 30 Tutorial, 31 Touch, 32 Leaderboards). Their index rows were left for their writers. |
| I7 sweep | applied | A grep for "no GDD" / "provisional" found three more stale lines, now fixed: Co-op "Inputs from undesigned systems", Save Interactions header, systems-index "Scoring (8) provisional contracts". The rows left on purpose point at 29–32, the Online leaderboards GDD's own stale rows (file being written) and generic table headers. |
| Session | adapted | `tally_hero_landed` is not added. Audio (Group C) plays the hero sound on the max-chain `tally_row_revealed`. |

## Remaining inconsistencies (for the user / next pass)

1. **Chain-window tick default.** Audio's decision says it is ON by default. Accessibility's `access.chain_cue_audio` defaults to false, and Audio now gates the sound on that key. The two disagree about the default.
2. **Era card effects layer.** Era shift puts time-dust and the reveal burst on layer 11, inside the era card. VFX Rule 1 / AC-01 allow nothing above layer 6 except `fx_cb_flash`. Fix: either VFX makes an exception for the card, or Era shift owns those sprites.
3. **Display-only layout during drop-in (I5).** While a Selecting slot pushes the display to 3-4P, the strip is 72 px. Player plane and Co-op do not yet say that `play_top` push-down and gameplay rules ignore the display mode. Boss OQ5 (the mid-fight `play_top` 48→72 jump) is also still open.
4. **Flak fuse cap.** VFX assumes at most 8 concurrent fuses. Neither the Pattern library nor the Director enforces this.
5. **Online leaderboards GDD** (being written) still says Era shift, HUD and Tally have "no GDD" (lines ~197, 198, 369).
6. **Audio OQ11** (TATE confirm sound) is still open. Display scaler has a duplicate "Matched" key note (cosmetic only).
7. **Programmer tasks** (code not touched):
   - Remove the `screen_flash_requested` emits and `PopupLayer`.
   - Renumber the GameLoop step 6 sub-order.
   - Write an ADR for the game-speed scheduler and for blocking-load tick discard.
