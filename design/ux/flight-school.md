# UX Spec: Flight School (School list, Drill card, in-drill presentation, first-run hint surfaces)

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring; `/ux-review` 2026-11-03 done, blocking issues fixed, see report `production/ux-reports/flight-school.md`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Tier**: **Target** (not MVP). Everything here is built after the MVP loop ships; the Title item, Lobby SCHOOL mode and Pause tip row are absent in MVP builds.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (final doc closeout, art-director amendments A1/A2)**: the HUD DONE / SKIPPED stamp row carries the real 16x11 rects (1P (224,4); 3-4P (73,16) per column) and records `stamp = none` for 2P and Compact 48; a **per-slot result row on the Flight School surface** is now required in those two modes (Tutorial Rule 16a); UI cue ids rewritten to `sfx_ui_*`.
> **Revision 2026-11-03 (UX consistency check, wave 5)**: Open Questions 12 and 15 closed against the applied Tutorial amendments (per-plane `required_mask`, plane-neutral or per-kit `tip_key`); the "All required done" state and the Title commit row now cite the landed Tutorial F3 and Save Rule 20 text.
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: the Coach card's pattern id is **P30**, not the earlier "candidate P29" (P29 is the Status block).
> **Journey Phase(s)**: unknown (no `design/player-journey.md`)
> **Template**: UX Spec
> **Platform Target**: PC, Web, Switch: full (gamepad primary, keyboard full, pointer parity). iOS/Android: solo only (TOUCH is slot 0), partial. Canvas 360x640.
> **Sources**: `design/gdd/tutorial.md` (authority: Rules 2, 5-28, 30a/30b of HUD, F1, F3, F5, F8, Visual/Audio, AC-01..44), `menus-title-plane-select.md` (Rules 7, 8, 12-17, 27-33, 51; V/A table), `hud.md` (Rules 5a, 30a; element rects), `accessibility-options.md`, `localization.md` (Rules 15, 25), `stage-end-tally.md`, `design/ux/pause.md`, `stage-tally.md`, `main-menu.md`, `arcade-ui-style.md`. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P01, P02, P03, P04, P05, P06, P08, P10, P11, P13, P19, P21, P22, P23 (see `interaction-patterns.md`). Closes pattern-library Gap 5 (tip row) as a layout proposal (Open Question 1).

> Revised 2026-11-03 after /ux-review: added Loading/Empty/Error/Disconnect states, focus order and keyboard/pointer cells, data owners, `school_seen` commit on leaving to Title, Pause geometry and tip-row ACs aligned with `pause.md`, accessibility section rebased on `accessibility-requirements.md` (COMPREHENSIVE), corrected contrast figures, plane-neutral tip text, per-device glyph rule, localization limits, new ACs.

Scope: School list, Drill card, in-drill presentation (Ready, Live, Done), Coach card, drill Pause items, and the budgets for the four first-run hint surfaces. The Lobby SCHOOL mode, Title item and plain Pause are specified in `lobby.md`, `main-menu.md` and `pause.md`.

---

## Purpose & Player Need

The player wants **help with one concept without being forced to learn all of them**: "how do I keep my chain?", "what does hold do?". Flight School is a door, not a gate (Tutorial Rule 4): 11 short drills, each one idea, one number to reach, one stamp when done. A failed attempt costs nothing but seconds. First-run hints serve the player who never opens school: one short line on a stopped screen, or a bracket on the HUD, never words over bullets (Rule 2).

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| Title, first launch | Curious, unsure of the genre | NEW tag on the item invites, does not push (Rule 25) |
| After a bad first run | Frustrated, wants to understand | Results footer line points here once |
| Returning to the list after a drill | Pleased or mildly annoyed | The list should offer the next lesson under the thumb |
| Co-op friends | Social, uneven skill | Everyone flies at once; slower players are not blocked for more than 30 s (Rule 22) |
| Hint surfaces (Pause, Tally, stage card) | Mid-game, mind on the fight | One line, no new decision, nothing to dismiss |

## Navigation Position

`Title -> Lobby (SCHOOL mode) -> **SCHOOL LIST** -> **DRILL CARD** -> Ready -> Live -> Done -> SCHOOL LIST`. Live may open the Coach card and Pause. The list also reaches `Players` (back to Lobby), `Reset progress` (in place), Back (Title). Hint surfaces live in normal runs: stage card (stage 1 lead-in), Pause panel, Tally, HUD strip.

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Lobby (SCHOOL) | All joined slots Locked, 45 ticks, `GameSession.start_school(selections)` | Joined slots, planes, devices |
| Drill Done / Skip / Quit to list | Done beat ends, or hold complete, or item | `commit_settings()` once after a completed drill |
| Title -> FLIGHT SCHOOL | Confirm (opens the Lobby, not the list) | NEW tag state |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Drill Card | Confirm on a drill row | Focus is restored to the row on return (P05) |
| Ready -> Live | Confirm on Card | Planes fly in, 60-tick pip beat |
| Lobby (SCHOOL) | Confirm on Players | Slots and planes can change |
| Title | Cancel / Back plate on the list | Session cleared; if the last slot is dropped, Title too. **`commit_settings()` once if the profile is dirty** (so `tutorial.school_seen` and any hint counts survive a restart; without this the NEW tag would only clear after a completed drill. **The Save trigger landed 2026-11-03 (wave 5 batch 2):** Save Rule 20 lists "Flight School list left to Title while any `tutorial.*` key is dirty", and Tutorial Rules 16 / 25a carry the same contract) |
| Settings (over Pause) | Pause > Settings | Same Settings screen; commit once on close if dirty |

---

## Layout Specification

### Information Hierarchy

