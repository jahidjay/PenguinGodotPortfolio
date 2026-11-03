# UX Spec: Main Menu (Title + Play choice)

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring, pending `/ux-review`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Journey Phase(s)**: First launch, every session start (see `design/player-journey.md`)
> **Platform Target**: PC (Steam/itch), Web, iOS, Android, Switch. Gamepad primary, keyboard first-class, touch partial, pointer on Web/PC
> **Template**: UX Spec
> **Sources**: `design/gdd/menus-title-plane-select.md` (Rules 3-11, 17, 49+; V/A table; UI Requirements; AC-01..09), `tutorial.md` (Flight School item), `online-leaderboards-boss-rush.md` (Play choice, Stretch), `touch-controls.md` (TF7), `input-and-player-mapping.md`, `accessibility-options.md`, art bible 2, 7.8. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P01, P02, P03, P05, P06, P11, P14, P22, P23, P24 (see `interaction-patterns.md`)
> **Style**: `arcade-ui-style.md` (arcade conventions, single-language menus, Bengali rules)
> **Revision 2026-11-03**: fixes from `/ux-review` (first-run photosensitivity prompt, platform target, measured layout, resolution AC, keyboard keys, data null handling)
> **Revision 2026-11-03 (UX amendments wave 5)**: menu-list top is y 372 with FLIGHT SCHOOL (6 items) and stays y 392 for 5 items; Open Question 1 closed.

"Main menu" in this project is the **Title** screen. This spec also covers the **Play choice** list (Stretch), because it is the same plate and the same list. Lobby, Settings, High scores and Credits get their own specs.

---

## Purpose & Player Need

The player arrives wanting to **fly in one or two presses**, or to find scores, settings or help without a detour. Title is the front door: it must show the game's identity (bilingual logo, four planes, "the cabinet is calling you"), put START GAME under the thumb, and fix a wrong language guess in one press. It never decides gameplay rules.

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| First launch | Curious, a little impatient | No first-run language screen; the language chip fixes a wrong OS guess (Rule 3) |
| Returning from a run (Board, Results) | Wants "one more go" | START GAME must stay the default focus; Board offers PLAY AGAIN directly |
| Back from Scores / Settings / Credits | Calm | Focus is restored on the item that opened the screen (P05) |
| After idle attract | Passive | The waking input is consumed (P14, G7) |
| Web | Just clicked the browser tab | Passes through the Web gate first (P24) |

Players arrive voluntarily. No time pressure exists; the only timer is the 30 s attract.

## Navigation Position

`Boot -> (Web gate) -> (first-run photosensitivity prompt, once) -> **TITLE** -> Lobby | Scores | Settings | Credits | Quit`. At Stretch, once Boss Rush or Single Boss is unlocked: `TITLE -> PLAY CHOICE -> Lobby | Boss select`. Title is the root of the menu tree; it is reachable from Board, Results, Lobby (last slot cancels or 60 s idle) and Pause (Quit to title, abandoned run).

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Boot (desktop/mobile) | Save, Localization, Display ready (Rule 4) | Resolved language, saved settings |
| Web gate | First click, key or touch (consumed) | Audio unlocked, saved fullscreen applied |
| First-run photosensitivity prompt (Accessibility Rule 34) | Shown once, after Boot and the Web gate, while `access.first_run_prompt_done` is false. Bilingual plate "This game has one bright flash. Reduce flashing and effects?", items **Keep as is** (default focus) / **Reduce flashing and effects**. Specified in `settings.md` | Choice saved; Title opens next |
| Scores / Settings / Credits | Cancel | Focus returns to the opener |
| Lobby | Last slot cancels, or 60 s idle | Devices unbound |
| Board / Results | Title action | Run finished; hi-score may have changed |
| Pause | Quit to title (hold) | Run ABANDONED, nothing saved |
| Attract | Any input | Input consumed |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Lobby | Confirm on START GAME | Pad/keyboard Confirm **binds that device to slot 0** and slot 0 starts Choosing. Pointer Confirm opens Lobby with all slots Empty. Touch tap binds TOUCH to slot 0 (solo) |
| Play choice | Confirm on START GAME (Stretch, mode unlocked) | Shown only when a non-MAIN mode is unlocked |
| Flight School | Confirm on FLIGHT SCHOOL (Target) | NEW tag until `tutorial.school_seen` |
| High scores | Confirm | Shared screen |
| Settings | Confirm | Changes apply live |
| Credits | Confirm | |
| Quit | Confirm on QUIT | Desktop and Switch only; hidden on Web and mobile |
| Language toggle | Drone button / chip click | Stays on Title, commits immediately |

