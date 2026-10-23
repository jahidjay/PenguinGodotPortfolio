# Boss Chain Concept Prototype

**Status:** in-progress (built, awaiting first playtest)

## Hypothesis
If the player keeps shooting a boss and then lands **laser + bomb at critical HP**, the hit counter climbs past 100 and spikes past 200. True if a tester voluntarily retries to beat their chain and can explain why they dropped it.

**Riskiest assumption:** a strict 1 s chain window with pure reset feels tense and fair, not just punishing.

## How to run
1. Open Godot 4.7 -> Import -> select `prototypes/boss-chain-concept/project.godot` (a separate throwaway project, not the main game).
2. Press F5.

## Controls
| Action | Keyboard | Gamepad (slot 0) |
|---|---|---|
| Move | Arrows / WASD | Left stick / D-pad |
| Shot (hold) | Z or Space | A |
| Laser (hold, needs meter >= 40) | X | X |
| Bomb | C | B |
| Restart | R | — |

## What to try
- Chain hits on the boss and watch the green window bar. Stopping for 1 s resets to 0.
- Hits fill the orange laser meter. Laser = invulnerable + 3x damage, slower movement.
- When the boss turns yellow/flashing (CRITICAL), press Bomb **while Laser is on** for the Critical Break (chain x3 + 50, big score bonus).
- Bombing without laser, or outside critical, is a plain bomb.

## Iteration 2 — multi-boss + destructible parts
First playtest (single player): core chain + laser + Critical Break loop **works**.
Now testing: do destructible parts with their own hitboxes and patterns make better boss design?

| Key | Boss | Parts | Core rule |
|---|---|---|---|
| 1 | 1941 Flying Fortress | 2 wing turrets (aimed fans), 2 engines (rings) | Armored (25% dmg) while parts live; spiral escalates |
| 2 | 1970s Jet Carrier | 3 orbiting missile pods (aimed streams), 2 wings (bullet walls w/ gap) | Armored; accelerating fans |
| 3 | 2100 Plasma Ring | 4 orbiting shields (curving bullets) | **Immune** until shields die; time-warp bullets freeze then re-aim |

- Destroying a part: stops its pattern, cancels nearby bullets, +5 chain, +2000 score.
- Laser stops at the first part in its column, so part layout shapes your route.
- N = next boss, 1/2/3 = pick boss.

## Prototype shortcuts (on purpose)
- Boss cannot die from normal damage below critical (`BOSS_CLAMP_AT_CRIT`); it needs the Critical Break.
- All values are constants at the top of `main.gd`.
- Rectangles/circles only, no audio, no pooling.

## Findings
(to be filled in after playtest — see REPORT.md)
