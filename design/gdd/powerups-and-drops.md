# Powerups and Drops

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (economy-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts, Readable Chaos, Four Planes Four Games

## Overview

**The data layer:** Powerups and drops owns every **item** in the play field. There are five kinds: the **drone pod** (+1 drone), the **chain pickup** (+10 chain hits), the **medal** (score), the **1-up** (+1 life) and the **gem** (small score, made from cancelled bullets). It receives two inputs: `drop_requested(pos, killer_slot, def_id)` from a destroyed **carrier** enemy (Enemy 10), and a list of cancelled-bullet positions plus a cause slot from the Bullet manager (3). For a carrier it decides *what* drops, using a seeded drop table with a pity counter. For cancelled bullets it makes gems, capped per cancel. It then moves the items (float and fall, or auto-fly), tests pickup against each Active plane, and reports the result: `Session` for drones and lives, `ChainTracker.add_bonus` for chain pickups, `Scoring` for gems and medals. It runs on the 60 Hz integer tick (ADR-0001), uses packed arrays, no per-item nodes, and one seeded drop stream per stage.

**The player impact:** items are the only way to get stronger, and "stronger" is deliberately small. A pod adds one drone, to a maximum of four, and drones never hit harder. Dying throws all of them away. That makes the drone count a **fragile escort the player wants to keep**, not a stat to farm (anti-pillar: no stat grinding). Chain pickups and medals pull the eye to a risky patch of screen. Gems are the quiet reward for every bomb and every big kill, and they fly to the player on their own. Nothing here is hidden: a carrier pulses cream before it dies, and the item that drops is the one the player can see.

## Player Fantasy

**Anchor moment: the pod in the bullet pocket.** A carrier bomber blows up in the middle of a curtain. A cream tile pops out of the fireball, rises a few pixels and starts to drift down between two bullet streams. The player has 0 drones after a death. They slide to focus speed, thread the gap, and the pod snaps into the wing. One drone is back. Then comes the next carrier.

What makes that feeling possible:
- **The pod is always worth the walk.** It is cream, it bobs, it does not move sideways more than 6 px, and the player can see it for 10 seconds. The risk is the route, not a trick.
- **Death stings, but it is recoverable.** Losing 4 drones costs roughly one stage of pods. A forced pod after the next carrier keeps the player in the game.
- **Power stays flat.** The fourth drone is a convenience for chain and for the kit's ability, not a damage ramp. A player at 4 drones is not "stronger"; they are *better equipped to keep the chain alive*.
- **Gems are a thank-you, not a chore.** They fly in by themselves, so a bomb never forces the player into the bullets they just cleared.
- **Co-op shares.** Every item is first come, and the plane that needs the pod most gets it on a tie.

Reference feel: DoDonPachi's "get the item or don't, the score doesn't depend on it", and 1941's pod that you spot a screen early.

**Anti-fantasy (what must never happen):** a stat that grows run after run, a pickup that has to be farmed, a medal hidden behind a random roll the player cannot see, an item that looks like a bullet, or a pod lost because a partner at 4 drones "wasted" it.

> `creative-director` not consulted (lean mode).

## Detailed Design

### Core Rules

**Item kinds**

1. There are five item kinds. Only these.

| Kind | Source | Effect on pickup | Scored (Scoring 8) |
|---|---|---|---|
| **POD** (drone pod) | carrier drop | `Session.add_powerup(slot)`: `drone_count + 1`, max 4 (`max_drones`) | No |
| **CHAIN** (chain pickup) | carrier drop | `ChainTracker.add_bonus(slot, chain_pickup_amount, "chain_pickup")` | No |
| **MEDAL** | carrier drop; overflow of POD / 1-up | none | `item_collected(slot, MEDAL)`, 1,000 × chain factor |
| **1UP** | scheduled carrier drop (Rule 11) | `Session.add_oneup(slot)`: `lives + 1`, max `max_lives` (6) | No |
| **GEM** | a cancelled enemy bullet (Bullet manager Rule 14) | none | `item_collected(slot, GEM)`, 100 × chain factor |

2. **Anti-grinding guardrail (hard rule).** No item changes shot damage, fire rate, spread, speed, hitbox, bomb stock, kit meter or kit cooldown. Items write only four things: `drone_count` (Session), `lives` (Session), the chain count (ChainTracker) and score (Scoring). The only persistent effect is `drone_count`, which is capped at 4 and reset to 0 on death. Bomb and meter refills are **not** items.

**Carriers and drops**

3. Only an enemy flagged **carrier** by its wave drops anything. Powerups never rolls for a non-carrier. A carrier that escapes drops nothing (Enemy 10). A carrier destroyed by any means (shot, laser, drone, bomb) drops.
4. On `drop_requested(pos, killer_slot, def_id)` Powerups looks up the enemy's `kill_class` (SMALL, MEDIUM, LARGE) from the enemy definition by `def_id`, and builds the drop with the drop table for that class (Rule 6). *(Provisional: Enemy 10 should add `kill_class` to the request so no lookup is needed.)*
5. **Items per drop** `n = N`, the Co-op (18) player count (1 to 4), read at the drop tick. This gives every player the same expected pod income as a solo player (F2).
6. **Drop tables** (data, `data/drops/drop_tables.tres`). Each SMALL or MEDIUM item gets one roll `r` in `[0, 100)` from the stage drop stream:

| Carrier class | POD | CHAIN | MEDAL | Pity-tracked |
|---|---|---|---|---|
| SMALL | 0–54 (55) | 55–79 (25) | 80–99 (20) | Yes |
| MEDIUM | 0–49 (50) | 50–69 (20) | 70–99 (30) | Yes |
| LARGE | fixed bundle: `n` PODs + 1 MEDAL, no roll | | | No |

   Items are placed in a row (F6). A LARGE carrier is a guaranteed reward, so the player is paid for killing the hard target.
7. **Pod pity.** The team has one `pity_misses` counter, starting at 0 each stage. When `pity_misses >= pity_limit` (2), the next SMALL/MEDIUM item is a POD regardless of `r`. A POD (rolled or forced) sets `pity_misses = 0`; any other result adds 1. When any slot dies, `pity_misses = pity_limit` (the **recovery pod**: the next SMALL/MEDIUM drop is a pod).
7a. **Drill override** *(2026-11-03, wave 4, [Tutorial (30)](tutorial.md))*: an enemy spawned with `drop_override` (POD, MEDAL or CHAIN; drills only) drops exactly that item, bypassing the drop table and the pity counter (`pity_misses` unchanged).
8. **Need check (drop substitution).** Let `k` = number of slots in state Alive or Dead with `drone_count < max_drones`. Within one drop, only the first `k` POD results stay PODs; the rest become MEDALs. If `k = 0`, no PODs drop that tick. A pod therefore never appears when nobody can use it.
9. **RNG discipline.** Every `drop_requested` consumes exactly **4** draws from the stage drop stream (one per possible item, even if `n < 4`, even if the result is substituted). Content never depends on how many draws were used elsewhere.
10. **Seed.** `drop_seed = hash(run_seed, stage_index, "drops")`. The stream advances only on `drop_requested`, in the order Enemy (10) emits them within a tick (ascending enemy id, then tick order).
11. **1-up schedule (fixed, not random).** Per stage, the **4th** carrier destroyed (count of `drop_requested` this stage) drops one extra **1UP** next to its normal items. If `N >= 3`, the **9th** carrier drops a second one. If every slot in Alive or Dead has `lives == max_lives`, the 1UP is replaced by a MEDAL. A stage in which fewer carriers die has no 1-up. The 1-up comes with its own gold rim, so the player can see it is special.

**Cancel items (gems)**

12. When the Bullet manager (3) cancels bullets (`request_cancel`, bomb, kill-cancel, boss part kill, boss death whole screen (Boss 14 Rule 31), full screen), it hands Powerups the list of cancelled bullets in pool-index order, their positions (already inset-clamped, BM F9) and the cause slot. Powerups keeps **at most `items_per_cancel_cap` (100)** gems per cancel, chosen by **stride sampling** (F3), so the kept gems spread evenly over the cancel area. Cancelled bullets over the cap are still cancelled; they just give no gem.
13. Gems and carrier drops live in **separate pools** (`gem_cap` 300 and `drop_cap` 24) so a bomb can never push a pod or 1-up out of the field. Gems are discarded (counted for debug) when the gem pool is full.
14. **Anti-farm.** (a) The 100-per-cancel cap applies to every source, bomb and kill-cancel alike. (b) Medals, chain pickups, pods and 1-ups only come from carriers; bullets never make them. (c) The death clear and stage clear-all make no gems (BM Rules 15a, clear-all). (d) The worst case, 100 gems at chain 500+, is 110,000 points (F9), about 0.6% of an expert stage (three such bombs about 1.7%).

**Motion**

15. **Drop items (POD, CHAIN, MEDAL, 1UP)** pop, then fall. For `pop_ticks` (18) they rise (F5). Then they fall at `drop_fall` (0.8 px/tick, 48 px/s) with a gentle horizontal bob (amplitude 6 px, period 90 ticks). They stop at `rest_y` (616) and wait there until their lifetime ends: `drop_lifetime` 600 ticks (10 s), 1UP 900 ticks (15 s). The last 120 ticks they pulse (V3). They never leave through the bottom, so a miss costs only time.
16. **Magnet (drop items only).** If an eligible Active plane's centre is within `magnet_radius` (36 px) of the item, the item moves toward the nearest eligible plane at `magnet_speed` (5 px/tick, above `move_speed`). Bobbing stops. Eligible = the plane could collect it now (Rule 20).
17. **Gems** sit still for `gem_hold` (6 ticks), then fly toward the **cause slot's plane** (pure pursuit) with speed `min(gem_vmax, gem_v0 + gem_accel * t)` (F4), always faster than the player. A gem never loses its target while the cause slot is **Active**. If the cause slot is not Active (Dying, Dead, Continue, Inactive), the gem does not fly: it drifts down at `drop_fall` and any Active plane can collect it by touch. It resumes flying on the first tick the cause slot is Active again. A gem expires after `gem_lifetime` (300 ticks).
18. **Sweep.** On `boss_defeated` (Boss 14), every item still in the field (gems and drop items) flies to the nearest Active plane at `sweep_speed` (10 px/tick) and is collected normally. Items still present on `stage_cleared` are removed with no payment (Scoring pays nothing after `stage_cleared`).

**Pickup**

19. **Pickup test (F6):** a plane collects an item when the distance between centres is `<= pickup_radius (14) + r_item`. `r_item` by kind: GEM 4, MEDAL 7, CHAIN 7, POD 8, 1UP 8.
20. **Who can collect.** Only a plane in state **Active** (Alive, not Dying, not Dead, Continue, Selecting or Inactive; Active begins on the tick the plane becomes Active, the same moment `respawn_invuln` starts). Dead and Continue slots collect nothing, and nothing is held for them. A plane at `drone_count == 4` is **not eligible for PODs** while at least one other Active plane has `< 4`; the pod passes through it. If every Active plane is at 4, a POD pickup is an **overflow** (Rule 22).
21. **First come, tie-break.** The first tick any eligible plane overlaps an item, that item is collected. If two or more planes overlap it on the same tick, the plane with **fewer drones** wins; if equal, the **lowest slot** wins (Co-op 18 Rule 10). Items are never reserved for the player who caused the drop. A gem collected by another player pays the collector from the collector's chain.
22. **Overflow.** A POD collected at 4 drones gives no drone; it pays a MEDAL (`item_collected(slot, MEDAL)`) at once. A 1UP collected at `max_lives` fires `extend_awarded(gained = 0)` (Session) and also pays a MEDAL. Overflow cannot happen when the drop was made with a need check unless the situation changed in flight.
23. **Order inside a tick.** (1) Collision resolves hits and deaths, (2) Bullet manager runs cancels, (3) Powerups creates gems and drop items for requests received this tick, (4) Powerups moves items, (5) Powerups tests pickup. A plane that died on this tick is no longer Active at step 5 and collects nothing (death wins). Gems made on tick T are first moved on tick T + `gem_hold`.

**Value and score**

24. Gems and medals are scored with `Scoring.item_collected(slot, kind, count)`, where `count` is the **collector's** chain count read from the Chain tracker at the pickup tick (Scoring AC-22). Value = `item_base × (1 + min(count, 500) / 50)` (Scoring F3). POD, CHAIN and 1UP pay nothing themselves.
25. **Chain pickup** (decision): `add_bonus(slot, 10, "chain_pickup")`. As defined by Chain tracker Rule 2, this raises the count by 10 (cap 999) and **refills the chain window**; it can start a chain from 0. It is **not** a hit: no hit score, no `chain_hit`. Milestones (50, 100, 200) fire if the count crosses them.

### States and Transitions

Per item:

| State | Kinds | → Next | Trigger |
|---|---|---|---|
| Pop | drop items | Fall | `pop_ticks` (18) elapsed |
| Fall | drop items | Rest | `y >= rest_y` |
| Hold | gems | Fly or Drift | `gem_hold` (6) elapsed |
| Fly | gems | Drift | cause slot not Active |
| Drift | gems | Fly | cause slot Active again |
| Fall / Rest / Drift / Fly / Pop / Hold | any | Collected | eligible plane overlaps (Rule 19) |
| Fall / Rest / Drift / Hold | any | Expired | lifetime elapsed |
| Any | any | Swept | `boss_defeated` → fly at `sweep_speed`, then Collected |
| Any | any | Removed | `stage_cleared`, stage start, run reset (no payment) |

Per run: the drop stream, `pity_misses`, `carriers_this_stage` and 1-up flags reset at `stage_started`. The `drone_count` they affect lives in Session.

### Interactions with Other Systems

| System | Direction | Data (✓ = GDD exists) |
|---|---|---|
| Enemy and AI (10) ✓ | ← | `drop_requested(pos, killer_slot, def_id)` for carriers only. Provisional: also carries `kill_class`. Escaped carriers send nothing |
| Bullet manager (3) ✓ | ← | cancelled positions (pool-index order, inset-clamped) + `cause_slot` per cancel request: the `items = true` entries of the per-tick `cancel_report[]` (BM Rule 13, merged 2026-11-03) |
| Collision, damage and lives (6) ✓ | ← | `player_died(slot)` (recovery pod); plane Active flag per slot; Collision resolves before Powerups in a tick |
| Player plane (5) ✓ | ← | plane position per slot. Pickup radius is owned here (14 px) |
| Game events and session (1) ✓ | ↔ | reads slot state, `drone_count`, `lives`, `N`, `stage_index`, `run_seed`; calls `add_powerup(slot) -> int` and `add_oneup(slot) -> int (gained)` *(provisional names)*; emits nothing into Session state otherwise |
| Chain tracker (7) ✓ | ↔ | reads `count(slot)` for scoring; calls `add_bonus(slot, 10, "chain_pickup")` |
| Scoring (8) ✓ | → | `item_collected(slot, kind, count)` for GEM and MEDAL |
| Co-op (18) ✓ | ← | `N`; pickup tie-break contract |
| Plane kits (11) ✓ | → | indirectly through `drone_count` only. New drones dock at the next free wing slot (Kits Rule 32) |
| Boss (14), [Wave director (16)](wave-and-stage-director.md) | ← | `boss_defeated` (sweep), `stage_cleared` (Director: `max(boss_gone, boss_defeated + sweep_min_ticks)`, `sweep_min_ticks` 90), `stage_started`; Wave director supplies carriers (see Dependencies) |
| Bombs (12) | ← | bomb cancels arrive through the Bullet manager; no direct call. Bombs never create medals |
| HUD (20), Audio (24), VFX (25) | → | `item_collected_ex(slot, kind, pos)`, `drone_gained(slot, new_count)`, `item_expired(kind, pos)`, `oneup_dropped(pos)` (presentation only) |

> Audio (24), VFX (25) and Accessibility (28) GDDs exist *(2026-11-03, wave 3b)* and match this contract; Boss (14), Bombs (12), Wave director (16) and HUD (20) GDDs exist (2026-11-03) and match this contract. Contract: Powerups only needs the signals named above; they own no state Powerups reads except `boss_defeated` and `stage_cleared`.

> Decided under auto-approve (2026-11-03): five item kinds only; items per drop = N; fixed LARGE bundle; SMALL/MEDIUM table 55/25/20 and 50/20/30; team pity limit 2 plus a recovery pod after a death; need check on pods; 1-up fixed at the 4th carrier (9th also at 3P+) with a medal at max lives; gems capped by stride sampling at 100; separate gem and drop pools; items rest at the bottom instead of leaving; sweep on boss defeat; planes at 4 drones skip pods while a partner needs them; overflow pays a medal; chain pickup +10 and refills the window; collect only when Active; pickup radius 14.

## Formulas

**Conventions:** units are px and ticks (60 Hz). `r_p` etc. as in other GDDs. All integers unless marked float. Positions are floats; the tick order is fixed (Rule 23) so results are repeatable on one machine.

**F1. Drop resolution** *(`drop_item_kind`)*

`kind(r, misses) = POD if misses >= pity_limit, else table_class(r)`; then `misses' = 0 if kind == POD else misses + 1`. After the loop, apply the need check (Rule 8): PODs beyond `k` become MEDALs.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Roll | `r` | int | 0–99 | Draw from the stage drop stream |
| Pity misses | `misses` | int | 0–`pity_limit` | Shared by the team, set to `pity_limit` on a death |
| Pity limit | `pity_limit` | int | 1–4 (default 2) | Non-pod results before a forced pod |
| Needy slots | `k` | int | 0–4 | Slots in Alive/Dead with `drone_count < 4` |

**Output Range:** POD, CHAIN or MEDAL per item.
**Example (SMALL, solo, k = 1):** `misses = 0`, `r = 62` → CHAIN (55–79), `misses = 1`. Next `r = 90` → MEDAL, `misses = 2`. Next `r = 99` → forced POD (`misses >= 2`), `misses = 0`. After a death `misses = 2`, so the next item is a POD even if `r = 99`.

**F2. Expected pods** *(`pod_income`)*

Long-run POD probability of a SMALL/MEDIUM item with pod weight `p` and pity limit `L`: `P_pod = 1 / (1 + q + q² + … + q^L)`, `q = 1 − p`. Expected pods per stage per player = `(P_pod_small × n_small + P_pod_med × n_med + n_large) × kill_rate` (with `n` items per drop = N the per-player income is independent of N).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Pod weight | `p` | float | SMALL 0.55, MEDIUM 0.50 | From Rule 6 |
| Carrier counts per stage | `n_small`, `n_med`, `n_large` | int | 4, 2, 2 (Wave director contract) | Carriers authored per stage |
| Kill rate | `kill_rate` | float | 0.5–1.0 | Share of carriers killed |

**Output Range:** 0–5.6 pods per player per stage at the contract mix.
**Example:** SMALL: `q = 0.45`, `1 + 0.45 + 0.2025 = 1.6525`, `P = 0.6051`. MEDIUM: `q = 0.5`, `1 + 0.5 + 0.25 = 1.75`, `P = 0.5714`. Per stage: `4 × 0.6051 + 2 × 0.5714 + 2 = 2.4204 + 1.1428 + 2 = 5.563` pods at full kill; at `kill_rate = 0.85`: **4.73**. Rebuilding 0 → 4 drones after a death takes about `4 / 4.73 = 0.85` of a stage, plus the recovery pod. This is the intended "sting".

**F3. Cancel stride sampling** *(`cancel_item_sample`)*

`stride = ceil(n / cap)`; bullet at pool order index `i` (0-based) makes a gem iff `i mod stride == 0`; `kept = ceil(n / stride)`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cancelled bullets | `n` | int | 0–2000 | In this cancel request |
| Cap | `cap` | int | 50–200 (default 100) | `items_per_cancel_cap` |
| Stride | `stride` | int | 1–40 | Spacing between kept bullets |

**Output Range:** `kept` is 0 to `cap`. **Example:** `n = 1350`, `cap = 100` → `stride = ceil(13.5) = 14`, `kept = ceil(1350 / 14) = ceil(96.43) = 97`. `n = 100` → stride 1, kept 100. `n = 101` → stride 2, kept 51. `n = 250` → stride 3, kept 84. `n = 0` → 0.

**F4. Gem flight** *(`gem_speed`)*

`speed(t) = min(gem_vmax, gem_v0 + gem_accel × t)` px/tick, `t` = ticks since the hold ended. The gem moves `min(speed, distance_to_target)` toward the target each tick (pure pursuit, no overshoot).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Start speed | `gem_v0` | float | 2–5 (default 3) | px/tick |
| Acceleration | `gem_accel` | float | 0.1–0.5 (default 0.25) | px/tick² |
| Max speed | `gem_vmax` | float | 6–14 (default 10) | px/tick; must exceed `move_speed` 3.5 |

**Output Range:** 3–10 px/tick. **Example:** `t = 0` → 3; `t = 14` → 6.5; `t = 28` → 10. Distance in the first 28 ticks = `28 × 3 + 0.25 × (27 × 28 / 2) = 84 + 94.5 = 178.5` px. A gem 300 px from a plane needs 282 px (reach 18): 178.5 px by t = 28, then `ceil(103.5 / 10) = 11` more ticks → collected at `t = 39`, i.e. 45 ticks (0.75 s) after the cancel.

**F5. Drop item motion** *(`drop_motion`)*

*(2026-11-03, ADR-0003)*: the bob `sin` uses the `SimMath` table and item positions are rounded to 1/16 px. Pop: for `t = 0..pop_ticks−1`, `y += −pop_v0 × (1 − t / pop_ticks)`. Fall: `y += drop_fall` until `y >= rest_y`. `x = x0 + bob_amp × sin(2π × age / bob_period)`, clamped to `[drop_inset, 360 − drop_inset]`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Pop speed | `pop_v0` | float | 0.5–2 (default 1.0) | px/tick at t = 0 |
| Pop ticks | `pop_ticks` | int | 6–30 (default 18) | |
| Fall | `drop_fall` | float | 0.4–1.2 (default 0.8) | px/tick |
| Rest line | `rest_y` | int | 560–630 (default 616) | |

**Output Range:** rise 9.5 px, then 0.8 px/tick. **Example:** rise = `18 − (0 + … + 17) / 18 = 18 − 153 / 18 = 9.5` px. A drop at y = 200 reaches `y = 616` after `18 + (616 − 190.5) / 0.8 = 18 + 532 = 550` ticks, inside the 600-tick life (a 1UP rests there until tick 900).

**F6. Pickup, magnet and row placement** *(`pickup_test`)*

`collect = (dx² + dy²) <= (pickup_radius + r_item)²`. Magnet: `(dx² + dy²) <= magnet_radius²`. Row placement for item `i` of `m` items: `x_i = x_drop + (2i − (m − 1)) × 7`, clamped.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Pickup radius | `pickup_radius` | int | 10–20 (default 14) | Owned here, centre of plane |
| Item radius | `r_item` | int | GEM 4, MEDAL 7, CHAIN 7, POD 8, 1UP 8 | |
| Magnet radius | `magnet_radius` | int | 0–60 (default 36) | |

**Output Range:** bool; offsets −21 to +21 px for m ≤ 4 (m = 5 for a 4P LARGE: −28 to +28).
**Example:** POD (reach 14 + 8 = 22): plane (100, 100), pod (100, 122) → `d² = 484 ≤ 484` collected; pod (100, 123) → 529 > 484 not collected. GEM (reach 18): d = 18 → collected; 19 → not. Row for m = 3: offsets −14, 0, +14. Magnet: a pod at d = 36 closes the 14 px to reach 22 in 3 ticks at 5 px/tick.

**F7. Item-pool bounds** *(`item_pool_bounds`)*

`max_items = gem_cap + drop_cap = 300 + 24 = 324`. Per-cancel budget: `items_per_cancel_cap ≤ gem_cap / 3`.

**Output Range:** ≤ 324 items. **Example:** three 100-gem cancels within 5 s fit (300). A fourth overflow: its gems beyond the pool are discarded and counted.

**F8. Overflow and recovery**

`pods_per_death_gap`: after a death, the first SMALL/MEDIUM drop is a POD (Rule 7); then F2 applies. **Example:** player dies with 3 drones at pity 0. `misses = 2`. Next drop: `r = 80` (would be MEDAL) → forced POD, `misses = 0`. Next drop `r = 80` → MEDAL, `misses = 1`.

**F9. Cancel farming bound** *(`cancel_value_bound`)*

`max_cancel_value = items_per_cancel_cap × gem_base × (1 + factor_cap_count / factor_step)` with the Scoring factor.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cap | `items_per_cancel_cap` | int | 50–200 | |
| Gem base | `gem_base` | int | 100 | Scoring `item_base` |
| Factor cap, step | `factor_cap_count`, `factor_step` | int | 500, 50 | Scoring knobs |

**Output Range:** up to 110,000 per cancel. **Example:** `100 × 100 × (1 + 500 / 50) = 100 × 100 × 11 = 110,000`. Three such bombs in an expert stage (19,712,700, Scoring F7, re-baselined 2026-11-03) = 330,000 = **1.7%**. At the competent profile (chain ~80, factor `1 + 80 / 50 = 2`): `100 × 100 × 2 = 20,000` per bomb, 60,000 for three = **2.0%** of 2,987,250.

> Decided under auto-approve (2026-11-03): pity limit 2; contract mix 4 SMALL / 2 MEDIUM / 2 LARGE carriers per stage; stride sampling instead of nearest-first; `gem_v0` 3, `gem_accel` 0.25, `gem_vmax` 10; `pickup_radius` 14; `magnet_radius` 36.

## Edge Cases

**Drops**
- **If a carrier is destroyed and no slot is Alive or Dead** (all Inactive/Continue-expired), no PODs drop (`k = 0`); the item becomes a MEDAL. Other kinds drop normally.
- **If two carriers are destroyed on the same tick**, requests are processed in ascending enemy id; the second one sees the pity counter after the first.
- **If a LARGE carrier drops with `N = 4` and `k = 1`**, the bundle is 5 items: 1 POD and 4 MEDALs (3 PODs substituted, plus the fixed MEDAL).
- **If a player dies on the same tick a carrier is killed**, the drop is made first (Enemy order), then the death sets `pity_misses = pity_limit`. The next SMALL/MEDIUM drop is the recovery pod.
- **If the 4th carrier is a LARGE**, the bundle also contains the 1UP (row grows by one).
- **If the 1UP is due and everyone in Alive/Dead has `lives == max_lives`**, a MEDAL drops instead.
- **If a carrier's `def_id` has no known `kill_class`**, treat it as SMALL and log one data warning.
- **If `drop_requested` arrives after `boss_defeated`**, the drop is made and swept like any other item.
- **If the drop position is outside the play area** (carrier destroyed in the margin), the position is clamped to `[drop_inset, 360 − drop_inset] × [play_top + drop_inset, rest_y]` (drop_inset 12).

**Gems**
- **If a cancel has more bullets than `gem_cap` allows**, only the first `gem_cap − gems_alive` of the sampled gems are created; the rest are discarded and counted.
- **If the cause slot is Dead, Continue or Inactive**, gems still spawn and drift (Rule 17). Any Active plane can collect them by touch; the collector is paid.
- **If a cancel happens on the tick the cause slot dies**, the gems spawn and drift; they fly again when the slot is Active.
- **If a gem is collected by a plane that is not its cause slot**, the pay uses that plane's chain count, and the cause slot's plane is unaffected.
- **If a bomb cancel catches bullets in the margin**, their gems are already inset-clamped by the Bullet manager (F9) and start inside the play area.
- **If a gem's target plane stops moving next to a wall**, pure pursuit still arrives; there is no path logic.

**Pickup**
- **If a plane overlaps two items on the same tick**, both are collected in item index order.
- **If two pods are collected on the same tick by the same slot at 3 drones**, the first gives the 4th drone, the second is an overflow MEDAL (Session edge case).
- **If a plane at 4 drones overlaps a POD while a partner has fewer**, the POD passes through and is not collected (Rule 20).
- **If a partner who needed the POD dies before reaching it**, the pod stays; the plane at 4 drones may now collect it as overflow only if no other Active plane has `< 4`.
- **If a plane becomes Active on the tick an item overlaps it**, the item is collected on that tick.
- **If the plane dies on the tick it overlaps an item**, the item is not collected (Rule 23).
- **If an item is under a plane at `y > rest_y`**, items rest at 616 and the plane may stand there; no special case.
- **If a chain pickup is collected at count 995**, count becomes 999 (cap), the window refills, milestones are checked.
- **If a chain pickup is collected by a slot whose chain is Frozen** (Chain tracker boss-phase rule), `add_bonus` follows the Chain tracker's own rule (ignored if the slot is not Active; refill is its call).

**Stage and run**
- **If the boss dies while items are in flight**, all fly to the nearest Active plane (Rule 18). If no plane is Active, items stay until `stage_cleared` and are removed.
- **If `stage_cleared` arrives before the sweep finishes**, the remaining items are removed with no pay.
- **If a new stage starts**, all items are cleared, `pity_misses = 0`, `carriers_this_stage = 0`, the drop stream is reseeded.
- **If the game is paused**, no item ticks.
- **If a player joins mid-stage (drop-in)**, `N` rises; the next drop uses the new `N`. Items already in the field are unchanged.
- **If the run resets (game over, return to title)**, all pools clear with no pay and no events.

**Determinism and pools**
- **If the drop pool is full (24)**, the oldest MEDAL or CHAIN is evicted for a new POD or 1UP; if none can be evicted, a new MEDAL or CHAIN is discarded and counted. PODs and 1UPs are never evicted.
- **If `item_expired` fires for a POD**, VFX plays a soft puff (V5); there is no penalty.

> Decided under auto-approve (2026-11-03): clamp-at-edge for drop positions; no revive by items; sweep only for Active planes.

## Dependencies

**Upstream (this system needs them)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) ✓ | Hard | slot state, `drone_count`, `lives`, `N`, `run_seed`, `stage_index`; `add_powerup`, `add_oneup` *(provisional)* |
| Collision, damage and lives (6) ✓ | Hard | `player_died(slot)`; Active flag; tick order |
| Chain tracker (7) ✓ | Hard | `count(slot)`, `add_bonus(slot, n, source)` |
| Scoring (8) ✓ | Hard | `item_collected(slot, kind, count)` |
| Enemy and AI (10) ✓ | Hard | `drop_requested(pos, killer_slot, def_id)` for carriers; `kill_class` |
| Bullet manager (3) ✓ | Hard | cancelled positions + cause slot, pool order (`items = true` entries of `cancel_report[]`, BM Rule 13) |
| Player plane (5) ✓ | Hard | plane positions; pickup radius owned here |
| Co-op (18) ✓ | Soft | `N`; pickup tie-break |
| Plane kits (11) ✓ | Soft | none direct; drones appear through `drone_count` |
| Boss (14) | Soft ([GDD](boss-and-boss-parts.md)) | `boss_defeated(reason, killer_slot)` for the sweep; bosses drop no carrier items |
| Wave director (16) | Soft ([GDD](wave-and-stage-director.md)) | carrier authoring and spacing (8 per stage, Director F5); `stage_started`, `stage_cleared` |

