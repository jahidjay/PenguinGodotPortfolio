# Applied amendments — wave 2 (2026-11-03)

Applier pass over five reports in `production/gdd-reports/`: `plane-kits-lancer-leech.md`, `boss-and-boss-parts.md`, `powerups-and-drops.md`, `bombs.md` (full wording in `design/gdd/bombs.md` › Dependencies › Amendments 1–14), `boss-power-budget.md`. Status words: **applied**, **adapted** (with a reason), **skipped** (with a reason). Paths are relative to the project root. Work was split by target file: main pass (systems index, the five new GDDs, art bible, ADR), Group A (collision, bullet manager, chain), Group B (session, scoring, player plane, input), Group C (enemy, pattern library, co-op, localization, game concept), Group D (registry). `design/gdd/critical-break.md` and `design/gdd/wave-and-stage-director.md` were not touched.

## Cross-cutting (resolution rules)

| Item | Status | Notes |
|---|---|---|
| Owners win (rule 1) | applied | No owner conflict between reports. Boss report §4 still quotes ref_dps 300 / old hp; superseded by the balance reconcile (Plane kits owns `ref_dps` 800). |
| Powerups F9 leftover (rule 2) | applied | `design/gdd/powerups-and-drops.md` F9: 330,000 / 19,712,700 = **1.7 %** (1.674 %); 60,000 / 2,987,250 = **2.0 %** (2.009 %). Rule 14(d) "about 1 % of an expert stage" → "about 0.6 % (three such bombs about 1.7 %)" (110,000 / 19,712,700 = 0.558 %). No AC hard-codes the percentages (AC-41 checks 110,000 / 20,000 only). |
| Bombs farm share (rule 2) | verified | `design/gdd/bombs.md` B9 already cites 1.7 % of 19.7M and 11 % of 2.99M. |
| Scoring F7 re-baseline (Plane kits 7, Powerups 4c medals) | skipped (verified) | Already done by `_balance-reconcile-1.md`; medals 3/4/4 and the hit re-baseline are present in `design/gdd/scoring.md`. |
| Code / project files (rule 7) | skipped | Programmer tasks below. |

## systems-index.md (`design/gdd/systems-index.md`) — main pass

| Source | Amendment | Status |
|---|---|---|
| Plane kits 1 | Row 11 → Depends `1, 3, 5, 6, 7`; Designed + GDD link, "bottleneck, high risk"; 11↔13 cycle note added under Dependency notes | applied |
| Bombs 1 | Row 12 → Depends `1, 2, 3, 5, 6, 7`; Designed; "Bomb design per plane" removed from Open items (closing note added) | applied |
| Powerups 1 | Row 13 → Depends `1, 3, 5, 6, 7, 8, 10, 18`; Designed | applied. Decisions bullet "Powerups (dropped by small enemies)" got a dated note: carriers only, gems from cancels. |
| Boss 1 | Row 14 → Depends `3, 6, 7, 8, 9, 10, 18`; Designed; removed from "Code exists without GDD" (now 2: 17, 20 partly) | applied |
| Budget 1 | Row 15 → Depends `9, 10, 14`; Designed; Decisions bullet 1 "(Detail in boss-power-budget.md.)" | applied |
| Tracker | GDDs written recounted from files: **18** (20 files minus game-concept and systems-index; none has "[To be designed]") | applied |
| Pending asks | New Dependency-notes bullet listing asks for Wave director (16), Critical Break (17), Era shift (19) and which systems must list Bombs | applied (see "For the next pass") |

## Five new GDDs (cross-links and closed questions) — main pass

