# Project Structure

How the MorutJan Godot project is laid out and how the pieces talk to each other.

## Folders

```
res://
├── src/                     All code + the scenes that belong to it (feature-based)
│   ├── autoload/            Global singletons (registered in project.godot)
│   │   ├── game_events.gd     Signal bus for effects/UI (flash, popups, critical break)
│   │   ├── input_setup.gd     Registers p1_..p4_ actions: pad defaults + KB1/KB2 keyboard schemes
│   │   ├── input_sampler.gd   The only bridge from devices into SimInput (ADR-0002 step 1)
│   │   └── game_session.gd    State that survives a scene change (plane selections, debug boss)
│   ├── core/
│   │   └── combat_rules.gd    Resource: chain window, Critical Break, scoring rules
│   ├── gameplay/
│   │   ├── game/              game.tscn = main scene; Game = composition root + win/lose states
│   │   ├── chain/             ChainTracker (pure logic, unit tested)
│   │   ├── bullets/           BulletManager (all enemy bullets, packed arrays)
│   │   │   └── patterns/      BulletPattern resources (fan, ring, spiral, wall, curve)
│   │   ├── boss/              BossDefinition / BossPartDefinition (data) + Boss / BossPart (nodes)
│   │   ├── player/            Player, ShotWeapon, LaserAbility, PlaneConfig
│   │   └── effects/           PopupLayer (floating text)
│   ├── display/             (planned, Display scaler GDD) DisplayLayout, DisplayPresenter, sharp_bilinear.gdshader
│   └── ui/
│       ├── hud/             HUD scene + script (display only)
│       ├── localization/    UiStrings (every user-facing string) + UiStringTable resource
│       └── menu/            title.tscn, plane_select.tscn, LobbyModel, PlaneCard, LobbyRules
├── data/                    Designer-editable .tres files (no code)
│   ├── combat_rules.tres    plus bullet_, chain_, kit_, bomb_, item_, scoring_, enemy_rules
│   ├── bosses/              fortress_1941, jet_carrier_1970s, plasma_ring_2100
│   ├── stages/              stage_1_1941.tres (five named waves, then the boss)
│   ├── enemies/, patterns/  Per-enemy and per-pattern definitions
│   ├── menus/               plane_cards.tres (the four plane cards), lobby_rules.tres
│   ├── locale/              ui_menus.tres: every UI string, one column per language
│   ├── art/                 run_visuals_1941.tres (sprites the run draws)
│   ├── planes/              lancer.tres
│   └── display/             (planned) display_params.tres, bezel art per era
├── assets/                  Art, audio, fonts (empty: placeholder shapes for now)
├── tests/unit/              Headless tests (godot --headless --script ...)
├── design/gdd/              Game design docs
├── docs/                    Technical docs, engine reference
├── production/              Stage, review mode, session handoff
└── prototypes/              Throwaway builds. Never imported by src/.
```

## Scene tree at runtime

```
Game (game.gd)
├── Background      ColorRect
├── BossLayer
│   └── Boss        built from a BossDefinition
│       ├── Core    BossPart
│       └── Turret, Engine, Pod, Shield...  BossPart
├── BulletManager   draws all enemy bullets
├── PlayerLayer
│   └── Player      player.tscn
│       ├── LaserAbility
│       └── ShotWeapon   (top_level: shots live in world space)
├── PopupLayer
└── HUD             CanvasLayer
```

## Front end: how a run starts

```
title.tscn            TitleScreen        START GAME (Fire or Start, any device)
   |                                     GameSession.clear_run()
   v
plane_select.tscn     PlaneSelectScreen  view only; LobbyModel decides everything
   |                                     slot 0 opens Choosing (the Title press bound it)
   |                                     other slots join on Start / Fire
   |                                     Fire locks, Bomb unlocks then leaves
   |                                     all joined slots locked -> 45-tick bar -> commit
   |                                     GameSession.start_run(selections)
   v
run.tscn              Run                _join_selected_players():
                                           SimWorld.set_slot_kit(slot, kind)  (kit + bomb)
                                           world.add_player(slot)
                                           colourway per slot drives every sprite and tint
```

Input in both menus and the run goes through the same two stages: `InputSampler.service_step()`
every physics step (latches presses, runs while paused), then `commit_sim_tick(input)` writes one
`SimInput` for the tick. Nothing reads `Input` during a tick. Drone and Bomb presses are buffered
in `SimInput` for 6 ticks and consumed by whoever acts on them.

Keyboard: slot 0 is KB1 (arrows, Z fire, X drone, C bomb, Enter start), slot 1 is KB2 (WASD,
F fire, G drone, R bomb, 1 start), so two players share one keyboard. Slots 1-4 also have pads
1-4. The Lobby takes WASD off slot 0 while slot 1 is in the lobby.

## Who talks to whom

| From | To | How |
|---|---|---|
| Game | Boss, Player, HUD | Direct references, set in `Game._ready()` (dependency injection via `setup()`) |
| ShotWeapon / LaserAbility | Boss | `boss.find_part_at()`, `boss.find_laser_target()`, `part.apply_damage()` |
| Weapons | Player | `player.register_hit(result)` → chain, score, meter |
| Player | Boss | `boss.apply_bomb()`, `boss.critical_break()` |
| BossPart | BulletManager | via `BulletPattern.update()` → `bullets.spawn()` |
| Anything | effects / HUD | `GameEvents` signals only |
| HUD | Player, Boss | Reads state each frame. Never writes. |

## Adding content

- **New boss:** duplicate a file in `data/bosses/`, edit parts and patterns in the inspector, then add it to `GameSession.bosses`.
- **New bullet pattern:** extend `BulletPattern`, override `_emit()`, then add it to a part's `patterns` list.
- **New plane:** new `PlaneConfig` .tres. A different ability (turrets, drones) = a new component like `LaserAbility`.
- **Tuning:** `data/combat_rules.tres` (game-wide), `data/planes/*.tres`, `data/bosses/*.tres`, and BulletManager exports in `game.tscn`.

## Known gaps / tech debt

- Generated placeholder sprites (`tools/gen_placeholder_art.gd`), no audio at all.
- Two scene families still coexist: `game.tscn` is the old prototype boss fight (node-based
  Player / Boss / BulletManager), `run.tscn` is the real one (SimWorld + GameLoop). `src/gameplay/
  player/` and `src/gameplay/bullets/bullet_manager.gd` belong to the old one and are the only
  readers of the legacy `pN_ability` action.
- UI text goes through `UiStrings`, but most Bengali columns in `data/locale/ui_menus.tres` are
  empty and fall back to English on purpose.
- Input: slot N is still hard-bound to joypad N, there is no remapping, no hot-plug handling and
  no touch. See the Implementation status table in `design/gdd/input-and-player-mapping.md`.
- All GDScript, decided in ADR-0001 (no C#; Web export must work).
- No test framework: `tests/*/test_*.gd` are plain headless `SceneTree` scripts, run by
  `bash tests/run_all.sh` (22 suites).