1. **School list:** the next undone required lesson (default focus), then each lesson's done mark, then the group it belongs to, then the group-level extras (Players, Reset progress, Back).
2. **Drill card:** the goal in numbers ("Hit 10 times with taps"), then the controls used (glyphs), then Start.
3. **In drill:** the bar `n/N` (HUD strip) first, the field second. No words over the field.
4. **Hint surfaces:** the icon first, then one line. Never a button.

### Layout Zones

Canvas 360x640, warm hangar backdrop (art bible 2). School screens are shared (any device, last input wins, P01).

| Zone | Rect (canvas px) | Contents |
|---|---|---|
| Header | y 0-40 | `tut.school.title` (L tier), joined-slot chips (P08), `n/10` required done (INFO, digits via `format_int`) |
| List viewport | x 16, y 44, 328 x 512 (to y 556) | 5 group headers (20 px) + 11 rows (min 32 px, 4 px gap) + 3 items. Content is about 624 px, so the list **scrolls** (focused row kept in view, 8x8 scroll arrows at x 336 top and bottom) |
| Toast | y 560-584 | P11 strip 328x24 |
| Prompt bar | y 600-640 | Glyphs for the last-used device |
| Drill card plate | (16, 120, 328, 360) | Title (M), goal (S, 2 lines; Bengali 3), glyph row, optional tip block, Start and Back plates |
| Live field | y `play_top` (48/72) onward | Real stage field; zones (`move`) and drill objects only |
| HUD strip (drill) | y 0-47 / 0-71 | Drill bar on boss-bar rect (24,37,312,10); left zone (0,36,24,12) group icon 12x12; right zone (336,36,24,12) `n/N` in D10 (Rule 18) |
| Pause panel (drill) | 216 wide, **bottom-anchored at y 420**, 208 high at text step 0 (top y 212), grows upward at higher steps and never covers the HUD strip (`pause.md`) | Owner tag, PAUSED, 5 items, no tip row in drills |
| Coach card | 296 x 120 minimum, centred in the field, top y 284 | Tip (S tier), one Resume button; grows downward with text size |

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|
| Group header | Info | No (skipped by focus) | P01 | Group icon 12x12 + `tut.group.*` name |
| Drill row | LINK | Yes | P03 | Title (max 28 EN chars), done stamps, "2P" tag; rows grow to 2 lines (3 Bengali) |
| Done stamp | Badge | No | P08 | 14x14, **one per joined slot**, ring-pattern frame + check glyph when done; empty frame when undone. Never colour alone |
| "2P" tag | Badge | No | — | On `min_players` > joined: row dimmed, Confirm = `sfx_ui_deny` + one-line reason toast |
| Players | LINK | Yes | P03 | Returns to Lobby SCHOOL mode |
| Reset progress | HOLD_BUTTON | Yes | P04 | 60 ticks; consequence line `tut.school.reset_warn` beside it (new string, Open Question 8) |
| Back plate | Button | Pointer/touch | P05, P06 | At least 24x24 |
| Glyph token | Info | No | — | 16x16 button glyph + S-tier action word (Fire / Drone / Bomb); 1-3 per card. **Which glyph:** the family and the actual (possibly remapped) binding of the **last-used device** (the Card is shared, P01); on keyboard it shows the key name (e.g. Z / X / C for KB1). In co-op with mixed families the tokens follow the last-used device and update on the next input |
| Start plate / Back plate (Card) | BUTTON | Yes | P03 | Height at least 24 |
| Ready pips | Feedback | No | P13 | 3 pips centred in the field, lit at ticks 0 / 20 / 40 of 60 |
| Drill bar | Feedback | No | — | Stepped Cream fill (F1), target notch at the end, no words |
| Zone bracket (`move`) | Field object | No | — | Cream corners, 6 px arms, 1 px; 40x40 (r 20) or 10x10 (r 5); 25% tint by quarter on dwell; under layer 8 |
| DONE / SKIPPED stamp (HUD) | Badge in a HUD column | No | P08 | One 16x11 asset (3 px border, 10x5 interior): DONE = Cream border + check glyph, SKIPPED = `#A89E8A` border + 6x1 dash, at both `hud_contrast` settings. Rects are HUD GDD Rule 30b: **1P (224,4,16,11)**, **3-4P (73,16,16,11) per column** (absolute x 73 / 163 / 253 / 343, y 16). 90 ticks, no flash. **`stamp = none` in 2P and Compact 48** |
| Per-slot result row (Flight School surface) | Badge row | No | P08 | *(2026-11-03, art-director A2; Tutorial Rule 16a.)* **Required in 2P and Compact 48**, where the HUD carries no stamp rect: through the Done beat and on the return to the list, Flight School shows **one 14x14 School-list stamp per joined slot in slot order** - ring-pattern frame + check glyph (DONE), dash glyph (SKIPPED), empty frame (not attempted) - plus the per-slot `sfx_tut_drill_done` cue. Same asset as the list stamps; no new colour, hex or rect. Harmless but redundant in 1P and 3-4P, where the HUD stamp is the signal |
| Coach card | Modal | Yes (Resume) | **P30** (single-button modal over a stopped field), accepted into `interaction-patterns.md` 2026-11-03. *(Was "candidate P29"; P29 is now the Status block, so the id moved - wave 5 batch 2.)* Not folded into P10: P10 is owner-only and the Coach card holds the whole group | Tip text only; opens for the whole group; names no slot |
| Zone bracket, Drill bar, Strip mark, "2P" tag | Field / HUD / Badge | No | **new patterns flagged** (drill-only HUD feedback; no interaction) | Not in the library; they have no input, so only visual specs exist (art bible) |
| Pause tip row / Tally tip row | Info | No (never focus) | — | Budgets below |
| Stage card primer | Info | No | — | Budget below |
| Strip mark | HUD overlay | No | — | Budget below. Never used in drills (hints do not run in school, Rule 26) |

