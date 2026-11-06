class_name Slime
extends EnemyBase
## Hopping enemy. Sits still, squashes down (the telegraph: it flattens and
## flashes) and then hops toward the player. It only hurts on contact while
## it's in the air, so its timing is easy to read: rest, squash, hop, land.
## Won't hop off ledges or into spike pits on its own, but can be knocked in.

enum State { REST, SQUASH, HOP }

const BODY := Color("#5ccf6a")

@export var tint := BODY
@export_group("Detection")
@export var detect_range := 300.0
@export var detect_height := 140.0
@export var disengage_range := 560.0
@export var disengage_time := 3.0
@export_group("Hopping")
## Rest on the ground between hops while chasing.
@export var hop_interval := 1.0
## Rest between idle hops when nobody's around.
@export var idle_hop_interval := 2.2
## The squash before each hop (the attack telegraph).
@export var squash_time := 0.35
@export var hop_speed := 190.0
@export var idle_hop_speed := 50.0
@export var hop_velocity := 430.0
@export var wander_distance := 60.0
@export_group("Attack")
@export var contact_damage := 10.0
@export var contact_knockback := Vector2(240, -220)

var state := State.REST

var _t := 0.0
var _home_x := 0.0
var _lost_t := 0.0
var _hop_dir := 1
var _air_t := 0.0
var _hit_this_hop := false
var _land_t := 0.0
var _anim := 0.0


func _ready() -> void:
	super._ready()
	_home_x = global_position.x
	_t = rng.randf_range(0.3, idle_hop_interval)


func _ai(delta: float) -> void:
	_anim += delta
	_land_t = maxf(_land_t - delta, 0.0)
	var player := get_player()
	if player and player.health.is_dead and is_engaged:
		_disengage()
	if is_engaged:
		_track(player, delta)
	else:
		_try_detect(player)

	match state:
		State.REST:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			_t -= delta
			if _t <= 0.0 and is_on_floor():
				state = State.SQUASH
				_t = squash_time
				_hop_dir = _choose_dir(player)
				if _hop_dir != 0:
					facing = _hop_dir
		State.SQUASH:
			velocity.x = 0.0
			_t -= delta
			if _t <= 0.0:
				_hop()
		State.HOP:
			_air_t += delta
			if is_engaged and not _hit_this_hop and player and not player.health.is_dead:
				_contact(player)
			if _air_t > 0.08 and is_on_floor():
				state = State.REST
				_t = hop_interval if is_engaged else idle_hop_interval
				_land_t = 0.15
				velocity.x = 0.0


func _choose_dir(player: Player) -> int:
	if is_engaged and player:
		return 1 if player.global_position.x > global_position.x else -1
	var off := global_position.x - _home_x
	if absf(off) > wander_distance:
		return -1 if off > 0.0 else 1
	return 1 if rng.randf() < 0.5 else -1


func _hop() -> void:
	var speed := hop_speed if is_engaged else idle_hop_speed
	var air_time := 2.0 * hop_velocity / gravity
	# Only hop sideways if there's solid ground both next to it and where it lands.
	var dir := _hop_dir
	if dir != 0 and (is_wall_ahead(dir) or not _ground_at(dir * (body_size.x * 0.5 + 6.0)) \
			or not _ground_at(dir * (speed * air_time + body_size.x * 0.5))):
		dir = 0
	velocity = Vector2(dir * speed, -hop_velocity)
	state = State.HOP
	_air_t = 0.0
	_hit_this_hop = false


func _ground_at(dx: float) -> bool:
	var from := global_position + Vector2(dx, 0.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, body_size.y * 0.5 + 20.0), HitQuery.LAYER_WORLD)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _contact(player: Player) -> void:
	for target in HitQuery.box(self, global_position, body_size, HitQuery.LAYER_PLAYER):
		if target == player:
			var dir := 1.0 if player.global_position.x >= global_position.x else -1.0
			if player.take_hit(Hit.new(contact_damage, Vector2(contact_knockback.x * dir, contact_knockback.y), self,
					PackedStringArray(["contact"]))):
				_hit_this_hop = true


func _try_detect(player: Player) -> void:
	if player == null or player.health.is_dead:
		return
	var d := player.global_position - global_position
	if absf(d.x) <= detect_range and absf(d.y) <= detect_height:
		set_engaged(true)
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
	_home_x = global_position.x


func is_telegraphing() -> bool:
	return state == State.SQUASH and not is_dead


func _on_interrupted() -> void:
	state = State.REST
	_t = hop_interval


func _on_knockback_end() -> void:
	state = State.REST
	_t = hop_interval * 0.6


func _on_died() -> void:
	state = State.REST


func body_color() -> Color:
	return tint


func _draw() -> void:
	var alpha := 1.0 - death_progress() if is_dead else 1.0
	var c := body_color()
	if hit_flash() > 0.0:
		c = c.lerp(Color.WHITE, 0.8)
	elif is_telegraphing():
		c = c.lerp(Color("#fff27a"), 0.35 + 0.3 * sin(_anim * 40.0))
	c.a = alpha * 0.92
	var w := body_size.x * 0.5
	var h := body_size.y
	# Squash and stretch.
	var sx := 1.0
	var sy := 1.0
	if state == State.SQUASH:
		var k := 1.0 - _t / maxf(squash_time, 0.01)
		sx = 1.0 + 0.3 * k
		sy = 1.0 - 0.35 * k
	elif state == State.HOP and not is_on_floor():
		sx = 0.85
		sy = 1.2
	elif _land_t > 0.0:
		sx = 1.25
		sy = 0.75
	if is_dead:
		sy *= 1.0 - 0.7 * death_progress()
		sx *= 1.0 + 0.4 * death_progress()
	var feet := h * 0.5
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(Vector2(cos(a) * w * sx, feet + sin(a) * h * sy))
	pts.append(Vector2(w * sx, feet))
	pts.append(Vector2(-w * sx, feet))
	draw_colored_polygon(pts, c)
	draw_polyline(pts, Color(c.darkened(0.35), alpha), 1.5)
	# Shine and eyes.
	draw_circle(Vector2(-w * 0.35 * sx, feet - h * 0.7 * sy), w * 0.18, Color(1, 1, 1, 0.45 * alpha))
	var eye_y := feet - h * 0.5 * sy
	for ex in [-0.25, 0.3]:
		var e := Vector2((ex + 0.12 * facing) * w * 2.0 * sx * 0.5, eye_y)
		draw_circle(e, maxf(2.0, w * 0.16), Color(1, 1, 1, alpha))
		draw_circle(e + Vector2(facing * 1.0, 0.5), maxf(1.0, w * 0.08), Color(0, 0, 0, alpha))
	if is_telegraphing():
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-10, -h * 0.5 - 12), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, 4, Color.BLACK)
		draw_string(font, Vector2(-10, -h * 0.5 - 12), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("#fff27a"))
	if not is_dead and health < max_health:
		var bw := maxf(22.0, body_size.x)
		var top := -h * 0.5 - 8.0
		draw_rect(Rect2(-bw * 0.5, top, bw, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-bw * 0.5, top, bw * health / max_health, 4), Color("#e04040"))
