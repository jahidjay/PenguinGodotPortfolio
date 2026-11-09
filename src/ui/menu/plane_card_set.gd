class_name PlaneCardSet
extends Resource
## The plane cards the Lobby offers, in card-row order
## (design/gdd/menus-title-plane-select.md Rule 19).
##
## Usage:
## [codeblock]
## var set := load("res://data/menus/plane_cards.tres") as PlaneCardSet
## var cards := set.available_cards()   # unavailable planes are not listed
## [/codeblock]

@export var cards: Array[PlaneCard] = []


## Only the planes a player may pick. A card with `available = false` is left
## out of the row entirely rather than shown greyed, so the cursor can never
## land on something it cannot lock.
func available_cards() -> Array[PlaneCard]:
	var out: Array[PlaneCard] = []
	for card: PlaneCard in cards:
		if card != null and card.available:
			out.append(card)
	return out
