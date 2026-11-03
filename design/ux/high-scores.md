# UX Spec: High Scores and Records

> **Status**: Approved (2026-11-03) — previously: Reviewed (`/ux-review` 2026-11-03; blocking issues fixed, see `production/ux-reports/high-scores.md`)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (final doc closeout)**: Status block and failure styling now offer the text-only **Alarm Flare `#F2494D`** headline beside the `#E03A3E` edge/glyph rule (art bible 4.1, style guide 3.1 "two reds, two jobs"); UI cue ids rewritten to `sfx_ui_*`; Open Question 14 closed - **Delete my online data** lives in Settings > Online only.
> **Revision 2026-11-03 (UX consistency check, wave 5)**: the "Tab not listed (platform)" row no longer claims an OL-versus-ADR-0007 conflict (both now state Switch / Switch 2 and mobile ship no adapter); Open Question 14 restated as a live conflict for the screen-map owner.
> **Journey Phase(s)**: unknown (no `design/player-journey.md`)
> **Template**: UX Spec
> **Platform Target**: PC Steam/itch (keyboard + gamepad), Web (keyboard/mouse; gamepad when attached), Switch / Switch 2 (gamepad only, no pointer), iOS and Android (touch, Target; mobile deprioritised). Gamepad-first, portrait 360x640 canvas. Accessibility tier: COMPREHENSIVE (`design/accessibility-requirements.md`).
> **Sources**: `design/gdd/menus-title-plane-select.md` (Rules 38-41, F10, V/A "Board" and "Touch row pitch" rows, High scores mock-up, Boards edge cases, AC-45..48, Open Questions 10), `save-settings-high-scores.md` (Rules 4-14, 21-23, 28, 30, 32; F1-F4; unknown-plane edge case), `online-leaderboards-boss-rush.md` (Rules 6, 10-13, 19, 25, 29, 31, 33, Stretch), `docs/architecture/adr-0007-online-services.md` (adapter selection, Web storage fallback, Steam extension scope), `scoring.md` (F8 display clamp), `coop-and-team-chain.md` (Rule 18: co-op ranked by `team_score`), `touch-controls.md` (Rules 2, 30; TF7, TF8), `accessibility-options.md` (Rules 8-9, 32 via Save, text size), `design/accessibility-requirements.md`, `localization.md` (Rule 17, F3), `plane-kits-sentry-breaker.md` (Target planes), `arcade-ui-style.md`, `interaction-patterns.md`. Where this spec and a GDD disagree, the GDD wins.
> **Patterns used**: P01, P02, P03, P05, P06, P08, P11, P16, P21, P22, P26 (see `interaction-patterns.md`). Fills pattern **Gap 8** (empty / error / loading states) for this screen. **New pattern accepted:** the **Status block** (a plated message block that replaces the board rows; see Layout and States) was added to `interaction-patterns.md` as **P29** on 2026-11-03 (wave 5). The Coach card's single-button modal over a stopped field is **P30**, a different pattern.

> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: the Status block is confirmed as **P29** in the pattern library (not a proposal); the Alarm Red rule is restated as the stricter "never a text fill" form; Open Question 1 is marked closed now that the Menus GDD amendment has landed.
> Revised 2026-11-03 after /ux-review: added real empty, loading, error and platform-absent states for local and Online boards; resolved ranked-vs-top-10, one team rank per co-op row, unreachable unknown planes, filtered ranks and lead player; fixed stretch width overflows; replaced the stale accessibility section (tier COMPREHENSIVE) with contrast ratios and screen-reader scope; added Data, Events and Acceptance rows for the new states.
> **Related spec**: `design/ux/results-name-entry.md` (board-after-run variant). This spec owns the **shared board view**; that spec only adds the highlight, PLAY AGAIN and the entry rules.

HIGH SCORES is a single shared screen with three MVP tabs (Solo, Co-op, Records). It is entered from Title, and by the after-run variant from Results. **Tier markers:** MVP = Solo (Lancer, Leech), Co-op 2P/3P/4P, Records. **Target** = Sentry and Breaker sub-tabs, touch boards. **Stretch** = Rush, Boss and Online tabs. Stretch items are marked **[STRETCH]**.

---

## Purpose & Player Need

The player wants to answer three questions fast: "Where do I rank?", "Who beat me, and how?" and "What is my best chain?". Mastery over many sessions is the long-term goal (Every Hit Counts), so the board must feel permanent and honest: only real endings and game overs appear, never abandoned runs. The screen is calm, read-mostly and never competes with play. It must work with one thumb on a pad and with a finger on a phone.

## Player Context on Arrival

| Arrival | Emotional state | Notes |
|---|---|---|
| From Title (HIGH SCORES) | Curious, comparing | Default view: Solo tab, first listed plane, filter All. Focus on rank 1 |
| After a run (see `results-name-entry.md`) | Proud or "one more go" | Opens on the run's board id; new entry highlighted; not specified here |
| Fresh profile | Neutral | Empty board with one INFO row; no shame wording |
| After a save problem | Worried | Toast explains once (Save notices); board shows what could be loaded |
| Co-op group | Friendly rivalry | Co-op tab shows team rows; detail strip shows every player |

No time pressure exists; nothing on this screen is timed. Title's attract timer does not run here.

## Navigation Position

`Title -> **HIGH SCORES** -> (Cancel) Title`. Second entry: `Results -> (name entry) -> BOARD (after-run variant) -> Lobby | Title`. [STRETCH] sub-screens under the Online tab: `Consent`, `Handle`.

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Title | Confirm on HIGH SCORES | Nothing; default view |
| Results / Name entry | Confirm after submit | Board id of the run, new-entry index (after-run variant) |
| Settings > Clear scores (via Title) | Hold-confirm completed, then return to Title | Boards empty on next open |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Title | Cancel (Bomb/Back, Esc, C) or Back plate | Focus restored on HIGH SCORES (P05) |
| Lobby (after-run only) | PLAY AGAIN | Owned by `results-name-entry.md` |
| [STRETCH] Consent / Handle | Confirm on a CONNECT row in the Online tab | Cancel returns to the Online tab |

Cancel never discards anything on this screen: it is read-only.

---

## Layout Specification

### Information Hierarchy

1. The rows of the selected board (rank, score, who).
2. Tab row (which board family).
3. Sub-tab and filter rows (which board, All or 1CC).
4. Detail strip for the focused row (every player, chain, Critical Breaks).
5. Status or notice lines (empty, read-only, offline).
6. Prompt bar / Back plate.
7. Toasts.

### Layout Zones