### ASCII Wireframes

School list (1P, Move done, scrolled to top):

```
+----------------------------------------------------------+ y0
| FLIGHT SCHOOL                      [P1]       1 / 10     |
+----------------------------------------------------------+ y44
|  FLIGHT                                              ^   |
|    Move and slow down                      [P1 (v)]      |
|  > The tiny hitbox                         [P1 ( )]      |
|  GUNS                                                    |
|    Tap to shoot                            [P1 ( )]      |
|    ...                                                   |
|  TOGETHER                                                |
|    The team chain                    [2P]  [P1 ( )] dim  |
|    Players                                           v   |
+----------------------------------------------------------+ y556
| [A] Start drill   [B] Back                               | y600
+----------------------------------------------------------+
```

The prompt bar glyphs are those of the last-used device (Xbox glyphs shown). Prompt bar content per screen: **List** Fire = Start drill, Bomb = Back (keyboard: Z, C); **Card** Fire = Start, Bomb = Back; **Ready/Live/Done** none (the field owns the screen; Pause is the way out); **Coach** Fire = Resume. Touch shows no prompt bar (Back plate and Start plate are the targets).

Drill card:

```
        +----------------------------------------------+ y120
        | [wing] FLIGHT                                |
        | The tiny hitbox                              |
        | Pass 5 walls in a row without a hit.         |
        | Your hitbox is the small dot, not the plane. |
        |  [A]/[focus] Fire (hold)                     |
        |                                              |
        |   [ START DRILL ]       [ BACK ]             |
        +----------------------------------------------+ y480
```

In drill, HUD strip bottom row (1P, `chain` drill, 5 of 12), DONE stamp in column when finished:

```
 y36 | [chain] | [###############-----------|] |  5/12 |  left zone / bar (24,37,312,10) / right zone
```

Pause in a drill (owner P1):

```
            +--------------------------------+ y212 (bottom-anchored at y 420)
            | [P1 solid frame, 1 pip]        |
            |            PAUSED              |
            |  >  RESUME                     |
            |     RESTART DRILL              |
            |     SETTINGS                   |
            |     SKIP DRILL      [----]     | hold bar
            |     QUIT TO LIST               |
            +--------------------------------+ y420
```

Coach card (field stopped, bullets cleared):

```
    +----------------------------------------+ y284
    | Hold Fire to charge. Charged hits      |
    | count here; taps do not.               |
    |             [ RESUME ]                 |
    +----------------------------------------+ y404
```

### Hint surfaces (cross-reference)

Each surface is owned by its host screen; this table is the **budget** the host must reserve. All plates: Cabinet Char `#1E1B18`, 1 px edge `#5A5148` (Cream in high contrast), Cream text with 1 px outline, no focus, no button.

| Surface | Host | Rect proposed | Content | Lines | Shown when |
|---|---|---|---|---|---|
| Stage card primer | Field, stage 1 lead-in | Plate 216 x 104 at (72, 292), centred on the field at `play_top` 48; 3 rows of 28 px | 16x16 glyph + one S-tier word per row (Move, Fire, Bomb) | 1 per row | 120 ticks (`lead_in_ticks`), stage 1 only, `tutorial.complete` false, once per run; field has no enemy |
| Pause tip row | `pause.md` | **Inside the Pause plate, last row** (decided 2026-11-03): the plate is bottom-anchored at y 420 and grows upward to fit it (see `pause.md`). A separate plate under the panel was rejected (enters the lower third) | Icon 14x14 at x+6, text x+26, 296 px wide | 2 Latin / 3 Bengali | A hint is pending and eligible; absent in drills |
| Tally tip row | `stage-tally.md` | **Footer band y 600-640**: plate x 12, y 602, w 336, h 36 (all layouts 1P/2P/4P: the prompt line ends at y 600 in each) | Icon 14x14 at x+6, text x+26, 304 px wide | 2 Latin / **1 Bengali** | A hint is pending and eligible and text size step is 0 or 1; the grid never moves |
| Strip mark | HUD strip | 4 corner brackets, arm 4 px, 1 px thick, 2 px outside the element rect (needs 3 px clear on every side) | No text | — | 180 ticks, steady |

Strip mark clearances (1P rects from `hud.md`):

| Element id | Rect (1P) | Clear margin needed vs available | Verdict |
|---|---|---|---|
| `chain_plate` | (262,1,96,34) | Top: 1 px, right: 2 px | **Clipped** at the top and right; see Open Question 3 |
| `chain_bar` | inside the plate, bottom row | Plate interior | OK (bracket sits on the plate) |
| `kit_bar` | (45,33,78,4) | Bottom: reaches y 40 | **Overlaps** the boss/drill bar (24,37,312,10) |
| `lives_icons`, `bomb_icons` | (45,19,78,14), (143,19,78,14) | Top reaches y 16 | Overlaps the score rows by up to 3 px at the corners |
| `drone_pips` / `drone_lamp` | (226,22,19,6) / (247,22,5,5) | 2 px between them | The pips' right line touches the lamp's left line |

---

## States & Variants

**School session** (Tutorial States): Closed -> Lobby -> List -> Card -> Ready -> Live -> Done -> List. Live may show the Coach card or Pause.

