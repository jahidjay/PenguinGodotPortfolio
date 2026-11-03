# Display Scaler and Bezel

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (technical-artist) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (same view, same fairness on every screen), Every Hit Counts (the 6 px hitbox stays crisp and the same size relative to the field everywhere)
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: the UI table's "Reset display" row now says *same result as* `display_reset` with a `confirm_hold` hold length, instead of equating the menu item with the 2 s real-time hotkey.

## Overview

**The data layer:** the game is always drawn on a **fixed 360x640 canvas** (art bible §8.1.1). The Display scaler owns everything between that canvas and the physical screen. A node-free layout class (`DisplayLayout`) takes the window size, the OS safe area, the chosen scaling mode and the TATE setting, and returns one **layout**: the display scale, the canvas rectangle on screen, and up to four **bezel rectangles** (the screen area outside the canvas). It also converts screen points to canvas points (for mouse and touch). A thin presenter node renders the game into a 360x640 SubViewport, shows that image at the layout scale (whole-number scales stay perfectly sharp; fractional scales use a **sharp-bilinear** shader), draws era-themed **bezel** art around it, and handles window mode, resize, Web canvas size and safe areas. Nothing here changes gameplay: gameplay never learns the screen size.

**The player impact:** every player on every device sees the same amount of world, so patterns, lanes and scores are comparable between a phone, a TV and a Steam Deck (**Readable Chaos**). Pixels stay square and crisp (whole-number scale where possible), the hitbox dot is never smeared, and any spare screen area looks like the cabinet frame instead of black bars. A player on a rotated monitor (TATE) gets the classic arcade vertical setup.

## Player Fantasy

**Anchor moment: the cabinet in your room.** The player starts the game on whatever they own, a phone, a laptop, a 4K TV, a monitor turned on its side, and it looks like a vertical arcade cabinet: a sharp pixel screen in a dark frame that quietly matches the era they are flying through. The frame never competes with the bullets, never tells them anything they need, and never lets one player see more of the sky than another.

- **Same game everywhere.** Nobody can play on a taller or wider field.
- **Crisp, not mushy.** Whole-number scale when the screen allows it. When it does not, the picture still has hard pixel edges, not blur.
- **The frame belongs to the era.** 1941 gets a worn olive-and-brass cabinet frame; later eras tint it. It is decoration, low contrast, and never uses a bullet colour.
- **It just fits.** Resize the window, flip to fullscreen, turn the monitor: the game re-fits at once and never crops the play field.

**Anti-fantasy (must never happen):** a field that shows more or less world on some devices; HUD or hitbox cut off by a notch or the screen edge; bezel art that looks like a bullet or flashes; uneven pixel rows at a fractional scale; a rotated screen the player cannot turn back.

> `art-director` and `creative-director` not consulted (auto-approve). Bezel look is an art-director decision; this document defines only limits.

## Detailed Design

### Core Rules

**The canvas**

1. **Fixed canvas.** The game renders into a SubViewport of exactly **360x640 px** (`canvas_size`) on every device and mode. *(2026-11-03, ADR-0004 / ADR-0006:)* the game SubViewport uses `render_target_update_mode = UPDATE_ALWAYS` (the single-frame Critical Break flash relies on it). No gameplay, HUD or menu node reads the screen size. All of them use the SubViewport (`get_viewport()` inside the game returns 360x640).
2. **The HUD is inside the canvas.** The reserved top strip (`play_top` 48 px for 1-2P, 72 px for 3-4P, art bible §7.2) is part of the 360x640. The strip is never in the bezel, so the play field is the same size everywhere. Menus, pause and tally are also inside the canvas.
3. **Pixel rules inside the canvas.** The SubViewport uses nearest filtering and snaps 2D transforms and vertices to whole pixels (art bible §8.1). The canvas is never re-rasterised at window resolution.

**Layout (all in physical window pixels)**

4. **Effective screen.** Take the window size (physical pixels) and, on mobile, intersect it with the OS **safe area** (Rule 15). If TATE is on, swap width and height (F1). All layout maths happens in this *effective* space; TATE rotation is applied once at the end (Rule 12). *(Amended 2026-11-03, wave 4, touch-controls.md F2:)* when Touch controls are active, the effective area is the safe rect **minus the bottom `touch_strip_px`** (supplied by Touch TF2); `get_layout()` also returns `touch_strip_rect`. The strip reserve changes only while the session is not Playing (Touch Rule 3).
5. **Whole-number scale** `n` = the largest integer such that 360n and 640n both fit the effective screen (F2). **Fill scale** `f` = the largest real number that fits (F2).
6. **Scaling modes** (setting `display_scale_mode`, default **Auto**):

| Mode | Scale used | Notes |
|---|---|---|
| **Auto** | `n` if `n >= 1` and the canvas covers at least `auto_fill_min_pct` (85%) of the screen on the limiting side; otherwise `f` | F3. Matches the art bible device table. |
| **Pixel Perfect** | `n`; if `n = 0` (screen smaller than 360x640) falls back to `f` | Always sharp; may leave wide bezel. |
| **Fill** | `f` | Sharp-bilinear (Rule 9). |

7. **Placement.** The canvas is drawn at integer window-pixel size `dw x dh` (F4), centred in the effective screen (offsets rounded down). Everything not covered by the canvas is **bezel** (Rule 10).
8. **Pure and deterministic.** The layout is a pure function of (window size, safe area, mode, TATE, params). The same inputs always give the same layout; there is no hysteresis or history. Layout is recomputed only when one of those inputs changes.

**Rendering the canvas**

9. **One shader path.** The SubViewport texture is shown by one full-quad sprite with a **sharp-bilinear** shader (F5) and a linear-filtered texture. At an integer scale the shader's output equals nearest-neighbour; at a fractional scale each source pixel is a flat block with a blend region of about one screen pixel at its edges. When the scale is 1.0 or lower the shader uses plain linear sampling (a downscale). One code path serves all three modes. (→ ADR: Display presentation architecture.)

**Bezel**

10. **Bezel rectangles.** Up to four rectangles (top, bottom, left, right) cover everything outside the canvas in the full window (F4). Empty ones are skipped. Portrait phones get top and bottom panels; landscape windows get left and right panels; both can exist at once (windowed resize, Fill with spare height).
11. **Bezel content rules.**
   1. Bezel is decorative. It never holds gameplay information (score, lives, chain, bullets). It may show the stage name or hi-score only while the session state is not Playing (title, attract, game over, results, pause), and only if the panel is at least `bezel_feature_min_px` (48) canvas pixels wide or tall.
   2. Bezel is drawn behind the canvas and never overlaps it. No bezel pixel is drawn over the canvas, so bullets can never be hidden by it.
   3. Bezel uses art bible §4.7 warm neutrals with the era Accent at 20% on frame edges only. It never uses Void Indigo, Ink, or any hue in 225-265 degrees, and no bullet-reserved shape (orb, rice, needle, ring, art bible §3.3).
   4. Bezel is darker than the play field: average luma <= `bezel_luma_avg_max` (40 of 255) and peak luma <= `bezel_luma_peak_max` (96, Rec.709 on gamma values as in §4.2). The 2 canvas-px strip next to the canvas edge has luma <= 20 so the canvas edge always reads.
   5. Bezel never flashes. Critical Break's white frame is inside the canvas only. The only bezel motion is the era swap (Rule 13) and the 7.7 pulse rule if the art-director adds a pulse.
   6. Bezel art is drawn at the **same scale** `s` as the canvas, with the same shader, so its pixels match the canvas pixels in size.
   7. Setting `bezel_style` = **Art** (default) or **Plain** (solid Cabinet Char `#1E1B18`, no art, no text). Plain is for OLED burn-in worries, low-end devices and accessibility.
