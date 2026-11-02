# Collision, Damage and Lives

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — lean mode
> **Author**: user + Claude
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (every death is the player's fault), Every Hit Counts (which hits count)

## Overview

Collision, Damage and Lives is **the referee**: it takes every contact the game reports and decides what it means.

**What it owns:**

- **Player hits.** A bullet hit (reported by the Bullet Manager) or **contact with any enemy body** (tested here — small fighters, big ships, boss parts and cores) costs that player **a life**. The player's plane enters Dying, their **drones are lost**, their **chain drops to 0**, and **every enemy bullet on screen is cleared** (no score items).
- **Invulnerability.** One timer per player. Respawn, bombs and the Lancer laser *request* time on it; this system alone answers "can this player be hit right now?"
- **Damage to enemies.** Player bullets, lasers, drones and bombs report hits here. This system applies damage to enemy / part / core health, applies armour and immunity, and returns the result: **ignored, hit or destroyed**.
- **Which hits count.** A hit that does damage (or is armoured) counts for the chain; an immune target's hit is ignored and **doesn't count**.

**The player impact:** this is where *"every death is the player's fault"* (Readable Chaos) and *"every hit counts"* become rules. Death is clear and consistent — one touch, one life, clean screen. Damage is honest — every armoured or immune target says so, and the chain only rewards hits that really landed.

> Notes: (1) the screen clear needs a new Bullet Manager request, "clear enemy pool, no score items" (its existing clear-all also removes player shots). (2) "All bodies kill" means every enemy and boss part needs a **body shape** in addition to its hurtbox; body-vs-player tests live here, not in the Bullet Manager.

## Player Fantasy

**Both: the player feels every hit and every death directly; the referee rules underneath keep them consistent.**

The anchor moment: **a rice bullet clips the core — the plane bursts, the drones scatter, and every blue bullet on screen vanishes at once.** One beat of silence on a clean field, then the plane flies back in from below. The player knows exactly what killed them and is already planning the next attempt.

- **Fair death.** One touch, one life, every time. Bullets and enemy bodies follow the same rule, and only the visible core can be hit. No hidden hitboxes, no damage over time. The player always knows *why* they died.
- **Clean restart.** A death wipes every enemy bullet from the screen. It costs a life, the drones and the chain, but never punishes twice: the player comes back to a clear field, not into the curtain that just killed them.
- **Earned damage.** Hits that count look and sound like they count. Armoured cores visibly shrug off most of the damage; immune targets clearly reject it. The chain only climbs on hits that really landed, so the counter is an honest record of skill.

It serves **Readable Chaos** (*"every death is the player's fault"*) and **Every Hit Counts** (*"the chain is the game"*): this system decides which hits count, and that decision must never feel arbitrary.

> `creative-director` not consulted for this section (lean mode).

## Detailed Design

### Core Rules

**Player hits**

1. A player is hit when **either**:
   - the Bullet Manager reports an enemy bullet hit `(slot)`, or
   - this system finds the player's hitbox (radius 3.0) overlapping **any lethal enemy body** (small enemy, large ship, boss part or boss core). Bodies carry `lethal` (bool, default true); ground targets publish `lethal = false` (Enemy (10); amended 2026-11-03).

   Body tests run every tick, after the Bullet Manager's hit pass, using the same swept rule and the Player Plane's registered positions (PF7).
2. A hit only counts if the slot is **hittable**: the plane is Active and `invuln_remaining = 0`. Otherwise it is ignored.
3. **On a counted hit**, in this order, on the same tick:
   1. session `lives −= 1`
   2. session `drone_count = 0`
   3. the player's chain drops to 0 (Chain 7)
   4. the plane enters Dying (Player plane 5)
   5. the Bullet Manager **clears the enemy pool with no score items** (whole screen)
   6. `player_died(slot)` is announced
4. **One hit per player per tick.** Multiple bullets/bodies touching on the same tick still cost one life.
5. If two players are hit on the same tick, each loses a life; the screen clear happens once.

**Invulnerability**

6. Each slot has one timer, `invuln_remaining`. Respawn, Bombs (12) and the Lancer laser (11) **request** a duration; the timer becomes `max(remaining, requested)` — requests never add up.
7. The respawn request (`respawn_invuln`) is applied when the plane becomes **Active** after fly-in, not at death.
8. Laser invulnerability is a **hold** request: at least 1 tick while the laser is active, plus a short `laser_exit_grace` when it ends.
8a. *(added 2026-11-03, Plane kits 11 / Bombs 12)* Collision also keeps `blink_remaining(slot)`: the longest remaining **non-laser** invulnerability request (respawn, bomb). Player plane V7 blinks only while `blink_remaining > 0`, so the laser never makes the plane blink while a bomb or respawn request still does.
9. While invulnerable, bullet hits and body contacts are ignored; the player passes through bodies (no pushing).

**Damage to enemies**

10. Hits on enemies arrive as `(target, shooter slot, damage, source, counts_chain)`; source is bullet, laser tick, drone tick or bomb. Bullet hits come from the Bullet Manager; laser and drone ticks from Plane kits (11) at a fixed rate; bomb damage from Bombs (12). `counts_chain` defaults to true; source BOMB always sends `false` (Bombs 12 Rule 9). Hit results returned to a source carry the bullet/source `tag` (0 plane shot, 1 drone, 2 charge shot/slug, 3 return bolt; Plane kits 11 and 29) and the target class (`kill_class`; Bombs 12 needs it to emit `bomb_landed`).
11. Each target has `hp` and a **damage mode**: **normal** (full damage), **armoured** (× `armor_pct`/100; e.g. a boss core while parts live at `core_armor_pct` 25, or a critical core at `critical_armor_pct` 20 — values owned by Boss 14), or **immune** (0 damage).
12. The result returned to the source: **ignored** (immune, or target already dead), **hit** (damage applied, hp > 0), **destroyed** (hp ≤ 0 on this hit). Each result also carries `hp_after` (the target's hp after this hit), used by Enemy (10).
13. **Chain counting:** every *hit* or *destroyed* result counts as one hit for the shooter's chain — including each laser/drone tick and armoured hits. *Ignored* never counts. Bomb damage never counts for the chain (Bombs 12 Rule 9).
14. A target is destroyed **once**: the first hit that takes hp to ≤ 0 gets *destroyed* and the kill credit; later hits that tick are *ignored*.
15. **Drill mode** *(2026-11-03, wave 4, Tutorial (30))*: while Session `run_kind == DRILL`, a counted player hit raises `drill_hit(slot)`, calls `request_invuln(slot, respawn_invuln)` and drops the chain with reason DEATH; it never removes a life, never kills the plane and never runs the death clear. Damage to enemies is unchanged.

### States and Transitions (per slot)

| State | Hittable | → Next |
|---|---|---|
| Not in play (plane Absent, FlyIn or Dying) | no | Invulnerable (plane becomes Active; respawn request applied) / Vulnerable (Active with no request) |
| Invulnerable (`invuln_remaining > 0`) | no | Vulnerable (timer reaches 0) |
| Vulnerable | yes | Not in play (counted hit) / Invulnerable (bomb or laser request) |

Enemy targets: Alive (normal / armoured / immune) → Destroyed. The mode can change while alive (e.g. a core goes armoured → normal when its parts die — Boss 14).

### Interactions with Other Systems

| System | Gives to collision | Gets from collision |
|---|---|---|
| Game events and session (1) — GDD | Slot states | `lives −1`, `drone_count = 0`, `player_died(slot)` |
| Bullet manager (3) — GDD | Player hits `(slot)`; enemy hits `(target, shooter, damage)` | Hittable flag per slot; **"clear enemy pool, no items"** request (new — amends the Bullet Manager GDD) |
| Player plane (5) — GDD | Position, previous position, state | Invulnerable flag; "lethal hit → Dying" |
| Chain tracker (7) — GDD | — | `chain_hit(slot, on_boss)`, `chain_drop(slot)` |
| Enemy (10), Boss (14) | Body shapes, hp, damage mode, `armor_pct`, `kill_class`, `on_boss`, `lethal`; Boss republishes the core's hp/mode/`armor_pct` between ticks under the same id (two-stage core) | Hit results; "destroyed" |
| Plane kits (11) | Laser and drone damage ticks; laser invulnerability hold | Hit results (with `tag`); `blink_remaining(slot)` |
| Bombs (12) | Bomb damage (`counts_chain = false`); bomb invulnerability request | Hit results (with target class) |
| Scoring (8) — GDD | — | `kill_credit(slot, class)` on "destroyed"; class ∈ SMALL, MEDIUM, LARGE, PART, CORE (from Enemy 10 / Boss 14; added 2026-11-03, Scoring GDD) |
| HUD (20), VFX (25), Audio (24) | — | `player_died`, hit results (armour / immune feedback); event `hit_feedback(target_id, result, pos, tick)` for VFX *(2026-11-03, wave 3b)* |

All listed systems now have GDDs *(2026-11-03, wave 3b)*; the contracts above match them. *Target-tier note (Accessibility 28):* the assists `access.auto_bomb` and `access.deathbomb_grace` need a `will_die(slot)` pre-hit callback from Collision; it is not part of the MVP and will be specified when those assists are scheduled.

> Specialist agents not consulted for this section (lean mode).

## Formulas

All time is integer ticks (60/s). Distance tests compare squared distances. The logic is a plain class with no nodes, so the same inputs always give the same state. Targets are referenced by `(id, generation)`, so a recycled enemy slot never receives hits meant for the old enemy.

**C1. Body contact (swept capsule)**

Every enemy body is a **capsule**: a segment `a→b` with radius `r_e`. A circle is a capsule with `a = b`. Small fighters, boss parts and cores are circles. Big ships and wide boss arms are capsules along their spine. Enemy (10) and Boss (14) publish `a`, `b`, `r_e` and the origin's previous and current positions `p_e(T)`, `p_e(T+1)` every tick. Rotation within a tick is ignored; the shape at T+1 is used.

`q0 = p_pl(T) − (p_e(T) − p_e(T+1))`, `q1 = p_pl(T+1)`
`contact = segdist²(q0→q1, a→b) ≤ (r_pl + r_e)²`

`segdist²` is 0 when the two segments cross; otherwise it is the smallest of the four endpoint-to-segment distances. When `a = b` this is exactly the registered `swept_hit`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Player positions | p_pl(T), p_pl(T+1) | vec2 | play area | Registered previous and current positions (PF7) |
| Enemy origin | p_e(T), p_e(T+1) | vec2 | play area ± margin | Before and after the enemy's move. On the enemy's spawn tick `p_e(T) = p_e(T+1)` (no sweep across the spawn). |
| Capsule ends | a, b | vec2 | world | Spine endpoints at T+1 |
| Player radius | r_pl | float | 2.0–3.0 | `player_hitbox_radius` (3.0) |
| Body radius | r_e | float | 2–40 | Set by Enemy/Boss; boss parts and cores up to 26 px (Boss 14) |

**Output:** bool. A slot is tested only if it is hittable (C2).
**Example:** big ship, `r_e = 10`, spine (80,491)→(120,491), moved +1 px down. Player moves (100,500)→(100,496.5), so q0 = (100,501). Segment distance 5.5, d² = 30.25 ≤ 169 → **contact**. At x = 135: nearest point is b, d² = 225 + 30.25 = 255.25 > 169 → **no contact**.

**C2. Hittable and tick order**

`hittable[s] = (plane_state[s] == Active) AND (invuln_remaining[s] == 0)`

A snapshot taken once per slot at the start of the collision pass; bullet reports and body tests in that tick both use it. Order inside a tick:

1. Invulnerability requests are applied.
2. Bullet Manager hit pass (BM step 5). Its cancels already ran, so a cancelled bullet never hits.
3. **Phase A:** damage to enemies (C4, C6).
4. **Phase B:** player hits — bullet reports, then body tests, slots ascending. A target destroyed in Phase A is not body-tested, so a killing shot saves you from that body.
5. `invuln_remaining = max(0, invuln_remaining − 1)`.

**Output:** bool per slot. **Example:** a plane is Active with `invuln_remaining = 1` at tick T, so it is not hittable at T. The timer reaches 0 at the end of T, so it is hittable at T+1.

**C3. Invulnerability timer**

`request: invuln_remaining = max(invuln_remaining, requested)`
`end of tick: invuln_remaining = max(0, invuln_remaining − 1)`

A request of N ticks made in step 1 of tick T protects ticks T to T+N−1.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Timer | invuln_remaining | int ticks | 0–240 | One per slot |
| Request | requested | int ticks | 1–240 | Never adds |
| Respawn | respawn_invuln | int ticks | 60–240 | **120 (2.0 s)**, applied on the tick the plane becomes Active |
| Laser grace | laser_exit_grace | int ticks | 0–30 | **12 (0.2 s)** |

- **Laser:** on every active tick the kit requests `1 + laser_exit_grace`. The last laser tick leaves 12 ticks of grace; no "laser ended" event is needed.
- **Bomb:** `request_invuln(slot, ticks)`; the duration is owned by Bombs (12).

**Output:** 0–240. **Example:** the plane becomes Active at tick 1000 → timer 120, ticks 1000–1119 are safe. At 1050 (timer 70) a bomb requests 90 → timer 90, safe through tick 1139. A laser request of 13 at 1050 changes nothing.

**C4. Damage resolution**

Health and damage are **integers** (damage units).

```
dealt = 0                                       if immune, target dead, or damage ≤ 0
dealt = damage                                  if normal
dealt = max(1, (damage × armor_pct) div 100)    if armoured
hp'   = max(0, hp − dealt)                      if normal
hp'   = max(1, hp − dealt)                      if armoured  (an armoured target cannot die)
result = ignored if dealt = 0; destroyed if hp' = 0; else hit
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Health | hp | int | 1–100000 | Target health |
| Damage | damage | int | 0–10000 | Before armour; set by the source (Kits 11, Bombs 12) |
| Armour | armor_pct | int | 1–99 | Authored directly as a whole percent by Boss (14): `core_armor_pct` 25, `critical_armor_pct` 20 (was `armor_mult` × 100; renamed 2026-11-03, Boss GDD), so no rounding rule is needed. |
| Mode | mode | enum | normal / armoured / immune | Set by the target owner; can change while alive |
| Dealt | dealt | int | 0–damage | Damage applied |

- **The floor of 1 on `dealt`** means an armoured hit is never lost, so it still counts for the chain.
- **The floor of 1 on `hp`** means an armoured core waits at 1 hp until it becomes normal (parts first).
- **Authoring rule:** any damage value that can hit an armoured target must be **≥ 20 units** (rounding error ≤ 5%).
- The prototype's `bomb_part_mult` is a bomb multiplier owned by Bombs (12), not armour; it is now `bomb_part_pct` 60 (whole percent, applied by Bombs before the damage event is sent; Bombs B7).

**Output:** hp' 0 to hp. **Examples:** core 3000 hp, armoured 25%, damage 40 → dealt 10, hp 2990, *hit*. Damage 3 → 75 div 100 = 0, floored to 1. Armoured core at 5 hp takes 40 → hp 1, *hit*; once its parts die it becomes normal and the next 40 → hp 0, *destroyed*. Immune → *ignored*.

**C5. Chain count**

`counts = (result == hit OR result == destroyed) AND shooter_state == Active AND counts_chain`, credited to the shooter slot, once per resolved event, sent as `chain_hit(slot, on_boss)` (`on_boss` = target is a boss part or core; used by the Chain tracker team chain). Laser ticks, drone ticks and armoured chips all count. *Ignored* never counts, including overkill after the target is already dead. Shots still in flight from a shooter who is Dying, Absent or FlyIn (or has left) still deal damage and get kill credit, but send **no** `chain_hit` — the chain stays at 0 until the new plane is Active.

**C6. Same-tick order**

Damage events are applied sorted by `(target_id, shooter_rank, source_rank, source_seq)`, all ascending:

- `shooter_rank = (slot − (tick mod 4) + 4) mod 4` — the priority slot rotates every tick.
- `source_rank`: bomb 0, laser 1, drone 2, bullet 3.
- `source_seq`: bullet slot index, or the kit's emit counter.

The first event that takes hp to 0 gets *destroyed* and the kill credit; later events on that target this tick are *ignored*. Each player takes at most one counted hit per tick. Several players hit on one tick are processed in slot order: each loses a life; the enemy pool is cleared once.

**Example:** target 30 hp at tick 600 (600 mod 4 = 0). P1 and P2 hit for 20 each. P1 first → 10 (*hit*); P2 → 0 (*destroyed*, kill credit). At tick 601 P2 would resolve first.

**C7. Lives (boundary)**

A counted hit performs Rule 3 and sends `lives_decrement(slot)` (lives − 1). The lives clamp (0 to `max_lives` = 6), game over, continues and extends belong to Session (1); this system never reads or clamps lives.

> Formulas proposed by `systems-designer`, decisions by the user (2026-11-02): armoured targets cannot die, kill credit rotates by tick, kills resolve before rams, 2.0 s / 0.2 s invulnerability.

## Edge Cases

**Player hits and death**

- **If a bomb is pressed on the same tick a bullet or body hits the player**: the bomb's invulnerability request is applied in step 1, before the hit pass, so **the player survives** (the deathbomb works on that tick only). One tick later is too late; the hit has already counted. Bombs (12) must send its request on the tick the input is read.
- **If several bullets and/or bodies touch one player on the same tick**: one life lost, one death announced (Rule 4). All those bullets are removed anyway by the clear.
- **If two or more players are hit on the same tick**: processed in slot order; each loses a life; the enemy pool is cleared **once**.
- **If a player is hit on the same tick a bomb or part-kill cancel runs**: the cancel runs first (BM step 4), so those bullets still drop score items; the death clear then removes the remaining enemy bullets with no items.
- **If a player's last life is lost**: this system still performs Rule 3 completely (including the screen clear) and sends `lives_decrement`. Game over and the continue offer belong to Session (1).
- **If a bullet hit is reported for a slot that is not hittable** (a BM bug or stale report): ignored — no life lost, no clear. A debug warning is logged.
- **If an enemy body spawns or enters the screen overlapping a player**: it **kills** (no grace, same as the BM rule for bullets). Enemy (10), Wave director (16) and Boss (14) must spawn bodies off-screen or at least `r_pl + r_e + 8` px from every active player; an acceptance criterion checks this.
- **If an enemy is destroyed in Phase A on the tick its body would touch a player**: the body is not tested; the player survives (C2).
- **If an immune target's body touches a player** (lethal bodies only): it still kills. Immunity is about damage taken; every lethal body kills (Rule 1).
- **If a player is invulnerable while overlapping a body**: they pass through. If they are still overlapping when the timer reaches 0, they are hit on the first hittable tick (the sweep only covers ticks hittable at both ends — BM edge case).

**Invulnerability**

- **If an invulnerability request arrives for a slot that is not Active** (FlyIn, Dying, Absent): it is dropped. The respawn request is applied separately when the plane becomes Active.
- **If the laser is still held when the plane would die**: it can't die while the laser is active (the laser holds invulnerability). When the meter empties, the 12-tick grace runs, then the player is hittable. After a death the kit must stop requesting; requests it does send are dropped (above).
- **If a bomb and the laser both request on the same tick**: `max` wins; nothing adds.
- **If the game is paused**: no ticks run; the timer is frozen and no hits happen.

**Damage to enemies**

- **If a hit targets an unknown or recycled `(id, generation)`**: *ignored*; no damage, no chain count.
- **If damage ≤ 0**: *ignored*; does not count.
- **If several hits land on one target in one tick and an early one kills it**: the first gets *destroyed* and the kill credit; the rest are *ignored* and don't count for the chain (overkill, C6).
- **If an armoured target would drop to ≤ 0 hp**: it stays at 1 hp and the result is *hit* (counts). It can only be destroyed after its mode becomes normal.
- **If a target's mode changes during a tick** (e.g. the last part dies in Phase A, so the core becomes normal): mode is a **snapshot at the start of the tick**; the change takes effect next tick. This tick's remaining core hits resolve as armoured.
- **If a bomb hits an immune target**: *ignored*; does not count. Bomb damage never counts for the chain anyway (`counts_chain = false`, Bombs 12 Rule 9).
- **If a player dies on the same tick they score a kill**: Phase A runs first, so the kill and the chain hit count, then the chain drops to 0 in Phase B. The kill credit and score stay.
- **If a shooter dies, or their slot leaves the game, while their shots are still flying**: the hits still damage targets and kill credit is sent (Scoring 8 ignores a slot not in play). No `chain_hit` is sent while the shooter is not Active (C5), so a dead player's chain never climbs while they are exploding.

**Timing details**

- **Death clear timing**: the clear runs at the end of the hit tick T0 and removes every enemy bullet, including those spawned earlier that tick.
- **Fire hold**: `death_fire_hold` blocks new enemy bullets on ticks T0+1 to T0+30. A second death during the hold sets it to `max(remaining, 30)` (same rule as invulnerability; never adds).
- **First hittable tick after respawn**: the tick FlyIn ends is the tick the plane becomes Active; the 120-tick timer starts on it. Active at tick 1000 → first hittable tick **1120**. Player plane's `hittable = false` on that first tick (PP AC-15) is already covered by the timer.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Slot states (Selecting, FlyIn, Dying, Absent are not hittable). Receives `lives_decrement(slot)`, `drone_count = 0`, `player_died(slot)`. Session owns the lives clamp, game over and continues. |
| Bullet manager (3) — GDD | Hard | Sends player hits `(slot)` and enemy hits `(target, shooter, damage)` after its cancel step. Receives the hittable flag per slot and the **"clear enemy pool, no items"** request. |
| Player plane (5) — GDD | Hard | Sends position, previous position (PF7) and state. Receives the invulnerable flag and "lethal hit → Dying". |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Chain tracker (7) — GDD | Hard | Receives `chain_hit(slot, on_boss)` (C5; `on_boss` true when the target is a boss part or core, flag supplied by Boss 14) and `chain_drop(slot)`. |
| Scoring (8) — GDD | Hard | Receives `kill_credit(slot, class)` on *destroyed*, class ∈ SMALL, MEDIUM, LARGE, PART, CORE (added 2026-11-03). |
| Enemy and AI (10) — GDD | Hard | Publishes bodies (capsule `a`, `b`, `r_e`, `p_e(T)`, `p_e(T+1)`), hp and mode. Receives hit results and *destroyed*. Must spawn bodies clear of players by calling Collision's `spawn_is_clear(pos, r_e)` (off-screen, or ≥ `r_pl + r_e + spawn_clearance` from every active player); Wave director (16) and Boss (14) use the same helper. Emitters spawn no enemy bullets for `death_fire_hold` ticks after a death clear (Boss 14 too); the Pattern library (9) applies this by skipping volleys (its Rule 8). Publishes `kill_class` and `lethal` per body; receives `hp_after` in hit results; ground targets are non-lethal (Enemy GDD). |
| Plane kits (11) — GDD | Hard | Sends laser/drone damage ticks (integers, ≥ 20 if they can hit armour: laser 60 every 3 ticks, parked beam 40, latch 20, shot 20) and the laser hold request `1 + laser_exit_grace`. Receives hit results carrying `tag` (0 plane shot, 1 drone). Player plane reads `blink_remaining(slot)`. |
| Sentry, Breaker kits (29) — [GDD](plane-kits-sentry-breaker.md) | Hard (Target) | Hit results carry `tag` 0-3. Breaker net ram damage uses source DRONE (rank 2); Sentry turrets are bullets (no kit damage events). No new source. |
| Tutorial (30) — [GDD](tutorial.md) | Soft | Drill mode (Rule 15): `drill_hit(slot)` instead of a life loss. |
| Bombs (12) — GDD | Hard | Sends bomb damage with `counts_chain = false` (part damage already scaled by `bomb_part_pct` 60) and `request_invuln(slot, bomb_invuln = 90)` on the input tick. Receives hit results with the target class. |
| Powerups and drops (13) | Soft | No kill credit: drops come from Enemy (10) `drop_requested(pos, killer_slot, def_id, kill_class)` for carriers (Powerups 13; amended 2026-11-03). |
| Boss and boss parts (14) — GDD | Hard | Publishes part and core bodies, hp, mode (normal / armoured / immune), `armor_pct` (`core_armor_pct` 25 / `critical_armor_pct` 20), `kill_class`, `on_boss` and `lethal`. Receives hit results. Switches the core's mode when its parts die (applies from the next tick). Republishes the core between ticks under the same id and generation (core_main → critical reserve); the published record is authoritative and later same-tick events on a destroyed target are ignored. |
| Critical Break (17) — [GDD](critical-break.md) | Soft | Reads this tick's hit results and `bomb_landed` on the boss core at step 6b (after the referee). A bomb on the core uses the normal C4 path; the break itself is Boss `critical_break_finish(slot)`, not a damage event (2026-11-03). |
| HUD (20) — [GDD](hud.md), Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | Soft | Receive `player_died` and hit results (hit / armoured / immune / destroyed) for feedback; VFX also reads `hit_feedback(target_id, result, pos, tick)`. |
| Accessibility options (28) — [GDD](accessibility-options.md) | Soft | `access.reduce_flashing` (V2); Target: `will_die(slot)` callback for `auto_bomb` / `deathbomb_grace`. |

**Amendments to existing GDDs** (decided 2026-11-02):

1. ✅ *(applied)* **Bullet manager (3):** add the request "clear enemy pool, no score items" (runs after cancels in the same tick); update the Collision row in Interactions and Dependencies; change the edge case "hurtbox disappears same tick" so that overkill hits are decided by Collision and **do not count** (C5, C6).
2. ✅ *(applied)* **Systems index:** add 6 as a dependency of Chain (7), Scoring (8) and Powerups (13).
3. ✅ *(applied, plus V7 death ring now required)* **Player plane (5):** close Open Question 7 — respawn invulnerability is 120 ticks and starts at Active.

**Bidirectional check:** Session, Bullet manager and Player plane list this system (the Bullet manager row is updated by amendment 1). The undesigned downstream systems must list this system when written. *(2026-11-03, wave 3b: all downstream systems except Sentry/Breaker kits (29), Tutorial (30) and Touch (31) now have GDDs.)* *(2026-11-03, wave 4: 29 and 30 now have GDDs and rows above; Touch (31) has no Collision interface.)*

## Tuning Knobs

**Owned by this system**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `respawn_invuln` | 120 ticks (2.0 s) | 60–240 | Under ~1 s: no time to read the cleared field; instant re-deaths feel unfair. | Over ~3 s: free ramming through waves; deaths stop mattering. | `respawn_delay` + FlyIn (0.6 s) add to total safe time; the death clear already makes respawn mostly safe — keep it low. |
| `laser_exit_grace` | 12 ticks (0.2 s) | 0–30 | 0: releasing the laser inside a curtain is instant death; the laser becomes a trap. | Over ~0.4 s: Lancer chains lasers through anything (concept §13 dominance risk). | Lancer meter (11): small meter + long grace = near-permanent invulnerability. |
| `armour_damage_min` | 20 units | 10–50 | Rounding error grows (10% at 10); tiny hits on armour all deal 1. | Damage and hp numbers get large (no gameplay effect, only bigger numbers). | Damage values in Kits (11), Bombs (12); hp scale in Enemy (10), Boss (14). |
| `spawn_clearance` | 8 px (added to `r_pl + r_e`) | 4–24 | Bodies appear next to the player with no reaction time. | Spawners lose space, especially in 4P co-op. | Wave director (16) and Boss (14) entry paths. |
| `death_fire_hold` | 30 ticks (0.5 s) | 0–60 | 0: the field refills at once; no beat of silence after a death. | Over ~1 s: deaths become a free breather; bosses feel paused. | Enemy (10) and Boss (14) emitters obey it through the Pattern library (9) (volleys skipped, timers run); `respawn_delay` and FlyIn overlap it. |
| `kill_credit_rotation` | on | on / off | Off: P1 wins every tie. | — | Scoring (8) in co-op; only same-tick ties. |

**Owned elsewhere (pointers, not duplicated)**

- `player_hitbox_radius` 3.0 → Player plane (5)
- `starting_lives` 3, `max_lives` 6, `respawn_delay` 1.0 s → Session (1)
- `armor_mult`, core/part hp → Boss (14); enemy body radius `r_e` and hp → Enemy (10)
- Bomb invulnerability duration, `bomb_part_mult` → Bombs (12); laser/drone damage per tick → Plane kits (11)

All knobs live in a designer `.tres` resource under `data/`; no code change to tune.

## Visual/Audio Requirements

> Source of truth: art bible (AB). Only events Collision creates. Death animation, FlyIn and invulnerability blink: Player plane V7/A1. Cancel items, shockwave and layers: Bullet manager V5/V6/A2. All numbers (P) until playtested.

**V1. Death screen clear** (AB §1 "bullets always win", §6.8; Readable Chaos)

- **Hit tick T0, all at once:** every enemy bullet leaves instantly, no fade (BM V6); PP V7 Dying starts; drones pop; chain HUD drops to 0.
- **Beat of silence:** after a death clear, Enemy (10) and Boss (14) emitters (run by the Pattern library 9, which skips volleys) spawn **no new enemy bullets for `death_fire_hold` = 30 ticks (0.5 s)**. Movement continues; bodies still kill.
- **Clear puffs:** 6–10, sampled from the cleared bullets' positions; 3-frame dust at 20 fps in the era Shadow role colour (desaturated, never gold/cream); layer 5; shared 150-particle pool.
- **Death ring (required):** a single 2 px ring in the dying player's colour **and** pattern, no Ink outline; grows 40 → 80 px over T0–T18, fades T18–T24; layer 5. *Amends PP V7 (ring was optional).*
- **Death clear vs bomb/cancel:**

| | Bomb/cancel (BM) | Death clear |
|---|---|---|
| Items | gold diamonds | **none** |
| Puffs | gold/cream | grey era dust |
| Shockwave | area-wide, warm | one ring, player colour |
| Sound | bright rising chime | dull falling thud, then hush |

  No items is the non-colour cue that this was a death.

**V2. Enemy hit feedback** (AB §5.10 hit tint, §3.3, §6.8 layer 5)

| Result | Sprite | Spark (layer 5, below bullets) |
|---|---|---|
| Hit (normal) | white 60% tint, 2 frames | none, or 2-frame warm chip |
| Hit (armoured) | **no tint** | 3-frame "clank": 3–4 px cream chips in the era enemy-rim colour + one 2×2 steel dot |
| Ignored (immune) | no tint | 2-frame "ping": one 5×5 cream "+", no chips |
| Destroyed | size-class explosion — Enemy (10) / Boss (14) | once per target (C6) |

- **Throttles per target:** a new tint starts at most every 6 ticks (small/medium) or every **20 ticks (3 Hz)** on large targets and boss parts (photosensitivity). Armoured/immune sparks at most 1 per 8 ticks. The clank and ping effects (`fx_clank`, `fx_ping`) are VFX tier **T1**, so they survive `access.effects_level` MINIMAL as the visual twin of the sound-only cues (VFX 25, Accessibility 28) *(2026-11-03, wave 3b)*.
- **Sustained fire:** if the target was hit in each of 3 throttle windows in a row, the flashing tint becomes a steady 30% white tint. It turns off after one full window with no hits (no strobe from lasers/drones).
- **Global caps:** ≤ 24 live hit sparks, ≤ 8 of them armoured/immune; oldest dropped first (this is the VFX SPARK class overflow rule, VFX 25). Cost doesn't depend on bullet count.
- **"Reduce flashing" option:** tint becomes a 1 px darker outline pulse, under the same throttle (≤ 3 Hz); sparks stay.
- Sparks never draw above layer 5, so they never cover enemy bullets.

**V3. Armoured core** (AB §5.8)

- Armoured hits look the same at every hp, including 1 hp.
- **Waiting-for-parts tell:** while armoured at 1 hp, the critical crack overlay (red-orange, 2 Hz value pulse) shows only through the plate seams. Boss (14) decides whether it shows at 1 hp or only below `critical_hp`.
- **Mode change:** on the tick the new mode applies, the plating falls away over 8 ticks (4 frames at 30 fps), debris on layer 5, no flash; the core then shows its bright "CORE EXPOSED" colour.

**V4. Co-op** (AB §4.4, §4.8)

- Death ring uses the player's colour **and** pattern (solid / dashed / dotted / double); debris includes N pips in the player colour (N = player number). P3 and P4 have equal luma, so pattern and pips are mandatory.
- Several deaths on one tick: each gets its own ring and explosion; the clear, puffs and clear sound play once.
- Surviving players: no tint, no dim.

**A1. Audio** (audio-director to confirm, all (P))

| Event | Spec | Limit |
|---|---|---|
| Death boom | **owned by PP A1** | — |
| Screen clear | dull downward thud, then 0.3 s hush (other SFX ducked 6 dB) | 1 per tick, even for several deaths |
| Armour clank | metallic, 3 pitch variants | 1 per 6 ticks per target; ≤ 10/s globally |
| Immune ping | soft, high, short | 1 per 12 ticks per target |
| Normal hit tick | owned by Plane kits (11) | — |
| Destroy | owned by Enemy (10) / Boss (14) | — |

- **Hit-feedback voice pool:** ≤ 4 voices (1 reserved for the clear, ≤ 2 clank, ≤ 1 ping); priority clear > clank > ping. Separate from the bullet pool (8) and plane pool (3).
- Clank and ping are the sound-only cues that a hit didn't count normally; their visual twins are `fx_clank` / `fx_ping` (T1, Accessibility Rule 30).

**Amendments flagged:** AB §5.10 hit-tint throttle; AB §5.8 crack-through-seams; PP V7 death ring required in player colour.

> Visual direction from `art-director`, reconciled with PP A1 and BM A1/A2; decisions by the user (2026-11-02), including `death_fire_hold` = 30 ticks.

## UI Requirements

This system draws no UI. It only sends events that the HUD and menus show.

| Data | Shown by | Notes |
|---|---|---|
| Lives (from `lives_decrement`) | HUD (20) | Lives pip disappears on the hit tick; value owned by Session (1). |
| Chain dropped to 0 | HUD (20) | Drops on the hit tick, no countdown; display owned by Chain (7) / HUD (20). |
| Hit results (armoured / immune) | In-world only (V2) | **No HUD text or icon** — feedback stays on the target, keeping eyes on the field (Readable Chaos). |
| Invulnerability | In-world only (PP V7 blink) | No HUD timer. |
| "Reduce flashing" toggle (V2) | Accessibility options (28), Settings | Key `access.reduce_flashing` (bool, default false), registered by Accessibility (28), stored by Save (26). |

No UX flag: this system has no screen or HUD element of its own.

## Acceptance Criteria

Defaults used: `respawn_invuln` 120, `laser_exit_grace` 12, `armour_damage_min` 20, `spawn_clearance` 8, `death_fire_hold` 30, `kill_credit_rotation` on, `r_pl` 3.0, 60 ticks/s. Slots 0-indexed. Tests read every number from `data/collision_rules.tres` (working name), `PlaneConfig` and the bullet rules resource, never literals. Position asserts ±0.01 px.

**Test setup:** the logic lives in a plain `RefCounted` class (working name `CollisionReferee`) with no nodes and no `delta`; `tick()` advances one 1/60 s step and keeps its own tick counter. Inputs before a tick: `set_slot(slot, plane_state, pos, prev_pos)`, `set_bodies([{id, gen, a, b, r_e, p_prev, p_cur, hp, mode, armor_pct, lethal, kill_class}])` (`lethal` defaults to true), `report_player_bullet_hit(slot)`, `report_damage(id, gen, shooter, damage, source, seq)`, `request_invuln(slot, ticks)`, `laser_active(slot)`, `plane_became_active(slot)`. Outputs after a tick: `invuln_remaining(slot)`, `blink_remaining(slot)`, `hittable(slot)`, `hit_results [(id, shooter, result, dealt, hp_after)]`, `events` (ordered log: `lives_decrement`, `drone_count_zero`, `chain_drop`, `lethal_hit`, `clear_enemy_pool(no_items)`, `player_died`, `chain_hit`, `kill_credit`), `fire_hold_remaining`, `warnings`, `state_hash()`; plus the query `spawn_is_clear(pos, r_e)`. Stub Session, Chain, Scoring and emitters record what they receive. A Node adapter calls `tick()` from `_physics_process` and is tested separately. Tests: `tests/unit/test_collision_referee.gd` (`extends SceneTree`, like `test_chain_tracker.gd`), `tests/integration/test_collision_bullet_field.gd`, `tests/integration/test_collision_player_plane.gd`, `tests/perf/collision_bench.tscn`; manual evidence in `production/qa/evidence/collision-damage-lives/`. Names: `test_collision_[scenario]_[result]`.

Tags: [Unit] pure logic, headless · [Integration] real `BulletField` / `PlaneCore` / scenes · [Manual] needs a human · [Perf] measured on REF-PC and REF-WEB (Bullet manager definitions).

### Player hits (Rules 1–5, C1, C2)

- **AC-01 [Unit] (Rule 1, bullet):** **GIVEN** slot 0 Active, timer 0, **WHEN** `report_player_bullet_hit(0)` and a tick runs, **THEN** exactly one `lives_decrement(0)` and one `player_died(0)`.
- **AC-02 [Unit] (Rule 1, C1 example):** **GIVEN** a big ship `r_e = 10`, spine (80,491)→(120,491), moved +1 px down, **WHEN** the player moves (100,500)→(100,496.5), **THEN** contact (d² 30.25 ≤ 169) and 1 death. Player (135,500)→(135,496.5) → no contact (d² 255.25 > 169).
- **AC-03 [Unit] (C1 boundary):** static circle `r_e = 10` at (100,491), static player: y = 504.0 (d = 13.0) is contact, y = 504.01 is not. Same for `r_e = 2` (threshold 5.0), the four diagonals, and a capsule end point.
- **AC-04 [Unit] (C1 sweep):** circle `r_e = 4`, `p_e(T) = (100,480)`, `p_e(T+1) = (100,500)`, player static at (100,496) → contact (q0 = (100,516)); player at (110,496) → none. On an enemy spawn tick (`p_e(T) = p_e(T+1)`) overlapping the player → kills (no sweep, no grace).
- **AC-05 [Unit] (C1 = `swept_hit`):** 500 seeded random circle bodies (`a = b`) and player segments → contact equals the Bullet manager `swept_hit` result in every case. Crossing capsule segments give d² = 0 even with all four endpoints > 20 px away.
- **AC-06 [Unit] (Rules 2–3, C2):** a hit for each plane state: Active + timer 0 → counted; Active + timer 1 → ignored; FlyIn, Dying, Absent, Selecting → ignored, with no life lost, no clear, no event.
- **AC-07 [Unit] (Rule 3 order):** one counted hit → `events` is exactly `lives_decrement`, `drone_count_zero`, `chain_drop`, `lethal_hit`, `clear_enemy_pool(no_items)`, `player_died`, same tick, in that order.
- **AC-08 [Unit] (Rule 4):** 5 bullet reports and 2 overlapping bodies for slot 1 on one tick → exactly one of each event for slot 1.
- **AC-09 [Unit] (Rule 5):** slots 1 and 3 hit on one tick → two `lives_decrement` (1 then 3), two `player_died`, exactly one `clear_enemy_pool`. Slots 0–3 on one tick → 4 lives lost, 1 clear.
- **AC-10 [Unit] (C2 snapshot):** timer 1 at tick T with a body overlapping → no hit at T, hit at T+1. A request in step 1 of tick T is already in that tick's hittable snapshot for bullet and body tests.

### Invulnerability (Rules 6–9, C3)

- **AC-11 [Unit] (Rule 6, C3 example):** `plane_became_active` at tick 1000 → timer 120; hits at 1000–1119 ignored, hit at **1120** counted. At 1050 (timer 70) a bomb requests 90 → timer 90, safe through 1139, hittable at 1140. A laser request of 13 at 1050 leaves 70. A bomb 90 and a laser 13 on one tick give 90 (never 103).
- **AC-12 [Unit] (Rule 7):** death, 60 ticks Dying/Absent, 36 ticks FlyIn → timer 0 throughout; becomes 120 on the tick FlyIn ends (the Active tick). `respawn_invuln` 60 / 240 give 60 / 240.
- **AC-13 [Unit] (Rule 8, laser):** `laser_active` on ticks 100–159 → timer ≥ 1 every tick, hit at 159 ignored; grace: hits ignored 160–171, counted at 172. `laser_exit_grace` 0 → counted at 160; 30 → counted at 190.
- **AC-14 [Unit] (Rule 9):** invulnerable slot overlapping a live body for 10 ticks → no event, no position change (no pushing). Timer ends at end of tick T with overlap still present → hit counted at T+1.

### Damage (Rules 10–14, C4–C6)

- **AC-15 [Unit] (Rule 10):** one event per source (bullet, laser tick, drone tick, bomb), damage 10, normal 100 hp target → four *hit* results with correct shooter and source, hp 60.
- **AC-16 [Unit] (Rule 11, C4):** armoured core 3000 hp, `armor_pct` 25: damage 40 → dealt 10, hp 2990, *hit*; 3 → 1; 20 → 5; 19 → 4. Immune, damage 500 → *ignored*, hp unchanged. Normal, 40 → 40.
- **AC-17 [Unit] (Rule 12, armour floor):** armoured core at 5 hp takes 40 → hp 1, *hit*; takes 40 again → hp 1, *hit* (never destroyed). Mode becomes normal next tick, takes 40 → hp 0, *destroyed*.
- **AC-18 [Unit] (Rule 13, C5):** slot 2 (Active): 4 *hit*, 1 *destroyed*, 1 armoured *hit*, 1 immune, 1 dead-target on separate targets → exactly 6 `chain_hit(2)`. Each laser and drone tick counts once.
- **AC-19 [Unit] (Rule 14, C6 example):** target 30 hp at tick 600, slots 0 and 1 each report 20 → slot 0 *hit* (10), slot 1 *destroyed*, one `kill_credit(1)`. At tick 601 → slot 1 *hit*, slot 0 *destroyed*. Rotation off → slot 0 resolves first on both ticks.
- **AC-20 [Unit] (C6 order):** at tick 601, a 30 hp target, events slot 0 bullet (seq 3), slot 1 laser, slot 1 bomb, slot 1 drone (10 each), submitted in 100 shuffled orders → resolve order is always slot 1 bomb → laser → drone, then slot 0 bullet. Two bullets seq 2 and 5 → seq 2 first.
- **AC-21 [Unit] (overkill):** 10 hp target, three 20-damage hits from three slots on one tick → one *destroyed*, two *ignored*, exactly one `chain_hit`. A later hit on the dead target → *ignored*.
- **AC-22 [Unit] (stale id, damage ≤ 0):** recycled `(id, generation)` or unknown id → *ignored*, no hp change, no `chain_hit`, no error. Damage 0 and −5 → *ignored*, no `chain_hit`.
- **AC-23 [Unit] (C7 boundary):** Session stub reports lives = 0, player hit → Rule 3 completes in full (including clear) and `lives_decrement` is sent; the referee never reads or clamps lives.

### Edge cases

- **AC-24 [Unit] (deathbomb):** orb hit for slot 0 on tick T plus `request_invuln(0, 90)` on T → no life lost, no clear. Request on T+1 → life lost at T.
- **AC-25 [Unit] (Phase A saves):** normal 20 hp body overlapping slot 0 plus a 20-damage hit on it, same tick → *destroyed*, body not tested, no death. Without the hit → death. Armoured 3000 hp body → death.
- **AC-26 [Unit] (immune body):** immune target's body overlapping slot 0 → player dies; target hp and mode unchanged.
- **AC-27 [Unit] (bad reports):** bullet hit reported for an Active invulnerable slot → ignored, no life lost, no clear, one `warnings` entry. `request_invuln` for FlyIn, Dying or Absent → dropped (timer stays 0, no error); the respawn request still applies at Active (AC-12).
- **AC-28 [Unit] (mode snapshot):** last part destroyed in Phase A at tick T → this tick's remaining core hits resolve armoured (hp floor 1); from T+1 normal.
- **AC-29 [Unit] (kill + death):** slot 0 scores a *destroyed* hit and is hit the same tick → `chain_hit(0)` and `kill_credit(0)` appear before `chain_drop(0)`; credit not revoked.
- **AC-30 [Unit] (ghost shots):** slot 3 Dying (and, separately, slot 3 not in play) → its bullet hits apply damage and log `kill_credit(3)` on *destroyed*, but **no** `chain_hit(3)`. When slot 3 is Active again its next hit logs `chain_hit(3)`.
- **AC-31 [Unit] (pause):** timer 70, adapter tree paused 30 s real time → timer still 70, no event; after resume it drops 1 per tick.
- **AC-32 [Unit] (determinism):** scripted 600-tick scenario (4 slots, mixed sources, 2 deaths, 1 mode change), run twice → `state_hash()` equal every tick.
- **AC-33 [Unit] (data lint):** every damage value in `data/` marked "can hit armour" is ≥ 20; every `armor_pct` is a whole percent 1–99. *Unblocked for Kits (11), Bombs (12) and Boss (14) (all GDDs written 2026-11-03: shot/drone 20, laser 60, parked 40, bomb 100/200/100, `core_armor_pct` 25, `critical_armor_pct` 20); runs once their `data/` files exist.*
- **AC-34 [Unit] (spawn_is_clear):** `r_e = 10`, player at (100,500): `spawn_is_clear((100,521.0))` → true; `(100,520.99)` → false; any off-screen position → true; with 4 players, false if any one is too close. *[Integration] follow-up when Enemy (10), Wave director (16), Boss (14) exist: every scripted spawn in a 1P and 4P run passes the helper.*
- **AC-35 [Unit] (clear and hold timing):** death at T0 → `fire_hold_remaining` blocks T0+1 to T0+30, open at T0+31. Second death at T0+20 → hold becomes max(10, 30) = 30, open at T0+51.

### Integration: Bullet manager

- **AC-36 [Integration] (hittable flag):** real `BulletField`, orb at (103,500), slot 0 Active: timer 1 → `set_targets` carries `hittable = false`, no hit; timer 0 → 1 `player_hits (0)` and a death.
- **AC-37 [Integration] (clear, no items):** 1,350 enemy and 400 player bullets, a player hit → same tick `enemy_active = 0`, `player_active = 400`, `cancel_items` empty, CLEAR counter +1,350, including bullets spawned earlier that tick. Clear-all still empties both pools (BM AC-17).
- **AC-38 [Integration] (cancel before clear):** 10 of 100 enemy bullets inside a part-kill cancel circle plus a death on the same tick → `cancel_items` has exactly 10 entries; the other 90 removed with no items.
- **AC-39 [Integration] (hits in):** a 40-damage shot on an armoured 3000 hp hurtbox → dealt 10, *hit*, one `chain_hit`. A cancel covering an orb plus a hit on slot 0 → no hit (cancel beats hit).

### Integration: Player plane

- **AC-40 [Integration] (previous position):** real `PlaneCore` (Lancer at (100,500), holding up) and the AC-02 ship → registered `prev = (100,500)`, `pos = (100,496.5)` used; dies on tick 1. At (135,500) → survives.
- **AC-41 [Integration] (Dying):** referee sends `lethal_hit` → `PlaneCore.state` is Dying that tick, sent once. A hit during FlyIn/Dying/Absent is ignored. While timer > 0, the plane registers `hittable = false` (PP AC-10).
- **AC-42 [Integration] (fire hold):** stub emitters wired to the referee, death at T0 → zero enemy bullet requests accepted for T0+1 to T0+30; accepted again at T0+31. Bodies still move and kill during the hold.

### Visual / Audio (Manual, evidence in `production/qa/evidence/collision-damage-lives/`)

- **AC-43 [Manual] (V1 clear):** recorded death with 200+ enemy bullets → all vanish on one frame, zero gold diamonds, 6–10 grey era-dust puffs, dull falling thud (not the bomb chime).
- **AC-44 [Manual] (V4 co-op ring):** P1–P4 each die in turn → a 2 px ring grows 40 → 80 px over 18 frames, gone by frame 24, in the player's colour and pattern with N pips; a grayscale screenshot tells P3 from P4. Two deaths on one tick → 2 rings, 1 clear sound.
- **AC-45 [Manual] (V2 throttle):** a boss part hit 60 times/s by a drone → in a 60 fps recording a new white tint starts at most every 20 frames (≤ 3/s); small targets at most every 6 frames.
- **AC-46 [Manual] (V2 steady tint):** laser on a boss part for 3 s → after 3 throttle windows the tint is a steady 30% white with no flicker on a frame-by-frame luma plot; it clears within one window (20 frames) after the laser stops.
- **AC-47 [Manual] (V2 layers):** armour/immune sparks overlapping 5 enemy bullets → bullets draw above sparks every frame. Armoured: no tint + clank sparks; immune: 5×5 "+" ping.
- **AC-48 [Manual] (reduce flashing):** option on → tint replaced by a 1 px darker outline pulse at ≤ 3 Hz; no white tint in a 10 s laser capture.
- **AC-49 [Manual] (beat):** frame-by-frame capture of a death → no new enemy bullet for 30 frames after the clear.
- **AC-50 [Manual] (A1 audio):** 4 simultaneous deaths → 1 clear thud, other SFX ducked 6 dB for 0.3 s. A 10 s drone burst on armour → ≤ 10 clanks/s.

### Performance

- **AC-51 [Perf] (body tests):** 4 hittable players × 64 bodies (half capsules), all overlapping → body pass ≤ 0.15 ms p99 on REF-PC and REF-WEB.
- **AC-52 [Perf] (damage):** 600 damage events per tick on 40 targets → resolution including the sort ≤ 0.30 ms p99.
- **AC-53 [Perf] (budget):** `bullet_bench.tscn` plus 256 bodies → collision pass ≤ **0.5 ms p99** (mean ≤ 0.3 ms) and BM AC-39/40/41 still pass (BM 2.5 ms + collision 0.5 ms ≤ 3.0 ms p99; 1%-low ≥ 55 fps). Memory growth < 1 MB over 10 minutes.

> Criteria drafted by `qa-lead`; 6 gaps resolved by the user (2026-11-02): `spawn_is_clear` helper, clear/hold timing, first hittable tick = Active + 120, steady-tint rules, 0.5 ms budget + whole-percent armour, ghost shots damage but don't chain.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Body radii (`r_e`) and capsule spines per enemy size class and boss part/core | Enemy (10), Boss (14) | Those GDDs |
| 2 | ~~hp scale and `armor_mult` per boss; crack-through-seams tell at 1 hp or only below `critical_hp`~~ **Closed 2026-11-03:** `core_armor_pct` 25 (replaces `armor_mult`); the crack overlay shows only in Critical (below `critical_hp`), not at 1 hp (Boss 14) | Boss (14) | Boss GDD |
| 3 | ~~Laser/drone damage per tick and tick rate (≥ 20 units if they can hit armour); Lancer meter vs `laser_exit_grace` balance~~ **Closed 2026-11-03:** laser 60 every 3 ticks (20 hits/s), parked beam 40, latch 20, shot 20; invulnerability duty 20.5–22.3 % at perfect landing, data test fails above 25 % (Plane kits 11 K5, K6, K8) | Plane kits (11) | Kits GDD + playtest |
| 4 | ~~Bomb invulnerability duration, bomb damage counting per target, `bomb_part_mult`~~ **Closed 2026-11-03:** bomb invulnerability 90 ticks; `bomb_part_pct` 60; bomb hits never count for the chain (Bombs 12) | Bombs (12) | Bombs GDD |
| 5 | ~~Does a Critical Break hit on a core use its own damage rule or the normal C4 path?~~ **Closed 2026-11-03:** the normal C4 path; the break is Boss `critical_break_finish(slot)`, not a damage event (critical-break.md). | Critical Break (17) | CB GDD |
| 6 | Playtest `respawn_invuln` 120, `laser_exit_grace` 12, `death_fire_hold` 30 and "kill first" vs ramming | Designer | First playable boss |
| 7 | ~~Audio numbers (voice pool 4, clank/ping rates, 6 dB duck)~~ **Closed 2026-11-03:** HIT pool 4, rate gates kept, `death_dip` 6 dB (audio.md) | audio-director | Audio pass |
| 8 | Art bible amendments: hit-tint throttle (§5.10), crack-through-seams (§5.8); PP V7 death ring required | art-director (`/art-bible` update) | Before enemy/boss art |
| 9 | `src/core/combat_rules.gd` and `boss_part.gd` use float hp and differ from this GDD (integer hp, capsule bodies, referee class) — **Closed for bosses 2026-11-03:** the boss-side corrections (`boss.gd`, `boss_part.gd`, definitions, `data/bosses/*.tres`) are listed in Boss (14) Open Question 12; `combat_rules.gd` stays open | Programmer | Collision epic implementation |
