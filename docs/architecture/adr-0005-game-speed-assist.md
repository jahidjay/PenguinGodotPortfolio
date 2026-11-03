# ADR-0005: Game-Speed Assist Scheduler

## Status
**Accepted (2026-11-03)** — accepted with the design set at the Concept → Pre-Production gate. V1 (cadence + determinism) and V2 (audio on Web) remain required validation during implementation; a failure amends this ADR.

## Date
2026-11-03

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer |
| **Domain** | Core / Audio |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/` (2026-11-03); ADR-0002, ADR-0003, ADR-0004 |
| **Post-Cutoff APIs Used** | None. Explicitly does **not** use `Engine.time_scale`, `Engine.physics_ticks_per_second` changes, `AudioServer.playback_speed_scale` or `AudioStreamPlayer.pitch_scale` for speed (their 4.7 behaviour is UNVERIFIED and not needed). |
| **Verification Required** | Music keeps normal speed and SFX timing on the Web export at 50 % (V2). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (admission gates, input split), ADR-0003 (game ticks identical; replay boundary), ADR-0004 (discard window) |
| **Enables** | Accessibility Rule 24 (Vertical Slice), Single Boss practice (Online leaderboards) |
| **Blocks** | Nothing at MVP (the option ships at Vertical Slice) |
| **Ordering Note** | Implement with the GameLoop gates; the gate is a few lines but its tests guard determinism. |

## Context

### Problem Statement
Accessibility Rule 24 / F2 adds `access.game_speed_pct` (50–100, step 10, ASSIST): fewer game ticks per second without changing any tick-level rule, input latched across skipped steps, music at normal speed, and the run marked PRACTICE (`run.assisted`, never ranked or uploaded). Accessibility OQ10 asks for the scheduler ADR, confirmation that `Engine.time_scale` is not used, and music behaviour; Era/Session ask how it combines with the blocking-load discard.

### Constraints
- Game ticks must be identical to 100 % ticks (ADR-0003); menus, pause, TATE confirm, Save and audio buses stay real time.
- No tap may be lost (Input Rule 24a).

### Requirements
- Exactly `speed_pct` game ticks per 100 physics steps, never two in one step.
- Deterministic interaction with pause and load discard.

## Decision

1. **Integer accumulator gate** (`SpeedGate`, node-free), evaluated by the GameLoop as the **third** admission gate (after pause and the load-discard window, ADR-0002 Decision 4):
   `acc += speed_pct; if acc >= 100: acc -= 100; run game tick` — else the step is a **skipped step**.
   `speed_pct` is read from Accessibility at physics-step boundaries. `acc` is cleared to 0 on a speed change, on pause entry, and at `run_started`. At 100 every step runs a tick (gate is a no-op).
2. **Input across skipped steps.** `InputSampler.service_step()` runs on every physics step (ADR-0002 step 0) and keeps latching; `commit_sim_tick()` runs only on game ticks, so a press/release between game ticks is delivered as `pressed` on tick T and `released` on T+1 (Input F1). Touch `drag` accumulates and is delivered on the next game tick. `held_ticks`, `buffer_ticks`, Tap Assist cadence, continue countdown and every sim timer count **game ticks**. Menu navigation repeat counts physics steps (real time).
3. **What slows and what does not.**
   - Slows (game ticks): the whole `SimWorld`, and step-9 presentation models (HUD roll, VFX, ParallaxState, SFX triggers, retrigger gaps W in game ticks).
   - Real time: menus (MenuHost), pause/resume beat, Display presenter, TATE confirm, Save, online `poll()`, audio buses, duck envelopes and crossfades (ms-based, Audio F7/F10).
   - **Music and ambience play at normal speed, not time-stretched or pitched.** SFX fire on their game ticks (spaced wider). `Engine.time_scale` stays 1.0 (lint).
   - Frame cadence: repeated frames (90 % repeats 1 in 10); no interpolation (ADR-0001).
4. **`run.assisted` latch.** Session sets it at step 1a (`Session.begin_tick`) of the first game tick on which any ASSIST option is in effect (speed < 100 included) and never clears it in that run; reset only by `run_started`. Effects per Accessibility Rule 23: PRACTICE tag, `submit_run` "not ranked", no NEW BEST, no name entry, `one_credit_clear` false.
5. **Blocking-load interaction.** Steps dropped by the discard window (ADR-0004 Decision 7) are evaluated **before** the gate and **do not add to `acc`**; the cadence resumes where it stopped. Pause clears `acc`.
6. **Replays.** The gate is outside the deterministic boundary; game ticks are identical, so the replay of an assisted run is the same stream of `SimInput` per game tick. The recorder may keep recording (local replay later), but **assisted runs never upload** (Online Rule 1, Save Rule 32). The speed setting is not a replay timing setting (it never changes tick-level results).

### Key Interfaces

```gdscript
class_name SpeedGate extends RefCounted
func set_speed(pct: int) -> void   # clears acc
func reset() -> void               # pause entry, run_started
func step() -> bool                # true = run a game tick on this physics step; < 2 µs (Accessibility AC-48)
```

## Alternatives Considered

### Alternative A (chosen): integer tick-skip accumulator on 60 Hz physics steps
Described above.

### Alternative B: `Engine.time_scale`
- **Pros**: One line.
- **Cons**: Scales the physics clock for every node, so the InputSampler, MenuHost and resume beat slow too; Tweens/UI animations slow; non-integer cadence; behaviour in 4.7 unverified.
- **Rejection Reason**: Breaks real-time menus and exact tick counting.

### Alternative C: Lower `physics_ticks_per_second` at runtime
- **Rejection Reason**: Input sampling and menus drop to 30 Hz; latency rises; changes ADR-0001's fixed 60 Hz.

### Alternative D: Scale speeds inside the sim
- **Rejection Reason**: Changes tick-level rules and replays; not "the same game, slower".

## Consequences

### Positive
- Assisted play is the same simulation; determinism and replay tooling unaffected.
- Exact, testable cadence; tiny cost.

### Negative
- Visible judder (repeated frames) at < 100 %; accepted for an assist.
- SFX sparser than music at low speed.

### Risks
| Risk | Mitigation |
|---|---|
| A system counts real time inside the sim | ADR-0003 lint (no `delta`/`Time`); V1 hash test |
| Audio scheduling drifts on Web | V2 |
| Latch missed if speed changes while paused | Latch evaluated on the first game tick after resume (AC-38) |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| accessibility-options.md | Rules 23–24, F2, OQ10, AC-37/38/48 | Decisions 1–6 |
| input-and-player-mapping.md | Rule 24a latching on skipped steps | Decision 2 |
| game-events-and-session.md | `run.assisted` latch, game-speed gate | Decision 4 |
| audio.md | Music real time; SFX on ticks | Decision 3 |
| online-leaderboards-boss-rush.md | Assisted runs never upload; Single Boss practice | Decision 6 |

## Performance Implications
- **CPU**: < 2 µs per physics step. At 50 % the sim costs half per second.
- **Memory / Load / Network**: none.

## Migration Plan
Add `SpeedGate` to the GameLoop gates when Accessibility lands (Vertical Slice); until then the gate is fixed at 100.

## Validation Criteria
- **V1** — Unit: for every speed 50–100, 10,000 steps give exactly `speed × 100` ticks, never two per step; Accessibility AC-37 (identical hashes at 100 % and 60 %, sub-tick tap delivered) and AC-38 (latch on next game tick, stays set) pass; a discard window during a 70 % run leaves `acc` unchanged.
- **V2** — Manual on REF-WEB: at 50 % music plays at normal pitch/speed, ducks still work, SFX fire on game ticks.

## Related Decisions
- ADR-0002, ADR-0003, ADR-0004.

> Engine review: not run (lean mode).