| File | Source | Amendment | Status |
|---|---|---|---|
| `design/gdd/plane-kits-lancer-leech.md` | Bombs 8 | Open Q7 closed (Bombs read no kit state; Rule 40 stays for CB); Interactions + Dependencies Bombs rows rewritten (Dependencies Hard → Soft, no snapshot) | applied |
| same | Powerups 9 | Edge case "powerup at 4 drones": skipped if a partner needs it, else pays a MEDAL | applied |
| same | bookkeeping | "— no GDD" on Powerups / Boss / Bombs / Budget rows → GDD links | adapted (not in reports; keeps Dependencies bidirectional) |
| `design/gdd/boss-and-boss-parts.md` | Budget 3a | Open Q8 closed | applied |
| same | Budget 3b | Rule 2 `tags[]` convention `mech:<mechanic_id>` | applied |
| same | Budget 3c, 3d, 3f | Jet core `core_lock_fan`; Fortress `core_rage_ring` as variant of `m2_engine_ring` | adapted: Boss GDD has no "F9 pattern table" (its F9 is cancel/entrance), so a dated "Pattern bindings" paragraph was added after the F10 migration table |
| same | Budget 3e | Budget (15) rows point to the GDD; lint requires `data/boss_budget/<id>.tres` | applied |
| same | bookkeeping | Bombs/Powerups rows linked; Open Q10 closed (`bomb_part_pct` 60, cap 1,000, bomb hits never count — Bombs); phase guard ≥ 4,000 hp noted on the Bombs row | adapted (answer from Bombs GDD) |
| `design/gdd/powerups-and-drops.md` | rule 2 | F9 + Rule 14(d) recomputed | applied |
| same | bookkeeping | Boss row linked (`boss_defeated(reason, killer_slot)`); provisional note narrowed to 16/20/24/25; Open Q6 closed (bosses drop nothing; Boss Rule 24) | adapted |
| `design/gdd/bombs.md` | bookkeeping | Powerups / Boss rows linked; Open Q5 closed (Powerups Rules 12–14 confirm gems, cap per request, `items = false`) | adapted |
| `design/gdd/boss-power-budget.md` | — | No amendment targets it; Boss row already says "GDD" | no change |

## Art bible (`design/art/art-bible.md`), additive dated notes — main pass

Notes were inserted at the end of each section (just before the next heading).

| Source | Section | Status |
|---|---|---|
| Plane kits 8 | §5.6 Lancer lens-pod, 40 % meter notch, nose glow / 2x2 afterglow, no blink for the laser; §8.3 beam sets 14 px / 6 px, Leech tether | applied |
| Boss 10 | §5.8 no part-kill flash, no per-part hp bars; §6.8 part explosion 28–36 px, death-sequence cap 40 particles; §7.4 enrage/timeout and part-kill caption in the boss row | applied |
| Powerups 10 | §4.6 `+` diamond reserved for CHAIN, GEM plain 7 px diamond; §5.7 item sizes 7/15/15/17/17, layer 6 | applied |
| Bombs 10 | §7.4 banner rule (CB cancels before the banner; Bombs clears only on the press tick); §8.3 sprites 56x16 column, 12x12 hook, 48x48 burst, ring; §4.6 Tracer Orange `#FF8A1F`; §7.2 icon dims to 60 % while busy | applied |

## ADR-0001 (`docs/architecture/adr-0001-gdscript-bullets-multimesh.md`) — main pass

| Source | Status |
|---|---|
| Boss 11: steps 3c `BossController.tick()`, 6c `BossController.apply_results()` | applied |
| Powerups Rule 23 tick order | adapted: step 7b `Powerups.tick()` (after Collision and the cancels, before Chain/Scoring). The report gave the order but no step number. Bombs is already in step 3 ("Kits / Bombs"). |
| Budget rows (from the GDD perf ACs): kits ≤ 0.25 ms (Kits AC-41), bombs ≤ 0.10 ms (Bombs AC-51), boss ≤ 0.05 ms (Boss AC-50), powerups ≤ 0.15 ms tick / ≤ 0.10 ms pack (Powerups AC-46/47) | applied (dated). Status unchanged (Proposed). |

## Registry (`design/registry/entities.yaml`) — Group D

