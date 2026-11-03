# Interaction Pattern Library

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring, pending `/ux-review`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Template**: Interaction Pattern Library
> **Platform Target**: PC (Steam/itch), Web, iOS, Android, Switch. Gamepad primary, keyboard first-class, touch partial
> **Style**: `arcade-ui-style.md` - the **canonical owner** of the tokens, the bilingual rules and the cross-screen **animation (section 4)** and **sound (section 5)** standards. This library **cites** those tables per pattern and restates neither; `design/gdd/audio.md` owns the sound **ids**.
> **Revision 2026-11-03**: fixes from `/ux-review`: P17 corrected (per-column skip), P04 accessibility variants and Fire-only hold on Pause, new P25-P28, Animation and Sound Standards, Back behaviour table, gaps updated.
> **Revision 2026-11-03 (final doc closeout)**: every UI cue id rewritten to the canonical **`sfx_ui_*`** form (consistency-report C1, `design/gdd/audio.md` owns the ids); P29 now offers the Alarm Flare `#F2494D` headline option (art bible 4.1, style guide 3.1 rule 3).
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: P04 now states the hold verb once and for all - **Fire only on every screen**, Start never holds anywhere, and the hold length is `confirm_hold` even for a menu item that mirrors a real-time hotkey.
> **Revision 2026-11-03 (UX amendments wave 5)**: added **P29 Status block** (empty / loading / error block), **P30 Single-button modal over a stopped field** (Coach card) and **P31 Controller-lost plate with DROP**; P15 and P26 extended; Gaps 4, 6 and 8 closed; Animation Standards carry the join-plate range; the ownership of the animation and sound standards is stated once (they live in `arcade-ui-style.md` sections 4 and 5; `design/gdd/audio.md` owns the sound ids) and cited per pattern rather than restated.
> **Sources**: `menus-title-plane-select.md` (Rules 12-17, 20-30), `input-and-player-mapping.md` (Rules 1-7, 13, 19-20), `touch-controls.md` (Rules 1-22), `accessibility-options.md` (Rules 5-17), `stage-end-tally.md`, `hud.md`. Where this file and a GDD disagree, the GDD wins; fix this file.

---

## Overview

MorutJan is gamepad-first, 1-4 local players, bilingual (Bengali + English), drawn inside a fixed 360x640 canvas. Every screen spec (`design/ux/*.md`) must reuse the patterns below by name instead of inventing its own. A screen that needs behaviour not listed here adds a row to **Gaps** first.

**Global rules that apply to every pattern**

| # | Rule | Source |
|---|---|---|
| G1 | Menus use Input verbs only: **Nav** (4-way, repeat 18/6 ticks), **Confirm** (`fire` or `start`), **Cancel** (`bomb` or `back`). Raw keys only in name entry. | Menus R12 |
| G2 | Nothing depends on hover. Hover may move focus but never activates. | Menus R14, tech prefs |
| G3 | Nothing is colour-only. Slot identity = colour + ring pattern + pip count, plus "P{n}" text on menus (the in-play HUD uses pattern + pips without text, HUD Rule 8). | Access R17, art bible 4.4 |
| G4 | Everything fits inside 360x640. Reserve +40% text width for Bengali/English swaps. | Menus R2, Loc |
| G5 | Min touch target: visual 9 mm, hit 12 mm on gameplay buttons; 24x24 canvas px for menu steppers/sliders/Back. | Touch R7, Menus R14 |
| G6 | Input events carry a slot index. A menu is either *shared* (any device, last input wins) or *owned* (one slot). | Input R7, Menus R8, R27 |
| G7 | An input that leaves a gate/idle screen is consumed; it never also acts as Confirm. | Menus R5, R11 |
| G8 | All timers are integer ticks at 60 Hz. | ADR-0001 |

---

## Pattern Catalog

