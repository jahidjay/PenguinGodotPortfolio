# Session Handoff — MorutJan (saved 2026-10-23, updated 2026-10-31)

Read this first in a new session. It replaces the old conversation history.

## Latest (2026-11-15): Stage 1 wave rules — user-directed, GDD set aside
The user is now driving the game step by step and said to ignore the GDD for this work.
- A wave ends only when every enemy it sent is SHOT DOWN (`WaveDef.max_ticks` removed).
- An enemy that leaves the field or times out respawns at its spawn point, keeping its damage
  (`EnemyRules.respawn_on_escape`).
- Squad aggression: a spawn group of 2+ with half its members down flies 1.25x faster and fires at
  +0.35 intensity; the last survivor flies 1.5x faster at +0.7 (`data/enemy_rules.tres`). The 1941 wave
  patterns now have `interval_at_full` / `count_at_full`, so intensity changes how they fire.
- Lancer drone ability is now a Drone Shield (replaced "park"): drones line up just in front of the plane,
  follow it, fire straight up with the plane's gun, and erase enemy bullets touching them. Each drone
  breaks after `shield_budget` blocks; the shield lasts `shield_ticks` (`data/kit_rules.tres`).
- Next (user's plan): after STAGE CLEAR nothing happens yet; more stages and progression come next.

## Project in one line
2D vertical bullet-hell shmup (DoDonPachi-style chain) — four 1941 planes, each stage jumps forward in time (1941 → 1970s → 2030s → 2100+), 1–4 local co-op. Godot 4.7, GDScript + C#.

## Studio settings
- Stage: `Concept` (`production/stage.txt`)
- Review mode: `lean` (`production/review-mode.txt`)
- Engine knowledge risk: HIGH (4.7 beyond training) — check `docs/engine-reference/godot/` before writing engine code

## Files created so far
| File | What |
|---|---|
| `design/gdd/game-concept.md` | Full concept: pillars, core loop, chain rules, 4 planes, scope tiers, risks, visual anchor |
| `CLAUDE.md` | Tech stack + engine reference import |
| `.claude/docs/technical-preferences.md` | Naming (GD + C#), input (gamepad primary, 4P co-op), budgets (60fps, ~2000 bullets, pooled), specialist routing |
| `docs/engine-reference/godot/*` | VERSION, breaking-changes 4.3→4.7, deprecated-apis, best-practices |
| `prototypes/boss-chain-concept/` | Standalone Godot prototype (`project.godot`, `main.tscn`, `main.gd`, `README.md`) |

## Key design decisions (locked)
- **Pillars:** Every Hit Counts · Readable Chaos · Four Planes, Four Games · History Accelerates
- **Chain:** strict ~1 s window, **pure reset** to 0 when it expires; per-player counter; Team Chain Bonus in co-op
- **Critical Break:** boss core at critical HP + charge (laser) + bomb together → chain ×3 +50, big score + life bonus
- **Stage structure:** each stage = 5 waves → boss
- **Planes:** Sentry (stationary turret drones, recall), Breaker (drones erase bullets, return), Lancer (laser: dmg mult + invulnerable, meter fills from hits), Leech (drones latch onto enemies)
- **Era shift:** everything evolves (enemies, bullets, player plane look/abilities)
- **Action feel:** hybrid — lighter waves, DoDonPachi-density bosses
- **Visual anchor:** "Arcade Chronicle" — 1941 pixel art + per-era palette layer; player shots warm, enemy bullets cool w/ dark outline
- **MVP:** 2 stages (1941, 1970s), Lancer + Sentry, local co-op 1–4 (tested at 2P)
- **Platforms:** PC + Web (mobile later)

## Prototype status — /prototype boss-chain (Engine path)
- **Iteration 1 result (user):** single-player chain + laser + Critical Break loop "working perfectly". Effectively PROCEED on the core loop.
- **Iteration 2 (built, NOT yet playtested):** 3 bosses with destructible parts, selectable 1/2/3, N next, R restart
  - 1941 Flying Fortress: 2 turrets (fans) + 2 rect engines (rings); core armored (25% dmg) while parts live
  - 1970s Jet Carrier: 3 orbiting pods (aimed streams) + 2 wings (bullet walls w/ gap); accelerating bullets
  - 2100 Plasma Ring: 4 orbiting shields (curving bullets); core immune until shields die; time-warp bullets
  - Part kill: stops its pattern, cancels bullets in 90px, +5 chain, +2000 score. Laser stops at first part in column.
- Godot is not on the shell PATH here — code was never run by Claude; user runs it with F5.

## Production restructure (done 2026-10-23)
Prototype features were rewritten into the main project (`src/`, `data/`), split into small classes. See `docs/project-structure.md`.
- Main scene: `res://src/gameplay/game/game.tscn`. Autoloads: GameEvents, InputSetup, GameSession.
- Same features as prototype iteration 2 (Lancer, chain, Critical Break, 3 bosses with parts), all GDScript.
- NOT yet run in Godot by Claude. The user must open the project and press F5, and report errors.
- Unit test: `tests/unit/test_chain_tracker.gd`.

## Doc status
- Done: game concept (`design/gdd/game-concept.md`), tech prefs, engine reference, project structure.
- Done: art bible `design/art/art-bible.md` (all 9 sections, 2026-10-28). Key locked choices: reserved top HUD strip (48 px 1-2P / 72 px 3-4P at 360x640, boss bar inside it); 1 px outline on all text via hybrid method (pre-outlined digit atlas + outline font variant); smooth chain bar + red end-cap; HUD numerals follow chosen language; in-fight HUD icons/numerals only; 240x320 base (SUPERSEDED 2026-10-31, see below); one MultiMesh bullet atlas; 2048 max atlas; 96 MB VRAM target (was 64). References = the 4 games only (user dropped the Bengali lettering 5th ref). §8.9 lists 4 Web spikes (MultiMesh 2000 bullets, Bengali conjuncts, display setting names, shaders/particles).
- NOT done: system GDDs (/map-systems, /design-system), architecture doc / ADRs.
- **2026-10-31 resolution change:** canvas is now **360x640 (9:16)** pixel art, x4 = 1440x2560 (user wanted 1440p, chose to keep pixel art). All art bible pixel sizes rescaled 1.5x (line widths unchanged). New §8.1.1: fixed canvas on every device, extra area = bezel art, scaling modes Auto/Pixel Perfect/Fill (sharp-bilinear), safe areas, portrait-only phones, TATE mode, device table (iPhone X+, Galaxy S20+, Switch/Switch 2, PC, Steam Deck). Platforms now include iOS, Android, Switch. VRAM budget raised to 96/128 MB (proposal). Backup of old bible in that session's scratchpad only.
- Code follow-up: `src/` is still 480x640. Moving to 360x640 needs a gameplay retune (boss anchors/sway in `data/bosses/*.tres`, play_area in game/player/bullet_manager, HUD offsets) plus a display scaler for Auto/Fill + bezel. Not started.
- Open: Switch needs a third-party console port (W4 Games etc.); Godot mobile C# is experimental — affects the language-split ADR. Touch controls need a UX spec.

## Next steps
1. User playtests iteration 2 → report errors or feedback (which boss best, parts-first vs rush core, is immune core fun).
2. Phase 6 debrief questions (one at a time): hypothesis result, best moment, worst moment, surprise, PROCEED/PIVOT/KILL.
3. Write `prototypes/boss-chain-concept/REPORT.md` + `prototypes/index.md` (template `.claude/docs/templates/prototype-report.md` does not exist — structure by hand).
4. Then: `/art-bible` → `/map-systems` → `/design-system` (boss-parts system worth its own GDD).

## Open questions
- Bomb design per plane · exact Critical Break formula / Life Damage Bonus · co-op lives/continues · final title
- Language split (proposal: bullets in C#, rest GDScript) — decide via ADR


## 2026-11-02 - Systems decomposition
- Wrote `design/gdd/systems-index.md` (32 systems, 25 MVP, design order set). Lean mode: director gates skipped.
- New decisions: boss mechanics foreshadowed one per wave (wave N previews mechanic N); powerups = temp shot upgrade + chain pickup + medals/1-ups (no stat grinding).
- Godot 4.7.2 is at `D:\Unreal Engine\GodotEngine\Godot_v4.7.2-stable_win64_console.exe` (headless import ran clean, no script errors).
- User said prototype iteration 2 "has issues" but never gave details - ask.
- GDD rule: every GDD needs 8 sections (Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria), written one section at a time with approval.
- Next: `/design-system bullet-manager` (first in design order).

## Current task (2026-11-02)
- Bullet manager GDD paused: user chose to design dependency first. Context gathered (see engine finding: official 4.7 has NO C# Web export, noted in docs/engine-reference/godot/current-best-practices.md).
- Task: Designing game-events-and-session GDD
- File: design/gdd/game-events-and-session.md
- Sections done: Overview, Player Fantasy, Detailed Design, Formulas (drones added; concept 5 + index revised: powerup = +1 drone max 4, MVP = Lancer + Leech). Edge Cases done. Dependencies done. Tuning Knobs done. Acceptance Criteria (35) + Open Questions done, 8 qa gap fixes applied. Next: optional Visual/Audio + UI, then wrap-up.
- DONE: game-events-and-session GDD complete (all sections, status Designed pending review). Registry created at design/registry/entities.yaml. Systems index row 1 = Designed.
- Next: resume `/design-system bullet-manager` (was paused); user should run `/design-review design/gdd/game-events-and-session.md` in a FRESH session.
<!-- CONSISTENCY-CHECK: 2026-11-02 | GDDs checked: 1 (+concept) | Conflicts found: 0 | 2 notes: F2 extends_reached still float-division; concept 3 line 37 stale (drones on Fire hold) -->
- Consistency notes fixed (F2 integer form, concept 3 Drone button). Next: resume /design-system bullet-manager.

## Current task (2026-11-02, cont.)
- Task: Designing bullet-manager GDD
- File: design/gdd/bullet-manager.md
- Sections done: Overview, Player Fantasy, Detailed Design (two pools, cancel->score items, circle hits, target at spawn). Formulas done (ring=solid circle r2, swept+480 cap, keep speeds, BM owns hit tests). Edge Cases done. Dependencies done (+ session GDD row added). Tuning Knobs done. Acceptance Criteria (47) + Open Questions done, qa fixes applied (cancel beats hit; phones 30 fps render). Next: optional Visual/Audio + UI, wrap-up.
- DONE: bullet-manager GDD complete (status Designed pending review). Registry +12 entries. Index row 3 = Designed.
- Key decisions: two pools; cancel->score items; circle hits (ring = solid centre + 3 px pip); swept test + 480 cap; tick order spawn>age>move>cancel>hit>remove (cancel beats hit); phones render 30 fps; hitbox dot drawn at 6 px; shot opacity 100/75/50 by player count; play_top under HUD.
- Pending: art bible amendments (bullet GDD Open Q8); language ADR gated by bullet perf ACs 39-44.
- Next: run /design-review on both GDDs in a FRESH session; next GDD in order = Player plane (5).

## Current task (2026-11-02, cont.)
- Task: Designing player-plane GDD (scope: movement, speed modes, bounds, hitbox, look, input hand-off to kit; chain/score/lives/bombs/CB moved out)
- File: design/gdd/player-plane.md
- Sections done: Overview, Player Fantasy, Detailed Design (8-way digital, fixed wing slots, fly-in respawn, pass-through). Formulas done (210/105, drones off-screen ok, column start spots; bullet GDD numbers updated). Edge Cases done. Dependencies done. Tuning Knobs done. Acceptance Criteria (37) done, qa fixes applied. Next: Visual/Audio (required, art-director), UI, Open Questions, wrap-up.
- DONE: player-plane GDD complete (status Designed pending review). Registry: move_speed 210, focus_speed 105, hitbox owner moved. Index row 5 = Designed.
- Key decisions: 8-way digital no inertia; speeds 210/105 (crossing 1.71 s); fixed rigid wing slots (drones may go off-screen); fly-in from bottom 0.6 s; death 0.6 s; column start spots; pass-through co-op; 10 fps hide blink kept (dot/ring/pips never blink); drones 100% opacity; stepped banking; Lancer lens-pod drone, Leech hook-claw drone.
- Pending art bible update list: bullet GDD Open Q8 + plane GDD Open Q2.
- Next in design order: Collision, damage and lives (6). Run /design-review on the 3 GDDs in a FRESH session.

## Current task (2026-11-02, cont.)
- Task: Designing collision-damage-lives GDD. Decisions: on hit clear WHOLE screen (no items), drop that player's chain, drones 0; ALL enemy bodies kill on contact; Collision owns one invulnerability timer per slot (respawn/bomb/laser request time).
- File: design/gdd/collision-damage-lives.md
- Sections done: Overview, Player Fantasy, Detailed Design (invuln = max, every tick counts, invuln passes bodies, armoured hits count). Formulas done (capsule bodies, integer hp, armoured cannot die (hp floor 1), kill credit rotates by tick, Phase A damage before Phase B player hits, respawn_invuln 120 t, laser_exit_grace 12 t). Edge Cases done (deathbomb = same tick only; body spawn overlap kills, spawners keep r_pl+r_e+8 clear; mode snapshot per tick). Dependencies done (overkill does NOT count -> amend BM line ~300; BM gets clear-enemy-pool-no-items request; index: 6 upstream of 7, 8, 13; close plane Open Q7). Amendments pending at wrap-up. Tuning Knobs done. Visual/Audio done (death_fire_hold 30 t added to knobs + deps; death ring required; hit tint throttles). UI done (no own UI). Acceptance Criteria done (53; gaps fixed: spawn_is_clear helper, hold timing, first hittable = Active+120, ghost shots no chain, 0.5 ms budget). Next: Open Questions, wrap-up (registry, BM/PP/index amendments, index status).
- DONE: collision-damage-lives GDD complete (all 12 sections, 53 ACs, status Designed pending review; CD-GDD-ALIGN skipped lean). Registry +5 constants (respawn_invuln 120, laser_exit_grace 12, death_fire_hold 30, armour_damage_min 20, spawn_clearance 8) +2 formulas (body_contact, armour_damage). BM amended (Rule 15a enemy-pool clear no items; overkill not counted). PP amended (Open Q7 closed; V7 death ring required).
- Key decisions: capsule bodies; integer hp; armoured cannot die (hp floor 1); kill credit rotates by tick; Phase A damage before Phase B player hits (kill saves from ram); deathbomb same tick only; body spawn overlap kills (spawn_is_clear helper); death_fire_hold 30 t; ghost shots damage but no chain_hit; collision budget 0.5 ms p99.
- DONE: systems index updated (row 6 Designed + link; 6 added to deps of 7, 8, 13; GDD count 4).
- Pending art bible list: + hit-tint throttle (AB 5.10), crack-through-seams (AB 5.8).
- Next in design order: Chain tracker (7). Run /design-review on the 4 GDDs in a FRESH session.
<!-- CONSISTENCY-CHECK: 2026-11-02 | GDDs checked: 4 | Conflicts found: 0 | 2 info notes: 'invulnerable' listed as a slot state in BM/Session deps (now Collision-owned flag); Session F-output says 'deaths subtracted by system 6' vs Collision sends lives_decrement request | Report: not saved; both notes fixed -->

## 2026-11-02 - ADR-0001
- Wrote docs/architecture/adr-0001-gdscript-bullets-multimesh.md (Proposed; Accepted when bench V1 passes). GDScript only, no C#; packed arrays + MultiMesh; node-free RefCounted logic; GameLoop 60 Hz, no interpolation; budgets: bullet tick <=1.5 ms p99 REF-WEB to accept (hard 2.5), collision 0.5, pack 1.0/frame; REF-PC/WEB/PHONE defined. Fallback = C++ GDExtension kernel via ADR-0002 if V1 > 3.0 ms.
- Updated CLAUDE.md, technical-preferences (GDScript only + Forbidden Patterns), project-structure. Created docs/registry/architecture.yaml.
- Next: /design-system chain-tracker. Later: bullet_bench spike (V1), core-architecture ADR. Run /architecture-review in a FRESH session.

## Current task (2026-11-02, cont.)
- Task: Designing chain-tracker GDD
- File: design/gdd/chain-tracker.md
- Sections done: Overview (scope: window/count/drop/max, bonus adds, CB multiply, Team Chain detection). Player Fantasy (direct; anchor = keeping it alive on the boss). Detailed Design (boss record = peak while alive; team chain excludes non-Active; cap 999; freeze-record-drop at stage end; amendments pending: Collision chain_hit(slot,on_boss), Session rule 9). Formulas done (W=60, fresh-skip, team_window 60, x3+50, milestones every crossed, bar ceil + art bible reword pending, cap reachable ~4.5 s flag for 8/17). Edge Cases done (CB at 0 -> 50). Dependencies done (amendments pending: Collision chain_hit on_boss, Session rule 9, art bible 7.3 bar wording). Tuning Knobs done. Acceptance Criteria done (51; gap fixes: own team timer survives EXPIRED, non-Active hit ignored, in-play = Active >=1 fight tick, freeze beats expiry, multi-boss, ghost_visible). Next: V/A, UI, Open Q, wrap-up.
- DONE (2026-11-03): chain-tracker GDD complete (12 sections, 51 ACs, Designed pending review; CD skipped lean). Registry +6 constants (chain_window 60, team_window 60, chain_cap 999, cb_mult 3, cb_add 50, part_kill_chain 5) +2 formulas. Amended: Collision chain_hit(slot, on_boss); Session rule 9 (chains drop at tally start); art bible 7.3 bar step wording. Index row 7 Designed, GDD count 5.
- Next in design order: Scoring (8). Run /design-review on the 5 GDDs in a FRESH session; /architecture-review fresh too.
<!-- CONSISTENCY-CHECK: 2026-11-03 | GDDs checked: 5 | Conflicts found: 0 | 1 info note: Session tuning row respawn_delay 'chain window always lapses' is moot (death drops the chain) | Report: not saved; note fixed -->

## Next session (saved 2026-11-03)
- Resume with: `/design-system scoring` (no skeleton yet; context already gathered: Session extend_unit placeholder 1,000,000 must be supplied by Scoring; Collision kill credit on destroyed; Chain count after each hit, cap 999 reachable ~4.5 s; Team Chain bonus value owned by Scoring/Co-op; BM cancel items -> Powerups 13; prototype hit 10+chain, part kill 2000, CB final_chain*100 + 5000/life).
- Also pending: /design-review on the 5 GDDs (fresh session each), /architecture-review (fresh), bullet benchmark spike (ADR-0001 V1).

## Current task (2026-11-03, scoring)
- Task: Designing scoring GDD
- Sections done: Overview (chain-first ranking), Player Fantasy (direct; anchor = Critical Break leap). Detailed Design done (sources S1-S9: hit linear base+count, kills, part/boss kill, CB+life bonus, items scale w/ chain, stage-end bonuses, team chain = multiplier on S1; amendments pending: Chain hit_counted event, Collision kill_credit class). Formulas done (F1 hit ((10+count)*team_pct+50)/100, team 120; F2 kills 200/1k/5k, part 5k, boss 100k; F3 items gem 100/medal 1k x (1+min(c,500)/50); F4 CB = 1000 x uncapped before*3+50, LDB 50k x (lives-1); F5 stage end 100k/200k/50k per life/1k per peak; F6 cap-hold streak 500 x min(s,30)/s (S10 added); F7 extend_unit 3M (0.8/1.0 kept); F8 9-digit display). Rule 6 + S5 updated. Edge Cases done (team state from T-1; S4 to Alive/Dead at boss_defeated; Continue gets no S4/S8; no-death needs Alive from stage_started; frozen resets cap streak; items_per_cancel_cap 100 owned by Powerups). Dependencies done (5 amendments pending at wrap-up: Chain hit_counted + close OQ1; Collision kill_credit class; Session extend_unit 3M + add_score + close OQ5; index 8 deps 1,6,7; registry extend_unit). Tuning Knobs done (17 knobs + health check: chain share >=70% competent, >=90% expert). Acceptance Criteria done (57; tally events ignored, strict chain share 65/90, 0.10 ms p99, PART/CORE classes). V/A, UI, Open Questions done.
- File: design/gdd/scoring.md
- DONE (2026-11-03, autonomous wrap-up at user request): scoring GDD complete (12 sections, 57 ACs, Designed pending review; CD skipped lean). Registry: extend_unit 3,000,000 + 8 scoring constants + 4 formulas; chain_cap/cb_mult/cb_add referenced_by scoring. Amended: Chain Rule 14 hit_counted event + OQ1 closed; Collision kill_credit(slot, class) SMALL/MEDIUM/LARGE/PART/CORE; Session extend_unit 3M (OQ5 closed), add_score, life_bonus_total = points. Index row 8 Designed, deps 1,6,7, GDD count 6.
- Key decisions: chain-first; hit ((10+count)*team_pct+50)/100, team 120; kills 200/1k/5k, part 5k, boss 100k to each eligible slot; items gem 100/medal 1k x (1+min(c,500)/50); CB 1000 x uncapped before*3+50, LDB 50k x (lives-1); stage end 100k/200k/50k per life/1k per peak; cap-hold streak 500 x min(s,30)/s; extend_unit 3M; 9-digit display; tally ignores late events; strict chain share >=65%/>=90%; 0.10 ms p99.
- Next: run /consistency-check; /design-review design/gdd/scoring.md in a FRESH session; next GDD in order = Bullet pattern library (9).
<!-- CONSISTENCY-CHECK: 2026-11-03 | GDDs checked: 6 | Conflicts found: 0 | 2 info notes: Session AC defaults called extend_unit 1M a "placeholder" (reworded as test parameter); registry part_kill_chain referenced_by +scoring | Report: not saved; both notes fixed -->

## Current task (2026-11-03, bullet pattern library)
- Task: Designing bullet-pattern-library GDD
- File: design/gdd/bullet-pattern-library.md
- Sections done: Overview (both framing, ADR-0001 cited, generic intensity 0-1 replaces rage; owner of intensity = user system). Player Fantasy (direct; anchor = reading the gap; every pattern has an answer, learnable, seeded randomness in limits). Detailed Design (stack on emitter; per-runner state; int ticks; intensity gate+scale read per burst; fire hold skips volleys, timers run; per-emitter target rotation per burst, Alive only, none -> down + slot 0; aim once per burst, reaim flag, aim lock; spawn_safe_radius skip bullet; per-emitter seeded stream; catalogue 7: fan, ring, spiral, wall, radial curve, flak burst, seeded spray; one-time x0.75 data migration). Formulas done (F1 ticks + minimums; F2 burst timing, overlap pushes later; F3 intensity lerp+roundi, gate inclusive eps; F4 rotation, lock-tick targeting; F5 aim, lock/reaim exclusive; F6 geometry a-g, spiral from counter, wall V set, flak standoff 56/dist 240/delay 36, spray jitter 0.5; F7 spawn_safe_radius 42 + override; F8 validator lane_min_clear 14; F9 density 450/runner, 1700/scene; F10 migration closes BM OQ4, jet fan 50->70). Rules 10, 14 amended. Pending at wrap-up: BM OQ4 close + F0 wording; registry spawn_safe_radius 42, lane_min_clear 14. Edge Cases done (skipped volleys still draw RNG; fuse in hold is used up; lock_ended fired=false; FlyIn targetable not safety; owner destroyed cancels fuses; same-tick order emitter reg > list > index). Dependencies done (upstream 3, 1, 6, 5; downstream 10, 14, 19, 16, 24, 25; 5 amendments pending at wrap-up: BM row+F0+close OQ4, Collision hold names 9, Session row 9, PP row 9 + line 114 fix, index deps 1,3,5,6). Tuning Knobs done (global pattern_rules.tres: safe 42, t_react 9, lane 14, d_ref 160, D_lane 120, corridor warn 20, E 8, runner warn 450, flak inset 12; per-pattern table; lock 0 or 18-60). V/A done (art-director; muzzle flash 6 t, lock line+reticle in target colour, flak smoke puff+spark, era language table, audio cues; AB amendments pending: combat tell category, ring colour on lock lines, alert amber, particle budget). UI done (none; debug overlay). AUTO-APPROVE from 2026-11-03 (user). Amendments to BM/Collision/Session/PP applied. Next: Acceptance Criteria (qa-lead running), Open Questions, wrap-up (registry, index).
- Context: existing code src/gameplay/bullets/patterns/ (6 patterns) breaks ADR-0001 (float delta cooldowns, global randf, single target, old Kind enum); rage gating may belong to Boss (14). BM hands over: x0.75 spacing retune (BM OQ4), target-slot rule, spawn points clear of players, peak <= 1700.

## Auto-approve batch (2026-11-03)
- User: "auto approve from now ... get all things that are left (sound, environments etc.)". Memory saved (auto-approve-design).
- Brief for agents: production/gdd-authoring-brief.md (agents write only their own GDD; main session applies amendments, registry, index).
- Pattern library (9): all sections except ACs written; qa-lead drafting ACs. Registry + index row 9 + amendments to BM/Collision/Session/PP done.
- Wave 1 running: Enemy (10) enemy-and-ai.md, Co-op (18) coop-and-team-chain.md, Input (2) input-and-player-mapping.md, Display scaler (4) display-scaler-and-bezel.md, Save (26) save-settings-high-scores.md, Localization (27) localization.md.
- Planned waves: 2 = Plane kits (11), Boss (14); 3 = Bombs (12), Powerups (13), Boss power budget (15), Critical Break (17); 4 = Wave director (16), Era shift (19); 5 = HUD (20), Tally (21), Menus (22), Parallax (23), Audio (24), VFX (25), Accessibility (28). Then Target/Full (29-32) if time.
- After each report: apply amendments, registry, index; run consistency check at the end.
- 2026-11-03: Pattern library (9) COMPLETE (12 sections, 61 ACs, qa gaps fixed: stable-id seeds, flak timing, merged fortress spiral arms 2, lock edge cases, validator rows). Open Q10: ADR-0001 needs pattern-tick budget row (0.2 ms p99).
- Reports now saved to production/gdd-reports/<slug>.md; plan: one "applier" agent per wave applies amendments + registry + index from those reports.
- Wave 1 done so far: localization.md, save-settings-high-scores.md (reports being saved).
- Wave 1 COMPLETE (6 GDDs): localization, save-settings-high-scores, coop-and-team-chain, input-and-player-mapping, display-scaler-and-bezel, enemy-and-ai. Reports in production/gdd-reports/.
- Conflict resolved: coop hp scaling = Co-op's 50%/extra player (Enemy's 60% overridden).
- Running: applier for wave 1 (log -> production/gdd-reports/_applied-wave-1.md); Plane kits (11); Boss (14).
- Next wave after Boss + Kits: Bombs (12), Powerups (13), Boss power budget (15), Critical Break (17).
- Wave-1 applier done (log _applied-wave-1.md); fixing 6 follow-up inconsistencies.
- Plane kits (11) DONE. Conflict: Scoring F7 hit-count budget > kit max (72 hits/s) -> decision: re-baseline Scoring F7 (~2,700 competent / 3,600 expert boss hits); check extend_unit 3M still fits, flag if not.
- Running: Boss (14), Bombs (12), Powerups (13). Then Boss power budget (15), Critical Break (17), wave-2 applier (kits, boss, bombs, powerups).
- Boss (14) DONE. Conflict: Enemy/Boss hp used provisional ref_dps 300, but Kits DPS ~1,100 (4 drones) -> balance reconcile agent (systems-designer) rescaling Enemy/Boss hp + Scoring F7 to Kits-owned ref DPS (log _balance-reconcile-1.md); extend_unit 3M must stay.
- Running: balance reconcile, Bombs (12), Powerups (13), Boss power budget (15), wave-1 applier follow-up fixes.
- Next: Critical Break (17) after Bombs; then wave-2 applier (kits, boss, bombs, powerups, power budget, CB) AFTER balance reconcile finishes (same files).
- Powerups (13) DONE. Balance reconcile DONE (_balance-reconcile-1.md): ref_dps 800 (Kits, 2 drones); enemy hp x8/3; boss hp rescaled (fights 45-55 s kept); Scoring F7 re-baselined, peak_value 1000->1300, competent 2.99M, chain share 71/94%. Leftover: powerups F9 recompute vs new totals (wave-2 applier).
- Bombs (12), Boss power budget (15) DONE. Running: Wave director (16), Critical Break (17), wave-1 applier follow-up (maybe done).
- Wave-2 applier pending: reports plane-kits, boss, powerups, bombs, boss-power-budget (+ CB, wave director when done). Balance already applied; leftover powerups F9 recompute.
- Wave-1 follow-up fixes DONE. Running: wave-2 applier (kits, boss, powerups, bombs, power budget -> _applied-wave-2.md), Wave director (16), Critical Break (17), HUD (20), Stage tally (21), Menus (22).
- Remaining to launch: Era shift (19, after 16), Parallax/environments (23, after 16), Audio (24), VFX (25), Accessibility (28, after 20/22). Then wave-3 applier + full /consistency-check.
- Critical Break (17) DONE. Running: Wave director (16), HUD (20), Tally (21), Menus (22), Audio (24), VFX (25), wave-2 applier follow-up fixes.
- Remaining: Era shift (19) + Parallax (23) after 16; Accessibility (28) after 20/22; wave-3 applier (CB, 16, 19-25, 28); full consistency check; then summary to user.
- Tally (21), Menus (22), Wave director (16) DONE. Running: HUD (20), Audio (24), VFX (25), Era shift (19), Parallax (23), wave-2 applier follow-up. Then Accessibility (28) after HUD; wave-3 applier (CB, 16, 19-25, 28); consistency check.
- HUD (20), Audio (24), VFX (25) DONE. Running: Era shift (19), Parallax (23), Accessibility (28), wave-2 applier follow-up. Then wave-3 applier (CB, 16, 19-25, 28) + consistency check.
- ALL MVP + VS GDDs WRITTEN (28 systems; 30 GDD files total incl. pattern library etc.). Era shift (19), Parallax (23), Accessibility (28) done.
- Running: wave-3a applier (CB, 16, 21, 22, 20 -> _applied-wave-3a.md); Target/Full GDDs: Sentry/Breaker (29), Tutorial (30), Touch (31), Leaderboards+boss rush (32).
- Next: wave-3b applier (audio, vfx, era-shift, parallax, accessibility) AFTER 3a; then wave-4 applier (29-32); then full consistency check; then user summary.
- Wave 3a + 3b appliers DONE (logs _applied-wave-3a.md, _applied-wave-3b.md). Registry 233 entries. Tutorial (30), Touch (31), Leaderboards (32) DONE. Sentry/Breaker (29) running.
- Pending decisions for wave-4 applier: chain_cue_audio default ON; era card may use layer 11 (no bullets during transition); play_top latched at wave_started/stage_started (HUD layout follows latched play_top; mid-boss drop-in keeps 48 until next stage); flak fuses max 8 lit per scene (validator + runtime skip); TATE confirm uses UI tick sound; fix stale rows in leaderboards GDD.
- ALL 32 GDDs WRITTEN (Sentry/Breaker 29 done). Running: wave-4 applier (29-32 + 6 decisions -> _applied-wave-4.md). Next: full /consistency-check, then final summary to user (review in fresh sessions: /design-review per GDD, /review-all-gdds, /architecture-review).
- 2026-11-03 END OF SESSION: all 32 GDDs Designed (pending review); wave-4 applier DONE (_applied-wave-4.md). Usage limit hit before the final consistency check.
- NEXT: run /consistency-check (fresh session); fix wave-4 leftovers (merge BM cancel_report structs; compact 2P HUD column rects; sound IDs for tutorial/Sentry-Breaker/online; touch provisional names; touch key prefix clash; Menus boss rush/touch prose); confirm invented items (RunRecord.touch, start_run signature, ui_touch.csv, Sentry/Breaker wing offsets); then /design-review per GDD and /review-all-gdds in fresh sessions; ADRs listed in _applied-wave-4.md.
- Running: consistency check + leftovers (-> docs/consistency-report-2026-11-03.md); ADR-0002..0005 (core runtime, owns docs/registry/architecture.yaml); ADR-0006..0009 (flash, online, touch, Bengali shaping; registry entries returned to main session).

<!-- CONSISTENCY-CHECK: 2026-11-03 | GDDs checked: 32 | Conflicts found: 7 | Report: docs/consistency-report-2026-11-03.md -->

## Status (2026-11-03, end of autonomous batch)
- DONE: 32/32 GDDs Designed (pending review); consistency check PASS (docs/consistency-report-2026-11-03.md, 7 conflicts fixed); ADR-0002..0009 written (Proposed), architecture registry updated; ADR-driven GDD edits applied (_applied-adr-amendments.md).
- USER DECISION NEEDED: GodotSteam GDExtension exception to "GDScript only" (ADR-0007) — CLAUDE.md not edited.
- NEXT (fresh sessions): /design-review per GDD, /review-all-gdds, /architecture-review; spikes: bullet bench (ADR-0001 V1), whole-game REF-WEB bench, cross-platform replay math, display presenter, Web Bengali shaping, Web audio, touch; sign-offs: art-director (Breaker brackets, alert amber, combat tells), audio-director (sound IDs), UX (/ux-design for HUD, menus, tally, touch), lead-programmer (start_run, cancel_report cost). Then /gate-check pre-production.
- 2026-11-03: user APPROVED GodotSteam exception; CLAUDE.md + technical-preferences updated.

## 2026-11-03 - UX pattern library
- DONE: design/ux/interaction-patterns.md written (24 patterns P01-P24, 8 gaps, 6 open questions). Status Draft, auto-approved, NOT yet /ux-review'd. Condensed from Menus/Input/Touch/Accessibility GDDs; P15-P18 only skimmed.
- No design/player-journey.md or design/accessibility-requirements.md exists (accessibility tier undecided).
- Next: /ux-design for main-menu, hud (GDD hud.md already has wireframes), stage-end-tally; then /ux-review each; /gate-check pre-production.

## 2026-11-03 - UX main-menu
- DONE: design/ux/main-menu.md (Title + Play choice), 14 ACs, 9 open questions. Draft, auto-approved, NOT /ux-review'd.
- Found: with Flight School the Title list is 6 items (212 px from y392 -> ends y604) and overlaps the prompt bar at y600; GDD only sizes 5. Needs art-director ruling.
- Next: /ux-design lobby, stage-end-tally (hud.md GDD already has wireframes); then /ux-review each.

## 2026-11-03 - UX lobby
- DONE: design/ux/lobby.md (plane select + co-op join), 16 ACs, 10 open questions. Draft, auto-approved, NOT /ux-review'd.
- Found: 4-plane cards are 76 px wide (Target, Sentry/Breaker) and cannot hold 3 trait rows + tagline + tag, esp. Bengali; Touch lobby shows unusable join plates for slots 1-3; untimed_menus coverage of Lobby timers unspecified.
- Specs so far: interaction-patterns, main-menu, lobby. Next: stage-end-tally, pause/disconnect, results+name entry, high-scores, settings; then /ux-review each.

## 2026-11-03 - UX pause
- DONE: design/ux/pause.md (pause menu, disconnect overlay, resume beat), 15 ACs, 10 open questions. Draft, auto-approved, NOT /ux-review'd.
- Found: (1) Start-held-to-confirm vs Start=Resume conflict (Menus F6 vs Rule 28); (2) 216x192 pause plate cannot hold tip row + Bengali wraps; (3) disconnect overlay with 3-4 Waiting slots won't fit; (4) disconnect/tip strings missing from string table; (5) art-bible exception for panel over frozen field still pending.
- Specs so far: interaction-patterns, main-menu, lobby, pause. Next: stage-end-tally, results+name-entry, high-scores, settings; then /ux-review each.

## 2026-11-03 - UX stage-tally
- DONE: design/ux/stage-tally.md (named per Tally GDD UX Flag, not stage-end-tally.md), 16 ACs, 10 open questions. Draft, auto-approved, NOT /ux-review'd.
- Found: touch auto-fire pulse must not count as a skip press (Touch/Tally GDDs silent); pointer-only players can't skip; tip row and 1P prompt have no y-budget (1P prompt labelled y576-632 but 24 px tall); fixed grid blocks text enlargement; reduce_motion undefined for tally.
- Specs so far: interaction-patterns, main-menu, lobby, pause, stage-tally. Next: results+name-entry, high-scores, settings (+hud if wanted); then /ux-review each; /gate-check pre-production.

## 2026-11-03 - UX design complete (all screens, drafts)
- User decisions: arcade (DoDonPachi-tradition, original) UI feel; menus stay SINGLE-language with chip (dual-script only title, banners, tally labels, Web gate, first-run plate, TATE confirm title); goal today = finish all UX design.
- design/ux/: arcade-ui-style.md (new style guide), interaction-patterns.md (P01-P28 + Back table + animation/sound standards), main-menu, lobby, pause, stage-tally (all revised after /ux-review), hud, results-name-entry, high-scores, settings, flight-school (Target), credits. Also design/accessibility-requirements.md (tier COMPREHENSIVE) and design/player-journey.md.
- Decided under auto-approve (need GDD amendments): hold-to-confirm = Fire only on Pause (Menus F6); Pause plate bottom-anchored y420, grows up (Menus V/A); Tally tip band y600-640 + fit rule, defer to Pause (Tally 1a, Tutorial 27); tally skip ignores auto-fire pulse (Tally 15); TATE title dual-script.
- Open conflicts for GDD owners (see each spec's Open Questions): 3-4P Results column too narrow for 9 digits; no 4P name-wheel layout; co-op rank shown per row vs one team rank; Save "ranked if >=1" vs Online "top 10"; MISSION COMPLETE vs ALL CLEAR wording; Stretch tab strip (6 tabs) too wide; unknown-plane entries unreachable; reset_settings resets first_run_prompt and language; display_reset 2 s vs 60 ticks; HUD victory portrait unreachable; continue timer access variants vs HUD HF2; strip-mark clipping; 4-plane 76 px lobby cards; touch Lobby lock flow.
- NOT yet run: /ux-review on the 7 new docs. Next: /ux-review all (fresh session), then GDD amendment pass, then /gate-check pre-production.

## 2026-11-03 (cont.) - UX review pass
- Brief written: `production/ux-review-brief.md` (checklist + cross-ref context + hard rule: each agent edits only its own UX doc; cross-doc amendments go to its report).
- Reports go to `production/ux-reports/<slug>.md`.
- Running 7 parallel /ux-review agents (each fixes its own file): hud, settings, results-name-entry, high-scores, flight-school, credits, arcade-ui-style.
- Already reviewed+revised earlier today (not in this batch): interaction-patterns, main-menu, lobby, pause, stage-tally.
- Next after reports: apply cross-document amendments centrally (GDDs, art bible, registry, systems index), then /gate-check pre-production.
- UX review results: 6/7 back, all NEEDS REVISION -> APPROVED (with open questions) after in-file fixes. hud (15 fixes), results-name-entry (15), high-scores (12), credits (12), arcade-ui-style (12), flight-school (12 groups). settings still running (resumed after turn limit).
- Decisions made under auto-approve: (1) online scope = GDD wins, Switch/mobile ship no adapter + no Online tab, ADR-0007 reworded; (2) main-menu list top y372 with Flight School present (6 items end y584), y392 for 5; (3) arcade-ui-style owns animation+sound STANDARDS tables, audio GDD owns sound IDs, pattern library cites both; (4) Alarm Red (3.95:1) = plate edge/glyph fill only, never bare text, failure needs glyph+words.
- Applier batch 1 running -> production/gdd-reports/_applied-ux-amendments-1.md. Allowlist excludes settings.md + the GDDs the settings agent is reading (accessibility-options, save-settings, input, display-scaler, audio, localization); those amendments are deferred to batch 2.
- Batch 2 (after settings returns): apply deferred amendments + settings' own cross-doc amendments.
- Then: full /consistency-check, then /gate-check pre-production.
- settings (20) UX review DONE: 13 blocking -> APPROVED WITH CONDITIONS, 18 fixes. ALL 7/7 UX reviews now complete (~96 in-file fixes, ~45 cross-doc amendments).
- settings conflicts resolved: no tab strip in Settings (6-tab strip is high-scores' problem); reset_settings = keep-list (A1); display_reset split into Reset-display button (confirm_hold 60 t) vs display_reset hotkey (2 s real-time) (A2).
- settings amendments A1-A5 go to batch 2 (A2/A4 touch menus + interaction-patterns, which batch 1 owns -> must wait for batch 1).
- Applier batch 1 DONE (_applied-ux-amendments-1.md): 28 amendments applied across 13 files, 16 deferred (D1-D16 with exact text), 1 not applied (Bengali for 14 new Menus keys - needs native review). P29 = Status block, P30 = single-button modal over stopped field (Coach card).
- Decisions made: tutorial required_mask = PER-PLANE (Sentry/Breaker-only profiles can reach complete, no new drills); CONTINUE_ACCEPT = Fire only (Start stays Pause in gameplay); Alarm Red stays barred as text fill (no new hex invented).
- STILL NEEDS ART-DIRECTOR: lighter Alarm Red text variant (new palette hex); DONE/SKIPPED stamp rect (no rect in any HudLayout, layout lint cannot check it).
- STILL NEEDS LOCALIZATION LEAD: Bengali for 14 new Menus string keys (+ all other draft bn strings).
- Applier batch 2 running -> _applied-ux-amendments-2.md (D1-D16 + settings A1-A5; D1 first = Save Rule 5 top-board_size, else not-placed runs reach Name entry).
- Then: full /consistency-check, then /gate-check pre-production.
- Applier batch 2 DONE (_applied-ux-amendments-2.md): 21/21 items (D1-D16 + A1-A5) = 49 edits across 21 files, 0 not applied. D1 landed FIRST (Save Rule 5 now requires rank_index < board_size; preview_rank returns 'not placed'; not-placed run asks no initials, stores nothing; new AC-03a). 9 OQs closed, 2 narrowed. Also fixed 5 stale cb_banner_wait_max refs in critical-break.md.
- Decided: nav_group_prev/next = KEEP SUPPRESSION RULE, no new menu verbs.
- Still open (not guesses, need real input): 2 Localization F3 font-spike measurements (D10 plate width at 9 digits + INDIAN grouping 81px vs D12 budget); which events Sentry/Breaker kits publish (Kits 29, Target tier); accepted tutorial.complete OR-over-planes looseness; Bengali strings pending native review.
- Running: art-director (Alarm Red text token + DONE/SKIPPED stamp rect -> production/ux-reports/_art-director-decisions.md; owns art-bible.md, arcade-ui-style.md, design/ux/hud.md); consistency check scoped to the UX pass (-> docs/consistency-report-2026-11-03-ux.md; report-only on those 3 files).
- Then: /gate-check pre-production.
- Art-director decisions DONE (production/ux-reports/_art-director-decisions.md):
  - ALARM FLARE #F2494D = text-only red, 4.76:1 on Char (computed, needs renderer re-measure). Same hue as #E03A3E (358.6 deg). #E03A3E stays edge/fill/glyph red, never text. Flare: one headline line per screen + Cream sentence + error glyph; renders Cream under HIGH contrast; barred from HUD strip, slot columns, near P1 pips/rings, play field. CAVEAT: Flare NOT luma-distinct from P1 (13.3 vs 30.9 min) - mitigated by keeping it away from P1. CAVEAT: protanopia likely drops below 4.76, unmeasured.
  - DONE/SKIPPED stamp = 16x11 asset. 1P (48px): (224,4,16,11). 3-4P (72px): (73,16,16,11) per column (abs x 73/163/253/343). 2P + Compact 48: SUPPRESSED, no room (largest free block 31x6). Consequence: 2P co-op Flight School needs per-slot DONE on the drill surface itself.
  - Edited: art-bible 4.1/7.8/7.10, arcade-ui-style (OQ2 closed), design/ux/hud.md (OQ21 closed).
- PENDING (main session to apply after consistency check): art-director's 5 amendments - (1) gdd/hud.md Rule 30b stamp rects + AC-03 lint clause + new AC; (2) tutorial/flight-school per-slot DONE in 2P + Compact 48; (3) accessibility-requirements.md line 96 exception to "7:1 on menus" for the single Flare headline (ELSE new token contradicts COMPREHENSIVE tier); (4) registry/HudTheme ALARM_FLARE = #F2494D text-only; (5) optional reword settings.md line 6.

## 2026-11-03 - REALITY CHECK (user asked; recorded so it is not lost)
Measured state of the repo, not a projection:
- **Zero art assets.** 0 png / aseprite / audio / font files anywhere. assets/art/sprites, assets/art/ui, assets/fonts, assets/audio/sfx, assets/audio/music are all EMPTY dirs. The art bible describes pixel art; none has been drawn. Claude has produced no sprites and cannot draw pixel art (can write /asset-spec specs + AI gen prompts only).
- **UX work is markdown, not code.** design/ux/ = 12 spec docs. Only UI code is src/ui/hud/hud.gd from the Oct prototype, unrelated to the specs.
- **Everything renders as primitives** (draw_rect / draw_circle). No textures. No MultiMesh anywhere, despite ADR-0001 mandating it for bullets.
- **1,427 lines of GDScript in src/ vs 33,571 lines of design docs (~24:1).**
- **project.godot is still 480x640**; all design assumes 360x640. Retune never started.
- **ADR-0001 still Proposed** - the bullet benchmark that would accept-or-break it (GDScript, 2000 bullets, <=1.5 ms p99 REF-WEB) has NEVER been run. The core technical premise under all 33k lines of docs is unvalidated. Cheap to test.
- Godot binary: D:\Unreal Engine\GodotEngine\Godot_v4.7.2-stable_win64_console.exe
**USER DECISION (2026-11-03):** finish the paper trail first - apply art-director amendments, finish consistency check, /gate-check pre-production, then design reviews. Implementation + art + benchmark deferred by choice, with the above known.
<!-- CONSISTENCY-CHECK: 2026-11-03 | Scope: UX review wave 5 amendments (8 shared decisions, 24 docs, 7 registry constants) | Conflicts found: 2 (UI sound cue id naming - Audio 24; Delete-my-data location - Menus 22/Online 32) | Fixed: 20 stale refs in 7 files | Report: docs/consistency-report-2026-11-03-ux.md -->

## 2026-11-03 - IMPLEMENTATION STARTED (user: "be done with the gdd's and implement")
**User scope decision:** mainly OFFLINE game, LOCAL CO-OP first, online features LATER. Online (32), leaderboards, GodotSteam/ADR-0007 are OFF the critical path.

### ADR-0001 V1 benchmark: RUN, and it changed the design
Harness `tests/perf/bullet_bench.gd`, result recorded in `docs/architecture/spike-0001-bullet-bench-v1.md`.
- **First (naive) implementation FAILED: p99 1.916 ms** vs 1.5 ms accept threshold, on a desktop (REF-WEB is slower).
- **After 2 optimisations: p99 0.749 ms (2.6x faster), PASS with ~2x headroom.**
  1. Deleted the `_px`/`_py` prev-position arrays - prev is exactly `x - vx` once velocity is updated. Saved 2 reads + 2 writes per bullet per tick.
  2. Broad-phased the hit loop (was 4 slots x 2000 = 8000 swept tests/tick, the dominant cost). One AABB around hittable slots, padded by max_reach + hit_radius + longest step this tick, so it stays exact.
- `state_hash()` BYTE-IDENTICAL before/after (-5848840803477005472) = pure speedup, no behaviour change.
- MultiMesh pack p99 0.647 ms (budget 1.0) PASS. Determinism PASS.
- **MultiMesh TRANSFORM_2D buffer layout now VERIFIED on 4.7.2: 16 floats/instance, origin at buffer [3] and [7].** Closes ADR-0001 verification item 1. NOTE: `MultiMesh.buffer` is EMPTY headless (no rendering device) - must run windowed to check.
- Kind bucketing (ADR-0001 D3) deliberately NOT implemented: budget met with headroom, held in reserve for REF-WEB.
- **STILL OPEN: REF-WEB measurement** - that is the platform the ADR actually accepts on. Desktop pass is necessary, not sufficient. Also Web shader-compile hitch.

### Code written
- `src/gameplay/bullets/bullet_field.gd` - node-free BulletField (RefCounted), packed arrays, int ticks, spawn>age>move>cancel>hit>remove, swept test, deferred compaction. No gameplay constants in it.
- `src/gameplay/bullets/bullet_rules.gd` + `data/bullet_rules.tres` - all tuning (per the rule that gameplay values must come from data, never hardcoded). Authored per-second, converted to per-tick once in _init.
- `src/gameplay/bullets/bullet_renderer.gd` - MultiMeshInstance2D, one buffer assignment per pool, `pack()` split out so it can be timed without a device. Atlas hook ready for when art exists.
- `tests/unit/test_bullet_field.gd` - 12 tests, ALL PASS. Includes the tunnelling regression test that fails if the derived prev-position math is wrong.

### 360x640 retune: DONE (x scales 0.75, y unchanged; 3:4 -> 9:16)
- project.godot: viewport 360x640, window 720x1280, stretch aspect=keep, **physics_ticks_per_second=60 + max_physics_steps_per_frame=8** (ADR-0001 D5).
- play_area in game.gd / player.gd / bullet_manager.gd; offset_right in game.tscn + hud.tscn.
- boss_definition.gd defaults anchor (180,130), sway (68,0); boss.gd hull rect -90/180.
- data/bosses/*.tres: anchors 240->180, sway 130->98 / 120->90, part offsets and x-sizes x0.75 (mirrored pairs kept symmetric).
- data/planes/lancer.tres: speeds -> approved GDD values 210 / 210 / 105.
- **Verified: both test suites PASS, game scene runs 180 frames headless with zero errors.**

### Next implementation steps (in order)
1. GameLoop node + ADR-0002 fixed tick order (the spine).
2. Local co-op 1-4 players: PlaneCore (node-free, 4 slots), per-player device assignment.
3. CollisionReferee (GDD 6) - Phase A damage, Phase B player hits, invuln timers.
4. Scoring (GDD 8). 5. Wave director + non-boss enemies (GDD 16, 10). 6. HUD at 360x640 per spec.
- Art: still ZERO assets; everything stays on primitives. Decoupled so PNGs drop in with no code change.

## 2026-11-03 - PLAYABLE CO-OP PROTOTYPE ON THE NEW ARCHITECTURE
`run.tscn` is now the main scene (legacy `game.tscn` still runnable). Press F5.

### Files written
| File | What |
|---|---|
| `src/core/tick_event_log.gd` | ADR-0002 D5 preallocated tick event log. Double-buffered, `rotate()` swaps + resets (no alloc). Consumers after producer -> same tick, at/before -> `previous_*`. Grows only on overflow (dropping an event would desync a replay). |
| `src/core/sim_input.gd` | Per-slot input snapshot, the ONLY way input reaches the sim. Digital axes, held/pressed/held_ticks, pack/load for replays. NOTE: enum is `Action`, NOT `Button` - `Button` is a Godot Control class and collides. |
| `src/core/sim_world.gd` | ADR-0002 D1/D3: node-free SimWorld, steps 1-8, `Config` (+`from_data()`), `emitters` array = step 4 hook, `state_hash()`. Unbuilt epics are marked + skipped, not faked. |
| `src/core/game_loop.gd` | Node driver. PROCESS_MODE_ALWAYS, admission gates (pause now; load-discard/speed later), `service_step()` idempotent per physics frame (ADR-0002 D2 fallback), 8 ms tick guard, `tick_ran` = step 9. |
| `src/autoload/input_sampler.gd` | Autoload. `service_step()` every physics step (latches presses, runs while paused) + `commit_sim_tick()` at step 1. The split stops presses being lost on steps that do not become ticks. |
| `src/gameplay/player/plane_core.gd` | Node-free plane logic for ALL 4 co-op slots in packed arrays. EMPTY/FLY_IN/ACTIVE/DEAD/GAME_OVER, 8-way digital normalised diagonals, column start spots, invuln timer, lives, hands target arrays straight to BulletField. |
| `src/gameplay/player/plane_rules.gd` + `data/plane_rules.tres` | All plane tuning (210/105, 48/72 strip, 36/36/120 ticks, 3 lives). |
| `src/gameplay/run/run.gd` + `run.tscn` | Presentation only. Drop-in co-op (slot joins on its own Fire), plane primitives + always-visible hitbox dot, MultiMesh bullets, readout, pause (Esc/P/Start), restart (R). |
| `src/gameplay/run/test_emitter.gd` | SCAFFOLDING step-4 emitter (spiral/aimed fan/ring) so there is something to dodge. Marked for deletion when the Pattern library epic lands. |
| `tests/run_all.sh` | Runs every suite; exit 0 only if all pass. |

### Tests: 4 suites, ALL PASS (`bash tests/run_all.sh`)
- `test_bullet_field.gd` (12) incl. tunnelling regression test
- `test_plane_core.gd` (14) incl. 4-slot co-op columns, diagonal normalisation, 48 vs 72 strip clamp, determinism
- `test_sim_world.gd` (11) incl. same-tick event delivery, invuln/death-hold immunity, 1000-tick no-drift, determinism
- `test_chain_tracker.gd` (legacy, still passing)

### Verified working (headless, 1800 ticks, 4 co-op planes, real emitter)
peak 146 bullets, 84 live, 12 hits -> 12 deaths (= 4 players x 3 lives), all 4 GAME_OVER, 0 spawn rejections.
Windowed smoke test clean too (exercises MultiMesh + drawing, which headless skips).

### Project settings changed
main_scene -> run.tscn; `InputSampler` autoload added; `pause` action (Esc/P/pad Start) registered in input_setup.gd.

### NOT yet implemented (deliberately, marked in sim_world.gd at their step numbers)
Plane kits + bombs (3), StageDirector + ScrollClock (3a), EnemyManager (3b), BossController (3c), real pattern runners (4), full CollisionReferee Phase A (6), Critical Break (6b), powerups (7b), Chain/Scoring/Co-op/Session/Tally/Era (8a-8f), HUD per spec (9b).
Current step 6 does Phase B only (bullet reaches player -> PlaneCore.kill), which is all that is meaningful with no enemies yet.

### Next
1. ChainCore + ScoringLedger on int ticks (steps 8a/8b) - the old `ChainTracker` is float-seconds and belongs to the legacy path.
2. EnemyManager + CollisionReferee Phase A (enemies that can be shot) + player shot pool.
3. StageDirector: 5 waves -> boss.
4. HUD at 360x640 per `design/ux/hud.md`.
5. Art: still ZERO assets. Everything on primitives; MultiMesh atlas hook ready.

## 2026-11-03 - GDD #7 (chain) + #8 (scoring) IMPLEMENTED
User decision: keep working the GDD list in its designed order (asked about the 32-GDD count; I raised that a minimum-scope cut would finish the game sooner, user chose to continue the list).

| File | What |
|---|---|
| `src/gameplay/chain/chain_rules.gd` + `data/chain_rules.tres` | W=60, team_window 60, team_window_step 8, cap 999, cb 3/+50, part_kill_chain 5, milestones [50,100,200]. All from the registry. |
| `src/gameplay/chain/chain_core.gd` | ChainCore, 4 slots, int ticks. F2 fresh-skip window, pure reset to 0 on expiry, F3 team chain, F4 CB (returns UNCAPPED raw for scoring), F5 milestones, F6 bar ratio + red zone, boss peak, freeze. |
| `src/gameplay/scoring/scoring_rules.gd` + `data/scoring_rules.tres` | All locked registry values. Deliberately does NOT duplicate cb_mult/cb_add/chain_cap - reads ChainRules so they cannot drift. |
| `src/gameplay/scoring/scoring_ledger.gd` | F1 hit, F2 flat kills, F3 item chain factor, F4 CB on uncapped raw + LDB, F5 stage end, F6 cap-hold streak, F7 extends, F8 9-digit display clamp (int64 storage). Per-source breakdown for the tally. |

### Wired into SimWorld
Step 8a chain (death drops that slot's chain only), step 8b scoring (runs AFTER chain so hits use `count_after`). New `report_enemy_hit(slot, on_boss)` is the single path by which the chain climbs and hit score is paid - the enemy/boss epics call it from step 6. `boss_alive` gates team chain + cap-hold. Flag buffers reused (no per-tick alloc). state_hash now covers chain + scoring.

### Tests: 6 suites, 62 tests, ALL PASS
New: `test_chain_core.gd` (17), `test_scoring_ledger.gd` (18). Every formula is asserted against the GDD's OWN worked example, so the code is checked against the design, not itself:
- CB 50->200, 100->350, 150->500, 200->650, 317->999 (raw 1001 clamped); CB at 0 -> 50; raw 400 -> 1250 uncapped
- window drops on exactly the 60th hit-free tick; a hit on the drop tick saves it
- milestone 40->170 fires 50 and 100, not 200; team windows 60/68/76 for 2/3/4P
- hit 150 solo 160, 2P team 192, 3P 208, 4P 224; count 7 team -> 20
- kills 60s+20m+4l = 52,000; medal at 237 -> 5,000, at 999 -> 11,000
- CB 150 -> 500,000; 999 -> 3,047,000; LDB 3 lives -> 100,000
- stage end competent -> 1,295,000; cap-hold 30 s -> 232,500, 95 s -> 1,207,500
- display clamps to 999,999,999 while int64 storage does not

### Readout now shows score, chain (with red-zone marker) and TEAM CHAIN.

### Honest gap
The chain CANNOT climb in-game yet: nothing shoots. `report_enemy_hit` has no caller because there are no enemies and no player shot pool. Chain/score are correct and fully tested, but only exercised by tests until GDD #9 (pattern library) and #10 (enemy) land, plus a player shot pool.

### Next in design order
#9 pattern library (real emitters, replacing `test_emitter.gd` scaffolding), #10 enemy + CollisionReferee Phase A + player shot pool -> then the chain climbs and it becomes a shooter.

## 2026-11-04 - GDD #9 (bullet pattern library) IMPLEMENTED + Bullet manager Warp
Continued the design-order list. The previous session had written the six pattern
sources (`src/gameplay/patterns/`) and the ADR-0003 sim foundation (`src/sim/`)
but stopped before data, tests and wiring; `scene.play_top` did not exist, so the
flak path would have crashed on its first burst.

### Finished the library
| File | What |
|---|---|
| `data/patterns/*.tres` (16) | The F10 golden table: 4 fortress, 3 jet, 4 plasma, plus 5 wave patterns covering all 7 kinds (flak, spray, locked fan). Authored in ticks; **0 validator errors, 0 warnings**. |
| `data/run/platform_{fortress_1941,wave_1941}.tres` + `platform_def.gd`, `platform_gun.gd` | Authored stand-in enemy content (anchor, sway, ramp, gun offsets + pattern lists), so the run scene's values live in data like everything else. |
| `src/gameplay/run/pattern_platform.gd` | SCAFFOLDING step-4 owner: moves emitters on a triangle wave from the integer tick, ramps intensity. Replaces the deleted `test_emitter.gd`. Goes when Enemy (10)/Boss (14) land. |
| `tests/helpers/{fake_bullet_field,pattern_harness}.gd` | Recording field + scene rig (slots, hold, event record, `dispose_all`). |
| 6 unit suites + 1 integration suite | timing, targeting, geometry, safety, determinism, validator, plus `tests/integration/test_pattern_world.gd`. |
| `tests/perf/pattern_bench.gd` | AC-53/54/55 with a second rig at F9's real budget. |

### Fixes to the existing pattern code (it was not runnable)
- `PatternScene.play_top` was referenced by the flak clamp but never declared -> **every flak burst would have been a runtime error**. Added, with `set_player_count()` so the clamp floor follows the 48/72 px HUD strip.
- `TickEventLog` had none of the five pattern event kinds the runner appends. Added (append-only, after `BULLET_CANCEL_BURST`).
- `PlaneCore` had no `alive_flags()`/`active_flags()`; the library needs both (Alive = targetable incl. FLY_IN, Active = spawn-safety protected).
- Flak measured its standoff from the target's LIVE position, so a locked shell drifted off its telegraphed point. It now measures from the aim point (`_aim_x/_aim_y`).
- A fuse now carries the `count_eff` it was lit with, so the ring that bursts is the one that was telegraphed.
- **Reference cycle:** PatternScene -> emitter -> runner -> emitter is a RefCounted cycle, so nothing freed (204 leaked objects in the first test run). Added `dispose()` at all three levels, called on every removal path, plus `SimWorld.dispose()` (called from `Run._exit_tree`). Leak reports now clean, headless and windowed.
- F6 geometry moved into `PatternMetrics` as pure functions (the runner calls them), so the quoted-`u` ACs are testable and the runner cannot drift from the validator.

### Bullet manager Warp (GDD #3 gap, needed by the 2100 patterns)
`BulletField.Beh.WARP` implemented to bullet-manager F4 / Rules 16-17: flies to T1
42, frozen 43-66 (speed exactly 0), re-aims once on 67 at `warp_speed` 190 -> its
target slot, else the nearest Alive player (lowest slot on a tie), else its stored
spawn heading. `set_targets` gained an optional `alive` array (Warp needs Alive,
which is wider than hittable). 6 new tests. **ADR-0001 V1 re-run: p99 0.823 ms vs
the 1.5 ms threshold (was 0.749 before Warp) - still PASS.**

### Perf: the one budget missed, and why
`docs/architecture/spike-0002-pattern-bench.md`.
- AC-53's own rig (40 emitters / 120 runners, all armed on tick 0): **p99 0.527 ms
  vs the 0.2 ms budget**. That rig sustains ~3,600 live bullets by F9's own formula
  - over 2x the 1,700 F9 calls an ERROR - and the run refuses 1,533 spawns.
- The same code at F9's budget with staggered arming: **p99 0.115 ms, mean 0.054 ms
  = PASS**. AC-54 1.292 ms (budget 1.7) PASS. AC-55 -1.4 KiB / +0 objects PASS.
- Optimisation pass took the AC rig from p99 0.706 -> 0.527 ms and the mean from
  0.158 -> 0.099 ms: flat Active-player list for spawn safety, per-volley latching,
  call-site guards on `_service_fuses`/`_maybe_begin_lock`. The F3 gate is now
  inline in the runner AND in PatternMetrics; `test_pattern_gate_agrees_with_the_validator`
  sweeps 201 intensities x 5 ranges so the two copies cannot drift.

### Tests: 14 suites, ALL PASS (`bash tests/run_all.sh`, now includes tests/integration)

### Raised for the designer (GDD Open Questions 11-13, not guessed at)
11. AC-53's rig is ~2x over F9's scene budget - restate the rig or raise the budget.
12. AC-49's spiral arm gap "~133" is **150.5** for the shipped merged 2-arm spiral.
13. AC-39's partial flak-ring skip is impossible: a ring spawns every bullet at its
    centre, so a player on the burst point loses all 12 or none.

### Still true
- **Zero art and audio assets.** AC-56 to AC-61 (muzzle flash, lock reticle, fuse
  marker, grayscale, audio) are BLOCKED on that, not on code. The library already
  emits the events VFX (25) and Audio (24) need.
- AC-20 (pause through the tree) and AC-43 (30/60/144 fps + a stall) are owed: both
  need a GameLoop integration harness.
- REF-WEB is still unmeasured for both ADR-0001 V1 and AC-53.
- The legacy `src/gameplay/bullets/patterns/` is still on disk, used only by the old
  `game.tscn` path and the boss `.tres` files. It goes when Boss (14) lands.

### Next in design order
1. **#10 Enemy and AI** + CollisionReferee Phase A + a player shot pool - then the
   chain can finally climb and it becomes a shooter. Enemies own emitters
   (`owner_id = event_id * 16 + member_index`, arm on entering the fire zone,
   intensity frozen at spawn), which replaces `PatternPlatform`.
2. #16 Wave and stage director (5 waves -> boss), incl. the V-D5 cross-enemy density check.
3. #14 Boss and boss parts (the boss `.tres` files still carry legacy patterns).
4. HUD at 360x640 per `design/ux/hud.md`.

## 2026-11-04 (cont.) - IT IS A SHOOTER NOW (user: "no art, no menu, no missions, no boss")
User was right: `run.tscn` drew only planes, so bullets came from an invisible
point, nothing could be shot, and there was no menu or stage. Fixed, in code not docs.

- **Player shots** `src/gameplay/player/player_shots.gd` + `data/shot_rules.tres`
  (damage 20, interval 5, 2 needles, 900 px/s). It owns its own `BulletField` with
  the ENEMIES as targets, so shot-vs-enemy is the same tested swept test as
  bullet-vs-player. `BulletField` gained `hit_targets` / `hit_shooters` (one entry
  per impact) so damage and chain credit go to the right player.
- **Enemies** `src/gameplay/enemy/` (`EnemyDef`, `EnemyPathDef`, `EnemyPath`,
  `EnemyManager`) + `data/enemies/1941/` - scout, prop fighter, flak gunner (ground,
  not lethal), heavy bomber (plated 120 ticks), boss_fortress. Paths are pure
  functions of the integer age (STRAIGHT / SINE / ENTER_HOVER_EXIT). Guns ARM once
  on entering the field (Rule 18).
- **Stage director** `src/gameplay/stage/` + `data/stages/stage_1_1941.tres`:
  5 waves -> boss, 12 spawn events. Waves clear on "all sent and field empty and
  min_ticks", or time out.
- **Collision Phase A** in `SimWorld._resolve_shot_hits` (step 6a): per-impact chain
  hit (armoured hits count, C5), damage, kill credit + score. Enemy index resolved
  highest-first so a removal cannot shift a pending index.
- **Main menu** `src/ui/menu/title.tscn` is now the MAIN SCENE: focus list, START
  GAME, language chip (L), keyboard + gamepad (any slot) + mouse. Unbuilt items say
  so instead of dead-ending. Q in a run quits to title.
- **Localization seam** `src/ui/localization/` + `data/locale/ui_menus.tres`: all UI
  text goes through `UiStrings.text(key)`, `en`/`bn` columns, English fallback.
  Stored as .tres not .csv on purpose (Godot's CSV importer does not ship the source,
  which would break the Web build). The Bengali title line renders only if a Bengali
  font is in `assets/fonts/` - otherwise it would draw as boxes.
- **Still no art.** Enemies/shots are primitives (aircraft silhouette, ground
  emplacement, needle). Decoupled, so PNGs drop in with no logic change.
- Tests: **16 suites, all PASS**, incl. new `test_enemy_manager.gd` (12) and
  `tests/integration/test_stage_run.gd` (5: every wave runs, shots kill and climb the
  chain, armoured hits count, determinism, a still player dies).
- Deferred and KNOWN: boss is one LARGE enemy, not parts/phases (GDD 14); no powerups,
  bombs, plane kits, HUD per spec, tally, era shift; enemy hurtbox_count is 1 (GDD
  says 2/3 for MEDIUM/LARGE); no wave banner; high scores / settings / credits screens.

### Next
1. HUD per `design/ux/hud.md` (score, lives, chain bar) - the readout is a debug line.
2. Boss parts and phases (GDD 14) so the fortress breaks up.
3. Powerups + bombs (GDD 12, 13) and the plane kits (GDD 11).
4. Art: either real sprites (an artist, or AI-generated PNGs) or keep primitives.

## 2026-11-04 (cont.) - PLACEHOLDER ART, ON SPEC
- `assets/art/palettes/` - 7 .gpl + 7 .hex (global, players, UI, 4 eras) straight
  from art bible section 4. The bible calls these the only source of truth and they
  did not exist. Load a .gpl into Aseprite / Retro Diffusion / PixelLab / Krita.
- `tools/pixel_canvas.gd` + `tools/gen_placeholder_art.gd` - generator. **32 PNGs**:
  16 planes (4 types x 4 slot outlines), 5 enemies (+ bomber plating overlay),
  boss hull + turret + engine + core (SLICED, per 8.3), player shot, 4 hitbox rings
  (per-slot pattern), 2 parallax strips. It FAILS the run if a sprite breaks its
  8.3 size tier or colour cap - the spec is executable, not trusted.
- Wired: `EnemyDef.sprite`/`plating_sprite`, `data/art/run_visuals_1941.tres`
  (planes, hitboxes, shot, strips, scroll speeds, bullet tints).
- run.gd draws sprites + a scrolling delta (river down the quiet lane, paddy at the
  edges, muted clouds above). Layer order is now world -> enemies + player shots ->
  ENEMY BULLETS -> planes, because the bible's one inviolable rule is that a bullet
  draws over anything it could be mistaken for, and the hitbox over everything.
- Fixed while verifying against real captured frames (not assumptions):
  (1) a negative z_index layer never rendered - the whole world was invisible;
  (2) bullet tints were cyan/pink/teal, all three BANNED as bullet fills (4.3) -
      now the locked 225-265 deg indigo band, as data in run_visuals;
  (3) clouds were Cream and sat in the centre lane - now in the era value band and
      outside the central 120 px.
- Still placeholders: geometric block silhouettes, no animation frames, no damage
  states, no bullet atlas (MultiMesh quads are tinted, not textured), 1941 only.
- NEXT for art: bullet atlas + shader (needs angle in INSTANCE_CUSTOM for rice and
  needle), explosion/VFX sprites, the HUD plates, then real sprites from an artist
  or Retro Diffusion/PixelLab - the palettes and size tiers are the brief.

## 2026-11-04 (cont.) - KITS, DRONES, LASER, BOMBS (GDD 11 + 12)
- **Fixed the reported bug**: enemies armed their guns when the BODY touched the
  play area, so a bomber fired from above the screen. Enemy Rule 18 says the MUZZLE
  must be inside the fire zone (inset 4, now in data/enemy_rules.tres). Measured
  off-screen firing ticks: 2 -> 0.
- **Flak fuse tell** (pattern library V3): the real "fires from nowhere". A flak
  ring bursts 240 px from the gun 36 ticks after the fuse lights, and nothing drew
  the fuse. PatternScene.collect_fuses() exposes them; run.gd draws a growing smoke
  square with a spark that blinks every 12 ticks, then 6, then solid.
- **Score was never broken**: probe shows 31 kills / 28,994 points / chain 64. What
  looked broken was a plane with no drones being hard to aim.
- **PlaneKits** (src/gameplay/kits/, data/kit_rules.tres) - GDD 11:
  fire state machine (tap -> SHOT + 12-tick linger; hold 18 -> CHARGE or HOLD_PLAIN,
  edge-checked once per press), Lancer 3-streak volley + LASER (meter 0-1000, min
  400, -5/tick, 60 dmg every 3rd tick, invuln every tick, 90 px/s crawl, +2 meter
  per counted plane-shot hit only), Leech 2-streak + focused shot (30 dmg, 6 ticks),
  drones (idle diamonds on per-drone phase, Lancer PARK with 40-dmg column beams,
  Leech LATCH 20 dmg/5 ticks, claim cap 2/target, recall + 600/540 cooldowns).
- **BombCores** (src/gameplay/bombs/, data/bomb_rules.tres) - GDD 12: stock 3,
  reset on death, floor at stage start; accept -> 90-tick invuln + chain toll 50%
  (ChainCore.apply_bomb_toll, a REDUCTION not a drop) + full-screen cancel; Lancer
  column holds 24 ticks then sweeps at 8 px/tick, 100 dmg every 4 ticks, 1,000 cap
  per target; 90-tick lockout.
- **Input was unbound**: the sampler looks for pN_drone / pN_focus / pN_start and
  InputSetup registered none of them (only pN_ability). Drones were unusable in the
  real game. Now: X drone, C bomb, Shift focus, Enter start (+ pad X / B / RB / Start).
- Bugs found by the new tests: drone positions were never initialised, so the first
  park sent the whole flight to the screen corner; the rig also proved the laser
  shields the plane (a kill test had to wait out its own invulnerability).
- Art: drone pod sprites (4 slots). Laser beam, parked beam and bomb column are
  drawn as rects for now (FX sprites not generated).
- Tests: **17 suites**, new test_plane_kits.gd (12 tests).

### Honest gaps after this pass
- Sentry and Breaker kits are GDD 29 and NOT built; slots fly Lancer/Leech/Lancer/
  Leech so no player has a dead ability button.
- starting_drones = 2 is invented: drones are supposed to come from POD pickups
  (Powerups GDD 13, not built). Without it nobody would ever see a drone.
- Leech bomb = the Lancer sweep, not 4 seeking hooks (GDD 12 Rules 23-27).
- Laser needs 200 landed hits (meter +2, min 400) and the meter resets on death, so
  in play it is rare. Worth a playtest look at fill_per_hit.
- Leech latch out-scores Lancer by roughly 4x in a probe. Both are per-GDD; flagging
  it for the designer, not changing it.
- Still missing: powerups (13), Critical Break (17), VFX (25), the real HUD (7),
  boss parts and phases (14), era shift (19).


## 2026-11-04 (cont.) - BOSS, STAGE, 4 PLANES, POWERUPS, CRITICAL BREAK

### The reported bugs, and what they actually were
- "No boss at the end, stages don't progress." The director was fine (probe:
  boss at tick 4020). The player was DEAD at tick ~2148 and SimWorld kept
  running waves over a corpse forever. SimWorld now has a `run_state`
  (PLAYING / GAME_OVER / STAGE_CLEAR); `tick()` returns early once it leaves
  PLAYING, so the last frame holds under a banner.
- **Holding Fire through a respawn left the gun off.** `_tick_fire_state` only
  started the gun on a PRESS edge, and Rule 3 ignores buttons while the plane
  is flying in - so a player holding Fire (every shmup player) was disarmed
  after every death and at the start of every run until they let go and
  pressed again. Found by a probe measuring 0 shots in 200 ticks.
- **The laser was unreachable.** Rule 4 checks the charge on the edge at hold
  tick 18, so a meter that fills DURING the hold never starts a laser. New
  data switch `charge_rearms_while_held` (default true) starts it the moment
  the meter is full; `false` restores the GDD letter, and both are tested.
  Also: a laser that ran dry while Fire was held left the slot in CHARGE
  forever, so it was one laser per press. It now drops to HOLD_PLAIN.
  `fill_per_hit` 2 -> 8 (200 landed hits -> 50) after measuring 0 s of laser
  across a whole stage.

### Built
- **Powerups and drops (GDD 13)**: `src/gameplay/items/` + `data/item_rules.tres`.
  Five kinds (POD, CHAIN, MEDAL, 1UP, GEM), seeded drop stream (4 draws per
  carrier, always), pity counter + recovery pod on death, need check, the
  fixed 1-up at the 4th carrier, stride-sampled gems from cancelled bullets,
  pop/fall/rest/magnet motion, gem pursuit, boss-defeat sweep.
  `starting_drones` 2 -> 0: pods are now the only source, as the GDD says.
- **Sentry and Breaker (GDD 29)**, so all four slots fly different planes.
  Sentry: twin parallel guns, Entrench nose cannon + aimed docked drones +
  the plane slowed to 75 px/s, world-anchored turret posts with early recall.
  Breaker: 30-damage ram, Breach slugs + seeking return bolts paid out of a
  stock, the plane-relative Erase Net that deletes enemy bullets, credits the
  stock (capped per pulse), rams, and never covers the plane's own hitbox.
- **Bastion and Backlash** bombs (dome, wall) in BombCores, chosen by kit.
- **Critical Break (GDD 17)**: `src/gameplay/critical/`. Charge the boss while
  it is under `critical_hp_pct`, bomb it, and the chain is MULTIPLIED instead
  of halved - the bomb's 50% toll is waived when the break is armed. Commit,
  lenience, one break per boss, and the miss counters are all in.
- **Per-bullet damage** in BulletField (`_dmg`, `hit_damage`): one pool now
  holds a 20 dmg drone diamond and a 50 dmg Entrench shell at once.
- **Cancel reporting** in BulletField: positions + cause per cancelled bullet
  (which is what turns a bomb's curtain into gems) and a per-region count
  (which is what pays the Breaker's stock). `request_clear_all` is now
  deferred into the cancel step, so it lands before the hit pass.
- **Stage 1 re-authored**: five named waves (RIVER MOUTH, THE SANDBARS, FLAK
  ROW, THE CROSSING, THE APPROACH), tighter max_ticks, and the Powerups
  contract mix of carriers (4 SMALL / 2 MEDIUM / 2 LARGE). Wave 1's first
  carrier has a POD override, so a new player holds a drone within 10 s.
- **Presentation**: wave/WARNING/BOSS/CLEAR/GAME OVER banner; an item layer;
  net zones, the Bastion dome and the Backlash wall drawn; EMPLACED and
  LATCHED drone states drawn; the readout shows HIT n xN (the multiplier),
  the kit, its own resource, drones, bombs and the break cue.
- **Bullet atlas + shader**: `assets/art/shots_fx/bullet_atlas_64x16.png` and
  `bullet_atlas.gdshader`, one cell per shape picked from INSTANCE_CUSTOM.x.
  2,000 bullets of four shapes are still ONE draw call. Enemy bullets are no
  longer flat squares. Five item sprites generated too (42 files total).
- **docs/art-pipeline.md**: the requested technical guide - every sprite, its
  size, its colour cap, which .tres line points at it, and how to swap it.

### Measured (bot probe, all four kits, after the fixes)
| Kit | End | Boss at | Drones | Items | Break | Score |
|---|---|---|---|---|---|---|
| Lancer | CLEAR 167 s | 70 s | 4 | 57 | yes | 1.1M |
| Leech | CLEAR 95 s | 55 s | 4 | 71 | yes | 4.7M |
| Sentry | CLEAR 94 s | 72 s | 4 | 9 | yes | 4.9M |
| Breaker | CLEAR 164 s | 76 s | 3 | 6 | yes | 1.6M |

Before this pass the same bot died at 40-57 s and never saw the boss.

### Tests: 20 suites, all passing
New: `test_item_field.gd` (14), `test_sentry_breaker.gd` (10),
`test_critical_break.gd` (11).

### Honest gaps after this pass
- Critical is "boss hp <= 25%", not "the main pool is destroyed": Boss and
  boss parts (GDD 14) is not built, so there is one body and no core.
- Without per-bullet TAGS, any plane-pool hit while charging counts as a
  charge hit for the break, where GDD 29 Rule 38 wants only tags 2 and 3.
  A drone bullet can therefore arm a break. Needs a `tag` column to fix.
- The Leech bomb is still the Lancer sweep, not four seeking hooks.
- No stage 2: the era ladder (19) and a second StageDef do not exist, so
  STAGE CLEAR is the end of the game.
- Still missing: VFX (25), the real HUD (7), plane select (22), audio (24),
  the stage-end tally screen (23).


## 2026-11-09 - PC CONTROLS, DRONE DEPLOY, PLANE SELECT

### What the owner asked for
"Update controls for keyboard or gamepad on PC now, later button UI for mobile
users, and update that requirement in the docs. The player has drones but we
cannot deploy them. Before starting the level there is no scene to select the
planes we have available - in multiplayer and single player, free choice of
one plane, and if the same plane is selected we change the colour for the 2nd,
3rd or 4th. Implement today and update the docs."

### Controls (PC)
- `src/autoload/input_setup.gd` rewritten to the GDD default bindings table.
  Pad: South/RB Fire, West/LB Drone, East/RT Bomb, LT Focus, Start, Back.
  **KB1 "Main" on slot 0** (arrows, Z/Space/`,` fire, X/`.` drone, C//` bomb,
  Shift focus, Enter start, Esc back) and **KB2 "Left hand" on slot 1**
  (WASD, F, G, R, Q, 1, 2). Two players now share one keyboard with no setup.
- WASD is slot 0's alternate only while slot 1 is out: the Lobby calls
  `release_wasd_from_kb1()` / `restore_wasd_to_kb1()`.
- Debug keys moved **R/N/1/2/3 -> F5-F9** (they collided with KB2's Bomb and
  Start, GDD correction 9). `pN_back` added. `pN_ability` kept as a legacy
  alias for the old prototype scene only.
- Move deadzone 0.2 -> 0.3 (`dz_enter`); an action's deadzone is now the
  highest its controls ask for, so a trigger-as-button presses at 0.50 (F3).
- Still owed (table in the input GDD): dynamic device assignment (slot N is
  still joypad N), `SlotInput`/raw stick/8-way in Input, trigger release
  hysteresis, remapping, Fire toggle, Tap Assist, hot-plug and focus loss.

### Why "we cannot deploy drones", and what was actually wrong
The deploy itself worked: a probe deployed all four kits' abilities once the
plane held a drone. Three real problems behind the complaint:
1. **The press was lost unless the tick was perfect.** Input Rule 17's 6-tick
   Drone/Bomb buffer was never built. Now in `SimInput` (`buffered`,
   `consume`, `clear_buffer`), consumed by `PlaneKits` and `BombCores` only on
   the tick they act, cleared by `PlaneCore` every non-Active tick (Rule 18).
   A press 6 ticks before the cooldown ends now deploys.
2. **Nothing said why nothing happened.** The run scene now shows
   "NO DRONES - COLLECT A POD" or "DRONES RECHARGING {n}s" on a Drone press it
   cannot honour. `starting_drones` stays 0: pods are the only source (GDD 13
   Rule 2), and wave 1's first carrier drops one.
3. P2-P4 had **no keyboard at all**, so a second player could not press
   anything, drone included. Fixed by KB2.

### Plane select (GDD 22, Rules 18-25)
- `src/ui/menu/lobby_model.gd` - node-free, 60 Hz, unit tested: four slots,
  per-slot cursor, join on Start/Fire, Fire locks, Bomb unlocks then leaves,
  45-tick commit bar, AFK release (30 s), lobby idle (60 s) back to Title.
- `src/ui/menu/plane_select.tscn` + `plane_select.gd` - view only: card row,
  four slot columns, split rim light per holder, READY stamp, commit bar.
- Cards are data: `data/menus/plane_cards.tres` (all four planes available),
  `data/menus/lobby_rules.tres` for the timings, strings in
  `data/locale/ui_menus.tres` (38 new keys, 3 Bengali filled).
- **Entry gate** (`_armed`): the Fire press that confirmed START GAME on Title
  cannot lock a plane - a verb must be released first. Without it the lobby
  locked and launched before the player saw the cards.
- Title START GAME -> plane select -> run. `GameSession.start_run(selections)`
  carries `{slot, kind, colourway, plane_id}`; `Run._join_selected_players()`
  calls the new `SimWorld.set_slot_kit()` (kit AND bomb) and adds only the
  locked slots.

### Duplicate planes -> colourways (new GDD 22 Rule 20a, closes OQ 4)
Free choice for every slot, duplicates allowed, and **the colourway is the
slot**: P1 amber, P2 azure, P3 green, P4 pink. The second player on a plane
flies it azure, the third green, the fourth pink, so no two planes on screen
share a palette - and it needed no new art, because `plane_sprites` already
holds four colourways per plane.
- **Bug found and fixed:** `plane_sprites` is stored `[type][slot]` but the
  .tres was in generator order (sentry, breaker, lancer, leech) while the code
  indexed `(slot % 4) * 4 + slot`. P1 (a Lancer) was drawing the SENTRY
  airframe. The resource is now in `KitRules.Kind` order and the run indexes
  `kind * 4 + colourway`. Hitbox ring, laser, drones, shots and plane all
  follow the colourway now.

### Docs updated
- `design/gdd/input-and-player-mapping.md`: 2026-11-09 revision note, `pN_focus`
  added to the action table, and a full **Implementation status** section
  (done / not done / the shipped PC binding sheet).
- `design/gdd/menus-title-plane-select.md`: revision note, **Rule 20a**,
  edge-case line, **Implementation status** table, Open Question 4 closed.
- `design/gdd/touch-controls.md`: revision note recording that the **mobile
  button UI is deferred** until the PC scheme is final - design unchanged,
  nothing implemented.
- `design/gdd/plane-kits-lancer-leech.md`: revision note on the buffered
  Drone press.
- `docs/project-structure.md`: autoloads, `src/ui/`, `data/`, a new "Front
  end: how a run starts" section, and honest Known gaps.

### Tests: 22 suites, all passing (`bash tests/run_all.sh`)
New: `test_lobby_model.gd` (13 tests), `test_input_buffer.gd` (11 tests,
including the carried-over-press and buffered-deploy regressions).
Also smoke-ran title.tscn, plane_select.tscn, run.tscn and game.tscn headless
(`--quit-after 200`): no script errors.

### Honest gaps after this pass
- The lobby is MVP art: drawn text and rectangles, no pilot animation, no
  pedestal, no hangar backdrop, no plane preview animation.
- A joining slot starts on the card matching its slot index; `profile.last_plane`
  (Save 26) does not exist.
- A slot that drops in during a run (Fire press) still gets the simulation
  default kit, not a pick: the drop-in pick UI (Rule 26) is not built.
- Devices are still hard-bound to slots, so "any pad may join" is not true yet.
- No Settings, Results, name entry, boards, pause panel or attract mode.
