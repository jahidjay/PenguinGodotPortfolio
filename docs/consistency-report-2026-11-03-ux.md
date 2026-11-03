# Consistency Check Report — UX review wave 5 (post-amendment)

**Date**: 2026-11-03
**Scope**: targeted, not a full sweep. Checks only what the 7-document UX review pass and its two applier batches changed.
**Inputs read**: `production/gdd-reports/_applied-ux-amendments-1.md` (28 amendments, 13 files), `production/gdd-reports/_applied-ux-amendments-2.md` (21 items, 21 files, 49 edits), `design/registry/entities.yaml`.
**Not redone**: the full 32-GDD sweep of `docs/consistency-report-2026-11-03.md` (7 conflicts, all fixed).

**Verdict: PASS with 2 conflicts for an owner.** 8 of 8 shared decisions hold across every document that states them. 20 stale cross-references were found and fixed. 2 genuine conflicts remain, both pre-existing and neither introduced by this pass. 5 further items are recommendations in files that were being edited concurrently.

**Files not edited by this check** (hard rule, art-director in flight): `design/art/art-bible.md`, `design/ux/arcade-ui-style.md`, `design/ux/hud.md`. All three were read; findings in them are recorded as recommendations below.

---

## 1. Per-decision verification

### 1.1 Ranked = `score >= min_ranked_score` **and** `rank_index < board_size` (10) — ✅ CONSISTENT

| Document | States it as | Verdict |
|---|---|---|
| `save-settings-high-scores.md` Rule 5 (owner) | both halves, `rank_index < board_size` named, `preview_rank` returns a rank or `not placed`, a not-placed run asks for no initials and stores nothing | ✅ |
| same, F1 | `ranked = (new_score >= min_ranked_score) AND (rank_index < board_size)`; worked example of the full-board case | ✅ |
| same, "Run submit" + **AC-03a** | name entry only when a rank came back; the 1,200,000-on-a-full-board case returns `not placed` | ✅ |
| `menus-title-plane-select.md` Rule 35 | rank strip reads `RANK {n}` / **`Not in top {n}`** / nothing at all; cites Save Rule 5 | ✅ |
| same, Rule 40 | one rank per co-op row; 1CC filter keeps true board ranks | ✅ |
| `online-leaderboards-boss-rush.md` Rule 1 | "Save ranked it locally (Save Rule 5, so score at least `min_ranked_score` and in the local top `board_size`)" | ✅ |
| `design/ux/results-name-entry.md` (Resolved conflicts, Rank strip, Not-placed state, Data table, AC) | identical, including the "not placed treated exactly like unranked — no Name entry" path | ✅ |
| `design/ux/high-scores.md` "Run did not place" | identical, and correctly refers the per-run explanation to the Results spec | ✅ |
| `design/accessibility-requirements.md` 5.2 | a run that scored but did not place asks for **no initials** | ✅ |
| registry `board_placement` | expression and note match Save F1 / Rule 5 | ✅ |

The "not placed" path is stated the same way in all seven places. The sequencing risk flagged in batch 1's open question 6 (Save Rule 5 lagging the Menus edits) is gone — D1 landed first.

### 1.2 `CONTINUE_ACCEPT` = Fire only; Start pauses — ✅ CONSISTENT

| Document | States it as | Verdict |
|---|---|---|
| `input-and-player-mapping.md` **Rule 24b** (owner) | one verb, `fire` pressed by that slot; Start does not accept, it pauses (Rule 25); only the slot in Continue can accept; the verb follows a remap; not a tally skip | ✅ |
| same, action table + HUD interactions row | `pN_fire` "accepts a Continue (`CONTINUE_ACCEPT`, Rule 24b)"; `pN_start` "**Never** accepts a Continue" | ✅ |
| `hud.md` Rule 24 + **Open Question 10 CLOSED** | verb-based `action_glyph(slot, CONTINUE_ACCEPT)`, resolved to Fire, "no accept-versus-Pause priority to decide" | ✅ |
| `stage-end-tally.md` Rule 17 | a **Fire** press by that slot; Start never accepts; not a tally key | ✅ |
| `game-events-and-session.md` Continue-prompt UI line | same verb, same Start rule | ✅ |
| `design/ux/hud.md` Continue-plate Content row + **OQ 13 CLOSED** | same | ✅ |
| `design/ux/stage-tally.md` Continue row | same | ✅ |
| registry `continue_accept_verb` = `fire` | note names both surfaces and the Start rule | ✅ |

