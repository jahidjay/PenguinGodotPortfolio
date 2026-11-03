# Report: Input and Player Mapping (1-4P) GDD

## 1. File written
`design/gdd/input-and-player-mapping.md` (all 14 required headings, 56 ACs). It defines a node-free `InputSampler` (one `SlotInput` snapshot per slot per 60 Hz tick, event latching so sub-tick taps are never lost), `DeviceAssigner` (slot-to-device by Start press in join order), default bindings (pad, KB1, KB2), remap rules, Drone/Bomb buffer, Tap Assist and Fire toggle, menu nav events, pause/focus/disconnect rules, glyph families and Bengali+English prompt strings. It also lists 10 problems in the existing `InputSetup` and a 3-step correction plan.

## 2. Key decisions (auto-approve)
- Custom sampler with event latching instead of `Input.is_action_just_pressed`; ticked from the autoload (process ALWAYS) before GameLoop so menus work while paused.
- Gameplay reads only the snapshot; `pN_*` InputMap registrations stay for the prototype and are removed when Player plane is refactored. `pN_ability` -> `pN_drone` final.
- 4 slots, one device per slot, binding by Start press, slot = lowest Empty (join order); binding kept all run; cleared at run end or on Selecting cancel.
- Keyboard: two schemes. KB1 arrows + Z/X/C (alts Space, `,` `.` `/`, WASD only while KB2 free); KB2 WASD + F/G/R, Start `1`, Back `2`. Tab avoided (browser).
- Pad: South Fire, West Drone, East Bomb (as existing), alts RB/LB/RT; pad movement, Start, Back not remappable.
- Digital input overrides analog; sampler supplies raw stick; deadzone numbers (0.30/0.20/4 deg) live in `input_rules.tres`, maths stays in Player plane PF2.
- Drone/Bomb buffer 6 ticks, cleared every non-Active tick; Fire never buffered.
- Tap Assist (period 6, until 18) and Fire toggle: options, default off.
- Start or Back pauses in Stage; pause owner controls the menu; focus loss pauses; resume re-arms held buttons (pressed=false, held_ticks=0).
- Pad disconnect during Stage/Tally auto-pauses; overlay: Reconnect / Use keyboard / Drop player (needs new Session `forfeit_slot`) / Wait.
- Debug keys moved to F5-F9, debug builds only (R collided with KB2 Bomb).
- Remap: 2 bindings per action per class, swap on conflict, last binding protected, reserved keys list.
- Project rule file "use delta" was not followed: the brief and ADR-0001 mandate integer ticks.

## 3. Amendments
1. `design/gdd/systems-index.md` row 2 status: `**Designed** (pending review) — [GDD](input-and-player-mapping.md)`; Depends on stays `1`; tracker GDDs written 8, "Code exists without GDD" 3.
2. `player-plane.md`: Dependencies Input row (GDD exists, `pN_drone` final); Rule 9 wording (SlotInput snapshot); Interactions Input row (deadzone values stored in `data/input/input_rules.tres`); Rule 10 add "plane calls `clear_buffer(slot)` every non-Active tick"; AC-20 replace with "SlotInput exposes move, fire, drone, bomb, start, back; no `ability` id"; Open Question 5 resolved; edge case "pad disconnects mid-flight" -> game pauses first.
3. `game-events-and-session.md`: add transition Alive/Dead/Continue/Selecting -> Inactive on `forfeit_slot(slot)` (fires `player_slot_inactive`); Interactions Input row; Open Question 2 resolved; Rule 7 slot choice = Input F7.
4. `adr-0001...md` tick diagram step 1: `InputSampler snapshot (autoload, ALWAYS, ticked before GameLoop)`.
5. `game-concept.md` section 5: optional Start/Back note.
6. GDDs 11, 12, 18, 20, 22, 26, 28, 31 must list Input in Dependencies.

## 4. Registry candidates
```yaml
  - name: max_players
    value: 4
    unit: slots
    source: design/gdd/input-and-player-mapping.md (Rule 1)
    referenced_by: [input-and-player-mapping, game-events-and-session, player-plane]
  - name: dz_enter
    value: 0.30
    unit: stick magnitude
    range: "0.15-0.50"
    source: design/gdd/input-and-player-mapping.md (Rule 15)
    referenced_by: [input-and-player-mapping, player-plane]
  - name: dz_exit
    value: 0.20
    unit: stick magnitude
    range: "0.10-dz_enter"
    source: design/gdd/input-and-player-mapping.md (Rule 15)
    referenced_by: [input-and-player-mapping, player-plane]
  - name: sector_hyst
    value: 4
    unit: degrees
    range: "0-8"
    source: design/gdd/input-and-player-mapping.md (Rule 15)
    referenced_by: [input-and-player-mapping, player-plane]
  - name: buffer_ticks
    value: 6
    unit: ticks (0.1 s), Drone and Bomb only
    range: "0-12"
    source: design/gdd/input-and-player-mapping.md (Rule 17, F6)
    referenced_by: [input-and-player-mapping]
formulas:
  - name: press_edge
    expression: "held = down_now OR latch_press; pressed = held AND NOT held_prev; released = NOT held AND held_prev; held_ticks = held ? prev+1 : 0"
    variables: [down_now, latch_press, held_prev, held_ticks]
    output: "pressed/released true for exactly one tick; sub-tick tap -> pressed T, released T+1"
    source: design/gdd/input-and-player-mapping.md (F1)
    referenced_by: [input-and-player-mapping, player-plane]
```
Existing entries: none need `input-and-player-mapping` added.

## 5. Conflicts
- Existing `input_setup.gd`: action deadzone 0.2 and `Input.get_vector` analog movement contradict Player plane PF2 (0.30/0.20, 8-way digital); `pN_ability` vs `pN_drone`; debug key R collides with KB2 Bomb.
- Player plane AC-20 (checks `InputMap` actions) conflicts with removing `pN_*` registrations; amended.
- Player plane edge case "pad disconnect: plane stops, stays hittable" superseded by auto-pause.
- ADR-0001 step 1 wording (see Amendments).
- No locked registry value contradicted.

## 6. Open risks
- Godot 4.7 Web gamepad support is unverified (GUID, `get_joy_name`, connection events); AC-55 is the check.
- Nintendo positional button mapping in 4.7 unverified.
- Bengali strings are drafts needing native review.
- Keyboard ghosting for 2P on one keyboard.
- Tap Assist depends on a kit charge threshold that Plane kits (11) has not set (18 ticks assumed).
- `forfeit_slot` is a new Session contract.
- Sampler-as-autoload vs GameLoop ownership needs an ADR note.
- `qa-lead`/specialists not consulted; ACs were drafted solo.
