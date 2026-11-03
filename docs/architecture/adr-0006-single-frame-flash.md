# ADR-0006: Single-Frame Critical Break Flash (Render-Side One-Shot Flag)

## Status
**Accepted (2026-11-03)** — accepted with the design set at the Concept → Pre-Production gate. The flash capture spike (Validation Criteria V1–V3) on REF-PC, REF-WEB and REF-PHONE remains required validation during implementation; a failure amends this ADR.

## Date
2026-11-03

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer |
| **Domain** | Rendering / Presentation / Accessibility |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (none cover frame pacing, `frame_post_draw` or SubViewport update modes); RenderingServer class reference 4.1 (web search 2026-11-03) |
| **Post-Cutoff APIs Used** | None knowingly. Relies on `RenderingServer.frame_post_draw` (signal; documented in 4.1 as "emitted at the end of the frame, after the RenderingServer has finished updating all the Viewports"), `Engine.get_frames_drawn()`, `SubViewport.render_target_update_mode = UPDATE_ALWAYS`, `CanvasItem.visible`, `Node.process_mode = PROCESS_MODE_ALWAYS`. All **UNVERIFIED for 4.7**. |
| **Verification Required** | (1) `frame_post_draw` still fires once per drawn frame in 4.7 Compatibility on Web (single-threaded) and Android. (2) A visibility change made inside a `frame_post_draw` handler applies to the next drawn frame, not the one just drawn. (3) A SubViewport with `UPDATE_ALWAYS` renders on every root frame, so one SubViewport frame = one presented frame. (4) Behaviour with `display/window/vsync/vsync_mode` off on PC (tearing). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (fixed 60 Hz tick, no render interpolation, render decoupled from ticks); ADR-0002 (tick order: `CriticalBreakCore.tick()` at 6b, presentation signals at step 9); ADR-0004 (scene host: the Display SubViewport and `process_mode` of presentation hosts); ADR-0005 (game speed: the flash keys on **game** ticks, not physics steps) |
| **Enables** | VFX epic (`FlashState`, `FlashPresenter`), Critical Break presentation, Accessibility `reduce_flashing` |
| **Blocks** | VFX AC-07, AC-51; CB AC-34, AC-36 sign-off |
| **Ordering Note** | Can be implemented as soon as the Display SubViewport presenter exists. The spike (V1–V3) needs only a test scene with a forced flash, not the real Critical Break. |

## Context

### Problem Statement
The Critical Break (CB) is the **only** full-screen flash in the game (VFX Rule 5, art bible §2): one white 360×640 frame at tick `T+1`, layer 10 (`z_index` 100), covering the instant the field is cancelled. The GDDs require "exactly one **rendered** frame" (CB Rule 25, VFX Rule 28, F12, AC-07) on every platform. The simulation runs at a fixed 60 Hz (ADR-0001) but rendering does not:

- **Phones may render at 30 fps** while ticking at 60 Hz: two ticks run per drawn frame. A flag that is true only during tick `T+1` is cleared by tick `T+2` before anything is drawn, so the flash would never appear.
- **120/144 Hz screens repeat frames** (no interpolation, ADR-0001 Decision 6): a flag held for the whole of tick `T+1` is drawn 2–3 times.
- **Long frames, pause on `T+1`, scene change mid-flash and game speed < 100 %** (ADR-0005) must not produce zero or two white frames (VFX edge cases, AC-51).

The "one frame" must therefore be decided on the **render side**, by counting drawn frames, not ticks. CB Open Question 9 assigns this to the technical director.

### Constraints
- Gameplay never depends on the flash: it is presentation only and absent in headless runs (verifier, tests).
- Readable Chaos: nothing above layer 8 except hitbox dots (9), the flash (10) and the HUD (11); the field is empty at `T+1` (CB Rule 25).
- Photosensitivity: the flash happens at most once per boss (CB Rule 27); a stage has one boss. WCAG 2.3.1 / Ofcom-style guidance: no more than **3 flashes in any 1-second period**. `access.reduce_flashing` replaces the flash with a particle burst; a first-run prompt offers the Calm preset (Accessibility Rule 34).
- The flash lives **inside** the 360×640 canvas (Display scaler: the bezel never flashes), so its area is the canvas, not the window.