Canvas 360x640, inner margin 16 (inner width 328). Pad/keyboard sizes; row heights from Menus V/A (Board 10 x 28 = 280, tabs 24).

| Zone | y range (px) | Contents |
|---|---|---|
| Tab row | 16-40 | Solo, Co-op, Records (3 x ~106 wide). [STRETCH] adds Rush, Boss, Online. With more than 3 tabs listed the strip is a **window of 3 tabs** with `<` / `>` glyph hints at its ends; the selected tab is always inside the window and the window moves one tab at a time. Locked tabs and tabs the platform cannot serve (P22) are not listed |
| Sub-tab row | 44-68 | Solo: plane chips (MVP 2, Target 4) plus one chip per **unknown plane id** that has a stored board (see "Other planes" below). Co-op: 2P / 3P / 4P. Records: none (row hidden, zones below move up 28 px). [STRETCH] Online: scope Global / Friends / Around me. The row scrolls (P26) when its chips overflow 328 px |
| Filter row | 72-96 | `Filter: All` or `Filter: 1CC only` (CHOICE). Hidden on the Online tab (online boards are verified bests; no 1CC filter is defined) |
| Board rows | 104-384 | 10 rows x 28 px, no gap. Rank 1 on top. **Also the Status block area:** empty, loading, offline and error states replace the rows here as one plated block (280 px tall max), so a state is never hidden below the fold |
| Detail strip | 392-484 | 328 x 92 plate, for the focused row. Hidden when no row exists |
| Free / notice | 484-556 | One notice line (2 lines Latin, 3 Bengali): "Scores are read-only", "Practice runs are not ranked", "Offline - last updated {n} days ago". At text size 3 it is part of the scrolling content, never clipped |
| Toast | 560-584 | Strip 328x24 (P11) |
| Prompt bar | 600-640 | Glyphs and verbs for the current device |

### Row layout (F10, worst case co-op lead row)

| Part | Width (px) | Notes |
|---|---|---|
| Rank | 26 | 2 digits x 11 + 4; `format_int`; Bengali digits on the same grid |
| Initials | 27 | 3 Latin characters, always Latin in both languages |
| "+N" tile | 18 | Co-op only; N = other played slots (text, not colour) |
| Plane icon | 18 | 14 + 4; generic icon + raw id (Latin) for an unknown plane |
| Score | 111 | 9 digits Gold, tabular; display clamp 999,999,999 |
| Stage reached | 15 | 1 digit |
| Badges | 34 | "C" tile (continues used) and "1CC" tile; each tile is text on a plate |
| Total | 249 | 79 px spare (24%); covers the text-size step |

**Rank on a co-op row (decision).** A co-op board ranks **one team entry** by `team_score` (Co-op Rule 18, Save F2). So one row = one team = one rank number. There is no per-player rank on this screen. The row shows the lead player's initials and "+N"; the detail strip lists every player. **Lead player** = the `players[]` entry with the highest individual `score`, ties to the lower slot (derived from the existing `players[].score` field; no new data). `players[]` order is slot order (Save Rule 11), which is what lets the strip draw P08 badges.

**[STRETCH] Online row (worst case, fits).** Rank 26 + handle 81 + "+N" 18 + plane 18 + score 111 + stage or bosses 15 + badges 34 + verified tile 18 = **321 px of 328**. The handle shows at most 9 cells: a 12-character handle is cut to its first 8 characters plus an `...` glyph cell; the full handle shows in the detail strip. Relative date moves to the detail strip. (Replaces the 348 px worst case that overflowed.) At text size 1-3 the row wraps to two lines and grows; nothing is clipped.

**Other planes.** A solo board whose plane id is not in the plane registry (for example after a downgrade or a removed plane) still exists in the save (Save: unknown planes are never dropped). It appears as an extra Solo sub-tab chip after the known chips: generic plane icon + the raw id in Latin, cut to 8 characters + `...` if longer. Chips exist only for ids that have a board for the current stage count. Selecting it shows that board like any other. Records for an unknown plane id are listed below the known planes with the same icon + raw id heading.

### Component Inventory

| Component | Type | Interactive | Pattern | Notes |
|---|---|---|---|---|
| Tab strip | CHOICE row | Yes | P03, P16 | Left/Right changes tab; selected tab filled + underline + text, not colour |
| Sub-tab chips | CHOICE row | Yes | P03, P16, P26 | Plane icon + name; same filled-chip rule. Extra chips for unknown plane ids; scrolls on overflow |
| Status block | INFO, **P29** (accepted into `interaction-patterns.md` 2026-11-03, wave 5) | Retry action only on the Online tab | P02 | Plated block in the board area: icon tile (glyph, not colour) + one headline line + one detail line + optional action row. Used for every empty / loading / offline / error / platform state. Alarm Red `#E03A3E` appears only as the plate edge and the "!" glyph tile, never as text colour (3.95:1 on Char is below 4.5:1). *(2026-11-03, final doc closeout:)* the block's **headline** line may instead be drawn in the text-only **Alarm Flare `#F2494D`** (4.76:1, art bible 4.1) - one headline per screen, detail line stays Cream, "!" glyph and Alarm Red edge still required, Cream under `hud_contrast` HIGH |
| Filter | CHOICE row | Yes | P03 | All / 1CC only; Confirm also cycles |
| Board row | LINK-like row | Focus only | P01, P02 | Focus = 3 px Cream border + arrow; Confirm does nothing (see Interaction Map) |
| Rank / initials / plane / score / stage | INFO | No | — | Score Gold only |
| "C" and "1CC" tiles | INFO | No | — | Legend in detail strip header |
| Detail strip | INFO | No | P08 | One line per player; P08 badge per player |
| Empty row | INFO | Skipped by row focus | P16 | "No scores yet" |
| Notice line | INFO | No | — | Read-only save, Offline age |
| Toast strip | Feedback | No | P11 | Save notices never dropped |
| Back plate | BUTTON | Yes (pointer/touch) | P05 | At least 24x24 px (touch: `touch_item_h`) |
| Records block (per plane) | INFO (focusable for scroll) | Focus only | P01 | Best chain per boss, 1CC counts |
| [STRETCH] Status tile, CONNECT row | INFO / LINK | Yes (CONNECT) | P03 | Online tab only |
| [STRETCH] Device chip (Pad/Key, Touch) | CHOICE | Yes | P03, P22 | Solo tab, shown only when a `/touch` board exists or the platform has touch |

### ASCII Wireframe

Solo tab, Lancer, MVP. Cursor on rank 2. (Not an after-run view.)