12. **Era.** The bezel follows the current era (1941, 1970s, 2030s, 2100). It swaps on `era_swap_committed(era_index)` (Era shift 19, [GDD](era-shift-and-plane-evolution.md); visible behind the era card), with `stage_started` as a fallback if the swap has not run, when the era differs from the one shown, in `bezel_era_swap_frames` (8) frames as 4 stepped changes (no tween blur). Title and plane select use the neutral warm bezel (art bible §7.8).

**Window, orientation and platforms**

13. **Window mode** (setting `window_mode`: Windowed / Fullscreen). Default Windowed on desktop, Fullscreen on mobile and Web-on-mobile (not selectable on phones). Fullscreen is the borderless desktop-sized mode, not exclusive, so alt-tab works. The presenter always reads the real mode back from the OS after a change and after every resize, because the OS or browser can leave fullscreen on its own.
14. **Windowed size.** First launch opens a window of height `window_default_height_pct` (90%) of the usable screen height, rounded down to an even number, at exactly 9:16 (F6). After that the saved size is used. The window is freely resizable (any aspect becomes bezel). The minimum window size is 360x640 (640x360 when TATE is on).
15. **Safe area (phones).** On iOS and Android the canvas is laid out inside the OS safe area (notch, Dynamic Island, home indicator, punch-hole, rounded corners). Bezel art may draw under them; bezel touch targets (Touch controls 31) may not. On desktop, Web and Switch the safe area is ignored (treated as the full window). *(Web safe area is unverified, see Open Questions.)*
16. **Orientation.** Phones and tablets are locked to portrait (project setting; no rotation handling). PC, Web and Switch are free.
17. **TATE** (setting `tate_mode`: Off / Rotate clockwise / Rotate counter-clockwise; PC and Switch only; default Off, never auto-detected). The whole display (canvas and bezel) is rotated 90 degrees about the window centre. TATE is for a monitor or Switch physically turned on its side but still reported as landscape. Changing TATE starts a confirmation: **"Keep this rotation?"** with a `tate_confirm_seconds` (10 s) real-time countdown; no answer or Cancel reverts to the previous value. Bezel art is authored for the effective portrait space and rotates with the image.
18. **Pointer mapping.** The presenter maps mouse and touch positions from window space to canvas space with the inverse layout transform (F7) and forwards them to the SubViewport. Positions outside the canvas are not forwarded to the canvas (they belong to bezel/overlay). Keyboard and gamepad events are forwarded unchanged. Gameplay input still polls the `Input` singleton (Input 2) and is unaffected.
19. **Overlay layer.** A window-space layer above the canvas image holds things that must sit in the bezel or over the screen in real pixels (Touch controls 31, debug overlay). It is not rotated or scaled by the layout; the layout is given to its owners (Interactions). Nothing in W3 covers the canvas; touch buttons live in the strip below it (wave 4, touch-controls.md). While the session is Playing, touches belong to Touch controls and are not forwarded to the canvas; in menus they are forwarded (Touch Rule 29).
20. **Web.** The presenter works only in physical (device) pixels of the canvas element as reported by the window size. It never reads CSS pixels. When the browser window, zoom, devicePixelRatio or mobile address bar changes, the engine reports a new window size and the layout is recomputed on that same frame. The page shell must give the canvas the full browser viewport with a background matching the bezel base colour (Visual/Audio Requirements). *(Canvas and devicePixelRatio behaviour unverified on 4.7, spike required.)*
21. **Cursor.** In Fullscreen while the session state is Playing, the mouse cursor is hidden. It is visible in every other state and whenever the mouse moves in a menu.
22. **Time.** The presenter is presentation only. It runs on real frame time and keeps running while the game is paused (`PROCESS_MODE_ALWAYS`). No gameplay logic reads it, so the 60 Hz tick rule of ADR-0001 is not touched.

**Tiers**

| Tier | Contents |
|---|---|
| MVP (basic) | Fixed 360x640 SubViewport, `DisplayLayout`, Auto / Pixel Perfect / Fill with the sharp-bilinear shader, Windowed/Fullscreen, resize, Web resize, **Plain** bezel only, min window size |
| Vertical Slice | Persisted settings and the Display settings screen (via 26 and 22) |
| Target (full) | Bezel art per era, safe area, TATE, overlay hooks for Touch controls (31), bezel text on idle screens |

### States and Transitions

The presenter has these states. Window mode (Windowed/Fullscreen) is a separate flag, not a state.

| State | Meaning | Enters from | Leaves to |
|---|---|---|---|
| **Uninitialised** | Nodes not built | App start | Active (first layout applied before the first game frame) |
| **Active** | Layout valid and applied | Uninitialised, Suspended, TateConfirm | Suspended, TateConfirm |
| **Suspended** | Window size has a zero side (minimised) or the app is hidden | Active | Active when the size is valid again; the last layout is kept while suspended |
| **TateConfirm** | A new TATE value is applied and awaiting Keep / Cancel / timeout | Active | Active (kept: value saved; cancelled or timed out: previous value restored) |

| Event | Effect |
|---|---|
| `size_changed` (window) | Recompute layout (F1-F4), apply, emit `layout_changed` |
| Setting changed (mode, scale mode, bezel style, window mode) | Recompute and apply on the same frame (live preview, no confirm) |
| TATE changed | Apply, enter TateConfirm |
| `stage_started` with a new era | Start bezel era swap (Rule 12) |
| Session state change | Show/hide bezel text (Rule 11.1), cursor (Rule 21) |

### Interactions with Other Systems

