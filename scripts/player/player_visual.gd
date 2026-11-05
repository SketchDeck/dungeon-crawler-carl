class_name PlayerVisual
extends Node2D
## Draws Carl with Donut riding on his shoulder, all with code-drawn shapes.
## Runs placeholder animation states: idle, run, jump, fall, dash, kick, charge, cast, dead.
## Juice: squash and stretch on jumps and landings, hurt flashes, invulnerability blink.

const CARL_TUNIC := Color("#e27b3a")
const CARL_TUNIC_SHADE := Color("#b0561f")
const CARL_SKIN := Color("#f2c38e")
const CARL_HAIR := Color("#3b2516")
const CARL_BELT := Color("#3d2517")
const SCARF := Color("#d7263d")
const DONUT_PINK := Color("#ff8fd0")
const DONUT_VIOLET := Color("#b57bff")
const OUTLINE := Color("#1b1420")
const VISUAL_SCALE := 1.2

var player: Player
var _t: float = 0.0
var _state_t: float = 0.0
var _state: String = "idle"
var _serial: int = -1
var _squash: float = 0.0
var _hurt_t: float = 0.0
var _drink_t: float = 0.0
var _mode_t: float = 0.0
var _respawn_t: float = 0.0
var _death_t: float = 0.0
var _mode: int = Player.Mode.CARL
var _dead: bool = false


func _ready() -> void:
	z_index = 20
	player.controller.jumped.connect(func() -> void: _squash = 1.0)
	player.controller.landed.connect(func() -> void: _squash = -1.0)


func on_hurt() -> void:
	_hurt_t = 0.4


func on_drink() -> void:
	_drink_t = 0.6


func on_mode_changed(mode: int) -> void:
	_mode = mode
	_mode_t = 0.5


func on_death() -> void:
	_dead = true
	_death_t = 0.0


func on_respawn() -> void:
	_dead = false
	_death_t = 0.0
	_respawn_t = 0.45


func _process(delta: float) -> void:
	_t += delta
	_state_t += delta
	_squash = move_toward(_squash, 0.0, delta * 3.2)
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_drink_t = maxf(0.0, _drink_t - delta)
	_mode_t = maxf(0.0, _mode_t - delta)
	_respawn_t = maxf(0.0, _respawn_t - delta)
	if _dead:
		_death_t += delta

	var state := _pick_state()
	var serial := player.combat.anim_serial
	if state != _state or (serial != _serial and state in ["kick", "cast"]):
		_state = state
		_state_t = 0.0
	_serial = serial

	var squash := _squash
	scale = Vector2(VISUAL_SCALE - 0.12 * squash, VISUAL_SCALE + 0.16 * squash)
	var blink := 1.0
	if player.alive and player.health.is_invulnerable() and int(_t * 18.0) % 2 == 0:
		blink = 0.4
	var fade := 1.0
	if _dead:
		fade = clampf(1.0 - _death_t * 1.1, 0.0, 1.0)
	var hurt := clampf(_hurt_t / 0.4, 0.0, 1.0)
	modulate = Color(1.0, 1.0 - 0.65 * hurt, 1.0 - 0.65 * hurt, blink * fade)
	rotation = _death_t * 7.0 if _dead else 0.0
	queue_redraw()


func _pick_state() -> String:
	if _dead:
		return "dead"
	if player.controller.is_dashing():
		return "dash"
	if player.combat.is_charging():
		return "charge"
	var anim := player.combat.current_anim()
	if anim == "kick" or anim == "charge_kick":
		return "kick"
	if anim == "cast":
		return "cast"
	if not player.is_on_floor():
		return "jump" if player.velocity.y < 0.0 else "fall"
	if absf(player.velocity.x) > 25.0:
		return "run"
	return "idle"


