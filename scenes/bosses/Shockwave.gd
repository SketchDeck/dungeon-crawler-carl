class_name Shockwave
extends Node2D
## Ground shockwave from the Goblin Brute's slam. Travels along the floor and
## hits the player once if their feet are below `height` when it passes, so
## jumping over it (or standing on a platform) avoids it. Stops at walls.

const PLAYER_HALF_WIDTH := 12.0
const PLAYER_FEET := 28.0

var direction := 1
var speed := 360.0
var max_range := 300.0
var height := 26.0
var hit: Hit

var travelled := 0.0
var _has_hit := false
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	var step := speed * delta
	position.x += direction * step
	travelled += step
	if travelled >= max_range or _hits_wall():
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and not _has_hit and not player.health.is_dead:
		var feet := player.global_position.y + PLAYER_FEET
		var close := absf(player.global_position.x - global_position.x) < PLAYER_HALF_WIDTH + 16.0
		if close and feet > global_position.y - height and feet < global_position.y + 8.0:
			if player.take_hit(hit):
				_has_hit = true
	queue_redraw()


func _hits_wall() -> bool:
	for body in HitQuery.circle(self, global_position + Vector2(direction * 12.0, -14.0), 6.0, HitQuery.LAYER_WORLD):
		if not (body is SolidBlock and (body as SolidBlock).one_way):
			return true
	return false


func _draw() -> void:
	var fade := clampf((max_range - travelled) / (max_range * 0.2), 0.0, 1.0)
	var rock := Color(0.75, 0.6, 0.45, fade)
	var hot := Color(1.0, 0.55, 0.3, 0.8 * fade)
	# Jagged crest of rock shards, tallest at the leading edge.
	for i in 4:
		var x := -direction * i * 9.0
		var h := height * (1.0 - i * 0.2) * (0.85 + 0.15 * sin(_t * 40.0 + i))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 6, 0), Vector2(x + direction * 2, -h), Vector2(x + 6, 0)]), rock if i > 0 else hot)
	# Dust trail.
	draw_rect(Rect2(minf(0.0, -direction * 40.0), -5, 40, 5), Color(0.8, 0.7, 0.55, 0.35 * fade))
