# UX Spec: Pause (Pause Menu + Disconnect Overlay + Resume Beat)

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring, pending `/ux-review`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Journey Phase(s)**: Every run; co-op night (see `design/player-journey.md`)
> **Platform Target**: PC (Steam/itch), Web, iOS, Android, Switch. Gamepad primary, keyboard first-class, touch partial (Pause button on the strip), pointer on Web/PC
> **Template**: UX Spec
> **Sources**: `design/gdd/menus-title-plane-select.md` (Rules 27-33, 45, 52; F6, F9; V/A table and Pause/Disconnect mock-ups; AC-27..35; edge cases), `input-and-player-mapping.md` (Rules 25-33, 12, 19), `touch-controls.md` (Rules 7, 11, 17), `tutorial.md` (Pause tip row, drill pause items), `accessibility-options.md`, art bible 6.8, 7.8. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P01, P02, P03, P04, P05, P08, P10, P11, P13, P21, P22 (see `interaction-patterns.md`)
> **Style**: `arcade-ui-style.md`
> **Revision 2026-11-03**: fixes from `/ux-review`. Decided under auto-approve: hold-to-confirm uses **Fire only** (Start always resumes); the plate grows **upward** when a tip row is shown; `confirm_style` / `confirm_hold` mapped; pausable windows listed. Two GDD amendments needed (Menus F6, Menus V/A pause panel), see Open Questions 2 and 5.

---

## Purpose & Player Need

The player arrives wanting to **stop the game safely**, then either **carry on exactly where they were** or **leave**. Pause must be (a) instant, (b) clear about **who** paused in a co-op game, (c) honest that quitting loses the score, and (d) give the player a beat to get their hands back before bullets move. The Disconnect overlay serves the same purpose when a pad drops: the game is already stopped and the player needs to decide how to get their plane back.

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| USER pause (Start/Back) | Interrupted, possibly mid-dodge, possibly stressed | The field is frozen with bullets visible |
| FOCUS pause (window blur) | Surprised | Not caused by the player's action; never auto-resumes |
| DISCONNECT pause | Annoyed, flustered | May have lost a controller mid-boss; the other players are waiting |
| Co-op | Mixed | Non-owners are watching someone else's menu |

Players arrive both voluntarily (USER) and involuntarily (FOCUS, DISCONNECT).

## Navigation Position

`Stage / Tally -> **PAUSE** -> Resume | Settings (-> back to Pause) | Quit to title`. The Disconnect overlay opens **over** the Pause menu (or on its own). Pause is only reachable while a Stage or Tally is active; it is not available in Title or Lobby (Lobby pad loss gets a toast and no pause). In a Flight School drill the items differ (see States).

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Stage / Tally (USER) | `start` or `back` pressed by any **bound** slot; touch Pause button | That slot becomes the **owner** |
| Window focus loss (FOCUS) | Tab blur, alt-tab, minimise, app backgrounding | Owner = lowest connected bound slot |
| Pad disconnect (DISCONNECT) | `joy_connection_changed` for a Selecting / Alive / Dead / Continue slot | Slot becomes **Waiting** |
| Touch: landscape rotation | Device rotated | "Rotate your phone upright" (separate prompt, not this menu) |
| Touch: app backgrounded / system gesture | All fingers released | Pause requested if Playing |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Stage / Tally | Resume (Confirm on Resume, Cancel, or Start) by the owner, then the 45-tick resume beat | The press that closed the menu is consumed; held buttons report `held = true, held_ticks = 0` |
| Settings (over Pause) | Confirm on Settings | Same Settings screen as Title; closing commits once if dirty |
| Title | Hold Confirm on Quit to title for 60 ticks | Run **ABANDONED**; nothing is saved; bindings cleared |
| Forfeit | Hold Confirm on "Drop P{n}" (disconnect overlay) | `forfeit_slot(slot)`; the run continues for others |
| (Flight School) Skip drill / Quit to list | Item | Drill pause only |

Exits that cannot be undone: Quit to title (score is lost) and Drop P{n}.

**When pause is available** (Accessibility Rule 31, Input Rule 25): any time in Stage and Tally, including the Continue countdown (it freezes), the WARNING banner, the boss intro and the fly-in. **Not pausable:** the 12-frame Char hold between Lobby and stage load, and Results name entry. Start during those moments does nothing.

---

## Layout Specification

### Information Hierarchy