---

## Layout Specification

### Information Hierarchy

1. **START GAME** (default focus; the primary action).
2. Game identity: bilingual logo.
3. Remaining actions: FLIGHT SCHOOL, HIGH SCORES, SETTINGS, CREDITS, QUIT.
4. Language chips (always visible, so a wrong guess is recoverable).
5. Hi-score line (discoverable ambient information).
6. Prompt bar with device-correct glyphs.
7. Toasts (transient).

### Layout Zones

Canvas 360x640. Zone positions from the Menus V/A table. **All y values are nominal at text step 0.** Menus Rule 51 lays screens out from measured text, so a larger text step grows rows and the list scrolls; the order of zones never changes.

| Zone | y range (px) | Contents |
|---|---|---|
| Top bar | 0-28 | Hi-score line (S tier, Gold, y 8) left; language chips top right (2 x 56x20) |
| Logo | 72-200 | `logo_title_bn` above `logo_title_en`, XL, equal weight |
| Backdrop | full | Warm sepia dusk, four-plane formation flyby |
| Menu list | **372** with FLIGHT SCHOOL, **392** otherwise (+ n x 36) | Plate 216 px wide, centred; item height 32, gap 4. **6 items (FLIGHT SCHOOL present, Target):** top y **372**, 212 px tall, ends y **584** - 16 px clear of the prompt bar at y 600. **5 items:** top y **392**, 176 px tall, ends y **568**. The logo ends at y 200, so the 172 px gap above the list absorbs the 20 px shift. At text steps 2-3 the list **scrolls inside y 372-584** with the focused row kept in view. The toast strip (y 560-584) overlaps the list bottom exactly as it already does at 5 items; while a toast is shown it takes precedence (it is transient). *(Decided 2026-11-03, wave 5; closes Open Question 1.)* |
| Toast | 560-584 | Strip 328x24 |
| Prompt bar | 600-640 | Glyph + verb pairs for the current device |

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|
| START GAME | BUTTON/LINK | Yes | P01, P03 | Default focus |
| FLIGHT SCHOOL | LINK | Yes | P03 | Target tier; static NEW tag (text + star glyph) |
| HIGH SCORES | LINK | Yes | P03 | |
| SETTINGS | LINK | Yes | P03 | |
| CREDITS | LINK | Yes | P03 | |
| QUIT | BUTTON | Yes | P22 | `platform_tags`: hidden on Web, mobile |
| Language chips (বাংলা, English) | TOGGLE | Yes | P23 | Always in own script; active chip filled |
| Hi-score line | INFO | No | — | Stays visible during attract |
| Logo lockup | Art | No | P23 | Hand-pixeled, two layers |
| Prompt bar | INFO | No | — | Glyphs per active device |
| Toast strip | Feedback | No | P11 | |
| PLAY CHOICE list (Stretch) | Focus list | Yes | P01 | MAIN (default), BOSS RUSH, SINGLE BOSS; locked modes not listed |

### ASCII Wireframe

