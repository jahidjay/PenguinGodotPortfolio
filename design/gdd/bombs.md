# Bombs

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Four Planes, Four Games (primary: two different bombs), Every Hit Counts (the chain toll and the Critical Break), Readable Chaos (honest invulnerability, effects never hide bullets)

## Overview

**The data layer:** a **bomb** is the player's emergency button. One node-free logic class (`BombCore`, one per slot, `tick()` at 60 Hz) owns: the **bomb stock** (an integer per slot), the Bomb button handling (accept / deny / buffer), the **invulnerability request**, the **chain toll**, the **screen cancel**, and the plane-specific **bomb effect** (Lancer: a sweeping light column; Leech: four seeking hooks that clamp and burst). It does not own bullets (it *requests* cancels from the Bullet manager 3), damage resolution (Collision 6), the chain (7), score items (Powerups 13), the Critical Break trigger (17) or the plane's kit (11). All numbers are integers in ticks, px and damage units, and live in `data/bombs/*.tres`. A bomb is **stock-limited** (3 per life, topped up at each stage start), **short** (90 ticks of invulnerability, one bomb at a time per slot), **bounded in damage** (at most 1,000 per target per bomb, 60% on boss parts), and **never feeds the chain**: bomb hits do not count, and using a bomb costs half the chain count. Only one rule bends this: a bomb used while a Critical Break is armed pays no toll, because the Critical Break is what the bomb is for.

**The player impact:** the bomb is a **survival tool with a price**, and the one required ingredient of the Critical Break. When a curtain closes, the player taps Bomb: the field clears, the plane is untouchable for 1.5 s, and the chain loses half its count. At chain 12 that is nothing; at chain 600 it hurts, so the player decides *what the chain is worth*. Each plane's bomb matches its kit: **Lancer** drops a wide column of light that holds where it was cast and then sweeps both ways across the screen (wide, position-based); **Leech** sends four hooks that chase the nearest enemies, clamp for a third of a second and burst (targeted, position-free). Neither bomb gets stronger with drones, eras or score, and neither can skip a boss phase.

## Player Fantasy

**Direct: the player presses it with their thumb and feels the screen change.** MDA aesthetics: **Challenge** (when to spend it), **Fantasy** (the panic button that answers), **Expression** (spend it to live, or hold it for the Critical Break).

- **"The curtain was too thick, and I answered it."** The anchor moment: a wall closes from both sides, the thumb taps Bomb a frame early, and the screen blooms. Every bullet on the field vanishes at once, gold diamonds spill out, and the plane flickers through what is left. The player is safe for exactly as long as the flicker lasts, and *sees* it end.
- **Lancer: "I am the lighthouse."** A warm column plants itself where the plane was, burns for a beat, then splits and sweeps outward to both edges, wiping bullets and fodder as it goes.
- **Leech: "Nothing hides from the hooks."** Four claws fly out, each picks its own enemy, bites in, swells for a heartbeat, and bursts. The hooks choose the targets; the player chose the moment.
- **A price you can read.** The icon row shows how many bombs are left. The chain number visibly halves when one is spent. Nothing is hidden (Competence).
- **Spend it or save it.** Three bombs a life, one of which the Critical Break needs. Using two on the waves means no break on the boss. The player decides (Autonomy).
- **Bullets always win.** The bomb effect never draws over a surviving bullet, never flashes the screen (that belongs to the Critical Break), and never changes a bullet's shape or colour.

It serves **Four Planes, Four Games** (each bomb has its own shape and its own use), **Every Hit Counts** (the toll and the Critical Break tie the bomb to the chain) and **Readable Chaos** (the invulnerability is visible and the field it leaves is lethal and honest).

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

Units: **tick** = 1/60 s; **px** on the 360x640 canvas; **damage unit** (integer). `k` = ticks since the bomb was accepted (the accept tick is `k = 0`). `play_top` = 48 (1-2P) or 72 (3-4P).

**A. All bombs**