### Requirements
- R1: With `reduce_flashing` false, a CB produces **exactly one** presented frame whose canvas is fully `#FFFFFF`, no fade, at the first drawn frame at or after game tick `T+1`.
- R2: Holds at 30, 60, 120 and 144 fps render rates, with game speed 50–100 %, and across a long frame.
- R3: Pause on `T+1` before the flash is drawn: the flash draws once, then hides, and stays hidden through the pause (VFX edge case, AC-51).
- R4: Scene change or run end at any point hides it and resets the state (AC-33).
- R5: With `reduce_flashing` true: no white frame at all; no consecutive frames differ by more than 8 % mean luma over the CB (AC-23, AC-36).
- R6: Budget: zero cost when idle; +1 draw call on the flash frame (VFX AC-44).

## Decision

**Split the flash into a tick-side state machine and a render-side one-shot flag.**

1. **`FlashState` (node-free `RefCounted`, VFX)** is ticked with the game tick (step 9 presentation side, ADR-0002). On `critical_break_landed` at tick `T` with `reduce_flashing` false (read at `T`, CB Rule 27) it goes IDLE → ARMED and stores `T+1`. When the game tick counter reaches `T+1` it goes ARMED → PENDING and increments a **request counter** `flash_requests` (int). It never shows or hides anything itself and knows nothing about frames. With `reduce_flashing` true it stays IDLE and spawns the burst (VFX Rule 28). A second request while not IDLE is ignored and logged (VFX edge case).
2. **`FlashPresenter` (Node2D inside the Display SubViewport, `z_index` 100, `process_mode = ALWAYS`)** owns the only white rect (`draw_rect` of the canvas, or a `ColorRect`; one draw call). It holds `consumed_requests` (int) and `shown_frame` (int, −1 when hidden):
   - In `_process` (render rate): if `state.flash_requests > consumed_requests` and it is hidden, set `consumed_requests = state.flash_requests`, set `visible = true`, record `shown_frame = Engine.get_frames_drawn()`, and connect **one-shot** to `RenderingServer.frame_post_draw`.
   - In the `frame_post_draw` handler: set `visible = false`, `shown_frame = −1`, and tell `FlashState` the frame was drawn (PENDING → IDLE).
   - **Safety net:** in `_process`, if visible and `Engine.get_frames_drawn() > shown_frame`, hide (covers a missed signal). If `frame_post_draw` proves unreliable in 4.7 (V4), this frame-counter check becomes the primary mechanism.
   - Because `_process` runs before the frame is drawn and the hide happens after it is drawn, the rect is in **exactly one** drawn frame, regardless of how many ticks ran in that frame (30 fps) or how many frames share one tick (144 Hz).
3. **The flag is a counter, not a bool**, so a consumed request cannot be re-shown and a missed frame cannot lose the request: if no frame is drawn (long frame, tab hidden), the request waits, and is shown on the next drawn frame (VFX edge case "held until one frame is drawn").
4. **Pause.** `FlashState` freezes with the tree (no ticks). `FlashPresenter` runs `ALWAYS`, so a request raised on `T+1` before the pause is still drawn once and hidden (R3). No new request can be raised while paused.
5. **Scene change / run end.** `FlashPresenter._exit_tree()` and `stage_started` force hidden and set `consumed_requests = flash_requests`; `FlashState` resets to IDLE (R4).
6. **Display requirements (owned by ADR-0004 / Display scaler):** the game SubViewport uses `render_target_update_mode = UPDATE_ALWAYS`, so one SubViewport render equals one presented frame. The flash is drawn **inside** the SubViewport, never in the window-space overlay (bezel and touch strip never flash).
7. **Refresh rate is not compensated.** At 144 Hz the white frame lasts ~7 ms; at 30 fps ~33 ms. We accept the perceptual difference: "one frame" is the art direction, and a shorter flash is safer, never riskier.
8. **Vsync.** The flash guarantee is defined for vsync on (the default). With vsync off on PC a torn partial white frame is possible; documented, not fixed.
9. **Photosensitivity guard (debug and CI):** a debug-build `FlashAudit` samples the mean luma of each presented canvas frame (from the SubViewport texture, debug only) and logs an error if more than one frame differs from its predecessor by more than 8 % in any 1 s window, or more than 3 such transitions occur in any 1 s window. This is the automated half of VFX AC-06 / CB AC-36. Before release, a CB capture is also run through a dedicated flash-analysis tool (e.g. the free PEAT tool or a Harding test service) — production task.
10. **Frequency limit (by design, recorded here):** ≤ 1 flash per boss; a stage has one boss; Boss Rush bosses are separated by the death sequence (180 ticks), tally and era transition, so the minimum interval between two flashes is well over 3 s (a single flash = one up-and-down transition pair, far below the 3 flashes/s limit). The 3/s rule must also hold **with** the CB background tint (ramp in 6 ticks to 60 %, out over 12): flash + tint = at most 2 large luminance transitions within 1 s. No other system may add a full-screen luminance change (VFX Rule 5).

