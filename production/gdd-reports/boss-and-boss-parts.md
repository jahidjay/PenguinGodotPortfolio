# GDD report: Boss and boss parts (system 14)

## 1. File written
`D:\Projects\GodotProjects\Morutjan\morut-jan\design\gdd\boss-and-boss-parts.md` (status Designed, pending review; 56 acceptance criteria, 11 formulas, 13 open questions).

A boss is a node-free `BossController` ticked at 60 Hz from a `BossDefinition` (max 6 parts, one core, at most 8 hurtboxes). It publishes hurtboxes and bodies, feeds emitters an intensity equal to the fraction of non-core parts destroyed, and applies Collision's hit results. The fight runs Intro, Parts, Exposed, Critical, then Dying (or Retreating on timeout). Part kills stop emitters, cancel 90 px (150 px for the last part), give +5 chain to the credited slot and pay 5,000. The core has a 15 % critical reserve and a 7 s window in which it cannot die from shots, so a Critical Break is always possible. An enrage ramp and a timeout stop stalling. The prototype code is described and corrected, and the 480 px data is migrated to 360 px (Fortress and Jet fully; Plasma Ring for Target).

## 2. Key decisions (auto-approve, recommended option each time)
- **Integer hp and percentages.** `core_armor_pct` 25, `critical_pct` 15 (replaces absolute `critical_hp` 200), `critical_armor_pct` 20.
- **Two-stage core.** Collision gets `core_main` hp; when it is "destroyed" in Exposed, the boss enters Critical and republishes the core with the reserve hp (same id and generation). This stops one big hit from skipping the critical band.
- **Critical window:** 420 ticks (7 s), core ARMOURED 20 % with a 1 hp floor, ends with the core NORMAL. `is_critical()` stays true until the core dies. CB owns the trigger and calls `critical_break_finish(slot)`.
- **Phases:** Parts, Exposed, Critical, with the core mode switching on the next tick (Collision snapshot). Intensity `I` = parts destroyed ÷ non-core parts; `I_eff = max(I, I_enr)`.
- **Part kill:** stop emitters with `owner_destroyed`, `request_cancel` 90 px (150 px for the last part), `add_bonus(slot, 5)`, event. The prototype screen flash is removed (art bible).
- **Intro:** 240 ticks (180 entrance, 60 hold). All parts IMMUNE (hits ignored, no chain) and non-lethal; no emitters armed. A clearance gate delays `boss_started` up to 180 ticks if a player overlaps.
- **Enrage and timeout:** `enrage_start = round100(1.75 × T_fight)` (Fortress 4,700, Jet 5,700, Plasma 5,500); the ramp lasts 600 ticks; timeout 1,200 ticks after enrage as `boss_defeated(TIMEOUT)`. Timeout means no boss value, no cap-hold from enrage, the boss withdraws. Using `boss_defeated` with a reason keeps the Session, Chain, tally and ending flows unchanged. The clock runs only while a slot is Active and not paused.
- **hp budget (F6):** reference dps 300 at 70 % uptime; new hp is Fortress parts 900/900/1,200/1,200 and core 6,200, Jet pods 700, wings 1,550, core 7,400. `T_fight` is 2,706 and 3,284 ticks (45 s and 55 s). The prototype hp (about 10 s) was far too low.
- **Laser:** `laser_query(x, half_width, y_origin)` returns the first part in the column (largest bottom, ties to the lowest index). IMMUNE parts block, dead parts and the hull do not.
- **Migration:** geometry ×0.75, anchor x 240 → 180, rad/s → integer-tick periods, 1/16 px quantized closed-form placement. Jet wings are thicker (`r_e` 9) so they fit 2 hurtboxes (Jet total is exactly 8).
- **Fire-zone rule:** bosses are exempt from the Enemy fire-zone arming; a placement lint replaces it. Emitters start at `boss_started`.
- **Part ids:** unique `id` replaces the duplicate `part_name` (it seeds each emitter's RNG).
- **Death:** `boss_defeated` fires on the first tick, with a whole-screen cancel (items to the killer), and a 180-tick explosion sequence follows. No per-part hp bars. Captions go in the HUD boss row, not over the field.

## 3. Amendments
1. **`design/gdd/systems-index.md`**, row 14: status `**Designed** (pending review) — [GDD](boss-and-boss-parts.md)`; Depends on `6, 9, 10` → `3, 6, 7, 8, 9, 10, 18`. Progress tracker: add Boss to the GDD count; remove 14 from "Code exists without GDD".
2. **`design/gdd/chain-tracker.md`**: Rule 8, add: "`boss_started` fires when the boss Intro ends; chains from wave 5 expire during the Warning and entrance, so a carried-in chain does not normally occur." Rule 10 / Boss row: `boss_defeated(reason, killer_slot)`; the record is appended and the chain freezes for every reason, including TIMEOUT.
3. **`design/gdd/scoring.md`**: S4 is paid only if `reason != TIMEOUT`; add the input `boss_cap_hold_allowed()` (false from `enrage_start` to the boss end) to F6 and AC-39; close Open Question 4; the Boss row in Dependencies points to the Boss GDD.
4. **`design/gdd/collision-damage-lives.md`**: Boss row (Interactions/Dependencies) adds `kill_class`, `on_boss`, `lethal`, and republishing of the core hp/mode/`armor_pct` between ticks under the same id (the published record is authoritative; later same-tick events on a destroyed target are ignored). Body radius note "cores 6–12 (placeholder)" → bosses up to 26 px (range 2–40 holds). Open Question 2 answered: `core_armor_pct` 25, crack overlay only in Critical (below `critical_hp`), not at 1 hp. `armor_mult` → `core_armor_pct`. Open Question 9 closed for bosses.
5. **`design/gdd/enemy-and-ai.md`**: Rule 18 and Interactions: "Boss (14) is exempt from fire-zone arming (placement lint instead)". Rule 23: the boss uses at most the 8 reserved hurtboxes. Boss row points to the GDD.
6. **`design/gdd/bullet-pattern-library.md`**: Boss row: intensity = `I_eff`; `owner_id` = unique part `id`; lint "patterns opening at I > 0 need `start_delay` ≥ 18".
7. **`design/gdd/bullet-manager.md`**: cancel requesters add "Boss (14): part kill 90 px, last part 150 px, boss death whole screen (cause = killer); TIMEOUT uses the Rule 15a enemy-pool clear without items".
8. **`design/gdd/coop-and-team-chain.md`**: Boss row points to the Boss GDD; F4 note that `critical_hp` and `core_main` derive from the scaled core hp.
9. **`design/gdd/game-events-and-session.md`**: add `boss_intro_started`, `boss_started`, `boss_part_destroyed`, `boss_core_exposed`, `boss_phase_changed`, `boss_critical_started`, `boss_critical_window_closed`, `boss_enraged`, `boss_gone`; change `boss_defeated` to `boss_defeated(reason, killer_slot)` with reason KILLED, CRITICAL_BREAK or TIMEOUT; add Boss (14) to the Dependencies table.
10. **`design/art/art-bible.md`**: §5.8 part kills never flash, per-part hp bars removed; §7.4 add the enrage/timeout display and the part-kill caption inside the boss row; §6.8 add boss part explosion size 28–36 px and the death-sequence particle cap of 40.
11. **ADR-0001 diagram:** add 3c `BossController.tick()` and 6c `apply_results()`.
12. **Code (at implementation):** correct `boss.gd`, `boss_part.gd`, `boss_part_definition.gd`, `boss_definition.gd` and `data/bosses/*.tres`. The list is in Open Question 12.

## 4. Registry candidates
```yaml
constants:
  - name: part_cancel_radius
    value: 90
    unit: px (bullet cancel circle on a boss-part kill)
    range: "60-120"
    source: design/gdd/boss-and-boss-parts.md (Rule 24)
    referenced_by: [boss-and-boss-parts, bullet-manager]
  - name: last_part_cancel_radius
    value: 150
    unit: px (cancel circle when the last non-core part dies)
    range: "100-220"
    source: design/gdd/boss-and-boss-parts.md (Rule 24)
    referenced_by: [boss-and-boss-parts]
  - name: core_armor_pct
    value: 25
    unit: percent of damage taken by an armoured core while parts live
    range: "10-50"
    source: design/gdd/boss-and-boss-parts.md (Rule 18)
    referenced_by: [boss-and-boss-parts, collision-damage-lives]
  - name: critical_pct
    value: 15
    unit: percent of core hp held as the critical reserve
    range: "5-30"
    source: design/gdd/boss-and-boss-parts.md (Rule 20)
    referenced_by: [boss-and-boss-parts]
  - name: critical_window_ticks
    value: 420
    unit: ticks (7 s) in which the critical core cannot die from shots
    range: "300-600"
    source: design/gdd/boss-and-boss-parts.md (Rule 22)
    referenced_by: [boss-and-boss-parts]
  - name: critical_armor_pct
    value: 20
    unit: percent of damage taken by the core during the critical window
    range: "5-40"
    source: design/gdd/boss-and-boss-parts.md (Rule 22)
    referenced_by: [boss-and-boss-parts]
  - name: boss_hurtbox_budget
    value: 8
    unit: hurtbox circles per boss
    range: "6-12"
    source: design/gdd/boss-and-boss-parts.md (Rule 10)
    referenced_by: [boss-and-boss-parts, enemy-and-ai, bullet-manager]
  - name: boss_intro_ticks
    value: 240
    unit: ticks (180 entrance + 60 hold); parts IMMUNE and non-lethal
    range: "180-360"
    source: design/gdd/boss-and-boss-parts.md (Rule 12)
    referenced_by: [boss-and-boss-parts]
  - name: enrage_mult
    value: 1.75
    unit: multiple of the reference fight length T_fight
    range: "1.5-2.5"
    source: design/gdd/boss-and-boss-parts.md (F6)
    referenced_by: [boss-and-boss-parts]
  - name: boss_timeout_after_enrage
    value: 1200
    unit: ticks (20 s) between enrage start and the boss withdrawing
    range: "600-2400"
    source: design/gdd/boss-and-boss-parts.md (Rule 33)
    referenced_by: [boss-and-boss-parts]
  - name: ref_uptime_pct
    value: 70
    unit: percent (share of time a competent player's fire lands; used in hp budgets)
    range: "50-90"
    source: design/gdd/boss-and-boss-parts.md (F6)
    referenced_by: [boss-and-boss-parts, enemy-and-ai]
formulas:
  - name: boss_core_split
    expression: "critical_hp = (core_hp * critical_pct + 50) / 100; core_main = core_hp - critical_hp (integer division)"
    variables: [core_hp, critical_pct]
    output: "critical_hp >= 1, core_main >= 1"
    source: design/gdd/boss-and-boss-parts.md (F3)
    referenced_by: [boss-and-boss-parts, coop-and-team-chain]
  - name: boss_intensity
    expression: "I = destroyed_noncore / total_noncore; I_enr = clamp((fight_ticks - enrage_start) / enrage_ramp, 0, 1); I_eff = max(I, I_enr)"
    variables: [destroyed_noncore, total_noncore, fight_ticks, enrage_start, enrage_ramp]
    output: "0-1, never decreasing"
    source: design/gdd/boss-and-boss-parts.md (F4)
    referenced_by: [boss-and-boss-parts, bullet-pattern-library]
  - name: boss_fight_budget
    expression: "T_fight = ceil(sum(part_hp)*6000/(ref_dps*ref_uptime_pct)) + ceil(core_main*6000/(ref_dps*ref_uptime_pct)); enrage_start = round100(enrage_mult * T_fight)"
    variables: [part_hp, core_main, ref_dps, ref_uptime_pct, enrage_mult]
    output: "T_fight 2400-3600 ticks"
    source: design/gdd/boss-and-boss-parts.md (F6)
    referenced_by: [boss-and-boss-parts]
```
Existing entries whose `referenced_by` gains `boss-and-boss-parts`: `part_kill_chain`, `kill_values`, `armour_damage_min`, `armour_damage`, `death_fire_hold`, `spawn_clearance`, `play_top`, `chain_cap`, `cap_hold_streak`, `hit_radius_orb` (cancel example), `enemy_cap`, `pattern_target_rotation`. The `kill_values` note should also say part is paid by Collision's `kill_credit(slot, PART)`.

## 5. Conflicts with locked values or other GDDs
- **No locked registry value is contradicted.**
- Chain Rule 8 ("a chain carried in from wave 5 counts"): the unhittable Intro makes this impossible in practice. Softened by Amendment 2.
- Collision "cores 6–12 (placeholder)" body radius: bosses use up to 25.5 px (within the 2–40 range).
- Session / Scoring: `boss_defeated` gains `reason`, and S4 skips TIMEOUT (Amendments 3 and 9).
- Collision must accept the core's hp and mode being republished mid-fight under one id (Open Question 6).
- The prototype's screen flash on part kills conflicts with the art-bible flash rule; the flash is removed.
- Pattern library F9 quotes Fortress "≈155" at full intensity. This is the core's two runners only (91.4 + 63.5 = 154.9), which matches this GDD. The enraged all-parts-alive scene is higher and must be validated.

## 6. Open risks
- hp values are re-budgeted from `ref_dps` 300 (provisional); a real kit may make fights much shorter or longer.
- The enrage timing (1.75 ×, 20 s timeout) is untested for new players and co-op (η is an assumption).
- The Critical window costs a non-CB player about 5.6 s; the CB bonus (Scoring and CB GDDs) must justify it.
- The Jet Carrier uses exactly the 8-hurtbox budget with 6 parts, so any new part needs a trade-off.
- Collision two-stage-core compatibility is assumed (Open Question 6).
- Final-stage TIMEOUT counts as a clear (decision; Session and Scoring should confirm).
- Plasma Ring numbers are migrated but unplaytested (Target).
- Platform float differences are mitigated by 1/16 px quantization but not proven across Web and PC.
