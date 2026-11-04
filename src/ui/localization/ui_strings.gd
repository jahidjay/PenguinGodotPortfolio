class_name UiStrings
extends Object
## The string table every piece of UI text goes through
## (design/gdd/localization.md: menus call `text(key)`, the language toggle
## calls `set_language`).
##
## MVP of that system, not a stand-in for it: keys live in `data/locale/*.csv`
## with one column per language, so no screen holds a user-facing literal and
## Bengali can be filled in by a translator without touching code.
##
## A missing key returns the key itself in brackets, which is loud in a
## screenshot and impossible to ship by accident. A language with no
## translation for a key falls back to English rather than showing nothing.
##
## Usage:
## [codeblock]
## UiStrings.set_language("bn")
## label.text = UiStrings.text("menu.start_game")
## [/codeblock]

## Languages the table carries, in the order the chip cycles them.
const LANGUAGES := ["en", "bn"]

const TABLE_DIR := "res://data/locale"

static var _language := "en"
static var _rows := {}
static var _loaded := false


static func set_language(code: String) -> void:
	if LANGUAGES.has(code):
		_language = code


static func language() -> String:
	return _language


## Switches to the next language in [constant LANGUAGES] and returns it.
static func cycle_language() -> String:
	var i := LANGUAGES.find(_language)
	_language = LANGUAGES[(i + 1) % LANGUAGES.size()]
	return _language


## The string for `key` in the current language, falling back to English.
static func text(key: String) -> String:
	_ensure_loaded()
	if not _rows.has(key):
		return "[%s]" % key
	var row: Dictionary = _rows[key]
	var value: String = row.get(_language, "")
	if value.is_empty():
		value = row.get("en", "")
	return value if not value.is_empty() else "[%s]" % key


## True when `key` has a translation in `code` (so a screen can hide a
## dual-script line it cannot render yet).
static func has_translation(key: String, code: String) -> bool:
	_ensure_loaded()
	if not _rows.has(key):
		return false
	var row: Dictionary = _rows[key]
	return not String(row.get(code, "")).is_empty()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(TABLE_DIR)
	if dir == null:
		push_warning("UiStrings: %s is missing; every key will show as [key]" % TABLE_DIR)
		return
	for file: String in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var table := load("%s/%s" % [TABLE_DIR, name]) as UiStringTable
		if table == null:
			continue
		for i: int in range(table.keys.size()):
			var row := {}
			for code: String in LANGUAGES:
				var column := table.column(code)
				if i < column.size():
					row[code] = column[i]
			_rows[table.keys[i]] = row
