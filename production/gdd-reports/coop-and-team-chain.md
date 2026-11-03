# Report: Co-op and Team Chain Bonus (system 18)

## 1. File written
`D:\Projects\GodotProjects\Morutjan\morut-jan\design\gdd\coop-and-team-chain.md` (status: Designed, pending review; 46 acceptance criteria).

Co-op is a small rules layer over systems that already handle several players. It owns the player count `N`, the Team Chain Bonus value per member count, difficulty scaling by `N`, the friendly rules, and a join grace that stops a returning pilot breaking a running team chain. Chain (7) still owns detection; Session (1) still owns lives, continues and slot states.

## 2. Key decisions (all taken under auto-approve; the user can change any)
- **`N`** = slots in Alive, Dead or Continue (same set as Player plane PF5). Co-op owns this one definition for `play_top`, start spots, shot opacity, team bonus and scaling.
- **`team_pct` by member count `m`:** `120 + 10 × (m − 2)`, giving 2P 120, 3P 130, 4P 140. Solo and non-members get 100. Answers Scoring Open Question 2: 120 is modest on purpose (+3-4 % of a stage at 2P). 4P gets more because the chain is harder to hold. Guard: bonus share of a stage ≤ 10 % at full uptime (competent 3.4 / 5.1 / 6.6 %, expert 4.4 / 6.5 / 8.4 %). Competent 4P chain share is 67.0 %, which still passes Scoring AC-48.
- **Team window by Active count:** `60 + 8 × (a − 2)`, giving 60 / 68 / 76. This is a Chain F3 amendment and closes Chain Open Question 2.
- **Join grace:** 120 ticks (equal to `respawn_invuln`) after a slot becomes Active by respawn, continue or drop-in. While the slot's `boss_hit_left` is 0 it is exempt from the team-chain check.
  - New team test: boss alive, `|M|` ≥ 2, and every Active non-exempt slot is in `M`.
  - `M` = Active slots with `boss_hit_left` > 0.
  - Scoring pays only members at `team_pct(|M|)`; everyone else gets 100.
- **Team chain feedback:** HUD only, with nothing in the play field.
  - Gold bracket plus an icon tag with `+20 / +30 / +40` and no text (so no localisation).
  - A 2×2 px lamp per plate shows who has hit the boss recently; grace shows as an outline.
  - Audio is debounced: start cue at most once per 120 ticks; end cue only after a run of 180 ticks or more.
  - Art bible's optional boss-background pulse is off in MVP.
- **Lives and continues:** per player (confirmed). No shared pool, no transfers, **no revive**. Closes the game-concept open question.
- **Difficulty scaling:**
  - Hit points of MEDIUM, LARGE, PART and CORE: +50 % per extra player (100 / 150 / 200 / 250 %). SMALL is unscaled.
  - SMALL group size: +20 % per extra player, rounded up (100 / 120 / 140 / 160 %).
  - Pattern geometry, bullet counts and speeds are never scaled (Readable Chaos, and the fairness validator stays valid).
  - Scaling is read once at spawn (the boss at `boss_started`), so drop-in never changes hp mid-fight.
  - Wave data must pass a 4P density check against 1,700 and may set `coop_spawn_cap`.
  - Fight-length ratio vs solo is 0.94-0.96. This uses an assumed damage share η of 1.00 / 0.80 / 0.70 / 0.65, which needs measuring.
- **Friendly rules:** pass-through (existing); no friendly fire; first-come pickups, tie-break by fewer drones then lowest slot (provisional for Powerups 13); per-slot fair share of the player bullet pool, `floor(player_cap / N)` for `N` ≥ 2.
- **Pattern library Open Question 4:** keep per-emitter rotation for MVP and revisit only if a 4P playtest shows unfair snipes.
- **Score:** stays personal. No shared team score. Co-op high-score boards rank Session's `team_score`, with separate boards per player count (provisional for Save 26).
- **Stats:** `team_on_ticks`, `eligible_ticks`, uptime % and per-slot `team_bonus_points` go to the tally.

