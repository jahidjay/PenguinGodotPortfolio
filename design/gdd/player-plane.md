# Player Plane (movement, hitbox, look)

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + Claude
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (honest hitbox), Four Planes, Four Games (each airframe carries its own kit)

## Overview

The Player Plane is **the thing the player flies**: one 1941 airframe per joined slot, which moves, dodges, shows exactly where it can be hit, and passes the player's button presses to its plane kit.

**What it owns:**

- **Movement** across the play field, with speed modes: full speed, slower while holding Fire for the charge mode, and the kit's own speed while its ability runs.
- **Screen bounds:** below the HUD strip (`play_top`) and inside the 360x640 field.
- **The hitbox:** one small circle (radius 3.0), drawn at its true size so what you see is what hits. It is registered with the Bullet Manager every tick (current and previous position).
- **The plane's look:** the WW2 silhouette, the co-op ring colour, pattern and pips, and its drones' positions around it.
- **Input hand-off:** it reads its slot's Fire / Drone / Bomb buttons and passes them to its **plane kit** (Lancer or Leech). The kit decides what they do.

**What it doesn't own:** chain, score, lives, bombs, Critical Break and respawn invulnerability. Those belong to their own systems and only *read* the plane's position and state.

**The player impact:** this is the player's body in the game. If it moves sluggishly, slides, or its hitbox lies, every other system feels unfair. With a crisp, honest plane, a 1,000-bullet curtain becomes a puzzle the player can actually solve.

> Implementation note (→ ADR / refactor): the current `player.gd` also holds chain, score, lives, bombs and Critical Break. Those move to their own systems when this GDD is implemented.

## Player Fantasy

**Direct: the player flies this plane every second of the run.**

The anchor moment: **the curtain closes, the player holds Fire, the plane slows to a crawl, and they ease it two pixels to the left.** The bullet passes right by the glowing core, the drones keep firing at the boss, and the chain keeps climbing. The fantasy is *a 1941 ace with absolute control of the aircraft.*

- **Crisp control.** The plane goes exactly where the stick says and **stops dead** when it's released. There is no drift, no inertia and no acceleration ramp. Every death is the player's fault because the plane never surprises them.
- **Focus is precision.** Holding Fire trades speed for accuracy. At full speed the player repositions across the screen. While focused, they thread gaps. Choosing *when* to slow down is the dodging skill.
- **The WW2 ace.** The player is a pilot in a 1941 airframe (Lancer, Leech), and the silhouette stays recognisable even when it's covered in 2100 plasma tech. The era changes around them, but the pilot doesn't.
- **A growing escort.** Each powerup adds one more drone at the wing, up to four. The plane visibly gains strength as the stage goes on, and **losing all of them on death stings.** That gives the player a reason to survive beyond lives (Every Hit Counts: drones keep the chain alive).

It serves **Readable Chaos** (*"every death is the player's fault"*): the hitbox the player sees is the hitbox that gets hit. It also serves **Four Planes, Four Games**: the airframe carries a kit that changes *how* the player chains.

> `creative-director` not consulted for this section (lean mode).

## Detailed Design

### Core Rules

**Movement**

1. The plane moves on the fixed 60 Hz gameplay tick, never on the variable frame time.
2. **Digital 8-way:** past the deadzone, the stick or d-pad gives one of 8 directions at **full speed for the current mode**. Diagonals are normalised, so diagonal speed equals straight speed. Stick pressure never changes speed. *(2026-11-03, wave 4, Touch controls (31):)* touch DRAG is an analog direction, capped by the same speed as 8-way (PF8).
3. **No inertia:** speed is instant on press and zero on release. There's no acceleration or drift.
4. **Speed modes**, checked in priority order:
   1. **Kit ability active** (e.g. Lancer laser): the kit's speed (Lancer `ability_speed` 90 px/s; Leech has none, Plane kits (11) Rule 22; Sentry Entrench 75 px/s, Breaker none — Sentry/Breaker (29), 2026-11-03).
   2. **Fire held** (charge mode, e.g. Leech focused shot): `focus_speed`. *(Amended 2026-11-03, Plane kits (11):)* "held" means Fire is physically down, including during a tap; `focus_speed` does not apply during the kit's 12-tick tap linger after release. A touch auto-fire pulse (`fire_auto` true) is **not** a Fire hold (Touch controls (31), 2026-11-03).
   3. Otherwise `move_speed`.

   The kit tells the plane which mode is active; the plane applies the speed.
5. **Bounds:** the plane's **whole sprite** stays inside the field: left and right edges of 360, the bottom of 640, and the top at `play_top` (48 px in 1–2P, 72 px in 3–4P). It stops at a bound and never wraps. `play_top` is the **latched** value (Co-op Rule 2, 2026-11-03 wave 4): it changes only at `stage_started` and `wave_started` (during a boss fight, not until the next stage). When the latched value moves down, a plane above the new line is pushed down to it on the next tick. Gameplay never reads the HUD display mode.

**Hitbox**

6. The hitbox is a circle of radius **3.0** (registry `player_hitbox_radius`) at the plane's centre, drawn at its true 6 px size in white with the player's ring colour.
7. Every tick the plane **registers** with the Bullet Manager: slot, current position, previous position, radius and **hittable**. Hittable is true only when the plane is *Active* and Collision (6) says it isn't invulnerable. **The tick FlyIn ends registers `hittable = false` with previous = current;** hits start the next tick. **An Absent plane registers nothing.**
8. The plane never decides what a hit does. Bullet hits go to Collision (6), which handles lives and invulnerability and tells the plane to enter *Dying*. A lethal hit while not Active (FlyIn, Dying, Absent) is ignored.

**Input hand-off**

