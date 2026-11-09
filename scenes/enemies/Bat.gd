class_name Bat
extends EnemyBase
## Flying enemy. Hovers above the player, out of reach of a standing kick,
## then flashes (the telegraph), dives at where the player stood and flaps
## back up. Donut's bolts curve toward flying enemies, so magic is the easy
## answer; a jump kick works for the brave.

enum State { IDLE, STALK, WINDUP, DIVE, RECOVER }

const GROUP_FLYERS := "flyers"
const BODY := Color("#4b3a66")
const WING := Color("#6c5394")

@export var tint := BODY
@export_group("Detection")
@export var detect_range := 320.0
@export var detect_height := 260.0
@export var disengage_range := 600.0
@export var disengage_time := 3.0
@export_group("Flight")
@export var hover_height := 96.0
@export var hover_offset := 64.0
@export var stalk_speed := 150.0
@export var stalk_time := 1.3
@export var windup_time := 0.55
@export var dive_speed := 430.0
@export var dive_time := 0.65
@export var recover_time := 0.7
@export_group("Attack")
@export var contact_damage := 10.0
@export var contact_knockback := Vector2(220, -200)

var state := State.IDLE

var _t := 0.0
var _home := Vector2.ZERO
var _lost_t := 0.0
var _anim := 0.0
var _dive_target := Vector2.ZERO
var _hit_this_dive := false
var _side := 1


func _ready() -> void:
	flying = true
	super._ready()
	add_to_group(GROUP_FLYERS)
	_home = global_position
	_anim = rng.randf() * TAU
	_side = 1 if rng.randf() < 0.5 else -1


func _physics_process(delta: float) -> void:
	_anim += delta
	super._physics_process(delta)


func _ai(delta: float) -> void:
	var player := get_player()
	if player and player.health.is_dead and is_engaged:
		_disengage()
	if is_engaged:
		_track(player, delta)
	match state:
		State.IDLE:
			var target := _home + Vector2(sin(_anim * 0.9) * 24.0, sin(_anim * 2.3) * 8.0)
			velocity = (target - global_position) * 3.0
			_try_detect(player)
		State.STALK:
			if player == null:
				_disengage()
				return
			if absf(player.global_position.x - global_position.x) > 8.0:
				facing = 1 if player.global_position.x > global_position.x else -1
			var target := player.global_position + Vector2(-_side * hover_offset, -hover_height)
			target.y += sin(_anim * 4.0) * 6.0
			velocity = velocity.move_toward((target - global_position).limit_length(stalk_speed), 900.0 * delta)
			_t -= delta
			if _t <= 0.0 and global_position.distance_to(target) < 60.0:
				state = State.WINDUP
				_t = windup_time
				_dive_target = player.global_position
		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = State.DIVE
				_t = dive_time
				_hit_this_dive = false
				Audio.play("dodge", -10.0)
				var dir := (_dive_target - global_position).normalized()
				velocity = dir * dive_speed
				if absf(dir.x) > 0.1:
					facing = 1 if dir.x > 0.0 else -1
		State.DIVE:
			_t -= delta
			if player and not _hit_this_dive and not player.health.is_dead:
				_contact(player)
			if _t <= 0.0 or is_on_floor() or is_on_wall() or global_position.distance_to(_dive_target) < 10.0:
				_start_recover()
		State.RECOVER:
			velocity = velocity.move_toward(Vector2(0, -stalk_speed), 900.0 * delta)
			_t -= delta
			if _t <= 0.0:
				_side = -_side
				state = State.STALK if is_engaged else State.IDLE
				_t = stalk_time


func _start_recover() -> void:
	state = State.RECOVER
	_t = recover_time


func _contact(player: Player) -> void:
	for target in HitQuery.box(self, global_position, body_size + Vector2(6, 6), HitQuery.LAYER_PLAYER):
		if target == player:
			var dir := 1.0 if player.global_position.x >= global_position.x else -1.0
			if player.take_hit(Hit.new(contact_damage, Vector2(contact_knockback.x * dir, contact_knockback.y), self,
					PackedStringArray(["contact"]))):
				_hit_this_dive = true
				_start_recover()


func _try_detect(player: Player) -> void:
	if player == null or player.health.is_dead:
		return
	var d := player.global_position - global_position
	if absf(d.x) <= detect_range and absf(d.y) <= detect_height:
		set_engaged(true)
		state = State.STALK
		_t = stalk_time
		_lost_t = 0.0


func _track(player: Player, delta: float) -> void:
	if player == null:
		_disengage()
		return
	if player.global_position.distance_to(global_position) > disengage_range:
		_lost_t += delta
		if _lost_t >= disengage_time:
			_disengage()
	else:
		_lost_t = 0.0


func _disengage() -> void:
	set_engaged(false)
	_home = global_position
	state = State.IDLE


func apply_haste(factor: float) -> void:
	stalk_speed *= factor
	dive_speed *= factor
	stalk_time /= factor
	windup_time /= factor
	recover_time /= factor


func is_telegraphing() -> bool:
	return state == State.WINDUP and not is_dead


func _on_interrupted() -> void:
	_start_recover()


func _on_knockback_end() -> void:
	_start_recover()


func _on_died() -> void:
	state = State.IDLE


func weakness() -> Weakness:
	return Weakness.MAGIC


func body_color() -> Color:
	return tint


func _draw() -> void:
	var alpha := 1.0 - death_progress() if is_dead else 1.0
	var body := body_color()
	if hit_flash() > 0.0:
		body = body.lerp(Color.WHITE, 0.8)
	elif is_telegraphing():
		body = body.lerp(Color("#ff4030"), 0.4 + 0.3 * sin(_anim * 40.0))
	body.a = alpha
	var wing := Color(WING if hit_flash() <= 0.0 else Color.WHITE, alpha)
	var flap := sin(_anim * (26.0 if state == State.DIVE else 14.0))
	if is_dead:
		flap = -0.6
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	for side in [-1.0, 1.0]:
		var tip := Vector2(side * 22.0, -6.0 - 12.0 * flap)
		var mid := Vector2(side * 13.0, 2.0 - 6.0 * flap)
		draw_colored_polygon(PackedVector2Array([Vector2(side * 4.0, -4.0), tip, mid, Vector2(side * 4.0, 4.0)]), wing)
	draw_circle(Vector2.ZERO, 8.0, body)
	# Ears and eyes.
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -5), Vector2(-4, -13), Vector2(-1, -6)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -5), Vector2(4, -13), Vector2(1, -6)]), body)
	draw_circle(Vector2(3, -1), 1.8, Color(1, 0.3, 0.25, alpha))
	draw_circle(Vector2(-1.5, -1), 1.5, Color(1, 0.3, 0.25, alpha))
	draw_line(Vector2(1, 4), Vector2(2, 6.5), Color(1, 1, 1, alpha), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_telegraphing():
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-10, -16), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, 4, Color.BLACK)
		draw_string(font, Vector2(-10, -16), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("#ff4030"))
	if not is_dead and health < max_health:
		draw_rect(Rect2(-12, -22, 24, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-12, -22, 24 * health / max_health, 3), Color("#e04040"))
	draw_weakness(Vector2(0, -32))
