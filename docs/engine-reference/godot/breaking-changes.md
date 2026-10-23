# Godot Breaking Changes (4.3 → 4.7)

> Last verified: 2026-10-23
> Source: official "Upgrading from Godot X to Godot Y" pages (4.4, 4.5, 4.6, 4.7) on docs.godotengine.org.
> Filtered for a 2D project using GDScript + C#. 3D / XR / editor-plugin items are omitted unless they affect export or C#.
> Legend: **GD** = GDScript, **C#B/C#S** = C# binary/source compatibility.

## 4.3 → 4.4

| Area | Change | Impact |
|---|---|---|
| Core | `FileAccess.store_*` (store_8/16/32/64, store_buffer, store_line, store_string, store_var, etc.) return `bool` instead of `void` | GD ok; C# binaries must be recompiled |
| Core | `OS.read_string_from_stdin` gains `buffer_size` | GD callers may need updating |
| Core | `Curve` now enforces its value range | Curves with points outside [0,1] must set `min_value`/`max_value` |
| Export | `@export_file` now stores/returns `uid://` paths | Arrays may mix `uid://` and `res://`; 4.5 adds `@export_file_path` for raw `res://` |
| Rendering | `Shader.get/set_default_texture_parameter` use `Texture` instead of `Texture2D` | C# recompile/edit |
| Rendering | `VisualShaderNodeCubemap.cube_map`, `VisualShaderNodeTexture2DArray.texture_array` → `TextureLayered` | C# incompatible |
| Rendering | `VisualShaderNodeVec4Constant` input type is `Vector4` | Recreate constants in existing visual shaders |
| Rendering | `CPUParticles2D/GPUParticles2D.restart` gains `keep_seed` | Additive |
| Navigation | `NavigationServer2D.query_path` gains `callback` | Additive |
| Android | Sensor events disabled by default | Enable in Project Settings > Input Devices > Sensors |

## 4.4 → 4.5

| Area | Change | Impact |
|---|---|---|
| Platform | C# Android export requires .NET 9; other platforms .NET 8 minimum | C# only |
| Core | `Node.get_rpc_config` renamed `get_node_rpc_config` | GD incompatible |
| Core | `JSONRPC.set_scope` replaced by `set_method` | GD/C# incompatible |
| Core | `Resource.duplicate(true)` now only duplicates resources internal to the file | Use `duplicate_deep(DEEP_DUPLICATE_ALL)` for old behavior |
| Core | `ProjectSettings.add_property_info()` warns on missing/invalid keys | Use `set_as_basic()`, `set_restart_if_changed()`, `set_as_internal()` |
| Rendering | `RenderingServer.instance_reset_physics_interpolation`, `instance_set_interpolated` removed | GD incompatible |
| Text | Draw methods (`draw_string`, `draw_char`, `Font.draw_*`, `TextLine.draw`, etc.) gain optional `oversampling` | Additive; `TextServerExtension` overrides break |
| GUI | `RichTextLabel.add_image/update_image`: `size_in_percent` → `width_in_percent` + `height_in_percent` | Old calls still work; set height too to keep behavior |
| C# | `StringExtensions.PathJoin`, `GetExtension` behavior fixed; `Quaternion(Vector3, Vector3)` now shortest-arc | C# only |
| Navigation | Region updates run threaded by default (`navigation/world/region_use_async_iterations`); navmesh merge order changed | Tune `navigation/2d_or_3d/merge_rasterizer_cell_scale` |
| TileMap | `TileMapLayer` physics chunking on by default; `get_coords_for_body_rid()` results can differ | Set `physics_quadrant_size = 1` for exact lookups |

## 4.5 → 4.6

| Area | Change | Impact |
|---|---|---|
| Core | `FileAccess.get_as_text`: `skip_cr` parameter removed | Fix call sites passing it |
| Core | `FileAccess.create_temp`: `mode_flags` is `FileAccess.ModeFlags` | Compatible |
| Animation | `AnimationPlayer.assigned_animation/autoplay/current_animation` → `StringName`; `get_queue` returns `StringName[]`; `current_animation_changed` param → `StringName` | GD ok; C# source/binary break |
| Navigation | `AStar2D.get_point_path`, `AStar3D.get_point_path`, `AStarGrid2D.get_id_path/get_point_path` return **empty path** if `from_id` is disabled/solid | Check code assuming non-empty path |
| Rendering | Glow default blend mode now Screen; `glow_intensity` 0.8 → 0.3, glow levels retuned | Retune glow; affects 2D with HDR 2D |
| Scenes | `.tscn` no longer writes `load_steps`; unique node IDs saved | Run Project > Tools > Upgrade Project Files, then commit |
| Defaults (new projects) | Windows rendering driver D3D12; Jolt for 3D physics | Not relevant to existing GL Compatibility project |
| GUI | `Control.grab_focus` gains `hide_focus`; `PopupMenu.submenu_popup_delay` 0.3 → 0.2 | Minor |
| Android | Export source layout moved to `src/main/java/...` | Android export only |

## 4.6 → 4.7 (rated "relatively safe")

| Area | Change | Impact |
|---|---|---|
| Input | Mouse/keyboard `InputEvent.device` IDs changed from 0 to `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` | **Relevant to 4P local co-op:** never test `device == 0`; compare against the constants or check event type |
| Audio | `AudioStreamPlayer.area_mask` default 1 → 0 | Area2D `audio_bus_override` stops working unless mask reset to layer 1 |
| Audio | `AudioEffectSpectrumAnalyzer.tap_back_pos` removed | All |
| Rendering | `CanvasItem` no longer adds antialiasing feather to lines | Lines look thinner; **check bullet/laser line rendering** |
| Rendering | `LinearToSRGB` visual shader node no longer clamps on Mobile/Forward+ | Visual shaders |
| Rendering | `RenderingServer.particles_request_process_time`: `time` → `process_time` | C# source break |
| Physics | `PhysicsServer2D.body_set_shape_as_one_way_collision` gains `direction` | Additive |
| GDScript | Setting an element of a packed array no longer calls the property setter for the whole array | Behavior change |
| GDScript | Overrides of methods with a typed return now inherit that return type and need an explicit return | Add `return null` or a value |
| Animation | `AnimationNodeBlendSpace1D/2D`: `sync` bool → `sync_mode` enum | Set `sync_mode` if blends break |
| Animation | `Animation.length` metadata float → double | C# break |
| GUI | `RichTextLabel.add_image/update_image`: `width_in_percent/height_in_percent` → `width_unit/height_unit` (`RichTextLabel.ImageUnit`); `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT` | GD break for the constant |
| GUI | `Control.accessibility_live` type moved to `AccessibilityServer.AccessibilityLiveMode` | C# break |
| Core | `Object.is_class` takes `StringName`; `OptimizedTranslation.generate` returns `bool` | C# binary break for the latter |
| New-project defaults | `display/window/stretch/mode` = `canvas_items`, `aspect` = `expand` | Set explicitly for pixel-art integer scaling |
| Platform | Minimum macOS raised to 11 | macOS export |

## Items to double-check for this project

- Use `canvas_items` or `viewport` stretch with integer scaling for pixel art; do not rely on defaults.
- 4P local co-op: map devices through `Input.get_connected_joypads()` / joypad `device` IDs; keyboard device ID changed in 4.7.
- Retest line-drawn bullets and lasers for thickness after 4.7's missing feather.
