# Game Events and Session State

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: user + Claude
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (UX amendments wave 5)**: Session publishes `continue_total` (the active Continue countdown length in seconds, resolved from `access.continue_timer`, nullable) beside `continue_remaining`, so the HUD can draw the EXTENDED and UNTIMED drain bars (HUD GDD HF2, Rule 34a(c)).
> **Implements Pillar**: Every Hit Counts (indirect — carries score, chain records and lives across a run)

## Overview

Game Events and Session State is MorutJan's foundation for **who is playing, where they are in the run, and how systems hear about things they don't own**. It has two parts.

**Session state** holds one *run*: one credit from title to ending or game over. It records which players have joined (1–4), the plane each one chose, the current stage and era, and each player's score, lives, continues, max chain and Critical Breaks. It survives scene changes between stages, and it is the single source of truth that the HUD, stage tally, high-score table and save system read from.

**Game events** is a global signal bus for one-way announcements, where the sender should not need to know who is listening (screen flash, popups, Critical Break landed, stage cleared, player died). Gameplay rules still talk through direct references and local signals. The bus is for presentation and for cross-scene facts.

Players never see this system. They feel it when their score and lives carry from 1941 into the 1970s, when a co-op partner drops in with a fresh plane, and when the tally shows the chain they built three stages ago. Without it, every stage would be an isolated level, and the one-credit run at the heart of score chasing would not exist.

> Implementation note (→ ADR, not GDD): whether this stays two autoloads (`GameEvents`, `GameSession`) or splits into a separate run-flow controller is an architecture decision.

## Player Fantasy

**Indirect: players feel what this system makes possible.**

The fantasy it serves belongs to the run: *one credit, four eras, one unbroken record of how well you flew.* The player should feel that **nothing they earned is lost between stages**. The score from 1941 is still on the HUD over the 1970s jets, the life they saved is still in reserve, and the 187-hit chain from the first boss is waiting on the final tally. In co-op, a friend who grabs a pad mid-run joins *this* run, not a new game.

It serves **Every Hit Counts**: *"The chain is the game; every system feeds or threatens the hit counter."* A chain record that resets between stages, or a score that doesn't survive a scene change, would make hits stop counting.

**The test of success is that the player never notices this system.** If they do, something broke: a lost score, a wrong plane after a stage transition, or a co-op player with the wrong lives.

> `creative-director` not consulted for this section (lean mode).

## Detailed Design

### Core Rules

**The run**

1. A **run** starts when the **Lobby commits** (every joined slot Locked and `start_delay_ticks` (45) elapsed): Menus (22) calls `start_run(selections, mode, stage_list)` once (`mode` MAIN and the main stage list by default; Online leaderboards (32) passes RUSH / BOSS lists; signature (decided under auto-approve 2026-11-03, consistency check)) with the locked slots in slot order, each `joined_at_run_start = true`. Pre-run lobby slots live in Menus' `LobbyModel`; **Selecting** stays the mid-run drop-in state. Quit to title calls `abandon_run()` (`run_ended_by = ABANDONED`, Save not called). *(Amended 2026-11-03, Menus (22) Rules 23, 29.)* It ends at **game over** (no player active and no continue taken) or at **ending** (the last stage's boss is defeated; `run_ended_by = ENDING` is set at `boss_defeated`, the last stage still gets its Stage-end tally (21), and `run_ended` fires and the `RunRecord` is built when that tally is Done; amended 2026-11-03, Stage-end tally (21)). MVP has 2 stages; Target has 4.
   - *Run kind and mode (wave 4, 2026-11-03).* The session holds `run_kind` (`RUN` default, `DRILL`) and `mode` (`MAIN` default, `RUSH`, `BOSS`) plus the run's ordered **stage list**; `stage_count` = length of that list. **Drills** ([Tutorial (30)](tutorial.md)): `start_school(selections)` starts a `DRILL` run; while `DRILL`, `preview_rank` / `submit_run` are never called, there is no Results, Tally or continue, and the run ends with `run_ended_by = DRILL_END`; drills may write `drone_count` and `bombs`. **Boss Rush / Single Boss** ([Online leaderboards, boss rush (32)](online-leaderboards-boss-rush.md)): `start_run(selections, mode, stage_list)` where each rush entry is a boss-only stage (`waves = []`, `home_stage`); Session continue and co-op rules are unchanged.
   - *Replay recording (wave 4, Online leaderboards (32)).* When `online.enabled`, Session calls `ReplayRecorder.tick(inputs_by_slot)` once per tick after Input (ADR-0001 step 1), using Input's `sim_input_byte(slot)`. `run_ticks` counts non-paused ticks.
2. Only one run exists at a time. Session state is created at run start and cleared on return to title. The session **calls `SaveStore.preview_rank(record)` when Results opens (read-only) and `SaveStore.submit_run(record, initials)` on Results confirm, both before the clear**, so saving never depends on an event being heard. Not called for ABANDONED. *(Amended 2026-11-03, Save (26).)* `run_ended` is announced for presentation only.
3. The run stores: `stage_index` (0-based), `era` (from the stage definition), `run_time`, and up to 4 **player slots**. **Game time** *(amended 2026-11-03, ADR-0002/0003)*: `run_time` is `run_ticks` (completed game ticks; seconds = ticks / 60 for display only) and every session timer (continue countdown, respawn delay) counts game ticks, never frame deltas; the session is not ticked while the game is paused, so all of them stop during pause.

**Player slots** (fixed slots 1–4, one per input device; matches InputSetup `p1_`–`p4_`)

