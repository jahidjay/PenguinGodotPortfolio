# ADR-0003: Deterministic Simulation, Seeded Streams and Replays

## Status
**Accepted (2026-11-03)** — accepted with the design set at the Concept → Pre-Production gate. Validation still required during implementation: the math micro-spike (V1) on Windows, Linux and Web, and - for the online-verification part only - the full cross-platform replay spike (V2 = Online leaderboards AC-14). If V2 fails, the same-platform fallback (Decision 9) applies without reopening the decision. Refines ADR-0001 Decision 7 "Seeded randomness" (one RNG → keyed streams).

## Date
2026-11-03

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer |
| **Domain** | Core / Scripting / Data |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/` (all four files, 2026-11-03); ADR-0001, ADR-0002 |
| **Post-Cutoff APIs Used** | None knowingly. Uses `RandomNumberGenerator` (PCG32: `seed`, `state`, `randi`, `randi_range`, `randf`, `randf_range`), `HashingContext` (SHA-256), `PackedFloat32Array/PackedInt32Array.to_byte_array()`, `PackedByteArray.decode_u32/decode_s64`, `PackedByteArray.compress(COMPRESSION_ZSTD)` — **all UNVERIFIED for 4.7** (not in the upgrade pages). 4.7 note: setting a packed-array element no longer calls the property setter (breaking-changes 4.6→4.7) — no sim code may rely on that setter. |
| **Verification Required** | (1) PCG32 output and `randf()` bit-identical on Windows/Linux/Web (V1). (2) GDScript float ops and the allowed engine helpers bit-identical across platforms (V1). (3) `to_byte_array()` is little-endian on all targets. (4) ZSTD compression available on Web export. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (integer ticks, node-free cores), ADR-0002 (`SimWorld` boundary, step 1b recorder, checkpoint after step 8) |
| **Enables** | Online leaderboards verifier; local replay / attract demo (Menus OQ1, Online OQ6/7); determinism ACs in every GDD |
| **Blocks** | Online leaderboard feature commit (until V2); any sim code using trig or RNG (must follow Decisions 3–5 from day one) |
| **Ordering Note** | Ship `SimMath`, `SimHash`, `SimRng` before Pattern library / Enemy / Boss code, so no `sin`/`atan2`/`hash()` calls have to be ripped out later. |

## Context

### Problem Statement
Replay verification (Online leaderboards Rules 22–24) requires the verifier's headless Linux build to reproduce a client's run **bit-exactly**, from Windows, Linux or Web (wasm). The GDDs use `sin`, `cos`, `atan2` in sim formulas (Enemy paths, Pattern aims/curves, Boss C(t), Powerups bob, Sentry tracking), float positions, an underspecified `hash(run_seed, …)` for seeds, and conflicting seed rules (Pattern Rule 15 stable-id hash vs Enemy "draw seeds from the gameplay RNG in spawn order"). The input boundary is also unclear: the sim reads more than the 7-bit "input byte" (tap-assist pulses, touch drag, the Drone/Bomb buffer that depends on sim acceptance).

### Constraints
- GDScript only (ADR-0001); verifier = the same game build, headless.
- Platform C runtimes differ: MSVC UCRT, glibc, emscripten musl — transcendental functions may differ in the last ulp.
- The simulation must stay fast (no per-bullet hashing or bignum math).

### Requirements
- Same `run_seed` + same recorded `SimInput` stream + same timing settings → same `state_hash()` at every tick, on every supported platform class.
- Replays small (≤ 256 KB compressed, Online F3); checkpoints every 600 ticks.
- No outcome may depend on wall-clock, frame rate, load speed or presentation.

## Decision

1. **Deterministic boundary.** Everything inside `SimWorld` (ADR-0002 steps 1–8) is deterministic; everything outside (device handling, presentation, loading, audio) is not required to be. The **only** inputs crossing into the sim are: (a) per-slot `SimInput` per game tick, (b) recorded run events, (c) `run_seed`, (d) the content (data manifest, `content_hash`), (e) the recorded **timing settings** (Decision 7). Device-side state may react to sim events (e.g. fire-toggle reset on `plane_died`); its only effect on the sim is through the recorded `SimInput`.
2. **`SimInput`** (per slot per tick), produced by `InputSampler.commit_sim_tick()`:
   - byte: bits 0–3 `move` (0 neutral, 1–8 = the 8 directions, computed device-side incl. deadzone and sector hysteresis, so PF2's `atan2` is outside the sim), bit 4 Fire held, bit 5 Drone held, bit 6 Bomb held, bit 7 **fire pulse** (Tap Assist synthetic press, or touch `fire_auto`);
   - **touch slots additionally**: `drag` (two int16, 1/16 canvas px), `drag_active` (bool), `fire_auto` (bool). **Touch runs are recorded and verifiable** (decision: record, don't exclude), so `/touch` boards are replay-verified.
   - Sim side, a `SimInputDecoder` at step 1 derives `pressed`/`released`/`held_ticks` from the bit history and owns the Drone/Bomb `buffer_ticks` window, `consume()` and `clear_buffer()` (these depend on sim acceptance, so they must be inside the boundary and in `state_hash`).
3. **Float policy.**
   - Allowed in the sim: `int` arithmetic; float `+ − × ÷`, `sqrt`, `abs`, `min/max`, `floor/ceil/round`, comparisons, `int()`/`float()` conversion, float32 storage in packed arrays (rounding is IEEE-exact).
   - **Forbidden in the sim:** `sin cos tan asin acos atan atan2 exp log pow` (and `Vector2.angle/angle_to/rotated/from_angle`, `lerp_angle`, `randfn`, `Curve.sample`, `Tween`) — their results come from the platform libm. Use **`SimMath`**: trig from a shipped table (`data/sim/trig_table.tres`, 16,384-entry quarter-wave `PackedFloat32Array`, generated offline once and covered by `content_hash`), angles as int **binary angle units** (65,536 per turn), `SimMath.atan2_bam(dy, dx)` by table bisection; exponential growth as per-tick multiply recurrences.
   - Engine compound helpers (`Vector2.length/normalized/dot`, `move_toward`, `lerp`) are **allowed only after V1 shows them identical** on all classes; otherwise inline them as scalar ops. Reason: C++ compilers may contract `a*b+c` into FMA on ARM64 (and on x86 if built with FMA).
   - **Quantisation:** published positions that come from closed-form paths (Boss C(t), Enemy SINE/drift, Powerups bob) are computed with `SimMath` and quantised to **1/16 px** (Boss rule, extended); touch drag is already 1/16 px int.
4. **Seeded streams.** `run_seed` (64-bit int) is chosen by Session at `start_run` from non-sim entropy and recorded; drills use a fixed seed. There is **no shared, order-dependent gameplay RNG**. Every stream is a `RandomNumberGenerator` seeded with `SimHash.seed(parts…)` and is listed here:

| Stream | Seed | Owner | Advances on |
|---|---|---|---|
| Emitter | `seed(run_seed, stage_index, owner_id, emitter_index)` | Pattern library runner | its own random choices only |
| Drops | `seed(run_seed, stage_index, "drops")` | Powerups | 4 draws per `drop_requested` (Powerups Rule 9) |
| *(new streams)* | must be added to this table by ADR amendment | — | — |

   `owner_id` is a stable authored id: boss part `id`, or for wave enemies `event_id × 16 + member_index`. Spawn order, refused spawns and other emitters never change a stream. Allowed RNG calls: `randi`, `randi_range`, `randf`, `randf_range`. Forbidden: global `randf/randi/randomize/rand_from_seed`, `Array.shuffle/pick_random`, `randfn`.
5. **Hashing.** `SimHash` uses `HashingContext` SHA-256 over a canonical little-endian byte stream (ints 8 bytes, float32/64 by bit pattern via `to_byte_array()`, strings UTF-8 + length). `seed()` = first 8 bytes as int64; `state_hash()` = first 4 bytes as uint32. Godot's Variant `hash()` is forbidden for anything persisted or compared across builds. Each sim system implements `hash_into(ctx)` over its sim state in a fixed field order; `SimWorld.state_hash()` visits systems in ADR-0002 step order.
6. **Other sim prohibitions:** no `delta`, `Time.*`, `OS.*`, `Engine.get_*_frames`, `get_tree()`, threads, `await`, file or resource loading by path inside `tick()`; no iteration order derived from `get_instance_id()`/Object identity; every `sort_custom` comparator is a total order (ties broken by stable id); `Engine.time_scale` stays 1.0.
7. **Load- and setting-gated timing.** Anything that can shift sim ticks is recorded:
   - **Timing settings** in the replay header: `access.continue_timer`, `access.tally_auto_advance`, `access.era_transition_short` (any future setting the sim reads must be added here or classified ASSIST).
   - **I/O-gated waits** as run events: Era shift's release tick (`era_released(tick)`, incl. `era_load_late`). In verification mode the loader reports "ready" exactly at the recorded tick (content is pre-loaded synchronously before the run). The tally/era-card skip reads only `SimInput` fire edges.
8. **Replay format** (`ReplayRecorder`, step 1b, node-free; matches Online Rule 22):
   - Header: magic, `format_version`, `game_version`, `engine_version`, `ruleset`, `content_hash`, `platform_class`, `mode`, stage/boss list, `run_seed`, slots (plane, `joined_at_run_start`, device kind TOUCH or not), timing settings.
   - Input records, run-length: `(tick_delta varint, slot, byte)` when the byte changes; touch slot extension `(tick_delta, drag.x int16, drag.y int16, flags[drag_active, fire_auto])` on every tick where any of them is non-zero/changes (est. ≤ 3 bytes/tick while dragging; a 20-min touch run ≈ 216 KB raw, ≈ 70–110 KB compressed — under `replay_max_raw_bytes` 1 MB; to re-check with F3).
   - Run events: `join(slot, plane)`, `continue_accept(slot)`, `slot_forfeit(slot)`, `era_released`, each with tick.
   - Checkpoints: `state_hash()` after step 8 of every tick with `(t + 1) % 600 == 0`.
   - Footer: per-slot score, stage/boss reached, `run_ended_by`, total ticks. Compressed ZSTD (fallback: deflate if ZSTD is missing on Web, flagged in header).
   - Recording costs nothing in the sim: the recorder only reads `SimInput` and run events. Assisted and debug-tainted runs may be recorded but never upload (ADR-0005).
9. **Verification.** The verifier runs the `ruleset` build headless (`--headless`), a `ReplayRunner` that drives `SimWorld.tick()` in a loop with recorded inputs, compares every checkpoint (stop at the first mismatch) and the footer. **Platform classes:** `x64-desktop` (Windows, Linux), `wasm` (Web), later `arm64`. A class is "verified" only after V2 passes for it. **Fallback** if V2 fails for a class: claims from that class are verified by a verifier build of the same class (e.g. a Node/Chromium-hosted Web build) or shown on a separate `UNVERIFIED` tab (Online Rule 23); further fallback: quantise more of the sim (positions to 1/16 px ints everywhere).
10. **Rulesets.** Any change to sim code, data, the trig table or the engine version is a new `ruleset`; boards are keyed by ruleset (Online Rule 22 header).

### Key Interfaces

```gdscript
class_name SimMath    # static: sin_bam(a:int)->float, cos_bam, atan2_bam(dy,dx)->int, rad_to_bam(r)->int (load-time only)
class_name SimHash    # static: seed(parts: Array)->int, begin()->HashingContext, add_int/add_f32_array/..., digest32(ctx)->int
class_name SimRng     # static: make(stream_key: StringName, parts: Array) -> RandomNumberGenerator (asserts key is registered)
class_name SimInput   # byte:int, drag:Vector2i, drag_active:bool, fire_auto:bool
class_name ReplayRecorder extends RefCounted   # tick(inputs: Array[SimInput], run_events), checkpoint(t, hash), finish(footer) -> PackedByteArray
class_name ReplayRunner extends RefCounted     # run(bytes) -> VerifyResult {ok, first_mismatch_tick, footer}
```

## Alternatives Considered

### Alternative A (chosen): float sim with banned transcendentals + tables + 1/16 px quantisation
Described above.

### Alternative B: Full fixed-point (int) simulation
- **Pros**: Determinism by construction on every platform, incl. ARM.
- **Cons**: Rewrites BM/Collision math in ints; GDScript int ops are not faster; every GDD formula in px/s floats must be re-expressed; large schedule cost.
- **Rejection Reason**: Too costly now. **Designated second fallback** for a failing class (quantise more, Decision 9).

### Alternative C: Record state snapshots instead of re-simulating
- **Pros**: No determinism requirement.
- **Cons**: Forgeable (the client produces the state); replays megabytes.
- **Rejection Reason**: Defeats "verified means replayed".

### Alternative D: One shared gameplay RNG drawn in spawn order (Enemy GDD wording)
- **Rejection Reason**: Order-dependent; a refused spawn or an added emitter changes every later random choice; conflicts with Pattern Rule 15.

### Alternative E: Exclude touch runs from verification
- **Rejection Reason**: Touch boards would be unverifiable; recording drag costs ≤ 3 bytes/tick (user decision: record).

## Consequences

### Positive
- Bit-exact replays are possible; local replay/attract demo comes for free.
- Seeds are stable under content edits (adding an emitter changes nothing else).
- The determinism rules are lintable (grep for banned calls in `src/sim/**`).

### Negative
- Authors must use `SimMath` instead of `sin`/`atan2`; angles in data are converted to binary-angle units at load.
- Input's buffer and edge logic move to a sim-side decoder (Input/Player GDD amendments).
- Replays of touch runs are larger.

### Risks
| Risk | Mitigation |
|---|---|
| Engine compound math differs across platforms (FMA, libm) | V1 torture test; inline scalar ops if any helper differs |
| Web differs from desktop in the full sim | V2; per-class verifier or `UNVERIFIED` tab (Decision 9) |
| A setting or load timing shifts ticks unnoticed | Decision 7 list; V3 tests run with each timing setting and slow/fast loaders |
| Engine patch changes VM float behaviour | Engine version in header; ruleset bump per engine upgrade |
| `HashingContext` cost at checkpoints | One SHA-256 over ≈ 120 KB every 600 ticks (native); measured in V4 |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| online-leaderboards-boss-rush.md | Rules 22–24, OQ1, AC-11..14: deterministic contract, replay, checkpoints, cross-platform gate | Decisions 1–10; V2 = AC-14 |
| bullet-pattern-library.md | Rule 15 stable-id emitter seeds | Decision 4 (and its `hash` defined) |
| powerups-and-drops.md | Rules 9–10 drop stream per stage | Decision 4 stream table |
| boss-and-boss-parts.md | 1/16 px quantisation, AC-44/47 | Decision 3 |
| touch-controls.md, input-and-player-mapping.md | `drag` 1/16 px; Rule 13a sim byte | Decision 2 (+ touch fields recorded) |
| accessibility-options.md | AC-07, AC-37 presentation/speed don't change the sim | Decision 1 boundary; ADR-0005 |
| enemy-and-ai.md, wave-and-stage-director.md, all [determinism] ACs | equal `state_hash` per tick | Decisions 3–6 |

## Performance Implications
- **CPU**: Table trig ≈ an array read; `state_hash` only every 600 ticks in play (every tick in tests); recorder ≤ 20 µs.
- **Memory**: trig table 64 KB; replay buffer ≤ 1 MB raw.
- **Load Time**: trig table load < 1 ms.
- **Network**: replay ≤ 256 KB per upload (Online F3).

## Migration Plan
1. Add `src/sim/` (`SimMath`, `SimHash`, `SimRng`, `SimInput`, decoder) + `data/sim/trig_table.tres` + generator tool script.
2. Lint test: no banned calls / global RNG / `hash(` in `src/sim/**` and sim cores.
3. Prototype boss/bullet code (`sin`, float hp, `delta`) is replaced during the Boss and Bullet epics (already planned).

## Validation Criteria
- **V1 (gate for Accepted)** — `tests/determinism/math_torture`: 10⁶ seeded cases of every allowed op, every `SimMath` function, candidate engine helpers, PCG32 sequences and `SimHash` on Windows release, Linux headless and Web (REF-WEB) → identical digests. Lists any engine helper that differs (then banned).
- **V2 (gate for online)** — Online AC-14: 5 replays (2 stages, 1P Lancer, 1P Leech, 2P, Boss Rush, + 1 touch run) recorded on Windows, re-simulated on Linux headless and Web: identical checkpoints and footer.
- **V3** — Same replay with timing settings at each value and a loader delayed by 0/60/200 ticks → identical hashes when the recorded `era_released` is honoured.
- **V4** — Checkpoint hash ≤ 2 ms on REF-WEB; recorder ≤ 20 µs median.
- **V5** — ADR-0001 V5 (same machine, run twice) and BM AC-37/38 still pass.

## Related Decisions
- ADR-0001 (Decision 7 refined), ADR-0002 (SimWorld, step 1b), ADR-0005 (assisted runs never upload), ADR-0007 (online transport/hosting), ADR-0008 (touch input fields).

> Engine review: not run (lean mode); all listed APIs UNVERIFIED for 4.7.
