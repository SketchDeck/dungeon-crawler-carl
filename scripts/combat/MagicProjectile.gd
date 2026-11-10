class_name MagicProjectile
extends Node2D
## Donut's magic bolt. Flies straight, hits the first enemy or switch it
## touches, stops at solid walls (not one-way platforms) and fizzles out at
## max_range. It is independent of the player, so it keeps flying when the
## combat mode changes. RoomManager frees every projectile when a room unloads.

signal hit_target(projectile: MagicProjectile, target: Node)

const GROUP := "player_projectiles"

var direction := 1
var speed := 560.0
var max_range := 380.0
## Drawn size; the hit check uses hit_radius, which is a little more forgiving.
var radius := 7.0
var hit_radius := 10.0
var hit: Hit
var heavy := false
var color := Color("#c77dff")
var mask := HitQuery.LAYER_ENEMIES | HitQuery.LAYER_HITTABLE | HitQuery.LAYER_WORLD
## Bolts curve up or down toward flying enemies ahead of them (Cave Bats), at
## up to this many pixels per second.
## Laser-Guided Tiara: fly through enemies, hitting each once.
var pierce := false
var seek_speed := 300.0
var seek_range := Vector2(320, 200)

var travelled := 0.0
var _t := 0.0
var _trail: Array[Vector2] = []
var _already_hit := {}


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	_t += delta
	var step := speed * delta
	global_position.x += direction * step
	travelled += step
	var flyer := _flyer_ahead()
	if flyer:
		global_position.y = move_toward(global_position.y, flyer.global_position.y, seek_speed * delta)
	_trail.push_front(global_position)
	if _trail.size() > 7:
		_trail.pop_back()

	var blocked := false
	var target: Node = null
	for body in HitQuery.circle(self, global_position, hit_radius, mask):
		if body.has_method("take_hit"):
			if _already_hit.has(body.get_instance_id()):
				continue
			if target == null or _ahead(body, target):
				target = body
		elif body is SolidBlock and (body as SolidBlock).one_way:
			continue
		elif body is CollisionObject2D and (body as CollisionObject2D).collision_layer & HitQuery.LAYER_WORLD:
			blocked = true
	if target:
		target.take_hit(hit)
		hit_target.emit(self, target)
		if pierce and target is EnemyBase:
			_already_hit[target.get_instance_id()] = true
			Fx.burst(global_position, color, radius * 1.8, 0.15)
			queue_redraw()
		else:
			_pop(1.0)
	elif blocked:
		_pop(0.6)
	elif travelled >= max_range:
		Fx.burst(global_position, Color(color, 0.6), radius * 1.4, 0.15)
		queue_free()
	else:
		queue_redraw()


## The nearest living flying enemy in front of the bolt, if any.
func _flyer_ahead() -> Node2D:
	if seek_speed <= 0.0:
		return null
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(Bat.GROUP_FLYERS):
		var e := node as EnemyBase
		if e == null or e.is_dead:
			continue
		var d := (e.global_position - global_position) * Vector2(direction, 1)
		if d.x < -4.0 or d.x > seek_range.x or absf(d.y) > seek_range.y:
			continue
		if d.x < best_d:
			best_d = d.x
			best = e
	return best


## Target closest to where the projectile came from.
func _ahead(a: Node, b: Node) -> bool:
	return (a as Node2D).global_position.x * direction < (b as Node2D).global_position.x * direction


func _pop(strength: float) -> void:
	Fx.burst(global_position, color, radius * 2.6 * strength, 0.22)
	Fx.burst(global_position, Color.WHITE, radius * 1.2 * strength, 0.12)
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	# Fading trail of sparkles behind the bolt.
	for i in range(_trail.size() - 1, 0, -1):
		var k := 1.0 - float(i) / _trail.size()
		draw_circle(to_local(_trail[i]), radius * (0.35 + 0.5 * k), Color(color, 0.35 * k))
	var pulse := 1.0 + 0.12 * sin(_t * 40.0)
	draw_circle(Vector2.ZERO, radius * 1.6 * pulse, Color(color, 0.25))
	draw_circle(Vector2.ZERO, radius * pulse, color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 0.95, 1))
	if heavy:
		# Charged blast: spinning ring of runes.
		for i in 4:
			var a := _t * 9.0 + i * TAU / 4.0
			draw_circle(Vector2(cos(a), sin(a)) * radius * 1.5, 2.5, Color(1, 0.9, 1, 0.9))
		draw_arc(Vector2.ZERO, radius * 1.9, 0, TAU, 24, Color(color.lightened(0.3), 0.7), 2.0)
