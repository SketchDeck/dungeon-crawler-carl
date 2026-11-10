class_name AcidPool
extends Node2D
## Temporary acid puddle left by the Mutating Slime. Hurts the player while
## they stand in it (the usual hurt invulnerability spaces out the ticks).
## Origin is the centre of the puddle's surface on the floor.

const PLAYER_FEET := 28.0

var width := 140.0
var duration := 2.5
var damage := 8.0

var _t := 0.0


func _ready() -> void:
	add_to_group("boss_hazards")
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()
	if _t < 0.15:
		return  # a moment to form before it hurts
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.health.is_dead:
			continue
		var feet := player.global_position.y + PLAYER_FEET
		if absf(player.global_position.x - global_position.x) < width * 0.5 + 10.0 and absf(feet - global_position.y) < 10.0:
			player.take_hit(Hit.new(damage, Vector2(0, -260), self, PackedStringArray(["hazard", "acid"])))


func _draw() -> void:
	var grow := minf(_t / 0.15, 1.0)
	var fade := clampf((duration - _t) / 0.4, 0.0, 1.0)
	var w := width * 0.5 * grow
	var c := Color(0.55, 1.0, 0.25, 0.55 * fade)
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, w, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 5:
		var x := (fmod(i * 0.37 + _t * 0.6, 1.0) - 0.5) * w * 1.6
		var y := -4.0 - fmod(_t * 1.5 + i * 0.3, 1.0) * 10.0
		draw_circle(Vector2(x, y), 2.5, Color(0.7, 1.0, 0.4, 0.7 * fade))
