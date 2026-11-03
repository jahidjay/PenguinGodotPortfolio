# UX Review: HUD Design (`design/ux/hud.md`)

**Date**: 2026-11-03 | **Checklist**: Phase 3B (HUD) + general completeness/quality | **Owning GDD**: `design/gdd/hud.md`

## Verdict

- **Before fixes: NEEDS REVISION.** Layout, element specs and ACs were strong, but the document lacked required sections (purpose, context, navigation/entry/exit, interaction map, events fired, transitions, tuning knobs, per-element visibility/owner/priority, notification priority, error/degraded states, contrast ratios, colour-vision variants, screen-reader scope, banner px budgets), and three recorded conflicts (victory portrait, Continue timer variants, strip-mark clipping) were unresolved, plus one found geometric conflict (pick plate vs boss zones).
- **After fixes: APPROVED WITH CROSS-DOCUMENT AMENDMENTS PENDING.** No blocking issue remains in the UX file; GDD edits (below) are needed to keep the GDD and spec consistent.

## Phase 3B checklist results

| Item | Before | After |
|---|---|---|
| HUD philosophy | Pass | Pass |
| Information architecture covers all systems with UI requirements | Partial (no visibility/owner/priority) | Pass (Element Reference + coverage note) |
| Zones with safe-zone margins per platform | Partial (rules, no numbers) | Pass (margin table) |
| Per-element spec (zone, trigger, source, priority) | Partial | Pass |
| States by context | Pass; no degraded/loading/empty | Pass |
| Visual budget (elements, screen %) | Partial (no banner %) | Pass (20.0% / 10.4% / 15% proposal) |
| Platform adaptation | Pass | Pass |
| Tuning knobs | Missing in UX file | Pass |
| Nothing over centre without hide rule | Pass (gate) | Pass; pick plate/zone overlap fixed |
| Colourblind variants | Partial | Pass |
| Notification queue/priority | Partial | Pass (channel table) |

## General completeness and quality

- Header, patterns used, layout, component inventory, data sources, localization, accessibility, ACs (17, with perf UX-16 and resolution UX-15): present.
- Added: Purpose & Player Need, Player Context, Navigation/Entry/Exit/Focus, Interaction Map (no input), Events Fired (null stated), Transitions, loading/empty/degraded states.
- No data element owned by "UI"; update triggers stated (pull/push).
- Advisory items left open: dim-text contrast, banner character counts, 4P legibility on phone.

## Fixes applied

1. **Header**: status to Reviewed, revision note added.
2. **New sections** Purpose & Player Need, Player Context on Arrival, Navigation Position and Entry/Exit (hard cuts, no focus, no Back).
3. **Information Architecture**: new Element Reference table (29 elements: zone, visible when, data source/owner, P1-P3 priority) and a GDD coverage note; inventory item 9 corrected.
4. **Safe zone**: per-platform margin table (HUD inset 0, platform inset handled by Display scaler) and a hard pixel-bound requirement.
5. **Pilot portrait** (conflict 1): victory pose removed from the HUD (HUD is hidden in Tally; Tally already draws a 96x96 victory portrait); pose priority and reset rules defined (marked as derived); AC UX-20, OQ 1 resolved.
6. **Continue plate** (conflict 2): active total `T`, bar/red formula, 30 s two-digit fit, EXTENDED worked example, UNTIMED rule aligned with Accessibility Rule 22 (countdown shown if another slot is Alive; glyph only if none), accept glyph via `action_glyph(slot, CONTINUE_ACCEPT)` instead of hard-coded START; UX-11 extended, UX-18 added, OQ 4 resolved.
7. **Strip mark** (conflict 3): clamp rule (inflate 2 px, clip to x>=col+4 / <=355 for P2, y<=36 or 59), worked examples, UX-19.
8. **Pick plate vs boss zones** (new finding): zones draw above the plate; Menus keep-out corner; UX-22, OQ 20.
9. **Degraded states** table, **Notification priority** table, **Interaction Map**, **Events Fired**, **Transitions and Animations**.
10. **Visual Budget**: banner screen share and one-banner rule.
11. **Tuning Knobs** section (15 rows with ranges).
12. **Accessibility**: UNTIMED row corrected; contrast ratio table (computed), colour-vision variants, screen reader/TTS scope (out per tier section 4), subtitles N/A.
13. **Localization**: banner pixel budgets, +40% rule, Warning height arithmetic (76.4 of 80 px).
14. **ACs**: UX-18..UX-22 added.
15. **Open Questions**: 1 and 4 resolved; 13 updated (Tally says Fire accepts Continue, HUD GDD says START); new 16-20.

