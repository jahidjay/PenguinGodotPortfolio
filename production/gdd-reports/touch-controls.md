# Report: Touch controls (system 31) — saved by main session

The agent could not write this file; full amendment list is in `design/gdd/touch-controls.md` → Dependencies → "Amendments to other docs".

## Key amendments (summary)
- systems-index row 31: Designed — [GDD](touch-controls.md); Depends on 2, 4, 5; remove "touch controls UX spec" from open items.
- input-and-player-mapping: Rule 2 TOUCH = GDD link, slot 0 only, solo only; Rule 13 SlotInput adds `drag` (Vector2i, 1/16 px), `drag_active`, `fire_auto`; Rule 3/F7 START GAME tap binds TOUCH to slot 0 on touch platforms; close OQ7; OQ10 → touch haptics in touch-controls Rule 32.
- player-plane: add PF8 Touch leash; Rule 4.2 `fire_auto` pulses are not a Fire hold (no focus speed); Rule 9 read `drag`; Rule 10 clear `pending` on non-Active ticks; close OQ6.
- display-scaler-and-bezel: with touch active, effective area = safe rect minus `touch_strip_px`; `get_layout()` adds `touch_strip_rect`; replace the 50 % corner-button exception with "nothing in W3 covers the canvas"; close OQ8.
- save-settings-high-scores: `board_id` gets `/touch` suffix (solo only, one extra board per plane); register `touch.*` keys (scheme, autofire, hand, one_hand, sens, button_scale, haptics, hints_seen).
- menus-title-plane-select: Rule 9 touch platforms bind TOUCH on START GAME tap; touch targets ≥ 9 mm (TF7) instead of 24 px; add `touch_solo` toast, landscape prompt, Touch section in Controls, first-run hints; OQ11 partly resolved.
- hud: close OQ13 (Pause is in the strip); Touch dependency row → GDD.
- accessibility-options: Touch row lists one-hand/hand/scale/sens/haptics; add "Touch: one hand" preset.
- plane-kits-lancer-leech Rule 5: touch auto-fire relies on the 12-tick linger; kit publishes `drone_state`.
- game-concept §13: touch risk mitigation updated. art-bible: touch glyphs §7.6, §3.5 note, §8.1.1 strip reserve note.
- ADR-0001 tick step 1 + docs/project-structure.md: `src/input/touch/`, `data/input/touch_rules.tres`; touch-to-mouse emulation setting needs an ADR.
- localization: `touch.*` and `opt.touch_*` keys.

## Registry candidates
```yaml
  - name: touch_target_min_mm
    value: 9
    unit: mm (smallest visual target; hit areas >= 12 mm)
    range: "locked"
    source: design/gdd/touch-controls.md (Rule 7, TF7)
    referenced_by: [touch-controls, menus-title-plane-select]
  - name: touch_strip_mm
    value: "15 (3 + 12 x s_btn); buttons Hold 12, Drone 11, Bomb 12, Pause 9; hit_pad 1.5"
    unit: mm
    range: "13-17"
    source: design/gdd/touch-controls.md (TF2)
    referenced_by: [touch-controls, display-scaler-and-bezel]
  - name: touch_leash_px
    value: 12
    unit: px (pending drag stored by the plane; 1/16 px fixed point)
    range: "8-32"
    source: design/gdd/touch-controls.md (TF4)
    referenced_by: [touch-controls, player-plane]
  - name: touch_autofire_period
    value: 10
    unit: ticks (must be <= shot_linger_ticks)
    range: "6-12"
    source: design/gdd/touch-controls.md (TF6)
    referenced_by: [touch-controls, plane-kits-lancer-leech]
formulas:
  - name: touch_drag_delta
    expression: "drag = round_half_away(window_motion * (360/dw) * sens * 16), jitter-filtered by drag_min_mm"
    variables: [window_motion, dw, sens, drag_min_mm]
    output: "Vector2i, 1/16 canvas px"
    source: design/gdd/touch-controls.md (TF3)
    referenced_by: [touch-controls, player-plane, input-and-player-mapping]
  - name: touch_leash_step
    expression: "pending' = clamp_len(pending + drag, leash*16); step = clamp_len(pending', v*16/60); pending = pending' - step; blocked axis -> 0"
    variables: [pending, drag, leash_px, v]
    output: "|step| <= 56 units at move_speed"
    source: design/gdd/touch-controls.md (TF4)
    referenced_by: [touch-controls, player-plane]
  - name: touch_strip_px
    expression: "s_btn = clamp((W_mm-20)/41, 0.82, s_user); strip_px = round((3 + 12*s_btn) * ppmm)"
    variables: [W_mm, s_user, ppmm]
    output: "int px (e.g. 270 on 1125x2436 at 458 dpi)"
    source: design/gdd/touch-controls.md (TF2)
    referenced_by: [touch-controls, display-scaler-and-bezel]
  - name: min_touch_target_canvas_px
    expression: "ceil(9 * ppmm / s)"
    variables: [ppmm, s]
    output: "55 at x3 / 458 dpi"
    source: design/gdd/touch-controls.md (TF7)
    referenced_by: [touch-controls, menus-title-plane-select]
```
Existing entries gaining `touch-controls` in referenced_by: move_speed, focus_speed, lancer_ability_speed, charge_hold_ticks, shot_linger_ticks, buffer_ticks, canvas_size, press_edge, board_id (output note: plus /touch solo boards).
