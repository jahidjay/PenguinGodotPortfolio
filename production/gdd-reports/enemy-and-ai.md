# Report: Enemy and AI (system 10)

## 1. File written
`D:\Projects\GodotProjects\Morutjan\morut-jan\design\gdd\enemy-and-ai.md` (status: Designed (pending review)). No other file was edited except this report.

Summary: enemies are pooled node-free records built from `EnemyDefinition` resources (SMALL / MEDIUM / LARGE, integer hp, capsule body, kill class, path, emitters). Paths are closed-form functions of integer age (STRAIGHT, BEZIER, SINE, ENTER_HOVER_EXIT, FOLLOW_FORMATION). The Enemy manager publishes hurtboxes to the Bullet manager and bodies to Collision, arms/retires Pattern library emitters by a fire-zone rule, and runs a fixed death sequence on *destroyed*. "AI" is scripted, with turn-to-face as the only reaction to players. Waves spawn by role; Era shift maps roles to per-era definitions (1941: scout, prop fighter, flak gunner, heavy bomber; 1970s: dart jet, delta jet, radar gunner, missile carrier). 10 formulas, 58 acceptance criteria, 14 open questions.

## 2. Key decisions (all auto-approve; user may change)
- AI is scripted, not reactive. Only reactions: optional facing toward the nearest Active player (cap 0.05 rad/tick), pattern aiming (library), spawn clearance.
- Paths are `pos(age)` in closed form (no accumulation). Formations = several FOLLOW_FORMATION enemies on one anchor with offsets; no formation system.
- **Off-screen emitters do not fire** (closes Pattern library Open Q5). Emitter arms once when the muzzle enters the field inset by 4 px, retires once when it leaves, the enemy starts Leaving, or `fire_end`. Never re-armed (library has no pause).
- Intensity: CONSTANT, WAVE (frozen at spawn), or AGE_RAMP. Frozen intensity avoids the library's gate-flicker problem.
- Kill cancel: SMALL none; MEDIUM 40 px circle; LARGE 72 px circle (cause = killer, area-based, via BM `request_cancel`). No extra chain bonus on kills.
- Classes: SMALL hp 20-60, circle r_e 7-9, 1 hurtbox; MEDIUM r_e 12 spine +-8, 2 hurtboxes, hp 450 (1941) / 560 (1970s); LARGE r_e 18 spine +-30, 3 hurtboxes, hp 1,500 / 1,880. `ref_dps` 300 (provisional). TTK targets 1.5 s / 5 s. Exposure must be >= 1.4 x TTK (validator).
- Armour use: only LARGE has plating (armoured 50% for the first 120 ticks targetable, then normal; hatch opens and first wall volley starts at the same tick). Armoured hits count for chain.
- Hurtbox = r_e + 2 px (generous shots, honest deaths). Multi-circle hurtboxes share one `(id, gen)`.
- Ground targets (`layer = GROUND`) are non-lethal bodies (`lethal = false`) but still hittable.
- Only targetable enemies (body intersects field) publish hurtboxes/bodies; Incoming enemies cannot be hit by bombs/lasers.
- hp scales with player count for MEDIUM/LARGE only: `round10(hp_base x (100 + 60(N-1)) / 100)`, frozen at spawn. SMALL unscaled.
- Spawn: blocked-by-clearance requests retry 30 ticks then drop; cap 28 alive and 32 enemy hurtboxes (8 of BM's 40 reserved for boss); seeds drawn only on success.
- Drops: deterministic "carrier" flag in the spawn request (wave-authored), not random; Enemy sends `drop_requested`, Powerups decides contents. Escaped carriers drop nothing.
- Spawn by role (`fodder`, `fighter`, `gunner`, `heavy`) with per-era role tables; no mid-life definition swaps.
- Death sequence: remove from publication, stop emitters (owner_destroyed, cancels fuses), `enemy_destroyed` event, optional cancel, optional drop, free slot (gen+1). Escape/despawn is silent. `max_life_ticks` 1,500 forces a straight-up exit at 2.5 px/tick.
- `y_shift = play_top - 48` for 3-4P applied to all path y at spawn.
- Perf: Enemy tick <= 0.2 ms p99 (28 enemies); tick order adds step 3b (move/publish) and 6b (apply results).

## 3. Amendments (exact edits for other files)
1. **design/gdd/bullet-pattern-library.md**
   - Open Questions row 5: change to "Closed: Enemy (10) Rule 18 - off-screen enemy emitters do not fire; arm once on muzzle entering the fire zone, retire once."
   - Interactions with Other Systems and Dependencies (Upstream/Downstream Enemy row): add "`next_volley_in(emitter) -> int` (ticks to next volley over the emitter's runners, -1 if none), read-only, used for enemy tells" and "Enemy holds intensity constant per enemy (frozen at spawn)".
2. **design/gdd/collision-damage-lives.md**
   - Core Rule 1 / C1 body list: "any enemy body shape" -> "any **lethal** enemy body". `set_bodies` record gains `lethal` (bool, default true) and `kill_class`. Ground targets publish `lethal = false`.
   - `hit_results` tuple gains `hp_after`: `[(id, shooter, result, dealt, hp_after)]` (Test setup paragraph and Rule 12).
   - Dependencies, Enemy and AI (10) row: append "publishes `kill_class`, `lethal`; receives `hp_after`; ground targets are non-lethal".
   - Edge case "If an immune target's body touches a player" add "(lethal bodies only)".
3. **design/gdd/bullet-manager.md**
   - Interactions + Dependencies cancel requesters ("Bombs (12), Boss (14) part kills, Critical Break (17)"): add "Enemy (10): MEDIUM/LARGE kills (circle 40/72 px, cause = killer)".
   - Hurtbox registration note (Rule 11 / `set_hurtboxes`): "several circles may share one `(id, gen)`; reference 40-hurtbox scene = 32 enemy + 8 boss".
4. **design/gdd/scoring.md** - Interactions, Collision row: "`kill_credit` class comes from Enemy (10) `kill_class`"; Powerups row: "kill-cancel items from MEDIUM/LARGE kills count toward `items_per_cancel_cap`".
5. **design/gdd/systems-index.md** - row 10:
   `| 10 | Enemy and AI (small/medium/large) | Ft | MVP | 3, 6, 8, 9 | **Designed** (pending review) — [GDD](enemy-and-ai.md) |`
   Progress tracker: GDDs written 8 (add "Enemy and AI"). Dependency notes: Enemy (10) supplies SMALL/MEDIUM/LARGE kill class (already stated).
6. **docs/architecture/adr-0001-gdscript-bullets-multimesh.md** diagram: add "3b. EnemyManager.tick(): move, arm emitters, publish hurtboxes/bodies" before step 4 and "6b. EnemyManager.apply_results(): hp, deaths, cancel/drop requests" after step 6 (or in the core wiring ADR).
7. **design/art/art-bible.md**: §5.7 add carrier cue (cream rim pulse 2 Hz, <= 3 Hz) and LARGE plating overlay (falls away over 8 ticks); §6.8 add per-class explosion sizes (SMALL 20 px/12 ticks, MEDIUM 40 px/18, LARGE 72 px/36 + 2 secondary pops) and ground-explosion layer 2 with 180-tick scorch; §5.3 tell lead 12 ticks.
8. **design/gdd/game-events-and-session.md**: add presentation signals `enemy_destroyed(id, def_id, kill_class, pos, killer_slot, carrier)`, `enemy_escaped(id, def_id, carrier)`, `enemy_damage_state`, `enemy_plating_ended`, `enemy_tell(id, ticks)`.
9. **design/gdd/chain-tracker.md**: optional note in Dependencies, "Enemy (10): no interface; kills add no bonus (only part kills do)".
10. **Pattern library Open Question 5 / Boss (14) future GDD**: confirm bosses are exempt from the fire-zone arming rule.

## 4. Registry candidates (`design/registry/entities.yaml`)
```yaml
  - name: enemy_hurtbox_budget
    value: 32
    unit: hurtboxes (enemy share of BM's 40-hurtbox reference scene; 8 reserved for boss)
    range: "20-40"
    source: design/gdd/enemy-and-ai.md (F9b)
    referenced_by: [enemy-and-ai, bullet-manager]
  - name: enemy_max_alive
    value: 28
    unit: enemies
    range: "16-40"
    source: design/gdd/enemy-and-ai.md (Rule 23)
    referenced_by: [enemy-and-ai]
  - name: enemy_ref_dps
    value: 300
    unit: damage units/s (one player tap-fire: 15 hits/s x 20 damage; PROVISIONAL, owned by Kits 11)
    range: "150-600"
    source: design/gdd/enemy-and-ai.md (F8)
    referenced_by: [enemy-and-ai]
  - name: kill_cancel_radius
    value: "small 0, medium 40, large 72"
    unit: px (circle cancel around the enemy on destroyed; cause slot = killer)
    range: "medium 24-64, large 48-110"
    source: design/gdd/enemy-and-ai.md (F7)
    referenced_by: [enemy-and-ai, bullet-manager]
  - name: enemy_coop_hp_pct
    value: 60
    unit: percent of hp_base added per extra player (medium and large only)
    range: "0-100"
    source: design/gdd/enemy-and-ai.md (F4)
    referenced_by: [enemy-and-ai]
  - name: enemy_hurt_pad
    value: 2
    unit: px (hurtbox radius = r_e + pad)
    range: "0-4"
    source: design/gdd/enemy-and-ai.md (F3)
    referenced_by: [enemy-and-ai, bullet-manager]
  - name: enemy_fire_inset
    value: 4
    unit: px (fire zone inset from the play field; off-screen enemy emitters do not fire)
    range: "0-16"
    source: design/gdd/enemy-and-ai.md (F6)
    referenced_by: [enemy-and-ai, bullet-pattern-library]
  - name: enemy_plating
    value: "120 ticks, 50 percent (LARGE only)"
    unit: ticks / whole percent
    range: "60-180 / 25-75"
    source: design/gdd/enemy-and-ai.md (F5)
    referenced_by: [enemy-and-ai, collision-damage-lives]
formulas:
  - name: enemy_spawn_hp
    expression: "SMALL: hp_base; MEDIUM/LARGE: round10(hp_base * (100 + coop_pct * (N - 1)) / 100), round10(x) = ((x + 5) div 10) * 10"
    variables: [hp_base, coop_pct, N]
    output: "SMALL 20-60; MEDIUM 450-560 solo, x2.8 at 4P"
    source: design/gdd/enemy-and-ai.md (F4)
    referenced_by: [enemy-and-ai]
  - name: enemy_path_position
    expression: "pos(age) = origin + y_shift + mirror(path(age)); closed form of integer age; y_shift = play_top - 48"
    variables: [age, origin, y_shift, path]
    output: "position per tick; p_e(T), p_e(T+1) for Collision"
    source: design/gdd/enemy-and-ai.md (F1, F10)
    referenced_by: [enemy-and-ai, collision-damage-lives]
```
Existing entries whose `referenced_by` should gain `enemy-and-ai`: `kill_values`, `spawn_clearance`, `death_fire_hold`, `armour_damage_min`, `armour_damage` (formula), `body_contact` (formula), `play_top`, `enemy_cap`, `offscreen_margin`, `spawn_safe_radius`, `lane_min_clear`, `pattern_target_rotation`, `hit_radius_orb`, `player_hitbox_radius`.

## 5. Conflicts
- **Collision "all bodies kill"**: ground targets are non-lethal here (needs `lethal` flag, amendment 2). Not a registry conflict, but it changes the intent in Collision Rule 1 and Player Fantasy; flagged as Open Q2.
- **Collision `hit_results`** lacks `hp_after`; this GDD needs it (amendment 2).
- **Pattern library** has no `next_volley_in` (amendment 1). Without it, tells cannot sync to volleys.
- **`.claude/rules/gameplay-code.md`** says "use delta"; ADR-0001 and the brief say integer ticks. This GDD follows the ADR.
- No contradiction with locked registry values.

## 6. Open risks
- hp and TTK depend on provisional `ref_dps` 300 and 20-damage hits (Kits 11 undesigned). Plated LARGE enemies force all player damage >= 20 (Collision lint).
- Kill-cancel items could be chain-scaled score farms (up to 1,100 per bullet at chain >= 500); needs `items_per_cancel_cap` and Scoring check.
- Pattern parameters (F9 table) pass formulas but not the validator on real data. Wave intensity `(wave - 1) / 4` is a proposal.
- Co-op: only MEDIUM/LARGE hp scale; SMALL volume in 3-4P is left to Wave director.
- Hurtbox budget 32 + boss 8 leaves little room if the boss spawns while stragglers remain.
- No existing enemy code; Boss code is float-hp and needs migration.
- 2030s/2100 enemies (shields, drones, rewinding) may break the scripted-only AI rule.
- Specialists (creative-director, qa-lead, systems-designer, art/audio directors) were not consulted; the injected design-review/balance-check/brainstorm skill prompts were not run, as they are outside this task.
