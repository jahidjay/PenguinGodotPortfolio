# GDD Report: Bombs (system 12)

## 1. File written
`design/gdd/bombs.md` (all 14 required headings, 10 formulas B1-B10, 58 acceptance criteria). It defines `BombCore` (node-free, integer ticks, no RNG, one per slot): stock rules, Bomb press acceptance via Input `consume` and a 90-tick lockout, 90-tick invulnerability requested on the input tick (same-tick deathbomb only), the chain toll, the full-screen cancel, a per-target damage cap, and two bombs. Lancer: "Lance Sweep" (a 56 px light column planted at the plane's x for 24 ticks, then two columns sweep outward at 8 px/tick). Leech: "Barb Burst" (four bomb hooks, independent of drones, each takes the least-claimed nearest target, clings 18 ticks, bursts with splash and a local cancel). It also covers the Critical Break contract, co-op rules, anti-farm bounds and prototype migration. Balance numbers use the coordinator update (ref_dps 800; boss core 16,500 / 19,700; scoring 2.99M / 19.7M).

## 2. Key decisions (auto-approve; the user reviews these)
- **Stock:** 3 per life. Death resets to 3. `stage_started` tops up to a floor of 3. Max 5. No powerup, extend or pickup refill. `bomb_boss_floor` knob exists, default 0 (off). The Critical Break needs 1 of the 3.
- **One bomb at a time:** lockout 90 ticks = invulnerability 90 ticks (Collision's example value).
- **Deathbomb:** same tick only (Collision's rule). No grace window; a grace needs Collision to defer death (Open Question 2). The 6-tick buffer helps only after a lockout, not after a hit. Bombs calls `consume` only while IDLE with stock, so a press made while busy expires and never fires late (except within 6 ticks of the lockout ending, by design).
- **Chain:** bomb hits **never count** for the chain (new `counts_chain=false` flag). Each bomb costs **50% of the chain count** (toll, never drops a chain to 0). The toll is **waived** if the Critical Break reports `cb_armed(slot)` at the accept tick. Charge first, then bomb is the intended order. Toll knob 0 turns it off.
- **Cancel:** full-screen cancel with score items on the press tick (Powerups caps items at 100, gems). Later area cancels (Lancer rectangles, Leech 96 px circles) give no items. Items from the farm are bounded at 110,000 per bomb at best.
- **Damage:** Lancer 100 per hit every 4 ticks; Leech hook 200 + splash 100. Boss parts take 60%. Immune targets get no event and do not block the bomb (the laser does). Cap 1,000 per target per bomb (before the part percent). Lone core: Lancer 700, Leech 800 (ratio 0.875). A bomb is about 1 s of ref_dps (4.2-4.8% of a Fortress core; 17-20% of a turret). Bombs cannot kill MEDIUM or LARGE enemies alone. Phase guard: every boss phase span >= 4 x cap = 4,000 hp.
- **Leech uses separate bomb hooks, not the player's drones** (deviation from the brief's example): a bomb that depends on drones is weakest right after a death, when it is most needed, and would change the drone build. Hooks may launch visually from drones later (cosmetic).
- **Lancer bomb is world-anchored** at the plane's x at press, not following the plane. The Lancer core aligned for the laser is also hit at k=0, so the Lancer Critical Break is easy to line up.
- **Co-op:** per-slot stock; rank rotation `(slot - tick mod 4 + 4) mod 4` decides who gets the cancel items on same-tick bombs; bomb hits never refresh the team chain; no friendly fire.
- **No auto-bomb in MVP.** No kit state is read (closes Plane kits Open Question 7). Bomb numbers are identical in every era (EraBombSkin is visual only).
- **Visual:** Tracer Orange `#FF8A1F`; no screen flash (only the Critical Break flashes); everything on layers 5-6, below bullets (layer 8); the invulnerability end is shown by the plane blink (Player plane V7).
- **Dependencies:** index "Depends on" changes from `5, 6, 11` to `1, 2, 3, 5, 6, 7`.

## 3. Amendments
(Full wording is in `design/gdd/bombs.md`, Dependencies > Amendments 1-14.) Summary:
1. `systems-index.md` row 12: Depends on `5, 6, 11` → `1, 2, 3, 5, 6, 7`; Status → `**Designed** (pending review) — [GDD](bombs.md)`; progress tracker GDDs written +1; remove "Bomb design per plane" from "Open items carried over".
2. `chain-tracker.md`: add `apply_bomb_toll(slot, pct)` rule (`count - (count x pct) div 100`, window not refilled, `last_dropped` unchanged, skipped when Frozen) and event `chain_reduced(slot, before, after)`; Interactions/Dependencies rows for Bombs; edge case for milestones re-firing; one AC.
3. `collision-damage-lives.md`: damage events carry `counts_chain` (BOMB sends false); C5 adds the flag; Rule 13 last sentence → "Bomb damage never counts for the chain"; Open Question 4 closed (invuln 90, part 60%); `blink_remaining` includes the bomb; AC-33 unblocked for bombs; hit results carry target class.
4. `bullet-manager.md`: cancel areas gain an axis-aligned **rectangle**; cancel requests gain `items` (default true; false → reason CANCEL_NOITEM, no item); Bombs row; rectangle AC.
5. `game-events-and-session.md`: slot field `bombs` (0-5), `set_bombs` (Bombs-only writer), reset on run start/continue/drop-in, event `bomb_used(slot)`, carry-over note in Rule 9.
6. `input-and-player-mapping.md`: Rule 17 note (Bombs consumes only while IDLE with stock; purge at `stage_started`); Bombs dependency row no longer provisional.
7. `player-plane.md`: Rule 9 / Interactions: Bombs reads plane position at accept; bomb invulnerability blinks.
8. `plane-kits-lancer-leech.md`: Open Question 7 closed (Bombs read no kit state; independent of `drone_count`).
9. `game-concept.md` §5: replace "Bomb designs per plane: TBD" with the two bombs and the stock/toll rule; remove "Bomb design for each plane" from open items.
10. `art-bible.md`: §7.4 banner rule (Critical Break issues its own cancel before the banner); §8.3 sprite sets (column 56x16, hook 12x12, burst 48x48, ring); §4.6 Tracer Orange for bomb FX; §7.2 icon dims to 60% while busy.
11. `coop-and-team-chain.md` Rule 9: bomb items by rank order; bomb hits never refresh `boss_hit_left`.
12. `enemy-and-ai.md`: Bombs row, GDD exists.
13. `scoring.md` Open Question 3 note: bomb items are gems, capped, area cancels give none.
14. `localization.md`: glossary keys `bomb.name`, `bomb.lancer.name`, `bomb.leech.name`.

## 4. Registry candidates
```yaml
constants:
  - name: bomb_start
    value: 3
    unit: bombs (per slot at run start, continue, drop-in and after death)
    range: "2-5"
    source: design/gdd/bombs.md (Rule 3, B1)
    referenced_by: [bombs, game-events-and-session]
  - name: bomb_max
    value: 5
    unit: bombs (HUD shows at most 5 icons)
    range: "3-5"
    source: design/gdd/bombs.md (Rule 2, B1)
    referenced_by: [bombs, game-events-and-session]
  - name: bomb_stage_floor
    value: 3
    unit: bombs (minimum at stage_started; never lowers)
    range: "1-5"
    source: design/gdd/bombs.md (Rule 3, B1)
    referenced_by: [bombs, game-events-and-session]
  - name: bomb_invuln
    value: 90
    unit: ticks (1.5 s) requested on the accept tick
    range: "60-150"
    source: design/gdd/bombs.md (Rule 14, B3)
    referenced_by: [bombs, collision-damage-lives]
  - name: bomb_lockout
    value: 90
    unit: ticks (accept to next possible accept)
    range: "85-150"
    source: design/gdd/bombs.md (Rule 6, B2)
    referenced_by: [bombs]
  - name: bomb_chain_toll_pct
    value: 50
    unit: whole percent of the chain count lost per bomb (0 = off; waived when a Critical Break is armed)
    range: "0-75"
    source: design/gdd/bombs.md (Rule 12, B4)
    referenced_by: [bombs, chain-tracker]
  - name: bomb_target_cap
    value: 1000
    unit: damage units per target per bomb (before bomb_part_pct)
    range: "600-1500"
    source: design/gdd/bombs.md (Rule 8, B7)
    referenced_by: [bombs, collision-damage-lives]
  - name: bomb_part_pct
    value: 60
    unit: whole percent of bomb damage dealt to boss parts (class PART)
    range: "40-100"
    source: design/gdd/bombs.md (Rule 10, B7)
    referenced_by: [bombs, collision-damage-lives]
  - name: bomb_damage
    value: "Lancer 100 per hit (every 4 ticks); Leech hook 200, splash 100"
    unit: damage units
    range: "Lancer 60-150; hook 120-300"
    source: design/gdd/bombs.md (B5, B6, B7)
    referenced_by: [bombs, collision-damage-lives]

formulas:
  - name: bomb_chain_toll
    expression: "after = before - (before * toll_pct) div 100; skipped if before = 0, chain Frozen, or cb_armed"
    variables: [before, toll_pct]
    output: "1..999 when before >= 1 (never 0)"
    source: design/gdd/bombs.md (B4)
    referenced_by: [bombs, chain-tracker]
  - name: lancer_bomb_effect_ticks
    expression: "hold + ceil((max(x0, 360 - x0) + half_w) / v) - 1; defaults 24, 28, 8"
    variables: [x0, hold, half_w, v]
    output: "49-72 ticks"
    source: design/gdd/bombs.md (B5)
    referenced_by: [bombs]
  - name: bomb_target_cap_rule
    expression: "send only if sent[target] + base <= bomb_target_cap; part damage = (base * bomb_part_pct) div 100"
    variables: [base, sent, bomb_target_cap, bomb_part_pct]
    output: "0-1000 pre-multiplier per target per bomb"
    source: design/gdd/bombs.md (B7)
    referenced_by: [bombs, collision-damage-lives]
```
Existing entries whose `referenced_by` should gain `bombs`: `armour_damage_min`, `buffer_ticks`, `canvas_size`, `play_top`, `respawn_invuln`, `chain_cap`, `item_base`, `max_drones` (no: not used), `player_hitbox_radius` (no). So add to: `armour_damage_min`, `buffer_ticks`, `canvas_size`, `play_top`, `respawn_invuln`, `item_base`.

## 5. Conflicts with locked values or other GDDs
- No locked registry value is contradicted.
- **Collision Rule 13** ("Bomb damage counts per target touched") is open for Bombs to decide; this GDD decides "never counts", so Collision's wording needs the amendment above (not a conflict).
- **Bullet manager** supports only circle and full-screen cancel areas; Bombs needs a rectangle and a no-items flag (amendment 4).
- **Systems index** lists Bombs as depending on Plane kits (11); this GDD drops that dependency (kits Open Question 7 closed).
- **Art bible §6.8 / Critical Break banner rule:** Bombs cannot guarantee a clear field at the break moment; Critical Break (17) must issue its own cancel.

## 6. Open risks
- The 50% chain toll is a guess; the `bomb_chain_toll_pct` knob (0-75) is the lever. It adds a new Chain API and event.
- No deathbomb grace: humans cannot react after a hit, so bombs are anticipatory only. Playtest; a grace would need Collision to defer death.
- Rectangle cancels plus a no-items flag in GDScript with 2,000 bullets (up to 8 area cancels per tick in 4P); mitigated by the k=0 clear leaving few bullets. Perf AC-51.
- Item farm: competent-player share of bomb items is about 11% of the 2.99M stage at the extreme (110,000 x 3); lower `items_per_cancel_cap` to 50 if it proves exploitable. Depends on Powerups confirming gems and the cap.
- Leech Critical Break needs Fire held about 1 s until the hooks burst; Lancer's is easy (core hit at k=0). Check balance when the Critical Break GDD exists.
- With the new hp (flak gunner 1,200, core 16,500) bombs no longer kill mediums; they only clear fodder and cancel bullets. If bombs feel weak for clearing waves, raise `lancer_damage`/`hook_damage` together (keep the lone-core ratio 0.8-1.2).
- Boss phase guard: a core split into 5+ phases (under 4,000 hp each) fails B10; Boss (14) must respect it.
- The skills `/design-review`, `/balance-check` and `/brainstorm` were attached to the request; no specialist agents are available in this run, so no agent review was done and nothing was written outside `bombs.md` and this report. The balance numbers in B8/B9/B10 were checked by hand against the updated references.
- Godot 4.7 tiled-sprite behaviour for the 56 px column is unverified (Open Question 15).
