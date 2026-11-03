# Localization (Bengali + English)

> **Status**: Approved (2026-11-03)
> **Accepted 2026-11-03** (final doc closeout): the owner accepted the design as it stands and the project moved to Pre-Production. Items still listed in Open Questions stay open and are resolved during implementation.
> **Author**: Claude (localization-lead) under user auto-approve, 2026-11-03
> **Last Updated**: 2026-11-03
> **Implements Pillar**: Readable Chaos (text and numbers stay legible in both scripts), Every Hit Counts (the chain and score read the same in either language)
> **Revision 2026-11-03 (UX amendments wave 5, batch 2)**: new Rule 5a registers the Menus, Results, name-entry, Boards and Credits keys added by the UX review (English source only, Bengali pending native review); the glossary gains the "ALL CLEAR" / "MISSION COMPLETE" pair (Rule 30); F3 records the 3-4P Results digit tiers D12/D10 and the two open font-spike questions.

## Overview

**The data layer:** Localization is the **string and number layer** for all player-facing text. Every string lives in a CSV string table under `data/localization/strings/` and is looked up by a stable dot-notation key through Godot's `TranslationServer`. Two languages ship: Bengali (`bn`) and English (`en`). A small autoload, `Localization`, resolves the starting language (saved choice, else OS locale, else English), switches language at runtime, and exposes three services: `text(key, args)` for strings, `format_int(n)` for numbers (Bengali or Western digits, grouped), and `text_both(key)` for strings that always show both scripts (title, banners, boss name plates, tally). The rules are node-free `RefCounted` classes (formatter, resolver, pseudo-localizer, key linter) so they are unit-testable without a scene. Fonts, the digit atlas and the text-fit rules from the art bible (sections 7.5 and 8.8) are enforced here as data and lint checks. Per ADR-0001, gameplay logic never reads a string: game rules emit keys and numbers, and presentation turns them into text.

**The player impact:** The game is a Bengali game. A Bengali player sees Bengali menus, Bengali digits on the score and chain, and Bengali on the banners, and never sees a missing glyph, a broken conjunct or a raw key. An English player sees the same layout in English. Switching language in Settings changes every string and every digit at once, with nothing shifting on screen. Fights stay readable in both scripts because the in-fight HUD is icons and numerals only. Without this system, text would be hard-coded, Bengali conjuncts would break on Web, and the HUD would jump when the language changed.

## Player Fantasy

**Anchor moment: "it's written for me."** A player in Dhaka or Kolkata opens the game and sees the title in their own script, at the same weight as the English, with their own digits ticking up on the chain counter. Nothing feels pasted on. An English-speaking friend picks up the second pad, flips the language, and the screen is the same screen. Both players read the bilingual **CRITICAL BREAK** banner at the same glance, because Bengali and Latin carry equal weight.

What this must feel like:
- **Native, not translated-looking.** Digits, grouping and spacing look right in each script, and the conjuncts (ক্ষ, শ্রী, ঙ্গ, ত্র) are whole and legible at 1x.
- **Nothing moves when you switch.** Both digit sets sit on one fixed-width grid, so language is a skin and not a layout change.
- **Text never costs a life.** In a fight there are no words to read. Banners appear only when the field is clear.

**Anti-fantasy (must never happen):** a raw key such as `menu.settings.title` on screen; a clipped matra; a conjunct that falls apart into separate letters; a layout that breaks because Bengali is wider; an English-only string left in a Bengali build.

> `creative-director` not consulted (lean mode).

## Detailed Design

### Core Rules

**Languages and fallback**

1. **Supported languages** are `bn` (Bengali, বাংলা) and `en` (English). Both are LTR. No RTL support is needed. The list lives in `data/localization/localization_config.tres`; adding a language is a producer decision (→ Open Questions).
2. The **fallback chain** is: requested locale → its base language (`bn_BD` and `bn_IN` → `bn`) → `en`. Any other OS locale (`fr_FR`, `ja`) resolves to `en`. There is one Bengali locale (`bn`), written in standard colloquial Bengali (চলিত ভাষা) with no region-specific vocabulary.
3. **Default language (first run):** if the player has no saved language, use the OS locale's language part: `bn` → Bengali, anything else → English. The result is stored by Save (26) as an explicit `bn` or `en`, so later OS changes do not flip the game. The title screen always shows both scripts, and a language toggle on the title and in Settings lets a wrong guess be fixed in one press.
4. **A missing or empty translation never shows a key.** `text()` returns the requested language's string; if it is missing or empty it returns the `en` string; if that is missing too it returns the literal `⚠` plus nothing else in debug builds and an empty string in release (the lint makes this unreachable in a shipped build, Rule 21). Every miss is logged once per key.

**String table pipeline**

5. **Format: CSV, one file per feature area**, imported by Godot into `.translation` resources and registered in Project Settings. Columns: `keys,en,bn`. UTF-8 **without BOM**, LF line endings, every field quoted. Files: `ui_menu.csv`, `ui_settings.csv`, `ui_tally.csv`, `ui_banner.csv`, `boss.csv`, `plane.csv`, `common.csv`. *Key families added 2026-11-03:* `ui_menu.csv` holds the Menus (22) `menu.*` keys (UI Requirements table of `menus-title-plane-select.md`); `plane.csv` holds the plane-card keys `plane.<id>.name/tag/style/fire/hold/drone`; the title language-chip labels `বাংলা` / `English` are a non-translated lint exception (each shows in its own script in both languages). `ui_tally.csv` holds the Stage tally (21) `tally.*` keys (list in `stage-end-tally.md`, Visual/Audio): `tally.row.*`, `tally.header.*` and `tally.note.boss_withdrew` are bilingual (`text_both`); badges, slot words and prompts are single-language. *Key families added 2026-11-03 (wave 4):* `plane.csv` gains `plane.sentry.*` and `plane.breaker.*` (Target; plane-kits-sentry-breaker.md). New file **`ui_tutorial.csv`**: `tut.*` (`tut.school.*`, `tut.drill.<id>.title/goal/tip`, `tut.hint.<id>`; tutorial.md). New file **`ui_touch.csv`** (file name (decided under auto-approve 2026-11-03, consistency check)): `ui.touch.*` strings (hints `ui.touch.hint.*`, solo toast `ui.touch.solo`, landscape prompt `ui.touch.landscape`, `ui.touch.max_here`, `ui.touch.back_hint`) and the Settings labels `opt.touch_*` (touch-controls.md UI Requirements). *(Renamed 2026-11-03, consistency check: string keys no longer use the `touch.` prefix, which is reserved for Save setting keys.)* New files **`ui_online.csv`** (`ui_online.*`: consent text, status lines, board labels, error lines per server reason code; the server sends codes, never text; handles are Latin and never translated) and **`ui_rush.csv`** (`ui_rush.*`; online-leaderboards-boss-rush.md). Bengali cells in all four are drafts for native review. **Glyph-token arguments:** a string may carry a placeholder such as `{g_fire}` that the caller fills with an inline button glyph (Input `action_glyph(slot, action)`) at draw time; the token is identical in `en` and `bn` and the placeholder lint (Rule 21) checks it like any other placeholder (Tutorial, Touch).
5a. **Keys registered 2026-11-03 (UX review wave 5, batch 2).** All of these are **single-language** (not `text_both`) and live in `ui_menu.csv`. **English is the source; every Bengali cell is `pending native review`** and must be filled by the localisation lead before the string soft freeze - none of them was machine-drafted. Each needs a `_meta` row (Rule 8) before the lint will pass.

