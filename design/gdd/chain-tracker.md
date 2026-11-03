# Chain Tracker

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — lean mode
> **Author**: user + Claude
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Every Hit Counts (primary)

## Overview

The **Chain tracker** keeps each player's **hit chain**: the number of hits landed without a break. Every counted hit adds to it and refills a strict **chain window** (~1 s). If the window runs out, or the player dies, the chain **drops straight to 0** — no decay. Each player in co-op has their own chain.

**What it owns:**

- **The counter and the window** — one count and one window timer per player, in whole ticks, plus each player's best chain per boss (for the tally and the run records).
- **Bonus adds** — other systems can ask it to add more than one hit at once (e.g. **+5 for a boss-part kill**, a chain pickup). They own the amounts; the chain applies them.
- **The Critical Break multiply** — when Critical Break (17) confirms a break, the chain applies the multiply (currently `chain × 3 + 50`).
- **Team Chain detection** — in co-op, it checks whether **every active player** hit the boss inside the same window, and reports when a team chain starts and ends. What the bonus is worth belongs to Scoring (8) and Co-op (18).

**What it doesn't own:** which hits count (Collision 6 sends `chain_hit(slot)` and `chain_drop(slot)`), score per hit (Scoring 8), and how the chain looks (HUD 20, art bible §7.3).

**The player impact:** the chain is the game's core verb. The counter climbs past 100, then 200, while the gold bar drains between hits. When it drops, the last value stays on screen as a ghost — the player knows exactly what they lost: *"I dropped it at 187."* Everything else in the game either feeds the counter or threatens it.

> Implementation (ADR-0001): a node-free class with `tick()`. The window is counted in whole 60 Hz ticks, not seconds; all values come from a `.tres` resource. The current `chain_tracker.gd` (seconds + `delta`) will be migrated.

## Player Fantasy

**Direct: the player plays for the counter.** It is the number they watch, the bar they race, and the thing they protect.

The anchor moment: **the boss shifts phase, its core goes dark for a beat, and the gold bar drains toward the red end-cap.** The player slides under the new curtain, a parked drone lands one tick on a turret with a frame to spare, and the bar snaps back to full. The counter rolls past 100 and the plate edge steps to gold. The player breathes out and is already lining up the next hit.

- **Tension you can read.** The window is short and strict, and the bar shows exactly how long is left. The danger is always visible, never hidden.
- **Every hit is a lifeline.** A turret, a popcorn fighter or a drone tick on armour all refill the window. The player keeps the chain alive by choosing what to hit next, not only by dealing damage.
- **Honest loss.** When it drops, it drops to 0, and the ghost shows what was lost. Nobody else broke it; the player knows the beat they missed.
- **A number worth bragging about.** Each player's best chain per boss is kept for the tally and the run records — "187 on the Fortress" is something worth saying out loud.

It serves **Every Hit Counts** (*"The chain is the game; every system feeds or threatens the hit counter"*) and **Four Planes, Four Games**: each kit keeps the window alive in its own way — Lancer's parked lasers hold it while you dodge; Leech's drones latch on and keep hitting.

> `creative-director` not consulted for this section (lean mode).

## Detailed Design

### Core Rules

**Per-player state** (one per slot): `count` (0–999), `window_left` (ticks), `boss_hit_left` (ticks), `boss_peak`, `last_dropped` (the ghost value).

**Counting**

1. **Counted hit:** Collision (6) sends `chain_hit(slot, on_boss)`. Then `count = min(chain_cap, count + 1)` and `window_left = chain_window`. If `on_boss` (the target is a boss part or core), also `boss_hit_left = team_window + team_window_step × (a − 2)` (F3). A `chain_hit` for a slot that isn't Active is ignored and logs a warning (Collision already filters these).
2. **Bonus add:** `add_bonus(slot, n, source)` — e.g. **+5 for a part kill** (Boss 14), **+10 for a chain pickup** (Powerups 13, source `"chain_pickup"`). If the slot is Active: `count = min(chain_cap, count + n)` and the window refills. A bonus can start a chain from 0. If the slot is not Active, the bonus is ignored.
3. **At or above the cap**, hits and bonuses still refill the window; `count` stays at 999.
4. **Every tick**, first apply that tick's events in arrival order (GameLoop step 8, after the Collision referee). Then, unless frozen, every chain with `count > 0` ticks down `window_left −= 1`, and every slot's `boss_hit_left = max(0, boss_hit_left − 1)` (its own timer, independent of `count`). If `window_left` reaches 0, the chain **drops** (EXPIRED). A chain refreshed this tick skips this tick's countdown (F2), so it survives exactly `chain_window` hit-free ticks.

**Dropping**

5. **Drop:** `last_dropped = count`, `count = 0`, `window_left = 0`; `boss_hit_left = 0` for DEATH, LEFT and STAGE_END only (an EXPIRED drop keeps it, so a team chain can outlive a personal chain when `team_window > chain_window`); emit `chain_dropped(slot, value, reason)`. A drop at `count = 0` does nothing and emits nothing.
6. **Reasons:** EXPIRED (window ran out), DEATH (Collision `chain_drop(slot)`), STAGE_END (tally starts), LEFT (slot became Inactive or Empty).

**Critical Break**

7. `apply_critical_break(slot)` from Critical Break (17): `count = min(chain_cap, count × cb_mult + cb_add)`, the window refills, and the new value is returned; emit `chain_multiplied(slot, before, after)`. Critical Break owns *when* a break happens; the chain owns the math (`cb_mult` 3, `cb_add` 50 for now — confirmed in Formulas). *(2026-11-03, Critical Break 17:)* the multiply must arrive **before** `boss_defeated` for the same boss, so `boss_peak` includes it before Rule 10 freezes the peak; CB runs at tick step 6b, before Boss `apply_results` (6c), which guarantees this.

