class_name UiStringTable
extends Resource
## One block of UI strings, one column per language
## (design/gdd/localization.md).
##
## A `.tres` rather than a `.csv` on purpose: Godot's CSV importer turns a csv
## into `.translation` files and does not ship the source, so a runtime CSV
## read works in the editor and fails in an exported build — including the Web
## build this project has to run on. A resource is exported like every other
## piece of designer data.
##
## `keys[i]` is the key; `en[i]` and `bn[i]` are its text. An empty entry falls
## back to English (see [UiStrings]), so a half-translated table is shippable
## and visibly half-translated rather than blank.

@export var keys := PackedStringArray()
@export var en := PackedStringArray()
@export var bn := PackedStringArray()


## Column for a language code, or an empty array if this table has none.
func column(code: String) -> PackedStringArray:
	match code:
		"bn":
			return bn
		"en":
			return en
		_:
			return PackedStringArray()