4. Each slot stores: `state`, `plane`, `drone_count` (0–4), `score`, `lives`, `continues_used`, `extends_awarded`, `max_chain_per_boss` (one entry per boss fought), `critical_breaks`, `life_bonus_total`, `pre_continue_score_total` (display only), `is_1cc` (true until the first continue), `joined_at_run_start` (bool, used by F7; added 2026-11-03, Save (26)), `bombs` (0–5; stored here so it survives scene changes, written **only** by Bombs (12) through `set_bombs(slot, n)`; set to `bomb_start` (3) at run start, continue and drop-in, and reset to 3 on death; Bombs Rules 2–3; added 2026-11-03).
5. **Lives are per player.** A slot starts with `starting_lives` (tuning knob). Extends (score thresholds or 1-up drops) add lives, up to `max_lives`.
6. **Continue:** when a slot reaches 0 lives it enters *Continue* and a countdown starts. If the player accepts, the wiped score is added to `pre_continue_score_total`, then `score = 0`, `critical_breaks = 0`, `life_bonus_total = 0`, `extends_awarded = 0`, `continues_used += 1`, `is_1cc = false`, lives refill to `starting_lives`, `bombs` is set to `bomb_start` by Bombs (12), and they respawn (with 0 drones, already lost at death). `max_chain_per_boss` is kept. The plane can't be changed. If the countdown expires, the slot goes *Inactive*.
7. **Drop-in:** pressing start on a free pad during a stage or tally opens an in-place plane pick. The game does not pause. The slot is in the **Selecting** state, which Collision (6) treats as non-hittable (no plane exists yet). They spawn with `starting_lives`, `bomb_start` bombs (Bombs 12), `score = 0`, and are marked `is_1cc = false`, since they didn't play from stage 1. Drop-in runs are ranked on the co-op board with no 1CC badge (Save (26) Rules 6–7). Which slot a Start press takes is Input (2) F7. The drop-in pick auto-cancels after `dropin_pick_ticks` (900) and the slot returns to its previous state (Menus (22) Rule 26; added 2026-11-03).
8. **Drop-out:** there is no explicit leave. A slot that lets its continue expire becomes *Inactive* and can drop in again later as a new entry (score 0, 0 drones). `continues_used` is kept, so the run record stays honest.
9. **Stage carry-over:** score, lives, continues, records and plane carry to the next stage. **Drones (`drone_count`) carry over too.** Chain counters do **not**: chains drop when the tally starts (Chain tracker Rule 10). **Death resets `drone_count` to 0** (see F1). *(Added 2026-11-03.)* **`bombs` carries too**; `stage_started` tops it up to `bomb_stage_floor` (3) and never lowers it (Bombs 12). At `stage_cleared` deployed drones snap home to their wing slots and the drone cooldown becomes 0; the Lancer meter and `drone_count` carry (Plane kits 11 Rule 13). At `stage_started` the session stores, per slot, `critical_breaks` and `len(max_chain_per_boss)` as stage-start marks so the Stage-end tally (21) can show this stage's values *(added 2026-11-03, Stage-end tally 21)*.
10. **Game over** happens when no slot is *Alive*, *Dead* or *Continue* (i.e. every slot is *Inactive*, *Empty* or *Selecting*). A *Selecting* slot does not keep the run alive: its join is cancelled and it returns to its previous state. The run ends and the results screen shows each slot that played.

**Run record** *(added 2026-11-03, Save (26))*

The session builds one immutable `RunRecord` at run end and passes it to Save (Rule 2). Fields (Save GDD `RunRecord` table):

| Field | Type | Source |
|---|---|---|
| `run_ended_by` | enum ENDING / GAME_OVER | F7 |
| `debug_tainted` | bool | set by Director (16) debug stage select / wave skip; Save never ranks a tainted run (Save Rule 5; added 2026-11-03, wave 3a) |
| `stage_count` | int | stage definitions (2 MVP, 4 Target) |
| `stage_reached` | int | `stage_index + 1` at run end |
| `run_time` | float s | Rule 3 |
| `mode` | enum MAIN / RUSH / BOSS | Rule 1 (wave 4, Online leaderboards (32)) |
| `boss_ids[]` | string[] | RUSH/BOSS stage list (wave 4) |
| `run_seed` | int | run seed (wave 4) |
| `run_ticks` | int | non-paused ticks (wave 4) |
| `assisted` | bool | `run.assisted` latch (Accessibility 28); never ranked or uploaded (wave 4) |
| `touch` | bool | solo run with TOUCH bound, selects the `/touch` board (Touch controls (31), wave 4; (decided under auto-approve 2026-11-03, consistency check)) |
| `slots[]` | up to 4, played slots only (not Empty, includes Inactive), in slot order | Rule 4 |
| per slot | `slot`, `plane` (string id: `lancer`, `leech`, `sentry`, `breaker`), `score`, `continues_used`, `max_chain_per_boss` (int[]), `critical_breaks`, `life_bonus_total`, `pre_continue_score_total`, `is_1cc`, `joined_at_run_start`, `final_state` (Alive/Dead/Continue/Inactive) | Rule 4, F7 |

Save recomputes `one_credit_clear` from these fields (F7); it never trusts a stored flag.

**Game events bus**

