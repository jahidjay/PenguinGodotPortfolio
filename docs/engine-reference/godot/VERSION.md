# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.7 (latest patch seen: 4.7.2) |
| **Project Pinned** | 2026-10-23 |
| **LLM Knowledge Baseline** | Godot ~4.3 (skill baseline); treat 4.4–4.7 APIs as unverified unless listed in these docs |
| **Risk Level** | HIGH — version is beyond reliable LLM training data |
| **Last verified** | 2026-10-23 (all four official upgrade pages read) |

## Reference files
- [breaking-changes.md](breaking-changes.md) — 4.3 → 4.7, filtered for 2D + GDScript/C#
- [deprecated-apis.md](deprecated-apis.md) — removed/renamed APIs
- [current-best-practices.md](current-best-practices.md) — practices from the guides

## Rules for agents

1. Before suggesting engine API code, check these docs and the official class reference for 4.7 (`https://docs.godotengine.org/en/4.7/`).
2. When unsure whether an API exists, changed or is deprecated, use WebSearch and say it was unverified.
3. Do not assume 4.3-era behavior for physics, rendering, GDScript or C# bindings.

## Official upgrade pages (all read 2026-10-23)

- 4.3 → 4.4: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.4.html
- 4.4 → 4.5: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.5 → 4.6: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.6 → 4.7: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html

## Not yet covered

The upgrade pages have no Input/Audio/2D/Web-export sections for most versions. Release notes for 4.4–4.7 (new features, performance, Web export changes) have not been reviewed.
