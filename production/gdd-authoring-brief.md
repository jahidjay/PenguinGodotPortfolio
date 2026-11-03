# GDD Authoring Brief (for agents writing MorutJan system GDDs)

Created 2026-11-03. The user asked for all remaining GDDs to be written under **auto-approve**: take the recommended option at every decision, and record it so the user can change it later.

## Your job
Write ONE system GDD to `design/gdd/<slug>.md`. **Do not edit any other file.** Return a final report (format at the bottom); the main session applies cross-doc changes.

## Read first (project root D:\Projects\GodotProjects\Morutjan\morut-jan)
- `CLAUDE.md`, `.claude/docs/technical-preferences.md`
- `design/gdd/game-concept.md` (pillars: Every Hit Counts · Readable Chaos · Four Planes, Four Games · History Accelerates)
- `design/gdd/systems-index.md` (your row, its dependencies, the "Decisions captured" block, design order)
- `design/registry/entities.yaml` — **locked values; never contradict.** If you need a different value, report it as a conflict, don't change it.
- Every existing GDD your system touches (upstream AND downstream) — at minimum read their Detailed Design, Dependencies and Open Questions. Read `design/gdd/bullet-pattern-library.md` as the style reference (newest, cleanest).
- `design/art/art-bible.md` sections relevant to your system (visual systems must follow it).
- `docs/architecture/adr-0001-gdscript-bullets-multimesh.md` (60 Hz integer ticks, no `delta` in logic, one seeded RNG passed in, node-free RefCounted logic classes with `tick()`, all tuning in `data/*.tres`, GDScript only).
- `docs/engine-reference/godot/` if you mention engine features (Godot 4.7; flag anything unverified).
- Existing code for your system under `src/` and `data/` if the index says code exists.
- Memory facts: the game ships **Bengali + English** (all text, fonts, UI); MVP planes **Lancer + Leech**; powerup = +1 drone (max 4); canvas **360x640** pixel art (x4 = 1440x2560); platforms PC + Web first (iOS/Android/Switch later).

## Required structure (exact headings, in order)
```
# <System Name>

> **Status**: Designed (pending review)
> **Author**: Claude (<agent role>) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: <pillars>

## Overview
## Player Fantasy
## Detailed Design
### Core Rules
### States and Transitions
### Interactions with Other Systems
## Formulas
## Edge Cases
## Dependencies
## Tuning Knobs
## Visual/Audio Requirements
## UI Requirements
## Acceptance Criteria
## Open Questions
```

## Style rules
- Plain, short English. Tables over prose. Numbered rules in Core Rules. Bold the key term once.
- Overview: "**The data layer:**" + "**The player impact:**" paragraphs (or just the player paragraph for pure-presentation systems).
- Every formula: name, expression in backticks, variable table `| Variable | Symbol | Type | Range | Description |`, **Output Range**, **Example** with real, correctly computed numbers.
- Edge cases: `- **If <condition>**, <exact outcome>.` Never "handle gracefully".
- Dependencies: Upstream and Downstream tables `| System | Hard/Soft | Interface |`, marking which have a GDD. Then **"Amendments to other docs"** — a numbered list of exact changes other GDDs/index need for bidirectional consistency.
- Tuning Knobs: `| Knob | Default | Safe range | Too low | Too high | Interacts with |`, plus "Owned elsewhere" list. Balance values must cite their formula or rationale.
- Visual/Audio: concrete (px at 1x, ticks, draw layers from art bible §6.8, colour roles). Bullets always win: no effect over enemy bullets (layer 8); never use Void Indigo / Ink or reserved bullet shapes for non-bullets.
- UI: what HUD/menu elements this system needs, or "no player-facing UI" + debug tools. If it has UI, add the line `📌 **UX Flag**: run /ux-design for <screen> before writing epics.`
- Acceptance Criteria: a "Defaults used:" line, a "Test setup:" paragraph (node-free classes, injected seeded RNG/ticks, tests in `tests/unit/test_<area>_*.gd`, `extends SceneTree` style like `tests/unit/test_chain_tracker.gd`, numbers read from `.tres`), then `- **AC-NN [Unit|Integration|Perf|Manual] (ref):** ...` with concrete numbers; at least one per core rule and formula; include determinism and a perf budget where the system runs per tick. Typically 30–55 criteria.
- Open Questions: `| # | Question | Owner | Resolve by |`.
- End sections that took a design choice with a note: `> Decided under auto-approve (2026-11-03): <list>.`
- Interfaces to undesigned systems are **provisional** — say so and define the contract you expect.
- Stay at behaviour level; implementation patterns that need a decision → note "→ ADR".

## Final report (write it to `production/gdd-reports/<slug>.md` AND return it as text)
1. File written + one-paragraph summary.
2. Key decisions (bullets) — the user will review these.
3. **Amendments**: exact edits other files need (file, location/line text, new text). Include the systems-index row update (status `**Designed** (pending review) — [GDD](<slug>.md)` and any dependency column change).
4. **Registry candidates**: YAML entries (constants/formulas) in the registry's existing format, only for values other systems use; plus existing entries whose `referenced_by` should gain your slug.
5. Conflicts with locked values or other GDDs (or "none").
6. Open risks.