11. The bus is for one-way announcements only. Rules that need a reply or ordering use direct references or local signals (existing rule in `game_events.gd`).
12. Every signal passes the slot index (0–3), not a node reference, for anything about a player. This lets listeners survive scene changes and player respawns.
13. MVP signal set (grows with each GDD): ~~`screen_flash_requested`~~, ~~`popup_requested`~~ (both deprecated 2026-11-03, see wave 3b block), `critical_break_landed`, `player_died`, `player_continued`, `player_joined`, `player_slot_inactive`, `extend_awarded`, `stage_started`, `stage_cleared`, `boss_defeated(reason, killer_slot)` (reason KILLED / CRITICAL_BREAK / TIMEOUT), `run_ended`. Added 2026-11-03: `coop_count_changed(old, new)` (published by Co-op (18)); presentation signals from Enemy (10): `enemy_destroyed(id, def_id, kill_class, pos, killer_slot, carrier)`, `enemy_escaped(id, def_id, carrier)`, `enemy_damage_state`, `enemy_plating_ended`, `enemy_tell(id, ticks)`. Added 2026-11-03 (Bombs 12, Boss 14, Boss power budget 15): `bomb_used(slot)`; `boss_intro_started(boss_id)`, `boss_started`, `boss_part_destroyed(part_id, pos, slot, last)`, `boss_core_exposed`, `boss_phase_changed(phase)`, `boss_critical_started`, `boss_critical_window_closed`, `boss_enraged`, `boss_gone`; **`boss_defeated` becomes `boss_defeated(reason, killer_slot)`** with `reason` ∈ KILLED, CRITICAL_BREAK, TIMEOUT. A TIMEOUT (the boss withdraws after its enrage, Boss Rule 33) still drives the normal stage-clear or ending flow, so no new Session path exists; on the final stage it ends the run with the ending. Optional: `mechanic_previewed(boss_id, mechanic_id, wave)` (Boss power budget 15, presentation only).

    **Signals added 2026-11-03 (wave 3a; Critical Break 17, Wave director 16, Stage-end tally 21, Menus 22, HUD 20):**
    - *Critical Break (17):* `critical_break_landed(slot, before, after, raw, core_pos, breaks_on_run)` **replaces** the prototype's `critical_break_landed(player, final_chain, life_bonus)`; new `critical_break_missed(slot, reason)` (NO_CHARGE / NOT_ON_CORE), `critical_break_expired(reason)` (KILLED / TIMEOUT). CB writes no Session counters; Scoring (8) writes `critical_breaks` and `life_bonus_total`.
    - *Wave and stage director (16):* `stage_started(stage_index, era)` (emitted by the Director after `era_ready`), `stage_cleared(stage_index)` (= max(`boss_gone`, `boss_defeated` + 90), watchdog `boss_defeated` + 360), `wave_started(stage, wave, total)`, `wave_ended(stage, wave, early)`, `warning_started(ticks)`, `scroll_changed(v_x100)`, `stage_cue(cue_id, transition)`, `era_ready(era_id)`; `mechanic_previewed(boss_id, mechanic_id, wave)` is now emitted by the Director (no longer optional).
    - *Stage-end tally (21):* `tally_started`, `tally_row_revealed(slot, line)`, `tally_extend_shown(slot, n)`, `tally_settled(slot)`, `tally_new_best(slot)`, `tally_exit(stage_index, from_era, to_era)`, `tally_finished(stage_index, next)`.
    - *Menus (22):* no bus signals; direct calls `start_run(selections, mode, stage_list)` and `abandon_run()` on the session (Rule 1).
    - *HUD (20):* no bus signals; reads only. `boss_defeated` stays Boss (14)'s signal, not the Director's.

    **Signals added 2026-11-03 (wave 3b; Audio 24, VFX 25, Era shift 19, Parallax 23, Accessibility 28):**
    - *Deprecated:* `screen_flash_requested` (the only flash is the Critical Break frame, driven by `critical_break_landed`; VFX 25 screen policy) and `popup_requested` (removed). Programmer task: remove the prototype `screen_flash_requested.emit(...)` calls in `src/gameplay/player/player.gd` and `src/gameplay/boss/boss.gd` and the `PopupLayer` use when VFX is implemented.
    - *Era shift (19):* `era_swap_committed(era_index)` (tick 90 of the transition, behind the era card), `era_ready(era_id)` (at transition release, **before** Tally Done), `era_load_late(era_id, ticks)`, `era_failed(era_id)`.
    - *Collision (6) for VFX (25):* `hit_feedback(target_id, result, pos, tick)` (presentation only).
    - *Presentation listeners, provisional (Audio 24):* `run_state_changed(state)`, `pause_changed(paused)`; Audio also listens to `warning_started` (Director) and `tally_started` / `tally_row_revealed` / `tally_new_best` / `tally_finished` (Tally). The proposed `tally_hero_landed` is not added: Audio plays the hero sound on the max-chain `tally_row_revealed`. Audio (24) and VFX (25) are listeners only.
    - *Director → Tally (16, 21):* at `stage_cleared` the Director supplies `is_last_stage` and `next_era` (from Era shift `era_for_stage`) to the Tally.

    **Session additions 2026-11-03 (wave 3b; Accessibility 28, Era shift 19):**
    - **`run.assisted`** (bool per run, owned by Session): false at `run_started`; latches true on the first tick any `ASSIST` option is in effect (Accessibility Rule 23) and never clears. An assisted run is PRACTICE: `submit_run` returns "not ranked", `one_credit_clear` is false, no NEW BEST, no name entry.
    - **Game-speed gate** (Accessibility F2): on each 60 Hz physics step `acc += access.game_speed_pct`; a game tick runs only when `acc >= 100` (then `acc -= 100`). Game ticks are identical, so determinism holds; inputs pressed on a skipped step latch to the next game tick (Input 2).
    - **Continue timer override:** `access.continue_timer` STANDARD uses `continue_seconds` (10 s = 600 ticks); EXTENDED 1800 ticks; UNTIMED never expires. The locked `continue_seconds` is unchanged. Session publishes the **resolved** length as **`continue_total`** (seconds, nullable) so the UI never has to resolve the override itself: 10 under STANDARD, 30 under EXTENDED, 30 under UNTIMED **while another slot is Alive** (the countdown is shown for the waiting team-mate but never expires), and `null` under UNTIMED when no other slot is Alive (no countdown and no drain bar; HUD Rule 34a(c), Accessibility 28 Rule 22).
    - **Era:** Session waits for `era_ready` before `run_started` completes and before `stage_index + 1` is used. On `era_failed` Session ends the run unranked. A blocking load discards accumulated logic ticks (→ ADR needed).

### States and Transitions

**Run flow**

| State | Enters from | Leaves to | Trigger |
|---|---|---|---|
| Title | boot, Results | Plane select | start pressed |
| Plane select | Title | Stage | Lobby commits: every joined slot Locked, `start_delay_ticks` elapsed (Menus 22) |
| Stage | Plane select, Tally | Tally / Results | `stage_cleared` (Director 16, after the item sweep) → Tally / game over → Results |
| Tally | Stage | Stage (next) / Results | `tally_finished`; the last stage also has a tally, then → Results (ending) |
| Paused | Stage | Stage / Title | pause / resume / quit |
| Results | Stage, Tally | Title | confirm (records saved first) |

**Player slot**

| State | Meaning | → Next |
|---|---|---|
| Empty | no one ever joined | Selecting (start on free pad) |
| Selecting | picking plane | Alive |
| Alive | flying | Dead (hit) |
| Dead | respawn delay | Alive (lives > 0) / Continue (lives = 0) |
| Continue | countdown | Alive (accept) / Inactive (timeout) |
| Inactive | out; record kept | Selecting (drop in again) |

Alive, Dead, Continue or Selecting → **Inactive** on `forfeit_slot(slot)` (Input (2) "Drop player" after a pad disconnect): record kept, `player_slot_inactive(slot)` fires; the Rule 10 game-over check then runs. *(Added 2026-11-03, Input (2).)*

### Interactions with Other Systems

| System | Reads from session | Writes to session | Events |
|---|---|---|---|
| Input (2) | slot states; slot ↔ device mapping | `forfeit_slot`, join request | — |
| Player plane (5) and Plane kits (11) | slot plane, lives, `drone_count` | death (→ `drone_count = 0`) | emits `player_died` |
| Collision and lives (6) | lives | lives −1 | — |
| Scoring (8) | — | score only (via session); supplies `extend_unit` | — |
| Session itself | score | lives (extend check F2/F3) | `extend_awarded` |
| Powerups and drops (13) — GDD | slot state, `drone_count`, `lives`, `N`, `run_seed`, `stage_index` | `add_powerup(slot) -> int` (`drone_count` +1, F1), `add_oneup(slot) -> int` (gained; `lives` +1 up to `max_lives`, gained 0 at the cap fires `extend_awarded(gained = 0)`) | — |
| Bombs (12) — GDD | slot states, `bombs`, `stage_started`, `stage_cleared`, `player_died`, continue and drop-in | `set_bombs(slot, n)` (only writer of `bombs`) | `bomb_used(slot)` |
| Boss and boss parts (14) — GDD | slot states (`N` at `boss_started`) | — | boss events (Rule 13), including `boss_defeated(reason, killer_slot)` |
| Chain (7) | — | max chain per boss | — |
| Critical Break (17) — [GDD](critical-break.md) | slot states | — (Scoring (8) writes `critical_breaks` and `life_bonus_total`) | `critical_break_landed`, `critical_break_missed`, `critical_break_expired` (Rule 13) |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | stage_index, era, slot states (stage clock stops while no slot is Active) | stage cleared | `stage_started(stage_index, era)`, `stage_cleared(stage_index)`, wave/warning/scroll/cue events (Rule 13); `boss_defeated` comes from Boss (14) |
| Co-op (18) | slot states (owns `N`) | — | `player_joined`; publishes `coop_count_changed` |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | `stage_index`, `tally_exit` | — | `era_swap_committed`, `era_ready`, `era_load_late`, `era_failed` (Rule 13) |
| Accessibility (28) — [GDD](accessibility-options.md) | settings | `run.assisted` latch (via Session), game-speed gate, `continue_timer` | — |
| HUD (20) — [GDD](hud.md), Stage-end tally (21) — [GDD](stage-end-tally.md) | everything (read-only); the tally snapshots each slot at `stage_cleared` | — (the tally pays S8 through Scoring `pay_stage_end_line(slot, line)`) | HUD listens; the tally emits `tally_*` (Rule 13) |
| Menus (22) — [GDD](menus-title-plane-select.md) | slots, `RunRecord`, `run_ended_by`, aggregates (F6) | `start_run(selections, mode, stage_list)`, `abandon_run()`, drop-in plane choice | — |
| Save and high scores (26) | `RunRecord` (session calls `preview_rank` on Results open, `submit_run` on confirm, before clearing) | — | `run_ended` (presentation only) |

