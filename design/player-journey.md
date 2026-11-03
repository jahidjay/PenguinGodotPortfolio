# Player Journey: MorutJan

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** — Open Questions in this document stay open.
> **Author**: user + ux-designer (Claude)
> **Last Updated**: 2026-11-03
> **Template**: none found in `.claude/docs/templates/`; layout below is the project's own
> **Sources**: `design/gdd/game-concept.md` (pillars, loops, target players), Player Fantasy sections of `menus-title-plane-select.md`, `tutorial.md`, `stage-end-tally.md`, `chain-tracker.md`, `coop-and-team-chain.md`, and `design/ux/arcade-ui-style.md`
> **Rule**: GDDs win over this document. It adds no game rules. Proposals are in Open Questions.

---

## 1. Who Walks This Journey

| Player | Share | Wants | Source |
|---|---|---|---|
| Score chaser / 1CC hunter (primary) | Core | Challenge, mastery, "I know where I dropped it" | game-concept 11 |
| Spectacle and combo-counter fan (secondary) | Large | Big numbers, clear feedback, flow | game-concept 11 |
| Couch co-op friends (secondary) | Large | Together on one screen, 2-4 pads, no setup | game-concept 11; co-op GDD |
| Phone player (solo) | Some | Fair touch controls, short sessions | touch-controls |
| Player who needs accessibility options | All groups | The same game, set up once | accessibility-options |
| Not for | Story-first and failure-averse players | | game-concept 11 |

Platform note: PC (Steam/itch), Web, iOS, Android, Switch. Gamepad is the primary input. Touch is solo only. Co-op on phones is for Bluetooth pads.

## 2. Design Pillars Applied to the Journey

| Pillar | What the journey must show |
|---|---|
| Every Hit Counts | The chain counter is understood in the first stage and is the reason the player returns |
| Readable Chaos | Every death feels like the player's fault; every screen is calm and clear between fights |
| Four Planes, Four Games | The plane choice feels like a style choice, not a guess |
| History Accelerates | Each stage jump is felt: the era card, the new bullet language |
| Arcade fast, not arcade cruel | Title to flying is 2 presses solo; game over to a new run is 3 (Menus Player Fantasy) |

---

## 3. Journey Overview

| # | Phase | Time span | Player goal | Emotion arc | Success signal |
|---|---|---|---|---|---|
| 1 | First launch | 0-1 min | Get into the game | Curious, a little impatient | Reaches Title with correct language and settings |
| 2 | First run | 0-30 min (session 1) | Fly stage 1, understand the chain | Eager, then humbled, then hooked | Beats stage 1 or says "one more go" |
| 3 | Learning | Days 1-7 | Understand kits, routes and the boss | Frustrated, then curious, then competent | Completes the first two stages; tries both planes |
| 4 | Co-op night | Any evening | Fly together | Playful, loud, supportive | Everyone joins in under a minute and nobody quits |
| 5 | Mastery | Weeks | Raise max chain, 1CC, boards, boss practice | Focused, proud, competitive | New best, 1CC, Critical Break on every boss |

```
Boot -> Web gate -> First-run prompt -> TITLE -> LOBBY -> STAGE 1 -> (death/continue) -> BOSS -> TALLY -> ... -> RESULTS -> BOARD -> TITLE
                                             \-> FLIGHT SCHOOL (opt-in) ... -> Pause -> Settings
```

### 3.1 Screen spec links

| Screen | Spec | State |
|---|---|---|
| Title / Main menu | [ux/main-menu.md](ux/main-menu.md) | Written |
| Lobby (plane select) | [ux/lobby.md](ux/lobby.md) | Written |
| Pause | [ux/pause.md](ux/pause.md) | Written |
| Stage tally | [ux/stage-tally.md](ux/stage-tally.md) | Written |
| Patterns and style | [ux/interaction-patterns.md](ux/interaction-patterns.md), [ux/arcade-ui-style.md](ux/arcade-ui-style.md) | Written |
| Gameplay HUD | `ux/hud.md` | Draft 2026-11-03 |
| Results and name entry | `ux/results-name-entry.md` | Draft 2026-11-03 |
| High scores | `ux/high-scores.md` | Draft 2026-11-03 |
| Settings and Accessibility | `ux/settings.md` | Draft 2026-11-03 |
| Flight School | `ux/flight-school.md` | Draft 2026-11-03 |