| System | Direction | Interface (provisional unless the other system has a GDD) |
|---|---|---|
| Game events and session (1) | In | Reads session state (Playing or not) and the current era; listens to `stage_started`. Never writes session state. |
| [HUD (20)](hud.md) | Out | Guarantees the HUD canvas is 360x640 and never in the bezel. HUD owns its strip layout. *Amended 2026-11-03 (wave 3b, Accessibility 28 Rule 20):* there is **no HUD scale**; `play_top` (48 / 72) is unchanged by accessibility options. |
| [Menus, title, plane select (22)](menus-title-plane-select.md) | In/Out | Menus render inside the canvas. The Display settings screen edits `display_scale_mode`, `window_mode`, `tate_mode`, `bezel_style`, and shows the read-only line "Scale x3 (1080x1920)". The TATE confirm dialog is a canvas menu. |
| Save, settings and high scores (26) | In/Out | Stores the four display settings (persisted keys below). The presenter applies defaults when no save exists and works without 26. |
| [Accessibility (28)](accessibility-options.md) | In | `bezel_style = Plain` is an accessibility-relevant option; no other coupling. No HUD scale; `play_top` unchanged by accessibility options. |
| Touch controls (31) — [GDD](touch-controls.md) | ↔ | ← `touch_strip_px` (Touch TF2) reduces the effective area. → `get_layout()` returns the current layout (canvas rect, bezel rects, scale, safe rect, `touch_strip_rect`). Signal `layout_changed(layout)`. `bezel_touch_rects` are the bezel rects clipped to the safe area. Pointer events consumed by the overlay are not forwarded to the canvas. |
| Input (2) | In | Provisional actions `toggle_fullscreen` (F11 / Alt+Enter) and `display_reset` (hold 2 s, resets the four display settings to default; the safety net for a bad TATE). Pointer events reach the presenter as raw window events. |
| [VFX and screen feedback (25)](vfx-and-screen-feedback.md) | Rule | Screen shake must move content *inside* the SubViewport (world layers only, integer pixels), never the SubViewport or bezel. Flashes are inside the canvas, never on the bezel. *(2026-11-03: VFX has no global shake; the only shake is a boss-sprite offset of at most 4 px at a Critical Break, so no overscan margin is needed for the canvas.)* |
| Bullet manager (3) | Rule | The canvas clips drawing: bullets beyond `offscreen_margin` are culled by Bullet manager; anything within the margin is simply not visible because it is outside the SubViewport. Bezel does not hide or show bullets. |
| [Parallax and environment (23)](parallax-and-environment.md) | Rule | Backgrounds are drawn inside the canvas and must not rely on seeing beyond 360x640. Parallax keeps an 8 px overscan (strips 376 wide, plates 376 x 656); any world-layer shake is capped at 8 px. |
| [Era shift (19)](era-shift-and-plane-evolution.md) | In | `era_swap_committed(era_index)` triggers the bezel era swap (Rule 12). |
| [Audio (24)](audio.md) | None | Not affected. |
| Localization (27) | In | Bezel text and the display settings labels are localized strings (Bengali + English). |

> Decided under auto-approve (2026-11-03): SubViewport presenter instead of Godot's built-in stretch (Rule 1, 9, §Open Questions); one sharp-bilinear shader path for all modes; bezel drawn at the canvas scale with the same shader; Auto threshold 85% (from the art bible); TATE manual with CW/CCW and a 10 s revert; safe area on phones only; pointer events mapped by the presenter; bezel text only outside Playing; Plain bezel style as an option; fullscreen is borderless not exclusive; windowed default 90% height at 9:16; cursor hidden in fullscreen play; tiering as above.

## Formulas

All screen values are integer physical pixels unless marked real.

### F1: Effective screen

`(We, He) = TATE ? (Hs, Ws) : (Ws, Hs)` where `(Ws, Hs)` is the window size, or the safe-area size on mobile.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Window or safe width | `Ws` | int | 1-16384 | Physical pixels |
| Window or safe height | `Hs` | int | 1-16384 | Physical pixels |
| TATE | `TATE` | bool | on/off | Either rotation direction swaps the axes |
| Effective size | `We, He` | int | 1-16384 | Space the canvas is laid out in |

**Output Range:** same as the inputs, axes swapped under TATE.
**Example:** 1920x1080 with TATE on gives `We = 1080`, `He = 1920`.

### F2: Scales

`n = min(We div 360, He div 640)`  and  `f = min(We / 360, He / 640)` (real)

Width-limited when `We * 640 <= He * 360`, otherwise height-limited (integer compare).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Whole-number scale | `n` | int | 0 up | 0 means the screen is smaller than 360x640 |
| Fill scale | `f` | real | > 0 | Exact fit on the limiting side |

**Output Range:** `n <= f < n + 1`-ish (`f >= n` always).
**Example:** 1290x2796: `n = min(3, 4) = 3`, `f = min(3.5833, 4.3688) = 3.5833`, width-limited (`1290*640 = 825,600 <= 2796*360 = 1,006,560`).

### F3: Mode resolution

```
Pixel Perfect: s = n if n >= 1 else f
Fill:          s = f
Auto:          s = n if n >= 1 and (limit_canvas * 100) >= (auto_fill_min_pct * limit_screen) else f
```

`limit_canvas = 360n` and `limit_screen = We` when width-limited; `640n` and `He` when height-limited.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Final scale | `s` | real | > 0 | Integer-valued when INTEGER, else `f` |
| Fill threshold | `auto_fill_min_pct` | int | 70-95 | Default 85 (art bible §8.1.1) |
| Kind | `kind` | enum | INTEGER / FILL | INTEGER iff `s == n` and `n >= 1` |

**Output Range:** `s > 0`; INTEGER results are whole numbers.
**Example:** 828x1792: width-limited, `n = 2`, `720*100 = 72,000 >= 85*828 = 70,380`, so Auto gives x2 INTEGER. 1290x2796: `1080*100 = 108,000 < 85*1290 = 109,650`, so Auto gives FILL 3.5833. Boundary: width 423 (height 2000): `36,000 >= 35,955` INTEGER x1; width 424: `36,000 < 36,040` FILL 1.1778.

### F4: Canvas rectangle and bezel rectangles

```
dw = round(360 * s)    dh = round(640 * s)
x0 = ox + (We - dw) div 2    y0 = oy + (He - dh) div 2
```

`(ox, oy)` is the origin of the effective area (the safe-area offset; 0 on desktop). Bezel rects in the full effective window (width `W`, height `H`):
top `(0, 0, W, y0)`; bottom `(0, y0+dh, W, H-(y0+dh))`; left `(0, y0, x0, dh)`; right `(x0+dw, y0, W-(x0+dw), dh)`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Canvas size on screen | `dw, dh` | int | 1 up | `round` is half away from zero |
| Canvas origin | `x0, y0` | int | any | May be negative only if `s` is rounded up beyond the screen (never, since `s <= f`, except rounding of 0.5 px, which F4 clamps to 0) |
| Origin offset | `ox, oy` | int | 0 up | Safe-area offset |
| Window size | `W, H` | int | 1 up | Full effective window (bezel fills all of it) |

**Output Range:** canvas always inside the effective area; the four bezel rects plus the canvas cover the window exactly with no overlap.
**Example:** 2560x1440, `s = 2`: `dw = 720`, `dh = 1280`, `x0 = 920`, `y0 = 80`. Left `(0,80,920,1280)`, right `(1640,80,920,1280)`, top `(0,0,2560,80)`, bottom `(0,1360,2560,80)`. Areas: `2*920*1280 + 2*2560*80 + 720*1280 = 2,355,200 + 409,600 + 921,600 = 3,686,400 = 2560*1440`. Fill example, 1920x1080, `s = 1.6875`: `dw = round(607.5) = 608`, `dh = 1080`, `x0 = 656`, `y0 = 0`. Safe-area example, iPhone X 1125x2436 with safe `y = 132`, `h = 2202`: `n = min(3, 3) = 3`, width-limited, `1080*100 >= 85*1125`, so x3; `dw = 1080`, `dh = 1920`, `x0 = 22`, `y0 = 132 + (2202-1920) div 2 = 273`; top bezel 273 px, bottom bezel 243 px.

