# Applied: UX review cross-document amendments, batch 1

**Date**: 2026-11-03
**Applier**: Claude (central applier), auto-approve in force
**Source reports**: `production/ux-reports/hud.md`, `results-name-entry.md`, `credits.md`, `high-scores.md`, `arcade-ui-style.md`, `flight-school.md`
**Allowlist honoured**: only the 15 files named in the brief were touched. `design/ux/settings.md`, `design/gdd/accessibility-options.md`, `save-settings-high-scores.md`, `input-and-player-mapping.md`, `display-scaler-and-bezel.md`, `audio.md`, `localization.md` were **not opened for writing** (a seventh review agent owns them).

Totals: **28 applied**, **11 deferred to batch 2**, **1 not applied**, **6 open questions raised or confirmed**.

Source-report IDs below use the amendment numbering of each report: H = `hud.md`, R = `results-name-entry.md`, C = `credits.md`, HS = `high-scores.md`, A = `arcade-ui-style.md`, F = `flight-school.md`.

---

## Applied

| # | Source | Target file | Section | What changed |
|---|---|---|---|---|
| 1 | H1 | `design/gdd/hud.md` | Rule 22, AC-32 | Portrait no longer goes to **victory**: it returns to **neutral** on `boss_defeated`, and the rule and AC now say the 96x96 victory portrait is drawn by the Stage tally (the HUD is hidden in Tally mode). Information inventory and Interaction text were checked and mention no victory pose, so they needed no edit. |
| 2 | H2 | `design/gdd/hud.md` | HF2 (formula, variable table, example), Rule 24, Rule 34a(c), AC-37, new AC-37b, Defaults, "Owned elsewhere" | Continue bar scales on **`continue_total`** instead of the fixed `continue_seconds`; `remaining` range 0–30; new nullable `continue_total` variable row; EXTENDED worked example (14 s of 30 → 44 px, red from 7.5 s); Rule 34a(c) rewritten so **UNTIMED shows the EXTENDED countdown and bar while another slot is Alive** and drops both only when no other slot is Alive; AC-37 made total-explicit and **AC-37b** added for EXTENDED + both UNTIMED branches. |
| 3 | H3 | `design/gdd/game-events-and-session.md` | Header, Session additions (Continue timer override), F4 (formula, variable table, example), UI Requirements, Defaults | Session now **publishes `continue_total`** (seconds, nullable) beside `continue_remaining`, resolved from `access.continue_timer`: 10 STANDARD / 30 EXTENDED / 30 UNTIMED-with-another-slot-Alive / `null` otherwise. `Last Updated` moved 2026-11-02 → 2026-11-03. |
| 4 | H4 + F5 (reconciled) | `design/gdd/hud.md` | Rule 30a | Strip-mark brackets are **clamped to the column's mark clip rect**: x from column origin + 4 (2P: up to x 355 for P2), y 0 to the row limit 36 (48 px strips) or 59 (72 px); a clamped side sits **on** the clip edge. |
| 5 | H4 | `design/gdd/tutorial.md` | Rule 21, Visual/Audio strip-mark line | Same clamp wording added to Tutorial's restatement of the mark, with HUD Rule 30a named as the owner of the clamp. |
| 6 | H5 | `design/gdd/hud.md` | "Compact 48 px column form" layout table (Pick plate row), Rule 23 | The geometrically false "zones stay" claim is replaced: the plate hides only the boss **bar**; the boss row's zones (0,36,24,12) and (336,36,24,12) draw **above** the plate, so in columns 0 and 3 the plate's bottom outer **19x10 corner is clipped**. Menus must keep cursor and labels out of that corner. |
| 7 | H5 | `design/gdd/menus-title-plane-select.md` | Rule 52 (HUD contract) | Keep-out requirement recorded on the Menus side: the plate's frame may be clipped in that 19x10 corner, nothing readable may be drawn there. |
| 8 | H6 (part) | `design/gdd/hud.md` | Rule 24, Open Question 10 | Rule 24 now draws the accept glyph via **`action_glyph(slot, CONTINUE_ACCEPT)`** and states it is **one verb shared with the Tally prompt** — no hard-coded START. OQ 10 rewritten with the resolved shape (one `CONTINUE_ACCEPT` verb plus an explicit START-versus-Pause priority while a slot is in Continue) and left open pending the Input and Tally GDDs (batch 2). |
| 9 | H7 | `design/gdd/hud.md` | Visual/Audio, Warning banner row | "text opacity pulse 100 to 60 % at 1.5 Hz at most" → **1 Hz** (`pulse_step_ticks` 15, Rule 31, HF9). |
| 10 | H8 | `design/gdd/hud.md` | HF4 variable table and Output Range | `W` now lists **14** (compact 48 px column form); notch at 5 for that width. |
| 11 | H9 | `design/gdd/hud.md` | AC-45, AC-13 | `warning_requested` → `warning_started`; "by tick 36" → "by tick 32 (HF1 Output Range)". |
| 12 | H2/H3 | `design/registry/entities.yaml` | `constants` | New locked constant **`continue_total`** added next to `continue_seconds`, with the resolution rule, nullability and `referenced_by: [game-events-and-session, hud, accessibility-options]`. Header gained a "Last updated 2026-11-03" line. |
| 13 | R2 | `design/gdd/menus-title-plane-select.md` | Rule 35, Results 2P ASCII mock-up | Rank is shown **once in a strip under the heading**, not on P1's row; in co-op it is the **single team rank** (`team_score`); added the **`Not in top {n}`** case and "nothing at all" for an unranked run. The mock-up's `RANK 2 NEW` moved out of P1's row into its own strip line. |
| 14 | R3 | `design/gdd/menus-title-plane-select.md` | Rule 36, Visual/Audio "Name wheel" row | 3–4 player name entry: **2x2 grid of 160x136 blocks at x = 16 / 184, y = 104 / 264** (ends y 400), one block per played slot with its own wheel, P-tag and device glyph; **3P centres P3 at x = 100**. |
| 15 | R4 | `design/gdd/menus-title-plane-select.md` | Rule 36, name-entry pad-disconnect edge case | Added "unless `access.untimed_menus` is on: the slot is **held** (controller-lost plate with **DROP**) until the pad returns or a player drops it", in both the rule and the edge case, resolving the contradiction with the Accessibility GDD's edge case. |
| 16 | R5 (part) | `design/gdd/menus-title-plane-select.md` | Visual/Audio "Results" row | Recorded that 3–4P Results score plates use **D12 (9 digits, Western, 78 px, centred)** with a **D10 fallback applied to all columns together**, and that the INDIAN-grouping 81 px case and the D10 plate width must be confirmed in the font spike. |
| 17 | R6 (part) | `design/gdd/menus-title-plane-select.md` | String table + note | Registered 14 new Menus-owned keys: `menu.results.not_placed`, `not_ranked`, `practice`, `stage_of`, `next`; `menu.name.done`, `editing`, `no_limit`, `controller_lost`, `drop`, `latin_only`; `menu.scores.empty_1cc`; `menu.credits.empty`, `licence_missing` (English source text given; see Not applied / Open questions for the Bengali). The note also records the **"ALL CLEAR" (Tally banner) vs "MISSION COMPLETE" (Results verdict)** glossary pair that `localization.md` must carry. |
| 18 | R8 | `design/ux/interaction-patterns.md` | P15, new **P31**, Gap 6 | P15 extended from `results-name-entry.md` (mouse is not bound so only a TOUCH slot taps; Start finishes only the pressing slot; opening press consumed; focus order inside a wheel only; 3–4P grid; Latin-only with `menu.name.latin_only`). New **P31 Controller-lost plate with DROP** covers untimed pad loss. Gap 6 updated and still closed. |
| 19 | C1 | `design/gdd/menus-title-plane-select.md` | Rule 46, Tuning table | Rule 46 now carries: Nav up/down steps one line and pauses the auto-scroll; Fire or Start press resumes; `access.reduce_motion` = auto-scroll off, opens in manual; stop with the last line at the viewport centre, no loop and no auto-exit; licence text not translated and lint-exempt; **Start acts as Confirm, not Cancel**. `access.reduce_motion` added to the tuning table as a key Menus reads. |
| 20 | C4 | `design/ux/interaction-patterns.md` | P26, Back/Cancel table, Gap 4 | Gap 4 marked **closed** with the credits answer; P26 gained the **Credits line-step variation** (line, not whole row; pause/resume; reduce-motion manual); the Back table gained a Credits row noting **Start is Confirm here, not Cancel**. |
| 21 | C5 | `design/gdd/menus-title-plane-select.md` | Open Question 15 | Licence entries are a **`kind = LICENCE` record** in `credits.tres` (title + body), body never localised and lint-exempt; content and length stay the producer's call. |
| 22 | HS3 + R7 (reconciled) | `design/gdd/menus-title-plane-select.md` | Rule 40, Boards "unknown plane id" edge case | Rule 40 now defines the **lead player** (highest `players[].score`, ties to the lower slot, `players[]` in slot order), states a co-op row carries **one** team rank, and makes an unknown-plane solo board reachable as an **extra Solo sub-tab chip** (generic icon + raw id cut to 8 characters + `...`). 1CC-filtered lists keep **true board ranks**; `menu.scores.empty_1cc` named. The edge case that wrongly said those entries appear on co-op boards is corrected. |
| 23 | HS4 | `design/gdd/coop-and-team-chain.md` | Open Question 8 | Closed: one team entry per board, ranked by `team_score`, separate boards per player count, one team rank displayed, lead-player initials + `+N` tile. Header revision note added. |
| 24 | HS5 (**decision 1**) | `docs/architecture/adr-0007-online-services.md` | Date, section 2 (Adapters, Selection), architecture diagram | `HttpAdapter` reworded: **technically capable on all platforms, enabled on PC and Web only**; **Switch / Switch 2 and iOS / Android ship no adapter**, get `NullAdapter`, and do **not** list the Online tab. Selection paragraph and the diagram's adapter lines updated to match. |
| 25 | HS5 (**decision 1**) | `design/gdd/online-leaderboards-boss-rush.md` | Header, Rule 6 table row, Rule 33 | The "Consoles, mobile (later): out of scope" row is replaced by an explicit **"Switch / Switch 2, iOS / Android — none at launch, `NullAdapter`, Online tab not listed"** row that also states `HttpAdapter` serves Web, itch and PC only. Rule 33 now distinguishes "service unavailable" (one-line notice) from "no adapter on this platform" (tab not listed at all). |
| 26 | HS6 (**decision 4**) | `design/ux/arcade-ui-style.md` | 3.1 palette row, 3.1 rule 3, section 8 conformance checklist | **Alarm Red is never a text fill** (3.95:1). It is allowed as bar fill, plate edge, end-cap and glyph fill; failure is conveyed by **Cream words plus an Alarm Red plate edge and/or error glyph**, tier S or larger, glyph **and** words. Explicitly stated to supersede the earlier "Alarm Red text allowed with glyph and words" exception and to bind every spec that quoted it. |
| 27 | HS7 + F6 (reconciled) | `design/ux/interaction-patterns.md` | Catalog, new **P29** and **P30**, Gap 8 | **P29 Status block** (empty / loading / error / unavailable, focusable, retry refused with `ui_deny` in backoff, failure styling per the new Alarm Red rule) added and Gap 8 closed. **P30 Single-button modal over a stopped field** added for the Coach card. Both ids are in the catalog table. |
| 28 | HS8 | `design/gdd/online-leaderboards-boss-rush.md` Rule 13 + `design/gdd/menus-title-plane-select.md` F10 | Rule 13, F10 | The 348 px worst case is recorded against the 328 px inner width, with the adopted fix: **handle cut to 8 characters + `...` in the row**, full handle and **relative date in the focused row's detail strip**. |
| 29 | A1 | `design/ux/stage-tally.md` | Component inventory (MAX_CHAIN hero), Animation table ("Hero end"), Reduce-motion row, Open Question 6 | The hero's "scale +1 step" is removed everywhere (art bible 7.3/7.7: digits never enlarge). Replaced by a **colour step to bright Gold with a 1 px edge step** at count end; reduce-motion makes that a static state; OQ 6 updated. No tick count was invented for the step. |
| 30 | A2 | `design/ux/hud.md` | Open Question 9 | Stale "Style guide G3" citation fixed to **`arcade-ui-style.md` 3.1**, and the question **resolved**: P{n} is required only where a text label fits; the HUD column (GDD Rule 8) is exempt. |
| 31 | A3 | `design/ux/hud.md` | Localization, banner text row | Bengali headroom now reads "never clip top 2 px / bottom 3 px **and reserve 4 px above the matra line** (art bible 7.5)", with the clip-floor vs reservation distinction spelled out. |
| 32 | A4 | `design/ux/credits.md` | Layout Zones line height, new Open Question 9 | The false arithmetic ("Latin 12 px x 1.2, rounded up" = 20) is corrected: 12 x 1.2 = 14.4 → 15. The **20 px pitch is kept as an authored value** and labelled as not derived; a new Open Question 9 ties it to the style guide's line-pitch base. No new base was invented. |
| 33 | A5 | `design/ux/interaction-patterns.md` | Animation Standards, P09 | The join-plate row now carries the range **1 Hz, 100% ↔ 60%**, and P09 gained a matching Lobby-plate-pulse bullet (steady under `reduce_pulsing`; the in-play HUD plate never pulses). |
| 34 | A8 (**decision 3**) | `design/ux/arcade-ui-style.md` + `design/ux/interaction-patterns.md` | Style guide Ownership table and section 5 heading; pattern library Style line, Animation Standards, Sound Standards | Ownership stated once and consistently: the **style guide owns the cross-screen animation (4) and sound (5) standards tables**; **`design/gdd/audio.md` owns the sound ids**; the **pattern library cites both per pattern and restates neither** (both standards sections rewritten as pattern→row mappings with "the style guide wins if they differ"). |
| 35 | F1 (**decision 2**) | `design/ux/main-menu.md` | Layout Zones (Menu list), Accessibility text-size bullet, Open Question 1 | Menu list top is **y 372 with FLIGHT SCHOOL** (6 items, 212 px, ends y 584, 16 px clear of the prompt bar at y 600) and stays **y 392 for 5 items** (ends y 568); logo ends y 200 so the shift fits; at text steps 2–3 the list scrolls inside its band with the focused row in view; the toast strip overlap is unchanged and transient. **Open Question 1 closed.** |
| 36 | F2 (part) | `design/gdd/tutorial.md` | Rule 16, new Rule 25a, Rule 25(a), AC-27 | `commit_settings()` is now **also** called when the player leaves the School list to Title with `tutorial.*` dirty, so the NEW tag clears without completing a drill. New Rule 25a states the persistence contract; AC-27 extended to cover open-list → back-out → restart. |
| 37 | F3 | `design/gdd/tutorial.md` | F3 (new flag paragraph), Rule 12 note, new Open Question 11 | The reachability bug is recorded in full: a fixed `required_mask = 1023` can never be satisfied by a Sentry-only or Breaker-only profile because Rule 12 hides their unavailable drills, and `drill_ref`-keyed hints would never settle. Both candidate fixes are written down, **neither adopted** (see Open questions). |
| 38 | F4 | `design/gdd/tutorial.md` | Rule 13 | `goal_key` / `tip_key` text must be **plane-neutral**, or per-kit keys (`tut.drill.<id>.tip.<kit>`) resolved by the slot's plane; the four kits charge differently (laser / focused shot / Entrench / Breach) so no drill string may name one kit's mechanic. The Coach card uses the same resolved key. |
| 39 | F5 | `design/ux/hud.md` | Strip mark row, new Open Question 21 | Added the **inset rule**: where an element has **less than 3 px free** on a side, that bracket is drawn inside the element's rect, flush to its edge — covering 1P `chain_plate` (1 px above, 2 px right) and `kit_bar` against the drill/boss bar. The undefined **DONE / SKIPPED stamp rect** is raised as Open Question 21 instead of being invented. |
| 40 | housekeeping | `design/ux/hud.md` | Open Questions 1, 4, 10, 12, 15, 20 | Statuses updated now that the GDD edits are in: 1, 4, 12, 15 and 20 **closed**; 10 **narrowed** to the Critical Break `cb_banner_wait_max` 120 vs 180 item only (the 1 Hz half is applied). |
| 41 | housekeeping | `design/ux/credits.md` | Open Questions 1 and 8 | OQ 1 **closed** (Rule 46 amendment applied); OQ 8 updated to show the keys are registered in the Menus GDD and that only the `localization.md` registry entries remain (deferred). |
| 42 | C1 follow-through | `design/gdd/systems-index.md` | Header, row 22 | Menus (22) gains a **soft dependency on Accessibility (28)**, which it already reads and now also reads `access.reduce_motion` for the Credits roll. `Last Updated` line added. |

