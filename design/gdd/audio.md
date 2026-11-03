# Audio

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (audio-director) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (primary: the player must always hear the cues that matter), History Accelerates (sound changes with the era), Every Hit Counts (death, chain and Critical Break have clear voices); supports Four Planes, Four Games (per-player pitch and pan identity)
> **Revision 2026-11-03 (final doc closeout, consistency-report C1)**: one UI cue id scheme everywhere - `sfx_ui_*`; the dotted `ui.*` and unprefixed `ui_*` forms are retired; `ui.rank` resolved to `sfx_ui_new_best`; six Menus-only cues added to the Sound Event List (`sfx_ui_lock`, `sfx_ui_unlock`, `sfx_ui_start_run`, `sfx_ui_hold_tick`, `sfx_ui_hold_done`, `sfx_ui_toggle_lang`).
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: one sentence of ownership added to the UI-sound part of the event list - the cross-screen UI sound **standard** belongs to `design/ux/arcade-ui-style.md` section 5, this GDD owns the cue **ids**.

## Overview

Audio is the sound layer of MorutJan: **music** (one track per state, crossfaded), **sound effects** (about 75 sounds, each owned by the system that triggers it) and the **mix** (buses, levels, ducking, voice limits). MVP is "basic": two eras of sound (1941 and 1970s, matching the two MVP stages), no voice lines, no ambience layer, no beat-synced music.

**The data layer:** Audio is **presentation only**. It listens to events from other systems (Game events bus, Pattern library, Collision, Kits, Bombs, Boss, Powerups, Chain, Co-op, Scoring, Critical Break, Input, menus) and never writes gameplay state. Every request is turned into a play / drop decision by a node-free `RefCounted` policy class that runs on integer ticks: a **rate gate** per sound ID, a **voice pool** per family, and **priority stealing**. The policy takes no `delta`, no RNG and no node references, so the same event stream always gives the same decisions (AC-37). A thin Node adapter owns the `AudioStreamPlayer` pool, the buses and the music players. All numbers live in `data/audio/*.tres`. This GDD consolidates every audio proposal that other GDDs left "(P), audio-director to confirm" and turns them into one rule set.

**The player impact:** In a 2000-bullet, 4-player scene the player still hears the things that decide the run: their own death, the Critical Break sting, the Warning siren, the 1UP jingle and the "clear" thud always play and are never stolen. Enemy volleys are the quietest, most droppable layer. Music sits under the effects and ducks for big moments. Each era sounds different (brassy 1941, analogue 1970s, digital 2030s, warped 2100) but every cue keeps the same meaning in every era, so a veteran never has to relearn what a sound says. Every important sound also has a visual twin (see Accessibility), so the game stays playable muted.

## Player Fantasy

The cabinet is calling you. The title music is proud and gilded; the first stage is a brisk brass march you could hum; the 1970s turn it cool and tense; the boss track is the same tune in a darker key of mind, heavier, with the drums from a *dhak*. When you finally land a Critical Break the music drops out for a second and one huge brass-and-synth stab says *you did that*. When you die, the thud is dull and falling, and the field goes quiet for a heartbeat so you know exactly what just happened.

| Pillar | How audio serves it |
|---|---|
| Every Hit Counts | Death thud vs bomb chime are opposites. Chain milestones rise in pitch (50, 100, 200). Armour clank and immune ping say "that hit did not count". |
| Readable Chaos | Strict voice limits, rate gates and priorities; enemy volleys are the first layer dropped; death and Critical Break are never masked. |
| Four Planes, Four Games | Each slot has its own pitch step and stereo position for its own actions. |
| History Accelerates | Instrumentation, tempo and SFX timbre change per era; the reversed, warped 2100 sound quotes the earlier eras. |

## Detailed Design

### Core Rules

**Buses and levels**

1. **Bus layout** (Godot `AudioServer` buses). Base offsets are the mix balance at slider maximum; the player sliders add on top.

    | Bus | Parent | Base offset (dB) | Slider | Holds |
    |---|---|---|---|---|
    | `Master` | — | 0 | `audio.master` | Everything. Ends in a limiter (ceiling −1.0 dB). |
    | `Music` | Master | −4 | `audio.music` | Music players only. |
    | `SFX` | Master | 0 | `audio.sfx` | Parent of the three gameplay SFX buses. |
    | `SFX_Crit` | SFX | 0 | — | Death, Critical Break, extend, Warning siren, clear thud. |
    | `SFX_Player` | SFX | −4 | — | Kits, bombs, drones, pickups, chain, cancel, team. |
    | `SFX_Enemy` | SFX | −6 | — | Volleys, enemy deaths, Warp, lock, flak, boss sounds. |
    | `UI` | Master | −4 | `audio.sfx` (same step as SFX) | Menus, tally, name entry, join. |

    No `Voice` bus at MVP (no voice lines; Localization OQ 12 closed). If a voiced announcer is added, it gets a `Voice` bus under Master that ducks Music by 6 dB and needs a language-audio rule.
2. **Default player levels** come from Save (26): `audio.master` 10, `audio.music` 7, `audio.sfx` 8. Step to gain uses Save F6, owned here (**F1**). Step 0 mutes the bus. The sliders are integers 0–10 (Save Rule 16).
3. **Mono option:** new Save key `audio.mono` (bool, default false, owner Audio 24 / Accessibility 28). When true, all per-sound pan is forced to 0 and the Master bus output is downmixed to mono. How to downmix is an implementation question (OQ 3).
4. **Loudness targets** (asset side, see Visual/Audio Requirements): music masters −18 LUFS integrated, true peak ≤ −1.5 dBTP. SFX are normalised by peak class (Critical −3 dBFS, Player −6, Enemy fire −10, UI −8, Pickup −9). A 60 s stage capture at default settings must measure **−16 LUFS integrated ±2** with true peak ≤ −1.0 dBTP.

**Events, ticks and the policy**

5. **Event-driven.** Audio never polls gameplay state except `Settings`. It subscribes to the events in the Interactions table. Events are queued during the tick; at the end of the tick (after every simulation step, provisional "presentation" step → ADR) the policy processes the queue once, in priority order (lowest number first, then arrival order). No sound is delayed past the tick it was requested in.
6. **Rate gate (F2).** Each sound ID has `(N, W, scope)`: at most `N` plays in any `W` ticks per scope key (global, slot or target id). The default is the Bullet manager rule: `N = 1, W = 3` (gap of 3 ticks = 50 ms) per sound ID. Per-ID overrides are in the Sound Event List. A refused request is silent and costs nothing else.
7. **Voice pools (F3).** Every sound belongs to one pool with a cap. Caps come from the GDDs that proposed them; this GDD confirms all of them:

    | Pool | Cap | Contents | Origin |
    |---|---|---|---|
    | CRIT | 4 | Death boom (≤ 2), Critical Break sting (1), extend jingle (1) | Player plane A1, CB V6 |
    | HIT | 4 | Screen clear (1 reserved), clank (≤ 2), ping (≤ 1) | Collision A1 |
    | PLANE | 3 | FlyIn whoosh, drone pop (gain / lost) | Player plane A1 (death moved to CRIT) |
    | EDEATH | 4 | SMALL / MEDIUM / LARGE destroyed, tells, plating | Enemy A1 |
    | BULLET | 8 | Enemy fire (≤ 4 of them), player shot ticks (≤ 1 per slot), Warp, cancel, pickups, bomb accept, lock tone | Bullet manager A1/A2 |
    | KIT | 8 (≤ 4 per slot) | Laser, drone, hit tink | Kits A1 |
    | BOMB | 6 (≤ 3 per slot) | Bomb hum, launch, clamp, thud, blips | Bombs A1 |
    | BOSS | 4 | Intro rumble, part kill, core exposed, heartbeat loop, enrage drone, death series | Boss A1 |
    | CHAIN | 3 | Milestone, chain dropped, window tick, cap-hold chime | Chain, Scoring |
    | TEAM | 1 | Team start / end | Co-op A1 |
    | UI | 4 | All UI-bus sounds | Input A1 |
    | WARN | 1 | Warning siren loop | this GDD |

    Sum of caps is 50; **global SFX cap = 32 voices** (`max_global_voices`; music players are not counted). Both caps apply: a sound must be admitted by its pool and by the global cap.
8. **Priority bands** (lower number = more important). A sound has one band from the Sound Event List.

    | Band | Name | Examples |
    |---|---|---|
    | P0 | Critical | Own death, CB sting, extend / 1UP jingle, Warning siren, screen-clear thud |
    | P1 | Major | Cancel (small and large), bomb accept, boss part kill / death, LARGE destroyed |
    | P2 | Important | Warp cues, lock tone and click, MEDIUM destroyed, armour clank, laser start, CB armed / miss |
    | P3 | Normal | SMALL destroyed, kit abilities, medal / pod / chain pickups, chain milestone, hit feedback |
    | P4 | Fire | Enemy volley sounds, player shot ticks, gem ticks, denied blips |
    | P5 | Ambient | Team cues, FlyIn, ping, tink, parked hum, grace click, dock |

    This matches the Bullet manager order (cancel > Warp > enemy fire > player fire) and keeps pickups below cancel.
9. **Admission and stealing (F3).** A new sound is admitted if its pool and the global cap have a free voice. If full, it may **steal** the least important active voice in the full pool (highest band number, then oldest start tick) only if that voice's band is **strictly lower in importance** than the new sound's. Equal band never steals (the new sound is dropped), with one exception from the Bullet manager: a **boss volley may steal the oldest enemy-fire voice**. **P0 voices are never stolen.** A P0 sound arriving when its pool is full of P0 voices still plays on the oldest P0 voice (a death boom replaces an older death boom).
10. **Per-tick burst cap:** at most `max_new_voices_per_tick` = 6 new voices start in one tick. Extra requests are dropped, least important first; P0 requests are exempt.
11. **Round-robin variants, no RNG.** Sounds with several variants (SMALL pop ×3, clank ×3, fan "pew" ×2) cycle through them with a per-ID counter that increments only when the sound actually plays. Audio never calls a random function.
12. **Pitch (F4):** `pitch_scale = 2^(semitones/12)`. Used for slot identity, gem steps and chain milestones.
13. **Co-op identity (rules for N ≥ 2 only; a solo player always plays at offset 0 and pan by position):**
    - **Pitch:** sounds that belong to one player's own action (shot tick, laser start, bomb accept, drone pop, join chime, deploy) are shifted by the slot step: P1 0, P2 +2, P3 −2, P4 +4 semitones.
    - **Pan (F5):** every positional sound is panned by the world x of its source: player sounds with width 0.6, world sounds (enemy fire, deaths) with width 0.35. Menu and UI sounds are centred.
    - **Trim (F6):** `SFX_Player` is lowered 1.5 dB per extra player so four stacked planes do not clip the mix.