1. **One `BombCore` per slot.** A node-free `RefCounted` class, `tick()` once per 60 Hz tick, **after** the Player plane and the plane kits and **before** Collision step 1 (so a request made on tick T is in tick T's hit pass: the deathbomb, Rule 17). It uses no `delta`, no global `randf()` and no randomness at all (ties break by target id, then by hook index). A thin Node adapter draws and plays sound. It holds no bullet references (Bullet manager Rule 5). Slots tick in the rotating rank `rank = (slot - (tick mod 4) + 4) mod 4`, ascending (the same rotation as Collision C6), so same-tick ties are fair in co-op.
2. **Stock.** `bombs` is an integer, `0 .. bomb_max` (5), per slot. Bombs is its **only writer**; Session (1) stores it in the slot record so it survives scene changes (Amendment 5). It is not a powerup: nothing the player picks up, scores or waits for adds a bomb.
3. **Stock rules** (this table is complete; any other change to `bombs` is a bug):

   | Event | Result |
   |---|---|
   | Run start, a continue accepted, a drop-in confirmed | `bombs = bomb_start` (3) |
   | `player_died(slot)` (Collision Rule 3) | `bombs = bomb_start` (a hard reset, like drones; it also refills 0 to 3) |
   | `stage_started`, for a slot that is Alive or Dead | `bombs = max(bombs, bomb_stage_floor)` (3) |
   | `boss_started`, for a slot that is Alive or Dead | `bombs = max(bombs, bomb_boss_floor)` (default 0: no change) |
   | A bomb accepted | `bombs = bombs - 1` |
   | Pickups, extends, 1-ups, score, time, kills, Critical Break | no change |

   `bombs` never exceeds `bomb_max`. With the defaults it never exceeds 3, so every stage starts with exactly 3 and the Critical Break needs 1 of them.
4. **Accepting a press.** On every tick where the slot's `BombCore` is **IDLE**, `bombs >= 1`, the plane is **Active**, and Session is in the Stage state, `BombCore` calls Input's `consume(slot, BOMB)` (Input Rule 17, F6). If it returns true (a fresh press this tick, or a buffered press within `buffer_ticks` = 6), the bomb is accepted. It does **not** call `consume` in any other case, so a press made during a bomb is not eaten and not stored forever: it simply expires after 6 ticks. Session events (`stage_cleared`, `stage_started`) are applied at the start of the tick, before the press.
5. **On accept** (`k = 0`), in this order, all on the same tick:
   1. `bombs = bombs - 1`; emit `bombs_changed(slot, old, new)`.
   2. `request_invuln(slot, bomb_invuln)` (90 ticks; Collision C3, `max`-combined, never added).
   3. **Chain toll** (Rule 12), unless a Critical Break is armed.
   4. **Full-screen cancel** of the enemy pool, with score items, cause slot = this slot (Rule 13).
   5. Start the plane-specific effect (Rules 20-27).
   6. Emit `bomb_started(slot, plane, pos)` and `bomb_used(slot)` (event bus).
6. **One bomb at a time, then a lockout.** After an accepted bomb the slot is not IDLE for **`bomb_lockout`** = 90 ticks (the same length as the invulnerability): press at tick T, next possible accept at T + 90. While not IDLE a **fresh** press emits `bomb_denied(slot, BUSY)`. With `bombs = 0` it emits `bomb_denied(slot, NO_BOMBS)`. A denied press changes nothing else. Pressing while the plane is not Active does nothing at all (Input already clears the buffer, Input Rule 18; no event).
7. **A bomb never touches the kit.** It does not interrupt the Lancer laser, cost or fill the meter, start a drone cooldown, move drones, or change `charge_active` (Plane kits Rule 40). Fire and Drone presses on the same tick are processed by the kit as normal. The bomb does not slow or speed the plane. The bomb effect does not read kit state at all, so a plane with 0 drones and a plane with 4 drones bomb identically.
8. **Bomb damage events.** Bomb damage goes to Collision as `(target, slot, damage, BOMB, seq, counts_chain = false)`. `seq` is a per-slot counter. Collision's same-tick order puts bombs first (`source_rank` 0, Collision C6). Bombs sends **at most one event per target per tick per bomb** and never more than `bomb_target_cap` (1,000, measured before the part multiplier) to one target per bomb (F7). Targets are read from the Bullet manager's hurtbox registry, which holds only targetable enemies (Enemy Rule 9), so a bomb never hurts an enemy the player has not seen.
9. **Bomb damage never counts for the chain.** The `counts_chain = false` flag makes Collision skip `chain_hit` for the result (Amendment 3). The bomb **does** pay everything else: kill credit and score (Scoring S2/S3), carrier drops (Powerups), part-kill cancels (Boss). This is the Collision Rule 13 decision: **a bomb touch never counts as a chain hit** (so a bomb cannot refill the chain window, farm hits, or keep a chain alive).
10. **Damage modifiers.** A target of class PART (a boss part) takes `bomb_part_pct` = 60% of the base damage (integer: `(base x 60) div 100`). Every other class takes 100%. Armour then applies as usual (Collision C4). **Immune** targets get **no event** (the bomb passes through; it is not blocked by them, unlike the laser). A target destroyed earlier in the same tick returns *ignored* (Collision C6) and still counts toward the cap (the event was sent).
11. **Bomb results come back.** Collision returns each result to Bombs. For every *hit* or *destroyed* result Bombs emits `bomb_landed(slot, target_id, target_class, tick)`. This is how the Critical Break learns that a bomb reached the core (Rule 28). *Ignored* results emit nothing.
12. **Chain toll.** At `k = 0`, if `bomb_chain_toll_pct > 0` and the slot's chain `count > 0` and the chain is not Frozen, Bombs calls `Chain.apply_bomb_toll(slot, bomb_chain_toll_pct)`: `after = before - (before x toll_pct) div 100` (F4). The chain keeps its window (no refill), `last_dropped` is unchanged, and no `chain_dropped` event is sent (it is a reduction, not a drop; Chain emits `chain_reduced(slot, before, after)`). The toll is paid **once per bomb**, at `k = 0` only. **It is waived** when the Critical Break (17) reports `cb_armed(slot)` true on the accept tick. *(Defined 2026-11-03 in critical-break.md F1:)* `cb_armed(slot)` = boss `is_critical()` AND the break not yet consumed AND the slot Active AND its charge (Lancer laser active ticks, not grace; Leech focused shot) has run >= `cb_charge_min_ticks` (12) consecutive ticks AND is charging now or ended <= `cb_charge_lenience` (12) ticks ago AND its last charge hit was on the core (`core_target_id()`) <= `cb_hit_window` (12) ticks ago. A bomb accepted while armed is **committed**: it needs no further charge to break when it lands on the core.
13. **Cancel.** At `k = 0` Bombs sends one **full-screen cancel** of the enemy pool with score items to the Bullet manager (Bullet manager Rules 13-14), cause slot = the bomber. Powerups (13) caps the items (`items_per_cancel_cap`, proposed 100; the bullets beyond the cap still vanish, with no item). Every later cancel the bomb makes (Rules 22, 26) is an **area cancel with no items** (`items = false`; Amendment 4). The cancel runs before the hit pass in the same tick (Bullet manager Rule 7), so a cancelled bullet never hits (the deathbomb works). A full-screen cancel also catches bullets in the margin; their items are moved inside the play area (Bullet manager F9).
14. **Invulnerability is exactly as long as it says.** The request is 90 ticks from `k = 0`: ticks `T .. T+89` are safe, `T+90` is the first mortal tick (Collision C3). The plane blinks while any non-laser request is active (Plane kits Amendment 3c; Player plane V7), so the bomb's end is visible. The plane can fly through enemy bodies while invulnerable (Collision Rule 9); if it is still inside a lethal body when the timer ends, it is hit on the first hittable tick (Collision edge case). That is the player's call.
15. **No auto-bomb in the MVP.** A bomb is only ever started by a Bomb press. (An accessibility "auto-bomb on lethal hit" option needs a pre-hit callback from Collision; see Open Questions.)
16. **Reset and end rules.**
    - `stage_cleared`: the bomb effect stops at once (no more damage events, cancels or hooks), the slot goes IDLE, the invulnerability timer is left to Collision. `bombs` is kept.
    - `plane_died(slot)` (including a Collision death), `forfeit_slot`, or the slot leaving play: the effect stops at once, hooks are removed, the slot goes IDLE, `bombs` follows Rule 3 (death) or is irrelevant (forfeit).
    - Pause: no ticks run; everything freezes.
17. **Deathbomb (decision).** The only deathbomb is the **same tick**: a press on the tick T of a lethal hit saves the player (Collision edge case and AC-24); a press on T+1 is too late and is ignored (the plane is Dying). There is **no grace window after the hit**. Why this is fair: the Input buffer only helps *before* the bomb is ready (after a lockout), not after a hit; the player must press when they *see* the bullet that will kill them, one decision earlier. Every death is therefore still the player's fault (Readable Chaos). A short grace window is an Open Question, not a knob, because it needs Collision to delay a death.

**B. Lancer: Lance Sweep**

18. **Origin.** `x0` = the plane's x at `k = 0`, clamped to `[0, 360]`. The column is **world-anchored**: it does not follow the plane afterwards.
19. **Hold phase** (`k = 0 .. hold_ticks - 1`, `hold_ticks` = 24): one full-height column (from `play_top` to y = 640), centred on `x0`, `sweep_half_w` = 28 px each side (56 px wide).
20. **Sweep phase** (`k >= hold_ticks`): with `m = k - hold_ticks + 1`, `d = sweep_speed x m` (8 px per tick), two columns of the same width centred on `x0 - d` and `x0 + d`. The effect ends (ACTIVE ends) after the last tick with any part of a column inside the field: `effect_ticks = hold_ticks + ceil((max(x0, 360 - x0) + sweep_half_w) / sweep_speed) - 1` (F5). 49 ticks at `x0` = 180; 72 at the screen edge; never more than 72.
21. **Damage.** On every tick `k` with `k mod damage_interval == 0` (4), every non-immune target whose hurtbox circle overlaps **any** column (`|cx - column_x| < sweep_half_w + r_h`, strict) takes **one** event of `lancer_damage` = 100 (60 on a PART). A target in both columns on one tick gets one event. The cap (Rule 8) applies.
22. **Cancel.** `k = 0`: full-screen with items (Rule 13). Each later tick `k = 1 .. effect_ticks - 1`: one area cancel per column rectangle, clipped to the field, **no items**. During the hold phase that is one rectangle; during the sweep phase two. A bullet that spawns inside a rectangle on that tick is cancelled too (cancel runs after spawns). Bullets outside the rectangles survive.
23. **Plane control.** The plane moves normally and fires normally; it is invulnerable for 90 ticks. The column never hurts planes (Co-op Rule 8).

**C. Leech: Barb Burst**

24. **Launch** (`k = 0`): `hook_count` = 4 **bomb hooks** appear at the plane's position. They are bomb projectiles, **not the player's drones**: drones are neither used nor changed. The effect is the same with 0 drones.
25. **Choosing a target** (at launch, and for every retarget): hooks are processed in index order `i = 0..3`. A hook takes, among **eligible** targets (in the hurtbox registry, alive, not immune) with the **fewest hooks already claiming them**, the one nearest to the hook's current position (lowest id on ties). A claim is a hook flying to, clinging to, or retargeted to that target. With 4 or more eligible targets this spreads one hook per target; with 2 it gives 2 each; with 1 it gives all 4 to it. No eligible target: the hook is **SEARCHING**.
26. **Hook life.**
    - **FLYING:** moves `hook_speed` = 14 px/tick straight at the target's centre each tick (homing), starting on `k = 1`. When its distance is `<= 14` at the start of a tick, it is **CLINGING** from that tick (the arrival tick `a`). A flying hook can't be hit and deals no damage.
    - **CLINGING:** rides the target (display offset only), for `cling_ticks` = 18. At tick `a + 18` it **detonates**.
    - **Target lost** (destroyed, turned immune, left the field, removed): a FLYING hook retargets at once by Rule 25 from its current position (none: SEARCHING); a CLINGING hook detonates at once at its last position with no primary hit (splash only).
    - **SEARCHING:** hovers in place and re-checks every tick. It becomes FLYING when a target appears. After `search_ticks` = 30 ticks without one, it detonates in place (cancel only; no damage, because nothing is eligible near it).
    - **Life cap:** any hook not yet detonated at `k = hook_life_cap` = 84 detonates in place. So the effect always ends by `k = 84`, before the 90-tick lockout.
27. **Detonation.** At the blast point `B` (the hook's position): (a) one event of `hook_damage` = 200 (120 on a PART) to the primary target if it is still eligible; (b) one **splash** event of `hook_damage x splash_pct / 100` = 100 (60 on a PART) to every *other* eligible target whose hurtbox circle satisfies `dist(B, centre) <= splash_radius + r_h` (`splash_radius` = 40); (c) one **circle cancel** of radius `blast_cancel_radius` = 96 around `B`, **no items**. All obey the cap (Rule 8). A target hit by several hooks in one tick takes one event per hook (they carry different `seq`).

**D. Critical Break contract** (specified in [critical-break.md](critical-break.md) Rules 9-12)

28. **Critical Break (17) owns the trigger** (boss core at critical HP + charge active + bomb). Bombs supplies: `bomb_active(slot)` (true while the bomb is ACTIVE, i.e., ticks `0 .. effect_ticks - 1`), `bomb_landed(slot, target_id, target_class, tick)` (Rule 11), and consumes `cb_armed(slot)` (Rule 12). A bomb "lands" on the core when a bomb event on the core returns *hit* or *destroyed* (an armoured core counts). The Critical Break decides whether `charge_active(slot)` was true on that tick. Bombs never triggers, ends or changes anything because of a Critical Break. **Banner rule** (art bible §7.4): Bombs clears the field on `k = 0`, but bullets can reappear before the bomb lands on the core, so **17 must issue its own full-screen cancel on the trigger tick, before any banner is shown** (Amendment 10). *(2026-11-03: the interface is now specified in `critical-break.md` Rules 9-12: the trigger is `bomb_landed(slot, core, CORE)`, valid if the bomb was committed at the accept tick or the slot is armed at the landing tick.)*
29. **Plane-specific timing for the break.** Lancer: the hold column covers the plane's x at `k = 0..23`, so a core aligned for the laser (`|dx| < 7 + r_h`) is also hit at `k = 0`; the player needs only to be holding the laser first. Leech: hooks reach the core about 20-70 ticks after the press; the player must keep Fire held (focus shot active) until the detonation (Open Question 7).

**E. Co-op**

30. **Stock and bombs are per player.** No sharing or transfer (Co-op Rule 4). Overlapping bombs from several slots are allowed; each has its own state, invulnerability and cap.
31. **Shared field effects help everyone** (Co-op Rule 9): the cancel clears the whole field for all players, but only the bomber is invulnerable. Items go to the cause slot (Bullet manager Rule 14). If two bombs land on one tick, the first in rank order cancels the bullets and gets the items; the second finds the field empty (Bullet manager: first request wins). Because rank rotates each tick (Rule 1), neither slot is favoured over a run.
32. **Team chain.** Bomb hits never set `boss_hit_left` (they do not count), so a bomb cannot keep a team chain alive.
33. **No friendly fire.** The column and the hooks never hit a plane's hitbox (Co-op Rule 8).

**F. Era hook (Era shift 19, [GDD](era-shift-and-plane-evolution.md))**

34. Each bomb has one **`EraBombSkin`** resource per era (`data/bombs/skins/*.tres`) that may change **only** sprite and animation ids, sound ids and colour tint within the warm range. It may not change any damage, count, radius, width, speed, interval, tick count, stock or toll number. All numbers are identical in every era (AC-44). The `EraBombSkin` is selected by `(bomb, era_index)` at the `era_swap_committed` swap commit (Era shift 19) *(2026-11-03, wave 3b)*.

**G. Target-tier bombs (Sentry/Breaker kits (29), [GDD](plane-kits-sentry-breaker.md)) — added 2026-11-03, wave 4**

35. **Sentry: Bastion** (Sentry/Breaker Rule 31, SB7-SB8). A growing dome centred 56 px ahead of the plane: radius 40 → 104 (4 px/tick), `effect_ticks` 72 (fixed), 60 damage every 6 ticks (at most 12 events = 720; PART 36), shelters allies. All Bombs rules apply (full-screen cancel with items at `k = 0`, area cancels without items afterwards, no kit state read, ends before the 90-tick lockout).
36. **Breaker: Backlash** (Sentry/Breaker Rule 32, SB7-SB8). A full-width wall rising 12 px/tick from the plane, `effect_ticks` 2-49, 500 damage once per target (PART 300), hits everything above the plane. Same Bombs rules as Rule 35.

**Prototype migration (`player.gd`, `plane_config.gd`, `combat_rules.gd`, `boss.gd`)**

| Prototype | Problem | Corrected here |
|---|---|---|
| `bombs = 3`, held in `player.gd` | Mixed with chain, score, lives | `BombCore` + stock in Session (Rules 2-3) |
| `bomb_invulnerability 2.0` (float seconds) | Not tick-exact; no `max` combine | `request_invuln(slot, 90)` (Collision C3) |
| `bomb_damage 80.0` to every part, once | Float; hits everything on screen; no limit | Integer damage, per-target cap 1,000, targets only if targetable (Rules 8, 10) |
| `bomb_part_mult 0.6` (float) | Float | `bomb_part_pct` 60 (whole percent) |
| Bomb only works with a live boss (`boss == null` returns) | No bombs in waves | Bombs work anywhere in a stage (Rule 4) |
| Bomb hits counted via `register_hit` (chain) | Bomb refills chain | `counts_chain = false` (Rule 9) |
| Bomb fills the laser meter | Bomb spam feeds the laser | Never (Rule 7; Plane kits Rule 20) |
| No cancel | Bomb does not clear bullets | Full-screen cancel (Rule 13) |
| `HUD`: "LASER + BOMB" critical text from `player.gd` | Mixed systems | Critical Break (17) owns it (Rule 28) |

> Decided under auto-approve (2026-11-03): stock 3 per life, reset on death, topped up to 3 at each stage start, max 5, no powerup refill; one bomb at a time with a 90-tick lockout equal to the invulnerability; 90-tick invulnerability; same-tick deathbomb only (no grace); Bomb press via `consume` only while IDLE; bomb hits never count for the chain; half the chain is lost per bomb (waived when a Critical Break is armed); full-screen cancel with items on the press tick, area cancels without items afterwards; bomb passes through immune targets; boss parts take 60%; 1,000 per target per bomb cap; Lancer = world-anchored column that holds 24 ticks then sweeps outward at 8 px/tick; Leech = 4 independent bomb hooks (not drones) that pick the least-claimed nearest target, cling 18 ticks and burst; no auto-bomb; no kit state read.

### States and Transitions

**Bomb state (per slot)**

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| IDLE | Ready if `bombs >= 1` | ACTIVE | Press accepted (Rule 4) |
| ACTIVE | Effect running; ticks `0 .. effect_ticks - 1`; invulnerable | TAIL | `k = effect_ticks` (Lancer 49-72; Leech: when the last hook has detonated, at most `k = 85`; Bastion 72; Backlash 2-49) |
| TAIL | Effect over, invulnerability and lockout still running | IDLE | `k = bomb_lockout` (90) |
| ACTIVE / TAIL | | IDLE | `plane_died`, `stage_cleared`, `forfeit_slot` (effect stops at once) |

`bomb_active(slot)` is true only in ACTIVE. `bomb_busy(slot)` is true in ACTIVE and TAIL. A fresh press while busy emits `bomb_denied(BUSY)`.

**Lancer effect**

| Phase | Ticks | Column(s) |
|---|---|---|
| HOLD | `k = 0 .. 23` | One, centred `x0` |
| SWEEP | `k = 24 .. effect_ticks - 1` | Two, centres `x0 - 8m` and `x0 + 8m` (`m = k - 23`) |

**Leech hook (per hook)**

| State | → Next | Trigger |
|---|---|---|
| FLYING | CLINGING | Distance to target centre <= 14 at the start of a tick |
| FLYING | FLYING / SEARCHING | Target lost: new target / none |
| SEARCHING | FLYING | An eligible target appears |
| SEARCHING | DONE | 30 ticks without a target (detonate in place) |
| CLINGING | DONE | `a + 18` (detonate), or target lost (detonate at once) |
| Any | DONE | `k = 84` (detonate in place), or `plane_died` / `stage_cleared` / `forfeit_slot` (removed, no blast) |

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Session (1) — GDD | ← slot states, `stage_started`, `stage_cleared`, `boss_started`, `player_died`, continue and drop-in events; → `bombs` (stored in the slot record), `bomb_used(slot)` on the event bus | Bombs is the only writer of `bombs`. |
| Input (2) — GDD | ← `consume(slot, BOMB)` each IDLE tick | A denied or busy press is not consumed. |
| Bullet manager (3) — GDD | → `request_cancel(area, cause_slot, items)` with area = full screen, rectangle or circle; ↔ hurtbox queries `nearest(pos, filter)` and the registry list | Amendment 4: rectangle area type and `items` flag. |
| Player plane (5) — GDD | ← plane position, state (Active); `blink_remaining` includes the bomb | Bombs reads `pos` at `k = 0`. |
| Collision (6) — GDD | → `request_invuln(slot, 90)`, damage events `(…, BOMB, seq, counts_chain = false)`; ← hit results | Amendment 3. |
| Chain tracker (7) — GDD | → `apply_bomb_toll(slot, pct)`; ← `chain_reduced` | Amendment 2. |
| Scoring (8) — GDD | none directly | Kills by bombs pay through Collision `kill_credit`. |
| Plane kits (11) — GDD | none | The bomb reads no kit state. |
| Powerups and drops (13) — [GDD](powerups-and-drops.md) | → cancelled positions through the Bullet manager; ← `items_per_cancel_cap` | Provisional: cancel items are gems; cap applies per cancel request; area cancels give none. |
| Boss (14) — [GDD](boss-and-boss-parts.md) | ← hurtbox `kind` (PART or CORE), optional `bomb_pct` override | Provisional. Boss phase spans must be >= `4 x bomb_target_cap` (F10). |
| Critical Break (17) — [GDD](critical-break.md) | → `bomb_active`, `bomb_landed`; ← `cb_armed(slot)` query; 17 issues its own cancel | Rule 28; CB Rules 9-12. |
| Co-op (18) — GDD | none | Per-slot stock; rank rotation (Rule 1). |
| HUD (20) — [GDD](hud.md) | → `bombs`, `bomb_busy`, `bomb_denied` | See UI Requirements. |
| Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | → events | See Visual/Audio. |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | ← `era_index` | Selects `EraBombSkin` at `era_swap_committed` (Rule 34). |

All listed systems now have GDDs *(2026-11-03, wave 3b)*; the contracts above are what this GDD expects.

## Formulas

All time in integer ticks, distance in px, damage in integer units. `div` is integer division. `k` = ticks since accept.

**B1. Stock**

`bombs' = bomb_start` (start / continue / drop-in / death) · `max(bombs, floor)` (`stage_started`, `boss_started`) · `bombs - 1` (accept), then `bombs' = clamp(bombs', 0, bomb_max)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Stock | `bombs` | int | 0-5 | Per slot |
| Start | `bomb_start` | int | 2-5 (3) | After start, continue, drop-in, death |
| Stage floor | `bomb_stage_floor` | int | 1-5 (3) | Minimum at `stage_started` |
| Boss floor | `bomb_boss_floor` | int | 0-2 (0) | Minimum at `boss_started`; 0 = off |
| Max | `bomb_max` | int | 3-5 (5) | Cap (HUD shows at most 5 icons) |

**Output Range:** 0-5. **Example:** stage 1 starts with 3; 2 used on waves → 1; the Critical Break uses the last → 0; stage 2 starts → 3. Death with 1 → 3. A debug-set 5 → death → 3; `stage_started` with 5 → 5 (a floor never lowers).

**B2. Press acceptance and lockout**

`accept(t) = IDLE AND bombs >= 1 AND plane Active AND Session in Stage AND consume(slot, BOMB)`; next IDLE tick = `t0 + bomb_lockout`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Buffer | `buffer_ticks` | int | 0-12 (6) | Owned by Input |
| Lockout | `bomb_lockout` | int ticks | 85-150 (90) | From accept to the next possible accept |
| Accept tick | `t0` | int | >= 0 | |

**Output Range:** one accept per `bomb_lockout` ticks per slot. **Example:** accepted at tick 100 (bombs 3 → 2); IDLE again at 190. A press at 150 → `bomb_denied(BUSY)`. A press at 185: `consume` at 190 sees 190 - 185 = 5 <= 6, so a bomb starts at 190. A press at 183: 7 > 6, expired, nothing starts at 190.

**B3. Invulnerability**

`invuln_remaining' = max(invuln_remaining, bomb_invuln)` at the accept tick; safe ticks `t0 .. t0 + bomb_invuln - 1`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Bomb invulnerability | `bomb_invuln` | int ticks | 60-150 (90) | Collision timer cap is 240 |

**Output Range:** 60-150. **Example:** a respawn timer has 70 left at tick T: a bomb makes it 90, safe through T+89. A laser request of 13 on the same tick changes nothing. A timer of 100 stays 100 (the bomb adds nothing).

**B4. Chain toll**

`after = before - (before x toll_pct) div 100`, applied once at `k = 0`; skipped if `toll_pct = 0`, `before = 0`, the chain is Frozen, or `cb_armed(slot)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Chain count | `before` | int | 0-999 | Count at `k = 0` |
| Toll | `bomb_chain_toll_pct` | int (whole percent) | 0-75 (50) | Share of the count lost |
| Result | `after` | int | 1-999 when `before >= 1` | `ceil(before x (100 - toll) / 100)` |

**Output Range:** `after >= 1` for any `before >= 1` (the toll never drops a chain to 0). **Example (toll 50):** 187 → 187 - 93 = **94**; 150 → 75; 99 → 99 - 49 = 50; 3 → 2; 2 → 1; 1 → 1; 0 → 0; 999 → 999 - 499 = **500**. At toll 75: 187 → 187 - 140 = 47.

**B5. Lancer geometry and damage**

`column_x(k) = x0` for `k < hold`; for `k >= hold`: `m = k - hold + 1`, `d = v x m`, columns `x0 - d` and `x0 + d`
`hit(k, target) = (k mod interval == 0) AND for any column: |cx - column_x(k)| < half_w + r_h`
`effect_ticks = hold + ceil((max(x0, 360 - x0) + half_w) / v) - 1`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Origin | `x0` | int px | 0-360 | Plane x at `k = 0` |
| Hold | `hold` (`hold_ticks`) | int ticks | 12-36 (24) | Column stays at `x0` |
| Half width | `half_w` (`sweep_half_w`) | int px | 20-40 (28) | 56 px wide |
| Sweep speed | `v` (`sweep_speed`) | int px/tick | 6-12 (8) | Each column |
| Interval | `interval` (`damage_interval`) | int ticks | 3-6 (4) | Ticks between damage events |
| Target centre / hurtbox radius | `cx`, `r_h` | px | field / 9-22 (enemies) | From the registry |

**Output Range:** `effect_ticks` 49-72. A target takes at most **9** events at `r_h` 12 and 10 at larger boss hurtboxes (the cap, 10 x 100). **Example (`r_h` 12, `x0` 180):** a core at `x = 180`: events at k = 0, 4, 8, 12, 16, 20 (hold) and 24 (the columns at 172/188 still overlap: 8 < 40), none at 28 (d = 40, 40 < 40 is false) → 7 events = **700**. A medium at `x0 + 100`, `r_h` 14: overlap when 58 < d < 142, i.e., k = 31..40 → events at **32, 36, 40** = 300. `effect_ticks`: `x0` 180 → 24 + ceil(208 / 8) - 1 = **49**; `x0` 8 → 24 + ceil(380 / 8) - 1 = 24 + 48 - 1 = **71**; `x0` 0 or 360 → 24 + ceil(388 / 8) - 1 = **72**. A core at dx = 39 gets 6 hold hits + 3 sweep hits (k = 24, 28, 32) = **900** (the maximum at `r_h` 12).

**B6. Leech hook: targeting, flight, detonation**

`claims(t)` = hooks flying to, clinging to or assigned to target `t`; hook takes `argmin over eligible t of (claims(t), dist(hook, t), id)`
Each tick FLYING: `if dist <= 14: CLING; else pos += 14 x unit(target - pos)`; `detonate_tick = a + cling_ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Hook count | `hook_count` | int | 2-6 (4) | Fixed, independent of drones |
| Hook speed | `hook_speed` | int px/tick | 10-16 (14) | 840 px/s |
| Arrival radius | `arrive_r` | int px | 10-16 (14) | |
| Cling | `cling_ticks` | int | 6-30 (18) | Fuse after arrival |
| Search | `search_ticks` | int | 10-45 (30) | SEARCHING before a blank blast |
| Life cap | `hook_life_cap` | int | 60-88 (84) | Must be < `bomb_lockout - 4` (lint) |

**Output Range:** arrival `a` 1-53, detonation 19-71 (+ search up to 84). **Example:** plane at (180, 500); targets T1 (180, 400) 100 px, T2 (100, 300) 215.4 px, T3 (300, 200) 323.1 px, T4 (50, 150) 373.4 px, T5 (260, 100) 407.9 px → hooks 0-3 take T1, T2, T3, T4 (each has 0 claims; T5 is farthest). With only T1 and T2: T1, T2, T1, T2. With only T1: all four. A target 280 px away: moves on ticks 1-19 (280 - 14 x 19 = 14), clings from tick **a = 20**, detonates at **k = 38**. The longest flight (734.3 px diagonal): `a = 53`, detonation 71, under 84.

**B7. Damage per event, cap**

`base = lancer_damage | hook_damage | splash_damage`; `dmg = (base x bomb_part_pct) div 100` if PART else `base`; send only if `sent[target] + base <= bomb_target_cap`, then `sent[target] += base`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Lancer hit | `lancer_damage` | int | 60-150 (100) | >= `armour_damage_min` 20 |
| Hook hit | `hook_damage` | int | 120-300 (200) | |
| Splash | `splash_damage` | int | `hook_damage x splash_pct div 100` (100) | |
| Part percent | `bomb_part_pct` | int | 40-100 (60) | Whole percent |
| Cap | `bomb_target_cap` | int | 600-1500 (1000) | Per target per bomb, before the part percent |
| Sent | `sent[target]` | int | 0..cap | Per bomb, resets each bomb |

**Output Range:** 0-1,000 pre-multiplier per target per bomb; a PART takes at most 600. Every sent value (and its ×60% form) is an integer >= 20. **Example:** Lancer on a PART: 100 → 60 per hit. A core with `sent` = 900 and a next hook hit of 200: 900 + 200 > 1,000, skipped. With `sent` = 900 and a next Lancer hit of 100: sent (1,000); the one after is skipped. Armoured core at 25%: Lancer 100 → dealt 25 (Collision C4: `(100 x 25) div 100`); a PART hit of 60 → 15.

**B8. Bomb value and balance (single-target reference)**

`lone_core = hits x damage` (Lancer, `r_h` 12, `x0` aligned) vs `4 x hook_damage` (Leech)

| Scene | Lancer | Leech | Ratio (L / Le) |
|---|---|---|---|
| Lone boss core above the plane | 7 x 100 = 700 | 4 x 200 = 800 | 0.875 |
| Boss PART (x 60%) | 7 x 60 = 420 | 4 x 120 = 480 | 0.875 |
| 5 small enemies (hp 20-60) spread 40 px apart | all die (sweep reaches all) | 4 hooks + splash (radius 40 + `r_h`) reach all | similar |
| One MEDIUM (flak gunner, hp 1,200) directly above | 700: survives (58% lost) | 800 (4 hooks): survives (67% lost) | 0.875 |
| One MEDIUM only on the sweep (offset 100 px) | 300: survives (25% lost) | 800: survives (67% lost) | 0.375 |
| One LARGE (heavy bomber, hp 4,000), plated 50% | 350: survives | 400: survives | — |

**Output Range:** a bomb never kills a MEDIUM or LARGE alone (it kills SMALL fodder, hp 20-60, and softens bigger targets). A full bomb on one target is about **1 s of one player's reference fire** (`ref_dps` = 800, Plane kits: 700-800 damage = 0.9-1.0 s). The bombs are within +/-15% on a lone core (0.875) and differ by scene: Lancer covers width over time, Leech picks targets. **Example (share of a boss, solo hp):** Fortress core 16,500: 700 / 16,500 = **4.2%** (Lancer), 800 / 16,500 = **4.8%** (Leech); Jet core 19,700: 800 / 19,700 = 4.1%. A Fortress turret (2,400, PART x 60%): Lancer 420 = 17.5%, Leech 480 = 20%; four Leech bombs on one turret = 1,920 < 2,400 (and part hp is x2.5 at 4P, Co-op F4), so bombs alone cannot strip a part in co-op. The core is armoured while parts live, so its real loss is smaller.

**B9. Item farm bound (anti-farm)**

`farm = n_items x item_base_gem x (1 + min(count_at_pickup, factor_cap_count) div factor_step)` (Scoring F3)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Items from one bomb | `n_items` | int | 0-100 | `items_per_cancel_cap` (Powerups 13), only the `k = 0` cancel gives items |
| Gem base | `item_base_gem` | int | 100 | Scoring F3 |
| Chain at pickup | `count_at_pickup` | int | 0-999 | After the toll |
| Cap / step | `factor_cap_count`, `factor_step` | int | 500 / 50 | Scoring F3 |

**Output Range:** 10,000-110,000 per bomb. **Example:** chain 999 → toll → 500 at pickup: factor `1 + 500 div 50` = 11 → 100 x 100 x 11 = **110,000** (the maximum). Chain 40 after the toll: factor 1 → **10,000**. Chain 237: factor 5 → 50,000. At most 3 bombs per life: <= 330,000 per life, about 1.7% of an expert's 19.7M stage and 11% of a competent 2.99M (Scoring F7, updated 2026-11-03; the competent share is the one to watch: if it proves exploitable, lower `items_per_cancel_cap` to 50, which halves it); the toll makes the high-chain case cost a lot of chain to get it.

**B10. Boss phase guard (data test)**

`phase_span >= phase_guard_mult x bomb_target_cap` for every boss phase boundary, `phase_guard_mult` = 4

**Output Range:** with defaults, every boss phase must span >= **4,000 hp** (solo). **Example:** the Fortress core (16,500 hp) in 3 phases is 5,500 per phase and the Jet core (19,700) is 6,567: both pass; four players' bombs on one core (4 x 800 = 3,200) cannot cross a phase. A core split into 4 phases (4,125 each) passes only barely; 5 phases fail the guard. Co-op hp scaling (x2.5 at 4P) widens the margin.

> Formulas proposed by game-designer; numbers by auto-approve (2026-11-03). Landing assumptions are none: bomb damage is deterministic by geometry. Balance references updated 2026-11-03 (coordinator): `ref_dps` 800 (Plane kits), enemy hp flak gunner 1,200 / radar gunner 1,500 / heavy bomber 4,000 / missile carrier 5,000, boss hp Fortress turrets 2,400 / engines 3,200 / core 16,500, Jet pods 1,900 / wings 4,100 / core 19,700, Scoring stage totals competent ~2.99M / expert ~19.7M.

## Edge Cases

**Press, stock and buffer**

- **If Bomb is pressed with 0 bombs**, `bomb_denied(NO_BOMBS)` fires (quiet low blip); nothing else changes and nothing is consumed.
- **If Bomb is pressed during ACTIVE or TAIL**, `bomb_denied(BUSY)` fires on the fresh press; the press is not consumed and expires after 6 ticks, so it never fires later unless the lockout ends within those 6 ticks (then it fires at IDLE, by design).
- **If Bomb is pressed 7 or more ticks before the lockout ends**, it expires and nothing fires; at 6 or fewer, it fires on the first IDLE tick (B2).
- **If Bomb is pressed on the same tick as a lethal hit**, the bomb's `request_invuln` is applied in Collision step 1, so the player survives (Collision AC-24). On the next tick the plane is Dying and the press is ignored; no bomb is spent.
- **If Bomb is pressed during respawn invulnerability**, it is accepted and spent; the invulnerability becomes `max(remaining, 90)`; the cancel still clears the field. (Allowed: the player's call.)
- **If Bomb is pressed during FlyIn, Dying or Absent**, nothing happens; Input already cleared the buffer (Input Rule 18).
- **If Bomb is pressed on the tick `stage_cleared` arrives**, the Session event is applied first, Session is not in Stage, so the press is ignored and no bomb is spent.
- **If `stage_started` tops up the stock**, Bombs also calls `consume(slot, BOMB)` for every slot once, so a press made just before the stage began cannot fire a bomb on tick 1.
- **If Bomb is pressed with Fire and Drone on one tick**, all three are processed; the kit handles Fire and Drone, Bombs handles Bomb; no ordering is applied.
- **If the game is paused**, no ticks run: timers, hooks, columns and stock freeze. Input's resume rule discards held presses (Input Rule 27).
- **If a menu's Cancel verb uses the Bomb button** (Input Rule 24), the press that closes a pause menu is consumed by Input and produces no bomb.

**Stock**

- **If the plane dies with 0 bombs**, `bombs` becomes 3 (Rule 3). Dying is the refill.
- **If a slot continues or drops in**, `bombs` = 3.
- **If a debug cheat sets `bombs` above `bomb_max`**, it is clamped to 5.
- **If `bomb_stage_floor` is below the current stock**, nothing is lowered (a floor, not a reset).

**Effects: all bombs**

- **If a target is destroyed earlier in the same tick**, later bomb events on it return *ignored* (Collision C6), count toward the cap, and give no `bomb_landed`.
- **If a target is immune**, the bomb sends no event to it and does not stop at it. A normal target behind it in the same column is still hit.
- **If the target is armoured** (a core with parts alive, a plated LARGE), the event is sent at full base damage and Collision applies the percentage; `bomb_landed` fires on a *hit* result.
- **If a bomb hits a boss part and destroys it**, kill credit and score (S3) pay, and the Boss's part-kill cancel runs as normal; whether a bomb kill gives the +5 chain bonus is Boss's call, recommended **no** (Open Question 4).
- **If the full-screen cancel catches 2,000 bullets**, all are removed on `k = 0`; only the first `items_per_cancel_cap` (proposed 100) become items; the rest vanish with none.
- **If a bullet spawns inside a rolling-cancel rectangle or circle on that tick**, it is cancelled with no item.
- **If no enemy is on screen**, the bomb still clears bullets (the full-screen cancel), still gives invulnerability, still costs a bomb and the toll; no damage events are sent.
- **If the stage clears mid-bomb**, the effect stops on that tick: no further damage, cancel or hook events; hooks are removed without a blast; stock kept; the invulnerability timer is left to Collision.
- **If the slot leaves play mid-bomb** (`forfeit_slot`), the effect stops the same way; no event follows.
- **If two bombs overlap in co-op**, each applies its own damage, so a target can take one event per bomb per tick; each bomb's cap is separate (4 x 1,000 at most; B10).
- **If a bomb ends while the plane is inside a lethal body**, the plane is hit on the first hittable tick (T+90), as in Collision. The plane's blink is the warning.

**Lancer**

- **If the plane is at the screen edge**, `x0` is clamped to `[0, 360]`; the column is clipped to the field; `effect_ticks` = 72.
- **If the plane moves during the hold**, the column stays at `x0`. It does not follow.
- **If the target is in both columns on one tick** (k = 24, the columns still overlap), it takes **one** event.
- **If a target enters the column late** (hold phase), it can still be hit on the next `k mod 4 == 0` tick; the count is capped by the cap, not by the time.
- **If the boss core is taller than the column**, `r_h` widens the overlap; up to 10 events (the cap) can land.
- **If the laser is on**, the bomb does not interrupt it; both can hit the core on the same tick (Collision C6: bomb first, then laser).

**Leech**

- **If there are fewer targets than hooks**, extra hooks double up on the least-claimed nearest target (B6). With none, every hook SEARCHES and detonates in place at `k = 30` (cancel only).
- **If a hook's target turns immune mid-flight**, it retargets as if destroyed. **If it turns immune while clinging**, the hook detonates at once with splash only.
- **If a target is destroyed mid-cling by another source**, the hook detonates at once at its last position; splash still hits others in range.
- **If a hook's flight would exceed `k = 84`**, it detonates in place at 84 (cancel and splash only). With defaults, the longest flight (53) + cling (18) = 71 never reaches it; only SEARCHING hooks that find a target late can.
- **If `drone_count` is 0**, the bomb is identical. Drones are not read, not consumed and not moved.
- **If a Leech player also has a latched drone ability running**, the two systems are independent: bomb hooks and latched drones may share a target; each source is capped on its own.

**Chain toll and Critical Break**

- **If the chain is 0**, the toll does nothing and emits nothing.
- **If the chain is 1**, the toll leaves it at 1 (B4).
- **If the chain is Frozen** (boss defeated, before the tally), the toll is skipped.
- **If a Critical Break is armed at the accept tick**, the toll is waived. **If it becomes armed later in the bomb** (the player pressed Bomb first and started charging after), the toll has been paid and the break multiplies the reduced count. The intended order is charge first, then bomb.
- **If `cb_armed` is true but the bomb misses the core**, the toll was still waived (an accepted small leak: the player was already in a break position).
- **If a bomb kills the last boss part**, the core's mode change applies next tick (Collision snapshot rule); this tick's remaining bomb events on the core resolve armoured.

**Degenerate strategies and mitigations (Sirlin)**

| Strategy | Why it appeals | Mitigation |
|---|---|---|
| **Bomb spam for permanent invulnerability** | Invulnerable forever | Stock 3 per life; 90-tick lockout (one at a time); the Critical Break needs one of the 3 |
| **Bomb as a chain keeper** (bomb every second to refill the window) | Hits on bomb touches | Bomb hits never count (Rule 9); the window is not refilled by a bomb; the toll takes half the count |
| **Bomb as a boss killer** | Big damage | At most 1,000 per target per bomb (about 4-5% of a boss core, 17-20% of a turret), PART x 60%, no phase can be skipped (B10) |
| **Item farming with bombs** | Thousands of cancelled bullets → gold | Items capped at 100 per bomb, gems only, area cancels give none, the toll lowers the chain used for item value (B9: <= 110,000 per bomb) |
| **Saving every bomb for the Critical Break** | Biggest payoff | Allowed and intended (3 per life); a death resets to 3 anyway, so hoarding past one stage costs nothing but also gives nothing |
| **Dying on purpose to refill bombs** | Bomb refill | Death costs a life, drones, chain, meter (Collision, kits); the refill is 3 bombs only |
| **Bombing during respawn invulnerability** | Free clear | Costs a bomb and the toll for no extra safety; allowed but pointless |
| **Bombing to cancel before the boss pattern's opening** | Skips the opener | Cancel is instant, but the boss keeps firing; the 90-tick invulnerability does not stop new patterns |
| **Stacking 4 players' bombs on a boss core** | 4 x 800 = 3,200 | Under 20% of a 4P core (16,500 x 2.5 = 41,250); B10 guard |

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Slot states, `stage_started`, `stage_cleared`, `boss_started`, `player_died`, continue and drop-in; stores `bombs` per slot; carries `bomb_used` on the event bus. |
| Input and player mapping (2) — GDD | Hard | `consume(slot, BOMB)`; the 6-tick buffer. |
| Bullet manager (3) — GDD | Hard | `request_cancel(area, cause_slot, items)` with the new rectangle area and `items` flag; hurtbox registry and `nearest(pos, filter)`. |
| Player plane (5) — GDD | Hard | Plane position and Active state each tick; the plane's blink uses `blink_remaining`. |
| Collision, damage and lives (6) — GDD | Hard | `request_invuln` on the input tick, damage events with `counts_chain`, hit results; the referee's tick order. |
| Chain tracker (7) — GDD | Hard | `apply_bomb_toll(slot, pct)` and `chain_reduced`. |
| Plane kits (11) — GDD | Soft | Information only: the bomb reads no kit state and never changes the kit; the index dependency on 11 is removed (Amendment 1). |
| Enemy and AI (10) — GDD | Soft | Bomb damage reaches only targetable enemies (Enemy Rule 9; the registry holds only those). |
| Scoring (8) — GDD | Soft | Kill score and items; bomb hits give no HIT points (they do not reach Scoring). |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Critical Break (17) | Hard | `bomb_active`, `bomb_landed`, `cb_armed` query; issues its own cancel. | yes ([GDD](critical-break.md)) |
| Powerups and drops (13) | Hard | Receives cancelled positions + cause slot; owns `items_per_cancel_cap` (100, gems only, no medals). | yes |
| HUD (20) | Hard | `bombs`, `bomb_busy`, `bomb_denied`. | yes ([GDD](hud.md)) |
| Boss and boss parts (14) | Soft | Supplies hurtbox kind (PART or CORE) and may override `bomb_pct`; phase spans >= `4 x bomb_target_cap`. | yes |
| Co-op and Team Chain (18) | Soft | No interface; per-slot stock; item credit by rank. | yes |
| Audio (24), VFX (25) | Soft | Events listed in Visual/Audio; BOMB_DUST global cap 40. | yes ([Audio](audio.md), [VFX](vfx-and-screen-feedback.md)) |
| Era shift (19) | Soft | `EraBombSkin`. | yes ([GDD](era-shift-and-plane-evolution.md)) |
| Accessibility options (28) | Soft | `access.auto_bomb`, `access.deathbomb_grace` (Target tier; need Collision `will_die`). | yes ([GDD](accessibility-options.md)) |
| Sentry, Breaker kits (29) | Hard (Target) | Reuse `BombCore` with a new effect each: Bastion, Backlash (Rules 35-36). | yes ([GDD](plane-kits-sentry-breaker.md)) |
| Tutorial (30) | Soft | Teaches the bomb and the toll; listens to `bomb_used`, `chain_reduced`. | yes ([GDD](tutorial.md)) |

**Amendments to other docs** (exact edits; the main session applies them)

1. **`design/gdd/systems-index.md`**, row 12: Depends-on cell `5, 6, 11` → `1, 2, 3, 5, 6, 7`; Status cell → `**Designed** (pending review) — [GDD](bombs.md)`. Progress tracker: GDDs written +1. "Open items carried over": remove "Bomb design per plane".
2. **`design/gdd/chain-tracker.md`**: add Rule: "`apply_bomb_toll(slot, pct)` from Bombs (12): if the slot is Active, `count > 0` and not Frozen, `count = count - (count x pct) div 100`; the window is not refilled; `last_dropped` is unchanged; emit `chain_reduced(slot, before, after)`. The toll never drops a chain to 0." Add `chain_reduced` to the events list, the Interactions row (Bombs → toll; HUD/VFX/Audio listen to `chain_reduced`) and the Dependencies row (Bombs (12): Hard). Add an Edge Case: "a reduction does not fire milestones; climbing back over 50 / 100 / 200 fires them again, as after a drop." Add AC: `count 187`, toll 50 → 94, window unchanged, `boss_peak` unchanged.
3. **`design/gdd/collision-damage-lives.md`**: (a) Rule 10 and Interactions: damage events carry `counts_chain` (default true); source BOMB sends `false`; C5 `counts = (hit OR destroyed) AND shooter Active AND counts_chain`. (b) Rule 13 last sentence: replace "Bomb damage counts per target touched (rule owned by Bombs 12)" with "Bomb damage never counts for the chain (Bombs 12 Rule 9)." (c) Open Question 4 closed: bomb invulnerability 90 ticks, `bomb_part_pct` 60, no chain counts. (d) `blink_remaining` (Plane kits Amendment 3c) includes the bomb request. (e) AC-33 data lint unblocked for bombs. (f) Hit results to a BOMB source carry the target class so Bombs can emit `bomb_landed`.
4. **`design/gdd/bullet-manager.md`**: (a) F9 and Rule 13: a cancel area may also be an **axis-aligned rectangle** `(x0, y0, x1, y1)`; the rule is `|px - cx| <= half_w + r_vis` and `|py - cy| <= half_h + r_vis`. (b) Cancel requests get a flag `items` (default true); with `items = false` the bullet is removed with reason CANCEL_NOITEM and no score item. (c) Interactions row for Bombs: "cancel requests (full screen with items at the press; rectangles / circles without items afterwards)". (d) Add AC for the rectangle edge (bomb column).
5. **`design/gdd/game-events-and-session.md`**: Rule 4 slot fields add `bombs` (0-5); add bombs to the reset lists (run start, continue, drop-in: `bomb_start`); add `set_bombs(slot, n)` as Bombs-only; add `bomb_used(slot)` to the signal set (Rule 13); add "stage carry-over: `bombs` carries; `stage_started` tops up to the floor (Bombs 12)" to Rule 9.
6. **`design/gdd/input-and-player-mapping.md`**: Rule 17 note: "Bombs calls `consume(slot, BOMB)` every tick it is IDLE and has stock; it does not consume while busy or at 0 stock, so a press expires after 6 ticks. On `stage_started` it consumes once to purge." Update the Bombs row in Dependencies: no longer provisional.
7. **`design/gdd/player-plane.md`**: Rule 9: Bomb goes to Bombs (12); Bombs reads the plane's position at the accept tick. V7 blink: bomb invulnerability blinks (non-laser). Interactions row for Bombs: "plane position, Active state".
8. **`design/gdd/plane-kits-lancer-leech.md`**: Open Question 7 closed: "Bombs read no kit state; they do not use parked drones or drone positions, so Rule 40's snapshot is not needed by Bombs. Lancer's bomb and Leech's bomb hooks are independent of `drone_count`." Rule 40 snapshot remains for Critical Break (17). The Bombs row in Interactions: "← `bomb_started(slot)` (info only)" stays.
9. **`design/gdd/game-concept.md`**: §5 "Bomb designs per plane: TBD" → "Decided (Bombs 12): Lancer = Lance Sweep (a light column that holds, then sweeps both ways); Leech = Barb Burst (four seeking hooks that cling and burst). 3 bombs per life, topped up at each stage; each bomb costs half the chain count unless a Critical Break is armed." §4/§9 open items: remove "Bomb design for each plane".
10. **`design/art/art-bible.md`**: (a) §7.4 banner rule: "Critical Break (17) issues its own full-screen cancel on the trigger tick before the banner; Bombs clears the field only on the press tick." (b) §8.3: add sprite sets: bomb column tile 56x16, Leech bomb hook 12x12, detonation burst 48x48, shockwave ring (cream/orange). (c) §4.6: confirm Tracer Orange `#FF8A1F` for bomb FX. (d) §7.2 bomb icon: already "pictogram on Tracer Orange tile"; note the icon dims to 60% while busy.
11. **`design/gdd/coop-and-team-chain.md`**: Rule 9 add: "Bomb items go to the first bomber in rank order (Bombs 12 Rule 31); bomb hits never refresh `boss_hit_left` (Bombs Rule 32)."
12. **`design/gdd/enemy-and-ai.md`**: Dependencies row for Bombs (12): GDD exists; interface "no events needed; bombs read the hurtbox registry".
13. **`design/gdd/scoring.md`**: Open Question 3 note: "Bomb cancel items are gems, capped at `items_per_cancel_cap` per bomb; area cancels give no items (Bombs B9)." No formula change.
14. **`design/gdd/localization.md`**: glossary keys `bomb.name`, `bomb.lancer.name`, `bomb.leech.name` (English "Bomb", "Lance Sweep", "Barb Burst"; Bengali by the translator; Open Question 4 translate vs transliterate).

**Bidirectional check:** Session, Input, Bullet manager, Player plane, Collision, Chain tracker, Plane kits, Co-op and Enemy already list or are listed by Bombs, or are amended above. Undesigned downstream systems (13, 14, 17, 19, 20, 24, 25, 28, 29, 30) must list Bombs when written. *(2026-11-03, wave 3b: all downstream systems except Sentry/Breaker kits (29), Tutorial (30) and Touch (31) now have GDDs.)*

## Tuning Knobs

All values live in `data/bombs/bomb_rules.tres` (shared), `data/bombs/lancer_bomb.tres`, `data/bombs/leech_bomb.tres` and `data/bombs/skins/*.tres`; none is hardcoded. Categories: **F** feel, **C** curve, **G** gate.

**Shared**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `bomb_start` (G) | 3 | 2-5 | 2: no spare for the Critical Break | 5: bombs stop being a decision | `bomb_stage_floor`, B1 |
| `bomb_max` (G) | 5 | 3-5 | Below `bomb_start`: lint fails | Over 5: HUD shows `+N` | HUD (max 5 icons) |
| `bomb_stage_floor` (G) | 3 | 1-5 (<= `bomb_max`) | 1: stage 2 starts nearly empty; break unlikely | 5: stock is effectively unlimited | Death reset; Critical Break rate |
| `bomb_boss_floor` (G) | 0 | 0-2 | — | 2: the "save one bomb for the break" decision is gone | `boss_started` (Chain / Wave director) |
| `bomb_invuln` (F) | 90 ticks | 60-150 | Under ~1 s: cannot cross a curtain | Over ~2.5 s: free progress through patterns | `bomb_lockout`; Collision timer cap 240 |
| `bomb_lockout` (G) | 90 ticks | 85-150 | Below the longest effect (85): lint fails | Slow second bomb in a long fight | `bomb_invuln` (keep equal), `hook_life_cap` |
| `bomb_chain_toll_pct` (C) | 50 | 0-75 | 0: bombs cost only stock; too safe | Over 75: bombs feel like deaths | B4, Critical Break pay (it is waived there) |
| `bomb_target_cap` (C) | 1,000 | 600-1,500 | Bombs barely scratch mediums (1,200+ hp) | Bombs become boss damage tools | B7, B10, boss hp |
| `bomb_part_pct` (C) | 60 | 40-100 | Parts shrug off bombs | Bombs strip parts too fast | Collision C4, Boss part hp |
| `phase_guard_mult` (lint) | 4 | 2-8 | — | Boss phases forced long | Boss (14) phase spans |

**Lancer**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `hold_ticks` (F) | 24 | 12-36 | Column vanishes before it feels planted | Hold dominates; sweep irrelevant | B5, `effect_ticks` (<= 72) |
| `sweep_half_w` (F) | 28 px | 20-40 | Misses targets; too thin to read | Covers too much of the screen | B5, enemy `r_h` |
| `sweep_speed` (F) | 8 px/tick | 6-12 | Sweep too slow (`effect_ticks` > 90) | Targets get 1 hit | `effect_ticks` |
| `damage_interval` (C) | 4 | 3-6 | Over-cap hits on big hurtboxes | Few hits on small targets | B5, cap |
| `lancer_damage` (C) | 100 | 60-150 | Under 20 fails the armour lint | Bomb outweighs the Leech's | B7, B8 |

**Leech**

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `hook_count` (C) | 4 | 2-6 | Few targets | Screen full of hooks | B6, cap |
| `hook_speed` (F) | 14 px/tick | 10-16 | Slow, effect long | Instant | `hook_life_cap` |
| `cling_ticks` (F) | 18 | 6-30 | No fuse readable | Over 0.5 s: bomb feels slow | CB timing (Rule 29) |
| `hook_damage` (C) | 200 | 120-300 | Weaker than Lancer | Lone core exceeds the cap | B7, B8 |
| `splash_pct` (C) | 50 | 0-75 | Clusters not rewarded | Cluster wipe too easy | `hook_damage` |
| `splash_radius` (C) | 40 px | 24-64 | Splash never connects | Hits half the screen | Enemy `r_h` |
| `blast_cancel_radius` (C) | 96 px | 48-128 | Little cancel | Blast clears everything | Bullet manager F9 |
| `search_ticks` (G) | 30 | 10-45 | Hooks fizzle at once | Hooks hover | `hook_life_cap` |
| `hook_life_cap` (G) | 84 | 60-88 | Long flights cut | Past the lockout: lint fails | `bomb_lockout` |

**Owned elsewhere (pointers, not duplicated):** `buffer_ticks` 6 → Input (2) · `respawn_invuln` 120 → Collision (6) · `armour_damage_min` 20 → Collision (6) · `chain_cap`, `chain_window` → Chain (7) · `items_per_cancel_cap`, item kinds → Powerups (13) · `factor_cap_count` 500, `factor_step` 50, `item_base` → Scoring (8) · `play_top` → art bible §7.2 · player count / rotation → Co-op (18) · boss hp / phase spans → Boss (14).

**Rationale for the defaults:** 3 bombs = two for survival and one for the Critical Break; 90 ticks equals the lockout and gives one clear beat; toll 50% costs 2 s of rebuilding at chain 180 and 8 s at chain 800 (cost grows with what is at risk, B4); damage numbers are about 1 s of `ref_dps` 800 (4-5% of a boss core) so bombs stay a survival tool (B8); the 1,000 cap (not the per-bomb damage) is what the lint and the phase guard check.

## Visual/Audio Requirements

> Source of truth: `design/art/art-bible.md` (AB). Draw layers per AB §6.8 as in Bullet manager V5: enemies 4, air FX 5, **player shots / beams / drones / score items 6**, planes 7, **enemy bullets 8**, hitbox dots 9, Critical Break frame 10, HUD 11. **Bullets always win**: nothing here draws above layer 8. **The only screen flash is the Critical Break**: no bomb effect flashes. Never use Void Indigo / Ink for bomb art; never use enemy shapes (orb, rice, needle, ring). Bomb colour is **Tracer Orange `#FF8A1F`** (AB §4.1, §4.6) with the player-shot palette (`#FFB82E` fill, `#FFF2B0` core). All art is sprites (AB bans `draw_line` / `draw_circle` for lasers). Numbers marked (P) are unplaytested.

**V1. Shared (press tick)**
- **Shockwave ring** (layer 5): a 2 px ring in Tracer Orange fading to Cream, centred on the plane, diameter 36 → 480 px over 12 ticks, opacity 100% → 0%. No Ink outline. Not bullet-shaped (a thin full ring, larger than 24 px: AB §6.8 rule 3).
- **Cancel puffs** (layer 5): gold / cream, 3-5 frames at 20 fps, sampled to at most 40 per sweep (Bullet manager V6), within the 150-particle cap (AB §8.6). Cancelled bullets vanish instantly (Bullet manager V6: no fade).
- **Score items** from the `k = 0` cancel: art and motion owned by Powerups (13) (Ember Gold diamonds, layer 6).
- **Plane:** the invulnerability blink is Player plane V7 (`blink_remaining`); the bomb adds no extra mark on the plane. The blink ending is the tail cue.
- **No luma flash:** across a 10 s capture with four simultaneous bombs no frame's mean luma differs from the previous frame by more than 8% (AC-52).

**V2. Lancer: Lance Sweep** (layer 6, below planes and bullets)
- **Column tile 56 x 16 px**, 4 frames at 20 fps (a scroll of the bright core, no brightness strobe), vertically repeated from `play_top` to y = 640: 4 px edge `#FF8A1F`, 20 px fill `#FFB82E` at 60% opacity (so enemies read through it), 8 px core `#FFF2B0` at 100%, 20 px fill, 4 px edge. No outline.
- **Ignite:** at `k = 0..2` the column widens 14 → 56 px (3 ticks). Hold: the column is steady. Sweep: each moving column has a 2 px Cream leading edge and sheds 2+ px warm dust (at most 40 live particles; VFX class BOMB_DUST, a **global** cap of 40 shared by all bombs, VFX 25 *(2026-11-03, wave 3b)*).
- **Ending:** a column that leaves the field is simply gone off-screen (no shrink needed).
- **Ground and enemies:** the column draws above enemies (layer 4) and below planes (7) and bullets (8).

**V3. Leech: Barb Burst**
- **Bomb hook 12 x 12 px** (larger than the 10 x 10 drone): Tracer Orange `#FF8A1F` head with a notched claw silhouette (never a disc), 2 px Cream core, 2 frames at 10 fps. Flight trail: 4 px warm, 2 frames. The hook faces its target.
- **Cling (fuse):** a 3-frame clamp animation at 20 fps, then the hook body swells 12 → 14 → 16 → 18 px at the 6th, 12th and 18th tick of the cling, so the fuse is readable without flashing. It rides the target with an 8-16 px offset toward the plane.
- **Detonation:** 5-frame cluster burst, 48 x 48 px, 20 fps (cream / orange / gold), layer 5; plus a shockwave ring of the cancel radius (192 px diameter) over 8 ticks, 2 px, no Ink.
- **SEARCHING hook:** the claw hovers with a slow 1 px bob (2 Hz); it never looks like an enemy bullet.
- **Drones:** unchanged; they dock and fire as normal (bomb hooks are separate sprites).

**V4. Era skins** (Rule 34): per era, the column and hook art recolour within the warm range and change pylon / claw / lens style (AB §5.5); at most 2 bolt-on sprites per plane per era (Player plane V8); no number changes.

**V5. HUD icon:** bomb pictogram on a Tracer Orange 14 x 14 tile (AB §7.6; language-neutral). While busy (ACTIVE / TAIL) the icon row dims to 60% (shape unchanged), so ready vs busy is readable in greyscale as brightness and in colour-blind modes as the dimmed outline.

**A1. Audio** (audio-director to confirm (P))

| Event | Spec | Limit |
|---|---|---|
| Bomb accept | One rising stinger per bomb | 1 per slot per bomb; in the 8-voice bullet pool |
| `k = 0` cancel | The Bullet manager "large" cancel cue (A2) | 1 per cancel request; rolling cancels play none |
| Lancer hold / sweep | One low hum, pitch falls as the columns leave | 1 voice per slot; at most 2 globally |
| Leech launch | One "pop-out" per bomb | 1 per bomb |
| Hook clamp | Soft click | At most 2 per 6 ticks globally |
| Hook detonation | Short thud | At most 2 per 6 ticks globally; priority below cancel |
| `bomb_denied(NO_BOMBS)` | Quiet low blip | 1 per press |
| `bomb_denied(BUSY)` | None (the HUD dim is the cue) | — |
| Stage-start top-up | Soft chime | 1 per slot |
| Invulnerability end | None (the blink is the cue; a sound would mask bullet cues) | — |

Voice caps: bomb SFX at most 3 voices per slot; bullet-related SFX share the 8-voice pool; priority cancel > Warp cue > enemy fire > player fire; bomb SFX obey it. No sound for the end of invulnerability.

> Drafted from the art bible and Bullet manager V5/V6 by game-designer under auto-approve (2026-11-03). `art-director` and `audio-director` not consulted.

📌 **Asset Spec** — run `/asset-spec system:bombs` to produce per-sprite specs (column tile, hook, burst, ring, HUD icon, per-era skins).

## UI Requirements

The HUD (20) draws the bomb stock per player slot. Data Bombs supplies each tick:

| Data | Use |
|---|---|
| `bombs(slot)` | Icon row: up to 5 icons (14 x 14 plated, AB §7.2), overflow as `+N` |
| `bomb_busy(slot)` | Dim the icon row to 60% while ACTIVE / TAIL |
| `bomb_denied(slot, reason)` | `NO_BOMBS`: the row shakes 2 px for 8 ticks (not faster than 2 Hz) with the quiet blip. `BUSY`: no UI |
| `bombs_changed(slot, old, new)` | A spent icon plays a 3-frame break; a refill adds icons one every 6 ticks |

- **No text, no timers:** the icon row, its dim and the plane's blink carry all the information (Bengali and English share the same icons). Hit-tint and flash rules (Collision V2) do not apply to the bomb.
- **Accessibility:** ready vs busy is brightness and shape, not colour alone. The "Reduce flashing" option (`access.reduce_flashing`) needs nothing here, because the bomb has no flash; the shockwave ring and column scroll remain.
- **Debug tools:** overlay of bomb state, `k`, `x0`, column rectangles, hook states and targets, per-target `sent` damage, cancel requests (area, items flag), toll applied; cheats "bombs set" and "bomb now".

📌 **UX Flag**: run /ux-design for the per-slot plane panel (lives, bombs, drone count, kit bar) before writing epics.

## Acceptance Criteria

Defaults used: `bomb_start` 3, `bomb_max` 5, `bomb_stage_floor` 3, `bomb_boss_floor` 0, `bomb_invuln` 90, `bomb_lockout` 90, `bomb_chain_toll_pct` 50, `bomb_target_cap` 1,000, `bomb_part_pct` 60; Lancer `hold_ticks` 24, `sweep_half_w` 28, `sweep_speed` 8, `damage_interval` 4, `lancer_damage` 100; Leech `hook_count` 4, `hook_speed` 14, `arrive_r` 14, `cling_ticks` 18, `hook_damage` 200, `splash_pct` 50, `splash_radius` 40, `blast_cancel_radius` 96, `search_ticks` 30, `hook_life_cap` 84; `buffer_ticks` 6; `armour_damage_min` 20; `respawn_invuln` 120; `items_per_cancel_cap` 100 (Powerups stub); `factor_cap_count` 500, `factor_step` 50; canvas 360x640; `play_top` 48; 60 ticks/s. Slots 0-indexed.

**Test setup:** the logic lives in a plain `RefCounted` class (working name `BombCore`, with `LanceSweep` and `BarbBurst` effects) with no nodes, no drawing, no `delta` and no RNG. `tick()` advances one 1/60 s step and keeps its own tick counter. Inputs before a tick: `set_config(res)`, `set_plane(slot, pos, state)`, `set_session_state(state)`, `set_bombs(slot, n)`, `set_targets([{id, gen, pos, r_h, mode, kind}])` through an injected stub registry (`kind` ∈ SMALL, MEDIUM, LARGE, PART, CORE) that also answers `nearest(pos, filter)`, `set_input(slot, pressed, buffered_age)` through a stub `consume`, `set_chain(slot, count, frozen)`, `set_cb_armed(slot, bool)`, `deliver_hit_results([...])`, `plane_died(slot)`, `stage_started()`, `stage_cleared()`, `boss_started()`, `forfeit(slot)`. Outputs after a tick: `bombs(slot)`, `state(slot)`, `k(slot)`, an ordered `log` (`bombs_changed`, `invuln_request(slot, ticks)`, `chain_toll(slot, pct)`, `cancel_request(area, items, cause_slot)`, `damage_event(id, gen, slot, damage, BOMB, seq, counts_chain)`, `bomb_started`, `bomb_denied(reason)`, `bomb_landed`, `bomb_used`), hook states and positions, `bomb_active(slot)`, `bomb_busy(slot)`, `warnings`, `state_hash()`. A stub Collision applies C3/C4 for the integration tests. Tests: `tests/unit/test_bombs_core.gd`, `test_bombs_lancer.gd`, `test_bombs_leech.gd`, `test_bombs_balance.gd` (`extends SceneTree`, like `tests/unit/test_chain_tracker.gd`); integration in `tests/integration/test_bombs_*.gd` using real `BulletField`, `CollisionReferee`, `ChainTracker`, `PlaneCore`; perf in `tests/perf/bombs_bench.tscn`. Every number is read from `data/bombs/*.tres`, never literals. Position asserts +/-0.01 px.

Tags: [Unit] pure logic · [Integration] real BulletField / referee / ChainTracker / PlaneCore · [Perf] REF-PC and REF-WEB · [Manual] needs a human.

### Stock (Rules 2-3, B1)

- **AC-01 [Unit] (Rule 3):** a run start, a continue accepted and a drop-in confirmed each set `bombs` to 3; spending three bombs (with lockouts between) leaves 0 and no 4th accept.
- **AC-02 [Unit] (Rule 3, death):** `bombs` 1 and `plane_died` → 3; `bombs` 0 → 3; a debug-set 5 → 3.
- **AC-03 [Unit] (Rule 3, stage floor):** `stage_started`: 1 → 3, 3 → 3, a debug-set 5 → 5 (floor never lowers). An Alive and a Dead slot are topped up; Continue, Inactive, Empty and Selecting slots are unchanged.
- **AC-04 [Unit] (Rule 3, boss floor):** `bomb_boss_floor` 1 with `bombs` 0 and `boss_started` → 1; with the default 0 → unchanged.
- **AC-05 [Unit] (Rule 2, no sources):** over 3,600 ticks with scripted pickups, extends, 1-ups, kills, score awards and a Critical Break, `bombs` never rises except by Rule 3 events.
- **AC-06 [Unit] (B1 clamp):** `set_bombs(9)` → 5; `set_bombs(-1)` → 0.

### Press, lockout, deathbomb (Rules 4-6, 14, 17, B2, B3)

- **AC-07 [Unit] (Rule 5):** slot 0 Active, IDLE, `bombs` 3, fresh press on tick 100 → `bombs` 2; in `log` order on tick 100: `bombs_changed(0, 3, 2)`, `invuln_request(0, 90)`, `chain_toll(0, 50)` (chain > 0), `cancel_request(FULL_SCREEN, items = true, 0)`, `bomb_started`, `bomb_used`; state ACTIVE, `k` 0.
- **AC-08 [Unit] (Rule 6, denials):** `bombs` 0 → fresh press gives `bomb_denied(NO_BOMBS)`, no state change, no requests. During ACTIVE or TAIL → `bomb_denied(BUSY)`, `bombs` unchanged. Plane FlyIn / Dying / Absent → no event and no `consume` call.
- **AC-09 [Unit] (B2, lockout and buffer):** accept at 100 → IDLE at 190; a fresh press at 189 → `BUSY`; a press at 185 is accepted at 190; a press at 183 (7 ticks) is not; no bomb starts at 190 unless the stub `consume` returns true.
- **AC-10 [Unit] (Rule 4, no purge):** while ACTIVE / TAIL, and while `bombs` = 0, `BombCore` never calls `consume`; the stub buffer entry is untouched.
- **AC-11 [Unit] (stage start):** `bombs` 0 with a stub buffered press 3 ticks old and `stage_started` → `bombs` 3, the buffered press is consumed (purged), and no bomb starts on that or the next tick.
- **AC-12 [Integration] (Rule 17, deathbomb):** real `CollisionReferee` and `BulletField`: an orb hit for slot 0 on tick T plus a bomb press on T → no life lost, no clear (the `request_invuln` is in step 1 and the cancel runs before the hit pass). A press on T+1 → life lost on T, the press ignored, no bomb spent.
- **AC-13 [Unit] (B3):** respawn timer 70 at tick T plus a bomb → 90, hittable at T+90; a laser request of 13 on T → 90; a timer of 100 stays 100.
- **AC-14 [Integration] (Rule 7, laser):** `LancerKit` laser active ticks 100-200, bomb on 150 → the laser, its meter, `charge_active` and `ability_speed` 90 are unchanged on 149, 150, 151; `invuln_remaining` = max(90, 13) = 90 on 150.
- **AC-15 [Unit] (Rule 7, kit independence):** the same scripted bomb with `drone_count` 0 and 4, kit in IDLE and in a deployed ability → identical `log` and `state_hash()`.

### Chain toll (Rule 12, B4)

- **AC-16 [Unit] (B4 table):** toll 50: before 187 → 94, 150 → 75, 99 → 50, 3 → 2, 2 → 1, 1 → 1, 0 → 0 (no call), 999 → 500. Toll 75, 187 → 47. Toll 0 → no `chain_toll` call.
- **AC-17 [Unit] (Rule 12, waivers):** `cb_armed(0)` true → no toll; chain Frozen → no toll; toll sent exactly once per bomb (only on `k = 0`).
- **AC-18 [Integration] (real ChainTracker):** count 187, `window_left` 30, bomb → count 94, `window_left` 30, `last_dropped` unchanged, `boss_peak` unchanged, one `chain_reduced(0, 187, 94)` and no `chain_dropped`; climbing back over 100 fires `chain_milestone(0, 100)` again.

### Damage, cap and results (Rules 8-11, B7)

- **AC-19 [Unit] (Rule 10, parts):** Lancer event on a PART = 60, on a CORE = 100; Leech hook on a PART = 120, splash on a PART = 60; an immune target receives no event.
- **AC-20 [Unit] (Rule 9):** every damage event has `counts_chain = false` and source BOMB.
- **AC-21 [Integration] (Rule 9, real Collision and Chain):** a bomb destroys a SMALL (20 hp) → one `kill_credit(0, SMALL)`, zero `chain_hit(0)`; a hit on a normal 3000-hp core → result *hit*, zero `chain_hit`, and `bomb_landed` emitted; a hit on an immune target → no event and no `bomb_landed`.
- **AC-22 [Unit] (B7 cap):** a target with `sent` 900: a 200 hook event is skipped; a 100 Lancer event is sent (1,000), the next 100 is skipped. `sent` resets on the next bomb.
- **AC-23 [Unit] (armour):** armoured core 25%: Lancer 100 → dealt 25, hook 200 → dealt 50; PART 60 → 15. `bomb_landed` fires on each (result *hit*).
- **AC-24 [Unit] (lint):** every bomb damage value and its x 60% form in the `.tres` is an integer >= `armour_damage_min`; the data test fails for a `lancer_damage` of 30 (x 60% = 18).
- **AC-25 [Unit] (Rule 10, pass-through):** an immune boss part and a normal target in the same Lancer column → only the normal target takes events.
- **AC-26 [Unit] (C6 ordering):** a bomb event, a laser event and a bullet on one 30-hp target in 100 shuffled orders → the bomb resolves first (Collision AC-20); the same-tick second bomb event from the same slot is not sent (one event per target per tick).

### Lancer (Rules 18-23, B5)

- **AC-27 [Unit] (B5 `effect_ticks`):** `x0` 180 → 49; `x0` 8 → 71; `x0` 0 → 72; `x0` 360 → 72; the plane at x = -5 or 400 is clamped to 0 / 360.
- **AC-28 [Unit] (B5 core):** a core at x = 180, `r_h` 12, `x0` = 180: events on ticks 0, 4, 8, 12, 16, 20, 24 (7 x 100 = 700), none on 28; at dx = 39: 6 hold events + k = 24, 28, 32 = 9 events (900).
- **AC-29 [Unit] (B5 medium):** a medium at `x0 + 100`, `r_h` 14: events on k = 32, 36, 40 only (300); none during the hold phase.
- **AC-30 [Unit] (B5 dedupe):** a target within both columns on k = 24 gets one event; the plane moving 60 px right during the hold leaves the column at `x0`.
- **AC-31 [Unit] (Rule 22):** `x0` 180: `k = 0` full-screen cancel (items true); rolling area cancels on ticks 1-23 (one rectangle each) and 24-48 (two each) → 23 + 50 = 73 requests, all `items = false`; none on tick 49.
- **AC-32 [Unit] (states):** `x0` 180: ACTIVE on ticks 0-48, TAIL 49-89, IDLE at 90; `bomb_active` false from tick 49; `bomb_busy` true until 89.
- **AC-33 [Integration] (real BulletField):** a rectangle cancel at `x0` ± 28: an orb at `x0 + 32.5` (28 + `r_vis` 4.5) is cancelled, at `x0 + 32.51` survives; the rectangle gives zero items (Amendment 4).

### Leech (Rules 24-27, B6)

- **AC-34 [Unit] (B6 targets):** plane (180, 500), T1..T5 as in B6 → hooks take [T1, T2, T3, T4]; with T1 and T2 only → [T1, T2, T1, T2]; with T1 only → all T1; with none → all SEARCHING.
- **AC-35 [Unit] (B6 flight):** a target 280 px away: the hook moves on ticks 1-19, clings from tick 20, detonates on tick 38 with a 200 event; the 734.3 px diagonal clings at tick 53 and detonates at 71.
- **AC-36 [Unit] (splash):** blast at B; another target `r_h` 16 at 56 px → splash 100; at 56.01 px → none; the primary target takes no splash; a PART splash = 60.
- **AC-37 [Unit] (SEARCHING):** no targets at launch → all SEARCHING; one appears on tick 10 → that hook flies; the others detonate in place on tick 30 with a circle cancel and no damage event.
- **AC-38 [Unit] (life cap):** a hook that starts SEARCHING at tick 0, finds a target at tick 29 (53 px of flight) → detonates in place at tick 84 if not arrived; `bomb_active` false after the last detonation; IDLE at 90.
- **AC-39 [Unit] (target lost):** the primary dies during the cling on tick 30 → the hook detonates on tick 30 at its last position, splash only; during flight it retargets the same tick by the B6 rule.
- **AC-40 [Integration] (detonation cancel):** a circle of 96 px, no items: an orb at 100.5 px is cancelled (96 + `r_vis` 4.5), at 100.51 survives; 0 items.
- **AC-41 [Unit] (lone core):** one eligible armoured (25%) core: 4 events of 200 → 4 x dealt 50 = 200 hp lost; a normal core loses 800; `sent` = 800.

### Chain, score, Critical Break (Rules 11, 28-29, B8-B10)

- **AC-42 [Unit] (Rule 28):** `bomb_landed(slot, core_id, CORE, tick)` is emitted for each *hit* result on the core and not for *ignored*; with a stub CB reading `charge_active` = true on a landing tick the break condition is observable.
- **AC-43 [Unit] (B8, B10 data tests):** from the `.tres`: max events per target (Lancer 10 at large `r_h`, 9 at `r_h` 12, Leech 4 hooks + splash) x damage <= `bomb_target_cap`; lone-core ratio Lancer 700 / Leech 800 = 0.875 in [0.8, 1.2]; every Boss phase span in the boss data (when it exists) >= `4 x 1,000`.
- **AC-44 [Unit] (Rule 34):** for each `EraBombSkin` of both bombs, the hash of all numeric bomb data is identical; skins differ only in sprite / sound ids and tint.
- **AC-45 [Unit] (B9):** Scoring F3 stub: 100 gems at count 500 → 110,000; at count 40 → 10,000; at 237 → 50,000; the bomb's `k = 0` cancel yields at most `items_per_cancel_cap` items; rolling cancels yield 0.

### Co-op and lifecycle (Rules 16, 30-33)

- **AC-46 [Unit] (stock per slot):** slots 0 and 1: slot 0 bombs → slot 0 stock 2, slot 1 stock 3 and no invulnerability for slot 1.
- **AC-47 [Integration] (rank order, items):** tick 601 (601 mod 4 = 1), slots 0 and 1 press, 1,350 enemy bullets → slot 1 is processed first, receives `min(1350, 100)` = 100 items; slot 0 gets none. Tick 600: slot 0 first.
- **AC-48 [Integration] (no friendly fire, Rule 33):** real `BulletField`, 4 planes, a Lancer bomb and a Leech bomb → zero hits on any plane from bomb effects; lives unchanged. Bomb events never set `boss_hit_left` (Chain).
- **AC-49 [Unit] (Rule 16):** `stage_cleared` mid-bomb on tick 20 → no damage, cancel or hook event after tick 20, hooks removed, IDLE, `bombs` unchanged; `forfeit(slot)` the same; `plane_died` → IDLE and `bombs` = 3; a pause of 30 s real time leaves `k` and hook positions unchanged.

### Determinism and performance

- **AC-50 [Unit] (determinism):** a scripted 3,000-tick scenario (2 slots, Lancer and Leech; 6 bombs; moving targets; 1 death; 1 stage clear) run twice and at 60 / 30 / 144 fps adapters → `state_hash()` equal every tick.
- **AC-51 [Perf] (budget):** 4 `BombCore` (2 Lancer + 2 Leech) active, 64 hurtboxes → total bomb pass <= **0.10 ms** p99 on REF-PC and REF-WEB; <= 2 cancel requests per slot per tick (<= 4 for Leech detonations on one tick); no allocation per tick after warm-up (memory growth < 1 MB over 10 minutes). With 2,000 live enemy bullets refilled each tick by emitters, the Bullet manager update including the bomb cancels stays <= 2.5 ms p99 (Bullet manager AC-40).
- **AC-52 [Unit] (data lint):** no tuning literal in `src` bomb code; no `delta`, `randf` / `randi`, or `Input.` in the core class; every bomb number is loaded from the `.tres`; `bomb_lockout >= hook_life_cap + 4` and `>= effect_ticks` (72).

### Manual (evidence in `production/qa/evidence/bombs/`)

- **AC-53 [Manual] (V1 no flash):** a 10 s capture with four simultaneous bombs: no frame's mean luma differs from the previous frame by more than 8%; no effect draws above an enemy bullet in any frame (5 bullets crossing a column and a blast circle); colours are warm only (hex check); no Void Indigo / Ink in bomb sprites.
- **AC-54 [Manual] (identity):** after 10 minutes on each plane, at least 8 of 10 testers describe the Lancer bomb as a "sweeping beam / column" and the Leech bomb as "seeking / exploding hooks" without being told.
- **AC-55 [Manual] (survival tool):** 5 testers x 3 boss attempts: in at least 60% of bomb uses, Collision ignored at least one lethal contact within the 90 ticks (telemetry `bomb_saved`); no tester reports bombs as "the way to kill the boss".
- **AC-56 [Manual] (end of invulnerability):** 10 s clips of bombs with a mix of curtains: at least 90% of clips, viewers identify within 0.5 s when the plane is mortal again from the plane's blink.
- **AC-57 [Manual] (Critical Break feasibility):** with a stub Critical Break (charge active + bomb landing on the core), 10 attempts each: Lancer (laser held first) triggers in at least 9 of 10; Leech (focus shot held until the hooks burst) in at least 8 of 10.
- **AC-58 [Manual] (HUD):** the bomb icon row: 5 icons shown, overflow `+N`, dim to 60% while busy, readable in greyscale, NO_BOMBS shake <= 2 Hz; in Bengali and English the HUD is identical.

> Criteria drafted by game-designer (qa-lead not consulted, auto-approve). Manual pass bars are proposals.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Is the 50% chain toll the right price? Alternatives: 25%, or none (stock only). The knob exists (`bomb_chain_toll_pct`, 0 disables it). Needs playtest of "bomb at chain 180 / 800". | Designer, playtest | First playable boss |
| 2 | ~~Deathbomb grace: same-tick only (this GDD) vs a 3-6 tick grace after the lethal hit. Needs Collision to defer a death; an accessibility option candidate.~~ **Closed 2026-11-03:** MVP stays same-tick; `access.deathbomb_grace` 0/3/6 is a Target-tier ASSIST (marks the run PRACTICE) needing Collision `will_die(slot)` (accessibility-options.md Rule 25) | Collision (6), Accessibility (28), playtest | Vertical Slice |
| 3 | ~~Auto-bomb accessibility option ("spend a bomb when a hit would be lethal"): needs a pre-hit callback from Collision. Recommended off and absent in the MVP.~~ **Closed 2026-11-03:** `access.auto_bomb` is a Target-tier ASSIST (run PRACTICE), absent in the MVP, needing Collision `will_die(slot)` (accessibility-options.md Rule 25) | Accessibility (28), Collision (6) | Accessibility GDD |
| 4 | Should a boss part killed by a bomb give the +5 part-kill chain bonus (Chain Rule 2)? Recommended **no**, to keep bombs out of the chain. | Boss (14), Chain (7) | Boss GDD |
| 5 | ~~Powerups (13): confirm cancel items are gems, `items_per_cancel_cap` 100 applies to a bomb's `k = 0` cancel, and area cancels with `items = false` are allowed.~~ **Closed 2026-11-03:** confirmed by Powerups (13) Rules 12-14: cancel items are gems, the cap of 100 applies per cancel request (the bomb's `k = 0` cancel), area cancels with `items = false` give none. | Powerups (13) | Powerups GDD |
| 6 | Bullet manager amendments (rectangle area, `items` flag, `CANCEL_NOITEM` reason): cost of up to 8 area cancels per tick in GDScript with 2,000 bullets (mitigated by the `k = 0` clear). | Bullet manager (3), lead-programmer | Before the bombs epic |
| 7 | ~~Critical Break (17): `cb_armed(slot)` query and `bomb_landed` contract; its own cancel before the banner; is Leech's break too easy relative to the Lancer's meter, or too slow (about 1 s of holding Fire until the hooks burst)?~~ **Closed 2026-11-03:** contract in critical-break.md Rules 9-12 and F1; CB issues its own cancel; a committed bomb needs no charge at landing, so Leech can press Bomb while focused shots land and release Fire (hooks bite at `t0 + 19..71`). Parity risk tracked in CB Open Question 1. | Critical Break (17) | CB GDD |
| 8 | ~~Should unused bombs pay a stage-end bonus? Recommended **no** (the Critical Break is the reward for saving one; it would push hoarding over survival).~~ **Closed 2026-11-03:** no stage-end bomb bonus (stage-end-tally.md). | Scoring (8) | Tally GDD |
| 9 | Boss data: phase spans >= 4,000 hp (B10), optional `bomb_pct` per part, whether any phase is bomb-immune. | Boss (14), Boss power budget (15) | Boss GDD |
| 10 | Is 3 bombs per life with a stage floor of 3 right? `bomb_boss_floor` (default 0) is the lever if the Critical Break is too rare. | Designer, playtest | MVP playtest |
| 11 | Names and glossary: "Lance Sweep" / "Barb Burst" in Bengali (translate or transliterate). | writer + translator | Glossary draft |
| 12 | Lancer bomb world-anchored vs following the plane during the hold. | Playtest | First playtest |
| 13 | Art: art bible amendments (bomb sprite sets, §7.4 banner rule, icon dim). | art-director | Before plane art |
| 14 | ~~Audio caps and the stage-start chime.~~ **Closed 2026-11-03:** BOMB pool 6, Lancer hum capped at 2 globally (audio.md) | audio-director | Audio pass |
| 15 | Godot 4.7: tiled vertical sprites for the 56 px column and the cost of 8 columns in 4P (unverified; same as Plane kits Open Question 10). | godot-specialist | Before VFX epic |
| 16 | ~~Sentry and Breaker bombs (29): confirm the `BombCore` base class with a per-plane effect.~~ **Closed 2026-11-03:** `BombCore` hosts per-plane effect classes (Bastion, Backlash fit unchanged; Rules 35-36); lead-programmer confirms at architecture (Sentry/Breaker GDD) | lead-programmer | Target tier |