```
+----------------------------------------------------------+ y0
| HI 9,100,000                      [ বাংলা ][ English* ]  |
|                                                          |
|              [ LOGO  bn   XL, gold ]                     | y72
|              [ LOGO  en   XL, gold ]                     | to y200
|                                                          |
|        . . . four planes, slow formation flyby . . .     |
|                                                          |
|                  +--------------------+                  | y392
|               >  |     START GAME     |                  |
|                  |  FLIGHT SCHOOL *NEW|                  | Target
|                  |    HIGH SCORES     |                  |
|                  |     SETTINGS       |                  |
|                  |      CREDITS       |                  |
|                  |       QUIT         |                  | hidden on Web / mobile
|                  +--------------------+                  |
| [toast strip, y560]                                      |
| [A] Confirm   [X] Language                               | y600
+----------------------------------------------------------+ y640
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default | Boot or return | Menu list visible, START GAME focused |
| Web gate | Web build, before Title | Char screen with bilingual line; no menu (P24) |
| Attract | 1,800 ticks (30 s) idle | List, chips and prompt hide; backdrop cycles the four era palettes every 1,200 ticks; logo + hi-score stay; any input returns and is consumed |
| Play choice (Stretch) | Confirm on START GAME with a mode unlocked | Same plate, new items; Cancel returns to Title list |
| Fresh profile | No scores | Hi-score line shows `HI 0` (fields have no leading zeros, HUD Rule 14) |
| No QUIT | Web, mobile | List is one shorter; focus wrap recalculated (P22) |
| Touch device | Touch platform | Row height `touch_item_h` (55 canvas px at x3/458 dpi), full plate width, list scrolls if it no longer fits |
| Save notice | Corrupt/newer save, `save_failed` | Toast (never dropped) |
| Language changed | Chip toggle | Labels swap in one frame, nothing shifts |
| Reduce pulsing | `access.reduce_pulsing` | Focus pulse off (steady) |
| Landscape on touch | Width > height | Game pauses with "Rotate your phone upright" |
| Loading | Boot not finished | Not shown; Title's first frame is after Save, Localization and Display are done (AC-01) |
| First run | `access.first_run_prompt_done` false | Photosensitivity plate comes before Title (once); Title then opens normally |
| Save read-only / unavailable | Save state on boot | Title opens normally; one toast "Progress will not be saved"; hi-score shows the in-memory value |

---

## Interaction Map

Input methods: gamepad (primary, full), keyboard, touch (partial), pointer on Web/PC. Verbs only (G1).

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Menu list | Move focus | D-pad / stick up-down (repeat 18/6) | Up/Down | Hover moves focus; wheel scrolls | Focus border + arrow, UI move tick | Wraps, skips disabled |
| START GAME | Activate | Fire / Start | Enter, Z, Space | Click / tap | UI confirm sound, 12-frame wipe | Lobby (device bound to slot 0) or Play choice |
| Other LINK items | Activate | Fire / Start | Enter, Z, Space | Click / tap | Confirm sound, wipe | Opens screen |
| QUIT | Activate | Fire / Start | Enter, Z, Space | Click | Confirm sound | Exits the application |
| Language | Toggle | Drone (West / X / Square / Y; alt. left shoulder) | KB1 `X` or `.`; KB2 `G` | Click / tap chip | Instant swap | `Localization.set_language`, `commit_settings` once |
| Back | Cancel | Bomb / Back | Esc, C | Back plate (Play choice only) | — | Title: does nothing. Play choice: up to Title |
| Any input in Attract | Wake | Any | Any | Any | Palette stops cycling | Returns to Title; input consumed |
| Web gate | Leave | Pad button (audio may stay locked) | Any key | Click / tap | — | Title; input consumed |

Joining: a **Start** press on an unbound device from Title opens the Lobby as the join request (Input Rule 3). A pointer cannot be a flying device. Title is **shared**: every connected device may navigate and the last input wins.

## Events Fired

| Player Action | Event / Call | Payload | Persistent state? |
|---|---|---|---|
| Confirm START GAME (pad/keyboard) | `bind_device(device, 0)`, open Lobby | device id | Binding is session-only |
| Confirm START GAME (pointer) | Open Lobby, all slots Empty | — | No |
| Confirm START GAME (touch) | Bind TOUCH to slot 0 | — | No |
| Toggle language | `Localization.set_language`, `commit_settings` | `bn` or `en` | **Yes** (`settings.language`): flag for Save |
| Confirm FLIGHT SCHOOL | Open `school_list` | — | No |
| Confirm HIGH SCORES / SETTINGS / CREDITS | Screen change | — | No |
| Confirm QUIT | Application exit | — | No |
| Wake from attract | none | — | No (input consumed) |
| Save failure | Toast | reason | No |

Analytics: no events are defined in any GDD for Title (see Open Question 4).

## Transitions & Animations

- **Enter / exit:** stepped 4-step Char wipe over 12 frames; no white, no fade-to-white (art bible 7.8). Reduce-motion: cut instead of wipe.
- **Focus move:** instant; arrow glyph snaps (stepped easing 3-4 positions where animated).
- **Focus pulse:** 40% opacity or less, 2 Hz or less, one element; off under `reduce_pulsing`.
- **Attract:** palette cycle between four era tints every 20 s; hard steps, no flashing. Reduce-flashing: the cycle uses a 18-tick cross-tint instead of a cut (to confirm with VFX; see Open Question 5).
- **Language swap:** one frame, no layout shift.
- **Toast:** 8-frame in/out, 90 ticks hold.
- **Formation flyby:** slow, looping; stops under `reduce_motion` (first frame held).

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Hi-score | Save (26) | Read | Shown on Title and attract only |
| Active language | Localization (27) | Read/Write | Chip state |
| Strings (`menu.title.*`) | Localization (27) | Read | Bilingual draft table in the Menus GDD |
| Unlocked modes | Online leaderboards (32) / Save | Read | Decides whether START GAME opens Play choice |
| `tutorial.school_seen` | Tutorial (30) / Save | Read | Controls the NEW tag |
| Platform tags | Display / engine | Read | QUIT visibility |
| Device list | Input (2) | Read | Prompt-bar glyph family |
| Save notices | Save (26) | Read | Toasts |
| `reduce_*` options | Accessibility (28) | Read | Pulse/motion |

Update trigger: hi-score, unlocks and `school_seen` are read once on screen open; language on `language_changed`; device glyphs on the last input. Null handling: no hi-score -> `0` (not 000,000,000); no unlocked mode -> START GAME goes straight to the Lobby; unknown device -> generic glyphs.

UI owns no game state. The screen is a view over `MenuModel` (node-free, ticked at 60 Hz).

## Accessibility

Target tier: **Comprehensive** (`design/accessibility-requirements.md`), implemented through `accessibility-options.md`.

- **Gamepad path:** D-pad moves through every item in visual order; Fire/Start activates; Drone toggles language; no focus traps.
- **Keyboard path:** same verbs (Enter/Z/Space confirm, Esc/C cancel).
- **Contrast:** Cream `#F4EBD6` text with a 1 px `#14110E` outline on Cabinet Char `#1E1B18` plates. High-contrast option swaps plate edges to Cream and dim text to `#A89E8A`.
- **Colour-independent:** focus = border + arrow; NEW = text + star glyph; active language = filled chip with text, not colour alone.
- **Motion:** focus pulse, flyby and wipe respect `reduce_pulsing` / `reduce_motion`.
- **Text size:** `font_size_px` step from Accessibility applies. At steps 2-3 the list scrolls inside its band (y 372-584 with 6 items, y 392-584 with 5) and keeps the focused row in view; it never grows past the prompt bar.
- **Timing:** nothing on Title is timed except attract (non-blocking), so `untimed_menus` has no effect here.
- **Screen reader:** no stance exists for this game (pattern library gap 7). Not specified.
- **Touch:** row height at least 9 mm (TF7).

