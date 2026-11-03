# Report: Plane kits and bombs: Sentry, Breaker (system 29, Target tier)

## 1. File written
`design/gdd/plane-kits-sentry-breaker.md` (all 13 required headings in order, 51 acceptance criteria, 14 open questions).

Summary: Sentry and Breaker inherit LL Rules 1-15 (Fire state machine, tap/hold, drone return rules, hit-rate caps, charge contract) and add four distinct chain routes next to Lancer (damage to meter) and Leech (attachment to guaranteed hits). **Sentry = territory**: twin parallel shot, Entrench nose cannon (50 x 10/s, tracking idle drones, ability speed 75), world-anchored auto-aiming turrets (range 160, 40 damage every 7 ticks, 420 ticks, cooldown 480, early recall after 60 ticks). **Breaker = threat conversion**: 30-damage ram shot, Breach slug (40 x 15/s) that spends a **return stock** as seeking bolts, and a plane-relative **Erase Net** (circle cancels r 26, budget 30 bullets per drone, 40 px clear of the hitbox, `items = false`) whose erased bullets fill the stock. Two bombs fit Bombs 12 unchanged: **Bastion** (Sentry: growing dome at a point 56 px ahead, 72 ticks, 60 damage per 6 ticks, shelters allies) and **Backlash** (Breaker: full-width wall rising 12 px/tick, 500 damage once per target). 2-drone sustained dps 804.0 (Sentry) and 777.2 (Breaker), both inside +/-10% of `ref_dps` 800; raw hit-rate maxima 58.3 and 67 per second (T999 >= 14.9 s); <= 46 live bullets per slot.

## 2. Key decisions (auto-approve; please review)
- **Chain identities:** Sentry = coverage (turrets keep the chain while the plane dodges, only within 160 px of fixed posts); Breaker = enemy bullets become hits (erase -> stock -> bolts), strongest in dense fire, weak in calm waves.
- **Breaker cancels give NO items** (`items = false`): a continuous net with items would farm up to 100 gems per request x 150 requests per drone; gems would clutter the screen when the net works; the reward is stock/bolts. Outside `items_per_cancel_cap` (bomb `k = 0` cancel keeps its cap). Cost: Breaker's score from erasing is indirect (Open Question 4).
- **Readable Chaos guards for the net:** budget 30 bullets per drone per use (<= 7.74 bullets/s average, data limit 10/s, AC-32), zones >= 40 px from the hitbox (pulses skipped near the top), no tunnelling (`v_cap x interval <= 2 x r`), true-size corner brackets, SPENT drones dim, erase pulse every 2 ticks (fallback 3-4).
- **Bullet-manager contract:** new `cancel_report(slot, request_id, count)` at the start of the next tick; credit per pulse capped at 4, max 32 stock per drone per use, `stock_max` 60 (30 bolts, 2.5 s barrage); stock carries across stages, resets on death.
- **Charge modes:** both always available at `h = 18` (no HOLD_PLAIN). New `charge_kind` values `ENTRENCH`, `BREACH`; charge-source hits are new bullet tags 2 (shell/slug) and 3 (bolt); turret, idle and ram hits are not charge. Entrench slows the plane to 75 px/s (cost of tracking drones).
- **Sentry can pre-place** (no target required to press Drone); **early recall** after 60 ticks (Sentry only; cooldown starts at the last dock, so the cycle stays 930 at full use and ~565 at early recall).
- **All cycles 930 ticks** (Sentry 420/30/480, Breaker 300/30/600); Sentry has the highest active share (45.2%), balanced by fixed posts and range.
- **Kit damage sources:** no new Collision source; Breaker net ram uses DRONE; Sentry sends no kit damage events (turrets are bullets).
- **Bombs:** Bastion (r 40 -> 104, 72 ticks fixed, 12 events max = 720, PART 36) and Backlash (wall 12 px/tick, `effect_ticks` 2-49, 500 once per target, PART 300, hits everything above the plane). Both: full-screen cancel with items at `k = 0`, area cancels without items afterwards, no kit state read (Bombs Rule 7 holds), end before the 90-tick lockout. Backlash is weakest on one target (500) and strongest on many; Bastion is the close-range/co-op shelter.
- **Live bullets <= 48 per slot kept** (Sentry 46, Breaker 40), so Co-op Rule 11 is untouched.
- **ref_dps stays 800** (MVP-owned); the Target planes are tuned into its band (Breaker 777.2 is -2.9%).

