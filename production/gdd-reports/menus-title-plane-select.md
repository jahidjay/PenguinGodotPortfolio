## 1. File written
`D:\Projects\GodotProjects\Morutjan\morut-jan\design\gdd\menus-title-plane-select.md`. It follows the brief's headings in order. It has 10 formulas, 62 acceptance criteria, 15 open questions, ASCII mock-ups of 7 screens at 360x640, and the UX Flag line. I wrote it in one pass because auto-approve was on.

In short: Menus is the front door and every screen outside the fight. These are node-free `RefCounted` models ticked at 60 Hz (`MenuModel`, `LobbyModel`, `PauseModel`, `NameEntryModel`, `ResultsFlow`, `HoldConfirm`) under thin views. Screens are defined in `data/menus/*.tres`. The doc covers:
- boot and the Web gate
- Title
- Lobby / plane select
- the mid-run drop-in pick
- Pause and the disconnect overlay
- Results
- name entry
- boards and Records
- Settings
- Credits

Not written: Stage-end tally (21) has no GDD, so Menus owns Results only. The continue prompt and the pick-plate geometry are left to HUD (20), as Session says.

## 2. Key decisions (all auto-approved; change any of them later)
- **No first-run language screen.** The title is always bilingual and has a language chip. The Drone button or a click toggles it, and it commits at once (Localization Rule 3 already says this fixes a wrong OS guess in one press).
- **Title is shared.** Any device can navigate (Input Rule 6). Confirm on START GAME binds that device as slot 0. A pointer opens an open lobby, because a mouse cannot fly.
- **Web gate only on Web.** The first click, key or touch is consumed. It unlocks audio and applies a saved fullscreen. Whether a gamepad press alone unlocks audio is marked unverified (AC-62).
- **Lobby layout is fixed.**
  - Four 90 px slot columns are always visible, even solo, so co-op is discoverable.
  - Plane cards sit above them: `card_w` = 160 at 2 planes.
  - Each slot has its own cursor. Duplicate planes are allowed.
  - Rim light is split among the hovering slots' colours.
  - The READY stamp is text plus glyph plus ring pattern, never colour alone.
- **Plane cards convey identity** with a tagline, a playstyle tag and three trait rows (Fire / Hold / Drone) with button glyphs.
  - Lancer: "Burst and hold".
  - Leech: "Latch and sustain".
  - Text keys are `plane.<id>.*`.
- **Commit rule.** The run starts when all joined slots are Locked and `start_delay_ticks` (45) have passed. Any change resets the counter.
- **Stall protection.** A Choosing slot with no input for 30 s is released if someone else is Locked. The whole lobby returns to Title after 60 s of no input. There is no forced lock-in.
- **Drop-in pick.** It is drawn in the empty slot's HUD column inside the strip, never over the field. It auto-cancels after 900 ticks.
- **Pause.** Items are Resume, Settings, Quit to title. There is no Restart in MVP.
  - Quit is a 60-tick hold. It shows "Score will not be saved" and calls `abandon_run()` (ABANDONED, Save not called).
  - Only the pausing slot owns the menu.
  - A 45-tick, 3-pip resume beat keeps the tree paused before play resumes (closes Input Open Question 4).
- **Disconnect overlay.** Rows per Waiting slot: Reconnect / Use keyboard / Drop P{n} (hold) / Wait.
- **Results.**
  - Menus owns it.
  - Confirm is locked for 30 ticks.
  - Layout: per-slot rows, team block, "C" and "1CC" tiles, and "Before continues".
  - Order: Results → name entry (ranked runs only) → Board (new entry highlighted) → Title or **Play again**.
- **Name entry.**
  - Simultaneous per-slot wheels over 38 characters.
  - Shared 30 s timer; on timeout the player's current text or last initials are kept.
  - A single keyboard slot may type.
  - A slot with no device is auto-filled.