1. **Who paused / whose menu is this?** (owner tag with slot frame, ring pattern, pips, "P{n}")
2. **That the game is stopped** ("PAUSED" title; frozen field)
3. **Resume** (default focus)
4. **Settings**
5. **Quit to title**, with its consequence ("Score will not be saved")
6. Pause reason line (only FOCUS / DISCONNECT): "Paused - window lost focus"
7. One tutorial tip row (optional, never takes focus)

### Layout Zones

Canvas 360x640. Panel positions from the Menus V/A table.

| Zone | Rect (canvas px) | Contents |
|---|---|---|
| Live HUD strip | y 0-47 | **Unchanged and frozen**; never covered |
| Frozen field | y 48 onward | Bullets visible, **no dim, no tint** |
| Pause panel | 216 wide, centred. Default 216 x 192 at top y 224 (bottom y 416). **Bottom-anchored plate (decided 2026-11-03, one rule for every Pause variant):** the plate's bottom edge stays at y 420 (out of the lower third, y 427+) and its height follows its content: base menu, FOCUS reason line, drill items (5 items, Flight School), tip row (Latin 2 lines about 36 px, Bengali 3 lines about 76 px). The top moves up as needed but never above y 56 (8 px under the HUD strip); if content still does not fit (large text steps), the item list scrolls (P26) and the tip row stays visible. | Owner tag 90x20 with slot frame; "PAUSED"; 3 items (3 x 32 + 2 x 4 = 104); warning line; reason line; tip row (icon + 2 lines Latin 12 px = 32 px; 3 lines Bengali 17 px = 72 px) |
| Disconnect panel | Centred plate (size by rows) | One block per Waiting slot |
| Resume beat | Centred, three pips | 45 ticks |
| Toast | y 560 | 328x24 |
| Prompt bar | y 600-640 | Glyph + verb pairs for the **owner's** device |

Menus draw on a CanvasLayer above layer 11. Pause covers the frozen field only while the simulation is stopped. The art bible does not yet allow this (Open Question 1).

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|
| Owner tag | Badge | No | P08, P10 | Slot colour frame + ring pattern + pips + "P{n}" |
| Title "PAUSED" | Text | No | P23 | `menu.pause.title` |
| RESUME | BUTTON | Yes | P01, P03 | Default focus |
| SETTINGS | LINK | Yes | P03, P05 | Opens Settings over Pause |
| QUIT TO TITLE | HOLD_BUTTON | Yes | P04 | 4-segment hold bar (12x6 each); "Score will not be saved" beside it |
| Reason line | Text | No | — | FOCUS: "Paused - window lost focus"; USER: none |
| Tip row | Info | No (no focus) | — | Icon 14x14 + up to 2 lines (3 in Bengali) when a hint is pending |
| Disconnect row (per Waiting slot) | Group | Yes | P10 | Slot frame + "Reconnect controller for P{n}" + options below |
| Reconnect | INFO | No | — | "Press START on a controller" (resolved by Input) |
| Use keyboard | BUTTON | Yes | P22 | Only if a keyboard scheme is free: "Press Enter / 1" |
| Drop P{n} | HOLD_BUTTON | Yes | P04 | Calls `forfeit_slot` |
| Wait | BUTTON | Yes (default) | P01 | Nothing happens; stays paused |
| Resume beat pips | Feedback | No | P13 | 3 pips lit at 0 / 15 / 30 ticks |
| Back plate | Button | Pointer/touch | P05, P06 | At least 24x24 |

### ASCII Wireframe

USER pause by P2 in a 2P stage:

```
+----------------------------------------------------------+
| HUD STRIP (P1 | P2) -- frozen                            | y0-47
|                                                          |
|          (frozen play field, bullets visible)            |
|            +--------------------------------+            | y224
|            | [P2 dashed frame, 2 pips]      |            | owner tag
|            |            PAUSED              |            |
|            |  >  RESUME                     |            |
|            |     SETTINGS                   |            |
|            |     QUIT TO TITLE   [----]     |            | hold bar (4 steps)
|            |   Score will not be saved      |            |
|            +--------------------------------+            | y416
| P1 controls dimmed                                       |
| [A] Select   [B] Resume                                  | y600
+----------------------------------------------------------+
```

DISCONNECT (P2 pad lost):