Four surfaces plus the registry agree, and no document still says "default START".

### 1.3 Co-op ranking: one team rank by `team_score`, lead player = highest `players[].score`, ties to the lower slot — ✅ CONSISTENT

| Document | Verdict |
|---|---|
| `menus-title-plane-select.md` Rule 35 (one team rank, `team_score`) and Rule 40 (lead player definition verbatim, `players[]` in slot order, never a rank per player) | ✅ |
| `coop-and-team-chain.md` Rule 18 + **Open Question 8 closed** with the same wording | ✅ |
| `save-settings-high-scores.md` Rule 11 note (lead player, ties to the lower slot, cross-linked to Menus Rule 40 and Co-op OQ 8) | ✅ |
| `design/ux/results-name-entry.md` Co-op rank state + AC | ✅ |
| `design/ux/high-scores.md` "Rank on a co-op row (decision)" + AC + OQ 11 closed | ✅ |

### 1.4 Online platform scope: Switch / Switch 2 and mobile ship no adapter and do not list the Online tab — ✅ CONSISTENT (one stale note fixed)

| Document | Verdict |
|---|---|
| `docs/architecture/adr-0007-online-services.md` §2 Adapters, §2 Selection, diagram | ✅ `HttpAdapter` "technically capable on all platforms — enabled on PC and Web only"; Switch / Switch 2 and iOS / Android always `NullAdapter`, Online tab not listed |
| `online-leaderboards-boss-rush.md` Rule 6 table row, Rule 33 | ✅ explicit row; Rule 33 separates "service unavailable" (one-line notice) from "no adapter on this platform" (tab not listed at all) |
| `design/ux/high-scores.md` "Tab not listed (platform)" | **FIXED** — the row still carried a stale parenthetical claiming an OL-versus-ADR-0007 conflict ("ADR-0007 says `HttpAdapter` is all platforms — conflict, see report") and quoted OL Rule 6's retired "Consoles, mobile (later): out of scope" text. Replaced with the resolved statement. |
| same, ACs and Data rows | ✅ already consistent ("on a build with only `NullAdapter` the Online tab is not listed") |

### 1.5 Alarm Red is never a text fill — ✅ CONSISTENT in the UX layer, 2 stale GDD permissions fixed

| Document | Verdict |
|---|---|
| `design/ux/arcade-ui-style.md` 3.1 palette row, rule 3, §8 checklist | ✅ owner; **note:** the art-director has since landed the follow-on decision (see §4.1) |
| `design/art/art-bible.md` 4.1, 7.10 | ✅ same (read only, not edited) |
| `design/ux/settings.md` States "Save failure", Accessibility contrast line | ✅ "never a text fill", Cream words + Alarm Red edge and/or error glyph |
| `design/ux/high-scores.md` Status block, failure styling, contrast, colour-independence, ACs | ✅ four places, all "never a text fill anywhere" |
| `design/ux/results-name-entry.md` | ✅ makes no Alarm Red text claim — nothing to fix |
| `design/ux/interaction-patterns.md` P29 | ✅ "never Alarm Red text", cites style guide 3.1 rule 3 |
| `menus-title-plane-select.md` Style note (line ~506) | **FIXED** — still read "Alarm Red only for corruption/failure text". Rewritten to the amended rule, pointing at the style guide and art bible 4.1 / 7.10 as the owners of which red may be used for words. No hex transcribed (the owning files are in flight). |
| `save-settings-high-scores.md` V/A "Save-failed notice" | **FIXED** — still read "Red only for corruption/failure text". Same rewrite. |

