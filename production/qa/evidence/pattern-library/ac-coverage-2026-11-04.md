# Pattern library — acceptance criteria coverage

| Field | Value |
|-------|-------|
| **GDD** | `design/gdd/bullet-pattern-library.md` (system 9) |
| **Date** | 2026-11-04 |
| **Build** | source, Godot 4.7.2.stable, Windows desktop |
| **Suites** | `bash tests/run_all.sh` — 14 suites, all PASS |
| **Verdict** | every unit-testable AC covered and passing; 7 ACs deferred with the reason stated |

## Where each AC is checked

| AC | Covered by | Note |
|---|---|---|
| AC-01 shared resource, two emitters | `test_pattern_determinism.gd::test_pattern_resource_is_shared_without_being_touched` | property fingerprint + B's log with and without A |
| AC-02 origin per tick, curve centre | `..._bullets_spawn_at_the_origin_of_their_own_tick` | |
| AC-03 stacked patterns, same tick | `..._stacked_patterns_fire_independently` | fan requests before ring; gating the ring leaves the fan's schedule |
| AC-04 request fields, refusal | `test_pattern_safety.gd::..._request_carries_every_field_the_bullet_needs`, `..._pool_refusal_is_not_retried` | |
| AC-05 F1 minimums | `test_pattern_timing.gd::..._f1_minimums_clamp_zero_fields_to_one` | |
| AC-06 F2 schedule | `..._burst_fires_on_the_exact_gdd_schedule` | 148/154/160/166/172/178, next 232 |
| AC-07 F2 fallback | `..._overlapping_burst_pushes_the_next_burst_later` | `interval_eff` 20 → 31 |
| AC-08 F3 scaling | `..._intensity_scales_interval_and_count` | 78→33 at 0.5 = 56; 5→9 at 0.125 = 6 |
| AC-09 gate epsilon | `..._gate_is_inclusive_within_one_epsilon` + `..._gate_agrees_with_the_validator` | the second sweeps 201 intensities × 5 ranges against `PatternMetrics.gate_open` |
| AC-10 intensity mid-burst | `..._intensity_change_mid_burst_applies_from_the_next_burst` | |
| AC-11 gate leave / re-enter | `..._leaving_the_gate_drops_the_burst_and_restarts_start_delay`, `..._gate_toggled_faster_than_start_delay_never_fires` | |
| AC-12 states | `..._states_follow_the_gdd_table` | Gated→Waiting→Firing→Cooling→Locking→Firing→Stopped |
| AC-13 fire hold | `..._fire_hold_skips_volleys_but_keeps_the_rhythm` | 172 uses φ(4), as in the unheld run |
| AC-14 RNG on skipped volleys | `..._skipped_volley_still_draws_its_randomness` | wall, spray and ring, with and without a hold |
| AC-15 fuse in a hold | `..._flak_fuse_inside_a_hold_is_used_up_and_never_fires_late` | |
| AC-16 lock + hold | `test_pattern_targeting.gd::..._lock_ends_unfired_when_the_gate_shuts_during_the_tell` | the hold variant of the same path |
| AC-17 stop mid-burst | `..._stop_mid_burst_fires_nothing_more` | |
| AC-18 fuse survives gate / stop | `..._fuse_survives_a_gate_or_a_plain_stop` | |
| AC-19 fuse cancelled on destroy | `..._fuse_is_cancelled_when_the_owner_is_destroyed` | also `remove_all_emitters` |
| AC-21 lock edge cases | `..._lock_ends_unfired_...`, `..._lock_with_nobody_alive_shows_no_tell_and_fires_down`, validator warnings in `test_pattern_validator.gd` | |
| AC-22 F4 rotation | `..._target_rotates_to_the_next_alive_slot_each_burst`, `..._target_cursor_holds_still_when_nobody_is_alive` | |
| AC-23 one target per burst | `..._every_bullet_of_a_burst_stores_the_same_target`, `..._cursor_advances_once_per_burst_even_when_held` | |
| AC-24 join / death mid-burst | `..._join_or_death_mid_burst_changes_nothing_until_the_next_burst` | |
| AC-25 F5 aim | `..._aim_matches_the_gdd_worked_example`, `..._aim_below_half_a_pixel_fires_straight_down`, `..._aim_has_no_upward_clamp`, `..._no_target_fires_down_and_stores_slot_zero` | 1.4959 rad, ±1 bam |
| AC-26 aim once vs re-aim | `..._normal_burst_aims_once_and_reaim_tracks`, `..._reaim_keeps_its_last_aim_when_the_target_dies` | |
| AC-27 lock timing | `..._lock_samples_the_position_lock_ticks_early`, `..._locked_burst_fires_even_if_the_target_dies`, `..._short_start_delay_samples_the_lock_at_activation` | |
| AC-28 lock-tick cursor | `..._lock_cursor_advances_at_the_lock_tick` | |
| AC-29 – AC-36 geometry | `test_pattern_geometry.gd`, one test per shape | seeded shapes assert the `PatternMetrics` function the runner itself calls, fed the AC's quoted `u` |
| AC-37 – AC-39 spawn safety | `test_pattern_safety.gd` | AC-39's flak clause is all-or-none; see GDD OQ 13 |
| AC-40 seeding + lint | `test_pattern_determinism.gd::..._emitter_seed_is_the_stable_id_recipe`, `..._runtime_has_no_global_random_calls` | the lint reads the six runtime sources |
| AC-41 emitter independence | `..._emitter_streams_are_independent_of_every_other_emitter` | 4 arrangements: baseline, add, remove, reverse |
| AC-42 determinism | `..._scripted_scenario_is_bit_identical_twice`, `..._rng_state_is_unchanged_by_what_the_players_did` | 1,800 ticks, 4 emitters, 8 patterns, ramp, hold 600-630, 2 moving players, 1 death |
| AC-44 same-tick order | `..._same_tick_order_is_registration_then_pattern_list` | |
| AC-45 pool full | `test_pattern_safety.gd::..._pool_refusal_is_not_retried` | |
| AC-46 all data passes | `test_pattern_validator.gd::..._every_authored_pattern_passes_the_validator` | **16 patterns, 0 errors, 0 warnings** |
| AC-47 thresholds | `..._validator_catches_closing_lanes`, `..._catches_unreadable_walls`, `..._catches_unfair_flak_and_spray` | each pass/fail pair from the AC table |
| AC-48 overlap / lock / safe radius | `..._validator_catches_burst_overlap_and_bad_locks`, `..._catches_a_spawn_radius_too_small_for_the_speed` | |
| AC-49 prototype margins | `..._authored_data_reports_the_gdd_fairness_margins` | fan lane 21.4, corridor 27, speed 110, reach 138, spawn safe 41.5; **arm gap 150.5, not 133 — GDD OQ 12** |
| AC-50 F10 golden table | `..._migrated_data_matches_the_f10_golden_table` | every row, plus the era behaviour language |
| AC-51 F9 density | `..._density_matches_the_f9_worked_examples`, `..._density_catches_a_runner_and_a_gate_overlap` | jet fan 52.4, jet 116, fortress 155, synthetic ring 512 |
| AC-52 no canvas scale | `..._runtime_has_no_canvas_scale_factor` | |
| AC-53 – AC-55 performance | `tests/perf/pattern_bench.gd` | see below and [spike-0002](../../../../docs/architecture/spike-0002-pattern-bench.md) |
| — integration | `tests/integration/test_pattern_world.gd` | the library inside a real `SimWorld`: 4-player co-op, determinism, `death_fire_hold`, every shipped platform |