| ID | Pattern | Category | Used in |
|---|---|---|---|
| P01 | Focus list | Navigation | Title, Pause, Settings, Scores, Play choice |
| P02 | Focus indicator | Feedback | Every focusable element |
| P03 | Item kinds (Button, Link, Toggle, Stepper, Choice, Info) | Input | Title, Settings |
| P04 | Hold-to-confirm | Input | Quit to title, Skip drill |
| P05 | Cancel goes up, never out | Navigation | Every sub-screen |
| P06 | Pointer parity | Input | Title, Settings, Scores (Web/PC/touch) |
| P07 | Per-slot cursor | Navigation | Lobby, Drop-in pick, Name entry |
| P08 | Slot identity badge | Data Display | Lobby, HUD, Pause, Tally, Results |
| P09 | Join / ready-up | Input | Lobby, Drop-in |
| P10 | Owner-only modal | Modal | Pause, Disconnect overlay |
| P11 | Toast strip | Feedback | Title, Lobby, Settings, Save |
| P12 | Confirm countdown (safe default) | Modal | TATE confirm |
| P13 | Resume beat | Feedback | After Pause |
| P14 | Idle / attract timeout | Feedback | Title, Lobby |
| P15 | Name wheel | Input | Name entry |
| P16 | Tab + filter list | Data Display | High scores, Records |
| P17 | Tally count-up with skip | Data Display | Stage-end tally |
| P18 | HUD plate (per-slot column) | Data Display | HUD |
| P19 | Touch button strip | Input | Stage, Pause (touch only) |
| P20 | Drag-to-move | Input | Stage (touch only) |
| P21 | Accessibility-aware motion | Feedback | Every animated element |
| P22 | Platform-gated item | Navigation | Title (QUIT), Settings |
| P23 | Bilingual text block | Data Display | Title, banners, names |
| P24 | Web gate | Navigation | Boot (Web only) |
| P25 | Yes / No dialog (safe default) | Modal | Quit game (PC/Switch), first-run photosensitivity plate |
| P26 | Scrolling list and touch row pitch | Navigation | Boss select, High scores, Settings, Credits, touch menus |
| P27 | Stepped progress bar | Feedback | Commit bar, hold bar, countdowns, chain window, boss HP |
| P28 | Rebind control (listen for input) | Input | Settings > Controls (full spec in `settings.md`) |
| P29 | Status block (empty / loading / error) | Feedback | High scores (Online), Save notices, any list that can be empty or fail |
| P30 | Single-button modal over a stopped field | Modal | Flight School Coach card |
| P31 | Controller-lost plate with DROP | Modal | Name entry under `access.untimed_menus` |

---

## Patterns

### P01 Focus list

**Category**: Navigation
**Used In**: Title, Play choice, Pause, Settings, High scores, Credits

**Description**: A vertical list with exactly one focused item per navigating owner. The default focus is the safest forward action (START GAME, RESUME).

**Specification**:
- Nav up/down moves focus; moving past either end **wraps**; disabled items are skipped. Hold repeats at 18 ticks first, then every 6.
- Left/right changes STEPPER and CHOICE items, and does nothing on other kinds.
- Focus is restored to the opening item when returning from a sub-screen (P05).
- Shared screens (Title, Scores, Settings from Title, Credits): any connected device may navigate; last input wins. Owned screens: see P10.
- Accessibility: focus order follows visual order; no focus traps.

**When to Use**: Any list of 2+ actions. **When NOT to Use**: Plane selection (use P07) and name entry (use P15).

### P02 Focus indicator

**Category**: Feedback

**Specification**:
- 3 px Cream border plus an arrow glyph offset 2-3 px. Never hue alone.
- Optional pulse: opacity swing 40% or less, 2 Hz or less, one element at a time. Off when `reduce_pulsing` is on (steady).
- High-contrast HUD option swaps plate edges to Cream `#F4EBD6` and dim text to `#A89E8A`.

**When NOT to Use**: Never replace with hover-only highlight.

### P03 Item kinds

**Category**: Input

| Kind | Confirm does | Left/Right does | Notes |
|---|---|---|---|
| BUTTON | Runs the action | none | |
| LINK | Opens a screen (P05 applies) | none | |
| TOGGLE | Flips value | Flips value | Value text + glyph, not colour |
| STEPPER | none | +/- one integer step (e.g. volume 0-10) | Each step is a 24x24 px click target |
| CHOICE | none | Cycles a string set | Shows current value in text |
| HOLD_BUTTON | Starts hold (P04) | none | |
| INFO | none | none | Read-only; skipped by focus |

Settings changes apply live (no Apply button).

### P04 Hold-to-confirm

