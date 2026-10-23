# Godot 4.7 — Current Best Practices (project-relevant)

> Last verified: 2026-10-23
> Only practices stated in the official upgrade pages are listed. Add more via `/setup-engine refresh` after reading 4.5–4.7 release notes.

## Project / scenes
- After upgrading, run **Project > Tools > Upgrade Project Files…** and commit it on its own to avoid large diffs from the new `.tscn` format (no `load_steps`, unique node IDs).
- Set old defaults explicitly if your project depends on them (glow blend mode, `area_mask`, stretch mode, etc.).

## Display (pixel art)
- New-project defaults in 4.7 are `display/window/stretch/mode = canvas_items` and `aspect = expand`. Choose and set these deliberately for pixel-art integer scaling.

## Input / co-op
- Don't test `InputEvent.device == 0` for mouse/keyboard. Compare with `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` or check the event type.
- Assign joypads to players by device ID; keep keyboard as a separate input source.

## GDScript
- Overrides of methods with a typed return inherit that return type; return an explicit value.
- Don't depend on the packed-array property setter being called when setting a single element.
- Use `@export_file_path` when you need raw `res://` strings instead of `uid://`.

## C#
- Target .NET 8 minimum; .NET 9 for Android exports.
- Many binding changes are C# source/binary breaking (AnimationPlayer `StringName`, Animation length double, FileAccess store_* returns). Recompile after each engine bump.
- Wrap editor-only classes in `#if TOOLS`.

## Rendering
- Retune glow and HDR 2D after engine bumps; defaults changed in 4.6.
- Line drawing in 4.7 has no antialiasing feather; use wider lines or sprites for bullets/lasers.

## Navigation / TileMap
- `AStar*` returns an empty path when the start point is disabled/solid (4.6).
- Set `TileMapLayer.physics_quadrant_size = 1` if you need exact per-cell body lookups.

## Gaps
- Web export, performance, and MultiMesh/bullet-pooling guidance for 4.7 were **not** covered in the upgrade pages. Verify against the 4.7 docs before committing to a bullet architecture.

## C# and Web export (checked 2026-11-02)
- Official Godot 4.7 does **not** support exporting C# projects to Web. Official docs still say C# Godot 4 projects cannot export to the web.
- Only experimental routes exist: community builds (ComplexRobot/godot-dotnet-web-export, has a 4.7.2 build, net9.0, "not all features supported") and the unmerged PR GH-106125 (raulsntos prototype, .NET 9 + wasm-tools).
- Impact: any C# code in the project blocks the official Web export. The language-split ADR must decide: all-GDScript gameplay (keeps Web), C# + no Web, or C# + unofficial build (risk).
- Sources: https://github.com/ComplexRobot/godot-dotnet-web-export/releases , https://github.com/raulsntos/godot4-web-dotnet-prototype , https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