| Key | English source | Context / limit |
|---|---|---|
| `menu.results.not_placed` | `Not in top {n}` | Results rank strip when the run scored but did not place; `{n}` = `board_size`, formatted by `format_int` (Menus Rule 35, Save Rule 5) |
| `menu.results.not_ranked` | `Not ranked` | Results, score 0 or an assisted run |
| `menu.results.practice` | `PRACTICE` | Results verdict tile for an assisted run |
| `menu.results.stage_of` | `Stage {n} / {m}` | Results, stage reached |
| `menu.results.next` | `NEXT` | Results prompt bar |
| `menu.name.done` | `DONE` | Name-entry stamp |
| `menu.name.editing` | `EDITING` | Name-entry slot state |
| `menu.name.no_limit` | `No time limit` | Name entry under `access.untimed_menus` |
| `menu.name.controller_lost` | `Controller lost` | Name-entry controller-lost plate (P31) |
| `menu.name.drop` | `DROP` | Action on that plate |
| `menu.name.latin_only` | `Latin letters only` | Refusal hint when a Bengali key is pressed on the wheel (Save Rule 12) |
| `menu.scores.empty_1cc` | `No 1CC scores yet` | Boards, 1CC filter on an empty result |
| `menu.scores.empty_hint` | `Finish a run to put your initials here` | Boards empty-board Status block detail line |
| `menu.scores.practice_note` | `Practice runs are not ranked` | Boards notice line |
| `menu.scores.readonly` | `Scores are read-only` | Boards notice line, Save ReadOnly state |
| `menu.scores.unsaved` | `Progress will not be saved` | Boards notice line, Save Unavailable state |
| `menu.scores.reset_note` | `Scores could not be restored` | Boards notice line, Save Reset state (no blame wording) |
| `menu.credits.empty` | `No credits available.` | Credits empty-data status line |
| `menu.credits.licence_missing` | `Licence text unavailable.` | Credits licence block with an empty body |

   **Status-block limits** (from `design/ux/high-scores.md`, "Status block and notice strings"): a headline is at most **2 lines of 28 Latin characters** (56 total), a detail line at most **2 lines of 36 Latin characters** (72 total) and a notice line at most **56 Latin characters over 2 lines**; Bengali at `bn_width_reserve_pct` 40 is allowed a third line in each. The lint checks these as `max_width_px` per key (F5).

   **Confirmed, not new:** the `credits.section.<key>` family already exists (Credits section headings, translated) together with `menu.title.credits`; `menu.scores.empty` and `menu.scores.play_again` are unchanged. Names, handles, plane ids and licence bodies are **not translated** and stay on the lint allow-list exception (Menus Rule 46).

   **[STRETCH] Online keys** (Boss Rush / Online boards, only when that tab ships): `menu.scores.tab_solo`, `tab_coop`, `tab_records`, `tab_online`, `filter_all`, `filter_1cc`, `legend_c`, `legend_1cc`, `col_chain`, `col_crit`, `dash_note`, `online_off`, `offline_age` (`{n}` via `format_int`) and the client-side **`menu.scores.status_*` family**, one key per adapter reason code (`status_rate_limited`, `status_update_required`, `status_suspended`, `status_backoff`, `status_offline`, `status_loading`, `status_empty`, `status_friends_empty`, `status_around_me_empty`, `status_storage_blocked`, `status_reconsent`). The server sends a **code, never text** (Online Rule 33), so each code must have a key here or the Status block cannot be drawn. These go in `ui_online.csv`, not `ui_menu.csv`, and follow the same status-block limits.

6. **Why CSV and not PO:** there are two languages and a few hundred strings; CSV is one diffable file per area, the Bengali translator can work in a spreadsheet, and Godot imports it with no plugin. PO's advantages (plural forms, translator comments, tools like Poedit/Weblate) are not needed: the in-fight HUD has no words, plurals are handled by Rule 14, and context lives in the metadata sidecar (Rule 8). Switch to PO if a third language or heavy plural use appears (→ Open Questions). *Unverified on 4.7:* Godot's CSV `?context` and `?plural` columns; this design does not use them.
7. **Key naming:** lower-case dot notation, `area.screen_or_group.element[.variant]`, matching `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`, at most 48 characters. Keys name the **role**, never the English text. Examples: `banner.critical_break`, `banner.warning`, `menu.settings.language.label`, `tally.row.max_chain`, `boss.fortress_1941.name`, `common.confirm`. A key's meaning never changes after it ships; a meaning change gets a new key and the old one is deleted.
8. **Context metadata** lives in `data/localization/strings/_meta.csv`, one row per key: `keys,context,max_width_px,tier,variables,bilingual,status`. `context` says where it appears and who says it. `max_width_px` is the box width in px at 1x. `tier` is S, M or XL. `variables` lists placeholders. `bilingual` is true for keys shown in both scripts at once. `status` is `new | drafted | sent | translated | reviewed | frozen`. A key with no `_meta` row fails the lint.
9. **No hard-coded player-facing strings** in `.gd`, `.tscn` or `.tres`. Scenes use keys in Control `text` properties (Godot translates them), and designer data (`data/bosses/*.tres`, plane configs) stores `name_key` fields, never names. The lint scans for quoted strings next to `Label`, `text =`, and banner calls (→ tools-programmer).
10. **Placeholders** are named, `{n}`, `{player}`, `{stage}`, filled by `String.format()` with a dictionary. Positional `%s` is banned because Bengali word order differs. A translation must contain exactly the placeholders of its `en` source (lint).
11. **Numbers are never typed into translations.** A value reaches a string as a placeholder already formatted by `format_int()` (Rule 17). Translation cells contain no ASCII digits and no Bengali digits (allow-list: none). Translators write words only.
12. **No manual line breaks** in cells. Text wraps on spaces (`autowrap_mode` word). Both languages use spaces between words.
13. **Unicode normalisation:** Bengali cells are stored in NFC. In NFC the precomposed nukta letters (ড় U+09DC, ঢ় U+09DD, য় U+09DF) decompose to base + nukta (U+09BC). The font must shape both forms (a `ccmp` feature). ZWJ and ZWNJ are allowed. The authoring tool normalises on save; the lint rejects non-NFC cells. (→ tools-programmer)
14. **Plurals** use two keys, `<key>_one` and `<key>_other`, picked by `plural_form(lang, n)` (F6). Phrases with a count should prefer icon plus number so no plural is needed. At MVP no HUD string needs a plural.

**Runtime and switching**