Row count note: the table numbers the *edits*; against the reports' own amendment numbering, **28 distinct amendments** were applied (the extra rows are the second target of a two-file amendment, plus four housekeeping/consistency edits the applied amendments made necessary).

---

## Reconciled

1. **Strip-mark geometry — H4 vs F5.** H4 asked for a clamp rect ("a clamped side sits on the clip edge"); F5 asked for brackets "drawn inset when less than 3 px is free". Applied as one coherent rule rather than two: the **clamp** is the normative placement (GDD Rule 30a and Tutorial Rule 21, both files), and the **inset** case is spelled out in `design/ux/hud.md` for the two tight elements F5 named (`chain_plate`, `kit_bar`). One mechanism, two documented consequences — no contradiction between the GDD and the spec.
2. **Pattern id P29 — HS7 vs F6.** Both reports claimed **P29**: HS7 for the **Status block** and F6 for the **Coach-card single-button modal**. Resolved by giving **P29 = Status block** (because `design/ux/high-scores.md` already cites "proposed P29" for it and that file is outside my allowlist, so its reference must keep working) and **P30 = single-button modal over a stopped field**. F6's option to "fold into P10" was rejected: P10 is owner-only and this card holds the whole group, so folding would break P10's ownership rule. A numbering note in P30 records that `design/ux/flight-school.md` still calls it "candidate P29" and needs updating — see Not applied.
3. **Co-op rank — R2 vs HS3.** R2 wanted one rank in a strip under the Results heading; HS3 wanted one rank per co-op board row. Both are the same decision seen from two screens, so Rule 35 (Results) and Rule 40 (Boards) were edited together with one shared definition: **one team rank by `team_score`, lead player = highest `players[].score` with ties to the lower slot**. Co-op GDD Open Question 8 was closed with exactly that wording so the three documents cannot drift.
4. **Unknown plane — R7 vs HS3.** R7 asked to resolve the conflict with an "Other"/extra chip on Solo and to fix the Menus edge case; HS3 gave the concrete chip rule (generic icon + raw id cut to 8 characters + `...`). Applied as HS3's concrete text, with R7's correction of the edge case (solo entries never appear on co-op boards) folded into the same edit.
5. **Alarm Red — A6/A7 vs HS6 (under decision 4).** HS6 asked for "text stays Cream"; the style guide's own rule 3 still allowed Alarm Red text with a glyph and words; A7 asked other specs to add the glyph requirement. Applied the brief's decision as the single rule: **Alarm Red is never a text fill at all**, failure is Cream words + Alarm Red edge/glyph. This is stricter than the file's previous rule 3, so the rule explicitly says it supersedes it and binds the specs that quoted it, which is what the two forbidden/out-of-scope targets (`settings.md`, `high-scores.md`) will need to follow.
6. **Continue accept verb — H6 vs `design/ux/hud.md` OQ 13.** The HUD GDD had "default START"; the Tally says Fire. Rather than pick a button (not mine to pick, and Input owns it), Rule 24 was made verb-based (`action_glyph(slot, CONTINUE_ACCEPT)`) and OQ 10 now records the agreed *shape* (one shared verb + START-versus-Pause priority) while staying open for the Input and Tally GDDs in batch 2.

