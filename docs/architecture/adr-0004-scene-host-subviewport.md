# ADR-0004: Scene Host, 360x640 SubViewport Display Pipeline and Staged Loading

## Status
**Accepted (2026-11-03)** — accepted with the design set at the Concept → Pre-Production gate. The display spike (V1) and the loading spike (V2) remain required validation during implementation. If V1 fails, the built-in stretch fallback (Alternative B) is adopted by amending this ADR; the scene host and loading rules stay either way.

## Date
2026-11-03

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer (WebGL2 on Web) |
| **Domain** | Rendering / Scene management / Resources |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/` (2026-11-03): 4.7 new-project stretch defaults `canvas_items` + `expand` (must be set explicitly); 4.6 `.tscn` format change |
| **Post-Cutoff APIs Used** | None knowingly. Uses `SubViewport` (`size`, `render_target_update_mode`, `canvas_item_default_texture_filter`, `snap_2d_transforms_to_pixel`, `snap_2d_vertices_to_pixel`), `ViewportTexture`, `Viewport.push_input`, `ResourceLoader.load_threaded_request/_get_status/_get`, `PackedScene.instantiate`, `Engine.get_process_frames()` — **all UNVERIFIED for 4.7**; threaded loading on the single-threaded Web export especially. |
| **Verification Required** | (1) SubViewport render + sharp-bilinear present on REF-WEB/REF-PHONE within Display AC-47/48. (2) `push_input` pointer forwarding, multi-touch. (3) SubViewport keeps rendering while `SceneTree.paused`. (4) 2D snap property names in 4.7. (5) Whether `load_threaded_request` progresses incrementally or blocks on the no-threads Web build. (6) Godot's catch-up behaviour after a long stall (how many render frames carry backlog steps). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0002 (GameLoop gates, MenuHost at step 0) |
| **Enables** | Display scaler, Menus, Session run flow, Era shift and Parallax loading epics; ADR-0005 (discard/gate order); ADR-0006 (flash in the SubViewport) |
| **Blocks** | Moving `project.godot` to 360x640 / stretch disabled; any menu or run-flow code |
| **Ordering Note** | Run V1 before the Display epic; run V2 before Era shift implementation. |

## Context

### Problem Statement
The Display scaler GDD renders everything into a fixed 360x640 canvas shown by a presenter with a sharp-bilinear shader, TATE rotation and an era bezel; built-in stretch cannot do sharp-bilinear Fill or TATE. Because `change_scene_to_*` puts scenes under the root window, game and menu scenes need a custom host inside the SubViewport (Display OQ1/OQ4). Menus need 60 Hz node-free models running while paused and a `start_run` pre-load handshake (Menus OQ12); Era shift stages VRAM by freeing and loading era sets mid-run, with a synchronous fallback whose hitch must not cause a catch-up burst (Era OQ10, Session wave 3b).

### Constraints
- Fixed 360x640 canvas, nothing reads the screen size (Display Rule 1).
- Web: single-threaded export, no COOP/COEP (ADR-0001 REF-WEB).
- VRAM peak ≤ 96 MB target, staged 74 MB (Era F3).
- Logic is tick-based; presentation is real time.

### Requirements
- One host that swaps menus and runs without `change_scene_to_*`.
- A run starts only after its content is resident; failure returns to the lobby with nothing started.
- A blocking load never produces more than one game tick per render frame afterwards.

## Decision

1. **Root layout.**
```
root (Window, stretch mode DISABLED, base 360x640)
├── autoloads: InputSampler, GameEvents, GameSession, SaveStore, Localization, AudioDirector
└── Main (main scene)
    ├── DisplayPresenter (Node2D, ALWAYS)   bezel W0–W1, canvas sprite W2 (ViewportTexture + sharp_bilinear.gdshader), overlays
    └── GameViewport (SubViewport 360x640, ALWAYS, UPDATE_ALWAYS, nearest, 2D snap on)
        └── SceneHost (Node, ALWAYS)
            ├── RunLayer   (PAUSABLE)  run.tscn: GameLoop (ALWAYS, ADR-0002) + views
            ├── MenuLayer  (ALWAYS)    MenuHost + current screen views
            └── OverlayLayer (ALWAYS)  pause panel, toasts, loading plate