### Architecture Diagram

```
_physics_process (60 Hz, game ticks per ADR-0005)
  6b CriticalBreakCore ── critical_break_landed(T) ──► step 9 GameEvents
  9  VfxDirector → FlashState.tick(game_tick)
        IDLE ──landed(T), !reduce──► ARMED(T+1) ──tick==T+1──► PENDING: flash_requests += 1
        IDLE ──landed(T),  reduce──► IDLE + CB_BURST particles
                                                     ▲ PENDING → IDLE on "drawn"
_process (render rate, ALWAYS)                        │
  FlashPresenter: requests > consumed ? show, shown_frame = frames_drawn,
                  connect ONE_SHOT frame_post_draw ───┤
RenderingServer draws SubViewport (UPDATE_ALWAYS) → white canvas frame presented
  frame_post_draw ──► FlashPresenter.hide(); FlashState.mark_drawn()
```

### Key Interfaces

```gdscript
class_name FlashState extends RefCounted          # VFX, node-free, headless-testable
var flash_requests: int                           # monotonic; read by the presenter
func on_critical_break_landed(t: int, reduce_flashing: bool) -> void
func tick(game_tick: int) -> void
func mark_drawn() -> void                         # PENDING -> IDLE
func reset() -> void                              # scene change / stage_started

class_name FlashPresenter extends Node2D           # inside the Display SubViewport, z_index 100
func bind(state: FlashState) -> void
```

## Alternatives Considered

### Alternative A (chosen): Tick-side state + render-side one-shot flag confirmed by `frame_post_draw`
Described above.

### Alternative B: Tick-driven visibility (visible during tick `T+1` only)
- **Description**: The presenter shows the rect while `game_tick == T+1`.
- **Pros**: Trivial; no render-side state.
- **Cons**: At 30 fps the tick `T+2` runs before the draw, so the flash is never drawn; at 120/144 Hz it is drawn 2–3 times; game speed < 100 % makes it worse.
- **Rejection Reason**: Violates R1/R2 on exactly the platforms the GDDs name.

### Alternative C: Time-based flash (fixed milliseconds with a shader fade)
- **Description**: White overlay for ~16 ms or a quick fade, driven by real time.
- **Pros**: Same perceived duration on every refresh rate.
- **Cons**: Not "one frame" (art bible); a fade produces several luminance steps; real-time logic in presentation that otherwise derives from ticks; harder to test.
- **Rejection Reason**: Contradicts the art direction and the AC-34 "exactly one fully white frame" test.

### Alternative D: Window-space flash (overlay above the SubViewport)
- **Description**: Flash the whole window, bezel included.
- **Pros**: Independent of the SubViewport update mode.
- **Cons**: Larger flash area (worse for photosensitivity); bezel must never change (Display scaler); covers the touch strip.
- **Rejection Reason**: Breaks Display and accessibility constraints.

### Alternative E: No flash at all (particle burst for everyone)
- **Description**: Ship only the reduce-flashing variant.
- **Pros**: Zero photosensitivity risk; no render-side mechanism.
- **Cons**: Loses the game's single punctuation moment (CB Player Fantasy, art bible §2); design already provides an opt-out and a first-run prompt.
- **Rejection Reason**: A creative call already made in the GDDs; kept as the accessibility path, not the default.

## Consequences

### Positive
- Exactly one presented white frame on 30/60/120/144 Hz, through long frames and pause.
- `FlashState` stays node-free and deterministic; the verifier and unit tests never see a presenter.
- Zero idle cost; one draw call on the flash frame.