### Where the report's "current text" did not match the file

- **HS6** quoted the Alarm Red palette row as "failure/corruption text". The row had already moved on to "Boss bar, chain expiry cap, failure notices (see rule below)", and rule 3 under it already existed. Adapted: both the row and rule 3 were rewritten to the stricter decision.
- **F2** cited "`tutorial.md` Rule 25a"; no Rule 25a existed. Created it (the commit/NEW-tag persistence contract) and amended Rule 16, which actually owns the `commit_settings()` call.
- **F5** cited "spec Open Question 3" in `design/ux/hud.md`; that question has since been closed (join-plate pulse) and the clamp rule already existed at the strip-mark row. The inset rule was added there instead, and the stamp-rect half became a new Open Question 21.
- **A4** said to correct the credits line-pitch number "once Open Question 3 is answered" — that is the **style guide's** OQ 3, not credits' OQ 3. The arithmetic was corrected and a new credits Open Question 9 now points at the style guide's OQ 3.
- **R2** quoted the mock-up at "~line 592"; it is at line ~597 after earlier edits. Matched on content.
- **C1** quoted Rule 46 at "line 135"; content matched exactly, line number had drifted.

---

## Deferred to batch 2

Every amendment below targets a file another agent currently owns, or a file outside my allowlist. **Full proposed text is reproduced so nothing is lost.**