| Source | Entries | Status |
|---|---|---|
| Plane kits | 8 constants (`charge_hold_ticks`, `shot_linger_ticks`, `player_shot_damage`, `lancer_ability_speed`, `laser_meter`, `laser_damage`, `drone_ability_cycle`, `kit_max_hits_per_s`); formulas `laser_invuln_duty`, `drone_phase`; referenced_by += plane-kits on 10 entries | applied |
| Boss | 10 constants (`part_cancel_radius`, `last_part_cancel_radius`, `core_armor_pct`, `critical_pct`, `critical_window_ticks`, `critical_armor_pct`, `boss_hurtbox_budget`, `boss_intro_ticks`, `enrage_mult`, `boss_timeout_after_enrage`); formulas `boss_core_split`, `boss_intensity`, `boss_fight_budget`; referenced_by += boss on 13 entries; `kill_values` note "part is paid by Collision's kill_credit(slot, PART)" | applied |
| Boss `ref_uptime_pct`, `ref_dps` | already existed (70, 800) | adapted: merged referenced_by; `boss_fight_budget` output uses ref_dps 800 (2,703 / 3,285 ticks) |
| Powerups | 5 constants (`items_per_cancel_cap` new, `pickup_radius`, `chain_pickup_amount`, `pod_pity_limit`, `item_pools`); formulas `cancel_item_sample`, `pod_income`; referenced_by += powerups on 6 entries | applied |
| Bombs | 9 constants (`bomb_start`, `bomb_max`, `bomb_stage_floor`, `bomb_invuln`, `bomb_lockout`, `bomb_chain_toll_pct`, `bomb_target_cap`, `bomb_part_pct`, `bomb_damage`); formulas `bomb_chain_toll`, `lancer_bomb_effect_ticks`, `bomb_target_cap_rule`; referenced_by += bombs on 6 entries | applied |
| Boss power budget | 4 constants (`boss_budget_cap`, `preview_wave_frac`, `preview_transform_rows`, `mechanics_per_boss`); formulas `power_score`, `preview_transform`; referenced_by += budget on 5 entries | applied |

103 → 151 entries. Validated by script: no duplicate names; each entry has name + value/expression, source, referenced_by; constants before `formulas:`; no locked value changed.

## Group A (collision, bullet manager, chain)

### design/gdd/collision-damage-lives.md
| Source | Amendment | Status |
|---|---|---|
| Plane kits 3 | `tag` in hit results; Open Q3 closed (laser 60/3 ticks, parked 40, latch 20, shot 20; duty 20.5–22.3 %, limit 25 %); new Rule 8a `blink_remaining(slot)`; AC-33 unblocked; kits rows linked | applied |
| Boss 4 | Boss rows: `kill_class`, `on_boss`, `lethal`, core republished under same id/generation, published record authoritative; body radius "up to 26 px"; Open Q2 closed; `armor_mult` → `core_armor_pct` / `armor_pct` (Rule 11, C4, AC-33) | applied |
| Boss 4 | Open Q9 closed for bosses | adapted: Q9 also covers `combat_rules.gd`; closed for bosses only |
| Bombs 3a–3f | `counts_chain` in Rule 10 / C5; Rule 13 "Bomb damage never counts for the chain"; Open Q4 closed; `blink_remaining` includes bombs; AC-33 unblocked; BOMB hit results carry target class | applied (immune-bomb edge case reworded to match) |

### design/gdd/bullet-manager.md
| Source | Amendment | Status |
|---|---|---|
| Plane kits 2 | per-bullet `tag` (Rule 2, Rule 11); queries `first_in_column`, `nearest`; ≤ 48 live/slot; Open Q5 closed | applied |
| Boss 7 | cancel requesters: part 90 px, last part 150 px, death whole screen, TIMEOUT = Rule 15a clear without items | applied |
| Powerups 3 | Open Q6 closed; hand-off in pool-index order plus count, Powerups samples | applied; F9 example "1,350 items" adapted to "1,350 positions → 97 gems (Powerups F3)" |
| Bombs 4a–4d | rectangle area (Rule 13, F9 + example); `items` flag / CANCEL_NOITEM; Bombs rows; AC-33a (rectangle) + AC-33b (no-item) | applied (suffix numbering avoids renumbering) |

### design/gdd/chain-tracker.md
| Source | Amendment | Status |
|---|---|---|
| Boss 2 | Rule 8 `boss_started` note; Rule 10 `boss_defeated(reason, killer_slot)`, freeze for every reason; AC-53 (TIMEOUT record) | applied |
| Powerups 6 | `add_bonus(slot, 10, "chain_pickup")`, refills the window, not a hit | applied |
| Bombs 2 | Rule 15 `apply_bomb_toll`; event `chain_reduced`; Interactions/Dependencies rows; milestone edge case; AC-52 (187 → 94) | applied |

## Group B (session, scoring, player plane, input)