### F5: Sharp-bilinear sample

For output texel position `t = uv * (360, 640)`, per axis:

```
i = floor(t)    fr = t - i
r = 0.5 - 0.5 / s          (used only when s > 1)
c = fr - 0.5
fx = (c - clamp(c, -r, r)) * s + 0.5
uv' = (i + fx) / (360, 640)
```

If `s <= 1`, `uv' = uv` (plain linear).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Scale | `s` | real | > 0 | From F3 |
| Flat half-width | `r` | real | 0-0.5 | Part of the texel (each side of centre) shown as one flat colour |
| Fraction in texel | `fr` | real | 0-1 | Position inside the source pixel |
| Sample offset | `fx` | real | 0-1 | Where inside the texel the linear sampler reads |

**Output Range:** `fx` in [0, 1]; flat block share of each source pixel is `1 - 1/s`.
**Example:** `s = 1.6875`: `r = 0.5 - 0.2963 = 0.2037`; `fr = 0.9` gives `c = 0.4`, `fx = (0.4 - 0.2037) * 1.6875 + 0.5 = 0.8313`; `fr = 0.5` gives `fx = 0.5`. `s = 3`: `r = 0.3333`; screen-pixel centres fall at `fr = 1/6, 1/2, 5/6`, giving `c = -1/3, 0, 1/3`, all inside `[-r, r]`, so `fx = 0.5` for every pixel (identical to nearest-neighbour).

### F6: Default windowed size

`h = (floor(window_default_height_pct * Hu / 100) div 2) * 2`,  `w = (((h * 9) div 16) div 2) * 2`, then `max(w, 360)`, `max(h, 640)`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Usable screen height | `Hu` | int | 640 up | Screen height minus taskbar/title area, physical px |
| Height percent | `window_default_height_pct` | int | 60-100 | Default 90 |

**Output Range:** even width and height, 9:16 (within 1 px), at least 360x640.
**Example:** `Hu = 1040`: `h = 936`, `w = 526`. `Hu = 1400`: `h = 1260`, `w = 708`. `Hu = 600`: `h = 540` clamps to 640, `w = 360`.

### F7: Window point to canvas point

Effective point first, then canvas:

```
Off:  (xe, ye) = (u, v)
CW:   (xe, ye) = (v, Ws - u)
CCW:  (xe, ye) = (Hs - v, u)
canvas = ((xe - x0) * 360 / dw, (ye - y0) * 640 / dh)   (real)
inside = 0 <= canvas.x < 360 and 0 <= canvas.y < 640
```

(`Ws, Hs` are the *unswapped* window dimensions. On mobile, subtract the safe-area origin from `(u, v)` first.)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Window point | `(u, v)` | real | any | Pointer position in window pixels |
| Canvas point | `canvas` | real | any | Position in the 360x640 SubViewport |
| Inside | `inside` | bool | - | Only inside points go to the canvas |

**Output Range:** inside points are in [0, 360) x [0, 640). The inverse (canvas to window) round-trips within 1e-4.
**Example:** 2560x1440, x2: `(1280, 720)` maps to `((1280-920)*360/720, (720-80)*640/1280) = (180, 320)`. `(919, 80)` maps to `(-0.5, 0)`: not inside. TATE CW on 1920x1080 (x3, `x0 = y0 = 0`): `(1920, 540)` gives `(xe, ye) = (540, 0)` and canvas `(180, 0)`, the top centre. TATE CCW: `(0, 540)` gives `(xe, ye) = (1080 - 540, 0) = (540, 0)` and canvas `(180, 0)`.

## Edge Cases

- **If the window has a zero side (minimised)**, the state is Suspended, the last layout is kept and no recompute runs; on restore the layout is recomputed from the new size.
- **If the screen is smaller than 360x640 in Pixel Perfect (`n = 0`)**, the scale becomes `f` (a downscale with plain linear sampling) and the kind is FILL. Example 300x500: `f = min(0.8333, 0.78125) = 0.78125`, `dw = 281`, `dh = 500`, `x0 = 9`.
- **If Auto finds `n = 0`**, it uses `f` (same as above).
- **If both axes limit equally** (`We*640 == He*360`, exact 9:16), there is no bezel in Fill and no bezel at integer scales when the size is an exact multiple (e.g. 1080x1920 at x3).
- **If the window is dragged across the 85% line**, the layout flips between INTEGER and FILL on that frame with no hysteresis. The same size always gives the same result.
- **If a fractional OS scale (Windows 125%) or browser zoom changes the physical size**, layout uses the new physical size on the same frame; the game never reads the OS scale factor.
- **If the window moves to a monitor with a different size or DPI**, `size_changed` fires and the layout (and, on mobile, the safe area) is re-read.
- **If a phone reports a safe area larger than the window or with a zero side**, the safe area is ignored for that frame and the full window is used.
- **If the safe area is smaller than the canvas at the chosen mode** (tiny window), Pixel Perfect falls back to FILL as in the `n = 0` case.
- **If TATE is selected on a phone or tablet**, the setting is hidden in the menu; if a saved value exists from another device it is ignored on mobile.
- **If the TATE confirm times out (10 s) or the player cancels**, the previous TATE value is restored, applied, and saved as before. The countdown uses real time and keeps running while paused.
- **If the game is closed while in TateConfirm**, the previous value stays saved (the new value is only saved on Keep).
- **If the player holds `display_reset` for 2 s**, all four display settings return to defaults and apply at once, whatever the current state.
- **If the browser or OS exits fullscreen by itself (Esc, system gesture)**, the presenter reads the real mode back, shows Windowed, and does not re-enter fullscreen; the saved preference is unchanged until the player changes it in the menu.
- **If fullscreen is requested on Web from anything other than a direct input handler**, the browser may refuse; the setting stays Windowed and no error is shown. The toggle runs inside the input event call (F11, menu button press).
- **If the Web page's canvas size is fractional in CSS pixels (zoom 110%)**, only the integer physical size the engine reports is used.
- **If a mobile browser address bar appears or hides**, a new window size is reported and the layout recomputes immediately (the canvas may jump between x2 and Fill; see Open Questions).
- **If the bezel panel is smaller than `bezel_feature_min_px` (48 canvas px)** in either dimension, only the tiled base plate and frame trim draw; no feature art or text.
- **If the session is Playing**, bezel text is hidden; if it changes to Playing mid-frame, the text is gone on that frame.
- **If a stage starts with the same era**, the bezel does not swap.
- **If `stage_started` fires while a swap is running**, the swap restarts toward the new era from the current step.
- **If the bezel asset for an era is missing**, the Plain bezel is used and one warning is logged.
- **If `bezel_style = Plain`**, no bezel art loads, no text shows, and the era swap does nothing.
- **If a pointer event lands in the bezel**, it is not forwarded to the canvas; the overlay layer may handle it.
- **If a touch is consumed by the overlay (Touch controls)**, it is not forwarded to the canvas.
- **If two pointers (multi-touch) are active**, each is mapped independently by F7.
- **If the SubViewport texture is not ready on the first frame**, the screen shows the bezel base colour (`#14110E`) for that frame, never garbage.
- **If the 2D snap setting is off inside the SubViewport (misconfiguration)**, the test AC-33 fails; the layout itself is unaffected.

