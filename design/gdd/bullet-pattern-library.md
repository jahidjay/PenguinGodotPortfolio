# Bullet Pattern Library

> **Status**: Approved (2026-11-03) · **Implemented 2026-11-04** (`src/gameplay/patterns/`, `data/patterns/`; 16 patterns, 6 unit suites + 1 integration suite + `tests/perf/pattern_bench.gd`). Open Questions 9 closed, 11-13 raised by the implementation.
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + Claude (lean review mode)
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos, History Accelerates

## Overview

**The data layer:** the pattern library is a set of reusable, designer-tuned **pattern resources** (`data/patterns/*.tres`). Each one describes *how* a volley of enemy bullets is shaped and timed: an aimed fan, a ring, a spiral, a wall with a gap, and others. Enemies (10) and bosses (14) attach patterns to their emitters; each tick, a running pattern decides whether it fires and sends **spawn requests** (position, velocity, shape, behaviour, parameter, target slot) to the Bullet manager (3), which owns the bullets from then on. Patterns never hold bullets. Every pattern takes a generic **intensity** input (0–1) that can switch it on or speed it up; what drives intensity (boss parts destroyed, wave progress) belongs to the system using the pattern. The library also owns the **co-op targeting rule** (which player an aimed pattern aims at) and the **360 px canvas retune** (spacing and counts ×0.75) handed over by the Bullet manager. Implementation follows ADR-0001: integer 60 Hz ticks, one seeded random generator, node-free logic, all values in `.tres`.

**The player impact:** patterns are what the player actually reads and dodges. The shapes never change between eras; the patterns do. 1941 throws slow aimed fans and flak rings, the 1970s add radar-locked streams that accelerate, and 2100 freezes bullets and re-aims them. Each era adds one new trick before combining them (**History Accelerates**), and every pattern stays readable and fair: telegraphed, with a path through it, never spawning on top of a player (**Readable Chaos**). Without this library, every enemy and boss would hand-code its own bullets, era identity would drift, and fairness would be untestable.

## Player Fantasy

**Anchor moment: reading the gap.** A curtain fills the screen. For half a second it looks impossible. Then the eye finds the lane, the plane slides into it on focus speed, and the bullets pass a pixel either side. The player didn't get lucky; they *saw* it. That's the feeling this library exists to create: **chaos that turns out to be readable**.

What makes that feeling possible:
- **Every pattern has an answer.** A wall has a gap, a ring has spacing the hitbox fits through, an aimed fan can be side-stepped by moving early. Patterns never close off every path. When a player dies, it's because they missed the answer, not because there wasn't one.
- **Patterns are learnable.** The same pattern behaves the same way every time it's fired with the same inputs, so a player who dies to a spiral on attempt one can weave through it on attempt three. Randomness exists (a ring's rotation, a wall's gap position) but only inside limits that keep the answer visible.
- **Patterns announce themselves.** A volley's shape, its sound and its first bullets tell the player what's coming before it's dangerous.
- **Each era asks a new question.** In 1941 the question is "where is the gap?" In the 1970s it becomes "where will the gap be once these speed up?" In 2100 it becomes "where will they go after they stop?" The skill of reading carries over; only the question gets harder (**History Accelerates**).
- **Density is earned.** Waves are lighter and the boss is the peak. In co-op, the curtain is the shared problem all players solve together.

Reference feel: DoDonPachi's boss curtains (dense but with clear lanes), and Touhou's "every pattern is a puzzle with an answer".

**Anti-fantasy (what must never happen):** a bullet that appears on top of the player, a wall with no gap, a random spread that sometimes closes every lane, or a pattern that looks different from how it hits.

> `creative-director` not consulted (lean mode).

## Detailed Design

### Core Rules

**Patterns and emitters**

