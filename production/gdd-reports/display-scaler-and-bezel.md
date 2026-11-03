# Report: Display scaler and bezel (system 4)

## 1. File written
`design/gdd/display-scaler-and-bezel.md` (all 13 required headings, 48 acceptance criteria, 13 open questions).

Summary: the game always renders into a fixed 360x640 SubViewport. A node-free pure `DisplayLayout` class (window size, mobile safe area, scale mode, TATE in; scale, canvas rect, up to 4 bezel rects and a window-to-canvas pointer mapping out) drives a thin presenter node. The presenter shows the SubViewport through one sharp-bilinear shader (equal to nearest at integer scales), draws era-tinted bezel at the same scale, and handles window mode, resize, Web, safe area and TATE. All 17 rows of the art bible device table were re-computed and match the Auto rule (85%).

## 2. Key decisions (auto-approve)
- SubViewport presenter instead of Godot's built-in stretch (viewport + expand + integer). Reason: built-in stretch cannot do sharp-bilinear Fill, TATE, or a controlled bezel/safe area. Fallback if the spike fails: built-in viewport stretch, drop Fill/TATE. Needs an ADR.
- One shader path for all modes (single-pass sharp-bilinear; scale <= 1 uses plain linear). Differs in method (not look) from the art bible's "pre-scale x N then smooth down-scale".
- Bezel drawn at the canvas scale with the same shader; bezel rects = window minus canvas (top/bottom/left/right).
- Auto threshold 85%; Pixel Perfect with n=0 falls back to Fill; no hysteresis; layout is a pure function.
- TATE is manual only (Off / CW / CCW), PC and Switch, whole display rotates, 10 s real-time revert confirm (default focus Cancel); `display_reset` hold 2 s as safety net.
- Safe area used on iOS/Android only; ignored on desktop/Web/Switch.
- Pointer events mapped by the presenter (inverse layout transform) from unhandled input; overlay-consumed touches are not forwarded.
- Bezel: decorative, text only when not Playing and panel >= 48 canvas px, luma caps (avg 40, peak 96, 2 px edge strip <= 20), no bullet hues/shapes, no flash; Art/Plain style option.
- Web: physical pixels only, never CSS pixels; shell background #14110E.
- Windowed default 90% of usable height at 9:16, free resize, min 360x640; fullscreen = borderless; cursor hidden in fullscreen play.
- Tiers: MVP = layout, modes, shader, windowed/fullscreen, Plain bezel; Vertical Slice = settings screen and persistence; Target = bezel art, TATE, safe area, touch hooks.
- Game and menu scenes must live under the SubViewport (custom scene host, not change_scene_to_*).

## 3. Amendments
- `design/gdd/systems-index.md` row 4: status `**Designed** (pending review) — [GDD](display-scaler-and-bezel.md)`; Depends on column `—` becomes `1 (soft), 26 (soft)`. Progress tracker: GDDs written count +1 and add "Display scaler and bezel" to the list; add "Display scaler" to the Foundation-leftovers design order as done.
- `design/art/art-bible.md` §8.1 Base resolution row: replace "`display/window/stretch/mode = viewport`, `aspect = expand`, `scale_mode = integer` by default (unverified names in 4.7)" with "root window stretch disabled; game renders into a 360x640 SubViewport shown by the Display scaler (see design/gdd/display-scaler-and-bezel.md)"; keep the snap rule, applied to the SubViewport.
- `design/art/art-bible.md` §8.1.1 Fill row: "pre-scale x N with nearest, then a smooth down-scale" becomes "one-pass sharp-bilinear shader (display-scaler-and-bezel.md F5), visually equivalent". Safe-areas paragraph: add "phones only".
- `design/art/art-bible.md` §8.9 spike 3: add "SubViewport input forwarding, Web devicePixelRatio, Fill sharpness at 1080p, present-pass cost on REF-PHONE/REF-WEB".
- `design/gdd/game-events-and-session.md` Dependencies, Downstream table: add row "Display scaler and bezel (4) | Soft | Reads session state (Playing or not), era, and `stage_started` for bezel text/tint".
- `docs/project-structure.md`: add `src/display/` (DisplayLayout, DisplayPresenter, sharp_bilinear.gdshader) and `data/display/` (display_params.tres, bezel art per era).
- `project.godot` / `src/` (programmer task, not done): 480x640 to 360x640, stretch mode canvas_items to disabled, portrait on mobile, scene host under SubViewport.
- Future GDDs 20, 22, 26, 28, 31 must list Display scaler and bezel in Dependencies.