**Downstream (these need this system)**

| System | Hard/Soft | Interface |
|---|---|---|
| Wave director (16) | Hard | authors carriers using the contract in Amendment 11 |
| HUD (20) | Soft | presentation events; drone lamps from Kits |
| Audio (24), VFX (25) | Soft | `item_collected_ex`, `drone_gained`, `item_expired`, `oneup_dropped` |
| Bombs (12) | Soft | bomb cancels flow through the Bullet manager; cap applies |
| Tutorial (30) — [GDD](tutorial.md) | Soft | may highlight the carrier cue and the first pod; `drop_override` spawn param (Rule 7a, drills only) |

**Amendments to other docs**

1. **`design/gdd/systems-index.md`**, row 13: Status → `**Designed** (pending review) — [GDD](powerups-and-drops.md)`; Depends on `6, 7, 8, 10, 11` → `1, 3, 5, 6, 7, 8, 10, 18` (11 becomes soft/indirect; the 11 ↔ 13 cycle stays cut, Kits GDD amendment 1); progress tracker: GDDs written 14, add "Powerups and drops". Add the dependency note: "Powerups (13) owns item kinds POD/CHAIN/MEDAL/1UP/GEM and `items_per_cancel_cap` 100."
2. **`design/gdd/enemy-and-ai.md`**: (a) Interactions row for Powerups: `drop_requested(pos, killer_slot, def_id, kill_class)`; (b) Open Questions 3 and 6 closed: kill-cancel items use `items_per_cancel_cap` 100 with no value reduction (Powerups F9, 1% worst case); carrier cadence is 8 per stage (4 SMALL, 2 MEDIUM, 2 LARGE) and the recovery pod is owned by Powerups (Rule 7); (c) V2 carrier cue stays as is (cream pulse matches the cream POD).
3. **`design/gdd/bullet-manager.md`**: Open Question 6 closed: items fly only to an Active cause slot; Dead/Continue slots collect nothing; gems drift and any Active plane may collect them. Interactions: the cancel hand-off must supply the list in pool-index order plus `n`; Powerups does the stride sampling (F3).
4. **`design/gdd/scoring.md`**: (a) the interface is `item_collected(slot, kind, count)`; Powerups reads the collector's chain count; (b) Open Question 3 closed (kinds GEM and MEDAL only, cap 100, Active planes only) and Open Question 6 closed: a POD at 4 drones pays a MEDAL (no new kind); (c) F7 assumes 25/40/40 medals per stage, but medals only drop from carriers (about 2 to 4 per stage solo), so update the assumptions table to 3 / 4 / 4 medals; the chain share of score goes **up**, so AC-48 is unaffected; (d) edge case "cap 100" becomes a fact, not a proposal.
5. **`design/gdd/game-events-and-session.md`**: (a) add calls `add_powerup(slot) -> int` and `add_oneup(slot) -> int` (gained); (b) Open Question 4 closed: a POD at 4 drones gives a MEDAL, a 1UP at `max_lives` gives `gained = 0` and a MEDAL; (c) F1 note: `powerups_collected` 0–2 per frame stays, but with `N = 4` up to 4 pods may arrive on one tick, so range → 0–4 per frame.
6. **`design/gdd/chain-tracker.md`**: Interactions row 13: chain pickup amount is **10** (`chain_pickup_amount`), source id `"chain_pickup"`; it refills the window per Rule 2.
7. **`design/gdd/coop-and-team-chain.md`**: Rule 10 is made concrete: add "A plane with 4 drones skips a POD while any other Active plane has fewer; the tie-break applies to all item kinds; Dead/Continue/Selecting planes collect nothing." Open Question 7 closed. Items per drop = `N`.
8. **`design/gdd/player-plane.md`**: Interactions row for Powerups: pickup radius **14 px** from the plane centre (owned by Powerups).
9. **`design/gdd/plane-kits-lancer-leech.md`**: the "powerup at 4 drones" edge case now reads: "a POD at 4 drones is not collected if another Active plane needs it; otherwise it pays a MEDAL".
10. **`design/art/art-bible.md`**: §4.6 / §5.7 add item sizes (V1) and clarify "diamond with `+` is reserved for CHAIN; GEM is a small plain diamond with no `+`". §7 keep pickup glyphs free of text.
11. **Wave director (16) contract** *(done 2026-11-03: `wave-and-stage-director.md` F5 places 8 carriers per stage, >= 1 per wave, >= 180 ticks apart, unscaled; failed carrier spawns re-queued up to 2 times)*: author at least **8 carriers per stage solo** (4 SMALL, 2 MEDIUM, 2 LARGE), at least one per wave, the first before the end of wave 1, no two carriers closer than 180 ticks apart; carrier count does not scale with `N`.
12. **Bombs (12) contract** *(when written)*: bomb cancels use `items_per_cancel_cap`; bombs make no medals; a bomb refill is not an item.