14. **Ducking (F7).** Named duck rules lower a bus for a time, with a dB depth, attack, hold and release in milliseconds. Overlapping ducks on the same bus do not add; the **deepest one wins**. A duck retriggered while active restarts from its current level. Duck table:

    | Duck | Trigger | Target bus | Depth (dB) | Attack ms | Hold ms | Release ms |
    |---|---|---|---|---|---|---|
    | `clear_hush` | Screen clear (Collision A1) | `SFX_Player`, `SFX_Enemy` | 6 | 20 | 300 | 150 |
    | `death_dip` | `player_died` | `Music` | 6 | 40 | 500 | 500 |
    | `cb_stab` | `critical_break_landed` | `Music` | 12 | 50 | 1500 | 600 |
    | `cb_stab_sfx` | `critical_break_landed` | `SFX_Player`, `SFX_Enemy` | 6 | 50 | 1500 | 600 |
    | `extend_dip` | `extend_awarded` (gained > 0) | `Music` | 4 | 30 | 1200 | 400 |
    | `timeout_dip` | `boss_defeated(TIMEOUT)` | `Music` | 12 | 200 | 2000 | 1000 |
    | `warning_dip` | `warning_started` | `Music` | 12 | 600 | until `boss_intro_started` | 0 (music is faded out instead) |

    `SFX_Crit` is never ducked. `UI` is ducked by nothing.
15. **Pause:** on pause, `Music` goes −6 dB with a low-pass at 800 Hz, all gameplay SFX buses are muted and their looping voices stop; on resume the music returns over 200 ms and loops are restarted by their owners' next events. UI sounds still play. Audio does not run the policy clock while paused (the session is not ticked).
16. **Web caveats (Godot 4.7, unverified, spike required):**
    - Browsers keep audio suspended until the first user gesture. The Title screen starts its music on the first input on Web (desktop: at boot). The first input is also what unlocks audio; the first gesture should not be a sound the player needs.
    - Since Godot 4.3 the Web export can play short sounds as browser "samples" instead of through the engine's mixer. Sample playback may skip bus effects (low-pass, limiter) and ducking. Project setting `audio/general/default_playback_type.web` must be set to **Stream** if the spike shows ducks or the limiter are bypassed. Verify on Godot 4.7 before the first Web build.
    - Output latency on Web is higher than desktop (assume 50–100 ms). Nothing in gameplay depends on audio timing, so this is accepted.
17. **No gameplay dependency.** No system may wait for a sound to finish. Music state changes never block the run flow; if a track is missing, the state plays silence and logs once.
18. **Allocation:** all players and buses are created at boot. Nothing is instantiated, loaded or freed in a tick. All SFX are preloaded at boot. Music tracks are loaded when their state is about to start (title and stage tracks are preloaded one state ahead).

**Visual-twin lint** (2026-11-03, wave 3b): every row of this table carries a `visual_twin` field in `data/audio/audio_events.tres` (not printed as a column here). Every P0 and P1 row must name an existing effect or HUD element, or the lint fails (Accessibility 28 Rule 30, AC-39). Values are the "Visual twins of critical sounds" table in Visual/Audio Requirements; `sfx_coll_clank` → `fx_clank`, the immune ping → `fx_ping` (VFX T1).

**Sound Event List (MVP).** `Era`: E = has per-era variants (suffix `_1941`, `_1970s`, later `_2030s`, `_2100`); C = constant across eras. Critical cues are always C so a veteran recognises them in every era. Limits are `N per W ticks` (scope). Where a source GDD gave a limit, it is kept.

