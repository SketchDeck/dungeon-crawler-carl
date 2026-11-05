class_name GoblinBrute
extends BossBase
## Floor 1 boss. Each attack has a visible wind-up so it can be read and avoided.
## Phase 1: charge, ground slam (jump the shockwave), melee swing.
## Phase 2 (below 50% health): shorter wind-ups and recovery, longer shockwaves, chained attacks.

enum State { INTRO, IDLE, WINDUP, CHARGE, LEAP, SWING, RECOVER }

const CHARGE_SPEED := 470.0
const LEAP_SPEED := 180.0

var _state: int = State.INTRO
var _timer: float = 1.2
var _attack: String = ""
var _last_attack: String = ""
var _hit_done: bool = false
var _chain_next: bool = false
var _windup_total: float = 0.9
var _landed_shake: float = 0.0


func _ready() -> void:
	super._ready()
	base_color = Color("#6fbf5b")
	drop_chance = 0.0
	setup_health(Config.BRUTE_HP)
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 20.0
	capsule.height = 56.0
	shape.shape = capsule
	add_child(shape)


func display_name() -> String:
	return "Goblin Brute"


func _think(delta: float) -> void:
	var p := _find_player()
	var committed := _state == State.CHARGE or _state == State.LEAP
	if p != null and not committed:
		facing = 1 if p.global_position.x >= global_position.x else -1
	var fast := 1.35 if phase == 2 else 1.0
	_timer -= delta
	_landed_shake = maxf(0.0, _landed_shake - delta)

	match _state:
		State.INTRO:
			velocity.x = 0.0
			if _timer <= 0.0:
				_go(State.IDLE, 0.6)
		State.IDLE:
			velocity.x = 0.0
			if _timer <= 0.0:
				_start_attack(_pick_attack())
		State.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_begin_attack()
		State.CHARGE:
			velocity.x = float(facing) * CHARGE_SPEED * fast
			if p != null and not _hit_done and _overlaps(p, Vector2(52.0, 64.0)):
				_hit_done = true
				p.receive_hit(HitInfo.make(Config.BRUTE_CHARGE_DAMAGE,
					Vector2(float(facing) * 320.0, -260.0), self, "charge"))
			if is_on_wall() or _timer <= 0.0:
				Fx.shake(9.0)
				_go(State.RECOVER, _recover_time())
		State.LEAP:
			velocity.x = float(facing) * LEAP_SPEED * fast
			if _timer <= 0.0 and is_on_floor():
				_land()
		State.SWING:
			velocity.x = 0.0
			if not _hit_done and p != null and _in_swing_arc(p):
				_hit_done = true
				p.receive_hit(HitInfo.make(Config.BRUTE_SWING_DAMAGE,
					Vector2(float(facing) * 260.0, -220.0), self, "swing"))
			if _timer <= 0.0:
				_go(State.RECOVER, _recover_time())
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _timer <= 0.0:
				if _chain_next:
					_chain_next = false
					_start_attack(_pick_attack())
				else:
					_go(State.IDLE, 0.5 if phase == 1 else 0.28)


func _go(state: int, seconds: float) -> void:
	_state = state
	_timer = seconds
	if state == State.RECOVER:
		_chain_next = phase == 2 and _rng.randf() < 0.35


func _pick_attack() -> String:
	var options := ["charge", "slam", "swing"]
	options.erase(_last_attack)
	var pick: String = options[_rng.randi() % options.size()]
	_last_attack = pick
	return pick


func _start_attack(attack: String) -> void:
	_attack = attack
	_hit_done = false
	var fast := 1.35 if phase == 2 else 1.0
	match attack:
		"charge":
			_windup_total = 0.9 / fast
		"slam":
			_windup_total = 0.85 / fast
		"swing":
			_windup_total = 0.6 / fast
	Fx.text(global_position + Vector2(0.0, -92.0), _attack_label(attack), Color("#ffb3b3"), 14)
	_go(State.WINDUP, _windup_total)


func _begin_attack() -> void:
	match _attack:
		"charge":
			_hit_done = false
			_go(State.CHARGE, 0.75)
		"slam":
			velocity.y = -560.0
			_go(State.LEAP, 0.12)
		"swing":
			_hit_done = false
			_go(State.SWING, 0.3)


