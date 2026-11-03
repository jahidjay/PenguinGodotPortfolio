# Final Documentation Closeout — 2026-11-03

**Scope of this pass**: `design/`, `docs/`, `production/` only. Nothing under `src/`, `data/`, `tests/` or `project.godot` was touched (the main session is writing code there).

**Inputs**: `production/ux-reports/_art-director-decisions.md` (5 unapplied cross-document amendments A1–A5), `docs/consistency-report-2026-11-03-ux.md` (2 owner conflicts C1/C2 + 5 recommendations).

**Outcome**: design is closed out and formally accepted. `production/stage.txt` = **Pre-Production**.

---

## Accept counts

| Set | Count | New status |
|---|---|---|
| System GDDs in `design/gdd/` | **32** | `Approved (2026-11-03)` (from "Designed (pending review)" / "Designed (pending /design-review)") |
| Game concept (`design/gdd/game-concept.md`) | **1** | `Approved (2026-11-03)` (kept the 2026-10-23 brainstorm approval in the line) |
| Systems index (`design/gdd/systems-index.md`) | **1** | `Approved (2026-11-03)`; all **32** status cells rewritten to `**Approved** (2026-11-03)` |
| ADRs in `docs/architecture/` | **8** | `Accepted (2026-11-03)` |
| ADR-0001 (exception) | **1** | `Accepted (provisional) — pending benchmark V1, in progress 2026-11-03` |
| UX specs in `design/ux/` | **12** | `Approved (2026-11-03)` |

**ADR total 9/9 touched**: 0002–0009 accepted; 0001 provisional only.
**UX total 12/12**: 9 were `Draft`, 3 (`high-scores.md`, `hud.md`, `settings.md`) read `Reviewed`. The brief named the 9 Drafts but also said all 12 have been reviewed and revised, so all 12 were approved; each line keeps its previous status after an em dash for audit.

Every accepted document gained one `> **Accepted 2026-11-03** (final doc closeout)` line under its Status, which states that items still in Open Questions stay open. `Last Updated` is 2026-11-03 everywhere, and each file changed in substance also gained a one-line revision note.

### Why ADR-0001 is not unconditionally accepted

Its acceptance condition is the bullet benchmark (Validation Criterion V1). `docs/architecture/spike-0001-bullet-bench-v1.md` records a **desktop PASS** with roughly 2x headroom, but the ADR accepts on **REF-WEB**, which is still unmeasured — so the number the acceptance depends on does not exist yet. The status says so explicitly, says the fallback (a new GDExtension ADR at the next free number) applies if V1 fails, and says downstream readers must treat it as provisional until the V1 result is recorded in the ADR. It is not silently upgraded.

---

## Task 1 — the art director's 5 amendments, applied

**A1 — DONE / SKIPPED stamp into the HUD GDD** (`design/gdd/hud.md`)
- Rule 30b now carries the asset spec (one 16x11 asset: 3 px border, 10x5 interior; DONE = Cream border + check, SKIPPED = `#A89E8A` border + dash) and the `HudLayout` `stamp` rects: `hud_layout_1p` = **(224,4,16,11)**; `hud_layout_3_4p` = **(73,16,16,11)** per column (absolute x 73 / 163 / 253 / 343, y 16); `hud_layout_2p` and `hud_layout_compact48` = **`stamp = none`** explicitly.
- All four layout tables gained a `DONE / SKIPPED stamp` row, with the art director's clearance figures verbatim (1P: 4 px to the join plate, 6 px to MAX, 7 px above drone ticks, 22 px to the chain plate; 3-4P: 3 px to the lamp, 1 px under the score row, 1 px above the kit bar, 1 px to the next column).
- **Layout-lint clause** added to Rule 9 and to **AC-03**: every layout must carry a `stamp` key; a rect must overlap no other element rect in its layout; `stamp = none` is a valid explicit value; a missing key fails the lint.
- **New AC-28b** (the AC the report asked for): the 1P draw at (224,4,16,11) for 90 ticks with no overlap, the 3-4P per-column draw, nothing drawn in 2P / Compact 48, and the SKIPPED variant at both `hud_contrast` settings.
- `design/gdd/tutorial.md` Rule 21 did **not** repeat the old stamp wording (Rule 21 is the strip mark) — it now states that the strip mark and the stamp are separate elements and cites Rule 30b's rects. The restatements that *did* carry the old wording were Rules 16 and 22 and the Visual/Audio "DONE stamp" paragraph; all three were corrected.
- `design/ux/hud.md` Open Question 21 moved from "Closed (amendment pending)" to **"Closed and applied"**.

