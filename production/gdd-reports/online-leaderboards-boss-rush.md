# Report: Online leaderboards, boss rush (system 32)

## 1. File written
`design/gdd/online-leaderboards-boss-rush.md` (all 13 required headings, 52 ACs). Stretch GDD in two parts. Online: an opt-in, replay-verified leaderboard. After a run that ranked on the local board, the client uploads a claim plus the replay (`run_seed` + sparse per-tick input log). A custom verifier re-simulates it headlessly and publishes the entry only on an exact match. Platform adapters (Steam, later consoles) supply identity and friends, not trust. Boss Rush: a mode that plays the bosses in era order as "boss-only stages" (a stage with no waves), plus a Single Boss mode. Both reuse Session, Scoring, Boss, Tally and Save unchanged.

## 2. Key decisions (auto-approve, all changeable)
- **Backend: Option C.** The custom verifier service is authoritative on every platform. Steam supplies identity (auth ticket) and friends; an optional Steam Leaderboards mirror needs a GDExtension, so it needs an ADR. Web and non-Steam PC use `HttpAdapter` with an anonymous install id and friend codes. Consoles later add an adapter. `NullAdapter` covers offline and no-consent.
- **Interface:** `LeaderboardAdapter` is async and polled per frame, never in the tick. Methods: identity, friends, fetch, fetch_around, submit, status, delete_my_data, poll.
- **Privacy:** opt-in and off by default. Consent is versioned. Equal-weight Accept/Decline. Handles are 3–12 Latin chars with a server denylist. IP kept only as a 7-day hash. Replays purged after 7 days unless the entry is on a board. A hold-to-confirm "Delete my online data" with a 30-day SLA. No chat or free text.
- **Anti-cheat:**
  - Only locally-ranked, non-assisted, non-debug runs upload.
  - Server pipeline: transport checks, then plausibility (score ≤ stage_units × 31M per slot, minimum run ticks from boss intro + 25% of `T_fight`), then re-simulation of the top 100 per board plus a 5% random audit, with checkpoint hashes every 600 ticks.
  - The replay logs the post-Input logical byte, so ranked-legal input options replay without shipping settings.
  - The client never sees accusations (`NOT_VERIFIED` only).
  - Honest limit stated: tool-assisted input logs verify, so the defence is reports plus manual review of the top 10.
- **Boards:** key = `r{ruleset}/` + local board id (ruleset bumps on any sim-changing patch). Scopes: Global, Friends, Around me. One row per person per board. Co-op teams appear as the submitter plus "+N".
- **Replay format:** sparse events (about 3 B per input change), zstd, cap 256 KiB compressed / 1 MiB raw. Example: 20 min solo is about 11 KB.
- **Offline:** an upload queue of 10 (separate file), exponential backoff 30 s to 1 h, a 30-day board cache with an age label, and nothing ever blocks play.
- **Boss Rush rules:**
  - Order is `[fortress, jet_carrier]` (MVP), growing with built bosses. Each boss is a `waves = []` stage with a `home_stage`, so hp, patterns and `Q_cap` are identical to the main game.
  - Start: 3 lives, 3 bombs, 4 drones. Refit at each boss restores bombs to the floor and drones to 4; lives are not refilled.
  - Standard tally per boss. Scoring is unchanged. Session continue and co-op rules are unchanged, with the `C` and `1CC` badges.
  - Single Boss (1P) feeds `boss/{id}/{plane}` boards only, because its start state is identical for everyone. A boss inside a rush does not feed per-boss boards.
  - Unlock: Boss Rush on the first ENDING; each boss in Single Boss on its first KILLED or CRITICAL_BREAK defeat (TIMEOUT does not unlock).
  - Single Boss with a game-speed assist is the practice mode, closing Accessibility OQ9 for bosses.