---

## 4. Phase 1: First Launch

| Field | Detail |
|---|---|
| **Player goal** | Start playing within a minute; not fight settings |
| **Emotional state** | Curious, a little impatient; on Web, "I just clicked a tab" |
| **Screens** | Boot, Web gate (Web only; [main-menu.md](ux/main-menu.md)), first-run photosensitivity plate (spec pending, `settings.md`), [Title](ux/main-menu.md) |
| **Flow** | Boot -> Web gate (first click, key or touch, consumed; unlocks audio) -> first-run plate once (Keep as is / Reduce flashing and effects) -> Title with the language chip |
| **Design intent** | No first-run language screen: the chip fixes a wrong OS guess in one press. The bilingual logo and four planes show identity. START GAME is the default focus |

**Critical moments**

| Moment | Why it matters | Check |
|---|---|---|
| First click on Web | Audio unlock; a gamepad press may not count as a user gesture | Menus OQ6, Web spike |
| First-run plate | The only time a photosensitive player is warned before the one bright flash | Accessibility Rule 34 |
| Title, first view | Player must see how to start in 3 seconds | main-menu purpose |
| Wrong language guess | Bengali player sees English (or reverse) | Language chip is reachable by D-pad |

**Risks and drop-off**

| Risk | Effect | Mitigation (existing) |
|---|---|---|
| Web gate looks like a dead page | Tab closed | Char screen with a bilingual line, any input accepted |
| First-run plate feels like a legal wall | Player skips without reading | One press to skip; two items only; default focus Keep as is (see Open Question 2) |
| Wrong language, no obvious chip | Bounce | Chip on Title, own-script labels, language swap in one frame |
| Slow Web load (large download) | Bounce before Title | Out of scope here; see technical docs |

---

## 5. Phase 2: First Run

| Field | Detail |
|---|---|
| **Player goal** | Fly, hit things, see the chain climb, reach the first boss |
| **Emotional state** | Eager -> overwhelmed by bullets -> "I know where I went wrong" |
| **Screens** | Title -> [Lobby](ux/lobby.md) -> Stage 1 (HUD) -> Continue -> boss -> [Pause](ux/pause.md) -> [Stage tally](ux/stage-tally.md) -> Results and name entry -> Board |
| **Design intent** | Two presses to fly. The plane card says in three short rows what Fire, hold-Fire and Drone do. Stage 1 is sparse and slow and teaches movement and chain with no text in the field |

### 5.1 Step by step

| Step | What the player does | What the game shows | Notes |
|---|---|---|---|
| 1 | Start on START GAME | Lobby with the roster: four planes on pedestals (MVP: Lancer and Leech) | Lobby: [lobby.md](ux/lobby.md) |
| 2 | Move cursor, press Fire to lock | Vermillion solid ring slides onto the plane, READY stamp drops | Slot colour plus ring pattern plus pips |
| 3 | Wait for the start delay | Hangar doors open into 1941, stage card, no spawns | Char hold cannot be paused |
| 4 | Fly the five waves | Lighter, faster waves; hit counter and window bar; shots and bullets clearly different | HUD strip fixed: 48 px (1-2P) |
| 5 | **First death** | Life icon steps, short respawn invulnerability, bomb count refills per rules | Honest: a death is the player's fault |
| 6 | **First continue** (if out of lives) | Large numerals count down in the player's column | `continue_timer` option; Pause freezes it |
| 7 | **First boss** | Warning banner (amber stripes, bilingual plate, siren), boss name plate, HP bar with number | The visual twin of the siren is the banner |
| 8 | Chain on the boss | Chain plate edge steps to gold past 100; bar drains toward the red end-cap | Chain GDD player fantasy |
| 9 | Boss defeated (or Critical Break attempted) | Banner; stage clear | One Critical Break frame only (removable) |
| 10 | **Tally** | Rows drop in a quarter-second apart; counters tick up; missed bonuses dimmed with a cross | Always skippable: once to settle, once to go on |
| 11 | Game over or all clear | Results: score, max chain, name wheel if it qualifies | Pending `results-name-entry.md` |
| 12 | Board | The player's place on the board, PLAY AGAIN focused | Three presses from Results to a new run |