15. `Localization` is an **autoload** that loads before any scene. API: `set_language(code)`, `get_language()`, `text(key, args = {})`, `text_both(key, args = {})`, `format_int(n)`, `font_size_px(tier, step = 0)`, and the signal `language_changed(code)`.
16. `set_language(code)` calls `TranslationServer.set_locale(code)`, then emits `language_changed`. Controls re-translate through Godot's translation notification; custom drawers (the HUD digit atlas, banners) listen to the signal. The change takes effect within one frame. It is allowed on Title, Settings and Pause. Pause is outside the tick loop, so no gameplay tick is affected. An unsupported code is rejected and the current language is kept.
17. **`format_int(n)`** (F1) returns a Unicode string in the current language's digit set, grouped in threes with `,`. It is the only way a number becomes text. Score, chain, percent, lives overflow `+N`, tally rows, high-score table ranks, continue countdown, stage numbers all use it.
17a. *(Added 2026-11-03, wave 3b, [Era shift 19](era-shift-and-plane-evolution.md).)* **`format_plain(n)`** returns the digits of `n` in the current language's digit set with **no grouping** (a year must print "1941", not "1,941"); it maps to the same atlas cells. Era keys: `era.name.1941`, `era.name.1970s`, `era.name.2030s`, `era.name.2100` (bilingual, `text_both`), `era.card.skip` (single-language prompt), `era.error.load` (bilingual).
18. **Grouping is Western 3-digit (`999,999,999`) in both languages.** Indian (lakh/crore) grouping is supported by F1 behind the `digit_grouping` knob but is off. Reasons: the art bible fixes one grid for both digit sets and Scoring (8) specifies 9 digits plus separators; 3-digit grouping gives the same width in both languages (2 separators, not 3); arcade scores are compared across screenshots; and the Bengali reader of a 9-digit arcade score reads the digits, not a lakh figure.
19. **Bilingual strings** (`bilingual = true`, via `text_both`) return the `bn` string, a newline, then the `en` string, regardless of the current language. The Bengali line is always on top (art bible 7.3). Digits in a bilingual line follow the **chosen language**, not both. Always bilingual: title, **CRITICAL BREAK** banner, **WARNING** banner, boss name plates, tally row labels (`tally.row.*`), tally headers (`tally.header.*`) and the tally note `tally.note.boss_withdrew` *(amended 2026-11-03, Stage tally)*. Menus and settings are single-language.
20. **Pseudo-localisation:** a debug-only locale `qps` is generated at load from the `en` column (F4). It is unlocked by the debug flag `--pseudo-loc` and a Settings debug entry, and never ships in release builds. A second debug locale `qpb` fills Bengali slots with a conjunct stress string (Rule 28).
21. **Release gate (lint, CI):** the build fails if any key has an empty `bn` or `en` cell; any key lacks a `_meta` row; placeholders differ between languages; a cell has a digit, BOM, tab or manual break; a rendered string is wider than `max_width_px` in either language (measured with the real font, F5); a conjunct test string fails glyph coverage; or any non-NFC Bengali cell exists. (→ tools-programmer)

**Fonts and shaping**

22. **Font stack (shipped):** (1) the commissioned two-script pixel-grid face from art bible 8.8 (Latin + Bengali, with its outline variant); (2) a fallback to the same family for punctuation only. **No third-party fallback ships in UI.** GNU Unifont is allowed only in debug builds as a missing-glyph fallback (art bible 7.5).
23. **Interim fonts (until the commissioned face exists, all OFL):** Latin: Silkscreen or Pixelify Sans. Bengali: **Hind Siliguri Medium** (UI-tuned, even stroke) as first choice and **Noto Sans Bengali SemiBold** as second, both rendered with antialiasing off and hinting off. These are smooth outlines, not pixel-grid, so they are a stand-in for the conjunct and size spike, not shipped art. Licences are recorded in `assets/fonts/LICENSE` (OFL text plus copyright lines per font). *All font names, weights and licences here are unverified until the licence files are read.*
24. **Shaping needs Godot's advanced text server (HarfBuzz).** Bitmap fonts and the fallback text server do not reorder or ligate Bengali. *Unverified for 4.7 Web:* whether the official Web export template includes the advanced text server. This is spike S1 (Open Questions) and the top risk. Plan B and C are in Edge Cases. *(2026-11-03, ADR-0009:)* decided: TextServerAdvanced on every target incl. Web (gate S1), digit atlas, pixel-grid OTF + outline; Plan B pre-shaped runs, Plan C custom template. **Boot fallback:** if shaping is unavailable at boot, the game shows English words; digits (own atlas) are unaffected.
25. **Sizes** follow art bible 7.5: Bengali size = `ceil(Latin cap × 1.375)` (F7), with tiers S 12/17, XL 24/34 (XL is exactly 2× S). The conjunct gate can raise Bengali S to 18–20 px (knob `bn_size_s`). Sizes are integers only. Headroom is at least 4 px above the matra and the line box is `size + 7` px.
26. **Outline (hybrid, art bible 8.8):** HUD numerals come from the **pre-outlined digit atlas**; words use the font plus its outline variant drawn underneath. The atlas holds both digit sets on one fixed grid (F3). Localization maps each character returned by `format_int` to an atlas cell: `0-9`, `০-৯`, `,`, `x`, `+`, `%`, `:`, `/`. *(Amended 2026-11-03, HUD 20 Rule 12:)* the atlas ships five numeral tiers, D24, D17, D16, D12 (digit 12, cell 8, sep 3) and D10 (digit 10, cell 6, sep 2); the cell map, including `+` and `%`, exists in every tier. D12 and D10 Bengali digits are a numeral-only exception below the 17 px minimum (HUD Open Question 1).
27. **Pre-warming:** all banner, boss-name and tally strings for the next stage are shaped and cached at stage load, in the current language and in both (bilingual strings). No Bengali text is shaped for the first time during a fight. In-fight text is atlas digits only.
28. **Conjunct test set** (lint and visual spike): `ক্ষ`, `শ্রী`, `ঙ্গ`, `ত্র`, plus `র‍্য` (ZWJ), `ক্ষ্ম`, `দ্ব`, `স্ত্র`, a pre-base vowel sign (`কি`, `কে`), a reph (`র্ক`) and khanda ta (`ৎ`). Pass means every glyph is present (no .notdef box), the matra is unclipped with the 1 px outline on, and each conjunct is distinguishable at 1x. The `qpb` locale renders this set in every label.

**Process**

29. **Workflow:** developer adds a key and `en` text with a `_meta` row (status `new`) → extraction exports `new`/`changed` rows with screenshot, context and `max_width_px` (→ tools-programmer) → translator fills `bn` → a second native Bengali speaker reviews → rows become `reviewed` → import → locale test pass → `frozen`.
30. **Glossary:** `design/localization/glossary.md` (to be created) is the single source of truth for game terms: Chain, Critical Break, Drone, Bomb, Plane, Era, Lives, Combo/Hit, plane names, boss names. Each has the approved Bengali. Decision on whether to **translate or transliterate** terms like "Critical Break" is the translator's, signed off by the writer (→ Open Questions). Glossary terms are not written by this GDD. *Glossary pair requested by Menus (22) and Stage tally (21), 2026-11-03 (wave 5 batch 2):* **"ALL CLEAR"** (the Stage tally's end-of-run banner, `stage-end-tally.md`) and **"MISSION COMPLETE"** (`menu.results.ending`, the Results verdict) are **two distinct terms**, not synonyms, and must not be merged into one Bengali phrase by a translator. The glossary carries both rows with that note. *Glossary keys requested by Bombs (12), 2026-11-03:* `bomb.name` ("Bomb"), `bomb.lancer.name` ("Lance Sweep"), `bomb.leech.name` ("Barb Burst"); Bengali by the translator (translate vs transliterate: Open Question 4).
31. **String freeze:** after the Vertical Slice content lock, strings are frozen in two steps. **Soft freeze** (end of Vertical Slice): no new keys without a ticket; `en` edits go through the translator. **Hard freeze** (two weeks before the release candidate): no key or `en` change, only fixes to `bn` typos and fit failures. A hard-frozen key can only change by a ticket approved by the producer.

