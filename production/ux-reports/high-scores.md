# UX Review: High Scores and Records

**Spec reviewed**: `design/ux/high-scores.md`
**Date**: 2026-11-03
**Checklist**: Phase 3A (screen spec), tier COMPREHENSIVE, canvas 360x640
**Reviewer**: ux-designer (Claude), auto-approve in force

## Verdict before fixes: NEEDS REVISION
## Verdict after fixes: APPROVED WITH CONDITIONS (stretch Online strings and 4 cross-document amendments below)

## Findings before fixes (blocking)

1. Loading, empty and error states were happy-path: no real states for Web with blocked storage, no Steam identity, Switch/mobile with no adapter, Friends with no friends, Around me with no entry, per reason code text, or a loading duration. No statement that local boards have no loading state.
2. Open conflict: Save Rule 5 "ranked if >= 1" vs top 10 (F1 and Online Rule 1 say top 10 too).
3. Open conflict: co-op rank per row vs one team rank.
4. Open conflict: solo entries for unknown planes unreachable.
5. Accessibility section was stale ("no accessibility-requirements.md"); no contrast ratios; no screen-reader stance; Alarm Red text is 3.95:1 (fails 4.5:1).
6. Stretch layout overflows: online row 348 px > 328; six tabs did not fit.
7. Ambiguity inside ACs: filtered ranks, lead player, empty-state wording vs open questions.
8. Header: Platform Target omitted Switch and the tier; ACs had no error/loading/platform criteria; events had no stated nulls for no-op inputs.

## Fixes applied

1. Header: Status, Platform Target (PC, Web, Switch, mobile; COMPREHENSIVE), Sources, Patterns used (+P26, new Status block flagged as proposed P29), revision note.
2. Layout Zones: scrolling 3-tab window with hints, unlisted tabs, scrolling sub-tab row, Status block area, notice zone rules.
3. Row layout: one rank per co-op team row; lead player defined (highest `players[].score`, tie lower slot); online row 321 px fit; "Other planes" chips and records.
4. Component Inventory: Status block, extended chips.
5. States and Variants: local loading (none by design), empty, 1CC-empty, run-did-not-place (top-10 rule), practice, unknown plane, records; static notices for ReadOnly/Unavailable/Reset; full Online matrix (platform tab unlisted, not enabled, Steam absent, Web/itch install id with friend codes, Web storage blocked, re-consent, loading max 10 s, offline with/without cache, backoff, each reason code, empty, friends none, around-me none, failure styling).
6. Interaction Map: RETRY with `ui_deny` in backoff, scope row, paging, status block focus, focus-order/button summary.
7. Events Fired: online fetch/retry rows and explicit nulls.
8. Data Requirements: reason codes, service state, adapter kind, storage flag, unknown plane ids, lead player.
9. Accessibility: rewritten for COMPREHENSIVE: contrast ratios (Cream 14.4, Gold 11.2, dim 6.5, Red 3.95 so never text, edge 2.2 with HIGH contrast to Cream), untimed note, screen reader scope, twins.
10. Localization: char limits for headline, detail, notice (+40% Bengali) and new keys.
11. Acceptance Criteria: co-op single rank, unknown plane reachable, top-10 limit, local loading/notice, and six stretch criteria for loading, platform absence, reason codes, row width, empty variants; empty-state AC updated.
12. Open Questions: closure note; new Q18 (toast under untimed menus).

## Cross-document amendments requested

1. **`design/gdd/save-settings-high-scores.md`, Core Rules, Rule 5.** Current: "A run is **ranked** if its **board score** is at least `min_ranked_score` (1)." Proposed: "A run is **ranked** if its board score is at least `min_ranked_score` (1) **and** it places within the top `board_size` (10) of its board (F1: `rank_index < board_size`)." Reason: Rule 5 contradicts F1 and Online Rule 1.
2. **`design/gdd/save-settings-high-scores.md`, Rule 11 (`players`)** add: "Lead player of a co-op entry for display = highest `players[].score`, ties to the lower slot; `players[]` is in slot order." Also add to Menus below.
3. **`design/gdd/menus-title-plane-select.md`, Rule 40 and the "unknown plane" Boards edge case.** Current: Rule 40 "...An unknown plane id shows a generic plane icon and the raw id in Latin" and edge case "tab not shown but entries still appear on co-op boards". Proposed: "A solo board stored under an unknown plane id appears as an extra Solo sub-tab chip (generic icon + raw id, cut to 8 characters + `...`); the plane-select list does not show it. Lead player = highest individual score, ties to lower slot. A co-op row has one rank (team rank by `team_score`)." Also add Menus note: filtered 1CC lists keep true board ranks; empty 1CC board string `menu.scores.empty_1cc`.
4. **`design/gdd/coop-and-team-chain.md`, Open Question 8 (row 526).** Current: "Do co-op high-score boards rank `team_score`, or best single player in a team? Separate boards per count?" Proposed: mark closed: "Closed 2026-11-03: Rule 18 and Save F2/F3. One team entry per board, ranked by `team_score`, separate boards per player count; display shows one team rank."
5. **`design/gdd/online-leaderboards-boss-rush.md`, Rule 6 table vs `docs/architecture/adr-0007-online-services.md` section 2 "Adapters".** Current: GDD "Consoles, mobile (later): out of scope"; ADR "`HttpAdapter` (all platforms)". Proposed: state that Switch / Switch 2 and iOS / Android have no adapter at launch (NullAdapter, Online tab not listed, P22) until a per-platform adapter ships; note `HttpAdapter` serves Web, itch and PC only. Please confirm; if mobile should use `HttpAdapter`, the tab is listed there and the Web states apply.
6. **`design/ux/arcade-ui-style.md` palette row for Alarm Red** (art-director): Current "failure/corruption text". Proposed: "plate edge and glyph fill for failure; text stays Cream (Alarm Red on Char is 3.95:1, below 4.5:1)."
7. **`design/ux/interaction-patterns.md`**: add P29 Status block (empty / loading / error block) and close Gap 8; update Back table (no change needed).
8. **`design/gdd/online-leaderboards-boss-rush.md` Rule 13 / Menus F10**: online row worst case 348 px; adopt handle display cut to 8 characters + `...` in rows (full handle in detail strip) and relative date in the detail strip.
9. **`design/gdd/localization.md`**: add keys `menu.scores.empty_hint`, `empty_1cc`, `practice_note`, `readonly`, `unsaved`, `reset_note`, and the `status_*` family with limits in the spec.

## Still open

- Q3 (Input adds no tab verbs), Q6 (remember last view), Q7 (four Target chips at 76 px), Q9 (analytics), Q13 (date format on strip), Q14 (Delete my data location), Q16 (touch boards on non-touch), Q17 (attract page), Q18 (toast under untimed menus). 4-stage Records layout still undefined. Per-player score in the co-op strip was not added (width and no owner request). All advisory or needing another owner.
- Bengali strings are drafts pending native review.
