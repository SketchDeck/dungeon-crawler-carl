class_name PlayerVisual
extends Node2D
## Placeholder art: Carl (jacket + boxers) with Princess Donut on his shoulder.
## Poses are derived from player state each frame (idle, run, jump, fall,
## dodge, kick, charge, hurt, dead).

const SKIN := Color("#e8b48a")
const HAIR := Color("#6b3d1f")
const JACKET := Color("#6b4a2f")
const BOXERS := Color("#3f6fd1")
const HEARTS := Color("#ff7a9a")
const BOOTS := Color("#2e231c")
const DONUT_FUR := Color("#f3e3c7")
const DONUT_FACE := Color("#b8875a")
const TIARA := Color("#ffd34d")
const CHARGE := Color("#ff9a3c")

var player: Player
var _t := 0.0


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	_t += delta
	scale.x = player.facing
	var health := player.health
	if health.is_dead:
		rotation = lerpf(rotation, -PI * 0.5, minf(delta * 10.0, 1.0))
		position.y = lerpf(position.y, 16.0, minf(delta * 10.0, 1.0))
		modulate = Color(0.6, 0.6, 0.6)
	else:
		rotation = 0.0
		position.y = 0.0
		if health.time_since_damage < 0.12:
			modulate = Color(1.0, 0.35, 0.35)
		elif health.is_invulnerable() and int(_t * 20.0) % 2 == 0:
			modulate = Color(1, 1, 1, 0.35)
		elif player.is_dodging():
			modulate = Color(1, 1, 1, 0.55)
		else:
			modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	var combat := player.combat
	var kick := combat.kick_combo
	var power := combat.charged_kick
	var on_floor := player.is_on_floor()
	var crouch := 4.0 if power.is_charging() else 0.0

	# Dodge afterimages.
	if player.is_dodging():
		for i in 3:
			var off := Vector2(-14.0 * (i + 1), 0)
			draw_rect(Rect2(off + Vector2(-12, -20), Vector2(24, 46)), Color(1, 0.8, 0.5, 0.18 - i * 0.05))

	# Legs.
	var hip_back := Vector2(-5, 10 + crouch)
	var hip_front := Vector2(5, 10 + crouch)
	var foot_back := Vector2(-6, 27)
	var foot_front := Vector2(6, 27)
	var kick_extend := 0.0
	if kick.is_active():
		kick_extend = 1.0 if kick.phase == KickCombo.Phase.RECOVERY else 0.5
		foot_front = Vector2(8, 14).lerp(Vector2(32 + kick.current * 3, 6 - kick.current * 2), kick_extend)
	elif power.phase == ChargedKick.Phase.WINDUP or power.phase == ChargedKick.Phase.RECOVERY:
		foot_front = Vector2(38, 2)
	elif player.is_dodging():
		foot_back = Vector2(-14, 24)
		foot_front = Vector2(12, 22)
	elif not on_floor:
		if player.velocity.y < 0.0:
			foot_back = Vector2(-8, 20)
			foot_front = Vector2(8, 18)
		else:
			foot_back = Vector2(-10, 26)
			foot_front = Vector2(9, 24)
	elif absf(player.velocity.x) > 20.0:
		var s := sin(_t * 16.0)
		foot_back = Vector2(-6 - s * 8.0, 27 - maxf(0.0, -s) * 4.0)
		foot_front = Vector2(6 + s * 8.0, 27 - maxf(0.0, s) * 4.0)
	_draw_leg(hip_back, foot_back)
	_draw_leg(hip_front, foot_front, 7.0 if kick_extend > 0.0 else 6.0)

	# Boxers with hearts.
	var body_y := crouch
	draw_rect(Rect2(-11, 2 + body_y, 22, 11), BOXERS)
	draw_circle(Vector2(-5, 7 + body_y), 1.8, HEARTS)
	draw_circle(Vector2(4, 9 + body_y), 1.8, HEARTS)

	# Jacket torso and arm.
	draw_rect(Rect2(-12, -20 + body_y, 24, 23), JACKET)
	var hand := Vector2(10, -2 + body_y)
	if kick.is_active() or power.is_active():
		hand = Vector2(-12, -10 + body_y)
	draw_line(Vector2(6, -16 + body_y), hand, JACKET.darkened(0.2), 6.0)
	draw_circle(hand, 3.0, SKIN)

	# Carl's head.
	var head := Vector2(2, -29 + body_y)
	draw_circle(head, 9.0, SKIN)
	draw_arc(head, 9.0, PI, TAU, 12, HAIR, 4.0)
	draw_circle(head + Vector2(4, -1), 1.4, Color.BLACK)
	draw_rect(Rect2(head + Vector2(-2, 5), Vector2(10, 4)), HAIR.lightened(0.15))

	_draw_donut(Vector2(-11, -24 + body_y))

	# Drinking a potion: flask in hand plus a green flash.
	var since_potion := player.potions.time_since_use
	if since_potion < 0.35:
		PotionPickup.draw_flask(self, hand + Vector2(2, -6), 0.8)
		draw_circle(Vector2(0, -4), 30.0, Color(0.5, 1.0, 0.55, 0.25 * (1.0 - since_potion / 0.35)))

	# Automatic regeneration: soft rising green motes.
	if player.regen.is_active():
		for i in 4:
			var phase := fmod(_t * 0.8 + i * 0.25, 1.0)
			var x := sin(i * 2.3 + _t * 2.0) * 14.0
			draw_circle(Vector2(x, 20 - phase * 56.0), 2.2, Color(0.55, 1.0, 0.6, 0.6 * (1.0 - phase)))

	# Charge glow at the kicking foot.
	if power.is_charging():
		var r := power.charge_ratio()
		var pulse := 1.0 + 0.15 * sin(_t * 30.0) if r >= 1.0 else 1.0
		var c := CHARGE.lerp(Color.WHITE, 0.6 if r >= 1.0 else 0.0)
		draw_circle(Vector2(8, 22), (5.0 + r * 12.0) * pulse, Color(c, 0.35 + r * 0.3))
		draw_arc(Vector2(0, 0), 34.0 + r * 8.0, -PI * 0.5, -PI * 0.5 + TAU * r, 32, Color(c, 0.8), 3.0)


func _draw_leg(hip: Vector2, foot: Vector2, width := 6.0) -> void:
	draw_line(hip, foot, SKIN, width)
	draw_rect(Rect2(foot + Vector2(-3, -3), Vector2(9, 6)), BOOTS)


func _draw_donut(at: Vector2) -> void:
	# Tail.
	draw_line(at + Vector2(-5, 3), at + Vector2(-12, -4), DONUT_FUR.darkened(0.1), 4.0)
	# Body and head.
	draw_circle(at, 7.0, DONUT_FUR)
	var head := at + Vector2(2, -10)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -3), head + Vector2(-4, -11), head + Vector2(-1, -5)]), DONUT_FUR)
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, -3), head + Vector2(4, -11), head + Vector2(1, -5)]), DONUT_FUR)
	draw_circle(head, 6.0, DONUT_FUR)
	draw_circle(head + Vector2(1.5, 1.5), 3.0, DONUT_FACE)
	draw_circle(head + Vector2(3, -1), 1.2, Color.BLACK)
	# Tiara.
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-4, -5), head + Vector2(-3, -9), head + Vector2(-1, -6),
		head + Vector2(0, -10), head + Vector2(1, -6), head + Vector2(3, -9), head + Vector2(4, -5),
	]), TIARA)