**Cultural content check (WW2 / Bengal setting)**

32. Every text and art release passes this checklist, owned by Localization with `writer` and `art-director`:

| Item | Rule |
|---|---|
| Real insignia and flags | No swastika or real Axis insignia (illegal to display in some markets and sensitive everywhere). No Rising Sun flag or roundel. Use fictional roundels and tail marks. Allied-style markings are also fictional. Note for art: this includes bosses, debris, stage props and the title. |
| Faction names | Enemies are not named after a real nation or its people in any string. |
| Historical references | Chittagong and Calcutta were bombed in 1942–43 (art bible 3.1). Do not use the 1943 Bengal famine or civilian casualties as flavour or humour. |
| Humour and idiom | No puns that only work in English. No Bengali slang that is region-specific. |
| Religion and symbols | No religious imagery or script on planes, pickups or scenery. |
| Colours | Red is Alarm only (art bible 4.6); no flag colour combinations as faction marks. |
| Names | No real commanders or pilots. Character names are checked by a native Bengali speaker for unintended meanings. |
| Title logo | Bengali lettering gets native-speaker review (art bible 8.8). |

> Decided under auto-approve (2026-11-03): CSV over PO; one `bn` locale; Western 3-digit grouping in both languages; bilingual strings are Bengali-over-English with digits following the chosen language; named placeholders only; no digits inside translations; two-key plural scheme; NFC storage; OS-locale default stored as an explicit choice; Hind Siliguri then Noto Sans Bengali as interim OFL fonts; debug-only `qps` and `qpb` locales; two-step string freeze.

### States and Transitions

The language state is per application, not per run.

| State | Meaning | Enter | Exit |
|---|---|---|---|
| Unresolved | Autoload loaded, no language chosen yet | App start | `resolve_language` runs (F2) |
| Active(bn) | Bengali strings and Bengali digits | Resolved to `bn`, or `set_language("bn")` | `set_language("en")` |
| Active(en) | English strings and Western digits | Resolved to `en`, or `set_language("en")` | `set_language("bn")` |
| Active(pseudo) | Debug `qps` or `qpb` | Debug flag only | Any `set_language` call |

Transitions:
- Unresolved → Active(x): at boot, using the saved choice if Save (26) has loaded, else the OS locale (F2). The first successful resolution is written back through Save (26).
- Active(x) → Active(y): `set_language(y)`. Emits `language_changed(y)` once. Calling it with the current code does nothing and emits nothing.
- Pause or menu open is irrelevant to this state machine.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| HUD (20) | Localization → HUD | `format_int(n)` for score, chain, `%`, `+N`; the atlas cell map (Rule 26); `language_changed` to re-render digits. The HUD never formats a number itself. |
| Stage-end tally (21) | Localization → Tally | `text_both(key)` for row labels (`tally.row.*`), `format_int` for values. Scoring (8) source labels are keys (scoring.md, Interface section). |
| Menus, title and plane select (22) | Both | Menus use `text(key)` and the language toggle calls `set_language`. The title logo uses the two art layers `logo_title_bn` / `logo_title_en`, not a string. |
| Save, settings and high scores (26) — [GDD](save-settings-high-scores.md) | Both | Save stores `settings.language` (`bn`/`en`) and calls `set_language` when settings load. Localization writes the first resolved value back via Save's request method. |
| Accessibility (28) — [GDD](accessibility-options.md) | Both | Text-size step-up asks `font_size_px(tier, step)`; Localization owns the table. Step values (2026-11-03, Accessibility F1): steps 0-3 = 100/125/150/200 % for S and M tiers only, Latin cap 12/15/18/24, Bengali 17/21/25/33 (`max(ceil(cap x 11 / 8), bn_size_s)`); L and XL are identity at every step. |
| Boss (14) | Boss → Localization | Boss data holds `name_key`; the name plate calls `text_both`. |
| Scoring (8) | Scoring → Localization | Scoring emits keys and integers only; display clamp stays in Scoring F8. |
| Game events and session (1) | None | Localization does not subscribe to or emit gameplay events. |
| Audio (24) — [GDD](audio.md) | None at MVP | There are no voice lines. The warning siren is language-neutral. A future Voice bus needs a language-audio rule. |
| Tutorial (30) — [GDD](tutorial.md) | Tutorial → Localization | `text`, `text_both`, `format_int`, `font_size_px`; `tut.*` keys in `ui_tutorial.csv`; glyph-token arguments (Rule 5). |
| Touch controls (31) — [GDD](touch-controls.md) | Touch → Localization | `ui.touch.*` / `opt.touch_*` string keys (`touch.*` is reserved for Save setting keys; renamed 2026-11-03); `format_int` for the Bomb numeral (Bengali digits in Bengali). |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | 32 → Localization | `ui_online.*`, `ui_rush.*` keys; reason code → localized line; handles stay Latin. |

## Formulas

**F1. Number formatting (`format_int`)**

`digits = str(abs(n)); groups = split digits from the right into runs of g (first run of 3 for WESTERN: all runs 3; INDIAN: first run 3 then runs of 2); out = join(groups, ","); if lang == bn: map each ASCII digit d to U+09E6 + d`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Value | n | int | 0 to 999,999,999 (display clamp from Scoring F8) | The number to show |
| Language | lang | enum | bn, en | Current language |
| Grouping | g | enum | WESTERN, INDIAN | Config `digit_grouping` (default WESTERN) |
| Separator | , | char | `,` | Same in both languages |

**Output Range**: a string of 1 to 11 characters for WESTERN (9 digits + 2 separators); 1 to 12 for INDIAN. A negative `n` is a bug: debug asserts, release shows `0`.

**Example**: `format_int(1234567)`: en WESTERN `1,234,567`; bn WESTERN `১,২৩৪,৫৬৭`; en INDIAN `12,34,567`. `format_int(999999999)` en WESTERN `999,999,999`; INDIAN `99,99,99,999`. `format_int(0)` en `0`, bn `০`.

**F2. Language resolution (`resolve_language`)**

