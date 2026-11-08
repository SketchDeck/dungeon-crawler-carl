class_name Explosion
extends RefCounted
## Instant radial damage: hits everything with take_hit() on `mask` inside
## `radius` of `at`, pushing each target directly away from the centre.
## Used by the Explosive Kick, Area Magic Burst and explosive barrels.


## Returns the number of targets hit. `player_damage` (if >= 0) replaces
## `damage` for the player, so hazards can hurt enemies more than Carl.
static func detonate(ctx: Node2D, at: Vector2, radius: float, damage: float, knockback: float, mask: int,
		source: Node, tags: PackedStringArray, color := Color("#ff9a3c"), player_damage := -1.0) -> int:
	var count := 0
	for target in HitQuery.circle(ctx, at, radius, mask):
		if target == source or target == ctx or not target.has_method("take_hit"):
			continue
		var pos := (target as Node2D).global_position
		var dir := 1.0 if pos.x >= at.x else -1.0
		var amount := player_damage if target is Player and player_damage >= 0.0 else damage
		target.take_hit(Hit.new(amount, Vector2(dir * knockback, -knockback * 0.6), source, tags))
		count += 1
	Fx.explosion(at, radius, color)
	Audio.play("explosion")
	return count
