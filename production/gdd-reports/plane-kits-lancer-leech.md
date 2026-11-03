# GDD Report: Plane kits and drones: Lancer, Leech (system 11)

## 1. File written
`design/gdd/plane-kits-lancer-leech.md` (all 14 required headings, 12 formulas K1-K12, 48 acceptance criteria). It defines two kit cores (LancerKit, LeechKit; node-free, integer ticks, no RNG): the Fire state machine (tap shot with 12-tick linger; hold 18 ticks = charge mode), Lancer laser and meter, Lancer parked-laser drones, Leech focused shot and latch drones, damage table, hit-rate caps, DPS equivalence, laser invulnerability duty maths, prototype corrections, and provisional hand-offs to Bombs, Critical Break and Era shift.

## 2. Key decisions (auto-approve)
- Fire press = normal shot (auto-repeat); release before 18 ticks keeps firing 12 more ticks (tap linger). Hold 18 ticks (0.3 s) = charge mode and the shot stops. Hold while the Lancer meter < 400 = HOLD_PLAIN (slow continuous normal shot); the laser check is an edge check at tick 18 only.
- Damage scale: 1 standard bullet = 20 (= armour_damage_min), so all damage is armour-safe. Lancer shot 3-way fan (+/-9 deg), 36 bullets/s, 20 dmg. Leech normal 2 bullets (+/-4 deg), 24/s, 20; focused 2 bullets, 20/s, 30 dmg, 6 px pair. Drone bullets 20 dmg every 8 ticks each.
- Lancer laser: meter 1,000, min 400, burn 5/tick (200 ticks max, 80 min), fills +2 per counted hit from the plane's own shot only (no drones, no parked beams, no laser, no bombs, no fill while the laser runs). Laser 60 dmg every 3 ticks (20 hits/s). Requests 1+12 invuln every active tick. Ability speed 90 px/s (Leech has none).
- Dominance check: invulnerability duty 20.5% (full cycles) to 22.3% (min-activation spam) at perfect landing, 15-17% competent. The prototype was about 44% (fill 0.6/100). A data test fails above 25%.
- Lancer Drone button: drones park in place (x clamped 8-352) 300 ticks firing 6 px beams, 40 dmg every 8 ticks each; cooldown 600 starting at last dock. Uses no meter (closes concept §5 open question).
- Leech Drone button: drones latch (nearest eligible target, max 2 per target), 20 dmg every 5 ticks each (12 hits/s), jump to nearest on target loss, speed 14 px/tick (max jump 53 ticks < chain window); timer 360, cooldown 540 from last dock; denied with no valid target; immune targets dropped after 30 ignored hits.
- Design identity: Lancer converts to damage (fewer, bigger hits, position-dependent); Leech converts to hits (more guaranteed hits, position-independent).
- Balance: sustained effective DPS Lancer 1,129 vs Leech 1,095 (ratio 0.97, test band +/-10%); boss hp reference about 46,000 for a 60 s fight with one 4-drone player; raw max hit rate 72/s, so chain 999 takes at least 13.9 s.
- Pool: at most 48 live bullets per slot; 4P 192 <= 600, per-slot share 150.
- Death: drones removed, meter to 0 (knob), cooldown 0. Stage clear: drones snap home, cooldown 0, meter and drone_count carry (closes Session Open Q3).
- Critical Break contract: kit publishes `charge_active` (laser active ticks only, not grace), `charge_kind`, `charge_last_hit`; CB owns the trigger. Bombs never interrupt the laser nor touch the meter.
- Era hook: `EraKitSkin` per era changes visuals/sound/muzzle offsets (+/-4 px) only; all numbers identical (tested).
- Laser cue on the plane: nose lens glow while On, 2x2 afterglow for the 12 grace ticks; no blink for laser invulnerability.

## 3. Amendments
1. `design/gdd/systems-index.md` row 11: Depends on `5, 6, 7, 13` → `1, 3, 5, 6, 7` (cuts the 11<->13 cycle; Powerups gives drones via Session); Status → `**Designed** (pending review) — [GDD](plane-kits-lancer-leech.md) — **bottleneck, high risk**`. Progress tracker GDDs written +1.
2. `bullet-manager.md`: add per-bullet `tag` (0 plane shot, 1 drone) stored and returned in hit reports; add read-only hurtbox queries `first_in_column(x, half_width, y_from)` and `nearest(pos, filter)`; Open Q5 streak 3.0 / diamond 4.0 confirmed; Plane kits dependency row updated.
3. `collision-damage-lives.md`: hit results to sources carry `tag`; close Open Q3 (laser 60/20 per s, parked 40, latch 20, shot 20; duty 20.5-22.3%); add `blink_remaining(slot)` (longest non-laser invuln request) for the plane blink; AC-33 unblocked for kits.
4. `player-plane.md`: close Open Q4 (Lancer ability_speed 90, Leech none); V7 blink only while `blink_remaining > 0`, never for the laser; Rule 9 note kit counts its own held ticks; Rule 4 note focus_speed applies while Fire is physically down incl. taps, not during linger; add `stage_cleared` to Plane→Kit signals.
5. `game-events-and-session.md`: close Open Q3: drones snap home at `stage_cleared`; cooldown resets on death and at stage clear.
6. `game-concept.md` §5: replace "Open: does Lancer's drone deploy also need/use the laser meter..." with the decision (own cooldown only, 600 ticks); add tap/hold rule line.
7. `scoring.md` F7: hit-count assumptions exceed kit capability (see conflicts).
8. `art-bible.md`: §5.6 Lancer drone row lens-pod; kit meter 40% notch; beam sets (14 px, 6 px) and Leech tether (stretched sprite) in §8.3.
9. `coop-and-team-chain.md`: optional note under Rule 11 (kits <= 48 live bullets/slot).

