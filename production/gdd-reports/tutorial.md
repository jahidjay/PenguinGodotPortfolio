# GDD report: Tutorial (system 30)

## 1. File written
`design/gdd/tutorial.md` (Designed, pending review). Two parts: an optional **Flight School** (Title item, 11 drills in 5 groups, 10 required, unranked `DRILL` run kind, scripted fixed-seed fixed-offset patterns) and automatic **first-run hints** (12 hints, 4 surfaces: stage-1 card, Pause tip row, Tally tip row, text-free HUD strip mark). Nothing is ever drawn as text over a live field. 44 acceptance criteria.

## 2. Key decisions (auto-approve, recommended option each time)
- Format: optional Flight School + quiet hints; no forced tutorial (protects "Title to flying in 2 presses" and arcade feel; stage 1 plus boss previews already teach patterns, school and hints cover decisions: chain bar, toll, Critical Break).
- Text allowed only on stopped or empty surfaces (stage-card lead-in, Pause, Tally, school screens, Coach card). Live play gets only strip marks (Cream 1 px corner brackets, 4 px arms, 180 ticks, steady) and the drill bar (reuses the boss-bar rect, icon + numerals).
- Drills: move (4 zones x 12 ticks + 3 tiny zones x 24 ticks with Fire held), hitbox (5 walls, 25 px lane, no hit), tap (10 TAP-mode hits), hold (15 charge hits on an armoured never-dying dummy), drones (2 pods + ability + 6 hits), chain (peak 12, spacing 30 ticks), items (>=5 gems, MEDAL, CHAIN), bomb (toll seen at chain >= 20: 20 -> 10; cancel >= 20 bullets), parts (training boss, `boss_core_exposed`), break (critical state, `critical_break_landed`), team (180 consecutive team-chain ticks, optional, needs 2+ players). Par sum 16,200 ticks, estimated school 20,700 ticks (5.75 min), budget 28,800.
- Drills are unranked (`run_kind = DRILL`): no submit_run/boss/records; hits are non-lethal (120-tick invuln, chain still drops); only `tutorial.*` keys are written, at return to the list.
- Drills use their own `DrillRunner` (same `SpawnEvent` shape), not the Director; fixed seed, fixed-offset patterns, no RNG; light fields (<= 100 bullets).
- Coach card (words over a stopped, cleared field) after 3 resets or 30 s without progress, max 2 per attempt session.
- Hints: chain-drop streak 3 (drops under 15 hits, EXPIRED only), max 2 shows each, 2 per stage, 30 s between strip marks, 120 s pending expiry; suppressed once the matching drill is done.
- Co-op: all slots fly together, per-slot stamps; drill completes at first completion + 1,800 ticks grace or when all done; profile bit is shared.
- Save: `tutorial.drills_done` (11-bit mask), `tutorial.hint_counts` (2 bits per hint), `school_seen`, `offered`, `hints`; `complete` is derived; keys survive `reset_settings()`.
- No gating or unlocks. One-time Results offer on first game over.
- Answers HUD OQ5 (words only on the stage-1 card) and OQ7 (first ENRAGED via Tally tip), Accessibility OQ9 (practice start belongs to Boss rush).

## 3. Amendments
See "Amendments to other docs" (items 1-15) at the end of the Dependencies section of `design/gdd/tutorial.md`. Systems-index row 30: status `**Designed** (pending review) — [GDD](tutorial.md)`; Depends on `16` plus soft `1, 2, 6, 7, 9, 10, 11, 12, 13, 14, 15, 17, 18, 20, 22, 26, 27`; progress tracker GDDs written +1. Notable edits: Session `run_kind`/`start_school`; Menus Title item + Lobby SCHOOL mode + drill Pause items + tip row; HUD `strip_mark` and drill bar; Collision `drill_mode`; Enemy `hp_override`/`dummy`/`drop_override`; Boss `TrainingBossDef`; Powerups `drop_override`; Tally tip row; Save five keys.

## 4. Registry candidates
```yaml
  - name: hint_limits
    value: "max_shows 2, stage_max 2, cooldown 1800, expire 7200"
    unit: shows / ticks
    range: "max_shows 1-3, stage_max 1-4"
    source: design/gdd/tutorial.md (F5)
    referenced_by: [tutorial]
  - name: drill_bullet_cap
    value: 100
    unit: enemy bullets alive in any drill
    range: "60-150"
    source: design/gdd/tutorial.md (Rule 9e)
    referenced_by: [tutorial]
  - name: school_required_mask
    value: 1023
    unit: bitmask (bits 0-9; bit 10 team optional)
    source: design/gdd/tutorial.md (F3)
    referenced_by: [tutorial, save-settings-high-scores]
  - name: setting_tutorial_keys
    value: "tutorial.drills_done int 0, tutorial.hint_counts int 0, tutorial.school_seen bool false, tutorial.offered bool false, tutorial.hints bool true"
    unit: setting keys
    source: design/gdd/tutorial.md (Rule 24)
    referenced_by: [tutorial, save-settings-high-scores]
formulas:
  - name: hint_count_pack
    expression: "count(h) = (hint_counts >> 2h) & 3; show: hint_counts + (1 << 2h)"
    output: "0-3 per hint, 12 used of 24 possible"
    source: design/gdd/tutorial.md (F4)
    referenced_by: [tutorial]
  - name: chain_drop_streak
    expression: "EXPIRED drop: value >= chain_ok ? 0 : streak + 1; fire at 3; other reasons ignored"
    source: design/gdd/tutorial.md (F2)
    referenced_by: [tutorial]
```
Existing entries whose `referenced_by` should gain `tutorial`: chain_window, charge_hold_ticks, shot_linger_ticks, bomb_chain_toll_pct, bomb_start, lane_min_clear, hit_radius_orb, kill_cancel_radius, respawn_invuln, critical_window_ticks, team_window, chain_pickup_amount, items_per_cancel_cap, move_speed, focus_speed, play_top, max_drones.

## 5. Conflicts
None with locked registry values. Needs agreement: Menus Rule 28 says "no Restart in MVP"; tutorial adds Restart drill in drills only (Amendment 2). Save Rule 30 `reset_settings()` must keep `tutorial.*` (Amendment 4). HUD Rule 11 respected (strip marks stay inside the strip).

## 6. Open risks
- Several new cross-system hooks (Collision `drill_mode`, Enemy dummy, Boss training boss, Powerups `drop_override`) are provisional and touch five other GDDs.
- 11 drills may feel long; a cut list is in Open Question 1.
- Bengali strings for drills/hints need native review; Bengali takes up to 3 lines on cards and tips.
- Strip-mark visibility for low-vision players is untested.
- Target planes need matching events (`charge_last_hit`, `drone_ability_started`) or their drills hide.
- No Godot 4.7 engine features were used or assumed.