| Variant | Trigger | What changes |
|---|---|---|
| Fresh profile | `drills_done` = 0 | No stamps; focus on `move`; header `0 / 10` |
| Partial | Some bits set | Focus on first undone required row |
| All required done | `drills_done & required_mask(plane) == required_mask(plane)` (Tutorial F3; `required_mask(plane)` = `1023 & available_mask(plane)`, so 1023 on both MVP planes) | Header `10 / 10`; focus on the first row; INFO line `tut.school.all_done` (proposal, Open Question 6) |
| Solo | `joined` = 1 | `team` row dimmed with a "2P" tag; Confirm = deny + reason |
| Plane without the events | Kit lacks `charge_last_hit` / `drone_ability_started` | Affected row hidden, not dimmed (Rule 12). **Mixed co-op:** hidden if **any** joined slot's plane lacks the event, so nobody is asked to do the impossible. The header counts `n / N` over the **visible required rows** (N = 10 when none hidden); hidden rows keep their bits untouched (see Open Question 12) |
| Loading | Card Confirm; field scene not yet ready | The 4-step wipe holds its last (full Char) frame until the field reports ready, then the Ready beat starts. If the wait passes 120 ticks (Web), a static word LOADING (S tier, centred, `tut.school.loading`, new string) shows; no spinner, no timer-driven dismiss. Input is ignored except Cancel (returns to the Card) |
| Empty list | Every row hidden (no `available` drill for the joined planes, or no `DrillDef` loaded) | Header `0 / 0`; INFO line `tut.school.empty` ("No lessons for this plane yet", new string) in the list viewport; Players and Back stay; focus starts on Players |
| Error: drill data | A `DrillDef` is missing a key or fails validation | That row is hidden and one warning is logged (see Data). If it was the card that was just opened, the Card closes to the list with a toast "This lesson is unavailable" (`tut.school.unavailable`, new string) and `sfx_ui_deny` |
| Error: save | Read-only / blocked | See "Save unavailable" below |
| Disconnect in a drill | A joined pad drops during Ready/Live/Done | Menus Rule 32 disconnect overlay opens over the stopped drill (like Pause); "Drop P{n}" removes the slot from the drill and from the completion count; the last slot dropped returns to Title; `team` falls back to its Card for one player (Tutorial Rule 22) |
| Game speed below 100 | `access.game_speed_pct` < 100 | Drills run at that speed like any stage; all drill timers are **game ticks** (Coach 1,800, co-op grace 1,800) so they stretch in real time. The HUD PRACTICE tile and the Pause PRACTICE word follow `accessibility-options.md` unchanged; Flight School adds no rule (drills are unranked regardless, see Open Question 13) |
| Co-op | `joined` >= 2 | One stamp per joined slot per row; Live: per-slot bar counters |
| Co-op partial finish | One slot done, others not | Group completes at +1,800 ticks; unfinished slots show SKIPPED |
| **2P or Compact 48 strip** | `joined` = 2, or `play_top` latched at 48 with a 3rd/4th slot Selecting/counted | The HUD has **no** stamp rect (`stamp = none`, HUD Rule 30b), so the in-strip DONE / SKIPPED is suppressed. Flight School itself shows the **per-slot result row** (above) through the Done beat and on the return to the list; the remaining in-strip signals are the drill bar reaching full stepped fill and `n/N` reaching `N/N`, and a skipped drill leaves the bar dim. 2P co-op is the most common multi-player case, so this row is not optional there (Tutorial Rule 16a) |
| Coach open | 3 resets or 1,800 ticks without progress | Drill pauses, `clear_all`, Coach card; max 2 per session, then no card |
| Pause (drill) | Start / Back | 5 items, no quit warning line, no tip row |
| Save unavailable | Read-only / blocked | Drills work; one toast "Progress will not be saved" |
| Touch | TOUCH bound | Solo; rows `touch_item_h` tall; list scrolls by drag/wheel |
| Text size 2-3 | `access.text_size` | Rows and card grow; list scrolls; Tally tip hides (Open Question 2) |
| Reduce motion / pulsing | Accessibility | Stamps appear in place; no focus pulse; bar and hold fill unchanged |

---

## Interaction Map

Input methods: gamepad (primary), keyboard, touch (solo), pointer. Verbs only (G1).

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| List | Move focus | D-pad / left stick up-down (`nav_repeat` 18/6) | Up/Down | Hover; wheel; drag | Focus border + arrow, `sfx_ui_nav_tick` | Wraps top to bottom; headers are skipped; dimmed "2P" rows are focusable (to explain why) |
| Drill row | Activate | Fire / Start | Enter, Z, Space | Click / tap | `sfx_ui_confirm`, wipe | Opens Card |
| "2P" row (solo) | Activate | Fire | Enter, Z, Space | Click / tap | `sfx_ui_deny` + toast | Nothing |
| Players | Activate | Fire | Enter, Z, Space | Click / tap | `sfx_ui_confirm` | Lobby SCHOOL mode |
| Reset progress | Hold (`confirm_style` HOLD, `confirm_hold` 40/60/90, default 60) or Double-tap ("Press again", 120 ticks) | Hold Fire | Hold Enter / Z | Press-hold | 4 segments fill; Gold on completion | Zeroes the 4 `tutorial.*` progress keys (P04). Releasing early cancels with no change |
| Back | Cancel | Bomb / Back | Esc, C | Back plate | `sfx_ui_cancel` | List -> Title; Card -> List |
| Card | Move focus | D-pad left/right | Left/Right | Hover | Focus border | Between Start (default) and Back; Up/Down also moves |
| Card | Start | Fire / Start | Enter, Z | Tap | `sfx_ui_confirm` | Ready |
| Live | Pause | Start / Back (any bound slot) | Enter / Esc | Pause button | Instant | Owner-only menu (P10); owner is the slot that pressed |
| Pause: move | Move focus | D-pad up/down | Up/Down | Hover | Focus border | Wraps; order Resume, Restart drill, Settings, Skip drill, Quit to list |
| Pause: Resume / Cancel | Activate | Fire / Bomb | Enter, Z / Esc, C | Tap | `sfx_ui_confirm` | 45-tick resume beat (P13) |
| Pause: Restart drill | Activate | Fire | Enter, Z | Tap | `sfx_ui_confirm` | Counters reset, Ready beat; no confirm |
| Pause: Skip drill | Hold or Double-tap (as Reset progress) | Hold Fire | Hold Enter / Z | Press-hold | Hold bar (P04) | List; no bit set |
| Pause: Quit to list | Activate | Fire | Enter, Z | Tap | `sfx_ui_cancel` | List at once, nothing at stake (Open Question 7) |
| Coach card | Resume | Fire / Start / Bomb | Enter / Z / Esc / C | Tap | `sfx_ui_confirm` | 45-tick beat, fail counters zero. Single focus target, so no focus movement |
| Free pad Start (Ready/Live/Done) | Press | Start | Keyboard Start key of a free scheme | | `sfx_ui_deny` + toast | "Players can join from the list" |

