# Accessibility Requirements: MorutJan

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** — Open Questions in this document stay open.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Template**: none found in `.claude/docs/templates/`; structure follows the UX layer conventions of `design/ux/arcade-ui-style.md`
> **Sources**: `design/gdd/accessibility-options.md` (the registry; wins on any conflict), `design/art/art-bible.md` 4.4-4.8, 7.7, 7.9, 7.10, `input-and-player-mapping.md`, `audio.md`, `touch-controls.md`, `localization.md`, `tutorial.md`
> **Rule**: this file commits a tier and lists requirements per screen. It adds no game rules. Anything new is in Open Questions.
> **Revision 2026-11-03 (final doc closeout, art-director A3)**: section 3.2 records the exception to the "7:1 on menus" row for the single Alarm Flare `#F2494D` headline line at 4.76:1 (text only, Cream repeat, Cream under HIGH contrast). The protanopia re-measurement of Flare stays open.
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: T-05 pass condition now names the **DROP** action on the controller-lost plate; the Settings / Accessibility / Controls row and gap G4 record that `design/ux/settings.md` now exists; the Credits and Results rows are aligned with the applied GDD amendments.

---

## 1. Committed Tier

**Tier: COMPREHENSIVE** (Game Accessibility Guidelines: all Basic and all Intermediate items met or not applicable; selected Advanced items met; Exemplary items explicitly out of scope).

| Tier | Meaning for MorutJan | Committed? |
|---|---|---|
| Basic | Remap, text size, volume sliders, not colour-only, no unwarned flashing, pause | Yes (floor) |
| Standard | Basic plus reduced motion, contrast option, hold alternatives, one-handed play, photosensitivity prompt, practice speed | Yes |
| **Comprehensive** | Standard plus per-slot pad maps, input test screen, colour-vision palette with luma spread, sound visual twins, background dim/plain, untimed menus, unranked-assist model | **Yes (the commitment)** |
| Exemplary | Screen reader / TTS, one-switch play, full touch layout editor, per-bullet customisation, AI-driven difficulty | No (section 4) |

**Why this tier:** the accessibility GDD already designs 30+ options covering every Basic and Intermediate guideline (its own checklist, "Visual/Audio Requirements"). Committing lower would leave designed work unprotected by the gate check. Committing Exemplary would need narration, one-switch and bullet changes that the pillars forbid (section 4). The score stays meaningful: assists mark a run PRACTICE instead of changing ranked rules.

### 1.1 Delivery stages (matches GDD tiers)

| Stage | What must be true | Gate |
|---|---|---|
| MVP | Hooks read with defaults: `reduce_flashing`, `reduce_pulsing`, `reduce_motion`, `effects_level`, `tally_auto_advance`; remap list; pause anywhere; patterns never colour-only; audio sliders and mono | Pre-Production exit |
| Vertical Slice | Full Accessibility screen, Controls screen (presets, per-slot pad maps, input test), text size, palette, hud contrast, game speed + PRACTICE latch, first-run prompt, Calm preset | Production exit |
| Target | Rumble option, auto-bomb and death-bomb grace contracts (keys only until Collision `will_die`), touch section, adaptive-controller test | Release candidate |

---

## 2. Principles (from the GDDs, not new)

| # | Principle | Source |
|---|---|---|
| 1 | Bullets always win: no option changes an enemy bullet's colour, shape, size, outline, opacity, speed, layer or hit radius; the hitbox dot is never hidden | Accessibility Rule 5; Pillar Readable Chaos |
| 2 | Ranked rules never move; options are PRESENTATION, INPUT_CONVENIENCE, TIMING_UI (ranked) or ASSIST (marks the run PRACTICE) | Accessibility Rule 6, 23 |
| 3 | Nothing is colour-only: ring pattern, pip count, "P{n}" text, glyph shape, numbers | Art bible 4.8, 7.10; Accessibility Rule 17 |
| 4 | Every P0/P1 sound has a visual twin; no caption strip | Accessibility Rule 30; Audio OQ10 (closed) |
| 5 | No UI over the field; live-field help is an icon, numeral or thin bracket | Art bible 7.7; Tutorial Rule 2 |
| 6 | The only flash in the game is the Critical Break frame, and it is removable | Arcade UI style section 4; Accessibility Rule 8 |
| 7 | Playable on keyboard only, gamepad only (primary), and touch (solo) | Accessibility AC-46; Touch controls |
| 8 | Settings can be changed from Pause and take effect at the documented moment (LIVE, EVENT, STAGE, RUN) | Accessibility Rule 4 |

