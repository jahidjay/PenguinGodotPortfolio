# ADR-0008: Touch Input Device — Virtual TOUCH Device for Slot 0, No Touch-to-Mouse Emulation, Quantized Relative Drag

## Status
**Accepted (2026-11-03)** — accepted with the design set at the Concept → Pre-Production gate. The touch device spike (Validation Criteria V1–V4) on one Android phone, one iPhone and Chrome on Android remains required validation during implementation; a failure amends this ADR.

## Date
2026-11-03

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer |
| **Domain** | Input / Platform (Android, iOS, Web) / Display |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/*` (only input note: 4.7 changed mouse/keyboard `InputEvent.device` to `DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD`; no touch coverage); Input class reference 4.x (web search 2026-11-03): `Input.emulate_mouse_from_touch` ↔ `ProjectSettings.input_devices/pointing/emulate_mouse_from_touch`, `emulate_touch_from_mouse` ↔ `input_devices/pointing/emulate_touch_from_mouse`; `vibrate_handheld(duration_ms, amplitude)` docs: amplitude cannot be changed on Web, unsupported on Safari and Firefox for Android, iOS duration needs iOS 13+ |
| **Post-Cutoff APIs Used** | None knowingly. Relies on `InputEventScreenTouch` (`index`, `position`, `pressed`, `canceled`), `InputEventScreenDrag` (`index`, `position`), the two emulation settings above, `Input.vibrate_handheld`, `DisplayServer.is_touchscreen_available()`, `DisplayServer.screen_get_dpi()`, `DisplayServer.get_display_safe_area()`, `NOTIFICATION_APPLICATION_FOCUS_OUT` / `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_GO_BACK_REQUEST`, `SubViewport.push_input`. Setting **names exist in 4.x docs but are UNVERIFIED for 4.7**; every other item is **UNVERIFIED for 4.7** (Touch GDD OQ1). |
| **Verification Required** | (1) Emulation setting names and that `false` stops synthetic mouse events on Android, iOS **and Web** (browser compatibility mouse events). (2) `InputEventScreenTouch.canceled` exists and fires on system gestures. (3) Multi-touch: ≥ 5 simultaneous indices on Android/iOS/Web. (4) `screen_get_dpi()` and `get_display_safe_area()` on iOS, Android and Web. (5) `vibrate_handheld` amplitude on Android, duration on iOS, Chrome Android behaviour. (6) The default Web HTML shell's touch handling (`touch-action`, overscroll, long-press menu). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (fixed tick, integer/quantized sim input, node-free logic); ADR-0002 (tick order: step 1 Input sampler; touch latched in `_input`); ADR-0003 (replay recording of post-Input sim input — this ADR adds the touch fields it must carry); ADR-0004 (scene host: Display SubViewport, window-space overlay, pointer forwarding to menus) |
| **Enables** | Touch controls epic (system 31): `TouchMapper`, `TouchLayout`, `TouchRouter`, strip presenter, haptics; Display layout strip reserve; Player plane PF8 leash |
| **Blocks** | Phone and touch-Web builds; Touch AC-19, AC-48, AC-57 |
| **Ordering Note** | Input sampler (system 2) and the Display presenter come first. Run the device spike before building the strip presenter. |

## Context

### Problem Statement
Touch controls (system 31) define TOUCH as one more device of Input, bound to slot 0 only, solo only, with relative-drag movement quantized to 1/16 canvas px, a button strip **below** the canvas, and haptics. Four engine-level choices must be fixed: (1) how touch events enter the deterministic per-tick `SlotInput` pipeline; (2) how to stop Godot (and the browser) from delivering a tap twice as touch **and** mouse (Touch Rule 29 "→ ADR"; Input Amendment "Project note"); (3) how the strip reserve enters the Display layout; (4) which haptics API and Web caveats apply.

### Constraints
- Determinism: the sim reads only integer, per-tick input (ADR-0001); the replay logs post-Input values (Input Rule 13a, Online Rule 22).
- No touch element over the canvas, no Node per button inside the SubViewport (Touch Rule 6, Display Rule 19).
- Same build serves desktop Web (mouse) and touch Web; hybrid devices exist (touch laptops).
- 4.7 changed mouse/keyboard `InputEvent.device` ids; never test `device == 0`.

### Requirements
- R1: One physical tap → exactly one activation, in menus and in play (Touch AC-48, AC-19).
- R2: Taps shorter than one tick still register (F1 latching); drag motion consumed by the first tick of a catch-up frame only (Touch Rule 18).
- R3: `SlotInput.drag` is a `Vector2i` in 1/16 canvas px; identical input logs give identical sim results on every platform.
- R4: Touch never binds slots 1–3; mixed TOUCH + pad co-op impossible (Touch Rule 1).
- R5: Focus loss / system gesture releases everything and pauses (Touch Rule 17).
- R6: Layout recomputed only on layout/settings/DPI changes, never per tick (Touch Rule 34).

## Decision

### 1. TOUCH is a virtual device of Input
- Input gets a device class `TOUCH` with **one** instance and a project-defined id (`InputDevices.TOUCH_ID`, not a Godot device id — never read `InputEventScreenTouch.device`). Binding rules live in Input: TOUCH may only bind slot 0; while bound, Start from any other device raises `touch_solo` (Touch Rule 1).
- TOUCH exists when `DisplayServer.is_touchscreen_available()` is true (UNVERIFIED on Web; fallback: create TOUCH lazily on the first `InputEventScreenTouch`).

### 2. Event path (window space → latch → tick)
- A `TouchInputHost` Node in the **root viewport** (window space, above the Display SubViewport; placement per ADR-0004) receives `InputEventScreenTouch` / `InputEventScreenDrag` in `_input`.
- It feeds a node-free `TouchLatch` (per finger index: role, down/up flags since last tick, last position, accumulated window-px motion). Positions use `event.position` (window px); motion is computed from **position deltas**, not `InputEventScreenDrag.relative` (avoids stretch-transform and version differences).
- **While the session is Playing** the host calls `get_viewport().set_input_as_handled()` for every touch event: nothing reaches the SubViewport, GUI or menus (Touch Rule 29).
- **In every other state** (`TouchRouter`): touches are mapped with Display `window_to_canvas` (F7) and forwarded into the game SubViewport as **one synthesized pointer stream** (`InputEventMouseButton` / `InputEventMouseMotion` in canvas coordinates via `SubViewport.push_input`, UNVERIFIED in 4.7) so menu models and any standard Control see exactly one event per tap. Strip buttons are inactive outside Playing.
- **`TouchMapper`** (node-free `RefCounted`) runs **inside the Input sampler tick (step 1)**: it drains `TouchLatch`, applies finger roles (Rules 12–16), button capture/slop, TF3 (jitter accumulator, `360 / dw`, `sens`), **rounds half away from zero to integers in 1/16 canvas px**, generates auto-fire pulses from the integer tick counter (F6), and writes `SlotInput.drag`, `drag_active`, `fire`, `drone`, `bomb`, `start`, `fire_auto` for slot 0. Accumulated motion is zeroed after the first tick of a frame (R2).
- Float maths happens **only before quantization** (window px → canvas units). The sim, the leash (PF8/TF4) and the replay see only integers, so platform float differences in the mapper cannot desync a replay.

### 3. Touch-to-mouse emulation OFF (project-wide, static)
- `input_devices/pointing/emulate_mouse_from_touch = false` in `project.godot` for **all** builds. Rationale: a runtime toggle per session state leaves a window where both streams exist; a static off-switch plus the `TouchRouter` (Decision 2) gives exactly one pointer stream everywhere. Setting name from the 4.x class reference; **UNVERIFIED for 4.7** (V1).
- `input_devices/pointing/emulate_touch_from_mouse = false` in release. A **debug-only** override may turn it on for desktop testing of the touch path; when on, `TouchInputHost` ignores real mouse buttons so a click is not seen twice.
- **Web:** browsers synthesize compatibility mouse events from touches. Whether Godot's Web platform suppresses them is UNVERIFIED; V1 tests it on Chrome Android and iOS Safari. Fallback: `TouchInputHost` drops `InputEventMouseButton` events that arrive within 500 ms of a touch at the same position (debounce) — only if V1 shows doubles.

### 4. Strip reserve in the Display layout
- `TouchLayout` (node-free) computes `ppmm` (TF1: `clamp(dpi / 25.4, 10, 24)`, fallback 16), `s_btn`, `strip_px` and button hit rects (TF2) from the safe rect and settings. It runs on `layout_changed`, settings change or DPI change only (R6).
- `DisplayLayout.compute(window, safe_area, mode, tate, touch_strip_px)` subtracts the strip from the bottom of the effective area and returns `touch_strip_rect` (Display Rule 4 amendment). `touch_strip_px` is **latched** while Playing; a change applies at the next non-Playing state (Touch Rule 3).
- The strip and buttons are drawn by a `TouchStripPresenter` in Display's window-space overlay layer (W3), never inside the SubViewport. Buttons are drawn plates, not `TouchScreenButton` nodes.
- **Web/DPI:** `screen_get_dpi()` on Web is expected to be unreliable; if it returns ≤ 0 or an implausible value, `ppmm = 16` (TF1 fallback). Web safe area = full window (Display Rule 15) unless V3 shows otherwise.

### 5. Haptics
- `HapticsPresenter` (presentation; listens to `GameEvents`, never read by the sim) calls `Input.vibrate_handheld(duration_ms, amplitude)` with the Touch Rule 32 limits (one pulse per `haptic_gap_ticks`, strongest wins, OFF/LOW/NORMAL). Platform notes: amplitude honoured on Android only (UNVERIFIED for 4.7); iOS duration needs iOS 13+; Web amplitude ignored and unsupported on Safari / Firefox Android → silently no-op. Android export needs the vibrate permission (preset option name UNVERIFIED).
- Haptics only fire when slot 0 is TOUCH (no phone buzz for pad players on the same phone).

### 6. Focus loss, cancel, back
- `InputEventScreenTouch.canceled`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED` and (Web) window focus loss → `TouchLatch.release_all()`, accumulators cleared, pause requested if Playing (Touch Rule 17). Android Back (`NOTIFICATION_WM_GO_BACK_REQUEST`) → `back`.
- Landscape on a touch device → pause + rotate prompt (Touch Rule 11); handled by `TouchRouter` from `layout_changed`.

### 7. Web shell requirements
- The exported HTML shell (custom shell if the default lacks them, UNVERIFIED) sets on the canvas: `touch-action: none`, `overscroll-behavior: none` on the page, suppresses the long-press context menu and text selection, and disables double-tap zoom (`<meta name="viewport" ... user-scalable=no>`). iOS Safari has no Fullscreen API on iPhone: address-bar resize events are expected and handled by `layout_changed` (Touch edge cases).

### 8. Replay and determinism (input to ADR-0003)
- A touch run's replay must carry the **post-mapping integers**: per tick (run-length) `drag.x`, `drag.y` (int16 each, 1/16 px; per-tick values are leash-bounded in practice but must be clamped to int16 by the mapper), `drag_active` and `fire_auto` in addition to `sim_input_byte`. The 4-bit 8-way move nibble cannot represent DRAG. **ADR-0003 owns the record format**; this ADR states the requirement. Until it is added, touch runs are **not uploadable** (they still rank locally on `/touch` boards).

### Architecture Diagram

```
Window (root viewport)                                      Game SubViewport 360x640
 _input: InputEventScreenTouch/Drag ─► TouchInputHost ─┐     (no touch while Playing)
           (emulate_mouse_from_touch = false)          │
     Playing:   set_input_as_handled ─► TouchLatch ────┤
     Not playing: TouchRouter ─ window_to_canvas ─ push_input(one mouse stream) ─► Menus
                                                       │
_physics_process step 1: InputSampler ─► TouchMapper.tick(latch, layout, settings, tick)
     roles, slop, TF3 → round_half_away(…*16) → SlotInput[0].drag:Vector2i, fire_auto, buttons
     → PlaneCore PF8 leash (integers) ; sim_input + drag → ReplayRecorder (ADR-0003)

layout_changed ─► TouchLayout (ppmm, s_btn, strip_px) ─► DisplayLayout(touch_strip_px) ─► strip rect
W3 overlay: TouchStripPresenter (plates)      GameEvents ─► HapticsPresenter ─► vibrate_handheld
```

### Key Interfaces

```gdscript
class_name TouchLatch extends RefCounted
func on_event(e: InputEvent) -> void              # called from TouchInputHost._input
func release_all() -> void

class_name TouchMapper extends RefCounted           # step 1, inside the sampler tick
func tick(latch: TouchLatch, layout: TouchLayoutResult, rules: TouchRules, tick: int, out: SlotInput) -> void

class_name TouchLayout extends RefCounted
func compute(safe_rect: Rect2i, dpi: float, settings: Dictionary, rules: TouchRules) -> TouchLayoutResult  # strip_px, hit rects

# DisplayLayout (Display scaler) gains: touch_strip_px input, touch_strip_rect output
```

## Alternatives Considered

### Alternative A (chosen): Static emulation off + own router + quantized mapper in the sampler tick
Described above.

### Alternative B: Toggle `Input.emulate_mouse_from_touch` at runtime (on in menus, off in play)
- **Pros**: Standard Controls work in menus without a router.
- **Cons**: State transitions can leak a duplicate or lost tap; behaviour depends on when the engine reads the flag; two code paths to test.
- **Rejection Reason**: R1 is easier to guarantee with one static configuration.

### Alternative C: `TouchScreenButton` / Control buttons for the strip
- **Pros**: Built-in pressed states.
- **Cons**: Lives in a canvas/viewport space, would be inside or above the SubViewport; signals per event not latched per tick; harder to apply roles/slop rules and to test headless.
- **Rejection Reason**: Breaks the "nothing over the canvas" rule and per-tick latching.

### Alternative D: Absolute positioning (plane follows the finger)
- **Pros**: Simple, common in mobile shmups.
- **Cons**: Thumb occludes the hitbox; teleports; can exceed the pad speed cap.
- **Rejection Reason**: Rejected by the Touch GDD (anti-fantasy, Every Hit Counts).

### Alternative E: Float drag passed to the sim
- **Pros**: No quantization step.
- **Cons**: Platform float differences reach the sim and replays; violates ADR-0001 determinism.
- **Rejection Reason**: R3.

## Consequences

### Positive
- One pointer stream everywhere; no double taps.
- Touch input is deterministic and replayable as integers.
- The strip never overlaps the canvas; layout changes never happen mid-run.

### Negative
- Menus must work from the router's synthesized pointer stream (no reliance on native touch handling in Controls).
- A custom Web HTML shell may be needed.
- Replay format grows for touch runs (ADR-0003).

### Risks
| Risk | Mitigation |
|---|---|
| Emulation setting renamed/behaves differently in 4.7 | V1 on device; fallback debounce filter (Decision 3) |
| Browser compatibility mouse events leak on Web | V1 on Chrome Android / iOS Safari; debounce; custom shell `touch-action: none` |
| DPI wrong on Web/iOS → buttons too small | TF1 clamp 10–24 ppmm + 16 fallback; `touch.button_scale` setting; V3 measures |
| `canceled` missing → stuck button | Focus-out notifications also release all; slop release (Touch Rule 13) |
| Haptics unsupported (iOS Web, Firefox) | Presentation only; silent no-op |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| touch-controls.md | Rule 1 (TOUCH device, slot 0, solo), Rules 12–18 (roles, latching, cancel) | Decisions 1, 2, 6 |
| touch-controls.md | Rule 19 / TF3 (1/16 px integer drag), Rule 34 (node-free, layout not per tick) | Decision 2, 4 |
| touch-controls.md | Rule 29, edge case, AC-19, AC-48: emulation off "→ ADR" | Decision 3 |
| touch-controls.md | Rule 6 / TF2 strip reserve; Rule 32 haptics; OQ1 unverified APIs | Decisions 4, 5; Verification Required |
| display-scaler-and-bezel.md | Rule 4 amendment (`touch_strip_px`, `touch_strip_rect`), Rule 15 safe area, Rule 19 overlay | Decision 4 |
| input-and-player-mapping.md | Rule 13 `SlotInput.drag/drag_active/fire_auto`; Rule 13a sim byte; F1 latching | Decisions 2, 8 |
| player-plane.md | PF8 leash on integers | Integers only reach the sim |
| online-leaderboards-boss-rush.md | Rule 22 replay logs post-Input values | Decision 8 (requirement to ADR-0003) |

## Performance Implications
- **CPU**: ≤ 5 fingers per tick; well under 0.05 ms in the sampler (to be measured on REF-PHONE).
- **Memory**: Negligible.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
1. Set both emulation settings in `project.godot` (after V1 confirms names).
2. Add the TOUCH device class and slot-0 rule to the Input sampler; `TouchLatch` / `TouchMapper` with unit tests (Touch AC-21..27).
3. Add `touch_strip_px` to `DisplayLayout`; `TouchStripPresenter` in the W3 overlay.
4. `TouchRouter` + menu pointer forwarding; `HapticsPresenter`.
5. Custom Web shell if V1/V4 require it.

## Validation Criteria
- **V1 (gate)** — Android, iOS, Chrome Android: one tap on a menu item = one activation (AC-48); while Playing, touches never reach the SubViewport (AC-19); no synthetic mouse event observed with emulation off.
- **V2** — 5 simultaneous touches tracked; notification pull-down mid-stage releases all buttons and pauses (AC-57).
- **V3** — Log `screen_get_dpi()`, safe area and computed `strip_px` on the test devices; buttons measure ≥ 9 mm with a ruler.
- **V4** — Haptics: Android amplitude LOW vs NORMAL distinguishable; iOS pulses; Chrome Android pulses or no-ops without error.
- **V5** — Determinism: the same recorded touch latch sequence fed to `TouchMapper` on Windows, Web and Android yields identical `drag` integers (ties into ADR-0003's spike).

## Related Decisions
- ADR-0001, ADR-0002 (step 1), ADR-0003 (replay format must add touch fields), ADR-0004 (overlay / router placement), ADR-0005 (game speed: drag consumed per **game** tick).
- Design: `design/gdd/touch-controls.md`, `input-and-player-mapping.md`, `display-scaler-and-bezel.md`, `player-plane.md` (PF8).

> Engine review: not yet run — `godot-specialist` to confirm the Touch GDD OQ1 API list for 4.7. TD-ADR skipped — Lean mode.
