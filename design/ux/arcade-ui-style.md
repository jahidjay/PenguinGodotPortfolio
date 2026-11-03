# Arcade UI Style Guide (UX layer)

> **Status**: Approved (2026-11-03) — previously: Draft (auto-approved, 2026-11-03); reviewed with `/ux-review` 2026-11-03, blocking issues fixed
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Template**: UX style guide (supplements the art bible section 7, does not replace it)
> **Sources**: `design/art/art-bible.md` (sections 4.1, 4.4, 4.7, 7.2-7.10, 8.1.1), `design/ux/interaction-patterns.md`, `design/accessibility-requirements.md`, `design/gdd/accessibility-options.md` (Rules 12, 17, 19; F1, F5, F6), `design/gdd/localization.md` (Rules 15-18, 25; text-size table), `design/gdd/hud.md`, `design/gdd/menus-title-plane-select.md`, `design/gdd/display-scaler-and-bezel.md`
> **Decided by user 2026-11-03:** arcade bullet-hell feel in the DoDonPachi tradition, with **original** art, names and layouts; menus stay **single-language** (language chip), dual-script only where the GDDs already require it.
>
> **Revision 2026-11-03 (final doc closeout)**: section 5 cue ids rewritten to the canonical **`sfx_ui_*`** form (consistency-report C1); six Menus-only cues added to the standard; the stale "missing IDs are tracked in the consistency report" closing line replaced with the assigned ids.
> **Revision 2026-11-03 (art-director decisions)**: rule 3 and the palette row now define red text as the art bible's **Alarm Flare `#F2494D`** (4.76:1 on Char); `#E03A3E` stays the plate-edge and glyph-fill red; Open Question 2 closed; conformance checklist colour-role item updated.
> **Revision 2026-11-03 (UX amendments wave 5)**: Alarm Red is now barred as a **text fill** (3.95:1) and restricted to plate edges and glyph fills, with failure words in Cream (rule 3, palette row, conformance checklist); the ownership of the animation and sound **standards** tables is stated explicitly against `design/gdd/audio.md` (sound ids) and `interaction-patterns.md` (cites per pattern); Open Question 2 is confirmed as an art-director decision.
> Revised 2026-11-03 after /ux-review: added header Sources, ownership table, colour roles with contrast ratios, type ramp, spacing/safe areas, panel treatment, accessibility degradation, conformance checklist and open questions; fixed the Lobby pulse depth (art bible 7.7), the banner timing row, the hero-scale rule (art bible 7.7), the headroom rule (art bible 7.5), slot colour sources and a stale proposal.

Every spec in `design/ux/` follows this file. Where it and a GDD or the art bible disagree, the GDD/art bible wins and this file is fixed.

### Ownership: what this file owns and what it only cites

| Topic | Owner | This file's role |
|---|---|---|
| Canvas 360x640, bezel, scaling, OS safe area | Art bible 8.1.1, Display GDD | Cites only; adds in-canvas margins (3.3) |
| Palette hexes, 1 px text outline, chamfered plates, HUD strip 48/72 px, tier definitions S/M/L/XL, D12/D10 | Art bible 4, 7.2, 7.5 | Maps hexes to **UI roles** and records contrast ratios (3.1); never redefines a hex |
| Component states, focus, Back, hold-to-confirm, toasts | `interaction-patterns.md` P01-P31 | Cites by P-number; adds none |
| Animation **standards** (section 4) and sound cue **standards** (section 5) | **This file** | **Canonical copy.** Confirmed 2026-11-03 (wave 5): `interaction-patterns.md` **cites** section 4 and section 5 per pattern and restates neither; `design/gdd/audio.md` keeps ownership of the sound **ids** themselves (this file maps ids to UI uses, it does not mint them) |
| Bengali/Latin handling, which surfaces are dual-script (section 2) | **This file** | Canonical copy |
| Screen layouts, per-screen strings and char limits | The individual `design/ux/*.md` specs | Cites only |

---

## 1. What "arcade feel" means for MorutJan

The game borrows the *conventions* of late-90s arcade bullet-hell cabinets, which players of the genre read instantly. It does **not** copy any existing game's logo, fonts, screen layouts, wording, characters or art.