---

## 3. Requirements Matrix

Status key: **Designed** = specified in a GDD (cited); **UX spec** = also has a `design/ux/` screen; **Gap** = not specified or unverified.

### 3.1 Motor

| Requirement | Status | Where |
|---|---|---|
| Remap every keyboard and pad action; reserved keys listed | Designed | Input Rules 34-39; Accessibility Rule 21 |
| Per-slot pad maps (swap a pad, keep the layout) | Designed (VS) | Accessibility Rule 21 |
| No action needs two buttons on one tick | Designed (audit) | Accessibility AC-47 |
| Fire toggle (no hold) | Designed | Input Rule 19 |
| Tap Assist (hold gives synthetic taps, capped by the kit) | Designed; ranked | Input Rule 20 |
| Auto-fire / turbo | Decided out: Fire toggle + Tap Assist suffice | Accessibility Rule 21 (Kits OQ2 closed) |
| Stick deadzone presets | Designed | `input.dz_preset` |
| Stick choice (left / right / either) | Designed (proposed Input amendment) | `input.move_stick` |
| One-handed presets: keyboard L/R, pad one-hand, touch one-hand | Designed | Accessibility Rule 21; Touch Rule 10 |
| Hold-to-confirm can become double-tap; hold length 40/60/90 | Designed | `confirm_style`, `confirm_hold` |
| Menu repeat rate FAST/NORMAL/SLOW | Designed | `nav_repeat` |
| No timed menus when asked: name entry, Lobby idle, drop-in pick | Designed | `untimed_menus` |
| Continue timer 10 s / 30 s / untimed | Designed | `continue_timer`, F9 |
| Practice speed 50-100 % (unranked) | Designed | `game_speed_pct`, F2 |
| Touch: relative drag, button scale 100/125/150, hand side, sensitivity | Designed | Touch Rules 4, 7, 8, 19 |
| Touch: drag-and-place layout editor | Out of scope | Touch OQ5 |
| Adaptive controller (presents as gamepad) | Designed; untested hardware | Accessibility Rule 21, OQ7 |
| Input test screen (live pressed/held) | Designed (VS); no UX spec yet | Accessibility Rule 21d |
| Auto-bomb, death-bomb grace (3/6 ticks) | Contract only (Target, ASSIST) | Accessibility Rule 25 |

### 3.2 Vision (low vision, contrast, text)

