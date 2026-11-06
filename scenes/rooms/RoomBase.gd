class_name RoomBase
extends Node2D
## A room scene. Geometry and objects are built at runtime from `layout`, a
## text map of 32px tiles:
##
##   #  solid terrain          =  one-way platform (jump up through it)
##   G  gate (solid until the challenge trial is complete)
##   E  entrance / player spawn
##   1-9 exit door N (leads to exits[N-1])
##   g  Goblin   s  Slime      C  reward chest       F  healing fountain
##   S  trial switch           i  sign (texts from `signs`, in reading order)
##   B  boss spawn (boss rooms)    X  stairs to the next floor (open once the boss is beaten)
##   ^  spikes (put them in a 1-tile-deep pit)
##   x  explosive barrel       b  breakable crate (holds a potion)
##   W  cracked wall (solid; strong attacks break it to open a path)
##
## Entities sit on the bottom edge of their tile. The room manager sets
## `state` (persistent progress such as "cleared") before adding the room,
## then calls activate() once the player is placed.

signal exit_requested(index: int)
signal state_changed(state: Dictionary)
signal encounter_started
signal encounter_cleared
signal trial_completed
signal reward_claimed
signal boss_started(boss: BossBase)
signal boss_defeated
signal floor_exit_requested

enum RoomType { ENTRANCE, COMBAT, SAFE, CHALLENGE, BOSS }
enum Trial { NONE, REACH, SWITCHES, DEFEAT }

const TILE := 32
const GOBLIN_SCENE := preload("res://scenes/enemies/Goblin.tscn")
const SLIME_SCENE := preload("res://scenes/enemies/Slime.tscn")

@export var room_id := ""
@export var display_name := ""
@export var room_type := RoomType.COMBAT
## Challenge rooms only: what unlocks the chest.
@export var trial := Trial.NONE
@export var trial_hint := ""
## Destination room ids for exit doors 1, 2, ...
@export var exits: PackedStringArray
## Optional text for each exit door (defaults to "EXIT").
@export var exit_labels: PackedStringArray
@export var signs: PackedStringArray
@export var lock_exits_during_encounter := true
## Boss rooms: the fight starts when the player gets this close to the boss.
@export var boss_wake_distance := 420.0
## Boss rooms: which boss the B marker spawns.
@export var boss_scene: PackedScene = preload("res://scenes/bosses/GoblinBoss.tscn")
## Camera limits; computed from the layout when one is given.
@export var bounds := Rect2(0, 0, 1280, 640)
@export var backdrop_color := Color("#1a2230")
@export_multiline var layout := ""

## Persistent progress: cleared, trial_done, reward_claimed, fountain_used.
var state := {}
var player: Player
var doors: Array[Door] = []
var switches: Array[FloorSwitch] = []
var chest: Chest
var fountain: Fountain
## Enemies that must die to clear the encounter / complete a DEFEAT trial.
var required_enemies: Array[EnemyBase] = []
var encounter_active := false
var boss_spawn := Vector2.ZERO
var boss: BossBase
var floor_exit: FloorExit

var _spawn := Vector2.ZERO
var _gates: Array[SolidBlock] = []
var _terrain: Node2D
var _enemies: Node2D
var _objects: Node2D


func _ready() -> void:
	_terrain = _make_layer("Terrain")
	_objects = _make_layer("Objects")
	_enemies = _make_layer("Enemies")
	if layout.strip_edges() != "":
		_build_from_layout()


func _make_layer(layer_name: String) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	add_child(layer)
	return layer


func get_spawn_point() -> Vector2:
	return to_global(_spawn)


func is_cleared() -> bool:
	return state.get("cleared", false)


func is_trial_done() -> bool:
	return state.get("trial_done", false)


## Called by the room manager after the player has been placed.
func activate(p: Player) -> void:
	player = p
	if room_type == RoomType.COMBAT:
		if is_cleared():
			_set_doors_locked(false)
		else:
			_start_encounter()


func _physics_process(_delta: float) -> void:
	# Boss rooms wake the boss once the player walks in far enough.
	if room_type != RoomType.BOSS or encounter_active or is_cleared():
		return
	if not is_instance_valid(boss) or not boss.is_dormant():
		return
	if is_instance_valid(player) and not player.health.is_dead \
			and absf(player.global_position.x - boss.global_position.x) <= boss_wake_distance:
		start_boss_fight()


## Locks the room and starts the boss encounter (no auto-heal until it ends).
func start_boss_fight() -> void:
	if encounter_active or not is_instance_valid(boss):
		return
	encounter_active = true
	_set_doors_locked(true)
	if player:
		player.combat_state.begin_encounter(StringName(room_id), true)
	boss.start_fight()
	encounter_started.emit()
	boss_started.emit(boss)