```
+----------------------------------------------------------+ y0
|  [Solo*][ Co-op ][Records]                               | y16
|  [ Lancer* ][ Leech ]                                    | y44
|  Filter: All                                             | y72
|   1  AAA  [L]  9,100,000   2  [C][1CC]                   | y104
| >[ 2  KAZ  [L]  4,200,000   2  [1CC]   ]<                |
|   3  BEE  [L]  3,000,000   2  [C]                        |
|   ...  (10 rows x 28 px)                                 | to y384
|  +----------------------------------------------------+  | y392
|  | KAZ  Lancer   Chain 187   Critical Breaks 3        |  |
|  | C = continued   1CC = no continues                 |  |
|  +----------------------------------------------------+  | y484
| [toast strip, y560]                                      |
| [A] -   [B] Back   [<][>] Tab                            | y600
+----------------------------------------------------------+ y640
```

Co-op tab, 3P, row 1 focused (shows "+N" and the strip):

```
|  [ Solo ][Co-op*][Records]                               |
|  [ 2P ][ 3P* ][ 4P ]                                     |
|  Filter: All                                             |
|>[ 1  AAA +2 [L]  6,200,000   2  [1CC]   ]<               |
|  +----------------------------------------------------+  |
|  | P1 AAA  Lancer  Chain 120  CB 2                    |  |
|  | P2 BEE  Leech   Chain  64  CB 0                    |  |
|  | P3 KAZ  Lancer  Chain  88  CB 1                    |  |
|  +----------------------------------------------------+  |
```

Records tab (sub-tab row removed):

```
|  [ Solo ][ Co-op ][Records*]                             |
|  LANCER                                                  |
|    Best chain   Boss 1  112    Boss 2  187               |
|    1CC          2 stages: 3                              |
|  LEECH                                                   |
|    Best chain   Boss 1   --    Boss 2   --               |
|    1CC          2 stages: --                             |
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default (from Title) | Confirm HIGH SCORES | Solo tab, first listed plane, filter All, focus on rank 1 |
| After-run variant | Arrive from Results | Run's board id, new entry highlighted; see `results-name-entry.md`. Everything else is this spec |
| **Loading (local)** | Screen open, tab, chip, filter change | **No loading state exists for local boards by design.** Boards are in memory from the boot load (Save Rule 22 runs before Title), so rows appear within one frame. A loading state would be a bug. If Save is still `Unloaded` (impossible after Title), treat as "No Save" below |
| **Empty board** | Board has 0 entries (fresh profile, a plane never flown, a player count never played, or only runs that did not rank) | Status block, headline "No scores yet" (`menu.scores.empty`), detail line "Finish a run to put your initials here" (`menu.scores.empty_hint`). Detail strip hidden. Focus rests on the Filter row (Records: the tab row), so the screen is never a dead end. No shame wording |
| Filter hides all rows | 1CC only on a board with no 1CC entry | Status block, headline "No 1CC scores yet" (`menu.scores.empty_1cc`, Open Question 15 closed: the GDD string `menu.scores.empty` stays for the plain empty board); Filter stays focusable (Menus edge case) |
| Run did not place | Run scored >= 1 but below rank 10 of a full board, or scored 0 | Nothing is added; the board is the top 10 only (Save F1: ranked = score >= `min_ranked_score` AND `rank_index` < `board_size`). This screen never explains an individual run; the after-run variant (`results-name-entry.md`) shows the "not placed" text |
| Practice only | Player only plays with an assist (Save Rule 32) | The board is the empty-board state plus the static notice line "Practice runs are not ranked" (`menu.scores.practice_note`), shown on every empty board and whenever the notice zone is otherwise free (Open Question 12 closed) |
| Partly filled board | 1-9 entries | Real rows then no placeholder rows (no `---` filler) |
| 4P/Co-op with unknown plane | Entry plane not a known id | Generic plane icon + raw id in Latin (Menus Rule 40) |
| Unknown plane id, solo | Entry stored on `solo/<id>` (Save edge case) | Reachable through an extra sub-tab chip with generic icon + raw id (see "Other planes"). Closes the old Open Question 1: the Menus text (tab not shown) is kept for the **plane-select** list, and this screen adds the chip so no entry is unreachable. Requires a Menus amendment (report) |
| Co-op row rank | Any co-op board | One rank per team row (see "Rank on a co-op row"); never per player |
| Records, no data | Plane never played | Dash `--` in each cell; never blank |
| Records, unknown plane | Plane id in records not in the registry | Shown after the known planes with generic icon + raw id heading (consistent with "unknown planes are never dropped") |
| **Corrupted / recovered save** | `scores.json` bad, `.bak` used (Recovered) | Boards show backup content; toast "restored from backup" once (Save notice, never dropped) |
| **Corrupted / reset save** | Main and `.bak` bad (Reset) | Boards empty (empty-board state); toast tells the player once; no accusation wording (Save Rule 26) |
| **Read-only save** | `scores.json` version newer (ReadOnly) | Boards empty (defaults in memory); one-time toast; the screen adds a static notice line "Scores are read-only" (`menu.scores.readonly`) while the state holds, so the empty board is still explained after the toast is gone (Open Question 5 closed; string and Save acknowledgement requested in the report) |
| Storage unavailable | Write blocked (Web private mode) | Boards show session data; "Progress will not be saved" once per session (Save Rule 28) |
| No Save at all (MVP early) | Save absent | "No scores yet" (Menus dependency note) |
| `save_failed` after a run | `submit_run` fails | Entry stays in memory for the session; failure toast with `sfx_ui_save_error` |
| Touch device | Touch platform | Rows, tabs, chips, filter use `touch_item_h` (see below) |
| **Touch boards** (Target) | Solo run flown with TOUCH | Separate `/touch` boards (Touch Rule 2, TF8). Device chip on the Solo tab switches Pad/Key vs Touch. Co-op has no touch board. On a touch phone the default device chip is Touch if slot 0 is TOUCH-bound, else Pad/Key |
| Text size step 1-3 | `access.text_size` | Rows may wrap and grow, list scrolls, nothing truncated; detail strip is fixed plate and keeps its lines |
| High contrast | HUD contrast option | Plate edges Cream, dim text `#A89E8A` |
| Reduce pulsing / flashing | Options | New-entry highlight stays static border + star; focus pulse off |
| Reduce motion | Option | Tab change and wipe are cuts |
| Language changed | Chip on Title (not available here) | Not changeable on this screen; reopen shows new language |
| **[STRETCH] Rush / Boss tab** | Mode unlocked (`endings_count`, `bosses_beaten`) | Locked tabs are not listed. Rush rows show **bosses beaten** instead of stage; Boss rows have no stage tile. Boss boards are 1P only |

