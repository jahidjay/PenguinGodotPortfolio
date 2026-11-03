# VFX and Screen Feedback

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (technical-artist) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (primary), Every Hit Counts, History Accelerates, Four Planes Four Games (slot colour and pattern on rings and tells)

## Overview

**The data layer:** VFX is a presentation-only layer. It listens to gameplay events, spawns **pooled effect instances** from `EffectDef` resources (`data/vfx/`), and draws them below the enemy bullets. An instance is a small record (def id, start tick, integer position, colour variant, seed). Its frame is a pure function of `tick - start_tick`, so it is deterministic, pause-safe and never touches gameplay state. One **shared budget** (150 live instances, the art bible cap) is split into classes and **priority tiers**. When the pool is full, lower-priority effects are evicted first. The system also owns the **screen-feedback policy**: no hit-stop, one screen flash (Critical Break), no global shake, sprite-level hit tints only, and the accessibility switches that weaken all of it.

**The player impact:** The screen feels loud without getting harder to read. Kills pop, bombs roar, the Critical Break lands with one white frame, and none of it ever covers an enemy bullet. In a 4P bomb storm the effects thin out before the bullets do. A player who is photosensitive or easily distracted can turn the flash into a particle burst and dial effects down, and still play the same game.

## Player Fantasy

"Everything I hit goes boom, and the boom never hides the thing that can kill me." The explosions are the reward layer: chunky, warm, era-coloured, and always one layer under the bullets. The one white frame of a Critical Break is the loudest thing in the game because nothing else is allowed to be loud in that way.

## Detailed Design

### Core Rules

**A. Principles (hard)**

1. **Bullets always win.** Every VFX instance draws on a layer below the enemy bullets (layer 8). The only things above layer 8 are hitbox dots and rings (9), the Critical Break flash frame (10) and the HUD (11). **Era-card exception (2026-11-03, wave 4):** the era-card time-dust and reveal burst (Era shift 19 Rule 21) draw on layer 11 inside the era card. This is allowed because no enemy bullet exists during the era transition (the field is clear from the tally to `era_ready`); they still count against the shared 150 cap and Era shift's 24-particle cap. No VFX effect, colour, shape or shader touches the bullet MultiMesh.
2. **Presentation only.** VFX reads events and writes nothing back. It never calls a gameplay request method, never uses the gameplay RNG, and never changes a tick. Turning every effect off must leave the gameplay state hash unchanged (AC-02).
3. **Tick-driven.** Frame, position, opacity and expiry are pure functions of the integer tick counter (60 Hz, ADR-0001). No `delta`, no `Tween`, no `AnimationPlayer` timing for pooled effects. When the game pauses, ticks stop and every effect freezes.
4. **No hit-stop, no time scaling, no render freeze** (Critical Break Rule 24). Input latency and tick determinism win.
5. **One flash.** The only full-screen flash is the Critical Break frame (art bible §2, §6.8). *(2026-11-03:)* its exactly-one-rendered-frame guarantee is implemented per **ADR-0006** (`FlashState` tick + `FlashPresenter` render-side one-shot); at 144 Hz the frame lasts ~7 ms. No other event may flash, tint or dim the whole screen: not part kills, not bombs, not deaths, not era changes, not boss entry.
6. **No global shake.** The camera, the SubViewport and the bezel never move. The only shake is a local sprite offset on the boss at a Critical Break (Rule 28). Any shake amplitude is capped at the Parallax overscan `bg_overscan_px` = 8 px (Parallax 23 Rule 26; 2026-11-03, wave 3b); the default 4 px sits inside it. Reasons: a shaken field moves every bullet against the 6 px hitbox (Readable Chaos); the Display scaler requires integer-pixel stability (Display scaler rule); and it costs nothing on Web frame pacing.
7. **Particles, not flashes.** Energy is carried by bursts, debris, smoke and rings (art bible §2).
8. **Sprite-based.** All effects are sprites from the effects atlas. No `draw_line`, `draw_circle`, no additive blend, no per-effect materials, no full-screen shader (art bible §8.6).

**B. Architecture (behaviour level)**

9. **Components** (all node-free `RefCounted` logic with `tick()`, ADR-0001):
   - `VfxDirector`: subscribes to events (Interactions table) and turns each into `spawn(def_id, pos, params)` calls. Holds the accessibility level and the player count `N`.
   - `EffectPool`: fixed arrays of 150 instances (plus 16 decals). Owns eviction, expiry and the budget.
   - `FlashState`: the Critical Break frame state machine (States and Transitions).
   - A thin **renderer** (a node) copies live instances into the MultiMeshes each frame. It holds no rules.
10. **Render backend (recommended): CPU-driven sprite effects in pooled MultiMeshes**, one MultiMesh per draw band, one shared effects atlas per era plus one shared atlas, one palette material per era per atlas (art bible §8.4, §8.6). Eight bands, so at most 8 draw calls (art bible: "effects up to 8 particle systems"):

| Band | z_index | Contents |
|---|---|---|
| B0 | 20 | Scorch decals (the boss vignette is rendered by Parallax 23 Rule 20; 2026-11-03, wave 3b) |
| B1 | 22 | Ground explosions, wreck smoke |
| B2 | 50 | Dust, smoke (air) |
| B3 | 51 | Explosion sprites |
| B4 | 52 | Debris |
| B5 | 53 | Cancel rings, puffs, shockwaves, CB burst |
| B6 | 54 | Hit sparks |
| B7 | 55 | Tells (lock, flak, reticle) |
| B8 | 63 | Pickup and gem sparkles (layer 6, above items) |

   `z_index = layer * 10 + sub`. Bands B0 and B1 are layer 2 and may share one MultiMesh if profiling shows the draw call matters (→ ADR on bands). Enemy bullets sit at z 80, hitbox dots at 90, the CB frame at 100, HUD at 110.
11. **Why not GPUParticles2D or CPUParticles2D.** Particle nodes cannot be tied to the tick counter (pause and determinism), cannot be counted in one shared budget with priority eviction, cannot be capped per class, and add a node and a draw per emitter. **GPUParticles2D in the 4.7 Web export on the GL Compatibility renderer is unverified** and is the exact risk art bible §8.9 spike 4 names. Decision: do not use particle nodes for gameplay-timed effects. Weather (owned by Parallax 23) may use them only if the spike passes and its instances are still counted against the 150 cap. Fallback if the MultiMesh path is too slow: a pool of 150 `AnimatedSprite2D` nodes (heavier; → ADR).
12. **Effect definitions** live in `data/vfx/effects.tres` (`EffectDef`: `id`, `class`, `tier`, `band`, `size_px`, `frame_ticks[]`, `anchor`, `cost`, `colour_role`, `era_variants`, `min_level`) and the budget in `data/vfx/vfx_budget.tres`. No magic numbers in code (technical preferences).
13. **VFX RNG.** Debris fans and scatter use a separate `RandomNumberGenerator` seeded from `hash(run_seed, "vfx")`. It is never the gameplay RNG, so effect level cannot change gameplay (Boss V4 states the same rule). Where the Boss GDD gives a fixed position table, the table wins.
14. **Pixel rules.** Positions are integers. Sprites with outlines never rotate except in 90 degree steps. Outline-free rings and puffs may be pre-drawn at stepped sizes (art bible §8.3). No filtered scaling.
15. **Ownership boundary.** VFX owns **pooled transient effects** (bursts, debris, rings, puffs, sparks, tells, sparkles, flares, splashes). Other systems own the **sprites of persistent state** and VFX only accounts for them in the draw-call budget:

| Owner | Persistent sprites (not in the pool) |
|---|---|
| Plane kits (11) | Lancer beam body, parked-drone beam, Leech tether, drones, nose lens glow, afterglow |
| Bombs (12) | Lance Sweep column tile, Leech bomb hook |
| Enemy (10) / Boss (14) | Enemy and part sprites, tell pose frames, carrier rim pulse, plating, crack overlay, damage states, stumps |
| Powerups (13) | Item sprites, pop-in, bob, expiry pulse |
| Collision (6) | Hit-tint rules and throttles (VFX applies them) |
| HUD (20) | Everything on layer 11 |

**C. Budget and priority**

16. **Pool cap.** `vfx_particle_cap` = 150 live instances in total, for every player count (art bible §8.6). "One particle" = one live sprite instance in the pool: a pre-drawn cluster sprite (a 40 px explosion) costs 1, one debris chunk costs 1. Decals (scorch) are a separate pool of 16.
17. **Tiers** (lower number = more important; used for eviction, F6):

| Tier | Meaning | Members |
|---|---|---|
| T0 | Never lost: gameplay information or the payoff | Critical Break burst and shockwave, CB core ring and window arc (`fx_cb_core_ring`), death rings, player Dying explosion, lock tells, flak fuse and burst, boss final explosion |
| T1 | Never dropped by a lower tier | MEDIUM and LARGE bursts, boss part-kill burst and puff ring, boss death sequence, bomb rings and Leech detonation, cancel shockwave rings, armour clank and immune ping (`fx_clank`, `fx_ping`: the visual twins of sound-only cues, Accessibility 28 Rule 30; 2026-11-03, wave 3b) |
| T2 | Important feedback | SMALL bursts, cancel puffs, death dust, bomb dust, pickup sparkles (non-gem), drone pops, plate fall |
| T3 | Decoration | Debris, normal hit chips, muzzle flashes, kit flares and splashes, gem sparkles, FlyIn puffs, expiry puffs, intro sweep |
| T4 | Ambience | Weather, damage smoke, wreck smoke |

18. **Class caps** (non-additive; they sum to more than 150 on purpose, the pool cap and tiers resolve it). Caps in the table are for FULL level and `N` = 1-2. Cosmetic classes (tier 3-4) scale by player count and level (F2).

