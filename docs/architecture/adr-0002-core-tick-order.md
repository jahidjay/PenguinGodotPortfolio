# ADR-0002: Core Tick Order, GameLoop and Event Delivery

## Status
**Accepted (2026-11-03)** — accepted with the design set at the Concept → Pre-Production gate. The whole-game tick bench (Validation V1) and the pause/ordering integration tests (V2, V3) remain **required validation during implementation**: a failure amends this ADR rather than reopening the decision. Supersedes ADR-0001's tick diagram, its `game_loop_tick_order` registry entry and the pause clause of its Decision 5 ("Pause = tree pause"); everything else in ADR-0001 stands.

## Date
2026-11-03

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (2026-11-03); ADR-0001 |
| **Post-Cutoff APIs Used** | None knowingly. Relies on `_physics_process`, `Node.process_mode` (`PROCESS_MODE_ALWAYS` / `PAUSABLE`), `Node.process_physics_priority`, `SceneTree.paused`, `Engine.get_physics_frames()`, `Time.get_ticks_usec()` — all pre-4.3 APIs, **behaviour UNVERIFIED for 4.7** (none is listed in the 4.4–4.7 upgrade pages). |
| **Verification Required** | (1) `process_physics_priority` orders the InputSampler autoload before the GameLoop in 4.7 (fallback built in: idempotent `service_step()`, Decision 2). (2) A `PROCESS_MODE_ALWAYS` node keeps receiving `_physics_process` while `SceneTree.paused` is true. (3) Signal emission is synchronous (unchanged since 3.x, still assumed). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GDScript, node-free cores, 60 Hz fixed tick, budgets, reference machines) |
| **Enables** | ADR-0003 (determinism/replays: the `SimWorld` boundary), ADR-0004 (scene host, blocking-load discard), ADR-0005 (game-speed gate); every gameplay epic's integration wiring |
| **Blocks** | Integration of any two gameplay systems in one tick (Enemy + Bullets + Collision + Chain …) until this is Accepted |
| **Ordering Note** | Write `SimWorld` + `GameLoop` with stub systems first (V2/V3 run on stubs); real systems slot in as their epics land. |

## Context

### Problem Statement
ADR-0001 fixed a 9-step tick but 20+ GDDs have since added sub-steps (3b, 3c, 6a–6c, 7b, Director 3a, ScrollClock, CB, Powerups, HUD, Tutorial, ReplayRecorder, TouchMapper), two systems claimed step 6b (wave 3a I1), and several timing questions were left "→ core wiring ADR": who ticks Era shift and the Tally, when events are seen by other systems (same tick or next), how pause interacts with an autoload sampler and menus, and whether the sum of all budgets fits a 60 Hz frame on REF-WEB. One authoritative order is needed before systems are integrated.

### Constraints
- 60 Hz integer ticks, no `delta` in logic, node-free `RefCounted` cores (ADR-0001).
- Input must be sampled before any gameplay system and must run while paused (Input Rule 9).
- Same inputs + same seed → same `state_hash()` on every frame rate (BM AC-37/38, Pattern AC-43, Player AC-?2).
- Presentation (HUD, VFX, Audio, Parallax view) must never change simulation results (Accessibility AC-07, Audio AC-38).
- A headless verifier must be able to run the simulation without nodes or rendering (Online leaderboards Rule 24, ADR-0003).

### Requirements
- One numbered step list that every GDD can cite; existing step numbers (3b, 3c, 6a, 6b, 6c, 7b) keep their meaning.
- Deterministic event delivery: a rule that tells, for any producer/consumer pair, whether the consumer sees the event this tick or next.
- Pause semantics that do not depend on scene-tree pause propagation timing.
- A budget table summing every GDD's per-tick and per-frame cost against the 16.6 ms frame on REF-WEB.

## Decision