**[STRETCH] Online tab state matrix.** The Online tab is a view over `OnlineService` / `LeaderboardAdapter` (OL Rules 5-6, 29, 31, 33; ADR-0007 section 2 "Selection"). Every call is asynchronous and polled; input is never locked and Cancel works at every moment. Each state below is a **Status block** in the board area. Strings are client-side keys from the `status_*` family, never server text; English wording is a draft, Bengali pending review.

| State | Trigger (who tells us) | What the player sees (headline / detail / action) | Cached rows? |
|---|---|---|---|
| **Tab not listed (platform)** | No adapter other than `NullAdapter` can ever be selected on this build: Switch / Switch 2, and iOS / Android until a mobile adapter ships (**resolved 2026-11-03, wave 5:** OL Rule 6 now carries an explicit "Switch / Switch 2, iOS / Android - none at launch, `NullAdapter`, Online tab not listed" row, and ADR-0007 section 2 reads "technically capable on all platforms, enabled on PC and Web only" with the same no-adapter statement, so the two agree) | The Online tab is **not listed** (P22), so there is no dead tab. Local tabs unchanged. The pad cannot reach what does not exist | n/a |
| **Not enabled / not signed in** | `online.enabled` false, `consent_version` 0, or `NullAdapter` selected because of that | Headline "Online scores are off", detail "Optional. Local scores are never affected.", action row **CONNECT** (Confirm opens Consent) | no |
| **Not signed in (Steam build, Steam not running)** | Steam build but the extension or Steam client is absent: ADR-0007 falls back to `HttpAdapter` | Treated as a normal non-Steam player: install id and friend codes. No error and no mention of Steam. The Friends scope uses friend codes (below) | per scope |
| **Web / itch / PC non-Steam (no Steam identity)** | `HttpAdapter` with a random install id (OL Rule 6, ADR-0007) | Fully functional: Global and Around me work; **Friends** works with friend codes only. No Steam wording anywhere | per scope |
| **Web, storage blocked** | Browser storage disabled (private mode, partitioned iframe): ADR-0007 section 4 falls back to `NullAdapter` with a one-line notice | Headline "Online scores are unavailable here", detail "This browser blocks saving. Local scores still show for this session." No CONNECT row (connecting cannot work). Local tabs work | no |
| **Re-consent** | `consent_version_current` > accepted (OL Rule 15) | Headline "Online terms changed", detail "Review them to see online scores.", action **CONNECT** (opens Consent). Uploads are stopped by the service | no |
| **Loading** | Fetch in flight (first fetch, scope change, page, Retry) | Headline "Loading" with a 3-dot text that steps at most 2 Hz (static "Loading..." under `reduce_motion`). **Maximum duration `request_timeout_s` = 10 s** (OL Rule 29, timeout counts as a failure), then Offline / Error. Cached rows for this board and scope stay visible with a one-line "Updating..." in the notice zone instead of the block. 8 skeleton rows are **not** shown | shows cache if present |
| **Offline** | No network, request timeout, adapter `UNAVAILABLE` | With cache: cached rows + notice "Offline - last updated {n} days ago" (`offline_age`). No cache: headline "Online scores are unavailable", detail "Check your connection, then try again.", action **RETRY** | cache up to `cache_max_days` 30; older = discarded |
| **Backoff** | Service in Backoff (OL F6) | Same as Offline plus detail "Trying again soon." RETRY gives `sfx_ui_deny` and keeps the block (the adapter refuses until the timer ends) | as Offline |
| `RATE_LIMITED` | Reason code | Headline "Too many requests", detail "Wait a little, then open this tab again." | cache if present |
| `UPDATE_REQUIRED` | Reason code (ruleset retired or build too old) | Headline "Update the game to see these scores", detail "Your local scores are safe." No RETRY (it cannot succeed) | cache if present |
| `SUSPENDED` | Reason code (maintenance) | Headline "Online scores are paused", detail "The service is being worked on. Try later." | cache if present |
| `ERASED` | Reason code after Delete my data | Treated as Not enabled (`online.enabled` becomes false, OL Rule 19) | no |
| **Empty board (online)** | Board has 0 verified entries | Headline "No online scores yet", detail "Be the first. Your ranked runs upload after you connect." | n/a |
| **Friends, none added** | Friends scope with no friends (Steam list empty or 0 friend codes) | Headline "No friends here yet", detail "Add a friend code in Settings > Online." (Steam builds: "Your Steam friends who play will appear here.") | n/a |
| **Around me, no entry** | Player has no verified entry (OL edge case) | Headline "No entry yet", detail "Play a ranked run and it will show here." | n/a |
| Failure styling | Any error row above | Plate edge Alarm Red `#E03A3E`, a "!" glyph tile, detail text Cream. Red is never the only signal and `#E03A3E` is never the text colour. *(2026-11-03:)* the single headline line of the block may use **Alarm Flare `#F2494D`** (text-only red, style guide 3.1 rule 3); one per screen, and all-Cream is equally correct | |
| Online row | Verified entry | Handle (cut to 9 cells), "+N", score, plane, stage or bosses beaten, badges, verified tile (check glyph + text "OK"). Detail strip adds full handle and relative date | |

Local tabs work in every Online state. A failed online call never delays input, tab switching or Cancel (OL Rule 29).

**Touch geometry.** `touch_item_h = max(32, min_target_canvas_px)` (55 at x3 / 458 dpi, TF7), 4 px gap, full plate width. Tab strip, chip row and filter row are each one 55 px row (59 px pitch with gap) and **pinned**: 3 x 59 = 177 px (y 16-193). Detail strip is pinned at the bottom (y 468-560, 92 px), shrinking the scroll area to y 197-464 (about 4 rows at 59 px pitch). Board rows scroll; the focused row stays visible. Prompt bar becomes a Back plate (`touch_item_h` tall).

---

## Interaction Map

Input methods: gamepad (primary), keyboard, pointer (Web/PC), touch (Target). Verbs only (G1). **Focus order** top to bottom: Tab row, Sub-tab row, Filter row, Row 1..N. Up/Down moves between all of them and wraps (P01).

