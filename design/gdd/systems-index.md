# Systems Index: MorutJan

> **Status:** **Approved (2026-11-03)** — indexed and approved 2026-11-02 (lean review mode; director gates skipped); all 32 system GDDs accepted 2026-11-03 at the Concept → Pre-Production gate
> **Source:** `design/gdd/game-concept.md`
> **Pillars:** Every Hit Counts · Readable Chaos · Four Planes, Four Games · History Accelerates
> **Last Updated:** 2026-11-03 — final doc closeout: all 32 system GDDs and the game concept are **Approved (2026-11-03)**; all 9 ADRs **Accepted (2026-11-03)** except ADR-0001, which is *Accepted (provisional) — pending benchmark V1*; all 12 UX specs in `design/ux/` **Approved (2026-11-03)**; `production/stage.txt` set to **Pre-Production**. Earlier note (UX amendments wave 5): Menus (22) gains a soft dependency on Accessibility (28), which it already reads (`access.confirm_style`, `access.confirm_hold`, `access.untimed_menus`, and now `access.reduce_motion` for the Credits roll, Menus Rule 46).

## Decisions captured at index time

- **Boss power budget:** a boss's mechanics are foreshadowed across its stage. Wave N previews boss mechanic N; wave 5 previews the combination; the boss then combines everything. Rule is fixed by the stage; the per-boss mechanic list is owned by the Boss power budget GDD; the Wave director only schedules it (this breaks the budget/director cycle). (Detail in boss-power-budget.md.)
- **Powerups (dropped by small enemies)** *(revised 2026-11-02)*: each powerup adds **+1 drone** (max 4); drones and shots never get stronger; death resets to 0 drones; drones carry across stages. Also: chain pickup, score medals, rare 1-ups. The temporary shot upgrade is removed. Bomb and meter refills are NOT powerups. Must not become stat grinding (anti-pillar). *(Amended 2026-11-03, powerups-and-drops.md: only carrier enemies flagged by their wave drop items; cancelled bullets give gems.)*
- **Planes** *(2026-11-02)*: three buttons — Fire (tap shot / hold charge mode), Drone, Bomb. MVP planes are **Lancer + Leech** (see game-concept §5); Sentry and Breaker are redesigned later under the same drone rules.

## Systems

Layers: F = Foundation, C = Core, Ft = Feature, P = Presentation, Po = Polish.