## Tuning Knobs

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `items_per_cancel_cap` | 100 | 50–200 | Bombs feel unrewarded | Bomb-cancel farming (110,000 at cap 100, F9) | Scoring `factor_cap_count`, `gem_cap` |
| `gem_cap` | 300 | 150–600 | Gem loss during big bombs | Perf; screen clutter | `items_per_cancel_cap`, perf budget |
| `drop_cap` | 24 | 12–48 | Evictions in 4P | Clutter | N, LARGE bundle |
| `pity_limit` | 2 | 1–4 | Pods nearly guaranteed, pace too fast | Long dry spells (more than 3 carriers in a row without a pod) | F2, Wave carrier count |
| SMALL pod / chain / medal weights | 55 / 25 / 20 | pod 40–70 | Slow rebuild after death | Chain and medal too rare | F2 |
| MEDIUM pod / chain / medal weights | 50 / 20 / 30 | pod 35–65 | same | same | F2 |
| `chain_pickup_amount` | 10 | 5–25 | Pickup feels pointless | Chain pickups rival hits (cap 999 reached early) | Chain `chain_window`, Scoring F1 |
| `oneup_ordinals` | [4] solo; [4, 9] at N ≥ 3 | 3–8 | 1-up too early (no weight) | Rarely seen | Session `max_lives`, extends |
| `pickup_radius` | 14 px | 10–20 | Pods feel unfair | Pickup without intent | Player plane sprite size |
| `magnet_radius` / `magnet_speed` | 36 px / 5 px/tick | 0–60 / 3.5–8 | Fiddly pickups | Items fly through bullets for the player | `move_speed` 3.5 px/tick |
| `drop_fall` | 0.8 px/tick | 0.4–1.2 | Pods linger over dangerous areas | Pods fall too fast to reach | `drop_lifetime`, F5 |
| `drop_lifetime` / 1UP lifetime | 600 / 900 ticks | 360–900 / 600–1200 | Pods lost before reached | Items pile at the bottom | `rest_y` |
| `gem_v0` / `gem_accel` / `gem_vmax` | 3 / 0.25 / 10 | see F4 | Gems lag the player | Gems appear to teleport | F4, `move_speed` |
| `gem_hold` | 6 ticks | 0–12 | No "pop" read | Gems hang too long | VFX |
| `gem_lifetime` | 300 ticks | 180–600 | Drifting gems vanish | Gem build-up | `gem_cap` |
| `sweep_speed` | 10 px/tick | 6–14 | Sweep too slow for the tally | N/A | Boss→tally delay (`sweep_min_ticks` 90, Wave director) |
| `pop_ticks` / `pop_v0` | 18 / 1.0 | see F5 | No pop read | Items rise too far | F5 |
| `bob_amp` / `bob_period` | 6 px / 90 ticks | 0–10 / 60–180 | Flat | Items hard to line up | `pickup_radius` |
| `rest_y` | 616 | 560–630 | | | Player bottom limit |
| `drop_inset` | 12 px | 8–20 | Items half off-screen | Items far from the carrier | Item sprite size |

