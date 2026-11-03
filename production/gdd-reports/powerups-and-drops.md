# Report: Powerups and drops (system 13)

## 1. File written
`design/gdd/powerups-and-drops.md`. The GDD covers five item kinds: POD (+1 drone, max 4), CHAIN (+10 hits), MEDAL, 1UP and GEM. Only carrier enemies (flagged by their wave) drop PODs, CHAINs, MEDALs and 1UPs. Cancelled bullets become GEMs, capped at 100 per cancel by stride sampling. The drop tables are seeded and use a team pity counter. Items move by float-and-fall or auto-fly, and are collected only by Active planes. The GDD has 9 formulas, 52 acceptance criteria, an anti-grinding guardrail (Rule 2) and 12 amendments.

## 2. Key decisions (all auto-approved; change any of them)
- Five item kinds only. Items write only `drone_count`, `lives`, the chain count and score. They never touch damage, fire rate, bombs, meter or cooldown.
- Items per carrier drop = Co-op `N`, so pod income per player matches solo. A LARGE carrier gives a fixed bundle of N PODs + 1 MEDAL.
- SMALL table is POD 55 / CHAIN 25 / MEDAL 20. MEDIUM table is 50 / 20 / 30.
- Team pity limit is 2 (forced pod). The next SMALL/MEDIUM drop after any death is a recovery pod. This answers Enemy Open Question 6.
- Need check: a pod only drops if some Alive or Dead slot has fewer than 4 drones. Extra pods become medals.
- A plane at 4 drones skips PODs while a partner is below 4. If all are at 4, a pod pickup pays a MEDAL. This closes Session Open Question 4 and Scoring Open Question 6, and needs no new Scoring item kind.
- 1-up is fixed, not random: the 4th carrier destroyed in a stage drops one; at N ≥ 3 the 9th does too. It becomes a medal if everyone is at 6 lives. At max lives, picking one up pays gained 0 plus a medal.
- Chain pickup is +10 via `add_bonus(slot, 10, "chain_pickup")`. It refills the window, per Chain tracker Rule 2, and is not a hit.
- Gems: capped at 100 per cancel (`items_per_cancel_cap`), chosen by stride sampling. The same cap applies to bomb and kill-cancel. There is no value reduction for kill-cancels: the worst case is 110,000 per cancel, about 1% of an expert stage.
- Gem and drop pools are separate (300 and 24), so a bomb can't push out a pod.
- Gems hold 6 ticks, then pursue the cause slot's plane at 3 → 10 px/tick. If the cause slot is not Active, gems drift down and any Active plane can touch them. Dead and Continue slots collect nothing. This closes BM Open Question 6.
- Drop items pop (9.5 px, 18 ticks), then fall at 0.8 px/tick with a 6 px bob. They rest at y = 616 instead of leaving the screen. Lifetime is 600 ticks, 900 for a 1-up. They have a small magnet (36 px at 5 px/tick).
- Pickup radius is 14 px, owned here. Collection needs an Active plane. Death on the same tick wins over pickup.
- On `boss_defeated`, all items sweep to the nearest Active plane. Items left at `stage_cleared` are removed unpaid.
- Look: GEM is a plain 7 px gold diamond. MEDAL is a 15 px gold tile. CHAIN is a 15 px gold diamond with `+`. POD is a 17 px cream tile with a drone glyph. 1UP is a 17 px cream tile with a gold rim. All draw on layer 6.
- Determinism: one drop stream per stage, `hash(run_seed, stage_index, "drops")`, with a fixed 4 draws per `drop_requested`.
- Perf budget: `tick()` ≤ 0.15 ms p99 and pack ≤ 0.10 ms on REF-WEB, with 300 gems + 24 drops.

## 3. Amendments (exact edits for the main session)
1. **systems-index.md row 13:** Status → `**Designed** (pending review) — [GDD](powerups-and-drops.md)`. Depends on `6, 7, 8, 10, 11` → `1, 3, 5, 6, 7, 8, 10, 18` (11 becomes indirect only). Progress tracker: GDDs written 14, and add Powerups and drops to the list.
2. **enemy-and-ai.md:**
   - Interactions row for Powerups (line ~170): `drop_requested(pos, killer_slot, def_id, kill_class)`.
   - Close Open Questions 3 and 6. Kill-cancel items use cap 100 with no value reduction. Carrier cadence is 8 per stage (4 SMALL, 2 MEDIUM, 2 LARGE), and the recovery pod is owned by Powerups.
3. **bullet-manager.md:**
   - Close Open Question 6. Items fly only to an Active cause slot; gems from a non-Active cause slot drift and any Active plane can collect them.
   - The cancel hand-off must supply bullets in pool-index order plus the count. Powerups does the stride sampling.
4. **scoring.md:**
   - The interface is `item_collected(slot, kind, count)`, with the collector's chain count read by Powerups.
   - Close Open Questions 3 and 6.
   - F7 assumes 25/40/40 medals per stage, but medals drop only from carriers. Change it to about 3 / 4 / 4. The chain share goes up, so AC-48 is unaffected.
   - Edge case "cap 100" becomes a fact.
