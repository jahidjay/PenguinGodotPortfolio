# Co-op and Team Chain Bonus

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (UX amendments wave 5)**: Open Question 8 closed - co-op boards hold one team entry per board, ranked by `team_score`, separate boards per player count, one team rank shown.
> **Implements Pillar**: Every Hit Counts (Team Chain Bonus), Readable Chaos (4P screen), Four Planes, Four Games (each kit helps a team differently)

## Overview

**The data layer:** Co-op is a small rules layer that sits on top of systems that already handle multiple players. It owns five things. (1) The **player count** `N`, which is the one definition every other system uses for `play_top`, start spots, shot opacity and difficulty. (2) The **Team Chain Bonus value**: Chain tracker (7) detects a team chain, and Co-op decides what it pays, per player count. (3) **Difficulty scaling by player count**: enemy hit points, small-enemy group size, and a density check against the 1,700-bullet budget. (4) The **friendly rules**: no friendly fire, first-come pickups, a fair share of the player-bullet pool, and **no revive**. (5) The **join grace** that stops a returning or joining player from breaking a running team chain. Lives, continues, drop-in states and chains stay where they are: per player, in Session (1) and Chain (7). Co-op is a node-free class with `tick()` (ADR-0001); every value lives in `data/coop_rules.tres`.

**The player impact:** local co-op is a headline feature (1-4 players). This system makes it feel like one team without turning it into a different game. Every player keeps their own chain, lives, score and plane. The team gets one shared goal on the boss: all hit it inside one window and every member's hits pay more. A joining or returning pilot never costs the others their bonus. Bigger teams get a bigger bonus and tougher enemies, but never more bullets per enemy, so the curtain stays as readable in 4P as in 1P (**Readable Chaos**).

## Player Fantasy

**Anchor moment: the bracket links.** Two pilots are chasing different boss turrets. One drifts off, the other tags the core, the first swings back and lands a hit with 20 ticks to spare. A gold bracket snaps between their plates and both scores start to climb faster. Nobody said a word. They just *read* each other.

- **We are in this together, but each of us still owns our run.** Chain, score, lives and continues are personal. Nobody can drain a partner's lives or lose a partner's chain. The team bonus is a reward for flying at the same target, not a shared pool to fight over.
- **Coordination you can see.** A small lamp on each plate shows who has hit the boss recently. If the bracket is missing, you can see who is missing it.
- **A pilot who comes back is welcome.** After a death, a continue or a drop-in, the returning plane gets a short grace period. It cannot break the team's bonus while it flies back to the boss.
- **Bigger team, bigger payoff, same readable curtain.** 3P and 4P earn a larger bonus because the team chain is harder to hold. Bullets per enemy do not rise. The enemies get tougher and the waves get a bit denser, so four pilots still have something to shoot.
- **Arcade honesty.** There is no revive. If you die, you pay for it, and your partners fly on. The cost of dying is yours.

It serves **Every Hit Counts** (the team chain is a multiplier on the chain hits that already count) and **Readable Chaos** (scaling never touches pattern density; the 4P screen keeps the shot-opacity and ring-pattern measures).

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

**Player count `N`**

1. **`N` = the number of slots in state Alive, Dead or Continue** (the same definition as Player plane PF5). Selecting, Inactive and Empty do not count. `N` is clamped to 1-4. Co-op publishes `N`, and emits `coop_count_changed(old, new)` once on each change. *(2026-11-03, wave 4:)* `N` is live (hp/spawn scaling, opacity read it as before), but `play_top` is **latched** from `N` (Rule 2); the two may differ until the next latch.
2. **Everything keyed to player count reads this `N`:** `play_top` (48 for `N` <= 2, 72 for `N` >= 3; **latched** at `stage_started` and `wave_started` only — a drop-in or `N` change mid-wave or mid-boss keeps the current `play_top` until the next latch, which during a boss fight is the next stage; the HUD layout mode follows the latched `play_top`; gameplay never reads the HUD display mode — decided 2026-11-03, wave 4), start spots (Player plane PF5), shot opacity (Bullet manager V3: 100 / 75 / 50 % at N = 1 / 2 / 3-4), team bonus lookup, hit-point scaling and spawn scaling. No other system defines its own count.
3. A slot in Continue still counts, so a 10 s continue prompt never flips the HUD layout or the shot opacity. `N` falls only when a slot becomes Inactive.

**Lives, continues, drop-in (confirmed, not changed)**

4. **Lives and continues are per player** (Session Rule 5-6). There is no shared life pool and no transfer of lives, drones or bombs between players. This closes the game-concept open question "shared vs per-player lives".
5. **No revive.** A player in Dead or Continue returns only by Session's own rules (respawn delay, or accepting the continue). No partner action or pickup brings them back.
6. **Drop-in and drop-out** (states owned by Session Rules 7-8). Gameplay rules added here:
   - A joiner flies in to the start spot for the new `N` (Player plane PF5) and gets the normal respawn invulnerability (Collision C3).
   - Enemies and bosses already in play **keep their hit points**. Scaling is read once when the enemy spawns (Rule 14).
   - A joiner, a respawned plane and a continued plane all receive **join grace** (Rule 11).
   - A player who goes Inactive is dropped from the team-chain check (Chain Rule 5, reason LEFT). The others keep their team chain if two or more members remain.

**Friendly rules**

7. **Planes pass through each other** (Player plane Rule 14). No pushing, no blocking, no plane-to-plane damage.
8. **No friendly fire.** Player-pool bullets, lasers, drone attacks, bombs and Critical Break effects never hit a plane's hitbox. The Bullet manager tests the player pool only against enemies, and enemy bullets only against players.
9. **Shared field effects help everyone.** A bomb's or a part kill's bullet cancel and a death clear affect the whole field and benefit every player. Score items from a cancel are credited to the cause slot for value only when that slot collects them (Rule 10; Powerups 13 owns the items). Bomb cancel items on same-tick bombs go to the first bomber in rank order (Bombs (12) Rule 31); bomb hits never refresh `boss_hit_left` (Bombs Rule 32). *(Amended 2026-11-03.)* The Sentry Bastion dome and the Breaker Erase Net are shared field effects too (no items; any stock/credit goes to the requester; Sentry/Breaker (29), wave 4).
10. **Pickups are first come, first served** (contract confirmed by [Powerups (13)](powerups-and-drops.md), 2026-11-03; items per carrier drop = `N`):
    - A pickup is collected by the first plane whose pickup radius overlaps it. A pickup is never reserved for the player who made it drop.
    - If two or more planes overlap it on the same tick, the plane with **fewer drones** wins; if equal, the **lowest slot** wins. This lets a powerup go to the player who needs it.
    - A plane with 4 drones skips a POD while any other Active plane has fewer. The tie-break applies to all item kinds. Dead, Continue and Selecting planes collect nothing (Powerups (13)).
    - Score items still auto-fly toward their cause slot (Bullet manager Rule 14), but any plane that touches one first collects it and is paid from its own chain (Scoring F3).
