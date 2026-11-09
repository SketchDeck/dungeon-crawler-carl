class_name Minimap
extends Control
## Floor map in the HUD corner: every room as a dot, laid out by how far it
## is from the entrance (left to right) and its path (upper/middle/lower).
## Rooms you've been in are filled; the current one pulses; rooms you
## haven't found yet are faint outlines. Secret rooms stay hidden until found.

const COLORS := {
	RoomBase.RoomType.ENTRANCE: Color("#8ec5ff"),
	RoomBase.RoomType.COMBAT: Color("#ffcf6b"),
	RoomBase.RoomType.SAFE: Color("#8fe39a"),
	RoomBase.RoomType.CHALLENGE: Color("#c3a6ff"),
	RoomBase.RoomType.BOSS: Color("#ff7a7a"),
}

var manager: RoomManager
## room id -> {"pos": Vector2 (grid), "type": RoomType, "exits": Array, "secret": bool}
var rooms := {}
var floor_number := -1
var _t := 0.0


func bind(p_manager: RoomManager) -> void:
	manager = p_manager
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	manager.room_entered.connect(func(_room: RoomBase) -> void:
		if manager.floor_number != floor_number:
			build(manager.floor_number)
		queue_redraw())


## Lays out the floor's rooms from their scenes' exits.
func build(number: int) -> void:
	floor_number = number
	rooms.clear()
	if not FloorData.has_floor(number):
		return
	for id: String in FloorData.room_ids(number):
		var room := (load(FloorData.room_scene_path(number, id)) as PackedScene).instantiate() as RoomBase
		rooms[id] = {"type": room.room_type, "exits": Array(room.exits), "secret": room.secret, "pos": Vector2.ZERO}
		room.free()
	# Depth from the entrance (longest path, so merges line up on the right).
	var depth := {FloorData.start_room(number): 0}
	var changed := true
	var guard := 0
	while changed and guard < 50:
		changed = false
		guard += 1
		for id: String in rooms:
			if not depth.has(id):
				continue
			for target: String in rooms[id]["exits"]:
				if rooms.has(target) and int(depth.get(target, -1)) < int(depth[id]) + 1:
					depth[target] = int(depth[id]) + 1
					changed = true
	for id: String in rooms:
		rooms[id]["pos"] = Vector2(int(depth.get(id, 0)), lane(id))


## Path from the room id: U = upper, M or numbered = middle, D = lower, S = secret.
static func lane(id: String) -> float:
	var tag := id.substr(3, 1)
	match tag:
		"U":
			return -1.0
		"D":
			return 1.0
		"S":
			return 1.8
	return 0.0


func visited(id: String) -> bool:
	return manager != null and (manager.room_states.has(id) or manager.current_room_id == id)


func _process(delta: float) -> void:
	_t += delta
	if visible and manager:
		queue_redraw()


func _point(grid: Vector2, max_depth: float) -> Vector2:
	var x := 10.0 + grid.x / maxf(max_depth, 1.0) * (size.x - 20.0)
	var y := size.y * 0.5 + grid.y * size.y * 0.24
	return Vector2(x, y)


func _draw() -> void:
	if rooms.is_empty() or manager == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var max_depth := 1.0
	for id: String in rooms:
		max_depth = maxf(max_depth, rooms[id]["pos"].x)
	for id: String in rooms:
		if rooms[id]["secret"] and not visited(id):
			continue
		for target: String in rooms[id]["exits"]:
			if not rooms.has(target) or (rooms[target]["secret"] and not visited(target)):
				continue
			var seen := visited(id) and visited(target)
			draw_line(_point(rooms[id]["pos"], max_depth), _point(rooms[target]["pos"], max_depth),
				Color(1, 1, 1, 0.5 if seen else 0.15), 1.5)
	for id: String in rooms:
		if rooms[id]["secret"] and not visited(id):
			continue
		var at := _point(rooms[id]["pos"], max_depth)
		var c: Color = COLORS.get(rooms[id]["type"], Color.WHITE)
		if id == manager.current_room_id:
			draw_circle(at, 7.0 + 1.5 * sin(_t * 6.0), Color(c, 0.35))
			draw_circle(at, 5.0, c)
			draw_arc(at, 6.0, 0, TAU, 16, Color.WHITE, 1.5)
		elif visited(id):
			draw_circle(at, 4.0, c)
		else:
			draw_arc(at, 3.5, 0, TAU, 12, Color(c, 0.4), 1.0)
