extends Control
## Small HUD flask icon.


func _draw() -> void:
	PotionPickup.draw_flask(self, size * 0.5 + Vector2(0, 2), 1.0)