`lang = saved if saved in {bn, en} else base(os_locale) if base(os_locale) in {bn, en} else en; base(x) = lower(first token of x split on _ - @ .)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Saved language | saved | string or empty | bn, en, "" | From Save (26) |
| OS locale | os_locale | string | any | `OS.get_locale()` result |

**Output Range**: `bn` or `en`.

**Example**: saved "" and `bn_BD` → `bn`. saved "" and `en_US` → `en`. saved "" and `fr_FR` → `en`. saved `en` and `bn_IN` → `en` (saved wins). saved "xx" and `bn` → `bn` (invalid saved is ignored).

**F3. Digit-atlas grid**

`cell_w = ceil(cell_ratio × h); sep_w = round(0.4 × cell_w); plate_w = digits × cell_w + seps × sep_w`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Digit height | h | int px | 10 to 34 | Bengali digit height at the tier (17 for S/M; 16, 24 for L; 12 and 10 for the HUD tiers D12 and D10, added 2026-11-03) |
| Cell ratio | cell_ratio | float | 0.5 to 0.7 | Knob; default 0.6 (proposal, confirm in the font spike) |
| Digits, separators | digits, seps | int | 0 to 9, 0 to 2 | Count in the string |

**Output Range**: `cell_w` 6 to 15 px at defaults (10 to 15 before the HUD tiers); both digit sets use the same cell.

*(Amended 2026-11-03, wave 5 batch 2, [Menus (22)](menus-title-plane-select.md) Visual/Audio "Results" row:)* the **3-4P Results score plates** use **D12** - 9 digits, Western grouping, `9 x 8 + 2 x 3 = 78 px` - with a **D10 fallback applied to all columns together** (never one column at a time, so the four plates stay the same width). Two numbers are **unconfirmed and belong to the font spike**: the **D10 plate width** at 9 digits plus 2 separators, and the **INDIAN-grouping case**, which adds a third separator and gives `9 x 8 + 3 x 3 = 81 px` at D12 - 3 px over the D12 budget. INDIAN grouping is off by default (Rule 18), so this only matters if `digit_grouping` is ever turned on.

**Example**: S tier, h = 17: `cell_w = ceil(10.2) = 11`, `sep_w = round(4.4) = 4`. A 9-digit score: `9 × 11 + 2 × 4 = 107 px`. L tier, h = 24: `cell_w = ceil(14.4) = 15`; a 3-digit chain `3 × 15 = 45 px`, inside the 84 px inner width of a 96 px plate. L tier h = 16 (3–4P): `cell_w = ceil(9.6) = 10`; 3 digits = 30 px. HUD tiers (HUD 20, 2026-11-03): h = 12: `cell_w = ceil(7.2) = 8`, `sep_w = round(3.2) = 3` (9-digit score `9 × 8 + 2 × 3 = 78 px`); h = 10: `cell_w = 6`, `sep_w = round(2.4) = 2` (`100%` = 4 × 6 = 24 px).

**F4. Pseudo-localisation (`pseudo`)**

`pad = (len(en) × bn_width_reserve_pct + 99) div 100; out = "[" + accent(en) + "~" × pad + "]"`, where `accent` replaces vowels with accented Latin-1 forms and keeps `{placeholders}` untouched.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| English length | len(en) | int | 1 to 80 | Characters in the `en` cell, placeholders counted as written |
| Reserve | bn_width_reserve_pct | int | 40 | Art bible 7.5 (+40% width) |

**Output Range**: `len(en) + pad + 2` characters, about 1.4× the source plus brackets.

**Example**: `START` (5): `pad = (5 × 40 + 99) div 100 = 2`; output `[STÅRT~~]`, 9 characters. `GAME OVER` (9): `pad = (360 + 99) div 100 = 4`; 15 characters.

**F5. Text-fit check (lint and layout)**

`fits = measure_px(text, tier) <= max_width_px; box_min_px = (en_px × (100 + bn_width_reserve_pct) + 99) div 100`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Rendered width | measure_px | int px | 0 to 360 | Real font, real size, with the outline (+2 px) |
| Box width | max_width_px | int px | 12 to 328 | From `_meta` |
| English width | en_px | int px | 0 to 328 | Measured `en` string |

**Output Range**: bool; `box_min_px` is a layout guide so a box holds Bengali when it holds English.

**Example**: an English label measuring 60 px needs a box of at least `(60 × 140 + 99) div 100 = 84 px`. A Bengali string measuring 91 px in an 84 px box fails the lint.

**F6. Plural form (`plural_form`)**

`en: one if n == 1 else other; bn: one if n in {0, 1} else other`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Count | n | int | 0 to 999,999,999 | The quantity |
| Language | lang | enum | bn, en | Current language |

**Output Range**: suffix `_one` or `_other`.

**Example**: n = 0: en `_other`, bn `_one`. n = 1: both `_one`. n = 2: both `_other`.

**F7. Bengali size and line box**

`bn_size = (cap × 11 + 7) div 8 (= ceil(cap × 1.375)); line_box = size + 7`; the XL tier overrides to `2 × bn_size(12)`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Latin cap height | cap | int px | 12 to 24 | Tier cap height |
| Size | size | int px | 17 to 34 | Chosen font size |

**Output Range**: S 17 px (line box 24); L 16 → 22, 24 → 33; XL 34 (line box 41), Latin XL line box = 24 + 7 = 31.

**Example**: cap 12: `(132 + 7) div 8 = 17`. cap 16: `(176 + 7) div 8 = 22`. cap 24: `(264 + 7) div 8 = 33`, but XL words use 34 (exact 2× S), so the formula applies to numerals and S/M only.

## Edge Cases

- **If the `bn` cell is empty or missing at runtime**, `text()` returns the `en` string and logs the key once; in a release build this cannot pass the lint (Rule 21).
- **If both cells are missing**, debug shows `⚠` and logs; release shows an empty string and logs. No key text is ever drawn.
- **If `set_language` gets an unsupported code**, it returns false, keeps the current language, and emits nothing.
- **If `set_language` is called with the current language**, nothing happens and no signal is emitted.
- **If the saved language is invalid or the file is missing**, F2 runs with `saved = ""` and the result is saved.
- **If the OS locale is empty or unparsable**, the language is `en`.
- **If the Web browser reports `bn` or `bn-BD`**, the language is `bn`. *Unverified on 4.7 Web:* what `OS.get_locale()` returns in the browser.
- **If the advanced text server is not in the Web export (spike S1 fails)**, ship Plan B: pre-shape every Bengali string at import into a glyph-ID sequence in a private-use range, rendered by the fallback server from a font whose glyphs are keyed to those codepoints. Plan C: build a custom Web template with `text_server_adv`. Plan B changes the pipeline (→ ADR). Plan C costs build size and engine maintenance. Plan B is preferred if S1 fails, because it also shapes once instead of per frame.
- **If a translated string is wider than its box at runtime**, the Label wraps on spaces and the plate grows downward, to at most 3 lines. It is never clipped and never shrinks the font. The lint should have caught it (Rule 21).
- **If a banner's Bengali line wraps**, both lines keep equal tier size; the English line is not enlarged to match.
- **If a word contains a conjunct and the 1 px outline fills its gaps at 17 px**, raise `bn_size_s` to 18, then 19, then 20 (art bible 7.5 gate). The outline is not removed.
- **If `format_int` gets a value above 999,999,999**, it formats the value it is given (up to int64). The 9-digit clamp is Scoring's (F8), applied before the call.
- **If `format_int` gets a negative value**, release returns the format of `0` and logs; debug asserts.
- **If the language changes while a banner is on screen**, the banner re-renders on the next frame. A bilingual banner changes only its digits. A single-language menu string changes fully.
- **If the language changes while the HUD shows `1,234`**, the same cells now draw `১,২৩৪`. Width is unchanged because the grid is shared (F3).
- **If a translator uses a Bengali digit or an ASCII digit in a cell**, the lint fails the build.
- **If a placeholder is missing from a translation**, the lint fails the build. At runtime, `String.format` leaves the unreplaced `{name}` text out of the result and logs the key.
- **If two players share a screen**, they share one language. There is no per-player language.
- **If a font file fails to load**, the debug Unifont fallback is used in debug builds; in release the build is invalid (the font is a `res://` dependency, not an external file).
- **If a high-score name entry needs letters**, only Latin `A-Z`, `0-9` and a few symbols are offered at MVP (→ Open Questions). Bengali names are not entered.
- **If a date must be shown**, it is `DD/MM/YYYY` with the current language's digits. No date is shown at MVP.
- **If a locale has no `.translation` resource loaded** (import failed), startup logs an error and uses `en` strings from the table directly, never an empty UI.