9. The plane reads its slot's **`SlotInput` snapshot** from Input (2) each tick: move, **Fire**, **Drone**, **Bomb** (Input Rule 13; `pN_drone` is the final name, `pN_ability` is gone). Each tick it passes the buttons' states to its kit: pressed this tick, held, released, and `held_ticks` (integer ticks from Input's `SlotInput`, Input F1; 30 ticks = 0.5 s). *(Amended 2026-11-03: was `held_time` in seconds.)* The **kit** decides what tap, hold and press mean; it counts its own held ticks from `pressed` (Plane kits (11) Rule 4: 18 ticks = charge mode). **Bomb** goes to Bombs (12), which reads the plane's position and Active state at the accept tick (Bombs Rule 4). *(Amended 2026-11-03.)* With TOUCH bound the plane also reads `drag` / `drag_active` (PF8, Touch controls (31)).
10. Input is ignored while the plane is not *Active* (fly-in, dying, absent); the plane calls `clear_buffer(slot)` every non-Active tick (Input Rule 18). A button held through that time starts on the first Active tick as `pressed = false`, `held = true`, `held_ticks = 0`; a held Fire gives `focus_speed` at once. The touch leash `pending` (PF8) is cleared on every non-Active tick.

**Drones (formation only)**

11. The plane provides **4 fixed wing slots** relative to its centre: slot 1 inner-left, 2 inner-right, 3 outer-left, 4 outer-right. Idle drones (0–4, from session `drone_count`) fill slots in order and **move rigidly with the plane** (no lag).
12. When the kit deploys drones (Lancer parks them, Leech latches them), they **leave the formation** and the kit controls them. When they return, they fly back to their slot. The plane only owns the slot positions.
13. On death, every drone (idle and deployed) is removed, because session sets `drone_count = 0`.

**Co-op**

14. Planes **pass through each other**: no plane-to-plane collision or pushing.
15. Each slot's plane carries its co-op identity: ring colour, ring pattern and pip count (art bible §4.4). Each slot has a fixed **start spot** at the bottom of the screen, spread evenly by player count (`N`, defined in Co-op (18) Rule 1).

### States and Transitions

| State | Meaning | Hittable | Input | → Next |
|---|---|---|---|---|
| Absent | Slot Empty, Selecting, Dead-waiting, Continue or Inactive; no plane on screen | no | no | FlyIn (session: slot becomes Alive) |
| FlyIn | Enters from below the screen to its start spot over `flyin_time` | no | no | Active (arrived) |
| Active | Flying | yes, unless Collision says invulnerable | yes | Dying (Collision reports a lethal hit) |
| Dying | Death effect plays; drones removed | no | no | Absent (after `death_time`; session handles respawn and continue) |

Stage start uses FlyIn for every Alive slot. Drop-in plane pick happens while Absent (session Selecting; no plane yet).

### Interactions with Other Systems

| System | Gives to the plane | Gets from the plane |
|---|---|---|
| Game events and session (1) | Slot state, plane choice, `drone_count`, `play_top` (from player count) | — |
| Input (2) | Per-slot `SlotInput` snapshot (move, Fire, Drone, Bomb); deadzone values stored in `data/input/input_rules.tres` | `clear_buffer(slot)` every non-Active tick; `consume` |
| Bullet manager (3) | — | Per-tick hitbox: slot, position, previous position, radius 3.0, hittable |
| Collision, damage and lives (6) | Invulnerable flag; "lethal hit → Dying" | Position, state |
| Plane kits and drones (11) | Which speed mode is active; deployed-drone control | Button states; position; drone wing-slot positions |
| Bombs (12) — GDD | Bomb invulnerability (via Collision; it blinks, V7) | Bomb press; plane position and Active state read at the accept tick |
| Powerups and drops (13) — GDD | — | Position; pickup when `d <= pickup_radius + r_item`, `pickup_radius` = 14 px from the plane centre (owned by Powerups F6); Active planes only |
| Co-op (18), HUD (20) | — | Position, state, slot identity |
| Wave and stage director (16) | `stage_cleared` (Dying ends at once → Absent) | — |
| Plane kits and drones (11) — signal | — | `plane_died(slot)` once on entering Dying, so the kit removes deployed drones and resets its cooldown; `stage_cleared` forwarded to the kit (drones snap home, cooldown 0, laser off; added 2026-11-03) |

All listed systems now have GDDs *(2026-11-03, wave 3b)*; the contracts above match them. VFX (25) reads the plane position on the death tick: `get_position(slot)` stays valid on the tick `plane_died(slot)` / the session's death event fires (death ring, VFX amendment 12).

> Specialist agents not consulted for this section (lean mode).

## Formulas

Assumptions: canvas 360x640, `dt = 1/60` s, y grows downward. Sprite sizes from art bible §3.1: Lancer 48×39, Leech 39×45. The hitbox sits at the sprite centre (Rule 6). Position is stored as float; only the draw position is snapped to whole pixels.

**Decided speeds (2026-11-02):** `move_speed = 210` px/s (3.5 px/tick), `focus_speed = 105` px/s (1.75 px/tick). That is 0.75 × the prototype's 280, matching the narrower canvas (patterns migrated in Pattern library F10), so crossing 360 px takes **1.71 s** — the same as 480 px at 280 on the old canvas. Focus ratio 0.50 (Touhou 4.0/2.0 px per tick; DoDonPachi ~0.4–0.5 under laser). Kit ability speed is owned by Plane kits (11); recommended 90 px/s, range 60–120, never above `move_speed`.

**PF1. Movement step**

`v = ability_speed if ability_active; else focus_speed if fire_held; else move_speed`
`step = d × v × dt`; `pos_raw = pos_prev + step` (then PF3 clamps)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Direction | `d` | Vector2 | 9 exact values (PF2) | Already normalised |
| Move speed | `move_speed` | float px/s | 150–240 (default 210) | Neither Fire nor ability active |
| Focus speed | `focus_speed` | float px/s | 60–140 (default 105) | Fire held, no ability |
| Ability speed | `ability_speed` | float px/s | 60–120 (recommended 90) | Supplied by the kit |
| Step | `step` | Vector2 px | length 0–3.5 | Displacement this tick |

**Output Range:** `|step|` is 0 when idle, otherwise exactly `v × dt`; never more than 3.5 px/tick (kit speed ≤ `move_speed`).
**Example:** Fire held, up-right: `step = 1.75 × (0.7071, −0.7071) = (1.237, −1.237)`. Unfocused right: `(3.5, 0)`. Lancer crosses its reachable width (312 px) in 1.49 s.

**PF2. Deadzone and 8-way direction**

*(2026-11-03, ADR-0003)* PF2 is evaluated **in Input** (device side, before the replay boundary); Input's sim byte carries `move` 0–8 (`k`, or neutral). The plane reads `DIR[k]` only; `atan2` here never runs in the simulation. Formula and ACs unchanged.

`m = |s|`; `active = m ≥ dz_enter` if idle last tick, else `m ≥ dz_exit`
`θ = atan2(s.y, s.x)` (degrees, y down); `k = round(θ / 45°) mod 8`, keeping the previous `k` while `|wrap180(θ − 45°·k_prev)| ≤ 22.5° + sector_hyst` (the remembered `k_prev` is cleared whenever the stick goes idle)
`d = DIR[k]` if active, else `(0, 0)`
`DIR = [(1,0), (0.7071,0.7071), (0,1), (−0.7071,0.7071), (−1,0), (−0.7071,−0.7071), (0,−1), (0.7071,−0.7071)]` (lookup, no float drift)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Raw stick | `s` | Vector2 | each axis −1..1 | Keyboard / d-pad skip the deadzone: `d` = normalised digital `(x, y)` |
| Enter / exit deadzone | `dz_enter`, `dz_exit` | float | 0.15–0.50 (0.30) / 0.10–`dz_enter` (0.20) | Radial; the gap stops flicker |
| Sector hysteresis | `sector_hyst` | float deg | 0–8 (default 4) | Stops flipping on a sector edge |

**Output Range:** `d` is always one of 9 exact values. Opposite digital inputs (left+right) cancel on that axis.
**Example:** `s = (0.6, −0.5)`: `m = 0.781`, `θ = −39.8°`, `k = 7` → up-right. `s = (0.2, 0.1)` while idle: `m = 0.224 < 0.30` → no movement.

**PF3. Bounds clamp**

`hx, hy = sprite_W / 2, sprite_H / 2` (base envelope, not the animation frame)
`pos = (clamp(pos_raw.x, hx, W − hx), clamp(pos_raw.y, play_top + hy, H − hy))`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Canvas | `W`, `H` | int px | 360, 640 | |
| Play top | `play_top` | int px | 48 (1–2P), 72 (3–4P) | Registry |
| Half-extents | `hx`, `hy` | float px | Lancer 24 / 19.5; Leech 19.5 / 22.5 | Art bible §3.1 |

**Output Range** (hitbox centre):

| Plane | x | y (1–2P) | y (3–4P) |
|---|---|---|---|
| Lancer | 24–336 | 67.5–620.5 | 91.5–620.5 |
| Leech | 19.5–340.5 | 70.5–617.5 | 94.5–617.5 |

A plane pushing into a wall stops on that axis and slides along the other; no bounce or wrap.
**Example:** Lancer 1P at `(10, 60)` → `(24, 67.5)`. Leech 4P at `(350, 700)` → `(340.5, 617.5)`.

**PF4. Wing slot offsets (idle drones)**

`slot_pos[i] = plane_pos + (sx_i × ox_i, oy_i)`; `ox_inner = ceil(hx + g_p + s / 2)`; `ox_outer = ox_inner + s + g_d`; `oy_inner = 4`, `oy_outer = 10`. Slots: 1 inner-left, 2 inner-right, 3 outer-left, 4 outer-right.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Drone box | `s` | float px | 10–16 (default 12) | Largest idle drone box |
| Plane gap | `g_p` | float px | 1–4 (default 2) | Sprite edge to drone edge |
| Drone gap | `g_d` | float px | 1–4 (default 2) | Inner to outer drone |
| Rows | `oy_inner`, `oy_outer` | float px | 0–12 (4 / 10) | Small rear stagger (a V) |

| Plane | Slot 1 | Slot 2 | Slot 3 | Slot 4 |
|---|---|---|---|---|
| Lancer | (−32, +4) | (+32, +4) | (−46, +10) | (+46, +10) |
| Leech | (−28, +4) | (+28, +4) | (−42, +10) | (+42, +10) |

**Output Range:** fixed and rigid; drones never overlap the plane sprite or each other, and stay within the plane's own height band. **Drones are not clamped to the screen (decided 2026-11-02):** at a wall the outer drones go off-screen and only cost firepower; the whole width stays playable.
**Example:** Lancer at `(180, 500)` with 3 drones → `(148, 504)`, `(212, 504)`, `(134, 510)`. Lancer at the left wall `(24, 500)` → slot 1 at x = −8, slot 3 at x = −22 (off-screen).

*(2026-11-03, wave 4, Sentry/Breaker (29), Target; computed by PF4; re-checked 2026-11-03 (Sentry `ceil(22.5 + 2 + 6)` = 31, 31 + 12 + 2 = 45; Breaker `ceil(21 + 2 + 8)` = 31, 31 + 16 + 2 = 49), (decided under auto-approve 2026-11-03, consistency check):)* Sentry (45x42 box, `s` 12): slots (∓31, +4), (∓45, +10). Breaker (42x45 box, `s` 16 for the 16x10 eraser): slots (∓31, +4), (∓49, +10).

**PF5. Start spots**

`start_x(r, N) = W × (2r + 1) / (2N)`, `start_y = 560`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Occupied slots | `N` | int | 1–4 | Slots Alive, Dead or Continue (same count that drives `play_top`); defined in Co-op (18) Rule 1 |
| Rank | `r` | int | 0..N−1 | Order among occupied slots, by slot index, left to right |
| Start Y | `start_y` | int px | 520–600 (default 560) | |

**Output Range (decided: column centres):** N=1: 180 · N=2: 90, 270 · N=3: 60, 180, 300 · N=4: 45, 135, 225, 315. All inside PF3; 4P spacing (90 px) matches the HUD's four columns.
**Example:** N=3, rank 1 → `(180, 560)`.

**PF6. FlyIn and Dying timing**

`y(u) = start_y + (enter_y − start_y) × (1 − u)²`, `u = tick / flyin_ticks`, x fixed at `start_x`; `flyin_ticks = round(flyin_time × 60)`
`death_time = min(death_time_default, respawn_delay − death_gap_min)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Enter Y | `enter_y` | int px | 664 (`H + 24`) | Fully below the screen |
| FlyIn time | `flyin_time` | float s | 0.4–1.0 (default 0.6 = 36 ticks) | |
| Death time | `death_time_default` | float s | 0.3–0.8 (default 0.6) | Dying duration |
| Respawn delay | `respawn_delay` | float s | 0.5–2.0 (default 1.0) | Registry / session F5 |
| Empty gap | `death_gap_min` | float s | 0.1–0.4 (default 0.2) | Plane-free beat before respawn |

**Output Range:** ease-out ending at zero speed exactly at `start_y`; peak 347 px/s at the very start of the fly-in only. Dying always ends before the slot becomes Alive.
**Example (defaults), from the lethal hit:** 0.0–0.6 s Dying → 0.6–1.0 s Absent (clear screen) → 1.0 s slot Alive, FlyIn starts (matches session AC-09) → 1.3 s at y = 586 → 1.6 s Active. Control is lost for 1.6 s in total. With `respawn_delay` 0.5, `death_time = 0.3`.

**PF7. Previous position for the swept test**

`registered_prev(T+1) = pos(T)` if the plane was Active on both ticks and no teleport happened; otherwise `registered_prev(T+1) = pos(T+1)` (zero-length segment). `registered_cur(T+1) = pos(T+1)` after PF1 and PF3.
**Teleports:** FlyIn start, FlyIn → Active (that tick registers `hittable = false`), stage start, and a `play_top` push-down. A bounds clamp only shortens the segment and is not a teleport.

**Output Range:** segment length 0–3.5 px.
**Example:** pushing into the left wall: `prev (24, 300) → cur (24, 300)`, length 0. Respawn from `(100, 500)` to `(100, 600)` sets `prev = (100, 600)` (Bullet Manager AC-22). The first Active tick after FlyIn is unhittable at its start, so hits resume the tick after (Bullet Manager AC-21).

**PF8. Touch leash** *(added 2026-11-03, wave 4; Touch controls (31) TF4)*

With TOUCH bound (slot 0, solo only), the plane keeps a fixed-point `pending` motion (Vector2i, 1/16 px) and moves by the touch `drag` instead of the 8-way step:

`pending' = clamp_len(pending + drag, leash_px × 16)`; `step = clamp_len(pending', v × 16 / 60)`; `pending = pending' − step`; `pos += step / 16`, then PF3; each axis the clamp changed sets `pending.axis = 0`.