**Boss record**

8. On **`boss_started`** (Wave director 16 / Boss 14), the fight opens: every slot's `boss_peak = count` (a chain carried in from wave 5 counts). *(2026-11-03, Boss 14)* `boss_started` fires when the boss Intro ends; chains from wave 5 expire during the Warning and entrance, so a carried-in chain does not normally occur.
9. While the boss is alive, `boss_peak = max(boss_peak, count)` after every change.
10. On **`boss_defeated(reason, killer_slot)`** (reason KILLED, CRITICAL_BREAK or TIMEOUT; Boss 14): all windows **freeze** (nothing ticks down; hits still add). Each slot that was **Active on at least one tick** between `boss_started` and `boss_defeated` appends its `boss_peak` to Session's `max_chain_per_boss`. Events apply before the countdown, so a chain on its last window tick at `boss_defeated` is frozen, not dropped. The record is appended and the chains freeze for **every** reason, including TIMEOUT. A stage with several bosses repeats Rules 8–10: each `boss_started` re-seeds `boss_peak`, each `boss_defeated` appends one entry. On **`stage_cleared`** (tally starts), every chain drops (STAGE_END).

**Team Chain**

11. `team_chain = (boss alive) AND (|M| ≥ 2) AND (every Active non-exempt slot is in M)`, where `M` = Active slots with `boss_hit_left > 0`. A slot is exempt only while Co-op (18) has set `set_team_exempt(slot, true)` (join grace) **and** its `boss_hit_left` is 0; an exempt slot that hits the boss joins `M`. Query `team_members()` returns `M`. Dying, FlyIn, Absent, Continue and Inactive slots are left out. A single player never has a team chain. *(Amended 2026-11-03, Co-op (18) Rule 13.)*
12. Checked at the end of every tick; emit `team_chain_started(slots)` when it turns on and `team_chain_ended()` when it turns off. What the bonus pays belongs to Scoring (8) and Co-op (18).

**Milestones**

13. When a chain crosses **50, 100 or 200** upward, emit `chain_milestone(slot, value)` (HUD plate step, VFX, audio — art bible §7.3).
14. **Per-hit event** *(added 2026-11-03, Scoring GDD)*: after applying each counted hit (Rule 1), emit `hit_counted(slot, count_after, on_boss)` in arrival order, so Scoring can pay each hit at its own count when several land on one tick.

**Bomb toll** *(added 2026-11-03, Bombs 12)*

15. `apply_bomb_toll(slot, pct)` from Bombs (12): if the slot is Active, `count > 0` and the chains are not Frozen, `count = count - (count × pct) div 100`; the window is **not** refilled; `last_dropped` is unchanged; `boss_peak` is unchanged; emit `chain_reduced(slot, before, after)`. Otherwise nothing happens and nothing is emitted. The toll never drops a chain to 0 (`count ≥ 1` gives `after ≥ 1`). Bombs owns `bomb_chain_toll_pct` (50) and waives the call when a Critical Break is armed.

**Pause** stops ticks, so windows freeze. The chain is never saved to Session; only boss records are (Session rule 9).

### States and Transitions

Per slot:

| State | Window ticks down | → Next |
|---|---|---|
| Idle (`count = 0`) | — | Chaining (counted hit or bonus) |
| Chaining (`count > 0`) | yes | Idle (EXPIRED / DEATH / LEFT) · Frozen (`boss_defeated`) |
| Frozen (boss dead, before tally) | no | Idle (`stage_cleared` → STAGE_END) |

Fight state (shared): **No boss → Boss alive** (`boss_started`) **→ Boss dead** (`boss_defeated`) **→ No boss** (`stage_cleared`).

### Interactions with Other Systems

| System | Gives to chain | Gets from chain |
|---|---|---|
| Collision (6) — GDD | `chain_hit(slot, on_boss)`, `chain_drop(slot)` | — |
| Session (1) — GDD | Slot states (Active, …) | Appends to `max_chain_per_boss` |
| Boss (14), Wave director (16) | `boss_started`, `boss_defeated`, `stage_cleared`; part kill `add_bonus(slot, 5)` | — |
| Powerups (13) — GDD | Chain pickup `add_bonus(slot, 10, "chain_pickup")` (refills the window, Rule 2; not a hit) | — |
| Bombs (12) — GDD | `apply_bomb_toll(slot, pct)` (Rule 15) | — |
| Critical Break (17) | `apply_critical_break(slot)` | New count; `chain_multiplied` |
| Scoring (8) — GDD | — | `hit_counted(slot, count_after, on_boss)` once per applied hit, in arrival order (per-hit score); `chain_multiplied`; team events |
| Co-op and Team Chain (18) — GDD | `set_team_exempt(slot, bool)` (join grace) | `team_chain_started` / `team_chain_ended`; `team_members()` |
| HUD (20), VFX (25), Audio (24) | — | `count`, `window_left / chain_window`, `last_dropped`, `chain_dropped`, `chain_milestone`, `chain_multiplied`, `chain_reduced` |

**Amendments needed** (applied at wrap-up with approval): (1) Collision: `chain_hit(slot)` → `chain_hit(slot, on_boss)`; Boss (14) marks its targets as boss parts/cores. (2) Session Rule 9: "the window expires during the tally" → "chains drop when the tally starts (Chain Rule 10)".

> Specialist agents not consulted for this section (lean mode).

## Formulas

All time is integer ticks (60/s). All values come from the chain rules `.tres`.

**F1. Chain window**

