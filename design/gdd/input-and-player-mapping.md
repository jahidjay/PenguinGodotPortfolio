# Input and Player Mapping (1-4P)

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts (no lost or late inputs), Readable Chaos (every death is the player's fault, so the controls must never lie), Four Planes, Four Games (one shared 3-button grammar for every plane)
> **Revision 2026-11-09 (PC controls pass, partly implemented)**: the PC default bindings of this doc are now in code (`src/autoload/input_setup.gd`): positional pad faces with the shoulder / trigger alternates, **KB1 "Main" on slot 0 and KB2 "Left hand" on slot 1** so two players share one keyboard with no setup, `pN_back` added, and the debug keys moved to **F5-F9** (they used to collide with KB2's Bomb and Start). The **Drone / Bomb buffer (Rule 17, F6)** is implemented, on the simulation side, in `SimInput`. **Mobile on-screen buttons are deliberately deferred**: the owner's requirement, recorded 2026-11-09, is "keyboard and gamepad on PC now, the button UI for mobile users later" - the TOUCH device stays specified in [Touch controls (31)](touch-controls.md) and is not built until the PC scheme is final. See "Implementation status" below for what is still owed.
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: one `CONTINUE_ACCEPT` verb, bound to **Fire**, defined for both the in-stage HUD Continue plate and the Tally Continue prompt; Start stays Pause (Rule 24b); Accessibility-list group jump may not use a shoulder bound to Fire / Drone / Bomb (Rule 24c).

## Overview

**The data layer:** Input and Player Mapping turns raw devices (gamepads, keyboard, later touch) into one **clean input snapshot per player slot, once per 60 Hz gameplay tick**. It owns: the slot-to-device assignment (who flies with which pad or keyboard scheme), the default and remapped bindings, edge detection (pressed, held, released, held ticks) that never loses a tap between ticks, the 8-way-ready stick data the Player plane needs, a short input buffer for Drone and Bomb, the optional Tap Assist and Fire toggle, menu navigation events, the pause rules, and what happens when a pad is unplugged mid-run. It does **not** decide what a button does (the Player plane and plane kits do), and it does not do the deadzone-to-direction maths (Player plane PF2); it supplies the raw stick and the deadzone numbers.

**The player impact:** The player should never think about input. A tap that lasted 5 ms still fires. A pad that dies mid-boss pauses the game instead of killing the player. Four friends can each press Start on their own pad and be flying within seconds. A bad input system would turn every death into "the game ate my button".

> Implementation note (→ ADR amendment): the sampler is a node-free `RefCounted` class (`InputSampler`); the `InputSetup` autoload becomes its thin adapter. See Detailed Design, "Existing code".

## Player Fantasy

**Indirect: players feel that the plane is wired straight to their hands.**

The anchor moment: the curtain closes, the player taps Bomb a split second *before* the cooldown ends, and the bomb goes off the instant it can. They never think "did it register?" because it always did. In co-op, the anchor is **four pads, four Start presses, four colours on screen**, with nobody opening a menu to configure anything.

- **Honest controls.** What the hands did is what the plane did. No input is dropped, doubled or delayed by more than one tick (16.7 ms).
- **Drop-in is a handshake.** Pressing Start on a pad is the whole "join" flow (Sessions Rule 7).
- **Nothing punishes the hardware.** A dead battery or a loose cable pauses the game and asks; it never costs a life.
- **Everyone can play.** Hold-to-toggle Fire, Tap Assist, remapping and a stick deadzone choice are first-class (Accessibility 28 surfaces them).

MDA: Aesthetic = Challenge (fair), Fellowship (instant co-op). SDT: Competence (clear cause and effect), Autonomy (remapping, assists).

## Detailed Design

### Core Rules

**Slots and devices**

1. There are exactly **4 player slots** (0-3, shown as P1-P4). A slot is bound to **one device** at a time; a device is bound to **at most one slot**. Slot index order is **join order** (lowest free slot first), not device number.
2. Device classes:
   - **PAD**: any gamepad, identified by Godot joypad device id plus its GUID.
   - **KB1**: keyboard scheme 1 ("Main", arrows).
   - **KB2**: keyboard scheme 2 ("Left hand", WASD).
   - **TOUCH**: virtual device from Touch controls (31). GDD: `touch-controls.md`. Single instance, slot 0 only, solo only; other devices' Start is ignored while TOUCH is bound (`touch_solo`). *(Amended 2026-11-03, wave 4.)* Project note: gameplay disables Godot's touch-to-mouse emulation (needs an ADR).
   There is one physical keyboard, so KB1 and KB2 share it; each scheme can be claimed by at most one slot. Two players can therefore share one keyboard (see Rule 22 for the ghosting caveat). Pads are the primary input (technical preferences); keyboard is first-class.
3. **Binding is created by a Start press** on an unbound device during Title, Plane select, Stage or Tally (Session Rule 7). Choice of slot, in order: (a) the slot already bound to this device (an Inactive slot re-entering), else (b) the lowest **Empty** slot, else (c) the lowest **Inactive** slot whose bound device is **not connected** or which has no binding, else the press is ignored (the game is full; Menus shows "Game full"). The Start press is the join request; Session creates the Selecting state. *(Amended 2026-11-03, [Menus (22)](menus-title-plane-select.md):)* on Title, **Confirm (Fire or Start) on the START GAME item** is also a join request and binds that device to slot 0. `bind_device(device, slot)` binds a known device to a slot directly (used by Results "Play again" to keep the previous run's bindings). *(Amended 2026-11-03, wave 4, touch-controls.md:)* on touch platforms a tap on START GAME binds TOUCH to slot 0.
4. Keyboard Start keys: KB1 `Enter` / `Numpad Enter`, KB2 `1`. The first keyboard scheme that presses Start claims its slot. If both keyboard Start keys are pressed on the same tick as a pad Start, requests are processed **in event arrival order** (stable, deterministic).
5. A binding is **kept for the whole run**: a slot that goes Inactive (continue expired) keeps its device so that the same pad re-enters the same slot. Bindings are **cleared** when the run ends (Title) or when the slot returns to Empty (a Selecting player pressed Back before confirming, which releases the device).
6. Before any run exists (Title), every connected device may navigate menus; the device that confirms START GAME (Fire or Start, Rule 3) becomes P1's device (slot 0). *(Amended 2026-11-03, Menus Rules 3-6.)* For name entry, Input emits a provisional `typed_char(slot, char)` event when a slot bound to a keyboard types a character in the name-entry alphabet (Menus Rule 36).

**Actions per slot**

7. Every bound slot exposes this fixed action set (ids are the contract with other GDDs):

| Action id | Kind | Used for |
|---|---|---|
| `pN_left`, `pN_right`, `pN_up`, `pN_down` | direction (digital, plus analog on pads) | movement; menu navigation |
| `pN_fire` | button | tap shot / hold charge mode (kit decides); menu confirm; **accepts a Continue** (`CONTINUE_ACCEPT`, Rule 24b) |
| `pN_drone` | button | drone ability (renamed from `pN_ability`) |
| `pN_bomb` | button | bomb; menu cancel |
| `pN_start` | button | join, pause, menu confirm. **Never** accepts a Continue (Rule 24b) |
| `pN_back` | button | menu cancel; also opens pause in Stage |
| `pN_focus` | button | *(added 2026-11-09, as built)* hold to fly at focus speed (precision move, Player plane Rule 6). Default: pad **left trigger**, KB1 **Shift**, KB2 **Q**. Never buffered. |

8. Global (not per slot) actions exist only in **debug builds**: restart, next boss, boss 1-3. They move to `F5`, `F6`, `F7`, `F8`, `F9` (see "Existing code"). They are removed from release builds.

**Sampling and edges (once per tick)**

9. The sampler runs **once per 60 Hz tick, before any gameplay system** (ADR-0001 step 1). It is ticked from the autoload's `_physics_process` with `process_mode = ALWAYS`, so it also runs while the tree is paused (menus need it) and always finishes before the pausable `GameLoop` reads it. Simulation reads only the finished snapshot, never `Input` directly.
10. Raw events are **latched** as they arrive (in `_input`), not polled at the tick. For each action the sampler keeps `down_now`, `latch_press` (a press arrived since the last tick) and `latch_release`. At the tick: `held = down_now OR latch_press`; `pressed = held AND NOT held_prev`; `released = (NOT held) AND held_prev`; then the latches clear (F1). Effect: a tap shorter than one tick still yields `pressed` on tick T, `held = true` for that one tick, `released` on T+1. **No tap is ever lost.**
11. If a button is pressed, released and pressed again inside one tick, it is one press (the sub-16 ms re-press is ignored). If a render frame runs several ticks (catch-up), events are consumed by the first tick; later ticks see steady state.
12. `held_ticks`: 0 when not held; 1 on the `pressed` tick; +1 per tick held. The Player plane converts it to seconds (`held_ticks / 60`).
13. **Snapshot per slot (`SlotInput`)**:

| Field | Type | Meaning |
|---|---|---|
| `connected` | bool | bound device currently present |
| `stick` | Vector2 | raw analog move vector, length clamped to 1 (F2); (0,0) for keyboard/d-pad |
| `dig` | Vector2i | digital move vector, each axis -1/0/1 (opposites cancel); from keys and d-pad |
| `fire`, `drone`, `bomb`, `start`, `back` | `ButtonState` | `pressed`, `held`, `released`, `held_ticks` |
| `nav` | enum set | menu navigation events this tick (Rule 24) |
| `*_buffered` | bool | Drone / Bomb press still inside the buffer window (Rule 17) |
| `drag` | Vector2i | TOUCH only: relative drag this tick in 1/16 canvas px (Touch TF3); (0,0) for other devices *(added 2026-11-03, touch-controls.md)* |
| `drag_active` | bool | TOUCH only: a move finger is down |
| `fire_auto` | bool | TOUCH only: true on touch auto-fire pulse ticks (a pulse is not a Fire hold; Player plane Rule 4.2) |

13a. **Simulation input byte** *(added 2026-11-03, wave 4, online-leaderboards-boss-rush.md):* read-only `sim_input_byte(slot)` returns the post-Input logical input of the tick as one byte (4 bits move direction + 3 bits Fire / Drone / Bomb held). The replay recorder logs it, so ranked-legal input options replay without shipping settings. It never feeds back into the sampler. *(2026-11-03, ADR-0003 / ADR-0008:)* bit 7 carries the fire pulse (Tap Assist / touch auto-fire); for a TOUCH slot the replay also records `drag` (int16 x/y, 1/16 px), `drag_active` and `fire_auto` every tick they change or are non-zero, so touch runs replay exactly.

14. **Digital wins**: if `dig != (0,0)`, the Player plane uses `dig` and skips the deadzone (Player plane PF2); otherwise it uses `stick` with the deadzone. A stick and the d-pad pushed together: `dig` wins.
15. The sampler supplies the shared deadzone numbers to the Player plane from `data/input/input_rules.tres`: `dz_enter` 0.30, `dz_exit` 0.20, `sector_hyst` 4 deg. *(2026-11-03, ADR-0003)* **The 8-way direction is chosen in Input** (the sampler runs Player plane PF2 device-side and outputs `move` 0–8 in the sim byte), so the plane reads only the direction, and PF2's `atan2` is outside the deterministic simulation.
16. Analog triggers used as buttons use press/release hysteresis (F3): press at value >= 0.5, release below 0.35.

**Buffering**

17. *(2026-11-03, ADR-0003)* **Owner moved:** the buffer, `consume(slot, action)` and `clear_buffer(slot)` live in the simulation-side `SimInputDecoder` (GameLoop step 1, part of `state_hash`), because they depend on whether the simulation accepted the press; the sampler only supplies held bits. Behaviour below is unchanged. **Drone and Bomb** presses are buffered for `buffer_ticks` (6 ticks, 0.1 s). A consumer that was not ready on the press tick (kit on cooldown, Bombs not ready) may fire from the buffer by calling `consume(slot, action)` within the window (F6). **Fire is never buffered** (it is a hold). Start/Back are never buffered. *(Note 2026-11-03, Bombs (12) Rule 4:)* Bombs calls `consume(slot, BOMB)` every tick it is IDLE and has stock; it does not consume while busy or at 0 stock, so a press made then expires after 6 ticks. On `stage_started` it consumes once to purge.
18. A buffered press is cleared by `consume`, by expiry, and by `clear_buffer(slot)`. The Player plane calls `clear_buffer(slot)` **every tick the plane is not Active** (FlyIn, Dying, Absent), so a press made before control returns never fires after it (keeps Player plane Rule 10 and AC-17 true).

**Fire options (accessibility)**

19. **Fire toggle** (`fire_toggle`, default off): when on, a Fire press flips a latch; `held` follows the latch (press 1: `pressed` + held; press 2: `released`). The latch resets to off on `plane_died`, on Pause entry and on stage start. Toggle does not affect Drone/Bomb (they are press-only).
20. **Tap Assist** (`tap_assist`, default off): while Fire is held, the sampler adds synthetic `pressed` flags on `fire` at the cadence in F5, only during the first `tap_assist_until` ticks of the hold. It never changes `held` or `held_ticks`, so charge mode behaves exactly as without it. `tap_assist_until` must not exceed the kit's charge threshold (Plane kits 11 publishes it; provisional, 18 ticks assumed). Kits keep their own shot-rate cap, so assist cannot beat it.
21. There is no "turbo" for Drone or Bomb.

**Keyboard and ghosting**

22. Keyboard bindings use **physical keycodes** (position-based; WASD stays WASD on AZERTY). Two players on one keyboard is supported but cheap keyboards may ghost 6-8 simultaneous keys; Menus shows a one-time notice when KB1 and KB2 are both claimed ("Controllers recommended" / Bengali string in the table below).

**Menu navigation**

23. For menus, direction presses become 4-way **nav events** from `dig` or `stick` (stick uses press 0.5 / release 0.35 on the dominant axis, F3 thresholds). Held directions repeat (F4: first repeat after 18 ticks, then every 6). *(2026-11-03, Accessibility 28: the repeat pair reads `access.nav_repeat`: FAST 12 / 4, NORMAL 18 / 6 (default), SLOW 30 / 10.)*
24. Mapping to menu verbs (Menus 22 consumes these): **Confirm** = `fire` pressed or `start` pressed; **Cancel** = `bomb` pressed or `back` pressed; **Nav** = nav events. During Plane select each Selecting slot navigates **only its own** panel with its own device. Elsewhere Menus decides the owner (Rule 27).
24b. *(Added 2026-11-03, wave 5 batch 2, [HUD (20)](hud.md) Rule 24 and [Stage tally (21)](stage-end-tally.md) Rule 17.)* **`CONTINUE_ACCEPT`.** There is **one** verb that accepts a Continue, and it is **`fire` pressed by that slot**. It is the same verb on both surfaces that can show a Continue prompt - the in-stage HUD Continue plate and the Stage tally's dim Continue column - so the glyph the HUD draws, `action_glyph(slot, CONTINUE_ACCEPT)`, resolves to that slot's Fire glyph in its own glyph family (F8).
   - **Start does not accept a Continue.** `start` keeps its single in-stage meaning: it **pauses** (Rule 25). There is therefore **no priority question** between accepting and pausing, and a player in Continue can still pause.
   - Only the slot **in Continue** can accept its own Continue; another slot's Fire press is a normal gameplay Fire for that slot and is never read as an accept.
   - A remap moves the verb with the button: the verb is `fire`, whatever physical input `fire` is bound to in that slot's class (Rules 34-39), and the glyph follows.
   - In the Tally this press is **not** a tally skip (Tally Rule 17).
24c. *(Added 2026-11-03, wave 5 batch 2, `design/ux/settings.md` and [Accessibility (28)](accessibility-options.md) Rule 21a.)* **Menu group jump.** The Accessibility list's group jump (pad shoulders, PageUp / PageDown) is a convenience and never the only path to a row. It **must not fire from a physical shoulder that is bound to Fire, Drone or Bomb in the active pad class** - the **Gamepad: one hand** preset binds Fire to the left shoulder - so on such a class the jump is **suppressed** on the colliding side. Input may instead expose a dedicated verb pair, `nav_group_prev` / `nav_group_next`, that Menus consumes in place of the raw shoulders; either answer satisfies the rule, and suppression is the fallback until the verb pair exists. This is a menu-only verb and never affects an in-run binding.
24a. *(Added 2026-11-03, Accessibility 28 F2.)* **Game-speed latching.** When the game-speed assist (`access.game_speed_pct` < 100) skips a game tick on a 60 Hz physics step, the sampler still runs on that step and **latches** every press edge, so the next game tick sees it; no press is lost.

**Pause, focus and resume**

25. In Stage or Tally, `start` or `back` pressed by any bound slot **pauses** (tree pause; sampler keeps running). The pausing slot is the **pause owner**; only the owner's menu input is accepted (other slots' presses are ignored, shown dimmed). If the owner's device disconnects, ownership passes to the lowest connected bound slot.
26. **Window focus loss** (tab blur, alt-tab, minimise) pauses the game immediately with the owner = lowest connected bound slot. Held states are zeroed on focus loss so no key sticks "down" after refocus.
27. **Resume rule:** on the tick the game leaves Pause, every held gameplay button reports `pressed = false, held = true, held_ticks = 0`; all latches, buffers and unfinished presses made during pause are discarded; the Start/Fire/Bomb press that closed the menu is consumed. (Same shape as the Player plane's held-through-respawn rule.) The Fire toggle latch is off after any pause (Rule 19).

**Disconnect and hot-plug**

28. Godot's `Input.joy_connection_changed(device, connected)` drives all of this. A PAD disconnect for a slot in Selecting, Alive, Dead or Continue **during Stage or Tally** triggers an **automatic pause** with a per-slot "reconnect" overlay (reason DISCONNECT). The slot's binding becomes **Waiting**. A disconnect for an Empty or Inactive slot, or while in Title/Plane select, does not pause (Selecting is cancelled and the slot returns to its previous state, Session Rule 10).
29. A Waiting slot resolves in one of four ways, chosen on the overlay:
   1. **Reconnect:** a pad reconnects whose GUID matches, or any *unbound* pad presses Start: it is bound to the slot. The game stays paused with "Press Start to resume" (never auto-resumes; Rule 27 then applies).
   2. **Use keyboard:** KB1 or KB2 Start (whichever scheme is free) rebinds the slot to the keyboard.
   3. **Drop player:** the slot is forfeited: Session moves it to **Inactive** (record kept; request `forfeit_slot(slot)`, Amendment to Session). Its binding is cleared.
   4. **Wait:** nothing happens; the game stays paused indefinitely.
30. While a slot is Waiting and the game is running (only possible if the player chose to leave the overlay, which is not offered) the slot reports neutral input. Because Rule 28 pauses, the plane is never left unattended.
31. If **several** pads disconnect on one tick (e.g. USB hub), one overlay lists all Waiting slots; each resolves independently; resume is allowed only when no slot is Waiting.
32. A pad **connecting** while no slot is Waiting changes nothing, except that its glyph family becomes available for prompts when it joins.
33. If the pausing slot disconnects while an unrelated pause is open, the pause stays open and the overlay appears over it.

**Remapping** (UI owned by Accessibility 28 / Menus 22; rules here)

34. Remappable: `fire`, `drone`, `bomb` on every class, plus KB1/KB2 movement keys. **Not remappable:** pad movement (left stick + d-pad), `start`, `back`, and the Esc / pad Start/Back roles. *(2026-11-03, Accessibility 28: a setting `input.move_stick` (LEFT / RIGHT / EITHER, default LEFT) picks which pad stick moves the plane; this is a choice of stick, not a movement remap.)*
35. Each action holds **up to 2 bindings** (primary, alternate) **per class**. Bindings are stored per class (all pads share one pad map; KB1 and KB2 each have their own). *(2026-11-03, Accessibility 28 / Save Rule 18, Vertical Slice: optional per-slot pad maps `pad_s0`..`pad_s3` override the shared `pad` map for that slot.)*
36. **Conflict rule:** a control may be bound to one action per class, and a key may not be in both KB1 and KB2. Assigning an already-used control **swaps** (the other action receives the control the target action had; if the target had none, the other action loses that binding). Menus shows a confirm line before swapping.
37. **Last-binding rule:** `fire`, `drone` and `bomb` always keep at least one binding; clearing the last one is refused.
38. **Reserved controls** (cannot be bound): `Esc`, all `F1-F12`, `Tab`, `Ctrl`, `Alt`, `Meta`, `Print`, mouse buttons, pad Start/Back/Guide. (`Tab`/`Ctrl`/`F5`/`F11`/`F12` are browser-reserved on Web.)
39. "Reset to defaults" works per action and per class. Unknown or invalid saved ids are dropped on load and that action falls back to its default (Save 26 stores `InputBindingsData`: version, per-class action to control ids, options `fire_toggle`, `tap_assist`, `dz_preset`).

### Default bindings

**Gamepad (all pad families; positional, matches Godot `JoyButton` names which follow the Xbox layout)**

| Action | Primary | Alternate | Xbox | PlayStation | Nintendo |
|---|---|---|---|---|---|
| Move | Left stick | D-pad | stick / D-pad | stick / D-pad | stick / D-pad |
| Fire | South | Right shoulder | A / RB | Cross / R1 | B / R |
| Drone | West | Left shoulder | X / LB | Square / L1 | Y / L |
| Bomb | East | Right trigger (axis >= 0.5) | B / RT | Circle / R2 | A / ZR |
| Start | Start | - | Menu | Options | + |
| Back | Back | - | View | Create | - |

Matches the existing code (A fire, X ability, B bomb); the alternates are new. Right stick, North button, L-stick/R-stick click, touchpad: unbound. *Unverified:* Godot 4.7 reports Nintendo pads with the same positional `JoyButton` names (South = the pad's bottom face button); confirm on hardware before shipping Switch glyphs.

**Keyboard**

| Action | KB1 "Main" primary | KB1 alternate | KB2 "Left hand" primary | KB2 alternate |
|---|---|---|---|---|
| Move | Arrow keys | WASD (**only while KB2 is unclaimed**) | W A S D | - |
| Fire | Z | Space; `,` | F | - |
| Drone | X | `.` | G | - |
| Bomb | C | `/` | R | - |
| Start | Enter, Numpad Enter | - | 1 | - |
| Back | Esc, Backspace | - | 2 | - |

Notes: `Esc` is `back` for KB1 and KB2 and also pauses in Stage (Rule 25). KB1's `,` `.` `/` are the right-hand set for a right-side player in a split-keyboard game. `Tab` is deliberately unused (browser focus key).

### States and Transitions

**Slot binding**

| State | Meaning | → Next |
|---|---|---|
| Unbound | no device (slot Empty, or Inactive with cleared binding) | Bound (Start press, Rule 3) |
| Bound | device present, input flowing | Waiting (pad disconnect during Stage/Tally), Unbound (Selecting cancelled; run ends) |
| Waiting | slot's pad is gone; game paused | Bound (reconnect or keyboard), Unbound (Drop player) |

**Pause**

| State | Meaning | → Next |
|---|---|---|
| Running | simulation ticking | Paused (Start/Back in Stage or Tally; focus loss; disconnect) |
| Paused (USER / FOCUS / DISCONNECT) | tree paused, sampler still running, owner set | Running (owner resumes and no slot is Waiting), Title (quit confirmed, Session ABANDONED) |

**Per-button tick state** (derived each tick): Idle → Pressed (1 tick) → Held (n ticks) → Released (1 tick) → Idle. A sub-tick tap is Pressed (T) → Released (T+1).

### Interactions with Other Systems

| System | Gets from Input | Gives to Input |
|---|---|---|
| Game events and session (1) | Slot-to-device binding; join request on Start; forfeit request on Drop player; pause/disconnect signals | Slot states (Empty, Selecting, Alive, Dead, Continue, Inactive); confirms or cancels a join |
| Player plane (5) | `SlotInput` snapshot each tick; deadzone numbers; `consume`, `clear_buffer` | Calls `clear_buffer(slot)` on every non-Active tick; `plane_died` resets the Fire toggle |
| Plane kits (11), Bombs (12) | Button states; buffered Drone/Bomb via `consume` | Charge threshold (for Tap Assist cap); readiness |
| Menus, title, plane select (22) | Nav / confirm / cancel per slot; pause owner; glyph family per slot | Which slot owns which screen |
| [Accessibility (28)](accessibility-options.md) | Remap API, options (`fire_toggle`, `tap_assist`, `dz_preset`, `access.nav_repeat`, `input.move_stick`, per-slot pad maps); game-speed press latching (Rule 24a) | UI that edits them; one-handed presets |
| Save (26) | `InputBindingsData` on change | Loads it at boot |
| Touch controls (31) — [GDD](touch-controls.md) | Accepts a TOUCH device that writes the same `SlotInput` plus `drag`, `drag_active`, `fire_auto` | Drag / stick mapping, strip buttons, haptics (Touch Rule 32) |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | `sim_input_byte(slot)` per tick (Rule 13a) | Replay recording and verification |
| Tutorial (30) — [GDD](tutorial.md) | Same `SlotInput` in drills; glyphs via `action_glyph` | Drill goals, hints |
| [HUD (20)](hud.md) | `glyph_family(slot)`, `next_join_slot()`, `action_glyph(slot, action)` for join plates and the continue prompt (`CONTINUE_ACCEPT` = `fire`, Rule 24b); pause overlay data | The join plate is icon-only; HUD does not draw `join.prompt` |
| [Audio (24)](audio.md), [VFX (25)](vfx-and-screen-feedback.md) | UI sound triggers (see Visual/Audio) | - |

*(Updated 2026-11-03, wave 4: Touch controls (31) now has a GDD; no interface above is provisional.)*

### Existing code (`src/autoload/input_setup.gd`, autoload `InputSetup`)

What it does today: registers `p1_`..`p4_` actions in `InputMap` (left/right/up/down, fire, ability, bomb) with action deadzone 0.2, hard-binds slot N to gamepad device N-1, adds keyboard (arrows+WASD, Z/Space fire, X ability, C bomb) to **P1 only**, and registers global `restart`(R), `next_boss`(N), `boss_1..3`(1,2,3). Player code reads `Input.is_action_pressed` / `get_vector` / `is_action_just_pressed` directly in `_physics_process`.

| # | Problem | Correction |
|---|---|---|
| 1 | `pN_ability` | Rename to `pN_drone` now (Player plane dependency and AC-20). `laser_ability.gd` reads `"ability"` and must change with it. |
| 2 | Slot N hard-bound to pad id N-1. Joypad ids are not stable across hot-plug, so P2's pad can be device 0 | Dynamic assignment by Start press (Rules 1-6); `DeviceAssigner` owns the table |
| 3 | P1 gets keyboard **and** pad 0 at once; P2-P4 have no keyboard | Per-class bindings; a slot has one device (Rule 1); KB1 / KB2 schemes |
| 4 | No `start` / `back` actions, no pause, no join | Add them (Rule 7) |
| 5 | Action deadzone 0.2 on every action, and `Input.get_vector` returns analog movement, which contradicts the Player plane's 8-way digital movement and its 0.30 / 0.20 hysteresis | Sampler reads **raw** stick axes (`get_action_raw_strength`-style), the plane applies PF2; `DEADZONE` constant removed; values move to `input_rules.tres` |
| 6 | `is_action_just_pressed` can miss a tap that starts and ends between two physics ticks | Event latching (Rule 10, F1) |
| 7 | Input read by every node in its own `_physics_process` | One sampler, one snapshot per tick (Rule 9) |
| 8 | No hot-plug or focus handling | Rules 26-33 |
| 9 | Debug keys R/N/1/2/3 collide with KB2 (R = Bomb, 1 = Start) and ship in release | Move to F5-F9 and compile out of release (Rule 8) |
| 10 | `ALL_DEVICES = -1` for keyboard events | Kept as an event filter; device checks use `InputEvent.DEVICE_ID_KEYBOARD` or the event type, never `device == 0` (Godot 4.7 change) |

Transition plan: step 1, rename `ability` to `drone` and move debug keys (safe now); step 2, build `InputSampler` and `DeviceAssigner` with tests; step 3, when the Player plane is refactored to `PlaneCore`, it reads the snapshot and the `pN_*` registrations in `InputMap` are **removed** (the ids live on as strings in the bindings table). Until then `InputSetup` keeps registering them for the prototype. `InputMap` keeps only `ui_*` and debug actions.

### Implementation status (2026-11-09)

What is in code, and what a reader should not assume works yet.

**Done**

| Thing | Where | Note |
|---|---|---|
| `pN_drone` replaces `pN_ability` | `src/autoload/input_setup.gd` | `pN_ability` is kept as a legacy alias for the old prototype scene (`laser_ability.gd`) and nothing new reads it |
| Pad defaults, with alternates | same | South / RB Fire, West / LB Drone, East / RT Bomb, LT Focus, Start, Back |
| KB1 on slot 0, KB2 on slot 1 | same | Arrows + Z X C / Enter / Esc, and WASD + F G R / 1 / 2. **2P on one keyboard works out of the box** |
| WASD is KB1's alternate only while KB2 is unclaimed | `release_wasd_from_kb1()` / `restore_wasd_to_kb1()`, called by the Lobby when slot 1 joins or leaves | a solo player may use either hand position |
| Physical keycodes (Rule 22) | same | WASD stays WASD on AZERTY |
| Debug keys off player keys (Rule 8, correction 9) | same | F5 restart, F6 next boss, F7-F9 boss select |
| Trigger-as-button press point | `_ensure()` keeps the highest deadzone an action's controls ask for | presses at 0.50 (F3) |
| Drone / Bomb buffer, 6 ticks (Rule 17, F6) | `src/core/sim_input.gd`: `buffered`, `consume`, `clear_buffer` | the buffer is simulation state, so a replay rebuilds it (ADR-0003). `PlaneKits` and `BombCores` consume only on the tick they act; `PlaneCore` clears it every non-Active tick (Rule 18) |
| Edge detection that does not lose a tap | `src/autoload/input_sampler.gd` latches presses between ticks (Rule 10) | the two-stage sampler from ADR-0002 Decision 2 |

**Not done — do not assume these**

| Gap | Rule | Consequence today |
|---|---|---|
| Dynamic device assignment by Start press | 1-6, correction 2 | slot N is still hard-bound to **joypad N**. Hot-plug can therefore hand P2's pad to P1 |
| `SlotInput` as its own snapshot type, raw stick, 8-way in Input | 13, 14, 15 | the sampler writes `SimInput` directly with **digital** move only; `dz_exit` 0.20 and the 4 degree sector hysteresis do not exist |
| Trigger release hysteresis (0.35) | F3 | a trigger releases at the same value it presses at |
| Remapping, `data/input/input_rules.tres`, `InputBindingsData` | 34-39 | every binding is a code default; nothing is remappable in game |
| Fire toggle, Tap Assist | 19, 20 | not present |
| Hot-plug, focus loss and the disconnect overlay | 26-33 | unplugging a pad mid-run does nothing; the plane simply stops answering |
| `pN_back` consumers, `CONTINUE_ACCEPT`, `action_glyph`, `glyph_family` | 24b, 24c | the action exists and is bound; the HUD and Continue surfaces that read it do not exist yet |
| TOUCH device, `drag`, `fire_auto` | 13, 31 | **deferred on purpose** (see the 2026-11-09 revision note); mobile has no controls at all yet |

**Current PC scheme, as shipped** (this is the sheet to hand a playtester):

| | P1 (KB1) | P2 (KB2) | Any pad (P1-P4 on pads 1-4) |
|---|---|---|---|
| Move | Arrows (WASD while P2 is out) | W A S D | Left stick / D-pad |
| Fire | Z, Space, `,` | F | A (South), RB |
| Drone | X, `.` | G | X (West), LB |
| Bomb | C, `/` | R | B (East), RT |
| Focus | Shift | Q | LT |
| Start / join | Enter, Numpad Enter | 1 | Start |
| Back | Esc, Backspace | 2 | Back |
| Pause | Esc, P | Esc, P | Start (pad 1) |
| Debug | F5 restart, F6 next boss, F7-F9 boss | - | - |

> Decided under auto-approve (2026-11-03): custom sampler with event latching instead of `Input.is_action_just_pressed`; dynamic device assignment by Start press in join order; two keyboard schemes (KB1 arrows, KB2 WASD) so 2P can share a keyboard; face buttons positional (South Fire, West Drone, East Bomb) with shoulder/trigger alternates; pad movement not remappable; auto-pause on pad disconnect with Reconnect / Use keyboard / Drop player; focus loss pauses; Start or Back pauses in Stage; Tab avoided; Drone/Bomb buffer 6 ticks, Fire unbuffered; Tap Assist and Fire toggle as options, default off; debug keys moved to F5-F9; one pad map shared by all pads; digital input overrides analog.

## Formulas

Assumptions: tick = 1/60 s; all timers are integer tick counts (ADR-0001). Values read from `data/input/input_rules.tres`.

**F1. Press / hold / release edge detection** (per slot, per action, per tick)

`held = down_now OR latch_press`
`pressed = held AND NOT held_prev`
`released = (NOT held) AND held_prev`
`held_ticks = held ? held_ticks_prev + 1 : 0`; then `latch_press = latch_release = false`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Down now | `down_now` | bool | - | Control state at the sample moment |
| Press latch | `latch_press` | bool | - | A press event arrived since the last tick |
| Previous held | `held_prev` | bool | - | `held` of the previous tick |
| Held ticks | `held_ticks` | int | 0-unbounded (clamp 2^31-1) | 1 on the pressed tick |

**Output Range:** `pressed` and `released` are true for exactly one tick per press. A press never produces `pressed` twice without a `released` between.
**Example:** a 5 ms tap between ticks 99 and 100 (`down_now` false at tick 100, `latch_press` true): tick 100 `held = true, pressed = true, held_ticks = 1`; tick 101 `held = false, released = true`. A hold from tick 100 to 129 gives `held_ticks` 1..30; at the 30th tick `held_ticks / 60 = 0.5 s`.

**F2. Analog move vector**

`s = (str(right) - str(left), str(down) - str(up))`; `s = s / max(1, |s|)`; `dig = (sign_x, sign_y)` from digital sources with opposites cancelling

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Raw direction strength | `str(a)` | float | 0.0-1.0 | Raw (no action deadzone) strength of an axis direction |
| Stick | `s` | Vector2 | length 0-1 | Output analog vector |
| Digital | `dig` | Vector2i | each -1/0/1 | Keys / d-pad |

**Output Range:** `|s| <= 1` (square-gate pads that report (1,1) are scaled to length 1); `dig` has 9 values.
**Example:** right 0.6, up 0.5 gives `s = (0.6, -0.5)`, `|s| = 0.781` (Player plane PF2 then reads up-right). Corner (1.0, 1.0) gives `(0.7071, 0.7071)`. Left + right keys gives `dig.x = 0`.

**F3. Trigger / axis-as-button hysteresis**

`down = value >= trigger_press` if currently up, else `value >= trigger_release`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Axis value | `value` | float | 0-1 | Trigger or menu stick axis |
| Press threshold | `trigger_press` | float | 0.3-0.8 (0.5) | Becomes down at or above |
| Release threshold | `trigger_release` | float | 0.1-`trigger_press` (0.35) | Becomes up below |

**Output Range:** bool, no flicker inside 0.35-0.50.
**Example:** values 0.49 up, 0.50 down, 0.40 still down, 0.35 still down, 0.34 up.

**F4. Menu navigation repeat**

`nav_fires(h) = (h == 1) OR (h >= 1 + nav_delay AND (h - 1 - nav_delay) mod nav_repeat == 0)` where `h` = `held_ticks` of the direction

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Held ticks | `h` | int | >= 1 | Direction held ticks |
| Initial delay | `nav_delay` | int ticks | 10-30 (18) | Before repeating |
| Repeat interval | `nav_repeat` | int ticks | 3-12 (6) | Between repeats |

**Output Range:** first event at once, then a steady repeat.
**Example (18 / 6):** events at h = 1, 19, 25, 31, 37 (0 s, 0.30 s, 0.40 s, 0.50 s, 0.60 s).

**F5. Tap Assist synthetic presses**

`assist_press(h) = tap_assist AND 1 < h < tap_assist_until AND (h - 1) mod tap_assist_period == 0`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Fire held ticks | `h` | int | >= 1 | `fire.held_ticks` |
| Period | `tap_assist_period` | int ticks | 4-12 (6) | 10 taps/s at 6 |
| Window | `tap_assist_until` | int ticks | 2-kit threshold (18) | Assist stops here (charge begins) |

**Output Range:** extra `pressed` flags only; `held` and `held_ticks` are unchanged.
**Example (6 / 18):** real press at h = 1, synthetic at h = 7 and h = 13; none at h = 19 or later. Off: only h = 1.

**F6. Press buffer**

`buffered(a, now) = (now - press_tick_a) <= buffer_ticks AND NOT consumed_a`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Tick counter | `now` | int | >= 0 | Sampler tick |
| Last press tick | `press_tick_a` | int | >= 0 | Tick of last `pressed` for Drone / Bomb |
| Window | `buffer_ticks` | int | 0-12 (6) | 6 ticks = 100 ms |

**Output Range:** bool.
**Example:** Bomb pressed at tick 100, ready at tick 105: 5 <= 6, fires (once). Ready at 107: 7 > 6, no. Pressed at 100 and consumed at 101: gone.

**F7. Slot choice for a Start press**

`slot = device_slot(d) if bound; else min{ s : state(s) == Empty }; else min{ s : state(s) == Inactive AND (binding(s) is none OR not connected) }; else none`

**Output Range:** 0-3 or none.
**Example:** P1 Alive on pad 4, others Empty; a pad (id 7) presses Start: it becomes slot 1. Next, P1 goes Inactive, pad 4 stays connected; a new pad presses Start: it takes Empty slot 2, not P1's. If all 4 slots are non-Empty and every bound pad is connected: ignored.

**F8. Glyph family**

`family = Nintendo if name matches ("nintendo","switch","pro controller"); PlayStation if ("ps","dualshock","dualsense","playstation"); Xbox if ("xbox","xinput","microsoft"); else Generic`, case-insensitive on `Input.get_joy_name(device)`.

**Output Range:** one of 4 families; keyboard slots use the keycap set. **Example:** "PS5 Controller" gives PlayStation; "Wireless Gamepad" gives Generic. On Web, browser pad ids differ; Generic is the safe fallback.

> Decided under auto-approve (2026-11-03): single tick of tap stretching; trigger thresholds 0.5 / 0.35 (matches the deadzone-gap idea in PF2); nav repeat 18 / 6 (standard console UI feel); Tap Assist 6-tick period; buffer 6 ticks (100 ms, within the 5-8 frame range arcade games use).

## Edge Cases

**Taps and edges**

- **If a button is pressed and released between two ticks**, it yields `pressed` and `held` on the next tick and `released` on the one after (F1).
- **If a button is pressed, released and pressed again within one tick**, it counts as one press.
- **If the game runs 0 ticks in a frame (render faster than 60 Hz)**, events keep latching and the next tick consumes them; nothing is lost.
- **If the game runs 2+ ticks in a frame**, the first tick consumes the events; later ticks repeat steady state with no new `pressed`.
- **If left+right (or up+down) are pressed together**, `dig` cancels on that axis.
- **If a stick and the d-pad are used together**, `dig` wins and `stick` is ignored by the plane.
- **If a stick reports a magnitude over 1**, it is scaled to length 1 (F2).
- **If a stick drifts above `dz_enter`**, the plane drifts; the player can pick a larger `dz_preset` (Accessibility 28). A sub-0.30 drift never moves the plane.

**Buffer**

- **If Drone is pressed while the plane is FlyIn, Dying or Absent**, nothing is buffered (cleared every non-Active tick, Rule 18).
- **If Bomb is pressed 7 ticks before it becomes ready**, it does not fire (6-tick window).
- **If Drone and Bomb are pressed on the same tick**, both are buffered independently; kit and Bombs decide order.
- **If a press is consumed by the kit**, the buffer entry is removed so one press never fires twice.

**Fire options**

- **If Tap Assist is on and the player taps once**, only the real press (h = 1) is sent; assist adds taps only while held.
- **If Fire toggle is on and the plane dies**, the latch resets to off; the player must press Fire again after respawn.
- **If Fire toggle is on and the game is paused and resumed**, the latch is off after resume (Rule 19).

**Assignment**

- **If two devices press Start on the same tick**, they are served in event arrival order (first gets the lower slot).
- **If a device that already owns a slot presses Start during a Stage**, it pauses (it does not join again).
- **If a 5th device presses Start with all 4 slots bound**, it is ignored.
- **If KB1 and KB2 are both claimed**, any other keyboard Start press does nothing.
- **If a pad drops in during the final boss or the tally**, the join is allowed (Session edge cases); input to that slot starts only when its plane is Active.
- **If a Selecting player presses Back/Cancel before confirming**, the slot returns to Empty and the device is released for others.
- **If an Inactive slot's device is still connected and a different new device presses Start while an Empty slot exists**, the new device gets the Empty slot, not the Inactive one.

**Disconnect and focus**

- **If a pad disconnects mid-Stage while its plane is Active**, the game pauses before the next tick's simulation; no tick runs with the plane unattended. (The disconnect event arrives in `_input`; the pause is applied at that tick's start.)
- **If a pad disconnects exactly on a tick where the player took a lethal hit**, the hit stands (Session/Collision own it). The pause begins after the tick.
- **If the pad reconnects with a different device id but the same GUID**, it rebinds to the Waiting slot. If GUID is unreadable (Web), only the "any unbound pad presses Start" path applies.
- **If two Waiting slots and one pad returns**, it is bound to the **lowest** Waiting slot unless the GUID matches the other.
- **If the only connected device was P1's pad and KB1 is free**, "Use keyboard" is offered.
- **If the player picks Drop player for the last live slot**, Session sees a forfeited slot; if no slot remains Alive, Dead or Continue, game over follows (Session Rule 10).
- **If the window loses focus while a button is held**, held states are zeroed and the game pauses (Rule 26); on refocus and resume, held controls are re-sampled with `pressed = false`.
- **If the Web tab is backgrounded and ticks stop**, the pause on blur has already happened; on return the game stays paused.

**Remapping**

- **If the player binds a control already used**, it swaps (Rule 36); if the swap would leave the other action with no bindings, the swap is refused for `fire`/`drone`/`bomb`.
- **If the player binds a reserved control (Esc, F-keys, Tab)**, it is refused with a message.
- **If saved bindings reference a control that no longer exists**, that binding is dropped and the action falls back to its default if empty.
- **If KB1 alternate movement (WASD) is active and KB2 is claimed mid-run**, WASD leaves KB1 on the next tick; KB1 uses arrows only.
- **If the keyboard layout is non-QWERTY**, physical keycodes keep positions; displayed key labels use the layout label where available, else the QWERTY label (unverified on Web).

**Degenerate strategies**

- **If a player uses a macro or turbo controller**, Fire has no gameplay value beyond the kit's shot-rate cap, Drone/Bomb are cooldown-gated; nothing to exploit. Tap Assist cannot exceed the cap (Rule 20).
- **If a player holds Pause to freeze-step**, there is no frame-step in release builds; pausing resets held states and buffers (Rule 27), so pause cannot be used to line up inputs.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Slot states (Empty, Selecting, Alive, Dead, Continue, Inactive); slot-to-device table is owned here; join confirm; `forfeit_slot(slot)` (Amendment); pause owner and ABANDONED flow |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Player plane (5) — GDD | Hard | `SlotInput` each tick; `pN_drone` rename; deadzone numbers; `clear_buffer`, `consume` |
| Plane kits and drones (11) — GDD | Hard | Button states, buffered Drone; kit publishes its charge threshold (`charge_hold_ticks` 18, Plane kits Rule 4). |
| Bombs (12) — GDD | Hard | Bomb press / buffer: `consume(slot, BOMB)` only while IDLE with stock; one purge `consume` at `stage_started` (Bombs Rule 4). |
| Menus, title and plane select (22) — [GDD](menus-title-plane-select.md) | Hard | Nav, confirm, cancel per slot; pause owner; disconnect overlay; glyph family; Title Confirm as join (Rule 3); `bind_device`; `typed_char` (provisional). |
| Stage-end tally (21) — [GDD](stage-end-tally.md) | Soft | `pN_fire` press edge is tally skip (first press) and confirm (second press); Start/Back pause (Rule 25). *(Added 2026-11-03.)* |
| Accessibility options (28) — [GDD](accessibility-options.md) | Soft | Remap API; `fire_toggle`, `tap_assist`, `dz_preset`, `nav_repeat`, `input.move_stick`, `pad_s0..3`. |
| Save, settings and high scores (26) — [GDD](save-settings-high-scores.md) | Soft | Persists overrides only as `input.bindings` (`InputBindingsData` against Input defaults, Save Rule 18) plus `input.dz_preset`, `input.fire_toggle`, `input.tap_assist`; loads at boot. |
| Touch controls (31) — [GDD](touch-controls.md) | Soft | TOUCH device writes `SlotInput` (incl. `drag`, `drag_active`, `fire_auto`); slot 0, solo only. |
| Tutorial (30) — [GDD](tutorial.md) | Soft | Reads `SlotInput` in drills; `action_glyph` for glyph tokens. |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | Soft | `sim_input_byte(slot)` for the replay log. |
| HUD (20) — [GDD](hud.md) | Soft | `glyph_family(slot)`, `next_join_slot()`, `action_glyph(slot, action)`. Join plate is icon-only (START glyph + pips): `join.prompt` is not drawn by the HUD (Menus may still use it). |
| Co-op and Team Chain (18) — [GDD](coop-and-team-chain.md) | Soft | Active slot set (via Session) |
| Audio (24), VFX (25) — [GDD](audio.md), [GDD](vfx-and-screen-feedback.md) | Soft | UI sound triggers. |
| Localization (27) — [GDD](localization.md) | Soft | Prompt strings (Bengali + English) |

**Dependency graph check:** GDD files that exist: game-events-and-session.md, player-plane.md. All others are not yet written and must list this system. *(Update 2026-11-03: every system above has a GDD, including Touch controls (31) since wave 4.)*

**Amendments to other docs**

1. `design/gdd/systems-index.md` row 2: status `**Designed** (pending review) — [GDD](input-and-player-mapping.md)`; Depends on stays `1`. Progress tracker: GDDs written 8; "Code exists without GDD" 3 (14, 17, 20 partly).
2. `design/gdd/player-plane.md`: Dependencies row Input (2): replace "No GDD ... Provisional: `pN_ability` is renamed `pN_drone`" with "GDD: `input-and-player-mapping.md`. `pN_drone` is final." Rule 9: "(InputSetup `pN_*`; ...)" becomes "(Input `SlotInput` snapshot; actions `pN_*`; `pN_ability` is now `pN_drone`)". Interactions row Input: add "deadzone numbers `dz_enter`/`dz_exit`/`sector_hyst` are stored in `data/input/input_rules.tres` (owned by Input), the maths stays in PF2". Rule 10: add "the plane calls `clear_buffer(slot)` every non-Active tick". AC-20: replace with "the Input snapshot for each of slots 0-3 exposes move, fire, drone, bomb, start, back; no `ability` id exists". Open Question 5: mark **Resolved**: pad disconnect pauses with a reconnect overlay (Input Rules 28-33). Edge case "If a pad disconnects mid-flight": the plane no longer stops and stays hittable, the game pauses first.
3. `design/gdd/game-events-and-session.md`: add a slot-state transition **Alive / Dead / Continue / Selecting → Inactive on `forfeit_slot(slot)`** (used by Input's "Drop player"; record kept, `player_slot_inactive` fires); Interactions row Input (2): "Writes: `forfeit_slot`, join request; reads slot states"; Open Question 2 marked **Resolved by Input GDD**. Rule 7 note: slot choice is Input F7.
4. `docs/architecture/adr-0001-gdscript-bullets-multimesh.md` tick diagram step 1: `InputSetup read per-slot actions` becomes `InputSampler snapshot (autoload, process_mode ALWAYS, ticked before GameLoop)`.
5. `design/gdd/game-concept.md` section 5: no change (Fire / Drone / Bomb unchanged); add Start/Back note under shared rules.
6. Each later GDD (11, 12, 18, 20, 22, 26, 28, 31) lists "Input and player mapping" in Dependencies.

## Tuning Knobs

All live in `data/input/input_rules.tres` (rules), `data/input/default_bindings.tres` (bindings), `data/input/prompt_glyphs.tres` (glyph ids, strings). Categories: F = feel, C = curve, G = gate.

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `dz_enter` (F) | 0.30 | 0.15-0.50 | Drift moves the plane | Dead stick, slow start | Player plane PF2 |
| `dz_exit` (F) | 0.20 | 0.10-`dz_enter` | Flicker if equal to `dz_enter` | Stop feels sticky | `dz_enter` |
| `sector_hyst` (F) | 4 deg | 0-8 | Diagonal flip-flop | Hard to hit diagonals | PF2 |
| `dz_presets` (F) | low 0.20/0.12, default, high 0.40/0.28 | within the ranges above | - | - | Accessibility (28) |
| `trigger_press` / `trigger_release` (F) | 0.5 / 0.35 | 0.3-0.8 / 0.1-press | Accidental trigger bomb | Hard to fire | Bomb alt binding |
| `buffer_ticks` (F) | 6 | 0-12 | Bomb "ate" my press | Premature surprise Bomb | Kit/Bomb cooldown |
| `tap_assist` (G) | off | on/off | - | - | Accessibility |
| `tap_assist_period` (F) | 6 ticks | 4-12 | Exceeds the kit rate cap | Slow, barely helps | Kit shot rate |
| `tap_assist_until` (F) | 18 ticks | 2-kit charge threshold | No assist | Eats into charge | Kit charge threshold (provisional) |
| `fire_toggle` (G) | off | on/off | - | - | Accessibility |
| `nav_delay` / `nav_repeat` (F) | 18 / 6 ticks | 10-30 / 3-12 | Menu overshoots | Menu sluggish | Menus |
| `bindings_per_action` (G) | 2 | 1-3 | No alternate | UI clutter | Remap UI |
| `pause_on_focus_loss` (G) | on | on/off | - | - | Web, alt-tab |
| `keyboard_ghost_notice` (G) | on | on/off | - | - | KB1+KB2 co-op |

Locked, not knobs: 4 slots (`max_players`), 60 Hz sampling, one device per slot, Fire never buffered, Start/Back not remappable.

**Owned elsewhere:** shot-rate cap, charge threshold, drone cooldown - Plane kits (11); bomb readiness - Bombs (12); what `held_ticks` means for charge - kit; menu screen layouts - Menus (22).

> Decided under auto-approve (2026-11-03): defaults above. `buffer_ticks` 6 balances "forgiving" against "surprise bomb"; revisit after playtest (Open Questions).

## Visual/Audio Requirements

> Art bible (`design/art/art-bible.md`) rules apply: no effect over enemy bullets (layer 8); no Void Indigo / Ink for non-bullets; no reserved bullet shapes (orb, rice, needle, ring) as UI icons.

**Button glyphs** (menus, pause overlay, join plate; never drawn in the play field during Active flight)

- Size **16x16 px at 1x** in a square plate with cut corners (never a bare circle, so a face-button glyph cannot read as an enemy orb), 1 px Char outline (no Ink), Cream `#F4EBD6` face with the button letter/symbol in Char; the button currently being asked for is Ember Gold `#FFC93C`.
- Glyph sets (ids in `prompt_glyphs.tres`): `xbox`, `playstation`, `nintendo` (South is labelled B, East A), `generic` (a 4-cell diamond with the asked-for position filled), `keycap` (keyboard keys, Latin letters, arrows drawn as arrow glyphs).
- Colour is never the only cue (shape or letter always present). P-colour tag (art bible §4.4) appears next to the glyph on the join plate, with pattern and pips, never colour alone.
- Keycaps stay Latin in Bengali UI (keys are physically Latin); Bengali digits are not used on keycaps.
- Disconnect overlay: Alarm Red end-cap only if a timer is shown (none here); a 2 px slot-colour frame around the Waiting slot's plate; no flashing, no screen tint.

**Audio** (audio-director to confirm; all on the UI bus, never competing with the 8-voice bullet pool)

| Event | Sound | Notes |
|---|---|---|
| Menu nav | short tick | per slot pitch step |
| Confirm / Cancel | soft click / lower click | |
| Join (Start press accepted) | short rising chime in the slot's pitch | 1 voice, max 2 per tick merged |
| Pad disconnected | one low two-note cue | once per tick, not per pad |
| Pause / resume | filtered-down / back (Audio owns ducking) | |

No rumble in MVP. No sound when a button is pressed in-flight (Input makes none).

## UI Requirements

Player-facing elements this system needs (owners in brackets):

- **Join plates** in empty co-op slots: "Press START to join" with the pad glyph (HUD 20 / art bible join plate).
- **Press-START screens** on Title, with a "press any button on your controller" line (Web gamepads appear only after a first press) (Menus 22).
- **Disconnect / reconnect overlay** (per Waiting slot, options Reconnect / Use keyboard / Drop player / Wait) (Menus 22).
- **Pause menu** with owner tag; others dimmed (Menus 22).
- **Controls and remap screen**, hold-vs-toggle, Tap Assist, deadzone preset (Accessibility 28 / Menus 22).
- **Game full** and **controllers recommended** toasts.
- **Prompts** anywhere a button is named use the current slot's glyph family.

**Bilingual strings** (Bengali drafts for native-speaker review by Localization 27; equal visual weight per art bible, +40% width reserved for Bengali):

| Key | English | Bengali (draft) |
|---|---|---|
| action.fire | Fire | গুলি |
| action.drone | Drone | ড্রোন |
| action.bomb | Bomb | বোমা |
| action.start | Start | শুরু |
| action.back | Back | পিছনে |
| action.pause | Pause | বিরতি |
| join.prompt | Press START to join | যোগ দিতে শুরু চাপুন |
| pad.disconnected | Controller disconnected | কন্ট্রোলার সংযোগ বিচ্ছিন্ন |
| pad.reconnect | Reconnect controller for P{n} | P{n}-এর জন্য কন্ট্রোলার সংযুক্ত করুন |
| pad.use_keyboard | Use keyboard | কীবোর্ড ব্যবহার করুন |
| pad.drop | Drop P{n} | P{n} বাদ দিন |
| pad.resume | Press START to resume | চালিয়ে যেতে শুরু চাপুন |
| game.full | Game full | খেলা পূর্ণ |
| kb.ghost | Controllers recommended for two players on one keyboard | একই কীবোর্ডে দুই জনের জন্য কন্ট্রোলার ভালো |
| opt.tap_assist | Tap Assist | ট্যাপ সহায়তা |
| opt.fire_toggle | Toggle Fire | ফায়ার টগল |

Player tags stay "P1"-"P4" (Latin P with Latin digits) in both languages; identity is carried by colour, pattern and pips (Open Question).

📌 **UX Flag**: run /ux-design for the disconnect/reconnect overlay, the join plate, and the controls/remap screen before writing epics.

## Acceptance Criteria

Defaults used: 4 slots, tick 1/60 s, `dz_enter` 0.30, `dz_exit` 0.20, `sector_hyst` 4, `trigger_press` 0.5, `trigger_release` 0.35, `buffer_ticks` 6, `tap_assist_period` 6, `tap_assist_until` 18, `nav_delay` 18, `nav_repeat` 6, `fire_toggle` off, `tap_assist` off, `pause_on_focus_loss` on.

**Test setup:** the sampler, assigner and bindings logic are node-free `RefCounted` classes (`InputSampler`, `DeviceAssigner`, `InputBindings`) with no `Input` singleton access. Tests drive them with injected raw events `feed(device_class, device_id, control_id, value)` between explicit `tick()` calls (no real time, no `delta`), a stub Session returning slot states, and the bindings/rules loaded from `data/input/*.tres` (numbers read from the resources, not literals). Tests: `tests/unit/test_input_sampler.gd`, `test_input_assignment.gd`, `test_input_bindings.gd`, in `extends SceneTree` style like `tests/unit/test_chain_tracker.gd`. Integration: `tests/integration/test_input_pause.gd`. Manual evidence: `production/qa/evidence/input/`.

Tags: [Unit] headless pure logic · [Integration] scenes/tree pause · [Perf] budget · [Manual] needs a human/hardware.

### Slots and assignment

- **AC-01 [Unit] (Rules 1, 3, F7):** **GIVEN** all slots Empty, **WHEN** pad id 5 then pad id 2 press Start on separate ticks, **THEN** pad 5 is slot 0 and pad 2 is slot 1 (join order, not id order).
- **AC-02 [Unit] (F7):** slots `[Alive(pad 4), Empty, Empty, Empty]`, pad 7 presses Start gives slot 1. With slot 0 Inactive and pad 4 connected, a new pad takes slot 2 (Empty first), not slot 0.
- **AC-03 [Unit] (Rule 3):** all 4 slots bound to connected pads, a 5th device presses Start: no binding changes and a `game_full` event is raised.
- **AC-04 [Unit] (Rule 1):** a device bound to slot 0 presses Start again during Stage: no second binding is created; a pause request is raised instead.
- **AC-05 [Unit] (Rule 4):** pad Start and KB1 Enter in the same tick, pad first in arrival order: pad gets slot 0, KB1 slot 1; reversed order gives the reverse.
- **AC-06 [Unit] (Rules 2, 4):** KB1 claimed by slot 0, then KB1 Enter again: nothing; KB2 key `1` claims slot 1; a third keyboard Start does nothing.
- **AC-07 [Unit] (Rule 5):** slot 1 Selecting presses Back: slot 1 becomes Empty, device released, and the same pad pressing Start again gets slot 1 (lowest Empty, slot 0 being bound).
- **AC-08 [Unit] (Rule 5):** slot 0 goes Inactive with its pad still connected; that pad presses Start again: it re-enters slot 0 (not an Empty slot).
- **AC-09 [Unit] (Rule 5):** run ends: all bindings cleared.

### Edges and ticks

- **AC-10 [Unit] (F1):** sub-tick tap (`feed` press and release between ticks 99 and 100): tick 100 has `pressed = held = true, held_ticks = 1, released = false`; tick 101 has `released = true, held = false, held_ticks = 0`.
- **AC-11 [Unit] (F1, Rule 12):** press fed before tick 100, release fed before tick 130: `held_ticks` = 1..30 on ticks 100..129; `pressed` only on 100; `released` only on 130; at tick 129 `held_ticks / 60 = 0.5`.
- **AC-12 [Unit] (Rule 11):** press, release, press fed in one tick: exactly one `pressed`, `held` stays true, no `released`.
- **AC-13 [Unit] (Rule 11):** two ticks run back-to-back after one event batch: the second tick has `pressed = false`.
- **AC-14 [Unit] (Rule 9):** `tick()` output for 600 ticks of a seeded random event script is identical across two runs (determinism: compare a hash of all snapshots).
- **AC-15 [Perf] (Rule 9):** 4 slots, all 9 actions, 10,000 ticks with random events: p99 `tick()` <= 0.05 ms on REF-PC and <= 0.1 ms on REF-WEB; event feed p99 <= 0.02 ms; zero allocations per tick after warm-up.

### Stick and digital

- **AC-16 [Unit] (F2):** right 0.6 + up 0.5: `stick = (0.6, -0.5)` ±0.001; (1.0, 1.0) gives (0.7071, 0.7071) ±0.001; (0.2, 0.1) is passed through unchanged (no deadzone applied by the sampler).
- **AC-17 [Unit] (Rule 14):** keys left+right: `dig.x = 0`; up+left+right: `dig = (0, -1)`; d-pad right with stick (0, 1): `dig = (1, 0)` and the plane uses `dig`.
- **AC-18 [Unit] (Rule 15):** the sampler exposes `dz_enter = 0.30`, `dz_exit = 0.20`, `sector_hyst = 4` read from `input_rules.tres`; changing the resource changes the exposed value.
- **AC-19 [Unit] (F3):** right trigger value 0.49 not down, 0.50 down, 0.40 down, 0.35 down, 0.34 up; with value jittering 0.45-0.55 after pressing, no release occurs while >= 0.35.

### Buffer and options

- **AC-20 [Unit] (F6):** Bomb pressed at tick 100: `consume` at 105 returns true and a second `consume` returns false; `consume` at 107 returns false (fresh press).
- **AC-21 [Unit] (Rule 18):** Drone pressed at tick 100, `clear_buffer(slot)` at 101: `consume` at 102 is false. Presses fed while `clear_buffer` is called every tick never become consumable.
- **AC-22 [Unit] (Rule 17):** Fire pressed: `fire_buffered` does not exist / is always false; Drone and Bomb buffer independently when pressed on the same tick.
- **AC-23 [Unit] (F5):** `tap_assist` on, Fire held from tick 100: `pressed` on h = 1, 7, 13 only (ticks 100, 106, 112); `held_ticks` unchanged (1..N); off: only h = 1. With `tap_assist_until` 8: only h = 1, 7.
- **AC-24 [Unit] (Rule 19):** `fire_toggle` on: press 1 gives `pressed, held`; held stays after release; press 2 gives `released`; `plane_died` resets latch to off; pause entry resets it.
- **AC-25 [Unit] (Rule 21):** Drone and Bomb ignore `fire_toggle` and `tap_assist` (no synthetic presses).

### Menu navigation

- **AC-26 [Unit] (F4):** a direction held from tick 100: nav events at ticks 100, 118, 124, 130, 136 (h = 1, 19, 25, 31, 37); release at 126 stops them.
- **AC-27 [Unit] (Rule 24):** Confirm fires on `fire` pressed or `start` pressed; Cancel on `bomb` pressed or `back` pressed; stick right at 0.5 gives a nav-right event, at 0.34 after pressing it releases.
- **AC-28 [Unit] (Rule 24):** during Plane select slot 1's nav does not move slot 0's panel (events carry slot index).

### Pause, resume, focus

- **AC-29 [Integration] (Rule 25):** in Stage, slot 1 presses Start: tree paused, owner = slot 1; slot 0's Confirm is ignored; slot 1's Back resumes (owner action). The sampler still produces snapshots while paused.
- **AC-30 [Integration] (Rule 27):** Fire held through pause and resume: first tick after resume `pressed = false, held = true, held_ticks = 0`; the Start/Bomb press that closed the pause produces no `pressed` in the game.
- **AC-31 [Unit] (Rule 27):** presses fed during pause are discarded on resume; Drone buffer empty after resume.
- **AC-32 [Integration] (Rule 26):** emit window focus loss with Fire and Left held: game pauses within the same tick, held states zero, owner = lowest connected bound slot; after refocus the game stays paused.
- **AC-33 [Integration] (Rule 25):** owner disconnects while Paused: ownership passes to the lowest connected bound slot.

### Hot-plug

- **AC-34 [Integration] (Rule 28):** 2P Stage, slot 1's pad disconnects (injected): game is paused before the next gameplay tick (no PlaneCore tick runs), slot 1 binding = Waiting, overlay data lists slot 1 only.
- **AC-35 [Unit] (Rule 28):** disconnect while on Title, or for an Empty/Inactive slot: no pause; during Plane select the Selecting slot returns to its previous state.
- **AC-36 [Unit] (Rule 29.1):** a pad with the same GUID reconnects with a different device id: bound to Waiting slot 1, game still paused until Start is pressed to resume. A different-GUID pad pressing Start also binds to slot 1.
- **AC-37 [Unit] (Rule 29.2):** Use keyboard with KB2 free: slot 1 rebinds to KB2; with KB1 and KB2 both claimed: option not offered.
- **AC-38 [Integration] (Rule 29.3):** Drop player: `forfeit_slot(1)` called once, slot Inactive, record kept, binding cleared; if no Alive/Dead/Continue slot remains the run ends GAME_OVER.
- **AC-39 [Unit] (Rule 31):** pads for slots 0 and 2 disconnect on the same tick: one overlay with two entries; resume is refused while either is Waiting.
- **AC-40 [Unit] (Rule 32):** a pad connects with no Waiting slot: no binding or pause change.

### Bindings and remapping

- **AC-41 [Unit] (Default bindings):** the default table matches the tables above for pad, KB1, KB2 (each control id resolves to the listed action); no control id appears for two actions in the same class; no key appears in both KB1 and KB2 except none.
- **AC-42 [Unit] (Rule 36):** bind Bomb to `Z` (Fire's key) in KB1: swap, Fire gets Bomb's old key `C`; no duplicates remain.
- **AC-43 [Unit] (Rule 37):** clearing the last binding of Fire/Drone/Bomb is refused; clearing the alternate succeeds.
- **AC-44 [Unit] (Rule 38):** binding `Esc`, `F5`, `Tab`, `Ctrl` or a pad Start button to Fire is refused.
- **AC-45 [Unit] (Rule 34):** pad movement and `start`/`back` cannot be remapped (API refuses).
- **AC-46 [Unit] (Rule 39):** a saved `InputBindingsData` with an unknown control id loads: that binding is dropped, the action falls back to default if empty; a valid saved remap round-trips unchanged.
- **AC-47 [Unit] (Keyboard):** KB1 WASD alternate works while KB2 is unclaimed; after KB2 is claimed, WASD affects only KB2's slot and KB1 uses arrows only.
- **AC-48 [Unit] (Rule 8):** release builds register no `restart`/`next_boss`/`boss_N` actions; debug builds map them to F5-F9.

### Glyphs and labels

- **AC-49 [Unit] (F8):** names "Xbox Wireless Controller" gives Xbox, "PS5 Controller" gives PlayStation, "Nintendo Switch Pro Controller" gives Nintendo, "Wireless Gamepad" gives Generic; Nintendo South label is "B".
- **AC-50 [Unit] (UI strings):** every key in the bilingual table exists in both languages; no string is empty; `{n}` placeholders match across languages.
- **AC-51 [Manual] (Visual):** at 1x, Bengali pause overlay, Reconnect and Join plates fit their plates with >= 4 px headroom above the matra and 40% extra width; reviewed by a native Bengali reader.

### Existing code

- **AC-52 [Integration] (Existing code #1):** project contains no `_ability` input id; `laser_ability.gd` reads `drone`; the game plays as before after step 1 of the transition.
- **AC-53 [Manual] (Feel):** frame-stepped capture with a 1 kHz-class key logger: 20 sub-10 ms taps on Fire, 20 on Bomb in a test scene produce 20 of 20 registered shots/bombs (zero lost).
- **AC-54 [Manual] (4P drop-in):** four testers each press Start on their own pad within 10 s; all four are flying with distinct colours, nobody opens a menu other than plane select.
- **AC-55 [Manual] (Web):** on desktop Chrome and Firefox (REF-WEB) with an Xbox and a PS5 pad: first press activates the pad, 8-way move, Fire/Drone/Bomb all work, unplugging a pad mid-stage pauses; document results. Safari/mobile browsers are out of MVP scope. Godot 4.7 Web gamepad behaviour is **unverified**; this AC is the check.
- **AC-56 [Manual] (Keyboard co-op):** two testers share one keyboard (KB1 + KB2) for a 2-minute stage; record any ghosting; pass if no stuck or missed input on a standard 6KRO and an NKRO keyboard.

> Criteria drafted under auto-approve; `qa-lead` not consulted (solo drafting). Numbers in AC-26 and AC-23 follow F4 and F5 exactly.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Godot 4.7 Web gamepad support (Gamepad API mapping, GUIDs, `joy_connection_changed` timing, `get_joy_name` strings) is **unverified**. Test on REF-WEB with Xbox and PS pads (AC-55). | Input + godot-specialist | Before Web vertical slice |
| 2 | Do Nintendo pads report the same positional `JoyButton` indices in 4.7 (South = bottom button)? Needed for correct Switch glyphs. | Input | Before Switch tier |
| 3 | Plane kits' charge threshold (Tap Assist upper bound, assumed 18 ticks) and shot-rate cap. | Plane kits (11) GDD | Plane kits GDD |
| 4 | ~~Should resuming from pause add a short 3-2-1 count or a brief invulnerability beat? Currently only input re-arming (Rule 27).~~ **Closed 2026-11-03:** a 45-tick, 3-pip resume beat (`resume_beat_ticks`) keeps the tree paused before play resumes; no invulnerability (Menus Rule 30). (menus-title-plane-select.md) | Menus (22) + Collision (6) | Pre-Production UX |
| 5 | Player tag text: "P1" Latin in both languages, or Bengali ordinals? Bengali strings above need native review. | Localization (27) | Vertical Slice |
| 6 | ~~Per-slot pad remapping (different maps for different pads)? Currently one pad map shared.~~ **Closed 2026-11-03:** yes at VS, `pad_s0`..`pad_s3` override the shared map (accessibility-options.md; Rule 35). | Accessibility (28) | Vertical Slice |
| 7 | ~~Touch controls: virtual stick style (relative drag), button layout, and whether TOUCH can hold more than one slot.~~ **Closed 2026-11-03:** relative drag (floating stick as option), buttons in a strip below the canvas, TOUCH is one slot (slot 0, solo) (touch-controls.md). | Touch controls (31) + `/ux-design` | Target tier |
| 8 | Replay/ghost support: the sampler's output is deterministic and could be recorded (stick quantised to 1/127). Wanted? *(2026-11-03: Online leaderboards (32) records `sim_input_byte` per tick for replay verification; a watch-replay feature stays out of scope.)* | Producer | Full Vision |
| 9 | ADR: sampler as autoload vs owned by `GameLoop`; `InputMap` removal of `pN_*`; amend ADR-0001 step 1. | lead-programmer | Before implementation |
| 10 | ~~Rumble on hit/Critical Break and a rumble toggle.~~ **Closed 2026-11-03:** `access.rumble` (OFF / LOW / NORMAL, Target) and `access.chain_cue_rumble` (VS) (accessibility-options.md). Touch haptics are decided in touch-controls.md Rule 32. | Audio (24) / Accessibility (28) | Polish |