## 3. Amendments (exact edits; main session applies)
1. `design/gdd/systems-index.md` row 29: Depends-on `11, 12` -> `3, 6, 11, 12`; Status -> `**Designed** (pending review) — [GDD](plane-kits-sentry-breaker.md)`. Dependency note: systems 17, 19, 20, 24, 25, 28 should list system 29.
2. `design/gdd/bullet-manager.md`: Rule 2 `tag` add 2 = charge shot, 3 = return bolt (bolt speed 18 px/tick); Rule 13/Interactions: kits may issue circle cancels with `items = false` (<= 2 per slot per tick) and receive `cancel_report(slot, request_id, count)` next tick; Dependencies row Plane kits: add Sentry 46 / Breaker 40 live bullets; AC-40 scenario: 1,350 bullets + 12 cancel areas per tick <= 2.5 ms p99; Rule 14: net cancels are outside `items_per_cancel_cap`.
3. `design/gdd/collision-damage-lives.md`: hit results carry `tag` 0-3; Breaker net ram = source DRONE (rank 2); no new source.
4. `design/gdd/critical-break.md`: Rule 5 charge list add Entrench (`ENTRENCH`) and Breach (`BREACH`); `charge_kind` enum add both; row "Sentry, Breaker kits (29)" -> GDD exists; `charge_last_hit` = last counted tag 2/3 result.
5. `design/gdd/bombs.md`: add Bastion and Backlash (new Rules 35-36 linking `plane-kits-sentry-breaker.md` Rules 31-32, SB7-SB8); Dependencies row "Sentry, Breaker kits (29)" -> GDD exists; Open Question 16 closed (`BombCore` hosts per-plane effect classes, confirm with lead-programmer); `effect_ticks`: Bastion 72, Backlash 2-49.
6. `design/gdd/plane-kits-lancer-leech.md`: Open Question 15 closed (shared `DroneBank`); Open Question 5 note (early recall: Sentry only, 60 ticks); Rule 2 tags add 2 and 3; Rule 40 `charge_kind` add `ENTRENCH`, `BREACH`; K8 note: Sentry 804.0 / Breaker 777.2 at 2 drones.
7. `design/gdd/player-plane.md`: V6 add Sentry turret 12x12 and Breaker eraser 16x10; PF4 offsets for 45x42 and 42x45 sprites; `ability_speed` Sentry 75.
8. `design/gdd/coop-and-team-chain.md`: Rule 11 note (Sentry 46 / Breaker 40 live bullets); Rule 9: Bastion dome and Breaker net are shared field effects (items none, credit to the requester).
9. `design/art/art-bible.md`: 5.6 Breaker row "pulse arc in front" -> four true-radius corner brackets; add Sentry base plate, tick marks, bolts, brackets, dome frames and wall bar to 8.3; 7.2 Breaker stock bar.
10. `design/gdd/menus-title-plane-select.md`: Sentry/Breaker `available = true` at Target; keys `plane.sentry.*`, `plane.breaker.*` in Bengali and English.
11. `design/gdd/boss-power-budget.md` and `design/gdd/bullet-pattern-library.md`: authoring note "a Breaker net removes up to ~120 bullets per 930 ticks; patterns must stay survivable without it, and lethal shapes must not depend on those bullets surviving".
12. `design/gdd/hud.md`: Sentry (ability bar + recall glyph) and Breaker (stock bar + drone lamp) data rows.