**Owned elsewhere (not knobs here):** `max_drones` 4, `max_lives` 6 → Session (1); `item_base` gem 100 / medal 1,000, `factor_cap_count`, `factor_step` → Scoring (8); `chain_window`, chain cap → Chain tracker (7); kill-cancel radii 40 / 72 → Enemy (10); `item_inset` 8 → Bullet manager (3); carrier cadence → Wave director (16); `move_speed` → Player plane (5); drone behaviour → Plane kits (11).

> Decided under auto-approve (2026-11-03): defaults above. Balance values cite F1–F9. Numbers marked unplaytested.

## Visual/Audio Requirements

> Source of truth: `design/art/art-bible.md`. Numbers are unplaytested proposals. Audio items are proposals for the **audio-director**.

**V1. Item sprites (1x px)**

| Kind | Look | Size | Colours | Notes |
|---|---|---|---|---|
| GEM | plain diamond, no glyph | 7×7 (outline included) | Ember Gold `#FFC93C`, outline `#3A2A14` | 2 frames, 10 fps twinkle. Not a circle, ring, rice or needle |
| MEDAL | chamfered square tile with a star glyph | 15×15 | Ember Gold fill, `#3A2A14` outline and glyph | gold = score |
| CHAIN | diamond with a `+` glyph | 15×15 | Ember Gold, `#3A2A14` | the only shape with `+` (AB 4.6) |
| POD | chamfered square tile with a drone glyph | 17×17 | Cream `#F4EBD6` body, `#3A2A14` outline | matches the cream carrier rim |
| 1UP | chamfered square tile with a plane glyph and a 1 px Ember Gold rim | 17×17 | Cream body, Gold rim | rim pulses at 2 Hz |

