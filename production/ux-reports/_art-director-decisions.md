# Art Director Decisions, 2026-11-03

Files edited: `design/art/art-bible.md` (4.1, 7.8, 7.10, header), `design/ux/arcade-ui-style.md` (3.1 rule 3 + palette row, checklist, Open Question 2, header), `design/ux/hud.md` (new "DONE / SKIPPED stamp" section, Open Question 21, header). No GDD edited.

All contrast figures are WCAG relative-luminance ratios computed by hand from the hex values. They are **not renderer measurements** and must be re-measured with the real renderer, font and outline in the font spike, and under protan/deutan simulation.

## Decision 1: Alarm Flare `#F2494D` (text-only red)

| | Alarm Red `#E03A3E` | Alarm Flare `#F2494D` |
|---|---|---|
| Luminance | 0.1922 | 0.2418 |
| On Char `#1E1B18` (0.01126) | 3.95:1 | **4.76:1** |
| On boss track `#2A0F12` (0.00877) | 4.12:1 | 4.97:1 |
| Hue (HSL) | 358.6 | 358.6 (identical) |
| Rec.709 luma | 93.6 | 109.2 |

Reasoning: hue held exactly, only value raised, saturation kept high, so it stays a signal red and not pink or orange. `#EE4448` is 4.53:1, too little margin for renderer error. `#FF6366` (5.9:1) looks coral. Name follows the "Descriptor Noun" convention (Alarm Flare).

Role split (stated in art bible 4.1 and 7.10): `#E03A3E` stays the plate-edge, bar-fill, end-cap and glyph-fill red and is never text. `#F2494D` is text only.

Use rules: text only, 1 px outline, tier S or larger, on Char or `#2A0F12`; one headline status line per screen, with the explanatory sentence in Cream; the Alarm Red edge and/or error glyph is still required; Cream under `hud_contrast` HIGH; not in the HUD strip, any slot column, beside P1 pips or rings, or the play field; not era-tinted; only where a Cream sentence repeats the same words.

Colour-vision check (LUMA_SPREAD): gaps to slot luma 122.5 / 231.2 / 169.0 / 199.8 are 13.3 / 122.0 / 59.8 / 90.6. Gaps to Cream 126.3, Gold 93.1, Amber 70.9, Tracer Orange 45.9. Distinct from all text colours. Caveats:
1. P1 gap is 13.3, under the 30.9 slot minimum, and P1 `#FF5A36` is about 12 degrees of hue away. Acceptable only because Flare is text and P1 is a pip, ring or plane, and the rules keep them apart.
2. In greyscale Flare reads as mid-value text, not an alarm, so the words and glyph must carry the meaning.
3. Protanopia dims reds; contrast on Char under protan simulation is expected to drop below 4.76 and is unmeasured.
4. 4.76:1 is below the 7:1 menu line (see amendment A3).

## Decision 2: DONE / SKIPPED stamp

Asset: 16x11, 3 px border ring, 10x5 interior. DONE = Cream border, Char interior, Cream check. SKIPPED = same rect, border and 6x1 dash in `#A89E8A` at both contrast settings (it carries information, so `#5A5148` is not allowed). 90 ticks, no flash.

| Mode | Rect (x,y,w,h) |
|---|---|
| 1P, 48 px | **(224,4,16,11)** |
| 2P, 48 px | **none, suppressed** |
| Compact 48 | **none, suppressed** |
| 3-4P, 72 px | **(73,16,16,11) relative to the column**; absolute x 73 / 163 / 253 / 343, y 16 |

1P clearances: 4 px to join plate (ends x 219), 6 px to MAX (starts x 246), 7 px above drone ticks (y 22), 22 px to chain plate. 3-4P: 3 px to the lamp (ends x 69), 1 px under the score row, 1 px above the kit bar (y 28), 1 px to the next column.

2P and Compact 48 genuinely have no room: the largest free block in a 2P cluster is x 52-82 by y 25-30 (31x6), and the Compact 90 px column is packed to y 35 with the chain plate at x 44-89. Fallback chosen: suppress the in-strip stamp. Rejected: drawing over the play field (hides bullets, breaks "nothing over the field") and borrowing the boss-row zones (they hold the drill group icon and `n/N`, which counts as covering the boss row). The remaining in-strip signals are the drill bar reaching full fill and `n/N` reaching `N/N`; a skipped drill leaves the bar dim. This means **2P co-op Flight School, the most common multi-player case, has no per-slot DONE in the HUD.** The Tutorial surface must carry it (A2).