## 4. Registry candidates (entities.yaml, existing format)
```yaml
  # --- Wave (2026-11-03): Plane kits Sentry, Breaker (29) ---
  - name: net_erase_budget
    value: 30
    unit: bullets erased per Breaker drone per use (then the drone is SPENT)
    range: "15-45"
    note: "Average erase bound 4 x 30 / 15.5 s = 7.74 bullets/s per slot; data test limit 10/s"
    source: design/gdd/plane-kits-sentry-breaker.md (Rule 23, SB4)
    referenced_by: [plane-kits-sentry-breaker, boss-power-budget, bullet-pattern-library]
  - name: breaker_stock
    value: "max 60, bolt cost 2, credit <= 4 per pulse, death keep 0"
    unit: stock units
    source: design/gdd/plane-kits-sentry-breaker.md (Rules 20-21, 25)
    referenced_by: [plane-kits-sentry-breaker, hud]
  - name: net_safe_clear
    value: 40
    unit: px (zone edge to plane centre; net never erases closer)
    range: "30-60"
    source: design/gdd/plane-kits-sentry-breaker.md (Rule 24, SB5)
    referenced_by: [plane-kits-sentry-breaker, bullet-manager]
  - name: bastion_bomb
    value: "r 40 -> 104 (4 px/tick), 72 ticks, 60 dmg every 6 ticks, centre 56 px ahead of the plane"
    unit: px / ticks / damage
    source: design/gdd/plane-kits-sentry-breaker.md (Rule 31, SB7)
    referenced_by: [plane-kits-sentry-breaker, bombs]
  - name: backlash_bomb
    value: "wall 12 px/tick, half height 12, 500 dmg once per target (PART 300), effect_ticks 2-49"
    unit: px / ticks / damage
    source: design/gdd/plane-kits-sentry-breaker.md (Rule 32, SB7)
    referenced_by: [plane-kits-sentry-breaker, bombs]
  - name: kit_player_bullet_tags
    value: "0 plane shot, 1 drone bullet, 2 charge shot, 3 return bolt"
    unit: tag id
    source: design/gdd/plane-kits-sentry-breaker.md (Rule 2)
    referenced_by: [plane-kits-sentry-breaker, plane-kits-lancer-leech, bullet-manager, collision-damage-lives, critical-break]
```
Edit existing: `drone_ability_cycle` value -> `"Lancer park 300 / cooldown 600; Leech latch 360 / cooldown 540; Sentry emplace 420 / cooldown 480; Breaker net 300 / cooldown 600 (all 930-tick cycles incl. 30 return; cooldown from last dock)"`. Add `plane-kits-sentry-breaker` to `referenced_by` of: `max_drones`, `player_cap`, `v_cap_global`, `move_speed`, `focus_speed`, `play_top`, `armour_damage_min`, `chain_window`, `chain_cap`, `charge_hold_ticks`, `shot_linger_ticks`, `player_shot_damage`, `kit_max_hits_per_s`, `ref_dps`, `items_per_cancel_cap`, `bomb_start`, `bomb_max`, `bomb_stage_floor`, `bomb_invuln`, `bomb_lockout`, `bomb_chain_toll_pct`, `bomb_target_cap`, `bomb_part_pct`, `bomb_damage`, and formula `drone_phase` (Sentry turret phases (d x 7) div 4, Breaker ram (d x 6) div 4).

## 5. Conflicts with locked values or other GDDs
1. **`ref_dps` floor rule:** the registry defines `ref_dps = floor100(min(Lancer(2), Leech(2)))` = 800. Breaker(2) = 777.2 would give 700 if included. Resolved by keeping 800 (MVP-owned) and tuning Target planes into +/-10% (Open Question 14). Not a change to the registry value.
2. **LL Open Question 5** (early recall default no): Sentry allows recall after 60 ticks. Intentional, Sentry only.
3. **Art bible 5.6** Breaker "a pulse arc in front (not a ring shape) shows the erase zone": this GDD uses four corner brackets (a front arc would misreport a full-circle zone). Needs art-director confirm (Open Question 6).
4. **BM Rule 2 / LL Rule 8** define tags 0 and 1 only; tags 2-3 and `cancel_report` are new (Amendment 2). Not a locked value.
5. **Critical Break** names `charge_kind` `LASER`/`FOCUS` in prose; two enum values added (CB reads no rule from the kind). No locked value changed.
No contradiction with registry constants (`chain_cap`, `armour_damage_min`, `player_cap`, `v_cap_global`, `bomb_*`, `items_per_cancel_cap`).

## 6. Open risks
- **Perf (engine):** Breaker cancels per tick in 4P (up to 12 areas x 1,350 bullets = 16,200 tests/tick in GDScript before broad-phase). Mitigation: pulse interval 2 (3-4 fallback), grid broad-phase, AC-45. Godot 4.7 packed-array loop speed unverified.
- **Cancel report API** (new Bullet manager surface) must be deterministic and cheap; ordering with FIFO and `items = false` reasons.
- **Balance is assumption-heavy:** Sentry in-range share 0.75, Breaker contact share 0.35, `fill_eff` 0.70, Breach share 0.40, landing factors, 30-tick return. Breaker/Lancer ratio is only 0.906 (limit 0.90); a small change flips it.
- **Breaker in calm waves** has almost no bolt income (24 dps at `fill_eff` 0.7, 3.5 at 0.1): it may feel weak outside curtains; no gems for erasing may feel unrewarding.
- **Readable Chaos in 4P:** 16 zones plus nets over a dense screen; bracket flash throttled to 2 Hz; needs the 4P capture test (AC-46).
- **Sentry active share 45.2%** is the highest; boss designs with parts out of turret reach or moving constantly could make Sentry weak, or immobile bosses make it dominant.
- **Backlash** may over-serve waves (kills all SMALL above the plane); Open Question 11.
- Not consulted: creative-director, art-director, audio-director, qa-lead, systems-designer (auto-approve).
