extends RoomBase
## Development sandbox: platforms, Goblins and a couple of potions.
## Debug: press R to respawn all Goblins.

const GOBLIN_SCENE := preload("res://scenes/enemies/Goblin.tscn")

## Test-room-only override so drops are easy to observe (the game default is 20%).
@export_range(0.0, 1.0) var test_drop_chance := 0.5

var _spawns: Array[Vector2] = []

@onready var _enemies: Node2D = $Enemies


func _ready() -> void:
	for enemy in _enemies.get_children():
		if enemy is EnemyBase:
			_spawns.append((enemy as Node2D).position)
			(enemy as EnemyBase).potion_drop_chance = test_drop_chance


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		respawn_enemies()


func respawn_enemies() -> void:
	for enemy in _enemies.get_children():
		enemy.queue_free()
	for pos in _spawns:
		var goblin := GOBLIN_SCENE.instantiate() as EnemyBase
		goblin.position = pos
		goblin.potion_drop_chance = test_drop_chance
		_enemies.add_child(goblin)
