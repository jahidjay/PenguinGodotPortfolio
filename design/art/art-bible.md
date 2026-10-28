# Art Bible: MorutJan

> **Status:** Complete, all 9 sections (authored via /art-bible, 2026-10-28)
> **Art Director Sign-Off (AD-ART-BIBLE):** skipped (lean review mode)
> **Review mode:** lean
> **Visual anchor:** "Arcade Chronicle" (from `design/gdd/game-concept.md` §7)
> **References:** 1941: Counter Attack (Capcom), DoDonPachi (Cave), Metal Slug (SNK/Nazca), Ganryu (Visco, 1999)
> **Last Updated:** 2026-11-03
> **Revision 2026-11-03 (art-director decisions)**: 4.1 gains the text-only red **Alarm Flare `#F2494D`** (4.76:1 on Char, computed); `#E03A3E` stays the plate-edge and glyph-fill red; 7.10 and 7.8 updated to match.
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: 7.5 separates the 4 px matra **reservation** from the 2 px / 3 px **clip floors**; 7.10 bars Alarm Red as a text fill and requires Cream words plus an Alarm Red edge and/or error glyph for any failure, and records the lighter-red text token as an open art-director decision with no colour invented.

## Project Constraints

- **Bilingual (Bengali + English):** MorutJan is a Bengali game. The title and all player-facing text ship in both Bengali (বাংলা) and English. Every text-bearing asset (title logo, HUD labels, menus, tally screens, chain counter labels) must be designed for both scripts. See Section 6 and Section 8.
- **Canvas:** **360×640** (9:16) vertical pixel canvas, the same on every device. It scales x2 to 720×1280, x3 to 1080×1920 and x4 to 1440×2560 (the 1440p target). Godot 4.7, GL Compatibility renderer. Device and aspect support is in Section 8.1.1. *(Changed 2026-10-31 from 240×320; all pixel sizes in this document were rescaled by 1.5x. Line widths such as 1 px outlines did not change.)*
- **Platforms:** PC (Steam/itch), Web, iOS (iPhone X and later), Android (Galaxy S20 class and later), Nintendo Switch / Switch 2.

---

## 1. Visual Identity Statement

**Visual rule:** *Hand-pixeled arcade charm everywhere, except where it touches a bullet: bullets always win.*

The game is a 1941-style arcade chronicle. Planes and worlds are lovingly hand-drawn and exaggerated, in the tradition of 1941: Counter Attack, Metal Slug, and Ganryu. Each era layers a new palette over that style (olive/sepia, then chrome/orange, then neon cyan, then white/magenta plasma). Everything that is not a bullet gives way to the bullets.

### Supporting principles

**1. Caricature, not replica: planes are nameable and chunky.** *(Serves Four Planes, Four Games and History Accelerates.)*
Each plane starts as a recognizable WW2 airframe, drawn with oversized engines, cockpits, and punchy shapes in the Metal Slug "TV-show" spirit. Each era bolts future tech onto the same exaggerated base. The four planes must stay distinct from each other in silhouette. This refines the original "silhouettes stay 1941" principle: the caricatured shape is what stays constant.
*Test: when a plane design is ambiguous, choose the version where you can still name the base airframe at thumbnail size in the 2100 era, and where it can't be mistaken for another player's plane.*

**2. Rich world, quiet lanes: environments carry the detail, bullets carry the contrast.** *(Serves Readable Chaos.)*
Backgrounds get full Metal Slug/Ganryu richness: texture, props, and incidental animation. That richness lives in a reduced-contrast, reduced-saturation value band, and it never uses the bullet hues or the dark outline. The center play lane stays calmer than the edges. Background detail is allowed up to the point where an enemy bullet stops reading in a grayscale screenshot, and no further.
*Test: when background detail and bullet clarity compete, simplify the background (lower its contrast, merge its shapes) until every bullet reads in grayscale. Never dim or alter the bullet.*

**3. Time shows in the palette and the bullets first.** *(Serves History Accelerates, bounded by Readable Chaos.)*
Era change is carried by the palette layer, enemy design, and bullet language before it is carried by glow or particles. Later eras earn more effects, but effects never sit on top of enemy bullets. Enemy-bullet contrast rules stay constant across all eras so the player's reading skill transfers.
*Test: when an era needs to feel more advanced, change the palette, shapes, or bullet pattern first. Add glow or particles only if they stay off the bullet layer.*

### What this rules out
- Faithful, historically accurate WW2 plane models, and sleek realistic sci-fi redesigns that make the base airframe unnameable.
- Detailed backgrounds that reuse bullet colors, the dark bullet outline, or high-contrast small round shapes.
- Effects, glow, or particles that overlap or obscure enemy bullets, however spectacular.
- Non-pixel or mixed-style assets (smooth vector, 3D renders, filtered scaling) and non-integer scaling.
- Era palettes that change enemy-bullet contrast or color rules.

---

## 2. Mood & Atmosphere

**Governing rule:** Mood lives in backgrounds, palette, and non-bullet effects. Enemy bullets keep the constant cool-with-dark-outline treatment in every state. Mood never dims, tints, or overlays the bullet layer (Section 1, principles 2 and 3). Non-play states (title, select, tally, game over) are free to be expressive because no bullets are on screen. They must still be visually distinct from each other and from gameplay.

**Flash rule:** *Particles, not flashes.* High-energy moments (boss entry, part kills, explosions, chain milestones, era transitions) are carried by particles, debris, and shockwave rings, never by screen flashes. **Critical Break is the only event that may flash the screen**, which keeps it unique and readable as the game's payoff. A "Reduce flashing" accessibility option replaces the Critical Break flash with a particle burst.

### State Mood Table

| State | Primary emotion | Lighting | Atmosphere | Energy | Carrying element |
|---|---|---|---|---|---|
| **Title / attract** | Proud nostalgic anticipation ("the cabinet is calling you") | Warm sepia dusk, medium-high contrast, low sun behind the logo | Heroic, gilded, dusty, theatrical | Medium, building | Bilingual logo with **Bengali and English at equal visual weight**, in warm gold on a painted sunset, with all four planes in slow formation flyby. Attract mode cycles through the era palettes. |
| **Plane select** | Confident choice, "pick your ace" | Neutral warm hangar, soft top light, low contrast, a spotlit slot per plane | Intimate, workshop, tactile, orderly | Low-medium | Planes on hangar-floor pedestals in the Metal Slug "roster" idiom, with idle animation (propeller spin, pilot wave). The selected plane gets a warm rim light. |
| **Stage 1: 1941** | Plucky, open-air adventure; the sense of a classic you already know | Clear late-morning sun, warm olive/sepia, mid contrast, long soft cloud shadows | Sunlit, pastoral, painterly, nostalgic, brisk | Medium, the lightest tempo, a teaching pace | Rolling terrain, ocean and coastline with wartime props (flak puffs, ships, farmland), drifting cloud banks. |
| **Stage 2: 1970s** | Tense, cool-headed Cold War pressure | Hard overcast afternoon, chrome-and-orange, high-contrast steel sky with a sodium-orange horizon | Industrial, metallic, tense, hazy, concrete | Medium-high | Radar dishes, missile silos, and runway grids with orange warning-light accents, kept in the background value band. Smoke trails and exhaust haze sit below the bullet layer. |
| **Stage 3: 2030s** | Cold, clinical, surveilled unease | Night, neon cyan over deep blue-black, low ambient and high local contrast (the world is dark and pools of light are bright) | Synthetic, sleek, wet, humming, electric | High | A neon city grid below with rain streaks and scanline drones. Light pools stay desaturated and low-value near the center lane. |
| **Stage 4: 2100+** | Dreamlike vertigo, reality coming apart | No fixed sun. Pale white-magenta void with an unstable light source and a slow brightness pulse (gradual, never a flash). High value contrast, kept in the background band. | Ethereal, fractured, floating, unstable, uncanny | Highest | Floating shards of earlier eras (a 1941 hangar, a radar dish) drifting in a magenta-white sky. Rewinding background elements echo the time-warp bullets. |
| **Boss encounter** | Dread-to-focus, "now it's personal" | Wave palette shifts one step darker and warmer-contrasted, with a vignette that eases in and pulls the eye inward. The sky stays era-colored. | Looming, claustrophobic, weighty, charged | High, sustained | The background scroll slows or stops, and the boss's silhouette dominates the upper third. On entry, a debris/dust particle sweep plays instead of a flash. The boss HP bar is the primary UI accent. |
| **Critical Break** | Savage triumph, the payoff moment | **A single-frame white flash** (the only screen flash in the game), then a brief (~0.5 s) high-contrast warm burst. The background desaturates toward the era's brightest tone. | Explosive, euphoric, sharp, victorious | Peak | The flash, a shockwave ring, and a heavy particle burst on the boss, plus bilingual "CRITICAL BREAK" text. All effects except the flash frame stay on the boss and background layers, never over enemy bullets. |
| **Stage tally** | Satisfied reflection, "look what I did" | Soft warm light, low contrast, calm. The era's palette in muted form. | Calm, ceremonial, tallying, restful | Low | The final boss wreckage fading into a sunset or dawn gradient. Bilingual score rows reveal one at a time. The max-chain number is the hero element. |
| **Game over / continue** | Sober, motivating regret ("I know where I went wrong") | Cold desaturated dusk, low contrast, a single warm light source (the continue prompt) | Quiet, hollow, still, brief | Very low | The wreckage of the player's plane smoking against a desaturated sky. A bilingual continue countdown glows in warm tones as the only focal point. Restart stays instant, and the mood must not slow the retry loop. |

### Notes

- **Distinctness check:** The states separate along these axes. Stages 1 and 2 differ in light source and value (soft sun against hard steel). Stage 3 is dark where the others are bright. Stage 4 has no stable light. Title is warm gold. Plane select is neutral and indoor. Tally is calm and warm. Game over is cold and quiet. Boss and Critical Break are intensity shifts, not new palettes.
- **Era-to-era arc:** The mood trajectory is pastoral, then industrial, then synthetic, then unreal. This supports the History Accelerates pillar without relying on glow first.
- **Boss shift rule:** The boss mood is a darkening and vignette of the current era, not a new palette. This keeps the bullet-reading contrast rule constant.
- **Co-op variant:** Moods are unchanged in co-op. Plane select shows multiple pedestals with each player's ring color as the rim light. In gameplay, other players' shots stay at reduced opacity per the concept risk mitigation, and no extra atmospheric effects are added to compensate for the busier screen. The Team Chain Bonus can add a subtle warm pulse to the boss background, never over bullets.
- **Bilingual:** Bengali and English carry **equal visual weight** on the title and on all bilingual screens. Mood treatments such as gold gradients and glow must be tested against Bengali's matras and connected letterforms, so keep text outlines at a thickness that holds at 360×640.
- **Grayscale gate:** Every wave and boss background must pass the grayscale screenshot test with enemy bullets fully readable before its mood treatment is approved.
- *Added 2026-11-03 (wave 3b, audio.md, parallax-and-environment.md):* Audio follows this State Mood Table (music states and era identity in `design/gdd/audio.md` Visual/Audio). The grayscale gate is run as the procedure in `design/gdd/parallax-and-environment.md` (zone caps EDGE / SHOULDER / CORE, luma 16 to 128, lintable checks).

---

## 3. Shape Language

**Governing idea:** *Chunky and nameable for friends, sharp and cool for threats, plain for the world.* Shape is the second reading channel after color. It must survive the grayscale test (Section 1, principle 2). Everything below follows from "bullets always win" (Identity Statement) and serves **Readable Chaos**, with **Four Planes, Four Games** and **History Accelerates** named where they apply.

### 3.1 Player plane silhouettes
*(Identity principle 1; pillars: Four Planes, Four Games)*

Planes are the largest friendly shapes and use the roundest, widest forms on screen. Proportions follow Metal Slug "TV-show" caricature: oversized engine, cockpit and nose, and short wings. Each plane has one exaggerated trait, which must still read at 1x (the actual pixel size).

| Plane | Sprite (W x H px) | Caricatures | Silhouette trait | Hints at kit |
|---|---|---|---|---|
| Sentry | 45 x 42 | P-38 Lightning | Twin tail booms joined by a central pod | The twin booms read as turret mounts and drone bays |
| Breaker | 42 x 45 | Supermarine Spitfire | Elliptical wing and a long, oversized nose | The nose reads as a battering ram |
| Lancer | 48 x 39 | Hawker Hurricane | Broad, thick, wide-span wings, a humped canopy, and a spear-thin forward spine | The spine points forward like a lance, ready for the laser |
| Leech | 39 x 45 | F4U Corsair | Inverted gull-wing kink and a huge cowled engine | The bent wing reads as claws or latches |

> **Airframe note:** Lancer caricatures the Hawker Hurricane, which flew in the defence of Bengal in 1942–43. The A6M Zero was rejected as a hero airframe for a Bengali game, because Japan bombed Chittagong and Calcutta in that period.

- **Size:** keep the long axis between 39 and 48 px, about 11-13% of canvas width.
- **Distinctness check:** all four are different at 1x in solid black. Sentry is a double-prong, Breaker a long teardrop, Lancer a flat wide "T" with a hump, and Leech a "W" with a fat head.
- **Era bolt-ons** add small outward shapes (pods, fins, intakes) and stay inside the base envelope plus about 6 px. They never change the core silhouette.