| Sound ID (stem) | Trigger (system / event) | Bus | Band | Pool | Limit | Era |
|---|---|---|---|---|---|---|
| `sfx_plane_death_boom` | Player plane: Dying / `player_died` | Crit | P0 | CRIT | 1 per slot per death; 2 per tick | C |
| `sfx_coll_clear_thud` | Collision: screen clear (plus `clear_hush`, 0.3 s) | Crit | P0 | HIT | 1 per tick (several deaths = 1) | C |
| `sfx_cb_sting` | CB: `critical_break_landed` (1.0–1.5 s) | Crit | P0 | CRIT | 1 per boss | C |
| `sfx_score_extend_jingle` | Session: `extend_awarded(gained > 0)` (also the 1UP pickup) | Crit | P0 | CRIT | 1 per 60 ticks | C |
| `sfx_ui_warning_siren_loop` | `warning_started(duration_ticks)` | Crit | P0 | WARN | 1 | C |
| `sfx_plane_flyin_whoosh` | Player plane: FlyIn | Player | P5 | PLANE | 1 per slot; stage start merges to 1 | C |
| `sfx_plane_drone_gain` | Powerups: `drone_gained(slot, n)` | Player | P3 | PLANE | 1 per slot per tick | C |
| `sfx_plane_drone_lost` | Player plane: Dying (merged cue) | Player | P3 | PLANE | 1 per death | C |
| `sfx_coll_clank` (×3) | Collision: armour hit | Player | P2 | HIT | 1 per 6 ticks per target; 10 per 60 ticks global | E |
| `sfx_coll_ping` | Collision: immune hit | Player | P5 | HIT | 1 per 12 ticks per target | C |
| `sfx_kit_shot_tick` | Kits: `shot_volley` | Player | P4 | BULLET | 1 per 4 ticks per slot; ≤ 1 voice per slot | E |
| `sfx_kit_laser_start` | Kits: `laser_started` at tick h = 18 | Player | P2 | KIT | 1 per slot | E |
| `sfx_kit_laser_hum_loop` | Kits: laser On (pitch tied to meter); `sfx_kit_laser_end_tail` (0.2 s fall) on `laser_ended` | Player | P3 | KIT | 1 per laser; 2 loops global (others mute) | E |
| `sfx_kit_laser_ready` | Kits: `laser_ready` | Player | P3 | KIT | 1 per 120 ticks per slot | C |
| `sfx_kit_grace_click` | Kits: afterglow ends | Player | P5 | KIT | 1 per laser | C |
| `sfx_kit_drone_deploy` | Kits: `drone_deployed` | Player | P3 | KIT | 1 per slot | E |
| `sfx_kit_drone_hum_loop` | Kits: any drone parked | Player | P5 | KIT | 1 voice per slot | E |
| `sfx_kit_drone_latch` | Kits: `drone_latched` | Player | P3 | KIT | 2 per 6 ticks global | E |
| `sfx_kit_drone_denied` | Kits: `drone_denied` | Player | P4 | KIT | 1 per press | C |
| `sfx_kit_drone_dock` | Kits: `drone_docked` | Player | P5 | KIT | 1 per 6 ticks per slot | C |
| `sfx_kit_hit_tink` | Kits: normal hit | Player | P5 | KIT | 6 per 6 ticks per slot, played on a 2-voice round robin | E |
| `sfx_kit_sentry_plant` | Sentry/Breaker (29) A1: Sentry posts planted (low thud, per use, not per drone) | Player | P3 | KIT | 1 per slot per use | E |
| `sfx_kit_turret_tick` | Sentry turret shot (short tick) | Player | P4 | BULLET | 1 per 4 ticks per slot | E |
| `sfx_kit_recall_chime` | Sentry recall accepted | Player | P4 | KIT | 1 per press | C |
| `sfx_kit_charge_sting` | Entrench / Breach start at `h = 18` | Player | P2 | KIT | 1 per slot per charge | E |
| `sfx_kit_net_deploy` | Breaker net deploy (whoosh) | Player | P3 | KIT | 1 per slot per use | E |
| `sfx_kit_net_fizz` | Breaker net pulse that erased ≥ 1 bullet (cancel > fire; no sound per erased bullet) | Player | P3 | BULLET | 1 per 6 ticks per slot | E |
| `sfx_kit_drone_spent` | Breaker drone spent (quiet click) | Player | P5 | KIT | 1 per drone | C |
| `sfx_kit_bolt_launch` | Breaker breach slug / return bolts launched (shared tick) | Player | P4 | BULLET | 1 per 5 ticks per slot | E |
| `sfx_kit_stock_ready` | Breaker stock first reaches 2 after being below | Player | P5 | KIT | 1 per 120 ticks per slot | C |
| `sfx_bomb_accept` | Bombs: `bomb_used(slot)` | Player | P1 | BULLET | 1 per bomb per slot | E |
| `sfx_bomb_hum_loop` | Bombs: Lancer hold / sweep (pitch falls) | Player | P3 | BOMB | 1 per slot; 2 global | E |
| `sfx_bomb_launch` | Bombs: Leech launch | Player | P3 | BOMB | 1 per bomb | E |
| `sfx_bomb_hook_clamp` | Bombs: hook clamp | Player | P4 | BOMB | 2 per 6 ticks global | E |
| `sfx_bomb_hook_thud` | Bombs: hook detonation | Player | P3 | BOMB | 2 per 6 ticks global | E |
| `sfx_bomb_empty_blip` | Bombs: `bomb_denied(NO_BOMBS)` | Player | P4 | BOMB | 1 per press | C |
| `sfx_bomb_topup_chime` | Bombs: stage-start top-up | Player | P4 | BOMB | 1 per slot | C |
| `sfx_bomb_bastion_loop` | Bombs Rule 35 Bastion: rising thrum at `k = 0`, falling tail `sfx_bomb_bastion_tail` at `k = 71`; `sfx_cancel_large` at `k = 0` only | Player | P3 | BOMB | 1 voice per slot | E |
| `sfx_bomb_backlash_sweep` | Bombs Rule 36 Backlash: one rising sweep at `k = 0`; `sfx_cancel_large` at `k = 0` | Player | P3 | BOMB | 1 voice per slot | E |
| `sfx_cancel_large` | Bullet manager: large cancel (bomb, `k = 0`) | Player | P1 | BULLET | 1 per tick, first request wins | E |
| `sfx_cancel_small` | Bullet manager: small cancel (part kill; "muffled sweep") | Player | P1 | BULLET | shares the cancel gate with large | E |
| `sfx_warp_freeze` / `sfx_warp_reaim` | Bullet manager: Warp freeze / re-aim | Enemy | P2 | BULLET | 1 each per volley | E |
| `sfx_enemy_fan_pew` (×2) | Pattern library: `volley_fired` fan / stream | Enemy | P4 | BULLET (enemy fire ≤ 4) | default 1 per 3 ticks per ID | E |
| `sfx_enemy_ring_thump` | `volley_fired` ring | Enemy | P4 | BULLET | default | E |
| `sfx_enemy_wall_sweep` | `volley_fired` wall | Enemy | P4 | BULLET | default | E |
| `sfx_enemy_spiral_tick` | `volley_fired` spiral (one rotating tick sample, not per bullet) | Enemy | P4 | BULLET | default | E |
| `sfx_enemy_lock_tone` | Pattern library: `lock_started` (rises; **F8**) | Enemy | P2 | BULLET | 2 audible locks at once; extras silent | E |
| `sfx_enemy_lock_click` | `lock_ended(fired = true)`; none when not fired | Enemy | P2 | BULLET | 1 per lock | E |
| `sfx_enemy_flak_fuse` | `flak_fuse(pos, ticks)` (ticks speed up; **F8**) | Enemy | P3 | BULLET | 1 per fuse; 3 global | E |
| `sfx_enemy_flak_pop` | `flak_burst(pos)` | Enemy | P3 | BULLET | 3 per 6 ticks global | E |
| `sfx_enemy_small_pop` (×3) | Enemy: `enemy_destroyed` SMALL | Enemy | P3 | EDEATH | 1 per 3 ticks global | E |
| `sfx_enemy_medium_crunch` | `enemy_destroyed` MEDIUM | Enemy | P2 | EDEATH | 1 per 6 ticks | E |
| `sfx_enemy_large_boom` | `enemy_destroyed` LARGE (+ 0.5 s rumble) | Enemy | P1 | EDEATH | 1 per 12 ticks | E |
| `sfx_enemy_tell_clunk` | Enemy: `enemy_tell` (MEDIUM / LARGE) | Enemy | P4 | EDEATH | 1 per tell | E |
| `sfx_enemy_plating_clatter` | Enemy: `enemy_plating_ended` | Enemy | P4 | EDEATH | 1 per enemy | E |
| `sfx_boss_intro_rumble` | Boss: `boss_intro_started` | Enemy | P1 | BOSS | 1 per boss | E |
| `sfx_boss_part_kill` | Boss: `boss_part_destroyed` (thud + metal tear) | Enemy | P1 | BOSS | 1 per part; 2 per 6 ticks | E |
| `sfx_boss_core_exposed` | Boss: `boss_core_exposed` (rising two-note) | Enemy | P1 | BOSS | 1 per boss | C |
| `sfx_boss_heartbeat_loop` | Boss: `boss_critical_started` to window closed / death | Enemy | P2 | BOSS | 1 | C |
| `sfx_boss_enrage_loop` | Boss: `boss_enraged` (low drone, rises over the ramp) | Enemy | P2 | BOSS | 1 | E |
| `sfx_boss_timeout_fade` | Boss: `boss_defeated(TIMEOUT)` (engine fade) | Enemy | P1 | BOSS | 1 | E |
| `sfx_boss_death_series` | Boss: death sequence (staggered booms, deep final boom) | Enemy | P1 | BOSS | 1 per boss | E |
| `sfx_cb_armed_tick` | CB: `cb_state` first ARMED | Player | P2 | CHAIN | 1 per arming per slot | C |
| `sfx_cb_miss_blip` | CB: `critical_break_missed` (low two-tone) | Player | P2 | CHAIN | 1 per bomb | C |
| `sfx_pickup_gem` | Powerups: `item_collected_ex` GEM (**F9**) | Player | P4 | BULLET | 1 per 3 ticks global | C |
| `sfx_pickup_medal` | MEDAL (bright two-note) | Player | P3 | BULLET | 1 per 3 ticks per ID | C |
| `sfx_pickup_chain` | CHAIN (rising "+10" blip) | Player | P3 | BULLET | 1 per 3 ticks per ID | C |
| `sfx_pickup_pod` | POD (low-high "dock" click) | Player | P3 | BULLET | 1 per slot per tick | C |
| `sfx_chain_milestone` | Chain: `chain_milestone(slot, 50 / 100 / 200)` (**F4**: +0 / +4 / +7 semitones) | Player | P3 | CHAIN | 1 per slot per tick | C |
| `sfx_chain_dropped` | Chain: `chain_dropped` (soft falling tick-off; none for STAGE_END) | Player | P3 | CHAIN | 1 per slot per 6 ticks | C |
| `sfx_chain_window_tick` | Chain: window in last 25% (`red`, `window_left` ≤ 15); played only while `access.chain_cue_audio` is true (Accessibility 28 Rule 28; **default true**, so the tick is on by default and can be turned off) (2026-11-03, wave 3b; default reconciled wave 4) | Player | P5 | CHAIN | 1 per window per slot | C |
| `sfx_score_cap_hold` | Scoring: cap-hold at full rate (single soft chime) | Player | P5 | CHAIN | 1 per streak | C |
| `sfx_team_link_start` | Co-op: `team_cue_start` (two-note) | Player | P5 | TEAM | 1 per 120 ticks | C |
| `sfx_team_link_end` | Co-op: `team_cue_end` (falling note) | Player | P5 | TEAM | only after a ≥ 180-tick run | C |
| `sfx_ui_nav_tick` | Menus: move focus (slot pitch step) | UI | P2 | UI | 1 per 2 ticks | C |
| `sfx_ui_confirm` / `sfx_ui_cancel` | Menus: accept / back | UI | P2 | UI | 1 per tick each | C |
| `sfx_ui_join_chime` | Input: join accepted, in slot pitch | UI | P2 | UI | max 2 per tick merged | C |
| `sfx_ui_pad_lost` | Input: pad disconnected (low two-note) | UI | P1 | UI | 1 per tick | C |
| `sfx_ui_pause_in` / `sfx_ui_pause_out` | Session: pause / resume | UI | P2 | UI | 1 per toggle | C |
| `sfx_ui_slider_preview` | Settings: slider change on SFX / Master | UI | P3 | UI | 1 per 6 ticks | C |
| `sfx_ui_lock` | Menus (22): a Lobby slot reaches Locked (stamp thunk, slot pitch) | UI | P2 | UI | 1 per tick | C |
| `sfx_ui_unlock` | Menus (22): a Lobby slot unlocks | UI | P2 | UI | 1 per tick | C |
| `sfx_ui_start_run` | Menus (22): run commit (one rising sting) | UI | P2 | UI | 1 per commit | C |
| `sfx_ui_hold_tick` / `sfx_ui_hold_done` | Menus (22): each of the 4 `HOLD_BUTTON` segments (rising pitch) / hold completion | UI | P3 | UI | 1 per segment / 1 per hold | C |
| `sfx_ui_toggle_lang` | Menus (22): language chip toggled | UI | P3 | UI | 1 per press | C |
| `sfx_ui_tally_row` | Tally: each row reveal | UI | P3 | UI | 1 per row | C |
| `sfx_ui_tally_hero` | Tally: max-chain number lands | UI | P2 | UI | 1 per tally | C |
| `sfx_ui_new_best` | Tally / Results: NEW BEST | UI | P2 | UI | 1 per screen | C |
| `sfx_ui_name_tick` | Save / Results: name-entry character change | UI | P3 | UI | 1 per change | C |
| `sfx_ui_save_ok` / `sfx_ui_save_error` | Save: confirm sting / failure | UI | P2 | UI | 1 per save | C |
| `sfx_ui_deny` | Menus: refused action (disabled item, game full, refused rebind; Tutorial 2P row, mid-drill join) | UI | P3 | UI | 1 per press | C |
| `sfx_tut_drill_done` | Tutorial: a slot's drill completes (short rising two-note, 20 frames, quiet) | UI | P4 | UI | 1 per tick | C |
| `sfx_tut_coach_open` | Tutorial: Coach card opens (`sfx_ui_pause_in` family) | UI | P3 | UI | 1 per card | C |
| `sfx_ui_upload_tick` | Online (32): upload queued (quiet UI tick); never during a stage | UI | P4 | UI | 1 per 60 ticks | C |
| `sfx_ui_upload_ok` | Online (32): score verified (soft sting); never during a stage | UI | P3 | UI | 1 per 60 ticks | C |
| `sfx_ui_upload_error` | Online (32): upload or verification failed (error tone); never during a stage | UI | P3 | UI | 1 per 60 ticks | C |
| `sfx_rush_refit` | Boss Rush (32) Rule 39: `rush_refit_ticks` beat, drones dock between bosses (the next Warning plays `sfx_ui_warning_siren_loop` as usual) | Player | P3 | PLANE | 1 per boss transition | C |

**One id scheme (decided 2026-11-03, final doc closeout, consistency-report C1)**: every UI cue id is written in the **`sfx_ui_*`** form in every document - GDDs, UX specs and the pattern library. The earlier unprefixed `ui_*` (style guide, pattern library) and dotted `ui.*` (Menus audio table, and one row of this GDD) forms are retired and no longer appear anywhere in `design/`. The Menus cue **`ui.rank`** ("Results shows a rank") is resolved to **`sfx_ui_new_best`**, the cue the style guide already assigns to "NEW BEST stamp, new board entry"; no separate rank sound is minted. Six Menus-only cues that had no row here gained one above (`sfx_ui_lock`, `sfx_ui_unlock`, `sfx_ui_start_run`, `sfx_ui_hold_tick`, `sfx_ui_hold_done`, `sfx_ui_toggle_lang`; ids assigned 2026-11-03, audio-director to confirm the sound design). Every cue id referenced anywhere in the UX layer now has a row in the table above.

