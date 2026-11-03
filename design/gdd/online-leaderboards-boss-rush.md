# Online Leaderboards and Boss Rush

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (UX amendments wave 5)**: Rule 6 platform scope made explicit and aligned with ADR-0007 (Switch / Switch 2 and mobile ship no adapter, Online tab not listed; `HttpAdapter` serves Web, itch and PC only); Rule 13 row-width fix (handle cut to 8 characters + `...`, relative date in the detail strip); Rule 33 covers the no-adapter platform case.
> **Implements Pillar**: Every Hit Counts (a verified score is the proof of mastery), Four Planes, Four Games (boards per plane), History Accelerates (the rush walks the eras boss by boss), Readable Chaos (nothing here touches the simulation)

## Overview

**The data layer:** This stretch system has two parts that share one set of boards.

1. **Online leaderboards.** After a run that already ranked on the **local** board (Save 26), an opted-in player's game uploads a **claim** (score, plane, mode, stages) together with the run's **replay** (the `run_seed` plus the per-tick input log). A small custom **verifier service** re-simulates the replay with the same deterministic game (ADR-0001: 60 Hz integer ticks, one seeded RNG) and publishes the entry only if the re-simulated result equals the claim. Boards are **global** and **friends**, keyed like the local boards. Platform services (Steam today, consoles later) plug in through one `LeaderboardAdapter` interface for identity and friends, not for trust. Everything is **opt-in**, async, never blocks play, and queues when offline.
2. **Boss Rush.** A mode that plays the bosses back to back in era order (one continuous run, shared lives), plus a **Single Boss** mode for one boss. Each boss is a "boss-only stage": a stage definition with no waves, so the Wave director, Boss, Scoring, Tally and Save run unchanged. Rush and Single Boss get their own local and online boards.

**The player impact:** Players who love the chain game get a way to compare against people they will never meet, with a number they can trust because it was replayed, not just typed. Boss Rush gives the boss-chain player a pure, fast, repeatable test: no waves, only the part of the game the DoDonPachi chain exists for. Players who never go online lose nothing: all boards, the rush and the single-boss mode work offline with local boards.

## Player Fantasy

**Anchor moment: my chain, proven.** You finish a Boss Rush with the Leech, tap "Upload", and a small plated tile beside your row turns from dots to a check: *verified*. Your friend's name sits one row above you on the Friends tab. Their row has a check too, so you both know the number is real. You open the Single Boss tab for the Fortress and aim for rank 40 next week.

What makes that feeling work:
- **Verified means replayed.** A row with a check was re-played by the server and gave the same score. Nobody can type a bigger number (**Every Hit Counts**).
- **Four planes, four boards.** Solo boards are per plane online too (**Four Planes, Four Games**).
- **Boss Rush is the pure chain test.** The bosses come in era order, so the plane and the bullets evolve as in the real game (**History Accelerates**).
- **Consent first, easy out.** One clear screen, off by default, one button to erase your online data.
- **Offline is normal.** A run on a train still counts locally and uploads later.

**Anti-fantasy:** a leaderboard full of impossible scores; a name shown to strangers without asking; a rejected run that tells the player "you cheated"; a score lost because the Wi-Fi dropped; a Boss Rush that is only the main game with the waves hidden, or one so punishing that one early death ends the fun.

> `creative-director` not consulted (lean mode, auto-approve).

## Detailed Design

### Core Rules

**A. Scope and trust model**

1. **Local first.** Online never replaces Save's boards. A run is eligible to upload only if all are true: the player has consent (Rule 14), Save ranked it locally (Save Rule 5, so score at least `min_ranked_score` and in the local top `board_size`), `run_ended_by` is ENDING or GAME_OVER, `run.assisted` is false (Accessibility 28), `run.debug_tainted` is false (Wave director 16), and a replay was recorded. Anything else never leaves the machine.
2. **The server never trusts the client.** The claim is a request to verify, not a score. The only thing that publishes an entry is a **VERIFIED** re-simulation (Rule 24). There is no client secret to steal: the client holds no key that can mint a score.
3. **Honest limits.** Replay verification stops edited memory, edited data files, modified builds and typed-in scores. It does **not** stop a tool-assisted or bot-generated input log, because the inputs are digital and replay cleanly. That risk is handled by reports and manual review of the top ranks (Rule 28), and is stated here so nobody assumes more.

**B. Backend (decision)**

4. **Options considered**

| Option | Pros | Cons |
|---|---|---|
| A. Steam Leaderboards only | Free hosting, friends and identity built in, no accounts | Stores an int32 score and a small detail array only, no server-side replay check on its own, PC/Steam only, Web gets nothing, per-platform code |
| B. One custom service only | One trust model on every platform, replay verification, full control of boards | We host and moderate it; need our own identity and friends |
| C. **Custom verifier is authoritative; platform adapters supply identity and friends (Recommended)** | One trust model, one board set on every platform, Steam users get real friends and no extra account, consoles later just add an adapter | Needs a service anyway; Steam leaderboard mirror is optional extra work |

   **Decision: C.** (Pillar fit: Every Hit Counts needs one verified truth, not four unverified ones.)

5. **Common interface** `LeaderboardAdapter` (node-free `RefCounted`, async through a polled event queue so tests need no network; never called from the 60 Hz tick):

| Method | Purpose |
|---|---|
| `identity() -> {provider, id_token, display_hint}` | Who is this player to the service |
| `friends() -> PackedStringArray` | Provider friend ids (may be empty) |
| `fetch(board_key, scope, offset, count) -> request_id` | Read a page |
| `fetch_around(board_key, scope) -> request_id` | Read the rows around the player |
| `submit(claim, replay_bytes) -> request_id` | Queue-level upload of one claim |
| `status(submission_id) -> SubmissionStatus` | Poll a submission |
| `delete_my_data() -> request_id` | Erase everything the service holds |
| `poll() -> Array[OnlineEvent]` | Drain completed requests (called once per rendered frame, never from the GameLoop) |

   *(2026-11-03, ADR-0007:)* every request carries a **bearer install token** over HTTPS. The token is issued once by `POST /v1/installs` (at consent; returns install id + token, stored by Save) and sent as `Authorization: Bearer <token>`; Steam additionally sends its session ticket for identity.

6. **Adapters per platform**

| Platform | Adapter | Identity | Friends | Notes |
|---|---|---|---|---|
| Web (itch.io, own site) | `HttpAdapter` (Godot `HTTPRequest` over HTTPS) | Random install id (128-bit hex) created at consent; no account | Friend codes (Rule 21) | Server must allow CORS from the game's origin (unverified for itch.io iframe) |
| PC (Steam) | `SteamAdapter` wraps `HttpAdapter` | Steam auth session ticket sent over HTTPS; the server validates it with Steam's Web API (unverified) | Steam friends list | Optional later: the server mirrors verified scores to Steam Leaderboards (int32, `min(2^31-1, score)`, F5) so the Steam overlay shows them. Needs Steamworks through a GDExtension, so **→ ADR** (CLAUDE.md allows C++ GDExtension only by ADR) |
| PC (non-Steam, itch.io app) | `HttpAdapter` | Install id | Friend codes | Same as Web |
| Switch / Switch 2, iOS / Android | **None at launch** - `NullAdapter` | - | - | **No online adapter ships on these platforms** (decided 2026-11-03, wave 5). The **Online tab is not listed** at all there (not "listed but disabled"; Menus P22), and every local board works as normal. One adapter per platform (platform user id token, platform friends) may be added later; the interface is the contract. `HttpAdapter` serves **Web, itch.io and PC only** - it is technically capable everywhere, but it is enabled only on those presets (ADR-0007 section 2) |

   *(2026-11-03, ADR-0007:)* every adapter obtains its bearer install token through `POST /v1/installs`; the Steam adapter uses the GodotSteam GDExtension (Steam Win/Linux presets only) for identity, ticket and friends only. **No client-side Steam Leaderboards mirror** (OQ8 closed).
| Offline / not consented / no adapter | `NullAdapter` | — | — | Every call returns `UNAVAILABLE` at once |

7. **Server shape (behaviour, not hosting choice):** an HTTPS JSON API (submit, status, board page, around-me, delete) in front of a database, a job queue, and **verifier workers** that run a headless export of the exact game build for the claim's ruleset. Hosting vendor and region → ADR and `/security-audit`.

**C. Boards**

8. **Online board key** = `"r{ruleset}/" + local_board_id`. `ruleset` is an int bumped only when a change alters simulation results (scoring, patterns, hp, timings). A balance patch bumps it and starts fresh boards; a UI patch does not. The server keeps verifier builds for the current and the previous `ruleset` only.
9. **Local board ids** (Save F3, extended by Amendment 1):