5. **game-events-and-session.md:**
   - Add `add_powerup(slot) -> int` and `add_oneup(slot) -> int` (gained).
   - Close Open Question 4.
   - F1 `powerups_collected` range 0–2 → 0–4 per frame (N = 4).
6. **chain-tracker.md:** Powerups interface row. Amount 10, source `"chain_pickup"`, refills the window.
7. **coop-and-team-chain.md:**
   - Rule 10: add "a plane with 4 drones skips a POD while another Active plane has fewer".
   - Add "the tie-break applies to all item kinds".
   - Add "Dead/Continue/Selecting planes collect nothing".
   - Close Open Question 7. Items per drop = N.
8. **player-plane.md:** Powerups row, pickup radius 14 px from the plane centre.
9. **plane-kits-lancer-leech.md:** edge case "powerup at 4 drones" → a pod at 4 drones is skipped if a partner needs it, otherwise it pays a MEDAL.
10. **art-bible.md:**
    - §4.6 / §5.7: add item sizes (gem 7, medal 15, chain 15, pod 17, 1UP 17).
    - The `+` diamond stays reserved for CHAIN; GEM is a plain diamond.
11. **Wave director GDD (when written):** at least 8 carriers per stage (4 SMALL, 2 MEDIUM, 2 LARGE), at least one per wave, spaced at least 180 ticks apart, and not scaled with N.
12. **Bombs GDD (when written):** bomb cancels obey the cap and make no medals.

## 4. Registry candidates
```yaml
constants:
  - name: items_per_cancel_cap
    value: 100
    unit: gems per cancel request (stride-sampled)
    range: "50-200"
    source: design/gdd/powerups-and-drops.md (F3, F9)
    referenced_by: [powerups-and-drops, scoring, enemy-and-ai, bullet-manager]
  - name: pickup_radius
    value: 14
    unit: px (plane centre; collect when d <= pickup_radius + r_item)
    range: "10-20"
    source: design/gdd/powerups-and-drops.md (F6)
    referenced_by: [powerups-and-drops, player-plane]
  - name: chain_pickup_amount
    value: 10
    unit: hits (add_bonus, refills window)
    range: "5-25"
    source: design/gdd/powerups-and-drops.md (Rule 25)
    referenced_by: [powerups-and-drops, chain-tracker]
  - name: pod_pity_limit
    value: 2
    unit: non-pod SMALL/MEDIUM results before a forced pod
    range: "1-4"
    source: design/gdd/powerups-and-drops.md (F1)
    referenced_by: [powerups-and-drops]
  - name: item_pools
    value: "gem_cap 300, drop_cap 24"
    unit: items
    range: "gem 150-600, drop 12-48"
    source: design/gdd/powerups-and-drops.md (F7)
    referenced_by: [powerups-and-drops]
formulas:
  - name: cancel_item_sample
    expression: "stride = ceil(n / cap); gem iff pool_index mod stride == 0; kept = ceil(n / stride)"
    variables: [n, cap, stride]
    output: "0..cap gems (1350 -> 97)"
    source: design/gdd/powerups-and-drops.md (F3)
    referenced_by: [powerups-and-drops, bullet-manager]
  - name: pod_income
    expression: "P_pod = 1 / (1 + q + ... + q^L), q = 1 - p"
    variables: [p, L]
    output: "SMALL 0.605, MEDIUM 0.571; 5.56 pods per stage at full kill"
    source: design/gdd/powerups-and-drops.md (F2)
    referenced_by: [powerups-and-drops]
```
Existing entries whose `referenced_by` should gain `powerups-and-drops`: `max_drones`, `max_lives`, `item_base`, `item_chain_factor` (formula), `drone_count` (formula), `kill_cancel_radius`, `chain_window`, `hit_base` (no), `player_hitbox_radius` (no). Set: max_drones, max_lives, item_base, item_chain_factor, drone_count, kill_cancel_radius.

## 5. Conflicts
- No registry value is contradicted.
- Scoring F7 assumes 25/40/40 medals per stage, but this GDD gives medals only from carriers (about 2 to 4 per stage). Non-blocking; see Amendment 4.
- Art bible §4.6 reserves the `+` diamond for chain items, while Bullet manager V8 says score items are a "gold diamond". Resolved with a plain 7 px GEM and a `+` CHAIN.
- Session F1 allows 0–2 powerups per frame; N = 4 needs 0–4.

## 6. Open risks
- Carrier cadence (8 per stage) is a requirement for the unwritten Wave director.
- Pod income and rebuild time (0.85 stage) are unplaytested.
- The chain-pickup window refill is a lifeline. It is cheap (+10), but it needs a playtest.
- The sweep needs enough time between `boss_defeated` and `stage_cleared`. The assumption is ≥ 75 ticks.
- The Session/Boss/Wave/HUD interfaces are provisional.
- The 14 px pickup radius depends on the final plane art.
- The perf budget is untested.
