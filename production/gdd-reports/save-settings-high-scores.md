## 1. File written
`D:\Projects\GodotProjects\Morutjan\morut-jan\design\gdd\save-settings-high-scores.md`. I wrote it in one pass rather than section by section, because auto-approve was on. It follows the brief's exact headings and has 49 acceptance criteria, 6 formulas, 12 open questions and a UX flag.

The design in short:
- **Files:** two JSON files, `user://scores.json` and `user://settings.json`. They share an envelope (`format`, `version`, `check`, `payload`) and each has a `.bak` backup and a `.corrupt` set-aside copy.
- **Code shape:** a node-free `SaveStore` with an injected file backend, so unit tests run against an in-memory backend and never touch the real disk.
- **Boards, records, settings:** high-score boards, personal records, and a typed settings schema.
- **Write protocol:** write `.tmp`, read it back, rotate main to `.bak`, rename `.tmp` to main. Writes happen only at Results confirm, settings close, window close while dirty, and confirmed reset/clear actions. Nothing is written during a stage, tally or while a player is selecting.

## 2. Key decisions
- **Board split:**
  - Solo gets one board per plane (e.g. `2s/solo/lancer`).
  - Co-op gets one board per player count (`2s/coop/2` to `4`), with planes mixed.
  - Run length (stage count) is part of the board id, so 2-stage scores never mix with later 4-stage scores.
  - Each board holds 10 entries. Ties keep the older entry on top.
- **Ranked runs:**
  - Only ENDING and GAME_OVER runs reach Save.
  - Score must be at least 1.
  - Continues are allowed and ranked, using the post-continue score. The wiped `pre_continue_score_total` never counts.
  - Entries carry "C" (continued) and "1CC" badges.
  - Drop-in players count toward the team, which then has no 1CC badge. This closes Session Open Question 6 and Scoring Open Question 7.
- **Initials:** 3 characters from A-Z, 0-9, `-` and `.`, Latin only, and optional.
  - A 3-slot gamepad wheel cannot offer Bengali conjuncts.
  - Skipping or a 30 s timeout saves the slot's last-used initials, or `AAA` on first use.
  - Each co-op player enters their own.
  - Score is stored as the true int64 value, capped at 2^53-1 (JSON float precision). The 9-digit display clamp stays a UI rule.
- **Personal records:** best chain per plane per boss, and 1CC counts per plane and stage count. These update on submit, including score-0 runs. ABANDONED runs update nothing.
- **Session flow:** Session calls `preview_rank(record)` when Results opens (read-only). Menus runs name entry. `submit_run(record, initials)` runs on Results confirm, before the clear. Save recomputes `one_credit_clear` from the record fields instead of trusting it.
- **Settings:**
  - Typed keys with defaults, ranges and a named owner each.
  - Volumes are 0-10 integer steps; `language` is `auto`, `en` or `bn`.
  - Input bindings store only overrides against `InputSetup` defaults. Keyboard overrides apply to P1 only. Pad overrides (`fire`, `ability`, `bomb`) apply to all four players.
  - `access.*` is a namespace registered by Accessibility (28). Unknown keys survive a round trip.
  - Changes apply in memory at once and are written only on commit.
- **Checksum and versioning:**
  - The check is `sha256(SALT + canonical sorted-key JSON)`. It is explicitly not security, and a mismatch is treated as corruption, never as cheating.
  - Payloads contain no floats. Whole floats are normalised to int on load, because Godot's JSON parser returns every number as a float.
  - Migrations are pure functions run in order.
  - A file newer than the build is read-only: defaults load in memory and the file is left untouched.
- **Web:** the same API on every platform. The IndexedDB flush timing, rename atomicity and private-browsing behaviour in 4.7 are marked unverified. AC-46 is the manual test that settles them. If storage is blocked, the game runs memory-only with a one-time "progress will not be saved" notice. Fullscreen is not applied at boot on Web.
- **Replays:** deferred, kept as an Open Question with a size estimate of about 72 KB raw per slot for a 20-minute run. It needs Session to keep a `run_seed`.

## 3. Amendments
1. `design/gdd/game-events-and-session.md`:
   - Rule 2: replace "calls Save and high scores (26) directly with the run record before the clear" with "calls `SaveStore.preview_rank(record)` when Results opens (read-only) and `SaveStore.submit_run(record, initials)` on Results confirm, both before the clear. Not called for ABANDONED."
   - Rule 4: add `joined_at_run_start` to the slot fields. F7 uses it but Rule 4 doesn't store it.
   - Add a Run record subsection with the `RunRecord` table from this GDD. The new fields are `stage_count`, `stage_reached`, `final_state` and `joined_at_run_start`, with plane as a string id.
   - Open Question 6: close it ("Closed 2026-11-03: continued and drop-in runs ranked with badges; see Save (26) Rules 6-7").
   - AC-06: add that name entry happens between `preview_rank` and `submit_run`, and that initials default to `profile.last_initials` on timeout.