- **High scores.** Tabs are Solo (per plane), Co-op (2P/3P/4P) and Records. A co-op row shows the lead player's initials plus "+N", with a detail strip on focus. There is no combined co-op tab.
- **Settings.**
  - Sections: Audio, Display, Language, Controls, and an Accessibility shell (holding `access.reduce_flashing` at MVP).
  - Changes apply live and commit on close (never discarded).
  - Destructive actions use hold-to-confirm. An accessibility alternative `confirm_style = double_tap` is proposed.
- **Transitions** are a stepped 4-step Char wipe over 12 frames. No white and no flashes.
- **Attract mode** at MVP only cycles era backdrops after 30 s idle. A recorded-input demo is recommended later (Open Question 1).

## 3. Amendments (the main session applies these)
1. **`design/gdd/systems-index.md`**
   - Row 22 status: `**Designed** (pending review) — [GDD](menus-title-plane-select.md)`.
   - Row 22 "Depends on": `2, 26` stays; add soft `1, 4, 11, 18, 27`.
   - Progress tracker: GDDs written +1 (add "Menus, title and plane select").
   - Dependency notes: HUD (20), Tally (21), Accessibility (28) and Touch (31) must list Menus (22).
2. **`design/gdd/game-events-and-session.md`**
   - Rule 1 and the Run-flow table: replace "A run starts when the first player confirms a plane on plane select" with "A run starts when the Lobby commits (every joined slot Locked, `start_delay_ticks` elapsed). Menus calls `start_run(selections)`; each committed slot has `joined_at_run_start = true`."
   - Add `abandon_run()` for quit-to-title (ABANDONED).
   - Rule 7: the drop-in pick auto-cancels after `dropin_pick_ticks` (900) and the slot returns to its previous state.
   - Note that pre-run lobby slots live in Menus' `LobbyModel`; Selecting stays the mid-run drop-in state.
   - UI Requirements: Results and Pause owned by Menus (22), Tally by 21, continue prompt and pick plate geometry by HUD (20).
3. **`design/gdd/input-and-player-mapping.md`**
   - Rules 3 and 6: Confirm (Fire or Start) on the Title START GAME item is a join request, bound to slot 0.
   - Add `bind_device(device, slot)` for "Play again".
   - Add a provisional `typed_char(slot, char)` event for name entry.
   - Open Question 4 (resume beat): closed by Menus Rule 30 (45 ticks, no invulnerability).
   - Dependencies row Menus (22): now has a GDD.
4. **`design/gdd/save-settings-high-scores.md`**
   - Rule 16 display keys: replace `display.window_mode`, `display.integer_scale` and `display.bezel` (auto/off) with `display.scale_mode` (`auto`, `pixel_perfect`, `fill`), `display.window_mode` (`windowed`, `fullscreen`), `display.tate_mode` (`off`, `cw`, `ccw`), `display.bezel_style` (`art`, `plain`), and `display.window_size` (two ints, windowed only).
   - Add `profile.last_plane` string[4] (default `["","","",""]`, owned by Menus, written at commit).
   - Add `access.confirm_style` (`hold` / `double_tap`, default `hold`, registered by Accessibility 28).
   - Rule 20 triggers: add "Title language chip toggle" (Menus).
   - V/A "Name entry": change "repeat after 15 ticks every 6" to "Input nav repeat (18 / 6)".
   - Open Question 4: kept at confirm. Open Question 7: no combined co-op tab at MVP. Open Question 9: raw id in Latin plus a generic icon.
   - Dependencies: Menus (22) now has a GDD.
5. **`design/gdd/localization.md`**
   - Open Question 7 (Latin-only initials): closed (Save Rule 12, Menus Rule 36).
   - Add the Menus key families to `ui_menu.csv`: `menu.*` and `plane.<id>.*`, from the UI Requirements table.
   - The `বাংলা` / `English` chip labels are a non-translated lint exception.
   - Dependencies: Menus (22) now has a GDD.
