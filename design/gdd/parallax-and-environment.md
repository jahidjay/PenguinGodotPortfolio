# Parallax and Environment

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (art-director) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos, History Accelerates (also Every Hit Counts: ground targets sit on a scroll the player can trust)

## Overview

**The data layer:** the **Parallax and environment** system draws the world behind the action. It has five background layers (L0 sky, L1 far, L2 mid, L3 near, L4 overhead) that scroll downward at fixed fractions of one shared **ground scroll**. The ground scroll is a single integer, `S`, counted in 1/100 px and advanced once per 60 Hz tick from the speed the Wave and stage director (16) sets for each wave. Every layer, every ground target and every scorch mark reads `S`, so they all move together and never drift apart. The world is cut into **sections**, one per wave plus one boss arena. A section is a bundle of data (`data/environment/sections/<section_id>.tres`): which strips, tile chunks, props and landmarks to show, where the ground-target pads are, and how much wreckage to add. The Director switches sections on state triggers (`WAVE_START(n)`, `BOSS_WARNING`), never on absolute ticks. The system owns the **readability rules for backgrounds** (luma and saturation caps, a three-zone detail limit across the screen width, hue lock, and the grayscale gate) as numbers a lint tool can check. It draws nothing in the play field that can hurt, block or be mistaken for a bullet. It runs on integers only (ADR-0001): no `delta`, no RNG, `RefCounted` logic classes with `tick()`, all values in `.tres`.

**The player impact:** the player feels a place, not a wallpaper. Stage 1 is a sunlit coast with a lighthouse, a harbour and a gun-deck fortress. Stage 2 is a hard steel-grey sky over radar masts, missile silos, runway grids and a carrier fleet, with a few orange warning lights at the edges. The background is rich at the screen edges and calm in the middle, so every bullet reads even in a grayscale screenshot (**Readable Chaos**). The terrain changes with each wave, and the whole look moves one era forward in Stage 2 (**History Accelerates**). Ground targets ride the scroll exactly, so a gunboat or flak nest sits on its pad and does not slide. At the boss, the world slows to a near stop, the edges darken and the Fortress or Jet Carrier owns the top of the screen.

## Player Fantasy

**Anchor moment: "the sea is just sea."** The player is deep in a bullet curtain. Behind it the water barely moves, a lighthouse slides past on the left, and the middle of the screen is calm green-grey. Every blue bullet stands out like ink on paper. They never think about the background. Later they stop at a screenshot of wave 3 and notice the moored fleet, the brick dock and the palms, and realise how much was there.

- **The world is a diorama of one place over a century.** The same river and coast appear in 1941 and in the 1970s, changed (art bible 6.1).
- **Quiet lanes, loud edges.** Detail lives at the sides. The middle 120 px is the calmest part of the screen.
- **Ground targets are on the ground.** They scroll with the terrain and never skate over it.
- **Time shows in the scenery.** Pastoral sun gives way to industrial steel (art bible principle 3).
- **The boss gets the stage.** The scroll eases down, the edges darken, and the landmark stands damaged behind the boss.
- **Wreckage accumulates.** Wave 1 is clean. By the boss, the edges show burned hulls and craters. The cost is visible without a single casualty on screen.

**Anti-fantasy (must never happen):** a background pattern that looks like a bullet field; a bright, small, round shape in the middle lane; a ground target that slides over the terrain; scenery that shimmers or flickers at 1 px steps; a parallax pop when a wave changes; the boss losing the top third to scenery; any flash that is not Critical Break.

Reference feel: Metal Slug and Ganryu detail at the edges; DoDonPachi's flat, dark backgrounds behind dense patterns.

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

**Scope and ownership**

1. **Presentation only, one exception.** Layers, sections, grades, vignette and props never change gameplay. The one gameplay-visible output is the **ground scroll `S`** and the **ground anchor** (Rule 5). Everything else may differ between machines without affecting a run. Both are deterministic: the same `scroll_changed` sequence gives the same `S` and the same layer offsets on every run.
2. **Classes.** `ScrollClock` (integrates `S`; lives in the Wave director module so Enemy can read it without depending on a Presentation system, → Amendment 2), `ParallaxState` (pure integer maths: layer accumulators, fades, grades), `ParallaxView` (Node: moves sprites and tile layers from `ParallaxState`, no logic), `EnvLint` (offline art checks), `EnvValidator` (data checks). Logic classes are node-free `RefCounted` with `tick()` (ADR-0001).

**Scroll model**

