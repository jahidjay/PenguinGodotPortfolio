# UX Spec: Credits

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved authoring, `/ux-review` fixes applied 2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (final doc closeout)**: UI cue ids rewritten to the canonical `sfx_ui_*` form (`design/gdd/audio.md` owns the ids; consistency-report C1).
> **Revision 2026-11-03 (UX consistency check, wave 5)**: Open Question 8 closed (both keys registered in `localization.md` Rule 5a); Open Question 7's storage half answered by Menus Open Question 15 (inline `body` on a `kind = LICENCE` record in `credits.tres`).
> **Journey Phase(s)**: unknown (no `design/player-journey.md`)
> **Template**: UX Spec
> **Platform Target**: PC, Web, Switch, iOS/Android. Gamepad primary, keyboard full, pointer/touch partial. Canvas 360x640.
> **Sources**: `design/gdd/menus-title-plane-select.md` (Rules 8, 12-16, 46; Tuning `credits_px_per_s`; Open Question 15; Screens table), `audio.md` (licence rules: CC-BY must be credited), `accessibility-options.md`, `accessibility-requirements.md` (Section 5: Credits), `localization.md`, `arcade-ui-style.md`. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P01 (shared screen), P05, P06, P21, P23, P26 (see `interaction-patterns.md`). P02 is not used (no focusable items, see Focus Order). Gap 4 (credits scroller) is answered here as proposals.
> **Revision 2026-11-03 (UX amendments wave 5)**: Menus Rule 46 amendment applied in the GDD (manual scroll, resume, `reduce_motion` manual mode, end at viewport centre, Start = Confirm, licence not localised), so Open Question 1 is closed; the new string keys are registered in the Menus string table (Open Question 8); the S-tier line-pitch arithmetic is corrected.
> Revised 2026-11-03 after /ux-review: added loading, error and licence-failure states; manual scroll and pause for pad and keyboard; reduce_motion turns auto-scroll off; Start no longer exits; end position defined; owners on every data row; focus order, chevrons, character limits, licence-not-localised rule, contrast ratios, screen-reader stance; ACs extended.

---

## Purpose & Player Need

The player wants to **see who made the game and what it uses**, then leave. It is a calm, optional screen; it must be readable at a comfortable pace (the player can always stop or slow the text), quick to leave, and legally complete (licence credits for fonts and music).

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| Title -> CREDITS | Curious, relaxed | No time pressure; may be a friend, a fan or a reviewer |
| Co-op group | Social, reading aloud | Any device may use the screen (shared, Rule 8) |

## Navigation Position

`TITLE -> **CREDITS** -> TITLE`. No other entry. Not reachable from Pause or a run.

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Title | Confirm on CREDITS | Language, text step, `reduce_motion` |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Title | Cancel (Bomb / Back / Esc / C) or Back plate | Focus returns to CREDITS (P05); nothing is saved. Same in every state, including Empty and Error |

No timeout, no auto-exit and no attract mode on this screen (attract belongs to Title only, Menus Rule 11); the screen stays open indefinitely, which satisfies `access.untimed_menus` without reading it.

---

## Layout Specification

### Information Hierarchy

1. **Names and roles** being read now (centre of the viewport).
2. **Section headings** (Design, Programming, Art, Music and sound, Fonts and licences, Thanks).
3. Screen title "CREDITS".
4. Prompt bar (Fire = faster, Up/Down = scroll, Cancel = back).

### Layout Zones

| Zone | Rect (canvas px) | Contents |
|---|---|---|
| Header | y 0-40 | `menu.title.credits` (L tier), single-language |
| More-above chevron | 4x4 at (178, 42) | P26 chevron, drawn while offset > 0 |
| Viewport | x 16, y 48, 328 x 544 (to y 592) | Scrolling list, clipped at both edges (no fade) |
| More-below chevron | 4x4 at (178, 594) | P26 chevron, drawn while offset < end offset |
| Back plate | (8, 8, 24, 24) pointer/touch only | At least 24x24 |
| Prompt bar | y 600-640 | Glyph + verb pairs: faster (hold Fire), scroll (Nav up/down), back |