1. **Two layers.** `SimWorld` (`RefCounted`, node-free) owns every simulation system and runs steps 1–8 in `tick(t)`. `GameLoop` (Node, inside the run scene) is the thin driver: each physics step it runs the **admission gates** (Decision 4), then `SimWorld.tick()`, then the presentation step 9. Tests, the replay verifier and drills drive `SimWorld` directly.
2. **Input split.** The `InputSampler` autoload (`PROCESS_MODE_ALWAYS`, `process_physics_priority` lowest) runs `service_step()` **every physics step**: drains latched `_input` events, device assignment, menu verbs (real time), touch latching. It never clears gameplay latches there. At step 1 of a **game tick** the GameLoop calls `commit_sim_tick()`, which computes the per-slot `SimInput` (ADR-0003) and clears the latches. If priority ordering fails on 4.7, the GameLoop calls `service_step()` first; the call is idempotent per `Engine.get_physics_frames()`.
3. **The authoritative tick** (one game tick; `t` = game tick index, 0 at `run_started`):

```
PHYSICS STEP (60 Hz, every step, real time)
 0.  InputSampler.service_step()            autoload, ALWAYS (latch, devices, menu verbs)
     MenuHost menu models .tick()           ALWAYS, real time (ADR-0004); PauseModel while paused
     GameLoop admission gates               pause → load-discard (ADR-0004) → speed gate (ADR-0005)
     ── if admitted: one GAME TICK t ──────────────────────────────────────────────────────────
SimWorld.tick(t)   (simulation; hashed; headless-safe)
 1.  InputSampler.commit_sim_tick()         SimInput per slot (TouchMapper inside); decoder: edges, held_ticks, buffers
 1a. Session.begin_tick()                   apply queued slot requests: join / continue accept / forfeit / drop-in pick
 1b. ReplayRecorder.tick()                  when recording: SimInput changes + 1a run events (ADR-0003)
 2.  PlaneCore[0..3].tick()                 movement, state, registers pos/prev/radius/hittable
 3.  PlaneKit[0..3].tick(), then BombCore[0..3].tick()   requests: request_invuln, damage events, spawns, cancels
 3a. StageDirector.tick()  (DrillRunner in DRILL runs)   spawn calls, boss start, wave/warning events, play_top latch
     ScrollClock.tick()                     S += v_eff (after Director, before Enemy — Parallax Rule 3)
 3b. EnemyManager.tick()                    move, arm emitters, publish hurtboxes/bodies
 3c. BossController.tick()                  intro/fight clock, emitters (I_eff), publish parts
 4.  Pattern runners (emitters)             request_spawn; fire hold; flak fuse cap
 5.  CollisionReferee.begin_pass()          apply invuln requests, hittable snapshot, set_targets/set_hurtboxes
     BulletField.tick()                     spawn > age > move > cancel > hit > remove; cancel/clear reports
 6.  CollisionReferee.tick()                Phase A damage, Phase B player hits, invuln decrement, fire hold
 6a. EnemyManager.apply_results()           hp, deaths, cancel/drop requests
 6b. CriticalBreakCore.tick()               arm/commit; multiply uses chain count at start of tick
 6c. BossController.apply_results()         part hp, part kills, phases, critical, boss_defeated
 7.  BulletField.apply_pool_clear()         enemy-pool death clear requested this tick (no items)
 7b. PowerupSystem.tick()                   gems/drops from this tick's requests, move, pickup
 8.  run rules, in this order:
     8a ChainTracker.tick()  8b ScoringLedger.tick()  8c CoopRules.tick()
     8d Session.tick()  (timers, continue, slot states, run_ticks, game over)
     8e StageTally.tick()   8f EraShift.tick()
     checkpoint: if (t + 1) % 600 == 0 → state_hash() to ReplayRecorder (ADR-0003)
GameLoop presentation (game ticks only; frozen while paused; never hashed)
 9.  GameEvents flush                       emit this tick's event log as bus signals, in arrival order
     9a DrillTracker / HintEngine  9b HudModel  9c VfxDirector + EffectPool  9d ParallaxState  9e Audio policy
     tick guard: log game ticks over 8 ms with per-step timings (debug/profile builds)
RENDER FRAME (_process, 60 or 30 fps; real time)
     BulletRenderer pack · Powerups pack · VFX pack · HudView · ParallaxView · Display present (ADR-0004)
```

