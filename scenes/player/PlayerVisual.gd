class_name PlayerVisual
extends Node2D
## Placeholder art: Carl (black leather vest, white boxers with red hearts) with
## Princess Donut (a brown cat in a purple tiara) on his shoulder.
## Poses are derived from player state each frame (idle, run, jump, fall,
## dodge, kick, charge, cast, switch, hurt, dead). Both characters are always
## drawn; the active combat mode shows as a colored glow at Carl's feet, and
## in Donut mode Donut glows purple and does the casting.

const SKIN := Color("#e8b48a")
const HAIR := Color("#6b3d1f")
const VEST := Color("#1b1a1d")
const VEST_SHINE := Color("#4a4650")
const BOXERS := Color("#f4f2ee")
const HEARTS := Color("#e0304a")
const BOOTS := Color("#2e231c")
const DONUT_FUR := Color("#8a5a34")
const DONUT_FUR_DARK := Color("#5e3a1f")
const DONUT_FACE := Color("#c49a6c")
const TIARA := Color("#9b4dff")
const TIARA_GEM := Color("#ffd0ff")
const CHARGE := Color("#ff9a3c")
const MAGIC := Color("#b46cff")

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
	# The Explosive Kick reuses the power kick's poses.
	var boom := combat.explosive_kick
	var power: ChargedKick = boom if boom.is_active() else combat.charged_kick
	var burst := combat.area_burst
	var missile := combat.magic_missile
	var blast := combat.charged_blast
	var donut_mode := combat.mode == PlayerCombat.Mode.DONUT
	var mode_color := PlayerCombat.mode_color(combat.mode)
	var on_floor := player.is_on_floor()
	var crouch := 4.0 if power.is_charging() else 0.0

	# Combat mode glow under Carl's feet (warm = Carl, purple = Donut).
	draw_set_transform(Vector2(0, 28), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(mode_color, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Switching: a ring bursts outward in the new mode's color.
	var since_switch := combat.time_since_switch
	if since_switch < 0.3:
		var k := since_switch / 0.3
		draw_arc(Vector2(0, -4), 20.0 + k * 26.0, 0.0, TAU, 32, Color(mode_color, 0.9 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0)

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

	# White boxers with red hearts.
	var body_y := crouch
	draw_rect(Rect2(-11, 2 + body_y, 22, 11), BOXERS)
	draw_rect(Rect2(-11, 2 + body_y, 22, 2), BOXERS.darkened(0.15))
	draw_line(Vector2(0, 5 + body_y), Vector2(0, 12 + body_y), BOXERS.darkened(0.2), 1.0)
	_draw_heart(Vector2(-6, 8 + body_y), 2.2)
	_draw_heart(Vector2(4, 7 + body_y), 2.2)
	_draw_heart(Vector2(-1, 11 + body_y), 1.8)
	_draw_heart(Vector2(8, 11 + body_y), 1.8)

	# Bare torso under an open black leather vest.
	draw_rect(Rect2(-12, -20 + body_y, 24, 23), SKIN)
	draw_rect(Rect2(-12, -20 + body_y, 15, 23), VEST)
	draw_rect(Rect2(8, -20 + body_y, 4, 23), VEST)
	draw_line(Vector2(-9, -18 + body_y), Vector2(-9, 1 + body_y), VEST_SHINE, 1.5)
	draw_line(Vector2(3, -20 + body_y), Vector2(3, 3 + body_y), VEST_SHINE, 1.0)
	# Bare arm (the vest is sleeveless).
	var hand := Vector2(10, -2 + body_y)
	if kick.is_active() or power.is_active():
		hand = Vector2(-12, -10 + body_y)
	draw_line(Vector2(6, -16 + body_y), hand, SKIN.darkened(0.08), 6.0)
	draw_circle(Vector2(6, -16 + body_y), 3.5, VEST)
	draw_circle(hand, 3.0, SKIN)

	# Carl's head.
	var head := Vector2(2, -29 + body_y)
	draw_circle(head, 9.0, SKIN)
	draw_arc(head, 9.0, PI, TAU, 12, HAIR, 4.0)
	draw_circle(head + Vector2(4, -1), 1.4, Color.BLACK)
	draw_rect(Rect2(head + Vector2(-2, 5), Vector2(10, 4)), HAIR.lightened(0.15))
	draw_hat(self, GameManager.equipped_hat, head + Vector2(0, -7))

	# Donut leans forward and points a paw while casting.
	var casting := missile.is_active() or blast.phase == ChargedBlast.Phase.CAST or blast.phase == ChargedBlast.Phase.RECOVERY \
		or combat.area_burst.is_active()
	var donut_at := Vector2(-11, -24 + body_y)
	if casting or blast.is_charging():
		donut_at += Vector2(5, -2)
	if donut_mode:
		var glow := 0.18 + 0.08 * sin(_t * 5.0)
		draw_circle(donut_at + Vector2(1, -5), 15.0, Color(MAGIC, glow))
	_draw_donut(donut_at)
	if donut_mode:
		# Two sparkles orbiting Donut.
		for i in 2:
			var a := _t * 3.0 + i * PI
			draw_circle(donut_at + Vector2(1, -6) + Vector2(cos(a) * 13.0, sin(a) * 6.0), 1.6, Color(1, 0.85, 1, 0.8))
	var paw_tip := Vector2(combat.projectile_origin.x, combat.projectile_origin.y)
	if casting or blast.is_charging():
		# Short outstretched paw, with a thin stream of magic down to the bolt.
		var paw := donut_at + Vector2(11, 3)
		draw_line(donut_at + Vector2(4, 1), paw, DONUT_FUR, 3.0)
		draw_circle(paw, 2.5, DONUT_FUR)
		draw_line(paw, paw_tip, Color(MAGIC, 0.45), 2.0)
	if missile.phase == MagicMissile.Phase.CAST:
		draw_circle(paw_tip, 9.0, Color(MAGIC, 0.6))

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
		var base := Color("#ff3a1a") if power == boom else CHARGE
		var c := base.lerp(Color.WHITE, 0.6 if r >= 1.0 else 0.0)
		draw_circle(Vector2(8, 22), (5.0 + r * 12.0) * pulse, Color(c, 0.35 + r * 0.3))
		draw_arc(Vector2(0, 0), 34.0 + r * 8.0, -PI * 0.5, -PI * 0.5 + TAU * r, 32, Color(c, 0.8), 3.0)

	# Explosive Kick: flickering sparks around the foot while charging.
	if power == boom and boom.is_charging():
		for i in 5:
			var a := _t * 11.0 + i * TAU / 5.0
			draw_circle(Vector2(8, 22) + Vector2(cos(a), sin(a)) * (10.0 + 6.0 * boom.charge_ratio()), 2.0, Color("#ffd34d"))

	# Magic Burst: the blast radius shows while Donut gathers it.
	if burst.phase == AreaBurst.Phase.CAST:
		var k := burst.cast_ratio()
		draw_circle(Vector2(0, -4), burst.radius, Color(MAGIC, 0.08 + 0.12 * k))
		draw_arc(Vector2(0, -4), burst.radius, 0.0, TAU, 48, Color(MAGIC, 0.4 + 0.5 * k), 2.0)
		draw_circle(Vector2(0, -4), burst.radius * k, Color(1, 0.85, 1, 0.15))

	# Magic blast charge: a growing orb at Donut's paw plus a purple charge ring.
	if blast.is_charging():
		var r := blast.charge_ratio()
		var full := r >= 1.0
		var pulse := 1.0 + (0.18 * sin(_t * 30.0) if full else 0.0)
		var c := MAGIC.lerp(Color.WHITE, 0.5 if full else 0.0)
		var orb := blast.radius_for_ratio(r) * pulse
		draw_circle(paw_tip, orb * 1.5, Color(c, 0.25))
		draw_circle(paw_tip, orb, Color(c, 0.75))
		draw_circle(paw_tip, orb * 0.4, Color(1, 0.95, 1))
		draw_arc(Vector2(0, 0), 34.0 + r * 8.0, -PI * 0.5, -PI * 0.5 + TAU * r, 32, Color(c, 0.8), 3.0)


func _draw_leg(hip: Vector2, foot: Vector2, width := 6.0) -> void:
	draw_line(hip, foot, SKIN, width)
	draw_rect(Rect2(foot + Vector2(-3, -3), Vector2(9, 6)), BOOTS)


func _draw_heart(center: Vector2, size: float) -> void:
	draw_circle(center + Vector2(-size * 0.5, 0), size * 0.6, HEARTS)
	draw_circle(center + Vector2(size * 0.5, 0), size * 0.6, HEARTS)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 1.05, size * 0.15), center + Vector2(size * 1.05, size * 0.15),
		center + Vector2(0, size * 1.3)]), HEARTS)


