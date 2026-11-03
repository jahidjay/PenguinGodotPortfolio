# UX Spec: Lobby (Plane Select + Co-op Join)

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring, pending `/ux-review`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Journey Phase(s)**: First run, co-op night, every run start (see `design/player-journey.md`)
> **Platform Target**: PC (Steam/itch), Web, iOS, Android, Switch. Gamepad primary, keyboard first-class (KB1 + KB2 on one keyboard), touch partial (solo), pointer cannot fly
> **Template**: UX Spec
> **Sources**: `design/gdd/menus-title-plane-select.md` (Rules 9, 18-26, 51 stall/commit; F2, F3, F7, F8; V/A table and mock-up; AC-10..25; edge cases), `input-and-player-mapping.md` (Rules 1-6, 28), `touch-controls.md`, `tutorial.md` (SCHOOL mode), `accessibility-options.md`, art bible 2, 7.8. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P02, P05, P07, P08, P09, P11, P14, P21, P23 (see `interaction-patterns.md`)
> **Style**: `arcade-ui-style.md`
> **Revision 2026-11-03**: fixes from `/ux-review` (removed invented touch Confirm plate, `untimed_menus` per Accessibility GDD, platform target, measured layout, resolution AC, null handling)

---

## Purpose & Player Need

The player arrives wanting to **pick a plane and start flying**, and a friend who grabs a pad should be **in the game the moment they press Start**. The Lobby makes each plane's identity legible before commitment (a spear or a leash), shows all four co-op slots at all times so co-op is discoverable, and hands off to the stage after a short, cancellable countdown. It never decides gameplay rules.

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| From Title, pad/keyboard Confirm | Eager | Their device is already P1 (slot 0 Choosing): no extra press |
| From Title, pointer click | Slightly lost | All slots Empty, hint "Press START on a controller or keyboard" |
| From Title, touch tap | Eager | TOUCH bound to slot 0, solo only |
| From Board "Play again" | Wants "one more go" | The pressing device is bound to slot 0; cursor starts on the last plane |
| Stage-load failure | Annoyed | Lobby re-opens with everyone Locked and an error toast |

Arrival is voluntary. There is no time pressure except stall timers (30 s / 60 s).

## Navigation Position

`Title -> **LOBBY** -> Stage`. At Stretch: `Title -> Play choice -> (Boss select) -> LOBBY -> Stage`. At Target also a Flight School `SCHOOL` mode entry (from the school list). Lobby is context-dependent (only reachable from Title, Board and the mode lists). The Lobby is **per-slot**, not shared: each slot is controlled only by its own device.

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Title (START GAME) | Pad/keyboard Confirm | Device bound to slot 0, slot 0 Choosing |
| Title (START GAME) | Pointer click | No devices bound; all Empty |
| Title (START GAME) | Touch tap | TOUCH bound to slot 0 |
| Play choice / Boss select | Item activate | `mode` (MAIN / RUSH / BOSS / SCHOOL) and its stage list |
| Board | Play again | Pressing device bound to slot 0; devices that disconnected leave their slot Empty + toast |
| Stage load failure | After commit | Every slot Locked; error toast; no Session started |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Stage (InRun) | Commit: `ready_ticks >= 45` | `start_run(selections, mode, stage_list)` called **once**, selections in slot order; `profile.last_plane` written at commit |
| Title | Last joined slot cancels | |
| Title | 60 s with no input from any joined slot | Warning bar in the last 10 s |
| Title | A Locked/only slot's pad disconnects (joined becomes 0) | With toast |

---

## Layout Specification

### Information Hierarchy

1. **Which plane am I on, and is it locked?** (my cursor, my READY stamp)
2. **What does this plane do?** (name, tagline, playstyle tag, Fire / Hold / Drone rows)
3. **Who else is here and where?** (four slot columns; rim light on cards)
4. **Is the game about to start?** (commit bar, "Starting")
5. **How do I act?** (prompt bar glyphs for the current device)
6. Transient: toasts ("Game full", "P{n} left"), idle-warning bar.

### Layout Zones

Canvas 360x640 (from Menus V/A table). All y values are nominal at text step 0; Menus Rule 51 lays out from measured text (cards switch to a 2-row trait layout at larger steps).