### D1 — `design/gdd/save-settings-high-scores.md`, Core Rules, Rule 5 (FORBIDDEN: owned by the settings reviewer)

Two reports ask for the same change; apply once, using the union of both.

> **From R1.** Current: "A run is **ranked** if its **board score** is at least `min_ranked_score` (1)."
> Proposed: "A run is **ranked** if its board score is at least `min_ranked_score` (1) **and** it places within the top `board_size` of its board (F1). `preview_rank` returns a rank or `not placed`; a not-placed run asks for no initials and stores nothing." (Aligns with F1, AC-03 and Online Rule 1.)

> **From HS1.** Current: "A run is **ranked** if its **board score** is at least `min_ranked_score` (1)." Proposed: "A run is **ranked** if its board score is at least `min_ranked_score` (1) **and** it places within the top `board_size` (10) of its board (F1: `rank_index < board_size`)." Reason: Rule 5 contradicts F1 and Online Rule 1.

**Applier's note:** Menus Rule 35 and Rule 40 have already been edited on the assumption that this lands (the `Not in top {n}` case and the top-10 limit). Until Rule 5 is amended, Save Rule 5 and Menus Rule 35 disagree and the **GDD-versus-GDD rule gives Save the win**, which would let a not-placed run into Name entry.

### D2 — `design/gdd/save-settings-high-scores.md`, Rule 11 (`players`) (FORBIDDEN)

