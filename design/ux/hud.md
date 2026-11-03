# HUD Design

> **Status**: Approved (2026-11-03) — previously: Reviewed (`/ux-review` 2026-11-03; blocking issues fixed, cross-document amendments pending, see `production/ux-reports/hud.md`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Template**: HUD Design
> **Revision 2026-11-03 (final doc closeout)**: Open Question 21 is now closed **and applied** - the HUD GDD carries the `stamp` rects and the lint clause, and Tutorial Rule 16a owns the 2P / Compact 48 fallback.
> **Revision 2026-11-03 (art-director decisions)**: new "DONE / SKIPPED stamp" layout section gives the stamp a 16x11 rect for 1P (224,4) and 3-4P (73,16 per column); 2P and Compact 48 have no room and suppress the in-strip stamp; Open Question 21 closed (the GDD Rule 30b amendment was applied later the same day, see the closeout revision above).
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: Open Question 10 **closed** (`critical-break.md` now reads HUD's `banner_wait_max` 180) and Open Question 13 **closed** (`CONTINUE_ACCEPT` = Fire, Start stays Pause).
> **Revision 2026-11-03 (UX amendments wave 5)**: the GDD amendments this spec requested are now applied (`design/gdd/hud.md` Rules 22, 23, 24, 30a, 34a(c), HF2, HF4, AC-13, AC-32, AC-37/37b, AC-45; `game-events-and-session.md` `continue_total`), so Open Questions 1, 4, 12, 15 and 20 are closed and 10 is narrowed to Critical Break. Style-guide citation fixed to section 3.1 (there is no G3); Bengali 4 px headroom reservation added; strip-mark inset rule for tight elements.
> Revised 2026-11-03 after /ux-review: added Purpose, Context, Navigation, Entry/Exit; Element Reference (zone, trigger, source, owner, priority); Notification Priority; Degraded States; Interaction Map, Events Fired, Transitions; Tuning Knobs; contrast ratios and colour-vision variants; banner px budgets; resolved victory portrait (moved to Tally), Continue timer variants (active total, UNTIMED rule), strip-mark clamping, pick-plate vs boss-zone draw order; ACs UX-18..UX-22.
> **Platform Target**: PC (Steam/itch), Web, Nintendo Switch / Switch 2, iOS, Android. Gamepad primary; keyboard full; touch partial (solo, 1P layout only). 1-4 local players. Fixed 360x640 portrait canvas (TATE-capable on PC/Web/Switch).
> **Sources**: `design/gdd/hud.md` (authority: Rules 1-36, HF1-HF9, AC-01..55), UI Requirements of `chain-tracker.md`, `scoring.md`, `collision-damage-lives.md`, `bombs.md`, `plane-kits-lancer-leech.md`, `plane-kits-sentry-breaker.md`, `boss-and-boss-parts.md`, `critical-break.md`, `coop-and-team-chain.md`, `powerups-and-drops.md`, `wave-and-stage-director.md`, `touch-controls.md`, `accessibility-options.md`, `tutorial.md`, `game-events-and-session.md`; `display-scaler-and-bezel.md` (Rules 15-16); art bible 7.1-7.10; `.claude/docs/technical-preferences.md` (Input & Platform). Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P08 (slot identity badge), P09 (join / ready-up, drop-in), P10 (owner-only pause; `set_slot_emphasis`), P11 (not used in play), P13 (resume beat), P18 (HUD plate), P19 (touch strip, outside canvas), P21 (accessibility-aware motion), P23 (bilingual block, banners only). Gap 2 in `interaction-patterns.md` (Continue prompt) is specified here, section "Continue plate".

Stories cite this file for layout and behaviour; exact rects live in `data/ui/hud_layout_*.tres` (GDD Rule 9). The rect tables in GDD "Layout tables" win over every drawing below.

---

## Purpose & Player Need

The player is flying a plane through a curtain of bullets and has about 200 ms per glance to confirm five facts: how many lives and bombs they have, how long the chain will live, how hurt the boss is, and which column is theirs (or who is in the team chain). The HUD exists so that the player never has to look away from the lane for longer than one glance, and never has to read a word to get any of those facts. In co-op the same glance must also answer "which column is mine" in grayscale. Failure looks like: a player dropping a 187 chain because the red end-cap was unreadable, or not knowing they are on the last life.

## Player Context on Arrival

The strip is not a screen the player navigates to; it is on screen the whole time the player is in a stage. Players arrive from Plane select / Lobby (just confirmed a plane, hands on the pad, adrenaline low) or from a Tally (just read a lot of numbers, about to be dropped into a Warning). Co-op players arrive mid-run through drop-in. The player's attention is on the field, not the strip: the HUD is read peripherally, with muscle memory for fixed positions.

## Navigation Position and Entry / Exit

| Item | Spec |
|---|---|
| Position | A persistent overlay of the Stage game state. Not a screen; not reachable from menus; takes no focus |
| Entry | Mode Hidden -> Stage on `stage_started` (hard cut, no animation, on the same tick the field and strip latch `play_top`). Drop-in changes a column, not the mode |
| Exit | Stage -> Tally on `tally_started` (strip removed on that tick, no animation); Stage -> Hidden on `run_ended`. The Pause menu draws over the frozen strip; it does not exit the mode |
| Focus | None. The HUD never holds input focus; there is no focus order and no d-pad order to document. The only interactive things near it (join, Continue accept, pause) are Input verbs routed by Input/Session/Menus |
| Back | No Back behaviour (P-pattern Back table: not applicable) |

---

## HUD Philosophy

| # | Principle | Consequence |
|---|---|---|
| 1 | **The glance.** A 200 ms look up must give: lives, bombs, chain life, boss health, who is in the team chain. | Few elements, fixed positions, one large element (chain plate). |
| 2 | **Nothing over the bullets.** The HUD lives in an opaque strip outside the play field. Only three banners cross the field, and only when no enemy bullet is alive. | No score popups, no floating tags, no element attached to an entity (Rule 11). |
| 3 | **Shape and number before colour.** Every meaning has a shape, count or pattern backup. | Pips + ring pattern for players, notch shape for "ready", end-cap for "chain about to die". |
| 4 | **Quiet.** No HUD element flashes. One pulse at a time, 1 Hz, 40% depth. | Pulse arbiter (Rule 31); `reduce_pulsing` turns it off. |
| 5 | **Same shape in every language.** Digits change script, layout never moves. | Shared digit grid per tier; icon-only fight HUD. |
| 6 | **Read-only.** The HUD never writes gameplay state and takes no input. | Pause, join and Continue input belong to Input/Session/Menus; the HUD only shows them. |

Anti-patterns (from GDD Player Fantasy): score popup over the field; blinking bar; layout change on language switch; unclear which column is mine; boss bar drawn in the field; Bengali text too small to read.

---

## Information Architecture

### Full Information Inventory

| # | Item | Source GDD (rule) |
|---|---|---|
| 1 | Score, 9 digits, per slot | Scoring UI; HUD 14, 16 |
| 2 | Lives (icons in 1P, icon + count in 2P / 3-4P), overflow `+N` | Session; HUD 13, 22 |
| 3 | Last-life cue (`lives == 1`) | HUD 22, 31 |
| 4 | Extend feedback (`+gained` tag, Gold edge step, MAX icon at cap) | Session; Powerups UI; HUD 22 |
| 5 | Bombs (icons / count), busy dim, denied shake | Bombs UI; HUD 21 |
| 6 | Kit bar (Lancer / Leech / Sentry / Breaker) with 40% notch | Kits UI; HUD 19 |
| 7 | Drone ticks (4) and drone lamp / Sentry recall glyph | Kits UI; HUD 20 |
| 8 | Slot identity: pip stack, identity line (ring pattern), colour | Co-op; art bible 4.4; HUD 8 |
| 9 | Pilot portrait (1P only; hurt / determined / neutral. The victory pose is drawn by the Tally, not the HUD; see Open Question 1) | HUD 22 |
| 10 | Chain count, window bar, red end-cap, ghost, milestone edge, `xN` popup, +1 jump | Chain UI; HUD 17 |
| 11 | Chain lamp (boss fight, 2+ Active slots) | Co-op UI; HUD 17 |
| 12 | Team bracket + `+NN` tag on member plates | Co-op UI; HUD 18 |
| 13 | Plate-local awards (PART, BOSS, CRITICAL_BREAK, LIFE_BONUS) | Scoring UI; HUD 29 |
| 14 | MAX tag (cap-hold streak at full rate) | Scoring; HUD 30 |
| 15 | Critical Break armed ticks + Gold bomb-icon outline | Critical Break UI; HUD 28 |
| 16 | Boss bar, phase tick, critical notch, chip, `NN%` | Boss UI; HUD 26, HF3 |
| 17 | Part-kill cue (broken-plate icon + parts left) | Boss UI; HUD 26 |
| 18 | Enrage cue (Amber icon + seconds left) | Boss UI; HUD 26 |
| 19 | Stage / wave progress track (outside boss fights) | Wave director UI; HUD 26 |
| 20 | Join plate (START glyph + pips), Selecting frame | Session, Co-op; HUD 23 |
| 21 | Drop-in pick plate (84x44) in the Selecting slot's column | Session UI; HUD 23 |
| 22 | Continue plate: accept glyph, countdown, drain bar, dim score | Session UI; HUD 24 |
| 23 | Slot emphasis frame (paused-by / waiting) | Menus 22; HUD 25 |
| 24 | Banners: WARNING, boss name plate, CRITICAL BREAK (dual-script) | Wave director, Boss, CB; HUD 27 |
| 25 | Tutorial strip mark, drill bar, DONE / SKIPPED stamps | Tutorial; HUD 30a, 30b |
| 26 | Boss Rush counter `n/N` | Leaderboards / Rush; HUD 30c |
| 27 | PRACTICE assist tag (12x12) | Accessibility; HUD 34a |
| 28 | Near-plane chain bar (optional, layer 7) | Accessibility; HUD 34a |
| 29 | Era tint on plate edges | Era shift; HUD 33 |

Deliberately **not** on the HUD: hit results on armoured targets and invulnerability timer (in-world only, Collision UI); hitbox/damage numbers; any pause menu (Menus); any word label in the fight HUD (icons and numerals only).

### Categorization

| Category | Meaning | Items (inventory #) |
|---|---|---|
| **Must show** | Always visible while the HUD is in Stage mode | 1, 2, 5, 6, 8, 10 (plate frame, count, bar), 16 only during a boss, 19 otherwise (the boss row is always occupied) |
| **Contextual** | Appears on a game event or state, leaves by itself | 3 (lives == 1), 4, 7 (hidden at 0 drones), 9 (1P), 11, 12, 13, 14, 15, 17, 18, 20, 21, 22, 23, 24, 26, 27, 29 |
| **On demand** | Shown because the player or a system asked | 25 (Tutorial), 28 (setting), 27 (setting `run.assisted`), Pause emphasis frame (23) |
| **Hidden** | Never drawn in the HUD | Tally mode (whole strip), Hidden mode (menus), hit results, invuln timer, difficulty/rank numbers, any in-field number |

### Element Reference (zone, visibility trigger, data owner, priority)

Priority is the keep-order if space or the pulse/lane budget forces a choice: **P1** never hidden or displaced in Stage mode; **P2** shown on its trigger, may be queued; **P3** decorative or optional, first to be dropped. "Owner" is the system that owns the data; the HUD owns only display state (shown score, chip, animation counters). No data element is owned by "UI".

| # | Element | Zone | Visible when | Data source (owner) | Priority |
|---|---|---|---|---|---|
| 1 | Score | Cluster row A | Stage, slot Alive/Dead; dim in Continue | `display_score(slot)` (Scoring) | P1 |
| 2 | Lives | Cluster row B | Alive/Dead; hidden Continue/Inactive | `lives(slot)` (Session) | P1 |
| 3 | Last-life underline | Under lives | `lives == 1`, slot Alive | Session | P1 |
| 4 | Extend tag / MAX icon | Plate lane / lives | 60 ticks after `extend_awarded` | Session | P2 |
| 5 | Bombs | Cluster row B | Alive/Dead | `bombs(slot)`, `bomb_busy` (Bombs) | P1 |
| 6 | Kit bar + notch | Cluster row C | Alive/Dead | `kit_bar(slot)`, `kit_ready` (Kits) | P1 |
| 7 | Drone ticks / lamp | Cluster row B-C | ticks always; lamp at 1+ drones | `drone_count` (Session), `drone_lamp` (Kits) | P2 |
| 8 | Identity (pips, line) | Column outer edge | Always, every mode | Slot colour/pattern (Player plane) | P1 |
| 9 | Pilot portrait | 1P (5,0) | 1P Stage | Session events | P3 |
| 10 | Chain plate | Right of cluster | Alive/Dead | `count`, `bar_px`, `red` (Chain tracker) | P1 |
| 11 | Chain lamp | Plate corner | Boss alive and 2+ Active | `lamp_state` (Co-op) | P2 |
| 12 | Team bracket + tag | Strip top / plate lane | `team_chain_on` | Co-op, Chain tracker | P2 |
| 13 | Awards | Plate lane / takeover | 60 ticks per award | award events (Scoring) | P2 |
| 14 | MAX tag | Plate lane / beside | Cap-hold full rate | Scoring | P3 |
| 15 | Armed ticks, bomb outline | Plate corners, bomb icon | `cb_state` ARMED/COMMITTED | Critical Break | P1 |
| 16 | Boss bar, zones | Boss row | Boss alive | `boss_bar_state()` (Boss) | P1 |
| 17 | Part-kill cue | Right zone | 90 ticks | Boss | P2 |
| 18 | Enrage cue | Left zone | Enrage to boss_gone | Boss | P1 |
| 19 | Progress track | Boss row | No boss, no drill, no rush | `wave_started/ended` (Wave director) | P3 |
| 20 | Join plate | Free column / 1P gap | Slot free | Session, Input glyph | P3 |
| 21 | Pick plate | Selecting column | Slot Selecting | Menus (geometry), Session | P1 for that column |
| 22 | Continue plate | Replaces chain plate | Slot in Continue | `continue_remaining`, resolved total (Session) | P1 |
| 23 | Slot emphasis | Column frame | Paused-by / waiting | Menus | P1 |
| 24 | Banners | Field centre | Gate clear | Wave director, Boss, Critical Break | P1 |
| 25 | Strip mark, drill bar, stamps | Element / boss row / column | Tutorial request | Tutorial | P2 |
| 26 | Rush counter | Left zone | Rush, outside fight | Session `mode`, Rush | P2 |
| 27 | PRACTICE tag | Column corner | `run.assisted` | Accessibility / Session | P2 |
| 28 | Near-plane bar | Under plane (layer 7) | Setting on | Chain tracker | P3 |
| 29 | Era tint | Plate edges | From `era_swap_committed` | Era shift | P3 |

GDD coverage: every system in the owning GDD's Interactions table that has a UI Requirement (Session, Chain tracker, Scoring, Co-op, Kits, Bombs, Boss, Critical Break, Wave director, Powerups, Tutorial, Rush, Accessibility, Era shift, Touch) maps to a row above. Collision-damage-lives UI items that are deliberately not on the strip (hit results, invulnerability timer) are listed under "Deliberately not on the HUD".

---

## Layout Zones

Canvas 360x640 at 1x. Coordinates are canvas px, `(x, y, w, h)`. Opaque Cabinet Char `#1E1B18` strip at draw slot 11, inside the canvas, never in the bezel. `play_top` is latched at `stage_started` / `wave_started` (GDD Rule 6).

### Zone summary

| Mode | Strip (y) | Columns | Latch rule |
|---|---|---|---|
| 1P | 0-47 (`play_top` 48) | 1 | N = 1 |
| 2P | 0-47 | 2, plates face each other | N = 2 |
| Compact 48 | 0-47 | 4 x 90 px | Only while 48 px latched and a 3rd/4th slot is Selecting or counted |
| 3-4P | 0-71 (`play_top` 72) | 4 x 90 px fixed | N >= 3, latched |

1P <-> 2P changes on the tick `coop_count_changed` arrives (same strip height). 2P -> 3P waits for the next `wave_started`, or the next `stage_started` during a boss fight. No transition animation. A slot in Continue still counts, so a Continue never flips the layout.

### 1P (360x48)

```
#:[PORTRAIT][ 123,456,789  score D17 ]  [START]#            [MAX]   .--------------------.
#:[  36x36 ][                         ]                             | +50   x3       187 |
#:[        ][ o o o o o +N ]  [ o o o o o ]  ||||  [L]              | ################^  |
#:[        ][ ===|======== kit ]                                    '--------------------'
  [E 20]  [==============================  boss bar  ======================] [87%]
```

| Element | Rect | Size |
|---|---|---|
| Identity line / pip stack | (3,0,1,36) / (0,2,3,15) | |
| Portrait | (5,0,36,36) | 36x36 |
| Score | (45,0,107,19) | D17, right-aligned, Gold |
| Lives icons / overflow | (45,19,78,14) / (123,20,16,14) | 14x14, D12 |
| Bomb icons | (143,19,78,14) | 14x14 |
| Kit bar | (45,33,78,4) | |
| Drone ticks / lamp / MAX | (226,22,19,6) / (247,22,5,5) / (246,5,12,8) | 4x6 ticks |
| Join plate (next free slot) | (156,1,64,16) | START glyph 16x16 |
| Chain plate | (262,1,96,34) | D24 |
| Boss bar / left zone / right zone | (24,37,312,10) / (0,36,24,12) / (336,36,24,12) | D10 in zones |

### 2P (360x48)

P1 cluster as below; P2 cluster = P1 + 272 px, identity at the right edge (line x 356, pips x 357-359). Plates face each other with 2 px between (P1 plate 83-178, P2 plate 181-276 as given by GDD). Team bracket sits on y 0 between plate centres.

| Element | P1 rect | Size |
|---|---|---|
| Score | (5,1,78,14) | D12, 9 digits + 2 seps = 78 |
| Lives icon + count | icon (5,16,14,14), digit (19,16,8,14) | counter form |
| Bomb icon + count | icon (30,16,14,14), digit (44,16,8,14) | counter form |
| Drone ticks / lamp | (56,19,19,6) / (76,19,5,5) | |
| Kit bar | (5,31,78,4) | |
| Chain plate | (83,1,96,34); P2 (181,1,96,34) | D24 |
| Boss bar and zones | as 1P | one bar for the strip |

### Compact 48 (360x48, four 90 px columns, origin `90c`)

Used only for a 3rd/4th slot joining while the strip is latched at 48. Unused column is blank (no join plate).

| Element | Rect (relative to column) | Size |
|---|---|---|
| Score | (5,0,85,14) | D12 |
| Lives / bomb icon + count | icon (5,16,11,11) digit (17,16,6,12) / icon (24,16,11,11) digit (36,16,6,12) | D10 |
| Drone ticks / lamp | (5,29,15,5) / (21,29,5,5) | 3x5 ticks |
| Kit bar | (28,30,14,4), notch at x 33 | W 14 |
| Chain plate | (44,14,46,22) | D16, `BAR_PX` 42 |
| Pick plate (Selecting slot) | (5,2,84,44) | replaces the column cluster |
| Boss bar and zones | as 1P | |

### 3-4P (360x72, four columns of 90 px)

```
#:[ 1,234,567 ]  #:[   987,654 ]  #:[ 3,100,200 ]  #:[ START + pips ]
#:[o3 o2 || ]    #:[o2 o1 || ]    #:[o3 o0 || ]    #:[   join plate  ]
#:[==|======]    #:[==|=======]   #:[==|=======]   #:[               ]
#:.----------.   #:.----------.   #:.----------.    #:.--------------.
#:| +30  187 |   #:| +30   64 |   #:| +30  412 |    #:|              |
#:| ########^|   #:| ######## |   #:| ######## |    #:|              |
  [E]  [===============  boss bar  ================]  [87%]
```

| Element | Rect (relative to column) | Size |
|---|---|---|
| Identity line / pip stack | (3,0,1,60) / (0,2,3,15) | rows A-C |
| Score | (5,1,85,14) | D12, right-aligned |
| Lives / bomb icon + count | icon (5,17,11,11) digit (17,16,6,12) / icon (26,17,11,11) digit (38,16,6,12) | 11x11, D10 |
| Drone ticks / lamp | (48,19,15,5) / (65,19,5,5) | 3x5 ticks |
| Kit bar | (5,28,82,4) | W 82 |
| Chain plate | (5,33,84,26) | D16, `BAR_PX` 82 |
| Team bracket | y 32 | |
| Boss bar (absolute) / zones | (24,61,312,10) / (0,60,24,12), (336,60,24,12) | Row D |

A slot that is Empty, Inactive or Selecting in a 3-4P column shows the join plate (or pick plate). A 4P game with slot 2 Empty keeps columns 0, 1, 3 at x 0, 90, 270.

### DONE / SKIPPED stamp (Flight School, GDD Rule 30b)

Decided 2026-11-03 (art-director). One stamp asset, **16x11** at every scale: a 3 px border ring and a 10x5 interior. **DONE** = Cream border, Char interior, Cream check glyph (about 7x5). **SKIPPED** = same size and rect, border and dash glyph (6x1, centred) in `#A89E8A` (6.5:1) at **both** contrast settings, because it carries information and `#5A5148` (2.2:1) may not (arcade-ui-style 3.1 rule 2). Shape differs (check vs dash), so it reads in greyscale. Shown 90 ticks, no flash, no animation (so `reduce_motion` changes nothing); draw slot 11 with the strip.

| Mode | Stamp rect (x, y, w, h) | Free space used | Clearance |
|---|---|---|---|
| 1P (48 px) | **(224,4,16,11)** | Gap between the join plate (156-219) and the MAX tag (246-257), above the drone ticks (y 22) | 4 px to the join plate, 6 px to MAX, 7 px above the drone ticks, 22 px to the chain plate (262); nothing of pip stack, identity, portrait, score, kit bar or boss row is touched |
| 2P (48 px) | **none, suppressed** | See below | n/a |
| Compact 48 | **none, suppressed** | See below | n/a |
| 3-4P (72 px) | **(73,16,16,11) relative to the column**; absolute x 73 / 163 / 253 / 343, y 16 | Block right of the drone lamp (ends x 69), under the score (ends y 14), above the kit bar (y 28) | 3 px to the lamp, 1 px under the score row, 1 px above the kit bar (y 27 is free), 1 px to the next column; chain plate (y 33+) and boss row (y 60+) are clear |

**Why 2P and Compact 48 have no rect.** In 2P each 83 px cluster is full: score y 1-14, counters y 16-29, drone ticks and lamp at x 56-80 (y 19-24), kit bar y 31-34, then the 96 px chain plates from x 83 with a 2 px gap between them. The largest free block is x 52-82 by y 25-30 (31x6), under 11 px tall. In Compact 48 the 90 px column is packed from the score row to y 35, with the chain plate at x 44-89 (y 14-35) leaving no block even 11 px high. Forcing a rect would cover the chain plate, kit bar or boss row, which Rule 30b does not allow.

**Fallback (binding for 2P and Compact 48).** The stamp is **not drawn in the strip**. It is **not** drawn over the play field (a 16x11 Char plate would hide bullets and breaks "nothing over the field"), and it does **not** borrow the boss-row zones (they hold the drill group icon and `n/N` and are covered by the zone-priority rules). The in-strip signals that remain are the drill bar reaching its full stepped fill and `n/N` reaching `N/N`. A skipped drill leaves the bar dim. Per-slot DONE / SKIPPED in these two modes must therefore be carried by the Flight School / Tutorial surface itself (its own plate, a toast, or audio); this is a cross-document request to the Tutorial owner, not something the HUD can supply. Layout lint (AC-03) treats `stamp = none` as a valid explicit value in `hud_layout_2p` and `hud_layout_compact48` and fails if the key is missing.

**Check against the 1P rect table:** the stamp sits at x 224-239, y 4-14. Join plate (156,1,64,16) ends x 219; MAX (246,5,12,8) starts x 246; drone ticks (226,22,19,6) start y 22; lamp (247,22,5,5). No overlap. The existing kit bar (45,33,78,4) already touches the drill bar row (y 36 against y 37) and is not changed here.

### Chain plate internals (all modes)

Left **lane** (free of digits) priority: award or `+N` > `xN` popup > team tag > MAX tag. Lane = x +1..+43 (1-2P), +1..+46 (3-4P). In 3-4P team tag (37) + 1 + MAX (8) = 46 side by side; in 2P MAX stacks under the team tag; in 1P MAX sits beside the plate.

### Safe zone, bezel and platform notes

| Platform | Rule |
|---|---|
| All | Strip and banners are inside the 360x640 canvas; never in the bezel (Display Rule 2). The HUD has no scale option; `play_top` stays 48 / 72. |
| iOS / Android | Canvas is laid out inside the OS safe area (Display Rule 15), so notch/home indicator never overlap the strip. Bezel art may go under them; the HUD never does. |
| PC / Web / Switch | Safe area ignored (full window). On Switch TV mode, no extra HUD margin is added; unverified for TV overscan (Open Question 7). |
| Touch strip reserve | The button strip (Hold, Drone, Bomb, Pause) is **below** the canvas, `strip_px` = `round((3 + 12 x s_btn) mm x ppmm)` (about 270 px on iPhone X). It is outside the HUD. The HUD has no tile for it; Pause is a strip button (Touch GDD). Strip reserve is constant during a run; the HUD never moves for it. |
| TATE | Canvas rotates as a unit; strip stays at the screen "top" of the canvas; no layout change. |

Margins in canvas px (1x), per platform. The canvas is the same everywhere, so the margin is a property of the canvas, not of the device:

| Platform | HUD inset from canvas edge | Platform inset applied outside the canvas |
|---|---|---|
| PC / Web | 0 px (pip stack at x 0, chain plate to x 357 in 1P); no extra margin | None. Web: embedded page may crop the canvas edges (Open Question 7) |
| Switch / Switch 2 | 0 px; no extra margin added (TV overscan unverified, Open Question 7) | Bezel art only |
| iOS (iPhone X+) / Android (Galaxy S20+) | 0 px inside the canvas | Canvas is placed inside the OS safe area by the Display scaler, so the notch, home indicator and camera cut-out never overlap the strip (Display Rule 15). The HUD does not read safe-area values |
| Touch strip (phones) | None | `strip_px` below the canvas, constant for the run |

Required by this spec: no HUD pixel lies outside x 0-359 / y 0-(`play_top` - 1), except the three banners which stay inside the canvas (UX-15 verifies).

---

## HUD Elements

Common columns: **Category** (Must / Contextual / On demand), **Update trigger** (pull = sampled each tick; push = event), **Reduce-motion / flash behaviour**. Timings in ticks at 60 Hz. All colours via `HudTheme`.

### Score
| Field | Spec |
|---|---|
| Category | Must |
| Content | `display_score`, 9 digits, `,` grouping, no leading zeros, clamp 999,999,999 |
| Visual form | D17 Gold (1P), D12 Gold (2P, 3-4P, compact); right-aligned; ones digit fixed x |
| Update | Pull each tick. Gap <= 5,000 snaps; larger gaps roll geometric (about 32 ticks); falls snap (HF1) |
| Contextual | In Continue the cluster shows the score dim `#5A5148` |
| Animation | Roll only for big gaps |
| Reduce motion | `reduce_motion`: always snap |
| Null / empty | `0` |

### Lives
| Field | Spec |
|---|---|
| Category | Must; last-life cue Contextual |
| Content | Session `lives` (plane in flight counts as one) |
| Visual form | 1P: up to 5 plane-pictogram tiles 14x14 + `+N` overflow. 2P / 3-4P: one icon + count |
| Update | Pull; `player_died` push for break animation |
| Contextual | `lives == 1` and slot Alive: steady 1 px Alarm Red underline; pulses via arbiter. Extend: new icon with 12-frame Gold edge step + `+gained` tag 60 ticks; `gained == 0` shows MAX icon 60 ticks |
| Animation | Lost life: 3-frame break (Alarm Red tile frames 1-2, then gone); no screen tint |
| Reduce | `reduce_pulsing`: underline stays static. `reduce_motion`: break remains (functional) |
| Null | Slot Continue/Inactive: lives hidden |

### Bombs
| Field | Spec |
|---|---|
| Category | Must |
| Content | `bombs(slot)`, up to 5 |
| Visual form | 14x14 (11x11 in 3-4P / compact) Tracer Orange tiles, bomb pictogram; counter form in 2P+ |
| Update | Pull; `bombs_changed`, `bomb_denied` push |
| Contextual | `bomb_busy`: whole display 60% opacity, shapes unchanged. CB ARMED/COMMITTED: Gold outline on the icon |
| Animation | Spent: 3-frame break. Refill: one icon per 6 ticks. `NO_BOMBS` denied: 2 px shake for 8 ticks (max 2 Hz). `BUSY` denied: no UI |
| Reduce | `reduce_motion`: no shake |
| Null | 0 bombs: empty row (in counter form shows `0`) |

### Kit bar and notch
| Field | Spec |
|---|---|
| Category | Must |
| Content | `kit_bar(slot) = (num, den)`: Lancer meter; Leech and Sentry ability bar; Breaker stock (`stock/60`) |
| Visual form | 4 px bar, Tracer Orange on Char, ticks each 25%; Lancer notch 2x4 at 40% (outline = not ready, solid Cream = ready). Breaker ready = `stock >= 2` |
| Update | Pull (HF4: at least 1 px when `num > 0`) |
| Reduce | No animation |
| Null | `den = 0`: 0 px + one debug warning |

### Drone ticks and lamp
| Field | Spec |
|---|---|
| Category | Contextual (hidden lamp at 0 drones) |
| Content | `drone_count` (0-4); Lancer / Breaker lamp READY / ACTIVE / COOLDOWN; Sentry recall glyph; Leech none |
| Visual form | 4 ticks, Cream filled = owned, outline = empty. Lamp 5x5: solid Cream READY; outline + bottom-up fill COOLDOWN; steady Cream + shrinking underline ACTIVE. Sentry glyph outline until `recall_available`, solid after |
| Update | Pull; new drone fills tick in 4 frames + 6-frame Gold edge step |
| Reduce | Nothing animates beyond the 4-frame fill |
| Null | 0 drones: all ticks empty on the death tick, lamp hidden |

### Chain plate
| Field | Spec |
|---|---|
| Category | Must (hero element) |
| Content | `count` 0-999, window bar, red end-cap, ghost, lamp, corner ticks, popups |
| Visual form | Chamfered Char plate, `#5A5148` edge + 20% era tint. D24 (1-2P) / D16 (3-4P) Gold digits. Bar 4 px Gold on `#3A2A14`, `BAR_PX` 94 / 82 / 42 |
| Update | Pull `count`, `bar_px`, `red`. Push gain / milestone / drop / multiply |
| Contextual | Last 25% of window: 1 px Alarm Red end-cap at the bar tip (no blink). Milestones 50 Cream, 100 Gold, 200 bright Gold + 2 px edge (stays until drop). `xN` popup 60 ticks. CB ARMED: four Alarm Red 2x2 corner ticks (steady; pulse within Rule 31 when COMMITTED). Lamp 2x2 top-right: lit Gold, unlit `#5A5148`, Gold outline in join grace; boss alive and 2+ Active slots only |
| Animation | Gain: digits up 2 px for 2 frames, at most once per 12 ticks; bar refills in 2 steps. Milestone sparkles 12 frames (fixed table). Drop: digits fade to `#5A5148` and shift down 3 px over 4 frames (1,2,3,3), clipped to the plate |
| Reduce | `reduce_motion`: no jump, no drop shift (fade only). `reduce_flashing`: sparkles off, edge step stays |
| Null | Before any chain: dim `0`, empty bar. After a drop: dim ghost of last value until the next counted hit |

### Team bracket and tag
| Field | Spec |
|---|---|
| Category | Contextual (boss fights, `team_chain_on`) |
| Content | Members, `team_pct - 100` |
| Visual form | 1 px Gold bracket (y 0 in 1-2P, y 32 in 3-4P) with 3 px down-ticks at member plate centres; each member plate carries a 12x8 two-chevron icon + `+20/+30/+40` (D12 Cream) in its lane |
| Update | Push `team_chain_started/ended`; pull `m`, `team_pct` |
| Reduce | Static: no flash or pulse |
| Null | Off: nothing drawn |

### Awards and MAX tag
| Field | Spec |
|---|---|
| Category | Contextual |
| Content | PART `+5,000` (lane, 60 ticks); BOSS `+100,000`, CRITICAL_BREAK `+N`, LIFE_BONUS (plane icon + `+N`) take over the digit area 60 ticks (D12 Gold, centred, bar keeps running) |
| Queue | FIFO of 3 per plate; one shown at a time; 4th drops the oldest not yet shown |
| MAX tag | 12x8 icon (8 px wide in 3-4P), double chevron over a bar, Gold; while cap-hold streak pays full rate |
| Not shown | HIT, KILL, ITEM, CAP_HOLD only update the score. No number is ever drawn over the field |
| Reduce | No motion involved |

### Pilot portrait (1P only)
36x36 at (5,0). Three poses in the HUD: **neutral** by default; **hurt** from `player_died` for 120 ticks (`portrait_hurt_ticks`); **determined** from `boss_intro_started`. Priority while two apply: hurt over determined; when the hurt timer ends in a boss fight the portrait returns to determined, otherwise neutral. The portrait returns to neutral on `boss_defeated` / `boss_gone` (derived: determined is tied to the boss fight; GDD Rule 22 does not say). **The victory pose is not a HUD pose**: the HUD is hidden in Tally mode, so a HUD victory could never be seen. The Tally draws its own 96x96 victory portrait (`stage-tally.md`, 1P hero block); see Open Question 1 and the cross-document amendment. No portrait in 2P / 3-4P. Data: Session events (owner Session); update push on event. Null: unknown pose falls back to neutral. Reduce-motion: swap is instant (no animation).

### Join plate and pick plate
| Field | Spec |
|---|---|
| Category | Contextual |
| Content | START glyph 16x16 (family of the pad that would join) + pip stack of the slot that would be taken; pattern line at 40%. No text |
| Where | 1P: one plate for the next free slot at (156,1,64,16). 2P: none. 3-4P: in each non-counted column. Compact: none |
| Selecting | Steady 2 px slot-colour frame. In 48 px mode the Menus 84x44 pick plate (plane cursor; P07, P09) goes into the compact column; in 72 px mode into the fixed column. Never over the field, never over an Alive plate. Display layout returns when the pick ends (lock-in or 900-tick cancel) |
| Pick plate vs boss row | The 84x44 plate (5,2,84,44) overlaps the boss bar and, in columns 0 and 3, the left/right zones (e.g. `NN%` at x 336-359). Decision: the **zones draw above the pick plate** (their 24x12 rects are never covered, so enrage seconds and `NN%` stay readable); the plate's bottom outer corner in those columns is clipped by the zone and Menus must keep its cursor and labels out of that 19x10 corner (amendment requested). The boss **bar** (24..335) is hidden under the plate only for the columns it overlaps (GDD `shares_lane`); the bar fill resumes when the pick ends |
| Animation | None in the HUD GDD (Open Question 3) |
| Reduce | n/a |

### Continue plate
| Field | Spec |
|---|---|
| Category | Contextual (slot in Continue) |
| Content | Accept-button glyph 16x16 from Input's `action_glyph(slot, CONTINUE_ACCEPT)` - resolved 2026-11-03 to **Fire** (Input Rule 24b); Start does not accept, it pauses - plus the `ceil(continue_remaining)` countdown and the drain bar |
| Visual form | Replaces the chain plate. Countdown D24 Cream (1-2P) / D16 (3-4P); up to two digits (30 s fits: 2 x 15 = 30 px of the 45 px count area). Drain bar built like the chain bar, Alarm Red end-cap in the last 25% of the **active** duration. Cluster shows the score dim (what a Continue wipes); lives and bombs hidden |
| Update | Pull `continue_remaining` and the resolved total each tick; Audio ticks on `ceil` change |
| Active total | `T = continue_total` in seconds, resolved by Session from `access.continue_timer`: STANDARD 10 s (600 ticks), EXTENDED 30 s (1,800 ticks), UNTIMED with another slot Alive 30 s (Accessibility Rule 22, F9). The HUD never assumes 10 s |
| Bar formula | `bar_px = ceil(BAR_PX x continue_remaining / T)`; `red = continue_remaining x 4 <= T`. Examples: STANDARD 3.8 s -> 36 px (1-2P); EXTENDED 14 s -> `ceil(94 x 14 / 30)` = 44 px; red from 7.5 s (24 px) |
| UNTIMED, no other slot Alive | Session reports no total: the plate shows the accept glyph only (steady, no countdown, no drain bar, no red). If a total later appears (last other player dies while waiting), the countdown and bar appear at that value (Accessibility edge case); the HUD draws whatever Session reports |
| Result | Accept: score snaps to 0, column returns to Alive. Expiry: slot becomes Inactive (join plate). Pause freezes the countdown |
| Touch | Touch-only solo play shows the same glyph slot as a tap hint (proposal, Open Question 2) |
| Reduce | Countdown and bar are functional: kept |

### Boss row (Row B in 1-2P and compact, Row D in 3-4P)
| Field | Spec |
|---|---|
| Category | Must (always occupied) |
| Boss bar | Alarm Red fill on `#2A0F12`, 1 px outline, 310 px interior (HF3). Cream phase tick (parts / core boundary), taller Alarm Red critical notch (lights in Critical). Fill-in over 60 ticks at `boss_started`. Darker `#7A2226` chip catches up in 18 ticks. Right zone `NN%` D10 Cream (`100%` = 24 px) |
| Part kill | 90 ticks: broken-plate icon + parts left in the right zone; last part: core-exposed icon, no number |
| Enrage | Left zone: 7x10 Amber icon + `timeout_left` seconds (D10 Amber), counting from 20; icon pulses via arbiter |
| No boss | Segmented stage/wave track (4 px, one segment per wave, filled = done): 100% for 300 ticks after `stage_started`, then 40% |
| Rush | `n/N` + boss glyph in the left zone outside fights |
| Flight School drill | Boss rect becomes the drill bar (stepped Cream fill, target notch), group icon left, `n/N` right |
| Reduce | `reduce_motion`: chip snaps (proposal, see Open Question 8). `reduce_pulsing`: enrage icon steady |
| Null | `bar_permille` 1 shows 1 px and `1%`; no boss shows the track, nothing red |

### Banners (WARNING, boss name plate, CRITICAL BREAK)
| Banner | Content | Timing |
|---|---|---|
| WARNING | Two 24 px Amber stripe bands (scroll 3 px / 4 ticks) + 80 px plate, `text_both("banner.warning")` (Bengali 34 px over Latin 24 px). Block top `centre_y - 64` (HF8): 280 at `play_top` 48, 292 at 72 | `warning_started`, 150 ticks, out 8 frames |
| Boss name | 9-slice Char plate, top `play_top + 24`, `text_both("boss.<id>.name")` | 90 ticks, from intro tick 60 |
| Critical Break | 300x80 plate at x 30, y `play_top + 24`, Gold on Char, `text_both("banner.critical_break")` | in 10 frames, hold about 30 ticks, out 8 frames; starts from `critical_break_landed` |

Gate: a banner starts only when `enemy_bullet_count == 0`; waits up to `banner_wait_max` (180); then skipped with fallback (Amber stripes in the boss row for 150 ticks for WARNING, nothing for the others) and a debug warning. One at a time, queue of 2. `stage_cleared` ends a showing banner in 8 frames. Pause freezes it. Reduce: `reduce_motion` cuts in/out and freezes stripes (proposal, Open Question 5); `reduce_pulsing` makes the WARNING text steady; `reduce_flashing` leaves the banner and replaces the CB white frame with particles (VFX).

### Slot emphasis, strip mark, assist tag, near-plane bar
| Element | Spec |
|---|---|
| Slot emphasis | `set_slot_emphasis(slot, NONE / PAUSED_BY / WAITING)`: steady 2 px frame in the slot colour around the column (P10). Never flashes |
| Strip mark | Tutorial: four Cream corner brackets (4 px arms, 1 px stroke), steady, 180 ticks (paused ticks do not count), one per slot. Ids: `chain_plate`, `chain_bar`, `kit_bar`, `drone_lamp`, `drone_pips`, `bomb_icons`, `lives_icons`. Placement: the element rect inflated by 2 px, then **clamped** to the mark clip rect of that column: x from column-origin + 4 (P2 in 2P: up to x 355) so the pip stack and identity line are never covered; y from 0 down to the row limit (36 in 48 px strips, 59 in 72 px strips) so the boss row is never covered. A clamped side keeps its bracket on the clip edge (the gap shrinks to 0), arms stay 4 px. **Inset rule (added 2026-11-03, wave 5):** where an element has **less than 3 px free** on a side, the bracket on that side is drawn **inset** - inside the element's own rect, flush to its edge - instead of outside it. This covers the two known tight cases: 1P `chain_plate` (262,1,96,34) has only 1 px above and 2 px to the right, and `kit_bar` would otherwise reach into the drill/boss bar (24,37,312,10). The mark stays four readable brackets in every case. Example: 1P `chain_plate` (262,1,96,34) inflates to y -1: top brackets draw at y 0; `kit_bar` (45,33,78,4) bottom brackets draw at y 36. Marks draw over neighbouring elements for their 180 ticks (layer 11), never below `play_top` |
| Assist tag | 12x12 PRACTICE hourglass icon per column while `run.assisted` is latched |
| Near-plane chain bar | Optional, off by default: 26x5 copy of the window bar under the slot's plane, layer 7, slot colour fill, Alarm Red end-cap. Not part of the strip; the only HUD-related drawing in the field and only by player choice (see Open Question 6) |

---

## HUD States by Gameplay Context

| Context | Strip | Changes |
|---|---|---|
| **Hidden** (boot, Title, Plane select, Results) | Not drawn | Menus draw their own UI |
| **Stage play** | Full | Boss row shows the progress track (100% for 300 ticks, then 40%). Join plates visible for free slots (1P, 3-4P) |
| **Warning** | Full | WARNING banner after the field is clear (bullet gate). Boss row stays on the track until `boss_started`. Fallback: Amber stripes in the boss row |
| **Boss intro** | Full | Boss name plate (90 ticks). 1P portrait goes to determined. Boss bar fills in over 60 ticks at `boss_started`. Lamps and team bracket become available |
| **Boss fight** | Full | Boss bar with chip, phase tick, notch, `%`. Part-kill cue (90 ticks) per part. Enrage cue (icon + seconds). Team bracket + tags when `team_chain_on` |
| **Critical Break** | Full | Armed: corner ticks on the plate + Gold bomb outline (COMMITTED pulses via arbiter). Landed: `xN` 60 ticks, then award takeover; banner via gate. Core ring/arc is VFX, not HUD |
| **Death / respawn** | Full | Lives break animation, chain drop on the hit tick, 1P portrait hurt 120 ticks, drones empty |
| **Continue** | Full (that column changes) | Continue plate replaces the chain plate; score dim; lives/bombs hidden. Layout never changes |
| **Drop-in pick** | Full | Display layout is the next mode (1P -> 2P, 2P -> 3-4P) within the latched strip height; pick plate in the Selecting column; Alive columns unchanged |
| **Paused** | Last frame, frozen (model does not tick) | Menu draws over it. `set_slot_emphasis` frames on the owner (PAUSED_BY) or waiting slots. Resume beat (P13) is drawn by Menus |
| **Tally** | **Hidden entirely**; tally owns the canvas | HUD returns at the next `stage_started`. No `extend_awarded` presentation (tally shows it) |
| **Era transition** | Full | Era tint on plate edges set on `era_swap_committed` (fallback `stage_started`). No other change |
| **Flight School (DRILL)** | Full | Drill bar replaces the boss bar when no boss; strip marks; DONE (check plate, 90 ticks) / SKIPPED stamps |
| **Boss Rush** | Full | Rush counter `n/N` in the left zone outside fights |
| **Run end** | Hidden | `run_ended` -> Results (Menus) |

### Loading, empty and degraded states

The HUD has no loading screen. "Loading" is the Hidden mode (not drawn); the first Stage frame draws from the first snapshot.

| State | What the player sees | Rule |
|---|---|---|
| Loading / first frame | Nothing until `stage_started`; then full strip from the first snapshot | No placeholder, no spinner. Layout, theme and atlas are loaded before `hud_ready` |
| Empty (no chain yet) | Dim `0`, empty bar | Chain plate Null rule |
| Empty (no boss) | Progress track, nothing red | Boss row Null rule |
| Empty column (3-4P) | Join plate with the pips of the slot that would be taken | Per-slot column state |
| Lost events | Numbers re-sync from the next snapshot; animations may be skipped | Dynamic Behaviors, event order |
| Missing system (test scene or load fault) | That element blank, no error shown to the player, one debug warning | Dynamic Behaviors |
| Kit `den = 0` | 0 px bar, one debug warning | Kit bar Null rule |
| Missing atlas cell | Western digit shown, one warning, layout unchanged | Localization table |
| Banner gate never clears | Banner skipped, Amber stripes (Warning only), debug warning | Banners gate |
| Pad disconnect for a live slot | Input auto-pauses; the HUD shows the frozen strip plus `WAITING` emphasis on that slot (Menus draws the reconnect overlay) | Slot emphasis |
| Layout lint failure (build time) | Build/test fails; never reaches the player | GDD AC-03 |

### Notification priority and queues

The HUD never stacks notifications in the same place. Each "channel" has one visible item, a bounded queue, and a defined drop rule:

| Channel | Shows at once | Queue | Priority within channel | Overflow |
|---|---|---|---|---|
| Banners (field centre) | 1 | 2 | request order (FIFO) | Third request dropped with a debug warning; `stage_cleared` ends the current one |
| Plate lane (per plate) | 1 | none | award or `+N` > `xN` > team tag > MAX tag (higher replaces lower; lower returns after) | n/a |
| Plate takeover (per plate) | 1 | 3 awards | FIFO | Fourth drops the oldest not yet shown |
| Pulse | 1 element | none | Warning text > enrage icon > last life of the lowest slot | Others show their static cue |
| Boss row left zone | 1 | none | enrage > rush counter > drill group icon (never co-occur by state: enrage needs a boss, rush shows outside fights, drill needs no boss) | n/a |
| Boss row right zone | 1 | none | part-kill cue > `NN%` (or drill `n/N`) | A second part kill within 90 ticks restarts the cue with the current parts left (proposal, Open Question 16) |
| Strip mark | 1 per slot | none | newest replaces older | n/a |

Across channels there is no global priority; banners sit in the field and never share pixels with the strip.

### Interaction Map

The HUD takes **no input**. Every input method has the same entry: none.

| Input | HUD behaviour |
|---|---|
| Gamepad (primary) | No focus, no buttons. Glyphs shown for join/Continue come from the slot's pad family |
| Keyboard | No focus, no keys. Glyphs show the bound key cap |
| Touch (partial, solo) | No tap targets in the HUD. Pause and play buttons are in the touch strip below the canvas |
| Mouse | No hover or click behaviour; nothing is hover-only |

Join, Continue accept, pause and disconnect reconnect are Input verbs handled by Input/Session/Menus; the HUD only reflects the results. Because there are no targets, Fitts's Law and mouse precision do not apply, and keyboard-only and gamepad-only play are the same.

### Events Fired

| Action | Event | Notes |
|---|---|---|
| HUD ready after layout/theme load | `hud_ready` | Own signal |
| A banner finishes (shown, skipped or cut by `stage_cleared`) | `banner_finished` | Own signal; Audio/Wave director may listen |
| Everything else | **None (null)** | The HUD writes no gameplay state and fires nothing else (GDD Rule 1, AC-01) |

### Transitions and Animations

All transitions are hard cuts or stepped, integer positions, at 60 Hz ticks. No tween smoothing.

| Transition | Enter | Exit | Reduce-motion behaviour |
|---|---|---|---|
| Strip (Stage mode) | Hard cut on `stage_started` | Hard cut on `tally_started` / `run_ended` | Same |
| Layout latch | Same tick as field bounds | n/a | Same (already no animation) |
| Banners | In 10 frames | Out 8 frames | Cut in/out (proposal, Open Question 5) |
| Boss bar | Fill in 60 ticks at `boss_started` | Cleared on `boss_gone` | Fill-in kept (functional); chip snaps (proposal, Open Question 8) |
| Plate award / popup | 60 ticks, no motion | Removed on timer | Same |
| Join / pick plate | Appears on slot state change, no animation | Removed on lock-in or cancel | Same |
| Continue plate | Replaces chain plate on state change | Returns on accept; join plate on expiry | Same |
| Slot emphasis | Instant | Instant | Same |
| Strip mark | Instant | Instant after 180 ticks | Same |

---

## Visual Budget

| Budget | Limit |
|---|---|
| Strip area | 1P/2P: 360x48 = 17,280 px = 7.5% of canvas. 3-4P: 360x72 = 25,920 px = 11.3% |
| Max simultaneous elements per 1P strip (Stage play, worst case) | 18: identity, portrait, score, lives, bombs, kit bar, drones, lamp, MAX, join plate, chain plate (frame, count, bar, lamp), boss bar, 2 zones |
| Max per column in 3-4P | 10: identity, score, lives, bombs, drones, lamp, kit bar, chain plate (frame, count, bar) |
| Max pulsing elements | 1 (arbiter): Warning text > enrage icon > last life of the lowest slot |
| Max simultaneous banners | 1 showing, 2 queued |
| Banner screen share (max) | Canvas is 360x640 = 230,400 px. WARNING block 360x128 = 46,080 px = 20.0%; Critical Break plate 300x80 = 24,000 px = 10.4%; boss name plate sized to its text, budget 15% (about 34,500 px, proposal; GDD gives no cap). Total banner + strip at worst: 20.0% + 11.3% = 31.3% of the canvas |
| Banner rule | Only one banner at a time, and only when no enemy bullet is alive, so the banner share never overlaps a live bullet |
| Max plate-local overlays per plate | 1 lane item + 1 takeover (3 queued awards) |
| Changes per tick | No element changes luminance faster than 3 Hz; reduce-flashing 1 Hz |
| Draw calls | At most 24 for the HUD in a full 4P frame (proposed, tighten after measurement) |
| **Field rule** | **Nothing is drawn over the play field (y >= `play_top`) except the three banners** (and the optional near-plane bar, a player setting on layer 7). No HUD node is parented to a plane, bullet or enemy. No score numbers over the field. Banners start only when no enemy bullet is alive |

---

## Dynamic Behaviors

| Behavior | Rule |
|---|---|
| Event order | HUD ticks after all gameplay systems in the same tick; events consumed in arrival order. After event loss, the next snapshot re-syncs all values |
| Redraw | Numeral fields redraw only on change. Constant score for 600 ticks = 0 `format_int` calls |
| Language switch | `language_changed` marks every numeral dirty; redraw within one frame; no rect moves |
| Layout latch | `play_top` and mode follow the latched `N`; no animation; field and strip move together on the latch tick |
| Pulse arbiter | One pulse at a time; opacity 100 / 80 / 60 / 80% in 15-tick steps (1 Hz) |
| Chain drop same tick as gain | Drop wins |
| Two milestones in one jump | Edge steps once to the highest; sparkles play once |
| Award during takeover | Queued (max 3); lane not drawn during a takeover |
| Pad swap | Join and Continue glyphs redraw next tick from Input's lookup |
| Missing system in a test scene | Element blank, no error |
| Pause | No tick; all animation frozen; no catch-up on resume |

---

## Tuning Knobs

All live in `data/ui/hud_rules.tres` (timings, thresholds, counts), `data/ui/hud_layout_*.tres` (rects) or `HudTheme` (colours). Values are GDD defaults; the GDD "Tuning Knobs" table holds the full too-low / too-high notes.

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `score_roll_instant_max` | 5,000 | 0-50,000 | Which score gains roll vs snap |
| `score_roll_div` | 6 | 2-12 | Roll speed (about 32 ticks for 1.25 M) |
| `chain_jump_min_gap` | 12 ticks | 6-30 | Digit jump frequency in laser streams |
| `milestone_sparkle_frames` | 12 | 6-24 | Milestone feedback length |
| `award_show_ticks` / `award_queue_max` | 60 / 3 | 30-120 / 1-5 | Award readability vs queue backlog |
| `part_caption_ticks` | 90 | 60-180 | Part-kill cue time over `NN%` |
| `chip_ticks` / `boss_fill_ticks` | 18 / 60 | 10-36 / 30-120 | Boss bar feel |
| `portrait_hurt_ticks` | 120 | 60-240 | Hurt pose vs respawn |
| `progress_full_ticks` / `progress_dim_pct` | 300 / 40 | 120-600 / 20-60 | Stage track prominence |
| `pulse_step_ticks` | 15 | 15-30 (never below 15: over 2 Hz) | Pulse rate |
| `banner_wait_max` / `banner_queue_max` | 180 / 2 | 60-300 / 1-3 | Banner skip rate vs lateness |
| `warning_ticks` / `name_plate_ticks` | 150 / 90 | 120-180 / 60-120 | Banner duration |
| `strip_mark_ticks` (Tutorial-owned) | 180 | Tutorial range | Strip mark duration |
| `continue_timer` (Accessibility-owned) | STANDARD 600 | 600 / 1,800 / untimed | Continue countdown and bar scale |
| `play_top` (registry-owned) | 48 / 72 | fixed | Strip height; not a HUD knob |

---

## Platform & Input Variants

The HUD takes **no input**. Variants affect only glyphs and reserved space.

| Variant | Behaviour |
|---|---|
| Gamepad (primary) | Join and Continue glyphs from the pad family (Xbox / PlayStation / Switch) for that slot via `glyph_family(slot)`, `action_glyph(slot, action)`. The Continue accept verb and its glyph come from Input (GDD default START, conflicts with Pause on START; Open Question 13) |
| Keyboard | Glyph shows the bound key cap (e.g. Enter); key names stay Latin in both languages |
| Mixed local players | Each slot's plate shows its own family; a pad swap redraws on the next tick |
| Touch (solo only, iOS / Android; Web touch) | 1P layout only. Button strip is below the canvas and constant for the run. Join plate is hidden on touch-only (touch cannot join others; proposal, Open Question 2). Continue accept glyph becomes a tap hint on the plate (proposal) |
| Phone vs PC vs Switch | Same canvas and layout everywhere; only bezel art and safe area differ. 4P on phone is pad-only; 90 px columns are about 4 mm at x3, so legibility on REF-PHONE is a playtest item (GDD OQ 2) |
| TATE | Canvas rotates as a unit; HUD unchanged |
| Hover | Nothing in the HUD depends on hover |

---

## Accessibility

Accessibility checklist: keyboard-only (HUD needs no input; join/Continue are Input verbs), gamepad-only, readable at minimum size (fixed pixel grid, tested in grayscale), not colour-only, no flashing, subtitles (the HUD has no dialogue), scales at all resolutions (integer scale of the fixed canvas).

| Option | HUD effect |
|---|---|
| `access.reduce_flashing` | Chain milestone sparkles off (edge step stays); no element changes brightness faster than 1 Hz; CB white frame replaced by particles (VFX) while the banner stays |
| `access.reduce_pulsing` | Pulse arbiter off: last-life underline, enrage icon, WARNING text, COMMITTED ticks all steady; join plate steady 100% |
| `access.reduce_motion` | Score snaps; digit jump, plate-drop shift and bomb shake off; portrait swap instant; (proposed) banners cut in/out, WARNING stripes static, chip snaps |
| `access.hud_contrast` (STANDARD / HIGH) | Plate edges `#5A5148` -> Cream; ghost digits and dim text -> `#A89E8A` (contrast about 6.5:1). Outline and patterns unchanged |
| `access.player_palette` (DEFAULT / LUMA_SPREAD) | Slot colours remap; ring pattern, pip count unchanged |
| `access.chain_bar_near_plane` | Optional 26x5 chain bar under the plane (layer 7), slot colour fill |
| `access.continue_timer` | STANDARD 600 / EXTENDED 1,800 / UNTIMED. UNTIMED shows the EXTENDED countdown while another slot is Alive; it hides countdown and bar only when no other slot is Alive (see Continue plate) |
| `access.text_size` | HUD numerals ignore it (fixed grid); banner words use `font_size_px(tier, step)`; banners are fixed plates, never scaled |
| `run.assisted` (from `game_speed_pct` assist) | PRACTICE tag 12x12 per column |
| `access.effects_level`, `background` | HUD unaffected; layer modulate stays 1.0 (HUD never dimmed by background dim) |
| HUD scale | **Not adopted** (Accessibility Rule 20). Substitutes: high contrast, Pause status panel, near-plane bar |

### Contrast ratios (against Cabinet Char `#1E1B18`, WCAG relative luminance, computed 2026-11-03; art pass must re-verify)

| Colour | Use | Ratio | Verdict |
|---|---|---|---|
| Cream `#F4EBD6` | Phase tick, countdown, `NN%`, team tag | about 14:1 | Pass |
| Ember Gold `#FFC93C` | Score, chain count | about 11:1 | Pass |
| Amber `#FFB000` | Enrage, WARNING bands | about 9:1 | Pass |
| Alarm Red `#E03A3E` | End-cap, underline, boss fill | about 3.1:1 | Graphic only (3:1); never text. Every red cue has a shape (end-cap, underline, notch) |
| Dim `#5A5148` | Ghost digits, dim score, unlit lamp | about 2.2:1 | Below 4.5:1 by design (inactive state); the HIGH contrast setting lifts it to `#A89E8A`, about 6.5:1. Advisory: in STANDARD the Continue-dim score is hard to read (Open Question 17) |

### Colour-vision variants

`access.player_palette` LUMA_SPREAD remaps the four slot colours to spread luma; the HUD never relies on colour alone: pip count (1-4), ring pattern (solid / dashed / dotted / double) and column position stay fixed. Gold vs Cream vs Amber differ by position and shape, not hue alone. Red cues are paired with shape (end-cap, underline, notch, corner ticks). HUD tested in grayscale (UX-06).

### Screen reader and announcements

Out of scope by decision (`accessibility-requirements.md` section 4): no TTS or screen reader for in-field gameplay. The HUD has no dialogue, so subtitles do not apply. Sound twins for HUD events (extend, milestone, Continue ticks, Warning siren) are Audio's; the visual forms are the twins.

### Non-colour backups

Non-colour backups: player identity = pips + ring pattern; chain danger = end-cap shape; kit ready = notch shape; boss critical = notch; last life = underline + single icon / `1`; bomb busy = 60% dim (shape unchanged); armed = corner ticks.

---

## Localization Considerations

| Topic | Rule |
|---|---|
| Language of HUD labels | Single-language per the style guide, but the fight HUD has **no word labels**: icons and numerals only. Only banners are dual-script (Bengali above Latin, equal weight) |
| Digits | Bengali `০-৯` or Western `0-9` follow the chosen language; both sets share one fixed grid per tier; grouping is Western `,` |
| Digit tiers | D24 (cell 15, sep 6), D17 (11, 4), D16 (10, 4), D12 (8, 3), D10 (6, 2). Cell = `ceil(0.6 x h)`, sep = `round(0.4 x cell)` |
| Worst-case widths | D17 score 107; D12 score 78; D24 chain 45; D16 chain 30; D10 `100%` 24; D12 `+5,000` 43; `+100,000` 59; `+3,047,000` 70 (HF6) |
| Bengali size rule | Style guide: 17 px minimum for Bengali text. D12 and D10 digits are below that; digits have no matra or conjuncts, so accepted pending the font spike (GDD OQ 1; fallback widen 2P/3-4P score to D16/D17) |
| Banner text | Bengali 34 px over Latin 24 px (WARNING). Reserve +40% width, +25% height. Never clip top 2 px / bottom 3 px of Bengali, and **reserve 4 px above the matra line** (art bible 7.5; the 2/3 px figures are clip *floors*, the 4 px is the layout *reservation* - see `arcade-ui-style.md` 2.2). Line height 1.4 Bengali, 1.2 Latin. No tracking, no faux bold. Word-wrap only at word boundaries |
| Banner width budgets (px, layout-critical) | Limits are in pixels because Bengali and Latin glyph widths differ; character counts follow from Localization's font metrics (open, Open Question 18). CRITICAL BREAK plate 300 px wide: text line at most 284 px (8 px padding). WARNING plate: its width is set by GDD art; text line must fit with the +40% expansion rule, i.e. the English source line is at most 1/1.4 of the plate's text width. Boss name plate: text at most 328 px per line (canvas 360 minus 16 px plate padding minus 16 px canvas margin), two lines, plate height = measured text + 8 px. Heights: Warning 34 x 1.4 + 24 x 1.2 = 76.4 px of the 80 px plate (no further height growth allowed) |
| Numerals | No translated strings in the fight HUD, so the 40% expansion applies to banners only. Digit fields never grow (HF6 widths) |
| Conjunct check | `ক্ষ`, `শ্রী`, `ঙ্গ`, `ত্র` legible at 1x in banners (GDD AC-53) |
| Fixed strings | `P1`-`P4` and key names stay Latin; HUD column shows pips and pattern, not "P{n}" text (see Open Question 9) |
| Switch behaviour | Layout rects never move; missing atlas cell falls back to the Western digit with one warning |
| Localization keys used | `banner.warning`, `banner.critical_break`, `boss.<id>.name` only; `join.prompt` is not drawn |

---

## Acceptance Criteria

Pass/fail by a tester using a debug "force N / lives / chain / award / banner" panel (GDD UI Requirements) or scripted snapshots. Numbers are GDD defaults.

| # | Layout / area | Criterion | GDD AC |
|---|---|---|---|
| UX-01 | 1P layout | At N=1 the strip is 48 px tall; score right-aligned in (45,0,107,19) shows `999,999,999` without clipping; lives show 5 icons plus `+1` at lives 6; the chain plate sits at (262,1,96,34) | AC-06, AC-15, AC-29 |
| UX-02 | 2P layout | At N=2 the strip is 48 px; two plates face each other at x 83 and 181; lives and bombs show icon + digit; one boss bar is shared | AC-06, AC-07 |
| UX-03 | 3-4P layout | At N=3 or 4 the strip is 72 px and four columns start at x 0, 90, 180, 270; slot 2 Empty shows a join plate in column 2 and the other columns do not move | AC-06, AC-07 |
| UX-04 | Compact | With 48 px latched, a third slot Selecting shows the 84x44 pick plate in column 2 of four 90 px columns; the strip stays 48 px and no Alive chain plate is covered | Rule 23 |
| UX-05 | Latch | A 2P -> 3P join mid-wave changes the strip to 72 px at the next `wave_started`, mid-boss at the next stage; a Continue slot never changes the mode | AC-06 |
| UX-06 | Identity | In a grayscale 4P screenshot a tester names each column's player, lives and chain state in at least 8 of 10 trials; pip counts 1-4 and patterns solid / dashed / dotted / double are unique | AC-08, AC-52 |
| UX-07 | Field rule | During a 4P boss fight with 300 bullets, no HUD pixel is drawn below `play_top` except banners; no score number ever appears over the field; no HUD node is parented to a plane, bullet or enemy | AC-09, AC-10 |
| UX-08 | Chain plate | At `window_left` 60 / 30 / 16 / 15 the bar is 94 / 47 / 26 / 24 px with the Alarm Red end-cap only at 15; bar never drops more than 2 px per tick; a drop at 187 leaves a dim `187` ghost until the next counted hit | AC-17, AC-21 |
| UX-09 | Boss row | With bar_permille 595: fill 185 px, phase tick 184, notch 27, text `60%`. Part kill shows icon + count for 90 ticks. Enrage shows Amber icon and `20` counting down | AC-39, AC-42, AC-43 |
| UX-10 | Banners | With 12 bullets alive the WARNING waits; it starts the tick bullets reach 0; if never clear it is skipped at tick 180 with Amber stripes in the boss row for 150 ticks. Block top is y 280 at `play_top` 48 and 292 at 72 | AC-45, AC-46 |
| UX-11 | Continue | STANDARD: a slot at `continue_remaining` 3.8 shows `4`, bar 36 px (1-2P); at 2.5 s the bar is 24 px with the red cap; accept shows score 0; expiry shows the join plate. EXTENDED (30 s): at 14 s the countdown shows `14`, bar 44 px, red cap from 7.5 s (24 px) | AC-37 (extended) |
| UX-12 | Pause / Tally | While paused, 120 frames produce no animation change; the owner column has a steady 2 px slot-colour frame. In Tally mode no strip pixel is drawn (including the 1P portrait, whatever its pose); the strip returns at the next `stage_started` | AC-04, AC-38, Tally |
| UX-13 | Accessibility | With `reduce_pulsing`, `reduce_flashing` and `reduce_motion` on, over a 3,600-tick scripted run no element pulses, no sparkles appear, the score snaps, and no element changes luminance faster than 1 Hz | AC-14, AC-49, AC-50 |
| UX-14 | Language | Switching English <-> Bengali mid-run changes digit shapes only; every rect keeps its position; conjuncts in banners are legible at 1x on REF-PHONE | AC-11, AC-53 |
| UX-15 | Resolution | At 1080x1920 (x3), 720x1280 (x2) and 360x640 (x1) the strip occupies exactly 48 / 72 canvas px; at 1080x1920 no bullet pixel is drawn above y 72 canvas px in a 4P screenshot; no text is clipped by the 1 px outline | AC-09 |
| UX-16 | Performance | 4P scripted run, 10,000 ticks, 300 events per tick: `HudModel.tick()` at most 0.05 ms p99 with no allocations after warm-up; view redraw at most 0.30 ms p99; at most 24 HUD draw calls per frame; idle for 600 ticks issues 0 numeral redraws | AC-54, AC-55 |
| UX-18 | Continue, UNTIMED | UNTIMED with another slot Alive shows the 30 s countdown and bar; UNTIMED with no other slot Alive shows the accept glyph only (no digits, no bar, no red cap); when the last other player dies the countdown appears at the value Session reports | Accessibility AC-35 |
| UX-19 | Strip mark | For each element id in each mode, all brackets lie inside x 4..359 (P2 in 2P: up to 355), y 0..36 (48 px strips) or 0..59 (72 px); none touches the pip stack, identity line or boss row; arms are 4 px; the mark ends after exactly 180 unpaused ticks. Example: 1P `chain_plate` top brackets at y 0 | Tutorial Rule 21 |
| UX-20 | Portrait | 1P: `player_died` -> hurt for 120 ticks, then determined if a boss fight is on else neutral; `boss_intro_started` -> determined; `boss_defeated` -> neutral; no victory pose is ever drawn by the HUD | AC-32 (amended) |
| UX-21 | Degraded | After dropping all events for 60 ticks, one snapshot re-syncs score, lives, bombs, chain and boss bar; a missing system leaves its element blank with no player-visible error; a kit with `den = 0` draws 0 px and logs one warning | AC-05, AC-35 |
| UX-22 | Pick plate | With a 3-4P Selecting slot in column 3 during a boss fight, the right zone `NN%` (336,36,24,12) is fully visible; the pick plate does not cover an Alive chain plate | Rule 23 |
| UX-17 | Glyph / platform | With a pad connected the join plate shows that pad family's START glyph; a pad swapped for keyboard redraws the glyph within one tick; on a touch-only phone the layout is 1P and the touch strip does not move the canvas | Rule 23, Touch |

---

## Open Questions

Carried from the GDD (still open), then new findings. Items marked **(proposal)** are not binding until a GDD changes.

| # | Question | Owner | Source |
|---|---|---|---|
| 1 | ~~**Victory portrait is unreachable.**~~ **Resolved here 2026-11-03:** the HUD has no victory pose; `stage-tally.md` already draws a 96x96 victory portrait in the 1P hero block. GDD Rule 22 / AC-32 now read `boss_defeated -> neutral` with no victory pose in the HUD (**amendment applied 2026-11-03, wave 5**). | game-designer, Tally owner | Closed |
| 2 | **Touch join plate.** In 1P on a touch-only platform the join plate offers a START glyph, but touch play is solo only and cannot join others. **(proposal)** Hide the 1P join plate on touch. | ux-designer, Touch owner | New |
| 3 | ~~**Join plate pulse.**~~ **Closed 2026-11-03:** `arcade-ui-style.md` and P09 corrected to the GDD: the HUD join plate is icon-only and steady; the text plate with a pulse is Lobby-only. | ux-designer | Closed |
| 4 | ~~**Continue timer vs HF2.**~~ **Resolved here 2026-11-03:** bar scale and red threshold use the active total `T` (see Continue plate); two-digit countdown fits D24; UNTIMED follows Accessibility Rule 22. **Amendment applied 2026-11-03 (wave 5):** Session now publishes `continue_total` (F4, nullable) and HUD HF2 / Rule 24 / Rule 34a(c) / AC-37 + new AC-37b use it. | Session, Accessibility | Closed |
| 5 | **WARNING stripes vs `reduce_motion`.** Accessibility lists Warning under `reduce_motion`; the HUD GDD only covers `reduce_pulsing`/text. Proposal: static stripes and cut in/out with `reduce_motion`. | ux-designer, Accessibility | Conflict |
| 6 | **Near-plane bar breaks "nothing over the field".** It is an opt-in layer-7 element (Accessibility Rule 20). Confirm the Visual Budget exception is acceptable. | art-director, Accessibility | New |
| 7 | **Switch TV overscan and Web safe area.** Display GDD ignores safe area on Switch/Web; unverified whether a TV or embedded page can crop the strip edges. | Display owner | New |
| 8 | **Chip under `reduce_motion`.** GDD does not say whether the boss chip catch-up (18 ticks) snaps. **(proposal)** Snap. | ux-designer | New |
| 9 | ~~**"P{n}" text on the HUD.**~~ **Resolved 2026-11-03 (wave 5):** `arcade-ui-style.md` **3.1** (there is no "G3") requires "P{n}" only where a text label fits; the HUD column (GDD Rule 8) is **exempt** and identifies slots by colour, ring pattern and pips. Re-open only if the art-director wants a 5 px label. | ux-designer, art-director | Closed |
| 10 | ~~**Banner timing vs CB.**~~ **CLOSED 2026-11-03 (wave 5 batch 2).** `critical-break.md` now retires `cb_banner_wait_max` everywhere - F5, its variable and tuning tables, the defaults list and AC-44 all read HUD's `banner_wait_max` = **180**, and a stray CB key must fail the data lint. The WARNING pulse half was already applied (1 Hz, GDD Rule 31, HF9). | — | Closed |
| 11 | ~~**Continue during Tally.**~~ **Answered by Tally Rule 17:** a slot in Continue at tick 0 gets a dim Tally column "CONTINUE n" with the countdown, and Fire accepts (see `stage-tally.md` States). The HUD stays hidden. | Tally | Closed |
| 12 | ~~**Kit bar width W.**~~ **Closed 2026-11-03 (wave 5):** GDD HF4 now lists W = 14 for the compact 48 px column form (notch at 5). | HUD GDD owner | Closed |
| 13 | ~~**Start button: Continue accept vs Pause.**~~ **CLOSED 2026-11-03 (wave 5 batch 2).** `CONTINUE_ACCEPT` is **Fire** (Input Rule 24b), the same verb on the HUD plate and in the Tally column; **Start stays Pause** and never accepts, so no priority rule is needed. HUD GDD Open Question 10 is closed with the same wording. | — | Closed |
| 14 | D12 / D10 Bengali digit legibility; 3-4P strip readability at 1x on REF-PHONE; bright Gold `#FFE27A` palette entry; tag-in-plate acceptance (Co-op V1); 2P idle join prompt; MAX icon comprehension; lives total vs spare lives; 1P kit bar row y 36 cramped. | art-director, ux-designer, game-designer | GDD OQ 1, 2, 3, 4, 6, 8, 12, 14 |
| 15 | ~~Stale text in the GDD: AC-45 `warning_requested`; AC-13 tick 36.~~ **Closed 2026-11-03 (wave 5):** AC-45 now reads `warning_started` and AC-13 reads tick 32 (HF1 Output Range). | HUD GDD owner | Closed |
| 16 | **Part-kill cue overlap.** GDD is silent when a second part dies within 90 ticks. Proposal: restart the 90 ticks showing the current parts left. | Boss owner, ux-designer | New |
| 17 | **Dim text at STANDARD contrast.** `#5A5148` on Char is about 2.2:1, so the Continue dim score (what a Continue wipes) is hard to read unless HIGH contrast is on. Consider `#7A6F60` or similar for the dim score only. | art-director | New (advisory) |
| 18 | **Banner character limits.** Pixel budgets are set (Localization section); character counts need Localization's font metrics and the WARNING plate width. | Localization, art-director | New |
| 19 | **Strip mark over neighbours.** The clamp rule lets a mark overdraw adjacent elements by up to 2 px for 180 ticks. Confirm Tutorial and art-director accept this versus shrinking the arms. | Tutorial, art-director | New |
| 20 | ~~**Pick plate corner.**~~ **Closed 2026-11-03 (wave 5):** HUD GDD Rule 23 and the Compact 48 layout table state the draw order (boss zones above the plate, bottom outer 19x10 corner clipped in columns 0 and 3), and Menus Rule 52 now carries the keep-out requirement for the cursor and all labels. | Menus owner | Closed |
| 21 | ~~**DONE / SKIPPED stamp rect.**~~ **CLOSED 2026-11-03 (art-director).** See "DONE / SKIPPED stamp" in Layout Zones: 16x11 at (224,4) in 1P and (73,16) per column in 3-4P; **no room in 2P or Compact 48**, where the stamp is suppressed from the strip and per-slot completion must come from the Flight School / Tutorial surface. **Amendment APPLIED 2026-11-03 (final doc closeout):** `design/gdd/hud.md` Rule 30b now carries the stamp asset spec and the `HudLayout` `stamp` rects, the 1P / 2P / Compact 48 / 3-4P layout tables each carry a `stamp` row, Rule 9 and AC-03 lint the key, and new AC-28b asserts the draw. The 2P / Compact 48 fallback is confirmed by `design/gdd/tutorial.md` **Rule 16a**: the Flight School surface shows a per-slot result row there. | HUD GDD owner, Tutorial (30) | **Closed and applied** |
