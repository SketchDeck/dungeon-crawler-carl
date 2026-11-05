class_name PotionPickup
extends Area2D
## A health potion on the ground. Touching it collects it if there is room (capacity 10).
## When the pack is full the potion stays on the ground, as the spec requires.

var collectible: bool = true
var _age: float = 0.0
var _taken: bool = false
var _warned: bool = false


static func spawn(world: Node, pos: Vector2) -> PotionPickup:
	var pickup := PotionPickup.new()
	pickup.position = pos
	pickup.z_index = 15
	pickup.collision_layer = Config.LAYER_PICKUP
	pickup.collision_mask = Config.LAYER_PLAYER
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	pickup.add_child(collider)
	pickup.body_entered.connect(pickup._on_body_entered)
	# Spawns often happen inside physics callbacks (a projectile hitting a crate), where Godot
	# cannot add new physics objects right away, so the node joins the tree at the end of the frame.
	world.add_child.call_deferred(pickup)
	return pickup


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _taken or not collectible or not (body is Player):
		return
	if Game.potions.is_full():
		if not _warned:
			_warned = true
			Fx.text(global_position + Vector2(0.0, -24.0), "Pack full", Color("#9aa4b2"), 14)
		return
	_taken = true
	Game.potions.add(1)
	Sfx.play("pickup")
	Fx.burst(global_position, Color("#6dff9a"), 16, 200.0, 0.5)
	Fx.glow(global_position, Color("#6dff9a"), 26.0, 0.3)
	Fx.text(global_position + Vector2(0.0, -24.0), "+1 potion", Color("#6dff9a"), 15)
	queue_free()


func _draw() -> void:
	var bob := sin(_age * 3.4) * 3.0
	var glow := 0.18 + 0.08 * sin(_age * 5.0)
	draw_circle(Vector2(0.0, bob), 15.0, Color(0.42, 1.0, 0.6, glow))
	draw_set_transform(Vector2(0.0, 12.0 + bob), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 7.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var glass := Color("#7dffb0")
	draw_circle(Vector2(0.0, 3.0 + bob), 6.5, Color("#1d6b44"))
	draw_circle(Vector2(0.0, 3.0 + bob), 5.2, glass)
	draw_circle(Vector2(-2.0, 1.0 + bob), 1.6, Color(1.0, 1.0, 1.0, 0.85))
	draw_rect(Rect2(Vector2(-2.5, -6.0 + bob), Vector2(5.0, 4.0)), Color("#c9b28a"))
	draw_rect(Rect2(Vector2(-3.5, -8.0 + bob), Vector2(7.0, 2.5)), Color("#8a5a2b"))