`chain_window = 60 ticks (1.0 s)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Chain window | W | int ticks | 45–90 (default 60) | Ticks a chain survives with no counted hit |
| Boss/wave gap | G | int ticks | 0 to W−1 | Longest stretch a boss or wave leaves the player with no hittable target |

**Design constraint for Boss (14) and Wave director (16):** `G ≤ W − ceil(W/4)` = **45 ticks** at W = 60 (enforced by the Wave director's stage validator, `wave-and-stage-director.md` F6, 2026-11-03). Only a deliberate "frame to spare" moment may go beyond.
**Output:** constant. **Example:** a core immune for 40 ticks leaves 20 ticks on the window (red zone, chain survives); a 58-tick gap leaves 2.

**F2. Tick-down and drop**

```
per tick, after events:   window_left = W                   if fresh (hit, bonus or CB this tick)
                          window_left = window_left − 1     otherwise (count > 0, not Frozen)
drop when                 window_left == 0 AND count > 0
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Last hit tick | T | int | ≥ 0 | Tick of the last counted hit |
| Window left | window_left | int ticks | 0–W | Remaining after this tick |
| Fresh | fresh | bool | — | Set by a hit, bonus or CB this tick; cleared at end of tick |

**Output:** 0–W. A hit on tick T drops the chain at the end of tick **T + W** if no hit lands on ticks T+1 … T+W — exactly "W hit-free ticks → drop" (clarifies Rule 4).
**Example:** hit at 100 → 60 at end of tick 100, 59 at end of 101, 1 at end of 159; drops at end of 160. A hit on tick 160 is applied first and saves it.

**F3. Team-chain window**

`boss_hit_left = team_window + team_window_step × (a − 2) on a boss hit (a = Active slots at the hit tick, clamped 2–4); counts down with the same fresh-skip rule as F2`
`team_chain = boss_alive AND |M| ≥ 2 AND every Active non-exempt slot is in M` (M = Active slots with boss_hit_left > 0)

*(Amended 2026-11-03 by Co-op (18) F3 and Rule 13: 60 / 68 / 76 ticks for 2 / 3 / 4 Active.)*

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Team window | team_window | int ticks | ≥ chain_window; 60–120 (default 60) | How long a boss hit keeps a slot "in" the team chain |
| Team window step | team_window_step | int ticks | 0–15 (default 8) | Added per Active player above 2 (Co-op F3) |
| Active count | a | int | 0–4 | Slots whose plane is Active, at the hit tick |
| Members | M | set | 0–4 slots | Active slots with `boss_hit_left > 0` |

**Output:** bool, checked at end of tick. **Example:** P1 hits the boss at tick 200, P2 at 240. End of 240: P1 has 20 left, P2 60 → team chain **starts**. It **ends** at the end of tick 260 unless P1 hits again.

**F4. Critical Break multiply**

`after = min(chain_cap, before × cb_mult + cb_add)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Before | before | int | 0–999 | Count when the break is confirmed (0 → `cb_add`, see Edge Cases) |
| Multiplier | cb_mult | int | 1–5 (default 3) | — |
| Flat add | cb_add | int | 0–200 (default 50) | — |
| Cap | chain_cap | int | 999 (locked) | — |
| After | after | int | before+1 to 999 | New count |

**Output:** ≤ 999 (largest raw value 3047, clamped). The cap is reached from `before ≥ 317`.
**Example:** 50 → 200, 100 → 350, 150 → 500, 200 → 650, 317 → 999 (raw 1001).

**F5. Milestones**

`for M in milestones (ascending): emit chain_milestone(slot, M) if before < M ≤ after`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Milestones | milestones | int[] | default [50, 100, 200] | Thresholds (data list) |
| Before / after | before, after | int | 0–999 | Count before and after one change |

**Output:** 0–3 events per change, ascending. Landing exactly on M counts. After a drop, milestones fire again on the next climb.
**Example:** a Critical Break from 40 to 170 emits 50, then 100 (not 200).

**F6. HUD bar**

```
ratio  = window_left / W            (0 when count = 0)
bar_px = ceil(BAR_PX × window_left / W)
red    = window_left × 4 ≤ W
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Bar length | BAR_PX | int px | 94 (1–2P), 82 (3–4P), 42 (HUD compact 48 px form, 2026-11-03) | Set by HUD (20) Rule 17 (2026-11-03) |
| Filled | bar_px | int px | 1–BAR_PX | Ceil: a live chain never shows an empty bar |
| End-cap | red | bool | — | Last 25% of the window |

**Example (96 px, W = 60):** window_left 30 → 48 px; 15 → 24 px + red end-cap; 1 → 2 px. The bar moves 1–2 px per tick, so **art bible §7.3 is reworded** from "1 px steps" to "one visible step per tick, never more than 2 px".

**F7. Reaching the cap (reference)**

