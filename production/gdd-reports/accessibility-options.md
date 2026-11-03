# Report: Accessibility options (system 28), 2026-11-03

## 1. File written
`design/gdd/accessibility-options.md` (all 13 required headings, 37 core rules, 9 formulas F1-F9, 50 ACs, 15 open questions). It is the single data-driven registry of every `access.*` key (`data/accessibility/access_options.tres`), each with default, range, owner, class (PRESENTATION / INPUT_CONVENIENCE / TIMING_UI / ASSIST) and tier (MVP hook / VS / Target). It adds: a first-run photosensitivity prompt and Calm preset, a per-run `run.assisted` PRACTICE latch (unranked), a game-speed assist, a palette option with a CVD acceptance test, text-size steps, background dim / plain, hitbox ring and ally-shot options, a near-plane chain bar, one-handed presets, per-slot pad maps, timing options, and a sound-to-sight "visual twin" rule. Includes the coordinator's new keys (`access.effects_level`, `access.reduce_pulsing`, `audio.mono`) and the clank / ping decision.

## 2. Key decisions
- **One registry**; consumers only read via Save `get_setting` / `settings_changed`; each option has an apply mode (LIVE / EVENT / STAGE / RUN).
- **Bullets always win:** no option touches an enemy bullet. Rejected: thicker bullet outline (changes drawn size vs true hit radius), "bullet glow off" (bullets have no glow). Instead `access.background` FULL / DIMMED (65 %) / PLAIN gives contrast without touching bullets.
- **No screen-wide colour filter** (would alter locked bullet hues, Web cost). `access.player_palette` DEFAULT / LUMA_SPREAD (P2 `#FFF04A`, P4 `#FFB4EA`; luma gap 0.5 -> 30.9). Ring pattern + pips + "P{n}" are never switchable. Computed under protan/deutan/tritan simulation (CIE76): LUMA_SPREAD min dE 26.2 / 31.1 / 24.8. Debug-only CVD overlay.
- **HUD OQ9 resolved:** `play_top` stays 48 / 72; HUD scale 100/125/150 NOT adopted (field height locked, score comparability, strip is fixed-grid icons). Replaced by high-contrast HUD palette, optional near-plane chain bar, Pause status panel at the text step.
- **Text size** `access.text_size` 0-3: S/M tiers only, Latin cap 12/15/18/24, Bengali 17/21/25/33 (`max(ceil(cap*11/8), bn_size_s)`); L/XL identity at every step; Tally grid and HUD ignore it.
- **Reduce flashing** also replaces the 10 fps invulnerability blink (a 5 Hz hide) with steady 65 % opacity (closes Player plane OQ3). `reduce_pulsing`, `reduce_motion`, `effects_level` registered as VFX/HUD asked.
- **Game speed** 50-100 % in steps of 10 via an integer tick-skip accumulator on 60 Hz physics steps (exactly `speed` ticks per 100 steps; identical game ticks, so determinism holds). Presses latch across skipped steps. It is an ASSIST: `run.assisted` latches monotonic, run is PRACTICE, `submit_run` returns "not ranked", no NEW BEST, no name entry. Assists also defined for Target: `auto_bomb`, `deathbomb_grace` (need Collision `will_die` callback). No damage/lives/invincibility assists.
- **Sound-only cues:** visual twin for armour clank / immune ping = existing VFX `fx_clank` / `fx_ping`, promoted to **T1** so MINIMAL keeps them; Audio event table gets a `visual_twin` lint column; no caption strip (no HUD space; art bible forbids UI over the field). Other twins mapped (siren -> Warning banner, extend -> life stamp, etc.).
- **Audio:** no separate UI/Dialogue slider (Audio decided UI follows SFX; no dialogue); Master limiter covers loud peaks; `audio.mono` presented.
- **Input:** per-slot pad maps (`pad_s0..pad_s3`) at VS (Input OQ6); `input.move_stick` LEFT/RIGHT/EITHER proposed; one-handed presets (kb left hand, kb right hand, one-hand pad); auto-tap closed (Tap Assist + Fire toggle suffice, Kits OQ2); `nav_repeat`, `confirm_style`, `confirm_hold`, `untimed_menus`, `continue_timer` (STANDARD 600 / EXTENDED 1800 / UNTIMED).
- Rumble toggle `access.rumble` (Target); chain cues (audio, rumble) VS.
- Menus builds basic remap list (MVP); Accessibility owns polish (Menus OQ8). Closed also: Powerups OQ9 (no item pulse), Wave director OQ10 (no label on segments), Menus OQ9 (`untimed_menus`).
- First-run photosensitivity prompt + Calm preset (reduce_flashing, reduce_pulsing, reduce_motion, effects REDUCED).

