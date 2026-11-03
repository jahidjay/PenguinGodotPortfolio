# Accessibility Options

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (accessibility-specialist) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (bullets always win; every option keeps shapes and colours of threats), Every Hit Counts (ranked rules never change; assists mark a run unranked), Four Planes, Four Games (slot identity never depends on colour)
> **Revision 2026-11-03 (final doc closeout, art-director A4)**: Rule 16 and AC-20 record that the HIGH-contrast theme renders an `ALARM_FLARE` `#F2494D` headline status line in Cream, while the `ALARM_RED` `#E03A3E` edge and error glyph are unchanged.
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: Menus (Credits roll) added to the consumers of `reduce_motion` (Rule 10, Tuning table); the Accessibility-list **group jump** may not use a shoulder bound to Fire / Drone / Bomb (Rule 21); first-run plate height is by content, about 240 px, not a fixed 120 (Visual/Audio).

## Overview

**The data layer:** Accessibility options is the **single registry of every `access.*` setting** and the rules for how each one is read. It owns a data file, `data/accessibility/access_options.tres`, with one `AccessOptionDef` per option: key, type, default, allowed values, tier (MVP hook / Vertical Slice / Target), group, owner system, the systems that read it, and the string keys for its label and help text. Save (26) registers these keys into `data/settings_schema.tres` and stores them. Consumers (HUD, VFX, Collision, Critical Break, Tally, Menus, Audio, Input, Localization, Parallax, Player plane, Bullet manager, Session) **read** a key; none of them writes it. The system also owns the **Accessibility screen** content (rows are generated from the option list), a first-run photosensitivity prompt, the CVD (colour-vision) palette check tool, the **assist run flag** (`run.assisted`), and the audit rules ("every sound has a visual twin", "no option changes a bullet"). It adds no gameplay rules of its own except one: **game speed**, which is a practice assist and marks the run unranked.

**The player impact:** A player with photosensitivity, low vision, colour-vision difference, a single working hand, tremor, slow reaction time, or hearing loss can set the game up once and keep playing the same game. Ranked rules never move: the 6 px hitbox, the enemy bullet shapes and colours, `chain_window`, the kit shot-rate caps and `play_top` are identical for everyone. Convenience options (Fire toggle, Tap Assist, deadzone, remapping, hold style) stay ranked because they cannot beat the kits' own caps. Options that change the simulation (game speed, and later auto-bomb and death-bomb grace) are called **assists**: the run is marked **PRACTICE**, shown on the pause menu and Results, and is not entered on a ranked board. The player is never refused a feature; they only choose whether the run counts.

This GDD is a Vertical Slice system, but its hooks (`access.reduce_flashing`, `access.reduce_pulsing`, `access.reduce_motion`, `access.effects_level`, `access.tally_auto_advance`) are already read by MVP systems with defaults, so MVP behaves correctly with Save absent.

## Player Fantasy

"The game meets me where I am, and my score still means something." A player turns on Reduce flashing before the first Critical Break and gets a warm burst instead of a white frame, and the payoff still lands. A player with one hand picks a layout in two presses. A co-op pair where one player needs Tap Assist and a slower practice run can still play together, and everyone can see which run is practice. Nothing is hidden behind a difficulty name or a shame label.

**Anti-fantasy (must never happen):** an option that changes enemy bullets; an option that is needed to see the hitbox; an unranked run that looks ranked; a ranked run quietly changed by an assist; a setting that only works with a mouse; a colour-only cue; a flash the player turned off that comes back after a mode change.

## Detailed Design

### Core Rules

**Ownership and registration**

1. **One registry.** Every `access.*` key is defined once in `data/accessibility/access_options.tres` (`AccessOptionDef[]`). Keys owned by other systems but presented on the Accessibility screen (`input.*`, `audio.*`, `display.*`, `language`) are listed with `owner` set to that system; Accessibility changes their values only through Save's `set_setting`, never by defining a second copy.
2. **Registration at boot.** Before `load_all` completes, Accessibility passes its defs to Save's schema loader (Save Rule 15). A key unknown to an older build is kept untouched by Save; an out-of-range or unknown enum value on load falls back to the default for that key only.
3. **Read-only consumers.** Consumers call `Save.get_setting(key)` at the points in the Option table ("Applies") and listen to `settings_changed(key)`. They never cache beyond that point. A consumer never writes an `access.*` key.
4. **Timing.** Each option has an `applies` mode: **LIVE** (next tick boundary), **EVENT** (read once at the start of a timed effect, so it never changes mid-effect: e.g. Critical Break reads at `T`), **STAGE** (read at `stage_started`), or **RUN** (frozen at `run_started`, except assists, Rule 23).

**What an option may and may not do**

5. **Bullets always win.** No option changes an enemy bullet's colour, shape, size, outline, opacity, speed, draw layer or hit radius, and none may hide, fade below 40 %, or remove the hitbox dot. This is checked by lint (AC-06). Because bullets already have no glow (art bible 4.2), there is no "bullet glow off" option; and a thicker bullet outline is **rejected** because it changes the drawn size against the true hit radius (Bullet manager: hitbox drawn at true size).
6. **Ranked-safe vs assist.** Every option has `class` = `PRESENTATION`, `INPUT_CONVENIENCE`, `TIMING_UI` or `ASSIST`. The first three never change simulation results for the same inputs. `ASSIST` options change the simulation or give a capability the base game does not; they set `run.assisted` (Rule 23). *(2026-11-03, ADR-0003)* **Sim-relevant timing settings:** `access.continue_timer`, `access.tally_auto_advance` and `access.era_transition_short` do not change hit rules but shift when ticks happen, so they are written into the replay header and the verifier uses the recorded values; any future non-ASSIST setting the simulation reads must be added to that list (ADR-0003 Decision 7).
7. **Presentation options read only; they never touch gameplay state.** A unit test runs the same recorded input twice with every presentation option at its extreme and compares the full `GameState` hash per tick: they must be identical (AC-07).

**Visual options**

8. **Reduce flashing** (`access.reduce_flashing`, bool, default false). Effects when true:

| System | Effect |
|---|---|
| Critical Break / VFX | No white frame; 80 warm particles; tint ramp 18 ticks to at most 25 % (CB V1/V2, VFX Rule 28). Banner stays. Read at `T` (EVENT) |
| Collision hit tint | Tint becomes a 1 px darker outline pulse, same throttle (Collision V2) |
| HUD | Milestone sparkles off; edge steps stay; nothing changes brightness faster than 1 Hz (HUD edge case) |
| Tally / Board | NEW BEST and new-entry pulses off; static border and star remain |
| Player plane | **New (resolves Player plane OQ3):** the 10 fps hide blink (respawn invulnerability and bomb invulnerability) becomes a **steady 65 % opacity** (35 % dim) for the same duration. The dot, ring and pips stay at their own opacity |

9. **Reduce pulsing** (`access.reduce_pulsing`, bool, default false). HUD pulse arbiter off (steady cues), VFX `pulse_pct` returns its high value (VFX F11), carrier rim steady, menu focus pulse off, Warning text steady, new-entry highlight steady. LIVE.
10. **Reduce motion** (`access.reduce_motion`, bool, default false). HUD score roll snaps, chain digit jump off, bomb-denied shake off, plate-drop shift off (HUD Rules 16, 17, 21); Warning stripes stop scrolling (static stripes); Accessibility calls Parallax `set_scroll_scale(50)` (Parallax 23 Rule 29b): L0, L1, L2 and L4 scroll at 50 %, L4 is hidden, prop animation holds on frame 0 and tile shimmer stops; L3 and ground targets stay on the gameplay scroll `S`, so hurtboxes still match their pads (stated limit: the terrain under ground targets cannot be slowed without changing gameplay speed, which only `game_speed_pct` does); menu wipes keep their 4 steps (they are not smooth motion). *(Added 2026-11-03, wave 5 batch 2, [Menus (22)](menus-title-plane-select.md) Rule 46:)* **Menus** also reads this key for the **Credits roll**: with `reduce_motion` on, the auto-scroll is **off** and the Credits screen opens in **manual** mode, scrolled one line at a time by Nav. The local boss shake is governed by `effects_level` (Rule 11), not by this key. LIVE.
11. **Effects level** (`access.effects_level`, enum `FULL` default / `REDUCED` / `MINIMAL`, owned and defined by VFX 25 Rule 21; presented here). Registered by Accessibility. LIVE for new instances. **Gap fixed here:** VFX's MINIMAL spawns only T0-T1, which would drop the armour clank and immune ping that are the visual twins of two sound-only cues (Rule 30). VFX must classify `fx_clank` and `fx_ping` as **T1** (Amendment 13).
12. **Background** (`access.background`, enum `FULL` default / `DIMMED` / `PLAIN`, PRESENTATION, STAGE). DIMMED multiplies every environment layer (Parallax L0-L4 plus boss plates and props, not enemies, bullets, planes, shots, items or HUD) by `bg_dim_pct` 65 (F4). PLAIN hides all environment layers and fills the field with the era Shadow colour (art bible 4.5), so only gameplay objects and the bezel remain. This is the way to improve bullet contrast without touching a bullet. Both must pass the grayscale gate (Rule 37).
13. **Hitbox ring** (`access.hitbox_ring_opacity`, int 40/60/80/100, default 100; `access.hitbox_ring_size`, enum `NORMAL` 22 px / `LARGE` 30 px, default NORMAL; PRESENTATION, LIVE). Only the ring changes. The white 6 px dot, the pips and the plane outline never change (Player plane V6: floor 40 %). LARGE draws the P4 double ring at 30 and 32 px. The dot is always shown on every platform (technical preferences).
14. **Other players' shots** (`access.ally_shot_dim`, int 0/25/50, default 0, PRESENTATION, LIVE). Opacity of the dimmed shots = `max(25, (base(N) × (100 − dim) + 50) div 100)` (F3), where `base(N)` is 100/75/50 for N = 1/2/3-4 (Bullet manager V3). Own shots and all drones stay as they are. Hit radii are untouched.
15. **Chain bar near the plane** (`access.chain_bar_near_plane`, bool, default false, PRESENTATION). A 26x5 px plated bar, 3 px of fill in the slot colour inside a 1 px Char frame, centred 6 px below the plane's base, layer 7 (below enemy bullets, never above layer 8), shown only while that slot's chain is above 0 (art bible 7.9). Fill from F5. Rectilinear plate, not a needle (art bible 3.3). *Placement is an art review item (Open Question 6).*
16. **High-contrast HUD** (`access.hud_contrast`, enum `STANDARD` default / `HIGH`, PRESENTATION, LIVE). HUD and menu theme swap (`HudTheme` high variant): plate edges `#5A5148` → Cream `#F4EBD6`; ghost digits and dim text `#5A5148` → `#A89E8A` (contrast on Cabinet Char 2.2 → 6.5, F6); outline stays 1 px `#14110E`; *(added 2026-11-03, art-director A4:)* an **`ALARM_FLARE` `#F2494D`** headline status line → Cream `#F4EBD6` (the `ALARM_RED` `#E03A3E` plate edge and error glyph beside it do **not** change); no other colour changes, no pattern changes.

