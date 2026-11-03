# Menus, Title and Plane Select

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (ux-designer) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Revision 2026-11-03 (final doc closeout)**: Rule 39 drops **Delete my online data** from the scores screen's Online tab and links to Settings > Online, the single owner (consistency-report C2); the audio-cue table is rewritten to the canonical `sfx_ui_*` ids, with `ui.rank` resolved to `sfx_ui_new_best` (consistency-report C1).
> **Revision 2026-11-03 (UX consistency check, wave 5)**: Style note follows the amended Alarm Red rule (`#E03A3E` never a text fill); the string-table note names `ui_menu.csv` (Localization Rule 5) and records that the ALL CLEAR / MISSION COMPLETE glossary pair is now registered in `localization.md` Rule 30.
> **Implements Pillar**: Four Planes, Four Games (plane select must show each plane's identity), Readable Chaos (menus are calm, legible and never compete with play), Every Hit Counts (honest records: quitting banks nothing, name entry and boards), History Accelerates (title and attract carry the era look)
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: "Reset display" is a hold of `confirm_hold` length with the **same effect as** `display_reset`, which stays a separate 2 s real-time hotkey (Rule 43, AC-50); Settings **ignores Start from Pause** and holds count **Fire only** (Rule 43, F6, AC-52).
> **Revision 2026-11-03 (UX amendments wave 5)**: one rank strip on Results, team rank in co-op and the `Not in top {n}` case (Rule 35, 2P mock-up); 3-4P name-entry grid (Rule 36, V/A); untimed pad loss holds the name-entry slot (Rule 36, edge case); 3-4P Results digit tiers (V/A); unknown-plane solo sub-tab chip and lead-player definition (Rule 40, Boards edge case); online row handle cut (F10); Credits manual scroll, reduce_motion and licence records (Rule 46, Open Question 15); pick-plate keep-out corner (Rule 52); new string keys.

> **Revision 2026-11-09 (plane select built; duplicate-plane colourways)**: the Lobby / plane select screen now exists (`src/ui/menu/plane_select.tscn` + `LobbyModel`), and the owner's requirement of 2026-11-09 closes Open Question 4: **a player may always pick any available plane, in solo and in co-op, duplicates included, and a duplicate pick is told apart by its colourway** - new **Rule 20a** below. See "Implementation status" at the end of Detailed Design for what is MVP-complete and what is not.

## Overview

**The data layer:** Menus, title and plane select owns every screen the player sees **outside the fight itself**: boot and Web gate, **Title**, **Lobby / Plane select** (per-slot cursors and ready-up), the in-run **Drop-in pick** and **Pause** menu (including the disconnect overlay), **Results**, **Name entry**, **High scores and Records**, **Settings** (Audio, Display, Language, Controls, Accessibility shell) and **Credits**. Each screen is a thin view over a node-free `RefCounted` model with a `tick()` at 60 Hz (ADR-0001): `MenuModel` (focus graph, navigation, activation), `LobbyModel` (slots, cursors, ready-up, commit), `PauseModel`, `NameEntryModel`, `ResultsFlow`, `HoldConfirm`. Screens are described in data (`data/menus/*.tres`): items, focus order, bound setting keys, string keys, platform tags. Models read the input snapshot from Input (2) (`nav`, confirm, cancel, `held_ticks`), call Session (1) to start and abandon runs, call Save (26) for boards and settings, call Localization (27) for strings and numerals, and live inside the 360x640 canvas of the Display scaler (4). Menus never decide gameplay rules.

**The player impact:** the player should go from "press Start" to flying in one or two presses, and back into a new run just as fast. A friend who grabs a pad is in the lobby the moment they press Start, with their own colour, cursor and ready stamp. Each plane shows what it *is* (a spear or a leash) before the player commits. Pausing is safe and clear about who paused. Quitting says plainly that the score will not be saved. Game over shows an honest result, a name wheel that works on a pad, and a board that remembers. Without this system the game would be a prototype with no front door, no way to pick a plane, and no way to change the volume.

## Player Fantasy

**Anchor moment: the roster.** The cabinet hums in a warm hangar. Four planes stand on pedestals in the soft top light. The first player taps Start and a vermillion ring slides onto the Lancer; a second pad joins, a yellow dashed ring lands on the Leech, both press Fire, two **READY** stamps drop, and the hangar doors open into 1941. No menu was configured. Nobody read a manual.

What it must feel like:
- **Arcade-fast.** Title to flying is 2 presses solo (Start on START GAME, Fire to lock). Game over to a new run is 3 (Confirm Results, Confirm board, Start).
- **Pick your ace.** The plane card says in three short rows what Fire, hold-Fire and Drone do, so the choice is a style choice, not a guess.
- **Together.** In co-op, every player has their own cursor at the same time and nobody waits for a turn. A stalled friend cannot hold the lobby hostage.
- **Honest.** "Quit to title" asks you to hold, and says the score will not be saved. A name wheel that times out keeps your last initials. Nothing silently ate your run.
- **Native.** The title is both scripts at equal weight; the menus are in the player's language, with their digits, and a one-press language toggle.

**Anti-fantasy (must never happen):** a menu that only works with a mouse; a gamepad player stuck on a screen they cannot leave; two players fighting over one cursor in plane select; a pause that lets another player resume by accident; a quit that costs a score without warning; any white flash between screens; Bengali text clipped in a button; a screen that needs reading while bullets are live.

> `art-director`, `creative-director` not consulted (auto-approve). Visual limits here follow `design/art/art-bible.md` §2, §4.7, §7.5-7.9.

## Detailed Design

### Core Rules

**Screen flow**

```
BOOT --(Web only)--> WEB GATE --> TITLE <------------------------------+
  Save.load_all, Localization,       |  \__ HIGH SCORES / RECORDS      |
  Display ready                      |  \__ SETTINGS (Audio, Display,  |
                                     |       Language, Controls, Access)|
                                     |  \__ CREDITS   \__ QUIT (PC/Switch)
                                     v
                     LOBBY (plane select, per-slot, co-op join)
                                     | commit (all joined locked + 45 ticks)
                                     v
        +--------------------->  STAGE  <------> PAUSE (Resume / Settings / Quit)
        |  (drop-in pick,          |   |            |-- disconnect overlay (Input 28-33)
        |   continue prompt:       |   |            \-- Quit (hold) --> TITLE  [ABANDONED, nothing saved]
        |   HUD-hosted)            v   |
        |                        TALLY (21) ----> next STAGE
        |                          | last stage (game over skips the tally: STAGE --> RESULTS)
        |                          v
        +--------------------   RESULTS --> NAME ENTRY (ranked only) --> BOARD (new entry) --> TITLE
                                                                                     \--> LOBBY ("Play again")
```

1. **Screen owners.** Menus owns Boot, Web gate, Title, Lobby, Drop-in pick logic, Pause, Disconnect overlay, Results, Name entry, Board, Settings, Credits. Stage tally is Stage-end tally (21). The **continue prompt** and the **join / pick plate geometry** are HUD (20) (Session UI Requirements); Menus supplies the pick model and the prompts. *(2026-11-03, wave 3a: Stage-end tally (21) has a [GDD](stage-end-tally.md). It runs after every stage, including the last, and hands over to Results at tally Done. A GAME_OVER before a boss dies goes straight to Results with no tally (Tally Rule 1).)*
2. **Everything is drawn inside the 360x640 canvas** (Display scaler Rule 1). Menus never read the screen size. They live under the presenter's SubViewport scene host (→ ADR, Display Open Question 4).
3. **No dedicated first-run language screen.** The title is always bilingual and carries a language chip, so a wrong OS guess is fixed with one press (Localization Rule 3). *(Decided under auto-approve.)*

**Boot and Web gate**

4. Boot order is fixed: `Save.load_all()` → `Localization.resolve_language` → Display presenter first layout → Title. Title is not shown before all three finish. Boot shows a Char backdrop with a small two-script wordmark and a stepped loading bar (4 steps); no skip.
5. On **Web only**, boot ends at the **Web gate**: a Char screen with the bilingual line "Click or press a key to start" (`text_both`, since the language may still be unresolved on a wrong guess). Its purpose: browsers need a user gesture to unlock audio and fullscreen, and gamepads appear only after a first press (Input UI Requirements). The first click, key, or touch leaves the gate, resumes the audio context, applies a saved `fullscreen` (Save Rule 29), and **is consumed**: it never also acts as Confirm on Title. A pad button press alone leaves the gate but may not unlock audio (*unverified*; AC-46). Desktop builds skip the gate.

**Title**

6. Title has one focus list (Rule 8), a bilingual logo (two art layers `logo_title_bn` / `logo_title_en`, Bengali on top, equal weight), the hi-score line, and the language chip. Backdrop: warm sepia dusk, formation flyby (art bible §2, §7.8). Neutral warm palette; no era tint.
7. **Title items:** START GAME (default focus), HIGH SCORES, SETTINGS, CREDITS, QUIT. QUIT is hidden on Web and mobile (`platform_tags`). *(Amended 2026-11-03, wave 4:)* at Target, **FLIGHT SCHOOL** (`LINK`) sits between START GAME and HIGH SCORES with a static NEW tag (text plus star glyph) until `tutorial.school_seen` (tutorial.md Rules 5, 25). At Stretch, once unlocked (Online leaderboards and boss rush 32, Rule 44), START GAME first shows a **Play** choice: MAIN (default focus), **BOSS RUSH**, **SINGLE BOSS**; locked modes are not listed, so a fresh profile still reaches the Lobby in one press.
8. **Title is shared.** Every connected device may navigate (Input Rule 6). There is no owner on Title, Scores, Settings (from Title) or Credits; the last input wins.
9. **Starting a run from Title.** Confirm (Fire or Start) on START GAME by a pad or keyboard device **binds that device to slot 0** and opens the Lobby with slot 0 already Choosing. A pointer (mouse or touch) cannot be a flying device: it opens the Lobby with all four slots Empty, and slots join by Start press. *(Amendment to Input Rule 3: Confirm on START GAME counts as the join request.)* **Touch platforms (amended 2026-11-03, touch-controls.md):** on a touch platform a tap on START GAME **binds TOUCH to slot 0** and opens the Lobby with slot 0 Choosing; TOUCH is solo only, so while it is bound another device's Start is ignored and the `touch_solo` toast shows. The "pointer cannot be a flying device" rule keeps applying on PC and Web desktop.
10. **Language chip.** Two chips, `বাংলা` and `English`, each always in its own script and never translated; the active one is filled. The **Drone** button (glyph shown on the chip) or a pointer click toggles the language through `Localization.set_language`. It applies in one frame, shifts nothing (shared digit grid), and **commits immediately** (`commit_settings`), because Title is a calm moment. *(Amendment to Save Rule 20.)*
11. **Attract.** After `attract_idle_ticks` (1,800 = 30 s) with no input, the menu list hides and the backdrop cycles the four era palettes every `attract_era_ticks` (1,200 = 20 s) with the logo and hi-score only. Any input returns to Title and **is consumed**. MVP has no gameplay demo (Open Question 1).

**Navigation model**

12. **Gamepad first.** Menus use Input's verbs only (Input Rule 24): **Nav** (4-way, repeat 18/6), **Confirm** (`fire` or `start` pressed), **Cancel** (`bomb` or `back` pressed). Keyboard uses the same verbs from the KB1/KB2 defaults (Enter/Z/Space confirm; Esc/C cancel). Menus never read raw keys except name-entry typing (Rule 36).
13. **Focus.** Exactly one focused item per navigating owner. The focus indicator is a **3 px Cream border plus an arrow glyph offset 2-3 px** (art bible §7.8); it never relies on hue. A focused item may pulse at 40% opacity or less and 2 Hz or less, one element at a time (§7.7); the pulse is off when reduce-pulsing is on (Accessibility 28). Movement wraps (F1) and skips disabled items.
14. **Pointer (Web, PC, touch later).** A click or tap on an item focuses and activates it in one action. Mouse hover may move focus as a convenience but never activates, and no state exists only on hover (technical preferences). Positions arrive already mapped to canvas space by the presenter (Display F7). Pointer rules: cannot join a slot (Rule 9); wheel scrolls lists; stepper and slider steps are individual click targets of at least 24x24 px; Cancel on pointer is a visible Back plate (at least 24x24).
15. **Item kinds** (data, Rule 41): `BUTTON`, `LINK` (opens a screen), `TOGGLE`, `STEPPER` (integer steps, e.g. volume 0-10), `CHOICE` (set of strings), `HOLD_BUTTON` (hold-to-confirm, F6), `INFO` (read-only line). Left/right changes `STEPPER` and `CHOICE`; Confirm activates `BUTTON` and `LINK`; Cancel goes up one level.
16. **Cancel goes up, never out.** Cancel on a sub-screen returns to the parent with focus restored on the item that opened it. Cancel on Title does nothing. Cancel never discards: Settings changes apply live (Rule 47).
17. **Toasts.** One plated strip at a time, `save_toast_ticks` (90) long, panel in/out 8 frames (Save V/A). Used for: "Game full", "Controllers recommended" (Input), Save notices (`save_failed` reasons, corruption, reset, newer version, "Progress will not be saved"), "P{n} left" (AFK release), "P{n} controller disconnected" (lobby). A queue holds at most 3; extras are dropped oldest first except Save notices.

**Lobby and plane select**

18. **Lobby layout is fixed.** Four slot columns of 90 px are always visible (P1-P4), even for a solo player, so co-op is always discoverable. Empty slots show the join plate "Press START to join" with the slot's ring pattern and pips. The plane cards sit above the columns (F7). The hangar is neutral warm, soft top light (art bible §2).
19. **Plane cards** are data (`data/menus/plane_cards.tres`, one per plane) and convey identity in a fixed shape: pilot idle animation on a pedestal, the plane name, a one-line tagline, a **playstyle tag**, and three trait rows (Fire / Hold / Drone) each with a button glyph and one short line. MVP content (kit facts from Plane kits 11; text keys, English source):

| Plane | Playstyle tag | Tagline | Fire (tap) | Hold Fire | Drone button |
|---|---|---|---|---|---|
| **Lancer** | Burst and hold | I am the spear. | Wide 3-way shot | Laser: invulnerable while it burns | Drones park and fire lasers |
| **Leech** | Latch and sustain | Nothing gets away. | Narrow 2-way shot | Focused shot: narrow, strong, slow | Drones latch onto enemies |

   Keys: `plane.<id>.name`, `plane.<id>.tag`, `plane.<id>.style`, `plane.<id>.fire`, `plane.<id>.hold`, `plane.<id>.drone`. Trait rows are two lines at most. A plane with `available = false` (Sentry, Breaker at MVP) is not listed. *(2026-11-03, wave 4: Sentry and Breaker are `available = true` at Target (plane-kits-sentry-breaker.md); keys `plane.sentry.*` and `plane.breaker.*` in Bengali and English.)* With more than four planes the card row scrolls (Target).
20. **Per-slot cursor.** Every Choosing slot has its own cursor on a plane card, moved only by that slot's own Nav (Input Rule 24: events carry the slot index). Left/right wraps. Two slots **may** pick the same plane (Co-op mixes planes on boards; no uniqueness rule). The card's rim light shows the colours of every slot hovering or locked on it, split into equal segments (F8); each slot's cursor token also has its ring pattern and pips, so colour is never the only cue.
20a. **Duplicate planes and colourways.** *(Added 2026-11-09, owner requirement; closes Open Question 4.)* Plane choice is **free for every slot, in solo and in co-op**: there is no uniqueness rule and no cap, so all four slots may lock the same plane. What separates them is the **colourway**, and **the colourway is the slot**: P1 amber, P2 azure, P3 green, P4 pink (art bible 3.1, 4.4). So the second player to take a plane flies it in azure, the third in green, the fourth in pink, and **no two planes on screen ever share a palette** - the thing the owner asked for ("if the same plane is selected we change the colour for the 2nd, 3rd or 4th") falls out of the slot identity colour that the HUD, the cursor rim, the hitbox ring and the boards already use, so it needs no extra art and no extra rule.
   - Art contract: `RunVisuals.plane_sprites` holds **four colourways per plane**, flattened `kind * 4 + colourway` (`data/art/run_visuals_1941.tres`, in `KitRules.Kind` order). A plane whose row has no sprite falls back to a tinted primitive in the same colour.
   - Colour is never the only cue (4.4): the slot's **ring pattern and pips** carry the same identity, and a slot that locked a plane somebody else already holds also shows a `COLOUR {n}` line in its column, where `n` is its rank on that card (2 for the second player on it).
   - The run receives `{slot, kind, colourway, plane_id}` per locked slot, so Save (26) and the boards record the plane, not the colour.

21. **Slot panel states** (Lobby slot): **Empty** → (Start press, Input Rule 3) **Choosing** → (Confirm) **Locked** (a READY stamp: text, check glyph and the ring-pattern frame) → (Cancel) **Choosing** → (Cancel) **Empty**. Cancel from Choosing releases the device (Input Rule 5) and returns the slot to Empty. If the last joined slot cancels, the Lobby returns to Title.
22. **Initial cursor.** A joining slot starts on its last locked plane (`profile.last_plane[slot]`) or on the first listed plane if none. *(New Save key proposed, Amendments.)*
23. **Commit.** `ready = joined >= 1 AND locked == joined`. While `ready`, a counter runs (F2); at `start_delay_ticks` (45) the Lobby commits: it calls `GameSession.start_run(selections, mode, stage_list)` **once** (MAIN and the main stage list from START GAME; RUSH / BOSS and their lists from the Play choice, Online leaderboards 32 Rules 35, 43; signature (decided under auto-approve 2026-11-03, consistency check)) with every locked slot (slot, plane id, device) in slot order, each marked `joined_at_run_start = true`, then starts the stage load. Any change (unlock, cancel, a new join, a disconnect) resets the counter to 0 and removes the "Starting" bar. *(Amendment to Session Rule 1.)*
24. **Stall protection.** (a) A Choosing slot with no input for `afk_release_ticks` (1,800 = 30 s) **while at least one other slot is Locked** is released to Empty with the toast "P{n} left" (F3). (b) If **no** joined slot sends any input for `lobby_idle_ticks` (3,600 = 60 s), the Lobby returns to Title; a warning bar shows in the last `lobby_warn_ticks` (600). There is no forced lock-in. A pad that disconnects in the Lobby returns its slot to Empty with a toast, no pause (Input Rule 28).
25. **Game full.** A fifth device pressing Start is ignored with the toast "Game full" (Input AC-03).

**Drop-in pick (in a run)**

26. A Start press on a free pad during a Stage or Tally opens an in-place pick for that slot (Session Rule 7). The game keeps running. Menus owns the model (`DropInPick`): a cursor over listed planes with the same card summary (name, playstyle tag), Confirm to lock, Cancel to leave. It is **drawn in the empty slot's HUD column inside the reserved strip**, never over the play field (HUD (20) hosts the geometry; requirement in Rule 52). The slot is non-hittable while Selecting (Session Rule 7). It auto-cancels after `dropin_pick_ticks` (900 = 15 s) and returns the slot to its previous state (Session Rule 10). Confirm sends the plane choice to Session, which makes the slot Alive.

**Pause**

27. Start or Back from any bound slot during Stage or Tally pauses (Input Rule 25). The pausing slot is the **owner**; the pause panel shows an owner tag (slot colour frame, ring pattern, pips, "P{n}"). Only the owner's Nav and Confirm are accepted; other slots' presses are ignored and their tags dimmed. If the owner's device disconnects, ownership passes to the lowest connected bound slot (Input Rule 25).
28. **Pause items:** **Resume** (default focus), **Settings**, **Quit to title** (`HOLD_BUTTON`). No Restart in MVP (Open Question 5); debug builds keep F5. Cancel or Start on the pause menu resumes. **In a Flight School drill** (Tutorial 30 Rule 15) the items are **Resume**, **Restart drill**, **Settings**, **Skip drill** (`HOLD_BUTTON`), **Quit to list**; Restart exists in drills only. When a Tutorial hint is pending, the Pause panel shows one **tip row** (14x14 icon + up to two S-tier lines; three in Bengali) under the items (Tutorial Rule 27).
29. **Quit to title** needs a hold of `hold_confirm_ticks` (60) and shows "Score will not be saved" beside it (F6). On completion Menus calls `GameSession.abandon_run()`: `run_ended_by = ABANDONED`, Save is **not** called, the session clears, Title loads (Session AC-35). Quit has no second dialog.
30. **Resume beat.** After the owner resumes, a three-pip beat of `resume_beat_ticks` (45) runs with the tree still paused; at the end the game runs and Input re-arms held buttons (Input Rule 27). Closes Input Open Question 4 for the input side; no invulnerability is added (Collision owns that). The beat always runs after any pause reason, so the player is ready. `resume_beat_ticks = 0` disables it.
31. **Pause reasons** (Input States): USER shows the full menu. FOCUS (window blur) shows the same menu with the line "Paused - window lost focus" and never auto-resumes. DISCONNECT shows the **disconnect overlay** over the menu.
32. **Disconnect overlay.** One plated row per Waiting slot (Input Rule 31), each with the slot frame, "Reconnect controller for P{n}", and: **Reconnect** (instruction line "Press START on a controller"; resolves by Input), **Use keyboard** (shown only if a keyboard scheme is free; "Press Enter / 1"), **Drop P{n}** (`HOLD_BUTTON`, calls `forfeit_slot`), **Wait** (default; changes nothing). Resume is refused while any slot is Waiting (Input Rule 31). No flashing, no tint (Input V/A).
33. **Settings from Pause** is the same Settings screen. Closing it commits once if dirty (Save Rule 20). Display changes preview live. The TATE confirm and its countdown run in real time (Display Rule 17).

**Results, name entry and boards**

34. **Results** opens at game over or ending (after the last stage's tally). Quit-to-title (ABANDONED) never opens Results. The mood is cold and quiet for GAME OVER and warm for ENDING (art bible §2). On open, Menus asks Session to call `preview_rank(record)` (read-only). Confirm is **ignored for `results_input_lock_ticks` (30)** so a player mashing Fire in the last second does not skip it.
35. **Results content** (per played slot, in slot order; Session F6): P-tag with frame, plane icon, score (9-digit clamp), best chain, Critical Breaks, a **"C"** tile and continue count if `continues_used > 0`, a **"1CC"** tile if `one_credit_clear`, and `stage_reached` of `stage_count`. Co-op adds a team block: team score, team best chain, team Critical Breaks. If any slot continued, one small line shows "Before continues: {n}" (`team_score_incl_continues`, display only). **Rank is shown once, in a strip under the heading** - never on a player's row (amended 2026-11-03, wave 5). In **co-op it is the single team rank** (one entry per board, ranked by `team_score`: Save Rule 5, Co-op Rule 18), not a rank per row. The strip reads "RANK {n}" with a NEW tag when `preview_rank` returns a rank, **`Not in top {n}`** (`menu.results.not_placed`, `n` = `board_size`) when the run scored but did not place, and nothing at all when the run is not ranked (score 0, PRACTICE/assisted). Rows reveal every 15 ticks; any Confirm after the lock skips to the end state.
36. **Name entry** follows Results Confirm and appears **only if the run is ranked** (`preview_rank`). Every played slot whose bound device is connected edits its own initials simultaneously, each with its own 3-slot wheel (Save Rule 12). **Layout (added 2026-11-03, wave 5):** 1-2P keep the single centred wheel; **3-4 players use a 2x2 grid of 160x136 blocks at x = 16 / 184 and y = 104 / 264** (so the grid ends at y 400), one block per played slot in slot order, each block carrying its own wheel, P-tag and **device glyph**; with **3 players the bottom block is centred at x = 100**. The rank line is the shared strip under the heading (Rule 35), not per block. Wheel characters: characters `A-Z`, `0-9`, `-`, `.` (38). Up/down changes the focused character (F4), left/right moves focus, Confirm on the last slot (or Start anywhere) marks the player **Done**, Cancel steps focus back (on the first slot it does nothing). A Latin keyboard slot may also **type** letters and digits, which set the focused character and advance focus (only when exactly one keyboard slot is editing; provisional `typed_char` event from Input). A slot with no connected device is pre-filled with its `profile.last_initials` and shown Done - **unless `access.untimed_menus` is on**, in which case the slot is **held open** instead (controller-lost plate with a **DROP** action; Accessibility 28) until the pad returns or a player drops the slot. A shared timer of `name_entry_ticks` (1,800 = 30 s) runs (F5); at 0 every unfinished slot keeps its **current** wheel text if the player changed it, else its last-used initials. When every slot is Done, or at timeout, Menus calls `submit_run(record, initials)` **once**.
37. **Unranked runs** skip name entry; Results Confirm calls `submit_run` (records still update, Save Rule 13) and goes to the Board.
38. **Board after a run.** The High scores screen for the run's board id opens with the new entry highlighted (static Cream 3 px border plus arrow; a pulse at 40% and 2 Hz or less is allowed, off under reduce-flashing). Two actions: **Play again** (default; Start or Confirm, binds the pressing device to Lobby slot 0) and **Title**. Records for "NEW BEST" are shown on the tally (21), not here.

**High scores and records**

39. **High scores screen.** Tabs: **Solo** with one sub-tab per listed plane (Lancer, Leech), **Co-op** with 2P / 3P / 4P, and **Records**. MVP boards: `2s/solo/lancer`, `2s/solo/leech`, `2s/coop/2`, `2s/coop/3`, `2s/coop/4`. A run-length selector appears only once more than one `stage_count` exists in the file. A badge filter cycles All / 1CC only. Left/right changes tab, up/down moves rows, Cancel returns. No combined co-op tab at MVP (Save Open Question 7). *(2026-11-03, wave 4:)* Target adds Sentry and Breaker sub-tabs and touch boards (`/touch` suffix, solo only, Save F3); Stretch adds **Rush** and **Boss** tabs (`rush{n}/…`, `boss/{boss_id}/{plane}`) and turns the reserved slot into the **Online** tab (Global / Friends / Around me scopes, status tile, Consent and Handle screens; online-leaderboards-boss-rush.md Rules 13-16, 33). *(Amended 2026-11-03, final doc closeout, consistency-report C2:)* **Delete my online data** is **not** on this screen. It lives in **Settings > Online only** (online-leaderboards-boss-rush.md Rule 19; `design/ux/settings.md`), so there is exactly one place to destroy data; the Online tab's status tile may **link** to it (focusable row that opens Settings > Online) but never carries the `HOLD_BUTTON` action itself.
40. **Row** (Save V/A): rank, initials, plane icon, 9-digit score (Gold, tabular), stage reached, "C" and "1CC" tiles. A co-op row shows the **lead player's** initials and a "+N" tile; focusing the row shows a detail strip with every player's initials, plane, best chain and Critical Breaks. **Lead player** of a co-op entry = the highest `players[].score`, ties to the **lower slot** (Save Rule 11; `players[]` is in slot order). A co-op row carries **one rank**, the team rank by `team_score` (Rule 35, Co-op Rule 18) - never a rank per player. A **solo board stored under an unknown plane id** appears as an **extra Solo sub-tab chip** (generic plane icon plus the raw id in Latin, cut to 8 characters + `...`); the plane-select list does not show that plane (amended 2026-11-03, wave 5; closes Save Open Question 9 for the UI). A **1CC-filtered list keeps the true board ranks** (it does not renumber 1, 2, 3). Empty board: "No scores yet" (`menu.scores.empty`); empty 1CC-filtered board: `menu.scores.empty_1cc`.
41. **Records tab:** best chain per plane per boss and 1CC counts per plane and stage count (Save F4, Rule 13), read-only. A plane with no data shows a dash.

**Settings and Credits**

42. **Settings sections** (MVP): **Audio** (`audio.master`, `audio.music`, `audio.sfx`, steppers 0-10), **Display** (Display UI table: window mode, scaling, rotate screen, bezel, info line, reset display), **Language** (BN / EN, same toggle as the Title chip), **Controls** (remap `fire`/`drone`/`bomb` and KB movement per Input Rules 34-39, Fire toggle, Tap Assist, deadzone preset, reset to defaults), **Accessibility** (a section shell registered by Accessibility (28); at MVP it holds `access.reduce_flashing`). Items are data; Accessibility adds its entries without code changes. *(2026-11-03, wave 3b, [Accessibility 28](accessibility-options.md): Accessibility rows are generated from `AccessOptionDef` entries in `data/accessibility/access_options.tres`. The **first-run photosensitivity prompt** (with the Calm preset) shows once after the Web gate (or after boot on desktop) until `access.first_run_prompt_done`. Pause shows a **status panel** at the current text step (the HUD has no scale). A run with `run.assisted` latched shows a **PRACTICE** tag on Pause and Results, and Results skips name entry (not ranked).)*
43. **Display section** shows only what the platform allows: window mode hidden on phones; TATE only on PC and Switch; TATE opens the confirm dialog ("Keep this rotation?", countdown 10 s, **default focus Cancel**, Display Rule 17). "Reset display" is a `HOLD_BUTTON` with the **same effect as** `display_reset` and the normal `confirm_hold` length (60 ticks at NORMAL, F6); **`display_reset` itself is the separate 2 s real-time hotkey** owned by [Display (4)](display-scaler-and-bezel.md) and is not this item. *(Amended 2026-11-03, wave 5 batch 2: the two were wrongly equated, which made the menu item inherit a 2 s wall-clock hold that ignores `access.confirm_hold`.)* **Settings ignores Start when it was opened from Pause**, and every hold in Settings counts **Fire (Confirm) only** - Start never starts or advances a hold anywhere Start has another meaning (F6, `design/ux/pause.md`, pattern P04). *(Added 2026-11-03, wave 5 batch 2.)*
44. **Controls section** rules: a rebind waits for the next control from the **same device class** and shows "Press a control for {action}" with a Cancel; a control already in use asks to swap (Input Rule 36, confirm line); a reserved control is refused with a message (Input Rule 38); the last binding of Fire / Drone / Bomb cannot be cleared (Input Rule 37). All text and glyphs follow the current device family (Input F8).
45. **Destructive actions** use `HOLD_BUTTON` with F6: Reset settings, Clear scores, Reset display, Quit to title, Drop player. Clear scores shows "This cannot be undone". Quit game (PC/Switch) uses a Yes / No dialog, default No.
46. **Credits.** A scrolling list from `data/menus/credits.tres` (section key, name lines). Scroll speed `credits_px_per_s` (24), integer steps; holding Fire doubles it; Cancel exits. Names are proper nouns and are not translated (excluded from the string lint allow-list). *(Amended 2026-11-03, wave 5:)* **Nav up/down scrolls one line and pauses the auto-scroll**; a **Fire or Start press resumes** it. With **`access.reduce_motion`** on, the auto-scroll is **off** and the screen opens in **manual** mode (accessibility-requirements.md Section 5: credits must be scrollable by input at the player's pace). Scrolling **stops with the last line at the viewport centre**; there is **no loop and no auto-exit**. **Licence text is not translated** and is excluded from the string lint allow-list (like the names). **Start acts as Confirm** here (faster / resume), **not** as Cancel (Rule 12).
47. **Apply and commit.** Settings changes apply live through `set_setting` (sliders preview). Closing or backing out of Settings calls `commit_settings()` once if dirty (Save Rule 20); no discard. Opening the screen never writes.

**Audio cues** (UI bus, ids owned by Audio (24); Input's table is the base). *(Amended 2026-11-03, final doc closeout, consistency-report C1: the dotted `ui.*` spelling this table used is retired; every id is written in the canonical `sfx_ui_*` form that `design/gdd/audio.md` owns, and the old `ui.rank` resolves to `sfx_ui_new_best` - no separate rank sound.)*

| Cue id | Trigger | Notes |
|---|---|---|
| `sfx_ui_nav_tick` | focus moves | per-slot pitch step in Lobby and Name entry |
| `sfx_ui_confirm` / `sfx_ui_cancel` | Confirm / Cancel | |
| `sfx_ui_join_chime` | Lobby slot Empty to Choosing | slot's pitch; max 2 merged per tick (Input) |
| `sfx_ui_lock` | slot Locked | stamp thunk, slot pitch |
| `sfx_ui_unlock` | slot unlocked | |
| `sfx_ui_start_run` | commit | one rising sting |
| `sfx_ui_deny` | disabled item, game full, refused rebind | |
| `sfx_ui_hold_tick` | each of the 4 hold segments | rising pitch; `sfx_ui_hold_done` at completion |
| `sfx_ui_toggle_lang` | language chip | |
| `sfx_ui_name_tick` | wheel character change | |
| `sfx_ui_new_best` | Results shows a rank | short, once |
| `sfx_ui_save_error` | `save_failed` toast | Input/Save table |
| `sfx_ui_pause_in` / `sfx_ui_pause_out` | pause / resume | Audio owns ducking |

Music (Audio 24): title theme, hangar theme (Lobby), sober loop (Results), shared with Title for the Board. The Web gate plays no sound.

**Transitions**

48. Screen changes use a **stepped Char wipe**: 4 steps over `transition_frames` (12), each step covering 25% of the canvas area with dark Char panels; no fade through white, no full-screen luma jump in a single frame, never more than 3 changes per second (art bible §7.7). Menu sub-screen changes use the 6-frame menu transition; panels use 8 frames in and out. Nothing here flashes, so `access.reduce_flashing` does not change menus.
49. Game-start transition: Lobby wipes to a Char hold of at most 12 frames while the stage loads (pre-warming is Localization Rule 27), then the stage banner flow of the HUD begins. Results and Pause open with the panel animation only, never a tint over bullets.

**Web specifics**

50. Web gate (Rule 5). Fullscreen only on a direct input event (Display edge cases). Quit game is hidden. Save "will not be saved" toast once per session when storage is blocked (Save Rule 28). Keyboard shortcuts `Tab`, `Ctrl`, `F5`, `F11`, `F12` are never used as menu verbs (browser-reserved). The language chip, Settings and Scores work with mouse alone. Pad hot-plug after the gate shows the connected glyph family on next prompt.

**Accessibility hooks**

51. Every screen is fully usable with keyboard only and with gamepad only. Text uses `font_size_px(tier, step)` and screens lay out from measured text, never fixed offsets, so the text-size step-up (Accessibility 28) reflows rows without clipping (rows grow downward; lists scroll). Colour is never the only cue: slots by ring pattern, pips and "P{n}"; READY by text and glyph; focus by border and arrow; rank by number. Hold-to-confirm has an accessibility alternative `confirm_style = DOUBLE_TAP` (press twice within 120 ticks), key `access.confirm_style`, default `HOLD`; the hold length is `access.confirm_hold` (SHORT / NORMAL / LONG, default NORMAL) (Accessibility 28). Name-entry and drop-in timers are stopped by `access.untimed_menus` (Accessibility 28; Open Question 9 closed). Minimum text 12 px Latin / 17 px Bengali, outline 1 px on all text, contrast 7:1 or better (art bible §7.8).

**Data-driven definitions**

52. **HUD contract.** While any slot is Selecting mid-run, HUD (20) renders a pick plate in that slot's column inside the strip, at least 84x44 px, never over the field and never hiding an Alive player's chain plate. *(2026-11-03, wave 3b, decided: a Selecting slot makes the HUD use the **next layout mode for display only** (1P → 2P, 2P → 3-4P) so the slot gets its own column; the 84x44 pick plate (this GDD's model and plane cursor) is drawn in that column inside the strip (HUD Rule 23). Co-op `N` is unchanged. There is no HUD scale (Accessibility 28 Rule 20).)* *(Amended 2026-11-03, wave 5, draw order: the boss row's left and right **zones** (0,36,24,12) and (336,36,24,12) draw **above** the pick plate, so in the outer columns (0 and 3) the plate's bottom outer **19x10 corner is clipped**. Menus must keep the plane cursor, the plane name and every label **out of that corner** - the plate's own frame may be clipped there, nothing readable may be. HUD Rule 23 owns the draw order.)*
53. Definitions live in `data/menus/`: `menu_screens.tres` (list of `MenuScreenDef`), `plane_cards.tres`, `credits.tres`, `menu_rules.tres` (all knobs). A **`MenuScreenDef`** has: `id`, `title_key`, `layout` (LIST, TABS, LOBBY, CUSTOM), `items[]`, `back_target`. A **`MenuItemDef`** has: `id`, `label_key`, `kind` (Rule 15), `setting_key` (must exist in Save's schema), `choices[]` or `range`, `target` (screen id or action id), `platform_tags` (`pc`, `web`, `mobile`, `switch`), `visible_if` (named predicate, e.g. `tate_supported`), `confirm_style`. A lint (→ tools-programmer) fails the build if a key, target, setting key or predicate does not exist. No player-facing string is in code or scenes (Localization Rule 9).

### Implementation status (2026-11-09)

| Thing | Where | State |
|---|---|---|
| Lobby model: slots, per-slot cursors, lock / unlock / leave, commit countdown, AFK release, lobby idle | `src/ui/menu/lobby_model.gd` (node-free, 60 Hz `tick`), `data/menus/lobby_rules.tres` | **Done** (Rules 18, 20, 20a, 21, 23, 24) |
| Plane cards as data | `src/ui/menu/plane_card.gd` + `data/menus/plane_cards.tres`: four cards, all `available` | **Done** (Rule 19). Name, playstyle tag, tagline and the Fire / Hold / Drone rows all come from the string table |
| The screen | `src/ui/menu/plane_select.tscn` + `plane_select.gd` | **Done at MVP**: card row, four slot columns, split rim light, READY stamp, commit bar, prompt bar. Drawn immediately, no pilot animation, no pedestal, no hangar backdrop |
| Entry gate | `LobbyModel._armed` | **Done**: the Fire press that confirmed START GAME on Title cannot lock a plane - a verb must be released before it counts (same shape as Input Rule 27) |
| Selections reach the run | `GameSession.start_run()` → `Run._join_selected_players()` → `SimWorld.set_slot_kit()` | **Done**: only locked slots are in the run, each on its chosen plane and colourway |
| Title → Lobby | `title_screen.gd` START GAME | **Done** |
| Join by Start on an unbound device | Rule 18 / Input Rule 3 | **Partial**: a slot joins by pressing Start **or** Fire, but devices are still hard-bound to slots (Input correction 2), so "any pad" is really "that slot's pad, or the shared keyboard schemes" |
| `profile.last_plane[slot]` initial cursor (Rule 22) | - | **Not done**: a joining slot starts on the card matching its slot index, so four players who all lock at once get four different planes |
| Attract, Settings, Results, name entry, boards, Pause panel, drop-in pick (Rules 11, 26-47) | - | **Not done** |
| Bengali card text | `data/locale/ui_menus.tres` | **Partial**: the keys exist with English source text and three Bengali strings; the rest fall back to English until a translator fills them |

### States and Transitions

**Top-level menu state** (one at a time; the Session run flow table is the gameplay view of the same states)

| State | Enters from | Leaves to | Trigger |
|---|---|---|---|
| Boot | app start | WebGate (Web) / Title | load, resolve, layout done |
| WebGate | Boot | Title | first click, key or touch |
| Title | Boot, WebGate, Scores, Settings, Credits, Board, Lobby | Lobby / Scores / Settings / Credits / Quit | activate item |
| PlayChoice (Stretch) | Title (START GAME when a mode is unlocked, OL Rule 44) | Lobby (MAIN, BOSS RUSH) / BossSelect (SINGLE BOSS) / Title (Cancel) | activate item |
| BossSelect (Stretch) | PlayChoice | Lobby (boss chosen; `mode` BOSS, stage list of that boss) / PlayChoice (Cancel) | activate item |
| Lobby | Title, Board, PlayChoice, BossSelect | Title / InRun | last slot cancels or idle 60 s / commit |
| InRun | Lobby | Results / Title | Session state (Menus idle except Pause and drop-in) |
| Paused | InRun | InRun / Title | resume / quit hold completes (ABANDONED) |
| Results | InRun | NameEntry / Board | Confirm after lock; ranked or not |
| NameEntry | Results | Board | all Done or timeout |
| Board | NameEntry, Results, Title | Title / Lobby | Title / Play again |
| Scores, Settings, Credits | Title (Settings also Paused) | parent | Cancel |

**Lobby slot** (per slot, 0-3)

| State | Meaning | → Next |
|---|---|---|
| Empty | no device | Choosing (Start press by free device) |
| Choosing | own cursor on a plane | Locked (Confirm) / Empty (Cancel, AFK release, disconnect) |
| Locked | READY stamp | Choosing (Cancel) |

**Lobby** (whole): Open → Counting (`ready`, F2) → Committed (calls `start_run`); Counting → Open on any change; Open → Closed (to Title) on last cancel or idle timeout.

**Pause**

| State | Meaning | → Next |
|---|---|---|
| Closed | game running | Open |
| Open (USER / FOCUS / DISCONNECT) | menu shown, owner set | Settings, QuitHold, Beat, Closed |
| Settings | Settings screen over pause | Open (commit on close) |
| QuitHold | Quit held | Open (released early) / Abandon (60 ticks) |
| Beat | 3-pip resume beat, tree paused | Closed (45 ticks) |

**Name entry slot:** Editing → Done (Confirm or Start) / Done (timeout or no device). Editing ↔ Editing (focus moves).

### Interactions with Other Systems

| System | Direction | Interface (provisional unless the other system has a GDD) |
|---|---|---|
| Game events and session (1) — GDD | ↔ | Menus calls `start_run(selections, mode, stage_list)` (new, Amendment; `mode`/`stage_list` 2026-11-03), `abandon_run()` (new), the drop-in plane choice, and reads slot states, `RunRecord`, `run_ended_by`, aggregates (F6). Session calls `preview_rank` on Results open and `submit_run` on confirm (Menus drives timing: name entry between). |
| Input and player mapping (2) — GDD | In | `nav`, Confirm, Cancel, `held_ticks`, slot-tagged events, pause owner, glyph family, join requests, game-full event, disconnect/Waiting data, remap API. Out: lobby slot states (Empty / Choosing / Locked as Selecting), `bind_device(device, slot)` for Title and Play again (Amendment). |
| Save, settings and high scores (26) — GDD | ↔ | Boards, `preview_rank`, `submit_run`, `get_best_chain`/records, `set_setting`/`commit_settings`, `reset_settings`, `clear_scores`, `save_failed`. |
| Localization (27) — GDD | ↔ | `text`, `text_both`, `format_int`, `set_language`, `language_changed`, `font_size_px`. |
| Display scaler and bezel (4) — GDD | ↔ | Canvas host, pointer mapping, `get_layout()` for the info line, settings `scale_mode`, `window_mode`, `tate_mode`, `bezel_style`, `display_reset`, TATE confirm. Bezel idle text (stage name, hi-score) is shown by the presenter while Menus is active (Display Rule 11.1). |
| Plane kits (11) — GDD | In | Plane ids, `name_key`, tagline, trait text keys (card data); charge threshold unaffected. |
| Co-op and Team Chain (18) — GDD | In | Player colour, ring pattern, pips (Rule 15); `N` unaffected by Lobby. Answers Co-op Open Question 9: any bound slot may pause; the pauser owns the menu. |
| HUD (20) | ↔ | Hosts drop-in pick plate and join plate; Menus supplies the model. |
| Stage-end tally (21) | Out | Tally sits between Stage and Results (after every stage, incl. the last); Menus owns Results only and takes over at tally Done ([GDD](stage-end-tally.md)). |
| Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | Out | UI cue ids and transitions (no flashes). UI bus follows `audio.sfx` (Audio). |
| Accessibility (28) — [GDD](accessibility-options.md) | ↔ | Registers Settings entries (`AccessOptionDef`); `font_size_px` step; `confirm_style`, `confirm_hold`, `untimed_menus`, `nav_repeat`; reduce-pulsing; first-run prompt; `run.assisted` (PRACTICE tag). |
| Touch controls (31) — [GDD](touch-controls.md) | In / Out | Pointer verbs; touch targets at least 9 mm (TF7: 55 canvas px at x3 on a 458 dpi phone) with a touch row pitch instead of 24 px; START GAME tap binds TOUCH to slot 0; `touch_solo` toast; landscape prompt ("Rotate your phone upright"); Touch section in Controls; first-run touch hints. |
| Tutorial (30) — [GDD](tutorial.md) | ↔ | FLIGHT SCHOOL Title item and NEW tag; Lobby `SCHOOL` mode; screens `school_list`, `drill_card`, `coach_card` in `menu_screens.tres`; drill Pause items; Pause tip row; Results offer line (footer, GAME_OVER only, once). |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | ↔ | Online tab (was the reserved tab slot); Play choice with Boss Rush and Single Boss; Consent and Handle screens; Results Upload action. **Delete my online data lives in Settings > Online only** (Online Rule 19; Rule 39 as amended 2026-11-03) - this screen may link to it, never host it. |

> Decided under auto-approve (2026-11-03): no first-run language screen (title chip instead); shared Title navigation with Confirm-on-START binding; always-visible four-column lobby; simultaneous per-slot cursors, duplicate planes allowed; ready-up with a 45-tick commit gate; AFK release at 30 s and lobby idle at 60 s, no forced lock-in; drop-in pick in the HUD strip with 15 s timeout; pause with Resume / Settings / Quit only (no Restart); quit by 1 s hold, ABANDONED; 45-tick resume beat; Results confirm lock 30 ticks; name entry only for ranked runs; "Play again" from the board; lead-player row plus detail for co-op boards; Settings apply live and commit on close; hold-to-confirm for destructive actions; stepped Char wipe transitions; Web gate on Web only.

## Formulas

**F1. Focus move (wrap, skip disabled)**

`next = first (i + dir × j) mod n for j = 1 … n where enabled(item)`; if none, `next = i`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Items | `n` | int | 1-24 | Count of items in the focus list |
| Current index | `i` | int | 0 … n-1 | Focused item |
| Direction | `dir` | int | -1 or +1 | Nav up/left = -1, down/right = +1 |
| Enabled | `enabled(k)` | bool | - | Item shown and not disabled |

**Output Range:** 0 … n-1. **Example:** n = 5, item 0 disabled, `i` = 4, `dir` = +1: j = 1 gives 0 (disabled), j = 2 gives 1, so next = 1. From `i` = 1, `dir` = -1: j = 1 gives 0 (disabled), j = 2 gives `(1 - 2) mod 5` = 4, so next = 4. With every other item disabled: stays `i`.

**F2. Lobby ready gate**

`ready = joined >= 1 AND locked == joined`; `ready_ticks = ready ? ready_ticks_prev + 1 : 0`; `commit when ready_ticks >= start_delay_ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Joined | `joined` | int | 0-4 | Slots Choosing or Locked |
| Locked | `locked` | int | 0-4 | Slots Locked |
| Ready ticks | `ready_ticks` | int | 0 … `start_delay_ticks` | Consecutive ticks `ready` held |
| Delay | `start_delay_ticks` | int ticks | 0-120 (45) | Beat after the last lock before the run starts |

**Output Range:** commit happens exactly once, on the first tick `ready_ticks` reaches the delay. **Example:** both players lock on tick T: `ready_ticks` = 1 on T, 45 on T+44, commit on T+44. P2 unlocks at T+20 (counter 0), relocks at T+30 (`ready_ticks` = 1 on T+30): commit on T+74. A third player pressing Start at T+10 makes `joined` 3 and `locked` 2: no commit until they lock.

**F3. Idle timers**

`idle(s) = input(s) ? 0 : idle_prev(s) + 1`; release slot `s` when `state(s) == Choosing AND idle(s) >= afk_release_ticks AND locked >= 1`; leave Lobby when `max over joined slots of (no input) >= lobby_idle_ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Idle ticks | `idle(s)` | int | 0 up | Ticks since slot `s` last sent any Nav / Confirm / Cancel |
| AFK release | `afk_release_ticks` | int ticks | 900-3600 (1800) | 30 s |
| Lobby idle | `lobby_idle_ticks` | int ticks | 1800-7200 (3600) | 60 s with no input from any joined slot |
| Warning | `lobby_warn_ticks` | int ticks | 300-900 (600) | Warning bar shown when idle >= `lobby_idle_ticks - lobby_warn_ticks` |

**Output Range:** release or exit on one tick. **Example:** P1 Locked at tick 0, P2 Choosing with no input: P2 is released at tick 1,800 (toast "P2 left"). If P2 moves its cursor at tick 1,500, release is at 3,300. With nobody Locked, P2 is never released by (a), and the Lobby leaves at tick 3,600 if neither player sends input; the warning shows from tick 3,000 (10 s).

**F4. Name wheel**

`alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-."` (38); `idx' = (idx + dir) mod 38`; `steps(a, b) = min((b - a) mod 38, (a - b) mod 38)`; ticks to reach step `k` of a held direction: `t(1) = 0`, `t(k) = nav_delay + nav_repeat × (k - 2)` for `k >= 2` (Input F4)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Character index | `idx` | int | 0-37 | Position in the alphabet |
| Direction | `dir` | int | -1 / +1 | Up = +1 (next character), down = -1 |
| Nav delay / repeat | `nav_delay`, `nav_repeat` | int ticks | 18 / 6 | From Input F4 |

**Output Range:** `steps` 0-19. Worst case 19 steps takes `18 + 6 × 17` = 120 ticks (2.0 s) by holding. **Example:** `Z` (25) up gives `0` (26); `.` (37) up gives `A` (0); `A` down gives `.`. `A` to `Z`: up 25, down 13, so `steps` = 13. Three characters at the worst case: 6.0 s, inside the 30 s timer (Save rationale).

**F5. Name-entry timer**

`entry_left = max(0, name_entry_ticks - elapsed)`; displayed `ceil(entry_left / 60)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Elapsed | `elapsed` | int ticks | 0 … `name_entry_ticks` | Menu ticks since name entry opened (real time, paused-independent) |
| Length | `name_entry_ticks` | int ticks | 900-3600 (1800) | `name_entry_seconds` (Save, 30) × 60 |

**Output Range:** 0-1800 ticks; display 0-30. **Example:** elapsed 1,500: left 300, shows 5. Elapsed 1,741: left 59, shows 1. Elapsed 1,800: left 0, unfinished slots take initials, `submit_run` is called.

**F6. Hold-to-confirm**

`fires = held_ticks >= hold_confirm_ticks`; `segments = (4 × min(held_ticks, hold_confirm_ticks)) div hold_confirm_ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Held ticks | `held_ticks` | int | 0 up | Continuous **`fire.held_ticks`** of the activating device (Input Rule 12). *(Amended 2026-11-03, wave 5 batch 2: `start.held_ticks` is **not** counted. Wherever Start carries another meaning - Pause, Credits, Continue-adjacent screens, Settings opened from Pause - a hold must not be startable with Start, so the rule is simply **Fire only, everywhere**, which also removes the per-screen exception list.)* |
| Hold length | `hold_confirm_ticks` | int ticks | 30-120 (60) | 1.0 s |
| Segments | `segments` | int | 0-4 | Filled bar steps (stepped, no tween) |

**Output Range:** `segments` 0-4; fires once, on the tick `held_ticks` reaches the length; release before then resets to 0. **Example:** held 45 → 180 div 60 = 3 segments; held 59 → 236 div 60 = 3, no fire; held 60 → 4 and fires.

**F7. Plane card width**

`card_w = (360 - 2 × card_margin - (P - 1) × card_gap) div P`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Planes listed | `P` | int | 1-4 (more scroll) | Available planes |
| Margin / gap | `card_margin`, `card_gap` | int px | 16 / 8 | Screen edge and card spacing |

**Output Range:** 76-328 px. **Example:** P = 2: (360 - 32 - 8) div 2 = 160. P = 3: 312 div 3 = 104. P = 4: 304 div 4 = 76 (Target; trait rows use icons only below 100 px).

**F8. Rim-light segments**

`seg_w(i) = card_w div k + (i < card_w mod k ? 1 : 0)` for `i = 0 … k-1`, `k` = slots on the card in slot order

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Slots on card | `k` | int | 1-4 | Slots hovering or locked on this card |
| Card width | `card_w` | int px | 76-328 | F7 |

**Output Range:** `Σ seg_w = card_w`. **Example:** `card_w` 160: k = 1 gives [160]; k = 3 gives [54, 53, 53] (160 = 3 × 53 + 1); k = 4 gives [40, 40, 40, 40].

**F9. Resume beat**

`lit = (3 × t) div resume_beat_ticks`; resume when `t >= resume_beat_ticks`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Beat tick | `t` | int | 0 … `resume_beat_ticks` | Menu ticks since the owner resumed |
| Length | `resume_beat_ticks` | int ticks | 0-90 (45) | 0 disables the beat |

**Output Range:** `lit` 0-3. **Example (45):** t 0-14 gives 0 pips, 15-29 gives 1, 30-44 gives 2, t = 45 gives 3 and the game runs.

**F10. Board row width budget (co-op lead row, worst case)**

`row_w = rank_w + initials_w + more_w + plane_w + score_w + stage_w + badge_w` and `row_w <= row_inner_w`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Rank | `rank_w` | px | 26 | 2 digits × 11 (Localization F3, S tier) + 4 gap; same for Bengali digits |
| Initials | `initials_w` | px | 27 | 3 Latin characters × 9 advance (proposal) |
| "+N" tile | `more_w` | px | 18 | 14 + 4 gap |
| Plane icon | `plane_w` | px | 18 | 14 + 4 |
| Score | `score_w` | px | 111 | 9 digits × 11 + 2 separators × 4 (Localization F3) + 4 |
| Stage | `stage_w` | px | 15 | 1 digit × 11 + 4 |
| Badges | `badge_w` | px | 34 | "C" and "1CC" tiles, 2 × 14 + 2 + 4 |
| Inner width | `row_inner_w` | px | 328 | 360 - 2 × 16 margin |

**Online board rows (added 2026-11-03, wave 5):** an online row also carries a player **handle**, and at full handle length the worst case computes to **348 px > 328**. The row therefore shows the handle **cut to 8 characters + `...`** (full handle in the focused row's detail strip), and the date is shown as a **relative date in the detail strip**, not in the row (Online Rule 13).

**Output Range:** 249 px used, 79 px spare (24%). **Example:** 26 + 27 + 18 + 18 + 111 + 15 + 34 = 249 ≤ 328. The Bengali digit set uses the same grid, so the row is the same width in both languages; the 79 px spare covers the text-size step. The initials advance (9 px) is a proposal until the font spike.

> Decided under auto-approve (2026-11-03): all numeric defaults in Tuning Knobs. Hold 60 ticks matches the 1 s convention for destructive confirms; 45-tick commit is long enough to see the last READY stamp and to cancel; 30 s AFK equals the name-entry timer.

## Edge Cases

**Title and boot**
- **If Save loads in state Recovered, Reset, ReadOnly or Unavailable**, Title opens normally and shows the matching Save notice once as a toast (queue rule 17); the game never blocks on it.
- **If the Web gate click lands on a Title item**, it only leaves the gate; the item is not activated.
- **If a pad and the keyboard press Confirm on START GAME in the same tick**, the first in event-arrival order becomes slot 0 (Input Rule 4).
- **If START GAME is activated by pointer**, the Lobby opens with no joined slot and a hint line "Press START on a controller or keyboard"; if nobody joins for `lobby_idle_ticks`, it returns to Title.
- **If Drone is pressed during Attract**, it returns to Title and does not toggle the language (input consumed).
- **If the language chip is toggled while a toast is showing**, the toast text updates on the next frame.

**Lobby**
- **If two slots lock the same plane**, the run starts normally with both on that plane, each in its own slot colourway (Rule 20a). The same holds for three or four slots on one plane.
- **If a slot presses Confirm on the same tick another slot joins**, both events apply in slot order; the counter resets once.
- **If a Locked slot's pad disconnects**, the slot returns to Empty with a toast, the counter resets, and if `joined` is now 0 and slot 0 was the only one, the Lobby returns to Title.
- **If a device that already owns a slot presses Start in the Lobby**, it acts as Confirm for that slot (no second join).
- **If the idle timeout fires on the same tick as a commit**, the commit wins.
- **If a slot is released by AFK at the tick the counter would start**, the counter starts the next tick with the new `joined` count.
- **If `plane_cards` lists only one available plane**, the cursor still shows and Confirm works (no wrap needed).
- **If a pad was Locked and then another player joins mid-countdown**, the countdown cancels; the first player's stamp stays.
- **If the stage fails to load after commit**, the Lobby re-opens with every slot Locked and an error toast; Session has not been started (the call is made after a successful pre-load; → ADR).

**Drop-in and pause**
- **If the drop-in picker is open and the whole run ends (game over)**, the pick is cancelled and the Results flow starts.
- **If two free pads press Start in the same tick mid-run**, each gets its own pick in event-arrival order (lowest free slot first, Input F7).
- **If the pausing slot is also in Continue**, its countdown freezes (Session edge case) and the pause menu works as normal.
- **If a non-owner slot presses Start while paused**, nothing happens and its tag stays dimmed; no "wrong player" error sound.
- **If the owner holds Quit and a pad disconnects**, the hold is cancelled and the disconnect overlay opens.
- **If Settings is open in Pause and the window loses focus**, the menu stays; the reason line changes to FOCUS and no auto-resume happens.
- **If Resume is pressed during the beat**, the extra press is ignored (no skip); the beat always finishes.
- **If the game is paused on the same tick a boss dies**, pause wins; the tally starts after resume (the tick order is Input's).

**Results and name entry**
- **If the run is GAME_OVER with a score of 0**, Results shows, name entry is skipped (unranked), and records still update.
- **If Confirm is pressed twice within the lock window**, only the first valid one after tick 30 counts; Save's dedupe also protects against a double submit (Save edge case).
- **If a player in a co-op run finishes initials and another does not**, the finished slot's wheel locks; the timer continues for others.
- **If the keyboard player types a lowercase letter**, it is stored upper case; `!`, space and Bengali letters are rejected with `sfx_ui_deny` and no change (Save Rule 12).
- **If two slots use KB1 and KB2 in name entry**, typing is disabled and both use the wheel.
- **If the pad used at name entry disconnects**, that slot becomes Done with its last-used initials; no pause (Input Rule 28 applies to Stage and Tally only). **Unless `access.untimed_menus` is on:** the slot is **held** (controller-lost plate, `menu.name.controller_lost`, with a **DROP** action) until the pad returns or a player drops it; the shared timer is already stopped under that option (Rule 51). *(Amended 2026-11-03, wave 5; aligns with accessibility-options.md.)*
- **If `submit_run` raises `save_failed`**, the Board still opens, shows the entry for this session, and shows the failure toast (Save Rule 21).
- **If the player presses Play again and a pad has since disconnected**, the Lobby opens with that slot Empty and a toast.

**Boards and settings**
- **If a stored board has an unknown plane id**, its **solo** entries are still reachable: the board shows an extra **Solo sub-tab chip** with a generic plane icon and the raw id in Latin cut to 8 characters + `...` (Rule 40). The plane-select list does not offer that plane. *(Corrected 2026-11-03, wave 5: the earlier text said the tab was hidden and the entries appeared on co-op boards - a solo entry never appears on a co-op board, so those records were unreachable.)*
- **If the 1CC filter hides every row**, the screen shows "No scores yet" and the filter label stays focusable.
- **If a setting write fails (`save_failed`)**, the value stays applied in memory, the toast shows, and the file stays dirty for the next close (Save Rule 21).
- **If Settings is closed with no change**, no write happens (Save edge case).
- **If TATE is selected on a phone**, the item is hidden (Display edge case); a saved TATE from another device is ignored.
- **If Reset display is held while the TATE confirm is open**, the reset wins and the dialog closes.
- **If a language has no string for a key**, Localization falls back to English and never shows a key (Localization Rule 4).
- **If Bengali text is wider than its plate**, the plate grows downward to at most 3 lines (Localization edge case); button rows are measured so the list scrolls instead of clipping.
- **If the text-size step is raised**, list rows grow in height, lists scroll, plane cards switch to a 2-row trait layout; nothing is clipped.

**Platform**
- **If Quit game is activated on PC**, a Yes / No dialog (default No) appears; Yes calls `get_tree().quit()` after `commit_settings` if dirty.
- **If the mouse moves over an item while a pad is in use**, focus follows only until the next pad input; no hover-only information exists.
- **If a menu is opened in TATE**, all layout and pointer mapping come from the presenter (Display F7); Menus has no rotation code.

## Dependencies

**Upstream (this system depends on)**

| System | Hard/Soft | Interface |
|---|---|---|
| Input and player mapping (2) — GDD | Hard | Nav, Confirm, Cancel, `held_ticks`, slot-tagged events, join requests, pause owner, disconnect data, remap API, glyph family. |
| Save, settings and high scores (26) — GDD | Hard for boards and settings screens (Vertical Slice); Soft at MVP | Boards, `preview_rank`, `submit_run`, `set_setting`, `commit_settings`, `reset_settings`, `clear_scores`, `save_failed`. Without Save (Rule 31 there) the Board shows "No scores yet" and Settings shows defaults without persisting. |
| Game events and session (1) — GDD | Hard | `start_run`, `abandon_run`, slot states, `RunRecord`, `run_ended_by`, aggregates, `forfeit_slot`. |
| Localization (27) — GDD | Hard | `text`, `text_both`, `format_int`, `set_language`, `font_size_px`. |
| Display scaler and bezel (4) — GDD | Hard | 360x640 canvas, pointer mapping, display settings and TATE confirm. |
| Plane kits and drones (11) — GDD | Soft | Plane ids, name and trait text keys for cards. |
| Co-op and Team Chain (18) — GDD | Soft | Player colour, ring pattern, pips. |
| Art bible | Hard (document) | §2, §4.4, §4.7, §7.5-7.9. |

**Downstream (systems that depend on this one)**

| System | Hard/Soft | Interface |
|---|---|---|
| Game events and session (1) — GDD | Hard | Receives `start_run`, `abandon_run`, plane choices. |
| HUD (20) — [GDD](hud.md) | Soft | Hosts the drop-in pick plate and join plate (HUD Rule 23); pause owner tag via `set_slot_emphasis`. |
| Stage-end tally (21) — [GDD](stage-end-tally.md) | Soft | Sits between Stage and Results (every stage, incl. the last); shares Results visual language. |
| Accessibility options (28) — [GDD](accessibility-options.md) | Hard | Settings shell and entry registration; text-size reflow; `confirm_style`, `confirm_hold`, `untimed_menus`; first-run prompt; PRACTICE tag. |
| Audio (24) — [GDD](audio.md), VFX (25) — [GDD](vfx-and-screen-feedback.md) | Soft | UI cue ids; transition spec. |
| Touch controls (31) — [GDD](touch-controls.md) | Soft | Pointer verbs; 9 mm touch targets (TF7); TOUCH binding on START GAME; `touch_solo`; landscape prompt; Touch section. |
| Tutorial (30) — [GDD](tutorial.md) | Soft | Title item, Lobby SCHOOL mode, school screens, drill Pause items, tip rows, Results offer line. |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | Soft | Online tab, Play choice (Boss Rush, Single Boss), consent / handle / delete screens. |
| Plane kits Sentry, Breaker (29) — [GDD](plane-kits-sentry-breaker.md) | Soft | Plane cards at Target (`plane.sentry.*`, `plane.breaker.*`). |

**Amendments to other docs** (the main session applies these)

1. `design/gdd/systems-index.md` row 22: status `**Designed** (pending review) — [GDD](menus-title-plane-select.md)`; Depends on `2, 26` stays and add soft `1, 4, 11, 18, 27`. Progress tracker GDDs written +1. Dependency notes "Display scaler (4)" and "Input (2)" lines: mark 22 done.
2. `design/gdd/game-events-and-session.md`: Rule 1 and the Run-flow table: "A run starts when the **Lobby commits** (every joined slot Locked and `start_delay_ticks` elapsed); Menus calls `start_run(selections)` with the locked slots, each `joined_at_run_start = true`." Pre-run lobby slots are held by Menus' `LobbyModel`; slot Selecting remains the mid-run drop-in state. Add `abandon_run()` (quit to title → ABANDONED). Rule 7: drop-in pick auto-cancels after `dropin_pick_ticks` (900) and returns the slot to its previous state. UI Requirements: Results screen and Pause menu owned by Menus (22); Tally by 21; continue prompt and pick plate geometry by HUD (20). Interactions row Menus (22): "start_run, abandon_run, plane choice; reads slots, RunRecord".
3. `design/gdd/input-and-player-mapping.md`: Rule 3/6: a Confirm (Fire or Start) on the Title START GAME item is a join request for that device, bound to slot 0. Add `bind_device(device, slot)` for "Play again". Add a provisional `typed_char(slot, char)` event for name entry. Open Question 4 (resume beat): closed by Menus Rule 30 (45-tick beat, no invulnerability). Dependencies row Menus (22) now has a GDD.
4. `design/gdd/save-settings-high-scores.md`: (a) Rule 16 schema: replace `display.window_mode` (windowed/fullscreen), `display.integer_scale`, `display.bezel` (auto/off) with the Display scaler keys `display.scale_mode` (`auto`, `pixel_perfect`, `fill`; default `auto`), `display.window_mode` (`windowed`, `fullscreen`), `display.tate_mode` (`off`, `cw`, `ccw`), `display.bezel_style` (`art`, `plain`), `display.window_size` (two ints, windowed only). (b) Add `profile.last_plane` string[4] (default `["", "", "", ""]` meaning first plane) owned by Menus (22), updated at commit. (c) Add `access.confirm_style` (`hold`, `double_tap`; default `hold`) registered by Accessibility (28). (d) Rule 20 triggers: add "Title language chip toggle" (Menus, calm moment). (e) Visual/Audio "Name entry" line: repeat "after 15 ticks every 6" becomes "Input nav repeat (18 / 6)". (f) Open Question 4 (save before name entry): kept at confirm; Menus runs name entry before `submit_run`. Open Question 7: no combined co-op tab at MVP. Open Question 9: raw id in Latin and a generic icon. Dependencies: Menus (22) now has a GDD.
5. `design/gdd/localization.md`: Open Question 7 (Latin-only initials) is closed (Save Rule 12, Menus Rule 36). Add the Menus key families (UI Requirements) to `ui_menu.csv`; the language-chip labels `বাংলা` / `English` are a non-translated exception to the string lint. Dependencies: Menus (22) now has a GDD.
6. `design/gdd/display-scaler-and-bezel.md`: UI Requirements: "Display settings screen and TATE confirm are defined by Menus (22) Rules 43-45; owner of the settings keys is Display". Persisted settings list matches the amended Save schema.
7. `design/gdd/coop-and-team-chain.md` Open Question 9: close: "Any bound slot pauses with Start/Back; the pausing slot owns the menu; others are ignored (Input Rule 25, Menus Rules 27-28)."
8. `design/gdd/plane-kits-lancer-leech.md`: add the plane-card text keys (`plane.<id>.name/tag/style/fire/hold/drone`) as a data requirement; Dependencies: Menus (22) now has a GDD.
9. `design/art/art-bible.md` §7.8: add "Pause panel: a compact plate over the frozen field (the simulation is stopped); Lobby layout is four fixed 90 px slot columns under the plane cards"; §7.2 "lower third never used for UI" gets the exception "Pause and Disconnect panels while the game is stopped". Menus draw on a CanvasLayer above the §6.8 layer 11.
10. `design/gdd/systems-index.md` "Dependency notes": Menus (22) must be listed by HUD (20), Tally (21), Accessibility (28), Touch (31) in Dependencies.
11. `docs/architecture` (→ ADR): menu host under the SubViewport; `MenuModel` / `LobbyModel` ticked at 60 Hz with `process_mode = ALWAYS`; `start_run` pre-load handshake.

## Tuning Knobs

All in `data/menus/menu_rules.tres` unless noted; no magic numbers in code (ADR-0001).

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `start_delay_ticks` | 45 | 0-120 | No time to see the last stamp or cancel a mistake | Solo players wait | F2; Lobby feel |
| `afk_release_ticks` | 1,800 (30 s) | 900-3,600 | A thinking friend is kicked | A sleeping slot stalls the lobby | F3; name entry 30 s |
| `lobby_idle_ticks` | 3,600 (60 s) | 1,800-7,200 | Lobby closes while players chat | Abandoned cabinet sits in Lobby | F3; attract |
| `lobby_warn_ticks` | 600 | 300-900 | No warning | Warning too early | F3 |
| `dropin_pick_ticks` | 900 (15 s) | 600-1,800 | Not enough time to read two cards | Non-hittable slot lingers (Session Rule 7) | Session; HUD plate |
| `hold_confirm_ticks` | 60 | 30-120 | Accidental quit | Feels like a freeze | F6; Input `held_ticks` |
| `resume_beat_ticks` | 45 | 0-90 | Hands not on the controls | Slow retry loop | F9; Input Rule 27 |
| `results_input_lock_ticks` | 30 | 15-60 | Button-masher skips Results | Player waits | Results flow |
| `reveal_interval_ticks` | 15 | 10-30 | Rows blur by | Slow | Art bible §7.4 (0.25 s) |
| `name_entry_ticks` | 1,800 (30 s) | 900-3,600 | 4P rushed | Stalls Results | Save `name_entry_seconds` (shared value); F4, F5 |
| `attract_idle_ticks` | 1,800 (30 s) | 600-7,200 | Menu hides while reading | Screen burn-in on idle | Attract |
| `attract_era_ticks` | 1,200 (20 s) | 600-2,400 | Palette churn | Boring | Attract |
| `transition_frames` | 12 | 8-24 | Abrupt | Slow menus | Art bible §7.7 |
| `card_margin` / `card_gap` | 16 / 8 px | 8-24 / 4-16 | Cards crowd | Cards shrink | F7 |
| `menu_item_h` | 32 px | 28-48 | Tight Bengali line box (24 px) | Short lists | Localization F7 (line box 24) |
| `toast_queue_max` | 3 | 1-5 | Lost notices | Toast spam | Rule 17; `save_toast_ticks` 90 (Save) |
| `credits_px_per_s` | 24 | 12-60 | Boring | Unreadable | Credits |
| `reduce_motion` | off | on / off | - | - | Accessibility (28) (`access.reduce_motion`); read by Menus for Credits: auto-scroll off, manual mode (Rule 46) |
| `confirm_style` | `hold` | `hold`, `double_tap` | - | - | Accessibility (28) |
| `confirm_hold` | NORMAL | SHORT / NORMAL / LONG | - | - | Accessibility (28) (`access.confirm_hold`) |
| `double_tap_window_ticks` | 120 | 60-240 | Cannot double-tap | Accidental confirm | `confirm_style` |

Rationale: `hold_confirm_ticks` 60 = 1 s, art bible §7.8 destructive-action rule; `afk_release_ticks` = 30 s keeps one idle friend from blocking three; `resume_beat_ticks` 45 = 0.75 s, short enough to keep the retry loop, long enough for a thumb to find the stick.

**Owned elsewhere:** `nav_delay` / `nav_repeat` (Input); `name_entry_seconds`, `board_size`, `initials_length`, `save_toast_ticks` (Save); `tate_confirm_seconds`, `display_reset_hold_seconds` (Display); `bn_width_reserve_pct`, `bn_size_s`, `digit_grouping` (Localization); `continue_seconds`, `starting_lives` (Session); focus pulse limits (art bible §7.7).

## Visual/Audio Requirements

**Layers.** Menus draw on their own CanvasLayer above art bible §6.8 layer 11. The only time a menu panel overlaps the gameplay field is Pause and the Disconnect overlay, while the simulation is stopped (Open Question 2). The drop-in pick lives only in the HUD strip. Nothing menu-related is drawn during live play over enemy bullets (layer 8). No Void Indigo or Ink fills; no orb, rice, needle or ring shapes as icons or cursors (the slot ring is an annulus drawn as a plated frame, not a free ring).

**Style (art bible §7.8).** Rectilinear chamfered plates, Cabinet Char `#1E1B18` fill, `#5A5148` edge; Cream `#F4EBD6` text with the 1 px `#14110E` outline on all 8 sides; Ember Gold `#FFC93C` for score and chain only; **Alarm Red `#E03A3E` is never a text fill** — it is the bar fill, plate edge, end-cap and glyph fill, and a corruption/failure state is carried by Cream (or the style guide's red *text* token) words plus an Alarm Red plate edge and/or an error glyph (`design/ux/arcade-ui-style.md` 3.1 rule 3 and art bible 4.1 / 7.10 own the palette rule; amended 2026-11-03, UX amendments wave 5). All positions are integers; easing is stepped 3-4 positions. Title and Lobby use the neutral warm palette; Results GAME OVER uses the cold desaturated dusk with one warm focal light; Results ENDING and Board use warm tally light.

| Item | Spec (px at 1x on the 360x640 canvas) |
|---|---|
| Menu list | Plate 216 px wide, centred; item height 32 (`menu_item_h`); 4 px gap; 5 Title items = 176 px; list top y 392 |
| Play choice (Stretch) | Same plate as the Menu list (216 wide, `menu_item_h` 32, 4 px gap), list top y 392; items MAIN (default focus), BOSS RUSH, SINGLE BOSS; locked modes are not listed (3 items = 104 px) *(added 2026-11-03, consistency check)* |
| Boss select (Stretch) | Menu list plate; one row per boss in `bosses_beaten`, in `rush_order` (era order); row = boss name (M) left, best Single Boss score (S, Gold) right; PRACTICE tag plate when a game-speed assist is on (OL Rule 45); never-beaten bosses are not listed; at most 4 rows visible, then the list scrolls *(added 2026-11-03)* |
| Touch row pitch (TF7) | On a touch device every focusable row, tab and button is `touch_item_h = max(menu_item_h, min_target_canvas_px)` tall (Touch TF7: 55 at x3 / 458 dpi, 57 at 420 dpi FILL, 32 on a 264 dpi tablet), 4 px gap, full plate width; a list that no longer fits its area scrolls with the focused row kept visible; pad / keyboard keep `menu_item_h` 32 *(added 2026-11-03, consistency check)* |
| Focus | 3 px Cream border, arrow glyph 8x8 offset 2-3 px left of the plate; pulse ≤ 40% opacity, ≤ 2 Hz, one element |
| Title logo | `logo_title_bn` XL above `logo_title_en` XL, equal weight, y 72-200; hi-score line (S tier, Gold) y 8; language chips top right, 2 × 56x20 |
| Plane card | `card_w` × 296 px, y 72-368 (F7); pedestal and pilot idle animation top 120 px; name (M) , tagline (S), style tag plate, 3 trait rows of 24 px (14x14 button glyph + text, 2 lines max) |
| Slot columns | 4 × 90 px, y 392-512 (120 px); frame in the slot's ring pattern (solid, dashed, dotted, double), 3 px colour notch left, pips top; join plate, Choosing token or READY stamp inside |
| READY stamp | Plated tile, Cream text + check glyph, drops in 4 steps over 8 frames, no flash, no pulse |
| Commit bar | 4-segment bar, y 520, shows during `ready_ticks`; clears on any reset |
| Prompt bar | y 600-640: glyph + verb pairs for the current device (Confirm / Cancel / language) |
| Rim light | Warm 3 px rim along the card top and sides, split per F8 in slot colours with the pattern ticks at segment boundaries |
| Hold bar | 4 stepped segments, 12x6 each, beside the item; Cream fill, Ember Gold on completion frame |
| Toast | Plated strip 328x24 at y 560, 8-frame in/out |
| Pause panel | 216 x 192 plate centred at y 224; owner tag 90x20 with slot frame; no full-screen dim and no tint |
| Name wheel | Three 28x36 plated slots, 6 px gap, focused slot 3 px Cream border + arrow; characters L tier 24 px; up/down chevron glyphs above and below. **3-4 players:** a 2x2 grid of 160x136 blocks at x = 16 / 184, y = 104 / 264 (grid ends y 400), one block per played slot with its own wheel, P-tag and device glyph; **3P centres P3 at x = 100** (Rule 36) |
| Results | Per slot row 328 x 56 (1-2P) or 4 columns of 80 x 220 (3-4P); hero number is best chain, Gold, 24 px. **3-4P score plates use D12** (9 digits, Western grouping, 78 px, centred in the 80 px column) with a **D10 fallback applied to all columns together** when D12 does not fit; INDIAN grouping is the 81 px worst case. Confirm the D10 plate width and the 81 px INDIAN case in the font spike (Localization F3) |
| Board | 10 rows × 28 px = 280 px (F10); tabs 24 px high |
| Bezel | Presenter shows stage name / hi-score on idle screens (Display Rule 11.1); not Menus' job |

**ASCII mock-ups** (1 column ≈ 6 px, 1 row ≈ 16 px; vertical spacing compressed where noted; Bengali shown as the English source)

Title (Lobby entry from START GAME):
```
+----------------------------------------------------------+ y0
| HI 000,000,000                    [ বাংলা ][ English* ]  | hi-score S / language chips
|                                                          |
|              [ LOGO  bn   XL, gold ]                     | y72
|              [ LOGO  en   XL, gold ]                     | y150-200
|                                                          |
|        . . . four planes, slow formation flyby . . .     | backdrop (warm dusk)
|                                                          |
|                  +--------------------+                  | y392
|               >  |     START GAME     |                  | focus: 3 px border + arrow
|                  +--------------------+                  |
|                  |    HIGH SCORES     |                  |
|                  |     SETTINGS       |                  |
|                  |      CREDITS       |                  |
|                  |       QUIT         |                  | hidden on Web / mobile
|                  +--------------------+                  |
| [A] Confirm   [X] Language                               | prompt bar y600 (glyphs per device)
+----------------------------------------------------------+ y640
```

Plane select, 2P with P3/P4 empty (P1 Locked on Lancer, P2 Choosing on Leech):
```
+----------------------------------------------------------+
|              CHOOSE YOUR PLANE                           | y16 header (S/M)
|  +--------------------------+ +--------------------------+| y72  cards: 160 px each, x16 and x184
|  |#### P1 rim ####   LANCER | |== P2 rim ==      LEECH  || rim = slot colours (F8)
|  |   [ pedestal + plane ]   | |   [ pedestal + plane ]  ||
|  |   [ pilot idle      ]    | |   [ pilot idle      ]   ||
|  |  "I am the spear."       | |  "Nothing gets away."   ||
|  |  [BURST AND HOLD]        | |  [LATCH AND SUSTAIN]    ||
|  |  [A] 3-way wide shot     | |  [A] 2-way narrow shot  ||
|  |  [A hold] Laser: safe    | |  [A hold] Focus: strong ||
|  |  [X] Drones park + laser | |  [X] Drones latch on    ||
|  +--------------------------+ +--------------------------+| y368
|                                                          |
| +--P1 (solid, 1 pip)-+ +--P2 (dashed, 2)-+ +--P3------+ +--P4------+ y392-512
| |  LANCER   [READY v]| |  < LEECH >      | | Press    | | Press    |
| |  vermillion token  | |  yellow token   | | START to | | START to |
| |                    | |                 | | join     | | join     |
| +--------------------+ +-----------------+ +----------+ +----------+
|  [ #### starting ####                   ]                | y520 commit bar (only while ready)
| [A] Lock  [B] Back                                       | y600
+----------------------------------------------------------+
```

Pause (P2 paused in a 2P stage; strip y0-47 is the live HUD, unchanged):
```
+----------------------------------------------------------+
| HUD STRIP (P1 | P2) -- frozen                            | y0-47
|                                                          |
|          (frozen play field, bullets visible)            |
|            +--------------------------------+            | y224
|            |  P2  (dashed frame, 2 pips)    |            | owner tag
|            |            PAUSED              |            |
|            |  >  RESUME                     |            |
|            |     SETTINGS                   |            |
|            |     QUIT TO TITLE   [----]     |            | hold bar, 4 steps
|            |   Score will not be saved      |            |
|            +--------------------------------+            | y416
| P1 controls dimmed                                       |
+----------------------------------------------------------+
```

Results, 2P game over (P2 continued once):
```
+----------------------------------------------------------+
|                   GAME OVER                              | cold dusk, one warm light
|                   RANK 2  NEW                            | one rank strip (team rank in co-op)
|                                                          |
|  P1 [Lancer]      4,200,000         2/2                  |
|     best chain 187   Critical Breaks 2                   |
|  P2 [Leech]         900,000         2/2                  |
|     best chain  96   Critical Breaks 0     [C x1]        |
|  ------------------------------------------------------  |
|  TEAM  5,100,000   best chain 187   CB 2                 |
|  Before continues: 5,700,000                             |
|                                                          |
| [A] Next (after 0.5 s)                                   |
+----------------------------------------------------------+
```
(The "1CC" tile shows only on an ENDING run for a slot with `one_credit_clear`; a GAME_OVER run never shows it.)

Name entry (2P, simultaneous):
```
+----------------------------------------------------------+
|                ENTER YOUR INITIALS          00:23        | shared timer (F5)
|                                                          |
|   P1 solid           P2 dashed                           |
|    ^   ^   ^           ^   ^   ^                         |
|  [ K ][ A ][ Z ]     [ L ][ E ][ E ]   <- focus 3 px     |
|    v   v   v           v   v   v                         |
|   editing             DONE v                             |
|                                                          |
| [Up/Down] Change  [Left/Right] Move  [A] OK              |
+----------------------------------------------------------+
```

High scores (Solo / Lancer, new entry highlighted):
```
+----------------------------------------------------------+
|  [Solo*] [Co-op] [Records]      [ Lancer* ][ Leech ]     |
|  filter: All                                             |
|   1  AAA  [L]  9,100,000   2   [1CC]                    |
| >[ 2  KAZ  [L]  4,200,000   2   [1CC] ]<  NEW            | 3 px border + arrow
|   3  BEE  [L]  3,000,000   2   [C]                      |
|  ...  (10 rows x 28 px)                                  |
|                                                          |
| [A] Play again   [B] Title                               |
+----------------------------------------------------------+
```

Disconnect overlay (2P, P2 pad lost):
```
+----------------------------------------------------------+
|        +------------------------------------+            |
|        | Controller disconnected            |            |
|        | P2 (dashed frame)                  |            |
|        |  Reconnect: press START on a pad   |            |
|        |  Use keyboard: press Enter / 1     |            |
|        |  Drop P2        [----]  (hold)     |            |
|        |  > Wait                            |            |
|        +------------------------------------+            |
+----------------------------------------------------------+
```

**Audio.** Cue table in Core Rules. All UI-bus, never competing with the 8-voice bullet pool. No rumble. No voice. Menus play no sound while a stage is live except the pause and drop-in cues.

## UI Requirements

This system *is* the UI. Screens (each needs a UX spec):

| Screen | Owner device | Elements |
|---|---|---|
| Boot, Web gate | any | Wordmark, loading bar; bilingual "Click or press a key" line |
| Title | shared | Logo, hi-score, 5 items, language chips, prompt bar, toasts |
| Play choice, Boss select (Stretch) | shared | Mode list (MAIN / BOSS RUSH / SINGLE BOSS); boss list with best score and PRACTICE tag |
| Lobby / plane select | per slot | Plane cards, 4 slot columns, rim light, READY stamps, commit bar, AFK/idle warnings |
| Drop-in pick | per slot | Mini plane cards in the HUD strip (HUD hosts) |
| Pause | owner | Owner tag, Resume, Settings, Quit (hold), reason line |
| Disconnect overlay | owner | Per Waiting slot rows with Reconnect / Use keyboard / Drop / Wait |
| Results | any bound slot | Per-slot rows, badges, team block, rank, lock timer |
| Name entry | per slot | 3-slot wheel per player, shared timer |
| High scores, Records | shared | Tabs, filter, rows, detail strip |
| Settings | shared / owner | Audio, Display, Language, Controls, Accessibility |
| TATE confirm | shared | Countdown, Keep, Cancel (default) |
| Credits | shared | Scrolling list |

**Bilingual strings** (drafts for native-speaker review by Localization (27); menus are single-language; the title, banners and names are bilingual; equal visual weight; +40% width reserved):

| Key | English | Bengali (draft) |
|---|---|---|
| menu.title.start | START GAME | খেলা শুরু |
| menu.title.scores | HIGH SCORES | সর্বোচ্চ স্কোর |
| menu.title.settings | SETTINGS | সেটিংস |
| menu.title.credits | CREDITS | কৃতজ্ঞতা |
| menu.title.quit | QUIT | বের হন |
| menu.gate.prompt | Click or press a key to start | শুরু করতে ক্লিক করুন বা একটি কী চাপুন |
| menu.select.heading | CHOOSE YOUR PLANE | বিমান বেছে নিন |
| menu.select.ready | READY | প্রস্তুত |
| menu.select.starting | Starting | শুরু হচ্ছে |
| menu.select.left | P{n} left | P{n} চলে গেছে |
| menu.select.idle_warn | Returning to title | শিরোনাম পর্দায় ফিরছে |
| menu.pause.title | PAUSED | বিরতি |
| menu.pause.resume | RESUME | চালিয়ে যান |
| menu.pause.settings | SETTINGS | সেটিংস |
| menu.pause.quit | QUIT TO TITLE | শিরোনামে ফিরুন |
| menu.pause.quit_warn | Score will not be saved | স্কোর সংরক্ষিত হবে না |
| menu.pause.focus | Paused - window lost focus | বিরতি - উইন্ডো সক্রিয় নয় |
| menu.hold | Hold to confirm | নিশ্চিত করতে ধরে রাখুন |
| menu.results.game_over | GAME OVER | খেলা শেষ |
| menu.results.ending | MISSION COMPLETE | অভিযান সফল |
| menu.results.rank | RANK {n} | র‍্যাঙ্ক {n} |
| menu.results.before_continues | Before continues: {n} | কন্টিনিউর আগে: {n} |
| menu.results.not_placed | Not in top {n} | *(bn: pending native review)* |
| menu.results.not_ranked | Not ranked | *(bn: pending native review)* |
| menu.results.practice | PRACTICE | *(bn: pending native review)* |
| menu.results.stage_of | Stage {n} / {m} | *(bn: pending native review)* |
| menu.results.next | NEXT | *(bn: pending native review)* |
| menu.name.done | DONE | *(bn: pending native review)* |
| menu.name.editing | EDITING | *(bn: pending native review)* |
| menu.name.no_limit | No time limit | *(bn: pending native review)* |
| menu.name.controller_lost | Controller lost | *(bn: pending native review)* |
| menu.name.drop | DROP | *(bn: pending native review)* |
| menu.name.latin_only | Latin letters only | *(bn: pending native review)* |
| menu.scores.empty_1cc | No 1CC scores yet | *(bn: pending native review)* |
| menu.credits.empty | No credits available. | *(bn: pending native review)* |
| menu.credits.licence_missing | Licence text unavailable. | *(bn: pending native review)* |
| menu.name.heading | ENTER YOUR INITIALS | আদ্যক্ষর লিখুন |
| menu.scores.empty | No scores yet | এখনও কোনো স্কোর নেই |
| menu.scores.play_again | PLAY AGAIN | আবার খেলুন |
| menu.settings.language.label | Language | ভাষা |
| menu.confirm.clear_scores | This cannot be undone | এটি ফেরানো যাবে না |
| menu.tate.keep | Keep this rotation? | এই ঘূর্ণন রাখবেন? |

Plane card keys (`plane.lancer.*`, `plane.leech.*`) are in the Core Rules table. Player tags stay "P1"-"P4" (Input Open Question 5). Initials are Latin in both languages (Save Rule 12); a Bengali key press on the wheel is refused with `sfx_ui_deny` and the hint `menu.name.latin_only`.

*(Keys added 2026-11-03, wave 5: `menu.results.not_placed`, `not_ranked`, `practice`, `stage_of`, `next`; `menu.name.done`, `editing`, `no_limit`, `controller_lost`, `drop`, `latin_only`; `menu.scores.empty_1cc`; `menu.credits.empty`, `licence_missing`. **English is the source; the Bengali column is deliberately left as "pending native review" rather than machine-drafted - the localisation lead fills it when `ui_menu.csv` is extended** (file name per [Localization (27)](localization.md) Rule 5, which owns it).** The glossary pair **"ALL CLEAR"** (the Tally's banner, stage-end-tally.md) and **"MISSION COMPLETE"** (`menu.results.ending`, the Results verdict) **are registered in `localization.md` Rule 30 (2026-11-03, wave 5 batch 2)** as two distinct terms - they are not synonyms and must not be merged by a translator.)*

📌 **UX Flag**: run /ux-design for the Title and Lobby (plane select), Pause and disconnect overlay, Results and name entry, and High scores screens before writing epics.

## Acceptance Criteria

Defaults used: `start_delay_ticks` 45, `afk_release_ticks` 1,800, `lobby_idle_ticks` 3,600, `lobby_warn_ticks` 600, `dropin_pick_ticks` 900, `hold_confirm_ticks` 60, `resume_beat_ticks` 45, `results_input_lock_ticks` 30, `name_entry_ticks` 1,800, `attract_idle_ticks` 1,800, `nav_delay` 18, `nav_repeat` 6, `card_margin` 16, `card_gap` 8, `board_size` 10, MVP planes Lancer and Leech, `stage_count` 2.

**Test setup:** `MenuModel`, `LobbyModel`, `PauseModel`, `NameEntryModel`, `ResultsFlow` and `HoldConfirm` are node-free `RefCounted` classes with an explicit `tick()` and **no RNG, no `delta`, no `Input` singleton**. Tests inject: scripted Input events (`nav(slot, dir)`, `confirm(slot)`, `cancel(slot)`, `held_ticks`), a stub Session (slot states, `start_run`, `abandon_run` call recorders), a stub Save (in-memory boards, `preview_rank` result, call recorders), and a stub Localization (`text`, `format_int`). Numbers are read from `data/menus/menu_rules.tres`, not hard-coded. Tests: `tests/unit/test_menu_model.gd`, `test_lobby_model.gd`, `test_pause_model.gd`, `test_name_entry.gd`, `test_results_flow.gd`, `test_menu_defs.gd`, in `extends SceneTree` style like `tests/unit/test_chain_tracker.gd`; integration `tests/integration/test_menus_flow.gd`. Manual evidence: `production/qa/evidence/menus/`.

Tags: [Unit] headless pure logic · [Integration] scenes and signals · [Perf] budget · [Manual] human/hardware.

### Boot, Title, navigation

- **AC-01 [Integration] (Rule 4):** boot order recorded as `Save.load_all`, `Localization.resolve_language`, Display first layout, then Title; Title's first frame is never earlier than the third event.
- **AC-02 [Integration] (Rule 5):** in a Web export the gate shows; the first click leaves it, the audio context is running, and the click does **not** activate START GAME; a desktop build shows no gate.
- **AC-03 [Unit] (F1, Rule 13):** list of 5 with item 0 disabled: from 4 `dir` +1 → 1; from 1 `dir` -1 → 4; one enabled item → focus stays.
- **AC-04 [Unit] (Rule 7, 8):** Title default focus is START GAME; nav events from any slot or device move the single shared focus; QUIT is absent when tag `web` is active.
- **AC-05 [Unit] (Rule 9):** Confirm by a pad on START GAME → Lobby slot 0 is Choosing and bound to that device; Confirm by pointer → Lobby with 4 Empty slots; pad Confirm and keyboard Confirm in one tick (pad first) → pad is slot 0.
- **AC-06 [Unit] (Rule 10):** Drone on Title toggles `bn`↔`en` through `set_language` exactly once per press, `commit_settings` is called once, and the stub shows `settings.language` updated; during Attract the same press only exits Attract.
- **AC-07 [Unit] (Rule 11):** with no input, Attract starts at tick 1,800 and cycles palettes at 1,200-tick steps; any input at tick 2,000 returns to Title and the input is not delivered to the menu.
- **AC-08 [Unit] (Rule 53):** `menu_screens.tres` lint: every `label_key` exists in both languages; every `target` resolves; every `setting_key` is in the Save schema; every `platform_tags` entry is one of `pc`, `web`, `mobile`, `switch`; item ids are unique per screen. A bad definition fails.
- **AC-09 [Unit] (Rule 17):** four toasts queued → the oldest non-Save toast is dropped (max 3); a Save notice is never dropped; each toast lasts 90 ticks.

### Lobby

- **AC-10 [Unit] (Rules 20-21):** slot 0 and 1 Choosing; slot 1 nav right moves only slot 1's cursor; slot 0's cursor is unchanged; wrap works on 2 planes.
- **AC-11 [Unit] (Rule 21):** Empty→Choosing (Start), Choosing→Locked (Confirm), Locked→Choosing (Cancel), Choosing→Empty (Cancel, device released); any other transition is rejected.
- **AC-12 [Unit] (F2):** both slots lock at tick T → commit at T+44 exactly once; P2 unlocks at T+20 and relocks at T+30 → commit at T+74.
- **AC-13 [Unit] (F2, Rule 23):** slot 2 joins at T+10 with slots 0 and 1 Locked → no commit until slot 2 locks, and the counter restarts at its lock tick.
- **AC-14 [Unit] (Rule 23):** commit calls `start_run` once with selections in slot order `[(0, lancer, dev), (1, leech, dev)]`, each `joined_at_run_start = true`; a second commit attempt is rejected.
- **AC-15 [Unit] (Rule 20):** two slots both lock `lancer` → commit succeeds with two Lancer entries.
- **AC-16 [Unit] (F3, Rule 24):** P1 Locked at 0, P2 Choosing, no input → P2 Empty at tick 1,800 and a "P2 left" toast; with P2 input at 1,500 → released at 3,300; with nobody Locked → never released by AFK.
- **AC-17 [Unit] (F3, Rule 24):** no input from any joined slot: warning shown from tick 3,000, Lobby closes to Title at 3,600; any input at 3,599 resets it.
- **AC-18 [Unit] (Rule 24, Input Rule 28):** a Locked slot's pad disconnects → slot Empty, counter reset, toast, no pause; if it was the only joined slot, Title opens.
- **AC-19 [Unit] (Rule 21):** the last joined slot cancels → Title; one of two cancels → Lobby stays with the other.
- **AC-20 [Unit] (Rule 25):** a fifth device Start → toast "Game full", no state change.
- **AC-21 [Unit] (F7):** `card_w` for P = 2, 3, 4 is 160, 104, 76; card x origins for P = 2 are 16 and 184.
- **AC-22 [Unit] (F8):** `card_w` 160 → k=1 [160], k=3 [54, 53, 53], k=4 [40, 40, 40, 40]; each sums to 160.
- **AC-23 [Unit] (Rule 22):** `profile.last_plane[1] = "leech"` → slot 1 joins with the cursor on Leech; empty value → first listed plane; `last_plane` is written at commit.
- **AC-24 [Manual] (Rule 19, pillar):** five testers see each card for 10 s; at least 4 of 5 can state, without help, that Lancer's hold-Fire makes it invulnerable and that Leech's drones latch onto enemies. Evidence: notes.
- **AC-25 [Manual] (Rule 18, Input AC-54):** four pads press Start within 10 s and lock; all four columns show distinct ring pattern, pips and colour; screenshot at 1x checked for the two equal-luma slots (P3, P4) being distinguishable in greyscale by pattern.

### Drop-in and pause

- **AC-26 [Integration] (Rule 26):** during a stage, Start on a free pad opens the pick; the game keeps ticking (tick counter advances); the pick is drawn only inside the strip (pixel check y ≥ 48 unchanged between frames); Confirm → Session slot Alive; at 900 ticks without Confirm the pick cancels and the slot returns to its previous state; Cancel cancels at once.
- **AC-27 [Integration] (Rule 27):** slot 1 pauses; slot 0's Confirm is ignored; slot 1's Nav moves focus; the owner tag shows P1/P2's pattern and pips; if slot 1's device disconnects, ownership passes to slot 0.
- **AC-28 [Unit] (Rule 28):** pause items are exactly Resume, Settings, Quit to title; default focus is Resume; Cancel or Start resumes; no Restart item in release builds.
- **AC-29 [Unit] (F6, Rule 29):** Quit held 59 ticks → segments 3, no action; 60 → fires, `abandon_run` called once, Save `submit_run` calls = 0; released at 59 → progress 0.
- **AC-30 [Integration] (Rule 29):** quit-to-title with score 900,000 → `run_ended_by = ABANDONED`, high-score data byte-identical to before (Session AC-35), Title loads, bindings cleared.
- **AC-31 [Unit] (F9, Rule 30):** resume at tick 0: lit 0 for 0-14, 1 for 15-29, 2 for 30-44; the game ticks first at beat tick 45; a second Resume press during the beat is ignored; with `resume_beat_ticks = 0` the game runs at once.
- **AC-32 [Integration] (Rule 30, Input AC-30):** Fire held through pause and resume: first game tick `pressed = false, held = true, held_ticks = 0`; the Start that closed the menu is consumed.
- **AC-33 [Integration] (Rule 31):** window blur → paused, reason FOCUS line visible, owner = lowest connected bound slot; on refocus the game stays paused until the owner resumes.
- **AC-34 [Integration] (Rule 32):** a pad disconnect in 2P → pause with an overlay row for that slot only; Resume refused while Waiting; "Drop P2" held 60 ticks → `forfeit_slot(1)` once; with "Wait" nothing changes.
- **AC-35 [Integration] (Rule 33, Save AC-44):** change `audio.sfx` in Settings from Pause, close → exactly one `settings.json` write; close with no change → zero writes.

### Results, name entry, boards

- **AC-36 [Unit] (Rule 34):** Confirm at Results tick 29 is ignored, at tick 30 accepted; ABANDONED never opens Results.
- **AC-37 [Unit] (Rule 35, Session F6):** for an ENDING run with P1 4,200,000 / chain [112, 187] / 2 CB / `one_credit_clear` true and P2 900,000 / chain [96] / `pre_continue_score_total` 600,000 / `continues_used` 1, Results shows team score 5,100,000, team chain 187, team CB 2, "Before continues 5,700,000", P2 "C x1", P1 "1CC" only if `one_credit_clear`, P2 without "1CC". Digits use `format_int`.
- **AC-38 [Integration] (Rules 34, 36, 37):** ranked run → `preview_rank` once on open, then name entry, then `submit_run` once; unranked run → no name entry, `submit_run` once; double Confirm within the lock → one submit.
- **AC-39 [Unit] (F4):** `Z`+up → `0`; `.`+up → `A`; `A`+down → `.`; `steps(A, Z)` = 13; holding up from `A` reaches the 20th step at the tick predicted by `t(k)` and 19 steps take 120 ticks.
- **AC-40 [Unit] (F5, Rule 36):** at elapsed 1,500 display 5; at 1,741 display 1; at 1,800 every unfinished slot is Done with `last_initials` (or its edited text if changed) and `submit_run` is called once.
- **AC-41 [Unit] (Rule 36):** typing `k` stores `K` and advances; `!`, space and `ক` are rejected with `sfx_ui_deny`; typing is disabled when two keyboard slots are editing; a slot with no connected device is Done with `last_initials[slot]`.
- **AC-42 [Unit] (Rule 36):** two slots edit simultaneously; slot 0's events never change slot 1's wheel; slot 0 Done while slot 1 edits; the run submits only when both are Done or at timeout.
- **AC-43 [Integration] (Rule 38):** after submit the Board opens on the run's board id with the new entry highlighted; "Play again" binds the pressing device to Lobby slot 0; Title returns to Title; bindings are cleared on Title.
- **AC-44 [Integration] (edge):** `submit_run` fails with `save_failed` → Board still opens, the entry is shown for the session, the error toast appears with `sfx_ui_save_error`.

### High scores and records

- **AC-45 [Unit] (Rule 39):** MVP tabs are Solo (Lancer, Leech), Co-op (2P, 3P, 4P), Records; no run-length selector with only `stage_count` 2; the 1CC filter hides non-`one_cc` entries; with no rows shows "No scores yet".
- **AC-46 [Unit] (Rule 40):** a co-op entry shows the lead player's initials and "+N"; focus shows a detail strip with every player's row; an entry with plane `"x"` shows a generic icon and raw `x`.
- **AC-47 [Unit] (F10):** the worst-case row computes to 249 px ≤ 328; the Bengali digit set gives the same width as the Western one (Localization F3 grid).
- **AC-48 [Unit] (Rule 41):** Records shows `best_chain[lancer]` as `[112, 187]` with dashes for planes with no data.

### Settings

- **AC-49 [Unit] (Rule 42, 47):** every Settings item with a `setting_key` reads and writes through `set_setting`; the audio steppers clamp at 0 and 10; the screen writes nothing on open; close commits once only if dirty.
- **AC-50 [Integration] (Rule 43, Display AC-12):** TATE change opens the confirm dialog with default focus Cancel; no input for 600 ticks reverts the value; Keep persists it; TATE is hidden on a phone; "Reset display" held for `confirm_hold` ticks (**60 at NORMAL**, 40 SHORT / 90 LONG) restores the four display defaults; the 2 s real-time `display_reset` hotkey is a separate path with its own length *(amended 2026-11-03, wave 5 batch 2)*.
- **AC-51 [Unit] (Rule 44, Input AC-42..44):** rebinding Bomb to Fire's key asks for a swap and swaps on yes; a reserved key (`Esc`, `F5`, `Tab`) is refused with the message; clearing the last Fire binding is refused.
- **AC-52 [Unit] (Rule 45):** Clear scores requires a 60-tick hold and calls `clear_scores` once; Quit game requires Yes with default No. *(Added 2026-11-03, wave 5 batch 2:)* a hold driven by **Start** never fires anywhere (F6: Fire only), and **Settings opened from Pause ignores Start entirely** (Rule 43), so a Start press there neither confirms nor resumes.

### Cross-cutting

- **AC-53 [Manual] (Rules 12, 51):** a keyboard-only tester (KB1) completes Title → Lobby → Stage → Pause → Settings → Results → name entry → Board → Title without a mouse or pad; a gamepad-only tester repeats it with no keyboard. Evidence: video.
- **AC-54 [Integration] (Rule 14, Display AC-14):** clicks activate items in windowed 540x960, fullscreen 2560x1440 and TATE CW; a click in the bezel activates nothing; a pointer click on Lobby never joins a slot; hover alone never activates.
- **AC-55 [Manual] (Rule 48):** the Title→Lobby→Stage and Pause open/close transitions, recorded at 60 fps, contain no full-frame luma change above one step of a 4-step wipe, no frame with white `#FFFFFF`, and no more than 3 changes per second; a photosensitivity analyser (Harding-class) passes. Evidence: report.
- **AC-56 [Manual] (Localization AC-48):** switching language on each screen changes every string and digit, moves no element, and no raw key or `⚠` appears; the Bengali build at 1x has at least 4 px headroom above matras and fits all plates with 40% extra width.
- **AC-57 [Unit] (Localization AC-35):** no quoted player-facing string in `src/**/menu*` or menu scenes; the language chip labels are the only allow-listed literals.
- **AC-58 [Manual] (Rule 51):** with the text-size step raised (when Accessibility 28 defines it), the Title, Lobby cards, Pause and Board rows reflow with no clipping and the lists scroll.
- **AC-59 [Unit] (determinism):** a scripted event stream of 3,600 ticks run twice through `LobbyModel`, `PauseModel` and `NameEntryModel` produces identical state hashes (no RNG, no `delta`).
- **AC-60 [Unit] (audio table):** Lobby join, lock, unlock, commit, deny, hold segments, name tick and language toggle each emit exactly their cue id; two joins in one tick emit at most 2 `sfx_ui_join_chime`.
- **AC-61 [Perf] (budget):** all menu models `tick()` ≤ 0.1 ms p99 on REF-WEB for a 4-slot Lobby; the 4P Lobby scene holds 60 fps on REF-WEB and REF-PHONE with ≤ 60 draw calls; committing settings causes no menu frame above 33 ms (Save AC-45).
- **AC-62 [Manual] (Web, Rule 50):** in Chrome and Firefox: audio plays after the gate click; record whether a gamepad press alone unlocks audio (unverified); QUIT is hidden; fullscreen from the Display item works; Esc leaves fullscreen and the item shows Windowed.

> Criteria drafted under auto-approve; `qa-lead` not consulted. Numbers in AC-12, AC-16, AC-21, AC-22, AC-31, AC-39 and AC-47 follow F2, F3, F7, F8, F9, F4 and F10.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Attract mode demo.** MVP cycles era backdrops only. Recommend a recorded input demo later (deterministic 60 Hz ticks plus a seed make it replayable, ADR-0001): ~30 s, no score, "DEMO" tag. Wanted, and for which tier? | Producer / game-designer | After Vertical Slice |
| 2 | **Pause panel over frozen bullets.** The art bible says nothing covers enemy bullets, and the lower third is never UI. A compact panel over a stopped field is proposed as an exception. Confirm, or move pause to a side-docked panel inside the strip? | art-director | Pre-Production UX |
| 3 | ~~**HUD drop-in plate geometry** at 1P (a 48 px strip with one column) and the strip change when N goes 1 to 2; HUD must host an at least 84x44 px pick plate.~~ **Closed 2026-11-03:** the HUD shows the next layout mode for display only while a slot is Selecting; the pick plate sits in that column (hud.md Rule 23, Rule 52 here). | HUD (20) GDD | HUD GDD |
| 4 | ~~Should duplicate planes in co-op be allowed (decided yes) or capped at one per plane for 2P (Four Planes, Four Games)?~~ **Closed 2026-11-09** (owner): free choice for every slot, duplicates allowed, told apart by colourway - Rule 20a. | game-designer | Closed |
| 5 | Add **Restart** to Pause? Decided no (a one-credit game; quit then start is 2 steps; ABANDONED rule). Revisit if playtesters ask. | game-designer | After playtest |
| 6 | Unverified Godot 4.7 Web: does a **gamepad** press count as a user gesture for the audio context? Test AC-62 on Chrome and Firefox. | godot-specialist | Web spike |
| 7 | Bengali strings above are drafts. Terms (Critical Break, Drone, Bomb, "Mission complete", "Before continues") need the glossary and native review. | Localization (27) | String soft freeze |
| 8 | ~~Remap UI depth: Menus builds a basic list at MVP; Accessibility (28) owns polish (per-pad maps, colour remap). Confirm the split.~~ **Closed 2026-11-03:** split confirmed; per-slot pad maps at VS (accessibility-options.md). | Accessibility (28) / ux-designer | Accessibility GDD |
| 9 | ~~Untimed option for name entry and drop-in pick (`access.untimed_menus`)?~~ **Closed 2026-11-03:** yes, `access.untimed_menus` (bool, default false) (accessibility-options.md). | Accessibility (28) | Accessibility GDD |
| 10 | Co-op board tab: "all co-op" combined view (Save Open Question 7). Defaulted to none. | game-designer | After first 4P boards |
| 11 | Touch menus: ~~tap targets (24 px minimum assumed)~~, swipe lists, safe area, back gesture on Android. **Partly closed 2026-11-03:** targets follow Touch TF7 (9 mm; 55 canvas px at x3 / 458 dpi) with a touch row pitch; safe area via the Display strip reserve (touch-controls.md). Swipe lists and the Android back gesture stay open. | Touch controls (31) | Target tier |
| 12 | `start_run` pre-load handshake (fail-safe if the stage fails to load) and where `LobbyModel` lives relative to Session (autoload vs run-flow controller). | ADR / lead-programmer | Before implementation |
| 13 | Plane card ability loop (a 2 s pre-authored strip of laser or latch on focus) as polish; MVP is static trait rows. | art-director | Polish |
| 14 | `typed_char` event design for keyboard name entry and non-QWERTY layouts (physical keys vs typed characters). | Input (2) | Input amendment |
| 15 | Credits content, names and licences list (fonts, music). Shape decided 2026-11-03 (wave 5): licence entries are a **`kind = LICENCE` record** in `credits.tres` with a `title` and a `body`; the body is never localised and is exempt from the string lint (Rule 46). Content and the body length are still the producer's call. | producer | Before release candidate |

> Decided under auto-approve (2026-11-03): attract is backdrop-only at MVP; pause panel exception flagged not assumed; duplicate planes allowed; no Restart; combined co-op tab deferred.
