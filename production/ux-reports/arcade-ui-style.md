# UX Review: Arcade UI Style Guide

**Document**: `design/ux/arcade-ui-style.md`
**Type**: Style guide (adapted checklist: scope, completeness, testability, consistency)
**Reviewed**: 2026-11-03
**Reviewer**: ux-designer (Claude)

## Verdict before fixes: NEEDS REVISION
## Verdict after fixes: APPROVED (with advisory open questions)

## Blocking issues found (all fixed in the file)

1. Header lacked Last Updated and Sources.
2. No ownership statement; the pattern library already points to this file for the animation and sound tables, and the brief assumed the reverse.
3. No type ramp (pixel sizes by tier, text-size steps, font variants).
4. Colour tokens had no roles and no contrast ratios. Measured: Cream 14.4:1, Gold 11.2:1, Amber 9.4:1, Alarm Red 3.95:1 (below 4.5), `#5A5148` 2.2:1 (it was listed for "dim text"), `#A89E8A` 6.5:1.
5. No spacing/grid or safe-area rules.
6. No panel, border or shadow treatment.
7. No degradation table for `hud_contrast`, `text_size`, palette, reduce_*, background dim/plain.
8. No acceptance criteria or conformance checklist.
9. Section 4 Lobby plate pulse went 100% to 40% (a 60-point swing), violating art bible 7.7 (40 points maximum).
10. Section 4 "Banners: 6-frame ease" contradicted art bible 7.7 (in 10 / out 8), Critical Break (6/30/6) and HUD WARNING (out 8).
11. Section 4 allowed a "hero +1 step" scale, contradicting art bible 7.3 and 7.7 (no scaling, digits never enlarge).
12. Section 2.2 said "never clip top 2 px" while art bible 7.5 and 7.10 require 4 px headroom.
13. Slot colours were attributed to the Co-op GDD; they live in art bible 4.4 and Accessibility F5 (LUMA_SPREAD hexes missing). Also "always paired with P{n}" conflicted with the HUD, which has no P{n} text.
14. Proposal 3 (era-tinted plates) was already adopted in art bible 7.8 and `hud.md`.
15. Latin "12 px" was ambiguous (cap height vs size).

## Advisory (left as open questions)

- Ghost digits at 2.2:1 in Standard mode, Alarm Red text at 3.95:1, line-pitch base, plate shadow, HUD "P{n}", tally hero step, font spike re-measure, margins not device-tested.

## Fixes applied

1. **Header**: added Last Updated, Sources, Status note and the revision line.
2. **New "Ownership" table** (before section 1): what this file owns vs cites.
3. **New 1.1**: five arcade-intent rules as measurable checks (luma <= 90 for plates, Gold-only-on-score, 8% luma-change flash test, etc.).
4. **2.1**: tally block broken down (17 + 2 + 12 = 31), chip size cited from `main-menu.md`, rule for adding new dual-script surfaces.
5. **2.2**: cap height vs size clarified; headroom reconciled (4 px reserved, 2/3 px clip floors); D12/D10 exception; line pitch; conjunct gate added.
6. **Section 3 retitled and expanded**: 3.1 colour roles with contrast ratios and five rules; slot colour table with LUMA_SPREAD; 3.2 type ramp with steps 0-3; 3.3 grid, margins, reserved bands, safe areas; 3.4 panel, border, shadow, focus treatment.
7. **Section 4**: Lobby pulse corrected to 100% <-> 60%; focus pulse expressed as a swing; banners row replaced by owner timings; WARNING pulse row added; easing row no longer allows hero scale; canonical-table statement added.
8. **Section 5**: ownership line (Audio GDD owns ids).
9. **Section 6**: proposal 3 marked adopted; proposal 2 respects the chosen language.
10. **New section 7**: degradation under hud_contrast, text_size, palette, reduce_*, background modes, colour-vision, untimed menus, screen reader (out of scope).
11. **New section 8**: 14-item conformance checklist including resolution and performance criteria.
12. **New section 9**: eight open questions.

## Cross-document amendments requested

1. **`design/ux/stage-tally.md` line 90 and line 167** (MAX_CHAIN hero: "scale +1 step at end"; reduce motion: "hero scale step off"). Conflicts with art bible 7.3 / 7.7 and the style guide section 4. Proposed: "colour step to bright Gold with a 1 px edge step at count end (no scaling)", or remove the step; update the reduce-motion row and Open Question 6 accordingly.
2. **`design/ux/hud.md` Open Question 9 (line 485)**: cites "Style guide G3 lists P{n}", but the style guide has no G3. Proposed text: "Style guide 3.1 requires P{n} only where a text label fits; the HUD column (Rule 8) is exempt. Close as resolved unless art-director wants a 5 px label."
3. **`design/ux/hud.md` line 437** (Bengali headroom "Never clip top 2 px / bottom 3 px"): add "reserve 4 px above the matra line (art bible 7.5)".
4. **`design/ux/credits.md` line 59** (S tier line 20 px "Latin 12 px x 1.2, rounded up"): 12 x 1.2 rounds to 15, not 20. Either state the real base or correct the number once Open Question 3 (line-pitch base) is answered.
5. **`design/ux/interaction-patterns.md` Animation Standards (line 399)**: still says "join plate 1 Hz opacity step"; add "100% <-> 60%". P09 should carry the same range.
6. **Art bible 7.10 / 7.5 (art-director)**: consider (a) a lighter Alarm Red text variant reaching 4.5:1 on Char (style guide OQ 2) and (b) a statement that the 2/3 px clip floors and the 4 px headroom reservation are both valid.
7. **`design/ux/settings.md` line 309, `high-scores.md` line 196** ("Alarm Red text allowed / only with words"): now bound by style guide 3.1 rule 3 (error glyph plus words, tier S or larger). Add the error glyph requirement if absent.
8. **Brief note for the main session**: the brief says the pattern library owns animation and sound standards; the pattern library itself delegates both to the style guide sections 4 and 5. The style guide now states it is the canonical copy. Confirm.

## Still open

- Open Questions 1-8 in the file (section 9). Items 1, 2, 4, 5 need art-director decisions; item 3 and 7 need the font spike; item 8 needs device testing.
- Contrast ratios were computed by hand from the hexes (WCAG formula); re-measure with the real renderer.
- Bengali strings remain draft until native review.
- Proposals 1 and 2 still need Menus GDD amendments before binding.

## Checks that passed

- Single-language rule and the dual-script surface list match the brief, `main-menu.md`, `settings.md` (first-run plate, TATE) and `interaction-patterns.md` P23.
- No contradiction found with `main-menu.md` (216 px plate, chips 56x20, prompt bar y 600) or `settings.md` (HIGH contrast swap, text size 2-3 stacking) beyond the items above.
- Tokens match the art bible (4.1, 7.3, 7.4); HUD strip sizes and canvas are cited, not restated.