| # | System | Layer | Tier | Depends on | Status |
|---|---|---|---|---|---|
| 1 | Game events and session state | F | MVP | — | **Approved** (2026-11-03) — [GDD](game-events-and-session.md) |
| 2 | Input and player mapping (1–4P) | F | MVP | 1 | **Approved** (2026-11-03) — [GDD](input-and-player-mapping.md) |
| 3 | Bullet manager (pooled) | F | MVP | 1 | **Approved** (2026-11-03) — [GDD](bullet-manager.md) — **bottleneck, high risk** |
| 4 | Display scaler and bezel | F | MVP (basic) / Target (full) | 1 (soft), 26 (soft) | **Approved** (2026-11-03) — [GDD](display-scaler-and-bezel.md) |
| 5 | Player plane, movement, hitbox | C | MVP | 1, 2 | **Approved** (2026-11-03) — [GDD](player-plane.md) |
| 6 | Collision, damage and lives | C | MVP | 1, 3, 5 | **Approved** (2026-11-03) — [GDD](collision-damage-lives.md) |
| 7 | Chain tracker | C | MVP | 1, 6 | **Approved** (2026-11-03) — [GDD](chain-tracker.md) |
| 8 | Scoring | C | MVP | 1, 6, 7 | **Approved** (2026-11-03) — [GDD](scoring.md) |
| 9 | Bullet pattern library | C | MVP | 1, 3, 5, 6 | **Implemented** (2026-11-04) — [GDD](bullet-pattern-library.md) — `src/gameplay/patterns/`, 16 patterns in `data/patterns/`; OQ 11-13 open |
| 10 | Enemy and AI (small/medium/large) | Ft | MVP | 3, 6, 8, 9 | **Approved** (2026-11-03) — [GDD](enemy-and-ai.md) |
| 11 | Plane kits and drones: Lancer, Leech | Ft | MVP | 1, 3, 5, 6, 7 | **Approved** (2026-11-03) — [GDD](plane-kits-lancer-leech.md) — **bottleneck, high risk** |
| 12 | Bombs | Ft | MVP (2 planes) | 1, 2, 3, 5, 6, 7 | **Approved** (2026-11-03) — [GDD](bombs.md) |
| 13 | Powerups and drops | Ft | MVP | 1, 3, 5, 6, 7, 8, 10, 18 | **Approved** (2026-11-03) — [GDD](powerups-and-drops.md) |
| 14 | Boss and boss parts | Ft | MVP | 3, 6, 7, 8, 9, 10, 18 | **Approved** (2026-11-03) — [GDD](boss-and-boss-parts.md) |
| 15 | Boss power budget | Ft | MVP | 9, 10, 14 | **Approved** (2026-11-03) — [GDD](boss-power-budget.md) |
| 16 | Wave and stage director | Ft | MVP | 1, 3, 9, 10, 13, 14, 15, 18 | **Approved** (2026-11-03) — [GDD](wave-and-stage-director.md) |
| 17 | Critical Break | Ft | MVP | 1, 3, 7, 8, 11, 12, 14 | **Approved** (2026-11-03) — [GDD](critical-break.md) |
| 18 | Co-op and Team Chain Bonus | Ft | MVP | 1, 5, 7, 8 | **Approved** (2026-11-03) — [GDD](coop-and-team-chain.md) |
| 19 | Era shift and plane evolution | Ft | MVP (1→2) / Target (3–4) | 1, 3, 9, 10, 11, 12, 15, 16, 21 | **Approved** (2026-11-03) — [GDD](era-shift-and-plane-evolution.md) |
| 20 | HUD | P | MVP | 1, 4, 7, 8, 11, 12, 14, 18, 27 | **Approved** (2026-11-03) — [GDD](hud.md) |
| 21 | Stage-end tally | P | MVP | 1, 7, 8, 18 (soft), 26 (soft), 27 | **Approved** (2026-11-03) — [GDD](stage-end-tally.md) |
| 22 | Menus, title and plane select | P | MVP (basic) | 2, 26; soft 1, 4, 11, 18, 27, 28 | **Approved** (2026-11-03) — [GDD](menus-title-plane-select.md) |
| 23 | Parallax and environment | P | MVP (basic) | 1, 4, 16 (soft: 17, 19, 21, 25, 28) | **Approved** (2026-11-03) — [GDD](parallax-and-environment.md) |
| 24 | Audio | P | MVP (basic) | 1; listens to 2, 3, 5–18, 26 (soft) | **Approved** (2026-11-03) — [GDD](audio.md) |
| 25 | VFX and screen feedback | P | MVP (basic) | 1, 3, 5, 6, 9, 10, 11, 12, 13, 14, 17, 18 (soft: 4, 23, 26) | **Approved** (2026-11-03) — [GDD](vfx-and-screen-feedback.md) |
| 26 | Save, settings and high scores | F | Vertical Slice | 1 | **Approved** (2026-11-03) — [GDD](save-settings-high-scores.md) |
| 27 | Localization (Bengali + English) | F | Vertical Slice | — | **Approved** (2026-11-03) — [GDD](localization.md) |
| 28 | Accessibility options | Po | Vertical Slice | 1 (soft), 2, 4, 20, 21, 22, 24, 25, 26, 27 | **Approved** (2026-11-03) — [GDD](accessibility-options.md) |
| 29 | Plane kits: Sentry, Breaker (+ bombs) | Ft | Target | 3, 6, 11, 12 | **Approved** (2026-11-03) — [GDD](plane-kits-sentry-breaker.md) |
| 30 | Tutorial | Po | Target | 16; soft 1, 2, 6, 7, 9, 10, 11, 12, 13, 14, 15, 17, 18, 20, 22, 26, 27 | **Approved** (2026-11-03) — [GDD](tutorial.md) |
| 31 | Touch controls | Po | Target | 2, 4, 5 | **Approved** (2026-11-03) — [GDD](touch-controls.md) (the `/ux-design` pass for the strip and settings still runs) |
| 32 | Online leaderboards, boss rush | Po | Full Vision | 26, 1, 2, 8, 14, 16, 22, 28 | **Approved** (2026-11-03) — [GDD](online-leaderboards-boss-rush.md) — Stretch |

## Dependency notes