**Ownership of the UI sounds** *(added 2026-11-03, UX amendments wave 5 batch 2, decision 3)*: the UI sound **standard** - which cue plays for which interaction across screens - is owned by **`design/ux/arcade-ui-style.md` section 5**. This GDD owns the cue **ids** themselves (`sfx_ui_*` above) and their sound design, bus routing, rate gates and mix. `design/ux/interaction-patterns.md` **cites both** per pattern and restates neither. If the style guide's table and a per-pattern citation differ, the style guide wins; if the style guide names a cue id that is not in the table above, that is a bug in the style guide, not a new sound.

Not sounds (confirmed silent): Tutorial strip marks and hints (Tutorial Visual/Audio: silent on purpose), drill start (the Drill card confirm plays `sfx_ui_confirm`), drill progress reset / drill hit (the real hit sound plays, no extra cue), Online Pending status, chain hit (+1), `chain_multiplied` popup (CB sting covers it), score awards, Focus toggle, invulnerability blink and its end, `bomb_denied(BUSY)`, `item_expired`, preview-spawn stinger, Display changes, Save during a stage, rumble (Input / Accessibility own it).

### States and Transitions

Music has one **state** at a time. States follow the Session run flow plus the boss sub-states. All times are wall-clock milliseconds (music is presentation, so it may use real time; the tick policy above does not).

| State | Track (id) | Starts on | Era |
|---|---|---|---|
| `TITLE` | `mus_title_loop` | Title shown (Web: first input) | neutral |
| `SELECT` | `mus_select_loop` | Plane select shown | neutral |
| `STAGE` | `mus_stage_<era>_loop` | `stage_started(stage_index, era)` | by stage |
| `WARNING` | stage track ducked + `sfx_ui_warning_siren_loop` | `warning_started(duration_ticks)` | — |
| `BOSS` | `mus_boss_<era>_loop` | `boss_started` | by stage |
| `BOSS_DEFEAT` | silence (CB sting or death series plays) | `boss_defeated(reason, slot)` | — |
| `TALLY` | `mus_tally_loop` (jingle intro, then loop) | `tally_started` (the Tally opens at `stage_cleared`, which the Director already holds until `boss_gone` or `boss_defeated` + 90; Stage-end tally 21) | neutral |
| `GAMEOVER` | `mus_gameover_loop` (sting intro, then quiet loop) | Last slot loses its last life / continue screen | neutral |
| `ENDING` | `mus_ending_01` (one shot, 40 s) | `run_ended` with ENDING | neutral |
| `RESULTS` | keeps the previous track | Results opens | — |
| overlay `PAUSED` | current track, filtered (Rule 15) | pause | — |

**Transitions** (equal-power crossfade, F10; "cut" = start at once, no fade):

| From → To | Old track | New track | Notes |
|---|---|---|---|
| (boot) → `TITLE` | — | fade in 800 ms | Web: waits for first input |
| `TITLE` → `SELECT` | fade out 800 ms | fade in 800 ms (crossfade) | |
| `SELECT` → `STAGE` | fade out 600 ms | fade in 500 ms, starts at the track's 2-bar intro | |
| `STAGE` → `WARNING` | not stopped: `warning_dip` over 600 ms | siren loop starts at once | Siren length = `duration_ticks` (min 120 ticks, else it still plays 120) |
| `WARNING` → `BOSS` | stage track fades out 1000 ms from `boss_intro_started` | `sfx_boss_intro_rumble` at once; boss track starts at `boss_started`, fade in 300 ms | Siren stops at `boss_intro_started` (fade 200 ms) |
| `BOSS` → `BOSS_DEFEAT` (KILLED) | fade out 1200 ms | death series plays | |
| `BOSS` → `BOSS_DEFEAT` (CRITICAL_BREAK) | `cb_stab` duck, then fade out 1500 ms starting when the duck has released | CB sting at `T+1` | Boss track keeps playing under the duck |
| `BOSS` → `BOSS_DEFEAT` (TIMEOUT) | `timeout_dip`, then fade out 1000 ms | engine fade | |
| `BOSS_DEFEAT` → `TALLY` | — | cut in at the jingle | Waits for `stage_cleared` and `boss_gone` (Critical Break rule: the clear jingle waits for `boss_gone`) |
| `TALLY` → `STAGE` (next) | fade out 800 ms | fade in 500 ms | |
| any → `GAMEOVER` | fade out 600 ms | starts after a 300 ms gap | |
| `GAMEOVER` → `STAGE` (continue accepted) | fade out 300 ms | stage track restarts from its intro, fade in 500 ms | |
| last stage `BOSS_DEFEAT` → `ENDING` | — | cut in after `boss_gone` | |
| `GAMEOVER` / `ENDING` → `TITLE` | fade out 800 ms | fade in 800 ms | After Results confirm |

Rules:
- A new state request while a fade is running finishes the old fade early by cutting its remaining time to 150 ms, then starts the new one.
- Same track requested twice: no restart (e.g. `stage_started` for a stage that is already playing).
- Music is **not beat-quantised** at MVP. Every loop is authored at a constant tempo and its `bpm`, `bars` and `intro_bars` are stored in the cue data, so a later change can align transitions to a bar without re-authoring.
- A drop-in during a stage, a death or a continue never changes the music (only `death_dip`).

### Interactions with Other Systems

Interface checked (2026-11-03, wave 3b) against the GDDs now written for Wave director 16, Era shift 19, HUD 20, Tally 21, Menus 22, Parallax 23, VFX 25 and Accessibility 28. Signals still to be confirmed by their owners are marked *(provisional)*. Audio **listens** to the events below. It publishes nothing. Slot indices follow Session Rule 12.

| System | Event / data Audio reads | Audio response |
|---|---|---|
| Game events and session (1) | `stage_started`, `stage_cleared`, `boss_*`, `player_died`, `extend_awarded`, `run_ended`, `player_joined`, `coop_count_changed(old, new)` (N for trim, pitch and pan rules) | Music states; extend jingle; death boom |
| Game events (1) additions (Session Rule 13 block) | `warning_started(ticks)` (Director 16; `warning_ticks` 150), `tally_started`, `tally_row_revealed(slot, line)`, `tally_new_best(slot)`, `tally_finished` (Tally 21); `run_state_changed(state)` and `pause_changed(paused)` *(provisional)*. The tally hero sound plays on `tally_row_revealed` of the max-chain line (Tally has no separate `tally_hero_landed`) | See States and Sound Event List |
| Input (2) | UI sound triggers, pad lost, join | UI bus sounds |
| Player plane (5) | Dying, FlyIn, drone gain / lost | Death boom, whoosh, drone pops |
| Collision (6) | `player_died`, screen clear, hit results (armoured / immune) | Clear thud and `clear_hush`; clank; ping |
| Chain tracker (7) | `chain_milestone`, `chain_dropped`, window `red` | Chain sounds |
| Scoring (8) | Cap-hold full rate, `extend_awarded` | Cap-hold chime, extend jingle |
| Bullet manager (3) | Spawn / cancel / warp request counters; cancel tier and Warp events from requesters | Cancel and Warp cues; never per-bullet sounds |
| Pattern library (9) | `volley_fired`, `lock_started`, `lock_ended`, `flak_fuse`, `flak_burst` | Volley, lock, flak sounds |
| Enemy and AI (10), Boss (14), Boss power budget (15) | `enemy_destroyed`, `enemy_tell`, `enemy_plating_ended`, `boss_*`. Preview volleys use the same cue as the pattern they preview; no extra stinger | Kill, tell, boss sounds |
| Plane kits (11), Bombs (12) | Kit and bomb events | Kit and bomb sounds |
| Powerups (13) | `item_collected_ex`, `drone_gained`, `oneup_dropped` | Pickup sounds (1UP: extend jingle on `extend_awarded`, none on the pickup itself) |
| Critical Break (17) | `critical_break_landed`, `_missed`, `_expired`, `cb_state` | Sting, armed tick, miss blip, `cb_stab` |
| Co-op (18) | `team_cue_start`, `team_cue_end` (already debounced by Co-op: start ≤ once per 120 ticks, end after ≥ 180-tick runs) | Team link sounds; Audio's own gate repeats the 120-tick rule as a safety net |
| Save (26) | `audio.master`, `audio.music`, `audio.sfx`, `audio.mono`; `setting_changed` | Re-apply bus gains at once on change |
| Localization (27) | None | No spoken or localised audio at MVP |
| Display scaler (4) | None | — |

## Formulas

**F1. Volume step to gain** (adopted from Save F6)

`step_db = linear_to_db(step / 10)` ; step 0 → bus muted. Final bus gain = `base_db + step_db + trim_db`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Step | `step` | int | 0–10 | Stored slider |
| Base offset | `base_db` | float | −6…0 | Rule 1 table |
| Co-op trim | `trim_db` | float | −4.5…0 | F6, `SFX_Player` only |

**Output Range:** −∞ (mute) … 0 dB.
**Example:** defaults. Music: `−4 + linear_to_db(0.7)` = −4 − 3.10 = **−7.10 dB**. `SFX_Enemy`: `−6 + linear_to_db(0.8)` = −6 − 1.94 = **−7.94 dB**. `SFX_Crit`: 0 − 1.94 = −1.94 dB. Step 5 = −6.02 dB.

**F2. Rate gate**

`allowed = count(plays of (id, key) in ticks (t − W, t]) < N`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current tick | `t` | int | ≥ 0 | Session tick |
| Window | `W` | int ticks | 1–600 | Per sound ID |
| Limit | `N` | int | 1–10 | Plays allowed in the window |
| Key | `key` | id | global / slot / target | Scope |

**Output Range:** bool. The default `N = 1, W = 3` means a gap of at least 3 ticks.
**Example:** sound played at tick 100, default gate. Request at 102: window (99, 102] holds the play at 100 → count 1 ≥ 1 → refused. Request at 103: window (100, 103] is empty → allowed. Armour clank, 10 per 60 ticks: the 11th request within one second is refused.

**F3. Voice admission and stealing**