## 4. Registry candidates
```yaml
constants:
  - name: canvas_size
    value: "360x640"
    unit: px (fixed canvas on every device; x4 = 1440x2560)
    note: "Locked by art bible 8.1.1; not a tuning knob"
    source: design/gdd/display-scaler-and-bezel.md (Rule 1)
    referenced_by: [display-scaler-and-bezel, art-bible, bullet-manager, bullet-pattern-library]
  - name: auto_fill_min_pct
    value: 85
    unit: percent of limiting screen side
    range: "70-95"
    source: design/gdd/display-scaler-and-bezel.md (F3)
    referenced_by: [display-scaler-and-bezel]
  - name: tate_confirm_seconds
    value: 10
    unit: seconds (real time)
    range: "5-20"
    source: design/gdd/display-scaler-and-bezel.md (Rule 17)
    referenced_by: [display-scaler-and-bezel]
  - name: bezel_feature_min_px
    value: 48
    unit: canvas px
    range: "24-96"
    source: design/gdd/display-scaler-and-bezel.md (Rule 11)
    referenced_by: [display-scaler-and-bezel]
formulas:
  - name: display_scale
    expression: "n = min(We div 360, He div 640); f = min(We/360, He/640); Auto: n if n>=1 and limit_canvas*100 >= auto_fill_min_pct*limit_screen else f"
    variables: [We, He, n, f, auto_fill_min_pct]
    output: "real scale s > 0; INTEGER or FILL"
    source: design/gdd/display-scaler-and-bezel.md (F2, F3)
    referenced_by: [display-scaler-and-bezel, touch-controls]
  - name: window_to_canvas
    expression: "Off (u,v); CW (v, Ws-u); CCW (Hs-v, u); canvas = ((xe-x0)*360/dw, (ye-y0)*640/dh)"
    variables: [u, v, Ws, Hs, x0, y0, dw, dh]
    output: "canvas point; inside iff in [0,360)x[0,640)"
    source: design/gdd/display-scaler-and-bezel.md (F7)
    referenced_by: [display-scaler-and-bezel, touch-controls, menus]
```
Existing entry `play_top`: add `display-scaler-and-bezel` to `referenced_by`.

## 5. Conflicts
- None with locked registry values.
- Soft deviations from the art bible (needs the amendments above): §8.1 specifies Godot built-in stretch (viewport/expand/integer); this GDD replaces it with the SubViewport presenter. §8.1.1 describes Fill as a two-step pre-scale; this GDD uses a one-pass equivalent.
- Current `src/` and `project.godot` are 480x640 and canvas_items; migration is listed as a dependency, not changed.

## 6. Open risks
- Everything about Godot 4.7 is unverified: safe-area API, Web devicePixelRatio and canvas size (physical vs CSS), `push_input` and touch forwarding, snap setting names, fullscreen modes, sRGB look of SubViewport textures in GL Compatibility. A spike must pass before epics; if it fails, fallback loses Fill and TATE.
- Present-pass cost on REF-PHONE and REF-WEB (extra full-screen blit) is a budget proposal (0.5 ms), not measured.
- Scene host under the SubViewport touches scene flow in other systems (ADR needed).
- Mobile-browser address bar can make the canvas jump between x2 and Fill (no debounce by default).
- Bezel luma caps and art are proposals pending art-director.
- Switch export and TATE depend on a third-party port.