### 3.2 Enemy shape grammar
Enemies are drawn **smaller than players** (except bosses) and **hard-edged and darker-valued**, with the era-specific enemy shape below. They carry a **dark outline**. Players get a lighter, warmer-value interior and a **thinner, colored (non-black) outline**. This keeps enemies from ever being mistaken for friendly planes, including in a 4P screen.

| Era | Enemy grammar | Feeling |
|---|---|---|
| 1941 | Round and riveted: blunt noses, circular cowls, rounded bomber bellies | Familiar, almost cute |
| 1970s | Angular delta: swept triangles and chisel noses | Cold and fast |
| 2030s | Faceted, hex-based: drone bodies built from hexagons and discs | Clinical and unsympathetic |
| 2100+ | Fractured and crystalline: broken symmetry, floating shards, offset halves | Unstable and uncanny |

Each era's enemies show a new shape logic. They are not reskins (pillar: **History Accelerates**).

### 3.3 Bullet shape grammar
*(Pillar: Readable Chaos)*

Enemy-bullet vocabulary is **fixed across all eras**, so reading skill transfers. All have a dark outline and a cool fill.

| Shape | Meaning | Typical size |
|---|---|---|
| Round (orb) | Standard aimed or spread shot | 8-9 px |
| Rice (elongated) | Fast, directional stream | 4 x 9 px |
| Needle | Very fast or sniping | 3 x 12 px |
| Ring (hollow) | Slow, large, sweeping hazard | 14-18 px |

Eras change the **pattern** (aimed spreads, locks, time-warp rewinds), not the shapes. Bullet shapes are **reserved**.

**Not allowed for environment, enemy art or effects:**
- small, high-contrast circles and rice-shaped dashes with a dark outline
- thin, fast-looking needle lines
- hollow rings of 14-18 px (shockwave rings must be larger than 36 px and must not use the dark outline)

Player shots use a separate vocabulary: **warm** and **long, rounded streaks and diamonds**. They never use orb, rice or ring shapes.

### 3.4 Environment geometry and the quiet lane
Environment shapes are **large, soft and low-contrast**. They are never small and round.

| Era | Geometry |
|---|---|
| 1941 | Organic and rolling: hills, clouds, coastlines, farm patches |
| 1970s | Rectilinear: runway grids, silos, radar discs (large only) |
| 2030s | Orthogonal city grid with thin lines and large light pools |
| 2100+ | Floating angular shards that echo the fractured enemy language, at lower contrast |

**Quiet lane rule, in shape terms:** within the central lane (about the middle 60% of width), background shapes are **at least 24 px across and without a dark outline**. Fine detail (windows, rivets, small props) lives in the outer 20% edges. Rain streaks and scanlines are allowed only if they are thin (1 px wide), long and low-contrast. They must not resemble needles.

### 3.5 UI shape grammar
*(Pillar: Every Hit Counts)*

The HUD is a **distinct language from the world**. It uses **rectilinear, plated, flat panels with small corner chamfers**, a single constant style across eras (only the palette tint changes). It is also distinct from bullet shapes: no orbs, rice or rings in UI chrome. The hit counter and chain-window bar are the only large UI shapes.

**Bengali + Latin:** text containers have a flat top and bottom, with **at least 4 px headroom above** the text line so the Bengali matra (headline bar) and ascenders are not clipped. Use a rounded, even-stroke pixel face for both scripts at equal weight. Bengali letterforms are rounded and connected, so avoid decorative shapes that fight the matra. Do not use ornamental underlines.

*Added 2026-11-03 (wave 4, touch-controls.md):* touch button plates (Hold, Fire, Drone, Bomb, Pause) follow the same chamfered rectilinear grammar: Cabinet Char fill, `#5A5148` edge, Cream glyph, integer scale, pressed state = Cream fill plus a 1 px step down. They live in the touch strip below the canvas, never over it.