> **From HS2.** Add: "Lead player of a co-op entry for display = highest `players[].score`, ties to the lower slot; `players[]` is in slot order."

**Applier's note:** the Menus half of HS2 is applied (Rule 40). This is the Save half.

### D3 — `design/gdd/save-settings-high-scores.md`, Rule 20 (commit triggers) (FORBIDDEN)

> **From F2.** Current trigger list contains "Flight School drill complete (return to the list)" only.
> Proposed: add "leaving the School list to Title while `tutorial.school_seen` or `hint_counts` are dirty", so the NEW tag clears without completing a drill.

**Applier's note:** the Tutorial half is applied (Rules 16, 25a, AC-27). Save Rule 20 must list the new trigger or the two GDDs disagree on when a commit happens.

### D4 — `design/gdd/localization.md`, string key registry (Menus keys section) (FORBIDDEN)

> **From C2.** Register `menu.credits.empty` and `menu.credits.licence_missing` (en + bn), and confirm `credits.section.*` keys exist. Proposed English: "No credits available." and "Licence text unavailable."

### D5 — `design/gdd/localization.md`, F3 (FORBIDDEN)

> **From R5.** Record that 3-4P Results columns use D12 (78 px, Western) with a D10 fallback; confirm D10 plate width and the INDIAN-grouping 81 px case in the font spike.

