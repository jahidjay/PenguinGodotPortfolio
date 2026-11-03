# HUD

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (ux-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos, Every Hit Counts (also Four Planes, Four Games for the per-plane kit bar)
> **Revision 2026-11-03 (final doc closeout, art-director amendment A4)**: `HudTheme` (Rule 33) now names both reds explicitly - `ALARM_RED #E03A3E` fill-only, `ALARM_FLARE #F2494D` text-only and never drawn in the strip, a slot column or the field.
> **Revision 2026-11-03 (final doc closeout, art-director amendment A1)**: Rule 30b now carries the DONE / SKIPPED stamp asset spec and the `HudLayout` `stamp` rects (1P (224,4,16,11); 3-4P (73,16,16,11) per column; `stamp = none` in 2P and Compact 48), with the AC-03 lint clause and new AC-28b.
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: `CONTINUE_ACCEPT` resolved to **Fire** with Start staying Pause (Rule 24, Open Question 10 closed).
> **Revision 2026-11-03 (UX amendments wave 5)**: victory portrait moved to the Stage tally (Rule 22, AC-32); Continue bar uses `continue_total` with the EXTENDED/UNTIMED variants (HF2, Rules 24 and 34a(c), AC-37/AC-37b); strip-mark clamp rect (Rule 30a); pick plate versus boss-row zones (Compact 48 layout table, Rule 23); one `CONTINUE_ACCEPT` verb (Rule 24, Open Question 10); Warning text pulse 1 Hz; HF4 compact bar width W = 14; stale AC-45 event name and AC-13 tick count fixed.

## Overview

**The data layer:** the **HUD** is a read-only presentation system. It draws everything the player reads that is not in the play field: score, lives, bombs, drones, kit bar, chain plate and window bar, team-chain bracket and lamps, boss bar, join and Continue plates, plus the transient banners (Warning, boss name plate, Critical Break). It owns no gameplay state. Each tick a node-free `HudModel` (`RefCounted`, `tick()`) takes a read-only snapshot of Session, Chain, Scoring, Co-op, Kits, Bombs, Boss and Input data plus the events of that tick, and updates **display state** only (shown score, chip positions, animation counters). A thin view node draws that display state from a pre-outlined digit atlas, into a **reserved top strip** that is outside the play field (48 px for 1-2P, 72 px for 3-4P, at the fixed 360x640 canvas). The layout is data (`data/ui/hud_layout_*.tres`), chosen by player count.

**The player impact:** the player should be able to read their run in a half-second glance without taking their eyes off the bullets: how many lives and bombs they have, how long the chain will live, whether the boss is nearly dead, and who in a 4P game is in the team chain. The strip never covers a bullet, never flashes, and never moves anything over the field. A language switch changes the digits (Bengali or Western) but never the layout. Without it, the chain system, the team bonus, and the "I dropped it at 187" feeling that **Every Hit Counts** promises have no face.

## Player Fantasy

**Anchor moment: the glance.** Mid-curtain, the player's eyes flick up for 200 ms. They learn three things without reading: the chain bar is short and has a red tip (keep hitting), the boss bar is under 40 %, and they have one life left (the icon is steady and underlined). Their eyes drop back to the lane. The HUD gave them everything and cost them nothing.

What makes that feeling possible:
- **Quiet and fixed.** The strip is a cabinet bezel: plated, opaque, the same shape from 1P to 4P, so muscle memory carries. Only the chain plate is large.
- **Shape and number before colour.** Every meaning has a shape, count or pattern backup (the 4 ring patterns, pips, the 40 % notch, the red end-cap, the dimmed bomb row).
- **Honest numbers.** The chain count, the window bar and the boss percentage are exact. The bar drains in visible steps, not a blur.
- **Co-op identity.** In a 4P screenshot the player finds "their" column by colour, pip count and border pattern, even when two colours have the same brightness.
- **Never in the way.** No score numbers float over the field. No screen flash comes from the HUD. Banners appear only when the field is clear of enemy bullets.

**Anti-fantasy (must never happen):** a score popup over the bullets; a bar that blinks; a HUD that changes shape when the language changes; a player who cannot tell which column is theirs; a boss bar that is the only large red on screen but sits in the play field; text too small to read in Bengali.

> `creative-director` and `art-director` not consulted (auto-approve). Sizes below extend art bible §7 and are proposals until the §7.2 layout spike (Open Questions 1, 2).

## Detailed Design

### Core Rules

**Role and boundaries**

1. The HUD is **read-only**. It never writes to Session, Chain, Scoring, Kits, Bombs, Boss, Co-op or Input. It requests nothing from gameplay. Its only outward calls are to Localization (`format_int`, `text_both`, `font_size_px`), to Input (glyph lookup), and its own signals (`hud_ready`, `banner_finished`). *(Rule fits ui-code: UI never owns state.)*
2. **Logic and view are split (ADR-0001).** `HudModel extends RefCounted` holds all display state and runs `tick()` at 60 Hz on the integer tick counter. It has no `delta`, no `randf`, no Node access. A view node (`HudView`, a `CanvasLayer` child) reads `HudModel` and draws. The model is unit-testable headless with scripted snapshots and events.
3. **Tick order.** The HUD ticks **after** all gameplay systems of the same tick (Collision, Chain, Scoring, Boss, Kits, Bombs, Co-op). It sees the final values of tick T. It never reads the state of tick T+1. Events that arrive during tick T are queued and consumed in the HUD tick of T, in arrival order.
4. **The HUD ticks only with the game.** While the game is paused the model does not tick, so every animation freezes in place (Pause: Rule 22).
5. **Pull for state, push for transitions.** Continuous values (score, lives, bombs, drone count, kit bar, chain count, window left, boss permille) are sampled from the snapshot each tick. One-shot reactions (gain, milestone, drop, multiply, award, part kill, extend, death, enrage) come from events. Missing an event must never leave the display wrong: after any event loss the next snapshot re-syncs every continuous value (animations may be skipped, numbers may not).

**Strip, layout and what lives where**

5a. **Strip height is set by the layout mode:** 1P and 2P use `play_top` 48; 3P and 4P use 72 (registry `play_top`). The strip is opaque Cabinet Char `#1E1B18`, drawn at draw slot 11 (art bible §6.8), inside the 360x640 canvas, never in the bezel. Bullets, enemies and planes are culled by their own systems at `play_top`; the HUD does not clip them.
6. **Layout mode** is `1P` when `N = 1`, `2P` when `N = 2`, `3-4P` when `N >= 3`, where `N` comes from Co-op (`coop_count_changed`). A slot in Continue still counts (Co-op Rule 3), so a Continue countdown never flips the layout. *(Amended 2026-11-03, wave 4: `play_top` is **latched** at `stage_started` and `wave_started` from the counted `N` (Co-op Rule 1, Player plane); the strip height and the layout mode follow the **latched** `play_top`, never the live `N`.)* Between latches the mode may change only inside the same strip height (1P ↔ 2P, both 48 px), on the tick `coop_count_changed` arrives. A change that needs another strip height (2P → 3P, 3P → 2P) waits for the next latch; during a boss fight (no `wave_started`) it waits for the next stage. Until then a third counted slot in 48 px mode uses the compact 2P column form (Rule 23), and a 72 px strip keeps its four fixed columns. There is no transition animation: the field bounds and the strip move together on the latch tick. Gameplay never reads the HUD display mode.
7. **Slot to column.** 1P: the one counted slot fills the single column. 2P: the two counted slots, in slot order, left then right. 3-4P: four fixed columns, column `c` = slot `c` (P1 to P4). A slot that is Empty, Inactive or Selecting in a 3-4P column shows a **join plate** (Rule 23). In 1P and 2P there is no empty column.
8. **Identity block (every column, every mode).** The column's outer edge carries the player identity from art bible §4.4:
   - a **pip stack**: 1 to 4 blocks of 3x3 px in the player colour (P1 1 block, P4 4 blocks), 1 px apart, starting at y 2;
   - an **identity line**: a 1 px vertical line in the player colour next to the pip stack, running the height of the column's rows, drawn in that player's **ring pattern** (solid, dashed 4 on 2 off, dotted 1 on 2 off, double = two parallel lines: the line plus a 1 px bar at the outer edge);
   - the player colour is never used alone: pips and pattern are always drawn (P3 and P4 have equal luma).
9. **Element rects are data.** Every rect in the tables below lives in `data/ui/hud_layout_1p.tres`, `hud_layout_2p.tres`, `hud_layout_34p.tres`, `hud_layout_compact48.tres` (type `HudLayout`). Code never hard-codes a coordinate. A layout lint (AC-03) checks that no rect leaves the strip, that no two rects of one column overlap unless marked `shares_lane`, and that every text rect holds its worst-case string (Formula HF6). The lint also requires every layout to carry a `stamp` key (Rule 30b): where it is a rect it must overlap no other element rect in its layout; `stamp = none` is a valid explicit value and a missing key is a failure.

**Layout tables (canvas px at 1x; rect = x, y, w, h)**

*1P (strip y 0-47, one column, origin x 0)*

| Element | Rect | Numeral tier / size | Notes |
|---|---|---|---|
| Identity line / pip stack | (3,0,1,36) / (0,2,3,15) | | Slot colour and pattern |
| Pilot portrait | (5,0,36,36) | | 36x36, expression set from art bible §5.9 |
| Score | (45,0,107,19) | D17 (cell 11, sep 4) | 9 digits + 2 separators = 107 px, right-aligned, Ember Gold |
| Lives icons | (45,19,78,14) | 14x14 icons, 2 px gap | Up to 5 shown |
| Lives overflow `+N` | (123,20,16,14) | D12 | Only when lives > 5 |
| Bomb icons | (143,19,78,14) | 14x14 icons, 2 px gap | Up to 5 shown |
| Kit bar | (45,33,78,4) | | Its last row (y 36) is Row B's margin row |
| Drone pips | (226,22,19,6) | 4x6 ticks, 1 px gap | 4 slots, filled = drone present |
| Drone lamp | (247,22,5,5) | | Lancer and Breaker; Sentry shows the recall glyph in the same rect; hidden at 0 drones |
| MAX tag | (246,5,12,8) | icon | Cap-hold streak at full rate |
| DONE / SKIPPED stamp | (224,4,16,11) | 16x11 asset | Rule 30b. 4 px to the join plate (ends x 219), 6 px to MAX (starts x 246), 7 px above the drone ticks (y 22), 22 px to the chain plate |
| Join plate (next free slot) | (156,1,64,16) | START glyph 16x16 + pips | Only while a slot is free |
| Chain plate | (262,1,96,34) | D24 (cell 15) | See "Chain plate" |
| Boss bar (outer) | (24,37,312,10) | | Interior 310 px (Formula HF3) |
| Boss row left zone | (0,36,24,12) | D10 (cell 6) | Enrage icon + seconds left |
| Boss row right zone | (336,36,24,12) | D10 | `87%` or part-kill icon and count |

*2P (strip y 0-47, two columns; P1 column given, P2 cluster = P1 cluster + 272 px, P2 plate at x 181, P2 identity at the right edge: line x 356, pips x 357-359)*

| Element | P1 rect | Tier / size | Notes |
|---|---|---|---|
| Identity line / pip stack | (3,0,1,36) / (0,2,3,15) | | |
| Score | (5,1,78,14) | D12 (cell 8, sep 3) | 9 digits + 2 seps = 78 px exactly |
| Lives icon + count | icon (5,16,14,14), digit (19,16,8,14) | D12 | Counter form (Rule 13) |
| Bomb icon + count | icon (30,16,14,14), digit (44,16,8,14) | D12 | |
| Drone pips / lamp | (56,19,19,6) / (76,19,5,5) | | |
| Kit bar | (5,31,78,4) | | |
| Chain plate | (83,1,96,34); P2 (181,1,96,34) | D24 | Inner side. 2 px between plates |
| DONE / SKIPPED stamp | `stamp = none` | - | Rule 30b. No free 16x11 block exists in a 2P cluster; the in-strip stamp is suppressed and the Flight School surface carries per-slot DONE / SKIPPED (tutorial.md Rule 16a) |
| Boss bar, zones | as 1P | | One bar for the strip |
| Team bracket | y 0, x from plate centre to plate centre | | See Rule 18 |

*Compact 48 px column form (added 2026-11-03, consistency check; Rules 6, 23, decision D3). Used only while `play_top` is latched at 48 and a third or fourth slot is Selecting or counted (until the next latch). Strip y 0-47, four fixed columns of 90 px, column `c` = slot `c`, origin `90c`; coordinates relative to the column origin. An unused column is blank (no join plate).*

| Element | Rect | Tier / size | Notes |
|---|---|---|---|
| Identity line / pip stack | (3,0,1,34) / (0,2,3,15) | | Rows A-B |
| Score | (5,0,85,14), right-aligned | D12 | 9 digits grouped = 78 px |
| Lives icon + count | icon (5,16,11,11), digit (17,16,6,12) | 11x11 icon, D10 | Counter form |
| Bomb icon + count | icon (24,16,11,11), digit (36,16,6,12) | D10 | |
| Drone pips / lamp | (5,29,15,5) / (21,29,5,5) | 3x5 ticks | |
| Kit bar | (28,30,14,4) | | 40 % notch at x 33 |
| Chain plate | (44,14,46,22) | D16 (cell 10) | Count 30 px; window bar `BAR_PX` 42, 4 px, plate bottom |
| DONE / SKIPPED stamp | `stamp = none` | - | Rule 30b. The 90 px column is packed to y 35; the in-strip stamp is suppressed and the Flight School surface carries per-slot DONE / SKIPPED (tutorial.md Rule 16a) |
| Team bracket | y 14 | | Plate tops |
| Pick plate (Selecting slot) | (5,2,84,44) | Menus 84x44 | Replaces the column's cluster while Selecting; `shares_lane` with the boss row (hides the boss **bar** under it only). The boss row's **zones** (0,36,24,12) and (336,36,24,12) draw **above** the plate, so in columns 0 and 3 the plate's bottom outer 19x10 corner is clipped (Rule 23) |
| Boss bar, zones | as 1P (24,37,312,10); (0,36,24,12), (336,36,24,12) | D10 | One bar for the strip |

*3-4P (strip y 0-71, four columns of 90 px, column `c` origin `90c`; coordinates below are relative to the column origin)*

| Element | Rect | Tier / size | Notes |
|---|---|---|---|
| Identity line / pip stack | (3,0,1,60) / (0,2,3,15) | | Rows A-C |
| Score | (5,1,85,14), right-aligned | D12 | 9 digits grouped = 78 px |
| Lives icon + count | icon (5,17,11,11), digit (17,16,6,12) | 11x11 icon, D10 | Counter form |
| Bomb icon + count | icon (26,17,11,11), digit (38,16,6,12) | D10 | |
| Drone pips / lamp | (48,19,15,5) / (65,19,5,5) | 3x5 ticks | |
| Kit bar | (5,28,82,4) | | |
| Chain plate | (5,33,84,26) | D16 (cell 10) | |
| DONE / SKIPPED stamp | (73,16,16,11) per column | 16x11 asset | Rule 30b. Absolute x 73 / 163 / 253 / 343, y 16. 3 px to the lamp (ends x 69), 1 px under the score row, 1 px above the kit bar (y 28), 1 px to the next column |
| Team bracket | y 32 | | |
| Boss bar | (24,61,312,10) (absolute) | | Row D; zones (0,60,24,12) and (336,60,24,12) |

**ASCII mock-ups** (schematic, 1 char = about 4 px wide and 4 px tall; the rect tables win over the drawings). `#` = pip stack, `:` = identity line, `[..]` = plate or field, `o` = icon, `|` on the kit bar = the 40 % notch, `^` = Alarm Red end-cap, `=` = bar fill.

1P (360x48):
```
#:[PORTRAIT][ 123,456,789  score D17 ]  [START]#            [MAX]   .--------------------.
#:[  36x36 ][                         ]                             | +50   x3       187 |
#:[        ][ o o o o o +N ]  [ o o o o o ]  ||||  [L]              | ################^  |
#:[        ][ ===|======== kit ]                                    '--------------------'
  [E 20]  [==============================  boss bar  ======================] [87%]
```
2P (360x48; P2 mirrors the cluster to the right, plates face each other, bracket on top when a team chain runs):
```
#:[123,456,789 D12   ] .------------. .------------. [123,456,789 D12   ]:#
#:[o 3   o 2 |||| [L]] | +20  187  | | +20  244  | [o 2   o 3 |||| [L]]:#
#:[===|========= kit ] | ########^  | | ########  | [===|========= kit ]:#
  [E]  [=====================  boss bar  =====================]  [87%]
```
4P (360x72; the 3P game shows slot 3's column as a join plate; the identity line runs rows A-C):
```
#:[ 1,234,567 ]  #:[   987,654 ]  #:[ 3,100,200 ]  #:[ START + pips ]
#:[o3 o2 || ]    #:[o2 o1 || ]    #:[o3 o0 || ]    #:[   join plate  ]
#:[==|======]    #:[==|=======]   #:[==|=======]   #:[               ]
#:.----------.   #:.----------.   #:.----------.    #:.--------------.
#:| +30  187 |   #:| +30   64 |   #:| +30  412 |    #:|              |
#:| ########^|   #:| ######## |   #:| ######## |    #:|              |
  [E]  [===============  boss bar  ================]  [87%]
```

10. **Reserved lanes inside a chain plate.** A plate has a left **lane** (free of digits) that is shared in this priority order: award takeover or `+N` award > `xN` popup > team tag > MAX tag. The lane is x +1 to +43 in 1-2P (43 px) and x +1 to +46 in 3-4P (46 px), relative to the plate's left edge. In 3-4P the team tag (37 px) and the MAX tag (8 px) sit side by side (37 + 1 + 8 = 46). In 1-2P the MAX tag sits beside the plate (1P) or stacks under the team tag (2P).
11. **What is in the strip and what is in the world.** Everything above is in the strip. The only things the HUD draws in the play field are the **transient banners** (Rule 26) and nothing else. The 2 s spawn pip tag over a plane belongs to Player plane (V5), not to the HUD. No HUD element is attached to a moving entity.

**Numerals**

12. **All numbers come from the digit atlas.** The HUD never builds a number string itself. It asks `Localization.format_int(n)` (Western 3-digit `,` grouping in both languages) and maps each character to an atlas cell with the Localization cell map. Digits follow the chosen language (Bengali `০-৯` or Western `0-9`); both sets share one fixed grid per tier, so a language switch never shifts a rect. Tiers (digit height / cell / separator / glyph box incl. 1 px outline):

    | Tier | Digit height | Cell | Sep | Glyph box height | Used for |
    |---|---|---|---|---|---|
    | D24 | 24 | 15 | 6 | 26 | Chain count, 1-2P; Continue count 1-2P |
    | D17 | 17 | 11 | 4 | 19 | 1P score |
    | D16 | 16 | 10 | 4 | 18 | Chain count, 3-4P; Continue count 3-4P |
    | D12 | 12 | 8 | 3 | 14 | 2P and 3-4P score; 2P counters; award tags; team `+NN`; `+N` overflow |
    | D10 | 10 | 6 | 2 | 12 | 3-4P counters; boss row (`%`, seconds, part count) |

    Cell and separator follow Localization F3 (`cell_w = ceil(0.6 x h)`, `sep_w = round(0.4 x cell_w)`). D12 and D10 are **HUD digit tiers added here** (Open Questions 1, 2).
13. **Counter form and icon form.** Lives and bombs are shown as **icons** (14x14, up to 5, 2 px gap, overflow `+N`) in 1P, where there is room. In 2P and 3-4P they are shown as **one icon plus a count** (14x14 and D12 in 2P, 11x11 and D10 in 3-4P). Both forms show the same data. Lives show the Session `lives` value (the plane in flight counts as one life); the last-life cue is `lives == 1`.
14. **Fields are right-aligned, tabular, no leading zeros.** A field always keeps the ones digit at the same x. A value of 0 shows `0`. The score display is clamped to 999,999,999 (Scoring F8).
15. **Only redraw on change.** The model keeps the last drawn value of each numeral field and calls `format_int` only when the shown value changes (Localization AC-40: 0 calls over 600 ticks with a constant score). On `Localization.language_changed(code)` (a signal on the `Localization` autoload, **not** on `GameEvents`) every numeral field is marked dirty and redrawn within one frame.

**Score**

16. **Score roll.** The shown score follows the true score (Scoring `display_score`, clamped) by Formula HF1: gaps of `score_roll_instant_max` (5,000) or less snap on the next tick, so ordinary hits, kills and items feel instant. Larger gaps (parts, boss, Critical Break) roll up geometrically and reach the target in about 32 ticks. A drop in score (a Continue wipe) snaps at once. With `access.reduce_motion` the roll is off and the score always snaps.

**Chain plate (all modes)**

17. **Chain plate.** A chamfered rectangle: Cabinet Char `#1E1B18` fill, 1 px `#5A5148` edge with a 1 px 20 % era tint (art bible §7.8). Inside:
    - **Count**: `count` (0 to 999) in Ember Gold, tabular D24 (1-2P) or D16 (3-4P), right-aligned at plate x +88 (1-2P) or +76 (3-4P).
    - **Window bar**: full interior width, 4 px tall, Ember Gold on `#3A2A14`. Length `bar_px(slot, BAR_PX)` with `BAR_PX` = 94 (1-2P), 82 (3-4P) or 42 (compact 48 px form) (Formula HF2), so it drains by at most 2 px per tick. In the last 25 % of the window (`red`), a 1 px Alarm Red `#E03A3E` end-cap shows at the bar tip. No blinking, no whole-bar colour change.
    - **Gain (+1)**: the digits jump up 2 px for 2 frames, at most once per `chain_jump_min_gap` (12) ticks, so a laser stream does not make them buzz. The bar refills in 2 steps (HF2b). With `access.reduce_motion` the jump is off.
    - **Milestone (50 / 100 / 200)**: the plate edge steps and stays at the highest milestone reached in the current chain: below 50 `#5A5148`; 50 Cream; 100 Ember Gold; 200 bright Gold (`#FFE27A`, a new palette entry, Open Question 3) and a 2 px edge (the width is the non-colour backup). Sparkle pixels (4, from a fixed table, no RNG) cycle inside the plate for 12 frames. Digits never grow. With `access.reduce_flashing` the sparkles are off and only the edge step remains.
    - **Drop (`chain_dropped`)**: the digits fade to `#5A5148` and shift down 3 px over 4 frames (1, 2, 3, 3 px), clipped to the plate interior. The plate frame does not move (it cannot leave the strip). The last value stays as a dim **ghost** (`ghost_visible`, `last_dropped`) until the next chain starts. Before any chain, a dim `0` shows. The bar is empty.
    - **Hit-tick death**: the chain drops on the tick of the hit (Collision), so the plate drops on the same tick as the lives icon.
    - **`xN` popup** (`chain_multiplied`): in the left lane, `x3` in D24/D16 Gold for 60 ticks.
    - **Lamp**: a 2x2 px square at the top-right inner corner, 2 px inset (1-2P rect (+91, 4, 2, 2); 3-4P (+79, 36, 2, 2) in canvas y). Lit Ember Gold while the slot's `lamp_state` is lit; unlit `#5A5148`; a 1 px Gold outline during join grace. Shown only while a boss is alive and at least 2 slots are Active. Never blinks.

**Team chain (Co-op 18)**

18. **Bracket and tag.** While `team_chain_on` (boss fights only), a 1 px Ember Gold bracket links the member plates: in 1-2P a line at y 0 with 3 px down-ticks (y 0-2) at each member plate's centre; in 3-4P a line at y 32 with 3 px down-ticks (y 32-34). No flash, no pulse. Each **member** plate shows the tag in its left lane: a 12x8 two-chevron icon in Gold on Char, 1 px gap, then `+20`, `+30` or `+40` (= `team_pct - 100`) in D12 Cream with the outline (37 px). So a player finds who is in the team chain by which plates carry the tag. No Latin or Bengali text. *(Replaces Co-op V1's "8 px digits centred on the bracket"; Open Question 4.)*

**Per-plane panel**

19. **Kit bar.** A 4 px segmented bar, Tracer Orange `#FF8A1F` on Char, ticks every 25 %, filled length by Formula HF4. The data is `kit_bar(slot) = (num, den)` from the kit. Lancer adds a 2x4 px notch at 40 % (outline while not `kit_ready`, solid Cream when ready). Leech uses the same bar for its ability (no second gauge). The ready state is read from the notch shape, not from fill length. *(Added 2026-11-03, wave 4, plane-kits-sentry-breaker.md UI Requirements:)* **Sentry** uses the bar as its ability bar (like Leech: time left / 420 while ACTIVE, `1 - cooldown_left / 480` in COOLDOWN, full when READY). **Breaker** uses it as the **stock bar** (`stock / 60`; each bolt drops it by 2/60); `kit_ready` = `stock >= 2`.
20. **Drones.** Four 4x6 (1P, 2P) or 3x5 (3-4P) ticks, one per possible drone, 1 px apart: filled Cream for each drone owned (`drone_count`), outline for empty ones. A new drone fills its tick in 4 frames with a Gold edge step for 6 frames (pickup feedback, no field popup). On death all four empty on the death tick. Beside the ticks, the **drone lamp** (Lancer only, 5x5): solid Cream = READY; outline with a bottom-up fill = COOLDOWN; steady Cream with a shrinking underline = ACTIVE; hidden at 0 drones. The Leech shows no lamp. **Breaker** shows the same lamp with the Lancer states (READY / ACTIVE / COOLDOWN). **Sentry** shows a 5x5 **recall glyph** (arrow into a base) in the lamp rect: outline until `recall_available` (ACTIVE and at least 60 ticks since the press), solid Cream after; hidden at 0 drones (wave 4, Sentry/Breaker kits 29).
21. **Bombs.** Up to 5 icons, 14x14 plated Tracer Orange tiles with the bomb pictogram (11x11 in 3-4P). While `bomb_busy(slot)` the whole bomb display dims to 60 % opacity (shape unchanged). A spent bomb plays a 3-frame break; a refill adds one icon every 6 ticks. `bomb_denied(NO_BOMBS)` shakes the bomb display 2 px for 8 ticks (at most 2 Hz; off with `access.reduce_motion`). `bomb_denied(BUSY)` has no UI.
22. **Lives and the last life.** Icons are top-down plane pictograms in the player colour on Char tiles. A lost life plays a 3-frame break (Alarm Red tile on frames 1-2, then gone); there is no screen flash or tint. In 1P the portrait swaps to **hurt** from `player_died` for `portrait_hurt_ticks` (120), to **determined** from `boss_intro_started`, and back to **neutral** on `boss_defeated`; the **victory pose is drawn by the Stage tally** (96x96 hero portrait, `stage-end-tally.md`), **not by the HUD**, because the HUD is hidden in Tally mode. The HUD has no victory expression. When `lives == 1` and the slot is Alive: the lives display gets a steady 1 px Alarm Red underline (the non-colour backup is the single icon or the count `1`) and pulses within the allowed rule (Rule 31). Extend (`extend_awarded(slot, gained)`): `gained > 0` adds the new icons with a 12-frame Gold edge step and shows a `+gained` tag (D12, Gold, plate-local, in the plate lane) for 60 ticks; `gained == 0` (at `max_lives`) shows the **MAX icon** for 60 ticks on the lives display instead. *(Resolves Session Open Question 1.)*

**Join, Continue, pause**

23. **Join plate.** An Empty or Inactive slot shows a plate with the **START glyph** (16x16, glyph family of the pad that would join, from Input) and the pip stack of the slot that would be taken (colour and pips; the pattern line dim at 40 %). Text is not drawn (Open Question 5). A Selecting slot shows the same plate with a steady 2 px frame in the slot colour. In 1P one join plate for the next free slot shows in the free area of the score row while a slot is free. In 2P no join plate is drawn (no room; Open Question 6). *(2026-11-03, wave 3b, drop-in pick plate: while any slot is **Selecting** mid-run, the HUD uses the **next layout mode for display only** (1P → 2P layout, 2P → 3-4P layout), so the Selecting slot gets its own column; Co-op's `N` is unchanged (scoring, team chain and difficulty still use the counted slots). **Amended 2026-11-03 (wave 4):** the display layout must fit the **latched** strip (Rule 6): the strip height never changes for a pick. In 48 px mode the Selecting slot uses the **compact 2P column form** (a 1P run shows the 2P layout; a 2P run shows the new slot in the 2P column form beside the two counted columns); in 72 px mode it uses its fixed 3-4P column. The Menus 84x44 **pick plate** (plane cursor, Menus Rule 52) is drawn in that column inside the strip, never over the field and never over an Alive player's chain plate. **Draw order against the boss row (amended 2026-11-03, wave 5):** the plate hides only the boss **bar** under it; the boss row's left and right **zones** (0,36,24,12) and (336,36,24,12) draw **above** the plate, so in the outer columns (0 and 3) the plate's bottom outer **19x10 corner is clipped**. Menus must keep the plane cursor, the plane name and every label out of that corner (Menus Rule 52). The strip uses the displayed layout's registry height (48 / 72) only; there is no HUD scale (Accessibility 28 Rule 20). The display mode returns to the counted layout when the pick ends (lock-in or `dropin_pick_ticks` cancel).)* *(Rects added 2026-11-03, consistency check: the compact 2P column form is the "Compact 48 px column form" table above: four 90 px columns in the 48 px strip; the Selecting slot's column shows the pick plate; once that slot is counted it keeps the compact column until the next latch switches to 3-4P.)*
24. **Continue plate.** A slot in Continue replaces its chain plate with: the accept-button glyph (16x16, `action_glyph(slot, CONTINUE_ACCEPT)` from Input (2) in that slot's glyph family - **one verb shared with the Tally's Continue prompt**, so the HUD never hard-codes a button; *resolved 2026-11-03, wave 5 batch 2: `CONTINUE_ACCEPT` is **Fire** (Input Rule 24b), and **Start does not accept a Continue** - it still pauses, so there is no accept-versus-Pause priority to decide*), the `ceil(continue_remaining)` countdown in D24/D16 Cream (two digits worst case, 30 s), and a drain bar under it built like the chain bar (HF2, over `continue_total`) with the same Alarm Red end-cap in the last 25 %. The cluster shows the slot's score in `#5A5148` (not Gold) so the player sees what a Continue wipes; lives and bombs are hidden. On accept, the score snaps to 0. On expiry the slot becomes Inactive (join plate).
25. **Pause hooks.** The HUD does not draw a pause menu (Menus 22). It exposes `set_slot_emphasis(slot, kind)` (kinds: NONE, PAUSED_BY, WAITING) which draws a 2 px frame in the slot colour around that slot's column; the frame is steady (no flash). It keeps drawing the last frame while paused.

**Boss row (Row B in 1-2P, Row D in 3-4P)**

26. **Boss bar.** Alarm Red `#E03A3E` fill on `#2A0F12`, 1 px outline, 310 px interior. The fill length, phase tick, critical notch, chip and the number follow Formula HF3. A 1 px Cream **phase tick** marks the parts/core boundary; a taller Alarm Red **critical notch** marks the critical threshold and lights during Critical. The bar fills in over 60 ticks at `boss_started`. A darker `#7A2226` **chip** catches up in 18 ticks. The right zone shows `display_pct` with `%` in D10 Cream (`100%` = 24 px, exactly the zone).
    - **Part kill** (`boss_part_destroyed`): for 90 ticks the right zone shows a broken-plate icon and the number of parts left; for the last part, a core-exposed icon with no number. *(Boss specified a bilingual caption; a 12 px row cannot hold 17 px Bengali and the fight HUD is icons and numerals only. Open Question 7.)*
    - **Enrage** (`boss_enraged`): from `enrage_start` the left zone shows a 7x10 Amber `#FFB000` icon and `timeout_left` seconds (D10, Amber), counting down from `timeout_after_enrage / 60` = 20. The icon pulses per Rule 31.
    - **Outside boss fights** the row shows the stage and wave progress as a thin segmented track (4 px, one segment per wave, filled = done), at 100 % for 300 ticks after `stage_started`, then dimmed to 40 %.
27. **Transient banners.** The HUD owns the presentation of three banners, drawn at slot 11 over the play field: **Warning** (trigger `warning_started(ticks)` from the Wave director: 150 ticks at wave-5 end + 90, after its field clear at + 60), **boss name plate** (`boss_intro_started`, 90 ticks from intro tick 60, text from `text_both("boss.<id>.name")`), **Critical Break** (`critical_break_landed` from Critical Break 17; starts no earlier than `T+2`). Layout and timings are in Visual/Audio. A banner **starts only when no enemy bullet is alive** (`enemy_bullet_count == 0`, read from Bullet manager). If the field is not clear it waits up to `banner_wait_max` (180) ticks; if still not clear the banner is **skipped** and a strip-only fallback is shown: the boss row fills with Amber stripes for 150 ticks (Warning) or nothing (name plate, Critical Break), and a debug warning is logged (a guarantee from Wave director/Boss/Bombs was broken). Only one banner shows at a time; later ones queue (max 2). *(2026-11-03, wave 3a: the HUD owns banner presentation; `banner_wait_max` 180 also governs the Critical Break banner, superseding CB's 120.)*

**Critical Break (contract aligned with [critical-break.md](critical-break.md), 2026-11-03)**

28. The HUD expects from Critical Break (17): `cb_armed(slot)` (bool, true while that slot can trigger a break), the existing `critical_break_landed(slot, ...)`, and `chain_multiplied`. While armed, the slot's chain plate shows four Alarm Red 2x2 corner ticks (steady, no blink); this is the "armed indicator". On landing: the `xN` popup in the plate lane for 60 ticks, then the award takeover (Rule 29). The white flash frame (layer 10) and the banner trigger belong to Critical Break/VFX; the HUD only draws the banner and, with `access.reduce_flashing`, the banner stays and the flash is replaced by VFX. *(If 17's design differs, only this rule and its ACs change.)* *(2026-11-03, wave 3a: CB publishes `cb_state(slot)` = NONE / OPEN / ARMED / COMMITTED / OPEN_LATE, not a bool. Read "armed" above as `cb_state(slot) in {ARMED, COMMITTED}`: corner ticks steady while ARMED, pulsing within Rule 31 while COMMITTED. CB also asks for a core ring with a 420-tick arc while OPEN (thin static ring in OPEN_LATE) and a Gold outline on the bomb icon while ARMED (CB UI Requirements). *(2026-11-03, wave 3b: the core ring/arc is a **world-space tell owned by VFX (25)** (tier T0, layer 5, below enemy bullets, never over bullets); the HUD adds only the Gold bomb-icon outline while `cb_state` is ARMED or COMMITTED, plus the corner ticks.)* There is no `critical_break_banner_requested`: the banner starts from `critical_break_landed`. Bombs keeps reading CB's pure `cb_armed(slot)` query.)*

**Awards**

29. **Plate-local awards.** From Scoring's award events `(slot, points, source)`: `PART` (`+5,000`) shows in the plate left lane for 60 ticks. `BOSS` (`+100,000`), `CRITICAL_BREAK` (`+N`) and `LIFE_BONUS` (`LIFE` plane icon and `+N`) are **takeovers**: for 60 ticks the digits area is replaced by the award in D12 Gold, centred in the plate interior; the window bar keeps running. Each plate has a FIFO of at most 3 pending awards (a fourth drops the oldest not yet shown); one is shown at a time. HIT, KILL, ITEM, CAP_HOLD only update the score. **No score number is ever drawn over the play field.**
30. **MAX tag.** While Scoring pays the cap-hold streak at its full rate (30 s at the cap, 15,000/s) the slot shows the MAX tag (a 12x8 plated icon: double chevron over a bar, Gold; 8 px wide in 3-4P). It disappears when the streak ends (chain drop or `boss_cap_hold_allowed()` false). It is an icon, not the word MAX, so it needs no translation. *(Amends Scoring's "gold MAX tag"; Open Question 8.)*

**Tutorial, Boss Rush (added 2026-11-03, wave 4)**

30a. **Strip mark** (Tutorial 30 Rule 21). `strip_mark(slot, element_id, ticks)`: four Cream `#F4EBD6` corner brackets, 4 px arms, 1 px, 2 px outside the element's rect **clamped to the column's mark clip rect** (x from the column origin + 4, and in 2P up to x 355 for P2; y from 0 to the row limit, 36 in 48 px strips or 59 in 72 px strips); a clamped side sits **on** the clip edge instead of outside the element, steady (no pulse or blink), layer 11 inside the strip, removed instantly after `ticks` (default `strip_mark_ticks` 180, owned by Tutorial). Element ids: `chain_plate`, `chain_bar`, `kit_bar`, `drone_lamp`, `drone_pips`, `bomb_icons`, `lives_icons`. One mark per slot; a new one replaces the old. Marks never enter the play field.
30b. **Drill bar** (Tutorial Rule 18). In a `DRILL` run with no boss alive, the boss-bar rect (24,37,312,10) becomes the drill bar: stepped Cream fill with a target notch (Tutorial F1), group icon (12x12) in the left zone (0,36,24,12), `n/N` in D10 in the right zone (336,36,24,12). A slot that finishes shows a **DONE** stamp (check glyph in a 3 px Cream plate, 90 ticks, no flash) in its column; a skipped drill shows the dimmed **SKIPPED** dash glyph. The DONE and SKIPPED stamps are one 16x11 asset (3 px border, 10x5 interior; DONE = Cream border and check glyph, SKIPPED = `#A89E8A` border and dash). `HudLayout` carries a `stamp` rect: `hud_layout_1p` stamp = (224,4,16,11); `hud_layout_3_4p` stamp = (73,16,16,11) relative to each column (absolute x 73, 163, 253, 343, y 16). `hud_layout_2p` and `hud_layout_compact48` set `stamp = none` explicitly because no free block of 16x11 exists there; in those layouts per-slot DONE / SKIPPED is the Tutorial's responsibility (tutorial.md Rule 16a). AC-03 asserts the stamp rect overlaps no other element rect in its layout and fails if the `stamp` key is missing.
30c. **Rush counter** (Online leaderboards and boss rush 32). In a `RUSH` run, outside a boss fight (Warning, intro, refit beat) the boss row's left zone shows the rush position `n/N` (boss index / bosses in the rush) in D10 with a boss glyph, instead of the stage track; during the fight the row is the normal boss bar. Layer 11, inside the strip (never over the field).

**Pulses, accessibility and themes**

31. **One pulse at a time.** Pulsing elements (last-life display, enrage icon, Warning text) share one **pulse arbiter**. At most one element pulses; priority: Warning text > enrage icon > last-life of the lowest slot. Others in the same state show their static cue. A pulse is opacity 100 / 80 / 60 / 80 % in steps of 15 ticks (1 Hz, 40 % depth), never faster, never a blink. `access.reduce_pulsing` turns the arbiter off (all static cues).
32. **No flash from the HUD.** The HUD has no element that changes luminance faster than 3 Hz. The prototype's full-screen flash rectangle is removed (`screen_flash_requested` is deprecated: VFX (25) Rule 5, Session Rule 13).
33. **Colour roles come from `HudTheme`** (`data/ui/hud_theme.tres`): Gold, Cream, Char, edge, Tracer Orange, **`ALARM_RED` `#E03A3E`** (fill only: boss-bar fill, chain end cap, plate edge, error-glyph fill - never a text fill), **`ALARM_FLARE` `#F2494D`** (*(added 2026-11-03, art-director A4)* **text only, never a fill of any kind**: the one headline status line of a failure or danger state on a menu or plated screen, 4.76:1 on Char; it is **never drawn in the HUD strip, in a slot column, beside a P1 pip or ring, or in the play field**, and it is never era-tinted - so the HUD theme carries the token for the shared menu/UI theme only; it renders Cream under `hud_contrast` HIGH; art bible 4.1, `arcade-ui-style.md` 3.1 rule 3 "two reds, two jobs"), Amber, player colours (with the colour-blind remap, patterns unchanged) and a high-contrast variant, chosen by Accessibility (28). The HUD reads the theme on `settings_changed` and on stage start; the era tint is set on `stage_started`. *(2026-11-03, wave 3b: the theme is chosen by `access.hud_contrast` (STANDARD / HIGH) and `access.player_palette` (DEFAULT / LUMA_SPREAD) (Accessibility 28). The era tint (`EraDef.ui_tint`) is set on `era_swap_committed(era_index)` (Era shift 19), with `stage_started` as a fallback if the swap has not run.)*
34. **Text size.** HUD numerals have a fixed grid and do **not** follow the text-size step-up. Banner words use `Localization.font_size_px(tier, step)`. **HUD scale is not adopted; `play_top` stays 48 / 72** (Accessibility 28 Rule 20, 2026-11-03). In its place: the high-contrast theme (Rule 33), the Pause status panel at the text step (Menus 22), and the optional near-plane chain bar (Rule 34a).
34a. **Accessibility elements (2026-11-03, wave 3b, Accessibility 28).** (a) Each `HudLayout` has an `assist_tag` rect, 12x12, per column (lint-exempt from the overlap rule); it shows the PRACTICE icon while `run.assisted` is latched. (b) Optional **near-plane chain bar** (`access.chain_bar_near_plane`, default off): a thin copy of the slot's chain window bar drawn under that slot's plane on layer 7. (c) The Continue plate countdown reads `access.continue_timer` (STANDARD 600 ticks / EXTENDED 1800 ticks). **UNTIMED shows the EXTENDED countdown and drain bar while another slot is Alive** (a waiting team-mate must be able to see how long the wait is); there is no countdown and no drain bar **only when no other slot is Alive** (Accessibility 28 Rule 22). The active total is published as Session `continue_total` and feeds HF2.

**Data and existing code**

35. All timings, thresholds and counts in this GDD are `HudRules` fields in `data/ui/hud_rules.tres`; all rects in the three `HudLayout` files; all colours in `HudTheme`.
36. The existing `src/ui/hud/hud.gd` is a prototype: it polls `Player` and `Boss` objects directly, builds strings with `%d`, shows English status text, has a full-screen flash and a result panel. It is replaced by `HudModel` + `HudView`; the result panel moves to Stage tally (21) / Results (22); the flash moves to VFX (25); status text is removed (Boss supplies icons and numbers).

### States and Transitions

**HUD mode**

| Mode | Enters from | Leaves to | Shows |
|---|---|---|---|
| Hidden | boot, Title, Plane select, Results | Stage | Nothing (menus draw their own) |
| Stage | `stage_started` | Tally (`stage_cleared`), Hidden (`run_ended`) | Everything in the tables above |
| Tally | `tally_started` | Stage (`stage_started`), Hidden (`run_ended`) | **Nothing: the strip is hidden while the tally panel is up**; the tally owns the full canvas. The HUD shows again at the next `stage_started`. No `extend_awarded` presentation in this mode; the tally shows extends via `tally_extend_shown` (Tally Rule 24). *(2026-11-03, wave 3b: replaces the wave-3a "strip kept" form.)* |
| Paused | game paused | Stage / Tally | Last frame, frozen (the model does not tick) |

**Per-slot column state** (from Session slot state and Co-op)

| Slot state | Column shows | Next |
|---|---|---|
| Empty | Join plate (3-4P) / nothing (1-2P) | Selecting |
| Selecting | Join plate with a 2 px slot-colour frame | Alive |
| Alive | Full column | Dead |
| Dead (respawn delay) | Full column; lives already reduced; 1P portrait hurt | Alive / Continue |
| Continue | Continue plate (Rule 24); cluster dim score only | Alive / Inactive |
| Inactive | Join plate; the identity block kept | Selecting |

**Banner state:** Idle, Waiting (field not clear, up to 180 ticks), Showing (in 10, held, out 8 frames), Skipped (fallback).

### Interactions with Other Systems

| System | Direction | What the HUD reads or listens to |
|---|---|---|
| Session (1) | In | Slot state, `plane`, `lives`, `score`, `drone_count`, `continue_remaining`, `stage_index`, era; events `player_died`, `player_continued`, `player_joined`, `player_slot_inactive`, `extend_awarded(slot, gained)`, `stage_started`, `stage_cleared`, `boss_defeated`, `run_ended`, `coop_count_changed` |
| Chain tracker (7) | In | `count`, `bar_px(slot, BAR_PX)`, `red`, `ghost_visible`, `last_dropped`, `team_chain_active`; events `chain_milestone`, `chain_dropped`, `chain_multiplied`, `team_chain_started`, `team_chain_ended` |
| Scoring (8) | In | `display_score(score)` per slot; award events `(slot, points, source)`; cap-hold full-rate flag |
| Co-op (18) | In | `N`, `team_chain_on`, `m`, `team_pct`, per-slot `lamp_state` |
| Plane kits (11) — [GDD](plane-kits-lancer-leech.md); Sentry, Breaker (29) — [GDD](plane-kits-sentry-breaker.md) | In | `kit_bar(slot) = (num, den)`, `kit_ready`, `drone_lamp` (state and ratio); Sentry `recall_available`; Breaker `stock` (via `kit_bar`) |
| Bombs (12) | In | `bombs(slot)`, `bomb_busy(slot)`, `bomb_denied(slot, reason)`, `bombs_changed(slot, old, new)` |
| Boss (14) | In | `boss_bar_state()` (`bar_permille`, `phase_tick`, `critical_notch`, `display_pct`), `timeout_left`; events `boss_intro_started`, `boss_started`, `boss_part_destroyed`, `boss_core_exposed`, `boss_critical_started`, `boss_critical_window_closed`, `boss_enraged`, `boss_defeated`, `boss_gone` |
| Powerups (13) | In | Nothing direct: drone count (Session), 1-up (`extend_awarded`), score (Scoring) |
| Bullet manager (3) | In | `enemy_bullet_count` for the banner gate |
| Wave director (16) — [GDD](wave-and-stage-director.md) | In | `wave_started(stage, wave, total)` / `wave_ended(stage, wave, early)` give the progress track's (done, total); `warning_started(ticks)` starts the Warning banner *(aligned 2026-11-03, wave 3a; replaces `stage_progress()` / `warning_requested`)* |
| Critical Break (17) — [GDD](critical-break.md) | In | `cb_state(slot)`, `critical_left`, `core_world_pos()`, popup values; `critical_break_landed`, `critical_break_missed`, `critical_break_expired` (Rule 28) |
| Localization (27) | In | `format_int`, `text_both`, `font_size_px`, atlas cell map, `language_changed` (on the autoload) |
| Input (2) | In | Glyph family per slot, `next_join_slot()`, accept-button glyph |
| Display scaler (4) | In | Guarantees the fixed 360x640 canvas, strip inside it, never in the bezel |
| Player plane (5) | In | Slot identity (colour, pattern, pips); the **latched** `play_top` (set at `stage_started` / `wave_started`); the HUD layout follows it, gameplay never reads the HUD mode (wave 4) |
| Tutorial (30) — [GDD](tutorial.md) | In | `strip_mark(slot, element_id, ticks)`; drill bar mode; DONE / SKIPPED stamps (Rules 30a, 30b) |
| Touch controls (31) — [GDD](touch-controls.md) | none | Pause button is in the touch strip below the canvas; no HUD tile |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | In | Session `mode` (RUSH) and boss index / count for the rush counter (Rule 30c) |
| Menus (22) | Out | `set_slot_emphasis`; pause owner |
| Accessibility (28) — [GDD](accessibility-options.md) | In | Settings: `access.reduce_flashing`, `reduce_pulsing`, `reduce_motion`, `player_palette`, `hud_contrast`, `chain_bar_near_plane`, `continue_timer`; `run.assisted` (assist tag). No HUD scale (Accessibility Rule 20) |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | In | `era_swap_committed(era_index)`; `EraDef.ui_tint` (Rule 33) |
| Save (26) | In (via 28) | `settings.*` values |
| Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | none | They listen to the same events; the HUD makes no sound and no screen effect. VFX draws the Critical Break core ring/arc as a world-space tell (Rule 28) |

## Formulas

**HF1. Score roll**

`remaining = target - shown; shown' = target if remaining <= score_roll_instant_max or remaining < 0 else shown + ceil(remaining / score_roll_div)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| True score | `target` | int | 0 to 999,999,999 | `display_score`, already clamped |
| Shown score | `shown` | int | 0 to `target` | The number on the plate |
| Instant gap | `score_roll_instant_max` | int | 0 to 50,000 (5,000) | Gaps at or below this snap |
| Roll divisor | `score_roll_div` | int | 2 to 12 (6) | Larger is slower |

**Output Range:** `shown` never exceeds `target`; it is monotone non-decreasing while `target` does not fall; it equals `target` after a bounded number of ticks (about 32 for a 1,250,000 gap). A fall in `target` snaps.
**Example:** `target` 1,250,000, `shown` 0. Tick 1: remaining 1,250,000, step `ceil(208,333.3)` = 208,334, shown 208,334. Tick 2: remaining 1,041,666, step 173,611, shown 381,945. The gap shrinks by 5/6 each tick: 1,250,000 x (5/6)^31 = about 4,400, which is below 5,000, so the next tick snaps (tick 32). A 4,000 gap snaps on the next tick.

**HF2. Chain bar and Continue bar**

`bar_px = ceil(BAR_PX x window_left / W)` (Chain tracker F6); `red = window_left x 4 <= W`. Continue bar: `bar_px = ceil(BAR_PX x remaining / continue_total)`; `red = remaining x 4 <= continue_total`. `continue_total` is the **active** total for that slot in seconds, read from Session (`continue_total`, Session Continue UI contract) after Accessibility resolves `access.continue_timer`: 10 s (STANDARD), 30 s (EXTENDED), and 30 s under UNTIMED while another slot is Alive. It is `null` when UNTIMED has no other slot Alive, and then no countdown and no bar are drawn (Rule 34a(c)).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Bar length | `BAR_PX` | int px | 94 (1-2P), 82 (3-4P), 42 (compact 48 px form) | Plate interior width |
| Window left | `window_left` | int ticks | 0 to 60 | From Chain |
| Window | `W` | int ticks | 60 (`chain_window`) | |
| Remaining | `remaining` | float s | 0 to 30 | Session `continue_remaining` |
| Continue total | `continue_total` | float s, nullable | 10 or 30 | Session `continue_total`; `null` = no countdown and no bar (Rule 34a(c)) |

**Output Range:** 1 to `BAR_PX` for a live chain; consecutive ticks differ by at most 2 px (94 / 60 = 1.57; 82 / 60 = 1.37).
**Example:** 1-2P, `window_left` 60 → 94; 30 → 47; 16 → `ceil(25.07)` = 26, no red; 15 → `ceil(23.5)` = 24, red. 3-4P, 1 → `ceil(1.37)` = 2. Continue, 2.5 s of a 10 s total → `ceil(23.5)` = 24, red. EXTENDED, 14 s of a 30 s total → `ceil(94 x 14 / 30)` = `ceil(43.9)` = 44 px, not red; red starts at 7.5 s (30 / 4).

**HF2b. Bar refill on a gain** (2 steps)

`step 1: shown = shown + ceil((target - shown) / 2); step 2: shown = target`

**Example:** shown 40, target 94: step 1 → 40 + 27 = 67; step 2 → the current target. While draining, `shown = target` each tick.

**HF3. Boss bar pixels**

`fill_px = (bar_permille x BOSS_PX + 999) div 1000; tick_px = (phase_tick x BOSS_PX) div 1000; notch_px = (critical_notch x BOSS_PX) div 1000; chip_px(t) = fill_px + ceil((chip_start - fill_px) x (18 - t) / 18)` for `t` 0 to 18 after the last damage.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Interior | `BOSS_PX` | int px | 310 | Bar (312) minus the 2 outline px |
| Permille | `bar_permille` | int | 1 to 1000 | Boss F7 |
| Phase / notch | `phase_tick`, `critical_notch` | int | 0 to 1000 | Boss F7 |
| Chip start | `chip_start` | int px | `fill_px` to 310 | Chip length when damage landed |

**Output Range:** `fill_px` 1 to 310 (a living boss never shows an empty bar); the chip is always at or above the fill.
**Example:** Fortress, all parts dead, core untouched: `bar_permille` 595 → `(595 x 310 + 999) div 1000` = `(184,450 + 999) div 1000` = 185 px; `phase_tick` 595 → `184,450 div 1000` = 184; `critical_notch` 89 → `27,590 div 1000` = 27. Chip: start 200, fill 150 → t = 0 → 200; t = 9 → 150 + 25 = 175; t = 18 → 150.

**HF4. Kit bar**

`fill_px = max(1 if num > 0 else 0, (num x W) div den); notch_px = (40 x W) div 100`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Numerator, denominator | `num`, `den` | int | 0 to `den`; `den` > 0 | From the kit (`meter`, `meter_max`; Leech: ticks left, `latch_ticks` etc.) |
| Bar width | `W` | int px | 78 (1P, 2P), 82 (3-4P), 14 (compact 48 px column form) | |

**Output Range:** 0 to `W`; the notch is at 31 (W 78), 32 (W 82) or 5 (W 14, the compact 48 px column form).
**Example:** Lancer meter 400 of 1000, W 78 → 31 px, notch at 31; ready shown by the solid Cream notch. W 82 → 32. Leech cooldown 750 of 1000 → 58 px at W 78.

**HF5. Icon row**

`shown = min(value, 5); over = max(0, value - 5); icon_x(i) = row_x + 16 x i` (14 px icon, 2 px gap)

**Output Range:** 0 to 5 icons, overflow `+over` in D12.
**Example:** lives 6 → 5 icons (x 45, 61, 77, 93, 109 in 1P; last ends at x 122) and `+1`. Bombs 5 → 5 icons, no overflow.

**HF6. Numeral field width**

`field_w = digits x cell + seps x sep; fits = field_w <= rect.w` (Localization F3)

**Output Range:** the worst case must fit its rect in every language.
**Example:** 1P score, D17: 9 x 11 + 2 x 4 = 107 (rect 107). 2P and 3-4P score, D12: 9 x 8 + 2 x 3 = 78 (rects 78 and 85). Chain, D24: 3 x 15 = 45; D16: 3 x 10 = 30. Boss `100%`, D10: 4 x 6 = 24 (zone 24). Lane awards, D12: `+5,000` = 5 x 8 + 3 = 43 (lane 43); `+100,000` = 7 x 8 + 3 = 59; `+3,047,000` = 8 x 8 + 2 x 3 = 70 (takeover width 82 or 94).

**HF7. Layout mode**

`mode = 1P if N == 1; 2P if N == 2; 3-4P if N >= 3`; `play_top = 48 if N <= 2 else 72`. *(Wave 4: `N` here is the count **latched** at `stage_started` / `wave_started`; between latches only a 1P ↔ 2P change is applied, Rule 6.)*

**Output Range:** 3 modes, 2 values of `play_top`. **Example:** N = 2 with one slot in Continue stays 2P; N = 3 → 3-4P, `play_top` 72.

**HF8. Banner geometry**

`centre_y = play_top + (640 - play_top) div 2; warning_top = centre_y - 64` (two 24 px bands and an 80 px plate, 128 px total).

**Example:** `play_top` 48 → centre 344, top 280 (band 280-303, plate 304-383, band 384-407). `play_top` 72 → centre 356, top 292.

**HF9. Pulse opacity**

`opacity_pct(t) = [100, 80, 60, 80][(t div 15) mod 4]`

**Output Range:** 60 to 100 (a 40 % swing, period 60 ticks = 1 Hz). **Example:** t = 0 → 100; t = 30 → 60; t = 45 → 80.

## Edge Cases

- **If the score gap is exactly 5,000**, the shown score snaps on the next tick; at 5,001 it rolls (one step of 835, then snaps).
- **If the score falls (Continue accepted)**, the shown score snaps to the new value on that tick; no roll-down.
- **If the score reaches the 999,999,999 clamp**, the plate shows 999,999,999 and stays; it never shows more than 9 digits.
- **If `language_changed` arrives in the middle of a score roll**, the digits redraw in the new script; the roll continues from the same shown value; no rect changes.
- **If a language has no atlas cell for a character**, the cell shows the Western digit and a debug warning is logged once; the layout is unchanged.
- **If the chain is dropped on the same tick as a gain**, the drop wins: digits fade, no jump.
- **If two milestones are crossed in one change (40 to 170)**, the edge steps once to the highest (Gold at 100), and the sparkles play once.
- **If a gain arrives less than 12 ticks after the last digit jump**, the digits do not jump again; the count still updates that tick.
- **If the chain count is 999 and the cap-hold streak is at full rate**, the plate shows `999`, the MAX tag, and (in a team chain) the team tag side by side in 3-4P; in 2P the MAX tag stacks under the team tag.
- **If `ghost_visible` is true and a new chain starts**, the ghost disappears on the first counted hit.
- **If an award arrives while the plate shows a takeover**, it is queued; if 3 are already queued, the oldest queued (not the one showing) is dropped.
- **If a `PART` award arrives during a takeover**, it is queued like the others; the lane is not drawn during a takeover.
- **If `extend_awarded` has `gained = 0`**, the MAX icon shows on the lives display for 60 ticks and no icon is added.
- **If lives is 6 and one is lost**, the display goes from 5 icons and `+1` to 5 icons, with the break animation on the `+1` tag.
- **If a slot is in Continue when `coop_count_changed` fires**, the layout does not change (Co-op Rule 3); the Continue plate stays in its column.
- **If a third player joins during a boss fight (2P to 3P)**, `play_top` and the strip stay 48 px until the next stage (no `wave_started` in a fight); the new slot uses the compact 2P column form (Rule 6, amended 2026-11-03 wave 4).
- **If a third player joins mid-wave**, the strip becomes 72 px at the next `wave_started`; no animation.
- **If a 3rd player drops out (3P to 2P) mid-fight**, the 72 px strip and four columns stay until the next stage; the dropped column shows its join plate; the chip and fill of the boss bar are kept.
- **If a 4P game has slot 2 Empty**, column 3 shows a join plate; the other columns keep their positions (fixed slot order).
- **If the boss bar is requested while no boss exists**, the row shows the stage track; nothing is drawn red.
- **If `bar_permille` is 1 (a boss at 0.1 %)**, the bar shows 1 px and the number `1%` (`display_pct` is at least 1).
- **If the boss is killed and TIMEOUT happen on the same tick**, KILLED wins in Boss; the HUD shows what `boss_defeated(reason)` says and clears the enrage display.
- **If `timeout_left` reaches 0**, the left zone shows `0` until `boss_gone`, then clears.
- **If a banner is requested while the field has enemy bullets**, it waits up to 180 ticks; if the field never clears, it is skipped, the fallback is shown and a debug warning is logged.
- **If two banners are requested at once**, they play one after the other in request order; a third request while two are pending is dropped with a debug warning.
- **If the HUD receives `stage_cleared` while a banner is showing**, the banner ends at once (8-frame out).
- **If the game is paused during a banner**, it freezes in place and resumes on unpause.
- **If `drone_count` jumps from 4 to 0 (death)**, all four ticks empty on that tick, no animation, and the lamp hides.
- **If a Leech plane has no drone lamp**, the lamp rect stays blank.
- **If a kit supplies `den = 0`**, the bar shows 0 px and a debug warning is logged (the HUD never divides by 0).
- **If the HUD sees a slot colour remapped by Accessibility**, the colour changes but the ring pattern and pip count do not.
- **If `access.reduce_flashing` is on**, sparkles are off, edge steps remain, and no element changes brightness faster than 1 Hz.
- **If `access.reduce_pulsing` is on**, the pulse arbiter is off; the last life shows the steady underline and the enrage icon is steady.
- **If `access.reduce_motion` is on**, the score snaps, the digit jump, bomb shake and plate-drop shift are off.
- **If two pulsing states hold at once (enrage and a last life)**, only the enrage icon pulses; the lives display shows its static underline.
- **If the controller family changes (a pad swaps to keyboard)**, the join and Continue glyphs redraw on the next tick from Input's lookup.
- **If the snapshot is missing a system (Kits not loaded in a test scene)**, that element is blank; no error; the rest draws.

## Dependencies

**Upstream (the HUD needs these)**

| System | Hard/Soft | Interface | GDD |
|---|---|---|---|
| Game events and session (1) | Hard | Slot state, score, lives, drones, events | Yes |
| Input and player mapping (2) | Soft | Glyph family, `next_join_slot`, accept glyph | Yes |
| Display scaler and bezel (4) | Hard | Fixed 360x640 canvas, strip inside it | Yes |
| Player plane (5) | Soft | Slot identity, `play_top` push-down | Yes |
| Chain tracker (7) | Hard | Count, `bar_px`, `red`, ghost, events | Yes |
| Scoring (8) | Hard | `display_score`, award events, cap-hold flag | Yes |
| Plane kits (11), Sentry/Breaker kits (29) | Hard | `kit_bar`, `kit_ready`, `drone_lamp`, `recall_available` | Yes |
| Bombs (12) | Hard | `bombs`, `bomb_busy`, `bomb_denied`, `bombs_changed` | Yes |
| Boss and boss parts (14) | Hard | `boss_bar_state`, `timeout_left`, boss events | Yes |
| Co-op and Team Chain (18) | Hard | `N`, team state, lamps | Yes |
| Bullet manager (3) | Soft | `enemy_bullet_count` (banner gate) | Yes |
| Localization (27) | Hard | `format_int`, atlas map, `text_both`, `language_changed` | Yes |
| Wave and stage director (16) | Soft | `wave_started`, `wave_ended`, `warning_started` | Yes |
| Critical Break (17) | Soft | `cb_state`, `critical_break_landed` | Yes |
| Accessibility (28) | Soft | HUD settings keys, theme choice, `run.assisted` | Yes |
| Era shift and plane evolution (19) | Soft | `era_swap_committed`, `ui_tint` | Yes |

**Downstream (these use the HUD)**

| System | Hard/Soft | Interface | GDD |
|---|---|---|---|
| Menus, title and plane select (22) | Soft | `set_slot_emphasis` for pause owner and disconnect frames; HUD hidden during menus | Yes |
| Stage-end tally (21) | Soft | HUD hides its strip while the tally panel is up (Tally mode) and shows again at `stage_started` | Yes |
| Accessibility (28) | Soft | Palette, contrast, pulse/motion, near-plane chain bar and assist-tag options consume HUD hooks (no HUD scale) | Yes |
| Audio (24), VFX (25) | none | Listen to the same events; no HUD interface | Yes |
| Tutorial (30) | Soft | `strip_mark` by element id; drill bar; DONE / SKIPPED stamps | [GDD](tutorial.md) |
| Touch controls (31) | Soft | Pause button is in the touch strip; no HUD tile | [GDD](touch-controls.md) |
| Online leaderboards, boss rush (32) | Soft | Rush counter `n/N` (Rule 30c) | [GDD](online-leaderboards-boss-rush.md) |

**Amendments to other docs**

1. `design/gdd/systems-index.md`: row 20 status → `**Designed** (pending review) — [GDD](hud.md)`; "Depends on" → `1, 4, 7, 8, 11, 12, 14, 18, 27` (adds 1, 4, 11, 12, 27); progress tracker: GDDs written +1; "Code exists without GDD" count −1.
2. `design/gdd/scoring.md` Visual/Audio table: "A 1 px gold 'MAX' tag beside the chain plate" → "A MAX icon tag (12x8 plated, double chevron over a bar, no text) in the plate lane (HUD 20 Rule 30)".
3. `design/gdd/coop-and-team-chain.md` V1: tag digits "8 px Cream" → "D12 (12 px) Cream"; tag "centred on the bracket" → "drawn in the left lane of each member plate; the bracket links the plates (HUD 20 Rule 18)".
4. `design/gdd/boss-and-boss-parts.md` UI table: part-kill caption → "broken-plate icon and parts-left count in the boss row for 90 ticks; core-exposed icon for the last part; no text"; enrage row → "Amber icon and `timeout_left` seconds in D10 (no word ENRAGED)"; remove the localisation keys `boss.part.<id>.down`, `boss.enraged` (keep `boss.<id>.name` and `boss.core_exposed` only if a later banner uses them).
5. `design/gdd/plane-kits-lancer-leech.md` UI Requirements: kit supplies `kit_bar(slot) -> (num, den)` as ints; the drone lamp sits on the icon row after the drone ticks, not beside the bar.
6. `design/gdd/chain-tracker.md` F6: `BAR_PX` = 94 (1-2P), 82 (3-4P) (replaces "~96 / ~84"); Visual table: "plate drops 3 px" → "digits shift down 3 px inside the plate".
7. `design/gdd/game-events-and-session.md`: add HUD (20) GDD link in Dependencies; Open Question 1 closed by HUD Rule 22 (`gained = 0` shows the MAX icon).
8. `design/gdd/powerups-and-drops.md` UI Requirements: "1-up banner" → "plate-local `+gained` tag and Gold edge step on the lives display (HUD Rule 22)".
9. `design/gdd/localization.md`: add the atlas tiers D10 and D12 (heights 10 and 12; cell 6 and 8; separators 2 and 3) to F3 and Rule 26; note that `+` and `%` exist in every tier.
10. `design/gdd/input-and-player-mapping.md`: HUD (20) row → Hard-ish Soft with interface `glyph_family(slot)`, `next_join_slot()`, `action_glyph(slot, action)`; `join.prompt` is not drawn by the HUD (icon-only join plate).
11. ~~`design/gdd/display-scaler-and-bezel.md` Rule 2 / HUD row: add "HUD scale changes `play_top`; layout files per scale" once Accessibility decides (Open Question 9).~~ **Withdrawn 2026-11-03:** HUD scale not adopted (Accessibility 28 Rule 20); `play_top` stays 48 / 72.
12. `design/art/art-bible.md`: §7.2 pip mark → pip stack and identity line in the outer 4 px; §7.2 score "8 digits / 6 digits" → "9 digits in every mode (D17 / D12)"; §7.2 counter form in 2P/3-4P and 11x11 icons in 3-4P; §7.3 "plate drops 3 px" → digits shift; §7.4 boss row numeric zone x 336-359 uses D10; §7.5 add the HUD digit tiers D10 and D12 and the Bengali-digit exception; §4.1 or §7.3 add bright Gold `#FFE27A` if accepted.

> Decided under auto-approve (2026-11-03): read-only model/view split; HUD ticks after gameplay; counter form in 2P and 3-4P; icon-only join plate; award takeover in the chain plate; tag inside each member plate; icon-based part-kill and enrage cues; banner gate with a strip fallback.

## Tuning Knobs

All in `data/ui/hud_rules.tres` unless noted. Values marked (P) are unplaytested.

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `score_roll_instant_max` | 5,000 | 0-50,000 | Every medal rolls; hits feel delayed | Parts and boss awards snap (no payoff) | HF1; Scoring kill values (200-5,000) |
| `score_roll_div` | 6 | 2-12 | Roll too fast to see | Roll over 0.8 s, lags the extend | HF1 |
| `chain_jump_min_gap` | 12 ticks | 6-30 | Digits buzz in laser streams | Hit feedback feels dead | Chain gain rate (laser every 3 ticks) |
| `milestone_sparkle_frames` | 12 | 6-24 | Not noticed | Distracting | Milestones [50, 100, 200] |
| `ghost_hold` | until next chain | fixed | - | - | Chain tracker `last_dropped` |
| `award_show_ticks` | 60 | 30-120 | Not readable | Queue backs up | Scoring awards; queue 3 |
| `award_queue_max` | 3 | 1-5 | Awards lost | Stale awards | Critical Break pays 3 awards at once |
| `part_caption_ticks` | 90 | 60-180 | Part-kill cue missed | Hides the percentage too long | Boss V3 (90) |
| `chip_ticks` | 18 | 10-36 | Chip invisible | Chip lags the bar | HF3 |
| `boss_fill_ticks` | 60 | 30-120 | Bar snaps in | Slow intro | Boss intro hold |
| `portrait_hurt_ticks` | 120 | 60-240 | Portrait recovers before respawn | Stays hurt too long | `respawn_delay` 1.0, FlyIn 0.6 |
| `progress_full_ticks` | 300 | 120-600 | Progress track not seen | Competes with first wave | Wave director |
| `progress_dim_pct` | 40 | 20-60 | Track lost | Track distracts | Art bible §7.4 |
| `pulse_step_ticks` | 15 | 15-30 (1-0.5 Hz) | Over 2 Hz (rule break) | Pulse not noticed | HF9; AB §7.7 (<= 2 Hz, <= 40 %) |
| `banner_wait_max` | 180 ticks | 60-300 | Banners often skipped | Banner late | Wave director, Bombs clear |
| `banner_queue_max` | 2 | 1-3 | Banner lost | Late banners | |
| `warning_ticks` | 150 | 120-180 | Siren cut | Waits too long | Boss scroll-stop |
| `name_plate_ticks` | 90 | 60-120 | Unreadable in 2 scripts | Covers the opening | Boss V4 (90) |
| `cb_banner_hold` | 30 + 2x6 frames | 24-60 | Unreadable | Covers the field | AB §7.3 (about 0.5 s) |
| `lamp_*` sizes, rect values | layout files | within strip | Illegible | Collides | Layout lint (AC-03) |
| `BAR_PX` | 94 / 82 | plate interior | - | - | Chain F6 |
| `HudTheme` colours | art bible | AB palette | - | - | Accessibility 28; `ALARM_RED` is fill-only and `ALARM_FLARE` is text-only (Rule 33, registry) |

**Owned elsewhere:** `play_top`, canvas size → registry/Display scaler; `chain_window`, milestones → Chain; `team_pct`, lamps → Co-op; `bomb_max`, busy dim 60 % → Bombs; `meter_max`, 40 % notch → Kits; `enrage_start`, `timeout_after_enrage`, `critical_pct` → Boss; `continue_seconds`, `continue_total`, `max_lives` → Session; accessibility toggles → Accessibility (28)/Save (26); font sizes → Localization.

## Visual/Audio Requirements

Source of truth: art bible §7. All sizes are px at 1x on the 360x640 canvas. All text has the 1 px `#14110E` 8-side outline. Colours: Cabinet Char `#1E1B18`, edge `#5A5148`, Cream `#F4EBD6`, Ember Gold `#FFC93C`, Tracer Orange `#FF8A1F`, Alarm Red `#E03A3E`, Amber `#FFB000`, chain bar back `#3A2A14`, boss bar back `#2A0F12`, boss chip `#7A2226`. **Never** Void Indigo or Ink; no orb, rice, ring or needle shapes (all icons are chamfered plated tiles).

| Item | Spec |
|---|---|
| Draw slot | HUD strip and banners draw at slot 11 (above Critical Break frame, slot 10). The HUD adds nothing at slots 1-10 |
| Strip | Opaque Char; 1 px edge rule at the last strip row drawn first (other elements overwrite it); 20 % era tint on frame edges only (never on text, digits, bar fills, Gold, Red, Orange, player colours) |
| Easing | Stepped, 3-4 integer positions; panel in/out 8 frames, counter tick 2, milestone 12, banner in 10 / out 8 (art bible §7.7) |
| Chain events | As Rule 17; jump 2 px for 2 frames; drop shift 1, 2, 3, 3 px over 4 frames |
| Bomb icon | Orange tile 14x14 (11x11 in 3-4P); busy dim 60 %; break 3 frames |
| Lives icon | Plane pictogram in the player colour on a Char tile; break 3 frames (Alarm Red on frames 1-2) |
| Drone ticks | Cream fill, 4x6 (3x5 in 3-4P); new drone fills in 4 frames |
| Boss bar | As Rule 26 and HF3; right zone `87%` D10; part-kill icon and count; enrage icon Amber |
| Join plate | Cut-corner plate; START glyph 16x16 (Input's family); slot pips |
| Warning banner | Two 24 px Amber `#FFB000` stripe bands with black diagonal stripes, scrolling 3 px every 4 ticks (45 px/s); central 80 px plate with `text_both("banner.warning")` (Bengali XL 34 px above Latin XL 24 px); text opacity pulse 100 to 60 % at **1 Hz** (`pulse_step_ticks` 15; Rule 31, HF9; arbiter); lasts `warning_ticks` 150 with a siren (Audio), then out in 8 frames; geometry HF8 |
| Boss name plate | 9-slice Char plate sized to the measured text + 16 px wide, two lines + 8 px high, centred at x 180, top at `play_top + 24`; `text_both("boss.<id>.name")` |
| Critical Break banner | 300 x 80 plate at x 30, y `play_top + 24`; `text_both("banner.critical_break")` Ember Gold on Char, Bengali on the top line; in 10 frames (6-frame ease in), hold about 30 ticks, out 8 frames; the white flash frame is VFX's (`reduce_flashing` → particle burst) |
| Banner colour roles | Ember Gold on Char, Cream second line allowed; Bengali and Latin at equal weight |
| Audio | The HUD plays no sound. Audio (24) listens to the same events (milestone chime, chain drop tick, Warning siren, Continue tick on `ceil` change). Sounds for HUD-only events (award tag, MAX, extend) are owned by Audio |

**Readable Chaos:** the strip is outside the field; only banners cross it, and only when no enemy bullet is alive.

## UI Requirements

This system is the HUD. Elements: strip frame; per-slot identity block; pilot portrait (1P); score; lives; bombs; drone ticks and lamp; kit bar; chain plate (count, window bar, ghost, lamp, popups, award takeover); team bracket and tag; MAX tag; join plate; Continue plate; boss row (bar, phase tick, critical notch, number, part-kill cue, enrage cue, progress track); banners (Warning, boss name plate, Critical Break); slot emphasis frames. Every element has a shape, number or pattern backup, and works with keyboard or gamepad only (the HUD takes no input). Its layout is chosen by player count (display mode, Rule 23) on the fixed 360x640 canvas; there is no HUD scale.

Debug tools (development builds): a layout overlay (draws every rect with its id and highlights overflow), a dirty-field counter, a "force N / lives / chain / award / banner" panel driven by scripted snapshots, a language toggle, and a pulse-arbiter readout.

📌 **UX Flag**: run /ux-design for the HUD (per-mode layouts, chain plate, boss row, join and Continue plates, banners) before writing epics. Stories cite `design/ux/hud.md`, not this GDD.

## Acceptance Criteria

**Defaults used:** `play_top` 48 / 72; `chain_window` 60; `BAR_PX` 94 / 82; `BOSS_PX` 310; `score_roll_instant_max` 5,000; `score_roll_div` 6; `chain_jump_min_gap` 12; `award_show_ticks` 60; `award_queue_max` 3; `part_caption_ticks` 90; `chip_ticks` 18; `boss_fill_ticks` 60; `portrait_hurt_ticks` 120; `banner_wait_max` 180; `banner_queue_max` 2; `warning_ticks` 150; `pulse_step_ticks` 15; digit tiers D24 / D17 / D16 / D12 / D10 as in Rule 12; `continue_seconds` 10 (`continue_total` 10 / 30, resolved by Session); `max_lives` 6; `bomb_max` 5.

**Test setup:** `HudModel extends RefCounted` with `tick()`, driven by a scripted `HudSnapshot` (plain data) and a scripted event list, an integer tick counter, and no seeded RNG needed (the HUD uses none; sparkles use a fixed table). Tests in `tests/unit/test_hud_*.gd`, `extends SceneTree` like `tests/unit/test_chain_tracker.gd`. Layout rects and rules are read from `data/ui/hud_layout_*.tres` and `data/ui/hud_rules.tres`, never literals. View tests (draw calls, screenshots) are [Integration] or [Manual].

### Boundaries and tick (Rules 1-5)

- **AC-01 [Unit] (Rule 1, static scan):** a scan of `src/ui/hud/` for assignments to Session, Chain, Scoring, Kits, Bombs, Boss, Co-op or Input fields finds none; outward calls are only Localization, Input glyph lookup, and HUD signals.
- **AC-02 [Unit] (Rules 2, 3):** `HudModel` loads and ticks with no scene tree and no `delta`; two runs of a 600-tick scripted input produce an identical `display_hash()` every tick (determinism).
- **AC-03 [Unit] (Rule 9, layout lint):** for all four `HudLayout` files, every rect lies inside its strip (y < 48 or < 72, x 0-359); no two rects of one column overlap unless `shares_lane`; every numeral rect holds its worst-case string (HF6 values 107, 78, 85, 45, 30, 24, 43, 59, 70); every file carries a `stamp` key, the `stamp` rect (1P (224,4,16,11); 3-4P (73,16,16,11) per column) overlaps no other rect in its layout, `hud_layout_2p` and `hud_layout_compact48` read `stamp = none`, and a missing `stamp` key fails the lint (Rule 30b).
- **AC-04 [Unit] (Rule 4):** with the game paused, calling the driver for 120 frames produces zero `tick()` calls and an unchanged `display_hash()`.
- **AC-05 [Unit] (Rule 5):** drop all events for 60 ticks, then deliver one snapshot: score, lives, bombs, drones, chain count, boss permille all equal the snapshot on that tick (animations may be skipped, values may not).

### Layout and columns (Rules 5a-11, HF7)

- **AC-06 [Unit] (HF7):** latched `N` = 1, 2, 3, 4 → modes 1P, 2P, 3-4P, 3-4P and `play_top` 48, 48, 72, 72; a slot in Continue keeps the count; a 1P ↔ 2P change applies on the tick `coop_count_changed` arrives; a 2P → 3P change mid-wave applies at the next `wave_started`, and mid-boss at the next `stage_started` (wave 4 latch).
- **AC-07 [Unit] (Rule 7):** 2P with slots 0 and 2 active → left column slot 0 (vermillion, 1 pip, solid), right column slot 2 (green, 3 pips, dotted). 4P with slot 2 Empty → column 2 shows the join plate and the other three keep their x origins 0, 90, 270.
- **AC-08 [Unit] (Rule 8):** the pip stack has 1, 2, 3, 4 blocks for slots 0-3; the identity line patterns are solid, dashed (4 on 2 off), dotted (1 on 2 off), double; no two slots share a (pip count, pattern) pair; with the colour remap on, patterns and pips are unchanged.
- **AC-09 [Integration] (Rule 5a, art bible §7.2 test):** in a 4P screenshot at 1080x1920, no bullet pixel is drawn above y 72 and the strip occupies y 0-71 in canvas px.
- **AC-10 [Unit] (Rule 11):** the HUD scene has no node parented to a plane, bullet or enemy; the only HUD draws below `play_top` are the three banners.

### Numerals and score (Rules 12-16, HF1, HF6)

- **AC-11 [Unit] (Rule 12):** score 1,234,567 in `en` and `bn` draws 9 atlas cells (7 digits + 2 separators) at the same x for the ones digit; `set_language("bn")` changes cell ids only; no rect changes (Localization AC-37).
- **AC-12 [Unit] (Rule 15):** over 600 ticks with a constant score, `format_int` is called 0 times; changing the score once calls it once.
- **AC-13 [Unit] (HF1 example):** target 1,250,000 from 0 → tick 1 shown 208,334; tick 2 shown 381,945; shown is monotone; it equals 1,250,000 by tick 32 at the latest (HF1 Output Range) and never exceeds it.
- **AC-14 [Unit] (HF1 edges):** gap 5,000 → snap on the next tick; gap 5,001 → first step 835 and then a snap; score falls 800,000 → 0 → snaps in one tick; `reduce_motion` on → any gap snaps.
- **AC-15 [Unit] (Rule 14):** 0 shows `0`; a 9-digit score is clamped to 999,999,999; fields keep the ones digit at a fixed x for 1 to 9 digits.
- **AC-16 [Unit] (HF6):** worst-case widths: D17 9 digits 107; D12 9 digits 78; D24 3 digits 45; D16 3 digits 30; D10 `100%` 24; D12 `+3,047,000` 70.

### Chain plate (Rule 17, HF2)

- **AC-17 [Unit] (HF2):** 1-2P `window_left` 60 / 30 / 16 / 15 → bar 94 / 47 / 26 / 24 px; `red` false / false / false / true; 3-4P `window_left` 1 → 2 px; across a full 60-tick drain no two consecutive ticks differ by more than 2 px.
- **AC-18 [Unit] (HF2b):** bar shown 40, target 94 after a gain → 67 on step 1, then the live target on step 2.
- **AC-19 [Unit] (Rule 17, jump):** gains on ticks 0, 3, 6, 9 → the digits jump on tick 0 only (2 px for 2 frames); the next jump is allowed on tick 12; `reduce_motion` → no jump.
- **AC-20 [Unit] (Rule 17, milestones):** count 49 → 50 → 100 → 200: edge colour `#5A5148`, Cream, Gold, bright Gold; at 200 the edge is 2 px; a change 40 → 170 shows Gold once; after a drop the edge returns to `#5A5148`.
- **AC-21 [Unit] (Rule 17, drop):** `chain_dropped` at 187 → ghost 187 in `#5A5148`; digits shift 1, 2, 3, 3 px over 4 frames; the plate frame rect is unchanged; the ghost stays 60 ticks later; the first counted hit of the next chain clears it. Before any chain a dim `0` shows.
- **AC-22 [Unit] (Rule 17, lamp):** lamp is lit when `lamp_state` is lit, unlit `#5A5148` otherwise, an outline in grace; it is hidden with no boss or fewer than 2 Active slots; it never blinks (no change except on state changes).

### Team chain, awards, MAX (Rules 18, 29, 30)

- **AC-23 [Unit] (Rule 18):** 3P team chain with slots 0, 1, 3 as members and `team_pct` 130 → plates 0, 1, 3 show the tag `+30`; slot 2's plate does not; the bracket line at y 32 spans the centres of plates 0 and 3; with `team_chain_on` false nothing is drawn.
- **AC-24 [Unit] (Rule 18, 2P):** 2P team chain, `team_pct` 120 → both plates show `+20` (37 px: 12 icon + 1 + 24 digits) inside the 43 px lane; the bracket is at y 0.
- **AC-25 [Unit] (Rule 29):** a `PART` award of 5,000 on slot 0 → `+5,000` (43 px) in the lane for 60 ticks; a `BOSS` award → takeover `+100,000` for 60 ticks, the window bar keeps its HF2 value; awards `HIT`, `KILL`, `ITEM`, `CAP_HOLD` create no tag.
- **AC-26 [Unit] (Rule 29, queue):** four awards in one tick → three are queued in arrival order, the oldest queued is dropped for the fourth; one is shown at a time.
- **AC-27 [Unit] (Rule 30):** the cap-hold full-rate flag true → MAX icon shown; chain drop or `boss_cap_hold_allowed` false → icon removed; in 3-4P with the team tag the two fit side by side (37 + 1 + 8 = 46).
- **AC-28b [Unit] (Rule 30b, stamp):** finishing a drill in 1P draws the DONE stamp at (224,4,16,11) for 90 ticks with no overlap of any other rect; in 3-4P it draws at the finishing column's (73,16,16,11) (absolute x 73 / 163 / 253 / 343, y 16); in 2P and Compact 48 nothing is drawn in the strip; a skipped drill draws the same rect with the `#A89E8A` border and dash at both `hud_contrast` settings.
- **AC-28 [Unit] (Rule 28):** `cb_state(slot)` ARMED → four Alarm Red corner ticks on that plate, steady, and a Gold outline on the slot's bomb icon; COMMITTED → corner ticks pulse within Rule 31 and the bomb-icon outline stays; NONE / OPEN / OPEN_LATE → neither; the HUD draws no core ring or arc (VFX owns it); `chain_multiplied` → `x3` in the lane for 60 ticks.

### Lives, bombs, drones, kit (Rules 13, 19-22, HF4, HF5)

- **AC-29 [Unit] (HF5):** 1P lives 6 → 5 icons at x 45, 61, 77, 93, 109 and `+1`; bombs 5 → 5 icons; 2P lives 3 → one icon and the digit `3`; 3-4P bombs 2 → 11x11 icon and the digit `2`.
- **AC-30 [Unit] (Rule 22):** `lives_decrement` to 1 → steady Alarm Red underline appears; with several slots at 1 life, only the lowest slot pulses (arbiter) and the others show the static underline; a lost life plays the 3-frame break, with no screen-wide effect.
- **AC-31 [Unit] (Rule 22, extend):** `extend_awarded(0, gained = 1)` → a new icon with a 12-frame Gold edge step and a `+1` tag for 60 ticks; `gained = 0` → the MAX icon for 60 ticks and no new icon.
- **AC-32 [Unit] (Rule 22, portrait):** `player_died` → portrait hurt for 120 ticks; `boss_intro_started` → determined; `boss_defeated` → neutral; no victory pose is ever set in the HUD (the Tally draws it); 2P and 3-4P draw no portrait.
- **AC-33 [Unit] (Rule 21):** `bomb_busy` true → the bomb display opacity is 60 % and the icon shapes are unchanged; `bomb_denied(NO_BOMBS)` → a 2 px shake for 8 ticks; `bomb_denied(BUSY)` → no UI; `reduce_motion` → no shake.
- **AC-34 [Unit] (Rule 20):** `drone_count` 0 → 2 → 4 → 0: ticks filled 0, 2, 4, 0 (the last on the death tick); the Lancer lamp states READY / COOLDOWN / ACTIVE map to the three shapes; the lamp is hidden at 0 drones and never drawn for the Leech.
- **AC-35 [Unit] (HF4):** Lancer meter 400 of 1000 at W 78 → 31 px, notch at 31, notch solid Cream with `kit_ready`; at W 82 → 32; meter 0 → 0 px; any meter above 0 → at least 1 px; `den = 0` → 0 px and one debug warning.

### Join, Continue, pause (Rules 23-25)

- **AC-36 [Unit] (Rule 23):** an Empty 3-4P slot shows the join plate with that slot's pips; Selecting adds a 2 px slot-colour frame; 1P shows one join plate for the next free slot; 2P shows none.
- **AC-37 [Unit] (Rule 24, HF2):** a slot in Continue with `continue_total` 10 and `continue_remaining` 3.8 → the countdown shows 4; the bar is `ceil(94 x 3.8 / 10)` = 36 px; at 2.5 s the bar is 24 px and red; on accept the score shows 0; on expiry the join plate shows.
- **AC-37b [Unit] (Rules 24 and 34a(c), HF2, EXTENDED):** `access.continue_timer` EXTENDED → `continue_total` 30; `continue_remaining` 14.0 → countdown 14, bar `ceil(94 x 14 / 30)` = 44 px, not red; the end-cap turns red at 7.5 s; the countdown rect holds two digits (30 s worst case). UNTIMED with another slot Alive → the EXTENDED countdown and bar are drawn; UNTIMED with no other slot Alive → `continue_total` is `null`, no countdown and no bar, accept glyph only.
- **AC-38 [Unit] (Rule 25):** `set_slot_emphasis(1, PAUSED_BY)` draws a steady 2 px frame in slot 1's colour around column 1 only; `NONE` removes it; no flashing.

### Boss row (Rule 26, HF3)

- **AC-39 [Unit] (HF3):** Fortress with all parts dead, core untouched (`bar_permille` 595) → fill 185 px, phase tick 184, critical notch 27 (`critical_notch` 89); `display_pct` 60 → `60%` in D10 (the right zone is 24 px).
- **AC-40 [Unit] (HF3, chip):** damage from 200 to 150 px → chip 200, 175, 150 at t = 0, 9, 18; a further hit during the chip restarts it from the current chip length.
- **AC-41 [Unit] (Rule 26):** `bar_permille` 1 → fill 1 px and `1%`; the bar fills over 60 ticks at `boss_started`; `100%` fits the zone exactly.
- **AC-42 [Unit] (Rule 26, part kill):** `boss_part_destroyed(last = false)` → broken-plate icon and parts left for 90 ticks; `last = true` → core-exposed icon, no number; afterwards the percentage returns.
- **AC-43 [Unit] (Rule 26, enrage):** `boss_enraged` → Amber icon and `20` in the left zone at `enrage_start`, counting down once a second to 0; the display clears on `boss_gone`; a KILLED boss clears it at once.
- **AC-44 [Unit] (Rule 26, progress):** outside a boss fight the row shows the segmented track at 100 % for 300 ticks after `stage_started`, then 40 %; the track is replaced by the boss bar at `boss_started`.

### Banners (Rule 27, HF8)

- **AC-45 [Unit] (Rule 27, gate):** `warning_started` with `enemy_bullet_count` 0 → the banner starts at once; with 12 bullets alive → Waiting; cleared on tick 40 → starts on tick 40; never cleared → skipped on tick 180 with the Amber boss-row fallback for 150 ticks and one debug warning.
- **AC-46 [Unit] (HF8):** `play_top` 48 → Warning block top y 280, plate y 304-383; `play_top` 72 → top y 292; the block never crosses `play_top`.
- **AC-47 [Unit] (Rule 27, queue):** two banners requested on one tick play in request order; a third is dropped with a warning; `stage_cleared` ends a showing banner in 8 frames.
- **AC-48 [Unit] (Localization):** the Warning plate text is `text_both("banner.warning")`: Bengali first line, Latin second; digits follow the chosen language (Localization AC-30).

### Accessibility and animation (Rules 31-34, HF9)

- **AC-49 [Unit] (HF9, Rule 31):** pulse opacity at t = 0, 15, 30, 45 is 100, 80, 60, 80; with Warning text, enrage and a last-life active at once, only the Warning text pulses; `reduce_pulsing` → no element pulses and all static cues show.
- **AC-50 [Unit] (Rule 32):** over a 3,600-tick scripted run with every event type, no HUD element changes mean luminance by more than 40 % at more than 3 Hz, and no full-screen rect is drawn.
- **AC-51 [Unit] (Rules 33, 34):** a `HudTheme` colour remap changes the player colours and nothing else; HUD numerals ignore the text-size step; banner words call `font_size_px(tier, step)`.
- **AC-52 [Manual] (grayscale and squint):** a tester sees a 4P strip screenshot in grayscale and names, for each column, the player, the lives and the chain state in at least 8 of 10 trials (art bible §7.10).
- **AC-53 [Manual] (language):** in Bengali and English, every numeral and banner fits its box with the 1 px outline; the conjuncts in the banner words (`ক্ষ`, `শ্রী`, `ঙ্গ`, `ত্র`) are legible at 1x; D10 and D12 Bengali digits are rated legible (Open Question 1).

### Performance and Web (ADR-0001)

- **AC-54 [Perf] (REF-WEB):** 4P scripted run, 10,000 ticks with 300 events per tick: `HudModel.tick()` is at most 0.05 ms p99 with no allocations after warm-up; `HudView` redraw at most 0.30 ms p99; at most 24 draw calls from the HUD in a full 4P frame (budget proposed; tighten after the first measurement).
- **AC-55 [Perf] (idle):** with no value changing for 600 ticks, the view issues 0 redraws of numeral fields (dirty-flag only).

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | D12 and D10 Bengali digits are below the 17 px Bengali minimum. Digits have no matra or conjuncts, but are they legible at 12 and 10 px with the 1 px outline? Fallback: widen the 2P/3-4P score to D16/D17 and shorten the field | art-director, Localization | Font spike (art bible §8.9) |
| 2 | The 3-4P strip (72 px) is tight: 11x11 icons, a 12 px counter row, and the kit bar at y 28-31. Is it readable at 1x on REF-PHONE? | art-director, ux-designer | §7.2 layout spike and playtest |
| 3 | Add bright Gold `#FFE27A` (milestone 200) to the palette, or use only the 2 px edge | art-director | Before HUD art |
| 4 | Move the team tag inside each member plate (this GDD) instead of centred on the bracket. Accept? | Co-op owner, art-director | HUD UX spec |
| 5 | ~~Should the join plate show the words ("Press START to join" in both scripts)? Icon-only keeps the fight HUD text-free; new players may need words. Show for the first 10 s of stage 1 only?~~ **Closed 2026-11-03:** icon-only in play; words on the stage card for stage 1 only (tutorial.md Rule 27). | ux-designer, Tutorial (30) | Playtest |
| 6 | 2P has no room for a join plate for slots 3 and 4. Add a 16x16 START glyph in the free plate gap, or rely on the title/plane-select teaching? *(2026-11-03: a Selecting slot is shown via the next layout mode (Rule 23); this question now covers only the idle join prompt.)* | ux-designer | Playtest |
| 7 | ~~The boss part-kill caption and ENRAGED tag are icon plus number here, not bilingual words. Is the icon language enough, or should a one-off banner explain the first enrage (Tutorial)?~~ **Closed 2026-11-03:** icons stay; the first ENRAGED is explained by a Tally tip (hint `enrage_icon`, tutorial.md). | Boss owner, Tutorial (30) | Boss playtest |
| 8 | MAX is an icon, not text. Confirm with Scoring's owner and test that players read it as "capped". | Scoring owner | Playtest |
| 9 | ~~HUD scale 100 / 125 / 150 %: integer scaling of pixel art breaks the 1x grid. Proposal: three authored layout sets with a per-set `play_top`.~~ **Closed 2026-11-03:** HUD scale not adopted; `play_top` stays 48 / 72; replaced by the high-contrast theme, near-plane chain bar and Pause status panel (accessibility-options.md Rule 20). | Accessibility (28), ux-designer | Accessibility GDD |
| 10 | ~~Continue accept button: the HUD and the Tally must use one verb.~~ **CLOSED 2026-11-03 (wave 5 batch 2).** [Input (2)](input-and-player-mapping.md) Rule 24b defines a single **`CONTINUE_ACCEPT`** verb bound to **Fire**, used by both the HUD Continue plate (Rule 24) and the Tally Continue column ([Stage tally (21)](stage-end-tally.md) Rule 17). **Start stays Pause** and never accepts, so the START-versus-Pause priority question disappears. | — | Closed |
| 11 | ~~Critical Break (17) has no GDD: confirm the `cb_armed` and banner-request contract.~~ **Closed 2026-11-03:** `cb_state(slot)` and `critical_break_landed` (Rule 28 note; critical-break.md). | Critical Break owner | Critical Break GDD |
| 12 | Lives display: total (with the plane in flight) as here, or spare lives only (arcade convention, `lives - 1`)? | game-designer | Playtest |
| 13 | ~~Touch layout (31): where does a pause button go? The strip has no free tile.~~ **Closed 2026-11-03:** Pause is a button in the touch strip below the canvas; no HUD tile (touch-controls.md). | Touch controls (31) | Touch UX spec |
| 14 | The 1P kit bar uses the margin row y 36 beside the boss bar outline (y 37). Does it look cramped, or should the score row be D16? | art-director | Layout spike |