## 4. Registry candidates
```yaml
constants:
  - name: charge_hold_ticks
    value: 18
    unit: ticks (0.3 s held Fire before charge mode)
    range: "12-30"
    source: design/gdd/plane-kits-lancer-leech.md (Rule 4, K1)
    referenced_by: [plane-kits-lancer-leech, player-plane]
  - name: shot_linger_ticks
    value: 12
    unit: ticks
    range: "6-24"
    source: design/gdd/plane-kits-lancer-leech.md (Rule 5)
    referenced_by: [plane-kits-lancer-leech]
  - name: player_shot_damage
    value: 20
    unit: damage units (standard bullet; plane and drone bullets)
    range: ">= armour_damage_min"
    source: design/gdd/plane-kits-lancer-leech.md (K8)
    referenced_by: [plane-kits-lancer-leech, collision-damage-lives]
  - name: lancer_ability_speed
    value: 90
    unit: px/s (1.5 px/tick) while the laser is active
    range: "60-120"
    source: design/gdd/plane-kits-lancer-leech.md (Rule 22)
    referenced_by: [plane-kits-lancer-leech, player-plane]
  - name: laser_meter
    value: "max 1000, min 400, burn 5/tick, fill 2/hit"
    unit: meter units
    source: design/gdd/plane-kits-lancer-leech.md (K3)
    referenced_by: [plane-kits-lancer-leech]
  - name: laser_damage
    value: "60 per tick, every 3 ticks"
    unit: damage units
    range: "40-90"
    source: design/gdd/plane-kits-lancer-leech.md (K6)
    referenced_by: [plane-kits-lancer-leech, collision-damage-lives]
  - name: drone_ability_cycle
    value: "Lancer park 300 / cooldown 600; Leech latch 360 / cooldown 540 (ticks, cooldown from last dock)"
    unit: ticks
    source: design/gdd/plane-kits-lancer-leech.md (K12)
    referenced_by: [plane-kits-lancer-leech]
  - name: kit_max_hits_per_s
    value: 72
    unit: raw counted hits/s per player (Leech tap + 4 latched drones)
    note: "chain_cap 999 reached in no less than 13.9 s; data test requires >= 12 s"
    source: design/gdd/plane-kits-lancer-leech.md (K9)
    referenced_by: [plane-kits-lancer-leech, chain-tracker, scoring]
formulas:
  - name: laser_invuln_duty
    expression: "(E + laser_exit_grace) / (E + R); E = ceil(meter / laser_burn); R = (meter_max - m0) / (fill_per_hit * eta_shot * 36 / 60)"
    variables: [E, laser_exit_grace, R, fill_per_hit, eta_shot]
    output: "0.15-0.23 at defaults; test limit 0.25"
    source: design/gdd/plane-kits-lancer-leech.md (K5)
    referenced_by: [plane-kits-lancer-leech, collision-damage-lives]
  - name: drone_phase
    expression: "phase_d = (d * interval) div 4"
    variables: [d, interval]
    output: "0..interval-1; distinct for 4 drones"
    source: design/gdd/plane-kits-lancer-leech.md (K7)
    referenced_by: [plane-kits-lancer-leech]
```
Existing entries whose `referenced_by` should gain `plane-kits-lancer-leech`: `max_drones`, `laser_exit_grace`, `armour_damage_min`, `move_speed`, `focus_speed`, `player_cap`, `chain_window`, `chain_cap`, formulas `drone_count` and `armour_damage`.

## 5. Conflicts
- **Scoring F7 hit counts** (competent 5,150 / expert 7,500 boss hits per 60 s = 86 / 125 hits/s) exceed kit raw maximum 72 hits/s (landed 43-60). Not a registry conflict (extend_unit untouched), but F7 must be re-baselined (about 2,700 competent / 3,600 expert boss hits; waves similar) or kit rates raised about 1.6x (T999 would drop to about 8 s). Recommended: re-baseline F7. Open Question 1.
- **Systems index** row 11 lists 13 as a dependency while 13 depends on 11: cycle, resolved by Amendment 1.
- Player plane V7 blinks on any Collision invulnerability, which would make the laser blink: needs `blink_remaining` (Amendment 3c/4b).
- Process note: global rules in `~/.claude/rules/gameplay-code.md` say "use delta time"; ADR-0001 and technical-preferences forbid `delta` in logic. The GDD follows ADR-0001 (integer ticks).
- No locked registry value was changed.

## 6. Open risks
- Lancer invulnerability duty (15-22%) is an unplaytested estimate; landing factors `eta` are assumptions.
- Tap-linger plus hold-to-laser auto-start may waste meter or feel sticky (Open Q2, Q3).
- Bullet manager needs two new capabilities (tag, hurtbox queries): cost and ownership unproven.
- Leech vs Lancer parity (ratio 0.97) holds only under assumed uptimes; the Leech focused shot is the likely outlier.
- Boss design must respect the un-skippable-dodge (> 4 s) and hit-gap constraints.
- Godot 4.7 tiled-sprite beams unverified.
- Critical Break, Bombs and Boss GDDs are undesigned; the provisional contracts may shift.
