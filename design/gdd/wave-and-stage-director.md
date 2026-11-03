# Wave and Stage Director

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (level-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos, Every Hit Counts, History Accelerates (also Four Planes, Four Games: chain-friendly streams suit every kit)

## Overview

**The data layer:** the **Wave and stage director** (the Director) plays a stage from data. A stage is one `StageDef` resource (`data/stages/stage_<n>_<era>.tres`): a lead-in, **5 waves**, then a fixed **boss block** (field clear, WARNING, scroll-stop, boss intro, fight, sweep, clear). Each wave is a list of **spawn events** on integer ticks counted from the wave start (role, path, origin, group size, carrier flag, preview mechanic). The Director has one job per tick: issue the spawn requests whose tick has come (to Enemy and AI 10), track when the wave ends, and run the boss-block steps. It owns the stage clock, the scroll speed, the background section changes (for Parallax 23), the music cues (for Audio 24) and the events `stage_started`, `wave_started`, `wave_ended`, `warning_started` and `stage_cleared`. It also owns the **stage validator** (`StageValidator`, a unit test over `data/stages/`) that proves a stage obeys every budget handed to it: the boss preview schedule (Boss power budget 15), carrier cadence (Powerups 13), the 1,700-bullet density ceiling (Pattern library 9, Co-op 18), the 28 / 32 alive and hurtbox caps (Enemy 10), the 45-tick chain gap (Chain tracker 7) and the stage length target. The Director draws **no random numbers**: the same stage data, player count and kill history give the same spawns on every run. It is a node-free `RefCounted` class with `tick()` (ADR-0001), no `delta`, all values in `data/*.tres`.

**The player impact:** the player feels a stage as a shaped five-minute piece. Wave 1 is sparse and slow and teaches movement and the chain. Each wave adds a little more (one new boss idea in miniature, shown alone), with two short **rest beats** to breathe and grab drones. Waves are built as **chain lanes**: streams of targets that hand over to each other inside the chain window, so a good player can hold a chain through a whole wave (**Every Hit Counts**). Pods arrive on a steady beat, never in a flood. Then a siren, a WARNING plate, a scroll that slows to a drift, and the boss, which is always the peak (**Readable Chaos**). Stage 2 repeats the shape with a faster scroll and the 1970s language (**History Accelerates**). Nothing is random: a run that fails at wave 4 meets the same wave 4 on the next credit, so players can learn and plan.

## Player Fantasy

**Anchor moment: "I read the whole stage."** The player is on wave 4. A heavy bomber spins a small one-arm spiral from its belly, and they think "that is a baby version of the Fortress core." They clear it, a pod drops, the rest beat lets them pick it up, wave 5 mixes the four tricks gently, the siren sounds, and when the Fortress opens fire they already know every voice in the chorus. The stage was a lesson plan, and the boss was the exam.

- **Waves are a rhythm, not a pile.** Enemies arrive in streams that hand over to each other. A player who aims well keeps the chain alive from the first scout to the last bomber (**Every Hit Counts**).
- **Rests are earned and short.** Two 2.5 to 3 s lulls per stage let the player collect pods, check drones and reset their hands. They are never a punishment and never dead air longer than 3 s.
- **Escalation is visible.** More enemies, more guns, more speed, wave after wave, and still lighter than the boss (**Readable Chaos**).
- **The next era is a step.** Stage 2 scrolls faster, uses jets and radar locks, and introduces them one at a time (**History Accelerates**).
- **A good player is not slowed down.** Clear the wave early and the next one starts after a short gap. A weak player is not rushed: the timeline never skips content.
- **Co-op is busier, not different.** More small enemies per player (the same wave, the same beats), so four chains can live at once.

**Anti-fantasy (must never happen):** a wave that ends only when you kill X enemies (stalling); a pod flood or pod drought; a preview the player cannot see because its carrier died in half a second; a wave that is denser than the boss; a random wave order that cannot be learned; dead air longer than 3 s outside a rest beat; a boss that starts while enemy bullets are still on screen.

Reference feel: DoDonPachi's fixed, memorisable stage scripts; 1941's escalating squadrons; Mega Man's stage-to-boss echo (the stage teaches what the boss uses).

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

**Stage data and clock**

1. A stage is a **`StageDef`** (`data/stages/stage_<n>_<era>.tres`). Fields: `stage_number` (1 to 4; Session's `stage_index` is `stage_number - 1`), `stage_id`, `era_id`, `boss_id`, `lead_in_ticks` (default 120), `waves[5]`, `boss_block` (Rule 24), `bg_sections[]` (Rule 20), `music_cues[]` (Rule 21), `name_key` (Localization). A stage has **exactly 5 waves** (Boss power budget V13). *(Amended 2026-11-03, wave 4, online-leaderboards-boss-rush.md:)* the one exception is a **boss-only stage** for Boss Rush / Single Boss: `waves = []` plus `home_stage` (the main-game stage whose boss block, era and `Q_cap` it reuses). It runs lead-in, Warning, `Boss.start_intro(boss_id, home_stage)`, Sweep and `stage_cleared` exactly as the boss block of `home_stage`; no `wave_started` is emitted.
2. A **`WaveDef`**: `index` (1 to 5), `length_ticks`, `boundary` (`BRIDGED` or `REST`), `gap_ticks` (0 for BRIDGED, 120 to 300 for REST), `scroll_v_x100` (px per tick x 100, int), `intensity_x100` (default `(index - 1) x 25`: 0, 25, 50, 75, 100, matching Enemy Rule 19), `coop_spawn_cap` (a `spawn_pct` limit, 100 to 160, default 160 = none), `events[]`. Wave 5 has no `boundary`: the boss block follows it.
3. A **`SpawnEvent`**: `id` (unique int), `tick` (int, ticks from the wave start), `role` (`fodder`, `fighter`, `gunner`, `heavy`), `path_ref` (an Enemy `EnemyPathDef`), `origin` (Vector2i px, authored for 1 to 2P), `mirror` (bool), `count` (base group size, 1 to 12), `spacing_ticks` (0 to 60; 0 = all on the same tick), `formation` (`NONE`, `TRAIL`, `V` with `anchor` / `offset` per Enemy Rule 7), `scaled` (bool, default true for SMALL, forced false for MEDIUM, LARGE, carriers and previews), `carrier` (bool), `preview` (mechanic id or empty), `lane` (int, 0 = none; Rule 16), `max_life_ticks` (0 = role default). All fields are integers or strings. No floats in stage data.
4. Events are stored **sorted by `tick`, then `id`**. The Director keeps one cursor per wave. Each tick it issues every event with `tick == wave_t` (Rule 6). Per-tick cost is O(events issued).
5. **Stage clock.** `stage_t` counts ticks since `stage_started`. `wave_t` counts ticks since the current wave started. Both advance by 1 per tick **only if at least one slot is Active and the game is not paused**. If every slot is Dead or in Continue, the clock stops (enemies already on screen keep moving; nothing new spawns). *Why:* the same rule as the Boss fight clock (Boss Rule 33). A death costs the player no wave content and no new threat while they are down.

**Spawning**

6. **Issuing.** On the tick an event's `tick` comes, the Director expands it into spawn requests (Rule 7) and calls `EnemyManager.spawn(role, path_ref, origin, mirror, params)` in event order. `params` = `event_id` (the spawn event's id, echoed in `spawn_failed(event_id, reason)`; 2026-11-03), `carrier`, `wave_intensity` (= `intensity_x100 / 100`), `scroll_v` (the current scroll speed; for ground enemies superseded by the live ground anchor `S`, Rule 20), `preview` (a mechanic id, → Enemy amendment) and `max_life_ticks` if set. The Director runs **before** `EnemyManager.tick()` in the tick order (step 3a; → core wiring ADR).
7. **Group expansion.** An event with `count > 1` spawns `group_size` enemies, the first at `tick` and the others every `spacing_ticks` after it (a trail) or on the same tick (a V). `group_size = coop_spawn_scale(count, min(spawn_pct(N), coop_spawn_cap))` (F2) for `scaled` events, else `count`. `N` is read from Session **once**, on the first tick of the group. Players who join or leave later do not resize a group. Extra members extend the trail at the same spacing.
8. **Carriers are never scaled.** A `carrier` event has `count` 1 and `scaled` false. A co-op wave has exactly the same carriers as a solo wave (Powerups: "not scaled with N"). Carriers are plain enemies from the stage's role table with the carrier flag; they are never preview carriers.
9. **Spawn failure.** Enemy refuses a spawn when `alive >= 28` or the hurtbox budget (32) is full (dropped at once), or drops it after the 30-tick clearance retry (Enemy Rule 8). Enemy reports `spawn_failed(event_id, reason)` (provisional). For a **carrier** or a **preview** event the Director re-queues it once, `requeue_delay` (60) ticks later, up to `requeue_max` (2) times in total, and only if the wave still has at least 300 ticks left. Any other event is dropped and counted (`events_dropped`). A requeued carrier keeps its flag, so cadence is kept. A preview that is lost for good logs `preview_missed(wave, mechanic)` in debug builds.
10. **Placement.** Every event's origin must satisfy Enemy F10 for both `play_top` 48 (1 to 2P) and 72 (3 to 4P): the Enemy manager adds `y_shift` itself; the Director never shifts origins. The validator checks both shifts (V-D7).
11. **No reactive spawning.** The Director never reads player positions, score, chain or hp to decide what spawns. The only live inputs are the player count `N` (Rule 7), `any_active` (Rule 5), the alive count (early clear, Rule 14) and spawn failures (Rule 9).

**Waves: start, end, rest**

12. **A wave starts** at `wave_started(stage, wave, 5)`. Wave 1 starts `lead_in_ticks` after `stage_started` (the stage card; no spawns). Wave `n+1` starts when wave `n` ends plus `gap_ticks` of wave `n`.
13. **A wave ends** at the first of: `wave_t == length_ticks` (the **nominal end**), or the **early clear** (Rule 14). Enemies still alive at the end are **not** removed: they finish their paths (a wave may spill a few seconds into the next). Spawns of a finished wave never continue.
14. **Early clear (decision: fixed timeline, short gap).** The wave is in **Tail** once its last event has been issued (and no requeue is pending). In Tail, when `alive == 0` and no spawn is queued, a timer of `early_clear_gap` (24 ticks) starts; when it ends, the wave ends early. The timer is cancelled if an enemy appears. The player is never rushed by a quota and never punished for killing fast; the timeline of events is identical on every run, only the start time of later waves moves. Why this and not a kill-gated wave: see Decided note.
15. **Rests.** A `BRIDGED` boundary has no gap: the next wave's first group must be targetable within `bridge_entry_max` (21) ticks of its spawn, so an early clear (24) plus entry stays within the 45-tick chain gap (F6). A `REST` boundary is a fixed `gap_ticks` (120 to 300) of no new spawns, **never shortened** by an early clear. MVP stages have 2 REST boundaries (waves 2 to 3 and 4 to 5) plus the boss block's quiet start. Rests are where pods are collected, drones counted and hands rested.
16. **Chain lanes.** A **lane** is a tagged sequence of groups (`lane` > 0) meant to be chained through. Authoring rules: (a) consecutive lane groups leave **no more than `chain_gap_budget` (45) ticks** with no targetable enemy anywhere on the field (Chain tracker F1, `G <= W - ceil(W/4)`); (b) the lateral jump between consecutive lane groups is at most `lane_reach_px` (157 px = 3.5 px/tick x 45); (c) at least `lane_cover_min` (70 %) of every wave's non-rest ticks lie in lane coverage (F6). Outside a REST boundary and the boss block, a stretch longer than 45 ticks without a targetable enemy is an error (V-D8). Co-op group growth only lengthens trails, never opens a gap.
17. **Density and caps** (the validator, Rule 28): F3 gives the concurrent bullet estimate `N_scene(t, N)` from the nominal timeline. It must stay at or below **1,700** at every `N` in 1 to 4 (Pattern library F9 hands the cross-enemy check to the Director) and at or below the **wave curve cap** `wave_curve_cap[w]` (60 / 80 / 100 / 120 / 150) at `N` = 1. Peaks must strictly rise from wave 1 to wave 5. Alive enemies and hurtboxes (F4) must stay at or below 26 and 30 (the caps 28 and 32 minus `cap_margin` 2) at `N` = 4, so Enemy never refuses a spawn.

**Boss foreshadowing** (the schedule is fixed by Boss power budget 15 Rules 13 to 17; the Director only places it)

18. **Previews.** Wave `N` (1 to 4) spawns the preview of mechanic `N` as `preview = <mechanic_id>` on the carrier role the budget names; wave 5 spawns all four inside `combo_window_ticks` (180) with `max_life_ticks` at least 600 each. The Director uses at least **`preview_carriers_min` (2) successive carriers** in every wave 1 to 4, spawned so that the next one starts after the previous one's nominal exit (so `preview_alive_max` = 1 holds). When the carrier role is SMALL (the Jet's `fighter`, hp 50), it uses **3** successive carriers (Open Question 2). `preview_alive_max` is read **per mechanic**; in waves 1 to 4 only that wave's own mechanic is on screen, so one preview carrier is alive at most; in wave 5 four are alive, one per mechanic (Open Question 1). Previews may not be powerup carriers. The Director emits `mechanic_previewed(boss_id, mechanic_id, wave)` at the first preview spawn of each mechanic.
19. **Novelty gating.** For each novelty tag `t` of the stage's boss, `novelty_debut_wave(stage, t)` gives the debut wave `d` (Jet: `behaviour:accelerate` 1, `option:aim_lock` 4). The Director strips `t` from **native** enemy patterns (not previews): `lock_ticks` forced to 0 for `option:aim_lock`, Accelerate replaced by Straight at `v_strip` (Era shift F4; default `V_EFF` = average speed, `strip_speed_mode`; 2026-11-03). Stripping applies to every native spawn whose wave is `< d`, and in wave `d` to every native spawn **before the first preview carrier of that mechanic has spawned** (`tag_open_tick`, F9). It is passed to Enemy as `strip_tags[]` in the spawn params (→ Enemy amendment). Era shift (19) owns the stripping map (`StripMap`, [GDD](era-shift-and-plane-evolution.md)); the Director only decides *when*.