`v` is the PF1 speed mode (210 / 105 / ability). `leash_px` 12 (Touch knob). **Output Range:** `|step|` ≤ 56 units (3.5 px) at `move_speed`; `|pending|` ≤ 192 after every tick; the plane stops within 4 ticks at 210 px/s after the thumb stops. `pending` is cleared on every non-Active tick (Rule 10). A PF3 clamp is not a teleport (PF7 unchanged). Tests: Touch controls AC-21 to AC-27.

> Formulas proposed by `systems-designer`; user decisions (2026-11-02): 210 / 105 px/s, drones may go off-screen at walls, column-centre start spots.

## Edge Cases

**Input**

- **If left and right (or up and down) are pressed together**, they cancel on that axis (up+left+right moves straight up).
- **If a stick drifts slightly below the deadzone**, the plane doesn't move. Starting needs 0.30; stopping needs only a drop below 0.20 (PF2).
- **If a pad disconnects mid-flight**, the game pauses before the next tick's simulation, so no tick runs with the plane unattended (Input (2) Rule 28). *(Amended 2026-11-03.)*
- **If Fire, Drone and Bomb are pressed on the same tick**, all three are passed on; the kit and Bombs (12) decide their order. The plane only reports them.
- **If a button is held through a respawn**, it is ignored until the plane is Active. A Fire held from before the death doesn't count as held time; the hold timer starts at the first Active tick.

