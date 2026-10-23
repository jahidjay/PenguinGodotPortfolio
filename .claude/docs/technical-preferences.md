# Technical Preferences

## Engine & Language
- **Engine**: Godot 4.7 (GL Compatibility)
- **Languages**: GDScript only, statically typed (ADR-0001, 2026-11-02). No C# — official Godot 4.7 cannot export C# to Web.
- **Native fallback**: C++ GDExtension for the bullet kernel only if the ADR-0001 benchmark (V1) fails, via a new ADR.
- **Approved exception (2026-11-03, ADR-0007)**: GodotSteam GDExtension on Steam Win/Linux presets only, for identity / auth ticket / friends. No gameplay code, no Web or console builds.
- **C# sections below are kept for reference only; C# is not used in this project.**

## Naming Conventions

**GDScript (.gd)**
- Classes: PascalCase (`PlayerController`)
- Variables/functions: snake_case (`move_speed`)
- Signals: snake_case past tense (`health_changed`)
- Files: snake_case matching class (`player_controller.gd`)
- Scenes: PascalCase matching root node (`PlayerController.tscn`)
- Constants: UPPER_SNAKE_CASE (`MAX_HEALTH`)

**C# (.cs)**
- Classes: PascalCase, must be `partial`
- Public properties/fields: PascalCase (`MoveSpeed`)
- Private fields: `_camelCase` (`_currentHealth`)
- Methods: PascalCase (`TakeDamage()`)
- Signal delegates: PascalCase + `EventHandler` suffix
- Files: PascalCase matching class (`PlayerController.cs`)
- Constants: PascalCase (`MaxHealth`)

## Input & Platform
- **Target Platforms**: PC (Steam/itch), Web, iOS (iPhone X+), Android (Galaxy S20 class+), Nintendo Switch / Switch 2. Base canvas 360x640, see art bible §8.1.1
- **Input Methods**: Keyboard, Gamepad
- **Primary Input**: Gamepad
- **Gamepad Support**: Full
- **Touch Support**: Partial (mobile deprioritized)
- **Local Multiplayer**: 1–4 players, one input device per player
- **Platform Notes**: No hover-only interactions. Hitbox must stay visible on all platforms. Input map must support per-player device assignment from day 1.

## Performance Budgets
- **Target framerate**: 60 fps (fixed-timestep gameplay)
- **Frame budget**: 16.6 ms
- **Active bullets (target)**: ~2000 simultaneous on screen at 60 fps in 4P co-op
- **Bullet architecture**: pooled / array-based; no per-bullet Node instances
- **Draw calls**: keep under ~200 (GL Compatibility; batch via MultiMesh/atlas)
- **Bullet tick**: ≤ 1.5 ms p99 on REF-WEB to accept ADR-0001 (hard limit 2.5 ms); collision ≤ 0.5 ms; MultiMesh pack ≤ 1.0 ms per frame
- **Reference machines**: REF-PC, REF-WEB, REF-PHONE (defined in ADR-0001)
- **Memory**: [TO BE CONFIGURED]
- **Audio** *(added 2026-11-03, Audio GDD 24)*: ≤ 16 MB shipped at MVP (music 12 MB, SFX 4 MB); 32 SFX voices; audio policy ≤ 0.1 ms p99 per frame on REF-WEB
- **VFX / environment (proposals, added 2026-11-03)**: 150 live pooled effects in ≤ 8 MultiMesh draw calls, VFX tick ≤ 0.25 ms and pack ≤ 0.35 ms (VFX GDD 25); parallax 8 draw calls steady / 10 transient, env VRAM ≤ 28 MiB (Parallax GDD 23); era-staged VRAM peak 74 MB (Era shift GDD 19)

## Testing
[TO BE CONFIGURED]

## Forbidden Patterns
(ADR-0001)
- Per-bullet Nodes, or `_draw()`/`draw_circle` for bullets — use packed arrays + MultiMesh.
- Function calls, Callables, signals or `match` per bullet inside hot loops — inline loops, kind buckets.
- Gameplay rules inside Nodes — rules live in node-free `RefCounted` classes with `tick()`.
- Writing another system's state directly — use its request methods or signals.
- Magic numbers for tuning — values live in `.tres` resources under `data/`.
- Global `randf()`/`randi()` in gameplay — use the seeded `RandomNumberGenerator` passed in.
- `delta` inside gameplay logic — use the integer tick counter (60 Hz).

## Allowed Libraries
[TO BE CONFIGURED]

## Engine Specialists
- **Primary**: godot-specialist
- **GDScript Specialist**: godot-gdscript-specialist (.gd files — gameplay/UI scripts)
- **C# Specialist**: godot-csharp-specialist (.cs files — performance-critical systems)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for cross-language architecture decisions and which systems belong in which language. Invoke GDScript specialist for .gd files. Invoke C# specialist for .cs files and .csproj management. Prefer signals over direct cross-language method calls at the boundary.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Game code (.cs files) | godot-csharp-specialist |
| Cross-language boundary decisions | godot-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Project config (.csproj, NuGet) | godot-csharp-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