**Applier's note:** the Menus half is applied (V/A "Results" row).

### D6 — `design/gdd/localization.md`, string registry + glossary (FORBIDDEN)

> **From R6.** Add `menu.results.not_placed`, `menu.name.controller_lost`, `menu.name.drop`, `menu.name.latin_only`, `menu.results.practice`, `menu.results.not_ranked`, `menu.results.next`, `menu.name.done`, `menu.name.editing`, `menu.name.no_limit`, `menu.results.stage_of`; and record the pair "ALL CLEAR" (Tally banner) and "MISSION COMPLETE" (Results verdict) in the glossary.

**Applier's note:** all eleven keys plus `menu.scores.empty_1cc`, `menu.credits.empty` and `menu.credits.licence_missing` are now in the Menus GDD string table with **English source text only** — the Bengali column reads "*(bn: pending native review)*" by deliberate choice (see Open questions). The glossary pair is recorded in the Menus string-table note as well, but `localization.md` is the registry of record.

### D7 — `design/gdd/localization.md`, key additions for Boards (FORBIDDEN)

> **From HS9.** Add keys `menu.scores.empty_hint`, `empty_1cc`, `practice_note`, `readonly`, `unsaved`, `reset_note`, and the `status_*` family with limits in the spec.

### D8 — `design/gdd/accessibility-options.md`, Rule 10 and the Menus dependency row (FORBIDDEN)

