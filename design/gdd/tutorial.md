# Tutorial (Flight School and First-Run Hints)

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (ux-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (teaching never adds clutter to the field), Every Hit Counts (the school teaches the chain and the tiny honest hitbox; drills are unranked so no record is faked), Four Planes, Four Games (drills adapt to the plane flown), History Accelerates (hints reuse the boss previews the stage already shows)
> **Revision 2026-11-03 (final doc closeout, art-director amendments A1/A2)**: new Rule 16a - in 2P and Compact 48 the HUD carries no stamp rect, so the Flight School surface shows the per-slot DONE / SKIPPED (reusing the School-list stamp form); Rules 16, 21, 22 and Visual/Audio now cite HUD Rule 30b's stamp rects; UI cue ids normalised to the `sfx_ui_*` form (audio.md owns them).
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: `required_mask` is now a **per-plane** mask - fix (a) adopted, fix (b) rejected, no new drills authored for Sentry or Breaker (F3, Rule 12, Open Question 11 closed, Open Question 7 narrowed).
> **Revision 2026-11-03 (UX amendments wave 5)**: commit on leaving the School list to Title (Rules 16, 24, 25, AC-27); strip-mark clamp rect aligned with HUD Rule 30a (Rule 21, Visual/Audio); `tip_key` / `goal_key` must be plane-neutral or per-kit (Rule 13); `required_mask` reachability flagged for Sentry/Breaker (F3, Rule 12, Open Question 11).

## Overview

**The data layer:** the **Tutorial** has two parts that share one rule: *nothing is ever written over a live play field*.

1. **Flight School** is an optional mode started from the Title (a fifth list item, between START GAME and HIGH SCORES). It is a list of 11 bite-sized **drills** in 5 groups (Flight, Guns, Chain, Boss, Together). A drill is one `DrillDef` resource (`data/tutorial/drills/<id>.tres`): a scripted list of spawn events on integer ticks (the same `SpawnEvent` shape as the Wave director, Rule 3 there), a start state (drones, bombs, chain), and a **success condition** counted in ticks, hits or events. A node-free `DrillRunner` issues the events; a node-free `DrillTracker` reads the same events the HUD reads and counts progress per slot. Drills use the real game systems (real Collision, Chain, Kits, Bombs, Boss) with only three differences: hits are not lethal, the drill uses a fixed seed with fixed-offset patterns (so every attempt is the same), and nothing is ranked or stored except the drill-done bits.
2. **First-run hints** are a small rules engine (`HintEngine`, node-free, `tick()`) that watches the same event stream during a normal run and decides when a player is probably missing a concept. A hint (`HintDef`, `data/tutorial/hints/<id>.tres`) never appears over the field. It may appear on exactly four **surfaces**: the **stage card** (the 120-tick lead-in before wave 1, field empty), the **Pause tip row**, the **Tally tip row**, and a **strip mark** (a thin Cream bracket drawn around one HUD element, inside the reserved strip, no text). Hints are presentation only: they read events and never change simulation results.

Both parts are data-driven (`data/tutorial/`), tick-based at 60 Hz, free of `delta` and RNG (ADR-0001), and store their progress in Save as five `tutorial.*` keys.

**The player impact:** a new player who wants to fly presses START GAME and flies in two presses; nobody forces a lesson (the arcade promise of Menus). A new player who wants help picks Flight School and learns, in about 6 minutes at par, the eight things the game never explains in words mid-fight: move and slow down, the tiny hitbox, tap and hold Fire, drones, the chain, items, bombs and their toll, the boss parts and the Critical Break, and the team chain. A player who skips school still gets help: if they drop their chain three times in a row, the next Pause or Tally shows one short line and the chain bar gets a bracket for a few seconds. They are never stopped, never quizzed, and never shown the same tip more than twice.

## Player Fantasy

**Anchor moment: "Oh, that is what the bar is for."** A new player has dropped three small chains in a row. They pause. Below the Resume button a plated row shows the chain icon and one line: "Hit again before the bar runs out to keep your chain." They resume, and for three seconds a thin bracket sits around the chain bar. Their next kill lights the chain, the next hit holds it, and they keep it for the first time. Nobody told them what to do while bullets were live. Nothing flashed. They never opened a manual.

What it must feel like:
- **Arcade first.** The default path from Title to flying is still two presses. School is a door, not a gate.
- **A flight instructor, not a quiz.** Each drill has one idea, a number to reach, and a clear stamp when done. A failed attempt costs nothing but ten seconds.
- **Honest.** Drills use the real hitbox, real chain window and real bomb toll. A drill never shows a softer rule than the game has.
- **Respectful of the field.** In a live fight the only help is an icon, a numeral or a thin bracket in the HUD strip. Words wait for a pause, a tally or the stage card.
- **Together.** In co-op every player flies the drill at once, each with a stamp in their own column, and the "Together" lesson needs a friend.
- **Native.** Every card and tip is written for Bengali and English with the same layout.

**Anti-fantasy (must never happen):** a forced tutorial before the first run; a message over bullets; a hint that interrupts a boss; the same tip three times; a drill that teaches a rule the real game does not have (for example a free bomb with no chain toll); a drill that can only be passed by luck; a hint that needs colour to read; a school that takes more than 8 minutes at par; a locked mode or unlock behind completing school (no gating); a school score that lands on a leaderboard.

> `creative-director` and `art-director` not consulted (auto-approve). Visual limits follow `design/art/art-bible.md` §4.4, §7.4, §7.7, §7.8 and the HUD GDD.

## Detailed Design

### Core Rules

**Format and principles**

1. **Two parts, one rule (decided).** Flight School (optional mode) plus first-run hints (automatic, low volume). No forced tutorial run, no mandatory first stage lesson, no pop-up in a live field. *Why not a forced tutorial:* MorutJan promises "Title to flying in 2 presses" (Menus Player Fantasy) and arcade players expect to learn in stage 1; a forced lesson breaks that and punishes experts and returning players. *Why not only the stage:* the stage already teaches by sparse waves and boss previews (Wave director Rules 18-19, Boss power budget), but it cannot teach the chain bar, the bomb toll or the Critical Break set-up, which are decisions, not patterns. A short optional school plus quiet hints covers both.
2. **The no-text-over-field rule.** Tutorial text is allowed only on surfaces where the simulation is stopped or the field is empty of enemies and bullets: the stage card (lead-in, no spawns), the Pause panel, the Tally, the Flight School screens, and the Coach card (Rule 17). In a live field the only Tutorial output is a **strip mark** (Rule 21). *(Matches HUD Rule 11 and the banner rule of Wave director Rule 23.)*
3. **Teaching never changes score or ranks.** Drills are unranked (Rule 8). Hints and strip marks are presentation: the same recorded input gives the same `GameState` hash with hints on and off (AC-30).
4. **No gating.** Nothing in the game unlocks, locks or changes based on school progress. The progress bits only decide: the NEW tag on the Title item, the one-time Results offer, and which hints are suppressed (Rule 19).

**Flight School: flow**

5. **Entry.** Title item **FLIGHT SCHOOL** (`LINK`). Activating it opens the Lobby in `SCHOOL` mode (Menus Lobby rules 18-25 unchanged, banner key `tut.school.title`, no "Starting" bar). When every joined slot is Locked and `start_delay_ticks` has run, the Lobby calls `GameSession.start_school(selections)` (new, provisional) and opens the **School list**. A pointer-only start behaves like START GAME (Menus Rule 9).
6. **School list.** Five group headers and 11 drill rows, in this order (data order, `order` field):

| Bit | Group | Drill id | Row title (English source) | Required |
|---|---|---|---|---|
| 0 | Flight | `move` | Move and slow down | yes |
| 1 | Flight | `hitbox` | The tiny hitbox | yes |
| 2 | Guns | `tap` | Tap to shoot | yes |
| 3 | Guns | `hold` | Hold to charge | yes |
| 4 | Guns | `drones` | Pods and drones | yes |
| 5 | Chain | `chain` | Keep the chain alive | yes |
| 6 | Chain | `items` | Gems, medals and chain pickups | yes |
| 7 | Chain | `bomb` | Bombs and the chain toll | yes |
| 8 | Boss | `parts` | Boss parts and the core | yes |
| 9 | Boss | `break` | The Critical Break | yes |
| 10 | Together | `team` | The team chain | no (needs 2+ players) |

   Each row shows a stamp per joined slot (ring-pattern frame plus check glyph when done; colour is never the only cue). A row with `min_players` above the joined count is dimmed and shows a "2P" tag; Confirm on it plays `sfx_ui_deny` and shows a one-line reason. The list is shared (last input wins, like Title). Items below the rows: **Players** (returns to the Lobby in SCHOOL mode), **Reset progress** (`HOLD_BUTTON`), Back (Cancel). Cancel returns to Title. Focus starts on the first undone required row, else the first row.
7. **Drill lifecycle.** `Card` (Flight School screen: title, goal text, glyph row; Confirm starts, Cancel back) → `Ready` (`ready_beat_ticks` 60: the field loads, planes fly in, the three-pip beat of Menus Rule 30) → `Live` (the drill script runs) → `Done` (`done_beat_ticks` 90: a DONE stamp on each completed slot's column, field keeps running but no new spawns) → back to the list with the row stamped. Drills have **no lives, no game over and no continue**. A drill ends only by success, by Skip, or by leaving.
8. **Unranked (decided).** A drill session is `run_kind = DRILL` in Session (new field, Amendment 1). While `DRILL`: `submit_run` and `preview_rank` are never called; no board, record, best-chain or `one_credit_clear` is touched; Results, Tally, name entry and the continue prompt do not exist; Scoring and Chain still run so the player feels the real numbers, but nothing is stored. The **only** writes are the `tutorial.*` keys (Rule 24). `run_ended_by = ABANDONED`-style: Session reports `DRILL_END` and clears.
9. **Drill rules (all drills).**
   a. **Real rules, softer consequences.** Every system runs as in a stage (hitbox 3.0 px, `move_speed`, `focus_speed`, chain window, kit cooldowns, bomb lockout, bomb toll, armour). The only changes are in Rule 10.
   b. **No lethal hits (`drill_mode`).** Collision treats a player hit as: no life lost, no death, `request_invuln(slot, respawn_invuln)` (120 ticks), a `drill_hit(slot)` event to the tracker, the real hit tint and hit sound. Chain drops with reason DEATH exactly as for a death (the real consequence of a hit is felt: the chain falls). The hit is therefore *honest* but not punishing.
   c. **Start state is data.** `start_drones` (0-4), `start_bombs` (0-5), `start_chain` (0), refilled at each step start where the drill says so. Drones are written through Session as Powerups does; a drill ends with drones, bombs and chain cleared.
   d. **Fixed seed, no random.** The pattern seed is `hash(DRILL_SEED, drill_id, owner_id, emitter_index)` with `DRILL_SEED` a constant (Pattern library Rule 15), and every pattern in a drill uses fixed-offset mode (no seeded rotation or gap). The DrillRunner draws no random numbers. Two attempts at the same drill see the same bullets on the same ticks (AC-12).
   e. **Light fields.** A drill never has more than `drill_bullet_cap` (100) enemy bullets alive (checked by `DrillValidator`, F7 density method of the Wave director), at most 6 enemies alive and 1 boss. Every lane obeys `lane_min_clear` (14 px) for `play_top` 48 and 72.
   f. **Co-op.** All joined slots fly the drill together (Rule 22).
10. **Allowed drill-only controls (the complete list).** (1) Non-lethal hits (9b). (2) `drop_override` on a carrier (force POD, MEDAL or CHAIN so the lesson is never at the mercy of the drop table; Powerups amendment). (3) `hp_override` and an armoured, never-dying **dummy** target (Enemy amendment). (4) A **training boss**: the stage-1 Fortress layout with `drill_hp_pct` 25, boss fire limited to its preview-transform rows (Boss power budget F5, wave 1 row), and in `break` a pre-set critical state plus `cb_only` (Boss amendment). Nothing else is bent: no free bombs, no slowed chain window, no weaker bullets.

**Flight School: the drills**

11. **Drill table.** `T` = ticks, 60 per second. "Par" is the expected time for a competent first attempt, used only for the school length budget (F5). Success is counted per slot. A drill has no failure state: the counters in the "Resets when" column set progress back, and the script continues or repeats.

| Drill | Setup | Success condition (per slot) | Resets when | Par (T) |
|---|---|---|---|---|
| `move` | No enemies. Step A: four **zones** (square-cornered brackets, 40x40 px, r 20) at the field corners inset 36 px. Step B: three **tiny zones** (r 5) | A: stand in each of the 4 zones for 12 consecutive ticks, any order. B: stand in each of 3 tiny zones for 24 consecutive ticks **with Fire held** (focus speed 1.75 px/tick). | Dwell resets on leaving the zone, or (step B) on releasing Fire | 1,200 |
| `hitbox` | Wall pattern, 1 gap, spacing 15 px, orb speed 2 px/tick (120 px/s), one wall every 150 ticks, 5 walls; the hitbox ring is forced to opacity 100 | Pass 5 walls in a row with no hit: the wall crosses the plane's y with no `drill_hit` since it spawned. Clear lane of the gap is 25 px (F4) | A hit sets the pass count to 0 (the walls keep coming, 3 more walls are queued after the 5th) | 1,500 |
| `tap` | 3 trails of 4 `fodder` (SMALL), spacing 24 ticks, entering from the sides | 10 counted hits made while the kit is in **TAP** mode (Fire held less than `charge_hold_ticks` 18, or within `shot_linger_ticks` 12 of a tap) | none (hits only add) | 900 |
| `hold` | One **dummy** (MEDIUM role, hp 6,000, armoured 100 %, no weapons, never dies) hovering at (180, play_top + 150) | 15 counted hits in **charge mode** (`charge_last_hit` events: Lancer laser ticks, Leech focused shot) | none | 1,200 |
| `drones` | Start drones 0, bombs 0. Two carriers 180 ticks apart, `drop_override = POD`; then 6 `fodder` | Collect 2 pods (`drone_gained` twice, count 2), then press Drone with the ability accepted (`drone_ability_started`), then land 6 counted hits during the ability window | none | 1,500 |
| `chain` | Trails of 14 `fodder`, spacing 30 ticks (inside the 45-tick gap budget), alternating sides within `lane_reach_px` 157; a new trail starts every 600 ticks until success | Reach a chain count of 12 (peak, `chain_hit` events, no `chain_dropped(EXPIRED)` in between) | A drop (`EXPIRED` or `DEATH`) sets the progress to 0 | 1,500 |
| `items` | One MEDIUM (hp 1,200, solo scale) hovering, firing a ring of 8 orbs (speed 70 px/s) every 30 ticks; two carriers with `drop_override` MEDAL and CHAIN | Collect at least 5 gems (cancelled bullets, F6), 1 MEDAL and 1 CHAIN pickup (+10 chain) | none | 1,800 |
| `bomb` | Start bombs 3, refilled at each step. Step A: 18 `fodder` trail, spacing 30. Step B: two walls and a ring cluster that fill the field with at least 20 bullets | A: press Bomb with chain count of 20 or more and see the toll applied (`chain_reduced`, F2). B: press Bomb while at least 20 enemy bullets are alive and cancel at least 20 of them, with no `drill_hit` during the bomb | A: none. B: a hit before the bomb restarts the cluster 120 ticks later | 2,400 |
| `parts` | Training boss, the first 240 ticks are the real boss intro | Destroy every non-core part (`boss_part_destroyed(..., last)` then `boss_core_exposed`) | none | 2,400 |
| `break` | Training boss in the **critical state**: parts gone, core in the critical window (`critical_window_ticks` 420), bombs 3 | A `critical_break_landed(slot)` for this slot | Window ends without a break: the boss reappears in the critical state after 120 ticks (`cb_only`: the core cannot die from shots) | 1,800 |
| `team` | 2+ players. Training boss with parts and core | A team chain running **180 consecutive ticks** (`team_chain_started` to `team_chain_ended`), counted for the team | `team_chain_ended` before 180 ticks resets the streak | 1,800 |

12. **Per-plane notes.** The success conditions use kit events, not plane names, so both MVP planes use the same table. `hold` and `break` read `charge_active` / `charge_last_hit` (Plane kits) and `cb_armed` (Critical Break). Target planes (Sentry, Breaker) must publish the same events; a plane without one marks its drill `available = false` and the row is hidden (→ Open Question 7). **Resolved (2026-11-03, wave 5 batch 2):** hiding a row no longer strands `complete`. F3's `required_mask` is **evaluated per plane** (`1023 & available_mask(plane)`), so a drill a plane cannot trigger is **not required on that plane**, and a Sentry-only or Breaker-only pilot can still finish the school. **No plane-specific replacement drills are authored** for the hidden rows - that option was rejected. A missing event is still a Kits defect to fix (Open Question 7), just not a blocker for the school flag (Open Question 11 closed).
13. **Teaching order and text.** Each drill's card carries: a title, a **goal** (one or two short lines, the thing to achieve in numbers: "Hit 10 times with taps"), three button glyphs showing which controls the drill uses (Fire / Drone / Bomb, glyph family of the slot, Input F8), and a hidden **tip** (Rule 17). Text lengths: title at most 28 characters English, goal at most 80, tip at most 90. **`goal_key` and `tip_key` text must be plane-neutral** (2026-11-03, wave 5): the four kits charge and fire differently (Lancer laser, Leech focused shot, Sentry **Entrench**, Breaker **Breach**), so no drill string may name one kit's mechanic ("the laser burns" is wrong for three of the four). Either write the line in kit-neutral words ("hold Fire to charge, then release") or add **per-kit keys** (`tut.drill.<id>.tip.<kit>`) and let the Card pick by the slot's plane; the Coach card (Rule 17) uses the same resolved key. Bengali is laid out on measured width and may take up to 3 lines (Localization edge case), reserve 40 % (`bn_width_reserve_pct`).
14. **Skip.** A drill may be skipped from its Card (Cancel back to list), and from Pause (**Skip drill**, `HOLD_BUTTON`, 60 ticks). Skipping sets nothing. There is no "skip school" step: leaving school is Cancel.
15. **Pause in a drill.** Pause items: **Resume**, **Restart drill**, **Settings**, **Skip drill**, **Quit to list** (Menus Rules 27-33 apply; no "score will not be saved" line, since nothing is at stake; Restart drill is allowed in drills only). The resume beat (45 ticks) applies.
16. **Done.** When the condition holds for a slot, that slot shows a DONE stamp on its column (HUD Rule 30b; in 2P and Compact 48 the HUD has no stamp rect and the Flight School surface carries it instead, Rule 16a) and `ui` jingle `sfx_tut_drill_done`; the slot keeps flying. The drill ends by Rule 22. On the return to the list, Menus calls `commit_settings()` once (calm moment, Save Rule 20). **Amended 2026-11-03 (wave 5):** Menus **also** calls `commit_settings()` once when the player leaves the School **list to the Title** while any `tutorial.*` key is dirty (typically `school_seen`, set on opening the list, or `hint_counts`). Without this trigger a player who only browses the list and backs out would see the NEW tag again after a restart (Rule 25a; Save Rule 20 commit triggers).
16a. **Per-slot DONE / SKIPPED when the HUD cannot show a stamp (decided 2026-11-03, art-director A2).** The HUD's in-strip stamp is a 16x11 rect that exists only in the 1P and 3-4P layouts; `hud_layout_2p` and `hud_layout_compact48` set `stamp = none` because no free 16x11 block exists there (HUD Rule 30b). In those two modes the **Flight School surface itself carries the per-slot result**: through the Done beat (Rule 7, `done_beat_ticks` 90) and on the return to the list, Flight School shows **one stamp per joined slot** using the School-list stamp form already specified in Visual/Audio (14x14 icon in that slot's ring-pattern frame: check glyph = DONE, dash glyph = SKIPPED, empty frame = not attempted), one per joined slot in slot order, and the per-slot `sfx_tut_drill_done` cue still plays on each slot's completion. No new colour, hex or strip rect is introduced, and nothing is drawn over the live play field. In 1P and 3-4P the HUD stamp remains the per-slot signal and this surface row is redundant but harmless.
17. **Coach card (decided).** A drill never shows words while `Live` except through this one exception: when a slot has had `coach_after_fails` (3) progress resets without progress in between, or `coach_after_ticks` (1,800) ticks with no progress change, the drill **pauses**, clears enemy bullets (`clear_all`, no items), and shows the **Coach card** (the drill's tip text and a Resume button) over the stopped field, like a Pause panel (art bible §7.8 exception, Amendment 8). After Resume the 45-tick beat runs and the fail counters reset. At most `coach_max` (2) cards per drill attempt session; the third time the tip is only on the Card. In co-op the card opens for the whole group and its text names no slot.
18. **Drill progress display (no words).** The HUD's boss-bar rect (24,37,312,10 in the strip) becomes a **drill bar** when no boss is alive: a stepped Cream fill with the target notch, the drill's group icon in the left zone (0,36,24,12) and `n/N` numerals in the right zone (336,36,24,12) in tier D10 (digits follow the language, `Localization.format_int`). In boss drills (`parts`, `break`, `team`) the boss bar is shown as normal and the progress is the boss state itself (part-kill icon and count, ARMED lamp, team bracket).
19. **Hints and school progress.** A hint has a `drill_ref`. If the `drill_ref` bit is set in `tutorial.drills_done`, that hint never triggers (the player has been taught it).
20. **Re-doing.** Done drills can be replayed; replay never clears a bit. **Reset progress** (hold) zeroes `tutorial.drills_done` and `tutorial.hint_counts` and clears `tutorial.school_seen` and `tutorial.offered`.
21. **Strip mark (decided).** The HUD draws a **strip mark** on request: `HUD.strip_mark(slot, element_id, ticks)`. It is four Cream (`#F4EBD6`) corner brackets, each arm 4 px long and 1 px thick, drawn 2 px outside the element's rect **clamped to the column's mark clip rect** (x from the column origin + 4, in 2P up to x 355 for P2; y from 0 to the row limit, 36 in 48 px strips or 59 in 72 px strips; a clamped side sits **on** the clip edge - HUD Rule 30a owns the clamp), steady (no pulse, no blink, no fade faster than 1 Hz), at the HUD draw slot (art bible §6.8 layer 11, inside the strip). Element ids: `chain_plate`, `chain_bar`, `kit_bar`, `drone_lamp`, `drone_pips`, `bomb_icons`, `lives_icons`. The strip mark is a separate element from the DONE / SKIPPED stamp, whose rects HUD Rule 30b owns ((224,4,16,11) in 1P, (73,16,16,11) per column in 3-4P, `stamp = none` in 2P and Compact 48). One mark per slot at a time; a new one replaces the old. Duration `strip_mark_ticks` (180). Marks never overlap the play field (the strip is outside it, HUD Rule 5a).

**Drill co-op**

22. **Group drills.** All joined slots fly at once, each with its own counters. A drill is **complete** when at least one slot has completed it and (every joined slot has completed it, or `coop_grace_ticks` (1,800) have passed since the first completion) (F5). On completion the field stops spawning; slots that did not finish see their column marked SKIPPED (a dash glyph, HUD Rule 30b; in 2P and Compact 48 on the Flight School surface instead, Rule 16a) and keep flying through the Done beat. A slot that has not finished does **not** get its DONE stamp. The profile bit is set at completion (one shared profile, no accounts). `team` needs `joined >= 2`; if a player leaves during it (`forfeit_slot`) so `joined` becomes 1, the drill restarts as a Card for the remaining player and cannot complete.
23. **No mid-drill join.** During `Ready`/`Live`/`Done` a free device's Start press shows `sfx_ui_deny` and the toast "Players can join from the list". Joining happens in the Lobby (via **Players**).

**Save and progress**

24. **Keys (Save schema, Amendment 4).**

| Key | Type | Default | Range | Meaning |
|---|---|---|---|---|
| `tutorial.drills_done` | int bitmask | 0 | 0 to 2,047 (11 bits); extra high bits preserved | Bits per Rule 6 |
| `tutorial.hint_counts` | int, 2 bits per hint | 0 | 0 to 2^48 - 1 | Times each hint was shown, 0-3 (F4) |
| `tutorial.school_seen` | bool | false | | Player has opened school (hides the NEW tag) |
| `tutorial.offered` | bool | false | | The one-time Results offer was shown |
| `tutorial.hints` | bool | true | | Hints on or off (presented in Settings and Accessibility) |

   `tutorial.complete` is **derived**, not stored: `(drills_done & required_mask(plane)) == required_mask(plane)` for any plane, where `required_mask(plane) = 1023 & available_mask(plane)` (F3; **per-plane since 2026-11-03, wave 5 batch 2** - `drills_done` itself stays one profile-wide bitmask). All five keys are profile keys: `reset_settings()` keeps them (like `profile.last_initials`).
25a. **NEW-tag persistence (2026-11-03, wave 5).** `tutorial.school_seen` is set the moment the School list opens, and it is **committed** both on the return from a drill and on leaving the list to the Title while the profile is dirty (Rule 16). Opening the list once therefore clears the NEW tag permanently, with no drill completed.
25. **Offer (decided).** (a) Until `tutorial.school_seen`, the FLIGHT SCHOOL Title item carries a NEW tag (text plus a star glyph; static); it clears on the first commit after the list is opened (Rule 25a). (b) The first time a run ends in GAME_OVER with `tutorial.offered == false` and `tutorial.complete == false`, the Results screen shows one footer line "New? Try Flight School from the title." and sets `tutorial.offered`. (c) Nothing else: no pop-up on first boot, no prompt in the Lobby.

**First-run hints**

26. **Hint list (MVP of Target; data).** Each hint has an index `h` (0-11, the pack position in F4), a trigger, surfaces and a `drill_ref`. "Run" means a normal run (`run_kind = RUN`). Hints only exist in real runs; there are none in school, attract or menus.

| h | Id | Trigger (all must hold) | Surfaces (in order tried) | Drill ref |
|---|---|---|---|---|
| 0 | `stage1_primer` | `stage_started` for stage 1 and `tutorial.complete` is false | Stage card | none |
| 1 | `chain_drops` | Chain-drop streak reaches 3 (F2) | Strip mark (`chain_bar`) then Pause tip, Tally tip | `chain` (5) |
| 2 | `hold_fire` | Wave 1 and 2 of stage 1 have ended and the slot never held Fire for 18 or more ticks | Strip mark (`kit_bar`), Pause tip, Tally tip | `hold` (3) |
| 3 | `drone_button` | The slot has had 1 or more drones for 1,200 ticks and never had a Drone press accepted | Strip mark (`drone_lamp`), Pause tip, Tally tip | `drones` (4) |
| 4 | `pod_missed` | A POD expired (`item_expired(POD)`) while every Active slot had 0 drones | Tally tip, Pause tip | `drones` (4) |
| 5 | `bomb_toll` | The first `chain_reduced` from a bomb toll in this profile (`hint_counts[5] == 0`) | Tally tip, Pause tip | `bomb` (7) |
| 6 | `bomb_saves` | The slot died twice in the run while holding 1 or more bombs | Strip mark (`bomb_icons`, on the respawn tick), Pause tip | `bomb` (7) |
| 7 | `focus_dodge` | The slot died twice in the run having not held Fire in the 30 ticks before each death | Pause tip, Tally tip | `move` (0) |
| 8 | `break_missed` | A Critical window (`critical_window_ticks`) ended with no break, the slot had 1 or more bombs | Tally tip | `break` (9) |
| 9 | `enrage_icon` | The first `boss_enraged` in this profile | Tally tip | `parts` (8) |
| 10 | `team_chain` | `N >= 2`, a boss fight of 1,200 or more ticks ended and no `team_chain_started` occurred | Tally tip | `team` (10) |
| 11 | `boss_echo` | Pause opened while the boss is alive and at least one `mechanic_previewed` fired this stage | Pause tip (arg: the previewed mechanic's `name_key`) | none |

27. **Surfaces.**
    - **Stage card:** drawn during `lead_in_ticks` (120) on stage 1 only (`stage1_primer`): three icon rows (Move / Fire / Bomb glyphs of the first joined slot with one short word each) on a Char plate centred over the empty field. No enemy exists in the lead-in (Wave director Rule 12). Removed when wave 1 starts. It resolves HUD Open Question 5 (icon-only HUD in play; words only here).
    - **Pause tip row:** one plated row (icon + up to two lines) under the Pause items, shown only if a hint is pending and eligible. It does not take focus.
    - **Tally tip row:** one line in the Tally footer, shown only if a hint is pending and eligible. The Tally owns the position (Tally amendment).
    - **Strip mark:** Rule 21. Never carries text.
28. **Pending and show rules (F5).** When a trigger fires, the hint becomes **pending** for that slot. The engine shows at most one hint per surface opening: the pending eligible hint with the lowest `priority` (then lowest `h`). Strip marks may also fire on their own at the trigger time (if the hint lists them first), subject to the cooldown. A hint counts as **shown** when its surface first draws (not at trigger time). Rules: a hint shows at most `hint_max_shows` (2) times in the profile; at most `hint_stage_max` (2) hints show per stage; at least `hint_cooldown_ticks` (1,800 game ticks) pass between two strip marks; a pending hint expires after `hint_expire_ticks` (7,200) game ticks, or when the run ends, and then does **not** count as shown.
29. **Hints off.** `tutorial.hints = false` clears pending hints on the next tick and stops the engine. School is unaffected.
30. **Co-op hints.** Triggers are evaluated per slot; the strip mark appears in the triggering slot's column; Pause and Tally tips are shared (one hint per opening). A hint's profile count is incremented once per show, not per slot.
31. **Mechanic names.** `boss_echo` shows the previewed mechanic's `name_key` (Boss power budget `MechanicDef.name_key`), localised, so the tip reads, for example, "This boss uses {name} - you saw it in wave {n}".

**Data and tick order**

32. **Data (→ ADR for autoload ownership).** `data/tutorial/tutorial_rules.tres` (all knobs), `drills/*.tres` (`DrillDef`), `hints/*.tres` (`HintDef`). A `DrillDef` has: `id`, `bit`, `group`, `order`, `title_key`, `goal_key`, `tip_key`, `glyph_ids[]` (up to 3), `min_players`, `planes[]` (empty = all), `start` (`drones`, `bombs`, `chain`), `events[]` (`SpawnEvent`, plus `drop_override`, `hp_override`, `dummy`), `repeat_every_ticks` (0 = none), `steps[]` (each a `SuccessDef`), `par_ticks`. A `SuccessDef` has `kind` (`ZONES`, `WALLS_CLEAN`, `EVENT_COUNT`, `CHAIN_PEAK`, `ITEM_SET`, `BOMB_TOLL`, `BOMB_CANCEL`, `BOSS_STATE`, `TEAM_STREAK`), integer parameters, and `reset_on` (a list of event names). A `HintDef` has: `id`, `h`, `priority`, `trigger` (kind plus ints), `surfaces[]`, `icon_id`, `strip_target`, `text_key`, `drill_ref`, `max_shows`. All fields are ints, strings, bools, arrays and dictionaries; no floats.
33. **Tick order.** `DrillRunner` ticks with the Director's step (before Enemy spawns). `DrillTracker` and `HintEngine` tick after all gameplay systems and before the HUD, so a strip mark requested on tick T is drawn on tick T. They tick only with the game (paused: frozen). `DrillValidator` and `HintValidator` are unit tests over `data/tutorial/` (AC-01 to AC-05).
34. **Debug.** Development builds: a `tutorial.hint_force(id)` command, a drill skip, and an overlay showing pending hints, counts, streaks and the tracker counters.

### States and Transitions

**School session**

| State | Meaning | → Next | Trigger |
|---|---|---|---|
| Closed | not in school | Lobby | Title: FLIGHT SCHOOL |
| Lobby | players join and lock (SCHOOL mode) | List / Closed | all Locked and 45 ticks / last slot cancels |
| List | drill rows, stamps | Card / Lobby / Closed | Confirm on a row / Players / Cancel |
| Card | goal text and glyphs | Ready / List | Confirm / Cancel |
| Ready | field loads, pip beat (60 ticks) | Live | beat done |
| Live | drill runs; Pause may open; Coach card may open | Done / List | success (Rule 22) / Quit to list, Skip |
| Done | stamps, no new spawns (90 ticks) | List | beat done; `commit_settings()` |

**Drill step** (inside Live): `Step n active` → (`SuccessDef` met for the slot) → `Step n+1` or `Slot done`; a `reset_on` event sets the active step's counters to 0 (the step index never goes back).

**Hint** (per hint, per profile run): `Idle` → (trigger) `Pending` → (surface opens, eligible) `Shown` (count + 1) → `Idle`; `Pending` → (expire, run ends, hints off) `Idle` without a count. `Idle` stays until trigger again, while `count < hint_max_shows`.

### Interactions with Other Systems

| System | Direction | Interface (provisional unless the other system has a GDD) |
|---|---|---|
| Game events and session (1) — GDD | ↔ | New `start_school(selections)` and `run_kind` (`RUN`, `DRILL`); `DRILL_END` reason; drills set `drone_count`, `bombs` through Session like Powerups and Bombs do; reads `stage_started`, `stage_index`, slot states, `N`, `run_kind`. Amendment 1 |
| Menus, title and plane select (22) — GDD | ↔ | Title item and NEW tag, Lobby SCHOOL mode, School list and Card screens, Pause drill items, Pause tip row, Results offer line, Coach card plate. Amendment 2 |
| HUD (20) — GDD | → | `strip_mark(slot, element_id, ticks)`; drill bar mode on the boss-bar rect; DONE stamp and SKIPPED glyph in a column. Answers HUD Open Questions 5 and 7. Amendment 3 |
| Stage-end tally (21) — GDD | → | Tally tip row and its reserved footer position |
| Collision, damage and lives (6) — GDD | → | `drill_mode`: non-lethal hit with `request_invuln(slot, 120)` and `drill_hit(slot)`. Amendment 5 |
| Enemy and AI (10) — GDD | → | `spawn` with `hp_override`, `dummy` (armoured 100 %, never dies, no weapons, no drops), `drop_override`; `max_life_ticks`. Amendment 6 |
| Boss and boss parts (14) — GDD | → | Training boss: `drill_hp_pct` 25, preview-row fire, `start_state = CRITICAL`, `cb_only`; reads `boss_part_destroyed`, `boss_core_exposed`, `boss_enraged`. Amendment 7 |
| Boss power budget (15) — GDD | ← | `mechanic_previewed`, `MechanicDef.name_key`, preview transform rows (wave 1 row for the training boss) |
| Wave and stage director (16) — GDD | ← | `stage_started`, `wave_ended`, `mechanic_previewed`, `lead_in_ticks`. DrillRunner is separate and does not use the Director (Rule 32) |
| Bullet pattern library (9) — GDD | ← | Wall, Ring, Aimed fan with fixed-offset mode; fixed seed. `lane_min_clear` validator reused by `DrillValidator` |
| Chain tracker (7) — GDD | ← | `chain_hit`, `chain_dropped(slot, value, reason)`, `chain_reduced`, `count`, `team_chain_started`, `team_chain_ended` |
| Plane kits and drones (11) — GDD | ← | `charge_active`, `charge_last_hit`, tap/charge mode, `drone_ability_started`, `drone_denied`, `drone_gained` |
| Bombs (12) — GDD | ← | `bomb_used(slot)`, `bomb_denied`, the toll formula, cancel counts |
| Critical Break (17) — GDD | ← | `cb_armed(slot)`, `critical_break_landed(slot, ...)`, critical window start and end |
| Powerups and drops (13) — GDD | ↔ | ← `item_collected_ex`, `item_expired`, `drone_gained`. → `drop_override` (Amendment 9) |
| Co-op and Team Chain (18) — GDD | ← | `N`, `team_window`, team chain events, `coop_hp_scale` (drills apply `drill_hp_pct` after it) |
| Input and player mapping (2) — GDD | ← | Slot glyph family (F8), `nav`, Confirm, Cancel, `held_ticks`, `fire_held` (for the focus zone and `focus_dodge`) |
| Save, settings and high scores (26) — GDD | ↔ | Five `tutorial.*` keys; `commit_settings()` on return to the list; keys survive `reset_settings()`. Amendment 4 |
| Localization (27) — GDD | ← | `text`, `text_both`, `format_int`, `font_size_px`; key family `tut.*` in `ui_tutorial.csv`; glyph tokens as arguments (convention added to Localization, Amendment 13, wave 4) |
| Accessibility options (28) — GDD | ↔ | Presents `tutorial.hints`; text size step reflows cards and tip rows; `untimed_menus` has no effect in drills (no timers in drills except the Critical window, which is the real rule) |
| Audio (24), VFX (25) — GDD | → | Cue ids `sfx_tut_drill_done`, `sfx_tut_coach_open`. No new VFX |
| Display scaler (4) — GDD | ← | Canvas host, `play_top` layout by player count |
| Touch controls (31) — GDD | ← | On touch, glyph tokens follow the device in use (touch glyphs, art bible 7.6); drills are solo (TOUCH is slot 0 only); the three first-run touch hints stay Touch's (Touch Rule 33) (2026-11-03, wave 4) |

> Decided under auto-approve (2026-11-03): optional Flight School plus quiet first-run hints (no forced tutorial); text only on stopped or empty surfaces, strip marks without text in live play; Coach card after 3 resets or 30 s; 11 drills in 5 groups, `team` optional; unranked `DRILL` run kind, hits non-lethal but chain still falls; fixed-seed fixed-offset patterns; DrillRunner separate from the Director; progress stored as bitmask, derived complete flag; no gating or unlocks; hints at most 2 shows each, 2 per stage; drills restart-able but not game-over-able; co-op group completes at first completion plus 1,800 ticks; Results offer once.

## Formulas

**F1. Drill bar fill**

`fill_px = (bar_inner * min(progress, goal)) div goal`; the displayed numerals are `min(progress, goal)` and `goal`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Bar inner width | `bar_inner` | int px | 310 (fixed by HUD HF3) | Interior of the boss-bar rect |
| Progress | `progress` | int | 0 up | Counter of the active step |
| Goal | `goal` | int | 1-60 | Target of the active step |

**Output Range:** 0 to 310 px, whole pixels, stepped (no tween). **Example:** goal 12 (`chain`), progress 5: `310 * 5 = 1550`, `1550 div 12` = **129** px, numerals `5/12`. Progress 14: capped at 12, fill 310.

**F2. Chain-drop streak (hint `chain_drops`)**

`streak' = 0 if (reason == EXPIRED and value >= chain_ok) else streak + 1 if (reason == EXPIRED and value >= 1) else streak`; fire when `streak' >= chain_streak_trigger`. DEATH, LEFT, STAGE_END and toll drops neither count nor reset.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Drop value | `value` | int | 1-999 | `last_dropped` from `chain_dropped` |
| Good chain | `chain_ok` | int hits | 8-40 (15) | A drop at or above this is a "good" chain and resets the streak |
| Trigger | `chain_streak_trigger` | int | 2-5 (3) | Consecutive small drops before the hint |

**Output Range:** `streak` 0 to `chain_streak_trigger`; the hint fires on the tick the streak reaches the trigger and the streak resets to 0 afterwards. **Example:** drops 4, 2, 6 (all EXPIRED): streak 1, 2, 3 → fires. Drops 4, 18, 3: streak 1, 0, 1 → no hint. Drops 4 (EXPIRED), 3 (DEATH), 5 (EXPIRED): streak 1, 1, 2.

**F3. School complete (derived flag)**

`required_mask(plane) = 1023 & available_mask(plane)` ; `complete(plane) = (drills_done & required_mask(plane)) == required_mask(plane)` ; `complete = OR over planes of complete(plane)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Done bits | `drills_done` | int | 0-2,047 | Save key; high bits preserved on write |
| Available mask | `available_mask(plane)` | int | 0-2,047 | One bit per drill whose Rule 12 `available` flag is **true for that plane** (the plane publishes the kit events the drill reads) |
| Required mask | `required_mask(plane)` | int | 0-1,023 | `1023 & available_mask(plane)`. Bit 10 (`team`) is optional and is masked out of the requirement on every plane |

**Output Range:** bool. **Example (a plane with all ten drills available, `required_mask` = 1023):** `drills_done` = 1023 → complete. = 1024 (only `team`) → not complete. = 2047 → complete. = 1022 (bit 0 missing) → not complete. **Example (a plane that cannot publish the events of bits 3 and 6, so `available_mask` clears them and `required_mask` = 1023 - 8 - 64 = 951):** `drills_done` = 951 → **complete on that plane**; the same `drills_done` is **not** complete on a plane whose mask is 1023.

**Resolved 2026-11-03 (wave 5 batch 2; raised by the Flight School UX review, amendment 3).** A **fixed** `required_mask` of 1,023 was unreachable for a pilot who only flies Sentry or Breaker, because Rule 12 hides the drills whose kit events those planes do not publish (`available = false`). Of the two candidate fixes, **(a) the per-plane mask is adopted** and **(b) authoring plane-specific equivalent drills is rejected** - no new drills are written for Sentry or Breaker. What that means in detail:

- `required_mask` is **not a constant**. It is **evaluated per plane**: a drill is required on a plane only if that plane can actually trigger it. Bit 10 (`team`) stays optional everywhere.
- `drills_done` remains **one profile-wide bitmask**. A drill cleared on the Lancer counts on every plane; the per-plane part is only *which bits are demanded*, never *which bits are stored*. The Save key, its width and its high-bit preservation are unchanged (Rule 24).
- The single derived flag `tutorial.complete` - the one Rule 25(b) and the Title NEW tag read - is true when `complete(plane)` is true for **any** plane, so a Sentry-only or Breaker-only profile can reach it by clearing the drills its kit can actually do. **Known looseness, accepted:** a Lancer pilot who happens to clear exactly the subset a Breaker could clear also counts as complete. That is cheaper than a per-plane save key and nobody is blocked by it.
- In **MVP** both planes (Lancer, Leech) publish every event the ten drills read, so `available_mask` is 2,047, `required_mask` is 1,023 on both, and **nothing about MVP behaviour changes**. The formula only bites once a Target plane with a missing event ships.
- **Hints** (Rule 19, F5): a hint gated on `NOT bit(drill_ref(h))` whose drill is **not available to the slot's plane** can never have that bit cleared by that pilot, so the bit test alone would keep it eligible for ever. It still **settles on the `hint_max_shows` cap** (2 shows, F4), which is the real terminator; the `drill_ref` gate is an early-out, not the only one. No extra rule is needed, and the hint is **not** suppressed - a pilot who cannot drill the thing is exactly the pilot who should see the hint twice.
- A plane that *should* publish an event and does not is still a **Kits bug**, tracked as Open Question 7; the per-plane mask stops it from bricking `complete` but does not excuse it.

**F4. Hint count pack (2 bits per hint)**

`count(h) = (hint_counts >> (2 * h)) & 3`; `show(h)`: if `count(h) < 3` then `hint_counts' = hint_counts + (1 << (2 * h))`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Packed counts | `hint_counts` | int | 0 to 2^48 - 1 | Fits the exact JSON integer range of Save (2^53 - 1) with up to 24 hints |
| Hint index | `h` | int | 0-23 (0-11 used) | Position in the table (Rule 26) |

**Output Range:** `count` 0-3 (the engine stops at `hint_max_shows` 2; the third slot value is a guard). **Example:** `hint_counts` = 18 = binary 010010: `count(0)` = 2, `count(1)` = 0, `count(2)` = 1. `show(1)`: 18 + 4 = 22, `count(1)` = 1. `show(0)` at count 2 is refused by `hint_max_shows`.

**F5. Hint eligibility and drill completion**

Hint: `eligible(h, t) = hints_on AND count(h) < hint_max_shows AND NOT bit(drill_ref(h)) AND stage_shown < hint_stage_max AND (not a strip mark OR t - last_mark_tick >= hint_cooldown_ticks) AND t - trigger_tick(h) < hint_expire_ticks`

Group drill: `complete = completed >= 1 AND (completed == joined OR t - first_done_tick >= coop_grace_ticks)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Max shows | `hint_max_shows` | int | 1-3 (2) | Shows per hint in the profile |
| Stage cap | `hint_stage_max` | int | 1-4 (2) | Hints shown per stage |
| Cooldown | `hint_cooldown_ticks` | int ticks | 900-3,600 (1,800) | Between strip marks |
| Expire | `hint_expire_ticks` | int ticks | 3,600-14,400 (7,200) | Game ticks a pending hint waits |
| Completed / Joined | `completed`, `joined` | int | 0-4 | Slots done / slots in the drill |
| Grace | `coop_grace_ticks` | int ticks | 600-3,600 (1,800) | Wait after the first completion |

**Output Range:** bool. **Example (hint):** `chain_drops` triggers at tick 3,000 (count 0, stage 1 shown 0, last mark never), pause opens at 3,400: eligible, shown (count 1). Triggers again at 9,000 and the player pauses at 9,100 with stage_shown 1: shown (count 2). A third time: `count` is 2, refused. **Example (drill):** 3 slots, P1 done at tick 1,000, P2 at 1,500, P3 never: `completed` = 2 of 3; the drill completes at 1,000 + 1,800 = **2,800**. If P3 finishes at 2,000, it completes at 2,000.

**F6. Cancel gems in `items` (design check)**

`gems = ring_count * (1 + (age + interval <= floor(r_cancel / v_tick)))`, `age` in `0 .. interval - 1` = age of the freshest ring at the dummy's death; `v_tick = v / 60`; `r_cancel = kill_cancel_radius[MEDIUM] = 40`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Ring size | `ring_count` | int | 8 | Orbs per ring |
| Ring interval | `interval` | int ticks | 30 | Ticks between rings |
| Orb speed | `v` | int px/s | 70 (`v_min`) | Speed of the ring orbs |
| Cancel radius | `r_cancel` | int px | 40 | Medium kill cancel radius |

**Output Range:** 8 or 16 gems (below `items_per_cancel_cap` 100). **Example:** `v_tick` = 70 / 60 = 1.1667 px/tick, so `floor(40 / 1.1667)` = 34 ticks. The freshest ring (age 0 to 29) is always inside: 8 gems. The previous ring (age + 30) is also inside only when `age + 30 <= 34`, i.e. `age <= 4`: 16 gems. Goal is 5, so the step always passes with one kill. *(Orbs are about 53 alive at steady state, under `drill_bullet_cap` 100.)*

**F7. Hitbox lane (drill `hitbox`)**

`lane_clear = (gap_slots + 1) * spacing - 2 * hit_radius_orb`, required `lane_clear >= lane_min_clear`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Gap slots | `gap_slots` | int | 1-2 (1) | Missing slots in the wall |
| Spacing | `spacing` | int px | 12-20 (15) | Distance between wall orb centres |
| Orb radius | `hit_radius_orb` | px | 2.5 (locked) | Registry |
| Minimum lane | `lane_min_clear` | px | 14 (locked) | Registry |

**Output Range:** 14 or more px. **Example:** `(1 + 1) * 15 - 2 * 2.5` = **25** px, margin 11 px over `lane_min_clear` and about four times the 6 px hitbox. The wall has 24 slots, 23 orbs; two walls alive at once (256-tick travel at 2 px/tick, one wall per 150 ticks) = 46 bullets.

**F8. School length budget**

`school_est = sum(par_i for required drills) + n_req * (ready_beat_ticks + done_beat_ticks + read_est_ticks)`; must be `<= school_max_ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Par ticks | `par_i` | int | 900-2,400 | Per drill (Rule 11) |
| Required drills | `n_req` | int | 10 | Bits 0 to 9 |
| Ready / Done beats | `ready_beat_ticks`, `done_beat_ticks` | int | 60 / 90 | Rule 7 |
| Reading estimate | `read_est_ticks` | int | 300 | 5 s to read a card |
| Max length | `school_max_ticks` | int | 28,800 (8 min) | Budget |

**Output Range:** under 28,800. **Example:** sum of par = 1,200 + 1,500 + 900 + 1,200 + 1,500 + 1,500 + 1,800 + 2,400 + 2,400 + 1,800 = **16,200**; overhead `10 * (60 + 90 + 300)` = 4,500; `school_est` = **20,700** ticks = 345 s = 5.75 min, with 8,100 ticks (2.25 min) spare.

> Decided under auto-approve (2026-11-03): all defaults listed in Tuning Knobs. 3 drops and 15 hits for a "good chain" because wave-1 trails give about 8 to 14 hits; 2 shows and 1,800-tick cooldown so a struggling player gets help without nagging; 100 bullets for drills is between the wave 2 and wave 3 curve caps (80 and 100).

## Edge Cases

**School and drills**
- **If the player presses Cancel on a Card**, the list returns with focus on that row and nothing changes.
- **If a drill's Live phase ends in Skip or Quit to list**, no bit is set, the field is cleared (`clear_all`, `despawn_all`), and the list opens.
- **If a hit lands during the Ready beat**, it cannot: planes are non-hittable until Live (`respawn_invuln` style) and `drill_hit` is not raised.
- **If a hit lands on the same tick the success condition becomes true**, success wins (the hit is still logged and the chain drops).
- **If a counted hit comes from a teammate in a co-op drill**, it counts for the slot that fired it only (shot owner), as in Collision.
- **If a Leech player does `tap` and holds Fire past 18 ticks**, the charge-mode hits do not count for `tap`; progress is not reset (Rule 11).
- **If the dummy in `hold` reaches 1 hp**, it stays at 1 (armoured 100 %, Collision C4) and keeps taking and counting hits; it never drops items or explodes.
- **If a carrier is killed by a teammate in `drones`**, the pod is a normal pickup and either slot may collect it (Powerups tie-break); each slot's `drone_gained` count is its own.
- **If a slot reaches 4 drones in `drones`**, the pod is overflow (Powerups Rule 22) and counts as a MEDAL; the step needs only 2 pods, so a 2-pod count is never blocked.
- **If `items` has no gems because the MEDIUM died with no ring in range** (cannot happen at `interval` 30; guard), the drill re-spawns the MEDIUM after 120 ticks.
- **If the training boss dies by shots in `parts`**, the drill still succeeds on `boss_core_exposed`; the boss is not required to die.
- **If the Critical window ends in `break` with a bomb in flight**, the Critical Break rules apply (the break lands or not by Critical Break Rule 12); a break that lands counts, a window that ends first resets the step (boss respawns critical after 120 ticks, bombs refilled to 3).
- **If a slot has 0 bombs in `bomb` step B or `break`**, the tracker refills bombs to `start_bombs` at each reset.
- **If a player drops a controller in a drill**, the disconnect overlay and Input rules apply (Menus Rule 32); "Drop P{n}" removes the slot from the drill and from the completion count.
- **If the last slot is dropped**, the school session returns to the Title.
- **If the Coach card opens while Pause is requested**, the Pause menu waits one tick, then opens over the card (Coach card closes first).
- **If a drill is opened for a plane with no `charge_last_hit` event** (Target planes before their GDD), the row is hidden (Rule 12).
- **If the language changes on a Card or Coach card**, text re-renders on the next frame.
- **If Save is unavailable or read-only**, drills work; bits stay in memory for the session; Menus shows "Progress will not be saved" once (Save Rule 28).
- **If `tutorial.drills_done` has bits above 10 set** (newer build), they are preserved on write and ignored for completion.

**Hints**
- **If two hints trigger on the same tick**, both become pending; the lower `priority` (then lower `h`) shows first; the other waits for the next surface opening.
- **If a hint is pending when the run ends**, it is dropped without a count.
- **If the player pauses while a strip mark is showing**, the mark stays and its 180-tick timer is paused with the game (HUD does not tick while paused).
- **If a hint's text key has no Bengali string**, the English string shows (Localization Rule 4); the lint flags it in the data check.
- **If `tutorial.hints` is turned off in Pause settings**, the Pause tip row disappears on the next frame; pending hints are cleared.
- **If the Pause tip row would be the only content below Resume and the text size step is 3**, the row grows downward; the panel scrolls (Menus Rule 51).
- **If a Tally has no hint pending**, the tip row is absent and the footer prompt line is unchanged.
- **If the run is `assisted` (Accessibility Rule 23) or in the Practice state**, hints still show; they do not change the ranking state.
- **If `stage1_primer` shows on a continue or restart of stage 1**, it shows only once per run: the engine marks it shown at the first stage card of the run.
- **If two players share a hint trigger (both die twice)**, one pending hint exists; the strip mark appears in the first-triggering slot's column (lowest slot on a tie).
- **If a slot leaves the run**, its pending strip marks are cancelled; shared tips remain.
- **If a run is ABANDONED while a hint is shown**, nothing is written beyond the already-counted show.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | `run_kind`, `start_school`, events, `drone_count` / `bombs` writes, `N`, slot states. |
| Wave and stage director (16) — GDD | Soft | `stage_started`, `lead_in_ticks`, `mechanic_previewed`, `wave_ended`. School does not need it; hints do. |
| Chain tracker (7) — GDD | Hard | Events listed in Interactions. |
| Plane kits and drones (11) — GDD | Hard | Charge, tap, drone events. |
| Bombs (12) — GDD | Hard | `bomb_used`, toll, cancel counts. |
| Critical Break (17) — GDD | Hard for `break` | `cb_armed`, `critical_break_landed`. |
| Boss and boss parts (14) — GDD | Hard for the Boss group | Training boss options and part events. |
| Boss power budget (15) — GDD | Soft | Mechanic ids and `name_key`, preview rows. |
| Powerups and drops (13) — GDD | Hard for `drones`, `items` | `drop_override`, item events. |
| Bullet pattern library (9) — GDD | Hard | Fixed-offset Wall, Ring, Fan; validator. |
| Enemy and AI (10) — GDD | Hard | `hp_override`, `dummy`, `drop_override`. |
| Collision, damage and lives (6) — GDD | Hard | `drill_mode`. |
| Co-op and Team Chain (18) — GDD | Hard for `team` | Team chain events, `N`. |
| HUD (20) — GDD | Hard for strip marks and drill bar | `strip_mark`, drill bar mode. |
| Menus, title and plane select (22) — GDD | Hard | Title item, Lobby SCHOOL mode, list, Pause. |
| Save, settings and high scores (26) — GDD | Soft | Five keys; without Save, progress lives in memory. |
| Localization (27) — GDD | Hard | Strings, numerals, text sizes. |
| Input and player mapping (2) — GDD | Hard | Glyph family, nav, held buttons. |
| Display scaler and bezel (4) — GDD | Soft | Canvas and `play_top`. |
| Touch controls (31) — GDD | Soft | Touch glyphs; solo on touch; touch hints stay Touch's. |
| Stage-end tally (21) — GDD | Soft | Tip footer row. |
| Accessibility options (28) — GDD | Soft | Presents `tutorial.hints`; text sizes. |
| Art bible | Hard (document) | §4.4, §6.8, §7.4, §7.7, §7.8. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Menus (22) | Soft | Hosts school screens, tip row, Results offer |
| HUD (20) | Soft | Receives strip-mark and drill-bar requests |
| Stage-end tally (21) | Soft | Hosts the tip row |
| Save (26) | Soft | Stores `tutorial.*` |
| Accessibility (28) | Soft | Shows `tutorial.hints`; Open Question 9 (practice start) is answered here |
| Audio (24) | Soft | Cue ids `sfx_tut_drill_done`, `sfx_tut_coach_open` |
| Online leaderboards and Boss Rush (32) — [GDD](online-leaderboards-boss-rush.md) | Soft | Practice start = Single Boss with a game-speed assist (owned by 32); not part of school. Drills never upload (`run_kind = DRILL`). |

**Bidirectional check:** Session, Menus, HUD, Tally, Collision, Enemy, Boss, Powerups, Wave director, Boss power budget, Chain tracker, Kits, Bombs, Critical Break, Co-op, Input, Save, Localization and Accessibility name Tutorial (30) as a soft or provisional dependency already (see the grep list in the report) or receive it in the amendments.

**Amendments to other docs** (applied 2026-11-03, wave 4; see `production/gdd-reports/_applied-wave-4.md`)

1. `design/gdd/game-events-and-session.md`: Rule 1 and Run-flow: add `run_kind` (`RUN` default, `DRILL`) and `start_school(selections)`; while `DRILL`, `preview_rank`/`submit_run` are never called, no Results/Tally/continue, `run_ended_by = DRILL_END`; Session UI Requirements: Flight School owned by Tutorial (30) through Menus (22); Interactions row Tutorial (30): "run_kind, start_school, drone_count/bombs writes in drills".
2. `design/gdd/menus-title-plane-select.md`: (a) Title items add **FLIGHT SCHOOL** between START GAME and HIGH SCORES, NEW tag until `tutorial.school_seen`; (b) Lobby `SCHOOL` mode; (c) screens `school_list`, `drill_card`, `coach_card` in `menu_screens.tres`; (d) Pause items in a drill: Resume, Restart drill, Settings, Skip drill (HOLD), Quit to list; (e) Pause tip row and Results offer line (footer, GAME_OVER only, once); (f) Open Question 6/Dependencies: Tutorial (30) now has a GDD.
3. `design/gdd/hud.md`: (a) add `strip_mark(slot, element_id, ticks)` (Tutorial Rule 21); element ids list; (b) drill bar mode on the boss-bar rect and DONE/SKIPPED glyph in a column; (c) Open Question 5: closed ("icon-only in play; words on the stage card for stage 1 only, Tutorial Rule 27"); Open Question 7: closed ("first ENRAGED explained by a Tally tip, hint `enrage_icon`"); Dependencies row Tutorial (30): "Highlights HUD elements by id" -> add GDD link.
4. `design/gdd/save-settings-high-scores.md`: Rule 16 schema add the five `tutorial.*` keys (Rule 24 table); Rule 30: `reset_settings()` also keeps `tutorial.*`; Rule 20 triggers add "Flight School drill complete (return to the list)"; Dependencies add Tutorial (30).
5. `design/gdd/collision-damage-lives.md`: add `drill_mode` (Session `run_kind == DRILL`): a player hit raises `drill_hit(slot)`, calls `request_invuln(slot, respawn_invuln)`, drops the chain with reason DEATH, never removes a life or kills; Dependencies add Tutorial (30).
6. `design/gdd/enemy-and-ai.md`: spawn params `hp_override`, `dummy` (armoured 100 %, never dies, no weapons, no drops, still takes counted hits), `drop_override`; used by drills only (lint: a stage may not set them).
7. `design/gdd/boss-and-boss-parts.md`: `TrainingBossDef` options (`drill_hp_pct` 25 applied after `coop_hp_scale`, fire limited to preview-row patterns, `start_state = CRITICAL`, `cb_only`: after `critical_window_ticks` the core cannot die from shots); event `boss_enraged` documented; Dependencies add Tutorial (30).
8. `design/art/art-bible.md` §7.8: extend the "Pause and Disconnect panels while the game is stopped" exception to the **Coach card**; §7.2: the stage card may carry the `stage1_primer` icon rows during the lead-in; note the strip mark bracket (Cream, 1 px, 4 px arms) as a HUD-layer element.
9. `design/gdd/powerups-and-drops.md`: spawn param `drop_override` (POD, MEDAL, CHAIN) bypasses the drop table and pity counter, drills only; Dependencies row Tutorial (30) now has a GDD.
10. `design/gdd/wave-and-stage-director.md`: Interactions row Tutorial (30): `stage_started`, `mechanic_previewed`, `lead_in_ticks` (stage card), no calls into the Director; Dependencies row link.
11. `design/gdd/stage-end-tally.md`: reserve a one-line **tip row** in the footer (Tutorial Rule 27), absent when no hint is pending.
12. `design/gdd/accessibility-options.md`: present `tutorial.hints` in the Settings list; Open Question 9: "practice start at a chosen stage or boss is not part of school (Tutorial); Boss rush (32) owns it"; Dependencies row Tutorial (30) link.
13. `design/gdd/localization.md`: add `ui_tutorial.csv` (key family `tut.*`: `tut.school.*`, `tut.drill.<id>.title/goal/tip`, `tut.hint.<id>`) and the glyph-token argument convention; Dependencies row Tutorial (30).
14. `design/gdd/bombs.md`, `critical-break.md`, `chain-tracker.md`, `plane-kits-lancer-leech.md`, `coop-and-team-chain.md`, `boss-power-budget.md`, `input-and-player-mapping.md`: change the Tutorial (30) row "not yet" to "GDD: tutorial.md", and publish the event names used (see Interactions: `bomb_used`, `chain_reduced`, `charge_last_hit`, `drone_ability_started`, `critical_break_landed`, `team_chain_started`/`ended`, `mechanic_previewed`).
15. `design/gdd/systems-index.md`: row 30 status `**Designed** (pending review) — [GDD](tutorial.md)`; Depends on `16` stays and add soft `1, 2, 6, 7, 9, 10, 11, 12, 13, 14, 15, 17, 18, 20, 22, 26, 27`; Progress tracker GDDs written +1.

## Tuning Knobs

All in `data/tutorial/tutorial_rules.tres` unless noted; no magic numbers in code (ADR-0001).

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `hint_max_shows` | 2 | 1-3 | Hint missed once and gone | Nagging | F4, F5 |
| `hint_stage_max` | 2 | 1-4 | Needed hints queue forever | Pause/Tally clutter | F5 |
| `hint_cooldown_ticks` | 1,800 | 900-3,600 | Strip marks stack | Hint arrives too late | F5; `strip_mark_ticks` |
| `hint_expire_ticks` | 7,200 | 3,600-14,400 | Hint gone before a pause | Stale advice | F5 |
| `strip_mark_ticks` | 180 | 120-300 | Missed | Bracket becomes noise | HUD arbiter |
| `chain_ok` | 15 | 8-40 | A weak 8-hit chain counts as good | Every normal drop counts as small | F2; wave-1 chain length |
| `chain_streak_trigger` | 3 | 2-5 | Fires on bad luck | Player gives up first | F2 |
| `coach_after_fails` | 3 | 2-5 | Coach on a single slip | Player frustrated | Rule 17 |
| `coach_after_ticks` | 1,800 | 900-3,600 | Interrupts thinkers | Stuck players wait | Rule 17 |
| `coach_max` | 2 | 1-3 | No second chance | Repeats | Rule 17 |
| `coop_grace_ticks` | 1,800 | 600-3,600 | A slow friend is skipped | Group waits | F5 |
| `ready_beat_ticks` / `done_beat_ticks` | 60 / 90 | 30-90 / 60-180 | Hands not ready / stamp unseen | Slow loop | F8 |
| `read_est_ticks` | 300 | 180-600 | Underestimates school length | Overestimates | F8 |
| `school_max_ticks` | 28,800 | 21,600-36,000 | Validator rejects good drills | School too long | F8 |
| `drill_bullet_cap` | 100 | 60-150 | Drills too thin | Not "light" | Wave curve cap (80 / 100) |
| `drill_hp_pct` (training boss) | 25 | 15-50 | Boss falls too fast to teach | Drill exceeds par | Boss F6 hp budget |
| Drill goals (`tap` 10, `hold` 15, `chain` 12, `items` gems 5, `bomb` cancel 20, `team` 180) | see Rule 11 | +-50 % | Concept not demonstrated | Drill drags | Kit rates, F6 |
| `dwell_zone` / `dwell_tiny` | 12 / 24 | 6-24 / 12-48 | Walk-by passes | Tedious | `focus_speed` |
| `hitbox` wall interval / walls | 150 / 5 | 120-240 / 3-8 | Tight / dull | | F7 |
| `tap_hits`, `hold_hits` | 10 / 15 | 6-20 / 8-30 | | | Kit shot rates (Lancer 3, Leech 6 ticks) |

**Owned elsewhere (read, not owned):** `chain_window` 60, `bomb_chain_toll_pct` 50, `bomb_start` 3, `charge_hold_ticks` 18, `shot_linger_ticks` 12, `lane_min_clear` 14, `critical_window_ticks` 420, `kill_cancel_radius` medium 40, `respawn_invuln` 120, `team_window` 60, `move_speed` / `focus_speed`, `hold_confirm_ticks` 60, `resume_beat_ticks` 45, `lead_in_ticks` 120, `items_per_cancel_cap` 100.

## Visual/Audio Requirements

All art follows the art bible. No tutorial element is drawn over the live play field in a way that hides a bullet; bullets always win.

**Drill zones** (`move`): square-cornered brackets, four corner ticks of 6 px arm, 1 px, Cream `#F4EBD6`; zone sizes 40x40 px (r 20) and 10x10 px (r 5, step B); the zone fills with a 25 % Cream tint on the plane's dwell (stepped by quarter, no pulse). Draws on the ground layer below the enemy-bullet layer 8 (layer 7 or lower). Never Void Indigo or Ink; never a ring or circle (circle with a core pip is the reserved ring bullet).

**Strip mark** (Rule 21): four corner brackets, 4 px arms, 1 px, Cream, 2 px outside the element and clamped to the column's mark clip rect (HUD Rule 30a), HUD layer 11, steady. Removed instantly at the end of its 180 ticks (no flash). Under `access.reduce_pulsing` and `reduce_flashing` no change (it is already steady).

**Drill bar** (Rule 18): the boss-bar rect (24,37,312,10), fill Cream, target notch at the end, stepped fill per F1; left zone icon 12x12 (group icon: wing, gun, chain, bomb/boss, two-planes), right zone numerals D10.

**DONE stamp** (a column): the HUD's 16x11 stamp asset (3 px border, 10x5 interior; DONE = Cream border and check glyph, SKIPPED = `#A89E8A` border and dash) at the layout's `stamp` rect - (224,4,16,11) in 1P and (73,16,16,11) per column in 3-4P; shown 90 ticks, no flash (HUD Rule 30b owns the asset and the rects). In 2P and Compact 48 the layout sets `stamp = none` and the Flight School surface shows the per-slot result instead (Rule 16a). School list stamps: 14x14 icon per slot in ring-pattern frame; undone is an empty frame; the same form is reused for the Rule 16a surface row.

**Drill card (School screens)** inside the 360x640 canvas on the neutral warm hangar backdrop (art bible §2): card plate at (16, 120, 328, 360); title M tier; goal S tier, two lines (Bengali up to three); three 16x16 glyph tokens in a row; Confirm and Back plates at least 24 px high. Focus indicator is the 3 px Cream border plus arrow (Menus Rule 13). Text outline 1 px, contrast 7:1 or better.

**Coach card:** a compact plate over the stopped field (Pause panel style), 296x120 px, tip text S tier, one Resume button. Field behind is not tinted (Menus Rule 49).

**Stage card primer** (stage 1 lead-in): Char plate centred, three rows of 16x16 glyph + one short word each (Move, Fire, Bomb), shown for the 120 ticks of `lead_in_ticks`. **Pause tip row / Tally tip row:** plate row, 14x14 icon + up to two S-tier lines (three Bengali), a 1 px `#5A5148` edge (high-contrast theme: Cream).

**Audio (ids owned by Audio 24):**

| Cue | Trigger | Notes |
|---|---|---|
| `sfx_tut_drill_done` | a slot's drill completes | Short rising two-note, 20 frames; max 1 per tick; a quiet cue so it never covers weapon sounds |
| `sfx_tut_coach_open` | Coach card opens | Uses the `sfx_ui_pause` sound family |
| `sfx_ui_confirm`, `sfx_ui_cancel`, `sfx_ui_deny` | List and Card | Menus table; ids owned by audio.md |
| (none) | Strip mark, hints | Silent on purpose: no new sound competes with the 8-voice bullet pool |

Visual twin rule: every sound has a visual (DONE stamp, card plate).

## UI Requirements

Tutorial adds UI in: Title (item and NEW tag), School list, Drill card, Coach card, Lobby SCHOOL banner, Pause (drill items and tip row), Tally (tip row), Results (offer line), HUD (strip mark, drill bar, DONE stamp), and the stage card (primer). All obey the accessibility checklist: keyboard-only and gamepad-only usable (Menus verbs only); text via `font_size_px(tier, step)` and measured layout; colour never the only cue (ring pattern, check glyph, word DONE); no flashing; strings by key; digits via `format_int`.

Debug tools: pending-hint overlay, forced hint, drill skip, tracker counters, `DrillValidator` report.

📌 **UX Flag**: run /ux-design for the Flight School list and Drill/Coach cards, and for the hint surfaces (stage card primer, Pause tip row, Tally tip row, strip mark) before writing epics.

## Acceptance Criteria

**Defaults used:** `hint_max_shows` 2, `hint_stage_max` 2, `hint_cooldown_ticks` 1,800, `hint_expire_ticks` 7,200, `strip_mark_ticks` 180, `chain_ok` 15, `chain_streak_trigger` 3, `coach_after_fails` 3, `coach_after_ticks` 1,800, `coach_max` 2, `coop_grace_ticks` 1,800, `ready_beat_ticks` 60, `done_beat_ticks` 90, `read_est_ticks` 300, `school_max_ticks` 28,800, `drill_bullet_cap` 100, `drill_hp_pct` 25, required mask 1,023; registry values `chain_window` 60, `bomb_chain_toll_pct` 50, `charge_hold_ticks` 18, `lane_min_clear` 14, `respawn_invuln` 120, `kill_cancel_radius` medium 40.

**Test setup:** node-free `DrillRunner`, `DrillTracker`, `DrillValidator`, `HintEngine` and `HintValidator` (`RefCounted`) are driven with injected tick counts and scripted event lists; there is no RNG in any of them (a seeded RNG is injected only into the fake Enemy and Pattern stubs so the tests can prove it is never called). Tests live in `tests/unit/test_tutorial_drills.gd`, `test_tutorial_hints.gd`, `test_tutorial_data.gd`, in `extends SceneTree` style like `tests/unit/test_chain_tracker.gd`. Numbers are read from `data/tutorial/tutorial_rules.tres` and `data/tutorial/drills/*.tres`, not hard-coded. Manual items use a dev build with a pad and a keyboard.

**Data and validators**
- **AC-01 [Unit] (Rule 32):** all drill and hint resources load; there are 11 drills with bits 0-10 unique, 12 hints with `h` 0-11 unique; every field is int, string, bool, array or dictionary (no float). A missing key logs one data warning.
- **AC-02 [Unit] (Rule 9e, F7):** `DrillValidator` computes the clear lane of every wall and ring in every drill for `play_top` 48 and 72; all are >= `lane_min_clear` (14). `hitbox` gives 25 px. A drill with a 13 px lane fails the validator.
- **AC-03 [Unit] (Rule 9e):** the concurrent enemy bullet estimate of every drill is <= `drill_bullet_cap` (100) and enemies alive <= 6; `hitbox` estimate is 46.
- **AC-04 [Unit] (Rule 9d):** every pattern in every drill is fixed-offset; the validator rejects a seeded rotation, a seeded wall gap or any `randf` call (stub RNG call count must be 0 across a full simulated drill).
- **AC-05 [Unit] (F8, Rule 11):** `school_est` for the shipped drills is 20,700 and <= `school_max_ticks` 28,800; adding 8,200 ticks of par makes the validator fail.
- **AC-06 [Unit] (Rule 13):** every `DrillDef` and `HintDef` text key exists in `ui_tutorial.csv` for both `en` and `bn`; English length limits hold (title <= 28, goal <= 80, tip <= 90, hint line <= 90); a missing `bn` is reported as a warning (fallback allowed).

**Drill rules**
- **AC-07 [Unit] (Rule 9b):** in `drill_mode`, a hit on slot 0 leaves `lives` unchanged, calls `request_invuln(0, 120)` once, emits `drill_hit(0)`, and the chain drops with reason DEATH when it was > 0.
- **AC-08 [Unit] (Rule 8):** while `run_kind == DRILL`, `submit_run`, `preview_rank` and Save record writes are never called (spy count 0); `run_ended_by == DRILL_END` and the session clears.
- **AC-09 [Unit] (Rule 11, `move`):** zone r 20 at (36, 84): a plane at (45, 93) (d^2 = 162) is inside; at (50, 100) (d^2 = 452) is outside. 12 consecutive inside ticks set the zone; leaving on tick 11 resets the dwell to 0. A tiny zone (r 5) dwell counts only on ticks with Fire held; 24 consecutive ticks needed.
- **AC-10 [Unit] (Rule 11, `hitbox`):** five walls passed with no `drill_hit` since each spawned give success on the tick the 5th wall crosses the plane's y; a hit at wall 4 sets the pass count to 0 and queues walls so 5 more can still be passed.
- **AC-11 [Unit] (Rule 11, `tap`):** 10 counted hits only in TAP mode count; 12 hits made in charge mode leave progress at 0; the 10th TAP hit completes the step.
- **AC-12 [Unit] (Rule 9d, determinism):** running the same drill twice with the same scripted input gives identical spawn logs (hash equal) and identical `DrillTracker` counters per tick; changing `DRILL_SEED` changes nothing as no random choice exists in the drills.
- **AC-13 [Unit] (Rule 11, `hold`):** the dummy (hp 6,000, armoured 100 %) receives 30 laser hits of 60 and stays alive; progress is the number of `charge_last_hit` events (15 completes); a tap hit does not count.
- **AC-14 [Unit] (Rule 11, `drones`):** two `drone_gained` events (count 2), then `drone_ability_started`, then 6 counted hits within the ability completes; a press while `drone_denied(NO_DRONES)` does not progress; at 4 drones a POD is a MEDAL and the 2-pod count is still reachable.
- **AC-15 [Unit] (Rule 11, `chain`):** a trail with spacing 30 ticks keeps the chain; 12 hits with no `chain_dropped(EXPIRED)` completes; a drop at 9 hits sets progress to 0; a drop with reason STAGE_END is not possible in a drill.
- **AC-16 [Unit] (F6, `items`):** with ring 8, interval 30, speed 70 px/s and a MEDIUM dying at ring age 10, the cancel gives 8 gems; at age 3 it gives 16; the step needs >= 5 gems, 1 MEDAL, 1 CHAIN (+10 chain via `add_bonus`).
- **AC-17 [Unit] (Rule 11, `bomb`, F2):** pressing Bomb at chain 20 gives `chain_reduced` 20 -> 10 (toll 50 %) and completes step A; at chain 19 it does not complete step A; step B needs >= 20 bullets cancelled with no `drill_hit` in the bomb's 90 ticks.
- **AC-18 [Unit] (Rule 11, `parts`):** `boss_part_destroyed(..., last = true)` followed by `boss_core_exposed` completes; the boss need not die; `drill_hp_pct` 25 reduces each part hp to 25 % after the co-op scale (1,200 -> 300 solo; at 2P 1,800 -> 450).
- **AC-19 [Unit] (Rule 11, `break`):** `critical_break_landed(slot)` completes; a window that ends first resets the step and respawns the boss in the critical state after 120 ticks with bombs 3; the core cannot die by shots.
- **AC-20 [Unit] (Rule 11, `team`):** a team chain of 179 ticks then `team_chain_ended` resets the streak; 180 consecutive ticks completes; with `joined == 1` the row is dimmed and cannot start.
- **AC-21 [Unit] (Rule 17):** three resets without progress open the Coach card (the drill pauses, `clear_all` is called, no items); 1,800 ticks with no progress change also opens it; a third request in the same session shows no card; Resume plays the 45-tick beat and zeroes the fail counters.

**Co-op, flow and Save**
- **AC-22 [Unit] (Rule 22, F5):** joined 3, P1 done at tick 1,000, P2 at 1,500, P3 never: the drill completes at tick 2,800; P3 shows SKIPPED; the bit is set. If P3 finishes at tick 2,000, it completes at 2,000.
- **AC-23 [Unit] (Rule 22):** a player dropped during `team` makes `joined` 1: the drill returns to its Card for the remaining player and cannot complete.
- **AC-24 [Unit] (Rule 23):** a Start press from a free device during Live shows `sfx_ui_deny` and the toast; the joined set is unchanged.
- **AC-25 [Unit] (F3, Rule 24):** `drills_done` 1,023 -> complete; 1,024 -> not; 2,047 -> complete; 1,022 -> not; a write preserves bit 11+ that was present at load.
- **AC-26 [Unit] (Rule 24):** `reset_settings()` keeps all five `tutorial.*` keys; Reset progress (hold) zeroes `drills_done`, `hint_counts`, `school_seen`, `offered`.
- **AC-27 [Unit] (Rules 16, 25a):** `commit_settings()` is called once when the list opens after a completed drill; it is also called once when the player leaves the School list to the Title with `school_seen` or `hint_counts` dirty (open the list, back out, restart -> no NEW tag); it is not called again when nothing is dirty; no write occurs during Live ticks (spy on the file backend).
- **AC-28 [Unit] (Rule 25):** `school_seen` false -> Title item shows NEW; opening school sets it. First GAME_OVER with `offered` false and not complete shows the offer line and sets `offered`; the second GAME_OVER does not; ENDING never shows it.

**Hints**
- **AC-29 [Unit] (F2):** drops [4, 2, 6] (EXPIRED) fire `chain_drops` on the third; [4, 18, 3] do not; a DEATH drop between does not change the streak; the streak resets to 0 after firing.
- **AC-30 [Integration] (Rule 3):** a recorded 3,600-tick input is run twice, with hints on and off, with strip marks and tips enabled; the per-tick `GameState` hash sequence is identical.
- **AC-31 [Unit] (F4):** `hint_counts` 18: `count(0)` 2, `count(1)` 0, `count(2)` 1; `show(1)` gives 22; `show(0)` at count 2 is refused by `hint_max_shows`.
- **AC-32 [Unit] (F5, Rule 28):** `chain_drops` pending at tick 3,000, pause opens at 3,400: shown, count 1. A second strip mark within 1,800 ticks of the last is refused; at `trigger + 7,200` the pending hint expires with no count.
- **AC-33 [Unit] (Rule 28):** two hints pending at one Pause opening: only the lowest `priority`, then `h`, shows; the other remains pending; 3 hints already shown in a stage: none show (`hint_stage_max` 2 stops at 2).
- **AC-34 [Unit] (Rule 19):** with the `chain` bit set, `chain_drops` never triggers; with it cleared it does.
- **AC-35 [Unit] (Rule 26):** each trigger in the table fires on its stated event sequence and not on near misses: `hold_fire` after waves 1-2 with no 18-tick hold fires; with one 18-tick hold it does not; `bomb_toll` fires on the first toll event only; `team_chain` needs `N >= 2` and 1,200 fight ticks.
- **AC-36 [Unit] (Rule 29):** `tutorial.hints = false` clears pending hints within 1 tick and no surface requests a hint after; school is unchanged.
- **AC-37 [Unit] (Rule 27):** the primer shows only for stage 1 while `complete` is false, at most once per run, and is removed by wave 1; there is no enemy alive during it (spy on Enemy count 0).
- **AC-38 [Unit] (Rule 21):** a strip mark request returns the element rect plus 2 px outset; a new mark for the same slot replaces the old one; the mark ends after exactly 180 game ticks (paused ticks do not count).

**Surfaces, text and accessibility**
- **AC-39 [Integration] (Rule 2):** during Live play (any state with enemies or bullets alive), the Tutorial adds no text to any draw layer in the play field; only strip marks and zone brackets exist (scene-tree scan for Label/RichText nodes under the field root: count 0).
- **AC-40 [Manual] (Rules 13, 27):** Bengali and English cards and tips render without clipping at text-size steps 0 and 3, 360x640 and 4x; Bengali takes at most 3 lines; no hint text overflows the Pause panel.
- **AC-41 [Manual] (Accessibility checklist):** all School screens, Card, Coach card and tips are fully usable with keyboard only and with gamepad only; every state has a non-colour cue (ring pattern, check glyph, the word DONE); nothing flashes (no brightness change faster than 1 Hz).
- **AC-42 [Manual] (Rule 21, art bible):** with bullets on screen, the strip mark does not cover any bullet, enemy or plane pixel; zone brackets sit under layer 8; no shape is a ring or uses Void Indigo / Ink.
- **AC-43 [Manual] (Fantasy):** a first-time player (no gaming-community knowledge) completes the 10 required drills in <= 10 minutes of real time without help; a returning player pressing START GAME reaches flying in 2 presses and sees no tutorial prompt.

**Performance**
- **AC-44 [Perf] (Rule 33):** `DrillRunner.tick` + `DrillTracker.tick` + `HintEngine.tick` together cost <= 0.05 ms per tick on the Web reference build with 100 bullets and 6 enemies; allocation count per tick is 0 after warm-up. The `HintEngine` work is O(events this tick x 12 hints).

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Is the 11-drill school too long for a Target demo? A cut line is `hitbox` + `tap` merged, and `items` folded into `chain`; school would fall to about 4 minutes. | game-designer | First playtest of drills |
| 2 | Should completing school grant a cosmetic (a pilot badge on the Title, no gameplay effect)? Rule 4 forbids gating; a badge is allowed but not designed. | creative-director | Target polish |
| 3 | Bengali names for the drill and hint strings and the right word for "drill" and "Flight School" need native review (suggested title: উড়ান প্রশিক্ষণ). | localization lead | Before `ui_tutorial.csv` freeze |
| 4 | Practice start at a chosen stage or boss (Accessibility OQ9) is not part of school; Boss rush (32) is the proposed owner. | game-designer | Boss rush GDD |
| 5 | Should Pause tips ever show on a boss's intro (240 ticks, no bullets)? Currently only on Pause and Tally. | ux-designer | Boss playtest |
| 6 | Is a 4 px Cream bracket visible enough on the strip for low-vision players? Test with the high-contrast HUD and text step 3; larger arms are the fallback. | ux-designer, art-director | HUD layout spike |
| 7 | Target planes (Sentry, Breaker) should publish `charge_last_hit` / `drone_ability_started` equivalents. **Narrowed 2026-11-03 (wave 5 batch 2):** the "or get plane-specific drills" option is **withdrawn** (no new drills are authored), and this is no longer a blocker for F3's `complete` because the per-plane mask covers it. What remains is a **Kits** question: which of these events each Target kit publishes, so the School list is as full as it can be on every plane. | game-designer | Kits GDD 29 |
| 8 | Is `Quit to list` wise without a hold, given Pause hold rules elsewhere? Nothing is saved, so none is required here. | ux-designer | Menus review |
| 9 | Should `tutorial.hints` default to off for players who completed school? Current: stays on but suppressed per concept (Rule 19). | ux-designer | Playtest |
| 10 | Should drills support an assist (slower game speed) differently from normal runs? Currently the Accessibility `game_speed_pct` works in drills like anywhere. | accessibility lead | Accessibility review |
| 11 | ~~`required_mask` versus hidden rows.~~ **CLOSED 2026-11-03 (wave 5 batch 2).** The **per-plane mask** is adopted: `required_mask(plane) = 1023 & available_mask(plane)`, `drills_done` stays one profile-wide bitmask, and `tutorial.complete` is the OR over planes, so a Sentry-only or Breaker-only pilot can finish the school. Authoring plane-specific replacement drills was **rejected** - no new drills. Hints settle on `hint_max_shows`, not on the `drill_ref` bit. See F3 and Rule 12. | — | Closed |