`ticks_to_cap = ceil(chain_cap / hits_per_tick)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Hit rate | hits_per_tick | float | 0.5–4 | Counted hits per tick (assumption until Kits 11 sets rates) |

**Example:** normal shots only (~0.67/tick) → ~1,500 ticks (25 s); laser only (1/tick) → 999 ticks (16.7 s); laser + 2 drones + shots (~3.7/tick) → ~270 ticks (4.5 s). 999 is reachable in one boss fight — **flagged for Scoring (8) and Critical Break (17)**: a capped chain makes the CB multiply and per-hit score growth moot.

> Formulas proposed by `systems-designer`; decisions by the user (2026-11-02): W = 60, fresh-skip drop timing, separate `team_window` 60, ×3 + 50, art bible bar wording change.

## Edge Cases

**Same-tick ordering**

- **If a player scores hits and dies on the same tick**: Collision sends `chain_hit` (Phase A) before `chain_drop` (Phase B). The hits count, then the chain drops; `last_dropped` and `boss_peak` include them.
- **If several `chain_hit` events arrive on one tick** (laser + drones + shots): each adds 1 in arrival order; milestones are checked per change, so a run of +1s crossing 50 emits 50 exactly once.
- **If a hit and the window's last tick coincide**: the event is applied first and the countdown skips that tick (F2) — the chain survives.
- **If a Critical Break and a hit land on the same tick**: applied in arrival order. Critical Break (17) sends its request at step 6b (after the Collision referee at 6 and `EnemyManager.apply_results` at 6a; adapted 2026-11-03; was "GameLoop step 8"). **The multiply uses the count as of the start of the tick**; this tick's hits are applied by Chain at step 8, after the multiply *(2026-11-03, wave 3b)*.

**Critical Break**

- **If a break is confirmed while the chain is 0**: it applies — 0 → `cb_add` (50) — starting a new chain and refilling the window.
- **If a break is confirmed at ≥ 317**: capped at 999; `chain_multiplied` reports the capped value.
- **If a break is confirmed for a slot that isn't Active**: ignored; returns the current count. Critical Break (17) must not send one.

**Cap**

- **If the count is 999**: hits, bonuses and breaks still refill the window; `count`, milestones and `boss_peak` don't change.

**Boss record and stage end**

- **If a player dies during the boss fight**: `boss_peak` keeps its highest value; the drop doesn't lower it.
- **If a player drops in during the boss fight**: their `boss_peak` starts at 0; their record is appended on `boss_defeated` (they were in play during the fight).
- **If a player continues during the boss fight**: the record carries on (Session: `max_chain_per_boss` is never reset on continue).
- **If a slot is Inactive or Empty for the whole fight**: nothing is appended for it.
- **If a slot goes Inactive mid-fight**: it drops (LEFT); its `boss_peak` so far is still appended on `boss_defeated`.
- **If hits land while Frozen** (after `boss_defeated`, before the tally): they still add to `count`, but `boss_peak` and the record no longer change.
- **If `stage_cleared` arrives while a chain is already 0**: STAGE_END does nothing for that slot; its ghost stays.
- **If a player dies on the same tick the boss dies**: the DEATH drop (Phase B) is applied, then `boss_defeated` writes the record, which already includes the peak.

**Team chain**

- **If one of two Active players starts Dying**: only one Active slot remains, so the team chain ends that tick. It can restart once `|M|` ≥ 2 and every Active non-exempt slot is in `M` (Rule 11; amended 2026-11-03).
- **If one of three Active players starts Dying**: the other two can keep the team chain; the dying slot is left out of the check.
- **If no boss is alive** (waves, or after `boss_defeated`): the team chain is always off; `team_chain_ended` fires if it was on.

**Bonuses**

- **If a bonus arrives for a slot that isn't Active**: ignored (covers part kills by a dead player's in-flight shots, matching Collision C5).
- **If a bonus is ≤ 0**: ignored; logged as a data error.

**Other**

- **If the game is paused**: no ticks run; windows don't move.
- **If a slot leaves** (Inactive / Empty): the chain drops (LEFT) and the slot leaves the team-chain check.
- **The ghost:** `ghost_visible = (last_dropped > 0 AND count == 0)`. It stays until the next chain starts; `last_dropped` is only overwritten by the next drop.
- **If hits land while Frozen**: milestones still fire and the ghost clears as normal.
- **If a bomb toll reduces a chain** (Rule 15): no milestone fires on the way down; climbing back over 50 / 100 / 200 fires them again, as after a drop.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Slot states (only Active slots chain or receive bonuses). Receives appended `max_chain_per_boss`. Its `boss_defeated` / `stage_cleared` events drive Rule 10. |
| Collision, damage and lives (6) — GDD | Hard | `chain_hit(slot, on_boss)` per counted hit (C5); `chain_drop(slot)` on death. Phase A events arrive before Phase B. |

**Inputs from other systems (contracts; every system below has a GDD as of 2026-11-03)**

| System | Interface it must provide |
|---|---|
| Boss and boss parts (14) — GDD (confirmed 2026-11-03) | `boss_started` (Intro end); `boss_defeated(reason, killer_slot)`; marks targets as boss part/core (for `on_boss`); part kill `add_bonus(slot, 5)`; gaps ≤ 45 ticks (F1) |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | `boss_started` (E5+480) / `stage_cleared` (`max(boss_gone, boss_defeated + 90)`) timing; wave gaps ≤ 45 ticks (F1), enforced by its validator |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Scoring (8) — GDD | Hard | Receives `hit_counted(slot, count_after, on_boss)` per applied hit (added 2026-11-03), `chain_multiplied`, team events and Frozen state. Cap handled by Scoring F4 (uncapped CB basis) and F6 (cap-hold streak). |
| Powerups and drops (13) — GDD | Soft | Sends chain pickup `add_bonus(slot, 10, "chain_pickup")`; refills the window, not a hit. |
| Bombs (12) — GDD | Hard | Sends `apply_bomb_toll(slot, pct)` (Rule 15) before its damage; bomb hits never reach the chain (Collision `counts_chain = false`). |
| Critical Break (17) — [GDD](critical-break.md) | Hard | Sends `apply_critical_break(slot)` at step 6b (before `boss_defeated`), gets the new count; cap handled by Scoring F4 (uncapped `raw`). Resolved 2026-11-03. |
| Co-op and Team Chain (18) — GDD | Hard | Receives `team_chain_started(slots)` / `team_chain_ended()`, reads `team_members()`; sends `set_team_exempt(slot, bool)`. Owns what the bonus pays and the join-grace flag. |
| Enemy and AI (10) — GDD | Soft | No interface; enemy kills add no chain bonus (only boss part kills do). |
| HUD (20) — [GDD](hud.md) | Hard | Reads `count`, window ratio, `last_dropped`, `red`; listens to `chain_dropped`, `chain_milestone`, `chain_multiplied`. |
| Stage tally (21) — [GDD](stage-end-tally.md) | Soft | Reads `max_chain_per_boss` from Session. |
| VFX (25), Audio (24) | Soft | Listen to `chain_milestone`, `chain_dropped`, `chain_multiplied`, `chain_reduced`. [VFX](vfx-and-screen-feedback.md), [Audio](audio.md) |
| Tutorial (30) — [GDD](tutorial.md) | Soft | Listens to `chain_dropped` (reason EXPIRED, for the chain-drop streak hint), `chain_reduced` (bomb toll drill), `team_chain_started` / `team_chain_ended` (team drill). *(2026-11-03, wave 4)* |

**Amendments to existing documents** (✅ applied 2026-11-03):

1. **Collision (6):** `chain_hit(slot)` → `chain_hit(slot, on_boss)` (Interactions, Dependencies, C5 output, AC-18); Boss (14) supplies the boss flag per target.
2. **Session (1) Rule 9:** "the window expires during the tally" → "chains drop when the tally starts (Chain Rule 10)".
3. **Art bible §7.3:** "drains … in 1 px steps" → "one visible step per tick, never more than 2 px" (F6).

**Bidirectional check:** Session lists "Chain tracker (7) — Hard — writes `max_chain_per_boss`"; Collision lists "Chain tracker (7) — Hard". The systems index already lists 7 as a dependency of 8, 13, 17, 18, 20, 21. Boss (14) and Wave director (16) must list the contracts above when written.

## Tuning Knobs

**Owned by this system** (chain rules `.tres`)

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `chain_window` | 60 ticks (1.0 s) | 45–90 | Ordinary retargeting drops chains; chain lives only during laser streams | Keeping it alive stops being tense; the bar never nears red | Boss/wave gap limit `G ≤ W − ceil(W/4)` (F1); HUD bar speed (F6) |
| `team_window` | 60 ticks | `chain_window`–120 | Team chains flicker; 4P nearly impossible | Team chain becomes automatic, no coordination | Must stay ≥ `chain_window`; player count via `team_window_step` |
| `team_window_step` | 8 ticks | 0–15 | 3–4P team chains rarely form | 4P team chain is automatic | `team_window`; Co-op (18) F3 owns the value (60 / 68 / 76) |
| `chain_cap` | 999 | 999 (locked) | — | — | HUD plate width (3 digits); F4 saturates from 317 |
| `cb_mult` | 3 | 1–5 | Break feels small next to just keeping the chain | Cap reached on most breaks (at 5: from 190) | `cb_add`, `chain_cap`; Critical Break (17) score |
| `cb_add` | 50 | 0–200 | A break on a small chain feels empty | Low-chain breaks become the dominant strategy | `cb_mult`; break-at-0 rule (gives `cb_add`) |
| `milestones` | [50, 100, 200] | ascending, each < 999 | Milestone feedback becomes noise | Players rarely see any | HUD plate edge steps, VFX, audio (art bible §7.3) |

**Owned elsewhere (pointers, not duplicated)**

- Part kill bonus +5 → Boss (14) (`part_kill_chain` in the prototype `combat_rules.tres`)
- Chain pickup amount → Powerups (13)
- Which hits count, laser/drone tick rates → Collision (6), Plane kits (11)
- Per-hit score from the chain → Scoring (8); Team Chain Bonus value → Co-op (18)
- Bar length and colours → HUD (20) / art bible §7.3

## Visual/Audio Requirements

The chain draws nothing itself; it sends events that presentation systems react to. Visual source of truth: **art bible §7.3**.

| Event | Visual (HUD 20 / VFX 25) | Audio (24) (P) |
|---|---|---|
| Hit (+1) | Numerals jump 2 px for 2 frames; bar refills in 2 steps | None (kits 11 own hit-tick sounds) |
| Window in last 25% (`red`) | 1 px Alarm Red end-cap at the bar tip, no blinking | Optional soft tick, max 1 per window; gamepad rumble pulse (§7.9) |
| `chain_milestone` 50 / 100 / 200 | Plate edge steps Cream → Gold → bright Gold; sparkles inside the plate | Rising chime, one pitch per milestone; max 1 per slot per tick |
| `chain_dropped` | Numerals fade to `#5A5148`, digits shift down 3 px inside the plate over 4 frames (HUD 20, 2026-11-03), ghost stays | Soft falling "tick-off"; none for STAGE_END |
| `chain_multiplied` | `xN` plate-local popup (CB flash/banner owned by Critical Break 17) | Owned by Critical Break (17) |
| `team_chain_started` / `ended` | 1 px Gold bracket linking plates + "TEAM" tag, no flash | Soft two-note link, once on start |

