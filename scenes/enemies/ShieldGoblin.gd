class_name ShieldGoblin
extends Goblin
## A goblin with a big wooden shield. Kicks from the front clank off it; magic
## goes over the top, and so do kicks from behind (jump over it) and
## explosions. Teaches players to switch to Donut.


func hit_multiplier(hit: Hit) -> float:
	if _blocks(hit):
		return 0.0
	return 1.0


func _blocks(hit: Hit) -> bool:
	if not hit.has_tag("kick") or hit.has_tag("explosion"):
		return false
	var src := hit.source as Node2D
	if src == null:
		return false
	# The shield faces the way the goblin faces.
	var side := signf(src.global_position.x - global_position.x)
	return side == 0.0 or int(side) == facing


func resist_text(_hit: Hit) -> String:
	return "SHIELD BLOCK!"


func weakness() -> Weakness:
	return Weakness.MAGIC


func _draw() -> void:
	super._draw()
	if is_dead:
		return
	var wood := Color("#9a6a3a")
	var rim := Color("#c8d4e6")
	if hit_flash() > 0.0:
		wood = wood.lerp(Color.WHITE, 0.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	var raised := -4.0 if state == State.WINDUP else 0.0
	var shield := Rect2(10, -20 + raised, 9, 34)
	draw_rect(shield.grow(2), rim)
	draw_rect(shield, wood)
	draw_line(Vector2(14.5, -18 + raised), Vector2(14.5, 12 + raised), wood.darkened(0.3), 1.5)
	draw_circle(shield.get_center(), 2.5, rim)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_weakness(Vector2(0, -body_size.y * 0.5 - 26))