**Category**: Input
**Used In**: Quit to title (Pause), Skip drill (Flight School)

**Description**: Destructive or irreversible actions need a held Confirm instead of a second dialog. Used for: Quit to title, Skip drill, Drop P{n}, Reset settings, Clear scores, Reset display.

**Specification**:
- Hold **Fire** (Confirm) for `hold_confirm_ticks` (60 = 1 s). A 4-segment bar (P27) beside the item grows with the hold; releasing early resets it.
- **Fire only, everywhere.** *(Amended 2026-11-03, wave 5 batch 2, from `settings.md` and `pause.md`.)* **Start never starts, advances or completes a hold on any screen** - not only on Pause and the disconnect overlay. Start keeps whatever other meaning that screen gives it (resume on Pause, Confirm / resume in Credits, Pause in-stage), and a screen on which Start has another meaning simply ignores it for holds. **Settings opened from Pause ignores Start altogether** (Menus Rule 43). Menus F6 counts `fire.held_ticks` only.
- **Hold length is `confirm_hold`**, not a wall-clock value: 60 ticks at NORMAL, 40 SHORT, 90 LONG. A menu item that mirrors a real-time hotkey ("Reset display" versus the 2 s `display_reset`) still uses `confirm_hold` for its own hold (Menus Rule 43, Display UI table).
- Accessibility: `access.confirm_hold` sets the length (SHORT 40 / NORMAL 60 / LONG 90 ticks); `access.confirm_style` DOUBLE_TAP replaces the hold with two presses within 120 ticks ("Press again" shown after the first; a press elsewhere cancels).
- The consequence is written beside the item: "Score will not be saved" (menu.pause.quit_warn).
- No second dialog. Completing the hold performs the action (`GameSession.abandon_run()`).
- Pointer: press-and-hold the item; touch likewise.
- Reduce-motion: the fill bar still fills (it is functional, not decorative).

**When NOT to Use**: Reversible actions (use plain BUTTON).

### P05 Cancel goes up, never out

**Category**: Navigation

**Specification**:
- Cancel (`bomb` / `back` / Esc / C) returns to the parent screen with focus restored on the opener.
- Cancel on Title does nothing. Cancel never discards: settings are live.
- Pointer/touch: a visible **Back plate** of at least 24x24 px.
- Exception: in Lobby, Cancel steps a slot Locked -> Choosing -> Empty (P09).

### P06 Pointer parity

**Category**: Input

**Specification**:
- Click/tap on an item focuses and activates in one action.
- Mouse hover may move focus but never activates; no state exists only on hover.
- Wheel scrolls lists. Pointer positions arrive already in canvas space.
- A pointer cannot be a flying device and cannot join a slot (it opens the Lobby with all slots Empty). Exception: TOUCH binds to slot 0 on a touch platform (P19).

### P07 Per-slot cursor

**Category**: Navigation
**Used In**: Lobby plane cards, Drop-in pick

**Specification**:
- Each Choosing slot owns a cursor moved only by that slot's Nav. Left/right wraps.
- Two slots may pick the same plane. The card rim light shows every hovering/locked slot colour as equal segments; each cursor token also carries its ring pattern and pips (G3).
- A joining slot starts on its last locked plane or the first listed plane.

### P08 Slot identity badge

**Category**: Data Display

**Specification**:
- Four fixed identities: P1 solid ring, P2 dashed, P3 dotted, P4 double; pips 1-4; slot colour; text "P{n}" on menus, Pause, Tally and Results (not on the in-play HUD, HUD Rule 8).
- Colour is swappable via `access.player_palette` (LUMA_SPREAD); ring pattern, pips and text are never switchable.
- Appears on: HUD column frame and notch, Lobby rim and cursor, Pause owner tag, Tally column, Results rows, chain bar near plane.

### P09 Join / ready-up

**Category**: Input
**Used In**: Lobby, Drop-in pick, Continue prompt (HUD-hosted)