**Focus order (List):** first undone required row (else first row) is the default; then Up/Down walks rows in data order, then **Players**, **Reset progress**; the Back plate is reached by Cancel only (it is a pointer/touch target, not a focus stop). **Drill controls (Ready/Live):** no menu focus exists; the Pause button (touch) is the only pointer target. Nothing on a pad needs pointer precision; scroll arrows are indicators, not targets.

Drill controls themselves (move, Fire, Drone, Bomb) are the real game input. The Coach card is shared (any bound slot may Resume) because it has no owner in the GDD (Open Question 5).

## Events Fired

| Player Action | Event / Call | Payload | Persistent state? |
|---|---|---|---|
| School list opens (first time) | Sets `tutorial.school_seen` | — | **Yes**: flag for Save (written at next commit) |
| Confirm Start on Card | `DrillRunner` begins; `run_kind = DRILL` | drill id, slots | No |
| Counted event in drill | Tracker counter + bar | slot, progress | No |
| Player hit in drill | `drill_hit(slot)`, `request_invuln(slot, 120)`, chain drop (DEATH) | slot | No |
| Slot completes | `sfx_tut_drill_done` cue, DONE stamp | slot | No |
| Drill complete (Rule 22) | Sets bit in `tutorial.drills_done` | bit | **Yes** |
| Return to list after completion | `commit_settings()` once | — | **Yes** (one write) |
| Coach card opens | `sfx_tut_coach_open` cue, `clear_all` | — | No |
| Skip / Quit to list / Restart | `despawn_all`, `clear_all`, (Restart: `reset`) | — | No |
| Reset progress hold completes | Zero `drills_done`, `hint_counts`, `school_seen`, `offered` | — | **Yes** |
| Hint shown | `hint_counts` + 1 for that hint | h | **Yes** (at next commit) |
| Strip mark | `HUD.strip_mark(slot, id, 180)` | slot, id | No |
| Back to Title with a dirty profile | `commit_settings()` once | — | **Yes** (one write; amendment requested) |
| Drop P{n} / pad disconnect in a drill | Menus Rule 32 overlay; slot removed from the drill | slot | No |
| Focus move, scroll, Card open / Cancel, Players, toasts, Pause open / Resume / Restart, language change | None (UI cue sound only, no event) | — | No |

Drills never call `submit_run`, `preview_rank`, Results or name entry (Rule 8). No analytics events are defined (Open Question 10).

## Transitions & Animations

| Motion | Spec | Reduce motion / pulsing |
|---|---|---|
| Screen change | 4-step Char wipe, 12 frames | Cut |
| Card open | Same wipe (no plate slide) | Cut |
| Ready beat | 3 pips, 60 ticks (0 / 20 / 40) | Unchanged (functional) |
| Drill bar | Stepped fill, no tween; resets to 0 in one step | Unchanged |
| Zone tint | 25% by quarter, no pulse | Unchanged |
| DONE / SKIPPED stamp | Drops in over 8 frames, held 90 ticks, no flash | Appears in place |
| Done beat | 90 ticks, field keeps running, no new spawns | Unchanged |
| Row stamp on return | Appears in place (no animation) | — |
| Coach card in/out | 8-frame panel animation, stepped | Appears in place |
| Strip mark | Appears and disappears instantly; steady | Same |
| Stage card | 6-frame in/out inside the 120 ticks | Cut in/out |
| Focus | Instant; pulse <= 40%, <= 2 Hz, one element | Pulse off |

Nothing flashes. No sound on hints or marks (Tutorial V/A).

## Data Requirements

| Data | Source | Read / Write | Update trigger | Null / missing handling |
|---|---|---|---|---|
| `tutorial.drills_done` | Save (26) | R/W | On list open (read); on drill complete (write bit); on Reset | Missing = 0; bits above 10 preserved on write, ignored for completion |
| `tutorial.school_seen` | Save | R/W | Title draw (read); list open (write) | Missing = false (NEW shown) |
| `tutorial.hint_counts`, `tutorial.hints`, `tutorial.offered` | Save (26) | R/W | Hint show; Settings; Results | Missing = 0 / true / false |
| `DrillDef` list (`order`, `title_key`, `goal_key`, `tip_key`, `glyph_ids`, `min_players`, `planes`, `par_ticks`) | `data/tutorial/drills/*.tres`; owner Tutorial (30) | R | Screen open | A drill with a missing key logs one warning and its row is hidden; `available=false` hides the row |
| `HintDef`, pending hint, eligibility | Tutorial (30) `HintEngine` | R | Each Pause/Tally open; each tick for marks | No pending hint = surface absent, layout unchanged |
| Joined slots, planes, devices | Session (1) / Input (2) | R | List open; on drop | 0 slots -> Title |
| Slot identity (colour, ring, pips) | Co-op (18) / Accessibility (28) palette | R | List, HUD | Defaults |
| Text step, language, digit set | Accessibility (28), Localization (27) | R | `language_changed`, option change | English string if Bengali missing (Loc Rule 4) |
| Glyph family and binding of the last-used device | Input (2) F8 | R | Device change, remap | Generic glyphs |
| `confirm_style`, `confirm_hold` | Accessibility (28) | R | Boot, option change | HOLD, 60 |
| `hold_confirm_ticks` 60, `resume_beat_ticks` 45, `ready/done beats` 60/90 | Menus (22) / Tutorial (30) tuning | R | Boot | Defaults |
| `access.game_speed_pct`, PRACTICE latch | Accessibility (28) | R | Each tick (HUD tile, Pause word) | 100, not latched |
| Progress counters, steps (`n`, `N`) | Tutorial (30) `DrillTracker` | R | Every game tick in Live (not while paused) | Unknown step = bar empty, no numerals |
| Visible-row set (`available`, plane events) | Tutorial (30) via Plane kits (11, 29) | R | List open, on drop | None visible = Empty state |