No cool hue, no Void Indigo, no Ink outline, no ring or orb shape (bullet grammar, AB 3.3). Glyphs carry meaning, never text (deutan-safe: shape, not hue).

**V2. Draw layer.** Layer 6 (AB 6.8), with player shots and drones. Drop items draw above gems inside the layer. Nothing draws over enemy bullets (layer 8).

**V3. Motion and expiry cue.** Pop 18 ticks, bob 6 px / 90 ticks. In the last 120 ticks the item pulses opacity 100% ↔ 60% at 2 Hz (AB 8 "may pulse" rule: ≤ 40% change, ≤ 2 Hz, one element at a time; if several expire together, only the oldest pulses).

**V4. Pickup feedback.** 8-tick cluster of four 2×2 px particles in the item's colour (gold for MEDAL/CHAIN, cream for POD/1UP), below layer 8. **GEM** *(2026-11-03, wave 3b)*: one 2-frame 4 px sparkle particle, at most 1 per 2 ticks and 12 live (VFX 25), so a 100-gem sweep cannot fill the pool. POD: the sprite shrinks into the plane over 8 ticks; the new drone exists on the collection tick (Session F1) and takes a 12-tick cream rim pulse (Kits own the drone sprite). No flash (Critical Break only).

**V5. Expire / lost.** Soft 6-tick puff (smoke colour), no shockwave.

