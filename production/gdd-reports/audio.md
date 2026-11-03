# GDD report: Audio (system 24)

## 1. File written
`design/gdd/audio.md` (Designed, pending review). It covers the basic MVP audio layer: music, SFX and mix. Audio is presentation only. It listens to events and never writes gameplay state. A node-free tick-based policy class decides every play, drop or steal through rate gates, voice pools and priority bands. It consolidates every audio proposal other GDDs left as "(P), audio-director to confirm". It defines a 7-bus layout, about 75 sound stems with an event table, a music state machine with crossfade times, ducking, co-op pitch and pan identity, loudness and asset specs, a sourcing plan, 10 formulas and 54 acceptance criteria.

## 2. Key decisions (user to review)
- Buses: Master > Music (−4 dB), SFX (parent of SFX_Crit 0, SFX_Player −4, SFX_Enemy −6), UI (−4, follows the `audio.sfx` slider). No Voice bus at MVP.
- Defaults come from Save (10 / 7 / 8). Final gains: Music −7.10 dB, SFX_Enemy −7.94 dB.
- New setting `audio.mono` (bool, default false).
- Priority bands P0–P5. P0 (own death, CB sting, extend/1UP jingle, Warning siren, clear thud) is never stolen and always era-constant. Enemy volleys and player shot ticks are P4. This matches the Bullet manager order (cancel > Warp > enemy fire > player fire).
- 12 voice pools with the caps the other GDDs proposed. All are confirmed: BULLET 8, HIT 4, EDEATH 4, KIT 8, BOMB 6, BOSS 4, PLANE 3, CRIT 4, and others. Global SFX cap is 32. Burst cap is 6 new voices per tick.
- Stealing happens only when the victim is strictly less important. A boss volley may steal the oldest enemy-fire voice. A P0 sound may replace the oldest P0 voice.
- Rate gate is `N per W ticks` per (id, scope). Default is 1 per 3 ticks (Bullet manager rule). The per-ID limits from every GDD are kept.
- Variants cycle round-robin. There is no RNG anywhere in Audio.
- Co-op identity applies only when N ≥ 2: slot pitch 0 / +2 / −2 / +4 semitones, pan by world x (width 0.6 for player sounds, 0.35 for world sounds), and SFX_Player trim of −1.5 dB per extra player.
- Ducks use a deepest-wins rule: clear_hush 6 dB / 300 ms, death_dip 6 dB, cb_stab 12 dB (50 / 1500 / 600 ms), extend_dip 4 dB, timeout_dip 12 dB. Pause low-passes the music at 800 Hz and mutes the SFX buses.
- Lock tone and flak fuse use tail-aligned samples (F8), so the climax always lands on the burst.
- Music: equal-power crossfades. Not beat-quantised at MVP. Each state is one track; stage and boss tracks share a key. BPM and bars are in cue data for later alignment.
- Era identity:
  - 1941 is a brass march with swing at 112 BPM.
  - 1970s is spy-funk with analogue synths at 124 BPM.
  - 2030s is dark synthwave and 2100 is reversed/warped. Both are Target tier.
  - A Bengali four-note motif (bansuri) recurs in every track. Boss tracks use dhak-style percussion. A Bengali musician should write or review it.
- Assets: music is Ogg Vorbis q4, stereo, −18 LUFS. SFX is WAV 16-bit mono at 44.1 kHz. Budget is 12 MB music and 4 MB SFX. Whole-mix target is −16 LUFS ±2 with true peak ≤ −1 dBTP.
- Web: Stream playback type is required if the spike shows ducks or the limiter are bypassed in Sample mode. The title music waits for the first input on Web. Both points are marked unverified.
- Sourcing: commissioned original music, CC0 or paid commercial SFX only, no AI-generated audio (open question), and a licence ledger.
- Chain window tick and cap-hold chime are ON by default.
- The 1UP pickup is silent. The jingle plays from `extend_awarded(gained > 0)`.