4. **Admission gates and pause.** The GameLoop node is `PROCESS_MODE_ALWAYS` and decides itself whether a physics step runs a game tick, in this order: (a) **pause** — `Session.is_paused()` true → no tick (and the speed accumulator is cleared, ADR-0005); (b) **load discard window** (ADR-0004); (c) **game-speed gate** (ADR-0005). Pause requests that arrive before or during step 0 of a physics step (from `_input`, window focus, pad disconnect, a Start verb in `service_step()`) take effect on that step: no game tick runs on it. `SceneTree.paused` is still set on pause so presentation nodes (pausable) freeze; the simulation does not depend on it. The resume beat (Menus Rule 30) runs on real-time physics steps with the game still paused.
5. **Event delivery.** Within `SimWorld`, every fact (`player_died`, `boss_defeated`, `stage_cleared`, `wave_started`, `tally_exit`, …) is appended to a preallocated **tick event log** in arrival order. A consumer reads the log at its own step:
   - consumer step **after** the producer step → **same tick**;
   - consumer step **at or before** the producer step → **next tick** (reads the previous tick's log).
   - **Requests** (`request_spawn`, `request_cancel`, `request_invuln`, `pay_stage_end_line`, …) are queued by the receiver and applied at the receiver's step with the same rule. Named exceptions (synchronous calls that return a value): `Chain.apply_critical_break`, `Boss.critical_break_finish`, `Input consume`/`clear_buffer` (now decoder-side, ADR-0003), `Scoring.preview_*`, read-only getters.
   - Consequences (consistent with the GDDs): Collision 6 → Chain 8 same tick; Boss 6c → Powerups 7b / Chain 8 same tick; Boss 6c → Director 3a next tick; part-kill cancel 6c → BulletField 5 next tick (accepted lag); kit `cancel_report` 5 → kits 3 next tick; fire hold set at 6 → runners 4 next tick; `tally_exit` 8e → EraShift 8f same tick; step 9 requests (e.g. DrillTracker ends a drill) → next tick.
   - **No simulation system connects to `GameEvents`.** The bus is presentation-only and is emitted only at step 9 from the log, so presentation code never runs mid-simulation and the headless verifier pays no signal cost.
6. **Ownership of ticking.** `SimWorld` ticks every system listed in steps 1–8 (this replaces "Era shift is ticked by Session" and similar GDD wording). The GameLoop owns the integer `game_tick` and the step-9 calls. `run_ticks` = completed game ticks.
7. **Budgets** (p99 per game tick on REF-WEB unless noted; from the GDDs and ADR-0001):

| Step | System | Budget (ms) | Source |
|---|---|---|---|
| 1 | InputSampler commit (+ TouchMapper on touch) | 0.10 (+0.05) | Input AC-15, Touch AC-50 |
| 1a/8d | Session | 0.02 *(proposed here)* | — |
| 1b | ReplayRecorder | 0.02 | Online AC-? (20 µs median) |
| 2 | PlaneCore ×4 | 0.05 *(proposed here)* | — |
| 3 | Plane kits ×4 / Bombs ×4 | 0.25 / 0.10 | Kits AC-41, SB AC-44, Bombs AC-51 |
| 3a | StageDirector (or DrillRunner) / ScrollClock + ParallaxState | 0.05 / 0.03 | Director AC-45 (REF-PC), Parallax AC-46 |
| 3b+6a | EnemyManager | 0.20 | Enemy AC-56 |
| 3c+6c | BossController | 0.05 | Boss AC-50 |
| 4 | Pattern runners | 0.20 | Pattern AC-53 |
| 5 | BulletField (accept / hard) | 1.50 / 2.50 | ADR-0001, BM AC-40 |
| 6 | CollisionReferee | 0.50 | Collision AC-53 |
| 6b | CriticalBreakCore | 0.02 | CB AC-43 (REF-PC) |
| 7b | Powerups (+ cancel burst tick) | 0.15 (+0.10) | Powerups AC-46/47 |
| 8 | Chain / Scoring / Co-op | 0.05 / 0.10 / 0.02 | Chain AC-44, Scoring, Co-op AC-37 |
| 8e/8f | StageTally / EraShift (not concurrent with combat) | 0.05 / 0.05 | Tally AC-50, Era AC-39 |
| 9 | Tutorial / HudModel / VFX tick / Audio policy | 0.05 / 0.05 / 0.25 / 0.10 | Tutorial AC-44, HUD AC-54, VFX AC-43, Audio AC-52 |
| **Σ tick** | at BM acceptance (1.5) / BM hard (2.5) | **≈ 4.1 / 5.1** | sum of p99s (conservative) |
| frame | BulletRenderer pack / Powerups pack / VFX pack | 1.00 / 0.10 / 0.35 | ADR-0001, Powerups, VFX |
| frame | HudView / ParallaxView / Display present delta | 0.30 / 0.30 / 0.50 | HUD AC-54, Parallax AC-47, Display AC-48 |
| frame | Audio mixing | 1.00 | Audio AC-53 |
| **Σ frame (scripted + mixing)** | | **≈ 3.55** | |
| **Total per 60 Hz frame** | 1 tick + 1 render | **≈ 7.7 ms (8.7 ms at BM hard)** of 16.6 ms | leaves ≈ 8 ms for engine render submission, WebGL driver, browser, GC |
| 30 fps phone frame | 2 ticks + 1 render | ≈ 11.8 ms of 33.3 ms | |

   Verdict: the frame fits on paper on REF-WEB with ~8 ms headroom, but two rows are proposals and several are REF-PC numbers; the whole-game bench (V1) is the real check. **Whole-sim gate: Σ steps 1–9 ≤ 4.5 ms p99 on REF-WEB**; render-side scripted ≤ 3.6 ms.
8. **Tick guard** (refines ADR-0001 Decision 5): times every game tick; over 8 ms → log with per-step breakdown; known blocking loads report as `load_hitch` instead (ADR-0004). It never changes the simulation. `max_physics_steps_per_frame` stays the catch-up limit.

### Key Interfaces

```gdscript
class_name SimWorld extends RefCounted
func tick(t: int) -> void                  # steps 1–8, fixed order
func state_hash() -> int                   # ADR-0003
var events: TickEventLog                   # this tick + previous tick, preallocated

class_name GameLoop extends Node           # PROCESS_MODE_ALWAYS, in the run scene
func _physics_process(_d: float) -> void   # gates → SimWorld.tick → step 9
func discard_backlog() -> void             # ADR-0004
var game_tick: int

# InputSampler (autoload): service_step() every physics step; commit_sim_tick() -> SimInput[4] at step 1
```

## Alternatives Considered

### Alternative A (chosen): SimWorld + GameLoop driver, event log, explicit gates
Described above.

### Alternative B: Keep ADR-0001 as is (tree pause, signals between gameplay systems)
- **Pros**: Less code; idiomatic Godot.
- **Cons**: Same-tick vs next-tick depends on signal connection order and listener side effects; pause timing depends on unverified scene-tree propagation; the verifier would need the scene tree.
- **Rejection Reason**: Non-deterministic in subtle ways and blocks headless verification.

### Alternative C: Each system as its own Node with `process_physics_priority`
- **Pros**: Editor-visible order.
- **Cons**: Order spread over 25 scene files; no single place to read or test; node per system contradicts ADR-0001's node-free rule.
- **Rejection Reason**: Not testable headless; ordering bugs are silent.

### Alternative D: Full renumbering (1..30)
- **Rejection Reason**: Dozens of GDD references to 3b/6a/6b/6c/7b would break; sub-labels are kept and only new items are added.

## Consequences

### Positive
- One step list; every "same tick or next?" question has a mechanical answer.
- Simulation runs headless (tests, verifier, drills) with no signal or node cost.
- Pause is deterministic and testable.

### Negative
- Gameplay systems lose the convenience of listening to `GameEvents`; they must read the log.
- Presentation sees events up to one step late compared with mid-tick signals (no visible effect: all within the same frame).
- Two budget rows are proposals until measured.

### Risks
| Risk | Mitigation |
|---|---|
| Summed budgets exceed 16.6 ms on REF-WEB | V1 whole-game bench; ADR-0001 fallback path for bullets; VFX/parallax effects-level degrade |
| `process_physics_priority` misbehaves in 4.7 | Idempotent `service_step()` called by GameLoop |
| Event log allocation per tick | Preallocated ring, fixed capacity, overflow asserts in debug |
| GDDs keep old "listens to signal" wording | Amendments listed in the summary; lint: no `GameEvents.connect` under `src/` sim folders |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-and-player-mapping.md | Rule 9: sample before gameplay, run while paused; OQ9 sampler ownership | Step 0 service + step 1 commit; autoload ALWAYS |
| critical-break.md, chain-tracker.md, boss-and-boss-parts.md, enemy-and-ai.md | 6 → 6a → 6b → 6c; CB before `boss_defeated`; multiply on start-of-tick count | Steps 6–6c, event rule |
| parallax-and-environment.md | AC-03: Director before ScrollClock before Enemy | Step 3a order |
| hud.md, tutorial.md | HUD after all gameplay; Drill/Hint trackers before HUD | Step 9a/9b |
| powerups-and-drops.md | Rule 23 order; death wins pickup | Step 7b after 6 |
| stage-end-tally.md, era-shift-and-plane-evolution.md | `tally_exit` → hold on the same tick | 8e before 8f |
| game-events-and-session.md | OQ7 architecture; pause stops time; `run_ticks` non-paused | SimWorld/GameLoop; gates; `run_ticks` |
| plane-kits-sentry-breaker.md | `cancel_report` at start of next tick | Event rule |
| online-leaderboards-boss-rush.md | Recorder after Input; headless re-sim | Step 1b; SimWorld |
| all GDDs with [Perf] ACs | Budgets sum within the frame | Decision 7 |

## Performance Implications
- **CPU**: ≈ 4.1 ms per tick + ≈ 3.6 ms per frame scripted on REF-WEB (paper). Event log and gates < 0.01 ms.
- **Memory**: Event log ring ≈ 2 × 512 entries; negligible.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
1. Build `SimWorld`, `TickEventLog`, `GameLoop` with stub systems; write V2/V3 tests.
2. Replace `src/gameplay/game/game.gd` per-node `_physics_process(delta)` calls as each system's epic lands.
3. Move `GameEvents.connect` uses in gameplay code to log reads; keep the bus for HUD/VFX/Audio.

## Validation Criteria
- **V1 (gate)** — `tests/perf/game_bench.tscn`: 4P, 2000 enemy + 600 player bullets, 28 enemies, boss, 150 VFX, HUD, parallax, audio, on REF-WEB release Web export: Σ steps 1–9 ≤ 4.5 ms p99, frame avg ≤ 16.6 ms, 1%-low ≥ 55 fps, no dropped ticks; per-step p99 printed.
- **V2** — Order test: a recording stub per step logs calls; 1,000 ticks give exactly the Decision 3 order every tick; same-tick/next-tick pairs of Decision 5 asserted.
- **V3** — Pause: pause requested from `_input`, focus loss and a Start verb on physics step S → no game tick at S; resume after the beat; `state_hash` equal to an unpaused run with the same inputs.
- **V4** — Frame-rate independence: BM AC-37/38 with the full SimWorld at 30/60/144 fps + 100 ms stall.

## Related Decisions
- ADR-0001 (superseded in part: tick diagram, pause clause). ADR-0003 (SimInput, state hash, replays). ADR-0004 (scene host, load discard). ADR-0005 (game-speed gate).
- Not decided here: Critical Break single-rendered-frame flag (ADR-0001 pending b); touch-to-mouse emulation setting.

> Engine review: not run (lean mode); 4.7 behaviour of the listed APIs marked UNVERIFIED.