```
   The presenter maps pointer events window→canvas (Display F7) and forwards them with `GameViewport.push_input()`; keys/pads are read by `InputSampler` at the root (forwarding them is harmless; nothing in the SubViewport reads raw key events). The game SubViewport uses `UPDATE_ALWAYS` (ADR-0006 relies on it).
2. **Custom scene host, no `change_scene_to_*`.** `SceneHost.show_screen(id)` swaps menu views under MenuLayer; `SceneHost` owns a node-free `RunFlow` controller that follows Session's run-state table (Title → Lobby → Stage ⇄ Tally → Results) and mounts/unmounts `run.tscn`. **Session owns run state; RunFlow owns scenes.** This closes Session OQ7, Menus OQ12 and Tally OQ9: `GameSession` stays the run-state autoload; `LobbyModel` lives in MenuLayer (Menus); the Tally is a sim system in `SimWorld` (ADR-0002 step 8e) with its view in RunLayer.
3. **MenuHost.** `MenuModel`, `LobbyModel`, `PauseModel`, `NameEntryModel`, `ResultsFlow`, `HoldConfirm` are node-free and ticked by `MenuHost` once per **physics step** (60 Hz real time, step 0 of ADR-0002) with `PROCESS_MODE_ALWAYS`, so they run while paused and ignore the game-speed gate.
4. **`start_run(selections, mode, stage_list)` handshake.**
   1. `LobbyModel` commits → `RunFlow.request_start(selections, mode, stage_list)`; Lobby shows a loading plate; no game ticks exist yet.
   2. **Pre-load**: `run.tscn` (resident since boot), era 0 `core` + `env` sets, stage 0 `StageDef` (+ validation in debug), bullet shader warm-up (ADR-0001), Bengali shaping pre-warm (Localization AC-41), audio bank. Loaded with the `StagedLoader` (Decision 6).
   3. **Success** → instantiate `run.tscn` under RunLayer; call `GameSession.start_run(selections, mode, stage_list)` (picks `run_seed`, emits `run_started`); Era shift finds era 0 resident and emits `era_ready` on its first tick; Director `load_stage(0)`; free the lobby views; `GameLoop.discard_backlog()`.
   4. **Failure** → nothing is instantiated, Session is never started; Lobby re-opens with every slot Locked and an error toast (Menus edge case).
5. **Staged era loading** (Era shift Rules 17–23): free old `core` at `stage_cleared`, request next `core`; at transition **tick 53** (card covers the canvas) free old `env`, request next `env`; poll every `poll_ticks` (6). If not ready at `era_hold_max`, load synchronously, emit `era_load_late`, then `discard_backlog()`. The release tick is recorded for replays (ADR-0003 Decision 7).
6. **`StagedLoader`** (one interface, two backends chosen by the V2 result):
   - **Threaded** (desktop, mobile, and Web if V2 shows incremental progress): `load_threaded_request` + polling.
   - **Sliced** (Web if V2 shows the request blocks the main thread): one resource `load()` per poll, issued **only while the canvas is covered** (era card ticks 53–200, Tally panel, lobby loading plate); the `core` request moves from `stage_cleared` to tick 53 on Web; each slice calls `discard_backlog()`.
   - The verifier/test backend loads synchronously and reports ready at the recorded tick (ADR-0003).
7. **Blocking-load rule (drop, never catch up).** Any synchronous load or `instantiate()` during a run calls `GameLoop.discard_backlog()`. Effect: for the rest of the current render frame and the next `discard_frames` (default 2, `data/core/loop_rules.tres`) render frames, **at most one game tick runs per render frame** (fence on `Engine.get_process_frames()`); other admitted physics steps run no game tick, add nothing to the speed accumulator (ADR-0005) and keep input latches. Dropped steps change no sim result (ticks are identical; only wall-clock pacing changes). The tick guard reports the load as `load_hitch`, not a budget breach. If V2 shows backlog lasting longer, `discard_frames` is raised or the fence switches to "drop steps arriving < 8 ms after the previous admitted tick".
8. **Fallback if V1 fails (Alternative B):** root stretch `viewport`, `aspect keep`, `scale_mode integer`, base 360x640; Fill degrades to Pixel Perfect, TATE dropped; `SceneHost` moves under the root unchanged (same API), so RunFlow/menus code does not change.

### Key Interfaces

```gdscript
class_name SceneHost extends Node
func show_screen(id: StringName) -> void
func request_start(selections: Array, mode: int, stage_list: Array) -> void   # handshake, Decision 4
signal start_failed(reason: int)