## Cross-document amendments requested

1. **`design/gdd/hud.md`, Rule 22 (portrait sentence)**. Current: "to **victory** on the tally, else **neutral**". Proposed: "to **neutral** on `boss_defeated`; the victory pose is drawn by the Stage tally (96x96 hero portrait), not the HUD, because the HUD is hidden in Tally mode." Also **AC-32**: current "`player_died` -> hurt 120 ticks; `boss_intro_started` -> determined; tally -> victory"; proposed: "...; `boss_defeated` -> neutral; no victory pose in the HUD". Also GDD Information inventory/Interaction text if it mentions victory.
2. **`design/gdd/hud.md`, Formula HF2 (Continue bar), AC-37, Rule 24**. Current: `bar_px = ceil(BAR_PX x remaining / continue_seconds)`, "remaining 0 to 10", AC-37 assumes 10 s. Proposed: replace `continue_seconds` with `continue_total` (resolved from `access.continue_timer`: 10 / 30 s; absent when UNTIMED with no other slot Alive); `remaining` range 0 to 30; add AC-37b EXTENDED: 14 s -> 44 px, red from 7.5 s. Rule 34a(c) current "UNTIMED: no countdown or drain bar"; proposed: "UNTIMED shows the EXTENDED countdown while another slot is Alive; no countdown/bar only when none is Alive".
3. **`design/gdd/game-events-and-session.md`, Continue UI contract (section around line 210/367)**. Add: Session exposes `continue_total` (seconds, resolved from the override; nullable) next to `continue_remaining`. Currently the HUD can only read `continue_seconds` (10).
4. **`design/gdd/hud.md`, Rule 30a (strip mark)**. Current: "2 px outside the element's rect". Proposed: add "clamped to the column's mark clip rect: x from column origin + 4 (P2 in 2P up to x 355), y 0 to the row limit 36 (48 px strips) or 59 (72 px strips); a clamped side sits on the clip edge". Also `design/gdd/tutorial.md` Rule 21 / AC if it restates 2 px outside.
5. **`design/gdd/hud.md`, Layout table "Compact 48" Pick plate row and Rule 23**. Current: "`shares_lane` with the boss row (hides the boss bar under it only; zones stay)" — geometrically false for columns 0 and 3. Proposed: "the zones (0,36,24,12) and (336,36,24,12) draw above the pick plate; the plate's bottom outer 19x10 corner is clipped in columns 0 and 3". Also `design/gdd/menus-title-plane-select.md` Rule 52 / pick plate: keep cursor and labels out of that corner.
6. **`design/gdd/hud.md`, Rule 24 and Open Question 10; `design/gdd/stage-tally` / Tally Rule 17; `design/gdd/input-and-player-mapping.md`**. Current: HUD default accept = START (which pauses); Tally: Fire accepts the Continue. Proposed: Input defines one `CONTINUE_ACCEPT` verb for both, with explicit START-versus-Pause priority while a slot is in Continue. HUD already follows the verb via `action_glyph`.
7. **`design/gdd/hud.md`, Visual/Audio Warning row**. Current "text opacity pulse ... at 1.5 Hz at most". Proposed "1 Hz (Rule 31, HF9)". (Open Question 10 already carries this; also CB `cb_banner_wait_max` 120 vs 180.)
8. **`design/gdd/hud.md`, Open Question 14/Rule 22 note, HF4**. Add W = 14 (compact kit bar) to HF4 (existing UX OQ 12).
9. **`design/gdd/hud.md`**: stale AC-45 `warning_requested` -> `warning_started`; AC-13 tick 36 -> about 32 (UX OQ 15).

## Still open

- Switch TV overscan / Web embed cropping (needs hardware/Display owner) - OQ 7.
- Dim text contrast 2.2:1 in STANDARD (advisory; art-director) - OQ 17.
- Banner character counts (need font metrics and Warning plate width) - OQ 18.
- Strip-mark overdraw acceptance - OQ 19; part-kill restart rule - OQ 16.
- Touch: join plate hiding and Continue tap hint remain proposals - OQ 2.
- Continue accept verb (START vs Fire) - OQ 13.
- D12/D10 Bengali digit legibility, 4P strip readability on REF-PHONE: playtest/font spike - OQ 14.
- Contrast ratios are computed, not measured; art pass must verify.
- Menus-owned screen-reader scope for menus (Vertical Slice reconsideration) does not affect the HUD.
