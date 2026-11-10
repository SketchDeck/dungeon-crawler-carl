class_name ArmoredSlime
extends Slime
## A slime wearing a shell of rusty plates. Magic splashes off the shell, and
## light kicks barely dent it; a heavy kick (combo finisher or power kick) or
## an explosion cracks it off. Once cracked, its soft insides take extra magic
## damage, so the fight goes Carl -> Donut.

## Light kicks against the shell deal this fraction of their damage.
@export var shell_kick_factor := 0.5
## Magic against the cracked slime deals this much more.
@export var soft_magic_factor := 1.5

var shelled := true


func hit_multiplier(hit: Hit) -> float:
	if not shelled:
		return soft_magic_factor if hit.has_tag("magic") else 1.0
	if hit.has_tag("explosion") or hit.has_tag("hazard") or (hit.has_tag("kick") and hit.has_tag("heavy")):
		crack()
		return 1.0
	if hit.has_tag("magic"):
		return 0.0
	if hit.has_tag("kick"):
		return shell_kick_factor
	return 1.0


func crack() -> void:
	if not shelled:
		return
	shelled = false
	Audio.play("crate_break", -2.0)
	Fx.burst(global_position, Color("#8a96a8"), 30.0, 0.3)
	Fx.text(global_position + Vector2(0, -body_size.y * 0.5 - 30), "SHELL CRACKED!", Color("#ffd34d"), 16)
	GameManager.shell_cracked.emit(self)


func resist_text(_hit: Hit) -> String:
	return "SPLASH! The shell's too hard"


func weakness() -> Weakness:
	return Weakness.KICKS if shelled else Weakness.MAGIC


func body_color() -> Color:
	return tint if shelled else Color("#e58ab0")


func _draw() -> void:
	super._draw()
	var h := body_size.y
	if shelled and not is_dead:
		# Plates riveted over the top of the body.
		var plate := Color("#7d8796") if hit_flash() <= 0.0 else Color("#e0e6ee")
		var feet := h * 0.5
		var w := body_size.x * 0.5
		for i in 3:
			var a := PI + PI * (0.18 + 0.32 * i)
			var c := Vector2(cos(a) * w * 0.8, feet + sin(a) * h * 0.85)
			draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 9)), plate)
			draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 9)), plate.darkened(0.4), false, 1.5)
			draw_circle(c, 1.5, plate.lightened(0.4))
	draw_weakness(Vector2(0, -h * 0.5 - 22))
