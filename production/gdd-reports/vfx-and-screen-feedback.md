# Report: VFX and screen feedback (system 25)

## 1. File written
`design/gdd/vfx-and-screen-feedback.md` (Designed, pending review). It defines VFX as a presentation-only layer: a tick-driven pool of 150 effect instances drawn in 8 MultiMesh bands below the enemy bullets, with five priority tiers, class caps and an eviction rule. It has a full effect catalogue (about 45 ids with trigger, layer, size, frames, colour role, era variants, cost, tier), the screen-feedback policy, era treatment, co-op density, accessibility levels, a perf budget and 51 acceptance criteria. It collects every VFX requirement stated by the other GDDs and the art bible and resolves their open "VFX decides" items.

## 2. Key decisions (changeable)
- **Backend:** CPU-driven sprite effects in pooled MultiMeshes (8 bands, at most 8 draw calls). No GPUParticles2D / CPUParticles2D for gameplay effects. The 4.7 Web GL Compatibility behaviour of particle nodes is flagged unverified (art bible spike 4). Fallback: a pool of 150 AnimatedSprite2D nodes.
- **Presentation only and tick-driven:** the frame is a function of `tick - start_tick`. Own seeded VFX RNG (`hash(run_seed, "vfx")`). Gameplay state hash must be identical with effects on or off.
- **Budget:** 150 live total (art bible cap), 15 non-additive class caps, tiers T0-T4 (CB, death rings, tells > MEDIUM/LARGE, part kills, bomb rings > SMALL, cancel puffs, dust, clanks > debris, chips, muzzle > weather and smoke). Eviction: oldest instance of the lowest-priority tier. Debris first, then SMALL, which matches Enemy V3.
- **Screen policy:** no hit-stop; the only flash is the Critical Break frame (exactly one rendered frame, guaranteed even at 30 fps render); **no global shake**, because a shaken field moves bullets against a 6 px hitbox (Readable Chaos) and the Display scaler needs integer stability. The only shake is the boss-sprite offset at a Critical Break (4 px, 8 ticks, integer decaying table, hurtboxes do not move). No full-screen tint except the CB background tint (background layers only).
- **Co-op:** cosmetic classes scale 100 / 100 / 80 / 70 percent by `N`; at most 2 full death rings, the 3rd and 4th use a compact ring (closes Co-op V2).
- **Accessibility:** existing `access.reduce_flashing`, plus new `access.effects_level` (FULL 100 / REDUCED 50 / MINIMAL 25 percent; REDUCED drops weather, smoke, pops, flares, shake; MINIMAL keeps only T0-T1) and new `access.reduce_pulsing`.
- **Cancel feedback:** a cancel of 0 bullets shows nothing; CB's own cancel is capped at 12 puffs and has no ring; part-kill rings are filled puff rings (12, last part 16); MEDIUM/LARGE kill cancels get a thin Cream-Gold ring (80 / 144 px).
- **Gem sparkle = 1 particle** (rate limit 1 per 2 ticks, 12 live), deviating from Powerups V4's cluster of four, so a 100-gem sweep cannot fill the pool.
- **Bomb dust cap is global (40)**, not 40 per bomb.
- **Era:** MVP eras 1941 and 1970s; 2030s and 2100 extras (+2 / +4 shard chips) ride the DEBRIS class so they are evicted first. Glow is a pixel halo inside the frames, no additive blend.
- **Hit tint** applied by VFX; implementation (shader instance uniform vs white-silhouette frames) left to a spike.
- **Boss vignette** rendered by VFX band B0 unless Parallax takes it.
- Retire the prototype `screen_flash_requested` and `popup_requested`.