3. **`S` is an int in 1/100 px.** Each unpaused tick, `S += v_eff`, where `v_eff` is the Director's `scroll_v_x100` (F1). `ScrollClock.tick()` runs after `StageDirector.tick()` (step 3a) and **before** `EnemyManager.tick()`, so ground enemies read this tick's `S`. It keeps ticking while every slot is Dead or in Continue (enemies and ground keep moving; only the Director's clock stops). It does not tick while paused.
4. **Stage-start ease.** For the first `stage_ease_ticks` (60) ticks after `stage_started`, `v_eff = (v x t) div 60`. The scenery eases in; nothing spawns in this window because the lead-in is 120 ticks. After that `v_eff = v`.
5. **Ground anchor.** A ground object (a `GROUND` enemy, a scorch decal, an on-ground prop) stores `S_spawn = S` at creation. Its screen y each tick is `y_start + ground_dy`, where `ground_dy = (S div 100) - (S_spawn div 100)` (F4). L3 draws at `S div 100`, so a ground object and L3 terrain step on the same ticks by the same pixels. Enemy keeps its float hurtbox for hits; the drawn y is the integer anchor. They differ by at most 1 px.
6. **Layer factors** (art bible 6.5). Each layer has an integer `factor_pct`. It keeps its own accumulator `A` in 1/10,000 px: `A += v_eff x factor_pct`, wrapped at `loop_px x 10,000`. Draw offset is `A div 10,000`. No float, no remainder bookkeeping, no drift (F2).

| Layer | Name | `factor_pct` | Loop (px) | Draw layer (art bible 6.8) | May scroll | May animate |
|---|---|---|---|---|---|---|
| L0 | Sky | 8 | 1,280 | 1 (back-most) | yes (crawl) | slow cloud drift only (it is the scroll) |
| L1 | Far | 25 | 1,280 | 1 | yes | no |
| L2 | Mid | 50 | chunk 1,920 (S1) / 2,400 (S2) | 1 | yes | water shimmer tile frames, boats, smoke |
| L3 | Near | 100 | chunk 1,920 (S1) / 2,400 (S2) | 1 | yes | props, radar dish, warning lights |
| L4 | Overhead (optional) | 130 | none (sprite set) | 1 (top of the background; below layer 2) | yes | yes |
| (GT) | Ground-target layer | 100 (via Rule 5) | n/a | 3 | with L3 | owned by Enemy (10) |
| (FX) | Env FX, scorch (VFX), boss vignette (Parallax), desaturation tint (Parallax) | 100 for decals | n/a | 2 (z 20 to 22) | decals only | VFX (25) |

   Exactly four main layers plus L4. No more layers are added. L4 is drawn above L3 but **below** layer 2, 3 and everything above them, so it can never cover a ground target, an enemy or a bullet.

**Tiles, chunks and loops**

7. **Cell and chunk.** L2 and L3 terrain is a `TileMapLayer` of **24 x 24 px** cells (art bible 6.4), 17 columns wide (408 px: 24 px overscan each side). A **chunk** is `chunk_rows x 24` px tall: Stage 1 **80 rows = 1,920 px**, Stage 2 **100 rows = 2,400 px**. Tile data is assigned from a prebuilt `PackedByteArray` per chunk (no per-cell calls at runtime; *unverified on 4.7, → spike*).
8. **Chunk pool.** Each of L2 and L3 holds at most **3** live chunk instances (the one leaving, the one on screen, the one queued above). When a chunk's top edge enters the screen, the next copy (same section) is placed above it.
9. **Passes and dressing.** One pass is one chunk traveling through the screen. A section must not need more than **2.0 passes** of L3 at nominal speed (F3, validator V-E2). Each section has two prop **dressings**, A and B (placement lists in data). Pass 1 uses A, pass 2 uses B, pass 3 uses A again. Dressing is chosen by pass parity, never by RNG. L2 has one dressing and fewer than 1.0 pass in every MVP section.
10. **Prop placement.** Props are placed from `PropPlacement` rows in the section data: `y_in_chunk` (px), `x` (px), `sprite_id`, `dressing` (A, B or BOTH), `anim_id`. They are pooled `Sprite2D` nodes, at most **40 live**. A prop's zone is checked by its sprite box (Rule 15). No RNG anywhere.

**Sections and transitions**

11. **Section data.** A `BgSectionDef`: `section_id`, `l0_strip`, `l1_strip`, `l2_chunk`, `l3_chunk`, `l4_set`, `prop_dressings`, `landmark`, `edge_ed_cap`, `wreck_level`, `pad_class` (`NONE` or `PAD`), `palette_id`, and `cap_rows` (Rule 13). The Director's `bg_sections[]` entries (`trigger`, `section_id`, `blend_ticks`) point at these.
12. **Triggers.** `stage_started` loads and shows the wave 1 section (so the lead-in has scenery). `WAVE_START(n)` selects section `n` (for n = 1 this is a no-op). `BOSS_WARNING` selects the boss arena (Rule 17). The Director fires them by state, so an early clear moves a section change earlier with its wave.
13. **L2 / L3 changes are spatial (a seam).** On the trigger tick the new chunk is placed with its **leading (bottom) edge at y = 0**, and scrolls in from the top. Everything above that edge is the new section; what is below stays the old section until it scrolls off. The first `cap_rows` rows (default 4 = 96 px) of every chunk are a **boundary band**: a full-width, opaque, natural edge (a shoreline, breakwater, road, ditch, river junction) with an in-lane luma step of at most 28. Old props cut by the seam are hidden behind the band; there is no crossfade and no double image on L2 / L3.
14. **L0 / L1 changes are time crossfades.** The incoming strip fades in over `blend_ticks` (default 120) with an integer alpha: `alpha = (255 x min(t, B)) div B` (F5). The outgoing strip is freed when the alpha reaches 255. A trigger that arrives during a blend completes the running blend at once (alpha 255), then starts the new one. L4 sets swap at the trigger tick: old sprites finish scrolling off, new ones enter from the top.

**Zones and readability (the quiet lane, made testable)**

15. **Three zones across the 360 px width.** The art bible's central lane (about the middle 60 %) is split in two so the middle 120 px can be made calmest.

| Zone | x range (canvas px) | Width | Role |
|---|---|---|---|
| EDGE | 0 to 71 and 288 to 359 | 72 each | Detail lives here |
| SHOULDER | 72 to 119 and 240 to 287 | 48 each | Soft detail |
| CORE | 120 to 239 | 120 | The calm middle |

   A sprite's zone is the zone of its **box**; a sprite that crosses a zone line is held to the stricter zone's rules.

16. **Zone limits** (checked by `EnvLint` on every exported strip, chunk render and plate; `ED` and `dL` are F8 and F9).

| Rule | CORE | SHOULDER | EDGE |
|---|---|---|---|
| Edge density `ED` per 24 x 24 window | at most 6 % | at most 12 % | at most `edge_ed_cap` (default 25 %) |
| Luma step between adjacent regions `dL` | at most 28 | at most 48 | at most 80 |
| Smallest region with `dL` above 8 | 24 x 24 px | 4 x 4 px | 2 x 2 px |
| Tinted texture clusters (`dL` 8 or less) | 2 x 2 px minimum | 2 x 2 px minimum | 2 x 2 px minimum |
| Outline of any kind | none | none | darker same-hue tone only (luma 16 or more, never Ink) |
| Ordered dither | banned | banned | allowed (2x2 or 4x4) |
| Animated sprites | 0 | at most 4 (shared with core) | within the global budget (Rule 22) |
| L4 sprites | banned | banned | allowed, box fully inside the edge |

   Single isolated pixels are banned in every zone (a region must be 4 px or larger, or part of a 2 x 2 cluster).

17. **Colour rules** (art bible 4.2, 4.3, 4.5, 6.3). Every env pixel must satisfy all of:
    a. Luma (Rec.709 on gamma values) between **16 and 128**. MVP eras have no edge exception (the 160 allowance is for 2030s neon only).
    b. HSV saturation at most **55 %**, except era **Accent** entries (at most 80 %) used under the warm rule (c).
    c. **Warm rule.** A pixel with hue 10 to 50 degrees and saturation above 55 % must have luma at most 105, must lie in an EDGE zone, and all such pixels together must be at most 2 % of the 360 x 640 frame. (This keeps the 1970s orange lights apart from Tracer Orange `#FF8A1F`, luma 155, saturation 88 %.)
    d. **Hue lock.** No pixel with hue 225 to 265 degrees and saturation above 12 %. (Bullet fills are locked to 225 to 265 degrees; steel-grey skies at 205 to 224 degrees and low saturation pass.)
    e. Uses only the era's palette entries plus at most 2 ramp steps per layer (art bible 8.4). Never Ink `#0B0B2A`, never the enemy outline colours, never Void Indigo `#4A5CFF`.

18. **Grayscale gate** (art bible 2 and 6.10). Every section, plus every arena plate set, must pass this before its mood treatment is approved:
    1. Render the section with no HUD at three scroll phases (first third, middle, last third of a chunk pass).
    2. **Automated:** `EnvLint` runs Rule 16 and 17 on each render, then places the four bullet sprites (orb, rice, needle, ring) at **12 probe points** (x 60, 180, 300; y 140, 260, 380, 500). For each probe, take the 4 px ring around the sprite box. It passes if `217 - bg_max >= 89` (bullet core minus the brightest background pixel) and the window luma range (max minus min) is at most 28 (CORE), 48 (SHOULDER) or 80 (EDGE).
    3. **Manual:** convert the render and a 300-bullet pattern-bench capture to Rec.709 grayscale; two reviewers count the bullets in marked 100 x 100 px regions (same as Bullet manager AC-45). Pass: every bullet is counted and reads as a dark-outlined shape.
    4. Save evidence to `production/qa/evidence/bg_gate_<section_id>_<phase>.png`. A failed section is simplified (lower contrast, merged shapes), never the bullet.
    5. **Accessibility modes.** Repeat step 2 for DIMMED (`bg_max` becomes `(bg_max x 166) div 255`) and PLAIN (flat Shadow, luma 51.1 / 46.4) on all 12 sections, and step 3 on the busiest 4P capture of each era in each mode (Accessibility Rule 37).

**Boss arena and tally**

19. **Boss arena plates.** On `BOSS_WARNING` (`E5 + 90`; the field is already clear, Director Rule 23) the arena replaces L2 and L3 with two **static plates** (376 x 656 px, no scroll) crossfaded in over `plate_blend_ticks` (120) with `alpha = (255 x min(t,120)) div 120`. L0 and L1 crossfade to their boss strips over the same 120 ticks and then keep crawling at their factors (L0 8 %, L1 25 %). When the plates reach alpha 255 (`E5 + 210`), the old L2 / L3 chunks and the old strips are hidden and freed. The plates therefore stop first and the far layers crawl (art bible 6.9). The L2 plate holds the stage **landmark in damaged form** in the upper third behind the boss; the L3 plate holds the framing edges (broken walls, hulls). The CORE of both plates is the flattest area of the stage.
20. **Boss grade.** `warning_ticks` (150, from `warning_started`) after the warning, i.e. at `E5 + 240` when the boss intro and the scroll-stop start, the **grade** eases in over `grade_ticks` (90): L0 to L3 and both plates are modulated by `boss_rgb = (204, 196, 184)` (about 77 % luma, warmer), and the **vignette** sprite (layer 2, Shadow colour, no Ink) fades to full. The vignette is zero across x 72 to 287 and rises in 6 bands of 12 px to alpha 102 of 255 (40 %) at the screen edge (F7). The sky keeps its era colour; the grade is a darkening, not a new palette. No dither (the bands are flat).
21. **Boss scroll.** The Director eases `v` from the wave 5 speed to `boss_scroll_v_x100` (25) over 60 ticks at `E5 + 240`. **Decision: 25 is confirmed** (closes Director Open Question 5). Because L2 / L3 are static plates, only L0 (0.02 px/tick) and L1 (0.0625 px/tick) crawl. The `ParallaxState` never reads the boss; it needs no Boss call.
22. **Tally.** On `tally_started` the grade eases out over `tally_grade_ticks` (60) and the scroll becomes `tally_scroll_pct` (25) % of the speed at tally open (25 x 25 div 100 = 6, i.e. 0.06 px/tick; closes the ambiguity in Tally). No other change. Results, Game over and Menus draw their own backdrops (Menus 22).

**Environment budgets**

23. **Animated props.** At most **12** animated sprites on screen at once, **0** in CORE, at most **4** in SHOULDER + CORE together, and at most **1** "fast" animation (6 fps or faster) visible between x 72 and x 287 at a time (art bible 6.5 motion rule). Props run at 6 fps or slower (10 ticks per frame). Tile water shimmer is 4 frames at 30 ticks per frame with a luma change of at most 8 between frames. Orange warning lights pulse on a 90-tick cycle (45 + 45) between the Accent and an 80 % ramp step (luma change 20.6, at most 24); never above 1 Hz.
24. **Env particles share the 150 cap.** Parallax owns **no particle pool**. Environment smoke puffs (chimneys, silos, burning hulls) are requested from VFX (25) as ambient weather-class effects (tier T4, VFX Rule 16 to 19), so each live puff counts against the shared `vfx_particle_cap` of **150** and is the first to be evicted. Parallax asks for at most **12** at once (VFX weather class cap is 40). 2 x 2 px minimum, effects atlas, drawn at layer 2. When VFX effects level is REDUCED or MINIMAL, VFX allows no weather, so Parallax requests none (the scenery still works without them). Rain is not used in MVP; if added later it counts against the same 40. Gull flocks, haze bands and cloud shadows are **sprites** (L0 / L4), not pooled particles. Scorch decals are drawn by VFX (decal pool of 16); Parallax only supplies the ground anchor.
25. **Wreckage accumulates** (art bible 6.7). Each section has `wreck_level`: the count of burned hulls and craters in its edge dressing, at most 8 per chunk: Stage 1 `0 / 2 / 4 / 6 / 8`, Stage 2 `0 / 0 / 3 / 6 / 8`, boss plates 8 or more baked in. All wreckage sits in SHOULDER or EDGE.
26. **Overscan.** Strips, plates and tile layers are authored with 8 px of overscan on every side (strips 376 px wide, plates 376 x 656, tile layers 17 columns), so a world-layer screen shake of up to **8 px** never shows an empty strip (closes Display scaler Open Question 5 for the background; VFX (25) must cap the shake at 8 px).
27. **Loading and the era swap** (Era shift 19, Rules 19, 20, 23, 28). The whole stage environment set (about 22.5 MiB, F10; the Era shift budget for one `env` set is 36 MB, so it fits) is never streamed mid-stage. The Tally keeps the old set (arena plates) on screen until the era transition card covers the canvas. Then, driven by Era shift:
    a. **Transition tick 53:** Era shift calls `Parallax.free_set()`. The old set is freed (the canvas is covered) and only then does `Parallax.prepare(stage_id)` start, at most one resource per tick (≤ 30 ticks, so it ends before tick 90). Old and new sets are never in memory together.
    b. **Transition tick 90, `era_swap_committed(era_index)`:** the new set is shown at rest on section 1 (hidden behind the card), with the new era's palette and strips. The swap needs only one tick, because every resource is already loaded. If the set is not loaded yet, `era_ready` is delayed by Era shift (its Rule 23); Parallax keeps drawing nothing but the card.
    c. **First stage of a run:** Era shift runs the same staged load on `run_started`; Parallax has no other loader path.
    d. On Web, threaded loading is not assumed (*unverified on 4.7*).
    e. `env_prepared(stage_id)` is emitted when loading ends; Era shift must not emit `era_ready` before it.
28a. **Stage fade-in** (Era shift Rule 28, F5 there). When the card releases, `era_ready` starts a fade-in from the 85 % dim. Parallax owns the fade overlay: a flat Cabinet Char `#1E1B18` sprite over the whole canvas at z 105 (below the HUD, above the play field; the field is clear and no bullets exist, Director Rule 23). Levels are integers in percent: **85, 76, 66, 57, 47, 38, 28, 19, 9, 0**. That is **9 steps**, each of at most **10** points, all in one direction (brighter), one step every `fade_step_ticks` (4), so the fade lasts 36 ticks. The overlay is never used to darken again inside 60 ticks (the dim phase ended at least 170 ticks earlier). The stage-start ease (Rule 4) runs under it. Stage 1 at the start of a run uses the same fade from the card (Era shift staged load).
28. **Co-op and 4P.** No change at any `N`. Backgrounds draw the full canvas under the HUD strip (48 or 72 px); the strip covers it. Pads, props and caps are the same.
29. **Accessibility API** (Accessibility options 28, `access.background`, `access.reduce_motion`; this rule defines the contract and Accessibility Rules 10 and 12 use it, 2026-11-03 wave 3b: Reduce motion calls `set_scroll_scale(50)`).
    a. **`set_background_mode(FULL | DIMMED | PLAIN)`**, default FULL. It affects environment drawing only, never enemies, bullets, planes, shots, items, ground targets, scorch or the HUD.
       - **DIMMED:** every environment node (L0 to L4, tile chunks, props, landmarks, arena plates) is modulated by `dim = (255 x bg_dim_pct + 50) div 100 = 166` per channel (65 %, F12). It combines with the boss grade by multiplication (`m_c = (grade_c x dim) div 255`). The vignette and the desaturation tint are not dimmed further.
       - **PLAIN:** all environment nodes are hidden and a single flat sprite (360 x 640, z 10) filled with the era **Shadow** colour (1941 `#2E3626`, 1970s `#2A2F36`, luma 51.1 / 46.4; hue 90 / 215 degrees, never a bullet hue) is shown. The boss vignette is hidden. The desaturation tint and the stage fade-in overlay still work. `ParallaxState` keeps ticking (so returning to FULL shows the right scroll), but `ParallaxView` skips its updates in PLAIN.
       - **Switching during a stage** eases in steps of at most 10 percentage points every `mode_step_ticks` (8): DIMMED goes 100, 90, 80, 70, 65 (%); PLAIN fades the fill in at 10 % alpha steps. Outside a stage (menus, pause) it snaps. This keeps the change inside Era shift's F5 brightness-step rule.
       - Both modes must pass the grayscale gate (Rule 18, step 5).
    b. **`set_scroll_scale(pct)`**, `pct` an int 0 to 100, default 100 (Reduce motion sets a lower value; Accessibility owns the number). It scales the **presentation scroll of the decorative layers only**: L0, L1, L2 and L4 (F2: `k_L = pct`). **L3 and the ground anchor stay at 100 %**, because ground-target hurtboxes follow the gameplay scroll `S` and must sit exactly on their pads (Rule 5, F4). `S` and every gameplay position are unchanged by this call. A value below 100 also hides L4, freezes prop animation on frame 0 and stops tile shimmer. Changing the value mid-stage changes the rate from that tick, so there is no jump. Stated limit: the terrain under the ground targets (L3) keeps moving at gameplay speed. Slowing that would need a change to the gameplay scroll itself (the Director, or Accessibility `game_speed_pct`), which is out of scope here.
30. **Critical Break desaturation.** CB (17) / VFX (25) call `Parallax.set_desaturation(pct)` each tick of the tint (`pct` is an int 0 to 100; Parallax clamps it to `bg_tint_max` 60). The tint is a flat colour sprite (the era **Sky** colour) at layer 2 (z 21), below enemies and bullets, with `alpha = (pct x 255 + 50) div 100` (60 % gives 153, 25 % gives 64). The ramp shape belongs to Critical Break (in 6, hold 18, out 12; Reduce flashing: in 18, maximum 25 %). Sky luma is at most 128, so the tinted background stays inside the band. It never reaches layer 4 or above.

**Boss vignette owner**

30a. **Parallax renders the boss vignette** (closes VFX Open Question 5). Parallax owns the whole boss darkening (the grade on L0 to L3 and plates, and the vignette sprite) so the luma floor of 16 and the CORE-untouched rule are enforced in one place. The vignette is a single sprite at layer 2 (z 20, VFX band B0) and costs 0 pooled particles. VFX band B0 keeps only scorch decals. On `BOSS_ENRAGED` (the Director's cue) the bands scale to `enrage_vignette_pct` (125 %, alpha capped at 127) over 60 ticks; VFX does not draw it.

**Ground-target pads**

31. **Pads.** Any section that can host a `gunner` (ground target) has `pad_class = PAD`: two vertical corridors, **x 72 to 150** and **x 210 to 288**, where the terrain is a large flat shape (sand, quay, concrete apron, escort deck) for the full chunk height. The gunner's authored origins (x 110 and x 250) sit inside them. A section without pads must not have a gunner alive in it: for every `gunner` event, `spawn_tick + ground_life <= next_section_start` unless the next section also has pads (F11, validator V-E5). A gunner alive blocks an early clear, so the nominal wave end is the worst case.

### States and Transitions

| State | Meaning | Layers | → Next | Trigger |
|---|---|---|---|---|
| Unloaded | no stage set (old set freed at transition tick 53) | none | Preparing | `prepare(stage_id)` from Era shift, right after `free_set()` |
| Preparing | loading one resource per tick | none | Ready | all resources loaded (`env_prepared`) |
| Ready | set loaded; shown at rest from `era_swap_committed` (tick 90); fade-in from `era_ready` (tick 201, 36 ticks) | section 1 at rest | Stage(1) | `stage_started` (stage ease starts) |
| Stage(n), n = 1 to 5 | normal scroll; sections switch spatially (L2 / L3) and by crossfade (L0 / L1) | L0 to L4 | Stage(n+1) / BossPlates | `WAVE_START(n+1)` / `BOSS_WARNING` |
| BossPlates | plates and boss strips crossfade (120 ticks), field clear | L0, L1, plates | BossGrade | `warning_started` + `warning_ticks` (150) |
| BossGrade | darken and vignette ease in (90 ticks) | L0, L1, plates, vignette | BossHold | 90 ticks |
| BossHold | arena static, crawl only | as above | TallyCalm | `tally_started` |
| TallyCalm | grade eases out (60), scroll 25 % | L0, L1, plates | Unloaded | Era shift `free_set()` at transition tick 53 (the card covers the canvas) |

`set_desaturation`, `set_background_mode` and `set_scroll_scale` can apply in any Stage / Boss state. Tally and the era transition (Rule 27): the old set stays through TallyCalm and is freed at transition tick 53 (state Unloaded), `prepare` runs until `env_prepared`, `era_swap_committed` shows section 1 (state Ready), `era_ready` starts the 36-tick stage fade-in (Rule 28a). Paused: no state changes. Continue / all slots Dead: `ScrollClock` and layers keep running. Debug `skip_wave` jumps to the section of the new wave without a crossfade (snap, Rule 14).

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Wave and stage director (16) — GDD | ← | `scroll_changed(v_x100)` (on every integer change, and once at `stage_started`), `bg_sections[]` triggers, `stage_started`, `wave_started`, `warning_started(ticks)`, `stage_cleared`. `ScrollClock` lives with the Director |
| Enemy and AI (10) — GDD | ← | GROUND targets read `S` for their anchor (Rule 5); Parallax reads nothing from Enemy. Enemy draws ground targets at layer 3 and ground explosions at layer 2 |
| Boss and boss parts (14) — GDD | — | No calls. The vignette and plates are keyed to `warning_started`. The Boss intro (vignette over 90 ticks, scroll over about 2 s) is satisfied by Rules 19 to 21 |
| Display scaler and bezel (4) — GDD | ← | Draws inside the 360 x 640 SubViewport; shake moves world layers by at most 8 px (Rule 26); nothing outside the canvas |
| Stage-end tally (21) — GDD | ← | `tally_started`, `tally_finished`; `tally_scroll_pct` 25; Rule 22 |
| Critical Break (17) — GDD | ← | `set_desaturation(pct)` (via VFX); Rule 30 |
| Era shift (19) — GDD | ← | `free_set()` at transition tick 53, `prepare(stage_id)` after it, `era_swap_committed(era_index)` (tick 90: show new set), `era_ready` (tick 201: start fade-in); → `env_prepared(stage_id)`; Rules 27 and 28a |
| VFX and screen feedback (25) — GDD | ← / → | VFX draws scorch decals at layer 2 using `ground_dy` and caps shake at 8 px; Parallax requests at most 12 weather-class smoke puffs from the shared 150 pool (Rule 24); Parallax renders the boss vignette (Rule 30a) |
| Accessibility options (28) — GDD | ← | `set_background_mode(FULL / DIMMED / PLAIN)`, `set_scroll_scale(pct)`; Rule 29 |
| Game events and session (1) — GDD | ← | pause, `stage_index`, state (Parallax ticks only in Stage states) |
| Save, settings (26) — GDD | — | None; the `access.background` and `access.reduce_motion` keys belong to Accessibility, which calls Parallax |
| HUD (20) — GDD | — | No interface. HUD plates cover y 0 to 47 / 71 |
| Coop and Team Chain (18) — GDD | — | No change (Rule 28). The team background pulse stays off in MVP |
| Audio (24), Localization (27), Powerups (13), Scoring (8) | — | None. There is no text in the play field, so no Bengali / English asset is needed here |

> Era shift (19), VFX (25) and Accessibility options (28) now have GDDs; their rows here follow those documents. Contract: Parallax only receives the calls named above, and never calls back into gameplay.

> Decided under auto-approve (2026-11-03): `S` in 1/100 px owned by the Director module (no Enemy-to-Presentation dependency); layer factors 8 / 25 / 50 / 100 / 130; per-layer accumulators in 1/10,000 px; ground anchor by floor difference; stage-start ease 60; 24 px tile chunks 1,920 / 2,400 px; at most 2 passes with A / B dressing by parity; spatial seam with a boundary band for L2 / L3 and time crossfade for L0 / L1; boss arena as static plates with a 120-tick crossfade at `BOSS_WARNING`; grade and vignette at warning + 150; boss drift 25 confirmed; three zones (edge 72, shoulder 48, core 120) with edge-density and `dL` caps; warm rule for the 1970s accent; pad corridors for ground targets; 8 px overscan; wash overlay for Critical Break; environment set loaded whole at stage start.

### Stage Environment Designs

Sections follow the Director's `bg_sections` ids (Director V5). All sections obey Rules 16 and 17. Palette roles are in "Era palette application" below. "Landmark" means at most one in view.

#### Stage 1: 1941 (Fortress). Chunk 1,920 px. Mood: clear late morning, long soft cloud shadows.

| # | Section id | Trigger | L0 sky | L1 far | L2 mid | L3 near: CORE | L3 near: EDGE / SHOULDER | Landmark | Pads | `wreck_level` | `edge_ed_cap` |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `s1_open_sea` | `stage_started` / `WAVE_START(1)` | Sky with 3 soft cloud banks (48 px or larger, `dL` 10 or less) | Far swell bands; a far convoy ship (36 x 96, no outline) | Open water in flat Sky / Far bands (24 px or taller) | flat water; no props | reef patches, sampans (30 x 10), gull flock (L4, 4 max) | none | none | 0 | 25 % |
| 2 | `s1_coast` | `WAVE_START(2)` | as 1 | Far coast line; a far palm line | Water in the centre; shore starts at the shoulders | calm sea; surf line on the boundary band | dunes, palm clusters (32 x 32), thatch huts (24 x 24), sandbag nests on the pads, fishing boats offshore, paddy terraces behind the dunes | **lighthouse** (40 x 88) on the left headland | PAD | 2 | 25 % |
| 3 | `s1_harbour` | `WAVE_START(3)` | as 1, slightly warmer | Far town roofline; **domed silhouette** (40 x 36, optional, see Open Question 4) at x 160 to 200, L1 only | Harbour water | water plane, no props | wooden jetties (24 px wide) reaching to x 150 / 210, brick godowns, cranes, moored fleet (36 x 110 hulls in Mid tones, no outline) | brick **dock house** (72 x 56) right | PAD (quays) | 4 | 22 % |
| 4 | `s1_fortress_approach` | `WAVE_START(4)` | as 1, thin cloud | Far: the fortress ridge | Dry ground, trench lines | flat packed earth, no joints | bunkers, AA nest pads, trenches, craters, burned hulls | **watch tower** (48 x 64) left | PAD | 6 | 20 % |
| 5 | `s1_fortress_walls` | `WAVE_START(5)` | as 4 | Far: gun-deck ridge | Courtyard base | flat concrete, no seam lines | high wall segments (24 px wide), gun tubs, sandbags, burned hulls | **gun deck** (96 x 48) right | PAD | 8 | 18 % |
| 6 | `s1_boss_deck` | `BOSS_WARNING` | boss sky strip | boss far strip | **L2 plate:** deck courtyard with the damaged watch tower and gun deck (upper third, y 60 to 230) | empty courtyard | **L3 plate:** broken wall frames, scorch, two braziers | damaged tower | n/a | 8+ | 18 % |

Stage 1 nominal ground scroll per section (F3): see AC-11. The boss deck plate is opaque; the sky and far strips are hidden behind it (their VRAM is kept, as it is cheap, to keep one loader path).

#### Stage 2: 1970s (Jet Carrier). Chunk 2,400 px. Mood: hard overcast, chrome and orange.

| # | Section id | Trigger | L0 sky | L1 far | L2 mid | L3 near: CORE | L3 near: EDGE / SHOULDER | Landmark | Pads | `wreck_level` | `edge_ed_cap` |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `s2_high_haze` | `stage_started` / `WAVE_START(1)` | Steel Sky with 3 haze bands (48 px or taller, `dL` 10 or less); the top 160 px warms to a sodium horizon (Sky mixed 90 / 10 and 75 / 25 with Accent, 2 ramp steps) | high cloud deck | quilt of rectilinear fields (48 px blocks, `dL` 20 or less) and a river thread | open fields, no props | power pylons (24 x 24 tops), roads, field edges | none | none | 0 | 25 % |
| 2 | `s2_river_delta` | `WAVE_START(2)` | as 1 | far haze and a far skyline | dredged river channel, 120 px or wider, flat | calm water | concrete blocks, cargo cranes, fuel tanks (40 x 40, edge only), **missile silos** (40 x 40, edge only), radar masts, orange warning lights on masts and cranes | **radar mast** with rotating dish (56 x 96, left bank); optional **cantilever bridge** (360 x 48, one crossing, Open Question 5) | PAD (banks) | 0 | 25 % |
| 3 | `s2_airbase` | `WAVE_START(3)` | as 1 | far hangar line | **runway grid:** wide concrete planes, no markings | taxiway apron, no seam lines, no dashes | runway markings (24 x 4, `dL` 14 or less) in SHOULDER / EDGE only, hangars, silos, warning lights, parked jets (36 x 40, 3 max, edge only, no outline, 24 `dL` or less) | **hangar** (96 x 60) right | PAD (aprons) | 3 | 22 % |
| 4 | `s2_carrier_fleet` | `WAVE_START(4)` | as 1 | far sea | steel sea | calm sea, soft wake wedges (8 px or wider, `dL` 14 or less) | escort ships down both edges (40 x 150, decks are pads), masts with warning lights | none | PAD (escort decks) | 6 | 20 % |
| 5 | `s2_flight_deck_approach` | `WAVE_START(5)` | as 4, thin cloud | far sea | churned carrier wake in soft bands | wake bands, no props | debris, burned escort hull, crater-like rafts | none | none | 8 | 18 % |
| 6 | `s2_boss_sea` | `BOSS_WARNING` | boss sky strip | boss far strip | **L2 plate:** open sea (transparent so L1 crawl shows) with the damaged radar mast on a sandbar (upper third, y 60 to 230) | empty sea | **L3 plate:** burning escort hull and snapped silo hatches at the edges | damaged radar mast | n/a | 8+ | 18 % |

The 1970s orange lights are 8 x 4 px rectangular housings, never round. The lighthouse (1941), radar mast (1970s) and arena landmark form the landmark echo of art bible 6.7.

#### Era palette application

All values are the art bible 4.5 hexes. Luma is Rec.709 on gamma values; saturation is HSV. Figures computed 2026-11-03.

| Role | Layer use | 1941 hex (luma / sat) | 1970s hex (luma / sat) |
|---|---|---|---|
| Sky | L0, water, haze | `#6E8264` (123.6 / 23 %) | `#6C7A86` (119.9 / 19 %) |
| Far | L1, deep water | `#5A6B4E` (101.3 / 27 %) | `#48525C` (80.6 / 22 %) |
| Mid | L2, sand, concrete | `#7A6A48` (106.9 / 41 %) | `#787E84` (125.2 / 9 %) |
| Ground | L3 base | `#4C5A3C` (84.9 / 33 %) | `#5C5F63` (94.7 / 7 %) |
| Accent | edge props only; warm rule | `#8A6F4A` (114.1 / 46 %) | `#A85A22` (102.5 / 80 %) |
| Shadow | cloud shadows, scorch, vignette | `#2E3626` (51.1 / 30 %) | `#2A2F36` (46.4 / 22 %) |

Adjacent-region `dL` where the pair appears (rounded to 0.1):

| Pair | 1941 | 1970s | Allowed in CORE (28)? |
|---|---|---|---|
| Sky / Mid | 16.6 | 5.3 | yes, both |
| Sky / Far | 22.3 | 39.3 | 1941 yes; 1970s SHOULDER |
| Far / Ground | 16.4 | 14.1 | yes, both |
| Mid / Ground | 22.1 | 30.5 | 1941 yes; 1970s SHOULDER, or use one ramp step (about 109.9) to get 15.3 / 15.3 |
| Ground / Shadow | 33.7 | 48.2 | no; EDGE only (1970s) / SHOULDER (1941) |

Cloud shadows (1941) are L4 shapes at 96 to 160 px wide that darken the ground under them by at most 14 luma; they live in EDGE only. Drawing and logic differ per era (palette is baked into redrawn strips and tiles; no runtime recolour for terrain, art bible 8.4).

## Formulas

Conventions: 60 ticks per second; `S` and layer accumulators are 64-bit ints (GDScript `int`); `div` is integer division (floor for positive values).

**F1. Ground scroll integration** *(`ground_scroll`)*

`v_eff(t) = (v x min(t, E)) div E` for `t < E` after `stage_started`, else `v`; `S(t+1) = S(t) + v_eff(t)`; `y_world_px = S div 100`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Speed | `v` | int, px/tick x 100 | 0 to 200 | Director `scroll_v_x100` (current integer value) |
| Ease length | `E` | int ticks | 0 to 120 (60) | `stage_ease_ticks` |
| Ticks since stage start | `t` | int | 0 and up | |
| Scroll position | `S` | int, 1/100 px | 0 to about 2 x 10^6 per stage | |

**Output Range:** `S` rises by 0 to 200 per tick. **Example (Stage 1, v = 80, E = 60):** `v_eff(59) = (80 x 59) div 60 = 78`; `S(60) = sum of floor(4t/3), t = 0..59 = 2,340`; `S(120) = 2,340 + 60 x 80 = 7,140` (wave 1 starts). **Stage 1 at `E5`** (nominal, no early clear, Director blends floored): `7,140 + 168,000 + 204,540 + 239,340 + 252,000 + 296,340 = 1,167,360` (11,673 px). **Stage 2 at `E5`:** lead-in `S(120) = 3,540 + 7,200 = 10,740`; waves `259,200 + 303,540 + 352,140 + 395,340 + 423,000 = 1,733,220`; total **1,743,960** (17,439 px).

**F2. Layer accumulator and draw offset** *(`layer_offset`)*

`A_L(t+1) = (A_L(t) + (v_eff x f_L x k_L) div 100) mod (loop_L x 10,000)`; `draw_y_L = A_L div 10,000`; `k_L = scroll_scale_pct` for L0, L1, L2, L4 and `100` for L3 (Rule 29b)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Layer factor | `f_L` | int percent | 0 to 130 | 8 / 25 / 50 / 100 / 130 |
| Loop height | `loop_L` | int px | 1,280 to 2,400 | strip or chunk height |
| Accumulator | `A_L` | int, 1/10,000 px | 0 to `loop x 10,000` | per layer |
| Scroll scale | `k_L` | int percent | 0 to 100 (100) | `set_scroll_scale`; always 100 for L3 |

**Output Range:** `draw_y` 0 to `loop_L - 1`; step per tick at most 2 px (L4 at v = 150: 1.95 px). **Example (v = 80):** per tick L0 640, L1 2,000, L2 4,000, L3 8,000, L4 10,400 units. After 100 ticks: L0 `64,000 div 10,000 = 6` px, L1 20, L2 40, L3 80, L4 104. L0 first moves 1 px at tick 16 (`10,240`). L3 (`f = 100`) satisfies `A = S x 100`, so `draw_y_L3 = S div 100` exactly. **Closed form, 1,000,000 ticks at v = 150, L1:** `1,000,000 x 150 x 25 = 3,750,000,000`; mod `12,800,000` = `12,400,000`; draw **1,240**.

**Scaled example (F2):** `scroll_scale_pct` 25, v = 80: L1 gains `(80 x 25 x 25) div 100 = 500` units per tick (1 px per 20 ticks, a quarter of 2,000); L3 still gains 8,000 (`k` = 100); `S` is unchanged, so ground targets still match.

**F12. Background mode modulate** *(`bg_dim`)*

`dim = (255 x bg_dim_pct + 50) div 100`; `L_out = (L x dim + 127) div 255`; stage-time easing levels move toward the target by at most 10 points every `mode_step_ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Dim percent | `bg_dim_pct` | int | 40 to 90 (65) | Accessibility F4 |
| Modulate | `dim` | int 0..255 | 102 to 230 | per channel |
| Source luma | `L` | float | 16 to 128 | environment pixel |

**Output Range:** `0.65 L`, about 10 to 83 for the band. **Example:** `dim = (255 x 65 + 50) div 100 = 166`. 1941 Sky luma 123.6 becomes about **80.5**; 1970s Sky 119.9 becomes **78.0**; the darkest boss-graded Shadow (35.8) becomes **23.3**, still at or above 16. Bullet contrast only improves: `217 - 80.5 = 136.5`. PLAIN uses luma 51.1 (1941) or 46.4 (1970s): `217 - 51.1 = 165.9`.

**F3. Section scroll and passes** *(`section_passes`)*

`px_x100(w) = v_old x B + sum_{t=0..B-1}((v_new - v_old) x t div B) + v_new x (L - B)`; `passes = (px_x100 / 100) / chunk_h`; require `passes <= 2.0`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Old / new speed | `v_old`, `v_new` | int | 20 to 200 | previous and this wave (Director) |
| Blend | `B` | int ticks | 60 to 240 (120) | `scroll_blend_ticks` |
| Wave length | `L` | int ticks | 1,800 to 3,600 | `length_ticks` |
| Chunk height | `chunk_h` | int px | 1,920 or 2,400 | Rule 7 |

**Output Range:** passes 0.8 to 2.0 in MVP. **Example, Stage 1 (chunk 1,920):** W1 (no blend) `80 x 2,100 = 168,000` → 1,680 px → **0.875**; W2 `80 x 120 + 540 + 90 x 2,160 = 204,540` → 2,045 px → **1.065**; W3 `90 x 120 + 540 + 100 x 2,280 = 239,340` → **1.247**; W4 `252,000` → **1.313**; W5 `100 x 120 + 540 + 110 x 2,580 = 296,340` → **1.544**. **Stage 2 (chunk 2,400):** `259,200 / 303,540 / 352,140 / 395,340 / 423,000` → **1.080 / 1.265 / 1.467 / 1.647 / 1.763**. With a 1,920 chunk Stage 2 wave 5 would be 2.203 and fail V-E2, which is why Stage 2 uses 2,400. The sum of the blend terms is 540 because `sum_{t<120} floor(t/12) = 12 x 45`. A Continue pause can push passes beyond 2.0 for that run only (Edge Cases).

**F4. Ground anchor** *(`ground_dy`)*

`ground_dy(S_now, S_spawn) = (S_now div 100) - (S_spawn div 100)`; drawn `y = y_start + ground_dy`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Position now / at spawn | `S_now`, `S_spawn` | int | 0 and up | `ScrollClock` |
| Start y | `y_start` | int px | -64 to 0 | spawn y (Enemy F10) |

**Output Range:** 0 to about 700 px over a ground life. **Example:** `S_spawn = 123,457` (floor 1,234). 100 ticks at v = 85 later `S = 131,957` → 1,319 → `ground_dy = 85`. From `S_spawn = 123,499` with v = 80, tick 1 gives `S = 123,579` → 1,235 → `ground_dy = 1`, on the same tick L3 steps 1 px. Over a 120-tick blend 80 → 90 the gap between `ground_dy` and the L3 offset is **0** on every tick.

**F5. Crossfade alpha** *(`fade_alpha`)*

`alpha(t) = (255 x min(t, B)) div B`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Ticks since trigger | `t` | int | 0 and up | |
| Blend length | `B` | int ticks | 30 to 240 (120) | `blend_ticks`, `plate_blend_ticks` |

**Output Range:** 0 to 255. **Example (B = 120):** t = 1 → **2**; t = 60 → **127**; t = 120 → **255**.

**F6. Boss grade modulate** *(`boss_grade`)*

`rgb_c(g) = 255 - ((255 - boss_rgb_c) x g) div G`, `g` = ticks since grade start (0..G), `G` = 90, `boss_rgb = (204, 196, 184)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Channel target | `boss_rgb_c` | int | 160 to 255 | R 204, G 196, B 184 |
| Grade tick | `g` | int | 0 to 90 | |

**Output Range:** each channel 255 down to its target; luma factor at full grade `(0.2126 x 204 + 0.7152 x 196 + 0.0722 x 184) / 255 = 0.772`. **Example:** g = 45 → R `255 - (51 x 45) div 90 = 230`, G `255 - 29 = 226`, B `255 - 35 = 220`. At g = 90 → (204, 196, 184). Floor check: 1941 Shadow (46, 54, 38) becomes (36.8, 41.5, 27.4), luma **39.5**; 1970s Shadow (42, 47, 54) becomes luma **35.8**; 1941 Sky becomes luma **95.4**. All stay inside 16 to 128.

**F7. Vignette alpha** *(`vignette_alpha`)*

`d = min(x, 359 - x)`; `k = d div 12`; `alpha(x, g) = (band[k] x g) div G` for `d < 72`, else 0; `band = [102, 87, 71, 54, 36, 18]`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Edge distance | `d` | int px | 0 to 179 | to the nearer side |
| Band index | `k` | int | 0 to 5 | outermost = 0 |
| Grade tick | `g` | int | 0 to 90 | |

**Output Range:** 0 to 102 (40 % of 255); zero for x 72 to 287. **Example:** x = 5 → `d = 5`, k = 0 → 102 (g = 90) or 51 (g = 45); x = 70 → k = 5 → 18; x = 100 → 0; x = 355 → `d = 4` → 102.

**F8. Edge density** *(`edge_density`)*

`ED = differing_pairs / 1,104` over a 24 x 24 window (`2 x 24 x 23 = 1,104` horizontal and vertical neighbour pairs); a pair differs if the two palette indices differ

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Differing pairs | | int | 0 to 1,104 | |
| Window | | 24 x 24 px | | stride 8 in CORE / SHOULDER, 24 in EDGE; zone = zone of the window centre |

**Output Range:** 0 to 100 %. **Example:** one straight boundary between two regions: 24 / 1,104 = **2.17 %**. One 1-px vertical line: 2 per row x 24 = 48 → **4.35 %** (passes the CORE cap 6 %). A 1-px vertical line crossing a 1-px horizontal line: `46 + 46 = 92` → **8.33 %** (fails CORE, passes SHOULDER). A 1-px checkerboard: **100 %**.

**F9. Adjacent luma step** *(`luma_step`)*

`dL = |Y(a) - Y(b)|`, `Y = 0.2126 R + 0.7152 G + 0.0722 B` (gamma values); check for each pair of 4-neighbour regions larger than the zone's small-region limit

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Region luma | `Y` | float | 16 to 128 | after lint rounding to 0.1 |

**Output Range:** 0 to 112; caps 28 / 48 / 80. **Example (1970s):** Mid `#787E84` 125.2 and Ground `#5C5F63` 94.7 → **30.5**: fails CORE (28), passes SHOULDER (48). With a ramp step of luma 109.9 between them: **15.3** and **15.2**, both pass.

**F10. Environment VRAM** *(`env_vram`)*

`MiB = sum(w x h x 4) / 1,048,576` over the stage set (RGBA8, lossless import, art bible 8.1)

| Asset | Count | Size (px) | MiB each | MiB total |
|---|---|---|---|---|
| Terrain tile atlas | 1 | 1,024 x 512 | 2.000 | 2.000 |
| Props atlas | 1 | 1,024 x 1,024 | 4.000 | 4.000 |
| Landmarks atlas | 1 | 1,024 x 1,024 | 4.000 | 4.000 |
| Arena plates (L2, L3, vignette) | 3 | 376 x 656 | 0.941 | 2.823 |
| L0 sky strips (day, boss) | 2 | 376 x 1,280 | 1.836 | 3.672 |
| L1 far strips | 3 | 376 x 1,280 | 1.836 | 5.508 |
| L4 overhead atlas | 1 | 512 x 256 | 0.500 | 0.500 |
| **Total** | | | | **22.50** |

**Output Range:** 22.5 MiB planned; design budget `env_vram_budget_mib` 28; art bible cap 36. **Example:** whole-device check: always-loaded 18 + enemies and bosses 18 + fx 2 + environment 22.5 = **60.5 MiB**, under the 96 MiB target. Peak while the previous set is freed before the next loads stays at this value.

**F11. Pad continuity** *(`pad_continuity`)*

`ok = (t_spawn + ground_life <= t_next_start) OR next.pad_class == PAD`; `ground_life = ceil(640 x 100 / v_x100)` (Director F8)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Spawn tick (wave-relative) | `t_spawn` | int ticks | 0 to `length` | `gunner` event |
| Next section start | `t_next_start` | int ticks | nominal `length` | worst case |
| Ground life | `ground_life` | int ticks | 320 to 3,200 | Director F8 |

**Output Range:** bool. **Example:** Stage 2 wave 3 (v = 140, `ground_life` 458, `length` 2,520): a gunner at tick 2,100 → 2,558 > 2,520, so it is only legal because wave 4 has PAD (escort decks). If wave 4 had no pads, the latest legal tick is `2,520 - 458 = 2,062`.

> Decided under auto-approve (2026-11-03): all constants above are proposals (zone caps 6 / 12 / 25 % and 28 / 48 / 80, grade colour, vignette bands, 22.5 MiB plan). They are tuned by the grayscale gate and playtest.

## Edge Cases

**Scroll and sync**
- **If every slot is Dead or in Continue**, `ScrollClock` and all layers keep ticking; ground targets stay locked to the terrain; only the Director's clock stops.
- **If the game is paused**, `ScrollClock` and `ParallaxState` are not ticked; all accumulators are unchanged; animations pause.
- **If `scroll_changed` is never received after `stage_started`**, `v` stays 0, the world is still, and an error is logged in debug builds.
- **If `v` changes mid-section (the 120-tick blend)**, `S` and all layers integrate the new value each tick; ground objects stay locked (F4).
- **If a Continue lasts 600 ticks at v = 150**, `S` gains 90,000 (900 px) and L3 may exceed 2.0 passes for that wave; dressing keeps alternating A / B; nothing else changes.
- **If a ground target is still alive when its section changes**, it keeps its anchor (F4); its pad continues into the next section by Rule 31, so it never sails onto the wrong terrain.
- **If `S_spawn` is read on a blend tick**, the anchor uses the integer `S` of that tick; no float is involved.
- **If the run is saved or resumed**, only `S` is needed to rebuild; all accumulators derive from `S` in the debug snapshot; MVP has no mid-stage resume.

**Sections and transitions**
- **If a trigger names an unknown `section_id`**, a debug build asserts; a release build keeps the current section and logs it. The missing section is never drawn.
- **If a section asset fails to load**, `prepare()` fails: debug asserts; release keeps the last good set and logs. No magenta placeholder is shown to players.
- **If `WAVE_START(n)` fires during an L0 / L1 blend**, the running blend completes at once (alpha 255), then the new blend starts.
- **If `WAVE_START(n)` and the REST gap overlap**, nothing special: a section change is the same at any scroll speed; the REST gap does not stop the scroll.
- **If a wave ends early (early clear)**, the next section starts earlier with it. The seam arrives sooner; the old chunk's remaining rows are never shown.
- **If an old prop straddles the seam**, it is cut by the boundary band (Rule 13). Authors must not place props so that a cut leaves a free-standing fragment: props within 96 px of a chunk's far (top) edge are not allowed (validator V-E3).
- **If `BOSS_WARNING` fires with L2 / L3 mid-seam**, the plates crossfade over everything; the field is already clear, so there are no bullets on screen to read against the double image.
- **If the boss dies early or the boss times out**, nothing changes in Parallax; the grade holds until `tally_started`.
- **If `warning_started` arrives with `ticks` not equal to 150**, the grade delay equals that value (Rule 20).
- **If the stage is `debug` restarted at a wave**, the snapshot taken at the wave start restores `S` and all accumulators (debug only; sets `run.debug_tainted`).

**Readability**
- **If an env pixel has luma below 16**, the lint fails the asset. Ink `#0B0B2A` has luma 13.2 and the 1941 enemy outline `#14180F` fails too.
- **If a core window measures `ED` 6.1 %**, the asset fails; 6.0 % passes (round to 0.1 %).
- **If a prop box crosses x = 120 from the shoulder into the core**, it is held to CORE limits.
- **If a landmark and a ground-explosion burst overlap**, the burst wins (layer 2 over layer 1) and the landmark is not damaged; sacred silhouettes appear on L1 only, never under a pad, and never in the arena (art bible 6.1).
- **If the grayscale gate fails on a probe**, the section is not approved; the background is simplified. The bullet sprites are not altered.
- **If the Critical Break desaturation overlaps the boss grade**, both apply (the tint is at layer 2 above the L0 to L3 modulate); the sum stays inside luma 16 to 128 because the tint colour is the era Sky.
- **If `set_desaturation` is called with `pct` above 60**, it is clamped to 60; a call with 0 hides the tint.
- **If the background mode is PLAIN during the boss**, the arena plates and vignette are hidden; the grade has nothing to darken; the flat fill stays at the era Shadow luma (51.1 / 46.4).
- **If `set_scroll_scale(25)` is active and a gunner crosses the screen**, the gunner and L3 still move together at gameplay speed; only L0, L1, L2 and L4 slow down.
- **If DIMMED is combined with the boss grade**, the modulates multiply; the darkest result (1970s Shadow) has luma 23.3, above 16.
- **If a weather-class puff request is refused** (pool full, or effects level REDUCED / MINIMAL), the puff is simply not drawn; the scene is complete without it.
- **If `era_swap_committed` arrives before `env_prepared`**, Parallax shows nothing (the card covers the canvas) and the swap completes on the tick `env_prepared` fires; Era shift's own late-load rule releases the hold.
- **If the stage fade-in overlay would start while the dim phase is under 60 ticks old**, it does not start (Era shift Rule 28 forbids opposite steps inside 60 ticks); the Director's order makes this impossible by 170 ticks.

**Resources and platform**
- **If the 8 px shake overscan is exceeded by VFX**, the clear colour shows at the edge; VFX must cap the shake at 8 px (Rule 26); the lint test uses the cap.
- **If the chunk pool would exceed 3 instances in a layer**, the oldest off-screen chunk is released first; a fourth instance is never created (debug assert).
- **If `prepare()` runs while a previous set is still loaded**, the previous set is freed first (peak VRAM stays at one set).
- **If the Web build cannot load threaded**, `prepare()` runs one resource per tick synchronously (Rule 27).
- **If the player count is 3 or 4**, the HUD strip is 72 px tall; the background is unchanged.
- **If `set_scroll_scale` is below 100**, L0, L1, L2 and L4 scroll at that percentage (L4 hidden), prop animation is frozen on frame 0 and tile shimmer stops; L3, `S`, ground targets and gameplay are unchanged.
- **If the Display scaler runs Fill (sharp-bilinear) or TATE**, the background is already inside the SubViewport and needs no change.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Wave and stage director (16) | Hard | `scroll_changed`, `bg_sections`, `stage_started`, `warning_started`, `ScrollClock` | yes |
| Display scaler and bezel (4) | Soft | 360 x 640 SubViewport, shake inside the canvas | yes |
| Game events and session (1) | Soft | pause, state, `stage_index` | yes |
| Stage-end tally (21) | Soft | `tally_started`, `tally_finished`, `tally_scroll_pct` | yes |
| Critical Break (17) | Soft | `set_desaturation(pct)` | yes |
| Era shift (19) | Hard | `free_set`, `prepare` / `env_prepared`, `era_swap_committed`, `era_ready` | yes |
| VFX and screen feedback (25) | Soft | layer 2 FX, shake cap, weather-class pool share | yes |
| Accessibility options (28) | Soft | `set_background_mode`, `set_scroll_scale` | yes |
| Art bible | Reference | Sections 2, 3.4, 4, 6, 8 | yes |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Enemy and AI (10) | Hard (via `ScrollClock` in the Director module) | GROUND anchor `ground_dy`; layers 2 and 3 | yes |
| VFX (25) | Soft | scorch decals and ground explosions use `ground_dy` | yes ([VFX](vfx-and-screen-feedback.md)) |
| Boss and boss parts (14) | Soft | arena plates and vignette are there when the boss enters | yes |
| Menus / Tally (21, 22) | Soft | background left in the arena state for the tally | yes / yes |

**Amendments to other docs** (apply at wrap-up)

1. **Systems index:** row 23 status `**Designed** (pending review) — [GDD](parallax-and-environment.md)`; `Depends on` `16` becomes `1, 4, 16` (soft: 17, 19, 21, 25); progress tracker adds this GDD.
2. **Wave and stage director** (`wave-and-stage-director.md`): (a) Rule 20 and F8: add a `ScrollClock` owned by the Director module with `scroll_pos_x100()` (`S`, F1 here); `scroll_changed(v_x100)` is emitted on every integer change and once at `stage_started`; (b) Rule 20 and F8 / AC-28: "ground enemies take the speed current at their spawn tick and keep it" is replaced by "ground enemies follow the live `S` (ground anchor)"; `ground_life` stays an estimate from the speed at spawn; (c) V2: "background layers L0 to L3 keep their relative parallax ratios" becomes "L2 and L3 are replaced by static arena plates; L0 and L1 crawl" (Parallax Rule 19); (d) V5: boss section ids are the arena plate sets; the first section loads at `stage_started`; (e) Open Question 5 closed (25 confirmed); (f) Downstream row "Parallax": GDD exists; (g) the validator calls `EnvValidator` checks V-E1 to V-E5; (h) stage lengths and speeds changes require re-running F3 here.
3. **Enemy and AI** (`enemy-and-ai.md`): (a) Rule 8 `params.scroll_v` and the `STRAIGHT` `SCROLL` mode: a `GROUND` enemy stores `S_spawn` and its drawn y is `y_start + ground_dy`; the hurtbox y uses the same value (float allowed); (b) Open Question 5 closed; (c) draw layers confirmed (ground target 3, ground explosion and scorch 2); (d) Parallax row in Dependencies points to this GDD.
4. **Display scaler and bezel** (`display-scaler-and-bezel.md`): Open Question 5 background half closed: overscan 8 px, shake at most 8 px; Parallax row: GDD exists.
5. **Art bible** (`design/art/art-bible.md`): (a) 4.5 note: the 1970s Accent `#A85A22` measures 80 % HSV saturation (above the 55 % background cap); allowed only under the warm rule (Rule 17c); saturation is HSV; (b) 6.4: strips are 376 px wide and plates 376 x 656 (8 px overscan); (c) 6.5: zone definitions (EDGE 72, SHOULDER 48, CORE 120) and the limits in Rule 16; (d) 6.9: L2 / L3 are replaced by static plates; vignette bands (F7) and `boss_rgb`; (e) 8.6: parallax draw calls at most 8 steady and 10 during a 120-tick crossfade; environment VRAM design budget 28 MiB (22.5 planned); (f) 2 Grayscale gate: the procedure in Rule 18.
6. **Stage-end tally** (`stage-end-tally.md`): `tally_scroll_pct` is a percentage of the scroll speed at tally open; Parallax row: GDD exists; the grade eases out over 60 ticks.
7. **Critical Break** (`critical-break.md`): V2 background tint is implemented as `Parallax.set_desaturation(pct)` (called through VFX), a flat Sky-colour sprite at layer 2, maximum 60 % (alpha 153), Reduce flashing maximum 25 % (alpha 64).
7a. **Era shift and plane evolution** (`era-shift-and-plane-evolution.md`): Parallax row becomes "GDD exists": `free_set()` at transition tick 53, `prepare` after it, `env_prepared` before `era_ready`, `era_swap_committed` shows the new set, `era_ready` starts Parallax's 9-step fade-in (85, 76, 66, 57, 47, 38, 28, 19, 9, 0; 4 ticks per step); the Parallax stage fade overlay at z 105 replaces any second fade owner; env set of about 22.5 MiB fits the 36 MB budget.
7b. **VFX and screen feedback** (`vfx-and-screen-feedback.md`): Open Question 5 closed: Parallax renders the boss vignette (and enrage darken); remove `fx_boss_vignette` from the effects list (band B0 keeps scorch only); `fx_weather` smoke puffs requested by Parallax are tier T4 and count against the 150 cap (at most 12, none at REDUCED / MINIMAL); `set_desaturation(pct)` exists on Parallax; shake at most 8 px.
7c. **Accessibility options** (`accessibility-options.md`): the Parallax row becomes "GDD exists": `set_background_mode` (DIMMED `dim` 166 = F4 65 %; PLAIN flat era Shadow fill, vignette off) and `set_scroll_scale(pct)` affects L0, L1, L2 and L4 only, L3 and ground targets stay on gameplay scroll; Rule 12 "L0-L5" reads "L0-L4 plus plates and props"; add the limit that terrain under ground targets cannot be slowed without changing gameplay speed.
8. **Boss and boss parts** (`boss-and-boss-parts.md`): Visual: the vignette is driven by Parallax at `warning_started` + 150 and needs no Boss call; Parallax row: GDD exists.
9. **Boss power budget / Powerups / Scoring:** none.
10. **Coop and Team Chain** (`coop-and-team-chain.md`): Visual: the optional team background pulse stays off; Parallax row: no change at any `N`.
11. **Save, settings and high scores** (`save-settings-high-scores.md`): none beyond the keys Accessibility already owns (`access.background`, `access.reduce_motion`).
12. **Registry** (`design/registry/entities.yaml`): add the entries from the report; add `parallax-and-environment` to `referenced_by` of `canvas_size` and `play_top`.

**Bidirectional check:** the Director, Display scaler, Tally, Enemy, Era shift, VFX and Accessibility GDDs list Parallax; amendments 2 to 8 and 7a to 7c make each row point back here.

## Tuning Knobs

**Owned by this system** (`data/environment/env_rules.tres` for globals; `data/environment/sections/<section_id>.tres` per section)

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `factor_pct` L0 / L1 / L2 / L3 / L4 | 8 / 25 / 50 / 100 / 130 | L0 0 to 10; L1 15 to 35; L2 35 to 65; L3 fixed 100; L4 110 to 150 | No depth | Shimmer, layers look unrelated | Art bible 6.5, F2 |
| `chunk_h` (S1 / S2) | 1,920 / 2,400 | 1,440 to 3,600 | Repeats show | More tile data and art | F3, passes |
| `max_passes` | 2.0 | 1.0 to 3.0 | Needs a bigger chunk | Visible repeats | F3, V-E2 |
| `stage_ease_ticks` | 60 | 0 to 120 | Jump at stage start | Slow start | F1, lead-in 120 |
| `blend_ticks` (L0 / L1) | 120 | 60 to 240 | Visible swap | Mixed sky too long | F5 |
| `plate_blend_ticks` | 120 | 60 to 180 | Pop at the boss | Plates still blending at intro | F5, warning 150 |
| `grade_ticks` | 90 | 60 to 120 | Abrupt | Slow mood | Boss intro (vignette 90) |
| `boss_rgb` | (204, 196, 184) | each 160 to 230 | Too dark (floor 16) | Barely darker | F6, luma floor 16 |
| `vignette_band[0..5]` | 102 / 87 / 71 / 54 / 36 / 18 | max 128 | No pull inward | Edge bullets lose contrast | F7, zones |
| `tally_grade_ticks` | 60 | 30 to 120 | Pop | Dark during tally | Tally |
| `ED` caps CORE / SHOULDER / EDGE | 6 / 12 / 25 % | CORE 3 to 8 | Backgrounds dull | Bullets lose readability | F8, grayscale gate |
| `dL` caps CORE / SHOULDER / EDGE | 28 / 48 / 80 | CORE 16 to 36 | Flat sections | Bullet clutter | F9 |
| `edge_ed_cap` per section | 25, 25, 22, 20, 18 % | 12 to 30 | Barren edges | Busy edges at high bullet density | Art bible 6.6 |
| `anim_max` / `anim_shoulder_core_max` / `anim_fast_max` | 12 / 4 / 1 | 6 to 16 / 2 to 6 / 1 to 2 | Dead world | Motion competes | Rule 23 |
| Prop frame ticks / tile shimmer ticks | 10 / 30 | 6 to 20 / 20 to 60 | Flicker | Frozen look | Rule 23 |
| Warning light cycle | 90 ticks | 60 to 180 | Strobe risk (must stay at or below 1 Hz) | Static | Accessibility |
| `wreck_level` per section | S1 0 / 2 / 4 / 6 / 8; S2 0 / 0 / 3 / 6 / 8 | 0 to 8 | Clean world | Clutter | Edge only |
| `prop_pool_max` | 40 | 24 to 64 | Missing props | Node cost | Perf |
| `env_smoke_max` / `scorch_max` | 12 / 12 | 6 to 20 / 6 to 16 | No ambient smoke | Over the 150 particle cap | Art bible 8.6 |
| `overscan_px` | 8 | 4 to 16 | Edge shows on shake | VRAM | Display scaler, VFX shake cap |
| `pad_x` corridors | 72 to 150, 210 to 288 | within shoulders to x 160 / 200 | Gunner off-pad | Pad intrudes into the core | Enemy origins x 110 / 250 |
| `env_vram_budget_mib` | 28 | 20 to 36 | Art cut | Over device cap | F10 |
| `draw_calls_steady` / `transient` | 8 / 10 | 5 to 8 / 8 to 10 | n/a | Over the 200 budget | Art bible 8.6 |
| `bg_tint_max` (desaturation clamp) | 60 % (alpha 153; Reduce flashing 25 %, owned by Critical Break) | 0 to 60 | Weak CB tint | Washed field | Critical Break, VFX |
| `bg_dim_pct` / `dim` | 65 % / 166 (owned by Accessibility F4) | 40 to 90 | Field nearly black | Little gain | F12 |
| `mode_step_ticks` | 8 | 4 to 16 | Brightness step too quick | Slow mode change | Era shift F5 (steps of 10 points or less) |
| `scroll_scale_pct` | 100 (set by Accessibility) | 0 to 100 | Frozen decorative layers | n/a | F2, Rule 29b |
| `fade_levels` / `fade_step_ticks` | 85, 76, 66, 57, 47, 38, 28, 19, 9, 0 / 4 | at least 9 steps, each at most 10 points | Breaks Era shift F5 | Slow stage start | Era shift Rule 28 |
| `enrage_vignette_pct` | 125 (alpha cap 127) | 100 to 125 | No enrage cue | Edge bullets lose contrast | F7 |
| `env_weather_request_max` | 12 | 0 to 24 | No ambient smoke | Evicts burst effects first (T4) | VFX cap 150 |

**Owned elsewhere:** `scroll_v_x100` per wave, `boss_scroll_v_x100` 25, `scroll_blend_ticks` 120, `warning_ticks` 150 (Director 16); `tally_scroll_pct` 25, `open_ticks` 30 (Tally 21); luma 16 to 128 and the palette hexes (art bible 4); shake amount (VFX 25); particle caps 150 (art bible 8.6); scorch life 180 ticks (Enemy 10); `play_top` and HUD strip (art bible 7.2, HUD 20).

**Balance rationale:** zone widths come from the art bible quiet lane (middle 60 %) and the user's 120 px core. The `ED` caps allow about one 1-px line (4.35 %) in the core but no grid (8.33 %). The `dL` caps keep the core within one ramp step of the neighbouring tones. The vignette and grade values keep every pixel at luma 35 to 96 or higher, so `217 - bg_max >= 89` holds with room to spare. Chunk sizes are set so every MVP wave needs under 2 passes (F3).

## Visual/Audio Requirements

All art follows the art bible. Sizes are px at 1x on the 360 x 640 canvas. Draw layers are art bible 6.8. **Bullets always win:** nothing here draws above layer 8, nothing uses Void Indigo `#4A5CFF` or Ink `#0B0B2A`, and no env shape is an orb, rice, needle or 14 to 18 px ring.

| Element | Spec |
|---|---|
| L0 sky strips | 376 x 1,280, indexed to the era palette, ordered dither only in EDGE columns; clouds and haze bands 48 px or larger with `dL` 10 or less |
| L1 far strips | 376 x 1,280, soft merged shapes at the dim end of the band |
| Terrain tiles | 24 x 24 cells, 2 px gutter, atlas 1,024 x 512, tile animation: water 4 frames |
| Landmarks | Hand-painted, 3 tones per material in the lane (4 at the edges), no outline in the lane; edge props may use a darker same-hue tone |
| Props | Individual sprites, 6 fps or slower; round props 36 px or larger and only in EDGE |
| Boundary bands | 96 px full-width natural edges (shoreline, breakwater, road, ditch) |
| Arena plates | 376 x 656, static; L2 plate has the damaged landmark in the upper third (y 60 to 230); L3 plate frames the edges; CORE flat |
| Vignette | 376 x 656, Shadow colour, 6 flat bands, no dither, alpha 18 to 102 |
| Desaturation tint | Flat Sky colour sprite, layer 2 (z 21) |
| Boss vignette | Layer 2 (z 20), rendered by Parallax (Rule 30a) |
| Stage fade overlay | Flat Cabinet Char `#1E1B18` sprite, z 105, 9 steps |
| PLAIN fill | Flat era Shadow sprite, 360 x 640, z 10 |
| Light | Baked top-left in 1941 and 1970s; no runtime lighting on environment sprites (art bible 6.3) |
| Text | None. No signage, slogans or script in the play field (art bible 6.7) |
| Sacred silhouettes | L1 only, never enemy, never under a pad or the boss (art bible 6.1); cultural review before lock |

**Asset list hooks for `/asset-spec`** (names follow the art bible `[category]_[name]_[variant]_[size]` convention; palette = era palette)

| Asset | File name | Notes |
|---|---|---|
| Sky strips | `env_strip_sky_1941_376x1280.png`, `env_strip_sky_boss_1941_376x1280.png` (and `1970s`) | 2 per stage |
| Far strips | `env_strip_far_open_1941_376x1280.png`, `..._coast_...`, `..._fortress_...` (and `1970s` haze, delta, fleet) | 3 per stage |
| Terrain atlas | `tile_terrain_1941_atlas_1024x512.png` (and `1970s`) | water, sand, quay, earth, wall; concrete, runway, apron, river, deck |
| Prop atlas | `env_props_1941_atlas_1024x1024.png` (and `1970s`) | sampans, palms, huts, nests, godowns, moored ships, burned hulls, craters; cranes, tanks, silos, pylons, escort hulls, parked jets, warning lights (2 frames) |
| Landmarks | `env_landmark_lighthouse_1941_40x88.png`, `..._dockhouse_72x56`, `..._watchtower_48x64`, `..._gundeck_96x48`, `..._dome_silhouette_40x36` (optional); `env_landmark_radarmast_1970s_56x96.png` (+ dish 8 frames 36 x 36), `..._hangar_96x60`, `..._bridge_360x48` (optional) | atlas 1,024 x 1,024 |
| Arena plates | `env_plate_arena_l2_1941_376x656.png`, `env_plate_arena_l3_1941_376x656.png` (and `1970s`) | static |
| Vignette | `fx_vignette_boss_1941_376x656.png` (and `1970s`) | Shadow colour |
| L4 set | `env_l4_cloud_1941_512x256.png`, `env_l4_haze_1970s_512x256.png` | edge sprites, cloud shadows, gulls, pylon tops |
| Scorch decals | `fx_scorch_ground_1941_32x32.png` (and `1970s`) | VFX atlas, 2 variants |

Environment audio: none owned here. Stage music and the WARNING siren are Director cues (Audio 24).

## UI Requirements

No player-facing UI. The background never shows text and has no interactive element.

**Debug only (development builds):**
- **Zone overlay:** vertical lines at x 72, 120, 240, 288 with tinted zones.
- **Grayscale toggle** and **luma heat map** (green inside 16 to 128, red outside).
- **Bullet probe grid:** the 12 probe points with pass / fail marks (Rule 18).
- **Layer toggles** for L0 to L4, props, plates, vignette.
- **Readout:** `S`, `v`, `A_L` per layer, draw offsets, section id, pass index, chunk pool count, draw calls, VRAM.
- **Jump to section** and **stage restart**: sets `run.debug_tainted` (Director debug tools). A scroll speed multiplier (0x to 4x) also sets it, because it changes ground-target motion.
- **Lint print:** per-asset `ED`, `dL`, hue and saturation numbers.

## Acceptance Criteria

Defaults used: `factor_pct` 8 / 25 / 50 / 100 / 130, loops 1,280 / 1,280 / chunk, chunk 1,920 (S1) / 2,400 (S2), `stage_ease_ticks` 60, `blend_ticks` 120, `plate_blend_ticks` 120, `grade_ticks` 90, `boss_rgb` (204, 196, 184), `boss_scroll_v_x100` 25, `warning_ticks` 150, `tally_scroll_pct` 25, `tally_grade_ticks` 60, `ED` caps 6 / 12 / 25 %, `dL` caps 28 / 48 / 80, zones EDGE 0 to 71 / 288 to 359, SHOULDER 72 to 119 / 240 to 287, CORE 120 to 239, `overscan_px` 8, `anim_max` 12, `env_vram_budget_mib` 28, wash alpha 153 (RF 64), 60 ticks/s. Stage 1 `E5` S = 1,167,360; Stage 2 `E5` S = 1,743,960.

**Test setup:** logic is in node-free `RefCounted` classes: `ScrollClock`, `ParallaxState` (ints only, `tick()`), `EnvLint` and `EnvValidator` (offline). Injected: loaded `.tres` files (`data/environment/*.tres`, `data/stages/stage_1_1941.tres`, `stage_2_1970s.tres`); a fake Director event bus that scripts `scroll_changed`, `stage_started`, `wave_started`, `warning_started(150)`, `tally_started`; a fake Enemy (a ground target with a recorded `S_spawn`); a fake Session (pause, `any_active`); small synthetic PNG fixtures for lint (generated in the test). No RNG is injected; a seeded RNG that fails on any call is passed to prove determinism. Tests live in `tests/unit/test_parallax_[scroll|layers|sections|boss|lint|ground|data].gd` and `tests/perf/parallax_bench.tscn`, `extends SceneTree` like `tests/unit/test_chain_tracker.gd`, named `test_parallax_[scenario]_[result]`. Numbers are read from the `.tres`, except the golden tables. Tags: [Unit] headless · [Integration] real Enemy / Display scaler · [Perf] REF-PC / REF-WEB (ADR-0001) · [Manual] human. Pixel measures use Rec.709 luma on gamma values, HSV saturation.

### Scroll model (Rules 1 to 6, F1, F2, F4)

- **AC-01 [Unit] (F1 ease):** v = 80 from `stage_started`: `v_eff(59)` = 78 and `v_eff(60)` = 80; `S(60)` = 2,340; `S(120)` = 7,140.
- **AC-02 [Unit] (Rule 3, active/pause):** with `any_active` false for 100 ticks at v = 80, `S` gains 8,000; paused ticks (no `tick()` call) change `S` and every `A_L` by 0.
- **AC-03 [Integration] (Rule 3, tick order):** the tick log shows `StageDirector` before `ScrollClock` before `EnemyManager` every tick; a ground enemy spawned on tick T reads the `S` of tick T.
- **AC-04 [Unit] (F1, golden):** Stage 1 nominal with the Director's floored blends: `S` at `E5` = **1,167,360**; Stage 2 = **1,743,960**.
- **AC-05 [Unit] (F2, rates):** v = 80 constant: after 100 ticks the draw offsets are L0 6, L1 20, L2 40, L3 80, L4 104; L0 first reaches 1 px on tick 16 (not 15).
- **AC-06 [Unit] (F2, wrap and closed form):** 1,000,000 ticks at v = 150: L1 offset = **1,240**; `A_L` stays below `loop_L x 10,000` on every tick; L3's offset equals `S div 100` on every tick.
- **AC-07 [Unit] (no float, determinism):** `ParallaxState` and `ScrollClock` have no `float` members; two runs of a scripted 3,000-tick `v` sequence give equal state hashes; the failing-RNG fixture is never called.
- **AC-08 [Unit] (F4 anchor, golden):** `S_spawn` 123,457, v = 85 for 100 ticks → `ground_dy` = 85; `S_spawn` 123,499 at v = 80 → `ground_dy` = 1 on tick 1.
- **AC-09 [Unit] (F4 lockstep):** across a 120-tick blend 80 → 90, the difference between a ground object's drawn y and the L3 feature it was placed on is 0 on every tick.
- **AC-10 [Integration] (real Enemy):** a flak gunner spawned in the last 100 ticks of Stage 1 wave 3 and alive across the wave 4 blend stays on its pad: drawn y minus terrain feature y = 0 for 600 ticks; its float hurtbox differs from the drawn y by at most 1 px.

### Chunks and passes (Rules 7 to 10, F3)

- **AC-11 [Unit] (F3, golden):** passes, Stage 1 = 0.875 / 1.065 / 1.247 / 1.313 / 1.544; Stage 2 = 1.080 / 1.265 / 1.467 / 1.647 / 1.763; all at most 2.0. A Stage 2 copy with `chunk_h` 1,920 gives 2.203 for wave 5 and fails V-E2.
- **AC-12 [Unit] (pool):** a full dry run of each stage never holds more than 3 chunks per layer; every chunk y is an int.
- **AC-13 [Unit] (dressing):** pass 1 uses dressing A, pass 2 B, pass 3 A; a prop marked A is absent in pass 2; the RNG fixture is not called.
- **AC-14 [Unit] (props):** live prop sprites never exceed 40; each prop's zone box obeys Rule 16.

### Sections and transitions (Rules 11 to 14)

- **AC-15 [Unit] (triggers):** `WAVE_START(n)` selects section n for n = 1 to 5 and `BOSS_WARNING` the arena; a wave that ends early (Director AC-11) moves the section change by the same amount; no section is bound to an absolute tick.
- **AC-16 [Unit] (seam):** on the trigger tick the new L3 chunk's leading edge is at y = 0; after 100 ticks at v = 90 it is at y = 90; the first 96 px of every chunk is a full-width opaque band (lint: 100 % opaque pixels).
- **AC-17 [Unit] (F5 crossfade):** alpha at t = 1 / 60 / 120 = 2 / 127 / 255; a second trigger at t = 50 completes the running blend (alpha 255) then starts a new one at alpha 0.
- **AC-18 [Unit] (unknown id):** an unknown `section_id` asserts in debug; in release the current section is kept and one error is logged.
- **AC-19 [Unit] (first section):** `stage_started` shows `s1_open_sea` (Stage 1) or `s2_high_haze` (Stage 2); `WAVE_START(1)` changes nothing.

### Boss arena and tally (Rules 19 to 22, F6, F7)

- **AC-20 [Unit] (plates):** with `warning_started(150)` at `E5 + 90`, plate alpha is 127 at `E5 + 150` and 255 at `E5 + 210`; the old L2 / L3 are hidden and freed at `E5 + 210`; the plates' draw offset stays 0 for 2,703 ticks.
- **AC-21 [Unit] (grade, F6):** the grade starts at `E5 + 240`; g = 45 → modulate (230, 226, 220); g = 90 → (204, 196, 184); 1941 Shadow luma after grade 39.5, 1970s Shadow 35.8; no pixel of any boss render is below 16.
- **AC-22 [Unit] (vignette, F7):** g = 90: x = 5 → 102, x = 70 → 18, x = 100 → 0, x = 355 → 102; g = 45, x = 5 → 51; alpha is 0 for every x from 72 to 287.
- **AC-23 [Unit] (boss crawl):** with v = 25 for 100 ticks: L0 moves 2 px, L1 6 px; the plates 0.
- **AC-24 [Unit] (tally):** at `tally_started` with v = 25: target v = 6; the grade is full at tick 0 and ends at 255 / alpha 0 after 60 ticks.
- **AC-25 [Unit] (desaturation, Rule 30):** `set_desaturation(60)` gives tint alpha 153, `(25)` gives 64, `(0)` hides it, `(80)` clamps to 153; the tint sprite is at layer 2 (z 21), below enemies and bullets; its colour equals the era Sky.

### Readability (Rules 15 to 18, F8, F9)

- **AC-26 [Unit] (palette luma):** the 12 palette entries measure within 0.1 of the table (e.g. 1941 Sky 123.6, 1970s Mid 125.2, 1970s Shadow 46.4) and all lie in 16 to 128.
- **AC-27 [Unit] (saturation and warm rule):** the five base entries of both eras are at most 55 % saturation; 1970s Accent measures 79.8 %; it passes only as an EDGE pixel set under 2 % of the frame with luma at most 105; the same colour in a CORE window, or at luma 106, fails.
- **AC-28 [Unit] (hue lock):** a pixel at hue 240 degrees and 40 % saturation fails; hue 210 degrees at 22 % passes; hue 235 degrees at 12 % passes and 13 % fails; both era palettes pass.
- **AC-29 [Unit] (ED, F8):** fixtures measure 2.17 % (one boundary), 4.35 % (one 1-px line), 8.33 % (crossed lines), 100 % (checkerboard); a CORE window at 6.1 % fails and at 6.0 % passes; SHOULDER limit 12 %; EDGE 25 % (and a section's `edge_ed_cap`).
- **AC-30 [Unit] (dL, F9):** 1970s Mid / Ground at 30.5 fails in CORE and passes in SHOULDER; with the 109.9 ramp step both 15.3 and 15.2 pass; 1941 Mid / Ground 22.1 passes in CORE.
- **AC-31 [Unit] (dark pixel):** a fixture containing Ink `#0B0B2A` (luma 13.2) fails; so does a pixel at luma 15.9; luma 16.0 passes.
- **AC-32 [Unit] (small regions):** an isolated 3 x 3 region with `dL` 20 fails in CORE; with `dL` 8 it passes; a single pixel fails in every zone; a 2 x 2 region with `dL` 20 passes in EDGE.
- **AC-33 [Unit] (L4 and dither):** an L4 sprite with box x 60 to 90 fails; x 0 to 71 passes; ordered 2 x 2 dither in a SHOULDER window fails and in an EDGE window passes; a regular dot grid in CORE fails by `ED`.
- **AC-34 [Unit] (animation budget):** a frame with 13 animated sprites fails; 5 animated in SHOULDER + CORE fails; any animated sprite in CORE fails; 2 sprites at 6 fps or faster between x 72 and 287 fail; the warning light cycle is 90 ticks with luma change 20.6.
- **AC-35 [Integration] (probes):** `EnvLint` places the 4 bullet sprites at the 12 probe points over every section render at three phases (12 sections x 3 phases): each passes `217 - bg_max >= 89` and the window range cap of its zone.
- **AC-36 [Manual] (grayscale gate):** two reviewers count bullets in the marked 100 x 100 px regions of a 300-bullet pattern-bench capture, in Rec.709 grayscale, on each of the 12 sections: 100 % of bullets counted; evidence saved to `production/qa/evidence/bg_gate_<section_id>_<phase>.png`.

### Pads and wreckage (Rules 25, 31, F11)

- **AC-37 [Unit] (pads, V-E5):** Stage 1 sections 2 to 5 and Stage 2 sections 2 to 4 have pad corridors x 72 to 150 and 210 to 288; Stage 2 wave 3 with a gunner at tick 2,100 passes only because wave 4 has pads; with wave 4 padless it fails (2,558 > 2,520) and tick 2,062 passes.
- **AC-38 [Unit] (wreckage):** wreck counts per chunk are S1 0 / 2 / 4 / 6 / 8 and S2 0 / 0 / 3 / 6 / 8, none above 8, all in SHOULDER or EDGE.
- **AC-39 [Unit] (sacred rule):** a section data check fails if a sacred silhouette sprite is in L2 / L3, in an arena plate, or inside a pad corridor.

### Memory, loading and layout (Rules 26 to 28, F10)

- **AC-40 [Unit] (VRAM):** the sum over the stage set equals 22.5 MiB (±0.1) from the texture sizes in data; no atlas is larger than 2,048 x 2,048; at most 28 MiB.
- **AC-41 [Integration] (staged load, Rule 27):** in the Era shift timeline the old set is still drawn at transition tick 52 and freed at tick 53 (not earlier); `prepare()` starts after `free_set()`, loads at most 1 resource per tick and finishes by tick 90 (at most 30 ticks from tick 53); old and new sets are never resident together (peak environment memory 22.5 MiB, device total at most 60.5 MiB, under the 36 MB per-era env budget); the new set is shown on `era_swap_committed`; `env_prepared` fires before `era_ready`.
- **AC-57 [Unit] (stage fade-in, Rule 28a, Era shift F5):** the overlay levels after `era_ready` are 85, 76, 66, 57, 47, 38, 28, 19, 9, 0 at 4-tick intervals (9 steps, each at most 10 points, never rising again); it ends 36 ticks after `era_ready`; no darkening step occurs within 60 ticks before it; a copy with a step of 12 fails the data check.
- **AC-58 [Unit] (vignette owner, Rule 30a):** Parallax draws the boss vignette at z 20 and VFX draws none; on `BOSS_ENRAGED` the outer band eases from 102 to 127 over 60 ticks (`102 x 125 div 100` = 127 after cap); x 72 to 287 stays 0.
- **AC-59 [Integration] (shared 150 cap, Rule 24):** with the VFX pool at 150 live, a Parallax smoke request evicts or is refused (never exceeds 150); at most 12 Parallax puffs are ever live; at effects level REDUCED or MINIMAL zero are requested; evicting all of them leaves the scene valid.
- **AC-42 [Integration] (overscan):** with a world-layer shake of 8 px in every direction, the SubViewport shows no clear-colour pixel; at 9 px the test reports the missing strip.
- **AC-43 [Unit] (co-op):** the layer state hash for N = 1 and N = 4 with the same `v` sequence is equal, and with `play_top` 48 and 72.
- **AC-44 [Unit] (scroll scale, Rule 29b, F2):** `set_scroll_scale(25)` with v = 80 for 100 ticks: L1 offset 5 px (500 units per tick), L0 1 px, L2 10 px, L3 80 px (unchanged), `S` gain 8,000 (unchanged); L4 hidden, prop animation frozen on frame 0; `set_scroll_scale(100)` restores the F2 table values with no offset jump.
- **AC-53 [Integration] (scale and ground sync):** with `set_scroll_scale(0)` a flat gunner on its pad for 600 ticks: drawn y minus L3 feature y = 0 on every tick; the hurtbox y still equals the gameplay position (differs by at most 1 px from drawn).
- **AC-54 [Unit] (background modes, Rule 29a, F12):** DIMMED: `dim` = 166, 1941 Sky luma 123.6 → 80.5, 1970s Sky 119.9 → 78.0, boss-graded 1970s Shadow 35.8 → 23.3; enemies, bullets, planes, items, ground targets and HUD modulate stay exactly 1.0. PLAIN: all environment nodes hidden, fill luma 51.1 (1941) or 46.4 (1970s), vignette hidden, hue not in 225 to 265 degrees.
- **AC-55 [Unit] (mode easing):** switching FULL → DIMMED during a stage steps the modulate through 100, 90, 80, 70, 65 % at 8-tick intervals (each step at most 10 points); the same switch in a menu snaps in one tick; PLAIN fill alpha rises in steps of at most 10 %.
- **AC-56 [Integration] (gate in modes):** the 12-probe test of AC-35 passes for FULL, DIMMED and PLAIN on all 12 sections; the Manual capture of AC-36 passes for the busiest 4P frame of each era in each mode.
- **AC-45 [Unit] (debug restore):** a snapshot taken at a wave start and restored returns `S` and all `A_L` to the same values and sets `run.debug_tainted`.

### Performance

- **AC-46 [Perf] (logic):** `ScrollClock.tick()` + `ParallaxState.tick()` ≤ **0.03 ms p99** (mean ≤ 0.01 ms) on REF-PC and REF-WEB; zero allocations per tick over 1,000 ticks.
- **AC-47 [Perf] (view):** `ParallaxView` update ≤ **0.30 ms p99 per frame** on REF-WEB with 40 live props and 12 animated sprites; chunk instantiation (tile data assignment) ≤ **1.0 ms p99**; no frame at a seam exceeds the median frame time by more than 3 ms.
- **AC-48 [Perf] (draw calls):** with the Bullet manager benchmark (2,000 bullets, 4P) the parallax part is at most **8** draw calls steady and **10** during a crossfade; total stays under 200 (art bible 8.6).
- **AC-49 [Perf] (REF-PHONE, report-only):** gameplay ticks stay at 60 per second; rendering at 30 fps or better; average layer overdraw at most 3.5 px per canvas px; reported, not gated.

### Playtest (Manual)

- **AC-50 [Manual] (readability):** 6 testers play Stage 1 and 2 at 1P and 4P; at least 5 of 6 say "I could always see the bullets"; none reports background shimmer or flicker; the three busiest captured frames pass AC-36.
- **AC-51 [Manual] (ground sync):** a 10 s capture of a flak gunner crossing the screen at x 110, stepped frame by frame, shows zero frames where the gunner moves relative to its pad.
- **AC-52 [Manual] (cultural review):** a native-speaker review signs off the lighthouse, dock house, dome silhouette (if kept) and carrier-fleet landmarks before the art is locked (art bible 6.1).

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | `ScrollClock` lives in the Director module (to avoid Enemy depending on a Presentation system). Confirm, or move it to Session. | Wave (16), Enemy (10) | Director review |
| 2 | Ground enemies now follow live `S` instead of a speed frozen at spawn (Amendment 2b, 3a). This changes Director AC-28's last clause. Confirm. | Wave (16), Enemy (10) | Next review |
| 3 | The 1970s Accent `#A85A22` is 80 % saturation (art bible says 55 %) and shares hue with Tracer Orange. Confirm the warm rule (luma at most 105, edge only, under 2 % of frame) or darken the Accent. | Art director | Art review |
| 4 | The optional domed silhouette on L1 in `s1_harbour` needs a cultural review; if rejected, replace with a generic water tower. | Art director, narrative | Before art lock |
| 5 | The 1970s cantilever bridge (one crossing in the delta) sits in the lane as a 360 x 48 shape. Keep or drop? | Art director | Section art pass |
| 6 | Parked jets in `s2_airbase` could be mistaken for enemy delta jets (lighter, no outline, edge only). Playtest. | Art director, playtest | First Stage 2 playtest |
| 7 | Parallax draw calls: 8 steady / 10 transient exceeds the art bible's 5 to 8. Accept, or avoid the crossfade second draw. | Technical artist | Spike |
| 8 | Godot 4.7 details are unverified: `TileMapLayer.tile_map_data` assignment cost, tile animation frames, pixel snap settings, Web loading without threads. Spike and re-check. | Technical artist | Art spike (art bible 8.9) |
| 9 | 3-4P: the HUD strip is 72 px, so the top 72 px of the background are hidden. Is the Stage 2 sodium horizon (top 160 px) still visible enough? | Art director, HUD | UX review |
| 10 | Stages 3 and 4 (night grid, plasma void) are not designed here. Their edge-neon exception (luma 160), rain cap, and shard layers need their own section tables. | Art director | Target milestone |
| 11 | Should Results / Game over reuse the arena plates as a backdrop, or draw their own (Menus 22)? | Menus (22) | Menus GDD |
| 13 | `set_scroll_scale` cannot slow the terrain under ground targets (L3) without changing gameplay. Is that acceptable for Reduce motion, or should Accessibility pair it with `game_speed_pct`? | Accessibility (28), designer | Accessibility review |
| 14 | VFX Open Question 5 is closed here (Parallax renders the vignette). Confirm VFX removes `fx_boss_vignette` from its effects list. | VFX (25) | VFX review |
| 12 | Sections switch with spatial seams for L2 / L3 only. If playtests show a visible "pop" at a seam, try a 24-tick alpha overlap on the boundary band. | Art director | First playable |
