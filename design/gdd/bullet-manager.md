# Bullet Manager

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + Claude
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (primary), Every Hit Counts (bullet cancels feed the chain)

## Overview

The Bullet Manager owns **every enemy bullet on screen**: spawning, moving, ageing, removing and drawing them. It also answers the one question the rest of the game keeps asking: *"is anything touching this point?"*

**The data layer:** bullets are not individual game objects. They are entries in one shared pool, built to keep **about 2000 bullets at 60 fps** in 4-player co-op on PC, Web and phones. Each bullet has a position, velocity, age, a **shape** from the fixed art-bible vocabulary (orb, rice, needle, ring), and a **behaviour** (straight, accelerating, curving, warping) that era patterns combine to create their bullet language. Patterns, bosses and enemies only *request* bullets. They never own them. Bombs, boss-part kills and later plane abilities can **cancel** bullets in an area.

**The player impact:** this system is what makes **Readable Chaos** possible. Every bullet uses the same few shapes and the same cool, outlined colours in every era, so dodging skill transfers from 1941 to 2100. Hits are judged against a small, honest hitbox, so a death is always the player's fault. Bullets vanish in a satisfying sweep when a part dies or a bomb lands. Without it, the game couldn't show DoDonPachi-density curtains without slowdown, unfair hits or unreadable clutter.