> **From C3.** Add Menus (Credits roll off, Manual mode) to the consumers of `reduce_motion`; the Tuning table's "Used by" column for `access.reduce_motion` currently reads "HUD, Parallax, Warning" and should add "Menus (Credits)".

**Applier's note:** the Menus side is applied (Rule 46 + tuning table), and `design/gdd/systems-index.md` row 22 now carries the soft dependency on 28.

### D9 — `design/gdd/input-and-player-mapping.md` + `design/gdd/stage-end-tally.md` Rule 17 (Input FORBIDDEN; Tally GDD outside my allowlist)

> **From H6.** Current: HUD default accept = START (which pauses); Tally: Fire accepts the Continue. Proposed: Input defines one `CONTINUE_ACCEPT` verb for both, with explicit START-versus-Pause priority while a slot is in Continue. HUD already follows the verb via `action_glyph`.

**Applier's note:** HUD Rule 24 and Open Question 10 are already verb-based and name `CONTINUE_ACCEPT`; this is the Input + Tally half. Until it lands, the glyph the HUD draws is undefined because the verb has no binding.

### D10 — `design/accessibility-requirements.md`, line 205 / T-05 (outside my allowlist; not owned by the settings reviewer either)

> **From R9.** Current: "pad disconnect holds the entry open when untimed". No change needed; confirmed consistent with the spec after fix 8. T-05 should add "DROP" to the pass condition.

### D11 — `design/art/art-bible.md` 7.5 / 7.10 (art-director's file, outside my allowlist)

> **From A6.** Consider (a) a lighter Alarm Red text variant reaching 4.5:1 on Char (style guide OQ 2) and (b) a statement that the 2/3 px clip floors and the 4 px headroom reservation are both valid.

**Applier's note:** (b) is already reflected in `design/ux/hud.md` and `arcade-ui-style.md` 2.2; (a) is an art-director decision and **no hex was invented** — see Open questions. Both are recorded in style-guide Open Question 2.

### D12 — `design/ux/settings.md` line 309 and `design/ux/high-scores.md` line 196 (settings.md FORBIDDEN; high-scores.md outside my allowlist)

> **From A7.** ("Alarm Red text allowed / only with words"): now bound by style guide 3.1 rule 3 (error glyph plus words, tier S or larger). Add the error glyph requirement if absent.

**Applier's note:** style guide 3.1 rule 3 is now **stricter** than A7 assumed — Alarm Red is barred as a text fill outright. Both specs must be reworded to "Cream words + Alarm Red plate edge and/or error glyph", not merely "with words".

### D13 — `design/ux/high-scores.md`, Open Question 1 (outside my allowlist)

> **From R7.** Resolve the unknown-plane conflict with an "Other" chip on Solo that exists only when such a board exists (the chip proposal already in `high-scores.md`); fix the Menus edge case which wrongly says those entries appear on co-op boards.

**Applier's note:** the **Menus half is applied** (Rule 40 + the edge case). Only closing `high-scores.md` OQ 1 remains, and that file's own reviewer may already have done it.