| Requirement | Status | Where |
|---|---|---|
| Text size 4 steps on S/M tiers (Latin cap 12/15/18/24, Bengali 17/21/25/33) | Designed | Accessibility Rule 19, F1 |
| Minimum text 12 px Latin / 17 px Bengali at step 0, 1 px outline | Designed | Art bible 7.10; arcade-ui-style 2.2 |
| High-contrast HUD (ghost digits 2.2:1 to 6.5:1) | Designed | `hud_contrast`, F6 |
| Hitbox dot always on, 6 px, 100 % | Designed | Accessibility Rule 13 |
| Hitbox ring size (22/30 px) and opacity (40-100 %) | Designed | Rule 13, F7 |
| Other players' shots dim (25 % floor) | Designed | Rule 14, F3 |
| Background FULL / DIMMED 65 % / PLAIN (bullet contrast without touching a bullet) | Designed | Rule 12, F4 |
| Grayscale gate on all bullets in all backgrounds and eras | Designed | Rule 37; AC-15 |
| Near-plane chain bar (26x5 px, layer 7) | Designed; placement is an art review item | Rule 15; OQ6 |
| HUD scale | **Rejected on purpose** (field height fixed for ranked comparability) | Rule 20 |
| Pause status panel at the current text step | Designed; spec in `pause.md` | Rule 20; Menus Amendment 7 |
| Larger window / fill scale | Designed (Display) | Display scaler GDD |
| Magnification of the field on phones | **Gap** (field is about 60-70 mm wide; no zoom, see section 6) | Touch Rule 1-3 |
| Contrast of plated UI at least 7:1 on menus | Designed | Accessibility Visual/Audio table |
| &nbsp;&nbsp;↳ **Exception (2026-11-03, art-director A3):** the single **Alarm Flare `#F2494D`** headline status line (**4.76:1** on Cabinet Char, hand-computed; minimum 4.5:1) is allowed because the same words are repeated in Cream on that screen, an Alarm Red edge and/or error glyph is also present, and it renders **Cream** under `hud_contrast` HIGH. One headline line per screen, text only, never a fill. Without this exception the new token would contradict the committed COMPREHENSIVE tier on menu screens. | Designed (exception recorded) | art bible 4.1, 7.10; `arcade-ui-style.md` 3.1 rule 3; `production/ux-reports/_art-director-decisions.md` Decision 1 / A3 |

### 3.3 Colour

| Requirement | Status | Where |
|---|---|---|
| Slot identity never colour-only (solid / dashed / dotted / double ring, 1-4 pips, "P{n}") | Designed; mandatory, not switchable | Rule 17; art bible 4.4, 4.8 |
| `player_palette` DEFAULT / LUMA_SPREAD (luma gap 30.9, min dE 24.8 tritan) | Designed | Rule 17, F5 |
| No screen-wide colour filter (would change bullet hues) | Decided out | Rule 17 |
| Enemy bullets stay hue 225-265 degrees, white core, dark outline | Designed | Art bible 4.2, 4.3 |
| Warm player shots vs cool enemy bullets, shot shape differs from ring shape | Designed | Art bible 4.8 |
| Red/green pairs in HUD have shape or position backups (boss HP top bar + number; chain expiry end-cap) | Designed | Art bible 4.8; Rule 30 |
| CVD simulation overlay (F9, dev only, stripped in release) | Designed | Rule 18; AC-24 |
| CVD matrix values verified against the paper | **Gap** (computed from remembered coefficients) | OQ3 |
| P4 pink vs Needle blue under protan (dE 22.4, narrow) on real sprites | **Gap** | OQ2 |

### 3.4 Hearing

| Requirement | Status | Where |
|---|---|---|
| Separate Master / Music / SFX sliders (0-10); UI follows SFX | Designed | Rule 27; Audio |
| Mono option | Designed; downmix method unverified in 4.7 | `audio.mono`; Audio OQ3 |
| Visual twin for every P0/P1 sound (clank, ping, Warning, extend, chain expiry, boss critical, CB armed) | Designed; lint AC-39 | Rule 30 |
| Subtitles / captions | Not applicable: no speech; banners are text. No caption strip (no HUD space) | Audio OQ10; Rule 30 |
| Chain-window audio tick (on by default) and rumble (off) | Designed | Rule 28 |
| Rumble OFF / LOW / NORMAL | Designed (Target) | Rule 29 |
| Touch haptics OFF / LOW / NORMAL, never per shot | Designed | Touch Rule 32 |
| Sound never carries the only copy of information | Designed (audit) | Rule 30; AC-39 |

### 3.5 Cognitive