## Dependencies

**Upstream (this system depends on):**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Game events and session state (1) | Soft | Session state (Playing / not) and current era; `stage_started`. Works with defaults (neutral bezel, text hidden) if absent. | Yes |
| Save, settings and high scores (26) | Soft | Provides the persisted display settings (`display.scale_mode`, `display.window_mode`, `display.tate_mode`, `display.bezel_style`, `display.window_size`). Defaults apply if absent. | [Yes](save-settings-high-scores.md) |
| Input and player mapping (2) | Soft | `toggle_fullscreen` and `display_reset` actions. | [Yes](input-and-player-mapping.md) |
| Localization (27) | Soft | Localized bezel text and settings labels. | [Yes](localization.md) |
| Era shift and plane evolution (19) | Soft | `era_swap_committed(era_index)` for the bezel swap (Rule 12). | [Yes](era-shift-and-plane-evolution.md) |

**Downstream (depends on this system):**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| HUD (20) | Hard | Fixed 360x640 canvas, strip inside it; no HUD scale, `play_top` 48 / 72 unchanged by accessibility options | [Yes](hud.md) (prototype code to replace) |
| Menus, title and plane select (22) | Hard | Display settings screen; canvas-hosted menus; TATE confirm (Menus Rules 43-45) | [Yes](menus-title-plane-select.md) |
| Touch controls (31) | Hard | `get_layout()`, `layout_changed`, `bezel_touch_rects`, `touch_strip_rect`, overlay layer; supplies `touch_strip_px` | Yes ([GDD](touch-controls.md)) |
| Accessibility options (28) | Soft | `bezel_style`; no HUD scale | [Yes](accessibility-options.md) |
| Save, settings and high scores (26) | Soft | Stores the display settings (`display.*` keys) | [Yes](save-settings-high-scores.md) |
| Bullet manager (3), Player plane (5), Parallax (23), VFX (25) | Soft | Rely on a constant 360x640 clipped canvas; shake stays inside it | Yes |

**Persisted settings (Save 26 keys):** `display.scale_mode` (auto / pixel_perfect / fill), `display.window_mode` (windowed / fullscreen), `display.tate_mode` (off / cw / ccw), `display.bezel_style` (art / plain), `display.window_size` (Vector2i, windowed only). The old `display.bezel` and `display.integer_scale` keys are retired. *Matched 2026-11-03:* Save (26) stores them as `display.scale_mode`, `display.window_mode`, `display.tate_mode`, `display.bezel_style`, `display.window_size` (Save Rule 16, amended from Menus (22)).

**Code migration (dependency for programmers, nothing changed by this GDD):**
- `src/` and `project.godot` are still **480x640** (`viewport_width=480`, `play_area := Rect2(0, 0, 480, 640)` in game, player and bullet manager, HUD offsets, boss anchors in `data/bosses/*.tres`). They must move to 360x640 with the gameplay retune owned by Bullet pattern library (spacing and counts x0.75) and Boss (14).
- Project display settings change from the current `stretch/mode="canvas_items"` to **disabled** (the presenter does the scaling), base size 360x640, portrait orientation on mobile.
- Game and menu scenes must live under the presenter's SubViewport. `change_scene_to_*` puts scenes under the root window, so a scene host inside the SubViewport is needed (→ ADR). Autoloads stay at the root.

**Amendments to other docs:**

1. `design/art/art-bible.md` §8.1 Base resolution row: replace "`display/window/stretch/mode = viewport`, `aspect = expand`, `scale_mode = integer`" with "root window stretch disabled; the game renders into a 360x640 SubViewport shown by the Display scaler (see display-scaler-and-bezel.md)". Keep the 2D snap rule, applied to the SubViewport.
2. `design/art/art-bible.md` §8.1.1 Scaling modes, Fill row: change "pre-scale x N with nearest, then a smooth down-scale" to "one-pass sharp-bilinear shader (display-scaler-and-bezel.md F5), visually equivalent". Add the safe-area note "phones only".
3. `design/art/art-bible.md` §8.9 spike 3: add "SubViewport input forwarding, `Window.content_scale_*` not used, Web devicePixelRatio, Fill sharpness at 1080p".
4. `design/gdd/systems-index.md` row 4 and Progress tracker (see final report).
5. `design/gdd/game-events-and-session.md` Dependencies: add Display scaler and bezel (4) as a downstream reader of session state, era and `stage_started`.
6. `docs/project-structure.md`: add `src/display/` (DisplayLayout, DisplayPresenter, shader) and `data/display/` (display params, bezel art per era).
7. Future GDDs (20, 22, 26, 28, 31) must list "Display scaler and bezel" in Dependencies with the interface above.

## Tuning Knobs

All in `data/display/display_params.tres` (no magic numbers in code, ADR-0001).

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `canvas_size` | 360x640 | fixed | - | - | Everything; locked by the art bible (not a tuning knob) |
| `auto_fill_min_pct` | 85 | 70-95 | Wide bezel bands at integer scale (e.g. iPhone Pro Max x3 at 84% would stay integer) | Auto goes Fill (soft edges) too often | F3; art bible device table is checked at 85 |
| `window_default_height_pct` | 90 | 60-100 | Small first window | Window overlaps the taskbar | F6 |
| `window_min_size` | 360x640 | 180x320-360x640 | Window can be smaller than the canvas (downscale) | Cannot shrink the window | F2 (n = 0 case) |
| `tate_confirm_seconds` | 10 | 5-20 | Not enough time to rotate head | Long wait on a wrong rotation | Rule 17 |
| `bezel_feature_min_px` | 48 | 24-96 canvas px | Feature art crammed in slim panels | Feature art rarely shows | Rule 11.1, edge cases |
| `bezel_era_swap_frames` | 8 | 4-16 | Abrupt tint change | Swap lingers into the stage | Rule 12; art bible §7.7 (8-frame panel) |
| `bezel_luma_avg_max` | 40 | 24-64 | Bezel too dark to show art | Bezel competes with the field | Rule 11.4, art bible §4.2 (backgrounds luma 16-128) |
| `bezel_luma_peak_max` | 96 | 64-128 | No highlights | Bright trim pulls the eye off the canvas | Rule 11.4 |
| `bezel_edge_strip_px` | 2 | 1-4 canvas px | Canvas edge hard to read in dark eras | Wasted bezel | Rule 11.4 |
| `display_reset_hold_seconds` | 2 | 1-4 | Accidental reset | Frustrating if stuck | Input (2) |
| `hide_cursor_in_play` | true | on/off | - | - | Rule 21 |
| Present-pass GPU budget | 0.5 ms on REF-PHONE, 0.2 ms on REF-PC | - | - | Cuts into the 16.6 ms frame | Technical preferences; proposal until profiled |
| Bezel memory | 1 MB RGBA8 per loaded era, 1 era loaded | 0.25-2 MB | - | VRAM budget (art bible §8.6) | 8.6 |

