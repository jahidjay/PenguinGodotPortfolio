# Enemy and AI (small / medium / large)

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts, Readable Chaos, History Accelerates

## Overview

**The data layer:** an **enemy** is a pooled, node-free record built from a read-only **enemy definition** (`data/enemies/*.tres`). The definition holds a size class (**SMALL / MEDIUM / LARGE**), integer hp, a body shape (a capsule, as Collision (6) expects), a score class, and a **path** that says where it flies, all in integer ticks. It also holds a list of **emitters**, each with a muzzle offset and a list of Pattern library (9) patterns. Each tick the Enemy manager moves every enemy by evaluating its path at its integer age, publishes hurtboxes to the Bullet manager (3) and bodies to Collision (6), keeps each emitter's origin and intensity current, and arms or retires emitters by a fixed fire-zone rule. When Collision reports *destroyed*, the manager stops the enemy's emitters, fires the death events (explosion, drop request, optional bullet cancel) and recycles the slot. Enemies are **scripted, not reactive**: the only reaction to players is an optional turn-to-face. Waves (Wave director 16) spawn enemies by **role** (`fodder`, `fighter`, `gunner`, `heavy`); Era shift (19) maps each role to that era's definition.

**The player impact:** enemies are the stage's "sentences": the things the player chains through between boss fights. Small enemies are chain fodder that keep the window alive. Medium and large enemies are **chain bridges**: they take long enough to kill that the player holds the chain on them while dodging what they fire. Because every enemy flies a fixed route and fires fixed patterns, a squadron the player died to on attempt one can be swept cleanly on attempt three. Each era's enemies are drawn and armed differently (propeller fighters and flak in 1941, delta jets and radar locks in the 1970s), so the era jump is felt in the first wave (**History Accelerates**).

## Player Fantasy

**Anchor moment: sweeping the squadron.** Five fighters peel in from the left on one curve. The player slides under the leader, holds fire, and the stream walks down the V: five pops in one second, the chain going 31, 32, 33... Then the bomber's hatch swings open, the wall of bullets starts to roll, and the player is already in the gap, hitting it point-blank because that is where the chain lives.

- **Scripted so it can be learned.** Every enemy flies the same route and fires the same patterns every run. "Fighters come from the left after the first bomber" is knowledge the player owns, and a chain route is built from it (**Every Hit Counts**).
- **Targets that bridge the chain.** Small enemies are fast, cheap hits. Medium and large enemies stay on screen long enough to keep a 1 s chain window alive, and every hit on them counts, even the ones that bounce off armour.
- **Fair by construction.** Enemies never spawn on a player, never fire from off-screen, and only their visible core is deadly. A medium or large enemy telegraphs before it fires (**Readable Chaos**).
- **Killing the source feels like relief.** Killing a gunner or bomber clears a pocket of its own bullets and turns them into score items. Small fighters just die.
- **Each era is a new opponent.** Round, riveted 1941 fighters and flak versus angular 1970s jets and radar locks: new shapes and new patterns, not recolours.

**Anti-fantasy (must never happen):** an enemy appearing on top of the player, a bullet from an enemy the player cannot see, an enemy that dodges or hides so the chain drops, a route that changes depending on where the player stands, or an enemy that lingers for a minute because nobody could reach it.

Reference feel: 1941 and DoDonPachi waves: fixed formations, popcorn that flows into mid-size "gunship" moments.

> `creative-director` not consulted (lean mode).

## Detailed Design

### Core Rules

**Classes and data**

1. Every enemy is an instance of an **`EnemyDefinition`** resource (`data/enemies/<era>/<id>.tres`). Fields: `id`, `size_class` (SMALL / MEDIUM / LARGE), `kill_class` (default = size class), `hp_base`, `body` (`r_e`, `spine_half` = half spine length in px, `lethal`), `hurtbox_count`, `path` (an `EnemyPathDef`), `facing_mode`, `turn_rate`, `plating_ticks` and `plating_armor_pct` (0 = no plating), `emitters[]`, `cancel_radius`, `max_life_ticks`, `layer` (AIR / GROUND), `fire_during_exit`.
2. **Class table (MVP defaults):**

| Class | Sprite (AB 5.7) | Body | Hurtboxes | hp rule | Kill value | Kill cancel | Armour use |
|---|---|---|---|---|---|---|---|
| **SMALL** | 18–27 px | circle, `r_e` 7–9 | 1 | 1–3 reference hits (hp 20–60) | 200 | none | none |
| **MEDIUM** | 36–60 px | capsule, `r_e` 12, spine ±8 | 2 | about 1.5 s of reference fire (hp 1,200–1,500) | 1,000 | 40 px | none (data field exists) |
| **LARGE** | 72–120 px | capsule, `r_e` 18, spine ±30 | 3 | about 5 s of reference fire (hp 4,000–5,000) | 5,000 | 72 px | **plating**: armoured for the first 120 ticks on screen (Rule 12) |

   Kill values are the registered `kill_values` (Scoring F2); this system never defines them.
3. **Roles and eras.** Waves refer to enemies by **role**, not id. MVP roles: `fodder` (SMALL, unarmed), `fighter` (SMALL, armed), `gunner` (MEDIUM, ground), `heavy` (LARGE, air). Each era has a role table (`data/enemies/<era>/roles.tres`) mapping role → definition. Era shift (19) loads the table at stage start. The shapes, patterns and bullet behaviours differ per era (MVP table below); the role slots stay the same.

| Role | 1941 (stage 1) | 1970s (stage 2) |
|---|---|---|
| `fodder` | **Scout** (unarmed, hp 20) | **Dart jet** (unarmed, hp 20) |
| `fighter` | **Prop fighter**: aimed 3-round stream, orbs (hp 40) | **Delta jet**: aim-locked fan, accelerating rice (hp 50) |
| `gunner` | **Flak gunner** (ground): flak ring (hp 1,200) | **Radar gunner** (ground): aim-locked 5-fan (hp 1,500) |
| `heavy` | **Heavy bomber**: wall + tail fan (hp 4,000) | **Missile carrier**: wall + aim-locked 7-fan (hp 5,000) |

   Pattern parameters for these are in the Formulas section (F9). They are authored against the Pattern library validator and are provisional until it runs on real data.

   **Novelty gating (Boss power budget (15), amended 2026-11-03):** a role definition may carry `novelty_tags`. Before a novelty's debut wave the Wave director strips it from native patterns: aim lock → `lock_ticks` 0, Accelerate → Straight at `v_strip` (Era shift (19) F4; default `V_EFF`, the average speed `(speed + v_cap) / 2`, switch `strip_speed_mode`; the Era shift GDD owns the strip map) *(2026-11-03, wave 3b)*. The 1970s `fighter` (aim-locked fan + accelerating rice) is the MVP case; it fires the stripped versions until the debut waves of those mechanics. Needs Enemy/Era shift (19) sign-off.

**Why scripted, not reactive (the "AI")**

4. Enemy "AI" is a **timeline of authored behaviour**: a path, a facing rule, an emitter list. It never reads player positions to decide *where to go*, *when to fire* or *whether to retreat*. Reasons:
   - **Learnable** (Readable Chaos): the pattern library's fantasy is "the same inputs give the same volley". Reactive movement would make every run different, and the player could not memorise a route.
   - **Chain planning** (Every Hit Counts): players plan where to be when the next squadron arrives. A reactive enemy that dodges away would drop chains for reasons the player cannot read.
   - **Co-op**: with 1–4 players there is no single "the player" to react to. Anything reactive needs a targeting rule and would behave differently per player count.
   - **Determinism and cost**: closed-form paths need no per-enemy decisions, test headless, and cost almost nothing on Web.
   - **Authoring**: waves are tuned by editing numbers, not by tuning behaviour trees.
5. The **only** reactions to players are:
   - **Facing** (optional per definition): the sprite and muzzle turn toward the nearest player at a capped rate (F2). It changes where the muzzle points, not the path.
   - **Aim** inside patterns, which is the Pattern library's job (its targeting rotation), not this system's.
   - **Spawn clearance** (Rule 8).

**Movement paths**

6. A **path** (`EnemyPathDef`) is a pure function of the enemy's integer **age** (ticks since spawn; age 0 on the spawn tick) and the spawn parameters: `position = origin + path(age)` (F1). Types, all in px and integer ticks:

| Type | Behaviour | Main parameters |
|---|---|---|
| `STRAIGHT` | constant velocity; ground targets follow the live ground scroll `S` (ground anchor, F-table below) | `v` (px/tick), `speed_mode` = FIXED / SCROLL |
| `BEZIER` | cubic curve over `D` ticks, then continues straight at the end velocity | `P0..P3`, `D` |
| `SINE` | steady descent with a lateral sine wave | `v_y`, `amp`, `period`, `phase` |
| `ENTER_HOVER_EXIT` | ease in to a hover point, hover (optional drift), accelerate away | `H`, `enter_ticks`, `hover_ticks`, `drift_amp`, `drift_period`, `exit_v`, `exit_a` |
| `FOLLOW_FORMATION` | anchor path of any other type, plus a fixed offset | `anchor` (path), `offset`, `rotate_offset` |

   A path may be **mirrored** (x → 360 − x) at spawn, so one authored left-entry path serves both sides.