| Component | Action | Gamepad | Keyboard | Pointer / Touch | Feedback | Outcome |
|---|---|---|---|---|---|---|
| Any focusable | Move focus | D-pad / stick up-down (repeat 18/6) | Up/Down | Hover moves focus (never activates); wheel/drag scrolls | Focus border + arrow, `sfx_ui_nav_tick` | Wraps; detail strip follows focus |
| Board row | Change tab | Left/Right | Left/Right | Tap a tab | `sfx_ui_nav_tick` | Previous / next tab (Menus Rule 39); focus stays on the same row index, clamped to the last row |
| Tab row | Change tab | Left/Right | Left/Right | Tap | Selected tab filled + underline | Same as above |
| Sub-tab row | Change plane / player count | Left/Right (wraps) | Left/Right | Tap chip | `sfx_ui_nav_tick` | Rows swap in one frame; focus stays on the sub-tab row |
| Filter row | Cycle All / 1CC | Left/Right or Confirm | Left/Right or Enter/Z/Space | Tap | `sfx_ui_nav_tick` | Rows re-filter; **rank numbers stay the true board rank** (decision, Open Question 4 closed) |
| Board row | Confirm | Fire / Start | Enter, Z, Space | Tap focuses only | `sfx_ui_deny` is **not** played | No action; the detail strip is already shown. (Avoids a dead Confirm sounding like an error) |
| Records block | Scroll | Up/Down | Up/Down | Wheel/drag | — | Read-only |
| Back | Cancel | Bomb / Back | Esc, C | Back plate | `sfx_ui_cancel`, 12-frame wipe | Title, focus on HIGH SCORES |
| Device chip (Target) | Toggle | Left/Right | Left/Right | Tap | `sfx_ui_nav_tick` | Swaps Pad/Key and Touch board of the same plane |
| [STRETCH] CONNECT row | Activate | Fire / Start | Enter, Z, Space | Tap | `sfx_ui_confirm` | Opens Consent; Cancel returns to Online tab |
| [STRETCH] RETRY action (Status block) | Retry | Fire / Start | Enter, Z, Space | Tap | `sfx_ui_confirm`; `sfx_ui_deny` + unchanged block when the service is in Backoff | Refetch; shows Loading (max 10 s) |
| Status block (no action) | Focus | Up/Down reaches the action row if any; otherwise focus rests on the Filter / Scope row | same | Tap does nothing | — | Never a dead end: Cancel and Left/Right tab change always work |
| Sub-tab row, Online | Change scope | Left/Right (wraps) | Left/Right | Tap | `sfx_ui_nav_tick` | Global / Friends / Around me; each triggers one fetch or cache read; focus stays on the row |
| Board row (Online), paging | Next page | Down past row 10 | Down | Scroll | `sfx_ui_nav_tick` | Loads the next page of `page_size` 10 up to rank 100; the list is not wrapped on the Online tab (Down at the last loaded row stays) |

**Focus order, D-pad and face buttons (summary).** D-pad / stick Up-Down: Tab row, Sub-tab row, Filter row, Row 1..N, wrap. Left-Right: changes the thing the focus is on (tab, chip, filter, or tab from a board row). Fire / Start / Enter / Z / Space: CHOICE rows cycle, CONNECT / RETRY activate, board rows do nothing. Bomb / Back / Esc / C: Cancel to Title. Nothing needs pointer precision; pointer and touch are parity only (P06).

Shared screen: every connected device may navigate; last input wins (P01). No hover-only state (G2). Left/Right on a board row changing the tab is the GDD's rule; P16's "shoulder buttons" are **not** Input verbs (Open Question 3). Input is not locked on arrival, unlike Results.

## Events Fired

This screen is read-only. It writes nothing and calls no mutator in Save.

| Player Action | Event / Call | Payload | Persistent state? |
|---|---|---|---|
| Open screen | Read board `board_id` from Save | board id string | No |
| Change tab / chip / filter | Read next board | board id | No (selection is not remembered after exit; Open Question 6) |
| Records tab | Read `best_chain`, `one_cc_count` | — | No |
| Cancel | Screen change to Title | — | No |
| `save_failed` seen | Toast (P11) | file, reason | No |
| [STRETCH] Open Online tab | `fetch(board_key, scope, offset, count)` or `fetch_around` | board key, scope | Cache file written **only** on the Online tab (OL Rule 32) |
| [STRETCH] Change scope / page | `fetch` / `fetch_around` (or cache read) | board key, scope, offset, count | Cache only |
| [STRETCH] Confirm RETRY | `fetch` again | same | Cache only |
| [STRETCH] Confirm CONNECT | Open Consent | — | Consent writes `online.*` in its own spec |
| Confirm on a board row, Records block, Status block without action, Cancel on loading | **Null: no event** (stated so a missing event is not read as an omission). Cancel still leaves the screen and abandons the pending read |  | No |

Analytics: none defined in any GDD (Open Question 9).

## Transitions & Animations

- **Enter / exit:** 4-step Char wipe, 12 frames, no white. Reduce motion: cut (art bible 7.8).
- **Tab / chip / filter change:** rows swap in one frame; the selected underline snaps. No slide.
- **Rows on open:** appear in place (no row reveal). The only motion is the optional highlight (after-run variant). Under reduce-motion nothing differs.
- **Focus:** instant move; optional pulse at or below 40% opacity and 2 Hz on one element; off under `reduce_pulsing` (steady). Declared option: `reduce_pulsing`.
- **New-entry highlight (after-run only):** static 3 px Cream border + arrow + NEW tile; pulse removed under `reduce_pulsing` / `reduce_flashing` (Access Rules 8-9). Sound `sfx_ui_new_best`.
- **Toast:** 8-frame in/out, 90 ticks (P11).
- **[STRETCH] Loading dots:** 3-step text change at most 2 Hz; static "Loading" under `reduce_motion`.
- No flashing, no white frames, no scaling of digits.

## Data Requirements

