class_name RunVisuals
extends Resource
## Every texture the run scene draws that is not owned by an enemy
## (design/art/art-bible.md sections 3.1, 4.4, 6.4, 6.5).
##
## Presentation only: nothing here changes the simulation, and the run draws
## primitives for anything left null, so the game still runs with an empty
## `assets/art/`.
##
## One resource per era later; `data/art/run_visuals_1941.tres` is stage 1.

@export_group("Planes (art bible 3.1, 4.4)")
## Plane body per type, one per colourway. Indexed
## [kit kind][colourway], flattened as `kind * 4 + colourway`, where kind is
## a [enum KitRules.Kind] value (LANCER, LEECH, SENTRY, BREAKER) and the
## colourway is the slot identity colour (P1 amber, P2 azure, P3 green,
## P4 pink). Two players on the same plane therefore never share a palette
## (menus GDD Rule 20a).
@export var plane_sprites: Array[Texture2D] = []
## Hitbox dot and ring, one per slot: the ring PATTERN differs per slot
## because P3 and P4 have equal luma (4.4).
@export var hitbox_sprites: Array[Texture2D] = []
## The player's main shot.
@export var shot_sprite: Texture2D
## A drone, docked or deployed (art bible 5.6, 8.3: 12x12, 6 colours).
@export var drone_sprite: Texture2D

@export_group("Score items (powerups-and-drops.md)")
## One sprite per [enum ItemField.Kind]: POD, CHAIN, MEDAL, 1UP, GEM. Cream
## and warm, never the locked bullet hue, each with its own glyph so the kind
## reads without colour.
@export var item_sprites: Array[Texture2D] = []

@export_group("Bullets (art bible 4.3)")
## Tint per bullet shape index, until the bullet atlas exists. The fill hue is
## LOCKED to 225-265 degrees: cyan, teal, violet-pink and white are never
## bullet fills, because the player's colour-reading skill has to transfer
## across all four eras.
@export var bullet_colors := PackedColorArray()
## One strip of cells, one per [enum BulletRules.Shape], in enum order. Drawn
## white-on-transparent and tinted by `bullet_colors`, so the locked fill hue
## stays in data. Null draws plain tinted quads instead, and the game plays
## identically. Replacing this one PNG re-skins every enemy bullet.
@export var bullet_atlas: Texture2D
@export var bullet_atlas_cells := 4

@export_group("Parallax (6.4, 6.5)")
## Far strip: sky and distant ridge, 376 px wide, seamless over its height.
@export var strip_far: Texture2D
## Mid strip: the river, paddy terraces and landmarks.
@export var strip_mid: Texture2D
## Scroll in px per tick. Integer positions only, so the strips never shimmer
## (6.4). Far scrolls slower than mid: that IS the parallax.
@export var far_scroll_per_tick := 0.25
@export var mid_scroll_per_tick := 0.6
