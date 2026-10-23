class_name PatternContext
extends RefCounted
## Everything a BulletPattern needs to fire one volley. Reused every frame by
## the firing BossPart (no per-frame allocation).

var origin := Vector2.ZERO    ## where bullets spawn (the part)
var center := Vector2.ZERO    ## boss center (for outward patterns)
var target := Vector2.ZERO    ## what aimed patterns aim at (the player)
var rage := 0.0               ## 0..1, fraction of non-core parts destroyed
var bullets: BulletManager


func aim_angle() -> float:
	return (target - origin).angle()