func _on_boss_died(_enemy: EnemyBase) -> void:
	encounter_active = false
	_set_doors_locked(false)
	if is_instance_valid(player):
		player.combat_state.end_encounter(StringName(room_id))
	_set_state("cleared", true)
	if floor_exit:
		floor_exit.reveal()
	boss_defeated.emit()


# --- Encounters --------------------------------------------------------------

func _start_encounter() -> void:
	encounter_active = true
	if lock_exits_during_encounter:
		_set_doors_locked(true)
	if player:
		player.combat_state.begin_encounter(StringName(room_id))
	encounter_started.emit()
	if required_enemies.is_empty():
		_clear_encounter()


func _clear_encounter() -> void:
	encounter_active = false
	_set_doors_locked(false)
	if player:
		player.combat_state.end_encounter(StringName(room_id))
	_set_state("cleared", true)
	Fx.text(player.global_position + Vector2(0, -70) if player else get_spawn_point(), "ROOM CLEARED", Color("#7dff8a"), 20)
	encounter_cleared.emit()


func _on_required_enemy_died(enemy: EnemyBase) -> void:
	required_enemies.erase(enemy)
	if not required_enemies.is_empty():
		return
	if encounter_active:
		_clear_encounter()
	if room_type == RoomType.CHALLENGE and trial == Trial.DEFEAT:
		complete_trial()


func _exit_tree() -> void:
	if encounter_active and is_instance_valid(player):
		player.combat_state.end_encounter(StringName(room_id))


func _set_doors_locked(value: bool) -> void:
	for door in doors:
		door.set_locked(value)


# --- Challenge trials --------------------------------------------------------

func complete_trial() -> void:
	if is_trial_done():
		return
	_set_state("trial_done", true)
	_open_gates()
	if chest:
		chest.unlock()
	Fx.text(get_spawn_point() if player == null else player.global_position + Vector2(0, -70),
		"TRIAL COMPLETE", Color("#ffd34d"), 20)
	trial_completed.emit()


func _open_gates() -> void:
	for gate in _gates:
		if is_instance_valid(gate):
			Fx.burst(gate.global_position + gate.size * 0.5, Color("#ffd34d"), 30.0, 0.35)
			gate.queue_free()
	_gates.clear()


func _on_switch_activated(_switch: FloorSwitch) -> void:
	for s in switches:
		if not s.is_on:
			return
	complete_trial()


func _on_chest_opened() -> void:
	_set_state("reward_claimed", true)
	reward_claimed.emit()


func _on_fountain_used() -> void:
	_set_state("fountain_used", true)


func _set_state(key: String, value: Variant) -> void:
	state[key] = value
	state_changed.emit(state)


# --- Layout building ---------------------------------------------------------

func _build_from_layout() -> void:
	var rows: PackedStringArray = []
	for line in layout.strip_edges().split("\n"):
		rows.append(line.strip_edges())
	var width := rows[0].length()
	bounds = Rect2(0, 0, width * TILE, rows.size() * TILE)

	for rect in _merge_tiles(rows, "#"):
		_add_block(rect, false)
	for rect in _merge_tiles(rows, "="):
		_add_block(rect, true, Vector2(0, 0), 12.0)
	for rect in _merge_tiles(rows, "^"):
		var spikes := SpikeTrap.new()
		spikes.position = Vector2(rect.position * TILE)
		spikes.size = Vector2(rect.size * TILE)
		_objects.add_child(spikes)
	for rect in _merge_tiles(rows, "W"):
		var wall := Breakable.new()
		wall.kind = Breakable.Kind.WALL
		wall.position = Vector2(rect.position * TILE)
		wall.size = Vector2(rect.size * TILE)
		_terrain.add_child(wall)
	var gate_rects := _merge_tiles(rows, "G")
	if not is_trial_done():
		for rect in gate_rects:
			var gate := _add_block(rect, false)
			gate.color = Color("#a08030")
			_gates.append(gate)

	var sign_index := 0
	var spawn_enemies := _should_spawn_enemies()
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			var foot := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			match ch:
				"E":
					_spawn = foot - Vector2(0, 28)
				"g":
					if spawn_enemies:
						_spawn_enemy(GOBLIN_SCENE, foot - Vector2(0, 20))
				"s":
					if spawn_enemies:
						_spawn_enemy(SLIME_SCENE, foot - Vector2(0, 12))
				"C":
					chest = Chest.new()
					chest.position = foot
					chest.locked = trial != Trial.REACH and not is_trial_done()
					chest.is_open = state.get("reward_claimed", false)
					chest.opened.connect(_on_chest_opened)
					_objects.add_child(chest)
				"F":
					fountain = Fountain.new()
					fountain.position = foot
					fountain.dry = state.get("fountain_used", false)
					fountain.used.connect(_on_fountain_used)
					_objects.add_child(fountain)
				"S":
					var s := FloorSwitch.new()
					s.position = foot
					s.is_on = is_trial_done()
					s.activated.connect(_on_switch_activated)
					switches.append(s)
					_objects.add_child(s)
				"i":
					var room_sign := RoomSign.new()
					room_sign.position = foot
					room_sign.text = signs[sign_index] if sign_index < signs.size() else ""
					sign_index += 1
					_objects.add_child(room_sign)
				"B":
					boss_spawn = foot
					if room_type == RoomType.BOSS and not is_cleared():
						boss = boss_scene.instantiate() as BossBase
						boss.position = foot - Vector2(0, boss.body_size.y * 0.5)
						boss.died.connect(_on_boss_died)
						_enemies.add_child(boss)
				"x":
					var barrel := ExplosiveBarrel.new()
					barrel.position = foot
					_objects.add_child(barrel)
				"b":
					var crate := Breakable.new()
					crate.kind = Breakable.Kind.CRATE
					crate.position = foot - crate.size * Vector2(0.5, 1.0)
					_objects.add_child(crate)
				"X":
					floor_exit = FloorExit.new()
					floor_exit.position = foot
					floor_exit.open = is_cleared()
					floor_exit.entered.connect(floor_exit_requested.emit)
					_objects.add_child(floor_exit)
				_:
					if ch >= "1" and ch <= "9":
						var door := Door.new()
						door.position = foot
						door.exit_index = ch.to_int() - 1
						door.target_label = exits[door.exit_index] if door.exit_index < exits.size() else ""
						if door.exit_index < exit_labels.size():
							door.label = exit_labels[door.exit_index]
						door.entered.connect(_on_door_entered)
						doors.append(door)
						_objects.add_child(door)
	queue_redraw()