Line height: S tier, **20 px** for Latin, Bengali 24 px (17 px x 1.4). *(Corrected 2026-11-03, wave 5: the old parenthetical "12 px x 1.2, rounded up" was wrong arithmetic - 12 x 1.2 = 14.4, which rounds to 15, not 20. The 20 px pitch is kept as the authored value for reading comfort in a scrolling roll; it is **not** derived from the 1.2 multiplier. The canonical line-pitch base is `arcade-ui-style.md` Open Question 3; if that question sets a derived pitch, this number follows it - see Open Question 9.)* Section heading: M tier, 8 px extra above, Cream with a 1 px `#5A5148` rule beneath. Gold is not used (Gold is reserved for score and hero numbers). Licence body text is left-aligned in the 328 px viewport; names and headings are centred.

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|
| Header | Text | No | — | Single-language |
| Section heading | Text | No | — | Key `credits.section.<key>`, translated |
| Name line | Text | No | — | Proper noun, **not translated**, shown as written (Latin or Bengali script) |
| Role line (optional) | Text | No | — | Translated if the data supplies a key |
| Licence block | Text | No | — | Legal wording, **not translated**, English, left-aligned, wraps (see Localization) |
| Scroll list | Scroller | Yes (speed, manual scroll, exit) | P01-shared, P26 (modified: pixel/line steps, not whole rows, because it is a reading roll) | 24 px/s, hold Fire doubles; Nav steps one line and pauses |
| Scroll chevrons | Glyph | No | P26 | 4x4, up and down; shape only, no colour meaning |
| Back plate | Button | Pointer/touch | P05, P06 | |
| Prompt bar | INFO | No | — | Glyphs per active device |
| Status line (empty / error) | INFO | No | — | Only in Empty and Error states |

New pattern: none. The only deviation is the P26 variation noted above (a continuous roll with a manual mode); it is not generalised.

### ASCII Wireframe