func _draw_donut(at: Vector2) -> void:
	# Big fluffy tail.
	draw_line(at + Vector2(-5, 3), at + Vector2(-12, -4), DONUT_FUR_DARK, 5.0)
	draw_circle(at + Vector2(-12, -5), 3.0, DONUT_FUR_DARK)
	# Fluffy body.
	draw_circle(at, 7.5, DONUT_FUR)
	draw_circle(at + Vector2(-4, 2), 4.5, DONUT_FUR)
	draw_circle(at + Vector2(3, 3), 4.0, DONUT_FUR_DARK.lerp(DONUT_FUR, 0.5))
	var head := at + Vector2(2, -10)
	# Ears with darker insides.
	draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -3), head + Vector2(-4, -11), head + Vector2(-1, -5)]), DONUT_FUR_DARK)
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, -3), head + Vector2(4, -11), head + Vector2(1, -5)]), DONUT_FUR_DARK)
	# Round, flat-faced head with a fluffy ruff.
	draw_circle(head + Vector2(0, 3), 6.5, DONUT_FUR_DARK.lerp(DONUT_FUR, 0.6))
	draw_circle(head, 6.0, DONUT_FUR)
	draw_circle(head + Vector2(1.5, 1.8), 3.0, DONUT_FACE)
	draw_circle(head + Vector2(3, -1), 1.3, Color("#ffcf3a"))
	draw_circle(head + Vector2(3.2, -1), 0.7, Color.BLACK)
	draw_circle(head + Vector2(3.5, 1.5), 0.8, Color("#5a2a2a"))
	# Purple tiara with a sparkling gem.
	var tiara := PackedVector2Array([
		head + Vector2(-4.5, -5), head + Vector2(-3.5, -9), head + Vector2(-1.5, -6.5),
		head + Vector2(0, -11), head + Vector2(1.5, -6.5), head + Vector2(3.5, -9), head + Vector2(4.5, -5),
	])
	draw_colored_polygon(tiara, TIARA)
	draw_polyline(tiara, TIARA.lightened(0.35), 1.0)
	draw_circle(head + Vector2(0, -7), 1.3, TIARA_GEM)


