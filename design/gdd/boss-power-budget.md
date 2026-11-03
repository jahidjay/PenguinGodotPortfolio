# Boss Power Budget

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (game-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: History Accelerates, Readable Chaos (also Every Hit Counts: the armour rule is previewed before the boss)

## Overview

**The data layer:** the **boss power budget** is an authoring-time rule set plus a small data layer. For every boss it lists exactly **4 previewable mechanics** (`data/boss_budget/<boss_id>.tres`). A **mechanic** is either a *pattern mechanic* (a Pattern library pattern family + its bullet behaviour + the boss-part role that fires it, e.g. "turret aimed fan") or a *rule mechanic* (a fight rule such as the armoured core). Each mechanic is bound to the exact pattern slots on the boss parts that use it. The system defines one number, the **power score `Q`**, built from density (Pattern library F9), lane tightness (F8), speed, aim, behaviour novelty, how many mechanics run together, and rule load. `Q` is computed for every boss phase (every set of destroyed parts) and for every preview. A **stage cap** `Q_cap(stage)` limits the boss, and a **wave fraction** limits each preview wave. The fixed stage rule is: **wave N previews boss mechanic N, wave 5 previews the combination, the boss combines everything.** A **preview transform** (fewer bullets, slower, one mechanic, no escalation) turns a boss pattern into the version the Wave director schedules. A **validator** (a unit test over `data/`) rejects a boss that has an unpreviewed mechanic, a preview that is not weaker than the boss, a boss over its cap, or an era that adds more than one new behaviour. There is no per-tick code: the system runs at load (`PreviewBuilder.build_stage`) and in tests. Implementation follows ADR-0001: integer ticks in data, no `delta`, no gameplay RNG, all values in `data/*.tres`.

**The player impact:** the player never meets a boss trick cold. The Fortress's aimed fan is a small slow fan in wave 1, its ring is a loose ring in wave 2, its armour is a plated bomber in wave 3, its spiral is a one-arm spiral in wave 4, and wave 5 mixes them gently, so the boss reads as "all the things I already beat, at once". Stage 2 does the same with the 1970s tricks, one at a time (accelerating bullets first, radar lock last). Difficulty rises on a visible staircase: Stage 1 is sparse and slow, Stage 2 has a higher cap, and inside a stage the boss is always the peak (**History Accelerates**, **Readable Chaos**). Designers get a number they can argue about instead of a feeling.

## Player Fantasy

**Anchor moment: "I know this one."** The Fortress's right turret opens fire and the player's hands move before they think. It is the same wide fan they sidestepped in wave 1, only faster and doubled. The ring from the engines? Wave 2. The spiral? They saw a baby version in wave 4. The boss is a room full of old acquaintances all talking at once, and the player is ready for it.

- **The stage is a lesson plan.** Each wave is one new idea, shown alone, in a form that is easy to read. Nothing in the boss is a surprise except how many ideas arrive together (**Readable Chaos**).
- **Eras are real steps.** Stage 1 is sparse and slow. Stage 2 adds one new bullet behaviour (accelerating rice) and one new aim trick (radar lock), each shown alone before the boss mixes them (**History Accelerates**).
- **Armour is learned on a bomber first.** The player hits plated armour before they meet an armoured core, so "hits still count, slowly" is known (**Every Hit Counts**).
- **The boss is the peak, always.** Wave 5 feels like a tense rehearsal. The boss is clearly bigger, never a cheap jump.

**Anti-fantasy (must never happen):** a boss trick that appears for the first time in the boss; a preview that is as dense or as fast as the boss pattern it previews; a wave 5 that is harder than the boss; a stage-1 boss that outscores the stage-2 boss; two new behaviours introduced in one wave.

Reference feel: Mega Man's stage-to-boss echo (the stage teaches what the boss uses), DoDonPachi's escalation by stage, and the "one new idea per level" rule of good tutorial design (scaffolded challenge, Csikszentmihalyi flow channel).

> `creative-director` not consulted (auto-approve).

## Detailed Design

### Core Rules

**Definitions**

1. A **mechanic** is one previewable idea of a boss. It has a `kind`:
   - **PATTERN**: a Pattern library pattern *family* (aimed fan, ring, spiral, wall, radial curve, flak burst, seeded spray) + its bullet **behaviour** (Straight, Accelerate, Curve, Warp) + its aim option (none, aimed, aim-locked) + the boss-part **role** that fires it (fixed turret, orbiting pod, core).
   - **RULE**: a fight rule of the boss. MVP rules: `ARMOURED` core (the core takes `core_armor_pct` while parts live) and `IMMUNE` core (Target). A rule has no bullets.
2. A boss has **exactly 4 previewable mechanics**, `index` 1 to 4 (the MVP stage has 5 waves). It may also list **carried** mechanics (Rule 6). Everything else the boss does is a **baseline rule** and is not a mechanic: intensity rising with part kills, the part-kill cancel, the critical window, the enrage ramp and the entrance (Boss 14).
3. **`BossBudgetDef`** (`data/boss_budget/<boss_id>.tres`): `boss_id`, `stage_index` (1 to 4), `mechanics[4]`, `carried[]`, `q_boss_x100` (int, parity check, V12). Each **`MechanicDef`**: `id`, `index`, `kind`, `family`, `bindings[]`, `base_binding`, `novelty[]` (tags, Rule 15), `preview` (`PreviewDef`), `name_key` (`mech.<boss_id>.<id>.name`, Bengali + English, debug and Tutorial only).
4. A **binding** is `(part_id, emitter_index, pattern_index)` and names one pattern slot on one boss part. Every part that carries a bound pattern also has the tag `mech:<mechanic_id>` in its `tags[]` (Boss Rule 2). A RULE mechanic has no bindings; it names the rule (`rule`, `rule_param`).
5. `base_binding` is the binding the preview is built from (the pattern at its non-escalated, intensity-0 form). Other bindings of the same mechanic are **variants** (Rule 7).
6. A **carried** mechanic is one a boss reuses unchanged from an earlier stage's boss (`carried_from = <boss_id>.<mechanic_id>`). It needs no preview but its parameters must hash equal to the source (V11). It still counts in `Q` (it is on the screen) and in the combination term.
7. **Variant rule.** All bindings of one mechanic share family, behaviour, aim option and bullet shape. A variant may differ in `count` by at most `variant_count_mult_max` (2.0 x the base binding's count), in `speed` by at most `variant_speed_mult_max` (1.25 x), and in interval, intensity gate and scaling freely. *Why:* the Fortress core ring (24 bullets, gate at full intensity) is the same idea as the engine ring (12 bullets); the player learned "rings" in wave 2.
8. Every pattern slot on every boss part is bound to exactly one mechanic or carried mechanic. An unbound slot is an error (V2).

**The Fortress (stage 1, 1941) mechanic list**

| # | Mechanic id | Kind | Bindings (part / emitter / pattern) | Pattern (migrated data, Pattern library F10) | Preview carrier |
|---|---|---|---|---|---|
| 1 | `m1_turret_fan` | PATTERN, aimed fan | `turret_l`, `turret_r` / 0 / 0 | count 3, spread 0.21, interval 66, speed 170, Straight, aimed | `gunner`, path `STATIC_GROUND` |
| 2 | `m2_engine_ring` | PATTERN, ring | `engine_l`, `engine_r` / 0 / 0 (base); `core` / 0 / ring (variant, gate [1,1]) | count 12, interval 114, speed 100; variant count 24, interval 66, speed 110 | `gunner` |
| 3 | `m3_armoured_core` | RULE, ARMOURED | the core (`core_rule`) | `core_armor_pct` 25 | `heavy`, plating 180 ticks at 50 % |
| 4 | `m4_core_spiral` | PATTERN, spiral | `core` / 0 / spiral | arms 2, step 0.33, interval 7 to 3, speed 140 | `heavy` |

**The Jet Carrier (stage 2, 1970s) mechanic list**

| # | Mechanic id | Kind | Bindings | Pattern | Preview carrier |
|---|---|---|---|---|---|
| 1 | `m1_accel_fan` | PATTERN, aimed fan, **Accelerate** (new behaviour) | `core` / 0 / fan | count 5 to 9, spread 0.165, interval 78 to 33, speed 70, v_cap 330, rice | `fighter`, path `SINE` |
| 2 | `m2_pod_stream` | PATTERN, aimed stream, orbiting part role | `pod_1..3` / 0 / 0 | count 1, burst 6, gap 6, interval 84, speed 240, Straight | `fighter`, path `SINE` (a moving muzzle stands in for the orbit) |
| 3 | `m3_wing_wall` | PATTERN, wall | `wing_l`, `wing_r` / 0 / 0 | count 7, spacing 16, gap 1, interval 138, speed 110 | `heavy` |
| 4 | `m4_radar_lock` | PATTERN, aimed fan with **aim lock** (new option) | `core` / 1 / 0 (**new pattern `core_lock_fan`**) | count 7, spread 0.1875, interval 120, speed 150, `lock_ticks` 30, gate [0.4, 1.0], `start_delay` 48 | `gunner` |
| carried | `c_armoured_core` | RULE, ARMOURED | the core | `core_armor_pct` 25 | none (carried from `fortress_1941.m3_armoured_core`) |

`core_lock_fan` is new data this GDD adds to the Jet Carrier (the migrated Boss data has no aim-locked pattern; the 1970s language needs one, Pattern library V4). It is bound to the core and gated at intensity 0.4, so it joins the fight after two of the five non-core parts are down. Its `start_delay` 48 is at least its `lock_ticks` 30 and at least the 18-tick escalation lag of Boss Rule 25.

**The power score**

9. **`Q`** (F3) is a dimensionless difficulty number for a *set of active runners* plus the rule load: density, speed, lane tightness, aim, behaviour novelty, concurrency and rule points. It is a design tool and a lint, not a player-facing number.
10. **Boss `Q`.** `Q_boss` (F4) is the maximum of `Q` over **every subset of destroyed non-core parts** (at most 2^5 = 32 subsets; Boss Rule 3 allows 5 non-core parts). For a subset `S`: intensity `I = |S| / K`; only runners on living parts whose gate contains `I` are active; scaling is read through Pattern library F3; the core rule counts while `S` is not the full set (PARTS). The Exposed state (all non-core parts dead) has no rule points. The Critical window is excluded (it is a gift). **Enrage states (the I_eff ramp with parts alive) are excluded**: they are the stall penalty (Boss Rule 33) and must only pass the density budget (V10).
11. **Stage cap** `Q_cap(s) = cap_base + cap_step x s` (F4): 18, 23, 28, 33 for stages 1 to 4 (stages 3 and 4 are Target, provisional). **Fill rule:** `Q_boss` must be in `[fill_min x Q_cap, Q_cap]`, `fill_min` = 0.85. The upper bound keeps Stage 1 sparse and every stage below the next; the lower bound stops a boss from being under-built.
12. **Wave fractions** `wave_frac[1..5]` = 0.32, 0.36, 0.40, 0.45, 0.75 of `Q_cap(stage)`. The preview (or combination) of wave N must have `Q` at most `wave_frac[N] x Q_cap`. The fractions increase with N, so the rule "boss over wave 5 over wave 1" cannot be broken by a cap swap.

**The preview**

13. **Wave N previews mechanic N** for N = 1 to 4. **Wave 5 previews the combination:** all non-carried mechanics, each in its wave-5 form, alive together. A stage with a boss budget must have exactly 5 waves (else V13).
14. **Preview transform** (F5), applied to `base_binding`'s pattern at load by `PreviewBuilder.build_stage(stage_index) -> PreviewSet[1..5]`. The result is a read-only derived pattern resource; nothing mutates at runtime. The transform:
    - scales count (or burst count for streams) down, interval up, speed down, per the **preview row** of the wave (percentages in `data/boss_budget/budget_rules.tres`: wave 1 = 60 / 160 / 75, wave 2 = 65 / 150 / 80, wave 3 = 70 / 145 / 85, wave 4 and wave 5 = 75 / 140 / 90);
    - uses the pattern at **intensity 0**: `*_at_full` values are ignored and the intensity gate is **bypassed** (a gated pattern such as the Jet lock fan still fires);
    - keeps spread, shape, behaviour, aim option, spiral `step`, wall `spacing`, `gap_width`, flak `flak_delay` and `standoff` unchanged (the *shape of the idea* is the lesson);
    - sets spiral `arms` to 1;
    - raises `lock_ticks` by `preview_lock_add` (12, max 60), so the radar-lock tell is easier to read than the boss's;
    - sets `start_delay = max(base, 48)`;
    - never raises count, speed or lowers interval above the base; counts floor at `count_floor` (fan 2, ring 4, wall 5, stream burst 2) but never exceed the base count;
    - never scales with player count (Co-op: patterns are unscaled).
15. **Carrier.** The preview rides on an existing enemy body (the `PreviewDef.carrier_role`). The Wave director spawns it with the spawn param `preview = <mechanic_id>` (→ Enemy amendment). The Enemy manager then replaces the carrier's emitter 0 patterns with the preview patterns and sets `intensity_source = CONSTANT(0)`. Body, hp, path, kill value and cancel radius stay those of the role. A preview carrier is **not** a powerup carrier. Number of preview carriers alive at once: `preview_alive_max` (default 1), counted **per mechanic** (amended 2026-11-03: in wave 5 four are alive, one per mechanic, Rule 17).
16. **Rule preview (ARMOURED).** The carrier gets `plating_ticks = 180` and `plating_armor_pct = min(75, core_armor_pct + 25)` = 50 (inside the Enemy plating range, registry `enemy_plating`: 60 to 180 ticks, 25 to 75 %). Its native patterns stay (they are the wave's content and count towards the Wave director's own density check, not towards `Q`). Rule points use F2.
17. **Combination (wave 5).** One carrier per non-carried mechanic, each built from the wave-5 row. The Wave director spawns all four inside one `combo_window_ticks` (180) so they overlap on screen, and each carrier has `max_life_ticks` at least 600. Carried mechanics are not shown. The combination's `Q` is measured with all four runners active (F3), which is the worst case; if the player kills carriers faster, it is lower.

**Era novelty**

18. **One new behaviour per era.** Bullet behaviours form a ladder (`data/boss_budget/budget_rules.tres`, from Concept section 10 and Bullet manager): stage 1 Straight only (flak and walls are patterns, not behaviours), stage 2 adds **Accelerate**, stage 3 adds **Curve**, stage 4 adds **Warp**. A boss may use only behaviours at or below its stage on the ladder (V8), and the stage's new behaviour must be used by at least one mechanic.
19. **One new aim option per era at most.** Pattern options are `aim_lock`, `reaim_each_volley`, `flak_fuse`. The ladder gives `aim_lock` to stage 2 (Pattern library V4: "1970s: aim-locked fans"). A boss has at most 1 new behaviour and 1 new option, and each is the `novelty` tag of exactly one mechanic. Tag format: `behaviour:accelerate`, `option:aim_lock`. *(2026-11-03, wave 3b, [Era shift 19](era-shift-and-plane-evolution.md) Rule 9: the **option ladder** is `flak_fuse` base (1941), `aim_lock` era 2 (1970s), `reaim_each_volley` era 3 (2030s, Target proposal), none era 4 (2100, proposal). Its data home is `EraDef.new_option`.)*
20. **Debut wave = mechanic index.** `novelty_debut_wave(stage, tag)` returns the index of the mechanic that owns the tag: Jet `behaviour:accelerate` = 1, `option:aim_lock` = 4. **Novelty gating** (→ Enemy 10, Wave 16, Era shift 19): before its debut wave, no enemy of the stage may use that tag. The Wave director strips it from native enemies: `lock_ticks` forced to 0, Accelerate replaced by Straight at `v_strip` (Era shift F4; default `V_EFF` = average speed; 2026-11-03). *Why:* the Enemy GDD's 1970s `fighter` (aim-locked fan, accelerating rice) would otherwise teach both tricks in wave 1.
21. **One new thing per preview wave.** A preview wave 1 to 4 may carry at most one novelty tag (its own). Wave 5 carries all of the stage's tags.

**Validation (the lint, `tests/unit/test_boss_budget_*.gd`; errors fail the build)**

| ID | Check |
|---|---|
| V1 | The boss has exactly 4 non-carried mechanics, `index` 1 to 4 unique; `kind` valid; each PATTERN mechanic has at least 1 binding and a `base_binding` among them. |
| V2 | Every pattern slot on every boss part is bound exactly once (no orphan, no double binding); each bound part has the tag `mech:<id>`; no mechanic references a missing part, emitter or pattern. |
| V3 | Each mechanic has a `PreviewDef` with a carrier role that exists in the stage's era role table; a RULE mechanic's preview matches Rule 16. |
| V4 | Variant rule (Rule 7) holds for every non-base binding. |
| V5 | Reduction: for each PATTERN preview, `N_preview <= preview_n_ratio_max (0.60) x N_base` and `v_eff_preview <= preview_v_ratio_max (0.90) x v_eff_base`; count not above, interval not below base. `N_base` is the density at intensity 0 of **all boss instances of the base pattern** (gates ignored). |
| V6 | Wave cap: `Q_preview(N) <= wave_frac[N] x Q_cap(stage)` for N = 1 to 5. |
| V7 | Boss cap and fill: `fill_min x Q_cap <= Q_boss <= Q_cap`. |
| V8 | Behaviour ladder (Rule 18) and novelty (Rules 19 to 21): at most 1 new behaviour, at most 1 new option, one owner mechanic per tag, no tag in an earlier-stage boss counted as new. |
| V9 | Ordering: `Q_w5 > max(Q_w1..Q_w4)` and `Q_boss >= boss_over_w5_min (1.20) x Q_w5`. |
| V10 | Fairness: every preview pattern and every boss phase passes Pattern library F8 (lanes, tells), and the largest `N_scene` over all subsets and over the enraged state is at most 1,700 (F9); no runner above 450 is a warning. |
| V11 | Carried mechanics: parameter hash equals the source mechanic's hash; otherwise the mechanic must be a normal one with a preview. |
| V12 | Parity: `q_boss_x100` in the data equals `round(100 x Q_boss)`. |
| V13 | The stage has exactly 5 waves; the stage lint (Rule 22) passes. |
| V14 | The boss has a budget file; a boss without one is refused in debug and logged in release (the stage still plays; Wave 5 shows no combination). |

22. **Stage lint (`check_stage(waves)`, run by the Wave director's data test).** For the stage's wave scripts: (a) no wave with index < N spawns a preview of mechanic N or any enemy using mechanic N's novelty tag (after gating); (b) wave N (N = 1 to 4) spawns at least one carrier with `preview = mechanic N`, and no preview of another mechanic; (c) wave 5 spawns all four previews inside `combo_window_ticks`; (d) preview carriers alive at once never exceed `preview_alive_max` **per mechanic**: in waves 1-4 that is one in total (only that wave's mechanic is previewed); in wave 5 four are alive by design, one per mechanic (Rule 17). *(Amended 2026-11-03, Wave director (16) Rule 18.)*

**Runtime**

23. This system has no `tick()`. `PreviewBuilder.build_stage` runs once at stage load, allocates the derived resources, and is cached for the stage. It makes no random draws.

### States and Transitions

The system has no gameplay state machine. It has an authoring lifecycle and, per run, an exposure status for each mechanic.

**Authoring lifecycle of a `BossBudgetDef`**

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| Draft | Fields filled, lint not yet run | Linted | lint run |
| Failing | Any V-check fails; the test log prints `Q`, the cap and the failing row | Draft | author edits data |
| Linted | All V-checks pass; `q_boss_x100` equals the computed value | Locked | design review sign-off |
| Locked | Any change to a bound pattern re-runs the lint (parity V12 fails until updated) | Draft | data edit |

**Per-run exposure of one mechanic** (Wave director and Boss events; used by Tutorial and analytics)

| Status | Entered when | → Next |
|---|---|---|
| Unseen | stage start | Previewed |
| Previewed | the first preview carrier of that mechanic spawns in wave N | Combined |
| Combined | wave 5's combination window begins | In boss |
| In boss | `boss_started` | (end) |

### Interactions with Other Systems

| System | Direction | Data |
|---|---|---|
| Boss and boss parts (14) — GDD | ← reads parts, emitters, patterns, `tags[]`, `core_rule`, `core_armor_pct`; → `BossBudgetDef` per boss; Boss lint requires the budget file | Part `tags[]` carry `mech:<id>` (Boss Rule 2); Boss owns hp and the F6 fight length, this system never reads hp |
| Bullet pattern library (9) — GDD | ← F3 (intensity scaling), F8 (lane checks), F9 (density) as **pure functions** (`PatternMetrics`); → derived preview pattern resources | Library has no era logic; this system owns the preview transform |
| Enemy and AI (10) — GDD | → spawn param `preview`, emitter swap, `CONSTANT(0)` intensity, plating override; ← role tables for carrier roles, plating ranges | Provisional contract (amendment 2) |
| [Wave and stage director (16)](wave-and-stage-director.md) | → `PreviewSet[1..5]`, `novelty_debut_wave`, `check_stage`, `preview_alive_max`, `combo_window_ticks`; ← wave scripts for the stage lint | The Director only schedules; the rule is fixed by this GDD (breaks the 15/16 cycle) |
| Era shift (19) — [GDD](era-shift-and-plane-evolution.md) | → behaviour ladder, novelty gating tags (ladder data now in `EraDef.new_behaviour` / `new_option`; `budget_rules.tres` reads `EraLadder`); ← which boss belongs to which stage (stage 1 Fortress, stage 2 Jet Carrier) | Era shift strips undebuted novelty from native enemy patterns |
| Co-op and Team Chain (18) — GDD | none at runtime | Previews and boss patterns are unscaled; `hp_pct(N)` on carriers is Enemy's |
| Game events and session (1) — GDD | → optional event `mechanic_previewed(boss_id, mechanic_id, wave)`; ← pause (not needed: no tick) | Provisional |
| Tutorial (30) — [GDD](tutorial.md), Audio (24), VFX (25) | → mechanic ids and `name_key`s, `mechanic_previewed`; carriers wear the preview mark (V1 below) | Tutorial uses `mechanic_previewed` for hints (Target) |
| Scoring (8), Chain tracker (7), Collision (6), Bullet manager (3) | none | Carrier kills pay the role's `kill_class` through Enemy as usual |

> Decided under auto-approve (2026-11-03): exactly 4 + combination; `Q` as a weighted sum with a subset worst-case; stage cap `13 + 5 x stage`; wave fractions 0.32 / 0.36 / 0.40 / 0.45 / 0.75; preview rows 60/160/75 to 75/140/90; previews at intensity 0 with gates bypassed; armour previewed on a plated heavy; carried mechanics need no preview; one new behaviour and one new aim option per era; novelty stripped from native enemies before the debut wave; new Jet `core_lock_fan` pattern; enrage states excluded from the cap.

## Formulas

Conventions: px, 60 ticks per second, integer ticks in data. Authoring formulas run in tests and the editor, not per tick, so floats are allowed; results are compared with a tolerance of 0.005 and stored as integers x100 (`q_boss_x100`). `roundi` rounds half away from zero (Godot). Registry values: `lane_min_clear` 14, `hit_radius_*` 2.5 / 1.5 / 1.25 / 2.0, `v_min` 70, `enemy_cap` 2,000 (budget 1,700).

**F1. Runner density** (Pattern library F9, restated with the gate and alive multiplier)

`N_runner = (count_eff - gap_slots) x burst_count x 60 / interval_eff x L_path / v_eff x alive`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Count | `count_eff` | int | 1 to 24 | Library F3 at the evaluated intensity `I`. Spiral: `arms`. Streams: 1 |
| Gap slots | `gap_slots` | int | 0 or `gap_width` | Walls only |
| Burst | `burst_count` | int | 1 to 8 | |
| Interval | `interval_eff` | int ticks | 1 to 3600 | Library F3 at `I` |
| Path length | `L_path` | px | 640 or 320 | 640 aimed, wall, spray, curve; 320 ring, spiral, flak |
| Effective speed | `v_eff` | px/s | 70 to 480 | Straight, Curve: `speed`; Accelerate: `(speed + v_cap) / 2`; Warp: 66 |
| Alive multiplier | `alive` | int | 1 to 3 | Boss: number of living parts with this binding. Preview: `preview_alive_max` |

**Output Range:** 0 to about 100 per runner. **Example (Fortress):** turret fan, one turret: `3 x 60 / 66 x 640 / 170` = 2.7273 x 3.7647 = **10.27**; two turrets **20.54**. Engine ring, one: 6.3158 x 3.2 = **20.21**; two **40.42**. Core spiral (arms 2) at `I` = 0 / 0.25 / 0.5 / 0.75 / 1: interval 7 / 6 / 5 / 4 / 3 gives **39.18 / 45.71 / 54.86 / 68.57 / 91.43**. Core ring (24, interval 66, speed 110): **63.47**. Jet accelerating fan at `I` = 0: `5 x 60 / 78 x 640 / 200` = **12.31**; pods (3): **34.29**; walls (2, `(7 - 1) x 60 / 138 x 640 / 110`): **30.36**; lock fan `7 x 60 / 120 x 640 / 150`: **14.93**.

**F2. Term scores**

`S = v_eff / v_ref`
`L = min(L_cap, lane_min_clear / lane_clear)` (0 if the pattern has no lane check)
`A = a_aimed (0.5) if aimed, a_lock (1.0) if aim-locked, 0 if unaimed; + a_reaim (0.5) if reaim_each_volley`, max 1.0
`B = b[behaviour]`: Straight 0, Curve 1, Accelerate 1, Warp 2
`R = w_R x (100 - armor_pct) / 100` for ARMOURED; `R = r_immune (5)` for IMMUNE; 0 otherwise

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Speed reference | `v_ref` | px/s | 150 (fixed default) | Pattern library default speed |
| Lane cap | `L_cap` | float | 2.0 | Caps a lane at half the minimum |
| Lane (clear px) | `lane_clear` | px | > 0 | Per family (below). `lane_clear` <= 0 caps `L` at `L_cap` (and F8 reports an error) |
| Armour | `armor_pct` | int % | 1 to 99 | Share of damage that gets through |
| Rule weight | `w_R` | float | 4.0 | |

**Lane per family** (Pattern library F8 distances): fan `spread x d_ref - 2 r_b` (n >= 2; `d_ref` 160); ring `2 pi x D_lane_max / n - 2 r_b` (`D_lane_max` 120; flak: the `standoff` 56); spiral `v x (interval / 60) x 2 pi / (|step| x arms) - 2 r_b`; wall `(gap_width + 1) x spacing - 2 r_b`; spray `(1 - J) x arc x d_ref / n - 2 r_b`; single-bullet stream, radial curve and Warp: no lane check, `L` = 0 (stream) or `L_default` 0.5 (curve and Warp, estimate).

**Output Range:** `S` 0.47 to 3.2; `L` 0 to 2; `A` 0 to 1; `B` 0 to 2; `R` 0 to 5. **Example:** fan spread 0.21, orb: lane `0.21 x 160 - 5` = 28.6, `L` = 14 / 28.6 = **0.4895**. Ring n = 12: `2 pi x 120 / 12 - 5` = 57.83, `L` = **0.2421**. Wall: `2 x 16 - 5` = 27, `L` = **0.5185**. Spiral at `I` = 0: arm gap 150.49, `L` = **0.0930**; at `I` = 1: 61.64, `L` = **0.2271**. Rice fan spread 0.165: `26.4 - 3` = 23.4, `L` = **0.5983**. ARMOURED 25: `R` = 4 x 0.75 = **3.00**; plating 50: **2.00**.

**F3. Power score**

`Q = w_D x N / N_unit + w_S x max(S) + w_L x max(L) + w_A x max(A) + w_B x max(B) + w_C x max(M - 1, 0) + sum(R)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Weights | `w_D, w_S, w_L, w_A, w_B, w_C` | float | 3, 2, 2, 2, 2, 1.5 | Tuning knobs |
| Density | `N` | float | 0 to 400 | Sum of `N_runner` over active runners (F1) |
| Density unit | `N_unit` | float | 50 | 50 bullets on screen = 1 density point |
| Mechanics active | `M` | int | 0 to 6 | Distinct mechanic ids (including RULE and carried) with an active runner or an active rule |
| Max terms | `max(S)`, ... | float | | Over the active runners |

**Output Range:** single mechanic 2 to 8; a boss phase 13 to 23 at MVP; a preview 2 to 7; a combination 12 to 15. **Example (Fortress, nothing destroyed, `I` = 0):** `N` = 20.54 + 40.42 + 39.18 = 100.14; density term `3 x 100.14 / 50` = 6.008; `max(S)` = 1.1333 (fan) x 2 = 2.267; `max(L)` = 0.4895 x 2 = 0.979; `max(A)` = 0.5 x 2 = 1.000; `B` = 0; `M` = 4 (fan, ring, spiral, armour) so 1.5 x 3 = 4.500; `R` = 3.000. **Q = 17.75.** Single mechanic values at their boss form: `m1_turret_fan` (both turrets) **5.48**, `m2_engine_ring` (both) **4.24**, `m3_armoured_core` **3.00**, `m4_core_spiral` at `I` = 0 **4.40**; Jet `m1_accel_fan` **7.60**, `m2_pod_stream` (3 pods) **6.26**, `m3_wing_wall` (2 wings) **4.33**, `m4_radar_lock` **6.02**.

**F4. Boss peak and stage cap**

`Q_boss = max over S subset of non-core parts of Q(runners(S), rule(S))`
`Q_cap(s) = cap_base + cap_step x s`
`fill = Q_boss / Q_cap(s)`; pass if `fill_min <= fill <= 1`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Destroyed set | `S` | subset | 2^K subsets, K <= 5 | `I = |S| / K`; rule points only if `|S| < K` |
| Cap base / step | `cap_base`, `cap_step` | float | 13 / 5 | Tuning knobs |
| Stage | `s` | int | 1 to 4 | |
| Fill minimum | `fill_min` | float | 0.85 | |

**Output Range:** `Q_cap` 18 / 23 / 28 / 33. **Example, Fortress** (16 subsets): all parts alive gives **17.75**; one turret down 17.53; both turrets and one engine down 13.68; only the core left (spiral at full + core ring, `N` = 154.90, no rule) **13.72**. Peak **17.75**, fill 17.75 / 18 = **0.986**. **Jet Carrier** (32 subsets): nothing destroyed 19.51; two pods destroyed (lock fan gate opens at `I` = 0.4, fan count 7, interval 60) **22.14** (`N` = 22.40 + 11.43 + 30.36 + 14.93 = 79.12; density 4.747; `S` 3.200; `L` 1.197; `A` 2.000; `B` 2.000; `M` = 5 gives 6.000; `R` 3.000); only the core left 13.40. Peak **22.14**, fill 22.14 / 23 = **0.963**.

**F5. Preview transform**

`count_eff = clamp(roundi(count x pct_count / 100), min(count_floor, count), count)`
`interval_eff = max(interval, roundi(interval x pct_interval / 100))`
`speed_eff = max(v_min, speed x pct_speed / 100)`, and for Accelerate `v_cap_eff = v_cap x pct_speed / 100`
`lock_eff = min(60, lock + preview_lock_add)` if `lock > 0`
`arms_eff = 1` (spiral), `I = 0`, gates bypassed, `start_delay_eff = max(start_delay, 48)`
For a single-bullet stream the count axis is `burst_count`, floored at 2.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Wave row | `pct_count, pct_interval, pct_speed` | int % | wave 1: 60/160/75; 2: 65/150/80; 3: 70/145/85; 4 and 5: 75/140/90 | Tuning knobs, increase with wave |
| Floors | `count_floor` | int | fan 2, ring 4, wall 5, stream 2 | |
| Lock add | `preview_lock_add` | int ticks | 12 | |
| Min speed | `v_min` | px/s | 70 | Registry |

**Output Range:** `count_eff <= count`, `interval_eff >= interval`, `speed_eff` at least 70. **Example (Fortress):**
- Wave 1 fan: count `roundi(1.8)` = 2, interval `roundi(105.6)` = 106, speed 127.5. `N` = 2 x 60 / 106 x 640 / 127.5 = **5.68**.
- Wave 2 ring: count `roundi(7.8)` = 8, interval 171, speed 80. `N` = **11.23**.
- Wave 4 spiral: 1 arm, interval `roundi(9.8)` = 10, speed 126. `N` = **15.24**.
- **Jet:** wave 1 accelerating fan: count 3, interval 125, speed `max(70, 52.5)` = 70, v_cap 247.5, v_eff 158.75, `N` = **5.81**. Wave 2 pod stream: burst `roundi(3.9)` = 4, interval 126, speed 192, `N` = **6.35**. Wave 3 wall: count `roundi(4.9)` = 5, interval 200, speed 93.5, `N` = **8.21**. Wave 4 lock fan: count `roundi(5.25)` = 5, interval 168, speed 135, `lock` 42, `N` = **8.47**.

**F6. Preview scores, ratios and wave checks**

`Q_preview(N) = F3(runners = {preview N}, rule = preview rule)`  (M = 1, no concurrency term)
`Q_w5 = F3(runners = all four wave-5 previews)`
Checks: `Q_preview(N) <= wave_frac[N] x Q_cap`; `N_preview / N_base <= 0.60`; `v_eff_preview / v_eff_base <= 0.90`; `Q_w5 > max Q_preview(1..4)`; `Q_boss >= 1.20 x Q_w5`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Wave fractions | `wave_frac[1..5]` | float | 0.32, 0.36, 0.40, 0.45, 0.75 | Strictly increasing |
| Ratios | `preview_n_ratio_max`, `preview_v_ratio_max` | float | 0.60, 0.90 | |
| Boss over wave 5 | `boss_over_w5_min` | float | 1.20 | |

**Output Range:** `Q_preview` 2 to 7; `Q_w5` 12 to 15. **Example, Fortress** (caps 5.76 / 6.48 / 7.20 / 8.10 / 13.50): wave 1 **4.02** (density 0.341, speed 1.700, lane 0.979, aim 1.000); wave 2 **2.05**; wave 3 rule only `R` = 4 x 0.5 = **2.00**; wave 4 **2.67**; wave 5 (fan 5.46, ring 12.00, spiral 15.24 gives `N` = 32.69; density 1.962, speed 2.040, lane 0.979, aim 1.000, `M` = 4 gives 4.500, `R` 2.000) **12.48**; ratio `Q_boss / Q_w5` = 17.75 / 12.48 = **1.42**. N ratios 0.277 / 0.278 / 0.389; speed ratios 0.75 / 0.80 / 0.90. **Example, Jet** (caps 7.36 / 8.28 / 9.20 / 10.35 / 17.25): **6.66 / 3.94 / 2.78 / 5.43**; wave 5 without the carried armour: `N` = 7.68 + 7.53 + 8.04 + 8.47 = 31.72; density 1.903, speed 2.880 (pod 216 px/s), lane 1.197, aim 2.000, behaviour 2.000, `M` = 4 gives 4.500: **14.48**; ratio 22.14 / 14.48 = **1.53**. N ratios 0.472 / 0.185 / 0.271 / 0.567; speed ratios 0.794 / 0.80 / 0.85 / 0.90.

> Decided under auto-approve (2026-11-03): weights 3 / 2 / 2 / 2 / 2 / 1.5 and rule weight 4; `N_unit` 50; `v_ref` 150; behaviour points 0 / 1 / 1 / 2; aim points 0.5 / 1.0 (+0.5 re-aim); `L_cap` 2; the F6 ratios 0.60 and 0.90; the preview rows; subset worst case with the enrage state excluded; part role (orbit) not scored in v1 (Open Question 6).

## Edge Cases

**Breaker net (added 2026-11-03, wave 4, plane-kits-sentry-breaker.md):** a Breaker Erase Net removes up to ~120 bullets per 930 ticks per slot. Patterns must stay survivable without it, and lethal shapes must not depend on those bullets surviving (a hole erased in a wall or ring must not make the rest unfair, and a pattern must not be balanced on the assumption that the net is absent).

**Budget evaluation**
- **If a boss has 5 non-core parts**, the lint enumerates all 32 subsets; with 6 non-core parts (Boss lint already rejects this) the budget lint refuses to run and reports the Boss error.
- **If a subset has no active runner** (every gated pattern is out of range and no runner is alive), `Q` = rule points only, never negative, and the subset cannot be the peak unless the boss has no fire.
- **If `lane_clear` is zero or negative**, `L` = 2 (the cap) and F8's fairness error also fails the lint; no division by zero occurs.
- **If `Q_boss` is over the cap**, the lint prints `Q_boss`, `Q_cap`, the subset that produced it, and the per-term breakdown, so the author knows which term to cut.
- **If `Q_boss` is under `fill_min x Q_cap`**, the lint fails with the same breakdown (the boss is too light for its stage).
- **If a gated pattern's gate bound equals a part-kill intensity exactly** (the Jet lock fan at 0.4, two of five parts), the gate is inclusive (Library F3 `epsilon` 1e-6), so the pattern counts as active in that subset.
- **If the enrage state would be the highest `Q`** (Fortress all parts alive at `I_eff` = 1: `N` = 215.83), it is ignored for the cap but included in the 1,700 density check (V10) and the 450 runner warning.
- **If the Critical window is considered**, it is excluded; the core is armoured at 20 % there and the emitters equal the Exposed set, so the Exposed value already covers its bullets.
- **If the boss hp is rebalanced** (Boss F6 or a balance pass), `Q` is unchanged: `Q` never reads hp. Only pattern, rule and speed edits move it.
- **If a pattern value is edited**, `q_boss_x100` no longer matches (V12) until the author updates it, which forces a deliberate look at the new number.

**Preview transform**
- **If the base count is at or below the floor** (a 2-bullet fan), `count_eff` = base count and the reduction must come from interval and speed; V5 fails if the N ratio is still over 0.60.
- **If the scaled speed falls under `v_min` 70** (an Accelerate pattern starting at 70), `speed_eff` = 70 (the Jet wave 1 fan) and the reduction comes from `v_cap` and interval; V5 uses `v_eff`.
- **If the base pattern is gated** (the Jet lock fan, gate [0.4, 1.0]), the preview ignores the gate and fires at intensity 0; its `start_delay` is at least 48 so it does not ambush.
- **If the base pattern has `*_at_full` values**, the preview uses the non-escalated values; escalation is never previewed.
- **If the base pattern is an aim-lock pattern**, the preview's `lock_ticks` is `min(60, lock + 12)`; if that makes `lock_ticks` reach or pass `interval_eff`, V10 (Library F8: `lock_ticks < interval`) fails.
- **If a spiral preview's arms would be 2**, it is forced to 1; the second arm is the boss's own step up.
- **If a flak mechanic is previewed**, count scales as a ring, `flak_delay` and `standoff` are unchanged (Library F8: delay at least 18, standoff at least `R_safe + 8`).
- **If `roundi` lands on .5** (Jet wave 5 pod burst 4.5), it rounds away from zero to 5.

**Stage and wave rules**
- **If a native enemy uses a novelty tag before its debut wave**, the Wave director strips it (Rule 20); if the stage lint finds an unstripped use, it is an error.
- **If a wave's own enemies already fire the same family as the preview** (wave 2's fighters fire aimed streams while wave 2 previews the ring), nothing breaks: only the new idea is gated, not familiar ones.
- **If carrier hp is short against the reference dps** (balance update 2026-11-03: `ref_dps` 800, `ref_uptime_pct` 70, so 560 hp/s; flak gunner 1,200 hp = 2.1 s, radar gunner 1,500 = 2.7 s, heavy bomber 4,000 = 7.1 s, missile carrier 5,000 = 8.9 s, before plating), a `gunner` carrier of a wave-1 or wave-2 preview (interval 106 or 171 ticks, `start_delay` 48) may die after one volley or none. This system's `Q` never reads hp, so the caps are unaffected; the effect is exposure time only. Mitigation: the Wave director spawns at least 2 successive carriers per preview wave (3 when the carrier is SMALL; Director Rule 18, Open Question 1 closed), and the first volley fires `start_delay` 48 ticks (0.8 s) after arming. *Note 2026-11-03:* the Jet previews m1/m2 ride a SMALL `fighter` (hp 50), which can die before its first volley even with 3 carriers; a `preview_hp_floor` (Enemy) or moving these previews to a `gunner` is likely needed (Director Open Question 2).
- **If the player kills a preview carrier instantly**, the preview was seen for less time; the Wave director may respawn up to its own `carrier_spawns` budget (Open Question 1), but never above `preview_alive_max` at once.
- **If the player is in co-op**, previews are not scaled, `alive` stays `preview_alive_max`, and carrier hp scales as MEDIUM/LARGE (Enemy Rule 22); a 4P wave is not made harder by this system.
- **If the player skips or loses a wave (death)**, nothing is rescheduled; previews are tied to the wave index, not to the player's progress.
- **If a continue restarts a wave**, it replays with the same preview (waves are deterministic).
- **If the stage has a different number of waves than 5**, V13 fails.

**Boss data**
- **If a boss pattern is added to a part without a binding**, V2 fails (unbound slot).
- **If one pattern slot serves two mechanics**, V2 fails (double binding).
- **If a carried mechanic's parameters change** (Jet armour 30 instead of 25), the hash differs, V11 demands a normal mechanic with a preview, and since the Jet already has 4 mechanics the author must drop one or restore the value.
- **If a boss has only 3 interesting ideas**, the fourth mechanic must still exist; the author splits one (for example a variant) or adds a rule. A boss with fewer than 4 fails V1.
- **If a new era's novelty tag is used by two mechanics**, V8 fails: one owner only.
- **If the Plasma Ring (Target) is added**, it needs its own budget file; its IMMUNE rule and Warp behaviour are the stage-4 novelty (Open Question 5).

> Decided under auto-approve (2026-11-03): the enrage state does not count towards the cap; preview ignores gates and escalation; a fixed number of mechanics (4) forces authors to split rather than pad; carried-mechanic hash equality.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Boss and boss parts (14) — GDD | Hard | Parts, emitters, patterns, `tags[]`, `core_rule`, `core_armor_pct`, `K` non-core parts (<= 5) |
| Bullet pattern library (9) — GDD | Hard | F3, F8, F9 as pure functions; pattern resources; the 1,700 budget; V4 era language |
| Enemy and AI (10) — GDD | Hard | Role tables, plating ranges, spawn contract (`preview` param), carrier bodies |
| Bullet manager (3) — GDD | Soft | Behaviour vocabulary and defaults (Accelerate `v_cap` 330, Warp 66 px/s estimate), `v_min` 70 |
| Game concept (section 10) | Soft | One new behaviour per era; stage 1 sparse and slow |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Wave and stage director (16) | Hard | `PreviewSet[1..5]`, `check_stage` (wrapped by the Director's validator), `novelty_debut_wave`, `preview_alive_max`, `combo_window_ticks` | [yes](wave-and-stage-director.md) |
| Era shift (19) | Hard | Behaviour and option ladder (`EraDef`), novelty gating, `StripMap` | yes |
| Boss (14) | Hard | Budget file required; `tags[]` convention | yes |
| Enemy and AI (10) | Hard | `preview` spawn param and emitter swap | yes |
| Tutorial (30) | Soft | Mechanic ids and names; `mechanic_previewed` | yes ([GDD](tutorial.md)) |
| Plane kits Sentry, Breaker (29) | Soft | Breaker net erase bound (authoring note, Edge Cases) | yes ([GDD](plane-kits-sentry-breaker.md)) |
| Analytics / balance passes | Soft | `Q` per phase to compare with death data | not yet |

**Amendments to other docs** (apply at wrap-up)

1. **Systems index:** row 15 status `**Designed** (pending review) — [GDD](boss-power-budget.md)`; Depends on `10, 14` becomes `9, 10, 14`; progress tracker adds this GDD; "Decisions captured" first bullet: add "(detail in boss-power-budget.md)".
2. **Enemy and AI** (`enemy-and-ai.md`): (a) spawn `params` gains `preview` (mechanic id) which swaps emitter 0 patterns for the preview set and forces `intensity_source = CONSTANT(0)`, with plating overrides for rule previews; (b) novelty gating: a role definition may carry `novelty_tags`; before the debut wave the Wave director strips `aim_lock` (`lock_ticks` 0) and Accelerate (to Straight) from native patterns; the 1970s `fighter` row (aim-locked fan, accelerating rice) is the case; (c) Rule 19 `WAVE` intensity (`(wave - 1) / 4`) is not used by preview emitters; (d) Boss power budget (15) row in Dependencies.
3. **Boss and boss parts** (`boss-and-boss-parts.md`): (a) Open Question 8 closed: mechanic lists are in this GDD; (b) Rule 2 `tags[]`: convention `mech:<mechanic_id>` on every part with a bound pattern; (c) Jet Carrier gains the pattern `core_lock_fan` (core emitter 1: aim-locked fan, count 7, spread 0.1875, interval 120, speed 150, `lock_ticks` 30, gate [0.4, 1.0], `start_delay` 48); (d) Fortress `core_rage_ring` is bound as a variant of `m2_engine_ring`; (e) Dependencies: Boss power budget (15) row points to this GDD, and the boss data lint requires a `data/boss_budget/<id>.tres` file; (f) F9 pattern table: add `core_lock_fan` to the Jet data.
4. **Bullet pattern library** (`bullet-pattern-library.md`): (a) expose F3, F8, F9 as pure functions (`PatternMetrics.lane_clear`, `runner_density`, `interval_eff`, `count_eff`) so this lint does not copy them; (b) Boss (14) row mentions Boss power budget (15) for preview derivation; (c) F9 example "Jet carrier with everything active: about 116" is the sum of all runners ignoring gates and part deaths; the real worst case from the part-destruction subsets is 79.12 (Jet) and 154.90 (Fortress); (d) V4 note: "one new trick per era is enforced by Boss power budget (15)".
5. **Wave and stage director (16)** *(done 2026-11-03: [wave-and-stage-director.md](wave-and-stage-director.md) Rules 18-19, V-D5)*: schedule previews per Rule 13 to 17; run `check_stage`; apply novelty gating; keep `preview_alive_max` and `combo_window_ticks`; check the stage's concurrent density against the same 1,700.
6. **Era shift** (19): own the behaviour and option ladder, and the stripped-native-pattern mapping. *(Done 2026-11-03: the data home moved to `EraDef.new_behaviour` / `new_option`; `budget_rules.tres` reads `EraLadder`.)*
7. **Co-op** (`coop-and-team-chain.md`): Interactions row: Boss power budget (15), previews unscaled by `N`.
8. **Game events and session** (`game-events-and-session.md`): optional event `mechanic_previewed(boss_id, mechanic_id, wave)`.
9. **Game concept** (`game-concept.md`): section 10 note: "Each new era introduces one new bullet behaviour at a time before combining them" is implemented by Boss power budget (15).
10. **Registry** (`design/registry/entities.yaml`): add the entries from the report; add `boss-power-budget` to `referenced_by` of `lane_min_clear`, `enemy_plating`, `hit_radius_orb`, `hit_radius_rice`, `v_min`.

**Bidirectional check:** Boss (14) already lists "Boss power budget (15)" in Dependencies and Open Question 8. Enemy (10) and the Pattern library (9) must add this GDD (amendments 2 and 4). Wave (16), Era shift (19) and Tutorial (30) must list it when written. All interfaces to undesigned systems are **provisional**; the contracts above are what this GDD expects.

## Tuning Knobs

**Owned by this system** (`data/boss_budget/budget_rules.tres` for globals; `data/boss_budget/<boss_id>.tres` per boss)

| Knob | Default | Safe range | Too low | Too high | Interacts with | Category |
|---|---|---|---|---|---|---|
| `w_D` density weight | 3 | 2 to 4 | Density barely moves `Q`; screen-filling bosses pass | Every boss must be sparse | F1, `enemy_cap` budget 1,700 | Curve |
| `w_S` speed weight | 2 | 1 to 3 | Fast needles pass cheaply | Slow bosses only | `v_cap_global` 480 | Curve |
| `w_L` lane weight | 2 | 1 to 3 | Tight lanes pass cheaply | Dense patterns rejected | `lane_min_clear` 14 | Curve |
| `w_A` aim weight | 2 | 1 to 3 | Lock and tracking look free | Aimed patterns dominate `Q` | Library F5 | Curve |
| `w_B` behaviour weight | 2 | 1 to 3 | Era trick is free | Era bosses dominated by one trick | Bullet manager behaviours | Curve |
| `w_C` concurrency weight | 1.5 | 0.5 to 3 | Ten mechanics pass as easily as three | Combinations never pass the cap | Wave 5 combination | Curve |
| `w_R` armour weight | 4 | 2 to 6 | Armour is free | Armour dominates | `core_armor_pct` 25 | Curve |
| `r_immune` | 5 | 3 to 8 | IMMUNE core under-priced | Immune bosses impossible | Target | Curve |
| `N_unit` | 50 | 30 to 100 | Density term explodes | Density term vanishes | `w_D` | Curve |
| `v_ref` | 150 | 120 to 180 | Speed term inflated | Speed term deflated | Library default speed | Curve |
| `L_cap` | 2.0 | 1.5 to 3 | Tight lanes under-priced | One lane dominates | `lane_min_clear` | Curve |
| `cap_base` / `cap_step` | 13 / 5 | 8 to 18 / 3 to 8 | Stage 1 boss too easy; stages bunch | Stage 1 too hard; Stage 4 unreachable | Fill rule | Gate |
| `fill_min` | 0.85 | 0.7 to 0.95 | Weak bosses pass | Authors cannot hit the window | `cap_step` | Gate |
| `wave_frac[1..5]` | 0.32, 0.36, 0.40, 0.45, 0.75 | W1 0.25 to 0.40; W5 0.6 to 0.85; increasing | Previews too weak to teach | Previews as hard as the boss | Preview rows | Gate |
| `boss_over_w5_min` | 1.20 | 1.1 to 1.5 | Wave 5 as hard as the boss | Large jump into the boss | `wave_frac[5]` | Gate |
| Preview rows (count / interval / speed %) | 60/160/75, 65/150/80, 70/145/85, 75/140/90 | count 40 to 90; interval 120 to 200; speed 60 to 95 | Previews unreadable or boring | Previews equal the boss | `preview_n_ratio_max` | Feel |
| `count_floor` (fan / ring / wall / stream) | 2 / 4 / 5 / 2 | 1 to 6 | Previews are one bullet | Floors fight the ratio | F5 | Feel |
| `preview_lock_add` | 12 ticks | 6 to 24 | Radar lock tell no easier than the boss's | Free dodge (library max 60) | Library lock range 18 to 60 | Feel |
| `preview_n_ratio_max` / `preview_v_ratio_max` | 0.60 / 0.90 | 0.4 to 0.8 / 0.8 to 1.0 | Previews too weak | Preview not "reduced" | F6 | Curve |
| `preview_alive_max` | 1 | 1 to 2 | | Preview density doubles (`alive` factor) | Wave density | Gate |
| `combo_window_ticks` | 180 | 120 to 300 | Combination does not overlap | Wave 5 front-loaded | Wave pacing | Gate |
| `variant_count_mult_max` / `variant_speed_mult_max` | 2.0 / 1.25 | 1.5 to 3 / 1.1 to 1.5 | Escalated forms forbidden | A variant is a different mechanic | V4 | Gate |
| `armour_preview` (plating ticks / pct) | 180 / `min(75, core pct + 25)` | 60 to 180 / 25 to 75 | Plate invisible | Heavy takes too long to kill | Enemy `enemy_plating` | Feel |
| `behaviour_ladder` | Straight / Accelerate / Curve / Warp by stage | fixed by concept | | | Era shift (data home `EraDef.new_behaviour`, read via `EraLadder`; 2026-11-03) | Gate |
| `L_default` (curve, Warp) | 0.5 | 0.3 to 1.0 | | | Target | Curve |
| `mechanics_per_boss` | 4 | fixed (5 waves) | | | Waves | Gate |

**Owned elsewhere:** boss hp, fight length and enrage (Boss 14, F6); patterns and F3 / F8 / F9 constants (`lane_min_clear` 14, `d_ref` 160, `D_lane_max` 120, 450 and 1,700 densities) (Pattern library 9, Bullet manager 3); carrier hp, kill values, plating limits (Enemy 10, Scoring 8); wave timing and carrier spawns (Wave director 16); native enemy stripping (Era shift 19); `hp_pct(N)` (Co-op 18).

## Visual/Audio Requirements

Draw layers are art bible §6.8. The bullet rules in Pattern library V1 to V3 apply unchanged. Bullets always win: no effect here draws over enemy bullets (layer 8). No new bullet shape, no Void Indigo (`#4A5CFF`), no Ink (`#0B0B2A`) on any mark.

**V1. Preview mark** (a preview carrier must look related to the boss part it echoes)
- A 2 px stripe on the carrier sprite (layer 4, sprite pixels) in the **boss part's era Accent colour**, on the side facing the player: 8 px long on SMALL, 12 px on MEDIUM, 16 px on LARGE carriers. Era Accent: 1941 sepia-orange, 1970s hard orange (Pattern library V1 muzzle colours).
- The windup glow (12 ticks before each volley, Boss V1) is the same effect as on the boss part, so the visual tell matches.
- A plated preview heavy (rule preview) shows the same plate sprite as the Fortress core plating (Collision V3 plate-fall at tick 180).
- No label, text or icon over carriers (the field stays clear). Grayscale gate: the stripe differs from the carrier body by one value step or more.

**A1. Audio**
- A preview volley plays **the same cue as the boss pattern** it previews (Pattern library A1 table: fan "pew", ring thump, wall sweep, spiral tick). Eras change timbre only.
- The aim-lock rising tone and click are identical in preview and boss.
- No stinger on "preview spawned" in MVP.

## UI Requirements

No player-facing UI. Mechanic names (`mech.<boss_id>.<id>.name`, Bengali and English, `Localization` keys, S-tier size) exist only for the debug overlay and the Target Tutorial (30).

**Debug only (development builds):**
- A budget overlay listing, for the current stage and boss, each mechanic with its `Q`, the stage cap, `fill`, and the subset that produced `Q_boss`.
- A wave overlay showing which preview is live (`mechanic_id`, wave N, `alive`), `Q_preview` and its cap.
- The lint output prints per-term breakdowns (F3) to the test log.
- A `skip to wave 5 combination` and `spawn preview <mechanic>` command.

## Acceptance Criteria

Defaults used: `w_D` 3, `w_S` 2, `w_L` 2, `w_A` 2, `w_B` 2, `w_C` 1.5, `w_R` 4, `N_unit` 50, `v_ref` 150, `L_cap` 2, `cap_base` 13, `cap_step` 5, `fill_min` 0.85, `wave_frac` 0.32 / 0.36 / 0.40 / 0.45 / 0.75, `boss_over_w5_min` 1.20, preview rows 60/160/75, 65/150/80, 70/145/85, 75/140/90, `count_floor` 2 / 4 / 5 / 2, `preview_lock_add` 12, `preview_n_ratio_max` 0.60, `preview_v_ratio_max` 0.90, `preview_alive_max` 1, `combo_window_ticks` 180, `lane_min_clear` 14, `d_ref` 160, `D_lane_max` 120, `v_min` 70, 60 ticks/s.

**Test setup:**
- **Classes:** logic lives in node-free RefCounted classes: `BossBudget` (F1 to F4, subset search), `PreviewBuilder` (F5), `BudgetLint` (V1 to V14), `StageLint` (Rule 22). There is no `delta` and no `tick()`. The F3 / F8 / F9 helpers come from the Pattern library's `PatternMetrics` (amendment 4).
- **Injected:** loaded `.tres` resources from `data/bosses/*.tres`, `data/patterns/*.tres`, `data/boss_budget/*.tres`, `data/enemies/<era>/roles.tres`; fake wave scripts (arrays of spawn records); a `FakeEnemyManager` that records `spawn(..., params)` and the emitter pattern values it would build.
- **Files and tags:** tests in `tests/unit/test_boss_budget_[formulas|mechanics|preview|lint|novelty|stage].gd`, `extends SceneTree` like `tests/unit/test_chain_tracker.gd`, named `test_budget_[scenario]_[result]`. Integration: `tests/integration/test_boss_budget_*.gd`. Numbers are read from the `.tres` files, never literals, except the golden tables (AC-04, AC-07, AC-11), whose values are the spec. Tolerance: 0.005 on `Q` and ratios, 0.01 on `N`.
- Tags: [Unit] headless logic · [Integration] real Enemy manager and Pattern library · [Perf] reference machine · [Manual] human.

### Mechanic lists and bindings (Rules 1 to 8)

- **AC-01 [Unit] (V1):** Fortress and Jet each load with exactly 4 non-carried mechanics, `index` 1 to 4 once each; the Jet lists 1 carried mechanic; a copy with 3 or 5 mechanics, or two with `index` 2, fails V1.
- **AC-02 [Unit] (V2):** every pattern slot of every Fortress and Jet part is bound once: Fortress 7 slots (2 turret, 2 engine, core spiral, core ring, and the core pattern list counted by slot) all bound; adding an unbound pattern to a turret fails V2 and names the part; binding the same slot to two mechanics fails V2.
- **AC-03 [Unit] (Rule 4 tags):** every part with a bound pattern has the tag `mech:<id>` matching its mechanic; removing the tag from `turret_l` fails the lint.
- **AC-04 [Unit] (Rule 7, V4 variant):** the Fortress core ring (count 24 = 2.0 x 12, speed 110 = 1.1 x 100) passes; count 25 fails; speed 126 (1.26 x) fails; a variant with a different shape fails.
- **AC-05 [Unit] (V11 carried):** the Jet's `c_armoured_core` hashes equal to `fortress_1941.m3_armoured_core`; changing the Jet's `core_armor_pct` to 30 fails V11.

### Formulas (F1 to F4)

- **AC-06 [Unit] (F1 density):** Fortress turret pair `N` = 20.54, engine pair 40.42, core spiral at `I` = 0 / 0.25 / 0.5 / 0.75 / 1 = 39.18 / 45.71 / 54.86 / 68.57 / 91.43, core ring 63.47. Jet fan at `I` = 0 12.31, `I` = 0.4 (count 7, interval 60) 22.40, `I` = 1 52.36; pods (3) 34.29; walls (2, gap slot subtracted) 30.36; lock fan 14.93.
- **AC-07 [Unit] (F2 terms):** fan spread 0.21 → `L` 0.4895; ring n = 12 → 0.2421; wall corridor 27 → 0.5185; spiral `I` = 0 → 0.0930, `I` = 1 → 0.2271; rice fan 0.165 → 0.5983; a lane of 5 px → `L` = 2 (cap, not 2.8); a lane of 0 or less → `L` = 2 and no exception; ARMOURED 25 → `R` 3.00; plating 50 → 2.00; IMMUNE → 5.00.
- **AC-08 [Unit] (F3 single mechanic):** Fortress `m1_turret_fan` 5.48, `m2_engine_ring` 4.24, `m3_armoured_core` 3.00, `m4_core_spiral` (`I` = 0) 4.40; Jet `m1_accel_fan` 7.60, `m2_pod_stream` 6.26, `m3_wing_wall` 4.33, `m4_radar_lock` 6.02.
- **AC-09 [Unit] (F3 phase):** Fortress with nothing destroyed → `Q` 17.75 (density 6.008, speed 2.267, lane 0.979, aim 1.000, concurrency 4.500, rule 3.000); only the core left → 13.72, rule term 0.
- **AC-10 [Unit] (F4 peak, Fortress):** `Q_boss` = 17.75 with the empty destroyed set; the lint enumerates 16 subsets; fill 0.986 passes; a copy with the turret fan at count 5 gives `Q_boss` 18.58 and fails V7 (over 18).
- **AC-11 [Unit] (F4 peak, Jet):** `Q_boss` = 22.14 at a destroyed set of two pods (`I` = 0.4, lock fan active, `M` = 5); the lint enumerates 32 subsets; the empty set gives 19.51; only the core left 13.40; fill 0.963 passes. A copy with the lock fan gate at 0.2 raises `Q_boss` above 23 or leaves it in range as computed by the same formula, and the test asserts the computed value equals the hand check read from the file.
- **AC-12 [Unit] (stage cap):** `Q_cap` = 18 / 23 / 28 / 33 for stages 1 to 4; `cap_step` 4 gives 17 / 21 / 25 / 29 and the Fortress fails V7 (17.75 > 17).
- **AC-13 [Unit] (V12 parity):** `q_boss_x100` 1775 (Fortress) and 2214 (Jet) pass; a stored 1800 fails with the computed value in the message.
- **AC-14 [Unit] (enrage excluded):** the Fortress enraged state (all parts alive, `I_eff` = 1: `N` = 215.83) is not used for the peak; it is used in the density check and passes (<= 1,700).

### Preview transform (F5, Rules 13 to 17)

- **AC-15 [Unit] (F5 Fortress):** wave 1 fan → count 2, interval 106, speed 127.5, `N` 5.68; wave 2 ring → count 8, interval 171, speed 80, `N` 11.23; wave 3 → plating 180 ticks at 50 %, `R` 2.00; wave 4 spiral → 1 arm, interval 10, speed 126, `N` 15.24.
- **AC-16 [Unit] (F5 Jet):** wave 1 → count 3, interval 125, speed 70, v_cap 247.5, v_eff 158.75, `N` 5.81; wave 2 → burst 4, interval 126, speed 192, `N` 6.35; wave 3 → count 5, interval 200, speed 93.5, `N` 8.21; wave 4 → count 5, interval 168, speed 135, `lock_ticks` 42, `N` 8.47.
- **AC-17 [Unit] (rules of the transform):** the Jet wave 4 preview fires at intensity 0 although the base gate is [0.4, 1.0]; every preview has `start_delay` >= 48, `*_at_full` = −1, spread, shape and behaviour equal to the base; `roundi(4.5)` = 5 (Jet wave 5 pod burst).
- **AC-18 [Unit] (V5 reduction):** all eight single previews (Fortress 1, 2, 4; Jet 1 to 4; plus rule check) satisfy N ratio <= 0.60 (0.277 / 0.278 / 0.389; 0.472 / 0.185 / 0.271 / 0.567) and speed ratio <= 0.90 (0.75 / 0.80 / 0.90; 0.794 / 0.80 / 0.85 / 0.90). A Fortress wave 1 row of 100 / 100 / 75 (count 3, interval 66) gives `N` 13.69 > 0.60 x 20.54 = 12.32 and fails.
- **AC-19 [Unit] (F6 wave caps):** Fortress `Q_preview` = 4.02 / 2.05 / 2.00 / 2.67 with caps 5.76 / 6.48 / 7.20 / 8.10 → pass; Jet 6.66 / 3.94 / 2.78 / 5.43 with caps 7.36 / 8.28 / 9.20 / 10.35 → pass; setting `wave_frac[1]` to 0.20 makes the Fortress cap 3.60 and fails V6 on wave 1.
- **AC-20 [Unit] (combination):** Fortress wave 5 `Q_w5` = 12.48 (cap 13.50) and `Q_boss / Q_w5` = 1.42 ≥ 1.20; Jet wave 5 (no armour) = 14.48 (cap 17.25), ratio 1.53; `Q_w5 > max(Q_w1..Q_w4)` in both; a wave 5 that omits one mechanic fails V13.
- **AC-21 [Unit] (rule preview):** the Fortress `m3` preview sets `plating_ticks` 180 and `plating_armor_pct` 50 (= `min(75, 25 + 25)`); values outside the Enemy plating range (60 to 180 ticks, 25 to 75 %) fail.
- **AC-22 [Unit] (co-op, determinism of data):** building the preview sets with `N` = 1 and `N` = 4 gives the same property hash; the Boss pattern hash at `N` = 4 equals `N` = 1.
- **AC-23 [Unit] (determinism):** `PreviewBuilder.build_stage(1)` run twice gives an equal state hash; the builder makes zero calls to `randf()` or the gameplay RNG; the lint result is independent of resource load order.

### Novelty (Rules 18 to 21)

- **AC-24 [Unit] (ladder):** the Fortress uses only Straight; the Jet uses Straight and Accelerate; a Fortress copy with an Accelerate pattern fails V8; a Jet copy with a Curve pattern fails V8.
- **AC-25 [Unit] (one new each):** the Jet's novelty tags are `behaviour:accelerate` (owner `m1_accel_fan`) and `option:aim_lock` (owner `m4_radar_lock`); `novelty_debut_wave` = 1 and 4; a copy that also tags `option:reaim_each_volley` fails V8; two mechanics owning the same tag fails V8.
- **AC-26 [Unit] (gating):** with novelty gating, a stage-2 `fighter` spawned in wave 2 has `lock_ticks` 0 and Straight bullets (the role definition keeps its lock and Accelerate); in wave 4 it has its lock; the Accelerate stripe ends at wave 1 (debut 1), so wave 1 may use it. The stripped Straight speed is `v_strip` (Era shift F4, default `V_EFF`).

### Stage lint (Rule 22)

- **AC-27 [Unit] (valid stage):** a fake Fortress stage with `preview` carriers: wave 1 → `m1`, wave 2 → `m2`, wave 3 → `m3`, wave 4 → `m4`, wave 5 → all four spawned inside 180 ticks → passes `check_stage`.
- **AC-28 [Unit] (invalid stages):** a wave 2 that spawns the `m4` preview fails (early); a wave 4 without the `m4` carrier fails; a wave 5 missing `m2` fails; a wave 3 with two different previews fails; wave 5 spawn times 200 ticks apart fail the combo window; a stage with 4 waves fails V13.
- **AC-29 [Unit] (no stale previews):** no preview of a mechanic whose index is greater than the wave number appears in any wave of either stage's real data.

### Fairness and density (V10)

- **AC-30 [Unit] (F8 on previews):** every preview pattern passes the Pattern library fairness validator (fan lane >= 14 px, ring lane, wall corridor 27 >= 20, lock tell 18 to 60: Jet 42, `lock_ticks` < `interval_eff`).
- **AC-31 [Unit] (F9 on bosses):** Fortress largest `N_scene` over all subsets = 154.90 (only core runners) and enraged 215.83; Jet largest over all subsets and enraged each at most 1,700; no runner above 450.

### Integration

- **AC-32 [Integration] (carrier swap):** a real Enemy manager spawns a `gunner` with `preview = m1_turret_fan`: its emitter 0 shows count 2, interval 106, speed 127.5 and `intensity_source` CONSTANT(0); its hp, kill class and cancel radius equal the plain `gunner`; it is not a powerup carrier.
- **AC-33 [Integration] (gate bypass):** a Jet `gunner` with `preview = m4_radar_lock` fires its first locked fan `start_delay` 48 ticks after arming (lock tell starts at 6 ticks, within `lock_ticks` 42) at intensity 0.
- **AC-34 [Integration] (co-op density):** with `N` = 4, the number of preview carriers alive never exceeds `preview_alive_max` per mechanic and the preview bullets per carrier equal the solo values.

### Performance

- **AC-35 [Perf] (lint cost):** `BudgetLint` over both MVP bosses (16 + 32 subsets) completes in <= 200 ms on REF-PC (offline, not shipped); `PreviewBuilder.build_stage` for 5 waves completes in <= 5 ms and runs only at stage load.
- **AC-36 [Perf] (runtime cost):** with the system loaded, per-tick cost is 0 (no `tick()`); the allocation counter delta per tick is 0 over 1,000 ticks of a stage-1 run.

### Playtest (Manual)

- **AC-37 [Manual] (recognition):** 8 testers who played Stage 1 are shown the first 20 seconds of the Fortress; at least 6 of 8 say a named wave (1 to 4) contained something like what they see ("same as the gun in wave 1"). Fewer than 2 of 8 say a boss attack was a surprise they could not read.
- **AC-38 [Manual] (staircase):** 6 testers rank the difficulty of Stage 1 wave 1, wave 5, the Fortress and the Jet Carrier; at least 5 of 6 order them wave 1 < wave 5 < Fortress < Jet Carrier.
- **AC-39 [Manual] (one new thing):** testers after Stage 2 wave 1 can describe the new bullet trick ("they speed up"); after wave 4 at least 6 of 8 describe the radar lock tell ("a line shows where it will fire").
- **AC-40 [Manual] (wave 5 fairness):** across 10 first-time runs, deaths in the Fortress's wave 5 are fewer than deaths in the Fortress fight in at least 7 of 10 runs.
- **AC-42 [Manual] (exposure):** with `ref_dps` 800 fire, in at least 8 of 10 runs of each preview wave (Fortress waves 1 to 4) the player sees at least 2 volleys of the previewed mechanic (counted from `volley_fired` logs for carriers with `preview` set); if not, raise carrier spawns (Wave director) rather than carrier hp.
- **AC-41 [Manual] (readability):** a frame capture of a preview carrier and the matching boss part shows the same accent stripe colour family and the same windup glow; the grayscale gate passes; no stripe or effect covers a bullet.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | ~~How many preview carriers does a wave spawn over time (`carrier_spawns` budget), when does the combination spawn in wave 5, and can a killed carrier be respawned? With `ref_dps` 800 a 1,200 hp `gunner` dies in about 2.1 s, so each preview wave needs at least 2 successive carriers (see Edge Cases). This GDD fixes only `preview_alive_max` and the combo window.~~ **Closed 2026-11-03:** at least 2 successive carriers per preview wave (3 when the carrier is SMALL), each starting after the previous one's nominal exit; the wave-5 combination is spawned once, from wave tick 900 (900-1,060, inside `combo_window_ticks`); failed carrier/preview spawns are re-queued up to 2 times, 60 ticks apart (Director Rules 9, 18). (wave-and-stage-director.md) | Wave director (16) | Wave director GDD |
| 2 | Enemy contract: `preview` spawn param with emitter swap, `CONSTANT(0)` intensity and plating overrides; novelty stripping from native roles (the 1970s `fighter`). Confirm the table and where gating lives (Enemy vs Wave vs Era). | Enemy (10), Era shift (19) | Enemy review / Era GDD |
| 3 | `Q` weights, caps (18 / 23) and wave fractions are provisional. Re-fit against playtest death counts per phase and per wave once the first stage runs. | Designer, analytics | First playable Fortress |
| 4 | The Jet `core_lock_fan` is new and not in the Pattern library F10 migration or the Boss GDD data. Confirm the pattern, its gate 0.4 and the Boss GDD amendment 3. | Boss (14), Pattern library (9) | Boss review |
| 5 | Target-tier bosses: Plasma Ring (IMMUNE core + Warp shields) needs a mechanic list and a stage-4 budget; stage 3 has no boss yet. Sketch: `m1` shield orbit, `m2` curve radial, `m3` immune core, `m4` Warp ring (Warp = stage 4 novelty). | Designer | Target milestone |
| 6 | The boss-part **role** (an orbiting pod is harder to read than a fixed turret) is not scored in v1. Add an origin-motion term `O` (fixed 0, orbit 0.5)? | Designer | First Jet playtest |
| 7 | Should previews carry an on-screen hint (a bilingual codex line, a Tutorial tip) when a new trick debuts? | UX, Tutorial (30) | Tutorial GDD |
| 8 | Carried mechanics are left out of wave 5 (the Jet's armour). Should wave 5 of stage 2 include a plated carrier as a reminder? | Designer | Jet playtest |
| 9 | Aim lock is counted as a separate "option" novelty beside the one new behaviour. Confirm with the creative director that "one new bullet behaviour per era" allows one aim option too. | Creative director | Concept review |
| 10 | The fixed count of 4 mechanics per boss matches 5 waves. If the stage gains waves (Target), should mechanics per boss become `waves - 1`? | Producer, designer | Target scope |
| 11 | `Q` is reported to 2 decimals and stored x100. Is a per-term breakdown stored in the data for balance review dashboards? | Analytics | Balance tooling |
