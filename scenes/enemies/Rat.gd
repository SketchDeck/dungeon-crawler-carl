class_name Rat
extends EnemyBase
## Sewer rat (Floor 3). Small, fast and weak: scurries about, chases the
## player, crouches (the telegraph: it flattens and flashes) and then lunges.
## Only hurts during the lunge. Comes in packs.

enum State { IDLE, PATROL, CHASE, WINDUP, LUNGE, RECOVER }

const FUR := Color("#7a6a62")
const TAIL := Color("#e8a0a8")

@export_group("Movement")
@export var patrol_speed := 90.0
@export var chase_speed := 190.0
@export var patrol_distance := 90.0
@export_group("Detection")
@export var detect_range := 300.0
@export var detect_height := 100.0
@export var disengage_range := 560.0
@export var disengage_time := 3.0
@export_group("Lunge")
@export var lunge_range := 110.0
@export var windup_time := 0.35
@export var lunge_velocity := Vector2(340, -230)
@export var recover_time := 0.55
@export var contact_damage := 8.0
@export var contact_knockback := Vector2(200, -160)

var state := State.PATROL

var _t := 0.0
var _home_x := 0.0
var _patrol_dir := 1
var _lost_t := 0.0
var _anim := 0.0
var _hit_this_lunge := false


func _ready() -> void:
	super._ready()
	_home_x = global_position.x
	_patrol_dir = 1 if rng.randf() < 0.5 else -1


func _ai(delta: float) -> void:
	_anim += delta
	var player := get_player()
	if player and player.health.is_dead and is_engaged:
		_disengage()
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = State.PATROL
			_try_detect(player)
		State.PATROL:
			var target_x := _home_x + _patrol_dir * patrol_distance
			if absf(global_position.x - target_x) < 4.0 or is_ledge_ahead(_patrol_dir) or is_wall_ahead(_patrol_dir):
				_patrol_dir *= -1
				state = State.IDLE
				_t = 0.4
			else:
				facing = _patrol_dir
				velocity.x = facing * patrol_speed
			_try_detect(player)
		State.CHASE:
			if player == null:
				_disengage()
				return
			var d := player.global_position - global_position
			if absf(d.x) > 4.0:
				facing = 1 if d.x > 0.0 else -1
			if d.length() > disengage_range:
				_lost_t += delta
				if _lost_t >= disengage_time:
					_disengage()
					return
			else:
				_lost_t = 0.0
			if absf(d.x) <= lunge_range and absf(d.y) < 50.0 and is_on_floor():
				state = State.WINDUP
				_t = windup_time
				velocity.x = 0.0
			elif not is_ledge_ahead(facing) and not is_wall_ahead(facing):
				velocity.x = facing * chase_speed
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
		State.WINDUP:
			velocity.x = 0.0
			_t -= delta
			if _t <= 0.0:
				state = State.LUNGE
				_t = 0.6
				_hit_this_lunge = false
				velocity = Vector2(lunge_velocity.x * facing, lunge_velocity.y)
				Audio.play("squeak", -8.0)
		State.LUNGE:
			_t -= delta
			if player and not _hit_this_lunge and not player.health.is_dead:
				_contact(player)
			if (_t < 0.5 and is_on_floor()) or _t <= 0.0:
				state = State.RECOVER
				_t = recover_time
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			_t -= delta
			if _t <= 0.0:
				state = State.CHASE if is_engaged else State.PATROL


func _contact(player: Player) -> void:
	for target in HitQuery.box(self, global_position, body_size + Vector2(6, 4), HitQuery.LAYER_PLAYER):
		if target == player:
			var dir := 1.0 if player.global_position.x >= global_position.x else -1.0
			if player.take_hit(Hit.new(contact_damage, Vector2(contact_knockback.x * dir, contact_knockback.y), self,
					PackedStringArray(["contact"]))):
				_hit_this_lunge = true


func _try_detect(player: Player) -> void:
	if player == null or player.health.is_dead:
		return
	var d := player.global_position - global_position
	if absf(d.x) <= detect_range and absf(d.y) <= detect_height:
		set_engaged(true)
		state = State.CHASE
		_lost_t = 0.0


func _disengage() -> void:
	set_engaged(false)
	_home_x = global_position.x
	state = State.IDLE
	_t = 0.4


func apply_haste(factor: float) -> void:
	patrol_speed *= factor
	chase_speed *= factor
	windup_time /= factor
	recover_time /= factor


func is_telegraphing() -> bool:
	return state == State.WINDUP and not is_dead


func _on_interrupted() -> void:
	state = State.RECOVER
	_t = recover_time


func _on_knockback_end() -> void:
	state = State.CHASE if is_engaged else State.PATROL


func _on_died() -> void:
	state = State.IDLE


func body_color() -> Color:
	return FUR


func _draw() -> void:
	var alpha := 1.0 - death_progress() if is_dead else 1.0
	var fur := FUR
	if hit_flash() > 0.0:
		fur = fur.lerp(Color.WHITE, 0.8)
	elif is_telegraphing():
		fur = fur.lerp(Settings.warn_color(), 0.4 + 0.3 * sin(_anim * 40.0))
	fur.a = alpha
	var squash := 0.75 if state == State.WINDUP else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	if is_dead:
		draw_set_transform(Vector2(0, 4), PI * facing, Vector2(facing, 1))
	# Tail.
	var wag := sin(_anim * 10.0) * 3.0
	draw_polyline(PackedVector2Array([Vector2(-12, 4), Vector2(-20, 0 + wag), Vector2(-27, -4 - wag)]), Color(TAIL, alpha), 2.0)
	# Body, head, ear, eye, feet.
	draw_set_transform(Vector2(0, 8 - 8 * squash) if not is_dead else Vector2(0, 4), 0.0 if not is_dead else PI * facing,
		Vector2(facing, squash))
	draw_circle(Vector2(-2, 1), 9.0, fur)
	draw_circle(Vector2(7, 2), 6.5, fur)
	draw_colored_polygon(PackedVector2Array([Vector2(10, 2), Vector2(16, 4), Vector2(10, 6)]), fur)
	draw_circle(Vector2(16, 4), 1.4, Color(TAIL, alpha))
	draw_circle(Vector2(5, -5), 3.0, Color(TAIL.darkened(0.2), alpha))
	draw_circle(Vector2(9, 0), 1.5, Color(1, 0.2, 0.2, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_telegraphing():
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-10, -14), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, 4, Color.BLACK)
		draw_string(font, Vector2(-10, -14), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Settings.warn_color())
	if not is_dead and health < max_health:
		draw_rect(Rect2(-11, -16, 22, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-11, -16, 22 * health / max_health, 3), Color("#e04040"))