7. **Formations** are not a separate system. A formation is the Wave director spawning several `FOLLOW_FORMATION` enemies on the same `anchor`, with different `offset`s, on the same tick (a V) or on successive ticks (a trail, same `offset`). If the leader dies, the others keep flying.
8. **Spawn.** The Wave director calls `spawn(role, path_ref, origin, mirror, params)`; `params` = `carrier` (bool), `wave_intensity` (0–1), `S_spawn` (the ground scroll `S` at spawn, for GROUND targets; replaces `scroll_v`, Parallax (23) F4 *(2026-11-03, wave 3b)*), and optionally `preview` (a Boss power budget (15) mechanic id: the manager replaces emitter 0's patterns with that mechanic's preview set, forces `intensity_source = CONSTANT(0)` and, for a RULE preview, applies the preview's plating override; amended 2026-11-03 from Boss power budget (15) Rule 15). *Also 2026-11-03 ([Wave director (16)](wave-and-stage-director.md) Rules 6, 9, 19):* `strip_tags[]` (novelty tags to strip from native patterns, Rule 4 gating; a role with no tagged pattern ignores them), `max_life_ticks` (overrides the role default when > 0) and `event_id` (the Director's `SpawnEvent.id`, echoed in `spawn_failed`). *Drill-only params (2026-11-03, wave 4, [Tutorial (30)](tutorial.md)):* `hp_override` (int hp, replaces F4 scaling), `dummy` (armoured 100 %, never dies, no weapons, no drops, still takes counted hits) and `drop_override` (POD / MEDAL / CHAIN, passed to Powerups). Only Tutorial's `DrillRunner` may set them; the stage data lint rejects them in any `StageDef`. It succeeds only if all hold:
   1. fewer than `max_alive` enemies are alive, and the hurtbox budget has room (F9b);
   2. Collision's `spawn_is_clear(pos, r_e)` is true (off-screen, or `r_pl + r_e + spawn_clearance` from every Active player);
   3. the body at age 0 is completely outside the field (F10) or the definition is `GROUND` and the clearance check passes.

   If the spawn is **blocked by clearance (2)**, the request is kept and retried every tick for `spawn_retry_ticks` (30); after that it is dropped and counted (`spawns_dropped`). Refusals by (1) are dropped at once. Every refused or dropped request emits `spawn_failed(event_id, reason)` (`reason` = `MAX_ALIVE`, `HURTBOX_BUDGET` or `CLEARANCE_TIMEOUT`); the Director may re-queue carrier and preview events (Director Rule 9). `alive_count()` returns the number of alive enemies for the Director's early-clear test. *(Amended 2026-11-03.)* On success, the manager draws one seed per emitter from the gameplay RNG, in emitter order, and **only on success** (retries consume no random numbers).

**Lifecycle, visibility and body publication**

9. An enemy is **targetable** on a tick when its body capsule (at T+1) intersects the field rectangle `[0,360] × [play_top, 640]`. Only targetable enemies publish hurtboxes to the Bullet manager and a record (including hp and mode) to Collision. An enemy that is not targetable cannot be hit by anything, so a bomb or laser aimed at "everything" never kills an enemy the player has not seen.
10. **Hurtbox vs body:** Collision's lethal body is the capsule with radius `r_e` (the visible core: sprite 18 px → `r_e` 8). The Bullet manager's hurtbox is slightly bigger: `r_h = r_e + hurt_pad` (2 px), so shots feel generous while deaths stay honest. Capsules longer than one circle register `hurtbox_count` circles on the spine (F3), all sharing one `(id, generation)`.
11. **Ground targets** (`layer = GROUND`: gunboats, AA nests, turret platforms) have `lethal = false`: the player flies over them. They keep a hurtbox and hp, and a hit kills them like any enemy. Collision's body record carries the `lethal` flag (amendment 2). Air enemies are lethal.
12. **Plating (armour use).** A definition with `plating_ticks > 0` (MVP: both LARGE enemies, 120 ticks, `plating_armor_pct` 50) is published as **armoured** from the first tick it is targetable until `plating_ticks` ticks later, then **normal**. Armoured hits count for the chain (Collision C5). Armoured enemies cannot die, and a plated large enemy opens its hatch (the art bible "tell") at exactly the tick its plating falls and its first wall volley starts. SMALL and MEDIUM enemies are always normal.
13. **Hit results.** Collision returns `(id, gen, shooter, result, dealt, hp_after)`. The manager sets `hp = hp_after` of the last result for each enemy. On *destroyed* it runs Rule 14. *Ignored* and *hit* change nothing else.

**Death**

14. On *destroyed* (Collision Phase A, applied by the manager the same tick, after the referee tick), in this order:
   1. The enemy is removed from the next hurtbox/body publication; a body destroyed in Phase A is never body-tested (Collision C2).
   2. **All emitters stop** with `owner_destroyed = true`, which cancels lit flak fuses (Pattern library States). Bullets already in flight stay.
   3. `enemy_destroyed(id, def_id, kill_class, pos, killer_slot, carrier)` is emitted (VFX, Audio, Wave director, Powerups). Scoring's kill points come from Collision's `kill_credit(slot, class)`, not from this event.
   4. If the definition's `cancel_radius > 0`: `request_cancel(circle(pos, cancel_radius), cause_slot = killer_slot)`. Cancelled bullets become score items credited to the killer (Bullet manager Rules 13–14).
   5. If `carrier`: `drop_requested(pos, killer_slot, def_id, kill_class)` goes to Powerups (13).
   6. The slot's generation increments and the slot is free.
15. **Kill and bullets (decision).** SMALL kills cancel nothing. MEDIUM kills cancel a 40 px circle and LARGE kills a 72 px circle. Why:
   - *Against chain and scoring:* small enemies die constantly (a wave kills 40+). If each cleared bullets around it, the player could erase curtains by popping fodder, and score items would flood in at chain-scaled values (gem = 100 × up to 11). Medium and large kills are rare, deliberate events, so a small cancel pocket is a reward worth planning for.
   - *Why not none at all:* a bomber's wall and a gunner's ring are the biggest threats a player can remove, and the kill should feel like it. The pocket also keeps the player's close-range chain (hitting from point-blank) from being punished by the bullets that were aimed at them.
   - *Why not big:* radii of 40 and 72 px are about the enemy's own size, so the pocket never reaches across the screen. Bombs and part kills remain the big cancels.
   - The cancel is area-based, so it also takes other enemies' bullets inside the circle. This is accepted: it is the pocket.
   - A kill adds **no extra chain bonus** (only boss parts do, Chain tracker Rule 2). The killing hit itself counts as a normal hit.
16. **Escape and despawn.** An enemy that has been targetable at least once ("seen") and whose body is outside the field by more than `despawn_margin` (16 px) is removed silently: no kill credit, no explosion, no cancel; `enemy_escaped(id, def_id, carrier)` is emitted (the tally may count it). An escaped carrier drops nothing. An enemy that is never seen is only removed by `max_life_ticks` or `despawn_all`. When `age ≥ max_life_ticks` (air enemies only; default 1,500), the enemy switches to a **forced exit**: straight up at `forced_exit_speed` (2.5 px/tick) from its current position, and `Leaving` is set. The Wave director can call `force_exit(id)` for the same effect. `despawn_all(reason)` (stage end, boss intro) removes every enemy silently, stops emitters with `owner_destroyed = true`, and emits no kill events.

**Firing**