| Data | Source System | Read / Write | Update trigger | Null / missing handling |
|---|---|---|---|---|
| Board entries (`score`, `stage_reached`, `plane`, `one_cc`, `continues_total`, `players[]`, `date_utc`) | Save (26) | Read | Screen open, tab/chip change | Board missing = empty board state; entry field missing = dash in that cell |
| `players[]` (initials, plane, `max_chain`, `critical_breaks`) | Save (26) | Read | Focus change | Missing player data: strip shows `--`; never crash |
| Board id (F3: `{n}s/solo/{plane}`, `{n}s/coop/{k}`, `/touch`) | Save (26) | Read | Tab/chip/device chip change | Unknown id: ignored |
| `best_chain[plane][boss_index]`, `one_cc_count[plane][stage_count]` | Save (26) | Read | Records tab open | Missing = `--` |
| Known planes list | Plane registry | Read | Open | A plane with no data still appears (its board is empty) |
| Save state (Fresh/Recovered/Reset/ReadOnly/Unavailable) | Save (26) | Read | Open; `save_failed` signal | Unknown state treated as Clean |
| `format_int(n)` | Localization (27) | Read | Every render, `language_changed` | Negative or invalid prints `0` |
| `font_size_px(tier, step)`, `access.text_size` | Localization (27) / Accessibility (28) | Read | Open; live change | Step out of range clamps to 0-3 |
| `access.reduce_*`, `hud_contrast` | Accessibility (28) | Read | Open; live change | Defaults false |
| `touch_item_h`, device class of slot 0 | Display / Input (2) | Read | Open | Defaults to pad/keyboard geometry |
| Platform tags (touch, adapter) | Engine / Online | Read | Open | Hide the gated item (P22) |
| [STRETCH] `endings_count`, `bosses_beaten` | Save (26) | Read | Open | 0 / empty = Rush/Boss tabs not listed |
| [STRETCH] Online rows, scope, status, cache age | Online (32) | Read | Online tab open, scope change, page, Retry; `poll()` result once per rendered frame | `UNAVAILABLE` = offline/not enabled state; a row missing a field shows `--` in that cell |
| [STRETCH] Reason code (`OK`, `PENDING`, `NOT_VERIFIED`, `RATE_LIMITED`, `UPDATE_REQUIRED`, `SUSPENDED`, `ERASED`) | Online (32) | Read | Each completed request | Unknown code = the Offline block (never raw server text) |
| [STRETCH] Online service state (Disabled / ConsentPending / Ready / Offline / Backoff / UpdateRequired / Suspended / ReConsent) | Online (32) | Read | Online tab open, each `poll()` result | Unknown = Offline |
| [STRETCH] Adapter kind (Steam / Http / Null) and `friend_codes` count | Online (32) / Save (26) | Read | Online tab open | Null on a platform that cannot serve it = tab not listed |
| [STRETCH] Storage-blocked flag | Save (26) state Unavailable + Online adapter selection | Read | Open | Unknown = storage OK |
| [STRETCH] `online.enabled`, `consent_version` | Save (26) | Read | Online tab open | false = "Online scores are off" |
| Unknown plane ids with a stored board | Save (26) | Read | Solo tab open | None = no extra chips |
| Lead player of a co-op entry | derived from `players[].score` (Save 26) | Read | Row render | Equal scores = lower slot; missing score = slot 0 |

UI owns no game state. The screen is a view over a node-free model, ticked at 60 Hz. Board data comes from memory (loaded at boot), so there is no disk read when switching tabs.

## Accessibility

Committed tier: **COMPREHENSIVE** (`design/accessibility-requirements.md`; this section follows it and `accessibility-options.md`).

- **Gamepad only:** every control is reachable by Up/Down/Left/Right/Cancel. No shoulder buttons needed. On Switch there is no pointer; nothing here needs one.
- **Keyboard only:** same verbs (Enter/Z/Space, Esc/C).
- **Untimed menus:** nothing on this screen is timed except the 90-tick Save toast and the 10 s network timeout (not a player timer). Because a 1.5 s toast is easy to miss, every save problem that matters here is **also** shown as a static notice line for as long as the state holds (read-only: "Scores are read-only"; storage unavailable: "Progress will not be saved"; reset: "Scores could not be restored", no blame; recovered boards show their content and need no line). Keys `menu.scores.readonly`, `unsaved`, `reset_note`. The toast is therefore never the only carrier. Whether `untimed_menus` should hold the toast longer is Open Question 18.
- **Colour-independent:** selected tab = fill + underline + text; focus = border + arrow; badges = text tiles ("C", "1CC", "+N"); slot identity in the detail strip = P08 (colour + ring pattern + pips + "P{n}"); verified = check glyph + text; every Status block has a glyph tile and words; Alarm Red `#E03A3E` is only a plate edge and glyph fill, and the text-only Alarm Flare `#F2494D` is never a fill.
- **Contrast** (measured from the palette in `arcade-ui-style.md`, WCAG relative luminance, on Cabinet Char `#1E1B18`): Cream `#F4EBD6` text 14.4:1; Ember Gold `#FFC93C` scores 11.2:1; dim text `#A89E8A` 6.5:1 (all above 4.5:1); Alarm Red `#E03A3E` 3.95:1, **below 4.5:1, so it is never a text fill anywhere** (style guide 3.1 rule 3: failure is Cream words plus an Alarm Red plate edge and/or error glyph, glyph and words together); **Alarm Flare `#F2494D` 4.76:1 (computed)** is the **text-only** red and is never a fill - at most one headline status line per screen uses it, the detail sentence stays Cream, the Alarm Red edge and "!" glyph remain, and `hud_contrast` HIGH renders the headline Cream (art bible 4.1; `design/accessibility-requirements.md` records the 4.76:1 exception to the 7:1 menu line; the protanopia re-measurement is still open); plate edge `#5A5148` 2.2:1 (decorative edge only; with `access.hud_contrast` HIGH the edge becomes Cream, 14.4:1, above the 3:1 needed for a boundary that carries meaning). Focus border Cream 3 px: 14.4:1. 1 px outline on all text.
- **Screen reader / TTS:** out of scope at this tier for the HUD; for menus "out at Vertical Slice; reconsider at Target" (accessibility-requirements section 4). No ARIA or VoiceOver text is specified for this screen. Focus order (Tab row, Sub-tab row, Filter row, rows) is the future narration order.
- **Sound visual twins:** `sfx_ui_new_best` has the star + border highlight; `sfx_ui_deny` on RETRY in Backoff has the unchanged block plus the detail line "Trying again soon."
- **Text size:** rows reflow and the list scrolls at step 3; nothing is truncated; fixed plates (detail strip) keep their size.
- **Flashing / pulsing:** no flashing at all; highlight and focus pulse respect `reduce_pulsing`.
- **Touch:** rows at least 9 mm (TF7); Back plate at least `touch_item_h`.
- **Honest wording:** read-only and recovered saves never blame the player.
- **Screen reader:** no stance exists (pattern library gap 7); not specified.
- **Subtitles:** no dialogue here.
- **Legend:** "C" and "1CC" are explained in the detail strip header so meaning does not depend on prior genre knowledge.

## Localization Considerations

Menus are single-language (arcade-ui-style 2.1). No dual-script on this screen. Initials and "P1".."P4" stay Latin; numerals use `format_int` (Bengali digits on the same grid, Western 3-digit grouping).

