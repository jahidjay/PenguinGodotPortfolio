# ADR-0009: Bengali Text Shaping and Fonts on Web (Advanced TextServer, Plans B/C, Digit Atlas)

## Status
**Accepted (2026-11-03)** — accepted with the design set at the Concept → Pre-Production gate, as **Plan A with Plans B and C held in reserve**. Required validation during implementation: the conjunct spike S1 (Validation Criteria V1, Localization AC-42) on the official 4.7 Web export, and the font spike V2 (AC-43). If V1 fails, this ADR is amended to select Plan B (or C) before any Bengali UI art is finalised. The two Localization F3 font-spike measurements (D10 plate width, INDIAN 81 px) are still unmeasured and stay open.

## Date
2026-11-03

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (latest patch 4.7.2), GL Compatibility renderer, official (non-.NET) export templates |
| **Domain** | Text / Localization / UI rendering / Web export |
| **Knowledge Risk** | HIGH — 4.7 is beyond the LLM baseline (~4.3) |
| **References Consulted** | `docs/engine-reference/godot/*` (4.5: draw methods gain optional `oversampling`, `TextServerExtension` overrides break; nothing on Web text servers); TextServerAdvanced class reference 4.1/4.4 (web search 2026-11-03): "Used in Godot by default", uses HarfBuzz, ICU and SIL Graphite; Godot CTL progress report (ICU break-iterator data can be bundled into exported projects). **No source found that states the official 4.7 Web template contains TextServerAdvanced.** |
| **Post-Cutoff APIs Used** | None knowingly. Relies on `TextServerManager`, `TextServer.get_name()` / `has_feature(FEATURE_SHAPING)`, `TextLine` / `TextParagraph`, `FontFile` import options (antialiasing, hinting, subpixel positioning, MSDF, oversampling, `fixed_size`), `FontFile.fallbacks`, project settings `internationalization/rendering/text_driver` and `internationalization/locale/include_text_server_data`, `OS.get_locale()` on Web. All **UNVERIFIED for 4.7**. |
| **Verification Required** | (1) The official 4.7 Web template includes TextServerAdvanced (check `TextServerManager.get_primary_interface().get_name()` at runtime in a Web export). (2) Correct Bengali shaping on Web: pre-base vowel reorder, reph, conjuncts, ZWJ (AC-42). (3) Whether ICU line-break data must be bundled (`include_text_server_data`) for word wrap. (4) Web build size and load time with/without it. (5) Font import option names for pixel-grid rendering in 4.7. (6) `OS.get_locale()` on Web returns the browser language (Localization OQ10). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GDScript only; official Web export; node-free logic); ADR-0004 (Display SubViewport at 1× canvas, where text is drawn); ADR-0006 indirectly (banners appear after the flash; no text in the fight) |
| **Enables** | Localization epic (system 27), HUD digit renderer, banners/plates, Menus, Tally text; commissioning brief for the two-script face |
| **Blocks** | Final Bengali UI art and font commission sign-off (art bible 8.9 spike 2); any Plan B pipeline work (only if V1 fails) |
| **Ordering Note** | Run S1 first — it is a one-afternoon spike with the interim fonts (Hind Siliguri / Noto Sans Bengali) and decides whether Plans B/C exist at all. |

## Context

### Problem Statement
MorutJan is a Bengali-first game (Localization Overview; bilingual title, banners, boss plates, tally). Bengali needs **complex text shaping**: pre-base vowel signs reorder (`কি`, `কে`), reph sits on top (`র্ক`), conjuncts form ligatures (`ক্ষ`, `শ্রী`, `ঙ্গ`, `ত্র`, `স্ত্র`), ZWJ forms (`র‍্য`), nukta normalisation. In Godot this needs the **Advanced TextServer** (HarfBuzz + ICU); the Fallback server and bitmap fonts do not shape. The Web is a first-class target, and whether the **official Godot 4.7 Web export template** ships TextServerAdvanced is **unverified** (Localization Rule 24, OQ1, art bible 8.9 spike 2). The GDD names Plan B (pre-shaped glyph IDs at import) and Plan C (custom Web template) and asks for an ADR.

### Constraints
- Official Web export only (ADR-0001); no C#.
- Pixel-art look: text drawn at **1× in the 360×640 SubViewport** and integer/sharp-bilinear scaled by Display; no antialiased outlines (art bible 8.8).
- In-fight HUD has **no words**: numerals only, from a pre-outlined digit atlas (art bible 8.8, Localization Rule 26).
- No Bengali shaping during a fight (Localization Rule 27); language switch within one frame, nothing moves (Rules 16, 18).
- Bengali size rule: `ceil(Latin cap × 1.375)`, S 12/17, XL 24/34; conjunct gate may raise S to 18–20 (Rule 25).