- **Readable Chaos:** none of these draw over the play field (the HUD strip is opaque and outside it).
- **Bar step amendment (F6):** §7.3 "1 px steps" → "one visible step per tick, never more than 2 px".

## UI Requirements

Data the chain provides to HUD (20), per slot, read-only:

| Field | Use |
|---|---|
| `count` | Plate numerals, 0–999 (3 digits, tabular) |
| `bar_px(slot, BAR_PX)`, `red` | Window bar and end-cap (F6) |
| `ghost_visible`, `last_dropped` | Dim ghost value |
| `team_chain_active` + slots | Team bracket |
| Events | Milestone / drop / multiply / team reactions |

> **📌 UX Flag — Chain tracker:** the chain plate and bar are HUD elements. Run `/ux-design` for the HUD (20) **before** writing HUD epics; stories cite `design/ux/hud.md`, not this GDD.

## Acceptance Criteria

Defaults used: `chain_window` W = 60, `team_window` 60, `chain_cap` 999, `cb_mult` 3, `cb_add` 50, `milestones` [50, 100, 200], 60 ticks/s, `BAR_PX` 94 (HUD 20). Slots 0-indexed. Tests read every number from the chain rules `.tres` (working name `data/chain_rules.tres`), never literals; quoted numbers are derived from it (e.g. `W − 1`, `cap − 1`).

