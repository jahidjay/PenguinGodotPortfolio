# GDD Report: Parallax and environment (system 23)

## 1. File written
`design/gdd/parallax-and-environment.md` (Status: Designed, pending review). It defines five background layers (L0 to L4) driven by one integer ground scroll `S` (1/100 px), per-layer accumulators (1/10,000 px), 24 px tile chunks (1,920 px Stage 1, 2,400 px Stage 2), spatial seams for L2/L3 and time crossfades for L0/L1, a static-plate boss arena, a three-zone readability system (EDGE 72 px, SHOULDER 48 px, CORE 120 px) with lintable caps, a grayscale gate procedure, section-by-section environment tables for Stage 1 (1941) and Stage 2 (1970s), ground-target pad corridors, budgets (22.5 MiB VRAM, 8 draw calls, 12 animated sprites), 11 formulas (F1 to F12) and 59 acceptance criteria.

## 2. Key decisions (all auto-approved; change any)
- `S` is an int in 1/100 px, ticked after the Director and before Enemy. `ScrollClock` lives in the Director module so Enemy does not depend on a Presentation system.
- Ground targets follow the live `S` via `ground_dy = (S div 100) - (S_spawn div 100)`, so they never slide on the terrain.
- Layer factors 8 / 25 / 50 / 100 / 130 %; accumulators in 1/10,000 px; no float, no RNG.
- Stage-start ease 60 ticks. Exact golden values: S at `E5` = 1,167,360 (Stage 1), 1,743,960 (Stage 2).
- Chunks: 24 px cells; max 2.0 passes per section; A/B prop dressing by pass parity. Stage 2 uses 2,400 px chunks (1,920 would give 2.20 passes on wave 5).
- Section change: L2/L3 by spatial seam with a 96 px boundary band; L0/L1 by 120-tick crossfade.
- Boss arena: static L2/L3 plates (376 x 656) crossfaded in over 120 ticks at `BOSS_WARNING`; L0/L1 crawl; boss drift 25 confirmed. Grade (modulate 204/196/184) and vignette start at warning + 150 (intro start).
- Parallax renders the boss vignette (and enrage darken, 125 %). VFX band B0 keeps scorch only.
- Zones and caps: edge density per 24x24 window CORE 6 % / SHOULDER 12 % / EDGE 25 %; luma step 28 / 48 / 80; no outline, no dither, no animation in CORE; L4 only inside the edge.
- Colour: luma 16 to 128 (no MVP edge exception), saturation 55 % (HSV), hue lock 225 to 265 degrees above 12 % saturation, warm rule for the 1970s accent (luma 105 or less, edge only, under 2 % of frame).
- Ground pads: corridors x 72 to 150 and 210 to 288 in every section that can host a gunner; pad continuity check (F11).
- Overscan 8 px (strips 376 wide, plates 376 x 656), so VFX shake is capped at 8 px.
- Era shift integration: old set freed at transition tick 53, new set loads after, `era_swap_committed` shows it, `era_ready` starts a 9-step fade-in (85, 76, 66, 57, 47, 38, 28, 19, 9, 0; 4 ticks per step; Parallax-owned overlay at z 105). Env set 22.5 MiB fits the 36 MB budget.
- VFX integration: `set_desaturation(pct)` (clamped at 60, alpha = (pct x 255 + 50) div 100); smoke puffs are weather-class requests to the shared 150 pool (max 12, none at REDUCED/MINIMAL); gulls, haze and cloud shadows are sprites.
- Accessibility integration: `set_background_mode(FULL | DIMMED | PLAIN)` (DIMMED modulate 166 = 65 %, PLAIN flat era Shadow fill, vignette off, eased in steps of 10 points or less during a stage). `set_scroll_scale(pct)` scales L0, L1, L2, L4 only; L3 and ground targets stay on gameplay scroll `S`, so hurtboxes still match pads. Stated limit: terrain under ground targets cannot be slowed.
- Orange warning lights are 8 x 4 px rectangular housings, edge only, 90-tick pulse with luma change 20.6.
- Stage 1 landmarks: lighthouse, dock house, watch tower, gun deck; optional domed silhouette on L1 (cultural review). Stage 2: radar mast, hangar, optional bridge, silos, escort fleet.