2. `design/gdd/scoring.md`: close Open Question 7 with the same decision. Change the Save (26) interactions row (line 105) to "Final scores via Session; Save stores the true int64, display clamp unaffected".
3. `design/gdd/collision-damage-lives.md`, line 379: change "Setting owned by Save/settings (26)" to "Key `access.reduce_flashing` (bool, default false), registered by Accessibility (28), stored by Save (26)."
4. `design/gdd/game-concept.md` §12, Target row: "high-score tables (solo + co-op)" becomes "high-score tables (solo per plane, co-op per player count)".
5. `design/gdd/systems-index.md`:
   - Row 26 status: `**Designed** (pending review) — [GDD](save-settings-high-scores.md)`.
   - Row 26 "Depends on" stays `1` (hard). Soft providers are 2, 4, 24, 27, 28. Add the note "Settings schema keys come from 2, 4, 24, 27, 28".
   - Row 28 depends on `20, 22, 26`. Row 22 depends on `2, 26`. Row 21 depends on `7, 8, 26` (soft).
   - Progress tracker: GDDs written 7 becomes 8.
   - The row 26 layer is F and its tier is Vertical Slice, but Session calls Save from Results. Rule 31 makes that call a no-op when Save is absent, so MVP is unaffected.
6. Future GDDs (Input 2, Menus 22, Tally 21, Localization 27, Accessibility 28, Display scaler 4, Audio 24, Leaderboards 32) must each list Save (26) with the interface in this GDD's Interactions table.
   - Input must apply `input.bindings` and `input.pad_deadzone_pct` in `InputSetup` after the defaults are registered.

## 4. Registry candidates
```yaml
  - name: high_score_board_size
    value: 10
    unit: entries per board
    range: "5-20"
    source: design/gdd/save-settings-high-scores.md (F1)
    referenced_by: [save-settings-high-scores]
  - name: initials_length
    value: 3
    unit: characters (A-Z, 0-9, '-', '.')
    range: "2-5"
    source: design/gdd/save-settings-high-scores.md (Rule 12)
    referenced_by: [save-settings-high-scores]
  - name: score_store_max
    value: 9007199254740991
    unit: points (2^53 - 1; largest score Save stores exactly through JSON)
    source: design/gdd/save-settings-high-scores.md (F2)
    referenced_by: [save-settings-high-scores, scoring]
  - name: save_file_version
    value: 1
    unit: int (scores.json and settings.json envelope version)
    source: design/gdd/save-settings-high-scores.md (Rule 23)
    referenced_by: [save-settings-high-scores]
  - name: setting_access_reduce_flashing
    value: "access.reduce_flashing (bool, default false)"
    unit: setting key
    note: "Registered by Accessibility (28), stored by Save (26)"
    source: design/gdd/save-settings-high-scores.md (Rule 16)
    referenced_by: [save-settings-high-scores, collision-damage-lives]
formulas:
  - name: board_id
    expression: '"{stage_count}s/solo/{plane}" if played == 1 else "{stage_count}s/coop/{played}"'
    variables: [stage_count, played, plane]
    output: string key; 5 boards in MVP, 7 in Target (12 across both)
    source: design/gdd/save-settings-high-scores.md (F3)
    referenced_by: [save-settings-high-scores]
  - name: board_placement
    expression: "rank_index = count(entries with score >= new_score); ranked = new_score >= min_ranked_score AND rank_index < board_size"
    variables: [new_score, entries, board_size, min_ranked_score]
    output: "rank 1..board_size or not ranked"
    source: design/gdd/save-settings-high-scores.md (F1)
    referenced_by: [save-settings-high-scores]
```
Existing entries whose `referenced_by` should gain `save-settings-high-scores`: `one_credit_clear`, `score_display_digits`, `chain_cap`, `starting_lives`.

## 5. Conflicts
No conflict with locked registry values.
- The session GDD's Rule 4 slot fields omit `joined_at_run_start`, which F7 needs. It is fixed by amendment 1.
- Session AC-06 says Save is called when Results is "confirmed". The name-entry step needs the read-only `preview_rank` before that, so the call becomes two steps (amendment 1).

## 6. Open risks
- **Web persistence:** whether the browser reliably saves `user://` in 4.7 is unverified. Tab-close timing, rename atomicity and private mode are the risks. A silent failure cannot be detected at runtime, so AC-46 on REF-WEB must pass before shipping boards.
- **Results-screen crash:** the score is only saved at Results confirm, so closing the tab on Results loses it (Open Question 4 holds the alternative).
- **Abandoned runs:** they update no records, so a player who quits mid-run loses a new best chain. This is deliberate, to keep the no-banking rule simple.
- **Provisional contracts:** the settings keys and ranges for Input, Display, Audio, Localization and Accessibility are provisional until their GDDs exist. The `RunRecord` contract needs the Session amendments.
- **Empty co-op boards:** 4P boards may rarely fill (Open Question 7).
- **Corruption false alarm:** a hand-edited file is treated as corruption and loses entries back to the last backup. That is acceptable for a local game but could surprise modders.