| Requirement | Status | Where |
|---|---|---|
| Pause anywhere (Stage, Tally, Continue, Warning, boss intro), opens within 1 tick | Designed | Rule 31; AC-42 |
| Not pausable: Lobby-to-stage Char hold; name entry (already untimed by option) | Designed | Rule 31 |
| Tally auto-advance off (waits for confirm) | Designed | Rule 32 |
| Tutorial: Flight School (11 drills, no gating, no failure state) and opt-out contextual hints | Designed; no UX spec yet | `tutorial.md` Rules 5-31 |
| Hints never over a live field; strip marks only | Designed | Tutorial Rule 2 |
| Plain-language prompts, Bengali + English, wrapped by words | Designed | arcade-ui-style 2.2 |
| Consistent focus, back and confirm across all screens | Designed | `interaction-patterns.md` |
| Quit/confirm protections (hold, with text "score will not be saved") | Designed | Menus Player Fantasy; pause.md |
| Difficulty-like options | Only game speed (PRACTICE); no damage, lives or invincibility assists | Rule 24, 26 |
| Reduce visual noise: effects level, background, reduce_* | Designed | Rules 9-12, 35 |
| Calm preset in one action; Reset these options (hold) | Designed | Rule 34 |
| Memory load of 4 kits' hold/tap rules | Plane card states three rows; school drills; no gap | Menus Player Fantasy |

### 3.6 Photosensitivity

| Requirement | Status | Where |
|---|---|---|
| Only one flash in the game: the Critical Break white frame | Designed | Arcade UI style 1; art bible 7.3 |
| Reduce flashing: no white frame, 80 warm particles, tint at most 25 % over 18 ticks | Designed | Rule 8 |
| Invulnerability blink becomes steady 65 % opacity | Designed; needs playtest | Rule 8; OQ4 |
| No brightness change faster than 1 Hz in the HUD; focus pulse at most 2 Hz and 40 % | Designed | Rule 8; arcade-ui-style 4 |
| Reduce pulsing (steady cues), Reduce motion (stripes, parallax 50 %, snap counts) | Designed | Rules 9-10 |
| First-run prompt before Title; Calm preset applies four values in one commit | Designed | Rule 34; AC-44 |
| Era transition short mode | Designed (not in Calm preset) | `era_transition_short` |
| Flash default | Gap: default focus is **Keep as is**, so a photosensitive player who skips the prompt gets the white frame | OQ 3 in section 8 |
| Screen-wide strobe tests of captured footage (Harding/PEAT-style) | **Gap** (no tool named) | Section 7, T-12 |

---

## 4. Out of Scope (decided)

| Item | Decision | Justification |
|---|---|---|
| Screen reader / TTS for gameplay | **Out.** Not provided, ever, for the in-field game | The game is a 60 Hz twitch shooter; narration cannot keep pace with bullets, and information is on a pixel canvas. Honest limit, stated on the store page |
| Screen reader / TTS for menus | **Out at Vertical Slice; reconsider at Target** (Accessibility OQ8) | Menus have a defined focus order and text, so platform narration (Web ARIA, iOS VoiceOver, Switch) is feasible later. Cost: Godot 4.7 platform hooks are unverified. Not a Basic or Intermediate GAG item for this genre |
| One-switch play | **Out** | Moving through a curtain needs continuous analogue-style input. Closest support: one-handed presets, Fire toggle, Tap Assist, adaptive controllers, game speed 50 % |
| Difficulty selector (Easy/Normal/Hard) | **Out** | Pillar Every Hit Counts and Readable Chaos: one fixed ruleset so boards compare. Game speed is the only assist |
| Damage reduction, extra lives, invincibility, enemy slow-down | **Out** | Rule 26: they break Every Hit Counts more than they help |
| Assist runs on ranked boards | **Out.** Any assist latches PRACTICE for the run: no board entry, no personal best, no `one_credit_clear`, no upload | Rule 23. The score is still shown; the player is never refused a feature |
| Screen-wide colour-blind filter | **Out** | Would recolour enemy bullets (Rule 5, 17); palette swap plus mandatory patterns instead |
| Thicker bullet outline, bullet glow off, bullet recolour | **Out** | Changes drawn size against true hit radius (Rule 5) |
| HUD scale 100/125/150 | **Out** | Rule 20: `play_top` 48 / 72 fixed; replaced by text size, hud contrast, near-plane bar, Pause status panel |
| Caption strip for sounds | **Out** | No HUD space, art bible 7.7; visual twins replace it |
| Auto-fire turbo beyond Tap Assist | **Out** | Would cross the kit shot-rate cap |
| Touch layout drag-and-place editor | **Out** | Touch OQ5 |
| Touch co-op on one phone | **Out** | Touch Rule 1: co-op on phones is for Bluetooth pads |
| Voice control, eye tracking | **Out** | No engine support planned |
| Dyslexia font, custom fonts | **Out** | One pixel font per script; Bengali shaping already costly (Localization) |