### 1.6 Pattern ids: P29 = Status block, P30 = single-button modal (Coach card) — ✅ CONSISTENT

| Document | Verdict |
|---|---|
| `design/ux/interaction-patterns.md` catalog + §P29 + §P30 + numbering note | ✅ P29 Status block, P30 single-button modal over a stopped field, P31 controller-lost plate |
| `design/ux/high-scores.md` header + Status block row | ✅ P29 accepted (no longer "proposed"), names P30 as the different pattern |
| `design/ux/flight-school.md` Coach card row + header | ✅ P30, with the history of the moved id |
| whole-repo grep for P29 / P30 / P31 | ✅ no third document claims either id; no "candidate P29" or "proposed P29" remains anywhere |

### 1.7 Tutorial `required_mask` per plane; `drills_done` one profile-wide bitmask — ✅ CONSISTENT (2 stale restatements fixed)

| Document | Verdict |
|---|---|
| `tutorial.md` F3 (formula, variable table, two examples, resolution paragraph), Rule 12, Rule 24, **OQ 11 closed / OQ 7 narrowed** | ✅ owner; `required_mask(plane) = 1023 & available_mask(plane)`, `complete` = OR over planes, `drills_done` stays one profile-wide bitmask, Save key width unchanged |
| registry `school_required_mask` = `"1023 & available_mask(plane)"` | ✅ matches, with the MVP-unchanged note |
| `save-settings-high-scores.md` schema row for `tutorial.drills_done` | **FIXED** — still said "bits 0–9 required = `school_required_mask` 1023", a fixed value the registry and Tutorial no longer hold. Now points at Tutorial's per-plane mask and states that this key remains one profile-wide bitmask of unchanged width. |
| `design/ux/flight-school.md` "All required done" state | **FIXED** — still tested `drills_done & 1023 = 1023`. Now the per-plane form (= 1023 on both MVP planes). |
| `design/ux/flight-school.md` Open Question 12 | **FIXED** — still asked the game-designer to decide whether the mask becomes per-plane. Closed with the adopted answer; the spec's own "header counts visible required rows" decision is confirmed as compatible. |
| `tutorial.md` AC-25 (`drills_done` 1023 → complete, 1022 → not) | ✅ valid as written — both MVP planes have `available_mask` 2047 |

---

## 2. Stale cross-references found and fixed (20)

All fixes are stale-status or transcription corrections against a document that clearly owns the value. No rule, constant or layout value was invented.