func _should_spawn_enemies() -> bool:
	match room_type:
		RoomType.COMBAT:
			return not is_cleared()
		RoomType.CHALLENGE:
			return not (trial == Trial.DEFEAT and is_trial_done())
	return true


func _spawn_enemy(scene: PackedScene, pos: Vector2) -> void:
	var enemy := scene.instantiate() as EnemyBase
	enemy.position = pos
	_enemies.add_child(enemy)
	if room_type == RoomType.COMBAT or (room_type == RoomType.CHALLENGE and trial == Trial.DEFEAT):
		required_enemies.append(enemy)
		enemy.died.connect(_on_required_enemy_died)


func _on_door_entered(door: Door) -> void:
	exit_requested.emit(door.exit_index)


func _add_block(rect: Rect2i, one_way: bool, offset := Vector2.ZERO, height := -1.0) -> SolidBlock:
	var block := SolidBlock.new()
	block.position = Vector2(rect.position * TILE) + offset
	var size := Vector2(rect.size * TILE)
	if height > 0.0:
		size.y = height
	block.size = size
	block.one_way = one_way
	_terrain.add_child(block)
	return block


## Merges runs of `ch` into rectangles: horizontal runs per row, then identical
## runs on consecutive rows are joined vertically.
static func _merge_tiles(rows: PackedStringArray, ch: String) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var active := {}
	for y in rows.size():
		var row := rows[y]
		var next := {}
		var x := 0
		while x < row.length():
			if row[x] != ch:
				x += 1
				continue
			var start := x
			while x < row.length() and row[x] == ch:
				x += 1
			var key := "%d:%d" % [start, x]
			var rect: Rect2i = active[key] if active.has(key) else Rect2i(start, y, x - start, 0)
			rect.size.y += 1
			next[key] = rect
		for key: String in active:
			if not next.has(key):
				result.append(active[key])
		active = next
	for key: String in active:
		result.append(active[key])
	return result


func _draw() -> void:
	draw_rect(bounds, backdrop_color)
	var grid := Color(1, 1, 1, 0.025)
	var y := bounds.position.y
	var row := 0
	while y < bounds.end.y:
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), grid)
		var x := bounds.position.x + (32.0 if row % 2 == 1 else 0.0)
		while x < bounds.end.x:
			draw_line(Vector2(x, y), Vector2(x, y + 32.0), grid)
			x += 64.0
		y += 32.0
		row += 1
	# Sealed archway behind the entrance.
	if _spawn != Vector2.ZERO:
		var foot := _spawn + Vector2(0, 28)
		var arch := Rect2(foot.x - 22, foot.y - 80, 44, 80)
		draw_rect(arch.grow(4), Color("#3a3028"))
		draw_rect(arch, Color("#121419"))
		draw_line(arch.position + Vector2(6, 10), arch.end - Vector2(6, 10), Color("#3a3028"), 3.0)
		draw_line(Vector2(arch.end.x - 6, arch.position.y + 10), Vector2(arch.position.x + 6, arch.end.y - 10), Color("#3a3028"), 3.0)
