class_name Projectile
extends Area2D
## Straight-flying magic projectile. Friendly shots damage enemies and breakables; hostile shots
## damage the player. Removed on impact with terrain, a valid target, or when its range runs out.

var velocity: Vector2 = Vector2.ZERO
var damage: int = 0
var knockback: Vector2 = Vector2.ZERO
var kind: String = "projectile"
var charged: bool = false
var hostile: bool = false
var radius: float = 6.0
var color: Color = Color("#b57bff")
var range_left: float = 400.0
var _age: float = 0.0
var _dead: bool = false
var _trail: Array[Vector2] = []


static func spawn(world: Node, pos: Vector2, dir: Vector2, speed: float, dmg: int, knock: Vector2,
		reach: float, rad: float, col: Color, is_hostile: bool, hit_kind: String, is_charged: bool = false) -> Projectile:
	var p := Projectile.new()
	p.position = pos
	p.velocity = dir.normalized() * speed
	p.damage = dmg
	p.knockback = knock
	p.kind = hit_kind
	p.charged = is_charged
	p.hostile = is_hostile
	p.radius = rad
	p.color = col
	p.range_left = reach
	p.z_index = 45
	p.collision_layer = Config.LAYER_PROJECTILE
	if is_hostile:
		p.collision_mask = Config.LAYER_PLAYER | Config.LAYER_WORLD
	else:
		p.collision_mask = Config.LAYER_ENEMY | Config.LAYER_HAZARD | Config.LAYER_WORLD
	var shape := CircleShape2D.new()
	shape.radius = rad * 0.9
	var collider := CollisionShape2D.new()
	collider.shape = shape
	p.add_child(collider)
	world.add_child(p)
	p.body_entered.connect(p._on_body_entered)
	return p


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	var step := velocity * delta
	_trail.append(global_position)
	if _trail.size() > 9:
		_trail.pop_front()
	position += step
	range_left -= step.length()
	if range_left <= 0.0:
		_fizzle()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body is Player:
		if hostile:
			var info := HitInfo.make(damage, Vector2(knockback.x * signf(velocity.x), knockback.y), self, kind)
			info.charged = charged
			body.receive_hit(info)
			_impact(Color("#ff5f6d"))
		return
	if body.has_method("receive_hit") and not hostile:
		var info := HitInfo.make(damage, Vector2(knockback.x * signf(velocity.x), knockback.y), self, kind)
		info.from_player = true
		info.charged = charged
		body.receive_hit(info)
		_impact(color)
		return
	if body is StaticBody2D or body is TileMapLayer or body is CharacterBody2D:
		_impact(color)


func _impact(burst_color: Color) -> void:
	if _dead:
		return
	_dead = true
	Fx.burst(global_position, burst_color, 12 if not charged else 22, 240.0, 0.4)
	Fx.flash(global_position, burst_color, radius * 2.2, 0.14)
	if charged:
		Fx.shake(5.0)
	set_deferred("monitoring", false)
	queue_free()


func _fizzle() -> void:
	if _dead:
		return
	_dead = true
	Fx.burst(global_position, color, 6, 120.0, 0.3)
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + 0.12 * sin(_age * 26.0)
	var n := _trail.size()
	for i in range(n):
		var t := float(i + 1) / float(n + 1)
		var local := to_local(_trail[i])
		draw_circle(local, radius * t * 0.9, Color(color.r, color.g, color.b, 0.22 * t))
	draw_circle(Vector2.ZERO, radius * 2.1 * pulse, Color(color.r, color.g, color.b, 0.18))
	draw_circle(Vector2.ZERO, radius * 1.4 * pulse, Color(color.r, color.g, color.b, 0.45))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(1.0, 0.97, 1.0, 0.95))
