# Report: Era shift and plane evolution (system 19)

## 1. File written
`design/gdd/era-shift-and-plane-evolution.md` (all 13 required headings, in order, 47 acceptance criteria, 12 open questions).

Summary: an era is one `EraDef` .tres (palette layer, role table, ladder position, kit and bomb skins, bolt-ons, bezel, music/sfx bank, bg set, asset sets, hp guidance). MVP builds 1941 and 1970s fully; 2030s and 2100 are validator-checked data stubs. The GDD defines the behaviour/option ladder, the strip map for native patterns, the era validator (E-V1 to E-V13), a 201-tick presentation transition inside the Tally exit hold (swap commit at tick 90, skip after 75, short mode 96, cap 240), staged loading (peak 74 MB), and the visual-only rule for plane evolution (table of what evolves and what never does).

## 2. Key decisions (auto-approve; change any of these)
- Plane evolution is **visual only** (all kit and bomb numbers hash-identical across eras). Reads concept §3 "power" as not applying; flagged for the creative director.
- One stage per era; stage n uses era n-1.
- Behaviour ladder: Straight → Accelerate → Curve → Warp. Option ladder: `flak_fuse` base (1941), `aim_lock` (1970s), `reaim_each_volley` (2030s, proposal), none (2100, proposal).
- 1941 is **Straight only** (resolves Pattern library V4 "some Curve" in favour of Boss budget Rule 18).
- Era shift owns the strip map; Director owns *when*. Default Accelerate strip speed is `V_EFF` (average speed, density parity) instead of "same initial speed" (which would raise concurrent bullets about 2.86x for the Jet rice). Switch: `strip_speed_mode`.
- Native emitters using a new tag must list it in `novelty_tags`; stripped version must be legal in the previous era; previews are never stripped.
- "Not a reskin" is a validator rule: every armed role's (family, behaviour, option) differs from the previous era, one signature role uses the era's tag, grammar differs.
- Transition timeline (ticks from `tally_exit`): Dim 0-44, Card in 45-52, Jump 53-112 (year ticker), Name 113-128, Reveal 129-200, release 201. Swap commit atomic at tick 90. Hold 201 of the 240 cap.
- Skippable by any counted slot after tick 75; short mode (release 96) and reduce-flashing variants; release waits for env load up to the cap, then loads synchronously under the card.
- Flash safety: all full-canvas brightness steps at most 10 %, one direction at a time, dim and fade-in at least 170 ticks apart; time-dust is 2+ px clusters (no needle-like lines).
- Staged memory: free old core at `stage_cleared`, free old env at tick 53, then load new env; peak 74 MB (early mode 110 MB, default off).
- `era_ready` latches before Tally Done; bezel swaps on a new `era_swap_committed` event (behind the card), `stage_started` as fallback.
- 1941 plane hardware is base art; first bolt-on set is 1970s (max 2 sprites per plane per era).
- Behaviour ladder data home moves to `EraDef` (Boss budget's `behaviour_ladder` knob reads it).

## 3. Amendments
(Full text in the GDD, Dependencies, "Amendments to other docs", items 1-17.) Highlights:
- `design/gdd/systems-index.md` row 19: status `**Designed** (pending review) — [GDD](era-shift-and-plane-evolution.md)`; Depends on `9, 11, 16` → `1, 3, 9, 10, 11, 12, 15, 16, 21`; progress tracker +1 GDD. Dependency note: Era shift pending ask in the "Pending asks" block is now fulfilled.
- `stage-end-tally.md` Rule 18 / Interactions: link; Dim phase runs inside the 45-tick fade; `from_era`/`to_era` are era ids; none on final stage.
- `wave-and-stage-director.md` Rule 25 and State table: `era_ready` emitted at transition release, before Tally Done; `load_stage` requires it. Dependencies row link; `StripMap`, `era_for_stage`.
- `enemy-and-ai.md` line 57 and Rule 3: "same initial speed" → `v_strip` (Era shift F4).
- `boss-power-budget.md`: `behaviour_ladder` knob data home → `EraDef`; add option ladder.
- `bullet-pattern-library.md` V4 1941 row: Behaviours `Straight` (drop "some Curve").
- `plane-kits-lancer-leech.md` Rule 41 / Open Question 14 closed (visual only); add drone sprites per era.
- `display-scaler-and-bezel.md` Rule 12: bezel swap trigger = `era_swap_committed`.
- `hud.md` Rule 33: tint set on `era_swap_committed`.
- `game-events-and-session.md`: events `era_swap_committed`, `era_ready`, `era_load_late`, `era_failed`; wait for `era_ready`.
- `localization.md`: no-grouping year formatter (`format_int` would print "1,941"); keys `era.name.*`, `era.card.skip`, `era.error.load`.
- `save-settings-high-scores.md`: register `access.era_transition_short`.
- `game-concept.md` §3 line 48: note "look and ability visuals only".
- `art-bible.md` 8.x and 5.5 notes (staged loading; 1941 hardware is base art).
- Registry: add candidates below; add `era-shift-and-plane-evolution` to `referenced_by` of `hit_radius_orb`, `hit_radius_rice`, `hit_radius_needle`, `hit_radius_ring`, `v_min`, `v_cap_global`, `setting_access_reduce_flashing`, `max_drones`.

## 4. Registry candidates
```yaml
  # --- Wave 3: Era shift (19) ---
  - name: era_ladder
    value: "behaviours Straight / Accelerate / Curve / Warp by era 0-3; options flak_fuse (base), aim_lock (era 1), reaim_each_volley (era 2), none (era 3)"
    unit: ladder
    note: "Era 2-3 options are Target-tier proposals. One new behaviour and at most one new option per era."
    source: design/gdd/era-shift-and-plane-evolution.md (Rules 8, 9)
    referenced_by: [era-shift-and-plane-evolution, boss-power-budget, enemy-and-ai, bullet-pattern-library]
  - name: era_transition_ticks
    value: "full 201, short 96 (release tick from the tally_exit tick); swap commit at 90"
    unit: ticks
    range: "short 60-120; full 150-240 (cap era_hold_max 240)"
    source: design/gdd/era-shift-and-plane-evolution.md (F1)
    referenced_by: [era-shift-and-plane-evolution, stage-end-tally]
  - name: era_luma_step_max_pct
    value: 10
    unit: percent of canvas relative luminance per full-canvas step
    range: "5-10"
    source: design/gdd/era-shift-and-plane-evolution.md (F5)
    referenced_by: [era-shift-and-plane-evolution]
  - name: era_vram_budget
    value: "always 18 MB, per-era core 20 MB + env 36 MB; staged peak 74 MB, early peak 110 MB"
    unit: MB
    range: "target 96, hard cap 128"
    source: design/gdd/era-shift-and-plane-evolution.md (F3)
    referenced_by: [era-shift-and-plane-evolution]
  - name: strip_speed_mode
    value: "V_EFF (v_strip = (speed + v_cap) / 2 for Accelerate; Warp warp_speed; Curve speed), clamped 70-480"
    unit: enum V_EFF / INITIAL
    source: design/gdd/era-shift-and-plane-evolution.md (F4)
    referenced_by: [era-shift-and-plane-evolution, enemy-and-ai, wave-and-stage-director]

formulas:
  - name: era_release_tick
    expression: "clamp(max(plan_end, env_ready_tick), 0, era_hold_max); plan_end full = reveal_start + old_hold + swap_ticks + new_hold = 201"
    variables: [reveal_start, old_hold, swap_ticks, new_hold, env_ready_tick, era_hold_max]
    output: "96-240 ticks"
    source: design/gdd/era-shift-and-plane-evolution.md (F1)
    referenced_by: [era-shift-and-plane-evolution, stage-end-tally]
  - name: strip_speed
    expression: "Accelerate: clamp(round((speed + v_cap) / 2), v_min, v_cap_global) [V_EFF]; Curve: speed; Warp: warp_speed"
    variables: [speed, v_cap, warp_speed, v_min, v_cap_global]
    output: "70-480 px/s"
    source: design/gdd/era-shift-and-plane-evolution.md (F4)
    referenced_by: [era-shift-and-plane-evolution, wave-and-stage-director, enemy-and-ai]
```

## 5. Conflicts
- **Pattern library V4** says 1941 behaviours "Straight, some Curve"; Boss power budget Rule 18 and concept §10 say stage 1 is Straight only. Resolved here for Straight only (Amendment 5).
- **Enemy line 57 / Director Rule 19 / Boss budget AC-26** say Accelerate is stripped to Straight "with the same initial speed"; this GDD defaults to the average speed (`V_EFF`) for density parity. Both modes are supported by `strip_speed_mode`.
- **Boss budget** puts `behaviour_ladder` in `budget_rules.tres`; the brief makes Era shift the owner. Data home moved to `EraDef`.
- **Wave director Rule 25** orders "Tally done → Era shift loads → `era_ready`"; the Tally hold needs the swap before Tally Done. Reordered (Amendment 2).
- **Display scaler Rule 12** swaps the bezel on `stage_started`; changed to `era_swap_committed` (behind the card).
- **Systems index** still lists Wave director (16) as "Not started" although the GDD exists (index fix is the main session's).
- No conflicts with locked registry values.

## 6. Open risks
- Threaded loading on the Web export (Godot 4.7) is unverified; the env load window is about 2.4 s. A late load blocks under the card and needs a rule that drops accumulated ticks (ADR).
- 2030s/2100 role stubs, option ladder for eras 3-4, lasers and shields (not bullets), and a groundless 2100 gunner are unresolved.
- Concept §3 "power" wording vs visual-only evolution needs creative-director sign-off.
- Art volume: 12 bolt-on sets and 8-16 drone sprites at Target; MVP is at most 4 bolt-on sprites and 4 drone sprites.
- Parallax (23) must honour the fade-in rule (9 steps of at most 10 %), or the brightness bound fails.
