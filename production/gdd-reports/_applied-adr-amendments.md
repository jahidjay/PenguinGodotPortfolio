# Applied amendments — ADR-0002..0009 consistency (2026-11-03)

Technical-director pass (auto-approved). Every edit used scripted exact-string replacement with `assert count == 1`; all are dated notes or in-place rewrites citing the ADR. Locked values unchanged. Code not touched.

## Pass 1 — ADR-0006..0009 follow-ups

| File | Amendment | Status |
|---|---|---|
| `online-leaderboards-boss-rush.md` | Rule 22: byte layout (bit 7 fire pulse) + touch `drag` (int16 x/y, 1/16 px), `drag_active`, `fire_auto` recorded per tick; Touch (31) row same | applied (ADR-0003/0008) |
| same | Rule 5: bearer install token, `POST /v1/installs`; Rule 6 note: token per adapter, GodotSteam identity/ticket/friends only, no client Steam mirror | applied (ADR-0007) |
| same | OQ8 closed (no client mirror); OQ13 → ADR-0007 V1 | applied |
| `input-and-player-mapping.md` | Rule 13a: bit 7 + touch fields recorded | applied |
| `display-scaler-and-bezel.md` | Rule 1: game SubViewport `UPDATE_ALWAYS` | applied (ADR-0004/0006) |
| `touch-controls.md` | Rule 29: `emulate_mouse_from_touch = false`, `TouchRouter` single pointer stream, Web shell `touch-action: none` + no overscroll | applied (ADR-0008) |
| `critical-break.md` | OQ9 closed → ADR-0006; ~7 ms flash at 144 Hz noted | applied |
| `vfx-and-screen-feedback.md` | Rule 5 points to ADR-0006, 144 Hz note | applied |
| `localization.md` | Rule 24 + OQ1 point to ADR-0009; boot fallback (no shaping → English words, digits unaffected) | applied |

## Pass 2 — ADR-0002..0005 recommendations

| File | Amendment | Status |
|---|---|---|
| `enemy-and-ai.md` | Pattern-library Interactions row: stable-id seeds, `owner_id = event_id × 16 + member_index` | applied |
| same | AC-12 rewritten (seeds independent of spawn order / refused spawns); AC-46 last sentence (same seeds in any order) | applied |
| same | SINE and FOLLOW_FORMATION rows: `SimMath` trig/atan2, 1/16 px rounding | applied |
| `bullet-pattern-library.md` | Enemy/Boss row: `owner_id` definition; F-aim note: all angles via `SimMath` binary angle units, radians converted at load, tests ±1 unit | applied |
| `boss-and-boss-parts.md` | F1: `SimMath` sin/cos, 1/16 px (AC-44 unchanged) | applied |
| `powerups-and-drops.md` | Bob `sin` via `SimMath`, item positions 1/16 px | applied |
| `plane-kits-sentry-breaker.md` | Tracking formula: `SimMath`, 1/16 px | applied |
| `bullet-manager.md` | F2 Accelerate: per-tick multiply only, no `exp/pow/ln`; ticks-to-cap is analysis | applied (already a multiply; note added) |
| `input-and-player-mapping.md` | Rule 15: 8-way direction chosen in Input (PF2 device side); Rule 17: buffer, `consume`, `clear_buffer` owned by sim-side `SimInputDecoder` | applied |
| `player-plane.md` | PF2 note: evaluated in Input; plane reads `DIR[k]` only | applied |
| `game-events-and-session.md` | Rule 3: `run_time` = `run_ticks`; timers count game ticks | applied |
| `era-shift-and-plane-evolution.md` | Rule 30: ticked at GameLoop step 8f; Rule 16: era 0 pre-loaded by `start_run` | applied |
| `stage-end-tally.md` | Rule 15: skip edge read from recorded sim input (Fire bit) | applied |
| `accessibility-options.md` | Rule 6: `continue_timer`, `tally_auto_advance`, `era_transition_short` are sim-relevant timing settings, recorded in the replay header | applied |

## Not changed / follow-ups
- Examples with trig results (Enemy, Boss, Pattern) keep their ideal values; tests allow ±1 binary angle unit or ±0.05 px (stated in the notes).
- Input Rule 18's text still describes `clear_buffer` calls by the Player plane; the call target is now the decoder (covered by the Rule 17 owner note).
- Programmer tasks: `src/sim/` (`SimMath`, trig table + generator, `SimHash`, `SimRng`, `SimInputDecoder`), lint for banned calls (ADR-0003).