Every element has a system owner; the screens are views over `MenuModel` and `DrillTracker` (node-free) and own no game state.

## Accessibility

Tier: COMPREHENSIVE (`design/accessibility-requirements.md`, section 5.1 "All screens" applies in full). Option behaviour follows `accessibility-options.md`.

- **Keyboard only / gamepad only:** every list, card, Pause and Coach action uses Nav/Confirm/Cancel; drills use the same flight controls as the game. Pointer is never required. Focus is visible as a 3 px Cream border plus arrow.
- **Per-slot pad maps and remaps:** Card glyph tokens show the real (possibly remapped) binding of the last-used device, so a one-handed preset or custom map is taught correctly. Fire toggle and Tap Assist work in drills; Open Question 14 covers the `hold` and `move` wording.
- **Colour-independent:** done = ring-pattern frame + check glyph + (in drill) the word DONE; SKIPPED = dash glyph; dimmed "2P" row = tag text; focus = border + arrow.
- **Text readable:** S tier 12 px Latin / 17 px Bengali minimum; Cream `#F4EBD6` on Char `#1E1B18` is about 14:1 (computed, sRGB relative luminance) with a 1 px outline. Dimmed text `#A89E8A` on Char is about 6.4:1 (above 4.5:1, below 7:1), acceptable because a dimmed row also carries the "2P" tag text and is still focusable. The plate edge `#5A5148` on Char is about 2.2:1 and is decoration only (no information rides on it); the high-contrast theme swaps edges to Cream.
- **Text size:** list, card, Coach and Pause tip follow `font_size_px(tier, step)`; layouts grow and the list scrolls (Access edge case "no text clipped"). The Tally tip is the one exception (fixed grid): it hides at steps 2-3 and the hint stays pending (Open Question 2).
- **Flashing / motion:** none. Strip marks and zones are steady; hold and ready bars are functional and stay under reduce-motion.
- **Untimed:** the list and Card have no timers; drills have none except the real Critical window; `untimed_menus` has no effect (Tutorial interactions). The 120-tick stage card is the only timed text (Open Question 4).
- **Subtitles:** no dialogue or voice in the tutorial.
- **Assist:** `game_speed_pct` works in drills like anywhere (Tutorial OQ 10); the PRACTICE tile and word follow Accessibility unchanged (Open Question 13).
- **Hold-to-confirm:** Reset and Skip use `confirm_style` (HOLD or DOUBLE_TAP) and `confirm_hold` (40 / 60 / 90 ticks) like Quit to title (`pause.md`); the "59 does nothing, 60 completes" figures in the ACs are the default.
- **Sound visual twins:** `sfx_tut_drill_done` has the DONE stamp, `sfx_tut_coach_open` has the Coach card, `sfx_ui_deny` has the toast; hints are silent.
- **Background dim / plain:** School screens use the warm hangar backdrop and obey `access.background` (plain = flat Char); the drill field obeys it like a stage.
- **Touch:** rows at least 9 mm (`touch_item_h`); Back and Start plates at least 24x24 canvas px; drills solo; glyph tokens switch to touch glyphs.
- **Screen reader / TTS:** out of scope for the in-field game and out at Vertical Slice for menus (`accessibility-requirements.md` section 4); focus order above is defined so it can be added later.

## Localization Considerations

- Menus are **single-language**; the school header, list, card, Coach, tips and stamps follow the chosen language. Dual-script is not used anywhere in Flight School (except the existing stage-card banner, which is not ours).
- Limits (English source, GDD Rule 13): drill title 28, goal 80, tip 90, hint line 90 chars. Reserve +40% width and +25% height for Bengali; Bengali may use 3 lines in goal and tip.
- **HIGH PRIORITY:** the row title column is about 214-240 px (after stamps and the "2P" tag); a 28-char English title at +40% reaches about 235 px, so Bengali titles may wrap to 2 lines: rows must grow, never clip.
- **HIGH PRIORITY:** the Tally tip band fits 1 Bengali line (about 32 characters) but the GDD limit is 90; a short Bengali variant is needed (Open Question 1).
- **HIGH PRIORITY:** Coach card at 120 px holds exactly 3 Bengali lines + button at step 0; it must grow at higher steps.
- Max lengths for strings this spec adds (English source; Bengali uses measured width): group name 12; `tut.school.title` 16 (header, L tier, one line beside the chips); toast / reason lines 40 (one line at 328 px, S tier; Bengali may wrap to 2 lines in the 24 px strip only at step 0, otherwise the toast grows upward); `tut.school.reset_warn` 36; `tut.school.empty` 40; DONE 6; SKIPPED 9 (in the HUD column, which does not grow: see HUD owner, Open Question 9); LOADING 10; Card button labels 16.
- `n/N` numerals and the `n / 10` header use `format_int` (Bengali digits on the same grid). "P1".."P4" and key names stay Latin. Year-like numbers are not used.
- Glyph tokens are arguments, not text (`{glyph}` convention, Loc Rule 5). Group names (Flight, Guns, Chain, Boss, Together), "2P", DONE, SKIPPED, and the new strings in Open Question 8 need keys and drafts. All Bengali is draft until native review (suggested school title: উড়ান প্রশিক্ষণ).
- Language change on a Card or Coach card re-renders next frame; the progress numerals do not move.