**A2 — per-slot DONE / SKIPPED where the HUD has no stamp** (`design/gdd/tutorial.md`, `design/ux/flight-school.md`)
- New **Tutorial Rule 16a**. In 2P and Compact 48 the Flight School surface itself carries the per-slot result: through the Done beat (`done_beat_ticks` 90) and on the return to the list it shows **one stamp per joined slot in slot order**, reusing the **14x14 School-list stamp form already specified** in that GDD's Visual/Audio (ring-pattern frame; check glyph = DONE, dash = SKIPPED, empty frame = not attempted), with the per-slot `sfx_tut_drill_done` cue. Rules 16 and 22 now point at it.
- *Owner choice recorded:* the art director left the mechanism open ("own plate, toast, or audio"). The option chosen reuses an asset the Tutorial GDD already defines, so **no new colour, hex, rect or asset was invented**, and nothing is drawn over the live play field. If the Tutorial owner prefers a toast or its own plate instead, Rule 16a is the single place to change.
- `design/ux/flight-school.md` gained the per-slot result row in its component table (and the real 16x11 HUD rects on the existing stamp row) plus a **2P / Compact 48 strip** variant that states the row is not optional there, since 2P co-op is the most common multi-player case.

**A3 — accessibility exception** (`design/accessibility-requirements.md` §3.2)
An exception row now sits directly under "Contrast of plated UI at least 7:1 on menus": the single **Alarm Flare `#F2494D`** headline status line at **4.76:1** (hand-computed; minimum 4.5:1) is allowed because the same words repeat in Cream on that screen, an Alarm Red edge and/or error glyph is also present, and it renders Cream under `hud_contrast` HIGH. Without it the new token contradicted the committed COMPREHENSIVE tier.

**A4 — registry and `HudTheme`**
- `design/registry/entities.yaml`: added **`ALARM_FLARE = #F2494D`** (text only, never a fill, full use rules, both computed ratios, the protanopia caveat) and — for the split to be legible in one place — **`ALARM_RED = #E03A3E`** (fill only, never a text fill). The file had no colour tokens before; these are the first two.
- `design/gdd/hud.md` Rule 33 (`HudTheme`) now names both reds with their roles, and states that Flare is never drawn in the HUD strip, a slot column, beside a P1 pip or ring, or in the play field, and is never era-tinted.
- `design/gdd/accessibility-options.md` Rule 16 and **AC-20** record the one further HIGH-contrast difference: a Flare headline resolves to Cream, while `#E03A3E` edges and glyph fills are identical in both themes (AC-20 previously said "no other `HudTheme` colour differs").

**A5 — `design/ux/settings.md` line ~6 reworded**
The blanket "Alarm Red is never a text fill at all" is now stated as true **only of `#E03A3E`**, with the Flare role named; the superseded wave-5 note is kept and marked as superseded in part.

---

## Task 2 — Alarm Flare follow-up (3 specs brought in line with art bible 4.1 / style guide 3.1)

All three were written while no red text token existed, so they were stricter than the owner's rule and none mentioned Flare. Each now carries the "two reds, two jobs" split — `#E03A3E` for edges, bar fills, end caps and glyph fills; `#F2494D` for text, **one headline line per screen**, still paired with an error glyph and a **Cream explanatory sentence**, Cream under `hud_contrast` HIGH, never a fill:

- `design/ux/settings.md` — States "Save failure" (the "Could not save" toast headline is the single line allowed to take Flare) and the Accessibility contrast line. The stale sentence "No lighter red text token exists (style guide Open Question 2)" was replaced; the 4.76:1 exception is cross-referenced to `accessibility-requirements.md`.
- `design/ux/high-scores.md` — Status block row, Failure styling row, the colour-independence bullet, the contrast bullet (Flare's 4.76:1 added beside Alarm Red's 3.95:1, with the greyscale caveat) and the Stretch reason-code checklist item.
- `design/ux/interaction-patterns.md` **P29** — the full Flare clause, including that an all-Cream block remains equally correct.

Nothing was made mandatory: offering Flare is an option, and a screen that needs no red headline stays Cream.

---

## Task 3 — the 2 conflicts resolved

### C1 — UI sound cue id naming → **one scheme: `sfx_ui_*`**

`design/gdd/audio.md` owns the ids, so its spelling won. Rewrites (ids in backticks only; 11 files, 162 id occurrences):

| File | Was | Now |
|---|---|---|
| `design/ux/arcade-ui-style.md` §5 (owner of the *standard*) | `ui_nav_tick` … (19 ids) | `sfx_ui_*` |
| `design/ux/interaction-patterns.md` | unprefixed `ui_*` | `sfx_ui_*` |
| `design/ux/settings.md`, `high-scores.md`, `results-name-entry.md`, `flight-school.md`, `credits.md` | unprefixed `ui_*` | `sfx_ui_*` |
| `design/gdd/menus-title-plane-select.md` audio table | dotted `ui.nav`, `ui.lock`, `ui.rank`, … (16) | `sfx_ui_*` |
| `design/gdd/tutorial.md` | `ui.deny`, `tut.drill_done`, `tut.coach_open` | `sfx_ui_deny`, `sfx_tut_*` |
| `design/gdd/audio.md` itself | the `ui.deny` and `ui.pause` references inside its own rows | `sfx_ui_*` |

- **`ui.rank` resolved to `sfx_ui_new_best`** — the cue the style guide already assigns to "NEW BEST stamp, new board entry". No separate rank sound minted. `design/ux/results-name-entry.md` Open Question 17 is closed with that resolution.
- **Six Menus-only cues had no row in the Audio GDD** and gained one (`sfx_ui_lock`, `sfx_ui_unlock`, `sfx_ui_start_run`, `sfx_ui_hold_tick` / `sfx_ui_hold_done`, `sfx_ui_toggle_lang`), each carrying the sound character the Menus table already described, marked *ids assigned 2026-11-03, audio-director to confirm the sound design*. They were also added to the style-guide standard.
- **Verified**: every cue id referenced anywhere in `design/ux/` now has a row in the Audio GDD's Sound Event List (21 distinct ids, all matched). A one-paragraph "One id scheme" decision was recorded in `audio.md` beside the existing ownership statement.
- **Deliberately not renamed** (not sound cues): `ui_tint` (the era accent colour on `EraDef` / `HudTheme`), and the string-table names `ui_menu.csv`, `ui_tally`, `ui_touch`, `ui_online`, `ui_rush`, `ui_banner`, `ui_settings`, `ui_tutorial` plus the `ui.touch.*` string keys.
- Also applied from the report's §4.3: the stale style-guide §5 closing line ("Missing IDs … tracked in the consistency report") now lists the ids assigned in `audio.md` on 2026-11-03 and notes touch has no cue of its own.

### C2 — "Delete my online data" → **Settings > Online only**