### design/gdd/game-events-and-session.md
| Source | Amendment | Status |
|---|---|---|
| Plane kits 5 | Open Q3 closed: drones snap home at `stage_cleared`; cooldown 0 on death and clear; `drone_count` carries | applied (Rule 9 and two edge cases) |
| Boss 9 | boss events + `boss_defeated(reason, killer_slot)` (KILLED / CRITICAL_BREAK / TIMEOUT); Boss (14) in Dependencies | applied as a dated note on the Rule 13 signal list; TIMEOUT uses the normal clear flow |
| Powerups 5a–5c | `add_powerup`, `add_oneup`; Open Q4 closed; F1 `powerups_collected` 0–4 | applied |
| Bombs 5 | `bombs` field (0–5) via `set_bombs`; resets; Rule 9 carry-over + floor top-up; `bomb_used(slot)` | applied |
| Budget 8 | optional `mechanic_previewed(boss_id, mechanic_id, wave)` | applied |
| main pass | stale "none of these systems has a GDD yet" | adapted (dated note) |

### design/gdd/scoring.md
| Source | Amendment | Status |
|---|---|---|
| Boss 3 | S4 only if `reason != TIMEOUT` (S table, edge case, AC-15); `boss_cap_hold_allowed()` in F6 + AC-39; Open Q4 closed; Boss rows → GDD | applied |
| Powerups 4a, 4b, 4d | `item_collected(slot, kind, count)`; Q3 and Q6 closed; cap 100 is a fact | applied |
| Powerups 4c / Plane kits 7 | F7 re-baseline | skipped (verified present) |
| Bombs 13 | Q3 note: bomb items are capped gems; area cancels none | applied |
| main pass | heading "Inputs from undesigned systems" → "Inputs from other systems (… — GDD rows are confirmed)" | adapted |

### design/gdd/player-plane.md
| Source | Amendment | Status |
|---|---|---|
| Plane kits 4a–4e | Open Q4 closed (Lancer 90, Leech none); V7 blinks only on `blink_remaining > 0`, never the laser; Rule 9 kit counts held ticks; Rule 4 focus while Fire physically down, not during linger; `stage_cleared` to kit | applied |
| Bombs 7 | Rule 9 / Interactions / Dependencies: Bombs reads position and Active state at accept; bomb invuln blinks | applied |
| Powerups 8 | pickup radius 14 px from plane centre | applied |

### design/gdd/input-and-player-mapping.md
| Source | Amendment | Status |
|---|---|---|
| Bombs 6 | Rule 17 note (consume only while IDLE with stock; purge at `stage_started`); Bombs row no longer provisional | applied |
| bookkeeping | Plane kits row → GDD, `charge_hold_ticks` 18 | adapted |

## Group C (enemy, pattern library, co-op, localization, game concept)

### design/gdd/enemy-and-ai.md
| Source | Amendment | Status |
|---|---|---|
| Boss 5 | Rule 18 boss fire-zone exemption (placement lint); Rule 23 8 reserved hurtboxes = boss max; Boss rows → GDD; Open Q9 closed | applied (combined Boss/Budget Interactions row split in two) |
| Powerups 2a | `drop_requested(pos, killer_slot, def_id, kill_class)` in Interactions + Dependencies | applied (Rule 14.5 and AC `drop_log` still 3-arg — see inconsistencies) |
| Powerups 2b, 2c | Open Q3 closed (cap 100, no value reduction); Open Q6 closed (8 carriers 4/2/2, recovery pod = Powerups Rule 7); V2 cue unchanged | applied |
| Budget 2a–2d | spawn `params.preview`; novelty gating note (1970s `fighter`, needs Enemy/Era sign-off); Rule 19 WAVE intensity unused by previews; Budget (15) rows | applied |
| Bombs 12 | Bombs row: GDD exists; no events, reads hurtbox registry | applied |

### design/gdd/bullet-pattern-library.md
| Source | Amendment | Status |
|---|---|---|
| Boss 6 | Boss row: `I_eff`, `owner_id` = part id, lint `start_delay ≥ 18` | applied (rule text also uses `I_eff`) |
| Budget 4a–4d | `PatternMetrics` pure functions; Boss row mentions 15 + new 15 row; F9 "Jet ≈ 116" = gate-ignoring sum (true 79.12 / 154.90; AC-51 wording); V4 note | applied |
| Boss | Open Q5 (boss exemption) | adapted: marked done, confirmed by Boss |

