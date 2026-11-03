# Plane Kits and Drones: Lancer, Leech

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Four Planes, Four Games (primary), Every Hit Counts, Readable Chaos (honest invulnerability), History Accelerates (era hook, visuals only)

> **Revision 2026-11-09 (Drone press is buffered; no rule change)**: a Drone press now reaches Rule 30's gate through the **6-tick press buffer** of [Input (2)](input-and-player-mapping.md) Rule 17 instead of only on its own tick. The gate itself is unchanged - a press is still accepted only when the ability is READY and the plane holds at least one drone - but a press made up to 6 ticks before the cooldown ends, or before a pod lands, is no longer thrown away, and the press is consumed only on the tick the drones actually launch. A press that *cannot* be accepted inside the window expires, and the run scene says which it was ("NO DRONES - COLLECT A POD" / "DRONES RECHARGING {n}s"), because "I pressed Drone and nothing happened" was the single commonest complaint in play. Regression cover: `tests/unit/test_input_buffer.gd`.

## Overview

**The data layer:** a **plane kit** is a node-free logic class (one per slot, `tick()` at 60 Hz) that turns the three buttons into attacks. It owns: the **normal shot** (tap Fire), the **charge mode** (hold Fire: Lancer's **laser**, Leech's **focused shot**), the **Drone ability** (Drone button), the **idle drone bullets**, the **Lancer laser meter**, and every drone's state, position and cooldown. It does not own bullets (it *requests* them from the Bullet manager 3), damage resolution (Collision 6), the chain (7), bombs (12) or the drone *count* (Session 1 / Powerups 13). All numbers are integers in ticks, px and damage units, and live in `data/kits/*.tres`. The kit sends damage events and invulnerability requests; it never touches the chain directly. Because every counted hit refills the chain, the kit's **hit rates** are the chain's speed limit, so this GDD caps them per source (K9).

**The player impact:** the two MVP planes chain in different ways. **Lancer** is a *burst-and-hold* plane: a wide 3-way shot, a meter that fills from the plane's own hits, a laser that makes the plane **invulnerable** for a few seconds, and Drone-button lasers that **park** and keep hitting the boss while the plane dodges. **Leech** is a *latch-and-sustain* plane: a narrow stronger shot, and drones that **latch onto enemies** and keep hitting them (then jump to the next) so the chain keeps climbing wherever the plane flies. Both get stronger only by **drones** (powerups), and both lose that strength on death. Lancer's invulnerable laser is the flagged dominance risk; the meter economy (fill 2 per hit on a 1,000 meter) keeps it to roughly 15-22% of a fight, and the numbers in K3-K5 show why.

## Player Fantasy

**Direct: the player feels the kit in their thumb every second.** MDA aesthetics: **Challenge** and **Expression** (how you chain), **Fantasy** (the spear and the leech).

- **Lancer: "I am the spear."** The anchor moment: the boss core goes critical, the curtain closes, the player holds Fire. The nose lens lights, a white-gold beam punches up through the bullets, and the plane slows to a crawl, untouchable, while the counter rolls. The beam stops. Twelve ticks of afterglow, then the plane is mortal again, and the player must already be standing in a gap. The meter is a promise: *spend it now to survive the curtain, or save it for the Critical Break.*
- **Leech: "Nothing gets away."** The anchor moment: the player presses Drone, four hook-claws fly out, bite into the boss turrets and the counter keeps ticking while the plane slides sideways through a curtain. A turret dies, the claws jump to the next one, and the chain never gets a gap. The fantasy is *control through attachment*: you chose what to bite.
- **Tap vs hold.** Tapping Fire is fast and wide; holding Fire is slow and strong. The same button asks "do I move, or do I commit?" (Autonomy)
- **Honest power.** The player can see the whole kit: the meter bar, the drone lamp, the beam, the afterglow. Invulnerability is never a hidden rule; when it ends, they see it end (Readable Chaos, Competence).
- **A growing escort, a harsh reset.** Each drone adds a visible gun; death removes them all. Kits never get *stronger* any other way, so the run is about skill, not stats.