- **Scoring (8) contracts** *(confirmed 2026-11-03: Enemy 10, Boss 14, Powerups 13 and Co-op 18 GDDs supply them)*: Enemy (10) and Boss (14) supply kill class SMALL/MEDIUM/LARGE/PART/CORE; Boss (14) needs an enrage timer; Powerups (13) owns item kinds and `items_per_cancel_cap`; Co-op (18) owns `team_pct`.
- **Bidirectional reminder:** every downstream GDD (systems 2, 5, 6, 7, 8, 11, 13, 16, 17, 18, 20, 21, 22, 24, 25, 26) must list "Game events and session state" in its Dependencies with the interface from `game-events-and-session.md`.
- **Save (26):** hard dependency is 1 only. Settings schema keys come from 2, 4, 24, 27, 28 (soft). Session calls Save from Results; Save Rule 31 makes that call a no-op when Save is absent, so MVP is unaffected by Save being Vertical Slice. Future GDDs 2, 4, 21, 22, 24, 27, 28, 32 must list Save (26) with the interface in `save-settings-high-scores.md` *(2026-11-03, wave 4: satisfied — Online leaderboards (32) lists Save; Tutorial (30) and Touch (31) also register keys)*.
- **Co-op (18):** owns `N`, `team_pct` per member count, join grace and hp/group-size scaling. Enemy (10), Boss (14), Wave director (16), Powerups (13) and Save (26) must list Co-op in their Dependencies.
- **Localization (27):** interface notes for HUD (20), Tally (21), Menus (22), Save (26), Accessibility (28) — numerals via `Localization.format_int`, strings by key, `language_changed` on the `Localization` autoload, `settings.language` stored by Save, text-size step via `font_size_px(tier, step)`.
- **Input (2):** GDDs 11, 12, 18, 20, 21, 22, 26, 28, 31 must list Input in Dependencies.
- **Display scaler (4):** GDDs 20, 21, 22, 26, 28, 31 must list Display scaler and bezel in Dependencies.
- **Menus (22) (2026-11-03):** HUD (20), Stage-end tally (21), Accessibility (28) and Touch controls (31) must list Menus in their Dependencies. Run flow: Director (16) emits `stage_cleared` → Stage-end tally (21) runs after every stage, the last one included → Results (Menus 22). Signal additions from 16, 17, 21 are consolidated in `game-events-and-session.md` Rule 13.

- **Bottlenecks:** Bullet manager (3) and Plane kits (11). Design these carefully; most combat systems read from them.
- **Cycle resolved:** Boss power budget (15) ↔ Wave director (16) — see decisions above.
- **Cycle resolved (2026-11-03):** Plane kits (11) ↔ Powerups (13). Kits no longer depend on 13; Powerups writes `drone_count` through Session (1), and 11 is an indirect dependency of 13 only.
- **Pending asks for unwritten GDDs (2026-11-03):** Wave director (16): at least 8 carriers per stage (4 SMALL, 2 MEDIUM, 2 LARGE), at least one per wave, at least 180 ticks apart, not scaled with N (Powerups 13); schedule previews, run `check_stage`, apply novelty gating, `preview_alive_max` 1, `combo_window_ticks` 180, at least 2 successive carriers per preview wave (Boss power budget 15); leave at least 75 ticks between `boss_defeated` and `stage_cleared` for the item sweep (Powerups 13). Critical Break (17): owns the trigger from the kit's `charge_active` / `charge_kind` / `charge_last_hit` (Plane kits 11); calls `critical_break_finish(slot)` and reads `is_critical()` (Boss 14); reports `cb_armed(slot)` to waive the bomb toll and issues its own full-screen cancel before the banner (Bombs 12). Era shift (19): owns the behaviour/option ladder and native-pattern stripping (15); `EraKitSkin` / `EraBombSkin` are visual only. Systems 17, 19, 20, 24, 25, 28, 29, 30 must list Bombs (12) when written (13 and 14 already do). *(2026-11-03, wave 3a: the asks to 16 and 17 are answered in their GDDs — Director places 8 carriers/stage and runs `check_stage`; `stage_cleared` ≥ `boss_defeated` + 90 (`sweep_min_ticks`); CB publishes `cb_state(slot)` / `cb_armed` and issues its own cancel. Wave 3b: the Era shift ask (19) is answered in its GDD — `EraDef` holds the ladder, strip map and visual-only skins.)*
- **Wave 3b (2026-11-03):** Era shift (19) owns the behaviour/option ladder (`EraDef`), the strip map and the 201-tick transition inside the Tally exit hold; it emits `era_swap_committed`, `era_ready` (before Tally Done), `era_load_late`, `era_failed`. Parallax (23) owns background layers L0–L4, the ground scroll `S` (`ScrollClock` in the Director module), boss plates and the boss vignette, and provides `set_desaturation`, `set_background_mode`, `set_scroll_scale`. Audio (24) owns buses, voice pools and music; it listens to `warning_started` (Director) and the `tally_*` events. VFX (25) owns the shared 150-instance effect pool, the screen policy (no global shake, only the CB flash) and the CB core ring tell. Accessibility (28) reads Input (2), Display (4), HUD (20), Tally (21), Menus (22), Audio (24), VFX (25), Save (26), Localization (27), owns the `access.*` registry and the assist rule (`run.assisted` latch held by Session; assisted runs are PRACTICE, unranked). Tick order inside step 6: 6 CollisionReferee, 6a EnemyManager.apply_results, 6b CriticalBreakCore.tick, 6c Boss.apply_results (ADR-0001).
- **Wave 4 (2026-11-03):** Sentry/Breaker (29) inherit Lancer/Leech Rules 1–15, add bullet tags 2 (charge shot) and 3 (return bolt), `charge_kind` `ENTRENCH`/`BREACH`, Breaker net circle cancels with `items = false` and the Bullet manager per-tick `cancel_report[]` (one merged report, BM Rule 13), and bombs Bastion/Backlash under Bombs (12); systems 17, 19, 20, 24, 25, 28 should list system 29. Tutorial (30) adds Session `run_kind` (`RUN`/`DRILL`) and `start_school`, HUD `strip_mark` and drill bar, Collision `drill_mode`, Enemy `hp_override`/`dummy`/`drop_override`, Boss `TrainingBossDef`, five `tutorial.*` Save keys. Touch (31) binds TOUCH to slot 0 (solo only), adds `SlotInput.drag`/`drag_active`/`fire_auto`, Player plane PF8 leash, Display `touch_strip_rect`, `/touch` boards and `touch.*` keys. Online leaderboards (32) adds RUSH/BOSS board ids, `RunRecord` replay fields, `online.*` keys, boss-only stages (`waves = []`, `home_stage`) and `slot_stage_bound` (Scoring). `play_top` is latched at `stage_started` and `wave_started`; HUD layout follows the latched value; gameplay never reads the HUD display mode.
- **Leaf nodes (design late):** none left — all 32 systems have GDDs (Tutorial, Touch controls, Leaderboards designed 2026-11-03).