**Colour-vision support**

17. **No screen-wide colour-vision filter.** A post-process recolour would change the enemy bullet hues (locked to 225-265°, art bible 4.3), cost fill rate on Web and GL Compatibility, and is unreliable across the three types. Instead:
    - Slot identity is **never colour-only**: ring pattern (solid / dashed / dotted / double), pip count (1-4), "P{n}" text on menus, the frame pattern on HUD columns. These stay on in every option state and are not switchable (art bible 4.4, 4.8).
    - `access.player_palette` (enum `DEFAULT` / `LUMA_SPREAD`, default DEFAULT; PRESENTATION; STAGE) swaps the four slot colours. DEFAULT has equal luma for P3 and P4 (169.0 vs 168.5). **LUMA_SPREAD** keeps P1 `#FF5A36` and P3 `#2FD27A`, and changes P2 to `#FFF04A` and P4 to `#FFB4EA`: luma 122.5 / 231.2 / 169.0 / 199.8, minimum gap 30.9 (F5). All four stay outside the bullet hue band 225-265°. The palette is a `PlayerPalette` resource at `data/ui/player_palettes.tres`.
    - A palette is accepted only if it passes F5: pairwise luma gap at least 25 **and** pairwise ΔE (CIE76) at least 20 under protan, deutan and tritan simulation **and** at least 20 from every enemy bullet fill. LUMA_SPREAD passes except one pair noted in Open Question 2.
    - The palette affects: plane outline accent, hitbox ring, pips, HUD column notch and frame, Lobby rims, Pause owner tag, Tally column notches, `chain_bar_near_plane`. It never affects shots (warm orange fixed), items, bullets or backgrounds.
18. **Simulation tool.** A debug-only overlay (`F9` in dev builds) renders the canvas through the protan / deutan / tritan matrices (F5) and a grayscale mode. It is a dev tool for the manual test (AC-23) and for screenshots; it is stripped from release builds.

**Text**

19. **Text size** (`access.text_size`, int 0-3, default 0, PRESENTATION, LIVE). Steps scale the **S and M tiers only** (labels, menu rows, settings, descriptions, prompts, captions, board rows). `Localization.font_size_px(tier, step)` returns the table in F1: S/M Latin cap 12 / 15 / 18 / 24 px, Bengali 17 / 21 / 25 / 33 px (Bengali at step 0 uses `max(17, bn_size_s)`). **L and XL tiers are identity at every step** (titles, banners, chain counter, tally hero), because they already exceed the minimum and fixed plates would overflow. All sizes are integers. Screens lay out from measured text (Menus Rule 51): rows grow downward, long lists scroll, and from step 2 a settings row stacks its label above its control.
20. **The in-fight strip does not scale. Resolves HUD OQ9: `play_top` stays 48 (1-2P) and 72 (3-4P); the proposed HUD scale 100/125/150 % is not adopted.** Reasons: (a) `play_top` is locked in the registry and sets the field height that every pattern, `lane_min_clear`, boss budget and spawn rule was designed against; (b) a different field height per player would make scores incomparable on one board; (c) the strip holds only icons and numerals on a fixed grid (HUD Rule 34, Localization digit atlas), so there is no text to enlarge; (d) three authored layouts per mode would triple the HUD art and lint load. What replaces it: the high-contrast palette (Rule 16), the optional near-plane chain bar (Rule 15), a **status panel** on the Pause menu that shows each player's score, chain, lives, bombs and drones at the current text-size step (Menus Amendment 7), and the Display scaler's own fill scale for a larger window. The Tally grid is fixed for 4P and also ignores the step; only its prompt line scales (Tally accessibility row).

**Input**

21. **Controls screen.** Menus (22) owns the screen shell and the basic MVP rebind list. Accessibility owns, at Vertical Slice: (a) **per-slot pad maps** (resolves Input OQ6, below), (b) swap-confirm line, (c) one-handed **layout presets**, (d) an input test screen showing live pressed / held state per action, (e) per-action and per-class reset. The remapping rules (Input Rules 34-39) are unchanged.
21a. **Group jump on the Accessibility list** *(added 2026-11-03, wave 5 batch 2, `design/ux/settings.md`).* The long Accessibility page is one scrolling list with a **group jump** (pad shoulders, PageUp / PageDown on keyboard) that moves focus to the first row of the previous or next group. Two rules bind it: (a) it is a **convenience and never the only path** - every row is reachable by plain Nav, so a device with no shoulders loses nothing; (b) the jump **must not use a physical shoulder that is bound to Fire, Drone or Bomb in the active pad class**. The **Gamepad: one hand** preset binds Fire to the left shoulder, so on that preset the group jump is **suppressed** on the colliding side rather than stealing the press. Input (2) may instead expose a dedicated verb pair, `nav_group_prev` / `nav_group_next`, which Menus would use in place of the raw shoulders; either answer satisfies this rule, and the suppression rule is the fallback that holds until such a verb exists. The menu jump never affects in-run bindings.
    - **Per-slot pad maps:** a slot may override the shared `pad` map with its own (`pad_s0 … pad_s3` classes in `input.bindings`). Slot indices, not controller GUIDs, so a swapped pad keeps the player's layout. Conflict, last-binding and reserved-control rules apply per class. Pad movement, Start and Back stay fixed (Input Rule 34).
    - **Hold vs toggle Fire** `input.fire_toggle` (default false), **Tap Assist** `input.tap_assist` (false), **deadzone** `input.dz_preset` (`low` / `default` / `high`) are Input-owned keys shown on this screen unchanged. Tap Assist stays capped by `tap_assist_until` ≤ `charge_hold_ticks` and the kit shot-rate cap, so it is INPUT_CONVENIENCE and stays ranked.
    - **Auto-fire / auto-tap (Plane kits OQ2): closed, no new option.** A held Fire always shoots (plain volleys in HOLD_PLAIN, Plane kits Rule 4), so a player who cannot tap loses nothing but the wide tap shot's speed; Fire toggle removes the need to hold and Tap Assist covers the first 18 ticks. Adding a second turbo would cross the shot-rate cap.
    - **Layout presets** (write overrides in one action, each can be edited afterwards): `Keyboard: left hand` (Move W A S D, Fire Space, Drone Q, Bomb E), `Keyboard: right hand` (Move arrow keys, Fire `.`, Drone `,`, Bomb `/`; physical keycodes, see Open Question 5), `Gamepad: one hand` (Fire Left shoulder, Drone Left trigger, Bomb Left stick click; with `fire_toggle` on), `Touch: one hand` (`touch.one_hand` on; touch-controls.md, added 2026-11-03). Presets are data in `data/accessibility/layout_presets.tres`.
    - **Stick choice** `input.move_stick` (enum `LEFT` default / `RIGHT` / `EITHER`; *proposed Input amendment, VS*): movement from the chosen stick (EITHER takes the stick with the larger magnitude). Supports one-handed grips and adaptive controllers whose only analogue input is the right stick. D-pad always works.
    - **Adaptive controllers:** the Xbox Adaptive Controller and other hardware that presents as a standard gamepad are supported by the normal pad path with the presets above; no special code (Open Question 7: test hardware).
22. **Timing options.**