1. A **pattern** is a read-only data resource (`data/patterns/*.tres`, or embedded in an enemy or boss resource). It describes one kind of volley: its geometry, its timing, and the shape, behaviour, behaviour parameter and speed of its bullets. Many emitters can share one pattern.
2. An **emitter** is a point that fires patterns. Enemies (10) and bosses (14) own emitters and move them. Each tick, the owner gives the emitter its **origin** (spawn point), **centre** (the body's centre, for outward patterns) and **intensity** (0–1).
3. An emitter runs a **list of patterns** (stacking). Each pattern in the list has its own **runner**: per-emitter runtime state (timer, burst progress, volley counter, spiral angle, lock data). Patterns never store runtime state. Stacked patterns are independent; two can fire on the same tick.
4. A runner only **requests** bullets from the Bullet manager (3) with position, velocity, shape, behaviour, parameter and target slot. It keeps no bullet references.

**Timing (integer ticks, 60 Hz)**

5. All timing is in whole ticks: `start_delay`, `interval`, `burst_count`, `burst_gap`. A **volley** is one firing of a pattern's geometry. A **burst** is `burst_count` volleys, `burst_gap` ticks apart. `interval` is the gap from the start of one burst to the start of the next.
6. **Intensity** (0–1) is read at the start of each burst. It can:
   - **gate** the pattern: it fires only while `min_intensity ≤ intensity ≤ max_intensity`;
   - **scale** `interval` towards `interval_at_full`;
   - **scale** `count` towards `count_at_full`, for patterns that have a count (Formulas).

   What intensity means belongs to the owner. Boss (14) uses `I_eff` = fraction of non-core parts destroyed, floored by the enrage ramp (Boss F4), and waves may use other drivers.
7. When a gated pattern becomes active (on start, or when intensity enters its range), its runner waits `start_delay` before the first volley. It never fires on the tick it activates.
8. **Fire hold:** while Collision's `death_fire_hold` is active, runners keep counting. Volleys that fall in the hold are **skipped**: no bullets and no sound. They still advance the volley counter, the spiral angle and the target rotation. Rhythm stays in step with the owner's movement and the music.
9. A runner whose owner stops it (part destroyed, enemy killed, emitter removed) fires nothing more. Any unfinished burst is dropped.

**Targeting (co-op)**

10. Each emitter has a **target cursor**. At the start of each **burst**, it advances to the next **Alive** slot in slot order after the previous target, wrapping round. Solo: always that player. Every bullet in the burst stores this slot as its target (Bullet manager Rule 16). This applies to non-aimed patterns too, so a Warp ring knows whom to re-aim at. Aim-lock patterns choose the target at the lock tick instead (F4).
11. If no slot is Alive, the target is **none**. Aimed patterns fire straight down (`(0, 1)`) and bullets store slot 0. Warp bullets then follow Bullet manager Rule 17 at re-aim time.
12. **Aim** is the angle from the volley's origin to the target's position. It is taken **once per burst**, at its first volley. A pattern with `reaim_each_volley = true` re-aims every volley of the burst at the same target, which turns a burst into a tracking stream.
13. **Aim lock** (option on aimed patterns): the target position is sampled `lock_ticks` before the burst fires, and the emitter emits a **lock tell** for those ticks. Moving after the lock dodges the burst (1970s "radar-locked spreads").

**Spawn safety and randomness**

14. **Spawn safety:** a bullet whose spawn point is within `spawn_safe_radius` (default 42 px; a pattern may set a larger value, F7) of any **Active** player's centre is skipped. The rest of the volley fires. Skipped bullets are counted for debug and never retried.
15. **Seeded randomness:** each emitter owns its own random stream, seeded from a **stable id**: `seed = hash(run_seed, stage_index, owner_id, emitter_index)`, where `run_seed` comes from the gameplay RNG (ADR-0001) once per run and `owner_id` is the owner's authored id (wave slot or boss part name). Every random choice (ring rotation, wall gap, spray angles, flak ring offset) uses that stream, so adding, removing or reordering one emitter never changes another's randomness. Random choices are always **bounded** so the answer stays visible (Formulas). Global `randf()` is forbidden.

**Pattern catalogue (MVP)**

| Pattern | Geometry | Main parameters | Era use |
|---|---|---|---|
| **Aimed fan** | `count` bullets centred on the aim, `spread` apart. count 1 + burst = aimed stream | count, spread, aim lock, reaim | All. Core 1941 |
| **Ring** | `count` bullets evenly round 360°, rotation offset fixed or seeded within one gap | count, offset mode | All |
| **Spiral** | `arms` bullets per volley; the angle turns `step` each volley | arms, step, angle offset | Boss cores |
| **Wall** | Horizontal line of `count` slots `spacing` apart, moving in `direction`; one gap of `gap_width` slots, position fixed or seeded | count, spacing, gap width, direction | 1941 bombers, 1970s wings |
| **Radial curve** | Outward from the centre through the origin; Curve behaviour, spin sign alternating each volley | spin | 2100 shields |
| **Flak burst** | After `flak_delay`, a small ring spawns at a point out along the aim, stopping short of the target | ring count, distance, standoff, delay, aim lock | 1941 flak |
| **Seeded spray** | `count` bullets at random angles within `arc` around the aim (or down), speeds random within a band | count, arc, speed band | Light wave pressure |

Shape and behaviour are free per pattern (any enemy shape × any behaviour, Bullet manager Rules 3–4). **Eras choose which patterns and behaviours appear** (Era shift 19). The library has no era logic.

**Canvas retune**

16. Patterns are authored for the 360×640 canvas. Ported prototype values are converted **once**, as a data migration (Formulas). There is no runtime scale factor. Speed retune stays with the Bullet manager's `k_speed`.

### States and Transitions

Per runner:

| State | → Next | Trigger |
|---|---|---|
| Gated | Waiting | intensity enters `[min, max]` (or the emitter starts with it in range) |
| Waiting | Firing | `start_delay` ticks elapsed |
| Firing | Firing | `burst_gap` elapsed, burst not finished (next volley) |
| Firing | Cooling | last volley of the burst fired (or skipped) |
| Cooling | Locking | `lock_ticks` before the next burst (aim-lock patterns only) |
| Cooling / Locking | Firing | `interval` elapsed since the burst start |
| Any | Gated | intensity leaves `[min, max]` (an unfinished burst is dropped) |
| Any | Stopped | owner stops the emitter (final) |

Flak burst adds a per-volley **fuse**: aim point fixed, then a ring spawns `flak_delay` ticks later. A fuse already lit still bursts if the runner gates or stops. **Exception:** a stopped emitter whose owner was destroyed cancels its fuses. A dead gun fires nothing. **Fuse cap (decided 2026-11-03, wave 4):** at most `flak_fuse_max` = **8 lit fuses per scene** (all emitters together). A flak volley that would light a 9th fuse is **skipped**: it counts as fired (the interval timer restarts, `burst` index advances) and still makes its random draws, so the stream stays stable; no `volley_fired` or `flak_fuse` is sent. The validator checks the cap per owner (F8) and the Director's `StageValidator` checks it across co-active owners.

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Bullet manager (3) | → | `request_spawn(pos, vel, shape, behaviour, param, target_slot)` per bullet |
| Collision (6) | ← | `death_fire_hold` active (skip volleys); Active player positions for spawn safety |
| Session (1) / Player plane (5) | ← | slot states (Alive) and hitbox positions for targeting and aim |
| Enemy (10), Boss (14) | ↔ | own emitters: origin, centre, intensity, pattern list, start/stop. → `next_volley_in(emitter) -> int` (ticks to the next volley over the emitter's runners, −1 if none; read-only, for enemy tells). Enemy holds intensity constant per enemy (frozen at spawn). Enemy `owner_id = event_id × 16 + member_index`; Boss `owner_id` = part `id` (Rule 15 seeds; *(2026-11-03, ADR-0003)*) |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | ← | chooses which patterns each era's enemies use (data only); owns the behaviour/option ladder and `StripMap` |
| Audio (24), VFX (25) | → | `volley_fired(emitter, pattern, pos)` once per volley with ≥ 1 bullet spawned (flak: when the fuse is lit); `lock_started(emitter, target_slot, aim_point)`; `lock_ended(emitter, target_slot, fired)`; `flak_fuse(pos, ticks)`; `flak_burst(pos)` |
| Debug counters | → | `volleys_fired`, `volleys_skipped`, `spawn_safety_skips`, `active_runners` (per tick) |

> Specialist agents not consulted for this section (lean mode).

## Formulas

**Conventions:**
- Angles are in radians, with 0 = right (+x) and π/2 = down.
- `r_p` is the player hitbox radius, 3.0 (registry).
- `r_b` is the largest bullet hit radius in the pattern: orb 2.5, rice 1.5, needle 1.25, ring 2.0 (registry).
- The canvas is 360×640, with `play_top` 48 (1–2P) or 72 (3–4P).
- All timing is authored in **integer ticks** (60 per second).

**F1. Timing in ticks**

`ticks = max(min_t, roundi(seconds × 60))`. This is used only by the one-time migration (F10); new patterns are authored directly in ticks.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Seconds | `sec` | float | ≥ 0 | Prototype value |
| Minimum | `min_t` | int | 0–1 | Per field (below) |
| Ticks | `t` | int | 0–3600 | Authored value |

**Field minimums** (clamped at load and again at runtime):

| Field | Minimum |
|---|---|
| `interval` | 1 |
| `burst_gap` | 1 |
| `burst_count` | 1 |
| `start_delay` | 1 (Rule 7: never fires on its activation tick) |
| `flak_delay` | 1 |
| `lock_ticks` | 0 (0 means no lock) |

**Example:** 2.3 s → 138. 0.045 s → 3. A start delay of 0 s → 1.

**F2. Burst and volley timing**

`S[0] = T_act + start_delay`
`S[j+1] = S[j] + interval_eff[j]`
`tick(j, k) = S[j] + k × burst_gap`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Activation tick | `T_act` | int | ≥ 0 | Emitter start, or the tick intensity entered the gate range |
| Burst start | `S[j]` | int | ≥ 1 | Tick of the first volley of burst j |
| Volley index | `k` | int | 0 … `burst_count`−1 | |
| Volley counter | `c` | int | ≥ 0 | Counts every scheduled volley, including skipped ones (Rule 8) |

**Constraint:** `(burst_count − 1) × burst_gap < interval_eff`.
- **Validator:** checks both `interval` and `interval_at_full`.
- **Runtime fallback:** `interval_eff = max(scaled, (burst_count − 1) × burst_gap + 1)`. The next burst is pushed later and no volley is dropped.

**Example:** `T_act` 100, `start_delay` 48, `burst_count` 6, `burst_gap` 6, `interval` 84. Volleys fire at 148, 154, 160, 166, 172, 178. The next burst starts at 232.

**F3. Intensity: gate, interval and count**

`active = (min_i − ε ≤ I ≤ max_i + ε)`
`interval_eff = max(1, roundi(lerpf(interval, interval_full, I)))`
`count_eff = max(1, roundi(lerpf(count, count_full, I)))`

A negative `*_full` means no scaling.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Intensity | `I` | float | 0–1 | From the owner, clamped to 0–1 |
| Gate bounds | `min_i`, `max_i` | float | 0–1 | Inclusive at both ends |
| Epsilon | `ε` | float | 1e-6 | Guards float equality (e.g. 3/3 parts destroyed) |
| Full values | `interval_full`, `count_full` | int | ≥ 1, or −1 | Values at I = 1 |

**Output Range:** both values are integers ≥ 1, between their authored endpoints. They are read at burst start and held for the whole burst. The gate is checked every tick.

**Example:** interval 78 → 33 at I = 0.5 gives 55.5, which rounds to 56. Count 5 → 9 at I = 0.125 gives 5.5, which rounds to 6.

**F4. Target rotation**

`target = first s in [(prev+1) mod 4, (prev+2) mod 4, (prev+3) mod 4, (prev+4) mod 4] with Alive(s)`

If no slot is Alive, the target is none, the cursor stays unchanged, and F5's fallback applies.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Previous target | `prev` | int | −1 … 3 | Cursor. New emitters start at −1, so the first target is the lowest Alive slot |
| Alive | `Alive(s)` | bool | slots 0–3 | Session slot state |

**When the cursor moves:**
- Once per burst, including bursts skipped by fire hold.
- For aim-lock patterns, the target is chosen at the lock tick (`S[j] − lock_ticks`), not at `S[j]`.

**Example:** Alive = {0, 2, 3} and `prev` = 0 → targets go 2, 3, 0. In solo, it always returns the one player.

**F5. Aim, re-aim and lock**

`d = P_target − O`
`θ = atan2(d.y, d.x)` if `|d| ≥ 0.5`, else π/2  
*(2026-11-03, ADR-0003)*: in code all aim/spread/rotation angles use the shipped trig table `SimMath` (angles in binary angle units, 65,536 per turn; no platform `sin`/`cos`/`atan2` in the simulation) and published positions are rounded to 1/16 px (`θ = SimMath.atan2_bam(d.y, d.x)`; authored radians such as spiral `step` are converted to binary angle units at load). Example values in this GDD are the ideal results; tests allow ±1 binary angle unit (≈ 0.0055°).
`θ = π/2` if the target is none.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Origin | `O` | Vector2 | any | Emitter origin at the burst's first volley |
| Target position | `P_target` | Vector2 | any | Live hitbox centre, or `P_lock` for locked patterns |
| Lock tick | `t_lock` | int | `S[j] − lock_ticks` | Also the start of the lock tell |
| Aim angle | `θ` | float | (−π, π] | |

**Rules:**
- **Normal burst:** `θ` is taken once, at volley 0.
- **`reaim_each_volley`:** `θ` is recomputed every volley from the same target's live position. If that target is no longer Alive, the burst keeps its last `θ`.
- **Aim lock:** `P_lock` is sampled at `t_lock`. If `start_delay < lock_ticks` at activation, it is sampled at `T_act`. The burst goes to `P_lock` even if the target moves or dies.
- **Validator:** `lock_ticks < interval`. Aim lock and `reaim_each_volley` can't be combined.
- **Upward aim:** there is no clamp. A player above the emitter is fired at upward.

**Example:** `O` = (180, 100), target (210, 500) → `θ` = 1.4959 rad (85.7°).

**F6. Pattern geometry**

**a. Aimed fan:** `angle[i] = θ + (i − (n−1)/2) × σ`, for i = 0…n−1, with `n = count_eff`.
- `σ` (spread) is 0 only when n = 1; otherwise ≥ 0.12.
- **Example:** n = 5, σ = 0.165 around 1.4959 → 1.1659, 1.3309, 1.4959, 1.6609, 1.8259.

**b. Ring:** `step = 2π/n`; `angle[i] = offset + i × step`.
- `offset` is either fixed or `u × step`, with `u = rng.randf()` in [0, 1). A seeded rotation never exceeds one gap.
- **Example:** n = 24, u = 0.37 → offset 0.0969.

**c. Spiral:** `φ(c) = fposmod(angle_offset + c × step, 2π)`; `angle[i] = φ(c) + i × 2π/arms`.
- The angle comes from the integer volley counter, so it never drifts. The first volley fires at `angle_offset`.
- **Caveat:** a second spiral runner that activates later has its own `c` and is not locked opposite the first. Use `arms = 2` where the opposition matters.
- **Example:** step 0.33, c = 20 → 0.3168.

**d. Wall:** slot positions are `x[i] = O.x + (i − (n−1)/2) × s`.
- **Valid gap starts:** `V = { gs in [m, n−g−m] : x[gs−1] ≥ E and x[gs+g] ≤ 360−E }`.
- **Gap choice:** `gs = V[floor(rng.randf() × |V|)]`. The random draw always happens, so the stream stays stable.
- **If `V` is empty:** use the in-range `gs` nearest x = 180.
- Slots gs … gs+g−1 are not fired.

| Symbol | Default | Range | Description |
|---|---|---|---|
| `n` | — | ≥ 3 | Slot count |
| `s` | 16 px | ≥ 8 | Spacing |
| `g` | 1 | ≥ 1 | Gap width in slots |
| `m` | 1 | ≥ 1 | Edge slots that always fire, so bullets always bound the gap |
| `E` | 8 px | 0–24 | Screen-edge margin |

**Example:** n = 7, s = 16, O.x = 180 → x = 132 … 228. V = {1…5}. With u = 0.62, gs = 4, so the bullet at x 196 is skipped. The corridor is 180 → 212, which leaves 27 px clear.

**e. Radial curve:** `out = atan2(O − C)`, or π/2 if `|O − C| < 0.5`. `param = (c even ? +1 : −1) × spin`, with `|spin| ≤ 3` (Bullet manager clamp). Skipped volleys still flip the sign.

**f. Flak burst:**
1. `D = clamp(|T − O| − standoff, 0, flak_distance)`.
2. `B = O + unit(θ) × D`.
3. Clamp `B` into `[12, 348] × [play_top + 12, 628]`.
4. If `|B − T| < standoff` after the clamp, `B = O`.
5. The ring (geometry b) spawns at `B` `flak_delay` ticks after the volley.

| Symbol | Default | Range | Description |
|---|---|---|---|
| `flak_distance` | 240 | 80–400 | Max distance along the aim (migrated values ×0.75) |
| `standoff` | 56 | ≥ `spawn_safe_radius` + 8 | Burst centre never closer than this to the aim point |
| `flak_delay` | 36 | ≥ 18 | Fuse length (tell time) |

**Example:** O = (100, 120), T = (150, 520) → D = 240, unit(θ) = (0.1240, 0.9923), B ≈ (129.8, 358.2), which is 163.1 px from T.

**Flak timing:** the aim, `B` and the ring's random offset are fixed (and drawn) at the volley tick, when the fuse is lit; `volley_fired` and `flak_fuse` are sent then. Spawn safety (F7) is checked at the burst tick, against player positions on that tick, when the ring bullets actually spawn.

**g. Seeded spray (even spacing + jitter):**
`angle[i] = θ₀ − A/2 + (i + 0.5 + (u_i − 0.5) × J) × (A/n)`
`speed[i] = v_min + u'_i × (v_max − v_min)`
- Random draws go in a fixed order per bullet: angle, then speed.
- `θ₀` is the aim, or π/2 for unaimed sprays.
- `A` (arc) is 0.3–1.6 rad.
- `J` (jitter) is 0–1, default 0.5. With J < 1, bullets never bunch up and lanes always stay open.
- `v_min` is ≥ 70.

**F7. Spawn safety**

`skip = any Active player p with |spawn − p.centre| < R_safe` (strict `<`)
Required: `R_safe ≥ r_p + r_b + v_spawn × t_react / 60`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Safe radius | `R_safe` | float px | 24–96 (default **42**) | Global default (`spawn_safe_radius`); a pattern may set a larger value |
| Spawn speed | `v_spawn` | float px/s | 70–480 | After the Bullet manager clamp |
| Reaction | `t_react` | int ticks | 9 | 6 ticks to see and press, plus 3 ticks to move 9.5 px at 3.5 px per tick |

**Coverage:**
- **42 px** covers spawn speeds up to about 243 px/s. That includes every prototype pattern; the fastest is the 240 px/s pod stream, which needs 41.5.
- **A 480 px/s needle** needs `R_safe` ≥ 76.25, set on that pattern and checked by the validator.

**Example:** a bullet 40 px from a player is skipped; one 44 px away spawns.

**F8. Fairness validator** (authoring checks, never runtime clamps)

A unit test runs this over every pattern in `data/patterns/` and the boss and enemy resources. Errors fail the test; warnings report.

**Constants:**

| Constant | Value | Meaning |
|---|---|---|
| `lane_min_clear` | 14 px | 2 × `r_p` + 2 × 4 px margin |
| `d_ref` | 160 px | Close aimed distance |
| `D_lane_max` | 120 px | Distance at which ring lanes are measured |
| `react` | 18 ticks | |

| Check | Rule | Prototype data |
|---|---|---|
| Fan lane | `σ × d_ref − 2 r_b ≥ 14` (n ≥ 2) | min 21.4, pass |
| Ring lane | `n ≤ 2π × D_lane_max / (14 + 2 r_b)` (orb: 39) | 12, 20, 24: pass |
| Flak ring lane | same, with `standoff` for `D_lane_max` (standoff 56: n ≤ 18) | — |
| Spiral arm gap | `v × (interval/60) × 2π / (\|step\| × arms) − 2 r_b ≥ 14` | 133, pass |
| Wall corridor | `(g+1) × s − 2 r_b`: < 14 error, < 20 warning | 27, pass |
| Wall speed | `v ≤ 205` px/s | 110, pass |
| Wall reach | `min(interval, interval_full if ≥ 0) ≥ 18 + 360/3.5 = 121` ticks (time to cross to the gap) | 138, pass |
| Lock tell | `lock_ticks` is 0 or 18–60 (warning outside); lock patterns need `start_delay ≥ lock_ticks` (warning) | — |
| Flak | `flak_delay ≥ 18` (error); `standoff ≥ R_safe + 8` (error); peak concurrent lit fuses per owner (and per scene, Director V-D5) `≤ flak_fuse_max` 8 (error; wave 4) | — |
| Spray | `n ≤ (1 − J) × A × d_ref / (14 + 2 r_b)` (A 1.2, J 0.5: n ≤ 5) | — |
| Spawn safe | `R_safe ≥ r_p + r_b + 0.15 v` | 41.5 ≤ 42, pass |
| Burst overlap | F2 constraint, on `interval` and `interval_at_full` | pass |
| Lock | `lock_ticks < interval`; not combined with re-aim | — |

**Wall details:** velocity is `unit(direction) × speed`. `V` is recomputed every volley (count can change with intensity). For `g > 1`, "nearest x = 180" uses the gap's centre.

**Random draws when nothing varies:** a ring in fixed offset mode makes no draw (it never does, so the stream is stable). A spray with J = 0 still makes its angle draws.

**Runtime does only these:** F1 minimums, the F2 fallback, the wall `V` set, the flak clamps, the flak fuse cap skip (8 lit per scene; skipped volley counts as fired and draws RNG), the ring offset bound, the F7 skip, and the Bullet manager's own speed clamps.

**F9. Density budget**

`rate = (count_eff − gap_slots) × burst_count × 60 / interval_eff` (bullets per second)
`N_runner = rate × L_path / v_eff`
`N_scene = Σ N_runner` over runners active together, checked at each gate boundary

**Scope:** the validator checks `N_scene` per owner (one boss, or one enemy type) for every intensity value where the set of active runners changes (gate bounds are inclusive, so runners sharing a bound overlap there). Co-active emitters across different enemies are checked by the Wave and stage director (16) against the same 1,700 budget. *(Amended 2026-11-03:* the cross-enemy check is the Director's `StageValidator` rule V-D5, which also applies the per-wave curve caps 60 / 80 / 100 / 120 / 150 at N = 1; see [wave-and-stage-director.md](wave-and-stage-director.md).)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Path length | `L_path` | px | 640 or 320 | 640 for aimed, wall, spray and curve; 320 for ring, spiral and flak (estimate) |
| Effective speed | `v_eff` | px/s | 70–480 | Straight and Curve: speed. Accelerate: (speed + cap)/2. Warp: 66 (estimate) |
| Budgets | | | | `N_runner` ≤ 450 (warning); `N_scene` ≤ 1,700 (error, = Bullet manager's 85% of 2,000) |

**Example:** Jet carrier with everything active:
- Fan: 9 × 60/33 = 16.4/s × 640/200 = 52.
- Pods: 34.
- Walls: 30.
- Total ≈ 116.

Fortress at full intensity is about 155. The path lengths and the Warp estimate are confirmed against the Bullet manager's profiler counters.

*Note (2026-11-03, Boss power budget (15)):* the Jet "≈ 116" is the sum of all runners **ignoring gates and part deaths**. The true worst case over part-destruction subsets is **79.12** (Jet) and **154.90** (Fortress = the core's two runners, 91.4 + 63.5). The enraged all-parts-alive scene must still pass the 1,700 check (Boss power budget). F3, F8 and F9 are exposed as pure functions (`PatternMetrics.lane_clear`, `runner_density`, `interval_eff`, `count_eff`) so Boss power budget (15) lints call them rather than copying them.

**F10. Canvas migration (one-time, data only)**

**Principle:** scale what spans the canvas; never shrink a lane the hitbox must fit through. This replaces the Bullet manager's "spacing and counts ×0.75" (closes BM Open Question 4).

| Parameter | Rule |
|---|---|
| Timing | F1 conversion |
| Speeds | Unchanged (Bullet manager decision); minimum 70 |
| Fan `spread` | ×0.75; count unchanged |
| Wall | `count` → `roundi(count × 0.75)`; spacing unchanged (corridor stays 27 px) |
| Ring, spiral, radial curve | Unchanged (angular; lanes depend on count, not width) |
| Flak `flak_distance` | ×0.75 (standoff is absolute) |
| Boss anchors, offsets, orbits | Out of scope; Boss (14) migrates them (anchor x 240 → 180, offsets ×0.75) |

| Resource | Parameter | Old | New |
|---|---|---|---|
| fortress `core_spiral` | interval / full / delay / arms | 0.11 / 0.045 / 0.5 s / 1 | 7 / 3 / 30 / **2** |
| fortress `core_spiral_second_arm` | — | separate runner, offset π | **removed** (merged into `core_spiral` arms 2, so the arms stay opposite; F6c caveat) |
| fortress `core_rage_ring` | interval / delay | 1.1 / 0.3 s | 66 / 18 (count 24 kept) |
| fortress `turret_fan` | spread / interval | 0.28 / 1.1 s | 0.21 / 66 |
| fortress `engine_ring` | interval | 1.9 s | 114 |
| jet `core_accel_fan` | spread / interval / full / speed | 0.22 / 1.3 / 0.55 s / 50 | 0.165 / 78 / 33 / **70** |
| jet `pod_stream` | interval / gap | 1.4 / 0.1 s | 84 / 6 |
| jet `wing_wall` | count / interval | 9 / 2.3 s | 7 / 138 (spacing 16 kept) |
| plasma `core_shielded_warp_ring` | interval | 1.8 s | 108 |
| plasma `core_exposed_warp_ring` | interval / delay | 1.2 / 0 s | 72 / 1 |
| plasma `core_exposed_fan` | spread / interval / delay | 0.25 / 1.2 / 0.6 s | 0.1875 / 72 / 36 |
| plasma `shield_curve` | interval | 0.16 s | 10 |

Other defaults convert as `start_delay` 0.8 s → 48 and `burst_gap` 0.1 s → 6. Rounding makes the spiral 6–11% slower; retune in playtest.

> Formulas proposed by `systems-designer`; decisions by the user (2026-11-03): ticks authored directly, overlap pushes later, lock-tick targeting, lock and re-aim can't be combined, spiral from the counter, wall `V` set, spawn safety 42 px with per-pattern override, spray jitter 0.5, migration rule above (closes BM Open Question 4), fan speed 50 → 70.

## Edge Cases

**Breaker net (added 2026-11-03, wave 4, plane-kits-sentry-breaker.md):** a Breaker Erase Net removes up to ~120 bullets per 930 ticks per slot. Patterns must stay survivable without it, and lethal shapes must not depend on those bullets surviving (a hole erased in a wall or ring must not make the rest unfair, and a pattern must not be balanced on the assumption that the net is absent).

**Timing and intensity**

- **If intensity changes during a burst**, the burst finishes with the interval and count read at its start (F3). The new value applies from the next burst.
- **If intensity leaves the gate range during a burst**, the rest of the burst is dropped. When intensity comes back into range, the runner waits `start_delay` again (Rule 7).
- **If intensity crosses a gate boundary back and forth**, each re-entry restarts `start_delay`, so the pattern may never fire. Owners keep intensity steady or only rising (Boss: parts destroyed); any smoothing is the owner's job.
- **If intensity arrives outside 0–1**, it is clamped to 0–1.
- **If the game is paused**, runners aren't ticked, so timers, fuses and locks all freeze.

**Fire hold**

- **If a fire hold starts during a burst**, volleys inside the hold are skipped and the rest of the burst fires on schedule (Rule 8).
- **If a flak fuse runs out during a fire hold**, its ring is skipped. The fuse is used up and does not fire late.
- **If a lock tell is running when the hold starts, and its burst falls inside the hold**, the tell ends with `lock_ended(fired = false)` and no bullets follow.
- **If a volley is skipped (by fire hold or spawn safety)**, it still makes all its random draws: ring offset, wall gap, spray angles and speeds. The random stream never depends on what the players did, so a pattern stays learnable.

**Targeting**

- **If the target dies between the lock and the burst**, the burst still fires at `P_lock` (F5).
- **If the target dies during a re-aiming burst**, the burst keeps its last aim.
- **If a player joins or respawns during a burst**, the rotation includes them from the next burst.
- **If a player is not Alive (Selecting, Dead, Continue, Inactive)**, they are never targeted. If nobody is Alive, aimed patterns fire straight down and bullets store slot 0 (Rule 11).
- **If a target is flying in after respawn**, it is Alive. It can be targeted and aimed at its current position, but it is still invulnerable (Collision C3).

**Spawn safety**

- **If every bullet of a volley is too close to a player**, the volley spawns nothing, but it still counts as fired for timing and rotation. `volley_fired` (the sound) is sent only if at least one bullet spawned.
- **If spawn safety removes bullets next to a wall gap**, the corridor gets wider. This is allowed: safety only removes bullets, never adds them.
- **If a flak ring bursts near a player who isn't the target**, only the ring bullets within that player's safe radius are skipped.
- **If a player is in FlyIn or another non-Active state**, spawn safety ignores them (Rule 14). They are invulnerable anyway.

**Geometry**

- **If no valid wall gap fits on-screen** (`V` is empty), the gap goes in the in-range slot nearest x = 180 (F6d).
- **If an emitter is partly or fully off-screen**, it still fires. The Bullet manager keeps bullets in the margin that are moving inward and removes the rest (BM F8). Whether off-screen emitters should fire is the owner's choice.
- **If `count_eff` is 1**, a fan fires one aimed bullet (spread ignored) and a ring fires one bullet at its offset.
- **If a spiral's `step` is 0**, it fires a fixed-direction stream.
- **If a radial curve's origin equals the centre**, it fires straight down (F6e).
- **If a flak burst point would be too close to the target after clamping**, it bursts at the emitter (F6f step 4).

**Pool and order**

- **If the enemy pool is full**, the Bullet manager refuses the request. The runner doesn't retry and doesn't change its timing. A refusal means the content is too dense (F9).
- **If several runners fire on the same tick**, they run in emitter registration order, then pattern-list order, then bullet index. Each emitter has its own random stream, so the order only affects which requests are refused when the pool is full, and the state hash.

**Stopping**

- **If an emitter stops while a lock tell is running**, the tell ends (`lock_ended`, `fired = false`) and no burst fires.
- **If intensity gates the runner out during a lock tell**, the tell ends that tick with `lock_ended(fired = false)`.
- **If a lock's burst falls inside a fire hold**, `lock_ended(fired = false)` is sent on the burst tick (not when the hold starts).
- **If nobody is Alive at the lock tick**, no tell is shown and the burst fires straight down with slot 0 (Rule 11). A player who becomes Alive between the lock tick and the burst is not targeted until the next burst.
- **If `start_delay` is shorter than `lock_ticks`**, the first tell is shorter than authored; the validator warns (F8).
- **Fire hold timing:** Collision sets the hold on death tick T0 (GameLoop step 6) for T0+1 to T0+30. Runners (step 4) read it on T0+1, so there is no one-tick gap.
- **If an emitter's owner is destroyed**, its lit flak fuses are cancelled. If the emitter is only gated, or stopped without being destroyed, its lit fuses still burst (States).
- **If the stage ends**, owners remove their emitters, which cancels all fuses. The Bullet manager's clear-all removes the bullets.

> `systems-designer` not consulted for this section (lean mode).

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Bullet manager (3) — GDD | Hard | `request_spawn(pos, vel, shape, behaviour, param, target_slot)`; refusals are counted by BM. Shapes, behaviours, speed clamps (70–480), hit radii and the density target (≤ 1,700) are BM's. |
| Game events and session (1) — GDD | Hard | Slot states. **Alive** decides who can be targeted (F4). Not ticked while paused. |
| Collision, damage and lives (6) — GDD | Hard | `death_fire_hold` active flag; runners skip volleys while it is on (Rule 8). |
| Player plane (5) — GDD | Hard | Each slot's hitbox centre and state (**Active**) for aiming (F5) and spawn safety (F7). Read from the same per-tick registration the BM uses. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Enemy and AI (10) — GDD | Hard | Owns emitters: pattern list, origin, centre, intensity, start/stop. Off-screen enemy emitters do not fire: arm once when the muzzle enters the fire zone (`enemy_fire_inset` 4 px), retire once (Enemy Rule 18). Intensity is held constant per enemy (frozen at spawn). Reads `next_volley_in(emitter) -> int` (ticks to the next volley over the emitter's runners, −1 if none; read-only) for enemy tells. |
| Boss and boss parts (14) — [GDD](boss-and-boss-parts.md) | Hard | Same as Enemy, but exempt from fire-zone arming (emitters start at `boss_started`; placement lint). Intensity = `I_eff` (parts destroyed ÷ non-core parts, floored by the enrage ramp; replaces "rage"). `owner_id` = the unique part `id`. Lint: patterns that open at I > 0 need `start_delay ≥ 18`. Stops a part's emitter when the part dies (cancels its fuses). Migrates boss anchors, offsets and orbits to 360 px (F10 is out of scope for those). Preview patterns are derived by Boss power budget (15). |
| Boss power budget (15) — [GDD](boss-power-budget.md) | Soft | Calls `PatternMetrics` (F3, F8, F9 as pure functions) for its power score and lints; derives read-only preview patterns (its F5). Enforces "one new trick per era" (V4). |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | Soft | Chooses which patterns and behaviours each era's enemies use (data only). The library has no era logic. |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | Soft | Removes emitters at stage end (through their owners, `despawn_all`); runs the cross-enemy F9 density check (validator V-D5). |
| Audio (24) — [GDD](audio.md) | Soft | `volley_fired` once per volley with ≥ 1 bullet spawned (BM: spawn sounds come from the requester; gap ≥ 3 ticks per sound ID). Flak fuse ticks use tail-aligned samples (Audio F8). |
| VFX (25) — [GDD](vfx-and-screen-feedback.md) | Soft | `lock_started` / `lock_ended(fired)` tells, `flak_fuse(pos, ticks)` marker. At most 8 lit flak fuses per scene (`flak_fuse_max`, Rule in Flak burst; validator + runtime skip, decided 2026-11-03 wave 4); VFX's TELL pool references this cap. |

**Amendments to other docs (applied at wrap-up):**
1. **Bullet manager:**
   - Change the Pattern library row and F0's "spacing and counts ×0.75" so they point to Pattern library F10.
   - **Close Open Question 4**: the migration rule is F10, and the targeting rule is per-emitter rotation (F4).
2. **Collision:** the Pattern library (9) applies `death_fire_hold`. Runners skip volleys. Collision's text currently names only Enemy (10) and Boss (14).
3. **Session:** add a downstream row for the Pattern library (9), which reads Alive slot states for targeting.
4. **Player plane:** add a downstream row for the Pattern library (9), which reads hitbox centre and state. Fix line 114's "×0.75 pattern spacing (F0)" to point to Pattern library F10.
5. **Systems index:** row 9's dependencies become **1, 3, 5, 6**, and its status becomes Designed.

## Tuning Knobs

**Global library rules** (`data/pattern_rules.tres`, working name)

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `spawn_safe_radius` | 42 px | 24–96 | Point-blank bullets with no time to react (fails the F7 check) | Emitters near players go silent; hugging bosses becomes a safe spot | Per-pattern override; `t_react`; player speed 210 |
| `t_react` | 9 ticks | 6–15 | Validator passes unfair spawns | Every fast pattern needs a huge override | `spawn_safe_radius` |
| `lane_min_clear` | 14 px | 10–24 | Validator passes lanes only perfect play fits | Dense curtains rejected; bosses feel thin | Player hitbox 3.0 (locked) |
| `d_ref` | 160 px | 100–240 | Fan check too strict | Fan check too loose (lanes measured too far out) | Fan `spread` |
| `D_lane_max` | 120 px | 80–200 | Ring check too strict | Rings too dense near the emitter | Ring `count` |
| Wall corridor warning | 20 px | 14–28 | Tight corridors pass silently | Warnings everywhere | `lane_min_clear` |
| Wall edge margin `E` | 8 px | 0–24 | Gap can sit against the screen edge | Fewer valid gap positions; walls feel predictable | Wall `count`, `spacing` |
| Runner density warning | 450 bullets | 300–800 | Warnings on every boss pattern | One pattern can fill the screen alone | Scene budget |
| Scene density budget | 1,700 | **Owned by Bullet manager** (85% of `enemy_cap`) | — | — | BM F10 |
| Flak clamp inset | 12 px | 8–24 | Bursts at the very edge, partly off-screen | Bursts bunch towards the centre | `play_top` |

**Per-pattern parameters** (set on each pattern resource; ranges are from the formulas)

| Knob | Default | Safe range | Effect | Notes |
|---|---|---|---|---|
| `interval` / `interval_at_full` | — | 1–3600 ticks | Fire rate | F2 overlap rule; −1 = no scaling |
| `start_delay` | 48 | ≥ 1 | Warning time before the first volley | Low = pattern feels like an ambush |
| `burst_count` / `burst_gap` | 1 / 6 | ≥ 1 / ≥ 1 | Streams vs single volleys | F2 constraint |
| `min_intensity` / `max_intensity` | 0 / 1 | 0–1 | When the pattern is on | Owner drives intensity |
| `count` / `count_at_full` | per type | ≥ 1 | Density | F8 lane checks; F9 budget |
| `speed` | 150 | 70–480 (BM clamp) | Reaction time | Fast ⇒ larger `spawn_safe_radius` |
| `shape`, `behaviour`, `param` | orb, Straight | BM vocabulary | Era language | Era shift (19) chooses |
| `spread` (fan) | 0.25 | 0.12–0.6 rad | Side-step distance | F8 fan lane |
| `reaim_each_volley` | false | bool | Tracking stream | Not combined with lock |
| `lock_ticks` | 0 | 0 or 18–60 | Tell length for radar locks | Under 18: tell unreadable; over 60: free dodge |
| `offset_mode` (ring) | seeded | fixed / seeded | Learnable vs varied | Seeded within one gap |
| `arms` / `step` (spiral) | 1 / 0.33 | 1–6 / −1.0–1.0 rad | Spiral shape | F8 arm gap |
| `spacing` / `gap_width` (wall) | 16 / 1 | ≥ 8 / ≥ 1 | Corridor size | F8 corridor |
| `spin` (radial curve) | 1.3 | −3.0–3.0 | Curve tightness | BM clamp |
| `flak_distance` / `standoff` / `flak_delay` | 240 / 56 / 36 | 80–400 / ≥ 50 / ≥ 18 | Where and when flak bursts | Standoff ≥ safe radius + 8 |
| `arc` / `jitter` (spray) | — / 0.5 | 0.3–1.6 / 0–1 | Spray width and randomness | F8 spray count limit; J = 1 can close lanes |
| `spawn_safe_radius` override | (global) | ≥ global | Fast patterns | F7 check |

**Owned elsewhere (not knobs here):**
- Bullet speeds and clamps, behaviour parameters (accel, Warp times), hit radii, `enemy_cap`: Bullet manager (3).
- Player hitbox and speeds: Player plane (5).
- `death_fire_hold`: Collision (6).

## Visual/Audio Requirements

**Rules for every tell:**
- Draw layer 5, below enemy bullets (layer 8), so a bullet always draws on top.
- Chunky shapes, 2 px or wider, with no Ink outline.
- Colours come from the era Accent or Shadow, an alert amber, or the targeted player's ring colour.
- Never use Void Indigo (`#4A5CFF`), Ink (`#0B0B2A`), or a cyan, teal, white or violet-pink fill.
- Never use the reserved bullet shapes: no circles, outlined rings, rice, needles or orbs.
- Every tell counts against the 150-particle cap (AB §8.6, BM V8).

**V1. Muzzle flash**
- **Look:** a 3-frame, 6-tick smoky puff (2 ticks per frame) at the emitter's muzzle, in the AB §6.8 explosion language. At most 10 px wide, sitting on the emitter sprite.
- **When:** only when at least one bullet spawned (the same condition as `volley_fired`). One flash per emitter per volley; streams and bursts flash only on the first volley of the burst.
- **Era colours (recolour only):**

| Era | Colour |
|---|---|
| 1941 | Sepia-orange smoke |
| 1970s | Hard orange with a dark puff |
| 2030s | Cyan sparks (post-MVP) |
| 2100 | Magenta shards (post-MVP) |

**V2. Aim-lock tell** (`lock_ticks` 18–60)
- **Line:** a dashed line from the emitter to the locked aim point. Dashes are 2 px, in the **targeted player's ring colour and pattern** (AB §4.4), and crawl outward at 2 px per tick. With `lock_ticks` 18 the line fades in over the first 6 ticks.
- **Reticle:** a 10 px corner-bracket reticle at the aim point (four corners, 1 px), tightening by 4 px over the lock. The targeted player's pip count is drawn at one corner, because P3 and P4 have equal luma.
- **Co-op limits:** at most 4 lock tells at once. If more than 2 are active, new ones show the reticle only (no line).
- **Fired:** the reticle flashes bright for 2 ticks, the line vanishes, and the muzzle flash plays.
- **Not fired** (`lock_ended(fired = false)`): the reticle breaks into its 4 corners, which fall 6 px and fade over 8 ticks. No flash and no sound.

**V3. Flak fuse marker** (`flak_delay` 36)
- **Look:** a dark-grey or era-Shadow smoke puff at burst point B. It grows from 6 to 14 px, with a 3 px amber spark inside. Not an outlined ring, and no dotted circle around B.
- **Countdown:** the spark blinks every 12 ticks, then every 6 ticks for the last 12 ticks, and stays solid for the final 6. Players read "speeding up, then solid" without numbers.
- **Burst:** on the last tick the puff expands to 24 px over 3 frames as the ring spawns. The ring bullets draw above it.

**V4. Era pattern language** (guidance for Enemy 10, Boss 14 and Era shift 19). One new trick per era is enforced by Boss power budget (15) (novelty rules; added 2026-11-03).

| Era | Leading patterns | Behaviours |
|---|---|---|
| 1941 | Aimed fan, ring, wall; **flak is the signature** | Straight *(2026-11-03: "some Curve" removed; 1941 is Straight only, Era shift 19 Rule 8, Boss power budget Rule 18)* |
| 1970s | **Aim-locked fans**, walls; spirals on boss cores | Accelerate (rice streams) |
| 2030s (post-MVP) | Spirals, curves, timing windows around shields | Curve |
| 2100+ | Warp rings and fans | **Warp** (freeze and re-aim) |

Shapes never change between eras; only the patterns and behaviours do (BM V7). Each era's new trick appears alone in its first waves before being combined (concept §10, systems index boss-foreshadowing rule).

**A1. Audio**
- **Constant across eras:** cue timing, the retrigger gap (≥ 3 ticks per sound ID, BM rule) and what each cue means. Eras change only the timbre.
- **Volley sounds** (one per volley, only if at least one bullet spawned):

| Pattern | Sound |
|---|---|
| Fan / stream | Short, quick "pew" cluster |
| Ring | Wider, lower thump |
| Wall | Sweeping tone |
| Spiral | Rotating repeated tick (never one per bullet) |

- **Lock tone:** pitch rises over `lock_ticks` and ends in a short high click when the burst fires. When not fired, there is no click.
- **Flak fuse:** a tick on each blink, speeding up with the blinks, then a low "pop" on the burst.
- **Behaviours:** Warp keeps its single cue per volley (BM A2). Accelerate and Curve have no extra cue.
- **Era timbres:**

| Era | Timbre |
|---|---|
| 1941 | Mechanical, brassy |
| 1970s | Radar beeps, analogue sweeps |
| 2030s | Digital synth |
| 2100 | Reversed or warped |

- **Death beat:** during `death_fire_hold`, skipped volleys make no sound and no muzzle flash (Rule 8). Lock tells whose burst falls in the hold end silently (Edge Cases).

**Art bible amendments needed** (pending list, not applied):
1. AB §6.8 and §3.3: add a "combat tell" effect category (lock reticle, dashed lock line, fuse puff, muzzle flash) on layer 5. Allow corner-bracket reticles and dashed lines; outlined rings stay reserved.
2. AB §4.4: allow the slot ring colour and pattern to be used on lock lines.
3. AB §4.6: confirm an "alert amber" semantic colour, or add one.
4. AB §8.6: count combat tells in the 150-particle budget.

> Visual and audio direction from `art-director`. All of its open choices were taken as recommended under auto-approve (2026-11-03): keep the muzzle flash, line + reticle (reticle only above 2 locks), smoke puff + spark, lock line in the target's colour, silent fade when not fired.

📌 **Asset Spec**: run `/asset-spec system:bullet-pattern-library` after the art bible amendments are applied.

## UI Requirements

This system has **no player-facing UI** of its own. Its tells (V2, V3) are world-space effects, not HUD elements.

**Debug only (development builds):**
- A pattern overlay toggle draws each emitter's origin, its current target slot, the spawn-safety circles (`spawn_safe_radius`) and the lock aim points.
- Counters per tick: active runners, volleys fired and skipped, bullets skipped by spawn safety, and requests refused by the Bullet manager.
- The fairness validator (F8) prints its errors and warnings to the test log, not in-game.

## Acceptance Criteria

Defaults used: `spawn_safe_radius` 42, `t_react` 9, `lane_min_clear` 14, `d_ref` 160, `D_lane_max` 120, wall corridor warning 20, wall edge margin `E` 8, runner density warning 450, scene density budget 1,700, flak clamp inset 12, `start_delay` 48, `burst_count` 1, `burst_gap` 6, spray jitter 0.5, wall spacing 16 / gap width 1 / edge slots `m` 1, `spin` 1.3, `flak_distance` 240, `standoff` 56, `flak_delay` 36, `play_top` 48 (1–2P) or 72 (3–4P), `r_p` 3.0, bullet radii orb 2.5 / rice 1.5 / needle 1.25 / ring 2.0, 60 ticks/s. Slots 0-indexed. Tests read every number from `data/pattern_rules.tres` and the pattern resources, never literals, except the F10 golden table (AC-50), whose values are the spec.

**Test setup:**
- **Classes:** the logic lives in plain `RefCounted` classes (working names `Emitter`, `PatternRunner`), with no nodes and no `delta`. `Emitter.tick()` advances one 1/60 s step and keeps an integer tick counter.
- **Injected:**
  - `run_seed`, or a scripted `FakeRng` that returns queued `randf()` values (used where an AC quotes `u`);
  - slot states and hitbox positions (`set_slots`);
  - the `death_fire_hold` flag;
  - `update(origin, centre, intensity)`;
  - `stop(destroyed: bool)`;
  - a fake `BulletField` that records every `request_spawn(...)` with its tick and order, and can refuse after N.
- **Read after a tick:**
  - the request log;
  - the event log (`volley_fired`, `lock_started`, `lock_ended`, `flak_fuse`, `flak_burst`);
  - runner state, the volley counter `c`, the target cursor, lit fuses;
  - the debug counters (`spawn_safety_skips`, …);
  - `state_hash()`.
- **Files and tags:**
  - Tests: `tests/unit/test_pattern_[timing|targeting|geometry|safety|determinism|validator|migration|edges].gd`, `extends SceneTree` like `test_chain_tracker.gd`, named `test_pattern_[scenario]_[result]`.
  - Integration: `tests/integration/test_pattern_*.gd`. Perf: `tests/perf/pattern_bench.tscn`. Evidence: `production/qa/evidence/pattern-library/`.
  - Tolerances: angles ±1e-4 rad, positions ±0.01 px unless stated.
  - Tags: [Unit] headless logic · [Integration] real GameLoop/BulletField/Collision · [Perf] reference machine · [Manual] human.

### Patterns, emitters, runners (Rules 1–4)

- **AC-01 [Unit] (Rules 1, 3):** two emitters share one pattern resource; 600 ticks run and emitter A stops at tick 200 → the resource's property hash is unchanged, and B's request log is identical to a run without A.
- **AC-02 [Unit] (Rule 2):** stream (`burst_count` 6, `burst_gap` 6); the owner moves the origin (100, 50) → (140, 50) between ticks 148 and 154 → tick-148 bullets spawn at (100, 50), tick-154 bullets at (140, 50). A radial curve takes `out` from the `centre` passed that tick.
- **AC-03 [Unit] (Rule 3):** emitter with [fan, ring], both `start_delay` 48, `interval` 84, activated at 100 → both fire on 148, fan requests first. Closing the ring's gate leaves the fan's schedule unchanged.
- **AC-04 [Unit] (Rule 4):** a 24-bullet volley → each call carries (pos, vel, shape, behaviour, param, target_slot) and the runner keeps no bullet reference. The fake field refuses 10 of 24 → nothing is retried, and the next volley fires on schedule.

### Timing, intensity, states (Rules 5–7, F1–F3)

- **AC-05 [Unit] (F1):** 2.3 s → 138; 0.045 s → 3; a 0 s start delay → 1. `interval`, `burst_gap`, `burst_count`, `start_delay` or `flak_delay` authored as 0 load as 1, and the runtime clamp holds if changed after load. `lock_ticks` 0 stays 0.
- **AC-06 [Unit] (F2):** `T_act` 100, `start_delay` 48, `burst_count` 6, `burst_gap` 6, `interval` 84 → volleys at exactly 148, 154, 160, 166, 172, 178; next burst 232. Nothing fires before 148. Authored `start_delay` 0 → first volley at `T_act` + 1.
- **AC-07 [Unit] (F2 fallback):** 6 × 6 with `interval_eff` scaled to 20 → `interval_eff` = 31. All 6 volleys fire; the next burst starts 31 ticks after the burst start.
- **AC-08 [Unit] (F3):**
  - Interval 78 → 33: I = 0.5 → 56, I = 0 → 78, I = 1 → 33.
  - Count 5 → 9: I = 0.125 → 6, I = 0 → 5, I = 1 → 9.
  - A negative `*_full` leaves the value unchanged. Results are never below 1.
- **AC-09 [Unit] (F3 gate):** gate [0.5, 1.0] → active at 0.5, 1.0 and 0.4999995; inactive at 0.49999. I = 1.7 acts as 1.0 and −0.2 as 0.0. A change at tick t takes effect at tick t.
- **AC-10 [Unit] (intensity mid-burst):** a burst starts at I = 0 (78→33, 5→9); I jumps to 1.0 on the second volley → the burst finishes with count 5, and the next burst starts 78 ticks after this one. The burst after that uses 9 and 33.
- **AC-11 [Unit] (gate leave and re-enter):** AC-06 schedule, I leaves the range at 160 → volleys 166, 172 and 178 don't fire; state Gated. I re-enters at 200 → first volley at 248. Toggling the gate every 20 ticks → zero volleys in 600 ticks.
- **AC-12 [Unit] (States):** AC-06 gives Gated → Waiting → Firing (148) → Cooling (after 178) → Firing (232). With `lock_ticks` 30: Cooling → Locking at 202 → Firing at 232. Leaving the range from any state → Gated. `stop` → Stopped (final).

### Fire hold, stopping, fuses (Rules 8–9, Edge Cases)

- **AC-13 [Unit] (Rule 8):** AC-06 schedule on a spiral with a hold covering 154–166:
  - volleys 154, 160 and 166 make no requests and no `volley_fired`;
  - volleys 148, 172 and 178 fire, and 172 uses φ(4) exactly as in an unheld run;
  - `c` ends at 6, and the cursor advanced once.
- **AC-14 [Unit] (RNG on skipped volleys):** seeded ring, wall and spray patterns, run with and without a hold over volley 2 → identical RNG state after the burst, and identical post-hold logs. The skipped volley's draws equal the unheld run's draws.
- **AC-15 [Unit] (flak fuse in hold):** a fuse lit at 148, ring due at 184; a hold covering 184 → no ring, now or later. A volley inside a hold lights no fuse and sends no `flak_fuse`.
- **AC-16 [Unit] (lock and hold):** `lock_ticks` 30, burst at 148, tell from 118; a hold covering 148 → `lock_ended(fired = false)` at 148, no bullets; the cursor advanced at 118. Without the hold → `lock_ended(fired = true)` at 148.
- **AC-17 [Unit] (Rule 9):** `stop` at 160 mid-burst → no requests from 160, state Stopped, burst not resumed. A stop during a lock tell → `lock_ended(fired = false)` that tick.
- **AC-18 [Unit] (fuse survives):** a fuse lit at 148 still bursts at 184 if the runner is gated at 160, or stopped with `destroyed = false` at 160.
- **AC-19 [Unit] (fuse cancelled):** `stop(destroyed = true)` at 160 cancels a fuse due at 184. Removing all emitters cancels every lit fuse.
- **AC-20 [Integration] (pause):** a lit fuse (20 ticks left), a running lock tell and a mid-burst runner; the tree pauses for 30 s → on resume all timers continue (the fuse fires 20 ticks after resume), matching an unpaused control.
- **AC-21 [Unit] (lock edge cases):**
  - Intensity gates out during a tell → `lock_ended(fired = false)` that tick.
  - Nobody Alive at the lock tick → no `lock_started`; the burst fires straight down with slot 0.
  - The validator warns when `start_delay < lock_ticks`, or when `lock_ticks` is outside 0 or 18–60.

### Targeting and aim (Rules 10–13, F4, F5)

- **AC-22 [Unit] (F4):**
  - Alive {0, 2, 3} with `prev` 0 → targets 2, 3, 0, 2.
  - New emitter with Alive {1, 3} → 1 first.
  - Solo with slot 2 → always 2.
  - Nobody Alive → none, cursor unchanged. Then Alive {3} with the cursor at 1 → 3.
- **AC-23 [Unit] (Rule 10 scope):** every bullet of a 6-volley burst, ring bullets included, stores the burst's single target. The cursor advances once per burst, including bursts skipped by hold or spawn safety.
- **AC-24 [Unit] (join and death mid-burst):** slot 1 becomes Alive on volley 3 of a burst targeting 0 → the burst is unchanged; the next rotation includes 1. The target dying mid-burst on a non-re-aim pattern changes nothing in that burst.
- **AC-25 [Unit] (F5):**
  - O (180, 100), T (210, 500) → θ = 1.4959.
  - |d| = 0.424 → π/2; |d| = 0.5 exactly (T (180.5, 100)) → θ = 0.
  - T (180, 50) → −π/2 (no upward clamp).
  - No target → velocity direction (0, 1), and bullets store slot 0.
- **AC-26 [Unit] (Rule 12):** a normal burst takes θ once at volley 0, even if the target and origin move. With `reaim_each_volley`, θ is recomputed each volley; if the target stops being Alive, the burst keeps its last θ.
- **AC-27 [Unit] (Rule 13, F5 lock):** `lock_ticks` 30, `start_delay` 48, `T_act` 100:
  - `lock_started(emitter, slot, aim_point)` fires at 118, and `P_lock` is sampled at 118.
  - The player moves at 130; the burst at 148 still goes to `P_lock`, then `lock_ended(fired = true)`.
  - If the target dies at 130, the burst still fires.
  - With `start_delay` 18, `P_lock` is sampled at 100.
- **AC-28 [Unit] (F4 lock-tick selection):** an aim-lock cursor advances at 118, not 148. Bullets store the slot chosen at 118 even if it dies, and a slot joining between 118 and 148 waits for the next burst.

### Geometry (F6)

- **AC-29 [Unit] (F6a fan):**
  - n = 5, σ = 0.165, θ = 1.4959 → 1.1659, 1.3309, 1.4959, 1.6609, 1.8259.
  - n = 1 → θ exactly.
  - n = 4 → offsets ±0.5σ, ±1.5σ.
- **AC-30 [Unit] (F6b ring):**
  - n = 24, `u` 0.37 → offset 0.0969, step 0.2618.
  - `u` 0.999999 → offset below one step.
  - Fixed mode uses the authored offset and makes **no** draw.
  - n = 1 → one bullet.
- **AC-31 [Unit] (F6c spiral):**
  - step 0.33, c = 20 → 0.3168; c = 0 → `angle_offset`.
  - step −0.33, c = 1 → 5.9532.
  - step 0 → fixed direction.
  - `arms` 2 → the second arm is exactly π after the first.
  - c = 10,000 equals the closed form (no drift).
- **AC-32 [Unit] (F6d wall):**
  - n = 7, s 16, O.x 180 → x = 132 … 228; V = {1…5}.
  - `u` 0.62 → gs = 4 (x 196 not fired), and slots 0 and 6 always fire.
  - Over 1,000 volleys gs is always in V, with exactly one draw per volley.
  - Velocity is `unit(direction) × speed`.
- **AC-33 [Unit] (F6d empty V):** n = 5, s 16, O.x 0 → V empty → gap at the in-range slot nearest x 180 (gs 3); one draw still consumed. With g = 2, "nearest" uses the gap centre.
- **AC-34 [Unit] (F6e radial curve):**
  - O (220, 100), C (180, 100) → heading 0.
  - O = C, or |O − C| = 0.4 → π/2.
  - `param` is +1.3 on even volleys, −1.3 on odd. A volley skipped by hold still flips the sign.
- **AC-35 [Unit] (F6f flak):**
  - O (100, 120), T (150, 520), play_top 48 → D 240, B (129.77, 358.15) ±0.05, |B − T| 163.1.
    - `flak_fuse(B, 36)` and `volley_fired` are sent at the volley tick, and the ring offset is drawn then.
    - The ring spawns 36 ticks later, with spawn safety checked on that tick.
  - O (100, 120), T (100, 200) → D 24, B (100, 144), |B − T| = 56, so it stays.
  - O (180, −20), T (180, 100) → B clamps to (180, 60); |B − T| = 40 < 56, so B = O. With play_top 72 the clamp floor is 84.
  - |T − O| = 30 → B = O.
- **AC-36 [Unit] (F6g spray):**
  - n = 4, A 1.2, J 0.5, θ₀ π/2, all `u` 0.5 → 1.1208, 1.4208, 1.7208, 2.0208.
  - With `u` alternating 1, 0 → neighbour separation ≥ 0.15 rad.
  - Draw order is a₀, s₀, a₁, s₁…, and speeds are in [`v_min`, `v_max`]. J = 0 still makes its angle draws.

### Spawn safety (Rule 14, F7)

- **AC-37 [Unit] (F7):**
  - A bullet 40 px from an Active player is skipped; one at 44 px or exactly 42.0 spawns.
  - With an override of 76.25, one at 70 px is skipped.
  - FlyIn and other non-Active players are ignored, even when targeted.
  - With two Active players, a bullet near either is skipped.
- **AC-38 [Unit] (full-volley skip):**
  - A volley entirely within 42 px makes no requests and no `volley_fired`. `c`, the spiral angle, the cursor and the RNG advance anyway, and `spawn_safety_skips` rises by the bullet count.
  - A partial volley fires the rest and sends `volley_fired` once.
  - Skipped bullets are never respawned.
- **AC-39 [Unit] (wall and flak):** a skip next to a wall gap widens the corridor and never adds a bullet. A flak ring near a non-target Active player skips only the ring bullets within that player's radius.

### Randomness, determinism, order (Rule 15)

- **AC-40 [Unit] (Rule 15 seeding):** an emitter's seed equals `hash(run_seed, stage_index, owner_id, emitter_index)`; creating it draws nothing from the gameplay RNG. A lint finds no global `randf`, `randi`, `randf_range`, `randi_range` or `randomize` in the pattern source.
- **AC-41 [Unit] (independence):** a scene with emitters A, B and C, then (a) D is added at tick 300, (b) B is removed at 300, or (c) A, B and C are created in reverse order → A's and C's request logs equal the baseline in every case.
- **AC-42 [Unit] (determinism):** a scripted 1,800-tick scenario (4 emitters, all 7 patterns, an intensity ramp, a hold over 600–630, two moving players, one death), run twice → identical log and `state_hash()` every tick. With different player paths, each emitter's RNG state is still identical at every volley.
- **AC-43 [Integration] (fixed tick):** AC-42 through the GameLoop at 30, 60 and 144 fps, plus a 100 ms stall on frame 100 → identical `state_hash()` at tick 1,800 (same build and platform).
- **AC-44 [Unit] (same-tick order):** E1 then E2, each with [P1, P2], all firing at 148 with 3 bullets → log order E1·P1, E1·P2, E2·P1, E2·P2. Swapping registration order swaps the log order but not any emitter's own bullets.
- **AC-45 [Unit] (pool full):** the field accepts 5 of 24 → the first 5 are accepted in order, nothing is retried, the next volley is on schedule, and RNG and `c` advance as normal.

### Validator and density (F8, F9)

- **AC-46 [Unit] (all data):** the validator runs over every pattern, boss and enemy resource → zero errors, or the test fails. Warnings are listed with a count.
- **AC-47 [Unit] (F8 thresholds):**

  | Check | Passes | Errors or warns |
  |---|---|---|
  | Fan lane, orb | σ 0.165 → 21.4 | σ 0.11 → 12.6 |
  | Ring lane, orb | n 39 | n 40 |
  | Flak ring | n 18 | n 19 |
  | Spray (A 1.2, J 0.5, orb) | n 5 | n 6 |
  | Spiral arm gap | v 150, interval 7, step 0.33, 1 arm → 328 | v 70, interval 3, step 1.0, 6 arms → −1.3 |
  | Wall corridor (g 1) | s 16 → 27 | s 12 → 19 warning; s 8 → 11 error |
  | Wall speed | 110 | 206 |
  | Wall reach | 121 | 120; with `interval_full` −1 the check uses `interval` |
  | Flak | `flak_delay` 18, standoff 50 at R_safe 42 | `flak_delay` 17; standoff 49 |

- **AC-48 [Unit] (F8 overlap, lock, spawn safe):**
  - 6 × 6 with `interval` 84 passes; with 30 it is an error. Both `interval` and `interval_at_full` are checked, and −1 is skipped.
  - `lock_ticks ≥ interval` is an error, as is lock combined with re-aim.
  - A 480 px/s needle at `R_safe` 42 is an error; at 76.25 it passes. A 240 px/s orb at 42 passes.
- **AC-49 [Unit] (F8 prototype values):** the migrated data reports min fan lane 21.4; rings 12, 20 and 24 pass; spiral arm gap ≈133 (±1); corridor 27; wall speed 110; wall reach 138; spawn safe 41.5.
- **AC-50 [Unit] (F10 golden table):** the migrated resources equal the F10 table:
  - **Fortress:** `core_spiral` 7 / 3 / 30 with **arms 2**, and no separate `core_spiral_second_arm` runner; `core_rage_ring` 66 / 18, count 24; `turret_fan` 0.21 / 66; `engine_ring` 114.
  - **Jet:** `core_accel_fan` 0.165 / 78 / 33, speed 70; `pod_stream` 84 / 6; `wing_wall` count 7 / 138, spacing 16.
  - **Plasma:** `core_shielded_warp_ring` 108; `core_exposed_warp_ring` 72 / 1; `core_exposed_fan` 0.1875 / 72 / 36; `shield_curve` 10.
  - Fan counts, ring/spiral/curve geometry and all other speeds are unchanged.
- **AC-51 [Unit] (F9):**
  - Jet fan runner = 52.4 (±0.1). Jet total (gate-ignoring sum) ≈ 116 (±2). Fortress at full intensity ≈ 155 (±3).
  - A synthetic ring (24, `interval` 6, v 150) gives 512, which is a warning.
  - Runners gated [0, 0.5] (N 1,000) and [0.5, 1] (N 800) overlap at I = 0.5 for 1,800, which is an error; each alone is clean.
- **AC-52 [Unit] (Rule 16):** a lint finds no ×0.75 or other canvas scale factor in the pattern runtime.

### Performance

Reference machines are REF-PC, REF-WEB and REF-PHONE, as defined in ADR-0001 and the Bullet manager ACs. The benchmark is `tests/perf/pattern_bench.tscn`:
- 40 emitters and 120 runners covering all 7 patterns, with an intensity ramp;
- 4 moving players and a counting sink in place of the BulletField;
- 1,800 ticks after a 300-tick warm-up.

A second run feeds the real `BulletField`, holding ~1,700 active bullets.

- **AC-53 [Perf] (pattern tick):** ≤ **0.2 ms p99** per tick (mean ≤ 0.1 ms) on REF-PC and REF-WEB, spawn safety included. REF-PHONE is report-only. Budget row in ADR-0001 (added 2026-11-03; Open Question 10 closed).
- **AC-54 [Perf] (combined):** pattern tick + bullet update ≤ 1.7 ms p99 on REF-PC and REF-WEB. Peak requests per tick and `spawn_safety_skips` are reported.
- **AC-55 [Perf] (allocation):** 10 minutes of the benchmark → static memory grows < 1 MB after warm-up, object count stays stable ±5, and nothing is allocated per volley or per bullet.

### Visual and audio

- **AC-56 [Manual] (V1 muzzle flash):** frame-step a volley → a 3-frame, 6-tick puff ≤ 10 px at the muzzle, under the bullets. No flash for a fully skipped volley. Streams flash only on the burst's first volley.
- **AC-57 [Manual] (V2 lock tell):**
  - A 30-tick lock in 2P: a 2 px dashed line in the target's ring colour and pattern, plus a 10 px corner reticle with the target's pips. A screenshot at the first and last tick shows the aim point.
  - When fired, the reticle flashes for 2 ticks.
  - When not fired, the reticle breaks into 4 corners that fall and fade over 8 ticks, silently.
  - With 3 or more locks, new ones show the reticle only.
- **AC-58 [Manual] (V3 flak marker):** a 36-tick fuse → the smoke puff grows 6 → 14 px, the spark blinks every 12 ticks then every 6, solid for the last 6. On the last tick the puff opens to 24 px and the ring draws above it. No dotted circle.
- **AC-59 [Manual] (A1 audio):** a 4P stacked pattern → one volley sound per volley with ≥ 1 bullet, none for fully skipped volleys, and silence during `death_fire_hold`. The lock tone rises and clicks only when fired. The flak ticks speed up, then pop.
- **AC-60 [Manual] (grayscale):** a screenshot during a 1970s lock + 1941 flak test room, converted to grayscale → every enemy bullet is still readable over the tells. No tell is drawn above a bullet.
- **AC-61 [Manual] (co-op rotation):** 4P test room, all Alive → four consecutive aimed bursts from one emitter target slots 0, 1, 2, 3. A player who dies between bursts is skipped.

> Acceptance criteria drafted by `qa-lead`, adjusted to the gap fixes (stable-id seeds, flak timing, merged spiral arms, V/A section) under auto-approve (2026-11-03).

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Playtest `spawn_safe_radius` 42 and `lane_min_clear` 14: do hugging players exploit silent emitters, and are 14 px lanes fair at 4P density? | Designer | First playable boss |
| 2 | Confirm the F9 estimates (path 320/640 px, Warp `v_eff` 66) against the Bullet manager's profiler counters; adjust the 450 per-runner warning. | Programmer | Bullet bench (ADR-0001 V1) |
| 3 | Spiral rounding after migration (0.11 s → 7 ticks, 0.045 s → 3) makes cores 6–11% slower. Retune by feel. | Designer | Boss playtest |
| 4 | ~~Is per-emitter rotation enough in 4P, or do far players get unfair cross-screen snipes? Alternative: nearest within a range, else rotate.~~ **Closed 2026-11-03:** per-emitter rotation is kept for MVP; reopen only if a 4P playtest shows unfair snipes (Co-op (18)). | Co-op (18) | Done |
| 5 | ~~Should off-screen emitters fire? Library allows it; Enemy (10) decides per enemy type.~~ **Closed 2026-11-03:** off-screen enemy emitters do not fire; arm once on the muzzle entering the fire zone, retire once (Enemy (10) Rule 18). Boss (14) confirms bosses are exempt from this arming rule (emitters start at `boss_started`; placement lint). | Enemy (10) GDD | Done |
| 6 | 2030s pattern language (drones, lasers, shields) needs new geometry or behaviours (e.g. enemy lasers are not bullets). *(2026-11-03: tracked in era-shift-and-plane-evolution.md Open Question 4.)* | Era shift (19) | Target tier |
| 7 | "Rewinding" bullets for 2100 (concept §4) are not a BM behaviour; Warp covers MVP. A Rewind behaviour would need a BM amendment. *(2026-11-03: tracked in era-shift-and-plane-evolution.md Open Question 8.)* | Bullet manager / Era shift | Target tier |
| 8 | Art bible amendments listed under Visual/Audio (combat tells, ring colour on lock lines, alert amber, particle budget). | Art director | Before asset spec |
| 9 | ~~Code migration: existing `src/gameplay/bullets/patterns/` uses float `delta`, global `randf()`, one target and the old `Kind` enum. Rewrite to this GDD (runners, ticks, seeded streams, shape + behaviour).~~ **Closed 2026-11-04:** rewritten as `src/gameplay/patterns/` (`PatternDef`, `PatternScene`, `PatternEmitter`, `PatternRunner`, `PatternMetrics`, `PatternRules`) on integer ticks, binary angles and per-emitter seeded streams. The old `src/gameplay/bullets/patterns/` is still on disk, used only by the legacy `game.tscn` path and the boss `.tres` files, and goes when Boss (14) lands | Programmer | Done |
| 10 | ~~ADR-0001 needs a budget row for the pattern tick (≤ 0.2 ms p99; ≤ 1.7 ms with the bullet update) at GameLoop step 4.~~ **Closed 2026-11-03:** row added to ADR-0001 budget table (amendment pass) | Technical director | Done |
| 11 | **Raised by implementation 2026-11-04:** AC-53's benchmark rig (40 emitters, 120 runners of the authored patterns, all armed on one tick) sustains ~3,600 live bullets by F9's own formula — over 2× the 1,700 scene budget F9 calls an **error**, and ~1.8× the 2,000-bullet pool (the run refuses 1,533 spawns). Measured p99 is 0.527 ms against the 0.2 ms budget. The same code at F9's budget, with staggered arming, is **p99 0.115 ms (PASS)**. Restate the rig to the F9 budget, or raise the budget row for a scene the Director's V-D5 check would reject anyway. See [spike-0002-pattern-bench.md](../../docs/architecture/spike-0002-pattern-bench.md) | Technical director / Designer | Before the enemy density pass |
| 12 | **Raised by implementation 2026-11-04:** AC-49 quotes a spiral arm gap of "≈133" for the migrated data, but F10 merged the two fortress core spirals into one runner with `arms` 2, and the shipped `fortress_core_spiral` (speed 140, interval 7, step 0.33, arms 2) measures **150.5 px** by F8's formula. The test asserts the measured value. Confirm 150.5 is the intended margin (it is wider, so fairer) and correct AC-49 | Designer | Boss playtest |
| 13 | **Raised by implementation 2026-11-04:** AC-39 says a flak ring near a non-target player "skips only the ring bullets within that player's radius", but F6b spawns every ring bullet **at the ring's centre** and varies only direction — so a player standing on a burst point loses the whole ring, and one 44 px away loses none. All-or-none is what the geometry allows; the test asserts that. Either accept it (and reword AC-39) or spawn flak rings on a radius | Designer | Before the 1941 flak pass |

> Decisions in this GDD after 2026-11-03 Formulas were made by Claude under the user's auto-approve instruction (recommended options taken); all are open to user change.