func _land() -> void:
	_landed_shake = 0.3
	Sfx.play("shockwave")
	Fx.shake(14.0)
	Fx.hitstop(0.05, 0.1)
	Fx.burst(global_position + Vector2(0.0, 26.0), Color("#b3a392"), 26, 300.0, 0.6)
	Fx.ring(global_position + Vector2(0.0, 26.0), Color("#e0c9a6"), 70.0, 0.35, 5.0)
	var reach := 900.0 if phase == 2 else 520.0
	var origin := global_position + Vector2(0.0, 26.0)
	Shockwave.spawn(get_parent(), origin, 1.0, reach, 380.0, Config.BRUTE_SLAM_DAMAGE)
	Shockwave.spawn(get_parent(), origin, -1.0, reach, 380.0, Config.BRUTE_SLAM_DAMAGE)
	if phase == 2:
		Shockwave.spawn(get_parent(), origin, 1.0, reach * 0.55, 430.0, Config.BRUTE_SLAM_DAMAGE)
		Shockwave.spawn(get_parent(), origin, -1.0, reach * 0.55, 430.0, Config.BRUTE_SLAM_DAMAGE)
	_go(State.RECOVER, _recover_time())


func _recover_time() -> float:
	return 0.95 if phase == 1 else 0.55


func _attack_label(attack: String) -> String:
	match attack:
		"charge":
			return "CHARGE!"
		"slam":
			return "JUMP!"
		"swing":
			return "SWING!"
	return ""


func _overlaps(p: Player, half: Vector2) -> bool:
	var offset := p.global_position - global_position
	return absf(offset.x) < half.x and absf(offset.y) < half.y


func _in_swing_arc(p: Player) -> bool:
	var offset := p.global_position - global_position
	return offset.x * float(facing) > -6.0 and offset.x * float(facing) < 96.0 and absf(offset.y) < 70.0


func _on_hurt(hit: HitInfo) -> void:
	super._on_hurt(hit)
	if _state == State.WINDUP and hit.amount >= 20:
		_timer = maxf(_timer - 0.05, 0.0)


