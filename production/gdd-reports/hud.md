# GDD report: HUD (system 20)

## 1. File written
`design/gdd/hud.md` (status Designed, pending review). It defines the HUD as a read-only model/view system (`HudModel` RefCounted with `tick()`, plus a thin view) drawing a reserved top strip (48 px for 1-2P, 72 px for 3-4P) from three data-driven layouts. It gives exact element rects per mode (1P, 2P, 3-4P tables), five numeral tiers on the digit atlas (D24, D17, D16, D12, D10), all update rules (score roll, chain plate, award takeover, bar formulas), join and Continue plates, boss row, banners with a clear-field gate, pulse arbiter, accessibility hooks, perf budget, 9 formulas, ~35 edge cases, 55 acceptance criteria, 14 open questions. Schematic ASCII mock-ups for 1P, 2P and 4P are included (3P is the 4P drawing with slot 3 as a join plate).

## 2. Key decisions (auto-approve; change them here)
- Read-only `HudModel` (node-free, ticks after all gameplay systems, freezes on pause) plus `HudView`; layouts in `data/ui/hud_layout_{1p,2p,34p}.tres`, rules in `hud_rules.tres`, colours in `HudTheme`.
- Layout mode from Co-op `N` (1 / 2 / 3+); switches instantly on `coop_count_changed`; a Continue slot still counts.
- Identity block on every column: pip stack (1-4 blocks of 3x3) plus a 1 px identity line in the ring pattern (replaces the vague "pip mark" and "frame border").
- 1P shows lives and bombs as 14x14 icons (up to 5); 2P shows icon plus count (14x14); 3-4P shows 11x11 icon plus count. Lives show total `lives` (flight plane included); last life is `lives == 1`.
- Score is 9 digits in every mode: D17 in 1P (107 px), D12 in 2P and 3-4P (78 px).
- Two new digit tiers, D12 (cell 8, sep 3) and D10 (cell 6, sep 2), because the art bible numerals do not fit the 12 px boss row and the 17 px 3-4P Row A. Bengali digits there are below the 17 px minimum (OQ1).
- Boss bar x 24-335 (312 px outer, 310 interior), `%` zone x 336-359 in D10 (`100%` = exactly 24 px).
- Score roll: gaps up to 5,000 snap; larger gaps roll geometrically (`ceil(remaining / 6)` per tick, about 32 ticks for 1.25 M). Reduce-motion snaps.
- Chain bar `BAR_PX` 94 (1-2P) / 82 (3-4P); at most 2 px per tick. Milestone edge: `#5A5148` / Cream / Gold / bright Gold `#FFE27A` with 2 px edge. Digit jump limited to once per 12 ticks. Drop shifts the digits 3 px inside the plate (the frame cannot leave the strip).
- Awards: PART shows in the plate's left lane (43 px); BOSS, Critical Break and Life bonus take over the plate digits for 60 ticks; FIFO of 3 per plate. No number in the play field.
- Team tag sits inside every member plate (icon + `+NN` in D12), bracket on y 0 (1-2P) or y 32 (3-4P). MAX tag is an icon, not text.
- Boss part-kill and enrage cues are icon + number (the fight HUD is icons and numerals; a 12 px row cannot hold 17 px Bengali).
- Join plate is icon-only (START glyph + pips); none in 2P (no room).
- Continue plate: accept glyph (default START) + countdown + drain bar with the red end-cap rule.
- Banners (Warning, boss name plate, Critical Break) are HUD-presented at slot 11, start only when `enemy_bullets_alive == 0`; wait up to 180 ticks, then skip with an Amber boss-row fallback.
- One pulse at a time via an arbiter (Warning text > enrage icon > lowest-slot last life); 1 Hz, 40 % depth.
- Extend with `gained = 0` shows the MAX icon on the lives display (closes Session OQ1).
- Critical Break is provisional (no GDD): `cb_armed(slot)` shows four steady Alarm Red corner ticks on the plate; `critical_break_banner_requested` triggers the banner.
- Perf budget (proposal): model tick <= 0.05 ms p99, redraw <= 0.30 ms p99, <= 24 draw calls on REF-WEB.