- `design/gdd/menus-title-plane-select.md` **Rule 39** amended: the screen is dropped from the scores screen's Online tab; that tab may show a focusable **link** that opens Settings > Online but never hosts the `HOLD_BUTTON` action. The Dependencies row for system 32 was corrected the same way.
- `design/gdd/online-leaderboards-boss-rush.md` Rule 19 and `design/ux/settings.md` were already correct and were left untouched.
- `design/ux/high-scores.md` **Open Question 14 closed** with that resolution.

---

## Deliberately left open (not closed, by instruction)

1. **Two Localization F3 font-spike measurements** — D10 plate width and the INDIAN 81 px figure. Still unmeasured; also named in ADR-0009's new status line.
2. **Which events the Sentry / Breaker Target kits publish** — Tutorial Open Question 7, narrowed to a Kits question, untouched.
3. **Bengali strings pending native review** — every "pending native review" marker left as-is.
4. **Protanopia re-measurement of Alarm Flare** — stated as open in the registry note, in `settings.md` and in `high-scores.md`; the art-director report's caveat that *all* contrast figures are hand-computed and need renderer re-measurement in the font spike is preserved.

Also still open and untouched (not in the brief's list, but not closed by this pass): bright Gold `#FFE27A` acceptance (HUD Open Question 3 / art bible 4.1 note); the REF-PHONE hue eyeball for Flare; the per-kit tip-key registration in `localization.md` if per-kit `tut.drill.<id>.tip.<kit>` keys are ever chosen (consistency report §4.4); every ADR's validation spike, which the new statuses keep as required implementation work.

---

## Remaining inconsistencies / blockers

1. **ADR-0001 is the only live blocker.** `spike-0001-bullet-bench-v1.md` is a desktop PASS; **REF-WEB is unmeasured**, so V1 is not settled. Its status stays provisional until the main session's benchmark lands and the REF-WEB number is written into the ADR. Everything downstream (bullet manager, tick order, VFX budgets) reads on that assumption.
2. **Two `design/` root documents still read `Draft`**: `design/accessibility-requirements.md` and `design/player-journey.md`. Both are cited everywhere as committed (the COMPREHENSIVE tier; the journey phases), but neither is in `design/gdd/`, `docs/architecture/` or `design/ux/`, so neither was in the enumerated accept scope and I did not change them. **Recommend approving both** in the same breath — one line each.
3. `design/art/art-bible.md` reads `Complete, all 9 sections` — not a Draft/Designed/Proposed state, so it was left as-is. It is the owner of the Flare token and is consistent with everything written this pass.
4. **Tutorial Rule 16a names a mechanism the art director left to the owner.** It is implemented as "reuse the 14x14 School-list stamp form", which invents nothing; if the Tutorial owner wants a toast or a dedicated plate, Rule 16a is the only place to edit.
5. **Cosmetic, left as the report recommended**: `design/gdd/input-and-player-mapping.md` rules read 24, 24b, 24c, 24a (consistency report §4.5). No reference is broken.
6. Both source reports were annotated with a resolution block (`docs/consistency-report-2026-11-03-ux.md` §3, `production/ux-reports/_art-director-decisions.md` amendment section) so nobody re-applies them.

## Files changed

`design/gdd/`: all 32 system GDDs (status), plus substantive edits in `hud.md`, `tutorial.md`, `audio.md`, `menus-title-plane-select.md`, `accessibility-options.md`; `game-concept.md`, `systems-index.md`.
`design/ux/`: all 12 specs (status), plus substantive edits in `arcade-ui-style.md`, `interaction-patterns.md`, `settings.md`, `high-scores.md`, `results-name-entry.md`, `flight-school.md`, `hud.md`, `credits.md`.
`design/`: `accessibility-requirements.md`, `registry/entities.yaml`.
`docs/`: `architecture/adr-0001` … `adr-0009`, `consistency-report-2026-11-03-ux.md`.
`production/`: `stage.txt` (Concept → **Pre-Production**), `ux-reports/_art-director-decisions.md`, this report.