---

## 5. Per-Screen Requirements

Applies to every screen, then screen-specific rows. "Screen" links point to `design/ux/`; a spec marked *(not yet written)* inherits this table until it exists.

### 5.1 All screens

| Requirement | Test |
|---|---|
| Every action reachable by keyboard only and by gamepad only; pointer optional | T-01 |
| Visible focus: 3 px Cream border plus arrow, never colour alone | T-06 |
| Text at or above 12 px Latin / 17 px Bengali; reflows at all four text steps; lists scroll; no clipping | T-04 |
| Confirms of destructive actions honour `confirm_style` and `confirm_hold` | T-03 |
| No timer without an option (section 3.1); safety timer for Display TATE (10 s, defaults to Cancel) is allowed | T-05 |
| Reduce motion = cut transitions; reduce pulsing = steady cues; no flash in UI | T-07 |
| Both languages: dual-script only on the surfaces in arcade-ui-style 2.1 | T-04 |

### 5.2 Screen table

| Screen | Spec | Screen-specific requirements |
|---|---|---|
| Web gate, first-run plate | [main-menu.md](ux/main-menu.md) (Web gate); plate in [settings.md](ux/settings.md) | Bilingual line (language may be wrong); first-run plate appears once before Title, one press to skip, default focus **Keep as is**, second item **Reduce flashing and effects** applies the Calm preset in one commit; a gamepad press must unlock audio (Menus OQ6, Web spike) |
| Title | [main-menu.md](ux/main-menu.md) | START GAME is default focus; language chip reachable by D-pad; attract wake input is consumed; Flight School item shows text plus star for NEW (not colour) |
| Lobby | [lobby.md](ux/lobby.md) | Slot is a ring pattern + pips + "P{n}", never colour alone; join plate pulse becomes steady under reduce pulsing; `untimed_menus` disables idle close; per-slot pad map applies on join |
| Gameplay HUD | [hud.md](ux/hud.md); GDD [hud.md](gdd/hud.md) | Strip does not scale; numerals on fixed grid; PRACTICE tile (12x12) in strip; chain expiry has an end-cap shape; continue prompt honours `continue_timer`; edge steps never change brightness faster than 1 Hz under reduce flashing |
| Pause | [pause.md](ux/pause.md) | Opens within 1 tick; shows who paused; status panel at the text step (score, chain, lives, bombs, drones per player); PRACTICE word + icon; Settings reachable; "applies next stage" note for STAGE options |
| Stage tally | [stage-tally.md](ux/stage-tally.md) | Always skippable; auto-advance off waits for Confirm per column; NEW BEST pulse off under reduce flashing; missed bonuses shown with a cross glyph, not only dimmed; grid fixed for 4P, prompt line scales |
| Results and name entry | [results-name-entry.md](ux/results-name-entry.md) | Name wheel usable with D-pad and keyboard; 30 s limit off under `untimed_menus`; assisted run skips entry and shows "PRACTICE / not ranked"; pad disconnect holds the entry open when untimed, on a controller-lost plate with a **DROP** action (P31) *(confirmed 2026-11-03, wave 5 batch 2)*. A run that scored but did not place in the top `board_size` asks for **no initials** and shows "Not in top {n}" (Save Rule 5) |
| High scores | [high-scores.md](ux/high-scores.md) | Rows scale with text step and scroll; rank by number, not colour; assisted runs never listed |
| Settings, Accessibility, Controls | [settings.md](ux/settings.md) — **spec exists and is reviewed (2026-11-03)** | Groups in this order: Calm preset, Visual, Colour and contrast, Text, Controls, Assists, Audio, Timing, Reset; live preview plate (ring, four slot colours with patterns, ally shot at the chosen opacity, no bullets); from step 2 the label stacks above the control; reset is hold-to-confirm; per-action and per-class reset; input test screen; "will not be saved" note when Save is absent. The Accessibility list's **group jump must not use a shoulder bound to Fire / Drone / Bomb** and is never the only path to a row (Accessibility Rule 21a, Input Rule 24c) *(added 2026-11-03, wave 5 batch 2)* |
| Flight School | [flight-school.md](ux/flight-school.md); GDD [tutorial.md](gdd/tutorial.md) | Drill cards in text (not voice); no failure state; Pause has Restart drill and Skip drill; hints toggle in Settings; DONE stamp has text, not only colour; unranked by design |
| Credits | [credits.md](ux/credits.md) | Scrollable by input at the user's pace; scroll off under reduce motion |