## Recommended design order (GDDs)

MVP first, by layer:

1. Bullet manager (3)
2. Player plane (5)
3. Collision, damage and lives (6)
4. Chain tracker (7)
5. Scoring (8)
6. Bullet pattern library (9)
7. Enemy and AI (10)
8. Plane kits and drones: Lancer + Leech (11)
9. Bombs (12)
10. Boss and boss parts (14)
11. Boss power budget (15)
12. Powerups and drops (13)
13. Wave and stage director (16)
14. Critical Break (17)
15. Co-op and Team Chain (18)
16. Era shift (19, 1→2 slice)
17. HUD (20), Stage tally (21), Menus (22)
18. Parallax, Audio, VFX (23–25)
19. Foundation leftovers: Events/session (1), Input (2), Display scaler (4) — all done

Then Vertical Slice (26–28), then Target (29–31).

## High-risk systems

| System | Risk |
|---|---|
| Bullet manager | ~2000 bullets at 60 fps on Web and phones; GDScript vs C# decision pending (ADR) |
| Plane kits | Lancer invulnerable laser may dominate; four kits must chain differently |
| Powerups | Must not drift into stat grinding (anti-pillar) |
| Co-op (4P) | Screen flood vs Readable Chaos |

## Progress tracker

| Metric | Count |
|---|---|
| Systems total | 32 |
| MVP | 25 |
| GDDs written | 32 (Accessibility Options, Audio, Bombs, Boss and Boss Parts, Boss Power Budget, Bullet Manager, Bullet Pattern Library, Chain Tracker, Collision, Damage and Lives, Co-op and Team Chain Bonus, Critical Break, Display Scaler and Bezel, Enemy and AI (small / medium / large), Era Shift and Plane Evolution, Game Events and Session State, HUD, Input and Player Mapping (1-4P), Localization (Bengali + English), Menus, Title and Plane Select, Online Leaderboards and Boss Rush, Parallax and Environment, Plane Kits and Drones: Lancer, Leech, Plane Kits and Bombs: Sentry, Breaker, Player Plane (movement, hitbox, look), Powerups and Drops, Save, Settings and High Scores, Scoring, Stage-End Tally, Touch Controls, Tutorial (Flight School and First-Run Hints), VFX and Screen Feedback, Wave and Stage Director) — recounted from `design/gdd/` 2026-11-03 (wave 4): 34 files minus game-concept and systems-index, none containing "[To be designed]". Rows 19, 23, 24, 25, 28 set to Designed in wave 3b; rows 29–32 set to Designed in wave 4 — all 32 systems designed (pending review) |
| Code exists without GDD | 0. Pre-GDD prototype code in `src/` must be migrated to its GDD (e.g. Critical Break logic in `src/gameplay/boss/boss_part.gd` / `laser_ability.gd`, `src/ui/hud/hud.gd`, `src/autoload/game_events.gd` signal set) |

## Open items carried over

Final title. (Touch controls UX spec closed 2026-11-03: `touch-controls.md` is the design basis; the `/ux-design` pass still runs. Co-op lives/continues closed: per player, Co-op 18. Language split closed: Localization 27. Bomb design per plane closed: Bombs 12, 2026-11-03. Critical Break formula and Life Damage Bonus closed 2026-11-03: Chain F4, Scoring F4, trigger in critical-break.md.)