| Zone | y range | Contents |
|---|---|---|
| Header | 16 | `menu.select.heading` "CHOOSE YOUR PLANE" (S/M tier) |
| Plane cards | 72-368 | One card per available plane; `card_w` x 296, side margin 16, gap 8 |
| Slot columns | 392-512 | 4 x 90 px: frame in ring pattern, 3 px colour notch left, pips top |
| Commit bar | 520 | 4-segment bar, only while `ready` |
| Toast | 560 | 328x24 strip |
| Prompt bar | 600-640 | Glyph + verb pairs for the active device |

`card_w`: 2 planes = 160 (x origins 16 and 184), 3 planes = 104, 4 planes = 76 (more than 4 scrolls horizontally, Target). Rim light is split per F8 into equal segments (160 -> 1: [160]; 3: [54, 53, 53]; 4: [40, 40, 40, 40]).

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|
| Header | Text | No | P23 | Single-language per language setting |
| Plane card | Card | Via slot cursors | P07 | Pedestal + pilot idle animation (top 120 px), name (M), tagline (S), playstyle tag plate, 3 trait rows (Fire / Hold / Drone, glyph 14x14 + max 2 lines) |
| Cursor token | Marker | Yes (own slot) | P07, P08 | Slot colour + ring pattern + pips; on the card the player hovers |
| Rim light | Feedback | No | P08 | 3 px warm rim, split per slot colour with pattern ticks at segment boundaries |
| Slot column (x4) | Panel | Yes (own slot) | P08, P09 | Frame pattern, colour notch, pips; contents depend on state |
| Join plate | Panel | Via Start | P09 | "Press START to join" with the slot's ring pattern and pips |
| READY stamp | Stamp | No | P09 | Plated tile: text "READY" + check glyph + ring-pattern frame |
| Commit bar | Progress | No | — | 4 segments; shows `ready_ticks` progress; label "Starting" |
| Idle warning bar | Feedback | No | P14 | "Returning to title" in the last 600 ticks |
| Toast strip | Feedback | No | P11 | "Game full", "P{n} left", "P{n} controller disconnected", error on load fail |
| Pointer hint line | Text | No | — | "Press START on a controller or keyboard" (only when no slot is joined) |
| Back plate | Button | Pointer/touch | P05, P06 | At least 24x24; pointer/touch only |
| Prompt bar | Info | No | — | Per device family |

### ASCII Wireframe

2 planes (MVP: Lancer, Leech); P1 Locked on Lancer, P2 Choosing on Leech, P3/P4 Empty:

```
+----------------------------------------------------------+ y0
|              CHOOSE YOUR PLANE                           | y16
|  +--------------------------+ +--------------------------+| y72
|  |#### P1 rim ####   LANCER | |== P2 rim ==      LEECH   ||
|  |   [ pedestal + plane ]   | |   [ pedestal + plane ]   ||
|  |   [ pilot idle       ]   | |   [ pilot idle       ]   ||
|  |  "I am the spear."       | |  "Nothing gets away."    ||
|  |  [BURST AND HOLD]        | |  [LATCH AND SUSTAIN]     ||
|  |  [A]      Wide 3-way     | |  [A]      Narrow 2-way   ||
|  |  [A hold] Laser: safe    | |  [A hold] Focus: strong  ||
|  |  [X]  Drones park + laser| |  [X]  Drones latch on    ||
|  +--------------------------+ +--------------------------+| y368
|                                                          |
| +--P1 solid,1 pip--+ +--P2 dashed,2--+ +--P3---+ +--P4---+ | y392-512
| | LANCER [READY v ]| |   < LEECH >   | | Press | | Press | |
| |                  | |               | | START | | START | |
| +------------------+ +---------------+ +-------+ +-------+ |
|  [ #### Starting ####                    ]               | y520 (only while ready)
| [toast strip]                                            | y560
| [A] Lock   [B] Back                                      | y600
+----------------------------------------------------------+ y640
```

---

## States & Variants

**Slot states** (per slot):