```
+----------------------------------------------------------+ y0
| CREDITS                                                  |
+---------------------------v------------------------------+ y48
|                                                          |
|                 DESIGN AND PROGRAMMING                   |
|                 ----------------------                   |
|                      Name One                            |
|                      Name Two                            |
|                                                          |
|                    MUSIC AND SOUND                       |
|                      Name Three                          |
|  Licence text, left-aligned, English, wraps at 328 px    |
+---------------------------v------------------------------+ y592
| [A hold] Faster  [Up/Down] Scroll  [B] Back              | y600
+----------------------------------------------------------+
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Loading | Screen open, data not yet read | Header, prompt bar and Back plate show at once; the viewport is empty. `credits.tres` is a preloaded resource read synchronously during the 12-frame enter wipe, so Loading lasts at most those 12 frames. The scroll clock (tick 0) starts on the first frame after the wipe ends and the data is ready, never earlier |
| Scrolling (auto) | Data ready, `access.reduce_motion` off | Starts at offset 0 (viewport empty, first line entering at the bottom) |
| Fast | Fire / Start / Confirm held in auto mode | Speed 48 px/s while held; returns to 24 on release |
| Manual | Nav up or down in auto mode; always the mode when `reduce_motion` is on | Auto-scroll stops. Each Nav press (with repeat 18/6) moves one line (20 px Latin, 24 px Bengali). The prompt bar swaps "Faster" for "Resume" (not shown under reduce_motion). Held indefinitely, no timer |
| Ended | Auto-scroll reaches the end offset: the last line's bottom edge at the viewport centre (y 320) | Scrolling stops; the last page stays (never a blank viewport); Cancel exits (no auto-exit, no loop). Manual scroll back up still works |
| Empty data | `credits.tres` missing, unparsable, or no section with lines | One INFO status line `menu.credits.empty` centred in the viewport; the file problem is logged once; no scrolling, no chevrons; Cancel works |
| Partial data | A section has no lines | That section (and its heading) is skipped |
| Error: licence block | A LICENCE entry has an empty or missing `body` | The block shows its title line (proper noun) and one INFO line `menu.credits.licence_missing`; the problem is logged once; all other blocks and the scroll are unaffected. It never hides the credit for the asset |
| Error: missing glyph | A name uses a glyph the font lacks | The font's fallback glyph draws in its place, the rest of the line still shows; logged once (glyph coverage is a Localization font concern, Open Question 7) |
| Text size 2-3 | `access.text_size` | Headings, role lines and licence text grow; names keep S-tier size at least; the list gets longer (the end offset recomputes); over-wide lines wrap, never truncate |
| Reduce motion | `access.reduce_motion` | Auto-scroll is **off**; the screen opens in Manual mode at offset 0 with the first section visible at the top; enter/exit wipe becomes a cut (P21). Hold Fire has no effect. See Open Question 6 |
| Touch / pointer | Touch platform, mouse | Back plate visible; wheel scrolls one line per notch and switches to Manual; tap-hold on the list counts as hold Fire (auto mode) |
| Language change | Settings only | Not possible on this screen (no language chip here; Drone does nothing); text re-renders on next open |

---

## Interaction Map

Shared screen: any connected device, last input wins (Rule 8). Verbs are Input's Nav / Confirm / Cancel (Menus Rule 12).

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Scroller | Faster (auto mode) | Hold Fire or Start (Confirm) | Hold Enter / Z / Space | Hold click / tap | Speed doubles at once | 48 px/s while held; release returns to 24 |
| Scroller | Scroll one line | D-pad / stick Up, Down (repeat 18/6) | Up, Down arrows (repeat 18/6) | Wheel one line per notch | Content moves one line; `sfx_ui_nav_tick` | Enters Manual mode (auto stops); clamped to offset 0 and the end offset |
| Scroller | Resume auto | Fire or Start press (in Manual) | Enter / Z / Space press | Tap list | Prompt bar swaps back to "Faster" | Auto mode at 24 px/s from the current offset; not available under reduce_motion |
| Screen | Exit | Bomb, Back | Esc, C | Back plate | `sfx_ui_cancel`, wipe | Title, focus on CREDITS |

Left / right, Drone and Pause do nothing. **Start is Confirm (Menus Rule 12), so it acts as Fire here and does not exit;** Back and Bomb exit. The Nav/Fire manual-scroll controls are a proposal pending a Menus Rule 46 amendment (Open Question 1); until then the Nav input is ignored and only speed/exit exist.

**Fire during the first press in Manual mode:** the press that resumes is consumed (it does not also count as hold-faster until it is held for 1 further tick).

### Focus Order

There are no focusable list items. The scroller owns implicit input focus the moment the screen opens; there is no focus ring (P02 is not used) and no Tab stops. Order for pointer users: Back plate only. Pad and keyboard users reach every function with the verbs above, with no cursor.

## Events Fired

| Player Action | Event / Call | Payload | Persistent state? |
|---|---|---|---|
| Open | Screen change | — | No |
| Exit | Screen change | — | No |
| Faster / Manual scroll / Resume | None (null by design) | — | No |
| Data or licence failure | Log line (once per file/block) | file or block id | No |

No Save write, no `commit_settings`, no analytics (none defined, Open Question 4).

## Transitions & Animations

- **Enter / exit:** 4-step Char wipe, 12 frames; reduce-motion cut (P21: `reduce_motion`).
- **Scroll:** integer pixel steps only. In auto mode the offset after `t` ticks = `acc div 60` where `acc` is an integer accumulator adding `speed` (24, or 48 while held) each tick, so the same screen always scrolls identically; no sub-pixel movement, no easing. The offset keeps its value when the speed changes. A manual step adds one line height to the offset and sets `acc = offset x 60`. Declared option: `reduce_motion` turns the auto roll off (P21); `reduce_flashing` and `reduce_pulsing` do not apply (nothing flashes or pulses).
- **End offset:** `end_offset = content_height + 272` px (the last line's bottom edge reaches the viewport centre; 272 = half of 544).
- **Length example:** 40 lines x 20 px = 800 px, end offset 1,072 px, which is 45 s at 24 px/s (44.7 rounded up) and 23 s at 48 px/s.
- **No fade edges, no flash, no pulsing.** A clipped line at the viewport edge is acceptable (pixel-art stepped edge).
- **Chevrons** appear and disappear in the same frame as the condition changes (no animation).

## Data Requirements

| Data | Source System | Owner | Read / Write | Update trigger | Null / missing handling |
|---|---|---|---|---|---|
| Credits sections, name lines, role keys | `data/menus/credits.tres` | Menus (22); content by producer (Open Question 2) | Read | Screen open | Missing / unparsable / empty -> Empty data state; a section with no lines is skipped; a name line with empty text is skipped |
| Licence blocks (kind LICENCE: title, body) | `data/menus/credits.tres` | Menus (22) holds them; text must match `assets/fonts/LICENSE` (Localization AC-51) and the audio licence ledger (Audio) | Read | Screen open | Empty body -> Error: licence block state |
| `credits_px_per_s` (24) | Menus tuning | Menus (22) | Read | Screen open | Default 24; clamp to 12-60 |
| Section strings `credits.section.*`, `menu.title.credits`, `menu.credits.empty`, `menu.credits.licence_missing` | Localization | Localization (27) | Read | Screen open | English if Bengali missing (Loc Rule 4) |
| Active language | Localization | Localization (27) | Read | Screen open | `en` |
| `access.text_size` | Accessibility | Accessibility (28) | Read | Screen open and live while open (reflow, keeps the visible line at the viewport centre) | 0 |
| `access.reduce_motion` | Accessibility | Accessibility (28) | Read | Screen open (EVENT-like; a change needs Settings, so not possible while open) | false |
| Device glyph family | Input | Input (2), F8 | Read | Device change | Generic glyphs |
| Scroll offset, accumulator, mode (AUTO / MANUAL / ENDED) | Credits screen controller | Menus (22) | Read / write, local only | Every tick | Reset on open; never saved |

Names are excluded from the string lint allow-list (Rule 46). The screen owns only transient scroll state and no game or save state.

## Accessibility

Tier: COMPREHENSIVE (`accessibility-requirements.md`, Section 5: "Scrollable by input at the user's pace; scroll off under reduce motion").

- **Gamepad only / keyboard only:** open with Confirm, Fire to speed up, Nav up/down to scroll and pause, Cancel to leave; no mouse needed.
- **Not colour-dependent:** the screen has no state signalled by colour; headings use size and rule line; chevrons use shape.
- **Contrast:** Cream `#F4EBD6` on Cabinet Char `#1E1B18` with 1 px outline, 7:1 or better (art bible text rule, Section 7); the `#5A5148` rule line is decorative only (high-contrast theme switches it to Cream).
- **Text size:** all text follows `access.text_size`; names never go below S tier; lines wrap, never truncate (Accessibility edge case for step 3).
- **Timing ("pause, stop, hide"):** auto-scroll is time-based, so the player can stop it at any time with Nav (Manual mode), or have it off entirely with `reduce_motion`. No timeout anywhere (untimed by construction).
- **Flashing:** none.
- **Subtitles:** not applicable (no audio events). The only sound is `sfx_ui_cancel` on exit and `sfx_ui_nav_tick` on a manual step; each has a visual twin (the content moves; the wipe).
- **Screen reader:** out of scope at Vertical Slice (`accessibility-requirements.md` Section 4: menu screen reader reconsidered at Target). The text is plain strings in a defined order, so platform narration is feasible later.