**Specification**:
- Slot states: Empty -> (Start press) Choosing -> (Confirm) Locked (READY stamp: text + check glyph + ring-pattern frame) -> (Cancel) Choosing -> (Cancel) Empty.
- **Lobby:** every Empty slot shows the text plate "Press START to join", so co-op is discoverable even when solo.
- **In play (HUD Rule 23):** the join plate is icon-only (START glyph + pips), steady and text-free; 1P shows one plate for the next free slot; **2P shows none** (no room); 3-4P empty columns show it.
- **Lobby plate pulse:** 1 Hz opacity step, **100% <-> 60%** (a 40-point swing, art bible 7.7; `arcade-ui-style.md` section 4 is the canonical row). Steady under `reduce_pulsing`. The in-play HUD plate never pulses.
- Commit when `joined >= 1 AND locked == joined`, after a 45-tick start delay; any change (unlock, cancel, new join, disconnect) resets the countdown.
- A fifth device pressing Start gets the toast "Game full" (P11).
- Drop-in pick during a run is drawn inside the empty slot's HUD column, never over the play field; auto-cancels after 900 ticks; the slot is non-hittable while selecting.
- Stall protection: a Choosing slot idle 1,800 ticks while another slot is Locked is released with toast "P{n} left"; all-idle 3,600 ticks returns to Title with a warning bar in the last 600.

### P10 Owner-only modal

**Category**: Modal
**Used In**: Pause, Disconnect overlay

**Specification**:
- Start or Back from any bound slot during Stage/Tally opens the modal; that slot is the **owner**.
- Shows an owner tag (P08). Only the owner's Nav/Confirm are accepted; other slots' presses are ignored and their tags dimmed.
- If the owner's device disconnects, ownership passes to the lowest connected bound slot.
- Pause items: Resume (default focus), Settings, Quit to title (P04). Cancel or Start resumes.
- Disconnect overlay: one row per Waiting slot with Reconnect / Use keyboard / Drop / Wait.
- Opens over a paused game; the playfield stays visible but frozen.

### P11 Toast strip

**Category**: Feedback

**Specification**:
- One plated strip at a time, 90 ticks long, slide in/out over 8 frames. Queue of 3; extras drop oldest first, except Save notices which are never dropped.
- Uses: "Game full", "Controllers recommended", Save notices, "P{n} left", "P{n} controller disconnected", "Touch play is solo only".
- Never contains the only copy of critical information: toasts are advisory.
- Reduce-motion: strip appears without slide.

### P12 Confirm countdown with safe default

**Category**: Modal
**Used In**: TATE (rotated display) confirm

**Specification**:
- Countdown shown as number + bar. Default focus is the safe option (Cancel/revert). Keep requires an explicit Confirm. Timeout reverts.
- TATE confirm uses the UI tick sound.

### P13 Resume beat

**Category**: Feedback

**Specification**:
- After the owner resumes, a three-pip beat runs for 45 ticks with the tree still paused; then the game runs and Input re-arms held buttons. Always runs after any pause reason. 0 disables.
- No invulnerability is granted (Collision owns that).

### P14 Idle / attract timeout

**Category**: Feedback

**Specification**:
- Title: after 1,800 ticks (30 s) without input, the menu list hides and the backdrop cycles the four era palettes every 1,200 ticks with logo and hi-score. Any input returns and **is consumed** (G7).
- Lobby: warning bar in the last 600 ticks before returning to Title.

### P15 Name wheel

**Category**: Input
**Used In**: Name entry (ranked runs only)

**Specification** (full spec in `results-name-entry.md`):
- Three-slot wheel per player, shared timer. Up/down changes the character, left/right moves the slot, Confirm on the last slot submits, Cancel steps back one slot.
- Keyboard-bound slots may also type directly (the only place raw keys are allowed), and only when exactly one keyboard slot is editing. **A mouse is not bound to a slot, so pointer input does not drive a wheel**; only a TOUCH-bound slot taps the chevrons.
- **Start finishes only the pressing slot**, never the whole group; the press that opened Name entry is consumed and cannot mark a slot Done.
- Focus order runs **inside** a wheel (slot 1 -> 2 -> 3) and never moves between wheels: each player owns their own.
- **3-4 players** use a 2x2 grid of 160x136 blocks at x = 16 / 184, y = 104 / 264; with 3 players the bottom block is centred at x = 100. Each block carries its own wheel, P-tag and device glyph (Menus Rule 36).
- Timer expiry submits the current entry; the player is never locked out of their score. Under `access.untimed_menus` there is no timer, and a lost pad holds the slot open (**P31**) instead of forcing it Done.
- Initials are **Latin in both languages**; a Bengali key press is refused with `sfx_ui_deny` and the hint `menu.name.latin_only`.