### Requirements
- R1: Every string in the conjunct test set (Rule 28) renders correctly on Windows, Linux, Android, iOS and **Web**.
- R2: No `.notdef`, no clipped matra, 4 px headroom with the outline variant (AC-43).
- R3: HUD numerals: both digit sets on one fixed grid, no shaping, cheap per change (AC-40: `format_int` ≤ 20 µs on REF-WEB).
- R4: Shaping cost paid at load, not per frame.
- R5: Web download size increase from text support is measured and accepted.

## Decision

### 1. Plan A (expected): TextServerAdvanced everywhere, including Web
- Keep `internationalization/rendering/text_driver` at its default (Advanced). At boot, a debug assertion and a release log line record `TextServerManager.get_primary_interface().get_name()` and `has_feature(TextServer.FEATURE_SHAPING)`. If the primary server cannot shape on a platform, the game logs an error and falls back to **English** for words (digits still work via the atlas) rather than showing broken Bengali — a safety net, not a shipping plan.
- Set `internationalization/locale/include_text_server_data = true` **only if** V1 shows Bengali word-wrap or line-break needs ICU data on Web (setting name UNVERIFIED); measure the size cost either way (R5).
- **Spike S1 is the gate** (V1). If S1 passes, Plans B and C are not built.

### 2. Font stack
- **Shipped:** one commissioned **pixel-grid TTF/OTF** containing Latin + Bengali (`U+0980–09FF`, ZWJ/ZWNJ, both digit sets, `% x + : / ,`) with full OpenType Bengali features (`akhn`, `rphf`, `blwf`, `pstf`, `half`, `pres`, `abvs`, `blws`, `psts`, `ccmp` for nukta forms), plus its **outline variant** (a second font file drawn underneath the fill). Bitmap fonts (`.fnt`, image fonts) are **banned for words**: they cannot shape.
- **Import options (names UNVERIFIED for 4.7):** antialiasing off, hinting none, subpixel positioning disabled, MSDF off, oversampling 1.0, integer sizes only; text is drawn inside the 1× SubViewport so no oversampling is needed. `FontFile.fallbacks`: same family only; **GNU Unifont in debug builds only** (missing-glyph visibility).
- **Interim fonts (spike and pre-commission only):** Latin Silkscreen or Pixelify Sans; Bengali Hind Siliguri Medium, then Noto Sans Bengali SemiBold (all OFL, licences to be read and stored in `assets/fonts/LICENSE`, Localization Rule 23). Rendered with AA off, they are a shaping and size stand-in, not shipped art.
- **Commission brief requirement (from this ADR):** the face must pass the conjunct set at 17 px **and** keep conjunct glyphs inside the line box `size + 7` with 4 px headroom, because Plan A relies on HarfBuzz mark positioning against those metrics.

### 3. Digit atlas (no text server for numerals)
- HUD numerals, chain, score, %, lives `+N`, countdowns and tally numbers use a **pre-outlined digit atlas** (art bible 8.8): Western `0-9`, Bengali `০-৯`, `,` `x` `+` `%` `:` `/`, five tiers D24/D17/D16/D12/D10 (HUD Rule 12), one fixed cell grid per tier so both digit sets share widths.
- `Localization.format_int(n)` / `format_plain(n)` return a string; a node-free `DigitLayout` maps each character to an atlas cell index and x offset (no shaping, no font lookup); a `DigitAtlasRenderer` (presentation node) draws cells with `draw_texture_rect_region`, re-laying out only when the value or language changes (AC-40).
- Consequence: the in-fight HUD is **independent of the text server** — it works even if Bengali shaping fails on a platform.

### 4. Shaping cost: pre-warm and reuse
- Banners, boss names and tally strings for the next stage are shaped at **stage load** into cached `TextLine` / `TextParagraph` objects (current language, and both for bilingual strings) and drawn from the cache (Rule 27). Labels in menus shape on language change only. No Bengali is shaped for the first time during a fight.

### 5. Plan B (if S1 fails): pre-shaped glyph runs at import
- **What:** an editor import step (GDScript `EditorImportPlugin` / tool script; runs in the **editor**, which has TextServerAdvanced) shapes every Bengali cell of the CSV tables **per word** and stores glyph runs (glyph index, x/y offset, advance, cluster) per key in a generated `.tres`. A derived font is produced whose shaped glyphs are re-mapped to **Private Use Area codepoints** (offline font tool, e.g. fontTools, as a build-time dependency only), so the **Fallback** server can draw them by codepoint. A presentation `ShapedRunLabel` draws runs glyph by glyph with the stored offsets and wraps on the stored word boundaries.
- **Placeholders:** Bengali segments are pre-shaped; placeholder values are digits (atlas or plain font, no shaping) or Latin handles (no shaping), so runtime formatting still works.
- **Why preferred over C:** shapes once instead of per frame, keeps official templates, smallest Web size. **Cost:** a pipeline tool, a regenerated derived font on every font change, no runtime-typed Bengali (none exists: handles are Latin, Online Rule 16).
- Exact mechanics (PUA remap vs drawing by glyph index on the Fallback server) are UNVERIFIED and are the first task of a Plan B spike.