## Carl's cosmetic hat (GameManager.HATS), drawn on `canvas` with its brim at
## `at`. Static so menus can preview hats too.
static func draw_hat(canvas: CanvasItem, id: String, at: Vector2, k := 1.0) -> void:
	match id:
		"party_hat":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 0) * k, at + Vector2(0, -18) * k, at + Vector2(7, 0) * k]), Color("#ff5a8a"))
			canvas.draw_line(at + Vector2(-4, -6) * k, at + Vector2(4, -4) * k, Color("#ffd34d"), 2.0 * k)
			canvas.draw_line(at + Vector2(-2, -12) * k, at + Vector2(2, -11) * k, Color("#7ad8ff"), 2.0 * k)
			canvas.draw_circle(at + Vector2(0, -18) * k, 2.5 * k, Color("#ffd34d"))
		"crown":
			var pts := PackedVector2Array([at + Vector2(-7, 0) * k, at + Vector2(-7, -8) * k, at + Vector2(-3.5, -4) * k,
				at + Vector2(0, -10) * k, at + Vector2(3.5, -4) * k, at + Vector2(7, -8) * k, at + Vector2(7, 0) * k])
			canvas.draw_colored_polygon(pts, Color("#ffd34d"))
			canvas.draw_circle(at + Vector2(0, -3) * k, 1.6 * k, Color("#e0304a"))
		"traffic_cone":
			canvas.draw_rect(Rect2(at + Vector2(-9, -2) * k, Vector2(18, 3) * k), Color("#ff7a1a"))
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -2) * k, at + Vector2(0, -20) * k, at + Vector2(6, -2) * k]), Color("#ff7a1a"))
			canvas.draw_line(at + Vector2(-4, -8) * k, at + Vector2(4, -8) * k, Color.WHITE, 2.5 * k)
		"viking":
			canvas.draw_circle(at + Vector2(0, 1) * k, 8.0 * k, Color("#9aa4b2"))
			canvas.draw_rect(Rect2(at + Vector2(-9, 0) * k, Vector2(18, 3) * k), Color("#6c5a40"))
			for side in [-1.0, 1.0]:
				canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(side * 6, -3) * k, at + Vector2(side * 13, -13) * k,
					at + Vector2(side * 9, -2) * k]), Color("#f4ead8"))
		"propeller":
			canvas.draw_circle(at + Vector2(0, 1) * k, 7.5 * k, Color("#3a6ad8"))
			canvas.draw_rect(Rect2(at + Vector2(-8, 0) * k, Vector2(16, 2.5) * k), Color("#ffd34d"))
			canvas.draw_line(at + Vector2(0, -6) * k, at + Vector2(0, -10) * k, Color("#444"), 1.5 * k)
			var spin := Time.get_ticks_msec() * 0.02
			var blade := Vector2(cos(spin) * 8.0, 0) * k
			canvas.draw_line(at + Vector2(0, -10) * k - blade, at + Vector2(0, -10) * k + blade, Color("#e0304a"), 2.5 * k)
		"chef":
			canvas.draw_rect(Rect2(at + Vector2(-6, -6) * k, Vector2(12, 7) * k), Color.WHITE)
			for x in [-5.0, 0.0, 5.0]:
				canvas.draw_circle(at + Vector2(x, -10) * k, 5.0 * k, Color.WHITE)