| Element | Limit | Bengali / worst case |
|---|---|---|
| Tab label | 106 px per tab at 3 tabs; Latin M tier 9 px/char, **max 8 characters** (`RECORDS` = 63 px, with +40% = 88) | Bengali 17 px min, wrap forbidden in tab; fits 106 px with +40% reserve. At 6 tabs it does not fit (Open Question 2) |
| Plane chip | Icon 14 + 4 + name; MVP chip width 120 px | `LANCER` and `LEECH` fit; Target 4 chips at 76 px do not hold `BREAKER` + icon (Open Question 7) |
| Filter label | 328 px line: `Filter: ` + value, 24 characters | Bengali reserve +40% still one line |
| Empty row | 328 px, 2 lines allowed (3 in Bengali) | `এখনও কোনো স্কোর নেই` verify |
| Detail strip labels | Chain, Critical Breaks: 14 px column headers, one line each | Bengali 17 px: strip is 92 px tall, header 24 + 4 x 16 = 88 px; verify headroom (matra 2 px, descenders 3 px) |
| Rank / score / stage | Fixed digit grid; 249 of 328 px | Same width in Bengali (AC-47 in Menus) |
| Records labels | 328 px; `Best chain`, `1CC` | +40% reserve |
| Toast text | 328x24 strip, 1 line, 40 characters Latin | Bengali shortened wording needed |
| [STRETCH] Online handle | 3-12 Latin chars | See Open Question 2 for width |

**Status block and notice strings.** Headline: max **2 lines of 28 Latin characters (56 total)** (328 px at 9 px/char = 36, minus the 28 px glyph tile and padding); Bengali +40% allows 3 lines. Detail: max **2 lines of 36 Latin characters (72 total)**; Bengali at +40% needs 3 lines, and the block (up to 280 px) has room. Notice line: max 56 Latin characters over 2 lines; Bengali 3 lines inside 72 px. Wrap is allowed in blocks, never in tabs or chips. Draft English strings are the ones in the States tables; all must be checked against these limits by Localization (the longest draft headline, "Update the game to see these scores", is 35 characters and wraps to two lines by design). Handles and plane ids are Latin and never translated.

New string keys (English drafts; Bengali pending native review by Localization): `menu.scores.tab_solo`, `tab_coop`, `tab_records`, `filter_all`, `filter_1cc`, `legend_c`, `legend_1cc`, `col_chain`, `col_crit`, `readonly`, `unsaved`, `reset_note`, `practice_note`, `empty_hint`, `empty_1cc`, `dash_note`. Existing keys: `menu.scores.empty` (No scores yet / এখনও কোনো স্কোর নেই), `menu.scores.play_again`. [STRETCH] keys: `menu.scores.tab_online`, `online_off`, `offline_age` (placeholder `{n}` formatted by `format_int`), `status_*` for the reason codes. Translators write words only (Localization Rule 11).

---

## Acceptance Criteria

- [ ] From Title, Confirm on HIGH SCORES opens Solo, first listed plane, filter All, with focus on rank 1; Cancel returns to Title with focus on HIGH SCORES.
- [ ] MVP tabs are exactly Solo (Lancer, Leech), Co-op (2P, 3P, 4P) and Records; the sub-tab row is absent on Records; no run-length selector appears while only `stage_count` 2 exists in the save.
- [ ] Left/Right on a board row changes the tab; Up/Down moves between Tab row, Sub-tab row, Filter row and rows and wraps; a gamepad-only and a keyboard-only tester can reach every control.
- [ ] Switching tab, chip or filter shows the new rows within one frame (16.7 ms) with no disk access, and the screen holds 60 fps with 10 rows and the detail strip on a mid-range phone.
- [ ] **Empty state:** a board with no entries shows exactly one Status block "No scores yet" with its hint line (never a blank list), no detail strip, and focus on the Filter row; when the 1CC filter hides every entry the block reads "No 1CC scores yet" and the filter stays focusable.
- [ ] A row shows rank, 3-letter initials, plane icon, 9-digit Gold score, stage and "C" / "1CC" tiles; the worst-case co-op row is 249 px or less of 328 px, and Bengali digits give the same widths as Western digits.
- [ ] A co-op row shows one rank number for the whole team, the lead player's initials (highest individual score; tie to the lower slot) plus "+N"; focusing it shows one strip line per played player with P08 badge, plane, best chain and Critical Breaks. No per-player rank appears anywhere.
- [ ] An entry with plane id `"x"` shows the generic icon and raw `x` in Latin, and does not crash the screen. A solo board stored under unknown plane id `"x"` is reachable through an extra Solo sub-tab chip showing the generic icon and `x`; no stored entry is unreachable.
- [ ] A board never shows more than 10 rows; a run with score 0 or one that did not beat rank 10 of a full board never appears, and this screen shows no per-run explanation.
- [ ] **Loading (local):** switching tab, chip or filter never shows a loading state or a blank frame. **Error/notice (local):** in ReadOnly, Unavailable and Reset save states the matching static notice line shows for as long as the state holds, independent of the toast.
- [ ] Ties show the older entry above; a score above 999,999,999 displays as 999,999,999.
- [ ] Records shows `best_chain[lancer]` as `[112, 187]` and dashes for every plane or boss with no data.
- [ ] 1CC filter hides all entries without `one_cc`; row rank numbers remain the true board rank (e.g. 1CC-only shows 1, 4, 7 not 1, 2, 3).
- [ ] With a corrupted-and-reset `scores.json` the screen opens empty with a one-time notice that does not blame the player; with a newer-version file it opens empty, writes nothing, and shows the read-only toast once.
- [ ] Nothing on screen is colour-only: in greyscale, the selected tab, focused row, badges, "+N" and slot identity remain distinguishable.
- [ ] With `reduce_pulsing` / `reduce_flashing` on, nothing on this screen pulses; with `reduce_motion` on, enter and exit are cuts.
- [ ] At 1280x720, 1920x1080 and a 9:20 phone viewport all zones fit inside the 360x640 canvas; at `access.text_size` 3 the list scrolls, nothing is clipped and the detail strip keeps its lines.
- [ ] On a touch device every tab, chip, filter and row is at least 9 mm (about 55 canvas px at x3 / 458 dpi), header rows are pinned and the list scrolls with the focused row visible; `/touch` boards (Target) are never merged with pad/keyboard boards.
- [ ] The screen never writes to Save: opening, switching and leaving it leaves `scores.json` byte-identical.
- [ ] [STRETCH] With `online.enabled` false the Online tab shows the "Online scores are off" Status block and a CONNECT row; offline with a cache shows rows and "Offline - last updated {n} days ago"; offline without a cache shows "Online scores are unavailable" and RETRY; all local tabs work in every online state.
- [ ] [STRETCH] Loading: a fetch that gets no answer shows "Loading" for at most 10 s, then the Offline block; Cancel and tab switching work during the whole wait; under `reduce_motion` the dots are static.
- [ ] [STRETCH] On a build with only `NullAdapter` (Switch, mobile until an adapter ships) the Online tab is not listed; on Web with blocked storage it shows "Online scores are unavailable here" with no CONNECT row; on Web or non-Steam PC with consent, Global and Around me work and Friends works with friend codes only (no Steam wording).
- [ ] [STRETCH] Each reason code (`RATE_LIMITED`, `UPDATE_REQUIRED`, `SUSPENDED`) shows its own client-side string, never server text; failure blocks use Cream text (or one Alarm Flare `#F2494D` headline line) with an Alarm Red `#E03A3E` edge and a "!" glyph (in greyscale the glyph and words still carry the meaning, since Flare reads as mid-value text).
- [ ] [STRETCH] An online row is at most 321 px of 328 px for a 12-character handle (cut to 8 characters plus `...`), and the full handle shows in the detail strip.
- [ ] [STRETCH] Friends with no friends and Around me with no entry each show their own Status block, never a blank list.