```
if pool.active < pool.cap and global.active < max_global_voices: play
else victim = voice in (full pool or, if only global is full, all pools)
              with max band, then min start_tick
     if victim.band > new.band (strictly less important) and victim.band != 0: steal
     elif new is boss_volley and victim is enemy_fire: steal
     elif new.band == 0 and victim.band == 0: steal the oldest P0 voice
     else drop new
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Pool cap | `pool.cap` | int | 1–8 | Rule 7 |
| Global cap | `max_global_voices` | int | 16–64 | Default 32 |
| Band | `band` | int | 0–5 | Rule 8 |

**Output Range:** play / steal(voice) / drop.
**Example:** BULLET pool full (8): 4 enemy fire (P4), 2 player shot (P4), 1 Warp (P2), 1 cancel (P1). A new cancel (P1) arrives: the victim is the oldest P4 voice (P4 > P1) → stolen. A new enemy volley (P4) arrives: victim is the oldest P4 (P4 > P4 is false) → dropped. A boss volley (P4) arrives: allowed to steal the oldest enemy-fire voice.

**F4. Pitch scale**

`pitch_scale = 2 ^ (semitones / 12)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Semitones | `semitones` | float | −12…+12 | Slot step + gem step, or the milestone step |

**Output Range:** 0.5–2.0.
**Example:** P2 (+2): 1.1225. P3 (−2): 0.8909. P4 (+4): 1.2599. Milestones 50 / 100 / 200 at +0 / +4 / +7: 1.0000 / 1.2599 / 1.4983.

**F5. Stereo pan**

`pan = clamp((x − 180) / 180, −1, 1) × width` ; `pan = 0` if `audio.mono`. Width 0.6 for player sounds, 0.35 for world sounds.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| World x | `x` | px | 0–360 | Source x on the 360-wide canvas |
| Width | `width` | float | 0–1 | Rule 13 |

**Output Range:** −0.6…+0.6.
**Example:** a player plane at x = 300: (300 − 180)/180 = 0.667 × 0.6 = **+0.40**. An enemy at x = 60: −0.667 × 0.35 = **−0.23**.

**F6. Co-op trim**

`trim_db = coop_trim_per_player × (N − 1)`, with `coop_trim_per_player` = −1.5 dB, applied to `SFX_Player`.

**Output Range:** −4.5…0 dB. **Example:** N = 1 → 0 dB; N = 3 → −3.0 dB; N = 4 → −4.5 dB.

**F7. Duck envelope**

```
t < a            : duck_db = −D × t / a
a ≤ t < a + h    : duck_db = −D
a+h ≤ t < a+h+r  : duck_db = −D × (1 − (t − a − h) / r)
else             : 0
```
The bus duck is `min` (deepest) over all active ducks.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Depth | `D` | dB | 0–24 | Duck table |
| Attack / hold / release | `a`, `h`, `r` | ms | 0–3000 | Duck table |
| Elapsed | `t` | ms | ≥ 0 | Since trigger |

**Output Range:** −D…0 dB.
**Example:** `cb_stab` (D 12, a 50, h 1500, r 600): t = 25 ms → −6.0 dB; t = 1000 → −12.0; t = 1850 (halfway through release) → −6.0; t = 2150 → 0. If `death_dip` (−6) is also active at t = 1000, the music duck is −12 (deepest), not −18.

**F8. Tail-aligned sample start (lock tone and flak fuse)**

Both samples are authored 60 ticks (1.0 s) long, with the climax at the end. For a tell of `T` ticks:

`start_offset_s = max(0, 60 − T) / 60` and `start_delay_ticks = max(0, T − 60)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Tell length | `T` | int ticks | 18–60 for locks (Pattern library) | `lock_ticks` or the fuse `ticks` |

**Output Range:** offset 0–0.7 s. The sound always ends on the click or pop in time with the burst.
**Example:** `lock_ticks` = 30 → start 0.5 s into the sample, no delay. `T` = 72 (a long fuse) → offset 0, delay 12 ticks.

**F9. Gem pickup pitch**

`step = min(8, gems_in_window − 1)` where `gems_in_window` counts this slot's gems collected in the last 12 ticks including this one; `semitones = step`. At most one gem sound per 3 ticks globally (F2).

**Output Range:** 0–8 semitones (pitch 1.0000–1.5874).
**Example:** 6th gem within 12 ticks → step 5 → 2^(5/12) = **1.3348**. 12th gem → step capped at 8 → 1.5874.

**F10. Music crossfade (equal power)**

`out = cos(u × π/2)` ; `in = sin(u × π/2)` ; `u = clamp(t / T, 0, 1)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Fade time | `T` | ms | 150–1500 | Transition table |
| Elapsed | `t` | ms | ≥ 0 | Since start |

**Output Range:** 0–1 linear gain on each track.
**Example:** T = 800, t = 200 → u = 0.25 → out 0.9239 (−0.69 dB), in 0.3827 (−8.34 dB). At t = 400 both are 0.7071 (−3.01 dB), so the sum stays level.

## Edge Cases

- **If two players die on the same tick**, two death booms play (CRIT cap holds 2), one clear thud plays (1 per tick), and `clear_hush` and `death_dip` start once.
- **If a third death boom is requested while two are active**, it replaces the oldest P0 voice (F3), never dropped.
- **If the CRIT pool (4) is full of two death booms, a CB sting and an earlier extend jingle when a new extend jingle arrives**, the new jingle replaces the oldest P0 voice in CRIT (whichever started first); nothing is dropped.
- **If a Critical Break lands on the tick of a death**, both play; `cb_stab` (12 dB) is the music duck and `death_dip` (6 dB) is absorbed (deepest wins).
- **If `extend_awarded` fires with `gained = 0`** (overflow), no jingle plays; the MEDAL pickup sound plays instead (Powerups Rule 22).
- **If a 1UP is picked up**, only the extend jingle plays (from `extend_awarded`); the pickup itself is silent.
- **If 4 volleys with the same sound ID start in one tick**, only the first plays (default gate), and it counts one voice.
- **If a volley spawns zero bullets** (Pattern library edge case), no `volley_fired` arrives, so nothing plays. If a volley falls in `death_fire_hold`, it is silent too.
- **If 100 gems are picked up in one second**, at most 20 gem sounds play (1 per 3 ticks) and the step caps at 8; the BULLET pool is never starved because gems are P4.
- **If a boss volley arrives and all 4 enemy-fire voices are busy**, the oldest enemy-fire voice is stopped and the boss volley takes it. Any other enemy volley is dropped.
- **If more than 2 locks are active**, only the first 2 get a tone; the others are silent (their visual tell remains).
- **If a laser loop is requested while 2 loops are already playing**, the new one is muted (no voice used) but still tracked; if an older loop ends, the muted one does not retro-start.
- **If a sound is requested while the policy is paused** (game paused), it is dropped; UI-bus sounds are the only requests accepted during pause.
- **If a track file is missing**, the state plays silence, logs the id once and the run continues.
- **If an era variant is missing** (for example `_2030s` before it exists), the `_1941` variant plays and one warning is logged per ID per run.
- **If the first Web input arrives mid-`TITLE`**, the title track starts then; it is never played "silently" in the background.
- **If `audio.master` is 0 or all three sliders are 0**, all buses are muted, the policy still runs (so tests and determinism are unchanged), and no player node plays.
- **If `audio.sfx` is 0 but `audio.music` is above 0**, the `UI` bus is muted too (it follows the SFX step); music plays, and the Warning siren is silent (the HUD banner remains).
- **If `warning_started` arrives with `duration_ticks` below 120**, the siren plays for 120 ticks.
- **If `boss_started` never arrives after `warning_started`** (Wave director fault), the stage track stays ducked for at most 600 ticks, then the duck is lifted and a warning is logged.
- **If `stage_cleared` arrives before `boss_gone`**, the tally track waits for `boss_gone`; after 180 ticks it starts anyway.
- **If the game is paused during a music fade**, the fade is paused with the pause overlay and continues on resume.
- **If the window loses focus** (PC) the OS audio keeps running; no special handling. On Web, a suspended context after tab hide resumes on the next input (unverified).
- **If a continue is accepted during the `GAMEOVER` fade-out**, the fade is finished at once (150 ms rule) and the stage track starts from its intro.
- **If `coop_count_changed` raises N mid-stage**, the trim and pitch rules take effect from the next sound; sounds already playing are not re-pitched.
- **If the same sound ID is routed to two buses by an era skin**, the skin may change only the stream, never the bus, band or limit (AC-13).

> Decided under auto-approve (2026-11-03): global cap 32; burst cap 6; P0 may replace the oldest P0; stealing only by strictly lower importance; solo plays at pitch offset 0; the dB-deepest-wins duck rule; the 150 ms fade-cut rule; missing era variant falls back to 1941.

## Dependencies

**Upstream (Audio listens to; no hard dependency in either direction):**