func _draw() -> void:
	var f := float(player.controller.facing)
	var donut_color := DONUT_VIOLET if _mode == Player.Mode.DONUT else DONUT_PINK
	_draw_shadow()

	var bob := 0.0
	match _state:
		"idle":
			bob = sin(_t * 3.2) * 1.0
		"run":
			bob = -absf(sin(_state_t * 14.0)) * 2.0
		"dead":
			bob = 0.0

	var root := Vector2(0.0, bob)
	_draw_aura(root, donut_color)
	_draw_legs(root, f)
	_draw_scarf(root, f)
	_draw_torso(root, f)
	_draw_arms(root, f, donut_color)
	_draw_head(root, f)
	_draw_donut(root, f, donut_color)
	_draw_effects(root, f, donut_color)


func _draw_shadow() -> void:
	draw_set_transform(Vector2(0.0, 22.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_aura(root: Vector2, donut_color: Color) -> void:
	if _mode == Player.Mode.DONUT:
		var a := 0.12 + 0.05 * sin(_t * 5.0)
		draw_circle(root + Vector2(0.0, -6.0), 30.0, Color(donut_color.r, donut_color.g, donut_color.b, a))
		draw_circle(root + Vector2(0.0, -6.0), 20.0, Color(donut_color.r, donut_color.g, donut_color.b, a * 1.4))


func _draw_legs(root: Vector2, f: float) -> void:
	var hip_front := root + Vector2(3.0 * f, 6.0)
	var hip_back := root + Vector2(-3.0 * f, 6.0)
	var front := Vector2(4.0 * f, 21.0)
	var back := Vector2(-4.0 * f, 21.0)
	match _state:
		"run":
			var ph := _state_t * 14.0
			front = Vector2((4.0 + sin(ph) * 8.0) * f, 21.0 - maxf(0.0, cos(ph)) * 6.0)
			back = Vector2((-4.0 - sin(ph) * 8.0) * f, 21.0 - maxf(0.0, -cos(ph)) * 6.0)
		"jump":
			front = Vector2(5.0 * f, 14.0)
			back = Vector2(-3.0 * f, 17.0)
		"fall":
			front = Vector2(8.0 * f, 24.0)
			back = Vector2(-7.0 * f, 23.0)
		"dash":
			front = Vector2(-3.0 * f, 19.0)
			back = Vector2(-11.0 * f, 17.0)
		"kick":
			var t := clampf(_state_t / 0.16, 0.0, 1.0)
			var e := ease(t, 0.35)
			front = Vector2(lerpf(4.0, 27.0, e) * f, lerpf(21.0, 9.0, e))
		"charge":
			front = Vector2(3.0 * f, 21.0)
			back = Vector2(-5.0 * f, 21.0 + sin(_t * 30.0) * 0.6)
	_limb(hip_front, root + front, 5.0, OUTLINE, CARL_BELT)
	_limb(hip_back, root + back, 5.0, OUTLINE, CARL_BELT)
	draw_circle(root + front, 3.2, OUTLINE)
	draw_circle(root + back, 3.2, OUTLINE)


func _draw_scarf(root: Vector2, f: float) -> void:
	var flutter := sin(_t * 9.0 + _state_t * 3.0) * 2.5
	var base := root + Vector2(-3.0 * f, -12.0)
	var pts := PackedVector2Array([
		base,
		base + Vector2(-9.0 * f, 3.0 + flutter),
		base + Vector2(-17.0 * f, 0.0 + flutter * 1.4),
		base + Vector2(-9.0 * f, 6.0 + flutter * 0.6),
		base + Vector2(-2.0 * f, 4.0),
	])
	draw_colored_polygon(pts, SCARF)


func _draw_torso(root: Vector2, f: float) -> void:
	var body := PackedVector2Array([
		root + Vector2(-8.0, -14.0),
		root + Vector2(8.0, -14.0),
		root + Vector2(7.0, 6.0),
		root + Vector2(-7.0, 6.0),
	])
	draw_colored_polygon(body, CARL_TUNIC)
	var shade := PackedVector2Array([
		root + Vector2(-8.0 * f, -14.0),
		root + Vector2(-2.0 * f, -14.0),
		root + Vector2(-1.0 * f, 6.0),
		root + Vector2(-7.0 * f, 6.0),
	])
	draw_colored_polygon(shade, CARL_TUNIC_SHADE)
	draw_rect(Rect2(root + Vector2(-7.5, 2.0), Vector2(15.0, 4.0)), CARL_BELT)
	draw_rect(Rect2(root + Vector2(-2.0, 2.5), Vector2(4.0, 3.0)), Color("#ffd166"))
	draw_line(root + Vector2(-8.0, -14.0), root + Vector2(-7.0, 6.0), OUTLINE, 1.0, true)
	draw_line(root + Vector2(8.0, -14.0), root + Vector2(7.0, 6.0), OUTLINE, 1.0, true)


func _draw_arms(root: Vector2, f: float, donut_color: Color) -> void:
	var sh_front := root + Vector2(6.0 * f, -10.0)
	var sh_back := root + Vector2(-6.0 * f, -10.0)
	var hand_front := root + Vector2(9.0 * f, 4.0)
	var hand_back := root + Vector2(-9.0 * f, 4.0)
	match _state:
		"run":
			var ph := _state_t * 14.0
			hand_front = root + Vector2((8.0 + sin(ph + PI) * 3.5) * f, -2.0 + cos(ph + PI) * 3.0)
			hand_back = root + Vector2((-8.0 - sin(ph + PI) * 3.5) * f, -2.0 - cos(ph + PI) * 3.0)
		"jump":
			hand_front = root + Vector2(9.0 * f, -24.0)
			hand_back = root + Vector2(-6.0 * f, -22.0)
		"fall":
			hand_front = root + Vector2(15.0 * f, -12.0)
			hand_back = root + Vector2(-15.0 * f, -12.0)
		"dash":
			hand_front = root + Vector2(-12.0 * f, -6.0)
			hand_back = root + Vector2(-15.0 * f, 2.0)
		"kick":
			hand_front = root + Vector2(12.0 * f, 2.0)
			hand_back = root + Vector2(-15.0 * f, -9.0)
		"charge":
			hand_front = root + Vector2(16.0 * f, -6.0 + sin(_t * 30.0) * 1.0)
			hand_back = root + Vector2(10.0 * f, -10.0)
		"cast":
			hand_front = root + Vector2(22.0 * f, -10.0)
			hand_back = root + Vector2(4.0 * f, -7.0)
		"dead":
			hand_front = root + Vector2(10.0 * f, -26.0)
			hand_back = root + Vector2(-10.0 * f, -26.0)
	_limb(sh_back, hand_back, 4.0, OUTLINE, CARL_SKIN)
	_limb(sh_front, hand_front, 4.0, OUTLINE, CARL_SKIN)
	draw_circle(hand_front, 2.8, CARL_SKIN)
	draw_circle(hand_back, 2.6, CARL_SKIN)
	if _state == "charge" or _state == "cast":
		var glow_r := 6.0 + 4.0 * sin(_t * 18.0) * 0.5 + (10.0 * player.combat.charge_ratio() if _state == "charge" else 2.0)
		var glow_col := Color("#ffb347") if player.combat.is_charging_kick() else donut_color
		draw_circle(hand_front, glow_r * 1.8, Color(glow_col.r, glow_col.g, glow_col.b, 0.22))
		draw_circle(hand_front, glow_r, Color(glow_col.r, glow_col.g, glow_col.b, 0.85))


func _draw_head(root: Vector2, f: float) -> void:
	var head := root + Vector2(0.0, -23.0)
	draw_circle(head + Vector2(-0.5 * f, -3.0), 10.5, CARL_HAIR)
	draw_circle(head + Vector2(0.0, 1.0), 9.2, CARL_SKIN)
	draw_circle(head + Vector2(-3.5 * f, -4.5), 3.2, CARL_HAIR)
	var blink := fmod(_t, 3.4) > 3.3
	var eye := head + Vector2(3.4 * f, -1.0)
	if blink:
		draw_line(eye + Vector2(-1.5, 0.0), eye + Vector2(1.5, 0.0), OUTLINE, 1.2, true)
	else:
		draw_circle(eye, 1.7, OUTLINE)
	var mouth := head + Vector2(4.5 * f, 4.0)
	if _state == "kick" or _state == "charge":
		draw_line(mouth + Vector2(-2.0, 0.0), mouth + Vector2(1.5, -0.5), OUTLINE, 1.2, true)
	else:
		draw_arc(mouth, 1.8, 0.2, PI - 0.2, 6, OUTLINE, 1.0, true)


func _draw_donut(root: Vector2, f: float, donut_color: Color) -> void:
	var c := root + Vector2(-10.0 * f, -20.0) + Vector2(0.0, sin(_t * 4.0) * 1.2)
	var halo := 0.16 if _mode == Player.Mode.CARL else 0.3
	draw_circle(c, 13.0, Color(donut_color.r, donut_color.g, donut_color.b, halo))
	draw_circle(c + Vector2(-3.0, -6.0), 2.6, donut_color)
	draw_circle(c + Vector2(3.0, -6.0), 2.6, donut_color)
	draw_circle(c, 7.2, donut_color.lightened(0.15))
	draw_circle(c + Vector2(0.0, -2.0), 6.0, donut_color)
	draw_circle(c + Vector2(-2.2, -1.5), 1.1, OUTLINE)
	draw_circle(c + Vector2(2.2, -1.5), 1.1, OUTLINE)
	draw_arc(c + Vector2(0.0, 0.8), 1.8, 0.2, PI - 0.2, 5, OUTLINE, 0.9, true)
	draw_line(c + Vector2(-6.0, -6.0), c + Vector2(-4.0, -9.0), donut_color.lightened(0.3), 1.6, true)
	draw_line(c + Vector2(6.0, -6.0), c + Vector2(4.0, -9.0), donut_color.lightened(0.3), 1.6, true)
	if _mode == Player.Mode.DONUT:
		for i in range(3):
			var ang := _t * 3.0 + TAU * float(i) / 3.0
			var orbit := root + Vector2(cos(ang) * 24.0, -6.0 + sin(ang) * 14.0)
			draw_circle(orbit, 1.8, Color(donut_color.r, donut_color.g, donut_color.b, 0.9))


func _draw_effects(root: Vector2, f: float, donut_color: Color) -> void:
	if CombatState.is_regen_active() and player.alive:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		for i in range(4):
			var ang := _t * 1.6 + i * TAU * 0.25
			var mote := root + Vector2(cos(ang) * 24.0, sin(ang) * 13.0 - 6.0)
			draw_circle(mote, 2.2, Color(0.55, 1.0, 0.7, 0.35 + 0.45 * pulse))
	if player.combat.is_charging():
		var ratio := player.combat.charge_ratio()
		var col := Color("#ffb347") if player.combat.is_charging_kick() else DONUT_VIOLET
		var start := -PI * 0.5
		draw_arc(root + Vector2(0.0, -4.0), 30.0, start, start + TAU * ratio, 32, Color(col.r, col.g, col.b, 0.9), 3.0, true)
		draw_arc(root + Vector2(0.0, -4.0), 30.0, start, start + TAU, 32, Color(col.r, col.g, col.b, 0.18), 1.5, true)
	if _drink_t > 0.0:
		var k := _drink_t / 0.6
		draw_circle(root + Vector2(0.0, -4.0), 18.0 + (1.0 - k) * 20.0, Color(0.42, 1.0, 0.6, 0.35 * k))
	if _mode_t > 0.0:
		var m := _mode_t / 0.5
		var col := DONUT_VIOLET if _mode == Player.Mode.DONUT else Color("#ffb347")
		draw_arc(root + Vector2(-10.0 * f, -20.0), 14.0 + (1.0 - m) * 26.0, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.8 * m), 2.0, true)


func _limb(a: Vector2, b: Vector2, width: float, outline: Color, fill: Color) -> void:
	draw_line(a, b, outline, width + 2.0, true)
	draw_line(a, b, fill, width, true)
