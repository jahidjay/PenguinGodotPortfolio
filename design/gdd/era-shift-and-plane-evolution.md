# Era Shift and Plane Evolution

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: History Accelerates (primary) · Readable Chaos (bullet shapes, colours and radii never change) · Four Planes, Four Games (the base airframe stays nameable in 2100) · Every Hit Counts (all kit numbers identical in every era)

## Overview

**The data layer:** the **Era shift** (working name `EraShift`, node-free `RefCounted`, `tick()` at 60 Hz, no `delta`, no RNG; ADR-0001) owns what an era *is*. An era is one `EraDef` resource (`data/eras/era_<index>_<id>.tres`) that bundles: a palette layer, an enemy **role table** (role → `EnemyDefinition`), the era's place on the **behaviour / option ladder** (Straight → Accelerate → Curve → Warp), a `EraKitSkin` and `EraBombSkin` per kit, a bezel, a music set, a sound bank, a background set and an HUD tint. There are 4 eras (1941, 1970s, 2030s, 2100); MVP builds **1941 and 1970s fully** and defines 2030s and 2100 as **data stubs plus rules** (validator-checked, not playable). Era shift also owns the **novelty ladder rules** (one new behaviour and at most one new aim option per era), the **strip map** that removes un-debuted novelty from native enemy patterns (the Wave director decides *when*, Era shift decides *what*), the **era validator** (`EraValidator`), and the **era transition**: a 201-tick presentation that plays inside the Stage-end tally's exit hold, between the last stage's tally and the next stage's `stage_started`. The transition is presentation only: every logic result (which tables, skins and tags are live) is a function of the era index and the tick counter. It preloads the next era during the tally so the swap costs no frame time.

**The player impact:** the player feels the stage jump as a step in time: the tally closes, the screen dims, a year counter runs from 1941 to 1970, the cabinet frame changes, and their own plane shows a new bolt-on (pylon tanks, hook pylons) on the same airframe. Then the enemies come in angular, the sound is radar beeps, and the bullets *behave differently* (rice that accelerates, then fans that lock on). The shots look new and hit exactly as hard as before. Nothing about the plane's power, the bullets' shapes, colours or hit sizes, or the HUD changes, so everything the player learned still works (**History Accelerates**, **Readable Chaos**).

## Player Fantasy

**Anchor moment: "I was just in the war, and now the sky has jets."** The boss deck is burning, the tally counts your chain, and then the world slides forward. 1941 becomes 1970 on a ticking counter, the olive cabinet frame turns steel and orange, and your plane, the same ace's plane, wears new hardware. You launch into stage 2 and the enemies are cold angular darts. A rice stream you had not seen before curves up to speed. You are not stronger. The world is faster, and you are ready for it.

- **The jump is felt, not watched.** It lasts 3.4 s at most, can be skipped with one press, and has no cutscene. It is a doorway, not a movie.
- **Same ace, new tech.** The base airframe never changes; only bolt-ons and the palette do. A tester can name the plane in 2100 (Player plane AC-36).
- **Power is constant, the question is new.** Era changes the bullet language (behaviour, aim, patterns), never the player's numbers. Skill transfers from 1941 to 2100.
- **Each era asks one new thing, alone first.** The new behaviour is stripped from ordinary enemies until its debut wave, so the player meets it in a preview, then in the world, then in the boss.
- **Nothing flashes.** Dim, count, reveal. All screen brightness changes are small stepped moves in one direction.

**Anti-fantasy (must never happen):** an era that is only a recolour; a plane that gets stronger by era (anti-pillar: stat grinding); a bullet whose shape or colour depends on era; a transition longer than 4 s or one that cannot be skipped; a screen flash or a fast brightness reversal; an enemy using the new behaviour before its preview; a plane whose silhouette is no longer recognisable; a frame hitch when the era loads.

> `creative-director` not consulted (auto-approve). Concept §3 says the plane evolves in "look, shot, ability visuals/power". This GDD reads that as **visuals only** (Plane kits Open Question 14) and records it as a decision.

## Detailed Design

### Core Rules

**What an era is (data)**

1. An era is an **`EraDef`** resource, `data/eras/era_<index>_<id>.tres`, one per era, `index` 0 to 3. Fields:

   | Field | Type | Meaning |
   |---|---|---|
   | `id`, `index` | StringName, int | `era_1941` / 0, `era_1970s` / 1, `era_2030s` / 2, `era_2100` / 3. One stage per era: stage `n` uses era `n - 1` (MVP and Target). |
   | `status` | enum | `COMPLETE` (playable) or `STUB` (data + rules only; loads only in debug "preview" mode; a release build refuses a run longer than the last `COMPLETE` era) |
   | `year`, `year_label_key` | int, key | 1941, 1970, 2030, 2100 (ticker target) and the label key (`era.name.1941` and so on, bilingual) |
   | `palette` | `PaletteLayer` ref | The era's colour roles (Sky, Far, Mid, Ground, Accent, Shadow, enemy body / outline) from art bible 4.5, plus a Nx1 LUT texture for the `canvas_item` palette-swap shader (art bible 8.4). The hex values live in the art bible and in this resource; the validator compares luma bands, not copies. |
   | `ui_tint` | Color | The era Accent (muted); HUD, tally and bezel use it at 20 % on frame edges only (art bible 4.7) |
   | `muzzle_colour` | Color | Pattern library V1 (1941 sepia-orange, 1970s hard orange, 2030s cyan, 2100 magenta); also the carrier stripe colour (Boss power budget V) |
   | `enemy_grammar` | enum | `ROUND`, `ANGULAR`, `HEX`, `FRACTURED` (art bible 3.2) |
   | `role_table` | path | `data/enemies/<era>/roles.tres`: role (`fodder`, `fighter`, `gunner`, `heavy`) → `EnemyDefinition` (Rule 4) |
   | `new_behaviour` | enum | `NONE` (era 0: Straight is the base) / `ACCELERATE` / `CURVE` / `WARP` |
   | `new_option` | enum | `NONE` / `AIM_LOCK` / `REAIM_EACH_VOLLEY` (Rule 9) |
   | `kit_skins` | dict | kit id → `EraKitSkin` ref (Plane kits Rule 41) |
   | `bomb_skins` | dict | bomb id → `EraBombSkin` ref (Bombs Rule 34) |
   | `bolt_ons` | dict | plane id → up to 2 bolt-on sprite ids (Player plane V8) |
   | `drone_sprites` | dict | kit id → drone sprite set id |
   | `bezel_id` | id | Display scaler bezel art for the era |
   | `bg_set` | id | Parallax background set (art bible 6.2 settings) |
   | `music_set`, `sfx_bank` | id | Audio music cue prefix and the timbre bank (Pattern library A1) |
   | `asset_sets` | dict | `core` (enemies, bosses, fx; about 20 MB) and `env` (about 36 MB) resource paths, for staged loading (Rule 20) |
   | `ttk_mult_x100` | int | Enemy hp guidance, 100 (1941) / 125 (1970s) / 150 / 175 (Enemy knob) |

2. **Four palettes are always resident** (4 small LUT textures). Menus, attract mode and the tally can read any era's palette without a load (`EraShift.palette(era_index)`).
3. **One palette material per era per atlas** (art bible 8.4). Palette swaps are used for plane bases, props, debris, explosions, smoke and UI tint. Enemies, bosses and bolt-ons are separate sprites (art bible 3.1, 3.2, 5.5).
4. **Role table (role → `EnemyDefinition` per era).** The role slots never change; the definitions do. 1941 and 1970s are from Enemy and AI 3; 2030s and 2100 are **stub proposals** (marked `STUB`, names provisional, pattern numbers not authored until the Target milestone).

   | Role | 1941 (stage 1) | 1970s (stage 2) | 2030s (STUB) | 2100 (STUB) |
   |---|---|---|---|---|
   | `fodder` (SMALL, unarmed) | Scout (round, hp 20) | Dart jet (angular, hp 20) | Drone mote (hex disc) | Shard mote (broken-symmetry shard) |
   | `fighter` (SMALL, armed) | Prop fighter: aimed 3-round stream, orbs, Straight (hp 40) | Delta jet: aim-locked fan, accelerating rice (hp 50) | Hex drone: curving arc fan (Curve) | Phase fighter: warp ring (freeze, re-aim) |
   | `gunner` (MEDIUM, ground) | Flak gunner: flak ring (hp 1,200) | Radar gunner: aim-locked 5-fan (hp 1,500) | Shield pylon: timing-window spiral, plating | Echo turret on a floating shard: warp fan |
   | `heavy` (LARGE, air) | Heavy bomber: wall + tail fan (hp 4,000) | Missile carrier: wall + aim-locked 7-fan (hp 5,000) | Aegis carrier: plated, wall + curve spiral | Rift bomber: warp ring + fan |

   *Hp, patterns and bullet counts for 2030s and 2100 are not set here.* The 2030s "lasers" are not bullets (Pattern library Open Question 6) and are not part of the stub (Open Question 4). The 2100 `gunner` has no ground in its setting (art bible 6.2); the stub uses `layer = GROUND` on a floating shard that drifts with the background (Open Question 5).

**Era identity: what changes and what never does**

