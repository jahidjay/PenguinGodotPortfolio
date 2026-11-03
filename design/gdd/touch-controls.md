# Touch Controls

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (ux-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts (the plane goes where the thumb goes, never faster than a pad, and no tap is lost), Readable Chaos (nothing is drawn over the canvas and the hitbox is never hidden by design), Four Planes, Four Games (the same Fire / Drone / Bomb grammar as pad and keyboard)

> **Revision 2026-11-09 (scheduling, no design change)**: **deferred until the PC scheme is final.** The owner's requirement, recorded 2026-11-09: controls land for **keyboard and gamepad on PC first**, and "later we will add button UI for mobile users". Nothing in this design changes - the TOUCH device, the relative-drag mapping, auto-fire, the button strip and the touch boards all stand as approved - but **no part of it is implemented**, and a mobile build today has no controls at all. The order of work is: PC bindings (done, see [Input (2)](input-and-player-mapping.md) "Implementation status") → `SlotInput` / device assignment → this GDD's TOUCH device and button strip. The one thing already true in code is that the canvas is fixed at 360x640 on every device, which is what the button strip needs ([Display scaler (4)](display-scaler-and-bezel.md)).

## Overview

**The data layer:** Touch controls is the **TOUCH device** of Input (2). On iOS and Android (and touch browsers) it turns fingers into the same per-tick `SlotInput` snapshot that pads and keyboards produce. It owns: the finger roles (one **move finger**, up to three **button fingers**, one pause finger), the **relative-drag** movement mapping (1:1 with what the player sees on screen, quantised to 1/16 canvas px, with a short "leash" so the plane never moves faster than `move_speed`), the optional **floating 8-way stick** scheme, **auto-fire** (a synthetic 1-tick Fire tap every 10 ticks), the **button strip** (Hold/Fire, Drone, Bomb, Pause) sized in millimetres below the canvas, the rule that **nothing is drawn over the canvas**, haptics, the touch settings, and the rule that touch runs are **solo only** and rank on **their own boards**. It does not decide what a button does (kits and Bombs do), does not scale the canvas (Display scaler and bezel (4) does, but it reserves a bottom strip for us), and does not own menu layout (Menus (22)); it supplies the rule that menu targets be at least 9 mm.

**The player impact:** a phone player drags a thumb anywhere to fly, taps two buttons with the other thumb to use the drone and bomb, and holds a third to charge. The plane never jumps to the finger, never outruns a pad player, and stops within about 4 ticks of the thumb stopping. The thumb never has to sit on the plane, and no button ever covers a bullet. A bad touch scheme would make the game feel unfair ("my thumb hid the hitbox", "the plane teleported", "I pressed Bomb and it did not register"); this design exists so every death on a phone is still the player's fault (**Readable Chaos**).

## Player Fantasy

**Anchor moment: one thumb steers, the other one saves you.** The curtain closes. The right thumb is gliding the plane through a lane at the speed of a careful drag. The left thumb drops onto Bomb without the eyes leaving the field, and the buzz in the palm says "it went off" a tick before the screen does. Then the thumb slides to Hold, the laser lens glows, the right thumb never stopped.

- **Honest movement.** The plane moves as far as the finger moved, on screen, and never faster than a pad player (`move_speed` 210 px/s). If the thumb stops, the plane stops.
- **Eyes on the sky.** All buttons live in a strip under the field. Nothing sits over the bullets. The thumb can rest below the plane because the plane does not need to be touched.
- **No lost taps.** A 5 ms tap on Bomb still fires (Input F1 latching).
- **Big, calm controls.** Every button is at least 9 mm across, most are 11-12 mm with a larger invisible hit area. Controls are quiet plates, not glowing joysticks.
- **Everyone can play.** One-hand mode, left-hand mirror, drag speed, button size and vibration level are first-class settings.

MDA: Aesthetic = Challenge (fair), Sensation (haptics). SDT: Competence (clear cause and effect), Autonomy (scheme, hand, sensitivity). Reference feel: arcade shooters with relative-drag touch ports, but with the plane's speed capped like a pad.

**Anti-fantasy (must never happen):** the plane teleporting to the finger; a button that covers bullets; a thumb that must sit on the plane to steer; an accidental Bomb from a palm on the screen edge; a stuck button after a notification pull-down; touch players quietly sharing a leaderboard with pad players when their inputs differ.

> `creative-director` and `art-director` not consulted (auto-approve). Button look is the art-director's call; this document defines sizes, states and limits.

## Detailed Design

### Core Rules

**Scope and device**

1. **TOUCH exists on phones and tablets in portrait** (iOS, Android) and on Web when the browser reports a touchscreen (*unverified in 4.7*: `DisplayServer.is_touchscreen_available()`). It is one device instance, bound only to **slot 0 (P1)**, **solo only** (Input Rule 2). While TOUCH is bound, a Start press from any other device is ignored and raises `touch_solo` (Menus shows "Touch play is solo only"). TOUCH can never bind to slots 1-3.
   - *Why solo:* the phone shows one 360x640 field about 60-70 mm wide; two thumbs per player would collide, two 15 mm button strips do not fit, and 4P HUD columns are 90 px (about 4 mm at x3). Co-op on phones is for pads (Bluetooth) or other platforms.
2. **Touch boards.** A run whose slot 0 is bound to TOUCH at run start is a **touch run**. Its `board_id` gets the suffix `/touch` (F8). Touch runs never share a board with pad/keyboard runs. The binding is fixed for the run (Input Rule 5).
   - *Why:* DRAG gives continuous direction (a pad has 8) and auto-fire removes a skill (trigger discipline). The speed cap is the same, but the inputs are not equivalent, and comparable scores are the point of **Every Hit Counts**.
3. **Visibility.** Touch controls are shown when the platform has touch **and** P1 is TOUCH or unbound. If a pad or keyboard binds as P1 (Menus Lobby), the strip reserve is removed and the buttons hide. This change is applied only while the session is **not Playing** (Display layout never jumps mid-run).
4. **Scheme settings** (stored by Save, keys in Tuning Knobs): `touch.scheme` DRAG (default) or STICK; `touch.autofire` on (default) or off; `touch.hand` RIGHT (default: right thumb drags, buttons on the left) or LEFT (mirror); `touch.one_hand` off; `touch.sens`; `touch.button_scale`; `touch.haptics`.

**Layout: the button strip (all sizes in millimetres)**

5. **Millimetres, not pixels.** Sizes come from the screen DPI: `ppmm = clamp(dpi / 25.4, 10, 24)` (F1). If the DPI query fails or returns 0 or less, `ppmm = 16.0`. (*Unverified in 4.7:* reliability of `DisplayServer.screen_get_dpi()` on iOS, Android and Web; see Open Questions.)
6. **Strip reserve.** The bottom `strip_px` of the **safe area** (F2) is reserved for the buttons. Display (4) lays the canvas out in the safe area **minus the strip**, so the strip joins the bottom bezel and **never overlaps the canvas** (amendment to Display Rules 4, 15, 19). The reserve is constant in every session state (Title, Lobby, Stage, Pause, Tally) so the canvas never resizes between menus and play. This replaces the Display draft "buttons over the lower corners at 50% opacity": **no touch element is ever drawn over the canvas.**
7. **Buttons** (nominal sizes at `s_btn = 1`; hit area = visual + `hit_pad_mm` 1.5 on every side; gaps between visuals 3 mm):

| Button | Visual | Hit area | Action it writes | Notes |
|---|---|---|---|---|
| **Hold** (label "Fire" when auto-fire is off) | 12 mm | 15 mm | `fire` | Leftmost of the cluster (hand RIGHT) |
| **Drone** | 11 mm | 14 mm | `drone` | Middle; cooldown bar (Rule 27) |
| **Bomb** | 12 mm | 15 mm | `bomb` | Right of the cluster; stock numeral |
| **Pause** | 9 mm (fixed) | 12 mm | `start` | Far end of the strip, away from the cluster |

   Every visual is **9 mm or more** (the minimum target); every hit area is **12 mm or more**. Left margin 4 mm (hit area starts 2.5 mm from the edge), Pause right margin 4 mm. Exact positions in F2.
8. **Cluster scale.** `s_btn = clamp((W_mm - 20) / 41, s_min, s_user)` where `W_mm` is the safe-area width in mm, `s_user` is 1.00 / 1.25 / 1.50 (`touch.button_scale`) and `s_min = 0.82` (so the smallest button, Drone, never falls under 9 mm: 11 x 0.82 = 9.02). Gaps scale with `s_btn`; hit padding and Pause do not. The strip height follows: `strip_mm = 3 + 12 x s_btn` (15 mm at 1.00).
9. **Mirror.** `touch.hand = LEFT` mirrors every x position about the screen centre (cluster on the right, Pause on the left). Order from the screen edge stays Hold, Drone, Bomb.
10. **One-hand mode** (`touch.one_hand`): the cluster sits on the **same side as the dragging thumb** (use with `touch.hand` to choose the side), and **Hold becomes a toggle** (Input Rule 19: tap on, tap off; the latch resets on death, pause and stage start). Drone and Bomb are taps. The player lifts the drag thumb to tap a button; because movement is relative, the plane simply stops while the thumb is up.
11. **Landscape.** If a touch device is in landscape (width > height), the game pauses and shows "Rotate your phone upright" (Rule 29). No landscape layout is designed (Open Questions).

**Fingers (multi-touch)**

12. Every touch is assigned **one role at touch-down and keeps it until lift**: **BUTTON(id)** (it started inside that button's hit area), **MOVE** (the first touch that starts outside every button and outside the edge-reject margin, while no MOVE finger exists), or **IGNORED** (every other touch). Roles never change mid-touch.
13. **Button capture.** A BUTTON finger keeps its button while it stays within `slop_mm` (4 mm) of the hit area; past that distance the button is **released** (no stuck buttons) and the finger becomes IGNORED. A finger sliding from one button onto another does **not** press the second one.
14. **One MOVE finger.** A second non-button touch while MOVE exists is IGNORED. If MOVE lifts, an already-down IGNORED finger is **not promoted**; the player must lift and touch again. This stops the plane jumping when a resting second finger would take over.
15. **Edge reject.** A touch that starts within `edge_reject_mm` (2 mm) of the left or right window edge is IGNORED (grip palms). Buttons start 2.5 mm from the edge, so they are not affected.
16. **Pointer cap.** At most `max_pointers` (5: MOVE + 3 buttons + Pause) are tracked; a 6th simultaneous touch is IGNORED.
17. **Cancel and focus loss.** A cancelled touch (`InputEventScreenTouch.canceled`, *unverified in 4.7*), app backgrounding, a notification pull-down or a system gesture releases **every** tracked finger at once (all buttons `released`), clears accumulators, and requests a pause if the session is Playing (Input Rule 26).
18. **Latching.** Touch events are latched in `_input` exactly like other devices (Input Rule 10, F1): a tap shorter than one tick still gives `pressed` on tick T and `released` on T+1. Drag motion is accumulated between ticks and consumed by the **first** tick that runs (Input Rule 11); later ticks of a catch-up frame see zero new motion.

**Movement: DRAG scheme (default)**

19. **Relative drag.** The plane never snaps to the finger. Each tick the sampler converts the MOVE finger's window-pixel motion since the last tick into **canvas-pixel motion at the on-screen ratio** (F3: `360 / dw`, so the plane moves the same distance on screen as the finger, times `sens`), filters sub-`drag_min_mm` jitter, and writes it as `SlotInput.drag` in **1/16 canvas px** (integers). `drag_active` is true while a MOVE finger exists.
20. **Leash and speed cap** (rule lives in Player plane, new PF8, F4). The plane keeps a `pending` vector (units of 1/16 px): each tick `pending = clamp_len(pending + drag, leash_px)`, then moves by `step = clamp_len(pending, v x dt)` where `v` is the plane's current speed mode (`move_speed`, `focus_speed` while Hold is down, or the kit's ability speed), and `pending -= step`. Consequences: the plane **never moves faster than a pad** (3.5 px/tick), direction is smooth (not 8-way), the plane stops within `ceil(leash / (v x dt))` ticks (4 ticks at 210 px/s) of the thumb stopping, and a fast flick only moves the plane up to `leash_px` beyond its capped speed (the rest is dropped, like lifting and re-placing a mouse). A blocked axis (bounds clamp, PF3) **zeroes that axis of `pending`**, so there is no "sticky wall".
   - *Why this and not an 8-way stick as the default:* the user-facing promise is "my plane moves like my thumb". A relative drag keeps the finger away from the plane (no occlusion), is deterministic per tick (integers), and keeps the speed cap honest. The 8-way stick (Rule 21) stays as the alternative for players who want pad-identical direction.
21. **Movement: STICK scheme (alternative).** A **floating stick**: the anchor is where the MOVE finger lands; the stick vector is `s = clamp_len((p - anchor) / R_px, 1)` with `R_px = stick_radius_mm x ppmm` (F5, 10 mm). If the finger travels farther than `R_px`, the anchor follows (`anchor = p - dir x R_px`), so the finger always sits on the edge of the stick. The sampler writes `stick = s` and `dig = (0,0)`; the Player plane applies **PF2 unchanged** (0.30 / 0.20 deadzone, 8 sectors, 4 deg hysteresis). No drag fields are used. Nothing is drawn for the stick on the canvas (Rule 25).
22. **Not Active = no input.** While the plane is FlyIn, Dying or Absent, the sampler clears `drag`, the jitter accumulator and the stick; the plane clears `pending` (Player plane Rule 10). Fingers stay tracked; motion made before control returns is never applied afterwards.

**Fire, Hold, charge**

23. **Auto-fire** (default on, F6). While the plane is Active, the Hold button is not down, and not on the tick Hold was released, the sampler emits a **1-tick Fire tap every `autofire_period` (10) ticks**: `pressed` + `held` on the pulse tick, `released` the next. Each pulse carries `fire_auto = true`. With the kit's 12-tick tap linger (Plane kits Rule 5) the normal shot is **continuous** (a volley every 5 ticks), and because a pulse is a tap, charge mode never starts from auto-fire. The Player plane **ignores `fire_auto` for focus speed** (amendment to Player plane Rule 4.2), so auto-fire never slows the plane. `autofire_period` must be **at most `shot_linger_ticks`** (12): a data check fails otherwise.
24. **Hold button** (auto-fire on). Holding it sends a **real** Fire hold (`held_ticks` counts up, Input F1) and suppresses pulses. At `held_ticks` 18 (`charge_hold_ticks`) the kit enters charge mode (Lancer laser or Leech focused shot); the plane slows to `focus_speed` (or the laser speed) as for any Fire hold. Releasing Hold resumes auto-fire on the next tick. A short tap on Hold is an ordinary tap shot. **With auto-fire off**, the same button is labelled **Fire** and is the pad's Fire exactly (tap shot, hold charge); Tap Assist (Input Rule 20) works on it.
25. **Fire toggle** (Input Rule 19) applies to the Hold/Fire button only. Auto-fire pulses are not toggled.

**Drone, Bomb, pause**

26. **Drone and Bomb** write `pressed` on the tick after touch-down (not on release), with the Input buffer (`buffer_ticks` 6) and `consume` / `clear_buffer` exactly as for a pad (Input Rules 17-18). A touch Bomb tap and a pad Bomb press produce identical snapshots.
27. **Button state display.** Bomb shows the current stock numeral (0-5) and Drone shows a straight 4 px-equivalent cooldown bar and a READY fill (data from Session and the kit, read-only). These are glances, not requirements: no button needs to be read to be used.
28. **Pause.** The Pause button writes `start` **on release inside the button** and only if the touch lasted under `pause_tap_ticks` (30). Android Back writes `back` (Input Rule 25). Focus loss pauses (Rule 17). While paused the strip is dimmed and every touch is a menu pointer event (Rule 29). Resume follows Input Rule 27 (held buttons re-arm with `pressed = false`).

**Pointers in menus and the canvas**

29. **Routing.** While the session is Playing, every touch belongs to Touch controls and **nothing is forwarded to the canvas**. In every other state (Title, Lobby, Pause, Tally, Settings) touches are mapped with Display's `window_to_canvas` (F7) and forwarded to the canvas as pointer events for Menus; the strip's buttons are hidden or dimmed and inactive. A landscape prompt (Rule 11) blocks both. The project turns off Godot's mouse emulation from touch (`emulate_mouse_from_touch = false`, ADR-0008) so a tap is never delivered twice; in menus a `TouchRouter` synthesizes **one** pointer stream (first finger only) for Menus. The Web page shell must set CSS `touch-action: none` on the canvas and disable overscroll (`overscroll-behavior: none`) so the browser never scrolls, zooms or bounces (ADR-0008).
30. **Menu targets are at least 9 mm.** Any tappable menu item must have a hit area of at least `ceil(9 x ppmm / s)` canvas px on each axis (F7: 55 px at x3 on a 458 dpi phone). Invisible padding counts. Menus (22) uses a touch row pitch to fit this (amendment to Menus' "24 px" assumption).

**Feedback**

31. **Visual feedback** (limits only; Visual/Audio): pressed = plate fill changes and the plate steps 1 px down (never colour alone). A denied press (`drone_denied`, `bomb_denied`) nudges the plate 1 px left and right in two steps.
32. **Haptics** (presentation only, never read by the simulation): `Input.vibrate_handheld(duration_ms, amplitude)` (*unverified in 4.7 on iOS and Web*) on Bomb accepted, Drone accepted, denied press, life lost, Critical Break. At most one pulse per `haptic_gap_ticks` (6); simultaneous events merge to the strongest. `touch.haptics` OFF / LOW (amplitude x0.5) / NORMAL. **No haptic per shot.**

**Onboarding and performance**

33. **First run on touch** shows three short hints once (owned here and shown by Menus; Tutorial 30 does not replace them (2026-11-03, wave 4)): "Drag anywhere to fly", "Hold to charge", "Tap Drone or Bomb". `touch.hints_seen` is saved.
34. **Budget.** Touch sampling and layout are node-free `RefCounted` classes (`TouchMapper`, `TouchLayout`) driven by the Input sampler; layout is recomputed only on `layout_changed`, settings changes or DPI change, never per tick.

### States and Transitions

**Controller (whole system)**

| State | Meaning | Enters from | Leaves to |
|---|---|---|---|
| **Hidden** | Not a touch device, or P1 is a pad/keyboard, or the landscape prompt shows | boot, P1 binds a pad | Idle (touch device and P1 unbound or TOUCH) |
| **Idle** | Menus, Lobby, Tally, Settings: strip visible but inactive; touches are menu pointers | Hidden, Paused | Armed (stage starts, TOUCH bound), Hidden |
| **Armed** | Stage Playing, no finger tracked | Idle, Engaged (all lifted) | Engaged (a finger lands), Suspended (pause, focus loss), Idle (Tally) |
| **Engaged** | At least one tracked finger | Armed | Armed (all lifted), Suspended |
| **Suspended** | Paused or app inactive: all fingers released, accumulators cleared, strip dimmed | Armed, Engaged | Armed on resume (Input Rule 27), Idle |

**Finger roles (per touch)**

| State | Meaning | Next |
|---|---|---|
| Free | No touch | BUTTON, MOVE or IGNORED at touch-down (Rule 12) |
| BUTTON(id) | Owns one button | Free on lift; IGNORED if it drifts past `slop_mm` (button released) |
| MOVE | Owns movement (drag or stick) | Free on lift |
| IGNORED | Tracked only so it can never be promoted | Free on lift |

### Interactions with Other Systems

| System | Direction | Interface (provisional unless the other system has a GDD) |
|---|---|---|
| Input and player mapping (2) — GDD | Out | TOUCH device writes `SlotInput`: `stick`, `fire`, `drone`, `bomb`, `start`, `back`, plus new fields `drag` (Vector2i, 1/16 canvas px, valid when `drag_active`), `drag_active`, `fire_auto` (Amendment). Uses F1 latching, buffers, `consume`, `clear_buffer`, `fire_toggle`, `tap_assist`. |
| Display scaler and bezel (4) — GDD | In / Out | In: `get_layout()` (canvas rect, safe rect, scale `s`, `dw`), `layout_changed`, `window_to_canvas`. Out: `touch_strip_px` (F2) reserved at the bottom of the safe area; Display returns `touch_strip_rect`. Overlay layer W3 hosts the buttons. |
| Player plane (5) — GDD | Out | Reads `drag` and applies the leash (PF8); ignores `fire_auto` for focus speed; clears `pending` on non-Active ticks. |
| Plane kits (11) — GDD | Out | Hold/Fire writes real Fire; auto-fire pulses rely on the 12-tick tap linger; charge at `held_ticks` 18. Kit publishes `drone_state(slot)` = `(state, cooldown_permille)` (READY / ACTIVE / COOLDOWN; Plane kits LL Rule 40, SB Rule 38) for the Drone button (read-only). |
| Bombs (12) — GDD | Out / In | Bomb press and buffer as pad. In: `bomb_denied`, `bomb_used(slot)` (bomb accepted, Bombs Rule 5), stock count for the numeral. |
| Game events and session (1) — GDD | In / Out | Reads session state (Playing / not), slot states, `plane_died`; TOUCH binds slot 0 only; `stage_started` resets toggles. |
| Save, settings and high scores (26) — GDD | Out | `touch.*` setting keys; `board_id` `/touch` suffix. |
| Menus, title and plane select (22) — GDD | In / Out | Touch settings rows; first-run hints; START GAME tap binds TOUCH to slot 0 on touch platforms (Amendment to Menus Rule 9); 9 mm target rule; `touch_solo` toast; landscape prompt. |
| HUD (20) — GDD | Out | No HUD change. Pause is a strip button, so the HUD strip needs no tile (resolves HUD Open Question 13). |
| Accessibility options (28) — GDD | In / Out | Surfaces `touch.one_hand`, `touch.hand`, `touch.button_scale`, `touch.sens`, `touch.haptics` as a Touch section of the Controls screen. |
| Localization (27) — GDD | In | Strings by key, Bengali + English; numerals via `format_int` for the Bomb numeral. |
| Audio (24), VFX (25) — GDD | None | Touch adds no sound or effect (haptics only). Bomb/drone accept sounds come from their own systems. |
| Tutorial (30) — GDD | Out | The three first-run touch hints stay here (Rule 33; Menus shows them). Tutorial's own hints and Flight School use the device's glyphs and add no touch hint (2026-11-03, wave 4). |
| Co-op and Team Chain (18) — GDD | None | TOUCH is never in co-op (Rule 1). |

> Decided under auto-approve (2026-11-03): relative drag as default with an on-screen 1:1 ratio, a 12 px leash and the `move_speed` cap enforced in the plane; floating 8-way stick as the alternative (pad-identical PF2); auto-fire on by default as a 10-tick tap pulse (not a held Fire, so focus speed and charge never trigger by accident); Hold button = real Fire hold for charge, labelled Fire with auto-fire off; three action buttons plus Pause in a strip **below** the canvas reserved by Display (no overlay on the canvas, replacing the 50% corner buttons); sizes in mm (visual 9-12, hit 12-15); one MOVE finger, no promotion, button capture with a 4 mm slop; touch is solo only and ranks on `/touch` boards; haptics per event, none per shot; Pause on release-inside; landscape = pause and prompt; no plane-above-finger offset (relative drag makes it unnecessary).

## Formulas

Assumptions: tick = 1/60 s; canvas 360x640; all per-tick values integer or fixed-point (ADR-0001); the screen scale `s`, `dw` come from Display F3-F4; values read from `data/input/touch_rules.tres`.

### TF1: Pixels per millimetre

`ppmm = clamp(dpi / 25.4, ppmm_min, ppmm_max)`; `ppmm = ppmm_fallback` if `dpi <= 0`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Screen DPI | `dpi` | float | any | `DisplayServer.screen_get_dpi()` (unverified) |
| Bounds | `ppmm_min`, `ppmm_max` | float | 10 / 24 | Guards against bogus DPI |
| Fallback | `ppmm_fallback` | float | 16.0 | Used when DPI is unknown (about 406 dpi) |

**Output Range:** 10-24 px/mm.
**Example:** 458 dpi gives 18.03; 264 dpi (tablet) gives 10.39; 120 dpi gives 4.72 so 10; 700 dpi gives 27.6 so 24; dpi 0 gives 16.0.

### TF2: Strip, button scale and button rectangles

```
W_mm     = safe_w_px / ppmm
s_btn    = clamp((W_mm - 20) / 41, s_min, s_user)
strip_mm = 3 + 12 * s_btn
strip_px = round(strip_mm * ppmm)                  (half away from zero)
c_hold   = 4 + 6 * s_btn          c_drone = 4 + 20.5 * s_btn          c_bomb = 4 + 35 * s_btn      (mm from the left edge, hand RIGHT)
visual   = (12, 11, 12) * s_btn   (Hold, Drone, Bomb);   pause = 9 (fixed), at x = W_mm - 13 .. W_mm - 4
hit rect = visual + hit_pad_mm on every side; vertical centre = strip_bottom - strip_mm / 2
```

Display then lays the canvas out in the safe rect with the bottom `strip_px` removed; the strip rect is `(safe.x, safe.bottom - strip_px, safe.w, strip_px)`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Safe width | `safe_w_px` | int | 300+ | From Display safe rect |
| Width in mm | `W_mm` | float | 40-200 | |
| User scale | `s_user` | float | 1.00 / 1.25 / 1.50 | `touch.button_scale` |
| Minimum scale | `s_min` | float | 0.82 | Keeps Drone at 9.02 mm or more |
| Button scale | `s_btn` | float | 0.82-1.50 | Cluster scale actually used |
| Strip height | `strip_mm`, `strip_px` | float / int | 12.8-21 mm | Reserved bottom strip |
| Hit padding | `hit_pad_mm` | float | 1.5 (0.5-3) | Invisible target growth |

**Output Range:** every visual >= 9 mm, every hit area >= 12 mm, no two hit rects overlap (needs `W_mm >= 20 + 41 x s_btn`; below `W_mm = 53.62` the cluster is at `s_min` and Pause may be dropped, Edge Cases).
**Example (iPhone X, 1125x2436, 458 dpi, safe rect (0,132,1125,2202)):** `ppmm = 18.0315`, `W_mm = 62.39`, `(62.39 - 20) / 41 = 1.034`, `s_btn = 1.00`, `strip_mm = 15`, `strip_px = round(270.47) = 270`. Effective safe rect is (0,132,1125,1932); Display gives x3 INTEGER (height-limited, `1920 * 100 >= 85 * 1932`), canvas 1080x1920 at `(22, 132 + (1932 - 1920) div 2) = (22, 138)`; strip rect `(0, 2064, 1125, 270)`. Hold hit rect: x from `round(2.5 x 18.0315) = 45` to `round(17.5 x 18.0315) = 316`.
**Example (150% scale, same phone):** `s_btn = min(1.50, 1.034) = 1.034`; `strip_mm = 3 + 12.41 = 15.41`; `strip_px = round(277.8) = 278`.
**Example (narrow, 1080x2340, 476 dpi):** `ppmm = 18.740`, `W_mm = 57.63`, `s_btn = (57.63 - 20) / 41 = 0.918`; Hold 11.01 mm, Drone 10.10 mm, Bomb 11.01 mm; `strip_mm = 14.01`; `strip_px = 263`.

### TF3: Drag delta (window pixels to quantised canvas motion)

```
a      = acc + (p_now - p_prev)                       (window px, this tick's raw motion added to the jitter accumulator)
if |a| < drag_min_mm * ppmm:  acc = a;  d = (0,0)
else:                          acc = (0,0);  d = a * (360 / dw) * sens_value
drag   = round_half_away(d * 16)                      (integer 1/16 canvas px, per axis)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Finger motion | `p_now - p_prev` | Vector2 px | any | MOVE finger, window space, since the last tick |
| Canvas ratio | `360 / dw` | float | 0.07-0.9 | `dw` = on-screen canvas width (Display F4) |
| Sensitivity | `sens_value` | float | 0.75 / 1.00 / 1.25 / 1.50 | `touch.sens` 0-3 (default index 1) |
| Jitter threshold | `drag_min_mm` | float | 0.12 (0-0.3) | Below this the motion is held in `acc` |
| Output | `drag` | Vector2i | any | 1/16 canvas px (16 units = 1 px) |

**Output Range:** integers; 0 while idle or below the jitter threshold; large values are limited later by the leash.
**Example (iPhone X, `dw = 1080`, `sens` 1.0, `drag_min_px = 0.12 x 18.0315 = 2.16`):** motion (6, -9) gives `a` length 10.8 >= 2.16, `d = (2.0, -3.0)`, `drag = (32, -48)`. With `sens` 0.75: `(24, -36)`. Motion (1, 0) gives `5.33` rounded to 5 units when it passes the threshold. Three ticks of (1, 0): `acc` 1, 2 (both below 2.16, emit 0), then 3 passes: `d = (1.0, 0)`, `drag = (16, 0)`.

### TF4: Leash step (Player plane PF8)

```
pending' = clamp_len(pending + drag, leash_px * 16)
step     = clamp_len(pending', v * 16 / 60)         (v in px/s: move_speed 210 -> 56 units, focus_speed 105 -> 28, laser 90 -> 24)
pending  = pending' - step
position = position + step / 16, then PF3 clamp; for each axis the clamp changed, pending.axis = 0
clamp_len(w, L): w if |w|^2 <= L^2, else per-axis truncate_toward_zero(w * L / |w|)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Pending motion | `pending` | Vector2i | length <= `leash_px x 16` | Plane-owned, cleared on non-Active ticks |
| Leash | `leash_px` | int px | 8-32 (12) | Max stored motion; 12 px = 192 units |
| Speed mode | `v` | px/s | 90 / 105 / 210 | Player plane PF1 / Rule 4 |
| Step | `step` | Vector2i | length <= `v x 16 / 60` | Units moved this tick |

**Output Range:** `|step|` never exceeds 56 units (3.5 px) at `move_speed`; `|pending| <= 192` after every tick; stop time after the thumb stops is `ceil(192 / (v x 16 / 60))` ticks (4 at 210, 7 at 105, 8 at 90).
**Example:** `pending = (0,0)`, `drag = (32, -48)`: `|v|^2 = 3328 > 56^2 = 3136`, so `step = (trunc(31.06), trunc(-46.60)) = (31, -46)`, `pending = (1, -2)`; the next tick (no motion) steps `(1, -2)`, `pending = (0,0)`. **Saturation:** `drag = (480, 0)`: `pending' = (192, 0)`, steps 56, 56, 56, 24 (3.5, 3.5, 3.5, 1.5 px) = 12 px, then idle. **Catch-up frame (two ticks, 6 px = 96 units):** steps 56 then 40, nothing lost. **Wall:** at the left wall with `pending = (-100, 0)`, the clamp blocks x, so `pending.x = 0`; a +16 drag next tick moves the plane +1 px at once.

### TF5: Floating stick vector (STICK scheme)

```
R_px  = stick_radius_mm * ppmm
d     = p - anchor
if |d| > R_px:  anchor = p - (d / |d|) * R_px;  d = p - anchor
s     = d / R_px              (length <= 1)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Stick radius | `stick_radius_mm` | float | 10 (7-14) | Distance for full deflection |
| Anchor | `anchor` | Vector2 px | window | Where the finger landed, then follows |
| Output | `s` | Vector2 | length 0-1 | Written to `SlotInput.stick`; PF2 applies the deadzone |

**Output Range:** `|s| <= 1`. Movement starts at `|s| >= 0.30` (3.0 mm of travel at 10 mm) and stops below `0.20` (2.0 mm), from PF2.
**Example (ppmm 16.5354, `R_px = 165.35`):** finger 100 px right and 50 px up of the anchor: `s = (0.605, -0.302)`, `|s| = 0.676`, angle -26.6 degrees, PF2 gives up-right. Finger 300 px right: `|d| = 300 > 165.35`, anchor moves 134.65 px right, `s = (1.0, 0)`. Finger back to 120 px right of the old anchor: `d = -14.65` from the new anchor, `s = (-0.089, 0)`, below 0.20, so the plane stops.

### TF6: Auto-fire pulse

```
enabled = autofire AND plane Active AND NOT hold_down AND NOT hold_released_this_tick
a       = enabled ? a + 1 : 0
pulse   = enabled AND (a - 1) mod autofire_period == 0      (fire pressed + held + fire_auto this tick; released next tick)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Pulse counter | `a` | int | 0 up | Ticks the generator has been enabled |
| Period | `autofire_period` | int ticks | 6-12 (10); must be <= `shot_linger_ticks` | 10 gives 6 taps/s |

**Output Range:** `fire.pressed` and `fire_auto` are true on at most 1 tick in `autofire_period`; `held_ticks` is 1 on a pulse tick and 0 otherwise; never 18, so charge never starts from auto-fire.
**Example (period 10):** plane Active at tick 100; Hold pressed at 113 and held through 139 (`released` flag on 140). Pulses at ticks 100, 110; none during 113-140 (`a = 0`); `a = 1` at 141 gives a pulse, then 151, 161. Hold's real `held_ticks` is 18 on tick 130 (kit charge check). The kit sees tap presses at 100 and 110 (linger covers 101-112), so volleys continue every 5 ticks: **120 volleys in 600 ticks**.

### TF7: Minimum menu hit size on touch

`min_target_canvas_px = ceil(target_min_mm * ppmm / s)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Minimum target | `target_min_mm` | float | 9 (locked) | Material 48 dp is about 9 mm |
| Screen scale | `s` | float | 0.78-4 | Display F3 |

**Output Range:** 21-60 canvas px on phones and tablets.
**Example:** iPhone X x3: `9 x 18.0315 / 3 = 54.09`, so **55**. 1080x1920 at 420 dpi, FILL 2.6125: `9 x 16.5354 / 2.6125 = 56.96`, so **57**. Tablet 1640x2360 at 264 dpi, x3: `9 x 10.3937 / 3 = 31.18`, so **32**. A 24 px menu row at x3 on the iPhone X is `24 x 3 / 18.0315 = 3.99 mm`: too small.

### TF8: Touch board id

`board_id = "{stage_count}s/solo/{plane}/touch"` when `played == 1` and slot 0's device class is TOUCH; otherwise Save F3 unchanged.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Stage count | `stage_count` | int | 2 (MVP) | Save F3 |
| Plane | `plane` | string | lancer, leech (later sentry, breaker) | |
| Device class | `device_class` | enum | PAD / KB1 / KB2 / TOUCH | Fixed at run start |

**Output Range:** one extra solo board per plane; no touch co-op board exists.
**Example:** Lancer, 2-stage run on a phone: `"2s/solo/lancer/touch"`; the same run on a pad: `"2s/solo/lancer"`.

> Decided under auto-approve (2026-11-03): `leash_px` 12 (about 4 ticks at 210 px/s; 8 minimum covers a 30 fps catch-up frame of two ticks, 2 x 3.5 = 7); `drag_min_mm` 0.12; 1/16 px fixed point (exact for 3.5, 1.75 and 1.5 px/tick: 56, 28, 24 units); `autofire_period` 10 (2 ticks inside the 12-tick linger); stick radius 10 mm; strip 15 mm; `target_min_mm` 9 from the user's brief.

## Edge Cases

**Fingers**

- **If a touch starts inside a button's hit area**, that finger is the button's and never becomes MOVE, even if it later drags away.
- **If a finger slides from Hold onto Drone**, Drone is not pressed; Hold stays held until the finger lifts or passes `slop_mm` (4 mm) from Hold's hit area, then Hold is released.
- **If two touches land on the same button**, the first owns it; the second is IGNORED.
- **If a hit-test lands exactly on the border between two hit areas**, the lower id wins (order Hold, Drone, Bomb, Pause); with 3 mm gaps and 1.5 mm pads this only happens at exact equality.
- **If a second non-button finger lands while MOVE exists**, it is IGNORED; if MOVE lifts first, that finger is not promoted.
- **If a sixth finger lands**, it is IGNORED.
- **If a touch starts within 2 mm of the left or right edge**, it is IGNORED.
- **If a palm rests on the screen outside the buttons while no MOVE finger exists**, it becomes MOVE and the plane follows its motion only; a resting palm does not move (relative drag, jitter filter), so nothing happens until it slides.
- **If a touch is cancelled by the OS (notification pull-down, system swipe, incoming call)**, all fingers are released, buttons report `released`, the accumulators clear, and a pause is requested if Playing.
- **If the app loses focus with fingers down**, the same as cancel; on resume held buttons re-arm with `pressed = false` (Input Rule 27).
- **If the MOVE finger is outside the window (dragged off the edge)**, motion continues to be read from the reported position; the plane is clamped by PF3 as usual.

**Movement**

- **If the thumb moves faster than 210 px/s on screen**, the plane moves at the cap, `pending` holds at most 12 px and the rest is dropped; the plane stops within 4 ticks of the thumb stopping.
- **If the plane is at a wall and the thumb pushes into it**, the blocked axis of `pending` is zeroed each tick, so reversing moves the plane on the very next tick.
- **If the plane is FlyIn, Dying or Absent**, `drag`, the jitter accumulator and `pending` are cleared every tick; fingers stay tracked.
- **If Hold is down (focus speed) or the Lancer laser is on (90 px/s)**, the same leash applies with the lower cap; a fast thumb simply saturates earlier.
- **If the frame runs two ticks (30 fps phone)**, the first tick consumes the motion, the second continues from `pending`; total motion equals one tick's request (no loss, no extra speed).
- **If the screen layout changes while a finger is down (Web address bar, rotation)**, drag uses window pixels per tick and the new `dw`, so there is no jump; buttons are re-laid and captured fingers keep their capture until lift or slop.
- **If `drag` arrives with the STICK scheme active**, it is not produced; STICK writes only `stick`.
- **If the scheme is changed in Settings during a run**, it applies at the next `stage_started` (never mid-stage); all finger state is cleared.

**Fire and buttons**

- **If Hold is pressed and released within one tick (a 5 ms tap)**, `pressed` is on the next tick and `released` on the one after (Input F1); pulses are suppressed for those two ticks.
- **If Hold is held and the Lancer meter is below 400**, the kit goes to HOLD_PLAIN at `held_ticks` 18 (Plane kits Rule 4); auto-fire stays suppressed while Hold is down.
- **If auto-fire is on and the plane dies**, pulses stop (not Active); the first Active tick after FlyIn starts a pulse (`a = 1`).
- **If the Fire toggle is on in one-hand mode and the plane dies, the game pauses or a stage starts**, the Hold latch resets to off (Input Rule 19).
- **If Bomb is tapped with 0 bombs or during the lockout**, the press is denied: Bombs emits `bomb_denied`, the plate nudges, and a short haptic plays; nothing else changes.
- **If Drone is tapped with no drones or on cooldown**, the kit emits `drone_denied`; same feedback.
- **If Drone and Bomb are pressed on the same tick**, both are buffered independently (Input edge case).
- **If Pause is touched for 30 ticks or more, or released outside its area**, nothing happens (no pause).
- **If Pause is tapped during a Critical Break or boss intro**, the game pauses normally (Input Rule 25).

**Layout and platform**

- **If the DPI query returns 0 or less**, `ppmm = 16.0` and one warning is logged; layout still works.
- **If the safe-area width is under 53.62 mm** (`s_min` reached), buttons stay at 0.82 scale and the Pause button is omitted; pausing then uses focus loss and Android Back, and Menus shows the hint "Press Back to pause" on Android. No phone this narrow is in the device table.
- **If `touch.button_scale` is 150% on a narrow phone**, `s_btn` is capped by the width formula and the setting row shows "Max on this screen".
- **If the strip would push the canvas below the Auto 85% rule**, Display falls to FILL (sharp-bilinear), e.g. 1080x1920 gives FILL 2.6125 and canvas 941x1672 at (69, 0).
- **If a pad or keyboard binds as P1 on a phone (Lobby)**, the strip reserve is removed and buttons hide, applied only outside Playing.
- **If a Start press comes from a pad while TOUCH is bound**, it is ignored and `touch_solo` is raised.
- **If the device is rotated to landscape**, the game pauses and shows "Rotate your phone upright"; returning to portrait keeps the pause (the player resumes).
- **If the platform is Web and the browser exits fullscreen or the address bar toggles**, a new window size recomputes the strip and canvas the same frame; fingers stay tracked.
- **If the OS shows a gesture bar or home indicator**, it lies outside the safe area, so buttons never sit under it (Display Rule 15).
- **If Godot's touch-to-mouse emulation is on**, a tap would be delivered twice; the project setting is off for gameplay (→ ADR) and AC-48 tests it.
- **If the player has no vibration hardware (iPad, some Android tablets)**, haptic calls are no-ops; no error.
- **If the touch settings file holds an unknown enum value or a sens index out of 0-3**, that key falls back to its default; other keys are untouched.

**Degenerate strategies**

- **If a player uses a macro to tap Drone/Bomb**, nothing is gained: cooldown, lockout and stock gate both (Input edge case).
- **If a player uses STICK plus auto-fire off to emulate a pad**, they still rank on touch boards (device class, not behaviour, decides the board).
- **If a player uses DRAG's analog direction to thread a lane no 8-way input can**, that is why touch ranks apart (Rule 2).

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Input and player mapping (2) | Hard | TOUCH device writes `SlotInput` (new `drag`, `drag_active`, `fire_auto`); latching, buffer, toggles | Yes |
| Display scaler and bezel (4) | Hard | `get_layout()`, `layout_changed`, `window_to_canvas`, safe rect, overlay layer W3; reserves `touch_strip_px` | Yes |
| Player plane (5) | Hard | Applies the leash (PF8), speed modes, focus exception for `fire_auto` | Yes |
| Plane kits and drones (11) | Soft | Tap linger, charge at 18 ticks, `drone_state` for the Drone button | Yes |
| Bombs (12) | Soft | Bomb press, `bomb_denied`, stock numeral | Yes |
| Game events and session (1) | Soft | Session state, slot 0 binding, `plane_died`, `stage_started` | Yes |
| Save, settings and high scores (26) | Soft | `touch.*` keys; `/touch` boards | Yes |
| Localization (27) | Soft | Strings and numerals | Yes |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Menus, title and plane select (22) | Soft | 9 mm target rule, settings rows, START GAME binds TOUCH, toasts, landscape prompt, first-run hints | Yes |
| Accessibility options (28) | Soft | Touch settings section on the Controls screen | Yes |
| HUD (20) | Soft | Pause button is outside the HUD (strip) | Yes |
| Tutorial (30) | Soft | First-run hints stay Touch's; drills are solo on touch | Yes |
| Audio (24), VFX (25) | None | Haptics are owned here | Yes |

**Amendments to other docs** (applied 2026-11-03, wave 4; see `production/gdd-reports/_applied-wave-4.md`)

1. `design/gdd/systems-index.md` row 31: status `**Designed** (pending review) — [GDD](touch-controls.md)`; Depends on `2, 4` becomes `2, 4, 5`. Progress tracker: add Touch controls to the GDDs written count; "Open items carried over": remove "touch controls UX spec" (the GDD is the design basis; the `/ux-design` pass is still run for the strip and settings).
2. `design/gdd/input-and-player-mapping.md`:
   - Rule 2 TOUCH line: replace "*Provisional.* Single instance, P1 only." with "GDD: `touch-controls.md`. Single instance, slot 0 only, solo only; other devices' Start is ignored while TOUCH is bound (`touch_solo`)."
   - Rule 13 `SlotInput` table: add rows `drag` (Vector2i, 1/16 canvas px, TOUCH only), `drag_active` (bool), `fire_auto` (bool, true on touch auto-fire pulse ticks).
   - Rule 3 / F7: add "On touch platforms a tap on START GAME binds TOUCH to slot 0."
   - Interactions row 31 and Dependencies row 31: change "Provisional" to the GDD link. Open Question 7: mark **Resolved by Touch controls** (relative drag, buttons below the canvas, TOUCH is one slot); Open Question 10: touch haptics are decided in `touch-controls.md` Rule 32.
   - Project note: gameplay disables touch-to-mouse emulation (→ ADR).
3. `design/gdd/player-plane.md`: add **PF8 Touch leash** (TF4) and Rule 2 note "touch DRAG is analog direction, capped by the same speed as 8-way"; Rule 4.2: "Fire held (a real hold; a touch auto-fire pulse flagged `fire_auto` does not count)"; Rule 9: reads `drag` / `drag_active`; Rule 10: clears `pending`; Open Question 6: mark **Resolved by Touch controls**; add ACs for PF8 (see AC-21 to AC-27).
4. `design/gdd/display-scaler-and-bezel.md`:
   - Rule 4 / F1: when Touch controls are active, the effective area is the safe rect minus the bottom `touch_strip_px` (supplied by Touch F2); `get_layout()` also returns `touch_strip_rect`. Rule 19 and "Visual/Audio" W3 text: replace "nothing in W3 may cover the canvas except Touch controls' lower-corner buttons on 16:9 phones (50% opacity, Touch controls decision)" with "nothing in W3 covers the canvas; touch buttons live in the strip below it".
   - Open Question 8: mark **Resolved** (strip reserve, touches not forwarded to the canvas while Playing, forwarded in menus). Add AC rows for the strip layouts in AC-02 to AC-05 of the Touch GDD.
5. `design/gdd/save-settings-high-scores.md`: F3 `board_id`: add the `/touch` suffix (Touch TF8) and one extra solo board per plane; register `touch.scheme`, `touch.autofire`, `touch.hand`, `touch.one_hand`, `touch.sens`, `touch.button_scale`, `touch.haptics`, `touch.hints_seen` in the settings schema (owner Touch controls (31)).
6. `design/gdd/menus-title-plane-select.md`: Rule 9: on touch platforms a tap on START GAME binds TOUCH to slot 0 and opens the Lobby with slot 0 Choosing (the "pointer cannot be a flying device" rule keeps applying on PC and Web desktop); replace "24 px targets minimum" (Interactions row, line ~230 and ~444, Open Question 11) with the Touch TF7 rule (9 mm; 55 canvas px at x3 on a 458 dpi phone) and a touch row pitch; add the `touch_solo` toast, the landscape prompt, the Touch section in Controls, and the first-run hints.
7. `design/gdd/hud.md`: Dependencies row Touch: "Pause button is in the touch strip; no HUD tile"; Open Question 13: mark **Resolved**.
8. `design/gdd/accessibility-options.md`: Interactions row Touch (31): "Touch section: `touch.one_hand`, `touch.hand`, `touch.button_scale`, `touch.sens`, `touch.haptics`; layout drag-and-place editing is out of scope (Touch Open Question 5)". Add a layout preset line `Touch: one hand` = `touch.one_hand` on.
9. `design/gdd/plane-kits-lancer-leech.md` Rule 5: add "Touch auto-fire pulses every `autofire_period` (<= `shot_linger_ticks`) rely on this linger (Touch controls Rule 23); changing `shot_linger_ticks` below 12 requires revisiting the period." Interactions: kit publishes `drone_state` for the touch button (provisional).
10. `design/gdd/game-concept.md` section 13 risk "Precise dodging on touch devices": mitigation becomes "Relative touch-drag capped at `move_speed`, visible hitbox, separate touch boards (touch-controls.md)".
11. `design/art/art-bible.md`: section 7.6 add touch button glyphs (Hold, Fire, Drone, Bomb, Pause) and 3.5 note "touch plates follow the same chamfered rectilinear grammar"; section 8.1.1: add "touch devices reserve a bottom strip (touch-controls.md F2); device-table results for touch use the reduced height".
12. `docs/architecture/adr-0001-gdscript-bullets-multimesh.md` tick step 1: add "Touch events latched in `_input`; `TouchMapper` runs inside the sampler tick". `docs/project-structure.md`: add `src/input/touch/` (`TouchMapper`, `TouchLayout`, presenter) and `data/input/touch_rules.tres`.
13. `design/gdd/localization.md`: add the `touch.*` and `opt.touch_*` string keys from UI Requirements (Bengali drafts for native review).
14. Later GDDs (Tutorial 30, Audio 24) must list Touch controls when written.

## Tuning Knobs

All in `data/input/touch_rules.tres` unless marked (S) = player setting stored by Save. Categories: F = feel, G = gate, L = layout.

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `leash_px` (F) | 12 | 8-32 | Fast thumbs feel throttled; under 8 a 30 fps catch-up frame loses motion | Plane keeps moving after the thumb stops (rubber band) | TF4, `move_speed` |
| `sens_value` (S, `touch.sens`) | 1.00 (index 1) | 0.75 / 1.00 / 1.25 / 1.50 | Needs many re-grips to cross the field | Twitchy, saturates the speed cap | TF3, leash |
| `drag_min_mm` (F) | 0.12 | 0-0.30 | Resting thumb jitters the plane | Slow, precise drags are eaten | TF3 |
| `autofire_period` (F) | 10 ticks | 6-12 (must be <= `shot_linger_ticks`) | Wasted presses; the kit's own cap hides it | Gaps in fire if above the linger | Plane kits Rule 5 |
| `autofire` (S, `touch.autofire`) | on | on / off | - | - | Hold/Fire button label |
| `scheme` (S, `touch.scheme`) | DRAG | DRAG / STICK | - | - | TF3-TF5 |
| `stick_radius_mm` (F) | 10 | 7-14 | Too sensitive; thumb crowds | Needs a long thumb reach | PF2 deadzone |
| `button_mm` (L) | Hold 12, Drone 11, Bomb 12, Pause 9 | each >= 9 | Mis-taps | Strip too tall, canvas shrinks | TF2 |
| `hit_pad_mm` (L) | 1.5 | 0.5-3.0 | Hits miss the plate | Neighbouring hit areas touch | Gaps (3 mm) |
| `strip_mm` base (L) | 15 (3 + 12 x `s_btn`) | 13-17 | Buttons under 9 mm | Canvas drops from x3 to FILL on tall phones | Display F3 |
| `s_min` (L) | 0.82 | 0.82-1.00 | Drone under 9 mm | Narrow phones lose Pause | TF2 |
| `button_scale` (S) | 100% | 100 / 125 / 150% | - | Capped by screen width | Accessibility (28) |
| `slop_mm` (F) | 4 | 2-8 | Button releases during a bumpy hold | Finger drifts to a neighbour yet stays held | Rule 13 |
| `edge_reject_mm` (F) | 2 | 0-5 | Grip palms trigger MOVE | Edge drags ignored | Button margin 2.5 mm |
| `max_pointers` (F) | 5 | 3-8 | Fewer simultaneous buttons | - | Rule 16 |
| `pause_tap_ticks` (F) | 30 | 15-60 | Slow taps fail | Resting thumb pauses on release | Rule 28 |
| `hand` (S) | RIGHT | RIGHT / LEFT | - | - | TF2 mirror |
| `one_hand` (S) | off | on / off | - | - | Fire toggle |
| `haptics` (S) | NORMAL | OFF / LOW / NORMAL | - | - | Rule 32 |
| `haptic_gap_ticks` (F) | 6 | 3-12 | Buzzing | Misses fast bomb-then-death | Rule 32 |
| Haptic table (F) | bomb 25 ms / 0.8; drone 12 ms / 0.5; denied 8 ms / 0.3; life lost 60 ms / 1.0; Critical Break 40 ms / 0.8 | 5-100 ms, 0.1-1.0 | Not felt | Annoying, battery | Audio/VFX events |
| `target_min_mm` (L) | 9 | locked | - | - | TF7 |
| `ppmm_min` / `ppmm_max` / `ppmm_fallback` (F) | 10 / 24 / 16.0 | - | - | - | TF1 |
| Sampler budget | 0.02 ms p99 on REF-PHONE | - | - | Cuts into 16.6 ms frame | Technical preferences |

Rationale: 15 mm strip is the smallest strip that fits a 12 mm button plus 1.5 mm hit padding on both sides (3 + 12), and it keeps an iPhone X-class phone at x3 INTEGER (TF2 example); `leash_px` 12 follows TF4 (4 ticks at full speed); 9 mm follows Material's 48 dp target and the brief.

**Owned elsewhere:** `move_speed`, `focus_speed`, deadzone numbers, speed modes - Player plane (5) and Input (2); `charge_hold_ticks`, `shot_linger_ticks`, drone cooldowns - Plane kits (11); bomb stock and lockout - Bombs (12); `buffer_ticks` - Input (2); canvas, scale mode, safe rect - Display (4); menu layout - Menus (22); HUD layout - HUD (20); board size and persistence - Save (26).

> Decided under auto-approve (2026-11-03): all defaults above; these are untested on hardware and all feel values (leash, sensitivity, jitter, slop) are playtest items.

## Visual/Audio Requirements

> Art bible rules apply: nothing over enemy bullets (layer 8); no Void Indigo / Ink for non-bullets; no orb, rice, needle or ring shapes; Alarm Red is reserved; UI is plated, chamfered, rectilinear (§3.5, §7.10).

**Where it draws.** Touch buttons are on the window-level overlay **W3** (Display Visual/Audio table) **inside the strip rect only**. **No touch element is drawn over the canvas rect**, in any state or scheme. The STICK scheme draws **no base or knob** (the thumb is the marker). The DRAG scheme draws no marker. A pixel test (AC-45) compares the canvas rect with the overlay on and off.

**Button plates** (look is the art-director's; limits only)
- Plated chamfered square (chamfer 2 canvas px at the strip scale), Cabinet Char `#1E1B18` fill, `#5A5148` edge, 1 px `#14110E` outline, Cream `#F4EBD6` glyph. Era tint at 20% on the edge only (Display Rule 11.3 palette limits). Bomb glyph is the HUD bomb tile (§7.6) so players recognise it.
- Authored at 1x and drawn at an **integer** scale `k = max(1, floor(s))` so pixels stay square; plate size comes from the mm rect (nine-slice, never stretched); glyph 24x24 px drawn at `k_g = max(1, round(0.5 x visual_px / 24))` (a 12 mm button at 18.03 ppmm: `round(0.5 x 216 / 24) = round(4.5) = 5`, 120 px, about 6.7 mm).
- Idle opacity 80%, pressed 100%. **Pressed state:** fill changes to Cream with a Char glyph **and** the plate steps 1 px down (value and position, not colour alone). **Denied:** two 1 px side nudges over 4 frames (stepped, no tween). **Disabled/ready:** Bomb at 0 stock is dimmed to 50% with the numeral "0"; Drone on cooldown shows a 4 px straight bar (Ember Gold on `#3A2A14`) filling left to right; READY fills the plate edge with Gold. No Alarm Red anywhere on the strip.
- Glyphs: Hold (stacked chevrons), Fire (single chevron, shown instead of Hold when auto-fire is off), Drone (drone pictogram in a square), Bomb (HUD bomb tile), Pause (two bars). All have distinct grayscale silhouettes and none is a circle or ring.
- Numeral on Bomb: tier L (16 px) Cream with the 1 px outline, from `Localization.format_int` (Bengali digits in Bengali). Text on buttons is absent otherwise (language-neutral glyphs); the first-run hints name them.
- Pulse and motion obey §7.7: nothing flashes; the only motion is the 1-frame plate step and the denied nudge.
- Dimmed strip while paused: 40% opacity on all plates.

**Hints.** First-run hints are Cream text on a Char plate in the **bezel area above the strip** (never over the canvas), Latin >= 12 px and Bengali >= 17 px at equal weight, 4 px headroom, one at a time, 3 s each.

**Haptics** (presentation, owner here; audio-director/ux to tune on hardware)

| Event | Duration / amplitude | Notes |
|---|---|---|
| Bomb accepted | 25 ms / 0.8 | "It went off" |
| Drone accepted | 12 ms / 0.5 | |
| Denied press (bomb or drone) | 8 ms / 0.3 | Tells the thumb it did not fire |
| Life lost (`plane_died`) | 60 ms / 1.0 | |
| Critical Break | 40 ms / 0.8 | |

One pulse per `haptic_gap_ticks` (6), strongest merged; LOW scales amplitude by 0.5; OFF none; no haptic per shot or per pickup. Haptics never depend on and never change simulation state.

**Audio:** none from Touch controls. No sound on button press (Input: no in-flight press sounds); bomb/drone sounds come from their systems.

## UI Requirements

Player-facing elements (owners in brackets):

| Element | Owner | Notes |
|---|---|---|
| **Button strip**: Hold/Fire, Drone, Bomb, Pause plates, Bomb numeral, Drone cooldown bar | Touch controls (this GDD), art by art-director | Below the canvas; sizes in F2 |
| **Touch section of the Controls screen**: Move control (Drag / Stick), Auto-fire, Thumb side (Right / Left), One-hand mode, Drag speed (4 steps), Button size (100 / 125 / 150%), Vibration (Off / Low / Normal) | Menus (22) shell, rows from this GDD, surfaced by Accessibility (28) | Shown only on touch platforms; every row operable by touch with 9 mm targets |
| **First-run hints** (3) | Touch / Tutorial (30) | Once; `touch.hints_seen` |
| **Landscape prompt** "Rotate your phone upright" | Menus (22) | Pauses the game |
| **`touch_solo` toast** "Touch play is solo only" | Menus (22) | When another device presses Start |
| **Touch leaderboard tab** (boards with `/touch`) | Menus (22) / Save (26) | Filter on the High Scores screen |
| Debug tools (debug builds) | Touch controls | Overlay of finger roles, hit rects, strip rect, `ppmm`, `s_btn`, `pending`, `drag`; a desktop mouse-as-touch mode to test layouts; forced DPI and safe-rect commands to test the device table |

**Bilingual strings** (string keys use `ui.touch.*`; `touch.*` is reserved for Save setting keys, renamed 2026-11-03; Bengali drafts for native-speaker review by Localization 27; +40% width reserved for Bengali):

| Key | English | Bengali (draft) |
|---|---|---|
| ui.touch.hint.drag | Drag anywhere to fly | উড়তে যেকোনো জায়গায় টেনে নিন |
| ui.touch.hint.hold | Hold to charge | চার্জ করতে চেপে ধরুন |
| ui.touch.hint.buttons | Tap Drone or Bomb | ড্রোন বা বোমা চাপুন |
| ui.touch.landscape | Rotate your phone upright | ফোনটি সোজা করে ধরুন |
| ui.touch.solo | Touch play is solo only | টাচ খেলা শুধু একজনের জন্য |
| action.hold | Hold | ধরে রাখুন |
| opt.touch_scheme | Move control | চলাচল নিয়ন্ত্রণ |
| opt.touch_scheme.drag / .stick | Drag / Stick | টানুন / স্টিক |
| opt.touch_autofire | Auto-fire | স্বয়ংক্রিয় গুলি |
| opt.touch_hand | Thumb side | বুড়ো আঙুলের দিক |
| opt.touch_hand.right / .left | Right / Left | ডান / বাম |
| opt.touch_one_hand | One-hand mode | এক হাতে খেলা |
| opt.touch_sens | Drag speed | টানার গতি |
| opt.touch_button_scale | Button size | বোতামের আকার |
| opt.touch_haptics | Vibration | কম্পন |
| opt.touch_haptics.off / .low / .normal | Off / Low / Normal | বন্ধ / কম / স্বাভাবিক |
| ui.touch.max_here | Max on this screen | এই স্ক্রিনে সর্বোচ্চ |
| ui.touch.back_hint | Press Back to pause | থামাতে পিছনে চাপুন |

📌 **UX Flag**: run /ux-design for the touch button strip (plates, states, one-hand and mirror layouts) and the Touch section of the Controls screen before writing epics. This GDD is the design basis for that spec.

## Acceptance Criteria

**Defaults used:** `leash_px` 12, `sens` 1.00, `drag_min_mm` 0.12, `autofire_period` 10, `autofire` on, `scheme` DRAG, `stick_radius_mm` 10, buttons Hold 12 / Drone 11 / Bomb 12 / Pause 9 mm, `hit_pad_mm` 1.5, `s_min` 0.82, `s_user` 1.00, `slop_mm` 4, `edge_reject_mm` 2, `max_pointers` 5, `pause_tap_ticks` 30, `haptic_gap_ticks` 6, `move_speed` 210, `focus_speed` 105, `charge_hold_ticks` 18, `shot_linger_ticks` 12, `buffer_ticks` 6, tick 1/60 s, 2-stage MVP boards.

**Test setup:** `TouchMapper` (fingers, roles, drag, stick, auto-fire) and `TouchLayout` (TF1-TF2, TF7) are node-free `RefCounted` classes with no `Input` or `DisplayServer` access. Tests inject raw touch events `touch_down(index, pos)`, `touch_move`, `touch_up`, `touch_cancel` between explicit `tick()` calls (no real time, no `delta`), a stub `DisplayLayout` (dw, safe rect, strip), a stub DPI, a stub Session and kit, and a seeded RNG for random event scripts; numbers are read from `data/input/touch_rules.tres` (not literals). The leash is tested on the node-free Player plane core. Tests live in `tests/unit/test_touch_layout.gd`, `test_touch_fingers.gd`, `test_touch_drag.gd`, `test_touch_stick.gd`, `test_touch_autofire.gd`, `test_touch_leash.gd`, `test_touch_boards.gd` in `extends SceneTree` style like `tests/unit/test_chain_tracker.gd`. Integration: `tests/integration/test_touch_routing.gd`. Manual evidence: `production/qa/evidence/touch/`.

Tags: [Unit] headless pure logic · [Integration] scenes/tree · [Perf] budget · [Manual] needs a human/hardware.

### Layout and device table

- **AC-01 [Unit] (TF1):** `ppmm(458) = 18.03 ±0.01`; `ppmm(264) = 10.39 ±0.01`; `ppmm(120) = 10`; `ppmm(700) = 24`; `ppmm(0) = 16.0` and one warning logged.
- **AC-02 [Unit] (TF2, Display F3-F4):** 1125x2436, 458 dpi, safe rect (0,132,1125,2202): `s_btn = 1.00`, `strip_px = 270`, canvas x3 INTEGER 1080x1920 at (22, 138), strip rect (0, 2064, 1125, 270), Hold hit rect x 45 to 316 (±1 px).
- **AC-03 [Unit] (TF2):** 1080x1920, 420 dpi, no safe inset: `strip_px = 248`, Display Auto gives FILL 2.6125, canvas 941x1672 at (69, 0), strip rect (0, 1672, 1080, 248).
- **AC-04 [Unit] (TF2):** 1080x2400, 400 dpi, safe rect (0,80,1080,2272): `strip_px = 236`, x3 INTEGER, canvas at (0, 138), strip rect (0, 2116, 1080, 236).
- **AC-05 [Unit] (TF2):** 1080x2340, 476 dpi, no inset: `s_btn = 0.918 ±0.001`, Drone visual 10.10 mm ±0.02, `strip_px = 263`.
- **AC-06 [Unit] (TF2):** with `s_user` 1.50 on the AC-02 phone: `s_btn = 1.034 ±0.001`, `strip_px = 278`.
- **AC-07 [Unit] (Rule 7, TF2):** for the 6 devices above plus a 1640x2360 264 dpi tablet (`strip_px = 156`), every visual is >= 9 mm, every hit area >= 12 mm, Pause visual = 9 mm.
- **AC-08 [Unit] (TF2):** hit rects of Hold, Drone, Bomb, Pause never overlap, for `s_btn` in {0.82, 0.9, 1.0, 1.034}.
- **AC-09 [Unit] (Rule 9):** `hand = LEFT` mirrors every rect about the screen centre (x' = W - x within 1 px); order from the edge is Hold, Drone, Bomb.
- **AC-10 [Unit] (Rule 6):** for 20 sizes (including tablets and odd widths), the canvas rect and `touch_strip_rect` do not intersect and both lie inside the safe rect.
- **AC-11 [Integration] (Rule 6, Display):** with TOUCH active, the layout hash is identical in Title, Lobby, Stage, Pause and Tally; binding a pad as P1 in the Lobby removes the reserve only after the session leaves Playing (never mid-stage).

### Fingers and routing

- **AC-12 [Unit] (Rule 18, F1):** a 5 ms tap on Bomb gives `pressed` + `held` on tick T, `released` on T+1, `held_ticks` 1 then 0; the snapshot equals a pad Bomb tap's snapshot.
- **AC-13 [Unit] (Rule 13):** a finger down on Hold slides onto Drone: Drone never `pressed`; Hold stays held until lift or until 4 mm beyond its hit area, then `released`.
- **AC-14 [Unit] (Rules 12, 14):** first non-button touch is MOVE; a second non-button touch is IGNORED; when MOVE lifts, the second is not promoted (no `drag` from it); a new touch becomes MOVE.
- **AC-15 [Unit] (Rules 12, 16):** MOVE + Hold + Drone + Bomb + Pause down on one tick: all five roles tracked; a sixth touch is IGNORED.
- **AC-16 [Unit] (Rule 15):** a touch at 1.9 mm from the left edge is IGNORED; at 2.6 mm it becomes MOVE (not inside any button).
- **AC-17 [Unit] (Rule 17):** `touch_cancel` with Hold, Bomb and MOVE down: all buttons report `released` the same tick, `drag` and the accumulator clear, and a pause request is raised when Playing.
- **AC-18 [Unit] (Rule 28):** Pause touched for 10 ticks and released inside gives one `start` pressed on the release tick; released outside gives none; held 30 ticks or more gives none.
- **AC-19 [Integration] (Rule 29):** while Playing, a touch inside the canvas rect is not delivered to the SubViewport; while Paused, the same touch activates a menu item mapped through `window_to_canvas`; no tap is delivered twice (emulation off).
- **AC-20 [Integration] (Rule 17):** app focus-out with Hold and MOVE down releases everything and pauses; after resume held buttons report `pressed = false` (Input AC-30 behaviour).

### Drag and leash

- **AC-21 [Unit] (TF3):** at `dw = 1080`, `sens` 1.0, motion (6, -9) gives `drag = (32, -48)`; `sens` 0.75 gives `(24, -36)`; motion (1, 0) gives 5 units when it passes the threshold.
- **AC-22 [Unit] (TF3):** with `drag_min_px = 2.16`, three ticks of motion (1, 0) give `drag` (0,0), (0,0), then (16, 0); a resting finger with sub-threshold noise never emits `drag`.
- **AC-23 [Unit] (TF4):** `pending = (0,0)`, `drag = (32, -48)`, `move_speed`: step `(31, -46)`, `pending (1, -2)`; next tick step `(1, -2)`, `pending (0, 0)`.
- **AC-24 [Unit] (TF4):** `drag = (480, 0)` once: steps 56, 56, 56, 24 units (3.5, 3.5, 3.5, 1.5 px), total 12 px, then 0; `|pending| <= 192` on every tick.
- **AC-25 [Unit] (TF4, PF3):** at the left wall with `pending = (-100, 0)`: `pending.x` is 0 after the clamp tick; a following `drag = (16, 0)` moves the plane +1 px on that same tick.
- **AC-26 [Unit] (TF4, PF1):** with Hold down the step cap is 28 units; with the Lancer laser on it is 24; stop time after a saturated flick is 7 and 8 ticks respectively (4 at `move_speed`).
- **AC-27 [Unit] (TF4):** 10,000 ticks of seeded random `drag` (including 480-unit spikes): `|step| <= 56` units on every tick at `move_speed`, `|pending| <= 192`, no NaN.
- **AC-28 [Unit] (Rule 22):** non-Active ticks clear `drag`, the accumulator and `pending`; 60 ticks of finger motion during FlyIn produce zero displacement on the first Active tick.
- **AC-29 [Unit] (Edge, catch-up):** one frame with two ticks and 96 units of motion: steps 56 then 40, `pending (0,0)`.
- **AC-30 [Unit] (Rule 19):** `scheme = DRAG` produces `drag_active = true` and `stick = (0,0)`; `scheme = STICK` produces `drag_active = false`.

### Stick

- **AC-31 [Unit] (TF5):** ppmm 16.5354: finger (100, -50) px from anchor gives `stick = (0.605, -0.302) ±0.001`; the plane (PF2) moves up-right.
- **AC-32 [Unit] (TF5):** finger 300 px right of the anchor gives `stick = (1, 0)` and the anchor moves 134.65 px; finger back to 120 px right of the old anchor gives `stick (-0.089, 0)` and the plane stops.
- **AC-33 [Unit] (Rule 21):** STICK writes `dig = (0,0)` and the raw `stick` with no deadzone applied by the sampler (PF2 owns it); radius 10 mm gives movement start at 3.0 mm of travel.

### Fire, Hold, buttons

- **AC-34 [Unit] (TF6):** Active at tick 100, Hold down 113-139 (released flag 140): `fire.pressed` with `fire_auto` on ticks 100, 110, 141, 151, 161 only; `held_ticks` is 0 or 1; Hold's `held_ticks` is 18 on tick 130.
- **AC-35 [Integration] (Rule 23, kit):** Lancer test kit, 600 ticks of auto-fire with no Hold: 120 volleys (±1), never a gap longer than 5 ticks, laser never starts, meter unchanged by Fire.
- **AC-36 [Unit] (Rule 23, Player plane):** on a pulse tick the plane's speed is `move_speed` (`fire_auto` does not trigger focus); with Hold down it is `focus_speed`.
- **AC-37 [Unit] (Rule 23):** a `touch_rules.tres` with `autofire_period` 13 fails the data check against `shot_linger_ticks` 12; 12 passes.
- **AC-38 [Unit] (Rule 24):** `autofire = false`: no synthetic presses; the Fire button gives tap and hold exactly like a pad; Tap Assist on gives presses at h = 1, 7, 13.
- **AC-39 [Unit] (Rule 24-25):** one-hand mode: first Hold tap latches Fire on, second releases; death, pause and stage start reset the latch; auto-fire pulses are not affected.
- **AC-40 [Unit] (Rule 26):** scripted touch and pad event sequences for Drone and Bomb (including buffered presses at 5 and 7 ticks before readiness) produce identical snapshots for 600 ticks.

### Solo, boards, menus

- **AC-41 [Unit] (Rule 1):** with TOUCH bound to slot 0, a pad Start is ignored, `touch_solo` is raised once, and no slot changes; TOUCH never binds to slots 1-3.
- **AC-42 [Unit] (TF8, Rule 2):** Lancer 2-stage touch run gives `"2s/solo/lancer/touch"`; the same run on a pad gives `"2s/solo/lancer"`; no co-op board has a `/touch` suffix.
- **AC-43 [Integration] (Rule 3, Menus):** on a touch platform, tapping START GAME binds TOUCH to slot 0 and opens the Lobby with slot 0 Choosing.
- **AC-44 [Unit] (TF7):** `min_target_canvas_px` is 55 (458 dpi, x3), 57 (420 dpi, FILL 2.6125) and 32 (264 dpi, x3); a lint over the touch menu definition fails any item with a smaller hit area.

### Visual, haptic, feedback

- **AC-45 [Integration] (Visual rule):** a screenshot of the canvas rect with the touch overlay on equals the screenshot with it off (pixel diff 0), in DRAG and STICK schemes, while fingers are down.
- **AC-46 [Unit] (Rule 32):** with `haptic_gap_ticks` 6, Bomb accepted and a denied press on the same tick give one pulse (25 ms / 0.8); two events 4 ticks apart give one; 7 ticks apart give two; LOW halves the amplitude; OFF gives none.
- **AC-47 [Integration] (Rule 32):** the `GameState` hash per tick over a recorded run is identical with haptics OFF and NORMAL.
- **AC-48 [Integration] (Rule 29):** with the emulation project setting in the shipped configuration, one physical tap on a menu item produces exactly one activation.

### Determinism and performance

- **AC-49 [Unit] (Rule 18):** a 600-tick seeded random touch script (all finger roles, scheme DRAG and STICK) gives an identical hash of all snapshots across two runs.
- **AC-50 [Perf] (Rule 34):** `TouchMapper.tick()` with 5 fingers, 10,000 ticks: p99 <= 0.02 ms on REF-PHONE and <= 0.05 ms on REF-PC; event handler p99 <= 0.01 ms; zero allocations per tick after warm-up.
- **AC-51 [Perf] (Visual):** the strip draws in <= 12 draw calls from one atlas of <= 128x128 px; the present pass budget (Display AC-47) is unchanged.

### Manual

- **AC-52 [Manual] (Anti-fantasy, occlusion):** 10 testers, 5 minutes each on iOS and Android, screen recorded, 1 sample per second: the plane hitbox is covered by a thumb in <= 5% of samples; record how many testers rested the thumb below the plane.
- **AC-53 [Manual] (Reach):** testers of small, medium and large hands (3 each) can reach Hold, Drone and Bomb with the left thumb while holding a 6.1-inch phone with both hands, and Pause is never touched by accident in a 5-minute stage; record misses.
- **AC-54 [Manual] (Size):** measure Hold, Drone, Bomb, Pause and a Title menu row on hardware with a ruler: visuals >= 9 mm, hit areas >= 12 mm (menu row >= 9 mm).
- **AC-55 [Manual] (Feel):** 5 testers play stage 1 on touch: zero reports of "the plane jumped" or "the Bomb did not register"; a frame-stepped capture of 20 sub-10 ms taps on Bomb shows 20 of 20 registered (no lost taps).
- **AC-56 [Manual] (Accessibility):** one-hand mode (right and left) clears stage 1 on the Lancer with no second hand; Bengali and English strings of every touch row fit their plates with >= 4 px headroom and 40% extra width; reviewed by a native Bengali reader.
- **AC-57 [Manual] (Platform):** on one iOS and one Android phone (and Chrome on Android, *unverified*): vibration plays, landscape pause prompt appears, a notification pull-down mid-stage releases all buttons and pauses, the home indicator/gesture bar never overlaps a button. Document results.
- **AC-58 [Manual] (Fairness):** compare 10 stage-1 runs per input class (pad, touch DRAG, touch STICK): the touch plane never exceeds 3.5 px/tick in a position log (checked by script).

> Criteria drafted under auto-approve; `qa-lead` not consulted (solo drafting). Numbers in AC-02 to AC-06, AC-21 to AC-24, AC-31, AC-34 and AC-44 follow TF1-TF7 exactly.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Unverified Godot 4.7 APIs:** `DisplayServer.screen_get_dpi()` reliability on iOS/Android/Web, `DisplayServer.is_touchscreen_available()`, `get_display_safe_area()`, `Input.vibrate_handheld(duration_ms, amplitude)` (amplitude argument, iOS and Web behaviour), `InputEventScreenTouch.canceled`, the touch-to-mouse emulation setting name, multi-touch index limits, `NOTIFICATION_WM_GO_BACK_REQUEST`. Check `docs.godotengine.org/en/4.7/` and a device export. | godot-specialist | Before epics |
| 2 | Playtest the feel values: `leash_px` 12, `sens`, `drag_min_mm`, strip 15 mm, 12 mm buttons. Is a plane-above-finger FOLLOW scheme needed after all (absolute position with the same speed cap)? | ux-designer + game-designer | First phone playtest |
| 3 | Should STICK + auto-fire off (a pad-equivalent input) share the pad boards? Currently all touch runs use `/touch` boards. | producer | Before boards ship |
| 4 | Landscape layout for Web on phones and for tablets (currently: pause and prompt). | ux-designer | Web mobile decision |
| 5 | Drag-and-place custom button layouts (Accessibility 28 interactions mention "layout editing"). Out of scope here; presets only (hand, one-hand, scale). | Accessibility (28) | Post-Target |
| 6 | Pause button placement risk (thumb rests near it) and the missing Pause on screens narrower than 53.62 mm. Is hold-to-pause (20 ticks) better? | ux-designer | Playtest |
| 7 | Tablet strip proportions: 15 mm on a 10-inch tablet is small relative to the screen; allow a larger default `s_user`? | ux-designer | Tablet decision |
| 8 | Auto-detect handedness at first run (ask "Which thumb drags?") instead of default RIGHT. | ux-designer + Menus (22) | UX spec |
| 9 | Input recording and replay: `drag` is integer and deterministic, so replays are possible; wanted? (Input Open Question 8.) | Producer | Full Vision |
| 10 | Phones may render at 30 fps while ticks stay at 60 Hz (Bullet manager decision): confirm the two-ticks-per-frame catch-up is how the loop behaves (the leash covers it) and measure real input latency on REF-PHONE. | lead-programmer | Before epics |
| 11 | Bengali strings need native review. | Localization (27) | Vertical Slice |
| 12 | Hardware controllers on phones (Bluetooth pads): P1 on a pad hides touch controls and uses pad boards. Confirm the Lobby flow when both exist. | Menus (22) + Input (2) | Menus UX spec |