```
|        +------------------------------------+            |
|        | Controller disconnected            |            |
|        | P2 (dashed frame)                  |            |
|        |  Reconnect: press START on a pad   |            |
|        |  Use keyboard: press Enter / 1     |            |
|        |  Drop P2        [----]  (hold)     |            |
|        |  > Wait                            |            |
|        +------------------------------------+            |
```

Resume beat (after Resume): `[ o . . ]` -> `[ o o . ]` -> `[ o o o ]` -> game runs.

---

## States & Variants

**Pause state machine:**

| State | Meaning | Next |
|---|---|---|
| Closed | Game running | Open |
| Open (USER / FOCUS / DISCONNECT) | Menu shown, owner set | Settings, QuitHold, Beat, Closed |
| Settings | Settings over Pause | Open (commit once on close if dirty) |
| QuitHold | Quit being held | Open (released early) / Abandon (60 ticks) |
| Beat | 3-pip beat, tree paused | Closed (45 ticks) |

**Variants:**

| Variant | Trigger | What changes |
|---|---|---|
| USER | Start / Back / touch Pause | Full menu |
| FOCUS | Window blur | Same menu + line "Paused - window lost focus"; never auto-resumes on refocus |
| DISCONNECT | Pad lost | Overlay over the menu; Resume refused while any slot is Waiting |
| Several pads lost on one tick | USB hub | One overlay lists all Waiting slots; each resolves independently |
| Owner disconnects | Owner's pad lost | Ownership passes to the lowest connected bound slot |
| Non-owner presses Start | | Ignored; their tag stays dimmed; no error sound |
| Tip pending | `HintEngine` hint eligible | Tip row under the items |
| Flight School drill | Pause in a drill | Items: Resume, Restart drill, Settings, Skip drill (hold), Quit to list |
| Continue active | Owner's slot in Continue | Continue countdown freezes |
| Touch | TOUCH bound | Owner is always P1; hold bar must be reachable by thumb (Open Question 4) |
| Settings save fails | `save_failed` on close of Settings | Toast with the Save reason (never dropped); values stay applied for this session |
| Unpausable moment | Lobby->stage Char hold, name entry | Start ignored; no menu |
| Resume beat disabled | `resume_beat_ticks = 0` | Game runs at once |
| Debug build | Dev only | Restart (F5) exists; absent in release |
| Reduce motion / pulsing | Accessibility | No focus pulse; hold bar still fills (functional) |

---

## Interaction Map

Owner-only. Gamepad primary (full), keyboard, touch (partial), pointer.

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Pause (open) | Press | Start / Back (any bound slot) | Enter/1 / Esc | Pause button (touch) | Menu appears instantly; pause cue | Opens with that slot as owner |
| Items | Move focus | Owner's D-pad up/down | Owner's keys | Tap / hover | Focus border + arrow | Wraps |
| RESUME | Activate | Fire / Start | Confirm | Tap | Confirm sound | Resume beat |
| (anywhere) | Cancel | Bomb / Back / Start | Esc / C | Back plate | | Resume beat |
| SETTINGS | Activate | Fire | Confirm | Tap | | Settings screen |
| QUIT TO TITLE | Hold | Hold **Fire** (Start resumes, never holds) | Hold Z / Space (KB1), F (KB2) | Press-and-hold | 4 hold segments fill; completion frame Ember Gold | `abandon_run()`, Title loads |
| Use keyboard | Activate | | Enter (KB1) / 1 (KB2) | | | Slot rebinds to keyboard |
| Drop P{n} | Hold | Hold Fire | Hold confirm | Press-and-hold | Hold bar | `forfeit_slot(slot)` |
| Wait | Activate | Fire | Confirm | Tap | | Nothing |
| Reconnect | Press Start | A pad (matching GUID or unbound) | | | | Binds pad to the slot; "Press Start to resume"; stays paused |

Other slots' presses are ignored while paused; their tags dim. Pad movement and `start`/`back` are not remappable (Input Rule 34).

## Events Fired

| Player Action | Event / Call | Payload | Persistent? |
|---|---|---|---|
| Open pause | Tree paused; reason set | owner slot, reason | No |
| Resume | Resume beat then un-pause; Input re-arms held buttons (Input Rule 27) | — | No |
| Quit hold completes | `GameSession.abandon_run()`; `run_ended_by = ABANDONED`; **Save is not called**; bindings cleared | — | **Yes**: run is discarded; high-score data must stay byte-identical (Session AC-35) |
| Drop P{n} | `forfeit_slot(slot)` | slot | Yes (slot -> Inactive, record kept) |
| Settings change | `set_setting` live; `commit_settings()` once on close if dirty | key, value | **Yes** (one write at most) |
| Window blur | Pause (FOCUS) | | No |
| Pad disconnect | Pause (DISCONNECT), slot -> Waiting | slot | No |