## 3. Amendments needed (apply at wrap-up)
1. **`design/gdd/chain-tracker.md`**
   - Rule 11 and Interactions: replace "every Active slot has `boss_hit_left` > 0" with "boss alive AND `|M|` ≥ 2 AND every Active non-exempt slot is in `M`, where `M` = Active slots with `boss_hit_left` > 0". Add the query `team_members()` and the input `set_team_exempt(slot, bool)` (exemption only matters while `boss_hit_left` = 0).
   - F3 and Tuning Knobs: `boss_hit_left = team_window + team_window_step × (a − 2)`, `a` = Active slots at the hit tick. Add knob `team_window_step` = 8 (range 0-15).
   - Open Question 2: close it, "60 / 68 / 76 (Co-op 18)".
   - Interactions and Dependencies, Co-op row: "owns what the bonus pays and the join-grace flag".
2. **`design/gdd/scoring.md`**
   - Interface: `set_team_pct(pct)` becomes `set_team_pct(slot, pct)` (100 for non-members). F1 `team_pct` row: "100 solo; 120 / 130 / 140 for 2 / 3 / 4 members (Co-op F1)".
   - S9, Dependencies and the Co-op row: "each team member" means a slot in Chain's `M`.
   - Add an info-only breakdown figure `team_bonus_points` (part of HIT, not a new source id).
   - Open Question 2: close it, "120 / 130 / 140 with the ≤ 10 % rule (Co-op F8)".
   - Test setup: `set_team_pct(slot, pct)`.
3. **`design/gdd/bullet-manager.md`**
   - Add a per-slot fair share of the player pool, `floor(player_cap / N)` when `N` ≥ 2, with a `refused_player_share` counter. Touches Rule 1 / F10, the knobs table and one AC.
   - Define `N` by reference to Co-op Rule 1 (V3 opacity).
   - Rule 16 and the Co-op row: "rotation confirmed by Co-op (18)".
4. **`design/gdd/bullet-pattern-library.md`**: close Open Question 4: per-emitter rotation is kept for MVP; reopen only if 4P playtest shows unfair snipes.
5. **`design/gdd/game-events-and-session.md`**: Co-op row now reads "reads slot states; owns `N`". Add `coop_count_changed(old, new)` to the provisional signal list (published by Co-op). Dependencies row for Co-op (18) now mentions grace and `N`.
6. **`design/gdd/player-plane.md`**: PF5 and Rule 15: `N` is defined in Co-op Rule 1. Dependencies: Co-op (18) row Soft → Hard (grace trigger).
7. **`design/gdd/game-concept.md`**: §14 close "Shared vs. per-player lives / continues in co-op" → per player. §13 risk "4P co-op floods screen": add "pattern density unscaled; hp and group-size scaling per Co-op".
8. **`design/art/art-bible.md`**: §4.4 and §5.6 still say other players' shots and drones are 50 %. Decided values are Bullet manager V3 (shots 100 / 75 / 50 % by count) and Player plane V6 (drones 100 %). §7.3: add the plate lamp and the `+NN` team tag.
9. **`design/gdd/systems-index.md`**: row 18 becomes `| 18 | Co-op and Team Chain Bonus | Ft | MVP | 1, 5, 7, 8 | **Designed** (pending review) — [GDD](coop-and-team-chain.md) |`. The Session dependency (1) is added. Progress tracker: 8 GDDs written (add "Co-op and Team Chain"). Dependency notes: Enemy (10), Boss (14), Wave director (16), Powerups (13) and Save (26) must list Co-op.
10. **Registry**: see section 4.