| State | Meaning | Visible | Next |
|---|---|---|---|
| Empty | No device | Join plate "Press START to join" | Choosing (Start press by a free device) |
| Choosing | Cursor on a plane | Cursor token + `< PLANE >` in the column; rim segment on hovered card | Locked (Confirm) / Empty (Cancel, AFK release, disconnect) |
| Locked | Plane chosen | READY stamp (text + check + frame) | Choosing (Cancel) |

**Whole Lobby:**

| State | Trigger | What changes |
|---|---|---|
| Open | Default | |
| Counting | `ready = joined >= 1 AND locked == joined` | Commit bar fills over 45 ticks; any change resets it to Open |
| Committed | `ready_ticks >= 45` | `start_run` called once; stage load starts |
| Closed | Last cancel / idle / pad loss | Back to Title |
| Idle warning | No input from joined slots for 3,000 ticks | "Returning to title" bar until 3,600 |
| No joined slot (pointer arrival) | Pointer opened the Lobby | Hint line "Press START on a controller or keyboard"; all slots Empty |
| Game full | A fifth device presses Start | Toast "Game full"; no state change |
| Load failure | Stage fails to load after commit | All slots Locked, error toast; countdown restarts on the next valid change |
| Touch | TOUCH bound | Solo only; slots 1-3 show a note; other devices' Start is ignored with the "Touch play is solo only" toast |
| 3 or 4 planes | More planes available | Cards narrow to 104 / 76 px; trait rows must fit (Open Question 1) |
| Larger text step | `font_size_px` raised | Plane cards switch to a 2-row trait layout; nothing clipped |
| SCHOOL mode | Entered from Flight School | Same layout; mode label (Target) |
| Unavailable plane | `available = false` | Not listed |

---

## Interaction Map

Gamepad primary (full), keyboard (KB1/KB2), touch (partial), pointer. Verbs only.

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Join plate | Join | Start on a free pad | KB1 Enter, KB2 `1` | Cannot join (pointer). Touch binds at Title | Plate becomes Choosing token; join cue | Lowest Empty slot, else lowest Inactive slot with a disconnected device, else "Game full" |
| Cursor | Move | D-pad left/right (own slot only) | Own scheme's left/right | Tap a card | Token moves, rim updates | Wraps; per-slot |
| Plane | Lock | Fire / Start (own slot) | Own scheme's confirm (KB1 Z/Space/Enter; KB2 F/1) | Touch: tap a card to move the cursor; how a touch player locks is **not specified in any GDD** (Open Question 2). Pointer: cannot lock (no bound slot) | READY stamp drops in 4 steps over 8 frames, no flash | Slot Locked; counter evaluates |
| Locked slot | Unlock | Bomb / Back | KB1 C/Esc; KB2 R/2 | Back plate (24x24 min) | Stamp removed | Locked -> Choosing |
| Choosing slot | Leave | Bomb / Back | KB1 C/Esc; KB2 R/2 | Back plate | Column returns to join plate; device released | Choosing -> Empty. If the last joined slot leaves: Title |
| Lobby | Start run | (automatic) | | | Commit bar | After 45 ticks of `ready` |
| Any joined slot | Idle | No input | | | AFK release toast "P{n} left"; idle warning bar | See states |

Notes:
- Events carry the slot index; one slot's Nav never moves another's cursor (AC-10).
- A device that already owns a slot pressing Start acts as Confirm for that slot (no second join).
- Two slots may pick the same plane.
- Pointer/touch targets follow Touch TF7 (9 mm; 55 canvas px at x3 / 458 dpi) with a touch row pitch. Plane cards are large enough on 2 planes; see Open Question 3 for 4.

## Events Fired

| Player Action | Event / Call | Payload | Persistent? |
|---|---|---|---|
| Start press (free device) | Join request -> Session creates Selecting slot | slot, device | No (binding is session-only) |
| Confirm (lock) | Slot Locked | slot, plane id | No |
| Cancel (unlock / leave) | Slot state change; device released if Empty | slot | No |
| Commit | `GameSession.start_run(selections, mode, stage_list)` once | [(slot, plane, device)...], mode, stage list | **Yes**: writes `profile.last_plane[slot]` (new Save key proposed) |
| AFK release | Slot -> Empty + toast | slot | No |
| Pad disconnect | Slot -> Empty + toast | slot | No |
| Idle exit | Open Title | — | No |
| Fifth device Start | Toast | — | No |