## 3. Amendments (exact edits)
1. `design/gdd/systems-index.md` row 28: `| 28 | Accessibility options | Po | Vertical Slice | 1 (soft), 2, 4, 20, 21, 22, 24, 25, 26, 27 | **Designed** (pending review) — [GDD](accessibility-options.md) |`. Progress tracker: GDDs written +1 (accessibility-options). Dependency notes: add "Accessibility (28) reads Input (2), Display (4), HUD (20), Tally (21), Menus (22), Audio (24), VFX (25), Save (26), Localization (27) and owns `run.assisted`".
2. `save-settings-high-scores.md` line ~110-111: replace the two `access.*` rows with the keys: `access.reduce_flashing` bool false; `access.reduce_pulsing` bool false; `access.reduce_motion` bool false; `access.effects_level` enum FULL/REDUCED/MINIMAL FULL; `access.background` FULL/DIMMED/PLAIN FULL; `access.hitbox_ring_opacity` int 40/60/80/100 (100); `access.hitbox_ring_size` NORMAL/LARGE; `access.ally_shot_dim` 0/25/50 (0); `access.player_palette` DEFAULT/LUMA_SPREAD; `access.hud_contrast` STANDARD/HIGH; `access.chain_bar_near_plane` bool false; `access.text_size` int 0-3 (0); `access.confirm_style` HOLD/DOUBLE_TAP (HOLD); `access.confirm_hold` SHORT/NORMAL/LONG (NORMAL); `access.nav_repeat` FAST/NORMAL/SLOW (NORMAL); `access.untimed_menus` bool false; `access.continue_timer` STANDARD/EXTENDED/UNTIMED; `access.tally_auto_advance` bool true; `access.game_speed_pct` int 50-100 step 10 (100); `access.auto_bomb` bool false; `access.deathbomb_grace` 0/3/6 (0); `access.chain_cue_audio` bool false; `access.chain_cue_rumble` bool false; `access.rumble` OFF/LOW/NORMAL (NORMAL); `access.first_run_prompt_done` bool false; `audio.mono` bool false; `input.move_stick` LEFT/RIGHT/EITHER (LEFT). Rule 18: add optional classes `pad_s0`..`pad_s3` (per-slot pad overrides, override the shared `pad` for that slot). Rule 31 area: assisted runs return "not ranked".
3. `hud.md`: Rule 34 + OQ9 -> "HUD scale not adopted; `play_top` stays 48/72 (Accessibility 28 Rule 20)"; Rule 33: theme choice via `access.hud_contrast` (STANDARD/HIGH) and `access.player_palette`; add `assist_tag` 12x12 element in each HudLayout (lint exempt); add optional near-plane chain bar (layer 7); continue prompt reads `access.continue_timer`; list Accessibility (28) as GDD present.
4. `display-scaler-and-bezel.md` lines ~114, ~117, ~349: replace HUD scale text with "no HUD scale; `play_top` unchanged by accessibility options".
5. `art-bible.md` 7.9: replace HUD scale bullet; add reduce motion, background dim/plain, assist = PRACTICE; note "screen-shake" = boss-sprite local shake.
6. `localization.md`: OQ8 closed with Accessibility F1 table (S/M 12/15/18/24 Latin, 17/21/25/33 Bengali; L, XL identity); Accessibility row no longer provisional.
7. `menus-title-plane-select.md`: OQ8/OQ9 closed; add `access.confirm_hold`; Pause status panel at text step; PRACTICE tag on Pause and Results; first-run prompt after Web gate; Settings rows generated from `AccessOptionDef`.
8. `input-and-player-mapping.md`: Rule 35 and Save Rule 18 per-slot pad maps; Rule 23 reads `access.nav_repeat` (12/4, 18/6, 30/10); add `input.move_stick`; Rule 24 sampler latches presses on physics steps without a game tick; OQ6, OQ10 closed.
9. `game-events-and-session.md`: add `run.assisted` latch, game-speed gate (F2), `access.continue_timer` override of `continue_seconds`, assisted -> `submit_run` "not ranked", `one_credit_clear` false.
10. `player-plane.md`: OQ3 closed (steady 65 % opacity under reduce flashing); ring size/opacity per V6.
11. `bullet-manager.md` V3: add `access.ally_shot_dim` (Accessibility F3).
12. `stage-end-tally.md`: no NEW BEST for assisted runs.
13. `vfx-and-screen-feedback.md`: `fx_clank`, `fx_ping` to tier T1; OQ7 closed (REDUCED removes local shake; no separate toggle).
14. `audio.md`: `visual_twin` column in event table (entries per Accessibility Rule 30); register `audio.mono`; chain tick sound for `access.chain_cue_audio`.
15. `plane-kits-lancer-leech.md` OQ2 closed. 16. `bombs.md` OQ2/OQ3 -> Accessibility Rule 25 (Target). 17. `powerups-and-drops.md` OQ9 and `wave-and-stage-director.md` OQ10 closed. 18. `critical-break.md` OQ8 -> `access.rumble`; Accessibility row "GDD yes". 19. `coop-and-team-chain.md`: assisted co-op runs unranked. 20. Collision (6) when amended: `will_die(slot)` callback (Target). 21. Parallax (23) when written: `set_background_mode(FULL/DIMMED/PLAIN)`, `set_scroll_scale(pct)`.