## 4. Registry candidates (`design/registry/entities.yaml`)
Update the existing `team_pct` entry:
```yaml
  - name: team_pct
    value: 120
    unit: percent on hit score during a team chain (2 members)
    range: "100-200"
    note: "Owned by Co-op (18). 2P base 120; +team_pct_step per extra member: 3P 130, 4P 140"
    source: design/gdd/coop-and-team-chain.md (F1)
    referenced_by: [scoring, coop-and-team-chain]
```
New constants:
```yaml
  - name: team_pct_step
    value: 10
    unit: percent per extra team member
    range: "0-30"
    source: design/gdd/coop-and-team-chain.md (F1)
    referenced_by: [coop-and-team-chain, scoring]
  - name: team_window_step
    value: 8
    unit: ticks added to team_window per Active player above 2 (60 / 68 / 76)
    range: "0-15"
    source: design/gdd/coop-and-team-chain.md (F3)
    referenced_by: [coop-and-team-chain, chain-tracker]
  - name: team_join_grace
    value: 120
    unit: ticks (exempt from the team-chain check while boss_hit_left = 0; equals respawn_invuln)
    range: "60-240"
    source: design/gdd/coop-and-team-chain.md (Rule 13)
    referenced_by: [coop-and-team-chain, chain-tracker]
  - name: coop_hp_step
    value: 50
    unit: percent hp added per extra player (MEDIUM, LARGE, PART, CORE; 100 / 150 / 200 / 250)
    range: "0-100"
    source: design/gdd/coop-and-team-chain.md (F4)
    referenced_by: [coop-and-team-chain]
  - name: coop_spawn_step
    value: 20
    unit: percent added to SMALL group size per extra player (100 / 120 / 140 / 160)
    range: "0-50"
    source: design/gdd/coop-and-team-chain.md (F5)
    referenced_by: [coop-and-team-chain]
  - name: team_bonus_share_max
    value: 10
    unit: percent of a stage total (upper bound with the team chain always on)
    range: "5-15"
    source: design/gdd/coop-and-team-chain.md (F8)
    referenced_by: [coop-and-team-chain, scoring]
```
New formulas: `team_pct_by_members` (`team_pct_base + team_pct_step × (m − 2)`, 100 for m < 2); `coop_hp_scale` (`(base_hp × (100 + hp_step × (N − 1)) + 50) / 100`); `coop_spawn_scale` (`(base_size × (100 + spawn_step × (N − 1)) + 99) / 100`); `team_window_by_active` (`team_window + team_window_step × (a − 2)`).

Add `coop-and-team-chain` to `referenced_by` of: `team_window`, `respawn_invuln`, `play_top`, `player_cap`, `enemy_cap`, `hit_score` (formula), `hit_base`, `chain_window`.

## 5. Conflicts with locked values or other GDDs
- **No locked values changed.** `team_pct` 120 stays as the 2P base. 3P / 4P values are an extension, and the registry note needs updating.
- **Chain tracker Rule 11** is amended (exempt slots, `M`). Co-op does not duplicate detection.
- **Scoring `set_team_pct(pct)`** changes to a per-slot form.
- **Art bible §4.4 / §5.6** (50 % other-player shots and drones) conflicts with Bullet manager V3 and Player plane V6. The latter two are the decided values.
- **Session** says Co-op "reads active slots". Co-op now also owns `N`, which includes Continue slots (same as Player plane PF5).
- **Scoring Rule S9** says "each team member". This GDD defines member as a slot in `M`.

## 6. Open risks
- **Team chain reward may be too small.** At 2P, full uptime adds only about 3-4 % of a stage. If playtest says it does not feel worth chasing, consider a one-off boss-kill team bonus (Open Question 1).
- **η(N) is an assumption.** Fight length (0.94-0.96 vs solo) depends on it. Measure before trusting `hp_step` 50.
- **4P team chain may be too hard or too easy.** `team_window_step` 8 and the uptime targets (60 / 50 / 40 %) are unplaytested.
- **Stacked deaths and the death clear.** One player's death clears the whole field, and `death_fire_hold` can be extended by repeated deaths. Four players can use this to relieve pressure or stall a boss. It needs a Collision rule (Open Question 5).
- **Drop-in mid-boss** changes `play_top` and shot opacity at the busiest moment.
- **Idle-pilot pressure:** one idle but alive pilot blocks the team chain for everyone until they die and leave. This is deliberate, but it may feel punishing.
- **Provisional contracts:** Powerups (13) pickups, Enemy (10) / Boss (14) hp scaling, Wave director (16) spawn scaling and the density check, Save (26) boards, and HUD (20) lamps all rely on systems with no GDD yet.
- **Wave data authoring:** every wave needs a 4P density check, which adds authoring work and may force `coop_spawn_cap` overrides.
- **Unfair-snipe risk in 4P:** per-emitter rotation was kept without playtest evidence.
