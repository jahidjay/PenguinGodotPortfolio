# Report: Boss power budget (system 15)

## 1. File written
`design/gdd/boss-power-budget.md` (all 14 required headings, 41 ACs). It defines a **mechanic** (PATTERN = family + behaviour + aim option + part role; or RULE = fight rule), a **power score Q** (F3) with weights, a **subset worst-case** boss score (F4), a **stage cap** `13 + 5 x stage` (18 / 23), **wave fractions** (0.32 / 0.36 / 0.40 / 0.45 / 0.75), the **mechanic lists** for both MVP bosses (4 each + the combination), a **preview transform** (F5), 14 lint checks (V1-V14) plus a stage lint, and the era-novelty rules. No per-tick code; runs at load and in tests.

Balance update (ref_dps 800, new hp) reviewed: `Q` never reads hp or dps, so no number changed. Added an edge case, AC-42 and an Open Question 1 note on carrier exposure time (gunner 1,200 hp dies in about 2.1 s at 560 hp/s).

## 2. Key decisions (auto-approve, user can change)
- Mechanics: Fortress = turret aimed fan, engine ring (core ring is a variant), armoured core (RULE), core spiral. Jet = accelerating fan (new behaviour), pod aimed stream, wing wall, radar lock (new option), plus armour carried from Stage 1 (no preview needed).
- `Q = 3*N/50 + 2*S + 2*L + 2*A + 2*B + 1.5*(M-1) + rule`; rule = 4 x (100 - armor_pct)/100.
- `Q_boss` = max over all subsets of destroyed non-core parts (<= 32). Enrage and Critical window excluded from the cap (enrage still must pass the 1,700 density check).
- Results: Fortress Q_boss **17.75** (cap 18, fill 0.986); Jet **22.14** (cap 23, fill 0.963); wave 5 = 12.48 / 14.48; boss/wave5 = 1.42 / 1.53.
- Preview rows (count/interval/speed %): 60/160/75, 65/150/80, 70/145/85, 75/140/90 (wave 5 reuses row 4). Intensity 0, gates bypassed, 1-arm spiral, lock tell +12 ticks, unscaled by co-op.
- Reduction lint: N <= 0.60 x boss N, v_eff <= 0.90 x boss v_eff.
- Armour previewed as a plated `heavy` (180 ticks, 50 %), inside the Enemy plating range.
- Era novelty: behaviour ladder Straight / Accelerate / Curve / Warp by stage; 1 new behaviour + 1 new aim option (aim lock = stage 2) per era; native enemies are stripped of a novelty before its debut wave.
- Added a new Jet pattern `core_lock_fan` (count 7, spread 0.1875, interval 120, speed 150, lock 30, gate [0.4,1], start_delay 48).
- Part role (orbit) not scored in v1.

## 3. Amendments
1. **systems-index.md**: row 15 status `**Designed** (pending review) — [GDD](boss-power-budget.md)`; Depends on `10, 14` -> `9, 10, 14`; progress tracker +1 GDD; Decisions-captured bullet 1 add "(detail in boss-power-budget.md)".
2. **enemy-and-ai.md**: spawn `params.preview` (mechanic id) swaps emitter 0 patterns, sets `intensity_source = CONSTANT(0)`, rule-preview plating override; novelty gating (`novelty_tags`; strip `lock_ticks` and Accelerate before the debut wave, affects the 1970s `fighter` row); Rule 19 WAVE intensity unused by previews; add Boss power budget (15) to Dependencies.
3. **boss-and-boss-parts.md**: close Open Question 8; Rule 2 `tags[]` convention `mech:<id>`; add Jet `core_lock_fan` to the core; bind Fortress `core_rage_ring` as variant of `m2_engine_ring`; Dependencies row 15 -> this GDD; Boss lint requires a `data/boss_budget/<id>.tres`.
4. **bullet-pattern-library.md**: expose F3/F8/F9 as pure functions (`PatternMetrics`); Boss row mentions 15; F9 example "Jet everything active about 116" is a gate-ignoring sum (true worst case 79.12 Jet / 154.90 Fortress); V4 note that one-new-trick-per-era is enforced by 15.
5. **Wave director (16)** (when written): schedule previews, run `check_stage`, apply novelty gating, `preview_alive_max` 1, `combo_window_ticks` 180, at least 2 successive carriers per preview wave.
6. **Era shift (19)** (when written): owns behaviour/option ladder and native-pattern stripping.
7. **coop-and-team-chain.md**: Interactions row for 15 (previews unscaled).
8. **game-events-and-session.md**: optional event `mechanic_previewed(boss_id, mechanic_id, wave)`.
9. **game-concept.md** section 10: note implemented by 15.
10. **entities.yaml**: entries below; add `boss-power-budget` to `referenced_by` of `lane_min_clear`, `enemy_plating`, `hit_radius_orb`, `hit_radius_rice`, `v_min`.

