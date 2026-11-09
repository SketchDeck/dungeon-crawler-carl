class_name CrumblePlatform
extends Node2D
## Rotten catwalk: a one-way platform that starts to crack when the player
## stands on it, falls away `crumble_time` later and grows back after
## `respawn_time`. Enemies don't set it off.

var size := Vector2(96, 12)
var crumble_time := 0.5
var respawn_time := 2.5

var block: SolidBlock
var crumbling := false
var gone := false

var _t := 0.0


func _ready() -> void:
	block = SolidBlock.new()
	block.size = size
	block.one_way = true
	block.color = Color("#7a6a4a")
	add_child(block)


func _physics_process(delta: float) -> void:
	queue_redraw()
	if gone:
		_t -= delta
		if _t <= 0.0:
			gone = false
			block.collision_layer = 1
			block.show()
		return
	if crumbling:
		_t -= delta
		block.position.x = sin(_t * 90.0) * 1.5
		if _t <= 0.0:
			crumbling = false
			gone = true
			_t = respawn_time
			block.collision_layer = 0
			block.position.x = 0.0
			block.hide()
			Audio.play("crumble", -4.0)
			Fx.burst(global_position + size * 0.5, Color("#7a6a4a"), size.x * 0.5, 0.3)
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.is_on_floor() and not p.health.is_dead:
		var feet := p.global_position.y + 28.0
		if absf(feet - global_position.y) <= 6.0 and p.global_position.x >= global_position.x - 10.0 \
				and p.global_position.x <= global_position.x + size.x + 10.0:
			crumbling = true
			_t = crumble_time


func _draw() -> void:
	if gone or not crumbling:
		return
	# Cracks spreading across the planks.
	var k := 1.0 - _t / crumble_time
	for i in 3:
		var x := size.x * (0.2 + 0.3 * i)
		draw_line(Vector2(x, 0), Vector2(x + 6, size.y * k), Color(0, 0, 0, 0.6), 2.0)