## 3. Amendments (apply at wrap-up; full text in the GDD, Dependencies section)
1. `design/gdd/systems-index.md`: row 23 status `**Designed** (pending review) — [GDD](parallax-and-environment.md)`; Depends on `16` becomes `1, 4, 16` (soft: 17, 19, 21, 25, 28); progress tracker adds this GDD.
2. `wave-and-stage-director.md`: (a) Rule 20/F8 add `ScrollClock` with `scroll_pos_x100()`; `scroll_changed(v_x100)` emitted on every integer change and once at `stage_started`; (b) ground enemies follow live `S`, replacing "keeps the speed at spawn" (AC-28 last clause); (c) V2 "layers keep parallax ratios" becomes "L2/L3 replaced by static arena plates, L0/L1 crawl"; (d) V5 boss ids are plate sets, first section loads at `stage_started`; (e) Open Question 5 closed (25 confirmed); (f) Parallax downstream row: GDD exists; (g) validator calls `EnvValidator` V-E1 to V-E5.
3. `enemy-and-ai.md`: Rule 8 `scroll_v` / `STRAIGHT SCROLL` mode becomes the `S` ground anchor; Open Question 5 closed; Parallax row points to this GDD.
4. `display-scaler-and-bezel.md`: Open Question 5 background half closed (overscan 8 px, shake at most 8 px); Parallax row: GDD exists.
5. `design/art/art-bible.md`: 4.5 note on the 1970s Accent saturation (80 % HSV) and the warm rule; 6.4 strips 376 wide, plates 376 x 656; 6.5 zones and limits; 6.9 plates, vignette bands, `boss_rgb`; 8.6 parallax draw calls 8 steady / 10 transient and env VRAM design budget 28 MiB (22.5 planned); 2 grayscale gate procedure.
6. `stage-end-tally.md`: `tally_scroll_pct` is a percent of the speed at tally open (25 x 25 div 100 = 6); grade eases out over 60 ticks; Parallax row: GDD exists.
7. `critical-break.md`: background tint via `Parallax.set_desaturation(pct)` (through VFX), max 60 % (alpha 153), Reduce flashing 25 % (alpha 64).
7a. `era-shift-and-plane-evolution.md`: Parallax row "GDD exists"; `free_set()` at tick 53, `env_prepared` before `era_ready`, fade-in levels and overlay owner.
7b. `vfx-and-screen-feedback.md`: Open Question 5 closed (Parallax renders vignette); remove `fx_boss_vignette`; weather requests from Parallax are T4 and count against 150; shake at most 8 px.
7c. `accessibility-options.md`: Parallax row "GDD exists"; Rule 12 "L0-L5" reads "L0-L4 plus plates and props"; `set_scroll_scale` affects decorative layers only (limit noted).
8. `boss-and-boss-parts.md`: vignette driven by Parallax at `warning_started` + 150; Parallax row: GDD exists.
10. `coop-and-team-chain.md`: Parallax row, no change at any N; team background pulse stays off.
12. `design/registry/entities.yaml`: add the entries below; add `parallax-and-environment` to `referenced_by` of `canvas_size` and `play_top`.