Analytics events: none defined. Persistent write at commit (`last_plane`) goes through Save; flag for architecture.

## Transitions & Animations

- **Enter / exit:** 4-step Char wipe over 12 frames, no white (art bible 7.8). Reduce-motion: cut.
- **Join:** join plate swaps to Choosing token in one frame, join cue.
- **READY stamp:** plated tile drops in 4 steps over 8 frames; no flash, no pulse.
- **Cursor move:** snap with stepped easing (3-4 positions); rim light re-splits instantly.
- **Commit bar:** 4 segments fill across 45 ticks; clears at once on any reset.
- **Pilot idle animation:** loops on the pedestal; holds frame 0 under `reduce_motion`.
- **Toast:** 8 frames in/out, 90-tick hold.
- Focus/cursor pulse: <= 40% opacity, <= 2 Hz, one element, off under `reduce_pulsing`.

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Plane cards (id, name key, tagline, tag, trait keys, `available`) | `data/menus/plane_cards.tres` / Plane kits (11) | Read | MVP Lancer, Leech; Sentry/Breaker at Target |
| Slot states, device bindings | Session (1) / Input (2) | Read | Empty / Choosing(Selecting) / Locked |
| `profile.last_plane[slot]` | Save (26) | Read/Write | Initial cursor; written at commit |
| Slot colour, ring pattern, pips | Co-op (18) / Accessibility palette | Read | `access.player_palette` swaps colours only |
| Mode and stage list | Menus / Online (32) / Tutorial (30) | Read | MAIN, RUSH, BOSS, SCHOOL |
| Device glyph family | Input (2) | Read | Prompt bar |
| Timers (45 / 1,800 / 3,600 / 600 ticks) | Menus tuning knobs | Read | |
| Strings | Localization (27) | Read | `menu.select.*`, `plane.<id>.*` |

Update triggers: slot states and cursors every tick (`LobbyModel.tick()`); cards and `last_plane` once on open; glyphs on last input. Null handling: no `last_plane` -> first listed plane; a card with a missing string key fails the menu lint (Menus AC-08), never shows a raw key; zero available planes cannot happen (lint).

## Accessibility

- **Gamepad path:** Start joins; D-pad left/right picks; Fire locks; Bomb/Back cancels. No mode needs a second device.
- **Keyboard path:** each scheme (KB1, KB2) has its own join, move, confirm and cancel keys; two players can share one keyboard (ghosting caveat in Input Rule 22).
- **Colour-independent:** slot identity = colour + ring pattern + pips + "P{n}"; READY = text + check glyph + frame pattern; the two equal-luma slots (P3, P4) are distinguishable in greyscale by pattern (AC-25). `LUMA_SPREAD` palette available.
- **Contrast:** Cream text with 1 px outline on Cabinet Char plates; high-contrast option available.
- **Motion:** stamp drop, pilot idle, wipe and pulse honour `reduce_motion` / `reduce_pulsing` / `reduce_flashing`.
- **Timing:** with `access.untimed_menus` on, the Lobby idle-close (60 s) is **off** and the drop-in pick timeout is doubled (Accessibility GDD option table). The 30 s AFK release is not mentioned there; it only fires while another slot is Locked (Open Question 4).
- **Unsighted players:** no screen-reader stance exists (pattern library gap 7).

## Localization Considerations

- Plane card trait rows are limited to 2 lines (3 in Bengali). On a 76 px wide card (4 planes) this will not fit: **HIGH PRIORITY** (Open Question 1).
- Playstyle tags ("BURST AND HOLD", "LATCH AND SUSTAIN") and taglines are the longest strings on a 160 px card; reserve +40% width.
- "Press START to join" must fit a 90 px column in both languages; Bengali is likely to wrap to 3 lines (**HIGH PRIORITY**).
- "P{n} left" and "Returning to title" toast/bar strings: dynamic `{n}` stays Latin ("P1"-"P4").
- Bengali card strings are drafts needing native review (Menus Open Question 7).
- Header is single-language per setting; card text uses the Bengali-capable font at the S/M tiers.

---

## Acceptance Criteria

