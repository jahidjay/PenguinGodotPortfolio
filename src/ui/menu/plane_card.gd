class_name PlaneCard
extends Resource
## One plane's card in the Lobby / plane select screen
## (design/gdd/menus-title-plane-select.md Rule 19).
##
## Designer data, not code: the cards, their order and which planes are
## offered all live in `data/menus/plane_cards.tres`. Text is NEVER stored
## here — only the string keys, resolved through [UiStrings], so the screen is
## bilingual without touching this resource (localization.md).
##
## Usage:
## [codeblock]
## var card: PlaneCard = set.available_cards()[cursor]
## label.text = UiStrings.text(card.name_key())
## kits.set_kind(slot, card.kit_kind)
## [/codeblock]

## Stable id, used for string keys, boards and the save file.
@export var plane_id := ""
## Which kit this card flies, as a [enum KitRules.Kind] value. This is the one
## field that reaches the simulation.
@export var kit_kind: int = 0
## A plane with `available = false` is not listed (Rule 19).
@export var available := true
## Index into [member RunVisuals.plane_sprites] blocks: the four colourways of
## this plane live at `sprite_row * 4 + colourway`.
@export var sprite_row: int = 0


func name_key() -> String:
	return "plane.%s.name" % plane_id


func tag_key() -> String:
	return "plane.%s.tag" % plane_id


func style_key() -> String:
	return "plane.%s.style" % plane_id


func fire_key() -> String:
	return "plane.%s.fire" % plane_id


func hold_key() -> String:
	return "plane.%s.hold" % plane_id


func drone_key() -> String:
	return "plane.%s.drone" % plane_id