### P16 Tab + filter list

**Category**: Data Display
**Used In**: High scores, Records

**Specification**:
- Tabs across the top (shoulder buttons / left-right on the tab row); filter choice below; rows below; a detail strip for the focused row.
- The row for a new entry is highlighted by static border + star; the pulse is optional and off under reduce-pulsing/flashing.
- Empty state: a single INFO row, "No scores yet", never a blank list.

### P17 Tally count-up with skip

**Category**: Data Display
**Used In**: Stage-end tally

**Specification**:
- Lines reveal in a fixed order and count up on a schedule. **Skip is per column:** each player's own Fire press edge (after a 90-tick lockout) settles only that player's column; a second press, at least 30 ticks after settling, confirms that column. One player's press never changes another's column. Start/Back pause; Drone/Bomb do nothing.
- Only edges of the Fire held bit count; the touch auto-fire pulse and Tap Assist presses never skip.
- Skipping never changes the awarded score; it only shortens the display.
- Auto-advance timing follows `access.tally_auto_advance`.
- Reduce-motion/flashing: counts snap, NEW BEST pulse becomes a static border + star.

### P18 HUD plate (per-slot column)

**Category**: Data Display
**Used In**: HUD

**Specification**:
- 90 px column per slot with the P08 frame; contains score, lives, bombs, drones, kit meter, chain plate. Layout variants for 1P, 2P, 3-4P are fixed by `hud.md`.
- Empty slot shows the join plate (P09). The HUD never covers the play field beyond its reserved strip.
- HUD changes brightness no faster than 1 Hz under reduce-flashing.

### P19 Touch button strip

**Category**: Input
**Used In**: Stage, Pause (touch platforms, solo)

**Specification**:
- Bottom strip reserved from the safe area, constant in every session state so the canvas never resizes.
- Buttons Hold (12 mm), Drone (11 mm), Bomb (12 mm), Pause (9 mm). Hit areas are 12 mm or more. Layout mirrors for left-handed play; order from the edge is Hold, Drone, Bomb.
- A finger keeps its role from touch-down to lift. Sliding between buttons does not press the second one.
- Edge reject 2 mm. At most 5 tracked pointers.
- Haptics optional (`touch.haptics`).
- Landscape: the game pauses with "Rotate your phone upright".
- One-hand mode turns Hold into a toggle.

### P20 Drag-to-move

**Category**: Input
**Used In**: Stage (touch)

**Specification**:
- Default scheme DRAG: relative movement; the plane never snaps to the finger; speed capped to pad speed via the leash. Alternative STICK: floating stick, 10 mm radius.
- Not Active (FlyIn/Dying/Absent) = no input is applied, and motion made before control returns is discarded.

### P21 Accessibility-aware motion

**Category**: Feedback

**Specification**:
- Every animated element declares which option affects it: `reduce_flashing` (no white frames, 1 Hz max brightness change), `reduce_pulsing` (steady cues), `reduce_motion` (snaps instead of rolls/slides/shakes, static stripes).
- Functional animation (hold-fill bar, countdown) is never removed, only its flourish.
- Bullets, hit radii and the hitbox dot are never altered by any option.

### P22 Platform-gated item

**Category**: Navigation

**Specification**:
- Items carry `platform_tags`; an item not valid on the current platform is not listed (not greyed). QUIT is hidden on Web and mobile.
- Focus navigation, wraparound and default focus are computed after filtering.

### P23 Bilingual text block

**Category**: Data Display

**Specification**:
- Title, banners and names show both scripts at equal visual weight (Bengali on top). Menus are single-language, switched by the language chip.
- Language chips `বাংলা` and `English` are always in their own script, never translated; the active chip is filled; switching applies in one frame and shifts nothing (shared digit grid).
- Reserve +40% width. Numerals follow the Localization digit grid.

### P24 Web gate

**Category**: Navigation

**Specification**:
- Web only: after boot, a bilingual line "Click or press a key to start". The first click, key or touch leaves the gate, unlocks audio and fullscreen, and is consumed (G7).
- A gamepad button alone leaves the gate but may not unlock audio (unverified).

