class_name SpikeTrap
extends Area2D
## A strip of floor spikes (top-left origin, usually the bottom of a shallow
## pit). Hurts the player and enemies on contact and bounces them up. Each body
## is hit at most every `repeat_time` seconds. Enemies knocked in take heavy
## damage, so spikes finish off goblins. Hits are tagged "hazard" so kills can
## be credited to the environment.

@export var size := Vector2(96, 32)
@export var player_damage := 15.0
@export var enemy_damage := 30.0
@export var bounce := 430.0
@export var repeat_time := 0.5
@export var spike_height := 14.0

## instance id -> seconds until that body can be hit again
var _cooldowns := {}


func _ready() -> void:
	add_to_group("hazards")
	collision_layer = 0
	collision_mask = HitQuery.LAYER_PLAYER | HitQuery.LAYER_ENEMIES
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x - 4.0, spike_height)
	shape.shape = rect
	shape.position = Vector2(size.x * 0.5, size.y - spike_height * 0.5)
	add_child(shape)


func _physics_process(delta: float) -> void:
	for id: int in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	for body in get_overlapping_bodies():
		var id := body.get_instance_id()
		if _cooldowns.has(id):
			continue
		var tags := PackedStringArray(["hazard", "spikes"])
		if body is Player:
			var p := body as Player
			if p.take_hit(Hit.new(player_damage, Vector2(0, -bounce), self, tags)):
				_cooldowns[id] = repeat_time
		elif body is EnemyBase and not (body as EnemyBase).is_dead:
			(body as EnemyBase).take_hit(Hit.new(enemy_damage, Vector2(0, -bounce * 0.7), self, tags))
			_cooldowns[id] = repeat_time


func _draw() -> void:
	var metal := Color("#c8ccd4")
	var base_y := size.y
	var x := 0.0
	while x < size.x - 1.0:
		var w := minf(12.0, size.x - x)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, base_y), Vector2(x + w * 0.5, base_y - spike_height - 2.0), Vector2(x + w, base_y)]), metal)
		draw_line(Vector2(x + w * 0.5, base_y - spike_height - 2.0), Vector2(x + w * 0.5, base_y - 4.0), Color("#8a2a2a"), 1.0)
		x += 12.0
