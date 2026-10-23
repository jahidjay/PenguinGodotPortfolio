# Godot Deprecated / Removed APIs (4.3 → 4.7)

> Last verified: 2026-10-23
> Note: the official upgrade pages contain **no formal deprecation lists**. This table covers APIs they list as removed or renamed. Verify anything else against the class reference for 4.7.

| Don't use | Use instead | Since |
|---|---|---|
| `Node.get_rpc_config()` | `Node.get_node_rpc_config()` | 4.5 |
| `JSONRPC.set_scope()` | `JSONRPC.set_method()` | 4.5 |
| `RenderingServer.instance_reset_physics_interpolation()` | removed, no replacement listed | 4.5 |
| `RenderingServer.instance_set_interpolated()` | removed, no replacement listed | 4.5 |
| `RichTextLabel.add_image/update_image(size_in_percent)` | `width_in_percent` + `height_in_percent`, and in 4.7 `width_unit` / `height_unit` | 4.5 / 4.7 |
| `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` | `UPDATE_WIDTH_UNIT` | 4.7 |
| `FileAccess.get_as_text(skip_cr)` | call without `skip_cr` | 4.6 |
| `AnimationNodeBlendSpace1D/2D.sync` | `sync_mode` enum | 4.7 |
| `AudioEffectSpectrumAnalyzer.tap_back_pos` | removed | 4.7 |
| Comparing `InputEvent.device == 0` for mouse/keyboard | `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` | 4.7 |
| `RenderingServer.particles_request_process_time(time)` | `particles_request_process_time(process_time, ...)` | 4.7 |
| `Resource.duplicate(true)` expecting external resources copied | `duplicate_deep(DEEP_DUPLICATE_ALL)` | 4.5 |
| `ProjectSettings.add_property_info()` with `usage` key | `set_as_basic()`, `set_restart_if_changed()`, `set_as_internal()` | 4.5 |
| `@export_file` expecting `res://` paths | `@export_file_path` (4.5+) for raw `res://` | 4.4 / 4.5 |
