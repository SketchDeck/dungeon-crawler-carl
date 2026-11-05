class_name MutatingSlime
extends BossBase
## Floor 2 boss. Phase 1: a fan of predictable projectiles and a jump slam that leaves a puddle.
## Phase 2 (below 50% health): more projectiles, puddles on every landing, and smaller slimes.

signal summoned(enemy: Node)

enum State { INTRO, IDLE, WINDUP, LEAP, RECOVER }

const LEAP_VX := 250.0
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")

var _state: int = State.INTRO
var _timer: float = 1.2
var _attack: String = ""
var _last_attack: String = ""
var _chain_next: bool = false
var _squash: float = 0.0
var _windup_total: float = 0.7


func _ready() -> void:
	super._ready()
	base_color = Color("#b657d6")
	drop_chance = 0.0
	setup_health(Config.MUTANT_HP)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	shape.position = Vector2(0.0, 6.0)
	add_child(shape)


func display_name() -> String:
	return "Mutating Slime"


func _think(delta: float) -> void:
	var p := _find_player()
	if p != null and _state != State.LEAP:
		facing = 1 if p.global_position.x >= global_position.x else -1
	var fast := 1.3 if phase == 2 else 1.0
	_timer -= delta
	_squash = maxf(0.0, _squash - delta * 3.0)
	match _state:
		State.INTRO:
			velocity.x = 0.0
			if _timer <= 0.0:
				_go(State.IDLE, 0.6)
		State.IDLE:
			velocity.x = 0.0
			if _timer <= 0.0:
				_start_attack(_pick_attack(), fast)
		State.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_begin_attack()
		State.LEAP:
			velocity.x = float(facing) * LEAP_VX * fast
			if _timer <= 0.0 and is_on_floor():
				_land()
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if _timer <= 0.0:
				if _chain_next:
					_chain_next = false
					_start_attack(_pick_attack(), fast)
				else:
					_go(State.IDLE, 0.5 if phase == 1 else 0.3)


func _go(state: int, seconds: float) -> void:
	_state = state
	_timer = seconds
	if state == State.RECOVER:
		_chain_next = phase == 2 and _rng.randf() < 0.4


func _pick_attack() -> String:
	var options := ["volley", "jump"]
	options.erase(_last_attack)
	var pick: String = options[_rng.randi() % options.size()]
	_last_attack = pick
	return pick


func _start_attack(attack: String, fast: float) -> void:
	_attack = attack
	_windup_total = (0.7 if attack == "volley" else 0.65) / fast
	Fx.text(global_position + Vector2(0.0, -70.0), "SPLORCH!" if attack == "volley" else "SPLAT!", Color("#e7a6ff"), 14)
	_go(State.WINDUP, _windup_total)


func _begin_attack() -> void:
	match _attack:
		"volley":
			_fire_volley()
			_go(State.RECOVER, _recover_time())
		"jump":
			velocity.y = -540.0
			_go(State.LEAP, 0.12)


func _fire_volley() -> void:
	var p := _find_player()
	var origin := global_position + Vector2(0.0, -16.0)
	var aim := Vector2(float(facing), 0.0)
	if p != null:
		aim = (p.global_position + Vector2(0.0, -10.0) - origin).normalized()
	var count := 5 if phase == 2 else 3
	var speed := 380.0 if phase == 1 else 430.0
	for i in range(count):
		var angle := (i - (count - 1) * 0.5) * 0.24
		var dir := aim.rotated(angle)
		Projectile.spawn(get_parent(), origin, dir, speed, Config.MUTANT_PROJECTILE_DAMAGE,
			Vector2(150.0, -60.0), 760.0, 7.0, Color("#d68bff"), true, "projectile")
	Fx.burst(origin, Color("#e7a6ff"), 14, 200.0, 0.4)
	Fx.flash(origin, Color("#d68bff"), 26.0, 0.18)


