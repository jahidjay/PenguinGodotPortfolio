## 1. File written
`D:\Projects\GodotProjects\Morutjan\morut-jan\design\gdd\localization.md`. It has the required headings in order, 32 core rules, 7 formulas (F1-F7), 51 acceptance criteria, 13 open questions. I wrote only this file.

Summary: Localization is a string-and-number layer. Strings live in CSV tables and are looked up by key through TranslationServer. A thin `Localization` autoload resolves the language, switches it at runtime, and offers `text()`, `text_both()` (always Bengali over English) and `format_int()` (language-aware digits plus grouping). The logic classes (formatter, resolver, pseudo-localiser, linter) are node-free `RefCounted`. The doc also covers the font stack and shaping risk, the CRITICAL BREAK banner layout, a string-freeze process, and a cultural-content checklist for the WW2/Bengal setting. I did not write any Bengali translations.

## 2. Key decisions (for your review)
- **CSV, not PO.** One file per feature area (`data/localization/strings/*.csv`, columns `keys,en,bn`). Context, max width and status live in a sidecar `_meta.csv`. PO is the fallback if plurals or a third language appear.
- **Keys:** lower-case dot notation, a stable role name (never the English text), regex-checked, at most 48 characters.
- **Placeholders:** named `{n}` only. Translators never type digits; numbers arrive already formatted.
- **Plurals:** two keys, `_one` and `_other`. bn treats n=0 and n=1 as "one"; en treats only n=1 as "one". No HUD string needs one at MVP.
- **Default language:** saved choice, else OS locale (`bn*` gives Bengali, anything else gives English). The result is stored as an explicit value. A toggle on the title and in Settings fixes a wrong guess.
- **Fallback:** locale, then base language, then `en`. A raw key never shows. A miss shows `⚠` in debug and an empty string in release.
- **One Bengali locale (`bn`)**, standard colloquial Bengali, no region-specific vocabulary.
- **Digit grouping: Western 3-digit (`999,999,999`) in both languages.** Lakh grouping is supported in F1 behind a knob but off. Reasons: both digit sets share one grid, Scoring already specifies 9 digits plus separators, and it gives the same width in both languages.
- **Bilingual strings** (title, CRITICAL BREAK, WARNING, boss name plates, tally labels): Bengali on top, English below, always both. Digits in them follow the chosen language.
- **Fonts:** the shipped face is the commissioned two-script pixel-grid TTF from art bible 8.8. Interim OFL fonts are Hind Siliguri Medium (first) then Noto Sans Bengali SemiBold for Bengali, and Silkscreen or Pixelify Sans for Latin. Unifont is debug-only. Font names and licences are marked unverified.
- **Digit-atlas grid (proposal):** `cell_w = ceil(0.6 x digit height)`, separator = `round(0.4 x cell)`. At the S tier (17 px) that is an 11 px cell and a 9-digit score of 107 px. To be confirmed in the font spike.
- **Banner:** the CRITICAL BREAK plate is 88 px tall (72 px for the two lines plus 8 px padding top and bottom) and 328 px wide. Overflow wraps on spaces up to 3 lines and is never clipped. The lint fails any string that is too wide in either language.
- **Strings are stored in NFC**, and the font must shape the decomposed nukta letters.
- **Pseudo-localisation:** debug-only `qps` (accented, +40% padding) and `qpb` (Bengali conjunct stress set).
- **String freeze:** soft freeze at the end of the Vertical Slice, hard freeze two weeks before the release candidate.
- **Cultural checklist:** no swastika or real Axis insignia, no Rising Sun flag or roundel, fictional roundels only (note for art), no faction names after real nations, no famine humour, no religious imagery.
- **Web shaping fallbacks if the advanced text server is missing:** Plan B is pre-shaped glyph IDs at import (preferred, needs an ADR). Plan C is a custom Web template.
- **High-score initials:** Latin only at MVP (open question).

