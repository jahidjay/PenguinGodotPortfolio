# Game Concept: MorutJan

> **Status:** **Approved (2026-11-03)** — concept approved in /brainstorm 2026-10-23; formally accepted with the whole design set on 2026-11-03 (final doc closeout), project moved to Pre-Production
> **Last Updated:** 2026-11-03
> **Review mode:** lean
> **Engine:** Godot 4.7 (GL Compatibility renderer)

---

## 1. Core Identity

| Field | Value |
|---|---|
| **Working Title** | MorutJan (project name; final title TBD) |
| **Genre** | Vertical-scrolling bullet hell (danmaku) shoot 'em up |
| **Elevator Pitch** | Four 1941 warplanes fly through history — every stage jumps forward in time, from WW2 flak to 2100 plasma — chaining hundreds of hits on bosses in a DoDonPachi-style bullet hell for 1–4 players. |
| **Core Verb** | Chain (keep hitting to keep the hit counter alive) |
| **Core Fantasy** | A WW2 ace whose plane evolves through the eras, threading impossible bullet curtains and breaking bosses for 200+ hit chains. |
| **Unique Hook** | Like DoDonPachi, **and also** every stage is a jump forward in time that changes the bullet language, enemies, and your own plane — with four kits that each chain in a completely different way. |
| **Primary MDA Aesthetic** | Challenge (secondary: Sensation, Fellowship in co-op) |
| **Target Platforms** | Multiple — PC (Steam/itch), Web, iOS (iPhone X+), Android (Galaxy S20 class+), Nintendo Switch / Switch 2 |
| **Players** | 1–4 local co-op |
| **Estimated Scope** | Small–Medium (6–8 weeks to Target tier, solo professional) |
| **Primary Reference** | DoDonPachi (Cave, 1997), DonPachi (1995), 1941: Counter Attack (Capcom, 1990) |

---

## 2. Creative Brief

The player wants **challenge and mastery**: a screen flooded with enemy bullets, a tiny dodge window, and the thrill of a hit counter climbing past 100 — then past 200 — on a boss. The emotional peak is the boss chain: keep hitting continuously, and when the boss reaches critical condition, unleash charge attack + bomb together to multiply the chain and earn a Life Damage Bonus. The look is 1941 pixel art, escalating into the future each stage. The developer has a professional background and a weeks-scale timeline, so the game must be tight and polished rather than sprawling.

---

## 3. Core Loop

### 30-Second Loop (moment-to-moment)
- Move with a tiny hitbox through bullet curtains.
- **Tap fire** → wide normal shot. **Hold fire** → plane's charge mode (Lancer laser, Leech focused shot), movement slows for precision. **Drone button** → the plane's drone ability (drones come from powerups, max 4; see §5).
- Every hit inside the chain window (~1 s) increments the **hit counter**.
- **Hybrid density:** stage waves are lighter and faster (1941-arcade feel); bosses use full DoDonPachi-density curtains.

### 5-Minute Loop (one stage)
- **5 waves → boss.**
- **Boss chain:** sustain the hit counter through every boss phase.
- **Critical Break:** when the boss is at critical HP, hitting it with **charge attack + bomb simultaneously** applies a large chain multiplier (200+ hits achievable) and awards a **Life Damage Bonus**.
- Stage-end tally: max chain, Critical Break bonus, score.

### Session Loop (20–30 min, one credit)
Four stages, one per era. The player's plane **evolves** (look, shot, ability visuals/power) at each era jump *(look and ability visuals only; all numbers are identical in every era — Era shift 19, 2026-11-03)*:

| Stage | Era | Enemy / bullet language |
|---|---|---|
| 1 | 1941 | Propeller fighters, bombers, flak bursts, round bullets |
| 2 | 1970s | Jets, missiles, radar-locked spreads |
| 3 | 2030s | Drones, lasers, energy shields |
| 4 | 2100+ | Plasma, time-warp / rewinding bullet patterns |

Natural stopping point: after each stage tally or game over. The hook that stays with the player: "I dropped my chain at 187 — I know where I went wrong."

### Progression Loop (days/weeks)
- Growth is **player skill**, not stats.
- Goals: master all 4 planes, raise max chain per boss, high score, 1-credit clear (1CC) with each plane, co-op clears.

---

## 4. Chain System (core rules)