6. **`design/gdd/display-scaler-and-bezel.md`**: UI Requirements note "Display settings screen and TATE confirm are defined by Menus (22) Rules 43-45"; persisted settings list matches the amended Save schema.
7. **`design/gdd/coop-and-team-chain.md`** Open Question 9: close with "Any bound slot pauses with Start/Back; the pausing slot owns the menu, others are ignored (Input Rule 25, Menus Rules 27-28)."
8. **`design/gdd/plane-kits-lancer-leech.md`**: data requirement for the plane-card text keys `plane.<id>.name/tag/style/fire/hold/drone`; Dependencies: Menus (22) has a GDD.
9. **`design/art/art-bible.md`**
   - §7.8: add "Pause panel is a compact plate over the frozen field. Lobby is four fixed 90 px slot columns under the plane cards."
   - §7.2 "lower third never used for UI": add the exception "Pause and Disconnect panels while the game is stopped".
   - §6.8: note that Menus draw on a CanvasLayer above layer 11.
10. **ADR**: menu host under the Display SubViewport; menu models ticked at 60 Hz with `process_mode = ALWAYS`; the `start_run` pre-load handshake.

## 4. Registry candidates
New constants (all `source: design/gdd/menus-title-plane-select.md`, `referenced_by: [menus-title-plane-select]`):
```yaml
  - name: start_delay_ticks
    value: 45
    unit: ticks (Lobby commit delay after every joined slot is Locked)
    range: "0-120"
    source: design/gdd/menus-title-plane-select.md (F2)
    referenced_by: [menus-title-plane-select]
  - name: afk_release_ticks
    value: 1800
    unit: ticks (30 s; Choosing slot released if another slot is Locked)
    range: "900-3600"
    source: design/gdd/menus-title-plane-select.md (F3)
    referenced_by: [menus-title-plane-select]
  - name: lobby_idle_ticks
    value: 3600
    unit: ticks (60 s no input from any joined slot -> Title)
    range: "1800-7200"
    source: design/gdd/menus-title-plane-select.md (F3)
    referenced_by: [menus-title-plane-select]
  - name: hold_confirm_ticks
    value: 60
    unit: ticks (hold-to-confirm for destructive actions)
    range: "30-120"
    source: design/gdd/menus-title-plane-select.md (F6)
    referenced_by: [menus-title-plane-select]
  - name: resume_beat_ticks
    value: 45
    unit: ticks (3-pip beat before play resumes; tree paused)
    range: "0-90"
    source: design/gdd/menus-title-plane-select.md (F9)
    referenced_by: [menus-title-plane-select, input-and-player-mapping]
  - name: dropin_pick_ticks
    value: 900
    unit: ticks (mid-run plane pick auto-cancels)
    range: "600-1800"
    source: design/gdd/menus-title-plane-select.md (Rule 26)
    referenced_by: [menus-title-plane-select, game-events-and-session]
  - name: results_input_lock_ticks
    value: 30
    unit: ticks (Results ignores Confirm)
    range: "15-60"
    source: design/gdd/menus-title-plane-select.md (Rule 34)
    referenced_by: [menus-title-plane-select]
  - name: name_entry_seconds
    value: 30
    unit: seconds (shared name-entry timer; 1800 ticks)
    range: "15-60"
    source: design/gdd/save-settings-high-scores.md (Tuning Knobs)
    referenced_by: [save-settings-high-scores, menus-title-plane-select]
```
New formulas:
```yaml
  - name: lobby_ready_gate
    expression: "ready = joined >= 1 AND locked == joined; ready_ticks = ready ? prev + 1 : 0; commit when ready_ticks >= start_delay_ticks"
    variables: [joined, locked, ready_ticks, start_delay_ticks]
    output: "one commit per Lobby; 45 ticks after the last lock"
    source: design/gdd/menus-title-plane-select.md (F2)
    referenced_by: [menus-title-plane-select, game-events-and-session]
  - name: name_wheel_step
    expression: 'alphabet "A-Z0-9-." (38); idx'' = (idx + dir) mod 38; steps(a,b) = min((b-a) mod 38, (a-b) mod 38)'
    variables: [idx, dir, a, b]
    output: "steps 0-19; 19 steps by holding = 120 ticks"
    source: design/gdd/menus-title-plane-select.md (F4)
    referenced_by: [menus-title-plane-select, save-settings-high-scores]
  - name: hold_confirm_progress
    expression: "fires = held_ticks >= hold_confirm_ticks; segments = (4 * min(held_ticks, hold_confirm_ticks)) div hold_confirm_ticks"
    variables: [held_ticks, hold_confirm_ticks]
    output: "segments 0-4"
    source: design/gdd/menus-title-plane-select.md (F6)
    referenced_by: [menus-title-plane-select]
  - name: plane_card_width
    expression: "card_w = (360 - 2*card_margin - (P-1)*card_gap) div P"
    variables: [P, card_margin, card_gap]
    output: "160 / 104 / 76 px for 2 / 3 / 4 planes"
    source: design/gdd/menus-title-plane-select.md (F7)
    referenced_by: [menus-title-plane-select]
```
Existing entries whose `referenced_by` should gain `menus-title-plane-select`:
- Constants: `initials_length`, `high_score_board_size`, `canvas_size`, `max_players`, `tate_confirm_seconds`, `supported_languages`, `score_display_digits`, `bn_size_s`, `bn_width_reserve_pct`.
- Formulas: `board_id`, `board_placement`, `format_int`, `digit_cell_width`, `one_credit_clear`, `press_edge`.
- Fix on `window_to_canvas`: its `referenced_by` lists `menus`. Replace `menus` with `menus-title-plane-select`.