## Dependencies

**Upstream (this system depends on):**

| System | Hard/Soft | Interface |
|---|---|---|
| Save, settings and high scores (26) — [GDD](save-settings-high-scores.md) | Soft | Provides the saved `settings.language`. Without it the OS locale decides every run. |
| Art bible (7.5, 8.8, 8.9) | Hard (document) | Font tiers, outline method, digit-atlas rule, conjunct test, spike list. |
| Godot `TranslationServer`, `TextServer` | Hard (engine) | Locale lookup and Bengali shaping. *Unverified for 4.7 Web.* |

**Downstream (these depend on this system):**

| System | Hard/Soft | Interface |
|---|---|---|
| HUD (20) — [GDD](hud.md) | Hard | `format_int`, atlas cell map, `language_changed`. |
| Stage-end tally (21) — [GDD](stage-end-tally.md) | Hard | `text_both`, `format_int`, `tally.row.*` keys. |
| Era shift and plane evolution (19) — [GDD](era-shift-and-plane-evolution.md) | Soft | `format_plain` (year ticker), `era.name.*`, `era.card.skip`, `era.error.load`. |
| Menus, title and plane select (22) — [GDD](menus-title-plane-select.md) | Hard | `text`, `set_language`, `get_language`, language toggle. |
| Save, settings and high scores (26) — [GDD](save-settings-high-scores.md) | Hard | Stores and restores the language; calls `set_language`. |
| Accessibility (28) — [GDD](accessibility-options.md) | Soft | `font_size_px(tier, step)` for the text-size step-up. |
| Scoring (8), has GDD | Soft | Source labels are keys; Scoring does not format text. |
| Boss (14) — [GDD](boss-and-boss-parts.md) | Soft | `name_key` fields. |
| Critical Break (17) — [GDD](critical-break.md) | Soft | `banner.critical_break` bilingual banner. The CB score popup uses atlas digits and an icon, no text. |
| Plane kits Sentry, Breaker (29) — [GDD](plane-kits-sentry-breaker.md) | Soft | `plane.sentry.*`, `plane.breaker.*` card keys. |
| Tutorial (30) — [GDD](tutorial.md) | Soft | `ui_tutorial.csv` (`tut.*`), glyph tokens. |
| Touch controls (31) — [GDD](touch-controls.md) | Soft | `ui_touch.csv` (`ui.touch.*`, `opt.touch_*`). |
| Online leaderboards, boss rush (32) — [GDD](online-leaderboards-boss-rush.md) | Soft | `ui_online.csv`, `ui_rush.csv`. |

**Amendments to other docs** (the main session applies these):

1. `design/gdd/systems-index.md`, row 27: status `**Designed** (pending review) — [GDD](localization.md)`; "Depends on" stays `—` (Save (26) is a soft, provisional input only). Progress tracker: GDDs written +1.
2. `design/gdd/systems-index.md`, "Open items carried over": remove "language split (ADR)" (decided: both languages for all text, bilingual for title/banners/names/tally).
3. `design/gdd/systems-index.md`, bidirectional reminder: add system 27 (Localization) to the list of docs that must name `format_int` / `text` as their interface: HUD (20), Tally (21), Menus (22), Save (26), Accessibility (28).
4. `design/art/art-bible.md` 8.8 digit atlas: add the group separator `,` to the atlas character list (`0-9`, `০-৯`, `x + % : /`), as `format_int` emits it.
5. `design/art/art-bible.md` 7.5 tier table: note that cap 24 gives Bengali 33 by the 1.375 rule but the XL tier is fixed at 34 (exact 2× S). Add the digit cell sizes of F3 as proposals.
6. `design/gdd/scoring.md` F8 / HUD note and AC-47 area: state that separators are `,` Western 3-digit grouping in both languages, and that Scoring's `display_score` result is passed to `Localization.format_int`.
7. `design/gdd/game-events-and-session.md`: no change. (Localization does not use the event bus.) Note in the HUD GDD that `language_changed` is on the `Localization` autoload, not on `GameEvents`.
8. HUD (20) GDD: score and chain numerals go through `format_int` and the atlas; no string concatenation of numbers; no word labels in the fight HUD.
9. Boss (14) GDD: boss and part names are `name_key` fields; the name plate uses `text_both`.
10. *(Done 2026-11-03: `critical-break.md` exists; its popup uses atlas digits and an icon, no text.)* Critical Break (17) GDD: the banner key is `banner.critical_break`; the English source text is `CRITICAL BREAK`; the Bengali is set by the translator and the glossary.
11. Menus (22) GDD: Settings has a language toggle (`menu.settings.language.*`), the title has a quick toggle, and destructive confirms use keys.
12. Save (26) GDD: persist `settings.language` as `bn` or `en`; call `Localization.set_language` on load; first-run result is written back.
13. Accessibility (28) GDD: text-size step-up uses `font_size_px(tier, step)`; steps must be integer sizes authored per tier.

## Tuning Knobs

| Knob | Default | Safe range | Too low | Too high | Interacts with |
|---|---|---|---|---|---|
| `default_language_fallback` | `en` | bn, en | n/a | n/a | F2 (used when OS locale is unsupported) |
| `digit_grouping` | WESTERN | WESTERN, INDIAN | n/a | n/a | F1, F3 plate width (INDIAN adds 1 separator at 9 digits) |
| `bn_width_reserve_pct` | 40 | 30–60 | Bengali clips in boxes designed from English | Boxes waste HUD space | F4, F5, every text box |
| `bn_size_s` | 17 px | 17–20 | Conjuncts clipped or filled by the outline | Wider text, taller line box | F7, F3 cell width, `bn_width_reserve_pct` |
| `cell_ratio` | 0.6 | 0.5–0.7 | Digits crowd or overlap | Plate too wide | F3, HUD plate width (Row A budget) |
| `sep_ratio` | 0.4 | 0.3–0.5 | Groups hard to separate | Score plate too wide | F3 |
| `banner_max_lines` | 3 | 2–4 | Long Bengali is clipped | Plate covers the field | Edge case on wrapping, banner rule (art bible 7.4) |
| `pseudo_enabled` | false (release) | debug only | n/a | Pseudo text visible to players | Rule 20 |
| `warn_on_missing_key` | true | bool | Missing strings go unnoticed | Log spam | Rule 4 |

Rationale: `bn_width_reserve_pct = 40` and `bn_size_s = 17` come from art bible 7.5. `cell_ratio` 0.6 is a proposal: a Bengali digit is usually a little over half an em wide, so 0.6 of its height leaves room for the outline (2 px). It is confirmed in the font spike.

**Owned elsewhere:** font tier cap heights and the outline method (art bible 7.5, 8.8); display clamp 999,999,999 (`score_display_digits`, Scoring F8); strip heights and plate sizes (art bible 7.2, 7.3); the text-size step values (Accessibility 28); where the language is stored (Save 26).

## Visual/Audio Requirements