## Localization Considerations

- Menu plate is 216 px; item labels are single-language per the chosen language. Reserve +40% width: `HIGH SCORES` (11 chars) and `FLIGHT SCHOOL` (13 chars) are the **HIGH PRIORITY** English strings; Bengali `সর্বোচ্চ স্কোর` and `কৃতজ্ঞতা` need verifying against the plate at the M tier.
- Logo is always bilingual and equal weight; not translated.
- Language chips are never translated.
- Numerals (hi-score) use the shared digit grid; 9 digits.
- Bengali strings in the GDD are drafts awaiting native review (Menus Open Question 7).
- Web gate line is shown in both languages at once.

---

## Acceptance Criteria

Derived from Menus AC-01..09 plus UX-level checks.

- [ ] Title's first frame appears only after Save, Localization and Display have finished; Title appears within 2 s of the engine finishing load on a mid-range phone (*proposed target, not in a GDD; confirm with the perf budget*).
- [ ] On a fresh profile the photosensitivity plate appears once before Title in both scripts, with "Keep as is" focused; after a choice it never appears again.
- [ ] At 360x640 x1, x3 and on a 19.5:9 phone safe area, the logo, list, chips and prompt bar are fully visible, nothing overlaps, and all positions are whole pixels.
- [ ] Default focus is START GAME on every arrival; pressing Cancel on Title does nothing.
- [ ] On a 5-item list, Down from the last item wraps to the first; Up from the first wraps to the last; disabled items are skipped.
- [ ] Pad Confirm on START GAME opens the Lobby with that pad as P1 (slot 0 Choosing); mouse click opens the Lobby with four Empty slots.
- [ ] In a Web build, the first click leaves the gate, the audio context is running and START GAME is **not** activated; a desktop build shows no gate.
- [ ] QUIT is absent on Web and mobile, and focus wrap is correct without it.
- [ ] Pressing Drone on Title switches Bengali/English in one frame without moving any element, and the language persists after restart.
- [ ] After 30 s idle the menu hides and the backdrop cycles four palettes; any input restores Title and is **not** also applied as a menu action.
- [ ] Focus is visible with a 3 px border + arrow in greyscale; no information relies on hue alone.
- [ ] With `reduce_pulsing` on, nothing on Title pulses; with `reduce_motion` on, the wipe is a cut.
- [ ] On a touch device every list row is at least 9 mm tall and the list scrolls to keep the focused row visible.
- [ ] A Save failure shows a toast that is never dropped even with 3 other toasts queued.
- [ ] Both language layouts of all items fit the 216 px plate with no clipping at the largest `font_size_px` step.
- [ ] Back from Settings, Scores and Credits returns to Title with focus on the item that opened it.