> Implementation note (→ ADR, not GDD): language (official Godot 4.7 cannot export C# to Web — see `docs/engine-reference/godot/current-best-practices.md`) and rendering method (art bible §8: one MultiMesh atlas).

## Player Fantasy

**Both: the player fights these bullets directly, and the system underneath makes that fight fair.**

The anchor moment: **the screen is a wall of blue, and the player finds the gap.** A DoDonPachi-density curtain closes in, and a 2-pixel lane opens between two rings of orbs. The player slips the plane's tiny core through it while the chain counter keeps climbing. That is the bullet fantasy: *the impossible-looking curtain was readable all along, and you read it.*

It has four parts:

- **Threading the needle.** Curtains look overwhelming but are always solvable. Every bullet sits on a grid of meaning: an orb is aimed, rice streams, a needle is fast, a ring is slow and wide. The player learns to see lanes, not noise.
- **The sweep.** When a boss part dies or a bomb lands, a whole region of bullets **vanishes at once**. The pressure releases, and the screen briefly belongs to the player. It's the payoff for aggression (Every Hit Counts).
- **Reading the era.** The shapes never change. The *behaviour* does: 1941 orbs fly straight, 1970s rice accelerates, 2100 orbs freeze and re-aim. Each era asks "do you see the new trick?" (History Accelerates). What the player learned in 1941 still works in 2100. Only the question gets harder.
- **My fault, not the game's.** The hitbox is smaller than the plane. Bullets hit only when they visibly touch the core, and never through slowdown or hidden overlaps. After a death, the player thinks *"I went left too early"*, never *"that didn't touch me"*.

It serves **Readable Chaos**: *"The screen floods, but every bullet is readable and every death is the player's fault."* Under that pillar, a bullet that is spectacular but unclear is a bug.

> `creative-director` not consulted for this section (lean mode).

## Detailed Design

### Core Rules

**Pools**

1. The manager runs **two separate pools**:
   - **Enemy pool:** cap `enemy_cap` (default 2000). These bullets hit players.
   - **Player pool:** cap `player_cap` (default 600). Shots and drone bullets from all players; they hit enemies. **Fair share** *(added 2026-11-03, Co-op (18) Rule 11)*: while `N` ≥ 2, one slot may hold at most `floor(player_cap / N)` live player-pool bullets; further requests from that slot are refused and counted in `refused_player_share` (not `refused_player`). With `N` = 1 the slot may use the whole pool. `N` is the player count defined in Co-op Rule 1 (slots Alive, Dead or Continue).

   The pools never interact: bullets don't hit bullets.
2. Each bullet stores: position, previous position, velocity, **age in integer ticks**, **shape**, **behaviour**, a behaviour parameter, **heading `h`** (unit vector at spawn), **damage** (player pool; set by the requester, values owned by Plane kits (11)), **tag** (player pool; 0 plane shot, 1 drone, 2 charge shot/slug, 3 return bolt (bolt speed 18 px/tick); set by Plane kits (11) and Sentry/Breaker kits (29), added 2026-11-03) and **owner**. For enemy bullets the owner is the target slot (0–3); for player bullets it is the shooter's slot (0–3).
3. **Shapes** are fixed by the art bible (§3.3, §4.3–4.4):
   - Enemy: **orb, rice, needle, ring**.
   - Player: **streak, diamond**. They are warm, and never use the enemy shapes.

   Shape sets the look and the hit radius. Shape never changes behaviour.
4. **Behaviours** (enemy pool):
   - **Straight**
   - **Accelerate:** speeds up to a cap.
   - **Curve:** turns at a fixed rate.
   - **Warp:** flies, freezes, then re-aims at its **target slot's** current position.

   The player pool uses Straight only in MVP. Laser beams are *not* bullets; Plane kits (11) own them.
5. **Spawning:** patterns, enemies, bosses and plane kits *request* bullets (position, velocity, shape, behaviour, parameter, owner). The manager owns them from then on. Requesters keep no references. **Invalid requests** (an enemy-pool request with a player shape or vice versa, a non-Straight behaviour in the player pool, an owner outside 0–3) are refused and counted in a separate `invalid_requests` counter, not the pool-full counter.
6. **Pool full:** if a pool is at its cap, a new request is **refused**. Bullets already on screen are never deleted to make room, so a visible bullet never pops out of existence. Every refusal is counted for profiling.

**Movement and removal**

7. Every bullet updates once per fixed gameplay tick (60 Hz). **Order within a tick:** (1) apply spawn requests → (2) age += 1 → (3) move → (4) cancels, in the order they were requested (FIFO) → (5) hit tests → (6) removal. Requests made between ticks are consumed by the next tick. Because cancels run before hits, **a cancel beats a hit on the same tick** (a last-moment bomb saves the player).
8. A bullet is removed when it leaves the play area (360x640, top bound `play_top` below the HUD strip — V5) by more than `offscreen_margin`, when it passes `lifetime`, when it hits, or when it is cancelled.

**Hits**

9. Every bullet hits as a **small circle at its centre** (including rings: a small solid circle), with a hit radius per shape that is deliberately smaller than the sprite (F5). The test runs along the path the bullet travelled this tick (swept test, F6), so fast bullets can't skip past a hitbox.
10. **Enemy bullet → player:** a hit happens when the bullet circle overlaps a player's **hitbox** (owned by Player plane (5)). Players who are invulnerable or Selecting are skipped. A hitting enemy bullet is removed. The manager reports `(slot)` hit; Collision and lives (6) decides the outcome. **The bullet manager owns both hit tests and the broad-phase grid (F11)**; Collision only receives hit reports.
11. **Player bullet → enemy:** a hit happens when the bullet circle overlaps an enemy, boss part or boss core **hurtbox**. The bullet is removed and the manager reports `(target, shooter slot, damage, tag)` (`tag` added 2026-11-03 for Plane kits (11): only tag 0 fills the Lancer meter). Collision (6) applies damage and the chain counts the hit for that shooter. Several hurtbox circles may share one `(id, gen)` (multi-circle enemies, Enemy (10) F3); a bullet still hits once. The 40-hurtbox reference scene is 32 enemy + 8 boss (Enemy (10) F9b).
12. Hits are judged after movement and cancels, in the same tick. The hit test runs every tick regardless of frame rate, so slowdown never gives a free pass.

**Cancelling**

13. A cancel request gives an **area** (circle, axis-aligned rectangle `(x0, y0, x1, y1)`, or the whole screen), a **cause slot** (the player whose part kill, bomb or Critical Break caused it) and a flag **`items`** (default true; rectangle and `items` added 2026-11-03, Bombs (12)). **Only the enemy pool** is cancelled. With `items = false` each bullet is removed with reason CANCEL_NOITEM and gives no score item. *(2026-11-03, wave 4, Sentry/Breaker (29))* **Kit cancels:** a plane kit may issue circle cancels with `items = false` (Breaker Erase Net; at most 2 per slot per tick) tagged with a `request_id`; the kit reads its own entries of the per-tick `cancel_report[]` (below) at the start of the next tick. **One cancel report (merged 2026-11-03, consistency check; replaces the separate VFX-facing and kit-facing reports):** each manager tick publishes exactly one `cancel_report[]` with one entry per cancel request processed that tick, in request order: `(request_id, cause_slot, area, items, count, positions_in_pool_order[])`. `count` = bullets actually removed by that request after FIFO de-duplication (a bullet removed by an earlier request in the same tick is not counted again); `request_id` is the requester's id (kits) or a manager-assigned id (bombs, part kills, Critical Break; the death clear is not a cancel and stays in `clear_report`). Readers: VFX (25) reads every entry the same tick (rings, puffs); Powerups (13) reads the `items = true` entries (Rule 14); plane kits (11, 29) read their entries (matched on `cause_slot` + `request_id`) at the start of their next tick. The report is deterministic; there is no second report.
14. Every cancelled bullet in an **items-cancel** (`items = true`) is handed to Powerups and drops (13) with its position and the cause slot; Powerups keeps up to `items_per_cancel_cap` (100) **gems**, stride-sampled, and owns them (auto-fly, value, pickup). No-items cancels (`items = false`, CANCEL_NOITEM) give none; kit net cancels (Rule 13) are outside `items_per_cancel_cap` because they give no items (Sentry/Breaker 29). *(Reworded 2026-11-03.)* *(2026-11-03, Powerups (13) F3)* The hand-off is the `items = true` entries of the per-tick `cancel_report[]` (Rule 13): the cancelled bullets **in pool-index order plus their count**; Powerups does the stride sampling down to `items_per_cancel_cap` (100) gems, so the manager never samples.
15. A cancel takes effect on the next tick after it is requested (requesters call before the manager ticks), so in practice the same frame. No bullet in the area survives that tick.
15a. **Enemy-pool clear (no items)** *(added 2026-11-02, Collision GDD)*: when a player dies, Collision (6) requests a clear of the **whole enemy pool** with **no score items**. It runs at the end of that tick, after cancels and the hit pass, and removes every enemy bullet including those spawned that tick (removal reason CLEAR). Player bullets are kept. Cancels on the same tick still give their items first.

**Co-op targeting**

16. Aimed patterns pick a **target slot** when firing (rule owned by the Pattern library (9): per-emitter rotation between Alive players, F4; rotation confirmed by Co-op (18) for MVP). Each bullet stores it.
17. A Warp bullet re-aims at its target slot's **current** position. If that slot isn't Alive at re-aim time, it re-aims at the **nearest Alive player** (Selecting counts as not Alive; equal distance → lowest slot index). If no one is alive, it flies on its **stored heading `h`** (saved at spawn, since a frozen bullet has no velocity).

### States and Transitions

The manager itself has no modes. Each bullet has a short lifecycle:

| State | → Next | Trigger |
|---|---|---|
| Requested | Active / Refused | pool has room / pool full |
| Active | Removed | off-screen, lifetime, hit |
| Active | Cancelled → score item | cancel area covers it (enemy pool only) |
| Warp: Flying | Frozen | age > `warp_freeze_at` |
| Warp: Frozen | Re-aimed | age > `warp_reaim_at` |

**Clear-all** (stage end, run reset) removes both pools at once **without** making score items.

### Interactions with Other Systems

| System | Gives to the bullet manager | Gets from the bullet manager |
|---|---|---|
| Game events and session (1) | slot states (Alive / Selecting) | — |
| Player plane (5) | hitbox position and radius per slot | — |
| Collision, damage and lives (6) | enemy hurtboxes; hittable flag per slot; enemy-pool clear (no items) request | player hit `(slot)`; enemy hit `(target, shooter, damage)` |
| Chain tracker (7) | — | (through Collision) hit attributed to shooter slot |
| Pattern library (9), Enemy (10), Boss (14) | spawn requests with target slot | — |
| Plane kits (11) | player shot and drone bullet requests | — |
| Bombs (12), Boss (14) part kills, Critical Break (17), Enemy (10) MEDIUM/LARGE kills (circle 40 / 72 px, cause = killer) | cancel requests (area + cause slot + `items`). Bombs: full screen with items on the press tick; rectangles / circles without items afterwards. Boss: part kill circle 90 px, last part 150 px, boss death whole screen (cause = killer); TIMEOUT uses the Rule 15a enemy-pool clear without items | — |
| Powerups and drops (13) | — | cancelled positions + cause slot → score items |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | `clear_all()` at E5+60 (field clear before the WARNING) and at `stage_cleared` | — |
| VFX (25) — [GDD](vfx-and-screen-feedback.md) | — | reads every entry of the per-tick `cancel_report[]` `(request_id, cause_slot, area, items, count, positions_in_pool_order)` (Rule 13; one merged report, 2026-11-03) and `clear_report` each tick *(2026-11-03, wave 3b)* |
| Audio (24) — [GDD](audio.md) | — | per-tick counters (`spawned`, `cancelled`, `warp_reaims`) for rate-gated sounds |

All listed systems now have GDDs *(2026-11-03, wave 3b)*; the contracts above match them.

> Specialist agents not consulted for this section (lean mode).

## Formulas

Assumptions: canvas 360x640, `dt = 1/60` s (Rule 7), player hitbox radius 3.0 (owned by Player plane (5)), player move speed 210 px/s, focus 105 px/s (owned by Player plane (5), PF1).

**F0. Canvas retune**

`speed_new = speed_old × k_speed`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Old speed | `speed_old` | float px/s | 0–600 | Prototype value (480x640 canvas) |
| Speed scale | `k_speed` | float | 0.75–1.0 (default 1.0) | Global retune factor |

**Output Range:** 0 to `v_cap_global`. Canvas height is unchanged (640), so time-to-reach-the-player is unchanged. The narrower width (×0.75) is compensated in the Pattern library (its F10 migration: fan spread ×0.75, wall count ×0.75 with spacing kept, angular patterns unchanged; amended 2026-11-03), not by slowing bullets.
**Application:** applied at spawn to every enemy speed (including `warp_speed` and Accelerate `v_cap`), before the `v_min` / `v_cap_global` clamp, with no rounding. Not applied to the player pool.
**Example:** `warp_speed` 190 stays 190 (with `k_speed` 0.875 it would be 166.25).
**Resolved by Player plane (5):** move speed is 210 px/s (0.75 × 280), so crossing the 360 px width takes 1.71 s, the same as before.

**F1. Straight**

`p' = p + v · dt`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Position | `p` | Vector2 px | play area ± margin | Bullet centre |
| Velocity | `v` | Vector2 px/s | enemy 70–480; player ≤ 1200 | Clamped at spawn |

**Output Range:** moves until removed by F8. **Example:** `p = (100, 50)`, `v = (0, 150)` → `(100, 52.5)`; after 60 ticks `(100, 200)`.

**F2. Accelerate**

`g = 1 + accel_rate · dt`; `|v'| = max(|v|, min(|v| · g, v_cap))`, direction unchanged; then `p' = p + v' · dt`.  
*(2026-11-03, ADR-0003)*: implemented as this per-tick multiply only (`g` computed once at spawn); no `exp`/`pow`/`ln` in the simulation. The "ticks to cap" expression below is design analysis, not runtime code.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Accel rate | `accel_rate` | float 1/s | 0.5–4.0 (default 1.6) | Near-exponential growth |
| Speed cap | `v_cap` | float px/s | 100–480 (default 330) | Per-bullet ceiling |

**Output Range:** speed in `[|v_spawn|, max(v_cap, |v_spawn|)]`, never decreasing (fixes the prototype, which snapped a bullet spawned above the cap down to it). Ticks to cap: `ceil(ln(v_cap / v0) / ln(g))`.
**Example:** `v0 = 120`, `v_cap = 330` → 39 ticks (0.65 s).

**F3. Curve**

`v' = rotate(v, ω · dt)`; then `p' = p + v' · dt`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Spin | `ω` | float rad/s | −3.0 to 3.0 | Behaviour parameter; + is clockwise on screen |
| Turn radius | `r_turn` | float px | ≥ 50 | `|v| / |ω|` |

**Output Range:** speed preserved. A curving bullet can orbit indefinitely; lifetime (F8) ends it.
**Example:** `v = (0, 150)`, `ω = 1.5` → turn 0.025 rad per tick, `r_turn = 100` px.

**F4. Warp** (integer tick age `a`, incremented first)

- `a ≤ T1` → flying, `v = v0`
- `T1 < a ≤ T2` → frozen, `v = 0`
- first tick with `a > T2` → `v = warp_speed × unit(target − p)`; if `|target − p| < 1` → `v = warp_speed × h`

`T1 = round(warp_freeze_at / dt)`, `T2 = round(warp_reaim_at / dt)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Freeze tick | `T1` | int | 12–120 (default 42 = 0.7 s) | |
| Re-aim tick | `T2` | int | T1+6 to 180 (default 66 = 1.1 s) | |
| Warp speed | `warp_speed` | float px/s | 100–480 (default 190) | |
| Target | `target` | Vector2 | play area | Rule 17: stored slot → nearest Alive → none |
| Stored heading | `h` | unit Vector2 | | Saved at spawn; used when there is no target |

**Output Range:** after re-aim, `|v| = warp_speed` exactly. Frozen window 0.4 s. Integer ticks, not float age, so stages never drift by a tick.
**Example:** frozen at `(100, 155)`; target `(180, 500)` → `v = (42.9, 185.1)`.

**F5. Hit test (circle)**

`hit = |p_b − p_t|² ≤ (r_b + r_t)²`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Bullet centre | `p_b` | Vector2 px | | After this tick's move |
| Target centre | `p_t` | Vector2 px | | Player hitbox or enemy hurtbox |
| Bullet hit radius | `r_b` | float px | 1.0–4.0 | Per shape (table) |
| Target radius | `r_t` | float px | 1–60 | Player 3.0; hurtboxes owned by Enemy (10) / Boss (14) |

| Shape | Sprite | `r_b` | Combined with player (3.0) |
|---|---|---|---|
| Orb | 9 px | 2.5 | 5.5 |
| Rice | 4×9 | 1.5 | 4.5 |
| Needle | 3×12 | 1.25 | 4.25 |
| Ring (hollow) | 16 px | 2.0 (solid circle at centre) | 5.0 |
| Streak (player) | ~3×14 | 3.0 (placeholder) | — |
| Diamond (player) | ~7×7 | 4.0 (placeholder) | — |

Enemy radii are deliberately smaller than the sprite (an orb visibly touches the core at 7.5 px but hits at 5.5 px — 2 px of forgiveness). Player-bullet radii are generous so a visible touch always hits. Floor `r_b ≥ 1.0`.
**Output Range:** bool. **Example:** orb at `(100, 200)`, core at `(104, 203)`: d² = 25 ≤ 30.25 → hit. Core at `(105, 203)`: d² = 34 > 30.25 → miss.

**F6. Swept test** (used for every bullet)

`q0 = p_b(T) − (p_t(T) − p_t(T+1))`, `q1 = p_b(T+1)`, `hit = dist(p_t(T+1), segment q0→q1) ≤ R`, with `R = r_b + r_t`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Bullet previous / current | `p_b(T)`, `p_b(T+1)` | Vector2 px | | |
| Target previous / current | `p_t(T)`, `p_t(T+1)` | Vector2 px | | Player plane / Enemy supply both |
| Combined radius | `R` | float px | 3.5–70 | From F5 |

**Output Range:** bool; exact at any speed. A bounding-box precheck runs first.
**Example:** needle moving 8 px in one tick from `(100, 196)` to `(100, 204)`, static core at `(103.5, 200)`, `R = 4.25`: both endpoints are 5.3 px away (a point test misses), but the closest point on the path is 3.5 ≤ 4.25 → **hit**.
**Rules:** on respawn, the player's previous position is set to its new position (no sweep across the teleport). A player is only swept on ticks where they were hittable at both ends.

**F7. Readability cap**

`v_cap_global = 480 px/s` (8 px per tick) for enemy bullets; player pool cap 1200 px/s.
Kept for readability and authoring, not for correctness (F6 is exact). Without F6, point-test caps would be orb 450, rice 330, needle 300, ring 390 px/s with the player moving at 210 — needles would lose their "very fast" identity.

**F8. Removal**

`remove = out_x OR out_y OR (a > lifetime_ticks)`, with `lifetime_ticks = round(lifetime / dt)` (integer, 720 at 12 s)
`out_x = (x < −m AND vx ≤ 0) OR (x > W + m AND vx ≥ 0)`; `out_y` likewise with `H`, `vy`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Play size | `W`, `H` | int px | 360, 640 | |
| Play top | `play_top` | int px | 48 (1–2P), 72 (3–4P) | Top of the play field below the opaque HUD strip (AB §7.2); used instead of 0 for the top bound and the F9 item clamp. Latched value: changes only at `stage_started` / `wave_started` (Co-op Rule 2, 2026-11-03) |
| Margin | `m` | float px | 12–40 (default 20) | ≥ 2 × largest sprite half-extent (ring 8) |
| Min speed | `v_min` | float px/s | 50–100 (default 70) | Spawn clamp |
| Lifetime | `lifetime` | float s | 8–20 (default 12) | Safety net |

**Output Range:** bool; no bullet inside `[−m, W+m] × [−m, H+m]` is removed for position. The direction check keeps bullets spawned in the margin and curving bullets that re-enter. Lifetime floor: `L_path / v_min = √(400² + 680²) / 70 = 11.3 s ≤ 12 s` (the prototype's 10 s killed slow bullets).

**F9. Cancel**

Circle: `cancel_i = |p_i − c|² ≤ (R_c + r_vis)²`. Rectangle (centre `(cx, cy)`, half sizes `half_w`, `half_h`; added 2026-11-03, Bombs (12)): `cancel_i = |px − cx| ≤ half_w + r_vis AND |py − cy| ≤ half_h + r_vis`. Full screen: every enemy bullet. Output: one score item per cancelled bullet, at `clamp(p_i, play_area shrunk by item_inset)`, credited to `cause_slot`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cancel centre / radius | `c`, `R_c` | Vector2, float px | `R_c` 0–800 | From Bombs (12), Boss (14), Critical Break (17) |
| Rectangle half sizes | `half_w`, `half_h` | float px | 0–360 | From Bombs (12) (Lancer column `half_w` 28) |
| Sprite half-extent | `r_vis` | float px | orb 4.5, rice 4.5, needle 6, ring 8 | Anything that *looks* touched vanishes |
| Item inset | `item_inset` | float px | 4–16 (default 8) | Keeps items collectable |
| Cause slot | `cause_slot` | int | 0–3 | |

**Output Range:** 0–2000 items. Runs after this tick's spawns and movement.
**Example:** bomb at `(180, 320)`, `R_c = 120`: orb at 124 px cancelled, orb at 125 px survives. Full-screen cancel with 1,350 bullets → 1,350 cancelled positions handed over (Powerups (13) F3 keeps 97 gems). Bomb column rectangle centre x 180, `half_w` 28: an orb at x 212.5 is cancelled, at 212.51 it survives.

**F10. Capacity**

`accepted = min(requested, cap − active)`, `refused = requested − accepted`; steady state `N ≈ request_rate × time_on_screen`.

Player pool with `N_p` ≥ 2 players (Co-op Rule 1): `accepted = min(requested, cap − active, floor(player_cap / N_p) − active_slot)`; the part refused only by the share is counted in `refused_player_share`. *(Added 2026-11-03, Co-op (18) Rule 11.)*

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cap | `cap` | int | enemy 2000, player 600 | |
| Active | `active` | int | 0–cap | |
| Refused | `refused` | int | ≥ 0 | Profiled counter |
| Players | `N_p` | int | 1–4 | Co-op Rule 1 count (here `N_p`, since `N` above is steady-state bullets) |
| Slot active | `active_slot` | int | 0–cap | Live player-pool bullets owned by the requesting slot |

**Output Range:** active never exceeds cap; a batch is partly filled and the rest refused.
**Example:** average 150 px/s → about 4.5 s on screen → 2000 bullets needs 444 bullets/s. Content targets: peak ≤ 85% (1700), refusals < 0.1% — anything more is a pattern bug.

**F11. Cost budget**

Hit tests ≤ **1.5 ms per tick at the 99th percentile** (mean ≤ 1.0 ms); the **whole bullet update** (spawn, age, move, cancels, hits, removal) ≤ **2.5 ms per tick at p99**. Measured on reference machines REF-PC and REF-WEB named by the language ADR. **Phones:** gameplay ticks stay at 60 Hz; rendering may fall back to **30 fps**.

- Enemy bullets vs players (≤ 4): union-box precheck, then F6 on bullets near a player → about 1,000 tests instead of 8,000.
- Player bullets vs enemies: hurtboxes binned into a uniform grid (`cell_size` 32 px, 12 × 20 cells; performance only, never affects correctness); each bullet tests only hurtboxes in the cells its path overlaps → about 1,350 tests instead of 24,000.

**Estimate (unverified):** about 0.05 ms native, about 2.5 ms in GDScript. Language and rendering go to the ADR.

> Formulas proposed by `systems-designer`, decisions by the user (2026-11-02): ring = small solid circle, swept test + 480 cap, keep speeds and retune patterns, bullet manager owns hit testing.

## Edge Cases

**Spawning and capacity**

- **If a pool is full partway through a pattern's volley**, bullets spawn in request order until the cap is reached and the rest are refused. The pattern looks incomplete; this is a **pattern content bug** (F10 targets), not something fixed at runtime.
- **If a bullet spawns inside a player's hitbox**, it is hit-tested on its first tick (no grace period). The Pattern library (9) must keep spawn points clear of players.
- **If a bullet spawns in the off-screen margin moving inward**, it is kept (F8 direction check).
- **If a spawn request's speed is outside the allowed range**, it is clamped to 70–480 px/s (enemy) or ≤ 1200 (player). Speed 0 is clamped up to 70, except Warp while frozen.

**Hits**

- **If one enemy bullet touches two players on the same tick**, it is removed once and reports the lowest slot index. Collision (6) owns any fairer rule.
- **If one player bullet touches two hurtboxes**, it hits the one with the smaller entry point along its path (tie → lowest hurtbox registration index) and is removed (never hits twice).
- **If a player becomes hittable mid-tick** (invulnerability ends, or a pick is confirmed), the sweep only covers ticks where they were hittable at both ends. They can't be hit by the path they took while invulnerable.
- **If a player respawns**, their previous position is set to the new one, so the respawn jump is never swept.
- **If a hurtbox disappears** (a part dies) on the same tick bullets reach it, those bullets test against the hurtbox list from the **start** of the tick. Collision (6) decides the result: overkill hits on a target that died earlier that tick are *ignored* and **do not count** for the chain (Collision C5, C6).

**Behaviours**

- **If a Warp bullet's target slot is dead or out at re-aim**, it aims at the nearest Alive player; if none, it flies on its stored heading `h`.
- **If a Warp bullet is already on top of its target at re-aim** (distance < 1 px), it uses heading `h`.
- **If a Curve bullet circles inside the screen forever**, it is removed when its lifetime (12 s) ends.
- **If an Accelerate bullet spawns faster than its cap**, it keeps its spawn speed and never slows (F2).

**Cancelling**

- **If two cancels hit the same bullet on one tick** (e.g. a bomb and a part kill), it is cancelled once, credited to the **first** request processed that tick (cancels are processed in the order they were requested).
- **If a full-screen cancel catches bullets in the margin**, their score items are moved inside the play area (F9).
- **If a bullet spawns inside a cancel area on the same tick**, it is cancelled too (cancel runs after spawns).
- **If a bullet would hit a player on the same tick a cancel covers it**, the cancel wins: it becomes a score item and no hit is reported (Rule 7 order).
- **If a cancel's cause slot is no longer Alive**, items are still credited to that slot. Powerups (13) decides whether a Dead or Continue slot can collect them.
- **If a clear-all (stage end) happens**, both pools empty with **no** score items.

**Frame rate**

- **If the game drops below 60 fps**, the gameplay tick still runs at a fixed 1/60 s per step. The manager never uses variable `delta`, so behaviour and hits are identical at any frame rate.
- **If the game is paused**, the manager isn't ticked; bullets freeze in place.

> `systems-designer` not consulted separately for this section (lean mode); built from its Formulas-stage edge-case list.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) | Hard | Slot states (Alive / Selecting) decide who can be hit, together with the invulnerable flag from Collision (6). Not ticked while paused. |

**Runtime data providers** (designed after this system; they feed it data each tick through a registration interface this GDD defines):

- **Player plane (5):** registers each slot's hitbox (radius, current and previous position).
- **Enemy and AI (10), Boss (14):** register hurtboxes.

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Collision, damage and lives (6) | Hard | Receives player hits `(slot)` and enemy hits `(target, shooter, damage)`. Supplies the hittable flag per slot and the enemy-pool clear (no items) request (Rule 15a). |
| Bullet pattern library (9) | Hard | Spawn requests (shape, behaviour, parameter, target slot). Owns the targeting rule (per-emitter rotation, Pattern library F4) and the canvas migration (Pattern library F10). |
| Enemy and AI (10), Boss (14) | Hard | Spawn requests; hurtbox registration (several circles may share one `(id, gen)`; the 40-hurtbox reference scene = 32 enemy + 8 boss); part-kill cancels; Enemy (10) MEDIUM/LARGE kill cancels (circle 40 / 72 px, cause = killer). |
| Plane kits and drones (11) — GDD | Hard | Player shot and drone bullet requests with `tag` (0 shot, 1 drone), returned in hit reports. Read-only hurtbox queries for the laser and latch drones: `first_in_column(x, half_width, y_from)` and `nearest(pos, filter)` *(added 2026-11-03)*. At most 48 live bullets per slot. |
| Sentry, Breaker kits (29) — [GDD](plane-kits-sentry-breaker.md) | Hard (Target) | Tags 2 (charge shot/slug) and 3 (return bolt); Breaker net circle cancels with `items = false` (≤ 2 per slot per tick) and read their own entries of the per-tick `cancel_report[]` (Rule 13) next tick. Live bullets: Sentry ≤ 46, Breaker ≤ 40 per slot. *(2026-11-03, wave 4)* |
| Bombs (12) — GDD, Critical Break (17) — [GDD](critical-break.md) | Hard | Cancel requests (area + cause slot + `items`). Bombs: full screen with items at the press; rectangles / circles without items afterwards. Critical Break: `request_cancel(screen, cause_slot = breaker, items = true)` on the break tick (step 6b), and reads `enemy_bullet_count` to gate its banner (2026-11-03). Enemy (10) also requests kill cancels (row above). |
| Powerups and drops (13) — GDD | Hard | Receives cancelled positions (pool-index order) + count + cause slot → stride-sampled gems (cap 100). |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | Hard | `clear_all()` at E5+60 (with `despawn_all`, before the WARNING) and at `stage_cleared`. |
| Co-op and Team Chain (18) — GDD | Soft | Supplies `N` (Co-op Rule 1) for shot opacity (V3) and the player-pool fair share (Rule 1); reads `refused_player_share`. Relies on per-slot targeting (rotation confirmed by Co-op) and owner attribution. |
| VFX (25) — [GDD](vfx-and-screen-feedback.md) | Soft | `cancel_report` and `clear_report` each tick (vanish puffs, rings). |
| Audio (24) — [GDD](audio.md) | Soft | Per-tick counters; retrigger gap 3 ticks, BULLET pool 8 voices (Audio F2, Rule 7). |
| Accessibility options (28) — [GDD](accessibility-options.md) | Soft | `access.ally_shot_dim` for player-shot opacity (V3). |
| Era shift (19) | Soft | Eras select behaviours and patterns; shapes never change. |

**Bidirectional note:** Game events and session lists this system (fixed 2026-11-02). *(2026-11-03, wave 3b: every system above now has a GDD; each lists "Bullet manager" with the matching interface.)*

## Tuning Knobs

All live in data (e.g. `data/bullet_rules.tres`), not code.

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `enemy_cap` | 2000 | 800–3000 | Max curtain density, performance | Boss curtains get refused | Frame drops on Web/phones |
| `player_cap` | 600 | 200–1000 | 4P shot density | 4P shots refused | Performance cost |
| `player_share_enabled` (owned by Co-op (18)) | on (`N` ≥ 2) | on / off | Per-slot share `floor(player_cap / N)` | — | Off: slot 0 can starve slot 3 when the pool fills |
| `k_speed` | 1.0 | 0.75–1.0 | Global bullet speed | Too slow to threaten | — (1.0 is max) |
| `v_min` / `v_cap_global` | 70 / 480 | 50–100 / 360–600 | Slowest / fastest enemy bullet | Slow clutter / fast can't feel fast | — / unreadable needles |
| `accel_rate` / Accelerate `v_cap` | 1.6 / 330 | 0.5–4.0 / 100–480 | 1970s acceleration feel | Feels like Straight | Snaps to max, no tell |
| `warp_freeze_at` / `warp_reaim_at` / `warp_speed` | 0.7 / 1.1 / 190 | 0.2–2.0 / +0.1–3.0 / 100–480 | 2100 warp warning | No time to read the freeze | Warp feels sluggish |
| Hit radius orb / rice / needle / ring | 2.5 / 1.5 / 1.25 / 2.0 | 1.0–3.5 / 1.0–2.5 / 1.0–2.0 / 1.0–3.0 | Fairness vs danger | Bullets feel like ghosts | "That didn't touch me" deaths |
| Hit radius streak / diamond (player) | 3.0 / 4.0 | 2–5 | How easy player shots land | Visible shots miss | Shots hit through gaps |
| `offscreen_margin` | 20 px | 12–40 | Spawn lead-in, cull timing | Sprites pop at the edge | Wasted off-screen bullets |
| `lifetime` | 12 s | 8–20 | Safety net for orbiting bullets | Slow bullets die early (F8) | Stray curves linger |
| `item_inset` | 8 px | 4–16 | Cancel items collectable | Items at the very edge | Items bunch in the middle |
| `cell_size` | 32 px | 16–64 | **Performance only** | More grid work | More tests per cell |
| Occupancy warning | 90% (≥ 1800 active; logged once per crossing, debug builds) | 80–95% | Pattern authoring budget | False alarms | Warns too late |

**Knobs that interact:**

- Hit radii depend on the **player hitbox (3.0)** owned by Player plane (5). A smaller core (2.0–2.5 playtest option) shrinks every combined radius.
- `v_min` and `lifetime` must satisfy F8: `lifetime ≥ 11.3 s` at `v_min = 70`.
- `k_speed` works together with the Pattern library's canvas migration (Pattern library F10).

## Visual/Audio Requirements

> Source of truth: `design/art/art-bible.md` (AB). The Bullet Manager looks and sounds the way AB §3.3, §4.2–4.4 and §6.8 say; this section only adds manager-specific rules. Audio items are proposals for the **audio-director**. Numbers marked (P) are unplaytested.

**V1. Shared rendering rules**

- Two MultiMeshes: enemy bullets (draw layer 8) and player shots (layer 6, AB §6.8). Each has one atlas, one material, no additive blend (AB §8.6).
- Per-instance data is `custom = (frame, angle)`; player shots also use instance colour for alpha only. No per-bullet nodes, AnimationPlayer or SpriteFrames (AC-44). Instance count follows `enemy_active` / `player_active` each frame.
- Draw position is `round(sim position)` (integer pixels, AB §8.7); the hit test uses the unrounded position. No render interpolation: what is drawn is the tick the hit test used (AC-47).
- Each sprite's integer pivot lives in `data/`, never in the PNG (AB §8.7). The pivot is the visual centre and equals the hit-circle centre.
- **Angle comes from heading** (velocity direction); only the animation frame (if any) comes from age.

**V2. Enemy bullet sprites** (outline `#0B0B2A` on every shape; 24×24 atlas cells; no palette swap; same in every era)

| Shape | Sprite (px) | Fill / Core | Heading rotation | Frames |
|---|---|---|---|---|
| Orb | 9 | `#4A5CFF` / `#E8EEFF` | None (symmetric) | 1 |
| Rice | 4×9 | `#6A6CFF` / `#EEF0FF` | Pre-rotated, 16 angles at 22.5°, nearest to heading | 16 |
| Needle | 3×12 | `#9AA8FF` / `#FFFFFF` | As rice | 16 |
| Ring | 16 | `#5A4CFF` / `#E8E4FF` (inner edge) + **3 px solid core pip** `#E8E4FF` with Ink outline at the centre | None | 1 |

- **Ring core pip (decided 2026-11-02):** the ring hits only with a small solid circle at its centre (F5), so the centre pip makes the lethal spot visible. Amends AB §3.3 / §4.3.
- No bullet animation in MVP (AB §8.3 allows up to 4 frames).
- Curve updates the angle every tick. A frozen Warp keeps its flight heading; at re-aim the angle snaps with no easing.
- Fill hue stays inside 225–265° (AB §4.3). No glow, halo or trail on bullets (AB §4.2).

**V3. Player shot sprites** (AB §4.4, §8.3)

- Core `#FFF2B0`, fill `#FFB82E`, edge `#FF7A1A`; no dark outline. Streak ~3×14 (pre-rotated like rice), diamond ~7×7 (static) — placeholders (Open Q5); max 9×18, 2 frames, 4 colours.
- All players' shots look identical; co-op identity stays on the hitbox ring, pips and plane outline.
- **Opacity by player count (decided 2026-11-02):** 1P 100%, 2P 75%, 3–4P 50%, for all shots (player count `N` as defined in Co-op (18) Rule 1). AB §7.9's option to dim further is the accessibility setting `access.ally_shot_dim` 0 / 25 / 50: opacity = `max(25, (base(N) × (100 − dim) + 50) div 100)` with base 100 / 75 / 50 (Accessibility 28 F3) *(2026-11-03, wave 3b)*. Opacity never changes the hit radius.
- Player shots never use orb, rice or ring shapes, and are never blue or cool.

**V4. Behaviour tells** (shapes never change; no effect over bullets)

- Straight, Accelerate, Curve: no tell (speed change and turning sprite are the cue; trails are banned).
- Warp: the 0.4 s freeze and snap re-aim is the tell. Flash, glow, halo and overlay are banned. Playtest-gated option (art-director approval): a 2-frame core/fill swap during the frozen window only, inside the bullet's own cell, ≤ 2 Hz. Non-visual backup: one audio cue per volley (A2).

**V5. Draw order** (AB §6.8 layer numbers)

- Enemies (4) → air FX (5) → player shots and **score items** (6) → player planes (7) → **enemy bullets (8)** → hitbox dots and rings (9) → Critical Break frame (10) → HUD (11).
- Only hitbox dots/rings, the Critical Break frame and the opaque HUD strip may draw over enemy bullets. Drones, lasers, bomb FX, cancel puffs and shockwave, boss vignette, particles, planes and score items all draw below layer 8.
- **Hitbox dot drawn at true size (decided 2026-11-02):** the player's hitbox is drawn as the real 6 px core (radius 3.0), not a 1 px dot, so what you see is what hits (AC-47 "core" = the drawn dot). Amends AB §4.4; owned by Player plane (5).
- Banners (layer 11) appear only when the field is clear (AB §7.4).
- The HUD strip is opaque and outside the play field: bullets and items use `play_top` (48 px in 1–2P, 72 px in 3–4P) as the top of the play area (F8, F9). No clip rect. `play_top` is the latched value (changes only at `stage_started` / `wave_started`; Co-op Rule 2), never the HUD display mode.

**V6. Cancel sweep**

- A cancelled bullet leaves the MultiMesh on the cancel tick; its score item appears the same tick at the inset-clamped position (F9).
- **No ghosts:** a drawn enemy-bullet sprite is always lethal. Cancelled bullets never fade, shrink, flicker or tween — the vanish is instant (1 tick).
- Feedback comes from separate effects below layer 8: an area shockwave (≥ 36 px ring, no Ink outline, not bullet-shaped, expands over ~8–12 ticks) and small puffs (3–5 frames, gold/cream, no Indigo/Ink, era tint allowed), **sampled to at most ~40 per sweep** within the 150-particle cap (AB §8.6). *(2026-11-03, wave 3b)*: the puff live cap is **40 across all sweeps** together; a Critical Break cancel samples at most **12** puffs (VFX F3 `cancel_puff_sample`). Effects never draw over a surviving bullet.
- **Hand-off to Powerups and drops (13):** it owns item art, pop-in, value and auto-fly. Constraints: items must not read as bullets (the score item is a plain 7 px gold GEM diamond, Ember Gold `#FFC93C`; the `+` diamond is reserved for the CHAIN item; Powerups 13, AB §4.6, no cool hue, no Ink outline), must be instanced for 2,000 at once, draw on layer 6, and items clamped in from the margin may slide in rather than pop.
- Clear-all (stage end) removes bullets instantly with no FX and no items.

**V7. Era changes**

- **Never changes:** shapes, sizes, colours, hit radii, atlas, material, draw layer, cancel behaviour.
- **May change:** patterns, behaviour mix, speed, density (Pattern library 9, Era shift 19), and audio timbre (A1).
- The bullet atlas is in the always-loaded set (AB §8.6); eras don't reload it.

**V8. Performance as visual requirements** (AB §8.6, §8.9)

- One 512×512 atlas, 24×24 grid, 2 px gutter, extruded edges; one MultiMesh per pool, one material, no clip rects, no shader over the bullet layer. Bullets cost at most 2 draw calls.
- The 2,000-instance MultiMesh spike (AB §8.9) must hold 60 fps before bullet art is produced.
- Phones may render at 30 fps while ticking at 60 Hz; drawn positions are always the latest tick.
- Resizing a sprite means updating `r_vis` and the sprite column in `data/bullet_rules.tres`, and keeping `offscreen_margin` ≥ 2 × the largest half-extent.

**A1. Audio** (audio-director to confirm all numbers (P))

- The manager plays no per-bullet sound. It exposes per-tick counters (`spawned`, `cancelled`, `warp_reaims`) so audio/VFX never need per-bullet signals.
- Spawn sounds are triggered by the requester (Pattern library 9, Enemy 10, Boss 14, Plane kits 11), once per volley; retrigger gap ≥ 3 ticks (50 ms) per sound ID; refused requests are silent.
- Enemy fire: ≤ 4 concurrent voices, new starts over the cap dropped, except boss volleys may steal the oldest enemy-fire voice. Player fire (Plane kits 11): ≤ 1 voice per slot, per volley or loop, never per shot.
- No graze sound (no graze mechanic). Hit and death sounds are owned by Collision (6) and Player plane (5).
- Era flavour is allowed in spawn timbre; volley role and cue stay the same across eras.

**A2. Cancel and Warp cues**

- One cancel sound per cancel request, never per bullet; two tiers: small (part kill) and large (bomb). Critical Break keeps its own sound (AB §4.6). Several cancels in one tick play one sound, the first requested.
- Warp: at most one cue per volley at freeze and one at re-aim.
- **Voice cap:** bullet-related SFX (enemy fire, player fire, Warp cue, cancel) share ≤ 8 voices (P). Priority: cancel > Warp cue > enemy fire > player fire; lowest dropped first. Score item pickup chimes (Powerups 13) obey the same pool.

> Drafted by `art-director` from the art bible; decisions by the user (2026-11-02): hitbox dot drawn at true size, ring core pip, shot opacity by player count, `play_top` under the HUD strip.

📌 **Asset Spec** — run `/asset-spec system:bullet-manager` to produce per-sprite specs for the bullet atlas.

## UI Requirements

No player-facing UI. Debug-only: an occupancy / refusal readout (AC-42) and a hit-circle overlay (AC-47), both hidden in release builds. The visible hitbox dot is owned by Player plane (5) (V5).

## Acceptance Criteria

Defaults used: `enemy_cap` 2000, `player_cap` 600, `v_min` 70, `v_cap_global` 480, player cap 1200, Accelerate 1.6 / 330, Warp `T1` 42 / `T2` 66 / 190, `offscreen_margin` 20, `lifetime` 12 s (720 ticks), `item_inset` 8, `cell_size` 32, `k_speed` 1.0, occupancy warning ≥ 1800. Hit radii orb 2.5, rice 1.5, needle 1.25, ring 2.0, streak 3.0, diamond 4.0; player hitbox 3.0. Slots 0-indexed. Tests read every number from `data/bullet_rules.tres`, never literals.

**Test setup:** the logic lives in a plain `RefCounted` class (working name `BulletField`) with no nodes, no rendering and no `delta`; `tick()` advances exactly one 1/60 s step. Inputs injected before a tick: `request_spawn(...)` (returns accepted count, never a handle), `request_cancel(circle|rect|screen, cause_slot, items = true)` (FIFO), `set_targets(slots)` (state, hitbox position, previous position, radius, hittable), `set_hurtboxes(list)` (id, position, previous position, radius; several circles may share one id), `set_player_count(N)` (Co-op Rule 1). Outputs read after a tick: `enemy_active`, `player_active`, `refused_enemy`, `refused_player`, `refused_player_share`, `invalid_requests`, `peak_enemy_active`, `player_hits [(slot)]`, `enemy_hits [(target, shooter, damage)]`, `cancel_items [(pos, cause_slot)]`, per-bullet position/age/speed, removal-reason counters (OFFSCREEN, LIFETIME, HIT, CANCEL, CANCEL_NOITEM, CLEAR), and `state_hash()`. A MultiMesh renderer and a Node adapter calling `tick()` from `_physics_process` sit on top and are tested separately. Tests: `tests/unit/test_bullet_field.gd` (Perf in `tests/perf/`), `extends SceneTree` style like `test_chain_tracker.gd`, names `test_bullet_field_[scenario]_[result]`. Position asserts ±0.01 px (float32 `Vector2`).

Tags: [Unit] pure logic, headless · [Integration] scenes/signals · [Perf] measured on a reference machine · [Manual] needs a human.

### Pools and spawning

- **AC-01 [Unit] (Rules 1, 2):** **GIVEN** an empty field, **THEN** caps are 2000 / 600. **WHEN** 2000 enemy bullets are accepted, **THEN** a player request is still accepted, and an enemy and a player bullet at the same position cause no hit, removal or pool change.
- **AC-02 [Unit] (Rules 2, 3, F5):** **GIVEN** one request per shape (orb, rice, needle, ring enemy; streak, diamond player) with owners 0,1,2,3,0,1, **THEN** each stored bullet has that shape and owner, and hit radius 2.5 / 1.5 / 1.25 / 2.0 / 3.0 / 4.0.
- **AC-03 [Unit] (Rule 3):** **GIVEN** the same spawn requested once per enemy shape, **WHEN** 120 ticks run with no targets, **THEN** all four have identical position and speed every tick.
- **AC-04 [Integration] (Rule 5):** **GIVEN** a pattern node that requests 24 bullets and is then freed, **WHEN** 60 ticks run, **THEN** all 24 keep moving with no freed-instance errors; `request_spawn` returned only an integer count.
- **AC-05 [Unit] (Rule 6, F10):** **GIVEN** `enemy_active = 1995`, **WHEN** a 10-bullet volley is requested, **THEN** the first 5 in order are accepted, `enemy_active = 2000`, `refused_enemy` += 5. With `player_active = 598` and 5 requested: 2 accepted, `refused_player` += 3.
- **AC-05a [Unit] (Rule 1 fair share, F10):** **GIVEN** `N` = 4, `player_cap` 600 (share 150), slot 0 holding 150 live bullets and slot 1 holding 100, **WHEN** each requests 5, **THEN** slot 0's 5 are refused (`refused_player_share` += 5, `refused_player` unchanged) and slot 1's 5 are accepted. `N` = 2 → share 300; `N` = 1 → no share limit.
- **AC-06 [Unit] (Rule 6):** **GIVEN** a full enemy pool, **WHEN** 1 more is requested and a tick runs, **THEN** it is refused and all 2000 existing bullets are still present, moved only by their own behaviour.
- **AC-07 [Unit] (F0, F1, F7):** on spawn, before the first tick: enemy speed 600 → 480; 30 → 70; 0 → 70; player 1500 → 1200; Warp speed 0 stays 0 while frozen. With `k_speed = 0.75`, 200 → 150 and 70 → 70 (52.5 clamped up). With `k_speed = 0.875`, `warp_speed` 190 → 166.25 (no rounding).
- **AC-08 [Unit] (invalid requests):** **GIVEN** an enemy-pool request with a streak shape, a player-pool request with Curve behaviour, or an owner of 4, **THEN** each is refused, `invalid_requests` += 1, and `refused_enemy` / `refused_player` are unchanged.

### Movement and behaviours

- **AC-09 [Unit] (F1):** **GIVEN** Straight at `(100, 50)`, `v = (0, 150)`, **WHEN** 1 tick runs, **THEN** `(100, 52.5)`; after 60 ticks `(100, 200)`.
- **AC-10 [Unit] (F2):** **GIVEN** `v0 = 120`, 1.6, cap 330, **THEN** speed < 330 on tick 38 (~326.2), exactly 330 from tick 39 on, direction unchanged. **GIVEN** `v0 = 400`, **THEN** speed is 400 every tick.
- **AC-11 [Unit] (F3):** **GIVEN** `v = (0, 150)`, `ω = 1.5`, **WHEN** 1 tick runs, **THEN** velocity rotates 0.025 rad (±1e-4) clockwise on screen (y down) and speed stays 150 (±0.01); after 251 ticks heading is within 0.05 rad of the start; `ω = −1.5` turns the other way.
- **AC-12 [Unit] (F4 timeline):** **GIVEN** Warp `T1 = 42`, `T2 = 66`, `v0 = (0, 120)`, target `(180, 500)`, **THEN** it moves on ticks 1–42, has speed 0 and doesn't move on ticks 43–66, and on tick 67 its speed is 190 ±0.01. `warp_freeze_at 0.7` / `warp_reaim_at 1.1` give `T1 = 42`, `T2 = 66`.
- **AC-13 [Unit] (F4 example):** **GIVEN** Warp frozen at `(100, 155)`, target slot Alive at `(180, 500)`, **WHEN** the re-aim tick runs, **THEN** `v = (42.9, 185.1)` ±0.05, `|v| = 190`.

### Removal

- **AC-14 [Unit] (Rule 8, F8 margin):** with `m = 20`, checked by the removal pass on a placed bullet: `x = −20.0, vx < 0` kept; `x = −20.01, vx < 0` removed; `x = −25, vx > 0` kept; `x = 380.01, vx ≥ 0` removed; `y = 660.01, vy ≥ 0` removed; `y = −25, vy > 0` kept.
- **AC-15 [Unit] (F8 lifetime, integer ticks):** **GIVEN** a Curve bullet orbiting on screen, **THEN** present at age 720 and removed at age 721 with reason LIFETIME. **GIVEN** Straight at 70 px/s from `(−20, −20)` toward `(380, 660)`, **THEN** removed with reason OFFSCREEN between ticks 676–678, before 720.
- **AC-16 [Unit] (Rule 8):** **WHEN** a bullet hits or is cancelled, **THEN** it is removed that tick (reason HIT / CANCEL) and is never moved or tested again.
- **AC-17 [Unit] (clear-all):** **GIVEN** 1,350 enemy and 400 player bullets, **WHEN** clear-all runs, **THEN** both pools are 0, `cancel_items` is empty, and a following 2000-bullet request is fully accepted.

### Hits

- **AC-18 [Unit] (F5 boundaries):** static core radius 3.0: orb at d² = 25 → hit; d² = 34 → miss. Exact boundary: orb 5.5 hit / 5.51 miss; rice 4.5 / 4.51; needle 4.25 / 4.26; ring 5.0 / 5.01. A ring whose sprite edge touches the core (8 px from centre) → miss.
- **AC-19 [Unit] (F6 tunneling):** **GIVEN** a needle moving `(100, 196)` → `(100, 204)` in one tick and a static core at `(103.5, 200)`, **THEN** exactly 1 hit is reported. A 480 px/s bullet whose path passes 4.3 px from the core → no hit.
- **AC-20 [Unit] (F6 moving target):** **GIVEN** a static orb at `(100, 200)` and a core moving `(98.25, 205.4)` → `(101.75, 205.4)` in one tick (3.5 px, the max at 210 px/s), **THEN** 1 hit (closest approach 5.4 ≤ 5.5, while both endpoints are 5.68 px away, a point-test miss). With the core at y = 205.6 → no hit.
- **AC-21 [Unit] (Rule 10, no sweep while unhittable):** **GIVEN** the AC-20 setup with the slot unhittable at the start of the tick and hittable at the end, **THEN** no hit and the bullet stays. Hittable at both ends → hit. Unhittable (invulnerable or Selecting) at both ends while overlapping → never hit.
- **AC-22 [Unit] (respawn):** **GIVEN** a static orb at `(100, 550)` and a slot respawning from `(100, 500)` to `(100, 600)`, **THEN** previous position is set to `(100, 600)` and no hit is reported (a control run without the reset reports the hit).
- **AC-23 [Unit] (spawn inside hitbox):** **GIVEN** a core at `(180, 560)` and an orb spawned at `(182, 560)`, **WHEN** the next tick runs, **THEN** 1 hit (no grace).
- **AC-24 [Unit] (two players):** **GIVEN** an orb overlapping slots 1 and 3 on one tick, **THEN** it is removed once and exactly one hit `(1)` is reported.
- **AC-25 [Unit] (Rule 11):** **GIVEN** a streak (radius 3.0, owner 2, damage D) and a hurtbox radius 10, **THEN** at distance 13.0 one report `(target, 2, D)` and the bullet is removed; at 13.01 none. **GIVEN** a path crossing two hurtboxes, **THEN** exactly one report, for the one with the smaller entry point along the path (tie → lowest registration index).
- **AC-26 [Unit] (hurtbox removed same tick):** **GIVEN** a hurtbox removed in the same tick a player bullet reaches it, **THEN** the bullet tests against the start-of-tick list, one report is produced, and the bullet is removed.

### Cancelling

- **AC-27 [Unit] (F9 circle):** bomb at `(180, 320)`, `R_c = 120`: orb at 124 px cancelled, 125 px survives; ring at 128 px cancelled, 128.1 survives; needle threshold 126.
- **AC-28 [Unit] (Rules 13–15, full screen):** **GIVEN** 1,350 enemy bullets (some in the margin) and 400 player bullets, **WHEN** a full-screen cancel with `cause_slot = 2` runs, **THEN** `enemy_active = 0` that tick, `player_active = 400`, and 1,350 items credited to slot 2.
- **AC-29 [Unit] (F9 inset):** full-screen cancel catching `(−15, 300)`, `(370, 650)`, `(180, 320)` → items at `(8, 300)`, `(352, 632)`, `(180, 320)`.
- **AC-30 [Unit] (double cancel, FIFO):** **GIVEN** a bomb cancel (slot 0) requested before a part-kill cancel (slot 1) covering the same bullet, **THEN** one item credited to slot 0; reversed order → slot 1.
- **AC-31 [Unit] (cancel after spawn):** **GIVEN** a bullet spawned inside a cancel area in the same tick, **THEN** it produces an item and never appears in the active count.
- **AC-32 [Unit] (cancel beats hit):** **GIVEN** an orb that would hit slot 0 this tick and a cancel requested this tick covering it, **THEN** no hit is reported, the orb becomes one score item, and slot 0 is untouched.
- **AC-33 [Unit] (cause slot not Alive):** **GIVEN** `cause_slot = 3` in state Dead, **THEN** items are still credited to slot 3 with no error.
- **AC-33a [Unit] (rectangle cancel, Bombs 12):** **GIVEN** a rectangle cancel centred x 180, y 320, `half_w` 28, `half_h` 320, and orbs (`r_vis` 4.5) at x 212.5 and x 212.51 (same y), **THEN** the first is cancelled and the second survives.
- **AC-33b [Unit] (no-item cancel, Bombs 12):** **GIVEN** a circle cancel with `items = false` covering 10 bullets, **THEN** all 10 are removed with reason CANCEL_NOITEM and `cancel_items` is empty.

### Co-op targeting

- **AC-34 [Unit] (Rules 16, 17):** **GIVEN** Warp with target slot 2 Alive at re-aim, **THEN** it aims at slot 2's re-aim-time position even if slot 0 is nearer. **GIVEN** slot 2 Dead, Selecting or Inactive and slots 0 and 3 Alive, **THEN** it aims at the nearer of 0 and 3 (equal distance → lowest slot).
- **AC-35 [Unit] (Rule 17, F4):** **GIVEN** no slot Alive at re-aim, **THEN** it flies at 190 along stored heading `h`. **GIVEN** the target 0.5 px away, **THEN** it also uses `h`.

### Determinism and pause

- **AC-36 [Unit] (Rules 7, 12):** **GIVEN** a scripted 600-tick scenario (mixed behaviours, 3 targets, 2 cancels), **WHEN** run twice, **THEN** `state_hash()` is identical every tick; each tick every bullet's age rises by exactly 1, and hits are produced in the same tick as the move.
- **AC-37 [Integration] (fixed tick):** **GIVEN** 60 physics ticks per second and the manager ticked from `_physics_process`, **WHEN** AC-36's scenario runs with the frame limiter at 60, 30 and 144 fps (plus a 100 ms stall on frame 100), **THEN** `state_hash()` at tick 600 is identical in all runs. Same build and platform only; cross-platform bit-identity is not promised.
- **AC-38 [Integration] (pause):** **GIVEN** 500 bullets including a Warp at age 40, **WHEN** paused 30 s real time and resumed, **THEN** positions and ages are unchanged, and the Warp freezes 2 ticks after resume.

### Performance

Reference machines are named by the language ADR; placeholders: **REF-PC** (4 cores ~3 GHz, integrated GPU, 8 GB), **REF-WEB** (same machine, latest stable Chrome, release export), **REF-PHONE** (~2020 mid-range Android). Release export templates only. Benchmark scene `tests/perf/bullet_bench.tscn` (to be written): 2000 enemy + 600 player bullets steady state (all behaviours and shapes), 4 players moving, ~40 hurtboxes, 1,800 ticks after a 300-tick warm-up. **These results gate the language ADR** (C# cannot export to Web in official 4.7).

- **AC-39 [Perf] (F11 hit tests):** **GIVEN** the benchmark, **THEN** the hit-test pass (grid build included) is ≤ 1.5 ms at p99 per tick (mean ≤ 1.0 ms) on REF-PC and REF-WEB. Measure with `Time.get_ticks_usec()` per tick (on Web, time 60-tick blocks ÷ 60); cross-check with the Godot profiler.
- **AC-40 [Perf] (F11 total update):** **GIVEN** the benchmark, **THEN** the whole bullet update (spawn, age, move, cancels, hits, removal) is ≤ 2.5 ms at p99 per tick on REF-PC and REF-WEB. Includes a Target scenario: 1,350 enemy bullets + 12 kit cancel areas per tick (4P Breaker nets), still ≤ 2.5 ms p99 (Sentry/Breaker 29).
- **AC-41 [Perf] (frame rate):** **GIVEN** the benchmark with rendering, **THEN** on REF-PC and REF-WEB average frame time ≤ 16.6 ms, 1%-low ≥ 55 fps, and 60 physics ticks per second with none dropped. On REF-PHONE: gameplay still 60 ticks/s with none dropped, and rendering ≥ 30 fps (30 fps fallback allowed). Measure with `Engine.get_frames_per_second()`, a per-frame delta log, and the Monitors panel.
- **AC-42 [Perf] (accounting):** **GIVEN** a stress scene that over-requests, **THEN** `refused_enemy` equals the exact dropped count, the occupancy warning logs once on the first tick active ≥ 1800 (debug builds), and `peak_enemy_active` is reported. A real-stage content run passes if peak ≤ 1700 and refusals < 0.1%.
- **AC-43 [Unit] (grid correctness):** **GIVEN** a seeded scene (600 player bullets, 40 hurtboxes), **WHEN** run with `cell_size` 16, 32, 64 and a brute-force reference, **THEN** the hit-report sets are identical.
- **AC-44 [Perf] (allocation):** **GIVEN** the benchmark for 10 minutes, **THEN** static memory grows < 1 MB after warm-up, object count is stable ±5, and no per-bullet Node or Object is allocated.

### Visual

- **AC-45 [Manual] (grayscale gate):** **GIVEN** the benchmark on each era background, **WHEN** a screenshot is made grayscale, **THEN** a reviewer can count orb, rice, needle and ring bullets in a marked 100×100 px region and each reads as a dark-outlined shape. Evidence in `production/qa/evidence/`.
- **AC-46 [Manual] (shape vocabulary):** **GIVEN** the atlas, **THEN** enemy sprites measure orb 9 px, rice 4×9, needle 3×12, ring 16 px; player streak ~3×14, diamond ~7×7; enemy bullets only use the four cool enemy shapes and player bullets only the two warm shapes, in every era.
- **AC-47 [Manual] (hitbox honesty):** **GIVEN** a debug overlay drawing hit circles, **WHEN** a tester plays 10 minutes of the densest boss pattern, **THEN** every death shows the bullet circle overlapping the core; any "that didn't touch me" case is logged as a bug.

> Criteria drafted by `qa-lead`; its testability gaps were fixed in Rules 2, 5, 7, 12, 15, 17, F0, F8, F11 and Edge Cases. User decisions (2026-11-02): cancel beats hit on the same tick; phones may render at 30 fps.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Language for the bullet manager (GDScript / C# / GDExtension), rendering (MultiMesh), and the named reference machines REF-PC / REF-WEB / REF-PHONE. Official Godot 4.7 can't export C# to Web. Decided by the AC-39–AC-44 benchmark. | Language-split ADR | Before implementation |
| 2 | Player hitbox radius: keep 3.0 or try 2.0–2.5 for the "2-pixel lane" fantasy | Player plane (5) GDD + playtest | Player plane GDD |
| 3 | ~~Player lateral speed on the 360 canvas~~ — **resolved**: 210 / 105 px/s, crossing 1.71 s (Player plane PF1) | Player plane (5) GDD | Done 2026-11-02 |
| 4 | ~~Pattern spacing/count retune ×0.75 for the 360-wide canvas; target-slot choice rule (nearest vs rotating)~~ **Closed 2026-11-03:** Pattern library F10 (migration) and F4 (per-emitter rotation over Alive slots). | Bullet pattern library (9) GDD | Pattern library GDD |
| 5 | ~~Final player-shot sprite sizes and hit radii (streak, diamond are placeholders)~~ **Closed 2026-11-03:** hit radii streak 3.0 / diamond 4.0 confirmed (Plane kits 11); sprite sizes stay with the art bible §4.4 | Art bible §4.4 + Plane kits (11) | Plane kits GDD |
| 6 | ~~Score item value, auto-fly behaviour, and whether Dead/Continue slots can collect~~ **Closed 2026-11-03:** gems fly only to an Active cause slot; gems from a non-Active cause slot drift down and any Active plane can collect them; Dead/Continue slots collect nothing (Powerups 13) | Powerups and drops (13) GDD | Powerups GDD |
| 7 | ~~Cancel shockwave and puff timing (bullet vanish itself is instant, 1 tick — V6)~~ **Closed 2026-11-03:** puffs stride-sampled (F3), live cap 40 across sweeps, CB 12; rings per VFX F7 (vfx-and-screen-feedback.md) | VFX (25) | VFX pass |
| 8 | Art bible amendments: Lancer has drones like every plane (§5.6 says "n/a" — stale since the 2026-11-02 drone redesign); hitbox dot at true 6 px size (§4.4); ring core pip (§3.3/§4.3); angle driven by heading not age (§8.6); shockwave minimum 36 px in §6.8 (matches §3.3); score items on layer 6 in the §6.8 stack; rice/needle sizes include the outline (3-layer rule, §4.2); explicit per-frame pivots for odd-size sprites (§8.3) | art-director (`/art-bible` update) | Before bullet art |
| 9 | Rice/needle readability at 4 px / 3 px wide — confirm with the atlas spike and grayscale gate (AC-45) before locking AC-46 sizes | art-director + QA | Atlas spike |
| 10 | ~~Audio numbers (voice caps, retrigger gap, cancel tiers)~~ **Closed 2026-11-03:** BULLET pool 8, retrigger gap 3 ticks, priority bands P0–P5 (audio.md) | audio-director | Audio pass |
