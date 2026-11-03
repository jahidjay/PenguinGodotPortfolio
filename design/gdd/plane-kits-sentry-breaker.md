# Plane Kits and Bombs: Sentry, Breaker

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Four Planes, Four Games (primary: two more chain routes), Every Hit Counts (all kit hits count; erasing never counts), Readable Chaos (bounded, visible, item-free erasing)

## Overview

**The data layer:** this GDD adds two **plane kits** (Sentry, Breaker) and their two **bomb effects** (Bastion, Backlash) to the shared systems already specified in `plane-kits-lancer-leech.md` ("LL") and `bombs.md`. Each kit is a node-free `RefCounted` class (one per slot, `tick()` at 60 Hz, no `delta`, no randomness) that inherits LL Rules 1-15 unchanged: buttons, Active-only, the Fire state machine (tap = normal shot with a 12-tick linger, hold >= 18 ticks = the plane's charge mode), the single `shot_cd`, idle drone bullets, damage events, hit results, reset rules and target eligibility. Both reuse the LL drone state machine (docked, flying, returning, the 45-tick return cap, cooldown from the last dock) through a shared `DroneBank` (answers LL Open Question 15; lead-programmer to confirm). New here: **Sentry** owns *emplaced turrets* (world-anchored, auto-aiming, early recall) and an *Entrench* cannon; **Breaker** owns an *Erase Net* (drones that request circle cancels from the Bullet manager), a **return stock** filled by erased bullets, and a *Breach* charge that spends the stock as seeking bolts. The two bomb effects plug into `BombCore` and obey every Bombs rule (stock 3, 90-tick lockout, 90-tick invulnerability, toll, full-screen cancel with items on the press tick, 1,000 damage per target cap, counts no chain hits, reads no kit state). All numbers are integers in ticks, px and damage units and live in `data/kits/*.tres` and `data/bombs/*.tres`.

**The player impact:** the four planes now chain four different ways. **Lancer** converts *damage* into a meter and a shield; **Leech** converts *attachment* into guaranteed hits; **Sentry** converts *territory* into hits (the player plants guns where enemies will be, then flies free); **Breaker** converts *the enemy's own bullets* into hits (the net eats bullets, each bite loads a bolt, the bolt finds an enemy). Sentry is the zone-control plane: its chain survives while the player dodges, but only where the turrets reach. Breaker is the defensive-offence plane: its chain grows when the screen is densest. Neither plane gets stronger from anything but drones, and both lose them on death. The Breaker net is **bounded on purpose** (30 bullets per drone per use, never near the hitbox, never gives gems), so it thins a curtain without ever removing it, and the screen stays readable.

## Player Fantasy

**Direct: the player feels the kit in their thumb every second.** MDA aesthetics: **Challenge** and **Expression** (how you chain), **Fantasy** (the emplacement and the battering ram), with **Relatedness** in co-op (the Bastion shelters allies).

- **Sentry: "I own this patch of sky."** The anchor moment: wave 3 is about to cross the left side. The player taps Drone, four turrets fly out, plant with a thud and start swivelling. The wave enters their range and the chain never drops while the plane slides away from the bullets. Later the player taps Drone again to pick the guns up early and re-plant them where the boss's turrets are. The fantasy is *control through placement*: the guns are where you chose, and the plane is free.
- **Breaker: "Your bullets are my ammunition."** The anchor moment: a curtain closes. Four wedge drones slide ahead of the plane and bite holes in it; each bite clicks the stock bar up. The player holds Fire, the nose lights, and bolts leave the plane one after another and find the closest enemy. The chain, which was about to die in the bullets, climbs *because* of them. The fantasy is *defensive offence*: the more they shoot, the more I hit.
- **Tap vs hold.** Tap Fire is the fast, light shot. Hold Fire (0.3 s) commits: Sentry's nose cannon (slow, heavy, tracking drones) or Breaker's Breach (heavy slug plus bolts). The same button asks "do I move, or do I commit?" (Autonomy).
- **Honest power.** The Sentry turret range, the Breaker net brackets, the spent-drone dimming and the stock bar are all visible. A bullet vanishes only inside a drawn zone (Competence, Readable Chaos).
- **Bombs with a personality.** **Sentry's Bastion**: a dome of light grows around a point ahead of you, wipes bullets inside it and hurts what stays; allies can stand in it. **Breaker's Backlash**: a bright bar races up the whole screen from your nose to the top, wiping bullets and striking every enemy it passes once.
- **A growing escort, a harsh reset.** Each drone adds a visible gun or zone; death removes all of them, the Breaker stock and the cooldown.

It serves **Four Planes, Four Games** (each plane has its own resource or placement rule and its own risk), **Every Hit Counts** (erasing is not a hit; the bolt it buys is) and **Readable Chaos** (zones are drawn at their true size, drawn under bullets, and item-free).

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

Units: **tick** = 1/60 s; **px** on the 360x640 canvas; **damage unit** (integer). Standard bullet = **20 damage** = `armour_damage_min` (Collision C4), so every damage value below is safe on armour (checked by data test). `d` = drone index 0..3 in wing-slot order (0 inner-left, 1 inner-right, 2 outer-left, 3 outer-right; Player plane Rule 11). `t` = the global tick counter. `h` = ticks since the Fire press (LL Rule 2).

**A. Inherited from LL and shared by both kits**

1. **Inheritance.** LL Rules 1-15 apply to Sentry and Breaker **unchanged**, with these specific consequences: Active only (Rule 3); SHOT then CHARGE at `h = 18` (Rule 4); 12-tick tap linger (Rule 5); one shared `shot_cd` per kit (Rule 6); focus speed from the plane while Fire is down (Rule 7); requests via the Bullet manager, Straight only, refusals lost with no retry (Rule 8); idle drone bullets at phase `(d x 8) div 4` (Rule 9); damage events with per-slot `seq` (Rule 10); hit results back to the kit (Rule 11); no value rises with drones, eras, chain, score or time (Rule 12); reset rules (Rule 13, extended in Rule 40 below); eligibility (Rule 14); queries `first_in_column` and `nearest` (Rule 15). **HOLD_PLAIN does not exist** for these kits: charge mode is always available at `h = 18` (no resource edge check), as for Leech.
2. **Bullet tags.** `tag` 0 = plane normal shot, 1 = drone bullet (idle drone, Sentry turret), **2 = charge shot** (Sentry cannon shell, Breaker slug), **3 = return bolt** (Breaker). Tags 2 and 3 are new (Amendment 2). Tags 2 and 3 are the only **charge-source** hits for Critical Break (Rule 38).
3. **Idle drones.** Docked drones fire normal drone bullets while the plane's shot is on (LL Rule 9): diamond, damage 20, tag 1, straight up, every 8 ticks at phase `(d x 8) div 4`. Exception: Sentry in CHARGE aims them (Rule 10). A drone that is flying, emplaced, in the net or returning fires no idle bullets.
4. **The Drone button (both kits).** Accepted only if the plane is Active, the ability is READY (cooldown 0, drones not deployed) and `drone_count >= 1`. Neither kit needs a target (a Sentry pre-places turrets before the wave arrives; the Breaker net works with no enemy on screen). Rejected presses start no cooldown and emit `drone_denied(slot, reason)` with reason `NO_DRONES`, `COOLDOWN` or `ACTIVE`. Sentry's second-press recall is in Rule 14.
5. **Return and cooldown (both kits).** When the ability ends (timer 0, or Sentry recall) every deployed drone is RETURNING: each tick, if within `return_dock_r` = 10 px of its wing slot (the slot moves with the plane) it docks, else it moves `return_speed` = 10 px toward it; after `return_cap` = 45 ticks any drone still out snaps to its slot (LL Rule 31). The cooldown starts when the **last drone docks** (Sentry 480, Breaker 600 ticks). At 0 the ability is READY.
6. **Stage clear and death.** `stage_cleared`: the ability ends at once, deployed drones snap to their slots and dock, cooldown 0, charge stops, Breaker `stock` and `drone_count` carry over. `plane_died(slot)` (once): all drones removed, Fire IDLE, ability READY with cooldown 0, `shot_cd = 0`, Breaker `stock = stock_death_keep` (0), no further requests. Pending Breaker cancel reports for a dead slot are dropped (Rule 29).
7. **New drone during the ability.** If `drone_count` rises while drones are deployed, the new drone appears docked in the next free wing slot, fires idle bullets, and does not join the running ability (LL Rule 32).
8. **Hit-rate caps.** Every damage source has a fixed interval and phase, so no kit exceeds the per-source rates in K9. Raw maximum **67 counted hits/s** (Breaker net + Breach + bolts) and **58.3** (Sentry), both below the registry `kit_max_hits_per_s` 72; `chain_cap` 999 takes at least **14.9 s** (data test, AC-30). Sentry sends no kit damage events (all its damage is bullets); Breaker sends at most **1** kit damage event per tick (net ram, Rule 27).
9. **Live bullet cap.** At most **48 live player-pool bullets per slot** (K10: Sentry 46, Breaker 40), so a 4P game holds at most 184 of the 600 `player_cap`.

**B. Sentry (twin guns, nose cannon, emplaced turrets)**

10. **Normal shot.** Volley every **5** ticks (12 volleys/s): **2** streak bullets, damage **20**, tag 0, muzzles `(-8, -12)` and `(+8, -12)`, heading straight up (a parallel pair 16 px apart). Peak 24 bullets/s.
11. **Charge mode = Entrench** (`charge_kind = ENTRENCH`). From `h = 18` the normal shot is replaced by a **nose cannon**: **1** streak shell per volley, damage **50**, tag 2, muzzle `(0, -18)`, straight up, one volley every **6** ticks (10/s), using the shared `shot_cd` (the first shell fires when the cooldown reaches 0). While Entrench is on the kit reports `set_ability(true, 75)` (`entrench_speed` 75 px/s = 1.25 px/tick; the plane moves slower than Leech's focus 105; this is the cost of the tracking drones). It stops when Fire is released, with no linger. `charge_active` is true on every Entrench tick.
12. **Tracking drones (Entrench only).** While Entrench is on, each **docked** drone's idle bullet is aimed instead of straight: target = `nearest(drone position, eligible)` whose centre is above the drone (`cy < drone.y - 8`) and within `track_range` = 220 px; velocity `15 x unit(dir)` with the angle from straight up clamped to `track_max_deg` = 25 (SB1). No qualifying target: straight up. Damage and rate are unchanged (20 every 8 ticks). With 0 drones this rule does nothing.
13. **Emplace (Drone ability).** On an accepted press at plane position `(x_p, y_p)` the state is ACTIVE with timer **`emplace_ticks` = 420** (7 s). Each docked drone `d` gets a fixed **post** `P_d = (clamp(x_p + post_dx[d], 14, 346), clamp(y_p - 110, play_top + 40, 560))` with `post_dx = [-60, +60, -110, +110]` (SB2). Posts are **world-anchored**: they do not follow the plane. The drone flies straight to its post at `post_speed` = 10 px/tick; on any tick where the distance at the start is <= 10 it snaps and becomes **EMPLACED**. A flying drone cannot be hit, fires nothing and deals no damage.
14. **Early recall (Sentry only).** While ACTIVE and at least **`recall_min_ticks` = 60** ticks since the press, a Drone press is accepted and sends every deployed drone to RECALL at once. Before tick 60 the press is denied with `ACTIVE`. In RECALL the press is denied with `ACTIVE`; in COOLDOWN with `COOLDOWN`. The cooldown (480) starts at the last dock regardless of when the recall happened, so recalling early shortens the cycle (Rule 5).
15. **Turret fire.** An EMPLACED drone fires on ticks `t` with `t mod 7 == phase_d`, `phase_d = (d x 7) div 4` (0, 1, 3, 5). On such a tick: `T = nearest(post, eligible)`; if `T` exists and `dist(post, T.centre) <= turret_range` = **160** px, request one **diamond** bullet, damage **40**, tag 1, velocity `15 x unit(T.centre - post)` from the post. Otherwise nothing is requested (the phase still advances). Turrets need no Fire input. Ties go to the lowest target id. Aim has no lead (SB1). A turret never moves and cannot be hit.
16. **Timer end.** At `emplace_ticks` the ability goes to RECALL; the cooldown is 480 ticks from the last dock. The ability does not depend on `drone_count` after launch.
17. **Sentry bomb: Bastion** (Rule 31).

**C. Breaker (ram shot, Breach charge, Erase Net)**

18. **Normal shot ("Ram").** Volley every **3** ticks (20/s): **1** streak bullet, damage **30**, tag 0, muzzle `(0, -20)`, straight up. Peak 20 bullets/s.
19. **Charge mode = Breach** (`charge_kind = BREACH`). From `h = 18` the normal shot is replaced by a **slug**: 1 streak bullet, damage **40**, tag 2, muzzle `(0, -20)`, straight up, every **4** ticks (15/s), using the shared `shot_cd`. While Breach is on the kit also fires **return bolts** (Rule 20). The kit reports no `ability_active` (the plane's `focus_speed` 105 applies while Fire is down). It stops when Fire is released.
20. **Return bolts.** Each Breach tick, after the slug check, if `bolt_cd == 0` and `stock >= bolt_cost` (2) and `T = nearest(muzzle, eligible)` exists with `dist(muzzle, T.centre) <= bolt_range` = **360** px: request one **streak** bullet from the muzzle `(0, -20)` (plane-relative), speed **18 px/tick** (1,080 px/s, below the 1,200 player cap), velocity `18 x unit(T.centre - muzzle)`, damage **40**, tag 3; `stock = stock - 2`; `bolt_cd = bolt_interval` = 5 (12 bolts/s). `bolt_cd` is separate from `shot_cd`, counts down 1 per tick (min 0), is not reset by presses, and the stock is spent at the request (a refused bolt is lost, as LL Rule 8). Bolts fire only in Breach: out of Breach the stock is kept.
21. **Return stock.** `stock` is an integer `0..stock_max` (**60**). It rises **only** through Rule 25 (erased bullets). It never rises from hits, bombs, pickups, time or kills and never decays. Death: `stock = stock_death_keep` (0). Stage clear: kept. The stock is a run-only value (not shown or saved outside the run).
22. **Erase Net (Drone ability).** On an accepted press the state is ACTIVE with timer **`net_ticks` = 300** (5 s). Each docked drone `d` flies to its **station** `S_d`, recomputed every tick: `S_d = (clamp(plane.x + st_dx[d], 26, 334), max(play_top + 14, plane.y - 70))` with `st_dx = [-24, +24, -72, +72]`. The drone moves `station_speed` = 12 px/tick toward `S_d`; on a tick where the distance at the start is <= 12 it snaps to `S_d` and is **NET_ON**. From then on its position is `S_d` every tick (rigid with the plane, like a docked drone but ahead). Its **zone** is the circle of radius `net_r` = **26** px around it.
23. **Net budget.** Each drone has a `tally` (starts 0 on press). When `tally >= net_budget` (**30**) the drone is **SPENT**: it stops requesting erases (Rule 24) but keeps ramming (Rule 25) and stays in position until the timer ends.
24. **Erase pulse.** A NET_ON drone that is not SPENT requests, on ticks `t` with `(t + d) mod net_pulse_interval == 0` (`net_pulse_interval` = 2), one **circle cancel** of radius 26 around its position: `request_cancel(circle, cause = slot, items = false)`. It is skipped on that tick if `dist(drone, plane) - net_r < net_safe_clear` (**40** px; the net never covers the plane's hitbox neighbourhood, SB5). Cancels are **never** requested with `items = true` by a kit (decision, Rule 33). A tick with two drones pulsing (parity) sends at most 2 requests per slot.
25. **Reports and stock fill.** The Bullet manager publishes one per-tick `cancel_report[]` with entries `(request_id, cause_slot, area, items, count, positions_in_pool_order)`; the kit reads its own entries (matched on `cause_slot` + `request_id`) at the start of the next tick (Amendment 2; merged report, BM Rule 13, 2026-11-03). For a report of `count` bullets: `tally_d = tally_d + count` and `stock = min(stock_max, stock + min(count, credit_per_pulse_cap))` with `credit_per_pulse_cap` = **4**. So a pulse that removes 30 bullets gives 4 stock; a drone gives at most **32** stock per activation (SB4).
26. **What the net erases.** Only the **enemy pool**, every shape and every source (patterns, boss bullets, kill-cancel leftovers); never player bullets, never score items, never a plane. A bullet that spawns inside the zone on a pulse tick is erased (cancel runs after spawns, Bullet manager Rule 7). A bullet inside two zones of the same or different slots on one tick is removed once, by the first request processed (FIFO) and counted only in that request's report. Erase is **not** a hit: it never sends `chain_hit`, never pays score and never touches Boss state. A bullet can be erased only while it is inside a drawn zone (no hidden erase).
27. **Net ram.** A NET_ON drone (SPENT or not) on ticks `t` with `t mod 6 == (d x 6) div 4` (0, 1, 3, 4) looks for the eligible targets whose hurtbox circle overlaps its zone (`dist(drone, centre) < net_r + r_h`, strict); if any, it sends **one** damage event of **40**, source **DRONE**, to the one with the lowest id. Immune targets are not eligible (no event). The ram needs no Fire input.
28. **Net end.** At `net_ticks` the ability goes to RECALL; the cooldown is **600** ticks from the last dock. There is no early recall (Rule 4 reason `ACTIVE`).
29. **Pending reports.** A report for a request made before the drone returned still credits `stock` (not `tally`, which is gone); a report for a dead or reset slot is dropped. Reports arrive in request order.
30. **Breaker bomb: Backlash** (Rule 32).

**D. Bombs (BombCore effects)**

31. **Sentry: Bastion.** All Bombs rules (1-17, 30-34) apply. Origin: `C = (clamp(x0, 0, 360), max(play_top, y0 - 56))` with `(x0, y0)` the plane position at `k = 0`; the dome is **world-anchored** (does not follow the plane). Radius `r(k) = min(bastion_r_max, bastion_r0 + bastion_grow x k)` = `min(104, 40 + 4k)` (reaches 104 at `k = 16`). It lasts `bastion_ticks` = **72** ticks (`k = 0..71`; `effect_ticks` = 72, always). `k = 0`: the Bombs full-screen cancel with items (Bombs Rule 13). `k = 1..71`: each tick one **circle cancel** of radius `r(k)` at `C`, **no items**. Damage: on ticks with `k mod bastion_interval == 0` (6), every non-immune target whose hurtbox circle satisfies `dist(C, centre) <= r(k) + r_h` takes **one** event of `bastion_damage` = **60** (PART 36); the 1,000 cap applies (at most 12 events x 60 = 720 per target). Planes are never hurt (Co-op Rule 8). Allies standing inside the dome are safe from bullets that enter it (the cancel removes them); only the bomber is invulnerable.
32. **Breaker: Backlash.** All Bombs rules apply. `y0` = plane y at `k = 0`. The **wall** is a full-width rectangle (centre `x = 180`, `half_w = 180`, `half_h` = `backlash_half_h` = 12) at `y_w(k) = y0 - backlash_speed x k` = `y0 - 12k`. `k = 0`: the Bombs full-screen cancel with items. `k = 1 .. effect_ticks - 1`: one **rectangle cancel** at the wall, **no items**. Damage: the first tick a non-immune target's hurtbox satisfies `|cy - y_w(k)| < backlash_half_h + r_h` it takes **one** event of `backlash_damage` = **500** (PART 300), and never another from this bomb (set of hit ids). Targets below the wall (lower on screen than `y0 + 12 + r_h`) at `k = 0` are not hit; targets that appear below the wall later are not hit. `effect_ticks = floor((y0 + 12 - play_top) / 12) + 1` (SB7; 2-49). The wall never hurts planes.
33. **Erase and items decision (Breaker).** The kit's cancels give **no gems** (`items = false`). Reasons: (a) a continuous net with items would hand Powerups up to `items_per_cancel_cap` (100) gems per request, 150 requests per drone per activation, which is a farm; (b) gems would flood the screen at the moment the net is working (Readable Chaos); (c) the reward is the stock and the bolts, which pay in chain hits. The Breaker's score for erasing is therefore indirect and small (a design cost accepted for clarity).
34. **No Readable-Chaos regression (summary of guarantees).** The Breaker erase is: bounded (30 bullets per drone per activation, overshoot <= one pulse; at most 8 bullets/s average, SB4); local (a 26 px circle, drawn); clear of the hitbox (>= 40 px); item-free; drawn under enemy bullets (layer 5); and never modifies a surviving bullet. Pattern authors may assume at most about 120 bullets per Breaker per 930 ticks are removed by the net (Amendment 11).
35. **Bomb independence (Bombs Rule 7).** Neither bomb reads kit state: drones, Breaker stock, turrets and the net are not read, spent or changed by a bomb; the bomb does not interrupt Entrench or Breach and costs or fills no stock. A bomb is identical with 0 and 4 drones.
36. **Bastion and Backlash obey the lockout.** Both effects end before `bomb_lockout` 90 (72 and at most 49 ticks); the invulnerability (90) outlasts both.
37. **Co-op.** Turrets, nets and stock are per slot. Net cancels are shared field effects (Co-op Rule 9): they clear bullets for everyone, items none, credit (stock) only to the requester. When two requests cover one bullet in a tick, the one processed first (FIFO) removes it and gets the count; kit ticks run in the rotating rank `rank = (slot - (t mod 4) + 4) mod 4` (the same rotation as Bombs Rule 1) so neither slot is favoured over time.
38. **Critical Break contract (provisional, answers LL Open Question 8 for these kits).** Each tick the kit publishes `charge_active(slot)` (true on every Entrench tick / every Breach tick, false otherwise; Entrench and Breach have no grace window), `charge_kind(slot)` (`ENTRENCH` or `BREACH`; presentation only, CB reads no rule from it), `charge_last_hit(slot)` as `(target_id, tick)` of the last counted **tag 2 or tag 3** result (cannon shell, slug, bolt), plus `stock(slot)` (Breaker) and `drone_state(slot)` (same shape as LL Rule 40; ACTIVE while posts/turrets or the net are out). Sentry turret bullets (tag 1), idle bullets, the net ram and bombs are **not** charge. CB owns the trigger; the kit never triggers, ends or changes anything because of a break. A bomb press never interrupts Entrench or Breach.
39. **Era hook (Era shift 19).** One `EraKitSkin` and one `EraBombSkin` per era per plane (`data/kits/skins/*.tres`, `data/bombs/skins/*.tres`) may change only sprite and animation ids, sound ids, colour tint within the warm range, and muzzle positions within +/-4 px. They may not change any damage, interval, count, angle, speed, radius, width, budget, cooldown, duration or stock number (AC-44). Eras 3-4 of these planes are Target-tier art.
40. **Reset summary (extends Rule 6).** `plane_died`: Sentry posts and turrets vanish; Breaker net, drones and stock reset to 0. `stage_cleared`: Sentry turrets snap home, Breaker net ends, bolts in flight stay and hit (no chain if the slot is not Active, Collision C5).
41. **No prototype exists** for Sentry or Breaker (only the concept's old ideas: stationary turrets, bullet-erasing drones); nothing is migrated.

> Decided under auto-approve (2026-11-03): Sentry = twin parallel shot (24/s), Entrench cannon (50 x 10/s) with aimed idle drones and ability speed 75, world-anchored turrets (range 160, 40 damage every 7 ticks) with early recall after 60 ticks, cycle 420/30/480; Breaker = 30-damage ram shot (20/s), Breach slug (40 x 15/s) plus seeking bolts that cost 2 stock, a plane-relative Erase Net (300 ticks, 4 drones, radius 26, pulse every 2 ticks, budget 30 per drone, 40 px clearance), erase gives stock (max 4 per pulse, cap 60) and no gems, net ram 40 every 6 ticks, cycle 300/30/600 with no early recall; both charge modes always available; stock carries across stages and resets on death; Bastion (dome r 40 to 104, 72 ticks, 60 per 6 ticks) and Backlash (wall 12 px/tick, 500 once per target); kit sources reuse DRONE; era skins visual only.

### States and Transitions

**Fire state (per slot).** As LL (IDLE, SHOT, CHARGE) **without HOLD_PLAIN**: `SHOT -> CHARGE` at `h == 18` always. CHARGE = Entrench (Sentry) or Breach (Breaker). Release from CHARGE has no linger. Any state goes to IDLE on `plane_died`, `stage_cleared`, or the plane not Active.

**Sentry ability (per slot)**

| State | Meaning | -> Next | Trigger |
|---|---|---|---|
| READY | Cooldown 0, drones docked | ACTIVE | Drone pressed and accepted (Rule 4) |
| ACTIVE | Timer 420 running; posts assigned | RECALL | Timer 0; or a Drone press at >= 60 ticks since the press (Rule 14); or `stage_cleared` (instant snap, then READY) |
| RECALL | Drones returning (cap 45 ticks) | COOLDOWN | Last drone docked |
| COOLDOWN | Counting 480 | READY | Cooldown 0 |
| Any | | READY (cooldown 0, no drones) | `plane_died` |

**Sentry drone**

| State | -> Next | Trigger |
|---|---|---|
| DOCKED | FLYING_OUT | Ability accepted (and `drone_count` includes it at press) |
| FLYING_OUT | EMPLACED | Distance to post <= 10 at the start of a tick (snap) |
| EMPLACED | RETURNING | Timer 0 or recall |
| FLYING_OUT | RETURNING | Timer 0 or recall |
| RETURNING | DOCKED | Within 10 px of the slot, or return cap 45 |
| Any | removed | `plane_died` |

**Breaker ability (per slot)**

| State | Meaning | -> Next | Trigger |
|---|---|---|---|
| READY | Cooldown 0, drones docked | ACTIVE | Drone pressed and accepted |
| ACTIVE | Timer 300 running | RECALL | Timer 0, or `stage_cleared` (instant snap, then READY) |
| RECALL | Drones returning | COOLDOWN | Last drone docked |
| COOLDOWN | Counting 600 | READY | Cooldown 0 |
| Any | | READY (cooldown 0, stock reset) | `plane_died` |

**Breaker drone**

| State | -> Next | Trigger |
|---|---|---|
| DOCKED | FLYING_OUT | Ability accepted |
| FLYING_OUT | NET_ON | Distance to its station <= 12 at the start of a tick (snap) |
| NET_ON | SPENT | `tally >= 30` after a report (erase stops; ram continues) |
| NET_ON / SPENT / FLYING_OUT | RETURNING | Timer 0 |
| RETURNING | DOCKED | Within 10 px of the slot, or return cap 45 |
| Any | removed | `plane_died` |

**Bomb effects (`BombCore` ACTIVE phase)**

| Effect | Phase | Ticks | Geometry |
|---|---|---|---|
| Bastion | GROW | `k = 0..15` | Circle at `C`, radius `40 + 4k` (40 to 100) |
| Bastion | HOLD | `k = 16..71` | Circle at `C`, radius 104 |
| Backlash | RISE | `k = 0 .. effect_ticks - 1` | Full-width bar, `y_w = y0 - 12k` |

Both then follow the Bombs state table (ACTIVE, TAIL to `k = 90`, IDLE).

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Player plane (5) - GDD | <- buttons, plane position/state, `wing_slot(i)` (Player plane PF4: Sentry (∓31, +4), (∓45, +10); Breaker (∓31, +4), (∓49, +10); (decided under auto-approve 2026-11-03, consistency check)); -> `set_ability(active, speed)` (Sentry Entrench 75); <- `plane_died`, `stage_cleared` | Kit never moves the plane. |
| Bullet manager (3) - GDD | -> `request_spawn(...)` (tags 0-3); -> `request_cancel(circle, cause, items = false)` (Breaker net); <- own entries of the per-tick `cancel_report[]` (`request_id`, `count`; merged report, BM Rule 13); <- refusals; <-> `nearest(pos, filter)` | Net pulses are cancels, not bullets. |
| Collision (6) - GDD | -> Breaker ram events `(target, slot, 40, DRONE, seq)`; <- hit results with `tag` | Sentry sends no events. Bomb events as Bombs 12. |
| Chain tracker (7), Scoring (8) - GDD | none directly | Erased bullets never count. |
| Session (1) - GDD | <- `drone_count`, slot state, `stage_started`, `stage_cleared` | Kit never writes `drone_count`. |
| Bombs (12) - GDD | `BombCore` hosts `BastionEffect` and `BacklashEffect`; kits and bombs read nothing from each other | Amendment 5. |
| Critical Break (17) - GDD | -> `charge_active`, `charge_kind`, `charge_last_hit`; <- `cb_armed(slot)` (Bombs consumes) | Rule 38. |
| Powerups and drops (13) - GDD | <- `drone_count` +1 via Session; -> cancelled positions only from bombs (the net gives no items) | Rule 33. |
| Enemy (10), Boss (14) - GDD | <- hurtboxes with `id, gen`, bottom edge, mode, `latchable` (unused here), `kill_class` (PART for bomb percent) | Turret range and Backlash use `r_h` from the registry. |
| Co-op (18) - GDD | <- `N` for the player-pool share and shot opacity | Per-slot kits. |
| Era shift (19) - GDD | <- `era_index` | `EraKitSkin`, `EraBombSkin` (Rule 39). |
| HUD (20) - GDD | -> `kit_bar_ratio`, `kit_ready`, `drone_lamp`, `drone_count` | UI Requirements. |
| Audio (24), VFX (25) - GDD | -> events | Visual/Audio. |

All interfaces to systems marked provisional in LL remain provisional; the new Bullet manager `cancel_report` is adopted (Amendment 2 applied 2026-11-03, wave 4).

## Formulas

All time in integer ticks, distance in px, damage in integer units. `div` is integer division.

**SB1. Aim vector (turret, tracking drone, bolt)**

*(2026-11-03, ADR-0003)*: `atan2`/`sin`/`cos` below use `SimMath` (binary angle units; `sqrt` for `|T - P|` is allowed), positions rounded to 1/16 px. `v = s x (T - P) / |T - P|`; tracking drones: `angle = clamp(atan2(dx, -dy), -track_max_deg, +track_max_deg)`, `v = s x (sin(angle), -cos(angle))`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Speed | `s` | float px/tick | turret/tracking 15, bolt 18 | 900 / 1,080 px/s (<= 1,200 cap) |
| Source / target centre | `P`, `T` | px | field | Turret post, drone, or muzzle; target hurtbox centre |
| Clamp | `track_max_deg` | deg | 15-45 (25) | Tracking drones only |
| Range | `turret_range`, `bolt_range` | px | 100-240 (160) / 240-480 (360) | Centre distance |

**Output Range:** speed exactly `s`. **Example:** turret at (150, 380), target (210, 300): `d = (60, -80)`, `|d| = 100`, `v = 15 x (0.6, -0.8) = (9, -12)`. Bolt from muzzle (180, 480) to (240, 300): `|d| = 189.74`, `v = 18 x (0.31623, -0.94868) = (5.692, -17.076)`. Tracking drone at (170, 500), target (300, 450): the angle is `atan(130/50) = 69.0` deg, clamped to 25: `v = 15 x (0.42262, -0.90631) = (6.339, -13.595)`.

**SB2. Sentry posts and flight**

`P_d = (clamp(x_p + post_dx[d], 14, 346), clamp(y_p - 110, play_top + 40, 560))`; each tick `if dist <= post_speed: snap, else pos += post_speed x unit(P_d - pos)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Offsets | `post_dx` | px | [-60, +60, -110, +110] | Per wing slot |
| Forward distance | `post_dy` | px | 80-160 (110) | Above the plane |
| Post speed | `post_speed` | px/tick | 8-14 (10) | 600 px/s |

**Output Range:** posts x in [14, 346], y in [play_top + 40, 560]. **Example:** plane (180, 500), `play_top` 48: posts (120, 390), (240, 390), (70, 390), (290, 390). A drone starting at (148, 504) flying to (120, 390): distance `sqrt(28^2 + 114^2) = 117.38`; after 11 moves the distance is 7.38; on tick 12 it is <= 10 and snaps, so it is EMPLACED on **tick 12**. Plane at (10, 100) with `play_top` 48: posts x = clamp(-50) = 14, clamp(70) = 70, clamp(-100) = 14, clamp(120) = 120; y = clamp(-10, 88, 560) = 88.

**SB3. Turret schedule and rates**

`phase_d = (d x 7) div 4`; fire on `t mod 7 == phase_d` if a target is in range

**Output Range:** phases 0, 1, 3, 5 (distinct); at most 1 bullet per turret per 7 ticks (8.57/s each, 34.29/s for four); no damage events. **Example:** `d = 2`: `14 div 4 = 3`, fires on ticks 3, 10, 17, ...; `d = 3`: `21 div 4 = 5`.

**SB4. Breaker stock and erase bound**

`tally' = tally + count`; `stock' = min(stock_max, stock + min(count, credit_per_pulse_cap))`; `SPENT iff tally >= net_budget`; max credit per drone per use `= ceil(net_budget / credit_per_pulse_cap) x credit_per_pulse_cap` when every pulse removes at least the cap

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Report count | `count` | int | 0..`enemy_cap` | Bullets removed by one request |
| Per-pulse credit cap | `credit_per_pulse_cap` | int | 2-6 (4) | Stock per pulse |
| Budget | `net_budget` | int | 15-45 (30) | Tally that spends a drone |
| Stock max | `stock_max` | int | 30-120 (60) | 30 bolts at cost 2 |

**Output Range:** `stock` 0-60; max **32** stock per drone per use (8 pulses x 4), 128 per slot with 4 drones (clamped to 60). Erased bullets per drone per use: at least 30 (stops after the report that reaches 30), overshoot at most one pulse's count. Average erase rate bound `4 x 30 / (930 / 60) = 7.74` bullets/s per slot (data test limit **10/s**, AC-31). **Example:** reports 4, 4, 4, 4, 4, 4, 4, 4: credit 4 each (32 total), tally 32, SPENT after the 8th. Reports 1 each: credit 1 each, SPENT after 30 pulses (credit 30). One report of 30: credit 4, tally 30, SPENT at once. Stock 58 and a report of 4: stock 60 (cap).

**SB5. Net geometry, clearance, tunnelling**

`S_d = (clamp(px + st_dx[d], 26, 334), max(play_top + 14, py - 70))`; pulse allowed iff `|S_d - plane| - net_r >= net_safe_clear`; no tunnelling iff `v_cap x net_pulse_interval <= 2 x net_r`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Station offsets | `st_dx` | px | [-24, +24, -72, +72] | Per wing slot |
| Station height | `st_dy` | px | 56-100 (70) | Above the plane |
| Zone radius | `net_r` | px | 20-32 (26) | Erase and ram radius |
| Clearance | `net_safe_clear` | px | 30-60 (40) | Zone edge to plane centre |
| Pulse interval | `net_pulse_interval` | int ticks | 1-6 (2) | Per drone |
| Enemy bullet speed cap | `v_cap` | px/tick | 8 (registry 480 px/s) | `v_cap_global` |

**Output Range:** inner stations are 74.0 px from the plane (`sqrt(24^2 + 70^2)`), edge-to-plane 48.0 px (>= 40 passes); outer stations 100.4 px. `v_cap x interval = 16 <= 52` passes; the largest allowed interval is `floor(52 / 8) = 6`. **Example:** plane (180, 300): stations (156, 230), (204, 230), (108, 230), (252, 230). Plane at (180, 100), `play_top` 48: inner station y = max(62, 30) = 62, distance `sqrt(24^2 + 38^2) = 44.9`, edge 18.9 < 40: the inner drones skip pulses; outer (distance `sqrt(72^2 + 38^2) = 81.4`, edge 55.4) still pulse.

**SB6. Bolt economy**

`bolts_per_s = 60 / bolt_interval = 12`; `stock_burn_per_s = bolts_per_s x bolt_cost = 24`; `barrage_ticks = floor(stock / bolt_cost) x bolt_interval`

**Output Range:** a full stock (60) is a **150-tick** (2.5 s) barrage of 30 bolts. **Example:** stock 6 gives 3 bolts over ticks 0, 5, 10 (barrage 15 ticks). Per use, a slot's maximum fill 128 (clamped 60) is at most 64 bolts per 930-tick cycle (4.1 bolts/s average).

**SB7. Backlash and Bastion geometry**

Backlash: `y_w(k) = y0 - 12k`; `effect_ticks = floor((y0 + 12 - play_top) / 12) + 1`; first-hit tick for a target above: `k_hit = max(0, floor((y0 - cy - 12 - r_h) / 12) + 1)`; no tunnelling iff `backlash_speed + v_cap <= 2 x backlash_half_h`.
Bastion: `r(k) = min(104, 40 + 4k)`; `hit(k) = (k mod 6 == 0) AND dist(C, centre) <= r(k) + r_h`; `n_events <= bomb_target_cap div bastion_damage`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Plane y | `y0` | px | `play_top`-640 | At `k = 0` |
| Wall speed / half height | `backlash_speed`, `backlash_half_h` | px/tick / px | 8-16 (12) / 8-16 (12) | |
| Backlash damage | `backlash_damage` | int | 300-800 (500) | PART 60% |
| Dome | `bastion_r0`, `bastion_grow`, `bastion_r_max` | px | 30-60 (40) / 2-8 (4) / 80-130 (104) | |
| Dome damage / interval | `bastion_damage`, `bastion_interval` | int | 40-120 (60) / 4-8 (6) | PART 60% |

**Output Range:** Backlash `effect_ticks` 2-49; Bastion exactly 72. **Example (Backlash):** `y0 = 560`, `play_top` 48: `floor(524/12) + 1 = 44` ticks; `y0 = 616`: 49; `y0 = 48`: 2. A core at `cy = 200`, `r_h = 22`: `floor((560-200-12-22)/12) + 1 = 28`; check `k = 28`: `y_w = 224`, `|200-224| = 24 < 34` hit; `k = 27`: `y_w = 236`, 36 not < 34 miss. The wall and `v_cap`: `12 + 8 = 20 <= 24` passes. **Example (Bastion):** core at distance 100 from `C`, `r_h = 22`: needs `r(k) >= 78`, i.e. `k >= 10`; events at `k = 12, 18, ..., 66` = 10 events = **600** (PART 360); at distance <= 62 it is in at `k = 0`: events at `k = 0, 6, ..., 66` = 12 = **720** (maximum, under the 1,000 cap).

**SB8. Bomb value and balance**

`lone_core`: Backlash `500`, Bastion `<= 720`; reference Lancer 700, Leech 800.

| Scene | Lancer | Leech | Bastion (Sentry) | Backlash (Breaker) |
|---|---|---|---|---|
| Lone boss core, best placement | 7 x 100 = 700 | 4 x 200 = 800 | 12 x 60 = 720 | 500 |
| Same, PART (x 60%) | 420 | 480 | 12 x 36 = 432 | 300 |
| Typical lone core at distance 100 | ~700 (aligned) | 800 | 600 | 500 |
| 5 small enemies (hp 20-60) | all die | all die | all within 104 px of `C` die | **all die** (anywhere above the plane) |
| One MEDIUM (hp 1,200) | survives | survives | survives (720 or less) | survives (500) |
| Whole screen, many targets | width-limited | 4 targets + splash | one dome | **every target above the plane once** |

**Output Range:** no bomb kills a MEDIUM or LARGE alone; bomb share of a Fortress core (16,500): Bastion <= 4.4%, Backlash 3.0%. Backlash is weakest on one target and strongest on many (intransitive vs Bastion's close-range power). **Example:** a Fortress with 4 parts plus an armoured core (25%): Backlash deals 4 x 300 + 500 x 25 div 100 = 1,200 + 125 = **1,325** in one sweep, across the whole boss; Bastion deals at most 4 x 432 + 180 on parts within 104 px of `C` (usually 1-2 of them).

**K8. DPS equivalence (single target, raw = 100% landing; effective = raw x landing `eta`)**

`eff = damage x hits_per_s x eta`; cycle shares from K12; all landing factors and the 30-tick return are **assumptions** (Open Question 3).

| Source | Damage | Hits/s | Raw | `eta` | Effective |
|---|---|---|---|---|---|
| Sentry normal shot | 20 | 24 | 480 | 0.80 | 384 |
| Sentry Entrench cannon | 50 | 10 | 500 | 0.95 | 475 |
| Sentry idle drone, tracking (each) | 20 | 7.5 | 150 | 0.85 | 127.5 |
| Sentry turret (each, in range 75% of the time) | 40 | 8.57 | 342.9 | 0.85 x 0.75 | 218.6 |
| Breaker normal shot | 30 | 20 | 600 | 0.85 | 510 |
| Breaker Breach slug | 40 | 15 | 600 | 0.90 | 540 |
| Breaker idle drone (each) | 20 | 7.5 | 150 | 0.60 | 90 |
| Breaker net ram (each, in contact 35% of the time) | 40 | 10 | 400 | 1.00 x 0.35 | 140 |
| Breaker bolt | 40 | per K13 | - | 0.90 | 36 each |

- **Sentry average (Fire held in Entrench):** plane 475. Per drone: turret `218.6 x 420/930 = 98.7` + idle `127.5 x 480/930 = 65.8` = **164.5**. `dps(n) = 475 + 164.5 n`.
- **Breaker average (Breach 40% of the time):** plane `0.6 x 510 + 0.4 x 540 = 522`. Per drone: idle `90 x 600/930 = 58.1` + ram `140 x 300/930 = 45.2` + bolts 24.4 (K13) = **127.6**. `dps(n) = 522 + 127.6 n`.

| Drones `n` | 0 | 1 | **2 (reference)** | 3 | 4 |
|---|---|---|---|---|---|
| Lancer (LL) | 586.8 | 722.3 | 857.8 | 993.3 | 1,128.8 |
| Leech (LL) | 570.0 | 701.2 | 832.5 | 963.7 | 1,094.9 |
| **Sentry** | 475.0 | 639.5 | **804.0** | 968.5 | 1,133.0 |
| **Breaker** | 522.0 | 649.6 | **777.2** | 904.8 | 1,032.4 |

**Output Range / Constraint:** at the 2-drone reference each new kit must lie within **+/-10% of `ref_dps` 800** (720-880): Sentry 804.0 (+0.5%), Breaker 777.2 (-2.9%); and pairwise the four kits stay within a ratio of **0.90** (lowest/highest = 777.2 / 857.8 = **0.906**). `ref_dps` itself stays 800 (it is owned by the MVP kits; Conflict 1). Note the 0-drone floor: Sentry 475 and Breaker 522 are below Lancer 587 and Leech 570 (a Sentry without turrets is the weakest plane; its strength is the drones).

**K9. Hit rates and chain climb time (4 drones; raw = structural, landed = x `eta`)**

`T999 = chain_cap / hits_per_s`

| Mode | Raw hits/s | Landed hits/s | Seconds to 999 (raw / landed) |
|---|---|---|---|
| Sentry normal + idle | 24 + 30 = 54 | 19.2 + 18 = 37.2 | 18.5 / 26.9 |
| Sentry Entrench + tracking idle | 10 + 30 = 40 | 9.5 + 25.5 = 35.0 | 25.0 / 28.5 |
| Sentry normal + 4 turrets | 24 + 34.29 = **58.29** | 19.2 + 21.9 = 41.1 | **17.1** / 24.3 |
| Sentry Entrench + 4 turrets | 10 + 34.29 = 44.29 | 9.5 + 21.9 = 31.4 | 22.6 / 31.8 |
| Breaker normal + idle | 20 + 30 = 50 | 17 + 18 = 35 | 20.0 / 28.5 |
| Breaker Breach + bolts + idle | 15 + 12 + 30 = 57 | 13.5 + 10.8 + 18 = 42.3 | 17.5 / 23.6 |
| Breaker net + normal | 20 + 40 = 60 | 17 + 14 = 31 | 16.7 / 32.2 |
| **Breaker net + Breach + bolts (max)** | **15 + 12 + 40 = 67** | 13.5 + 10.8 + 14 = 38.3 | **14.9** / 26.1 |

**Output Range:** raw max 67/s (Breaker) and 58.3/s (Sentry), both <= registry `kit_max_hits_per_s` 72. **Constraint:** `T999_min >= 12 s` (AC-30; default 14.9 s). Kit damage events per tick: Sentry 0, Breaker <= 1 (ram phases 0, 1, 3, 4 of each 6 never coincide).

**K10. Player-pool load**

`live = ceil(rate_per_tick x lifetime)`; lifetime straight up = `ceil(640 / 15) = 43`; aimed up to `ceil(734.3 / 15) = 49`; bolts `ceil(640 / 18) = 36`

**Output Range:** per slot <= 48. **Example:** Sentry normal + idle `(2/5 + 4/8) x 43 = 38.7` (39); Sentry normal + 4 turrets `0.4 x 43 + (4/7) x 49 = 17.2 + 28.0 = 45.2` (46, the maximum); Sentry Entrench + tracking idle `(1/6) x 43 + 0.5 x 49 = 7.2 + 24.5 = 31.7` (32). Breaker normal + idle `(1/3 + 4/8) x 43 = 35.8` (36); Breach + idle + bolts `0.25 x 43 + 0.5 x 43 + 0.2 x 36 = 10.75 + 21.5 + 7.2 = 39.5` (40, the maximum). 4P all Sentry: `4 x 46 = 184 <= 600` and each slot <= 150 (`floor(600/4)`, Co-op Rule 11).

**K11. Cancel volume (perf input)**

`areas_per_tick = N x ceil(drones_in_net / net_pulse_interval)` (circle cancels), plus bomb areas

**Output Range:** Breaker net: 2 areas per tick per slot with 4 drones (parity 0/1), 8 at 4P. Backlash adds 1 rectangle per tick for at most 48 ticks; Bastion adds 1 circle per tick for 71 ticks. Worst combined at 4P: 8 net circles + 4 bomb areas = 12 areas per tick. **Example:** 4P, 1,350 enemy bullets: `12 x 1,350 = 16,200` point-in-area tests per tick before any broad-phase. This is the engine/perf risk (Open Question 1): the Bullet manager must meet its 2.5 ms p99 total (BM AC-40) with 12 areas per tick (AC-41), and the knob `net_pulse_interval` can rise to 3-4 (tunnelling limit 6) as the fallback.

**K12. Drone ability cycle**

`cycle = active + return + cooldown`; `active_share = active / cycle`; return 30 ticks is an assumption (LL K12)

| Kit | Active | Return | Cooldown | Cycle | Active share |
|---|---|---|---|---|---|
| Lancer (LL) | 300 | 30 | 600 | 930 | 32.3% |
| Leech (LL) | 360 | 30 | 540 | 930 | 38.7% |
| **Sentry** | 420 | 30 | 480 | 930 | **45.2%** |
| **Breaker** | 300 | 30 | 600 | 930 | 32.3% |

**Example:** a Sentry that recalls at tick 60 and docks 25 ticks later has a cycle of `60 + 25 + 480 = 565` (active share 10.6%); a drone parked 200 px from its slot docks on return tick 20. Sentry's active share is the highest by design because its turrets are fixed and range-limited (K8 gives a turret 218.6 effective dps against a parked Lancer drone's 240 and a latched Leech drone's 204).

**K13. Breaker bolt dps (K8 input)**

`bolt_dps_per_drone = (net_budget x fill_eff / bolt_cost) x bolt_damage x eta_bolt / (cycle / 60)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Fill efficiency | `fill_eff` | float | 0.3-1.0 (0.70, assumption) | Share of the 30-bullet budget that a real pattern lets the drone credit |
| Bolt landing | `eta_bolt` | float | 0.6-1.0 (0.90) | Straight bolt at <= 360 px |

**Output Range:** 0-34 per drone. **Example:** `(30 x 0.70 / 2) x 40 x 0.90 / 15.5 = 10.5 x 36 / 15.5 = 24.4`. In a calm wave (`fill_eff` 0.1): 3.5. Dense curtain (1.0): 34.8.

> Formulas proposed by game-designer; numbers by auto-approve (2026-11-03). The landing factors, the Sentry in-range share 0.75, the Breaker contact share 0.35, `fill_eff` 0.70, the Breach share 0.40 and the 30-tick return are **assumptions** that playtest telemetry must replace (Open Question 3).

## Edge Cases

**Fire and charge (both)**

- **If Fire is released on tick 17 or 18** (`held = false`), no charge attempt is made and the shot lingers 12 ticks (LL edge case). **If it is released on tick 19**, the charge was entered on tick 18: Sentry fired one cannon-shell tick (and `set_ability(true, 75)` for one tick), Breaker one slug/bolt check; both stop at once.
- **If Fire is held through death and respawn**, the kit starts at the first Active tick as a fresh hold (`h = 0`) and tries charge at `h = 18`.
- **If the pool refuses a request** (shot, shell, slug, bolt, turret bullet), it is lost with no retry; `shot_cd`, `bolt_cd` and turret phases still advance. A refused **bolt** still costs 2 stock (Rule 20); a refused cancel request still produces a report of 0.
- **If Fire and Drone are pressed on one tick**, both are processed (shot first, then the ability).
- **If the plane dies on the tick `h` reaches 18**, Dying wins; charge never starts.

**Sentry**

- **If Drone is pressed with 0 drones**, nothing happens and `drone_denied(NO_DRONES)` fires.
- **If Drone is pressed again before tick 60 of the ability**, `drone_denied(ACTIVE)`; at tick 60 or later it recalls (Rule 14). **If it is pressed during RECALL**, `ACTIVE`; during COOLDOWN, `COOLDOWN`.
- **If a post is clamped** (plane near a wall or the top), the post uses the clamped value (SB2); two posts can end up at the same x (for example `x = 14` for slots 0 and 2); they are not separated and both fire from that point. This only wastes coverage.
- **If the nearest eligible target is farther than 160 px from a post**, that turret fires nothing and keeps its phase (the nearest eligible target is the closest of all eligible ones, so none is in range). Immune and off-screen targets are skipped by eligibility before distance is compared.
- **If a turret's target dies after the bullet is fired**, the bullet flies on in its straight line (it may hit something else or leave the screen); no retarget.
- **If an enemy sits exactly on a post**, the aim vector length is 0: the turret fires straight up (`v = (0, -15)`).
- **If the stage clears while turrets are out**, they snap to the wing slots and dock; the ability is READY with cooldown 0 (Rule 6).
- **If the plane dies while turrets are emplaced**, they vanish with the plane; bullets already in flight hit (Collision ghost shots) but give no chain while the shooter is not Active.
- **If the recall happens while a drone is still FLYING_OUT**, it turns around from its current position and returns (cap 45 ticks).
- **If `drone_count` rises while turrets are out**, the new drone docks and fires idle bullets (Rule 7); the next use includes it.
- **If Entrench is on and a docked drone has a target behind it** (`cy >= drone.y - 8`), that drone's bullet goes straight up; it never fires sideways or backwards.
- **If a boss part is immune**, turrets skip it (not eligible); an armoured core is eligible and gets 40 x 25% = 10 per bullet, counted.

**Breaker**

- **If the Breaker stock is 1** (odd), a bolt needs 2, so no bolt fires; the single point waits until another erase raises it.
- **If Breach is on, `stock >= 2` and no eligible target is within 360 px**, no bolt is fired and no stock is spent; the slug still fires.
- **If the plane is at a wall**, station x is clamped to [26, 334]; outer drones come closer to the inner ones; the zones overlap more (fewer unique bullets erased) but the budget per drone is unchanged.
- **If a station is within `net_safe_clear` of the plane** (plane near the top, SB5), that drone does not pulse that tick; its ram still works; the budget is not spent.
- **If a drone is SPENT**, its brackets dim (Visual) and it stops requesting cancels; it still rams. The activation does not end early.
- **If two Breaker drones' zones overlap**, a bullet in the overlap is removed once, by the request processed first (within a slot, requests are made in drone index order, so the lower `d` wins); the other drone's report excludes it. Their budgets count only what each removed.
- **If a report arrives after the drone has returned** (the ability ended), stock still rises; tally is ignored.
- **If the net erases a bullet that would have killed the plane this tick**, the cancel wins (Bullet manager Rule 7): the plane lives. This is intended help but not a deathbomb exploit: zones are >= 40 px from the hitbox, so only a bullet that passes through a zone *before* reaching the hitbox is saved.
- **If a Breaker bolt's target dies before the bolt lands**, the bolt flies straight on and may hit another enemy; no retarget.
- **If Breach is on and `drone_count` is 0**, the slug fires; the stock can still be spent if it is above 0 (stock is kept across a stage; at 0 drones it does not rise).
- **If the stage clears while the net is on**, the net ends at once, drones dock, ability READY, cooldown 0, stock kept. Bolts in flight still hit but give no chain once the slot is not Active (Collision C5).
- **If the plane dies mid-net**, the net and drones vanish; pending reports are dropped; `stock = 0`.
- **If an enemy bullet is "immune to cancel"**, there is no such flag; every enemy bullet is erasable (Rule 26). Bosses that rely on a pattern surviving a net must be designed assuming at most 120 bullets removed (Rule 34).
- **If the Breaker presses Drone with no enemy bullets on screen**, the net still deploys, pulses erase nothing, the stock does not rise, and the cooldown starts normally. (Players learn to wait for the curtain.)

**Bombs**

- **If Bastion is cast with the plane at the top** (`y0 - 56 < play_top`), `C.y = play_top`; the dome is clipped to the field.
- **If a target is inside the dome at `k = 0`**, it takes the `k = 0` event (60); the dome at `k = 0` has radius 40.
- **If an ally is in the Bastion dome**, bullets inside are removed for them too; only the bomber is invulnerable; the ally's items are none.
- **If a Backlash target is below the plane** (cy > `y0 + 12 + r_h` at `k = 0`), it is never hit; the wall only travels up.
- **If a Backlash target spawns above the wall mid-bomb**, it is hit when the wall reaches it (if the wall has not yet passed it); if it spawns below the wall, it is not hit.
- **If an immune target is in the wall's path**, no event is sent and the wall passes through (Bombs Rule 10).
- **If `y0 + 12 - play_top < 12`** (plane at `play_top`), `effect_ticks = 2`; only the `k = 0` full-screen cancel (with items) and one rectangle at `k = 1` happen.
- **If two bombs overlap in co-op**, each applies its own damage and cap; the first requested cancel gives the items (Bombs Rule 31).
- **If a Critical Break is armed at the accept tick**, the toll is waived as for the other bombs (Bombs Rule 12); the kit's Entrench/Breach is not interrupted.

**Both**

- **If the game is paused**, no ticks run: timers, cooldowns, stock, drone positions and pulses freeze.
- **If the kit sends a damage event to a stale `(id, generation)`**, Collision returns *ignored* (Collision AC-22); the net ram retries on the next phase tick.
- **If the plane is Dying and a net pulse, turret shot or bolt would have fired**, none is sent.
- **If a powerup is collected at 4 drones**, `drone_count` stays 4; the kit does nothing.

**Degenerate strategies and mitigations (Sirlin)**

| Strategy | Why it appeals | Mitigation |
|---|---|---|
| **Breaker: net as a permanent shield** | Erase forever | 30-bullet budget per drone (<= 120 per 930 ticks, 7.7/s average, limit 10/s, AC-31); zones >= 40 px from the hitbox; 5 s on, 15.5 s cycle; no gems |
| **Breaker: farm stock from a stream of weak bullets** | Free ammo | Credit <= 4 per pulse, tally stops at 30, so <= 32 stock per drone per use; stock max 60 |
| **Breaker: hoard stock across stages for a boss dump** | Big burst | Allowed and intended (bolts are 12/s, 40 damage, 2.5 s for a full stock = 1,200 damage at 100% landing); a death resets it to 0 |
| **Breaker: stand inside the enemy emitter to farm** | Bullets spawn at the net | Same budget; erase at spawn is the cheapest 30 bullets but still only 30 per drone |
| **Breaker: items by cancelling** | Gems | Kits request `items = false` only (lint, AC-32); bomb `k = 0` cancel keeps its own cap |
| **Sentry: place and forget** | Chain with no effort | Turrets hold the chain only while targets are within 160 px of fixed posts; 420 ticks; a boss moving out of range gets no turret damage; the plane still has to hit to reach the boss's far side |
| **Sentry: recall-spam to reposition endlessly** | Always-on turrets | Cooldown 480 starts at the last dock, so recall at 60 yields a cycle of about 565 (active share 10.6%), lower than the full 45.2% |
| **Sentry: stack all four turrets on one boss part** | Concentrated dps | Posts are fixed by wing slot (x offsets -110..+110); four turrets at 40 x 8.57/s = 1,371 raw dps is a 4-drone number already inside K8 |
| **Sentry: hold Fire forever in Entrench (no tapping)** | Tracking drones | Entrench speed 75 (slower than any other kit) and 475 vs normal 384 dps is the intended trade |
| **Backlash as a boss skip** | Big damage | 500 per target once (PART 300); bomb cap 1,000; phase guard (Bombs B10) |
| **Bastion as a permanent shelter in co-op** | Safe pocket | 72 ticks; 3 bombs per life; dome centre 56 px ahead |
| **Dying on purpose to refill bombs / reset cooldowns** | Refill | Costs a life, drones, stock (unchanged from Bombs and LL) |

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Plane kits Lancer/Leech (11) - [GDD](plane-kits-lancer-leech.md) | Hard | Inherited Rules 1-15, drone return/dock rules, K8 reference dps, tag 0/1, the Rule 40 charge contract. |
| Bombs (12) - [GDD](bombs.md) | Hard | `BombCore` hosts the two new effects; stock, toll, lockout, cancel and cap rules apply unchanged. |
| Bullet manager (3) - [GDD](bullet-manager.md) | Hard | `request_spawn` (tags 0-3), `request_cancel` (circle/rectangle, `items`), new `cancel_report`, `nearest`. |
| Collision, damage and lives (6) - [GDD](collision-damage-lives.md) | Hard | Damage events (DRONE, BOMB), hit results with `tag`, `request_invuln`, `armour_damage_min`. |
| Player plane (5) - [GDD](player-plane.md) | Hard | Buttons, position/state, `wing_slot(i)`, `set_ability`, `plane_died`, `stage_cleared`. |
| Game events and session (1) - [GDD](game-events-and-session.md) | Hard | `drone_count`, slot states, stage events. |
| Chain tracker (7) - [GDD](chain-tracker.md) | Soft | None directly; `chain_window` 60 and `chain_cap` 999 for design tests (K9). |
| Enemy and AI (10), Boss (14) - [GDD](enemy-and-ai.md), [GDD](boss-and-boss-parts.md) | Hard | Hurtbox registry data (`kill_class`, mode, `r_h`). |
| Input and player mapping (2) - [GDD](input-and-player-mapping.md) | Hard | Fire/Drone/Bomb actions through the Player plane. |
| Powerups and drops (13) - [GDD](powerups-and-drops.md) | Soft | `items_per_cancel_cap` (bombs only); the net requests no items. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Critical Break (17) - [GDD](critical-break.md) | Hard | `charge_active`, `charge_kind` (new values), `charge_last_hit` (tags 2-3), `bomb_landed` from the new effects. |
| HUD (20) - [GDD](hud.md) | Soft | `kit_bar_ratio`, `kit_ready`, `drone_lamp`, `stock`. |
| Menus / plane select (22) - [GDD](menus-title-plane-select.md) | Soft | Sentry and Breaker become `available = true` at Target; text keys `plane.sentry.*`, `plane.breaker.*`. |
| Boss power budget (15), Bullet pattern library (9) - [GDD](boss-power-budget.md), [GDD](bullet-pattern-library.md) | Soft | Net erase bound (<= 120 bullets per Breaker per 930 ticks). |
| Co-op (18) - [GDD](coop-and-team-chain.md) | Soft | Per-slot kits; Bastion shelter; rank rotation. |
| Era shift (19) - [GDD](era-shift-and-plane-evolution.md) | Soft | `EraKitSkin`, `EraBombSkin` for Sentry/Breaker eras 1-4. |
| Audio (24) - [GDD](audio.md), VFX (25) - [GDD](vfx-and-screen-feedback.md) | Soft | Events listed in Visual/Audio. |
| Accessibility (28) - [GDD](accessibility-options.md) | Soft | Reduce flashing / pulsing for brackets and flares; Tap Assist unchanged. |
| Tutorial (30) - [GDD](tutorial.md) | Soft | `charge_last_hit`, `drone_ability_started` for the hold and drones drills (the drills hide for a plane without them). |
| Touch controls (31) - [GDD](touch-controls.md) | Soft | `drone_state` for the touch Drone button; touch auto-fire relies on the inherited 12-tick linger (LL Rule 5). |
| Online leaderboards and Boss Rush (32) - [GDD](online-leaderboards-boss-rush.md) | Soft | Per-plane boards and the rush refit (4 drones) apply unchanged. |

**Amendments to other docs** (exact edits; applied 2026-11-03, wave 4; see `production/gdd-reports/_applied-wave-4.md`)

1. **`design/gdd/systems-index.md`**, row 29: Depends-on `11, 12` -> `3, 6, 11, 12`; Status -> `**Designed** (pending review) — [GDD](plane-kits-sentry-breaker.md)`.
2. **`design/gdd/bullet-manager.md`**: (a) Rule 2 `tag`: add 2 = charge shot (Sentry cannon, Breaker slug), 3 = return bolt (Breaker bolt, speed 18 px/tick); (b) Rule 13 / Interactions: Plane kits may issue circle cancels with `items = false`, at most 2 per slot per tick (8 at 4P), and the manager returns `cancel_report(slot, request_id, count)` (bullets removed by that request) at the start of the next tick; (c) Dependencies row Plane kits: "at most 48 live bullets per slot (Sentry 46, Breaker 40)"; (d) AC-40 / F11 perf scenario: 1,350 enemy bullets with 12 cancel areas per tick must stay <= 2.5 ms p99; (e) Rule 14 note: net cancels are `items = false` and are outside `items_per_cancel_cap`.
3. **`design/gdd/collision-damage-lives.md`**: Interactions: hit results carry `tag` 0-3; Breaker's net ram uses source DRONE (rank 2); no new source value.
4. **`design/gdd/critical-break.md`**: Rule 5 charge list: "Sentry = Entrench (nose cannon) active ticks (`ENTRENCH`); Breaker = Breach active ticks (`BREACH`)"; the `charge_kind` enum gains `ENTRENCH`, `BREACH` (presentation only); the "Sentry, Breaker kits (29)" row: "yes - [GDD](plane-kits-sentry-breaker.md)"; `charge_last_hit` is the last counted tag 2 or 3 result.
5. **`design/gdd/bombs.md`**: add Sentry **Bastion** and Breaker **Backlash** as Rules 35-36 (summary and a link to this GDD: Rules 31-32 and SB7-SB8), the Lancer/Leech bomb names stay; the Dependencies row "Sentry, Breaker kits (29)": "yes - GDD exists"; Open Question 16 closed: `BombCore` hosts a per-plane effect class (confirm with lead-programmer); `effect_ticks` ranges Bastion 72, Backlash 2-49; registry `lancer_bomb_effect_ticks` stays Lancer-only.
6. **`design/gdd/plane-kits-lancer-leech.md`**: Open Question 15 closed: shared `DroneBank` (flight, dock, return) plus per-kit state; Open Question 5 (early recall): Sentry only, after 60 ticks; Lancer/Leech keep "no early recall"; Rule 2 (tags): add 2 and 3; Rule 40: `charge_kind` also `ENTRENCH`, `BREACH`; K8 note: Sentry 804.0 and Breaker 777.2 at 2 drones (see the new GDD).
7. **`design/gdd/player-plane.md`**: V6 drone sprites: Sentry turret 12x12 (barrel stub, base plate when emplaced), Breaker eraser 16x10 wedge (art bible 5.6); PF4 wing-slot offsets recomputed for the 45x42 and 42x45 sprite boxes; `ability_speed` Sentry 75; Plane-to-kit signal list unchanged.
8. **`design/gdd/coop-and-team-chain.md`**: Rule 11 note: kits never exceed 48 live bullets per slot (Sentry 46, Breaker 40); Rule 9: add the Bastion dome and Breaker net as shared field effects (clear for everyone, items none, credit to the requester).
9. **`design/art/art-bible.md`**: 5.6 Breaker row: "pulse arc in front" -> "four corner brackets at the true 26 px radius (a front arc would misreport a full-circle zone); no ring"; add Sentry base plate, Breaker bolt sprite, net brackets, Bastion and Backlash FX to 8.3; 7.2 kit bar: Breaker stock bar with ticks every 25%.
10. **`design/gdd/menus-title-plane-select.md`**: when Target tier ships, Sentry and Breaker `available = true`; keys `plane.sentry.*`, `plane.breaker.*` (name, tag, style, fire, hold, drone) added to localization (Bengali and English).
11. **`design/gdd/boss-power-budget.md`** and **`design/gdd/bullet-pattern-library.md`**: authoring note: "a Breaker net can remove about 120 bullets per 930 ticks (30 per drone per use); a pattern's lethal shape must not depend on those bullets surviving; patterns must stay survivable without the net".
12. **`design/gdd/hud.md`**: add Sentry (ability bar like Leech, recall-available glyph after 60 ticks) and Breaker (stock bar + drone lamp like Lancer) data rows; drone lamp states unchanged.
13. **`design/registry/entities.yaml`**: see the report (new constants; `referenced_by` additions; `drone_ability_cycle` value extended).

**Bidirectional check:** Bombs, Plane kits (11), Critical Break, Bullet manager, Player plane and Co-op already list Sentry/Breaker (29) as a provisional dependent (Bombs row 423, Critical Break row 362, LL Open Question 15). Era shift, HUD, Menus, Audio, VFX, Accessibility must list this GDD when updated.

## Tuning Knobs

All values live in `data/kits/sentry_kit.tres`, `data/kits/breaker_kit.tres`, `data/bombs/bastion.tres`, `data/bombs/backlash.tres` and `data/*/skins/*.tres`; none is hardcoded. Categories: **F** feel, **C** curve, **G** gate. Shared knobs (`charge_hold_ticks`, `shot_linger_ticks`, `return_speed`, `return_cap`, `drone_interval`, `drone_damage`) are LL's.

**Sentry**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `shot_interval` (C) | 5 | 4-7 | Tap shot beats Entrench | Tap feels slow | K8, K9, K10 |
| `shot_damage` (C) | 20 | >= 20 | Fails armour lint | Skips Boss tuning | Boss hp |
| `cannon_interval` / `cannon_damage` (C) | 6 / 50 | 4-8 / 30-70 | Entrench worse than tap | Sentry beats Lancer | K8 (band +/-10%) |
| `entrench_speed` (F) | 75 px/s | 60-105 | Entrench too punishing | No cost for tracking | Player plane PF1 |
| `track_range` / `track_max_deg` (F) | 220 / 25 | 120-300 / 15-45 | Tracking rarely engages | Drone fire sideways | K8 eta |
| `emplace_ticks` (C) | 420 | 240-600 | Not worth placing | Always on | Cooldown, K12 |
| `drone_cooldown` (G) | 480 | 360-720 | Turrets near-permanent | Ability forgotten | K12 |
| `recall_min_ticks` (G) | 60 | 30-120 | Recall-spam | Placement mistakes locked in | Cooldown |
| `post_dx` / `post_dy` (F) | [-60,60,-110,110] / 110 | +/-30 / 80-160 | Turrets cluster | Turrets off the action | Wing slots |
| `post_speed` (F) | 10 px/tick | 8-14 | Slow set-up | Instant, no read | K12 |
| `turret_range` (C) | 160 px | 100-240 | Hardly engages | Covers the field | K8 in-range share (0.75) |
| `turret_interval` / `turret_damage` (C) | 7 / 40 | 5-9 / >= 20 | Chain too fast (K9) | Turrets weak | K8, K9, K10 (<= 48) |

**Breaker**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `shot_interval` / `shot_damage` (C) | 3 / 30 | 3-5 / >= 20 | - | Ram beats Lancer | K8, K10 |
| `slug_interval` / `slug_damage` (C) | 4 / 40 | 3-6 / 30-60 | Breach worse than tap | Breach dominates | K8 |
| `bolt_interval` (C) | 5 | 4-8 | Chain too fast (K9) | Bolts feel absent | K9, K10 |
| `bolt_cost` (C) | 2 | 1-4 | Stock drains too slowly | Few bolts | SB6 |
| `bolt_damage` / `bolt_speed` (C/F) | 40 / 18 | 30-60 / 14-20 | Bolt not worth it | Melts targets; speed above the 20 cap | K8, player cap |
| `bolt_range` (F) | 360 | 240-480 | Bolts rarely fire | Bolts miss far targets | `eta_bolt` |
| `stock_max` (C) | 60 | 30-120 | Burst too short | Hoard dump too big | SB6 |
| `credit_per_pulse_cap` (C) | 4 | 2-6 | Stock too slow | Dense fire over-credits | SB4, AC-31 |
| `stock_death_keep` (C) | 0 | 0-20 | - | Death too cheap | Lives |
| `net_ticks` (C) | 300 | 180-420 | Net briefly | Net near-permanent | K12 |
| `drone_cooldown` (G) | 600 | 420-780 | Net near-permanent | Ability forgotten | K12 |
| `net_r` (F) | 26 | 20-32 | Little erased | Zone covers too much | SB5, clearance |
| `net_budget` (C) | 30 | 15-45 | Net trivial | Net dominates (limit 10 bullets/s average) | AC-31 |
| `net_pulse_interval` (F) | 2 | 1-6 (no-tunnel limit) | Cancel volume (K11) | Fast bullets slip | K11, SB5 |
| `net_safe_clear` (G) | 40 px | 30-60 | Net covers hitbox | Net dead near the top | `st_dy` |
| `st_dx` / `st_dy` (F) | [-24,24,-72,72] / 70 | +/-20 / 56-100 | Net too close | Net too far to help | Clearance |
| `station_speed` (F) | 12 px/tick | 8-16 | Late deploy | Instant | K12 |
| `ram_interval` / `ram_damage` (C) | 6 / 40 | 4-8 / >= 20 | Chain too fast | Ram weak | K9 |

**Bombs**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `bastion_r0` / `grow` / `r_max` (F/C) | 40 / 4 / 104 | 30-60 / 2-8 / 80-130 | Dome tiny | Screen clear | K11 areas |
| `bastion_ticks` (G) | 72 | 48-84 (< lockout - 4) | Short | Overlaps the next bomb | Bombs lockout |
| `bastion_damage` / `bastion_interval` (C) | 60 / 6 | 40-120 / 4-8 | Bomb useless | Beats Leech's hooks | SB8, cap 1,000 |
| `bastion_ahead` (F) | 56 | 30-90 | Centre on the plane | Dome ahead of the action | Boss reach |
| `backlash_damage` (C) | 500 | 300-800 | Not worth a bomb | Boss melts (cap 1,000) | SB8, Bombs B10 |
| `backlash_speed` / `half_h` (F) | 12 / 12 | 8-16 / 8-16 | Slow sweep | Tunnelling (limit 2 x half_h - v_cap) | SB7 |

**Owned elsewhere:** `armour_damage_min` 20 and `laser_exit_grace` 12 -> Collision (6) · `focus_speed` 105, `move_speed` 210 -> Player plane (5) · `max_drones` 4 -> Session (1) · `player_cap` 600 and `v_cap_global` 480 -> Bullet manager (3) · `chain_window`, `chain_cap` -> Chain tracker (7) · `bomb_start`, `bomb_lockout`, `bomb_invuln`, `bomb_chain_toll_pct`, `bomb_target_cap`, `bomb_part_pct` -> Bombs (12) · `items_per_cancel_cap` -> Powerups (13).

**Rationale for the defaults:** K8 puts both new kits inside the +/-10% band at 2 drones (804.0, 777.2); cycles are 930 ticks like the MVP kits; Sentry's turret range and Breaker's budget bound their own strength; the net budget 30 gives a 7.7 bullets/s ceiling below the 10/s test limit; bomb damage is placed on either side of the Lancer/Leech lone-core numbers (700-800) with a different scene advantage each (SB8).

## Visual/Audio Requirements

> Source of truth: `design/art/art-bible.md` (AB); consistent with LL V1-V5, Player plane V6-V8, Bullet manager V3/V6, Bombs V-section, Collision V2. Draw layers per AB 6.8: enemies 4, **air FX 5**, **player shots/drones 6**, planes 7, **enemy bullets 8**, hitbox dots 9, HUD 11. **Bullets always win**: nothing here draws over an enemy bullet. Never use Void Indigo or Ink; never use enemy shapes (orb, rice, needle, ring) for non-bullets; all art is sprites (no `draw_line`/`draw_circle`). Numbers marked (P) are unplaytested. Warm palette as LL V1: edge `#FF7A1A`, fill `#FFB82E`, core `#FFF2B0`.

**V1. Sentry turret drone (AB 5.6: 12x12 warm disc with a short barrel stub, P-colour ring)**
- Docked: PP V6 style (2 frames at 10 fps, 100% opacity). Flying out: 3 px warm trail, 2 frames, no rotation.
- EMPLACED: the barrel stub snaps to **8 pre-rotated facings** (45 deg steps) toward its current target (nearest eligible, within range); a **14x3 px base plate** shows under the disc (AB "stationary state adds a base plate"). Muzzle cue: one 2x2 px Cream pixel at the barrel tip for 2 ticks per shot; **no sprite-wide brightness flash**.
- Placement cue: on arrival, 8 tick marks (4x1 px, fill at 30% opacity) at 160 px from the post at 45-degree steps fade over 30 ticks; they are tick marks, **not a ring**; hidden when `access.effects_level` is MINIMAL.
- **Time-left cue:** last 60 ticks, the base plate pulses at 2 Hz (opacity 100% to 60%, 30-tick period; off under Reduce pulsing). Recall: the 3 px warm return trail.
- Entrench: a 3x3 px Cream pixel at the gun nose while the cannon is on (same role as Lancer's nose lens glow); no plane blink.

**V2. Breaker eraser drone and net (AB 5.6: 16x10 wedge/shield capsule, forward-pointing, P-colour outline)**
- **Net zone marker:** four **corner brackets** (L-shaped, 5x5 px, 1 px stroke) at the corners of the 52x52 px box around the drone (the zone is the circle inscribed in it), fill `#FFB82E` at 70% opacity, layer 5 (the drone sits on layer 6). A **front arc is not used** (a front arc would misreport a full-circle zone, Conflict 3).
- **Pulse feedback:** when a pulse removed >= 1 bullet the four brackets change to `#FFF2B0` for 3 ticks, throttled to once per 30 ticks per drone (<= 2 Hz); the bullets' own vanish puff comes from VFX's throttled cancel puff (VFX 25). Off under Reduce flashing (brackets stay steady).
- **SPENT:** two diagonal brackets only at 40% opacity, steady; the drone outline dims to 60%. This is the "budget used" cue; no number is shown.
- Flying out: 4 px warm trail, 2 frames. Net follows the plane rigidly (no lag).
- **Breach:** a 3x3 px Cream pixel at the ram nose (spine tip) while Breach is on; no blink.
- **Bolt:** streak shape, 2 px Cream core, fill `#FFB82E`, 3-frame trail; spawns at the nose at 18 px/tick; the Bullet manager's player-shot opacity by `N` applies (BM V3).

**V3. Bastion (Sentry bomb)**
- A translucent warm disc (`#FFB82E` at 18% opacity, a scaled sprite, layer 5) of radius `r(k)` with 4 corner brackets at the bounding-box corners (3 size frames, nearest radius; `#FF7A1A`, 1 px). Last 6 ticks (k 66-71): opacity fades 18% to 0. **No outline ring, no white flash.** It never covers a surviving bullet (layer 5 < 8).
- Targets inside take Collision V2 tint/spark throttles. The dome is world-anchored; its position is the dome centre, not the plane.

**V4. Backlash (Breaker bomb)**
- A full-width bar 24 px tall: top edge 2 px `#FFF2B0`, body `#FFB82E` at 22% opacity, a 12 px trail in 4 opacity steps, layer 5, rising 12 px/tick (visibly 1 screen in about 0.8 s from the plane's row). No flash; no screen shake beyond the VFX bomb tier.
- On targets: one hit spark (Collision V2 throttles).

**V5. Era skins (Rule 39; AB 5.5):** Sentry - plain twin booms and fixed nose gun (1941), missile rails on boom tips (1970s), hex drone bays under the booms (2030s), floating split pod with offset halves (2100). Breaker - wooden-prop ram nose (1941), jet-intake cowl and nose spike (1970s), armoured ram plate (2030s), crystal prow with a light-echo trail (2100). At most 2 bolt-on sprites per plane per era (Player plane V8). Brackets, dome and bar recolour only within the warm range.

**A1. Audio** (audio-director to confirm (P); sound IDs assigned in the Audio (24) Sound Event List 2026-11-03: `sfx_kit_sentry_plant`, `sfx_kit_turret_tick`, `sfx_kit_recall_chime`, `sfx_kit_charge_sting`, `sfx_kit_net_deploy`, `sfx_kit_net_fizz`, `sfx_kit_drone_spent`, `sfx_kit_bolt_launch`, `sfx_kit_stock_ready`, `sfx_bomb_bastion_loop`/`_tail`, `sfx_bomb_backlash_sweep`; drone denied reuses `sfx_kit_drone_denied`)

| Event | Spec | Limit |
|---|---|---|
| Sentry post planted | One low "thud" per slot per use (not per drone) | 1 per slot |
| Turret shot | Shared bullet SFX pool (short tick) | <= 1 per slot per 4 ticks; counted in the 8-voice pool |
| Recall | Soft chime on accept | 1 per press |
| Entrench start / Breach start | One stinger at `h = 18` | 1 per slot |
| Net deploy | One "whoosh" per slot per use | 1 per slot |
| Erase pulse | One soft "fizz" for any pulse that erased >= 1 bullet | <= 1 per slot per 6 ticks (cancel sounds obey the BM voice rule; cancel > fire) |
| Drone spent | Quiet click, once per drone | 1 per drone |
| Bolt launch | Shared pool tick | <= 1 per slot per 5 ticks |
| Stock ready | Soft chime when stock first reaches 2 after being below | 1 per slot per 120 ticks |
| Bastion | Rising thrum on `k = 0`, falling tail on `k = 71`; large cancel tier on `k = 0` only | 1 voice per slot |
| Backlash | One rising sweep on `k = 0` (large cancel tier) | 1 voice per slot |
| Drone denied | Quiet blip | 1 per press |

Voice caps: kit SFX <= 4 voices per slot, <= 8 total (as LL A1). No sound per erased bullet.

> Drafted from the art bible and LL; direction by game-designer under auto-approve (2026-11-03). `art-director` and `audio-director` not consulted.

📌 **Asset Spec** - run `/asset-spec system:plane-kits-sentry-breaker` to produce per-sprite specs (turrets, base plate, tick marks, eraser drone, brackets, bolts, dome frames, wall bar, bolt-ons per era).

## UI Requirements

The HUD (20) draws the kit state per player slot (icon-only; no text, so Bengali and English share it).

| Data | Sentry | Breaker |
|---|---|---|
| `kit_bar_ratio` | Ability: time left / 420 while ACTIVE, `1 - cooldown_left / 480` in COOLDOWN, 1 when READY | `stock / 60` |
| `kit_ready` | Ability READY | `stock >= 2` (a bolt is available) |
| `drone_lamp` | not used | Ability state (READY / ACTIVE / COOLDOWN / NONE at 0 drones) and ratio, as Lancer |
| `recall_available` | true when ACTIVE and >= 60 ticks since the press | not used |

- **Kit bar** (AB 7): the 4 px segmented bar under the lives row, Tracer Orange on Char, ticks every 25%. Sentry's bar is the ability bar (as Leech). Breaker's bar is the stock bar; each bolt spent drops it by 2/60 (3.3%).
- **Recall glyph (Sentry):** a 5x5 px arrow-into-base glyph beside the bar, outline until `recall_available`, solid Cream after; non-colour backup (shape fill). Hidden at 0 drones.
- **Breaker drone lamp:** 5x5 glyph, same states as the Lancer lamp.
- **Animation:** no pulses faster than 2 Hz; ready states are shapes, not colour alone.
- **Debug tools:** overlay of Fire state, `h`, `shot_cd`, `bolt_cd`, stock, per-drone state/tally/SPENT, zones (circles), turret ranges, wall and dome extents, cancel request counts per tick, per-source hit counters; cheats: set stock, set drones.

📌 **UX Flag**: run /ux-design for the per-slot plane panel (lives, drone count, kit bar, lamp, recall glyph) before writing epics.

## Acceptance Criteria

Defaults used: canvas 360x640, 60 ticks/s; `charge_hold_ticks` 18, `shot_linger_ticks` 12; Sentry shot interval 5 / damage 20 / muzzles `(-8,-12) (8,-12)`, cannon 6 / 50 at `(0,-18)`, `entrench_speed` 75, `track_range` 220, `track_max_deg` 25, `emplace_ticks` 420, cooldown 480, `recall_min_ticks` 60, `post_dx` `[-60,60,-110,110]`, `post_dy` 110, `post_speed` 10, `turret_range` 160, `turret_interval` 7, `turret_damage` 40; Breaker shot 3 / 30 at `(0,-20)`, slug 4 / 40, `bolt_interval` 5, `bolt_cost` 2, `bolt_damage` 40, `bolt_speed` 18, `bolt_range` 360, `stock_max` 60, `credit_per_pulse_cap` 4, `net_ticks` 300, cooldown 600, `net_r` 26, `net_budget` 30, `net_pulse_interval` 2, `net_safe_clear` 40, `st_dx` `[-24,24,-72,72]`, `st_dy` 70, `station_speed` 12, `ram_interval` 6, `ram_damage` 40; Bastion `r0` 40, grow 4, `r_max` 104, 72 ticks, damage 60 every 6, ahead 56; Backlash 12 px/tick, half height 12, damage 500; `return_speed` 10, `return_cap` 45, `drone_interval` 8; `armour_damage_min` 20; `chain_window` 60; `chain_cap` 999; `player_cap` 600; `v_cap_global` 480 px/s (8 px/tick); `bomb_lockout` 90; `bomb_target_cap` 1000; `bomb_part_pct` 60.

**Test setup:** each kit is a plain `RefCounted` class (working names `SentryKit`, `BreakerKit`, base `PlaneKit`, shared `DroneBank`; bomb effects `BastionEffect`, `BacklashEffect` inside `BombCore`) with no nodes, no drawing, no `delta` and no RNG. `tick()` advances one 1/60 s step. Inputs before a tick: `set_config(res)`, `set_plane(pos, state)`, `set_wing_slots([...])`, `set_buttons(fire_pressed, fire_held, fire_released, drone_pressed)`, `set_drone_count(n)`, `set_targets([{id, gen, pos, r_h, bottom_y, mode, kill_class}])` through an injected stub `TargetQuery`, `deliver_hit_results([...])`, `deliver_cancel_reports([...])`, `plane_died()`, `stage_cleared()`. Outputs after a tick: `bullet_requests`, `cancel_requests`, `damage_events`, `ability(active, speed)`, `stock`, `fire_state`, `ability_state`, `drone_states/positions/tallies`, `events`, `charge_*`, `state_hash()`. A stub Bullet manager removes bullets in a requested area and returns the count. Tests: `tests/unit/test_plane_kit_sentry.gd`, `test_plane_kit_breaker.gd`, `test_bomb_sentry_breaker.gd`, `test_plane_kit_sb_balance.gd` (`extends SceneTree`, like `tests/unit/test_chain_tracker.gd`); integration `tests/integration/test_plane_kit_sb_*.gd` with the real `BulletField`, `PlaneCore`, `CollisionReferee`. Every number is read from `data/kits/*.tres` and `data/bombs/*.tres`, never literals; position asserts +/-0.01 px, velocity +/-0.001.

Tags: [Unit] pure logic · [Integration] real BulletField / PlaneCore / referee · [Perf] REF-PC and REF-WEB · [Manual] needs a human.

### Fire and charge (Rules 1, 10-11, 18-19)

- **AC-01 [Unit] (Rules 10-11):** Sentry, Fire pressed on tick 0 and held to tick 40: normal volleys on ticks 0, 5, 10, 15; state CHARGE on tick 18 with `ability(true, 75)` from tick 18; the first shell on tick 20 (shot_cd reaches 0), then 26, 32, 38. No volley on tick 18 or 19.
- **AC-02 [Unit] (Rules 18-19):** Breaker, same hold: normal volleys on 0, 3, 6, 9, 12, 15; CHARGE on tick 18; the first slug on tick 18, then 22, 26, 30; `ability(false, _)` throughout.
- **AC-03 [Unit] (Rule 1):** with 0 drones and stock 0, Fire held to tick 18 enters CHARGE for both kits (no HOLD_PLAIN exists); release at tick 17 or 18 never enters CHARGE and lingers 12 ticks.
- **AC-04 [Unit] (LL Rule 5):** Sentry press 0 / release 3: volleys on 0, 5, 10 and none on 15; Breaker press 0 / release 3: volleys on 0, 3, 6, 9, 12 and none on 15.
- **AC-05 [Unit] (LL Rule 6):** Fire pressed every other tick for 20 ticks yields exactly 4 Sentry volleys (0, 5, 10, 15) and 7 Breaker volleys (0, 3, 6, 9, 12, 15, 18); a re-press never resets `shot_cd` or `bolt_cd`.
- **AC-06 [Unit] (LL Rule 3):** presses during FlyIn, Dying or Absent produce no request, event or cancel; Fire held through a respawn: first Active tick fires a volley at once with `h = 0`.
- **AC-07 [Unit] (Rules 10-11, 18-19):** request geometry: Sentry volley = 2 requests, velocities `(0,-15)` each, muzzles `(-8,-12) (8,-12)`, damage 20, tag 0, streak; shell = 1 request, `(0,-15)`, muzzle `(0,-18)`, damage 50, tag 2. Breaker volley = 1 request `(0,-15)` at `(0,-20)`, damage 30, tag 0; slug damage 40, tag 2. All speeds 15.000 +/- 0.001.
- **AC-08 [Unit] (Rule 12, SB1):** Sentry Entrench with 4 drones: a drone at (170, 500) and a target at (300, 450) fires a bullet with velocity `(6.339, -13.595)` +/-0.001 (clamped 25 deg); a target behind or beside (`cy >= drone.y - 8`) gives `(0,-15)`; a target at 220.0 px counts, 220.1 does not; outside Entrench the same drone fires straight.
- **AC-09 [Unit] (Rule 3):** docked drones fire on `t mod 8 == 0, 2, 4, 6` for `d = 0..3`; a drone flying out, emplaced, in the net or returning fires none.

### Sentry ability (Rules 13-16)

- **AC-10 [Unit] (Rule 13, SB2):** plane (180, 500), `play_top` 48, 4 drones: posts (120,390), (240,390), (70,390), (290,390); plane (10, 100): posts x 14, 70, 14, 120 and y 88; a drone from (148, 504) to (120, 390) becomes EMPLACED on tick 12.
- **AC-11 [Unit] (Rule 15, SB1, SB3):** a turret at (150, 380) with a target at (210, 300) fires on ticks with `t mod 7 == phase_d`: velocity `(9, -12)` +/-0.001, damage 40, tag 1, diamond; phases 0, 1, 3, 5; a target 160.0 px away is fired at and 160.1 px is not (no request, phase kept); target exactly on the post: `(0,-15)`; ties go to the lowest id.
- **AC-12 [Unit] (Rule 14):** press at tick 0 accepted; a press at tick 59 gives `drone_denied(ACTIVE)` and changes nothing; at tick 60 it recalls (state RECALL); a press in RECALL gives `ACTIVE`, in COOLDOWN `COOLDOWN`; 0 drones gives `NO_DRONES`; no press needs a target.
- **AC-13 [Unit] (Rules 5, 16, K12):** timer 420 -> RECALL; the last dock on tick T starts a 480 cooldown, READY on T + 480; a recall at tick 60 with a dock 25 ticks later: READY at `60 + 25 + 480 = 565` ticks after the press; `stage_cleared` while out: drones docked, READY, cooldown 0; `plane_died`: 0 drones, cooldown 0.
- **AC-14 [Unit] (Rule 8):** over a 10,000-tick random-input run, the Sentry sends 0 damage events and at most 1 bullet request per drone per 7 ticks plus the plane's.
- **AC-15 [Integration] (Rule 11):** with the real Player plane, Entrench ticks move the plane 1.25 px/tick (75 px/s); SHOT ticks move it 1.75 px/tick while Fire is down and 3.5 px/tick during linger.

### Breaker kit (Rules 20-29)

- **AC-16 [Unit] (Rule 20, SB6):** Breach with stock 6 and one target at 200 px: bolts on ticks 18, 23, 28 (stock 4, 2, 0), none on 33; each bolt tag 3, damage 40, speed 18.000 +/- 0.001, velocity per SB1 (muzzle (180,480) to (240,300): `(5.692, -17.076)`); the slug cadence is unchanged by bolts.
- **AC-17 [Unit] (Rule 20):** stock 1 -> no bolt, stock unchanged; stock 60 and a target at 360.0 px -> bolt, at 360.1 px -> none and no spend; a refused bolt (stub pool full) still spends 2.
- **AC-18 [Unit] (Rules 21, 25, SB4):** reports 4 x 8 -> stock +32, tally 32, SPENT after the 8th; one report of 30 -> stock +4, tally 30, SPENT; reports of 1 x 30 -> stock +30, SPENT after the 30th; stock 58 plus a report of 4 -> 60; hits, bombs, pickups, kills and time give +0.
- **AC-19 [Unit] (Rules 6, 21):** `plane_died` -> stock 0 (`stock_death_keep` 20 -> 20); `stage_cleared` -> stock unchanged; stock is not decayed over 10,000 ticks.
- **AC-20 [Unit] (Rule 22, SB5):** plane (180, 300), 4 drones: stations (156,230), (204,230), (108,230), (252,230); a drone becomes NET_ON on the tick its start-of-tick distance is <= 12, then its position equals the station every tick as the plane moves; plane (180, 100): inner stations at y 62, distance 44.9, edge 18.9 < 40.
- **AC-21 [Unit] (Rule 24):** a NET_ON, unspent drone with clearance >= 40 requests one circle cancel (radius 26, `items = false`, cause = slot) on ticks with `(t + d) mod 2 == 0`; at most 2 requests per slot per tick; none when SPENT, none when clearance < 40 (plane at (180,100): inner drones silent, outer drones pulse), none during FLYING_OUT or RETURNING.
- **AC-22 [Unit] (Rules 25, 29):** a report of `n` arrives on the tick after the request and updates tally and stock as SB4; a report after the drone has returned updates stock only; a report for a dead slot is dropped.
- **AC-23 [Unit] (Rule 27):** net ram: damage 40, source DRONE, drone `d` on ticks with `t mod 6 == 0, 1, 3, 4`, to the lowest-id eligible target overlapping the zone (`dist < 26 + r_h`); an immune target gives no event; a SPENT drone still rams; over 10,000 random ticks at most 1 damage event per tick.
- **AC-24 [Unit] (Rules 22, 28):** Breaker timer 300 -> RECALL, cooldown 600 from the last dock; a press during ACTIVE gives `ACTIVE` (no early recall); `stage_cleared` -> net ends, READY, cooldown 0, stock kept.
- **AC-25 [Unit] (Rule 5):** returning drones dock within 10 px; a drone 200 px from its slot docks on return tick 20; any drone still out on tick 45 snaps.

### Bombs (Rules 31-36, SB7-SB8)

- **AC-26 [Unit] (Rule 31, SB7):** Bastion: `C` for plane (180, 500) = (180, 444); `r(0) = 40`, `r(15) = 100`, `r(16) = r(40) = 104`; `k = 0` is a full-screen cancel with items, `k = 1..71` are circle cancels with `items = false`; the dome stays at `C` while the plane moves; `effect_ticks = 72`; `C.y = play_top` for a plane at y 80.
- **AC-27 [Unit] (Rule 31):** a core (`r_h` 22) at distance 100 from `C` takes events at `k = 12, 18, ..., 66` (10 events, 600; a PART 10 x 36 = 360); at distance 62 it takes 12 events (720) and never more than the 1,000 cap; an immune target gets none; a target in the dome at `k = 0` takes the `k = 0` event; `counts_chain = false` on every event.
- **AC-28 [Unit] (Rule 32, SB7):** Backlash `effect_ticks`: `y0 = 560` -> 44, `y0 = 616` -> 49, `y0 = 48` -> 2; a core at `cy = 200`, `r_h = 22`, `y0 = 560` is hit at `k = 28` (not 27) once (500; PART 300; armoured 25% -> 125); a target below the plane is never hit; a target is never hit twice; `k = 0` cancel has items, `k >= 1` rectangle cancels have none.
- **AC-29 [Integration] (Rule 32, no tunnelling):** real `BulletField`: enemy bullets at 8 px/tick moving down through the wall's path across all x -> none survives past the wall; a bullet spawned inside the rectangle on that tick is cancelled; the data test `backlash_speed + v_cap <= 2 x backlash_half_h` passes at 12 + 8 <= 24 and fails at `backlash_speed` 17.
- **AC-30 [Unit] (Rules 8, 35, K9):** Bastion and Backlash with 0 drones and with 4 drones produce identical `state_hash()`, events and damage; a bomb during Entrench/Breach leaves `charge_active`, stock and `bolt_cd` unchanged; Bombs rules (stock 3, lockout 90, invulnerability 90, toll 50%, waived when `cb_armed`, `counts_chain = false`) hold for both effects.

### Balance guards (K8-K10, SB4-SB5) - data tests, no scene

- **AC-31 [Unit] (K9, Rule 8):** from the `.tres`, raw maximum hits/s: Sentry 58.29 +/- 0.01, Breaker 67.0 +/- 0.01, both <= 72, `T999 = 999 / rate` >= 12 s (14.9 s at default); damage events per tick <= 1 (Breaker) and 0 (Sentry) over 10,000 random-input ticks.
- **AC-32 [Unit] (SB4, Rule 34):** the net erase bound `4 x net_budget / (cycle / 60)` is 7.74 at default and must be <= 10; `net_budget` 40 fails the test (10.3); `credit_per_pulse_cap` x ceil(budget / cap) per drone is 32.
- **AC-33 [Unit] (K8):** computed 2-drone sustained dps: Sentry 804.0 +/- 1, Breaker 777.2 +/- 1, both inside `ref_dps` 800 +/- 10% (720-880); lowest/highest of {857.8, 832.5, 804.0, 777.2} >= 0.90 (0.906); all damage values in the data are integers >= `armour_damage_min`.
- **AC-34 [Unit] (SB5):** every station at rest has clearance `sqrt(dx^2 + st_dy^2) - net_r >= net_safe_clear` (48.0 inner and 74.4 outer at default); `v_cap x net_pulse_interval <= 2 x net_r` (16 <= 52) passes and `net_pulse_interval` 7 fails.
- **AC-35 [Unit] (K10):** computed live bullets per slot <= 48 (Sentry 46, Breaker 40) for every mode combination; 4P total <= 184.
- **AC-36 [Unit] (Rule 39):** for every `EraKitSkin` and `EraBombSkin` of both planes the numeric data hash is identical; skins differ only in sprite/sound ids, tint and muzzle offsets within +/-4 px.
- **AC-37 [Unit] (lint):** no tuning literal, no `delta`, no `randf`/`randi`, no `Input.` in the kit or effect classes; no kit cancel request has `items = true`; all numbers come from the `.tres` files.

### Integration

- **AC-38 [Integration] (Rule 38):** `charge_active` is true on every Entrench/Breach tick (including tick 18) and false in SHOT, linger and at release; `charge_last_hit` updates only on counted tag 2 and tag 3 results (cannon shell, slug, bolt), not on turret bullets (tag 1), idle bullets, the net ram or bomb hits; `charge_kind` is ENTRENCH or BREACH; a bomb press changes none of these.
- **AC-39 [Integration] (chain):** each counted Sentry turret/shell and Breaker slug/bolt/ram result produces one `chain_hit`; an armoured 25% target: turret 40 -> 10, shell 50 -> 12, slug 40 -> 10, bolt 40 -> 10, ram 40 -> 10, all counted; an immune target gives none; erased bullets and cancels never produce `chain_hit` or score.
- **AC-40 [Integration] (cancel):** real `BulletField`, 200 enemy bullets inside a Breaker zone: the request removes all 200 with reason CANCEL_NOITEM, `cancel_items` empty, report count 200, stock +4, tally 200 (SPENT); a player bullet in the zone is untouched; a bullet inside two zones is removed once and counted in the first request only.
- **AC-41 [Integration] (cancel beats hit):** a bullet that would hit the plane this tick and is inside a zone is cancelled (no hit); zones are >= 40 px from the hitbox so a bullet already within 40 px of the hitbox is not erased by the net.
- **AC-42 [Integration] (pool, K10):** real `BulletField`, 4 Sentry slots with 4 turrets each plus Fire held, targets scattered, 600 ticks -> peak `player_active <= 184`, `refused_player_share == 0`, `refused_player == 0`; same for 4 Breaker slots (<= 160).

### Determinism and performance

- **AC-43 [Unit] (determinism):** a scripted 3,000-tick scenario (a Sentry slot and a Breaker slot; mixed targets and bullets; 1 death, 1 stage clear, bomb presses), run twice and at 60/30/144 fps adapters -> `state_hash()` equal every tick.
- **AC-44 [Perf] (kit budget):** 4 kits (Sentry/Breaker mix, 4 drones each, full activity, 64 targets) -> kit pass <= **0.25 ms** p99 on REF-PC and REF-WEB; <= 7 bullet requests per slot per tick; <= 2 cancel requests per slot per tick; target queries <= 10 per slot per tick; no allocation per tick after warm-up (memory growth < 1 MB over 10 minutes).
- **AC-45 [Perf] (cancel volume, K11):** 4P, 1,350 enemy bullets, 12 cancel areas per tick (8 net circles + 4 bomb areas) -> the Bullet manager's whole update <= **2.5 ms** p99 on REF-PC and REF-WEB (BM AC-40); on failure, set `net_pulse_interval` 3 and re-run (AC-34 must still pass).

### Manual (evidence in `production/qa/evidence/plane-kits-sentry-breaker/`)

- **AC-46 [Manual] (erase readability):** 4P capture of four Breaker nets in a curtain, shown to 10 testers: >= 8 correctly say "bullets only vanish inside the brackets"; a frame check finds no bullet removed outside a drawn zone; dimmed (SPENT) drones read as "used up" for >= 8 of 10.
- **AC-47 [Manual] (layers and palette):** brackets, dome and wall draw below enemy bullets on every frame (layer 5/6 < 8); hex check: warm colours only, no Ink/Void Indigo, no ring shape.
- **AC-48 [Manual] (chain identity):** after 10 minutes on each plane, >= 8 of 10 testers describe Sentry as "turrets / zone I place" and Breaker as "eats bullets / bolts" without being told; telemetry: Breaker chain gain per second correlates positively with enemy bullets on screen; Sentry chain survives plane movement better than Lancer's normal shot.
- **AC-49 [Manual] (Breaker dominance):** 5 testers x 3 boss attempts each on Breaker: net erase average <= 10 bullets/s (telemetry) and >= 4 of 5 say "it helps but a thick curtain is still deadly".
- **AC-50 [Manual] (Sentry placement):** >= 8 of 10 testers can explain that turrets keep firing when the plane moves; >= 5 use the early recall at least once; no tester reports being unable to tell where the turret range ends (tick marks).
- **AC-51 [Manual] (bombs):** Bastion and Backlash 10-s clips: >= 8 of 10 identify when invulnerability ends from the blink; in co-op, a second player standing in the Bastion survives a bullet that crosses the dome edge in >= 4 of 5 trials.

> Criteria drafted by game-designer (qa-lead not consulted, auto-approve). Manual pass bars are proposals.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Perf: Breaker cancels per tick in 4P** (K11: up to 12 areas x 1,350 bullets). Does the Bullet manager cancel path (GDScript, ADR-0001) stay within 2.5 ms p99, with a grid broad-phase? Fallback: `net_pulse_interval` 3-4 (tunnelling limit 6). Godot 4.7 behaviour of packed-array loops is unverified. | Bullet manager (3), lead-programmer, godot-specialist | Before the kit epic |
| 2 | Bullet manager `cancel_report[]` (shape settled 2026-11-03: one merged per-tick report, BM Rule 13): cost, request ids, FIFO ordering, how it interacts with `items = false` removal reasons. | Bullet manager (3) | Before the kit epic |
| 3 | Replace the assumed numbers with telemetry: landing `eta` (0.80/0.95/0.85/0.85/0.90/0.60), Sentry in-range share 0.75, Breaker contact share 0.35, `fill_eff` 0.70, Breach share 0.40, 30-tick return; re-check K8 (band +/-10% of 800, pairwise >= 0.90) and the net erase rate (<= 10/s). | analytics, balance | First playtest |
| 4 | Breaker's score from erasing is indirect only (no gems). Does the plane feel under-rewarded for taking risk? Option if so: a small `net_gem_cap` (for example 5 gems per use) under the Powerups cap. | Playtest, Powerups (13) | First playtest |
| 5 | Sentry range 160 px is not drawn after the first 30 ticks. Is the tick-mark cue enough, or does the player need a toggled range display (an accessibility/assist option)? | UX designer, Accessibility (28) | HUD spec |
| 6 | Art bible 5.6 says the Breaker draws "a pulse arc in front"; this GDD draws four corner brackets for an honest full-circle zone (Conflict 3). Art confirm, or change the zone to a forward half-disc (needs a half-disc cancel shape in the Bullet manager). | art-director | Before plane art |
| 7 | Sentry Entrench speed 75 (slowest of all kits) vs the benefit of tracking drones: does anyone hold Fire with 0-1 drones? Consider Entrench speed 90. | Playtest | First playtest |
| 8 | Breaker bolts target the nearest enemy only. Should they prefer the boss core when it is in Critical (helping the Critical Break)? Requires CB to expose a target hint. | Critical Break (17) | CB review |
| 9 | Pattern designers must treat up to 120 erased bullets per Breaker per 930 ticks as normal (Amendment 11). Does Boss (14) need an `erase_resist` flag for specific signature bullets? (Rejected here: it would hide a rule from the player.) | Boss (14), Pattern library (9) | Boss review |
| 10 | Confirm the shared `DroneBank` / `PlaneKit` split and that Sentry's and Breaker's per-kit state machines fit it (answers LL OQ15). | lead-programmer | Target tier |
| 11 | Backlash hits every target above the plane once for 500: is it too strong against waves of SMALL/MEDIUM (it kills all SMALL anywhere above)? Compare with Bastion's local power. Consider `backlash_damage` 400. | Playtest | First playtest |
| 12 | Co-op: should the Bastion dome also grant allies a short invulnerability, or is cancel-only enough? (Default: cancel-only.) | Co-op (18) | Playtest |
| 13 | Era 3-4 art for these planes is Target tier: confirm skins are visual only (as LL OQ14). | Creative director | Era shift review |
| 14 | `ref_dps` 800 is the floor of the MVP kits; Breaker at 777.2 is below it. Keep 800 and retune the plane (default) or recompute `ref_dps` including Target planes (700)? | Balance, Boss power budget (15) | First playtest |

> Decided under auto-approve (2026-11-03): kit cancels give no gems (items = false); stock cap per pulse 4; budget 30; zones are circles drawn as corner brackets; Backlash and Bastion damage values as in SB8; Sentry's early recall after 60 ticks; shared tags 2-3; Sentry/Breaker rank rotation as Bombs.