## 3. Amendments
1. `design/gdd/systems-index.md` row 25: status `**Designed** (pending review) — [GDD](vfx-and-screen-feedback.md)`; Depends on `1, 3, 5, 6, 9, 10, 11, 12, 13, 14, 17, 18 (soft: 4, 23, 26)`. Progress tracker: GDDs written +1 and add "VFX and screen feedback" to the list.
2. `coop-and-team-chain.md` V2 row "Big-effect cap": replace "Proposed; VFX decides" with "At most 2 full death rings, others compact (VFX 25 Rule 23)"; Dependencies: add VFX (25).
3. `display-scaler-and-bezel.md` Open Question 5: close it ("no global shake exists, so no overscan margin; only a boss-sprite offset of at most 4 px"); update the VFX row in Interactions.
4. `bullet-manager.md` Interactions: add "VFX (25) reads `cancel_report` (cause slot, area, cancelled positions in pool order, count) and `clear_report` each tick"; V6: puff live cap 40 across all sweeps, CB cancel samples at most 12.
5. `powerups-and-drops.md` V4: gem sparkle is one 2-frame 4 px particle, at most 1 per 2 ticks and 12 live; the four-particle cluster stays for medal, chain, pod, 1UP.
6. `game-events-and-session.md` Visual section (~line 321) and signals: `screen_flash_requested` deprecated (CB frame driven by `critical_break_landed`); remove `popup_requested`. Prototype code: delete the `screen_flash_requested.emit(0.4 / 0.3 / 0.12)` calls in `src/gameplay/player/player.gd` (lines ~107, 119, 129) and `src/gameplay/boss/boss.gd` (~157), and the `PopupLayer` use, when VFX is implemented.
7. `critical-break.md` V1-V2: CB cancel puffs capped at 12; shake applied by VFX (off at REDUCED and MINIMAL); reduce-flashing burst scales by `level_pct`; `set_desaturation(pct)` call to Parallax.
8. `collision-damage-lives.md` Interactions: add event `hit_feedback(target_id, result, pos, tick)`; V2 "oldest dropped first" is the SPARK overflow rule; Dependencies: add VFX (25).
9. `enemy-and-ai.md` V3 "Cap behaviour": reference VFX tiers (debris T3, SMALL T2, MEDIUM/LARGE T1); Dependencies: add VFX (25).
10. `boss-and-boss-parts.md` V4: vignette rendered by VFX band B0 (unless Parallax); death sequence is class BOSS_DEATH (40) in the shared pool; Dependencies: add VFX (25).
11. `save-settings-high-scores.md` schema table (~line 110): add `access.effects_level` (enum FULL/REDUCED/MINIMAL, default FULL) and `access.reduce_pulsing` (bool, default false), registered by Accessibility (28).
12. `player-plane.md`: `player_died(slot)` must carry the plane position (or `get_position(slot)` valid on the death tick); Dependencies: add VFX (25).
13. `design/art/art-bible.md`: §8.6 Particles row: 150 is the hard total, class caps are non-additive (explosions 24 + debris 56 = the old 80), tiers decide eviction; §6.8: add the `z_index = layer*10 + sub` mapping and the band table; §7.9: "screen-shake" means the local boss shake only; §4.6: confirm alert amber (also needed by Pattern library); §8.3: ring-baking note and effect sprite list.
14. `bombs.md` V1-V2: BOMB_DUST is a global cap of 40 shared by all bombs; Dependencies: add VFX (25).
15. Pending asks for unwritten GDDs: Accessibility (28) registers and shows the two new `access.*` keys; Parallax (23) provides `set_desaturation(pct)` and counts weather in the 150 cap (4P: weather is the first thing evicted); Pattern library/Wave director state a max concurrent flak fuses (VFX assumes 8).