**Owned elsewhere:** `play_top` and HUD layout (art bible §7.2, HUD 20); no HUD scale (Accessibility 28 Rule 20); persistence format (26); touch button layout (31); `offscreen_margin` (Bullet manager); screen shake amount (VFX 25); the four device-independent defaults for settings UI labels (Menus 22).

> Decided under auto-approve (2026-11-03): all defaults above. 85% comes from the art bible and was checked against all 17 device rows (AC-02). Bezel luma caps are proposals for the art-director to confirm; the edge strip rule exists so the 2030s night background (luma 17-25) always meets a visible edge. The GPU and memory budgets are proposals until profiled.

## Visual/Audio Requirements

**Window-level draw layers** (root window, back to front; these are outside the canvas stack of art bible §6.8, which lives inside the SubViewport):

| Layer | Content |
|---|---|
| W0 | Page/window clear colour `#14110E` (also the HTML shell background on Web) |
| W1 | Bezel base plate (tiled) and frame trim, bezel feature art, idle text |
| W2 | Canvas image (SubViewport texture, sharp-bilinear) |
| W3 | Overlay: Touch controls (31), debug overlay |

Bezel never draws on W2 or above; nothing in W3 covers the canvas; touch buttons live in the strip below it (amended 2026-11-03, touch-controls.md).