5. The table below is the contract. A change in the left column needs only an `EraDef`. A change in the right column is a design change that needs an anti-pillar review and a registry amendment.

   | Evolves per era (data in `EraDef`) | Owner | Never changes between eras | Owner |
   |---|---|---|---|
   | Palette layer, Accent, UI tint | Era shift | **Base airframe silhouette** (4 planes) | Art bible 3.1 |
   | Enemy shapes (grammar), role definitions, native patterns | Enemy (10) | Enemy bullet shapes (orb, rice, needle, ring), colours, outline | Bullet manager V7 |
   | Which bullet behaviours and aim options exist | Era shift (ladder) | Hit radii (2.5 / 1.5 / 1.25 / 2.0 px), `v_min`, `v_cap_global` | Bullet manager |
   | Plane bolt-ons (max 2 sprites per plane per era), drone sprite, shot and beam art, muzzle art | Kits (11), Player plane (5) | All kit numbers: damage, interval, count, angle, speed, width, cooldown, duration, meter (AC-35 of Kits) | Plane kits |
   | Bomb art, sound ids, warm tint | Bombs (12) | All bomb numbers (Bombs AC-44); Tracer Orange stays for bomb FX | Bombs |
   | Muzzle flash colour, explosion palette, smoke, weather | VFX (25), Pattern library V1 | Player hitbox 3 px, dot, ring, P-colours and patterns | Player plane (5) |
   | Sound timbre (shot, volley, music) | Audio (24) | Cue timing, what each cue means, retrigger gap | Pattern library A1 |
   | Bezel art, HUD era tint (20 %, frame edges) | Display (4), HUD (20) | HUD style, layout, rect sizes; tally layout; canvas 360x640 | HUD, Tally |
   | Background set, boss atlas, boss arena | Parallax (23), Boss (14) | Chain, score, lives, bombs, drones (max 4), Critical Break rules | Their own GDDs |
   | Hp guidance `ttk_mult` (1.0 / 1.25 / 1.5 / 1.75) | Enemy (10) | `chain_window`, `player_cap`, `enemy_cap`, 1,700 budget | Registry |

6. **Plane evolution is look-only.** Each kit has one `EraKitSkin` and one `EraBombSkin` per era. A skin may change sprite and animation ids, beam texture, bolt-on art, muzzle flash art, sound ids, and muzzle positions within +/-4 px (kits) or tint within the warm range (bombs). Era shift selects the skin by `era_index`; it never edits a number. The anti-"stat grind" test is the numeric hash (Rule 33, E-V9).
7. **Silhouette rule.** The base sprite is authored once in the 1941 palette and mapped per era (art bible 5.5). A bolt-on is a separate sprite on draw layer 7, inside the base envelope plus about 6 px, never within 8 px of the hitbox centre, single frame, following the bank with a +/-1 px offset. At most 2 bolt-on sprites per plane per era. 1941 hardware (Lancer fixed cannons and spine, Leech bent-wing claws) is part of the base art; the first bolt-on set is the 1970s one (Lancer wing pylon tanks, Leech hook pylons under the kink).

**The behaviour and option ladder (novelty)**

8. **Behaviour ladder** (owned here; data = `new_behaviour` of each `EraDef`). The set of allowed behaviours of era `n` is the set of era `n - 1` plus `new_behaviour(n)`:

   | Era | Stage | New behaviour | Allowed behaviours |
   |---|---|---|---|
   | 1941 | 1 | none (base) | Straight |
   | 1970s | 2 | Accelerate | Straight, Accelerate |
   | 2030s | 3 | Curve | Straight, Accelerate, Curve |
   | 2100 | 4 | Warp | Straight, Accelerate, Curve, Warp |

   Stage 1 is **Straight only**. Flak rings and walls are patterns, not behaviours (Boss power budget Rule 18). *(Pattern library V4 says "Straight, some Curve" for 1941; that is a conflict, resolved here in favour of the budget and concept §10. → Amendment 5.)*
9. **Option ladder** (aim and fuse options, Boss power budget Rule 19): at most one **new** option per era:

   | Era | New option | Allowed options |
   |---|---|---|
   | 1941 | none (`flak_fuse` is the base option and its signature) | `flak_fuse` |
   | 1970s | `aim_lock` (fixed by Boss power budget) | `flak_fuse`, `aim_lock` |
   | 2030s | `reaim_each_volley` | `flak_fuse`, `aim_lock`, `reaim_each_volley` |
   | 2100 | none (Warp already re-aims) | all three |

   The 2030s and 2100 rows are **Target-tier proposals** to be confirmed when those bosses are designed (Open Question 1).
10. **Novelty tags.** A new behaviour or option is a **novelty tag**: `behaviour:accelerate`, `behaviour:curve`, `behaviour:warp`, `option:aim_lock`, `option:reaim_each_volley` (tag format from Boss power budget Rule 19). An era's tag set is `{tag(new_behaviour), tag(new_option)}` minus `NONE`. The stage's boss must own exactly these tags, one mechanic each (Boss power budget V8): the Fortress owns none; the Jet owns `behaviour:accelerate` (`m1_accel_fan`) and `option:aim_lock` (`m4_radar_lock`). *(Cross-check E-V8.)*
11. **Native patterns may carry novelty.** An `EnemyDefinition` in era `n` may use that era's new behaviour or option in its patterns, but each such emitter must list the tag in `novelty_tags` so it can be stripped. A native emitter may not use a behaviour or option outside the era's allowed set, and may not carry a tag of a later era. *(E-V4, E-V5.)*
12. **Stripping (novelty gating).** The Wave director decides *when* (Director Rule 19 / F9: waves before the debut wave, and the debut wave before its first preview spawn) and passes `strip_tags[]` in the spawn params. Era shift owns the **strip map** (`data/eras/strip_map.tres`), a pure function `StripMap.apply(pattern, strip_tags) -> pattern'`:

    | Tag stripped | Transform | Notes |
    |---|---|---|
    | `option:aim_lock` | `lock_ticks` = 0 (fires at the aim point sampled at the volley tick, no tell) | Lock tell, tone and reticle do not play |
    | `behaviour:accelerate` | Straight at `v_strip` (F4) | Default `V_EFF`: `v_strip = (speed + v_cap) / 2`. `INITIAL` mode (the Enemy and Director wording): `v_strip = speed`. |
    | `behaviour:curve` | Straight at `speed` | turn rate dropped |
    | `behaviour:warp` | Straight at `warp_speed` | never freezes or re-aims |
    | `option:reaim_each_volley` | one aim sample at spawn, kept for all volleys | |

    Count, interval, arm count, shape and colour are never changed by stripping. Stripped values are clamped to `[v_min, v_cap_global]` = 70 to 480 px/s. **Preview patterns are never stripped** (they are the debut). The stripped version of any pattern must itself be legal in the **previous** era (E-V7). The validator's density check uses `max(N_def(native), N_def(stripped))` (Open Question 3 if Wave director F3 must change).