### P25 Yes / No dialog (safe default)

**Category**: Modal
**Used In**: Quit game (PC, Switch), first-run photosensitivity plate

**Description**: A two-item plate for a single yes/no decision that is not destructive enough for hold-to-confirm, or that must be answered once.

**Specification**:
- Plate centred, two BUTTON items stacked; **default focus is the safe option** (No / Keep as is).
- Cancel picks the safe option. Confirm activates the focused item. Pointer/touch: tap an item.
- The question line is single-language, except the first-run plate, which is dual-script (P23).
- Opening is instant; `sfx_ui_confirm` / `sfx_ui_cancel` cues.

**When to Use**: Quitting the application; one-time questions. **When NOT to Use**: Losing a run or data (use P04); timed choices (use P12).

### P26 Scrolling list and touch row pitch

**Category**: Navigation
**Used In**: Boss select, High scores, Settings, Credits, any list on touch

**Specification**:
- When a list does not fit its area, it scrolls so the focused row is always fully visible, with one row of look-ahead when possible.
- Scrolls in whole rows, stepped (no smooth tween); a 4x4 chevron glyph above/below shows there is more.
- Pad/keyboard rows are `menu_item_h` 32 px; on touch every focusable row is `touch_item_h = max(32, min_target_canvas_px)` (9 mm, Touch TF7), full plate width, 4 px gap.
- Mouse wheel scrolls one row; touch drag scrolls (swipe lists are open in Menus OQ 11).
- Focus never lands on a row that is off-screen.
- **Credits variation (line step, not whole row):** the credits roll has no focusable rows, so Nav up/down steps **one line** and pauses the auto-scroll; a Fire or Start press resumes it. With `access.reduce_motion` the auto-scroll is off and the screen opens in manual mode. Scrolling stops with the last line at the viewport centre - no loop, no auto-exit (Menus Rule 46, `credits.md`).

**When NOT to Use**: Fixed-size lists (Title, Pause).

### P27 Stepped progress bar

**Category**: Feedback
**Used In**: Lobby commit bar (4 segments), hold-to-confirm bar (4 x 12x6), countdowns, chain window bar, boss HP bar

**Specification**:
- Bars move in whole steps (segments, or 1-2 px per tick), never tweened.
- Every bar has a non-colour backup: a number (boss %, countdown digits), a label ("Starting", "Hold to confirm") or a segment count.
- Bars are functional: reduce-motion never removes them.
- Gold completion frame on hold bars; Alarm Red end-cap only on the chain window (last 25%).

### P28 Rebind control (listen for input)

**Category**: Input
**Used In**: Settings > Controls

**Specification** (summary; full spec in `settings.md`):
- Confirm on a binding row enters **Listening**: "Press a control for {action}", with Cancel. Only controls from the **same device class** are accepted.
- A control already in use asks to swap (confirm line); a reserved control is refused with a message (`sfx_ui_deny`); the last binding of Fire / Drone / Bomb cannot be cleared.
- Pad movement, Start and Back are not remappable.

### P29 Status block (empty / loading / error)

**Category**: Feedback
**Used In**: High scores (Online tab, local notices), Save notices, any list that can be empty, slow or broken

**Specification**:
- One **plated block** in the content area, never a blank area and never a modal: a glyph, a **headline** (what happened) and an optional **detail** line (what the player can do). It replaces the rows it stands in for; the rest of the screen stays usable.
- Four kinds: **Empty** (nothing stored yet), **Loading** (a request is in flight; a bounded wait, with a stated maximum), **Error** (a named reason code, not a stack trace) and **Unavailable** (the feature is off or absent on this platform; see P22 - a feature with no adapter at all is **not listed**, so it shows no block).
- A retry action is a focusable row inside the block when retrying is possible; while a backoff is in force the retry is refused with `sfx_ui_deny` rather than hidden.
- The block is focusable so a pad-only player can reach its action and so the text is reachable in reading order.
- Colour is never the only cue: the glyph plus the words carry the state. **A failure block uses Cream words with an Alarm Red `#E03A3E` plate edge and/or error glyph** - `#E03A3E` is never a text fill (3.95:1 on Char). *(Amended 2026-11-03, final doc closeout:)* the block's **one headline line** may instead be drawn in the text-only **Alarm Flare `#F2494D`** (4.76:1 on Char, computed; art bible 4.1, `arcade-ui-style.md` 3.1 rule 3 "two reds, two jobs"): one headline line per screen, the detail sentence stays Cream and repeats the same words, the Alarm Red edge and/or error glyph is still required, Cream is substituted under `hud_contrast` HIGH, and Flare is never a fill of any kind and never appears in the HUD strip, a slot column or the play field. An all-Cream block remains equally correct.
- Strings are per-screen with character limits; the headline fits one line at text step 3 (+40% for Bengali).