It serves **Four Planes, Four Games** (each kit has its own resource, its own chain rhythm and its own risk), **Every Hit Counts** (all kit hits count; ignored ones don't) and **Readable Chaos** (beams sit under bullets; the grace window is shown).

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

Units: **tick** = 1/60 s; **px** on the 360x640 canvas; **damage unit** (integer). One standard bullet = **20 damage**, which equals `armour_damage_min` (Collision C4), so *every* damage value in this GDD can safely hit armour.

**A. All kits**

1. **One kit core per slot.** A node-free `RefCounted` class per slot ticks once per 60 Hz tick, after the Player plane updates and before Collision step 1. It uses no `delta`, no global `randf()` and no randomness at all (ties break by target id). A thin Node adapter draws and plays sound. The kit holds no bullet references (Bullet manager Rule 5).
2. **Buttons.** The kit receives, per tick, Fire `{pressed, held, released}` and Drone `{pressed}` from the Player plane (Player plane Rule 9). It counts its own held ticks: **`h`** = ticks since the Fire press (press tick `h = 0`). The Bomb button goes to Bombs (12), not to the kit. A Fire already held when the plane becomes Active starts as `pressed = false, held = true, h = 0` (Player plane Rule 10) and fires like a fresh hold.
3. **Active only.** The kit acts only while the plane is **Active**. In FlyIn, Dying and Absent it fires nothing, requests nothing and ignores buttons.
4. **Fire modes (the Fire state machine, States table).** Each press starts **SHOT** (normal shot). If Fire is still held when `h` reaches **`charge_hold_ticks` = 18** (0.3 s), the kit tries to enter **CHARGE** (the plane's charge mode). If charge is unavailable (Lancer meter below `laser_min_meter`), it enters **HOLD_PLAIN** instead: the normal shot continues, hands-free, for as long as Fire stays held.
5. **Tap linger.** If Fire is released with `h < 18`, the normal shot keeps firing for **`shot_linger_ticks` = 12** more ticks (so a thumb tapping about twice a second keeps the gun going). A press during the linger starts a new `h`. A release from CHARGE or HOLD_PLAIN has no linger: it stops at once. *(2026-11-03, wave 4, Touch controls (31) Rule 23:)* touch auto-fire pulses every `autofire_period` (10, ≤ `shot_linger_ticks`) rely on this linger; changing `shot_linger_ticks` below 12 requires revisiting the period.
6. **One shot cooldown.** The plane shot uses a single counter: a volley fires when `shot_cd == 0` and the shot is allowed, then `shot_cd = interval`. The counter is not reset by presses or by switching modes, so mashing can never beat the interval.
7. **Focus speed comes from the plane, not the kit.** The Player plane applies `focus_speed` (105 px/s) *while the Fire button is physically down* (Player plane Rule 4, PF1). So a tap is a short slow-down and a hold is a long one. A linger after release moves at full speed.
8. **Bullets go through the Bullet manager.** The kit requests player-pool bullets: `request_spawn(pos, vel, shape, damage, owner = slot, tag)`; Straight only; speed 900 px/s (15 px/tick). **`tag`**: 0 = plane shot, 1 = drone bullet (Target kits add 2 = charge shot/slug, 3 = return bolt; Sentry/Breaker (29), 2026-11-03) (new field, Amendments 2-3). The plane shot uses the **streak** shape, drone bullets the **diamond**. If the manager refuses a request (`refused_player` or `refused_player_share`), that bullet is lost: no retry, and the volley counter and cooldowns still advance.
9. **Idle drone bullets.** Idle (docked) drones fire while the plane's shot is on (state SHOT, CHARGE or HOLD_PLAIN): one straight diamond every **`drone_interval` = 8** ticks, damage 20, from the drone's position. Each drone has a fixed phase: `phase_d = (d x 8) div 4` for drone index `d` (0..3), giving ticks 0, 2, 4, 6 of each 8-tick cycle. A drone that is not docked (parked, flying, latched, returning) fires no bullets.
10. **Kit hits are damage events.** Laser ticks, parked-beam ticks and latch ticks are sent to Collision as `(target, slot, damage, source, seq)` with source **LASER** (Lancer's own beam) or **DRONE** (parked beams, latch ticks), and a per-slot `seq` counter. Collision decides ignored / hit / destroyed and sends `chain_hit` (Collision C5). The kit never calls the chain or scoring.
11. **Hit results come back.** Collision returns each result to the kit (`on_hit_result(source, tag, target, result)`). The kit uses them for the Lancer meter (Rule 20) and for Leech's immune-target check (Rule 38). Only **hit** and **destroyed** count for the meter.
12. **Damage values are fixed.** No kit value rises with drones, eras, chain, score or time. Drones add *more guns*, never stronger ones.
13. **Reset rules.**
    - `plane_died(slot)` (Player plane, once): all drones are removed at once, deployed ones included; the laser stops; Fire state IDLE; Drone ability READY with cooldown 0; `shot_cd = 0`; Lancer meter = `meter_death_keep` (default 0). Requests made after this tick are dropped.
    - `stage_cleared`: the laser stops; every deployed drone **snaps** to its wing slot and docks; Fire state IDLE; cooldown = 0. The Lancer meter and `drone_count` **carry over**.
    - `stage_started`: nothing changes (the state above already carries).
14. **Targets.** A target is **eligible** for kit attacks if: it has a hurtbox, its bottom edge `y >= 0` (at least partly on screen), it is alive, and its damage mode (snapshot) is not **immune**. Armoured targets are eligible (their hits count). Ineligible targets can still *block* a beam (Rule 24), because the hurtbox is physically there.
15. **Target queries (Amendment 2; added to the Bullet manager GDD 2026-11-03).** The kit calls two read-only queries on the hurtbox registry (owned by the Bullet manager grid): `first_in_column(x, half_width, y_from)` returns the nearest hurtbox above `y_from` whose x-range overlaps `|dx| < target_half_width + half_width` (lowest id on ties), and `nearest(pos, filter)` returns the eligible target with the smallest squared distance to `pos` (lowest id on ties). Both use the start-of-tick registry.

**B. Lancer (wide shot, laser, parked lasers)**

16. **Normal shot.** Volley every **5** ticks (12 volleys/s): **3** streak bullets, damage **20**, speed 15 px/tick. Muzzle points `(-6, -14)`, `(0, -14)`, `(+6, -14)` relative to the plane centre; headings straight up and 9 degrees to each side (K2). Peak 36 bullets/s.
17. **Charge mode = laser.** Available when `meter >= laser_min_meter` (400 of 1,000) *at the tick `h` reaches 18*. This is an **edge check**: if it fails, this press is HOLD_PLAIN for good (the laser will not start later in the same hold, even if the meter reaches 400). Release and press again to try again. The first laser tick is the tick `h = 18`.
18. **Laser, each active tick** (in this order): (a) `request_invuln(slot, 1 + laser_exit_grace)` = 13 ticks (Collision C3); (b) `meter = max(0, meter - 5)`; (c) find the beam target with `first_in_column(plane.x, 7, plane.y - 14)` (beam width 14); (d) if the active-tick index `k` satisfies `k mod 3 == 0` and a target exists, send one damage event of **60** (source LASER); (e) tell the plane `set_ability(true, 90)`; (f) if `meter == 0`, the laser ends after this tick. A full 1,000 meter gives exactly **200** active ticks (3.33 s); 400 gives **80** (1.33 s).
19. **Laser rules.** The laser stops when Fire is released, the meter hits 0, the plane dies, or the stage clears. While it is on, the plane shot is off but **idle drones keep firing** their bullets. The beam **stops at the first hurtbox** in its column, including immune ones (which return *ignored* and do not count), so an immune shield blocks the laser. With no target the beam runs to the top of the screen, no events are sent, **the meter still burns and the invulnerability is still requested**. After the last active tick the invulnerability lasts 12 more ticks (the exit grace, Collision C3). The laser never needs a target to shield the player.
20. **Meter fill.** The meter fills by **`fill_per_hit` = 2** for each **counted** (hit or destroyed) result whose source is a **plane shot bullet (tag 0)**. It does **not** fill from drone bullets, parked beams, latch ticks, the laser itself, bombs, pickups or time. It does **not** fill while the laser is active (a shot already in flight that lands during the laser gives nothing). It stops at 1,000; overflow is lost. The meter is an integer 0-1,000. The fill is credited on the tick the result is delivered and can start a laser on the next tick.
21. **Meter on death and stage end.** Death sets the meter to `meter_death_keep` (0). Stage end keeps it. The meter is not shown or kept anywhere outside the run.
22. **Ability speed.** While the laser is active the kit reports `ability_active = true, ability_speed = 90 px/s` (1.5 px/tick) to the Player plane. During the 12 grace ticks the ability is *not* active: the plane moves at its normal speed.
23. **Drone ability: park.** Pressing Drone when ready (Rule 30) sends every docked drone to **park where it is**: the drone's world position at the press tick, with `x` clamped to `[8, 352]` (it slides there at 4 px/tick). A **parked** drone fires a thin vertical **beam** upward: width 6, found with `first_in_column(x, 3, y - 6)`, a damage event of **40** (source DRONE) every **8** ticks at phase `(d x 8) div 4`. Parked beams do not need the plane to be firing, do not grant invulnerability, do not touch the meter, and stop at the first hurtbox like the laser does. A parked drone that overlaps nothing is harmless and cannot be hit.
24. **Park timing.** Parked time is **`park_ticks` = 300** (5 s), counted from the press. Then the drones go to RECALL (Rule 31).
25. **No second resource.** The drone ability uses its **cooldown only**, never the laser meter (this closes game-concept §5's open question). The laser and the parked lasers are independent and can run at the same time.

**C. Leech (narrow shot, focused shot, latch drones)**

26. **Normal shot.** Volley every **5** ticks (12 volleys/s): **2** streak bullets, damage **20**, muzzle points `(-5, -16)`, `(+5, -16)`, headings 4 degrees outward (K2). Peak 24 bullets/s.
27. **Charge mode = focused shot.** Always available (no resource). From the tick `h = 18` the normal shot is replaced by: **2** streak bullets per volley, damage **30**, muzzle points `(-3, -16)`, `(+3, -16)`, heading straight up (a 6 px wide pair), one volley every **6** ticks (10 volleys/s, 20 bullets/s). It uses the shared `shot_cd`, so the first focused volley fires when the cooldown reaches 0. It stops when Fire is released. The Leech reports no `ability_active` (the plane's `focus_speed` 105 applies while Fire is down).
28. **Drone ability: latch.** Pressing Drone when ready (Rule 30) starts the timer **`latch_ticks` = 360** (6 s). Each docked drone leaves its slot and picks a target by Rule 34.
29. **Latched drone.** A drone that reaches its target (distance to its latch point <= 14 px at the start of a tick) is **LATCHED**: it rides the target (display offset only), follows it as it moves, and sends one damage event of **20** (source DRONE) every **5** ticks at phase `(d x 5) div 4` (ticks 0, 1, 2, 3 of each 5). That is 12 hits/s per drone. Latched drones fire no bullets.
30. **When the Drone button works (both kits).** The press is accepted only if all of these hold: the plane is Active; the ability is **READY** (cooldown 0, drones not deployed); `drone_count >= 1`. Leech also needs at least one eligible target on screen. A rejected press does nothing, starts no cooldown, and emits `drone_denied(slot, reason)` with reason `NO_DRONES`, `COOLDOWN`, `ACTIVE` or `NO_TARGET`. A press while the ability is ACTIVE is ignored (`ACTIVE`): there is no early recall.
31. **Recall and cooldown (both kits).** When the timer reaches 0 (or on `stage_cleared`, instantly), every deployed drone is **RETURNING**: each tick, if it is within 10 px of its wing slot (the slot moves with the plane) it docks; otherwise it moves 10 px toward it. After **`return_cap` = 45** ticks any drone still out snaps to its slot. When the **last drone docks**, the cooldown starts: **Lancer 600** ticks (10 s), **Leech 540** ticks (9 s). At cooldown 0 the ability is READY.
32. **New drones during the ability.** If a powerup raises `drone_count` while drones are deployed, the new drone appears docked in the next free wing slot (Player plane edge case), fires idle bullets, and does **not** join the running ability. It can be used the next time.
33. **Flight.** Leech drones fly at **`latch_speed` = 14 px/tick** (840 px/s) straight at the target's current latch point each tick (homing). A drone in flight cannot be hit and deals no damage. The longest possible jump (screen diagonal 734 px) takes 53 ticks, always less than `chain_window` (K11).
34. **Choosing a target (initial launch and every jump).** Drones are processed in index order `d = 0..3`. A drone picks `nearest(drone position)` among eligible targets, **skipping targets already claimed by `latch_max_per_target` = 2 drones** (a claim = latched or flying to it). If every eligible target is full, the cap is ignored for that drone. If there is no eligible target, the drone enters **SEARCHING**: it hovers in place and re-checks each tick; the timer keeps running.
35. **Retarget.** When a drone's target is destroyed, leaves the screen (bottom edge `y < 0`, or its centre more than 40 px outside any screen edge), or is removed, that drone immediately picks a new target by Rule 34 from its current position, and flies. Jumping drones are independent of each other.
36. **Timer end.** At 0, drones in any state go RETURNING (Rule 31).
37. **Latch lifetime.** The drone ability does not depend on `drone_count` after launch. It lasts the full 360 ticks even if every target dies (drones SEARCH, then return at the end).
38. **Immune and unfair targets.** If a latched drone gets **30** consecutive *ignored* results from its target (`ignored_streak_limit`), that target becomes ineligible for **60** ticks for that drone and it retargets. (The target's mode can flip to immune after the drone launched.)

**D. Hit-rate caps (why the chain is not trivial).**

39. Every damage source has a fixed interval and a fixed phase (Rules 9, 18, 23, 29), so no kit can exceed the per-source rates in K9. The structural caps are:
    - a plane volley is at most 3 bullets (Lancer) or 2 (Leech); bullets cannot multi-hit (Bullet manager: one hit, then removed);
    - the kit sends at most **2** damage events per tick (Lancer: laser + one parked drone) or **1** (Leech: one latch drone), because the phases never coincide beyond that;
    - raw maximum is **72 counted hits/s** per player (Leech tapping + 4 latched drones), which gives `chain_cap` 999 in no less than **13.9 s** even with perfect landing (K9).
    The cap value is checked by a data test (AC-31).

**E. Charge-mode contract with Critical Break (17) and Bombs (12)** (specified in `critical-break.md` F1, 2026-11-03)

40. The kit publishes per tick: `charge_active(slot)` (bool: Lancer laser *active ticks only*, not grace; Leech focused shot active), `charge_kind(slot)` (`LASER` or `FOCUS`; Target kits add `ENTRENCH` and `BREACH`, Sentry/Breaker (29)), `charge_last_hit(slot)` as `(target_id, tick)` for the last counted charge-source hit (laser tick or focused bullet), plus `laser_meter(slot)` and `drone_state(slot)` = `(state, cooldown_permille)`: `state` READY / ACTIVE (drones deployed) / COOLDOWN, `cooldown_permille` = `cooldown_left × 1000 div cooldown` (0 when READY or ACTIVE); read-only for the HUD and the Touch Drone button (Touch controls 31) *(defined 2026-11-03, consistency check)*. **Critical Break owns the trigger** (core at critical HP + charge active + bomb); the kit never triggers, ends or changes anything because of a Critical Break. The Bomb button never interrupts the laser, costs no meter and fills no meter. *(2026-11-03, Critical Break 17:)* `charge_last_hit` target ids are boss part ids (the core is 1000 + 0, Boss `core_target_id()`); CB checks that the last charge hit was on the core within `cb_hit_window` (12) ticks. HOLD_PLAIN shots, drones and the bomb are not charge.

**F. Era hook (Era shift 19, [GDD](era-shift-and-plane-evolution.md))**

41. Era shift sets the plane's `era_index`. Each kit has one **`EraKitSkin`** resource per era (`data/kits/skins/*.tres`) that may change **only**: sprite and animation ids, beam and bolt-on art, muzzle flash art, sound ids, and muzzle *positions* within +/-4 px of the defaults. It may **not** change any damage, interval, count, angle, speed, width, cooldown, duration or meter number. All kit numbers are identical in every era (AC-35); plane evolution is **visual only** (Era shift 19, closed 2026-11-03). The skin list also includes `drone_sprites` per era. The `EraKitSkin` is selected by `era_index` at `era_swap_committed`. This honours "shots never get stronger" and keeps History Accelerates in the visuals.

**Prototype migration (what exists in `src/gameplay/player/` and what changes)**

| Prototype (`laser_ability.gd`, `shot_weapon.gd`, `plane_config.gd`, `lancer.tres`) | Problem | Corrected here |
|---|---|---|
| `meter_per_hit 0.6` on `meter_max 100` (167 hits to fill) | Refills in ~5 s of fire while the laser burns 4 s: **~44% laser uptime**, i.e. near-permanent invulnerability | Fill 2 on 1,000 (500 hits): ~15-20% (K3-K5) |
| Meter also fills from bombs | Bomb spam feeds the laser | No fill from bombs or drones (Rule 20) |
| Laser holds plane invulnerable directly (`is_invulnerable` = `laser.active`) | No exit grace, bypasses Collision | `request_invuln(1 + 12)` each active tick (Rule 18) |
| `meter -= burn * delta`, `_tick_acc += delta`, floats | Frame-rate-dependent, not deterministic | Integer ticks: burn 5/tick, laser tick every 3 ticks |
| `laser_damage 3.0`, `shot_damage 1.0` floats | Collision uses integer damage; armour needs >= 20 | 60 and 20 |
| Twin shot every 0.06 s (33 bullets/s), `shot_offset 8` | Old 480 px canvas | 3-way fan, 36/s, canvas 360 px (Rule 16) |
| Shots are local data rows tested against boss parts only | Not pooled, no enemies, no co-op share | Bullet manager player pool, tagged (Rule 8) |
| Laser targets only `BossPart` | No small enemies | Column query over all hurtboxes (Rule 15) |
| `speed 280 / 200 / 120` | Old canvas, ability on its own button | Plane owns 210 / 105; Lancer ability speed 90 (Rule 22) |
| Laser starts by holding the `ability` action | Button now means Drone | Fire hold >= 18 ticks starts the laser; Drone button is the drone ability |
| `register_hit(result, gain_meter)` called by weapons | Kits credit their own chain | Collision sends `chain_hit`; kit only receives results |
| Bomb + laser + critical handled inside `player.gd` | Mixed systems | Critical Break (17) owns it; kit publishes `charge_active` (Rule 40) |
| No drones | — | Rules 9, 23-38 |

> Decided under auto-approve (2026-11-03): Fire press = normal shot with a 12-tick tap linger; hold >= 18 ticks (0.3 s) = charge mode, shot stops, edge check on the Lancer meter; HOLD_PLAIN keeps firing slowly if the laser is unavailable; meter 1,000 / min 400 / burn 5 / fill 2 from plane-shot hits only; no fill while the laser runs; laser 60 damage every 3 ticks (20 hits/s, 3x per-hit); Lancer ability speed 90; Leech has no ability speed; Lancer park in place 300 ticks with 40-damage beams every 8; Leech latch 360 ticks, 20 damage every 5, max 2 drones per target, speed 14; cooldowns 600 / 540 starting at the last dock; no early recall; deployed drones snap home at stage clear; death resets meter, cooldown and drones; kit hits never fill meter from drones; era skins change visuals only.

### States and Transitions

**Fire state (per slot)**

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| IDLE | No normal shot | SHOT | Fire pressed (plane Active) |
| SHOT | Tap fire: `h < 18` while held, or the 12-tick linger after a release | IDLE | Fire released and `linger_left == 0` |
| SHOT | | CHARGE | Fire held, `h == 18`, charge available (Lancer `meter >= 400`; Leech always) |
| SHOT | | HOLD_PLAIN | Fire held, `h == 18`, Lancer meter `< 400` |
| CHARGE | Lancer laser or Leech focused shot | IDLE | Fire released |
| CHARGE | (Lancer) | HOLD_PLAIN | Meter reached 0 while Fire still held (laser ends) |
| HOLD_PLAIN | Lancer only: continuous normal shot at focus speed | IDLE | Fire released |
| Any | | IDLE | `plane_died`, `stage_cleared`, or plane not Active |

A release in SHOT with `h < 18` sets `linger_left = 12`. A new press in SHOT/linger restarts `h` at 0. Linger has no effect in other states.

**Laser (Lancer only)**

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| Off | No beam, `ability_active = false` | On | Fire state enters CHARGE |
| On | Beam, invulnerability requested each tick, meter burns | Grace | Release, or meter reached 0 (ends after that tick) |
| Grace | 12 ticks of leftover invulnerability (owned by Collision's timer; the kit sends nothing) | Off | Timer reaches 0 |
| On / Grace | | Off | `plane_died` / `stage_cleared` (Grace is cleared only on death, because the plane is gone) |

**Drone ability (per slot)**

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| READY | Cooldown 0, drones docked | ACTIVE | Drone pressed and accepted (Rule 30) |
| ACTIVE | Timer running (Lancer `park_ticks` 300, Leech `latch_ticks` 360) | RECALL | Timer 0, or `stage_cleared` (instant snap, then READY) |
| RECALL | Drones returning (cap 45 ticks) | COOLDOWN | Last drone docked |
| COOLDOWN | Counting 600 / 540 | READY | Cooldown 0 |
| Any | | READY (cooldown 0, no drones) | `plane_died` |

**Per-drone state**

| State | Kit | → Next | Trigger |
|---|---|---|---|
| DOCKED | both | PARKING (Lancer) / FLYING (Leech) | Drone ability accepted |
| PARKING | Lancer | PARKED | Reached clamped park x |
| PARKED | Lancer | RETURNING | Timer 0 |
| FLYING | Leech | LATCHED | Within 14 px of the latch point |
| FLYING | Leech | FLYING / SEARCHING | Target lost: new target / none |
| LATCHED | Leech | FLYING / SEARCHING | Target destroyed, off screen, removed, or ignored-streak 30 |
| SEARCHING | Leech | FLYING | An eligible target appears |
| Any deployed | both | RETURNING | Timer 0 |
| RETURNING | both | DOCKED | Within 10 px of the slot, or return cap 45 |
| Any | both | removed | `plane_died` |

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Player plane (5) — GDD | ← buttons (Fire `{pressed, held, released}`, Drone `{pressed}`), plane position and state, `wing_slot(i)`; → `set_ability(active, speed)`; ← `plane_died(slot)`, `stage_cleared` | Kit never moves the plane. Focus speed is applied by the plane while Fire is down. |
| Bullet manager (3) — GDD | → `request_spawn(...)` player pool with `tag`; ← refusals, hit reports; ↔ hurtbox queries `first_in_column`, `nearest` (Amendment 2, in the Bullet manager GDD) | Beams and latch are not bullets (Bullet manager Rule 4 note). |
| Collision (6) — GDD | → damage events `(target, slot, damage, LASER or DRONE, seq)`, `request_invuln(slot, 13)` every laser tick; ← hit results with `tag` | Shot bullets reach Collision through the Bullet manager. |
| Chain tracker (7), Scoring (8) — GDD | none directly | Collision sends `chain_hit`; Scoring pays hits and kills. |
| Session (1) — GDD | ← `drone_count`, slot state, `stage_started`, `stage_cleared` | Kit never writes `drone_count`. |
| Powerups (13) — [GDD](powerups-and-drops.md) | ← `drone_count` +1 via Session | Not a powerup: meter, bombs. Cooldown and meter are never refilled by pickups. |
| Enemy (10), Boss (14) — [GDD](boss-and-boss-parts.md) | ← hurtboxes with `id, gen`, bottom edge, damage mode, `latchable` (default true) | Boss designers may set `latchable = false` for a part. |
| Bombs (12) — [GDD](bombs.md) | ← `bomb_started(slot)` (info only); Bombs read no kit state (Bombs Rule 7; Open Question 7 closed) | Bomb press goes plane → Bombs, not through the kit. No meter cost or fill. |
| Critical Break (17) — [GDD](critical-break.md) | → `charge_active`, `charge_kind`, `charge_last_hit` | CB owns the trigger; supplied state only. |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | ← `era_index` (at `era_swap_committed`) | Selects `EraKitSkin` (visuals only, Rule 41). |
| Co-op (18) — GDD | ← `N` (player count) for the per-slot player-pool share | Each slot's kit is independent; no sharing. |
| HUD (20) — [GDD](hud.md) | → per tick: `kit_bar(slot) -> (num, den)` (ints), `kit_ready`, `drone_lamp` (state, ratio), `drone_count` | See UI Requirements. |
| Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | → events: `laser_started`, `laser_ended`, `laser_ready`, `drone_deployed`, `drone_latched`, `drone_jumped`, `drone_docked`, `drone_denied`, `shot_volley` | See Visual/Audio. |

All listed systems now have GDDs *(2026-11-03, wave 3b)*; the contracts above are what this GDD expects.

## Formulas

All time in integer ticks, distance in px, damage in integer units. `h` = held ticks, `k` = active-tick index (first active tick `k = 0`).

**K1. Fire timing**

`charge_tick = press_tick + charge_hold_ticks`; plane volley allowed on tick `t` iff `shot_cd(t) == 0` and state in {SHOT, HOLD_PLAIN}; after a volley `shot_cd = interval`, each tick `shot_cd = max(0, shot_cd - 1)` first; linger allows ticks `R .. R + shot_linger_ticks - 1` for a release on tick `R`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Charge hold | `charge_hold_ticks` | int ticks | 12-30 (18) | Held ticks before charge mode |
| Linger | `shot_linger_ticks` | int ticks | 6-24 (12) | Shot continues after a tap |
| Shot interval | `interval` | int ticks | 4-7 (Lancer 5, Leech 5 normal / 6 focus) | Ticks between volleys |
| Shot cooldown | `shot_cd` | int | 0..interval | Shared by modes |

**Output Range:** volleys at most 1 per `interval` ticks. **Example (Lancer, meter 0):** press tick 0 held to tick 40: volleys at 0, 5, 10, 15 (SHOT), `h = 18` at tick 18 → HOLD_PLAIN (meter < 400), next volleys at 20, 25, 30, 35, 40. Tap: press 0, release 3 → linger allows ticks 3-14: volleys at 0, 5, 10; none at 15.

**K2. Shot velocity**

`vel = 15 x (sin a, -cos a)` px/tick (y down, `a` = degrees from straight up, positive = right); position at spawn `plane.pos + muzzle`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Angle | `a` | deg | Lancer -9, 0, +9; Leech normal -4, +4; Leech focus 0, 0 | Fixed per bullet |
| Speed | `v` | px/tick | 11.7-20 (15) | 900 px/s; player cap is 1,200 px/s |

**Output Range:** speed exactly 15 px/tick. **Example:** Lancer +9 deg: `(2.3465, -14.8153)`; at 300 px of climb the side bullet is `300 x tan 9 = 47.5 px` off the centre line (95 px fan). Leech +4 deg: `(1.0463, -14.9635)`, 21.0 px at 300 px.

**K3. Laser meter and duration**

`meter' = max(0, meter - laser_burn)` per active tick; `E = ceil(meter / laser_burn)` active ticks from the start; fill `meter' = min(meter_max, meter + fill_per_hit x n)` for `n` counted plane-shot hits delivered this tick, only while the laser is Off.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Meter | `meter` | int | 0-1000 | Laser resource |
| Max | `meter_max` | int | 600-1500 (1000) | Cap |
| Min to start | `laser_min_meter` | int | 250-600 (400) | Edge check at `h = 18` |
| Burn | `laser_burn` | int /tick | 4-8 (5) | While active |
| Fill | `fill_per_hit` | int | 1-3 (2) | Per counted plane-shot hit |

**Output Range:** `E` is 80-200 ticks at defaults (50-250 across the safe ranges). **Example:** meter 1000 → `E = 200` ticks (3.33 s); 400 → 80 (1.33 s); 403 → 81 (meter 403, 398, ... 3, 0 after tick 80, so 81 ticks).

**K4. Refill time**

`R = ceil((meter_max - m0) / (fill_per_hit x hits_per_tick))`, `hits_per_tick = eta_shot x 36 / 60`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Start meter | `m0` | int | 0..meter_max | Meter when refill begins |
| Landing | `eta_shot` | float | 0.5-1.0 (0.70 competent; 1.0 perfect) | Fraction of 36 bullets/s that hit |

**Output Range:** 833-1,500 ticks from empty. **Example:** perfect, from 0: `1000 / (2 x 0.6) = 833.3` ticks (13.9 s). Competent (0.70): `1000 / (2 x 0.42) = 1190.5` ticks (19.8 s). From 0 to the 400 minimum, perfect: `400 / 1.2 = 333.3` ticks.

**K5. Laser invulnerability duty (the dominance check)**

`duty = (E + laser_exit_grace) / (E + R)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Active ticks | `E` | int | 80-200 | K3 |
| Grace | `laser_exit_grace` | int ticks | 12 (Collision) | After the last active tick |
| Refill | `R` | float ticks | K4 | Ticks of fire needed |

**Output Range:** 0.15-0.23 at defaults. **Example:** perfect landing, full cycles: `(200+12)/(200+833.3) = 0.2052` (20.5%); perfect, minimum-activation spam: `(80+12)/(80+333.3) = 0.2226` (**22.3%, the maximum**); competent: full `212/1390.5 = 0.1525`, min-spam `92/556.2 = 0.1654`. The prototype's numbers (K5 with fill 0.6/100, 33 hits/s): 44% uptime. **Rule:** the data test fails if the perfect-landing maximum exceeds **0.25** (AC-30).

**K6. Laser and parked-beam schedule**

Laser hit at active tick `k` iff `k mod laser_tick_interval == 0` and a target exists: `hits = ceil(E / 3)`, `damage_total = hits x laser_damage`. Parked beam of drone `d` hits at ticks `t` with `t mod 8 == (d x 8) div 4`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Laser interval | `laser_tick_interval` | int ticks | 2-5 (3) | 20 hits/s |
| Laser damage | `laser_damage` | int | 40-90 (60) | 3x a plane bullet |
| Parked interval / damage | `parked_interval`, `parked_damage` | int | 6-12 (8) / 20-60 (40) | 7.5 hits/s each |

**Output Range:** events per tick <= 1 per source. **Example:** `E = 200` → 67 laser hits (k = 0, 3, ..., 198) = 4,020 damage; `E = 80` → 27 hits = 1,620. Drones 0-3 parked: phases 0, 2, 4, 6 of each 8 ticks.

**K7. Drone phases**

`phase_d = (d x interval) div 4`, interval 8 (bullets, parked), 5 (latch).

**Output Range:** distinct phases for 4 drones. **Example:** interval 8 → 0, 2, 4, 6; interval 5 → 0, 1, 2, 3 (`div` floors: 5, 10, 15 over 4).

**K8. DPS equivalence (single target; raw = 100% landing; effective = raw x landing `eta`)**

`dps = damage x hits_per_s`; `eff = dps x eta`

| Source | Damage | Hits/s | Raw dps | `eta` | Effective dps |
|---|---|---|---|---|---|
| Lancer plane shot | 20 | 36 | 720 | 0.70 | 504 |
| Lancer idle drone (each) | 20 | 7.5 | 150 | 0.60 | 90 |
| Lancer laser | 60 | 20 | 1,200 | 0.90 | 1,080 |
| Lancer parked beam (each) | 40 | 7.5 | 300 | 0.80 | 240 |
| Leech normal shot | 20 | 24 | 480 | 0.80 | 384 |
| Leech focused shot | 30 | 20 | 600 | 0.95 | 570 |
| Leech idle drone (each) | 20 | 7.5 | 150 | 0.60 | 90 |
| Leech latch (each) | 20 | 12 | 240 | 1.00 | 240 (x 0.85 on-latch share = 204) |

Assumptions (all unplaytested): Fire held the whole boss fight, 4 drones, laser duty from K4-K5 competent (`E / (E + R) = 200 / 1390.5 = 0.1438`), drone ability cycle `active + 30 return + cooldown` = 930 ticks for both kits.

- **Lancer average:** plane `0.8562 x 504 + 0.1438 x 1080 = 586.8`. Drones: parked `300/930 = 0.3226` x (4 x 240 = 960) + idle `600/930 = 0.6452` x (4 x 90 = 360) = `309.7 + 232.3 = 542.0`. **Total 1,128.8.**
- **Leech average:** plane focus 570. Drones: latched `360/930 = 0.3871` x (4 x 204 = 816) + idle `540/930 = 0.5806` x 360 = `315.9 + 209.0 = 524.9`. **Total 1,094.9.**

**Output Range:** the two kits' sustained effective DPS must be within **+/-10%** of each other (**0.970** at defaults). **Reference for Boss (14):** one competent 4-drone player deals about **1,100 dps** on a boss when on target; a 0-drone player about **590 (Lancer) / 570 (Leech)**. A 60-second boss with 70% on-target time is therefore about **46,000 hp** for one 4-drone player (the 4-drone *ceiling*; content is budgeted at the 2-drone reference below, about 33,600 hp per 60 s). (Prototype: Fortress total 1,760 hp at 1.0 damage per hit; x20 = 35,200.)

**Reference DPS for content budgets (`ref_dps`, owned here, registered in `design/registry/entities.yaml`; replaces the deprecated `enemy_ref_dps` 300).** Enemy (10) F8 and Boss (14) F6 budget hp with this single number. It is the K8 sustained effective dps of one competent player *on target* (landing `eta` already included; the 70% `ref_uptime_pct` of Boss F6 and the 1.4 `exposure_margin` of Enemy F8 are applied by those GDDs on top). Reference drone count: **2**, the typical mid-stage value (drones are lost on death and gained by powerups, so 0 is the post-death floor and 4 the best case; 2 is the middle of that range and keeps the 0 and 4 cases within about 1.4x / 0.73x of the target length).

`dps(n) = plane_avg + n x drone_avg_per_drone`; Lancer `plane_avg` 586.8, per drone `0.3226 x 240 + 0.6452 x 90` = 135.5; Leech `plane_avg` 570.0, per drone `0.3871 x 204 + 0.5806 x 90` = 131.2 (same cycle assumptions as above).

| Drones `n` | 0 | 1 | **2 (reference)** | 3 | 4 |
|---|---|---|---|---|---|
| Lancer | 586.8 | 722.3 | **857.8** | 993.3 | 1,128.8 |
| Leech | 570.0 | 701.2 | **832.5** | 963.7 | 1,094.9 |

`ref_dps = floor100(min(Lancer(2), Leech(2))) = floor100(832.5) = 800` (int, damage units/s; safe range 400-1,200; rounded down so the content is not tuned to the stronger kit). Worked example: a MEDIUM at TTK 1.5 s has hp `1.5 x 800 = 1,200`; a 45 s boss fight at 70% uptime has `800 x 0.70 x 45 = 25,200` hp of parts plus core main pool (Boss F6: Fortress 11,200 + 14,025).

**K9. Hit rates and chain climb time**

`T999 = chain_cap / hits_per_s` (seconds); raw rates are structural, landed rates use `eta`.

| Mode (4 drones) | Raw hits/s | Landed hits/s | Seconds to 999 (raw / landed) |
|---|---|---|---|
| Lancer tap/normal | 36 + 30 = 66 | 25.2 + 18 = 43.2 | 15.1 / 23.1 |
| Lancer laser (+ idle drones) | 20 + 30 = 50 | 18 + 18 = 36 | 20.0 / 27.8 |
| Lancer parked (+ plane shot) | 36 + 30 = 66 | 25.2 + 24 = 49.2 | 15.1 / 20.3 |
| Leech tap (normal) | 24 + 30 = 54 | 19.2 + 18 = 37.2 | 18.5 / 26.9 |
| Leech focus (+ idle) | 20 + 30 = 50 | 19 + 18 = 37 | 20.0 / 27.0 |
| Leech focus + latch | 20 + 48 = 68 | 19 + 40.8 = 59.8 | 14.7 / 16.7 |
| **Leech tap + latch (max)** | **24 + 48 = 72** | 19.2 + 40.8 = 60.0 | **13.9** / 16.7 |

**Output Range:** raw max **72/s**, i.e. never more than 1.2 hits/tick on average. **Constraint:** `T999_min >= 12 s` (AC-31). Scoring F7 assumes more (Open Question 1).

**K10. Player-pool load**

`live = ceil(rate_per_tick x lifetime_ticks)`, `lifetime = ceil((spawn_y + offscreen_margin) / 15)`; worst spawn_y 620 → `ceil(640/15) = 43` ticks.

**Output Range:** per slot ≤ 48 live bullets. **Example:** Lancer `(3/5 + 4/8) x 43 = 1.1 x 43 = 47.3` → 48; Leech normal `(2/5 + 0.5) x 43 = 38.7` → 39. 4P all Lancer: `4 x 48 = 192 <= 600` (`player_cap`) and each slot <= 150 (`floor(600/4)`, Co-op Rule 11): margin 3.1x.

**K11. Latch flight**

Each tick: `if dist <= latch_speed: latch; else pos += latch_speed x unit(target - pos)`. Longest jump ticks = `ceil(diag / latch_speed)`; constraint `ceil(diag / latch_speed) + 1 <= chain_window - 1` so a jump can never by itself drop a chain that other hits could hold.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Flight speed | `latch_speed` | float px/tick | 10-16 (14) | 840 px/s |
| Screen diagonal | `diag` | px | 734.3 | `sqrt(360^2 + 640^2)` |

**Output Range:** 1-53 ticks. **Example:** target 280 px away: the drone moves on ticks 1-19 (distance after 19 moves = `280 - 14 x 19 = 14`), and on tick 20 the distance is 14 <= 14, so it latches. Diagonal: `734.3 / 14 = 52.5` → 53 ticks, and `53 + 1 = 54 <= 59`.

**K12. Drone ability cycle**

`cycle = active_ticks + return_ticks + cooldown`; `active_share = active_ticks / cycle`.

**Example:** Lancer `300 + 30 + 600 = 930` → parked 32.3%; Leech `360 + 30 + 540 = 930` → latched 38.7%. Dock time depends on the plane's distance to the slot (10 px/tick, cap 45): a drone parked 200 px from its slot docks on return tick 20.

> Formulas proposed by game-designer; numbers by auto-approve (2026-11-03). The landing factors `eta` and the 30-tick return are **assumptions**; the playtest log must replace them (Open Question 4).

## Edge Cases

**Fire and charge**

- **If Fire is released on tick 17 or 18** (`held = false` on that tick), no charge attempt is made; the shot lingers 12 ticks. **If it is released on tick 19**, the attempt was made on tick 18 (held): a Lancer with meter 400 had exactly one laser tick on tick 18, then the laser ends because Fire is up (13 ticks of invulnerability from that one tick).
- **If the Lancer meter is 399 at `h = 18`**, the press is HOLD_PLAIN; reaching 400 later in the same hold does nothing. Release and press again.
- **If Fire is held through death and respawn**, the kit starts at the first Active tick as a fresh hold with `h = 0` (Player plane Rule 10): it fires the normal shot immediately and tries charge at `h = 18` (about 0.3 s after Active). Respawn invulnerability covers that.
- **If Fire is pressed again during linger**, `h` restarts at 0 and `shot_cd` is not reset; no extra volley.
- **If Fire and Drone are pressed on the same tick**, both are processed (shot first, then the ability); neither blocks the other.
- **If the pool refuses a volley**, those bullets are lost; no retry, and the cooldown still advances.
- **If the plane dies on the same tick `h` reaches 18**, Dying wins; the laser never starts.

**Lancer laser**

- **If the laser has no target**, it still burns meter and still holds invulnerability for the whole time. (Intentional: the laser is also a shield.)
- **If the beam's target is destroyed this tick by another source**, this tick's laser event returns *ignored* (overkill, Collision C6), and next tick's query finds the next target.
- **If the first hurtbox in the column is immune**, the beam stops there and the event is *ignored*: it deals nothing, counts nothing and gives no meter. Boss designers can use this to block the laser deliberately.
- **If the meter reaches exactly 0 on the last paid tick**, that tick still counts as active; the laser is off from the next tick.
- **If plane-shot bullets already in flight land during the laser**, they still deal damage and count for the chain but give **no meter** (Rule 20).
- **If a bomb is pressed during the laser**, the laser continues; the bomb's invulnerability request is `max`-combined with the laser's (Collision Rule 6); no meter is spent or gained.
- **If the stage clears during the laser**, the laser stops at once and the plane's ability speed ends; grace plays out; the meter is kept.
- **If the laser is active when the plane would be hit**, the hit is ignored by Collision (invulnerable). The 13-tick request means the first mortal tick is 13 ticks after the last active tick.
- **If the laser starts while a respawn invulnerability is running**, the longer wins (`max`); the laser still burns meter. (Using the laser during the 2 s of respawn invulnerability is allowed but wastes it.)

**Lancer drones**

- **If Drone is pressed with 0 drones**, nothing happens and `drone_denied(NO_DRONES)` fires.
- **If the plane is at a wall and outer drones are off-screen**, parked positions are clamped to `x` in `[8, 352]`; they slide in at 4 px/tick before firing (beams start when they arrive).
- **If a parked drone's column is empty**, its beam goes to the top and sends nothing.
- **If the parked drone is above a target (target lower on screen)**, the beam cannot reach it (beams go up only); no event.
- **If the plane dies while drones are parked**, they vanish with the plane (Player plane Rule 13); no beam events after that tick.

**Leech**

- **If Drone is pressed and every on-screen target is immune or off-screen**, the press is rejected (`NO_TARGET`) and no cooldown starts.
- **If all targets disappear during the ability**, drones SEARCH in place; the 360-tick timer runs on; they relaunch if a target appears. A wave gap longer than the timer wastes it (the cost of pressing too early).
- **If four drones all prefer the same target**, at most 2 latch it; the others take the next nearest. If it is the only eligible target, all 4 latch it (cap ignored).
- **If a latched target is a boss part that gets destroyed**, the 2 drones on it retarget the nearest eligible part or the core (armoured core still counts) the same tick.
- **If a boss core is armoured**, latch hits still count (dealt >= 1) and still refresh the chain; they just deal 5 damage at 25% armour.
- **If the target's mode turns immune**, the drone's results are *ignored* (not counted); after 30 ignored results it retargets and avoids that target for 60 ticks.
- **If a latched target moves off screen**, the drone retargets at once (bottom edge `y < 0`, or more than 40 px outside a screen edge).
- **If two Leech players are in co-op**, each slot's claims and timers are independent; they can both latch the same target.
- **If a powerup is collected at 4 drones**, `drone_count` stays 4 (Session); the kit does nothing. A POD at 4 drones is not collected if another Active plane needs it; otherwise it pays a MEDAL (Powerups 13 Rules 20, 22).

**Both**

- **If `drone_count` rises while the ability is running**, the new drone docks and fires idle bullets, and is not part of the ability (Rule 32).
- **If the stage clears while drones are deployed**, they snap to their slots at once, the ability is READY, cooldown 0 (Rule 13; closes Session Open Question 3).
- **If the plane dies while the ability is on cooldown**, cooldown is reset to 0; with 0 drones the next press is denied until a powerup arrives.
- **If the game is paused**, no ticks run: timers, cooldowns, meter and drone positions freeze.
- **If the kit sends a damage event to a stale `(id, generation)`**, Collision returns *ignored* (Collision AC-22); the kit retargets next tick (Leech) or ignores it (Lancer).
- **If the plane is Dying and a laser tick would have fired**, none is sent. Bullets already in flight still hit (Collision ghost shots; they give no chain).

**Degenerate strategies and mitigations (Sirlin)**

| Strategy | Why it appeals | Mitigation |
|---|---|---|
| **Laser spam on empty-room enemies** to farm meter | More shots = more fill | Fill is capped by the plane's own 36 bullets/s x 2 = 72/s, so duty is bounded at 22.3% (K5) however many enemies there are |
| **Laser as a permanent shield** | Invulnerable | 14-22% duty; laser speed 90 px/s; 12-tick grace means a bad exit still kills; the laser cannot be restarted until the meter refills (13.9-19.8 s) |
| **Farming meter from parked beams or drones** | Free fill | Drone, parked and laser hits give **0** meter |
| **Mashing Fire to beat the shot interval** | More dps | One shared `shot_cd` (Rule 6) |
| **Dying on purpose to clear bullets** (Collision) | Free screen clear | Costs life, 4 drones, meter, chain (unchanged; this kit adds the meter and cooldown loss) |
| **Holding Fire forever (no tapping)** | No mashing, precise | Costs the full-speed movement; Lancer laser auto-fires and spends the meter when armed, so the player must choose to tap if they want to save it |
| **Leech: always-latched** | Free chain | 360 ticks on, 540 off (+30 return); latch on armoured cores is low damage (5 per hit at 25%) |
| **Leech: latching a tiny enemy to keep the chain** | Sustained hits | Kills quickly then jumps; the 53-tick maximum jump keeps the chain alive, but the player still has to *reach* the next wave |
| **Saving the Lancer meter for the Critical Break only** | Big payoff | Allowed and intended: the meter is a decision, not a leak (it never decays) |

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | `drone_count` (0-4), slot state, `stage_started`/`stage_cleared`; the kit never writes `drone_count`. |
| Input and player mapping (2) — [GDD](input-and-player-mapping.md) | Hard | Per-slot Fire, Drone actions (via the Player plane). `pN_ability` renamed `pN_drone` (final). |
| Bullet manager (3) — GDD | Hard | Player-pool `request_spawn` with `tag`; refusals; `first_in_column` and `nearest` hurtbox queries (**amendment**). |
| Player plane (5) — GDD | Hard | Buttons, position/state, `wing_slot(i)`, `set_ability`, `plane_died`. |
| Collision, damage and lives (6) — GDD | Hard | Damage events, `request_invuln`, hit results with `tag`, `laser_exit_grace`, `armour_damage_min`. |
| Chain tracker (7) — GDD | Soft | No direct calls. `chain_window` (60) and `chain_cap` (999) are read for design constraints (K9, K11) and tests. |
| Enemy and AI (10), Boss (14) — GDDs exist | Hard | Hurtbox registry data: ids, bottom edge, mode (normal / armoured / immune), `latchable`. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Collision (6) — GDD | Hard | Receives damage events and invulnerability requests. |
| Bullet manager (3) — GDD | Hard | Receives player-pool bullet requests. |
| Powerups and drops (13) — GDD exists | Soft | Gives drones through Session; reads `drone_lamp` for no one. Meter/cooldown are not refillable by pickups. |
| Bombs (12) — GDD exists | Soft | No kit state read; bombs are independent of `drone_count` and drone positions (Bombs 12). The Rule 40 snapshot remains for Critical Break (17). |
| Critical Break (17) — [GDD](critical-break.md) | Hard | Reads `charge_active`, `charge_kind`, `charge_last_hit`. |
| Sentry, Breaker kits (29) — [GDD](plane-kits-sentry-breaker.md) | Hard (Target) | Inherit Rules 1-15 (Fire state machine, tap/hold, drone return, hit-rate caps, charge contract) and the shared `DroneBank`; `ref_dps` stays 800 (owned here). *(2026-11-03, wave 4)* |
| Tutorial (30) — [GDD](tutorial.md) | Soft | Listens to `charge_last_hit` and `drone_ability_started` for the hold and drones drills. *(2026-11-03, wave 4)* |
| Touch controls (31) — [GDD](touch-controls.md) | Soft | Touch auto-fire relies on the Rule 5 linger; the kit publishes `drone_state(slot)` for the touch Drone button (Rule 40). *(2026-11-03, wave 4)* |
| Co-op and Team Chain (18) — GDD | Soft | Per-slot kits; the player-pool share. Team chain reads `on_boss` hits that kits cause. |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | Soft | `EraKitSkin` per era (incl. `drone_sprites`). |
| HUD (20) — [GDD](hud.md); Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | Soft | Meter/lamp data and events. |
| Menus, title and plane select (22) — [GDD](menus-title-plane-select.md) | Soft | Plane-card text keys `plane.<id>.*` (UI Requirements). |
| Boss power budget (15) — GDD exists; Wave director (16) — [GDD](wave-and-stage-director.md) | Soft | Read the K8 reference dps and the laser duty constraint (below). |

**Design constraints handed to Boss (14), Boss power budget (15), Wave director (16):**

- **Un-skippable dodge segments:** the Lancer laser can cover at most **3.33 s + 0.2 s** of a curtain once per about 14-20 s. Any phase that must be survived by movement should be longer than **4 s** for it to stay a real test.
- **Hit-free gaps:** keep Chain's `G <= 45` ticks; Leech's maximum jump is 53 ticks (flight) but the plane's own shots usually keep the chain alive.
- **Hp reference:** K8 "Reference DPS for content budgets": `ref_dps` **800** (2 drones; about 1,100 at 4 drones, 580 at 0). *(2026-11-03, wave 4:)* Target kits at 2 drones: Sentry 804.0, Breaker 777.2 (both inside ±10 % of 800; `plane-kits-sentry-breaker.md`); `ref_dps` is not recomputed from them.
- **Immune parts block beams** and cannot be latched; use them deliberately.

**Amendments to other docs** (exact edits; the main session applies them)

1. **`design/gdd/systems-index.md`**, row 11: replace the Depends-on cell `5, 6, 7, 13` with `1, 3, 5, 6, 7` (Powerups gives drones only through Session; the 11 <-> 13 cycle is cut) and the Status cell with `**Designed** (pending review) — [GDD](plane-kits-lancer-leech.md) — **bottleneck, high risk**`. Row 13 (Powerups) keeps `11` as a dependency.
2. **`design/gdd/bullet-manager.md`**: (a) Rule 2 and the request signature: add a per-bullet `tag` (0 = plane shot, 1 = drone bullet; 1 byte) stored with the player bullet and returned in the hit report `(target, shooter slot, damage, tag)`; (b) add read-only hurtbox queries `first_in_column(x, half_width, y_from)` and `nearest(pos, filter)` (kit use, start-of-tick registry, lowest id on ties); (c) Open Question 5: streak hit radius 3.0 and diamond 4.0 are confirmed for kits; (d) Dependencies row for Plane kits: "player shot and drone bullet requests with `tag`, hurtbox queries".
3. **`design/gdd/collision-damage-lives.md`**: (a) Rule 10 / Interactions: hit results returned to the source include `tag`; the kit also receives results for LASER and DRONE sources; (b) Open Question 3 closed: laser 60 damage / 20 hits/s, parked 40 / 7.5 per drone, latch 20 / 12 per drone, shot 20, all >= `armour_damage_min`; laser meter vs grace resolved (K5: duty 20.5-22.3% perfect, 15-17% competent); (c) add `blink_remaining(slot)` (the longest *non-laser* invulnerability request) so the Player plane's blink (Player plane V7) ignores laser invulnerability; (d) AC-33 data lint is no longer blocked for Kits (damage values: 20, 30, 40, 60).
4. **`design/gdd/player-plane.md`**: (a) Open Question 4 closed: Lancer `ability_speed` = **90** px/s, Leech has none (focus_speed 105 applies); (b) V7 invulnerability blink: blink only while `blink_remaining > 0` (Amendment 3c), never for the laser; the laser cue is the beam + nose glow + 12-tick afterglow; (c) Rule 9: note that the kit counts its own held ticks from `pressed`; (d) Rule 4: add that the plane applies `focus_speed` while Fire is down, including during a tap, and not during linger; (e) add `stage_cleared` to the Plane → Kit signals.
5. **`design/gdd/game-events-and-session.md`**: Open Question 3 closed: deployed drones **snap home at `stage_cleared`**; **cooldown resets to 0 on death and at stage clear**; `drone_count` carries unchanged.
6. **`design/gdd/game-concept.md`** §5: replace "Open: does Lancer's drone deploy also need/use the laser meter..." with "Decided: Lancer's drone ability uses its own cooldown only (600 ticks); the meter belongs to the laser. A powerup at 4 drones is owned by Powerups (13)."; add to Shared rules: "Fire: a press fires the normal shot (auto-repeat while held); holding 0.3 s switches to the plane's charge mode."
7. **`design/gdd/scoring.md`** F7 assumptions (hit counts) — see Open Question 1.
8. **`design/art/art-bible.md`**: §5.6 Lancer drone row (None) → lens-pod 8x12 (already in Player plane Open Question 2); §7.2 kit meter: add a 2x4 px notch at 40% (the laser minimum); add the Lancer beam (14 px) and parked beam (6 px) sprite sets and the Leech tether (a stretched 1 px sprite, not `draw_line`) to §8.3.
9. **`design/gdd/coop-and-team-chain.md`**: no change needed (Rule 8 no friendly fire and Rule 11 share already cover kit bullets); add Plane kits (11) to the Rule 11 note: kits never exceed 48 live bullets/slot.

**Bidirectional check:** Session, Bullet manager, Player plane, Collision, Co-op and Chain tracker already mention this system. Undesigned downstream systems (10, 12, 13, 14, 15, 16, 17, 19, 20, 24, 25) must list it when written. *(2026-11-03, wave 3b: all downstream systems except Sentry/Breaker kits (29), Tutorial (30) and Touch (31) now have GDDs.)* *(Wave 4: 29, 30, 31 now have GDDs and rows above.)*

## Tuning Knobs

All values live in `data/kits/lancer_kit.tres`, `data/kits/leech_kit.tres` and `data/kits/skins/*.tres`; none is hardcoded. Categories: **F** feel, **C** curve, **G** gate.

**Shared**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `charge_hold_ticks` (F) | 18 | 12-30 | Charge triggers by accident while tapping | Charge feels laggy; lost shot time | `shot_linger_ticks`, tap speed |
| `shot_linger_ticks` (F) | 12 | 6-24 | Must tap faster than 3/s | Taps feel sticky; hard to stop | `charge_hold_ticks` |
| `player_bullet_speed` (F) | 900 px/s | 700-1200 | Bullets lag behind the boss | Pool lifetime short; harder to read | Bullet manager cap 1,200; K10 |
| `drone_interval` (C) | 8 ticks | 6-12 | Drones double the plane (power creep) | Drones feel pointless | K8, K9, K10 |
| `drone_damage` (C) | 20 | >= 20 | Fails armour rule (lint) | Drones outweigh the plane | Collision C4 |
| `return_speed` (F) | 10 px/tick | 6-14 | Drones lag back; long return | Instant, no flight read | cycle K12 |
| `return_cap` (G) | 45 ticks | 20-90 | Drones snap visibly | Drones stranded off-screen | K12 |
| `target_min_edge` (G) | y >= 0 | 0 / -8 | — | Targets off-screen get lasered | Enemy spawn rules |

**Lancer**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `shot_interval` (C) | 5 | 4-7 | — | Weak vs laser; tap feels slow | K8, K9 |
| `shot_damage` (C) | 20 | >= 20 | Fails armour lint | Skips Boss tuning | Boss hp |
| `fan_deg` (F) | 9 | 6-14 | Not "wide" | Misses small targets | K2 |
| `meter_max` (C) | 1000 | 600-1500 | Laser too short | Laser too long | `laser_burn` |
| `laser_min_meter` (G) | 400 | 250-600 | Flicker lasers, 50-tick minimum | Laser unreachable | `laser_burn` (min active ticks) |
| `laser_burn` (C) | 5 /tick | 4-8 | Laser > 4 s (dominance) | Laser < 2 s (useless) | K3, K5 |
| `fill_per_hit` (C) | 2 | 1-3 | Laser rare (> 27 s) | Duty > 25% (dominance) | K4, K5 |
| `laser_tick_interval` (C) | 3 | 2-5 | Hit rate too high (K9) | Laser feels like a stream | K9 |
| `laser_damage` (C) | 60 | 40-90 | Laser worse than normal | Boss melts | K8, Boss hp |
| `laser_width` (F) | 14 | 10-18 | Hard to aim | Too forgiving | Boss part widths |
| `ability_speed` (F) | 90 px/s | 60-120 (<= move_speed) | Laser exit too hard | Too safe | Player plane PF1 |
| `park_ticks` (C) | 300 | 180-480 | Parked lasers brief | Dominates boss fights | Cycle K12 |
| `drone_cooldown` (G) | 600 | 420-900 | Parked lasers near-permanent | Rarely used | K12 |
| `parked_damage` (C) | 40 | 20-60 | Not worth parking | Parks beat the laser | K8 |
| `meter_death_keep` (C) | 0 | 0-500 | — | Death costs less than intended | Lives, Critical Break |

**Leech**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `normal_interval` / `damage` (C) | 5 / 20 | 4-7 / >= 20 | — | Normal beats focus | K8 |
| `focus_interval` / `damage` (C) | 6 / 30 | 4-8 / 24-40 | Focus worse than tap | Leech outclasses Lancer | K8 (ratio +/-10%) |
| `latch_ticks` (C) | 360 | 240-540 | Hardly worth pressing | Always latched | Cooldown |
| `drone_cooldown` (G) | 540 | 360-780 | Chain trivial (latched 50%+) | Ability forgotten | K12 |
| `latch_interval` (C) | 5 | 4-8 | Chain too fast (K9 cap) | Too weak to hold chain | K9 |
| `latch_damage` (C) | 20 | >= 20 | Fails lint | Leech kills too fast | K8 |
| `latch_speed` (F) | 14 px/tick | 10-16 | Jumps drop chain (K11) | Instant teleport read | `chain_window` |
| `latch_max_per_target` (C) | 2 | 1-4 | Drones spread thin | All on one target | Boss part count |
| `ignored_streak_limit` (G) | 30 | 15-60 | Drones fidget | Drones stuck on immune | Boss designs |

**Owned elsewhere:** `laser_exit_grace` 12 and `armour_damage_min` 20 → Collision (6) · `focus_speed` 105 and `move_speed` 210 → Player plane (5) · `max_drones` 4 → Session (1) · `player_cap` 600 → Bullet manager (3) · `chain_window` 60, `chain_cap` 999 → Chain tracker (7) · bomb damage and invulnerability → Bombs (12).

**Rationale for the defaults:** laser tick damage 60 = 3x a plane bullet; per-hit rate 20/s keeps the laser below the shot's 36/s (the laser is a damage tool, not a chain engine); 200-tick full laser with K5 duty; Lancer vs Leech within 3% (K8); max hit rate 72/s (K9).

## Visual/Audio Requirements

> Source of truth: `design/art/art-bible.md` (AB); consistent with Player plane V1-V8, Bullet manager V3/V6, Collision V2. Draw layers per AB §6.8 as in Bullet manager V6: enemies 4, air FX 5, **player shots/beams/drones 6**, planes 7, **enemy bullets 8**, hitbox dots 9, HUD 11. **Bullets always win**: beams and drones sit below enemy bullets. Never use Void Indigo or Ink for kit art; never use enemy shapes (orb, rice, needle, ring). All art is sprites (AB bans `draw_line` / `draw_circle` for lasers). Numbers marked (P) are unplaytested.

**V1. Lancer beam** (layer 6)
- Body tile 14 px wide x 16 px tall, 4 frames at 20 fps (a scroll of the bright core, no brightness strobe), vertical tile repeat to the hit point. Colours: 2 px edge `#FF7A1A`, 3 px fill `#FFB82E`, 4 px core `#FFF2B0` (the Bullet manager V3 player-shot palette). No outline.
- Muzzle flare 14x10, 2 frames at 20 fps at the nose; impact splash 16x8, 3 frames at 20 fps at the hit point (layer 5, sparks policy of Collision V2: tint and spark throttles apply to the *target*). Beam ends with a 3-tick shrink.
- **Nose lens glow** (AB §7.1, the only on-plane Lancer cue): 3x3 px Cream `#FFF2B0` at the spine tip while the laser is On. **Afterglow:** a 2x2 px Cream stays lit for the 12 grace ticks, then goes dark. It shows exactly when the plane becomes mortal. No laser blink on the plane (Amendment 3c/4b).
- The beam may not hide enemy bullets (layer 6 < 8). Overlap with enemies: the beam draws above enemies (layer 4).

**V2. Lancer drones (lens-pod 8x12, PP V6)**
- Parked drone: the lens pixel grows from 1 px to 2x2 px; the beam is 6 px wide: 1 px edge `#FF7A1A`, 1 px fill `#FFB82E`, 2 px core `#FFF2B0`, 1 px fill, 1 px edge, 3-frame muzzle at 20 fps.
- **Time-left cue:** in the last 60 ticks the lens pulses at 2 Hz (opacity 100% to 60%, 30-tick period; AB "may pulse" rule).
- Parking slide: 4 px/tick, no trail. Return: a 3 px warm streak trail (2 frames).

**V3. Leech focused shot and drones (hook-claw 10x10)**
- Normal shot: streak bullets, fill `#FFB82E`. Focused shot: same streak shape with the bright core variant (core `#FFF2B0` 2 px, thinner, 4 frames pre-rotated unnecessary because straight up); the pair is 6 px apart.
- Latch flight: a 4 px warm trail (2 frames), the claw faces its target. Latched: a 3-frame clamp animation, then a stretched 1 px P-colour **tether** sprite (not `draw_line`) from the drone (hovering 8-16 px off the target centre toward the plane) to the latch point (AB §5.6). The drone never becomes a disc under 12 px (PP V6: notched claw).
- Latched drones show 1-frame hit sparks only per Collision V2 throttles (each target 1 tint per 6 / 20 ticks; sustained fire becomes a steady 30% tint).
- Last 60 ticks: the tether flickers at 2 Hz (opacity 100% to 60%). Return trail as above.

**V4. Idle drones and shot bullets**: PP V6 (2 frames at 10 fps, 100% opacity); shot bullets: streak (plane) and diamond (drone) from Bullet manager V3 with opacity by player count (BM V3).

**V5. Era skins** (Rule 41; AB §5.5): sprite sets per era for Lancer (1941 fixed cannons, 1970s pylon tanks, 2030s spine-tip lens emitter, 2100 free lance tip) and Leech (1941 bent-wing claws, 1970s hook pylons, 2030s grapple clamps, 2100 tendril latch arms), a palette-layer beam recolour (still warm), muzzle art. At most 2 bolt-on sprites per plane per era (Player plane V8). Drone sprites per era (`drone_sprites`; MVP at most 4 drone sprites). 1941 hardware is base art; the first bolt-on set is 1970s (Era shift Rule 7) *(2026-11-03, wave 3b)*.

**A1. Audio** (audio-director to confirm (P))

| Event | Spec | Limit |
|---|---|---|
| Plane shot volley | Short tick in the bullet SFX pool | 1 per slot per 4 ticks; counted in the 8-voice pool |
| Laser start | One stinger (rising) at tick `h = 18` | 1 per slot |
| Laser loop | Low hum, pitch tied to remaining meter; ends with a 0.2 s falling tail | 1 voice per laser; at most 2 loops global (others mute) |
| Laser ready | Soft chime when meter first crosses 400 | 1 per slot per 120 ticks |
| Grace end | Tiny "click" when the afterglow goes dark | 1 per laser |
| Drone deploy | A single "pop-out" per slot (not per drone) | 1 per slot |
| Parked hum | One soft hum per slot while any drone is parked | 1 voice per slot |
| Latch clamp | Soft clamp when a drone latches | <= 2 per 6 ticks global |
| Latch tick / parked tick | None per hit (use loop) | — |
| Drone denied | Quiet blip | 1 per press |
| Dock | Tiny click | 1 per slot per 6 ticks |
| Normal hit tick | Short "tink" owned here | <= 6 per 6 ticks per slot (Collision A1 hit-feedback pool owns armour sounds) |

Voice caps: kit SFX <= 4 voices per slot, <= 8 total; all separate from the bullet pool where possible. No sound for the afterglow itself.

> Drafted from the art bible and Player plane V6-V8; direction by game-designer under auto-approve (2026-11-03). `art-director` and `audio-director` not consulted.

📌 **Asset Spec** — run `/asset-spec system:plane-kits` to produce per-sprite specs (beams, flares, drones, tether, bolt-ons per era).

## UI Requirements

The HUD (20) draws the kit's state per player slot. Data the kit supplies each tick:

| Data | Lancer | Leech |
|---|---|---|
| `kit_bar(slot) -> (num, den)` (ints; replaces `kit_bar_ratio`, HUD 20, 2026-11-03) | `(meter, meter_max)` | Ability: `(time_left, latch_ticks)` while ACTIVE, `(cooldown - cooldown_left, cooldown)` while COOLDOWN, `(1, 1)` when READY |
| `kit_ready` | `meter >= 400` | ability READY |
| `drone_lamp` | state (READY / ACTIVE / COOLDOWN / NONE when 0 drones) and ratio | not used |

- **Kit bar** (AB §7): the existing 4 px segmented bar under the lives row, Tracer Orange on Char, ticks every 25%. Lancer adds a **2x4 px notch at 40%** that turns Cream when `kit_ready` (a non-colour backup: the notch also changes from outline to solid). Leech's bar uses the same bar for the ability (no second gauge, per the AB rule).
- **Drone lamp** (Lancer only): a 5x5 px glyph on the icon row after the drone ticks (not beside the bar; HUD 20, 2026-11-03), solid Cream when READY, outline with a bottom-up fill when COOLDOWN, steady Cream with a shrinking underline when ACTIVE. Hidden at 0 drones.
- **Bar animation:** no pulses faster than 2 Hz; no HUD text (Bengali and English share the same icon-only UI). Accessibility: ready/active states are shapes (notch, lamp fill), not colour alone.
- **Plane-card text (Menus 22, 2026-11-03):** each plane's data supplies the localization keys `plane.<id>.name`, `plane.<id>.tag`, `plane.<id>.style`, `plane.<id>.fire`, `plane.<id>.hold`, `plane.<id>.drone` for the plane-select card (Lancer: "Burst and hold"; Leech: "Latch and sustain"; see `menus-title-plane-select.md`).
- **Debug tools:** overlay of Fire state, `h`, `shot_cd`, meter, laser On/Grace, drone states and positions, beam columns and the per-source hit counters; a "meter set" cheat and "drones set" cheat.

📌 **UX Flag**: run /ux-design for the per-slot plane panel (lives, drone count, kit bar, drone lamp) before writing epics.

## Acceptance Criteria

Defaults used: canvas 360x640, 60 ticks/s; `charge_hold_ticks` 18, `shot_linger_ticks` 12; Lancer interval 5, damage 20, fan 9 degrees, muzzles `(-6,-14) (0,-14) (6,-14)`; `meter_max` 1000, `laser_min_meter` 400, `laser_burn` 5, `fill_per_hit` 2, `laser_tick_interval` 3, `laser_damage` 60, `laser_width` 14, `laser_exit_grace` 12, `ability_speed` 90, `park_ticks` 300, Lancer cooldown 600, `parked_damage` 40, `parked_interval` 8; Leech normal 5 / 20 / 4 degrees, focus 6 / 30, `latch_ticks` 360, cooldown 540, `latch_interval` 5, `latch_damage` 20, `latch_speed` 14, `latch_max_per_target` 2, `ignored_streak_limit` 30; `drone_interval` 8, `return_speed` 10, `return_cap` 45; `player_bullet_speed` 900 (15 px/tick); `armour_damage_min` 20; `chain_window` 60; `chain_cap` 999; `player_cap` 600.

**Test setup:** each kit is a plain `RefCounted` class (working names `LancerKit`, `LeechKit`, base `PlaneKit`) with no nodes, no drawing, no `delta`, and no RNG. `tick()` advances one 1/60 s step. Inputs before a tick: `set_config(res)`, `set_plane(pos, state)`, `set_wing_slots([...])`, `set_buttons(fire_pressed, fire_held, fire_released, drone_pressed)`, `set_drone_count(n)`, `set_targets([{id, gen, pos, half_w, bottom_y, mode}])` through an injected stub `TargetQuery`, `deliver_hit_results([...])`, `plane_died()`, `stage_cleared()`. Outputs after a tick: `bullet_requests`, `damage_events`, `invuln_requests`, `ability(active, speed)`, `meter`, `fire_state`, `ability_state`, `drone_states/positions`, `events`, `charge_*`, `state_hash()`. Stub Collision applies C3/C4 for the integration tests. Tests: `tests/unit/test_plane_kit_fire.gd`, `test_plane_kit_lancer.gd`, `test_plane_kit_leech.gd`, `test_plane_kit_balance.gd` (`extends SceneTree`, like `tests/unit/test_chain_tracker.gd`); integration in `tests/integration/test_plane_kit_*.gd` using real `BulletField`, `PlaneCore` and `CollisionReferee`; every number read from `data/kits/*.tres`, never literals. Position asserts +/-0.01 px.

Tags: [Unit] pure logic · [Integration] real BulletField / PlaneCore / referee · [Perf] REF-PC and REF-WEB · [Manual] needs a human.

### Fire state and tap/hold (Rules 2-7, K1)

- **AC-01 [Unit] (K1, Rule 4):** **GIVEN** a Lancer with meter 0, Fire pressed on tick 0 and held to tick 40, **THEN** volleys on ticks 0, 5, 10, 15 (SHOT), the state becomes HOLD_PLAIN on tick 18, and volleys continue on 20, 25, 30, 35, 40. No laser.
- **AC-02 [Unit] (Rule 5):** Fire pressed tick 0, released tick 3 → volleys on 0, 5, 10 and none on 15 (linger covers ticks 3-14). Press tick 0, release tick 17 → linger covers 17-28: volleys 0, 5, 10, 15, 20, 25 and none on 30.
- **AC-03 [Unit] (Rule 6):** Fire pressed on every other tick for 20 ticks (10 presses) → exactly 4 volleys (ticks 0, 5, 10, 15). Press on tick 0, release, press on tick 2 → the second press does not reset `shot_cd`.
- **AC-04 [Unit] (Rules 3, 13):** presses while the plane is FlyIn, Dying or Absent → no request, no event. Fire held through a respawn → first Active tick: state SHOT, a volley fires at once, `h = 0`, charge attempt at `h = 18`.
- **AC-05 [Unit] (Rule 2):** Fire and Drone pressed on one tick → both processed; `drone_denied` or ability accepted per Rule 30; the volley still fires.

### Shot geometry and pool (Rules 8-9, 16, 26-27, K2, K7, K10)

- **AC-06 [Unit] (K2, Lancer):** a volley yields 3 requests: velocities `(0, -15)` and `(+/-2.3465, -14.8153)` (+/-0.001), muzzles `(-6,-14) (0,-14) (6,-14)`, damage 20, shape streak, owner = slot, `tag` 0. Speed of each = 15.000 +/- 0.001.
- **AC-07 [Unit] (Leech):** normal volley = 2 requests with velocities `(+/-1.0463, -14.9635)`, muzzles `(-5,-16) (5,-16)`, damage 20, tag 0. Focused volley (after `h = 18`) = 2 requests with velocity `(0, -15)`, muzzles `(-3,-16) (3,-16)`, damage 30; with normal volleys at 0, 5, 10, 15, the first focused volley is on tick 20, then 26, 32.
- **AC-08 [Unit] (Rule 9, K7):** 4 drones docked, Fire held: bullets from drone `d` on ticks `t` with `t mod 8 == 0, 2, 4, 6` for `d = 0..3`; diamond shape, damage 20, tag 1, velocity `(0, -15)`. With Fire not held and no linger: no drone bullets. A drone that is parked or latched fires no bullets.
- **AC-09 [Unit] (Rule 8):** a request refused by a stub pool (full or share) → no retry; `shot_cd` and the drone phases are unchanged on the next tick.
- **AC-10 [Integration] (K10):** real `BulletField`, 4 Lancer slots each with 4 drones, Fire held, bullets spawned at y = 620 for 600 ticks → peak `player_active <= 192`, `refused_player_share == 0`, `refused_player == 0`.

### Lancer laser (Rules 17-22, K3-K6)

- **AC-11 [Unit] (Rule 17):** meter 400, Fire held from tick 0 → on tick 18 the laser starts (`ability(true, 90)`), the plane volleys stop after tick 15. Meter 399 → HOLD_PLAIN, and raising the meter to 400 at tick 30 does not start a laser. Release and press again with 400 → laser at the new `h = 18`.
- **AC-12 [Unit] (K3):** meter 1000 → laser active exactly 200 ticks (ticks 18-217), meter 0 after the 200th active tick, laser off from tick 218 with `ability(false, _)`. Meter 400 → 80 ticks; 403 → 81 ticks.
- **AC-13 [Unit] (K6):** vs a static target at `x = plane.x`: 200 active ticks → 67 damage events of 60 on active-tick indices 0, 3, ..., 198 (4,020); 80 ticks → 27 events (1,620); source LASER; `seq` increments by 1.
- **AC-14 [Unit] (Rule 18, Collision C3):** laser active ticks 100-299 → `request_invuln(slot, 13)` on every one of them and none on 300 or later; with the stub referee, a hit report on tick 299 is ignored, on 311 ignored, on 312 counted. `laser_exit_grace` 0 → counted on 300; 30 → counted on 330.
- **AC-15 [Unit] (Rule 20):** meter fill: 5 counted plane-shot (tag 0) hits → +10; 5 drone-bullet (tag 1) hits → +0; laser tick results → +0; parked-beam results → +0; an *ignored* result → +0; 3 hits at meter 996 → 1000 (cap). With the laser active, 5 counted tag-0 results → +0.
- **AC-16 [Unit] (Rule 19):** laser with no target → 0 damage events, invulnerability request each tick, meter still burns, laser ends at 0. With the first hurtbox immune: events are sent to it (results *ignored*), the hurtbox behind it is never hit.
- **AC-17 [Unit] (Rule 15, beam width):** target at `x = 180`, half-width 10: plane `x = 196` hits (|dx| 16 < 17); `x = 197` misses. Two targets in the column: only the lower (nearer) one is hit; destroyed → next tick the beam hits the second.
- **AC-18 [Unit] (Rule 22):** `ability(true, 90)` only on the active ticks; during the 12 grace ticks `ability(false, _)`. With the Player plane: step 1.5 px/tick during the laser, 1.75 while Fire is down in grace, 3.5 otherwise (Player plane AC-02).
- **AC-19 [Integration] (Rule 19 + bombs):** a bomb request of 90 ticks during the laser → `invuln_remaining` = max(90, 13) = 90; the laser is unaffected; the meter is unchanged by the bomb.
- **AC-20 [Unit] (Rule 13):** `plane_died` during the laser → laser Off, drones removed, meter = `meter_death_keep` (0 default; set 300 → 300), no requests on later ticks. `stage_cleared` → laser Off, meter unchanged.

### Lancer drone ability (Rules 23-25, 30-32)

- **AC-21 [Unit] (Rule 23):** Lancer at (180, 500) with 3 drones → on Drone press the drones park at (148, 504), (212, 504), (134, 510); state ACTIVE; with the plane at x = 24 (slots 1 and 3 at x -8 and -22) → parked x clamped to 8 and slid at 4 px/tick (arrive after 4 and 8 ticks).
- **AC-22 [Unit] (K6, K7):** parked beams: 40 damage, source DRONE, drone `d` on ticks with `t mod 8 == (d x 8) div 4`, with no Fire pressed; beam events do not change the meter; the plane's invulnerability is not requested.
- **AC-23 [Unit] (Rule 24, 31, K12):** after 300 ticks → RECALL; the last drone docks on tick T → cooldown 600 starts on T and READY at T + 600. A drone parked 200 px from its slot docks on return tick 20; return cap snaps any drone still out on tick 45.
- **AC-24 [Unit] (Rule 30):** Drone with 0 drones → no change, `drone_denied(NO_DRONES)`; during COOLDOWN → `COOLDOWN`; during ACTIVE → `ACTIVE`; cooldown unchanged by any rejected press.
- **AC-25 [Unit] (Rule 32):** `drone_count` 2 → 3 while parked → the third drone is docked at slot 3, fires idle bullets on its phase when Fire is held, and does not park; the next ability uses all 3.

### Leech latch (Rules 28-38, K11)

- **AC-26 [Unit] (Rule 34):** 4 drones; targets T1 (nearest, 100 px), T2 (150 px), T3 (400 px) → assigned [T1, T1, T2, T2]; with only T1 eligible → [T1, T1, T1, T1] (cap ignored). With none → Drone press denied (`NO_TARGET`).
- **AC-27 [Unit] (K11):** a drone 280 px from its target (speed 14) latches on tick 20; a 734 px diagonal jump latches on tick 53 and 53 ≤ `chain_window - 1`.
- **AC-28 [Unit] (Rule 29):** 4 latched drones → damage 20, source DRONE, drone `d` on ticks with `t mod 5 == (d x 5) div 4` (0, 1, 2, 3 offsets), 12 events per drone per 60 ticks, never more than 1 kit event per tick.
- **AC-29 [Unit] (Rules 35, 38):** the target is destroyed → the 2 drones on it pick the nearest eligible target the same tick; none eligible → SEARCHING, relaunch on the tick one appears. A target that returns *ignored* 30 times in a row is dropped for 60 ticks (retarget); results *hit* reset the streak.
- **AC-30 [Unit] (Rules 31, 36, 37):** timer 360 → drones go RETURNING even mid-flight; cooldown 540 starts at the last dock; `plane_died` → 0 drones, cooldown 0; `stage_cleared` while latched → drones snap to slots, state READY, cooldown 0.

### Balance guards (K4-K5, K8-K9) — data tests, no scene

- **AC-31 [Unit] (K5):** from the `.tres`, the perfect-landing maximum laser duty = `(E + grace) / (E + R)` ≤ 0.25 for `E` from `ceil(min / burn)` to `meter_max / burn` (default max 0.2226 at E = 80, 0.2052 at E = 200). Raising `fill_per_hit` to 3 must fail this test.
- **AC-32 [Unit] (K9):** computed raw maximum hits/s per kit ≤ 72 and `T999 = 999 / hits_per_s` ≥ 12 s (default 13.9 s); damage events per tick ≤ 2 (Lancer) / 1 (Leech) over 10,000 random-input ticks.
- **AC-33 [Unit] (K8):** computed sustained effective dps: Lancer 1,128.8 ± 1, Leech 1,094.9 ± 1; ratio in [0.90, 1.10]. Every damage value in the kit data ≥ `armour_damage_min` and is an integer.
- **AC-34 [Unit] (K11):** `ceil(734.3 / latch_speed) + 1 <= chain_window - 1` for the data value.
- **AC-35 [Unit] (Rule 41):** for each `EraKitSkin` of both kits, the numeric kit data (damage, intervals, counts, angles, speeds, widths, cooldowns, durations, meter values) hash is identical; skins differ only in sprite/sound ids and muzzle offsets within ±4 px.

### Integration

- **AC-36 [Integration] (Collision order):** same tick: a bomb, a laser tick, a parked-beam tick and a bullet hit the same 30 hp target in 100 shuffled orders → the resolution order is always bomb, laser, drone, bullet (Collision AC-20); source LASER is used for the plane laser only; parked and latch use DRONE.
- **AC-37 [Integration] (chain):** laser and latch ticks each produce one `chain_hit` per *hit/destroyed* result; an armoured 25% target: laser 60 → dealt 15, shot 20 → 5, latch 20 → 5, all counted; an immune target → none counted. Shots in flight from a dead slot deal damage but send no `chain_hit` (Collision AC-30).
- **AC-38 [Integration] (Critical Break contract):** `charge_active` is true on every laser active tick (including the first tick `h = 18`) and **false** during the 12 grace ticks; Leech focused shot active → true; `charge_last_hit` returns `(target_id, tick)` of the last counted charge hit; Bomb pressed → no change to the laser or `charge_active`.
- **AC-39 [Integration] (Session):** stage clear with drones deployed → `drone_count` unchanged, drones docked, ability READY; death with drones parked → `drone_count = 0` (Session AC-14) and no kit events afterwards.

### Determinism and performance

- **AC-40 [Unit] (determinism):** a scripted 3,000-tick scenario (2 slots: Lancer, Leech; mixed targets, 1 death, 1 stage clear, bomb presses), run twice and at 60/30/144 fps adapters → `state_hash()` equal every tick.
- **AC-41 [Perf] (budget):** 4 kits (4 drones each, full activity, 64 targets) → kit pass ≤ **0.25 ms** p99 on REF-PC and REF-WEB; ≤ 7 bullet requests per slot per tick; target queries ≤ 20 per slot per tick; no allocation per tick after warm-up (memory growth < 1 MB over 10 minutes).
- **AC-42 [Unit] (data lint):** no tuning literal in `src` kit code; no `delta`, no `randf`/`randi`, no `Input.` in the core class; all kit numbers are loaded from the `.tres`.

### Manual (evidence in `production/qa/evidence/plane-kits/`)

- **AC-43 [Manual] (laser readability):** shuffled 10-s clips of laser On, Grace and Off; ≥ 5 testers identify within 0.5 s when the plane is mortal again in ≥ 90% of clips, using the nose glow/afterglow; ≥ 90% say "I can't be hit while the beam is on".
- **AC-44 [Manual] (layers):** 5 enemy bullets crossing the beam and a parked beam → bullets draw above the beam on every frame (layer 8 > 6). Beam colours are warm only (hex check) and no Ink/Void Indigo in kit sprites.
- **AC-45 [Manual] (Lancer dominance playtest):** 5 testers x 3 boss attempts → laser uptime ≤ 25% and invulnerable time (laser + grace) ≤ 30% of boss time in at least 13 of 15 runs; at least 3 testers choose to *save* the meter at least once.
- **AC-46 [Manual] (chain identity):** after 10 minutes on each plane, ≥ 8 of 10 testers describe Lancer as "burst / invulnerable / parked lasers" and Leech as "latch / sustained" without being told; chain peaks per boss differ in shape (Lancer variance higher than Leech) in telemetry.
- **AC-47 [Manual] (tap feel):** 10 testers play 2 minutes tapping; ≥ 8 report the tap-linger as comfortable (not "sticky") and no one reports needing to mash faster than 4 taps/s.
- **AC-48 [Manual] (HUD):** the 40% notch turns solid at meter 400 in a 1x capture; the drone lamp states are distinguishable in greyscale.

> Criteria drafted by game-designer (qa-lead not consulted, auto-approve). Manual pass bars are proposals.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Scoring F7 assumptions exceed kit capability.** F7 assumes competent boss hits 5,150 and expert 7,500 in 60 s (86 and 125 hits/s); the kit raw maximum is 72/s (landed ~43-60/s), i.e. at most 4,320 boss hits per minute. Either re-baseline F7 (competent about 2,700, expert about 3,600 hits per boss, and wave hits similarly) with `extend_unit` re-checked, or raise kit rates about 1.6x (plane interval 3, drone interval 5, which pushes `T999_min` to about 8 s). Recommended: re-baseline F7. **Closed 2026-11-03:** Scoring F7 re-baselined to boss hits 2,700 competent / 3,600 expert (45 / 60 hits/s), waves 6,300 / 9,600; `extend_unit` unchanged, `peak_value` 1,300. | Scoring (8) + this GDD | Done |
| 2 | ~~Is the 12-tick tap linger plus the auto-hold fire comfortable, or should an "auto-tap" accessibility option exist for players who cannot tap?~~ **Closed 2026-11-03:** no auto-tap option; Tap Assist and the Fire toggle suffice (accessibility-options.md) | Playtest, Accessibility (28) | Vertical Slice |
| 3 | Should a hold with an armed Lancer meter always start the laser, or should an "Fire + Drone" or double-tap start it instead? Auto-start can waste meter when the player only wanted to focus. | Playtest | First playtest |
| 4 | Replace the assumed landing factors (`eta` 0.70 / 0.60 / 0.80 / 0.90 / 0.95 / 0.85) and return time 30 with telemetry; re-check K5 and K8 (laser duty target 15-22%, kit ratio +/-10%). | analytics, balance | First playtest |
| 5 | Early recall of drones by a second Drone press: allowed? Default is no (ignored). *Note 2026-11-03 (wave 4):* Sentry only allows early recall after 60 ticks (Sentry/Breaker GDD); Lancer and Leech keep "no". | Playtest | Vertical Slice |
| 6 | Bullet manager `tag` field and hurtbox queries (`first_in_column`, `nearest`): ownership and cost; hit results carrying `tag` through Collision. May need an ADR if hurtbox storage changes. | Bullet manager (3), Collision (6), lead-programmer | Before the kit epic |
| 7 | ~~Plane-specific bombs and what a kit snapshot must expose to them (Rule 40): e.g. does a Lancer bomb use parked drones?~~ **Closed 2026-11-03:** Bombs read no kit state; they do not use parked drones or drone positions, so Rule 40's snapshot is not needed by Bombs. Lancer's bomb and Leech's bomb hooks are independent of `drone_count`. Rule 40 remains for Critical Break (17) (bombs.md). | Bombs (12) | Bombs GDD |
| 8 | ~~Critical Break: required conditions on `charge_active`/`charge_last_hit` (must the beam be on the core?) and whether Leech's always-available focus makes its break too easy relative to Lancer's meter.~~ **Closed 2026-11-03:** charge run >= 12 ticks, last charge hit on the core within 12 ticks, the same test for both kits; HOLD_PLAIN and drones are not charge (critical-break.md F1). Leech parity risk moved to CB Open Question 1. | Critical Break (17) | CB GDD |
| 9 | Boss hp and mode design vs the K8 reference dps; whether any boss part is `latchable = false`; immune shields as beam blockers; the "> 4 s un-skippable dodge" constraint. | Boss (14), Boss power budget (15) | Boss GDD |
| 10 | Godot 4.7: vertical tiled sprites for beams (texture repeat on `Sprite2D`/`TextureRect` with region) and per-frame cost of 8 beams in 4P; unverified for 4.7. | godot-specialist | Before VFX epic |
| 11 | ~~Audio caps (2 laser loops, 4 voices per slot) and the "ready" chime.~~ **Closed 2026-11-03:** KIT pool 8, laser loops capped at 2 globally (BOMB hums separate) (audio.md) | audio-director | Audio pass |
| 12 | Art: art bible amendments (40% notch, beam sets, tether sprite, Lancer drone row). | art-director | Before plane art |
| 13 | Leech needs an in-world cue for "target immune" so the player understands a rejected press (`NO_TARGET`)? | UX designer | HUD spec |
| 14 | ~~Era: confirm "visuals only" for the evolution (concept §3 says look/shot/ability visuals/power). Numbers would need an anti-pillar review.~~ **Closed 2026-11-03:** visual only; all kit and bomb numbers are hash-identical across eras (era-shift-and-plane-evolution.md); creative-director sign-off still flagged there | Creative director | Era shift GDD |
| 15 | ~~Sentry and Breaker (29) reuse the same drone state machine (park / latch / return); confirm the base class split (`PlaneKit`, `DroneBank`).~~ **Closed 2026-11-03:** shared `DroneBank` (Sentry/Breaker GDD) | Lead-programmer | Target tier |