---

## 6. Gaps Found in the GDDs

| # | Gap | Why it matters | Owner |
|---|---|---|---|
| G1 | **No magnification or field zoom for low vision on phones.** HUD scale was rejected and the field is a fixed 360x640 canvas; 4P columns are 90 px | The only large-print help is text size, hud contrast, near-plane bar and window scaling. A low-vision phone player has no field-level remedy | UX + art-director |
| G2 | **CVD numbers are unverified** (Machado matrices from memory; CIE76 vs CIEDE2000 undecided; P4 vs Needle dE 22.4) | The palette claim in the registry may not hold on real sprites | accessibility-specialist, art-director |
| G3 | **Photosensitive default**: the single white Critical Break frame is on by default and the first-run prompt defaults to Keep as is; the Calm preset also leaves `era_transition_short` off | A user who dismisses the prompt can see the one flash unwarned in-game | game-designer decision |
| G4 | ~~Missing UX specs: Settings/Accessibility, Controls, first-run plate, HUD, Results, High scores, Flight School~~ **Largely closed 2026-11-03 (wave 5 batch 2):** `design/ux/settings.md` (Settings, Accessibility, Controls, Input test and the first-run plate), `hud.md`, `results-name-entry.md`, `high-scores.md` and `flight-school.md` all exist and have been through `/ux-review`. What remains is the open questions inside each of those specs, not a missing spec | ux-designer |
| G5 | Mono downmix method unverified in Godot 4.7 (Audio OQ3) and touch haptics on iOS and Web unverified | Two options may not work on shipped platforms | godot-specialist |
| G6 | Bengali strings for `opt.*` and the first-run plate are draft; conjunct fit at text step 3 untested | A Bengali player at step 3 may see clipped diacritics | localization lead |
| G7 | Switch and touch: no spec for Switch handheld text legibility; PRACTICE tile has no free 12x12 rect confirmed in the three HUD layouts | Console cert and HUD lint | HUD UX |
| G8 | Steady 65 % invulnerability may not read as "I am invulnerable" (OQ4) | Reduce flashing could cost survival information | Playtest |

---

## 7. Test Plan

Manual tests run on REF-WEB, one PC build with pad and keyboard, and one phone. A pass is recorded in `production/qa/` per release candidate. Unit tests exist in the accessibility GDD (AC-01 to AC-50) and are not repeated here.