| System | Hard/Soft | Interface | GDD |
|---|---|---|---|
| Game events and session (1) | Hard | Event bus and run-flow state. Without it Audio has nothing to play. | Yes |
| Save, settings, high scores (26) | Soft | `audio.master`, `audio.music`, `audio.sfx`, `audio.mono`; defaults 10 / 7 / 8 / false | Yes |
| Input and player mapping (2) | Soft | UI triggers, join, pad lost | Yes |
| Player plane (5) | Soft | Dying, FlyIn, drone events | Yes |
| Collision, damage, lives (6) | Soft | `player_died`, clear, hit results | Yes |
| Chain tracker (7) | Soft | `chain_milestone`, `chain_dropped`, `red` window | Yes |
| Scoring (8) | Soft | Cap-hold, `extend_awarded` | Yes |
| Bullet manager (3) | Soft | Cancel and Warp cues, counters | Yes |
| Bullet pattern library (9) | Soft | `volley_fired`, lock, flak events | Yes |
| Enemy and AI (10) | Soft | `enemy_*` events | Yes |
| Plane kits (11), Bombs (12) | Soft | Kit and bomb events | Yes |
| Powerups and drops (13) | Soft | Pickup events | Yes |
| Boss and boss parts (14), Boss power budget (15) | Soft | `boss_*` events | Yes |
| Critical Break (17) | Soft (Critical Break lists Audio as Hard for the sting) | `critical_break_*`, `cb_state` | Yes |
| Co-op and team chain (18) | Soft | `team_cue_*`, `coop_count_changed` | Yes |
| Wave and stage director (16) | Soft | `warning_started` and boss timing | Yes ([Director](wave-and-stage-director.md)) |
| Stage-end tally (21), Menus (22), HUD (20) | Soft | Tally and menu sound triggers | Yes ([Tally](stage-end-tally.md), [Menus](menus-title-plane-select.md), [HUD](hud.md)) |
| Era shift (19) | Soft | `era_swap_committed`, `era_ready` for the music/sfx bank swap (`EraDef` bank) | Yes ([Era shift](era-shift-and-plane-evolution.md)) |
| Localization (27) | None | No spoken audio | Yes |
| Tutorial (30) | Soft | `sfx_tut_drill_done` and `sfx_tut_coach_open` (Tutorial Visual/Audio) play on the UI bus (IDs assigned 2026-11-03, consistency check; audio-director to confirm) | Yes ([Tutorial](tutorial.md)) |
| Touch controls (31) | None | Touch adds no sound; haptics are owned by Touch controls Rule 32. A touch button press sounds only through the system it triggers (bomb, drone, pause) (2026-11-03, wave 4) | Yes ([Touch controls](touch-controls.md)) |
| Plane kits Sentry/Breaker (29), Online leaderboards and Boss Rush (32) | Soft | Kit, bomb and menu events as listed in their Visual/Audio sections; IDs in the Sound Event List (`sfx_kit_sentry_plant` … `sfx_kit_stock_ready`, `sfx_bomb_bastion_loop`, `sfx_bomb_backlash_sweep`, `sfx_ui_upload_*`, `sfx_rush_refit`; assigned 2026-11-03, consistency check; audio-director to confirm) | Yes ([Sentry/Breaker](plane-kits-sentry-breaker.md), [Online/Boss Rush](online-leaderboards-boss-rush.md)) |

**Downstream (systems that depend on Audio):**

| System | Hard/Soft | Interface | GDD |
|---|---|---|---|
| Accessibility (28) | Soft | `audio.mono` (registered by Accessibility, stored by Save); `access.chain_cue_audio`; visual-twin lint; no caption option (Accessibility Rule 30) | Yes ([Accessibility](accessibility-options.md)) |
| VFX (25), HUD (20) | Soft | Must show the visual twin of each critical cue (Visual/Audio table) | Yes ([VFX](vfx-and-screen-feedback.md), [HUD](hud.md)) |
| Menus (22), Tally (21) | Soft | Audio settings screen; tally row, hero and NEW BEST triggers | Yes |
| Critical Break (17) | Hard | Owns the sting asset and the `cb_stab` curve | Yes |

**Amendments to other docs** (to be applied by the main session):

1. `design/gdd/systems-index.md` row 24: status `**Designed** (pending review) — [GDD](audio.md)`; Depends-on column `1; listens to 2, 3, 5–18, 26 (soft)`; Progress tracker GDD count +1.
2. `design/gdd/save-settings-high-scores.md`: add schema row `audio.mono | bool | false | — | Audio (24) / Accessibility (28)`; mark F6 "adopted by Audio 24 F1"; note the `UI` bus follows `audio.sfx`.
3. `design/gdd/game-events-and-session.md` Rule 13: add provisional signals `warning_started(duration_ticks)`, `run_state_changed(state)`, `pause_changed(paused)`, `tally_started`, `tally_row_revealed(index)`, `tally_hero_landed`; list Audio (24) as a listener.
4. `design/gdd/localization.md`: close Open Question 12 (no voice lines at MVP; reserved `Voice` bus rule in Audio Rule 1).
5. `design/gdd/boss-and-boss-parts.md` A1 "Intro": the Warning siren asset is owned by Audio (`sfx_ui_warning_siren_loop`); the Wave director or HUD only sends `warning_started`.
6. `design/gdd/player-plane.md` A1: the plane pool of 3 voices excludes the death boom (the death boom is in CRIT, max 2); the voice cap line is updated accordingly.
7. `design/gdd/scoring.md` Visual/Audio: `extend_awarded` sound = `sfx_score_extend_jingle`; cap-hold chime is on by default.
8. `design/gdd/powerups-and-drops.md` V6: the 1UP pickup is silent; the jingle comes from `extend_awarded`.
9. `design/gdd/critical-break.md` V6 / Rule 28: sting id `sfx_cb_sting`; music duck is `cb_stab` (12 dB, 50 / 1500 / 600 ms); the `boss_defeated(CRITICAL_BREAK)` music rule is in Audio States.
10. Open Question rows to close with this GDD: Bullet manager OQ 10, Collision OQ 7, Plane kits OQ 11, Bombs OQ 14, Chain OQ 5 (milestone pitch and rumble: pitches closed here, rumble is Input / Accessibility).
11. `.claude/docs/technical-preferences.md` Performance Budgets: add `Audio: ≤ 16 MB shipped (MVP), 32 voices, policy ≤ 0.1 ms p99 per frame on REF-WEB`.
12. HUD (20), Tally (21), Menus (22), VFX (25), Accessibility (28) GDDs (when written) must list Audio (24); Wave director (16) must emit `warning_started`.
13. `design/art/art-bible.md` §2 State Mood Table: add a one-line note that Audio uses the same state table (Visual/Audio section here).

## Tuning Knobs

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `bus_base_music_db` | −4 | −10…0 | Music inaudible under SFX | Masks SFX | F1, ducks |
| `bus_base_player_db` / `bus_base_enemy_db` | −4 / −6 | −10…0 | Cues lost | Fire sounds crowd critical cues | Rule 8 bands |
| `max_global_voices` | 32 | 16–64 | Important sounds stolen | Web CPU cost | Rule 7 |
| Pool caps (Rule 7) | per table | ±2 each | Cues missing in busy scenes | Masking and CPU | Source GDD caps |
| `retrigger_default_n` / `_w` | 1 / 3 ticks | W 2–6 | Machine-gun buzz from stacked volleys | Fast volleys sound sparse | Bullet manager A1 |
| `max_new_voices_per_tick` | 6 | 3–10 | Bombs and bursts sound thin | Burst spike on Web | F3 |
| `coop_trim_per_player` | −1.5 dB | −3…0 | 4P mix too quiet | 4P clips or masks | F6, `SFX_Player` |
| Slot pitch steps | 0 / +2 / −2 / +4 | ±5 semitones | Players sound the same | Dissonant | F4; Pitch below −5 sounds muddy |
| `pan_width_player` / `_world` | 0.6 / 0.35 | 0–1 | Little separation | Hard-panned shots tire the ear | F5, mono option |
| Duck depths and times (Rule 14) | per table | depth 3–18 dB | Big moments not felt | Music pumps | F7 |
| Crossfade times (States) | 150–1500 ms | see table | Abrupt | Slow transitions blur state change | F10 |
| `warning_min_ticks` | 120 | 60–300 | Siren too short to read | Delays the boss | Wave director |
| `lock_tone_max_audible` | 2 | 1–4 | Locks not heard in 4P | Tone clutter | Pattern library |
| `window_tick_enabled`, `cap_hold_chime_enabled` | true / true | bool | — | — | Chain, Scoring (optional cues from their GDDs) |
| Loudness target | −16 LUFS-I ±2 | −20…−12 | Quiet on phones | Fatigue | Asset spec |
| Music budget / SFX budget | 12 MB / 4 MB | — | — | Web download time | Asset spec |

**Owned elsewhere:** `audio.master/music/sfx` defaults (Save 26); `team_cue_min_gap` 120 and `team_end_cue_min_run` 180 (Co-op 18); retrigger rule ≥ 3 ticks and the 8-voice bullet pool (Bullet manager 3); enemy fire ≤ 4 voices (Bullet manager 3); pickup limits (Powerups 13); chain milestones [50, 100, 200] (Chain tracker 7); lock and fuse length (Pattern library 9); Warning duration (Wave director 16). Rationale for all values here: mix balance is set so the loudest long sound (music) sits 4 dB under SFX peaks, and so critical cues are 6 dB hotter than fire sounds; all values are playtest-tunable and nothing in gameplay depends on them.

## Visual/Audio Requirements

**Sonic identity.** The game is a Bengali game told through a century of aviation. Palette: acoustic and brassy at the start, drifting to synthetic, then warped. Mood follows the art bible State Mood Table and the era arc: pastoral, industrial, synthetic, unreal.

**Signature motif (proposal).** One four-note melodic motif (a Bengali-flavoured phrase, e.g. built on a *bansuri* line) opens the title and returns in every stage track re-voiced per era. Boss tracks use *dhak*-style percussion patterns on top of the era kit. A Bengali musician should write or review the motif (OQ 1).

| State / era | Genre and instruments | BPM, loop | Feel |
|---|---|---|---|
| Title | Gilded, heroic: bansuri motif, brass band, timpani, swelling strings | 100 BPM, 32 bars (about 77 s) | Proud nostalgic anticipation, medium and building |
| Plane select | Intimate hangar: soft piano, upright bass, brushed snare, motif on solo flute | 96 BPM, 16 bars (about 40 s) | Confident choice, low-medium |
| Stage 1: 1941 | Brisk military march with swing: cornets and trumpets, tuba bass, snare rolls, bright piano, motif on cornet | 112 BPM, 48 bars (about 103 s), 2-bar intro | Plucky, open-air, the lightest tempo (teaching pace) |
| Stage 2: 1970s | Cold War spy-funk: electric piano, Hammond organ, wah guitar, tight funk drums, radar pings, motif on organ | 124 BPM, 56 bars (about 108 s), 2-bar intro | Tense, cool-headed |
| Stage 3: 2030s *(Target)* | Dark synthwave / techno: sidechained pulses, arpeggiated sequencer, cold pads, motif on lead synth | 138 BPM | Cold, clinical, surveilled |
| Stage 4: 2100+ *(Target)* | Reversed, warped, granular: earlier eras' motifs played backwards, bent tape, unstable time feel | 90, shifting | Dreamlike vertigo |
| Boss (each era) | Same key and same BPM as its stage, half-time or double-time feel, heavier percussion (dhak), darker voicing; 1941: 40 bars (about 86 s); 1970s: 48 bars (about 93 s) | = stage | Dread to focus |
| Tally | Warm, slow: 8 s jingle intro (brass or strings swell), then calm loop of piano and soft pads | 80 BPM, 16 bars (about 48 s) loop | Satisfied reflection |
| Game over / continue | Single sting (about 5 s), then a very sparse low drone with a slow heartbeat-free pulse | 60 BPM, 8 bars (about 32 s) | Sober regret; must not slow the retry |
| Ending | One-shot, 40 s, the motif resolved in full band | 100 | Triumphant, then fade to title |