func _draw_body() -> void:
	var f := float(facing)
	var telegraph := _state == State.WINDUP
	var enraged := phase == 2
	var bob := 0.0
	if _state == State.IDLE or _state == State.RECOVER:
		bob = sin(_t * 3.0) * 1.5
	if _state == State.WINDUP:
		bob = sin(_t * 40.0) * 1.2
	var root := Vector2(0.0, bob)
	var skin := base_color.lerp(Color("#ffffff"), clampf(hit_flash * 3.0, 0.0, 0.7))
	var dark := skin.darkened(0.4)
	var armor := Color("#4a3d33")

	draw_set_transform(Vector2(0.0, 30.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 40.0, Color(0.0, 0.0, 0.0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if enraged or telegraph:
		var glow := Color("#ff4d4d", 0.14 + 0.08 * sin(_t * 8.0))
		draw_circle(root + Vector2(0.0, -6.0), 58.0, glow)

	# Legs
	var stride := sin(_t * 9.0) * 6.0 if absf(velocity.x) > 30.0 else 0.0
	draw_line(root + Vector2(-9.0, 14.0), root + Vector2(-9.0 - stride, 34.0), dark, 9.0, true)
	draw_line(root + Vector2(9.0, 14.0), root + Vector2(9.0 + stride, 34.0), dark, 9.0, true)
	draw_rect(Rect2(root + Vector2(-18.0 - stride, 30.0), Vector2(14.0, 6.0)), Color("#2b2222"))
	draw_rect(Rect2(root + Vector2(4.0 + stride, 30.0), Vector2(14.0, 6.0)), Color("#2b2222"))

	# Torso and belly
	var torso := PackedVector2Array([
		root + Vector2(-26.0, -28.0), root + Vector2(26.0, -28.0),
		root + Vector2(30.0, 6.0), root + Vector2(20.0, 22.0),
		root + Vector2(-20.0, 22.0), root + Vector2(-30.0, 6.0),
	])
	draw_colored_polygon(torso, skin)
	draw_colored_polygon(PackedVector2Array([
		root + Vector2(-14.0, -4.0), root + Vector2(14.0, -4.0), root + Vector2(12.0, 16.0), root + Vector2(-12.0, 16.0),
	]), dark)
	# Shoulder plates and spikes
	for side in [-1.0, 1.0]:
		var shoulder := root + Vector2(26.0 * side, -22.0)
		draw_circle(shoulder, 14.0, armor)
		draw_circle(shoulder + Vector2(0.0, -2.0), 10.0, armor.lightened(0.12))
		for i in range(3):
			var sx: float = shoulder.x + side * (4.0 + i * 6.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx - 3.0, shoulder.y - 8.0), Vector2(sx, shoulder.y - 20.0 - i * 2.0), Vector2(sx + 3.0, shoulder.y - 8.0),
			]), Color("#d8d2c4"))

	# Arms and club
	var club_angle := -0.9 if _state != State.SWING else 0.8
	if telegraph:
		club_angle = -2.2
	if _state == State.SWING:
		club_angle = 0.6
	var club_root := root + Vector2(20.0 * f, -12.0)
	var club_tip := club_root + Vector2(cos(club_angle) * f * 46.0, sin(club_angle) * 46.0)
	draw_line(root + Vector2(18.0 * f, -12.0), club_root, dark, 8.0, true)
	draw_line(club_root, club_tip, Color("#6b4a2b"), 10.0, true)
	draw_circle(club_tip, 13.0, Color("#5a3d22"))
	for i in range(4):
		var a := club_angle + (i - 1.5) * 0.5
		var spike_tip := club_tip + Vector2(cos(a), sin(a)) * 12.0
		draw_line(club_tip, spike_tip, Color("#d8d2c4"), 3.0, true)
	var back_arm := root + Vector2(-20.0 * f, -6.0)
	draw_line(root + Vector2(-20.0 * f, -20.0), back_arm, dark, 8.0, true)
	draw_circle(back_arm, 5.0, dark)

	# Head with jaw and tusks
	var head := root + Vector2(4.0 * f, -44.0)
	draw_circle(head, 18.0, skin)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-6.0 * f, 8.0), head + Vector2(16.0 * f, 8.0), head + Vector2(14.0 * f, 18.0), head + Vector2(-4.0 * f, 16.0),
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(8.0 * f, 8.0), head + Vector2(14.0 * f, 2.0), head + Vector2(12.0 * f, 12.0),
	]), Color("#f4f0e4"))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(2.0 * f, 9.0), head + Vector2(7.0 * f, 14.0), head + Vector2(0.0 * f, 14.0),
	]), Color("#f4f0e4"))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-16.0 * f, -6.0), head + Vector2(-28.0 * f, -12.0), head + Vector2(-16.0 * f, 4.0),
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(16.0 * f, -6.0), head + Vector2(28.0 * f, -12.0), head + Vector2(16.0 * f, 4.0),
	]), skin)
	draw_rect(Rect2(head + Vector2(-16.0, -14.0) + Vector2(4.0 * f, 0.0), Vector2(30.0, 6.0)), armor)
	var eye_col := Color("#ff3b3b") if (telegraph or enraged) else Color("#ffd166")
	var eye := head + Vector2(7.0 * f, -4.0)
	draw_circle(eye, 5.0, Color(eye_col.r, eye_col.g, eye_col.b, 0.35))
	draw_circle(eye, 2.8, eye_col)
	draw_circle(head + Vector2(-2.0 * f, -4.0), 2.0, eye_col.darkened(0.25))
	if _state == State.LEAP or _state == State.CHARGE:
		for i in range(3):
			var trail := root + Vector2(-(30.0 + i * 14.0) * f, -20.0 + i * 12.0)
			draw_circle(trail, 6.0 - i, Color("#d9cdb8", 0.25))
	if _landed_shake > 0.0:
		draw_arc(root + Vector2(0.0, 30.0), 40.0 + (0.3 - _landed_shake) * 120.0, PI, TAU, 24,
			Color("#e0c9a6", _landed_shake * 2.0), 3.0, true)
