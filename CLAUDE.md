# MorutJan — Claude Code Game Studios

A 2D vertical bullet-hell shmup (DoDonPachi-style chain system, 1941 pixel art that advances through eras, 4 planes, 1–4 local co-op). See `design/gdd/game-concept.md`.

## Technology Stack

- **Engine**: Godot 4.7 (GL Compatibility renderer)
- **Language**: GDScript only (all gameplay and UI, so the official Web export works). No C#. C++ GDExtension only as a fallback approved by a new ADR (see `docs/architecture/adr-0001-gdscript-bullets-multimesh.md`). Exception (approved 2026-11-03): the third-party GodotSteam GDExtension on Steam Win/Linux builds only, for Steam identity, auth ticket and friends — never gameplay (see `docs/architecture/adr-0007-online-services.md`)
- **Build System**: Godot Export Templates (standard, non-.NET editor)
- **Asset Pipeline**: Godot Import System + custom resource pipeline

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Project Conventions

- Project layout and system wiring: `docs/project-structure.md` (read before adding code)
- Code in `src/`, designer data in `data/` (.tres), tests in `tests/`. `src/` never imports from `prototypes/`.

- Technical preferences: `.claude/docs/technical-preferences.md`
- Design docs: `design/gdd/`
- Production tracking: `production/` (stage in `production/stage.txt`, review mode in `production/review-mode.txt`)
