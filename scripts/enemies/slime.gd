class_name Slime
extends EnemyBase
## Hopping blob. Each hop is telegraphed with a visible squash, so the timing is predictable.
## Touching a slime hurts. Small slimes are spawned by the Mutating Slime boss.

var small: bool = false
var _hop_cd: float = 1.2
var _telegraph_t: float = 0.0
var _touch_cd: float = 0.0
var _wander_dir: float = 1.0
var _spawn_x: float = 0.0


func _ready() -> void:
	super._ready()
	base_color = Color("#6ee08a") if not small else Color("#9cf07c")
	setup_health(Config.SLIME_HP if not small else 12)
	drop_chance = Config.POTION_DROP_CHANCE if not small else 0.05
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0 if not small else 9.0
	shape.shape = circle
	shape.position = Vector2(0.0, 4.0)
	add_child(shape)
	_spawn_x = global_position.x


func display_name() -> String:
	return "Slime" if not small else "Slimelet"


func set_patrol(min_x: float, max_x: float) -> void:
	_spawn_x = (min_x + max_x) * 0.5
	_patrol_min = min_x
	_patrol_max = max_x


var _patrol_min: float = 0.0
var _patrol_max: float = 0.0


func _think(delta: float) -> void:
	_touch_cd = maxf(0.0, _touch_cd - delta)
	var p := _find_player()
	var grounded := is_on_floor()
	if grounded:
		if _telegraph_t > 0.0:
			_telegraph_t -= delta
			velocity.x = 0.0
			if _telegraph_t <= 0.0:
				_hop(p)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			_hop_cd -= delta
			if engaged and p != null and _hop_cd <= 0.0:
				facing = 1 if p.global_position.x >= global_position.x else -1
				_telegraph_t = Config.SLIME_TELEGRAPH
				_hop_cd = Config.SLIME_HOP_INTERVAL
			elif not engaged:
				_wander(delta)
	if p != null and p.alive and _touch_cd <= 0.0 and _touching(p):
		_touch_cd = 0.9
		var away := signf(p.global_position.x - global_position.x)
		if away == 0.0:
			away = 1.0
		var info := HitInfo.make(Config.SLIME_DAMAGE if not small else 5, Vector2(away * 140.0, -160.0), self, "contact")
		p.receive_hit(info)


func _hop(p: Player) -> void:
	var dir := 1.0
	if p != null:
		dir = 1.0 if p.global_position.x >= global_position.x else -1.0
	facing = int(dir)
	velocity.y = Config.SLIME_HOP_VELOCITY * (0.9 if small else 1.0)
	velocity.x = dir * Config.SLIME_HOP_SPEED


func _wander(_delta: float) -> void:
	if _patrol_max <= _patrol_min:
		velocity.x = 0.0
		return
	if global_position.x >= _patrol_max:
		_wander_dir = -1.0
	elif global_position.x <= _patrol_min:
		_wander_dir = 1.0
	velocity.x = _wander_dir * 36.0
	facing = int(_wander_dir)


func _touching(p: Player) -> bool:
	var offset := p.global_position - global_position
	return absf(offset.x) < 22.0 and absf(offset.y) < 28.0


func _on_hurt(_hit: HitInfo) -> void:
	_telegraph_t = 0.0


func _draw_body() -> void:
	var r := 16.0 if not small else 10.0
	var squash := 0.0
	if _telegraph_t > 0.0:
		squash = 1.0 - _telegraph_t / Config.SLIME_TELEGRAPH
	var stretch := 0.0
	if not is_on_floor():
		stretch = 1.0
	var wobble := sin(_t * 5.0) * 0.04
	var sx := 1.0 + 0.32 * squash - 0.12 * stretch + wobble
	var sy := 1.0 - 0.3 * squash + 0.18 * stretch - wobble
	var f := float(facing)

	draw_set_transform(Vector2(0.0, 16.0 * (1.0 - sy * 0.5 + 0.1)), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, r * 1.1, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2(0.0, r * 0.2), 0.0, Vector2(sx, sy))
	draw_circle(Vector2.ZERO, r, base_color.darkened(0.3))
	draw_circle(Vector2(0.0, -2.0), r * 0.84, base_color)
	draw_circle(Vector2(-r * 0.32, -r * 0.42), r * 0.26, Color(1.0, 1.0, 1.0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var eye_y := -r * 0.1 + r * 0.2 - (r * 0.25 * squash)
	var eye_x := f * r * 0.25
	for side in [-1.0, 1.0]:
		var e := Vector2(eye_x + side * r * 0.32, eye_y)
		draw_circle(e, r * 0.24, Color("#f7fff3"))
		draw_circle(e + Vector2(f * 1.2, 0.5), r * 0.12, Color("#16202a"))
	var warn := _telegraph_t > 0.0
	if warn:
		draw_string(ThemeDB.fallback_font, Vector2(-4.0, -r - 8.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14,
			Color("#ffd166"))
