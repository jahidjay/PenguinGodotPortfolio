# Spike result: pattern library performance (AC-53, AC-54, AC-55)

| Field | Value |
|-------|-------|
| **Date run** | 2026-11-04 |
| **GDD** | [bullet-pattern-library.md](../../design/gdd/bullet-pattern-library.md) AC-53 – AC-55 |
| **ADR** | [adr-0001-gdscript-bullets-multimesh.md](adr-0001-gdscript-bullets-multimesh.md) (budget row, step 4) |
| **Harness** | `tests/perf/pattern_bench.gd` (`godot --headless --script res://tests/perf/pattern_bench.gd`) |
| **Engine** | Godot 4.7.2.stable.official, GL Compatibility |
| **Machine** | Windows 11 desktop, RTX 3070 — **not** a reference machine |
| **Verdict** | **PASS on shippable content; FAIL on AC-53's rig as written.** The two differ by ~2×, and the difference is in the rig, not the code (below). REF-WEB unmeasured. |

## Headline numbers

| Criterion | Budget | Measured | Verdict |
|---|---|---|---|
| AC-53 pattern tick — **AC's rig**: 40 emitters / 120 runners, all armed on tick 0 | ≤ 0.2 ms p99, mean ≤ 0.1 ms | p99 **0.527 ms**, mean **0.100 ms** | FAIL (p99) |
| AC-53 pattern tick — **at F9's scene budget**: 55 runners summing to 1,700 bullets, staggered arming | ≤ 0.2 ms p99, mean ≤ 0.1 ms | p99 **0.115 ms**, mean **0.054 ms** | PASS |
| AC-54 pattern tick + bullet update, pool near the 2,000 cap | ≤ 1.7 ms p99 | p99 **1.292 ms** | PASS |
| AC-55 allocation, 6,000 ticks / 24,538 volleys after warm-up | < 1 MiB static growth, objects ±5 | **−1.4 KiB, +0 objects** | PASS |

## The finding: AC-53's rig asks for content F9 forbids

AC-53 specifies "40 emitters and 120 runners covering all 7 patterns, with an
intensity ramp". Filled with the authored patterns, that rig sustains roughly
**3,600 live bullets** by F9's own formula — more than **twice** the 1,700-bullet
scene budget F9 sets as an **error**, and ~1.8× the Bullet manager's 2,000-bullet
pool. The combined run confirms it from the other side: **1,533 spawn requests
were refused** because the pool was full, and the peak was 176 requests in one
tick.

The rig also arms every emitter on the same tick with identical `start_delay`s,
so all 120 runners fire **in phase**. Enemy (10) Rule 18 arms an enemy's emitter
when its muzzle enters the fire zone, and boss parts have their own
`start_delay`s, so in the game the volleys are spread across ticks. The p99 of
the AC rig is therefore the cost of *every gun in an over-budget scene firing on
the same tick*.

Rig [1b] measures the same code on content that passes the design's own gates:
emitters added until F9's 1,700-bullet budget is reached, each armed on its own
tick. That is **p99 0.115 ms — inside the 0.2 ms budget with ~1.7× headroom**.

**This needs a designer/TD decision, not a code change** (tracked as GDD Open
Question 11): either AC-53's rig is restated to the F9 budget, or the budget row
is raised for an over-dense rig that the Director's `StageValidator` (V-D5)
would reject anyway.

## What the optimisation pass changed

First measurement of the rig was **p99 0.706 ms, mean 0.158 ms**. Three changes
took it to **p99 0.527 ms, mean 0.100 ms** (1.6× on the mean), with no change to
behaviour — all 14 test suites, including the pattern determinism and state-hash
suites, pass identically before and after:

1. **Spawn safety reads a flat Active list.** `PatternScene.set_slots` now
   compacts the Active players into `active_x` / `active_y` / `active_count`
   once per tick. The safety check runs *per bullet per player*, and it was
   calling `is_active()`, `slot_x()` and `slot_y()` through the scene — up to
   12 method calls per bullet. It now indexes two packed arrays.
2. **The volley latches its snapshot.** `_fire_volley` caches the active list
   and the bullet field on the runner, so a 24-bullet ring does not re-read
   them 24 times. The flak burst latches its own snapshot at burst time, which
   is also what the GDD requires (spawn safety is checked on the burst tick,
   against the players as they are then).
3. **Per-tick calls guarded at the call site.** `_service_fuses` and
   `_maybe_begin_lock` were called for all 120 runners every tick only to
   early-return. With the guards at the call site, a tick with no fuses and no
   locks makes 240 fewer calls. This is what moved the median from 0.065 ms to
   0.042 ms.

One formula is now deliberately duplicated: the F3 gate test is inline in
`PatternRunner.tick` as well as in `PatternMetrics.gate_open`, because it runs
for every runner on every tick. `test_pattern_gate_agrees_with_the_validator`
sweeps 201 intensities across 5 gate ranges and fails if the two copies ever
disagree, which is the GDD's actual requirement ("the runner and the fairness
validator must agree").

## Not measured

1. **REF-WEB** — the platform AC-53 and ADR-0001 actually accept on. A desktop
   pass is necessary, not sufficient.
2. **REF-PHONE** — report-only in the AC, not run.
3. **AC-55's full ten minutes** — the 6,000-tick short form is what ran. The
   soak is `godot --headless --script res://tests/perf/pattern_bench.gd -- --soak`
   (36,000 ticks).
4. **AC-43** (the same scenario through GameLoop at 30 / 60 / 144 fps plus a
   stall) — needs the integration harness, not this bench.

## Side effect on ADR-0001 V1

`BulletField` gained the Warp behaviour (bullet-manager F4) in the same session,
which adds a branch to the move loop. Re-running `tests/perf/bullet_bench.gd`:
**p99 0.823 ms** against the 1.5 ms accept threshold (was 0.749 ms before Warp,
measured on the same machine), MultiMesh pack p99 0.503 ms against 1.0 ms. V1
still passes with ~1.8× headroom.
