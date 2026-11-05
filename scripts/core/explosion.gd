class_name Explosion
extends RefCounted
## Radial blast used by the explosive kick, explosive objects and the area magic burst.
## Damage falls off toward the edge; knockback pushes outward from the center.

static func detonate(origin: Node2D, center: Vector2, radius: float, damage: int, knockback: float,
		kind: String, mask: int, color: Color = Color("#ff9a3c"), from_player: bool = true,
		environmental: bool = false) -> int:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var targets := AttackQuery.overlapping(origin, shape, Transform2D(0.0, center), mask, origin)
	var count := 0
	for body in targets:
		if not body.has_method("receive_hit"):
			continue
		var offset: Vector2 = body.global_position - center
		var dist := offset.length()
		var falloff := clampf(1.0 - dist / (radius * 1.25), 0.35, 1.0)
		var dir := offset.normalized() if dist > 1.0 else Vector2.UP
		var push := Vector2(dir.x, minf(dir.y, -0.25)) * knockback * falloff
		var info := HitInfo.make(roundi(damage * falloff), push, origin, kind)
		info.from_player = from_player
		info.environmental = environmental
		info.charged = true
		body.receive_hit(info)
		count += 1
	Sfx.play("explosion")
	Fx.ring(center, color, radius, 0.35, 6.0)
	Fx.glow(center, color, radius * 0.9, 0.35)
	Fx.burst(center, color, 26, 320.0, 0.55)
	Fx.shake(clampf(radius / 12.0, 6.0, 14.0))
	Fx.hitstop(0.05, 0.1)
	return count