## Performance

| Criterion | Budget | Measured | Verdict |
|---|---|---|---|
| AC-53, AC's rig (120 runners, all in phase) | ≤ 0.2 ms p99 | p99 0.527 ms, mean 0.100 ms | **FAIL** — rig is ~2× over F9's scene budget (GDD OQ 11) |
| AC-53, at F9's 1,700-bullet budget | ≤ 0.2 ms p99 | p99 0.115 ms, mean 0.054 ms | PASS |
| AC-54 pattern + bullet update | ≤ 1.7 ms p99 | p99 1.292 ms | PASS |
| AC-55 allocation (6,000 ticks) | < 1 MiB, ±5 objects | −1.4 KiB, +0 objects | PASS |

## Not covered, and why

| AC | Why not |
|---|---|
| AC-20 pause through the tree | Needs the real `GameLoop` paused in a `SceneTree` test. `GameLoop` already gates ticks on pause (ADR-0002), so the runners freeze with it; the explicit test is still owed. |
| AC-43 fixed tick at 30/60/144 fps + a stall | Same harness gap. The sim is tick-driven with no `delta`, and `tests/integration/test_pattern_world.gd` pins the state hash across identical runs; the frame-rate sweep is owed. |
| AC-56 – AC-61 visual and audio | **Blocked: no assets.** `assets/art/` and `assets/audio/` are empty, and no muzzle flash, lock reticle or fuse marker exists to frame-step. The library emits the events they need (`PATTERN_VOLLEY_FIRED`, `PATTERN_LOCK_STARTED`, `PATTERN_LOCK_ENDED`, `PATTERN_FLAK_FUSE`, `PATTERN_FLAK_BURST` in `TickEventLog`), so VFX (25) and Audio (24) can be built against them. |
| AC-53 on REF-WEB / REF-PHONE | No reference machines measured. The desktop number is necessary, not sufficient. |

## Deviations from the GDD worth a designer's eye

1. **GDD OQ 11** — AC-53's benchmark rig asks for ~3,600 live bullets, over 2× F9's 1,700 error budget.
2. **GDD OQ 12** — AC-49's "spiral arm gap ≈133" is 150.5 for the shipped merged-arm spiral.
3. **GDD OQ 13** — AC-39's partial flak-ring skip is impossible: a ring spawns every bullet at its centre.
4. **Warp** — the 2100 patterns need the Bullet manager's Warp behaviour, which did not exist. It was implemented to bullet-manager F4 / Rule 17 (`BulletField.Beh.WARP`) with six new tests in `test_bullet_field.gd`, and ADR-0001 V1 was re-run after: p99 0.823 ms against the 1.5 ms threshold.