17. Each emitter in the definition has: `muzzle_offset` (px, in the "facing down" frame), `patterns[]` (Pattern library resources, or overrides), `intensity_source`, `fire_start` (default 0) and `fire_end` (default none), and `tell_ticks`.
18. **Fire zone and arming (decision on pattern library Open Question 5: off-screen emitters do not fire).** An emitter's muzzle position is **armed** the first tick its muzzle point is inside the fire zone (the field inset by `fire_inset` = 4 px on all sides), the enemy age ≥ `fire_start`, and the enemy is not `Leaving` (unless `fire_during_exit`). Arming starts the emitter, so the library's `start_delay` counts from that tick. It is **retired** (stopped for good, `owner_destroyed = false`) the first tick after that the muzzle leaves the zone, the enemy starts `Leaving`, or `age ≥ fire_end`. An emitter is never re-armed. Why: the pattern library has no pause, and arm-once/retire-once keeps timings learnable (Readable Chaos: the player never takes a bullet from an enemy they can't see). A validator warns when a path takes an armed muzzle out of the zone mid-pattern (F6). **Boss (14) is exempt from fire-zone arming:** it starts all its emitters at `boss_started` and relies on a placement lint instead (Boss GDD; amended 2026-11-03).
19. **Intensity** is read from `intensity_source` and held constant per burst by the library. Sources:
    - `CONSTANT(v)`: the same value for life. MVP default (v = 0, patterns fire always).
    - `WAVE`: the `wave_intensity` from the spawn request, **frozen at spawn**. The Wave director sets it from wave number (provisional: `(wave − 1) / 4`, so waves 1–5 give 0, 0.25, 0.5, 0.75, 1). Frozen intensity means a pattern's gate never flickers (library edge case) and a given wave is always the same. `WAVE` is not used by preview emitters (spawn param `preview`), which always run at `CONSTANT(0)` (Boss power budget (15)).
    - `AGE_RAMP(ticks)`: rises monotonically from 0 to 1 over `ticks` of armed time. Used for patterns that should "wind up".
20. **Tell.** MEDIUM and LARGE emitters expose a visible tell `tell_ticks` (default 12) before each volley, via the library's `next_volley_in(emitter)` query (amendment 1). Aim-lock patterns already have the library's lock tell, which counts as the tell.
21. **Facing.** `facing_mode`: `DOWN` (fixed, default for most), `PATH` (follows velocity direction), `AIM` (turns toward the nearest Active player at `turn_rate`, F2). The muzzle origin is `p + R(facing − π/2) · muzzle_offset`; the capsule spine rotates with facing for `AIM`/`PATH` enemies. The emitter's centre is the body centre.

**Co-op and scaling**

22. **hp scales with player count for MEDIUM and LARGE only**, read once at spawn (F4). SMALL hp is fixed. The Wave director scales co-op SMALL group sizes (`spawn_pct(N)`, Director F2; Open Question 4 closed). Existing enemies are never rescaled when players join or leave.

**Performance**

23. At most `max_alive` (28) enemies are alive and at most `enemy_hurtbox_budget` (32) enemy hurtboxes are registered at once. The Bullet manager's reference scene assumes 40 hurtboxes in total; the other 8 are reserved for a boss arriving as the last stragglers leave, and 8 is the boss's maximum (`boss_hurtbox_budget`, Boss (14) Rule 10). The manager allocates nothing per tick (fixed pools, reused buffers).

### States and Transitions

Per enemy:

| State | Hurtbox / body published | Emitters | → Next |
|---|---|---|---|
| **Incoming** | no | none armed | Active (body intersects the field) |
| **Active** | yes (while the body intersects the field) | arm/retire by Rule 18 | Leaving (path exit phase, `force_exit`, `max_life`) / Destroyed / Gone |
| **Leaving** | yes (while intersecting) | retired unless `fire_during_exit` | Destroyed / Gone |
| **Destroyed** | no | stopped, `owner_destroyed` | slot freed the same tick |
| **Gone** | no | stopped (`owner_destroyed = false`, fuses may still burst) | slot freed; `enemy_escaped` if seen |

Plating mode, per enemy with `plating_ticks > 0`: **Armoured** (from the first targetable tick for `plating_ticks` ticks) → **Normal** (permanent). The mode is a snapshot at the start of the tick (Collision edge case).

Per emitter: **Unarmed → Armed → Retired** (final). The library's runner states take over once Armed.

**Tick order for this system** (extends the ADR-0001 diagram; → ADR for the core wiring):
1. *(Wave director 16 spawns here, before the manager.)*
2. **3b. `EnemyManager.tick()`:** process the spawn queue; for each enemy in id order: `age += 1`, evaluate path, facing, mode, targetable, seen, leaving, despawn; arm/retire emitters and give each its origin, centre, intensity; publish hurtboxes to the Bullet manager and bodies to Collision.
3. Step 4 (Patterns) runs the library's runners with the new origins.
4. Steps 5–6 run Bullet manager and Collision referee.
5. **6a. `EnemyManager.apply_results()`** (renumbered from 6b *(2026-11-03, wave 3b)*; Critical Break is 6b, Boss `apply_results` 6c): apply hp, run Rule 14 for each destroyed enemy, remove them. Their cancel requests are consumed on the next tick (Bullet manager Rule 15).

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Collision (6) — GDD | → bodies `{id, gen, a, b, r_e, p_prev, p_cur, hp, mode, armor_pct, kill_class, lethal, on_boss = false}`; ← `hit_results` incl. `hp_after`; ← `spawn_is_clear(pos, r_e)`; ← `death_fire_hold` (via the library) | Referee applies damage and sends `kill_credit(slot, class)` to Scoring |
| Bullet manager (3) — GDD | → `set_hurtboxes([id, gen, pos, prev, radius])`, `request_cancel(circle, cause_slot)` on MEDIUM/LARGE kills | |
| Pattern library (9) — GDD | → per emitter: patterns, origin, centre, intensity, start (arm), stop(owner_destroyed); ← `next_volley_in(emitter)` | Emitter seeds come from stable ids, not from a shared RNG: `seed(run_seed, stage_index, owner_id, emitter_index)` with `owner_id = event_id × 16 + member_index` (member = position in the spawn group, 0–11) *(2026-11-03, ADR-0003)* |
| Scoring (8) — GDD | (via Collision) `kill_credit(slot, SMALL / MEDIUM / LARGE)` | |
| Chain tracker (7) — GDD | none directly (hits come from Collision) | Enemy adds no chain bonus |
| Session (1) / Player plane (5) — GDD | ← slot states and positions (facing target, `play_top`, player count for hp scale) | |
| [Wave director (16)](wave-and-stage-director.md) | ← `spawn(...)` (params incl. `preview`, `strip_tags[]`, `max_life_ticks`, `event_id`), `force_exit`, `despawn_all`; → `enemy_destroyed`, `enemy_escaped`, `spawn_failed(event_id, reason)`, `alive_count()` for wave bookkeeping | Spawns by role; owns wave timing, wave intensity, scroll speed |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | ← role tables per era (`EraDef`), strip map and `v_strip` (F4) | |
| Powerups (13) — [GDD](powerups-and-drops.md) | → `drop_requested(pos, killer_slot, def_id, kill_class)` for carriers | Powerups decides what drops (POD, CHAIN, MEDAL, 1UP); kill-cancel gems capped by `items_per_cancel_cap` |
| Plane kits (11) — [GDD](plane-kits-lancer-leech.md) | → read-only `targetable_enemies()` list `[(id, gen, pos, hurtbox_radius)]` for Leech magnets and homing | |
| Boss (14) — [GDD](boss-and-boss-parts.md) | shares `EmitterDef` and body/hurtbox publication helpers; **exempt from fire-zone arming** (starts emitters at `boss_started`, placement lint) | Boss owns its parts, uses at most the 8 reserved hurtboxes, and does not use `EnemyPathDef` |
| Boss power budget (15) — [GDD](boss-power-budget.md) | ← spawn param `preview` (emitter 0 swap, `CONSTANT(0)`, plating override); ← `novelty_tags` gating applied by the Wave director | Previews ride on role carriers |
| Bombs (12) — [GDD](bombs.md) | none (no events needed); Bombs read the hurtbox registry | Bomb damage reaches only targetable enemies |
| VFX (25) — [GDD](vfx-and-screen-feedback.md), Audio (24) — [GDD](audio.md), HUD (20) — [GDD](hud.md) | → `enemy_destroyed`, `enemy_damage_state`, `enemy_plating_ended`, `enemy_tell(id, ticks)`, `enemy_escaped` | Presentation only |

All listed systems now have GDDs *(2026-11-03, wave 3b)* (11, 13, 14, 15, 16, 19, 23, 24, 25); the contracts above are what this GDD expects. Parallax (23): ground targets read `S` from the Director's `ScrollClock` (no direct dependency on a presentation system).

> Decided under auto-approve (2026-11-03): scripted-not-reactive AI with turn-to-face only; no off-screen firing (closes Pattern library Open Question 5); arm-once/retire-once emitters; intensity frozen at spawn; SMALL kills cancel nothing, MEDIUM 40 px, LARGE 72 px; no kill chain bonus; ground targets non-lethal; LARGE plating 120 ticks at 50%; hp scales with players for MEDIUM/LARGE only; spawn by role with per-era role tables; carriers are flagged in the spawn request (no random drops).

## Formulas

Conventions: px; 60 ticks/s; angles in radians (0 = right, π/2 = down); `age` is an integer ≥ 0; canvas 360 × 640; positions are evaluated from `age` in closed form, never accumulated. `field` = `[0,360] × [play_top, 640]`.

**F1. Path position**

`pos(age) = origin + y_shift·ŷ + mirror_x(path(age))`, where `y_shift = play_top − 48` (F10) and mirror flips x about 180 (so `x → 360 − x`, `v.x → −v.x`).

| Type | `path(age)` |
|---|---|
| STRAIGHT | `P0 + v × age` (SCROLL mode, ground anchor: `y = P0.y + (S_now div 100) - (S_spawn div 100)`, equal to the L3 offset change since spawn; `S` read from the Director's `ScrollClock`, Parallax (23) F4 *(2026-11-03, wave 3b)*) |
| BEZIER | `t = min(age, D) / D`; `B(t) = (1−t)³P0 + 3(1−t)²t·P1 + 3(1−t)t²·P2 + t³·P3`; for `age > D`: `P3 + v_end × (age − D)`, `v_end = 3(P3 − P2) / D` |
| SINE | `(x0 + amp·sin(2π·age / period + phase), y0 + v_y × age)` — *(2026-11-03, ADR-0003)*: `sin` via `SimMath`, position rounded to 1/16 px |
| ENTER_HOVER_EXIT | below |
| FOLLOW_FORMATION | *(2026-11-03, ADR-0003)* `heading` uses `SimMath.atan2_bam`, `R(α)` uses table sin/cos, result rounded to 1/16 px. `anchor(age) + R(α)·offset`, `α = heading(anchor, age) − π/2` if `rotate_offset` else 0; `heading = atan2(Δy, Δx)` of `anchor(age) − anchor(age−1)` (age 0 uses age 1) |

ENTER_HOVER_EXIT with `u = age / enter_ticks`, `τh = age − enter_ticks`, `τ = age − enter_ticks − hover_ticks`, `drift(τh) = (drift_amp·sin(2π·τh / drift_period), 0)`:
- `age < enter_ticks`: `P0 + (H − P0) × (1 − (1 − u)²)` (ease out)
- `enter_ticks ≤ age < enter_ticks + hover_ticks`: `H + drift(τh)`
- `age ≥ enter_ticks + hover_ticks`: `H + drift(hover_ticks) + exit_v × τ + ½·exit_a × τ²` (flagged **Leaving**)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Age | `age` | int ticks | 0–`max_life_ticks` | Ticks since spawn |
| Duration | `D`, `enter_ticks`, `hover_ticks` | int ticks | ≥ 1 | Clamped to ≥ 1 at load |
| Velocity | `v`, `v_y`, `exit_v` | px/tick | 0.3–4 (player move_speed is 3.5) | Validator rejects `|v_end| < 0.3` |
| Period | `period`, `drift_period` | int ticks | ≥ 30 | |
| Amplitude | `amp`, `drift_amp` | px | 0–120 | |
| Formation offset | `offset` | Vector2 px | ±80 | Authored in the "heading down" frame |
| Play-top shift | `y_shift` | px | 0 or 24 | F10 |

**Output Range:** any position; the validator checks each path stays inside `[−60, 420] × [play_top − 60, 700]`.

**Example (all `y_shift` 0, no mirror):**
- STRAIGHT `P0 = (180,22)`, `v = (0,2)`, age 100 → **(180, 222)**. Mirrored with `P0 = (60,22)` → (300, 22) at age 0.
- SINE `x0 180, amp 40, period 120, v_y 1.6, y0 22`, age 30 → x = 180 + 40·sin(π/2) = 220, y = 22 + 48 → **(220, 70)**; age 60 → (180, 118).
- BEZIER `P0 (−20,40) P1 (120,40) P2 (240,200) P3 (380,360)`, `D 240`: age 120 → **(180, 140)**; age 0 → P0; age 240 → P3; `v_end = 3·(140,160)/240 = (1.75, 2.0)`; age 300 → **(485, 480)**.
- ENTER_HOVER_EXIT (heavy bomber) `P0 (180,22) H (180,150) enter 90 hover 420 drift 20/240 exit_v (0,−0.5) exit_a (0,−0.04)`: age 45 → u 0.5, ease 0.75 → **(180, 118)**; age 90 → (180,150); age 150 → τh 60 → (200,150); age 510 → drift sin(7π/2) = −1 → (160,150); age 576 → τ 66 → y = 150 − 33 − 87.12 = **(160, 29.88)**.
- FOLLOW_FORMATION on the BEZIER above, age 120: heading `atan2(1.5, 1.625) = 0.7454`, `α = −0.8254`; offset (20,0) → **(193.57, 125.30)**.

**F2. Motion pair and facing**

`p_e(T) = pos(age_T)`, `p_e(T+1) = pos(age_T + 1)`. On the spawn tick `p_e(T) = p_e(T+1) = pos(0)` (Collision C1: no sweep across a spawn).
`facing' = facing + clamp(wrap(θ_t − facing), −turn_rate, +turn_rate)`; `θ_t` is the angle from the enemy to the nearest Active player (squared distance; ties → lowest slot); with no Active player, `θ_t = path heading` (PATH) or π/2 (DOWN, AIM).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Turn rate | `turn_rate` | rad/tick | 0.02–0.12 (default 0.05, about 172°/s) | Per definition |
| Facing | `facing` | rad | (−π, π] | Starts at π/2 |

**Output Range:** `|facing' − facing| ≤ turn_rate`. **Example:** facing π/2 (1.5708), target at angle 0 (due right): diff −1.5708, clamped to −0.05 → 1.5208; after 10 ticks 1.0708.

**F3. Body capsule and hurtboxes**

`a = p + R(f)·(−spine_half, 0)`, `b = p + R(f)·(+spine_half, 0)`, `f = facing − π/2` for AIM / PATH enemies and 0 for DOWN.
`k = hurtbox_count`; hurtbox circle `i`: `c_i = a + (b − a)·i/(k−1)` (k = 1 → centre), radius `r_h = r_e + hurt_pad`.
**Validator:** `spacing = 2·spine_half/(k−1) ≤ 1.5·r_h` (no gap a bullet can slip through).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Spine half | `spine_half` | px | 0–40 | 0 for circles |
| Body radius | `r_e` | px | 7–20 | Lethal radius (Collision C1) |
| Hurt pad | `hurt_pad` | px | 0–4 (default 2) | Player-friendly hit area |
| Hurtboxes | `k` | int | 1–3 | Counts against the budget (F9b) |

**Output Range:** `r_h` 9–22. **Example (heavy bomber, `r_e` 18, spine ±30, k 3):** `r_h = 20`; circles at x = p.x − 30, p.x, p.x + 30; spacing 30 ≤ 1.5 × 20 = 30 → pass. Medium gunner: `r_e 12`, ±8, k 2, `r_h 14`, spacing 16 ≤ 21 → pass.

**F4. Spawn hp**

`hp = (hp_base × (100 + coop_hp_step × (N − 1)) + 50) / 100` for MEDIUM and LARGE (Co-op (18) F4 `coop_hp_scale`, used verbatim); `hp = hp_base` for SMALL; integer maths. *(Amended 2026-11-03: was `round10` with 60 %; Co-op owns the step.)*

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base hp | `hp_base` | int | 20–6,000 | From the definition |
| Players | `N` | int | 1–4 | Slots Alive, Dead or Continue at the spawn tick (the same count that sets `play_top`) |
| Co-op hp step | `coop_hp_step` | int | 0–100 (default 50, owned by Co-op (18)) | Each extra player adds this much of `hp_base` (100 / 150 / 200 / 250 %) |

**Output Range:** SMALL 20–60; MEDIUM 1,200–1,500 solo, up to ×2.5 at 4P (1,200 → 3,000; 1,500 → 3,750); LARGE 4,000–5,000 solo, up to 12,500 at 4P. **Example:** heavy bomber 4,000: N 1 → 4,000; N 2 → 6,000; N 4 → 10,000. Missile carrier 5,000, N 3 → (5,000 × 200 + 50) / 100 = **10,000**. Flak gunner 1,200, N 3 → 2,400; N 4 → 3,000. Scout 20 at any N → 20.

**F5. Plating mode**

`mode(T) = ARMOURED if plating_ticks > 0 and first_seen ≤ T < first_seen + plating_ticks, else NORMAL`; `armor_pct = plating_armor_pct`.
Damage follows Collision C4 (`dealt = max(1, damage × armor_pct div 100)`; hp floors at 1 while armoured).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| First seen | `first_seen` | int tick | ≥ 0 | First tick the enemy is targetable |
| Plating | `plating_ticks` | int | 0 or 60–180 (default 120 for LARGE) | |
| Plating armour | `plating_armor_pct` | int | 25–75, whole percent (default 50) | Same whole-percent lint as Collision C4 |

**Output Range:** ARMOURED for exactly `plating_ticks` ticks. **Example:** bomber first targetable on tick 1,003 → armoured ticks 1,003–1,122, normal from 1,123. A 20-damage hit during plating → dealt 10; after plating → 20.

**F6. Fire zone and arming**

`zone = field inset by fire_inset` = `[4, 356] × [play_top + 4, 636]`.
`arm_tick = first T where muzzle(T+1) ∈ zone and age ≥ fire_start and not Leaving`.
`retire_tick = first T > arm_tick where muzzle ∉ zone, or Leaving (unless fire_during_exit), or age ≥ fire_end`.
`muzzle = p + R(facing − π/2)·muzzle_offset`.

**Validator:** for each emitter, sample the path from `arm_tick` to `arm_tick + 1.5 × (start_delay + interval)`; warn if the muzzle leaves the zone.

**Output Range:** `arm_tick` ≥ 0; one arm and at most one retire per emitter. **Example (heavy bomber, muzzle offset (0,14), path F1, `play_top` 48):** muzzle y = path y + 14; zone top is 52 → needs path y ≥ 38. Age 5 → y = 22 + 128 × (1 − (1 − 5/90)²) = 35.8 (no); age 6 → 38.5 → **armed at age 6**. Tail-gun `start_delay` 60 → first volley at age 66.

**F7. Kill cancel**

`cancel_i = |p_i − c|² ≤ (R_c + r_vis)²`, with `c` = the enemy's centre at death, `R_c = cancel_radius` (SMALL 0 = no request, MEDIUM 40, LARGE 72); `r_vis` and credit rules are the Bullet manager's (F9 there).

**Example (MEDIUM kill at (200,300), cause slot 1, orb `r_vis` 4):** orb at 44 px is cancelled and becomes an item for slot 1; orb at 45 px survives. LARGE (72): orb at 76 px cancelled, 77 px survives.

**F8. Kill-time and exposure validator** (authoring check, unit test over `data/enemies/`)

`plating_dealt = plating_ticks × (ref_dps / 60) × plating_armor_pct / 100` (0 if no plating)
`ttk = plating_ticks + ceil((hp − plating_dealt) × 60 / ref_dps)` (no plating: `ceil(hp × 60 / ref_dps)`)
`exposure = count of ages where the body is targetable (F1 over age 0…max_life or until Gone)`
**Rule:** MEDIUM and LARGE: `exposure ≥ exposure_margin × ttk`; SMALL: `exposure ≥ 90` ticks.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Reference dps | `ref_dps` | int units/s | 400–1,200 (default **800**) | One competent player with 2 drones, on target: Plane kits (11) "Reference DPS for content budgets" (Lancer 857.8 / Leech 832.5, floored to 800). Owned by Kits (11); replaces the old provisional `enemy_ref_dps` 300 |
| Margin | `exposure_margin` | float | 1.2–2.0 (default 1.4) | Slack for a player who is not shooting the whole time |

**Output Range:** `ttk` 3–435 ticks at defaults. **Example (heavy bomber):** plating dealt = 120 × (800 / 60) × 0.5 = 800; `ttk = 120 + ceil((4,000 − 800) × 60 / 800) = 120 + 240 = 360`; required exposure 1.4 × 360 = 504. Path F1: targetable from age 3 to 575 (out at 576) → 573 ≥ 504 → **pass**. Missile carrier 5,000, hover 480: plating dealt 800, `ttk = 120 + ceil(4,200 × 60 / 800) = 120 + 315 = 435`, required 609; exposure 87 + 480 + 66 = 633 → pass. Flak gunner 1,200 → ttk 90.

**F9. Density and budgets**

**(a) Per-definition bullet estimate:** the Pattern library's F9 summed over the definition's emitters: `N_def = Σ rate × L_path / v_eff`, with `rate = (count − gap_slots) × burst_count × 60 / interval`. **Ceilings per enemy** (error): SMALL 20, MEDIUM 60, LARGE 150.

| Definition | Emitter patterns | `N_def` |
|---|---|---|
| Prop fighter | aimed stream: 1 orb × 3, gap 8, interval 150, 110 px/s | 1.2/s × 640/110 = **7.0** |
| Flak gunner | flak ring 12, interval 120, 90 px/s, L 320 | 6/s × 320/90 = **21.3** |
| Heavy bomber | wall 7 (gap 1), interval 138, 100 px/s; tail fan 3, interval 90, 130 px/s | 16.7 + 9.8 = **26.5** |
| Delta jet | aim-locked fan 3, interval 120, rice 70→330 (v_eff 200) | 1.5/s × 640/200 = **4.8** |
| Radar gunner | aim-locked fan 5, interval 108, v_eff 200 | 2.78/s × 3.2 = **8.9** |
| Missile carrier | wall 7 (gap 1), interval 138, 110 px/s; aim-locked fan 7, interval 96, v_eff 200 | 15.2 + 14.0 = **29.2** |

**(b) Budgets:** `Σ hurtbox_count over alive enemies ≤ enemy_hurtbox_budget` (32); `alive ≤ max_alive` (28). The wave-level bullet budget (`Σ N_def` for enemies alive together) belongs to the Wave director. ~~Provisional proposal: ≤ 600 per wave.~~ *Replaced 2026-11-03 by the Director's per-wave curve caps 60 / 80 / 100 / 120 / 150 at N = 1 (waves 1-5, peaks strictly rising) plus the 1,700 hard ceiling at N = 1-4 (Director F3, validator V-D5).*

**Example:** 16 SMALL (16) + 4 MEDIUM (8) + 2 LARGE (6) = 30 hurtboxes ≤ 32. A third LARGE (3 more, 33) is refused.

**F10. Spawn placement and play-top shift**

`y_shift = play_top − 48` (0 in 1–2P, 24 in 3–4P), added to every path y at spawn. Air enemies must satisfy `y(0) + y_shift + r_e + spawn_offscreen_margin ≤ play_top` for a top entry, or the equivalent for a side entry (`x(0) ≤ −r_e − 8`, `x(0) ≥ 360 + r_e + 8`).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Margin | `spawn_offscreen_margin` | px | 4–24 (default 8) | Body fully clear of the field at age 0 |

**Example:** heavy bomber `r_e` 18: `y(0) ≤ 48 − 18 − 8 = 22` → path P0.y = 22 ✓. In 3–4P `y_shift` 24: y(0) = 46 ≤ 72 − 18 − 8 = 46 ✓.

> Decisions (2026-11-03, auto-approve): closed-form paths; reference dps 300 and TTK targets (1.5 s / 5 s) (reference dps re-based to 800 = Kits reference, 2 drones, on 2026-11-03; hp x 8/3, TTK targets unchanged); plating 120 ticks at 50%; exposure margin 1.4; hp scaling 50% per extra player (Co-op `coop_hp_step`; amended 2026-11-03 from 60%); hurt pad 2 px; fire inset 4 px; despawn margin 16 px; forced exit 2.5 px/tick; `max_alive` 28, hurtbox budget 32.

## Edge Cases

**Spawning**
- **If `spawn_is_clear` is false**, the request is retried each tick for 30 ticks, then dropped (`spawns_dropped` +1), with no random numbers drawn and no event.
- **If `max_alive` or the hurtbox budget is exceeded**, the spawn is refused at once and counted (`spawns_refused`) and `spawn_failed` is emitted; the Wave director must not rely on Enemy retries (it re-queues carriers and previews itself, Director Rule 9).
- **If two spawns are accepted on the same tick**, they are processed in request order, so emitter seeds are drawn in a fixed order.
- **If a path's spawn point is on-screen** (a `GROUND` enemy appearing at the top edge), only clearance applies; `GROUND` enemies enter at `y ≤ play_top − r_e − 8` like air ones.
- **If `play_top` changes after spawn** (a player joins/leaves), existing enemies keep their shift; the fire zone and targetable test use the new `play_top`. An enemy now above the line stops being targetable until it comes back or leaves.
- **If a path has `D`, `enter_ticks`, `period` or `hover_ticks` < 1**, the loader clamps to 1 and logs an error; the validator fails.

**Movement and visibility**
- **If a path ends with `v_end` below 0.3 px/tick** (the enemy would stop), the validator fails. At runtime `max_life_ticks` forces an exit.
- **If an enemy is never targetable** (a mis-authored path), it is removed at `max_life_ticks` with `enemy_escaped` not emitted (never seen).
- **If an enemy is targetable only for a few ticks** (grazes a corner), it can be hit during those ticks only; it counts as seen.
- **If a mirrored path starts at x = 180**, mirroring is the identity.
- **If a FOLLOW_FORMATION anchor ends** (the anchor is a BEZIER past `D`), members continue at `v_end`; their offsets keep rotating by the last heading.
- **If an enemy overlaps another enemy**, nothing happens: bodies do not collide with each other.
- **If the game is paused**, no ticks run; ages, plating, arming and `max_life` freeze.

**Players and bodies**
- **If an air enemy's body reaches a player**, Collision handles it (kills, unless the player is invulnerable). Nothing here dodges, pushes or slows.
- **If the player is above a `GROUND` target**, there is no contact (non-lethal). The ground target can still be hit.
- **If an enemy is destroyed on the tick its body would touch a player**, the player survives (Collision C2). The manager only supplies the body list; the order is Collision's.
- **If all players are dead or absent**, enemies keep flying and firing; aimed patterns fire straight down (Pattern library Rule 11); `AIM` enemies face down.

**Damage and death**
- **If several hits arrive for one enemy on one tick**, Collision gives one *destroyed* result; the manager runs the death once (Rule 14). Later events in the same tick return *ignored*.
- **If a hit targets a freed slot** (stale `(id, gen)`), Collision returns *ignored*; nothing changes here.
- **If the last hit happens during plating**, the enemy stays at 1 hp (armoured cannot die). When plating ends it takes the next normal hit.
- **If plating ends on the tick a hit lands**, the hit uses the mode published at the start of that tick (snapshot).
- **If a large enemy dies with fuses lit** (flak), its fuses are cancelled (`owner_destroyed = true`); bullets already fired remain.
- **If a MEDIUM or LARGE kill and a player death happen on the same tick**, the kill's cancel request is made, then the death clear removes the remaining bullets; the cancelled ones still become items (Collision edge case, cancel before clear).
- **If the killer slot is Dead or Dying**, the cancel's items are still credited to that slot and Powerups decides whether it can collect them (Bullet manager edge case).
- **If a carrier is destroyed by a bomb, laser or drone**, it still drops (any destroyed result).
- **If a carrier escapes**, there is no drop and `enemy_escaped(carrier = true)` is emitted.

**Firing**
- **If the muzzle is outside the zone while the body is on-screen** (a big bomber's tail gun), that emitter is Unarmed and fires nothing.
- **If an enemy dies before an emitter arms**, nothing fires; the emitter was never started.
- **If `death_fire_hold` is active**, the library skips volleys; arming, retiring and intensity are unchanged, so timings stay in step with the path.
- **If an emitter retires with a flak fuse lit and the enemy is alive**, the fuse still bursts (Pattern library States).
- **If the stage ends with enemies alive**, `despawn_all` stops every emitter with `owner_destroyed = true` (fuses cancelled).
- **If a pattern is missing or invalid at load**, the definition fails the data lint and the run refuses to start in debug builds; release builds skip that emitter and log an error.

**Era and roles**
- **If a wave script uses a role that the era's table does not map**, the load fails in debug and the spawn is dropped (`spawns_dropped`) in release.
- **If an era swap happens while enemies are alive**, the swap waits for `despawn_all` at stage end; enemies never change definition mid-life.

**Performance**
- **If the Bullet manager pool is full**, the library's volleys are refused (Pattern library edge case); the enemy is unaffected.

> Decided under auto-approve (2026-11-03): retry-then-drop for blocked spawns; never-seen enemies removed silently at `max_life`; era swaps only at stage boundaries; no enemy-to-enemy collision.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Collision, damage and lives (6) — GDD | Hard | Receives bodies (capsule, hp, mode, `armor_pct`, `kill_class`, `lethal`) each tick; returns hit results with `hp_after`; provides `spawn_is_clear`; `death_fire_hold` is applied through the library. |
| Bullet manager (3) — GDD | Hard | `set_hurtboxes` each tick (multi-circle per `(id, gen)`); `request_cancel` on MEDIUM/LARGE kills; shapes, speeds, pool and 40-hurtbox reference scene are its. |
| Bullet pattern library (9) — GDD | Hard | Owns pattern resources and runners. This system starts/stops emitters and gives origin, centre, intensity. Needs `next_volley_in(emitter)`. |
| Scoring (8) — GDD | Soft | Kill values for SMALL/MEDIUM/LARGE (registry `kill_values`); no calls from here. |
| Game events and session (1) — GDD | Hard | Slot states, player count (hp scale, `play_top`). Not ticked while paused. |
| Co-op and Team Chain (18) — GDD | Soft | Owns `N` (Co-op Rule 1) and `coop_hp_step` 50 %; F4 uses Co-op's `coop_hp_scale` verbatim. SMALL group size scaling is Co-op/Wave director's. |
| Player plane (5) — GDD | Hard | Player positions for facing and `spawn_is_clear`. |
| Chain tracker (7) — GDD | Soft | No interface; this system adds no chain bonus. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Wave and stage director (16) | Hard | `spawn(role, path, origin, mirror, params)`, `force_exit`, `despawn_all`; events `enemy_destroyed`, `enemy_escaped`, `spawn_failed`; `alive_count()`; budgets (alive, hurtboxes). | [yes](wave-and-stage-director.md) |
| Tutorial (30) | Soft | `DrillRunner` calls `spawn` with the same params plus `hp_override`, `dummy`, `drop_override` (drills only). | [yes](tutorial.md) |
| Era shift (19) | Hard | Role tables per era (`EraDef`), strip map, `v_strip`. | [yes](era-shift-and-plane-evolution.md) |
| Powerups and drops (13) | Hard | `drop_requested(pos, killer_slot, def_id, kill_class)` from carriers; kill-cancel gems use `items_per_cancel_cap` 100. | [yes](powerups-and-drops.md) |
| Plane kits (11) | Soft | `targetable_enemies()` for magnets and homing; `ref_dps` and damage ≥ 20 for anything that can hit plating. | [yes](plane-kits-lancer-leech.md) |
| Boss and boss parts (14) | Hard | Reuses `EmitterDef` and body/hurtbox helpers; exempt from fire-zone arming (placement lint); at most 8 hurtboxes; owns its parts. | [yes](boss-and-boss-parts.md) |
| Boss power budget (15) | Soft | Spawn param `preview` (emitter 0 swap, `CONSTANT(0)`, plating override); `novelty_tags` gating (Wave N previews mechanic N). | [yes](boss-power-budget.md) |
| Bombs (12) | Soft | No events needed; Bombs read the hurtbox registry. Bomb damage reaches only targetable enemies. | [yes](bombs.md) |
| VFX (25), Audio (24) | Soft | Explosion, damage-state, tell and plating events. | yes ([VFX](vfx-and-screen-feedback.md), [Audio](audio.md)) |
| Parallax and environment (23) | Soft | Shares the ground scroll `S` through the Director's `ScrollClock`; ground pads and corridors (Parallax F11). | [yes](parallax-and-environment.md) |
| Stage-end tally (21) | — | None in MVP: no kill ratio (Tally decision, 2026-11-03). | [yes](stage-end-tally.md) |

**Amendments to other docs** (apply at wrap-up):

1. **Bullet pattern library** (`bullet-pattern-library.md`):
   - Open Question 5 → closed: "Enemy (10): off-screen emitters do not fire; emitters arm once when the muzzle enters the fire zone and retire once (Enemy Rule 18)."
   - Interactions/Dependencies: add `next_volley_in(emitter) -> int` (ticks to the next volley across the emitter's runners, −1 if none; read-only), used for enemy tells.
   - Enemy (10) row: "intensity is held constant per enemy (frozen at spawn)".
2. **Collision** (`collision-damage-lives.md`):
   - Rule 1 and the C1 body list: bodies carry `lethal` (bool, default true) and `kill_class`; Rule 1 reads "any **lethal** enemy body". Ground targets are `lethal = false`.
   - `hit_results` gains `hp_after`.
   - Dependencies row for Enemy (10): add "publishes `kill_class`, `lethal`; calls `spawn_is_clear`; receives `hp_after`". Edge case "immune target's body still kills" stays for lethal bodies.
3. **Bullet manager** (`bullet-manager.md`): Interactions/Dependencies — cancel requesters add "Enemy (10): MEDIUM/LARGE kills (circle 40/72 px, cause = killer)"; hurtbox list note: several circles may share one `(id, gen)`; the reference 40-hurtbox scene splits 32 enemy / 8 boss.
4. **Scoring** (`scoring.md`): Interactions — Collision's `kill_credit` class values come from this system's `kill_class` (SMALL/MEDIUM/LARGE); note that kill-cancel items from MEDIUM/LARGE kills use Powerups' `items_per_cancel_cap`.
5. **Systems index:** row 10 status → `**Designed** (pending review) — [GDD](enemy-and-ai.md)`; dependencies column stays `6, 9` and gains `3, 8` for the hurtbox and kill-class interfaces (→ `3, 6, 8, 9`).
6. **ADR-0001 diagram:** add step 3b (`EnemyManager.tick()`) before Emitters/Patterns and step 6a (`EnemyManager.apply_results()`) after the referee, then 6b CB and 6c Boss (→ core wiring ADR; renumbered *(2026-11-03, wave 3b)*).
7. **Art bible:** §5.7 add the carrier cue (cream rim pulse, 2 Hz) and large-enemy plating overlay; §6.8 add per-class explosion sizes (V3 below); §5.3 tell lead of 12 ticks.
8. **Game events** (`game-events-and-session.md`): add presentation signals `enemy_destroyed`, `enemy_escaped`, `enemy_damage_state`, `enemy_plating_ended`, `enemy_tell`.

**Bidirectional check:** Collision, Bullet manager and the Pattern library already list "Enemy (10)" downstream. Scoring and Chain tracker mention Enemy (10) as a provider of kill classes. The undesigned downstream systems must list this system when written. *(2026-11-03, wave 3b: all downstream systems except Sentry/Breaker kits (29), Tutorial (30) and Touch (31) now have GDDs.)* *(Wave 4: Tutorial (30) row added; 29 and 31 have no direct Enemy interface.)*

## Tuning Knobs

**Owned by this system** (`data/enemy_rules.tres` for globals; per-enemy values in each definition)

| Knob | Default | Safe range | Too low | Too high | Interacts with | Category |
|---|---|---|---|---|---|---|
| `ref_dps` (authoring reference; Kits-owned, 2 drones) | 800 units/s | 400–1,200 | hp too low relative to real fire: everything melts, chain bridges vanish | enemies feel like sponges | Kits (11) damage × hit rate; F8 | Curve |
| TTK targets: MEDIUM / LARGE | 1.5 s / 5 s | 1–2.5 s / 3–8 s | Chain bridge shorter than the 1 s window | Enemies outstay the route; fire hold hurts | `exposure_margin`, hover time | Curve |
| `hp_base` per definition | 20 / 40 / 1,200 / 4,000 (1941); 20 / 50 / 1,500 / 5,000 (1970s) | per F8 | — | — | F8 | Curve |
| `coop_hp_step` (owned by Co-op (18)) | 50 | 0–100 | Co-op trivialises mediums/larges | Co-op large enemies take too long; chains stall | `max_alive`, wave size | Curve |
| `plating_ticks` / `plating_armor_pct` | 120 / 50 | 60–180 / 25–75 | Plating pointless | Large enemies feel immune | Collision C4 (damage ≥ 20 lint); hatch tell timing | Feel |
| `hurt_pad` | 2 px | 0–4 | Shots miss visible sprites | Shots hit empty air | `r_e`, sprite size | Feel |
| `fire_inset` | 4 px | 0–16 | Muzzle fires at the screen edge | Enemies fire late | `start_delay` | Feel |
| `cancel_radius` MEDIUM / LARGE | 40 / 72 px | 24–64 / 48–110 | Kill feels unrewarded | Kills wipe curtains; item farm | Powerups `items_per_cancel_cap`; Scoring item factor | Curve |
| `spawn_offscreen_margin` | 8 px | 4–24 | Pop-in at the edge | Longer entry | Path P0 | Feel |
| `spawn_retry_ticks` | 30 | 0–90 | Blocked enemies vanish | Enemies appear late, off the wave beat | `spawn_clearance` | Gate |
| `max_alive` / `enemy_hurtbox_budget` | 28 / 32 | 16–40 / 20–40 | Waves feel empty | Blows Bullet manager/Collision budgets | BM 40-hurtbox scene; Collision AC-51 | Gate |
| `max_life_ticks` (air) | 1,500 (25 s) | 600–3,600 | Enemies leave early | Stragglers linger | F8 | Gate |
| `forced_exit_speed` | 2.5 px/tick | 1.5–3.5 | Slow flight-away | Instant disappear | `max_life` | Feel |
| `despawn_margin` | 16 px | 8–48 | Enemy vanishes in view | Wasted slots | `spawn_offscreen_margin` | Gate |
| `tell_ticks` (MEDIUM/LARGE) | 12 | 6–24 | Tell unreadable | Fire feels laggy | Library `start_delay` | Feel |
| `turn_rate` | 0.05 rad/tick | 0.02–0.12 | Aim facing lags | Facing snaps | Muzzle origin | Feel |
| `exposure_margin` | 1.4 | 1.2–2.0 | Chain-bridge enemies can leave early | Long hover = free hits | F8 | Curve |
| Density ceilings S / M / L | 20 / 60 / 150 | — | Hard to author | Screen floods | Library F9; Wave budget | Gate |
| Era `ttk_mult` guidance | 1941: 1.0; 1970s: 1.25 | 1.0–2.0 | History Accelerates flat | Later eras grind | hp_base | Curve |

**Owned elsewhere (not knobs here):** kill values 200 / 1,000 / 5,000 → Scoring (8); `spawn_clearance` 8, `death_fire_hold` 30, `armour_damage_min` 20 → Collision (6); pattern parameters, `spawn_safe_radius`, `lane_min_clear` → Pattern library (9); bullet speeds, pool size, hit radii → Bullet manager (3); `player_hitbox_radius`, `play_top` → Player plane (5); wave intensity, scroll speed, carrier cadence → Wave director (16) / Powerups (13).

**Per-definition data:** the pattern parameters for the six armed definitions are authored in `data/patterns/` or embedded; the values in F9 are the reference.

## Visual/Audio Requirements

Follow the art bible (AB §3.2 enemy grammar, §5.7 size classes, §6.8 layers). Bullets always win: nothing here draws over layer 8 and none of it uses Void Indigo (`#4A5CFF`), Ink (`#0B0B2A`) for non-enemy art, or reserved bullet shapes.

**V1. Sprites and layers**
- Draw layers: air enemies layer 4; ground targets layer 3; hit sparks, air explosions and tell effects layer 5; ground explosions and wreck smoke layer 2. Enemy sprites are clipped at the HUD strip's lower edge (`play_top`).
- Sizes (1x px): SMALL 18–27, MEDIUM 36–60, LARGE 72–120. The lethal body is smaller than the sprite (`r_e` 8 vs 18 px).
- Era shapes: 1941 round and riveted; 1970s angular delta (AB §3.2). A recoloured 1941 enemy is rejected (AB §8).
- Facing: `AIM` enemies use 8 pre-rotated frames (45° steps); others use a fixed pose.
- Damage states (AB §5.7): MEDIUM one state at hp ≤ 50% (crack + a smoke puff every 20 ticks); LARGE two states at hp ≤ 66% and ≤ 33%. Emitted as `enemy_damage_state`.
- Hit tint, armoured clank, immune ping: Collision V2/V3.

**V2. Carrier cue and plating**
- **Carrier:** the enemy's rim pulses cream (pickup colour) at 2 Hz (period 30 ticks), 1 px, never faster than 3 Hz; the pulse is a rim value shift, not a flash. Not red, not blue.
- **Plating (LARGE):** grey steel plates cover the hull; at plating end they fall away over 8 ticks (4 frames), with debris on layer 5 (same effect as Collision V3). The hatch opens on the same tick (the tell for the first wall volley).
- **Tell:** MEDIUM/LARGE show a muzzle/hatch "open" pose, a cream-amber glow 12 ticks before each volley (6-tick fade). Amber alert colour is the library's (V2 there). SMALL have no tell.

**V3. Explosions** (era palette from AB §6.8; layer 5, shared 150-particle cap, max 24 pooled explosion sprites)

| Class | Burst | Debris | Extras | Duration |
|---|---|---|---|---|
| SMALL | 3-frame, 20 px | 3 chunks | none | 12 ticks |
| MEDIUM | 4-frame, 40 px | 6 chunks | 1 smoke puff | 18 ticks |
| LARGE | 5-frame, 72 px | 12 chunks | 2 secondary pops (at +8 and +16 ticks, inside the body), wreck smoke | 36 ticks + smoke |

- **Ground targets:** the burst is layer 2 and leaves a dark scorch and smoke that fade over 180 ticks ("wreckage accumulates"). No crater above the field.
- **Cap behaviour:** when particles reach the cap, debris drops first, then SMALL bursts; MEDIUM/LARGE bursts are never dropped. VFX (25) tiers: debris T3, SMALL T2, MEDIUM/LARGE T1 (VFX F6 eviction) *(2026-11-03, wave 3b)*.
- **Co-op:** the kill's score pop uses the killer's colour (Scoring/HUD); the explosion is era-coloured, not player-coloured.
- **Flash rule:** explosions use particles and debris, never screen flashes (AB §2).

**A1. Audio** (all (P); audio-director to confirm)

| Event | Spec | Limit |
|---|---|---|
| SMALL destroyed | short dry pop, 3 pitch variants | ≤ 1 per 3 ticks globally |
| MEDIUM destroyed | crunch + short debris tail | 1 per 6 ticks |
| LARGE destroyed | heavy boom + 0.5 s low rumble | 1 per 12 ticks |
| Tell (MEDIUM/LARGE) | soft mechanical "clunk" (hatch/breech) | 1 per tell |
| Plating ends | metallic clatter | 1 per enemy |
| Carrier destroyed | normal explosion; the pickup chime belongs to Powerups (13) | — |

- Enemy-death voice pool ≤ 4 voices (separate from the bullet pool of 8); priority LARGE > MEDIUM > SMALL; lowest dropped first.
- Era timbre follows the library's A1: 1941 mechanical, brassy; 1970s analogue.
- Muzzle and volley sounds belong to the Pattern library.

> Visual and audio choices made by `game-designer` under auto-approve; art-director and audio-director not consulted.

## UI Requirements

This system has **no player-facing UI**. Enemies show no hp bars: damage states (V1) carry the information, to keep eyes on bullets (Readable Chaos).

**Debug only (development builds):**
- Overlay toggle drawing each enemy's id, state, capsule, hurtbox circles, fire zone, muzzle points, path trace (next 120 ticks), armed/retired flags and `kill_cancel` circles.
- Per-tick counters: alive, hurtboxes registered, spawns accepted / dropped / refused, destroyed, escaped, forced exits.
- The enemy validator (F6, F8, F9) prints errors and warnings to the test log.

No UX flag: no screen or HUD element.

## Acceptance Criteria

Defaults used: `ref_dps` 800, `hurt_pad` 2, `fire_inset` 4, `spawn_offscreen_margin` 8, `spawn_retry_ticks` 30, `coop_hp_step` 50, `max_alive` 28, `enemy_hurtbox_budget` 32, `despawn_margin` 16, `forced_exit_speed` 2.5, `max_life_ticks` 1,500, `plating_ticks` 120, `plating_armor_pct` 50, `exposure_margin` 1.4, `cancel_radius` 0 / 40 / 72, `kill_values` 200 / 1,000 / 5,000, `r_pl` 3.0, `spawn_clearance` 8, 60 ticks/s. Slots 0-indexed. Position asserts ±0.01 px (±0.05 for the formation example).

**Test setup:** the logic lives in a node-free `RefCounted` class (working name `EnemyManager`) with no nodes and no `delta`; `tick()` advances one step and keeps its own tick counter. It is constructed with the seeded gameplay RNG, the enemy rules resource and the role table (`data/enemy_rules.tres`, `data/enemies/<era>/*.tres`). Inputs before a tick: `set_field(play_top)`, `set_players([{slot, state, pos}])`, `spawn(role, path_ref, origin, mirror, {carrier, wave_intensity, scroll_v})`, `force_exit(id)`, `despawn_all(reason)`. After the referee: `apply_results([{id, gen, shooter, result, dealt, hp_after}])`. Outputs: `hurtboxes()`, `bodies()`, `events` (ordered log), `emitter_log` (calls to the stub Pattern library: start, stop with flags, origin, centre, intensity), `cancel_log` (stub Bullet manager), `drop_log` (records `drop_requested(pos, killer_slot, def_id, kill_class)`), `counters`, `state_hash()` (id, gen, age, hp, mode, state, position quantised to 1/256 px). Stubs: Collision (`spawn_is_clear` scripted), Bullet manager, Pattern library, Powerups, RNG. Tests: `tests/unit/test_enemy_manager.gd`, `tests/unit/test_enemy_paths.gd`, `tests/unit/test_enemy_data.gd` (validators), `tests/integration/test_enemy_bullet_field.gd`, `tests/integration/test_enemy_referee.gd`, `tests/perf/enemy_bench.tscn`; `extends SceneTree`, like `tests/unit/test_chain_tracker.gd`. Every number is read from the `.tres` files, never literals. Manual evidence: `production/qa/evidence/enemy-and-ai/`. Names: `test_enemy_[scenario]_[result]`.

Tags: [Unit] pure logic · [Integration] real `BulletField` / `CollisionReferee` · [Manual] needs a human · [Perf] REF-PC and REF-WEB (ADR-0001).

### Paths (Rules 6–7, F1, F2)

- **AC-01 [Unit] (STRAIGHT):** `P0 (180,22)`, `v (0,2)`, age 100 → (180,222). Mirrored `P0 (60,22)` at age 0 → (300,22); `v.x` flips sign.
- **AC-02 [Unit] (SINE):** `x0 180, amp 40, period 120, v_y 1.6, y0 22`: age 30 → (220,70); age 60 → (180,118); age 0 → (180,22).
- **AC-03 [Unit] (BEZIER):** the F1 curve: age 0 → (−20,40); 120 → (180,140); 240 → (380,360); 300 → (485,480). `v_end` (1.75, 2.0).
- **AC-04 [Unit] (ENTER_HOVER_EXIT):** ages 45 → (180,118); 90 → (180,150); 150 → (200,150); 510 → (160,150); 576 → (160,29.88). The `Leaving` flag is false at 509 and true at 510.
- **AC-05 [Unit] (FOLLOW_FORMATION):** anchor = the AC-03 curve, offset (20,0), `rotate_offset` true, age 120 → (193.57, 125.30) ±0.05. With `rotate_offset` false → (200,140).
- **AC-06 [Unit] (closed form):** evaluate ages 0..600 forward, backward and in 5 shuffled orders → identical positions every time (no accumulated state).
- **AC-07 [Unit] (spawn tick):** on the spawn tick `p_prev == p_cur == pos(0)`. On the next tick `p_prev = pos(0)`, `p_cur = pos(1)`.
- **AC-08 [Unit] (F10 shift):** with `play_top` 72 every path y is +24 and a top entry still has its body fully outside the field; with `play_top` 48 no shift.
- **AC-09 [Unit] (clamps):** a path with `D = 0` loads as `D = 1` and logs an error; `period = 0` → 1; `test_enemy_data` fails on both.

### Spawn (Rule 8, F9b)

- **AC-10 [Unit] (clearance retry):** `spawn_is_clear` false for 29 ticks then true → the enemy appears on tick 30 of retrying with age 0; false for 31 ticks → dropped, `spawns_dropped` = 1, zero RNG draws, no event.
- **AC-11 [Unit] (caps):** 28 alive → the 29th is refused (`spawns_refused` 1). 16 SMALL + 4 MEDIUM + 2 LARGE (30 hurtboxes) accepted; a third LARGE (33) refused; an extra SMALL (31) accepted.
- **AC-12 [Unit] (seeds):** spawning the heavy bomber (2 emitters) then a prop fighter (1 emitter) from a fixed `run_seed` derives 3 seeds from `(run_seed, stage_index, owner_id, emitter_index)` with `owner_id = event_id × 16 + member_index`; spawning them in the reverse order, or with a refused spawn in between, gives the **same** 3 seeds *(2026-11-03, ADR-0003)*.
- **AC-13 [Unit] (role table):** `fighter` resolves to prop fighter for 1941 and delta jet for 1970s; an unmapped role fails `test_enemy_data` and in release logs and drops the spawn.

### Bodies, hurtboxes, visibility (Rules 9–11, F3)

- **AC-14 [Unit] (heavy bomber geometry):** at (200,300): body a = (170,300), b = (230,300), `r_e` 18; 3 hurtboxes at x 170, 200, 230, `r_h` 20, all with the same `(id, gen)`.
- **AC-15 [Unit] (targetable):** the bomber is not published at age 2 and is published (body and hurtboxes) at age 3; a SMALL scout at `play_top` 72 follows the same rule against 72. After it leaves, publication stops.
- **AC-16 [Unit] (ground non-lethal):** a flak gunner's body record has `lethal = false` and hurtboxes present; the prop fighter has `lethal = true`.
- **AC-17 [Unit] (not-targetable ignored):** a damage event for an Incoming enemy's id → *ignored* by the stub referee (id not in the list); hp unchanged.
- **AC-18 [Unit] (F3 validator):** `test_enemy_data` fails a definition with `spine_half` 30, k 2, `r_e` 18 (spacing 60 > 30); passes the bomber (30 ≤ 30) and the gunner (16 ≤ 21).

### HP and plating (Rules 12–13, 22, F4, F5)

- **AC-19 [Unit] (spawn hp):** heavy bomber at N = 1, 2, 4 → 4,000 / 6,000 / 10,000; missile carrier at N = 3 → 10,000; flak gunner at N = 3 → 2,400, N = 4 → 3,000; scout at N = 1…4 → 20.
- **AC-20 [Unit] (hp frozen):** spawn at N = 1; a second player joins → hp unchanged.
- **AC-21 [Unit] (plating timeline):** bomber first targetable on tick 1,003 → published `mode = ARMOURED`, `armor_pct = 50` for ticks 1,003–1,122, `NORMAL` from 1,123; the `enemy_plating_ended` event is emitted once, on tick 1,123.
- **AC-22 [Integration] (plating with referee):** real `CollisionReferee`: bomber at 4,000 hp, 20-damage hit during plating → dealt 10, *hit*, `chain_hit` counted; after plating → dealt 20. During plating a 10,000-damage hit → hp 1, *hit* (not destroyed). On the first normal tick the same hit → *destroyed*.
- **AC-23 [Unit] (hp_after):** the manager sets `hp = hp_after` of the last result per id; two results on one tick (hp_after 40 then 10) → 10.

### Firing (Rules 17–21, F6)

- **AC-24 [Unit] (arm tick):** bomber tail gun, muzzle offset (0,14): `emitter_log` shows `start` on age 6 and not at age 5 (muzzle y 35.8 + 14 → 49.8 < 52; age 6 → 52.5).
- **AC-25 [Unit] (never off-screen):** a SINE enemy whose muzzle leaves the zone on the left at age 80 → `stop(owner_destroyed = false)` on that tick; the emitter is never started again even if it returns.
- **AC-26 [Unit] (retire rules):** a `Leaving` enemy with `fire_during_exit` false → every emitter retired on the tick `Leaving` becomes true; with `fire_during_exit` true → retired only when the muzzle leaves the zone. `fire_end` 200 → retired at age 200.
- **AC-27 [Unit] (intensity sources):** `CONSTANT(0.5)` → every tick 0.5. `WAVE` with `wave_intensity` 0.75 → 0.75 for life even if the stub changes it later. `AGE_RAMP(60)` → 0 at the arm tick, 0.5 at +30, 1 at +60 and after.
- **AC-28 [Unit] (muzzle origin):** `facing = π/2` → origin = p + muzzle_offset; `facing = 0` (AIM enemy) with offset (0,14) → `f = −π/2`, `R(f)·(0,14)` = (14, 0) → origin = p + (14, 0). Test asserts the stated rotation convention (x' = x cos f − y sin f, y' = x sin f + y cos f with `f = facing − π/2`).
- **AC-29 [Unit] (tell):** MEDIUM/LARGE emit `enemy_tell(id, 12)` when `next_volley_in` first equals 12 and not again until the next volley; SMALL emit none.
- **AC-30 [Unit] (facing):** facing π/2, nearest player due right → 1.5208 after one tick, 1.0708 after 10; never changes by more than `turn_rate`. Two players at equal distance → the lower slot. No Active player → π/2 (AIM/DOWN).
- **AC-31 [Unit] (fire hold):** with the stub library skipping volleys, `start`/`stop` calls and origins are identical to a run without the hold.

### Death and despawn (Rules 14–16)

- **AC-32 [Unit] (death order):** a *destroyed* result for a carrier MEDIUM at (200,300) from slot 1 → `emitter_log` stop(owner_destroyed = true) for every emitter, then `enemy_destroyed(..., kill_class MEDIUM, killer 1, carrier true)`, then `request_cancel(circle (200,300) R 40, cause 1)`, then `drop_requested`, in that order; the next publication omits it; its generation is +1.
- **AC-33 [Unit] (cancel by class):** SMALL kill → no cancel request. MEDIUM → R 40. LARGE → R 72.
- **AC-34 [Integration] (cancel with real field):** real `BulletField`, orbs at 44 px and 45 px from a MEDIUM kill → the 44 px orb becomes a score item credited to the killer; the 45 px orb survives. LARGE: 76 px cancelled, 77 px survives.
- **AC-35 [Unit] (single death):** two *destroyed* results for one id on one tick (a manager bug) → one `enemy_destroyed`, one cancel request.
- **AC-36 [Unit] (stale id):** after a kill, a result with the old generation → ignored; the recycled slot's new enemy is untouched.
- **AC-37 [Unit] (carrier drop):** non-carrier kill → no `drop_requested`. Carrier killed → exactly one. Carrier that escapes → none and `enemy_escaped(carrier = true)`.
- **AC-38 [Unit] (escape):** an enemy seen at age 20 and 17 px outside the field → `enemy_escaped`, no `kill_credit`, no explosion; at 15 px → still alive. Never seen → not despawned by distance.
- **AC-39 [Unit] (max life):** at `age = max_life_ticks` an air enemy gets a forced exit: position = `pos(max_life) + (0, −2.5) × τ`, `Leaving` true, emitters retired; `force_exit(id)` does the same at any age. `GROUND` enemies are not force-exited.
- **AC-40 [Unit] (despawn_all):** with 10 alive including a lit-fuse flak gunner → all removed, no `enemy_destroyed`, every emitter stopped with `owner_destroyed = true`, counters show 0 alive.

### Validators and data (F8, F9)

- **AC-41 [Unit] (F8 exposure):** heavy bomber → plating dealt 800, `ttk` 360, required 504, exposure 573 → pass. Missile carrier → ttk 435, required 609, exposure 633 → pass. A bomber with hover 300 → exposure 453 < 504 → fail.
- **AC-42 [Unit] (F9 density):** `N_def` for each of the six armed definitions equals the table (7.0, 21.3, 26.5, 4.8, 8.9, 29.2 ±0.1) and is under the class ceiling.
- **AC-43 [Unit] (library validator):** every pattern used by an enemy definition passes the Pattern library F8 checks (fan lane, flak ring lane at standoff 56, wall corridor, lock rules).
- **AC-44 [Unit] (armour lint):** every `plating_armor_pct` is a whole number; plated definitions are LARGE only; any player damage source in `data/` that can reach a LARGE enemy is ≥ 20 (shares Collision AC-33; blocked until Kits data exists).
- **AC-45 [Unit] (class lint):** SMALL has `r_e` 7–9 and 1 hurtbox; MEDIUM 12 and 2; LARGE 18 and 3; `kill_class` ≠ size class gives a warning.

### Determinism and integration

- **AC-46 [Unit] (determinism):** a 1,800-tick scenario (12 spawns across all six definitions, 4 players moving, 3 kills, 2 escapes, 1 forced exit), run twice with the same seed → `state_hash()` equal every tick. Different spawn order → identical emitter seeds (stable ids, *(2026-11-03, ADR-0003)*); only positions and timing differ.
- **AC-47 [Integration] (bullet manager):** real `BulletField`: a 20-damage player bullet at the middle hurtbox of the bomber reports `(target, shooter, 20)` once; a bullet crossing two circles reports once.
- **AC-48 [Integration] (referee, kill credit):** MEDIUM destroyed by slot 2 → `kill_credit(2, MEDIUM)` and Scoring stub +1,000; SMALL +200; LARGE +5,000. The ground gunner's body never produces a death for a player standing on it.
- **AC-49 [Integration] (spawn_is_clear):** every scripted spawn in a 1P and a 4P run passes Collision's helper; a spawn 20 px from an Active player is retried.

### Visual / Audio (Manual, evidence in `production/qa/evidence/enemy-and-ai/`)

- **AC-50 [Manual] (V1 grayscale):** a screenshot with 20 enemies and 400 bullets in grayscale: every bullet is readable, enemies are darker than any plane, no enemy sprite covers a bullet.
- **AC-51 [Manual] (V3 explosions):** recorded kills: SMALL burst 20 px / 12 ticks, MEDIUM 40 px / 18 ticks, LARGE 72 px with 2 secondary pops at +8 and +16, none above layer 8. 24 simultaneous SMALL kills never exceed the 150-particle cap.
- **AC-52 [Manual] (V2 carrier):** the carrier's cream rim pulses at 2 Hz and never above 3 Hz; it is distinguishable from a normal enemy in a grayscale capture.
- **AC-53 [Manual] (V2 tell/plating):** the bomber's plating falls over 8 ticks on the tick the first wall volley's tell completes; the hatch opens 12 ticks before each volley.
- **AC-54 [Manual] (A1 audio):** 6 kills in 10 ticks → at most 1 SMALL pop per 3 ticks; a LARGE boom is audible over three SMALL pops.
- **AC-55 [Manual] (feel, playtest):** 5 players play stage 1 solo and in 2P; at least 4 can say what a gunner's flak and a bomber's wall do before dying to them twice; chain drops attributed to "enemies left before I could hit them" are under 1 in 5 drops.

### Performance

- **AC-56 [Perf] (tick):** `enemy_bench.tscn`: 28 enemies (16 SMALL, 8 MEDIUM, 4 LARGE; 32 hurtboxes) → `tick()` plus `apply_results()` ≤ 0.2 ms p99 on REF-PC and REF-WEB (excluding the Pattern library runners).
- **AC-57 [Perf] (budget):** `bullet_bench.tscn` + 256 collision bodies + the enemy bench → BM + collision + enemy ≤ 3.2 ms p99 and BM AC-39/40/41 still pass.
- **AC-58 [Perf] (allocation):** 10 minutes of spawns and kills → no per-tick allocations in `tick()` (reused buffers); memory growth < 0.5 MB.

> Criteria drafted by `game-designer` under auto-approve; `qa-lead` not consulted. The Bullet manager's and Collision's numbers are taken from their GDDs.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | `ref_dps` 800 is now the Kits-owned reference (2 drones, competent landing, on target; Kits "Reference DPS for content budgets"). A 0-drone player (about 570-590 dps) takes about 1.4x the TTK targets; a 4-drone player (about 1,100) about 0.73x. Landing factors are unplaytested. Plated large enemies force every player damage source to ≥ 20 (Collision lint). | Plane kits (11) | First playtest |
| 2 | Ground targets are non-lethal (`lethal = false`, Collision amendment 2). Confirm this matches the user's "every body kills" intent; the alternative keeps ground targets lethal. | Designer / Collision | Review |
| 3 | ~~Kill-cancel pockets (40/72 px) create chain-scaled score items (up to 11 × 100 per bullet). Check against `items_per_cancel_cap` and the Scoring balance; reduce radii or exclude kill cancels from the chain factor if farmable.~~ **Closed 2026-11-03:** kill-cancel items use `items_per_cancel_cap` 100 with no value reduction; worst case about 1 % of an expert stage (Powerups (13) F9). | Powerups (13), Scoring (8) | Powerups GDD |
| 4 | ~~Co-op density: should the Wave director add more SMALL enemies in 3–4P (small hp is not scaled), and does `coop_hp_step` 50 (Co-op (18)) keep medium/large chain bridges the same length in 4P?~~ **Closed 2026-11-03:** the Director owns co-op SMALL scaling (`group_size` via `spawn_pct(N)`, read once per group; per-wave `coop_spawn_cap`); bridge length stays a playtest check. (wave-and-stage-director.md) | Wave director (16), Co-op (18) | 2P/4P playtest |
| 5 | ~~Stage scroll speed for `GROUND` targets (`scroll_v`) comes from where? Proposal: Wave director passes it at spawn; Parallax (23) reads the same value.~~ **Closed 2026-11-03:** ground targets follow the live integer scroll `S` (1/100 px) from the Director's `ScrollClock`; `ground_dy = (S div 100) - (S_spawn div 100)` (parallax-and-environment.md F4) | Wave (16), Parallax (23) | Wave GDD |
| 6 | ~~Carrier cadence: players need 4 powerups to reach 4 drones. Provisional proposal: ≥ 1 carrier per wave (5 per stage) and one guaranteed after a death. Powerups owns the rules and pity.~~ **Closed 2026-11-03:** carrier cadence is 8 per stage (4 SMALL, 2 MEDIUM, 2 LARGE), at least one per wave (Wave director contract); the recovery pod after a death is owned by Powerups (Rule 7). The carrier cue (cream pulse) stays as is. (Powerups (13)) | Powerups (13), Wave (16) | Powerups GDD |
| 7 | Pattern parameters in F9 pass the library's formulas but the validator has not run on real `.tres` data; wave intensity mapping `(wave − 1) / 4` is a proposal. | Programmer, Wave (16) | First implementation story |
| 8 | `next_volley_in(emitter)` is a new Pattern library API (amendment 1). If rejected, tells need a fixed animation loop that is not synced to volleys. | Pattern library (9) | Review |
| 9 | ~~Boss (14) shares `EmitterDef`, the arming rule and body helpers. Confirm bosses are exempt from the fire-zone rule (boss entry is long; parts may start off-screen).~~ **Closed 2026-11-03:** bosses are exempt from fire-zone arming; emitters start at `boss_started` and a placement lint replaces the rule (Boss (14)). | Boss (14) | Boss GDD |
| 10 | HUD-strip clipping of enemy sprites: who clips enemies at `play_top` (Display scaler (4) / HUD (20))? | Display scaler (4), HUD (20) | Those GDDs |
| 11 | Art bible amendments: carrier rim pulse, plating overlay, explosion sizes per class, tell pose lead of 12 ticks. | Art director | Before enemy art |
| 12 | 2030s and 2100 enemies (drones, shields, rewinding) may need behaviours beyond scripted paths (shield timing, drone formation transforms). Does "scripted, not reactive" still hold? **Partly answered 2026-11-03:** the 2030s/2100 role stubs are scripted; shields and lasers stay open in Era shift Open Question 4 (era-shift-and-plane-evolution.md). | Era shift (19) | Target tier |
| 13 | Code: there is no enemy code in `src/`. Boss code (`boss_part.gd`, `boss_part_definition.gd`) uses float hp, `_process`-style timing and global `randf()`; it must migrate to integer hp, capsule bodies and ticks. Also `.claude/rules/gameplay-code.md` says "use delta", which conflicts with ADR-0001 ("no `delta` in logic"); this GDD follows the ADR. | Programmer / user | First implementation story |
| 14 | ~~Should `enemy_escaped` feed the tally as a kill ratio? It is emitted but unused in MVP.~~ **Closed 2026-11-03:** no kill ratio in MVP; the event stays for telemetry. (stage-end-tally.md) | Tally (21) | Tally GDD |

> Decisions in this GDD were made by Claude under the user's auto-approve instruction (recommended options taken); all are open to user change.
