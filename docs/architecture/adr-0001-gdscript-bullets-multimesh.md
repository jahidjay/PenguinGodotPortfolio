# ADR-0001: GDScript-Only Gameplay, Packed-Array Bullets and MultiMesh Rendering

## Status
**Accepted (provisional) — pending benchmark V1, in progress 2026-11-03.**

This ADR is **not** unconditionally accepted. Its acceptance condition is the bullet benchmark spike (Validation Criteria V1), which is being run as this is written. [spike-0001-bullet-bench-v1.md](spike-0001-bullet-bench-v1.md) records a **desktop PASS** with roughly 2x headroom, but the ADR accepts on **REF-WEB**, which is still unmeasured - so V1 is not settled and must not be recorded as proven. The decision is accepted provisionally so implementation can proceed on it. If V1 fails, the GDExtension fallback this ADR describes is raised as a new ADR (next free number) and this status is revised; it is not silently upgraded. Everything downstream that cites ADR-0001 should read it as provisional until the V1 result is recorded here.

> **Superseded in part (2026-11-03):** the tick diagram, the `game_loop_tick_order` contract and Decision 5's pause clause → see [ADR-0002](adr-0002-core-tick-order.md); Decision 7 "Seeded randomness" refined into keyed streams → see [ADR-0003](adr-0003-determinism-and-replays.md). Related: [ADR-0004](adr-0004-scene-host-subviewport.md) (display/scene host, blocking-load discard), [ADR-0005](adr-0005-game-speed-assist.md) (game-speed gate). The GDExtension fallback this ADR calls "ADR-0002" will take the next free number if V1 fails.

## Date
2026-11-02

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer |
| **Domain** | Core / Scripting / Rendering |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (incl. "C# and Web export", checked 2026-11-02) |
| **Post-Cutoff APIs Used** | None knowingly. Relies on `MultiMesh.buffer`, `visible_instance_count`, `TRANSFORM_2D` + `use_colors` + `use_custom_data` — layout UNVERIFIED for 4.7. |
| **Verification Required** | (1) MultiMesh buffer layout (8 transform + 4 colour + 4 custom floats per instance) in 4.7 Compatibility on Web. (2) GDScript tick cost on REF-WEB (V1). (3) First-use shader compile hitch on Web. (4) Fallback only: GDExtension `dlink` Web templates in 4.7. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Core architecture / scene-wiring ADR; Bullet manager, Collision and Player plane epics |
| **Blocks** | Bullet manager (3) and Collision (6) implementation epics until V1 passes |
| **Ordering Note** | Run the benchmark spike (`tests/perf/bullet_bench.tscn`) before any production bullet code. If V1 fails, write ADR-0002 (GDExtension bullet kernel) before implementation. |

## Context

### Problem Statement
MorutJan must keep ~2000 enemy + 600 player bullets, swept hit tests and the collision referee at a fixed 60 ticks/s on PC, **Web**, phones and Switch. Official Godot 4.7 cannot export C# to Web, and the technical preferences proposed C# for exactly these hot systems. The language and the rendering path must be fixed before the Bullet manager and Collision epics start, because the Bullet manager GDD's performance criteria (AC-39..44) and reference machines are defined "by the language ADR".

### Constraints
- **Web must work with the official export** (user decision 2026-11-02). C# is therefore excluded from gameplay code.
- **Web holds the full `enemy_cap` 2000** — no reduced per-platform cap on Web.
- **Phones hold 60 Hz gameplay ticks**; rendering may drop to 30 fps (BM GDD).
- GL Compatibility renderer (WebGL2 on Web); draw calls < ~200.
- No per-bullet Nodes (technical preferences).
- Solo developer, weeks-scale timeline: one language for all gameplay keeps the codebase simple.