**Scroll, background, music**

20. **Scroll** (F8). Each wave has `scroll_v_x100`. At each wave start the scroll speed blends from the old value to the new one over `scroll_blend_ticks` (120) with integer arithmetic. Ground enemies take the speed current at their spawn tick. During the boss block the speed eases to `boss_scroll_v_x100` (25 = 0.25 px/tick) over 60 ticks. The Director emits `scroll_changed(v_x100)` for Parallax. *(2026-11-03, wave 3b, [Parallax 23](parallax-and-environment.md): the Director module owns a `ScrollClock` with the integer ground scroll `S` (1/100 px) and `scroll_pos_x100()`, ticked after the Director and before Enemy. `scroll_changed(v_x100)` is emitted on every integer change and once at `stage_started`. Ground enemies follow the **live** `S` (`ground_dy = (S div 100) - (S_spawn div 100)`), replacing "take the speed current at their spawn tick", so they never slide on the terrain.)* **Background sections** (`bg_sections[]`: `trigger`, `section_id`, `blend_ticks`) switch on **state triggers** (`WAVE_START(n)`, `BOSS_WARNING`), never on absolute ticks, so an early clear cannot desynchronise scenery. Parallax owns the art; scroll position is `sum(scroll_v)`.
21. **Music cues** (`music_cues[]`: `trigger`, `cue_id`, `transition`) also use state triggers: `STAGE_START`, `WAVE_START(n)`, `REST_START(n)`, `WAVE_TICK(n, rel_tick)` (in-wave swells), `WARNING`, `BOSS_INTRO`, `BOSS_STARTED`, `BOSS_ENRAGED`, `BOSS_DEFEATED`, `STAGE_CLEARED`. The Director emits `stage_cue(cue_id, transition)`; Audio (24) owns the mix.

**Boss block and stage end**

22. When wave 5 ends at tick `E5` the **boss block** runs on fixed offsets (Rule 24). Offsets from `E5` are the same on every stage. `boss_started` therefore fires at `E5 + 480` (a clearance wait of up to 180 more can follow, Boss Rule 15).
23. **Field-clear guarantee** (Boss Rule 11, art bible banner rule: the WARNING plate only shows over a clear field): at `E5` spawns have stopped and every alive enemy gets `force_exit`; at `E5 + 60` the Director calls `EnemyManager.despawn_all("boss_intro")` and `BulletManager.clear_all()` (no items, Bullet manager Rule 15 clear-all). Emitters are retired while Leaving (Enemy Rule 18), and `despawn_all` stops the rest, so no new bullet appears after the clear.
24. **Boss block table** (`BossBlockDef` defaults, offsets from `E5`):

| Offset (ticks) | Step | Calls and events |
|---|---|---|
| 0 | Wave 5 ends, spawns stop | `wave_ended(5)`, `force_exit` for all alive enemies |
| 60 | Field clear | `despawn_all("boss_intro")`, `clear_all()` |
| 90 | WARNING | `warning_started(150)` (HUD plate + siren), cue `WARNING` |
| 240 | Scroll-stop and intro | scroll eases to 25 over 60 ticks, `Boss.start_intro(boss_id, stage_number)` |
| 480 | Boss starts | `boss_started` (Boss: intro 240 = entrance 180 + hold 60) |
| 480 + T | Boss defeated | `boss_defeated(reason, killer)` from Boss; Director enters **Sweep** |
| D + 90 or `boss_gone` | Stage cleared | `despawn_all("stage_end")`, `clear_all()`, `stage_cleared(stage_index)` |

   `D` is the `boss_defeated` tick. `stage_cleared` fires at `max(boss_gone tick, D + sweep_min_ticks)` with `sweep_min_ticks` = 90 (Powerups needs 75: the farthest item at 730 px and 10 px/tick arrives in 73 ticks). A watchdog fires `stage_cleared` at `D + 360` if `boss_gone` never arrives (logged).
25. **Stage-end flow.** `boss_defeated` (Chain freezes, Scoring pays the boss value, Powerups sweeps) → Sweep (at least 90 ticks) → `stage_cleared` (Chain STAGE_END, Scoring pays the stage-end bonuses once, Powerups removes leftovers, Session enters Tally) → Tally (21) → Era shift (19) stages the next era during the tally, commits the swap at tick 90 of the transition and emits `era_ready(era_id)` at release, **before** Tally Done → on tally done, Session sets `stage_index + 1` → `Director.load_stage(next)` (requires `era_ready`) emits `stage_started(stage_index, era)` → `lead_in_ticks` → wave 1. At `stage_cleared` the Director supplies `is_last_stage` and `next_era` (= Era shift `era_for_stage(stage_index + 1)`, none on the last stage) to the Tally (2026-11-03, wave 3b). After the last stage's tally Session goes to Results and the Director goes idle. *(2026-11-03, wave 3a: Scoring computes the S8 stage-end lines at `stage_cleared` and the Stage-end tally (21) pays them line by line via `pay_stage_end_line`; the last stage also has a tally (`stage-end-tally.md` Rules 1, 11).)* A TIMEOUT boss (`reason = TIMEOUT`) follows the same flow; nothing branches on the reason.
26. **Mid-run joins and drops.** Join and leave only change `N` for *future* groups (Rule 7). The Director never restarts or rewinds a wave. A continue restarts nothing: the wave goes on where the clock stopped (Rule 5).
27. **Pause.** The Director is not ticked while paused (Session); all counters stop.

**Validation**

28. `StageValidator.check(stage_def, rules, budget, role_tables)` runs in `tests/unit/test_wave_director_*.gd` (errors fail the build) and at stage load (debug: assert; release: log and play anyway). Checks:

| ID | Check |
|---|---|
| V-D1 | Exactly 5 waves (or `waves = []` with a valid `home_stage` for a boss-only stage, Rule 1); boss id exists; roles and paths exist in the era's tables; events sorted; ids unique; ints only |
| V-D2 | `StageLint.check_stage` (Boss power budget Rule 22 a to d) passes, including `preview_alive_max` and the combination window; previews appear only on the carrier role the budget names; `preview_carriers_min` holds |
| V-D3 | Novelty gating: no native enemy spawns with an un-opened tag; `tag_open_tick` is on the first preview spawn |
| V-D4 | Carriers: per stage 4 SMALL + 2 MEDIUM + 2 LARGE (≥ 8); ≥ 1 per wave; spawn ticks ≥ 180 apart on the **stage timeline, worst case** across boundaries (F5); no carrier is scaled or a preview |
| V-D5 | Density: `N_scene(N)` ≤ 1,700 for N = 1 to 4; ≤ `wave_curve_cap[w]` at N = 1; peaks strictly increase; any `coop_spawn_cap` makes a failing wave pass; peak co-active lit flak fuses ≤ 8 (`flak_fuse_max`, Pattern library; added 2026-11-03 wave 4) |
| V-D6 | Alive ≤ 26 and hurtboxes ≤ 30 at N = 4 on the nominal timeline (F4) |
| V-D7 | Spawn placement valid for `play_top` 48 and 72; bridge entry ≤ 21 ticks |
| V-D8 | Chain: no stretch of more than 45 ticks without a targetable enemy outside REST and the boss block; lane jumps ≤ 157 px; lane cover ≥ 70 % |
| V-D9 | Timing: `length_ticks` ≥ last event tick + 120; REST gaps 120 to 300; 2 REST boundaries in MVP; par stage length in 14,400 to 18,000 ticks (F7) |
| V-D10 | Boss block: the table of Rule 24 matches; `sweep_min_ticks` ≥ 75 |
| V-D11 | Determinism: validator and a 3-run dry simulation give equal spawn-log hashes; no RNG calls |

### States and Transitions