| Tutorial (30) — [GDD](tutorial.md) | slot states, `run_kind` | `run_kind`, `start_school(selections)`, `drone_count` / `bombs` writes in drills | `drill_*` presentation events (Tutorial) |
| Touch controls (31) — [GDD](touch-controls.md) | session state (Playing or not) | — (binds TOUCH to slot 0 through Input (2)) | — |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | `RunRecord` (incl. `mode`, `run_seed`, `run_ticks`, `assisted`) | `start_run(selections, mode, stage_list)` for RUSH / BOSS | — |

Every listed system now has a GDD; interfaces follow those GDDs (updated 2026-11-03, wave 4).

> Specialist agents not consulted for this section (lean mode).

## Formulas

**F1. Drone count**

`drone_count_after = min(max_drones, drone_count + powerups_collected)`; on death `drone_count = 0`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Drone count | `drone_count` | int | 0–4 | Slot's current drones. Carries across stages. |
| Powerups collected | `powerups_collected` | int | 0–4 per frame | Powerup pickups this frame (drop rate owned by Powerups). With `N = 4` up to 4 pods can arrive on one tick (one per player per carrier drop, Powerups (13)); was 0–2, amended 2026-11-03. |
| Max drones | `max_drones` | int | 4 (locked by design) | Cap. |

**Output Range:** 0–4. A pickup at 4 has no drone effect (what it gives instead is an open question for Powerups).
**Example:** 1 drone + 1 pickup → 2. 4 + 1 → 4. Dying with 3 → 0. Clearing stage 1 with 2 → stage 2 starts with 2.

**F2. Extend threshold**

`extend_threshold(n) = extend_unit × (extend_first_mult + n × extend_step_mult)`
`extends_reached = count of n in 0 … max_score_extends − 1 where score >= extend_threshold(n)`
`extends_due = max(0, extends_reached − extends_awarded)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Slot score | `score` | int | ≥ 0 | Current score of the slot. |
| Score unit | `extend_unit` | int | > 0 | Par score of one clean stage, **supplied by Scoring**: 3,000,000 (Scoring F7). Examples and tests below still use 1,000,000 as a test parameter read from the resource. |
| First multiplier | `extend_first_mult` | float | 0.3–2.0 (default 0.8) | First extend lands at this many units. |
| Step multiplier | `extend_step_mult` | float | 0.5–3.0 (default 1.0), > 0 | Gap between extends, in units. |
| Score extend cap | `max_score_extends` | int | 0–4 (default 2) | Max score extends per entry. |
| Extends awarded | `extends_awarded` | int | 0–cap | Already paid out. Resets to 0 on continue and drop-in. |

**Integer rule:** thresholds are computed once as whole numbers, `round(extend_unit × (extend_first_mult + n × extend_step_mult))`, and compared with `score >= threshold` — never with float division — so exact boundary scores (800,000) always pay.

**Output Range:** 0 to `max_score_extends`. Evaluated after every score add, so one jump (e.g. a Critical Break) can cross several thresholds. An extend is consumed even if F3 discards it at the cap.
**Example:** unit 1,000,000 → thresholds 800,000 and 1,800,000. Score jumps 700,000 → 1,900,000 with 0 awarded: 1,900,000 ≥ 800,000 and ≥ 1,800,000 → `extends_reached` = 2 → **2 extends**.
**Rationale:** Cave/Capcom shmups give 1–2 score extends per credit, early then sparse. Retune the multipliers once Scoring defines `extend_unit`; at 4 stages consider `max_score_extends = 3`.

**F3. Lives clamp**

`lives_after = min(max_lives, lives + extends_due + oneups_collected)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current lives | `lives` | int | 0–`max_lives` | Lives before the award. |
| 1-ups collected | `oneups_collected` | int | 0–2 per frame | 1-up drops this frame (rate owned by Powerups). |
| Starting lives | `starting_lives` | int | 1–5 (default 3) | Lives at run start, on continue, on drop-in. |
| Max lives | `max_lives` | int | `starting_lives`–9 (default 6) | Hard cap. |

**Output Range:** `lives` to `max_lives`. Never reduces lives (on each death Collision (6) sends `lives_decrement(slot)`; Session applies it, clamped at 0). An award at the cap is lost, so lives can't be banked. `extend_awarded` **always fires** for each award, with `gained = lives_after − lives` (may be 0 at the cap; the HUD decides how to show that).
**Example:** 2 + 2 extends → 4. 6 + one 1-up → 6 (wasted).

**F4. Continue countdown**

`continue_remaining = max(0, continue_total − continue_elapsed)`; slot → Inactive at 0 (never under UNTIMED); HUD shows `ceil(continue_remaining)` and draws its drain bar over `continue_total` (HUD HF2).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Countdown length (locked) | `continue_seconds` | float | 5–15 (default 10) | Tuned base value in seconds; unchanged by the accessibility override. |
| Active countdown length | `continue_total` | float, nullable | 10 or 30 | **Published to the UI.** Resolved from `access.continue_timer`: `continue_seconds` (STANDARD), 30 (EXTENDED), 30 (UNTIMED while another slot is Alive), `null` (UNTIMED with no other slot Alive). |
| Elapsed | `continue_elapsed` | float | 0–`continue_total` | Game time (Rule 3) in Continue; stops while paused, keeps running during Tally. |

**Example:** STANDARD, `continue_total` 10: 10 − 6.2 = 3.8 → HUD shows 4. EXTENDED, `continue_total` 30: 30 − 16.0 = 14.0 → HUD shows 14 and a 44 px bar (HUD HF2).
**Rationale:** arcade "CONTINUE? 9..0" convention; in co-op the others keep flying, so 10 s is long enough to react without stalling a partner.

**F5. Respawn timing**