## 3. Amendments (main session to apply)
1. `design/gdd/systems-index.md`, row 27: replace `Not started` with `**Designed** (pending review) — [GDD](localization.md)`. "Depends on" stays `—`; Save (26) is only a soft, provisional input.
2. `systems-index.md`, Progress tracker: GDDs written +1, and add Localization to the list.
3. `systems-index.md`, "Open items carried over": delete "language split (ADR)".
4. `systems-index.md`, Bidirectional reminder: add Localization (27) interface notes for HUD (20), Tally (21), Menus (22), Save (26), Accessibility (28).
5. `design/art/art-bible.md` 8.8 (digit atlas): add `,` to `x + % : /`. `format_int` emits a separator and the atlas has none.
6. `art-bible.md` 7.5 tier table: add a note that cap 24 gives Bengali 33 by the 1.375 rule, but XL is fixed at 34 (exact 2x S). Optionally add the proposed digit cell sizes.
7. `design/gdd/scoring.md` F8 / HUD interface: state `,` Western 3-digit grouping in both languages, and that `display_score` output goes to `Localization.format_int`.
8. HUD (20) GDD: numerals only via `format_int` and the atlas; `language_changed` lives on the `Localization` autoload, not `GameEvents`.
9. Boss (14) GDD: names are `name_key` fields; the plate uses `text_both`.
10. Critical Break (17) GDD: banner key `banner.critical_break`, English source `CRITICAL BREAK`, Bengali from the glossary.
11. Menus (22) GDD: language toggle in Settings plus a quick toggle on the title.
12. Save (26) GDD: persist `settings.language` (`bn` or `en`), call `Localization.set_language` on load, accept the first-run write-back.
13. Accessibility (28) GDD: the text-size step-up uses `font_size_px(tier, step)` with integer sizes authored per tier.

## 4. Registry candidates
Add to `constants:`
```yaml
  - name: bn_width_reserve_pct
    value: 40
    unit: percent (extra width reserved for Bengali vs English in every text box)
    range: "30-60"
    source: design/gdd/localization.md (F4, F5; art-bible section 7.5)
    referenced_by: [localization]
  - name: bn_size_s
    value: 17
    unit: px (Bengali S/M tier; raise to 18-20 if the conjunct gate fails)
    range: "17-20"
    source: design/gdd/localization.md (F7; art-bible section 7.5)
    referenced_by: [localization]
  - name: digit_grouping
    value: "WESTERN (3-digit, ',' separator), both languages"
    unit: enum WESTERN/INDIAN
    source: design/gdd/localization.md (Rule 18, F1)
    referenced_by: [localization, scoring]
  - name: supported_languages
    value: "bn, en"
    unit: locale codes
    source: design/gdd/localization.md (Rule 1)
    referenced_by: [localization]
```
Add to `formulas:`
```yaml
  - name: format_int
    expression: "str(abs(n)) grouped in 3s from the right with ','; digits mapped to U+09E6+d when lang == bn; INDIAN grouping optional"
    variables: [n, lang, digit_grouping]
    output: "string of 1-11 chars (9 digits + 2 separators max at the display clamp)"
    source: design/gdd/localization.md (F1)
    referenced_by: [localization, scoring]
  - name: digit_cell_width
    expression: "cell_w = ceil(0.6 * digit_height); sep_w = round(0.4 * cell_w)"
    variables: [digit_height, cell_ratio, sep_ratio]
    output: "10-15 px cell at defaults (S tier 17 px gives 11)"
    source: design/gdd/localization.md (F3)
    referenced_by: [localization]
```
Existing entry: add `localization` to `referenced_by` of `score_display_digits` (the 9-digit clamp drives F1 and F3).

## 5. Conflicts
- **Art bible 7.5 vs 8.8 (minor):** the 1.375 rule gives Bengali 33 px for cap 24, but the tier table says 34 (exact 2x S). I kept 34 for XL words and noted it. Amendment 6 asks the art bible to say so.
- **Art bible 8.8 (gap):** the digit atlas lists `x + % : /` but not the group separator `,`. Amendment 5.
- No conflicts with the registry's locked values.

## 6. Open risks
- **Top risk:** it is unverified whether the official Godot 4.7 Web template includes the advanced text server (HarfBuzz). Without it Bengali conjuncts and pre-base vowels will not shape on Web. Plan B or C costs a pipeline change (ADR) or a custom engine build.
- No open pixel-grid Bengali font exists. The interim smooth fonts may fail the 17 px conjunct test with the 1 px outline. The commissioned face has no owner or budget yet.
- Unverified on 4.7: CSV import behaviour with Bengali UTF-8, `OS.get_locale()` on Web, and font import option names.
- The digit-cell ratios and the tier-L numeral sizes are proposals until the font exists. The 9-digit score plate (107 px) must fit the 1P and 2P Row A budgets, so HUD (20) must check it.
- Native-speaker review is the quality bottleneck. There is no translator or reviewer yet, and the glossary question (translate or transliterate "Critical Break" and the other terms) is open.
- Interfaces to Save (26), Accessibility (28), HUD (20), Tally (21) and Menus (22) are provisional until those GDDs exist.
- I did not use the collaborative "ask before writing" flow for the file. This follows the auto-approve and the brief's rule that the file is written without confirmation.