class_name RunFlow extends RefCounted        # follows GameSession run state; mounts/unmounts run.tscn
class_name StagedLoader extends RefCounted   # request(set_id), poll() -> int (READY/LOADING/FAILED), load_now(set_id)
# GameLoop.discard_backlog() — ADR-0002
```

## Alternatives Considered

### Alternative A (chosen): SubViewport presenter + custom SceneHost + StagedLoader
Described above.

### Alternative B: Built-in `viewport` stretch, integer scale
- **Pros**: No presenter or input forwarding; least risk.
- **Cons**: No sharp-bilinear Fill, no TATE, bezel harder.
- **Rejection Reason**: Loses Display GDD features. **Designated fallback** (Decision 8).

### Alternative C: `SubViewportContainer` instead of a manual presenter
- **Pros**: Automatic input forwarding.
- **Cons**: Integer `stretch_shrink` only; TATE rotation and the shader path unclear.
- **Rejection Reason**: Evaluated inside V1 (Display OQ2); adopt if it supports the shader and rotation.

### Alternative D: `change_scene_to_*` with menus as separate root scenes
- **Rejection Reason**: Scenes land under the root window, outside the SubViewport.

### Alternative E: Catch-up after a blocking load
- **Rejection Reason**: Up to 8 ticks in one frame = a visible speed burst and unfair input; Session/Era GDDs require discard.

## Consequences

### Positive
- One canvas for game and menus on every device; menus live while paused.
- Runs never start half-loaded; load failure is clean.
- VRAM stays staged; loading hitches are hidden and never speed the game up.

### Negative
- Manual pointer forwarding and a presenter to maintain.
- Web loading may need the sliced backend and moved request points.
- The SubViewport adds a full-canvas blit (≤ 0.5 ms, Display AC-48).

### Risks
| Risk | Mitigation |
|---|---|
| Presenter cost or sRGB mismatch on Web/phones | V1; fallback B |
| Threaded load blocks on Web | V2; Sliced backend under the card |
| SubViewport stops rendering while paused | V1 check; set the viewport ALWAYS / force update |
| Catch-up lasts beyond `discard_frames` | V2 stall test; wall-clock fence variant |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| display-scaler-and-bezel.md | Rules 1, 9, 18, 22; OQ1, OQ2, OQ4 | Decisions 1, 2, 8; V1 |
| menus-title-plane-select.md | Rule 2, 23; OQ12; models at 60 Hz ALWAYS; load-failure edge case | Decisions 2–4 |
| game-events-and-session.md | OQ7 run-flow ownership; blocking load discards ticks | Decisions 2, 7 |
| stage-end-tally.md | OQ9 run-flow ownership of the tally | Decision 2 |
| era-shift-and-plane-evolution.md | Rules 16–23, OQ2 (Web threaded load), OQ10 | Decisions 4–7 |

## Performance Implications
- **CPU**: presenter ≈ 0.05 ms; MenuHost ≤ 0.1 ms (menus only).
- **GPU**: present pass ≤ 0.2 ms PC / ≤ 0.5 ms phone (Display AC-47).
- **Memory**: 360x640 RGBA8 target ≈ 0.9 MB; era staging peak 74 MB.
- **Load Time**: run start = era 0 + stage 0 sets; measured in V2.

## Migration Plan
1. `project.godot`: stretch mode disabled, base 360x640, main scene `Main.tscn` (after V1).
2. Move `game.tscn` content into `run.tscn` under RunLayer; HUD from CanvasLayer into the SubViewport.
3. Replace `GameSession` scene changes with `SceneHost`/`RunFlow`.

## Validation Criteria
- **V1 (display spike, art bible §8.9 spike 3 extended)** — REF-PC/WEB/PHONE: sharp-bilinear Fill and integer modes, TATE CW/CCW, pointer + multi-touch forwarding via `push_input`, SubViewport renders while paused, 2D snap active; Display AC-47/48 met.
- **V2 (loading spike)** — REF-WEB and REF-PHONE: time and main-thread blocking of `load_threaded_request` for a 36 MB env set; a forced 500 ms synchronous load → count game ticks per render frame for the next 5 frames (expect ≤ 1 during the window, normal after); Era AC-40 holds.
- **V3** — Handshake: injected load failure → Lobby re-opens Locked, `run_started` never emitted; success → `run_started` once, first game tick after `discard_backlog`.

## Related Decisions
- ADR-0002 (gates, MenuHost), ADR-0003 (recorded era release), ADR-0005 (discard before the speed gate), ADR-0006 (flash relies on UPDATE_ALWAYS), ADR-0008 (touch strip / pointer stream).

> Engine review: not run (lean mode); listed APIs UNVERIFIED for 4.7.
