class_name Goblin
extends EnemyBase
## Basic ground melee enemy. Patrols between two x positions, notices the player, chases,
## telegraphs a short-range swing with a visible wind-up, then recovers.

const SWING_TIME := 0.22
const SWING_RANGE := Vector2(44.0, 38.0)

var patrol_min: float = 0.0
var patrol_max: float = 0.0
var _dir: float = 1.0
var _attack_cd: float = 0.6
var _windup: float = 0.0
var _swing: float = 0.0
var _swing_done: bool = false


func _ready() -> void:
	super._ready()
	base_color = Color("#7bd36b")
	setup_health(Config.GOBLIN_HP)
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 11.0
	capsule.height = 30.0
	shape.shape = capsule
	add_child(shape)


func display_name() -> String:
	return "Goblin"


## Called by the room to set the patrol segment.
func set_patrol(min_x: float, max_x: float) -> void:
	patrol_min = min_x
	patrol_max = max_x


func _think(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var p := _find_player()

	if _windup > 0.0:
		velocity.x = 0.0
		_windup -= delta
		if _windup <= 0.0:
			_swing = SWING_TIME
			Sfx.play("swing")
			_swing_done = false
		return

	if _swing > 0.0:
		_swing -= delta
		velocity.x = float(facing) * 260.0
		if not _swing_done and p != null and _in_swing_box(p):
			_swing_done = true
			var info := HitInfo.make(Config.GOBLIN_DAMAGE, Vector2(float(facing) * 150.0, -120.0), self, "contact")
			p.receive_hit(info)
		if _swing <= 0.0:
			_attack_cd = Config.GOBLIN_ATTACK_COOLDOWN
		return

	if engaged and p != null and p.alive:
		facing = 1 if p.global_position.x > global_position.x else -1
		var dist := absf(p.global_position.x - global_position.x)
		if dist <= Config.GOBLIN_ATTACK_RANGE and _attack_cd <= 0.0 and absf(p.global_position.y - global_position.y) < 40.0:
			_windup = Config.GOBLIN_TELEGRAPH
			velocity.x = 0.0
			return
		velocity.x = float(facing) * Config.GOBLIN_SPEED
		return

	_patrol()


func _patrol() -> void:
	if patrol_max <= patrol_min:
		velocity.x = 0.0
		return
	if global_position.x >= patrol_max:
		_dir = -1.0
	elif global_position.x <= patrol_min:
		_dir = 1.0
	velocity.x = _dir * 60.0
	facing = int(_dir)


func _in_swing_box(p: Player) -> bool:
	var offset := p.global_position - global_position
	var forward := offset.x * float(facing)
	return forward > -8.0 and forward < SWING_RANGE.x and absf(offset.y) < SWING_RANGE.y


func _on_hurt(_hit: HitInfo) -> void:
	_windup = 0.0
	_swing = 0.0


func _draw_body() -> void:
	var f := float(facing)
	var bob := 0.0
	if absf(velocity.x) > 20.0 and absf(velocity.y) < 5.0:
		bob = -absf(sin(_t * 12.0)) * 2.5
	var hit_tint := Color(1.0, 1.0, 1.0, 1.0).lerp(Color("#ffffff"), hit_flash * 4.0)
	var skin := base_color.lerp(hit_tint, clampf(hit_flash * 3.0, 0.0, 0.8))
	var dark := skin.darkened(0.35)
	var root := Vector2(0.0, bob)

	# Shadow
	draw_set_transform(Vector2(0.0, 17.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 14.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Legs
	var step := sin(_t * 12.0) * 4.0 if absf(velocity.x) > 20.0 else 0.0
	draw_line(root + Vector2(-3.0, 4.0), root + Vector2(-3.0 - step, 15.0), dark, 4.0, true)
	draw_line(root + Vector2(3.0, 4.0), root + Vector2(3.0 + step, 15.0), dark, 4.0, true)

	# Ragged loincloth and body
	var telegraph := _windup > 0.0
	var lean := -3.0 * f if telegraph else 0.0
	var body := PackedVector2Array([
		root + Vector2(-8.0 + lean, -10.0),
		root + Vector2(8.0 + lean, -10.0),
		root + Vector2(7.0, 6.0),
		root + Vector2(-7.0, 6.0),
	])
	draw_colored_polygon(body, skin)
	draw_colored_polygon(PackedVector2Array([
		root + Vector2(-7.0, 4.0), root + Vector2(7.0, 4.0), root + Vector2(5.0, 12.0),
		root + Vector2(1.0, 8.0), root + Vector2(-3.0, 12.0), root + Vector2(-7.0, 6.0),
	]), Color("#7a4a2a"))

	# Arms
	var arm_swing := sin(_t * 12.0) * 4.0 if absf(velocity.x) > 20.0 else 0.0
	var arm_front := root + Vector2(8.0 * f + lean * 0.3, -4.0 + arm_swing)
	if _swing > 0.0:
		arm_front = root + Vector2(16.0 * f, -4.0)
	elif telegraph:
		arm_front = root + Vector2(-2.0 * f, -16.0)
	draw_line(root + Vector2(-6.0 * f, -6.0), root + Vector2(-12.0 * f, 0.0 + arm_swing), dark, 4.0, true)
	draw_line(root + Vector2(6.0 * f, -6.0), arm_front, skin, 4.0, true)
	draw_circle(arm_front, 2.6, skin)

	# Head: big ears, pointy nose, glowing eyes
	var head := root + Vector2(lean * 0.5, -19.0)
	draw_circle(head, 9.5, skin)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-8.0 * f, -2.0), head + Vector2(-17.0 * f, -6.0), head + Vector2(-8.0 * f, 4.0),
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(7.0 * f, 2.0), head + Vector2(13.0 * f, 5.0), head + Vector2(7.0 * f, 6.0),
	]), dark)
	var eye_color := Color("#ff4d4d") if telegraph else Color("#ffe066")
	draw_circle(head + Vector2(3.5 * f, -2.0), 2.4, Color(eye_color.r, eye_color.g, eye_color.b, 0.35))
	draw_circle(head + Vector2(3.5 * f, -2.0), 1.4, eye_color)
	draw_line(head + Vector2(-2.0, -6.0), head + Vector2(3.0 * f, -5.0), dark, 1.2, true)

	if telegraph:
		var pulse := 0.6 + 0.4 * sin(_t * 30.0)
		draw_circle(head + Vector2(0.0, -18.0), 6.0, Color(1.0, 0.25, 0.25, 0.9 * pulse))
		draw_string(ThemeDB.fallback_font, head + Vector2(-3.0, -14.0), "!",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color("#ffffff"))