## Localization Considerations

- **Single-language screen.** No language chip is shown here (the chip is on Title, Menus Rule 10). Headings (`credits.section.*`) and status lines follow the active language.
- **Not translated, by design:** names are proper nouns shown as supplied and may mix Latin and Bengali script (Latin font for Latin names, Bengali font at 17 px minimum for Bengali). **Third-party licence text (fonts, music, CC-BY notices) is legal wording and is never localised**: it stays in its original language (English) in both language modes, because a translation could alter the legal terms. On the Bengali screen a licence block therefore sits beside Bengali headings; this is intentional and is not a missing-string bug (licence entries are excluded from the string lint). No Bengali draft is provided or required.
- **Character limits (proposed budgets, verify at font integration; the scroll never truncates):** screen title 16 chars; section heading 21 chars (longest English source "MUSIC AND SOUND" = 15 chars, +40% = 21) on one line at 328 px, wrapping to a second line at text step 2-3 or in Bengali; name line 40 chars; role line 30 chars; licence title 40 chars; licence body up to 600 chars (wraps, left-aligned). Wrap by word and never mid-conjunct: names up to 2 lines (3 Bengali).
- Bengali strings are drafts awaiting native review.

---

## Acceptance Criteria

- [ ] CREDITS on Title opens the screen; Cancel returns to Title with focus on CREDITS, in every state (Scrolling, Manual, Ended, Empty, Error).
- [ ] With `reduce_motion` off, after 600 ticks without input the content has moved exactly 240 px (24 px/s), in whole pixels, every run; the clock starts after the enter wipe.
- [ ] Holding Fire moves content at 48 px/s (480 px in 600 ticks); releasing returns to 24 px/s and the offset does not jump.
- [ ] Pressing Down on pad or keyboard stops auto-scroll and moves exactly one line (20 px Latin, 24 px Bengali) per press; the content stays still afterwards for at least 3,600 ticks (a 60 s hold with no input); Fire press resumes at 24 px/s from the same offset.
- [ ] With `reduce_motion` on, the content does not move for 600 ticks without input, Nav up/down moves one line per press, and the transition is a cut.
- [ ] Start does not exit; Back and Bomb exit; Drone and Pause do nothing.
- [ ] Auto-scroll stops at the end offset with the last line at the viewport centre (no blank viewport); the screen stays until Cancel is pressed and does not loop or exit.
- [ ] Names from `credits.tres` appear identically in English and Bengali; section headings change with the language; licence blocks are identical (English) in both languages.
- [ ] With `credits.tres` empty or missing the screen shows one `menu.credits.empty` line and Cancel still works; no error or crash. With one licence block body empty, that block shows `menu.credits.licence_missing`, every other block still shows, and one log line is written.
- [ ] No Save write occurs from opening, scrolling or leaving the screen, and no timeout or attract mode starts while the screen is open for 5,000 ticks.
- [ ] The screen renders without clipping at 360x640, 1080x1920 and 1440x2560, and with text step 3 in both languages (lines wrap, nothing truncated, chevrons correct).
- [ ] The screen is fully operable with a gamepad only and with a keyboard only; nothing flashes; no state depends on colour alone.
- [ ] Performance: holds 60 fps on REF-WEB with no per-frame allocation after warm-up; the list is drawn as at most 40 visible lines, not the whole file.