### design/gdd/coop-and-team-chain.md
| Source | Amendment | Status |
|---|---|---|
| Plane kits 9 | Rule 11 note ≤ 48 live bullets/slot | applied |
| Boss 8 | Boss rows → GDD; F4 note `critical_hp` / `core_main` from scaled core hp | applied |
| Powerups 7 | Rule 10 concrete (4-drone skip, tie-break all kinds, Dead/Continue/Selecting collect nothing); items per drop = N; Open Q7 closed | applied |
| Bombs 11 | Rule 9 rank-order bomb items; bomb hits never refresh `boss_hit_left` | applied |
| Budget 7 | Interactions row for 15 (previews unscaled) | applied |

### design/gdd/localization.md
| Source | Amendment | Status |
|---|---|---|
| Bombs 14 | keys `bomb.name`, `bomb.lancer.name`, `bomb.leech.name` | adapted: added to Rule 30 requested keys (no glossary file yet); Open Q4 extended |
| bookkeeping | Boss (14) row linked | adapted |

### design/gdd/game-concept.md
| Source | Amendment | Status |
|---|---|---|
| Plane kits 6 | §5 Lancer drone question closed (own cooldown 600); Fire tap/hold 0.3 s line | applied (4-drone answer uses Powerups wording) |
| Bombs 9 | §5 bomb designs decided; §14 open item struck | applied |
| Budget 9 | §10 note: implemented by 15 | applied |

## New inconsistencies noticed (for the final consistency check)

- `enemy-and-ai.md` Rule 14.5 + AC `drop_log` use 3-arg `drop_requested` (no `kill_class`); Downstream rows for Plane kits (11) still "not yet".
- `game-concept.md` §5 "Powerups only add drones" vs five item kinds; §3/§4 Critical Break "charge + bomb simultaneously" to check against CB (17).
- `bullet-manager.md` V-section "Ember Gold diamond" score item vs GEM plain / CHAIN `+` diamond; Rule 14 "every cancelled enemy bullet becomes a score item" not reworded (qualified by Rule 13 `items` and the cap).
- `collision-damage-lives.md` says Powerups uses kill credit to decide drops; Powerups uses Enemy `drop_requested`.
- `chain-tracker.md` Rule 2 mentions chain pickups without the amount 10 (only in rows).
- `game-events-and-session.md` base Rule 13 list and AC-05 still show bare `boss_defeated` (new signature only in the dated note).
- `scoring.md` F6: `boss_cap_hold_allowed()` false is applied as "streak resets"; Boss does not say reset vs pause.
- `input-and-player-mapping.md` Save (26) row still "no GDD / provisional".
- Registry: deprecated `enemy_ref_dps` 300 still present; several string-packed entries (`laser_meter`, `bomb_damage`, `item_pools`, `boss_budget_cap`, …) cannot be number-linted; `items_per_cancel_cap` note says it covers boss whole-screen cancels — Boss GDD should confirm its death cancel uses the cap.
- Scoring F8 "under 100M" bound stale (~31M) — carried from the balance reconcile.
- ADR-0001: boss part-kill cancels requested in 6c run at next tick's step 5; Powerups 7b handles hand-offs of the same tick — confirm that one-tick lag is intended (Boss AC-29 timing).

## For the next pass ("when written" asks; Critical Break and Wave director are being written now)

Also recorded in `design/gdd/systems-index.md` › Dependency notes.

- **Wave and stage director (16):** ≥ 8 carriers per stage (4 SMALL, 2 MEDIUM, 2 LARGE), ≥ 1 per wave, ≥ 180 ticks apart, not scaled by N (Powerups 11). Previews: schedule, run `check_stage`, novelty gating, `preview_alive_max` 1, `combo_window_ticks` 180, ≥ 2 successive carriers per preview wave, carrier respawns so short-lived gunners (~2.1 s) show a preview (Budget 5, risk). ≥ 75 ticks between `boss_defeated` and `stage_cleared` for the item sweep (Powerups Open Q3, retargeted from Boss). Warning/scroll-stop/`start_intro` timing (Boss Open Q3). Must list Bombs (12), Co-op (18), Session (1), Boss power budget (15).
- **Critical Break (17):** owns the trigger from `charge_active` / `charge_kind` / `charge_last_hit` (Kits Rule 40, Open Q8); calls `critical_break_finish(slot)`, reads `is_critical()`, `critical_left`, `core_world_pos()` (Boss); answers `cb_armed(slot)` (waives bomb toll), consumes `bomb_active` / `bomb_landed`, issues its own full-screen cancel before the banner (Bombs Rule 28, Open Q7); Leech break ease vs Lancer meter.
- **Era shift (19):** behaviour/option ladder and native-pattern stripping (Budget 6); `EraKitSkin`, `EraBombSkin` visual only.
- Systems 17, 19, 20, 24, 25, 28, 29, 30 must list Bombs (12).

