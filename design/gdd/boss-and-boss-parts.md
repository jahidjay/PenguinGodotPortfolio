# Boss and Boss Parts

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts, Readable Chaos, History Accelerates

## Overview

**The data layer:** a **boss** is a node-free `BossController` (RefCounted, ticked once per 60 Hz tick) built from a read-only **boss definition** (`data/bosses/*.tres`). The definition holds an anchor, a closed-form sway, a list of at most 6 **parts** (exactly one **core**), a core rule (ARMOURED or IMMUNE while other parts live), and tuning for the critical window, the enrage clock and the entrance. Each part has integer hp, a capsule body, a fixed offset or an orbit, and a list of Pattern library (9) emitters. Each tick the controller places the boss and every part from the integer fight tick (no accumulated state), publishes up to 8 hurtboxes to the Bullet manager (3) and one body per living part to Collision (6), and feeds each emitter its origin and an **intensity = fraction of non-core parts destroyed** (this replaces the prototype's "rage"). Collision's hit results come back after the referee; the controller applies hp, runs **part kills** (stop emitters, cancel bullets in a circle, +5 chain, 5,000 points) and moves the fight through its states: **Intro → Parts → Exposed → Critical → Dying → Gone**. A fight clock adds an **enrage** ramp and a hard **timeout**. The boss draws no random numbers; all randomness stays inside its emitters.

**The player impact:** the boss is the stage's paragraph, and the place the chain is for. The player arrives with a short, readable plan: break the parts that shoot the most, use each part kill as a breath (the bullets near it vanish, the chain jumps +5, a ring of the curtain goes quiet), then work on the exposed core. Each part kill also *raises* the pressure of what is left, so the fight tightens as it opens. When the core falls to its critical band, a fixed **7 s window** gives the player time to set up a Critical Break, the game's payoff. Armoured and immune states tell the truth: hits on armour still count for the chain, hits on an immune core do not. A fair clock stops endless stalling without punishing a slow first clear. The fight is also the era's showcase: a riveted 1941 Flying Fortress with a spiral core, a 1970s Jet Carrier with orbiting pods and walls (**History Accelerates**).

## Player Fantasy

**Anchor moment: the last turret falls.** The player has been sliding under the Fortress for twenty seconds, holding the chain on whichever plate is nearest. The right turret pops. A dome of bullets around it vanishes, +5 on the chain, the number jumps from 62 to 67. For a heartbeat the screen belongs to the player. Then the armoured core's plates drop away, a bright inner colour shows ("CORE EXPOSED"), and the spiral arms behind it speed up. The player is already in the gap, hitting the core point-blank because that is where the chain lives.

- **A fight with a shape.** Parts first, then the core, then the critical window. The player always knows which phase they are in and what to shoot (**Readable Chaos**).
- **Every hit counts, even on armour.** Hitting an armoured core is slow progress but a real chain hit. Hitting an immune core or an immune intro does nothing, and the chain is not rewarded for it (**Every Hit Counts**).
- **Aggression is rewarded.** Each part kill sweeps bullets, adds chain and score, and relieves one gun. The price is that the remaining guns speed up (intensity), so the player chooses which part to break first.
- **A gift before the finish.** In the critical window the core cannot die to ordinary fire. The player gets 7 seconds of controlled pressure to line up laser and bomb for a Critical Break, or simply finishes it at the cost of the bonus.
- **A boss that does not wait forever.** If nobody finishes it, the boss ramps up its fire and then withdraws. A slow player is warned in time; a staller gains nothing.
- **Each era's boss is a new opponent.** The Fortress is parts-then-core with a spiral. The Jet Carrier orbits its pods and throws walls. The Plasma Ring (Target) is a shield puzzle.

**Anti-fantasy (must never happen):** a boss that kills a player on the tick it becomes dangerous; a boss that is unhittable for longer than the chain window while the fight is on; a part kill that gives no relief; a screen flash for anything but the Critical Break; being locked in a fight that cannot end; losing the boss bonus to the clock in a normal-speed kill.

Reference feel: DoDonPachi's armoured bosses with destroyable parts and a finisher window, 1941 and Raiden-style "break the guns, then the heart".

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

**Definitions and data**

1. A boss is an instance of **`BossDefinition`** (`data/bosses/<id>.tres`). Fields: `id`, `era`, `core_rule` (ARMOURED / IMMUNE; the prototype's SHIELDED is renamed IMMUNE, same enum value 1), `core_armor_pct` (int, whole percent), `critical_pct`, `hull`, `anchor` (px, 360 canvas), `sway_amp` (px), `sway_period` (int ticks per axis, 0 = fixed on that axis), `enrage_start_ticks`, `parts[]`, `escape_enabled` (kept for data parity, always true in MVP, see Rule 33).
2. A part is a **`BossPartDefinition`**. Fields: `id` (unique string within the boss, e.g. `turret_l`; **replaces the duplicate `part_name`** because it seeds the emitter RNG), `is_core`, `shape` data (`r_e`, `spine_half`, spine axis HORIZONTAL or VERTICAL), `hp_base` (int), placement (`offset` for a fixed part, or `orbit_radius`, `orbit_period` in ticks, `orbit_phase_deg` for an orbiting one), `emitters[]` (Pattern library emitters with `muzzle_offset`, `patterns[]`, `min_intensity` / `max_intensity` set on the patterns), `tags[]` (free strings for Boss power budget 15; convention `mech:<mechanic_id>` on every part with a bound pattern, Boss power budget Rule 2), `name_key` (localization key).
3. **Limits (data lint, errors):** exactly one core; at least one non-core part; at most **6 parts including the core** (art bible 5.8); unique ids; hurtbox total ≤ `boss_hurtbox_budget` (8); every `hp_base` ≥ 1 and an integer; `core_armor_pct` and `critical_armor_pct` whole percents in 1–99; every emitter muzzle stays in the fire zone for every sway/orbit position (Rule 28).
4. **All hit points are integers.** The prototype's `float hp`, `armor_damage_mult` (0.25) and absolute `critical_hp` (200) are replaced by int `hp_base`, int `core_armor_pct` (25) and `critical_pct` (15). Damage resolution is Collision C4 unchanged.
5. **Canvas migration (one-time data change):** prototype 480 × 640 values convert once (F10): anchor x 240 → 180, offsets, orbit radii, sway amplitudes and part sizes × 0.75, anchor y unchanged, timing from rad/s to integer-tick periods. Boss geometry scales as a whole so a boss keeps its proportions on the 360 px canvas. The pattern values are migrated by Pattern library F10 (not here).

**Bodies, hurtboxes, ids**

6. Every part's **body** is a capsule (`a→b`, radius `r_e`) in the boss frame; a circle has `spine_half = 0`. The boss does not rotate. A part's body is **lethal** (Collision Rule 1) except where Rule 14 says otherwise. All bodies carry `on_boss = true`, `kill_class = PART` (non-core) or `CORE`.
7. **Hurtboxes** use Enemy F3: `r_h = r_e + hurt_pad` (2 px); `k` circles on the spine, with spacing ≤ 1.5 × `r_h`. **Boss addition:** a part with `spine_half ≤ r_e / 2` registers one circle at its centre with radius `r_e + spine_half + hurt_pad` (saves hurtboxes; slightly generous). A destroyed part publishes nothing.
8. **Target ids.** Part `i` (definition order, core = index 0) has `target_id = 1000 + i` and a `generation` equal to the boss instance counter (increments per boss spawned). The Bullet manager and Collision see parts as ordinary `(id, generation)` targets.
9. **Hull** (WING_BAR, DELTA, RING, NONE) is a presentation silhouette. It has no hurtbox, no body, and **never blocks shots or the laser**.
10. **Hurtbox budget:** boss ≤ 8 (the share reserved by Enemy Rule 23). The Wave director must `despawn_all` before the intro, so the boss normally has all 40 of the Bullet manager's reference hurtboxes to itself.

**Lifecycle**

11. The Wave director calls `Boss.start_intro(boss_id, stage_index)` when the scroll-stop begins (after the Warning screen). *(2026-11-03, Wave director 16 Rule 24: offsets from the wave-5 end E5 — field clear (`despawn_all` + bullet `clear_all`) at E5+60, WARNING at E5+90 for 150 ticks, scroll-stop and `start_intro` at E5+240, `boss_started` at E5+480.)* Only one boss exists at a time; a second `start_intro` while one lives is refused and logged. *(2026-11-03, wave 4, Online leaderboards / Boss rush (32):)* the stage argument is the boss's **home stage** (`home_stage`), so a boss-only rush stage (`waves = []`) gets the same `play_top`, hp, patterns and `Q_cap` as in the main game.
12. **Intro** lasts `intro_ticks` = 240: **entrance** ticks 0–179 (the boss descends from off-screen to its anchor with an ease-out, F9), then **hold** ticks 180–239 (the boss bar fills, the name plate shows). Sway and orbit time (`fight_t`) is 0 at the end of the hold.
13. During the Intro every part is **IMMUNE**: a hit returns *ignored* (Collision C4), does not count for the chain, and loses no hp. A part publishes a hurtbox only while its body intersects the field (Enemy Rule 9), so the laser and player bullets are visibly blocked by it. **No emitter is armed.** No enemy bullet is created by the boss.
14. During the Intro every body is **non-lethal** (`lethal = false`). The player cannot be killed by the boss descending onto them. *Why:* the descent is a 3 s unavoidable overlap risk for a player parked at the top, which would be unfair.
15. **Clearance gate.** At the end of the hold, if any Active player is within `r_pl + r_e + spawn_clearance` of any part body (checked with Collision's `spawn_is_clear` at the capsule's two ends and midpoint), the Intro **waits**: the hold repeats tick by tick until clear, for at most `intro_wait_max` = 180 ticks. After that the boss starts anyway (a player who parks inside the boss for 3 s dies by their own choice).
16. **`boss_started`** fires on the tick the Intro ends. It is the single moment when: bodies become lethal; the core and parts take their fight modes; all emitters are armed (Rule 27); hp is scaled for the player count (Rule 19); the Chain tracker's "boss alive" and Co-op's team chain begin; the fight clock starts.
17. **Phases (state machine, Rule 21 table).** The fight has three phases: **PARTS** (≥ 1 non-core part alive), **EXPOSED** (all non-core parts dead; core hp above its critical reserve), **CRITICAL** (core in the critical reserve). Phase changes are applied in `apply_results` (step 6c) and take effect for hurtbox/body modes on the **next** tick (Collision's mode snapshot).

**Core, armour and the critical reserve**

18. **Core modes.** In PARTS the core mode is `core_rule`: ARMOURED (`core_armor_pct`, default 25) or IMMUNE (hits ignored, not counted). In EXPOSED it is NORMAL. In CRITICAL it is ARMOURED at `critical_armor_pct` (20) until the window closes, then NORMAL (Rule 22). An armoured core's hp never drops below 1 (Collision C4).
19. **hp scaling** is read **once at `boss_started`**: `N` = Alive, Dead and Continue slots at that tick (Enemy F4's rule). `hp = (hp_base × hp_pct + 50) / 100` for every part and the core (Co-op F4, `hp_step` 50 %), integer maths. Patterns, speeds and the enrage clock are not scaled (Co-op F6). Nobody's join or leave changes a boss in play.
20. **Two-stage core.** The core's hp is split at the start into a **main** pool and a **critical reserve**:
    - `core_hp = scaled core hp`; `critical_hp = (core_hp × critical_pct + 50) / 100`; `core_main = core_hp − critical_hp`.
    - Collision's core target carries `core_main` as its hp in PARTS and EXPOSED. When Collision returns *destroyed* for the core in EXPOSED, the controller does **not** end the fight. It enters CRITICAL: the same `(id, generation)` is published next tick with `hp = critical_hp`, mode ARMOURED at `critical_armor_pct`. Overkill on the main pool is discarded. The *destroyed* result's `kill_credit(slot, CORE)` pays 0 (Scoring), so this causes no payout.
    - The armoured/immune core in PARTS cannot reach 0 main hp (armoured floors at 1; immune takes none). If an armoured core is chipped to 1 main hp while parts live, the first normal hit after EXPOSED enters CRITICAL.
    - Why a split: Collision resolves one hp number and can only floor it at 1 or 0. The split guarantees the critical band can never be skipped by one big hit.
21. **`is_critical()`** (what Critical Break reads) is true exactly when phase = CRITICAL and the core is alive, regardless of whether the window is still open.

**Critical window**

22. On entering CRITICAL, `critical_left` = `critical_window_ticks` (420, 7 s). It counts down by 1 per tick. While it is above 0 the core is ARMOURED at 20 %: hits count for the chain, deal `max(1, damage × 20 div 100)`, and the core stays at ≥ 1 hp. When it reaches 0 (`critical_window_closed` event), the core becomes NORMAL on the next tick and the next hit that takes its hp to 0 ends the fight (Rule 30). `is_critical()` stays true until the core dies. *Why 7 s and 20 %:* long enough to charge laser and bomb, with the player still earning chain and a little damage (about 3,100 hp of free time compared with a normal core: 7 s × 800 ref dps × 80 % armour reduction × 70 % uptime; about 5.6 s of fight at reference dps). The CB bonus has to be worth that cost (Scoring F4).
23. **Critical Break interface (CB (17) owns the trigger; see `critical-break.md`):** the controller exposes `is_critical()`, `critical_left`, `core_world_pos()`, `core_target_id()` (the core's part target id, 1000 + 0, used by CB to test that the last charge hit was on the core) and `critical_break_finish(slot) -> bool`. CB runs at step **6b** (`CriticalBreakCore.tick()`, after Collision/Bombs, before this controller's 6c) and calls `Chain.apply_critical_break` **before** `critical_break_finish`, so `boss_peak` includes the multiply before `boss_defeated` freezes it (2026-11-03). The call is valid only when the phase **at the start of the tick** was CRITICAL; otherwise it returns false and changes nothing. A valid call sets core hp to 0, runs the death sequence with `reason = CRITICAL_BREAK` and `killer_slot = slot`, and returns true. If a CB call and a normal *destroyed* arrive on one tick, the CB call is processed first.

**Part kills**

24. When Collision returns *destroyed* for a non-core part (credited slot `S`), the controller, in this order (`apply_results`, step 6c, in part index order when several die on one tick):
    1. Marks the part dead; it publishes no hurtbox or body from the next tick (a burnt-stump decoration remains).
    2. Stops all of the part's emitters with `owner_destroyed = true` (Pattern library: cancels lit flak fuses; bullets already in flight stay).
    3. Calls Chain `add_bonus(S, part_kill_chain = 5, "part_kill")`. The Chain tracker ignores it if `S` is not Active.
    4. Calls Bullet manager `request_cancel(circle(part_pos, R), cause_slot = S)` (requested in step 6c; applied at the next tick's step 5, a one-tick lag accepted 2026-11-03) with `R` = `part_cancel_radius` (**90 px**, unchanged from the prototype), or `last_part_cancel_radius` (**150 px**) if this is the last non-core part to die. Cancelled bullets become score items credited to `S`.
    5. Emits `boss_part_destroyed(part_id, pos, slot, last)`. If `last`, also emits `boss_core_exposed`.
    6. Recomputes intensity (Rule 25) and queues the core mode change for the next tick.
    Scoring's 5,000 comes from Collision's `kill_credit(S, PART)`, not from this system. **The prototype's `screen_flash_requested(0.12)` is removed** (art bible: Critical Break is the only flash).
25. **Intensity** `I` = non-core parts destroyed ÷ non-core parts total (F4), recomputed at each part kill and fed to every living emitter every tick. It replaces `rage()`. Patterns gate and scale on it through Pattern library F3 (`min_intensity`, `max_intensity`, `*_at_full`). A part kill changes `I` in one step and only upward, so no gate flickers (Pattern library edge case). **Escalation lag rule (data lint):** any pattern whose gate opens at `I` > 0 needs `start_delay ≥ 18` ticks (the library's `t_react`-sized reaction time), so the relief from the cancel is never followed by an instant volley.
26. Dead parts keep contributing to `I` for ever. There is no regrow, heal or part respawn.

**Firing**

27. At `boss_started` every emitter of every living part is started (armed). **The Enemy fire-zone rule (Enemy Rule 18) does not apply to bosses:** a boss is on screen for the whole fight, so emitters do not arm/retire by muzzle position. Instead the data lint requires every muzzle to be inside the fire zone `[4, 356] × [play_top + 4, 636]` at every possible sway/orbit position (Rule 28). A part's emitters stop only when the part dies, the fight ends, or the controller is destroyed. Emitter origin = part world position + `muzzle_offset`; centre = boss centre.
28. **Placement lint (analytic, per `play_top` 48 and 72):** for every circle `i`: `x_min = anchor.x − |amp.x| + min_local_x − r_h ≥ 4`, `x_max = anchor.x + |amp.x| + max_local_x + r_h ≤ 356`, and the highest point stays below `play_top + 4`. Orbiting parts use `±orbit_radius`.
29. **Tells.** Every boss emitter exposes the library's `next_volley_in(emitter)` (Enemy amendment 1); the presentation plays a 12-tick windup on the part (V2 below). Aim-lock patterns use the library's own lock tell.

**Ending the fight**

30. **Killed.** When Collision returns *destroyed* for the core in CRITICAL (window closed, NORMAL mode) the fight ends with `reason = KILLED`, `killer_slot` = the credited slot.
31. **Death sequence** (`Dying`, `death_ticks` = 180). On the tick the fight ends (any reason except TIMEOUT), in this order:
    1. Every emitter stops with `owner_destroyed = true`.
    2. Bullet manager `request_cancel(whole screen, cause_slot = killer_slot)`, applied at the next tick's step 5: every enemy bullet is cancelled and Powerups keeps up to `items_per_cancel_cap` (100) stride-sampled gems for the killer (Powerups F3).
    3. All hurtboxes and bodies are removed from the next publication (the boss is no longer targetable or lethal).
    4. `boss_defeated(reason, killer_slot)` is emitted **immediately** (Chain freezes, Scoring pays the boss value, Session starts the stage-clear flow).
    5. The explosion sequence plays for `death_ticks`; `boss_gone` fires at the end. The Wave director clears the stage at `stage_cleared = max(boss_gone, boss_defeated + 90)`, with a watchdog that forces `stage_cleared` at `boss_defeated + 360` if `boss_gone` never arrives (Wave director 16 Rule 24, 2026-11-03).
32. **Critical Break finish** uses the same sequence with `reason = CRITICAL_BREAK`. CB (17) owns its own cancel/flash; this sequence still runs the whole-screen cancel (a second cancel on the same bullets is a no-op, Bullet manager edge case).
33. **Enrage and timeout (the stall rule, decision).** The fight clock `fight_ticks` counts +1 per tick while the phase is PARTS, EXPOSED or CRITICAL **and** at least one slot is Active **and** the game is not paused (F5).
    - At `fight_ticks ≥ enrage_start_ticks` the boss is **enraged** (`boss_enraged` once): intensity becomes `I_eff = max(I, I_enr)`, with `I_enr` ramping 0 → 1 over `enrage_ramp_ticks` (600). The ramp is monotonic. `boss_cap_hold_allowed()` becomes false and Scoring's cap-hold streak **resets** to 0 (anti-stall, Scoring F6; decided 2026-11-03) (Scoring pays no cap-hold streak while it is false).
    - At `fight_ticks ≥ enrage_start_ticks + timeout_after_enrage` (1,200) the boss **withdraws**: the fight ends with `reason = TIMEOUT`, `killer_slot = none`. Emitters stop (`owner_destroyed = true`), the enemy pool is cleared with **no items** (Bullet manager Rule 15a), hurtboxes and bodies are removed, `boss_defeated(TIMEOUT, none)` fires, and the boss flies off the top at `retreat_speed` (2.5 px/tick) for at most 180 ticks. **No boss value is paid** (Scoring S4 skips TIMEOUT). Because the event is still `boss_defeated`, Session, Chain (freeze and record), the tally and the ending flow need no new path; a final-stage timeout still ends the run with the ending.
    - *Why this and not "escape without clearing":* a boss that escapes and leaves the stage open would need a new Session path (what is the run's end state?). Using `boss_defeated(TIMEOUT)` keeps every flow intact and removes only the thing a staller wants (the 100,000 boss value, and later cap-hold pay).
34. **If a kill and the timeout land on the same tick**, KILLED wins (the controller applies hits first, then the clock).

**Laser and shot blocking**

35. **Shots:** the Bullet manager decides player-bullet hits on hurtboxes. A bullet takes the hurtbox with the smaller entry point (Bullet manager edge case). No special boss rule.
36. **Laser (interface to Plane kits 11, [GDD](plane-kits-lancer-leech.md)):** `Boss.laser_query(x, half_width, y_origin) -> {part_index, y_hit, mode}` or `none`. The beam is a vertical column. A living, published part is a **candidate** if some hurtbox circle `i` satisfies `|c_i.x − x| < r_h,i + half_width` and `c_i.y − r_h,i < y_origin`. The **first part in the column** is the candidate with the largest `bottom = c_i.y + r_h,i` (closest to the plane); ties go to the lowest part index. `y_hit = min(y_origin, bottom)`. The kit sends its damage tick to that part only, and draws the beam to `y_hit`.
    - An ARMOURED part is hit normally (counts). An IMMUNE part (the Intro, a shielded core) **still blocks**: the beam stops at it and the hit returns *ignored* (no chain).
    - Dead parts do not block. The hull never blocks.
    - Drone lasers (Lancer parked drones) use the same query for their own column.
37. **Bombs:** a bomb sends ordinary damage events to every published part (Bombs 12 owns the damage and any `bomb_part_mult`). The prototype's `Boss.apply_bomb` is removed. Intro and IMMUNE parts return *ignored*.

**Co-op**

38. In co-op the boss is the same boss with more hp (Rule 19). Boss patterns, timers and the part-kill rewards are not scaled. Kill credit follows Collision's rotation. The chain bonus `+5` goes to the credited slot only. The boss value is paid in full to each eligible slot (Scoring).

**Performance**

39. The controller allocates nothing per tick: arrays of ≤ 6 parts and ≤ 8 hurtboxes are preallocated. Placement costs ≤ 12 `sin`/`cos` per tick.

**Training boss and boss rush** *(added 2026-11-03, wave 4)*

40. **`TrainingBossDef`** (Tutorial (30), drills only; a stage may not use it — lint): wraps a `BossDefinition` with `drill_hp_pct` (25, applied after `coop_hp_scale`), fire limited to the boss's preview-row patterns, `start_state = CRITICAL` (break drill) and `cb_only` (after `critical_window_ticks` the core cannot die from shots; only a Critical Break ends it). Events are unchanged; Tutorial listens to `boss_core_exposed`, `boss_enraged` (hint `enrage_icon`) and `critical_break_landed`.
41. **Boss rush (32):** `boss_defeated` with reason KILLED or CRITICAL_BREAK feeds the Save record `bosses_beaten` (unlocks Single Boss); TIMEOUT does not.

### States and Transitions

Boss states:

| State | Targetable | Lethal | Emitters | Clock | → Next | Trigger |
|---|---|---|---|---|---|---|
| **Idle** | no | no | none | no | Intro | `start_intro` |
| **Intro** | yes while intersecting the field, all IMMUNE | no | none armed | no | Parts | 240 ticks done and clearance gate clear (or 180 extra ticks) |
| **Parts** | yes; core ARMOURED/IMMUNE | yes | armed per Rule 27 | yes | Exposed | last non-core part destroyed |
| **Exposed** | yes; core NORMAL (main pool) | yes | armed | yes | Critical | core main pool destroyed |
| **Critical** | yes; core ARMOURED 20 % → NORMAL when window closes | yes | armed | yes | Dying (reason KILLED / CRITICAL_BREAK) | core destroyed; or CB finish |
| **Dying** | no | no | stopped | no | Gone | `death_ticks` (180) done |
| **Retreating** | no | no | stopped | no | Gone | off-screen or 180 ticks |
| **Gone** | no | no | none | no | Idle | after `boss_gone`; slot freed, generation +1 |

Any of Parts, Exposed or Critical → Retreating on timeout (reason TIMEOUT). Dying and Retreating are entered only once.

Overlay flags: **Enraged** (set once at `enrage_start_ticks`, cleared only by Gone); **Critical window open** (Critical state, `critical_left > 0`).

Per part: **Alive → Dead** (final). Core: **Armoured/Immune → Normal → Critical reserve (Armoured) → Normal (window closed) → Dead**.

**Tick order for this system** (extends ADR-0001 and Enemy's 3b / 6a; → ADR for the core wiring):
1. *(Wave director calls `start_intro` before the managers.)*
2. **3c. `BossController.tick()`** (after `EnemyManager.tick()`): advance `intro_t` or `fight_t`; evaluate placement (F1); apply queued mode changes from last tick; scale hp at `boss_started`; start/stop/update emitters with origin, centre and `I_eff`; publish hurtboxes to the Bullet manager and bodies to Collision.
3. Step 4 (Patterns), steps 5–6 (Bullet manager, Collision referee) run as usual, then **6a. `EnemyManager.apply_results()`** (Enemy 10) *(2026-11-03, wave 3b)*.
4. **6b. `CriticalBreakCore.tick()`** (Critical Break 17, 2026-11-03): evaluate `cb_armed`, resolve bombs landing on the core, call `Chain.apply_critical_break`, issue CB's own full-screen cancel, then `critical_break_finish(slot)`. Runs before 6c, so a break beats a same-tick normal kill (Rule 23).
5. **6c. `BossController.apply_results()`:** take Collision's hit results; set part hp; handle CB requests; run part kills (Rule 24) in part index order; core main → Critical; window and clock +1; enrage and timeout checks; end of fight (Rule 30 to 33). Cancel requests made here are consumed on the next tick (Bullet manager Rule 15).

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Collision (6) — GDD | → bodies `{id, gen, a, b, r_e, p_prev, p_cur, hp, mode, armor_pct, kill_class (PART / CORE), lethal, on_boss = true}`; ← `hit_results` incl. `hp_after`; ← `spawn_is_clear`; ← `death_fire_hold` (via the library) | Referee applies damage; boss sets the core mode, `armor_pct` and the main/reserve hp |
| Bullet manager (3) — GDD | → `set_hurtboxes([id, gen, pos, prev, radius])` (≤ 8); `request_cancel(circle \| screen, cause_slot)`; enemy-pool clear without items on TIMEOUT | |
| Pattern library (9) — GDD | → per emitter: patterns, origin, centre, intensity `I_eff`, start, stop(owner_destroyed); ← `next_volley_in(emitter)` | Part ids are the `owner_id` of the RNG seed |
| Enemy and AI (10) — GDD | ← shares `EmitterDef`, hurtbox helpers and `hurt_pad`; Boss is exempt from the fire-zone rule; budget 8 hurtboxes | Boss owns its parts and does not use `EnemyPathDef` |
| Chain tracker (7) — GDD | → `boss_started`, `add_bonus(slot, 5, "part_kill")`, `boss_defeated(reason, killer)`; targets marked `on_boss` | Chain appends the record on `boss_defeated`, including TIMEOUT |
| Scoring (8) — GDD | (via Collision) `kill_credit(slot, PART)` 5,000, `CORE` 0; → `boss_defeated(reason)`; ← `boss_cap_hold_allowed()` read by Scoring | S4 is not paid when `reason = TIMEOUT` |
| Co-op (18) — GDD | ← `hp_pct(N)` at `boss_started` | Applied to every part and the core; not to patterns or the clock |
| Game events and session (1) — GDD | ← slot states, player count, pause; → events (below) | Not ticked while paused |
| Player plane (5) — GDD | ← positions for `spawn_is_clear` and the clearance gate | |
| Plane kits (11) — [GDD](plane-kits-lancer-leech.md) | ← `laser_query(x, half_width, y_origin)`; → read-only `targetable_parts()` list `[(id, gen, pos, hurtbox_radius, mode)]` for Leech magnets and homing | |
| Bombs (12) — [GDD](bombs.md) | bomb damage events to published parts (`bomb_part_pct` 60 on PART, cap 1,000 per target per bomb; bomb hits never count for the chain) | |
| Critical Break (17) — [GDD](critical-break.md) | → `is_critical()`, `critical_left`, `core_world_pos()`, `core_target_id()`; ← `critical_break_finish(slot)` (called at step 6b after `Chain.apply_critical_break`) | CB owns its trigger |
| Wave director (16) — [GDD](wave-and-stage-director.md) | ← `start_intro(boss_id, stage_index)` at E5+240; guarantees `despawn_all` and an enemy-bullet clear at E5+60, WARNING E5+90; → `boss_gone` (`stage_cleared = max(boss_gone, boss_defeated + 90)`, watchdog `boss_defeated + 360`) | |
| Boss power budget (15) — [GDD](boss-power-budget.md) | ← per-boss mechanic list; reads `tags[]` on parts and emitters | Wave N previews mechanic N (index decision) |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | ← which boss belongs to which stage (stage 1 Fortress, stage 2 Jet Carrier; `era_for_stage`) | One stage per era |
| HUD (20) — [GDD](hud.md) | → `boss_bar_state()` (F7), part-kill / core-exposed icons, enrage state and `timeout_left` | |
| VFX (25) — [GDD](vfx-and-screen-feedback.md), Audio (24) — [GDD](audio.md), Parallax (23) — [GDD](parallax-and-environment.md) | → `boss_*` events, per-part damage state, `warning_started` | Presentation only. VFX: death sequence is class BOSS_DEATH (40) in the shared 150 pool. Parallax: boss arena plates, grade and vignette (V4). Audio: Warning siren asset (A1) |
| Powerups (13) — [GDD](powerups-and-drops.md) | (cancel items via Bullet manager; bosses drop no carrier items) | |

**Events (bus events; Game events and session (1) Rule 13 carries the signal list, which grows with each GDD):** `boss_intro_started(boss_id)`, `boss_started`, `boss_part_destroyed(part_id, pos, slot, last)`, `boss_core_exposed`, `boss_phase_changed(phase)`, `boss_critical_started`, `boss_critical_window_closed`, `boss_enraged` (also read by Tutorial (30) for the `enrage_icon` hint), `boss_defeated(reason, killer_slot)`, `boss_gone`. `reason` ∈ KILLED, CRITICAL_BREAK, TIMEOUT.

All listed systems now have GDDs *(2026-11-03, wave 3b)* (11, 12, 13, 15, 16, 17, 19, 20, 23, 24, 25); the contracts above are what this GDD expects and match them.

> Decided under auto-approve (2026-11-03): integer hp and percentages; `critical_pct` 15 with a two-stage core; critical window 420 ticks at 20 % armour; no screen flash on part kills; part-kill cancel 90 px and 150 px for the last part; +5 chain to the credited slot; intensity = parts destroyed ÷ parts (no rage); unique part ids; bosses exempt from the fire-zone rule; intro 240 ticks, all parts IMMUNE and non-lethal, with a clearance gate; hull never blocks the laser; immune parts do block it; enrage at 1.75 × the expected fight, timeout 1,200 ticks later as `boss_defeated(TIMEOUT)` with no boss value; geometry migrated ×0.75; no per-part hp bars.

## Formulas

Conventions: px; 60 ticks/s; integer ticks; `play_top` 48 (1–2P) or 72 (3–4P); `y_shift = play_top − 48`; canvas 360 × 640; positions are closed forms of an integer tick, never accumulated.

**F1. Placement (boss and parts)**

`C(t) = (A.x + a.x · sin(2π·t / P.x), A.y + y_shift + a.y · sin(2π·t / P.y))` (an axis with `P = 0` or `a = 0` contributes 0)
`local_i(t) = offset_i` for a fixed part; `local_i(t) = R_i · (cos θ, sin θ)`, `θ = φ_i + 2π·t / O_i` for an orbiting part (angles increase clockwise on screen)
`world_i(t) = quant16(C(t) + local_i(t))`, `quant16(v) = round(v · 16) / 16`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Fight tick | `t` | int | 0 … timeout | Ticks since `boss_started` (the sway phase starts at 0) |
| Anchor | `A` | Vector2 px | x 180, y 100–160 | Boss definition |
| Sway amplitude / period | `a`, `P` | px, int ticks | 0–100, 0 or 200–900 | Per axis |
| Orbit radius / period / phase | `R_i`, `O_i`, `φ_i` | px, int ticks, rad | 40–60, 250–500, 0–2π | Per orbiting part (`orbit_phase_deg` in data) |

**Output Range:** world positions inside the field (Rule 28 lint). **Example (Jet Carrier, anchor (180,120), amp (97.5, 11.25), periods (419, 222); pod_1 orbit 54, period 314, phase 0°):** at `t = 157`: `C = (249.07, 109.15)`; `θ = 2π·157/314 = π`, local `(−54, 0)`; pod_1 = **(195.07, 109.15)**, quantized (195.0625, 109.125). Fortress (anchor (180,130), amp (67.5, 0), period (754, 0)) at `t = 188`: core x = 180 + 67.5 · sin(2π·188/754) = 247.499 → **247.5**; at `t = 377`: 180.

*(Tolerance in tests: ±0.05 px; the quantization removes platform differences in `sin`.)* *(2026-11-03, ADR-0003)*: `sin`/`cos` here come from the shipped `SimMath` table (phase `2π·t/P` in binary angle units), never the platform `sin`, and every published coordinate is rounded to 1/16 px (AC-44), so results are identical on Windows, Linux and Web.

**F2. Hurtboxes per part and budget**

`r_h = r_e + hurt_pad` (2). If `spine_half ≤ r_e / 2`: one circle, radius `r_e + spine_half + hurt_pad`. Otherwise `k` = the smallest integer ≥ 2 with `2·spine_half / (k − 1) ≤ 1.5 · r_h`. Budget: `Σ k ≤ boss_hurtbox_budget` (8).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Body radius | `r_e` | px | 7–26 | Lethal radius (Collision range 2–40) |
| Spine half | `spine_half` | px | 0–16 | 0 for circles |
| Hurt pad | `hurt_pad` | px | 0–4 (2) | Enemy knob |
| Circles | `k` | int | 1–4 | |

**Output Range:** 1–4 per part. **Examples:** Fortress core `r_e` 13.5, spine 12.75: `r_h` 15.5, k = 2 gives 25.5 > 23.25, so **k = 3** (spacing 12.75). Engine `r_e` 8.25, spine 3.0 ≤ 4.125 → **k = 1**, radius 13.25. Jet wing `r_e` 9, spine 7.5: `r_h` 11, k = 2 gives 15 ≤ 16.5 → **k = 2**. Totals: Fortress 3 + 1 + 1 + 1 + 1 = **7**; Jet core 1 + pods 3 + wings 4 = **8**; Plasma 1 + 4 = **5**.

**F3. hp scaling and the core split**

`hp(N) = (hp_base × (100 + hp_step × (N − 1)) + 50) / 100`
`critical_hp = (core_hp(N) × critical_pct + 50) / 100`
`core_main = core_hp(N) − critical_hp`
All integer division.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Players | `N` | int | 1–4 | Slots Alive, Dead or Continue at `boss_started` |
| Step | `hp_step` | int % | 0–100 (50) | Owned by Co-op |
| Critical share | `critical_pct` | int % | 5–30 (15) | Per boss |
| Base hp | `hp_base` | int | 1–30,000 | Per part |

**Output Range:** hp ≥ `hp_base`; `critical_hp` ≥ 1; `core_main` ≥ 1. **Example (Fortress core 16,500):** N = 1 → 16,500, critical 2,475, main 14,025. N = 2 → 24,750, critical 3,713, main 21,037. N = 3 → 33,000, critical 4,950, main 28,050. N = 4 → 41,250, critical 6,188, main 35,062. Turret 2,400 at N = 4 → 6,000.

**F4. Intensity**

`I = destroyed_noncore / total_noncore`
`I_enr = clamp((fight_ticks − enrage_start) / enrage_ramp, 0, 1)`
`I_eff = max(I, I_enr)`, clamped to [0, 1], passed to every living emitter every tick.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Parts | `total_noncore` | int | 1–5 | Fixed at load |
| Ramp | `enrage_ramp` | int ticks | 300–1,200 (600) | |

**Output Range:** 0–1, never decreasing. **Example (Fortress, 4 non-core parts):** 0 → 0.25 → 0.5 → 0.75 → 1.0. Spiral interval `lerp(7, 3, I)` → 7, 6, 5, 4, 3 ticks (Pattern library F3). At `fight_ticks` 5,000 with `enrage_start` 4,700: `I_enr = 300/600 = 0.5`, so with I = 0.25 → `I_eff` = **0.5**.

**F5. Fight clock and enrage**

`fight_ticks' = fight_ticks + 1` if `phase ∈ {Parts, Exposed, Critical} AND any slot Active AND not paused`, else unchanged.
`enraged = fight_ticks ≥ enrage_start`; `timeout = fight_ticks ≥ enrage_start + timeout_after_enrage`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Enrage start | `enrage_start` | int ticks | 3,000–9,000 | Computed by F6 and stored per boss |
| Timeout after enrage | `timeout_after_enrage` | int ticks | 600–2,400 (1,200) | |

**Output Range:** `fight_ticks` ≥ 0. **Example (Fortress):** enrage at 4,700 (78.3 s), full ramp at 5,300, timeout at **5,900** (98.3 s).

**F6. hp budget and enrage placement** (authoring check, a unit test over `data/bosses/`)

`T_parts = ceil(Σ part_hp × 60 × 100 / (ref_dps × ref_uptime_pct))`
`T_core = ceil(core_main × 60 × 100 / (ref_dps × ref_uptime_pct))`
`T_fight = T_parts + T_core` (the critical window is excluded: the fight ends there by Critical Break or by normal damage)
`enrage_start = round100(enrage_mult × T_fight)`
**Rules:** `2,400 ≤ T_fight ≤ 3,600` (40–60 s; Scoring assumes about 60 s), and `enrage_start` in the data equals the formula. Both are errors in the data lint.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Reference dps | `ref_dps` | int units/s | 400–1,200 (**800**) | Owned by Plane kits (11): one competent player, 2 drones, on target (Kits "Reference DPS for content budgets"). Same value Enemy (10) uses |
| Reference uptime | `ref_uptime_pct` | int % | 50–90 (**70**) | Share of time one competent player's fire lands (matches Enemy's `exposure_margin` 1.4 ≈ 1/0.71) |
| Enrage multiple | `enrage_mult` | float | 1.5–2.5 (**1.75**) | Slack for slow or learning play |

**Output Range:** `T_fight` 2,400–3,600. **Examples (denominator 800 × 70 = 56,000):**
- **Fortress** (parts 2 × 2,400 + 2 × 3,200 = 11,200; core 16,500, main 14,025): `T_parts` = 11,200 × 6,000 / 56,000 = **1,200**; `T_core` = ceil(1,502.7) = **1,503**; `T_fight` **2,703** (45.05 s); enrage = round100(4,730.25) = **4,700**.
- **Jet Carrier** (parts 3 × 1,900 + 2 × 4,100 = 13,900; core 19,700, main 16,745): ceil(1,489.3) + ceil(1,794.1) = 1,490 + 1,795 = **3,285** (54.75 s); enrage = round100(5,748.75) = **5,700**.
- **Plasma Ring** (Target; parts 4 × 2,900 = 11,600; core 20,800, main 17,680): ceil(1,242.9) + ceil(1,894.3) = 1,243 + 1,895 = **3,138** (52.3 s); enrage = round100(5,491.5) = **5,500**.

(Re-based 2026-11-03: hp ×8/3 against the old ref_dps 300, rounded to 100; the fight lengths and enrage ticks are unchanged within 2 ticks.)

**F7. Boss bar**

`total_max = Σ part_hp_scaled + core_hp_scaled`
`remaining = Σ living part hp + core_main_hp + core_reserve` (reserve = `critical_hp` until Critical, then the live value)
`bar_permille = max(1, remaining × 1000 / total_max)` while the boss is alive
`display_pct = (bar_permille + 5) / 10`
`phase_tick = core_hp_scaled × 1000 / total_max` (boundary between "parts" and "core"); `critical_notch = critical_hp × 1000 / total_max`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Permille | `bar_permille` | int | 1–1000 | HUD fill |
| Display | `display_pct` | int | 1–100 | Numeric backup |

**Output Range:** monotone non-increasing. **Example (Fortress N = 1, total 27,700):** full → 1000 (100 %). All parts dead, core untouched → 16,500 / 27,700 → **595** (60 %). `phase_tick` = **595**, `critical_notch` = 2,475 × 1000 / 27,700 = **89**.

**F8. Laser column query** — see Rule 36. **Example (Fortress at `t = 0`, `play_top` 48, laser half-width 3, `y_origin` 500):** x = 141 (above the left engine at (141, 146.5), radius 13.25): engine bottom = 146.5 + 13.25 = **159.75** → hits the left engine. x = 180: core circles at (167.25 | 180 | 192.75, 125.5), `r_h` 15.5, bottom 141 (all one part) → hits the core at **141**. With the left engine dead and x = 141: core circle (167.25) is 26.25 away > 15.5 + 3 = 18.5 → **none** (the beam passes).

**F9. Cancel and entrance**

Part-kill cancel: `|p_i − c|² ≤ (R + r_vis)²` (Bullet manager F9), `R` 90 (150 for the last part). **Example:** part at (141, 146.5), orb `r_vis` 4: at 94 px cancelled, at 95 px survives. Last part: 154 px cancelled, 155 survives.

Entrance: `y0 = play_top − 8 − B`, where `B = max_i (local_y_max,i + r_h,i)` over the part circles (orbit parts use `R_i`); `y(a) = y0 + (A.y + y_shift − y0) × (1 − (1 − a/E)²)` for intro tick `a` in 0…`E` = 180; x = `A.x`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Off-screen margin | 8 | px | 4–24 | Enemy's `spawn_offscreen_margin` |
| Entrance ticks | `E` | int | 120–240 (180) | |

**Output Range:** the whole body is outside the field at `a = 0`. **Example (Fortress, B = 29.75 from the engine: 16.5 + 13.25; `play_top` 48):** `y0` = 48 − 8 − 29.75 = **10.25**; `a = 90`: 10.25 + 119.75 × 0.75 = **100.06**; `a = 180`: **130**. Jet: B = 54 + 11 = 65, `y0` = **−25**.

**F10. Prototype migration (one-time, data only)**

| Parameter | Rule |
|---|---|
| Anchor | x 240 → 180; y unchanged |
| Offsets, orbit radii, sway amplitude, part sizes | × 0.75 |
| Circle part (prototype `size.x` = radius) | `r_e` = radius × 0.75; `spine_half` 0 |
| Rect part (full width × height) | capsule along the long side: `r_e` = short side × 0.75 / 2; `spine_half` = long side × 0.75 / 2 − `r_e`. **Exception:** Jet wings use `r_e` 9 (thicker than 4.5) to fit 2 hurtboxes |
| Sway / orbit | rad/s `w` → period ticks = round(2π × 60 / w) |
| `armor_damage_mult` 0.25 | `core_armor_pct` 25 |
| `critical_hp` 200 (absolute) | `critical_pct` 15 |
| `max_hp` (float) | `hp_base` (int), re-budgeted by F6 |
| `part_name` | unique `id` + `name_key` |

| Boss | Part | Prototype | Migrated |
|---|---|---|---|
| Fortress | anchor / sway | (240,130) / amp (90,0) f 0.5 | (180,130) / amp (67.5, 0), period (754, 0) |
| Fortress | core | rect 70 × 36 @(0,−6), hp 1,200 | capsule `r_e` 13.5, spine 12.75 (horizontal) @(0,−4.5), hp **16,500** |
| Fortress | turrets L/R | radius 14 @(∓95, 12), hp 120 | `r_e` 10.5 @(∓71.25, 9), hp **2,400** |
| Fortress | engines L/R | rect 22 × 30 @(∓52, 22), hp 160 | capsule `r_e` 8.25, spine 3.0 (vertical) @(∓39, 16.5), hp **3,200** |
| Jet Carrier | anchor / sway | (240,120) / amp (130,15) f (0.9,1.7) | (180,120) / amp (97.5, 11.25), periods (419, 222) |
| Jet Carrier | core | radius 34, hp 1,400 | `r_e` 25.5, hp **19,700** |
| Jet Carrier | pods ×3 | radius 12, orbit 72, w 1.2, phases 0 / 120° / 240°, no hp (default 100) | `r_e` 9, orbit 54, period 314, hp **1,900** |
| Jet Carrier | wings L/R | rect 44 × 12 @(∓70, −14), hp 150 | capsule `r_e` 9, spine 7.5 (horizontal) @(∓52.5, −10.5), hp **4,100** |
| Plasma Ring *(Target)* | anchor / sway | (240,150) / amp (120,40) f (0.6,1.2) | (180,150) / amp (90, 30), periods (628, 314) |
| Plasma Ring | core (IMMUNE) | radius 30, hp 1,600 | `r_e` 22.5, hp **20,800** |
| Plasma Ring | shields ×4 | radius 16, orbit 62, w 0.8, phases 0 / 90 / 180 / 270°, hp 140 | `r_e` 12, orbit 46.5, period 471, hp **2,900** |

**Pattern bindings (Boss power budget 15, 2026-11-03):** the Jet Carrier core gains emitter 1 `core_lock_fan` (aim-locked fan: count 7, spread 0.1875, interval 120, speed 150, `lock_ticks` 30, gate [0.4, 1.0], `start_delay` 48); the Fortress `core_rage_ring` is bound as the core variant of mechanic `m2_engine_ring` (gate [1, 1]). Mechanic lists live in `boss-power-budget.md`.

The prototype hp values (1,200 core, 120–160 parts) give a fight of only a few seconds at the Kits reference dps of 800 (about 10 s at the old provisional 300); F6 re-budgets them (re-based to 800 on 2026-11-03, hp ×8/3). Pattern values (spiral arms 2, intervals, wall counts) follow Pattern library F10.

**F11. Stall bound** (justification for the enrage placement)

`cap_hold_pay(s) = Σ_{k=1..s} hold_unit × min(k, hold_ramp_s)` (Scoring F6, 500 and 30), with `s` = seconds held at 999.
**Example (Fortress, 999 reached at about 15 s):** natural kill at 55 s → 40 s held → 500 × (465 + 10 × 30) = **382,500**. Stall to enrage at 78.3 s → 63 s held → 500 × (465 + 33 × 30) = **727,500**. Maximum extra from stalling: about **345,000** (11.5 % of `extend_unit`); after `enrage_start` no cap-hold is paid. With no clock the extra was unbounded.

> Decided under auto-approve (2026-11-03): closed-form 1/16 px placement; ref uptime 70 %; `enrage_mult` 1.75; `timeout_after_enrage` 1,200; enrage ramp 600; the F10 migration table and re-budgeted hp; thicker Jet wings (9 px radius); core 15 % critical share.

## Edge Cases

**Intro**
- **If a player is inside a part's clearance at the end of the hold**, the Intro waits tick by tick, at most 180 ticks, then `boss_started` fires anyway.
- **If a player joins during the Intro**, they count in `N` at `boss_started`.
- **If the game is paused during the Intro**, no tick runs; `intro_t` freezes.
- **If `start_intro` is called while a boss is alive**, it is refused and logged.
- **If a hit lands on a part during the Intro**, the result is *ignored*; no chain, no hp loss, no armour spark (immune ping).
- **If the Wave director fails to clear enemy bullets before the Intro**, the name plate may overlap bullets. The Wave director must clear them (Interaction row); Boss does not clear them itself. In debug builds a warning logs when `enemy_bullet_count > 0` at `start_intro`.

**Part kills**
- **If two parts die on one tick**, they are processed in part index order; each gets its own +5, cancel and event. The `last` flag goes to the one processed when no non-core part remains; only that cancel uses 150 px.
- **If the credited slot is not Active** (Dying, Continue), the +5 chain bonus is ignored by the Chain tracker; the cancel items and `kill_credit` still go to that slot.
- **If a part dies on the tick the player that killed it dies**, `chain_hit` and the bonus arrive before the drop (Phase A before Phase B); the cancel still runs, then the death clear.
- **If a part dies with lit flak fuses**, its fuses are cancelled (`owner_destroyed`).
- **If an orbiting part dies**, its orbit slot stays empty; the other pods keep their own phase.
- **If a part is hit on the tick another shot destroys it**, later events are *ignored* and do not count (Collision C5).

**Core and critical**
- **If the core takes a hit that would exceed the main pool**, the main pool is *destroyed*, the excess is discarded, and the core enters Critical with the full `critical_hp`.
- **If the armoured core is chipped to 1 main hp while parts live**, hits still count; when the last part dies the first normal hit enters Critical.
- **If an IMMUNE core is hit while shields live**, the result is *ignored* and does not count for the chain. The team chain may end (Co-op edge case); the shields are always hittable, so the boss never leaves the player without a countable target.
- **If the critical window closes while hits are in flight**, the mode change applies from the next tick (snapshot). The hit on the closing tick still deals 20 %.
- **If the core takes damage in Critical larger than `critical_hp` during the window**, the core stays at 1 hp (armoured floor); hits still count.
- **If a CB request arrives on a tick that began in Exposed**, `critical_break_finish` returns false, changes nothing and logs.
- **If a CB request and a lethal normal hit arrive on one tick and the window is closed**, the CB request is processed first and wins.
- **If a CB request arrives after the window closed but the core is alive and in Critical**, it is valid (`is_critical()` stays true).
- **If all players are Dead or in Continue during Critical**, the window still counts (it is boss time, not player time); the fight clock does not.

**Enrage and timeout**
- **If every slot is Dead or in Continue**, `fight_ticks` freezes. If they all end Inactive, the run is over.
- **If a player continues, joins or respawns**, the clock resumes at once; it does not rewind.
- **If the boss times out during the Critical window**, the fight ends as TIMEOUT; no CB is possible after.
- **If the timeout and a kill land on the same tick**, KILLED wins.
- **If `enrage_start` is reached during Intro hold**, impossible: the clock does not run before `boss_started`.
- **If a boss is killed during the enrage ramp**, `I_eff` is irrelevant after the kill; nothing is paid differently except that cap-hold stops at enrage start.
- **If the enrage ramp pushes a gated pattern across its gate**, the library restarts that pattern's `start_delay` (≥ 18 ticks of warning); the ramp is monotonic, so each gate crosses once.
- **If TIMEOUT happens on the final stage**, `boss_defeated(TIMEOUT)` still drives Session to the ending; the run counts as a clear (decision; Open Question 4).

**Death sequence**
- **If the lethal hit on a player and `boss_defeated` land on the same tick**, Collision Phase A runs first: the player loses the life, then the boss dies (Session AC-34).
- **If the boss is destroyed while the player's bullets are still in flight**, they hit nothing (no hurtboxes) and fly off.
- **If a bomb is active on the boss's death tick**, the whole-screen cancel and the bomb's own cancel are one cancel for each bullet (Bullet manager edge case: credited to the first request).
- **If the fight ends while the stage-clear flow runs**, no further boss events fire; `boss_gone` arrives once.

**Movement and geometry**
- **If parts overlap** (Jet wings and pods), nothing happens: bodies do not collide with each other. Hurtbox selection follows the Bullet manager (smaller entry point). The laser takes the part with the lowest bottom.
- **If a player is above or beside a part**, there is no sweep problem: bodies are swept capsules (Collision C1).
- **If the boss's sway carries a part past the field edge**, impossible: the lint (Rule 28) rejects the data.
- **If a 3rd player joins during the fight**, `play_top` does **not** change: it is latched at `stage_started` / `wave_started` (Co-op Rule 2, decided 2026-11-03 wave 4), so the boss never shifts mid-fight; the new `play_top` applies from the next stage. `y_shift` is read at `start_intro` and is constant for the fight.
- **If a hull is drawn over a part**, parts draw above the hull (art bible 5.8).

**Laser and shots**
- **If the laser column straddles two parts**, only the closer one (largest bottom) takes the tick.
- **If the laser origin is inside a hurtbox** (the plane touches a part without dying, e.g. during invulnerability), `y_hit = y_origin` and the part takes the tick.
- **If a boss part is IMMUNE**, the laser stops at it and deals nothing, but the laser's invulnerability hold still counts for the plane (Collision).

**Co-op**
- **If `N` changes after `boss_started`**, hp is unchanged (Co-op Rule 14).
- **If one player never hits the boss**, Co-op's team chain stays off (intended pressure).
- **If four players kill parts**, `+5` goes to the credited slot only; the cancel's items go to the same slot.

**Data and performance**
- **If a boss definition fails the lint** (two cores, 7 parts, 9 hurtboxes, duplicate ids, a non-whole percent), debug builds refuse to start; release builds skip the boss and log an error, and the Wave director skips to `boss_gone`.
- **If the Bullet manager pool is full**, the library refuses volleys; the boss is unaffected (Pattern library edge case).
- **If the pattern validator's N_scene at full intensity exceeds 1,700**, the data lint fails (Pattern library F9).

> Decided under auto-approve (2026-11-03): the intro clearance gate; CB valid for the whole Critical state; the window counts even with no player alive; TIMEOUT on the final stage counts as a clear; a `play_top` shift moves the anchor in one tick *(superseded 2026-11-03, wave 4: `play_top` is latched per stage/wave, so it never shifts mid-fight)*.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Collision, damage and lives (6) — GDD | Hard | Bodies, hp, mode, `armor_pct`, `kill_class`, `lethal`; hit results with `hp_after`; `spawn_is_clear`. Mode changes apply the next tick. |
| Bullet manager (3) — GDD | Hard | `set_hurtboxes`, `request_cancel` (circle and whole-screen), enemy-pool clear without items. |
| Bullet pattern library (9) — GDD | Hard | Emitters, intensity, `owner_destroyed`, `next_volley_in`, seeds from part ids. |
| Enemy and AI (10) — GDD | Hard | Shared `EmitterDef`, `hurt_pad`, hurtbox helper, budget of 8 hurtboxes, `ref_dps`. Boss is exempt from the fire-zone rule. |
| Chain tracker (7) — GDD | Hard | `add_bonus`, `boss_started`, `boss_defeated`. |
| Scoring (8) — GDD | Hard | Part and boss values, kill classes, cap-hold gate. |
| Co-op and Team Chain (18) — GDD | Hard | `hp_pct(N)`, read at `boss_started`. |
| Game events and session (1) — GDD | Hard | Slot states, player count, pause, boss events. |
| Player plane (5) — GDD | Hard | Positions for the clearance gate. |
| Wave and stage director (16) | Hard | `start_intro`, bullet clear before the intro, `boss_gone`. [GDD](wave-and-stage-director.md) |
| Plane kits (11) | Soft | `laser_query`, `targetable_parts()`, `ref_dps`. [GDD](plane-kits-lancer-leech.md) |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Critical Break (17) | Hard | `is_critical()`, `critical_left`, `core_world_pos()`, `core_target_id()`, `critical_break_finish(slot)` | yes ([GDD](critical-break.md)) |
| Boss power budget (15) | Hard | Part and emitter `tags[]`; per-boss mechanic list; the boss data lint requires a `data/boss_budget/<id>.tres` file | yes ([GDD](boss-power-budget.md)) |
| HUD (20) | Hard | `boss_bar_state()`, part-kill icons, enrage/timeout state | yes ([GDD](hud.md)) |
| Wave and stage director (16) | Hard | `boss_gone`, `boss_defeated` | yes ([GDD](wave-and-stage-director.md)) |
| Plane kits (11), Bombs (12) | Soft | `laser_query`, `targetable_parts()`, bomb damage reach; every phase span >= `4 x bomb_target_cap` = 4,000 hp (Bombs B10) | yes |
| Era shift (19) | Soft | Which boss belongs to which stage | yes ([GDD](era-shift-and-plane-evolution.md)) |
| Stage-end tally (21) | Soft | `boss_defeated.reason` (show "Boss withdrew" on TIMEOUT; clear bonus and boss peak still pay) | yes ([GDD](stage-end-tally.md)) |
| VFX (25), Audio (24) | Soft | Boss events and damage states | yes ([VFX](vfx-and-screen-feedback.md), [Audio](audio.md)) |
| Parallax and environment (23) | Soft | `warning_started`, boss arena timing; renders the vignette and grade | yes ([GDD](parallax-and-environment.md)) |
| Powerups (13) | Soft | Cancel items (via Bullet manager) | yes |
| Tutorial (30) | Soft | `TrainingBossDef` (Rule 40); `boss_core_exposed`, `boss_enraged`, `critical_break_landed` | yes ([GDD](tutorial.md)) |
| Online leaderboards, boss rush (32) | Soft | `start_intro(boss_id, home_stage)` for boss-only stages; `boss_defeated` KILLED / CRITICAL_BREAK → `bosses_beaten` (Rule 41); `boss_intro_ticks`, `T_fight` for the plausibility bound | yes ([GDD](online-leaderboards-boss-rush.md)) |

**Amendments to other docs** (apply at wrap-up):

1. **Systems index:** row 14 status `**Designed** (pending review) — [GDD](boss-and-boss-parts.md)`; Depends on `6, 9, 10` gains `3, 7, 8, 18` (→ `3, 6, 7, 8, 9, 10, 18`); progress tracker adds this GDD.
2. **Chain tracker** (`chain-tracker.md`): Rule 8 note: the boss opens at `boss_started` = the end of the Intro; wave-5 chains expire during the warning and entrance, so the "carried-in chain" cannot normally occur. Rule 10 / Boss row: `boss_defeated(reason, killer_slot)` carries a `reason`; the record is appended and the chain freezes for **every** reason including TIMEOUT. Part kill `add_bonus(slot, 5, "part_kill")` unchanged.
3. **Scoring** (`scoring.md`): S4 is paid only if `reason != TIMEOUT`; add the input `boss_cap_hold_allowed()` (false from `enrage_start` to the boss end) to F6 and AC-39; close Open Question 4 ("Boss enrage timer ... Boss GDD"); Boss row in Dependencies points to this GDD.
4. **Collision** (`collision-damage-lives.md`): (a) Dependencies/Interactions row for Boss: bodies carry `kill_class` PART/CORE, `on_boss`, `lethal`; the boss changes the core mode and `armor_pct` between ticks and republishes the core's hp (main then reserve) under the same `(id, generation)`, so Collision must treat the published record as authoritative every tick and ignore later same-tick events on a target *destroyed* that tick; (b) body radius note "cores 6–12 (placeholder)" → boss cores up to 26 px, within the 2–40 range; (c) Open Question 2 (hp scale, `armor_mult`, crack tell at 1 hp) is answered: `core_armor_pct` 25, hp per F6/F10, the crack overlay shows only below `critical_hp` (Critical phase), not at 1 hp; (d) `armor_mult` → `core_armor_pct` (int); (e) Open Question 9 closed for bosses (integer hp).
5. **Enemy and AI** (`enemy-and-ai.md`): Rule 18 and Interactions: "Boss (14) is exempt from fire-zone arming; it starts all emitters at `boss_started` and relies on a placement lint"; Rule 23: the 8 reserved hurtboxes are the boss's maximum; Boss row now points to this GDD.
6. **Bullet pattern library** (`bullet-pattern-library.md`): Boss (14) row: intensity = `I_eff` (parts destroyed ÷ parts, floored by the enrage ramp); `owner_id` = unique part `id`; lint: patterns that open at I > 0 need `start_delay ≥ 18`. Open Question list: no change.
7. **Bullet manager** (`bullet-manager.md`): cancel requesters add "Boss (14): part kill 90 px / last part 150 px / boss death whole screen (cause = killer); TIMEOUT uses the enemy-pool clear without items (Rule 15a)".
8. **Co-op** (`coop-and-team-chain.md`): Interactions row for Boss (14) → this GDD; F4 confirms `critical_hp` and `core_main` derive from the scaled core hp; enrage timeout unscaled (F6 already says so).
9. **Game events and session** (`game-events-and-session.md`): add the events `boss_intro_started`, `boss_started`, `boss_part_destroyed`, `boss_core_exposed`, `boss_phase_changed`, `boss_critical_started`, `boss_critical_window_closed`, `boss_enraged`, `boss_gone`; change `boss_defeated` to `boss_defeated(reason, killer_slot)` with `reason` ∈ KILLED, CRITICAL_BREAK, TIMEOUT; add Boss (14) to the Dependencies table.
10. **Art bible** (`art-bible.md`): 5.8 — part kills never flash; per-part hp bars are removed (damage states only); core "CORE EXPOSED" cue is a strip caption (Rule below); §7.4 — add the enrage/timeout indicator and the part-kill caption inside the boss row (Row B/D); §6.8 — boss part explosion size 28–36 px, boss death sequence particle budget.
11. **ADR-0001 diagram:** add step 3c (`BossController.tick()`) and 6c (`apply_results()`) (→ core wiring ADR).
12. **Code to correct at implementation** (listed, not edited here): `boss.gd`, `boss_part.gd`, `boss_part_definition.gd`, `boss_definition.gd`, `data/bosses/*.tres` — see Open Question 12.

**Bidirectional check:** Collision, Bullet manager, Pattern library, Chain tracker, Scoring, Enemy, Co-op and Session already list "Boss (14)". Wave director (16), Plane kits (11), Bombs (12), Boss power budget (15), Critical Break (17), HUD (20) and Era shift (19) must list this GDD when written.

## Tuning Knobs

**Owned by this system** (`data/boss_rules.tres` for globals; per-boss values in each `BossDefinition`)

| Knob | Default | Safe range | Too low | Too high | Interacts with | Category |
|---|---|---|---|---|---|---|
| `part_kill_chain` (registry) | 5 | 3–10 | Part kills feel unrewarded | Part kills outweigh holding the chain on the core | Chain, Scoring `part_value` | Curve |
| `part_cancel_radius` | 90 px | 60–120 | No relief after a kill | Part kill erases the curtain; free dodge | Bullet manager F9; Enemy cancels 40 / 72 | Feel |
| `last_part_cancel_radius` | 150 px | 100–220 | "Core exposed" has no breath | Whole-screen clear for free | Part cancel radius | Feel |
| `core_armor_pct` | 25 % | 10–50 | Core as hittable as a part; parts become optional | Chain on the core feels dead; armour pointless | Collision C4, damage ≥ 20 | Curve |
| `critical_pct` | 15 % | 5–30 | Window too short to matter | Boss spends too long protected | Scoring CB value, F6 | Curve |
| `critical_window_ticks` | 420 (7 s) | 300–600 | Not enough time to set up laser + bomb | Free chain farming; the finish is delayed | Kits' charge times, Scoring F6 | Gate |
| `critical_armor_pct` | 20 % | 5–40 | Core feels immune | Core dies without a CB attempt | Window length | Curve |
| `hp_base` per part | per F6 / F10 | per F6 | Fight under 40 s | Fight over 60 s | `ref_dps`, `ref_uptime_pct` | Curve |
| `ref_uptime_pct` | 70 % | 50–90 | Bosses too short | Bosses too long | Enemy `exposure_margin` | Curve |
| `enrage_mult` | 1.75 | 1.5–2.5 | Slow first clears hit the clock | Stalling pays more (F11) | Scoring `hold_ramp_s` | Gate |
| `enrage_ramp_ticks` | 600 | 300–1,200 | Enrage feels like a switch | Enrage hardly noticed | Pattern gates | Feel |
| `timeout_after_enrage` | 1,200 (20 s) | 600–2,400 | Boss leaves before a struggling player can finish | Boss lingers; low tension | Tally, HUD | Gate |
| `intro_ticks` (entrance / hold) | 240 (180 / 60) | 180–360 | Banner and bar fill cut short | Dead time before the fight | Art bible 6.9, 7.4 | Feel |
| `intro_wait_max` | 180 | 60–300 | Player killed by overlap | Parking exploit | `spawn_clearance` | Gate |
| `death_ticks` | 180 | 120–300 | Death feels abrupt | Tally delayed | Wave director | Feel |
| `retreat_speed` | 2.5 px/tick | 1.5–4 | Retreat lingers | Looks like a teleport | Enemy `forced_exit_speed` | Feel |
| `boss_hurtbox_budget` | 8 | 6–12 | Bosses lose parts | Budget breaks | Bullet manager (40) | Gate |
| `boss_max_parts` | 6 | 5–6 | — | Unreadable 4P chain target (art bible) | Art bible 5.8 | Gate |
| `quant` | 1/16 px | fixed | — | — | Determinism | — |
| Sway / orbit amplitude and period | per F10 | per boss | Boss static | Boss leaves the lint bounds | Placement lint | Feel |

**Owned elsewhere:** `hurt_pad`, `ref_dps`, `exposure_margin` (Enemy 10); `hp_step` (Co-op 18); `armour_damage_min`, `death_fire_hold`, `spawn_clearance` (Collision 6); `chain_window`, `chain_cap` (Chain 7); `part_value`, `boss_value`, `hold_unit`, `hold_ramp_s` (Scoring 8); `enemy_cap`, hit radii (Bullet manager 3); pattern values (Pattern library 9); laser and drone damage (Kits 11); bomb damage (Bombs 12).

## Visual/Audio Requirements

Draw layers are art bible §6.8. Boss bodies and parts draw on layer 4; part-kill debris and explosions on layer 5; enemy bullets (layer 8) always draw on top of every boss effect.

**V1. Parts and hull**
- Hull is a flat mid-dark silhouette under the parts; parts sit one value step above it with a 2 px Ink outline (art bible 5.8). Boss width 144–270 px.
- **Damage states** per part by hp fraction: 100–66 % clean; 66–33 % scuffed (2–3 dark crack pixels); 33–0 % smoking (non-bullet grey particles, layer 5, below bullets). **No per-part hp bar** (the prototype's 28 × 3 px bar is removed).
- **Hit feedback:** Collision V2 (sprite tint, throttled to 3 Hz on boss parts, steady tint on sustained fire).
- **Windup:** 12 ticks before each volley (the library's `next_volley_in`), the part's emitter glows one value step brighter in an era accent. No flash, no bullet shapes.

**V2. Core states** (art bible 5.8)
- ARMOURED: plate-bordered core, blue-grey dull fill. IMMUNE: same plating plus a shield ring drawn at layer 4 (a 1 px arc, not an outlined bullet ring, era Accent).
- **Exposed:** the plating falls away over 8 ticks (Collision V3), debris on layer 5, the core shows its bright inner colour.
- **Critical:** a pulsing red-orange crack overlay on the core only (4–6 px lines), 2 Hz pulse in value, no screen tint. The window closing steps the pulse to 3 Hz for the last 60 ticks (value only, no flash).

**V3. Part kill**
- Part sprite swaps to a burnt stump (dark, no outline glow) and a debris burst (≤ 12 particles). Explosion 28–36 px, 3 frames at 2 ticks, layer 5. No screen flash.
- The cancel is the Bullet manager's vanish effect; a 90 px (150 px for the last) soft puff ring in the era Shadow colour expands below bullets over 8 ticks (not a bullet ring shape: a filled, dithered puff, never a thin outlined ring).
- Caption (2026-11-03, HUD 20): a broken-plate icon and the parts-left count in the HUD boss row (see UI), 90 ticks; no text. For the last part, a core-exposed icon replaces it.

**V4. Intro, enrage, death**
- **Intro:** dust and debris particle sweep as the boss enters (no flash); the vignette and grade are rendered by **Parallax (23)**, starting at `warning_started` + 150 (intro start) and easing in over 90 ticks (`boss_grade_ticks`; arena plates crossfade in from `BOSS_WARNING`) *(2026-11-03, wave 3b)*; the scroll stops over about 2 s (Wave director / art bible 6.9); name plate at the upper third for 90 ticks from intro tick 60, bilingual, layer 11, shown only while no enemy bullets exist (guaranteed by Rules 13 and the Wave director).
- **Enrage:** the vignette (Parallax) darkens one step (125 %) over 60 ticks; the boss's warning lights (orange lights on the Jet, rivet glints on the Fortress) pulse at 1.5 Hz at most. No flash, no new colour on the field.
- **Death sequence (180 ticks):** one explosion every 10 ticks at a part or hull point (positions from a fixed table per boss; the VFX seed is not the gameplay RNG), 3 frames each; at tick 150 a final large explosion (72 px) and a shockwave of filled puffs to 120 px radius over 20 ticks; wreckage remains. Live particle cap 40 for this sequence: VFX class BOSS_DEATH (40) in the shared 150 pool (art bible §8.6, VFX 25) *(2026-11-03, wave 3b)*. No flash.
- **Withdraw (TIMEOUT):** the boss climbs with a smoke trail and engine fade; no explosion.

**A1. Audio**
- Constant across eras: cue timing and meaning; eras change timbre only. Boss volleys may steal the oldest enemy-fire voice (Bullet manager audio rule).
- **Intro:** a low rumble that rises over the entrance. Audio (24) owns the Warning siren asset `sfx_ui_warning_siren_loop`; the Wave director or HUD only emits `warning_started` *(2026-11-03, wave 3b)*.
- **Part kill:** a heavy thud with a short metallic tear, distinct from MEDIUM/LARGE kills; a muffled "sweep" for the cancel (Boss owns the destroy sound, Bullet manager note). **Core exposed:** a rising two-note sting.
- **Critical:** a slow heartbeat loop for the window; it stops when the window closes or the boss dies.
- **Enrage:** a low drone under the music, rising over the ramp. **Timeout:** the music ducks; engine fade.
- **Death:** a staggered explosion series ending in a deep boom; the stage-clear sting belongs to the tally.

## UI Requirements

This system supplies data to the HUD (20) and owns no screen of its own. The HUD draws the **boss bar** inside the top strip (art bible §7.4: Row B in 1–2P, Row D in 3–4P; x 24–336, 8 px tall, 1 px outline).

| Element | Source | Notes |
|---|---|---|
| Bar fill | `bar_permille` (F7) | Alarm Red `#E03A3E` on `#2A0F12`; darker `#7A2226` chip catches up in 0.3 s; fills in over 60 ticks during the Intro hold |
| Phase tick | `phase_tick` | 1 px Cream tick at the parts/core boundary |
| Critical notch | `critical_notch` | taller Alarm Red notch; lights during Critical |
| Numeric | `display_pct` | `87%` at the right end, 12 px (non-colour backup) |
| Part-kill caption | `boss_part_destroyed` | Broken-plate icon and parts-left count in the boss row for 90 ticks, replacing the numeric; core-exposed icon for the last part; no text; never over the play field (HUD 20, 2026-11-03) |
| Enrage / timeout | `boss_enraged`, `timeout_left` | An Amber `#FFB000` enrage icon plus `timeout_left` seconds in D10 digits (no word ENRAGED) in the boss row from `enrage_start` to the end; counts down from `timeout_after_enrage / 60` = 20 (HUD 20, 2026-11-03) |
| Name plate | `boss_intro_started` | Bilingual name for 90 ticks at the upper third, layer 11 |

Strings are localization keys (`boss.<id>.name`, `boss.core_exposed`; `boss.part.<id>.down` and `boss.enraged` removed 2026-11-03 because HUD 20 uses icons); the prototype's hard-coded uppercase English popups are removed.

📌 **UX Flag**: run /ux-design for the boss bar row (phase tick, critical notch, caption, enrage and timeout display) before writing epics.

**Debug only (development builds):** overlay drawing every part's hurtbox circles, body capsule, mode and hp; the fight clock, `I`, `I_eff`, `critical_left`; counters for part kills, cancels and bullets cancelled; a "kill part N" and "skip to Critical" debug command.

## Acceptance Criteria

Defaults used: `part_kill_chain` 5, `part_cancel_radius` 90, `last_part_cancel_radius` 150, `core_armor_pct` 25, `critical_pct` 15, `critical_window_ticks` 420, `critical_armor_pct` 20, `enrage_mult` 1.75, `enrage_ramp_ticks` 600, `timeout_after_enrage` 1,200, `intro_ticks` 240 (180 + 60), `intro_wait_max` 180, `death_ticks` 180, `retreat_speed` 2.5, `boss_hurtbox_budget` 8, `hurt_pad` 2, `hp_step` 50, `ref_dps` 800, `ref_uptime_pct` 70, `armour_damage_min` 20, `spawn_clearance` 8, `r_pl` 3.0, `play_top` 48 (1–2P) or 72 (3–4P), 60 ticks/s. Slots 0-indexed. Tests read every number from `data/bosses/*.tres` and `data/boss_rules.tres`, never literals, except the F10 golden table (AC-02), whose values are the spec.

**Test setup:**
- **Classes:** logic lives in a node-free `BossController` (RefCounted) with no `delta`; `tick()` and `apply_results()` advance one 1/60 s step and keep an integer tick counter.
- **Injected:** `run_seed` or a `FakeRng`; slot states (`set_slots`); a `FakeCollision` that records published bodies and returns scripted `hit_results`; a `FakeBulletField` that records `set_hurtboxes`, `request_cancel`, `clear_enemy_pool`; a `FakeChain` that records `add_bonus`; an emitter factory (real `Emitter` from the Pattern library for integration tests, a recorder otherwise); the pause flag.
- **Read after a tick:** published bodies and hurtboxes, the event log, the request logs, `state_hash()`.
- **Files and tags:** tests in `tests/unit/test_boss_[data|placement|lifecycle|core|parts|clock|death|laser|bar|determinism].gd`, `extends SceneTree` like `tests/unit/test_chain_tracker.gd`, named `test_boss_[scenario]_[result]`. Integration: `tests/integration/test_boss_*.gd`. Perf: `tests/perf/boss_bench.tscn`. Evidence: `production/qa/evidence/boss/`. Tolerances: positions ±0.05 px.
- Tags: [Unit] headless logic · [Integration] real Collision / Chain / Scoring / Bullet manager / Pattern library · [Perf] reference machine · [Manual] human.

### Data and migration (Rules 1–10, F2, F10)

- **AC-01 [Unit] (Rules 1–3, lint):** every `data/bosses/*.tres` has exactly one core, 1–5 non-core parts, ≤ 6 parts in total, unique part ids, integer hp ≥ 1, whole-percent `core_armor_pct` / `critical_armor_pct`; a copy with two cores, 7 parts, a duplicate id or `core_armor_pct` 25.5 fails the lint.
- **AC-02 [Unit] (F10 golden table):** the loaded Fortress has anchor (180,130), amp (67.5, 0), period (754, 0); core `r_e` 13.5, spine 12.75, offset (0, −4.5), hp 16,500; turrets `r_e` 10.5 at (±71.25, 9), hp 2,400; engines `r_e` 8.25, spine 3.0, offset (±39, 16.5), hp 3,200. The Jet Carrier has anchor (180,120), amp (97.5, 11.25), periods (419, 222); core `r_e` 25.5, hp 19,700; pods `r_e` 9, orbit 54, period 314, phases 0 / 120 / 240, hp 1,900; wings `r_e` 9, spine 7.5, offset (±52.5, −10.5), hp 4,100.
- **AC-03 [Unit] (F2 hurtboxes):** Fortress core → 3 circles with spacing 12.75; engine → 1 circle radius 13.25; Jet wing → 2 circles spacing 15 (≤ 16.5). Totals: Fortress 7, Jet 8, Plasma 5, all ≤ 8; a test part with `r_e` 4.5 and spine 12 needs k = 4 and the Jet fails the 8-circle budget.
- **AC-04 [Unit] (Rule 28, placement lint):** for both `play_top` 48 and 72, every circle of every boss stays inside `[4, 356]` in x and below `play_top + 4` in y over the analytic bounds; Fortress minimum x is 180 − 67.5 − 71.25 − 12.5 = 28.75 ≥ 4; a copy with sway amp 130 fails.
- **AC-05 [Unit] (Rule 7 ids):** part ids 1000 + i with core = 1000; two bosses in sequence get different generations.

### Intro and start (Rules 11–16, F9)

- **AC-06 [Unit] (Rule 12, F9 entrance):** Fortress at `play_top` 48: `y0` = 10.25 at intro tick 0; tick 90 → y 100.06; tick 180 → 130; x = 180 throughout; at `play_top` 72 the same ticks give y0 34.25, 124.06, 154. Jet `y0` = −25.
- **AC-07 [Unit] (Rules 13, 14):** during ticks 0–239 a scripted hit on any part returns *ignored* (via the fake collision's immune record), no `chain_hit`, no hp change; published bodies have `lethal = false`; no emitter has started; `request_spawn` log empty.
- **AC-08 [Unit] (Rule 16):** `boss_started` fires exactly once on tick 240; from tick 241 bodies are `lethal = true`, modes are the fight modes, and every emitter of every part has started.
- **AC-09 [Unit] (Rule 15):** a player at 12 px from a part body at tick 239 (clearance needs `r_pl + r_e + 8`) → `boss_started` does not fire until the player is clear; with the player parked for 200 ticks, `boss_started` fires at tick 240 + 180 = 420.
- **AC-10 [Unit] (Rule 11):** `start_intro` while a boss is alive returns false and logs; no second controller exists.
- **AC-11 [Unit] (Rule 13, laser block):** at tick 100 with the Fortress partly in the field, `laser_query` returns the engine (IMMUNE) as the blocking part; the kit's tick returns *ignored*.

### hp and the core (Rules 18–23, F3)

- **AC-12 [Unit] (F3):** Fortress core at N = 1…4 → hp 16,500 / 24,750 / 33,000 / 41,250; critical 2,475 / 3,713 / 4,950 / 6,188; main 14,025 / 21,037 / 28,050 / 35,062; turret 2,400 at N = 4 → 6,000.
- **AC-13 [Unit] (Rule 19, read once):** `boss_started` at N = 1; a second slot becomes Alive on tick 500 → every hp unchanged. A boss started at N = 2 has the N = 2 values.
- **AC-14 [Unit] (Rule 18, C4):** Fortress in PARTS: core mode ARMOURED, `armor_pct` 25. A damage-40 hit → dealt 10 (*hit*); damage 20 → dealt 5; damage 3 (a test value) → dealt 1; a hit at main hp 5 → hp 1, never 0.
- **AC-15 [Unit] (Rule 18, IMMUNE):** Plasma core with a living shield: a hit is *ignored*; no `chain_hit`; hp unchanged.
- **AC-16 [Unit] (Rule 17, mode timing):** the last non-core part is destroyed on tick T → the core body published for tick T is still ARMOURED (a hit resolved during T deals 25 %); the body published for T + 1 is NORMAL (a hit deals full damage).
- **AC-17 [Unit] (Rule 20):** in EXPOSED, a hit that takes main to 0 → *destroyed*; the controller enters Critical, republishes the core on T + 1 with hp 2,475 (N = 1), mode ARMOURED at 20 %, `critical_left` 420; excess damage is discarded; `boss_critical_started` once; `kill_credit(slot, CORE)` logged once, and Scoring (stub) pays 0.
- **AC-18 [Unit] (Rule 22):** in the window, a 40-damage hit → dealt 8; 10,000 hits of 100 never take the core below 1 hp; `chain_hit` per hit.
- **AC-19 [Unit] (Rule 22, closes):** after exactly 420 ticks of the window `boss_critical_window_closed` fires once; from the next tick the core is NORMAL; a hit of 2,500 on a 2,475-hp core is *destroyed* → reason KILLED.
- **AC-20 [Unit] (Rule 23):** `critical_break_finish(slot 1)` on a tick that began in Critical → returns true, `boss_defeated(CRITICAL_BREAK, 1)` once; the same call in Exposed or Parts returns false with no state change; called after the window closed but with the core alive → true.
- **AC-21 [Unit] (Rule 23 order):** a CB request and a lethal normal hit on the same tick (window closed) → reason CRITICAL_BREAK, one `boss_defeated`.

### Part kills (Rules 24–26, F4, F9)

- **AC-22 [Unit] (Rule 24):** the left turret is destroyed by slot 2 → exactly one `add_bonus(2, 5, "part_kill")`; one `request_cancel(circle(turret pos, 90), 2)`; the turret's emitters stopped with `owner_destroyed = true`; one `boss_part_destroyed`; the part publishes nothing from the next tick; no screen-flash event exists in the log.
- **AC-23 [Unit] (Rule 24, last part):** destroying the fourth non-core part → cancel radius 150, `boss_core_exposed` once, `last = true`; earlier kills have `last = false` and radius 90.
- **AC-24 [Unit] (two parts one tick):** both engines die on tick T → events and bonuses in index order (left then right); only the second has `last` if no other part remains; both cancels logged in order.
- **AC-25 [Unit] (F4 intensity):** Fortress: after 0 / 1 / 2 / 3 / 4 part kills `I` = 0 / 0.25 / 0.5 / 0.75 / 1.0; the emitter receives it the next tick; `I` never decreases.
- **AC-26 [Integration] (real Emitter, F3):** the Fortress core spiral resolves `interval_eff` 7 / 6 / 5 / 4 / 3 at those five intensities; the core ring (gate [1, 1]) is silent at 0.75 and fires at 1.0 with `start_delay` 18.
- **AC-27 [Unit] (data lint, escalation lag):** every pattern whose `min_intensity` > 0 has `start_delay` ≥ 18; a copy with 10 fails.
- **AC-28 [Integration] (real Chain and Scoring):** slot 0 (Active, chain 60) destroys a turret → chain 61 + 5 = 66 (hit then bonus), PART 5,000 paid, no KILL; a part kill by a Dying slot adds no chain but still pays 5,000.
- **AC-29 [Integration] (real Bullet manager, F9):** a part kill at (141, 146.5) on tick T (step 6c) requests the cancel; on tick T+1, step 5, an orb `r_vis` 4 at 94 px is cancelled and handed to Powerups for the slot; at 95 px it survives. The last part: 154 px cancelled, 155 survives. Bullets in the circle still exist (and can hit) during the rest of tick T.
- **AC-30 [Integration] (real Pattern library):** two parts with different ids (`turret_l`, `turret_r`) running the same seeded-ring pattern produce different first-ring offsets with the same run seed; stopping `turret_l` with `owner_destroyed` cancels a lit flak fuse and leaves `turret_r`'s fuse.

### Clock, enrage, timeout (Rule 33, F5, F6, F11)

- **AC-31 [Unit] (F5):** `fight_ticks` is 0 through the Intro, advances 1 per tick in Parts / Exposed / Critical with ≥ 1 Active slot, and stops while all slots are Dead or Continue and while paused; it resumes at the same value.
- **AC-32 [Unit] (F6, data):** for Fortress, Jet and Plasma: `T_fight` is 2,703 / 3,285 / 3,138 and `enrage_start` is 4,700 / 5,700 / 5,500; `T_fight` is within 2,400–3,600; changing `ref_dps` to 400 makes the lint report `T_fight` out of range.
- **AC-33 [Unit] (Rule 33):** Fortress `boss_enraged` fires once at `fight_ticks` 4,700; `I_enr` = 0 at 4,700, 0.5 at 5,000, 1.0 from 5,300; `I_eff = max(I, I_enr)` (I = 0.25 at 5,000 → 0.5); `boss_cap_hold_allowed()` is true at 4,699 and false from 4,700, and Scoring's cap-hold streak resets to 0 at 4,700.
- **AC-34 [Unit] (timeout):** at `fight_ticks` 5,900 (Fortress) → `boss_defeated(TIMEOUT, none)` once; all emitters stopped with `owner_destroyed = true`; one enemy-pool clear without items; bodies and hurtboxes absent from the next publication; `boss_gone` within 180 ticks; the boss y decreases by 2.5 per tick during the retreat.
- **AC-35 [Unit] (timeout vs kill):** a kill and the timeout on one tick → reason KILLED.
- **AC-36 [Integration] (real Scoring and Chain):** TIMEOUT: no boss value paid; the chain freezes; `max_chain_per_boss` is appended; no cap-hold payment is made after tick 4,700; a KILLED boss pays 100,000 to each eligible slot (4 slots → 4 awards).
- **AC-37 [Unit] (F11):** the stall bound arithmetic: 40 s at the cap → 382,500; 63 s → 727,500; difference 345,000 (a test of the formula with the Scoring constants read from the registry).

### Death sequence (Rules 30–32)

- **AC-38 [Unit] (Rule 31):** on the tick the core is destroyed in Critical: emitters stopped with `owner_destroyed = true`; one whole-screen `request_cancel` with `cause_slot` = killer; bodies and hurtboxes removed from the next publication; `boss_defeated(KILLED, killer)` once; `boss_gone` exactly 180 ticks later; no other boss event after `boss_gone`.
- **AC-39 [Integration] (Session AC-34):** a lethal hit on slot 0 (lives 2) and the boss kill on one tick → slot 0 loses its life (Phase A), then `boss_defeated` fires; the stage clears and slot 0 is Alive at the next stage's start.
- **AC-40 [Integration] (cancel dedupe):** a bomb cancel and the death cancel on one tick → each bullet becomes one item, credited to the first request.

### Laser and blocking (Rules 35–37, F8)

- **AC-41 [Unit] (F8):** Fortress at `t = 0`, laser half-width 3, `y_origin` 500: x = 141 → part left engine, `y_hit` 159.75; x = 180 → core, `y_hit` 141; x = 141 with the left engine dead → none; x = 0 → none.
- **AC-42 [Unit] (Rule 36 rules):** a ties case (two circles with equal bottom) returns the lowest part index; an IMMUNE part blocks and returns its mode; a dead part never blocks; the hull never blocks; `y_origin` inside a hurtbox returns `y_hit = y_origin`.

### Placement and determinism (F1)

- **AC-43 [Unit] (F1):** Jet at `t = 157`: pod_1 at (195.06, 109.13) ± 0.05; Fortress core x at `t = 188` = 247.5, at `t = 377` = 180, at `t = 754` equal to `t = 0` (180) within 1/16 px.
- **AC-44 [Unit] (quantization):** every published world coordinate is a multiple of 1/16.
- **AC-45 [Unit] (closed form):** stepping 1,000 ticks and jumping straight to tick 1,000 give identical positions for every part.
- **AC-46 [Unit] (play_top shift):** at `play_top` 72 every part's y is 24 px lower than at 48 for the same tick; x is unchanged. A 3rd slot joining mid-fight leaves every part's y unchanged until the fight ends (latched `play_top`).
- **AC-47 [Unit] (determinism):** a scripted 5,400-tick run (4 slots, scripted hits, 3 part kills, a Critical window, a CB finish; one run to timeout), run twice with the same seed → `state_hash()` equal every tick; the boss makes zero calls to `randf()` and zero draws from the gameplay RNG.
- **AC-48 [Unit] (co-op patterns):** a boss loaded at N = 4 has pattern resources with the same property hash as at N = 1.

### Boss bar (F7)

- **AC-49 [Unit] (F7):** Fortress N = 1: full → 1000 (100 %); all four parts dead with the core untouched → 596 (60 %); `phase_tick` 596; `critical_notch` 89; a core at 1 hp with all parts dead → at least 1 (1 %); never 0 while alive; non-increasing under any damage sequence.

### Performance (Rule 39)

- **AC-50 [Perf] (budget):** on REF-PC and REF-WEB, `BossController.tick()` + `apply_results()` for the 8-hurtbox Jet Carrier ≤ **0.05 ms p99**; zero allocations per tick (allocation counter delta 0 over 1,000 ticks); hurtboxes published ≤ 8 on every tick.

### Playtest (Manual)

- **AC-51 [Manual] (fight length):** 5 solo runs by a competent tester on each boss → `T_fight` (Parts + Exposed) of 2,400–3,600 ticks in at least 4 of 5; a first-time player in 2 of 3 attempts reaches the Critical window without hitting enrage.
- **AC-52 [Manual] (readability):** frame-by-frame capture of the first part kill, the exposure and the death sequence: no full-screen flash (only Critical Break may flash); the cancelled area is visibly larger for the last part; no effect draws over an enemy bullet; the grayscale gate passes.
- **AC-53 [Manual] (Critical window):** 8 testers on Lancer and Leech each get one Critical window; at least 6 of 8 report enough time to attempt a Critical Break, and at most 2 of 8 say the window "wasted time".
- **AC-54 [Manual] (enrage):** testers asked "when did the boss get angrier, and how long was left?" answer correctly within ±10 s using only the HUD cue and music; no tester reports the withdrawal as a surprise.
- **AC-55 [Manual] (intro fairness):** across 20 intro runs with the player parked at the top (random positions), no death occurs during the Intro or on the `boss_started` tick.
- **AC-56 [Manual] (4P legibility):** a 4P boss fight on the Jet Carrier (8 hurtboxes, 6 parts): each tester can name which part each teammate is hitting from the plate lamps and the part damage states.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Laser contract: `laser_query(x, half_width, y_origin)`, the damage-per-tick rate and whether drone lasers use the same query; `targetable_parts()` for Leech homing. | Plane kits (11) | Kits GDD |
| 2 | ~~Critical Break trigger: valid for the whole Critical state (this GDD) or only while the window is open? CB score and Life Damage Bonus need to justify the 5.6 s of lost damage. Does CB own its cancel and flash?~~ **Closed 2026-11-03:** valid until the core dies (window expiry changes nothing); CB issues its own full-screen cancel and the one-frame white flash (critical-break.md). | Critical Break (17) | CB GDD |
| 3 | ~~Wave 5 to boss timing: the Warning screen, scroll-stop and `start_intro` call; bullets cleared before the Intro; the wave-5 chain cannot carry into the fight (Chain Rule 8 is effectively dead). Should Chain Rule 8 be reworded?~~ **Closed 2026-11-03:** field clear E5+60, WARNING E5+90 (150 ticks), `start_intro` E5+240, `boss_started` E5+480 (wave-and-stage-director.md Rule 24). Chain Rule 8 wording stays with Chain (7). | Wave director (16), Chain (7) | Wave director GDD |
| 4 | ~~Final-stage TIMEOUT: counts as a clear and ending (this GDD) and 1CC? Should a withdrawn boss lose the clear bonus too?~~ **Closed 2026-11-03 (clear bonus):** the clear bonus and boss peak still pay on TIMEOUT; the tally hides the BOSS row and shows "Boss withdrew" (stage-end-tally.md). | Session (1), Scoring (8) | Tally GDD / playtest |
| 5 | ~~`play_top` jumping from 48 to 72 mid-fight shifts the boss 24 px in one tick; smooth it over 30 ticks?~~ **Closed 2026-11-03:** no mid-fight change — `play_top` is latched at `stage_started` / `wave_started` (Co-op Rule 2; wave-4 decision) | Player plane (5) / Boss (14) | First 3P playtest |
| 6 | Collision must treat the published core record (hp, mode, armour) as authoritative each tick and ignore later same-tick events on a target already *destroyed*; confirm the two-stage core fits C4 / C6. | Collision (6) | Collision epic |
| 7 | `ref_dps` 800 (now derived from the Kits GDD, 2 drones) and `ref_uptime_pct` 70 are still unplaytested; re-run F6 with telemetry and re-tune `hp_base`. A 0-drone player (about 580 dps) takes about 1.4x the fight length; a 4-drone player (about 1,100) about 0.73x. | Kits (11), designer | First playable boss |
| 8 | ~~Per-boss mechanic list and the `tags[]` that link parts to waves ("wave N previews mechanic N"). Fortress sketch: turret = aimed fan, engine = ring, armoured core, spiral, then all together.~~ **Closed 2026-11-03:** mechanic lists, `tags[]` convention `mech:<id>`, and the budget file are in `boss-power-budget.md` (Boss power budget 15). | Boss power budget (15) | Budget GDD |
| 9 | Plasma Ring (Target): hp, patterns and the IMMUNE-core flow (Warp rings) are migrated but not playtested; the chain gap when only shields are countable. | Designer | Target milestone |
| 10 | ~~Bomb damage on bosses: `bomb_part_mult` and whether a bomb hit on a part counts as one chain hit per part.~~ **Closed 2026-11-03:** `bomb_part_pct` 60 on parts, cap 1,000 per target per bomb, and bomb hits never count for the chain (Bombs 12 Rules 9-10, B7). | Bombs (12) | Bombs GDD |
| 11 | Boss sprite sizes versus hurtboxes (Jet wing `r_e` 9 is thicker than the prototype's 4.5; core r 25.5). Does the art match these shapes? | Art director | Boss art spec |
| 12 | Code corrections at implementation: float hp / `armor_damage_mult` / absolute `critical_hp`; `_physics_process(delta)` and `elapsed += delta`; duplicate `part_name`; `rage()` → intensity; `Boss` as a Node2D with `_draw` → a node-free controller plus a view; `clear_radius` → `request_cancel` with a cause slot; `screen_flash_requested` and the English-only popup removed; per-part hp bars removed; `critical_break()` finishing without events; 480 × 640 coordinates. | Programmer | Boss epic |
| 13 | Is `enrage_mult` 1.75 and the 20 s timeout window fair for a first clear and for 4P (Co-op η is an assumption)? | Designer | First 2P–4P boss test |