**V6. Audio proposals.** All item sounds share the bullet SFX pool of ≤ 8 voices (BM audio rule); priority below cancel, Warp cue and enemy fire.
- Gem pickup: short high tick; pitch steps up one semitone per gem within a 12-tick window, up to 8 steps; at most 1 gem sound per 3 ticks.
- Medal: bright two-note chime. Chain pickup: rising "+10" blip. Pod: distinct low-high two-note "dock" click. 1UP: the pickup itself is **silent**; the jingle `sfx_score_extend_jingle` comes from `extend_awarded(gained > 0)` (Audio 24) *(2026-11-03, wave 3b)*.
- A carrier's destruction plays its normal explosion; the pickup sounds belong to this system.

> Decided under auto-approve (2026-11-03): sizes (gem 7, medal 15, chain 15, pod 17, 1UP 17); cream = pods and 1UP, gold = score and chain; no popups for score; pulse in the last 120 ticks.

## UI Requirements

No player-facing UI of its own. HUD (20) shows the drone count (via the Kits `drone_lamp`) and, for a 1-up, a plate-local `+gained` tag and Gold edge step on the lives display (HUD 20 Rule 22; no banner; amended 2026-11-03); score numerals update through Scoring (no in-field popups). All item art is textless, so Bengali and English need no work here.