## 3. Amendments (exact edits for the main session)
1. **save-settings-high-scores.md**
   - F3 and Rule 9: add RUSH ids `rush{boss_count}/solo/{plane}` and `rush{boss_count}/coop/{played}`, and BOSS id `boss/{boss_id}/{plane}` (1P). MAIN ids unchanged.
   - `RunRecord`: add `mode` (MAIN/RUSH/BOSS), `boss_ids[]`, `run_seed`, `run_ticks`, `assisted`, `debug_tainted`.
   - Rule 4: also reject records with `assisted` or `debug_tainted`.
   - Rule 13: add records `endings_count` and `bosses_beaten`.
   - Rule 16 schema: add `online.enabled` (false), `online.consent_version` (0), `online.handle` (""), `online.install_id` (""), `online.auto_upload` (true), `online.friend_codes` (≤50); owner 32.
   - Entry: optional `online_status` and `replay_ref`.
   - OQ3 closed (sparse event log, stored only in the online queue). OQ11 closed. OQ12 stays.
2. **game-events-and-session.md:** record fields as above. Call `ReplayRecorder.tick(inputs_by_slot)` per tick after Input when `online.enabled`. Run `mode` and stage list (`stage_count` = list length). `run_ticks` counts non-paused ticks.
3. **wave-and-stage-director.md:** a stage may have `waves = []` and a `home_stage`: Warning, `start_intro(boss_id, home_stage)`, Sweep, `stage_cleared`. Add a Dependencies row for 32.
4. **boss-and-boss-parts.md:** `start_intro` stage argument = home stage. `boss_defeated` KILLED or CRITICAL_BREAK feeds `bosses_beaten`.
5. **menus-title-plane-select.md:** the reserved "Online leaderboards (32)" tab becomes the Online tab. Add Boss Rush and Single Boss to Play, plus the Consent, Handle and Delete-my-data screens. Dependency row becomes Soft with a GDD.
6. **accessibility-options.md:** OQ9: boss practice = Single Boss with a game-speed assist (unranked, PRACTICE). Assisted runs never record for upload.
7. **scoring.md:** name the about-31M per slot per stage bound `slot_stage_bound` (31,000,000), read by 32 F1. Changing it needs a ruleset bump.
8. **input-and-player-mapping.md:** add a read-only `sim_input_byte(slot)` (4 bits move + 3 bits buttons).
9. **hud.md / stage-end-tally.md / localization.md:** "BOSS n/N" element; a per-boss tally in RUSH; key families `ui_online.*` and `ui_rush.*` (server messages are codes, never text; handles are Latin).
10. **systems-index.md** row 32: Depends on `26, 1, 2, 8, 14, 16, 22, 28`. Status `**Designed** (pending review) — [GDD](online-leaderboards-boss-rush.md)`. Progress tracker GDDs written +1. Also add "Online leaderboards (32)" to the Save-listing reminder as satisfied.
11. **game-concept.md** §12 Stretch row: "online leaderboards (opt-in, replay-verified; global/friends, per plane / player count) · boss rush (era-ordered + Single Boss)".
12. **New ADRs:**
    - (a) deterministic replay recording and cross-platform verification;
    - (b) online transport/adapters and the Steam GDExtension exception to GDScript-only;
    - (c) hosting and data region.