### 5.2 Critical moments

| Moment | Player feeling we want | Failure feeling to avoid |
|---|---|---|
| First chain over 20 | "I made that number go up" | Not noticing the counter |
| First death | "That was me" | "Unfair, I never saw it" |
| First time the chain drops | The ghost shows what was lost; "I know where I went wrong" | Confusion about why it reset |
| Boss Warning | Excitement, a peak | Panic from a flash or scream |
| First Tally | Pride; "look what I did"; sees the 200,000 left behind | Boredom from an unskippable roll |
| Quit to title | Trust: the hold asks first and says the score will not be saved | Silent loss |

### 5.3 Risks and drop-off

| Risk | Where | Mitigation (existing) |
|---|---|---|
| Too many bullets, never sees the chain | Stage 1 | Sparse stage 1; chain plate is the hero number; Readable Chaos |
| Does not understand tap vs hold Fire | Wave 1 | Plane card rows; contextual hints (opt-out); Flight School door |
| Fails repeatedly with no sense of progress | Boss 1 | Short failure loop; continue; Results offers Flight School once (Tutorial Rule 25) |
| Lost chain feels unexplained | Mid-stage | Ghost of the dropped chain |
| Wants help but sees "difficulty" shame | Any time | No difficulty names; only a practice speed assist, marked PRACTICE with an icon and word |
| Touch: thumb occludes or mis-taps | Phone first run | Buttons in a strip under the field; relative drag; no accidental Bomb from palm |
| Accessibility need discovered late | Mid-run | Settings reachable from Pause; changes marked "applies next stage" where needed |

---

## 6. Phase 3: Learning

| Field | Detail |
|---|---|
| **Player goal** | Understand why they died, how kits differ, and how to keep the chain through a boss |
| **Emotional state** | Frustrated -> curious -> competent ("one more go") |
| **Screens** | Title (FLIGHT SCHOOL item, NEW tag) -> [Lobby in school mode](ux/lobby.md) -> School list and drill cards (`flight-school.md`, pending) -> drill -> [Pause](ux/pause.md) (Restart drill, Skip drill) -> back to list; [Stage tally](ux/stage-tally.md) tips; [Settings](gdd/accessibility-options.md) |
| **Design intent** | School is a door, not a gate: nothing unlocks or locks on school progress. Each drill has one idea, a number to reach and a stamp. A failed attempt costs ten seconds. Drills use the real hitbox, chain window and bomb toll |

### 6.1 Entry points

| Entry | When | Source |
|---|---|---|
| FLIGHT SCHOOL item on Title | Always, with NEW tag until first visit | Tutorial Rule 25a |
| One-time Results footer "New? Try Flight School from the title." | After the first GAME_OVER if school not complete | Tutorial Rule 25b |
| Contextual hints in real runs (strip marks, Pause and Tally tips) | By trigger; suppressed when the drill is done; off in Settings | Tutorial Rules 19, 26-29 |
| Pause -> Settings | Any time | Menus |

### 6.2 Critical moments

| Moment | Why it matters |
|---|---|
| First DONE stamp in a drill | Confidence; proves "a failed attempt costs nothing" |
| First time the player holds Fire and the plane changes mode | Kit identity; the Lancer and Leech feel like different games |
| First boss tip at a Pause or Tally | Help arrives where the field is empty, never over bullets |
| Trying the second plane | "Four Planes, Four Games" confirmed |
| Discovering the Critical Break | The emotional peak that explains why the game exists |

### 6.3 Risks and drop-off