Debug tools: an overlay (toggle) with `gems_alive`, `drops_alive`, `gems_discarded`, `pity_misses`, `carriers_this_stage`, the drop-table roll log for the last 20 requests, and item hitbox/pickup-radius circles.

## Acceptance Criteria

**Defaults used:** `pickup_radius` 14, `magnet_radius` 36, `magnet_speed` 5, `gem_v0` 3, `gem_accel` 0.25, `gem_vmax` 10, `gem_hold` 6, `gem_lifetime` 300, `drop_lifetime` 600, 1UP 900, `drop_fall` 0.8, `pop_ticks` 18, `pop_v0` 1.0, `rest_y` 616, `gem_cap` 300, `drop_cap` 24, `items_per_cancel_cap` 100, `pity_limit` 2, `chain_pickup_amount` 10, `drop_inset` 12, SMALL 55/25/20, MEDIUM 50/20/30, `oneup_ordinals` [4] / [4, 9], `sweep_speed` 10.

**Test setup:** node-free `PowerupSystem extends RefCounted` with `tick()` and request methods. Tests in `tests/unit/test_powerups_*.gd`, `extends SceneTree` like `tests/unit/test_chain_tracker.gd`, with stubs for Session, ChainTracker and Scoring that log calls, a fake plane provider (position, Active flag per slot), an injected seeded `RandomNumberGenerator` and an integer tick counter. Every number is read from `data/powerup_rules.tres` and `data/drops/drop_tables.tres`, never a literal.