11. **Fair share of the player-bullet pool** (*amendment to Bullet manager*): while `N` >= 2, a slot may not hold more than `floor(player_cap / N)` live player-pool bullets; further requests from that slot are refused and counted as `refused_player_share`. With `N` = 1 the slot may use the whole pool. This stops slot 0 from starving slot 3 when the pool fills. Plane kits (11) never exceed 48 live bullets per slot (Kits K10), so at 4P (share 150) a kit is never refused. Target kits stay inside it: Sentry ≤ 46, Breaker ≤ 40 (Sentry/Breaker (29), 2026-11-03).

**Team Chain Bonus**

12. **Chain (7) owns detection; Co-op owns the value and the grace.** Chain reports a team chain with its **members** `M` (Active slots whose `boss_hit_left` > 0). The bonus value for a member is `team_pct(m)` where `m = |M|` (F1). Non-members and solo play use 100.
13. **Join grace.** When a slot becomes Active (after fly-in from a respawn, a continue or a drop-in), Co-op gives it `team_join_grace` ticks (default 120, equal to `respawn_invuln`). While the grace is running **and** the slot's `boss_hit_left` is 0, Co-op tells Chain the slot is **exempt**. Chain's team-chain test (as amended) is then: *the boss is alive, `|M|` >= 2, and every Active, non-exempt slot is in `M`.* An exempt slot that lands a boss hit joins `M` like any other. Grace is cleared when it runs out, when the slot dies, or when the slot leaves.
14. **Difficulty scaling is read once, at spawn.** Enemy hit points, small-enemy group size and boss hit points use `N` on the tick the enemy (or the boss, at `boss_started`) is created. Later changes in `N` do not change enemies already in play.
15. **What scales and what does not:**

    | Thing | Scales with `N`? | How |
    |---|---|---|
    | Hit points of MEDIUM, LARGE, boss PART and boss CORE | Yes | F4 |
    | Hit points of SMALL enemies | No | One-hit popcorn stays one-hit |
    | Group size of SMALL enemies in a wave | Yes | F5 |
    | Group size of MEDIUM / LARGE enemies | No | They get tougher, not more numerous |
    | Pattern geometry, bullet counts, speeds, intervals | **No** | Readable Chaos; the fairness validator stays valid for 1P-4P |
    | Aimed-pattern targets | Per emitter, rotating | Pattern library F4 (kept; Open Question 4 closed) |
    | Boss enrage timer | No | Expected fight length is nearly constant (F6) |

16. **Score stays personal.** Every player is paid their own S1-S10 (Scoring). The boss value is paid in full to each eligible player (Scoring edge cases). There is **no shared team score**; the team total is only a display and a high-score key (Rule 18).
17. **Co-op stats** (display and telemetry): per stage, Co-op counts `team_on_ticks`, `eligible_ticks` and each slot's `team_bonus_points` (F7, F2). The Stage tally (21) reads them. The stats reset on `stage_started` and the tally reads them once at its tick 0 (`stage_cleared`). *(Amended 2026-11-03, Stage tally.)*
18. **High scores** (Save 26, [GDD](save-settings-high-scores.md)): co-op runs are ranked by Session's `team_score` (sum of slot scores, F6 in Session), on separate boards for 2P, 3P and 4P. Solo has its own board. *(2026-11-03, Accessibility 28: if any slot's assist latches `run.assisted`, the whole co-op run is PRACTICE and unranked.)*

### States and Transitions

Co-op has no player-facing mode. It keeps two small pieces of state.

**Per slot: join grace**

| State | Meaning | → Next |
|---|---|---|
| None | No grace | Grace (slot becomes Active) |
| Grace (`grace_left` 120 → 0) | Counts down 1 per tick while the slot is Active. Exempt from the team test only while `boss_hit_left` = 0 | None (reaches 0, dies, or leaves) |

**Team-chain feedback state (shared)**

| State | Meaning | → Next |
|---|---|---|
| Off | No team chain | On (Chain `team_chain_started`) |
| On | Team chain running; `m` members | Off (Chain `team_chain_ended`) |

