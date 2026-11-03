# UX Review Brief (2026-11-03) — for per-document review agents

You are running the `/ux-review` checklist on **exactly one** UX spec, then fixing
its blocking issues **in that file only**.

## Hard rules
1. **You may edit only your assigned `design/ux/<file>.md`.** Never edit another
   UX spec, any GDD, the art bible, the registry, or the systems index. Other
   agents own those files concurrently — editing them corrupts the batch.
2. Cross-document problems (a GDD rule that must change, an art-bible amendment,
   a registry constant, a conflict with another UX spec) go in your **report** under
   `## Cross-document amendments requested`, with the exact file, section/line, current
   text and proposed text. The main session applies them.
3. Auto-approve is in force (user instruction, 2026-11-03): make the recommended
   decision yourself, record it, do not ask questions.
4. Do not invent game rules. If a value is missing and no owner GDD supplies it,
   either derive it from an existing constant (say so) or list it as an open question.

## Cross-reference context to load first
- `.claude/docs/technical-preferences.md` → `## Input & Platform` is **authoritative**
  for input coverage: Platforms = PC (Steam/itch), Web, iOS (iPhone X+), Android
  (Galaxy S20+), Switch/Switch 2. Input methods = Keyboard + Gamepad (gamepad
  primary, full support). Touch = partial, mobile deprioritised. 1–4 players,
  one device per player. No hover-only interactions.
- `design/accessibility-requirements.md` → committed tier is **COMPREHENSIVE**
  (incl. per-slot pad maps, input test screen, colour-vision palette with luma
  spread, sound visual twins, background dim/plain, untimed menus, unranked-assist
  PRACTICE latch). Section 1.1 splits requirements MVP / Vertical Slice / Production.
- `design/ux/arcade-ui-style.md` → the style guide (arcade/DoDonPachi tradition).
- `design/ux/interaction-patterns.md` → pattern library P01–P28 + Back table +
  animation/sound standards. Reference patterns, never re-specify them.
- `design/art/art-bible.md` → canvas is **360x640** (9:16) pixel art, x4 = 1440x2560.
  Reserved top HUD strip 48 px (1–2P) / 72 px (3–4P). 1 px outline on all text.
- The GDDs named in your spec's own header (read their UI Requirements / UI sections).
- Language rule (user decision, 2026-11-03): **menus are SINGLE-language with a
  language chip**; dual-script only for the title, banners, tally labels, the Web
  gate, the first-run plate and the TATE confirm title.

## Checklist to run
Use the full `/ux-review` Phase 3A checklist for screen specs (3B for `hud.md`,
3C for a pattern library):

**Completeness** — header (Status/Author/Platform Target); Purpose & Player Need
(player perspective); Player Context on Arrival; Navigation Position; Entry & Exit
Points; Layout Specification (zones + component inventory table); States & Variants
(must include loading, empty/populated, error); Interaction Map (every target input
method); Data Requirements (every element has source system + owner); Events Fired
(every action has an event or a stated null); Transitions & Animations (enter/exit
minimum); Accessibility Requirements; Localization Considerations (max char counts);
Acceptance Criteria (>= 5 specific, testable).

**Quality** — player need unambiguous and specific; error/empty/loading states real,
not happy-path only; every timer/auto-dismiss has a duration; keyboard-only
navigation fully specified; d-pad order + face button mapping documented; nothing
needs mouse-precision on a pad; focus order defined; **no data element owned by
"UI"**; update trigger stated for real-time data (not just "realtime"); null handling
per element; accessibility matches COMPREHENSIVE; nothing colour-only; contrast
ratios given; screen-reader/announcement handling stated or explicitly out of scope
per the tier's section 4; every GDD UI Requirement in your header covered and no UI
element changing game state without a GDD requirement; components cite the pattern
library and new patterns are flagged; char limits + 40% expansion for layout-critical
text; ACs include a performance criterion and a resolution criterion and are
evaluable without opening another document.

**HUD only (3B)** — HUD philosophy; information-architecture table covering all
systems with UI requirements; zones with safe-zone margins per platform; per-element
spec (zone, visibility trigger, data source, priority); states for exploration/combat/
cutscene/paused equivalents; visual budget (max simultaneous elements, max screen %);
platform adaptation; tuning knobs; nothing covering centre play area without a hide
rule; colourblind variants; queue/priority for notifications.

**Pattern library only (3C)** — catalog index current; all standard controls present
(button variants, toggle, slider, dropdown, list, grid, modal, dialog, toast, tooltip,
progress bar, input field, tab bar, scroll); every pattern has When to Use / When NOT
to Use / full states / accessibility / implementation notes; animation + sound standard
tables; no conflicting behaviour between patterns (esp. "Back").

## Deliverables
1. **Fix the blocking issues in your own file**, in place. Keep the document's existing
   structure, heading style and tone. Bump `Last Updated` to 2026-11-03 and add a
   one-line revision note (`> Revised 2026-11-03 after /ux-review: <summary>`) under
   the header block. Leave advisory-only items as Open Questions rather than inventing
   rules.
2. **Write your report to `production/ux-reports/<your-doc-slug>.md`** using the
   `/ux-review` Phase 4 output format, then these extra sections:
   - `## Fixes applied` — numbered, each naming the section changed.
   - `## Cross-document amendments requested` — as specified in Hard rule 2.
   - `## Still open` — anything deliberately left unresolved and why.
   Report both the verdict **before** your fixes and the verdict **after**.
3. Return a short summary: before/after verdict, count of fixes applied, and the
   cross-document amendments (these are what the main session must act on).