- **Layers:** banners draw at layer 11 and only when the field is clear (art bible 7.4 banner rule). In-fight text is the digit atlas only (HUD layer). Menu text draws on the menu layer. Nothing here draws over enemy bullets (layer 8).
- **Text colours:** Cream text on Char for menus (7:1 or better), Ember Gold for score, chain and banners. Outline `#14110E`, 1 px, all 8 sides. Never Void Indigo or Ink for text. Use the colour names from art bible 4.7; exact hex values are not repeated here.
- **Sizes:** S 12 px Latin / 17 px Bengali; XL 24 / 34 px; numerals 16–24 px (F3, F7). Integer sizes, integer positions, no scaling.
- **CRITICAL BREAK banner:** the art bible places it in the upper third, held 0.5 s with 6-frame ease in and out (art bible 7.3). Layout: Char plate; Bengali line on top at XL 34 px (line box 41 px), English below at XL 24 px cap (line box 31 px), equal weight; stack height 72 px plus 8 px padding top and bottom = **88 px** plate height; inner width 312 px on a 328 px plate. Ember Gold fill with the outline. "Reduce flashing" keeps the banner (art bible 7.3).
- **WARNING banner:** bilingual plate "সতর্কতা / WARNING" (art bible 7.4), same two-line layout, pulse within art bible 7.7.
- **Digits:** both sets pre-outlined on the shared grid; no tween blur on language switch; the swap is a single-frame redraw.
- **Audio:** no spoken language at MVP; no localised audio assets. If a voiced announcer is added later, it needs a new language-audio rule (→ Open Questions).
- **Never:** a text label on a plane, a bullet or an enemy; a number floating over the play field (art bible 7.7).

## UI Requirements

Localization owns no screen of its own, but it needs these elements from other screens:

| Element | Screen | Requirement |
|---|---|---|
| Language toggle | Title, Settings | Two options, `বাংলা` and `English`, each always written in its own script (not translated), focusable with the 3 px Cream border plus arrow glyph. Takes effect immediately with no restart. |
| Text-size step | Settings (Accessibility 28) | Uses `font_size_px`. |
| Debug pseudo-locale entry | Settings (debug builds only) | Switches to `qps` and `qpb`. |
| Missing-glyph indicator | Debug overlay | Shows `⚠` and the key. |

📌 **UX Flag**: run /ux-design for the Settings screen language toggle and the Title screen quick toggle before writing epics.

## Acceptance Criteria

**Defaults used:** supported languages `bn`, `en`; `digit_grouping` WESTERN; `bn_width_reserve_pct` 40; `bn_size_s` 17; `cell_ratio` 0.6; `sep_ratio` 0.4; `banner_max_lines` 3; CSV area files as in Rule 5.

**Test setup:** formatter, resolver, pseudo-localiser, plural and key-linter classes are node-free `RefCounted` classes with no `Node` or engine singleton in their API (the OS locale string and the CSV text are passed in). Tests live in `tests/unit/test_localization_*.gd` in the `extends SceneTree` style of `tests/unit/test_chain_tracker.gd`; knob values are read from `data/localization/localization_config.tres`, not copied into tests. There is no RNG in this system, so determinism is checked by repeated identical calls. The text-server and font criteria are Manual because they need the exported build.

