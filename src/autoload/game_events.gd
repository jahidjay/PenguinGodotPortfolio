extends Node
## Global signal bus (autoload "GameEvents").
## Only for events where the sender shouldn't need a reference to the receiver
## (effects, UI). Gameplay logic uses direct references and local signals.

## Brief white screen flash. strength ~0.1 (part down) to ~1.2 (Critical Break).
signal screen_flash_requested(strength: float)

## Floating text in world space, e.g. "TURRET DOWN".
signal popup_requested(world_position: Vector2, text: String)

## Emitted right before the boss is defeated by a Critical Break.
signal critical_break_landed(player: Player, final_chain: int, life_bonus: int)