## 4. Registry candidates
```yaml
constants:
  - name: boss_budget_cap
    value: "cap_base 13, cap_step 5 (Q_cap = 13 + 5 x stage: 18 / 23 / 28 / 33)"
    unit: power score Q (dimensionless)
    range: "cap_base 8-18, cap_step 3-8"
    source: design/gdd/boss-power-budget.md (F4)
    referenced_by: [boss-power-budget, boss-and-boss-parts]
  - name: preview_wave_frac
    value: "0.32, 0.36, 0.40, 0.45, 0.75 (waves 1-5, fraction of Q_cap)"
    unit: fraction
    range: "increasing; W1 0.25-0.40, W5 0.6-0.85"
    source: design/gdd/boss-power-budget.md (F6)
    referenced_by: [boss-power-budget]
  - name: preview_transform_rows
    value: "count/interval/speed percent: 60/160/75, 65/150/80, 70/145/85, 75/140/90 (wave 5 = wave 4 row)"
    unit: percent
    source: design/gdd/boss-power-budget.md (F5)
    referenced_by: [boss-power-budget, enemy-and-ai]
  - name: mechanics_per_boss
    value: 4
    unit: previewable mechanics (waves 1-4; wave 5 = combination)
    source: design/gdd/boss-power-budget.md (Rule 2)
    referenced_by: [boss-power-budget, boss-and-boss-parts]
formulas:
  - name: power_score
    expression: "Q = 3*N/50 + 2*max(S) + 2*max(L) + 2*max(A) + 2*max(B) + 1.5*max(M-1,0) + sum(R); S = v_eff/150; L = min(2, 14/lane_clear); R = 4*(100-armor_pct)/100"
    variables: [N, S, L, A, B, M, R]
    output: "2-8 per mechanic; 13-23 per MVP boss phase"
    source: design/gdd/boss-power-budget.md (F3)
    referenced_by: [boss-power-budget]
  - name: preview_transform
    expression: "count*pct_c, interval*pct_i (>= base), max(70, speed*pct_s); intensity 0, gates bypassed, arms 1, lock+12, start_delay >= 48"
    variables: [pct_count, pct_interval, pct_speed]
    output: "derived read-only pattern per preview wave"
    source: design/gdd/boss-power-budget.md (F5)
    referenced_by: [boss-power-budget]
```

## 5. Conflicts
- No registry conflicts.
- Enemy GDD role table: 1970s `fighter` (aim-locked fan + accelerating rice) conflicts with "one new thing per wave"; resolved by novelty gating (amendment 2), needs Enemy/Era sign-off.
- Pattern library F9 Jet "about 116" figure (gate-ignoring sum) differs from subset worst case 79.12.
- Boss GDD Jet data has no aim-locked pattern; `core_lock_fan` is added here (amendment 3).

## 6. Open risks
- Weights, caps and fractions are untested; Jet wave 1 preview (6.66) sits at 0.905 of its cap.
- Short-lived gunner carriers (about 2.1 s at ref_dps 800) may show a wave 1-2 preview only once; needs Wave director carrier respawns.
- Wave 5 combination relies on the Wave director overlapping four carriers.
- Aim lock counted as a second "option" novelty needs creative director approval.
- Orbit role not scored; Plasma Ring (stage 4, Target) has no mechanic list.
- Did not update `production/session-state/active.md` (brief says edit no other file).