**Bezel art spec** (limits only; look is the art-director's):
- Authored at 1x in canvas pixels, drawn at scale `s`. Pieces: tileable base plate (32x32 or 64x64), 4 frame trim strips and corners, top/bottom feature panels, left/right feature panels. Nine-slice or tile, never stretched. One atlas per era, at most 256x256 px (about 256 KB RGBA8), at most 12 draw calls for the whole bezel.
- Palette: §4.7 warm neutrals, era Accent at 20% on edges only, per §7.8 era tinting. Forbidden: Void Indigo, Ink, hue 225-265 degrees, orb/rice/needle/ring shapes, Alarm Red (reserved), anything that looks like a score or chain readout when the state is Playing.
- Motion: none while Playing. Era swap = 4 stepped changes over 8 frames. Any pulse follows §7.7 (opacity change <= 40%, <= 2 Hz, one element). No flash, ever.
- Text on idle bezel (stage name, hi-score): Cream with the 1 px outline, Latin >= 12 px and Bengali >= 17 px (§4.7), both scripts at equal weight, localized, hidden while Playing.
- Per-era tint: 1941 olive/brass `#8A6F4A` Accent at 20%; 1970s `#A85A22`; 2030s `#2A8A90`; 2100 `#A8348F` (Accent column of §4.5), always at 20% and on trim only.

**Web shell:** page and canvas background `#14110E`, canvas fills 100% of the viewport, no scrollbars, no page zoom or double-tap zoom (`user-scalable=no`, `touch-action: none`), canvas resize policy adaptive *(setting name unverified on 4.7)*.

**Audio:** none. (Display changes make no sound; the TATE confirm uses the standard menu sounds from Audio 24.)

## UI Requirements

Player-facing UI is the **Display settings** screen and the **TATE confirm** dialog, both canvas menus owned by Menus (22). This GDD defines their content. *Note 2026-11-03:* the Display settings screen and TATE confirm are defined by Menus (22) Rules 43-45 ([GDD](menus-title-plane-select.md)); persisted keys match the amended Save schema.

| Item | Control | Shown on | Notes |
|---|---|---|---|
| Window mode | Windowed / Fullscreen | PC, Web (desktop) | Hidden on phones/tablets |
| Scaling | Auto / Pixel Perfect / Fill | All | Live preview |
| Rotate screen (TATE) | Off / Clockwise / Counter-clockwise | PC, Switch | Opens the confirm dialog |
| Bezel | Art / Plain | All | Plain also disables idle text |
| Info line | "Scale x3 - 1080x1920" or "Scale 1.69 (Fill)" | All | Read-only, from `get_layout()` |
| Reset display | Button (hold-to-confirm per art bible §7.8) | All | **Same result as** `display_reset`; the **hold length is `confirm_hold`** (60 ticks at NORMAL, honouring `access.confirm_hold`), not the 2 s real-time window of the `display_reset` hotkey. The hotkey remains a separate input path with its own 2 s length *(amended 2026-11-03, wave 5 batch 2; Menus Rule 43, AC-50)* |

- TATE confirm dialog: "Keep this rotation?" (Bengali and English), a visible countdown (10, 9, ...), Keep (default focus is **Cancel**, so doing nothing is safe) and Cancel. Gamepad and keyboard operable; text is readable when the screen is rotated wrongly only after rotating the head, which is why the revert is automatic.
- Debug tools (debug builds): layout overlay with window size, effective size, `n`, `f`, `s`, kind, canvas rect, bezel rects, safe rect, TATE; a toggle to draw the canvas rect outline and a bezel-rect tint; forced-size commands to test the device table.

📌 **UX Flag**: run /ux-design for the Display settings screen and TATE confirm dialog before writing epics.

## Acceptance Criteria

**Defaults used:** `canvas_size` 360x640, `auto_fill_min_pct` 85, `window_default_height_pct` 90, `tate_confirm_seconds` 10, `bezel_feature_min_px` 48, `bezel_era_swap_frames` 8, `bezel_luma_avg_max` 40, `bezel_luma_peak_max` 96, `bezel_edge_strip_px` 2, `display_reset_hold_seconds` 2; Auto mode and no safe area unless stated.

**Test setup:** `DisplayLayout` is a node-free `RefCounted` pure function: tests build it with an injected `DisplayParams` resource loaded from `data/display/display_params.tres` (numbers read from the `.tres`, not hard-coded) and call `compute(window_size, safe_rect, mode, tate)`. No scene tree, no real window. Tests live in `tests/unit/test_display_layout_*.gd`, `extends SceneTree` style like `tests/unit/test_chain_tracker.gd`, test names `test_display_layout_<scenario>_<expected>`. The layout has no randomness and no ticks, so determinism is checked by repeated calls. Integration and manual items run in an editor/export build with the presenter. Shader maths (F5) is mirrored in a GDScript reference function so it can be unit tested.

**Layout and device table (Auto)**
- **AC-01 [Unit] (Rule 1, F4):** For every size in AC-02 and AC-03, `canvas_rect.size / scale` equals (360, 640) within 0.5 px (rounding), and `canvas_size` read from the `.tres` is (360, 640).
- **AC-02 [Unit] (F2, F3, device table):** Auto results: 1125x2436 gives x3 INTEGER canvas 1080x1920 at (22, 258); 828x1792 x2 (720x1280) at (54, 256); 1170x2532 x3; 1290x2796 FILL 3.5833 canvas 1290x2293 at (0, 251); 750x1334 x2 at (15, 27); 1440x3200 x4 at (0, 320); 1440x3120 x4 at (0, 280); 1080x2400 x3 at (0, 240); 720x1600 x2 at (0, 160); 1644x3840 x4 at (102, 640); 1812x2176 x3 at (366, 128); 1640x2360 FILL 3.6875 canvas 1328x2360 at (156, 0).
- **AC-03 [Unit] (F2, F3, landscape rows):** 1280x720 x1 at (460, 40); 1920x1080 FILL 1.6875 canvas 608x1080 at (656, 0); 2560x1440 x2 at (920, 80); 3840x2160 x3 at (1380, 120); 1280x800 FILL 1.25 canvas 450x800 at (415, 0); 1920x1080 TATE and 1080x1920 off both give x3, canvas 1080x1920 at (0, 0).
- **AC-04 [Unit] (Rule 6, F3):** Pixel Perfect on 1920x1080 gives x1 INTEGER; Fill on 2560x1440 gives FILL 2.0 (kind FILL even though whole); Pixel Perfect on 300x500 gives FILL 0.78125 canvas 281x500 at (9, 0).
- **AC-05 [Unit] (F3 boundary):** Width 423 x height 2000 gives INTEGER x1; width 424 x height 2000 gives FILL 1.1778. Changing `auto_fill_min_pct` to 90 in the test resource flips 1080 on 1125 wide (96%) to remain INTEGER and 1170 wide (92.3%) to remain INTEGER, but 1290 stays FILL.
- **AC-06 [Unit] (F4):** For 20 sample sizes (including odd widths), the canvas rect plus the non-empty bezel rects tile the window exactly: areas sum to W*H and no two rects overlap. 2560x1440 gives the four rects listed in F4.
- **AC-07 [Unit] (Rule 8):** Calling `compute` 1000 times with the same inputs returns identical layouts; calling it with a sequence of sizes then returning to the first size returns the first layout exactly (no hysteresis).
- **AC-08 [Unit] (Rule 7):** Offsets use floor: 1125x2436 gives x0 = 22 (not 23); even-width differences give exact halves.

**TATE**
- **AC-09 [Unit] (Rule 17, F1):** 1920x1080 TATE gives effective (1080, 1920); 1280x720 TATE gives x2 (720x1280, no bezel); 2560x1440 TATE gives x4 (1440x2560, no bezel).
- **AC-10 [Unit] (F7):** TATE CW on 1920x1080: window (1920, 540) maps to canvas (180, 0) inside; (0, 540) gives (xe, ye) = (540, 1920), canvas (180, 640), which is not inside (upper bound is exclusive). TATE CCW: (0, 540) maps to canvas (180, 0).
- **AC-11 [Unit] (F7 round trip):** For 200 pseudo-random window points (seeded RNG injected) in each of Off, CW, CCW, `canvas_to_window(window_to_canvas(p))` returns `p` within 1e-4 whenever `inside` is true.
- **AC-12 [Integration] (Rule 17, edge):** Setting TATE CW enters TateConfirm; with no input for 10 s of real time (including while paused) the previous value is restored and saved unchanged; pressing Keep saves CW; default focus on the dialog is Cancel.

**Pointer mapping**
- **AC-13 [Unit] (F7):** 2560x1440 x2: (1280, 720) maps to (180, 320); (920, 80) maps to (0, 0) inside; (919, 80) maps to (-0.5, 0) not inside; (1639, 1359) maps to (359.5, 639.5) inside; (1640, 80) not inside.
- **AC-14 [Integration] (Rule 18):** A mouse click at the screen position of a menu button in the canvas activates that button at windowed 540x960, at fullscreen 2560x1440 and in TATE CW; a click in the bezel activates nothing in the canvas.
- **AC-15 [Integration] (Rule 18, 19):** A touch consumed by an overlay Control is not delivered to the canvas; an unconsumed touch inside the canvas is delivered once, not twice.
- **AC-16 [Integration] (Rule 18):** Keyboard and gamepad events reach the SubViewport GUI (menu focus moves with up/down), and gameplay `Input` polling still works while the game runs in the SubViewport.

**Sharp-bilinear**
- **AC-17 [Unit] (F5):** `s = 1.6875`: `r = 0.2037 +/- 0.0001`; `fr = 0.9` gives `fx = 0.8313 +/- 0.0001`; `fr = 0.5` gives `fx = 0.5`.
- **AC-18 [Unit] (F5, integer):** For `s` in {2, 3, 4}, sampling at every screen-pixel centre across one source pixel gives `fx = 0.5` exactly (equal to nearest-neighbour).
- **AC-19 [Unit] (F5):** For `s <= 1` (e.g. 0.78125), `uv' = uv`.
- **AC-20 [Manual] (Rule 9):** At 1920x1080 Fill, a 1 px checkerboard test sprite in the canvas shows hard flat blocks with a blend no wider than 1 screen pixel; at x2 and x3 a screenshot is identical to nearest-neighbour (pixel diff 0).

**Window, resize, platforms**
- **AC-21 [Unit] (F6):** `Hu = 1040` gives 526x936; `Hu = 1400` gives 708x1260; `Hu = 600` gives 360x640.
- **AC-22 [Integration] (Rule 14):** Dragging a window from 360x640 to 1600x600 and back to 360x640 changes the layout each frame without a crash, the game keeps running, and the final layout equals the first. The window cannot be resized below 360x640 (640x360 in TATE).
- **AC-23 [Integration] (Rule 13):** Toggling fullscreen with F11 and the menu both works; after the OS leaves fullscreen by itself the menu shows Windowed.
- **AC-24 [Integration] (edge, Suspended):** Minimising the window (zero size) causes no layout error and no division by zero; restoring recomputes the layout.
- **AC-25 [Integration] (Rule 20, Web):** In a Web export, resizing the browser window, changing page zoom to 150%, and (with devtools) setting devicePixelRatio to 2 and 3 each yields a valid layout with the canvas filling at least 85% of the limiting side in Auto, and no scrollbars. *(Depends on the Web spike.)*
- **AC-26 [Integration] (Rule 20, Web fullscreen):** Fullscreen from the menu button works in Chrome and Firefox desktop; F11 or the menu toggle exits it.

**Safe area and phones**
- **AC-27 [Unit] (Rule 15, F4):** iPhone X 1125x2436 with safe rect (0, 132, 1125, 2202) gives x3, canvas (22, 273, 1080, 1920), top bezel height 273, bottom bezel height 243, and `bezel_touch_rects` clipped to y in [132, 2334).
- **AC-28 [Unit] (edge):** A safe rect with a zero side, or larger than the window, is ignored and the full window is used.
- **AC-29 [Manual] (Rule 15):** On an iPhone X-class device and a punch-hole Android, no canvas pixel sits under the notch, camera or home indicator.
- **AC-30 [Unit] (Rule 15):** On desktop and Web, a non-full safe rect passed in is ignored.

**Canvas rules**
- **AC-31 [Integration] (Rule 1):** `get_viewport().get_visible_rect().size` read from a gameplay node, a HUD node and a menu node is (360, 640) in windowed 540x960, fullscreen 2560x1440 and TATE.
- **AC-32 [Integration] (Rule 2):** In a 4P screenshot at 1080x1920 (x3), the HUD strip occupies canvas y 0-71 and no bullet is drawn above y 72; the strip is not in the bezel.
- **AC-33 [Integration] (Rule 3):** The SubViewport has nearest filtering and 2D transform and vertex snap on; a sprite at a fractional position is drawn on a whole pixel.
- **AC-34 [Integration] (VFX rule):** Triggering a Critical Break flash and a screen shake leaves every bezel pixel unchanged (pixel diff 0 over the bezel rects) and does not move the canvas rect.

**Bezel**
- **AC-35 [Manual] (Rule 11.3, 11.4):** For each era's bezel atlas, a script measures average luma <= 40 and peak luma <= 96, the 2 px strip next to the canvas has luma <= 20, and no pixel has a hue in 225-265 degrees at saturation > 30%.
- **AC-36 [Manual] (Rule 11.1):** While Playing, no text or number is visible on the bezel; on the title, results and pause screens, the hi-score or stage name shows only if the panel is >= 48 canvas px.
- **AC-37 [Integration] (Rule 12):** `stage_started` with a new era changes the bezel tint in 4 steps over 8 frames; with the same era nothing changes; a second `stage_started` mid-swap restarts toward the new era without a flash.
- **AC-38 [Integration] (edge, Plain):** `bezel_style = Plain` shows only `#1E1B18`; no bezel texture is loaded (VRAM monitor).
- **AC-39 [Integration] (edge):** Removing one era's bezel resource shows the Plain bezel and logs exactly one warning.
- **AC-40 [Manual] (Rule 11.2):** In a full-size screenshot at 1280x800 Fill and 2560x1440 x2, bezel pixels never overlap canvas pixels and no bullet is covered.
- **AC-41 [Manual] (Rule 11.5):** A 10 s recording of the bezel while playing shows no change (no flash, no pulse) except the era swap.

**Input, cursor, misc**
- **AC-42 [Integration] (Rule 21):** In fullscreen during Playing the cursor is hidden; in the title menu or when paused it is visible.
- **AC-43 [Integration] (display_reset):** Holding `display_reset` for 2 s (not 1.9 s) sets Auto, Windowed, TATE Off, Art and applies at once, even during TateConfirm.
- **AC-44 [Integration] (Rule 22):** With `get_tree().paused = true`, resizing the window still relayouts and the TATE countdown still runs.
- **AC-45 [Integration] (settings):** The four settings round-trip through Save (26) and apply at next launch; with no save file the defaults apply and the game runs.

**Performance**
- **AC-46 [Perf] (Rule 8):** `compute()` runs in <= 0.05 ms on REF-PC over 1000 calls (test fails above this); no allocation per frame when the inputs are unchanged.
- **AC-47 [Perf] (budget):** The present pass (SubViewport blit with shader plus bezel) costs <= 0.5 ms GPU on REF-PHONE at 1080x2400 x3 and <= 0.2 ms on REF-PC, and the bezel is <= 12 draw calls with <= 1 MB loaded texture memory.
- **AC-48 [Perf] (REF-WEB):** On REF-WEB at 4P load (2000 bullets), adding the presenter changes the frame time by <= 0.5 ms versus rendering directly to the window.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **ADR: Display presentation architecture.** SubViewport presenter (this GDD) versus Godot's built-in stretch (`viewport` + `expand` + integer, which has no sharp-bilinear Fill and no TATE). Needs the spike below to pass. Fallback if it fails: built-in `viewport` stretch with integer scale; Fill and TATE are dropped or degrade to Pixel Perfect. | technical-director | Before epics |
| 2 | Spike (art bible §8.9 spike 3, extended): input forwarding into the SubViewport (`push_input`, GUI focus, touch, multi-touch), whether `SubViewportContainer` could replace manual forwarding, 2D snap setting names on 4.7, sRGB look of the SubViewport texture in GL Compatibility, REF-WEB and REF-PHONE cost of the present pass. | godot-specialist / technical-artist | Before epics |
| 3 | Unverified Godot 4.7 APIs used: `Window.content_scale_*` (not used here, but needed if fallback), `DisplayServer.get_display_safe_area()`, `DisplayServer.window_set_mode`/fullscreen behaviour (borderless vs exclusive), `Viewport.push_input`, project setting for portrait orientation, Web canvas resize policy, Web devicePixelRatio and whether `Window.size` is in physical pixels, Web safe area. Check `docs.godotengine.org/en/4.7/` and a 4.7 export before coding. | godot-specialist | Before epics |
| 4 | Scene host: gameplay and menu scenes must live under the SubViewport, so scene changes need a custom host instead of `change_scene_to_*`. Affects Game events and session (1) scene flow. | lead-programmer | ADR |
| 5 | ~~Screen shake: VFX (25) must shake inside the canvas with an overscan margin so no empty strip shows; the maximum shake in px and the matching background overscan need a number.~~ **Closed 2026-11-03:** no global shake exists, so no canvas overscan margin; only a boss-sprite offset of at most 4 px (vfx-and-screen-feedback.md). Background overscan is 8 px, so any world-layer shake is capped at 8 px (parallax-and-environment.md Rule 26). | VFX (25) / Parallax (23) | Their GDDs |
| 6 | Mobile browser address bar and rotation can change the window size repeatedly. Is a debounce (e.g. 6 frames) needed to stop the canvas jumping between x2 and Fill? Default is no debounce. | technical-artist | Web playtest |
| 7 | Hi-score and stage-name bezel text needs data from Save (26) and Localization (27); confirm the interface when those GDDs exist. | Save (26) / Localization (27) | Their GDDs |
| 8 | ~~Touch controls (31) overlay behaviour on 16:9 phones with no bottom bezel (buttons over the lower corners at 50%) and the exact consume/forward rule for touches.~~ **Closed 2026-11-03:** a bottom strip reserve (`touch_strip_px`) on every touch device; touches are not forwarded to the canvas while Playing and are forwarded in menus (touch-controls.md Rules 3, 29; strip layout ACs AC-02 to AC-05 there). | Touch controls (31) | UX spec |
| 9 | Vsync, frame limiter and monitor selection: owned by whom? (Likely Save/settings 26.) Not part of this GDD. | producer | Before 26 |
| 10 | Switch export: window/safe-area behaviour and TATE (Switch held upright) depend on the third-party port vendor. | producer | Before Switch work |
| 11 | Bezel art direction per era, the final luma caps, whether the bezel may show decorative non-text elements that react to menu state. | art-director | Art pass |
| 12 | Should `window_size` be remembered per monitor, and should the first-run size snap to a whole-number scale when within 5% (e.g. 1260 -> 1280)? | technical-artist | Playtest |
| 13 | Screenshot/capture feature (canvas-only 360x640 and x4 image): worth adding for marketing and bug reports? | producer | Vertical Slice |