---

## Open Questions

> **Status after /ux-review 2026-11-03.** CLOSED in this spec: 1 (Other-plane chip), 2 (scrolling tab window; online row 321 px, handle cut to 8 + `...`), 4 (true board ranks under filter), 5 (static notice lines), 8 (unknown-plane records shown; 4-stage Records layout still open), 10 (tier COMPREHENSIVE, `design/accessibility-requirements.md` exists), 11 (lead player = highest individual score, tie to lower slot), 12 (practice notice), 15 (`menu.scores.empty_1cc`). Still open: 3, 6, 7, 9, 13, 14, 16, 17 and 18 below. Entries below marked closed are kept for history.
>
> 18. **Toast under `untimed_menus`.** Should the 90-tick Save toast stay until input when `access.untimed_menus` is on? Static notice lines already cover the important cases. Needs accessibility-options owner.

1. **CLOSED 2026-11-03 (wave 5 batch 2).** The Menus GDD amendment has landed: Rule 40 now defines the extra Solo sub-tab chip (generic plane icon plus the raw id cut to 8 characters + `...`) and its Boards edge case no longer claims those entries appear on co-op boards; Save Open Question 9 is answered for the UI. The original text: *Unknown plane id, solo (GDD conflict).* Menus edge case ("tab not shown but entries still appear on co-op boards") conflicts with Save ("entry goes to `solo/<that id>`"; Save Open Question 9). A solo entry cannot appear on a co-op board, so it is unreachable on screen. Proposal: show a trailing "Other" chip on Solo only if such a board exists. Needs game-designer + Save decision. *(Menus edge case, Save edge case.)*
2. **Stretch widths do not fit.** (a) Six tabs (Solo, Co-op, Records, Rush, Boss, Online) cannot fit 328 px at 9 px/char. Proposal: a scrolling tab strip with `<` `>` hints, focused tab kept visible, or a "Mode" row. (b) Online row worst case: 26 + 108 (12-char handle) + 18 + 18 + 111 + 15 + 34 + 18 (verified tile) = **348 px > 328** (OL Rule 13 vs Menus F10). Proposal: ellipsise handles at 9 characters in the row and show the full handle in the detail strip, or drop the stage tile online. Needs art-director + online owner.
3. **Controls verbs.** Menus Rule 39 uses Left/Right for tabs, but P16 mentions shoulder buttons and the filter/sub-tab rows also need Left/Right. This spec resolves it with row-level focus; confirm Input does not add tab verbs.
4. **Rank numbers under the 1CC filter.** GDDs do not say whether the filtered list renumbers. Proposal: keep true board ranks so "rank 4" always means the same; confirm with game-designer.
5. **Read-only notice.** Save emits `newer_version` once (toast). Proposal: also a static notice line while on this screen so the empty board is explained after the toast is gone. Needs a string and Save approval.
6. **Remembering the last view.** Proposal: remember the last plane for the session only; open from Title always on the first plane. Alternative: open on the player's most-played plane (needs a stat Save does not keep).
7. **Target chips.** Four plane chips (Lancer, Leech, Sentry, Breaker) at about 76 px do not hold icon + longest name `BREAKER` (63 px + icon). Proposal: icon-only chips plus a full name label for the focused chip. Needs art-director.
8. **Records for unknown planes and boss counts.** GDDs do not say whether records for a removed plane id appear; proposal: hide them. Also Records at 4-stage (Target) adds a "1CC" column per stage count: layout not defined.
9. **No analytics** events are defined for scores (analytics-engineer input needed, if telemetry exists).
10. **No accessibility tier recorded** (`design/accessibility-requirements.md` missing) and no player journey map.
11. **"Lead player" undefined.** Menus Rule 40 shows the lead player's initials; Save does not define which `players[]` entry leads. Proposal: highest individual score, ties to the lower slot. Also assumed: `players[]` order equals slot order, so P08 badges can be drawn.
12. **PRACTICE runs are invisible.** Assisted runs never reach boards (Save Rule 32), so a player who only uses game-speed assists sees "No scores yet" with no reason. Proposal: a static footer "Practice runs are not ranked". String needed.
13. **Date.** Entries store `date_utc` but no GDD places it on screen. Proposal: show the date in the detail strip (via a Localization date format, which does not exist yet).
14. ~~**Delete my online data location (CONFLICT).**~~ **CLOSED 2026-11-03 (final doc closeout, consistency-report C2).** It lives in **Settings > Online only** (`online-leaderboards-boss-rush.md` Rule 19 and `design/ux/settings.md`, both already correct). `menus-title-plane-select.md` Rule 39 was amended to drop the screen from the scores screen's Online tab; that tab may show a focusable **link** that opens Settings > Online, but never hosts the `HOLD_BUTTON` action. One place to destroy data. [STRETCH]
15. **Empty text under the 1CC filter.** GDD requires "No scores yet"; a specific "No 1CC scores yet" would be clearer. Proposal for a new string.
16. **[STRETCH] Device for touch boards.** Whether touch boards show on non-touch platforms is not specified; this spec shows the device chip only when a `/touch` board exists.
17. **Attract score page** (arcade-ui-style proposal 1) would reuse this board view read-only; not specified here.