### D14 — `design/ux/flight-school.md`, pattern id reference (outside my allowlist)

Follow-up created by reconciliation 2: that spec flags the Coach card as "candidate P29", but P29 is now the Status block. Change the reference to **P30 Single-button modal over a stopped field**.

### D15 — `design/gdd/critical-break.md`, `cb_banner_wait_max` (outside my allowlist)

Noted in H7 as a parenthetical and still open in `design/ux/hud.md` OQ 10: CB uses `cb_banner_wait_max` 120 while HUD Rule 27 supersedes it with 180. CB's AC and debug values must be brought to 180 or the supersession removed.

### D16 — `design/gdd/audio.md` wording (FORBIDDEN; required by decision 3)

No change to a rule is needed, only one sentence of ownership so the three documents agree. Proposed wording for the Audio GDD's UI-sound section:

> "The UI sound **standard** — which cue plays for which interaction across screens — is owned by `design/ux/arcade-ui-style.md` section 5. This GDD owns the cue **ids** themselves and their sound design, bus routing and mix. `design/ux/interaction-patterns.md` cites both per pattern and restates neither."

---

## Not applied

1. **Bengali text for the 14 new Menus string keys (part of R6).** The keys, their English source text and their character context are in the Menus GDD string table, but the Bengali column reads "*(bn: pending native review)*" for every new row. Machine-drafting Bengali UI strings here would have put unreviewed text into a table whose other rows are reviewed, and the brief forbids inventing content. The localisation lead fills them when `ui_menus.csv` is extended (and `localization.md` is the registry of record — see D6). This is the only item I could not complete inside the allowlist; everything else not applied is deferred above because of file ownership.

---

## Open questions raised

1. **Lighter Alarm Red text variant (art-director).** Alarm Red `#E03A3E` on Cabinet Char measures 3.95:1, below the 4.5:1 floor, so style guide 3.1 rule 3 now bars it as a text fill. Whether to add a lighter "Alarm Red text" token that reaches 4.5:1 is an **art-director decision and a new art bible palette entry**. **No hex was invented.** Recorded in `design/ux/arcade-ui-style.md` Open Question 2 and in D11. Until such a token exists, no spec may draw text in Alarm Red.
2. **`required_mask` reachability for Sentry / Breaker (game-designer).** `design/gdd/tutorial.md` F3 keeps `required_mask = 1023`, but Rule 12 hides drills a plane cannot publish events for, so `complete` is unreachable for a Sentry-only or Breaker-only profile and `drill_ref`-keyed hints never settle. Both candidate fixes are written into F3 — (a) compute the mask over the drills available to the profile's planes, or (b) author plane-specific equivalents — and **neither was adopted**, because choosing would be inventing a game rule. New Tutorial Open Question 11; ties to the existing Open Question 7.
3. **DONE / SKIPPED stamp rect (HUD GDD owner + Tutorial).** GDD Rule 30b places the stamps "in its column" with no rect in any `HudLayout`, so the layout lint (AC-03) cannot check them and the compact 48 px column form may not have room. Raised as `design/ux/hud.md` Open Question 21; no rect invented.
4. **S-tier line pitch base (art-director).** `design/ux/credits.md` kept its 20 px Latin pitch as an authored value and now says so explicitly; it is **not** 12 x 1.2. The canonical base is `arcade-ui-style.md` Open Question 3, and the credits number should be restated or recomputed once that is answered. New credits Open Question 9.
5. **Continue accept verb binding (Input + Session + Tally).** The *shape* is agreed and written down (one `CONTINUE_ACCEPT` verb for HUD and Tally, with explicit START-versus-Pause priority while a slot is in Continue), but no button is chosen and no priority rule is written in the Input GDD. HUD GDD Open Question 10 and `design/ux/hud.md` Open Question 13 stay open; see D9.
6. **Save Rule 5 is now the only thing standing between the applied Results/Boards edits and a correct flow.** Menus Rules 35 and 40 assume the top-`board_size` test. Because the project's conflict rule gives a GDD the win, until D1 is applied the documents disagree and the older Rule 5 would still admit a not-placed run to Name entry. This is a sequencing risk, not a design question.
