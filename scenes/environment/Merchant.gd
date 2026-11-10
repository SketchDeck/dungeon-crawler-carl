class_name Merchant
extends Interactable
## A safe-room shopkeeper (a goblin in a nice hat). Interact to spend the gold
## enemies drop: potions, loot boxes and upgrades. Main runs the shop screen.

var _bob := 0.0


func prompt() -> String:
	return "Shop"


func interact() -> bool:
	var stats := get_tree().get_first_node_in_group(RunStats.GROUP) as RunStats
	if stats == null:
		return false
	stats.shop_requested.emit()
	return true


func _draw() -> void:
	_bob = sin(_t * 2.0) * 1.5
	# Counter.
	draw_rect(Rect2(-26, -20, 52, 20), Color("#6a4a2a"))
	draw_rect(Rect2(-28, -24, 56, 5), Color("#8a6a3a"))
	# Shopkeeper behind it.
	var skin := Color("#6fae4f")
	var head := Vector2(0, -38 + _bob)
	draw_rect(Rect2(-9, -30 + _bob, 18, 10), Color("#3a5a9a"))
	draw_circle(head, 8.0, skin)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -2), head + Vector2(-15, -7), head + Vector2(-5, -6)]), skin)
	draw_colored_polygon(PackedVector2Array([head + Vector2(6, -2), head + Vector2(15, -7), head + Vector2(5, -6)]), skin)
	draw_circle(head + Vector2(-3, -1), 1.5, Color.BLACK)
	draw_circle(head + Vector2(3, -1), 1.5, Color.BLACK)
	draw_arc(head + Vector2(0, 2), 3.0, 0.2, PI - 0.2, 8, Color.BLACK, 1.0)
	# Top hat.
	draw_rect(Rect2(head + Vector2(-9, -9), Vector2(18, 3)), Color("#222"))
	draw_rect(Rect2(head + Vector2(-6, -19), Vector2(12, 11)), Color("#222"))
	draw_rect(Rect2(head + Vector2(-6, -12), Vector2(12, 2)), Color("#c33"))
	# Coin on the counter.
	draw_circle(Vector2(14, -27), 3.0, Color("#ffd34d"))
	draw_prompt(72.0)
