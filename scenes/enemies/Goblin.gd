class_name Goblin
extends EnemyBase
## Ground melee enemy: patrols, detects, chases and swings a club.
## The swing is telegraphed (club raised + "!") and armored against light hits.

enum State { IDLE, PATROL, CHASE, WINDUP, RECOVER }

const SKIN := Color("#6fae4f")
const CLOTH := Color("#7a5230")
const CLUB := Color("#8a5a2b")

@export_group("Movement")
@export var patrol_speed := 60.0
@export var chase_speed := 135.0
@export var patrol_distance := 110.0
@export var idle_time := 0.9
@export_group("Detection")
@export var detect_range := 280.0
@export var detect_height := 110.0
## Leave combat after the player has been this far away for disengage_time.
@export var disengage_range := 520.0
@export var disengage_time := 3.0
@export_group("Attack")
@export var attack_range := 44.0
@export var attack_damage := 12.0
@export var attack_knockback := Vector2(260, -200)
@export var attack_windup := 0.5
@export var attack_recovery := 0.55
@export var attack_cooldown := 0.9
## Hitbox relative to origin, facing right.
@export var attack_hitbox := Rect2(0, -24, 50, 42)

var state := State.PATROL

var _state_t := 0.0
var _attack_cd := 0.0
var _home_x := 0.0
var _patrol_dir := -1
var _lost_t := 0.0
var _swing_t := 0.0


func _ready() -> void:
	super._ready()
	_home_x = global_position.x


func _ai(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_swing_t = maxf(_swing_t - delta, 0.0)
	var player := get_player()
	if player and player.health.is_dead and is_engaged:
		_disengage()

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			_state_t -= delta
			if _state_t <= 0.0:
				state = State.PATROL
			_try_detect(player)
		State.PATROL:
			var target_x := _home_x + _patrol_dir * patrol_distance
			if absf(global_position.x - target_x) < 4.0 or is_ledge_ahead(_patrol_dir) or is_wall_ahead(_patrol_dir):
				_patrol_dir *= -1
				state = State.IDLE
				_state_t = idle_time
				velocity.x = 0.0
			else:
				facing = _patrol_dir
				velocity.x = facing * patrol_speed
			_try_detect(player)
		State.CHASE:
			_chase(player, delta)
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_strike()
				state = State.RECOVER
				_state_t = attack_recovery
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_attack_cd = attack_cooldown
				state = State.CHASE if is_engaged else State.PATROL


func _try_detect(player: Player) -> void:
	if player == null or player.health.is_dead:
		return
	var d := player.global_position - global_position
	if absf(d.x) <= detect_range and absf(d.y) <= detect_height:
		set_engaged(true)
		state = State.CHASE
		_lost_t = 0.0


func _chase(player: Player, delta: float) -> void:
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

	if absf(d.x) <= attack_range and absf(d.y) < 50.0 and _attack_cd <= 0.0:
		state = State.WINDUP
		_state_t = attack_windup
		velocity.x = 0.0
	elif absf(d.x) > attack_range * 0.75 and not is_ledge_ahead(facing) and not is_wall_ahead(facing):
		velocity.x = facing * chase_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)


func _disengage() -> void:
	set_engaged(false)
	_home_x = global_position.x
	state = State.IDLE
	_state_t = idle_time


func _strike() -> void:
	if is_dead:
		return
	_swing_t = 0.15
	var center := attack_hitbox.get_center()
	center.x *= facing
	var world_center := global_position + center
	var hit := Hit.new(attack_damage, Vector2(attack_knockback.x * facing, attack_knockback.y), self, PackedStringArray(["melee"]))
	for target in HitQuery.box(self, world_center, attack_hitbox.size, HitQuery.LAYER_PLAYER):
		if target.has_method("take_hit"):
			target.take_hit(hit)
	Fx.slash(world_center, facing, 26.0, Color("#ff6040"), 0.15)


func apply_haste(factor: float) -> void:
	patrol_speed *= factor
	chase_speed *= factor
	attack_windup /= factor
	attack_recovery /= factor
	attack_cooldown /= factor


func is_armored() -> bool:
	return state == State.WINDUP


func is_telegraphing() -> bool:
	return state == State.WINDUP and not is_dead


func _on_interrupted() -> void:
	if state == State.WINDUP or state == State.RECOVER:
		_attack_cd = attack_cooldown * 0.5
	state = State.CHASE


func _on_knockback_end() -> void:
	state = State.CHASE if is_engaged else State.PATROL


func _on_died() -> void:
	state = State.IDLE


func body_color() -> Color:
	return SKIN


func _draw() -> void:
	var alpha := 1.0 - death_progress() if is_dead else 1.0
	var skin := SKIN.lerp(Color.WHITE, 0.8) if hit_flash() > 0.0 else SKIN
	if is_telegraphing():
		skin = skin.lerp(Settings.warn_color(), 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.03))
	skin.a = alpha
	var cloth := Color(CLOTH, alpha)
	var club := Color(CLUB, alpha)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	if is_dead:
		draw_set_transform(Vector2(0, 10), -PI * 0.5 * facing, Vector2(facing, 1))
	# Legs.
	draw_line(Vector2(-5, 8), Vector2(-6, 20), skin, 5.0)
	draw_line(Vector2(5, 8), Vector2(6, 20), skin, 5.0)
	# Body + loincloth.
	draw_rect(Rect2(-10, -8, 20, 18), skin)
	draw_rect(Rect2(-11, 4, 22, 7), cloth)
	# Head with pointy ears.
	var head := Vector2(3, -15)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -2), head + Vector2(-16, -8), head + Vector2(-5, -6)]), skin)
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, -2), head + Vector2(15, -9), head + Vector2(5, -6)]), skin)
	draw_circle(head, 8.0, skin)
	draw_circle(head + Vector2(4, -1), 2.0, Color(1, 0.9, 0.2, alpha))
	draw_line(head + Vector2(1, 4), head + Vector2(7, 4), Color(0.1, 0.1, 0.1, alpha), 1.5)
	# Club: raised during windup, swung forward during strike/recovery.
	var hand := Vector2(8, -2)
	var club_tip := Vector2(14, -22)
	if state == State.WINDUP:
		hand = Vector2(-4, -12)
		club_tip = Vector2(-18, -34)
	elif _swing_t > 0.0 or state == State.RECOVER:
		club_tip = Vector2(36, 6)
	draw_line(hand, club_tip, club, 5.0)
	draw_circle(club_tip, 5.5, club)
	draw_circle(hand, 3.0, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if is_telegraphing():
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-10, -38), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 22, 4, Color.BLACK)
		draw_string(font, Vector2(-10, -38), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 22, Settings.warn_color())

	# Health bar once damaged.
	if not is_dead and health < max_health:
		var w := 30.0
		var top := -body_size.y * 0.5 - 14.0
		draw_rect(Rect2(-w * 0.5, top, w, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top, w * health / max_health, 4), Color("#e04040"))
