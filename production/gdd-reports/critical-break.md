# GDD Report: Critical Break (system 17)

## 1. File written
`design/gdd/critical-break.md` (status Designed, pending review). It defines the trigger for the game's payoff: a node-free `CriticalBreakCore` running at tick step 6b (after Collision/Bombs, before Boss `apply_results` 6c, before Chain step 8). A break fires when one slot lands a **bomb on the boss core** while the core is in its critical reserve and that slot's **charge** (Lancer laser / Leech focused shot) has been running and hitting the core. It then multiplies the chain (Chain F4), lets Scoring pay S5 + S6, issues its own full-screen cancel with items to the breaker, calls `Boss.critical_break_finish(slot)`, and plays one white frame (replaced by a particle burst under `access.reduce_flashing`) and the bilingual banner. It has 45 acceptance criteria, 7 formulas and 31 core rules.

## 2. Key decisions (auto-approve; the user can change any of these)
- **Trigger = bomb landing on the core (`bomb_landed(slot, core, CORE)`)**, not bomb acceptance. Qualifies if **committed** (armed at the accept tick) OR **armed at the landing tick** (late arming: toll was paid, multiply uses the reduced count).
- **Armed** (`cb_armed`) = `is_critical` AND slot Active AND not yet consumed AND charge run >= **12** ticks (`cb_charge_min_ticks`) AND (charging now OR ended <= **12** ticks ago, `cb_charge_lenience`, = `laser_exit_grace`) AND last charge hit was **on the core** within **12** ticks (`cb_hit_window`).
- **Charge, for both kits, is the same test.** Lancer = laser active ticks (not grace). Leech = focused shot (always available). HOLD_PLAIN, drones and the bomb are not charge. Both need Fire held >= 30 ticks (18 + 12) before a break can arm. This is the "equally achievable" rule; Lancer's extra cost is the 400 meter, Leech's is the hook delay (OQ 1 records the risk Leech is easier).
- **A committed bomb no longer needs the charge** (solves Bombs' Leech concern: press Bomb while focused bullets land, then release Fire; hooks bite at `t0 + 19..71`).
- **One break per boss** (`consumed`). **Co-op: the slot whose bomb lands first wins; same-tick ties by the rotating rank** `(slot - (tick mod 4) + 4) mod 4`. Losers get no refund and no break; the Boss value (S4) still goes to all eligible slots.
- **Order on success (atomic, tick T, step 6b):** `apply_critical_break` (so `boss_peak` includes the multiply before `boss_defeated` freezes it) -> own full-screen cancel with items to breaker -> `critical_break_finish` -> `critical_break_landed` event. CB runs before Boss 6c so CB beats a same-tick normal kill (Boss Rule 23).
- **CB pays and writes nothing itself.** Scoring pays S5/S6 on `chain_multiplied` and writes `critical_breaks`/`life_bonus_total` (resolves the Session table that said CB writes them). CB reads the popup amounts via new pure Scoring functions `preview_cb_points`, `preview_ldb_points`.
- **No hitstop, no time scaling, no presentation-only freeze** (logic keeps ticking; a frozen picture over a live game is rejected). Only a local boss-sprite shake (<= 4 px, 8 ticks).
- **Timeline:** logic at `T`; cancel executes and the **white frame is drawn at T+1** (it covers the bullet removal; exactly one rendered frame); banner at `T+2` once `enemy_bullet_count == 0` (waits <= 120 ticks, else dropped; bullets always win); banner 6/30/6 ticks; burst 36 ticks; popup 90 ticks.
- **Reduce flashing** replaces only the white frame (80-particle warm burst, tint max 25 %, luma step <= 8 % per frame); banner stays.
- **Failure feedback:** `critical_break_missed(slot, NO_CHARGE | NOT_ON_CORE)` blip, CB icon dims 30 ticks, no text. **No break:** boss dies normally, `critical_break_expired(reason)`, no counters.
- **Window expiry changes nothing** for CB: the break stays valid until the core dies (Boss `is_critical()` semantics); a bomb whose landing would kill the core still yields `CRITICAL_BREAK`.
- **HUD state published:** `cb_state(slot)` = NONE / OPEN / ARMED / COMMITTED / OPEN_LATE (armed icon on the plate, gold outline on the bomb icon, ring and 420-tick arc on the core).

## 3. Amendments (main session applies)
1. `design/gdd/systems-index.md` row 17: Depends-on `7, 11, 12, 14` -> `1, 3, 7, 8, 11, 12, 14`; Status -> `**Designed** (pending review) — [GDD](critical-break.md)`. Progress tracker GDDs written +1. "Open items carried over": remove "Critical Break formula and Life Damage Bonus".
2. `boss-and-boss-parts.md` Rule 23 and tick order: add `core_target_id()`; add step "6b. CriticalBreakCore.tick()" before 6c; state that CB calls `Chain.apply_critical_break` before `critical_break_finish`; Interactions row no longer provisional.
3. `bombs.md` Rule 28 / Amendment 10: interface now specified in critical-break.md Rules 9-12; Rule 12 define `cb_armed` precisely; Open Question 7 closed (committed bomb needs no charge).
4. `plane-kits-lancer-leech.md`: Open Question 8 closed (12-tick run, core-hit within 12, same test for both kits; HOLD_PLAIN and drones are not charge); Rule 40 note that `charge_last_hit` target ids are boss part ids (core 1000 + 0).
5. `chain-tracker.md` Rule 7: multiply must arrive before `boss_defeated` (CB runs at 6b); Dependencies row for CB resolved.
6. `scoring.md`: add pure `preview_cb_points(before)` and `preview_ldb_points(lives)`; Rule 6 clarify Scoring (not CB) writes `critical_breaks` and `life_bonus_total`.
7. `game-events-and-session.md` line ~110 and ~282: CB does not write the counters (Scoring does); event `critical_break_landed(slot, before, after, raw, core_pos, breaks_on_run)` (replaces the prototype's `(player, final_chain, life_bonus)`); add `critical_break_missed(slot, reason)`, `critical_break_expired(reason)`; dependency Hard -> Soft.
8. `collision-damage-lives.md`: Open Question 5 closed (normal C4 path; the break is `critical_break_finish`, not a damage event); Interactions row 270.
9. `bullet-manager.md`: Interactions row for CB: `request_cancel(screen, cause_slot, items = true)` and `enemy_bullet_count`.
10. `coop-and-team-chain.md`: Open Question 10 note (MVP: breaker only, first in rank order).
11. `localization.md` line ~280: CB GDD exists; popup uses atlas digits and an icon, no text.
12. `design/art/art-bible.md` 7.3: add the timeline (flash T+1, banner T+2 after the field is empty, 6/30/6), "no hitstop, local boss shake <= 4 px"; 7.4: CB issues its own cancel; banner waits <= 120 ticks then is dropped.
13. `game-concept.md` section 14: close "Exact Critical Break multiplier formula and Life Damage Bonus calculation" (Chain F4, Scoring F4, trigger in critical-break.md); section 4: bomb must land on the core with a charge hitting it within 12 ticks.

## 4. Registry candidates
```yaml
constants:
  - name: cb_charge_min_ticks
    value: 12
    unit: ticks (consecutive charge-active ticks before a break can arm)
    range: "6-30"
    source: design/gdd/critical-break.md (F1)
    referenced_by: [critical-break]
  - name: cb_charge_lenience
    value: 12
    unit: ticks (charge may have ended this long ago; equals laser_exit_grace)
    range: "0-30"
    source: design/gdd/critical-break.md (F1)
    referenced_by: [critical-break, bombs]
  - name: cb_hit_window
    value: 12
    unit: ticks (max age of the last charge hit on the core)
    range: "6-30"
    source: design/gdd/critical-break.md (F1)
    referenced_by: [critical-break, bombs]
  - name: cb_banner_wait_max
    value: 120
    unit: ticks (banner waits for an empty field, then is dropped)
    range: "0-240"
    source: design/gdd/critical-break.md (F5)
    referenced_by: [critical-break]
formulas:
  - name: cb_armed
    expression: "is_critical AND NOT consumed AND active(s) AND run_ok(s,t) AND hit_ok(s,t); run_ok: charge run >= cb_charge_min_ticks and (charging now or ended <= cb_charge_lenience ago); hit_ok: last charge hit target == core and age <= cb_hit_window"
    variables: [cb_charge_min_ticks, cb_charge_lenience, cb_hit_window, run_len, last_active, hit_tick]
    output: bool
    source: design/gdd/critical-break.md (F1)
    referenced_by: [critical-break, bombs]
  - name: cb_winner
    expression: "argmin rank(s,T) over triggering slots; rank = (s - (T mod 4) + 4) mod 4"
    variables: [s, T]
    output: "one slot or none, once per boss"
    source: design/gdd/critical-break.md (F2)
    referenced_by: [critical-break, coop-and-team-chain]
```
Existing entries to extend `referenced_by`: `cb_mult`, `cb_add`, `chain_critical_break` (add `critical-break`); `cb_unit`, `ldb_per_life`, `critical_break_score` (add `critical-break`); `setting_access_reduce_flashing` (add `critical-break`); `laser_exit_grace` (add `critical-break`).

## 5. Conflicts with locked values or other GDDs
- **Session vs Scoring on who writes `critical_breaks` / `life_bonus_total`:** Session's table says CB writes; Scoring Rule 6 says Scoring writes. Resolved here in favour of Scoring (Amendment 7). No locked value changed.
- **Prototype `boss_part.gd` "core can only be finished by a Critical Break":** contradicts Boss GDD (core can die after the window). Boss GDD wins; CB is optional.
- No locked registry values contradicted.

## 6. Open risks
- **Leech vs Lancer parity:** Leech's break needs no resource; may be easier (OQ 1). Knob ready: raise `cb_charge_min_ticks` for FOCUS or require N focused core hits.
- **Boss finish cannot be refused after the multiply** (defensive path, OQ 5); suggest a pure `can_critical_break_finish()`.
- **Leech hooks may not target the core** if other eligible targets exist (needs Wave director `despawn_all`, no adds).
- **Single-frame flash guarantee** on Web/mobile needs a render-side flag (→ ADR).
- **Banner gate** depends on no bullet sources after `boss_defeated` (Wave director/Pattern library `owner_destroyed`).
- **Late arming** means the multiply can apply to a halved chain; intended as a penalty, may feel punishing; playtest.
- Scoring preview functions (or an award event) must be added (OQ 7); HUD/Audio/VFX/Tally interfaces are provisional.