**Test setup:** the logic lives in a plain `RefCounted` class `ChainTracker` with no nodes and no `delta`; `tick()` advances one 1/60 s step and keeps its own tick counter. Inputs before a tick (queued, arrival order): `set_slot_state(slot, state)`, `chain_hit(slot, on_boss)`, `chain_drop(slot)`, `add_bonus(slot, n, source)`, `apply_critical_break(slot)` (returns the new count), `apply_bomb_toll(slot, pct)`, `boss_started()`, `boss_defeated(reason, killer_slot)`, `stage_cleared()`. Outputs after a tick: `count(slot)`, `window_left(slot)`, `boss_hit_left(slot)`, `boss_peak(slot)`, `last_dropped(slot)`, `ghost_visible(slot)`, `team_chain_active`, `bar_px(slot, bar_len)`, `bar_red(slot)`, `events` (ordered: `chain_dropped(slot, value, reason)`, `chain_multiplied(slot, before, after)`, `chain_reduced(slot, before, after)`, `chain_milestone(slot, value)`, `team_chain_started(slots)`, `team_chain_ended()`), `warnings`, `state_hash()`. A Session stub records `max_chain_per_boss` appends. A Node adapter calls `tick()` from `_physics_process` and is tested separately. Tests: `tests/unit/test_chain_tracker.gd` (`extends SceneTree`; the existing file must first be migrated from seconds/`delta` to ticks — until then the [Unit] criteria are not covered), `tests/integration/test_chain_collision.gd`, `tests/perf/chain_bench.tscn`; manual evidence in `production/qa/evidence/chain-tracker/`. Names: `test_chain_tracker_[scenario]_[result]`.

Tags: [Unit] pure logic, headless · [Integration] real `CollisionReferee` / Session / HUD adapter · [Manual] needs a human · [Perf] REF-WEB (ADR-0001).

### Counting (Rules 1–4, F1, F2)

- **AC-01 [Unit] (Rule 1):** **GIVEN** slot 0 Active, count 0, **WHEN** `chain_hit(0, false)` and a tick runs, **THEN** count 1, `window_left` = W, `boss_hit_left` 0. With `on_boss = true`, `boss_hit_left` = `team_window + team_window_step × (a − 2)` with `a` clamped 2–4, so 60 at 1–2 Active slots (F3; amended 2026-11-03).
- **AC-02 [Unit] (Rule 2):** count 10, `add_bonus(0, 5, part_kill)` → count 15, window refilled. From 0, `add_bonus(0, 5)` starts a chain at 5.
- **AC-03 [Unit] (Rule 3, cap):** count = cap − 1, 3 hits on one tick → count = cap, no overflow, no warning. A hit or bonus at cap with 30 ticks left refills the window to W.
- **AC-04 [Unit] (Rule 4 / F2 off-by-one):** hit at tick 100 → `window_left` W at end of 100, W−1 at end of 101, 1 at end of 159; **drops at end of tick 160** (`chain_dropped(0, 1, EXPIRED)`). A hit on tick 160 is applied before the countdown; the chain survives with `window_left` W.
- **AC-05 [Unit] (F1 gap example):** hit at 100, no hits for 40 ticks → `window_left` 20 at end of 140 (`bar_red` true), alive. A 58-tick gap leaves 2; a 60-tick gap drops it.
- **AC-06 [Unit] (Rule 4, idle):** a slot at count 0 never ticks down: `window_left` 0 for 600 ticks, no events, no warnings.

### Dropping (Rules 5–6)

- **AC-07 [Unit] (Rule 5):** count 187, `boss_hit_left` 30, `chain_drop(0)` → `last_dropped` 187, count 0, `window_left` 0, `boss_hit_left` 0, exactly one `chain_dropped(0, 187, DEATH)`. A second `chain_drop(0)` at 0 emits nothing; `last_dropped` stays 187.
- **AC-08 [Unit] (Rule 6, reasons):** one scenario per reason — EXPIRED (AC-04), DEATH, STAGE_END (AC-19), LEFT (AC-35) — each emits exactly one event with the matching reason.

### Critical Break (Rule 7, F4)

- **AC-09 [Unit] (F4 table):** returns 50 → 200, 100 → 350, 150 → 500, 200 → 650, 316 → 998, 317 → 999 (raw 1001); each emits `chain_multiplied(slot, before, after)` and refills the window.
- **AC-10 [Unit] (CB at 0 and at cap):** from 0 → returns 50, starts a chain, refills the window. At 999 → returns 999, emits `chain_multiplied(0, 999, 999)`, refills the window.
- **AC-11 [Unit] (CB same tick as hits):** 2 hits then CB on count 40, one tick → multiply uses 42, returns 176. CB first then 2 hits → 170 + 2 = 172.
- **AC-12 [Unit] (CB non-Active):** Dying slot at 40 (or Inactive at 0) → returns the current count, no change, one `warnings` entry, no `chain_multiplied`.

### Boss record (Rules 8–10)