| # | File | What was stale | Fix |
|---|---|---|---|
| 1 | `design/gdd/save-settings-high-scores.md` | `tutorial.drills_done` row claimed a fixed `school_required_mask` 1023 | points at Tutorial's per-plane mask |
| 2 | `design/gdd/save-settings-high-scores.md` | V/A notice allowed Alarm Red failure **text** | amended Alarm Red rule |
| 3 | `design/gdd/menus-title-plane-select.md` | Style note allowed Alarm Red failure **text** | amended Alarm Red rule |
| 4 | `design/gdd/menus-title-plane-select.md` | string-table note named **`ui_menus.csv`**; Localization Rule 5 owns the name and calls it **`ui_menu.csv`** | corrected, with the owner cited |
| 5 | `design/gdd/menus-title-plane-select.md` | note said the ALL CLEAR / MISSION COMPLETE glossary pair "must be registered in `localization.md`" | it **is** registered (Localization Rule 30) |
| 6 | `design/ux/flight-school.md` | Title row: "needs a Save trigger, see report amendment 2" | Save Rule 20 trigger landed (+ Tutorial Rules 16 / 25a) |
| 7 | `design/ux/flight-school.md` | "All required done" used the fixed 1023 test | per-plane form |
| 8 | `design/ux/flight-school.md` | Open Question 12 (per-plane mask) still open | closed |
| 9 | `design/ux/flight-school.md` | Open Question 15 (per-plane tip text) still open | answered by Tutorial Rule 13; the one genuinely remaining half (registering `tut.drill.<id>.tip.<kit>` if per-kit keys are chosen) is named |
| 10 | `design/ux/results-name-entry.md` | wheel-block note "amendment filed" | applied (Menus Rule 36 + V/A row) |
| 11-15 | `design/ux/results-name-entry.md` | Open Questions 1, 2, 4, 4a, 4b, 8 still marked *Amendment filed* / *Decide elsewhere* / *Add to the pattern library* | all updated to **Applied / Closed** against the landed Menus Rule 35 and mock-up, Rule 36 + V/A, Rule 40, Save Rule 5 + AC-03a, P31 and Localization Rule 30 |
| 16 | `design/ux/results-name-entry.md` | 11 new string keys still marked **(proposed)** with Bengali "needs draft" | marked **(registered)** against the Menus string table and Localization Rule 5a; Bengali restated as *pending native review* (the known-open item), plus one status line |
| 17 | `design/ux/high-scores.md` | "Tab not listed" row claimed an unresolved OL-versus-ADR-0007 platform conflict | resolved statement |
| 18 | `design/ux/credits.md` | Open Question 8: keys "still needed" in `localization.md` | closed — both are in Rule 5a, and `credits.section.*` / `menu.title.credits` are confirmed there |
| 19 | `design/ux/credits.md` | Open Question 7 asked whether licence bodies are inline or read from `assets/fonts/LICENSE` | answered by Menus Open Question 15 (inline `body` on a `kind = LICENCE` record in `credits.tres`); the length and the real licence set stay the producer's call |
| 20 | `design/ux/settings.md` | keep-list note said "needs Save amendment A1" and "until Save Rule 30 is amended the GDD wins (it keeps only `profile.last_initials` and `tutorial.*`)" | the amendment landed: Rule 30, AC-26 and registry `reset_settings_keep_list` all carry the full list. The keep-list AC also gained `touch.hints_seen`. |

Each of the seven edited files gained a one-line `Revision 2026-11-03 (UX consistency check, wave 5)` header note.

---

## 3. Conflicts needing an owner's decision (2)