**When NOT to Use**: transient outcomes that belong in a toast (P11), or a decision the player must answer now (P25).

### P30 Single-button modal over a stopped field

**Category**: Modal
**Used In**: Flight School Coach card (`flight-school.md`)

**Specification**:
- Opens over a **stopped** play field (the drill pauses and enemy bullets are cleared first), like a Pause panel, and is the one place a drill shows words while the field is up.
- Exactly **one** action: Resume. Every bound slot's Confirm resumes it; there is no owner (unlike P10) because the whole group is held.
- The resume beat (P13) runs after it closes.
- Capped per attempt (`coach_max`), so it can never become a loop; after the cap the same text is available on the drill Card.
- In co-op the card names no slot: the text is addressed to the group.
- Panel animation and sound come from the standards tables (`arcade-ui-style.md` sections 4 and 5).

**When NOT to Use**: anything with a choice (use P25) or anything owned by one slot (use P10).

*(Numbering note: the id **P30** is assigned here because P29 was already taken by the Status block in `high-scores.md`. `flight-school.md` called this "candidate P29"; **its reference was corrected to P30 on 2026-11-03, wave 5 batch 2**, so no stale id remains.)*

### P31 Controller-lost plate with DROP

**Category**: Modal
**Used In**: Name entry under `access.untimed_menus` (`results-name-entry.md`); any untimed menu where a slot's pad can vanish mid-edit

**Specification**:
- When a slot's bound pad disconnects **while `access.untimed_menus` is on**, the slot is **held** rather than auto-finished: its block shows a **controller-lost plate** (`menu.name.controller_lost`) over that slot's area only. Other slots keep working.
- The plate offers one explicit action, **DROP** (`menu.name.drop`), reachable by **any** bound slot, which abandons the held slot and lets the screen finish. Reconnecting the pad clears the plate and restores the slot's edit in place.
- Nothing is timed out while the plate is up (that is the point of the option); the screen can still never deadlock, because DROP is always available.
- Without `untimed_menus` the default rule applies instead: the slot becomes Done with its last-used initials (Menus Rule 36).

**When NOT to Use**: during play, where Input's own disconnect pause and the Disconnect overlay (P10) own the case.

---

## Back / Cancel behaviour by screen

| Screen | Cancel does | Why |
|---|---|---|
| Title | Nothing | Root; never exits the app by accident |
| Sub-screens (Scores, Settings, Credits, Play choice) | Up one level, focus restored on the opener (P05) | Standard |
| Lobby | Steps the slot back: Locked -> Choosing -> Empty; last slot -> Title (P09) | Per-slot state, not a screen stack |
| Pause | Resumes (with the resume beat) | Pause is a modal over play |
| Disconnect overlay | Nothing (choose Reconnect / Keyboard / Drop / Wait) | A decision is required |
| Tally | Nothing (Bomb/Drone ignored) | Fire-only screen; Start pauses |
| Name entry | Steps back one initial slot | Wheel editing |
| Credits | Up one level to its opener (P05). **Start is Confirm here** (resume the roll), not Cancel | Menus Rule 12; the roll needs a resume verb |
| Dialogs (P25) | Picks the safe option | Safe default |

---

## Animation Standards

**Owner: `arcade-ui-style.md` section 4.** That table is canonical and applies to every pattern; this section only points at it and names which pattern uses which row - it never carries its own numbers as an alternative source. Where a figure appears below it is a pointer, and if the two ever differ the style guide wins and this file is fixed.