### 3.6 Hero vs supporting shapes
**Hierarchy (what the eye reads first):**
1. **Hero:** enemy bullets, with the player's hitbox ring and hitbox. Both are the smallest and highest-contrast.
2. **Primary:** player plane and boss silhouette, the largest, most solid shapes.
3. **Secondary:** enemies, player shots (reduced for other players in co-op (amended 2026-11-03, bullet-manager.md V3 / player-plane.md V6: other players' shots 100 / 75 / 50% by player count; drones always 100%)), and the hit counter.
4. **Recede:** HUD chrome, backgrounds, debris and particles.

*Test:* squint at a screenshot and cover the color. The bullets, then the planes, must still stand out.

**Emotional read:** round and chunky means friendly and heroic (players and 1941). Sharp and angular means threat and cold pressure. Fractured means vertigo. Soft, large environment shapes signal safety and leave space for the bullets to carry the tension.

---

## 4. Color System

**Governing idea:** *Warm is ours, cool is theirs, and everything else is quiet.* Warm hues (tracer fire, engine glow, sun) belong to players and rewards. Cool hues (cold metal, machines, the void) belong to threats. This split holds in every era, so a bullet's threat reads from hue first and value second. Color is the third reading channel after shape (Section 3) and value (grayscale test). Every critical meaning also has a non-color backup.

### 4.1 Global palette

| Name | Hex | Role and why |
|---|---|---|
| Tracer Orange | `#FF8A1F` | Player offense and bombs. Tracer fire and exhaust read as "mine" to anyone who knows WW2 imagery. |
| Ember Gold | `#FFC93C` | Reward, score and chain. Gold is the arcade shorthand for value, and it is the warmest, brightest UI color. |
| Void Indigo | `#4A5CFF` | Enemy bullets and danger. It is cold and mechanical, and it sits well away from every background hue (4.3). |
| Ink | `#0B0B2A` | Enemy-bullet and enemy-body outline. It is blue-black, so it reads as "dark" without being a flat black. |
| Cream | `#F4EBD6` | UI text and neutral highlights. It is the paper of the arcade cabinet. |
| Cabinet Char | `#1E1B18` | UI panel base. It is warm and does not match any sky. |
| Alarm Red | `#E03A3E` | Boss HP, life lost, and critical UI only. It never appears in the play field. It is the **plate-edge, bar-fill, end-cap and glyph-fill** red. It is **never a text fill** (3.95:1 on Char, below 4.5:1). |
| Alarm Flare | `#F2494D` | The **text-only** Alarm Red: failure and danger words on Cabinet Char (or the boss-bar track `#2A0F12`). Same hue as Alarm Red (358.6°), lifted in value for legibility. Never a fill, edge, bar or glyph. Never in the play field. |

**Alarm Flare (authored 2026-11-03, art-director).** `#E03A3E` stays the plate-edge and glyph-fill red everywhere it is used today; nothing about it changes. `#F2494D` is a second token that exists only so a failure or danger *word* can be red.

| Measure | Alarm Red `#E03A3E` | Alarm Flare `#F2494D` |
|---|---|---|
| Relative luminance | 0.1922 | 0.2418 |
| Contrast on Cabinet Char `#1E1B18` (L 0.01126) | **3.95:1** (fails 4.5) | **4.76:1** (passes 4.5, margin 0.26) |
| Contrast on boss-bar track `#2A0F12` (L 0.00877) | 4.12:1 | 4.97:1 |
| Hue (HSL) | 358.6° | 358.6° (unchanged; R-G-B ordering and the 4:166 / 4:169 G-B gap are the same) |
| HSV saturation / value | 0.74 / 0.88 | 0.70 / 0.95 |
| Rec.709 gamma luma (0-255) | 93.6 | 109.2 |

*Why this value:* the hue is held exactly and only value is raised, with saturation kept high, so it stays a signal red and does not drift to salmon, pink (hue 340-350°) or orange (hue above 10°). The next step down, `#EE4448`, measures 4.53:1, which leaves no margin for renderer error, so `#F2494D` is the lightest-touch value with a usable margin. A lighter step such as `#FF6366` (5.9:1) was rejected as visibly coral.

**Use rules (Alarm Flare).**
1. Text fill only, with the 1 px `#14110E` outline, at tier S or larger (12 px Latin / 17 px Bengali minimum), on Cabinet Char or `#2A0F12` plates only.
2. It colours the **headline status words** of a failure, error or danger state (one line per screen at most). The explanatory sentence stays Cream. Every failure still carries the Alarm Red `#E03A3E` plate edge and/or error glyph, so the cue is words + glyph/edge + colour, never colour alone.
3. Not for body text, not for numerals in the HUD strip, not on any slot column, not beside a P1 pip or ring (see the colour-vision note), and never in the play field.
4. When `hud_contrast` is HIGH it renders as **Cream** (the HIGH palette targets 7:1 and Flare is 4.76:1). The edge and glyph stay Alarm Red.
5. Not tinted by the era (7.8), same as Alarm Red.
6. Because it is under 7:1, Flare is allowed only where the same words are repeated by a Cream sentence on that screen (the Flare line is a label, not the sole carrier). `design/accessibility-requirements.md` row "Contrast of plated UI at least 7:1 on menus" needs the matching exception (see the art-director report).

**Colour-vision note (LUMA_SPREAD palette, 4.4).** Flare luma 109.2 against the LUMA_SPREAD slot luma 122.5 / 231.2 / 169.0 / 199.8: gaps 13.3 (P1), 122.0 (P2), 59.8 (P3), 90.6 (P4). Against Cream 235.5 the gap is 126.3, against Gold 202.3 it is 93.1, Amber 180.1 it is 70.9 and Tracer Orange 155.1 it is 45.9, so Flare reads as a distinct, darker tone from every other text colour in greyscale. **Caveat:** the P1 gap (13.3) is below the 30.9 slot minimum and the hue of P1 vermillion `#FF5A36` is only about 12° from Flare. This is acceptable only because Flare is text and P1 is a pip, ring or plane, and rule 3 keeps them apart. In greyscale Flare looks like mid-value text, not an alarm, so meaning must come from the words and the glyph (rule 2). Protanopia dims reds, so the contrast on Char under a protan simulation is expected to fall below 4.76:1; it has not been measured.

*All ratios above are computed from the hex values (WCAG relative luminance, sRGB), not measured on rendered output. Re-measure against the real renderer, with the real font and outline, in the font spike, and under protan/deutan simulation.*

*Added 2026-11-03 (wave 3a, hud.md):* HUD proposes a **bright Gold `#FFE27A`** for the top chain-milestone edge (2 px). Pending art-director acceptance; until accepted it is not part of the global palette.

### 4.2 Value rule (the constant across all eras)

All **backgrounds sit in luma 16-128 (of 255)**, measured as Rec.709 on gamma values (`0.2126R + 0.7152G + 0.0722B`). Edge-zone neon accents (outer 20% only) may reach **160**.

Every enemy bullet is built from three layers:
- **Outline:** luma ≤ 20.
- **Fill:** mid value.
- **Core:** a 2-3 px near-white center, luma ≥ 217.

On dark backgrounds the core and fill carry the bullet (core minus background ≥ 89). On pale backgrounds the outline carries it (background minus outline ≥ 108). The bands are chosen so one of these always holds. Halos and glow are banned on bullets, because they would break the "effects never sit on bullets" rule.

*Verified 2026-10-28:* all era background hexes below measure luma 8-128. The 2030s edge peak `#3FB5BC` measures 156. Bullet cores measure 231-255 and the outline 13.

### 4.3 Enemy bullets

Fill hue is locked to **225-265°** (blue to indigo). This keeps bullets off the 2030s cyan (175-200°) and the 2100 magenta (≥300°), and it leaves a gap of at least 25° on each side. Cyan, teal, violet-pink and white are never used as bullet fills.

| Shape | Fill | Core | Outline |
|---|---|---|---|
| Orb | `#4A5CFF` | `#E8EEFF` | `#0B0B2A` |
| Rice | `#6A6CFF` | `#EEF0FF` | `#0B0B2A` |
| Needle | `#9AA8FF` | `#FFFFFF` | `#0B0B2A` |
| Ring (hollow) | `#5A4CFF` | `#E8E4FF` (inner edge) | `#0B0B2A` on both edges |

- **Cyan 2030s:** the dark outline merges with the blue-black night, so the core and fill do the work. The core is far brighter than any cyan pool, and the indigo hue sits apart from the cyan.
- **White 2100:** the background is capped at luma 128, a dusky lavender-white, never paper white. The outline reads at ≥ 108 contrast, and the indigo is a different hue from the magenta.
- **Tritan check:** the white core is the backup, because blue and magenta converge for protan viewers.

### 4.4 Player shots and co-op identity

**Shots:** core `#FFF2B0`, fill `#FFB82E`, edge `#FF7A1A`, with no dark outline. They are rounded streaks and diamonds (Section 3.3). Other players' shots draw at 50% opacity. *Superseded (amended 2026-11-03, bullet-manager.md V3 / coop-and-team-chain.md): other players' shot opacity steps by player count, 100 / 75 / 50%.*

| Player | Color | Ring pattern | Mark |
|---|---|---|---|
| P1 | Vermillion `#FF5A36` | Solid | 1 pip |
| P2 | Yellow `#F5E02E` | Dashed | 2 pips |
| P3 | Green `#2FD27A` | Dotted | 3 pips |
| P4 | Pink `#FF8AD8` | Double ring | 4 pips |

- The hitbox itself is a white 1 px dot, and the ring is 1 px in the player color.
- The plane's 1 px outline accent uses the same hex.
- All four have hues outside 225-265° (the nearest, P3 green, is at ~150°), so none can be mistaken for a bullet.
- Measured luma: P1 122, P2 216, P3 169, P4 169. P1 and P2 separate by brightness, but **P3 and P4 have equal luma**. For them the ring pattern and pip count are the only non-hue separation, so both are mandatory.

### 4.5 Era palettes

| Era | Sky | Far | Mid | Ground | Accent (muted) | Shadow | Enemy body / outline |
|---|---|---|---|---|---|---|---|
| 1941 olive/sepia | `#6E8264` | `#5A6B4E` | `#7A6A48` | `#4C5A3C` | `#8A6F4A` | `#2E3626` | `#3B4228` / `#14180F` |
| 1970s chrome/orange | `#6C7A86` | `#48525C` | `#787E84` | `#5C5F63` | `#A85A22` | `#2A2F36` | `#3A4048` / `#0F1115` |
| 2030s neon night | `#0F1A2E` | `#16304A` | `#1F4660` | `#0A1220` | `#2A8A90` (edge peak `#3FB5BC`) | `#05080F` | `#34425A` (rim `#6F86AA`) / `#070B16` |
| 2100+ plasma | `#80708C` | `#4A3A56` | `#7D6A8A` | `#877C91` (pulse peak) | `#A8348F` | `#2A2036` | `#2A2036` / `#0B0614` |

Backgrounds use ≤ 55% saturation, and their warm accents stay far below the 85%+ saturation of player shots. The 2100 pulse stays within the band.

*Added 2026-11-03 (wave 3b, parallax-and-environment.md):* the 1970s Accent `#A85A22` measures about 80 % HSV saturation, above the 55 % rule. Parallax applies a **warm rule**: the accent is used only at luma 105 or less, in the edge zone only, and under 2 % of the frame. Pending art-director confirmation.

### 4.6 Semantic colors

| Meaning | Color | Why, and non-color backup |
|---|---|---|
| Danger | Void Indigo bullets with Ink outline | Cold and mechanical means threat. The shape grammar is reserved (Section 3.3). |
| Reward, score, chain | Ember Gold `#FFC93C` | Gold means value. Chain items are diamonds with a `+` glyph, and the counter uses a plated frame. |
| Critical Break | White flash `#FFFFFF`, then `#FFF4D0` / `#FFB347` burst | The only flash in the game (Section 2), which makes it a payoff. It is accompanied by a bilingual banner and a unique sound. |
| Pickup | Cream `#F4EBD6` body, `#3A2A14` outline, glyph icon | It is neutral so it never competes with the bullet or player hues. The glyph carries the meaning. |
| Bomb | Tracer Orange with a "B" glyph | It is player-owned, so it is warm. |
| Boss HP | Alarm Red `#E03A3E` on `#2A0F12` | It is the only large red on screen. Phase tick marks and a numeric percentage are the backup. |
| Warning | Amber `#FFB000` with black diagonal stripes | The stripes follow the hazard-sign convention. It is a UI banner only, never in the play field, and it comes with a siren sound and an icon. |

*Added 2026-11-03 (powerups-and-drops.md, bombs.md):* the `+` diamond stays reserved for the CHAIN item; the GEM (cancel item) is a plain 7 px gold diamond. Tracer Orange `#FF8A1F` is confirmed for all bomb FX (Lance Sweep column, Barb Burst hooks and bursts, shockwave ring).

*Added 2026-11-03 (wave 3b, vfx-and-screen-feedback.md):* VFX uses the alert **Amber `#FFB000`** as its AMBER colour role for the flak-fuse spark (a 3 px tell in the play field, not a banner), as the Pattern library also asks. Pending art-director confirmation (VFX Open Question 8).

### 4.7 UI palette and text

The UI diverges from the world: a **warm neutral palette** (Cabinet Char, `#5A5148` edges, Cream text), constant across eras, with only a 20% era tint on frames. The HUD stays distinct from the world's cool/warm split.

| Element | Spec |
|---|---|
| Text fill | Cream `#F4EBD6` (Gold only for score and chain; Alarm Flare `#F2494D` only for failure/danger headline words, 4.1) |
| Outline | 1 px `#14110E` on all 8 sides, never thinner |
| Minimum size | Latin 12 px cap height; Bengali 17 px, so the matra and conjuncts keep their clearance |
| Bilingual | Same color, same weight, same outline in both scripts |

### 4.8 Colorblind safety

| Risky pair | Failing type | Backup cue |
|---|---|---|
| P1 vermillion and P3 green | Deutan / protan | Ring pattern (solid vs dotted), pip count, luma gap (122 vs 169) |
| P3 green and P4 pink | Deutan / protan | Ring pattern (dotted vs double), pip count (luma is equal, so no brightness backup) |
| P2 yellow and P4 pink | Tritan | Dashed vs double ring, pips |
| P4 pink and enemy-bullet blue/violet | Protan | Hue lock plus white core and dark outline; pink is never a bullet fill |
| Bullet blue and 2100 magenta | Protan | Outline and core value; background luma capped at 128 |
| Player shot orange and P1 vermillion | Protan / deutan | Shot shape (streak) vs ring shape; shots have no outline |
| Gold reward and P2 yellow | All | Diamond-plus shape vs annulus; context differs |
| Alarm Red boss HP and P1 vermillion | Deutan | Position (top bar), ticks, number |
| Pickup glyphs and bomb orange | Deutan | Glyph shape |

An option to remap player colors is recommended, but the ring patterns stay on regardless.

---

## 5. Character Design Direction

**Governing idea:** *Friends are warm, round and bright. Threats are cool, hard and dark. Pilots are the only place we get to be human.* Characters inherit Sections 3 and 4: planes are the roundest, widest shapes; enemies are smaller, darker, hard-edged, with an Ink outline; bullets always win. (Pillars: Readable Chaos, Four Planes, Four Games, History Accelerates.)

### 5.1 Player archetype
Each plane is a **caricatured WW2 airframe with a personality**: oversized engine, cockpit and nose, short wings, and a visible pilot head in the canopy (5-6 px, one skin/helmet color). The pilot head tells the player the plane is a character, not a machine. All four share one shading rule: warm light value interior, hand-pixeled 2-3 step ramp, light from top-left, and a thin 1 px outline in the P-color accent (4.4), never black.

### 5.2 Telling things apart at a glance

| Type | Value | Outline | Shape | Motion cue | Never |
|---|---|---|---|---|---|
| Player plane | Lightest, warm | 1 px P-color | Round, chunky, 39-48 px | Smooth bank, propeller/engine glow | Hard angles on the silhouette |
| Allied drone/turret | Light, warm | 1 px P-color | Small solid disc or capsule | Orbits or parks, tied to its plane by a short tether or return path | Black outline, orb/rice/ring shapes |
| Enemy | Darker, cool | 1-2 px Ink (era outline, 4.5) | Era grammar (3.2) | Faces down, jittery or mechanical | Warm interior hues, P-colors |
| Boss part | Dark body, bright damage cue | 2 px Ink | Era hull plus large parts | Slow, weighty | Same value as the core |
| Pickups (NPC-like) | Cream | `#3A2A14` | Glyph icon, 15-18 px | Gentle bob | Enemy hues |

Redundancy test: in grayscale, with colors removed, the lightest large rounded shape is a player. Anything dark with an Ink outline is a threat.

### 5.3 Expression and pose targets

| Subject | Style | Target |
|---|---|---|
| Planes | Exaggerated-stiff | Strong silhouette poses, 3-4 px squash on bank, no realism wobble |
| Popcorn enemies | Stiff, mechanical | Fixed poses, rotate or swap 1-2 frames |
| Mid/large enemies | Semi-expressive | Visible mechanical "tell" (flap, open hatch, charge glow) 6-12 frames before firing. Default tell lead 12 ticks *(added 2026-11-03, enemy-and-ai.md)* |
| Bosses | Weighty, theatrical | Part-level animation, slow, with readable windup |
| Pilots | Fully expressive, Metal Slug caricature | Big head, big eyes, one clear emotion per portrait |

### 5.4 LOD philosophy
The game camera is a fixed 360x640 canvas, integer-scaled where the screen allows (8.1), so there is **one LOD: the 1x sprite**. Detail is judged at 1x only.
- Plane sprites: a maximum of 3 value steps per material, no 1 px noise, one detail cluster (cockpit/nose) allowed per plane.
- Enemies: silhouette first. Details under 2 px are allowed only on large enemies and bosses.
- Anything smaller than 9 px that is not a bullet must be a solid blob (debris, sparks).
- Portraits are the only high-detail asset (5.9), used at 1x on non-play screens.

### 5.5 Plane evolution per era
Each cell is a **bolt-on swap layer** (small separate sprite, at most about 6 px beyond the base envelope) plus a palette layer. The base airframe sprite never changes.

| Plane | 1941 | 1970s | 2030s | 2100+ |
|---|---|---|---|---|
| Sentry (45x42) | Plain twin booms, fixed gun nose | Missile rails on boom tips | Hex drone bays under booms | Floating split pod, offset halves |
| Breaker (42x45) | Wooden-prop ram nose | Jet-intake cowl, nose spike | Armored ram plate | Crystal prow, light echo trail |
| Lancer (48x39) | Fixed cannons, spear spine | Pylon fuel tanks on wings | Lens emitter at spine tip | Free-floating lance tip |
| Leech (39x45) | Bent-wing claws, big cowl | Hook pylons under gull kink | Grapple clamps | Tendril-like latch arms |

Rules: one bolt-on per wing or nose position (max 2 sprites per era per plane), same palette mapping across planes in an era, P-color outline unchanged. Cost: 4 bases + 12 bolt-on sets, with palette swaps for the rest.

*Added 2026-11-03 (wave 3b, era-shift-and-plane-evolution.md):* 1941 hardware is part of the base art; the first bolt-on set is the 1970s one (Era shift Rule 7). Plane evolution is visual only: no kit or bomb number changes by era.

### 5.6 Drone and turret rules

| Plane | Unit | Size | Look | Distinction |
|---|---|---|---|---|
| Sentry | Turret drone | 12x12 px | Warm disc with a short barrel stub, P-color ring | Stationary state adds a base plate (reads as emplaced) |
| Breaker | Eraser drone | 16x10 px | Wedge/shield capsule, forward-pointing, P-color outline | A pulse arc in front (not a ring shape) shows the erase zone |
| Leech | Latch drone | 10x10 px | Hook-claw disc | Draws a 1 px P-color tether line to its target when latched |
| Lancer | None | n/a | Laser carries the kit (warm beam, no outline) | n/a |

Must-not rules: no orb/rice/needle/ring shapes (3.3), no cool hues, no Ink outline, no circular silhouette under 12 px that could pass for an enemy bullet. They keep a thin P-color outline and a light warm interior, and render at the same opacity as their owner (50% for other players' drones in co-op). *Superseded (amended 2026-11-03, player-plane.md V6 / coop-and-team-chain.md): drones always draw at 100%.*

*Added 2026-11-03 (plane-kits-lancer-leech.md):* Lancer drone = **lens-pod** (parks in place and fires a 6 px beam); Leech drone latches with a tether. The Lancer kit meter shows a notch at **40 %** (the minimum to start the laser). Laser cue on the plane: nose lens glow (3x3 px Cream) while the laser is On, a 2x2 px afterglow for the 12 grace ticks; the plane does **not** blink for laser invulnerability.

*Added 2026-11-03 (wave 4, plane-kits-sentry-breaker.md):* the Breaker row's "pulse arc in front" is superseded by the GDD: the erase zone is shown by **four corner brackets** (L-shaped, 5x5 px, 1 px) at the corners of the 52x52 box around the drone, marking the true 26 px radius circle (a front arc would misreport a full-circle zone); no ring. SPENT drones show two diagonal brackets at 40 % and a 60 % outline. Sentry: emplaced turrets show a 14x3 px base plate, the barrel snaps to 8 facings, and placement shows 8 tick marks (4x1 px, not a ring) at the 160 px range. Pending art-director confirmation (Sentry/Breaker Open Question 6).

### 5.7 Enemy size classes (360x640)

| Class | Size (px) | Outline | HP read | Examples |
|---|---|---|---|---|
| Popcorn | 18-27 | 1 px Ink | Dies in 1-3 hits, no damage state | Prop fighters, scouts, hex drones |
| Mid | 36-60 | 1-2 px Ink | 1 damage state (cracked, smoking) | Gunboats, jets, turret platforms |
| Large | 72-120 | 2 px Ink | 2 damage states | Bombers, cruisers, carriers (non-boss) |
| Boss | 144-270 wide | 2 px Ink | Per-part states (5.8) | Fortress, Carrier, Plasma Ring |

Every class stays visibly smaller than or cut from the player's value range (darker), except bosses, which are bigger than any player (Primary tier, 3.6).

*Added 2026-11-03 (enemy-and-ai.md):*
- **Carrier cue:** an enemy that will drop an item has a cream rim that pulses at 2 Hz (never above 3 Hz). It must stay distinguishable in a grayscale capture.
- **LARGE plating:** an overlay sprite shows the armour plating; when plating ends it falls away over 8 ticks.

*Added 2026-11-03 (powerups-and-drops.md):* item sizes: GEM 7 px, MEDAL 15 px, CHAIN 15 px, POD 17 px, 1UP 17 px; all items draw on layer 6.

### 5.8 Boss design rules
Matches the prototype data model (core plus parts, ARMORED/SHIELDED core rule, hulls NONE/WING_BAR/DELTA/RING).

| Rule | Spec |
|---|---|
| Hull vs parts | Hull is a flat, mid-dark silhouette. Parts sit **above** it with +1 value step and a 2 px Ink outline. |
| Armored core | Plate-bordered core with rivet or panel lines, a **blue-grey dull** fill while armor is up. When all parts are dead, the plating drops and the core shows a bright inner color ("CORE EXPOSED"). |
| Part damage states | 100-66% clean, 66-33% scuffed with 2-3 dark crack pixels, 33-0% smoking (non-bullet gray particles, below bullets). |
| Part death | Part sprite swaps to a burnt stump (dark, no outline glow), plus a debris particle burst. No flash. |
| Critical state | Core below `critical_hp`: a pulsing red-orange crack overlay on the core only (4-6 px lines), slow 2 Hz pulse in value, plus the Alarm Red tick on the HP bar. No screen tint, no full-boss flash. |
| Hit feedback | Sprite-level tint only (5.10). |
| Silhouette | Boss top-down silhouette must dominate the upper third at any phase. |

Era evolution (each boss uses its era grammar from 3.2):

| Boss | Era | Parts | Look |
|---|---|---|---|
| Flying Fortress | 1941 | 2 turrets + 2 engines, armored core | Round riveted bomber, wing-bar hull |
| Jet Carrier | 1970s | 3 orbiting pods + 2 wings | Angular delta hull, chisel nose, orange warning lights |
| Plasma Ring | 2100 | 4 orbiting shields | Fractured ring, offset halves, shield shards that orbit |

The 2030s boss follows the same part rules (hex-built, orbiting drones). Parts get clearer, not busier, in each era: no more than 6 hittable parts, so a 4P chain target is always legible.

*Added 2026-11-03 (boss-and-boss-parts.md):* part kills never flash the screen (the prototype flash is removed); there are no per-part hp bars (one boss bar in the HUD row, §7.4).

### 5.9 Pilot portraits

| Property | Spec |
|---|---|
| Size | 96x96 px (select, tally), 36x36 px (HUD lives/chain corner) |
| Style | Metal Slug caricature, big head, thick 1 px dark-brown outline (non-Ink), warm palette |
| Expression set | Neutral, determined, hurt, victory (4 frames per pilot, 16 total) |
| Frame usage | Neutral at select, determined on boss entry (HUD), hurt on life lost, victory on tally |
| Bilingual | Name plates in Bengali and English at equal weight |

Identity direction: four distinct pilots, each with a **unique head silhouette** (helmet, goggles, scarf, cap) so they read at 36 px. Pilots are Bengali-rooted but never stereotypes: individual names, varied ages and builds, warm dignified faces, and standard flight kit with **at most one cultural accent** (for example a gamcha-check scarf). No costume gags. Their identity comes from personality (confident, cheeky, stoic, scrappy), matching plane kits. Names and backstories are for the narrative director to approve.

### 5.10 Animation targets

| Animation | Frames | FPS | Notes |
|---|---|---|---|
| Plane idle (propeller/engine) | 2-3 | 12 | Looped, propeller blur |
| Bank left / right | 3 each (neutral to half to full) | 12 | Mirrored where the airframe is symmetric, separate for Breaker/Lancer if the hump or nose breaks symmetry |
| Plane hit (hurt/invuln) | Blink, 2 frames | 10 | Sprite visible/hidden, no flash |
| Popcorn | 1-2 | 8 | Wing flap or spin |
| Mid/large | 2-4 idle + 2-4 attack tell | 8-10 | Tell visible before fire |
| Boss parts | 2 idle + 3 damage states + 1 death | n/a | Damage states are sprite swaps |
| Drone | 2 | 10 | Spin or pulse |
| Pilot portrait | 4 static (+ optional 2-frame blink) | n/a | Expression swaps |

**Hit tint (sprite level only):** on a hit, the hit sprite is tinted white `#FFFFFF` at 60% for 2 frames (about 33 ms), applied to that sprite only, never full-screen, never on bullets. For bosses, tint the struck part only. This is not a screen flash and respects the "Reduce flashing" option, which swaps the tint for a 1 px darker outline pulse.

Art-volume budget: 4 plane bases + 12 bolt-ons, about 8 popcorn, 6 mid, 3-4 large, 4 bosses (3 prototypes plus 2030s), 16 portraits. All era variation beyond that is palette layers.

---

## 6. Environment Design Language

**Governing idea:** *The world is a diorama of one place across a century: soft, large, and quiet in the middle, detailed at the edges.* Environments carry the story and the era. They never compete with bullets (Sections 1-4). Every rule below is subordinate to the quiet-lane rule (3.4) and the luma 16-128 band (edge accents up to 160) from 4.2.

### 6.1 Setting, culture and history

**Decision (2026-10-28): "Bengal Continuum".** All four stages are **one continuous place, the Bengal delta, seen at four moments in time.** This gives *History Accelerates* a spatial spine: the player flies over the same river and coast as it changes. The place is also meaningful to the audience: Hurricanes defended Bengal in 1942-43 (the Lancer's airframe note in 3.1).

**Fallback rule:** all landmarks are *regionally flavored but unnamed* (no on-screen place names, no real flags or insignia). If cultural review raises concerns, the same layouts ship as generic terrain with no loss of function. A native-speaker / cultural review of Bengal-region details is advised before landmark designs are locked.

**Tone guardrail:** the war is the backdrop, not the subject. No depiction of civilian suffering, no real atrocity imagery. Hope, resilience and continuity (boats, markets, rivers) carry the history.

**Architecture principle:** buildings are *chunky, readable blocks* (Metal Slug "TV-show" spirit, matching 3.1 caricature). Regional character comes from a small number of **signature shapes**, not from detail: tin and tile pitched roofs, bamboo and thatch huts, riverboats with curved sails, a brick colonial dock, a terracotta-domed mosque or temple silhouette. **Sacred buildings are drawn respectfully as silhouettes only: never enemy structures, never bomb targets, never hit by explosions, and never placed under a boss.**

### 6.2 Per-era setting table

All moods are inherited from Section 2; palettes from 4.5.

| Era | Location | Architecture | Signature props | Weather / time of day |
|---|---|---|---|---|
| 1941 | Delta coast and river mouth; a colonial port town inland | Thatch and tin huts, brick godowns, wooden jetties, a lighthouse | Riverboats and sampans, paddy terraces, palm clusters, anti-aircraft sandbag nests, a convoy ship, flak puffs | Clear late morning, long soft cloud shadows |
| 1970s | The same river, now a dredged channel; the port is an industrial zone | Concrete blocks, silos, radar dishes, runway grids, a cantilever bridge | Cargo cranes, fuel tanks, orange warning lights (edge only), missile silos, power pylons | Hard overcast afternoon, sodium-orange horizon |
| 2030s | The same river as a lit canal inside a dense grid megacity (unnamed) | Stacked towers, elevated rails, rooftop paddy-gardens | Billboard planes, scanline drones, rooftop water tanks, rain-slick roads (thin light lines) | Night, rain |
| 2100+ | No ground. Drifting shards of the three earlier eras | Fractured angular fragments | A floating jetty, a radar dish, a lighthouse, a boat hull, frozen in mid-air | Pale white-magenta void with a slow, gradual brightness pulse |

### 6.3 Texture philosophy

**Chosen: hand-pixeled, limited-palette, authored shading. Not PBR, not smooth stylized or vector.** PBR and smooth styles violate the "no mixed-style assets" rule (Section 1), break integer-scale pixel integrity, and read as a different game from the Capcom/SNK references. Hand-pixeling lets us hard-cap value and saturation per layer and is cheap to palette-swap (production risk, concept §13).

- **Lighting is baked into the pixels.** One light direction per era: top-left in 1941/1970s, ambient plus local pools in 2030s, none (unstable) in 2100. No runtime lighting on environment sprites.
- **Pixel-cluster rules:** no pillow shading. Shade along the light direction, with 3 tones per material maximum in the quiet lane and 4 at the edges. **No noise or single-pixel scatter**; texture is made from deliberate clusters of 2+ pixels. Banding is acceptable; random speckle is not.
- **Outlines:** the dark Ink outline is reserved for enemies and bullets. Environment uses *no outline* in the center lane. Edge props may use a darker same-hue tone of the fill (never Ink, never black).
- **Dithering:** ordered 2x2 or 4x4 only, for sky and haze gradients. **Banned inside the central lane** if it produces a regularly spaced dot grid (it reads as a bullet field); use hard color bands or 2+ px clusters there. Edge zones may dither freely.
- **Palette:** each layer uses only its era's Sky / Far / Mid / Ground / Accent / Shadow colors (4.5), plus at most 2 intermediate ramp steps.

### 6.4 Tile and strip approach

| Content | Method | Reason |
|---|---|---|
| Sky, far terrain | Painted vertical strips, seamless-loop, 360 px wide | Few unique pixels; slow scroll hides repetition. |
| Mid terrain (coast, fields, canals) | **Tileset** (24x24 base tile, autotile edges) plus hand-placed strips for landmarks | Fast to build per wave; fits the Godot TileMap workflow. |
| Landmarks (port, silo, bridge, tower) | Hand-painted unique sprites | They carry the story and the eye anchors. |
| Props | Individual sprites, palette-swappable per era | Supports the palette-layer plus bolt-on production plan. |

Loop height is **at least 1280 px** (2 screens) for the far strip and 1920 px for the mid layer. Integer pixel positions only (no sub-pixel scrolling), to avoid shimmer.

*Added 2026-11-03 (wave 3b, parallax-and-environment.md):* strips are authored **376 px wide** and boss plates **376 x 656** (8 px overscan on every side), so a world-layer shake of up to 8 px never shows an empty edge. Tile chunks use 24 px cells (1,920 px Stage 1, 2,400 px Stage 2).

### 6.5 Parallax layering and the quiet lane

| Layer | Scroll speed (x ground) | Contents | May animate? | Quiet-lane handling |
|---|---|---|---|---|
| L0 Sky | 0.0-0.1 | Gradient, clouds or void | Slow drift only | Low contrast, no shapes under 24 px |
| L1 Far | 0.25 | Distant coastline, skyline, far shards | No | Soft, merged shapes, luma at the dim end of the band |
| L2 Mid | 0.5 | Terrain, river, buildings | Water shimmer, smoke, boats (slow) | Large forms at least 24 px, no outline |
| L3 Near | 1.0 (ground speed) | Roads, jetties, props, ground targets | Props and ground targets | Detail pushed to outer 20% edges; center is open ground, water or roof planes |
| L4 Overhead (optional) | 1.3 | Rare cloud wisps or pylons passing over the ground | Yes | **Outer 20% only; never in the center lane and never above the bullet layer** |

- Four main layers plus one optional overhead layer, never more.
- **Motion rule:** only one layer at a time may carry a visible, fast animation near the center lane.
- Co-op uses the same rules; no extra layers.

*Added 2026-11-03 (wave 3b, parallax-and-environment.md):* layer factors are L0 8 / L1 25 / L2 50 / L3 100 / L4 130 %. Readability zones: EDGE x 0-71 and 288-359, SHOULDER 72-119 and 240-287, CORE 120-239, with edge-density caps 25 / 12 / 6 % and luma-step caps 80 / 48 / 28; no outline, dither or animation in CORE; L4 only in the edge zone. See `design/gdd/parallax-and-environment.md` Rule 15.

### 6.6 Prop density by zone, wave and boss

| Zone | Wave | Boss |
|---|---|---|
| Center lane (about 60% of width) | **Sparse:** large soft forms only, at most 1 landmark in view at a time | **Emptiest:** nearly flat; the scroll slows to a stop, background simplifies |
| Edges (outer 20% each side) | **Dense:** windows, rivets, small props, neon, rooftop detail | Medium-dense; frames the arena |

*Density is inversely proportional to bullet density.* Early waves have more ambient detail; late waves and bosses have less. Open country (paddy, sea) is naturally sparse; urban zones are dense at the edges but use rooftops and canals (large planes) in the lane.

### 6.7 Environmental storytelling (no text)

| Technique | Detail |
|---|---|
| **Same river, four times** | The river mouth stays in roughly the same place. 1941: boats and a wooden jetty. 1970s: dredged channel with cranes. 2030s: a lit canal in a grid. 2100: the riverbed as a floating ribbon among shards. |
| **Landmark echoes** | A lighthouse (1941) reappears as a radar mast (1970s), a beacon tower (2030s), and a drifting fragment (2100). |
| **Wreckage accumulates** | Wave 1 starts clean. Later waves add burned hulls and craters to the ground. The boss arena shows the cost. |
| **People without people** | Life is implied (laundry, boats, lit windows, market awnings). No on-screen casualties. |
| **Pulse of the world** | Ground turrets and AA nests react as you pass (muzzle puffs). City lights go out when a wave begins (2030s). |
| **No text rule** | No signage, slogans or readable script in the play field; 2030s billboards are abstract color blocks. All text is HUD (Section 7). |

Ground targets read as targets by **shape and a darker, flatter, outlined silhouette** (enemy grammar, 3.2), not by glow.

### 6.8 Environment VFX

1. *Particles, not flashes.* The only screen flash is Critical Break (Section 2).
2. VFX never overlap or obscure enemy bullets; they are drawn below them.
3. Shockwave rings are larger than 24 px, have no dark outline, and are not shaped like bullet rings (3.3).
4. Particles are 2+ px clusters (not single-pixel scatter), in the era palette, never in Void Indigo / bullet hues.

| Effect | Look | Era scaling |
|---|---|---|
| Explosions | 3-5 frame cluster burst with a debris sprite fan | 1941: orange-sepia, smoky. 1970s: harder orange, black smoke. 2030s: cyan spark shards. 2100: magenta shard bursts that briefly rewind. |
| Debris | Chunky 2-4 px fragments with gravity and fade | Same in all eras, recolored. |
| Smoke | Soft clustered puffs rising from wrecks and chimneys | Thicker in 1970s; scanline haze in 2030s; drifting dust in 2100. |
| Weather | 1941: cloud shadows, birds. 1970s: haze bands. 2030s: rain streaks (1 px, long, low-contrast). 2100: drifting motes | Rain capped at 40 streaks on screen. |

*Explosion sizes per enemy class (added 2026-11-03, enemy-and-ai.md):* SMALL 20 px over 12 ticks; MEDIUM 40 px over 18 ticks; LARGE 72 px over 36 ticks plus 2 secondary pops. Ground-target explosions draw on layer 2 and leave a scorch decal for 180 ticks.

**Draw-order stack (back to front) — approved 2026-10-28:**
1. Background layers L0-L3 (+ optional L4 at edges)
2. Environment FX (smoke, weather, ground explosions, debris) and boss vignette
3. Ground targets and props that react
4. Enemies and bosses
5. Air explosions and enemy-hit sparks
6. Player shots and drones (other players' shots at 100 / 75 / 50% by player count, drones at 100%; amended 2026-11-03, bullet-manager.md V3 / player-plane.md V6)
7. Player planes
8. **Enemy bullets** (above all world FX and above the player planes, so a friendly sprite never hides a bullet)
9. **Hitbox dots and player rings** (above bullets, so each player's safe zone is always readable)
10. Critical Break flash (single frame; the only element allowed over bullets)
11. UI / HUD

*Added 2026-11-03 (boss-and-boss-parts.md):* boss part explosion 28–36 px; the boss death sequence (180 ticks) is capped at 40 particles.

*Added 2026-11-03 (wave 3a, menus-title-plane-select.md):* Menus draw on a CanvasLayer **above layer 11** (pause, disconnect and all out-of-fight screens).

*Added 2026-11-03 (wave 3b, vfx-and-screen-feedback.md):* effects use `z_index = layer * 10 + sub`. VFX draws in 8 MultiMesh bands, all below the enemy bullets (layer 8): B0 z 20 scorch decals; B1 z 22 ground explosions and wreck smoke; B2 z 50 dust and air smoke; B3 bursts; B4 debris, plate fall and kit flares; B5 rings, puffs, CB ring and burst; B6 hit sparks, clank, ping; B7 tells (lock, flak); B8 (layer 6) pickup sparkles. Only the Critical Break white frame (layer 10) sits above the bullets. The boss vignette is drawn by Parallax, not VFX.

### 6.9 Boss arena treatment

| Aspect | Rule |
|---|---|
| Scroll | Slows to a stop over about 2 s as the boss enters (eased, no snap). Mid and near layers stop first; far and sky continue at a crawl. |
| Vignette | Eases in over about 1.5 s, dark edges only, never touching the center lane. Drawn at layer 2, below bullets. |
| Palette | One step darker and warmer-contrast (Section 2). The sky keeps the era color. |
| Entry | Dust/debris particle sweep, not a flash. |
| Density | Edges stay medium-dense to frame the arena; the center is emptiest. |
| Boss silhouette | Dominates the upper third (3.6 hierarchy). |
| Era hook | Each arena includes the stage's landmark, in damaged form, behind the boss. |

*Added 2026-11-03 (wave 3b, parallax-and-environment.md):* the arena is two static plates (L2 and L3, 376 x 656) cross-faded in over 120 ticks at `BOSS_WARNING`; L0 and L1 keep crawling (boss drift 25). The grade (`boss_rgb` modulate 204 / 196 / 184) and the vignette (outer alpha 102 of 255, edge bands only) start at warning + 150 and ease over 90 ticks; enrage darkens to 125 %. Parallax owns the vignette.

### 6.10 Checks for any environment asset

- Passes the **grayscale screenshot test** with all bullets fully readable.
- Stays inside luma 16-128 (edge accents up to 160).
- No outline, no small round high-contrast shapes, no hollow rings in the center lane.
- Uses only era palette entries; no bullet hues.
- No flashing or fast-strobing elements.
- Integer-pixel scrolling only.

---

## 7. UI/HUD Visual Direction

**Governing idea:** *The HUD is the cabinet bezel, not part of the sky. It is plated, quiet and fixed, and it never hides a bullet.* It inherits 3.5 (rectilinear chamfered plates), 3.6 (HUD chrome recedes) and 4.7 (warm neutral palette, 20% era tint on frame edges only). *(Pillars: Readable Chaos, Every Hit Counts)*

Drafted by art-director with a ux-designer alignment check. Decisions locked by the user on 2026-10-28: reserved top strip, outline on all text, smooth chain bar with red end-cap, numerals follow the chosen language.

### 7.1 Screen-space, not diegetic
The HUD is **fully screen-space**. The only on-plane cues are the ones that already exist: the hitbox ring, the pips (4.4) and the Lancer engine glow. One exception is a P-color pip tag over each plane for 2 s after spawn or respawn, so co-op players can find themselves.
*Test: no UI element is parented to a plane, bullet or enemy, except the spawn tag.*

### 7.2 Reserved top strip
The HUD lives in a **reserved strip at the top of the canvas that is outside the play field**. Bullets, enemies and players are culled or clamped at its lower edge, so nothing is ever hidden under the HUD. The layout is the same idea from 1P to 4P, so muscle memory carries over.

| Mode | Strip height | Columns | Rows |
|---|---|---|---|
| 1P | 48 px (y 0-47) | 1 x 360 | Row A (y 0-35): 36x36 portrait, score, lives, bombs, kit meter on the left; chain plate on the right. Row B (y 36-47): boss bar / stage progress. |
| 2P | 48 px | 2 x 180, mirrored (P1 left, P2 right) | Row A: score, lives/bombs/meter, chain plate on the inner side. Row B: boss bar. |
| 3-4P | 72 px (y 0-71) | 4 x 90, fixed slot order P1-P4 | Row A (y 0-16): pip mark and score. Row B (y 17-31): lives, bombs, meter. Row C (y 32-59): chain plate. Row D (y 60-71): boss bar. No portrait. |

- The play field is y 48-639 (1-2P) or y 72-639 (3-4P). On every device the strip sits inside the 360x640 canvas, never in the outer bezel (8.1), so the play field is the same size everywhere. The lower third is never used for UI.
- **The boss HP bar lives inside the strip** (Row B/D). This keeps Alarm Red out of the play field (4.1).
- Each column has a 3 px left notch in the player color, the pips, and a frame border in that player's ring pattern (solid, dashed, dotted, double). This is mandatory because P3 and P4 have equal luma (4.4).
- An empty co-op slot shows a "join" glyph plate.
- **Kit meter:** a 4 px segmented bar under the lives row, Tracer Orange on Char, ticks every 25%. Lancer's laser meter uses it. Any other plane gauge must use this same bar (to be defined in the plane GDDs).
- **Lives and bombs:** 14x14 plated icons, at most 5 shown, overflow as `+N`.
- **Score:** 8 digits in 1-2P. In 3-4P it is 6 digits in the small tier; the full score shows on the tally.
- **Hi-score and credits** show on the title, attract and game-over screens only.

*Test: in a 4P screenshot, no bullet is ever drawn above y 72, and the strip is the only UI on screen apart from transient banners.*

*Added 2026-11-03 (bombs.md):* the bomb icon dims to 60 % while the bomb is busy (lockout).

*Added 2026-11-03 (wave 3a, hud.md, menus-title-plane-select.md):* the GDDs supersede parts of this section. **Identity:** "pip mark" and "frame border" mean a pip stack (1-4 blocks of 3x3) plus a 1 px identity line in the ring pattern in the outer 4 px of each column (HUD Rule 8). **Score:** 9 digits in every mode (HUD, Scoring), not 8 / 6. **Counters:** 14x14 icons up to 5 in 1P only; 2P uses icon plus count (14x14); 3-4P uses an 11x11 icon plus count. **Lower-third exception (pending art-director ruling, Menus Open Question 2):** the Pause and Disconnect panels may cover the frozen field while the game is stopped.

*Added 2026-11-03 (wave 4, plane-kits-sentry-breaker.md, tutorial.md):* **Kit bars:** Sentry uses an ability bar (like Leech) plus a recall-available glyph after 60 ticks; Breaker uses a **stock bar** with tick marks every 25 % plus the drone lamp (like Lancer). **Stage card:** during the stage-1 lead-in (120 ticks) the stage card may carry the `stage1_primer` rows (three 16x16 glyph + one short word: Move, Fire, Bomb). **Strip mark:** Tutorial's highlight is four Cream corner brackets (1 px, 4 px arms, 2 px outside the element), steady, HUD layer 11, 180 ticks. In drills the boss-bar rect may show the drill bar (Cream fill, icon plus numerals).

### 7.3 Chain counter and chain-window bar
*(Every Hit Counts. These are the only large UI shapes, per 3.5.)*

| Part | Spec |
|---|---|
| Plate | Chamfered rectangle, Cabinet Char `#1E1B18` fill, `#5A5148` edge, 1 px era tint on the edge. 1-2P: about 96x32. 3-4P: 84x26. |
| Numerals | 1-2P: 24 px tall. 3-4P: 16 px tall. Ember Gold with the 1 px outline (4.7). Tabular width. |
| Window bar | Full plate width, 4 px tall, Ember Gold on `#3A2A14`. It drains linearly over the window in one visible step per tick, never more than 2 px (no tween blur), so the rate is readable (Chain tracker F6, 2026-11-03). |
| Expiry warning | In the last 25% of the window, a 1 px **Alarm Red end-cap** appears at the bar's tip. No blinking and no whole-bar color change. The bar's shortness is the main cue. Optional audio tick and gamepad rumble pulse (7.9). |

| Event | Reaction (integer pixels, no scaling) |
|---|---|
| Gain (+1) | Numerals jump up 2 px for 2 frames. The bar refills in 2 steps. |
| Milestone (50 / 100 / 200) | The plate edge steps Cream, then Gold, then bright Gold. Sparkle particles stay inside the plate. Digits never enlarge. |
| Expire / reset | Numerals fade to `#5A5148` and the plate drops 3 px over 4 frames. The last value stays as a dim **ghost** until the next chain starts ("I dropped it at 187"). Max chain is stored for the tally. |
| Team Chain Bonus | A 1 px Gold bracket links the plates of the players in the team chain, with a "TEAM" icon tag. No flash. |
| Team tag and lamps *(added 2026-11-03, coop-and-team-chain.md)* | The tag is an icon plus `+20` / `+30` / `+40` (2 / 3 / 4 members), no text. Each plate has a 2x2 px lamp: lit while that player has hit the boss recently, outline-only during join grace. No play-field effect; the optional boss-background pulse is off in MVP. |

**Critical Break presentation:**
1. A single white frame (layer 10, the only flash in the game, Section 2).
2. A bilingual banner in the upper third of the play field, over the boss, held about 0.5 s with a 6-frame ease in and out. Ember Gold on a Char plate, Bengali on the top line and Latin below, at equal weight.
3. The chain plate shows the multiplier `xN` and the Life Damage Bonus as a plate-local popup.
4. "Reduce flashing" replaces the white frame with a particle burst. The banner stays.

*Test: reset a 187 chain. The ghost is still readable 1 s later, and nothing moved over the play field.*

*Added 2026-11-03 (wave 3a, critical-break.md, hud.md):* **Critical Break timeline:** logic at tick `T`; the cancel executes and the single white frame is drawn at `T+1` (exactly one rendered frame); the banner starts at `T+2` at the earliest, once no enemy bullet is alive, timed 6 / 30 / 6 ticks; warm burst 36 ticks; plate popup 90 ticks. **No hitstop, no time scaling, no presentation freeze;** only a local boss-sprite shake of at most 4 px for 8 ticks. **Chain drop:** the plate does not move; the digits shift down 3 px inside the plate (HUD Rule 17), superseding "plate drops 3 px" above.

### 7.4 Boss bar, warning screen, tally

**Boss HP bar** (strip Row B/D, x 24-336, 8 px tall, 1 px outline):
- Alarm Red `#E03A3E` fill on `#2A0F12`.
- 1 px Cream phase ticks. The critical-HP threshold has a taller Alarm Red notch.
- A numeric `87%` at the right end (12 px), as the non-color backup (4.6).
- Damage drains with a darker `#7A2226` chip that catches up in 0.3 s.
- The bar fills in over about 1 s during the scroll-stop (6.9).
- Outside boss fights, this row shows stage and wave progress as a thin segmented track that fades after stage start.

**Boss name plate:** bilingual, shown for 1.5 s at boss entry, in the upper third, then hidden.

**Warning screen** (Amber `#FFB000` with black stripes, UI only):
- Two 24 px stripe bands frame a central bilingual "সতর্কতা / WARNING" plate in the middle third.
- The stripes scroll slowly (45 px/s, integer steps).
- The text pulses between 100% and 60% opacity at 1.5 Hz at most. It never blinks.
- It lasts about 2.5 s with a siren, then eases out as the scroll-stop begins.

**Stage-clear tally** (calm, per Section 2):
- Rows reveal one every 0.25 s: Max Chain (hero, Gold, 24 px), Critical Break bonus, Life Damage Bonus, Score.
- 96x96 victory portrait. Co-op uses a 2x2 grid of 180 px cells.
- Any button skips to the final state.
- No flashes.

**Banner rule:** transient banners (Warning, Critical Break, boss name) draw at layer 11 over the play field, so they must only appear when the field is clear of enemy bullets. Warning plays before the boss spawns. Critical Break requires a bomb, which clears bullets. *Gameplay dependency: the boss and bomb GDDs must guarantee this.*

*Added 2026-11-03 (boss-and-boss-parts.md, bombs.md):* the boss row also shows the enrage state and the timeout ("Boss withdrew") and the part-kill caption; captions stay inside the boss row, never over the field. **Banner rule:** Critical Break (17) issues its own full-screen cancel on the trigger tick before the banner; Bombs clears the field only on the press tick.

*Added 2026-11-03 (wave 3a, critical-break.md, wave-and-stage-director.md, stage-end-tally.md, hud.md):* the GDDs supersede parts of this section. **Banners:** Critical Break issues its own full-screen cancel on the trigger tick; the HUD (owner of banner presentation) waits for an empty field up to `banner_wait_max` = 180 ticks, then skips the banner (CB's own 120-tick value is superseded). **Warning:** 150 ticks (2.5 s), starting at wave-5 end + 90, after the Director's field clear at + 60, so it always starts on a clear field. **Boss row numeric:** `x 336-359` in the D10 tier (`100%` = 24 px); part-kill and enrage are icon plus number, no words. **Stage-clear tally:** layouts are 1P full-width rows with the 96x96 portrait; 2P a shared bilingual caption band plus two 180 px cells (36x36 portraits in the column heads); 3-4P caption band plus four 90 px cells. The **fire key** skips (first press settles, second confirms), Start pauses; not "any button". Rows add EARNED (1-2P), the four stage-end lines (CLEAR, NO DEATH, LIVES LEFT, BOSS PEAK) and TEAM CHAIN (co-op). See `design/gdd/stage-end-tally.md`.

### 7.5 Typography
**Personality:** a rounded, even-stroke, slightly squat pixel face, like an arcade cabinet label. Latin and Bengali at equal weight. No decorative serifs, no ornamental underlines (3.5).

| Tier | Latin cap height | Bengali size | Used for |
|---|---|---|---|
| S | 12 px | 17 px | Labels, counts, `%` |
| M | 12 px, Gold | 17 px, Gold | Score |
| L | 16-24 px numerals | Bengali digits at the same height | Chain counter, tally hero |
| XL | 24 px | 34 px | Banners, titles |

- **Bengali size rule:** Bengali size = Latin cap height x 1.375, rounded up. *Note (added 2026-11-03, localization.md): for cap 24 the rule gives 33, but XL is fixed at 34 (exact 2x of S). Proposed digit cells: `cell_w = ceil(0.6 x digit height)`, separator `round(0.4 x cell)`, e.g. 11 px at 17 px digits; to be confirmed in the font spike.*
- **Headroom:** at least 4 px above the matra (3.5). Line box = size + 7 px. Reserve at least +40% width for Bengali strings compared with English.
  - *Clarified 2026-11-03 (wave 5 batch 2, `design/ux/hud.md`):* the **4 px above the matra is a layout reservation** - space a box must set aside before any text is placed - while the **2 px top / 3 px bottom figures quoted in the UX specs are clip floors**: the absolute minimum that must never be cut by a clip rect at draw time. They are not alternatives and neither supersedes the other: a box reserves 4 px, and whatever happens to it afterwards (a clip rect, a scroll edge, a plate chamfer) must still leave the 2 px / 3 px floors intact. A box that only meets the clip floors is **non-conforming at authoring time** even though it renders without visible damage.
- **Outline:** a 1 px `#14110E` outline on all 8 sides, **on all text, always** (4.7). This includes HUD text on plates.
- **Conjunct gate:** because the outline can fill the gaps in conjuncts, the chosen font must pass the conjunct test below with the outline on. If it fails at 17 px, **raise the Bengali size** (18-20 px). Do not drop the outline.
- **Numerals follow the chosen language:** Bengali digits (০১২৩৪৫৬৭৮৯) in Bengali, Western digits in English. Both digit sets are drawn on the **same fixed-width grid**, so a language switch never shifts the layout.
- **Where text appears:**
  - The in-fight HUD is icons and numerals only. It has no word labels.
  - Menus and settings use the chosen language.
  - The title, banners, boss name plates and tally show both scripts.
- **Font candidates (unverified):**
  - GNU Unifont covers Bengali as a 16 px bitmap. That is just under the S tier (17 px), so it works as a development fallback, not as the shipped face.
  - Silkscreen and Pixelify Sans are open-licence pixel faces, Latin only.
  - No known open pixel font covers Bengali at 17 px. Plan a custom or commissioned two-script face (see Section 8).
- **Shaping risk (unverified):** bitmap fonts in Godot do not shape conjuncts. The likely path is a pixel-grid TTF with the advanced text server, or precomposed conjunct glyphs. Test early on both the desktop and **Web** exports of Godot 4.7.

*Test: render "ক্ষ", "শ্রী", "ঙ্গ" and "ত্র" at 17 px with the outline, at 1x. The matra is not clipped and every conjunct is legible.*

*Added 2026-11-03 (wave 3a, hud.md):* two extra numeral tiers: **D12** (digit 12 px, cell 8, sep 3) and **D10** (digit 10 px, cell 6, sep 2), for the boss row and the 3-4P strip. Bengali digits in D12 / D10 are below the 17 px minimum; this is a numeral-only exception pending the font spike (HUD Open Question 1).

### 7.6 Iconography
- Icons are **plated square tiles with chamfered corners**: 14x14 in the HUD, 15-18 px for pickups.
- Never use circles, rings, rice or needle shapes, or Void Indigo or cool fills (3.3, 4.3). The diamond with a `+` glyph is reserved for chain items.
- **Lives:** a top-down plane pictogram in the player color on a Char tile.
- **Bombs:** a Tracer Orange tile with a bomb pictogram. (This replaces the Latin "B" from 4.6 in the HUD, so the icon stays language-neutral. 4.6 still applies elsewhere.)
- **Pickups:** Cream body, `#3A2A14` outline, glyph carries the meaning (4.6).
- Every icon has a distinct silhouette in grayscale.

*Test: at 1x next to an orb bullet, no icon can be mistaken for a bullet.*

*Added 2026-11-03 (wave 4, touch-controls.md):* **touch glyphs** (24x24 at 1x, drawn at an integer scale): Hold (stacked chevrons), Fire (single chevron, shown when auto-fire is off), Drone (drone pictogram in a square), Bomb (the HUD bomb tile), Pause (two bars). Distinct grayscale silhouettes; no circle or ring; no Alarm Red on the strip.

### 7.7 UI animation
Timings are at 60 fps.

| Rule | Spec |
|---|---|
| Easing | Stepped ease-out in 3-4 discrete positions. Integer positions only. No scale, rotation or sub-pixel tweens. |
| Durations | Panel in/out 8 frames. Counter tick 2. Milestone 12. Banner in 10, out 8. Menu transition 6. |
| May flash | Only the Critical Break frame. |
| May pulse | Opacity change of 40% or less, period of 0.5 s or more (2 Hz or less), one element at a time. Examples: warning text, low-life icon, focused menu item. |
| Never | Blink faster than 3 Hz. Flash or tint the screen on life lost (use the hurt portrait and debris). Float score numbers over the play field. Attach UI to a moving entity (except the 7.1 spawn tag). |

### 7.8 Menus, title and plane select
Menus **may be richer** than the HUD, because no bullets are on screen. They can have painted backdrops, parallax, animated planes, portraits, particles and gold gradients (Section 2). These rules still apply:
- Plates stay rectilinear and chamfered. Everything is pixel-snapped, with no filtered scaling.
- The 7.7 flash and pulse rules apply.
- Text is Cream on Char, at 7:1 contrast or better, with the outline.
- **Gamepad focus** never relies on hue alone: a 3 px Cream border plus an arrow glyph offset 2-3 px. On touch screens the focused item uses the same border. No hover-only states.
- Button prompts follow the device in use. Destructive actions (delete save, quit run) need hold-to-confirm.
- Plane select in co-op shows each pedestal with its player-color rim light, ring-pattern frame and join prompt.

**Era tinting:**
- In-game and tally plates take the era Accent at 20% on the frame edge only.
- The title and plane select use the neutral warm palette. Attract mode may cycle era tints.
- The tint never touches text, digits, the chain bar fill, Gold, Alarm Red, Tracer Orange or player colors.

*Added 2026-11-03 (wave 3a, menus-title-plane-select.md):* the **Pause panel** is a compact plate over the frozen field. The **Lobby** is four fixed 90 px slot columns (always visible, even solo) under the plane cards (`card_w` 160 at 2 planes). Transitions are a stepped 4-step Char wipe over 12 frames; no white.

*Added 2026-11-03 (wave 4, tutorial.md):* the stopped-game exception (Pause and Disconnect panels may cover the frozen field) also covers Tutorial's **Coach card** (296x120 plate over a stopped, cleared field, one Resume button). Flight School screens (school list, drill card) use the neutral warm hangar backdrop.

### 7.9 Accessibility options the UI must support
- **HUD scale:** 100 / 125 / 150%, inside the reserved strip (the strip grows; the play field shrinks).
- **Language switch** (Bengali / English) and a text-size step-up.
- **Reduce flashing** (7.3), screen-shake off or reduced, and reduce pulsing.
- **Colorblind:** player color remap (the ring patterns stay on) and a high-contrast HUD palette.
- **Chain cues:** optional audio tick and gamepad rumble for the last 25% of the window, and an optional 3 px near-plane chain bar in the player color (straight bar only, never an arc or ring).
- **Hitbox ring** size and opacity, and an option to dim other players' shots below 50%. *Note (amended 2026-11-03, bullet-manager.md V3 / player-plane.md V6: other players' shots 100 / 75 / 50% by player count; drones always 100%); the option dims below the V3 value for the current player count.*
- **Pause** shows which player paused. Any player can pause.

*Added 2026-11-03 (wave 3b, accessibility-options.md, vfx-and-screen-feedback.md, parallax-and-environment.md):* the **HUD scale bullet above is superseded**: there is no HUD scale and `play_top` stays 48 / 72 (Accessibility Rule 20). In its place: a text-size step on the S/M tiers only, a high-contrast HUD palette and a Pause status panel. "Screen-shake" means the local boss-sprite shake only (there is no global shake); it is off at effects level REDUCED / MINIMAL. Also supported: reduce motion (decorative parallax layers at 50 %), background DIMMED (65 %) / PLAIN, effects level FULL / REDUCED / MINIMAL, and the game-speed assist, which marks a run PRACTICE (unranked).

### 7.10 Checks for any UI asset
- Plated, chamfered and rectilinear. No orb, rice, ring or needle shapes (3.3).
- Passes the grayscale and squint tests: the HUD recedes, bullets and planes lead (3.6).
- Text meets 12 px Latin / 17 px Bengali, has the 1 px 8-side outline and at least 4 px headroom, and passes the 7.5 conjunct test.
- Uses only 4.1 and 4.7 colors. Alarm Red only for boss HP, life lost, chain expiry and critical UI.
- **Alarm Red `#E03A3E` is never a text fill.** *(Added 2026-11-03, wave 5 batch 2; see `design/ux/arcade-ui-style.md` 3.1 rule 3, which owns the UX-layer wording.)* On Cabinet Char it measures about **3.95:1**, below the 4.5:1 text floor, so no word, label, digit or status line is ever filled with it. It stays a **bar fill, plate edge, end-cap or glyph fill**.
- **Red words use Alarm Flare `#F2494D` (4.1), nothing else.** *(Decided 2026-11-03, art-director; closes `arcade-ui-style.md` Open Question 2.)* A failure, error or warning is carried by **three things together**: the **words** (the headline in Alarm Flare, 4.76:1 on Char; any explanatory sentence in Cream), an **Alarm Red `#E03A3E` plate edge and/or an error glyph** (tier S or larger), and the 4.1 Flare use rules (one headline line per screen, outline always, HIGH contrast renders it Cream, never colour alone). No other red may be used for text. Specs may not invent a further red.
- Every meaning has a non-color backup (shape, glyph, number or pattern).
- No flash except Critical Break. Pulses stay within 7.7.
- Integer pixel positions and stepped easing.
- Sits inside the reserved strip, or is a transient banner shown only when the field is clear.

**Open items (for GDDs and playtest):** all pixel sizes and timings above are proposals, not yet playtested. The 3-4P strip (72 px, 11% of height) may need trimming. Touch controls for phones are not designed yet (8.1). The boss and bomb GDDs must confirm the "clear field at banners" rule. Other planes' kit gauges are undefined. Font and licence claims are unverified.

---

## 8. Asset Standards

**Governing idea:** *Every pixel is placed by hand, snapped to the grid, and reproducible from a palette file.* This section turns Sections 1-7 into file-level rules. Sizes come from 3.1, 5.2, 5.6, 5.7, 5.9, 6.4 and 7.5 and are not changed here. All sizes are **px at 1x on the 360x640 canvas**.

Drafted by art-director with technical-artist engine constraints (2026-10-28). Items marked *(unverified)* come from Godot ~4.3 knowledge and must be spike-tested on 4.7 (8.9).

### 8.1 Display and import settings
| Item | Standard |
|---|---|
| Base resolution | **360x640** (9:16). ~~`display/window/stretch/mode = viewport`, `aspect = expand`, `scale_mode = integer` by default *(unverified names in 4.7)*.~~ Root window stretch disabled; the game renders into a 360x640 SubViewport shown by the Display scaler (see design/gdd/display-scaler-and-bezel.md) *(amended 2026-11-03, display-scaler-and-bezel.md)*. The snap rule applies to the SubViewport. Viewport mode renders at the base res and upscales, so no sprite or glyph is ever re-rasterised at window res. `expand` lets the extra screen area become bezel (8.1.1) instead of black bars. *Note: the current `src/` build uses a 480x640 playfield and must move to 360x640 (gameplay positions need a retune).* |
| Snapping | 2D transform and vertex snap to pixel on *(setting names unverified in 4.7)*. Integer positions and integer scroll only. |
| Texture import | Filter **Nearest**, mipmaps off, Detect 3D off, compress **Lossless**, fix alpha border on, premultiplied alpha off. Repeat on only for scrolling strips. **Never VRAM-compressed** (it smears 1 px outlines and is inconsistent on WebGL2). Applied via a shared import preset. |
| VRAM cost | Lossless PNGs still sit in VRAM as RGBA8 (4 bytes per pixel). Budget on that (8.6). |
| Banned | HDR 2D, glow, `draw_line` / `draw_circle` for bullets, rain, rings or lasers (4.7 removed line feathering). All of these are sprites. |

### 8.1.1 Resolution, aspect ratio and devices
**Rule: the game canvas is always 360x640, on every device.** The HUD strip and play field sit inside it, so every player sees the same amount of world (fair score chasing and the same patterns on a phone and a TV). Screens that are not 9:16 get **bezel**: cabinet-frame art outside the canvas. The bezel is never part of the play field and never holds gameplay information.

**Scaling modes** (Settings > Display; default **Auto**):
| Mode | Behaviour |
|---|---|
| Auto | Use the largest whole-number scale (x1, x2, x3, x4...). If that leaves the canvas filling **less than 85%** of the limiting screen side, switch to Fill. |
| Pixel Perfect | Always a whole-number scale. Sharpest, but may leave a wide bezel. |
| Fill | Scale to fill the limiting side exactly. Use **sharp-bilinear** (~~pre-scale x N with nearest, then a smooth down-scale~~ one-pass sharp-bilinear shader, display-scaler-and-bezel.md F5, visually equivalent; amended 2026-11-03), not plain nearest, so pixels stay crisp without uneven rows. *(Method to be proven in spike 3, 8.9.)* |

**Safe areas (phones only; ignored on desktop, Web and Switch — amended 2026-11-03, display-scaler-and-bezel.md):** the canvas and any bezel touch targets sit inside the OS safe area (iPhone notch and Dynamic Island, home indicator, Android punch-hole cameras and rounded corners). Read it with `DisplayServer.get_display_safe_area()` *(unverified on 4.7)*. Only bezel art may draw under a notch.

**Orientation:**
- Phones and tablets: **portrait only**, locked.
- PC, Web and Switch: landscape with side bezels by default.
- **TATE mode** (setting on PC and Switch): rotates the image 90° for a monitor turned on its side or a Switch held upright. A 1080x1920 rotated screen is exactly x3, and the Switch handheld (720x1280 rotated) is exactly x2.

**Bezel art:** portrait bezel = top and bottom panels (frame plates, era tint at 20%, may show the stage name or hi-score when idle). Landscape bezel = left and right panels in the same style (optional: hi-score, input display, era illustration). Bezel art follows Sections 4.7 and 7. It has no bullet shapes, nothing animated faster than the 7.7 pulse rule, and it stays darker than the play field so the canvas edge reads clearly.

**Touch controls (phones):** not designed yet. Planned direction: relative drag anywhere on the screen moves the plane (the finger is never under the plane), with laser and bomb buttons in the bottom bezel. Phones taller than 9:16 have room for them. A 16:9 phone (iPhone SE) has no bottom bezel, so its buttons overlay the lower corners at 50% opacity. Needs a UX spec (`/ux-design`).

**Device table** (Auto mode; scale = whole-number scale or Fill factor):
| Device | Screen (px, portrait unless noted) | Ratio | Auto result | Canvas on screen |
|---|---|---|---|---|
| iPhone X / XS / 11 Pro | 1125x2436 | 19.5:9 | x3 | 1080x1920, 96% width |
| iPhone XR / 11 | 828x1792 | 19.5:9 | x2 | 720x1280, 87% width |
| iPhone 12-16 / Pro | 1170x2532, 1179x2556 | 19.5:9 | x3 | 1080x1920, 92% width |
| iPhone Plus / Pro Max | 1284-1320 x 2778-2868 | 19.5:9 | Fill ~x3.6 | full width |
| iPhone SE (2nd/3rd gen) | 750x1334 | 16:9 | x2 | 720x1280, 96% |
| Galaxy S20 / S21-S25 Ultra (QHD+) | 1440x3200, 1440x3120 | 20:9, 19.5:9 | **x4** | 1440x2560, 100% width |
| Galaxy S20 default (FHD+), S21-S25, Pixel 6-9 | 1080x2340-2400 | 19.5:9-20:9 | **x3** | 1080x1920, 100% width |
| Budget Android (HD+) | 720x1600 | 20:9 | **x2** | 720x1280, 100% width |
| Sony Xperia 1 (4K) | 1644x3840 | 21:9 | x4 | 1440x2560, 88% width |
| Galaxy Z Fold (inner screen) | ~1812x2176 | ~5:6 | x3 | 1080x1920, 88% height, wide side bezel |
| iPad (10th gen) | 1640x2360 | ~4:3 | Fill ~x3.7 | full height, side bezel |
| Nintendo Switch / OLED handheld | 1280x720 landscape | 16:9 | x1 | 360x640, 89% height |
| Nintendo Switch docked, PC 1080p | 1920x1080 landscape | 16:9 | Fill x1.69 | full height |
| Switch 2 handheld | 1920x1080 landscape | 16:9 | Fill x1.69 | full height |
| PC 1440p | 2560x1440 landscape | 16:9 | x2 | 720x1280, 89% height |
| PC 4K, Switch 2 docked 4K | 3840x2160 landscape | 16:9 | x3 | 1080x1920, 89% height |
| Steam Deck | 1280x800 landscape | 16:10 | Fill x1.25 | full height |
| Any screen in TATE | e.g. 1080x1920, 1440x2560 rotated | 9:16 | x3, x4 | 100% |

The screen sizes above come from published specs and are not tested on hardware. Every Android ratio from 16:9 to 21:9 works under the same rule: width-limited, extra height goes to bezel.

**Platform caveats (unverified):**
- **Switch:** Godot has no official Switch export. It needs a Nintendo developer account plus a third-party console port (for example W4 Games). Renderer, C# support and performance on Switch must be confirmed with that vendor before production.
- **iOS / Android with C#:** Godot 4 mobile C# support has been marked experimental. Check the 4.7 status before committing the bullet system to C# (see the language-split ADR).
- **Phones and Web:** the VRAM budget (8.6) is a proposal. Test on a low-end Android (720x1600, 3-4 GB RAM) early.

*Added 2026-11-03 (wave 4, touch-controls.md):* touch devices reserve a **bottom strip** below the canvas for the touch buttons (Touch controls F2: `strip_mm` 15 = 3 + 12 x `s_btn`, e.g. 270 px on a 1125x2436 phone). Device-table results above use the height left after the strip on touch devices; nothing is drawn over the canvas.

### 8.2 Source and export formats
| Item | Standard | Test |
|---|---|---|
| Source | `.aseprite` is the master. One file per entity or tileset, with named tags for animations and layers for bolt-ons and outlines. | Every PNG in `assets/` has a source file. |
| Export | 8-bit **RGBA PNG**, straight alpha, sRGB, no ICC or gamma chunk. Author in indexed mode, export RGBA. | No ICC/gAMA chunk. |
| Alpha | **Binary only (0 or 255).** No baked soft edges, blur or glow. Opacity effects (co-op shots at 100 / 75 / 50% by player count, fades) are runtime modulate. *(Amended 2026-11-03, bullet-manager.md V3; drones 100%, player-plane.md V6.)* | Script finds no alpha other than 0 or 255. |
| Scale | Exported at 1x only, never resampled. | Dimensions match 8.3. |
| Where | `.aseprite` in `art-src/` at the repo root with a `.gdignore`. Exported PNGs, palettes and fonts in `assets/`. Never commit a PNG with no source. | |

### 8.3 Sprite size tiers
The **frame cell** is the bounding box plus 1 px padding on each side, rounded up to an **even** width and height, so a centred sprite never lands on a half pixel.

| Category | Sprite size (px) | Frames (5.10) | Max colours (excl. transparent) |
|---|---|---|---|
| Enemy bullets: orb / rice / needle / ring | 8-9 / 4x9 / 3x12 / 14-18, in **24x24 atlas cells** | Max 4. Rice and needle: 16 pre-rotated angles (22.5° steps) | 3 + Ink outline (4.3) |
| Player shots | Streak or diamond, up to 9x18 | 2 | 4 |
| Drones | 12x12, 16x10, 10x10 | 2 | 6 |
| Player planes | 39-48 long axis, cells up to 50x50 | Idle 3, bank 3+3 | 16 |
| Bolt-ons | Base envelope + 6 px max | 1-2 | 8 |
| Popcorn | 18-27 | 1-2 (8 pre-drawn angles if it turns) | 8 |
| Mid enemies | 36-60 | 2-4 idle, 2-4 tell, 1 damage | 12 |
| Large enemies | 72-120 | 2-4 idle, 2-4 tell, 2 damage | 16 |
| Boss hull, parts | Hull 144-270 wide, parts up to 72. **Sliced into parts**, never one huge sprite | Parts: 2 idle, 3 damage, 1 stump | 24 per boss |
| Pilot portraits | 96x96 and 36x36 | 4 expressions (+ optional 2-frame blink) | 24 / 16 |
| HUD icons, pickups | 14x14 / 15-18 | 1-2 | 6 |
| UI plates | 9-slice, 3 px chamfer corners | 1 | 6 (4.7) |
| Hitbox rings (4 patterns) | Pre-drawn ring sprite per player pattern | 1 | 2 |
| Tiles | **24x24** | 1 (water 2-4) | 16 per tileset |
| Parallax strips | **360 wide**, 1280 high (far) / 1920 high (mid) | 1 | 24 per strip |
| Explosions, debris | Shockwave 36+ px, debris 3-6 px clusters |
| Bezel art (8.1) | Portrait: 360 wide, top/bottom panels up to 360x200. Landscape: side panels up to 400x640, 9-slice or tiling | 1 (optional slow loop) | 24, era-tinted | 3-5 | Era palette only |

- **Rotation:** sprites with outlines never rotate at runtime except in 90° steps. Turning is done with pre-drawn frames. Round, symmetric orb and ring bullets may rotate freely, since it doesn't show.

*Test: every PNG's size fits its row, and a lint pass finds no category over its colour cap.*

*Added 2026-11-03 (plane-kits-lancer-leech.md, bombs.md):* sprite sets: Lancer laser beam 14 px wide and Lancer drone beam 6 px wide (vertical tiled strips; Godot 4.7 tiling unverified), Leech tether (one stretched sprite); bomb column tile 56x16, Leech bomb hook 12x12, detonation burst 48x48, shockwave ring (cream/orange).

*Added 2026-11-03 (wave 3b, vfx-and-screen-feedback.md):* rings over 128 px diameter are baked at stage load from four mirrored quadrants (stepped diameters; VFX Open Question 1). Effect sprite families: bursts (20 / 40 / 72 px, ground variants), debris and chips, smoke puffs, cancel puffs and rings, slot death rings (full and compact), bomb and CB rings, tells (lock reticle, flak fuse and burst), pickup and gem sparkles, plate fall. Full list: `design/gdd/vfx-and-screen-feedback.md` Visual/Audio catalogue.

*Added 2026-11-03 (wave 4, plane-kits-sentry-breaker.md):* Sentry/Breaker sprite sets: Sentry turret 12x12 with a 14x3 base plate and 8 pre-rotated barrel facings, placement tick marks 4x1; Breaker eraser 16x10, net corner brackets 5x5, bolt sprite (speed 18 px/tick); Bastion dome (translucent warm disc, 3 size frames up to r 104, corner brackets, no outline ring); Backlash wall bar (full width, half height 12). Era bolt-ons max 2 per plane per era. Full list: `design/gdd/plane-kits-sentry-breaker.md` Visual/Audio (`/asset-spec system:plane-kits-sentry-breaker`).

### 8.4 Palette discipline
| Rule | Spec |
|---|---|
| Palette files | `assets/art/palettes/`: `pal_global`, `pal_players`, `pal_ui`, `pal_1941`, `pal_1970s`, `pal_2030s`, `pal_2100` as `.gpl` + `.hex`. These files are the **only** source of truth; the Section 4 tables mirror them. |
| Per-sprite cap | See 8.3. Exceeding it needs a written art-director exception. |
| No stray colours | Every exported pixel matches a palette entry exactly. No anti-aliasing, no gradients. |
| Never recoloured | Enemy bullets (4.3) and UI (4.7, except the 20% frame-edge tint). |
| Palette swap allowed | Player plane bases (authored once in the 1941 palette, mapped per era, 5.5), props, debris, explosions, smoke, UI era tint. Done by a canvas_item LUT shader: indexed texture + small Nx1 palette texture, both Nearest. |
| Swap batching rule | **One palette material per era per atlas**, never one per sprite (each material breaks a batch). Player colours (rings, pips, outline accents) use instance colour / modulate or baked variants, not separate materials. |
| Redraw required | Enemies (3.2), bosses, bolt-ons (5.5), landmarks, tilesets, parallax strips. A recoloured 1941 enemy is rejected. |

*Test: an automated palette lint finds zero off-palette pixels against each PNG's declared palette.*

### 8.5 Naming and folders
Lowercase snake_case: `[category]_[name]_[variant]_[size].png`. Categories: `char`, `drone`, `bolt`, `enemy`, `boss`, `bul`, `shot`, `port`, `icon`, `ui`, `tile`, `env`, `fx`, `font`, `logo`, `pal`, `atlas`. Era tags: `1941`, `1970s`, `2030s`, `2100`.

| Example | Meaning |
|---|---|
| `char_lancer_base_48x39.png` | Lancer base airframe sheet |
| `bolt_lancer_1970s_pylon.png` | Era bolt-on |
| `enemy_popcorn_prop_1941_24.png` | 1941 popcorn |
| `boss_fortress_turret_dmg2.png` | Boss part, damage state 2 |
| `port_sentry_hurt_96.png` | Portrait, 96 px |
| `env_strip_far_2030s_1280.png` | Parallax strip |

```
assets/art/
  palettes/  players/  bullets/  shots_fx/  portraits/  bosses/
  enemies/{1941,1970s,2030s,2100}/
  env/{1941,1970s,2030s,2100}/{tiles,strips,props,landmarks}/
  ui/{plates,icons,digits}/  logo/
assets/fonts/
art-src/   # mirrors assets/art, .aseprite only, .gdignore
```

*Test: a filename lint rejects uppercase, spaces and unknown categories.*

### 8.6 Atlases, batching and memory
| Rule | Spec |
|---|---|
| Entity sheets | One PNG per entity, one horizontal strip per animation tag, fixed cell size. Frames and timings in a `SpriteFrames` `.tres`. |
| Bullet atlas | **One** atlas for all enemy bullets (512x512), fixed 24x24 grid, drawn as **one MultiMesh with one material**. Frame and angle are chosen per instance via custom data, driven by bullet age in the manager. No nodes, AnimationPlayer or SpriteFrames for bullets. |
| Category atlases | One atlas each for: bullets, player + shots, enemies per era, effects, UI, digits. Keep each atlas's sprites contiguous in draw order (6.8), since switching textures costs a draw call. |
| Atlas limits | **Max 2048x2048** per texture (WebGL2-safe), power-of-two preferred. **2 px transparent gutter** between regions with edge pixels extruded. |
| Batch breakers to avoid | Per-sprite materials, mixed blend modes (additive is banned on bullets), clip rects. Opacity via modulate is fine. |
| Draw-call budget | Under ~200 total: about 120 world, 40 UI, 40 spare. Bullets 1-2, parallax 5-8, effects up to 8 particle systems. |
| VRAM budget (Web and phones) | **96 MB target, 128 MB hard cap** *(proposal; was 64/96 MB at 240x320, and the 360x640 canvas has 2.25x the pixels per sprite)*. Always loaded about 18 MB (bullets, planes, UI, fonts, bezel). Per-era set about 56 MB (enemies + bosses 18 MB, env 36 MB, fx 2 MB), loaded at stage start and freed at stage end. The next era loads only after the boss dies. |
| Particles | Max **150 on screen** in 4P (rain 40, explosions/debris 80, smoke 30). Max 24 pooled explosion sprites. Particles are 2+ px sprites from the effects atlas. |
| Era screen effects | 2030s scanline haze and 2100 rewind are **sprite/tile animation, not full-screen shaders**. A shader is allowed only on a background-layer sprite, never over the bullet layer. |

*Added 2026-11-03 (wave 3b, vfx-and-screen-feedback.md, parallax-and-environment.md, era-shift-and-plane-evolution.md):* **Particles:** 150 is the hard total of live pooled effects; class caps are non-additive (explosions 24 + debris 56 = the old 80); tiers T0-T4 decide eviction; Parallax weather and smoke count against the 150. **Parallax:** 8 draw calls steady, 10 transient during a section crossfade; env VRAM design budget 28 MiB (22.5 MiB planned). **Loading:** "the next era loads only after the boss dies" is implemented as staged loading: old core freed at `stage_cleared`, old env freed at transition tick 53, then the new env loads (peak 74 MB; Era shift Rule 20).

### 8.7 Pivots and hitboxes
- Every sprite has an explicit **integer-pixel pivot** in `data/`, at the visual centre of mass. For planes, the pivot is the hitbox dot.
- **Hitboxes are never baked into art.** Hitbox shapes, drone offsets and bolt-on anchors live in `data/` `.tres` (`PlaneConfig`, `BossPartDefinition`). Aseprite slices may be used to author them, but the game reads only the `.tres`.

*Test: editing the hitbox `.tres` doesn't touch the PNG. A plane at `x = 100.0` shows no blurred pixel row.*

### 8.8 Fonts and text art
**Outline method (hybrid, locked 2026-10-28).** Godot's built-in outline is a rounded stroke, not a hard 8-side pixel outline, so:
- **HUD numerals** (score, chain, %, counts) come from a **pre-outlined digit atlas**: Western `0-9` and Bengali `০-৯` on one fixed-width grid, plus `x + % : /` and the group separator `,` *(added 2026-11-03, localization.md F1: `format_int` emits Western 3-digit grouping in both languages)*, at each size tier (12/17 and 16-24 px). This is crisp, cheap for numbers that change every frame, and enforces the 7.5 fixed grid.
- **Words** (menus, banners, tally, boss names) use the two-script font with an **outline variant** of the same font drawn underneath the fill.

**Two-script face deliverable (commission or custom):**
| Item | Requirement |
|---|---|
| Format | One **pixel-grid TTF/OTF** with both scripts (pixel-snapped outlines, no curves that antialias), plus its **outline variant**, plus editable source (`.glyphs` / `.ufo` / `.sfd`). |
| Coverage | Basic Latin + Latin-1, Bengali `U+0980-09FF`, ZWJ/ZWNJ, both digit sets, `% x + : / ,`. |
| Shaping | OpenType Bengali features (`akhn`, `rphf`, `blwf`, `pstf`, `half`, `pres`, `abvs`, `blws`, `psts`), or precomposed conjuncts. Shaping needs Godot's **advanced text server** (HarfBuzz). Bitmap fonts cannot shape Bengali, so they are allowed only for the digit atlas. *(unverified on 4.7)* |
| Metrics | Latin cap 12 px / Bengali 17 px (S/M). XL is the same master at exact 2x (24 / 34 px). |
| Godot import | Antialiasing off, hinting none, subpixel positioning off, no MSDF, oversampling 1.0, integer sizes only. Pre-warm common strings at load. *(option names unverified on 4.7)* |
| Licence | OFL or full commercial rights, in writing, in `assets/fonts/LICENSE`. |
| Fallback | Unifont only for missing glyphs during development, never in shipped UI. |

**Text in art:** all text is **rendered live**, except the title logo.
- **Title logo:** hand-pixeled lockup, Bengali and English at equal weight, always both shown. Delivered as layers (`logo_title_bn`, `logo_title_en`) plus the composed lockup. Bengali lettering gets native-speaker review.
- **Banners and plates:** text-free 9-slice plates with live bilingual text on top.
- **HUD, icons, pickups:** no text (7.5, 7.6). **Environment:** no text (6.7).

*Test: a language switch changes every string with no PNG re-export. Text layers exist in `art-src/` only under `logo/`.*

### 8.9 Spikes before production art
These must pass on a **Web export** before Section 8 numbers are treated as final:
1. **Bullets:** a 2000-instance MultiMesh at 4P load holds 60 fps (compare C# vs GDScript buffer packing).
2. **Bengali text:** the 7.5 conjunct test at 17 px with the outline variant, plus the Web build size with the advanced text server.
3. **Display settings:** `scale_mode = integer`, `aspect = expand` and the 2D snap setting names exist in 4.7. The Auto/Pixel Perfect/Fill switch works at runtime, sharp-bilinear Fill looks crisp at 1080p, TATE rotation works, and the safe area is read correctly on an iPhone X-class device and a punch-hole Android (8.1.1). Also *(added 2026-11-03, display-scaler-and-bezel.md)*: SubViewport input forwarding, Web devicePixelRatio, Fill sharpness at 1080p, and present-pass cost on REF-PHONE/REF-WEB.
4. **Shaders and particles:** palette-swap LUT shader batching, shader instance uniforms, and CPUParticles2D vs GPUParticles2D on Web.

### 8.10 Acceptance checklist (per asset)
- [ ] Source `.aseprite` committed; PNG exported from it at 1x.
- [ ] Filename and folder match 8.5.
- [ ] Size and frame count within 8.3 and 5.10.
- [ ] Palette lint passes, within the colour cap.
- [ ] Binary alpha, no ICC, import preset applied.
- [ ] Pivot and hitbox in `data/`, not in the art.
- [ ] In the correct category atlas; no per-sprite material.
- [ ] Passes its section check: 3.x shape, 4.2 luma, 5.x character, 6.10 environment, 7.10 UI.
- [ ] Reviewed at 1x on a 4P-density screenshot and in grayscale.
- [ ] Text-bearing: both scripts tested at 17 px with outline on desktop, Web and a phone.

**Open items:** Aseprite as the tool, and large-binary handling (the project isn't under git yet, so Git LFS is undecided). Colour caps, atlas size, gutter, VRAM and particle numbers are proposals until profiled.

---

## 9. Reference Direction

**Governing idea:** *Borrow methods, not images.* Each reference has one job. No two point the same way, and none is a source of assets.

| # | Reference | Job |
|---|---|---|
| 1 | 1941: Counter Attack (Capcom) | Airframe caricature and the 1941 palette |
| 2 | DoDonPachi (Cave) | Bullet legibility and chain presentation |
| 3 | Metal Slug (SNK / Nazca) | Characters, diorama and explosion craft |
| 4 | Ganryu (Visco, 1999) | Regional setting through restraint |

### 9.1 1941: Counter Attack
**Take:**
- Chunky, nameable WW2 airframes with oversized engines and short wings, built from a few big value blocks (3.1, 5.4).
- Limited warm olive/sepia terrain with tonal, unoutlined ground shapes (4.5, 6.3).
- Simple 3-frame bank animation (5.10).

**Avoid:**
- Its specific planes, bosses, power-up icons and stage layouts.
- Its busier, hard-edged ground patches, which would break the quiet lane (3.4).
- Flat black outlines on friendly planes. Ours use the player-color outline accent (4.4).

### 9.2 DoDonPachi
**Take:**
- The tiny, always-visible hitbox: a dot plus a ring (4.4, 7.1).
- The chain counter as the loudest UI element on screen (7.3).
- Bright-cored bullets that stay readable in dense patterns, as a *principle* only: the core is brighter than its surroundings (4.2).

**Avoid:**
- Pink/red bullet hues. Ours are locked to 225-265° blue-indigo (4.3).
- Saturated laser walls and bullet glow (Section 1).
- Frequent screen flashes. Ours are limited to Critical Break (Section 2).
- Its HUD layout, item art and boss designs.

### 9.3 Metal Slug
**Take:**
- Caricature: big heads, one exaggerated trait, expressive faces (5.3, 5.9), and "TV-show" airframes (3.1).
- Chunky, readable props and buildings with a few signature shapes (6.1).
- Explosions made of clustered bursts plus a debris fan, with particles instead of flashes (6.8).
- The select-screen roster idiom (Section 2).

**Avoid:**
- Its characters, poses, mission-complete layouts, fonts and sound-effect text.
- Its universal heavy black outline. Ink is reserved for enemies and bullets (6.3).
- Its animation density. Ours is capped by 5.10.

### 9.4 Ganryu
**Take:**
- Regional character carried by a few strong backdrop silhouettes (rooftops, bridges, boats) rather than dense ornament (6.1, 6.7).
- Hand-animated mid-size enemies with a clear mechanical tell before firing (5.3).
- Painterly background gradients, with dithering kept to the edges (6.3).

**Avoid:**
- Edo-period or Japanese iconography, and its characters and bosses.
- A detailed mid-ground that competes with bullets (4.2, 6.5).

### 9.5 How to use references
- Every asset brief names which reference supplies **which technique**, citing the sections above. A brief that cites a game without naming a technique is rejected.
- Keep one mood board per asset category, with notes on what was taken. Boards live outside the shipped assets.
- References are looked at, never traced, overpainted or imported. No sprites, tiles, fonts, screenshots or rips from these games go in the repo, `art-src/` or any atlas.
- Every plane, enemy, boss and logo is drawn from our own shape grammar (Section 3). Names, layouts and compositions are never reused.

*Test: remove the reference board. If a stranger could name the game the asset copied, redraw it from the Section 3 shape grammar.*