---

## Open Questions

1. ~~**Vertical overflow with Flight School.** Six items at 32 px + 4 px gap = 212 px, starting at y 392, ends at y 604, which overlaps the prompt bar (y 600).~~ **Closed 2026-11-03 (wave 5):** the list top is **y 372 when FLIGHT SCHOOL is present** (6 items, 212 px, ends y 584, 16 px clear of the prompt bar) and stays **y 392 for 5 items** (ends y 568). The item height and gap are unchanged and the prompt bar does not move. At text steps 2-3 the list scrolls inside its band with the focused row kept in view. See Layout Zones.
2. ~~Accessibility tier undefined~~ **Closed 2026-11-03:** Comprehensive (`design/accessibility-requirements.md`).
3. ~~Player journey map missing~~ **Closed 2026-11-03:** `design/player-journey.md`.
4. No analytics/telemetry events are defined for menu actions (`analytics-engineer` input needed, if telemetry is wanted at all).
5. Attract-mode behaviour under `reduce_flashing` is not specified in the Accessibility GDD (era palette cuts could read as a full-screen flash).
6. Web gate: does a gamepad press count as a user gesture for audio (Menus Open Question 6, Web spike)?
7. Touch: should the touch Title show a visible START affordance instead of a list-only layout? Not covered in the Touch GDD.
8. Language chip has no visible gamepad hint except the prompt bar `[X] Language`. Confirm glyph per device family with Input.
9. Attract mode has no gameplay demo at MVP (Menus Open Question 1).