---

## Acceptance Criteria

- [ ] Title FLIGHT SCHOOL opens the Lobby in SCHOOL mode; after all joined slots lock and 45 ticks pass, the School list opens; Cancel on the list returns to Title.
- [ ] The list shows 5 group headers and 11 rows in order: Move and slow down, The tiny hitbox, Tap to shoot, Hold to charge, Pods and drones, Keep the chain alive, Gems medals and chain pickups, Bombs and the chain toll, Boss parts and the core, The Critical Break, The team chain.
- [ ] With `drills_done` = 0 focus starts on row 1; with bits 0-2 set it starts on row 4; with 1,023 it starts on row 1; a row with its bit set shows a ring-pattern frame with a check glyph per joined slot, an unset row an empty frame.
- [ ] Solo: the team row is dimmed with a "2P" tag; Confirm plays `sfx_ui_deny`, shows a one-line reason and does not change screen; with 2 joined slots it opens.
- [ ] The Title NEW tag shows until the list has been opened once; after opening the list, leaving to Title **without completing a drill** and restarting the game it is gone (one `commit_settings()` on leaving to Title); after Reset progress (default hold 60 ticks; 59 does nothing; with DOUBLE_TAP a second press within 120 ticks) it returns.
- [ ] The Drill card shows title, goal and 1-3 glyph tokens inside (16,120,328,360); Cancel returns to the list with the same row focused; Confirm starts the Ready beat (3 pips over 60 ticks) and planes are not hittable until Live.
- [ ] During Live no text node exists inside the play field (scene scan below `play_top`: 0 Labels); the HUD strip shows the drill bar with `n/N` numerals and the group icon.
- [ ] In the `hitbox` drill a hit with 3 walls passed: lives are unchanged, no game over, the bar returns to `0/5` on the next frame, the chain (if any) drops.
- [ ] When a slot completes the condition, its column shows DONE (word + check + ring pattern) for 90 ticks; the list then opens with the row stamped and exactly one Save write occurs.
- [ ] Drill Pause lists, in order, Resume, Restart drill, Settings, Skip drill (hold), Quit to list inside a 216-wide panel anchored at bottom y 420 (208 high at step 0, growing upward at higher steps, never below y 420 and never over the HUD strip) with no clipping in English and Bengali at text step 0 and 3; no "Score will not be saved" line appears.
- [ ] Skip drill held 59 ticks does nothing; at 60 the list opens with no bit set. Restart drill returns to Ready with counters at 0. Quit to list opens the list at once.
- [ ] After 3 resets without progress the drill pauses, enemy bullets are cleared, and the Coach card (296 wide) appears; Resume runs a 45-tick beat; a third card in the same session does not appear.
- [ ] 2P: P1 completes at tick T and P2 does not; at T + 1,800 the drill completes, P2 shows SKIPPED, the bit is set and P2's list stamp follows the profile bit.
- [ ] A free pad pressing Start in Ready/Live/Done plays `sfx_ui_deny`, shows "Players can join from the list" and does not join.
- [ ] In a normal run with a hint pending, the Pause tip is the last row inside the Pause plate (296 px text width, 2 Latin / 3 Bengali lines), the plate grows upward and its bottom stays at y 420, the row never takes focus (Down from the last item wraps to Resume); in a drill Pause no tip row exists.
- [ ] With a hint pending the Tally tip plate occupies y 602-638 in 1P, 2P and 4P, and a pixel diff of the rest of the Tally with and without the tip is zero.
- [ ] A strip mark draws four corner brackets around the requested element for exactly 180 game ticks (paused ticks do not count), contains no text and never covers a bullet pixel.
- [ ] The stage card primer shows for 120 ticks in stage 1 only while the school is incomplete, with no enemy alive, in a plate at (72,292,216,104).
- [ ] Every screen renders without clipping at 360x640, 1080x1920 and 1440x2560 (4x), and the list scrolls so the focused row is always inside y 44-556.
- [ ] The list, Card, Coach card and drill Pause are fully operable with a gamepad only and with a keyboard only; no screen element changes brightness by more than the focus pulse (<= 40%, <= 2 Hz, off under reduce pulsing) and there is no full-screen flash.
- [ ] Focus order: from the default row Down visits rows in data order, then Players, then Reset progress, then wraps to the first row; headers and the Back plate never take focus; on the Card Left/Right toggles Start and Back with Start focused first.
- [ ] Glyph tokens on the Card show the binding of the last-used device: with a remapped Fire on a PlayStation pad the token shows that pad's glyph for the new button; on keyboard it shows the key name.
- [ ] Empty state: with every row hidden the list shows `0 / 0`, the empty line, and focus on Players; Back still returns to Title. Loading state: a Card Confirm whose field is not ready holds the Char frame; after 120 ticks LOADING shows; Cancel returns to the Card.
- [ ] A pad disconnect during Live opens the disconnect overlay over the stopped drill; "Drop P2" in a 2P drill continues for P1 and the completion count becomes 1; dropping the last slot returns to Title.
- [ ] With `game_speed_pct` 70, a drill runs at 70% speed, the Coach timer still counts 1,800 game ticks, and the list and Card are unchanged.
- [ ] At text steps 0 to 3, in English and Bengali, list rows, Card, Coach card and drill Pause grow without clipping, the list scrolls with the focused row inside y 44-556, and the Back plate is at least 24x24 px.
- [ ] Performance: list navigation holds 60 fps on REF-WEB with no per-frame allocation after warm-up; tracker + runner + hint engine together cost 0.05 ms per tick or less (Tutorial AC-44).

