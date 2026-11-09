class_name PlatformGun
extends Resource
## One gun on a [PlatformDef]: where it sits on the platform, and the patterns
## its emitter runs (GDD Rule 3: a list, each with its own runner).

## Offset from the platform centre, in canvas px.
@export var offset := Vector2.ZERO
## The patterns this gun's emitter runs, in list order.
@export var patterns: Array[PatternDef] = []
