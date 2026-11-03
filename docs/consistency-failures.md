# Consistency Failure Log

| Date | GDD A | GDD B | Conflict Type | Status |
|---|---|---|---|---|
| 2026-11-03 | hud.md | vfx-and-screen-feedback.md, game-events-and-session.md | Stale signal ownership | Fixed |
| 2026-11-03 | bullet-manager.md | vfx-and-screen-feedback.md, plane-kits-sentry-breaker.md, powerups-and-drops.md | Duplicate interface shape | Fixed |
| 2026-11-03 | touch-controls.md | plane-kits-lancer-leech.md, plane-kits-sentry-breaker.md | Undefined/provisional interface | Fixed |
| 2026-11-03 | touch-controls.md | bombs.md | Provisional event name | Fixed |
| 2026-11-03 | touch-controls.md, localization.md | save-settings-high-scores.md | Key namespace clash | Fixed |
| 2026-11-03 | audio.md | tutorial.md, plane-kits-sentry-breaker.md, online-leaderboards-boss-rush.md | Missing IDs / placeholders | Fixed |
| 2026-11-03 | game-events-and-session.md, menus-title-plane-select.md | online-leaderboards-boss-rush.md | Signature mismatch | Fixed |

## 2026-11-03 — HUD vs VFX/Session: `screen_flash_requested`
- **Domain:** presentation / event bus
- **Documents:** hud.md (Rule 31 area), vfx-and-screen-feedback.md Rule 5, game-events-and-session.md Rule 13
- **What happened:** HUD still said that VFX owns `screen_flash_requested` after wave 3b deprecated it.
- **Resolution:** HUD now says the signal is deprecated (VFX Rule 5, Session Rule 13).
- **Pattern:** deprecations were applied to the owner and its direct consumers, but not to docs that mention the signal only in passing.

## 2026-11-03 — Bullet manager `cancel_report` had two shapes
- **Domain:** bullet cancel interface
- **Documents:** bullet-manager.md Rules 13-14, vfx-and-screen-feedback.md Interactions, plane-kits-sentry-breaker.md Rule 25, powerups-and-drops.md
- **What happened:** wave 3b added a VFX-facing report `(cause_slot, area, positions, count)`. Wave 4 added a kit-facing `cancel_report(slot, request_id, count)` with the same name.
- **Resolution:** BM Rule 13 now defines one per-tick `cancel_report[]` with entries `(request_id, cause_slot, area, items, count, positions_in_pool_order[])` and lists its readers: VFX the same tick, Powerups the `items = true` entries, kits the next tick. All consumers now point to it.
- **Pattern:** an applier that adds an interface for a new consumer should extend the existing struct instead of adding a second one.

## 2026-11-03 — Touch vs Plane kits: `drone_state`
- **Domain:** kit outputs
- **Documents:** touch-controls.md Interactions, plane-kits-lancer-leech.md Rule 40, plane-kits-sentry-breaker.md Rule 38
- **What happened:** the kits named `drone_state` but never defined it. Touch marked it provisional.
- **Resolution:** LL Rule 40 defines `(state READY/ACTIVE/COOLDOWN, cooldown_permille)`. SB Rule 38 uses the same shape. Touch and LL now reference it.
- **Pattern:** a consumer's "provisional" name should be added to the owner's output list in the same pass.

## 2026-11-03 — Touch vs Bombs: bomb accepted event
- **Domain:** event names
- **Documents:** touch-controls.md Interactions, bombs.md Rule 5
- **What happened:** Touch used "bomb accepted (event name provisional)". Bombs emits `bomb_used(slot)`.
- **Resolution:** Touch now uses `bomb_used(slot)`.
- **Pattern:** the consumer GDD was written before it checked the owner's signal list.

## 2026-11-03 — Touch string keys vs Save setting keys
- **Domain:** localization / save keys
- **Documents:** touch-controls.md UI strings, localization.md Rule 5 and Interactions, save-settings-high-scores.md Rule 16
- **What happened:** the string keys `touch.hint.*`, `touch.solo` and others used the same `touch.` prefix as the Save setting keys `touch.*`.
- **Resolution:** string keys were renamed to `ui.touch.*` (file `ui_touch.csv`). Save keeps `touch.*`.
- **Pattern:** keep string-key and setting-key namespaces apart (`ui.*` / `opt.*` for strings).

## 2026-11-03 — Audio IDs missing for Tutorial, Sentry/Breaker and Online/Rush
- **Domain:** audio event list
- **Documents:** audio.md Sound Event List, tutorial.md Visual/Audio, plane-kits-sentry-breaker.md A1, online-leaderboards-boss-rush.md Visual
- **What happened:** these GDDs listed cues with no Audio IDs. Tutorial used placeholder sounds.
- **Resolution:** IDs added under Audio's rules (bus, band and pool chosen to match similar rows). Cues that Tutorial marks as silent were added to Audio's "Not sounds" list.
- **Pattern:** a new GDD with a Visual/Audio section needs a matching Audio event-list pass.

## 2026-11-03 — `start_run` signature
- **Domain:** run start API
- **Documents:** game-events-and-session.md Rule 1, Rule 13 and Interactions; menus-title-plane-select.md Rule 23 and Interactions; online-leaderboards-boss-rush.md
- **What happened:** the Online Leaderboards rows used `start_run(selections, mode, stage_list)`, but the Session rules and Menus still said `start_run(selections)`.
- **Resolution:** all of them now use the extended signature (defaults MAIN and the main stage list). It is recorded as a decision under auto-approve; the lead-programmer still needs to confirm it.
- **Pattern:** a signature change made in one row must also be made in the rule text.