`respawn_time = death_time + respawn_delay` (if the death took the last life, the Continue prompt appears at this moment instead)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Death time | `death_time` | float | ≥ 0 | `run_time` at the lethal hit. |
| Respawn delay | `respawn_delay` | float | 0.5–2.0 (default 1.0 s) | Time the slot is Dead. |

**Example:** death at 62.40 s → respawn at 63.40 s with 0 drones. Post-respawn invulnerability is owned by Collision, damage and lives (6).

**F6. Run aggregates** (computed for the results screen, not stored)

`slot_max_chain = max(max_chain_per_boss)` (0 if empty) · `team_max_chain = max(slot_max_chain)` over played slots
`team_score = Σ score` · `team_score_incl_continues = Σ (score + pre_continue_score_total)`
`team_life_bonus = Σ life_bonus_total` · `team_critical_breaks = Σ critical_breaks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Per-boss chains | `max_chain_per_boss` | int[] | each ≥ 0 | Best chain per boss fought. Lifetime record, **not** reset on continue. |
| Wiped score | `pre_continue_score_total` | int | ≥ 0 | Sum of scores wiped by continues. **Display only**, never ranked. |
| Life bonus, CBs | `life_bonus_total` (points, Scoring F4), `critical_breaks` | int | ≥ 0 | **Reset to 0 on continue.** |
| Played slots | — | set | 0–4 | Slots not Empty (includes Inactive). |

**Example:** P1 [112, 187], 4.2M, 2 CB. P2 continued after 600k, now 900k, [96]. → team chain 187, team score 5.1M (5.7M incl. continues), team CB 2.

**F7. 1CC flag**

`is_1cc = joined_at_run_start AND continues_used == 0` (only goes true → false)
`one_credit_clear = is_1cc AND run_ended_by == ENDING AND state != Inactive`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Joined at start | `joined_at_run_start` | bool | — | True only if the slot confirmed a plane before stage 1 began. |
| Continues used | `continues_used` | int | ≥ 0 | Accepted continues; kept on re-entry. |
| Run end cause | `run_ended_by` | enum | ENDING / GAME_OVER / ABANDONED | Why the run ended. ABANDONED = quit to title; never saved. |

**Example:** started, never continued, beat the last boss → true. Dropped in → false. Continued once → false. MVP 1CC = clear of the 2-stage run; boards tag clears by stage count.

> Formulas proposed by `systems-designer`, revised with the user (drones added 2026-11-02).

## Edge Cases

**Score and lives**

- **If one score add crosses several extend thresholds** (e.g. a Critical Break), all due extends are paid at once, up to `max_score_extends` (F2).
- **If an extend or 1-up arrives at `max_lives`**, it is used up with no effect and `extend_awarded` fires with `gained = 0`. Lives can't be banked.
- **If a player continues after earning extends**, `extends_awarded` resets to 0, so the new entry can earn its extends again from score 0.
- **If score would pass the integer maximum**, it is clamped at the maximum (int64, unreachable in practice).

**Drones**

- **If a powerup is picked up at 4 drones**, `drone_count` stays at 4. What the pickup gives instead is owned by Powerups (open question).
- **If two powerups land on the same frame at 3 drones**, the slot goes to 4 and the second pickup is treated as an overflow pickup.
- **If a player dies while their drones are deployed** (Lancer's parked lasers or Leech's latched magnets), every drone is removed at once, deployed ones included, and `drone_count = 0`. The drone ability cooldown resets to 0 (Plane kits 11 Rule 13).
- **If a stage ends while drones are deployed**, `drone_count` carries unchanged. Deployed drones snap home to their wing slots at `stage_cleared` and the cooldown becomes 0 (Plane kits 11 Rule 13).

**Continue, death and timing**

- **If two players die on the same frame**, each is handled independently. Order doesn't matter, because slots don't share lives.
- **If the last active player's continue countdown is running when another player's death would trigger game over**, there is no game over yet. Game over only happens when **every** slot is Inactive or Empty, and a slot in Continue still counts as a chance to continue.
- **If every player is in Continue at the same time**, the stage keeps running (enemies and bullets stay live). Game over only happens when the last countdown expires.
- **If a slot is in Continue when the boss dies**, the countdown keeps running through the tally (F4). If it expires, the slot goes Inactive and its record is kept. If accepted, the player starts the next stage.
- **If the game is paused during a countdown**, the countdown freezes (it counts only unpaused time).
- **If a player dies on the same frame the boss dies**, the death counts (life −1, drones to 0). The stage still clears, and the slot respawns at the start of the next stage instead of after `respawn_delay`.

**Drop-in and drop-out**

- **If a player drops in during the tally**, they start the next stage with `starting_lives`, 0 drones and `is_1cc = false`.
- **If a player drops in during the final boss**, the join is allowed. Their record counts, but they can never get a 1CC (F7).
- **If a pad disconnects mid-run**, the slot keeps its state and the game auto-pauses with a reconnect overlay (Input (2) Rules 28–33); "Drop player" calls `forfeit_slot`.
- **If a slot that never reached a boss ends the run**, `max_chain_per_boss` is empty and `slot_max_chain = 0` on the results screen.

**Run flow**

- **If the player quits to title from pause**, the run ends with `run_ended_by = ABANDONED`. Save is **not** called, so a high score can't be banked by quitting.
- **If the game closes or crashes mid-run**, the run is lost. There is no mid-run save in MVP.
- **If an event fires while no listener exists** (e.g. the HUD isn't loaded yet), nothing happens. Events are announcements only, and no game state depends on them being heard (Rule 11).

> `systems-designer` not consulted for this section (lean mode); built from its Formulas-stage edge-case list.

## Dependencies

**Upstream (this system depends on):** none. Foundation system. It reads stage and era definitions as data (`data/` resources) but owns no rules about them.

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Input and player mapping (2) — GDD | Hard | Slot index ↔ device. Drop-in starts from a start press on a free pad (slot choice: Input F7). Calls `forfeit_slot(slot)` for "Drop player". |
| Bullet manager (3) | Hard | Reads slot states (Alive / Selecting), plus the invulnerable flag from Collision (6), to decide who can be hit; not ticked while paused. |
| Bullet pattern library (9) | Hard | Reads Alive slot states to choose aimed-pattern targets (per-emitter rotation, Pattern library F4). |
| Player plane (5) | Hard | Reads plane, lives, `drone_count`; reports death. |
| Collision, damage and lives (6) | Hard | Subtracts lives. Owns invulnerability after respawn. |
| Chain tracker (7) | Hard | Writes `max_chain_per_boss`. |
| Scoring (8) — GDD | Hard | Adds score through `add_score(slot, points, source)`; supplies `extend_unit` (3,000,000); adds to `critical_breaks` and `life_bonus_total` (points). |
| Plane kits and drones (11) — GDD | Hard | Reads `drone_count` to know how many drones to spawn; `stage_started` / `stage_cleared` (drones snap home at clear, cooldown 0; reset on death). Never writes `drone_count`. |
| Bombs (12) — GDD | Hard | Stores `bombs` per slot (Bombs is the only writer, `set_bombs`); reads slot states, `stage_started`, `stage_cleared`, `player_died`, continue and drop-in; emits `bomb_used(slot)`. |
| Powerups and drops (13) — GDD | Hard | Calls `add_powerup(slot) -> int` (`drone_count` +1) and `add_oneup(slot) -> int` (gained); reads slot state, `lives`, `N`, `run_seed`, `stage_index`. |
| Boss and boss parts (14) — GDD | Hard | Emits the boss events (Rule 13) and `boss_defeated(reason, killer_slot)`; reads slot states for `N`. |
| Boss power budget (15) — GDD | Soft | Optional `mechanic_previewed(boss_id, mechanic_id, wave)` (presentation only). |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | Hard | Reads `stage_index`, era and slot states; emits `stage_started`, `stage_cleared` and the wave events (Rule 13). Boss events come from Boss (14). |
| Critical Break (17) — [GDD](critical-break.md) | Soft | Emits `critical_break_landed` / `_missed` / `_expired`; writes no session fields (Scoring (8) writes `critical_breaks` and `life_bonus_total`; amended 2026-11-03). |
| Co-op and Team Chain (18) — GDD | Hard | Reads slot states and `player_joined`; owns `N` (Alive, Dead or Continue slots) and the join grace after respawn, continue or drop-in; publishes `coop_count_changed(old, new)`. |
| HUD (20) — [GDD](hud.md), Stage-end tally (21) — [GDD](stage-end-tally.md) | Hard | Read everything; listen to events. The tally runs after every stage including the last, reads the stage-start marks (Rule 9) and hands off to the next stage or Results. |
| Menus and plane select (22) — [GDD](menus-title-plane-select.md) | Hard | Calls `start_run(selections, mode, stage_list)` and `abandon_run()`; writes the drop-in plane choice; reads slots, `RunRecord`, `run_ended_by`, aggregates. |
| Save and high scores (26) — GDD | Hard | Session calls `preview_rank(record)` when Results opens and `submit_run(record, initials)` on confirm, before clearing (not via `run_ended`). Not called for ABANDONED runs. |
| Display scaler and bezel (4) — GDD | Soft | Reads session state (Playing or not), era, and `stage_started` for bezel text/tint. |
| VFX (25) — [GDD](vfx-and-screen-feedback.md), Audio (24) — [GDD](audio.md), Parallax (23) — [GDD](parallax-and-environment.md) | Soft | Listen to events only; the game runs without them. |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | Hard | Emits `era_swap_committed`, `era_ready`, `era_load_late`, `era_failed`; Session waits for `era_ready`; `era_failed` ends the run unranked. |
| Accessibility options (28) — [GDD](accessibility-options.md) | Soft | Defines ASSIST options that latch `run.assisted`, the game-speed gate (F2) and the `access.continue_timer` override. |

| Tutorial (30) — [GDD](tutorial.md) | Soft | Calls `start_school(selections)`; reads `run_kind`; writes `drone_count` / `bombs` in drills only. |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | Soft | Calls `start_run` with RUSH/BOSS mode and stage list; reads the `RunRecord`; `ReplayRecorder.tick` when `online.enabled`. |

**Bidirectional note:** *(amended 2026-11-03: many of these systems now have GDDs; see the systems index.)* Each one's Dependencies section **must list "Game events and session state"** with the matching interface.

## Tuning Knobs

All live in data (e.g. `data/session_rules.tres`), not code.

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `starting_lives` | 3 | 1–5 | Difficulty, 1CC tension | Each mistake ends the run; new players bounce | Deaths stop mattering; chain risk feels free |
| `max_lives` | 6 | `starting_lives`–9 | How far a strong player can bank | Extends feel wasted | Endgame becomes a life buffer |
| `max_score_extends` | 2 | 0–4 | Reward for scoring | Score feels pointless for survival | Trivializes 1CC |
| `extend_first_mult` | 0.8 | 0.3–2.0 | When the first extend lands (× one stage's par) | Free life in stage 1 | First extend comes too late to help |
| `extend_step_mult` | 1.0 | 0.5–3.0 | Gap between extends | Extends bunch together | Second extend unreachable |
| `continue_seconds` | 10 | 5–15 | Co-op flow, decision pressure | Players miss the prompt | Stalls the run |
| `respawn_delay` | 1.0 s | 0.5–2.0 | Death readability, rhythm | Death effect gets swallowed | Dead time; long gaps before the player can rebuild a chain (the death itself already drops it) |

**Locked (not knobs):** `max_drones = 4`, set by design. Powerups only ever add one drone.

**Knobs that interact:**

- `extend_*` depends on `extend_unit` from **Scoring (8)**. Retune after the Scoring GDD.
- Post-respawn invulnerability is a knob in **Collision, damage and lives (6)**, not here.
- The 1-up drop rate is a knob in **Powerups and drops (13)**.

## Visual/Audio Requirements

None of its own. This system only announces events; VFX (25) and Audio (24) decide how `critical_break_landed` (the only flash), `extend_awarded`, `player_died`, `stage_cleared`, `critical_break_landed` etc. look and sound. Art bible rules (Readable Chaos: no effect over enemy bullets) apply to whoever renders them.

## UI Requirements

This system owns no screens, but it supplies the data for these. Each needs a UX spec in Pre-Production:

- **Continue prompt** (per slot, in-stage): `ceil(continue_remaining)`, `continue_total` (for the drain bar; `null` = no countdown), accept button → HUD (20). *(`continue_total` added 2026-11-03, wave 5.)* *(2026-11-03, wave 5 batch 2: the accept is the single `CONTINUE_ACCEPT` verb = **Fire**, Input Rule 24b; Start does not accept, it pauses.)*
- **Drop-in plane pick** (in-place, game keeps running) → Menus and plane select (22) / HUD (20).
- **Extend / 1-up feedback** (`gained` may be 0) → HUD (20).
- **Stage tally** (every stage, including the last) → Stage-end tally (21). **Results screen** (per-slot records, team aggregates F6, score incl. continues, 1CC badge) → Menus (22). *(Amended 2026-11-03.)*
- **Pause menu** with quit-to-title (ABANDONED warning: "score will not be saved") → Menus (22).
- **Flight School** (drill list, drill cards, Coach card) → owned by Tutorial (30), shown through Menus (22). *(Added 2026-11-03, wave 4.)* Continue prompt and drop-in pick-plate geometry → HUD (20).

## Acceptance Criteria

Defaults used: `starting_lives` 3, `max_lives` 6, `max_score_extends` 2, `extend_first_mult` 0.8, `extend_step_mult` 1.0, `extend_unit` 1,000,000 as a test parameter (real value 3,000,000, Scoring F7; tests read it from the rules resource), `continue_seconds` 10 (`continue_total` 10 / 30 / `null`, F4), `respawn_delay` 1.0 s, `max_drones` 4. Slots are 0-indexed in code.

**Test setup:** session logic lives in plain RefCounted classes (session/slot model) with an injected `tick(delta)` clock and a `SessionRules` resource — same pattern as `ChainTracker`/`CombatRules` — so [Unit] criteria run headless. Tests go in `tests/unit/test_game_session.gd`, named `test_session_[scenario]_[result]`.

Tags: [Unit] pure logic · [Integration] needs scenes/signals · [Manual] needs a human.

### Run flow

- **AC-01 [Unit] (Rules 1, 3, 4):** **GIVEN** no run exists, **WHEN** slot 0 confirms a plane, **THEN** a run exists with `stage_index = 0`; slot 0 is Alive with `lives = 3`, `score = 0`, `drone_count = 0`, `continues_used = 0`, `extends_awarded = 0`, `critical_breaks = 0`, `life_bonus_total = 0`, `pre_continue_score_total = 0`, empty `max_chain_per_boss`, `is_1cc = true`; slots 1–3 are Empty.
- **AC-02 [Unit] (Rule 2):** **GIVEN** a run is active, **WHEN** a second run start is requested, **THEN** it is rejected and the existing run is unchanged.
- **AC-03 [Unit] (slot table):** **GIVEN** a slot in each state, **WHEN** any transition not in the slot table is requested (e.g. Empty→Alive, Inactive→Alive, Dead→Inactive other than by `forfeit_slot`), **THEN** it is rejected and the state is unchanged; every listed transition succeeds.
- **AC-04 [Integration] (Rules 1, 9):** **GIVEN** stage 0 of 2 with slot 0 at `score = 123,456`, `lives = 2`, `drone_count = 2`, `continues_used = 1`, `max_chain_per_boss = [112]`, **WHEN** the boss dies and the tally completes, **THEN** stage 1 starts with `stage_index = 1`, era from the stage definition, and every listed field unchanged; the session stores no chain counter. If a drone was deployed at stage end, `drone_count` is still 2.
- **AC-05 [Integration] (Rule 1):** **GIVEN** the last stage, **WHEN** `boss_defeated(reason, killer_slot)` fires with any reason (KILLED, CRITICAL_BREAK or TIMEOUT), **THEN** `run_ended_by = ENDING` is set at once, the state is Tally (Stage-end tally 21) and then Results; `run_ended` fires exactly once and the `RunRecord` is built when the tally is Done (`tally_finished`). *(Amended 2026-11-03: the last stage also has a tally.)*
- **AC-06 [Integration] (Rule 2):** **GIVEN** a run ended with ENDING or GAME_OVER, **WHEN** Results is confirmed, **THEN** the session has called `preview_rank(record)` when Results opened and calls `submit_run(record, initials)` on confirm, both **before** clearing; name entry happens between the two calls, and initials default to `profile.last_initials` on timeout; after Title loads the session has no run and no slots.

### Slots and lives

- **AC-07 [Unit] (F3, Rule 5):** **GIVEN** `lives = 2`, `extends_due = 2`, **WHEN** the award is applied, **THEN** `lives = 4`; with `lives = 5`, `lives = 6`.
- **AC-08 [Unit] (F3):** **GIVEN** `lives = 6`, **WHEN** a 1-up is collected, **THEN** `lives` stays 6 and `extend_awarded` fires with `gained = 0`; no award ever reduces lives.
- **AC-09 [Unit] (F5):** **GIVEN** a slot dies at `run_time = 62.40` with lives remaining, **WHEN** the clock reaches 63.39, **THEN** it is Dead; **WHEN** it reaches 63.40, **THEN** it is Alive with `drone_count = 0`.
- **AC-10 [Unit] (F5, Rule 6):** **GIVEN** `lives = 1`, **WHEN** it takes the lethal hit at 62.40, **THEN** it enters Continue at 63.40 and never becomes Alive.
- **AC-11 [Unit] (edge case):** **GIVEN** slots 0 and 2 are Alive, **WHEN** both take a lethal hit in the same frame, **THEN** each loses exactly 1 life and has `drone_count = 0`, regardless of processing order.

### Drones

- **AC-12 [Unit] (F1):** 1 drone + 1 powerup → 2. 4 + 1 → 4. 3 + 2 in the same frame → 4 and one overflow pickup is reported.
- **AC-13 [Unit] (F1, Rule 9):** **GIVEN** `drone_count = 3`, **WHEN** the slot dies, **THEN** `drone_count = 0`.
- **AC-14 [Integration] (edge case):** **GIVEN** a Lancer with parked lasers (or Leech with latched magnets) deployed and `drone_count = 3`, **WHEN** the slot dies, **THEN** all drone nodes, deployed ones included, are freed that frame, `drone_count = 0`, and `player_died(slot)` fires once.

### Extends

- **AC-15 [Unit] (F2 boundaries):** with `extends_awarded = 0`: score 799,999 → 0 due; 800,000 → 1; 1,799,999 → 1; 1,800,000 → 2 (integer comparison, no float drift).
- **AC-16 [Unit] (F2):** **GIVEN** `score = 700,000`, `extends_awarded = 0`, `lives = 3`, **WHEN** one add brings it to 1,900,000, **THEN** 2 extends are paid in that evaluation and `lives = 5`.
- **AC-17 [Unit] (F2 cap):** **GIVEN** `extends_awarded = 2`, **WHEN** score rises to 5,000,000, **THEN** `extends_due = 0`. With `max_score_extends = 0`, no score ever yields an extend.
- **AC-18 [Unit] (F2 + F3):** **GIVEN** `lives = 6`, `score = 790,000`, **WHEN** score reaches 800,000, **THEN** `lives` stays 6, `extends_awarded` becomes 1 (consumed, does not re-fire), `extend_awarded` fires once with `gained = 0`.
- **AC-19 [Unit] (Rule 6, F2):** **GIVEN** a slot with `extends_awarded = 2` accepts a continue, **WHEN** it later reaches 800,000, **THEN** it earns an extend again (`extends_awarded` 0 → 1).

### Continue

- **AC-20 [Unit] (Rule 6):** **GIVEN** a slot in Continue with `score = 600,000`, `critical_breaks = 2`, `life_bonus_total = 50`, `extends_awarded = 1`, `continues_used = 0`, `is_1cc = true`, `max_chain_per_boss = [112]`, **WHEN** the player accepts, **THEN** `pre_continue_score_total = 600,000`, `score = 0`, `critical_breaks = 0`, `life_bonus_total = 0`, `extends_awarded = 0`, `continues_used = 1`, `is_1cc = false`, `lives = 3`, `drone_count = 0`, plane unchanged, `max_chain_per_boss = [112]`, slot Alive, `player_continued(slot)` fires once.
- **AC-21 [Unit] (F4):** **GIVEN** a slot enters Continue, **WHEN** 6.2 s of game time elapse, **THEN** `continue_remaining = 3.8` and the displayed value is 4; at 10.0 s it is 0 and the slot is Inactive; it never goes below 0.
- **AC-22 [Unit] (Rule 6, F4):** **WHEN** the countdown expires, **THEN** the slot is Inactive, `player_slot_inactive(slot)` fires once, and all record fields are kept.
- **AC-23 [Integration] (edge case):** **GIVEN** a countdown at 5.0 s elapsed, **WHEN** the game is paused for 30 s real time and resumed, **THEN** `continue_elapsed` is still 5.0 (±1 frame) and the slot is still in Continue.
- **AC-24 [Integration] (Rule 10):** **GIVEN** 2P with P1 Inactive and P2 Alive, **WHEN** P2 enters Continue, **THEN** no game over, enemies and bullets stay live; **WHEN** the countdown expires, **THEN** the run ends GAME_OVER and `run_ended` fires once. With P1 in Continue and P2 dying for the last time, `run_ended` waits until both countdowns expire.
- **AC-25 [Integration] (edge case):** **GIVEN** a slot in Continue at 4.0 s when the boss dies, **WHEN** the tally runs 3 s, **THEN** elapsed is 7.0 s; accepting at 8 s starts the next stage Alive with the AC-20 values; expiry during the tally makes the slot Inactive.

### Drop-in

- **AC-26 [Integration] (Rules 7, 8):** **GIVEN** a run with slot 1 Empty or Inactive, **WHEN** start is pressed on that pad mid-stage or during the tally, **THEN** the slot is Selecting while the game keeps running; after picking it is Alive with `lives = 3`, `score = 0`, `drone_count = 0`, `extends_awarded = 0`, `is_1cc = false`; `player_joined(1)` fires once. A re-entering Inactive slot keeps its `continues_used`. A join during the final boss is accepted with `is_1cc = false`.
- **AC-27 [Manual] (Rule 7):** **GIVEN** 2P in stage 1, **WHEN** a third pad joins mid-wave, **THEN** the game does not pause, the joiner cannot be hit while Selecting, and the other players' HUD values don't change.
- **AC-28 [Unit] (Rule 10):** **GIVEN** slot 0 Inactive and slot 1 Selecting (no Alive/Dead/Continue slots), **WHEN** the game-over check runs, **THEN** the join is cancelled, slot 1 returns to its previous state, and the run ends GAME_OVER.

### Aggregates and 1CC

- **AC-29 [Unit] (F6):** **GIVEN** P1 `[112, 187]`, 4.2M, 2 CB and P2 `[96]`, 900k, `pre_continue_score_total = 600k`, 0 CB, slots 2–3 Empty, **THEN** `team_max_chain = 187`, `team_score = 5.1M`, `team_score_incl_continues = 5.7M`, `team_critical_breaks = 2`. An Inactive slot with data is included; Empty is not; empty `max_chain_per_boss` → `slot_max_chain = 0`.
- **AC-30 [Unit] (F7):** `one_credit_clear` is true only for: joined at start, `continues_used = 0`, `run_ended_by = ENDING`, slot not Inactive. False if: continued once; dropped in; GAME_OVER; ABANDONED; Inactive at the end. `is_1cc` never returns to true.

### Events bus

- **AC-31 [Unit] (Rules 12, 13):** **GIVEN** the `GameEvents` script, **THEN** every signal listed in Rule 13 (including the dated additions) exists and every player-related signal's first argument is an `int` slot (0–3), never a Node.
- **AC-32 [Integration] (Rule 12):** **GIVEN** a listener on `player_died`, **WHEN** slot 0 dies, respawns, and the scene changes, **THEN** the listener gets each event with `slot = 0` and no freed-instance errors.
- **AC-33 [Unit] (edge case):** **GIVEN** no listeners on `extend_awarded`, **WHEN** a slot earns an extend, **THEN** `lives` and `extends_awarded` update as in AC-07 with no error or warning.

### Edge cases

- **AC-34 [Integration]:** **GIVEN** slot 0 Alive with `lives = 2`, `drone_count = 2` on the boss's final frame, **WHEN** the lethal hit and `boss_defeated` land on the same frame, **THEN** `lives = 1`, `drone_count = 0`, the stage clears, and slot 0 is Alive at the next stage's start without waiting `respawn_delay`. With `lives = 1` it enters Continue instead.
- **AC-35 [Integration]:** **GIVEN** slot 0 at 900,000, **WHEN** the player quits to Title from pause, **THEN** `run_ended_by = ABANDONED`, Save is not called, the high-score data is byte-identical to before the run, and the session is cleared.

> Criteria drafted by `qa-lead`; testability gaps it found were fixed in Rules 2, 7, 10, F2, F3, F4, F7 and Edge Cases (2026-11-02).

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~How does the HUD show an extend with `gained = 0` ("MAX" popup?)~~ **Closed 2026-11-03:** `gained = 0` shows the MAX icon on the lives display for 60 ticks (HUD (20) Rule 22). | HUD (20) GDD | Done |
| 2 | ~~Pad disconnect mid-run: pause + "Reconnect controller P#"?~~ **Closed 2026-11-03:** auto-pause with a per-slot reconnect overlay (Reconnect / Use keyboard / Drop player / Wait); Drop player uses `forfeit_slot` (Input (2) Rules 28–33). | Input (2) GDD | Done |
| 3 | ~~Deployed drones at stage end: recalled during tally? Drone cooldown reset on death?~~ **Closed 2026-11-03:** deployed drones snap home at `stage_cleared`; the cooldown resets to 0 on death and at stage clear; `drone_count` carries unchanged (Plane kits (11) Rule 13). | Plane kits and drones (11) GDD | Done |
| 4 | ~~What does a powerup give at 4 drones (score bonus?)~~ **Closed 2026-11-03:** a POD at 4 drones is skipped while a partner has fewer; otherwise it pays a MEDAL. A 1UP at `max_lives` gives `gained = 0` and a MEDAL (Powerups (13) Rules 21–22). | Powerups and drops (13) GDD | Done |
| 5 | ~~Real `extend_unit` (par score per stage); retune F2 knobs after~~ **Closed 2026-11-03:** `extend_unit` = 3,000,000 (Scoring F7); 0.8 / 1.0 kept, extends at 2.4M and 5.4M. | Scoring (8) GDD | Done |
| 6 | ~~Should high-score boards separate drop-in and continued runs?~~ **Closed 2026-11-03:** continued and drop-in runs are ranked with badges ("C", no 1CC); see Save (26) Rules 6–7. | Save and high scores (26) GDD | Done |
| 7 | Architecture: two autoloads vs a separate run-flow controller; logic in RefCounted classes for testing | ADR | Before implementation |