| ID | Test | Method | Maps to | Pass |
|---|---|---|---|---|
| T-01 | Input coverage | Complete first-run plate, Title, Lobby, 1 stage, Pause, Settings, Controls, Tally, Results with keyboard only, then pad only, then touch (solo) | AC-46, AC-47 | No mouse needed; no stuck focus |
| T-02 | One-handed run | Keyboard-left, keyboard-right, pad one-hand and touch one-hand presets clear stage 1 on the Lancer | AC-47 | Run completes; no two buttons on one tick |
| T-03 | Confirm styles | HOLD at 40 / 60 / 90 ticks and DOUBLE_TAP on Quit, Reset, Clear | AC-33 | Matches ticks |
| T-04 | Text and language | Steps 0-3 in English and Bengali on Title, Lobby, Pause, Settings, Tally, Board at 1x and 4x | AC-27 | No clip; diacritics intact; scrolls; focus in view |
| T-05 | Timers | `untimed_menus` on/off for name entry and Lobby; `continue_timer` all values; pad unplug at name entry | AC-34, AC-35 | Matches table; with `untimed_menus` on, a pad unplugged at name entry **holds** that slot open on a controller-lost plate offering **DROP**, and the slot is only finished when the pad returns or a player drops it *(added 2026-11-03, wave 5 batch 2; Menus Rule 36 edge case)* |
| T-06 | CVD simulation | Debug overlay (protan, deutan, tritan, gray) at 4P in HUD, Lobby, Pause, Tally; tell the four slots apart by ring and pips | AC-23 | All four distinct at 1x |
| T-07 | Reduce flashing/pulsing/motion | Capture 10 s across a Critical Break, respawn, hit tint, Tally; compare mean luma between frames | AC-08 to AC-13 | No full white frame; change at most 8 % per frame |
| T-08 | Grayscale gate | Each era with FULL, DIMMED, PLAIN backgrounds at 4P density | AC-15 | Every bullet readable |
| T-09 | Sound off | Mute everything; play a full stage and boss; note every information loss | AC-39, AC-40 | Each cue has a visible twin |
| T-10 | Assist latch | Set game speed to 90 mid-run, restore 100, finish; check Pause, Tally, Results, board | AC-38 | PRACTICE shown; not ranked |
| T-11 | Hardware | Xbox Adaptive Controller, a one-handed pad grip, a Switch Joy-Con pair | OQ7 | Playable with presets |
| T-12 | Flash analysis | Run captured footage of Critical Break (both settings), era shift, Warning through a photosensitive-epilepsy analysis tool (tool to be chosen) | Rule 8 | Below general flash and red flash thresholds with Reduce flashing; single frame documented without |
| T-13 | Screen-reader smoke (Target) | Menus only, per platform, if the stance changes | OQ8 | Documented result either way |
| T-14 | Tester panel | At least 3 external testers with different needs (photosensitivity, colour vision, one-handed or motor) on Vertical Slice | OQ4 | Findings logged, blockers fixed |
| T-15 | Platform checklists | Steam/Web/iOS/Android/Switch store accessibility fields and Xbox-style topics filled from section 3 | Rule 36 | Matches shipped options |

---

## 8. Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Should field-level magnification (a zoom that keeps the true hitbox and a larger window crop) be investigated for phones? It would change what the player sees, so ranked comparability and `play_top` need a ruling | game-designer, art-director | Target |
| 2 | Should the first-run prompt default focus move to **Reduce flashing and effects** for Web builds, where the player arrives cold? Proposal only; the GDD says Keep as is | game-designer | Vertical Slice |
| 3 | Add a store-page / Web page line about the single Critical Break flash and the Reduce flashing option? | producer | Release |
| 4 | Pick the flash-analysis tool for T-12 | QA | Vertical Slice |
| 5 | Commit to a platform narration stance for menus (Web ARIA, VoiceOver, Switch) at Target, or declare final | UX, platform | Target |
| 6 | Add an accessibility statement text (what the game supports and does not) to Credits or Settings? | UX, producer | Release |
| 7 | Do store questionnaires (Apple, Google, Steam, Nintendo) need a formal declaration of colour-only or flash content? | producer | Release |
| 8 | All Accessibility GDD open questions 1-15 remain open with their owners until closed there | see GDD | per GDD |

---

## 9. Acceptance Criteria for This Document

- A reviewer can find the committed tier (Comprehensive) and what is out of scope in under one minute.
- Every row in section 3 cites a GDD rule or is marked Gap.
- Every screen in the journey (`design/player-journey.md`) appears in section 5.2.
- Each test T-01 to T-15 states a method and a pass condition.
- When a GDD changes, the GDD wins and this file is updated.