| Risk | Mitigation (existing) |
|---|---|
| Player treats school as homework and quits | No gating, no failure, Skip drill, Quit to list |
| Hints annoy experts | Hints off in Settings; drill-done bits suppress hints |
| Text walls | No text over a live field; text only on stopped surfaces |
| Player cannot hit the drill target because of access needs | Practice speed assist is available from Pause (marks the run PRACTICE; drills are unranked anyway) |
| Co-op friends cannot all do drills | Per-slot success and DONE stamps; no mid-drill join, join via the list |

---

## 7. Phase 4: Co-op Night

| Field | Detail |
|---|---|
| **Player goal** | Fly with friends on one screen without setup |
| **Emotional state** | Playful, loud, supportive; "we just read each other" |
| **Screens** | [Title](ux/main-menu.md) -> [Lobby](ux/lobby.md) (join with Start) -> Stage (HUD with 2-4 columns, 72 px strip at 3-4P) -> [Pause](ux/pause.md) (who paused, status panel) -> [Stage tally](ux/stage-tally.md) (one column per player) -> Results -> Board (co-op per player count) |
| **Design intent** | Every player has their own cursor at the same time and nobody waits for a turn. A stalled friend cannot hold the lobby hostage. Chain, score, lives and continues are personal; no revive; no transfers. Team Chain Bonus rewards flying at the same target |

### 7.1 Step by step

| Step | What happens | UX check |
|---|---|---|
| 1 | First player presses Start: ring lands on the Lancer | Slot 1: solid vermillion ring, one pip |
| 2 | A second pad presses Start: dashed ring lands on the Leech | Slot identity by pattern and pips, not colour |
| 3 | Third and fourth pads join; keyboard can join as a seat | Pad pairing is automatic; swapping pads keeps slot layout (per-slot maps) |
| 4 | Everyone locks with Fire; READY stamps drop | A slot that has not locked does not block others past the Lobby rules |
| 5 | Stage: join plates in empty columns pulse steadily | Pulse steady under reduce pulsing |
| 6 | Boss: bracket links between plates, lamp shows who has hit recently | Team Chain Bonus visible, not only audible |
| 7 | A friend dies | Cost is theirs; the rest fly on; the returning plane gets a grace period |
| 8 | Tally | One column each; same clock; one player's skip never hides another's numbers |
| 9 | Results | Co-op board per player count; an assist anywhere marks the whole run PRACTICE |

### 7.2 Critical moments

| Moment | Feeling |
|---|---|
| Second pad joins and a ring appears | "It just worked" |
| Bracket snaps between plates | "We are a team" |
| A friend drops out and rejoins | Welcome back, not punishment |
| Four-player density | Still readable: allies' shots dimmed by count; hitbox rings per slot |
| Someone needs the game slower or a one-handed layout | Settings choose the whole run; PRACTICE tag is visible to everyone, nothing hidden or shamed |

### 7.3 Risks and drop-off

| Risk | Mitigation (existing) |
|---|---|
| Controller confusion (which pad is which) | Join plate, pad-lost chime and toast; slot indices, not GUIDs |
| Visual overload at 4P | Fixed pattern density per Co-op GDD; ally shot dim option; PLAIN/DIMMED background |
| One player is much weaker | Personal lives and continues; Tap Assist and Fire toggle remain ranked; practice speed marks the run unranked (global) |
| Colour confusion between slots | Ring pattern, pips, "P{n}"; LUMA_SPREAD palette option |
| Phone co-op expectation | Touch is solo; use Bluetooth pads |
| Evening ends in an argument over a drop-in | No revive, no shared pool; the rules are on the plate |

---

## 8. Phase 5: Mastery

| Field | Detail |
|---|---|
| **Player goal** | Higher chain, higher score, 1CC with each plane, Critical Break on every boss, boards, boss practice |
| **Emotional state** | Focused, proud, competitive; "I dropped my chain at 187" |
| **Screens** | [Title](ux/main-menu.md) (Play choice at Stretch) -> [Lobby](ux/lobby.md) -> Stage -> [Pause](ux/pause.md) -> [Stage tally](ux/stage-tally.md) -> Results and name entry -> [High scores](gdd/save-settings-high-scores.md) (`high-scores.md` pending) |
| **Design intent** | Growth is skill, not stats. No shops, no upgrades, no cutscenes. Short loops. Ranked rules never move |