| Key | Values | Owner reads | Effect |
|---|---|---|---|
| `access.confirm_style` | `HOLD` (default) / `DOUBLE_TAP` | Menus | Hold-to-confirm becomes two presses within 120 ticks (Menus Rule 51) |
| `access.confirm_hold` | `SHORT` 40 / `NORMAL` 60 / `LONG` 90 ticks | Menus | Hold length for `HOLD_BUTTON` (Menus knob 60) |
| `access.nav_repeat` | `FAST` 12/4 / `NORMAL` 18/6 / `SLOW` 30/10 | Input | First-repeat delay / repeat interval in ticks (Input F4) |
| `access.untimed_menus` | bool, default false | Menus | Name entry (30 s) has no limit; Lobby idle-close is off; drop-in pick timeout is doubled |
| `access.continue_timer` | `STANDARD` 600 / `EXTENDED` 1,800 / `UNTIMED` | Session, HUD | Continue countdown in game ticks. UNTIMED waits for the slot only while no other slot is Alive; otherwise it behaves as EXTENDED |

    Gameplay timings are **not** options: `charge_hold_ticks` (18), `buffer_ticks` (6), `shot_linger_ticks` (12), `bomb_lockout` (90), `chain_window` (60) and invulnerability lengths are ranked rules. Adjusting them is possible only as an assist (none planned).

**Assists**

23. **Assist class and the PRACTICE flag.** `run.assisted` is a latch owned by Session (1): it is false at `run_started`, becomes true on the first tick any `ASSIST` option is in effect (game speed below 100, auto-bomb enabled, death-bomb grace above 0), and is never cleared in that run. Assists can be changed in Settings from Pause; the latch means flipping them on briefly still marks the run. While latched: the pause panel and Results show the **PRACTICE** tag (plated icon plus word, bilingual, never colour alone); Session's `submit_run` returns "not ranked" (the same path as Save Rule 31), so no board entry, no personal-best, no `one_credit_clear`; the Tally does not show NEW BEST; high-score name entry is skipped. The run's score is still shown. Co-op: assists are global (one game), so the whole run is PRACTICE.
24. **Game speed** (`access.game_speed_pct`, int 50-100 in steps of 10, default 100, ASSIST). At less than 100 the simulation runs fewer ticks per second without changing any tick-level rule. Mechanism (F2): the fixed 60 Hz step keeps ticking, and an integer accumulator decides which physics steps run a **game tick**: `acc += speed; if acc >= 100: acc -= 100; run tick`. Every game tick is identical to a 100 % game tick, so replays, seeds and all `delta`-free logic are unchanged (ADR-0001). Rules:
    - Input is sampled every physics step, and presses between game ticks are **latched** and delivered on the next game tick (Input F1 `latch_press`); `held_ticks`, `buffer_ticks`, Tap Assist cadence and all timers count **game ticks**.
    - Real-time things stay real time: menu navigation, pause, Display TATE confirm, audio buses, Save.
    - Audio music and ambience play at normal speed and are not time-stretched (they are not tick-locked); sound effects fire on their game ticks (so they are spaced wider). *Unverified in 4.7:* whether any scene-tree `Engine.time_scale` is touched; the design uses the accumulator only (→ ADR for the scheduler).
    - Frame cadence: at 60 Hz display, 90 % repeats one frame in 10; 50 % repeats every other frame. Pixel art has no interpolation, so no blur; accepted.
25. **Auto-bomb and death-bomb grace** (Target tier, ASSIST; contracts only). `access.auto_bomb` (bool, false): when a hit would be lethal and the plane has a bomb, Bombs starts a bomb on the same tick instead. `access.deathbomb_grace` (int 0/3/6 ticks, default 0): Collision defers a lethal hit by that many ticks, during which a bomb press saves the plane (Bombs OQ2). Both need a **pre-lethal callback** from Collision (6) (`will_die(slot) -> bool` at step 6b) and are not shipped at VS. Registering the keys now keeps the schema stable.
26. **No other assists at VS.** No damage reduction, extra lives, invincibility or enemy slow-down; they would break Every Hit Counts more than they help, and game speed already gives the main benefit (time to react). Practice start at a chosen stage or boss is a Tutorial / Boss rush matter (Open Question 9, closed 2026-11-03: boss practice = **Single Boss with a game-speed assist**, unranked, PRACTICE tag; online-leaderboards-boss-rush.md). Assisted runs are never recorded for upload.

**Audio and cues**