## 3. Amendments
1. `design/gdd/systems-index.md`: row 20 → `| 20 | HUD | P | MVP | 1, 4, 7, 8, 11, 12, 14, 18, 27 | **Designed** (pending review) — [GDD](hud.md) |`; progress tracker: GDDs written 14 (add "HUD"), "Code exists without GDD" 3 → 2 (14, 17).
2. `design/gdd/scoring.md` Visual/Audio table row "Cap-hold streak at full rate": replace "A 1 px gold 'MAX' tag beside the chain plate" with "A MAX icon tag (12x8 plated, double chevron over a bar, no text) in the chain-plate lane (HUD 20 Rule 30)". Also add HUD (20) GDD link.
3. `design/gdd/coop-and-team-chain.md` V1 Tag row: "8 px Cream digits" → "D12 (12 px) Cream digits"; "centred on the bracket" → "drawn in the left lane of each member plate; the bracket links the plates (HUD 20 Rule 18)". HUD row in Dependencies: link `hud.md`.
4. `design/gdd/boss-and-boss-parts.md` UI table: Part-kill caption → "broken-plate icon and parts-left count in the boss row for 90 ticks; core-exposed icon for the last part; no text"; Enrage / timeout → "Amber icon plus `timeout_left` seconds in D10 (no word ENRAGED)"; keys `boss.part.<id>.down` and `boss.enraged` removed. V3 caption line likewise. HUD row: link `hud.md`.
5. `design/gdd/plane-kits-lancer-leech.md` UI Requirements: `kit_bar_ratio` → `kit_bar(slot) -> (num, den)` ints; drone lamp placed on the icon row after the drone ticks (not beside the bar).
6. `design/gdd/chain-tracker.md` F6: `BAR_PX` "~96 / ~84" → "94 (1-2P) / 82 (3-4P), set by HUD 20"; Visual table Drop row: "plate drops 3 px" → "digits shift down 3 px inside the plate".
7. `design/gdd/game-events-and-session.md`: HUD (20) row link `hud.md`; Open Question 1 closed ("gained = 0 shows the MAX icon on the lives display for 60 ticks, HUD Rule 22").
8. `design/gdd/powerups-and-drops.md` UI Requirements: "the 1-up banner (from Session extend_awarded)" → "a plate-local `+gained` tag and Gold edge step on the lives display (HUD 20 Rule 22); no banner".
9. `design/gdd/localization.md` F3 and Rule 26: add tiers D12 (digit 12, cell 8, sep 3) and D10 (digit 10, cell 6, sep 2); cell map includes `+` and `%` in every tier.
10. `design/gdd/input-and-player-mapping.md`: HUD (20) row → interface `glyph_family(slot)`, `next_join_slot()`, `action_glyph(slot, action)`; note `join.prompt` is not drawn by the HUD (icon-only join plate).
11. `design/gdd/display-scaler-and-bezel.md` HUD rows: "HUD scale changes `play_top`; HUD ships layout sets per scale (Accessibility 28 decides)".
12. `design/art/art-bible.md`: §7.2 "pip mark" → pip stack plus identity line in the outer 4 px; §7.2 score "8 digits / 6 digits" → "9 digits in every mode"; §7.2 counter form in 2P and 11x11 counters in 3-4P; §7.3 "plate drops 3 px" → digits shift down 3 px inside the plate; §7.4 boss-row numeric `x 336-359` in D10; §7.5 add digit tiers D10 and D12 (Bengali digits below 17 px as a numeral-only exception); §4.1 or §7.3 add `#FFE27A` if accepted.
13. New: `design/gdd/critical-break.md` (when written) must provide `cb_armed(slot)` and `critical_break_banner_requested`; Wave director must provide `stage_progress()` and `warning_requested`; Bullet manager must provide `enemy_bullets_alive`.

