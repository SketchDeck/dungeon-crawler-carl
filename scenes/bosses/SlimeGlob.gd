class_name SlimeGlob
extends Node2D
## A glob lobbed by the Mutating Slime. Flies on a fixed arc (gravity only), so
## its landing spot is predictable and previewed by the boss's telegraph.
## Hurts the player on contact; in phase 2 it leaves an acid pool where it lands.

const GRAVITY := 1200.0
const PLAYER_HALF := Vector2(12, 28)
const DEFAULT_RADIUS := 9.0

var velocity := Vector2.ZERO
var radius := DEFAULT_RADIUS
var hit: Hit
var leaves_pool := false
var pool_width := 70.0
var pool_duration := 3.0

var _age := 0.0


func _ready() -> void:
	add_to_group("boss_hazards")


## Where a glob launched from `origin` with `vel` comes down to `ground_y`.
static func landing_x(origin: Vector2, vel: Vector2, ground_y: float) -> float:
	# Solve origin.y + vy t + g t^2 / 2 = ground_y for the positive root.
	var a := GRAVITY * 0.5
	var b := vel.y
	var c := origin.y - ground_y
	var t := (-b + sqrt(b * b - 4.0 * a * c)) / (2.0 * a)
	return origin.x + vel.x * t


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	if _age > 5.0:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.health.is_dead:
			continue
		var d := (global_position - player.global_position).abs()
		if d.x < PLAYER_HALF.x + radius and d.y < PLAYER_HALF.y + radius:
			player.take_hit(hit)
			_splat(false)
			return
	for body in HitQuery.circle(self, global_position, radius, HitQuery.LAYER_WORLD):
		if body is SolidBlock and (body as SolidBlock).one_way:
			continue
		_splat(velocity.y > 0.0)
		return
	queue_redraw()


func _splat(on_ground: bool) -> void:
	Audio.play("acid", -8.0)
	Fx.burst(global_position, Color("#8cff5a"), radius * 2.2, 0.2)
	if on_ground and leaves_pool:
		var pool := AcidPool.new()
		pool.width = pool_width
		pool.duration = pool_duration
		get_parent().add_child(pool)
		pool.global_position = _floor_below()
	set_physics_process(false)
	queue_free()


func _floor_below() -> Vector2:
	var from := global_position - Vector2(0, radius)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 48), HitQuery.LAYER_WORLD)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result["position"] if not result.is_empty() else global_position + Vector2(0, radius)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0.3, 0.6, 0.15, 0.5))
	draw_circle(Vector2.ZERO, radius, Color("#8cff5a"))
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, Color(1, 1, 1, 0.6))