## 4. Registry candidates
```yaml
  - name: slot_stage_bound
    value: 31000000
    unit: points (hard per-slot per-stage score bound used for online plausibility)
    note: "Owned by Scoring (8); read by Online leaderboards F1. Change requires a ruleset bump."
    source: design/gdd/scoring.md (Edge Cases, 'Hard bound'); design/gdd/online-leaderboards-boss-rush.md (F1)
    referenced_by: [scoring, online-leaderboards-boss-rush]
  - name: replay_max_bytes
    value: 262144
    unit: bytes (compressed replay upload cap; raw cap 1048576)
    range: "131072-524288"
    source: design/gdd/online-leaderboards-boss-rush.md (F3)
    referenced_by: [online-leaderboards-boss-rush]
  - name: online_verify_depth
    value: 100
    unit: ranks per board verified by replay (plus 5 percent random audit)
    range: "25-500"
    source: design/gdd/online-leaderboards-boss-rush.md (Rule 24)
    referenced_by: [online-leaderboards-boss-rush]
  - name: replay_hash_interval_ticks
    value: 600
    unit: ticks between state-hash checkpoints
    range: "300-1800"
    source: design/gdd/online-leaderboards-boss-rush.md (Rule 22)
    referenced_by: [online-leaderboards-boss-rush]
  - name: min_fight_pct
    value: 25
    unit: percent of T_fight (fastest believable boss fight; PROVISIONAL)
    range: "10-40"
    source: design/gdd/online-leaderboards-boss-rush.md (F2)
    referenced_by: [online-leaderboards-boss-rush, boss-and-boss-parts]
  - name: rush_start_drones
    value: 4
    unit: drones (Boss Rush and Single Boss start and refit)
    range: "2-max_drones"
    source: design/gdd/online-leaderboards-boss-rush.md (Rule 37)
    referenced_by: [online-leaderboards-boss-rush, plane-kits-lancer-leech]
formulas:
  - name: online_board_key
    expression: '"r" + ruleset + "/" + local_board_id; local ids: "{n}s/solo|coop/...", "rush{n}/solo|coop/...", "boss/{boss_id}/{plane}"'
    variables: [ruleset, local_board_id]
    output: "string key"
    source: design/gdd/online-leaderboards-boss-rush.md (F5)
    referenced_by: [online-leaderboards-boss-rush, save-settings-high-scores]
  - name: online_plausibility_bound
    expression: "slot_bound = stage_units * slot_stage_bound; claim_bound = sum over played slots; boss_min_ticks = boss_intro_ticks + floor(T_fight * min_fight_pct / 100)"
    variables: [stage_units, slot_stage_bound, boss_intro_ticks, T_fight, min_fight_pct]
    output: "31,000,000-496,000,000; boss_min_ticks 915 (Fortress), 1061 (Jet Carrier)"
    source: design/gdd/online-leaderboards-boss-rush.md (F1, F2)
    referenced_by: [online-leaderboards-boss-rush]
```
Existing entries whose `referenced_by` should gain `online-leaderboards-boss-rush`: `board_id`, `board_placement`, `high_score_board_size`, `score_store_max`, `chain_cap`, `starting_lives`, `bomb_start`, `bomb_stage_floor`, `max_drones`, `boss_intro_ticks`, `boss_fight_budget`, `boss_budget_cap`, `one_credit_clear`, `extend_unit`.

## 5. Conflicts
No conflict with locked values. Notes:
- Save F3 board ids have no mode, so a 2-boss rush would collide with a 2-stage main run. Amendment 1 adds the mode prefix; MAIN ids are unchanged, so it is backward compatible.
- Save OQ3 estimated a dense 1 byte per tick per slot; 32 uses a sparse format (smaller typical, bounded worst case).
- Boss rush leaves players with 0 drones after a death and no powerups. The locked "death resets to 0" rule is kept, and it is flagged as OQ3 rather than overridden.

## 6. Open risks
- **Cross-platform determinism (the feature gate).** Floats and sin/cos may differ across Windows, Linux and Web. A spike (AC-14) is needed before any server work; the fallback is same-platform verification.
- **Tool-assisted and bot input logs verify.** The defence is reports plus manual review of the top ranks.
- `min_fight_pct` 25 is a guess, and headless `ms_per_tick` 1.5 and compression `z` are assumptions; all need measuring.
- **Unverified Godot 4.7 items:** HTTPRequest TLS and CORS on Web/itch iframe; Zstandard in `PackedByteArray.compress` on Web; Steam auth-ticket validation and Steam Leaderboards server-side write; GodotSteam as a GDExtension against CLAUDE.md's GDScript-only rule (ADR).
- **Legal/security items for `/security-audit`:**
  - GDPR basis, processor terms, retention and erase flow
  - minors (COPPA / UK Children's Code), age gate
  - privacy policy hosting
  - TLS and CORS; rate limits and DoS on the upload endpoint
  - decompression bombs; parser fuzzing of the replay format
  - sandboxing the headless verifier (data-only replay, never load paths from it)
  - denylist and moderation workflow; report abuse
  - IP hashing and log retention; install-token storage in plaintext `settings.json`
  - Steam ticket validation; hosting region
- Operating a server (moderation, uptime, cost) is ongoing work that a solo/indie team must budget; the stretch tier should be cut before this if time runs out. Boss Rush works alone with local boards.