| Mode | Board id | Example | Players |
|---|---|---|---|
| MAIN | `{stage_count}s/solo/{plane}` or `{stage_count}s/coop/{n}` | `2s/solo/lancer` | 1–4 |
| RUSH | `rush{boss_count}/solo/{plane}` or `rush{boss_count}/coop/{n}` | `rush2/solo/leech` | 1–4 |
| BOSS (Single Boss) | `boss/{boss_id}/{plane}` | `boss/fortress/lancer` | 1 only |

10. **Scopes.** `GLOBAL` (top `board_depth_max` = 100 visible, paged `page_size` 10), `FRIENDS` (the player plus friends, all their verified entries on that board, best per person), `AROUND_ME` (5 rows centred on the player's best, F7). Each person appears **once per board** with their best verified score; the Save local board can still hold 10 of one person's runs.
11. **Ordering.** Score descending. Ties: the entry verified earlier ranks higher (matches Save F1 "older above").
12. **Co-op rows.** A local co-op team uploads as one entry under the submitter's handle with a "+N" tag (N = other played slots). Per-player rows are not shown online.
13. **Entry fields shown:** rank, handle, score (true value; display clamp is a UI rule, Scoring F8), plane icon, stage reached or bosses beaten, `C` and `1CC` badges (Save Rule 6), verified tile, date as relative text. *(Width fix 2026-11-03, wave 5: the full field set computes to **348 px against the 328 px inner row width** (Menus F10), so the **row shows the handle cut to 8 characters + `...`** and the **date lives in the focused row's detail strip** as relative text, together with the full handle. Nothing else is dropped.)*

**D. Privacy and consent (GDPR-light)**

14. **Opt-in, off by default.** Setting `online.enabled` (bool, default false). It can only become true through the **Consent screen** (UI), which states in plain words, in both languages: what is sent (handle, scores, plane, run length, the input log of your run, game version, an anonymous install id; on Steam, a Steam id the server stores as a hash), what is not sent (no names from your device, no files, no telemetry, no chat), who runs the service, how long data is kept (Rule 18), and how to delete it. The player accepts or declines; declining leaves the game fully playable and the question is not asked again until they open the Online tab.
15. **Consent is versioned.** `online.consent_version` stores the version accepted. If the build's `consent_version_current` is higher (the policy text changed), uploads stop until the player accepts again.
16. **Handle.** A display name of 3–12 characters from `A–Z a–z 0–9 _ - .`, typed on keyboard or chosen with the same stepped wheel as initials (extended set). Latin only, consistent with Save Rule 12 and the art bible (a name wheel cannot offer Bengali conjuncts). On Steam the default suggestion is the Steam persona name with disallowed characters removed, shown for the player to edit and confirm; it is never uploaded without confirmation. The server applies a denylist (English and common transliterated Bengali terms); a refused handle returns `HANDLE_REFUSED` and the player picks another. No real-name field exists.
17. **Data minimisation.** The service stores: install id (or hash of provider id), handle, claims, verification results, board entries, replays. It stores **no** IP address beyond a hashed copy kept `ip_hash_days` (7) for rate limiting, and no device data.
18. **Retention.** Replays of entries on a board are kept while the entry is on the board; replays of REJECTED, EXPIRED or off-board entries are deleted after `replay_retention_days` (7). Entries and handle are kept until the player deletes them or `inactive_purge_days` (730) pass.
19. **Right to erase.** Settings > Online has **Delete my online data** (hold-to-confirm, art bible §7.8). It calls `delete_my_data()`; the service removes the handle, entries and replays for that identity within `erase_sla_days` (30) and answers `ERASED`. The local install id is then discarded, `online.enabled` becomes false, and local scores are untouched. Withdrawing consent without deleting just stops uploads.
20. **No social surface.** No chat, no messages, no avatars, no free text other than the handle. Report (Rule 28) is the only player-to-player signal.
21. **Friend codes (non-Steam).** At consent the service issues an 8-character code (Crockford base32, no I, L, O, U). A player adds up to `friends_max` (50) codes. A friend link is **one-way until accepted**: only people who added your code see you on their Friends tab, and you see only people whose codes you added. Steam builds use the Steam friends list and no codes.

**E. Replay and verification**

22. **What is recorded.** From `run_started`, a node-free `ReplayRecorder` (called by Session once per tick, after Input produces the sim-facing state) stores:
   - **Header:** magic, `format_version`, `game_version`, `ruleset`, `content_hash` (hash of the data manifest, so a modified `.tres` is detected), `mode`, stage or boss id list, `run_seed`, played slots with plane ids and `joined_at_run_start`.
   - **Input events** (run-length: a record only when a slot's input byte changes): tick delta, slot, input byte. *(2026-11-03, ADR-0003:)* the byte is bits 0-3 move, 4 Fire, 5 Drone, 6 Bomb held, 7 fire pulse (Tap Assist / touch auto-fire). **Touch runs** also record, per tick where any changes or is non-zero, `drag` (int16 x / y in 1/16 canvas px), `drag_active` and `fire_auto`, so `/touch` boards are replay-verified (decision: record, don't exclude). The byte is the **logical** input the simulation reads (Input's output, after deadzone, sector hysteresis, tap assist and buffering): 4 bits for the 8-way move plus neutral, 3 bits for Fire, Drone, Bomb. Logging after Input means every ranked-legal input option (`tap_assist`, `fire_toggle`, `dz_preset`) replays exactly, with no need to ship Input's settings.
   - **Run events:** `join(slot, plane, tick)`, `continue_accept(slot, tick)`, `slot_forfeit(slot, tick)`.
   - **Checkpoints:** a 32-bit state hash every `hash_interval_ticks` (600). The server compares its own hash at each; the first mismatch aborts early and is logged with the tick.
   - **Footer:** the claimed outcome (per-slot score, stage or boss reached, `run_ended_by`, total ticks).
   The whole file is compressed (Godot `PackedByteArray.compress`, Zstandard; availability in 4.7 unverified) and capped (F3).
23. **Deterministic contract (→ ADR).** Replays need a simulation that is bit-exact between the client's platform and the verifier build. ADR-0001 already requires integer ticks, no `delta` in logic and one seeded RNG; this system adds: no wall-clock reads and no platform-dependent calls in the sim; floats used in the sim must be quantised or produce the same result on Windows, Linux and Web (the Boss GDD already quantises boss positions to 1/16 px). A cross-platform spike (Open Question 1) must pass before this feature is committed. **If it fails**, the fallback is verifying only against same-platform-class builds and marking others `UNVERIFIED` on a separate tab.
24. **Verification pipeline** (server side, per submission):
   1. **Transport checks:** HTTPS, body at most `replay_max_bytes`, decompressed size at most `replay_max_raw_bytes`, format parses, `ruleset` supported, consent version acceptable, rate limit not exceeded (`submit_per_hour` 20 per install).
   2. **Plausibility (cheap, F1, F2):** score and time bounds, chain at most `chain_cap`, slot counts, stage counts, `claimed_ticks` equals the footer and the replay's last tick, replay hash not seen before.
   3. **Priority:** a claim goes to the replay queue if its provisional rank (from the claimed score) is within `verify_top_n` (100) on its board, or it is picked by the random audit (`audit_pct`, 5). Others stay **PENDING** (not shown). When the board changes so a pending entry now falls inside `verify_top_n`, it is queued.
   4. **Re-simulation:** a headless worker of the `ruleset` build plays the input log at full speed with no rendering. The result must match the claim **exactly**: every slot score, the ending, the stage reached, ticks. Checkpoint hashes must match.
   5. **Result:** `VERIFIED` (entry published), `REJECTED(code)`, or `EXPIRED` (not verified within `claim_ttl_days`).
   The replay file is **data only**: the worker never loads a path, script or resource named inside it.
25. **Status and messages.** The client shows only the status tile and a short localized line from the **reason code**; the server never sends text. Codes: `OK`, `PENDING`, `NOT_VERIFIED` (covers every replay or plausibility failure, no detail), `RATE_LIMITED`, `UPDATE_REQUIRED`, `HANDLE_REFUSED`, `SUSPENDED`, `ERASED`. The wording is "Could not verify this run", never an accusation (same stance as Save Rule 26).
26. **Repeated failures.** An install with `strike_limit` (5) `NOT_VERIFIED` results inside `strike_window_days` (30) is rate-limited to `strike_submit_per_day` (2) for 30 days. No notice says why.
27. **What the replay is also for.** The recording is general-purpose. A local "watch replay" feature and the Menus attract-mode demo can reuse it, but neither is in scope (Open Questions 6, 7).
28. **Reports and review.** Any board row can be reported (hold-to-confirm). `report_hide_threshold` (5) reports hide the row pending manual review. The top `manual_review_top` (10) rows of each board get a human look at the replay before the first publish after a ruleset change (a process item, listed for production).

**F. Offline behaviour**

29. **Never block.** Online calls are asynchronous, polled per rendered frame, with timeout `request_timeout_s` (10). A failed call never delays Results, the next run, or any menu input.
30. **Upload queue.** When a run qualifies (Rule 1), Results shows "Upload" as an action and also auto-queues it if `online.auto_upload` (bool, default true after consent). The claim and replay are written to `user://online_queue.json` plus `user://replays/<id>.mjr`, a separate file from `scores.json` so a damaged queue cannot touch scores (Save Rule 1 spirit). The queue holds at most `queue_max` (10) claims; when full, the lowest-score claim is dropped. Uploads retry with exponential backoff (F6) and on each launch and each Online-tab open.
31. **Board cache.** The last page fetched per board and scope is cached in `user://online_cache.json` with its fetch time. Offline, the Online tab shows the cache with "Offline - last updated {n} days ago". Cache entries older than `cache_max_days` (30) are discarded.
32. **No Save write during a stage.** Queue and cache writes happen only on Results confirm and on the Online tab, never in the Stage or Tally states (same rule as Save Rule 20).
33. **Without the service** (`NullAdapter`, no consent, no network): the Online tab says so in one line and all local boards work. **On a platform that ships no adapter at all** (Switch / Switch 2, iOS / Android, Rule 6) the Online tab is **not listed** - there is no disabled tab and no notice, because there is nothing for the player to turn on.

**G. Boss Rush**

34. **Modes.** *Boss Rush* is every boss in `rush_order` in one run. *Single Boss* is one chosen boss. Both start from the Menus Play flow with plane and player-count select unchanged (1–4 players for Rush; Single Boss ranks only with 1 player, more players play it unranked).
35. **Sequence.** `rush_order` is data: `[fortress, jet_carrier]` in the MVP build, then `plasma_ring` and the stage 4 boss as they are built. The set id is `rush{boss_count}`. Bosses follow their home era, so Era shift (19) shows the same plane and backdrop it would in the main game.
36. **Boss-only stage.** Each boss is played as a stage whose definition has `waves = []` and a `home_stage` (the boss's own stage number). The Wave director goes Warning, then `Boss.start_intro(boss_id, home_stage)`, then Sweep, `stage_cleared`. Because the Boss and the Boss power budget read the **home stage**, a boss in the rush has exactly the same hp, patterns and `Q_cap` as in the main game. `stage_index` is the position in the rush and is used for Session events and the drop/RNG seeds.
37. **Start state.** At run start: `starting_lives` (3) lives, `bomb_start` (3) bombs, `rush_start_drones` (4 = `max_drones`) drones, chain 0, per player. Rationale: with no small enemies there are no powerups to build drones, so the rush begins fully built.
38. **Refit at each boss.** On each `stage_started` after the first: bombs go to at least `bomb_stage_floor` (Bombs rule, unchanged) and drones are set to `rush_start_drones`. Lives are **not** refilled. A death during a boss still resets that player's drones to 0 (locked rule) and they stay 0 until the next boss's refit (Open Question 3).
39. **Between bosses.** The normal Stage-end tally runs per boss (so the stage-end bonuses and "NEW BEST" work); then a `rush_refit_ticks` (120) beat shows the drones docking, then the next Warning. Chain drops at `stage_cleared` (Chain tracker, unchanged).
40. **Scoring.** Unchanged (Scoring 8): hit score, boss kill value, Critical Break, stage-end bonuses, extends at `extend_unit`. No small-enemy or item income, so the rush score is dominated by the boss chain, the Critical Break and the stage-end bonuses. This is the intended identity of the mode.
41. **Lives, continues, co-op.** Session rules apply unchanged: `continue_seconds`, per-player lives, score restarts at 0 on a continue, Inactive slots, drop-in. `N`-based scaling (Co-op 18) applies as in the main game. A continued rush is ranked with the `C` badge; 1CC is computed by the same formula (Session F7).
42. **End.** ENDING when the last boss's `stage_cleared` fires. GAME_OVER when no slot can continue. A TIMEOUT withdrawal still clears the stage (Boss reason TIMEOUT) and the rush goes on; its chain bonuses are what they are.
43. **Single Boss.** One boss, same start state (3 lives, 3 bombs, 4 drones), one `stage_started`, ENDING at its `stage_cleared`. Ranks on `boss/{boss_id}/{plane}` for 1 player. Only Single Boss feeds per-boss boards, because its start state is identical for everyone (a boss inside a rush starts with whatever lives the player has left, which changes the Life Damage Bonus).
44. **Unlocks.** *Boss Rush* unlocks the first time Save records an ENDING (`endings_count` total at least 1, any plane, continues allowed). A boss becomes selectable in *Single Boss* the first time `boss_defeated` with reason KILLED or CRITICAL_BREAK is seen on this profile (`bosses_beaten`, Amendment 1). A TIMEOUT withdrawal does not unlock it. Without Save (MVP builds, Save Rule 31) both are unlocked, because nothing can be remembered.
45. **Practice.** With a game-speed assist (Accessibility 28), Single Boss is a practice mode: it works, is marked PRACTICE, and never ranks or uploads. This closes Accessibility Open Question 9 for the boss part (the stage-practice part stays with Tutorial 30).
46. **Local records.** Rush and Single Boss runs update Save's personal records (best chain per plane per boss, F4) like any run. `one_cc_count` is kept per `stage_count` key; a rush adds under its own key `rush{n}`.

### States and Transitions

**Online service** (one object):

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| Disabled | `online.enabled` false or no adapter | ConsentPending | player opens Online tab |
| ConsentPending | consent screen shown | Ready / Disabled | accept / decline |
| Ready | consented, last call ok | Offline / Backoff / UpdateRequired / Suspended | call fails / server says so |
| Offline | no network | Ready | a call succeeds |
| Backoff | retry timer running (F6) | Ready / Offline | timer ends and call ok / fails |
| UpdateRequired | server does not support this `ruleset` | Ready | new build |
| Suspended | server in maintenance | Ready | server says ok |
| ReConsent | `consent_version_current` > accepted | Ready / Disabled | accept / decline |

**Submission:**

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| Queued | in the local queue | Uploading | service Ready |
| Uploading | request in flight | Queued / Pending | fail (backoff) / accepted |
| Pending | server holds it, not shown | Verified / Rejected / Expired | pipeline result |
| Verified | published | — | — |
| Rejected(code) | final | — | — |
| Expired | not verified within `claim_ttl_days` | — | — |
| Dropped | queue full or replay too large, local only | — | — |

**Boss Rush run:** Locked → Unlocked (Rule 44); a run is a normal Session run (Selecting, Stage, Tally, Results) with `mode = RUSH`; Stage is repeated once per boss.

### Interactions with Other Systems

| System | Direction | Data (provisional unless stated) |
|---|---|---|
| Session (1) — GDD | ↔ | Adds `mode`, `boss_ids`, `run_seed`, `run_ticks`, `run.assisted`, `run.debug_tainted` to `RunRecord`; calls `ReplayRecorder.tick()` once per tick; reads rush stage list; `stage_started` per boss |
| Save (26) — GDD | ↔ | Board ids with mode, records `endings_count` and `bosses_beaten`, `online.*` settings keys, entry may carry `online_status`. Leaderboards read entries; they never write `scores.json` |
| Wave and stage director (16) — GDD | ← | Boss-only stage definition (`waves = []`, `home_stage`); `debug_tainted` |
| Boss and boss parts (14) — GDD | ← | `start_intro(boss_id, home_stage)`; `boss_defeated(reason, killer)` feeds `bosses_beaten` |
| Boss power budget (15) — GDD | ← | `Q_cap` by home stage (no change); `T_fight` feeds the min-time table (F2) |
| Scoring (8) — GDD | ← | The per-slot per-stage bound (~31M) used by F1; int64 score |
| Accessibility (28) — GDD | ← | `run.assisted` blocks upload; game speed makes Single Boss practice |
| Input (2) — GDD | ← | Per-slot logical input byte per tick (the sim-facing state) |
| Menus (22) — GDD | → | Online tab, consent screen, handle entry, Boss Rush and Single Boss entries, status tiles |
| Localization (27) — GDD | ← | `ui_online.*` and `ui_rush.*` keys; numerals; Latin handles |
| Co-op (18) — GDD | ← | `N` scaling and `team_pct` apply in the rush |
| Bombs (12), Powerups (13), Plane kits (11) — GDD | ← | Refit via `stage_started`; no carriers in a boss-only stage; drones set through Session (`drone_count`) |
| Era shift (19) — GDD | ← | Era by boss home stage (`era_for_stage(home_stage)`) |
| HUD (20), Stage-end tally (21) — GDD | → | "BOSS n/N" element; tally variant that is skippable after `tally_min_ticks` as usual |
| Touch controls (31) — GDD | ← | Touch solo boards (`/touch` suffix on the local board id) map to online boards through F5 unchanged; touch runs are solo only. The replay records the touch fields `drag` (int16 x/y, 1/16 px), `drag_active`, `fire_auto` per tick (Rule 22; ADR-0003, ADR-0008) |
| Steam / platform SDK | ↔ | `SteamAdapter` (→ ADR for the GDExtension) |

> Decided under auto-approve (2026-11-03): Option C (custom verifier authoritative, platform adapters for identity and friends); opt-in consent with versioning and erase; Latin handles; upload only locally ranked runs; replay verified for the top 100 plus 5% audit; boards keyed by ruleset; Boss Rush as boss-only stages; rush starts with 4 drones and refits per boss; only Single Boss feeds per-boss boards; unlock on first ENDING.

## Formulas

**F1. Score plausibility bound**

`slot_bound = stage_units × slot_stage_bound` ; `claim_bound = Σ over played slots of slot_bound` ; pass iff every `slot.score ≤ slot_bound` **and** `board_score ≤ claim_bound`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Stage units | `stage_units` | int | 1–4 | MAIN: `stage_count`; RUSH: `boss_count`; BOSS: 1 |
| Per-slot per-stage bound | `slot_stage_bound` | int | 31,000,000 | Scoring's hard bound per slot per stage (Scoring Edge Cases; Plane kits K9 rate) |
| Slot score | `slot.score` | int | ≥ 0 | From the claim |
| Played slots | — | set | 1–4 | |

**Output Range:** 31,000,000 (1 slot, 1 stage) to 496,000,000 (4 slots, 4 stages); always below `score_store_max` and the Steam int32 limit.
**Example:** RUSH with 2 bosses, 3 played slots: `claim_bound = 3 × (2 × 31,000,000) = 186,000,000`. A claim of 185,999,999 passes the sum check; 186,000,001 fails. A 2-slot, 2-stage claim with slot scores 70,000,000 and 1,000,000 has sum 71,000,000 (under 124,000,000) but fails the slot check (70,000,000 > 62,000,000).

**F2. Minimum run length**

`min_ticks = Σ over stages of stage_min_ticks` ; `boss_min_ticks = boss_intro_ticks + floor(T_fight × min_fight_pct / 100)` ; MAIN: `stage_min_ticks = wave_min_ticks + boss_min_ticks`; RUSH and BOSS: `stage_min_ticks = boss_min_ticks` ; pass iff `claimed_ticks ≥ min_ticks` for a run that ended in ENDING (a GAME_OVER run is only checked against the ticks it replays)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Boss intro | `boss_intro_ticks` | int | 240 | Registry (Boss 14) |
| Reference fight length | `T_fight` | int | 2,400–3,600 | Boss budget F6 (Fortress 2,703; Jet Carrier 3,285) |
| Fastest fight share | `min_fight_pct` | int | 10–40 (default 25) | Fastest believable fight as a percent of `T_fight`. **Provisional**, to be set from the fastest dev Critical Break kill (Open Question 4) |
| Wave minimum | `wave_min_ticks` | int | ≥ 0 | Earliest the scheduled waves can end, generated from stage data by a tool |

**Output Range:** ≥ 480 ticks per boss. **Example:** Fortress `240 + floor(2703 × 25 / 100) = 240 + 675 = 915`; Jet Carrier `240 + floor(3285 × 25 / 100) = 240 + 821 = 1,061`. RUSH of both: `min_ticks = 1,976` (32.9 s). A rush claim of 1,500 ticks is `NOT_VERIFIED`.

**F3. Replay size**

`raw_bytes = header_bytes + Σ_slots (changes_s × record_bytes)` ; `sent_bytes = ceil(raw_bytes × z)` ; accept iff `raw_bytes ≤ replay_max_raw_bytes` and `sent_bytes ≤ replay_max_bytes`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Header | `header_bytes` | int | about 256 | Ids, seed, hash, slots, footer |
| Input changes | `changes_s` | int | 0–ticks | Records for slot s (one per input-byte change) |
| Record size | `record_bytes` | int | 3 | 1 byte tick delta (2 if over 127), 1 slot and flags, 1 input byte; counted as 3 |
| Compression ratio | `z` | float | 0.3–0.7 | Zstandard ratio; **assumption to measure** |

**Output Range:** typical 5–60 KB; worst case under the caps.
**Example:** 1 slot, 20 min (72,000 ticks), 9,000 changes (a change about every 8 ticks): `raw = 256 + 9,000 × 3 = 27,256`; at `z` 0.4 `sent = 10,903` bytes. Worst case 4 slots changing every 2 ticks: `raw = 256 + 4 × 36,000 × 3 = 432,256` (under 1,048,576); at `z` 0.6 `sent = 259,354` (under 262,144, passes narrowly). This sparse format beats the dense 1 byte per tick per slot of Save Open Question 3 (72,000 B per slot) for typical play and stays within the cap in the worst case.

**F4. Verifier load**

`core_hours_per_day = submissions_per_day × p_verify × (ticks × ms_per_tick / 1000) / 3600` ; `p_verify = p_top + audit_pct/100 × (1 − p_top)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Submissions | `submissions_per_day` | int | 0–10,000 | After the transport and plausibility checks |
| Share in the verify depth | `p_top` | float | 0–1 | Share of claims whose provisional rank is within `verify_top_n` |
| Audit share | `audit_pct` | int | 0–100 (default 5) | Random audit of the rest |
| Tick cost headless | `ms_per_tick` | float | 0.5–3.0 | **Assumed 1.5 ms**, to be measured on the real sim |
| Ticks | `ticks` | int | 3,600–72,000 | Run length |

**Output Range:** 0 up to the farm size.
**Example:** 2,000 submissions/day, `p_top` 0.30, 20-minute runs (worst case): `p_verify = 0.30 + 0.05 × 0.70 = 0.335`; 670 verifications × (72,000 × 1.5 / 1000 = 108 s) = 72,360 s = **20.1 core-hours/day**, about 0.84 of one core. Typical runs (5 min) are a quarter of that.

**F5. Online board key and platform score**

`online_key = "r" + str(ruleset) + "/" + local_board_id` ; `steam_score = min(2,147,483,647, board_score)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Ruleset | `ruleset` | int | ≥ 1 | Bumped when simulation results change |
| Local board id | `local_board_id` | string | Rule 9 | From Save F3 (extended) |
| Board score | `board_score` | int | 0–`score_store_max` | Save F2 |

**Output Range:** key string of 8–40 chars; `steam_score` 0 to 2,147,483,647 (never clamped in range: max 496,000,000).
**Example:** `r1/rush2/solo/leech`; `r1/boss/fortress/lancer`; `r2/2s/coop/3`. `board_score` 124,000,000 → `steam_score` 124,000,000.

**F6. Upload retry backoff**

`delay_s = min(backoff_max_s, backoff_base_s × 2^attempt)` ; `jittered = delay_s × (80 + rng.randi_range(0, 40)) div 100` with an injected RNG

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Attempt | `attempt` | int | 0+ | Failures so far for this claim |
| Base | `backoff_base_s` | int | 30 | |
| Cap | `backoff_max_s` | int | 3,600 | |

**Output Range:** 30 to 3,600 s before jitter (24 to 4,320 after). **Example:** attempts 0..7 give 30, 60, 120, 240, 480, 960, 1,920, 3,600 (3,840 capped). At attempt 3 the jittered delay is 192–288 s.

**F7. Around-me window**

`start = max(1, min(my_rank − around, total − 2 × around))` ; rows `start … min(total, start + 2 × around)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| My rank | `my_rank` | int | 1–total | The player's best verified rank |
| Total | `total` | int | ≥ 1 | Entries on the board |
| Rows each side | `around` | int | 2 | |

**Output Range:** 1–5 rows. **Example:** rank 57 of 312 → rows 55–59; rank 1 → 1–5; rank 311 → `min(309, 308) = 308` → 308–312; total 3, rank 2 → `max(1, min(0, −1)) = 1` → rows 1–3.

## Edge Cases

**Eligibility and consent**
- **If the player has not consented**, no recorder runs, nothing is queued and the Online tab shows the consent screen on open.
- **If a run was ranked locally but is not in the local top 10**, it is not ranked locally and so is not uploaded (Rule 1).
- **If `run.assisted` or `run.debug_tainted` is true at any tick of the run**, the run never uploads and Results shows no Upload action.
- **If the game speed assist is switched on and back to 100 mid-run**, the latch stays true (Accessibility) and the run never uploads.
- **If consent is withdrawn while claims are queued**, the queue and its replays are deleted at once and nothing is sent.
- **If `consent_version_current` rises**, uploads stop (state ReConsent); queued claims stay locally for `claim_ttl_days` and send after the player accepts.
- **If the handle is empty**, the first upload asks for one; if declined the claim stays queued.

**Replay and verification**
- **If the replay exceeds `replay_max_bytes` or `replay_max_raw_bytes`**, the claim is Dropped locally with a short notice; the local board entry is unaffected.
- **If the replay's tick count differs from the footer or the claimed `run_ms`** (more than 1 ms rounding), the claim is `NOT_VERIFIED`.
- **If the same replay content hash is submitted by two installs**, the first stays; the second is `NOT_VERIFIED`.
- **If a checkpoint hash differs**, verification stops at that tick and the claim is `NOT_VERIFIED` (the tick is logged server-side only).
- **If the build's `content_hash` is not the verifier's for that ruleset**, the claim is `UPDATE_REQUIRED` when the version is old, else `NOT_VERIFIED`.
- **If cross-platform float drift makes honest replays fail**, the rate of `NOT_VERIFIED` for first-time submitters spikes; the dashboard alarm (`false_reject_alarm_pct`, Open Question 1) triggers the fallback in Rule 23.
- **If a worker crashes mid-run**, the claim returns to the queue; after `verify_retry_max` (3) crashes it is `EXPIRED`, not rejected.
- **If a claim is verified but its provisional rank was wrong**, the entry publishes at its true rank.
- **If a ruleset is retired**, its boards become read-only archive pages and uploads for it return `UPDATE_REQUIRED`.

**Boards**
- **If two verified entries have the same score**, the earlier verified ranks higher.
- **If a player has several verified runs on a board**, only the best is shown; the others are kept for `inactive_purge_days` and invisible.
- **If a friend deletes their data**, their rows disappear from Friends at the next fetch.
- **If the player has no verified entry**, Around-me shows "No entry yet" and Global shows the top.
- **If a board has fewer entries than `page_size`**, the page is short; no empty rows are drawn.
- **If a Steam persona name contains only disallowed characters**, the suggested handle is empty and the player types one.
- **If a handle is later denylisted**, the service replaces it with `Player` plus a 4-digit number and the client is told `HANDLE_REFUSED` on the next submit.

**Offline and errors**
- **If the network drops mid-upload**, the claim returns to Queued with backoff (F6); no duplicate is created because the server dedupes on replay hash.
- **If `HTTPRequest` is unavailable or blocked (Web CORS, storage blocked)**, the adapter reports `UNAVAILABLE`; the Online tab shows one line and play is unaffected.
- **If the system clock is wrong**, only relative-date text and `claim_ttl_days` are affected; nothing in the sim reads it.
- **If the queue file is damaged**, it is set aside as `.corrupt`, an empty queue starts, and the replays directory is cleared of unreferenced files; scores are untouched.
- **If the device is full**, the replay is not stored and the claim is Dropped.
- **If a request times out**, it counts as a failure for backoff.

**Boss Rush**
- **If a player dies in the first seconds of a boss**, they respawn with 0 drones (locked rule) and can still finish the fight; the Boss enrage rule (Boss Rule 33) is the safety net.
- **If all players die with no continue during boss 1**, GAME_OVER; score below `min_ranked_score` does not rank.
- **If a boss withdraws on TIMEOUT**, the stage clears; no `bosses_beaten` entry is added.
- **If a rush is launched with `rush_order` containing a boss not yet built**, that boss is dropped from the set at build time; the set id reflects the real count (`rush2`).
- **If a player joins mid-rush**, Session drop-in rules apply (3 lives, current boss's drone state 0 until the next refit); the team entry has no 1CC badge (Save Rule 7).
- **If Single Boss is played by 2+ players**, it runs, shows PRACTICE-like "no board" text and does not rank.
- **If `Boss Rush` is locked and the player holds the profile from before the unlock existed**, the unlock is derived from `endings_count` (missing = 0); a player who cleared earlier sees it after their next ENDING. A one-time migration is not needed (Rule 44 reads the new record, absent = locked) → Open Question 5.
- **If Save is absent**, both modes are unlocked and unranked (nothing to store).
- **If the rush set grows after a patch**, `rush{n}` changes id; old scores stay on `rush2`, new on `rush3`/`rush4`. The ruleset also bumps.

**Security-relevant**
- **If a replay contains a path, script or resource name**, the worker ignores it; the format has no field that is ever used as a path.
- **If a decompression bomb is uploaded**, the decompressor stops at `replay_max_raw_bytes` and the claim is `NOT_VERIFIED`.
- **If a tool-assisted input log is submitted**, it verifies (Rule 3). Reports and manual review of the top ranks are the only defence.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Save, settings and high scores (26) — GDD | Hard | Local ranking decides eligibility; board ids; `online.*` keys; `endings_count`, `bosses_beaten` |
| Game events and session state (1) — GDD | Hard | `RunRecord` fields, per-tick recorder call, `run_seed`, `stage_started`, ENDING/GAME_OVER |
| Input and player mapping (2) — GDD | Hard | Logical per-slot input byte per tick |
| Boss and boss parts (14) — GDD | Hard | `start_intro`, `boss_defeated`, boss list and `T_fight` |
| Wave and stage director (16) — GDD | Hard | Boss-only stage definition, `debug_tainted` |
| Scoring (8) — GDD | Hard | Score bound, int64 score |
| Accessibility options (28) — GDD | Hard | `run.assisted`, practice |
| Menus, title and plane select (22) — GDD | Hard | Screens for Online, consent, handle, Rush, Single Boss |
| Localization (27) — GDD | Soft | Strings, numerals |
| Boss power budget (15), Co-op (18), Bombs (12), Powerups (13), Plane kits (11) — GDD | Soft | Behave unchanged in boss-only stages |
| Era shift (19), HUD (20), Stage-end tally (21) — GDD | Soft | Era by boss; HUD element; tally variant |
| ADR-0001 deterministic simulation | Hard | Replay verification relies on it |

**Downstream (depend on this)**

| System | Hard/Soft | Interface |
|---|---|---|
| Menus (22) — GDD | Soft | Online tab, Rush and Single Boss entries (Menus lists 32 as a reserved tab) |
| Save (26) — GDD | Soft | Reads nothing; only the queue and cache are separate files |
| Tutorial (30) — GDD | Soft | Tutorial uses its own training boss (DrillRunner), not Single Boss; drills never upload. Tutorial answers Accessibility OQ9 by pointing practice start to Single Boss here (2026-11-03, wave 4) |

**Amendments to other docs** (applied 2026-11-03, wave 4; see `production/gdd-reports/_applied-wave-4.md`)

1. **`design/gdd/save-settings-high-scores.md`**
   - F3 and Rule 9: extend board ids with `mode`: RUSH `rush{boss_count}/solo/{plane}` and `rush{boss_count}/coop/{played}`, BOSS `boss/{boss_id}/{plane}` (1 player only). MAIN ids unchanged.
   - `RunRecord`: add `mode` (MAIN / RUSH / BOSS), `boss_ids[]`, `run_seed` (int), `run_ticks` (int), `assisted` (bool), `debug_tainted` (bool).
   - Rule 4: also reject records with `assisted` or `debug_tainted`.
   - Rule 13: add records `endings_count[plane][board_mode_key]` and `bosses_beaten` (array of boss ids); both absent = empty.
   - Rule 16 schema: add `online.enabled` (bool, false), `online.consent_version` (int, 0), `online.handle` (string, ""), `online.install_id` (string, ""), `online.auto_upload` (bool, true), `online.friend_codes` (string array, max 50), owner Online leaderboards (32).
   - Entry table: optional `online_status` (string) and `replay_ref` (string) fields.
   - Open Question 3 (replays): closed here ("recorded by `ReplayRecorder` as a sparse event log, F3; stored only in the online queue, not in `scores.json`"). Open Question 11: closed (handle 3–12 Latin chars; server denylist; replay re-sim). Open Question 12: stays (no encryption), plus "the replay is the trust anchor".
2. **`design/gdd/game-events-and-session.md`**: Run record gains the fields in Amendment 1; Session calls `ReplayRecorder.tick(inputs_by_slot)` once per tick after Input and before the sim step when `online.enabled`; Session supports a run `mode` and a stage list (RUSH/BOSS) with `stage_count` = list length; `run_seed` is stored in the record; `run_ticks` is an int counted only on non-paused ticks.
3. **`design/gdd/wave-and-stage-director.md`**: a stage definition may have `waves = []` and a `home_stage` (int); the Director then goes Warning, `Boss.start_intro(boss_id, home_stage)`, Sweep, `stage_cleared`. Dependencies row for 32. Debug tainting stays (Edge Cases, debug stage select).
4. **`design/gdd/boss-and-boss-parts.md`**: `start_intro(boss_id, stage_index)` second argument is the **home stage** (for `Q_cap` and data), not the run position; `boss_defeated` with reason KILLED or CRITICAL_BREAK is what Save counts for `bosses_beaten`.
5. **`design/gdd/menus-title-plane-select.md`**: the "Online leaderboards (32)" reserved tab becomes the Online tab (scope Global / Friends / Around me, board selector, status chip); Play menu gains **Boss Rush** and **Single Boss** (locked states with the unlock text); Consent screen, Handle entry and Delete-my-data (hold-to-confirm) are new screens; Dependencies row for 32 becomes Soft with GDD.
6. **`design/gdd/accessibility-options.md`**: Open Question 9: boss practice is Single Boss with a game-speed assist (unranked, PRACTICE); assisted runs never record for upload.
7. **`design/gdd/scoring.md`**: name the "about 31M per slot per stage" bound as `slot_stage_bound` (31,000,000) and note it is read by Online leaderboards F1; any change to it needs a ruleset bump.
8. **`design/gdd/input-and-player-mapping.md`**: provide `sim_input_byte(slot) -> int` (the logical per-tick input, 4 bits move + 3 bits buttons) as a read-only view for the recorder.
9. **`design/gdd/hud.md`** (when written): "BOSS n/N" element in RUSH. **`design/gdd/stage-end-tally.md`** (when written): RUSH tally per boss, same skip rule. **`design/gdd/localization.md`**: add key families `ui_online.*` (consent text, status lines, board labels, errors) and `ui_rush.*`; server messages are codes, never text; handles are Latin and exempt from translation.
10. **`design/gdd/systems-index.md`** row 32: Depends on `26` becomes `26, 1, 2, 8, 14, 16, 22, 28` (26 hard, others as listed above); status `**Designed** (pending review) — [GDD](online-leaderboards-boss-rush.md)`. Dependency note: Online leaderboards (32) lists Save per the Save GDD amendment 7. Progress tracker: GDDs written +1.
11. **`design/gdd/game-concept.md`** §12 Stretch row: "online leaderboards (opt-in, replay-verified; global and friends, per plane / player count) · boss rush (era-ordered, plus Single Boss)".
12. **New ADRs required:** (a) deterministic replay recording and cross-platform verification contract; (b) online service transport, adapters and the Steam GDExtension exception to GDScript-only; (c) hosting and data region (with `/security-audit`).

## Tuning Knobs

All client-side values live in `data/online_rules.tres` and `data/boss_rush.tres` (working names). Server values are server config but are listed because they shape the player experience.

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `slot_stage_bound` (Scoring) | 31,000,000 | follows Scoring | Honest scores rejected | Cheats pass | F1 |
| `min_fight_pct` | 25 | 10–40 | Impossible-fast runs pass | Real fast kills rejected | F2; Critical Break speed |
| `replay_max_bytes` | 262,144 | 131,072–524,288 | Long co-op runs dropped | Storage and bandwidth | F3 |
| `replay_max_raw_bytes` | 1,048,576 | 524,288–4,194,304 | Valid replays dropped | Decompression abuse | F3 |
| `hash_interval_ticks` | 600 | 300–1,800 | Slower verify, bigger file | Late divergence detection | F3, F4 |
| `verify_top_n` / `board_depth_max` | 100 | 25–500 | Players below rank 25 see unverified gaps | Verifier cost | F4 |
| `audit_pct` | 5 | 0–20 | Cheaters below top N unseen | Cost | F4 |
| `submit_per_hour` | 20 | 5–60 | Honest bursts blocked | Abuse | pipeline |
| `page_size` | 10 | 5–20 | Many requests | Long lists | UI, F7 |
| `around` | 2 | 1–4 | Little context | Crowded | F7 |
| `queue_max` | 10 | 3–30 | Offline runs dropped | Disk | Rule 30 |
| `backoff_base_s` / `backoff_max_s` | 30 / 3,600 | 10–120 / 600–14,400 | Request storms | Slow recovery | F6 |
| `request_timeout_s` | 10 | 5–30 | False failures | Long waits | Rule 29 |
| `cache_max_days` | 30 | 7–90 | Offline tab empty | Stale boards | Rule 31 |
| `claim_ttl_days` | 14 | 3–30 | Offline players lose runs | Old ruleset verifiers kept | Rule 24 |
| `friends_max` | 50 | 10–200 | Few friends | Fetch size | Rule 21 |
| `strike_limit` / `strike_window_days` | 5 / 30 | 3–10 / 7–90 | Honest players limited | Abusers unchecked | Rule 26 |
| `report_hide_threshold` | 5 | 3–20 | Griefing hides rows | Bad rows stay | Rule 28 |
| `replay_retention_days` | 7 | 1–30 | Cannot review | More stored data | Rule 18 |
| `inactive_purge_days` | 730 | 365–1,095 | Entries vanish | Stored long | Rule 18 |
| `erase_sla_days` | 30 | 7–30 | — | Legal risk | Rule 19 |
| `ip_hash_days` | 7 | 1–30 | Weak rate limits | More data held | Rule 17 |
| `handle_length` | 3–12 | 3–16 | Collisions | UI width | Rule 16 |
| `rush_start_drones` | 4 | 2–4 (`max_drones`) | Weaker boss damage, longer fights | — | Rule 37, Boss `T_fight` |
| `rush_refit_ticks` | 120 | 60–240 | Refit unreadable | Pacing drag | Rule 39 |
| `rush_order` | `[fortress, jet_carrier]` | era order | — | — | Rule 35 |

**Rationale:** 31M and `T_fight` come from the Scoring and Boss budget formulas. 100 deep matches the verified depth so no visible row is unverified. Backoff follows F6 so a Web tab left open sends at most 120 requests a day. 4 drones is `max_drones`: the rush removes the powerup climb, so the start is the full kit.

**Owned elsewhere:** `starting_lives`, `bomb_start`, `bomb_stage_floor`, `max_drones`, `extend_unit`, `chain_cap`, `boss_intro_ticks`, `enrage_mult`, `boss_timeout_after_enrage`, `score_store_max`, `board_size`, `initials_length`, `name_entry_seconds`, `min_ranked_score` (registry owners).

## Visual/Audio Requirements

Online screens are menus with no bullets on screen (art bible §7.8). Visuals follow the Save board style.

| Item | Spec |
|---|---|
| Board row | Rank, handle (Latin, 12 px tier), score (Gold, M tier, tabular digits), plane tile 14×14, badges `C` and `1CC` as 14×14 plated tiles, "+N" co-op tag, status tile 14×14 |
| Status tiles (plated, glyph inside, never circle, ring or needle shapes) | Verified: check glyph, Cream on Char. Pending: three-dot glyph. Not verified: dash glyph. Offline: slash glyph. Colour is never the only cue (glyph differs) |
| Own row highlight | Static Cream 3 px border plus arrow glyph; optional pulse 2 Hz or lower, 40% opacity or less; off with `access.reduce_flashing` (Save §Visual) |
| Scope and board selector | Plated tabs; focused tab uses the 3 px Cream border |
| Consent screen | One plated panel, body text S tier, two buttons (Accept, Decline) of equal size and weight (no dark pattern), a Privacy line. Bengali width reserve 40% (`bn_width_reserve_pct`) |
| Rush HUD element | "BOSS n/N" plated tile in the top HUD strip, HUD layer 11 inside the strip (HUD Rule 30c; corrected 2026-11-03, wave 4); never over the play field |
| Refit beat | `rush_refit_ticks` 120: drones dock to the plane over the boss-defeated backdrop; 12 px tiles; reduced motion keeps it static |
| Colours | Warm neutral UI palette only. No Void Indigo / Ink fills; no bullet shapes for any non-bullet |
| Audio (owned by Audio 24) | Upload-queued tick `sfx_ui_upload_tick`, verified sting (soft) `sfx_ui_upload_ok`, error tone `sfx_ui_upload_error`; none during a stage; no sound for Pending; rush refit beat `sfx_rush_refit` (IDs 2026-11-03) |

A request or cache write must not cause a visible hitch: no menu frame over 33 ms due to online code (Perf AC-44).

## UI Requirements

- **Online tab** (Menus): scope (Global / Friends / Around me), board selector (mode, run length, plane or player count, boss), status chip (Ready / Offline / Pending n), refresh.
- **Consent screen**: plain text, both languages, equal-weight Accept and Decline, link to the full policy (platform-dependent).
- **Handle entry**: keyboard text or wheel; shows the suggested Steam name.
- **Results**: "Upload" action and status of the queued claim; "Could not verify this run" line from a code.
- **Settings > Online**: on/off (off = withdraw), auto-upload, friend codes (add, remove, my code), **Delete my online data** (hold-to-confirm).
- **Play menu**: Boss Rush and Single Boss (boss picker with locked/unlocked states), unlock hint text.
- **Row actions**: Report (hold-to-confirm).
- **Notices**: offline, update required, rate limited, suspended, erased, queue full, upload dropped.

📌 **UX Flag**: run /ux-design for the Online tab, consent screen, handle entry, and the Boss Rush / Single Boss menus before writing epics.

## Acceptance Criteria

Defaults used: `slot_stage_bound` 31,000,000, `min_fight_pct` 25, `replay_max_bytes` 262,144, `replay_max_raw_bytes` 1,048,576, `hash_interval_ticks` 600, `verify_top_n` 100, `audit_pct` 5, `queue_max` 10, `backoff_base_s` 30, `backoff_max_s` 3,600, `around` 2, `page_size` 10, `rush_start_drones` 4, `rush_refit_ticks` 120, `rush_order` `[fortress, jet_carrier]`, `starting_lives` 3, `bomb_start` 3.

**Test setup:** All online logic is node-free `RefCounted` (`OnlineService`, `ReplayRecorder`, `ReplayVerifier`, `PlausibilityChecker`, `UploadQueue`, `BoardCache`) with an injected **fake adapter** (scripted responses and latency, in-memory file backend, injected clock and seeded RNG). No test touches the network or the disk. The verifier test drives the real sim headless with a recorded input list (ADR-0001 tick). Tests live in `tests/unit/test_online_*.gd`, `tests/unit/test_replay_*.gd` and `tests/unit/test_boss_rush_*.gd`, use the `extends SceneTree` style of `tests/unit/test_chain_tracker.gd`, and read numbers from `.tres`. Server-side checks are specified as black-box API tests (`[Integration]`).

### Eligibility and consent

- **AC-01 [Unit] (Rule 1):** a run is queued only when consent is true, Save ranked it, `run_ended_by` is ENDING or GAME_OVER, `assisted` and `debug_tainted` are false and a replay exists; flipping any one of the six makes `queue` unchanged (six cases).
- **AC-02 [Unit] (Rule 14):** with `online.enabled = false`, `ReplayRecorder.tick()` allocates nothing and the queue stays empty after 3 qualifying runs.
- **AC-03 [Unit] (Rule 15):** accepted `consent_version` 1, build requires 2 → state ReConsent, `submit` is a no-op and nothing is sent; after accepting 2, queued claims send.
- **AC-04 [Unit] (Rule 19):** `delete_my_data()` called → on `ERASED` the install id is empty, `online.enabled` is false, the queue and replays are deleted and local `scores.json` entries are unchanged.
- **AC-05 [Unit] (Rule 16):** handles `"AB"` and 13 chars are rejected; `"Kaz_01"` accepted; `"K@z"` rejected at input; a Steam name `"Kāz★12"` becomes `"Kz12"`; an all-disallowed name gives an empty suggestion.
- **AC-06 [Manual] (Rule 14):** the consent screen shows in English and Bengali; Accept and Decline have the same size, weight and focus order position rules; no Bengali clipping at 17 px S tier. Evidence: screenshots + review by the localization owner.

### Recording and replay format

- **AC-07 [Unit] (Rule 22):** a recorded 3,600-tick, 1-slot run with 450 input changes round-trips through encode and decode to the same per-tick input list; the file contains the header fields listed, the footer outcome and 6 checkpoints (ticks 600, 1,200, … 3,600).
- **AC-08 [Unit] (Rule 22):** Input options `tap_assist` on and off produce different logged byte streams for the same raw device taps, and each stream replays to its own result (the log is post-Input).
- **AC-09 [Unit] (F3):** the example numbers hold: 9,000 changes → `raw` 27,256; 4 slots × 36,000 changes → `raw` 432,256; a stream with `raw` 1,048,577 is refused; `sent` above 262,144 is refused (using a fixture with a fixed `z`).
- **AC-10 [Unit] (Rule 22):** run events `join`, `continue_accept` and `slot_forfeit` are recorded with the tick; replaying a run with a drop-in at tick 1,200 and a continue at tick 2,400 reproduces slot states exactly.
- **AC-11 [Unit] (determinism):** `ReplayVerifier` run twice on the same replay produces the same per-slot scores and the same 6 checkpoint hashes; run with the record built from a live headless run, the footer matches.
- **AC-12 [Unit] (Rule 23):** flipping one input byte at tick 900 in a 3,600-tick replay changes the checkpoint hash at tick 1,200 or earlier (stop tick reported as the first mismatch).
- **AC-13 [Unit] (edge):** a replay whose header names `ruleset` 99 is refused with `UPDATE_REQUIRED`; a corrupted magic is refused with `NOT_VERIFIED`; no path-like string in the header is ever opened (the file backend records zero reads for such strings).
- **AC-14 [Integration] (Rule 23):** cross-platform: a replay recorded on Windows desktop re-simulates on Linux headless and on a Web export with identical checkpoint hashes for 5 replays (2 stages, 1P Lancer, 1P Leech, 2P, Boss Rush). **This is the gate for the feature (Open Question 1).**

### Plausibility and verification

- **AC-15 [Unit] (F1):** RUSH 2 bosses, 3 slots: 186,000,000 passes, 186,000,001 fails; 2 slots × 2 stages with slot scores 70,000,000 / 1,000,000 fails the slot check; BOSS solo 31,000,000 passes, 31,000,001 fails.
- **AC-16 [Unit] (F2):** Fortress `boss_min_ticks` 915, Jet Carrier 1,061, RUSH total 1,976; a claim of 1,975 ticks with ENDING fails, 1,976 passes; a GAME_OVER claim of 1,000 ticks is not checked against F2.
- **AC-17 [Unit] (Rule 24):** a claim with `max_chain` 1,000, a slot count over 4, `stage_reached` greater than `stage_count`, or ENDING with `stage_reached` less than `stage_count` is `NOT_VERIFIED`.
- **AC-18 [Unit] (Rule 24):** a duplicate replay hash from a second install is `NOT_VERIFIED`; the first remains.
- **AC-19 [Integration] (Rule 24):** a claim with score +1 over the replay result is `NOT_VERIFIED` and not published; the exact claim is `VERIFIED` and published; a claim outside rank 100 and not audited stays `PENDING` and invisible.
- **AC-20 [Integration] (Rule 24):** a pending claim whose rank moves into the top 100 after another entry drops is queued for verification within `pending_recheck_minutes` (15).
- **AC-21 [Integration] (Rule 24, F4):** 1,000 random claims with `audit_pct` 5 audit between 3% and 7% of those outside the top 100 (seeded).
- **AC-22 [Unit] (F4):** the example: 2,000/day, `p_top` 0.30, 72,000 ticks at 1.5 ms → `p_verify` 0.335, 670 verifications, 20.1 core-hours (rounded to 0.1).
- **AC-23 [Integration] (Rule 26):** 5 `NOT_VERIFIED` in 30 days limits the install to 2 submissions/day; no message mentions strikes.
- **AC-24 [Integration] (Rule 24):** a decompression bomb (1 KB to 100 MB) is stopped at 1,048,576 bytes and rejected in under 1 s.
- **AC-25 [Integration] (Rule 25):** every server answer is one of the eight codes; the client maps each to a localization key present in both `en` and `bn`.

### Boards

- **AC-26 [Unit] (Rule 8, F5):** keys: `r1/rush2/solo/leech`, `r1/boss/fortress/lancer`, `r2/2s/coop/3`; changing `ruleset` changes the key; the Save MAIN id is unchanged.
- **AC-27 [Unit] (Rule 11):** two entries with equal score: the earlier verified ranks higher.
- **AC-28 [Integration] (Rule 10):** a player with three verified runs on one board appears once with the best; Friends shows self plus added friends only; a friend who deleted data disappears on the next fetch.
- **AC-29 [Unit] (F7):** rank 57/312 → 55–59; rank 1/312 → 1–5; rank 311/312 → 308–312; total 3 rank 2 → 1–3.
- **AC-30 [Unit] (F5):** `steam_score` for 124,000,000 is 124,000,000; for 2,200,000,000 (synthetic) is 2,147,483,647.
- **AC-31 [Unit] (Rule 12):** a 3-slot team entry shows the submitter's handle with "+2" and one row.
- **AC-32 [Integration] (Rule 21):** a friend code added is one-way: A adds B's code, A sees B, B does not see A until B adds A's code.

### Offline and queue

- **AC-33 [Unit] (F6):** backoff delays for attempts 0..8 with jitter fixed at 100%: 30, 60, 120, 240, 480, 960, 1,920, 3,600, 3,600; with jitter bounds, attempt 3 stays within 192–288.
- **AC-34 [Unit] (Rule 30):** 11 claims queued → the lowest score is dropped, the queue has 10; a failed upload keeps the claim; a duplicate send after a timeout produces one entry (server dedupe by replay hash, black-box).
- **AC-35 [Unit] (Rule 31):** offline, a cached board returns with age text; a cache older than 30 days is discarded; the Online tab never errors.
- **AC-36 [Integration] (Rule 29):** with the fake adapter returning no response, Results, Play again and the Title all respond within one frame of input; the queue holds the claim; after the adapter recovers the claim uploads on its own.
- **AC-37 [Unit] (Rule 32):** zero queue or cache file writes during Stage and Tally; first write at Results confirm.
- **AC-38 [Unit] (edge):** a damaged `online_queue.json` is set aside, an empty queue starts, `scores.json` is byte-identical before and after.

### Boss Rush

- **AC-39 [Unit] (Rule 35–36):** the stage list for `rush_order` `[fortress, jet_carrier]` has 2 stages, `waves = []`, `home_stage` 1 and 2, set id `rush2`; Boss receives `start_intro("jet_carrier", 2)` at rush position 2 and `Q_cap` 23 (`13 + 5 × 2`).
- **AC-40 [Unit] (Rule 37–38):** at rush start each player has 3 lives, 3 bombs, 4 drones, chain 0; at boss 2's `stage_started` a player with 1 bomb and 0 drones has 3 bombs and 4 drones and unchanged lives (e.g. 2).
- **AC-41 [Unit] (Rule 38):** a player who dies during boss 1 respawns with 0 drones and still has 0 drones until boss 2's refit.
- **AC-42 [Unit] (Rule 40):** a scripted rush gives the same boss kill value (100,000) and stage-end bonuses (clear 100,000, no_death 200,000 if no death) per boss as the main game, and no small-enemy or item income.
- **AC-43 [Unit] (Rule 43):** only a 1-slot BOSS run ranks on `boss/fortress/lancer`; a 2-slot BOSS run returns not ranked; a RUSH run never writes a `boss/…` board.
- **AC-44 [Unit] (Rule 44):** `endings_count` 0 → Boss Rush locked; one ENDING (with continues) → unlocked; `bosses_beaten` gains `fortress` on KILLED or CRITICAL_BREAK and not on TIMEOUT; with Save absent both unlocked.
- **AC-45 [Integration] (Rule 41):** a 2P rush with a continue at boss 2: the continuing slot restarts at 0 score, the entry has `C`, board `rush2/coop/2`, no 1CC; a no-continue, all-start 1P rush that ends ENDING has 1CC.
- **AC-46 [Unit] (Rule 45):** Single Boss with game speed 90 sets `run.assisted`, shows PRACTICE, does not rank and does not queue an upload.
- **AC-47 [Manual] (Rule 36, Rule 39):** play a full 2-boss rush: the Warning screen appears before each boss, the tally shows per boss, the refit beat lasts about 2 s, HUD shows BOSS 1/2 then 2/2. Evidence: video.

### Platform, perf, determinism

- **AC-48 [Perf] (Rule 22):** `ReplayRecorder.tick()` takes at most 20 µs median and allocates nothing in steady state (4 slots); online `poll()` at most 0.2 ms per frame; no menu frame over 33 ms during queue, cache or request completion on REF-WEB.
- **AC-49 [Manual] (Rule 6):** Web export on REF-WEB (Chrome, itch.io iframe): submit, view board, status tile changes after verification; blocked storage or blocked CORS shows the one-line unavailable notice and play continues. **Verifies the CORS and iframe assumptions.**
- **AC-50 [Manual] (Rule 6, Steam):** Steam build: identity by ticket works, Friends reads the Steam friends list, no extra account step appears.
- **AC-51 [Unit] (determinism):** the same record, replay and fake-adapter script applied twice gives byte-identical queue and cache files given an injected clock and RNG.
- **AC-52 [Manual] (Rule 16, art bible §7.5):** handles show correctly in both languages; digits follow the language script on the fixed grid; no layout shift on language switch.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Cross-platform determinism.** Does the sim give bit-identical results on Windows, Linux, Web (wasm) and later ARM? Floats and transcendental functions are the risk. Spike: AC-14. If it fails: same-platform verification and an `UNVERIFIED` tab, or quantise more of the sim. | technical-director / lead-programmer | Before committing the feature (ADR) |
| 2 | Verifier hosting, region, cost, and a legal review: GDPR lawful basis and processor terms, privacy policy, minimum age (COPPA / UK Children's Code), data export on request, Steamworks requirements. | producer / legal / `/security-audit` | Before any server work |
| 3 | Drone loss in the rush: with 0 drones after a death and no powerups, is the rest of that boss too slow? Options: keep as is (locked rule), or a one-off refit pod after each part kill. Playtest. | game-designer | Rush prototype |
| 4 | Set `min_fight_pct` from the fastest dev Critical Break kill per boss; measure `ms_per_tick` headless and `z`. | qa-lead / gameplay-programmer | Verifier prototype |
| 5 | Unlock reads the new `endings_count` record; players with old saves get it after their next clear. Also unlock on the existing `cleared` entries on boards? | game-designer | Vertical Slice |
| 6 | Local "watch my replay" screen and sharing replays (file or code)? Free once recording exists. | producer | Post-launch |
| 7 | Attract mode demo (Menus Open Question 1) can play a recorded replay; share the same format? | Menus (22) | After Vertical Slice |
| 8 | ~~Steam Leaderboards mirror: worth the GDExtension (needs an ADR) or Steam-ticket identity only?~~ **Closed 2026-11-03 (ADR-0007):** no client Steam mirror; GodotSteam only for identity / ticket / friends. | technical-director | Done |
| 9 | Tool-assisted and bot input logs verify fine. Accept with reports and manual review, or add input-statistics heuristics (frame-perfect streaks)? | game-designer / producer | After first month live |
| 10 | Ruleset policy: a balance patch bumps `ruleset` and resets boards. Keep an archive tab of older rulesets? | producer | Before launch |
| 11 | Co-op online rows show the submitter only. Add the team's other handles (needs their consent)? | game-designer | After launch |
| 12 | Are Rush lives enough? Consider a bonus life after a no-death boss. | game-designer | Rush playtest |
| 13 | ~~Is `HTTPRequest` TLS root-certificate handling on desktop and Web in Godot 4.7 as expected?~~ **Closed 2026-11-03:** moved to ADR-0007 Validation V1 (verification spike). | godot-specialist | ADR-0007 V1 |
| 14 | Does Godot 4.7 `PackedByteArray.compress` support Zstandard on all export targets including Web? **Unverified.** Fallback: Deflate. | godot-specialist | Before the replay format is frozen |

> Decided under auto-approve (2026-11-03): verifier-authoritative design with platform adapters; opt-in consent; erase on request; Latin handles; ruleset-keyed boards; sparse replay format capped at 256 KiB; top-100 verification plus 5% audit; Boss Rush as boss-only stages with a full-kit refit per boss; Single Boss feeds per-boss boards; unlock on the first ending.
