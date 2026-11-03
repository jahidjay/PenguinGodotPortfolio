# Save, Settings and High Scores

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (systems-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (UX consistency check, wave 5)**: the `tutorial.drills_done` schema row now points at Tutorial's **per-plane** `school_required_mask` instead of a fixed 1023; the Save-failure notice follows the amended Alarm Red rule (never a text fill).
> **Implements Pillar**: Every Hit Counts (records of chains and scores are the long-term goal), Four Planes, Four Games (one board per plane in solo)
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: a ranked run must also place inside the top `board_size` and `preview_rank` may answer `not placed` (Rule 5, Run submit, AC-03a); lead player of a co-op entry defined (Rule 11); leaving the Flight School list to Title with `tutorial.*` dirty is a commit trigger (Rule 20); `reset_settings()` keep-list extended to `language`, `access.first_run_prompt_done`, `profile.*` and `touch.hints_seen` (Rule 30, AC-26).

## Overview

**The data layer:** Save, settings and high scores owns everything MorutJan keeps **between sessions**. It has three parts.

1. **High-score boards.** When a run ends in an ending or a game over, Session hands Save one immutable **run record**. Save decides whether the run is ranked, finds its place on the right board, stores the entry (score, initials, plane, stage reached, 1CC flag) and keeps the top 10 per board.
2. **Personal records.** Best chain per plane per boss, and 1CC counts per plane. These feed the "new best" callouts on the tally.
3. **Settings.** Audio volumes, display mode, language, input bindings and accessibility options, stored as typed keys with defaults, ranges and one owner system each.

Data lives in two JSON files under `user://` (`scores.json`, `settings.json`). Each has a version number, a light checksum and a backup copy. Writes happen only at calm moments (Results confirm, settings close), never during a stage tick. A node-free `RefCounted` store does the logic and talks to files through a small backend interface, so it is unit-testable with no disk (ADR-0001).

**The player impact:** players never think about this system until it fails. They feel it when the score they fought for is on the board with their initials, when "NEW BEST 187" shows on the tally, and when the game starts in the language, volume and button layout they left it in. A lost score or a reset keybind breaks trust in a game whose whole point is mastery over many sessions. The system's job is to make records feel permanent and safe, and to make quitting mid-run unable to bank a score.

## Player Fantasy

**Anchor moment: my name on the wall.** After the last boss falls, three letters blink on the entry wheel: `K A Z`. The board slides in with your score at rank 2 and a small "1CC" badge beside it. Next week your friend plays 2P on the same machine and beats it, and the board shows both of their tags. The board is a **local arcade cabinet's memory**.

What makes that feeling work:
- **Records are earned, not banked.** Quitting to title never writes a score (Session ABANDONED rule). The board holds only runs that ended on a real ending or a real game over.
- **Four planes, four boards.** Solo scores are ranked per plane, so a Leech player is not buried under Lancer scores (**Four Planes, Four Games**).
- **Honest scores.** A score after a continue starts from zero (Session Rule 6), is marked as a continue, and is never mixed up with a 1CC.
- **The game remembers you.** Language, volumes and bindings come back exactly as set.
- **Nothing is lost silently.** If a file is damaged, the game restores the backup, tells the player, and never wipes scores without a visible reason.

**Anti-fantasy:** a score that vanishes after a crash on the Results screen, a settings reset after an update, a board that only shows the 1CC players, or a name entry that needs a Bengali keyboard on a gamepad.

> `creative-director` not consulted (lean mode, auto-approve).

## Detailed Design

### Core Rules

**Files and ownership**

1. Save keeps **two files**, written independently: `user://scores.json` (boards + records) and `user://settings.json`. A damaged settings file never touches scores and the other way round. Each file also has `<name>.bak` (previous good copy) and may have `<name>.corrupt` (the last damaged file set aside).
2. Both files use one **envelope**: `{ "format": "morutjan.scores" | "morutjan.settings", "version": <int>, "check": "<hex>", "payload": { ... } }`. The payload holds **no floats**: ints, strings, bools, arrays and dictionaries only. All settings that look fractional are stored as integer steps or percent.
3. The logic lives in a node-free `SaveStore` (`RefCounted`) with an injected **file backend** (read text, write text, rename, delete, exists). The game uses a `user://` backend; tests use an in-memory one. A thin autoload exposes it (→ ADR: autoload name and ownership with Session).

**What is a ranked run**

4. Session calls `submit_run(record, initials)` only for runs that ended `ENDING` or `GAME_OVER`. `ABANDONED` runs never reach Save (Session Rule 2). Save also rejects an ABANDONED record if one arrives anyway. *(Wave 4, 2026-11-03, Online leaderboards (32):)* a record with `assisted` or `debug_tainted` set is never ranked (Rule 32) and never queued for upload.
5. A run is **ranked** if its **board score** is at least `min_ranked_score` (1) **and** it places within the top `board_size` (10) of its board (F1: `rank_index < board_size`). Board score is the slot score (solo) or the sum of all played slots' scores (co-op, Session F6 `team_score`). `preview_rank(record)` therefore returns either a **rank** (1-`board_size`) or **`not placed`**; a not-placed run asks for **no initials** and stores nothing. *(Amended 2026-11-03, UX amendments wave 5 batch 2: the placement test was missing here and contradicted F1, AC-03 and [Online leaderboards (32)](online-leaderboards-boss-rush.md) Rule 1; [Menus (22)](menus-title-plane-select.md) Rules 35 and 40 read this rule for the `Not in top {n}` case.)* A run whose record has `debug_tainted = true` (set by debug stage select or wave skip, [Wave director (16)](wave-and-stage-director.md)) is **never ranked** and updates no personal records (Rule 13 does not apply to it). *(Amended 2026-11-03, provisional field in `RunRecord`.)*
6. **Continues are allowed and ranked.** The wiped pre-continue score is never counted (Session F6: `pre_continue_score_total` is display only). The entry stores `continues_total` and shows a "C" mark. A **1CC** run (`one_credit_clear`, Session F7, all played slots) shows a "1CC" badge. Boards are not split by continued/not-continued. The UI can filter on the badge (→ Menus).
7. **Drop-in players count.** A co-op run where a player dropped in is ranked on the board of the final played player count; that player's `is_1cc` is false, so the team entry has no 1CC badge (Session F7).
8. A run is ranked on **one board only**.

**Boards**

9. A **board** is the top `board_size` (10) entries for one **board id** (F3): run length (stage count) + mode + plane (solo) or player count (co-op).
   - **Solo** (exactly 1 played slot): one board per plane, e.g. `2s/solo/lancer`.
   - **Co-op** (2–4 played slots): one board per player count, e.g. `2s/coop/3`. Planes are mixed on these boards.
   - **Run length** (`stage_count`: 2 in MVP, 4 in Target) is part of the id, so MVP-length scores never compete with 4-stage scores after the game grows.
   - **Touch** *(wave 4, 2026-11-03, [Touch controls (31)](touch-controls.md) TF8)*: a solo run flown with TOUCH bound gets the `/touch` suffix, e.g. `2s/solo/lancer/touch` (one extra solo board per plane; touch is solo only, so co-op ids never carry it).
   - **Boss Rush / Single Boss** *(wave 4, 2026-11-03, [Online leaderboards, boss rush (32)](online-leaderboards-boss-rush.md))*: RUSH ids `rush{boss_count}/solo/{plane}` and `rush{boss_count}/coop/{played}`; BOSS ids `boss/{boss_id}/{plane}` (1P only). MAIN ids are unchanged, so the mode prefix is backward compatible.
10. Entries are sorted by score, highest first. **Ties:** the older entry stays above (F1). A full board's lowest entry is dropped when a higher score arrives. An equal score does not displace it.
11. **Entry** fields:

| Field | Type | Description |
|---|---|---|
| `id` | int | Monotonic per file (`next_entry_id`), never reused |
| `score` | int | Board score (F2), clamped to `score_store_max` |
| `stage_reached` | int | 1–`stage_count` (highest stage index + 1 at run end) |
| `cleared` | bool | `run_ended_by == ENDING` |
| `one_cc` | bool | Team 1CC (all played slots `one_credit_clear`) |
| `continues_total` | int | Σ `continues_used` over played slots |
| `run_ms` | int | `round(run_time × 1000)` |
| `date_utc` | int | Unix seconds when the entry was committed (wall clock; never read by gameplay) |
| `version` | string | Game version string at commit |
| `players` | array | 1–4 of `{ initials, plane, score, max_chain, critical_breaks, continues_used, one_cc }` |

   `players[].max_chain` is `slot_max_chain` (Session F6). Co-op entries keep per-player rows **in slot order**. The **lead player** of a co-op entry, for any display that names one player (board row initials, Results rank strip), is the row with the **highest `players[].score`**; on a tie the **lower slot** wins. *(Added 2026-11-03, UX amendments wave 5 batch 2; same definition as [Menus (22)](menus-title-plane-select.md) Rule 40 and [Co-op (9)](coop-and-team-chain.md) Open Question 8.)*
   *Wave 4 (2026-11-03, Online leaderboards (32)):* optional `online_status` (string; absent offline) and `replay_ref` (string; id into the online upload queue) — written only when `online.enabled`.

**Initials**

12. Initials are **3 characters** (`initials_length`) from `A–Z`, `0–9`, `-`, `.`. Each ranked player enters their own (co-op: each of the team's players). **Optional:** skipping, timing out or confirming without change saves the **last used initials for that slot** (`profile.last_initials`), or `AAA` on first use.
   - **Why Latin only:** a gamepad wheel needs a short fixed alphabet. Bengali has hundreds of glyph combinations with conjuncts, which a 3-slot wheel cannot offer, and there is no shipped Bengali on-screen keyboard. Latin initials also render in any font and keep the board bilingual by default (art bible §7.5). Keyboard typing is mapped to the same set.
   - Initials are normalised to upper case. Any other character is rejected at input and, if found in a loaded file, replaced with `-` (Edge Cases).
   - No profanity filter. Boards are local. Online (32) must add one.

**Personal records**

13. After a ranked **or unranked** (score 0) run is submitted, Save updates records for every played slot:
   - `best_chain[plane][boss_index] = max(old, new)` for each boss in the slot's `max_chain_per_boss` (F4). **`boss_index` = `stage_index`** in MVP (one boss per stage), so a slot that dropped in on stage 2 writes its first boss chain to index 1, not 0. *(Amended 2026-11-03, [Stage tally (21)](stage-end-tally.md).)*
   - `one_cc_count[plane][stage_count] += 1` if the slot's `one_credit_clear` is true.
   - *Wave 4 (2026-11-03, Online leaderboards (32)):* `endings_count += 1` when `run_ended_by == ENDING` (unlocks Boss Rush), and `bosses_beaten` (set of boss ids) gains each boss with a KILLED or CRITICAL_BREAK `boss_defeated` (unlocks it in Single Boss; TIMEOUT does not).
   Records are not updated for ABANDONED runs (they never reach Save). This is the price of the "no banking" rule.
14. The Tally reads `get_best_chain(plane, boss_index)` **before** the run is committed, so a boss chain higher than the stored one can show "NEW BEST". Records update only at Results confirm.

**Settings**

15. Settings are **typed keys** from a schema (`data/settings_schema.tres`): key, type, default, range or allowed set, owner system. A key not in the schema is **kept untouched** in the file on round-trip (so a newer build's keys survive an older build) but is never applied.
16. MVP schema (every owner now has a GDD; `access.*` keys follow the Accessibility (28) registry, `data/accessibility/access_options.tres` — *updated 2026-11-03, wave 3b*):

| Key | Type | Default | Range / set | Owner |
|---|---|---|---|---|
| `audio.master` | int step | 10 | 0–10 | Audio (24) |
| `audio.music` | int step | 7 | 0–10 | Audio (24) |
| `audio.sfx` | int step | 8 | 0–10 | Audio (24); the UI bus follows this slider (Audio Rule 1) |
| `display.scale_mode` | string | `"auto"` | `"auto"`, `"pixel_perfect"`, `"fill"` | Display scaler (4) *(keys replaced 2026-11-03 to match display-scaler-and-bezel.md and Menus (22); `display.integer_scale` and `display.bezel` removed)* |
| `display.window_mode` | string | `"windowed"` (Display scaler picks fullscreen on mobile) | `"windowed"`, `"fullscreen"` | Display scaler (4) |
| `display.tate_mode` | string | `"off"` | `"off"`, `"cw"`, `"ccw"` | Display scaler (4) |
| `display.bezel_style` | string | `"art"` | `"art"`, `"plain"` | Display scaler (4) / Accessibility (28) |
| `display.window_size` | int[2] | unset (first-run size) | windowed only, ≥ 360×640 | Display scaler (4) |
| `language` | string | `"auto"` | `"auto"`, `"en"`, `"bn"` | Localization (27) |
| `input.dz_preset` | string | `"default"` | `"low"`, `"default"`, `"high"` | Input (2). Values live in Input's `data/input/input_rules.tres` (default `dz_enter` 0.30 / `dz_exit` 0.20; low 0.20/0.12; high 0.40/0.28). Save stores only the player's choice. *(amended 2026-11-03, input-and-player-mapping.md)* |
| `input.fire_toggle` | bool | false | — | Input (2) / Accessibility (28) |
| `input.tap_assist` | bool | false | — | Input (2) / Accessibility (28) |
| `input.bindings` | dictionary | `{}` | Rule 18 | Input (2) |
| `access.*` | namespace | — | each key registered by Accessibility (28) | Accessibility (28) |
| `access.reduce_flashing` | bool | false | — | Accessibility (28); read by Collision V2, VFX (25), Player plane (5), Era shift (19) |
| `access.reduce_pulsing` | bool | false | — | Accessibility (28); read by VFX (25), HUD (20) |
| `access.reduce_motion` | bool | false | — | Accessibility (28); read by Parallax (23) `set_scroll_scale`, VFX (25) |
| `access.effects_level` | enum | `FULL` | `FULL`, `REDUCED`, `MINIMAL` | Accessibility (28); read by VFX (25) |
| `access.background` | enum | `FULL` | `FULL`, `DIMMED`, `PLAIN` | Accessibility (28); read by Parallax (23) |
| `access.hitbox_ring_opacity` | int | 100 | 40, 60, 80, 100 | Accessibility (28); read by Player plane (5) |
| `access.hitbox_ring_size` | enum | `NORMAL` | `NORMAL`, `LARGE` | Accessibility (28); read by Player plane (5) |
| `access.ally_shot_dim` | int | 0 | 0, 25, 50 | Accessibility (28); read by Bullet manager (3) |
| `access.player_palette` | enum | `DEFAULT` | `DEFAULT`, `LUMA_SPREAD` | Accessibility (28); read by Player plane (5), HUD (20) |
| `access.hud_contrast` | enum | `STANDARD` | `STANDARD`, `HIGH` | Accessibility (28); read by HUD (20) |
| `access.chain_bar_near_plane` | bool | false | — | Accessibility (28); read by HUD (20) |
| `access.text_size` | int | 0 | 0–3 | Accessibility (28); read by Localization (27), Menus (22) |
| `access.confirm_style` | enum | `HOLD` | `HOLD`, `DOUBLE_TAP` | Accessibility (28); read by Menus (22) |
| `access.confirm_hold` | enum | `NORMAL` | `SHORT`, `NORMAL`, `LONG` | Accessibility (28); read by Menus (22) |
| `access.nav_repeat` | enum | `NORMAL` | `FAST`, `NORMAL`, `SLOW` | Accessibility (28); read by Input (2) |
| `access.untimed_menus` | bool | false | — | Accessibility (28); read by Menus (22) |
| `access.continue_timer` | enum | `STANDARD` | `STANDARD`, `EXTENDED`, `UNTIMED` | Accessibility (28); read by Session (1), HUD (20) |
| `access.tally_auto_advance` | bool | true | — | Accessibility (28); read by Stage-end tally (21) |
| `access.game_speed_pct` | int | 100 | 50–100, step 10 | Accessibility (28); ASSIST (latches `run.assisted`); read by Session (1) |
| `access.auto_bomb` | bool | false | — | Accessibility (28); ASSIST, Target |
| `access.deathbomb_grace` | int | 0 | 0, 3, 6 | Accessibility (28); ASSIST, Target (needs Collision `will_die`) |
| `access.chain_cue_audio` | bool | true | — | Accessibility (28); read by Audio (24); VS — default on (chain-window tick on by default, decision 2026-11-03 wave 4) |
| `access.chain_cue_rumble` | bool | false | — | Accessibility (28); read by Input (2); VS |
| `access.rumble` | enum | `NORMAL` | `OFF`, `LOW`, `NORMAL` | Accessibility (28); Target |
| `access.first_run_prompt_done` | bool | false | — | Accessibility (28); read by Menus (22) |
| `access.era_transition_short` | bool | false | — | Era shift (19), registered by Accessibility (28) |
| `audio.mono` | bool | false | — | Audio (24) / Accessibility (28) |
| `input.move_stick` | enum | `LEFT` | `LEFT`, `RIGHT`, `EITHER` | Input (2) / Accessibility (28) |
| `profile.last_initials` | string[4] | `["AAA","AAA","AAA","AAA"]` | 3 chars each | Save (26) |
| `profile.last_plane` | string[4] | `["","","",""]` | plane id or empty | Menus (22); written at Lobby commit *(added 2026-11-03)* |
| `tutorial.drills_done` | int | 0 | 11-bit mask (bits 0–9 are the candidate required bits, bit 10 team optional). The required set is **per plane**: `school_required_mask` = `1023 & available_mask(plane)` ([Tutorial (30)](tutorial.md) F3, Rule 12, which owns it); this key stays **one profile-wide bitmask** and its width is unchanged | Tutorial (30) *(wave 4; per-plane mask recorded 2026-11-03, UX amendments wave 5 batch 2)* |
| `tutorial.hint_counts` | int | 0 | 2 bits per hint (12 hints) | Tutorial (30) *(wave 4)* |
| `tutorial.school_seen` | bool | false | — | Tutorial (30); read by Menus (22) for the NEW tag *(wave 4)* |
| `tutorial.offered` | bool | false | — | Tutorial (30); one-time Results offer *(wave 4)* |
| `tutorial.hints` | bool | true | — | Tutorial (30); presented by Accessibility (28) *(wave 4)* |
| `touch.scheme` | enum | `DRAG` | `DRAG`, `STICK` | Touch controls (31) *(wave 4)* |
| `touch.autofire` | bool | true | — | Touch controls (31) *(wave 4)* |
| `touch.hand` | enum | `RIGHT` | `RIGHT`, `LEFT` | Touch controls (31) *(wave 4)* |
| `touch.one_hand` | bool | false | — | Touch controls (31) *(wave 4)* |
| `touch.sens` | int index | 1 | 0–3 (0.75 / 1.00 / 1.25 / 1.50) | Touch controls (31) *(wave 4)* |
| `touch.button_scale` | int | 100 | 100, 125, 150 (%) | Touch controls (31) *(wave 4)* |
| `touch.haptics` | enum | `NORMAL` | `OFF`, `LOW`, `NORMAL` | Touch controls (31) *(wave 4)* |
| `touch.hints_seen` | bool | false | — | Touch controls (31) *(wave 4)* |
| `online.enabled` | bool | false | — | Online leaderboards (32) *(wave 4; opt-in, off by default)* |
| `online.consent_version` | int | 0 | ≥ 0 | Online leaderboards (32) *(wave 4)* |
| `online.handle` | string | `""` | 3–12 Latin chars | Online leaderboards (32) *(wave 4)* |
| `online.install_id` | string | `""` | opaque id | Online leaderboards (32) *(wave 4)* |
| `online.auto_upload` | bool | true | — | Online leaderboards (32) *(wave 4)* |
| `online.friend_codes` | string[] | `[]` | ≤ 50 entries | Online leaderboards (32) *(wave 4)* |

17. **`language = "auto"`** resolves at boot to `"bn"` if `OS.get_locale_language()` is `"bn"`, else `"en"` (Localization owns the resolve; Save only stores the setting). *Amended 2026-11-03 (localization.md Rule 3):* on first run Localization writes the resolved `"bn"` or `"en"` back through Save, so `"auto"` lasts only until the first boot completes and later OS locale changes do not flip the game. Localization calls `set_language` when settings load.
18. **Input bindings** store only **overrides** against the defaults owned by Input (2) (`InputBindingsData`, Input Rules 34–39): *(amended 2026-11-03, input-and-player-mapping.md)*
    `input.bindings = { "version": 1, "kb1": { "<action>": [physical_keycode, ...] }, "kb2": { "<action>": [physical_keycode, ...] }, "pad": { "<action>": [button_index, ...] } }`
    - *(added 2026-11-03, Accessibility 28, VS tier)* Optional classes `pad_s0` … `pad_s3` hold per-slot pad overrides; when present they override the shared `pad` map for that slot only. Same rules as `pad`.
    - Classes are `kb1` (keyboard scheme "Main"), `kb2` (keyboard scheme "Left hand") and `pad`. Actions are `fire`, `drone`, `bomb` in every class, plus the movement keys `up`, `down`, `left`, `right` in `kb1` and `kb2`. Each action holds at most 2 controls (primary, alternate). The `pad` map applies to **all four** players' pads (one layout per game). Pad movement, `start` and `back` are not rebindable.
    - A key may not appear in both `kb1` and `kb2`; on load such a clash drops the later override.
    - An override **replaces** that action's event list for that device class. An empty list is invalid (an action can never be left with no binding).
    - A binding clash within one device class is rejected by Menus before it reaches Save. On load, a clash (same key on two actions) drops the later action's override.
    - Reserved keys (pause, menu back) are owned by Input (2) and cannot be assigned.
19. **Apply vs persist:** `set_setting` changes the value in memory at once (so sliders preview live) and marks the file **dirty**. Only `commit_settings()` writes it.

**When saves happen**

20. Writes happen **only** in these places, always outside the 60 Hz gameplay tick, on the main thread, in one call:

| Trigger | File | Caller |
|---|---|---|
| Results confirm | `scores.json` | Session (`submit_run`), then the clear |
| Settings screen closed or backed out of (if dirty) | `settings.json` | Menus (22) |
| Game window close request while dirty | `settings.json` | Save's own close handler |
| Reset / clear actions confirmed | the file(s) affected | Menus (22) |
| Title language chip toggle *(added 2026-11-03)* | `settings.json` | Menus (22) |
| Flight School drill complete (on return to the drill list) *(added 2026-11-03, wave 4)* | `settings.json` (`tutorial.*` keys) | Tutorial (30) via Menus (22) |
| Flight School list left to Title while any `tutorial.*` key is dirty (`school_seen`, `hint_counts`) *(added 2026-11-03, wave 5 batch 2)* | `settings.json` (`tutorial.*` keys) | Tutorial (30) via Menus (22) |

   Save never writes in the Stage state, during a Tally, or during Selecting. Settings opened from Pause write on close (the game is not ticking). Autosave and mid-run save do not exist (Session: a crash loses the run).
21. **Write protocol** (per file, `write_file`): (1) build payload, serialise canonically, compute check; (2) write `<name>.tmp`; (3) read `.tmp` back and verify envelope + check; (4) if `<name>` exists, rename it to `<name>.bak` (replacing the old `.bak`); (5) rename `.tmp` to `<name>`. If any step fails, the previous `<name>` is left in place, the in-memory data is kept, the file stays dirty, and `save_failed(file, reason)` is emitted. The next commit retries.
22. **Load protocol** (`load_all`, once at boot, before the Title menu): for each file try `<name>`, then `<name>.bak`. A candidate is valid if it parses, `format` matches, the size is at most `max_file_bytes`, and the check matches. Result states in the States table. Loading never writes a content file. It may rename a damaged file to `.corrupt`.
23. **Versioning:** `version` is an int, current 1 for both files. Each migration is a pure function `migrate_vN_to_vN+1(payload) -> payload`, run in order on load. The migrated data is written on the next commit, and the old file becomes `.bak`. A file with `version` **higher** than supported is **read-only**: Save loads defaults into memory, leaves the file untouched, disables writes for that file and emits `save_failed(file, "newer_version")` once (→ Menus shows a notice).

**Tamper and corruption**

24. **Light checksum only.** `check = sha256_text(SALT + canonical_payload)` where `SALT` is a constant string in code and `canonical_payload = JSON.stringify(payload, "", true)` (compact, sorted keys). It catches accidental damage and casual edits. It is **not** security: the salt is in the shipped build and anyone can recompute it. Real anti-cheat is the job of online leaderboards (32) with server-side validation, and is a stretch goal.
25. **Number normalisation:** Godot's JSON parser returns all numbers as float. Before hashing and before use, the loader converts every whole-valued float to int. A non-whole float anywhere in a payload means the file is **corrupt**.
26. A check mismatch on `scores.json` is treated as corruption, not as cheating: the game restores the backup and says so. It never accuses the player.

**Web and platform**

27. On Web, `user://` is a browser-backed virtual file system (IndexedDB). Save uses the same API on every platform. **Unverified for Godot 4.7:** whether writes are flushed to IndexedDB at file close, on a timer, or only on page lifecycle events; whether `DirAccess.rename` is atomic there; and what happens in private browsing or when storage is disabled or full. These are checked in the Web spike (Open Questions 1–2).
28. If the first write or an `open` for write fails (Web with storage blocked, read-only disk, full disk), Save enters **Unavailable** for that file: the game runs normally, the data stays in memory for the session, and Menus shows "Progress will not be saved" once per session (Rule 21 event).
29. `fullscreen` on Web needs a user gesture. The loader does **not** apply `display.window_mode = "fullscreen"` at boot on Web. Display scaler (4) applies it on the first input event after load.

**Reset and clear**

30. `reset_settings()` restores schema defaults for all known keys, keeps unknown keys, and keeps a short **keep-list**: `language`, `access.first_run_prompt_done`, `profile.*` (initials and last plane), all `tutorial.*` keys and `touch.hints_seen` *(wave 4, 2026-11-03: Tutorial progress is not a setting; keep-list extended 2026-11-03, UX amendments wave 5 batch 2 — resetting these would make the photosensitivity plate reappear, flip the UI language back to an OS guess and re-show the touch hints)*. `clear_scores()` removes all boards and records and deletes `scores.json.bak` and `.corrupt` too (otherwise the backup would bring the data back). Both need hold-to-confirm in Menus (art bible §7.8).

**When Save is not present**

31. In builds without Save (MVP before Vertical Slice), Session's call to `submit_run` is a no-op that returns "not ranked". Settings use defaults and are not persisted. Nothing else depends on Save being there.
32. *(added 2026-11-03, Accessibility 28 Rule 23)* A run with `run.assisted = true` (latch held by Session) (an ASSIST option such as `access.game_speed_pct` < 100 was used) is PRACTICE: `submit_run` returns "not ranked", writes no board entry and no NEW BEST, and asks for no name entry.

### States and Transitions

**Per file** (`scores`, `settings`):

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| Unloaded | before boot load | Fresh / Clean / Recovered / Reset / ReadOnly | `load_all()` |
| Fresh | no file and no backup (first run), defaults in memory | Dirty | first change |
| Clean | loaded from the main file, matches disk | Dirty | any change |
| Recovered | main file bad; `.bak` loaded; main set aside as `.corrupt` | Dirty | any change; the heal write happens on the next commit |
| Reset | main and `.bak` both bad; defaults in memory; damaged files set aside | Dirty | any change; the player is told once |
| ReadOnly | file `version` newer than supported; defaults in memory, writes off | — (final for the session) | — |
| Dirty | in-memory data differs from disk | Clean | commit ok |
| Dirty | | Dirty | commit failed (retry on next commit) |
| Dirty / Fresh | | Unavailable | write cannot start (storage blocked) |
| Unavailable | memory only for this session | — (final) | — |

**Run submit** (stateless call, order fixed): `preview_rank(record)` (read-only, any time; a rank or `not placed`, Rule 5) → Menus name entry **only when a rank came back** → `submit_run(record, initials)` → entry inserted, records updated, `scores` written → returns `SubmitResult`. If the write fails, the data stays in memory and the Results screen is told (`save_failed`).

### Interactions with Other Systems

| System | Direction | Data (per the linked GDDs) |
|---|---|---|
| Session (1) — GDD | → Save | `RunRecord` (below) via `preview_rank` and `submit_run`; Session calls Save directly, not via `run_ended` |
| Scoring (8) — GDD | via Session | `score` int64. Save stores the true value; the 9-digit display clamp stays a display rule (Scoring F8) |
| [Menus (22)](menus-title-plane-select.md) | ↔ | Reads boards and settings; name entry; settings screens call `set_setting`/`commit_settings`; reset/clear actions; shows `save_failed` notices |
| [Stage tally (21)](stage-end-tally.md) | ← | `get_best_chain(plane, boss_index)` for "NEW BEST" (`boss_index` = `stage_index`, Rule 13), read once at tally tick 0 |
| [Input (2)](input-and-player-mapping.md) | ← | `input.bindings` (`kb1`/`kb2`/`pad`, VS: `pad_s0`–`pad_s3`), `input.move_stick`, `input.dz_preset`, `input.fire_toggle`, `input.tap_assist`. Input applies overrides after registering defaults |
| [Display scaler (4)](display-scaler-and-bezel.md) | ← | `display.*` (`scale_mode`, `window_mode`, `tate_mode`, `bezel_style`, `window_size`) |
| [Audio (24)](audio.md) | ← | `audio.*` steps (F6 mapping, Audio F1), `audio.mono` |
| Localization (27) | ← | `language`; stores no translated text |
| [Accessibility (28)](accessibility-options.md) | ↔ | Registers `access.*` keys in the schema (full list in Rule 16); defines the `run.assisted` PRACTICE rule (Rule 32; latch held by Session) |
| Collision (6) — GDD | ← | `access.reduce_flashing` via Accessibility |
| Online leaderboards (32) — [GDD](online-leaderboards-boss-rush.md) | ← | Reads entries and records (`endings_count`, `bosses_beaten`), `online.*` keys; queues replays in its own file; RUSH/BOSS board ids (F3) |
| Tutorial (30) — [GDD](tutorial.md) | ↔ | Five `tutorial.*` keys (Rule 16); write on drill-list return (Rule 20); kept by `reset_settings()` (Rule 30) |
| Touch controls (31) — [GDD](touch-controls.md) | ↔ | `touch.*` keys (Rule 16); `/touch` board suffix (F3) |

**`RunRecord`** (immutable snapshot built by Session at run end; Session must add the starred fields to its record):

| Field | Type | Source |
|---|---|---|
| `run_ended_by` | enum ENDING / GAME_OVER | Session F7 |
| `stage_count` * | int | stage definitions (2 MVP, 4 Target) |
| `stage_reached` * | int | `stage_index + 1` at run end |
| `run_time` | float s | Session `run_time` |
| `slots[]` | up to 4, played slots only (not Empty, includes Inactive), in slot order | Session Rule 4 |
| per slot: `slot`, `plane` (string id: `lancer`, `leech`, `sentry`, `breaker`), `score`, `continues_used`, `max_chain_per_boss` (int[]), `critical_breaks`, `life_bonus_total`, `pre_continue_score_total`, `is_1cc`, `joined_at_run_start` * , `final_state` * (Alive/Dead/Continue/Inactive) | Session Rule 4, F7 |

*Wave 4 (2026-11-03, Online leaderboards (32)):* the record also carries `mode` (MAIN / RUSH / BOSS), `boss_ids[]` (RUSH/BOSS), `run_seed`, `run_ticks` (non-paused ticks), `assisted` and `debug_tainted`, and `touch` (bool, solo TOUCH run, for the `/touch` board; (decided under auto-approve 2026-11-03, consistency check)).

`one_credit_clear` per slot is **recomputed by Save** from these fields using Session F7, never trusted from the record.

> Specialist agents not consulted (lean mode). Decided under auto-approve (2026-11-03): two files; JSON; solo board per plane + co-op board per player count + run length in the id; top 10; continued and drop-in runs ranked with badges (closes Session Open Question 6); 3-char Latin optional initials; records stored for best chain and 1CC counts; writes only at Results confirm and settings close; separate preview/submit calls.

## Formulas

**F1. Board placement**

`rank_index = count(entries on board where entry.score >= new_score)` ; `rank = rank_index + 1` ; `ranked = (new_score >= min_ranked_score) AND (rank_index < board_size)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| New score | `new_score` | int | 0–`score_store_max` | Board score of the finished run (F2) |
| Existing entries | `entries` | array | 0–`board_size` entries | The target board, sorted descending |
| Board size | `board_size` | int | 5–20 (default 10) | Entries kept per board |
| Minimum score | `min_ranked_score` | int | ≥ 1 (default 1) | A zero score never ranks |
| Insert position | `rank_index` | int | 0–`board_size` | 0-based; equal scores go **below** older entries |

**Output Range:** `rank` 1–`board_size` if ranked. After insert the board is trimmed to `board_size` by dropping the last entry.
**Example:** board `[9,000,000; 7,500,000; 7,500,000; 3,000,000]`, new 7,500,000 → three entries are ≥ it → `rank_index` 3, rank 4. A full 10-entry board whose lowest is 1,200,000: new 1,200,000 → 10 entries ≥ it → `rank_index` 10 → not ranked. New 1,200,001 → 9 entries ≥ it → rank 10, and the old 1,200,000 entry is dropped.

**F2. Board score**

`board_score = min(score_store_max, Σ slot.score over played slots)` ; solo: one slot

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Slot score | `slot.score` | int | ≥ 0 | Score after any continues (Session Rule 6) |
| Played slots | — | set | 1–4 | Slots not Empty, Inactive included (Session F6) |
| Store cap | `score_store_max` | int | 2^53 − 1 = 9,007,199,254,740,991 | Largest integer JSON-through-float keeps exact |

**Output Range:** 0–`score_store_max`. The stored value is the true sum (display clamp to 999,999,999 is a UI rule, Scoring F8). Two entries that both display 999,999,999 still sort by true value.
**Example:** P1 4,200,000 + P2 900,000 + P3 1,100,000 = 6,200,000. A solo 1,000,000,500 stays 1,000,000,500 on the board and displays as 999,999,999.

**F3. Board id**

`board_id = "{stage_count}s/solo/{plane}"` if `played = 1`, else `"{stage_count}s/coop/{played}"`

*Wave 4 (2026-11-03):* `+ "/touch"` for a solo TOUCH run (Touch TF8). RUSH: `"rush{boss_count}/solo/{plane}"` or `"rush{boss_count}/coop/{played}"`; BOSS (1P): `"boss/{boss_id}/{plane}"` (Online leaderboards F5). Online boards prefix `"r{ruleset}/"` (registry `online_board_key`).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Stage count | `stage_count` | int | 2 (MVP), 4 (Target) | Length of the run |
| Played slots | `played` | int | 1–4 | Count of non-Empty slots at run end |
| Plane id | `plane` | string | `lancer`, `leech`, `sentry`, `breaker` | The single player's plane |

**Output Range:** MVP: 2 solo + 3 co-op boards = 5. Target 4-stage: 4 solo + 3 co-op = 7. All 12 may exist in one file.
**Example:** one player with Leech in a 2-stage run → `2s/solo/leech`. Three played slots (one Inactive) in a 4-stage run → `4s/coop/3`.

**F4. Personal best chain**

`best_chain[plane][i] = max(best_chain[plane][i], slot.max_chain_per_boss[i])` for each boss index `i` the slot fought

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Stored best | `best_chain[plane][i]` | int | 0–999 (`chain_cap`) | Best chain on boss `i` with this plane; missing = 0 |
| Run chain | `max_chain_per_boss[i]` | int | 0–999 | From the run record |

**Output Range:** 0–999. Only ever rises. List grows to the number of bosses fought.
**Example:** stored Lancer `[112]`; new slot `[96, 187]` → `[112, 187]`. A slot that fought no boss changes nothing.

**F5. Canonical checksum**

`check = sha256_text(SALT + JSON.stringify(normalise(payload), "", true))`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Payload | `payload` | dictionary | ints, strings, bools, arrays, dictionaries | No floats |
| Salt | `SALT` | string | constant in code | Not secret |
| Normalise | `normalise` | function | — | Whole floats → int; non-whole float → invalid |
| Check | `check` | string | 64 hex chars | Stored in the envelope |

**Output Range:** 64-char lowercase hex. Same payload → same string on every platform (sorted keys, compact, ints).
**Example:** payload `{"b": 1, "a": [2]}` parsed back as `{"b": 1.0, "a": [2.0]}` → `normalise` → `{"b": 1, "a": [2]}` → canonical text `{"a":[2],"b":1}`. The test computes the digest of `SALT + that text` and compares both directions. (Digest literals are generated by the test, not hand-written here.)

**F6. Volume step to bus gain** *(adopted by Audio F1, owned by Audio (24); listed because the setting's meaning depends on it. Audio adds `bus_db = base_db + step_db + trim_db`)*

`gain_db = linear_to_db(step / 10)` ; step 0 → mute

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Step | `step` | int | 0–10 | Stored volume |
| Gain | `gain_db` | float | −∞ (mute) to 0 dB | Bus volume |

**Output Range:** 0 dB at 10, mute at 0.
**Example:** step 7 → `linear_to_db(0.7)` = −3.10 dB. Step 5 → −6.02 dB. Step 0 → mute.

> Decided under auto-approve (2026-11-03): ties favour the older entry; score cap 2^53−1; no floats in payloads; volume in 11 steps.

## Edge Cases

**Ranking**
- **If two entries have the same score**, the older one ranks higher (F1).
- **If a run scores 0** (e.g. died to the first bullet), it is not ranked, but personal records still update (Rule 13).
- **If the run is solo but the player dropped in after another player left** (2 slots played), it ranks on `coop/2`, not solo.
- **If a co-op slot is Inactive at the end**, it still counts as played: its score is in `board_score` and it enters initials (a one-row entry).
- **If the sum passes `score_store_max`**, `board_score` is clamped to it.
- **If `submit_run` gets a record with `run_ended_by = ABANDONED`**, it returns not ranked and writes nothing.
- **If the same record is submitted twice** (double-press on Results), the second call returns the first result and adds nothing. Dedupe key: `run_ms` + every slot score + `stage_reached`, matched against the newest entry committed within the last 5 s (injected clock).
- **If `plane` is not a known id**, the plane is stored as given and the entry goes to `solo/<that id>`. Unknown planes are never dropped.

**Initials**
- **If initials contain a disallowed character on load**, that character becomes `-`. Length is padded with `-` or cut to 3.
- **If a player does not finish name entry within `name_entry_seconds` (30)**, their last-used initials are saved. In co-op the timer is shared and each unfinished player takes their own last-used initials.
- **If the loaded `profile.last_initials` is invalid**, it resets to `AAA` for that slot.

**Files and writes**
- **If the main file is missing but `.bak` exists**, `.bak` is loaded (state Recovered).
- **If the main file is valid but `.bak` is bad**, the main file loads. The next commit overwrites `.bak` anyway.
- **If both are bad**, state Reset. Damaged files are renamed to `.corrupt` (replacing an older `.corrupt`) and the player gets one notice.
- **If the file is larger than `max_file_bytes` (512 KiB)**, it is treated as corrupt without parsing it.
- **If a write fails at step 2 or 3 (tmp)**, nothing changed on disk. If it fails at step 5 after step 4, the main file is missing and `.bak` holds the previous data, so the load protocol recovers it.
- **If the game is closed during a write**, either the old main, or `.bak`, or the new main is intact. At worst one commit is lost.
- **If settings are committed when nothing is dirty**, no write happens.
- **If a setting value is out of range or the wrong type**, only that key resets to its default (not the file). A count of repaired keys is logged.
- **If the file has keys not in the schema**, they are preserved on write (Rule 15).
- **If a file is edited by hand and the check no longer matches**, it is handled as corruption (Rule 26), with no accusation text.

**Time and platform**
- **If the system clock is wrong or changes**, `date_utc` can be wrong. Nothing in gameplay reads it. Sorting never uses it.
- **If the platform is Web and `user://` writes silently fail to persist** (unverified), Save cannot detect this. Mitigation: boot load check logs the count of entries found, so a persistence failure is visible in testing (Open Question 1).
- **If two instances of the game share one `user://`** (two browser tabs), last writer wins on each file. Not supported.
- **If the pad used at name entry disconnects**, the timer ends the entry (above). Input (2) owns the reconnect prompt.

**Settings**
- **If a rebind would leave an action with no binding**, it is rejected (Rule 18).
- **If a stored keyboard override refers to a key the platform does not have**, it is kept in the file but replaced at runtime by the default for that action, and logged.
- **If `language` is `"auto"` and the locale is neither `bn` nor `en`**, English is used.
- **If the game is built without Save (MVP)**, settings reads return defaults and writes are ignored (Rule 31).
- **If a newer build wrote `version` 2 and an older build opens it**, the file is untouched and read-only (Rule 23).

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session state (1) — GDD | Hard | Run record via direct call before clearing; not called for ABANDONED |
| Scoring (8) — GDD | Soft | Score is int64 via Session; Save caps it at `score_store_max` |
| Input and player mapping (2) — GDD | Soft | Defines the action names and classes (`kb1`, `kb2`, `pad`) bindings refer to; Input applies overrides |
| Display scaler and bezel (4) — [GDD](display-scaler-and-bezel.md) | Soft | Defines the `display.*` values |
| Audio (24) — [GDD](audio.md) | Soft | Defines the `audio.*` bus mapping |
| Localization (27) — [GDD](localization.md) | Soft | Resolves `language` |
| Accessibility options (28) — [GDD](accessibility-options.md) | Soft | Registers `access.*` keys |

Save has no hard dependency but Session; the settings keys are data it holds for the others.

**Downstream (depend on this)**

| System | Hard/Soft | Interface |
|---|---|---|
| Menus, title and plane select (22) — [GDD](menus-title-plane-select.md) | Hard | Boards, name entry, settings screens, reset/clear, `save_failed` notices |
| Stage-end tally (21) — [GDD](stage-end-tally.md) | Soft | `get_best_chain` for "NEW BEST" |
| Input (2) — GDD | Hard | Reads bindings, `dz_preset` and options at boot and on change (`InputBindingsData`) |
| Display scaler (4) — [GDD](display-scaler-and-bezel.md) | Hard | Reads `display.*` |
| Audio (24) — [GDD](audio.md) | Hard | Reads `audio.*` |
| Localization (27) — [GDD](localization.md) | Hard | Reads `language` |
| Accessibility options (28) — [GDD](accessibility-options.md) | Hard | Persists `access.*` through the schema |
| Online leaderboards (32) — [GDD](online-leaderboards-boss-rush.md) (stretch) | Hard | Reads entries; replay-verified upload; `online.*` keys; RUSH/BOSS ids |
| Tutorial (30) — [GDD](tutorial.md) | Soft | `tutorial.*` keys |
| Touch controls (31) — [GDD](touch-controls.md) | Soft | `touch.*` keys; `/touch` boards |

**Amendments to other docs**

1. **`design/gdd/game-events-and-session.md`**
   - Rule 2: replace "calls Save and high scores (26) directly with the run record before the clear" with: "…calls `SaveStore.preview_rank(record)` when Results opens (read-only) and `SaveStore.submit_run(record, initials)` on Results confirm, both before the clear. Not called for ABANDONED."
   - Rule 4 slot fields: add `joined_at_run_start` (bool). F7 already uses it but Rule 4 does not store it.
   - Add a **Run record** subsection: fields as in this GDD's `RunRecord` table, including `stage_count`, `stage_reached`, `final_state` and plane as a string id.
   - Open Question 6: mark closed: "Closed 2026-11-03: continued and drop-in runs are ranked with badges; see Save (26) Rules 6–7."
   - AC-06: add "name entry happens between `preview_rank` and `submit_run`; initials default to `profile.last_initials` on timeout".
2. **`design/gdd/scoring.md`** Open Question 7: mark closed with the same decision. Interactions row for Save (26): add "stores the true int64 score, display clamp unaffected".
3. **`design/gdd/collision-damage-lives.md`** line ~379: change the "Setting owned by Save/settings (26)" cell to: "Key `access.reduce_flashing` (bool, default false), registered by Accessibility (28), stored by Save (26)."
4. **`design/gdd/game-concept.md`** §12 Target row: "high-score tables (solo + co-op)" → "high-score tables (solo per plane, co-op per player count)".
5. **`design/gdd/systems-index.md`** row 26: Depends on `1` stays (hard); add soft providers in the note; status `**Designed** (pending review) — [GDD](save-settings-high-scores.md)`. Progress tracker: GDDs written +1. Row 28 depends on `20, 22, 26`. Row 22 depends on `2, 26`. Row 21 depends on `7, 8, 26` (soft).
6. **Input (2) GDD:** ~~must list Save (26); `InputSetup` applies `input.bindings` overrides and `input.pad_deadzone_pct` after registering defaults and re-applies on `setting_changed`.~~ **Closed 2026-11-03:** Input lists Save and persists `InputBindingsData`; the deadzone key is now `input.dz_preset` (input-and-player-mapping.md Rule 39).
7. ~~**Menus (22), Tally (21), Localization (27), Accessibility (28), Display scaler (4), Audio (24), Leaderboards (32) GDDs (to be written):** each must list Save (26)~~ **Closed 2026-11-03 (wave 4):** all written and list Save. Original ask: each must list Save (26) with the interface in this GDD's Interactions table.

## Tuning Knobs

All live in `data/save_rules.tres` (working name) unless noted.

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `board_size` | 10 | 5–20 | Boards feel unreachable; few rivals | Long lists; bigger file | F1; file size (≈ 590 B per 4P entry, 12 boards × 10 ≈ 71 KB) |
| `initials_length` | 3 | 2–5 | Name clashes | Slow name entry on a gamepad | UI width; entry wheel |
| `min_ranked_score` | 1 | 1–1,000,000 | — (1 is the floor) | Early deaths never rank, new players see an empty board | F1 |
| `name_entry_seconds` | 30 | 15–60 | Players rushed in co-op | Stalls the Results flow | Menus (22) |
| `max_file_bytes` | 524,288 | 131,072–2,097,152 | Valid files rejected (12 full boards ≈ 71 KB) | Parsing a huge bad file | Load protocol |
| `backup_count` | 1 (not tunable in MVP) | 1 | — | — | Write protocol |
| `save_toast_ticks` | 90 | 60–180 | Notice unread | Notice lingers | Menus (22) |
| `score_store_max` | 9,007,199,254,740,991 | fixed (2^53 − 1) | Valid scores clamped | JSON/float precision loss | F2 |

**Rationale:** 10 entries is the arcade convention; 3 initials is the arcade convention and fits a 3-slot wheel. The 30 s entry timer is long enough for 4 players to scroll three letters each at about 2 s per letter.

**Owned elsewhere:** `extend_unit`, `score_display_digits` (Scoring 8); `chain_cap` (Chain tracker 7); `starting_lives`, `continue_seconds` (Session 1); setting defaults per key (their owner systems, Rule 16); deadzone values and presets (Input 2, `input_rules.tres`).

## Visual/Audio Requirements

Save draws nothing in play. All visuals belong to Menus screens, which have no bullets on screen (art bible §7.8). Rules for those screens:

| Item | Spec |
|---|---|
| Board row | Rank, initials (Latin, 12 px tier), score (Gold, M tier, tabular digits, separators, 9-digit clamp), plane icon (14×14 plated tile), stage reached, "C" and "1CC" badges as 14×14 plated tiles with glyph, never circle/ring/needle shapes |
| Numerals | Follow the chosen language's digit set on the same fixed grid (art bible §7.5) |
| New-entry highlight | Static Cream 3 px border plus arrow glyph. May pulse at 40% opacity or less, 2 Hz or lower, one element at a time (§7.7). With `access.reduce_flashing` the pulse is off |
| Name entry | Three plated slots; focused slot uses the 3 px Cream border + arrow glyph. Up/down changes the character (stepped, one character per press, hold repeat uses Input nav repeat: 18 ticks, then every 6; amended 2026-11-03, Menus (22)) |
| Save-failed / "will not be saved" notice | A plated strip, Cream text on Char, 1 px outline, shown `save_toast_ticks` (90, 1.5 s) on menu screens only. Red text follows `design/ux/arcade-ui-style.md` 3.1 rule 3 (amended 2026-11-03, wave 5): **Alarm Red `#E03A3E` is never a text fill**; a failure notice is carried by Cream (or the style guide's red *text* token) words plus an Alarm Red plate edge and/or an error glyph — glyph **and** words. The style guide and art bible 4.1 / 7.10 own which red may be used for words. Panel in 8 frames, out 8 (§7.7) |
| Colours | Warm neutral UI palette only. No Void Indigo / Ink fills. No bullet shapes |
| Audio | Name-entry tick (one short SFX per character change), confirm sting, a distinct "error" sound for save failure. All owned by Audio (24). No sound from Save during a stage |

A save write must not cause a visible hitch: no frame in a menu may exceed 33 ms because of a write (Perf AC).

## UI Requirements

Save owns no screens. It supplies data for these (all Menus (22) / Accessibility (28)):

- **High-score screen:** tabs by mode (Solo plane tabs, Co-op 2P/3P/4P), run-length selector once 4-stage exists, badge filter (all / 1CC only).
- **Name entry:** 3-slot wheel per ranked player, simultaneous in co-op, gamepad and keyboard; shows rank from `preview_rank`.
- **Personal records screen:** best chain per boss per plane, 1CC counts.
- **Settings screens:** audio, display, language, controls (rebind with clash rejection and reserved keys), accessibility.
- **Notices:** "Could not save", "Save was damaged, backup restored", "Save was damaged, reset", "Saved by a newer version, changes will not be kept", "Progress will not be saved".
- **Destructive actions:** reset settings, clear scores: hold-to-confirm.

📌 **UX Flag**: run /ux-design for the high-score screen, name entry and settings screens before writing epics.

## Acceptance Criteria

Defaults used: `board_size` 10, `initials_length` 3, `min_ranked_score` 1, `name_entry_seconds` 30, `max_file_bytes` 524,288, `score_store_max` 2^53 − 1, file version 1, MVP `stage_count` 2.

**Test setup:** `SaveStore` is a node-free `RefCounted` class using an injected **in-memory file backend** (a Dictionary of path to text with fault-injection switches for write failure at step N, rename failure, missing file and size). No test touches the real disk. A `SaveRules` resource is built in the test. Run records are built by a test helper. Time is injected (`date_utc` comes from a clock callable). Tests live in `tests/unit/test_save_store.gd`, `tests/unit/test_save_settings.gd` and `tests/unit/test_save_migration.gd`, use the `extends SceneTree` style of `tests/unit/test_chain_tracker.gd`, and are named `test_save_[scenario]_[result]`. The real `user://` backend and Web are [Manual]/[Integration].

### Ranking and boards

- **AC-01 [Unit] (Rules 4–5, F1):** **GIVEN** an empty board, **WHEN** a solo Lancer run with score 1 is submitted, **THEN** it is ranked at rank 1; score 0 is not ranked (but records update, AC-17).
- **AC-02 [Unit] (F1):** **GIVEN** a board `[9,000,000; 7,500,000; 7,500,000; 3,000,000]`, **WHEN** 7,500,000 is submitted, **THEN** rank 4 and order is `[9.0M, 7.5M(old), 7.5M(old), 7.5M(new), 3.0M]`.
- **AC-03a [Unit] (Rule 5):** **GIVEN** a full 10-entry board whose lowest entry is 1,200,000, **WHEN** `preview_rank` is called with a board score of 1,200,000 (above `min_ranked_score`), **THEN** it returns **`not placed`**, Results shows no name entry and `submit_run` stores no entry. *(Added 2026-11-03, wave 5 batch 2.)*
- **AC-03 [Unit] (F1):** **GIVEN** a full 10-entry board with lowest 1,200,000, **WHEN** 1,200,000 is submitted, **THEN** not ranked and the board is unchanged; **WHEN** 1,200,001, **THEN** rank 10 and the old 1,200,000 entry is gone; the board still has 10 entries.
- **AC-04 [Unit] (F2):** **GIVEN** a 3-slot run with scores 4,200,000 / 900,000 / 1,100,000, **THEN** `board_score = 6,200,000`; an Inactive third slot's score is included; an Empty slot is not.
- **AC-05 [Unit] (F2):** **GIVEN** a summed score of 9,007,199,254,740,992 or more, **THEN** the stored score is 9,007,199,254,740,991. **GIVEN** 1,000,000,500, **THEN** the stored value is 1,000,000,500 (no display clamp).
- **AC-06 [Unit] (F3):** a 1-slot Leech 2-stage run → `2s/solo/leech`; 2 slots → `2s/coop/2`; 3 slots (one Inactive) in a 4-stage run → `4s/coop/3`; 1 slot in a 4-stage run → `4s/solo/<plane>`. A 2-stage score never appears on a `4s/…` board.
- **AC-07 [Unit] (Rule 4):** **GIVEN** a record with `run_ended_by = ABANDONED`, **THEN** `submit_run` returns not ranked and the backend has zero writes.
- **AC-08 [Unit] (Rule 6):** **GIVEN** a slot that continued once (score after continue 800,000, `pre_continue_score_total` 600,000), **THEN** the board score is 800,000, `continues_total = 1`, `one_cc = false`; the 600,000 appears nowhere in the score.
- **AC-09 [Unit] (Rule 6, 7; Session F7):** a team where every slot has joined at start, 0 continues, ENDING, not Inactive → `one_cc = true`; the same with one dropped-in slot, or one continue, or GAME_OVER, or one Inactive slot at the end → false. `one_cc` is recomputed from fields even if the record says otherwise.
- **AC-10 [Unit] (edge):** **GIVEN** the same record submitted twice within the dedupe window, **THEN** the second call returns the first result and the board has one entry.
- **AC-11 [Unit] (Rule 11):** an entry has exactly the fields in the entry table, `id` increases by 1 per entry and is never reused after an entry is dropped, `players` are in slot order, `stage_reached` = `stage_index + 1`, `run_ms = round(run_time × 1000)` (63.4 s → 63,400).
- **AC-12 [Unit] (edge):** an unknown plane id `"x"` is accepted and ranks on `2s/solo/x`.
- **AC-13 [Unit] (Rule 10):** an entry for a ranked slot-list of 4 players serialises under 600 bytes of JSON.

### Initials

- **AC-14 [Unit] (Rule 12):** initials `"kaz"` are stored as `"KAZ"`; `"K!Z"` is rejected at input; a loaded `"K!Z"` becomes `"K-Z"`; `"AB"` becomes `"AB-"`; `"ABCD"` becomes `"ABC"`.
- **AC-15 [Unit] (Rule 12):** **GIVEN** `profile.last_initials[0] = "KAZ"` and no entry made, **THEN** the slot-0 entry stores `"KAZ"`; with no stored value it stores `"AAA"`. After a submit with initials `"ZED"` for slot 0, `profile.last_initials[0] = "ZED"` and the settings file is marked dirty.
- **AC-16 [Manual] (Rule 12, `name_entry_seconds`):** in 2P, one player finishes and the other does nothing; at 30 s the second player's last-used initials are saved and the Results flow continues. Evidence: video.

### Records

- **AC-17 [Unit] (Rule 13, F4):** **GIVEN** Lancer best `[112]`, **WHEN** a Lancer slot with `[96, 187]` is submitted (also with score 0), **THEN** best is `[112, 187]`; submitting `[50]` afterwards leaves `[112, 187]`.
- **AC-18 [Unit] (Rule 13):** a slot with `one_credit_clear` true in a 2-stage run → `one_cc_count[lancer][2]` +1; a continued slot adds 0.
- **AC-19 [Integration] (Rule 14):** **GIVEN** stored Lancer boss-0 best 112 and a run with chain 140 on boss 0, **WHEN** the tally asks `get_best_chain` before Results confirm, **THEN** it returns 112 (so "NEW BEST" can show); after `submit_run` it returns 140.

### Settings

- **AC-20 [Unit] (Rule 15–16):** on a fresh store every schema key returns its default (e.g. `audio.music` 7, `language` `"auto"`, `input.dz_preset` `"default"`, `input.fire_toggle` false); `access.reduce_flashing` is false.
- **AC-21 [Unit] (Rule 19):** `set_setting("audio.sfx", 3)` returns 3 from `get_setting` immediately, marks the file dirty and emits `setting_changed` once; the backend has zero writes until `commit_settings()`.
- **AC-22 [Unit] (edge):** `set_setting("audio.sfx", 11)` is rejected (value stays); `-1` rejected; `"5"` (string) rejected; `display.window_mode = "borderless"` rejected.
- **AC-23 [Unit] (Rule 15):** a file with an unknown key `"future.x": 7` round-trips through load and commit with the key unchanged and not applied.
- **AC-24 [Unit] (edge):** a stored `audio.master = 99` resets only that key to 10; the other keys load as stored; the repaired-key count is 1.
- **AC-25 [Unit] (Rule 18):** an override `{kb1: {fire: [Z, SPACE]}}` loads as given; `{kb1: {fire: []}}` is dropped (action keeps default); two `kb1` actions with the same key keep only the first; the same key in `kb1` and `kb2` drops the later override; a `pad` override for `drone` is returned for P1–P4; an `ability` key is unknown and dropped.
- **AC-26 [Unit] (Rule 30):** `reset_settings()` restores all known keys to defaults, keeps unknown keys, keeps the whole keep-list (`language`, `access.first_run_prompt_done`, `profile.*`, every `tutorial.*` key and `touch.hints_seen`) at its stored value, and marks dirty. *(Amended 2026-11-03, wave 5 batch 2.)*
- **AC-27 [Unit] (Rule 17):** a fresh store returns `language` `"auto"`. **GIVEN** locale `bn`, **WHEN** Localization resolves and writes back on first boot, **THEN** Save stores `"bn"` (with `de`: `"en"`) and the next boot reads the explicit value even if the locale changes. A store that already holds `"en"` or `"bn"` is never overwritten by the resolve.
- **AC-28 [Integration] (Rule 18):** **GIVEN** a stored pad `fire` override (button 1), **WHEN** Input boots, **THEN** every slot bound to a pad fires on button 1 and the `kb1`/`kb2` bindings are unchanged.

### Files, write protocol, recovery

- **AC-29 [Unit] (Rule 21):** a commit with all backend calls succeeding produces, in order: write `.tmp`, read `.tmp`, rename main→`.bak` (if a main exists), rename `.tmp`→main; afterwards `.tmp` does not exist and the file is Clean.
- **AC-30 [Unit] (Rule 21):** **GIVEN** a failure injected at step 2 (write `.tmp`), **THEN** the main file is byte-identical to before, the state is Dirty, `save_failed` fires once, in-memory data is unchanged, and the next commit (failure cleared) succeeds.
- **AC-31 [Unit] (edge):** **GIVEN** a failure injected after main→`.bak` but before `.tmp`→main, **WHEN** the store reloads, **THEN** it loads `.bak` (state Recovered) with the previous data.
- **AC-32 [Unit] (Rule 22):** **GIVEN** a main file with a flipped character in a score, **THEN** the check fails, `.bak` is loaded, the main is renamed to `.corrupt`, the state is Recovered, and no content file is written by the load.
- **AC-33 [Unit] (Rule 22):** main and `.bak` both corrupt → state Reset, defaults in memory, both set aside as `.corrupt`, one notice event.
- **AC-34 [Unit] (edge):** a main file of 524,289 bytes is rejected without parsing; 524,288 valid bytes loads.
- **AC-35 [Unit] (Rule 22, edge):** a file with the wrong `format` string, invalid JSON, a missing `payload`, or a non-whole float (`1.5`) is invalid; whole floats (`3.0`) are accepted and converted to ints.
- **AC-36 [Unit] (F5, Rule 24–25):** the check of a payload parsed from its own saved text equals the check computed before saving (round trip through float parsing); changing any value, key or order-insensitive content changes the check; key order in the source does not change it.
- **AC-37 [Unit] (Rule 1):** a corrupt `settings.json` leaves `scores.json` loaded and untouched, and the other way round.
- **AC-38 [Unit] (Rule 28):** with write-open failing, the state is Unavailable, data stays readable and editable in memory, and exactly one "not saved" notice fires per session.
- **AC-39 [Unit] (Rule 30):** `clear_scores()` empties boards and records and deletes `scores.json.bak` and `.corrupt`; a reload then gives state Fresh, not Recovered.
- **AC-40 [Unit] (Rule 31):** with Save absent, Session's `submit_run` call returns not ranked without error.

### Versioning

- **AC-41 [Unit] (Rule 23):** a version-0 test payload (fixture) migrates through each registered migration in order to version 1 and loads with the expected values; the migrated data is written only on the next commit and the old file becomes `.bak`.
- **AC-42 [Unit] (Rule 23):** a file with `version = 2` (current 1) loads defaults, leaves the file byte-identical after a commit attempt (zero writes), and emits `save_failed(file, "newer_version")` once.

### Timing and platform

- **AC-43 [Integration] (Rule 20):** **GIVEN** a full 1P run, **WHEN** the Stage and Tally states run, **THEN** there are zero Save writes; the first write is at Results confirm. Quitting to Title from Pause (ABANDONED) causes zero writes (matches Session AC-35: data byte-identical).
- **AC-44 [Integration] (Rule 20):** closing the settings screen with a changed setting writes `settings.json` once; closing with no change writes nothing; a window-close request while dirty writes once.
- **AC-45 [Perf] (Rule 20):** serialising + writing a worst-case `scores.json` (12 boards × 10 four-player entries, about 71 KB) takes at most 5 ms median on REF-PC through the real backend, and no menu frame exceeds 33 ms on REF-WEB during the commit. Loading it takes at most 10 ms.
- **AC-46 [Manual] (Rule 27, Web):** in release Web export on REF-WEB (Chrome): submit a score, close the tab immediately, reopen: the entry is present. Repeat after changing settings and with the tab closed 1 s after the close of Settings. Also test private mode and blocked storage: the "will not be saved" notice appears and the game runs. Evidence: video + result log. **This is the verification for the unverified Web persistence claim.**
- **AC-47 [Manual] (Rule 29):** Web with stored `fullscreen`: the page loads windowed, and the first key/click applies fullscreen without a browser error.
- **AC-48 [Manual] (Rule 12, art bible §7.5):** the board shows Latin initials correctly in both language modes; digits follow the chosen script on the fixed grid with no layout shift when switching language.

### Determinism

- **AC-49 [Unit] (determinism):** the same sequence of records and settings changes applied twice to two fresh stores gives byte-identical `scores.json` and `settings.json` text given an injected clock (canonical sorted keys, ints only).

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Unverified (Godot 4.7 Web):** is `user://` persisted to IndexedDB reliably on file close, or only on a timer/page event? Can a tab close within 1 s lose the write? Is `DirAccess.rename` safe there? Does any `JavaScriptBridge` flush help? | godot-specialist (Web spike) | Before Vertical Slice (AC-46) |
| 2 | Private-browsing and storage-blocked behaviour on Web (itch.io iframe included). Does `FileAccess.open` fail or silently succeed? | godot-specialist | Before Vertical Slice |
| 3 | ~~Replays: store `run_seed` + per-tick input log per slot and re-simulate (ADR-0001 deterministic tick makes this possible). Estimate: 1 byte per slot per tick × 72,000 ticks (20 min) = 72 KB raw per slot, far smaller with run-length coding. Needs Session to keep `run_seed`, and every system to be bit-exact. Recommend: out of scope for Vertical Slice; reserve `replay` as an optional entry field; decide with Online leaderboards (32).~~ **Closed 2026-11-03:** sparse per-tick event log (about 3 B per input change, zstd, cap 256 KiB), stored only in the online upload queue, never in `scores.json` (online-leaderboards-boss-rush.md F3). | Game designer / technical-director | Target |
| 4 | ~~Should the Results screen save immediately on run end (before name entry) so a tab close on Results cannot lose a score? Needs a "pending entry" with default initials, then edited on confirm. Current design saves at confirm.~~ **Closed 2026-11-03:** kept at confirm. (menus-title-plane-select.md) | Session (1) / Menus (22) | Menus GDD |
| 5 | Should abandoned runs still update personal records (best chain)? Currently no (Rule 13), to keep the no-banking rule simple. | Game designer | After playtest |
| 6 | Bengali digits on the board (follows language per art bible §7.5) vs Latin only for scores. Defaulted to follow language; confirm with Localization. | Localization (27) | Localization GDD |
| 7 | ~~Co-op boards by player count may stay empty for 4P on a single machine. Do we also want a combined "all co-op" tab?~~ **Closed 2026-11-03:** no combined co-op tab at MVP (tabs Solo per plane, Co-op 2P/3P/4P, Records). (menus-title-plane-select.md) | Menus (22) | UX spec |
| 8 | Autoload architecture: `SaveStore` ownership with Session, how `save_failed` reaches Menus (local signal vs GameEvents bus). | ADR | Before implementation |
| 9 | ~~Unknown `plane` ids in boards: show as raw id or hide?~~ **Closed 2026-11-03:** show the raw id in Latin plus a generic plane icon. (menus-title-plane-select.md) | Menus (22) | UX spec |
| 10 | Controller device binding (per-player pad assignment) is not persisted; do we want to remember which pad was P2? | Input (2) | Input GDD |
| 11 | ~~Online leaderboards (32): required validation (replay re-sim vs server rules), profanity filter, handle/ID instead of 3 initials.~~ **Closed 2026-11-03:** replay re-simulation by a custom verifier, server denylist on 3–12 char Latin handles, initials kept locally (online-leaderboards-boss-rush.md). | Online leaderboards GDD | Full Vision |
| 12 | Save-file encryption or obfuscation: deliberately not done (light checksum only). Revisit only if online boards ship. | Technical-director | Full Vision |

> Decided under auto-approve (2026-11-03): Web persistence is flagged as unverified instead of assumed; replays deferred with a size estimate; saves at Results confirm (Open Question 4 keeps the alternative open).