| Class | Cap | Overflow | Source |
|---|---|---|---|
| EXPLOSION (burst sprites, air and ground) | 24 | evict oldest | Art bible §8.6 (24 pooled explosion sprites) |
| DEBRIS | 56 | drop request | Art bible: explosions plus debris = 80 (24 + 56) |
| SPARK (all hit sparks) | 24, of which armoured or immune at most 8 | evict oldest | Collision V2 |
| CANCEL_PUFF | 40 | drop request | Bullet manager V6 (about 40 per sweep) |
| CANCEL_RING | 8 | evict oldest | This GDD |
| DEATH_DUST | 10 | drop request | Collision V1 (6-10) |
| BOMB_DUST | 40 shared by all bombs | drop request | Bombs V2 (at most 40) |
| BOSS_DEATH | 40 | drop request | Boss V4, art bible §6.8 note |
| CB_BURST | 80 | evict oldest | Critical Break V1, V2 |
| TELL | 40 | evict oldest | 4 locks x 2 + 4 broken reticles x 4 + 8 flak fuses x 2 (8 = Pattern library cap of lit fuses per scene) |
| MUZZLE | 12 | drop request | This GDD |
| KIT_FLARE | 12 (8 reserved for the four main beams) | drop request | This GDD |
| PICKUP | 24 (gem sparkles at most 12) | drop request | This GDD |
| SMOKE | 30 | drop request | Art bible §8.6 |
| WEATHER | 40 | drop request | Art bible §8.6 (rain 40) |

19. **Eviction (F6).** A spawn request of tier `t` is admitted if the pool has a free slot and its class is under its cap. Otherwise:
    1. If the class is full: classes marked "evict oldest" free their own oldest instance; classes marked "drop request" refuse the request.
    2. If the pool is full: evict the **oldest instance of the highest-numbered tier that is greater than `t`**. If no such instance exists and `t` is 0 or 1, evict the oldest instance of tier `t` itself. If `t` is 2 or more, the request is dropped.
    3. T0 and T1 requests are never refused while any instance of a lower-priority tier or the same tier exists.
    4. An evicted instance disappears on that tick (no fade). Evictions and drops are counted for the debug overlay.
20. **Enemy Rule alignment.** Enemy V3 says "debris drops first, then SMALL bursts; MEDIUM/LARGE never dropped". Tiers give exactly that order (debris T3, SMALL T2, MEDIUM and LARGE T1).
21. **Accessibility levels** (`access.effects_level`, enum `FULL` default / `REDUCED` / `MINIMAL`, Rule 34):

| Level | `level_pct` | Tiers drawn | Also |
|---|---|---|---|
| FULL | 100 | T0-T4 | Everything |
| REDUCED | 50 | T0-T3 | No weather, no wreck or damage smoke, no secondary pops, no kit flares, no local shake, era extra debris off |
| MINIMAL | 25 | T0-T1 | Only explosions, rings, tells, Critical Break. Single-frame bursts, no debris, no sparkles |

    The effective pool cap is `floor(150 * level_pct / 100)` (F1).
22. **Co-op density** (F2): cosmetic classes (tier 3-4) scale by `dens_pct(N)` = 100 / 100 / 80 / 70 for `N` = 1 / 2 / 3 / 4. T0-T2 never scale by `N`, because they carry information. Enemy bullet density never scales with `N` (Co-op Rule 15), so VFX is the only thing that thins out.
23. **Big-effect cap in co-op** (closes Co-op V2 "VFX decides"): at most **2 death rings are drawn in full** at once. The third and fourth use the **compact ring** (40 to 56 px in 12 ticks, same player colour and pattern, pips kept). Every dying plane still gets its own explosion. The screen clear, dust and clear sound play once (Collision V4).

**D. Draw layers and colour**

24. **Layer assignment:**

| Layer | z_index | VFX content |
|---|---|---|
| 2 (environment FX) | 20-22 | Scorch, ground explosions, wreck smoke (boss vignette: Parallax 23) |
| 3 | 30 | None (ground targets are Enemy sprites) |
| 4 | 40 | None (CB burst on the boss is on layer 5, above the boss) |
| 5 (air FX) | 50-55 | Dust, smoke, explosions, debris, cancel fx, CB burst and ring, sparks, tells |
| 6 | 63 | Pickup sparkles (above items at 62, shots at 61, beams at 60) |
| 7, 8, 9 | 70, 80, 90 | None from VFX |
| 10 | 100 | CB flash frame only |
| 11 | 110 | Banner and popup (Critical Break, HUD); era-card time-dust and reveal burst (Rule 1 exception, no bullets during the era transition; wave 4) |

25. **Colour roles.** Effects use roles, not hex, so eras and accessibility can recolour without code. Never Void Indigo `#4A5CFF`, never Ink `#0B0B2A`, never any fill with hue 225-265, never a reserved bullet shape (orb, rice, needle, outlined ring), and no dark outline on effects.

| Role | Colour | Used for |
|---|---|---|
| WARM | Shot palette `#FFF2B0` / `#FFB82E` / `#FF7A1A` | Player shots, muzzle flares, impact splashes |
| BOMB | Tracer Orange `#FF8A1F` with Cream | Bomb rings, dust, detonation |
| BURST | Era explosion palette (Era treatment) | Enemy, boss and plane explosions, debris |
| SHADOW | Era Shadow (art bible §4.5) | Dust, flak puff, smoke, boss puff ring |
| GOLD / CREAM | `#FFC93C` / `#F4EBD6` | Cancel puffs, pickups, chips |
| AMBER | Alert amber (Pattern library V2; `#FFB000` pending art bible §4.6) | Flak spark, tell glow |
| SLOT | P1 `#FF5A36`, P2 `#F5E02E`, P3 `#2FD27A`, P4 `#FF8AD8` plus pattern and pips | Death ring, lock line, reticle |
| CB | `#FFF4D0` / `#FFB347`, flash `#FFFFFF` | Critical Break only |

**E. Event-to-effect rules**

26. **Cancel feedback** (Bullet manager V6). One request of a cancel produces: the area ring (class CANCEL_RING) and puffs sampled by F3 (class CANCEL_PUFF). Cancelled bullets vanish instantly; no ghost, no fade. A request that cancelled 0 bullets produces **no** effect at all (a bomb in an empty field still shows its own bomb ring, which is a bomb effect, not a cancel effect).

| Source | Ring | Puffs |
|---|---|---|
| Bomb (`k = 0`) | Tracer Orange to Cream, 36 to 480 px over 12 ticks (F7) | GOLD / CREAM, cap 40 |
| Part kill | Filled puff ring (12 puffs) to radius `part_cancel_radius` 90 over 8 ticks, SHADOW | GOLD / CREAM, cap 40 |
| Last part kill | Same, 16 puffs to `last_part_cancel_radius` 150 | cap 40 |
| MEDIUM / LARGE kill | Thin 2 px Cream-Gold ring, diameter `2 * kill_cancel_radius` (80 / 144) over 8 ticks | cap 40 |
| Critical Break cancel | None (the white frame and the CB shockwave cover it) | **cap 12** |
| Death clear | None (one death ring instead, Rule 29) | None (grey DEATH_DUST instead) |
| Stage clear-all | None (Bullet manager: no FX) | None |

27. **Kill explosions** (Enemy V3): SMALL 20 px, 3 frames, 12 ticks, 3 chunks; MEDIUM 40 px, 4 frames, 18 ticks, 6 chunks, 1 smoke puff; LARGE 72 px, 5 frames, 36 ticks, 12 chunks, 2 secondary pops at +8 and +16 ticks, wreck smoke. Ground targets: the burst and smoke go to band B1 (layer 2) and leave a scorch decal for 180 ticks. One explosion per target (Collision C6 destroys once). Explosions are era-coloured, never player-coloured.
28. **Critical Break** (Critical Break V1-V2, Rule 25; VFX renders it, Critical Break times it):
    - `T+1`: **one white frame**, 360 x 640, `#FFFFFF` 100%, layer 10. Guarantee: it is shown for exactly one **rendered** frame (FlashState).
    - `T+1` to `T+36`: CB shockwave (thin ring, `#FFF4D0` to `#FFB347`, 24 to 360 px over 18 ticks), heavy burst of 60 particles (`#FFB347` / `#FFF4D0`, 3-6 px, life up to 30 ticks), background desaturation (Parallax interface: ramp 6, hold 18, ramp 12, at most 60%).
    - Boss sprite local shake: amplitude `cb_shake_px` 4, `cb_shake_ticks` 8, F5. Draw offset only; hurtboxes do not move.
    - The boss death sequence (180 ticks) starts as Boss specifies and shares the pool (Budget scenario A).
    - **Reduce flashing:** no white frame. Replace with 80 warm particles (2-4 px, radial, life 18-30 ticks, class CB_BURST) and a background tint that ramps in 18 ticks to at most 25%. The shockwave and the banner stay. The shake stays unless `effects_level` is REDUCED or MINIMAL.
    - The flash is independent of `effects_level`: REDUCED and MINIMAL still show the white frame unless `reduce_flashing` is on. The CB burst counts scale by `level_pct` (F12).