- **AC-13 [Unit] (Rule 8):** slot 0 count 70, slot 1 count 0, `boss_started()` → `boss_peak` 70 and 0.
- **AC-14 [Unit] (Rule 9):** boss alive, count 70 → 90 → drop → 20: `boss_peak` stays 90. A bonus of 30 from 80 → 110, peak 110.
- **AC-15 [Unit] (Rule 10, append):** `boss_defeated()` with peaks 187 (slot 0) and 90 (slot 1) → Session stub receives 187 and 90. A slot Inactive for the whole fight gets no entry.
- **AC-16 [Unit] (Rule 10, freeze):** at `boss_defeated` count 40, `window_left` 50 → after 300 hit-free ticks, still 40 and 50.
- **AC-17 [Unit] (death on boss-death tick):** peak 120; one tick with `chain_drop(0)` then `boss_defeated` → count 0, appended peak 120.
- **AC-18 [Unit] (hits while Frozen):** Frozen, count 40, peak 40, 5 hits → count 45, peak 40, record unchanged, window doesn't tick. Crossing 50 while Frozen still emits `chain_milestone(0, 50)`; `ghost_visible` clears.
- **AC-19 [Unit] (STAGE_END):** `stage_cleared()` with slot 0 at 45, slot 1 at 0 → `chain_dropped(0, 45, STAGE_END)`, `last_dropped` 45; slot 1 emits nothing and keeps its ghost. The chain is never written to Session.
- **AC-20 [Unit] (death mid-fight):** the peak keeps its highest value after a DEATH drop (AC-14).
- **AC-21 [Unit] (drop-in mid-fight):** a slot Active after `boss_started` starts with `boss_peak` 0, hits to 33 → append 33.
- **AC-22 [Unit] (continue mid-fight):** dies at peak 120, continues, reaches 80 → append 120; no reset in Session.
- **AC-23 [Unit] (Inactive mid-fight):** goes Inactive at 60 (peak 60) → LEFT drop; `boss_defeated` still appends 60.

### Team chain (Rules 11–12, F3)