func _land() -> void:
	_squash = 1.0
	var at := global_position + Vector2(0.0, 26.0)
	Fx.shake(12.0)
	Fx.hitstop(0.05, 0.1)
	Fx.burst(at, Color("#b657d6"), 30, 320.0, 0.6)
	Fx.ring(at, Color("#e7a6ff"), 80.0, 0.4, 5.0)
	Puddle.spawn(get_parent(), at + Vector2(float(facing) * 26.0, 0.0), 46.0)
	if phase == 2:
		Puddle.spawn(get_parent(), at + Vector2(-float(facing) * 90.0, 0.0), 40.0)
		_summon_slimes()
	_go(State.RECOVER, _recover_time())


func _summon_slimes() -> void:
	for side in [-1.0, 1.0]:
		var slime: Node = SLIME_SCENE.instantiate()
		slime.small = true
		slime.position = global_position + Vector2(110.0 * side, 0.0)
		get_parent().add_child(slime)
		if slime.has_method("set_patrol"):
			slime.set_patrol(global_position.x - 260.0, global_position.x + 260.0)
		slime.engaged = true
		CombatState.engage(slime)
		summoned.emit(slime)
	Fx.text(global_position + Vector2(0.0, -80.0), "SPAWN!", Color("#9cf07c"), 16)


func _recover_time() -> float:
	return 0.9 if phase == 1 else 0.5


func _draw_body() -> void:
	var telegraph := _state == State.WINDUP
	var squash := _squash
	var wobble := sin(_t * 4.0) * 0.05
	var sx := 1.0 + 0.2 * squash + wobble
	var sy := 1.0 - 0.22 * squash - wobble
	if _state == State.LEAP:
		sx = 0.85
		sy = 1.2
	var enraged := phase == 2
	var core := base_color
	var lit := Color("#e7a6ff")
	if telegraph or enraged:
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		draw_circle(Vector2(0.0, -4.0), 52.0, Color(lit.r, lit.g, lit.b, 0.12 + 0.08 * pulse))

	draw_set_transform(Vector2(0.0, 36.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 44.0, Color(0.0, 0.0, 0.0, 0.4))
	draw_set_transform(Vector2(0.0, 6.0), 0.0, Vector2(sx, sy))
	draw_circle(Vector2(-18.0, 10.0), 14.0, core.darkened(0.2))
	draw_circle(Vector2(18.0, 10.0), 14.0, core.darkened(0.2))
	draw_circle(Vector2.ZERO, 32.0, core.darkened(0.25))
	draw_circle(Vector2(0.0, -2.0), 28.0, core)
	draw_circle(Vector2(-10.0, -12.0), 9.0, Color(1.0, 0.9, 1.0, 0.35))
	for i in range(5):
		var a := -PI * 0.2 + i * PI * 0.2
		var bulb := Vector2(cos(a), sin(a)) * 30.0 + Vector2(0.0, 2.0)
		draw_circle(bulb, 5.0 + (i % 2) * 2.0, core.lightened(0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var eye_count := 3 if enraged else 2
	var f := float(facing)
	for i in range(eye_count):
		var ex := (i - (eye_count - 1) * 0.5) * 14.0
		var ey := -20.0 if i == 1 and enraged else -8.0
		var e := Vector2(ex + f * 4.0, ey)
		draw_circle(e, 6.5, Color("#fff7ff"))
		draw_circle(e + Vector2(f * 2.0, 0.5), 3.2, Color("#2a0c33") if not telegraph else Color("#ff3b3b"))
	draw_arc(Vector2(f * 6.0, 8.0), 9.0, 0.2, PI - 0.2, 8, Color("#2a0c33"), 2.0, true)
	if _state == State.WINDUP:
		var a := -0.2 * PI
		for i in range(3):
			draw_circle(Vector2(cos(a + i * 0.2) * 40.0, -12.0 + sin(_t * 12.0 + i) * 3.0), 2.5, Color("#f0c6ff"))