- [ ] The Lobby opens within 1 s of Confirm on START GAME (*proposed target*) and shows four slot columns even with one player.
- [ ] At 360x640 x1 and x3, with 2 planes, both cards (160 px) and all four 90 px slot columns are fully visible with no overlap, and the commit bar, toast and prompt bar do not overlap each other.
- [ ] Pad Confirm on Title opens the Lobby with that pad as P1 in Choosing; mouse click opens it with all four slots Empty and the hint line.
- [ ] Slot 0 and slot 1 are both Choosing: slot 1 pressing right moves only slot 1's cursor; slot 0's is unchanged; the cursor wraps.
- [ ] A free pad pressing Start joins the lowest Empty slot; a fifth device shows "Game full" with no state change.
- [ ] Both players lock: the run starts exactly once, 45 ticks (0.75 s) later; if P2 unlocks and relocks in between, the start is delayed accordingly.
- [ ] A third player joining during the countdown cancels it; the first two READY stamps remain.
- [ ] Two players can lock the same plane and the run starts with both.
- [ ] A Choosing slot with no input for 30 s while another slot is Locked is released with the toast "P{n} left"; with nobody Locked it is never released.
- [ ] With no input from any joined slot, the "Returning to title" bar appears at 50 s and the Lobby closes to Title at 60 s; any input before that resets it.
- [ ] The last joined slot pressing Cancel returns to Title; one of two cancelling keeps the Lobby open.
- [ ] A Locked player's pad disconnect empties that slot, resets the countdown and shows a toast, without pausing.
- [ ] A joining slot's cursor starts on its last locked plane (or the first plane if none).
- [ ] All four slots are distinguishable in a greyscale screenshot by ring pattern and pip count alone.
- [ ] Five testers viewing each card for 10 s: at least 4 of 5 can state that Lancer's hold-Fire makes it invulnerable and that Leech's drones latch onto enemies.
- [ ] With `reduce_motion` and `reduce_pulsing` on, no element pulses and the READY stamp appears without animation.
- [ ] At the largest text step, no card text is clipped and the cards use the 2-row trait layout.

---

## Open Questions

1. **4-plane card width.** With Sentry and Breaker available at Target, `card_w` is 76 px. A 14x14 glyph plus text on 3 trait rows, a tagline and a style tag will not fit in 76 px, especially in Bengali. Needs a rule (horizontal scroll, two cards visible at a time, or a compact card). The Menus GDD only says "scrolls with more than four planes".
2. **Touch Lobby.** TOUCH is solo, but the Lobby shows four columns with join plates that the touch player cannot use. **Proposal (needs a Menus/Touch amendment):** on touch, slots 1-3 show a dim "Pads only" plate; tapping a card moves the cursor, tapping the focused card again locks it, and a Back plate (TF7 size) unlocks/leaves. The strip's Hold button could also act as Confirm.
3. **Card tap target on 4 planes** (76 px wide) is below 9 mm on some phones only if TF7 is applied to width; confirm whether cards count as touch targets or the Confirm plate does.
4. **Untimed menus.** The Accessibility GDD turns the Lobby idle-close off under `access.untimed_menus` (answered). Still open: should it also disable the 30 s AFK release? Recommend yes (an untimed player is never removed by a timer).
5. **Pointer arrival** (hint line only) means a mouse-only player on PC cannot play; confirm that is intended (Input: a pointer cannot be a flying device) and that a Web user without a pad/keyboard sees the keyboard Enter/1 hint.
6. **Mode label.** There is no on-screen indication of mode (MAIN / BOSS RUSH / SINGLE BOSS / SCHOOL) in the Lobby layout; add a header sub-line at Stretch/Target?
7. **Rim light with 4 hovering slots on one card** produces four 40 px segments plus pattern ticks; legibility to be checked with art-director.
8. The `profile.last_plane` Save key is only **proposed** (Menus Amendments); needs Save GDD confirmation.
9. ~~Journey map / accessibility tier missing~~ **Closed 2026-11-03:** `design/player-journey.md`; tier Comprehensive (`design/accessibility-requirements.md`).
10. Lobby re-open after a failed stage load has an unspecified recovery after repeated failures (loop?).