## 5. Conflicts with locked values or other GDDs
No registry value is contradicted. Doc conflicts, all resolved in the Amendments:
- **Session Rule 1 / Run-flow table** says a run starts when "the first player confirms a plane". A co-op lobby needs everyone locked first. Menus commits once for all (amendment 2).
- **Save schema vs Display settings.** Save lists `display.window_mode`, `display.integer_scale` (bool) and `display.bezel` (`auto`/`off`). Display defines `display_scale_mode` (3-way), `window_mode`, `tate_mode`, `bezel_style` (`art`/`plain`) and `window_size`. These cannot be represented in Save's current keys (amendment 4).
- **Name-entry hold repeat.** Save V/A says 15 ticks then 6. Input F4 says 18 then 6. Menus uses Input's nav events (amendment 4).
- **Input Rule 3** only lets a Start press create a binding. Title uses Confirm on START GAME, and "Play again" needs `bind_device` (amendment 3).
- **Art bible §7.2 / §2.** "Lower third never used for UI" and "nothing covers enemy bullets" conflict with a pause panel over the frozen field. Flagged as Open Question 2 and amendment 9, not assumed.
- **Registry slug mismatch** on `window_to_canvas` (`menus` vs the real slug).

## 6. Open risks
- **Web audio unlock by a gamepad press** is unverified; AC-62 is the test.
- **Pause panel over frozen bullets** needs an art-director ruling (Open Question 2).
- **HUD drop-in plate geometry at 1P** is unresolved. The 48 px, one-column strip has no spare empty column (Open Question 3). This is the riskiest cross-system contract.
- **Stage-end tally (21) has no GDD.** The Results/Tally boundary is assumed (Menus owns Results only).
- **Bengali strings are drafts.** Conjunct and font behaviour at 17 px (Localization spike S1) can force `bn_size_s` up, which changes plate sizes.
- **`LobbyModel` vs Session ownership** before a run exists, and the `start_run` pre-load handshake, need an ADR (Open Question 12).
- **Row width budget** (F10) assumes a 9 px Latin advance, a proposal until the font spike.
- **Scope.** The Controls remap list and the Accessibility shell are in the MVP screen list. If the MVP is cut, the remap list can slip to Vertical Slice (Accessibility 28) without touching other screens.