- **AC-01 [Unit] (Rule 1):** `LocalizationConfig.supported` equals `["bn", "en"]` and has exactly 2 entries.
- **AC-02 [Unit] (Rule 2):** `resolve("", "bn_BD")` → `bn`; `resolve("", "bn_IN")` → `bn`; `resolve("", "bn")` → `bn`.
- **AC-03 [Unit] (F2):** `resolve("", "en_US")` → `en`; `resolve("", "fr_FR")` → `en`; `resolve("", "")` → `en`; `resolve("", "ja")` → `en`.
- **AC-04 [Unit] (F2):** `resolve("en", "bn_IN")` → `en`; `resolve("bn", "en_US")` → `bn`; `resolve("xx", "bn")` → `bn`.
- **AC-05 [Unit] (Rule 3):** `resolve("", "BN-bd")` → `bn` (case and separator tolerant).
- **AC-06 [Unit] (Rule 4):** with `bn` empty and `en` = "Start", `text(key)` in `bn` → "Start" and the miss is logged exactly once after 5 calls.
- **AC-07 [Unit] (Rule 4):** with both cells empty, debug returns `⚠` and release returns `""`; neither equals the key in any case.
- **AC-08 [Unit] (F1):** `format_int(1234567)` en → `1,234,567`; bn → `১,২৩৪,৫৬৭`.
- **AC-09 [Unit] (F1):** `format_int(0)` en → `0`; bn → `০`. `format_int(999)` → `999`; `format_int(1000)` → `1,000`.
- **AC-10 [Unit] (F1):** `format_int(999999999)` en → `999,999,999` (11 characters); bn → `৯৯৯,৯৯৯,৯৯৯`.
- **AC-11 [Unit] (F1, Rule 18):** with `digit_grouping = INDIAN`, `format_int(123456789)` en → `12,34,56,789`; `format_int(1234567)` → `12,34,567`.
- **AC-12 [Unit] (F1):** `format_int(-5)` release → `0`; debug build asserts.
- **AC-13 [Unit] (F1):** every character of `format_int(n)` for 1000 values of n sampled evenly from 0 to 999,999,999 is either in `০-৯`, `0-9` or `,`, and never mixes digit sets in one string.
- **AC-14 [Unit] (determinism):** 1000 repeated calls of `format_int(1234567)` return the identical string.
- **AC-15 [Unit] (F3):** `cell_w(17) = 11`, `sep_w(11) = 4`, `plate_w(9, 2) = 107`.
- **AC-16 [Unit] (F3):** `cell_w(24) = 15`; `cell_w(16) = 10`; 3 digits at h = 24 → 45 px, at h = 16 → 30 px.
- **AC-17 [Unit] (Rule 26):** the atlas map returns a cell index for each of `0-9`, `০-৯`, `,`, `x`, `+`, `%`, `:`, `/` and the same cell width for `5` and `৫`.
- **AC-18 [Unit] (F4):** `pseudo("START")` has 9 characters and starts with `[` and ends with `]`; `pseudo("GAME OVER")` has 15 characters.
- **AC-19 [Unit] (F4):** `pseudo("Score: {n}")` keeps the substring `{n}` unchanged.
- **AC-20 [Unit] (F5):** `box_min(60) = 84`; `box_min(0) = 0`; `box_min(100) = 140`.
- **AC-21 [Unit] (F6):** `plural(en, 0)` → other; `plural(en, 1)` → one; `plural(en, 2)` → other; `plural(bn, 0)` → one; `plural(bn, 1)` → one; `plural(bn, 2)` → other.
- **AC-22 [Unit] (F7):** `bn_size(12) = 17`, `bn_size(16) = 22`, `bn_size(24) = 33`; `line_box(17) = 24`.
- **AC-23 [Unit] (Rule 7):** the key regex accepts `banner.critical_break`, `tally.row.max_chain`, rejects `Banner.Critical`, `menu`, `menu..x`, `menu.Start`, and a 49-character key.
- **AC-24 [Unit] (Rule 8, 21):** a key with no `_meta` row fails the lint; adding the row passes it.
- **AC-25 [Unit] (Rule 10, 21):** `{n}` in `en` but missing in `bn` fails the lint; `%s` anywhere fails.
- **AC-26 [Unit] (Rule 11, 21):** a cell containing `3` or `৩` fails the lint; the same cell with `{n}` passes.
- **AC-27 [Unit] (Rule 5, 21):** a file starting with a BOM (EF BB BF) fails the lint; a file with a tab or a manual line break in a cell fails.
- **AC-28 [Unit] (Rule 13):** a Bengali cell containing U+09DC fails the NFC check; the same text as U+09A1 U+09BC passes.
- **AC-29 [Unit] (Rule 21):** a table where one key has an empty `bn` cell fails; a table with all cells filled passes.
- **AC-30 [Unit] (Rule 19):** `text_both("banner.warning")` returns `<bn>\n<en>` in both `bn` and `en` languages; the Bengali is the first line.
- **AC-31 [Unit] (Rule 19):** `text_both` with `{n}` filled uses the current language's digits in both lines.
- **AC-32 [Unit] (Rule 16):** `set_language("bn")` from `en` emits `language_changed` exactly once with `bn`; repeating it emits 0 more; `set_language("fr")` returns false, emits 0, and `get_language()` stays `bn`.
- **AC-33 [Unit] (Rule 16):** `set_language("en")` then `text("common.confirm")` returns the `en` value; after `set_language("bn")` it returns the `bn` value.
- **AC-34 [Unit] (Rule 20):** in a release configuration, `set_language("qps")` returns false.
- **AC-35 [Unit] (Rule 9):** the scene lint finds 0 quoted player-facing strings in `src/**/*.gd` and `data/**/*.tres` (allow-list: key strings and debug-only labels).
- **AC-36 [Unit] (Rule 14):** for every `<key>_one` there is a `<key>_other` in both languages.
- **AC-37 [Integration] (Rule 15, 26):** with the HUD scene loaded and score 1,234,567, `set_language("bn")` redraws the score as `১,২৩৪,৫৬৭` within 1 frame, and the plate rectangle is unchanged (same x, width).
- **AC-38 [Integration] (Rule 2, 3):** Save (26) stub returns `""` and OS locale `bn_BD`: after boot `get_language() == "bn"` and the stub receives one write of `bn`. A second boot with the stub returning `bn` and OS locale `en_US` stays `bn`.
- **AC-39 [Integration] (Rule 16):** changing language from Pause during a run does not change the session tick counter, the score, or the RNG state.
- **AC-40 [Perf] (Rule 17):** `format_int` costs at most 20 µs per call on REF-WEB (budget to be confirmed on first measurement) and the HUD calls it only when the displayed value changes: 0 calls over 600 ticks with a constant score.
- **AC-41 [Perf] (Rule 27):** the first shaping of a Bengali banner string happens at stage load, not during a fight: 0 text-shaping cache misses recorded between stage start and boss death.
- **AC-42 [Manual] (Rule 24, spike S1):** a Web export of Godot 4.7 renders `কি`, `কে`, `র্ক`, `ক্ষ`, `শ্রী`, `ঙ্গ`, `ত্র`, `র‍্য`, `ৎ` correctly with the pre-base vowel in front and reph on top. Record the Web build size with and without the advanced text server. Evidence: screenshot plus size table.
- **AC-43 [Manual] (Rule 28):** the conjunct test set at 17 px, 1x, outline variant on: no `.notdef` boxes, no clipped matra, 4 px headroom present, every conjunct distinguishable. Evidence: 1x screenshot reviewed by a Bengali reader. If it fails, `bn_size_s` is raised and the test repeated.
- **AC-44 [Manual] (Rule 25):** Bengali text in S tier measured to be at most 17 px tall in glyph box and the XL banner at 34 px, with a 4 px clear band above the headline bar.
- **AC-45 [Manual] (Rule 19, banner):** the CRITICAL BREAK banner at 1P, 2P and 4P shows Bengali above English at equal weight, plate height 88 px, no clipping, held 0.5 s. Evidence: screenshots.
- **AC-46 [Manual] (qps):** boot with `--pseudo-loc` and open every screen: no clipped text, no overflow outside a plate, no raw key, and accented Latin glyphs all render. Evidence: screenshot per screen.
- **AC-47 [Manual] (qpb):** every label shows the conjunct set without a missing glyph at its tier.
- **AC-48 [Manual] (Rule 16, art bible 8.8 test):** switch language on every screen: every string and digit changes, no PNG re-export is needed, and no element moves.
- **AC-49 [Manual] (Rule 32):** the cultural checklist is completed and signed for the title, bosses and banners by the writer, an art director and a native Bengali reviewer. Evidence: signed checklist.
- **AC-50 [Manual] (Rule 29):** every key in the Vertical Slice build has status `reviewed` or `frozen`, reviewed by a second native Bengali speaker. Evidence: `_meta.csv`.
- **AC-51 [Manual] (Rule 23):** `assets/fonts/LICENSE` contains the licence text for every shipped font and every font file has a matching entry.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | Spike S1: does the official 4.7 Web template include the advanced text server, and what is the size cost? If not, choose Plan B (pre-shaped glyph IDs) or C (custom template) via ADR. **2026-11-03:** ADR-0009 written (gate S1 decides Plan A/B/C; boot fallback to English words, digits unaffected). Spike still to run. | godot-specialist | Before any Bengali UI art is finalised (art bible 8.9 spike 2) |
| 2 | Does Hind Siliguri or Noto Sans Bengali pass the conjunct test at 17 px with the outline variant? If neither, raise `bn_size_s` or commission the face. | art-director + ui-programmer | Font spike |
| 3 | Who is the Bengali translator and the second reviewer? Budget for the commissioned two-script face. | producer | Before Vertical Slice content lock |
| 4 | Translate or transliterate "Critical Break", "Chain", "Drone", "Bomb", and the bomb names "Lance Sweep" / "Barb Burst" (Bombs (12))? | writer + native translator | Glossary draft, before string soft freeze |
| 5 | Confirm Western 3-digit grouping in both languages, or switch Bengali to lakh grouping (`digit_grouping`). | user | Before HUD (20) GDD |
| 6 | Confirm the digit-cell proportions (0.6 and 0.4) once the real face exists. | art-director | Font spike |
| 7 | ~~High-score name entry: Latin-only initials, or Bengali letters too?~~ **Closed 2026-11-03:** Latin-only initials, 38-character wheel `A-Z0-9-.` (Save Rule 12, Menus Rule 36). (menus-title-plane-select.md) | ux-designer + Save (26) | Menus (22) GDD |
| 8 | ~~Text-size step-up: which integer sizes per tier at step 1 and 2?~~ **Closed 2026-11-03:** Accessibility F1 table — S/M Latin 12/15/18/24, Bengali 17/21/25/33 at steps 0-3; L and XL identity (accessibility-options.md F1). | Accessibility (28) | Accessibility GDD |
| 9 | Is PO needed once plurals or a third language appear? | localization-lead | If a third language is proposed |
| 10 | Does Godot 4.7 import the CSV with the extra metadata, and does `OS.get_locale()` on Web report the browser language? | godot-specialist | Spike S1 |
| 11 | Store page text, trailer captions, and the title logo Bengali lettering review: who owns them? | producer | Before release candidate |
| 12 | ~~Are voice lines or a spoken announcer planned? If yes, a language-audio rule is needed.~~ **Closed 2026-11-03:** no voice lines at MVP; a future Voice bus needs a language-audio rule (audio.md). | audio-director | Audio GDD (24) |
| 13 | Where to put the glossary and the extraction tooling (`tools/`), and who builds the lint? | tools-programmer | Vertical Slice start |