## 4. Registry candidates
```yaml
constants:
  - name: text_size_steps
    value: "mult 100/125/150/200 percent; S/M Latin cap 12/15/18/24; Bengali 17/21/25/33 at bn_size_s 17; L and XL identity"
    unit: percent / px
    range: "steps 0-3"
    source: design/gdd/accessibility-options.md (F1)
    referenced_by: [accessibility-options, localization, menus-title-plane-select, hud]
  - name: game_speed_steps
    value: "50-100 percent in steps of 10, default 100; ASSIST (marks run PRACTICE)"
    unit: percent of 60 Hz ticks
    range: "50-100"
    source: design/gdd/accessibility-options.md (F2)
    referenced_by: [accessibility-options, game-events-and-session, input-and-player-mapping]
  - name: bg_dim_pct
    value: 65
    unit: percent (environment layers only)
    range: "40-90"
    source: design/gdd/accessibility-options.md (F4)
    referenced_by: [accessibility-options]
  - name: ally_shot_dim_floor
    value: "dim 0/25/50; op_floor 25"
    unit: percent
    source: design/gdd/accessibility-options.md (F3)
    referenced_by: [accessibility-options, bullet-manager]
  - name: continue_timer_ticks
    value: "STANDARD 600, EXTENDED 1800, UNTIMED"
    unit: game ticks (accessibility override of continue_seconds, outside its 5-15 s range by design)
    source: design/gdd/accessibility-options.md (F9)
    referenced_by: [accessibility-options, game-events-and-session]
  - name: hitbox_ring_sizes
    value: "22 px NORMAL, 30 px LARGE (P4 inner/outer 30/32)"
    unit: px
    source: design/gdd/accessibility-options.md (F7)
    referenced_by: [accessibility-options, player-plane]
formulas:
  - name: assist_tick_gate
    expression: "acc' = acc + speed_pct; run = acc' >= 100; acc'' = acc' - 100 if run else acc'"
    variables: [acc, speed_pct]
    output: "exactly speed_pct game ticks per 100 physics steps"
    source: design/gdd/accessibility-options.md (F2)
    referenced_by: [accessibility-options, game-events-and-session]
  - name: ally_shot_opacity
    expression: "max(25, (base(N) * (100 - dim) + 50) div 100); base 100/75/50"
    variables: [base, dim, N]
    output: "25-100"
    source: design/gdd/accessibility-options.md (F3)
    referenced_by: [accessibility-options, bullet-manager]
  - name: palette_acceptance
    expression: "luma gap >= 25 AND dE76 >= 20 under protan/deutan/tritan (Machado 2009, severity 1.0) AND dE >= 20 vs each bullet fill"
    variables: [luma, dE, M]
    output: "pass/fail"
    source: design/gdd/accessibility-options.md (F5)
    referenced_by: [accessibility-options]
```
Existing entry to extend: `setting_access_reduce_flashing` referenced_by += `accessibility-options, vfx-and-screen-feedback, hud, critical-break, stage-end-tally`.

## 5. Conflicts
- HUD OQ9 (HUD scale 100/125/150, would change `play_top`) vs registry-locked `play_top` 48/72: resolved by not adopting HUD scale (needs HUD, Display, art bible edits above).
- VFX MINIMAL (T0-T1 only) would remove the clank / ping, the only visual twin of sound-only cues: needs VFX to promote both to T1.
- Audio decided UI bus follows SFX; the brief asked for separate UI/Dialogue sliders: kept Audio's decision.
- Save `display.bezel` (auto/off) vs Display `bezel_style` (Art/Plain): name/value mismatch (OQ15).
- Input Rule 34 (pad movement not remappable) vs one-handed needs: proposed `input.move_stick` as an Input amendment, not a change to movement remapping.
- Registry `continue_seconds` range 5-15 vs accessibility EXTENDED (30 s) / UNTIMED: treated as an override, not a change to the locked 10.
- `systems-index.md` says HUD (20) has "no GDD" but `hud.md` exists (index lag).
- Player plane's 10 fps hide blink exceeds 3 flashes/s (5 Hz); allowed as a small-area exception, but gets the reduce-flashing replacement.

## 6. Open risks
- CVD matrix coefficients and dE numbers computed from remembered Machado 2009 values (CIE76); verify before relying (OQ3). P4 vs Needle dE 22.4 under protan is narrow (OQ2).
- Game-speed scheduler and input latching touch Session and Input; needs an ADR and a spike; music/audio behaviour at < 100 % unverified.
- Mono downmix in Godot 4.7 unverified (Audio OQ3).
- Parallax (23) has no GDD; background and reduce-motion contracts are provisional.
- Steady 65 % invulnerability look may read poorly (OQ4); near-plane chain bar clutter in 4P (OQ6).
- Bengali strings for ~40 `opt.*` keys plus conjunct tests at text steps 0-3 not yet done.
- Per-slot pad maps add Save/Input schema work at VS.
- No hardware testing yet (Adaptive Controller, one-hand grips).