13. **Debut order a player experiences** (per era with a novelty): native enemies fire stripped patterns → the preview wave shows the tag alone on a carrier → the tag opens for natives (the debut wave's first preview spawn) → the boss mixes it. Era shift guarantees the data side; the Director schedules it; Boss power budget lints it.
14. **Not a reskin.** For era `n > 0`: (a) at least one native armed role uses a tag of the era (the **signature role**; the 1970s `fighter`); (b) every armed role's pattern signature `(family, behaviour, option)` differs from the same role in era `n - 1`; (c) the `enemy_grammar` differs; (d) enemy sprite ids carry the era tag. This is the concept test "an era must change the bullet language, not just reskin enemies" as a validator rule (E-V6).

**Constants Era shift guards (it never carries them)**

15. `EraDef` has **no field** for bullet shape, bullet colour, outline, hit radius or enemy-bullet contrast. The validator enumerates every emitter in every role table and boss and checks shape ∈ {orb, rice, needle, ring}, the registered radii, and the single constant bullet palette (E-V10). Era palettes may never lower enemy-bullet contrast: the grayscale test on the era background bands (art bible 4.5 luma 8 to 128, 2030s edge peak 156) is a Manual AC.

**Run flow and the transition**

16. **First era.** *(2026-11-03, ADR-0004:)* era 0's `core` and `env` sets are **pre-loaded by the `start_run` handshake** before Session starts the run, so Loading(0) finds them resident and emits `era_ready` on its first tick; the steps below remain the fallback (debug start-at-stage-N). On `run_started` (Session) Era shift enters **Loading(0)**: it loads era 0's `core` and `env` sets (no transition) and emits `era_ready(era_1941)` when both are resident. The Director's first `load_stage` waits for it. A debug "start at stage N" runs the same path for era `N - 1`.
17. **Staging.** On `stage_cleared(stage_index)`, if a next stage exists, Era shift enters **Staging(next)**: it reads `next_era = era_for_stage(stage_index + 1)`; frees the old era's `core` set (no enemies or boss exist after `despawn_all`); starts a threaded load of the next era's `core` set. If no next stage exists (final stage), nothing is staged.
18. **Hold.** On `tally_exit(stage_index, from_era, to_era)` with `from_era != to_era`, Era shift calls `request_exit_hold("era_shift")` on the same tick (tick **T0**) and starts the transition. If `to_era == from_era` (debug only) it emits `era_ready` at once and requests nothing. The Tally caps the hold at `era_hold_max` (240) and runs its own 45-tick panel fade at the same time (Tally Rule 18).
19. **Transition timeline** (ticks from T0; default / full mode; F1):

    | Ticks | Phase | What happens (presentation) | Logic |
    |---|---|---|---|
    | 0 to 44 | **Dim** | Tally panel fades out (Tally). The held frame's warm overlay steps 55 % → 63 / 70 / 78 / 85 % at ticks 0 / 11 / 22 / 33. Time-dust starts at tick 12. | `request_exit_hold` at 0 |
    | 45 to 52 | **Card in** | The era card (plated, Rule 21) slides in over 4 stepped positions (ticks 45 / 47 / 49 / 51) | At tick 53 the old env set is freed (the canvas is covered); the next env set load starts |
    | 53 to 112 | **Jump** | Year ticker runs from the old year to the new year over `year_ticks` 60 (F2). Card accent edge steps old → new Accent at ticks 53 / 74 / 95 / 116. | **Swap commit at tick 90** (Rule 22) |
    | 113 to 128 | **Name** | The bilingual era name plate steps in (ticks 113 to 116) and holds | |
    | 129 to 200 | **Reveal** | Plane cells show each counted slot's plane in the old look (129 to 140), then the bolt-on slides out and the new one slides in over 4 steps (141 / 143 / 145 / 147), one burst of 24 accent-colour particles at tick 147, then the new look holds to tick 200 | |
    | **201** | **Release** | Card fades out over 8 ticks (to 209). | `release_exit_hold("era_shift")` and `era_ready(to_era)` **if the env set is ready** (Rule 23) |

    The hold lasts **201 ticks (3.35 s)** by default, 39 ticks under `era_hold_max`.
20. **Staged loading.** Resources load with `ResourceLoader.load_threaded_request` and are polled every `poll_ticks` (6) ticks, not every tick. *(The API is stable since Godot 4.0; behaviour of threaded loading on the Web export in 4.7 is unverified; see Open Question 2.)* Memory is staged so the peak stays under the 96 MB VRAM target (F3):
    1. Always resident: about 18 MB (bullets, planes, UI, fonts, bezel).
    2. At `stage_cleared`: free old `core` (about 20 MB), load next `core`.
    3. At tick 53 (card covers the canvas): free old `env` (about 36 MB), load next `env`.
    4. `env_preload_early` = true (default false) loads both sets at `stage_cleared`; peak 110 MB, over target; for desktop only.
21. **The era card** (layer 11, calm, no bullets on screen; its time-dust and reveal burst are VFX instances that VFX Rule 1 allows on layer 11 as the era-card exception, because no enemy bullets exist during the transition (2026-11-03, wave 4)): a chamfered Cabinet Char plate with a 1 px `#5A5148` edge and a 1 px era Accent inner edge. Contents: the year ticker, the era name (Bengali over English), and one plane cell per **counted slot** (Rule 24). No text about numbers or power. The card never uses Void Indigo, Ink or a reserved bullet shape.
22. **Swap commit (tick 90).** One atomic tick. Era shift sets `current_era = to_era` and: points Enemy at the new `role_table`; sets each kit and bomb to the new skin by `era_index`; sets the palette LUT of the player atlas; sets the HUD / tally / bezel tint; sets the Audio sound bank and music set; emits `era_swap_committed(era_index)` (Display swaps the bezel in 8 frames, Audio swaps its bank). No enemy, boss, bullet or item exists at this time (field clear, tally). Era shift emits nothing to Scoring, Chain or the Director at commit.
23. **Release rule.** The hold is released at `release_tick = clamp(max(plan_end, env_ready_tick), 0, era_hold_max)` (F1). If the env set is not ready at `era_hold_max`, Era shift **loads it synchronously** at that tick (hitch hidden under the card), logs `era_load_late`, and drops the logic ticks the hitch consumed (no catch-up burst; → ADR / Session), then releases. `era_ready(to_era)` is emitted at the release tick, before the Tally reaches Done. Session then sets `stage_index + 1`, calls `Director.load_stage`, and the Director emits `stage_started(stage_index, era)` (Director Rule 25, amended to "`era_ready` latches before Tally Done").
24. **Counted slots on the card** follow the Tally's rule (Alive or Dead at tick 0, not Continue / Inactive / Waiting). Selecting slots show a "JOIN" cell; a slot that finishes picking a plane gets a cell in the **new** look, with no reveal. Layout: 1P one 120x120 cell; 2P two 120x120; 3-4P four 72x72, fixed slot order, slot tag 14x14 with the P-colour edge.
25. **Skip.** A `pN_fire` press edge from any counted slot after `era_skip_lockout` (75 ticks from T0) fast-forwards: if the swap has not committed it commits now; the card jumps to the final reveal composition; release = `max(skip_tick + skip_tail_ticks (12), env_ready_tick)`. The skip never changes a logic result (commit contents are the same), only the tick it happens.
26. **Short mode** (setting `access.era_transition_short`, bool, default false; registered by Accessibility 28, stored by Save 26): `year_ticks` 24, commit at tick 62, reveal 78 to 95, release at tick **96**. Env readiness still gates release, so short mode only helps when loading is ready.
27. **Reduce flashing** (`access.reduce_flashing`, registry): no time-dust, no particle burst at the reveal, the accent edge changes once (at commit) instead of in 4 steps. The dim steps stay (they are already monotone and under 10 %).
28. **Brightness rule for the whole transition** (F5): every full-canvas brightness change is a step of at most `luma_step_max_pct` (10 %); steps move in one direction at a time; no opposite-direction change of 10 % or more inside any 60-tick window. The dim phase (down, ticks 0 to 33) and the next stage's fade-in (up, Parallax) are at least 170 ticks apart. *(Art bible 6.8 / 7.7: particles, not flashes; Critical Break is the only flash.)*
29. **Final stage and run end.** After the last stage's tally there is no transition (`to_era` = none). On `run_ended` or return to title, Era shift frees the era sets and returns to **Inactive**; the title and plane select use the neutral warm bezel (Display Rule 12). The Menus' attract mode may call `palette(era_index)` and a read-only preview of a bolt-on set without staging.
30. **Pause and mid-transition events.** Era shift is ticked by `SimWorld` at **GameLoop step 8f** (after the Stage-end tally at 8e, so `tally_exit` is seen on the same tick; ADR-0002) and does not tick while paused. A pad disconnect pauses it. A pause during the transition freezes the timeline and the year ticker.

**Validation** (`EraValidator.check(era_defs, role_tables, boss_defs, skins, rules)`, a unit test over `data/eras/` and at load: debug asserts, release logs and plays on)

| ID | Check |
|---|---|
| E-V1 | 4 `EraDef`s, unique `id` / `index` 0 to 3 in order, `status` consistent (MVP: 0 and 1 `COMPLETE`, 2 and 3 `STUB`), one stage per era, `enemy_grammar` unique |
| E-V2 | Ladder is cumulative: `allowed_behaviours(n) = allowed(n-1) ∪ {new_behaviour(n)}`; at most 1 new behaviour and 1 new option per era; era 0 has none; Straight is in every era |
| E-V3 | Each `role_table` maps exactly the 4 roles to existing `EnemyDefinition`s whose path era folder matches; MEDIUM / LARGE sizes match the role; kill classes match |
| E-V4 | Every native emitter's behaviour and option ∈ the era's allowed sets |
| E-V5 | Every native emitter that uses the era's new behaviour or option lists its tag; no emitter carries a tag of another era |
| E-V6 | Not a reskin (Rule 14); `COMPLETE` eras only |
| E-V7 | `StripMap.apply` of every tagged native pattern is legal in era `n - 1`, keeps count / interval / arms, stays inside `[70, 480]` px/s, and passes the lane and density checks |
| E-V8 | The era's boss novelty tags equal the era's tag set (Fortress: none; Jet: `behaviour:accelerate`, `option:aim_lock`); the boss uses nothing outside the allowed sets |
| E-V9 | For each implemented kit and bomb and each `COMPLETE` era, a skin exists; the hash of all numeric fields is equal across eras; kit muzzle offsets within +/-4 px; at most 2 bolt-on sprites per plane per era |
| E-V10 | No emitter shape outside {orb, rice, needle, ring}; radii equal the registry; the bullet palette id is the single constant one; `EraDef` schema has no bullet-style field |
| E-V11 | All referenced asset ids exist (palette LUT, bezel, bg set, music set, sfx bank, sprites); each atlas uses one palette material per era |
| E-V12 | Timeline: phase table of Rule 19 matches `transition_rules.tres`; `release_tick` ≤ `era_hold_max`; dim levels and fade steps satisfy F5 |
| E-V13 | Determinism: no RNG calls in `EraShift`; two runs of the same inputs give equal `state_hash()` |

### States and Transitions

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| Inactive | No run | Loading(0) | `run_started` |
| Loading(0) | First era sets loading | Active(0) | both sets ready → `era_ready` |
| Active(e) | Era `e` is live; Era shift is not ticked except load polling | Staging(e+1) / Inactive | `stage_cleared` with a next stage / `run_ended` |
| Staging(n) | Old `core` freed, next `core` loading, waiting for the tally | Transition | `tally_exit(…, from ≠ to)` |
| Transition | T0 to release: Dim → Card in → Jump → Name → Reveal | Releasing | `release_tick` reached |
| Releasing | Waiting for env ready (up to the hold cap), then late-load if needed | Active(n) | `era_ready` emitted, hold released |
| Failed | A required asset did not load after one retry | Inactive | `era_failed`; Session ends the run unranked (Open Question 6) |

Any state → Inactive on `run_ended` or abandon (staged assets freed). The transition phases are a function of `t = tick - T0` and the readiness flag.

### Interactions with Other Systems

Interfaces to Parallax 23, Audio 24, VFX 25, Accessibility 28 and Menus 22 were checked against their GDDs on 2026-11-03 (wave 3b). The Director supplies `next_era` (from `era_for_stage`) and `is_last_stage` to the Tally at `stage_cleared`.

| System | Direction | Interface |
|---|---|---|
| Game events and session (1) — GDD | ↔ | ← `run_started`, `stage_cleared`, `run_ended`, pause, `stage_index`, slot states. → `era_swap_committed(era_index)`, `era_ready(era_id)`, `era_load_late(era_id, ticks)`, `era_failed(era_id)`. Session sets `stage_index + 1` after Tally Done and requires `era_ready` first. |
| Stage-end tally (21) — GDD | ↔ | ← `tally_exit(stage_index, from_era, to_era)`. → `request_exit_hold("era_shift")` / `release_exit_hold("era_shift")`, cap `era_hold_max` 240. The tally's own 45-tick fade runs inside the Dim phase. |
| Wave and stage director (16) — GDD | ↔ | → `era_ready(era_id)`; `era_for_stage`; `StripMap.apply`; ladder queries. ← `stage_started(stage_index, era)`, `strip_tags[]` decision (Director F9), `StageDef.era_id`. Director calls `load_stage` only after `era_ready`. |
| Enemy and AI (10) — GDD | → | Role table per era (`role → EnemyDefinition`); `StripMap.apply` for spawn params `strip_tags`; era swaps only at stage boundaries (Enemy edge case). |
| Boss power budget (15) — GDD | ↔ | → `EraLadder.allowed_behaviours(era)`, `allowed_options(era)`, era tag set. ← `novelty_debut_wave(stage, tag)`, boss novelty tags (E-V8). The budget's `behaviour_ladder` knob becomes a read of `EraDef`. |
| Boss and boss parts (14) — GDD | → | Boss atlas and arena belong to the era `core` / `env` sets. |
| Bullet pattern library (9) — GDD | ↔ | → era language (V4), muzzle colour, timbre. ← patterns, `PatternMetrics` (F3, F8, F9) for E-V7. The library keeps no era logic. |
| Bullet manager (3) — GDD | ← | V7 constants (shapes, radii, colours); read-only by the validator. |
| Plane kits (11) — GDD | → | `EraKitSkin` by `(kit, era_index)`; numeric hash test. ← kit numbers (read-only for E-V9). |
| Bombs (12) — GDD | → | `EraBombSkin` by `(bomb, era_index)`. |
| Player plane (5) — GDD | → | `era_index` for bolt-ons and the palette LUT of the player atlas (V8). |
| Display scaler and bezel (4) — GDD | → | `era_swap_committed(era_index)` (replaces `stage_started` as the bezel swap trigger, Rule 12; `stage_started` stays as a fallback). `bezel_id` per era. |
| HUD (20) — GDD | → | `ui_tint` for `HudTheme`; layout never changes. HUD is hidden during the tally and the transition. |
| Parallax and environment (23) — GDD | ↔ | → `bg_set`, palette LUT, `free_set()` at transition tick 53, `prepare(stage_id)` after it, `era_swap_committed` shows the new set, `era_ready` starts Parallax's stage fade-in (Parallax Rule 28a: overlay at z 105 owned by Parallax, levels 85, 76, 66, 57, 47, 38, 28, 19, 9, 0, 4 ticks per step). ← `env_prepared(stage_id)`, which must arrive before `era_ready`. Env set about 22.5 MiB fits the 36 MB env budget. |
| Audio (24) — GDD | → | `era_swap_committed` (swap bank and music set); cues `era_dim`, `era_tick`, `era_commit`, `era_reveal`, `era_release`. |
| VFX and screen feedback (25) — GDD | → | Time-dust, reveal burst (layer 11, 24-particle cap, shared 150 cap). Allowed above the bullet layer by the VFX Rule 1 era-card exception (no bullets alive; wave 4). |
| Localization (27) — GDD | ← | `text_both(key)` for era names; **needs a no-grouping number formatter** for years (`format_int` would print "1,941"). |
| Save, settings (26) — GDD | ← | `access.reduce_flashing` (registry); `access.era_transition_short` (registered by Accessibility 28). No writes. |
| Menus (22) — GDD | ← | `palette(era_index)` for attract mode; run start waits on `era_ready`. |
| Accessibility (28) — GDD | ← | Registers `access.era_transition_short` (PRESENTATION, apply EVENT, not in the Calm preset). |

> Decided under auto-approve (2026-11-03): an era is one `EraDef` resource plus per-kit skins; one stage per era; plane evolution is **visual only**; ladder: Straight → Accelerate → Curve → Warp, options `flak_fuse` (base), `aim_lock` (era 2), `reaim_each_volley` (era 3), none (era 4); 1941 is Straight only (resolves Pattern library V4); strip map is owned here and the Director only decides when; default strip speed `V_EFF` (density parity, differs from the "same initial speed" wording); transition is 201 ticks inside the tally exit hold with swap commit at tick 90, skippable after tick 75; short mode and reduce-flashing variants; staged memory loading; late load is synchronous under the card; bezel swaps at `era_swap_committed`; 2030s and 2100 are data stubs.

## Formulas

All integer, 60 ticks/s. Constants come from `data/eras/transition_rules.tres` and `data/eras/*.tres`. Validator maths runs offline and at load; floats are allowed there, stored results are integers.

**F1. Transition timeline and release tick** *(`era_release_tick`)*

```
plan_end(full)  = reveal_start + old_hold + swap_ticks + new_hold
plan_end(short) = short_release
plan_end(skip)  = min(plan_end, skip_tick + skip_tail_ticks)
release_tick    = clamp(max(plan_end, env_ready_tick), 0, era_hold_max)
late_load       = env_ready_tick > era_hold_max
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Reveal start | `reveal_start` | int ticks | 100–160 (129) | Start of the plane reveal |
| Old hold | `old_hold` | int ticks | 6–24 (12) | Old look shown |
| Swap ticks | `swap_ticks` | int ticks | 4–16 (8) | 4 steps x 2 ticks |
| New hold | `new_hold` | int ticks | 24–90 (52) | New look shown |
| Short release | `short_release` | int ticks | 60–120 (96) | Short mode |
| Skip tick | `skip_tick` | int ticks | ≥ `era_skip_lockout` (75) | First valid press |
| Skip tail | `skip_tail_ticks` | int ticks | 6–30 (12) | Time to show the final composition |
| Env ready | `env_ready_tick` | int ticks | 0 to unbounded | Tick (from T0) when the next env set reports loaded |
| Hold cap | `era_hold_max` | int ticks | 0–480 (240) | Owned by Tally |

**Output Range:** 96 to 240 (the hold never exceeds the cap). Full default `plan_end` = 129 + 12 + 8 + 52 = **201**.
**Example:** env ready at 150 → release **201**. Env ready at 230 → release **230**. Env ready at 300 → release **240**, `late_load` = true, the set loads synchronously at 240. Skip at tick 100 with env ready at 150 → `plan_end` = min(201, 112) = 112 → release `max(112, 150)` = **150**. Skip at tick 80 (swap not yet committed) → commit at 80, release `max(92, env_ready)`. Short mode, env ready at 70 → **96**.

**F2. Year ticker** *(`year_shown`)*

`year_shown(k) = from + ((to − from) × k + W / 2) / W`, integer division, `k = 0 … W` (the tally's TF2 rule)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| From, To | `from`, `to` | int | 1941–2100; `to > from` | Years of the old and new era |
| Window | `W` | int ticks | 24 (short) or 60 (full) | `year_ticks` |
| Step | `k` | int | 0–W | Ticks since the ticker start (tick 53) |

**Output Range:** `from` at k = 0; exactly `to` at k = W (the rounding term `W/2` < W adds 0). Never decreases.
**Example (1941 → 1970, W = 60):** k = 15 → 1941 + (29 × 15 + 30)/60 = 1941 + 465/60 = 1941 + 7 = **1948**; k = 30 → 1941 + 900/60 = **1956**; k = 45 → 1941 + 1,335/60 = **1963**; k = 60 → 1941 + 1,770/60 = **1970**. (2030 → 2100, k = 30 → 2030 + (70 × 30 + 30)/60 = 2030 + 35 = **2065**.)

**F3. Staged VRAM peak** *(`era_vram_peak`)*

```
peak_staged = A + max(S_core + S_env,                  # steady state
                      S_env_old + S_core_new,          # after step 2
                      S_core_new + S_env_new)          # after step 3
peak_early  = A + S_env_old + S_core_new + S_env_new   # old core already freed
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Always resident | `A` | MB | 18 | Bullets, planes, UI, fonts, bezel (art bible 8.x) |
| Era core set | `S_core` | MB | 20 | Enemies and bosses 18 + fx 2 |
| Era env set | `S_env` | MB | 36 | Backgrounds and props |
| Targets | | MB | 96 target / 128 hard | Art bible 8.x proposal |

**Output Range:** peak_staged = **74 MB**; peak_early = **110 MB**. Staged is under the 96 MB target; early is under the 128 MB cap but over the target, so it is off by default.
**Example:** steady 18 + 20 + 36 = 74; after freeing old core: 18 + 36 = 54; after loading new core: 54 + 20 = 74; after freeing old env: 18 + 20 = 38; after loading new env: 38 + 36 = 74. Early: 18 + 36 + 20 + 36 = 110.

**F4. Strip speed** *(`strip_speed`)*

```
Accelerate → Straight:  v_strip = clamp(round((speed + v_cap) / 2), v_min, v_cap_global)   [V_EFF, default]
                        v_strip = clamp(speed, v_min, v_cap_global)                          [INITIAL]
Curve      → Straight:  v_strip = clamp(speed, v_min, v_cap_global)
Warp       → Straight:  v_strip = clamp(warp_speed, v_min, v_cap_global)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Spawn speed | `speed` | px/s | 70–480 | Pattern speed (after Co-op / intensity scaling at spawn) |
| Accelerate cap | `v_cap` | px/s | 100–480 (330) | Bullet manager default |
| Warp speed | `warp_speed` | px/s | 100–480 (190) | Bullet manager default |
| Floors | `v_min`, `v_cap_global` | px/s | 70, 480 | Registry |

**Output Range:** 70 to 480 px/s. `V_EFF` keeps the average speed of the native bullet, so time on screen and bullet concurrency stay about equal (Boss power budget F3 uses `v_eff = (speed + v_cap)/2`).
**Example:** rice `speed` 70, `v_cap` 330 → `V_EFF` **200** px/s; `INITIAL` **70** px/s, which keeps the bullet on screen 200/70 = **2.86×** as long and raises concurrent bullets about 2.86× (the reason for the default). Warp native → Straight at **190**. Curve at speed 120 → **120**.

**F5. Brightness steps** *(`luma_step`)*

`step_delta = |level(i) − level(i−1)|` (overlay opacity, percentage points); the relative luminance change of the canvas is at most `step_delta` (an overlay of opacity `a` over a frame of luminance `L` against the Char overlay colour `C` changes by `Δa × (L − C)`, and `L − C ≤ 1`). Require `step_delta ≤ luma_step_max_pct` and no opposite-sign change ≥ 10 % within 60 ticks.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Dim levels | `dim_levels` | int[] % | 55 → [63, 70, 78, 85] | Held-frame warm overlay |
| Step cap | `luma_step_max_pct` | int % | 5–10 (10) | Per-step limit |
| Fade-in steps | `fadein_steps` | int | `ceil(85 / luma_step_max_pct)` = 9 | Parallax requirement |

**Output Range:** step deltas 7 to 8; fade-in 9 steps owned by Parallax (Rule 28a there): 85, 76, 66, 57, 47, 38, 28, 19, 9, 0, every 4 ticks = 36 ticks, inside the 120-tick lead-in (2026-11-03: Parallax's sequence replaces the earlier 85, 75 … 5, 0 / 8-tick draft).
**Example:** dim 55 → 63 (+8), → 70 (+7), → 78 (+8), → 85 (+7): all ≤ 10. Last dim step at tick 33; first fade-in step no earlier than tick 201 + 4 = 205 → gap 172 ticks > 60 (and ≥ 170). ✓

**F6. Not-a-reskin score** *(`reskin_count`)*

`reskin_count(n) = count of armed roles r where (family, behaviour, option)(r, n) == (family, behaviour, option)(r, n−1)`; require 0 for `COMPLETE` eras n > 0, and at least 1 signature role.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Armed roles | | int | 3 | fighter, gunner, heavy |
| Signature | `(family, behaviour, option)` | tuple | | From the role's emitters (largest emitter) |

**Output Range:** 0 to 3 (must be 0). **Example (1941 → 1970s):** fighter (aimed stream, Straight, none) → (aim-locked fan, Accelerate, aim_lock): differs; gunner (flak ring, Straight, flak_fuse) → (aim-locked 5-fan, Straight, aim_lock): differs; heavy (wall + fan, Straight, none) → (wall + aim-locked 7-fan, Straight, aim_lock): differs. `reskin_count` = **0**. A copy where the 1970s gunner keeps the flak ring would give 1 and fail.

## Edge Cases

**Loading and failure**
- **If the next era's env set is not ready at `era_hold_max`**, it loads synchronously at that tick under the card, `era_load_late` is logged, the logic ticks consumed by the hitch are dropped (no catch-up), and the hold releases.
- **If a required asset fails to load**, Era shift retries once; if it fails again it enters Failed, emits `era_failed`, releases the hold, and the run ends unranked with a bilingual "cannot load era" plate (release builds); debug asserts.
- **If a non-required asset is missing** (bezel, music set), the Plain bezel / silent music fallback is used and one warning is logged (Display edge case).
- **If threaded loading is unavailable on the platform**, the same polling loop runs and the load blocks at the first poll; the hitch is under the card.
- **If the run ends or is abandoned during Staging**, all staged resources are freed; no `era_ready`.
- **If `stage_cleared` arrives twice**, the second is ignored (Tally rule); Staging starts once.

**Timeline and input**
- **If the tally exits without a hold request** (same era, debug only), `era_ready` fires at once and no card shows.
- **If a fire press arrives before tick 75**, it is ignored.
- **If two slots press on the same tick**, one skip happens.
- **If a skip arrives before the swap commit**, the commit runs on that tick; the logic result is the same.
- **If the game is paused**, the transition clock, ticker and loading polls stop. A pad disconnect pauses it.
- **If `access.era_transition_short` is on and the env set loads late**, release waits for it (up to the cap); the shortened presentation holds its final frame.
- **If `reduce_flashing` is on**, no time-dust and no burst; the accent edge changes once at commit; dim steps unchanged.
- **If a Selecting slot picks a plane mid-transition**, its cell appears in the new look after commit, or immediately if commit has passed; no reveal.
- **If a slot goes Inactive mid-transition**, its cell dims to "OUT"; the layout does not change.
- **If every counted slot has dropped**, the transition still plays to release; the Tally decides Results versus next stage.
- **If a join hold (Selecting) follows the era hold**, the two run in sequence (Tally TF6); the new stage's era assets are already live.

**Swap and data**
- **If an enemy or bullet exists at the swap commit**, that is a bug: debug asserts; release despawns it with no credit (Enemy edge case: no era swap with live enemies).
- **If a role is missing from the target era's table**, E-V3 fails at build; at load in release the stage is refused and Failed is entered.
- **If a native pattern uses a behaviour above the ladder**, E-V4 fails; at runtime (release) the emitter is downgraded through the strip map to the nearest legal Straight pattern and a warning is logged.
- **If a native emitter uses the era's new tag without listing it**, E-V5 fails; the Director cannot strip it, so it would debut early.
- **If `strip_tags` names a tag the pattern does not use**, it is ignored.
- **If a stripped pattern's speed falls under `v_min` (70)**, it is clamped to 70.
- **If a debut wave is 4 and the Director passes `option:aim_lock`**, waves 1 to 3 natives have `lock_ticks` 0 (Director AC-23); Era shift only applies the map.
- **If two eras define the same `enemy_grammar`**, E-V1 fails.
- **If a stub era (`STATUS = STUB`) is requested in a release build**, the run is capped at the last `COMPLETE` era: the stage list is truncated and the last `COMPLETE` stage becomes the "ALL CLEAR" stage.
- **If a kit has no skin for an era in use**, E-V9 fails at build; at runtime the previous era's skin is used and a warning is logged.
- **If a bolt-on sprite is wider than the base envelope + 6 px**, E-V11 fails (art lint).

**Presentation**
- **If the language is Bengali**, the era name block uses the 34 px Bengali tier over the 24 px English line; the year digits use the digit atlas without grouping (Open Question 7); a language switch never moves a digit.
- **If the Display scale changes during the transition**, the card is in canvas space and scales with the canvas (Display); the bezel swap restarts toward the target era from the current step.
- **If the bezel asset for the new era is missing**, the Plain bezel is used (Display).

**Degenerate strategies and mitigations (Sirlin)**

| Risk | Why it matters | Mitigation |
|---|---|---|
| Skip-spam to dodge the transition | Not a gameplay exploit | Skip is allowed; logic is identical; only presentation changes |
| Hold-length exploit (a slow load stretches the hold) | Run time grows | Hold is capped at 240; `run_time` is not ranked; gameplay RNG is untouched |
| "Era power creep" via skins | Violates the anti-pillar | Numeric hash equality across eras (E-V9, AC-23) |
| A later era makes bullets harder to read | Breaks Readable Chaos | Constants guard E-V10; grayscale test; no era field for bullet style |
| Novelty leaks early | Players meet the trick unprepared | E-V4/E-V5/E-V7 plus Director F9 gate |

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Game events and session (1) | Hard | `run_started`, `stage_cleared`, `run_ended`, `stage_index`, pause, slot states; Era shift emits events through the bus | Yes |
| Stage-end tally (21) | Hard | `tally_exit`; `request_exit_hold` / `release_exit_hold`; `era_hold_max` | Yes |
| Wave and stage director (16) | Hard | `StageDef.era_id`, `stage_started`, Director F9 gating timing; waits for `era_ready` | Yes |
| Enemy and AI (10) | Hard | `EnemyDefinition` role tables; spawn params `strip_tags[]` | Yes |
| Boss power budget (15) | Hard | `novelty_debut_wave`; boss novelty tags; lint with the ladder | Yes |
| Bullet pattern library (9) | Hard | Patterns, `PatternMetrics`, V1 / V4 / A1 | Yes |
| Bullet manager (3) | Soft | V7 constants, `v_min`, `v_cap_global`, behaviours | Yes |
| Plane kits (11) | Hard | `EraKitSkin` contract, numbers for E-V9 | Yes |
| Bombs (12) | Soft | `EraBombSkin` contract | Yes |
| Player plane (5) | Soft | Bolt-on rules, `era_index` consumer | Yes |
| Boss and boss parts (14) | Soft | Boss per stage, boss atlas in the `core` set | Yes |
| Localization (27) | Soft | Era names; needs a year formatter | Yes |
| Save, settings (26) | Soft | `access.*` keys | Yes |
| Art bible | Soft | Palettes 4.5, bolt-ons 5.5, atlas and VRAM 8.x, flash rules | Yes (design/art) |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Enemy and AI (10) | Hard | Role table, `StripMap` | Yes |
| Wave and stage director (16) | Hard | `era_ready`, `StripMap`, `era_for_stage` | Yes |
| Boss power budget (15) | Hard | Ladder and tag set | Yes |
| Plane kits (11), Bombs (12), Player plane (5) | Soft | Skin selection by `era_index` | Yes |
| Display scaler and bezel (4) | Soft | `era_swap_committed`, `bezel_id` | Yes |
| HUD (20) | Soft | `ui_tint` | Yes |
| Stage-end tally (21) | Soft | Hold; reads `from_era` palette for its tint | Yes |
| Parallax (23), Audio (24), VFX (25) | Soft | `bg_set`, palette, fade-in, bank swap, particles | Yes ([Parallax](parallax-and-environment.md), [Audio](audio.md), [VFX](vfx-and-screen-feedback.md)) |
| Menus (22) | Soft | `palette(era_index)`; `era_ready` before run start | Yes ([Menus](menus-title-plane-select.md)) |
| Accessibility (28) | Soft | `access.era_transition_short` | Yes ([Accessibility](accessibility-options.md)) |
| Tutorial (30) | Soft | Era ladder knowledge for first-time hints (optional) | No |

**Amendments to other docs** (the main session applies them)

1. **Stage-end tally (21):** Core Rule 18 and Interactions "Era shift (19)": link this GDD; state the hold is requested on the tick `tally_exit` fires, the Tally's 45-tick fade runs inside the Dim phase, `from_era` / `to_era` are `era_id` values (`era_1941`), `to_era` is none on the final stage; the transition's pause behaviour follows Tally Rule 21. Dependencies row "Era shift (19)" gets "GDD exists".
2. **Wave and stage director (16):** (a) Rule 25 and State table: "Era shift loads next era's role table and look → `era_ready` → `load_stage`" becomes "Era shift stages the next era during the tally, commits the swap at tick 90 of the transition and emits `era_ready` at release, **before** Tally Done; Session sets `stage_index + 1`; the Director calls `load_stage` (requires `era_ready`)". (b) F9 / Rule 19: the stripped speed for Accelerate is `V_EFF` by default (see Conflicts); (c) Dependencies row "Era shift (19)": GDD exists, add `era_for_stage`, `StripMap`.
3. **Enemy and AI (10):** (a) Rule 3 and the novelty gating note (line 57): "Accelerate → Straight with the same initial speed" becomes "Accelerate → Straight at `v_strip` (Era shift F4; default average speed)"; the Era shift GDD owns the strip map. (b) Era shift row: link this GDD. (c) Open Question 12 (2030s / 2100 reactive AI): answered in part: stubs are scripted; Open Question 4 here covers shields and lasers.
4. **Boss power budget (15):** (a) `behaviour_ladder` knob (Gate): data home moves to `EraDef.new_behaviour` / `new_option`; `budget_rules.tres` reads `EraLadder`. (b) Add the option ladder (Rule 9 here) beside Rule 19: `flak_fuse` base, `aim_lock` era 2, `reaim_each_volley` era 3. (c) Interactions row "Era shift (19)": link this GDD. (d) AC-26 wording "Straight bullets" stays; add the `V_EFF` speed.
5. **Bullet pattern library (9):** (a) V4 table, 1941 row: Behaviours `Straight` (remove "some Curve"); (b) Open Question 6/7 (2030s lasers, 2100 rewind): point to this GDD's Open Questions 4 and 8; (c) Interactions row Era shift: link.
6. **Plane kits (11):** Rule 41 and Open Question 14: closed as "visual only" by this GDD; add `drone_sprites` per era to the skin list (V5); Dependencies row Era shift: GDD exists.
7. **Bombs (12):** Interactions and Dependencies "Era shift (19)": link this GDD; `EraBombSkin` is selected by `(bomb, era_index)` at the swap commit.
8. **Player plane (5):** V8 and AC-36: add "bolt-on and palette LUT selected by `era_index` at `era_swap_committed`"; list `EraDef.bolt_ons` as the data home.
9. **Display scaler and bezel (4):** Rule 12 (and the Interactions table, Core Rule row `stage_started` with a new era): the bezel swap trigger is `era_swap_committed(era_index)` (visible behind the era card); `stage_started` stays as a fallback if the swap has not run. Add Era shift (19) to Dependencies.
10. **HUD (20):** Rule 33: `HudTheme` era tint is set on `era_swap_committed` (and on `stage_started` as a fallback); add Era shift to Dependencies with `ui_tint`.
11. **Game events and session (1):** add events `era_swap_committed(era_index)`, `era_ready(era_id)` (already in the Director list), `era_load_late(era_id, ticks)`, `era_failed(era_id)`; Session ends a run unranked on `era_failed`; Session waits for `era_ready` before `run_started` completes and before `stage_index + 1` is used; Dependencies row for Era shift: link. Dropped logic ticks after a blocking load (Rule 23): add "→ ADR: blocking load discards accumulated ticks".
12. **Localization (27):** add a no-grouping number formatter (`format_plain(n)` or a `year` helper using the digit atlas) and the keys `era.name.1941`, `era.name.1970s`, `era.name.2030s`, `era.name.2100` (bilingual), `era.card.skip` (single-language prompt), `era.error.load` (bilingual).
13. **Save (26):** register `access.era_transition_short` (bool, default false) beside `access.reduce_flashing`.
14. **Registry:** add the candidates in the report; add `era-shift-and-plane-evolution` to `referenced_by` of `hit_radius_orb`, `hit_radius_rice`, `hit_radius_needle`, `hit_radius_ring`, `v_min`, `v_cap_global`, `setting_access_reduce_flashing`, `max_drones`.
15. **Game concept:** §3 line 48 "The player's plane evolves (look, shot, ability visuals/power)": add "(look and ability visuals only; all numbers are identical in every era)". §10 line 159 note: implemented by Boss power budget (15) and Era shift (19).
16. **Art bible:** 8.x loading note: "the next era loads only after the boss dies" is implemented as staged loading (Rule 20); 5.5: 1941 hardware is part of the base art, the first bolt-on set is 1970s (Rule 7).
17. **Systems index:** row 19 status `**Designed** (pending review) — [GDD](era-shift-and-plane-evolution.md)`; Depends on `9, 11, 16` becomes `1, 3, 9, 10, 11, 12, 15, 16, 21`; progress tracker +1 GDD.

## Tuning Knobs

**Owned by this system** (`data/eras/transition_rules.tres`, `data/eras/era_*.tres`, `data/eras/strip_map.tres`)

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `dim_levels` | 55 → [63, 70, 78, 85] | steps ≤ 10; end ≤ 90 | Frame barely dims; the card floats | Black screen feel; step > 10 breaks F5 | `luma_step_max_pct`, Tally overlay (55) |
| `dim_step_ticks` | 11 | 8–20 | Steps blur together | Dim drags | Tally `exit_ticks` 45 |
| `card_in_ticks` | 8 (4 steps x 2) | 6–12 | Pop-in | Slow | Art bible 7.7 (panel 8 frames) |
| `year_ticks` | 60 (24 in short mode) | 24–90 | Ticker unreadable | Hold grows | F1, F2 |
| `swap_tick` | 90 | 60–120 (≥ ticker start, ≤ `reveal_start`) | Swap before the card is solid | Swap after the reveal starts | `reveal_start`, Rule 22 |
| `accent_step_ticks` | 21 | 15–30 | Edge steps flicker (> 3 Hz) | Slow | Art bible 7.7 pulse rule |
| `reveal_start` | 129 | 100–160 | Name not read | Hold grows | F1 |
| `old_hold` | 12 | 6–24 | The old look is missed | Dead time | F1 |
| `swap_ticks` | 8 | 4–16 | Bolt-on pops | Slow | F1 |
| `new_hold` | 52 | 24–90 | New look not read | Hold grows | F1 |
| `era_skip_lockout` | 75 | 30–120 | Mash skips the card | Impatient wait | Tally `skip_lockout` 90 |
| `skip_tail_ticks` | 12 | 6–30 | Hard cut | Slow | F1 |
| `short_release` | 96 | 60–120 | Cuts the swap | Not short | `year_ticks` short |
| `luma_step_max_pct` | 10 | 5–10 | More steps, slower | Flash risk | F5 |
| `poll_ticks` | 6 | 1–30 | Per-tick polling cost | Late ready detect | Perf AC |
| `env_preload_early` | false | bool | Peak 74 MB | Peak 110 MB | F3, platform |
| `strip_speed_mode` | `V_EFF` | `V_EFF` / `INITIAL` | Same as high | `INITIAL`: 2.86x concurrency for the Jet rice | Director F3 density, F4 |
| `dust_count` | 40 | 0–60 | Plain | Competes with text | VFX 150 cap |
| `reveal_burst_particles` | 24 | 0–40 | Plain | Heavy | VFX 150 cap |
| `ttk_mult_x100` per era | 100 / 125 / 150 / 175 | 100–200 | History Accelerates flat | Later eras grind | Enemy hp |
| Ladder (`new_behaviour`, `new_option`) | See Rules 8, 9 | Fixed by concept | | | Boss power budget |

**Owned elsewhere:** `era_hold_max` 240, `skip_lockout` 90, `exit_ticks` 45 → Stage-end tally (21) · `lead_in_ticks` 120 → Wave director (16) · kit and bomb numbers → Kits (11), Bombs (12) · bullet radii, `v_min`, `v_cap_global` → Bullet manager (3), registry · `bezel_era_swap_frames` 8 → Display (4) · `access.reduce_flashing` → Accessibility (28) / Save (26).

**Rationale:** the transition is 3.35 s so it feels like a beat between stages, not a break; the timeline is tied to the art bible's 7.7 rules (stepped easing, panel 8 frames, pulse at most 2 Hz) and keeps 39 ticks of slack under the Tally's cap so a slow load does not cut the presentation.

## Visual/Audio Requirements

Sizes in px at 1x on the 360x640 canvas. Draw layer **11 (UI)**; world effects stay below enemy bullets (layer 8). Mood: art bible 2, "tally" calm with a sense of passage. Never Void Indigo or Ink; never a reserved bullet shape (orb, rice, needle, ring); no flashes.

**Era card**

| Element | Spec |
|---|---|
| Plate | 320 x 360 at (20, 140); Cabinet Char `#1E1B18`, 1 px `#5A5148` edge, 1 px inner edge in the era Accent (steps old → new, F1) |
| Year ticker | Digit atlas, 24 px Latin / 34 px Bengali tier, Cream `#F4EBD6`, 1 px `#14110E` outline; old year dim 12 px to the left with an arrow tile; no digit grouping |
| Era name | Bengali over English (Localization Rule 19); XL tier; Cream; steps in over 4 ticks |
| Plane cells | 1P 120x120, 2P 2 x 120x120, 3-4P 4 x 72x72; Char fill; slot tag 14x14 with P-colour edge; plane at 1x (integer scale only), bolt-on slides in 4 steps of 2 ticks |
| Prompt | S tier, chosen language only, bottom of the plate, shows the fire key after tick 75 |

**Colours by era** (art bible 4.5 Accent, 20 % tint; frame edge only): 1941 `#8A6F4A`, 1970s `#A85A22`, 2030s `#2A8A90`, 2100 `#A8348F`. Bezel luma limits: Display Rule 11.

**Motion**

| Event | Visual | Ticks |
|---|---|---|
| Dim | Warm overlay steps 55 → 85 % (F5) | 0 to 33 |
| Time-dust | Up to 40 clusters of 2x2 / 3x3 px in the old era Shadow → new Accent, drifting up 1 to 3 px/tick behind the plate | from 12 to 128 |
| Card in | Slides in over 4 stepped positions | 45 to 52 |
| Ticker | Digits change per F2; one quiet tick per 4 shown steps (max 10) | 53 to 112 |
| Name | Plate steps in | 113 to 116 |
| Reveal | Old bolt-on out, new in; 24 accent particles (2+ px clusters, not single pixels); the base airframe never moves | 141 to 147 |
| Release | Card fades out in 8 ticks; Parallax fades the new stage in (F5) | 201 to 209 |

**Per-era assets (palette swaps and bolt-ons, not redraws; concept risk "art volume")**

| Asset | MVP (1941 + 1970s) | Target (all 4) | Method |
|---|---|---|---|
| Plane bases | 2 (Lancer, Leech) | 4 | Authored once in the 1941 palette, LUT-mapped per era |
| Bolt-on sets (max 2 sprites each) | 2 sets (1970s, one per plane) = at most 4 sprites | 12 sets (4 planes x 3 post-1941 eras) | New sprites |
| Drone sprites | 2 kits x 2 eras = 4 | 8 (2 kits) / 16 (4 kits) | New sprites, 16x10 base size |
| Enemies and bosses | 4 + 4 role sprites; 2 bosses | +8; +2 bosses | New sprites (enemy grammar differs, art bible 3.2) |
| Environment | 2 sets | 4 | New tiles, palette-swappable props |
| Bezel art | 2 | 4 | Tiled plates, era tint |
| Effects, explosions, smoke, debris | Palette recolour | Palette recolour | LUT |

Per-era set size: `core` about 20 MB + `env` about 36 MB (art bible 8.x). 📌 **Asset Spec** — run `/asset-spec system:era-shift` to produce per-sprite specs (card plate, time-dust, bolt-ons per era).

**Audio** (UI bus, Audio 24; never competes with the 8-voice bullet pool). Cues requested: `era_dim` (soft low sustained note, fades in over 33 ticks), `era_tick` (quiet tick per 4 ticker steps), `era_commit` (a 1-second sting in the **new** era's timbre, at tick 90), `era_reveal` (a soft clunk at tick 147, pitched to the era), `era_release` (settle). Peak level at least 6 dB below the tally's `tally_hero_end`; no sudden transient, no panning sweeps. Timbres (Pattern library A1): 1941 mechanical, brassy; 1970s radar beeps and analogue sweeps; 2030s digital synth; 2100 reversed or warped. Music: the tally loop fades out during Dim; the new era's stage music starts at the Director's `STAGE_START` cue. Volley, hit and pickup cue **meaning** and timing never change with era.

**Localisation keys:** `era.name.1941`, `era.name.1970s`, `era.name.2030s`, `era.name.2100` (bilingual), `era.card.skip` (prompt), `era.error.load` (bilingual).

> Decided under auto-approve (2026-11-03): a calm card instead of a cutscene; year ticker, bezel swap and plane reveal as the three beats; time-dust (clusters, not lines, to avoid needle shapes); accent steps at 21 ticks; no screen flash; one burst of 24 particles only.

## UI Requirements

One player-facing screen: the **era card** (a full-canvas overlay inside the Tally exit hold). No menu, no HUD element, no new settings screen entry other than the `access.era_transition_short` toggle (Accessibility 28 registry).

| Need | Spec |
|---|---|
| Inputs | `pN_fire` press edge skips after tick 75; `start` / `back` pause; keyboard only or gamepad only; no mouse |
| Readability | Min 12 px Latin / 17 px Bengali; 1 px outline; Bengali width +40 %; year digits on a fixed grid |
| Accessibility | Nothing relies on colour alone (year and era name text; slot numbers); no flashing; short mode and reduce-flashing (Rules 26, 27); skippable; not time-gated for gameplay |
| Scale | Pre-fit for 360x640; scales with the Display scaler; safe at all supported scales |
| Debug | Dev overlay: state, `t` since T0, `env_ready_tick`, load status per set, VRAM estimate, `release_tick`, last `late_load`; "force skip" key; "jump to era N" stage select (marks the run `debug_tainted`) |

📌 **UX Flag**: run /ux-design for the Era card (plane cells for 1P / 2P / 4P, skip prompt, short mode) before writing epics. Stories cite `design/ux/era-card.md`, not this GDD.

## Acceptance Criteria

Defaults used: `dim_levels` [63, 70, 78, 85] at ticks 0 / 11 / 22 / 33, `card_in_ticks` 8, `year_ticks` 60, `swap_tick` 90, `accent_step_ticks` 21, `reveal_start` 129, `old_hold` 12, `swap_ticks` 8, `new_hold` 52, release 201, `era_skip_lockout` 75, `skip_tail_ticks` 12, `short_release` 96, `era_hold_max` 240, `luma_step_max_pct` 10, `poll_ticks` 6, `strip_speed_mode` `V_EFF`, Bullet manager `v_min` 70, `v_cap_global` 480, Accelerate `v_cap` 330, `warp_speed` 190; art bible memory A 18 / `S_core` 20 / `S_env` 36 MB; 60 ticks/s.

**Test setup:** `EraShift` is a plain `RefCounted` class with no nodes and no `delta`; `tick()` advances one step and keeps its own counter. Inputs: `begin_run(first_era)`, `on_stage_cleared(stage_index)`, `on_tally_exit(stage_index, from, to)`, `press(slot)`, `set_slot_state(slot, state)`, `set_paused(bool)`, `set_env_ready_tick(t)` (a fake loader reporting readiness at a chosen tick), `set_settings(reduce_flashing, short)`. Stubs: a `FakeTally` that records `request_exit_hold` / `release_exit_hold` with ticks; a `FakeLoader` with per-set load times and a memory ledger; recorders for Enemy (role table swap), Kits / Bombs (skin selection), Display, Audio, HUD events and the Session bus. Outputs: event log with ticks, current era, timeline `phase(t)`, `state_hash()`. Data tests read `data/eras/*.tres`, `data/enemies/<era>/roles.tres`, `data/kits/skins/*.tres`, `data/bombs/skins/*.tres`, `data/bosses/*.tres`; quoted numbers derive from the defaults, never literals in code. Tests (`extends SceneTree`, like `tests/unit/test_chain_tracker.gd`): `tests/unit/test_era_data.gd`, `tests/unit/test_era_ladder.gd`, `tests/unit/test_era_strip.gd`, `tests/unit/test_era_timeline.gd`, `tests/unit/test_era_skins.gd`, `tests/unit/test_era_memory.gd`, `tests/integration/test_era_flow.gd`, `tests/perf/era_bench.tscn`; manual evidence in `production/qa/evidence/era-shift/`. Names: `test_era_[scenario]_[result]`.

Tags: [Unit] pure logic, headless · [Integration] real Tally / Director / Enemy / Session · [Manual] needs a human · [Perf] REF-WEB.

### Data and validation (Rules 1-5, 14, 15, E-V1 to E-V13)

- **AC-01 [Unit] (E-V1):** the four `EraDef`s load with `index` 0 to 3 in order, ids `era_1941`, `era_1970s`, `era_2030s`, `era_2100`; eras 0 and 1 are `COMPLETE`, 2 and 3 `STUB`; `enemy_grammar` values are ROUND, ANGULAR, HEX, FRACTURED (all different). A copy with two equal grammars fails.
- **AC-02 [Unit] (Rule 4, E-V3):** each `COMPLETE` era's `roles.tres` maps exactly `fodder`, `fighter`, `gunner`, `heavy`; sizes SMALL, SMALL, MEDIUM, LARGE; 1941 hp 20 / 40 / 1,200 / 4,000 and 1970s hp 20 / 50 / 1,500 / 5,000 (read from the files; they equal Enemy 3). A copy missing `gunner` fails E-V3.
- **AC-03 [Unit] (Rule 5, E-V10):** the `EraDef` schema contains no field named or typed for bullet shape, colour, outline or hit radius; a copy that adds `bullet_colour` fails the schema lint.
- **AC-04 [Unit] (Rule 15, E-V10):** for every emitter in every `COMPLETE` role table and boss, shape ∈ {orb, rice, needle, ring} and radii equal 2.5 / 1.5 / 1.25 / 2.0 from the registry; an emitter with shape `star` fails.
- **AC-05 [Unit] (Rule 2):** `palette(0..3)` returns four distinct LUT ids with no staging done; the player-atlas material count per era equals 1.
- **AC-06 [Unit] (E-V11):** every id in `EraDef` (palette, bezel, bg set, music set, sfx bank, bolt-on sprites) resolves; a missing bezel id fails the build.

### Ladder and novelty (Rules 8-14)

- **AC-07 [Unit] (Rule 8, E-V2):** `allowed_behaviours` = {Straight} / {Straight, Accelerate} / {Straight, Accelerate, Curve} / {Straight, Accelerate, Curve, Warp} for eras 0 to 3; the 1941 `EraDef.new_behaviour` is `NONE`; a copy with two new behaviours in one era fails.
- **AC-08 [Unit] (Rule 9, E-V2):** allowed options = {flak_fuse} / +aim_lock / +reaim_each_volley / unchanged; a copy with two new options in era 1 fails.
- **AC-09 [Unit] (Rule 8, E-V4):** the 1941 role table has no Accelerate, Curve or Warp emitter; a 1941 copy with a Curve emitter fails E-V4 (Pattern library V4 conflict resolved).
- **AC-10 [Unit] (Rules 10, 11, E-V5):** the Delta jet and Radar gunner and Missile carrier emitters that use Accelerate or aim lock list `behaviour:accelerate` / `option:aim_lock` in `novelty_tags`; a copy with a tagged emitter missing its tag fails E-V5; a 1970s emitter carrying `behaviour:curve` fails.
- **AC-11 [Unit] (E-V8):** the Fortress novelty tag set is empty and the 1941 era tag set is empty; the Jet tag set is {`behaviour:accelerate`, `option:aim_lock`} and equals the 1970s era tag set. A Jet copy with an extra `option:reaim_each_volley` fails.
- **AC-12 [Unit] (Rule 14, F6, E-V6):** `reskin_count(1)` = 0 for the 1941 → 1970s tables; fighter, gunner, heavy signatures all differ; the signature role is the `fighter`. A 1970s copy whose `gunner` keeps the flak ring gives 1 and fails; a copy with equal `enemy_grammar` fails.
- **AC-13 [Unit] (Rule 12, F4, `aim_lock`):** `StripMap.apply` on the Radar gunner's 5-fan with `option:aim_lock` → `lock_ticks` 0; count 5, interval, shape and colour unchanged.
- **AC-14 [Unit] (F4, Accelerate, V_EFF):** a rice pattern with `speed` 70, `v_cap` 330 stripped of `behaviour:accelerate` → Straight at **200** px/s; with `strip_speed_mode` `INITIAL` → **70**. With `speed` 480, `v_cap` 480 → 480 (clamp).
- **AC-15 [Unit] (F4, Curve, Warp):** Curve pattern `speed` 120 → Straight at 120; Warp pattern → Straight at 190; both never freeze or re-aim. A stripped speed of 60 is clamped to 70.
- **AC-16 [Unit] (E-V7):** every tagged native pattern in the 1970s table, stripped, has only behaviours ∈ {Straight}, options ∈ {flak_fuse}, the same count / interval / arms, and passes the lane (`lane_min_clear` 14) check; the density estimate used by the Director is `max(native, stripped)`.
- **AC-17 [Unit] (Rule 12, preview):** a pattern marked as a preview is not modified by `apply` even when `strip_tags` contains its tag.
- **AC-18 [Integration] (Rules 11-13, Director F9):** Stage 2 in the fake spawn log: a Delta jet spawned at wave 1 tick 200 has `strip_tags` containing `behaviour:accelerate` and fires Straight at `V_EFF`; at tick 240 it does not; waves 1 to 3 natives have `lock_ticks` 0; a wave 4 native at tick 380 is stripped, at 400 it is not; Stage 1 strips nothing.

### Skins and plane evolution (Rules 6, 7, E-V9)

- **AC-19 [Unit] (Rule 6, Kits AC-35):** for Lancer and Leech and each `COMPLETE` era, the hash of all numeric `EraKitSkin` fields is equal across eras; the kit data hash is equal; skins differ only in sprite ids, sound ids and muzzle offsets within +/-4 px. A copy with a muzzle offset of 5 px fails.
- **AC-20 [Unit] (Rule 6, Bombs AC-44):** the `EraBombSkin` numeric hash is equal across eras for both bombs; only sprite ids, sound ids and a warm tint differ.
- **AC-21 [Unit] (Rule 7):** each plane has at most 2 bolt-on sprites per era; each bolt-on bounding box is within the base envelope + 6 px and more than 8 px from the hitbox centre (data lint); 1941 has no bolt-on entries (hardware is base art).
- **AC-22 [Integration] (Rule 22):** at the swap commit, the Lancer and Leech skins and bomb skins switch to the 1970s entries in the same tick; the next frame's kit data hash equals the previous era's.
- **AC-23 [Unit] (anti-pillar):** the registry values `player_shot_damage` 20, `laser_damage`, `lancer_ability_speed` 90, `max_drones` 4 read the same through the 1941 and 1970s kit data; the test fails if any per-era override exists.
- **AC-24 [Manual] (Player plane AC-36):** ≥ 5 testers name Lancer and Leech correctly in ≥ 90 % of shuffled 1x screenshots of 1941 and 1970s skins; the same bar for 2030s and 2100 art when it exists.

### Transition timeline (Rules 16-19, 22, 23, 25-28; F1, F2, F5)

- **AC-25 [Unit] (Rule 18):** `on_tally_exit(0, era_1941, era_1970s)` produces `request_exit_hold("era_shift")` on the same tick (T0); with `from == to` it produces no request and `era_ready` at once.
- **AC-26 [Unit] (Rule 19, F1):** with the loader ready at tick 0, the event log shows: dim overlay 63 / 70 / 78 / 85 at ticks 0 / 11 / 22 / 33; card in at 45 / 47 / 49 / 51; old env freed at tick 53; swap commit and `era_swap_committed(1)` at tick **90**; bolt-on swap steps at 141 / 143 / 145 / 147; burst at 147; `release_exit_hold` and `era_ready(era_1970s)` at tick **201**.
- **AC-27 [Unit] (F1):** release ticks for env-ready ticks 150 / 230 / 300 are **201 / 230 / 240**; at 300 `late_load` is true, one `era_load_late` is logged and a synchronous load is requested at tick 240.
- **AC-28 [Unit] (F2):** the ticker shows 1941 at k = 0, 1948 at k = 15, 1956 at k = 30, 1963 at k = 45, 1970 at k = 60 for W = 60; 2065 at k = 30 for 2030 → 2100; never decreases; ends exactly on the target.
- **AC-29 [Unit] (Rule 25):** a press at tick 74 is ignored; at tick 100 with env ready at 150 → release 150; at tick 80 with swap not yet committed → commit on tick 80; two presses on one tick cause one skip; logic hashes after release are equal with and without skip.
- **AC-30 [Unit] (Rule 26):** short mode: commit at tick 62, release at tick **96** with env ready at 70; with env ready at 120 → 120.
- **AC-31 [Unit] (Rule 27):** with `reduce_flashing`, no dust or burst events are logged and the accent edge changes once at commit; dim levels are unchanged.
- **AC-32 [Unit] (Rule 28, F5):** every consecutive pair of `dim_levels` (55, 63, 70, 78, 85) differs by ≤ 10; the fade-in sequence (85 → 0, step ≤ 10) has 9 steps of ≤ 10; the gap between the last dim step and the first fade-in step ≥ 60 ticks (here ≥ 170). A copy with a step of 12 fails E-V12.
- **AC-33 [Unit] (Rule 30):** while paused for 100 ticks, `t` and the ticker do not advance, and no load poll runs; resuming continues at the same phase.
- **AC-34 [Integration] (Rule 23, Director):** order on the fake bus: `stage_cleared`, `tally_exit`, `era_swap_committed`, `era_ready`, Tally Done, `stage_started(1, era_1970s)`; the Director's `load_stage` is refused if `era_ready` has not fired and called exactly once after it.
- **AC-35 [Integration] (Rules 16, 29):** `run_started` loads era 0 with no card and emits `era_ready(era_1941)` once both sets are ready; the final stage's `stage_cleared` stages nothing, no hold is requested, and `run_ended` returns the state to Inactive with the sets freed.

### Loading and memory (Rules 17, 20; F3)

- **AC-36 [Unit] (F3):** the fake memory ledger over a full 1941 → 1970s change peaks at **74 MB** with `env_preload_early` false and **110 MB** with it true; both stay below 128 MB; the staged peak stays below 96 MB.
- **AC-37 [Unit] (Rule 17, edge):** the old `core` set is freed at `stage_cleared`; the old `env` set is freed at tick 53 and not earlier; abandoning the run during Staging frees the staged set and emits no `era_ready`.
- **AC-38 [Unit] (edge):** a required asset that fails twice enters Failed, emits `era_failed`, releases the hold, and ends in Inactive; a missing bezel falls back to Plain with one warning.
- **AC-39 [Perf] (Rule 20, tick budget):** `EraShift.tick()` averages ≤ 0.02 ms and p99 ≤ 0.05 ms over a full transition (216 ticks) on REF-PC; allocation delta per tick over 1,000 ticks is 0; poll cost with `poll_ticks` 6 is ≤ 0.1 ms per poll.
- **AC-40 [Perf] (REF-WEB, Manual evidence):** the full transition on the Web export holds ≥ 55 fps for 95 % of frames; no frame over 50 ms unless `late_load` (then at most one, hidden under the card).

### Determinism and presentation

- **AC-41 [Unit] (E-V13):** two runs of the same tick-and-input script (including a skip at tick 100) produce equal `state_hash()` at tick 201 and equal event logs; the source contains no `randf`, `randi` or `delta`.
- **AC-42 [Unit] (determinism of logic vs load time):** with `env_ready_tick` 150 vs 230, the post-release `state_hash()` (current era, tables, skins) is identical; only the release tick differs.
- **AC-43 [Manual] (no flashes):** frame-capture the full transition (full, short, reduce-flashing) in 1941 → 1970s; the mean-luma step between consecutive displayed changes ≤ 10 % and no opposite-direction change ≥ 10 % within 1 s; reviewed against the Harding / WCAG three-flash rule with no failures. Evidence in `production/qa/evidence/era-shift/`.
- **AC-44 [Manual] (card legibility):** the card in Bengali and English shows the year and the era name with conjuncts legible at 1x in 1P, 2P and 4P, and the year digits have no grouping separators.
- **AC-45 [Manual] (bullet language, concept test):** ≥ 8 of 10 testers who play stages 1 and 2 can name at least one bullet-behaviour difference (e.g. "rice speeds up", "fans lock on") without being told, and ≥ 8 of 10 say stage 2 enemies "are not recoloured stage 1 enemies".
- **AC-46 [Manual] (power parity):** with kit data hashes equal, testers with equal skill clear stage 2 with Lancer at a reference time within 15 % of the time predicted from the unchanged `ref_dps`; no tester reports "my plane got stronger/weaker".
- **AC-47 [Manual] (feel):** ≥ 8 of 10 testers rate the jump "short enough" and "felt like a step in time" (4 of 5 on both); the skip is found by ≥ 6 of 10 without a prompt after the first viewing.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Confirm the option ladder for eras 3 and 4 (`reaim_each_volley` in 2030s; none in 2100) once those bosses exist. Boss power budget Open Question 9 asks whether one aim option beside the one new behaviour is allowed. | Creative director / Boss budget | Target milestone |
| 2 | Is `ResourceLoader.load_threaded_request` reliable and non-blocking on the Godot 4.7 Web export (single-thread default)? If not, the 2.4 s env window may be a blocking load. Unverified; check the 4.7 docs and a Web test. | Lead programmer | Before the Vertical Slice |
| 3 | The Director's density check (F3) must use `max(N_def(native), N_def(stripped))`; confirm F3 and the `INITIAL` vs `V_EFF` default (conflict with Enemy / Director wording). | Level designer / Systems designer | Director review |
| 4 | 2030s "lasers" and "energy shields": lasers are not bullets (Pattern library Open Question 6). Does the stub heavy keep a plating timing window only, or does a laser enemy type need a Bullet manager amendment? | Systems designer | Target milestone |
| 5 | The 2100 `gunner` has no ground (art bible 6.2). Confirm "floating GROUND shard that drifts with the background". | Level designer / Art director | Target milestone |
| 6 | Failure policy: release behaviour on `era_failed` (end the run unranked) vs offering a retry. | Producer / Lead programmer | Before release |
| 7 | Year formatter: add `format_plain` to Localization or reuse the digit atlas without grouping. | Localization owner | Localization review |
| 8 | 2100 "rewinding" bullets are not a Bullet manager behaviour (Pattern library Open Question 7); Warp covers MVP. Revisit when 2100 is built. | Bullet manager owner | Target milestone |
| 9 | Should the plane reveal also show the drones (max 4) on the card, or only the plane? Showing drones adds art cost (drone sprite per era). | Art director | Asset spec |
| 10 | Blocking loads drop accumulated logic ticks: needs an ADR or a Session rule so a late load never causes a catch-up burst. | Technical director | Before Vertical Slice |
| 11 | Should the era card replace the "ALL CLEAR" prompt on the final stage with an "ending" beat (a final year jump to 2100+), or stay silent? | Creative director | Target milestone |
| 12 | Concept §3 says "look, shot, ability visuals/power"; this GDD fixes "visuals only". Confirm with the creative director (also Plane kits Open Question 14). | Creative director | Concept review |