**Rule:** a boss track must be in the same key as its stage track so crossfades and stage-to-boss changes stay consonant.

**SFX timbre per era:**

| Era | Timbre | Examples |
|---|---|---|
| 1941 | Mechanical, brassy: clanks, bolt actions, cranked servos, horn stabs | Fan "pew" = short bolt-action bark; ring thump = a drum hit |
| 1970s | Radar and analogue: sonar pings, filtered noise sweeps, relay clicks | Fan "pew" = square-wave blip; wall sweep = filter sweep |
| 2030s (Target) | Clean digital synth: FM bell, glitch ticks, sub drops | |
| 2100+ (Target) | Reversed or warped: reversed tails, pitch-bent hits | |

Constant across eras: cue timing, limits, band, meaning, and the **Critical-band (P0) sounds are era-constant** so players learn them once. Era skins change only the audio stream, never bus, band, pool or limit.

**Visual twins of critical sounds** (Audio is never the only cue; Accessibility 28 and VFX / HUD own the visuals):

| Sound | Visual twin |
|---|---|
| Own death boom, clear thud | Death ring (Collision V4), screen clear puffs |
| CB sting | White flash (or particle burst with Reduce flashing), banner |
| Warning siren | Warning banner (art bible §7.4) |
| Extend / 1UP jingle | HUD lives icon update |
| Lock tone / click | Lock line and reticle (Pattern library V) |
| Flak fuse / pop | Fuse blink and burst puff |
| Warp cue | The 0.4 s freeze (the audio is the backup) |
| Armour clank / immune ping | VFX `fx_clank` / `fx_ping`, tier T1 so MINIMAL keeps them (Accessibility 28 Rule 30) |
| Chain milestone | Plate edge step and sparkles |
| Pad lost | Disconnect overlay |
| Team link | Gold bracket and "TEAM" tag |

**Asset specification (hook for `/asset-spec`).**

| Category | Prefix | Format | Rate and bit depth | Channels | Loudness / peak | Budget |
|---|---|---|---|---|---|---|
| Music | `mus_` | Ogg Vorbis, quality 4 (about 128 kbps) | 44.1 kHz | Stereo | −18 LUFS-I, ≤ −1.5 dBTP | ≤ 12 MB total at MVP (about 10 MB planned) |
| SFX one-shot | `sfx_` | WAV PCM 16-bit | 44.1 kHz | Mono (stereo only for the CB sting and boss death) | Peak by class: Crit −3, Player −6, Enemy −10, UI −8, Pickup −9 dBFS | ≤ 4 MB total; each < 2 s except stings |
| SFX loop | `sfx_*_loop` | WAV PCM 16-bit with loop points | 44.1 kHz | Mono | −8 dBFS peak | 1–2 s each |
| Ambience | `amb_` | none at MVP | — | — | — | — |

Naming: `[category]_[context]_[name]_[variant].[ext]`, variant = number or era, e.g. `sfx_enemy_fan_pew_1941.wav`, `sfx_cb_sting_01.wav`, `mus_stage_1970s_loop.ogg`, `mus_boss_1941_loop.ogg`. Folders: `assets/audio/music/`, `assets/audio/sfx/`. Data: `data/audio/sound_events.tres` (id, bus, band, pool, N, W, scope, era flag), `data/audio/mix.tres` (bus offsets, ducks, caps), `data/audio/music_cues.tres` (track, bpm, bars, intro bars, loop start, key). Total MVP count about 75 sound stems (about 45 with a 1941 + 1970s variant, so about 120 files) plus 9 music files. If WAV exceeds 4 MB, switch long SFX to the engine's compressed WAV mode (QOA; unverified for 4.7). Ogg loops use the stream's loop offset to skip the intro. Mix rate: 44.1 kHz (project default; confirm).

**Latency.** Events requested in tick `T` start in the same frame the tick ends. Total latency = under one frame (16.7 ms) + the platform output latency (desktop about 15 ms default; Web 50–100 ms, unverified).

**Sourcing plan (proposal).**
- **Music:** original, commissioned. One composer (preferably Bengali) for the motif, title, 1941 and 1970s tracks; later eras are Target. Work-for-hire with full buyout for all platforms; stems delivered (drums, bass, harmony, melody) for later vertical layers.
- **SFX:** originals made with synths and a field recorder first; CC0 libraries (Kenney, OpenGameArt CC0, Freesound CC0) as a base; generated placeholders (jsfxr-style) are allowed during production but live in `assets/audio/placeholder/` and are listed for replacement.
- **Licence rules:** CC0 or paid commercial licence only. No CC-BY-NC. CC-BY only if credited in the in-game credits. No unlicensed or unknown-source audio, and **no AI-generated audio in shipped builds** until the user decides otherwise (OQ 2). Every file is logged in an audio licence ledger (source, licence, date, link) before it enters the build.

## UI Requirements

Audio has no HUD of its own. Needs from other screens:

| Screen | Need |
|---|---|
| Audio settings (Menus 22) | Three sliders (Master, Music, SFX) in integer steps 0–10, plus a Mono toggle. Moving Master or SFX plays `sfx_ui_slider_preview`; Music plays nothing (the current track is the preview). Default highlighted values 10 / 7 / 8. Labels come from Localization keys (Bengali and English). |
| Pause menu | Same sliders reachable; music is filtered while open. |
| Web title | A "Press any button" prompt that doubles as the audio unlock (Rule 16). |

📌 **UX Flag**: run /ux-design for the Audio settings screen before writing epics.

**Debug tools (dev builds only):** an overlay listing each pool's active/cap, the last 8 dropped or stolen requests with their reason, the active ducks and the music state; a bus mute/solo command; a `play(id)` command. The key to open it is assigned by Input (2) with the other debug keys (not F5–F9).

## Acceptance Criteria

**Defaults used:** `audio.master` 10, `audio.music` 7, `audio.sfx` 8, `audio.mono` false; default gate `N = 1, W = 3`; `max_global_voices` 32; `max_new_voices_per_tick` 6; pool caps per Rule 7; duck table per Rule 14.

**Test setup:** the policy (`AudioPolicy`) and the music state machine (`MusicStateMachine`) are node-free `RefCounted` classes with an integer tick input and no RNG, loaded from `data/audio/*.tres`. Tests live in `tests/unit/test_audio_policy.gd`, `test_audio_pools.gd`, `test_audio_mix.gd` and `test_audio_music_state.gd`, written in the `extends SceneTree` style of `tests/unit/test_chain_tracker.gd`, and read all numbers from the `.tres` files. Event streams are fed as arrays of `(tick, event, args)`; outputs are arrays of `(tick, id, voice, action)`. Manual criteria are captured in `production/qa/evidence/audio/`.

### Buses and levels
- **AC-01 [Unit] (Rule 1):** the bus layout built from `mix.tres` has exactly Master, Music, SFX, SFX_Crit, SFX_Player, SFX_Enemy, UI with the stated parents and base offsets.
- **AC-02 [Unit] (F1):** step 7 → −3.10 dB (±0.01), step 5 → −6.02 dB, step 10 → 0 dB, step 0 → mute. Music bus at defaults = −7.10 dB; `SFX_Enemy` at defaults = −7.94 dB.
- **AC-03 [Integration] (Rule 2):** `setting_changed("audio.music", 3)` changes the Music bus gain on the next frame to `−4 + linear_to_db(0.3)` = −4 − 10.46 = −14.46 dB; no restart needed.
- **AC-04 [Unit] (edge):** `audio.sfx` = 0 mutes SFX, SFX_* and UI buses; Music is unchanged.
- **AC-05 [Integration] (Rule 3):** with `audio.mono` true, every computed pan is 0 and a stereo test tone measures identical left and right on Master.
- **AC-06 [Manual] (Rule 4):** a 60 s default-settings capture of stage 1 measures −16 LUFS ±2, true peak ≤ −1.0 dBTP; each music file measures −18 LUFS ±1 and ≤ −1.5 dBTP.

### Rate gate, pools and priority
- **AC-07 [Unit] (F2):** default gate: play at tick 100; request at 102 refused; request at 103 allowed.
- **AC-08 [Unit] (F2):** clank gate (10 per 60 ticks): the 11th request within 60 ticks is refused, the 11th at tick+60 is allowed.
- **AC-09 [Unit] (Rule 6):** 4 `volley_fired` events with the same sound ID on one tick produce exactly 1 play.
- **AC-10 [Unit] (Rule 7):** with every pool at its cap, the table caps equal Rule 7 values and `max_global_voices` = 32.
- **AC-11 [Unit] (F3):** BULLET pool example in F3: new cancel steals the oldest P4; a new enemy volley is dropped; a boss volley steals the oldest enemy-fire voice.
- **AC-12 [Unit] (Rule 9):** a P0 sound is never the victim of a steal by a P1–P5 sound (fuzzed 1000 requests, 0 P0 stolen).
- **AC-13 [Unit] (Rule 9, edge):** a third death boom replaces the oldest P0 voice in CRIT; an era skin that changes bus, band or limit fails data validation.
- **AC-14 [Unit] (Rule 10):** 12 non-P0 requests on one tick start 6 voices; a P0 request on the same tick still plays.
- **AC-15 [Unit] (Rule 8):** with 2000-bullet-scene event load (40 requests per tick for 600 ticks, mixed bands), no pool exceeds its cap, no P0 request is dropped except by the rate gate, and global active voices never exceed 32.
- **AC-16 [Unit] (Rule 11):** SMALL pop variants cycle 1, 2, 3, 1 over four plays; a refused request does not advance the counter.

