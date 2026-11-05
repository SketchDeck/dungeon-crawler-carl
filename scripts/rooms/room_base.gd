class_name RoomBase
extends Node2D
## One room of a floor, built from RoomData. Owns the geometry, the exits (doors on the sides and
## shafts up and down), hazards, enemies, signs and the encounter state. Enemies stay dormant until
## the player enters an encounter room (combat, challenge or boss). While the encounter is active,
## every exit is locked. Clearing the required enemies unlocks them.

signal encounter_started(room: RoomBase)
signal encounter_cleared(room: RoomBase, flawless: bool)
signal door_requested(room: RoomBase, side: String)
signal interact_requested(room: RoomBase, what: String)

const GOBLIN_SCENE := preload("res://scenes/enemies/Goblin.tscn")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")
const BRUTE_SCENE := preload("res://scenes/bosses/GoblinBrute.tscn")
const MUTANT_SCENE := preload("res://scenes/bosses/MutatingSlime.tscn")
const ENCOUNTER_KINDS := ["combat", "challenge", "boss"]

var room_id: String = ""
var layout: Dictionary = {}
var kind: String = "combat"
var theme: String = "warrens"
var size: Vector2 = Vector2(RoomData.ROOM_W, RoomData.ROOM_H)
var cleared: bool = false
var active: bool = false
var enemies: Array = []
var boss: Node = null
var interactables: Array = []

var _flawless: bool = true
var _barriers: Dictionary = {}
var _door_flash: Dictionary = {}
var _clock: float = 0.0
var _player: Player = null


func setup(id: String, is_cleared: bool) -> void:
	room_id = id
	layout = RoomData.layout(id)
	kind = str(layout.get("kind", "combat"))
	theme = str(layout.get("theme", "warrens"))
	size = layout.get("size", size)
	cleared = is_cleared


func display_name() -> String:
	return str(layout.get("name", room_id))


func spawn_point(side: String) -> Vector2:
	var spawn: Dictionary = layout.get("spawn", {})
	if spawn.has(side):
		return spawn[side]
	return spawn.get("start", Vector2(120.0, RoomData.STAND_Y))


func has_door(side: String) -> bool:
	return layout.get("exits", {}).has(side)


func is_locked() -> bool:
	return active and not cleared


func _ready() -> void:
	z_index = -5
	var backdrop := RoomBackdrop.new()
	add_child(backdrop)
	backdrop.setup(layout)
	_build_geometry()
	_build_openings()
	_build_trigger()
	_spawn_hazards()
	if not cleared:
		_spawn_enemies()
	_set_barriers(is_locked())
	call_deferred("_check_initial_overlap")


func _process(delta: float) -> void:
	_clock += delta
	for side in _door_flash.keys():
		_door_flash[side] = maxf(0.0, float(_door_flash[side]) - delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and Controls.is_interact_pressed():
		_try_interact()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player) and kind in ENCOUNTER_KINDS:
		if not active and not cleared and _player.alive:
			if Rect2(Vector2.ZERO, size).has_point(_player.global_position):
				activate()


## Begins the encounter: wakes enemies, locks every exit, and tells combat state.
func activate() -> void:
	if active or cleared or kind not in ENCOUNTER_KINDS:
		return
	active = true
	_flawless = true
	DungeonAI.begin_encounter()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
	_set_barriers(true)
	CombatState.set_room_encounter(true)
	if kind == "boss":
		CombatState.set_boss_active(true)
	encounter_started.emit(self)


func _check_initial_overlap() -> void:
	if kind in ENCOUNTER_KINDS and not cleared:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player != null and Rect2(Vector2.ZERO, size).has_point(_player.global_position):
			activate()


func _on_enemy_died(_enemy: Node) -> void:
	if not active or cleared:
		return
	if _remaining_enemies() == 0:
		_clear()


func _remaining_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count


func _clear() -> void:
	if cleared:
		return
	cleared = true
	active = false
	_set_barriers(false)
	CombatState.set_room_encounter(false)
	if kind == "boss":
		CombatState.set_boss_active(false)
	for node in interactables:
		if is_instance_valid(node) and node.has_method("on_room_cleared"):
			node.on_room_cleared()
	encounter_cleared.emit(self, _flawless)


func note_player_damaged() -> void:
	if active:
		_flawless = false


## The upgrade chest was used: it opens for good.
func complete_treasure() -> void:
	for node in interactables:
		if is_instance_valid(node) and node is TreasureChest:
			node.open()


func register_interactable(node: Node) -> void:
	interactables.append(node)


func _try_interact() -> void:
	for node in interactables:
		if not is_instance_valid(node):
			continue
		if node.has_method("can_interact") and node.can_interact(_player.global_position):
			if node.has_method("interact"):
				node.interact(self)
			return