### 8.1 What mastery looks like

| Mastery layer | What the player does | Screens |
|---|---|---|
| Chain routes | Chooses which targets to hit next to keep the window alive; learns what each kit contributes | HUD chain plate, Tally "max chain" |
| Critical Break | Lands charge plus bomb on the core while the boss is critical; spends the bomb on the break, not survival | HUD armed corner ticks, banner, Tally bonus |
| 1CC | Clears all four stages on one credit | Results "one credit clear", Board |
| Boards | Per plane (solo) and per player count (co-op) | High scores, name entry (initials, last initials remembered) |
| Online (Stretch) | Opt-in, replay-verified boards (global, friends, around me) | Board screens at Stretch |
| Boss Rush and Single Boss (Stretch) | Unlocked per boss on first defeat; Single Boss with a game-speed assist is the boss practice mode (unranked, PRACTICE) | Title -> Play choice -> Boss select |
| Replay and compare | Reads a ghost of a dropped chain; sees missed bonuses | Tally, Results |

### 8.2 Critical moments

| Moment | Why it matters |
|---|---|
| First chain of 100 and the plate edge steps to gold | The first hook; the player breathes out |
| First Critical Break | The emotional peak: bomb and charge together, life damage bonus |
| First new best | Tally NEW BEST stamp (removable pulse) |
| First 1CC | The end of the credit loop; Results should honour it |
| Entering initials | A short, forgiving wheel; times out to last initials |
| Unlocking Boss Rush (Stretch) | Late-game goal; Play choice appears on Title only once unlocked |

### 8.3 Risks and drop-off

| Risk | Mitigation (existing) |
|---|---|
| Plateau: no new content after 1CC | Four planes (Target), boards, boss rush (Stretch) |
| Leaderboards feel unfair | Assist runs never ranked or uploaded; touch has separate boards |
| Experts annoyed by menus | Skippable tally, 3-press restart, hold-to-confirm only where risk exists |
| Accessibility vs ranked tension | Convenience options stay ranked; sim-changing options mark PRACTICE; no silent assist |
| Burnout from failure | Short failure loops; Pause anywhere; session loop ends at a tally |
| Repeated Bengali text strain at long sessions | Text size steps; high-contrast HUD; PLAIN background |

---

## 9. Cross-Cutting Journey Rules

| Rule | Applies to |
|---|---|
| Menus show one language (the chosen one); only listed surfaces show both scripts | All phases ([arcade-ui-style.md](ux/arcade-ui-style.md) 2.1) |
| Pause anywhere in play; it opens within 1 tick | Phases 2-5 |
| Only one flash in the game; removable; first-run prompt offers the Calm preset | All phases |
| Accessibility settings are reachable from Title and Pause; assist use is always shown, never hidden | All phases (see [accessibility-requirements.md](accessibility-requirements.md)) |
| No coin or credit language; home-game wording | Title, Results |
| Nothing is lost silently: quit warns, name entry keeps last initials | Phases 2, 5 |

## 10. Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Where does the first-run plate sit relative to the Web gate when the first input is a gamepad that cannot unlock audio? | UX, Menus | Web spike |
| 2 | Should first-run default focus favour **Reduce flashing and effects** on Web (cold arrival)? The GDD says Keep as is | game-designer | Vertical Slice |
| 3 | Should the first Results screen after game over also point to Settings > Practice speed for players who die in stage 1? Today only Flight School is offered | game-designer | Playtest |
| 4 | Do we need a "co-op night" quick start (remember the last roster)? Not in any GDD | game-designer | Target |
| 5 | Should returning players skip the Lobby start delay? Not specified | game-designer | Playtest |
| 6 | Journey metrics (first-run completion, Flight School visits, drop-off by stage) need an analytics plan; none exists yet | analytics-engineer | Production |
| 7 | Write the missing UX specs: hud, results-name-entry, high-scores, settings, flight-school; each should use `Journey Phase(s)` from this file | ux-designer | Before Vertical Slice |
| 8 | Update existing UX specs that say "Journey Phase(s): unknown" to reference phases 1-5 here | ux-designer | With next review |