- **AC-01 [Unit] (Rule 1, data):** all defaults load from the `.tres` files; changing `pickup_radius` in the file changes F6 results with no code change. A missing key logs one data warning.
- **AC-02 [Unit] (Rule 1, POD):** slot 0 at `drone_count` 1 collects a POD → Session stub receives `add_powerup(0)` once; no Scoring call.
- **AC-03 [Unit] (Rule 22, overflow):** sole Active slot at 4 drones collects a POD → no drone call, `item_collected(0, MEDAL, count)` once.
- **AC-04 [Unit] (Rule 25, chain):** count 40, CHAIN collected → `add_bonus(0, 10, "chain_pickup")` once; stub tracker count 50; no `chain_hit`; no Scoring call.
- **AC-05 [Unit] (Rule 1, 1UP):** lives 2, 1UP → `add_oneup(0)` once; lives 3 in the stub; no Scoring call. Lives 6 → `gained = 0` and `item_collected(0, MEDAL)`.
- **AC-06 [Unit] (Rule 2, guardrail):** a static scan of the public API lists only four outward calls: Session `add_powerup` / `add_oneup`, ChainTracker `add_bonus`, Scoring `item_collected`, plus signals. No call touches damage, fire rate, bombs, meter or cooldown.
- **AC-07 [Unit] (Rule 3):** `drop_requested` is the only way drops are created; a non-carrier kill sends none → pools empty. A carrier that escapes → pools empty.
- **AC-08 [Unit] (Rule 6, SMALL table):** `r` = 54 → POD, 55 → CHAIN, 79 → CHAIN, 80 → MEDAL, 99 → MEDAL (pity 0).
- **AC-09 [Unit] (Rule 6, MEDIUM table):** `r` = 49 → POD, 50 → CHAIN, 69 → CHAIN, 70 → MEDAL.
- **AC-10 [Unit] (Rule 6, LARGE):** N = 1 → one POD and one MEDAL regardless of `r`; the pity counter is unchanged.
- **AC-11 [Unit] (Rule 7, F1 pity):** rolls 62, 90, 99 on SMALL → CHAIN, MEDAL, POD (forced), `misses` 1, 2, 0.
- **AC-12 [Unit] (Rule 7, recovery pod):** `player_died(1)` then a SMALL drop with `r` = 99 → POD; `misses` 0 after.
- **AC-13 [Unit] (Rule 8, F1 need):** N = 4, `k` = 1, LARGE drop → 1 POD and 4 MEDALs. `k` = 0 with a POD roll → MEDAL.
- **AC-14 [Unit] (Rule 5, F6 rows):** N = 3 → three items at x offsets −14, 0, +14 around the drop; N = 1 → offset 0; N = 4 → −21, −7, 7, 21.
- **AC-15 [Unit] (Rule 9, RNG discipline):** every `drop_requested` consumes exactly 4 draws for N = 1, 2, 3, 4, LARGE, substituted or not; the draw count after 100 requests is 400.
- **AC-16 [Unit] (Rule 11, 1UP schedule):** solo: the 4th carrier's drop includes a 1UP, the 9th does not. N = 3: the 4th and 9th do. N = 3 with all lives at 6 → both are MEDALs.
- **AC-17 [Unit] (Rule 12, F3 sampling):** n = 1350 → 97 gems; n = 100 → 100; n = 101 → 51; n = 250 → 84; n = 0 → 0. Kept indices are exactly the multiples of `stride`.
- **AC-18 [Unit] (Rule 14, bomb):** a 1,350-bullet full-screen cancel with `cause_slot` 2 → 97 gems, 0 medals, 0 pods; all gems have cause slot 2.
- **AC-19 [Unit] (Rule 13, pools):** 300 gems alive, a new cancel → 0 new gems, `gems_discarded` rises; a POD drop still succeeds (drop pool separate).
- **AC-20 [Unit] (Rule 17, F4):** gem speeds at t = 0, 14, 28, 40 → 3, 6.5, 10, 10; distance over 28 ticks = 178.5 px.
- **AC-21 [Unit] (F4 timing):** gem 300 px from a stationary Active cause plane → collected on `t` = 39 after the 6-tick hold (45 ticks total); it never overshoots.
- **AC-22 [Unit] (Rule 17, hold):** a gem made on tick T has the same position on T … T + 5 and starts moving on T + 6.
- **AC-23 [Unit] (Rule 17, orphan):** cause slot Dead → gem drifts down 0.8 px/tick; on the first tick the slot is Active again it flies. A different Active plane that touches it collects it.
- **AC-24 [Unit] (Rule 24):** gem collected by slot 1 while the cause slot is 0 → `item_collected(1, GEM, count_of_slot_1)`.
- **AC-25 [Unit] (Rule 17, lifetime):** an unreachable gem is removed after 300 ticks, `item_expired` fires once.
- **AC-26 [Unit] (F6, boundary):** POD at distance 22 → collected; 23 → not. GEM 18 → collected; 19 → not. MEDAL / CHAIN 21 → collected; 22 → not.
- **AC-27 [Unit] (Rule 21, tie):** planes with 2 and 3 drones overlap a POD on the same tick → the 2-drone plane gets it. Equal drones → lowest slot. One plane overlaps on an earlier tick → it wins regardless of drones.
- **AC-28 [Unit] (Rule 20, skip):** plane A (4 drones) and plane B (1 drone) both overlap a POD → B collects. A alone overlapping while B is Active → not collected. All Active at 4 → overflow MEDAL.
- **AC-29 [Unit] (Rule 20, states):** Dying, Dead, Continue, Selecting and Inactive planes overlapping an item → nothing collected.
- **AC-30 [Unit] (Rule 23, death wins):** a plane that is hit on tick T and overlaps a POD on tick T → not collected; it stays in the pool.
- **AC-31 [Unit] (F5, drop motion):** rise total 9.5 px over 18 ticks; then +0.8 px/tick; x offset from bob never exceeds 6 px; a drop starting at y 200 rests at 616 by about tick 550.
- **AC-32 [Unit] (Rule 15, rest and life):** item at `rest_y` stays; a POD expires at tick 600, a 1UP at 900. The last 120 ticks flag `pulse = true` (one item at a time).
- **AC-33 [Unit] (Rule 16, magnet):** POD at d = 36 from an eligible plane moves toward it at 5 px/tick and is collected in 3 ticks; at d = 37 it does not move toward the plane; an ineligible plane (4 drones, partner needy) does not attract it.
- **AC-34 [Unit] (Rule 18, sweep):** at `boss_defeated` with 40 gems and 2 PODs in the field, all are collected by Active planes at 10 px/tick; the farthest (730 px) arrives within 73 ticks. Items present at `stage_cleared` are removed with no Scoring calls.
- **AC-35 [Unit] (stage start):** `stage_started` clears pools, sets `pity_misses` 0 and `carriers_this_stage` 0, reseeds the stream (same seed + stage index → same sequence).
- **AC-36 [Unit] (edge, drop pool):** 24 drop items alive with some MEDAL/CHAIN; a new POD evicts the oldest MEDAL/CHAIN; with only PODs/1UPs alive, a new MEDAL is discarded and counted.
- **AC-37 [Unit] (edge, same tick):** two carriers destroyed on one tick → processed in enemy id order; the second sees the first's pity result.
- **AC-38 [Unit] (edge, chain cap):** count 995 + CHAIN → 999, milestones checked, window refilled.
- **AC-39 [Unit] (F2):** with SMALL weights 55/25/20 and `pity_limit` 2, a 100,000-drop simulation gives a POD fraction within 0.605 ± 0.01. MEDIUM → 0.571 ± 0.01.
- **AC-40 [Unit] (F2 income):** the contract mix (4 / 2 / 2) at `kill_rate` 1 → 5.56 expected pods ± 0.1; at 0.85 → 4.73 ± 0.1. A max dry spell of non-pod SMALL/MEDIUM drops never exceeds `pity_limit`.
- **AC-41 [Unit] (F9):** 100 gems at chain 500 → 110,000 total points through the Scoring stub; at chain 80 → 20,000.
- **AC-42 [Unit] (determinism):** two runs with the same `run_seed`, scripted events (50 drop requests, 6 cancels, 3 deaths, pickups, a sweep) → `state_hash()` equal every tick and identical call logs to Session, Chain and Scoring. Adding an unrelated enemy kill without a carrier flag does not change any hash or log.
- **AC-43 [Integration] (real BM + Scoring):** a real `BulletField` cancel and a real `Scoring` → 97 gems collected; points equal `Σ 100 × (1 + min(count, 500) / 50)`.
- **AC-44 [Integration] (Session):** a real Session: POD 1 → 2 drones, death → 0, recovery pod after next carrier; stage carry-over keeps `drone_count` (Session AC-04).
- **AC-45 [Integration] (Co-op 4P):** 4 slots, a LARGE carrier at N = 4 with `k` = 4 → 5 items placed in a row; each plane collects the one nearest; no slot gets 2 PODs unless it overlaps both on separate ticks.
- **AC-46 [Perf] (REF-WEB):** 300 gems + 24 drop items + 4 planes, 10,000 ticks → `tick()` ≤ **0.15 ms p99**, no allocations after warm-up (packed arrays, fixed capacities). Pack for the two MultiMeshes ≤ **0.10 ms** per frame. If the first measure is under 0.05 ms, tighten the budget.
- **AC-47 [Perf] (cancel burst):** a 2,000-bullet cancel → sampling and gem spawn ≤ 0.10 ms.
- **AC-48 [Manual] (V1, readability):** in a grayscale capture with 300 gems and a 1,500-bullet 4P scene, every item kind is distinguishable by shape and size from every bullet shape; no item uses a cool hue or ring/orb/rice/needle shape.
- **AC-49 [Manual] (V3/V4, no effects over bullets):** pickup particles and pulses draw below layer 8 in every state; no flash.
- **AC-50 [Manual] (V6, audio):** a 100-gem pickup produces ≤ 1 gem sound per 3 ticks and never starves the cancel / enemy fire voices.
- **AC-51 [Manual] (feel, pod risk):** in a playtest of the dev stage, a tester can collect a pod dropped in the middle of a medium curtain at least 2 times in 3 attempts without dying by focus-speed routing alone. Record the result.
- **AC-52 [Manual] (anti-grinding):** a designer reviews the full item list and API and confirms no stat other than `drone_count` persists, and `drone_count` resets on death.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Should the chain pickup refill the chain window (accepted here via Chain tracker Rule 2), or only add count? | Designer, Chain tracker (7) | First playable stage |
| 2 | ~~Are 8 carriers per stage (4 SMALL, 2 MEDIUM, 2 LARGE) feasible for the wave design?~~ **Closed 2026-11-03:** yes, Stage 1 and 2 outlines place all 8 (wave-and-stage-director.md F5). Still open: is 0.85 of a stage a good rebuild time after a death? | Wave director (16), playtest | Wave director GDD |
| 3 | ~~Time between `boss_defeated` and `stage_cleared`: the sweep needs ≥ 75 ticks (73 px/tick math, F6).~~ **Closed 2026-11-03:** the Wave director emits `stage_cleared` at `max(boss_gone, boss_defeated + sweep_min_ticks)` with `sweep_min_ticks` 90 (>= 75), watchdog at `boss_defeated` + 360 (wave-and-stage-director.md Rule 24; Stage tally's `boss_gone + 30` proposal not adopted, Director owns the timeline). | Boss (14), Session (1) | Boss GDD |
| 4 | Final Session API names and signal names for `add_powerup` / `add_oneup` / `drone_gained`. | Session (1) | Implementation |
| 5 | Add `kill_class` to `drop_requested` (removes the lookup)? | Enemy (10) | Next Enemy edit |
| 6 | ~~Do bosses and boss parts drop anything (a medal on part kill)? Default: no.~~ **Closed 2026-11-03:** no. Boss parts pay score, chain +5 and a cancel only (Boss 14 Rule 24); no `drop_requested`. | Boss (14) | Boss GDD |
| 7 | Do 1-ups need to exist at all with 2 score extends and continues? Revisit after playtest; the schedule is one knob. | Designer | Playtest |
| 8 | Is a 14 px pickup radius right for the final plane sprites? | Player plane (5), art | Sprite pass |
| 9 | ~~Should items pulse on the grid for colourblind players with the Accessibility option (stronger outline)?~~ **Closed 2026-11-03:** no item pulse option; item shapes and the existing expiry pulse suffice (accessibility-options.md) | Accessibility (28) | Accessibility GDD |
| 10 | Kit-specific effects of a new drone while the ability is running (e.g. Leech latched) are owned by Kits; confirm there is no free-ability-refill leak. | Plane kits (11) | Kits review |