No analytics events defined (Open Question 7).

## Transitions & Animations

- **Open:** instant (no animation) so the player is never confused about whether the game stopped.
- **Close:** hands over to the resume beat.
- **Resume beat:** three pips over 45 ticks: 0 lit for ticks 0-14, 1 for 15-29, 2 for 30-44, game ticks at 45. A second Resume press during the beat is ignored. Always runs after any pause reason. No invulnerability is granted (Collision owns that).
- **Hold bar:** 4 stepped segments (`segments = 4 x min(held, 60) div 60`), no tween; gold on the completion frame. Releasing early resets to 0. Not removed under reduce-motion.
- **Focus:** 3 px Cream border + arrow; pulse off under reduce-pulsing.
- **Owner-change:** tag swaps in one frame.
- **No full-screen dim and no tint** on the field.

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Pause owner, reason | Input (2) | Read | Owner changes on disconnect |
| Slot states (Waiting etc.) | Input (2) / Session (1) | Read | |
| Slot colour, ring pattern, pips | Co-op (18) / Accessibility palette | Read | |
| Pending tip | Tutorial (30) `HintEngine` | Read | Shown only if eligible; max two views per tip |
| Drill mode | Tutorial (30) | Read | Changes items |
| Settings values | Save (26) | Read/Write | `commit_settings` once on close if dirty |
| `hold_confirm_ticks` (60), `resume_beat_ticks` (45) | Menus tuning | Read | |
| Glyph family of the owner's device | Input (2) | Read | Prompt bar |

## Accessibility

- **Gamepad path:** Start/Back opens; Up/Down moves; Fire activates; Back or Start resumes. Every action is available on the owner's own device.
- **Keyboard path:** Enter/1 or Esc open; the same verbs navigate.
- **Colour-independent:** owner = P-tag text + ring pattern + pips + colour; disabled tags are dimmed *and* the owner is named.
- **Contrast:** Cream text with outline on Cabinet Char plate; high-contrast option applies.
- **Hold-to-confirm:** applies `access.confirm_hold` (SHORT 40 / NORMAL 60 / LONG 90 ticks) and `access.confirm_style` (HOLD default, or DOUBLE_TAP: first press shows "Press again" for 120 ticks, a second press confirms, a press elsewhere cancels) to **Quit to title, Skip drill and Drop P{n}** (Accessibility GDD option table and edge cases).
- **Timing:** nothing on Pause is timed except the resume beat (disable with 0) and hold. `access.untimed_menus` does not apply.
- **Motion:** beat pips and bar are stepped; no flashing.
- **Co-op fairness:** non-owners see the menu but cannot act; their feedback is the dimmed tag, not an error sound.
- **Screen reader:** no stance exists for the game (pattern library gap 7).

## Localization Considerations

- "QUIT TO TITLE" / "শিরোনামে ফিরুন" must fit the 216 px plate beside the hold bar (12x6 x 4 + spacing) on one line; **HIGH PRIORITY**.
- "Score will not be saved" / "স্কোর সংরক্ষিত হবে না" and "Paused - window lost focus" / "বিরতি - উইন্ডো সক্রিয় নয়" are the longest strings; the 192 px panel height may be exceeded when they wrap to 2-3 lines in Bengali (**HIGH PRIORITY**).
- Disconnect strings ("Reconnect controller for P{n}", "Press START on a controller", "Press Enter / 1") are not in the draft string table; they need keys and Bengali drafts.
- `{n}` and key names (Enter, 1) stay Latin.
- Tip row allows 3 lines in Bengali, which increases the panel height.
- Bengali strings are drafts awaiting native review (Menus Open Question 7).

---

## Acceptance Criteria