### Requirements
- Deterministic fixed-step simulation (same inputs → same `state_hash()`), integer tick counter, no `delta` in logic.
- All gameplay logic testable headless (the GDDs' acceptance criteria assume node-free classes).
- Budgets (p99, per tick unless noted), measured on the reference machines below:

| Budget | Value | Source |
|---|---|---|
| Whole bullet update (spawn, age, move, cancel, hit, remove) | ≤ 2.5 ms (hard), **≤ 1.5 ms to accept this ADR** | BM F12, user decision |
| Bullet hit tests | ≤ 1.5 ms | BM F12 |
| Collision referee pass | ≤ 0.5 ms | Collision AC-53 |
| Pattern tick (step 4, spawn safety included) | ≤ 0.2 ms (≤ 1.7 ms with the bullet update) | Pattern library AC-53, Open Q10 |
| Enemy tick (steps 3b + 6b, 28 enemies, runners excluded) | ≤ 0.2 ms | Enemy and AI AC-56 |
| Plane kits pass (step 3, 4 kits, 4 drones each, 64 targets) *(added 2026-11-03)* | ≤ 0.25 ms | Plane kits AC-41 |
| Bombs pass (step 3, 4 `BombCore`, 64 hurtboxes) *(added 2026-11-03)* | ≤ 0.10 ms | Bombs AC-51 |
| Boss tick (steps 3c + 6c, 8-hurtbox Jet Carrier) *(added 2026-11-03)* | ≤ 0.05 ms | Boss and boss parts AC-50 |
| Powerups tick (step 7b, 300 gems + 24 drops) / item pack *(added 2026-11-03)* | ≤ 0.15 ms / ≤ 0.10 ms | Powerups and drops AC-46, AC-47 |
| MultiMesh buffer pack | **≤ 1.0 ms per render frame** | this ADR |
| Frame | ≤ 16.6 ms; 1%-low ≥ 55 fps | technical preferences |

## Decision

1. **All gameplay and UI code is GDScript** (statically typed). No C# in the shipped project. C++ GDExtension is the only allowed native escape hatch, and only via a new ADR (Alternative B).
2. **Bullets live in packed arrays** inside one node-free `BulletField` (`RefCounted`): separate `PackedFloat32Array`s for x, y, vx, vy (no `PackedVector2Array` in the hot loop), `PackedInt32Array` for age ticks, shape, behaviour, owner/target slot.
3. **Hot-loop rules:** per-bullet work happens in a few hand-inlined loops (move, swept test, grid test) using typed locals (`for i: int in range(n)`, cached arrays/scalars). **No function call, Callable, signal or `match` per bullet**; bullets are processed in **kind buckets**. Removed bullets are compacted **once per tick**. The broad phase is the BM F11 uniform grid (32 px cells).
4. **Rendering: one `MultiMeshInstance2D` per pool** (enemy 2000, player 600), `TRANSFORM_2D`, `use_colors`, `use_custom_data`. `instance_count` is allocated once and never changed; each frame sets `visible_instance_count` and assigns the whole `multimesh.buffer` in **one** call. Basis stays fixed; rotation and atlas frame come from `INSTANCE_CUSTOM` in one canvas shader over the single bullet atlas (art bible §8). No `_draw()`/`draw_circle` for bullets.
5. **Fixed tick:** `physics/common/physics_ticks_per_second = 60`; one `GameLoop` node runs every system's `tick()` from `_physics_process` in a fixed order and owns an integer tick counter. A **tick guard** logs ticks over 8 ms and relies on `max_physics_steps_per_frame` to stop catch-up spirals. Pause = tree pause; no ticks run.
6. **No render interpolation.** The renderer draws the latest tick (pixel-art snapping; repeated frames on 120/144 Hz screens are accepted).
7. **Architecture rules** (apply to all gameplay code):
   - **Node-free logic:** each system's rules live in a `RefCounted` class with `tick()` and no scene-tree access (`BulletField`, `PlaneCore`, `CollisionReferee`, `ChainTracker`, …). Thin Node adapters own drawing, input and audio.
   - **Cross-system talk through requests and events:** systems call another system's public request methods (`request_spawn`, `request_invuln`, …) or emit/listen to signals (`GameEvents` for presentation). No system writes another system's state directly.
   - **Data in `.tres`:** every tuning value lives in a designer resource under `data/`; code and tests read it from there — no magic numbers.
   - **Seeded randomness:** gameplay uses one seeded `RandomNumberGenerator` passed in, never global `randf()`.

### Architecture Diagram

```
_physics_process (60 Hz)  ── GameLoop (Node, tick counter) ─────────────────────────┐
   1. InputSampler      snapshot (autoload, ALWAYS, ticked before GameLoop)          │
   2. PlaneCore[0..3]   .tick()  → registers pos/prev/radius/hittable                │
   3. Kits / Bombs      requests: request_invuln, damage, cancels                    │
   3b. EnemyManager     .tick(): move, arm emitters, publish hurtboxes/bodies        │
   3c. BossController   .tick(): intro/fight clock, emitters (I_eff), publish parts  │
   4. Emitters/Patterns request_spawn (blocked during death_fire_hold)              │
   5. BulletField       .tick(): spawn > age > move > cancel > hit > remove          │
   6. CollisionReferee  .tick(): Phase A damage, Phase B player hits                 │
   6a. EnemyManager     .apply_results(): hp, deaths, cancel/drop requests           │
   6b. CriticalBreakCore .tick(): arm/commit, multiply (chain at tick start)         │
   6c. BossController   .apply_results(): part hp, part kills, phases, critical      │
   7. BulletField       apply enemy-pool clear (no items) if requested               │
   7b. Powerups         .tick(): gems/drops from this tick's requests, move, pickup  │
   8. Chain / Scoring / Session consume referee events                               │
   9. GameEvents        signals → HUD, VFX, Audio (presentation only)                │
                                                                                     │
_process (render rate, 60 or 30 fps)                                                 │
   BulletRenderer (Node2D) packs BulletField arrays → MultiMesh.buffer (1 call/pool) ◄┘
   Planes, HUD, VFX draw from their cores' state (read-only)
```

### Key Interfaces

```gdscript
class_name BulletField extends RefCounted
func request_spawn(spec: BulletSpawnSpec) -> int        # accepted count, never a handle
func request_cancel(area: Rect2|circle, cause_slot: int) -> void   # FIFO, items
func request_clear_enemy_pool() -> void                 # no items (BM Rule 15a)
func set_targets(slots: Array[PlayerTarget]) -> void    # slot, pos, prev, radius, hittable
func set_hurtboxes(list: Array[Hurtbox]) -> void        # id, gen, pos, prev, radius
func tick() -> void
# read after tick: player_hits, enemy_hits, cancel_items, counters, state_hash()
# render access: enemy_count, player_count + read-only x/y/shape/angle arrays

class_name CollisionReferee extends RefCounted          # Collision GDD AC test setup
class_name PlaneCore extends RefCounted                 # Player plane GDD AC test setup

class_name BulletRenderer extends Node2D                # owns 2 MultiMeshInstance2D
func sync_from(field: BulletField) -> void              # one buffer assignment per pool
```

Exact signatures are owned by the GDD acceptance-criteria "Test setup" paragraphs; this ADR fixes only the language, the node-free shape and the render path.

### Reference machines (named by this ADR)

| Name | Definition |
|---|---|
| **REF-PC** | 4 cores ~3 GHz, integrated GPU, 8 GB RAM, Windows, release export |
| **REF-WEB** | Same machine, latest stable Chrome, release Web export (single-threaded, no COOP/COEP) |
| **REF-PHONE** | Galaxy S20-class Android (2020), release export |

## Alternatives Considered

### Alternative A (chosen): GDScript + packed arrays + MultiMesh
Described above.

### Alternative B: GDScript game + C++ GDExtension bullet kernel
- **Description**: Move `BulletField`'s hot loops (move, swept test, grid) into a GDExtension class; everything else stays GDScript.
- **Pros**: ~10–50× faster hot loop; same node-free API; works on consoles via native builds.
- **Cons**: C++ toolchain per platform; Web needs `dlink`-enabled export templates and a matching emscripten side-module build (UNVERIFIED for 4.7); a threaded build would need cross-origin isolation (itch.io support experimental); slower iteration.
- **Rejection Reason**: Not needed unless the spike fails. **Designated fallback** if V1 fails.

### Alternative C: C# for bullets and collision
- **Description**: The technical-preferences default split.
- **Pros**: Fast, familiar, good tooling.
- **Cons**: Official 4.7 cannot export C# to Web; only an unofficial community build exists ("not all features supported"); mobile C# is still experimental.
- **Rejection Reason**: Breaks the hard requirement that Web works with the official export.

### Alternative D: Server-based bullets (RenderingServer canvas items / PhysicsServer2D)
- **Description**: One server canvas item or physics shape per bullet.
- **Pros**: Native-speed collision broad phase.
- **Cons**: ~2600 server objects with per-object API calls from GDScript each tick; physics bodies don't do the BM swept rule or deterministic ordering; contradicts the BM GDD decision that the Bullet manager owns hit tests.
- **Rejection Reason**: Slower in GDScript call volume and conflicts with the approved GDD.

## Consequences

### Positive
- Official Web export stays available; one language for the whole game.
- Headless, deterministic unit tests for every gameplay rule.
- 1–2 draw calls for all bullets.

### Negative
- The GDScript hot loop must be written in a deliberately "unidiomatic", inlined style; readability is traded for speed in a few functions.
- No render interpolation: motion on 120/144 Hz screens is no smoother than 60 Hz.
- Performance headroom on Web is unproven until the spike runs.

### Risks
| Risk | Mitigation |
|---|---|
| GDScript on Web misses budget (specialist estimate: naive 3–4 ms) | Spike first (V1); optimisation round; fallback Alternative B (ADR-0002) |
| MultiMesh buffer layout differs in 4.7 | Spike verifies layout and draws a known pattern; check 4.7 class reference |
| Buffer packing exceeds 1.0 ms | Write only origin + custom (fixed basis/colour); split pools; measure in V1 |
| Catch-up spiral on slow phones | Tick guard + `max_physics_steps_per_frame`; phone check in V3 |
| Web shader compile hitch on first bullet | Warm the shader at stage load |
| GDExtension Web support absent in 4.7 (fallback) | Verify before choosing B; otherwise reduce cost via frame-staggered work |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| bullet-manager.md | ~2000 enemy + 600 player bullets at 60 fps, PC/Web/phones; pooled, no per-bullet objects | Packed arrays in `BulletField`, MultiMesh rendering |
| bullet-manager.md | F12: whole update ≤ 2.5 ms p99, hit tests ≤ 1.5 ms; REF machines "named by the language ADR"; Open Q1 | Names REF-PC/WEB/PHONE; acceptance gate ≤ 1.5 ms |
| bullet-manager.md | Determinism, `state_hash()`, headless `BulletField` test class | Node-free classes, integer ticks, seeded RNG |
| bullet-manager.md | Phones: 60 Hz ticks, render may be 30 fps | `_physics_process` 60 Hz + render decoupled |
| collision-damage-lives.md | AC-51..53: collision ≤ 0.5 ms p99; node-free `CollisionReferee` | GDScript, node-free, same budget table |
| player-plane.md | `PlaneCore` node-free tick, registration every tick | Node-free rule + GameLoop order |
| game-events-and-session.md | Game time in ticks; pause stops simulation | Integer tick counter; tree pause |

## Performance Implications
- **CPU**: Target ≤ 1.5 ms p99 bullet tick + ≤ 0.5 ms collision + ≤ 1.0 ms pack on REF-WEB.
- **Memory**: ~2600 × ~10 packed fields ≈ 100 KB; MultiMesh buffers 2600 × 16 floats ≈ 166 KB. Negligible.
- **Load Time**: One atlas + one shader; warm the shader at stage load.
- **Network**: None.

## Migration Plan
1. Build the spike `tests/perf/bullet_bench.tscn` (throwaway-quality but in `tests/perf/`), variants A (current style) and B (this ADR's rules).
2. If V1 passes: replace `src/gameplay/bullets/bullet_manager.gd` (`_draw()` + `PackedVector2Array` + per-bullet `match`) with `BulletField` + `BulletRenderer` + adapter, during the Bullet manager epic.
3. Move collision rules out of `src/core/combat_rules.gd` / `boss_part.gd` (float hp) into `CollisionReferee` (integer hp) during the Collision epic.
4. Update `.claude/docs/technical-preferences.md`, `docs/project-structure.md` and `CLAUDE.md` tech stack: remove "C# for bullets/collision"; C# not used.
5. Canvas retune 480×640 → 360×640 happens in the same epics (separate task).

## Validation Criteria
- **V1 (gate)** — `tests/perf/bullet_bench.tscn`, release Web export on REF-WEB, 30 s warm-up: 2000 enemy bullets (mixed shapes, 10% curve/warp) + 600 player bullets, 4 sweeping players, 40 hurtboxes, 32 px grid, both MultiMeshes rendering. Timed in 60-tick blocks with `Time.get_ticks_usec()`; p50/p99/max reported separately for tick, pack and frame; empty-loop baseline recorded.
  - **Accept:** variant B bullet tick **≤ 1.5 ms p99**, pack ≤ 1.0 ms p99, frame ≤ 16.6 ms avg, 1%-low ≥ 55 fps, zero dropped ticks.
  - **1.5–3.0 ms:** one optimisation round (bucketing, cheaper player-bullet tests, staggered work), re-test against 1.5 ms.
  - **> 3.0 ms or still failing:** write ADR-0002 (Alternative B, GDExtension kernel) and verify Web `dlink` before implementation.
- **V2** — Same scene on REF-PC: tick ≤ 1.0 ms p99.
- **V3** — REF-PHONE: 60 Hz ticks with no dropped ticks over 5 minutes; render ≥ 30 fps.
- **V4** — Collision AC-51..53 and BM AC-39..44 pass once the real systems exist.
- **V5** — Determinism: the bench run twice gives identical `state_hash()` every tick.

> **2026-11-03 (wave 3a; critical-break.md, hud.md, menus-title-plane-select.md):** tick-order additions. (1) `CriticalBreakCore.tick()` runs at **step 6b**, after the Collision referee and Bombs' results and **before** `BossController.apply_results()` (6c), so a break beats a same-tick normal kill and `chain_multiplied` reaches Chain (step 8) before `boss_defeated`. The number 6b is already used by `EnemyManager.apply_results()`; CB runs after it (both before 6c). Renumbering is left to the core architecture ADR. (2) `HudModel.tick()` runs after all gameplay systems (after step 8), read-only, and freezes on pause. (3) Menu models (`MenuModel`, `LobbyModel`, `PauseModel`, `NameEntryModel`, `ResultsFlow`, `HoldConfirm`) are node-free and ticked at 60 Hz by a host with `process_mode = ALWAYS`. **Pending ADRs (not written here):** (a) menu host under the Display SubViewport, menu models at 60 Hz with `process_mode = ALWAYS`, and the `start_run` pre-load handshake / `LobbyModel` vs Session ownership (Menus Open Question 12); (b) a render-side flag that guarantees the Critical Break white frame is exactly one rendered frame on Web and mobile (CB open risk).

> **2026-11-03 (wave 3b, decision):** step 6 sub-order is now fixed and drawn in the diagram: **6** `CollisionReferee`, **6a** `EnemyManager.apply_results()`, **6b** `CriticalBreakCore.tick()`, **6c** `BossController.apply_results()`. This supersedes the wave 3a note's "6b is already used" remark. The Critical Break multiply uses each slot's chain count as of the **start of the tick**; this tick's hits reach Chain only at step 8, after the multiply (critical-break.md F-section).

> **2026-11-03 (wave 4; touch-controls.md, online-leaderboards-boss-rush.md, plane-kits-sentry-breaker.md, tutorial.md):** additive notes, no decision changed. (1) **Step 1:** touch events are latched in `_input`; `TouchMapper` runs inside the sampler tick and fills `SlotInput.drag` / `drag_active` / `fire_auto` for slot 0. Gameplay disables Godot's touch-to-mouse emulation — that setting needs its own ADR. (2) **After step 1**, when `online.enabled`, `ReplayRecorder.tick(inputs_by_slot)` logs Input's post-mapping `sim_input_byte(slot)`; the replay re-simulation makes cross-platform determinism (V5 across Windows/Linux/Web) a gate for online boards — new ADRs needed: replay recording and verification, online transport/adapters (incl. a Steam GDExtension exception to Decision 1), hosting/data region. (3) **Bullet manager:** kit circle cancels with `items = false` (Breaker net, ≤ 2 per slot per tick) and `cancel_report(slot, request_id, count)` delivered at the start of the next tick; perf scenario 1,350 bullets + 12 cancel areas per tick ≤ 2.5 ms p99 (BM AC-40). (4) **`play_top`** is latched at `stage_started` and `wave_started`; gameplay never reads the HUD display mode. (5) **Drills** (`run_kind = DRILL`) use their own `DrillRunner` (same `SpawnEvent` shape) in place of the Director; fixed seed, no RNG.

## Related Decisions
- Core tick order and GameLoop: [ADR-0002](adr-0002-core-tick-order.md). Determinism and replays: [ADR-0003](adr-0003-determinism-and-replays.md). Scene host / SubViewport: [ADR-0004](adr-0004-scene-host-subviewport.md). Game-speed assist: [ADR-0005](adr-0005-game-speed-assist.md).
- Possible ADR-0002: GDExtension bullet kernel (only if V1 fails).
- Design: `design/gdd/bullet-manager.md`, `collision-damage-lives.md`, `player-plane.md`, `game-events-and-session.md`; art bible §8 (one bullet atlas, MultiMesh).

> Engine review: `godot-specialist` (2026-11-02) — proceed with conditions; 4.7 MultiMesh layout and GDExtension-on-Web marked UNVERIFIED. TD-ADR skipped — Lean mode.