## 4. Registry candidates
```yaml
  - name: parallax_factor_pct
    value: "L0 8 / L1 25 / L2 50 / L3 100 / L4 130"
    unit: percent of ground scroll
    note: "L3 = 100 so L3 offset = S div 100 (ground sync)"
    source: design/gdd/parallax-and-environment.md (Rule 6, F2)
    referenced_by: [parallax-and-environment, wave-and-stage-director, enemy-and-ai]
  - name: bg_zone_px
    value: "EDGE 0-71 / 288-359; SHOULDER 72-119 / 240-287; CORE 120-239"
    unit: canvas px
    source: design/gdd/parallax-and-environment.md (Rule 15)
    referenced_by: [parallax-and-environment, accessibility-options]
  - name: bg_overscan_px
    value: 8
    unit: canvas px (shake cap for world layers)
    range: "4-16"
    source: design/gdd/parallax-and-environment.md (Rule 26)
    referenced_by: [parallax-and-environment, vfx-and-screen-feedback, display-scaler-and-bezel]
  - name: boss_plate_blend_ticks
    value: 120
    unit: ticks
    range: "60-180"
    source: design/gdd/parallax-and-environment.md (Rule 19, F5)
    referenced_by: [parallax-and-environment]
  - name: boss_grade_ticks
    value: 90
    unit: ticks
    range: "60-120"
    note: "boss_rgb 204/196/184; vignette outer alpha 102 of 255"
    source: design/gdd/parallax-and-environment.md (Rule 20, F6, F7)
    referenced_by: [parallax-and-environment, boss-and-boss-parts]
  - name: env_vram_budget_mib
    value: 28
    unit: MiB (planned 22.5)
    range: "20-36"
    source: design/gdd/parallax-and-environment.md (F10)
    referenced_by: [parallax-and-environment, era-shift-and-plane-evolution]
  - name: stage_fade_levels
    value: "85,76,66,57,47,38,28,19,9,0 (4 ticks per step)"
    unit: percent dim
    note: "9 steps of at most 10 points; Era shift F5"
    source: design/gdd/parallax-and-environment.md (Rule 28a)
    referenced_by: [parallax-and-environment, era-shift-and-plane-evolution]
  # formulas
  - name: ground_anchor_dy
    expression: "(S_now div 100) - (S_spawn div 100)"
    variables: [S_now, S_spawn]
    output: "int px; equals the L3 offset change since spawn"
    source: design/gdd/parallax-and-environment.md (F4)
    referenced_by: [parallax-and-environment, enemy-and-ai, vfx-and-screen-feedback]
  - name: layer_draw_offset
    expression: "A_L += (v_eff * f_L * k_L) div 100 (mod loop*10000); draw = A_L div 10000"
    variables: [v_eff, f_L, k_L, loop_L]
    output: "int px; L3 draw = S div 100"
    source: design/gdd/parallax-and-environment.md (F2)
    referenced_by: [parallax-and-environment]
```
Existing entries to extend: `canvas_size`, `play_top` (add `parallax-and-environment`).

## 5. Conflicts
- Art bible 4.5 says backgrounds are 55 % saturation or less; the 1970s Accent `#A85A22` measures 79.8 % HSV (and hue 25 degrees, close to Tracer Orange). Resolved by the warm rule; needs art director confirmation.
- Director F8/AC-28 freezes ground speed at spawn; that cannot stay locked to terrain across scroll blends. Needs Enemy/Director change (Amendments 2b, 3).
- Director V2 ("layers keep ratios") vs art bible 6.9 ("mid and near stop first"): resolved with static plates.
- Art bible 6.4 (strips 360 wide) vs 8 px overscan: strips become 376 wide.
- Art bible 8.6 parallax draw calls 5 to 8 vs 10 transient during crossfade.
- Boss GDD says the vignette eases at intro; Director V5 lists the boss section at warning: reconciled (plates at warning, grade and vignette at warning + 150).
- Locked registry values: no conflict.

## 6. Open risks
- Godot 4.7 unverified: `TileMapLayer` data assignment cost, tile animation, pixel snap, Web loading without threads (spike).
- Seam pops where old props are cut by the boundary band; may need a short alpha overlap.
- Parked jets in the airbase could read as enemy jets; the optional bridge sits in the lane.
- Reduce motion cannot slow the L3 terrain without changing gameplay speed.
- 3 to 4P HUD strip (72 px) hides the top of the Stage 2 sodium horizon.
- Cultural review is needed for the lighthouse, dock house, dome silhouette and fleet landmarks.
- Zone caps (6 / 12 / 25 %, 28 / 48 / 80) are proposals until the grayscale gate and playtest.
- Stages 3 and 4 are not designed here.