**Movement and bounds**

- **If the plane pushes into a wall or corner**, it stops on that axis and slides along the other; in a corner it stays put and the swept test sees a zero-length path (PF7).
- **If `play_top` moves down** (a 3rd player joined; the latched value changes at the next `stage_started` / `wave_started`, never mid-wave or mid-boss), any plane above the new line is pushed down on the next tick. This is a teleport for the swept test, so no hit is swept across the jump.
- **If an era bolt-on** (art bible §5.5) makes the sprite up to 6 px wider than its base, the bounds still use the base size. The bolt-on may poke into the HUD strip or past the wall edge (visual only).
- **If the kit asks for a speed above `move_speed`**, it is capped at `move_speed` (keeps the swept test's 3.5 px/tick bound).

**Hitbox**

- **If the drawn hitbox is snapped to whole pixels**, it can be up to 0.5 px off the true position. Hits always use the true float position.
- **If a bullet already overlaps the plane on its first Active tick after FlyIn**, there's no hit that tick (not hittable at the start). If it still overlaps on the next tick, the hit counts.

**Drones**

- **If the plane is at a wall with 3–4 drones**, the outer drones go off-screen and fire from there. Their bullets behave normally and the Bullet Manager culls them by its own rules.
- **If drones are deployed when the plane dies**, they're removed with the others (Rule 13). The kit resets its cooldown (Plane kits 11).
- **If `drone_count` increases while drones are deployed**, the new drone takes the next free wing slot at once; deployed drones return to their own slots later.

**Death, respawn and co-op**

- **If a plane dies on the same tick the boss dies**, Dying is cut short at stage clear and the plane flies in at the next stage start.
- **If two or more planes respawn at once**, each flies in to its own start spot. Planes pass through each other, so overlapping fly-ins are fine.
- **If a player drops in mid-stage**, their plane flies in to the start spot for the new player count. Existing planes don't move, apart from a `play_top` push-down at the next latch (`wave_started` or `stage_started`).
- **If the player count drops** (a slot goes Inactive), later respawns use the new count's start spots, and `play_top` may move up at the next latch. Planes are never pulled up.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Slot state (Absent ↔ FlyIn on Alive), plane choice, `drone_count`, player count → `play_top` (latched at `stage_started` / `wave_started`, Co-op Rule 2), `respawn_delay` |
| Touch controls (31) — [GDD](touch-controls.md) | Soft (Target) | `SlotInput.drag` (Vector2i, 1/16 px), `drag_active`, `fire_auto` for slot 0 when TOUCH is bound; PF8 leash. *(2026-11-03, wave 4)* |
| Input and player mapping (2) — GDD | Hard | `SlotInput` snapshot per slot each tick (move, Fire, Drone, Bomb); deadzone values from `data/input/input_rules.tres`; `clear_buffer`, `consume`. `pN_drone` is final. |
| Bullet manager (3) — GDD | Hard | This plane registers its hitbox every tick (slot, position, previous position per PF7, radius 3.0, hittable). |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Collision, damage and lives (6) | Hard | Reads position and state; supplies the invulnerable flag; sends "lethal hit → Dying". Invulnerability should start at **Active**, not at death (FlyIn is already unhittable). |
| Bullet pattern library (9) | Hard | Reads hitbox centre and state for aiming (Active or FlyIn when Alive) and spawn safety (Active only). |
| Plane kits and drones (11) | Hard | Gets button states, position, wing-slot positions; supplies the active speed mode (ability speed 60–120, never above 210) and controls deployed drones. |
| Bombs (12) — GDD | Hard | Bomb press; plane position and Active state at the accept tick; bomb invulnerability blinks (V7). |
| Powerups and drops (13) — GDD | Hard | Plane position for pickups; `pickup_radius` 14 px from the plane centre (owned by Powerups). |
| Co-op and Team Chain (18) — GDD | Hard | Position, state, slot identity; owns `N` (Co-op Rule 1, used by PF5); Active transitions trigger the join grace. |
| HUD (20) | Soft | Slot identity (ring colour, pattern, pips). [GDD](hud.md) |
| VFX (25), Audio (24) | Soft | Dying and FlyIn moments; plane position valid on the death tick. [VFX](vfx-and-screen-feedback.md), [Audio](audio.md) |
| Era shift (19) | Soft | Bolt-on and palette LUT selected by `era_index` at `era_swap_committed` (V8). [GDD](era-shift-and-plane-evolution.md) |
| Accessibility options (28) | Soft | `access.reduce_flashing` (blink replacement), `access.hitbox_ring_size` / `access.hitbox_ring_opacity`, `access.player_palette`. [GDD](accessibility-options.md) |
| Sentry, Breaker kits (29) | Hard (Target) | Same contract as Plane kits (11): Sentry Entrench `ability_speed` 75 px/s; wing slots per PF4; V6 drone sprites. [GDD](plane-kits-sentry-breaker.md) |
| Tutorial (30) | Soft | Move and hitbox drills read position and state only. [GDD](tutorial.md) |

**Bidirectional check:** Game events and session and Bullet manager already list this system. The undesigned downstream systems must list it when written. *(2026-11-03, wave 3b: all downstream systems except Sentry/Breaker kits (29), Tutorial (30) and Touch (31) now have GDDs.)*

## Tuning Knobs

Stored per plane in `data/planes/*.tres` (`PlaneConfig`), except the shared input values.

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `move_speed` | 210 px/s | 150–240 | Repositioning, crossing time | Can't escape patterns; sluggish | Crossing < 1.3 s; placement imprecise; patterns easy |
| `focus_speed` | 105 px/s | 60–140 (ratio 0.35–0.65) | Precision dodging | Below ~1 px/tick feels stuck | Focus stops meaning precision |
| `dz_enter` / `dz_exit` | 0.30 / 0.20 | 0.15–0.50 / 0.10–`dz_enter` | Stick feel | Drift moves the plane | Dead stick, slow start |
| `sector_hyst` | 4° | 0–8° | Diagonal stability | Direction flickers | Diagonals hard to hit |
| Drone gaps `g_p`, `g_d`, box `s`, rows | 2, 2, 12, 4/10 px | 1–4, 1–4, 10–16, 0–12 | Formation width | Drones overlap sprite | Too wide; more firepower lost at walls |
| `start_y` | 560 | 520–600 | Where planes enter | — | Too low: no fly-in room |
| `flyin_time` | 0.6 s | 0.4–1.0 | Respawn rhythm | Jarring pop-in | Control lost too long |
| `death_time_default` | 0.6 s | 0.3–0.8 | Death readability | Effect unreadable | Clamped by PF6 |
| `death_gap_min` | 0.2 s | 0.1–0.4 | Clear-screen beat | No breathing room | Dying too short |

**Locked, not knobs:** `player_hitbox_radius` 3.0 (registry; 2.0–2.5 is a playtest option, Open Questions) and `play_top` 48 / 72 (art bible §7.2).

**Owned elsewhere:** ability speed (60–120, never above `move_speed`) — Plane kits (11); respawn invulnerability — Collision (6); `respawn_delay` — session.

**Interactions:** raising `move_speed` above 210 changes the Bullet Manager's F7 example caps and the PF7 segment bound — re-check them. `death_time` depends on `respawn_delay` (PF6).

## Visual/Audio Requirements

> Source of truth: `design/art/art-bible.md` (AB). This section only adds Player Plane rules and stays consistent with Bullet Manager V1–V8 and A1–A2. Audio items are proposals for the **audio-director**. Numbers marked (P) are unplaytested.

**V1. Plane sprites** (AB §3.1, §5.1–5.4, §8.3)

- Lancer 48×39, Leech 39×45; cell ≤ 50×50; one LOD judged at 1x. The sprite pivot is the hitbox centre (AB §8.7); pivots and hitboxes live in `PlaneConfig`, never in the PNG.
- Silhouette anchors (must pass the grayscale and solid-black test): **Lancer** — flat wide "T" with a humped canopy and a spear-thin forward spine. **Leech** — inverted-gull "W" wing with a fat cowled head.
- 5–6 px pilot head, light from top-left, 2–3 value steps, 1 px P-colour outline (never Ink); interior is the lightest value on screen (AB §5.2).
- Planes always draw at **100% opacity** in every player count. Idle propeller/engine blur: 2–3 frames at 12 fps.

**V2. Banking (decided 2026-11-02: stepped frames)**

- Movement is instant, so banking is purely visual; vertical movement has no frames.
- Bank level −2..+2 (neutral, half, full) steps one level toward the held horizontal direction every 5 ticks (12 fps) — frame swaps, not a tween. Full bank in 10 ticks; back to neutral in 10; a reversal passes through neutral (≤ 20 ticks).
- 3 frames per side, mirrored. A bank narrows the sprite 3–4 px and never grows past the base envelope. Hitbox, drone slots and bounds ignore the bank frame (PF3, PF4).

**V3. Focus cue** (Fire held; nothing near bullets)

- The propeller/engine idle drops to half rate (6 fps) with a slow-blade frame set. That is the only cue on the plane; the ring and dot never change with focus. No glow, aura or trail.
- The Lancer laser engine glow (AB §7.1) and the Leech focused-shot look belong to Plane kits (11).

**V4. Hitbox and ring** (layer 9; decided 2026-11-02: true 6 px size, amends AB §4.4)

- **Dot:** 6 px (radius 3.0) — 4 px white `#FFFFFF` core with a 1 px P-colour edge, no Ink outline (so it can't read as an enemy orb core). Drawn at the integer-snapped position (AC-12).
- **Ring:** 1 px P-colour, 22 px outer diameter, concentric. P1 solid; P2 dashed (4 on / 3 off); P3 dotted (1 on / 2 off); P4 double (22 and 24 px). Deliberately outside the 14–18 px enemy ring size and without Ink, so it can't be confused with a threat.
- The dot and ring are **never** faded, dimmed or hidden by blink, player-count opacity or era. Only the accessibility ring options may change them: `access.hitbox_ring_size` NORMAL 22 px / LARGE 30 px (P4 inner/outer 30/32) and `access.hitbox_ring_opacity` 40/60/80/100 % (Accessibility 28 F7) *(2026-11-03, wave 3b)*.
- **Pips:** 2×2 px P-colour squares on a 3 px pitch on the plane's tail, layer 7 (never over bullets); offset per plane in `PlaneConfig`.
- By state: Absent and Dying — no dot or ring. FlyIn — ring only. Active — ring and dot, including while invulnerable.

**V5. Co-op identity** (AB §4.4, §4.8, §7.1)

- Colour, pattern and pips per slot never change across death and respawn (AC-28). P3 and P4 have equal luma, so pattern and pips are mandatory.
- A P-colour pip tag shows over the plane for 2 s after FlyIn ends (layer 11) — the only plane-attached UI.

**V6. Drones** (AB §5.6; positions from PF4)

- Idle drones sit rigidly on their wing slots (no lag, no sway, no bank frame). Light warm interior, 1 px P-colour outline, 2 frames at 10 fps, layer 6.
- **Opacity (decided 2026-11-02):** drones stay at **100%** in every player count, like planes; only shots dim (Bullet Manager V3).
- **Lancer drone:** "lens-pod" — 8×12 vertical capsule with a short forward lance stub and a Gold-cream lens pixel at the tip.
- **Leech drone:** 10×10 hook-claw with a visible notch (never a plain disc).
- **Sentry drone (Target, 29):** 12×12 turret with a barrel stub; a base plate when emplaced (Sentry/Breaker V1).
- **Breaker drone (Target, 29):** 16×10 eraser wedge, forward-pointing (Sentry/Breaker V2).
- Off-screen outer drones at walls need no special rendering.
- Removal: 3-frame pop with 2–4 px debris; on death they go with the plane, never with a flash.

**V7. FlyIn, Dying, invulnerability** (AB §1 flash rule, §5.10, §6.8)

- **FlyIn** (0.6 s, ease-out): enters at 100% opacity with a small warm exhaust puff (layer 5). No blink, no flash. The dot appears on the first Active tick (AC-15).
- **Dying** (0.6 s): the sprite becomes a 4–6 frame era-tinted explosion with debris and smoke on layer 5, below bullets. **Death ring (required, Collision V1):** a 2 px ring in the player's colour and pattern, 40 → 80 px over 18 ticks, fades by tick 24, no Ink outline. **No screen flash or tint.** The HUD swaps the pilot portrait to "hurt" (AB §5.9).
- **Invulnerability blink (decided 2026-11-02: keep AB §5.10):** the plane sprite and its idle drones blink at **10 fps, fully hidden on the off frames**, starting at Active (timer owned by Collision 6). *(Amended 2026-11-03, Plane kits (11) / Bombs (12):)* the plane blinks **only while Collision's `blink_remaining(slot) > 0`** (the longest non-laser invulnerability request: respawn or bomb). Bomb invulnerability blinks; the Lancer laser's invulnerability **never** blinks (its cue is the beam, the nose-lens glow and a 12-tick afterglow, Plane kits visual rules). The hitbox **dot, ring and pips never blink** — the player's position is always visible.
- **Reduce flashing** *(2026-11-03, wave 3b)*: with `access.reduce_flashing` true the 10 fps hide blink is replaced by a steady **65 % opacity** for the same duration (Accessibility 28). The dot, ring and pips are unaffected.
- No hit tint on player planes (a hit means Dying).

**V8. Era bolt-ons** (AB §5.5)

- Separate sprites on layer 7 with a palette layer; the base airframe never changes. At most 2 bolt-on sprites per plane per era, each within the base envelope + ~6 px and never within 8 px of the hitbox centre. Single-frame; they follow the bank with a ±1 px data offset.
- Lancer: 1941 fixed cannons and spine · 1970s wing pylon tanks · 2030s spine-tip lens emitter · 2100 free-floating lance tip (2–3 px gap, ±1 px bob at 1 Hz).
- Leech: 1941 bent-wing claws · 1970s hook pylons under the kink · 2030s grapple clamps · 2100 tendril latch arms.
- *(2026-11-03, wave 3b)* Bolt-ons and the palette LUT are selected by `era_index` at `era_swap_committed`; the data home is `EraDef.bolt_ons` (Era shift 19). The 1941 hardware listed above is part of the **base art**; the first bolt-on set is 1970s (Era shift Rule 7). Evolution is visual only: no kit or bomb number changes by era.
- Bounds use the base envelope (PF3); a bolt-on may poke into the HUD strip or past a wall (visual only). One palette material per era per atlas (AB §8.6).

**A1. Audio** (audio-director to confirm (P))

- **Engine loop:** none (it would compete with the 8-voice bullet SFX pool; focus is a visual cue). If one is wanted: very quiet, one global voice, never per slot.
- **Death:** one short heavy boom per plane on entering Dying; highest priority (P0), in Audio's CRIT pool (max 2), outside the bullet pool; two simultaneous deaths play both.
- **FlyIn:** a soft rising whoosh once per FlyIn, lowest priority, first dropped; at stage start all slots merge to one voice.
- **Focus toggle, blink:** no sound.
- **Drones:** a short pop on gain and on removal; Dying plays one merged "drones lost" cue.
- **Voice caps** *(2026-11-03, wave 3b)*: PLANE pool 3 for FlyIn and drone pops. The death boom is in the CRIT pool (max 2) (Audio 24).

> Drafted by `art-director` from the art bible; user decisions (2026-11-02): keep the 10 fps hide blink (dot/ring/pips never blink), drones stay at 100% opacity, stepped banking.

📌 **Asset Spec** — run `/asset-spec system:player-plane` to produce per-sprite specs (planes, bank frames, drones, bolt-ons, hitbox ring set).

## UI Requirements

The plane owns one small piece of UI: the 2 s P-colour **pip tag** over the plane after FlyIn (V5, layer 11). Everything else the player reads about their plane (lives, drones count, kit meter, pilot portrait) is drawn by the HUD (20) from session and kit data. Debug-only: a position/state readout and the hit-circle overlay (AC-33, AC-35).

📌 **UX Flag — Player Plane:** the pip tag and the HUD's per-slot plane panel need a `/ux-design` spec in Pre-Production (HUD spec).

## Acceptance Criteria

Defaults used: canvas 360x640, tick 1/60 s, `move_speed` 210 (3.5 px/tick), `focus_speed` 105 (1.75 px/tick), test ability speed 90 (1.5 px/tick), `dz_enter` 0.30, `dz_exit` 0.20, `sector_hyst` 4°, hitbox radius 3.0, `play_top` 48 (1–2P) / 72 (3–4P), `start_y` 560, `enter_y` 664, `flyin_time` 0.6 s (36 ticks), `death_time_default` 0.6 s (36 ticks), `death_gap_min` 0.2 s, `respawn_delay` 1.0 s (60 ticks). Half-extents: Lancer 24 / 19.5, Leech 19.5 / 22.5. Slots 0-indexed. Tests read every number from `data/planes/*.tres` (`PlaneConfig`) and the registry, never literals. Position asserts ±0.01 px.

**Test setup:** movement, state and registration logic lives in a plain `RefCounted` class (working name `PlaneCore`, one per slot) with no nodes, no drawing and no `delta`; `tick()` advances one 1/60 s step. Inputs before a tick: `set_config`, `set_play_top`, `set_input(slot_input)` (a `SlotInput` snapshot: move, fire, drone, bomb, start, back), `set_ability(active, speed)`, `set_invulnerable(bool)`, `lethal_hit()`, `stage_cleared()`, `begin_flyin(start_x)`, `set_drone_count(n)`, `teleport_to(pos)` (test placement). Outputs after a tick: `state`, `pos`, `draw_pos`, `registration` (slot, pos, prev, radius, hittable — none while Absent), `kit_buttons` (pressed, held, released, `held_ticks`), `wing_slot(i)`. Stub kit and stub Bombs record what they receive. A `Node2D` adapter calls `tick()` from `_physics_process` and owns drawing; it is tested separately. Tests: `tests/unit/test_player_plane.gd`, `tests/integration/test_player_plane_bullet_field.gd`; manual evidence in `production/qa/evidence/player-plane/`.

Tags: [Unit] pure logic, headless · [Integration] real `BulletField` / scenes · [Manual] needs a human.

### Movement and speed

- **AC-01 [Unit] (Rules 1, 3, PF1):** **GIVEN** an Active Lancer at `(100, 500)` holding right, **WHEN** 1 tick runs, **THEN** `pos = (103.5, 500)`; after 30 ticks `(205, 500)`. **WHEN** released, **THEN** the next tick's step is exactly 0 and `pos` is still `(205, 500)` 10 ticks later.
- **AC-02 [Unit] (Rule 4, PF1):** at `(180, 500)`: Fire held up-right → `(181.237, 498.763)` ±0.001; no Fire right → `(183.5, 500)`; ability 90 → step 1.5; Fire held **and** ability 90 → 1.5 (ability beats Fire); Fire held, no ability → 1.75.
- **AC-03 [Unit] (PF1 knobs, kit cap):** `move_speed` 240 / 150 → step 4.0 / 2.5; `focus_speed` 60 / 140 → 1.0 / 2.333; kit ability speed 300 → step exactly 3.5 for 100 ticks; ability 60 / 120 → 1.0 / 2.0.
- **AC-04 [Unit] (Rule 2, PF2):** each of 8 digital directions → step length 3.5 ±0.001 (up-left `(−2.4749, −2.4749)`); left+right → `(0, 0)`; up+left+right → `(0, −3.5)`; all four → `(0, 0)`; stick magnitude 0.5 vs 1.0 at 0° → both `(3.5, 0)`; digital `(1, 0)` moves with no deadzone check.
- **AC-05 [Unit] (PF2 deadzone):** idle: `(0.2, 0.1)` no move, `(0.29, 0)` no move, `(0.30, 0)` moves, `(0.6, −0.5)` up-right. Moving: `(0.25, 0)` and `(0.20, 0)` keep moving, `(0.19, 0)` stops, then `(0.25, 0)` stays stopped.
- **AC-06 [Unit] (PF2 hysteresis):** moving right, 26° stays right, 27° → down-right; moving down-right, 20° stays, 18° → right; moving left at −155° stays left; idle at 26° → down-right; `sector_hyst = 0` switches at 23°. Going idle clears the remembered sector.

### Bounds

- **AC-07 [Unit] (PF3):** each plane driven into each wall for 200 ticks ends at Lancer x 24 / 336, y 67.5 (1–2P) / 91.5 (3–4P) / 620.5; Leech x 19.5 / 340.5, y 70.5 / 94.5 / 617.5. Lancer 1P at `(10, 60)` → `(24, 67.5)`; Leech 4P at `(350, 700)` → `(340.5, 617.5)`; Lancer at `(335.5, 300)` moving right → `(336, 300)`. A sprite 6 px wider (bolt-on) leaves the bounds unchanged.
- **AC-08 [Unit] (Rule 5 slide/corner):** Lancer at `(24, 300)` up-left → x 24, y 297.525; at `(24, 67.5)` up-left → unchanged and `prev == cur`; 1,000 seeded random ticks never leave the PF3 box.
- **AC-09 [Unit] (`play_top` push-down):** Lancer at `(100, 70)` in 2P, `play_top` → 72 → next tick `pos = prev = (100, 91.5)` (teleport); a plane at `(100, 200)` doesn't move; `play_top` back to 48 → plane stays at `(100, 91.5)`.

### Hitbox and registration

- **AC-10 [Unit] (Rule 7):** slot 2 registers `(2, pos, prev, 3.0, hittable)` each tick: Active → true; Active + invulnerable → false (still flying); FlyIn → false; Dying → false; Absent → **no registration**. Four planes give four distinct slots.
- **AC-11 [Unit] (PF7):** two Active ticks moving right from `(100, 500)` → `prev (100, 500) → cur (103.5, 500)`; Lancer at `(335, 300)` moving right → `(335, 300) → (336, 300)`; at `(24, 300)` pushing left → `prev = cur`. No segment exceeds 3.5 px over 600 random ticks.
- **AC-12 [Unit] (draw snapping):** `pos = (100.3, 500.7)` → `draw_pos = (100, 501)`, registered position stays `(100.3, 500.7)`.
- **AC-13 [Unit] (Rule 8):** overlapping an orb with no `lethal_hit()` → stays Active; `lethal_hit()` while Active → Dying; `lethal_hit()` while FlyIn, Dying or Absent → ignored.

### States and timing

- **AC-14 [Unit] (PF6 FlyIn, Rule 10):** `begin_flyin(180)` → `(180, 664)`; after tick 1 y = 658.30, tick 18 y = 586.00, tick 35 y = 560.08, tick 36 `(180, 560)` and Active. x stays 180; y strictly decreases with shrinking steps. Held right + Fire during FlyIn → no movement and the kit receives nothing. `flyin_time` 0.4 → 24 ticks, 1.0 → 60.
- **AC-15 [Unit] (PF7 first Active tick):** the tick FlyIn ends registers `hittable = false`, `prev = cur = (180, 560)`; the next tick registers `hittable = true` (Collision's invulnerability still applies on top).
- **AC-16 [Unit] (PF6 Dying, session AC-09):** `lethal_hit()` at 0 with `respawn_delay` 1.0 → Dying at tick 35, Absent at 36, `begin_flyin` at 60, y = 586.00 at 78, Active at 96. `respawn_delay` 0.5 → `death_time` 18 ticks; 2.0 → 36. Input ignored while Dying.
- **AC-17 [Unit] (held Fire through respawn):** Fire held across death, Dying, Absent and FlyIn → kit receives all-false states; first Active tick: `pressed = false`, `held = true`, `held_ticks = 0`, and the plane moves at `focus_speed`; 30 Active ticks later `held_ticks = 30` (exact).
- **AC-18 [Unit] (death on boss-kill tick):** `lethal_hit()` and `stage_cleared()` on the same tick → Absent (not Dying), never hittable; `stage_cleared()` at Dying tick 10 → Absent at once; next stage `begin_flyin(180)` → from `(180, 664)`, arrives after 36 ticks.

### Input hand-off

- **AC-19 [Unit] (Rule 9):** Fire pressed on tick T and held 30 ticks → `pressed` only on T, `held` 30 ticks with `held_ticks` = 30 at the 30th (Input F1, T counts as 1), `released` only on the next tick. Fire, Drone and Bomb on the same tick → kit gets Fire and Drone `pressed`, Bombs gets the press with the plane position, all that tick; no ordering applied.
- **AC-20 [Integration] (SlotInput):** `SlotInput` exposes move, fire, drone, bomb, start, back for each slot; no `ability` id exists. *(Amended 2026-11-03, Input (2).)*

### Drones

- **AC-21 [Unit] (PF4):** Lancer at `(180, 500)` with 3 drones → `(148, 504)`, `(212, 504)`, `(134, 510)`, slot 4 empty; 4 drones → slot 4 `(226, 510)`. Leech with 4 → `(152, 504)`, `(208, 504)`, `(138, 510)`, `(222, 510)`. 0 drones → no slot occupied.
- **AC-22 [Unit] (Rule 11, off-screen):** with 4 drones over 10 moving ticks, each `wing_slot(i) − pos` is constant. Lancer at `(24, 500)` → slot 1 `(−8, 504)`, slot 3 `(−22, 510)`, unclamped; plane bounds unchanged.
- **AC-23 [Unit] (new drone while deployed):** `drone_count` 1 with drone 1 deployed → becomes 2 → new drone at slot 2 `pos + (32, 4)` that tick; slot 1 stays reserved; 3 fills slot 3.
- **AC-24 [Unit] (Rule 13):** 3 drones with 1 deployed, `lethal_hit()` and session sets 0 → no slot occupied; the kit receives `plane_died` once.

### Co-op

- **AC-25 [Unit] (PF5):** start x by rank: N=1 180; N=2 90, 270; N=3 60, 180, 300; N=4 45, 135, 225, 315; y 560. Slots 0, 2, 3 occupied → slot 3 starts at 300. All spots inside both planes' PF3 box.
- **AC-26 [Unit] (Rule 14):** two planes at the same position with opposite inputs each move at full speed; neither is displaced.
- **AC-27 [Unit] (drop-in, count change):** slot 0 at `(150, 400)`, slot 1 drops in → flies to x 270, slot 0 doesn't move. Count 3 → 2, slot 0 respawns → start x 90. Two planes respawn on one tick → each to its own spot.
- **AC-28 [Unit] (Rule 15):** four slots expose distinct (ring colour, ring pattern, pip count) from art bible §4.4, unchanged across death and respawn.

### Integration with the Bullet Manager

- **AC-29 [Integration] (Rule 7):** real `BulletField`, 4 planes, 120 ticks → `set_targets` receives all four active slots every tick with position, previous, 3.0 and hittable. Plane at `(100, 500)` holding right with a static orb at `(106, 500)` → exactly 1 hit on tick 1 (the plane moves before the field's hit test).
- **AC-30 [Integration] (BM AC-21):** orb at the plane's arrival spot `(180, 560)` → no hit on the first Active tick, exactly 1 on the next. FlyIn, Dying and invulnerable ticks report none while overlapping.
- **AC-31 [Integration] (BM AC-22):** orb at `(100, 550)` between a death position `(100, 500)` and a FlyIn start or `play_top` push-down destination → registered previous equals new current, no hit. A control run keeping the old previous reports the hit.
- **AC-32 [Integration] (Rule 1, BM AC-37):** scripted run (right 30 ticks, up-left with Fire 30, lethal hit, respawn) at 60, 30 and 144 fps with a 100 ms stall on frame 100 → identical position and state after 600 ticks.

### Manual feel and look

- **AC-33 [Manual] (stops dead):** frame-stepped capture with a position readout: releasing a direction gives 0 px displacement on the next frame and over the next 10. Pass bar is the measurement; two testers also confirm it doesn't feel like sliding.
- **AC-34 [Manual] (focus precision):** orb wall with a 14 px centre-to-centre gap; after 2 minutes' practice a tester threads it with Fire held in ≥ 8 of 10 attempts (unfocused attempts recorded for comparison).
- **AC-35 [Manual] (honest hitbox):** with the debug hit-circle overlay, a 1x screenshot shows the hitbox dot 6 px wide (±0.5) centred on the overlay; an orb passing 5.4 px from a stationary plane hits, 5.6 px doesn't, and the overlay agrees.
- **AC-36 [Manual] (WW2 ace):** shuffled 1x screenshots of Lancer and Leech in every era → ≥ 5 testers name the plane correctly in ≥ 90% of shots, including 2100.
- **AC-37 [Manual] (Rule 15):** a 4P screenshot during a curtain shown for 1 s (also in greyscale) → ≥ 5 testers identify a pointed-at plane's slot from pattern and pips in ≥ 95% of trials.

### Touch and latch (added 2026-11-03, wave 4)

- **AC-38 [Unit] (PF8):** `pending (0,0)`, `drag (32, −48)` at `move_speed` → step `(31, −46)`, `pending (1, −2)`; next tick step `(1, −2)`, `pending (0, 0)` (Touch AC-23). A non-Active tick clears `pending`. A clamped axis zeroes that axis of `pending`.
- **AC-39 [Unit] (Rule 4.2):** Fire `fire_auto` pulses only → speed stays `move_speed`; a real Fire hold → `focus_speed`.
- **AC-40 [Unit] (Rule 5 latch):** a 3rd slot becomes Alive mid-wave → `play_top` stays 48 until the next `wave_started`, then 72 and push-down; mid-boss → stays 48 until the next `stage_started`.

> Criteria drafted by `qa-lead`; its testability gaps were fixed in Rules 7, 9, 13, PF2, PF7 and Interactions (2026-11-02). Manual pass bars confirmed by the user.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Hitbox radius: keep 3.0 or try 2.0–2.5 for the "2-pixel lane" fantasy (shared with Bullet Manager Open Q2) | Playtest + this GDD | First playtest |
| 2 | Art bible amendments: §4.4 hitbox dot → 6 px (4 px core + 1 px P-colour edge) and 22/24 px ring, plus §8.3 ring-sprite row and §3.6 wording; §5.6 add the Lancer lens-pod drone and make the Leech drone a notched hook-claw (no plain disc under 12 px); §5.2 "smooth bank" → "stepped"; §5.6 drones stay 100% opacity in co-op (drop the 50% rule) | art-director (`/art-bible` update) | Before plane art |
| 3 | ~~Photosensitivity: the 10 fps hide blink is kept by choice; should the "Reduce flashing" accessibility option (AB §1) also switch it to a slow 35% dim?~~ **Closed 2026-11-03:** yes; under `access.reduce_flashing` the blink becomes a steady 65 % opacity (V7) (accessibility-options.md) | Accessibility (28) | Vertical Slice |
| 4 | ~~Ability speed per kit (Lancer laser, Leech focus) — recommended 90 px/s, range 60–120~~ **Closed 2026-11-03:** Lancer `ability_speed` = 90 px/s while the laser is active; Leech has no ability speed (`focus_speed` 105 applies) (Plane kits (11) Rule 22). | Plane kits (11) GDD | Done |
| 5 | ~~Pause / reconnect when a pad disconnects mid-flight~~ **Closed 2026-11-03:** pad disconnect in Stage/Tally auto-pauses with a Reconnect / Use keyboard / Drop player / Wait overlay (Input (2) Rules 28–31). | Input (2) GDD | Done |
| 6 | ~~Touch controls (relative drag) for phones~~ **Closed 2026-11-03:** relative drag with a 12 px leash capped at the mode speed (PF8); Touch controls GDD (touch-controls.md) | Touch controls (31) + `/ux-design` | Target tier |
| 7 | ~~Respawn invulnerability length and that it starts at Active, not at death~~ **Resolved 2026-11-02:** `respawn_invuln` = 120 ticks, starting on the tick the plane becomes Active (Collision C3) | Collision (6) GDD | Closed |