### 6. Plan C (if S1 fails and Plan B proves unworkable): custom Web template
- Build the 4.7.x Web template from source with `module_text_server_adv_enabled=yes` (and the Fallback server disabled), keeping everything else identical to the official template. **Cost:** an emscripten toolchain pinned per engine patch, CI build time, larger download, engine-maintenance for a solo developer. Allowed only by amending this ADR.

### 7. Other rules fixed here
- Strings are NFC (Rule 13); the font must shape both nukta forms (`ccmp`).
- `OS.get_locale()` on Web is read once at first boot (Rule 3); if it returns an unexpected value, English is chosen and the title language toggle fixes it in one press.
- `qpb` debug locale (conjunct stress set in every label) is the continuous regression test for shaping.

### Architecture Diagram

```
CSV (keys,en,bn; NFC) ──import──► .translation ──► TranslationServer ──► Localization.text()/text_both()
                                                                          │
           Plan A (expected): TextServerAdvanced (HarfBuzz/ICU) ◄─────────┤ Labels / TextLine cache (pre-warmed at stage load)
           Plan B (if S1 fails): editor-time shaping ─► glyph-run .tres + PUA font ─► ShapedRunLabel (Fallback server)
           Plan C (last resort): custom Web template with text_server_adv
Pixel-grid TTF (fill) + outline variant TTF (under), AA off, 1× SubViewport ─► Display integer / sharp-bilinear scale

format_int / format_plain ─► DigitLayout (cell indices, fixed grid) ─► DigitAtlasRenderer (no text server)  ← all in-fight HUD numerals
```

### Key Interfaces

```gdscript
# Localization autoload (Rule 15) — unchanged by this ADR
func text(key: String, args: Dictionary = {}) -> String
func text_both(key: String, args: Dictionary = {}) -> String
func format_int(n: int) -> String
func format_plain(n: int) -> String

class_name DigitLayout extends RefCounted            # node-free, headless-testable
func layout(s: String, tier: int) -> PackedInt32Array   # cell index per char; x = i * cell_w (separators narrower)

class_name TextCapabilities extends RefCounted        # boot check
static func can_shape_bengali() -> bool               # primary TextServer name + FEATURE_SHAPING
```

## Alternatives Considered

### Alternative A (chosen): Advanced TextServer on all platforms + digit atlas, Plan B/C held in reserve
Described above.

### Alternative B: Plan B from the start (pre-shaped runs everywhere)
- **Pros**: Independent of the Web template; zero runtime shaping cost.
- **Cons**: Pipeline tool, derived font regeneration, custom label renderer, no standard Label/RichTextLabel for Bengali; real work for a solo dev.
- **Rejection Reason**: Not needed if S1 passes; kept as the designated fallback.

### Alternative C: Plan C from the start (custom Web template)
- **Pros**: Guaranteed text server choice.
- **Cons**: Leaves the official template path ADR-0001 relies on; maintenance per patch.
- **Rejection Reason**: Last resort only.

### Alternative D: Pre-rendered string images (whole strings baked to textures)
- **Pros**: Zero shaping at runtime; trivial renderer.
- **Cons**: Every string × size × language becomes an asset; art bible 8.8 test "a language switch changes every string with no PNG re-export" fails; outline variant baked; bigger memory.
- **Rejection Reason**: Conflicts with the art bible; acceptable only as an emergency for a handful of banners.

### Alternative E: Bitmap (BMFont) pixel font with precomposed conjunct glyphs mapped to codepoints
- **Pros**: Crisp pixel art; no HarfBuzz needed.
- **Cons**: Reordering and reph placement still need shaping logic; precomposed coverage is huge and error-prone.
- **Rejection Reason**: Bitmap fonts are allowed only for the digit atlas (art bible 8.8).

### Alternative F: English-only on Web
- **Pros**: No risk.
- **Cons**: Breaks the Bengali-first identity on the primary platform.
- **Rejection Reason**: Contradicts the game concept and the user's bilingual requirement.

## Consequences