| State | Meaning | Spawns | → Next | Trigger |
|---|---|---|---|---|
| Unloaded | no stage | no | LeadIn | `load_stage` after `era_ready`; emits `stage_started` |
| LeadIn | stage card | no | WaveRunning(1) | `lead_in_ticks` elapsed on the stage clock |
| WaveRunning(n) | events being issued | yes | WaveTail(n) | last event issued |
| WaveTail(n) | waiting for the end | no | Rest(n) / WaveRunning(n+1) / PreBoss | nominal end or early clear |
| Rest(n) | REST gap | no | WaveRunning(n+1) | `gap_ticks` elapsed (BRIDGED boundary skips this state) |
| PreBoss | offsets 0 to 90: force exit, clear | no | Warning | `E5 + 90` |
| Warning | plate and siren (150 ticks) | no | Intro | `E5 + 240` |
| Intro | scroll-stop, boss entrance and hold | no | BossFight | `boss_started` |
| BossFight | the Boss owns the field | no | Sweep | `boss_defeated` |
| Sweep | items fly to planes, boss dies/withdraws | no | Cleared | `max(boss_gone, D + 90)` or watchdog `D + 360` |
| Cleared | `stage_cleared` fired; Session runs Tally | no | Unloaded | next `load_stage`, or Results (after the last stage's tally) |

The clock stops (Rule 5) in every state while no slot is Active.

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Enemy and AI (10) — GDD | → | `spawn(role, path_ref, origin, mirror, params)` with `event_id`, `carrier`, `wave_intensity`, `scroll_v`, `preview`, `strip_tags[]`, `max_life_ticks`; `force_exit`, `despawn_all`. ← `spawn_failed(event_id, reason)`, `enemy_destroyed`, `enemy_escaped`, `alive_count()`, role tables, path library (provisional additions in amendments) |
| Boss power budget (15) — GDD | ← | `PreviewSet[1..5]`, `check_stage`, `novelty_debut_wave`, `preview_alive_max`, `combo_window_ticks`; → `mechanic_previewed` |
| Powerups and drops (13) — GDD | → / ← | carriers flagged per event (≥ 8 per stage); `stage_started` (reseed), `boss_defeated` (sweep), `stage_cleared` (clear items) |
| Boss and boss parts (14) — GDD | → / ← | `Boss.start_intro(boss_id, stage_number)`; ← `boss_started`, `boss_defeated(reason, killer)`, `boss_gone` |
| Coop and Team Chain (18) — GDD | ← | `N`, `spawn_pct(N)`; runs the F5 density check for every wave; `coop_spawn_cap` |
| Bullet pattern library (9) — GDD | ← | F9 per-enemy `N_def`; the cross-enemy 1,700 check is the Director's |
| Bullet manager (3) — GDD | → | `clear_all()` at the boss block and stage end |
| Collision, damage and lives (6) — GDD | ← | `spawn_is_clear` (used by Enemy; the Director validates origins are off-screen or ground) |
| Chain tracker (7) — GDD | — | no calls. Timeline gap rule G ≤ 45 (F1); `boss_started` / `stage_cleared` timing |
| Scoring (8) — GDD | — | no calls; `stage_cleared` starts the S8 payment, so the Director fires it once |
| Game events and session (1) — GDD | → / ← | → `stage_started(stage_index, era)`, `stage_cleared(stage_index)`, `wave_started`, `wave_ended`, `warning_started`, `scroll_changed`, `stage_cue`, `mechanic_previewed`. ← `N`, slot states (`any_active`), `stage_index`, `run_seed`, pause |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | ← / → | `era_ready(era_id)` (emitted at transition release, before Tally Done) before `load_stage`; `era_for_stage`, `StripMap`, role tables; the era ladder |
| Stage-end tally (21) — [GDD](stage-end-tally.md) | → | `stage_cleared` starts it (tally tick 0); the Director supplies `is_last_stage` and `next_era` (from Era shift `era_for_stage`) at `stage_cleared` (Tally amendment 11; decided 2026-11-03); `wave_ended(…, early)` counts for a "waves cleared early" line (optional) |
| HUD (20) — [GDD](hud.md) | → | `warning_started(150)` plate; `wave_started(stage, wave, 5)` / `wave_ended` for the thin progress track (art bible 7.4). *(2026-11-03, wave 3a: HUD Rules 26-27 called these `stage_progress()` and `warning_requested`; HUD now consumes these events.)* |
| Parallax (23) — [GDD](parallax-and-environment.md), Audio (24) — [GDD](audio.md) | → | `bg_sections`, `scroll_changed`, `ScrollClock.scroll_pos_x100()`, `stage_cue` |
| Tutorial (30) — [GDD](tutorial.md) | → | `stage_started`, `wave_started`, `mechanic_previewed`, `lead_in_ticks` (stage-1 card primer). No calls into the Director; drills use Tutorial's own `DrillRunner` (same `SpawnEvent` shape). |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | ← | Plays boss-only stages (`waves = []`, `home_stage`) in `rush_order` (Rule 1). |
| Save (26) — GDD | → | Debug tools set `run.debug_tainted` (a `RunRecord` field, Save / Online leaderboards amendment 2026-11-03), which blocks ranking and upload |

> *(Updated 2026-11-03, wave 4: every system named above has a GDD.)* Contract: the Director only emits the signals named above and never reads from them.

> Decided under auto-approve (2026-11-03): fixed event timeline per wave with an early-clear skip (24-tick gap) instead of kill-gated or time-only waves; event ticks relative to the wave, background and music keyed to state triggers; 2 REST boundaries (waves 2 to 3 and 4 to 5) and bridged others; stage clock stops while nobody is Active; group size read once at the group's first tick; carriers never scaled; requeue of failed carrier/preview spawns; at least 2 (SMALL carriers: 3) successive preview carriers; `preview_alive_max` read per mechanic; debut gate opens at the first preview spawn; boss block offsets 0 / 60 / 90 / 240 / 480; field clear before WARNING; `stage_cleared` at `max(boss_gone, boss_defeated + 90)`; no RNG in the Director; wave curve caps 60 / 80 / 100 / 120 / 150.

### MVP Stage Outlines

Level-document view of the two MVP stages (Level Document Standard). All times in ticks; wave-relative unless stated "stage". Estimates; the validator is authoritative.

#### Stage 1: 1941 (Fortress) — scroll 80 / 90 / 100 / 100 / 110, boss 25

**Estimated play time:** 4:24 at par (15,813 ticks including the 120-tick lead-in); boss block 56 s.

**Layout diagram (one field, top to bottom 640 px):**
```
 y=48   ------- play_top (spawn line for air) -------
        [scout trails enter from the sides: SWOOP_L / SWOOP_R]
        [prop fighters: SINE down the middle]
 y=200  [heavy ENTER_HOVER_EXIT hovers here (x 180)]
        [ground gunners scroll down at x 110 and x 250]
 y=616  rest_y (pods wait here)
```

| W | Name | Length | Boundary | Enemies (N=1 base, SMALL groups scale) | Preview (carriers at wave tick) | Powerup carriers (wave tick) | N peak 1P / 4P |
|---|---|---|---|---|---|---|---|
| 1 | Scouts | 2,100 | BRIDGED | scout trails 6 (x3), V 5 (x2), prop fighters 3 (x2) | m1 `turret_fan` on `gunner`: 300, 1,140 | SMALL 700 | 26.7 / 40.7 |
| 2 | Coast | 2,280 | REST 180 | scouts 6 (x3), fighters 4 (x3), flak gunner 1 | m2 `engine_ring` on `gunner`: 200, 960 | SMALL 500; MEDIUM (gunner) 1,800 | 49.3 / 70.3 |
| 3 | Harbour | 2,400 | BRIDGED | scouts 6, fighters 4 (x3), flak gunner 1 | m3 `armoured_core` on plated `heavy`: 300, 1,200 | LARGE (heavy) 1,800 | 75.8 / 96.8 |
| 4 | Fortress approach | 2,520 | REST 150 | scouts 6, fighters 6 (x3), flak gunner 1 | m4 `core_spiral` on `heavy`: 400, 1,400 | SMALL 200; MEDIUM 900 | 88.3 / 116.3 |
| 5 | Walls | 2,700 | boss block | scouts 5 (x3), fighters 6 (x3) | combination 900 / 950 / 1,000 / 1,060 (gunner, gunner, heavy, heavy) | SMALL 300; LARGE 1,800 | 111.0 / 139.0 |

**Critical path:** survive 5 waves, then kill (or outlast) the boss. **Optional paths:** kill every carrier (8 items; pods give drones up to 4), kill every preview carrier (practice for the boss; no bonus beyond the kill value), chain lanes through scouts and fighters.

**Encounter list:** the wave rows above; fighter and scout trails are the chain lanes (1 to 3 lanes per wave, coverage at least 70 %).

**Pacing chart** (tension 1 to 10; `_` marks a REST beat):
```
10 |                                                      B B
 9 |                                                    B     B
 8 |                                               w5 w5
 7 |                                      w4 w4
 6 |                   w3 w3 w3
 5 |            w2 w2
 4 |   w1 w1
 3 |  w1
 2 |                _ _            _ _     (rest beats)
 1 |__________________________________________________________
    0     2.1k   4.6k   7.0k   9.6k   12.3k  13.3k   15.8k
    lead  W1     W2  _  W3    W4  _  W5     WARN  BOSS  clear
```
Beats: calm opening (3), first armed enemies (4), coast gunner (5), REST (2), armour lesson (6), spiral lesson (7), REST (2), combination (8), siren and scroll slows (3), boss (10).

**Narrative beats / environment:** dawn sea, coast, harbour fleet, fortress approach (bunkers, AA nests), fortress walls, boss deck. No text; the background sections tell it.

**Music/Audio cues:** `s1_start`, `s1_wave_1` to `s1_wave_5` (layers), `s1_rest` at each REST, `warning_siren`, `s1_boss_intro`, `s1_boss`, `s1_boss_enrage`, `victory`, `tally` (table A1).

#### Stage 2: 1970s (Jet Carrier) — scroll 120 / 130 / 140 / 150 / 150, boss 25

**Estimated play time:** 4:41 at par (16,875 ticks including the lead-in); boss block 66 s.

| W | Name | Length | Boundary | Enemies (N=1 base) | Preview (carriers at wave tick) | Powerup carriers (wave tick) | N peak 1P / 4P |
|---|---|---|---|---|---|---|---|
| 1 | High haze | 2,160 | BRIDGED | dart jets 6 (x3), delta jets 4 (x2) (accelerating rice only after tick 240) | m1 `accel_fan` on `fighter`: 240, 700, 1,160 | SMALL 920 | 25.0 / 39.4 |
| 2 | River delta | 2,340 | REST 180 | darts 6, deltas 5 (x3), radar gunner 1 (lock stripped) | m2 `pod_stream` on `fighter`: 240, 700, 1,160 | SMALL 600; MEDIUM (radar gunner) 1,700 | 39.3 / 53.7 |
| 3 | Airbase | 2,520 | BRIDGED | darts 6, deltas 6 (x3), radar gunner 1 (lock stripped) | m3 `wing_wall` on `heavy`: 300, 1,200 | LARGE (missile carrier) 1,800 | 59.9 / 79.1 |
| 4 | Carrier fleet | 2,640 | REST 150 | darts 6, deltas 6 (x3), missile carrier 1 | m4 `radar_lock` on `gunner`: 400, 1,200 (lock allowed from tick 400) | SMALL 200; MEDIUM 1,700 | 66.5 / 85.7 |
| 5 | Flight deck | 2,820 | boss block | darts 5, deltas 6 (x3) | combination 900 (fighter) / 940 (fighter) / 1,000 (heavy) / 1,060 (gunner) | SMALL 300; LARGE 1,900 | 74.5 / 93.7 |

The Jet's armour (`c_armoured_core`) is carried and not previewed (Boss power budget Rule 6). **Critical path** and **optional paths** as Stage 1 (the lock-fan preview is a free read of the radar lock tell). Layout diagram as Stage 1 with jet paths (SINE fighters, ground gunners at the scroll speed).

**Pacing chart:**
```
10 |                                                          B B
 9 |                                                        B     B
 8 |                                                   w5 w5
 7 |                                          w4 w4
 6 |                       w3 w3 w3
 5 |            w2 w2
 4 |   w1 w1
 2 |                _ _            _ _
 1 |____________________________________________________________
    0    2.2k   4.7k   7.2k   10.0k  12.8k  13.3k   16.9k
```

**Narrative beats / environment:** high-altitude haze, river delta radar masts, airbase, carrier escorts, flight deck approach, open-sea boss.

**Music/Audio cues:** `s2_start`, `s2_wave_1` to `s2_wave_5`, `s2_rest`, `warning_siren`, `s2_boss_intro`, `s2_boss`, `s2_boss_enrage`, `victory`, `tally`.

> Decided under auto-approve (2026-11-03): wave names, lengths and compositions above; REST at waves 2 to 3 (180) and 4 to 5 (150); single combination set in wave 5; SMALL-bodied Jet previews get 3 carriers; Stage 2 carries the armour unpreviewed.

## Formulas

Conventions: 60 ticks per second; all stage data are integers; `px` positions; registry values `chain_window` 60, `move_speed` 210 px/s (3.5 px/tick), `enemy_max_alive` 28, `enemy_hurtbox_budget` 32, `enemy_cap` 2,000 (budget 1,700), `play_top` 48 / 72. Validator maths runs offline and at load, not per tick, so floats are allowed there; stored results are integers.

**F1. Wave timeline** *(`wave_timeline`)*

`start(1) = 0` (relative to wave 1 start; `stage_started` is `lead_in_ticks` earlier)
`end(w) = min(length(w), t_clear(w) + early_clear_gap)` where `t_clear(w)` is the first `wave_t` at or after the last issued event at which `alive == 0` and no spawn is queued; if there is no such tick, `end(w) = length(w)`
`start(w+1) = start(w) + end(w) + gap(w)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Wave length | `length(w)` | int ticks | 1,800 to 3,600 | Nominal wave length |
| Early clear gap | `early_clear_gap` | int ticks | 0 to 45 | Default 24 |
| REST gap | `gap(w)` | int ticks | 0 or 120 to 300 | 0 for BRIDGED |
| Clear tick | `t_clear(w)` | int ticks | ≥ last event tick | Field empty |

**Output Range:** `end(w)` from `last_event + early_clear_gap` to `length(w)`. **Example (Stage 1, nominal, no early clear):** lengths 2,100 / 2,280 / 2,400 / 2,520 / 2,700; gaps 0 / 180 / 0 / 150. Starts **0 / 2,100 / 4,560 / 6,960 / 9,630**; `E5` = 9,630 + 2,700 = **12,330**. Early clear: wave 1 cleared at `wave_t` 1,980 → `end` = 2,004 (96 ticks saved); wave 2 starts at 2,004. Cleared at 2,090 → `end` = min(2,100, 2,114) = **2,100**. A REST boundary keeps its gap: wave 2 cleared at 2,000 → ends 2,024; wave 3 starts 2,024 + 180 later.

**F2. Group size in co-op** *(`group_size`, restates Co-op F5 with the wave cap)*

`pct = min(100 + coop_spawn_step x (N - 1), coop_spawn_cap)`; `group_size = (count x pct + 99) / 100` (integer division, rounds up); SMALL `scaled` groups only

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base size | `count` | int | 1 to 12 | Authored 1P size |
| Players | `N` | int | 1 to 4 | Read at the group's first tick |
| Step | `coop_spawn_step` | int % | 0 to 50 (20) | Co-op (18), registry |
| Wave cap | `coop_spawn_cap` | int % | 100 to 160 (160) | Per wave; default = no cap |

**Output Range:** `count` to `ceil(1.6 x count)`. **Example:** `count` 6 → 6 / 8 / 9 / 10 for N = 1 to 4. With `coop_spawn_cap` 140 → N = 4 gives `(6 x 140 + 99) / 100` = **9**. `count` 5 → 5 / 6 / 7 / 8. `count` 1 (a carrier) → 1 at every N because `scaled` is false.

**F3. Scene density** *(`scene_density`)*

`N_scene(t, N) = sum over enemies e alive at nominal tick t of N_def(e)`

Enemy `N_def` is Enemy F9a (the Pattern library F9 summed over the enemy's emitters); a preview carrier uses the preview pattern in place of emitter 0 (Boss power budget F5) plus its other native emitters. "Alive at nominal tick t" means from spawn to the nominal exit age of its path (no kills assumed: the worst case). Groups are sized with F2. Checks: `max_t N_scene(t, N) <= 1,700` for N = 1 to 4; `max_t N_scene(t, 1) <= wave_curve_cap[w]`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Enemy estimate | `N_def` | float | 0 to 150 | Prop fighter 7.0, flak gunner 21.3, heavy bomber 26.5, delta jet 4.8, radar gunner 8.9, missile carrier 29.2, scout / dart 0 |
| Scene ceiling | | int | 1,700 | Bullet manager F10 (85 % of 2,000) |
| Curve cap | `wave_curve_cap[w]` | int | 60 / 80 / 100 / 120 / 150 | Tuning knob |

**Output Range:** 0 to a few hundred. **Example (Stage 1 wave 2, peak):** 4 prop fighters 28.0 + 1 flak gunner carrier 21.3 = **49.3** at N = 1 (cap 80 passes); at N = 4 fighters become `(4 x 160 + 99) / 100` = 7, so 49.0 + 21.3 = **70.3** (≪ 1,700). **Wave 5, peak:** 6 fighters 42.0 + fan preview 5.46 + ring preview 12.00 + armoured heavy 26.5 + spiral heavy (15.24 + tail fan 9.8) 25.04 = **111.0** (cap 150); at N = 4: 10 fighters 70.0 + 69.0 = **139.0**. Previews are unscaled.

**F4. Alive and hurtbox budgets** *(`resource_budget`)*

`alive(t, N) = sum over alive enemies of 1`; `hurtboxes(t, N) = sum of hurtbox_count` (SMALL 1, MEDIUM 2, LARGE 3); require `alive <= enemy_max_alive - cap_margin` and `hurtboxes <= enemy_hurtbox_budget - cap_margin` at N = 4

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Caps | `enemy_max_alive`, `enemy_hurtbox_budget` | int | 28 / 32 | Registry |
| Margin | `cap_margin` | int | 0 to 6 (2) | Slack so carriers are never refused |

**Output Range:** alive 0 to 26, hurtboxes 0 to 30. **Example (Stage 1 wave 5, N = 4):** 8 scouts + 10 fighters + 2 gunners + 2 heavies = **22 alive**; hurtboxes 8 + 10 + 2 x 2 + 2 x 3 = **28** (limit 30). A third heavy would make 31 and fail.

**F5. Carrier cadence** *(`carrier_spacing`)*

`spacing_min = min over consecutive carrier spawns (a, b) of (T_b - T_a)`, where for carriers in the same wave `T` = event tick difference, and across waves the **worst case** `T_b - T_a = (last_event(w_a) + early_clear_gap - tick_a) + tick_b` (wave `w_a` ended as early as possible); require `spacing_min >= 180` and exactly the class counts 4 / 2 / 2 with at least 1 per wave

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Spacing floor | `carrier_gap_min` | int ticks | 180 to 600 (180) | Powerups contract |
| Carriers | | list | 8 per stage | 4 SMALL, 2 MEDIUM, 2 LARGE |

**Output Range:** `spacing_min` ≥ 180. **Example (Stage 1, nominal stage times):** carriers at 700, 2,600, 3,900, 6,360, 7,160, 7,860, 9,930, 11,430 → gaps 1,900 / 1,300 / 2,460 / 800 / 700 / 2,070 / 1,500, `spacing_min` **700**. Stage 2: 920, 2,760, 3,860, 6,480, 7,400, 8,900, 10,290, 11,890 → `spacing_min` **920**. Worst case across a boundary: stage 1 wave 4 carrier at tick 900 and wave 5's at tick 300 give at least `(last_event(4) + 24 - 900) + 300` > 180 for any `last_event(4)` ≥ 1,500.

**F6. Chain gap and lane reach** *(`chain_gap`)*

`G(t) = number of consecutive ticks with no targetable enemy`; require `G <= chain_gap_budget = chain_window - ceil(chain_window / 4)` = 45 outside REST and the boss block; `lane_reach_px = floor(move_speed_tick x chain_gap_budget)`; `lane_cover = ticks in lane coverage / non-rest ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Chain window | `chain_window` | int ticks | 60 | Registry |
| Gap budget | `chain_gap_budget` | int ticks | 30 to 60 (45) | Chain tracker F1 |
| Move speed | `move_speed_tick` | float px/tick | 3.5 | Registry (210 px/s) |
| Bridge entry | `bridge_entry_max` | int ticks | 0 to 21 | `chain_gap_budget - early_clear_gap` |
| Cover min | `lane_cover_min` | float | 0.5 to 0.9 (0.7) | |

**Output Range:** `G` 0 to 45; `lane_reach_px` ≈ 157. **Example:** early clear 24 + entry 21 = **45** (limit met). `floor(3.5 x 45)` = **157** px; at focus speed (1.75) the reach is 78 px, so lane jumps above 157 px are errors and above 78 px are warnings. A 58-tick empty stretch inside wave 3 fails V-D8; the same stretch inside a REST boundary does not.

**F7. Stage length** *(`stage_par_ticks`)*

`T_par = lead_in + sum(length) + sum(gap) + 480 + T_fight_par + 180`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Lead-in | `lead_in` | int ticks | 60 to 240 (120) | Stage card |
| Boss block | 480 | int ticks | fixed | 90 pre-warning + 150 warning + 240 intro |
| Par fight | `T_fight_par` | int ticks | 2,400 to 3,600 | Boss F6: Fortress 2,703, Jet 3,285 |
| Death sequence | 180 | int ticks | fixed | Boss `death_ticks` |

**Output Range:** 14,400 (4:00) to 18,000 (5:00) ticks for MVP stages. **Example:** Stage 1: 120 + 12,000 + 330 + 480 + 2,703 + 180 = **15,813** (263.6 s, 4:24; boss block 3,363 ticks = 56 s). Stage 2: lengths 2,160 + 2,340 + 2,520 + 2,640 + 2,820 = 12,480; 120 + 12,480 + 330 + 480 + 3,285 + 180 = **16,875** (281.3 s, 4:41; boss block 3,945 = 66 s). A player who needs 30 % longer on the boss adds about 14 s.

**F8. Scroll blend and ground life** *(`scroll_speed`, `ground_life`)*

`v(t) = v_old + ((v_new - v_old) x min(t, B)) div B` (ints, x100 px/tick; `t` = ticks since the wave start); `ground_life = ceil(640 x 100 / v_x100)` ticks for a `STRAIGHT` ground enemy at spawn speed `v_x100`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Blend | `B` | int ticks | 60 to 240 (120) | `scroll_blend_ticks` |
| Speeds | `v_old`, `v_new` | int | 20 to 200 | px/tick x 100 |
| Travel | 640 | px | fixed | From `play_top` entry to 16 px past the bottom (Enemy Rule 16) |

**Output Range:** `v` between old and new; ground life 320 to 3,200. **Example:** blend 80 → 90, `t` = 60: 80 + (10 x 60) div 120 = **85**; `t` = 120: **90**. Ground life: speed 80 → **800** ticks; 90 → ceil(711.1) = **712**; 110 → ceil(581.8) = **582**; 120 → ceil(533.3) = **534**; 130 → **493**; 140 → ceil(457.1) = **458**; 150 → ceil(426.7) = **427**. Stage 1 scrolls 80 / 90 / 100 / 100 / 110; Stage 2 scrolls 120 / 130 / 140 / 150 / 150; boss 25.

**F9. Debut gate** *(`tag_open_tick`)*

`strip(tag, wave w, native spawn at tick s) = (w < d) OR (w == d AND s < open_tick(tag))`, with `open_tick(tag)` = tick of the first preview spawn of the mechanic that owns `tag`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Debut wave | `d` | int | 1 to 4 | Boss power budget Rule 20 |
| Open tick | `open_tick` | int ticks | wave-relative | First preview of the owner |

**Output Range:** bool. **Example (Jet):** `behaviour:accelerate`, `d` = 1, first preview fighter at wave tick 240. A delta jet spawned at tick 200 has Straight rice; at tick 240 and later it keeps Accelerate. `option:aim_lock`, `d` = 4, first lock preview at wave 4 tick 400: delta jets and radar gunners in waves 1 to 3 have `lock_ticks` 0; in wave 4 a spawn at tick 380 is stripped, one at tick 400 keeps its lock.

> Decided under auto-approve (2026-11-03): early-clear gap 24; `bridge_entry_max` 21 (so the bridged gap equals the 45-tick chain budget); lane cover 70 %; `cap_margin` 2; scroll values; lead-in 120; wave lengths; stage length window 4:00 to 5:00.

## Edge Cases

**Timeline and clock**
- **If every slot is Dead or in Continue**, the stage clock stops; no event is issued; enemies already spawned keep moving. It resumes on the first tick a slot is Active.
- **If the game is paused**, the Director is not ticked; no counter moves.
- **If a player dies mid-wave**, nothing is rescheduled. The wave continues from the same event cursor.
- **If a continue is accepted**, the wave continues where the clock stopped; the Director is not reset.
- **If the early-clear timer is running and a carrier spawn is requeued**, the requeue counts as a queued spawn, so the timer is cancelled until it spawns.
- **If the wave is cleared before its last event is issued**, there is no early clear (the wave is not in Tail); the remaining events are still issued on schedule.
- **If the nominal end arrives with enemies alive**, they stay; the next wave starts anyway and their `N_def` is counted by the validator (F3) through their nominal exit.
- **If a REST boundary follows an early clear**, the REST gap is not shortened (Rule 15).

**Spawning**
- **If `spawn_is_clear` is false for 30 ticks for a SMALL non-carrier**, Enemy drops it; the Director counts `events_dropped` and does not retry.
- **If a carrier is refused or dropped**, it is re-queued 60 ticks later, at most twice, and only if the wave has at least 300 ticks left; otherwise `carrier_lost` is logged and the 1-up count shifts by one carrier (Powerups handles the count).
- **If a preview carrier is lost for good**, `preview_missed(wave, mechanic)` is logged in debug; wave 5 still spawns the others.
- **If a group's last member would spawn after `length_ticks`**, V-D9 fails at N = 4 (the validator expands groups at the largest size).
- **If a player joins during a wave**, groups already started keep their size; the next group is sized for the new `N`.
- **If `N` rises to 3 or 4 mid-run**, `play_top` becomes 72; Enemy adds `y_shift` 24 to spawns made after the change; enemies already alive are not moved (Enemy owns the rule).
- **If the SMALL group size at N = 4 pushes alive or hurtboxes past 26 / 30**, V-D6 fails; the author lowers `count` or sets `coop_spawn_cap`.
- **If an event names a role missing from the era table**, V-D1 fails; at runtime (release) the event is skipped and logged.

**Previews and carriers**
- **If a preview carrier is killed instantly**, the Director has already scheduled at least one more carrier of the same mechanic (2, or 3 for SMALL bodies), each after the previous one's nominal exit; it never respawns a killed one early (`preview_alive_max` 1).
- **If the player ignores a preview carrier**, it flies its path and exits; the next carrier spawns on schedule.
- **If a carrier and a preview share a path**, they are separate events and separate enemies; a preview carrier never gets the carrier flag.
- **If co-op doubles the SMALL groups**, carriers and previews stay fixed (Rules 8, 18).
- **If the stage has no boss budget file**, V14 of Boss power budget applies: debug refuses; release plays, wave 5 shows no combination and the Director logs it.
- **If a native spawn falls in the stripped window**, Enemy receives `strip_tags` in the params; a role with no tagged pattern ignores them.

**Boss block**
- **If enemies are still alive at `E5`**, they get `force_exit`; at `E5 + 60` `despawn_all` removes any that remain, with no kill credit (`enemy_escaped` is not emitted for the despawn).
- **If a player is firing at a leaving enemy at `E5 + 59`**, the kill still counts; at tick 60 it is removed.
- **If a wave 5 early clear happens**, the boss block runs from that earlier `E5`; nothing else changes.
- **If `Boss.start_intro` is refused** (a boss is already alive), the Director logs an error, waits for `boss_gone`, and retries once; in debug it asserts.
- **If a player is inside the boss at the end of the hold**, Boss waits up to 180 ticks (Boss Rule 15); the Director only listens for `boss_started`.
- **If `boss_gone` never arrives**, `stage_cleared` fires at `D + 360` (watchdog) and an error is logged.
- **If the boss times out (TIMEOUT)**, the flow is identical: Sweep (at least 90 ticks), `stage_cleared`. A withdrawing boss reaches `boss_gone` in at most 180 ticks.
- **If all slots are Dead at `boss_defeated`**, the stage is still cleared; Session decides Tally or Results.
- **If a lethal hit and `boss_defeated` land on the same tick**, Collision resolves first (Session AC-34); the Director just reacts to `boss_defeated`.
- **If a player drops in during Sweep or Tally**, they join per Session Rule 7; the Director is idle by then.

**Stage end**
- **If the last stage is cleared**, `stage_cleared` fires, the Stage-end tally (21) runs, then Session goes to Results; no `load_stage` follows.
- **If the next stage's era assets are not ready**, `load_stage` waits for `era_ready`; no tick runs; the Tally stays open.
- **If `stage_cleared` is requested twice**, the second is ignored (once per `stage_started`).
- **If the stage is loaded from a debug stage select**, the run is marked `debug_tainted` and cannot be ranked.

**Data**
- **If a stage has a wave other than 5**, V-D1 and Boss power budget V13 fail.
- **If two events share a tick**, they are issued in `id` order; the order is part of the spawn-log hash.
- **If `length_ticks` is shorter than the last event tick + 120**, V-D9 fails.

> Decided under auto-approve (2026-11-03): requeue limits; escaped-vs-despawn behaviour at `E5 + 60`; `stage_cleared` watchdog 360; one `stage_cleared` per stage; debug stage select marks the run tainted.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Enemy and AI (10) — GDD | Hard | `spawn(...)`, role tables, paths, `alive_count()`, `force_exit`, `despawn_all`, `spawn_failed`. Provisional additions: `preview`, `strip_tags[]`, `max_life_ticks` params |
| Powerups and drops (13) — GDD | Hard | Carrier counts (8 per stage), cadence 180, not scaled, 90-tick sweep window |
| Boss power budget (15) — GDD | Hard | `PreviewSet`, `check_stage`, `novelty_debut_wave`, `preview_alive_max`, `combo_window_ticks` |
| Boss and boss parts (14) — GDD | Hard | `start_intro`, `boss_started`, `boss_defeated(reason)`, `boss_gone`, entrance 240, death 180 |
| Game events and session (1) — GDD | Hard | `N`, slot states, `stage_index`, pause, `run_seed`; events |
| Coop and Team Chain (18) — GDD | Hard | `spawn_pct(N)`, density check, `coop_spawn_cap` |
| Bullet pattern library (9) — GDD | Hard | F9 `N_def`; 1,700 ceiling |
| Bullet manager (3) — GDD | Hard | `clear_all()` |
| Chain tracker (7) — GDD | Soft | Gap rule G ≤ 45 |
| Collision, damage and lives (6) — GDD | Soft | `spawn_is_clear` (through Enemy) |
| Era shift (19) | Hard | `era_ready`, `era_for_stage`, role tables, `StripMap` ([GDD](era-shift-and-plane-evolution.md)) |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Era shift (19) | Hard | `stage_started`, `stage_cleared`, `load_stage` timing | yes |
| Parallax and environment (23) | Hard | `bg_sections`, `scroll_changed`, `ScrollClock` | yes |
| Audio (24) | Soft | `stage_cue`, `warning_started` | yes |
| Stage-end tally (21) | Soft | `stage_cleared` | yes |
| HUD (20) | Soft | `warning_started`, `wave_started` (progress track) | yes |
| Powerups (13), Scoring (8), Chain tracker (7), Bullet manager (3) | Hard | `stage_started`, `stage_cleared` events | yes |
| Tutorial (30) | Soft | `stage_started`, `wave_started`, `mechanic_previewed`, `lead_in_ticks` | yes ([GDD](tutorial.md)) |
| Online leaderboards, boss rush (32) | Soft | Boss-only stages (`waves = []`, `home_stage`) | yes ([GDD](online-leaderboards-boss-rush.md)) |
| Boss (14) | Hard | `start_intro` caller; guarantees field clear | yes |

**Amendments to other docs** (apply at wrap-up)

1. **Systems index:** row 16 status `**Designed** (pending review) — [GDD](wave-and-stage-director.md)`; Depends on `10, 13, 15` becomes `1, 3, 9, 10, 13, 14, 15, 18`; progress tracker adds this GDD.
2. **Enemy and AI** (`enemy-and-ai.md`): (a) Rule 8 `params` gains `preview`, `strip_tags[]` and `max_life_ticks`; (b) new event `spawn_failed(event_id, reason)` and query `alive_count()`; (c) Open Question 4 closed: co-op SMALL groups scale per Co-op F5, owned by the Director; (d) F9b "wave-level bullet budget" is replaced by the Director's wave curve caps (60 / 80 / 100 / 120 / 150) plus the 1,700 ceiling; (e) Open Question 6 closed: 8 carriers per stage, at least 1 per wave; (f) Wave director row in Dependencies points to this GDD.
3. **Boss power budget** (`boss-power-budget.md`): (a) Rule 22(d) wording: "preview carriers of one mechanic alive at once never exceed `preview_alive_max`; in waves 1 to 4 only the wave's own mechanic is spawned"; wave 5 has four alive by design; (b) Open Question 1 closed: at least 2 successive carriers per preview wave, 3 for SMALL carriers (Jet `fighter`), no early respawn; the combination spawns once, at wave tick 900 (Stage 1) / 900 (Stage 2) inside 160 ticks; (c) Edge case "carrier hp is short": note the Jet `fighter` (hp 50) carriers die in about 0.1 s of reference fire; see Director Open Question 2 (`preview_hp_floor`).
4. **Powerups and drops** (`powerups-and-drops.md`): Open Question 3 closed: `stage_cleared` fires at least `sweep_min_ticks` (90) after `boss_defeated`; Wave director row: GDD exists; carrier plan in `wave-and-stage-director.md` (8 per stage: 4 SMALL, 2 MEDIUM, 2 LARGE, ≥ 1 per wave).
5. **Boss and boss parts** (`boss-and-boss-parts.md`): Wave director row: GDD exists; the WARNING (150 ticks) starts at `E5 + 90` and `start_intro` at `E5 + 240`; field clear at `E5 + 60`; watchdog for `boss_gone` at `D + 360`.
6. **Game events and session** (`game-events-and-session.md`): (a) add events `wave_started(stage, wave, total)`, `wave_ended(stage, wave, early)`, `warning_started(ticks)`, `scroll_changed(v_x100)`, `stage_cue(cue_id, transition)`, `mechanic_previewed`, `era_ready(era_id)`; (b) state table row "Stage → Tally": trigger should read `stage_cleared` (fired by the Director after the sweep), not `boss_defeated`; (c) `stage_started(stage_index, era)` is emitted by the Director after `era_ready`.
7. **Coop and Team Chain** (`coop-and-team-chain.md`): Wave director row: GDD exists; `coop_spawn_cap` is a `spawn_pct` limit (100 to 160, per wave).
8. **Chain tracker** (`chain-tracker.md`): Wave director row: GDD exists; the validator enforces `G ≤ 45` outside REST and the boss block.
9. **Bullet pattern library** (`bullet-pattern-library.md`): F9 scope note: the cross-enemy check is `StageValidator` V-D5.
10. **Bullet manager** (`bullet-manager.md`): Wave director row: `clear_all()` at `E5 + 60` and at `stage_cleared`.
11. **Art bible** (`art-bible.md`): 7.4 Warning screen: "lasts about 2.5 s" = 150 ticks, starting only on a clear field (satisfied by Director Rule 23).
12. **Registry** (`design/registry/entities.yaml`): add the entries from the report; add `wave-and-stage-director` to `referenced_by` of `chain_window`, `move_speed`, `enemy_max_alive`, `enemy_hurtbox_budget`, `enemy_cap`, `coop_spawn_step`, `play_top`, `spawn_clearance`.
13. **Save, settings and high scores** (`save-settings-high-scores.md`): debug stage select / wave skip set `run.debug_tainted`; tainted runs are not ranked (provisional; needs a field in `RunRecord`).

**Bidirectional check:** Enemy (10), Powerups (13), Boss (14), Boss power budget (15), Co-op (18), Pattern library (9), Bullet manager (3), Chain tracker (7) and Session (1) already name the Wave director as a provisional dependency; amendments above make each row point to this GDD. Era shift (19), Parallax (23), Audio (24), Tally (21), HUD (20) and Tutorial (30) must list it when written.

## Tuning Knobs

**Owned by this system** (`data/stages/stage_rules.tres` for globals; `data/stages/stage_<n>_<era>.tres` per stage)

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `lead_in_ticks` | 120 | 60 to 240 | Stage card cut short | Dead time at start | F7 |
| Wave `length_ticks` (S1) | 2,100 / 2,280 / 2,400 / 2,520 / 2,700 | 1,800 to 3,600 | Not enough room for previews and carriers | Stage over 5:00 | F7, V-D9 |
| Wave `length_ticks` (S2) | 2,160 / 2,340 / 2,520 / 2,640 / 2,820 | 1,800 to 3,600 | As above | As above | F7 |
| REST `gap_ticks` | 180 (waves 2 to 3), 150 (4 to 5) | 120 to 300 | No breathing room | Dead air | Chain gap, pod pickup (drop falls 550 ticks) |
| `early_clear_gap` | 24 | 0 to 45 | Next wave starts on top of the kill | Chain drops after a fast clear | F6 `bridge_entry_max` |
| `bridge_entry_max` | 21 | 0 to 45 - `early_clear_gap` | Waves must start too close | Gap over 45 | F6 |
| `chain_gap_budget` | 45 | 30 to 60 | Over-constrained waves | Chains drop between groups | Chain tracker F1 |
| `lane_cover_min` | 0.70 | 0.5 to 0.9 | Chainless waves | Waves feel like rails | F6 |
| `wave_curve_cap[1..5]` | 60 / 80 / 100 / 120 / 150 | rising | Waves too thin | Waves rival the boss | F3, Boss power budget |
| `cap_margin` | 2 | 0 to 6 | Spawn refusals | Under-filled waves | Enemy caps |
| `preview_carriers_min` | 2 (SMALL carrier: 3) | 2 to 4 | Preview missed | Preview wave is only previews | AC-42 exposure |
| `requeue_delay` / `requeue_max` | 60 / 2 | 30 to 120 / 0 to 3 | Lost carriers | Late carriers | Enemy retry 30 |
| `carrier_gap_min` | 180 | 120 to 600 | Pod flood | Pod drought | Powerups F2 |
| `scroll_v_x100` per wave (S1) | 80 / 90 / 100 / 100 / 110 | 40 to 200 | Slow, boring | Ground targets pass too fast | F8, ground exposure |
| `scroll_v_x100` per wave (S2) | 120 / 130 / 140 / 150 / 150 | 40 to 200 | As above | As above | F8 |
| `boss_scroll_v_x100` | 25 | 0 to 60 | Dead background | Boss feels in motion | Boss intro, Parallax |
| `scroll_blend_ticks` | 120 | 60 to 240 | Jerky | Slow reaction | F8 |
| Boss block offsets | 0 / 60 / 90 / 240 / 480 | see Rule 24 | Banner over bullets | Dead time before the boss | Art bible 7.4, Boss intro |
| `warning_ticks` | 150 | 120 to 180 | Warning unreadable | Dead time | Art bible 7.4 |
| `sweep_min_ticks` | 90 | 75 to 180 | Items cut off | Dead time after kill | Powerups sweep (73 ticks) |
| `stage_par` window | 14,400 to 18,000 | 12,000 to 21,600 | Short stage | Long stage | F7 |
| `coop_spawn_cap` per wave | 160 | 100 to 160 | Co-op waves thin | 4P over 1,700 | Co-op F5 |

**Owned elsewhere:** carrier drop tables and pity (Powerups 13); `coop_spawn_step` 20 (Co-op 18); enemy caps 28 / 32, `spawn_retry_ticks` 30, `max_life_ticks` (Enemy 10); preview rows, wave fractions, `preview_alive_max`, `combo_window_ticks` (Boss power budget 15); intro, death and enrage timings (Boss 14); `chain_window` 60 (Chain tracker 7); `enemy_cap` 2,000 (Bullet manager 3); art for backgrounds and banner (Art bible, Parallax 23); mix (Audio 24).

**Balance rationale:** wave curve caps follow the Boss power budget wave fractions (0.32 to 0.45 of the stage cap at the first four waves, 0.75 at wave 5) in spirit: the Director's own N-based caps rise 60 → 150 so waves 1 to 4 sit well under the boss and wave 5 is a tense rehearsal. Lengths target a 4:00 to 5:00 stage with a boss block of about one minute (concept §5, "5-Minute Loop").

## Visual/Audio Requirements

The Director draws nothing in the play field. Draw layers are art bible §6.8. Bullets always win: no Director effect draws over enemy bullets (layer 8). No Void Indigo (`#4A5CFF`) or Ink (`#0B0B2A`) on any Director-triggered mark.

**V1. WARNING plate** (drawn by the HUD at layer 11; art bible 7.4)
- Starts at `E5 + 90`, lasts **150 ticks**, only over a field with no enemy bullets (Rule 23).
- Amber `#FFB000` with black diagonal stripes, two 24 px stripe bands framing a central bilingual plate "সতর্কতা / WARNING" in the middle third. Stripes scroll 45 px/s in integer steps (3 px every 4 ticks). Text opacity pulses 100 % to 60 % at 1.5 Hz at most; never blinks; no full-screen flash.
- Eases out over the last 20 ticks as the scroll-stop starts at `E5 + 240`.

**V2. Scroll-stop:** the scroll eases from the wave 5 speed to 0.25 px/tick over 60 ticks; L2/L3 are replaced by static arena plates and L0/L1 crawl (Parallax 23, 2026-11-03); no screen shake.

**V3. Rest beats:** the field is quiet; no banner or text; the music drops one layer (A2). Pods and gems keep falling and flying as normal.

**V4. Stage progress track** (HUD, art bible 7.4): a thin 5-segment track plus a boss pip in Row B/D outside boss fights; segment `n` fills on `wave_started(·, n, 5)`; fades 3 s after `stage_started`. Era Accent colour; never Void Indigo.

**V5. Background sections** (ids for Parallax 23; art by art-director). *(2026-11-03: the boss ids are static plate sets (Parallax Rule 19); the first section loads at `stage_started`. The stage validator also calls `EnvValidator` V-E1 to V-E5 (Parallax).)*

| Trigger | Stage 1 (1941) | Stage 2 (1970s) |
|---|---|---|
| Wave 1 | `s1_open_sea` — dawn sea, cloud shadows | `s2_high_haze` — high altitude, haze bands |
| Wave 2 | `s1_coast` — fishing boats, shoreline | `s2_river_delta` — green delta, radar masts |
| Wave 3 | `s1_harbour` — moored fleet | `s2_airbase` — runways and hangars |
| Wave 4 | `s1_fortress_approach` — bunkers, AA nests | `s2_carrier_fleet` — escort ships |
| Wave 5 | `s1_fortress_walls` — walls and gun decks | `s2_flight_deck_approach` — carrier wake |
| Boss warning | `s1_boss_deck` — the Fortress deck, darker vignette | `s2_boss_sea` — open sea, carrier wake |

**A1. Music cues** (`stage_cue`; Audio 24 mixes)

| Trigger | Cue | Transition |
|---|---|---|
| `STAGE_START` | `sN_start` | cut in |
| `WAVE_START(n)` | `sN_wave_n` | add a layer per wave (intensity up) |
| `REST_START` | `sN_rest` | drop one layer over 30 ticks |
| `WARNING` | `warning_siren` | duck music; siren once |
| `BOSS_INTRO` | `sN_boss_intro` | rumble rises (Boss audio) |
| `BOSS_STARTED` | `sN_boss` | full mix |
| `BOSS_ENRAGED` | `sN_boss_enrage` | up one step |
| `BOSS_DEFEATED` | `victory` | stinger, music out over 60 ticks |
| `STAGE_CLEARED` | `tally` | calm loop |

**A2. SFX:** the WARNING siren (once, ≤ 150 ticks, no strobing); a soft low pad on `WAVE_START` for the first 3 waves only is optional.

## UI Requirements

Player-facing: only the WARNING plate (HUD draws it from `warning_started`) and the wave progress track (V4, HUD). Both are presentation-only. Stage name card on `stage_started` uses `name_key` (Localization), shown for the lead-in (120 ticks).

📌 **UX Flag**: run /ux-design for the HUD stage-progress track and WARNING plate before writing epics.

**Debug only (development builds):**
- **Stage select**: jump to stage 1 to 4 (default loadout); sets `run.debug_tainted`.
- **Wave skip / restart**: `skip_wave` ends the current wave now (queued spawns dropped, alive enemies `despawn_all("debug")`), `restart_wave` reloads the wave start with the same `N`; sets `run.debug_tainted`.
- **Go to boss**: jumps to `E5 + 90` (WARNING).
- **Timeline overlay**: wave index, `wave_t`, next event, `N_scene` vs `wave_curve_cap`, alive and hurtbox counts vs 26 / 30, carriers seen, previews seen, `events_dropped`.
- **Fast-forward**: runs the nominal timeline to tick T without drawing (for the validator and capture).
- **Lint print**: the validator prints per-check numbers (peaks, `spacing_min`, `T_par`).

## Acceptance Criteria

Defaults used: `lead_in_ticks` 120, `early_clear_gap` 24, `bridge_entry_max` 21, `chain_gap_budget` 45, `lane_cover_min` 0.70, `wave_curve_cap` 60 / 80 / 100 / 120 / 150, `cap_margin` 2, `preview_carriers_min` 2 (SMALL carrier 3), `requeue_delay` 60, `requeue_max` 2, `carrier_gap_min` 180, `sweep_min_ticks` 90, `warning_ticks` 150, boss block offsets 0 / 60 / 90 / 240 / 480, `boss_scroll_v_x100` 25, `scroll_blend_ticks` 120, `coop_spawn_step` 20, `preview_alive_max` 1, `combo_window_ticks` 180, `enemy_max_alive` 28, `enemy_hurtbox_budget` 32, 60 ticks/s. Stage 1 starts `[0, 2,100, 4,560, 6,960, 9,630]`, `E5` 12,330; Stage 2 starts `[0, 2,160, 4,680, 7,200, 9,990]`, `E5` 12,810.

**Test setup:** logic lives in node-free `RefCounted` classes: `StageDirector` (`tick()`), `StageValidator` (V-D1 to V-D11, uses `StageLint` and `PreviewBuilder` from Boss power budget, `PatternMetrics` from the Pattern library). Injected: loaded `.tres` files (`data/stages/*.tres`, `data/enemies/<era>/roles.tres`, `data/boss_budget/*.tres`, `data/bosses/*.tres`); a `FakeEnemyManager` that records `spawn(...)` calls, alive count, and returns scripted `spawn_failed`; a `FakeBoss` (scripted `boss_started`, `boss_defeated(reason)`, `boss_gone`); a `FakeBulletManager` recording `clear_all`; a fake Session (`N`, `any_active`, pause); a fake event bus recording emissions in order; a seeded RNG that is passed in and must never be called. Tests in `tests/unit/test_wave_director_[timeline|spawn|carriers|preview|density|chain|bossblock|flow|data].gd`, `extends SceneTree` like `tests/unit/test_chain_tracker.gd`, named `test_wave_[scenario]_[result]`. Numbers are read from the `.tres` files, never literals, except the golden tables (AC-04, AC-12, AC-17, AC-20), whose values are the spec. Tags: [Unit] headless logic · [Integration] real Enemy manager, Boss, Powerups · [Perf] reference machine · [Manual] human. Tolerance: 0.05 on `N_scene`.

### Data and structure (Rules 1 to 5)

- **AC-01 [Unit] (Rule 1, V-D1):** Stage 1 and Stage 2 load with exactly 5 waves each, ids unique, events sorted by `(tick, id)`; a copy with 4 waves, an unsorted pair, or a duplicate id fails V-D1 with the offending id.
- **AC-02 [Unit] (Rule 3):** a `SpawnEvent` with a float field, or a role not in the era table, fails V-D1; every Stage 1 and 2 event uses only `fodder`, `fighter`, `gunner`, `heavy`.
- **AC-03 [Unit] (Rule 5, clock):** with `any_active` false for 100 ticks, `wave_t` and `stage_t` advance by 0 and no event is issued; resumed, the next event fires on its own tick; paused ticks (no `tick()` call) change nothing.
- **AC-04 [Unit] (F1 timeline):** Stage 1 nominal starts = `[0, 2,100, 4,560, 6,960, 9,630]`, `E5` = 12,330; Stage 2 = `[0, 2,160, 4,680, 7,200, 9,990]`, `E5` = 12,810; boundaries BRIDGED / REST / BRIDGED / REST with gaps 0 / 180 / 0 / 150.

### Spawning (Rules 6 to 11)

- **AC-05 [Unit] (Rule 6):** the Director issues the events of wave tick `t` to the fake Enemy in `id` order on tick `t` exactly, once; `params` carry the spawn `event_id`, `wave_intensity` = `(index - 1) x 25 / 100` (0, 0.25, 0.5, 0.75, 1.0) and the current scroll speed; the Director's step runs before the Enemy step in the tick order.
- **AC-06 [Unit] (Rule 7, F2):** a SMALL scaled group of base 6 spawns 6 / 8 / 9 / 10 enemies at N = 1 / 2 / 3 / 4; base 5 gives 5 / 6 / 7 / 8; with `coop_spawn_cap` 140, base 6 at N = 4 gives 9; a join after the group's first tick does not change its size.
- **AC-07 [Unit] (Rule 8):** at N = 1 and N = 4, Stage 1 and Stage 2 each spawn exactly 8 carriers (4 SMALL, 2 MEDIUM, 2 LARGE); no carrier event has `scaled` true or `count` above 1; no carrier is also a preview.
- **AC-08 [Unit] (Rule 9, requeue):** a carrier refused on its tick is re-issued 60 ticks later; refused again, it is re-issued once more (2 requeues total) then logged `carrier_lost`; a requeue with fewer than 300 ticks left in the wave is not made; a refused non-carrier SMALL is dropped, `events_dropped` +1.
- **AC-09 [Unit] (Rule 10):** every event of both stages passes Enemy F10 for `play_top` 48 and 72 (`y(0) + y_shift + r_e + 8 <= play_top` for top entries; side entries beyond `-r_e - 8` / `360 + r_e + 8`).
- **AC-10 [Unit] (Rule 11, no RNG):** a full dry simulation of Stage 1 and 2 makes 0 calls to the injected RNG; changing the fake player positions, scores and chains changes no spawn.

### Waves and rests (Rules 12 to 17)

- **AC-11 [Unit] (Rules 13, 14, F1):** Stage 1 wave 1 with the field cleared at `wave_t` 1,980 ends at 2,004 and wave 2 starts then; cleared at 2,090, wave 1 ends at 2,100; a clear before the last event issues does not end the wave; an enemy appearing during the 24-tick timer cancels it.
- **AC-12 [Unit] (Rule 15 rest, golden):** a REST wave cleared early keeps its full gap: Stage 1 wave 2 cleared at 2,000 → ends 2,024, wave 3 starts at 2,204 (+180); a BRIDGED boundary starts the next wave at the end tick (+0).
- **AC-13 [Unit] (Rule 13 stragglers):** at the nominal end with 3 enemies alive, none is removed; their nominal exit is counted in F3 for the next wave.
- **AC-14 [Unit] (Rule 16, V-D8, F6):** a stage copy with a 58-tick stretch and no targetable enemy inside wave 3 fails V-D8; the same stretch inside a REST gap passes; lane group jumps of 158 px fail and 157 px pass; lane cover 0.69 fails and 0.70 passes.
- **AC-15 [Unit] (Rule 15 bridge):** every BRIDGED wave start has a first group targetable within 21 ticks of its spawn; a first group at 22 ticks fails V-D7; `early_clear_gap` 24 + 21 = 45 equals `chain_gap_budget`.
- **AC-16 [Unit] (Rule 17, F3):** Stage 1 `N_scene` peaks at N = 1: 26.7 / 49.3 / 75.8 / 88.3 / 111.0 (strictly rising, each under 60 / 80 / 100 / 120 / 150); at N = 4: 40.7 / 70.3 / 96.8 / 116.3 / 139.0; Stage 2 at N = 1: 25.0 / 39.3 / 59.9 / 66.5 / 74.5; at N = 4: 39.4 / 53.7 / 79.1 / 85.7 / 93.7; all ≤ 1,700.
- **AC-17 [Unit] (V-D5 failure, golden):** a wave with `N_scene(1)` = 1,100 fails at N = 4 (1,760); with `coop_spawn_cap` 140 it computes 1,540 and passes; a wave over its curve cap by 1 fails; non-rising peaks fail.
- **AC-18 [Unit] (F4 budgets):** Stage 1 N = 4 peaks: alive 16 / 18 / 19 / 22 / 22 and hurtboxes 17 / 19 / 22 / 25 / 28; Stage 2: alive 18 / 20 / 22 / 22 / 22 and hurtboxes 18 / 21 / 25 / 25 / 25; a third wave-5 heavy (31 hurtboxes) fails V-D6.

### Boss foreshadowing (Rules 18, 19)

- **AC-19 [Unit] (Rule 18, V-D2):** `StageLint.check_stage` passes for both stages: wave `N` spawns only `preview = mechanic N` (Fortress: m1 gunner, m2 gunner, m3 heavy, m4 heavy; Jet: m1 fighter, m2 fighter, m3 heavy, m4 gunner); wave 5 spawns all four inside 160 ticks (≤ 180); no early preview of a later mechanic.
- **AC-20 [Unit] (successive carriers, golden):** Stage 1 preview carriers: wave 1 at 300 and 1,140; wave 2 at 200 and 960; wave 3 at 300 and 1,200; wave 4 at 400 and 1,400; wave 5 set at 900 / 950 / 1,000 / 1,060. Stage 2: wave 1 at 240 / 700 / 1,160; wave 2 at 240 / 700 / 1,160; wave 3 at 300 and 1,200; wave 4 at 400 and 1,200; wave 5 at 900 / 940 / 1,000 / 1,060. Each next carrier starts after the previous one's nominal exit (F8 ground life or path life); at least 2 per wave (3 for Jet waves 1 and 2).
- **AC-21 [Unit] (alive max):** on the nominal timeline at most 1 preview carrier of any one mechanic is alive; in waves 1 to 4, at most 1 preview carrier in total; wave 5 has 4 alive between ticks 1,060 and 1,482 (Stage 1) and 4 alive for at least 300 ticks (Stage 2, SMALL carriers on the slow path).
- **AC-22 [Unit] (Rule 18 event):** `mechanic_previewed(boss_id, mechanic_id, wave)` fires once per mechanic, at its first preview spawn.
- **AC-23 [Unit] (Rule 19, F9):** Stage 2: a delta jet spawned in wave 1 at tick 200 has `strip_tags` containing `behaviour:accelerate`; at tick 240 it does not; waves 1 to 3 natives carry `strip_tags` with `option:aim_lock`; a wave 4 native at tick 380 is stripped, at tick 400 it is not; Stage 1 strips nothing (no novelty tags).
- **AC-24 [Unit] (previews are not carriers):** no event has both `carrier` and `preview`; a preview carrier's drop request count is 0 when killed (integration with Powerups).

### Carriers (V-D4, F5)

- **AC-25 [Unit] (cadence, golden):** Stage 1 carrier stage ticks 700 / 2,600 / 3,900 / 6,360 / 7,160 / 7,860 / 9,930 / 11,430 (`spacing_min` 700); Stage 2 920 / 2,760 / 3,860 / 6,480 / 7,400 / 8,900 / 10,290 / 11,890 (`spacing_min` 920); a copy with two carriers 179 ticks apart fails; 180 passes.
- **AC-26 [Unit] (per wave):** carriers per wave: S1 and S2 W1 = 1 SMALL; W2 = 1 SMALL + 1 MEDIUM; W3 = 1 LARGE; W4 = 1 SMALL + 1 MEDIUM; W5 = 1 SMALL + 1 LARGE; a copy with a wave of 0 carriers fails.
- **AC-27 [Unit] (worst case across boundary):** the validator computes cross-boundary spacing with the earliest wave end (`last_event + 24`); a copy that places a carrier at tick 100 of a wave following a wave whose last carrier is at its tick `last_event - 50` fails (spacing 174 < 180).

### Scroll, background, music (Rules 20, 21)

- **AC-28 [Unit] (F8):** blend 80 → 90 over 120 ticks gives 85 at `t` = 60 and 90 at `t` = 120; ground life for scroll 80 / 90 / 110 / 120 / 130 / 140 / 150 = 800 / 712 / 582 / 534 / 493 / 458 / 427; a ground enemy spawned mid-blend follows the live ground anchor `S` (Parallax F4: `ground_dy = (S div 100) - (S_spawn div 100)`) *(2026-11-03, replaces "takes the current integer speed and keeps it")*.
- **AC-29 [Unit] (triggers):** `bg_sections` and `music_cues` switch on `WAVE_START(n)`, `REST_START`, `WARNING`, `BOSS_STARTED`, etc.; an early clear moves the `WAVE_START(2)` cue earlier by the same amount as the wave; no cue is bound to an absolute tick.

### Boss block and flow (Rules 22 to 27)

- **AC-30 [Unit] (offsets, golden):** with `E5` = T: at T `wave_ended(5)` and `force_exit` for all alive; T + 60 `despawn_all("boss_intro")` then `clear_all()`; T + 90 `warning_started(150)`; T + 240 `Boss.start_intro(boss_id, stage_number)` and scroll eases to 25 over 60 ticks; the fake Boss fires `boss_started` at T + 480.
- **AC-31 [Unit] (field clear):** at `warning_started` the fake Bullet manager reports 0 enemy bullets and the fake Enemy 0 alive; in a copy where `clear_all` is skipped the test fails; `start_intro` is never called while enemy bullets exist.
- **AC-32 [Unit] (stage clear timing):** boss_defeated at D, `boss_gone` at D + 180 → `stage_cleared` at D + 180; `boss_gone` at D + 40 (TIMEOUT retreat) → `stage_cleared` at D + 90; `boss_gone` never → `stage_cleared` at D + 360 with an error log; a second request is ignored; `stage_cleared` calls `despawn_all("stage_end")` and `clear_all()` once.
- **AC-33 [Unit] (flow order):** event order across a full stage in the fake bus: `stage_started`, `wave_started(1)`, ..., `wave_ended(5)`, `warning_started`, `boss_started`, `boss_defeated`, `stage_cleared`; then, after the fake Tally and `era_ready`, `stage_started` of the next stage; after the last stage no `load_stage` is called.
- **AC-34 [Integration] (Powerups sweep):** with a real Powerups and 40 gems + 2 pods in the field at `boss_defeated`, all are collected before `stage_cleared`; items left at `stage_cleared` are removed with no Scoring calls (Powerups AC-34).
- **AC-35 [Integration] (Session):** `stage_cleared` takes Session to Tally; Chain is frozen at `boss_defeated` and drops `STAGE_END` at `stage_cleared`; the next stage's `stage_started` resets Scoring's stage breakdown and Powerups' pity counter and reseeds the drop stream with `hash(run_seed, stage_index, "drops")`.

### Validation (Rule 28)

- **AC-36 [Unit] (length, F7):** `T_par` = 15,813 (Stage 1) and 16,875 (Stage 2); both in 14,400 to 18,000; a copy with `length_ticks` of wave 5 = 3,600 gives 16,713 for Stage 1 and passes, one with a REST gap of 301 fails V-D9.
- **AC-37 [Unit] (V-D9 tail):** an event at `length_ticks - 119` fails; at `length_ticks - 120` passes; REST gaps of 119 and 301 fail, 120 and 300 pass.
- **AC-38 [Unit] (V-D10):** the boss-block table matches Rule 24; `sweep_min_ticks` 74 fails, 75 passes.
- **AC-39 [Unit] (determinism):** two dry runs of Stage 1 and 2 at N = 1 and N = 4 with scripted kills give equal spawn-log hashes; three runs with different RNG seeds give the same hash; load order of the resources does not change the result.
- **AC-40 [Unit] (determinism under early clear):** the sequence of spawn events (after removing the time offset of each wave) is identical with and without early clears.

### Edge cases

- **AC-41 [Unit] (no active slot):** during a Continue with all slots Dead, the fake Enemy receives 0 new spawns; after respawn the wave continues at the same cursor.
- **AC-42 [Unit] (join mid-wave):** a join between two groups changes the next group size only.
- **AC-43 [Unit] (missing budget):** a stage whose boss has no budget file: debug build asserts; release logs and plays, with no wave 5 combination.
- **AC-44 [Unit] (debug tools):** `skip_wave` drops queued spawns, despawns alive enemies and sets `debug_tainted`; stage select sets `debug_tainted`.

### Performance

- **AC-45 [Perf] (tick):** `StageDirector.tick()` averages ≤ 0.02 ms and p99 ≤ 0.05 ms over a full Stage 2 at N = 4 on REF-PC; allocation delta per tick over 1,000 ticks is 0 (group expansion uses a fixed queue of 64).
- **AC-46 [Perf] (load and lint):** `StageValidator` over both MVP stages (including `StageLint` and density) completes in ≤ 300 ms offline; stage load validation in a release build is skipped (logged only) and `load_stage` completes in ≤ 5 ms.

### Playtest (Manual)

- **AC-47 [Manual] (length):** 6 testers play Stage 1 solo; median total (excluding the tally) is 4:00 to 5:15 and the boss block (WARNING to `boss_gone`) is 50 to 80 s.
- **AC-48 [Manual] (chain lane):** an expert Lancer run holds a chain through at least 70 % of waves 1 to 5 non-rest time at N = 1; no tester reports a "dead gap" outside the two rests.
- **AC-49 [Manual] (pacing):** 8 testers rate "waves get harder each time" yes for Stage 1 and 2; at least 6 of 8 say the boss was harder than wave 5; fewer than 2 say a rest felt too long.
- **AC-50 [Manual] (4P density):** a real 4P run of each stage keeps peak enemy bullets ≤ 1,700 with refusals < 0.1 % and no spawn refusal for a carrier.
- **AC-51 [Manual] (warning):** a frame capture of the WARNING plate shows no enemy bullet on screen and no strobing; pulses are ≤ 1.5 Hz.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | `preview_alive_max` 1 is read per mechanic (waves 1 to 4 one in total, wave 5 four at once). Boss power budget Rule 22(d) is ambiguous; confirm the wording. | Boss power budget (15) | Next review |
| 2 | Jet `m1` and `m2` previews ride a `fighter` (hp 50, 1 to 3 hits): a player can kill the carrier before its first volley (start_delay 48). The Director spawns 3 successive carriers, but exposure is still weak. Option: `preview_hp_floor` (Enemy sets hp ≥ 300 on SMALL preview carriers, killing them in about 0.5 s) or move the previews to a `gunner`. | Enemy (10), Boss power budget (15) | First Jet playtest |
| 3 | Death-time wave clock: the clock stops while nobody is Active. Is a solo respawn (60 ticks) a free breather the designer wants? | Designer | First playable |
| 4 | ~~Who emits `stage_cleared`: the Director (this GDD) vs Boss `boss_gone` → Session. Session's table says Tally starts at `boss_defeated`; this GDD moves it to `stage_cleared`. Confirm.~~ **Closed 2026-11-03:** the Director emits `stage_cleared(stage_index)`; Session's state table now starts the Tally at `stage_cleared` (game-events-and-session.md, States and Transitions, wave 3a). | Session (1) | Session review |
| 5 | ~~`boss_scroll_v_x100` 25 vs the Boss GDD's "scroll-stop" (a full stop). Confirm the slow drift.~~ **Closed 2026-11-03:** drift 25 confirmed; L0/L1 crawl over static L2/L3 plates (parallax-and-environment.md Rule 19). | Boss (14), Parallax (23) | Parallax GDD |
| 6 | Wave 5 combination spawns once. Should a second set follow at about wave tick 1,900 as a reminder (AC-42 exposure in Boss power budget)? | Designer | Playtest |
| 7 | Target stages 3 and 4: outlines, wave lengths and scroll speeds are not designed. The structure (5 waves, 2 REST, boss block) is fixed; the era ladder gives Curve (stage 3) and Warp (stage 4). | Level designer | Target milestone |
| 8 | Early-clear gap and chain: if playtests show chains dropping after fast clears, raise `bridge_entry_max` handling or remove the skip. | Designer | Chain playtest |
| 9 | Optional per-run variation (mirror flips from `run_seed`) was rejected for MVP (score-attack consistency). Revisit for a post-launch "variant" mode? | Producer | Post-MVP |
| 10 | ~~Do HUD stage-progress segments need a text label (bilingual) for accessibility, or is the colour + shape enough?~~ **Closed 2026-11-03:** no label; shape and count suffice (accessibility-options.md). | UX, Accessibility (28) | HUD UX |
| 11 | Dropped or refused SMALL non-carrier events are not replaced. Is that acceptable at 4P if the cap margin is 2? | Designer | 4P playtest |
| 12 | Wave curve caps (60 / 80 / 100 / 120 / 150) are estimates from `N_def` tables; re-fit once Enemy F9 runs on real data and the Bullet manager profiler counters exist. | Programmer, designer | Bullet bench |