> **RESOLVED 2026-11-03 (final doc closeout, see `production/gdd-reports/_final-doc-closeout.md`).** **C1:** one id scheme everywhere - **`sfx_ui_*`**. The style guide section 5, `interaction-patterns.md`, the Menus audio table and the one `ui.deny` row inside `audio.md` were all rewritten; `ui.rank` resolves to `sfx_ui_new_best`; six Menus-only cues (`sfx_ui_lock`, `sfx_ui_unlock`, `sfx_ui_start_run`, `sfx_ui_hold_tick`, `sfx_ui_hold_done`, `sfx_ui_toggle_lang`) gained rows in the Audio GDD, and every cue id referenced in the UX layer now has one. **C2:** "Delete my online data" lives in **Settings > Online only**; Menus Rule 39 and its Dependencies row were amended to link there instead of hosting it, and `design/ux/high-scores.md` Open Question 14 is closed. **Section 4.1-4.3 recommendations are also applied** (Alarm Flare offered in `settings.md`, `high-scores.md` and `interaction-patterns.md` P29; the HUD GDD carries the stamp rects; the style guide's stale "missing IDs" line is replaced). 4.4 and 4.5 remain as written (no action while tip text stays plane-neutral; rule reordering is cosmetic).

### 🔴 C1 — UI sound cue id naming. Owner: **Audio (24)**, with the art-director

Batch 2 decision 3 made `design/gdd/audio.md` the owner of the UI cue **ids**. Three naming forms are now live for the same cues:

- `design/gdd/audio.md` Sound Event List: **`sfx_ui_nav_tick`, `sfx_ui_confirm`, `sfx_ui_new_best`, `sfx_ui_deny`, …**
- `design/ux/arcade-ui-style.md` §5 (which the same decision made the owner of the *standard*): **`ui_nav_tick`, `ui_confirm`, `ui_new_best`, `ui_deny`, …** — the `sfx_` prefix is dropped throughout
- `design/ux/interaction-patterns.md` Sound Standards: the same unprefixed `ui_*` ids (correctly cited from the style guide)
- `design/gdd/menus-title-plane-select.md` audio table: a **third** form, **`ui.rank`** (dotted, and with no counterpart in the audio id table); `audio.md` itself refers to a "Menus cue `ui.deny`" in one row

The ownership statement now makes this decidable, and the style guide's own tie-break says "a style-guide cue id not in the Audio table is a bug in the style guide, not a new sound" — so by that rule most of §5 currently reads as a bug. Not fixed here: the style guide is one of the three files under concurrent edit, and `design/ux/results-name-entry.md` Open Question 17 already records the `ui.rank` half as Audio's call. **Decision needed:** one id spelling (`sfx_ui_*` is the owner's), then §5, the pattern library mapping and the Menus audio table are brought to it, and `ui.rank` is either mapped to `sfx_ui_new_best` or given its own id.

### 🔴 C2 — "Delete my online data" lives in two places. Owner: **Menus (22)**, with Online (32). [STRETCH]

- `menus-title-plane-select.md` Rule 39 (and the Dependencies row for 32) puts the **Delete-my-data** screen under the **Online tab**.
- `online-leaderboards-boss-rush.md` Rule 19 and its UI list put **Delete my online data** in **Settings > Online** — and `design/ux/settings.md` now specifies it there.

Pre-existing (`design/ux/high-scores.md` Open Question 14 raised it), but the pass spent its stated dependency: that question said "needs one decision before the Settings spec", and the Settings spec now exists, is reviewed, and placed the action. The OQ entry has been restated as a live conflict rather than a pending dependency; only one of the two rules should name the screen.

---

## 4. Recommendations (files under concurrent edit, or for another owner)

### 4.1 `design/ux/arcade-ui-style.md` + `design/art/art-bible.md` — the Alarm Red follow-on has already landed; the specs amended in batch 2 now understate it

The art-director closed style-guide Open Question 2 while this check was running: art bible 4.1 now carries **Alarm Flare `#F2494D`** (4.76:1 on Char, computed) as the red **text** token, and style-guide 3.1 rule 3 reads "two reds, two jobs" — `#E03A3E` never a text fill, red *words* are Alarm Flare, one headline line per screen, Cream under `hud_contrast` HIGH.

Nothing is contradictory: `design/ux/settings.md`, `design/ux/high-scores.md` and `interaction-patterns.md` P29 all say "Cream words plus an Alarm Red plate edge and/or error glyph", which is still permitted. But they were written in the window when **no** red text token existed, so they are now stricter than the owner's rule and none of them mentions Alarm Flare. **Recommendation:** once the style guide settles, a short follow-up pass should offer the Flare headline option in those three places (and in the two GDD lines fixed in §2, which deliberately point at the owner instead of naming a hex). This is a known-open item per the brief and is **not** reported as an inconsistency.

### 4.2 `design/ux/hud.md` Open Question 21 is closed by the art-director; the GDD side does not yet carry the rect

`design/ux/hud.md` now gives the DONE / SKIPPED stamp a **16x11** rect at (224,4) in 1P and (73,16) per column in 3-4P, with 2P and Compact 48 suppressing the in-strip stamp. `design/gdd/hud.md` Rule 30b still places the stamps "in its column" with no rect, and `tutorial.md` Rule 21 restates the GDD. **Recommendation:** the HUD GDD owner picks the rect up into Rule 30b (so the layout lint AC-03 can check it) and Tutorial Rule 21 cites it. Expected and not flagged as an inconsistency.

### 4.3 `design/ux/arcade-ui-style.md` §5 closing line is stale

It reads "Missing IDs for tutorial, Sentry/Breaker and touch are tracked in the consistency report". `design/gdd/audio.md` Dependencies records those ids as **assigned 2026-11-03** (`sfx_kit_sentry_plant` … `sfx_kit_stock_ready`, `sfx_bomb_bastion_loop`, `sfx_bomb_backlash_sweep`, `sfx_ui_upload_*`, `sfx_rush_refit`), pending audio-director confirmation. Recommend updating that sentence when the file is next touched.

### 4.4 `design/gdd/localization.md` — register the per-kit tip variant if it is chosen

Tutorial Rule 13 allows either plane-neutral strings **or** per-kit keys `tut.drill.<id>.tip.<kit>`. Localization Rule 5 registers only `tut.drill.<id>.title/goal/tip`. No action while the text stays plane-neutral; the dependency is now named in `design/ux/flight-school.md` Open Question 15.

### 4.5 `design/gdd/input-and-player-mapping.md` — rule ordering is cosmetically out of sequence

The new rules read **24, 24b, 24c, 24a** (batch 2 inserted 24b/24c ahead of the pre-existing 24a). No reference is broken and no content is affected; worth reordering next time the file is edited.

---

## 5. Registry check — ✅ ALL MATCH

Constants the pass added or amended in `design/registry/entities.yaml`, each checked against the GDD that owns it:

| Constant | Registry value | Owner GDD | Verdict |
|---|---|---|---|
| `continue_total` | 10 STANDARD / 30 EXTENDED / 30 UNTIMED-with-another-slot-Alive / `null` | `game-events-and-session.md` F4 | ✅ identical, including nullability and the HUD HF2 reference |
| `continue_accept_verb` | `fire` | `input-and-player-mapping.md` Rule 24b | ✅ incl. the "Start does not accept" rule and both surfaces |
| `menu_hold_verb` | `fire` | `menus-title-plane-select.md` F6, Rule 43 | ✅ F6's `held_ticks` row is Fire-only and `start.held_ticks` is gone; the Reset-display / `display_reset` distinction matches Menus Rule 43, AC-50 and Display's UI table |
| `reset_settings_keep_list` | `language, access.first_run_prompt_done, profile.*, tutorial.*, touch.hints_seen` | `save-settings-high-scores.md` Rule 30, AC-26 | ✅ exact |
| `school_required_mask` | `"1023 & available_mask(plane)"` | `tutorial.md` F3, Rule 12 | ✅ exact (and the one stale consumer in Save was fixed, §2 item 1) |
| `banner_wait_max` | 180, with `cb_banner_wait_max` recorded as retired everywhere | `hud.md` Rule 27 | ✅ `critical-break.md` F5 formula, F5 variable table, F5 example (drop tick 2182), tuning row (retired), defaults list and AC-44 ("no `cb_banner_wait_max` key is present") all read 180; no live use of the retired knob remains anywhere in `design/` or `docs/` |
| `board_placement` | `ranked = new_score >= min_ranked_score AND rank_index < board_size` | `save-settings-high-scores.md` F1, Rule 5 | ✅ exact, incl. the `not placed` note |

No stale registry entries. No new cross-system facts found that are missing from the registry.

---

## 6. Known-open items, confirmed not reported as conflicts

Per the brief, these were verified as deliberate and left alone: the lighter Alarm Red hex (now resolved as Alarm Flare by the art-director, §4.1), the DONE / SKIPPED stamp rect (§4.2), the two Localization F3 font-spike numbers (D10 plate width, INDIAN 81 px), which events each Target kit publishes (Tutorial OQ 7, narrowed to a Kits question), the accepted `tutorial.complete` OR-over-planes looseness, `nav_group_prev` / `nav_group_next` (suppression rule binds; either answer satisfies Accessibility Rule 21a and Input Rule 24c), and the Bengali cells pending native review.

---

## 7. Summary

- **Items verified**: 8 shared decisions across 24 documents, plus 7 registry constants = **39 checks**
- **Fixed**: **20** stale references / transcription mismatches in **7** files
- **Conflicts for an owner**: **2** (C1 UI sound cue id naming — Audio 24; C2 Delete-my-data location — Menus 22 / Online 32)
- **Recommendations in files under concurrent edit**: **5**
- **Registry**: clean

**Verdict: PASS** — no decision from the UX pass is stated two different ways anywhere. The two conflicts are pre-existing and neither blocks the pass; C1 became decidable *because* of this pass's ownership decision.
