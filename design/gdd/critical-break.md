# Critical Break

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (systems-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts (the chain multiply), Four Planes, Four Games (one test, two charge kits), Readable Chaos (one flash, nothing over bullets)
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: the retired `cb_banner_wait_max` (120) is now retired everywhere, not only in Rule 26 - F5, its variable table, the tuning table, the defaults list and AC-44 all read [HUD (20)](hud.md)'s `banner_wait_max` = **180** instead.

## Overview

**The data layer:** the **Critical Break** (CB) is a node-free `CriticalBreakCore` (RefCounted, one per run, `tick()` at 60 Hz). It owns one thing: the **trigger**. Each tick it reads the boss (`is_critical()`, `core_world_pos()`), each slot's charge state from the plane kit (`charge_active`, `charge_kind`, `charge_last_hit`) and each bomb's `bomb_started` / `bomb_landed` events. When one slot has **charged the core and landed a bomb on it** while the core is in its critical reserve, CB fires once per boss: it asks the Chain tracker for the multiply (`after = min(999, before x 3 + 50)`), lets Scoring pay the break and the Life Damage Bonus, requests a full-screen cancel with items for the breaker, and calls `Boss.critical_break_finish(slot)`, which ends the fight with `boss_defeated(CRITICAL_BREAK, slot)`. CB also answers Bombs' `cb_armed(slot)` query, which waives the 50 % bomb toll, and publishes a small read-only state (`cb_state(slot)`) for the HUD. CB does not own the chain math (Chain 7), the points (Scoring 8), the boss hp (Boss 14), the bomb (Bombs 12), the charge (Kits 11) or the art (VFX 25, Audio 24). All numbers are integers in ticks and live in `data/critical_break_rules.tres`. It uses no `delta`, no randomness and no node.

**The player impact:** this is the game's payoff. The boss core drops into its critical reserve and the boss gives the player a fixed 7 s window in which the core cannot die. The player holds the plane's charge (Lancer laser, Leech focused shot) on the core, then taps Bomb: the chain triples and gains 50, the score jumps by hundreds of thousands, spare lives pay a bonus, the whole field vanishes, a single white frame hits, and the bilingual banner rises over a boss that is already breaking apart. Doing it costs a bomb, a resource (Lancer meter) or a hold (Leech), and a window of exposure while the core's curtain keeps firing. Skipping it costs nothing but the bonus: the boss dies normally. Nothing here can happen by accident, and nothing is hidden: the HUD shows when the break is open and when it is armed.

## Player Fantasy

**Anchor moment: "I held the chain for 90 seconds and now I cash it in."** The last turret is gone. The core's armour peels, then the bar hits the red notch and the core flares gold: CRITICAL. The chain reads 187. The curtain is thick, but the player sits under the core with the laser burning, the number rolling, the clock arc on the core running down. Thumb to Bomb. The chain number does not halve (the toll is waived); the gold icon on the plate was already lit. One white frame. The field is empty. 187 becomes 611, the banner CRITICAL BREAK / ক্রিটিক্যাল ব্রেক rises over the dying boss and the score ticks up by 711,000.

- **Savage triumph, earned.** The break is the answer to the question "what is my chain worth?" The longer the chain going in, the bigger the payoff (Every Hit Counts).
- **You set it up, you see it armed.** The player is never guessing. A lit icon says "a bomb now breaks the boss" (Competence).
- **Two planes, two ways to arrive.** Lancer burns a stored meter and is untouchable while it does it. Leech spends nothing but time and aim, and the hooks need about a second to bite. Same test, different route (Four Planes, Four Games).
- **A gift, not a trap.** For 7 s the core cannot die. Failing costs only the bonus. Missing never kills you, never wastes a boss.
- **The only flash.** Nothing else in the game flashes, so this one is a punch. Players who cannot take a flash get a particle burst instead and keep everything else.

**Anti-fantasy (must never happen):** a break triggered with no player intent; a break that the player cannot tell was armed; a flash over a bullet-filled field; a break stolen by a teammate who did not qualify; a banner over bullets; a break lost because the boss died one tick earlier by a normal hit while the bomb was in flight; a multiply applied after the chain froze.

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

Units: **tick** = 1/60 s; **px** on the 360x640 canvas. `t` = the current tick. `T` = the trigger tick. A **charge hit** is a counted hit by the plane's charge source (Lancer laser tick; Leech focused-shot bullet). The **core** is the boss part with `target_id` 1000 (Boss Rule 8).

**A. Ownership and inputs**

1. **One `CriticalBreakCore` per run.** Node-free `RefCounted`, `tick()` once per 60 Hz tick at **step 6b**: after the Collision referee (step 6) and `EnemyManager.apply_results()` (6a), with Bombs' results for this tick, **before** `Boss.apply_results()` (6c), and before the Chain tracker applies events (step 8). The multiply uses the chain count **as of the start of the tick**: this tick's hits are applied by Chain at step 8, after the multiply (F3). *(2026-11-03, wave 3b)* A thin Node adapter draws and plays sound. It holds no bullet references. It uses no `delta` and no randomness at all.
2. **Reads, each tick:** `Boss.is_critical()`, `Boss.critical_left`, `Boss.core_world_pos()`, `Boss.core_target_id()` (1000 + 0, plus the generation); per slot `charge_active(slot)`, `charge_kind(slot)`, `charge_last_hit(slot)` as `(target_id, tick)` (Kits Rule 40); `bomb_started(slot)`, `bomb_active(slot)`, `bomb_landed(slot, target_id, target_class, tick)` (Bombs Rule 28); the slot's plane state (Active or not) and `lives` from Session.
3. **A break exists only while the core is critical.** `is_critical()` is true from the tick after the core's main pool is destroyed until the core dies (Boss Rule 21). It stays true after the 7 s window closes. CB uses the value **as of the start of the tick** (Boss changes phase only in 6c, after CB), which is exactly the validity rule of `critical_break_finish` (Boss Rule 23).
4. **One break per boss.** CB keeps `consumed` (bool) per boss instance (`generation`). Set at the first success, cleared when the next boss spawns. After it is set no slot can trigger, `cb_armed` returns false for everyone, and `critical_break_finish` is never called again.

**B. What counts as "charge" (same test for both kits)**

5. **Charge** is the plane's own charge mode, as published by the kit: Lancer = the **laser's active ticks** (`charge_kind = LASER`; the 12 grace ticks do **not** count); Leech = the **focused shot** (`charge_kind = FOCUS`); Sentry = the **Entrench** nose cannon (`charge_kind = ENTRENCH`); Breaker = the **Breach** slug (`charge_kind = BREACH`) *(Target, Sentry/Breaker (29), 2026-11-03 wave 4; `charge_last_hit` = the last counted tag 2/3 result)*. CB treats both identically and never reads `charge_kind` for a rule (it is used only by presentation). The plain normal shot, HOLD_PLAIN, parked and latched drones, and the bomb itself are **not** charge.
6. **Charge run.** CB tracks per slot `run_len` (consecutive ticks with `charge_active` true; the current run, or the most recent one if it has ended) and `last_active_tick`. A run must reach **`cb_charge_min_ticks`** = 12 (0.2 s) to count. Why: both kits enter charge at `h = 18`, so a qualifying slot has held Fire for at least 30 ticks (0.5 s). A tap cannot break the boss.
7. **Charge recent** `run_ok(slot, t)`: (`charge_active` now AND `run_len >= cb_charge_min_ticks`) OR (not active now AND `t - last_active_tick <= cb_charge_lenience` (12) AND the last run's length `>= cb_charge_min_ticks`). The lenience equals `laser_exit_grace`: a Lancer who lets go of Fire and taps Bomb within 12 ticks is still in.
8. **Charge on the core** `hit_ok(slot, t)`: `charge_last_hit(slot)` names the **core's target id** and `t - hit_tick <= cb_hit_window` (12). The charge must actually be hitting the core, not a part or a wall. An ARMOURED core counts (its hits count for the chain). An IMMUNE core cannot be a charge hit, but the core is never immune in Critical.

**C. Armed, committed, triggered**

9. **Armed.** `armed(slot, t)` is true when ALL hold: `is_critical()`, `consumed` is false, the slot's plane is **Active**, `run_ok`, `hit_ok` (F1). This is the value Bombs reads as **`cb_armed(slot)`** at its accept tick (a pure query, no side effects) and the value the HUD shows as ARMED.
10. **Committed.** On `bomb_started(slot)` (same tick as the accept, before Collision), CB re-evaluates `armed(slot, t)` with the same inputs, so the answer equals what Bombs got. If true, `committed[slot] = true`. A committed bomb **no longer needs the charge**: the player may release Fire. (This is how Leech works: the hooks bite 19 to 71 ticks after the press, Bombs Rule 29. Press Bomb while the focused bullets are landing, then let go.)
11. **Landed.** A bomb has **landed** on the core when Bombs reports `bomb_landed(slot, core_id, CORE, t)` this tick (a *hit* or *destroyed* result from Collision; an armoured core counts; an *ignored* result does not). Lancer's hold column can land at `k = 0`, the same tick as the press, then every 4 ticks. Leech lands at each hook's detonation.
12. **Trigger.** A break fires for `slot` on tick `T` when ALL hold (F2):
    - `bomb_landed` on the core this tick for this slot;
    - `is_critical()` at the start of the tick and `consumed` false;
    - the slot's plane is Active and its Chain is not Frozen;
    - `committed[slot]` OR `armed(slot, T)` (**late arming**: the player pressed Bomb first and charged after; the toll has been paid, so the multiply works on the reduced count; this is the penalty, not a failure).
13. **Who gets it (co-op).** If several slots satisfy Rule 12 on one tick, the **first in rank order** wins, with `rank = (slot - (t mod 4) + 4) mod 4` ascending (the rotation used by Collision C6 and Bombs Rule 1). If slot A's bomb lands on tick 100 and slot B's on tick 101, A wins by tick order. All other slots: `committed` cleared, no refund (their toll was waived and their bomb is spent). There is one break per boss.

**D. On success (tick `T`, step 6b, in this exact order)**

14. The sequence is atomic: it is one function call and no event is processed in between.
    1. `consumed = true`. Clear every slot's `committed`.
    2. **Chain:** `after = Chain.apply_critical_break(slot)` (Chain Rule 7, F4). The window refills, Chain emits `chain_multiplied(slot, before, after)`. Scoring pays on that event (S5 `cb_unit x uncapped raw`, S6 `ldb_per_life x max(0, lives - 1)`) and writes the slot's `critical_breaks` and `life_bonus_total`. The Chain's `boss_peak` is updated by the multiply because the boss is still alive (Chain Rule 9). **This must happen before step 4**, because `boss_defeated` freezes the peak and the record (Chain Rule 10).
    3. **Cancel:** `Bullets.request_cancel(screen, cause_slot = slot, items = true)`. This is CB's **own** cancel (art bible 7.4 banner rule; Bombs Amendment 10). Items go to the breaker (Bullet manager Rule 14), capped by `items_per_cancel_cap` (Powerups 13).
    4. **Finish:** `Boss.critical_break_finish(slot)`. It must return true (Rule 3 guarantees the phase). It sets the core's hp to 0, runs the death sequence with `reason = CRITICAL_BREAK`, `killer_slot = slot` and emits `boss_defeated(CRITICAL_BREAK, slot)` (Boss Rules 31-32). Its own whole-screen cancel is a no-op on bullets already cancelled by step 3 (Bullet manager: first request wins).
    5. **Announce:** emit `critical_break_landed(slot, before, after, raw, core_pos, breaks_on_run)` on the event bus (presentation only; Session counters are written by Scoring, Rule 15).
15. **Defensive path:** if step 4 returns false (a bug, since Rule 3 makes it impossible), CB logs an error, leaves `consumed = true`, still emits the event, and the debug build asserts. The chain multiply cannot be undone; the lint test AC-21 checks that this path is unreachable.
16. **Score ownership.** CB never adds score and never writes `critical_breaks` or `life_bonus_total`. Scoring does both on `chain_multiplied` (Scoring Rule 6). CB reads the two amounts for its popup through Scoring's pure functions `preview_cb_points(before)` and `preview_ldb_points(lives)` (F4), which use the same code as the payout (→ Amendment).
17. **Other slots.** The Boss value (S4 100,000) is paid to every eligible slot by `boss_defeated`, as for any kill. The break pays only the breaker. In co-op the unlucky teammate's bomb is simply spent.

**E. Failure, expiry, cleanup**

18. **A committed bomb that misses.** If a slot is committed and its bomb ends (`bomb_active` false) with no `bomb_landed` on the core, the commit is cleared and CB emits `critical_break_missed(slot, NOT_ON_CORE)`. The toll that was waived stays waived (Bombs accepts this leak). Nothing else changes.
19. **A bomb that lands on the core without qualifying.** If `bomb_landed(core)` arrives during Critical and Rule 12 fails (no charge or no charge hit), CB emits `critical_break_missed(slot, NO_CHARGE)` once per bomb. The toll was paid by Bombs. The bomb's damage went to the core as normal (armoured 20 %).
20. **Commit is cleared** on: the slot's `plane_died`, `forfeit_slot`, `stage_cleared`, the bomb ending, a break by another slot, or the core dying by any other route.
21. **Window expiry.** When `critical_left` reaches 0 nothing happens to CB: the break stays valid while the core is alive (Boss edge case). The core arc (a VFX world-space tell, V5) empties and the HUD cue changes (Rule 27). The core is NORMAL again and any lethal hit ends the fight as `KILLED`. A bomb in flight whose landing destroys the core still triggers the break (Rule 12 is evaluated at 6b, before the Boss applies the kill in 6c; Boss Rule 23 processes CB first).
22. **No break.** If the boss ends by `KILLED` or `TIMEOUT` while critical, CB emits `critical_break_expired(reason)` once, clears everything, and no counter changes. The Boss value is paid by `boss_defeated` as usual. A normal kill is a legitimate way to finish; it just earns no bonus.
23. **No break outside Critical.** A bomb landing on the core in PARTS or EXPOSED never triggers (Rule 3). `cb_armed` is false there, so the bomb toll is paid in full.

**F. Presentation timing and hitstop (decision)**

24. **No hitstop and no time scaling in logic.** Logic runs every tick at 60 Hz through the break. Fixed-tick determinism, input latency and Web frame pacing all argue against a freeze. A presentation-only freeze (render paused, logic running) is **rejected**: the player would act blind inside a frozen picture. A global render freeze is also rejected. VFX may add a local boss-sprite shake of at most 4 px for 8 ticks, which changes no gameplay state.
25. **Timeline** (relative to `T`; all presentation, driven by tick counters, F5):
    - `T`: logic only. Chain, score, cancel request, finish. The bullets still exist this tick (the cancel is consumed on the next tick, Boss Rule 31 and Bullet manager Rule 15).
    - `T+1`: the cancel is executed: the field is empty. **The white frame** is drawn this tick (layer 10), covering the removal. Exactly one rendered frame.
    - `T+2`: the **banner** starts (layer 11), once `enemy_bullet_count == 0` is confirmed. The warm burst and shockwave start on the boss (layers 4-5); the background desaturation ramps in.
    - `T+2 ... T+43`: banner ease-in 6, hold 30, ease-out 6 ticks.
    - `T+1 ... T+36`: warm burst and background tint (36 ticks, about 0.5 s plus the tail).
    - Plate-local popup (`x3`, life-bonus number) from `T+1`, 90 ticks.
26. **Banner gate.** The banner waits while `enemy_bullet_count > 0`, for at most `cb_banner_wait_max` = 120 ticks. If bullets remain after that, the banner is **dropped** (the popup and the burst still play) and an error is logged. Bullets always win. *(2026-11-03, wave 3a: HUD (20) owns banner presentation (HUD Rule 27). The wait is HUD's `banner_wait_max` = **180** ticks, then the banner is skipped; `cb_banner_wait_max` (120) is superseded and retired. CB still fixes the earliest start, `T+2`.)*
27. **Accessibility.** With `access.reduce_flashing` true: the white frame is replaced by a **particle burst** (a warm ring of particles on the boss and background layers), the background tint ramps over 18 ticks to at most 25 %, and no consecutive frames differ in mean luma by more than 8 % (AC-36). The banner stays (art bible 7.3). With it false: exactly one white frame, once per boss. The flash cannot occur more than once per boss; a stage has one boss, so the rate is below one flash per 30 s (far under the 3 flashes/s guideline).
28. **Audio.** One unique sting (Audio 24, `sfx_cb_sting`) starts at `T+1` with the flash. It is used for nothing else. Music ducks with Audio's `cb_stab` duck (12 dB; 50 / 1500 / 600 ms); the boss music fades out after the duck releases (Audio 24 owns the curve). *(2026-11-03, wave 3b)*

**G. Armed / state feedback for the HUD**

29. CB publishes per slot `cb_state(slot)`:

    | State | Meaning | HUD cue (HUD 20 draws) |
    |---|---|---|
    | NONE | Boss not critical, or break already taken | no cue |
    | OPEN | Critical, window open, slot not armed | ring around the core, arc shows `critical_left / 420` |
    | ARMED | `armed(slot, t)` true | the slot's plate shows the CB icon lit; the bomb icon gets a gold outline |
    | COMMITTED | Bomb accepted while armed, not yet landed | the CB icon pulses (within art bible 7.7); the core ring narrows |
    | OPEN_LATE | Critical, window closed, core alive | ring and arc replaced by a thin static ring (still valid) |

    It also publishes `critical_left` and `core_world_pos()` through Boss. The cues use shape and brightness, not colour alone, and no text.
30. **Failure feedback.** `critical_break_missed(slot, reason)` with reason `NO_CHARGE` or `NOT_ON_CORE`: a low two-tone blip, the CB icon dims for 30 ticks, no text, no flash. The debug overlay shows the reason (Rule 31).

**H. Debug**

31. A debug overlay (dev builds) shows per slot `run_len`, `last_active_tick`, `hit age`, `armed`, `committed`, `consumed`, the last `critical_break_missed` reason and the trigger tick. A debug command `cb_force(slot)` calls the success sequence (Rule 14) when `is_critical()`; it is stripped from release builds.

**Prototype migration (`player.gd` `_critical_break()`, `boss.gd`, `hud.gd`, `game.gd`)**

| Prototype | Problem | Corrected here |
|---|---|---|
| `if laser.active and boss.is_critical(): _critical_break()` in `player.gd` | Triggers on the laser alone; no bomb; no co-op; no lenience | Charge + bomb landing on the core, in its own system (Rules 9-12) |
| Break calls `chain.apply_critical_break()` with no slot, then `boss.critical_break()` | No slot; no order against the freeze | Slot-aware; multiply first, then finish (Rule 14) |
| `life_bonus` computed in `player.gd` | Mixed with the player | Scoring S6 on `chain_multiplied` (Rule 16) |
| `GameEvents.critical_break_landed(player, final_chain, life_bonus)` | Carries the player node and the bonus | `critical_break_landed(slot, before, after, raw, core_pos, breaks_on_run)` (Rule 14.5) |
| `hud.gd`: "!! CRITICAL: LASER + BOMB !!" literal | Hard-coded English; mixed system | HUD reads `cb_state` (Rule 29); no literal strings (Localization Rule 9) |
| `boss_part.gd`: core "can only be finished by a Critical Break" | Boss cannot be killed otherwise | Boss GDD: the core can die after the window; CB is optional (Boss Rules 22, 30) |

> Decided under auto-approve (2026-11-03): trigger = a bomb landing on the core, with a charge that was on the core (ready at the press, or at the landing); charge = laser active ticks (Lancer) or the focused shot (Leech), same 12-tick run and 12-tick lenience tests; a committed bomb no longer needs the charge; one break per boss; the first slot in rank order wins; multiply before finish; CB issues its own cancel with items; no hitstop and no presentation freeze; flash at `T+1`, banner at `T+2` behind a bullet gate; reduce-flashing replaces the flash only; CB pays nothing itself (Scoring does).

### States and Transitions

**Boss-level state** (one machine per boss instance):

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| DORMANT | Boss not critical | OPEN | `is_critical()` becomes true (tick after the core's main pool is destroyed) |
| OPEN | Critical, window open (`critical_left > 0`) | OPEN_LATE | `critical_left` reaches 0 |
| OPEN | | BREAKING | Rule 12 holds for a slot |
| OPEN_LATE | Critical, window closed, core alive | BREAKING | Rule 12 holds |
| BREAKING | Transient: the success sequence (Rule 14), one call | DONE | end of the call |
| OPEN / OPEN_LATE | | EXPIRED | `boss_defeated(KILLED)` or `boss_defeated(TIMEOUT)` without a break |
| DONE / EXPIRED | Terminal for this boss | DORMANT | next `boss_intro_started` (new generation) |

**Slot-level state** (derived each tick; the `cb_state` table above): NONE, OPEN, ARMED, COMMITTED, OPEN_LATE. A slot is COMMITTED from the accept tick until its bomb ends or lands.

**Presentation timeline** (F5), relative to `T`:

| Tick | Event |
|---|---|
| `T` | Chain multiply, cancel request, finish, `critical_break_landed` |
| `T+1` | Field cancelled; white frame (or the particle burst); sting; popup starts |
| `T+2` | Banner starts if the field is clear; burst, shockwave and tint |
| `T+36` | Burst and tint end |
| `T+44` | Banner gone |
| `T+91` | Popup gone |
| `T+180` | `boss_gone` (Boss death sequence) |

**Tick order** (extends Boss tick order and ADR-0001; → ADR for the core wiring): Kits and Bombs tick → Collision referee (step 6) → `EnemyManager.apply_results` (6a) → **CB step 6b** (reads this tick's `bomb_landed`) → Boss `apply_results` (6c) → Chain events (step 8). Chain Rule 4 applies events in arrival order, so `chain_multiplied` arrives before `boss_defeated`. The multiply reads the chain count as of the start of the tick; this tick's hits reach Chain at step 8, after it *(2026-11-03, wave 3b)*.

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Boss and boss parts (14) — GDD | ← `is_critical()`, `critical_left`, `core_world_pos()`, `core_target_id()`; → `critical_break_finish(slot) -> bool` | Valid only when the phase at the start of the tick was CRITICAL; CB is processed before a normal kill on the same tick |
| Plane kits (11) — GDD | ← `charge_active(slot)`, `charge_kind(slot)`, `charge_last_hit(slot)` | Tick order: kits run before CB. Kit never changes because of a break (Kits Rule 40) |
| Bombs (12) — GDD | ← `bomb_started`, `bomb_active`, `bomb_landed`; → answers `cb_armed(slot)` | `cb_armed` is a pure query on the accept tick; toll waiver is Bombs' |
| Chain tracker (7) — GDD | → `apply_critical_break(slot)`; ← new count; Chain emits `chain_multiplied` | Multiply before finish (Rule 14) |
| Scoring (8) — GDD | (via `chain_multiplied`) pays S5 and S6; ← `preview_cb_points(before)`, `preview_ldb_points(lives)` for the popup | CB never adds score |
| Game events and session (1) — GDD | → `critical_break_landed`, `critical_break_missed`, `critical_break_expired` on the bus; ← slot states, `lives`, pause | Counters are written by Scoring |
| Bullet manager (3) — GDD | → `request_cancel(screen, cause_slot, items = true)`; ← `enemy_bullet_count` for the banner gate | CB's own cancel |
| Collision, damage and lives (6) — GDD | none direct | Bomb results reach CB through Bombs; Collision Open Question 5 closed (Amendment) |
| Co-op and Team Chain (18) — GDD | ← none; rank rule shared | One break per boss; breaker only |
| Input (2) — GDD | none | Bomb and Fire are consumed by Bombs and the kit |
| Localization (27) — GDD | ← `text_both("banner.critical_break")` | Bengali above English |
| Save, settings (26) / Accessibility (28) | ← `access.reduce_flashing` | Replaces the white frame only |
| HUD (20) — [GDD](hud.md) | → `cb_state(slot)`, `critical_left`, `core_world_pos()`, popup values | See UI Requirements |
| Stage-end tally (21) — [GDD](stage-end-tally.md) | ← Session `critical_breaks`, `life_bonus_total`, breakdown lines | CB adds no data of its own |
| VFX (25) — [GDD](vfx-and-screen-feedback.md), Audio (24) — [GDD](audio.md) | → `critical_break_landed`, `critical_break_missed`, `critical_break_expired`; `cb_state(slot)`, `critical_left`, `core_world_pos()` for the core ring/arc | Presentation only. VFX owns the core ring/arc tell (T0, layer 5, below enemy bullets), the CB cancel puffs (max 12), the boss shake and the burst; Audio owns `sfx_cb_sting` and the `cb_stab` duck |
| Wave director (16) | none | `boss_defeated(CRITICAL_BREAK)` drives the stage clear as any reason |

All interfaces to the listed systems now have GDDs *(2026-11-03, wave 3b)*: Audio (24), VFX (25), Parallax (23) and Accessibility (28) are written; the contracts above match them. *(2026-11-03, wave 3a: HUD (20) and Stage-end tally (21) now have GDDs. HUD Rule 28 reads `cb_state(slot)` and starts the banner from `critical_break_landed`; there is no separate banner-request event.)*

## Formulas

All integers; `div` is integer division.

**F1. Armed**

`armed(s, t) = is_critical AND NOT consumed AND active(s) AND run_ok(s, t) AND hit_ok(s, t)`
`run_ok(s, t) = (charge_active(s, t) AND run_len(s) >= cb_charge_min_ticks) OR (NOT charge_active(s, t) AND t - last_active(s) <= cb_charge_lenience AND run_len(s) >= cb_charge_min_ticks)`
`hit_ok(s, t) = hit_target(s) == core_id AND t - hit_tick(s) <= cb_hit_window`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Tick | `t` | int | >= 0 | Current tick |
| Run length | `run_len` | int | 0-3600 | Consecutive charge-active ticks (current, or the last run if it ended) |
| Last active tick | `last_active` | int | >= 0 | Latest tick with `charge_active` |
| Minimum run | `cb_charge_min_ticks` | int | 6-30 (12) | Shortest charge that counts |
| Lenience | `cb_charge_lenience` | int | 0-30 (12) | Ticks after the charge ends that it still counts (= `laser_exit_grace`) |
| Hit window | `cb_hit_window` | int | 6-30 (12) | Max age of the last charge hit on the core |
| Hit target / tick | `hit_target`, `hit_tick` | int | | From `charge_last_hit(s)` |

**Output Range:** bool. **Example (Lancer, core in Critical):** laser active ticks 1000-1039 (`run_len` 40), last core hit at 1038, Bomb pressed at 1042: `charge_active` false, `1042 - 1039 = 3 <= 12`, `run_len 40 >= 12`, hit age `1042 - 1038 = 4 <= 12` -> **armed**. At 1052: `13 > 12` -> not armed. **Example (Leech):** Fire down at tick 0; focused shot from tick 18; first focused bullet (muzzle at ~y 560, core at y 260, 300 px at 15 px/tick = 20 ticks) lands at tick 38; `run_len` at 38 is 21, hit age 0 -> **armed from tick 38**. At tick 37: no hit yet -> not armed.

**F2. Trigger and winner**

`trigger(s, T) = landed(s, T) AND is_critical_at_start AND NOT consumed AND active(s) AND NOT frozen(s) AND (committed(s) OR armed(s, T))`
`winner = argmin over triggering s of rank(s, T)`, `rank(s, T) = (s - (T mod 4) + 4) mod 4`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Landed | `landed` | bool | | `bomb_landed(s, core_id, CORE, T)` this tick |
| Committed | `committed` | bool | | Set on `bomb_started` if armed (Rule 10) |
| Rank | `rank` | int | 0-3 | Lower wins |

**Output Range:** one slot or none per tick, once per boss. **Example:** `T = 1001`, slots 0 and 2 both trigger: `rank(0) = (0 - 1 + 4) mod 4 = 3`, `rank(2) = (2 - 1 + 4) mod 4 = 1` -> **slot 2**. At `T = 1000`: rank(0) = 0, rank(2) = 2 -> **slot 0**. Slot 1 triggers on 1005 after slot 3 broke on 1004 -> `consumed`, nothing.

**F3. Chain multiply** (owned by Chain 7 F4; shown for the contract)

`after = min(chain_cap, before x cb_mult + cb_add)`; `raw = before x cb_mult + cb_add` (uncapped)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Before | `before` | int | 0-999 | Count **as of the start of tick `T`**; this tick's hits are applied by Chain at step 8, after the multiply *(2026-11-03, wave 3b)* |
| Multiplier | `cb_mult` | int | 1-5 (3) | Chain 7 |
| Add | `cb_add` | int | 0-200 (50) | Chain 7 |
| Result | `after` | int | 50-999 | Written to the chain |

**Timing (wave 3b):** step 6 Collision referee → 6a `EnemyManager.apply_results` → 6b CB (the multiply) → 6c `Boss.apply_results` → 8 Chain applies this tick's hits. So `before` is the count at the start of the tick; a hit landing on tick `T` adds to `after`, not to `before` (AC-46).

**Output Range:** `after` 50-999; `raw` 50-3,047. **Example:** 0 -> 50; 40 -> 170; 150 -> 500; 187 -> **611**; 316 -> 998; 317 -> 999 (raw 1,001); 400 -> 999 (raw 1,250).

**F4. Break value** (owned by Scoring 8 F4; shown so the popup and tuning can be checked)

`cb_points = cb_unit x raw`; `ldb_points = ldb_per_life x max(0, lives - 1)`; `bonus_total = cb_points + ldb_points`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| CB unit | `cb_unit` | int | 500-2,000 (1,000) | Scoring |
| LDB per life | `ldb_per_life` | int | 25,000-100,000 (50,000) | Scoring |
| Lives | `lives` | int | 1-6 | Read on tick `T` (includes the live one) |

**Output Range:** 50,000-3,047,000 plus 0-250,000. **Example (lives 3):** before 187 -> raw 611 -> **611,000** + 2 x 50,000 = 100,000 -> **711,000** total. Before 40 -> 170,000 + 100,000 = 270,000. With 1 life: LDB 0. Compare the normal kill: the Boss value is **100,000** for either route; the break adds the rest.

**F5. Presentation timeline**

`flash_tick = T + 1` (or the burst start, with reduce flashing); `banner_start = max(T + 2, first tick >= T + 2 with enemy_bullet_count == 0)`; dropped if `banner_start > T + 2 + banner_wait_max` (**HUD (20)'s `banner_wait_max` = 180**, Rule 26; CB's own `cb_banner_wait_max` = 120 is retired - *amended 2026-11-03, wave 5 batch 2*); `banner_end = banner_start + 6 + 30 + 6`; `burst_end = T + 1 + 36`; `popup_end = T + 1 + 90`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Trigger tick | `T` | int | | Step 6b |
| Banner wait | `banner_wait_max` (HUD 20) | int | 60-300 (**180**) | Ticks to wait for an empty field. Read from HUD, not from CB data; `cb_banner_wait_max` is retired *(amended 2026-11-03, wave 5 batch 2)* |
| Ease / hold | | int | 6 / 30 | Banner (art bible 7.3) |

**Output Range:** `banner_end - banner_start` = 42 ticks (0.7 s total, 0.5 s held). **Example:** `T = 2000`: cancel executes 2001, flash 2001; field empty at 2001, banner 2002-2043; burst 2001-2037; popup 2001-2091. If a stray bullet exists until 2010: banner 2010-2051. If bullets still exist at tick 2182 (`T + 2 + 180`): banner skipped *(was 2122 under the retired 120; amended 2026-11-03, wave 5 batch 2)*.

**F6. Landing time per kit** (information; Bombs owns the numbers)

Lancer: `T_land = t0 + k*`, `k*` = first `k` with `k mod 4 == 0` and a column within `28 + r_h` of a core circle. Leech: `T_land = t0 + a + 18`, `a = 1 + ceil((D - 14) / 14)` for `D > 14` (D = distance to the core).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Press tick | `t0` | int | | Bomb accept tick |
| Core circle radius | `r_h` | px | 15.5 (Fortress) | Boss F2 |
| Distance | `D` | px | 0-734 | Hook to core |
| Arrival | `a` | int | 1-53 | Bombs B6 |

**Output Range:** Lancer 0 to ~32 ticks after the press; Leech 19 to 71. **Example:** Fortress core circles at x 167.25 / 180 / 192.75, `r_h` 15.5. Plane at x 180: `k* = 0`, break on the press tick. Plane at x 250: column at `250 - 8m`; `m = 5` (k = 28): `|210 - 192.75| = 17.25 < 43.5` -> first hit at **k = 28**; at k = 24 (`m = 1`): `|242 - 192.75| = 49.25` no. Leech with D = 300: moves ticks 1-21 (294 px), `dist 6 <= 14` at tick 22 -> `a = 22`, detonation at `k = 40`; the break fires at `t0 + 40`. With the plane at the core's x and `D = 120`: `a = 1 + ceil(106/14) = 9`, break at `t0 + 27`.

**F7. Opportunity cost of not breaking** (tuning check)

`gain_break = cb_unit x raw + ldb_per_life x max(0, lives - 1)` (the Boss value, 100,000, is paid in both routes, so it cancels)

**Output Range / Example:** a chain of 120 at the core with 3 lives: raw 410 -> 410,000 + 100,000 = **510,000**, which is 17 % of `extend_unit` 3,000,000 (510,000 / 3,000,000 = 0.17) and about 17 % of a competent stage (~2.99M). Scoring AC-48 owns the health check.

> Formulas proposed by systems-designer; numbers by auto-approve (2026-11-03). 12/12/12 are chosen to equal `laser_exit_grace` (12), which is the kit's own grace.

## Edge Cases

**Trigger and arming**
- **If Bomb is pressed while the core is in EXPOSED**, `cb_armed` is false, the toll is paid, no break. The bomb damages the core as normal.
- **If the core enters Critical on the same tick the bomb lands**, `is_critical()` at the start of the tick is false: no break on that tick. Lancer's column lands again every 4 ticks; a Leech's later hooks land later, so the break fires on a later landing if the slot qualifies then (Rule 12, late arming).
- **If the player holds Fire for fewer than `cb_charge_min_ticks` ticks of charge**, `run_ok` is false: no break, even with a bomb landing.
- **If Fire is released and Bomb pressed within 12 ticks**, the charge still counts (lenience). At 13 ticks it does not.
- **If the charge is hitting a part, not the core** (the core is behind a living part), `hit_ok` is false. In Critical all parts are dead, so this case occurs only if the beam is offset from the core.
- **If a bomb is accepted while armed and the player then releases Fire**, the break still fires when the bomb lands (committed). If the bomb never lands, `critical_break_missed(NOT_ON_CORE)`.
- **If the Lancer meter hits 0 before the bomb**, the laser ends; the 12-tick lenience still allows a press at once. After 12 ticks the Lancer must charge again (Fire hold needs a meter of 400).
- **If the bomb is pressed first and the charge starts later** (late arming), the toll has been paid; if the bomb lands on the core while the slot is armed, the break fires on the **reduced** chain (187 -> 94 -> 332). The intended order is charge first.
- **If the Leech's hooks spread to other enemies** (more than 4 eligible targets), a hook may not target the core; with no landing there is no break. In the MVP bosses have no adds, so this only arises if the Wave director leaves enemies alive (→ Wave director must `despawn_all`, Boss Rule 11).
- **If an armed slot's bomb hits the core with an *ignored* result** (a same-tick kill), no `bomb_landed`, no break.
- **If the bomb's hit destroys the core** (window closed, hp low), `landed` is true and CB fires first (Boss Rule 23); the result is `CRITICAL_BREAK`, not `KILLED`.
- **If a normal lethal hit and the break land on one tick**, the break wins (CB at 6b runs before the Boss's kill in 6c).
- **If the core dies on tick T-1** (a normal kill with the window closed), `is_critical()` is false from T (the boss is Dying): no break, `critical_break_expired(KILLED)`.
- **If `consumed` is already true**, every query returns false and no call is made.

**Chain**
- **If the chain is 0 at the trigger**, 0 becomes 50 and a chain starts (Chain edge case). This is nearly impossible, because the qualifying charge hit on the core refreshes the chain within the last 12 ticks.
- **If the chain would exceed 999**, `after` is 999; Scoring pays on the uncapped `raw` (F3, F4).
- **If a counted hit and the break land on the same tick**, they apply in arrival order; Collision's hits arrive first, so the multiply uses the count including this tick's hits.
- **If the slot is not Active at 6b** (it died this tick in Phase B), Rule 12 fails for it; the next slot in rank order may break. A bomb gives 90 ticks of invulnerability, so this is only possible if the player died on the same tick the bomb was accepted (same-tick deathbomb saves them, Bombs Rule 17).
- **If the chain is Frozen**, impossible (Frozen means the boss is dead).

**Co-op**
- **If two slots land bombs on the core on the same tick**, rank order decides (F2). The loser's bomb is spent, no break, no refund.
- **If slot A is committed and slot B breaks first**, A's commit is cleared and `critical_break_missed` is **not** emitted for A (the boss is already dead); the HUD shows DONE.
- **If a team chain is active**, nothing changes: the break is per slot. A team variant is out of MVP (Co-op Open Question 10).
- **If a slot is Dead or in Continue when a teammate breaks**, they get the Boss value as usual if eligible; no break pay.
- **If four players all qualify**, one breaks. The HUD shows ARMED on all four until then.

**Timeline and presentation**
- **If the game pauses during the break timeline**, presentation ticks freeze with logic; nothing advances.
- **If the render frame skips the flash tick** (a long frame), the flash flag is held until one frame is drawn, then cleared. It is never drawn for more than one rendered frame.
- **If `access.reduce_flashing` changes mid-boss**, the new value is read at `T` (not mid-timeline).
- **If the language changes during the banner**, it re-renders next frame (Localization). Digits in the popup follow the language.
- **If the field is not empty at `T+2`**, the banner waits up to 120 ticks, then is dropped (F5).
- **If four planes' bombs are active at `T`**, only the breaker's items and cancel apply; the others' effects are removed by `boss_defeated` freezing the boss's hurtboxes (no more damage events). The bombs themselves keep running to their end (Bombs Rule 16 covers `stage_cleared`).

**Boss and run**
- **If the boss times out in Critical**, `critical_break_expired(TIMEOUT)`; no break (Boss edge case).
- **If the stage has several bosses** (not in MVP), `consumed` resets on each `boss_intro_started`; one break per boss.
- **If `boss_defeated(CRITICAL_BREAK)` is the last stage's boss**, Session goes to the ending as for any reason; the break popup plays during the 180-tick death sequence.
- **If the plane dies during the 180-tick death sequence**, nothing changes; the break is complete.
- **If `critical_break_finish` returns false**, error log, debug assert, `consumed = true` (Rule 15).
- **If the same Fire release/press repeats**, a new charge run starts with `run_len` 0 and needs 12 ticks again.

**Degenerate strategies and mitigations**

| Strategy | Why it appeals | Mitigation |
|---|---|---|
| **Waive the toll with a fake charge** (tap Fire, then Bomb every time) | Free bombs | `run_ok` needs a 12-tick run and `hit_ok` needs a charge hit on the core, only in Critical, only once per boss |
| **Break at chain 1** | Safe low-risk bonus | The break is then 170,000 (F3, F4), well under a held chain; `cb_add` 50 keeps it above a normal kill but not dominant (Chain knob) |
| **Stealing the break in co-op** | Easy points | Rank order; the stealer must qualify (charge on the core) and land a bomb; the teammate's bomb is the cost |
| **Saving bombs for the break** | Biggest payoff | Intended: 3 per stage (Bombs) |
| **Leech never charging** (bombing from afar) | No exposure | Needs 12 ticks of focus run and a charge hit on the core within 12 ticks |
| **Stalling in Critical for a bigger chain** | Bigger multiplier | The window is 420 ticks, the core is armoured (hits count); after it closes the fight can end by a normal hit; `enrage` limits the total (Boss F5) |

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Boss and boss parts (14) | Hard | `is_critical()`, `critical_left`, `core_world_pos()`, `core_target_id()`, `critical_break_finish(slot)` | yes |
| Plane kits (11) | Hard | `charge_active`, `charge_kind`, `charge_last_hit` | yes |
| Bombs (12) | Hard | `bomb_started`, `bomb_active`, `bomb_landed`; answers `cb_armed` | yes |
| Chain tracker (7) | Hard | `apply_critical_break(slot)`, `chain_multiplied`, Frozen state, `boss_peak` rule | yes |
| Scoring (8) | Hard | Pays S5/S6 on `chain_multiplied`; pure preview functions | yes |
| Game events and session (1) | Hard | Slot states, `lives`, pause, event bus, `critical_breaks` / `life_bonus_total` | yes |
| Bullet manager (3) | Hard | `request_cancel(screen, cause, items)`, `enemy_bullet_count` | yes |
| Localization (27) | Soft | `banner.critical_break` | yes |
| Save, settings (26) / Accessibility (28) | Soft | `access.reduce_flashing`, `access.effects_level`, `access.rumble` | yes ([26](save-settings-high-scores.md), [28](accessibility-options.md)) |
| Co-op (18) | Soft | Rank rule and one-break rule | yes |
| Powerups and drops (13) | Soft | `items_per_cancel_cap` for the cancel's items | yes |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| HUD (20) | Soft | `cb_state(slot)`, popup values, banner trigger (`critical_break_landed`); gold bomb-icon outline and corner ticks | yes ([GDD](hud.md)); Soft *(2026-11-03, wave 3b)* |
| Stage-end tally (21) | Soft | Session counters and breakdown lines (via Scoring) | yes (reads them via Session / Scoring; does not list CB directly) |
| VFX (25) | Hard | `critical_break_landed`, `critical_break_missed`, flash timeline, core ring/arc tell | yes ([GDD](vfx-and-screen-feedback.md)) |
| Audio (24) | Hard | The sting (`sfx_cb_sting`), `cb_stab` duck and the miss blip | yes ([GDD](audio.md)) |
| Bombs (12) | Hard | `cb_armed` | yes |
| Boss (14) | Hard | `critical_break_finish` caller | yes |
| Accessibility (28) | Soft | `access.reduce_flashing` behaviour, `access.rumble` | yes ([GDD](accessibility-options.md)) |
| Tutorial (30) | Soft | Teaches the break; listens to `critical_break_landed` (break drill) | yes ([GDD](tutorial.md)) |
| Sentry, Breaker kits (29) | Hard (Target) | Publish the same `charge_*` triple; `charge_kind` adds `ENTRENCH`, `BREACH`; `charge_last_hit` = last counted tag 2/3 result | yes ([GDD](plane-kits-sentry-breaker.md)) |

**Amendments to other docs** (exact edits; the main session applies them)

1. **`design/gdd/systems-index.md`**, row 17: Depends-on cell `7, 11, 12, 14` -> `1, 3, 7, 8, 11, 12, 14`; Status cell -> `**Designed** (pending review) — [GDD](critical-break.md)`. Progress tracker: GDDs written +1. "Open items carried over": remove "Critical Break formula and Life Damage Bonus".
2. **`design/gdd/boss-and-boss-parts.md`**, Rule 23: add `core_target_id()` to the exposed interface list and the sentence "CB calls `Chain.apply_critical_break(slot)` before `critical_break_finish`; CB runs at tick step 6b, before `apply_results` (6c)". Add the tick-order step "6b. CriticalBreakCore.tick()" to the tick-order list. Interactions row for Critical Break: "no longer provisional".
3. **`design/gdd/bombs.md`**, Rule 28 / Amendment 10: replace "provisional" with "specified in critical-break.md Rules 9-12"; Rule 12: `cb_armed(slot)` is "core Critical AND charge run >= 12 ticks, charge ended <= 12 ticks ago, last charge hit on the core <= 12 ticks ago". Open Question 7 closed: Leech presses Bomb while the focused bullets land; a committed bomb no longer needs the charge (CB Rule 10).
4. **`design/gdd/plane-kits-lancer-leech.md`**, Open Question 8 closed: "CB (17) requires a 12-tick charge run, a charge hit on the core within 12 ticks, and the same test for Lancer and Leech (CB Rules 5-8). Leech's focused shot counts as charge; HOLD_PLAIN and drones do not." Rule 40: add that CB reads `charge_last_hit` target ids as boss part ids (core id 1000 + 0).
5. **`design/gdd/chain-tracker.md`**: Rule 7 add "must arrive before `boss_defeated` in arrival order (CB Rule 14.2); CB runs at step 6b". Dependencies row for CB: no longer pending. Edge case at CB at 0 remains.
6. **`design/gdd/scoring.md`**: add pure functions `preview_cb_points(before) -> int` and `preview_ldb_points(lives) -> int` to the interface (same code as F4); Rule 6 clarify "Scoring writes `critical_breaks` and `life_bonus_total`; CB writes neither". Dependencies row for CB: "GDD exists".
7. **`design/gdd/game-events-and-session.md`**, line 110 table row for Critical Break: change "writes critical_breaks, life_bonus_total" to "no writes; Scoring writes the counters on `chain_multiplied`; CB emits `critical_break_landed(slot, before, after, raw, core_pos, breaks_on_run)`"; add `critical_break_missed(slot, reason)` and `critical_break_expired(reason)` to the signal set. Dependencies row 282: Hard -> Soft (events only).
8. **`design/gdd/collision-damage-lives.md`**: Open Question 5 closed: "CB uses the normal C4 path: the break is `critical_break_finish`, not a damage event; bomb and charge hits on an armoured core are normal hits." Interactions row 270: "CB reads hit results indirectly through Bombs and the kit".
9. **`design/gdd/bullet-manager.md`**: Interactions row: CB -> `request_cancel(screen, cause_slot, items = true)` on the trigger tick and `enemy_bullet_count` for the banner gate (consumed next tick, Rule 15).
10. **`design/gdd/coop-and-team-chain.md`**: Open Question 10 note: "MVP: one break per boss, breaker only, first in rank order (CB Rule 13)". Rule 8 reference: CB effects never hit planes.
11. **`design/gdd/localization.md`**: line 280 note: "CB GDD exists; key `banner.critical_break`; popup uses atlas digits only and an icon, no text".
12. **`design/art/art-bible.md`**: 7.3 "Critical Break presentation": add the timeline (flash `T+1`, banner `T+2` after the field is empty, 6/30/6 ticks) and "no hitstop; local boss shake of at most 4 px for 8 ticks is allowed"; 7.4 banner rule: "CB issues its own cancel; the banner waits up to 120 ticks for an empty field, then is dropped".
13. **`design/gdd/game-concept.md`**: section 14 "Exact Critical Break multiplier formula and Life Damage Bonus calculation" -> "Closed: Chain F4 and Scoring F4; trigger in critical-break.md". Section 4: "bomb must land on the core with a charge hitting it within 12 ticks".

**Bidirectional check:** Boss, Bombs, Kits, Chain, Scoring, Session, Bullet manager, Co-op and Localization are amended above to list CB. Undesigned HUD (20), Tally (21), Audio (24), VFX (25) and Accessibility (28) must list CB when written. *(2026-11-03, wave 3a: HUD lists CB (Rule 28, Dependencies); Tally reads CB results through Session and Scoring.)* *(2026-11-03, wave 3b)* Audio, VFX and Accessibility list CB in their GDDs.

## Tuning Knobs

All values live in `data/critical_break_rules.tres`; none is hardcoded. Categories: **F** feel, **G** gate.

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `cb_charge_min_ticks` (G) | 12 | 6-30 | Under 6: a tap-hold arms the break | Over 30: Leech and Lancer must hold long inside a thick curtain | Kits `charge_hold_ticks` 18, F1 |
| `cb_charge_lenience` (F) | 12 | 0-30 | 0: must press Bomb while still holding Fire; strict | Over 30: break from an old charge; weakens "together" | `laser_exit_grace` 12 (rationale) |
| `cb_hit_window` (G) | 12 | 6-30 | Under 6 misses a Leech bullet stream gap (a volley every 6) | Over 30: the charge can have drifted off the core | Kits shot rates (Lancer 3, Leech 6 ticks), F1 |
| ~~`cb_banner_wait_max`~~ (G) | **retired** | — | — | — | Superseded 2026-11-03 by HUD (20) `banner_wait_max` **180** (HUD Rule 27, CB Rule 26). CB owns only the earliest start, `T+2`; it must not ship a competing knob |
| `cb_flash_ticks` (F) | 1 | 1 | Fixed: single frame (art bible) | Not allowed | Accessibility |
| `cb_banner_ease` / `cb_banner_hold` (F) | 6 / 30 | 4-8 / 24-36 | Banner unreadable | Banner covers play too long | Localization banner layout |
| `cb_burst_ticks` (F) | 36 | 24-48 | Burst too brief | Burst long enough to mask the cancel | VFX |
| `cb_popup_ticks` (F) | 90 | 60-150 | Bonus unreadable | Popup lingers | HUD |
| `cb_shake_px` / `cb_shake_ticks` (F) | 4 / 8 | 0-6 / 0-12 | None | Distracting | VFX |
| `cb_pause_in_hitstop` | not a knob | | | | Rule 24: no hitstop |

**Owned elsewhere (pointers, not duplicated):** `critical_pct` 15, `critical_window_ticks` 420, `critical_armor_pct` 20 -> Boss (14) · `cb_mult` 3, `cb_add` 50, `chain_cap` 999 -> Chain (7) · `cb_unit` 1,000, `ldb_per_life` 50,000 -> Scoring (8) · `bomb_chain_toll_pct` 50, `bomb_start` 3 -> Bombs (12) · `charge_hold_ticks` 18, `laser_min_meter` 400 -> Kits (11) · `items_per_cancel_cap` -> Powerups (13) · `access.reduce_flashing` -> Accessibility (28) / Save (26).

**Rationale for the defaults:** 12 ticks is the kit's own laser grace; 18 + 12 = 30 ticks (0.5 s) of Fire before a break can arm; a window of 12 hits covers 4 Lancer laser hits and 2 Leech volleys; 120 ticks (2 s) of banner wait is longer than any stray bullet lifetime after emitters stop, yet short enough not to delay the tally; the popup lasts 90 ticks so the 7-digit number is readable before the boss death sequence ends at 180.

## Visual/Audio Requirements

> Source of truth: `design/art/art-bible.md` (AB). Draw layers per AB 6.8: enemies 4, air FX 5, player shots 6, planes 7, **enemy bullets 8**, hitbox dots 9, **CB frame 10**, HUD 11 (banners). **Bullets always win**: nothing here draws above layer 8 except the single flash frame (layer 10) and the banner/popup (layer 11) after the field is clear. Never use Void Indigo / Ink for effects; never use enemy shapes (orb, rice, needle, ring); the shockwave is a thin full ring larger than 24 px (AB 6.8 rule 3). Numbers marked (P) are unplaytested.

**V1. The flash** (layer 10)
- One full-canvas 360x640 frame of `#FFFFFF` at 100 % opacity, one rendered frame, drawn at `T+1`, no fade (the only flash in the game, AB section 2). It covers the instant the field is cleared.
- **Reduce flashing:** no white frame. Replace with a **particle burst**: 80 warm particles (`#FFF4D0` / `#FFB347`), 2-4 px, radial from the core, lifetime 18-30 ticks, layers 4-5, inside the 150-particle cap (AB 8.6). The count scales by VFX `level_pct` (`access.effects_level`: FULL 100 / REDUCED 50 / MINIMAL 25 %) *(2026-11-03, wave 3b)*.

**V2. Warm burst and shockwave** (layers 4-5, on the boss and background)
- Shockwave ring: 2 px, `#FFF4D0` fading to `#FFB347`, diameter 24 -> 360 px over 18 ticks, centred on the core, opacity 100 % -> 0 %.
- Heavy burst on the boss: 60 particles (P), `#FFB347` / `#FFF4D0`, 3-6 px, lifetime up to 30 ticks. They never draw over a surviving bullet: the field is empty at `T+1`.
- CB's own cancel shows at most **12** cancel puffs and no ring (VFX F3, `cancel_puff_caps`) *(2026-11-03, wave 3b)*.
- Background desaturation toward the era's brightest tone (Parallax `set_desaturation(pct)`, called through VFX; max 60 % = alpha 153, reduce flashing 25 % = alpha 64) *(2026-11-03, wave 3b)*: ramp in 6 ticks, hold 18, ramp out 12 (36 ticks total), at most 60 % (P). With reduce flashing: ramp in 18 ticks, at most 25 %, ramp out 12.
- Boss sprite: a local shake of 4 px for 8 ticks (applied by VFX; off at `access.effects_level` REDUCED and MINIMAL; hurtboxes do not move); the explosion sequence (Boss death) follows for 180 ticks. No global freeze (Rule 24).

**V3. Banner** (layer 11, upper third)
- Bilingual `banner.critical_break` via `text_both`: Bengali line on top at XL 34 px, English below at XL 24 px cap, equal weight; Ember Gold fill on a Char plate with 1 px `#14110E` outline on all 8 sides; plate 328 x 88 px, inner width 312 px (Localization section Visual).
- Plate top at `y = play_top + 40` (88 at 1-2P, 112 at 3-4P), so it sits in the upper third and below the HUD strip.
- Timeline 6-tick ease in (slide 12 px + opacity), 30-tick hold, 6-tick ease out. Banner stays with reduce flashing.
- Waits for `enemy_bullet_count == 0` (up to 180 ticks per HUD Rule 27, else skipped; the earlier 120 is superseded, 2026-11-03, wave 3a).

**V4. Popup** (layer 11, plate-local, on the breaker's chain plate)
- `x3` multiplier glyph and the new count, Ember Gold; a heart pictogram and the LDB number (atlas digits, `Localization.format_int`, Bengali digits in `bn`), no words. 90 ticks, fade over the last 10. The popup is the "xN plate-local popup" of the Chain tracker and Scoring.
- In co-op each plate shows only its own slot's popup; the other plates show nothing.

**V5. Armed cue** (see UI Requirements): HUD (layer 11) draws the CB icon on the plate, the gold bomb-icon outline while `cb_state` is ARMED or COMMITTED, and its corner ticks. The **core ring and window arc** are a world-space tell owned by **VFX (25)**: tier T0, layer 5, below enemy bullets, never over bullets *(2026-11-03, wave 3b)*.

**V6. Audio** (Audio 24 owns the assets)
- **Sting:** `sfx_cb_sting`, one unique, unmistakable sting, 1.0-1.5 s, starts at `T+1` with the flash; used for nothing else. Descending impact then a rising brass/synth stab; no vocals.
- **Armed tick:** a short rising tick when `cb_state` first becomes ARMED for a slot (once per arming).
- **Miss blip:** low two-tone blip on `critical_break_missed`.
- **Music:** `cb_stab` duck (12 dB; 50 / 1500 / 600 ms), boss music fades out after the duck releases (Audio owns the curve); the stage-clear jingle waits for `boss_gone`.
- **Rumble (optional):** a 30-tick strong pulse, governed by `access.rumble` (OFF / LOW / NORMAL, Target tier; Accessibility 28).

## UI Requirements

Player-facing elements (HUD 20 draws them; HUD owns their final form, e.g. its armed indicator is four steady corner ticks on the chain plate, HUD Rule 28). *Resolved 2026-11-03 (wave 3b):* the core ring/arc is a world-space tell drawn by VFX (25), not the HUD; the HUD adds the gold bomb-icon outline when `cb_state` is ARMED or COMMITTED, plus its corner ticks:

| Element | Content | Notes |
|---|---|---|
| Core ring + window arc (VFX 25) | Ring around the core while `cb_state` is OPEN; the arc shows `critical_left / 420` | World space, T0, layer 5, below enemy bullets, never over bullets. Shape/brightness only, not colour only; becomes a thin static ring in OPEN_LATE |
| Armed icon | CB pictogram on the slot's chain plate, lit when ARMED, pulsing when COMMITTED | Language-neutral; pulse within AB 7.7 (<= 2 Hz) |
| Bomb icon outline (HUD 20) | Gold outline on the bomb icon while `cb_state` is ARMED or COMMITTED, plus its corner ticks | Teaches "bomb now breaks the boss" |
| Banner | Rule 25-26 | Layer 11 |
| Popup | Rule V4 | Plate-local |
| Miss feedback | Dim the CB icon for 30 ticks | No text |

Debug tools: the overlay and `cb_force(slot)` of Rule 31.

📌 **UX Flag**: run /ux-design for the HUD Critical Break cues (core ring, armed icon, bomb outline, popup) before writing epics.

## Acceptance Criteria

**Defaults used:** `cb_charge_min_ticks` 12, `cb_charge_lenience` 12, `cb_hit_window` 12, `banner_wait_max` 180 (HUD 20; `cb_banner_wait_max` retired), `cb_mult` 3, `cb_add` 50, `chain_cap` 999, `cb_unit` 1,000, `ldb_per_life` 50,000, `critical_window_ticks` 420, banner 6/30/6, burst 36, popup 90. All read from `.tres`, never literals.

**Test setup:** node-free classes only (`CriticalBreakCore`, with stubs for Boss, Kits, Bombs, Chain, Scoring, Bullet manager, Session); injected tick counter; no scene tree; no RNG (CB uses none). Tests live in `tests/unit/test_critical_break_*.gd`, `extends SceneTree`, in the style of `tests/unit/test_chain_tracker.gd`. A stub kit publishes `charge_active` / `charge_last_hit` per tick from a scripted table; a stub bomb publishes `bomb_started` / `bomb_landed`. Integration tests use the real Chain tracker and Scoring.

**Charge and arming**
- **AC-01 [Unit] (Rules 5, 6, F1):** Lancer laser active ticks 1000-1039 (40 ticks), hit on the core at 1038, core critical, query `cb_armed` at 1039 -> true. A run of 11 ticks -> false; 12 -> true.
- **AC-02 [Unit] (Rule 7, F1):** same run ending 1039; query at 1042 (age 3) -> true; at 1051 (age 12) -> true; at 1052 (age 13) -> false.
- **AC-03 [Unit] (Rule 8, F1):** charge hit target is a part id (1001) instead of the core (1000) -> `hit_ok` false, not armed. Hit age 12 -> true; 13 -> false.
- **AC-04 [Unit] (Rule 5):** `charge_kind = FOCUS` with the same run and hit values arms identically to `LASER`; HOLD_PLAIN (`charge_active` false) never arms.
- **AC-05 [Unit] (Rule 5):** grace ticks (kit publishes `charge_active` false) do not extend the run, but the 12-tick lenience covers them; a bomb 13 ticks after the last active tick -> not armed.
- **AC-06 [Unit] (Rule 3, 23):** `is_critical()` false (EXPOSED) -> `cb_armed` false; bomb landing on the core with a full charge -> no break, no events.
- **AC-07 [Unit] (Rule 3):** core becomes critical on tick T (phase change in 6c); a bomb landing at T -> no break; a landing at T+4 with a qualifying charge -> break.
- **AC-08 [Unit] (Rule 9):** plane not Active (FlyIn, Dying) -> `cb_armed` false even with a perfect charge.

**Commit and trigger**
- **AC-09 [Unit] (Rule 10):** `cb_armed` true at accept tick 1042 -> `bomb_started(0)` sets `committed[0]`; the value Bombs received equals the value CB stored (same inputs).
- **AC-10 [Unit] (Rule 10, 12):** committed, Fire released, `charge_active` false for 40 ticks, `bomb_landed` at `t0 + 40` -> break fires.
- **AC-11 [Unit] (Rule 12, late arming):** not armed at accept (toll paid, chain 187 -> 94); armed at the landing tick -> break fires on 94 -> **332**.
- **AC-12 [Unit] (Rule 12):** not committed, not armed at landing -> no break; one `critical_break_missed(NO_CHARGE)`.
- **AC-13 [Unit] (Rule 18):** committed, the bomb ends with no `bomb_landed` on the core -> `critical_break_missed(NOT_ON_CORE)`, `committed` cleared, no break.
- **AC-14 [Unit] (Rule 11):** `bomb_landed` with class PART or a target other than the core -> no trigger; an *ignored* result emits no landing.
- **AC-15 [Unit] (Rule 20):** `plane_died`, `forfeit_slot`, `stage_cleared` each clear `committed`.

**One break, co-op**
- **AC-16 [Unit] (Rule 4):** after a break, a second qualifying landing on a later tick -> no second call; `cb_armed` false for all; `critical_break_finish` called once.
- **AC-17 [Unit] (Rule 13, F2):** slots 0 and 2 both trigger on `T = 1001` -> slot 2 wins; at `T = 1000` -> slot 0 wins.
- **AC-18 [Unit] (Rule 13):** slot 0 lands on 100, slot 1 on 101 -> slot 0; slot 1's commit cleared, no refund (stock unchanged), no `critical_break_missed` for slot 1.
- **AC-19 [Unit] (Rule 12):** the winner slot is not Active at 6b -> next qualifying slot in rank order breaks.
- **AC-20 [Integration] (co-op, real Scoring/Session):** 2P, slot 1 breaks: only slot 1 gets `critical_breaks += 1` and the break points; both eligible slots get the Boss value 100,000.

**Success sequence**
- **AC-21 [Unit] (Rule 14, 15):** call order recorded by stubs: `apply_critical_break`, `request_cancel(screen, slot, items = true)`, `critical_break_finish(slot)`, `critical_break_landed`, in that order; `chain_multiplied` precedes `boss_defeated`; the finish stub returning false logs one error and sets `consumed`.
- **AC-22 [Integration] (Rule 14.2, Chain Rule 10):** real Chain: before 187, `boss_peak` 187; the break gives 611, `boss_peak` 611 and the appended `max_chain_per_boss` entry is 611 (not 187).
- **AC-23 [Integration] (F3, F4):** real Scoring with 3 lives: before 187 -> `chain_multiplied(0, 187, 611)`; points 611,000 and LDB 100,000; `critical_breaks` 1; `life_bonus_total` 100,000. Before 40 -> 170,000 + 100,000. With 1 life: LDB 0 and no warning.
- **AC-24 [Unit] (F3):** `before` 0 -> 50; 317 -> 999 and `raw` 1,001; 400 -> 999 and `raw` 1,250; popup values use `raw` through `preview_cb_points`.
- **AC-25 [Integration] (Rule 14.3):** screen cancel with `cause_slot` = breaker; items go to the breaker and respect `items_per_cancel_cap`; the Boss's own whole-screen cancel is a no-op on the same bullets.
- **AC-26 [Integration] (Boss Rule 23):** `critical_break_finish` with the phase at the start of the tick CRITICAL -> true, `boss_defeated(CRITICAL_BREAK, slot)`; EXPOSED -> false and unchanged.
- **AC-27 [Integration] (Rule 21, Boss Rule 23):** window closed, core hp 400, a bomb event of 100x8 lands and would destroy the core on the same tick -> result `CRITICAL_BREAK`, not `KILLED`.
- **AC-28 [Unit] (Rule 16):** CB never calls `Scoring.add_score` and never writes the Session counters (spy count 0).

**Failure and expiry**
- **AC-29 [Unit] (Rule 19):** a landing without a qualifying charge -> exactly one `critical_break_missed(NO_CHARGE)` per bomb, even with 7 Lancer column landings.
- **AC-30 [Integration] (Rule 22):** critical window of 420 ticks elapses, then the core dies by a normal hit -> `boss_defeated(KILLED)`, one `critical_break_expired(KILLED)`, counters unchanged, Boss value paid once.
- **AC-31 [Integration] (Boss edge case):** timeout during Critical -> `critical_break_expired(TIMEOUT)`; no break afterwards.

**Presentation and accessibility**
- **AC-32 [Unit] (F5):** with `T = 2000`: flash flag raised at 2001, banner start 2002 and end 2044 (42 ticks), burst end 2037, popup end 2091.
- **AC-33 [Unit] (Rule 26, F5):** `enemy_bullet_count` > 0 until 2010 -> banner starts 2010; still > 0 at 2122 -> banner dropped, one error logged, popup and burst still run.
- **AC-34 [Manual] (Rule 25, 24):** with a debug `cb_force`, record a 60 fps capture: exactly one fully white frame, on `T+1`, with no enemy bullet visible in any later frame during the banner; no freeze (logic tick counter increments every tick through the break). Evidence: video + tick log.
- **AC-35 [Manual] (Rule 27, flash off):** `access.reduce_flashing` true: no frame is fully white; a warm particle burst plays; the banner still shows. Evidence: capture.
- **AC-36 [Perf] (Rule 27):** 10 s capture with reduce flashing on: no consecutive frames differ in mean luma by more than 8 %. With it off: exactly one frame exceeds that threshold.
- **AC-37 [Manual] (Localization):** the banner at 1P, 2P and 4P shows Bengali above English at equal weight, plate 328 x 88, held 0.5 s, no clipping, in both languages (Localization AC-45). Evidence: screenshots.
- **AC-38 [Manual] (Rule 29):** HUD shows OPEN, ARMED and COMMITTED cues for a Lancer and a Leech run; the cue states are distinguishable in a greyscale capture. Evidence: captures.

**Both kits and timing**
- **AC-39 [Integration] (F6, Lancer):** real kit and Bombs stubs, Fortress core at x 180: plane at x 180 -> the break fires on the press tick (`k = 0`); plane at x 250 -> the first landing at `k = 28`, break at `t0 + 28`.
- **AC-40 [Integration] (F6, Leech):** core at 300 px: hooks detonate at `k = 40`; Fire held tick 0, focused bullets landing from tick 38; press at tick 40 (armed) and release Fire at 41 -> break at tick 80; press at tick 20 (not armed) with Fire held through 60 -> break at 60 via late arming, with the toll paid.
- **AC-41 [Integration] (equal achievability, Pillar 3):** a scripted Lancer run and a scripted Leech run each reach the break with a minimum Fire hold of 30 ticks (18 + 12); neither can break with a 29-tick hold.

**Determinism and performance**
- **AC-42 [Unit] (determinism):** two runs of the same 5,000-tick scripted input produce identical trigger tick, winner, `chain_multiplied` values and event order; CB code contains no `randf`, no `delta`.
- **AC-43 [Perf] (budget):** `CriticalBreakCore.tick()` with 4 slots and the boss critical: under 0.02 ms per tick on the reference PC; 0 allocations per tick (preallocated arrays, no per-tick `Array` creation); a lint test rejects `randf`, `randi` and `delta` in the file.
- **AC-44 [Unit] (data lint):** `critical_break_rules.tres` loads; `cb_charge_min_ticks` >= 6, `cb_charge_lenience` <= 30, `cb_hit_window` <= 30, **no `cb_banner_wait_max` key is present** (retired 2026-11-03; the banner wait is HUD's `banner_wait_max` = 180 and a stray CB key must fail the lint); no player-facing literal strings in CB code or data (Localization Rule 9).
- **AC-45 [Unit] (cleanup):** a new `boss_intro_started` (new generation) clears `consumed`, `committed`, runs and misses; stale `charge_last_hit` from the previous boss's core id never arms (the generation is compared).
- **AC-46 [Integration] (Rule 1, F3, tick order):** real Chain: count 187 at the start of tick `T`; on `T` two enemy hits by the breaker and a qualifying bomb landing -> `chain_multiplied(slot, 187, 611)` (start-of-tick count), then Chain applies the two hits at step 8 -> 613. Recorded call order: Collision referee, `EnemyManager.apply_results`, `CriticalBreakCore.tick`, `Boss.apply_results`, Chain events. *(2026-11-03, wave 3b)*

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Is the Leech's break too easy next to the Lancer's? Lancer needs a meter of 400 saved and the laser running; Leech needs no resource, only a 12-tick focus run and a charge hit. If playtests show it, raise `cb_charge_min_ticks` for FOCUS only, or require N focused hits on the core. | Game-designer | First playable boss |
| 2 | Should a co-op break be shared (a team break when two players qualify within a window)? MVP: breaker only. | Game-designer / Co-op (18) | Target tier |
| 3 | Should the toll be waived only when the bomb is armed AND the bomb lands on the core (refund on a hit)? Today it is waived on arming, and a miss keeps the waiver (Bombs leak). | Systems-designer | Playtest |
| 4 | Is 12 ticks of lenience readable for a human? Check that Lancer players do not release Fire and find the break did not fire. | Game-designer | Playtest |
| 5 | Boss `critical_break_finish` has no way to refuse after the multiply. Should Boss expose a pure `can_critical_break_finish()` to remove the defensive path (Rule 15)? | Boss (14) / Lead-programmer | Implementation |
| 6 | Wave director must guarantee `despawn_all` and no bullet source after `boss_defeated` so the banner gate passes; confirm with 16. | Wave director (16) | Wave GDD |
| 7 | Scoring should expose `preview_cb_points` / `preview_ldb_points` (Amendment 6) or emit the awarded amounts as an event; choose one. | Scoring (8) | Amendment pass |
| 8 | ~~A rumble pulse on the break (Input OQ 10) and its toggle.~~ **Closed 2026-11-03:** governed by `access.rumble` (OFF / LOW / NORMAL, Target tier) (accessibility-options.md) | Audio (24) / Accessibility (28) | Polish |
| 9 | ~~Single-frame guarantee on Web and mobile: "one rendered frame" needs a render-side flag (→ ADR).~~ **Closed 2026-11-03 (ADR-0006):** render-side one-shot counter (shown in `_process`, hidden on `frame_post_draw`, `frames_drawn` fallback; game SubViewport `UPDATE_ALWAYS`). Note: one rendered frame lasts ~7 ms at 144 Hz (16.7 ms at 60 Hz); accepted. | Technical-director | Done |
| 10 | Bengali wording for "CRITICAL BREAK" (translate or transliterate). | Writer / translator | Glossary draft |