func _spawn_enemies() -> void:
	for spec in layout.get("enemies", []):
		var enemy: Node = null
		match str(spec.get("type", "goblin")):
			"goblin":
				enemy = GOBLIN_SCENE.instantiate()
			"slime":
				enemy = SLIME_SCENE.instantiate()
			"goblin_brute":
				enemy = BRUTE_SCENE.instantiate()
			"mutating_slime":
				enemy = MUTANT_SCENE.instantiate()
		if enemy == null:
			continue
		enemy.position = spec.get("pos", Vector2(400.0, RoomData.STAND_Y))
		var patrol: Array = spec.get("patrol", [])
		if patrol.size() == 2 and enemy.has_method("set_patrol"):
			enemy.set_patrol(float(patrol[0]), float(patrol[1]))
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(enemy)
		_track_enemy(enemy)
		if enemy.has_method("is_boss") and enemy.is_boss():
			boss = enemy
			if enemy.has_signal("summoned"):
				enemy.summoned.connect(_on_boss_summoned)


func _track_enemy(enemy: Node) -> void:
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)


func _on_boss_summoned(enemy: Node) -> void:
	_track_enemy(enemy)


func _spawn_hazards() -> void:
	for rect in layout.get("spikes", []):
		Spikes.spawn(self, rect)
	for pos in layout.get("breakables", []):
		Breakable.spawn(self, pos)
	for pos in layout.get("explosives", []):
		ExplosiveBarrel.spawn(self, pos)
	for sign_spec in layout.get("signs", []):
		TutorialSign.spawn(self, sign_spec["pos"], str(sign_spec["text"]))
	if kind == "challenge":
		var taken := Game.is_reward_taken(room_id)
		TreasureChest.spawn(self, layout["chest"], cleared and not taken, taken)
	var bonfire: Vector2 = layout.get("bonfire", Vector2.ZERO)
	if bonfire != Vector2.ZERO:
		Bonfire.spawn(self, bonfire)


func _build_geometry() -> void:
	for rect in layout.get("shell", []):
		_add_block(rect, false)
	for rect in layout.get("platforms", []):
		_add_block(rect, false)
	for rect in layout.get("one_way", []):
		_add_block(rect, true)


func _add_block(rect: Rect2, one_way: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Config.LAYER_WORLD
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.size * 0.5
	collider.one_way_collision = one_way
	body.position = rect.position
	body.add_child(collider)
	add_child(body)
	return body


func _build_openings() -> void:
	var openings: Dictionary = layout.get("openings", {})
	for side in openings.keys():
		var data: Dictionary = openings[side]
		_barriers[side] = _add_block(data["barrier"], false)
		_door_flash[side] = 0.0
		_add_trigger(data["trigger"], str(side))


func _add_trigger(rect: Rect2, side: String) -> void:
	var trigger := Area2D.new()
	trigger.collision_layer = Config.LAYER_DOOR
	trigger.collision_mask = Config.LAYER_PLAYER
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.size * 0.5
	trigger.position = rect.position
	trigger.add_child(collider)
	trigger.body_entered.connect(_on_door_body_entered.bind(side))
	add_child(trigger)


func _build_trigger() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = Config.LAYER_PLAYER
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = size * 0.5
	area.add_child(collider)
	add_child(area)


func _on_door_body_entered(body: Node, side: String) -> void:
	if not (body is Player) or not body.alive:
		return
	if is_locked():
		_door_flash[side] = 0.4
		return
	door_requested.emit(self, side)


func _set_barriers(locked: bool) -> void:
	for side in _barriers.keys():
		var barrier: StaticBody2D = _barriers[side]
		if is_instance_valid(barrier):
			barrier.collision_layer = Config.LAYER_WORLD if locked else 0


func _draw() -> void:
	Decor.draw_torches(self, Decor.palette(theme), size, _clock)
	var openings: Dictionary = layout.get("openings", {})
	for side in openings.keys():
		_draw_opening(str(side), openings[side])


func _draw_opening(side: String, data: Dictionary) -> void:
	var locked := is_locked()
	var flash := float(_door_flash.get(side, 0.0))
	var col := Color("#ff5f6d") if locked else Color("#6dff9a")
	var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
	var glow: Rect2 = data["glow"]
	draw_rect(glow, Color(col.r, col.g, col.b, 0.14 + 0.1 * pulse + flash * 0.4))
	if side == "left" or side == "right":
		var x := 0.0 if side == "left" else size.x
		draw_rect(Rect2(x - 3.0 if side == "left" else x - 1.0, RoomData.DOOR_TOP, 4.0, RoomData.DOOR_HEIGHT),
			Color(col.r, col.g, col.b, 0.8))
		if locked:
			for i in range(4):
				var y := RoomData.DOOR_TOP + 12.0 + i * 38.0
				var reach := 14.0 if side == "left" else -14.0
				draw_line(Vector2(x, y), Vector2(x + reach, y + 8.0), Color(col.r, col.g, col.b, 0.5), 2.0, true)
	else:
		# Shafts get an arrow pointing into them.
		var cx: float = glow.get_center().x
		var mark_y := 22.0 if side == "up" else 620.0
		var dir := 1.0 if side == "up" else -1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, mark_y - dir * 10.0),
			Vector2(cx - 10.0, mark_y + dir * 8.0),
			Vector2(cx + 10.0, mark_y + dir * 8.0),
		]), Color(col.r, col.g, col.b, 0.85))