29. **Player death** (Collision V1, Player plane V7): on `player_died(slot)`: the Dying explosion (48 px, 5 frames, 20 ticks, 8 chunks, 1 smoke puff, era-coloured; the sprite itself is the Player plane's), the **death ring** in the slot's colour and pattern (40 to 80 px in 6 steps of 3 ticks, hold, fade T18-T24), pips in the debris (N pips), and `fx_death_dust` (6-10, F4, SHADOW grey, never gold or cream). Drones pop: one 3-frame pop plus 2 chips per drone (up to 4 per plane). No screen flash, no tint. Surviving players: no change.
30. **Hit feedback** (Collision V2; VFX renders):

| Result | Sprite | Spark (class SPARK, band B6) |
|---|---|---|
| Hit | White 60% tint for 2 ticks (Rule 31) | None, or 2-frame warm chip (T3) |
| Armoured | **No tint** | 3-frame clank: cream chips in the era enemy-rim colour plus one 2 x 2 steel dot (T2, 2 sprites) |
| Immune | No tint | 2-frame ping, one 5 x 5 cream "+" (T2, 1 sprite) |
| Destroyed | Size-class explosion (Rule 27) | None |

31. **Hit tint rules** (Collision V2, art bible §5.10), applied by VFX to the hit sprite only:
    1. White `#FFFFFF` at 60% for 2 ticks. Never full-screen, never on bullets, never on player planes (a hit on a plane is a death).
    2. New tint at most every 6 ticks on SMALL and MEDIUM and every 20 ticks on LARGE and boss parts. Armoured or immune sparks at most 1 per 8 ticks per target.
    3. Sustained fire (hit in 3 throttle windows in a row): steady 30% white, off after one window without hits.
    4. **Reduce flashing:** tint becomes a 1 px darker outline pulse under the same throttle (3 Hz maximum).
    5. Boss: tint the struck part only.
    6. Implementation is an open question (Open Questions 2): an instance shader uniform on the palette material, or a pre-drawn white-silhouette frame.
32. **Tells** (Pattern library V1-V3; Enemy V2; Boss V1): muzzle flash 3 frames, 6 ticks, at most 10 px; lock line (2 px dashes in the target's SLOT colour and pattern, crawling 2 px per tick) and 10 px bracket reticle tightening by 4 px; flak fuse puff 6 to 14 px with a 3 px AMBER spark blinking every 12 ticks then every 6 for the last 12 and solid for the final 6; burst puff 24 px. Co-op limit: at most 4 lock tells, and above 2 active the new ones show the reticle only (the library's rule). Tells are T0 (lock, flak) or T3 (muzzle).
33. **Sprite-level cues are not pooled**: the 12-tick windup glow, carrier rim pulse (2 Hz, 1 px, `pulse_pct` F9), plating fall frames, crack overlay pulse (2 Hz, 3 Hz for the last 60 ticks of the Critical window). They are frame swaps on the owner's sprite; VFX supplies `pulse_pct` and respects `access.reduce_pulsing` (Rule 34). Decorative debris from a plate fall is pooled (T3).
34. **Accessibility hooks** (read from Save through Accessibility 28; read at every `stage_started` and on settings change, never mid-tick):

| Key | Type | Default | Effect |
|---|---|---|---|
| `access.reduce_flashing` (existing) | bool | false | CB white frame to particle burst; hit tint to outline pulse; CB tint ramp 18 ticks, at most 25% |
| `access.effects_level` (**new**) | enum | FULL | Rule 21 |
| `access.reduce_pulsing` (**new**) | bool | false | Every pulse VFX supplies becomes steady at its high value; pulses owned by others read `pulse_pct` and follow suit |

    The CB local shake is off at REDUCED and MINIMAL. A separate shake toggle is not needed because there is no global shake (art bible §7.9 "screen-shake off or reduced" is met by this).
35. **Era treatment** (art bible §1 principle 3, §6.8): era changes the palette first, then shapes, then glow, and never the layer, the bullets or the budget.

| Era | Explosion look | Smoke | Extra | MVP |
|---|---|---|---|---|
| 1941 | Orange-sepia, smoky | Light grey, soft puffs | None | Yes |
| 1970s | Harder orange, black smoke | Thicker, +4 px puffs | None | Yes |
| 2030s | Cyan spark shards | Scanline haze (Parallax tile animation, not pooled) | +2 shard chips on MEDIUM and LARGE | Post-MVP |
| 2100 | Magenta shard bursts that briefly rewind (frames play forward, then the last 4 ticks play backward) | Drifting dust | +4 shard chips, rewind on the last 4 ticks | Post-MVP |

    Era extras are counted in DEBRIS (T3), so they are the first to be evicted. Glow is a lighter pixel halo drawn into the burst frames, never an additive blend and never a separate material. The CB palette, the death ring (slot colour), cancel puffs (gold) and tells (amber) do not change by era.
36. **Pause, stage change, run end.** Pause freezes the pool and the flash state. `stage_cleared` stops new spawns except HUD-side items; live effects finish (at most 36 ticks), scorch decals stay until the scene unloads. `stage_started` resets the pool, loads the era effects atlas, and applies the era palette material. A scene change or run end frees everything.

### States and Transitions

**Effect instance**

| State | Enter | Leave |
|---|---|---|
| Free | pool init, expiry, eviction | `spawn()` admitted |
| Live | `spawn()` admitted | `age >= life` (Expired) or evicted |
| Expired | the tick `age == life` | same tick, back to Free (no frame drawn at `age == life`) |
| Evicted | Rule 19 | same tick, back to Free |

**Flash (Critical Break frame)**

| From | Event | To | Action |
|---|---|---|---|
| IDLE | `critical_break_landed` at tick `T`, `reduce_flashing` false | ARMED | Store `T+1` |
| ARMED | tick counter reaches `T+1` | PENDING | Show the frame on the next render |
| PENDING | one frame rendered | IDLE | Hide the frame |
| IDLE | `critical_break_landed`, `reduce_flashing` true | IDLE | Spawn the particle burst instead |
| ARMED / PENDING | pause | same | Frozen |
| any | scene change | IDLE | Hidden |

**Effects level:** FULL <-> REDUCED <-> MINIMAL, changed only at `stage_started` or on a settings change at a tick boundary. On a change the pool is flushed of instances above the new tier limit on the next tick (no fade).

### Interactions with Other Systems

Interfaces were checked on 2026-11-03 against the downstream GDDs now written (HUD 20, Era shift 19, Parallax 23, Audio 24, Accessibility 28). VFX receives events only (GameEvents bus or direct signal on the producer). Per-bullet signals do not exist; VFX reads the Bullet manager's per-tick cancelled-position list.

| System | Direction | Contract |
|---|---|---|
| Game events and session (1) | In | `stage_started`, `stage_cleared`, `player_died(slot)`, `critical_break_landed`, `boss_defeated(reason, killer_slot)`, session state for pause. `screen_flash_requested(strength)` is **deprecated** (Rule 5) |
| Bullet manager (3) | In | `cancel_report[]` each tick (one merged per-tick report, BM Rule 13): entries `(request_id, cause_slot, area, items, count, positions_in_pool_order[])`; `clear_report` for the death clear (positions). Same positions Powerups gets |
| Player plane (5) | In | `player_died` with the plane position (or `get_position(slot)`), FlyIn start, drone removed, invulnerability blink is Player plane's |
| Collision (6) | In | `hit_feedback(target_id, result, pos, tick)` with result HIT / ARMOURED / IGNORED / DESTROYED; `plating_ended`, `mode_changed` for plate fall |
| Chain tracker (7), Scoring (8) | None | They draw only in the HUD; no play-field effect |
| Pattern library (9) | In | `volley_fired(emitter, pos)`, `lock_started(emitter, target_slot, aim_pos, lock_ticks)`, `lock_ended(fired)`, flak `fuse_started(B, delay)`, `fuse_burst(B)` |
| Enemy (10) | In | `enemy_destroyed(id, def_id, kill_class, pos, killer_slot, carrier)`, `enemy_damage_state`, tell via `next_volley_in` (sprite-level) |
| Plane kits (11) | In | `beam_started/ended(slot, kind, pos)`, `beam_hit_point(slot, pos)` for flares and splashes (rate-limited) |
| Bombs (12) | In | `bomb_used(slot)`, bomb phase events (`k = 0`, hook latch, detonation with position) |
| Powerups (13) | In | `item_collected(slot, kind, pos)`, `item_expired(pos)` |
| Boss (14) | In | `boss_started`, `boss_part_destroyed(part_id, pos, slot, last)`, `boss_core_exposed`, `boss_defeated`, intro and enrage markers |
| Critical Break (17) | In | `critical_break_landed(slot, before, after, raw, core_pos, breaks_on_run)`. VFX owns rendering of V1-V2 of its GDD; CB owns timing and knobs |
| Co-op (18) | In | `N` (Active slots, read at `stage_started` and on drop-in); slot colour, pattern, pips |
| HUD (20) | Out | Banner and popup are the HUD's; VFX only guarantees the field is empty at `T+2`. CB split (2026-11-03, wave 3b): VFX draws the world-space core ring and arc (`fx_cb_core_ring`); the HUD draws the Gold bomb-icon outline and the corner ticks while `cb_state` is ARMED / COMMITTED |
| Parallax (23) | Out | `set_desaturation(pct)` for the CB tint (clamped at 60); weather and smoke requests from Parallax are T4 and count against the 150 cap; Parallax renders the boss vignette (Open Question 5 closed); shake at most 8 px (overscan) |
| Audio (24) | None | No coupling; both listen to the same events |
| Save (26), Accessibility (28) | In | Reads `access.reduce_flashing`, `access.effects_level`, `access.reduce_pulsing` |
| Display scaler (4) | Rule | No shake of the SubViewport or bezel (Display scaler rule, AC-34) |

> Decided under auto-approve (2026-11-03): CPU-driven MultiMesh sprite pool (no particle nodes); 150 shared cap with five tiers and class caps; 2 full death rings in co-op, rest compact; no global shake, one local boss shake at Critical Break; no hit-stop; effects level FULL / REDUCED / MINIMAL; `reduce_pulsing` key; CB cancel puffs capped at 12; gem sparkles are one particle; part-kill rings are filled puff rings; MEDIUM and LARGE kill cancels get a thin ring; eviction by tier then age; era extras ride the debris class.

## Formulas

**F1. Effective pool cap**
`P_cap_eff = (vfx_particle_cap * level_pct) div 100`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Pool cap | `vfx_particle_cap` | int | 100-200 | Default 150 (art bible §8.6) |
| Level percent | `level_pct` | int | {100, 50, 25} | FULL / REDUCED / MINIMAL |

**Output Range:** 37-150. **Example:** REDUCED: `150 * 50 div 100 = 75`. MINIMAL: `150 * 25 div 100 = 37`.

**F2. Effective class cap**
`cap_eff = max(1, (cap * level_pct * dens_pct) div 10000)`, with `dens_pct = D(N)` for tier 3-4 classes and `100` for tier 0-2 classes. `D = [100, 100, 80, 70]` for `N` = 1-4.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Class cap | `cap` | int | 1-80 | Rule 18 table |
| Level percent | `level_pct` | int | {100, 50, 25} | F1 |
| Density percent | `dens_pct` | int | 70-100 | Co-op density |

**Output Range:** 1-80. **Example:** MUZZLE (12), `N` = 4, FULL: `12 * 100 * 70 div 10000 = 8`. WEATHER (40), `N` = 3, FULL: `40 * 100 * 80 div 10000 = 32`. CANCEL_PUFF (40, tier 2), REDUCED, `N` = 4: `40 * 50 * 100 div 10000 = 20`.

**F3. Cancel puff sampling** (same stride rule as Powerups F3)
`stride = ceil(n / cap_puff)`; puff for cancelled index `i` iff `i mod stride == 0`; `kept = ceil(n / stride)`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cancelled count | `n` | int | 0-2000 | From `cancel_report` |
| Puff cap for the request | `cap_puff` | int | 1-40 | 40 default; 12 for the Critical Break cancel; `cap_eff` of CANCEL_PUFF if lower |

**Output Range:** 0 to `cap_puff` (never above). **Example:** `n` = 1350, cap 40: `stride = ceil(33.75) = 34`, `kept = ceil(1350 / 34) = ceil(39.7) = 40`. `n` = 41: `stride = 2`, `kept = 21`. `n` = 1350, cap 12 (Critical Break): `stride = ceil(112.5) = 113`, `kept = ceil(1350 / 113) = 12`. `n` = 0: no puffs, no ring.

**F4. Death dust count**
`dust = min(n, clamp((n + 19) div 20, 6, 10))` for `n >= 1`, else 0.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cleared bullets | `n` | int | 0-2000 | From `clear_report` |

**Output Range:** 0-10. **Example:** `n` = 1350: `(1350+19) div 20 = 68`, clamp to 10, `dust = 10`. `n` = 50: `3`, clamp to 6, `min(50, 6) = 6`. `n` = 3: `min(3, 6) = 3`. `n` = 160: `8`.

**F5. Local shake offset** (integer, horizontal, decaying)
`off_x(k) = ((A * (n - k)) div n) * (+1 if k is even else -1)` for `k` in 0..n-1; `off_y = 0`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Amplitude | `A` | int px | 0-6 | `cb_shake_px`, default 4 (Critical Break knob) |
| Length | `n` | int ticks | 0-12 | `cb_shake_ticks`, default 8 |
| Tick index | `k` | int | 0..n-1 | Ticks since `T+1` |

**Output Range:** `|off_x| <= A`; ends at 0 for `k = n-1` when `A < n`. **Example (A=4, n=8):** k = 0..7 gives +4, -3, +3, -2, +2, -1, +1, 0. `A` = 0 or REDUCED / MINIMAL level: always 0.

**F6. Eviction victim**
`victim = oldest(instances where tier = max{tier_j : tier_j > t})` else (`t <= 1`) `oldest(instances where tier = t)` else none (request dropped). "Oldest" = smallest `start_tick`, ties by lowest pool index.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Request tier | `t` | int | 0-4 | From the `EffectDef` |
| Live tiers | `tier_j` | int | 0-4 | Tiers present in the pool |

**Output Range:** one pool index or none. **Example:** pool full (150): 40 weather (T4), 70 debris/chips (T3), 40 T2. A T1 request evicts the oldest weather instance. After all 40 weather are gone, it evicts the oldest T3. A T2 request with no T3 or T4 present is dropped.

**F7. Expanding ring diameter** (stepped)
`diam(t) = d0 + ((d1 - d0) * t) div T`, drawn at the nearest baked step; opacity `alpha(t) = 100 * (T - t) div T` where a fade applies.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Start / end diameter | `d0`, `d1` | int px | 24-480 | Per effect (Catalogue) |
| Duration | `T` | int ticks | 6-24 | Per effect |
| Age | `t` | int | 0..T | Ticks since spawn |

**Output Range:** `d0..d1`. **Example:** bomb ring (36, 480, 12): `t` = 6: `36 + 444*6 div 12 = 258`. CB ring (24, 360, 18): `t` = 9: `24 + 336*9 div 18 = 192`. Death ring (40, 80, 18, steps of 3 ticks): frame `f = t div 3`, `diam = 40 + 8 f`: `t` = 17 gives `f` = 5, 80. Death ring fade for `t` in 18-23: `alpha = 100 * (24 - t) div 6`: 100, 83, 66, 50, 33, 16; gone at 24.

**F8. Debris flight** (fixed point, 1/16 px)
`x(t) = x0 + (vx16 * t) div 16`; `y(t) = y0 + (vy16 * t) div 16 + (g16 * t * t) div 32`; `alpha(t) = 100` for `t <= 16`, `100 * (24 - t) div 8` for 16 < `t` < 24; life 24 ticks.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Launch velocity | `vx16`, `vy16` | int (1/16 px per tick) | -64..64 | From the fan table plus the VFX RNG |
| Gravity | `g16` | int | 0-8 | Default 4 |
| Age | `t` | int | 0..23 | Ticks |

**Output Range:** integer pixel offsets; drawn at `round`-free integers. **Example:** `v16 = (24, -32)`, `g16 = 4`, `t` = 18: `x = x0 + 27`; `y = y0 + (-36) + (1296 div 32 = 40) = y0 + 4`; `alpha = 100 * 6 div 8 = 75`.

**F9. Pulse value** (used for effect pulses VFX supplies)
`pulse_pct(t, P, lo, hi) = lo + ((hi - lo) * abs(2 * (t mod P) - P)) div P`; returns `hi` when `access.reduce_pulsing`. Rate `= 60 / P` Hz; require `P >= 20` (3 Hz at most) and `hi - lo <= 40`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Tick | `t` | int | 0+ | Tick counter |
| Period | `P` | int ticks | 20-120 | 30 = 2 Hz |
| Low / high opacity | `lo`, `hi` | int % | 60-100 | Default 60 / 100 |

**Output Range:** `lo..hi`. **Example:** `P` = 30, 60-100: `t` = 0: 100; `t` = 15: 60; `t` = 7: `60 + 40*16 div 30 = 81`; `t` = 22: `60 + 40*14 div 30 = 78`.

**F10. Count scaling**
`n_eff = max(m, (n_base * level_pct) div 100)`, `m` = 1 for tier 0-1, else 0.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base count | `n_base` | int | 1-80 | Rule 18 / catalogue |
| Minimum | `m` | int | 0-1 | |

**Output Range:** 0-80. **Example:** CB burst 60 at REDUCED: 30; reduce-flashing burst 80 at REDUCED: 40; 60 at MINIMAL: 15. LARGE debris 12 at REDUCED: 6. LARGE secondary pops (2) at REDUCED: 0 (Rule 21 removes them).

**F11. Pool occupancy under pressure**
`live = min(P_cap_eff, sum of admitted requests)`; `evicted = max(0, sum - P_cap_eff)`, taken from the highest tier first (F6).

**Worst-case scenarios (FULL, N = 4, cap 150):**

| Scenario | Requests | Sum | Evicted | Result |
|---|---|---|---|---|
| A: Critical Break, reduce flashing, 2030s rain | CB burst 80, CB ring 1, boss death 40, CB cancel puffs 12, sparks 8, weather 40 | 181 | 31 (all from weather) | Weather 9; every T0-T2 effect intact |
| B: four simultaneous bombs | Lancer dust 40, 4 bomb rings 4, 2 Leech bursts + 2 rings 4, cancel puffs 40, enemy explosions 24, debris 56, sparks 24 (16 chips T3, 8 clanks T2), weather 40 | 232 | 82: weather 40, then 42 of 72 T3 | T3 left 30; T0-T2 intact |
| C: Critical Break, normal flash | CB burst 60, CB ring 1, boss death 40, CB puffs 12, sparks 8, weather 40 | 161 | 11 (weather) | Weather 29 |

**F12. Flash visibility**
`flash_visible_renders = 1` per Critical Break, regardless of render rate. At 60 fps render, it covers 1 tick; at 30 fps render, 2 ticks.

## Edge Cases

- **If the pool is full and a T0 request arrives with nothing of a lower priority alive**, the oldest T0 instance is evicted. T0 requests are never refused.
- **If a class is at its cap and the class is marked "drop request"**, the new request is refused and the drop is counted; older instances keep playing.
- **If two Critical Breaks request a flash** (impossible: one break per boss), the second is ignored and an error is logged.
- **If the game renders at 30 fps and the white frame lands on the skipped render**, the flash is shown on the next rendered frame and cleared after it (PENDING state). It is never skipped and never shown twice.
- **If the game is paused on tick `T+1` before the flash rendered**, the flash renders once, then hides, and stays hidden through the pause.
- **If `reduce_flashing` is on**, no frame of the Critical Break differs from the previous frame by more than 8% mean luma (AC-23).
- **If `cancel_report` has `n = 0`**, no ring and no puffs spawn.
- **If several cancels run on one tick** (bomb plus part kill), each request gets its own ring; the puff sampling runs per request with cap 40, but the CANCEL_PUFF class cap (40) still limits the total. The Bullet manager credits each bullet once, so there are no duplicate positions.
- **If a bomb is used in a field with no enemy bullets**, its ring and dust play (they are bomb effects) and no cancel puffs spawn.
- **If a death clear and a bomb cancel happen on the same tick**, both play: the death ring, dust and the bomb ring. The dust is grey and the puffs are gold, so they stay distinguishable.
- **If three or four planes die on one tick**, two full death rings and the rest compact rings spawn, ordered by the Collision rotation rank; every plane still gets an explosion; dust and clear sound play once. Pool pressure never removes a death ring (T0).
- **If an enemy dies off-screen or above `play_top`**, no effect spawns for the part outside the play field; the burst is clipped at the HUD strip edge (Enemy V1).
- **If the effects atlas for the next era is not loaded yet**, the spawn is refused and counted; the era atlas loads at `stage_started` (art bible §8.6), before any enemy exists.
- **If `effects_level` changes mid-stage**, the change applies at the next tick boundary; instances above the new tier limit vanish that tick without fade.
- **If `effects_level` is MINIMAL**, a LARGE kill is one 72 px burst with no debris, no pops and no smoke; the cancel ring and score items still work.
- **If a Critical Break banner is dropped** (Critical Break Rule 26), the burst, ring and popup still play.
- **If `N` changes by drop-in**, density changes at the next `stage_started`; live instances are not touched.
- **If a boss dies during a Critical Break**, the CB burst and the boss death sequence share the pool (Scenario A and C); the final 72 px explosion at tick 150 is T0 and cannot be evicted.
- **If a hit-tint request arrives inside its throttle window**, it is ignored; the existing tint is not extended.
- **If the Leech bomb hook detonates outside the play field**, the burst is drawn only where it overlaps the field; its cancel ring is clipped by the canvas.
- **If a scorch decal pool (16) is full**, the oldest decal is replaced immediately.
- **If pickup sparkle requests for gems exceed 1 per 2 ticks**, the extra requests are dropped (a 100-gem sweep must not fill the PICKUP class).
- **If the scene is freed with live effects**, the pool and renderer are freed together with no errors (AC-33).
- **If a flak fuse count would exceed 8 at once**: this cannot happen in valid content. The Pattern library allows at most **8 lit fuses per scene** (validator per owner and per scene; at runtime a volley that would light a 9th fuse is skipped, counts as fired and still draws its RNG) (2026-11-03, wave 4). As a guard only, a 9th fuse would still be drawn (T0) by evicting the oldest TELL instance, and the debug build logs a warning.
- **If a cancel area removes bullets that spawned that tick**, they are in `cancel_report` like any other, so a puff may appear on a bullet that was never drawn; this is accepted (one frame of a sampled puff).

## Dependencies

**Upstream (VFX reads these)**

| System | Hard/Soft | Interface | GDD |
|---|---|---|---|
| Game events and session (1) | Hard | Event bus; session state; `N` | Yes |
| Bullet manager (3) | Hard | `cancel_report`, `clear_report`; layer rules V5-V6 | Yes |
| Player plane (5) | Hard | `player_died`, FlyIn, drone removal, slot identity | Yes |
| Collision (6) | Hard | `hit_feedback`, plating and mode events, tint throttles | Yes |
| Pattern library (9) | Hard | Tell events | Yes |
| Enemy and AI (10) | Hard | `enemy_destroyed`, damage state | Yes |
| Plane kits (11) | Soft | Beam events for flares and splashes | Yes |
| Bombs (12) | Hard | Bomb phase events | Yes |
| Powerups and drops (13) | Soft | Pickup and expiry events | Yes |
| Boss and boss parts (14) | Hard | Part kill, intro, enrage, death events | Yes |
| Critical Break (17) | Hard | `critical_break_landed`, `cb_state(slot)` for the core ring; owns timeline and shake knobs | Yes |
| Co-op (18) | Soft | `N`, slot identity | Yes |
| Display scaler (4) | Soft | Shake stays inside the canvas | Yes |
| Save (26) / Accessibility (28) | Soft | Settings keys | Yes ([Accessibility](accessibility-options.md)) |
| Art bible | Hard | Layers, palette, budget | Yes |

**Downstream (these depend on VFX)**

| System | Hard/Soft | Interface | GDD |
|---|---|---|---|
| HUD (20) | Soft | Field is empty when the banner shows; HUD owns the CB bomb-icon outline, VFX the core ring | Yes ([HUD](hud.md)) |
| Parallax and environment (23) | Soft | Desaturation call, weather budget, vignette | Yes ([Parallax](parallax-and-environment.md)) |
| Audio (24) | None | Parallel listener | Yes ([Audio](audio.md)) |
| Accessibility options (28) | Hard | Registers `access.effects_level`, `access.reduce_pulsing`; UI for the three toggles | Yes ([Accessibility](accessibility-options.md)) |
| Wave director (16), Era shift (19) | Soft | Era id, `stage_started` and `era_swap_committed` for the atlas swap | Yes ([Director](wave-and-stage-director.md), [Era shift](era-shift-and-plane-evolution.md)) |

**Amendments to other docs**

1. **`design/gdd/systems-index.md`** row 25: status `**Designed** (pending review) — [GDD](vfx-and-screen-feedback.md)`; Depends on: `1, 3, 5, 6, 9, 10, 11, 12, 13, 14, 17, 18 (soft: 4, 23, 26)`. Progress tracker: GDDs written +1; add the system to the list. Dependency notes: add "VFX (25) closes Display scaler Open Question 5 and Co-op V2 'VFX decides'".
2. **`design/gdd/coop-and-team-chain.md`** V2 row "Big-effect cap": replace "Proposed; VFX decides" with "At most 2 full death rings, others compact (VFX 25 Rule 23)". Dependencies: list VFX (25).
3. **`design/gdd/display-scaler-and-bezel.md`** Open Question 5: closed. "No global shake exists (VFX 25 Rule 6), so no overscan margin is needed; the only shake is a boss-sprite offset of at most 4 px." Interactions row for VFX: add the same note.
4. **`design/gdd/bullet-manager.md`** Interactions: add "VFX (25) — reads `cancel_report` (cause slot, area, cancelled positions in pool order, count) and `clear_report` each tick". V6: add "puff live cap 40 across all sweeps; the Critical Break cancel samples at most 12".
5. **`design/gdd/powerups-and-drops.md`** V4: gem pickup sparkle is **one** 2-frame 4 px particle (not four), at most 1 per 2 ticks and 12 live; the 4-particle cluster applies to medal, chain, pod and 1UP. Reason: a 100-gem sweep must not fill the pool.
6. **`design/gdd/game-events-and-session.md`** Visual section (line ~321) and signal list: `screen_flash_requested` is deprecated; the Critical Break frame is driven only by `critical_break_landed`. Remove `popup_requested` (floating world text is banned by art bible §7.7; captions live in the HUD). Prototype code: delete the `screen_flash_requested.emit(0.4 / 0.3 / 0.12)` calls in `src/gameplay/player/player.gd` and `src/gameplay/boss/boss.gd`, and the `popup_requested` use, when VFX is implemented.
7. **`design/gdd/critical-break.md`** V1-V2: add "cancel puffs from the CB cancel capped at 12 (VFX F3)", "shake applied by VFX (F5), off at REDUCED and MINIMAL effects levels", "reduce-flashing burst count scales by `level_pct` (VFX F10)", and the `set_desaturation` call to Parallax.
8. **`design/gdd/collision-damage-lives.md`** Interactions: add `hit_feedback(target_id, result, pos, tick)` event contract; V2: "oldest spark dropped first" is the SPARK class overflow rule. Dependencies: list VFX (25).
9. **`design/gdd/enemy-and-ai.md`** V3 "Cap behaviour": reference VFX tiers (debris T3, SMALL T2, MEDIUM and LARGE T1). Dependencies: list VFX (25).
10. **`design/gdd/boss-and-boss-parts.md`** V4: boss vignette is rendered by VFX (band B0) unless Parallax (23) takes it; death sequence class BOSS_DEATH (40) shares the pool. Dependencies: list VFX (25).
11. **`design/gdd/save-settings-high-scores.md`** schema table near line 110: add `access.effects_level` (enum FULL / REDUCED / MINIMAL, default FULL) and `access.reduce_pulsing` (bool, default false), registered by Accessibility (28).
12. **`design/gdd/player-plane.md`** event list: `player_died(slot)` must carry the plane position or `get_position(slot)` must be valid on the death tick. Dependencies: list VFX (25).
13. **`design/art/art-bible.md`**: §8.6 Particles row: "150 is the hard total; class caps are non-additive; explosions 24 + debris 56 = the old 80; tiers T0-T4 decide eviction (VFX 25 Rule 17-19)". §6.8: add the z_index mapping `layer*10 + sub` and the band table. §7.9: "screen-shake" means the local boss shake only. §4.6: confirm alert amber (also required by Pattern library). §8.3: add ring bake note and the effect sprite list.
14. **`design/gdd/bombs.md`** V1-V2: "BOMB_DUST is a global cap of 40 shared by all bombs (not 40 per bomb)". Dependencies: list VFX (25).
15. **Systems index dependency notes:** systems 17, 19, 20, 24, 25, 28, 29, 30 list Bombs (12) (already requested); 25 does.

## Tuning Knobs

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `vfx_particle_cap` | 150 | 100-200 | Burst effects get evicted mid-play | Web and phone frame cost; screen clutter | Perf budget, art bible §8.6 |
| `level_pct` (FULL / REDUCED / MINIMAL) | 100 / 50 / 25 | 100 / 25-75 / 10-40 | MINIMAL looks bare | Does not reduce enough to help | Accessibility |
| `dens_pct` by `N` | 100 / 100 / 80 / 70 | 50-100 | 4P loses feedback | 4P too busy | Co-op |
| Class caps (Rule 18) | see table | +/- 50% | Class starves | Pool saturated by one class | F6 |
| `death_ring_full_max` | 2 | 1-4 | Rings lost | 4P ring pile-up | Collision V1 |
| `cancel_puff_cap` (sweep) | 40 | 20-60 | Weak cancel read | Pool pressure | Bullet manager V6, F3 |
| `cb_cancel_puff_cap` | 12 | 0-24 | Fine | Competes with CB burst | Critical Break |
| `cb_burst_count` | 60 normal / 80 reduce-flashing | 30-100 | Weak payoff | Pool pressure | Critical Break V1-V2 |
| `debris_g16` | 4 | 0-8 | Debris floats | Debris drops too fast | F8 |
| `debris_life` | 24 ticks | 12-36 | Chips vanish | Pool pressure | F8 |
| `muzzle_cap` | 12 | 4-24 | Tells unclear | Clutter | Pattern library V1 |
| `kit_flare_cap` | 12 | 4-24 | Beam ends bare | Clutter in 4P | Plane kits V1 |
| `gem_sparkle_rate` | 1 per 2 ticks, 12 live | 1 per 1-6 ticks | Sweep feels flat | Fills PICKUP class | Powerups |
| `shake_px` / `shake_ticks` | 4 / 8 (owned by Critical Break) | 0-6 / 0-12 | None | Distracting | Critical Break |
| `bg_tint_max` | 60% normal, 25% reduce flashing (owned by Critical Break) | 0-60 / 0-25 | | Washes out bullets' contrast | Parallax |
| `tint_throttle` | 6 / 20 ticks (owned by Collision) | | | | Collision V2 |
| `era_extra_chips` | 0 / 0 / 2 / 4 per era | 0-6 | Eras look the same | Debris pressure | Era shift |
| VFX perf budget (Perf section) | tick 0.25 ms, pack 0.35 ms p99 | | | | ADR-0001 |

**Owned elsewhere:** hit-tint throttles and sustained tint (Collision 6); shake amplitude and length, flash timing, banner timeline (Critical Break 17); item pulse, pop and bob (Powerups 13); tell timing and lock ticks (Pattern library 9); weather density and the era brightness pulse (Parallax 23); `access.reduce_flashing` UI (Accessibility 28).

> Rationale: 150 and the 24 / 56 / 30 / 40 splits are the art bible's. Tier order follows Enemy V3 (debris first) and Readable Chaos (information before decoration). Co-op density `100 / 100 / 80 / 70` follows the shot-opacity steps (100 / 75 / 50) in spirit: more players, quieter decoration. All values are unplaytested (P).

## Visual/Audio Requirements

**Visual** (concrete sizes at 1x; layers per art bible §6.8)

### Effect catalogue

`Cost` = live pool instances at peak. `Ticks` = life; `fr` = frames. Colour role from Rule 25. Era variants: A = 1941, B = 1970s (MVP); C = 2030s, D = 2100 (post-MVP). "Recolour" = palette swap through the era material only.

| Id | Trigger event | Layer / band | Size px | Frames / ticks | Colour role | Era variants | Cost | Tier |
|---|---|---|---|---|---|---|---|---|
| `fx_muzzle` | `volley_fired` (first volley of a burst) | 5 / B7 | <= 10 | 3 fr, 6 | SHADOW / BURST smoke | A sepia-orange, B hard orange + dark puff, C cyan sparks, D magenta shards | 1 | T3 |
| `fx_lock_line` | `lock_started` | 5 / B7 | dashes 2 px, to aim point | 18-60 (`lock_ticks`), fades in 6 | SLOT colour and pattern | None | 1 | T0 |
| `fx_lock_reticle` | `lock_started` | 5 / B7 | 10 px brackets, tighten 4 px; pip count at one corner | `lock_ticks`; fired: bright 2 ticks; not fired: 4 corners fall 6 px, fade 8 ticks | SLOT | None | 1 (4 while breaking) | T0 |
| `fx_flak_fuse` | `fuse_started` | 5 / B7 | 6 to 14 px puff + 3 px spark | `flak_delay` 36; blink 12 then 6 then solid last 6 | SHADOW + AMBER | Shadow recolour | 2 | T0 |
| `fx_flak_burst` | `fuse_burst` | 5 / B7 | 24 px | 3 fr, 6 | SHADOW | Recolour | 1 | T0 |
| `fx_hit_chip` | `hit_feedback` HIT (optional) | 5 / B6 | 3-4 px | 2 fr, 6 | GOLD / CREAM | None | 1 | T3 |
| `fx_clank` | `hit_feedback` ARMOURED | 5 / B6 | chips 3-4 px + 2x2 steel dot | 3 fr, 9 | CREAM + era rim | Rim recolour | 2 | T1 (visual twin; kept at MINIMAL) |
| `fx_ping` | `hit_feedback` IGNORED | 5 / B6 | 5x5 "+" | 2 fr, 8 | CREAM | None | 1 | T1 (visual twin; kept at MINIMAL) |
| `fx_explosion_small` | `enemy_destroyed` SMALL (air) | 5 / B3 | 20 | 3 fr, 12 | BURST | A orange-sepia smoky, B hard orange, C cyan shards, D magenta rewind | 1 + 3 chunks | T2 |
| `fx_explosion_medium` | `enemy_destroyed` MEDIUM | 5 / B3 | 40 | 4 fr, 18 | BURST | Same | 1 + 6 chunks + 1 smoke | T1 |
| `fx_explosion_large` | `enemy_destroyed` LARGE | 5 / B3 | 72 | 5 fr, 36; pops at +8, +16 | BURST | Same | 1 + 2 pops + 12 chunks + smoke | T1 |
| `fx_explosion_ground` | `enemy_destroyed` (ground) | 2 / B1 | per class | per class | BURST (darker) | Same | per class | T1 / T2 |
| `fx_scorch` | ground kill | 2 / B0 | per class | 180 | SHADOW | Recolour | decal | n/a |
| `fx_debris` | any explosion | 5 / B4 | 3-6 px | 24 (F8) | BURST | + chips in C (2) and D (4) | 1 each | T3 |
| `fx_smoke_puff` | MEDIUM damage state (every 20 ticks), LARGE wreck, boss smoking part | 5 or 2 / B2 | 6-12 | 4 fr, 24 | SHADOW | B thicker (+4 px), C haze, D dust | 1 | T4 |
| `fx_plate_fall` | `plating_ended`, `mode_changed` | 5 / B4 | 4 plates (sprite frames) + 6 chunks | 4 fr, 8 | Steel grey | Recolour | 6 | T3 |
| `fx_part_burst` | `boss_part_destroyed` | 5 / B3 | 28 / 32 / 36 (part data) | 3 fr, 6 | BURST | Same | 1 + 12 chunks | T1 |
| `fx_part_puffring` | `boss_part_destroyed` | 5 / B5 | radius 90 (150 if last) | 12 (16) puffs, 8 | SHADOW | Recolour | 12 (16) | T1 |
| `fx_cancel_ring_bomb` | bomb `k = 0` | 5 / B5 | 36 to 480 | 12 | BOMB | None | 1 | T1 |
| `fx_cancel_ring_kill` | MEDIUM / LARGE kill with n >= 1 | 5 / B5 | 80 / 144 | 8 | GOLD / CREAM | None | 1 | T1 |
| `fx_cancel_puff` | any cancel with n >= 1 | 5 / B5 | 4-6 | 4 fr, 12 | GOLD / CREAM | Era tint allowed | <= 40 per sweep, 12 for CB | T2 |
| `fx_death_ring` | `player_died` | 5 / B5 | 40 to 80 | 6 steps x 3, fade 18-24 | SLOT colour and pattern | None | 1 | T0 |
| `fx_death_ring_compact` | 3rd and 4th simultaneous death | 5 / B5 | 40 to 56 | 3 steps x 4, fade 12-18 | SLOT | None | 1 | T0 |
| `fx_player_explosion` | `player_died` | 5 / B3 | 48 | 5 fr, 20; smoke to 36 | BURST (+ N pips in SLOT) | Same | 1 + 8 chunks + 1 smoke | T0 |
| `fx_death_dust` | death clear (F4) | 5 / B2 | 6-8 | 3 fr, 9 | SHADOW | Recolour | 6-10 | T2 |
| `fx_flyin_puff` | FlyIn start | 5 / B2 | 8 | 3 fr, 12 | WARM exhaust | None | 1 | T3 |
| `fx_drone_pop` | drone removed | 5 / B3 | 12 + 2 chips | 3 fr, 9 | WARM | None | 3 | T2 |
| `fx_bomb_dust` | Lance Sweep columns | 5 / B2 | 2+ px | ~20 | BOMB | Recolour (warm) | <= 40 total | T2 |
| `fx_barb_burst` | hook detonation | 5 / B3 | 48 | 5 fr, 15 | BOMB (cream / orange / gold) | Recolour (warm) | 1 | T1 |
| `fx_barb_ring` | hook detonation | 5 / B5 | 192 | 8 | BOMB | None | 1 | T1 |
| `fx_beam_flare` | Lancer beam on | 5 / B4 | 14x10 | 2 fr loop at 20 fps | WARM | None | 1 per beam | T3 |
| `fx_beam_splash` | beam hit point | 5 / B4 | 16x8 | 3 fr loop | WARM | None | 1 per beam | T3 |
| `fx_pickup_spark` | `item_collected` (medal, chain, pod, 1UP) | 6 / B8 | four 2x2 | 8 | GOLD or CREAM | None | 4 | T2 |
| `fx_gem_spark` | `item_collected` GEM | 6 / B8 | 4 | 2 fr, 6 | GOLD | None | 1 | T3 |
| `fx_expire_puff` | `item_expired` | 6 / B8 | 8 | 6 | SHADOW | None | 1 | T3 |
| `fx_boss_intro_sweep` | boss intro | 5 / B2 | 3-6 | 20 particles over 90 | SHADOW | Recolour | <= 20 | T3 |
| `fx_boss_death_burst` | boss death sequence | 5 / B3 | 28-36, one per 10 ticks | 3 fr, 9 | BURST | Same | within BOSS_DEATH 40 | T1 |
| `fx_boss_death_final` | boss death tick 150 | 5 / B3 | 72 + puff ring to 120 px radius over 20 | 5 fr | BURST + SHADOW | Same | 1 + 16 | T0 |
| `fx_withdraw_trail` | boss TIMEOUT | 5 / B2 | 8-12 | trail | SHADOW | Recolour | <= 6 | T3 |
| `fx_cb_core_ring` | `cb_state` of any slot OPEN / ARMED / COMMITTED / OPEN_LATE (Critical Break UI Requirements) | 5 / B5 (world space, below the enemy bullets; never over bullets) | ring around the core + arc showing `critical_left / 420`; narrows while COMMITTED; thin static ring in OPEN_LATE | follows the state each tick | CB | None | 2 (class TELL) | T0 |
| `fx_cb_flash` | `critical_break_landed` | 10 | 360x640 | 1 rendered frame | `#FFFFFF` | None | 0 | n/a |
| `fx_cb_ring` | `critical_break_landed` | 5 / B5 | 24 to 360, 2 px | 18 | CB | None | 1 | T0 |
| `fx_cb_burst` | `critical_break_landed` | 5 / B5 | 3-6 px (2-4 px alt) | 60 particles, life <= 30 (alt 80, 18-30) | CB | None | 60 (80) | T0 |
| `fx_weather` | Parallax | 2 | 1 px streaks etc. | Parallax-owned | Era | per era | <= 40 | T4 |

### Draw order inside layer 5 (back to front)
Dust and smoke (B2), explosions (B3), debris (B4), cancel fx (B5), sparks (B6), tells (B7). Tells sit on top so a lock reticle is never hidden by an explosion.

### Screen-feedback policy

| Feedback | Policy |
|---|---|
| Hit-stop / slow motion | None (Critical Break Rule 24) |
| Screen flash | Only the Critical Break frame; replaced by a particle burst with `reduce_flashing` |
| Screen shake | No global shake. One local boss-sprite shake (4 px, 8 ticks) at a Critical Break |
| Sprite tint | White 60% for 2 ticks on the struck sprite; armoured and immune hits never tint; outline pulse under `reduce_flashing` |
| Full-screen tint or dim | None on hit, death, bomb, part kill. Only the Critical Break background tint (36 ticks, at most 60% / 25%), applied to background layers, never above layer 5 |
| Vignette | Not VFX: rendered by Parallax (23 Rule 20, starts at `warning_started` + 150). VFX draws no vignette (2026-11-03, wave 3b) |
| Rumble | Not VFX (Input) |

**Why no global shake (Readable Chaos).** The player aims by watching a 6 px hitbox weave between 2.5 px bullets. Shaking the field moves every bullet against that hitbox. A 4 px shake equals the hitbox radius plus 1 px, so it changes which gap is safe. The shaken boss sprite is fine because it is not what kills the player and its hurtbox does not move.

### Performance budget (P, to be measured)

| Item | REF-WEB / REF-PHONE target | Hard limit |
|---|---|---|
| VFX `tick()` at 150 live + 24 sparks | <= 0.25 ms p99 | 0.5 ms |
| MultiMesh pack for all bands | <= 0.35 ms p99 | 0.7 ms |
| Draw calls | 8 bands (+1 on the flash frame) | 10 |
| Live instances | 150 | 150 (cannot exceed) |
| Effects atlas | <= 2 MB per era (art bible fx 2 MB) + <= 1 MB shared | 3 MB + 1 MB |
| Per-frame allocations | 0 (fixed arrays; no `Array.append` in `tick()`) | |
| Phone render | May render at 30 fps; ticks stay at 60 Hz and effects use the latest tick | |

These add to the bullet budget; with bullets (1.5 + 0.5 + 1.0 ms) the total stays under the 16.6 ms frame on REF-PC and must be re-checked on REF-WEB in the spike.

### Asset spec hooks

- Atlases: `atlas_fx_shared.png` (CB, rings, tells, sparks, pickup; always loaded) and `atlas_fx_<era>.png` (explosions, debris, smoke, per era). Max 2048 x 2048, 2 px gutter, extruded edges, power-of-two preferred.
- Naming: `fx_<name>_<era?>_<size>.png` (art bible §8.5), e.g. `fx_explosion_large_1941_72.png`, `fx_ring_death_dashed_80.png`.
- Colour cap per effect sheet: 8 colours (proposal; art bible gives no cap for category `fx`). Palette lint applies. No pixel in hue 225-265 with saturation >= 40%, and no Ink `#0B0B2A`.
- Rings: outline-free, 2 px, no ring shape resembling bullets. Three families: slot rings (4 patterns x 6 sizes), bomb and CB rings (stepped diameters), filled puff rings (built from puff sprites). Rings over 128 px diameter: baked at stage load from four mirrored quadrants (Open Question 1).
- Pivots and `frame_ticks` live in `data/vfx/`, not in the PNG.
- Run `/asset-spec system:vfx-and-screen-feedback` after the art bible amendments are applied.

**Audio:** VFX has no sound. Audio (24) listens to the same events. Sounds named in other GDDs (clear thud, clank, CB sting) keep their owners and caps. VFX never gates a sound and a sound never gates VFX.

## UI Requirements

No player-facing UI of its own. The three accessibility toggles (`reduce_flashing`, `effects_level`, `reduce_pulsing`) are drawn by Accessibility (28) and the Menus (22); each needs a non-colour label and a preview. Debug tools (debug builds only):

| Tool | Behaviour |
|---|---|
| FX overlay (key) | Live count per class and tier, evictions, drops, pool high-water mark, VFX tick and pack ms |
| `fx_force(def_id, x, y)` | Spawn any effect by id |
| `fx_budget_stress(scenario)` | Plays Scenarios A, B, C of F11 |
| Grayscale and band toggles | Hide one band, or render only layer 5, for the grayscale gate |
| `fx_level(level)` | Switch FULL / REDUCED / MINIMAL live |

## Acceptance Criteria

**Defaults used:** `vfx_particle_cap` 150; class caps of Rule 18; `level_pct` 100 / 50 / 25; `D(N)` = 100 / 100 / 80 / 70; death ring full max 2; `cb_shake_px` 4, `cb_shake_ticks` 8; `cancel_puff_cap` 40; `cb_cancel_puff_cap` 12; `g16` 4. All numbers are read from `data/vfx/vfx_budget.tres` and `data/vfx/effects.tres`, never typed in tests.

**Test setup:** `EffectPool`, `VfxDirector` and `FlashState` are node-free `RefCounted` classes with `tick()`. Tests inject the integer tick, a seeded `RandomNumberGenerator`, and synthetic event streams (cancel reports with generated positions, hit feedback, player deaths). Unit tests live in `tests/unit/test_vfx_pool.gd`, `test_vfx_formulas.gd`, `test_vfx_director.gd`, `test_vfx_flash.gd`, in the `extends SceneTree` style of `tests/unit/test_chain_tracker.gd`. Integration tests run in a scene with the real renderer. Perf tests run in `tests/perf/vfx_bench.tscn` on REF-WEB (release Web export) and REF-PHONE.

- **AC-01 [Unit] (Rule 1):** **GIVEN** every `EffectDef` in `effects.tres`, **THEN** its `z_index = layer * 10 + sub` is below 80 except `fx_cb_flash` (100) and the era-card time-dust and reveal burst (layer 11, z 110-119; Rule 1 exception, wave 4); no other def has a layer above 6, and none is below 2.
- **AC-02 [Unit] (Rule 2):** **GIVEN** a recorded 3600-tick gameplay run with a seeded RNG, **WHEN** replayed with `effects_level` FULL, REDUCED and MINIMAL (and with VFX removed), **THEN** the gameplay state hash at ticks 600, 1800 and 3600 is identical in all runs.
- **AC-03 [Unit] (Rule 2, 13):** **GIVEN** a run, **WHEN** debris spawns, **THEN** the gameplay RNG's draw count is unchanged versus a run with VFX disabled, and two VFX runs with the same seed produce identical instance lists (positions and frames).
- **AC-04 [Unit] (Rule 3):** **GIVEN** an instance spawned at tick 100 with `frame_ticks = [4,4,4]`, **THEN** its frame is 0 at ticks 100-103, 1 at 104-107, 2 at 108-111, and it is Free at 112; pausing the tick counter at 105 keeps frame 1.
- **AC-05 [Integration] (Rule 4):** **WHEN** a Critical Break is forced with `cb_force`, **THEN** the logic tick counter increments every tick through the break, and no code path calls `Engine.time_scale` or pauses the tree.
- **AC-06 [Integration] (Rule 5, 28):** **WHEN** the following events fire in a capture: part kill, bomb, player death, enemy kill, boss intro, enrage, era start, **THEN** no frame is a full-screen flash: the mean luma of consecutive frames differs by at most 8% (the same tolerance as Bombs AC-52). The only exception is the Critical Break white frame.
- **AC-07 [Unit] (Rule 5):** **GIVEN** `access.reduce_flashing` false, **WHEN** `critical_break_landed` fires at tick `T`, **THEN** `FlashState` shows exactly one rendered frame at `T+1` and none before or after. With 30 fps rendering it still shows exactly one rendered frame (F12).
- **AC-08 [Unit] (Rule 5, F12):** **GIVEN** a deprecated `screen_flash_requested` emission from any source, **THEN** no flash, tint or overlay is produced (the signal is not connected).
- **AC-09 [Integration] (Rule 6, Display scaler AC-34):** **WHEN** a Critical Break and its shake run, **THEN** the pixel diff over the bezel rects is 0, the canvas rect is unchanged, and the hurtbox positions of the boss are unchanged during the shake.
- **AC-10 [Unit] (F5):** **GIVEN** `A` = 4, `n` = 8, **THEN** `off_x` for `k` = 0..7 is +4, -3, +3, -2, +2, -1, +1, 0, and `off_y` is 0. With `effects_level` REDUCED or MINIMAL, all offsets are 0.
- **AC-11 [Unit] (Rule 8):** **GIVEN** the whole `src/` tree, **THEN** a lint finds no `draw_line`, `draw_circle`, `BLEND_MODE_ADD`, `GPUParticles2D` or `CPUParticles2D` in VFX code, and no per-effect `ShaderMaterial`.
- **AC-12 [Unit] (Rule 9, ADR-0001):** **GIVEN** `EffectPool`, `VfxDirector`, `FlashState`, **THEN** each extends `RefCounted`, has no `delta` parameter and calls no global `randf()` / `randi()`.
- **AC-13 [Unit] (Rule 16):** **GIVEN** 300 spawn requests of mixed tiers in one tick, **THEN** the live count never exceeds 150 (FULL), 75 (REDUCED), 37 (MINIMAL).
- **AC-14 [Unit] (F1):** `P_cap_eff` is 150, 75, 37 for FULL, REDUCED, MINIMAL.
- **AC-15 [Unit] (F2):** MUZZLE at `N` = 4 FULL gives 8; WEATHER at `N` = 3 FULL gives 32; CANCEL_PUFF at REDUCED `N` = 4 gives 20; `cap_eff >= 1` for every class at every level.
- **AC-16 [Unit] (Rule 18):** **GIVEN** each class filled to its cap, **WHEN** one more request arrives, **THEN** classes marked "evict oldest" free their oldest instance and admit; classes marked "drop request" refuse and increment the drop counter.
- **AC-17 [Unit] (Rule 19, F6):** **GIVEN** a full pool of 40 T4, 70 T3, 40 T2, **WHEN** a T1 request arrives 41 times, **THEN** the first 40 evict T4 oldest-first, the 41st evicts the oldest T3; a T2 request with only T0-T2 alive is dropped; a T0 request with only T0 alive evicts the oldest T0.
- **AC-18 [Unit] (Rule 19):** **GIVEN** two instances with the same tier and start tick, **THEN** the one with the lower pool index is evicted first (deterministic).
- **AC-19 [Unit] (Rule 20, Enemy V3):** **GIVEN** the pool at cap, **THEN** debris is evicted before SMALL bursts, and MEDIUM and LARGE bursts are never refused while debris or SMALL bursts exist.
- **AC-20 [Unit] (F11):** **GIVEN** Scenario A (181 requests), **THEN** 31 evictions, all weather, and every non-weather instance survives; Scenario B (232): 82 evictions (40 weather, 42 T3), all T0-T2 survive; Scenario C (161): 11 evictions, all weather.
- **AC-21 [Unit] (Rule 21):** **GIVEN** REDUCED, **THEN** no T4 instance spawns, no secondary pops, no kit flares, shake is 0, and counts follow F10 (CB burst 60 gives 30); MINIMAL: only T0-T1 defs spawn and LARGE spawns one burst, no chunks.
- **AC-22 [Unit] (Rule 22):** **GIVEN** `N` = 4, **THEN** tier 3-4 class caps are `70%` of the FULL values and tier 0-2 caps are unchanged; `N` = 2 gives 100%.
- **AC-23 [Integration] (Rule 28, 34):** **GIVEN** `access.reduce_flashing` true, **WHEN** a Critical Break fires, **THEN** no white frame is rendered, 80 `fx_cb_burst` particles spawn (40 at REDUCED), the tint ramp is 18 ticks with a maximum of 25%, and no consecutive frames differ in mean luma by more than 8% over a 10 s capture.
- **AC-24 [Unit] (Rule 23):** **GIVEN** 4 players dying on one tick, **THEN** 2 `fx_death_ring` and 2 `fx_death_ring_compact` spawn (ordered by the Collision rotation rank), 4 player explosions spawn, dust spawns once, and each ring has its slot's colour and pattern.
- **AC-25 [Unit] (F7):** **GIVEN** the bomb ring (36, 480, 12), `t` = 6 gives 258; the CB ring (24, 360, 18), `t` = 9 gives 192; the death ring `t` = 17 gives 80 and `alpha` at `t` = 20 gives 66.
- **AC-26 [Unit] (F3):** **GIVEN** `n` = 1350 and cap 40, **THEN** `stride` 34 and `kept` 40; `n` = 41 gives `kept` 21; `n` = 1350 with cap 12 gives `kept` 12; `n` = 0 spawns nothing and no ring.
- **AC-27 [Unit] (Rule 26):** **GIVEN** each cancel source in the Rule 26 table, **THEN** the ring def, size, duration and puff cap match; the Critical Break cancel spawns at most 12 puffs and no area ring; the stage clear-all spawns none.
- **AC-28 [Unit] (F4):** `n` = 1350 gives 10; `n` = 50 gives 6; `n` = 3 gives 3; `n` = 160 gives 8; `n` = 0 gives 0. The dust colour role is SHADOW (grey), never GOLD or CREAM.
- **AC-29 [Unit] (Rule 27):** **GIVEN** a SMALL, MEDIUM and LARGE kill, **THEN** burst sizes are 20 / 40 / 72, durations 12 / 18 / 36, chunk counts 3 / 6 / 12 (FULL), LARGE has pops at +8 and +16, and a ground target's burst is in band B1 with one scorch decal that expires after 180 ticks.
- **AC-30 [Unit] (Rule 27):** **GIVEN** a target destroyed once, **THEN** exactly one explosion spawns; a second `enemy_destroyed` with the same id is ignored.
- **AC-31 [Unit] (Rule 30, 31):** **GIVEN** an armoured hit, **THEN** no tint, a `fx_clank`; an ignored hit gives `fx_ping`; a normal hit tints for 2 ticks; a second hit within 6 ticks (SMALL) or 20 ticks (LARGE, part) starts no new tint; after hits in 3 throttle windows in a row, the tint is a steady 30% until one window passes with no hit.
- **AC-32 [Unit] (Rule 31, 34):** **GIVEN** `reduce_flashing` true, **THEN** the tint is replaced by a 1 px darker outline pulse under the same throttle and no white sprite tint ever applies. Spark caps hold: no more than 24 live sparks and 8 armoured or immune; the oldest is dropped first.
- **AC-33 [Integration] (Edge case):** **WHEN** the scene is freed with 150 live effects and with an active flash, **THEN** no errors, no leaked instances, and the flash node is hidden.
- **AC-34 [Unit] (Rule 32):** **GIVEN** 5 simultaneous lock tells, **THEN** at most 4 draw, and with more than 2 active the new ones are reticle-only; a fired lock flashes the reticle for 2 ticks; an unfired lock spawns 4 corners that fall 6 px and fade over 8 ticks and no muzzle flash.
- **AC-35 [Unit] (Rule 32):** **GIVEN** a flak fuse with `flak_delay` 36, **THEN** the spark blinks at ticks 12 and 24 (period 12), then every 6 ticks in ticks 24-30 (last 12), solid in 30-36, and the burst puff is 24 px.
- **AC-36 [Unit] (F9):** `pulse_pct(0, 30, 60, 100)` = 100, `(15)` = 60, `(7)` = 81, `(22)` = 78; with `reduce_pulsing` every call returns 100; a def with `P` < 20 or `hi - lo` > 40 fails the data lint.
- **AC-37 [Unit] (F8):** **GIVEN** `v16 = (24, -32)`, `g16 = 4`, **THEN** at `t` = 18 the offset is `(27, 4)` and `alpha` = 75; the chunk is Free at `t` = 24.
- **AC-38 [Unit] (F10):** CB burst 60 gives 30 (REDUCED) and 15 (MINIMAL); LARGE debris 12 gives 6 (REDUCED); a T1 def never scales below 1.
- **AC-39 [Unit] (Rule 33):** **GIVEN** the carrier rim, windup glow and crack overlay, **THEN** none of them occupy pool slots (pool count unchanged when they are active).
- **AC-40 [Unit] (Rule 24, 25):** **GIVEN** the effects atlas, **THEN** a palette lint finds no pixel with hue 225-265 and saturation >= 40%, no pixel equal to `#0B0B2A` or `#4A5CFF`, and no def uses the bullet shapes orb, rice, needle or outlined ring (def flag `bullet_shape_ok` is false for all).
- **AC-41 [Integration] (Rule 1, Rule 24):** **GIVEN** a 4P stress scene with 2,000 bullets and all effects forced on, **WHEN** captured, **THEN** every enemy bullet pixel is on top: no VFX pixel overlays a bullet pixel (z-order check by rendering VFX bands and bullets to separate masks; overlap of VFX above bullets is 0 pixels).
- **AC-42 [Manual] (grayscale gate):** **GIVEN** a 4P capture with a boss fight, bombs, kills and a Critical Break, converted to grayscale, **THEN** a reviewer can locate every enemy bullet and the hitbox dot in every frame outside the CB flash. Evidence: capture plus the reviewer's note.
- **AC-43 [Perf] (Perf budget):** **GIVEN** `vfx_bench.tscn` with 150 live instances plus 24 sparks, 4P, **THEN** on REF-WEB, `tick()` is at most 0.25 ms p99 and pack at most 0.35 ms p99 over 30 s after a 30 s warm-up; REF-PHONE runs 60 Hz ticks with no dropped ticks over 5 minutes.
- **AC-44 [Perf] (Draw calls):** **GIVEN** the 4P stress scene, **THEN** VFX draw calls are at most 8 (9 on the flash frame) and total draw calls stay under 200 (technical preferences).
- **AC-45 [Perf] (Rule 16):** **GIVEN** a 10 minute soak with random events, **THEN** the pool never exceeds 150, and there are zero per-frame allocations in `tick()` (allocation counter flat after warm-up).
- **AC-46 [Integration] (Rule 36):** **WHEN** `stage_cleared` fires with live effects, **THEN** no new spawns except HUD-side, live effects finish within 36 ticks, scorch decals remain; **WHEN** `stage_started` fires, **THEN** the pool is empty and the era atlas and palette material are loaded before the first spawn.
- **AC-47 [Integration] (Rule 34):** **GIVEN** each of the three `access.*` keys changed in settings, **THEN** the change applies at the next tick boundary and is read back after a save and load; defaults are FULL / false / false.
- **AC-48 [Unit] (Rule 35):** **GIVEN** era C and D defs, **THEN** their extra chips are DEBRIS class (T3) and absent at REDUCED; under pool pressure they are evicted before any T2 or higher effect.
- **AC-49 [Unit] (Edge case):** **GIVEN** a `cancel_report` of `n` = 0, **THEN** no ring or puff spawns; a bomb with `n` = 0 still spawns its bomb ring and dust.
- **AC-50 [Unit] (Edge case):** **GIVEN** gem pickups at 100 in 30 ticks, **THEN** at most 1 gem spark spawns per 2 ticks and at most 12 are live.
- **AC-51 [Integration] (Edge case):** **WHEN** the game pauses on `T+1` before the flash renders, **THEN** the flash renders once and hides; effect frames do not advance during the pause.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | How are large thin rings (up to 480 px) built without a shader or `draw_circle`? Recommended: bake stepped rings at stage load from four mirrored quadrants (about 0.5 MB for 7 steps); check VRAM and load time on Web. | technical-artist / godot-specialist (spike) | Before effects art |
| 2 | Hit tint implementation: shader instance uniform on the palette material (needs Compatibility + Web support; unverified in 4.7) or pre-drawn white-silhouette frames (more art)? | godot-shader-specialist (spike, art bible §8.9 spike 4) | Before enemy art |
| 3 | Is MultiMesh with per-instance custom data fast enough for 150 live effects on REF-WEB, or does the `AnimatedSprite2D` fallback win? Also confirm GPUParticles2D / CPUParticles2D behaviour on Godot 4.7 Web GL Compatibility (unverified; not used for gameplay effects). | godot-specialist | Web spike |
| 4 | Should the 8 draw bands be merged (B0 + B1; B2 + B3)? | technical-artist | After the perf bench |
| 5 | ~~Who owns the boss vignette: VFX (this GDD) or Parallax (23)?~~ **Closed 2026-11-03:** Parallax renders the vignette and enrage darken; `fx_boss_vignette` removed; B0 keeps scorch only (Parallax 23 Rule 20) | art-director / Parallax GDD | Parallax GDD |
| 6 | ~~What is the maximum number of simultaneous flak fuses? (TELL class assumes 8.)~~ **Closed 2026-11-03:** at most 8 lit fuses per scene, enforced by the Pattern library validator (per owner and scene) and its runtime skip rule (a volley that would light a 9th fuse is skipped, counts as fired, draws RNG) (wave 4 decision; Pattern library) | Pattern library (9) / Wave director (16) | Wave director GDD |
| 7 | ~~`access.effects_level` and `access.reduce_pulsing`: UI wording, and whether `REDUCED` should also lower the local shake rather than remove it~~ **Closed 2026-11-03:** REDUCED removes the local shake; no separate shake toggle; wording in the Accessibility registry (Accessibility 28) | Accessibility (28) / art-director | Accessibility GDD |
| 8 | Alert amber `#FFB000` for AMBER role: confirm in art bible §4.6 (already pending from Pattern library) | art-director | Art bible amendment |
| 9 | Does `kill_cancel_radius` need its own ring art, or should the MEDIUM / LARGE kill explosion cover it? Recommended default is the thin ring (Rule 26). | art-director | Playtest |
| 10 | Is a 4 px boss-sprite shake inside the 8 hurtbox budget visually honest (shot appears to hit 4 px off)? Only during the 8-tick CB. | game-designer | Playtest |
| 11 | Should co-op scale gem sparkles and muzzle flashes by player colour for feedback (rejected for now: only rings and tells use SLOT colour)? | game-designer | Co-op playtest |
| 12 | The project rule file `gameplay-code.md` says "use delta time"; ADR-0001 mandates integer ticks. This GDD follows ADR-0001. Confirm the rule file is meant for non-tick code. | lead-programmer | Anytime |

> Decided under auto-approve (2026-11-03): all Open Questions above have the recommended default applied until answered. Art direction items (colours, sizes) follow the art bible and the owning GDDs; `art-director` and `audio-director` were not consulted.

📌 **Asset Spec**: run `/asset-spec system:vfx-and-screen-feedback` after the art bible amendments are applied.