## 3. Amendments (main session applies)
1. `design/gdd/systems-index.md`, row 24: change the status to `**Designed** (pending review) — [GDD](audio.md)`. Set the Depends-on column to `1; listens to 2, 3, 5–18, 26 (soft)`. In the Progress tracker, add 1 to "GDDs written" and add "Audio" to the list.
2. `save-settings-high-scores.md`: add schema row `audio.mono | bool | false | — | Audio (24) / Accessibility (28)`. Change the F6 note from "provisional" to "adopted by Audio F1". Note that the UI bus follows `audio.sfx`.
3. `game-events-and-session.md`, Rule 13: add provisional signals `warning_started(duration_ticks)`, `run_state_changed(state)`, `pause_changed(paused)`, `tally_started`, `tally_row_revealed(index)` and `tally_hero_landed`. List Audio (24) as a listener.
4. `localization.md`: close Open Question 12. There are no voice lines at MVP. A future Voice bus needs a language-audio rule.
5. `boss-and-boss-parts.md`, A1 Intro: change the Warning siren owner from "HUD / Wave director" to "Audio owns the asset `sfx_ui_warning_siren_loop`; Wave director or HUD only emits `warning_started`".
6. `player-plane.md`, A1: the voice cap line "plane SFX (death, FlyIn, drone pop) ≤ 3 voices total, ≤ 1 per slot" becomes "PLANE pool 3 for FlyIn and drone pops. The death boom is in the CRIT pool (max 2)".
7. `scoring.md`, Visual/Audio: `extend_awarded` sound = `sfx_score_extend_jingle`. The cap-hold chime is on by default.
8. `powerups-and-drops.md`, V6: the 1UP pickup itself is silent. The jingle comes from `extend_awarded`.
9. `critical-break.md`, V6 and Rule 28: sting id `sfx_cb_sting`. The music duck is `cb_stab` (12 dB; 50 / 1500 / 600 ms). Boss music fades out after the duck releases.
10. Close these Open Questions with a pointer to audio.md: Bullet manager 10, Collision 7, Plane kits 11, Bombs 14, Chain 5 (pitches closed; rumble stays with Input or Accessibility).
11. `.claude/docs/technical-preferences.md`, Performance Budgets: add "Audio ≤ 16 MB shipped at MVP; 32 SFX voices; policy ≤ 0.1 ms p99 per frame on REF-WEB".
12. The HUD (20), Tally (21), Menus (22), VFX (25) and Accessibility (28) GDDs must list Audio (24) when written. The Wave director (16) must emit `warning_started`.
13. `design/art/art-bible.md` §2: add a note that Audio follows the State Mood Table.

## 4. Registry candidates
```yaml
constants:
  - name: audio_retrigger_gap_ticks
    value: 3
    unit: ticks (50 ms) per sound ID
    source: design/gdd/bullet-manager.md (A1); design/gdd/audio.md (F2)
    referenced_by: [bullet-manager, bullet-pattern-library, audio]
  - name: bullet_sfx_voice_cap
    value: 8
    unit: voices
    source: design/gdd/bullet-manager.md (A2); design/gdd/audio.md (Rule 7)
    referenced_by: [bullet-manager, bombs, plane-kits-lancer-leech, powerups-and-drops, audio]
  - name: audio_max_global_voices
    value: 32
    unit: voices (SFX only)
    range: "16-64"
    source: design/gdd/audio.md
    referenced_by: [audio]
  - name: audio_target_lufs
    value: -16
    unit: LUFS integrated (60 s stage capture, defaults), true peak <= -1.0 dBTP
    source: design/gdd/audio.md
    referenced_by: [audio]
formulas:
  - name: audio_volume_gain
    expression: "step_db = linear_to_db(step / 10); step 0 = mute; bus_db = base_db + step_db + trim_db"
    variables: [step, base_db, trim_db]
    output: "-inf..0 dB"
    source: design/gdd/save-settings-high-scores.md (F6); design/gdd/audio.md (F1)
    referenced_by: [save-settings-high-scores, audio]
  - name: audio_rate_gate
    expression: "allowed = count(plays of (id, key) in ticks (t - W, t]) < N"
    variables: [t, W, N, key]
    output: bool
    source: design/gdd/audio.md (F2)
    referenced_by: [bullet-manager, audio]
```
Existing registry entries: none reference audio. `team_cue_min_gap` (120) and `team_end_cue_min_run` (180) are listed under Co-op, not in the registry. If they are added, `referenced_by` should gain `audio`.

## 5. Conflicts
- No conflict with locked registry values.
- Minor GDD reconciliation (not a hard conflict):
  - Player plane A1 put the death boom in a "plane pool ≤ 3". Audio puts it in the CRIT pool (max 2), which matches PP A1's own "reserved voice outside the bullet pool". Amendment 6.
  - Boss A1 assigns the Warning siren to the HUD or Wave director. Audio owns the asset. Amendment 5.
  - Kits cap laser loops at 2 globally and Bombs cap the Lancer hum at 2 globally. They sit in different pools (KIT and BOMB), so up to 4 hums can play. This is accepted, and the pool caps bound the total.

## 6. Open risks
- Godot 4.7 Web audio is unverified. The playback type (Stream vs Sample) may bypass ducking, the low-pass or the limiter. The unlock timing on the first input is also unverified. A spike is needed before the first Web build.
- The mono downmix method on Master is unknown (OQ 3).
- Armour clank and immune ping are sound-only cues. Accessibility 28 needs a visual twin for them.
- Wave director (16), HUD (20), Tally (21) and Menus (22) have no GDD. The signals Audio needs from them (`warning_started`, `run_state_changed`, tally events) are provisional.
- The sourcing plan assumes a commissioned composer and a Bengali musician. The budget and the person are open (OQ 1).
- With up to 4 players, the full SFX load (about 50 pooled voices against a cap of 32) relies on stealing. Playtest the tuning of the band assignments.
- No beat-synced music at MVP. Volleys will not follow the music. The Pattern library wants rhythm "in step with the music", so this is a possible future ask (OQ 7).