- **AC-24 [Unit] (F3 example):** boss alive, P1 and P2 Active. P1 boss hit at 200, P2 at 240 → `team_chain_started([0,1])` at end of 240 (P1 has 20 left). No more hits → **ends at end of 260**, `team_chain_ended()` once. A P1 boss hit at 260 keeps it on.
- **AC-25 [Unit] (single / no boss):** one Active slot never starts a team chain. Two Active slots with no boss alive (or after `boss_defeated`) → always off; `team_chain_ended` fires on the tick the boss dies if it was on.
- **AC-26 [Unit] (not-boss hits):** `on_boss = false` hits never refresh `boss_hit_left`.
- **AC-27 [Unit] (2/3/4 players):** 2P: P2 Dying ends it that tick. 3P: P3 Dying → P1+P2 keep it (`|M|` = 2, every Active non-exempt slot in `M`), no `team_chain_ended`. 4P: starts only when every Active non-exempt slot is in `M` (each slot's `boss_hit_left` > 0, 76-tick window at 4 Active); an Absent or Continue slot is excluded. *(Amended 2026-11-03, Co-op (18).)*
- **AC-27a [Unit] (F3 window by Active count):** a boss hit with 2 / 3 / 4 Active slots sets `boss_hit_left` to 60 / 68 / 76 (`team_window` 60, `team_window_step` 8); 1 Active slot → 60. `a` is read at the hit tick: a slot already counting keeps its value when another player joins or dies. *(Added 2026-11-03, Co-op F3.)*
- **AC-27b [Unit] (join-grace exemption):** 3P, P1 and P2 in `M`, team chain on. P3 respawns and Co-op calls `set_team_exempt(2, true)`: the team chain stays on and `team_members()` = [0,1]. P3 hits the boss → `team_members()` = [0,1,2]. Without a hit, `set_team_exempt(2, false)` after 120 ticks → `team_chain_ended()` that tick. An exempt slot with `boss_hit_left` > 0 counts as a normal member. A lone non-exempt slot plus an exempt slot (`|M|` = 1) is never a team chain. *(Added 2026-11-03, Co-op Rule 13.)*
- **AC-28 [Unit] (restart):** after AC-24 ends, it restarts on the tick `|M|` ≥ 2 and every Active non-exempt slot is in `M` again (here: both slots have `boss_hit_left > 0`), with a new `team_chain_started`.

### Milestones (Rule 13, F5)

- **AC-29 [Unit] (F5 example):** CB 40 → 170 emits 50 then 100; no 200.
- **AC-30 [Unit] (single steps):** +1 hits through 49 → 51 emit 50 once; landing exactly on 100 emits 100; after a drop, climbing again re-emits 50; hits at cap emit nothing.
- **AC-31 [Unit] (bonus crossing):** bonus from 48 by 5 emits 50; bonus from 0 by 120 emits 50 then 100, same tick.

### Bonuses and edge cases

- **AC-32 [Unit] (bad bonus / non-Active):** `add_bonus(0, 0)` and `(0, −5)` → no change, no refill, one `warnings` entry each. `add_bonus` on a Dying, Absent, FlyIn, Continue or Inactive slot → ignored, no event.
- **AC-33 [Unit] (hits + death same tick):** count 49, 3 hits then `chain_drop` → `chain_milestone(0, 50)`, then `chain_dropped(0, 52, DEATH)`; `boss_peak` includes 52.
- **AC-34 [Unit] (pause):** `window_left` 30, adapter paused 30 s real time → still 30; after resume drops 1 per tick.
- **AC-35 [Unit] (slot leaves):** slot 0 at 60 with `boss_hit_left > 0` goes Inactive → `chain_dropped(0, 60, LEFT)`, `boss_hit_left` 0, excluded from the next team-chain check (a 3P team chain continues with the other two).
- **AC-36 [Unit] (ghost):** after a drop at 187, `last_dropped` 187 and `ghost_visible` true for 1,000 ticks; the next hit or bonus makes `ghost_visible` false; `last_dropped` changes only on the next drop.

### Determinism and sanity

- **AC-37 [Unit] (F7 sanity):** one hit per tick from 0 reaches 999 on tick 999; three per tick reach 999 on tick 333 (integer rates).
- **AC-38 [Unit] (determinism):** scripted 1,200-tick run (4 slots, hits, bonuses, 2 CBs, 2 deaths, a boss fight with continue and drop-in), run twice → `state_hash()` equal every tick.

### HUD bar (F6)

- **AC-39 [Unit] (F6):** 96 px, W = 60: `window_left` 60 → 96 px; 30 → 48 (not red); 16 → 26 (not red); 15 → 24 + red; 1 → 2 + red. Count 0 → ratio 0, 0 px; a live chain never shows 0 px. At 84 px: 30 → 42, 1 → 2. Over 60 consecutive ticks no step exceeds 2 px.

### Integration

- **AC-40 [Integration] (Phase A before Phase B):** real `CollisionReferee`: slot 2 lands a *destroyed* hit on a boss part and is hit the same tick → chain receives `chain_hit(2, true)` then `chain_drop(2)`; `last_dropped` includes the hit.
- **AC-41 [Integration] (on_boss flag):** Collision passes `on_boss = true` for boss cores/parts and false for popcorn; `boss_hit_left` reflects it. Ghost shots from a Dying slot produce no `chain_hit` (Collision AC-30); count stays 0.
- **AC-42 [Integration] (Session record):** real Session over two bosses → two entries per slot, in order; a continue between them doesn't reset the first. The chain itself is never saved or restored.
- **AC-43 [Integration] (events reach consumers):** HUD, VFX and Audio stubs each receive `chain_milestone`, `chain_dropped` and `chain_multiplied` in tick order, once each.

### Performance

- **AC-44 [Perf] (REF-WEB):** 4 slots, 300 events per tick (mixed hits and bonuses), 10,000 ticks → `tick()` ≤ 0.05 ms p99, no allocations after warm-up (no per-event `Array`/`Dictionary` outside a bounded log buffer). If the first measurement is below 0.01 ms, tighten to 0.02 ms.

### Manual (evidence in `production/qa/evidence/chain-tracker/`)

- **AC-45 [Manual] (milestones drive presentation):** 2P session, push P1 past 50, 100, 200 → HUD plate, VFX and audio each react once per crossing, in order. Evidence: clip + checklist. Presentation specs belong to HUD (20), VFX (25), Audio (24).
- **AC-46 [Manual] (ghost readable):** drop a chain at 187 by being hit → the ghost shows 187 for ≥ 1 s and is replaced on the next hit. Evidence: screenshot + note.

### Gap fixes (2026-11-02)

- **AC-47 [Unit] (team timer survives EXPIRED):** `team_window` 90, `team_window_step` 8, W 60, 2 Active slots (so `boss_hit_left` = 90). Boss hit at 100 → the personal chain drops (EXPIRED) at end of 160; `boss_hit_left` is still 30 then and reaches 0 at end of 190. A DEATH, LEFT or STAGE_END drop sets it to 0 at once.
- **AC-48 [Unit] (non-Active hit):** `chain_hit` for a Dying, FlyIn, Absent, Continue or Inactive slot → ignored, no count change, one `warnings` entry.
- **AC-52 [Unit] (bomb toll, Rule 15):** slot 0 Active, count 187, `window_left` 23, `boss_peak` 187, `last_dropped` 40: `apply_bomb_toll(0, 50)` → count 94, `window_left` 23 (not refilled), `boss_peak` 187, `last_dropped` 40, one `chain_reduced(0, 187, 94)`. Count 1 → stays 1. Count 0, Frozen or non-Active → no change, no event. *(Added 2026-11-03, Bombs 12.)*
- **AC-53 [Unit] (TIMEOUT record):** `boss_defeated(TIMEOUT, -1)` with peaks 120 and 80 → both appended and chains frozen, exactly as for KILLED. *(Added 2026-11-03, Boss 14.)*
- **AC-49 [Unit] ("in play"):** slot Active only on ticks 10–20 of a fight (then Continue, then Inactive) → its peak is appended. Slot Dying at `boss_defeated` but Active earlier → appended. Slot never Active during the fight → not appended. A slot that left and came back → one entry.
- **AC-50 [Unit] (freeze beats expiry):** a chain with `window_left` 1 on the tick `boss_defeated` arrives → Frozen with `window_left` 1, not dropped.
- **AC-51 [Unit] (two bosses in one stage):** `boss_started` → peak 80 → `boss_defeated` → `boss_started` (re-seeds `boss_peak` to the current count) → peak 120 → `boss_defeated` → Session receives two entries, 80 then 120.

> Criteria drafted by `qa-lead`; 5 gaps resolved by the user (2026-11-02): own team timer (survives EXPIRED), non-Active hits ignored + warning, "in play" = Active ≥ 1 fight tick, freeze beats expiry + multi-boss appends, `ghost_visible` rule and 0.05 ms budget.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~Laser + drones + shots reach the 999 cap in ~4.5 s. How do score and Critical Break stay meaningful at the cap?~~ **Closed 2026-11-03** by Scoring F4 (CB scored on uncapped `before × cb_mult + cb_add`) and F6 (cap-hold streak). Critical Break (17) may still add its own answer. | Scoring (8), Critical Break (17) | Done |
| 2 | ~~`team_window` 75 for 4P?~~ **Closed 2026-11-03:** 60 / 68 / 76 for 2 / 3 / 4 Active via `team_window_step` 8 (Co-op (18) F3). | Designer | Done |
| 3 | Is 60 ticks right with real fire rates and boss gaps? (Prototype feedback: yes.) | Designer | First playable boss |
| 4 | Migrate `chain_tracker.gd` + test from seconds/`delta` to ticks; move chain/score/CB out of `player.gd` | Programmer | Chain epic |
| 5 | ~~Audio cue pitches and rumble~~ **Closed 2026-11-03:** pitches closed by audio.md (chain window tick and cap-hold chime on by default); rumble moves to `access.rumble` / `access.chain_cue_rumble` (accessibility-options.md) (audio.md) | audio-director | Audio pass |
| 6 | Art bible §7.3 bar-step wording | art-director | Before HUD art |