---

## Open Questions

1. ~~**Manual scroll / pause (specified here, needs GDD amendment).**~~ **Closed 2026-11-03 (wave 5):** Menus Rule 46 now carries Nav up/down line scroll with auto-scroll pause, Fire-or-Start resume, `access.reduce_motion` = manual mode, stop with the last line at the viewport centre, no loop and no auto-exit, licence text not localised, and Start as Confirm. `access.reduce_motion` is also listed in the Menus tuning table as a key Menus reads.
2. **Content (Menus Open Question 15):** names, roles, fonts, music and licence lines. CC-BY audio must be credited (Audio GDD licence rules). Owner: producer, before release candidate.
3. **End behaviour:** stop at the end (decided, with the last line centred); loop is rejected (hides the end); auto-exit rejected (hides the last lines from slow readers).
4. No analytics, no player journey (see `main-menu.md` Open Questions).
5. Touch: "tap-hold = hold Fire", tap-to-resume and touch drag scroll are proposals; the Touch GDD does not cover Credits.
6. **Reduce motion default.** `accessibility-requirements.md` says "scroll off under reduce motion"; this spec follows it. Whether a player with reduce_motion on may opt back into auto-scroll is left unspecified (Accessibility owner).
7. **Licence text length and source.** The 600-character body budget is a guess; confirm against the real licence set (OFL fonts, CC-BY music) The **storage shape is decided** (Menus Open Question 15, 2026-11-03, wave 5): a licence entry is a **`kind = LICENCE` record in `credits.tres`** with a `title` and an inline `body`, never localised and exempt from the string lint - not a file read from `assets/fonts/LICENSE`. **Remaining:** the real licence set and the body length. Owner: producer / localization.
8. ~~**New string keys** `menu.credits.empty` and `menu.credits.licence_missing`~~ **CLOSED 2026-11-03 (wave 5 batch 2).** Both are registered in the Menus GDD string table **and** in `localization.md` **Rule 5a** with their English source text ("No credits available." / "Licence text unavailable."), single-language in `ui_menu.csv`; Rule 5a also confirms that the `credits.section.*` family and `menu.title.credits` already exist. **Remaining (project-wide, not a credits question):** every Bengali cell added in wave 5 reads *pending native review* and is filled by the localisation lead before the string soft freeze.
9. **S-tier line pitch.** The 20 px Latin pitch is authored, not derived (see Layout Zones). It should be restated or recomputed once `arcade-ui-style.md` Open Question 3 fixes the line-pitch base. Owner: art-director.