Note: the existing 1P kit bar (y 33-36) is adjacent to the drill bar row (y 37). I did not change it.

## Cross-document amendments for the main session

> **ALL FIVE APPLIED 2026-11-03** (final doc closeout; see `production/gdd-reports/_final-doc-closeout.md`).
> **A1** → `design/gdd/hud.md` Rule 30b, Rule 9, the four layout tables, AC-03 and new AC-28b.
> **A2** → `design/gdd/tutorial.md` new **Rule 16a** (Flight School surface carries the per-slot result in 2P and Compact 48, reusing the 14x14 School-list stamp form - no new colour, hex or rect), plus Rules 16 / 21 / 22 and Visual/Audio; `design/ux/flight-school.md` gained the per-slot result row and the 2P / Compact 48 variant.
> **A3** → `design/accessibility-requirements.md` 3.2, exception row under "Contrast of plated UI at least 7:1 on menus".
> **A4** → `design/registry/entities.yaml` constants `ALARM_FLARE` (and `ALARM_RED`, for the fill/text split); `design/gdd/hud.md` Rule 33 (`HudTheme`) and `design/gdd/accessibility-options.md` Rule 16 / AC-20 (Flare → Cream under HIGH).
> **A5** → `design/ux/settings.md` line 6 reworded; the Flare headline option was also offered in `settings.md`, `high-scores.md` and `interaction-patterns.md` P29 (consistency-report 4.1).
> Still open and deliberately untouched: the **protanopia re-measurement** of Alarm Flare, the renderer re-measurement of all contrast figures in the font spike, the bright Gold `#FFE27A` acceptance, and the REF-PHONE hue eyeball.

**A1. `design/gdd/hud.md` Rule 30b**: append to the end of the rule:
"The DONE and SKIPPED stamps are one 16x11 asset (3 px border, 10x5 interior; DONE = Cream border and check glyph, SKIPPED = `#A89E8A` border and dash). `HudLayout` carries a `stamp` rect: `hud_layout_1p` stamp = (224,4,16,11); `hud_layout_3_4p` stamp = (73,16,16,11) relative to each column (absolute x 73, 163, 253, 343, y 16). `hud_layout_2p` and `hud_layout_compact48` set `stamp = none` explicitly because no free block of 16x11 exists there; in those layouts per-slot DONE / SKIPPED is the Tutorial's responsibility. AC-03 asserts the stamp rect overlaps no other element rect in its layout and fails if the `stamp` key is missing."
Also add an AC: "Finishing a drill in 1P draws the DONE stamp at (224,4,16,11) for 90 ticks with no overlap; in 3-4P it draws at the column's (73,16,16,11); in 2P and Compact 48 nothing is drawn."

**A2. `design/gdd/tutorial.md` / `flight-school.md`**: add a requirement that in 2P and Compact 48 the Flight School surface itself shows per-slot DONE / SKIPPED (own plate, toast, or audio cue). Owner decision; I have not specified it.

**A3. `design/accessibility-requirements.md`** row "Contrast of plated UI at least 7:1 on menus" (line 96): add "Exception: the single Alarm Flare `#F2494D` headline status line (4.76:1, minimum 4.5:1) is allowed because the same words are repeated in Cream on that screen; it renders Cream under HIGH contrast." Without this the new token contradicts the committed COMPREHENSIVE tier on menu screens.

**A4. Registry**: add colour constant `ALARM_FLARE = #F2494D` (text only) to the HUD theme / UI colour registry and to `HudTheme`, with the rule "never a fill". No registry file was edited.

**A5. Specs that quoted the red-text ban** (`design/ux/settings.md` Save failure and contrast line, `design/ux/high-scores.md`, `design/ux/interaction-patterns.md` line 403): they remain valid as written (Cream words plus red edge). They may optionally adopt a Flare headline; no change is required. `design/ux/settings.md` line 6 says "never a text fill at all", which is now true only of `#E03A3E`; consider rewording.

## Other caveats
- The HUD GDD has a bright Gold `#FFE27A` still pending acceptance (art bible 4.1 note). Not decided here.
- Hue of the Flare on real hardware (coral drift at higher brightness) should be eyeballed on REF-PHONE.
