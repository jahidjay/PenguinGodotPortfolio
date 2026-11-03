# Report: Wave and Stage Director (system 16)

## 1. File written
`design/gdd/wave-and-stage-director.md` (Designed, pending review). The GDD defines the stage data format (`StageDef` > 5 `WaveDef` > integer-tick `SpawnEvent`, scroll, state-triggered background sections and music cues), wave start/end rules (fixed event timeline with an early-clear skip), rest beats, chain lanes, the fixed boss block (field clear, WARNING, scroll-stop, intro, sweep, `stage_cleared`), the stage validator (V-D1 to V-D11, wrapping Boss power budget `check_stage`), full MVP outlines for Stage 1 (1941, 4:24) and Stage 2 (1970s, 4:41), determinism (zero RNG), debug tools, 11 formulas, 51 acceptance criteria and 12 open questions.

## 2. Key decisions (auto-approve, user may change)
- Wave end: fixed event timeline per wave; if the field is empty after the last event, the wave ends 24 ticks later (early clear). Rest beats (REST) are never shortened. Rejected: kill-gated waves (stalling, co-op unfairness) and time-only waves (dead air for good players). Event ticks are wave-relative so content is identical on every run.
- Stage shape: lead-in 120 + 5 waves + 2 REST boundaries (waves 2-3: 180, 4-5: 150) + boss block. Stage 1 lengths 2,100/2,280/2,400/2,520/2,700 (par 15,813 ticks = 4:24); Stage 2 2,160/2,340/2,520/2,640/2,820 (par 16,875 = 4:41). Validator window 14,400 to 18,000.
- Boss block offsets from wave-5 end E5: 0 force_exit, 60 despawn_all + bullet clear_all, 90 WARNING (150 ticks, art-bible 2.5 s), 240 scroll-stop + `Boss.start_intro`, 480 `boss_started`. `stage_cleared` = max(boss_gone, boss_defeated + 90); watchdog at +360.
- Chain lanes: no stretch over 45 ticks without a targetable enemy outside REST and the boss block; lane jumps at most 157 px; lane cover at least 70 %; bridged waves must have first target within 21 ticks (24 + 21 = 45).
- Density: hard ceiling 1,700 at N=1..4 plus new per-wave curve caps 60/80/100/120/150 at N=1 and strictly rising peaks (replaces Enemy's provisional 600 per wave). Alive/hurtbox at N=4 limited to 26/30 (cap minus margin 2).
- Previews: at least 2 successive carriers per preview wave, 3 when the carrier is SMALL (Jet fighter hp 50); wave 5 combination spawned once, inside 160 ticks. Native debut gate opens at the first preview spawn of the owning mechanic.
- Carriers: 8 per stage (W1 S; W2 S+M; W3 L; W4 S+M; W5 S+L), never scaled with N; failed carrier/preview spawns are requeued twice (60 ticks apart).
- Stage clock stops while no slot is Active (like the Boss fight clock). Group size is read once at the group's first tick.
- Director uses no RNG. Background and music cues key on state triggers, not absolute ticks. Scroll: S1 80/90/100/100/110, S2 120/130/140/150/150, boss drift 25 (x100 px/tick).
- Debug stage select / wave skip mark the run `debug_tainted` (not rankable).

## 3. Amendments
1. `design/gdd/systems-index.md` row 16: status `**Designed** (pending review) — [GDD](wave-and-stage-director.md)`; Depends on `10, 13, 15` -> `1, 3, 9, 10, 13, 14, 15, 18`; progress tracker +1 GDD.
2. `enemy-and-ai.md`: Rule 8 `params` gain `preview`, `strip_tags[]`, `max_life_ticks`; new event `spawn_failed(event_id, reason)` and `alive_count()`; close Open Question 4 (Director owns co-op SMALL scaling) and 6 (8 carriers/stage, >= 1 per wave); F9b wave budget replaced by Director curve caps 60/80/100/120/150 + 1,700; Wave director row points to the GDD.
3. `boss-power-budget.md`: Rule 22(d) wording per mechanic (waves 1-4 one in total; wave 5 four alive by design); close Open Question 1 (>= 2 successive carriers, 3 for SMALL; combination once at wave tick 900); note SMALL-carrier exposure issue.
4. `powerups-and-drops.md`: close Open Question 3 (`sweep_min_ticks` 90); Wave director row -> GDD exists.
5. `boss-and-boss-parts.md`: Wave director row -> GDD; WARNING at E5+90, `start_intro` at E5+240, field clear E5+60, `boss_gone` watchdog D+360.
6. `game-events-and-session.md`: add events `wave_started`, `wave_ended`, `warning_started`, `scroll_changed`, `stage_cue`, `mechanic_previewed`, `era_ready`; state table "Stage -> Tally" trigger should be `stage_cleared` (Director, after the sweep), not `boss_defeated`; `stage_started(stage_index, era)` emitted by the Director after `era_ready`.
7. `coop-and-team-chain.md`: Wave director row -> GDD; `coop_spawn_cap` = per-wave `spawn_pct` limit (100-160).
8. `chain-tracker.md`: Wave director row -> GDD; validator enforces G <= 45.
9. `bullet-pattern-library.md`: F9 scope note -> `StageValidator` V-D5 does the cross-enemy check.
10. `bullet-manager.md`: Wave director row -> `clear_all()` at E5+60 and at `stage_cleared`.
11. `art/art-bible.md` 7.4: Warning = 150 ticks starting only on a clear field (satisfied by Director).
12. `save-settings-high-scores.md`: `run.debug_tainted` blocks ranking (provisional).
13. `design/registry/entities.yaml`: entries below; add `wave-and-stage-director` to `referenced_by` of `chain_window`, `move_speed`, `enemy_max_alive`, `enemy_hurtbox_budget`, `enemy_cap`, `coop_spawn_step`, `play_top`, `spawn_clearance`.

## 4. Registry candidates
```yaml
constants:
  - name: warning_ticks
    value: 150
    unit: ticks (WARNING plate duration; starts at wave-5 end + 90)
    range: "120-180"
    source: design/gdd/wave-and-stage-director.md (Rule 24)
    referenced_by: [wave-and-stage-director, boss-and-boss-parts]
  - name: boss_started_offset
    value: 480
    unit: ticks from wave-5 end to boss_started (90 pre-warning + 150 warning + 240 intro)
    source: design/gdd/wave-and-stage-director.md (Rule 24)
    referenced_by: [wave-and-stage-director, boss-and-boss-parts, chain-tracker]
  - name: sweep_min_ticks
    value: 90
    unit: ticks (minimum boss_defeated -> stage_cleared)
    range: "75-180"
    source: design/gdd/wave-and-stage-director.md (Rule 24)
    referenced_by: [wave-and-stage-director, powerups-and-drops]
  - name: early_clear_gap
    value: 24
    unit: ticks (field empty after last spawn -> wave ends)
    range: "0-45"
    source: design/gdd/wave-and-stage-director.md (Rule 14)
    referenced_by: [wave-and-stage-director]
  - name: chain_gap_budget
    value: 45
    unit: ticks (max no-target stretch outside rests; chain_window - ceil(chain_window/4))
    range: "30-60"
    source: design/gdd/chain-tracker.md (F1); enforced by wave-and-stage-director (F6)
    referenced_by: [chain-tracker, wave-and-stage-director]
  - name: wave_curve_cap
    value: "60 / 80 / 100 / 120 / 150"
    unit: bullets (N_scene at N=1, waves 1-5)
    source: design/gdd/wave-and-stage-director.md (F3)
    referenced_by: [wave-and-stage-director, enemy-and-ai]
  - name: carrier_plan
    value: "8 per stage: 4 SMALL, 2 MEDIUM, 2 LARGE; >= 1 per wave; >= 180 ticks apart; not scaled"
    unit: carriers
    source: design/gdd/powerups-and-drops.md; placed by wave-and-stage-director (F5)
    referenced_by: [powerups-and-drops, wave-and-stage-director, enemy-and-ai]
  - name: stage_par_window
    value: "14400-18000"
    unit: ticks (T_par of an MVP stage)
    source: design/gdd/wave-and-stage-director.md (F7)
    referenced_by: [wave-and-stage-director]
formulas:
  - name: wave_timeline
    expression: "end(w) = min(length(w), t_clear(w) + early_clear_gap); start(w+1) = start(w) + end(w) + gap(w)"
    variables: [length, t_clear, early_clear_gap, gap]
    output: "ticks; S1 starts 0/2100/4560/6960/9630, E5 12330"
    source: design/gdd/wave-and-stage-director.md (F1)
    referenced_by: [wave-and-stage-director]
  - name: stage_par_ticks
    expression: "lead_in + sum(length) + sum(gap) + 480 + T_fight_par + 180"
    variables: [lead_in, length, gap, T_fight_par]
    output: "S1 15813 (4:24), S2 16875 (4:41)"
    source: design/gdd/wave-and-stage-director.md (F7)
    referenced_by: [wave-and-stage-director]
  - name: group_size
    expression: "(count * min(100 + coop_spawn_step*(N-1), coop_spawn_cap) + 99) / 100"
    variables: [count, coop_spawn_step, N, coop_spawn_cap]
    output: "6 -> 6/8/9/10"
    source: design/gdd/wave-and-stage-director.md (F2); restates coop-and-team-chain F5
    referenced_by: [wave-and-stage-director, coop-and-team-chain]
```

## 5. Conflicts with locked values or other GDDs
- No registry value contradicted.
- Boss power budget Rule 22(d) ("preview carriers alive never exceed `preview_alive_max` = 1") conflicts with Rule 17 (four alive in wave 5). Resolved by reading it per mechanic (amendment 3).
- Session state table has Stage -> Tally on `boss_defeated`; Boss/Powerups/Chain imply the Tally starts at `stage_cleared` after the sweep (amendment 6).
- Enemy F9b proposed a 600 per-wave bullet budget; replaced by curve caps (amendment 2). Not a locked value.
- Boss GDD says "scroll-stop"; this GDD uses a 0.25 px/tick drift (Open Question 5).

## 6. Open risks
- Jet previews m1/m2 ride a SMALL `fighter` (hp 50): can die before the first volley (start_delay 48). Mitigated with 3 carriers; a `preview_hp_floor` (Enemy) or moving the previews to a gunner is likely needed.
- Wave curve caps and `N_def`-based peaks are estimates until Enemy F9 runs on real data.
- Stage clock stops while nobody is Active, which makes a solo respawn a free breather (Open Question 3).
- Early-clear gap (24) plus entry (21) sits exactly on the 45-tick chain budget; any slower first target breaks chains.
- Stages 3 and 4 (Target) have no outlines; HUD/Parallax/Audio/Era/Tally/Tutorial interfaces are provisional.
- Writing was done in one pass under auto-approve (no section-by-section approval), per the brief.