### Positive
- Standard Godot text nodes and translation flow work for Bengali if S1 passes.
- The fight HUD never depends on shaping (digit atlas).
- A clear, pre-decided path if the Web template lacks HarfBuzz.

### Negative
- Web download includes HarfBuzz/ICU (size to be measured).
- The commissioned font carries a strict OpenType feature requirement.
- Plan B, if needed, is a non-trivial pipeline.

### Risks
| Risk | Mitigation |
|---|---|
| Official 4.7 Web template lacks TextServerAdvanced (top risk, Localization Rule 24) | S1 first; Plan B; Plan C |
| Interim fonts fail the conjunct set at 17 px | Raise `bn_size_s` to 18–20 (Rule 25); try the second interim font; commission |
| Pixel-grid face misplaces marks at 1× (HarfBuzz offsets fractional) | Subpixel positioning off; integer sizes; font designed on the 1× grid; V2 review by a Bengali reader |
| ICU data needed for wrapping adds size | Measure (V1); Bengali uses spaces — word-wrap may work without dictionary data |
| `OS.get_locale()` wrong on Web | English default + one-press toggle on Title |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| localization.md | Rule 24 / OQ1 (S1: advanced text server on Web; Plans B/C via ADR) | Decisions 1, 5, 6; V1 gate |
| localization.md | Rules 22–23 (font stack, interim fonts), 25 (sizes), 28 (conjunct set), AC-42, AC-43 | Decision 2; V1, V2 |
| localization.md | Rule 26 (digit atlas, five tiers), Rule 17/17a (`format_int`, `format_plain`), AC-40 | Decision 3 |
| localization.md | Rule 27 (pre-warm, no shaping in a fight), Rule 13 (NFC), OQ10 (`OS.get_locale()` on Web) | Decisions 4, 7 |
| hud.md | Rule 12 (numeral tiers D24–D10) | Decision 3 |
| art-bible.md | 8.8 (pixel-grid TTF, outline variant, import flags), 8.9 spike 2 | Decision 2; V1–V2 |

## Performance Implications
- **CPU**: Shaping at load only; digit layout per value change (≤ 20 µs target, AC-40).
- **Memory**: Two font files (fill + outline) and the digit atlas (five tiers, small); shaped-text caches per stage.
- **Load Time**: Pre-warm at stage load (measure on REF-WEB, target ≤ 50 ms per stage).
- **Network / download**: Web build size delta of the text server and optional ICU data — measured in V1 and recorded here.

## Migration Plan
1. Spike S1: minimal Web export rendering the conjunct set with Hind Siliguri and Noto Sans Bengali; log the primary TextServer; record build size (with/without `include_text_server_data`).
2. If pass: implement `Localization`, `DigitLayout`, `DigitAtlasRenderer`, pre-warm cache; commission the face with Decision 2's brief.
3. If fail: amend this ADR to Plan B, run a Plan B spike (PUA remap + Fallback draw), then implement the import tool.
4. Replace prototype hard-coded English HUD text (`src/ui/hud/hud.gd` task from wave 3a) with keys + digit atlas.

## Validation Criteria
- **V1 (gate, S1 / Localization AC-42)** — official 4.7 release Web export on REF-WEB (Chrome desktop), plus Chrome Android and iOS Safari: `কি`, `কে`, `র্ক`, `ক্ষ`, `শ্রী`, `ঙ্গ`, `ত্র`, `র‍্য`, `ৎ`, `ক্ষ্ম`, `দ্ব`, `স্ত্র` render with pre-base vowels in front and reph on top; primary TextServer name logged; Web size table (wasm + pck, gzip/brotli) with and without ICU data.
- **V2 (gate, AC-43)** — the conjunct set at 17 px, 1×, outline variant on: no `.notdef`, no clipped matra, 4 px headroom, every conjunct distinguishable — reviewed by a native Bengali reader. Failing raises `bn_size_s` and repeats.
- **V3** — Language switch on Title/Settings/Pause changes every string and digit within one frame; HUD digit positions identical in both languages (Localization ACs).
- **V4** — `format_int` ≤ 20 µs on REF-WEB; 0 calls over 600 ticks with a constant score (AC-40).
- **V5** — No first-time Bengali shaping during a stage (debug counter on shaped-text cache misses = 0 after stage load).

## Related Decisions
- ADR-0001 (official Web export, GDScript only), ADR-0004 (SubViewport at 1×), ADR-0006 (banner timing after the flash).
- Design: `design/gdd/localization.md`, `hud.md`, `design/art/art-bible.md` §7.5, §8.8, §8.9.

> Engine review: not yet run — `godot-specialist` to confirm the 4.7 Web template's text server and font import option names. TD-ADR skipped — Lean mode.