27. **Audio keys.** Presented on the screen: `audio.master`, `audio.music`, `audio.sfx` (0-10, Audio-owned; the UI bus follows the SFX step, Audio Rule 1) and `audio.mono` (bool, default false; Audio Rule 3 forces pan 0 and a mono Master). **Decided: no separate Dialogue or UI slider**; there is no dialogue, and Audio already decided that the UI bus follows SFX. Peaks are limited by Audio's Master limiter (ceiling −1.0 dB), so no extra "quiet peaks" option is needed.
28. **Chain cues** (`access.chain_cue_audio`, bool, **true** — on by default, decided 2026-11-03 wave 4 to match Audio's chain-window tick; `access.chain_cue_rumble`, bool, false; art bible 7.9): a soft tick (Audio) and a short pad rumble pulse (Input) when `window_left` ≤ `ceil(chain_window / 4)` = 15 ticks, once per chain. Rumble also needs `access.rumble` ≠ `OFF`.
29. **Rumble** (`access.rumble`, enum `OFF` / `LOW` / `NORMAL`, default NORMAL; Target tier because rumble does not exist yet; resolves Input OQ10 and CB OQ8's toggle). Scales every rumble effect's strength (0 / 40 % / 100 %).
30. **Visual twin rule (sound → sight).** Every sound with priority P0 or P1 in Audio's event table must have a `visual_twin` column naming an existing visual, or the lint (AC-39) fails. The twins for the cases that had none:

| Sound-only cue | Visual twin (decided) |
|---|---|
| Armour clank (`sfx_coll_clank`, P2) | VFX `fx_clank` (3-frame cream chips plus steel dot, no tint). Promoted to T1 so MINIMAL keeps it |
| Immune ping | VFX `fx_ping`. Promoted to T1 |
| Warning siren | The Warning banner (Amber stripes plus bilingual plate) |
| Extend (1-up) | The life icon appears with its 3-frame stamp (HUD) |
| Chain-expiry tick | Alarm Red end-cap on the chain bar (HUD, art bible 7.3) |
| Boss heartbeat / critical | Crack overlay pulse (VFX Rule 33) and the critical notch (HUD) |
| CB armed / miss | Armed corner ticks (HUD Rule 28) and the banner / no-banner |

Decision for the two cues the coordinator asked about: **the twin is the existing VFX clank and ping, promoted to T1**, not a new caption. There is no caption strip: no HUD space exists, and art bible 7.7 forbids UI over the field.

**Cognitive options and defaults**

31. **Pause anywhere.** Start or Back pauses in Stage and Tally (Input Rule 25), including during the Continue countdown (it freezes, Session), the Warning, the boss intro and the fly-in. Not pausable: the 12-frame Char hold between Lobby and stage load, and Results name entry (which is already untimed under `access.untimed_menus`). The pause menu opens within 1 tick of the press.
32. **Tally auto-advance** (`access.tally_auto_advance`, bool, default true; Tally Rule 16). False: the Tally waits for every counted column to be Confirmed. MVP hook.
33. **Nothing time-limited that can be avoided.** The only timers in the game's menus are listed in Rule 22; each has an option. The Display TATE confirm countdown (10 s, real time) defaults to Cancel and is a safety timer (Display Rule 17); it is not changed.
34. **Photosensitivity prompt (first run).** Once, after Boot and the Web gate and before Title, if `access.first_run_prompt_done` is false: a bilingual plate "This game has one bright flash. Reduce flashing and effects?" with two items, **Keep as is** (default focus) and **Reduce flashing and effects**. The second applies the **Calm preset**: `reduce_flashing` true, `reduce_pulsing` true, `reduce_motion` true, `effects_level` REDUCED. Either choice sets `first_run_prompt_done` true. Skippable with one press. The Accessibility screen also has a **Calm preset** action and a **Reset these options** action (hold-to-confirm, honouring `confirm_style`).
35. **Simplified information.** No "simple HUD" option: the strip is already icons and numerals. Reducing visual noise is covered by `effects_level`, `background`, `reduce_*` and `hud_contrast`. Difficulty-style options do not exist except the game-speed assist.

**Verification**

36. **Standards.** Targets: WCAG 2.1 AA where it applies to UI (contrast, target size, keyboard operability), plus the Game Accessibility Guidelines (basic and intermediate) and the Xbox Accessibility Guidelines topics. The mapping is in the Visual/Audio section's checklist.
37. **Grayscale gate.** Every background mode (FULL, DIMMED, PLAIN) in every era must keep all enemy bullets readable in a grayscale capture (art bible 1, 4.2).

### States and Transitions

| State machine | States | Transitions |
|---|---|---|
| Option value | Default → Loaded (from Save) → Previewing (changed, in memory) → Committed (Save `commit_settings` on screen close) | `set_setting` applies immediately (Save Rule 19); backing out of the screen commits if dirty (Save Rule 20) |
| Run assist latch | Clean → Assisted (monotonic) | Clean → Assisted on the first tick an ASSIST option is in effect; reset only by `run_started` |
| First-run prompt | Pending → Done | Either choice → Done; stays Pending if the game exits before an answer |
| Game-speed gate | Full (speed 100: every step runs a tick) ↔ Gated (speed < 100) | Changes at a physics-step boundary; `acc` is cleared to 0 on change, on pause, and at `run_started` |
| Palette | DEFAULT ↔ LUMA_SPREAD | Applies at the next `stage_started` and immediately in menus and Lobby |

### Interactions with Other Systems

| System | Direction | Data / contract |
|---|---|---|
| Save, settings and high scores (26) — GDD | ↔ | Accessibility registers the `access.*` schema (defs from `access_options.tres`); Save stores them; `get_setting`, `set_setting`, `commit_settings`, `settings_changed(key)`. Per-slot pad classes added to `input.bindings` (Amendment 10) |
| Menus, title, plane select (22) — GDD | ↔ | Menus owns the Settings shell and Controls shell; Accessibility supplies row definitions, groups and the first-run plate; Menus reads `confirm_style`, `confirm_hold`, `untimed_menus`, `text_size`; shows PRACTICE on Pause and Results |
| HUD (20) — GDD | ← | `reduce_flashing`, `reduce_pulsing`, `reduce_motion`, `hud_contrast`, `player_palette`, `chain_bar_near_plane`, `continue_timer`; HUD shows `assist_tag` |
| Localization (27) — GDD | ← | `font_size_px(tier, step)` table (F1); `text_size` read by Menus and banners; string keys `opt.*` |
| Input and player mapping (2) — GDD | ↔ | Remap API, `fire_toggle`, `tap_assist`, `dz_preset`, `nav_repeat`, `move_stick`; latch across skipped steps (Rule 24); per-slot pad maps |
| Collision, damage, lives (6) — GDD | ← | `reduce_flashing` (hit tint); later `will_die` callback (Rule 25) |
| Critical Break (17) — GDD | ← | `reduce_flashing` read at `T`; no other coupling |
| Stage-end tally (21) — GDD | ← | `tally_auto_advance`, `reduce_flashing`; Tally hides NEW BEST when `run.assisted` |
| VFX and screen feedback (25) — GDD | ← | `effects_level`, `reduce_flashing`, `reduce_pulsing`; `fx_clank` / `fx_ping` at T1 |
| Audio (24) — GDD | ← | `audio.*`, `audio.mono`, `chain_cue_audio`, `visual_twin` lint |
| Display scaler and bezel (4) — GDD | ← | `bezel_style` Plain shown on the Visual group; no HUD scale (Rule 20) |
| Player plane (5) — GDD | ← | Ring opacity and size, invulnerability blink replacement |
| Bullet manager (3) — GDD | ← | `ally_shot_dim` on player-shot opacity |
| Game events and session (1) — GDD | ↔ | `run.assisted` latch, game-speed scheduler, `continue_timer`, `submit_run` not ranked |
| Plane kits (11), Bombs (12) — GDD | ← | Kits OQ2 closed; Bombs auto-bomb and grace contracts (Target) |
| Co-op (18) — GDD | ← | Assists are global; co-op boards unranked when assisted |
| Parallax and environment (23) — GDD | ← | `access.background` → `set_background_mode(FULL / DIMMED / PLAIN)` (DIMMED modulate 166 = F4 65 %; PLAIN flat era Shadow fill, vignette off); `access.reduce_motion` → `set_scroll_scale(pct)` on L0, L1, L2, L4 only (Parallax Rule 29) |
| Era shift and plane evolution (19) — GDD | ← | `access.era_transition_short` (short transition, release 96), `access.reduce_flashing` (transition variant) |
| Touch controls (31) — [GDD](touch-controls.md) | ← | Touch section of Controls: `touch.one_hand`, `touch.hand`, `touch.button_scale`, `touch.sens`, `touch.haptics`; layout drag-and-place editing is out of scope (Touch Open Question 5); preset `Touch: one hand` (Rule 21) |
| Tutorial (30) — [GDD](tutorial.md) | ← | `tutorial.hints` shown in the Settings list (Accessibility group); practice start is not part of the school |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | → | `run.assisted` blocks upload; Single Boss + game speed is the boss practice mode |

> Decided under auto-approve (2026-11-03): one data-driven registry; no colour filter, palette swap with mandatory patterns; text size on S/M only; `play_top` locked and HUD scale rejected; reduce-flashing also changes the invulnerability blink; effects level and pulsing registered as VFX asked; game speed by tick-skip accumulator and marked PRACTICE; assists latch; auto-bomb and death-bomb grace defined but Target; visual twin for clank and ping is the VFX effect promoted to T1; no UI or Dialogue slider; per-slot pad maps at VS; one-handed presets plus stick choice; first-run photosensitivity prompt with a Calm preset.

## Formulas

**F1. Text step sizes**

`cap(step) = round(12 × mult(step) / 100)`, `mult = [100, 125, 150, 200]`; `bn(step) = max(ceil(cap × 11 / 8), bn_size_s)`; `line_box_lat = cap + 7`; `line_box_bn = bn + 7`; `text_px(step) = ceil(text_px(0) × cap(step) / 12)`. L and XL tiers: `size(tier, step) = size(tier, 0)`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Step | `step` | int | 0-3 | `access.text_size` |
| Multiplier | `mult` | int percent | 100-200 | Authored table |
| Latin cap | `cap` | int px | 12-24 | S/M tier Latin cap height |
| Bengali size | `bn` | int px | 17-33 | S/M tier Bengali size |
| Bengali floor | `bn_size_s` | int px | 17-20 | Localization knob (registry) |

**Output Range:** `cap` 12 / 15 / 18 / 24; `bn` 17 / 21 / 25 / 33 at `bn_size_s` 17. **Example:** step 2: `cap = round(12 × 150 / 100) = 18`; `bn = max(ceil(18 × 11 / 8) = ceil(24.75) = 25, 17) = 25`; line boxes 25 and 32. A 150 px label at step 3 measures `ceil(150 × 24 / 12) = 300` px; in a 156 px box it wraps to 2 lines (`ceil(300 / 156) = 2`) and the row is `2 × 31 = 62` px tall in Latin. With `bn_size_s` 19, step 0 Bengali is `max(17, 19) = 19` and step 1 is `max(21, 19) = 21`.

**F2. Game-speed tick gate**

`acc' = acc + speed_pct; run = (acc' >= 100); acc'' = acc' − 100 if run else acc'`, evaluated once per 60 Hz physics step.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Accumulator | `acc` | int | 0-99 | Cleared on change, pause, `run_started` |
| Speed | `speed_pct` | int | 50-100, step 10 | `access.game_speed_pct` |
| Run | `run` | bool | — | A game tick runs this step |

**Output Range:** exactly `speed_pct` game ticks in every 100 physics steps, never two in one step. **Example (80 %):** acc 0 → 80 (no) → 160, acc 60 (run) → 140, acc 40 (run) → 120, acc 20 (run) → 100, acc 0 (run) → 80 (no): the pattern repeats every 5 steps with 4 runs. A 60 s stage takes 75 s of real time. At 50 %: N R N R … (acc 50 no, 100 run).

**F3. Other players' shot opacity**

`op = max(op_floor, (base(N) × (100 − dim) + 50) div 100)`; `base = 100 / 75 / 50` for N = 1 / 2 / 3-4; `op_floor = 25`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base | `base(N)` | int percent | 50-100 | Bullet manager V3 |
| Dim | `dim` | int percent | 0 / 25 / 50 | `access.ally_shot_dim` |
| Floor | `op_floor` | int percent | 25 | Keeps allies' fire visible |

**Output Range:** 25-100. **Example:** dim 50: N=1 → `(100 × 50 + 50) div 100 = 50`; N=2 → `(3,750 + 50) div 100 = 38`; N=4 → `(2,500 + 50) div 100 = 25`. Dim 25: N=2 → `(5,625 + 50) div 100 = 56`; N=4 → `(3,750 + 50) div 100 = 38`.

**F4. Background dim**

`L_out = (L × bg_dim_pct + 50) div 100`, `bg_dim_pct = 65`; applies to environment layers only.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Input luma | `L` | int | 8-160 | Rec.709 luma on gamma values (art bible 4.2) |
| Dim | `bg_dim_pct` | int percent | 40-90 | Knob |

**Output Range:** `0.4 L … 0.9 L`; bullets are never dimmed. **Example:** 2030s sky `#0F1A2E` luma 25 → `(25 × 65 + 50) div 100 = 16`; 2030s ground `#0A1220` luma 17 → `11`; 1941 sky `#6E8264` luma 125 → `81`. The art bible's lower bound of 16 is deliberately undercut: darker backgrounds only increase bullet core contrast (core minus background).

**F5. Palette acceptance and CVD simulation**

`sim_m(c) = encode(clamp(M_m × decode(c)))` with decode/encode the sRGB transfer and `M_m` the Machado et al. 2009 severity 1.0 matrices (protan, deutan, tritan); `ΔE = dist(Lab(sim(a)), Lab(sim(b)))` (CIE76, D65); `luma = 0.2126R + 0.7152G + 0.0722B` (gamma values). Accept iff, for all slot pairs: `|luma_a − luma_b| >= 25` and `ΔE_m >= 20` for each of the 3 types, and `ΔE >= 20` against each enemy bullet fill.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Matrix | `M_m` | 3x3 float | — | In `data/accessibility/cvd_matrices.tres`; *values to be verified against the paper (Open Question 3)* |
| Luma gap | — | float | 0-255 | Brightness backup |
| Colour distance | `ΔE` | float | 0-150 | After simulation |

**Output Range:** pass / fail with the minima reported. **Example (computed 2026-11-03):** DEFAULT: luma 122.5 / 215.6 / 169.0 / 168.5, min gap **0.5** (fails the luma rule, so the patterns are mandatory); min ΔE: protan 26.2, deutan 31.1, tritan 36.8. LUMA_SPREAD (`#FF5A36 #FFF04A #2FD27A #FFB4EA`): luma 122.5 / 231.2 / 169.0 / 199.8, min gap **30.9**; min ΔE: protan 26.2, deutan 31.1, tritan **24.8**. Closest bullet: P4 `#FFB4EA` to Needle `#9AA8FF` ΔE 36.2 normal, **22.4 protan** (passes 20 narrowly).

**F6. Contrast ratio**

`ratio = (L1 + 0.05) / (L2 + 0.05)`, `L` = WCAG relative luminance, `L1 >= L2`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Relative luminance | `L` | float | 0-1 | From linearised sRGB |

**Output Range:** 1-21. **Example:** Cabinet Char `#1E1B18` L = 0.01129. Standard ghost `#5A5148` L = 0.0853 → `0.1353 / 0.06129 = 2.21`. High `#A89E8A` L = 0.3462 → `0.3962 / 0.06129 = 6.46` (target at least 4.5 for text, 3 for UI edges).

**F7. Hitbox ring size**

`ring_outer = 22 (NORMAL) or 30 (LARGE)`; P4 inner/outer `= (ring_outer, ring_outer + 2)`.

**Output Range:** 22-32 px. **Example:** LARGE, P4: rings at 30 and 32 px; the dot stays 6 px.

**F8. Chain bar near the plane**

`fill_px = (24 × window_left + chain_window − 1) div chain_window`; `warn = window_left <= (chain_window + 3) div 4`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Window left | `window_left` | int ticks | 0-`chain_window` | Chain tracker |
| Chain window | `chain_window` | int ticks | 45-90 (60) | Registry |

**Output Range:** 0-24 px (0 only when `window_left` is 0). **Example:** `chain_window` 60: left 60 → 24; left 30 → `(720 + 59) div 60 = 12`; left 15 → `(360 + 59) div 60 = 6`, `warn` true (`15 <= (63) div 4 = 15`); left 1 → `(24 + 59) div 60 = 1`.

**F9. Continue timer ticks**

`ticks = 600 (STANDARD) | 1,800 (EXTENDED) | none (UNTIMED and no other Alive slot) | 1,800 (UNTIMED and another slot Alive)`

**Output Range:** 600-1,800 or none. **Example:** 2P, P1 Alive, P2 in Continue with UNTIMED → 1,800 ticks (30 s game time).

## Edge Cases

- **If `access.reduce_flashing` changes mid-boss**, a Critical Break already past `T` finishes as it started; the new value is read at the next `T` (CB edge case).
- **If `access.reduce_flashing` is on and the plane is invulnerable**, it shows a steady 65 % opacity; the dot, ring and pips are drawn at their own opacity, and the last 20 ticks keep the same steady look (no end-of-invuln blink).
- **If `access.ally_shot_dim` is 50 in a 4P game**, shots draw at 25 % and still cancel and hit at full strength; opacity never changes damage.
- **If `access.background` is PLAIN**, the field is the flat era Shadow colour; bullets, enemies and planes draw unchanged; the bezel is unaffected.
- **If `access.background` changes mid-stage**, the new mode applies at the next `stage_started`; the Pause menu shows "applies next stage".
- **If `access.text_size` is 3 and a string does not fit its row**, the row wraps to the next line and grows; if the screen overflows, the list scrolls; no text is truncated or clipped. A fixed-size plate (tally hero, banners, HUD) is never scaled.
- **If `access.text_size` changes while a Settings screen is open**, the screen reflows at once and keeps the focused item in view.
- **If `bn_size_s` is raised to 19 by the conjunct gate**, step 0 is 19 and every later step is computed from the table (F1); no step can be smaller than the one before it (enforced by the data test).
- **If a saved `access.*` value is not in the allowed set**, that key falls back to its default; other keys are untouched.
- **If a newer build wrote a key this build does not know**, it is kept in the file and never applied (Save Rule 15).
- **If Save is absent (MVP)**, every option reads its default, the screen cannot persist, and Menus shows the "will not be saved" note once per session.
- **If `access.game_speed_pct` is changed to below 100 during a stage**, the latch sets on the next game tick, `acc` is cleared, and the PRACTICE tag appears on the pause panel.
- **If game speed is set back to 100**, `run.assisted` stays true for that run.
- **If a press and release both happen between two game ticks** (speed 50, a 2-step tap), the latch delivers `pressed` on tick T and `released` on T+1 exactly as for a sub-tick tap (Input F1).
- **If the game pauses at a physics step where `acc` is non-zero**, `acc` is cleared on pause; the first step after resume cannot run two ticks.
- **If game speed is below 100 and the Continue countdown runs**, it counts game ticks, so it lasts `1/speed` as long in real time.
- **If the run is PRACTICE and a high score would qualify**, name entry is skipped, Results show "PRACTICE - not ranked", and `profile.last_initials` is unchanged.
- **If a co-op player joins mid-run while assists are active**, the join does not clear the latch; the whole run stays PRACTICE.
- **If `input.move_stick` is EITHER and both sticks are deflected**, the stick with the larger magnitude is used for that tick; ties use the left stick.
- **If a per-slot pad map and the shared map both bind a control**, the slot map wins for that slot; a control may be bound to one action per class (Input Rule 36).
- **If a preset would bind a reserved control** (Input Rule 38), the preset data fails validation in the data test; the shipped presets contain none.
- **If the player picks `access.confirm_style` DOUBLE_TAP**, the first press shows "Press again" for 120 ticks with the target focused; a second press elsewhere cancels.
- **If `access.untimed_menus` is on and a pad disconnects at name entry**, the entry stays open until the pad returns or the player chooses Drop (no timeout).
- **If `access.continue_timer` is UNTIMED and the last other player dies**, the countdown starts at that moment as EXTENDED if any slot is Alive on that tick; if no slot is Alive it was already waiting, and Game Over proceeds only on the player's choice.
- **If the first-run prompt is on screen and the window loses focus**, the game pauses its input as usual and the prompt stays.
- **If `first_run_prompt_done` is false and Save is absent**, the prompt is shown every launch (nothing can store the answer); it is hidden in MVP builds.
- **If `access.player_palette` is LUMA_SPREAD and a new plane evolves**, palette applies to the outline, ring and pips only; the era skin is unchanged.
- **If every sound is muted**, all P0 and P1 cues still have visual twins (AC-39); the player loses no information.
- **If Reduce flashing is off, Calm preset is chosen later**, the three booleans and `effects_level` are set together in one `commit` (no partial state is persisted).

## Dependencies

**Upstream (Accessibility reads or relies on)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| Save, settings and high scores (26) | Hard | Stores `access.*`; schema registration; `settings_changed` | Yes |
| Menus, title and plane select (22) | Hard | Settings and Controls shells, hold-confirm, Pause and Results | Yes |
| HUD (20) | Hard | Theme variants, tags, pulse arbiter | Yes ([HUD](hud.md)) |
| Localization (27) | Hard | `font_size_px`, string keys | Yes |
| Input and player mapping (2) | Hard | Remap API, option keys | Yes |
| Game events and session (1) | Hard | `run.assisted`, scheduler, `submit_run` | Yes |
| Display scaler and bezel (4) | Soft | `bezel_style` | Yes |
| VFX and screen feedback (25) | Soft | `effects_level`, `reduce_*` consumers | Yes |
| Audio (24) | Soft | `audio.*`, visual-twin lint | Yes |
| Collision, damage and lives (6), Critical Break (17), Stage-end tally (21), Player plane (5), Bullet manager (3) | Soft | Option consumers (see Interactions) | Yes |
| Parallax and environment (23) | Soft | Background mode, scroll scale | Yes ([Parallax](parallax-and-environment.md)) |
| Era shift and plane evolution (19) | Soft | Reads `access.era_transition_short`, `access.reduce_flashing` | Yes ([Era shift](era-shift-and-plane-evolution.md)) |

**Downstream (depend on Accessibility)**

| System | Hard/Soft | Interface | GDD? |
|---|---|---|---|
| HUD (20), Menus (22), VFX (25), Collision (6), CB (17), Tally (21), Audio (24), Input (2), Localization (27) | Soft | Read the keys registered here | Yes |
| Tutorial (30) | Soft | `tutorial.hints` setting row; first-run flow | Yes ([GDD](tutorial.md)) |
| Touch controls (31) | Soft | Touch section (`touch.one_hand`, `hand`, `button_scale`, `sens`, `haptics`); `Touch: one hand` preset | Yes ([GDD](touch-controls.md)) |
| Online leaderboards, boss rush (32) | Soft | `run.assisted` (no upload); Single Boss practice | Yes ([GDD](online-leaderboards-boss-rush.md)) |

**Amendments to other docs**

1. **`design/gdd/systems-index.md`** row 28 and notes: see the report (row text, dependency list, progress count, "Future GDDs … Accessibility" bidirectional note).
2. **`design/gdd/save-settings-high-scores.md`** schema table (line ~110): replace the `access.reduce_flashing` and `access.*` rows with the full key list in the Tuning Knobs table; add `audio.mono`; Rule 18: add optional classes `pad_s0`…`pad_s3` (per-slot pad overrides); note that a run with `run.assisted` returns "not ranked" from `submit_run`.
3. **`design/gdd/hud.md`**: Rule 34 and Open Question 9 closed per Rule 20 above; add an `assist_tag` element (12x12 plated icon, shown while `run.assisted`) to the layout files with a lint exemption; Rule 33 names `access.hud_contrast` (STANDARD/HIGH) and `access.player_palette`; add the optional near-plane chain bar (layer 7) to Rule 12 and the continue prompt reading `access.continue_timer`; use `access.reduce_pulsing` and `access.reduce_motion` as registered.
4. **`design/gdd/display-scaler-and-bezel.md`** Interactions rows for HUD (line ~114) and Accessibility (line ~117) and Owned elsewhere (line ~349): replace "HUD scale 100/125/150 (Accessibility 28)" with "no HUD scale; `play_top` is unchanged by any accessibility option".
5. **`design/art/art-bible.md`** 7.9: replace the "HUD scale 100/125/150 %" bullet with "text-size step on S/M tiers only; high-contrast HUD palette; Pause status panel"; add "reduce motion", "background dim / plain", "assist (game speed) marks a run PRACTICE".
6. **`design/gdd/localization.md`** Open Question 8 closed with F1; add the step table to `font_size_px` (rule 15) and the "L/XL identity" note; Interactions row for Accessibility no longer provisional.
7. **`design/gdd/menus-title-plane-select.md`** Open Questions 8 and 9 closed: Menus builds the basic remap list (MVP), Accessibility polishes (Rule 21); `access.untimed_menus` is the untimed option; add `access.confirm_hold`; add a Pause **status panel** at the text-size step; show **PRACTICE**; first-run prompt after the Web gate; Settings entry registration reads `AccessOptionDef`.
8. **`design/gdd/input-and-player-mapping.md`**: Rule 35 (and Save Rule 18) per-slot pad maps; Rule 23 nav repeat reads `access.nav_repeat`; add optional `input.move_stick`; Rule 24 sampler latches presses on physics steps that skip a game tick; Open Questions 6 and 10 closed.
9. **`design/gdd/game-events-and-session.md`**: add `run.assisted` (latch), the game-speed gate (F2), `access.continue_timer` for `continue_seconds` (registry range 5-15 is unchanged; the option is an override), and "assisted run → `submit_run` returns not ranked, no `one_credit_clear`".
10. **`design/gdd/player-plane.md`** Open Question 3 closed (steady 65 % under Reduce flashing); ring size and opacity options in V6.
11. **`design/gdd/bullet-manager.md`** V3: add "`access.ally_shot_dim`, F3 of Accessibility".
12. **`design/gdd/stage-end-tally.md`**: no NEW BEST for assisted runs; accessibility row remains true.
13. **`design/gdd/vfx-and-screen-feedback.md`**: classify `fx_clank` and `fx_ping` as **T1**; Open Question 7 closed (REDUCED removes the local shake; no separate toggle); `access.effects_level` and `access.reduce_pulsing` registered by Accessibility.
14. **`design/gdd/audio.md`**: add a `visual_twin` column to the event table with the Rule 30 entries; `audio.mono` registered; chain-cue sounds (`access.chain_cue_audio`).
15. **`design/gdd/plane-kits-lancer-leech.md`** Open Question 2 closed (Tap Assist and Fire toggle suffice).
16. **`design/gdd/bombs.md`** Open Questions 2 and 3: pointer to Rule 25 (Target tier).
17. **`design/gdd/powerups-and-drops.md`** Open Question 9 closed (no item pulse option) and **`design/gdd/wave-and-stage-director.md`** Open Question 10 closed (no text label on stage-progress segments; shape plus the numeric boss percentage).
18. **`design/gdd/critical-break.md`** Open Question 8: rumble toggle is `access.rumble`; Interactions row for Accessibility becomes "GDD: yes".
19. **`design/gdd/coop-and-team-chain.md`**: assisted co-op runs are unranked.

## Tuning Knobs

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `access.reduce_flashing` | false | bool | — | — | CB, Collision, HUD, Tally, Player plane, Era shift |
| `access.era_transition_short` | false | bool (PRESENTATION, apply EVENT, tier MVP hook; owner Era shift 19) | — | — | Era shift short mode (release tick 96 instead of 201); not part of the Calm preset (added 2026-11-03, wave 3b) |
| `access.reduce_pulsing` | false | bool | — | — | HUD arbiter, VFX `pulse_pct` |
| `access.reduce_motion` | false | bool | — | — | HUD, Parallax, Warning, **Menus (Credits roll)** *(added 2026-11-03, wave 5 batch 2)* |
| `access.effects_level` | FULL | FULL / REDUCED / MINIMAL | — | — | VFX tiers |
| `access.background` | FULL | FULL / DIMMED / PLAIN | — | — | Parallax, grayscale gate |
| `bg_dim_pct` (F4) | 65 | 40-90 | Field nearly black, loses era | Little contrast gain | Grayscale gate |
| `access.hitbox_ring_opacity` | 100 | 40-100 step 20 | Ring invisible (floor 40) | — | Player plane V6 |
| `access.hitbox_ring_size` | NORMAL (22) | 22 / 30 | — | Reads as an enemy ring if over 30 | Ring bullets 14-18 px |
| `access.ally_shot_dim` | 0 | 0 / 25 / 50 | — | Allies' shots unreadable (floor 25 %) | Bullet manager V3 |
| `op_floor` (F3) | 25 | 15-40 | Invisible shots | Dim option weak | Co-op |
| `access.player_palette` | DEFAULT | DEFAULT / LUMA_SPREAD | — | — | HUD theme, F5 |
| `access.hud_contrast` | STANDARD | STANDARD / HIGH | — | — | HudTheme |
| `access.chain_bar_near_plane` | false | bool | — | Clutter in 4P if default on | Layer 7 |
| `access.text_size` | 0 | 0-3 | — | Menus scroll heavily | Localization F1 |
| `mult` table (F1) | 100/125/150/200 | steps 100-200 | Little gain | Bengali XL clipping | `bn_size_s` |
| `access.confirm_style` | HOLD | HOLD / DOUBLE_TAP | — | — | Menus |
| `access.confirm_hold` | NORMAL (60) | 40 / 60 / 90 ticks | Accidental confirm | Tiring | Menus |
| `access.nav_repeat` | NORMAL (18/6) | 12/4, 18/6, 30/10 | Overshoot | Slow lists | Input F4 |
| `access.untimed_menus` | false | bool | — | — | Name entry, Lobby |
| `access.continue_timer` | STANDARD (600) | 600 / 1,800 / none | Panic | Stalls co-op if untimed | Session `continue_seconds` 10 |
| `access.tally_auto_advance` | true | bool | — | — | Tally `settle_hold` 300 |
| `access.game_speed_pct` | 100 | 50-100 step 10 | Too slow to be playable (<50) | — | Ticks, PRACTICE flag |
| `access.auto_bomb` | false | bool | — | — | Collision, Bombs (Target) |
| `access.deathbomb_grace` | 0 | 0 / 3 / 6 ticks | — | Pierces Every Hit Counts | Collision, Bombs (Target) |
| `access.chain_cue_audio` | true (wave 4) | bool | — | — | `chain_window`; Audio chain-window tick |
| `access.chain_cue_rumble` | false | bool | — | — | `chain_window` |
| `access.rumble` | NORMAL | OFF / LOW / NORMAL | — | — | Input (Target) |
| `access.first_run_prompt_done` | false | bool | — | — | Menus |
| `input.fire_toggle` / `tap_assist` / `dz_preset` / `move_stick` | false / false / default / LEFT | per Input | — | — | Input-owned |

**Owned elsewhere:** `audio.master/music/sfx/mono` → Audio (24); `play_top`, bezel styles → Art bible, Display (4); `font tiers`, `bn_size_s` → Localization (27); `confirm hold 60`, `name_entry_seconds 30` → Menus (22) / Save (26); `continue_seconds 10` → Session (1); `chain_window 60` → Chain tracker (7); `charge_hold_ticks 18`, `tap_assist_until` → Plane kits (11) / Input (2).

> Decided under auto-approve (2026-11-03): defaults all off or standard; every non-boolean has three or four steps so the UI stays simple; `bg_dim_pct` 65 is chosen so the darkest era sky lands at the art bible floor of 16; `op_floor` 25 keeps 4P allies visible at the strongest dim.

## Visual/Audio Requirements

Draw layers per art bible 6.8: enemies 4, air FX 5, player shots 6, planes 7, **enemy bullets 8**, hitbox dots 9, CB frame 10, HUD and banners 11. Bullets always win; nothing here draws over layer 8 except menus and the first-run plate (no bullets on screen).

| Element | Spec |
|---|---|
| Accessibility screen | Menus style (Char plates, `#5A5148` edge, Cream text, 1 px `#14110E` outline, 7:1 or better, art bible 7.8). Groups in order: Calm preset, Visual, Colour and contrast, Text, Controls, Assists, Audio, Timing, Reset. 3 px Cream focus border plus arrow |
| Live preview | In Visual, a 120x60 px sample plate shows ring size and opacity, the four slot colours with rings and pips, and a sample ally shot at the chosen opacity. No bullets in the sample |
| PRACTICE tag | 12x12 plated tile (hourglass pictogram) in the HUD, plus the word "PRACTICE / অনুশীলন" on Pause and Results (draft Bengali, translator to confirm). Gold-neutral, not a warning colour |
| Near-plane chain bar | 26x5 px plated bar, layer 7, slot colour fill, 1 px Char frame; Alarm Red 1 px end-cap when `warn` (HUD convention); no blink |
| Steady invulnerability | 65 % opacity plane sprite (dot, ring, pips unchanged) |
| High-contrast HUD | Cream plate edges, `#A89E8A` ghost digits |
| First-run plate | **328 px wide, height by content (about 240 px)**, dual-script text, two items. *(Amended 2026-11-03, wave 5 batch 2: a fixed 120 px plate cannot hold two wrapped dual-script text blocks plus two dual-script buttons; the height follows the text, it does not clip it.)* |
| Audio | No new sounds except the optional chain tick (Audio asset; a single 40 ms soft click, below the CB sting in loudness). The PRACTICE tag has no sound |

**Accessibility checklist (Game Accessibility Guidelines basic/intermediate and Xbox Accessibility Guidelines topics mapped to options)**

| Guideline topic | Level | Where met |
|---|---|---|
| Remappable controls | Basic | Rule 21, Input Rules 34-39 |
| No simultaneous presses required | Basic | Audit: no action needs two buttons on one tick; Fire + move + Drone/Bomb are separate presses; pad Bomb has a trigger and a button; toggle for Fire |
| Hold alternatives | Basic | `fire_toggle`, `confirm_style`, `confirm_hold` |
| Adjustable text size | Basic | Rule 19 |
| Contrast and text outline | Basic | Art bible 4.7, 7.8; `hud_contrast` |
| Not colour-only | Basic | Rule 17, art bible 4.8, 7.10 |
| Separate volume sliders | Basic | Rule 27 (master, music, SFX; UI follows SFX) |
| Subtitles | Basic | Not applicable: there is no speech; banners are text |
| Visual twin for important sounds | Basic | Rule 30 |
| Avoid flashing | Basic | Rules 8, 34; single CB frame only |
| Pause anywhere (single player) | Basic | Rule 31 |
| Difficulty or speed option | Intermediate | Rule 24 (practice) |
| Stick deadzone | Intermediate | `dz_preset` |
| One-handed play | Intermediate | Rule 21 presets |
| Reduced motion | Intermediate | Rule 10 |
| Aim and timing assists | Intermediate | Tap Assist, Rule 25 (Target) |
| Photosensitivity warning | Intermediate | Rule 34 |
| Screen-reader | Not applicable at VS | Menus expose focus order and text; no platform narration (Open Question 8) |

## UI Requirements

The Accessibility screen is part of Menus' Settings flow; it can be opened from Title and Pause. Elements: option rows (toggle, step selector, slider-by-steps, action), preview plate, preset buttons, reset, first-run plate, PRACTICE tag, and the Controls sub-screens (rebind list, one-handed presets, per-slot pad maps, input test).

📌 **UX Flag**: run /ux-design for the Accessibility screen, the Controls (remap, presets, per-slot pad maps, input test) screen and the first-run photosensitivity plate before writing epics.

## Acceptance Criteria

**Defaults used:** all `access.*` booleans false; `effects_level` FULL; `background` FULL; `bg_dim_pct` 65; ring opacity 100, size NORMAL; `ally_shot_dim` 0; `player_palette` DEFAULT; `hud_contrast` STANDARD; `text_size` 0; `confirm_style` HOLD; `confirm_hold` 60; `nav_repeat` NORMAL 18/6; `continue_timer` STANDARD 600; `tally_auto_advance` true; `game_speed_pct` 100; `op_floor` 25; `bn_size_s` 17.

**Test setup:** The option registry, text table, tick gate, palette check, opacity and bar formulas are node-free `RefCounted` classes (`AccessOptions`, `TextSteps`, `SpeedGate`, `PaletteCheck`). Tests use `extends SceneTree` style like `tests/unit/test_chain_tracker.gd` in `tests/unit/test_access_*.gd`. Defs, tables, matrices and palettes are read from `data/accessibility/*.tres` and `data/ui/player_palettes.tres`, never typed in tests. Time is integer physics steps with no `delta`. Gameplay-hash tests replay one recorded input list with the seeded RNG passed in. Manual items use captures at 1x and 4x.

**Registry and rules**

- **AC-01 [Unit] (Rule 1):** every key in `access_options.tres` is unique, has a type, default, allowed set, tier, owner and `label_key`/`help_key` present in `_meta.csv` (Localization Rule 8); a duplicate key fails the data test.
- **AC-02 [Unit] (Rule 2):** on a fresh store every `access.*` key returns its default; `access.reduce_flashing` false, `effects_level` FULL, `game_speed_pct` 100.
- **AC-03 [Unit] (Rule 2):** a saved enum value not in the allowed set (e.g. `access.background = "x"`) loads as `FULL`; neighbouring keys keep their saved values; an unknown future key survives a load-save round trip.
- **AC-04 [Unit] (Rule 3):** a consumer lint finds no write to an `access.*` key outside the Accessibility screen and the Calm preset code.
- **AC-05 [Integration] (Rule 4):** `reduce_flashing` flipped during a Critical Break after `T` leaves the running timeline unchanged; the next break uses the new value.
- **AC-06 [Unit] (Rule 5, 31):** a lint over option consumers finds no option that references an enemy-bullet colour, shape, size, outline, opacity, speed, layer or hit radius, and none that sets the dot opacity below 100 %.
- **AC-07 [Unit] (Rule 6, 7):** replaying one recorded 3,600-tick input list with every PRESENTATION option at each extreme produces an identical per-tick `GameState` hash to the all-default run (RNG seeded).

**Visual**

- **AC-08 [Manual] (Rule 8):** `reduce_flashing` on, 10 s capture across a Critical Break: no frame is fully white, 80 warm particles spawn (40 at REDUCED), the banner shows, and no consecutive frames differ in mean luma by more than 8 %.
- **AC-09 [Manual] (Rule 8):** `reduce_flashing` on, respawn invulnerability for 120 ticks: the plane draws at 65 % opacity on every tick, no hide frames; off: the 10 fps hide blink (period 12 ticks) plays; the dot and ring have the same opacity in both.
- **AC-10 [Manual] (Rule 8):** hit tint on a laser stream with `reduce_flashing` on shows only the 1 px outline pulse at 3 Hz or less; the HUD milestone shows no sparkle; the Tally NEW BEST has no pulse.
- **AC-11 [Unit] (Rule 9):** `reduce_pulsing` on: the HUD arbiter yields no pulsing element; `pulse_pct(t, P, lo, hi)` returns `hi` for every `t`; off: it varies between `lo` and `hi`.
- **AC-12 [Unit] (Rule 10):** `reduce_motion` on: a score gap of 1,250,000 snaps on the next tick; off: tick 1 shows 208,334 (HUD AC-13).
- **AC-13 [Manual] (Rule 10):** `reduce_motion` on: Warning stripes are static; L0, L1, L2 scroll at half speed and L4 is hidden (`set_scroll_scale(50)`, Parallax Rule 29b); L3 and a ground target stay locked together at gameplay speed.
- **AC-14 [Unit] (Rule 11, 30):** with `effects_level` MINIMAL, an armoured hit still spawns `fx_clank` and an ignored hit spawns `fx_ping`; both are T1 in `effects.tres`.
- **AC-15 [Manual] (Rule 12, 37):** for each era, FULL / DIMMED / PLAIN grayscale captures at 4P density: every enemy bullet is readable (core minus background at least 89 on dark backgrounds, background minus outline at least 108 on pale ones, art bible 4.2).
- **AC-16 [Unit] (F4):** `bg_dim_pct` 65: luma 25 → 16, 17 → 11, 125 → 81; layer modulate for enemies, bullets, planes, items and HUD is exactly 1.0.
- **AC-17 [Unit] (Rule 13, F7):** ring opacity 40 → ring alpha 0.40, dot alpha 1.0; size LARGE → rings at 30 and 32 px for P4 and 30 px for P1-P3; the dot is 6 px in all states.
- **AC-18 [Unit] (Rule 14, F3):** `ally_shot_dim` 50: N=1 → 50, N=2 → 38, N=4 → 25; dim 25: N=2 → 56, N=4 → 38; own shots and drones stay 100; hit radii unchanged.
- **AC-19 [Unit] (Rule 15, F8):** `window_left` 60 / 30 / 15 / 1 → fill 24 / 12 / 6 / 1 px; `warn` true at 15 and below only; the bar is not drawn at chain 0; its layer is 7.
- **AC-20 [Unit] (Rule 16, F6):** the high theme gives ghost-digit contrast 6.46 ± 0.05 and edge contrast at least 3:1 on Cabinet Char; the standard theme gives 2.21 ± 0.05; the only further difference is that an `ALARM_FLARE` `#F2494D` headline status line resolves to Cream `#F4EBD6` (`ALARM_RED` `#E03A3E` edges and glyph fills are identical in both themes); no other `HudTheme` colour differs.

**Colour vision**

- **AC-21 [Unit] (Rule 17, F5):** LUMA_SPREAD passes `PaletteCheck`: min luma gap at least 25 (30.9), min ΔE at least 20 for protan, deutan and tritan, and at least 20 from every bullet fill; DEFAULT fails the luma rule (0.5) and is accepted only because patterns are mandatory.
- **AC-22 [Unit] (Rule 17):** switching `player_palette` changes only colours: ring patterns (solid, dashed 4 on 3 off, dotted 1 on 2 off, double) and pip counts 1-4 are identical, and every `PlayerPalette` hue is outside 225-265°.
- **AC-23 [Manual] (Rule 17, 18):** with the debug simulation on (protan, deutan, tritan, gray), four players can be told apart by ring pattern and pips in the HUD, Lobby and Pause at 1x.
- **AC-24 [Unit] (Rule 17):** no release build contains the debug overlay (build lint).

**Text**

- **AC-25 [Unit] (F1):** `font_size_px(S, step)` returns Latin cap 12 / 15 / 18 / 24 and Bengali 17 / 21 / 25 / 33; with `bn_size_s` 19 step 0 returns 19 and step 1 returns 21; sizes never decrease with the step; L and XL return the same value at every step.
- **AC-26 [Unit] (F1):** a 150 px string at step 3 measures 300 px; in a 156 px box it wraps to 2 lines and the row height is 62 px (Latin).
- **AC-27 [Manual] (Rule 19, Menus AC-58):** at step 3 the Title, Lobby cards, Pause, Settings and Board rows reflow with no clipping, lists scroll, focus stays in view, in both English and Bengali.
- **AC-28 [Unit] (Rule 20):** the HUD numerals and `play_top` (48 and 72) are unchanged at every `text_size`; HUD banner words call `font_size_px` and the XL banner size is unchanged.

**Input and assists**

- **AC-29 [Unit] (Rule 21):** a saved `input.bindings` with `pad_s1` loads for slot 1 only; slot 0 keeps the shared map; a clash in `pad_s1` drops the later override; Start, Back and pad movement cannot be overridden.
- **AC-30 [Unit] (Rule 21):** every shipped layout preset binds no reserved control (Input Rule 38), leaves Fire, Drone and Bomb each with at least one binding, and has no clash within its class.
- **AC-31 [Unit] (Rule 21):** `move_stick` RIGHT moves the plane from the right stick only; EITHER with left 0.5 and right 0.8 uses the right stick; equal magnitude uses the left.
- **AC-32 [Unit] (Rule 22):** `nav_repeat` FAST produces repeats on ticks 12, 16, 20; SLOW on 30, 40, 50; NORMAL on 18, 24, 30 (Input F4).
- **AC-33 [Unit] (Rule 22):** `confirm_style` DOUBLE_TAP confirms on two presses within 120 ticks and cancels on a press at tick 121; `confirm_hold` SHORT / NORMAL / LONG confirms at 40 / 60 / 90 held ticks.
- **AC-34 [Integration] (Rule 22):** `untimed_menus` on: name entry stays open for 5,000 ticks; off: it ends at 1,800 ticks (Save `name_entry_seconds` 30).
- **AC-35 [Unit] (Rule 22, F9):** `continue_timer` STANDARD = 600 ticks, EXTENDED = 1,800; UNTIMED with another slot Alive = 1,800; UNTIMED with none Alive never expires.
- **AC-36 [Unit] (Rule 24, F2):** at 80 % over 100 physics steps exactly 80 game ticks run, the first ten steps give N R R R R N R R R R, and never two ticks in one step; at 50 % the pattern is N R repeating; at 100 % every step runs.
- **AC-37 [Unit] (Rule 24):** the same inputs on the same seed run at 100 % and at 60 % give identical `GameState` hashes at every game tick; a press and release between two game ticks is delivered as `pressed` on tick T and `released` on T+1; `buffer_ticks` 6 counts game ticks.
- **AC-38 [Integration] (Rule 23):** game speed set to 90 at physics step 1,000 of a run sets `run.assisted` on the next game tick; setting it back to 100 leaves it true; `submit_run` returns "not ranked", no board changes, `one_credit_clear` false, no NEW BEST on the Tally, Pause and Results show PRACTICE; `run_started` clears the latch.

**Audio and cues**

- **AC-39 [Unit] (Rule 30):** every Audio event of priority P0 or P1 has a non-empty `visual_twin` that names an existing effect or HUD element; a row without one fails the lint; clank and ping name `fx_clank` and `fx_ping`.
- **AC-40 [Manual] (Rule 27):** `audio.mono` on: a sound at canvas x 40 and one at x 320 have equal level in both channels; the Master output is mono (method per Audio OQ 3).
- **AC-41 [Unit] (Rule 28):** `chain_cue_audio` on: one tick request at `window_left` 15 per chain, none at 16 or 14, none after the chain drops; `chain_cue_rumble` with `access.rumble` OFF sends nothing.

**Cognitive and flow**

- **AC-42 [Integration] (Rule 31):** pressing Start on each of: Warning, boss intro, fly-in, Continue countdown, Tally, a Critical Break banner opens Pause within 1 tick; the Continue countdown stays frozen while paused.
- **AC-43 [Unit] (Rule 32):** `tally_auto_advance` true exits 300 ticks after the last settle; false never exits (Tally AC-31).
- **AC-44 [Integration] (Rule 34):** first launch with Save: the prompt shows once before Title; **Reduce flashing and effects** sets the four values in one commit; either choice sets `first_run_prompt_done`; the second launch skips it; with Save absent the prompt is hidden.
- **AC-45 [Unit] (Rule 34):** the Calm preset then **Reset these options** returns every `access.*` key to its default; the hold-to-confirm honours `confirm_style`.
- **AC-46 [Manual] (Rule 36):** keyboard-only and gamepad-only complete the Accessibility screen, every rebind, a preset, and the first-run plate with no mouse; the screen works on Web.
- **AC-47 [Manual]:** Controls audit: no action in the game needs two buttons on the same tick; a one-handed keyboard preset and the one-hand pad preset clear stage 1 on the Lancer.

**Performance and determinism**

- **AC-48 [Perf] (Rule 24):** `SpeedGate.step()` costs under 2 microseconds per call on REF-WEB; the Accessibility screen adds no per-tick work during a stage (zero `tick()` calls when no option is time-based).
- **AC-49 [Unit] (determinism):** the registry, formulas F1-F9 use only integers and the injected tables; the same inputs give the same outputs twice; no `randf()`.
- **AC-50 [Unit] (Save):** every option round-trips through Save (write, reload) with the same value and type, including enums as strings.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Where does the PRACTICE tile go in the HUD strip (a free 12x12 rect in each of the three layouts)? | HUD (20) / ux-designer | HUD UX |
| 2 | P4 `#FFB4EA` vs Needle `#9AA8FF` is ΔE 22.4 under protan (passes 20 narrowly). Re-check with real sprites and the white needle core; tweak P4 if the sprite test fails | art-director | Art bible spike |
| 3 | Verify the Machado 2009 matrix values and ΔE method (CIE76 vs CIEDE2000) in `cvd_matrices.tres` against the paper; the numbers in F5 were computed from remembered coefficients | accessibility-specialist | Before Vertical Slice |
| 4 | Is the steady 65 % invulnerability opacity enough to read "I am invulnerable" without the blink? Playtest with photosensitive testers | Playtest | Vertical Slice |
| 5 | Right-hand keyboard preset keys (`.` `,` `/`) clash with some layouts; confirm on AZERTY / QWERTZ using physical keycodes, and a left-hand-only gamepad grip that also uses the right stick | Input (2) | Vertical Slice |
| 6 | Placement and layering of the near-plane chain bar in 4P density; may need a sub-layer under planes | art-director | Art review |
| 7 | Test with real Xbox Adaptive Controller and a one-handed pad grip | QA / Accessibility | Vertical Slice |
| 8 | Platform screen-reader and narration for menus (Web ARIA, Switch, mobile). Out of scope for VS | UX / platform | Target |
| 9 | ~~Practice start at a chosen stage or boss, and unlock rules (Tutorial 30, Boss rush 32)~~ **Closed 2026-11-03:** not part of Flight School (tutorial.md); boss practice = Single Boss with a game-speed assist (unranked, PRACTICE), unlocked per boss on its first KILLED or CRITICAL_BREAK defeat (online-leaderboards-boss-rush.md). | Game designer | Target |
| 10 | The game-speed scheduler pattern (accumulator on physics steps) needs an ADR; confirm no `Engine.time_scale` use, and music behaviour at less than 100 % | godot-specialist | Before Vertical Slice |
| 11 | Mono downmix method in Godot 4.7 is unverified (Audio OQ 3); the option depends on it | Audio (24) | Audio spike |
| 12 | Is a separate UI volume slider wanted after playtests (currently follows SFX)? | Audio (24) | Playtest |
| 13 | Collision `will_die` callback shape for auto-bomb and death-bomb grace | Collision (6), Bombs (12) | Target |
| 14 | Bengali strings for all `opt.*` keys and the first-run plate need translation and conjunct testing at text steps 0-3 | Localization lead | Before string soft freeze |
| 15 | ~~`display.bezel` (Save: auto / off) and `bezel_style` (Display: Art / Plain) use different names; settle one key before the Visual group is built~~ **Closed 2026-11-03:** Save adopts the Display / Menus keys `display.scale_mode`, `display.window_mode`, `display.tate_mode`, `display.bezel_style` (Art / Plain), `display.window_size`; the old `display.bezel` and `display.integer_scale` keys are removed (wave 3b Save reconcile) | Display (4) / Save (26) | Vertical Slice |