### Negative
- Relies on the 4.7 semantics of `frame_post_draw` and SubViewport `UPDATE_ALWAYS` (unverified).
- The flash is shorter in wall-clock time on high-refresh screens.
- With vsync off a torn flash is possible on PC.

### Risks
| Risk | Mitigation |
|---|---|
| `frame_post_draw` timing differs in 4.7 or fires before present | Frame-counter safety net (`get_frames_drawn()`) becomes primary; V4 decides |
| Browser drops a composited frame on Web (frame drawn by Godot but not presented) | Cannot be controlled by the engine; V2 measures the miss rate; accept if ≤ 1 in 20 |
| Android/iOS present a frame twice (compositor repeat) | V3 high-speed capture; accept compositor repeats outside engine control; document |
| A later system adds a second full-screen luminance change | VFX Rule 5 + `FlashAudit` in debug builds + VFX AC-06 capture test |
| SubViewport set to another update mode later (perf work) | Display GDD/ADR-0004 records `UPDATE_ALWAYS` as required by this ADR |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| critical-break.md | Rule 25: white frame at `T+1`, layer 10, exactly one rendered frame; Open Q9 (render-side flag → ADR) | Render-side one-shot flag + post-draw hide |
| critical-break.md | Rule 27: reduce flashing replaces the flash; ≤ 1 flash per boss, under 3 flashes/s | `FlashState` reads `reduce_flashing` at `T`; frequency recorded (Decision 10) |
| critical-break.md | Edge case: long frame holds the flag until one frame is drawn | Request counter waits for the next drawn frame |
| vfx-and-screen-feedback.md | Rule 5, Rule 28, F12, AC-07, AC-23, AC-33, AC-44, AC-51; FlashState table | Exact mapping of IDLE/ARMED/PENDING; pause and scene-change rules |
| accessibility-options.md | Rule 8 (reduce flashing), Rule 34 (first-run photosensitivity prompt) | No white frame when on; audit tool for the 8 % luma rule |
| display-scaler-and-bezel.md | Bezel never changes; SubViewport presenter | Flash drawn inside the SubViewport only |

## Performance Implications
- **CPU**: One integer compare per render frame when idle; one signal connection per CB.
- **Memory**: Negligible.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
1. Delete prototype `screen_flash_requested.emit(...)` calls in `src/gameplay/player/player.gd` and `src/gameplay/boss/boss.gd` (VFX Rule 5 programmer task).
2. Implement `FlashState` (`src/presentation/vfx/flash_state.gd`) with unit tests `tests/unit/test_vfx_flash.gd` (AC-07 with a simulated 30 fps / 144 fps frame schedule).
3. Implement `FlashPresenter` under the Display SubViewport (path per `docs/project-structure.md`).
4. Add the debug `FlashAudit` luma sampler (debug builds only).

## Validation Criteria
- **V1 (gate, REF-PC)** — `tests/perf/flash_capture.tscn` forces 20 flashes at render caps 30, 60, 144 fps (`Engine.max_fps`, vsync on, 144 Hz monitor for the last) and at game speed 50 %: an external capture (or `FlashAudit` on the SubViewport texture) shows exactly one fully white canvas frame per request, none missed, none doubled.
- **V2 (gate, REF-WEB)** — same scene, release Web export, Chrome: ≥ 19 of 20 requests produce exactly one white frame, none produce two.
- **V3 (gate, REF-PHONE)** — release Android export at 30 fps render: 20/20 single frames (240 fps phone camera capture acceptable as evidence).
- **V4** — Pause on `T+1` (AC-51) and scene change mid-flash (AC-33) behave as specified; record whether `frame_post_draw` or the frame-counter safety net did the hiding.
- **V5** — CB AC-36: 10 s capture with reduce flashing on shows no consecutive-frame luma change > 8 %; with it off exactly one.

## Related Decisions
- ADR-0001 (no render interpolation; render decoupled), ADR-0002 (tick order 6b / step 9), ADR-0004 (Display SubViewport host), ADR-0005 (game-speed scheduler).
- Design: `design/gdd/critical-break.md` (Rules 25, 27; OQ9), `vfx-and-screen-feedback.md` (Rule 5, 28, F12, FlashState), `accessibility-options.md` (Rules 8, 34).

> Engine review: not yet run — `godot-specialist` to confirm `frame_post_draw` and SubViewport update semantics in 4.7. TD-ADR skipped — Lean mode.