`m` can change while On (a member dies or a grace slot hits). Co-op recomputes each member's percentage every tick, and the change takes effect on the following tick (Scoring reads the state from the end of the previous tick).

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Session (1) | ← | Slot states (for `N`), `player_joined`, `player_slot_inactive`, `player_died`, `player_continued` |
| Player plane (5) | ← | Plane becomes Active (starts grace). Reads `N` for start spots and `play_top` |
| Chain tracker (7) | ↔ | ← `team_chain_started/ended`, `team_members()` (mask), `boss_hit_left`. → `set_team_exempt(slot, bool)` |
| Scoring (8) | → | `team_pct_for(slot)` each tick (100 for non-members). ← per-slot `team_bonus_points` for the tally |
| Bullet manager (3) | ↔ | → `N` for shot opacity (V3). → per-slot share of the player pool (Rule 11). ← `refused_player_share` count |
| Collision (6) | ← | `player_died(slot)`, `death_fire_hold` active (not used here; see Open Question 5) |
| Bullet pattern library (9) | — | Unchanged: per-emitter rotation. This GDD closes its Open Question 4 |
| Enemy (10), [Boss (14)](boss-and-boss-parts.md) | → | `hp_pct(N)` at spawn / `boss_started` (F4) |
| [Boss power budget (15)](boss-power-budget.md) | — | Mechanic previews are **unscaled** by `N` |
| [Wave director (16)](wave-and-stage-director.md) | → | `spawn_pct(N)`, density check (F5, run by the Director's validator V-D5); per-wave `coop_spawn_cap` is a `spawn_pct` limit (100-160, default 160 = none) *(Amended 2026-11-03.)* |
| [Powerups (13)](powerups-and-drops.md) | → | Pickup tie-break contract (Rule 10); items per drop = `N` |
| [HUD (20)](hud.md) | → | `N`, `team_chain_on`, `m`, `team_pct`, per-slot lamp state |
| [Stage tally (21)](stage-end-tally.md) | → | `team_on_ticks`, `eligible_ticks`, uptime %, `team_bonus_points` per slot (reset on `stage_started`, read at tally tick 0) |
| [Save (26)](save-settings-high-scores.md) | → | `team_score` ranking key and player-count board id |
| [Audio (24)](audio.md), [VFX (25)](vfx-and-screen-feedback.md) | → | `team_cue_start`, `team_cue_end` (debounced). VFX scales cosmetic density 100 / 100 / 80 / 70 % by `N` (VFX F2) |
| [Parallax (23)](parallax-and-environment.md) | — | No change at any `N`; the team background pulse stays off |
| [Accessibility (28)](accessibility-options.md) | ← | `run.assisted`: an assisted co-op run is unranked |

*(2026-11-03, wave 3b: every system named above now has a GDD; the contracts are no longer provisional.)*

> Decided under auto-approve (2026-11-03): `N` counts Alive/Dead/Continue; lives and continues stay per player; no revive; no friendly fire; first-come pickups with a fewer-drones tie-break; per-slot share of the player pool; join grace 120 ticks; scaling read once at spawn; no shared team score; co-op boards by player count.

## Formulas

All maths is integer. `/` is integer division. Values come from `data/coop_rules.tres`; Chain and Scoring constants are read from their own resources and never copied.

**F1. Team percentage by member count**

`team_pct(m) = team_pct_base + team_pct_step × (m − 2)`, for `m` = 2…4; `100` for `m` < 2 or a non-member

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Members | `m` | int | 2-4 | `|M|`, the Active slots with `boss_hit_left` > 0 at the end of the previous tick |
| Base | `team_pct_base` | int % | 100-200 (default **120**, registry `team_pct`) | Value at `m` = 2 |
| Step | `team_pct_step` | int % | 0-30 (default 10) | Added per extra member |
| Result | `team_pct` | int % | 100, or 120-140 at defaults | Whole percent passed to Scoring F1 |

**Output Range:** 120 / 130 / 140 for `m` = 2 / 3 / 4. Never above 200 (clamped at the registry range).
**Example:** `m` = 3 → 120 + 10 × 1 = **130**.

**F2. Bonus a team multiplier adds per hit** (Scoring F1 applied twice)

`hit_points(p) = ((hit_base + count_after) × p + 50) / 100`
`team_extra = hit_points(team_pct) − hit_points(100)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Hit base | `hit_base` | int | 10 | Scoring |
| Count after hit | `count_after` | int | 1-999 | From `hit_counted` |
| Percent | `p` | int % | 100-140 | F1 |

**Output Range:** 0 to 2 × the solo value × 0.4, i.e. at most 404 at count 999 and 140 % (1,009 → 1,413).
**Example:** count 150: solo 160; `m` = 2 → 192 (+32); `m` = 3 → 208 (+48); `m` = 4 → 224 (+64). Count 7: solo 17; 120 → 20; 130 → 22; 140 → 24.

**F3. Team window by Active count** (*Chain F3 amendment*)

`boss_hit_left = team_window + team_window_step × (a − 2)` on a boss hit, with `a` = Active slots on that tick, clamped to 2-4

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base window | `team_window` | int ticks | 60 (Chain, registry) | Window for 2P |
| Step | `team_window_step` | int ticks | 0-15 (default 8) | Added per Active player above 2 |
| Active count | `a` | int | 1-4 | At the hit tick; stored value is not changed later |

**Output Range:** 60 / 68 / 76 ticks for `a` = 2 / 3 / 4; 60 for `a` = 1 (irrelevant: no team chain). Stays within the registry range (up to 120).
**Example:** 4P, a boss hit on tick 500 → `boss_hit_left` = 76 → that slot stays "in" through the end of tick 576 if it does not hit again.
**Rationale:** each extra pilot must be near the boss in the same window, which lowers the chance the whole team qualifies. If each pilot is on the boss for 90 % of windows, all-in odds are 81 % at 2P and 66 % at 4P; the longer window recovers part of that. Playtest value (Open Question 2).

**F4. Hit-point scaling**

`hp_pct(N) = 100 + hp_step × (N − 1)`
`scaled_hp = (base_hp × hp_pct + 50) / 100` for MEDIUM, LARGE, PART, CORE; `scaled_hp = base_hp` for SMALL

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Players | `N` | int | 1-4 | Rule 1, read at spawn |
| Step | `hp_step` | int % | 0-100 (default **50**) | Added per extra player |
| Base hit points | `base_hp` | int | ≥ 1 | From the enemy or boss resource (1-player value) |
| Percent | `hp_pct` | int % | 100 / 150 / 200 / 250 | |

**Output Range:** `scaled_hp` ≥ `base_hp` (never lower). An armoured target's floor of 1 hp (Collision C4) is not scaled. For a boss, `critical_hp` and `core_main` are derived from the **scaled** core hp (Boss (14) F3); the enrage timeout is unscaled (F6).
**Example:** base 1,200: 1,200 / 1,800 / 2,400 / 3,000 for N = 1 / 2 / 3 / 4. Base 35 at N = 2: (35 × 150 + 50) / 100 = **53**.

**F5. Wave density scaling and budget check**

`spawn_pct(N) = 100 + spawn_step × (N − 1)`
`group_size = (base_size × spawn_pct + 99) / 100` (round up) for SMALL groups
`N_scene(N) ≈ N_scene(1) × spawn_pct(N) / 100`, required ≤ **1,700** (Pattern library F9, Bullet manager F10)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Step | `spawn_step` | int % | 0-50 (default **20**) | Added per extra player |
| Base size | `base_size` | int | ≥ 1 | SMALL group size at 1P |
| Scene bullets | `N_scene` | int | 0-1,700 | Pattern library F9 estimate for the wave's concurrent emitters |

**Output Range:** `spawn_pct` = 100 / 120 / 140 / 160. `group_size` ≥ `base_size`.
**Example:** base 6 → 6 / 8 / 9 / 10; base 5 → 5 / 6 / 7 / 8. Density: a wave with `N_scene(1)` = 900 → 1,440 at 4P (pass); 1,100 → 1,760 at 4P (**fails**: the wave's data must set `coop_spawn_cap` so its 4P count stays under 1,700). Boss patterns are unscaled, so a boss scene is the same at every `N`.
**Note:** the check is conservative: it scales the whole scene, although only SMALL groups scale.

**F6. Expected fight length by player count** (balance anchor for F4)

`duration_ratio(N) = hp_mult(N) / (N × η(N))`, with `hp_mult = hp_pct / 100`; 1.0 at N = 1

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Effective share | `η(N)` | float | (P) 1.00 / 0.80 / 0.70 / 0.65 | Fraction of a player's solo damage that lands in a team (dodging, dead time, overlapping targets). **Assumption, unplaytested** |

**Output Range (defaults):** 1.00 / 0.94 / 0.95 / 0.96.
**Example:** N = 4: 2.5 / (4 × 0.65) = 2.5 / 2.6 = **0.96**. N = 2: 1.5 / 1.6 = **0.94**.
**Check against Plane kits (2026-11-03):** `η` is dodge/overlap/dead-time only, not pool refusal. At 4P each slot has `floor(600/4)` = 150 player-pool bullets and a kit never exceeds 48 live (Kits K10), so `refused_player_share` is 0 and no damage is lost to the pool; every slot keeps its own drones, so a player's solo dps (Kits `ref_dps` 800 at 2 drones) is the right base for `η`. Solo fight lengths are now 45-55 s at `ref_dps` 800 (Boss F6), so the 0.94-0.96 ratios give 4P fights of about 43-53 s. No change to `η`.
**Use:** the fight stays within ±10 % of the solo length at every `N`, so the enrage timer (Boss 14) and chain-window targets (Chain F1) do not need a per-count value. Replace `η` with measured values after the first 2P-4P boss test.

**F7. Team uptime and bonus statistics** (display and tuning telemetry)

`uptime_pct = (100 × team_on_ticks + eligible_ticks / 2) / eligible_ticks`, 0 if `eligible_ticks` = 0
`team_bonus_points[slot] += team_extra` for each team-multiplied hit of that slot

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| On ticks | `team_on_ticks` | int | ≥ 0 | Ticks at end of which a team chain was on |
| Eligible ticks | `eligible_ticks` | int | ≥ 0 | Ticks with a boss alive and ≥ 2 Active slots |
| Uptime | `uptime_pct` | int % | 0-100 | |

**Example:** 1,260 on-ticks of 2,100 eligible → (126,000 + 1,050) / 2,100 = **60**.
**Targets (P):** a coordinated team holds ≥ 60 % (2P), ≥ 50 % (3P), ≥ 40 % (4P).

**F8. Team bonus health check** (upper bound, tuning guard)

`bonus_share(p) = (p − 100)/100 × S1_boss / (total + (p − 100)/100 × S1_boss)`

Assumes the team chain is on for **every** boss hit (the maximum). `S1_boss` is the boss-phase part of Scoring F7's S1 line; `total` is the solo stage total.

| Archetype | `S1_boss` | `total` (solo) | 2P (120) | 3P (130) | 4P (140) |
|---|---|---|---|---|---|
| Competent | 368,250 | 2,987,250 | 73,650 → **2.4 %** | 110,475 → **3.6 %** | 147,300 → **4.7 %** |
| Expert | 3,600,000 | 19,712,700 | 720,000 → **3.5 %** | 1,080,000 → **5.2 %** | 1,440,000 → **6.8 %** |

(Re-baselined 2026-11-03 to Scoring F7: boss hits 2,700 competent / 3,600 expert.)

**Rule:** `bonus_share` must stay ≤ **10 %** at every `N`. Because the bonus multiplies hits that already come from the chain, the chain-first ranking of Scoring F7 still holds: competent 4P chain share = 2,127,250 / 3,134,550 = **67.9 %** (≥ 65 %). Expert 4P is 87.4 % when the bonus is counted as non-chain, and 94.2 % when it is counted as chain-derived, which is the right reading.
**Answer to Scoring Open Question 2:** 120 % at 2P is a modest reward (+3-4 % of a stage) on purpose; it is a *thank-you for flying together*, not a build-around. The reward grows with team size to 140 % because holding the chain gets harder. Do not exceed ~10 % without re-running Scoring AC-48.

> Formulas proposed by Claude (game-designer); all numbers decided under auto-approve (2026-11-03): 120/130/140, `team_window` +8 per extra Active player, hp +50 % per extra player, small groups +20 % per extra player, `η` assumption table.

## Edge Cases

**Player count**

- **If a player is in Continue**, they still count in `N`; the HUD and shot opacity do not change until the slot becomes Inactive.
- **If a slot is Selecting (drop-in pick)**, it is not counted. `N` rises on the tick the slot becomes Alive (fly-in starts).
- **If `N` rises from 2 to 3 mid-boss**, shot opacity becomes 50 % at once, but `play_top` stays 48 until the next `stage_started` (latch, Rule 2); the boss never shifts mid-fight and keeps its hit points. Mid-wave, `play_top` becomes 72 at the next `wave_started`. *(Amended 2026-11-03, wave 4.)*
- **If `N` falls from 3 to 2**, opacity returns to 75 % at once and `play_top` returns to 48 at the next latch. Planes are never pulled up (Player plane edge case).
- **If all slots become Inactive**, `N` is 0 internally and treated as 1 for lookups; Session ends the run.

**Team chain and grace**

- **If a returning player (respawn, continue, drop-in) becomes Active in a 3P team chain**, the slot is exempt for up to 120 ticks, so `team_chain_ended` does not fire. If it lands a boss hit sooner, it becomes a member at the end of that tick.
- **If the grace runs out and the slot has not hit the boss**, it becomes required. The team chain ends at the end of that tick unless it hit on that same tick. It restarts when the slot lands its next boss hit (and the others are still in).
- **If only two slots are Active and one is in grace**, there is no team chain (`|M|` < 2) until the grace slot hits the boss. This matches the old behaviour of Chain Rule 11.
- **If a grace slot dies**, its grace is cleared; when it respawns it gets a new 120 ticks.
- **If a member dies in a 4P team chain**, `m` falls to 3 and the other three are paid at 130 % from the next tick.
- **If `m` changes during a tick**, hits on that tick use the end-of-previous-tick state (Scoring edge case); there is no mid-tick change.
- **If one player never attacks the boss** (idle, or has no hittable target), the team chain stays off for everyone. This is intended pressure. A truly idle plane is killed by bullets and leaves through Continue (10 s), which removes it from the check.
- **If the boss is invulnerable for longer than the team window** (immune core), `boss_hit_left` runs out for everyone and the team chain ends; it restarts when all are hitting again.
- **If the boss dies**, the team chain ends (Chain Rule 11); no bonus is paid after `boss_defeated`. All grace timers keep running.

**Scaling**

- **If a player joins while a wave is on screen**, the wave keeps its size and hit points. The next wave spawn reads the new `N`.
- **If the boss spawns at 1P and a second player joins during the fight**, boss hit points do not change. The boss HP bar is based on the hit points set at `boss_started`.
- **If `base_hp` is 1**, it stays 1 for SMALL; for a scaled class it becomes 2 at N = 2. Authors should not give scaled classes 1 hp.
- **If scaling pushes a wave over 1,700 at 4P**, the authoring check (F5) fails the wave data; the wave sets `coop_spawn_cap`. At runtime the Bullet manager still refuses requests at the 2,000 cap and counts them (Pattern library edge case).
- **If a stage's `N` is 1**, every scaling value is exactly the 1P base; no rounding can change it.

**Friendly rules**

- **If two planes overlap a pickup on the same tick**, the one with fewer drones wins; equal → lowest slot. A plane with 4 drones loses a powerup to a plane with 3.
- **If a slot hits its share of the player pool**, its extra shots are refused and counted; other slots are unaffected. With `N` = 1 the share is 600.
- **If one player's death clears all enemy bullets** (Collision rule), it helps every player. A player may therefore "sacrifice" a life to clear a curtain for the team. This costs them a life, their drones and their chain, so it is allowed and not rewarded.
- **If several players die within `death_fire_hold`**, Collision restarts or extends the hold; whether stacked deaths can freeze the boss is Collision's rule (Open Question 5).
- **If a player kills a boss part another player damaged**, kill credit follows Collision's `kill_credit_rotation`; Co-op adds no rule.

**Lives, drop-out, run end**

- **If one player has 0 lives and the others are Alive**, the run continues; Session handles their Continue prompt.
- **If every player is in Continue**, the stage keeps running and no team chain can exist (no Active slots).
- **If a pad disconnects mid-run**, the slot keeps its state (Session). Team-chain rules follow the plane's state.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Slot states, `player_joined`, `player_slot_inactive`, `player_died`, `player_continued`. Lives, continues and drop-in states are Session's. |
| Player plane (5) — GDD | Hard | Plane becomes Active (starts grace); start spots and `play_top` read `N`; pass-through (Rule 14); ring colour, pattern, pips (Rule 15). |
| Chain tracker (7) — GDD | Hard | `team_chain_started/ended`, `team_members()`, per-slot `boss_hit_left`; Co-op calls `set_team_exempt`. |
| Scoring (8) — GDD | Hard | `hit_points` formula (F1) and the `team_pct` input; `team_bonus_points` stat. |
| Bullet manager (3) — GDD | Soft | Shot opacity by `N` (V3), player-pool cap, `refused_player_share` counter. |
| Collision, damage and lives (6) — GDD | Soft | Death clear and `death_fire_hold` (read for edge cases); `respawn_invuln` (grace length default). |
| Bullet pattern library (9) — GDD | Soft | Per-emitter target rotation (kept as is). |
| Input and player mapping (2) — GDD | Soft | Drop-in and slot choice by Start press (Input F7); pause ownership in co-op (Open Question 9). *(Added 2026-11-03.)* |

**Inputs from upstream systems** *(all now have GDDs; contracts confirmed there — wave 3b, 2026-11-03)*

| System | Interface it must provide |
|---|---|
| Boss (14) — [GDD](boss-and-boss-parts.md) | Read `hp_pct(N)` once at `boss_started`; apply to PART and CORE; `critical_hp` / `core_main` derive from the scaled core hp (Boss F3). (Enemy (10) now has a GDD and uses F4 verbatim for MEDIUM and LARGE at spawn, `enemy-and-ai.md` F4; amended 2026-11-03.) |
| Wave and stage director (16) — [GDD](wave-and-stage-director.md) | Read `spawn_pct(N)` for SMALL groups (N read once at the group's first tick); run the F5 density check on every wave (validator V-D5); `coop_spawn_cap` = per-wave `spawn_pct` limit, 100-160 (Director Rule 2, F2). *(Amended 2026-11-03.)* |
| Powerups and drops (13) — [GDD](powerups-and-drops.md) | First-come pickups with the fewer-drones tie-break (Rule 10); items per drop = `N`. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| HUD (20) — [GDD](hud.md) | Hard | `N`, team-chain bracket and tag, per-slot lamps, `team_pct` readout. |
| Stage tally (21) — [GDD](stage-end-tally.md) | Soft | `team_on_ticks`, `eligible_ticks`, uptime %, `team_bonus_points` (reset on `stage_started`, read at tally tick 0). |
| Scoring (8) | Hard | Per-slot `team_pct_for(slot)` each tick. |
| Wave director (16), Enemy (10), Boss (14) | Hard | `hp_pct(N)`, `spawn_pct(N)`. |
| Save and high scores (26) — [GDD](save-settings-high-scores.md) | Soft | `team_score` key, player-count board id. |
| Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | Soft | Debounced team cues; VFX big-effect cap (V2) and density by `N`. |
| Parallax (23) — [GDD](parallax-and-environment.md) | Soft | None at any `N` (no team background pulse). |
| Accessibility (28) — [GDD](accessibility-options.md) | Soft | Assisted co-op runs are unranked. |
| Sentry, Breaker kits (29) — [GDD](plane-kits-sentry-breaker.md) | Soft (Target) | Rule 11 share (Sentry 46 / Breaker 40 live bullets); Rule 9 shared field effects (Bastion, Erase Net). |
| Tutorial (30) — [GDD](tutorial.md) | Soft | Team drill listens to `team_chain_started` / `team_chain_ended`; per-slot drill stamps. |

**Amendments to other docs (to apply at wrap-up):**

1. **Chain tracker (7)**
   - Rule 11 and Interactions: team chain = boss alive AND `|M|` >= 2 AND every Active, **non-exempt** slot is in `M`, where `M` = Active slots with `boss_hit_left` > 0. Add the query `team_members()` and the input `set_team_exempt(slot, bool)` (exempt only matters while `boss_hit_left` = 0).
   - F3 and Tuning Knobs: `boss_hit_left = team_window + team_window_step × (a − 2)`, `a` = Active slots at the hit tick; add knob `team_window_step` (8). Close Open Question 2 ("75 for 4P?") with 60 / 68 / 76.
   - Dependencies: Co-op (18) row now reads "owns what the bonus pays and the join-grace flag".
2. **Scoring (8)**
   - Interface: `set_team_pct(pct)` → `set_team_pct(slot, pct)`, per slot; 100 for non-members. F1's `team_pct` column: "100 solo; 120 / 130 / 140 for 2 / 3 / 4 members".
   - Rule S9 / Dependencies: "each team member" means a slot in Chain's `M`.
   - Add an informational breakdown figure `team_bonus_points` (part of HIT, not a new source id).
   - Close Open Question 2 (see F8: 120 / 130 / 140, ≤ 10 % rule).
3. **Bullet manager (3)**
   - Rule 1 / F10: per-slot fair share of the player pool, `floor(player_cap / N)` when `N` >= 2; new counter `refused_player_share`.
   - Define `N` by reference to Co-op Rule 1 (V3 opacity).
   - Rule 16: add "rotation rule confirmed by Co-op (18)".
4. **Bullet pattern library (9)**: close Open Question 4: per-emitter rotation is kept for MVP; reopen only if 4P playtest shows unfair snipes (Open Question 3 here).
5. **Game events and session (1)**: the Co-op row now reads "reads slot states; owns `N`". Add `coop_count_changed(old, new)` to the provisional signal set (Co-op publishes it; Session does not emit it).
6. **Player plane (5)**: PF5 and Rule 15: `N` is defined in Co-op Rule 1 (same set as PF5). Change the Co-op downstream row to Hard (grace trigger).
7. **Game concept §14**: close "Shared vs. per-player lives / continues in co-op" → per player. §13 risk "4P floods screen": add "pattern density unscaled; hp/group scaling per Co-op".
8. **Art bible**: §4.4 and §5.6 still say other players' shots/drones are 50 %. Bullet manager V3 (opacity by count) and Player plane V6 (drones 100 %) are the decided values; update the art bible accordingly. §7.3: add the plate lamp (V1) and the `+NN` tag.
9. **Systems index**: row 18 status `**Designed** (pending review) — [GDD](coop-and-team-chain.md)`; Depends on stays `5, 7, 8` and adds `1` (the Session dependency is missing); progress tracker 8 GDDs written. Downstream notes: Wave director (16), Enemy (10), Boss (14) and Powerups (13) must list this GDD.
10. **Registry**: see the report (new constants, `team_pct` note, `referenced_by`).

## Tuning Knobs

All in `data/coop_rules.tres` (working name).

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `team_pct_base` | 120 | 100-150 | Team chain feels pointless | Bonus rivals the chain (F8 > 10 %) | `team_pct_step`; Scoring AC-48 |
| `team_pct_step` | 10 | 0-30 | 4P gets no extra reward for a harder chain | 4P bonus exceeds the 10 % guard (at 30: 180 % → ~19 %) | F8 |
| `team_window_step` | 8 ticks | 0-15 | 4P team chain almost never forms | Team chain becomes automatic | Chain `team_window` 60, F7 uptime target |
| `team_join_grace` | 120 ticks | 60-240 | A returning pilot breaks the team's bonus | Slacking pilot gets a free ride for 4 s | `respawn_invuln` 120 |
| `hp_step` | 50 % | 0-100 | Bosses melt at 3P-4P; chains feel short | 4P fights drag; enrage pressure | F6 duration ratio; `η` |
| `spawn_step` | 20 % | 0-50 | Too few targets to keep 4 chains alive | Waves cross 1,700 at 4P | F5 density; Wave director |
| `eta_by_count` (assumption) | 1.00 / 0.80 / 0.70 / 0.65 | measured | — | — | F6 only; used to retune `hp_step` |
| `player_share_enabled` | on (N >= 2) | on / off | Off: slot 0 starves slot 3 when the pool fills | — | Bullet manager `player_cap` |
| `pickup_tiebreak` | fewer drones, then lowest slot | enum | Always lowest slot: P1 always wins | — | Powerups (13) |
| `team_cue_min_gap` | 120 ticks | 60-300 | Cue spam when the chain flickers | Missed cue | Audio |
| `team_end_cue_min_run` | 180 ticks | 60-600 | End cue on every flicker | End cue rarely plays | Audio |
| `uptime_targets` | 60 / 50 / 40 % | 30-80 | Playtest bar too easy | Bar unreachable | F7 |

**Owned elsewhere:** `team_window` 60 and detection → Chain (7); `hit_base` and the hit formula → Scoring (8); shot opacity 100 / 75 / 50 and `player_cap` 600 → Bullet manager (3); `respawn_invuln`, `death_fire_hold` → Collision (6); `play_top`, start spots → Player plane (5); lives, continues, drop-in → Session (1).

## Visual/Audio Requirements

Source of truth: `design/art/art-bible.md` (AB), HUD §7.2-7.3. Everything here is HUD-side or audio. **Nothing is drawn in the play field**, so no effect can sit over enemy bullets (layer 8). Numbers marked (P) are unplaytested.

**V1. Team chain feedback (HUD strip only)**

| Element | Spec |
|---|---|
| Bracket | 1 px Ember Gold `#FFC93C` line linking the chain plates of the members, as in AB §7.3. No flash, no pulse |
| Tag | Icon only: two linked chevrons, 12 × 8 px, Gold on Cabinet Char `#1E1B18`, drawn in the left lane of each member plate; the bracket links the plates (HUD 20 Rule 18). Followed by the number `+20`, `+30` or `+40` (= `team_pct − 100`) in D12 (12 px) Cream digits with the 1 px `#14110E` outline. No Latin or Bengali text, so it needs no localisation |
| Lamp | One 2 × 2 px square at the top-right inner corner of each chain plate (2 px inset). Lit Gold when the slot's `boss_hit_left` > 0, unlit `#5A5148` otherwise. Shown only while a boss is alive and ≥ 2 slots are Active. Never blinks |
| Grace | A slot in grace with `boss_hit_left` = 0 shows its lamp as a 1 px Gold outline (unfilled), so the team sees it is "protected, not yet in" |
| Not shown | No team bracket outside boss fights |
| Background pulse | **Off in MVP.** AB's optional warm pulse on the boss background is deferred, to keep the 4P field clean |

**V2. 4P readability measures** (a checklist of decided values; sources in brackets)

| Measure | Value | Source |
|---|---|---|
| Player shots | 100 / 75 / 50 % at `N` = 1 / 2 / 3-4; hit radii unchanged | Bullet manager V3 |
| Planes, drones | 100 % always | Player plane V1, V6 |
| Hitbox dot and ring | Never faded; 4 patterns (solid, dashed, dotted, double) and 1-4 pips | Player plane V4 |
| Spawn tag | P-colour pip tag for 2 s after fly-in | Player plane V5 |
| Death ring | Player colour and pattern, 40 → 80 px | Collision V1 |
| Strip and field | 72 px strip, 4 × 90 px columns, field starts y = 72 | AB §7.2 |
| Enemy bullet density | Unscaled by `N` | Rule 15 |
| Big-effect cap | At most 2 simultaneous death rings drawn in full; others use the compact ring | At most 2 full death rings, others compact (VFX 25 Rule 23; 2026-11-03) |

**A1. Audio** (audio-director to confirm (P))

- **Team start:** the soft two-note "link" (Chain's table), at most one per `team_cue_min_gap` (120 ticks), so a flickering chain never spams.
- **Team end:** one soft falling note, only if the team chain ran ≥ `team_end_cue_min_run` (180 ticks). Shorter chains end silently.
- **Voice cap:** one team voice at a time, lowest priority; dropped first in a busy 4P mix.
- **Lamps and grace:** silent.

## UI Requirements

Data Co-op gives the HUD (20), read-only:

| Field | Use |
|---|---|
| `N` | Layout (1P, 2P mirrored, 3-4P columns), `play_top` |
| `team_chain_on`, `m`, `team_pct` | Bracket, tag (`+NN`) |
| Per-slot `lamp_state` (lit / unlit / grace) | Plate lamp |

Data for the Stage tally (21) and Results (22): `uptime_pct` per stage and run, `team_bonus_points` per slot, and the co-op `team_score` (Session F6). Source labels are localisation keys (English + Bengali); the tag in V1 has no text.

📌 **UX Flag**: run /ux-design for the HUD (20) and Stage tally (21) before writing epics (team bracket, tag, lamps, co-op results layout).

Debug only (development builds): a co-op overlay showing `N`, each slot's `boss_hit_left` and grace, `m`, `team_pct`, F7 uptime, `refused_player_share`, and the scaled `hp_pct` and `spawn_pct` for the current `N`.

## Acceptance Criteria

Defaults used: `team_pct_base` 120, `team_pct_step` 10, `team_window` 60, `team_window_step` 8, `team_join_grace` 120, `hp_step` 50, `spawn_step` 20, `player_cap` 600, `hit_base` 10, `respawn_invuln` 120, `play_top` 48 / 72, 60 ticks/s. Slots 0-indexed.

**Test setup:** logic lives in a plain `RefCounted` class `CoopRules` with no nodes and no `delta`; `tick()` advances one 1/60 s step. Inputs before a tick (arrival order): `set_slot_state(slot, state)`, `slot_became_active(slot)`, `player_died(slot)`, `slot_left(slot)`, `team_members(mask)` and `team_chain(on)` from a Chain stub, `boss_hit_left(slot, ticks)`, `boss_started()`, `boss_defeated()`. Outputs: `n`, `play_top`, `team_pct_for(slot)`, `exempt(slot)`, `hp_pct(n)`, `scaled_hp(base, class, n)`, `spawn_pct(n)`, `group_size(base, n)`, `uptime_pct`, `team_bonus_points(slot)`, `player_share(n)`, `pickup_winner(slots)`, `events`, `warnings`, `state_hash()`. A seeded RNG is injected but Co-op uses none. A Node adapter calls `tick()` from `_physics_process` and is tested separately. Every number is read from `data/coop_rules.tres` and the chain / scoring resources, never literals. Tests in `tests/unit/test_coop_rules.gd`, `tests/unit/test_coop_scaling.gd`, `tests/integration/test_coop_chain_scoring.gd`, `tests/perf/coop_bench.tscn` (`extends SceneTree` style like `tests/unit/test_chain_tracker.gd`); manual evidence in `production/qa/evidence/coop/`. Names: `test_coop_[scenario]_[result]`.

Tags: [Unit] pure logic · [Integration] real Chain / Scoring / Session / Bullet manager · [Manual] needs a human · [Perf] REF-WEB (ADR-0001).

### Player count (Rules 1-3)

- **AC-01 [Unit] (Rule 1):** slots in Alive, Dead, Continue count; Selecting, Inactive, Empty do not. States (Alive, Dead, Continue, Inactive) → `N` = 3; with slot 3 Selecting → still 3; Selecting → Alive → 4.
- **AC-02 [Unit] (Rule 2):** `play_top` = 48 at `N` = 1, 2 and 72 at `N` = 3, 4, evaluated at the latch (`stage_started` / `wave_started`); `N` 2 → 3 mid-wave leaves `play_top` 48 until the next `wave_started`, mid-boss until the next `stage_started`. `coop_count_changed(2, 3)` fires once on the tick slot 2 becomes Alive and not again while `N` stays 3.
- **AC-03 [Unit] (Rule 3):** a slot enters Continue → `N` unchanged, no event; it expires to Inactive → `N` falls by 1, one event. `N` is clamped to 1-4; zero Alive/Dead/Continue slots reports `n` = 1 for lookups.

### Team percentage (Rule 12, F1, F2)

- **AC-04 [Unit] (F1):** `team_pct(m)`: m = 2 → 120; 3 → 130; 4 → 140; m = 1 or non-member → 100. With `team_pct_step` 30, m = 4 → 180; the result is clamped at 200.
- **AC-05 [Unit] (F2):** through the Scoring stub: count 150 → solo 160, 120 % → 192 (extra 32), 130 % → 208 (48), 140 % → 224 (64). Count 7: 17 / 20 / 22 / 24.
- **AC-06 [Unit] (state from T−1):** the team chain starts at the end of tick T → hits on T pay 100 %; hits on T+1 pay `team_pct(m)`. Same on end.
- **AC-07 [Unit] (m changes):** 4P team chain (140 %), slot 3 dies on tick T → hits on T+1 for slots 0-2 pay 130 %; slot 3 pays 100 %.
- **AC-08 [Unit] (non-member):** 3P: slots 0, 1 are members and slot 2 is Active but exempt with `boss_hit_left` 0 → slots 0 and 1 pay 120 %, slot 2 pays 100 %.
- **AC-09 [Unit] (solo and off):** `N` = 1, or two Active slots with no team chain, or a boss not alive → every slot pays 100 %.

### Join grace (Rule 13)

- **AC-10 [Unit] (start):** `slot_became_active(2)` at tick 1000 → `exempt(2)` true while `boss_hit_left(2)` = 0 for ticks 1000-1119; false from tick 1120.
- **AC-11 [Unit] (3P continues):** 3P team chain, slot 2 respawns and becomes Active, slots 0 and 1 keep hitting → no `team_chain_ended`; `m` stays 2 for 120 ticks.
- **AC-12 [Unit] (grace slot hits):** slot 2 lands a boss hit on tick 1050 → it is a member from the end of tick 1050; `m` = 3, percentage 130 % from tick 1051.
- **AC-13 [Unit] (grace expires):** slot 2 never hits the boss → at the end of tick 1119 it becomes required; with `boss_hit_left` 0 the team chain ends (one `team_chain_ended`). A boss hit on tick 1120 restarts it.
- **AC-14 [Unit] (2P):** slot 1 becomes Active in grace while slot 0 hits the boss → no team chain (`|M|` = 1) until slot 1 hits.
- **AC-15 [Unit] (all entry paths):** a continue-accept, a drop-in and a respawn each start a 120-tick grace. A death during grace clears it; the next Active tick starts a new one. A slot that goes Inactive clears it.

### Team window (F3, Chain integration)

- **AC-16 [Integration] (real Chain):** boss hit with `a` = 2 / 3 / 4 sets `boss_hit_left` = 60 / 68 / 76. `a` falling after the hit does not change the stored value. With `team_window_step` 0 it is 60 for all `a`.

### Scaling (Rules 14-15, F4-F6)

- **AC-17 [Unit] (F4 table):** `hp_pct` = 100 / 150 / 200 / 250 for `N` = 1-4. Base 1,200 → 1,200 / 1,800 / 2,400 / 3,000. Base 35 at N = 2 → 53. `scaled_hp` ≥ `base_hp` for every base 1-5,000 and every `N`.
- **AC-18 [Unit] (classes):** at `N` = 4, SMALL base 3 → 3; MEDIUM, LARGE, PART, CORE base 100 → 250. An armoured 1 hp floor is not scaled.
- **AC-19 [Unit] (read once):** an enemy spawns at `N` = 1, a second slot becomes Alive → its hp is unchanged; the next enemy spawn at `N` = 2 uses 150 %. A boss started at `N` = 1 keeps its hp when a player joins mid-fight.
- **AC-20 [Unit] (F5 group size):** base 6 → 6 / 8 / 9 / 10; base 5 → 5 / 6 / 7 / 8; base 1 → 1 / 2 / 2 / 2. MEDIUM and LARGE group sizes are unchanged at every `N`.
- **AC-21 [Unit] (F5 density):** `N_scene(1)` 900 → 1,440 at 4P (pass); 1,100 → 1,760 (fail, error text names the wave); the same wave with `coop_spawn_cap` 140 (a `spawn_pct` limit, Director Rule 2) gives 1,540 and passes.
- **AC-22 [Unit] (F6):** `duration_ratio` with default `η` = 1.00 / 0.94 / 0.95 / 0.96 (±0.005) for N = 1-4; every value within 0.90-1.10.
- **AC-23 [Unit] (pattern data untouched):** with `N` = 4, a loaded boss pattern resource has identical `count`, `interval`, `speed` and `spread` to `N` = 1 (resource hash equal). The pattern fairness validator (Pattern library F8) results are identical.

### Friendly rules (Rules 7-11)

- **AC-24 [Integration] (no friendly fire, Rule 8):** real `BulletField`, 4 planes, 120 ticks of full player fire, a bomb, a Critical Break effect → zero hits registered on any plane from the player pool; lives unchanged.
- **AC-25 [Unit] (pass-through, Rule 7):** two planes at the same position with opposite inputs each move at full speed (Player plane AC-26).
- **AC-26 [Unit] (pickup tie-break, Rule 10):** planes with 2 and 3 drones overlap a powerup on one tick → the 2-drone plane gets it. Equal drones → lowest slot. One plane overlaps first, on an earlier tick → it gets it regardless of drones.
- **AC-27 [Unit] (pool share, Rule 11):** `N` = 4, `player_cap` 600 → share 150. Slot 0 at 150 live bullets has a 5-bullet request refused (`refused_player_share` += 5) while slot 1 at 100 is accepted. `N` = 2 → share 300. `N` = 1 → no share limit.
- **AC-28 [Integration] (pool share with real field):** 4P stress, all slots firing at max rate for 600 ticks → no slot's live count exceeds 150; total ≤ 600; no slot is refused while below its share.

### Lives, continues, revive (Rules 4-6)

- **AC-29 [Integration] (per-player lives):** slot 0 dies → slot 1's lives, drones, chain and score are unchanged. No API on Co-op or Session moves lives or drones between slots (API lint).
- **AC-30 [Unit] (no revive):** a slot in Dead with lives > 0 becomes Alive only by the respawn timer. A slot in Continue becomes Alive only by accepting. No pickup, bomb or partner action changes either transition.
- **AC-31 [Integration] (drop-out):** 3P team chain, slot 2's continue expires → Chain emits LEFT for slot 2, slots 0 and 1 keep the team chain, no `team_chain_ended`, percentage 120 % from the next tick, `N` = 2.

### Statistics and health check (Rule 17, F7, F8)

- **AC-32 [Unit] (F7):** 1,260 on-ticks of 2,100 eligible → `uptime_pct` 60. 0 eligible → 0 with no warning and no divide by zero.
- **AC-33 [Unit] (team bonus points):** slot 0 lands hits at counts 150, 7 in a 2P team chain → `team_bonus_points` = 32 + 3 = 35. Hits outside a team chain add nothing.
- **AC-34 [Unit] (F8 table):** computed from the Scoring archetype table, `bonus_share` is 3.4 / 5.1 / 6.6 % (competent) and 4.4 / 6.5 / 8.4 % (expert) for 2P / 3P / 4P (±0.1). Test fails if any exceeds `bonus_share_max` (10 %).
- **AC-35 [Unit] (chain share):** competent at 4P: chain share (Scoring AC-48 definition) 2,127,250 / 3,134,550 = 67.9 % ≥ 65 %; re-run on any `.tres` change.

### Determinism and performance

- **AC-36 [Unit] (determinism):** a scripted 1,800-tick run (4 slots; 2 deaths, 1 continue, 1 drop-in, 1 drop-out, a boss fight, team chain on/off 6 times), run twice → `state_hash()` equal every tick.
- **AC-37 [Perf] (REF-WEB):** 4 slots, 10,000 ticks of mixed events → `tick()` ≤ **0.02 ms** p99, no allocations after warm-up. If the first measurement is under 0.005 ms, tighten the budget.

### Integration

- **AC-38 [Integration] (real Chain and Scoring):** 3P boss fight with real `ChainTracker` and `ScoringLedger`: a respawning slot in grace does not end the team chain; HIT awards for members equal `hit_points(130)`; the grace slot's awards equal `hit_points(100)` until its first boss hit.
- **AC-39 [Integration] (real Session):** `N` follows real Session states through a drop-in, a death, a continue and an expiry; the Bullet manager's opacity (75 → 50 → 75 %) follows `N` on the same tick; `play_top` follows `N` at the next latch.
- **AC-40 [Integration] (events):** HUD, VFX and Audio stubs receive `coop_count_changed` once per change, `team_cue_start` at most once per 120 ticks, and `team_cue_end` only for runs of ≥ 180 ticks.

### Manual (evidence in `production/qa/evidence/coop/`)

- **AC-41 [Manual] (4P readability):** a 4P screenshot during a curtain, shown for 1 s (colour and greyscale) → ≥ 5 testers identify a pointed-at plane's slot from pattern and pips in ≥ 95 % of trials; a tester can also point to the nearest enemy bullet to their own plane in ≥ 90 % of trials. Evidence: screenshots and results.
- **AC-42 [Manual] (team chain readable):** 2P, then 4P: a tester can say who is missing from the team chain by looking at the HUD alone, in ≥ 8 of 10 trials. The tag shows no text and the digits read in both languages.
- **AC-43 [Manual] (uptime):** coordinated teams reach uptime ≥ 60 % (2P), ≥ 50 % (3P), ≥ 40 % (4P) over three boss fights; below target for two of three sessions → tune `team_window_step` first, then `team_pct_step`.
- **AC-44 [Manual] (4P density):** a real 4P stage: peak enemy bullets ≤ 1,700, refusals < 0.1 % (Bullet manager AC-42), and boss fight length within ±10 % of the solo length (F6). Note any wave that needed `coop_spawn_cap`.
- **AC-45 [Manual] (return feels fair):** a tester dies and returns three times in a 3P boss fight; the surviving two keep their bracket through each return, and the returning tester understands why their lamp is an outline (≥ 4 of 5 testers).
- **AC-46 [Manual] (joining mid-boss):** a third pad joins during a 2P boss fight; the HUD layout and shot opacity change once, no hit is unavoidable because of it, and testers rate it "not disorienting" (≥ 4 of 5).

> Criteria drafted by Claude (game-designer) under auto-approve; `qa-lead` not consulted.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Is 120 / 130 / 140 enough reward? F8 says +3-8 % of a stage at full uptime. Does the team chain feel worth chasing, or does it need a visible one-off reward (a boss-kill team bonus)? | Designer | 2P / 4P playtest |
| 2 | Are `team_window_step` 8 (60 / 68 / 76) and the uptime targets 60 / 50 / 40 % right? | Designer | 4P playtest (Chain Open Question 2 closed by this default) |
| 3 | Is per-emitter target rotation fair in 4P (cross-screen snipes)? Fallback: nearest within range, else rotate. Kept for MVP. | Designer | 4P playtest |
| 4 | `η(N)` (effective damage share) is an assumption; measure it and retune `hp_step`. | Analytics / Designer | First 2P-4P boss test |
| 5 | Can stacked deaths (several players dying inside `death_fire_hold`) freeze the boss or keep the field clear too long? Needs a retrigger rule or cap. | Collision (6) GDD | Collision review |
| 6 | ~~Drop-in mid-boss changes `play_top` and opacity (2P → 3P) in the busiest moment. Accept (as designed), or delay the layout change until the next safe beat?~~ **Closed 2026-11-03:** `play_top` and the HUD layout are latched at `stage_started` / `wave_started` (mid-boss: next stage); opacity follows `N` at once (Rule 2; wave-4 decision) | UX / Designer | HUD UX spec, playtest |
| 7 | ~~Pickup sharing (Rule 10) and "who may collect a cancel item" are provisional contracts.~~ **Closed 2026-11-03:** Powerups confirms Rule 10: items per drop = `N`; a 4-drone plane skips a POD while another Active plane has fewer; the tie-break applies to all kinds; only Active planes collect (Powerups (13)). | Powerups (13) GDD | Powerups GDD |
| 8 | ~~Do co-op high-score boards rank `team_score`, or best single player in a team? Separate boards per count?~~ **Closed 2026-11-03** (Rule 18 and Save F2/F3): **one team entry per board, ranked by `team_score`, with separate boards per player count**. The display shows **one team rank** (Menus Rule 35/40), never a rank per player; the row shows the **lead player's** initials (highest `players[].score`, ties to the lower slot) plus a `+N` tile. | Save (26) GDD | Closed |
| 9 | ~~Who may pause and resume in co-op?~~ **Closed 2026-11-03:** Any bound slot pauses with Start/Back; the pausing slot owns the menu, others are ignored (Input Rule 25, Menus Rules 27-28). (menus-title-plane-select.md) | Menus (22) / Input (2) | Menus GDD |
| 10 | Does the Critical Break need a team variant (two players break together)? Out of MVP. *Note 2026-11-03:* MVP is breaker only; the first triggering slot in rotating rank order wins, losers get no refund ([Critical Break (17)](critical-break.md) F2). | Critical Break (17) GDD | Target tier |
| 11 | Art bible §4.4 / §5.6 still say other players' shots and drones are 50 %; update to the decided values (Amendment 8). | art-director | Before plane art |

> Decided under auto-approve (2026-11-03): per-count team percentage, no team background pulse in MVP, `+NN` icon tag without text, plate lamps, one bonus per member, and the list of recommended defaults in the Detailed Design and Formulas sections. All are open to user change.