## 4. Registry candidates
```yaml
constants:
  - name: hud_chain_bar_px
    value: "94 (1-2P), 82 (3-4P)"
    unit: px (chain plate interior width; Chain F6 BAR_PX)
    range: "plate interior"
    source: design/gdd/hud.md (Rule 17, HF2)
    referenced_by: [hud, chain-tracker]
  - name: hud_boss_bar_px
    value: "312 outer, 310 interior (x 24-335)"
    unit: px
    source: design/gdd/hud.md (Rule 26, HF3)
    referenced_by: [hud, boss-and-boss-parts]
  - name: hud_digit_tiers
    value: "D24 cell15/sep6, D17 11/4, D16 10/4, D12 8/3, D10 6/2"
    unit: px (digit height 24/17/16/12/10)
    note: "D12 and D10 added by HUD; Localization F3 formula"
    source: design/gdd/hud.md (Rule 12)
    referenced_by: [hud, localization]
  - name: score_roll_instant_max
    value: 5000
    unit: points
    range: "0-50000"
    source: design/gdd/hud.md (HF1)
    referenced_by: [hud]
  - name: banner_wait_max
    value: 180
    unit: ticks
    range: "60-300"
    source: design/gdd/hud.md (Rule 27)
    referenced_by: [hud]
formulas:
  - name: score_roll
    expression: "shown' = target if target - shown <= instant_max or target < shown else shown + ceil((target - shown) / roll_div)"
    variables: [target, shown, score_roll_instant_max, score_roll_div]
    output: "shown <= target, monotone; ~32 ticks for a 1,250,000 gap"
    source: design/gdd/hud.md (HF1)
    referenced_by: [hud]
  - name: boss_bar_px
    expression: "fill_px = (bar_permille * 310 + 999) div 1000; tick_px = phase_tick * 310 div 1000"
    variables: [bar_permille, phase_tick, critical_notch]
    output: "1-310 px"
    source: design/gdd/hud.md (HF3)
    referenced_by: [hud, boss-and-boss-parts]
```
Existing entries whose `referenced_by` gains `hud`: `play_top`, `canvas_size`, `chain_window`, `chain_cap`, `score_display_digits`, `bn_width_reserve_pct`, `bn_size_s`, `digit_grouping`, `digit_cell_width`, `format_int`, `team_pct_by_members`, `max_lives`, `max_drones`, `continue_seconds`, `setting_access_reduce_flashing`, `team_join_grace`.

## 5. Conflicts
No conflict with locked registry values (`play_top` 48 / 72 and `canvas_size` are kept). Conflicts with other docs, all resolved in the HUD GDD and listed as amendments:
- Boss UI (bilingual caption, "ENRAGED" word, 12 px text) vs art bible (fight HUD is icons and numerals; row is 12 px tall) → icons plus D10 numbers.
- Co-op V1 tag (8 px digits, centred on bracket) vs art bible minimum 12 px and plate geometry → D12, inside member plates.
- Art bible §7.2 (score 8 / 6 digits) vs Scoring (9 digits) → 9 digits everywhere.
- Art bible §7.2 14x14 icons up to 5 in all modes vs 90 px and 180 px columns → counter forms; 11x11 in 3-4P.
- Scoring "MAX tag" (word) vs icons-only fight HUD → icon.
- Art bible §7.3 "plate drops 3 px" vs the strip bound → digits drop inside the plate.
- Chain F6 `BAR_PX` ~96 / ~84 → 94 / 82.
- Powerups "1-up banner" → in-strip tag.
- Plane kits "lamp beside the bar" → on the icon row.
- Session OQ1 closed.
- Display scaler/Accessibility: HUD scale 125 / 150 % changes `play_top`, which the registry locks (OQ9).
- Art bible 17 px Bengali minimum vs D10 / D12 Bengali digits (OQ1).

## 6. Open risks
- 3-4P strip is very tight (OQ2); the kit bar at y 28-31 and 11x11 icons may fail on REF-PHONE.
- D10 / D12 Bengali digits may be illegible; fallback widens fields and costs layout space.
- Four undesigned interfaces (Critical Break, Wave director warning and progress, Bullet manager `enemy_bullets_alive`, Accessibility settings) are provisional.
- The banner gate depends on Wave director, Bombs and Boss really clearing the field; if they do not, banners are skipped.
- Dropping the join text and the "ENRAGED" word may confuse first-time players (OQ5, OQ7).
- HUD scale needs a different strip height per scale and conflicts with the locked `play_top` (OQ9).
- Pixel counts (rects, 43 px lane, 24 px zone) are exact on paper but unproven in the font spike; the layout lint (AC-03) is the guard.
- The existing prototype `src/ui/hud/hud.gd` must be replaced (flash, result panel, English text, direct polling).
