# Spike result: ADR-0001 Validation Criterion V1 (bullet benchmark)

| Field | Value |
|-------|-------|
| **Date run** | 2026-11-03 |
| **ADR** | [adr-0001-gdscript-bullets-multimesh.md](adr-0001-gdscript-bullets-multimesh.md) |
| **Harness** | `tests/perf/bullet_bench.gd` (`godot --headless --script res://tests/perf/bullet_bench.gd`) |
| **Engine** | Godot 4.7.2.stable.official, GL Compatibility |
| **Machine** | Windows 11, desktop — **not** a reference machine |
| **Verdict** | **PASS on desktop.** ADR-0001 accepts on REF-WEB, which is unmeasured, so V1 is **not fully settled**. |

## Headline numbers

| Criterion | Budget | Measured (p99) | Verdict |
|---|---|---|---|
| Whole bullet update per tick @ 2000 bullets | ≤ 1.5 ms to accept (2.5 ms hard) | **0.749 ms** | PASS, ~2× headroom |
| MultiMesh buffer pack per render frame @ 2000 | ≤ 1.0 ms | **0.647 ms** | PASS |
| Determinism (same seed, 120 ticks) | identical `state_hash()` | identical | PASS |
| MultiMesh `TRANSFORM_2D` buffer layout | 16 floats/instance | **16, origin at [3] and [7]** | VERIFIED |

Tick detail at the cap: mean 0.683 ms, median 0.677 ms, p99 0.749 ms, max 0.953 ms,
over 600 measured ticks with the pool held saturated at 2000 and refilled outside
the timed region. Behaviour mix ~70% linear, 15% accelerate, 15% curve, against
4 hittable player slots.

## ADR-0001 verification items

1. **MultiMesh buffer layout in 4.7** — **VERIFIED.** 16 floats per instance for
   `TRANSFORM_2D` + `use_colors` + `use_custom_data`; a 2D transform's origin
   round-trips at buffer indices `[3]` and `[7]`. Note `MultiMesh.buffer` is
   **empty with no rendering device**, so this cannot be checked under
   `--headless`; the harness reports it as SKIPPED there rather than passing it.
   It was confirmed in a windowed run.
2. **GDScript tick cost on REF-WEB** — **NOT MEASURED.** This is the criterion the
   ADR actually accepts on. Desktop passing is necessary, not sufficient.
3. **First-use shader compile hitch on Web** — not measured.
4. **GDExtension `dlink` Web templates** — not needed unless V1 fails.

## The measurement that mattered

The first implementation was the straightforward one, and it **failed**:

```
mean 1.817 ms | median 1.814 ms | p99 1.916 ms | max 2.043 ms
verdict: CONCERN (p99 1.916 ms over 1.5 ms accept, under 2.5 ms hard)
```

On a desktop, over the accept threshold, with REF-WEB slower still. Two changes
took it to 0.749 ms (**2.6×**):

1. **Removed the previous-position arrays.** The swept test needs each bullet's
   prior position, which was stored in `_px`/`_py`. It is exactly
   `x - vx` once velocity has been updated for the tick, so the arrays were
   deleted: 2 writes and 2 reads per bullet per tick gone, plus
   2 × 2000 floats of memory.
2. **Broad-phased the hit loop.** It was 4 slots × 2000 bullets = 8000 swept
   tests per tick, the dominant cost, while players occupy a small region near
   the bottom of a 360×640 field. One AABB — built around the hittable slots and
   grown by the largest target radius, the bullet radius and the longest step any
   bullet took this tick — rejects almost every bullet in two compares. The pad
   is what keeps it exact: a bullet outside the grown box cannot have swept
   through a target.

**`state_hash()` is byte-identical before and after** (`-5848840803477005472`),
so the simulation produces exactly the same results — this is a pure speedup, not
a behaviour change. `tests/unit/test_bullet_field.gd` locks that in, including a
tunnelling regression test that fails if the derived previous position is wrong.

Decision 3 of the ADR also calls for processing bullets in **kind buckets** to
avoid a per-bullet branch. That was deliberately *not* implemented: with the
above two changes the budget is met with 2× headroom, so bucketing is an
optimisation to hold in reserve for REF-WEB rather than complexity to carry now.

## Consequences

- ADR-0001 stays **Accepted (provisional)** until REF-WEB is measured. The
  GDExtension fallback is not needed on this evidence.
- The bullet-manager and collision epics are unblocked for desktop work.
- **Next:** run this harness in a Web export on REF-WEB. If p99 there exceeds
  1.5 ms, apply kind bucketing and re-measure before considering ADR-0002.
- The harness is cheap to re-run and should be re-run whenever the bullet hot
  loop changes.
