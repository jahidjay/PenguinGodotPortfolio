# UX Spec: Settings (Audio, Display, Language, Controls, Accessibility, Data) + First-run Photosensitivity Plate

> **Status**: Approved (2026-11-03) — previously: Reviewed (`/ux-review` 2026-11-03; blocking issues fixed, open items in Open Questions and `production/ux-reports/settings.md`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (UX consistency check, wave 5)**: the reset keep-list note no longer says Save Rule 30 is unamended - Rule 30, AC-26 and the registry now carry the full keep-list - and the keep-list AC adds `touch.hints_seen`.
> **Revision 2026-11-03 (final doc closeout, Alarm Flare follow-up)**: failure styling now names both reds - **`#E03A3E` is never a text fill**, and red *words* use the art bible's text-only **Alarm Flare `#F2494D`** for the one headline line per screen, paired with an error glyph and a Cream explanatory sentence (art bible 4.1, style guide 3.1 rule 3 "two reds, two jobs"). The earlier blanket "Alarm Red is never a text fill at all" is true only of `#E03A3E`.
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: failure styling restated against the then-current style-guide rule - Alarm Red never a text fill, not merely "not alone" (States "Save failure", Accessibility contrast line). Superseded in part by the Alarm Flare follow-up above.
> Revised 2026-11-03 after /ux-review: aligned with `accessibility-requirements.md` (COMPREHENSIVE, section 1.1 staging table added); added Input test screen spec, delivery staging, loading / Save-absent / Title-assist states, touch 9 mm hit areas, help-line and first-run plate layout fixes, player-facing timing values, `reset_settings` keep-list and `display_reset` hold resolutions, ACs for the new content.
> **Journey Phase(s)**: unknown (no `design/player-journey.md`)
> **Template**: UX Spec
> **Platform Target**: PC (Steam/itch), Web, Switch / Switch 2, iOS, Android. Gamepad primary; keyboard full; touch partial. Canvas 360x640 (TATE rotates the whole display).
> **Sources**: `design/gdd/menus-title-plane-select.md` (Rules 33, 42-47, 51; V/A table; edge cases; AC-35, AC-49, AC-50; Open Questions 8, 11), `accessibility-options.md` (all rules, option table, Rule 34, UI Requirements; the registry, wins on any conflict), `design/accessibility-requirements.md` (tier COMPREHENSIVE, sections 1.1, 4, 5.1, 5.2), `input-and-player-mapping.md` (Rules 19-22, 34-39, F8), `display-scaler-and-bezel.md` (Rules 6, 13, 17, UI table, `display_reset`), `audio.md` (Rules 1-3, `sfx_ui_slider_preview`), `save-settings-high-scores.md` (Rules 15-20, 28, 30; schema), `touch-controls.md` (Rules 4, 8-10, 32; UI Requirements), `localization.md` (Rules 3, 16, 17; F5), `tutorial.md` (`tutorial.hints`), `design/ux/arcade-ui-style.md`, `design/ux/interaction-patterns.md`. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P01, P02, P03, P04, P05, P06, P10, P11, P12, P21, P22, P23 (see `interaction-patterns.md`). Fills **Gap 1** (key remap pattern) with the new item kind BINDING and the listening state (section "Controls").

---

## Purpose & Player Need

The player arrives wanting to **make the game fit their body and room once, then forget it**: volume, window, language, controls, and (for some players) the options that make play possible at all. Settings must (a) show the effect of a change immediately, (b) never trap the player in a bad state (a wrong rotation, an unbindable key, a language they cannot read), (c) make the few destructive actions deliberate, and (d) be honest about the one consequence that matters to score chasers: **ASSIST rows mark a run PRACTICE**; every other row is ranked-safe. Settings applies live and commits once on close (Menus Rule 47); there is no Apply button and no discard.

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| Title > SETTINGS (first visit) | Curious, wants to tweak one thing | Shared screen; any device navigates |
| Title, wrong language guess | Mildly stuck | Title chip is the fast path; Settings > Language is the backup |
| Pause > Settings (mid-run) | Interrupted; wants one fix (volume, remap, Reduce flashing) and back in | Owner only (P10); the run is frozen; assist rows have a consequence |
| Wrong TATE / display | Anxious ("the screen is sideways") | Must be reversible without reading the screen (safe default Cancel, auto-revert, `display_reset`) |
| Player needing access options | Deliberate, may be tired or in pain | Wants a few presses per change, large targets, no timers |
| First launch | Neutral, about to see the game | First-run plate (below) appears before Title, once |

## Navigation Position

`Title | Pause -> **SETTINGS index** -> Audio | Display | Language | Controls (-> Input test) | Accessibility | Data actions`. The Controls page edits one device class at a time, chosen by its first row (there is no separate device page). Listening is a state of the Controls page, not a level. Modals on top: TATE confirm, Quit game Yes/No, swap confirm (inline), preset confirm (inline). Back always goes up one level (P05); leaving the index closes Settings and commits. **There is no tab strip anywhere in Settings**: a 360 px canvas cannot hold the section names (Accessibility alone is 13 Latin / long in Bengali) at a readable size, so sections are an index of LINKs and the long Accessibility page is one scrolling list with group jumps.

| Level | Screen | Cancel goes to |
|---|---|---|
| 0 | Title (shared) or Pause (owner) | (opener) |
| 1 | Settings index: five section LINKs + Data group | Opener, **commit once if dirty** |
| 2 | Section page (Audio, Display, Language, Controls incl. Touch section, Accessibility) | Index (no commit) |
| 3 | Input test (from Controls or Accessibility) | The page that opened it |
| (state) | Listening / swap / preset strips on the Controls page | Strip closes, no change; the page stays |

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Title | Confirm on SETTINGS | Shared; last input wins; no run |
| Pause | Confirm on Settings | **Owner** slot, owner tag, owner's glyph family; `run.assisted` state; run is frozen |
| Controls page / Accessibility page > Input test | Confirm on the Input test LINK | Device class being edited |
| First-run plate | n/a | Plate is separate; it does not open Settings (it writes the same keys) |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Title / Pause (opener) | Cancel on the index, or the Back plate | Focus restored on SETTINGS / Settings (P05). `commit_settings()` once if dirty |
| Level up | Cancel on a section page | Focus restored on the section LINK; no commit |
| Application exit | Yes on Quit game dialog (Title only, PC / Switch) | Save's close handler writes dirty settings |
| Title (via Pause) | not from here | Quit to title is a Pause item, not a Settings item |

Exits that cannot be undone: **Reset settings**, **Clear scores**, **Quit game**. Reset display and the TATE change are reversible by design.

---

## Layout Specification

### Information Hierarchy

1. **Where am I and who owns this screen** (breadcrumb "SETTINGS > Display"; owner tag from Pause).
2. **The focused row and its current value** (value as text, not colour).
3. **Consequence lines** (PRACTICE on ASSIST rows, "applies next stage", "Max on this screen", destructive consequence text).
4. Section list / group headers (orientation in a long list).
5. Live preview (Display info line, Visual sample plate, Text sample).
6. Prompt bar with device glyphs; toast strip.

### Layout Zones

Canvas 360x640. `top` = 0 from Title; = HUD strip height (`play_top` 48 for 1-2P, 72 for 3-4P) from Pause, so the live HUD strip is never covered (Pause spec). Positions assume text step 0; rows are laid out from measured text (Menus Rule 51), so everything below the header moves down as rows grow.

| Zone | Rect (canvas px) | Contents |
|---|---|---|
| Header plate | x 16-344, y `top`+8 to `top`+40 (grows with measured text, min 32) | Breadcrumb (M tier; when it does not fit beside the owner tag it shows the section name only), owner tag 90x20 (Pause only), Back plate: visual 24x24, **hit area 24x24 on pad/keyboard/pointer platforms and `min_target_canvas_px` (55 at x3 / 458 dpi) square on touch platforms** (invisible padding counts, Touch Rule 30) |
| List viewport | x 16-344, y `top`+48 down to **4 px above the help line** (y 512 at text step 0 with a one-line Latin help text; shrinks as the help line grows) | Rows; scrolls; focused row kept in view; 4 px scroll bar plus "more" arrow glyphs (P26) |
| Row | 328 wide, min 32 tall (Latin) / 36 (Bengali); touch `touch_item_h` 55 | Label column 148 px (left), control column 172 px (right) |
| Help line | x 16-344, **bottom edge fixed at y 556**, height by measured text (max 2 lines: 38 Latin / 48 Bengali at step 0, 2 x (cap+7) at higher steps) | Help text for the focused row (`help_key`). The list viewport ends 4 px above its top edge, so the two never overlap. Toast y 560-584 is below it |
| Toast | y 560-584, 328x24 | P11 |
| Prompt bar | y 600-640 | Glyph + verb pairs for the active device (owner's during Pause) |
| Modal plate (TATE, Quit, swap) | 296 wide, centred, height by content | Over the list; list dimmed to the plate-edge colour, no tint over the HUD strip |

From **text step 2** the row stacks (label above control, Accessibility Rule 19); rows grow downward; nothing is clipped; a 24x24 minimum hit area is kept for every stepper arrow on pointer platforms. **On touch platforms every tappable element (row, stepper arrow, Back plate, Clear "x", chip) has a hit area of at least `min_target_canvas_px` on both axes** (Touch Rule 30; a 24 px target at x3 on a 458 dpi phone is 4 mm, too small); the visual stays small, the invisible padding carries the hit area, and adjacent hit areas never overlap (stepper: two 55 px arrows plus the bar fit the 172 px control column).

### Component Inventory

Conventions: label key is `opt.<setting name>` (e.g. `opt.reduce_flashing`) and help key `opt.<name>.help`; section and group headings are `menu.settings.<section>` / `menu.settings.group.<group>` (proposed, Localization to confirm; only `menu.settings.language.label` exists today). "Applies" uses the Accessibility modes: LIVE, EVENT, STAGE, RUN. "(a)" = assumed LIVE because the owning GDD does not state a mode (Open Question 12). Tier: rows whose system is not built yet are **not listed** (P22), not greyed: Auto-bomb, death-bomb grace, Rumble (Target); Vibration/Touch only on touch platforms.

**Delivery staging** (`accessibility-requirements.md` section 1.1; rows of a later stage are **not listed** until it ships, P22)

| Stage | Settings content that must exist | Not yet listed |
|---|---|---|
| MVP (Pre-Production exit) | Index with Audio, Display, Language, Controls; Audio page incl. Mono; Display page; Language page; Controls page with the **remap list** (Fire / Drone / Bomb, KB movement, per-action reset, Reset this device, swap and reserved-control handling); Reset settings; Clear scores; Quit game. The accessibility **hooks** read their defaults (`reduce_flashing`, `reduce_pulsing`, `reduce_motion`, `effects_level`, `tally_auto_advance`) with no screen | Accessibility page and LINK, first-run plate (Save absent; hidden), mirrors, presets, Input test, per-slot pad maps, Fire mode / Tap Assist / Deadzone / Move stick rows (assumption, OQ 16) |
| Vertical Slice (Production exit) | Full Accessibility page (all groups), Controls extras (presets, per-slot pad maps, Input test, Move stick), text size, palette, HUD contrast, Game speed + PRACTICE warnings, first-run plate, Calm preset, Reset these options | Rumble rows, Auto-bomb, death-bomb grace, Touch section |
| Target (release candidate) | Touch section (touch platforms), Rumble row and Chain cue rumble, Auto-bomb and death-bomb grace rows, adaptive-controller test | none |

**Index (level 1)**

| Row | Kind | Values | Default | Owner | Notes |
|---|---|---|---|---|---|
| Audio | LINK | opens page | — | Menus | Default focus on arrival |
| Display | LINK | opens page | — | Menus | |
| Language | LINK | opens page | — | Menus | Value shown on the row in its own script ("English" / "বাংলা"), so a player who cannot read the label can still find it by the value |
| Controls | LINK | opens page | — | Menus | |
| Accessibility | LINK | opens page | — | Accessibility | Vertical Slice (staging table) |
| Reset settings | HOLD_BUTTON | hold `confirm_hold` | — | Menus > Save `reset_settings()` | Consequence line: "All settings and controls return to defaults. Language, scores and Flight School progress are kept." Keep-list below |
| Clear scores | HOLD_BUTTON | hold `confirm_hold` | — | Menus > Save `clear_scores()` | **Title only** (hidden from Pause, OQ 8). Line: "This cannot be undone" (`menu.confirm.clear_scores`) |
| Quit game | BUTTON | opens Yes / No | — | Menus | **Title only**, PC and Switch (P22); hidden on Web, mobile, and Pause |

**Reset settings keep-list (decided 2026-11-03; Save amendment A1 applied 2026-11-03, wave 5 batch 2 - Save Rule 30 and AC-26 now carry the whole keep-list, so the GDD and this screen agree).** The screen requires that `reset_settings()` restores every known key to its default **except** `language` (keeps the resolved `bn` / `en`, so the UI never flips to an OS guess the player cannot read), `access.first_run_prompt_done` (the photosensitivity plate must not reappear and cannot be un-answered by a reset), `profile.*` (`last_initials`, `last_plane`), `tutorial.*` (including `tutorial.hints`) and `touch.hints_seen`. Save Rule 30 and AC-26 were amended to exactly this keep-list on 2026-11-03 (wave 5 batch 2), and the registry constant `reset_settings_keep_list` records it, so the consequence line above is the GDD behaviour.

**Audio page** (4 rows)

| Row (setting) | Kind | Values | Default | Owner | Applies |
|---|---|---|---|---|---|
| Master volume (`audio.master`) | STEPPER | 0-10, 10-cell bar + numeral | 10 | Audio (24) | LIVE; plays `sfx_ui_slider_preview` (max 1 per 6 ticks) |
| Music volume (`audio.music`) | STEPPER | 0-10 | 7 | Audio (24) | LIVE; no preview sound (the track is the preview) |
| SFX volume (`audio.sfx`) | STEPPER | 0-10 | 8 | Audio (24) | LIVE; preview sound. Help: "Menu sounds follow this" (UI bus follows SFX) |
| Mono audio (`audio.mono`) | TOGGLE | Off / On | Off | Audio (24) / Accessibility (28) | LIVE |

A step of 0 shows a muted-speaker glyph beside the numeral (not colour). No separate Dialogue or UI slider exists (Accessibility Rule 27).

**Display page** (6 rows; some hidden per platform)

| Row (setting) | Kind | Values | Default | Owner | Applies / platform |
|---|---|---|---|---|---|
| Window mode (`display.window_mode`) | CHOICE | Windowed / Fullscreen | Windowed (desktop) | Display (4) | LIVE. **Hidden on phones and tablets** |
| Scaling (`display.scale_mode`) | CHOICE | Auto / Pixel Perfect / Fill | Auto | Display (4) | LIVE preview; info line updates |
| Rotate screen (`display.tate_mode`) | CHOICE | Off / Clockwise / Counter-clockwise | Off | Display (4) | LIVE then **TATE confirm** (below). **PC and Switch only**; hidden on Web, phones |
| Bezel (`display.bezel_style`) | CHOICE | Art / Plain | Art | Display (4) | LIVE. At MVP only Plain exists, so the row is hidden until Art ships (tier) |
| Info line | INFO | "Scale x3 - 1080x1920" or "Scale 1.69 (Fill)" | — | Display (4) `get_layout()` | Read-only; refreshes on any layout change; skipped by focus |
| Reset display | HOLD_BUTTON | hold `confirm_hold` (60 ticks at NORMAL, per P04) | — | Display (4) | Restores Auto, Windowed, TATE Off, Art; applies at once; also closes an open TATE dialog. **Not the same control as the `display_reset` hotkey** (a 2 s real-time hold of 120 steps, Input action, works from anywhere); both give the same result, only the hold length differs (Open Question 1 resolved, amendment A2) |

**Language page** (1 row)

| Row (setting) | Kind | Values | Default | Owner | Applies |
|---|---|---|---|---|---|
| Language (`language`) | CHOICE, drawn as two chips like the Title chips (P23; active chip filled) | `বাংলা` / `English` (each in its own script, never translated) | OS guess, stored explicit `bn`/`en` after first boot | Localization (27) | LIVE, one frame, no layout shift; allowed from Pause (Localization Rule 16). Opening the page from the index puts focus on the active chip |

**Controls page (level 2; MVP = remap list rows only, see staging)**. Binding cell key names are Latin keycap labels of at most 7 characters (cell 52 px wide at step 0); longer names use a short form from the Input key-name table (OQ 17). Pad bindings show the glyph of the owner's family (Input F8).

| Row (setting) | Kind | Values | Default | Owner | Applies |
|---|---|---|---|---|---|
| Edit controls for | CHOICE | Gamepad (all pads) / Keyboard 1 (KB1) / Keyboard 2 (KB2); at VS also Gamepad P1-P4. Classes are named by number, not by hand, so they never clash with the preset names "Keyboard: left hand / right hand" (OQ 5 part resolved) | Class of the device used to open the page | Input (2) | LIVE. Keyboard classes are listed only where a keyboard can exist (PC, Web); on Switch and phones only pad classes (OQ 13) |
| Fire / Drone / Bomb (`input.bindings`) | BINDING | 2 cells per action (primary, alternate) + per-action reset | Input defaults | Input (2) | LIVE |
| Move up / down / left / right | BINDING | KB classes only; pad movement is fixed (not listed) | Input defaults | Input (2) | LIVE |
| Reset this device (`input.bindings` class) | HOLD_BUTTON | hold `confirm_hold` | — | Input (2) | Clears overrides for the edited class |
| Fire mode (`input.fire_toggle`) | TOGGLE | Hold / Toggle | Hold (off) | Input (2) | LIVE; latch clears on death, pause, stage start |
| Tap Assist (`input.tap_assist`) | TOGGLE | Off / On | Off | Input (2) | LIVE |
| Stick deadzone (`input.dz_preset`) | CHOICE | Low / Default / High | Default | Input (2) | LIVE |
| Move stick (`input.move_stick`, VS, proposed Input amendment) | CHOICE | Left / Right / Either | Left | Input (2) / Accessibility | LIVE |
| Layout presets (VS) | BUTTON x4 | Keyboard: left hand; Keyboard: right hand; Gamepad: one hand; Touch: one hand (touch platforms) | — | Accessibility (28) | Writes overrides in one action (inline confirm strip, below). **Scoping (decided, OQ 5):** a preset writes to the class currently chosen in "Edit controls for"; keyboard presets are listed only while a keyboard class is chosen, "Gamepad: one hand" only while a pad class (shared or per-slot) is chosen, "Touch: one hand" on touch platforms |
| Input test (VS) | LINK | live pressed / held per action per device | — | Accessibility (28) | Read-only screen, spec "Input test screen" below |
| Use shared pad map (VS, per-slot class only) | BUTTON | removes `pad_s{n}` override | — | Accessibility (28) | LIVE |

Controls rows are one data set; the Accessibility "Controls" group shows **mirrors** of Fire mode, Tap Assist, Deadzone, Move stick plus LINKs to the Controls page (same key, same value, two views; changing either updates both).

**Touch section** (touch platforms only, P22; below the Controls rows, 9 mm rows)

| Row (setting) | Kind | Values | Default | Owner | Applies |
|---|---|---|---|---|---|
| Move control (`touch.scheme`) | CHOICE | Drag / Stick | Drag | Touch (31) | Next `stage_started` (never mid-stage) |
| Auto-fire (`touch.autofire`) | TOGGLE | On / Off | On | Touch (31) | (a) |
| Thumb side (`touch.hand`) | CHOICE | Right / Left | Right | Touch (31) | (a) |
| One-hand mode (`touch.one_hand`) | TOGGLE | Off / On | Off | Touch (31) | (a); Hold becomes a toggle |
| Drag speed (`touch.sens`) | STEPPER | 4 steps (0-3) | index 1 | Touch (31) | (a) |
| Button size (`touch.button_scale`) | CHOICE | 100 / 125 / 150% | 100% | Touch (31) | (a); row shows "Max on this screen" when capped |
| Vibration (`touch.haptics`) | CHOICE | Off / Low / Normal | Normal | Touch (31) | LIVE |

**Accessibility page** (groups in the GDD order: Calm preset, Visual, Colour and contrast, Text, Controls, Assists, Audio, Timing, Reset). Group header = INFO row with a ranked-safe / PRACTICE sub-label (below). One scrolling list.

| Group | Row (setting) | Kind | Values | Default | Class | Owner | Applies |
|---|---|---|---|---|---|---|---|
| Calm | Calm preset | BUTTON | sets `reduce_flashing`, `reduce_pulsing`, `reduce_motion` true and `effects_level` REDUCED in one write; toast "Calm preset applied" | — | PRESENTATION | Accessibility | LIVE |
| Visual | Reduce flashing (`access.reduce_flashing`) | TOGGLE | Off / On | Off | PRESENTATION | Accessibility | LIVE (Critical Break: EVENT, read at T) |
| Visual | Reduce pulsing (`access.reduce_pulsing`) | TOGGLE | Off / On | Off | PRESENTATION | Accessibility | LIVE |
| Visual | Reduce motion (`access.reduce_motion`) | TOGGLE | Off / On | Off | PRESENTATION | Accessibility | LIVE |
| Visual | Effects level (`access.effects_level`) | CHOICE | Full / Reduced / Minimal | Full | PRESENTATION | VFX (25) | LIVE (new instances) |
| Visual | Background (`access.background`) | CHOICE | Full / Dimmed / Plain | Full | PRESENTATION | Parallax (23) | STAGE; from Pause help line "Applies next stage" |
| Visual | Hitbox ring opacity (`access.hitbox_ring_opacity`) | STEPPER | 40 / 60 / 80 / 100 | 100 | PRESENTATION | Player plane (5) | LIVE |
| Visual | Hitbox ring size (`access.hitbox_ring_size`) | CHOICE | Normal / Large | Normal | PRESENTATION | Player plane (5) | LIVE |
| Visual | Other players' shots (`access.ally_shot_dim`) | CHOICE | 0 / 25 / 50 | 0 | PRESENTATION | Bullet manager (3) | LIVE |
| Visual | Chain bar near plane (`access.chain_bar_near_plane`) | TOGGLE | Off / On | Off | PRESENTATION | HUD (20) | (a) |
| Visual | Short era transition (`access.era_transition_short`) | TOGGLE | Off / On | Off | PRESENTATION | Era shift (19) | EVENT (group is an assumption, OQ 12) |
| Visual | Bezel (mirror of `display.bezel_style`) | CHOICE | Art / Plain | Art | PRESENTATION | Display (4) | LIVE |
| Visual | Preview plate | INFO | 120x60: ring size + opacity, four slot colours with rings and pips, sample ally shot; no bullets | — | — | Accessibility | Live |
| Colour | Player palette (`access.player_palette`) | CHOICE | Default / Luma spread | Default | PRESENTATION | Accessibility | STAGE (menus and Lobby immediately) |
| Colour | HUD contrast (`access.hud_contrast`) | CHOICE | Standard / High | Standard | PRESENTATION | HUD (20) | LIVE |
| Text | Text size (`access.text_size`) | STEPPER | 0-3 with a sample line "Aa" and "আ" at that size | 0 | PRESENTATION | Localization (27) | LIVE; screen reflows at once, focus stays in view |
| Controls | Fire mode, Tap Assist, Deadzone, Move stick | mirrors | see Controls page | see above | INPUT_CONVENIENCE (ranked) | Input (2) | LIVE |
| Controls | Controls... , Presets..., Input test... | LINK | open the Controls page items | — | — | Menus | — |
| Assists | Game speed (`access.game_speed_pct`) | STEPPER | 50-100, step 10, shown "100%" | 100 | **ASSIST** | Session (1) | Tick gate at a physics-step boundary. Any value below 100 shows the PRACTICE tile and consequence line **in every opener** (Title too, since the value is saved and affects every later run, States below) |
| Audio | Mono audio (mirror `audio.mono`) | TOGGLE | Off / On | Off | PRESENTATION | Audio (24) | LIVE |
| Audio | Volume steppers (mirrors) | STEPPER | as Audio page | 10 / 7 / 8 | PRESENTATION | Audio (24) | LIVE |
| Audio | Chain cue sound (`access.chain_cue_audio`) | TOGGLE | Off / On | **On** | PRESENTATION | Audio (24) | (a) |
| Audio | Chain cue rumble (`access.chain_cue_rumble`) | TOGGLE | Off / On | Off | PRESENTATION | Input (2) | (a); shown dim with help "Needs Vibration" when `access.rumble` is OFF (Target) |
| Timing | Confirm style (`access.confirm_style`) | CHOICE | Hold / Double tap | Hold | TIMING_UI | Menus (22) | (a); changes every hold-to-confirm in the game |
| Timing | Confirm hold (`access.confirm_hold`) | CHOICE | Short / Normal / Long (stored 40 / 60 / 90 ticks; the screen shows words, not ticks) | Normal | TIMING_UI | Menus (22) | (a); marked inactive (see "Inactive rows", States) with help "Not used with Double tap" when style is Double tap |
| Timing | Menu repeat speed (`access.nav_repeat`) | CHOICE | Fast / Normal / Slow (stored 12/4, 18/6, 30/10 ticks) | Normal | TIMING_UI | Input (2) | (a) |
| Timing | Untimed menus (`access.untimed_menus`) | TOGGLE | Off / On | Off | TIMING_UI | Menus (22) | (a) |
| Timing | Continue timer (`access.continue_timer`) | CHOICE | Standard (10 s) / Extended (30 s) / Untimed (stored 600 / 1,800 ticks / none; seconds derived at 60 ticks per second) | Standard | TIMING_UI (sim-relevant, written to replay header) | Session (1), HUD (20) | (a) |
| Timing | Tally auto-advance (`access.tally_auto_advance`) | TOGGLE | Off / On | **On** | TIMING_UI (sim-relevant, replay header) | Stage-end tally (21) | (a) |
| Timing | Tutorial hints (`tutorial.hints`) | TOGGLE | Off / On | **On** | Not an `access.*` key | Tutorial (30) | LIVE; Pause tip row vanishes next frame. Not changed by Reset these options or Reset settings (both leave `tutorial.*` alone), so this toggle is its own reset |
| Reset | Reset these options | HOLD_BUTTON | hold per `confirm_style` | — | — | Accessibility | Sets every `access.*` key to default **except** `access.first_run_prompt_done`. Does **not** touch mirrored keys of other owners (`input.*`, `audio.*`, `display.bezel_style`) or `tutorial.hints`; the consequence line says so: "Resets the options on this page that are accessibility settings. Volume, controls and hints are kept." |

Group sub-labels (INFO text): Calm, Visual, Colour, Text, Controls, Audio, Timing = "Ranked-safe: never changes your rank"; Assists = "Marks the run PRACTICE: not ranked" with the PRACTICE tile (plated hourglass icon plus the word, never colour alone).

### ASCII Wireframe

Settings index from Title (`top` = 0):

```
+----------------------------------------------------------+ y0
| SETTINGS                                         [ < Back]|
|                                                          |
|   +--------------------------------------------------+   | y48
|  >| Audio                                             |   |
|   | Display                                           |   |
|   | Language                                  English |   |
|   | Controls                                          |   |
|   | Accessibility                                     |   |
|   | ------------------------------------------------ |   |
|   | Reset settings          [----] hold               |   |
|   | Clear scores            [----] hold               |   |
|   | Quit game                                         |   | PC / Switch only
|   +--------------------------------------------------+   |
|  Settings return to defaults. Scores are kept.           | help line
| [toast strip, y560]                                      |
| [A] Open   [B] Back                                      | y600
+----------------------------------------------------------+ y640
```

Controls page, listening state (from Pause, P2 owner, `top` = 48):

```
+----------------------------------------------------------+ y0
| [live HUD strip, unchanged]                              | y0-47
+----------------------------------------------------------+
| SETTINGS > Controls                   [P2 ::dashed ring] |
|  Edit controls for     < Keyboard 1 >                    |
|   Fire     [ Z      ] [ Space   ] [r]                    |
|   Drone    [ X      ] [  --     ] [r]                    |
|   Bomb     [>Press..] [ C       ] [r]                    |
|   +--------------------------------------------------+   |
|   | Press a control for Bomb        Esc / Back: cancel|  |
|   +--------------------------------------------------+   |
|   Move up/down/left/right ...                            |
|   Fire mode        Hold     Tap Assist        Off        |
|   Reset this device  [----] hold                         |
| [A] Rebind   [X] Clear   [B] Back                        | y600
+----------------------------------------------------------+
```

Swap confirm (inline strip replaces the listening strip): `Z is used by Fire. Swap with Bomb?   [ Swap ]  > [ Cancel ]`.

### TATE confirm dialog ("Keep this rotation?")

| Aspect | Spec |
|---|---|
| Trigger | Any change of `display.tate_mode` (applies at once, enters Display TateConfirm). **Not** triggered by Reset display (immediate) |
| Plate | 296 x about 140, centred in the rotated image; title `menu.tate.keep` shown in **both scripts** via `text_both` (Bengali above English; Display UI Requirements, because a rotated screen is disorienting); countdown numeral (S tier, 10 down to 0) plus a 10-segment bar; items **Keep** and **Cancel** in the chosen language |
| Focus | **Default focus Cancel** (P12). Keep needs an explicit move + Confirm. Doing nothing is safe |
| Timeout | `tate_confirm_seconds` 10 s **real time** (also while paused); timeout or Cancel/Back restores the previous value, which stays saved as before |
| Sound | `sfx_ui_nav_tick` once per second (Display: standard menu sounds), `sfx_ui_confirm` on Keep, `sfx_ui_cancel` on revert |
| Escape hatch | The global `display_reset` hold (2 s, Input action) still works and wins over the dialog (Menus edge case) |
| Pointer | Click Keep or Cancel; hover only moves focus |
| Pause | Allowed from Pause; the countdown does not stop |

### Quit game dialog

Plate 296x96: "Quit the game?" (`menu.settings.quit_confirm`, proposed), items **Yes** and **No**; **default focus No**; Cancel = No; Yes exits (Save's close handler writes dirty settings). Title only; PC and Switch.

### Input test screen (Vertical Slice; Accessibility Rule 21d)

Read-only live view of the device class chosen in "Edit controls for", so a player (or adaptive-controller user) can confirm what each physical control does. Pattern: new, flagged (a read-only live grid; no pattern covers it). Level 3, Cancel returns to the opener.

| Aspect | Spec |
|---|---|
| Columns | One per connected device of the class (max 4), labelled "P{n}" if bound to a slot else "Pad {n}"; keyboard classes show one column. No device: one line "No controller connected" (pad) |
| Rows | Fire, Drone, Bomb, Up, Down, Left, Right (Up/Down/Left/Right for keyboard classes and for pads as read from the stick/d-pad). Start and Back are not shown (fixed, not remappable) |
| Cell | Idle: empty box. Pressed this tick: box with a solid corner mark. Held: filled box plus held-tick count as numerals on the digit grid. Shape and number carry the state, never colour alone |
| Update | Every physics step while open (Input `pressed`, `held`, `held_ticks`); no per-frame work after the screen closes |
| Focus | One focusable item: the Back plate. Pressing tested controls never activates anything (the screen consumes all non-Back input) |
| Exit | Back (pad), Esc / C (keyboard), Back plate (pointer/touch). Back is not a testable control, so exit is always possible. Start is ignored here (OQ 18) |
| Layout | Row 28 tall (36 Bengali), label 96 px, 4 columns of 58 px; from text step 2 the labels move above the grid, columns stay |
| Timers | None |

### First-run photosensitivity plate (Accessibility Rule 34)

Shown **once**, after Boot and the Web gate (or after boot on desktop), **before Title**, while `access.first_run_prompt_done` is false and Save is present (hidden in MVP builds without Save, Accessibility edge case). It is a settings choice, so it lives in this spec; it is not part of the Settings tree.

| Aspect | Spec |
|---|---|
| Plate | 328 wide, **height by measured content, about 240** (two wrapped dual-script question blocks of about 110 px plus two dual-script buttons of about 51 px each plus padding; 120 px cannot hold it, amendment A3), centred vertically (about y 200-440); Cabinet Char, `#5A5148` edge (Cream under HIGH contrast, though the key is still default) |
| Text | **Dual-script** (style guide 2.1): Bengali above English, equal weight. English "This game has one bright flash. Reduce flashing and effects?" Bengali draft: "এই খেলায় একটি উজ্জ্বল ঝলক আছে। ঝলকানি ও ইফেক্ট কমাবেন?" (draft, native review pending) |
| Items | Vertical list, two BUTTONs, each shown Bengali over English: **Keep as is** (`যেমন আছে থাক`, draft) is **default focus**; **Reduce flashing and effects** (`ঝলকানি ও ইফেক্ট কমান`, draft) |
| Result: Keep as is | Writes `access.first_run_prompt_done = true` only |
| Result: Reduce | Applies the **Calm preset** (`reduce_flashing`, `reduce_pulsing`, `reduce_motion` true, `effects_level` REDUCED) **and** `first_run_prompt_done = true` in **one** `commit_settings()` (no partial state) |
| Skip | One press: Confirm on the default = Keep as is; Cancel / Back / Esc also = Keep as is. Either answer sets Done. Exiting the game before answering leaves it Pending |
| Input | Shared; any device. The answering press is consumed (G7) so it cannot also act on Title |
| Motion | Static plate: **no focus pulse, no pulse, no flash** (the player has not yet chosen a setting; Reduce pulsing/flashing are still off). Arrival uses the Char wipe (no white); the plate itself appears in place |
| Window blur | Plate stays; input pauses as usual |
| Verification | Later Settings > Accessibility > Calm preset and Reset these options let the player undo either choice |

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default (from Title) | Open | Shared; last input wins; no owner tag; focus on Audio |
| From Pause (owner only) | Open from Pause | P10: owner tag shown; only the owner's Nav/Confirm accepted; other slots' presses ignored and their tags dimmed; owner's glyph family in the prompt bar; HUD strip stays; Clear scores and Quit game hidden; ASSIST rows show the PRACTICE warning |
| Owner changes | Owner's device disconnects | Ownership moves to the lowest connected bound slot; a listening state is cancelled with no change; the Disconnect overlay draws over Settings |
| Platform-hidden rows | P22 | Phones: no Window mode, no TATE, no Quit game; Web: no TATE, no Quit game; touch platforms: Touch section shown; focus order and wrap computed after filtering |
| Tier-hidden rows | Feature not shipped | Auto-bomb, death-bomb grace, Rumble, per-slot pad maps, presets, input test absent until their tier ships |
| Listening-for-input | Confirm on a BINDING cell | Cell shows "Press a control for {action}" strip; all Nav ignored; accepts the next control from the **edited class** (Keyboard keys for KB1/KB2; pad buttons for pad classes; any connected pad, since pad classes are per class, not per GUID). No timeout. Esc or pad Back or the Cancel plate cancels |
| Reserved control pressed | Esc excepted, Back excepted | Strip text becomes "{control} is reserved" (+ `sfx_ui_deny`); **stays listening**. Mouse button: "Mouse buttons cannot be bound". Tab/Ctrl/F-keys/Alt/Meta/Print and pad Start/Guide the same |
| Conflict / swap | Control already bound to another action in this class | Inline strip "{control} is used by {other}. Swap with {action}?"; Swap / Cancel, **default Cancel**; Confirm runs the swap (Input Rule 36); Cancel returns to the list unchanged |
| Swap would empty an action | The other action's only binding would be lost | Refused: "{other} needs at least one control" (+ `sfx_ui_deny`); no change (OQ 4) |
| Same control, same action | Bound already to this action | No change; toast "Already bound to {action}" |
| KB1/KB2 clash | Key used in the other keyboard class | Refused: "{control} is used by {other keyboard}" (+ `sfx_ui_deny`) (Input Rule 36; OQ 4) |
| Last-binding protection | Clear on the only binding of Fire / Drone / Bomb | Refused with `sfx_ui_deny` and a toast "{action} needs at least one control"; clearing an alternate is allowed |
| No pad connected (pad class) | Edit pad class with only a keyboard | Rows show; listening strip reads "Press a button on a controller" and only Esc/Cancel works; INFO line "No controller connected" |
| Preset confirm | Confirm on a layout preset | Inline strip "Replace {class} controls with {preset}?" Apply / Cancel, default Cancel (OQ 5) |
| Assist active (from Pause) | A run is live and an ASSIST row is off its default | Row shows a PRACTICE tile and the line "Marks this run PRACTICE when you resume. Not ranked." Returning the row to 100% before resuming removes the line and sets nothing (the latch sets on the first game tick, Accessibility Rule 23) |
| Run already PRACTICE | `run.assisted` true | Banner row at the top of Assists: "This run is PRACTICE" (tile + text) |
| Text size 2-3 | `access.text_size` | Rows stack (label above control); list scrolls; sample line updates live |
| High contrast HUD | `access.hud_contrast` HIGH | Plate edges Cream, dim text `#A89E8A`; also applies to Settings plates |
| Reduce motion / pulsing | `access.reduce_*` | Screen change is a cut; focus pulse steady; toasts without slide; hold bars still fill |
| Double tap confirm | `access.confirm_style` DOUBLE_TAP | HOLD_BUTTONs show "Press again" for 120 ticks after the first press; a press on another item cancels |
| Loading / building | Opening a page | No spinner: rows are generated from data and only visible rows instantiated, built within one frame (the Accessibility page, about 35 rows, included). Settings values are already loaded by Save before any menu |
| Empty | Pad class with no pad; no layout presets data; Input test with no device; non-touch platform | Rows show with an INFO line ("No controller connected"); Presets rows hidden when `layout_presets.tres` is absent; Touch section not listed |
| Save absent (MVP build, no Save) | Save autoload missing | Every row reads its default and stays editable; the "Progress will not be saved" note shows once per session; first-run plate hidden |
| Assist set (from Title) | `access.game_speed_pct` < 100 on any opener | Row shows the PRACTICE tile and "Runs are PRACTICE (not ranked) while this is below 100%" |
| Inactive rows | Confirm hold under Double tap; Chain cue rumble without Rumble | Text keeps full contrast (4.5:1 minimum); an inactive glyph before the value plus the reason in the help line mark the state; never dimmed below 4.5:1 and never colour-only (style left to art-director, OQ 19). Row stays focusable and editable |
| Save failure | `save_failed(settings, reason)` on commit | Toast of `save_toast_ticks` (90 ticks) "Could not save", never dropped, `sfx_ui_save_error`. **Alarm Red `#E03A3E` is never a text fill** (about 3.95:1 on the dark plate, below 4.5:1): the toast is **Cream words plus an Alarm Red plate edge and/or an error glyph** (tier S or larger), glyph **and** words. *(Amended 2026-11-03, final doc closeout:)* the one **headline** status line may instead be drawn in **Alarm Flare `#F2494D`** (art bible 4.1; 4.76:1 on Char, computed), the text-only red; the explanatory sentence stays **Cream**, the Alarm Red edge and/or error glyph is still required, and under `hud_contrast` HIGH the headline renders Cream - the toast headline ("Could not save") is the single line allowed to take it, and staying all-Cream is equally correct (`design/ux/arcade-ui-style.md` 3.1 rule 3 "two reds, two jobs"; art bible 4.1); changes stay active in memory; the file stays dirty and retries at next commit |
| Save unavailable | Web storage blocked, read-only disk | Once per session toast "Progress will not be saved"; Settings stays fully editable |
| Newer save version | `save_failed(file, "newer_version")` | Settings opens with defaults; edits apply but are not kept; notice already shown at boot |
| Language changed | CHOICE | Labels swap in one frame; Language row shows own-script values; nothing shifts |
| Touch device | Touch platform | Row height `touch_item_h` (55 canvas px at x3 / 458 dpi); steppers 24x24 minimum; list scrolls |
| TATE active | `tate_mode` != Off | Layout and pointer mapping come from the presenter (Display F7); Menus has no rotation code |

---

## Interaction Map

Verbs only (G1). Focus order is top to bottom through visible, non-INFO rows (wraps); Left/Right change the value of the focused row, or move between cells on a BINDING row. **Holds count Fire (Confirm) only; Start never starts a hold** (`pause.md` decision), and Start is ignored in Settings opened from Pause. Group jump (L1/R1, PageUp/PageDown) is a convenience, never the only path, and is suppressed while the physical shoulder button is bound to Fire/Drone/Bomb in the active pad class (the Gamepad: one hand preset binds Fire to the left shoulder). Pad: D-pad/stick Nav, Fire/Start = Confirm, Bomb/Back = Cancel, Drone = secondary (used here only for Clear in Controls; also toggles language on Title, not here). Keyboard defaults: arrows, Enter/Z/Space, Esc/C, the `drone` key.

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Any list | Move focus | Up/Down (repeat per `access.nav_repeat`) | Up/Down | Hover moves focus; wheel/drag scrolls | Focus border + arrow, `sfx_ui_nav_tick` | Wraps, skips INFO and hidden rows |
| LINK | Open | Confirm | Enter/Z/Space | Click / tap | `sfx_ui_confirm`, 6-frame menu transition | Next level |
| TOGGLE | Flip | Confirm or Left/Right | Enter or Left/Right | Click | Value text changes, `sfx_ui_nav_tick` | `set_setting`, live |
| CHOICE | Cycle | Left/Right | Left/Right | Click cycles forward; each side half click on touch | Value text changes | `set_setting`, live; TATE opens dialog |
| STEPPER | +/- | Left/Right (hold repeats) | Left/Right | Click the 24x24 arrows or the bar cell | Bar cell fills; `sfx_ui_slider_preview` on Master/SFX | `set_setting`, clamped 0-10 (or the row's range) |
| BUTTON | Run | Confirm | Enter/Z/Space | Click | `sfx_ui_confirm` | Action; Calm preset shows a toast |
| HOLD_BUTTON | Hold | Hold Confirm `confirm_hold` ticks | Hold Enter/Z/Space | Press and hold | 4-segment bar fills, Gold on completion (P04) | Runs the action; early release resets. DOUBLE_TAP: two presses within 120 ticks |
| BINDING cell | Start listening | Confirm | Enter/Z/Space | Click | Strip opens, `sfx_ui_confirm` | Listening state |
| BINDING cell | Move between primary / alternate / reset | Left/Right | Left/Right | Click the cell | Focus border | — |
| BINDING cell | Clear | Drone | the `drone` key | Small "x" plate 24x24 | `sfx_ui_cancel` | Clears **alternate** only; refused on the last binding |
| Listening strip | Bind | Next pad button (not Back / Start / Guide) | Next key (not reserved) | n/a | `sfx_ui_confirm`, cell shows the glyph | `set_setting("input.bindings")`, live |
| Listening strip | Cancel | Back | Esc | Cancel plate | `sfx_ui_cancel` | No change |
| Swap strip | Choose | Left/Right, Confirm | same | Click | `sfx_ui_confirm` | Swap or cancel; the binding press itself is consumed |
| TATE dialog | Keep / Cancel | Left/Right + Confirm on Keep; Confirm on default = Cancel | same | Click | Tick per second | Keep persists value; Cancel/timeout reverts |
| Language row | Choose | Left/Right | Left/Right | Click chip | One-frame swap | `Localization.set_language`, `set_setting("language")` |
| Accessibility list | Jump group | Shoulder buttons (L1/R1) | PageUp / PageDown | Scroll | `sfx_ui_nav_tick` | Focus moves to the first row of the previous/next group (proposed, OQ 11) |
| Back | Cancel | Bomb / Back | Esc, C | Back plate 24x24 | `sfx_ui_cancel` | Up one level; index closes Settings and commits |
| Any row (owner screen) | Press from a non-owner | ignored | ignored | n/a | Owner tag dim on the other tag | Nothing |

Settings opened from Title is **shared**; from Pause it is **owned** (P10). Hover never activates (G2).

## Events Fired

| Player Action | Event / Call | Payload | Persistent state? |
|---|---|---|---|
| Change any row | `set_setting(key, value)` -> `settings_changed(key)` | key, value | In memory only; marks file dirty |
| Bind / swap / clear / reset a control | `set_setting("input.bindings", data)` | class, action, controls | In memory; persists at close |
| Apply layout preset | One `set_setting("input.bindings", ...)` (+ `input.fire_toggle` for pad one-hand, `touch.one_hand`) | preset id | In memory; persists at close |
| Calm preset (Accessibility) | Four `set_setting` calls in one batch | — | In memory; persists at close |
| Close the Settings index (Cancel / Back plate) | `commit_settings()` once, only if dirty | — | **Yes** (`settings.json`): flag for Save. Opening, section pages, and no-change closes write nothing |
| Reset settings (hold completes) | `reset_settings()` then immediate write | — | **Yes** (immediate, Save Rule 20) |
| Clear scores (hold completes) | `clear_scores()` then immediate write | — | **Yes** (`scores.json`, deletes `.bak`, `.corrupt`) |
| Reset display (hold completes) | `set_setting` x4 to defaults | — | In memory; persists at close |
| Reset these options (Accessibility) | `set_setting` for every `access.*` default | — | In memory; persists at close |
| TATE changed | Display enters TateConfirm | new value | Keep: value set; Cancel/timeout: previous restored |
| Yes on Quit dialog | Application exit; Save close handler | — | **Yes** if dirty (`settings.json`) |
| First-run answer | `set_setting("access.first_run_prompt_done", true)` (+ Calm values) then `commit_settings()` once | choice | **Yes** (`settings.json`) |
| Window close while dirty | Save close handler | — | **Yes** |
| Per-action reset / Reset this device | `set_setting("input.bindings", data)` | class, action | In memory; persists at close |
| Use shared pad map | `set_setting("input.bindings", data)` removing `pad_s{n}` | slot | In memory; persists at close |
| Open Input test, group jump, move focus, No on Quit, Cancel on any strip | none (null) | — | No |
| Reset settings held | also toast "Settings reset" (Save notice) | — | See above |
| Save failure | Toast | reason | No |
| Language change | `Localization.set_language` | `bn` / `en` | Persists at close (Title chip commits itself) |

Analytics: none defined in any GDD (same as Title; `analytics-engineer` input needed if wanted).

## Transitions & Animations

| Motion | Spec | Reduce motion | Reduce pulsing / flashing |
|---|---|---|---|
| Open / close Settings | Stepped Char wipe 12 frames (Title) or panel in/out 8 frames (Pause) | Cut / appear in place | — |
| Level change (index <-> page) | 6-frame menu transition | Cut | — |
| Focus move | Instant; arrow snaps | — | Pulse off |
| Stepper bar | Cell fills in one frame | — | — |
| Hold-to-confirm bar | 4 stepped segments, Gold on completion | Unchanged (functional) | Unchanged |
| Listening strip | Appears in place; no blinking cursor | — | — |
| TATE countdown | Numeral steps each second; bar segments empty one by one | Unchanged (functional) | Unchanged |
| Calm preset applied | Toast (8 frames in/out, 90 ticks) | Appear in place | — |
| Text size change | Reflow in one frame | — | — |
| Toast | 8 frames in/out, 90 ticks (Save notices never dropped) | Appear in place | — |
| First-run plate | In place after wipe; static | — | Static always |

Nothing in Settings flashes. Settings changes made live (ring opacity, palette) are visible in the preview plate only, never as a full-screen change.

## Data Requirements

| Data | Source System | Read / Write | Update trigger | Null handling |
|---|---|---|---|---|
| Setting values | Save (26) `get_setting` | Read | On open and on `settings_changed(key)` | Missing key = schema default; unknown enum falls back to default per key |
| Setting writes | Save (26) `set_setting`, `commit_settings`, `reset_settings`, `clear_scores` | Write | On change / close / hold | Rejected value (out of range, wrong type): row keeps its value, `sfx_ui_deny` |
| Option defs | `data/accessibility/access_options.tres` | Read | At screen build | Missing label key = English string (Localization fallback); never a raw key |
| Layout presets | `data/accessibility/layout_presets.tres` | Read | At screen build | Absent = Presets rows hidden |
| Bindings | Input (2) `InputBindingsData` | Read / Write | On open and on bind | Invalid saved id: action shows its default (Input Rule 39) |
| Glyph family per device | Input F8 `Input.get_joy_name` | Read | On device change | Unknown = Generic glyphs |
| Layout (`get_layout()`) | Display (4) | Read | On any layout change | None = info line hidden |
| `run.assisted`, run active | Session (1) | Read | On open and per Pause tick | Not in a run (Title) = no assist warnings |
| Platform tags, device availability | Engine / Display | Read | On open | Unknown platform = most restrictive (hide TATE, Quit, window mode) |
| Text step | Localization `font_size_px(tier, step)` | Read | On change | Out of range = 0 |
| `save_failed`, Save state | Save (26) | Read | Event | Toast with reason |
| Owner slot | Menus (P10) | Read | On disconnect | Lowest connected bound slot |
| Input test state (`pressed`, `held`, `held_ticks`) | Input (2) | Read | Every physics step while the screen is open | Device missing = "No controller connected" |
| Strings (`opt.*`, help, messages) | Localization (27) | Read | On open and `language_changed` | Missing key = English string |

UI owns no game state; the screen is a view over `MenuModel` (node-free). Rows are generated from data; only visible rows are instantiated.

## Accessibility

Tier COMPREHENSIVE (`accessibility-requirements.md` section 1.1 and 5.2); `accessibility-options.md` wins on conflict. **Contrast:** Cream text on Cabinet Char 7:1 or better (art bible 7.8); HIGH contrast dim text `#A89E8A` 6.5:1; standard dim `#5A5148` 2.2:1 is used for decoration only, never for text that carries information; Alarm Red `#E03A3E` is about 3.95:1 on Char and is therefore **never a text fill anywhere in Settings**; failure and error states use **Cream words plus an Alarm Red plate edge and/or error glyph**, glyph and words together. *(Amended 2026-11-03, final doc closeout:)* a **text-only** red token now exists - **Alarm Flare `#F2494D`**, 4.76:1 on Char (computed, art bible 4.1) - and at most **one headline status line per screen** may use it, with the Cream sentence repeating the same words, the Alarm Red edge and/or glyph still present, and Cream substituted under `hud_contrast` HIGH. It is never a fill of any kind. The 4.76:1 headline is the documented exception to the 7:1 menu line (`design/accessibility-requirements.md`, "Contrast of plated UI" row). Style-guide Open Question 2 is closed by that decision; the protanopia re-measurement of Flare is still open. Focus is a 3 px Cream border plus arrow. **Screen reader:** out at Vertical Slice, reconsider at Target (requirements section 4); focus order and text are exposed for a later layer.

- **Gamepad only:** every row, rebind, preset, dialog and the first-run plate completes with the pad (Nav, Confirm, Cancel, Drone for Clear, shoulders to jump groups). No mouse.
- **Keyboard only:** same verbs; Esc/C cancel; Enter/Z/Space confirm; PageUp/PageDown jump. Tab, Ctrl, F5, F11, F12 are never verbs (browser-reserved, Menus Rule 50).
- **Pointer / touch:** every row operable by click/tap; Back plate 24x24; steppers 24x24; touch rows 9 mm. A pointer cannot rebind or join; no mouse buttons can be bound.
- **Text:** `font_size_px` step applies to S/M tiers (rows, help, prompts); L/XL identity. Rows grow, stack from step 2, list scrolls, focus stays in view. Minimum 12 px Latin / 17 px Bengali. Outline 1 px; contrast 7:1 or better (art bible 7.8). Preview text sample shows the new size before leaving the row.
- **Colour independence:** focus = 3 px border + arrow; values are text; ASSIST = tile + word PRACTICE; group class = text label; slot identity in the Visual preview = ring pattern + pips + "P{n}"; toggles show "On/Off" words plus a check glyph.
- **Timing:** no timer on Settings except the TATE confirm (safety timer, Accessibility Rule 33, cannot be disabled; defaults to Cancel) and the DOUBLE_TAP window (120 ticks, the alternative itself). `confirm_hold` and `confirm_style` change all holds.
- **Motion / flashing:** nothing flashes. Focus pulse respects `reduce_pulsing`; transitions respect `reduce_motion`. Functional animation (hold bar, countdown) stays.
- **Audio:** slider preview has a visual twin (the bar fills); the muted glyph at 0; `audio.mono` available here. Menus play no rumble.
- **Reserved-control safety:** Esc and pad Back always exit listening; a player can never be stuck in it.
- **Screen reader:** see the stance above (out of scope until Target).
- **Checklist:** keyboard only [x]; gamepad only [x]; min font size [x]; not colour-only [x]; no flashing [x]; subtitles n/a (no speech); scales at supported resolutions [x, AC-12].

## Localization Considerations

- Menus are **single-language**; the dual-script exceptions here are the first-run plate and the TATE confirm title (Bengali above English). The Language row values are `বাংলা` and `English` in their own scripts.
- Reserve +40% width and +25% height per label (style guide 2.2). Label column 148 px, control column 172 px; if a label does not fit one line it wraps (max 2 lines Latin, 3 Bengali) and the row grows. Never truncate.
- **Character budgets at text step 0** (verify with the real font and F5 lint; Bengali reservation applied): row label <= 22 Latin / 16 Bengali characters on one line; value text <= 14 Latin / 10 Bengali; help line <= 64 Latin / 44 Bengali per line (2 lines). Digits on the shared digit grid (Bengali ০-৯ when Bengali is chosen), including volume numerals, ring opacity, game speed, hold ticks. Key names (Esc, Enter, Space, Tab) and "P1"-"P4" stay Latin in both languages. Grouping `৯৯৯,৯৯৯,৯৯৯`.
- **Longest labels are on the Accessibility page**: "Other players' shots", "Short era transition", "Chain bar near plane", "Reduce flashing and effects" (first-run), "Marks the run PRACTICE: not ranked", "Replace {class} controls with {preset}?", "{control} is used by {other}. Swap with {action}?". These are HIGH PRIORITY for Bengali review; placeholders `{control}`, `{action}`, `{other}`, `{class}`, `{preset}` must be re-orderable in Bengali (Localization placeholder rule). Action names (Fire, Drone, Bomb) follow the glossary (Menus Open Question 7).
- Controls strings use the current device family (F8) for glyphs; physical key labels are Latin.
- Bengali strings are drafts until native review (the Bengali plate text above too). Group sub-labels (ranked-safe / PRACTICE) must be translated, not abbreviated; PRACTICE appears as "PRACTICE / অনুশীলন" elsewhere (Accessibility V/A) but here only the chosen language shows.
- Language swap: one frame, no layout shift; measured layout reserves the wider of the two strings per row.

---

## Acceptance Criteria

Testable without other documents. "Row" = an item on the Settings pages.

- [ ] Opening Settings from Title or Pause performs zero writes; closing with no change performs zero writes; closing after one change performs exactly one `commit_settings()`; moving between section pages commits nothing.
- [ ] From Pause, Settings is owner-only: a press from another bound slot changes no focus and no value; the owner tag shows the owner's "P{n}" and ring pattern; if the owner's pad disconnects, ownership moves to the lowest connected bound slot and any open listening state is cancelled without a binding change.
- [ ] The five sections open from the index; Cancel returns to the opener with focus restored; Down from the last index row wraps to the first; rows hidden by platform (Window mode on phone, TATE on Web/phone, Quit on Web/mobile/Pause, Clear scores on Pause) are absent and wrap is computed without them.
- [ ] Audio steppers clamp at 0 and 10; Left at 0 and Right at 10 do nothing; Master and SFX play `sfx_ui_slider_preview` at most once per 6 ticks; Music plays none; SFX at 0 shows the muted glyph and mutes menu sounds.
- [ ] Changing the TATE row opens the confirm dialog with default focus Cancel; Confirm on the default reverts; pressing Right then Confirm keeps it; no input for 10 s (real time, including while paused) reverts; `display_reset` held 2 s closes the dialog and restores defaults.
- [ ] Reset display held for `confirm_hold` ticks restores Auto, Windowed, TATE Off, Art; releasing early changes nothing; the info line reads "Scale x{n} - {w}x{h}" or "Scale {f} (Fill)" and updates within one frame of any scaling change.
- [ ] Controls: Confirm on a binding cell shows "Press a control for {action}" and ignores Nav; pressing a free key binds it and the new glyph shows; Esc / pad Back cancels with no change; Esc, F1-F12, Tab, Ctrl, Alt, Meta, Print, any mouse button and pad Start/Guide each show a reserved message (except Esc/Back, which cancel) and the strip keeps listening.
- [ ] Binding a control used by another action in the same class shows the swap strip with default focus Cancel; Swap exchanges the two controls; if the other action would be left with no binding, the swap is refused with a message and nothing changes.
- [ ] Clearing the only binding of Fire, Drone or Bomb is refused with `sfx_ui_deny` and a message; clearing an alternate succeeds; "Reset this device" held restores that class's defaults and leaves other classes untouched.
- [ ] Reset settings held `confirm_hold` ticks restores every known key to default except `profile.last_initials` and `tutorial.*`; scores remain; Clear scores held shows "This cannot be undone", empties all boards and records on completion, and is unavailable from Pause.
- [ ] With `confirm_style` DOUBLE_TAP every HOLD_BUTTON confirms on two presses within 120 ticks and cancels on a press at tick 121 or on another item; `confirm_hold` SHORT/NORMAL/LONG confirm at 40/60/90 held ticks.
- [ ] ASSIST rows (Game speed) show the PRACTICE tile and the consequence line when changed from Pause during a live run; setting it back to 100% before resuming removes the line; after resume at <100% the Pause panel shows PRACTICE.
- [ ] The first-run plate shows once before Title when `first_run_prompt_done` is false: default focus Keep as is; Reduce flashing and effects sets the four Calm values and Done in one commit; either answer sets Done; the second launch skips it; the answering press does not act on Title; no element pulses.
- [ ] Quit game dialog shows only on PC/Switch from Title; default focus No; Cancel = No; Yes exits.
- [ ] Rows and text: at `text_size` 3, in English and Bengali, every Settings page shows no clipped label, rows stack, the list scrolls, and the focused row stays visible; the language swap moves no element.
- [ ] Resolution: all pages are fully operable (click, focus, scroll) in windowed 540x960, fullscreen 2560x1440 and TATE CW; a click in the bezel activates nothing.
- [ ] Error state: with a forced `save_failed`, closing Settings shows "Could not save" as a never-dropped toast, the changed values stay in effect, and the next close retries the write; with storage blocked the "Progress will not be saved" toast shows once per session.
- [ ] Performance (targets to confirm): building the Accessibility page (about 35 rows plus group headers) costs under one frame (16.6 ms) on REF-WEB by instantiating visible rows only; Settings adds zero per-tick work during a stage; open transition completes in 12 frames.
- [ ] Platform rows: on a touch device the Touch section lists seven rows with rows at least 9 mm tall; "Max on this screen" appears when `touch.button_scale` is capped.
- [ ] Input test: opens from Controls, shows one column per connected device, each pressed control shows a filled box and held-tick numerals within one physics step, Back/Esc always exits, and no tested control activates anything.
- [ ] Touch: on a touch device every tappable element (Back plate, stepper arrows, rows) has a hit area of at least `min_target_canvas_px` (55 at x3 / 458 dpi) on both axes with no overlap.
- [ ] Layout: at text step 3 in Bengali the help line (up to 2 lines) never overlaps the list viewport or the toast zone, and the first-run plate fits inside 360x640 with no clipping.
- [ ] Reset settings keeps `language`, `first_run_prompt_done`, `profile.*`, `tutorial.*` and `touch.hints_seen` (the whole Save Rule 30 keep-list); after it the first-run plate does not reappear, the touch hints do not re-show and the UI language is unchanged.
- [ ] With `game_speed_pct` 80 opened from Title, the row shows the PRACTICE tile and the consequence line; with Save absent, Settings is editable and shows "Progress will not be saved" once.
- [ ] Keyboard-only and gamepad-only testers complete every row, a rebind with swap, a preset, the TATE dialog, a hold action and the first-run plate with no mouse.

---

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~**Hold length for Reset display.**~~ **CLOSED 2026-11-03 (wave 5 batch 2):** this spec's answer is adopted. [Menus (22)](../gdd/menus-title-plane-select.md) **Rule 43** now reads "same effect as `display_reset`, with the normal `confirm_hold` length", AC-50 says `confirm_hold` ticks (60 at NORMAL), and [Display (4)](../gdd/display-scaler-and-bezel.md)'s UI table says "same result as `display_reset`; hold length is `confirm_hold`". The 2 s real-time `display_reset` hotkey stays a separate path. Original note: Display GDD says `display_reset` is a 2 s hold (120 ticks, `display_reset_hold_seconds`); Menus called the Settings button "equal to `display_reset`" while AC-50 said 60 ticks and Accessibility said holds use `confirm_hold`. | — | Closed |
| 2 | ~~**TATE dialog scripts.**~~ **Closed 2026-11-03:** the Display GDD wins; the dialog title is dual-script and `arcade-ui-style.md` 2.1 now lists it. Original note: Display UI Requirements say the dialog is "Bengali and English"; the style guide lists only the first-run plate and Web gate as dual-script. This spec renders it in the chosen language. If both scripts are wanted (a rotated screen is hard to read), amend the style guide. | art-director / Display | Pre-Production UX |
| 3 | ~~**`reset_settings()` side effects.**~~ **CLOSED 2026-11-03 (wave 5 batch 2):** [Save (26)](../gdd/save-settings-high-scores.md) **Rule 30** now keeps an explicit keep-list - `language`, `access.first_run_prompt_done`, `profile.*`, all `tutorial.*` and `touch.hints_seen` - and **AC-26** asserts it. Original note: `reset_settings()` restored every known key, so the photosensitivity prompt would reappear and `language = auto` could flip the UI to the OS guess. | — | Closed |
| 4 | **Rule 36 vs Rule 37.** Input Rule 36's swap can strip the other action's only binding, breaking Rule 37; and cross-class KB1/KB2 clashes have no stated resolution. This spec refuses both with a message. Confirm or define swap semantics. | Input (2) | Input amendment |
| 5 | **Preset overwrite confirm and target class.** GDD says presets write overrides in one action; this spec adds a default-Cancel confirm strip and leaves open which class each keyboard preset writes (KB1 or KB2); the preset name "Keyboard: left hand" also clashes with the class name "Keyboard: Left hand" (KB2). | Accessibility (28) / Input (2) | VS |
| 6 | **BINDING item kind, Clear verb and per-slot map creation.** New kind (two cells per row) and Drone = Clear are proposals (P03 has no multi-cell row). Per-slot pad map creation ("edit Gamepad P2 copies the shared map; Use shared pad map removes it") is not in the GDD. Add to the pattern library. | ux-designer / Input (2) | `/ux-review` |
| 7 | **PRACTICE safeguard.** The GDD lets players change assists from Pause with a non-blocking warning only. A hold-to-confirm on the first move off 100% during an unassisted live run would prevent accidental loss of rank. Wanted? | game-designer / Accessibility | VS playtest |
| 8 | **Clear scores and Quit game from Pause.** Menus Rule 45 does not say; this spec hides both in Pause. Confirm. | Menus (22) | Menus review |
| 9 | **Info line text** differs between Display UI table ("Scale x3 - 1080x1920") and Display Interactions ("Scale x3 (1080x1920)"); and a fractional scale "1.69" needs a localized decimal separator and digits (`format_int` handles integers only). | Display (4) / Localization (27) | VS |
| 10 | **TATE Keep persistence.** Display says the value is "saved on Keep"; Save writes only at Settings close. This spec treats Keep as `set_setting` with the file write at close (window-close handler covers exits). Confirm there is no immediate commit. | Display (4) / Save (26) | Save review |
| 11 | **Group-jump verb** (shoulders / PageUp-PageDown) on the long Accessibility list and the group sub-labels are proposals; the GDD only fixes the group order. | ux-designer | `/ux-review` |
| 12 | **Apply modes not stated** for `chain_bar_near_plane`, `confirm_style`, `confirm_hold`, `nav_repeat`, `untimed_menus`, `continue_timer`, `tally_auto_advance`, `touch.*` (marked "(a)" = LIVE assumed); and the group of `era_transition_short` (placed in Visual here). | Accessibility (28) / owners | Registry pass |
| 13 | **Device classes on non-desktop platforms.** Whether Keyboard classes are listed on phones/Switch with no keyboard, and whether Web shows a pad class when no pad is present, is not defined. This spec lists a class only when its device is available or the platform supports it. | Input (2) | VS |
| 14 | **Bengali strings** for all `opt.*`, group headings, listening/swap/refusal messages and the first-run plate need translation and conjunct tests at text steps 0-3. Drafts above are not reviewed. | Localization (27) | Before string soft freeze |
| 16 | **MVP vs VS rows** for Fire mode / Tap Assist / Deadzone are assumed Vertical Slice (requirements 1.1 lists only the remap list at MVP). Confirm. | Input (2) / Accessibility (28) | Planning |
| 17 | **Keycap short names** (7 characters max) for long key names. | Input (2) / Localization (27) | VS |
| 18 | **Start in Input test** is ignored (Back exits); confirm for Pause-opened Settings. | Menus (22) | Menus review |
| 19 | **Inactive-row style** (glyph, contrast at least 4.5:1). | art-director | Art review |
| 20 | **Switch rows**: Window mode and Scaling likely hidden on Switch; not stated by Display. | Display (4) | VS |
| 15 | **Touch hold-to-confirm** (60 ticks on a thumb that covers the bar) is still open (pattern library OQ 6); applies to Reset settings and Reset display on touch. | ux-designer | Touch playtest |
