class_name LobbyRules
extends Resource
## Every number the Lobby / plane select screen uses
## (design/gdd/menus-title-plane-select.md Rules 22-25, F2, F3; Input Rule 23).
##
## All timers are integer ticks at 60 Hz, like the rest of the project.

## Ticks the "Starting" bar runs once every joined slot is Locked (Rule 23).
## Any change — an unlock, a cancel, a new join — resets it to 0.
@export var start_delay_ticks := 45
## Menu navigation repeat (Input F4): first repeat after `nav_repeat_first`
## ticks of a held direction, then one every `nav_repeat`.
@export var nav_repeat_first := 18
@export var nav_repeat := 6
## A Choosing slot with no input for this long, while at least one other slot
## is Locked, is released to Empty (Rule 24a).
@export var afk_release_ticks := 1800
## If no joined slot sends any input for this long, the Lobby returns to Title
## (Rule 24b), with a warning shown for the last `lobby_warn_ticks`.
@export var lobby_idle_ticks := 3600
@export var lobby_warn_ticks := 600