### Co-op identity and pitch
- **AC-17 [Unit] (F4, Rule 13):** with N = 4, slot pitch scales are 1.0000, 1.1225, 0.8909, 1.2599. With N = 1, a P3 sound uses pitch 1.0000.
- **AC-18 [Unit] (F5):** x = 300 player sound → +0.40; x = 60 world sound → −0.23; x = 180 → 0; `audio.mono` → 0.
- **AC-19 [Unit] (F6):** `SFX_Player` trim is 0 / −1.5 / −3.0 / −4.5 dB for N = 1 / 2 / 3 / 4.
- **AC-20 [Unit] (F4):** milestones 50 / 100 / 200 play at pitch 1.0000 / 1.2599 / 1.4983; two milestones for different slots on one tick both play; two for the same slot on one tick play once.
- **AC-21 [Unit] (F9):** the 6th gem within 12 ticks has pitch 1.3348; the 12th has 1.5874; gem sounds are at least 3 ticks apart.

### Ducking and pause
- **AC-22 [Unit] (F7):** `cb_stab` at t = 25 / 1000 / 1850 / 2150 ms gives −6.0 / −12.0 / −6.0 / 0 dB.
- **AC-23 [Unit] (Rule 14):** `cb_stab` (−12) and `death_dip` (−6) active together give −12 dB on Music, not −18.
- **AC-24 [Unit] (Rule 14):** a screen clear ducks `SFX_Player` and `SFX_Enemy` by 6 dB for 300 ms hold and never ducks `SFX_Crit`.
- **AC-25 [Unit] (Rule 14):** 4 simultaneous deaths → 1 clear thud, 1 `clear_hush`, 4 death boom requests with 2 playing at once and 2 replacing older P0 voices (CRIT cap holds).
- **AC-26 [Integration] (Rule 15):** on pause, Music is −6 dB and low-passed, gameplay SFX buses are muted; on resume Music returns within 200 ms.

### Event-to-sound
- **AC-27 [Unit] (Collision A1):** armour clank ≤ 10 per second globally, ≤ 1 per 6 ticks per target; immune ping ≤ 1 per 12 ticks per target.
- **AC-28 [Unit] (Enemy A1):** 6 SMALL kills in 10 ticks → ≤ 4 pops (1 per 3 ticks); a LARGE boom plays over three SMALL pops.
- **AC-29 [Unit] (Co-op A1):** `team_cue_start` events 100 ticks apart → 1 sound; 130 ticks apart → 2. `team_cue_end` after a 150-tick run is silent; after 200 ticks plays.
- **AC-30 [Unit] (F8):** `lock_ticks` 30 → sample start offset 0.5 s; fuse 72 → offset 0, delay 12 ticks; not-fired lock → no click.
- **AC-31 [Unit] (BM A2):** 3 cancel requests on one tick (small, large, small) → one sound, the first requested.
- **AC-32 [Unit] (Powerups):** 100 gems in 60 ticks → ≤ 20 gem sounds; BULLET pool never holds more than 8.
- **AC-33 [Unit] (Rule 5, 1UP):** `extend_awarded(gained = 1)` → jingle once; `gained = 0` → no jingle; the 1UP pickup itself plays no sound.
- **AC-34 [Unit] (Kits A1):** 3 simultaneous Lancer lasers → 2 loop voices play, the third is muted.
- **AC-35 [Unit] (Plane kits, Bombs):** invulnerability end, `bomb_denied(BUSY)`, Focus toggle, `item_expired` and chain hit (+1) produce zero sound requests.
- **AC-36 [Integration] (CB):** `critical_break_landed` → sting (1.0–1.5 s) starts on the tick, music ducks by 12 dB, and the clear jingle waits for `boss_gone`.

### Determinism
- **AC-37 [Unit] (Rule 11, Overview):** two runs of the same recorded 10-minute event stream produce byte-identical decision logs; the policy code has no `randf`, `randi` or `delta` (lint).
- **AC-38 [Integration] (Rule 17):** with the audio adapter replaced by a null stub, a seeded 2-stage headless run gives the same final score, chain and tick count as with audio enabled.

### Music states
- **AC-39 [Unit] (States):** the transition table: `SELECT → STAGE` fades out 600 ms and in 500 ms; `STAGE → WARNING` starts `warning_dip` (−12 dB over 600 ms) and the siren; `WARNING → BOSS` stage track fades out over 1000 ms from `boss_intro_started`, boss track fades in over 300 ms at `boss_started`.
- **AC-40 [Unit] (F10):** T = 800 ms, t = 200 → out 0.9239, in 0.3827; t = 400 → both 0.7071.
- **AC-41 [Unit] (States):** a new state requested mid-fade cuts the old fade to 150 ms; the same track requested twice does not restart.
- **AC-42 [Unit] (Edge):** `stage_cleared` before `boss_gone` → tally music waits; after 180 ticks it starts anyway.
- **AC-43 [Unit] (Edge):** `warning_started(duration_ticks = 60)` → siren plays 120 ticks; no `boss_started` for 600 ticks after warning → duck lifted and one warning logged.
- **AC-44 [Integration] (Edge):** a missing track plays silence, logs once, and the run continues; a missing `_2030s` variant plays `_1941` and logs once per ID.
- **AC-45 [Manual] (Music):** stage 1, boss 1, stage 2, boss 2, tally, game over, ending and title tracks each loop without a click or gap across the loop point (listening test, two reviewers).
- **AC-46 [Manual] (Rule: key):** each boss track is in the same key as its stage track (composer's key sheet checked).

### Web and platform
- **AC-47 [Manual] (Rule 16):** on a Web build in Chrome and Firefox, the title music starts on the first input and not before; no console audio-context error loops. Record the Godot 4.7 playback type chosen and whether ducking and the limiter work.
- **AC-48 [Manual] (Rule 16):** on the Web build, a Critical Break duck and a pause low-pass are audible (proof that Stream playback type applies bus effects).

### Mix and readability
- **AC-49 [Manual] (Readable Chaos):** 4P co-op, 1500+ bullets, all abilities firing: own death boom, CB sting, Warning siren and 1UP jingle are clearly audible in every take (blind test: 5 listeners identify each within 1 s).
- **AC-50 [Manual] (Accessibility):** with the sound off, a tester can still tell every event in the Visual-twin table, armour clank and ping included (`fx_clank`, `fx_ping`).
- **AC-51 [Manual] (Era):** blind A/B between the 1941 and 1970s fan "pew": 5 of 5 listeners say which is which; the same listeners say both mean "a spread of bullets".

### Performance
- **AC-52 [Perf] (Rule 18):** policy processing ≤ 0.1 ms p99 per frame on REF-WEB for 40 requests per tick; zero allocations in the tick (measured with the engine's memory monitor over 3000 ticks).
- **AC-53 [Perf] (budget):** shipped audio ≤ 16 MB at MVP (music ≤ 12 MB, SFX ≤ 4 MB); peak simultaneous SFX voices ≤ 32; audio mixing adds ≤ 1.0 ms per frame on REF-WEB in the 4P benchmark scene.
- **AC-54 [Perf] (Rule 18):** no `load()` or node creation during a stage (checked by instrumented adapter).

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Who composes the music and the Bengali motif? Is a Bengali composer or musician available for commission, and what is the music budget? | User / creative-director | Before the music spec |
| 2 | Is AI-generated audio allowed in shipped builds? Default here: no. | User | Before sourcing |
| 3 | How is the mono option implemented on Master in Godot 4.7 (bus effect vs per-player pan only)? Needs a spike. | audio-director / godot-specialist | Before Accessibility GDD |
| 4 | Web audio: which playback type (Stream or Sample) in Godot 4.7, does ducking / limiter / low-pass work, and when does the browser unlock audio? | godot-specialist | First Web build; ADR |
| 5 | ~~Armour clank / immune ping are sound-only cues that a hit did not count normally. What visual twin does Accessibility give them?~~ **Closed 2026-11-03:** VFX `fx_clank` / `fx_ping`, promoted to T1 (Accessibility 28 Rule 30) | Accessibility (28) / VFX (25) | Accessibility GDD |
| 6 | Audio architecture: autoload vs scene, pool node layout, and where the presentation step sits in the tick. | lead-programmer → ADR | Before implementation |
| 7 | Optional layered intensity (stems) for stages and a bar-quantised boss start. Not MVP; stems are requested in the commission. | audio-director | Target tier |
| 8 | ~~Warning siren length and exact event timing from the Wave director (Audio assumes `duration_ticks` ≥ 120).~~ **Closed 2026-11-03:** `warning_started(ticks)` with `warning_ticks` 150, starting at wave-5 end + 90 (Wave director 16) | Wave director (16) | Wave director GDD |
| 9 | ~~Rumble is not Audio. Who owns the setting and trigger table (Input OQ 10, CB OQ 8)?~~ **Closed 2026-11-03:** `access.rumble` OFF / LOW / NORMAL (Target) and `access.chain_cue_rumble` are Accessibility's; triggers stay with Input (Accessibility 28 Rule 29) | Input (2) / Accessibility (28) | Polish |
| 10 | ~~Should there be a sound caption (subtitle-style) option for deaf or hard-of-hearing players?~~ **Closed 2026-11-03:** no caption strip (no HUD space; art bible 7.7 forbids UI over the field); every P0/P1 sound has a visual twin instead (Accessibility 28 Rule 30) | Accessibility (28) | Accessibility GDD |
| 11 | ~~Does the Display scaler TATE confirm need its own sound (currently the standard confirm)?~~ **Closed 2026-11-03:** no new sound ID. The TATE confirm uses the standard UI sounds: `sfx_ui_nav_tick` as the countdown tick (once per countdown step: 10, 9, ...) and `sfx_ui_confirm` / `sfx_ui_cancel` for Keep / Cancel; the automatic revert plays `sfx_ui_cancel` (wave 4 decision; Display scaler Rule 17) | Display scaler (4) | Menus GDD |
| 12 | Final loudness target after real hardware tests (−16 LUFS; phones may want −14). | audio-director | Vertical slice |
| 13 | Engine-loop sound for planes (Player plane A1 says none). Kept off; revisit if the mix feels empty. | audio-director | Playtest |

> Decided under auto-approve (2026-11-03): bus layout and base levels; 32-voice global cap; priority bands; Bengali motif with dhak percussion; MVP eras 1941 and 1970s only; WAV for SFX and Ogg for music; −16 LUFS target; Stream playback type if the spike requires; chain window tick and cap-hold chime on by default; critical sounds era-constant; no AI audio; no ambience, voice or beat-sync at MVP.