## 4. Registry candidates
```yaml
  - name: vfx_particle_cap
    value: 150
    unit: live pooled effect instances (all players)
    range: "100-200"
    note: "Art bible 8.6 total. Class caps are non-additive; tiers T0-T4 decide eviction."
    source: design/gdd/vfx-and-screen-feedback.md (Rule 16)
    referenced_by: [vfx-and-screen-feedback, bullet-manager, collision-damage-lives, enemy-and-ai, boss-and-boss-parts]
  - name: vfx_effects_levels
    value: "FULL 100, REDUCED 50, MINIMAL 25 (level_pct)"
    unit: percent of counts; setting access.effects_level
    source: design/gdd/vfx-and-screen-feedback.md (Rule 21)
    referenced_by: [vfx-and-screen-feedback, save-settings-high-scores]
  - name: vfx_density_by_players
    value: "100 / 100 / 80 / 70 (N = 1..4), tier 3-4 classes only"
    unit: percent
    range: "50-100"
    source: design/gdd/vfx-and-screen-feedback.md (F2)
    referenced_by: [vfx-and-screen-feedback, coop-and-team-chain]
  - name: death_ring_full_max
    value: 2
    unit: full death rings at once (others compact)
    range: "1-4"
    source: design/gdd/vfx-and-screen-feedback.md (Rule 23)
    referenced_by: [vfx-and-screen-feedback, collision-damage-lives, coop-and-team-chain]
  - name: cancel_puff_caps
    value: "sweep 40, Critical Break cancel 12"
    unit: puffs per cancel request
    range: "20-60 / 0-24"
    source: design/gdd/vfx-and-screen-feedback.md (F3)
    referenced_by: [vfx-and-screen-feedback, bullet-manager, bombs, critical-break]
  - name: setting_access_effects_level
    value: "access.effects_level (enum FULL/REDUCED/MINIMAL, default FULL)"
    unit: setting key
    note: "Registered by Accessibility (28), stored by Save (26)"
    source: design/gdd/vfx-and-screen-feedback.md (Rule 34)
    referenced_by: [vfx-and-screen-feedback, save-settings-high-scores]
  - name: setting_access_reduce_pulsing
    value: "access.reduce_pulsing (bool, default false)"
    unit: setting key
    source: design/gdd/vfx-and-screen-feedback.md (Rule 34)
    referenced_by: [vfx-and-screen-feedback, save-settings-high-scores]

formulas:
  - name: cancel_puff_sample
    expression: "stride = ceil(n / cap_puff); puff iff i mod stride == 0; kept = ceil(n / stride)"
    variables: [n, cap_puff, stride]
    output: "0..cap_puff (1350 -> 40 at cap 40, 12 at cap 12)"
    source: design/gdd/vfx-and-screen-feedback.md (F3)
    referenced_by: [vfx-and-screen-feedback, bullet-manager, powerups-and-drops]
  - name: fx_evict_victim
    expression: "oldest instance of the highest tier number > request tier t; else (t <= 1) oldest of tier t; else drop"
    variables: [t, tier_j, start_tick]
    output: "pool index or none"
    source: design/gdd/vfx-and-screen-feedback.md (F6)
    referenced_by: [vfx-and-screen-feedback]
  - name: fx_ring_diameter
    expression: "diam(t) = d0 + ((d1 - d0) * t) div T"
    variables: [d0, d1, T, t]
    output: "bomb 36->480/12; CB 24->360/18; death 40->80/18"
    source: design/gdd/vfx-and-screen-feedback.md (F7)
    referenced_by: [vfx-and-screen-feedback, bombs, critical-break, collision-damage-lives]
```
Existing entries to gain `vfx-and-screen-feedback` in `referenced_by`: `setting_access_reduce_flashing`, `kill_cancel_radius`, `part_cancel_radius`, `last_part_cancel_radius`, `death_fire_hold`, `enemy_plating`, `player_hitbox_radius`, `canvas_size`, `max_players`.

## 5. Conflicts
- **Art bible §8.6 particle split** (rain 40 / explosions-debris 80 / smoke 30 = 150) vs other GDDs' effects (cancel puffs 40, CB burst 60-80, boss death 40, bomb dust 40, tells). Not a locked-value conflict. Resolved by reading 150 as the hard total, class caps as non-additive, and explosions 24 + debris 56 = 80. Needs art bible amendment 13.
- **Powerups V4** (cluster of four per pickup) vs a 100-gem sweep: gem sparkle reduced to one particle (amendment 5).
- **Critical Break V1** reduce-flashing burst of 80 would fill more than half the pool; accepted (fits 150) but scaled down at REDUCED/MINIMAL.
- **Prototype code** emits `screen_flash_requested` for part down, death and bombs, which violates "only Critical Break flashes" (amendment 6).
- **`gameplay-code.md` rule** says "use delta time"; ADR-0001 mandates integer ticks. The GDD follows ADR-0001 (Open Question 12).
- Locked registry values: none contradicted.

## 6. Open risks
- Large thin rings (up to 480 px) without a shader or `draw_circle`: the quadrant-bake plan needs a VRAM/load-time spike.
- Hit tint without a per-sprite material depends on shader instance uniforms working in Compatibility on Web (unverified in 4.7), else extra white-silhouette art.
- MultiMesh pack cost for 150 instances in GDScript on REF-WEB is unmeasured (budget 0.25 ms tick, 0.35 ms pack are proposals).
- Weather (Parallax) is the first thing evicted in boss fights; if Parallax plans particle nodes, it must still count against the 150 cap.
- Unbounded concurrent flak fuses would stress the TELL class (assumed 8).
- A 4 px boss-sprite shake makes the visual 4 px off the hurtbox for 8 ticks; low risk because the boss is dying.
- The 4P stress scenario B evicts 82 instances (T3 and weather); readability of kills in a bomb storm needs a playtest.