| Convention | MorutJan version | Where specified |
|---|---|---|
| Portrait cabinet screen with art beside it | 360x640 canvas (TATE-style), bezel art fills the rest of the window | Display scaler GDD, art bible 8.1.1 |
| Score always on screen, big tabular numerals | 9-digit score per player in the top strip, right-aligned, no leading zeros | `hud.md` GDD Rules 12-16 |
| Combo counter as the hero number | **CHAIN** plate: big Gold numerals + draining window bar; ghost of the dropped chain | art bible 7.3, `hud.md` Rule 17 |
| Bomb and life stock as icons | 14x14 icons (1P), icon + count (2P), 11x11 + count (3-4P) | `hud.md` Rules 19-22 |
| "Press Start" on empty player slots | **In play (HUD):** icon-only join plate (16x16 START glyph + the slot's pips), steady, no text; 1P shows one plate for the next free slot, 2P shows none (no room). **In the Lobby:** text plate "Press START to join" in every empty column | HUD GDD Rule 23, Menus Rule 18, pattern P09 |
| Boss WARNING screen | Amber stripes + bilingual plate, siren, 2.5 s | art bible 7.4 |
| Big boss HP bar | Strip row, Alarm Red, % number backup | art bible 7.4 |
| Stage clear roll-up | Stage-end tally, rows tick in and count up, skippable | `stage-tally.md` |
| Continue countdown | Large numerals counting down in the player's column | `hud.md`, Session GDD |
| 3-letter initials on a name wheel | Name entry, A-Z 0-9 - . | `results-name-entry.md` |
| Attract loop | Title -> era palettes cycle (MVP); high-score page in the loop is a proposal (section 6) | `main-menu.md` |
| One bright moment | The single Critical Break white frame (removable) | art bible 7.3 |

**Things deliberately not borrowed:** coin/credit language ("INSERT COIN", "CREDIT 00"), rank/difficulty that rises secretly, medal pick-up chains, scrolling score tickers in the field, any flashing text. MorutJan is a home game: "PRESS START", free continues within Session rules, and no screen flashes beyond the one Critical Break frame.

### 1.1 The intent as rules a designer can check

| # | Intent | Measurable form |
|---|---|---|
| A1 | Chrome recedes, bullets lead (art bible 3.6) | Plate fill `#1E1B18` (luma about 28) and plate edge `#5A5148` (luma about 83) are the only large UI areas; both stay at luma 90 or below, far under bullet cores (231-255). Only text, numerals and glyphs inside a plate may exceed luma 150 |
| A2 | Score and chain are the hero numbers | Ember Gold appears only on score, chain, tally hero numbers and the S8 points tier (3.1). In a greyscale screenshot, Gold numerals are the brightest filled text on the HUD after Cream |
| A3 | Cabinet-label feel | Plates are rectilinear with chamfered corners, one text weight, no gradients inside plates, no soft shadow (3.4) |
| A4 | Home game, not a coin-op | None of the strings in the "not borrowed" list exist in any string table |
| A5 | One bright moment | Across any 10 s UI capture, the only frame with mean luma change above 8% is the Critical Break frame (accessibility T-07) |

---

## 2. Bilingual rules (single-language menus, user decision 2026-11-03)

### 2.1 Which surfaces show both scripts

| Surface | Script | Order |
|---|---|---|
| Title logo | Both, equal weight | Bengali above English |
| Banners: WARNING, STAGE n, ALL CLEAR, CRITICAL BREAK, BOSS WITHDREW, boss name plate, era card | Both | Bengali above English |
| Tally row labels and header | Both, stacked in a 31 px block (17 px Bengali + 2 px gap + 12 px Latin cap height) | Bengali above English |
| Web gate line, first-run photosensitivity plate | Both (language may still be a wrong guess) | Bengali above English |
| TATE confirm title ("Keep this rotation?") | Both (Display GDD UI Requirements; a rotated screen is disorienting) | Bengali above English |
| Language chips | Each in its own script, never translated; size is owned by `main-menu.md` (56x20 each) | `বাংলা` left, `English` right |
| **Everything else** (menus, HUD labels, prompts, toasts, settings, results, high scores, credits headings) | **Chosen language only** | — |

A new dual-script surface is added only by amending this table. On every dual-script surface both scripts share one colour, one weight and the 1 px outline (art bible 7.5, "equal visual weight").

### 2.2 Design changes for Bengali (apply to every text element)

Sizes in this file follow art bible 7.5: the **Latin figure is cap height**, the **Bengali figure is font size**. Tier definitions are in 3.2.

| Rule | Why |
|---|---|
| Minimum size at step 0: 17 px Bengali vs 12 px Latin cap height at the same tier. Only numeral tiers D12/D10 (digits only) may be smaller, pending the font spike (art bible 7.5 addition, HUD OQ 1) | Bengali conjuncts and vowel signs are unreadable at Latin sizes |
| Reserve **+40% width** and **+25% height** for any single-language label | Bengali strings are usually wider and taller (matra, descending vowel signs) |
| Line pitch: Bengali size x 1.4 (17 px -> 24 px, equal to art bible "size + 7"), Latin x 1.2; reserve **4 px** above the matra line (art bible 7.5). Clip floor: never clip the top 2 px or the bottom 3 px of a Bengali line box. Reserved headroom can be used by neighbours; clipped pixels cannot | Avoid cut-off diacritics; reconciles the 4 px reservation (art bible) with the 2/3 px clip floors quoted in `hud.md` |
| **No all-caps contrast for Bengali.** Latin uses caps for menu items ("START GAME"); Bengali has no case, so emphasis comes from size tier, plate and Gold colour, never from case | Keep both languages equally emphatic |
| No letter-spacing (tracking) on Bengali | It breaks the connecting headstroke (matra) |
| No faux bold, no italic, no skew on either script | Pixel font has one weight; skewed Bengali becomes unreadable |
| Bengali digits ০-৯ when Bengali is chosen, on the **same fixed digit grid** as 0-9; grouping is Western 3-digit (`৯৯৯,৯৯৯,৯৯৯`) | Localization Rules 17-18; numbers never move when language changes |
| "P1"-"P4", initials and key names (Enter, Esc) stay Latin in both languages | Localization / Save rules |
| Years print without grouping (`১৯৪১`) | Localization Rule 17a |
| Text is wrapped by words, never mid-conjunct; max 2 lines for menu labels (3 in Bengali) | Localization shaping rules |
| Conjunct gate: "ক্ষ", "শ্রী", "ঙ্গ", "ত্র" render legibly at 17 px with the outline at 1x; if not, raise the Bengali size to 18-20 px (never drop the outline) | Art bible 7.5 |
| All Bengali strings marked draft until native review | Menus Open Question 7 |

### 2.3 Language switching

- Title chip and Settings > Language swap all single-language text in one frame; no layout moves (measured layout reserves the larger width).
- Dual-script surfaces never change when the language changes, except digits.

---

## 3. Visual tokens and layout (from the art bible; cited, not redefined)

### 3.1 Colour roles and contrast

Ratios are WCAG relative-luminance contrast against Cabinet Char `#1E1B18` (luminance about 0.011), computed in the 2026-11-03 review (rounded; re-measure in the font spike with the real renderer).

| Role | Token | Value | Contrast on Char | Use |
|---|---|---|---|---|
| Plate fill | Cabinet Char | `#1E1B18` | — | Every UI plate; opaque |
| Primary text, focus border | Cream | `#F4EBD6` | 14.4:1 | All text, 3 px focus border, HIGH plate edge |
| Text outline | Outline | `#14110E` | Cream on outline 15.8:1 | 1 px on all 8 sides of every text and numeral |
| Hero numbers | Ember Gold | `#FFC93C` | 11.2:1 | Score, chain, tally hero, S8 points only |
| Bar track under Gold | — | `#3A2A14` | Gold on track about 9:1 | Chain bar track (art bible 7.3) |
| Alert | Amber | `#FFB000` | 9.4:1 | WARNING stripes and alert only |
| Failure / critical | Alarm Red | `#E03A3E` | **3.95:1** | Boss bar fill, chain expiry end-cap, **plate edge and glyph fill** for failure. **Never a text fill** (rule 3) |
| Failure / danger words | Alarm Flare | `#F2494D` | **4.76:1** (computed) | **Text only**: the single headline status line of a failure or danger state, with the 1 px outline. Cream under `hud_contrast` HIGH (rule 3) |
| Plate edge (STANDARD) | Plate edge | `#5A5148` | 2.2:1 | Plate border, ghost digits, unlit lamps, disabled items |
| Dim text (HIGH contrast) | — | `#A89E8A` | 6.5:1 | Replaces `#5A5148` for ghost digits and dim text when `hud_contrast` is HIGH |
| Tracer Orange | — | `#FF8A1F` | n/a | Kit bar, bomb tile (art bible 4.1) |

**Rules**
1. Menu and tally body text is Cream on Char at 14.4:1, which meets the 7:1 menu requirement (art bible 7.8, accessibility 3.2).
2. `#5A5148` (2.2:1) never carries information on its own. It is allowed only for (a) plate edges and decoration, (b) disabled items, (c) ghost digits and unlit lamps whose meaning is repeated elsewhere (the chain ghost is repeated in the tally max chain). Any other secondary text is Cream; hierarchy comes from tier and position, not from tone.
3. **Two reds, two jobs.** `#E03A3E` (Alarm Red, 3.95:1) is **never a text fill**; it is the bar fill, plate edge, end-cap and glyph fill. Red *words* use the art bible's **Alarm Flare `#F2494D`** (4.1; 4.76:1 on Char, computed). Rules for Flare: (a) text only, with the 1 px outline, tier S or larger, on Char or `#2A0F12`; (b) it colours the **one headline status line** of a failure or danger state - the explanatory sentence stays **Cream** (14.4:1); (c) the **Alarm Red plate edge and/or error glyph fill** is still required beside it, so a failure is words + glyph/edge, never colour alone and never a glyph alone; (d) under `hud_contrast` HIGH the headline renders **Cream** (the edge and glyph stay Alarm Red); (e) never in the HUD strip, never in a slot column or next to a P1 pip or ring, never in the play field; (f) never the only carrier of a message - the same words appear in the Cream sentence (this is what lets a 4.76:1 label sit on screens that otherwise hold the 7:1 menu line). A screen that does not need a red headline simply stays Cream. *(Decided 2026-11-03: wave 5 barred red text outright; the art-director then authored Alarm Flare, closing Open Question 2. Binds `settings.md`, `high-scores.md` and `interaction-patterns.md`, which may now use Flare for the headline line but need no change if they stay Cream.)*
4. Era tint (20% of the era accent) is applied to **plate edges only**, never to text, digits, bar fills, Gold, Alarm Red, Tracer Orange or slot colours (art bible 7.8). It is not applied while `hud_contrast` is HIGH (edges are Cream).
5. Menus never use Void Indigo or Ink fills; no round orbs, rings or needle shapes as UI icons (those read as bullets).

**Slot colours** (art bible 4.4; palette option `access.player_palette`)

| Slot | DEFAULT | LUMA_SPREAD | Ring pattern | Pips |
|---|---|---|---|---|
| P1 | `#FF5A36` | `#FF5A36` | Solid | 1 |
| P2 | `#F5E02E` | `#FFF04A` | Dashed | 2 |
| P3 | `#2FD27A` | `#2FD27A` | Dotted | 3 |
| P4 | `#FF8AD8` | `#FFB4EA` | Double | 4 |

LUMA_SPREAD luma 122.5 / 231.2 / 169.0 / 199.8, minimum gap 30.9 (Accessibility F5). DEFAULT has P3 and P4 at equal luma (169.0 / 168.5), so ring pattern and pips are mandatory and not switchable. Slot colour is always paired with ring pattern and pips (P08); the text label "P{n}" is added **wherever a text label fits** (Lobby, Pause, Results, High scores). The HUD column has no "P{n}" text by design (HUD Rule 8; see Open Question 5).

### 3.2 Type ramp

Tier definitions belong to art bible 7.5; this table adds the step values from Localization (Accessibility F1) and the variants in use. Text size applies to **S and M only**; L and XL are identity at every step.

| Tier | Latin cap height, steps 0-3 | Bengali size, steps 0-3 | Colour | Used for |
|---|---|---|---|---|
| S | 12 / 15 / 18 / 24 px | 17 / 21 / 25 / 33 px | Cream | Labels, menu items, counts, `%`, prompts |
| M | 12 / 15 / 18 / 24 px | 17 / 21 / 25 / 33 px | Gold | Score |
| L | 16-24 px numerals | Bengali digits at the same height | Gold | Chain counter, tally hero |
| XL | 24 px | 34 px | Per surface | Banners, titles |
| D12 / D10 | digit 12 px (cell 8, sep 3) / 10 px (cell 6, sep 2) | Bengali digits at the same height | Cream or Gold | Boss row, 3-4P strip numerals (HUD-owned) |

Font variants in use (art bible 7.5; the face is not yet chosen, see Open Question 7): **one regular weight** per script (Latin pixel face, Bengali face), Latin and Bengali digit sets on one fixed grid (`cell_w = ceil(0.6 x digit height)`, separator `round(0.4 x cell)`). No italic, bold, condensed or decorative variants. Rendered width includes the 1 px outline (+2 px).

HUD numerals ignore the text-size step (fixed grid); banner words use `font_size_px(tier, step)` at identity; banners are fixed plates, never scaled.

### 3.3 Spacing, grid and safe areas at 360x640

- **Grid unit 4 px.** Plate widths and heights, row pitch and gaps are multiples of 4 unless inherited from the art bible or a GDD (14x14 icons, 31 px tally block, 84x26 chain plate). Existing specs already conform: menu row 32 + 4 gap = 36 pitch, menu plate 216, modal plate 296, toast strip 328x24, strip 48 / 72.
- **All positions and sizes are whole canvas pixels**; no filtered scaling (art bible 7.8). Checked at x1, x2, x3 and x4.
- **In-canvas margins** (derived from the existing plate widths): any text or interactive plate outside the HUD strip keeps at least **8 px** from every canvas edge; plates and toasts at least **16 px** from the left and right edges (the 328 px toast is the widest allowed plate). Full-bleed backdrops, the Char wipe and bezel art are exempt. The HUD strip uses the GDD rects.
- **Reserved bands (menu screens):** toast y 560-584; prompt bar y 600-640 (glyph + verb pairs, `main-menu.md`). A screen that cannot fit above y 600 scrolls or reduces gap; it never overlaps the prompt bar.
- **Safe areas:** the canvas is always 360x640 and the OS safe area is handled by the Display scaler (art bible 8.1.1: canvas inside the safe area, only bezel art under a notch). This guide therefore adds **no extra top or bottom inset** inside the canvas. The touch button strip is below the canvas and never over it.
- **Gameplay screens:** nothing but the HUD strip, transient banners and the stopped-game panels (Pause, Disconnect, Coach card) may be drawn over the field; those panels only while the game is stopped (art bible 7.2 addition).
- **Text over backdrops:** text that sits directly on a backdrop (logo, hi-score line, banners) carries the 1 px outline and is Cream or Gold; everything else sits on a plate.

### 3.4 Panels, borders and shadows

- **Panel:** opaque Cabinet Char, chamfered rectilinear corners (chamfer size per art bible 3.5, identical on every plate), 1 px edge `#5A5148` (Cream under HIGH). No gradient, texture, blur or glow inside a plate.
- **Shadow / depth:** no soft or drop shadow. Separation comes from the plate edge and the text outline. A hard offset plate shadow is not part of the system (Open Question 4).
- **Scrim behind modals:** per `settings.md` (list dimmed to the plate-edge colour, no tint over the HUD strip); not redefined here.
- **Focus:** 3 px Cream border plus an arrow glyph offset 2-3 px (art bible 7.8, P02); never hue alone.
- **Tabs / chips / selected state:** fill plus underline or text, never colour alone (P03, P16, P23).
- Touch button plates follow the same grammar (art bible, touch addition) and live in the strip below the canvas.

---

## 4. Animation standards (all specs)

This is the canonical table; `interaction-patterns.md` summarises it. All timings are integer ticks at 60 Hz. Anything not listed is not allowed in UI.

| Motion | Spec | Reduce motion | Reduce pulsing / flashing |
|---|---|---|---|
| Screen change | 4-step Char wipe, 12 frames, no white | Cut | — |
| Panel / toast in-out | 8 frames, stepped 3-4 positions | Appear in place | — |
| Row reveal (tally, results) | Slide 4 px up + fade, 6 frames | Appear in place | — |
| Count-up | Integer steps to the exact value over 30 ticks (45 for hero) | Snap to final | — |
| Stamp (READY, NEW BEST, 1UP) | Drop/pop in 4 steps over 4-8 frames | Appear in place | NEW BEST pulse removed |
| Focus | Instant move; optional pulse with opacity swing of at most 40 points (never below 60%), at most 2 Hz, one element | — | Pulse off |
| Lobby "Press START to join" plate | Opacity 100% <-> 60% (a 40-point swing, art bible 7.7), 1 Hz, stepped (*proposal; Menus GDD does not specify a pulse*) | — | Steady 100% |
| HUD join plate | Steady, never pulses (HUD Rule 23) | — | — |
| Hold-to-confirm bar | 4 stepped segments, Gold on completion | Unchanged (functional) | Unchanged |
| Banners | Timings belong to the owning spec: Critical Break 6 / 30 / 6 ticks (in / hold / out); WARNING 150 ticks, out 8 frames (HUD); other banners in 10 / out 8 frames (art bible 7.7). Stepped ease only | Cut in/out | Text pulse steady |
| WARNING text pulse | Opacity 100% <-> 60%, at most 1.5 Hz (art bible 7.4) | — | Steady |
| Easing | Stepped (3-4 positions). No tween blur, no scale, rotation or sub-pixel tween; digits never enlarge (art bible 7.3, 7.7) | — | — |
| Flash | None in UI. The only flash in the game is Critical Break's single frame (VFX) | — | Replaced by particles |

Rule: the tally "hero scale +1 step" in `stage-tally.md` has no definition here and conflicts with the no-scale rule; see Cross-document amendments in the review report.

---

## 5. Sound standards (UI bus)

**Ownership (confirmed 2026-11-03, wave 5):** this table is the **canonical UI sound standard** - which cue plays for which interaction across screens. `design/gdd/audio.md` owns the cue **ids** and their actual sound design, bus and mix; this file never mints an id. `interaction-patterns.md` cites this section per pattern instead of restating it.

**Id form (decided 2026-11-03, final doc closeout, consistency-report C1):** every cue id is written in the **`sfx_ui_*`** form, exactly as `design/gdd/audio.md` spells it. The unprefixed `ui_*` form this table used until now is retired, as is the dotted `ui.*` form the Menus GDD used; one scheme everywhere.

| Cue id | Used for |
|---|---|
| `sfx_ui_nav_tick` | Focus move, cursor move, name wheel step (`sfx_ui_name_tick`) |
| `sfx_ui_confirm` | Activate item, lock plane |
| `sfx_ui_cancel` | Back / unlock |
| `sfx_ui_deny` | Refused action (game full, reserved key, locked item) |
| `sfx_ui_join_chime` | Slot joins |
| `sfx_ui_pad_lost` | Controller disconnected |
| `sfx_ui_pause_in` / `sfx_ui_pause_out` | Pause open / resume beat end |
| `sfx_ui_slider_preview` | Volume stepper preview |
| `sfx_ui_tally_row` / `sfx_ui_tally_hero` | Tally row in / hero count end |
| `sfx_ui_new_best` | NEW BEST stamp, new board entry |
| `sfx_ui_save_ok` / `sfx_ui_save_error` | Save notices |
| `sfx_ui_warning_siren_loop` | WARNING banner |
| `sfx_ui_upload_tick` / `sfx_ui_upload_ok` / `sfx_ui_upload_error` | Online upload (Stretch) |
| `sfx_ui_lock` / `sfx_ui_unlock` | Lobby slot Locked / unlocked (Menus 22) |
| `sfx_ui_start_run` | Run commit from the Lobby (Menus 22) |
| `sfx_ui_hold_tick` / `sfx_ui_hold_done` | Each `HOLD_BUTTON` segment / hold completion (P12) |
| `sfx_ui_toggle_lang` | Language chip toggled |

Rules: UI sounds never use the 8-voice bullet pool; no voice-over; no rumble on menus. Every sound cue has a visual twin (accessibility). The tutorial, Sentry/Breaker, bomb, online and Boss Rush ids were assigned in `design/gdd/audio.md` on 2026-11-03 (`sfx_tut_drill_done`, `sfx_tut_coach_open`, `sfx_kit_sentry_plant` … `sfx_kit_stock_ready`, `sfx_bomb_bastion_loop`, `sfx_bomb_backlash_sweep`, `sfx_ui_upload_*`, `sfx_rush_refit`), pending audio-director confirmation of the sound design; touch has no cue of its own (Touch controls owns its feedback). Every cue id named in this file has a row in that GDD's Sound Event List.

---

## 6. Proposals (need GDD amendments before they are binding)

1. **Attract loop with a score page.** Title attract (after 30 s) alternates: era palette backdrop with logo (20 s) -> top-5 board for the most-played plane (10 s) -> repeat. Classic arcade attract, no gameplay demo needed. Amends Menus Rule 11.
2. **Prompt bar always shows the device's glyphs**, including on attract (bottom line "PRESS START", in the chosen language).
3. ~~Era-tinted plates in game~~ **Adopted (art bible 7.8 and `hud.md`):** the 1 px plate edge carries the 20% era tint on HUD and tally plates. Rules in 3.1 item 4.

---

## 7. Degradation under the COMPREHENSIVE accessibility options

| Option | Effect on this guide's rules |
|---|---|
| `access.hud_contrast` HIGH | Plate edges `#5A5148` -> Cream (14.4:1); ghost digits and dim text `#5A5148` (2.2:1) -> `#A89E8A` (6.5:1); era tint on edges off; outline and ring patterns unchanged. Applies to HUD and to menu/Settings plates |
| `access.text_size` 0-3 | S and M tiers only, using the 3.2 steps. From step 2 Settings rows stack (label above control) and lists scroll; focus stays in view; no label is truncated; HUD numerals, banners and L/XL do not change. The +40% / +25% reserve is measured at the chosen step |
| `access.player_palette` LUMA_SPREAD | Changes P2 and P4 hexes (3.1); ring patterns, pips and "P{n}" are unchanged; applies at the next stage and immediately in menus and Lobby |
| `access.reduce_motion` | Column "Reduce motion" in section 4: wipes become cuts, slides and stamps appear in place, counts snap; functional animation (hold bar, countdown) stays |
| `access.reduce_pulsing` / `reduce_flashing` | Columns in section 4: every pulse steady, no focus pulse, NEW BEST pulse removed; Critical Break white frame replaced by particles (VFX) |
| Background FULL / DIMMED 65% / PLAIN | Affects in-game parallax only. UI must read on all three: text sits on plates or carries the outline (3.3), so no UI value depends on the background |
| Effects level / Calm preset | Sets reduce_flashing, reduce_pulsing, reduce_motion and REDUCED effects in one write; nothing in this guide depends on effects level |
| Colour-vision | Nothing in the UI is colour-only: slot = colour + ring + pips (+ "P{n}" where it fits); boss HP = bar + `%`; chain expiry = end-cap + shortness of the bar; failure = glyph + words; selected = fill + underline + text; focus = border + arrow |
| Untimed menus | No menu element in this guide times out; toast and banner durations are set by the owning spec |
| Screen reader / TTS | Out of scope for this file; stance is in `design/accessibility-requirements.md` |

---

## 8. Conformance checklist (run against any screenshot or capture)

Each item is pass/fail. A spec in `design/ux/` is conformant when all applicable items pass.

- [ ] **Outline:** every glyph of text and every numeral has the 1 px `#14110E` outline on all 8 sides, in both scripts.
- [ ] **Sizes:** at text step 0 no text is below 12 px Latin cap height or 17 px Bengali (D12/D10 digits excepted); at step 3 in both languages no label is clipped and no Bengali line loses its top 2 px or bottom 3 px.
- [ ] **Colour roles:** Gold appears only on score, chain, tally hero and S8 points; Amber only on WARNING; **no text is drawn in Alarm Red `#E03A3E`**; red words are Alarm Flare `#F2494D` only, one headline line per screen, Cream under HIGH (failure = Flare headline + Cream sentence + Alarm Red plate edge and/or error glyph, rule 3); era tint touches plate edges only.
- [ ] **Dim colours:** `#5A5148` text appears only in the allowed cases of 3.1 rule 2; with `hud_contrast` HIGH none remains.
- [ ] **Greyscale test:** with colour removed, every state (selected, active chip, error, slot identity) is still distinguishable; no information relies on hue alone.
- [ ] **Language rule:** dual-script appears only on the 2.1 surfaces; all other text is the chosen language; toggling the chip changes no element position (diff two screenshots).
- [ ] **Digits:** Bengali and Western digits occupy the same cells; grouping is Western; "P{n}", initials and key names are Latin.
- [ ] **Grid and margins:** every plate edge is on a whole pixel; new plates are multiples of 4 px; no text or plate within 8 px of the canvas edge (16 px for plates and toasts) outside the HUD strip; no plate overlaps y 600-640 prompt bar.
- [ ] **Plate grammar:** chamfered rectilinear opaque Char plates, 1 px edge, no gradient, shadow, glow, ring, orb or needle shape.
- [ ] **Focus:** exactly one focus border (3 px Cream + arrow glyph), visible in greyscale.
- [ ] **Motion:** every animation matches a row in section 4 and every pulse has an amplitude of 40 points or less at 2 Hz or less; with all three reduce options on, the capture is static except hold bars and countdowns; no frame other than Critical Break changes mean luma by more than 8%.
- [ ] **Originality:** no string from the "not borrowed" list exists; no logo, font or layout copied from a named game.
- [ ] **Resolution:** the screen renders identically in canvas pixels at 360x640 x1, 720x1280 x2, 1080x1920 x3 and 1440x2560 x4, and inside a 19.5:9 phone safe area with nothing drawn outside the canvas.
- [ ] **Performance:** a language or text-step change relayouts in the same frame (no visible intermediate frame in a frame-by-frame capture); UI animations are tick-driven and add no per-frame allocation.

---

## 9. Open questions

| # | Question | Owner | Why open |
|---|---|---|---|
| 1 | Ghost digits and Standard-mode dim states sit at 2.2:1. Accept as designed (meaning repeated elsewhere), or raise Standard dim to `#A89E8A` everywhere? | art-director, accessibility | Changes `hud.md`, `settings.md`, `main-menu.md` colours; not decided here |
| 2 | ~~Alarm Red text is 3.95:1; add a lighter text variant?~~ **CLOSED 2026-11-03 (art-director).** Art bible 4.1 now carries **Alarm Flare `#F2494D`**, 4.76:1 on Char (computed; re-measure with the real renderer in the font spike, and under protan simulation). `#E03A3E` stays the plate-edge and glyph-fill red. Rule 3 states the use. The 2/3 px clip floors versus the 4 px matra reservation statement was already added to art bible 7.5 by wave 5 batch 2. | — | Closed |
| 3 | Line pitch base: is Latin x 1.2 applied to cap height (12 -> 15 px) or to font em size? `credits.md` uses 20 px | font spike, ui-programmer | Needs the chosen font |
| 4 | Hard offset plate shadow (2 px `#14110E`) for depth on bright backdrops: wanted? | art-director | Visual style decision |
| 5 | HUD column has no "P{n}" text (HUD Rule 8); is pips + ring pattern enough, or add a 5 px label? | art-director, ux-designer | `hud.md` OQ 9 |
| 6 | Tally "hero scale +1 step": remove, or define as a colour or 1 px edge step? | ux-designer, art-director | Conflicts with art bible 7.7 |
| 7 | Font face and conjunct gate (art bible 7.5) are unverified; contrast ratios and sizes need re-measuring after the font spike | art-director | Font not chosen |
| 8 | Margins of 8 / 16 px are derived from existing plates, not playtested on REF-PHONE | ux-designer | Needs device test |