Pattern mapping: screen change (4-step Char wipe over 12 frames; cut under reduce motion) -> every P01/P05 screen step; panels and toasts (8 frames, stepped) -> P10, P11, P25, P30; row reveals (6 frames) -> P16, P17; counts (integer steps over 30 ticks, 45 for hero numbers) -> P17; stamps (4-8 frames) -> P09, P17; focus pulse (<= 40% opacity, <= 2 Hz, off under reduce pulsing) -> P02; **join plate opacity step at 1 Hz, 100% <-> 60%** (steady under reduce pulsing) -> P09; no flashes in UI; all timings are integer ticks (P21 governs the accessibility behaviour).

## Sound Standards

**Owner: `arcade-ui-style.md` section 5** for the standard (which cue plays for which interaction) and **`design/gdd/audio.md` for the cue ids** themselves. This section only maps patterns onto those cues. Pattern mapping: P01/P07 move -> `sfx_ui_nav_tick` (P15 wheel -> `sfx_ui_name_tick`); activate -> `sfx_ui_confirm`; P05 -> `sfx_ui_cancel`; refused -> `sfx_ui_deny`; P09 join -> `sfx_ui_join_chime`; P10 -> `sfx_ui_pause_in` / `sfx_ui_pause_out`, `sfx_ui_pad_lost`; P03 STEPPER (volume) -> `sfx_ui_slider_preview`; P17 -> `sfx_ui_tally_row`, `sfx_ui_tally_hero`, `sfx_ui_new_best`; P11 Save notices -> `sfx_ui_save_ok` / `sfx_ui_save_error`. Every cue has a visual twin; UI sounds never use the bullet voice pool.

---

## Gaps & Patterns Needed

| # | Gap | Needed by | Owner |
|---|---|---|---|
| 1 | ~~Key remap pattern~~ **Added as P28**; full spec in `settings.md` | Settings > Controls | done |
| 2 | Continue prompt: specified in `hud.md` (UX) from the HUD and Session GDDs | HUD, Session | see that file |
| 3 | **Boss select list** with PRACTICE tag and best score (Stretch) | Play choice | ux-designer |
| 4 | ~~**Credits scroller** (pause on focus? skip)~~ **Closed 2026-11-03:** answered in `credits.md` and Menus Rule 46 - Nav steps one line and pauses the auto-scroll, Fire or Start resumes, `access.reduce_motion` means manual only, the roll stops with the last line at the viewport centre. Recorded as the Credits variation under P26 | Credits | done |
| 5 | ~~Tutorial tip row~~ **Budgeted**: Pause plate is bottom-anchored at y 420 and grows upward (`pause.md`); Tally footer band y 600-640 with a fit rule (`stage-tally.md`); surfaces in `flight-school.md` | Tutorial | done (art-director to confirm) |
| 6 | ~~Results screen~~ specified in `results-name-entry.md`; **updated 2026-11-03** with the 3-4P name grid, the single rank strip (team rank in co-op), the not-placed case and the untimed pad-loss hold - folded into P15 and the new P31 | Results | done |
| 7 | Screen-reader / TTS stance: decided in `design/accessibility-requirements.md` | Accessibility | see that file |
| 8 | ~~**Error / empty / loading** shared states (save corrupt, online unavailable, leaderboard offline)~~ **Closed 2026-11-03: added as P29 Status block**, first specified in `high-scores.md` | Scores, Save | done |

---

## Open Questions

1. No `design/player-journey.md` or `design/accessibility-requirements.md` exists. Patterns here follow `accessibility-options.md`, but no committed accessibility tier (e.g. WCAG AA equivalent) is recorded. Decide the tier before `/gate-check pre-production`.
2. Web: gamepad-only gate exit may not unlock audio (Menus R5, unverified in 4.7). Needs a Web spike.
3. Touch: `InputEventScreenTouch.canceled`, `DisplayServer.is_touchscreen_available()` and DPI reliability on iOS/Android/Web are unverified in Godot 4.7 (Touch GDD Open Questions).
4. Pattern P15 (name wheel) details are summarised from the Menus GDD overview and acceptance criteria; confirm against Menus Rule 36 when writing the Name entry spec.
5. Patterns P16, P17 and P18 are condensed from the Tally and HUD GDDs; the per-screen specs should be treated as the authority for exact timings.
6. Should hold-to-confirm (P04) use 60 ticks on touch, where an accidental long press is more likely and the thumb covers the fill bar?