## Programmer tasks (not done: code and project files)

- Boss: correct `boss.gd`, `boss_part.gd`, `boss_part_definition.gd`, `boss_definition.gd` and `data/bosses/*.tres` (Boss Open Q12: integer hp, `core_armor_pct`, `critical_pct`, unique part `id`, 360 px migration, remove part-kill flash); add `core_lock_fan` and `data/boss_budget/<id>.tres`.
- Bullet manager: per-bullet `tag`, hurtbox queries `first_in_column` / `nearest`, rectangle cancel area, `items` flag + CANCEL_NOITEM.
- Collision: `counts_chain`, `blink_remaining(slot)`, two-stage core republish, `combat_rules.gd` float hp removal.
- Chain: `apply_bomb_toll`, `chain_reduced`; Session: `bombs` field, `set_bombs`, `add_powerup`, `add_oneup`, boss events with `reason`.
- Kits: replace laser logic in `player.gd` with `LancerKit` / `LeechKit` (meter, linger, drones); Bombs: `BombCore` with `LanceSweep` / `BarbBurst`; Powerups: item system with stride sampling.
- GameLoop order per ADR-0001 steps 3c, 6c, 7b.

## Follow-up fixes (coordinator decisions, 2026-11-03)

| # | Decision | Files | Status |
|---|---|---|---|
| 1 | `drop_requested(pos, killer_slot, def_id, kill_class)` everywhere | `design/gdd/enemy-and-ai.md` Rule 14.5 and test-setup `drop_log`; Plane kits (11) Interactions + Dependencies rows → GDD | applied |
| 2 | §5 Powerups line rewritten (pods, chain pickups, medals, fixed 1-ups, never stat upgrades) | `design/gdd/game-concept.md` | applied; Critical Break wording left alone |
| 3 | Score item = plain 7 px gold GEM, `+` reserved for CHAIN; Rule 14 reworded (items-cancel → Powerups keeps ≤ `items_per_cancel_cap` stride-sampled gems; no-items cancels give none) | `design/gdd/bullet-manager.md` Rule 14, Powerups hand-off line | applied |
| 4 | Drops come from Enemy `drop_requested`, not kill credit | `design/gdd/collision-damage-lives.md` Interactions (Powerups removed from the kill-credit row) + Dependencies row | applied |
| 5 | `boss_defeated(reason, killer_slot)` with KILLED / CRITICAL_BREAK / TIMEOUT | `design/gdd/game-events-and-session.md` Rule 13 base list, AC-05 | applied |
| 6 | Cap-hold streak **resets** when `boss_cap_hold_allowed()` becomes false | `design/gdd/boss-and-boss-parts.md` Rule 33 + AC-33; `design/gdd/scoring.md` already said "resets" (F6 variable row, AC-39) | applied |
| 7 | Input Save (26) row → GDD with interface (`input.bindings` overrides, `dz_preset`, `fire_toggle`, `tap_assist`); Chain Rule 2 lists +10 chain pickup | `design/gdd/input-and-player-mapping.md`, `design/gdd/chain-tracker.md` | applied |
| 8 | Boss death whole-screen cancel uses `items_per_cancel_cap` (stride-sampled) | `design/gdd/boss-and-boss-parts.md` Rule 31; `design/gdd/powerups-and-drops.md` Rule 12 source list | applied; deprecated registry entry left |
| 9 | One-tick lag accepted: part-kill / death cancels requested in 6c apply at next tick's step 5 | `design/gdd/boss-and-boss-parts.md` Rule 24 step 4, Rule 31, AC-29 | applied |
| 10 | F8 bound ~31M per slot per stage at 72 hits/s; run bound ~62M (MVP) / ~124M (4 stages); int64 storage + 9-digit display clamp kept | `design/gdd/scoring.md` F8 | applied (run bound rescaled to match; adapted) |