---

## Open Questions

1. **Tip rows (decided 2026-11-03 under auto-approve, art-director to confirm):** Pause tip sits inside the bottom-anchored Pause plate (`pause.md`); Tally tip uses the footer band y 600-640 with the fit rule in `stage-tally.md` (2 Latin lines or 1 Bengali line, otherwise deferred to the next Pause). Original analysis: Proposal above: Pause tip = separate 328-wide plate 8 px under the panel (h 40 / 80); Tally tip = footer band y 602-638. Conflicts: Tutorial Rule 27 says "one line" in the Tally while its V/A says "two lines (three Bengali)"; the band holds 2 Latin lines but only **1 Bengali line** (a 2-line Bengali tip needs 54 px, 36 available). Recommended: add a short Bengali variant (`tut.hint.<id>.tally`, <= 32 chars) or free 18 px in the Tally footer. Owners: game-designer (Tutorial), ux-designer (Tally, Pause).
2. **Text size 2-3.** The Pause tip plate would need 128-276 px; the Tally grid cannot grow. Recommend: Pause tip scrolls with the panel (Menus Rule 51); Tally tip hides and the hint stays pending (not counted as shown, F5).
3. **Strip mark clearance.** `chain_plate` has 1 px above and 2 px right of it, `kit_bar` brackets overlap the boss/drill bar. Recommend: brackets are drawn inset (inside the rect edge) when less than 3 px is free, or HUD adds a 3 px margin to those rects. art-director / HUD owner.
4. **Stage card is 2 s.** `lead_in_ticks` 120 is short for Bengali; stage 1 with the primer could use 180 (Director knob), or the primer could persist until the first wave starts. game-designer.
5. **Coach card ownership.** The GDD says "like a Pause panel" but names no owner. Proposed: any bound slot may Resume. Confirm.
6. **Gaps in the GDD flow:** (a) the list is only reachable through the Lobby, even to browse; (b) focus after a drill: Rule 6 says "first undone required row" (used here), P05 says restore the opener; (c) no "all done" message exists (`tut.school.all_done` is a proposal); (d) per-slot stamps vs one shared profile bit (Rules 6, 22, 24): the list can only show the shared bit, SKIPPED exists only in the drill; (e) Rule 13 says the tip is hidden, Rule 17 says the third time "the tip is only on the Card". Proposal: the Card gets a tip block only after the Coach cards are used up in the session.
7. **Quit to list without a hold** (Tutorial OQ 8) is kept. Restart drill also has no confirm.
8. **New strings needed:** `tut.school.reset_warn` ("Clears lesson stamps and tips"), `tut.school.all_done`, `tut.group.*`, "2P" reason line, "Players can join from the list" (exists in the GDD, key missing), glyph-token action words on the Card.
9. **DONE stamp size.** HUD owns the column; proposed rect is the existing pick plate (84x44) in compact and 3-4P columns. HUD owner to place it in 1P/2P.
10. No analytics events (drills started, completed, Coach opened) are defined; no player journey doc exists (see `main-menu.md` Open Questions 2-4).
11. **Bar numerals for multi-part goals** (`drones`: 2 pods, 1 press, 6 hits; `items`: gems, medal, chain pickup) need one defined `n/N` rule per step.
12. ~~**Hidden required rows vs `complete`.**~~ **CLOSED 2026-11-03 (wave 5 batch 2).** The game-designer adopted the **per-plane mask**: Tutorial F3 is now `required_mask(plane) = 1023 & available_mask(plane)` and `complete(plane) = (drills_done & required_mask(plane)) == required_mask(plane)`, with `tutorial.complete` the OR over planes, so a Sentry-only or Breaker-only pilot can finish the school. `drills_done` stays one profile-wide bitmask. Authoring plane-specific replacement drills was rejected. The UX decision in this spec (**header counts visible required rows**) is consistent with it and stands. See Tutorial Open Question 11 (closed) and Rule 12.
13. **PRACTICE in drills.** Unknown whether `run.assisted` latches in a `DRILL` run and whether the Pause word PRACTICE should show there; drills are unranked anyway. Accessibility owner to confirm; this spec adds no rule.
14. **Wording for Fire toggle / Tap Assist.** The `hold` and `move` step B goals say "hold Fire"; with `fire_toggle` the card word could read "Fire (toggle)". Not specified by Input; confirm with the Input owner.
15. ~~**Per-plane tip text.**~~ **ANSWERED 2026-11-03 (wave 5).** Tutorial Rule 13 now requires `goal_key` / `tip_key` text to be **plane-neutral**, or else per-kit keys **`tut.drill.<id>.tip.<kit>`** resolved by the slot's plane; no drill string may name one kit's mechanic (Lancer laser, Leech focused shot, Sentry Entrench, Breaker Breach). The Coach card uses the same resolved key. **Remaining:** if per-kit keys are chosen, `localization.md` Rule 5 must register the `.tip.<kit>` variant alongside `tut.drill.<id>.title/goal/tip` (localization owner).
16. **Title list overflow (cross-document).** With FLIGHT SCHOOL the Title list has 6 items (212 px from y 392, ends y 604) and overlaps the prompt bar at y 600. `main-menu.md` owns it (its Open Question 1); the proposed fix is in the review report (amendment 1). Until applied, do not build the Target Title list.