- **Chain window:** strict, ~1 second. Any hit on an enemy refreshes it.
- **Window expires → chain resets to 0** (pure reset, true DoDonPachi).
- Counter is **per player**. In co-op, a **Team Chain Bonus** applies while all active players hit the boss in the same window.
- **Critical Break:** boss in critical HP state + charge attack + bomb landing together → chain multiplier + Life Damage Bonus. *(Defined 2026-11-03, `critical-break.md`: the bomb must land on the boss core while that player's charge (Lancer laser / Leech focused shot) has run at least 12 ticks and hit the core within the last 12 ticks; one break per boss.)*
- Chain value feeds score; it is the primary score driver.

---

## 5. Player Planes

*(Revised 2026-11-02: drones come from powerups.)*

All four are 1941-era airframes. Each has its own **normal shot, charge mode, drone ability, and bomb**.

### Shared rules (all planes)
- **Fire:** a press fires the normal shot (auto-repeat while held); holding 0.3 s switches to the plane's charge mode (Plane kits (11), 2026-11-03).
- **Three buttons:** **Fire** (tap = normal shot, hold = the plane's charge mode), **Drone** (triggers the drone ability), **Bomb**. Plus **Start** (join / pause) and **Back** (pause / cancel) for menus (Input (2)).
- **Base plane has 0 drones.** Each **powerup** pickup adds **+1 drone**, max **4**.
- Powerups: drone pods (+1 drone, max 4), chain pickups, medals, rare fixed 1-ups — never stat upgrades (see powerups-and-drops.md).
- **Death resets the plane to 0 drones.** Drones carry over to the next stage if you don't die.
- Each plane's drone ability has its own **duration and cooldown** (4 planes, 4 drone powers, 4 cooldowns).
- Idle drones fly with the plane and fire normal drone bullets.

| # | Plane | Fire (hold) | Drone ability (Drone button) | Chain role | Tier |
|---|---|---|---|---|---|
| 1 | **Lancer** | **Laser:** invulnerable while lasering, damage multiplier, gated by a meter that fills from hits and burns while firing. | Drones **deploy and park in place, firing laser** for a set time, then fly back, return to normal drone bullets, and the cooldown starts. | Burst finisher; parked lasers hold a boss's chain while you dodge. | MVP |
| 2 | **Leech** | **Focused shot:** narrow, stronger, slower movement. | **Magnet drones latch onto an enemy** and keep hitting until it dies; then each drone jumps to the **closest** enemy, repeating until the timer runs out. Then they return and the cooldown starts. | Guaranteed sustained hits — steady chain building. | MVP |
| 3 | **Sentry** | TBD | TBD — to be redesigned under the shared drone rules (old idea: stationary turret drones). | Zone control. | Target |
| 4 | **Breaker** | TBD | TBD — to be redesigned under the shared drone rules (old idea: drones erase enemy bullets). | Defensive offense. | Target |

~~Open: does Lancer's drone deploy also need/use the laser meter, or only its own cooldown? What does a powerup give at 4 drones (score bonus?).~~ **Closed 2026-11-03:** Lancer's drone ability uses its own cooldown only (600 ticks); the meter belongs to the laser (Plane kits (11)). A powerup (POD) at 4 drones is skipped if another Active plane needs it, otherwise it pays a MEDAL (Powerups (13)). Durations, cooldowns and laser numbers are in `plane-kits-lancer-leech.md`.

~~Bomb designs per plane: TBD.~~ **Decided (Bombs 12, 2026-11-03):** Lancer = Lance Sweep (a light column that holds, then sweeps both ways); Leech = Barb Burst (four seeking hooks that cling and burst). 3 bombs per life, topped up at each stage; each bomb costs half the chain count unless a Critical Break is armed.

---

## 6. Game Pillars

1. **Every Hit Counts** — The chain is the game; every system feeds or threatens the hit counter.
   *Design test:* between a cooler-looking feature and one that creates chain decisions, choose the chain decision.
2. **Readable Chaos** — The screen floods, but every bullet is readable and every death is the player's fault.
   *Design test:* between visual spectacle and bullet clarity, choose clarity.
3. **Four Planes, Four Games** — Each kit changes *how* you chain, not just how much damage you do.
   *Design test:* a new ability must open a different route to a high chain, or it is cut.
4. **History Accelerates** — Every stage is a jump in time you see, hear and feel in the bullets.
   *Design test:* an era must change the bullet language, not just reskin enemies.

### Anti-Pillars
- We will **NOT** add stat grinding or upgrade shops — it would compromise *Every Hit Counts* by replacing skill with numbers.
- We will **NOT** add mid-run story cutscenes — they break flow and chain rhythm.
- We will **NOT** exceed 4 planes or 4 stages in this scope — it would compromise *Four Planes, Four Games* depth on a weeks-scale timeline.

---

## 7. Visual Identity Anchor — "Arcade Chronicle"

**Visual rule:** 1941 Capcom-style pixel art; each era adds a palette layer — olive/sepia → chrome/orange → neon cyan → white/magenta plasma.

**Supporting principles:**
1. **Warm vs. cool** — player shots are always warm; enemy bullets are always cool with a dark outline.
   *Test:* every new bullet must read in a grayscale screenshot.
2. **Silhouettes stay 1941** — player planes keep WW2 silhouettes; future tech is bolted on.
   *Test:* you can still name the base airframe in the 2100 era.
3. **Effects scale with time** — later eras earn more glow and particles, never on top of enemy bullets.
   *Test:* if an effect overlaps a bullet, it is cut.

**Color philosophy:** Each era owns a palette, but enemy-bullet colors and contrast rules are constant across all eras so the player's reading skill transfers from stage to stage. In co-op, each player owns a hitbox ring color.

**Resolution target:** vertical 360×640 (9:16) pixel canvas, x4 = 1440×2560. Fixed play area on every device; other aspect ratios get bezel art (art bible §8.1.1).

---

## 8. MDA Analysis

- **Mechanics:** tiny hitbox, strict chain window, charge abilities, bombs, Critical Break, era-shifting bullet patterns.
- **Dynamics:** risk/reward of staying close to the boss to keep the chain; choosing when to spend bomb on survival vs. Critical Break; co-op coordination for the Team Chain Bonus.
- **Aesthetics:** Challenge (primary), Sensation (screen-filling bullets, climbing counter), Fellowship (co-op).

---

## 9. Player Motivation (Self-Determination Theory)

- **Autonomy:** four distinct kits; choice of when to charge, bomb, or Critical Break.
- **Competence (dominant):** visible chain numbers, max-chain records, score, 1CC goals.
- **Relatedness:** local co-op, shared team chains, score bragging.

---

## 10. Flow State Design

- Stage 1 (1941) teaches movement and chain with sparse, slow patterns.
- Waves escalate within each stage; each boss is the peak.
- Each new era introduces one new bullet behavior at a time before combining them. *(Implemented by Boss power budget (15) and Era shift (19): mechanic previews, era novelty rules and the era ladder, 2026-11-03.)*
- Instant restart / continue keeps failure loops short.
- Clear feedback: hit counter, chain-window timer bar, Critical Break flash and audio sting.

---

## 11. Target Player

- **Primary:** Achievers / Competitors — score chasers and 1CC hunters (DoDonPachi, Touhou, Mushihimesama audience).
- **Secondary:** action players who love spectacle and combo-counter feedback; friends looking for local co-op.
- **Not for:** casual or story-first players, players averse to repeated failure.
- **Market notes:** Niche but loyal shmup audience on Steam/itch; pixel art + WW2-to-future hook + local 4P co-op are the differentiators.

---

## 12. Scope Tiers

| Tier | Content | Est. time |
|---|---|---|
| **MVP** | 2 stages (1941 → 1970s), each 5 waves + boss with Critical Break · 2 planes (Lancer, Leech) · local co-op 1–4 players (tested at 2P, architected for 4) · strict chain + pure reset · per-player chains + Team Chain Bonus · score + stage tally | ~3 weeks |
| **Target** | All 4 planes (+Sentry, +Breaker) · all 4 eras (4 stages × 5 waves + boss) · plane evolution per era · high-score tables (solo per plane, co-op per player count) | ~6–8 weeks |
| **Stretch** | Boss rush / score attack · online leaderboards | Post-launch |

*Added 2026-11-03 (wave 4, online-leaderboards-boss-rush.md):* Stretch detail: **online leaderboards** (opt-in, replay-verified; global / friends / around me, per plane and player count) and **boss rush** (bosses in era order, plus Single Boss). See `design/gdd/online-leaderboards-boss-rush.md`.

**MVP success question:** Is chaining a boss toward 100+ hits, then landing a Critical Break, thrilling — solo and in 2P co-op?

---

## 13. Risks

| Risk | Type | Mitigation |
|---|---|---|
| Hundreds of bullets choke Godot if each is a node | Technical | Pooled bullet manager (MultiMesh / PhysicsServer2D or custom arrays) from day 1 |
| 4P co-op floods screen, hurting *Readable Chaos* | Design | Other players' shots at reduced opacity; per-player hitbox ring colors; tune Breaker erase for co-op; pattern density unscaled, hp and group-size scaling per Co-op (18) |
| Lancer invulnerable laser becomes dominant | Design | Meter fills only from hits; burns during laser; balance in prototype |
| Late-era palettes hide enemy bullets | Art | Constant enemy-bullet color/contrast rule across eras; grayscale test |
| Precise dodging on touch devices | Platform | Relative touch-drag, visible hitbox; mobile deprioritized behind PC/Web |
| Art volume (4 eras × enemies × 4 planes × evolutions) | Production | Palette layers + bolt-on sprite swaps rather than full redraws |

*Added 2026-11-03 (wave 4, touch-controls.md):* mitigation for "Precise dodging on touch devices" is now: relative touch-drag capped at `move_speed`, visible hitbox, buttons in a strip below the canvas, and separate touch boards (`/touch`, solo only). See `design/gdd/touch-controls.md`.

---

## 14. Open Questions
- ~~Bomb design for each plane.~~ **Closed 2026-11-03:** see §5 (Bombs (12)).
- ~~Exact Critical Break multiplier formula and Life Damage Bonus calculation.~~ **Closed 2026-11-03:** multiplier in Chain F4 (`count x 3 + 50`, capped 999), points and Life Damage Bonus in Scoring F4, trigger in `critical-break.md`.
- ~~Shared vs. per-player lives / continues in co-op.~~ **Closed 2026-11-03:** per player; no shared pool, no transfers, no revive (Co-op (18)).
- Final game title.