- [ ] Pressing Start/Back during a stage freezes the game within the same frame and shows the menu with RESUME focused; no Restart item exists in a release build.
- [ ] In a 2P game P2 pauses: the owner tag shows P2's dashed frame and two pips; P1 pressing Confirm does nothing and P1's tag is dimmed.
- [ ] If the owner's pad disconnects, ownership passes to the lowest connected bound slot and the disconnect overlay opens.
- [ ] Holding Confirm on Quit to title for 59 ticks fills 3 segments and does nothing; at 60 ticks it quits once; releasing at 59 resets to 0.
- [ ] After quitting with a score of 900,000, the high-score list is unchanged and Title loads.
- [ ] After Resume, three pips light over 0.75 s, the game then runs, and pressing Resume again during the beat is ignored.
- [ ] Holding Fire through a pause and resume: on the first game tick Fire is held but not newly pressed, and the Start press that closed the menu does not fire a shot.
- [ ] Window blur pauses the game, shows "Paused - window lost focus", and the game stays paused after refocus until the owner resumes.
- [ ] In 2P unplugging P2's pad pauses the game with an overlay row for P2 only; Resume is refused while P2 is Waiting; Drop P2 (held 1 s) forfeits P2 once; Wait changes nothing.
- [ ] Changing sound volume in Settings from Pause and closing writes the settings file exactly once; closing with no change writes zero times.
- [ ] The HUD strip (y 0-47) is pixel-identical before and after opening Pause, and the field behind the panel is not dimmed or tinted.
- [ ] Every Pause action is reachable with the owner's gamepad only, and again with the keyboard only.
- [ ] With `reduce_pulsing` on, focus does not pulse; the hold bar still fills.
- [ ] In Bengali, no string in the Pause panel or disconnect overlay is clipped at the largest text step.
- [ ] Touch: the Pause button opens the menu and every row is at least 9 mm tall.
- [ ] At 360x640 x1 and x3, the pause plate (with and without a tip row, in both languages) never reaches below y 420 and never covers the HUD strip (y 0-47).
- [ ] With `confirm_style` DOUBLE_TAP, Quit to title needs two presses within 2 s and shows "Press again" after the first; with `confirm_hold` LONG the hold takes 1.5 s.
- [ ] Holding Start on Quit to title resumes the game on the first press and never starts the hold.

---

## Open Questions

1. **Panel over frozen bullets.** The art bible has not ruled on covering the lower field with a Pause panel (Menus Open Question 2); the panel is proposed as an exception while the simulation is stopped. art-director decision required.
2. **Start conflicts with hold (decided under auto-approve, GDD amendment needed).** Menus F6 counts `fire.held_ticks` **or** `start.held_ticks`, but a Start press on Pause resumes (Rule 28). Decision: on Pause and the disconnect overlay, holds count **Fire only**; Start always resumes on press. Amend Menus F6 to say so.
3. ~~`confirm_style` / `confirm_hold` mapping~~ **Answered** by the Accessibility GDD: they apply to every HOLD_BUTTON (see Accessibility).
4. **Touch Quit hold.** A held thumb on a 12 mm item hides its own hold bar; consider placing the bar beside the item and giving Quit a larger target. Not covered by the Touch GDD.
5. **Panel height budget (decided under auto-approve, art-director to confirm).** Base content is about 176-188 px. Drill Pause (5 items) needs about 248 px, a Bengali tip adds about 76 px. **Bottom-anchored plate (decided 2026-11-03, one rule for every Pause variant):** the plate's bottom edge stays at y 420 (out of the lower third, y 427+) and its height follows its content: base menu, FOCUS reason line, drill items (5 items, Flight School), tip row (Latin 2 lines about 36 px, Bengali 3 lines about 76 px). The top moves up as needed but never above y 56 (8 px under the HUD strip); if content still does not fit (large text steps), the item list scrolls (P26) and the tip row stays visible. Worst case (drill + FOCUS line + Bengali tip) is about 340 px: top y 80. Amend Menus V/A "Pause panel" row. The Flight School spec's earlier idea of a separate tip plate under the panel was rejected because it enters the lower third.
6. **Disconnect overlay size.** Up to 4 Waiting slots x (title + 4 options) will not fit one plate; define stacking or a compact two-option layout when 3+ slots are Waiting.
7. Disconnect and tip-row strings are missing from the string table.
8. No analytics events are defined for pause (frequency of pausing, quit rate) if telemetry is wanted.
9. Co-op "ghost" pause: a non-owner who needs to pause for a different reason must wait for the owner; consider whether the owner can hand the menu over.
10. ~~Journey map / accessibility tier missing~~ **Closed 2026-11-03:** `design/player-journey.md`; tier Comprehensive (`design/accessibility-requirements.md`).
