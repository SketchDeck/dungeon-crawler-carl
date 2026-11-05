class_name RoomData
extends RefCounted
## Builds each room's layout from the floor map (FloorMaps) and its content (LayoutFloor1/2).
## Room ids look like "f1_E": floor 1, room E on the map. Everything structural is generated here:
## the outer shell, four-side exits, shafts with stairs, and the spawn points for each side.
##
## Coordinates: rooms are 1280 x 640 with the floor top at y = 600 and the ceiling at y = 0.

const ROOM_W := 1280.0
const ROOM_H := 640.0
const STAND_Y := 572.0
const DOOR_TOP := 440.0
const DOOR_HEIGHT := 160.0
const STAIR_TOPS := [485.0, 370.0, 255.0, 140.0]


static func parse_id(room_id: String) -> Dictionary:
	var parts := room_id.split("_")
	if parts.size() != 2 or not parts[0].begins_with("f"):
		return {}
	return {"floor": int(parts[0].substr(1)), "letter": parts[1]}


static func start_room(floor_number: int) -> String:
	return FloorMaps.room_id(floor_number, FloorMaps.entrance_letter(floor_number))


static func boss_room(floor_number: int) -> String:
	return FloorMaps.room_id(floor_number, FloorMaps.boss_letter(floor_number))


## Shortest route through the floor from its entrance to its boss, as room ids.
static func path(floor_number: int) -> Array:
	var rooms := FloorMaps.rooms(floor_number)
	var start := FloorMaps.entrance_letter(floor_number)
	var goal := FloorMaps.boss_letter(floor_number)
	var previous: Dictionary = {start: ""}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == goal:
			break
		for side in rooms[current]["exits"].keys():
			var next: String = rooms[current]["exits"][side]
			if not previous.has(next):
				previous[next] = current
				queue.append(next)
	var letters: Array = []
	var step := goal
	while step != "" and previous.has(step):
		letters.push_front(step)
		step = previous[step]
	var ids: Array = []
	for letter in letters:
		ids.append(FloorMaps.room_id(floor_number, letter))
	return ids


## Hand-placed contents for a room (platforms, enemies, hazards, signs), before generation.
static func content(room_id: String) -> Dictionary:
	var parsed := parse_id(room_id)
	if parsed.is_empty():
		return {}
	var table: Dictionary = LayoutFloor1.ROOMS if int(parsed.floor) == 1 else LayoutFloor2.ROOMS
	return table.get(str(parsed.letter), {})


## The full layout used by RoomBase. Returns {} for unknown ids.
static func layout(room_id: String) -> Dictionary:
	var parsed := parse_id(room_id)
	if parsed.is_empty():
		return {}
	var floor_number: int = parsed.floor
	var letter: String = parsed.letter
	var rooms := FloorMaps.rooms(floor_number)
	if not rooms.has(letter):
		return {}
	var node: Dictionary = rooms[letter]
	var kind: String = node["kind"]
	var letter_exits: Dictionary = node["exits"]
	var vertical: Dictionary = node["vertical"]
	var data := content(room_id)

	var exits: Dictionary = {}
	for side in letter_exits.keys():
		exits[side] = FloorMaps.room_id(floor_number, letter_exits[side])

	# Shaft stairs are one-way ledges: a player can jump up through them, so the stack is climbable.
	var platforms: Array = data.get("platforms", []).duplicate()
	var one_way: Array = data.get("one_way", []).duplicate()
	if exits.has("up"):
		one_way.append_array(_stairs(vertical["up"]))

	var spawn := {"left": Vector2(90.0, STAND_Y), "right": Vector2(1190.0, STAND_Y)}
	if exits.has("up"):
		spawn["up"] = Vector2(vertical["up"], 40.0)
	if exits.has("down"):
		spawn["down"] = Vector2(vertical["down"] - 110.0, STAND_Y)
	spawn["start"] = data.get("start", spawn["left"] if exits.has("left") else spawn["right"])

	var bonfire: Vector2 = data.get("bonfire", Vector2.ZERO)
	if kind == "safe" and bonfire == Vector2.ZERO:
		bonfire = Vector2(640.0, 584.0)
	var chest: Vector2 = data.get("chest", Vector2.ZERO)
	if kind == "challenge" and chest == Vector2.ZERO:
		chest = Vector2(640.0, 584.0)

	return {
		"id": room_id,
		"floor": floor_number,
		"letter": letter,
		"name": data.get("name", room_id),
		"kind": kind,
		"theme": FloorMaps.theme(floor_number),
		"size": Vector2(ROOM_W, ROOM_H),
		"exits": exits,
		"vertical": vertical,
		"shell": _shell(exits, vertical),
		"platforms": platforms,
		"one_way": one_way,
		"openings": _openings(exits, vertical),
		"spawn": spawn,
		"enemies": data.get("enemies", []),
		"spikes": data.get("spikes", []),
		"breakables": data.get("breakables", []),
		"explosives": data.get("explosives", []),
		"signs": data.get("signs", []),
		"chest": chest,
		"bonfire": bonfire,
	}


## Ceiling, floor and side walls. An exit on a side leaves an opening there: side exits open the
## wall, up exits open the ceiling, and down exits open the floor.
static func _shell(exits: Dictionary, vertical: Dictionary) -> Array:
	var shell: Array = []
	var w := ROOM_W
	if exits.has("up"):
		var ux: float = vertical["up"]
		shell.append(Rect2(-40.0, -40.0, ux - 80.0 + 40.0, 40.0))
		shell.append(Rect2(ux + 80.0, -40.0, w + 40.0 - (ux + 80.0), 40.0))
	else:
		shell.append(Rect2(-40.0, -40.0, w + 80.0, 40.0))
	if exits.has("down"):
		var dx: float = vertical["down"]
		shell.append(Rect2(-40.0, 600.0, dx - 80.0 + 40.0, 40.0))
		shell.append(Rect2(dx + 80.0, 600.0, w + 40.0 - (dx + 80.0), 40.0))
	else:
		shell.append(Rect2(-40.0, 600.0, w + 80.0, 40.0))
	shell.append(Rect2(-40.0, 0.0, 40.0, DOOR_TOP if exits.has("left") else 600.0))
	shell.append(Rect2(w, 0.0, 40.0, DOOR_TOP if exits.has("right") else 600.0))
	return shell


## One-way steps that climb from the floor to an up exit, one jump apart.
static func _stairs(x: float) -> Array:
	var steps: Array = []
	for top in STAIR_TOPS:
		steps.append(Rect2(x - 75.0, top, 150.0, 22.0))
	return steps


## Solid barrier (locks while the encounter is active) and trigger (requests the transition) for
## each exit. Side exits sit in the wall gap; up and down exits sit in the shaft.
static func _openings(exits: Dictionary, vertical: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var w := ROOM_W
	if exits.has("left"):
		result["left"] = {
			"barrier": Rect2(2.0, DOOR_TOP, 14.0, DOOR_HEIGHT),
			"trigger": Rect2(-9.0, DOOR_TOP, 26.0, 150.0),
			"glow": Rect2(-22.0, DOOR_TOP - 4.0, 26.0, DOOR_HEIGHT + 8.0),
		}
	if exits.has("right"):
		result["right"] = {
			"barrier": Rect2(w - 12.0, DOOR_TOP, 14.0, DOOR_HEIGHT),
			"trigger": Rect2(w - 17.0, DOOR_TOP, 26.0, 150.0),
			"glow": Rect2(w - 4.0, DOOR_TOP - 4.0, 26.0, DOOR_HEIGHT + 8.0),
		}
	if exits.has("up"):
		var ux: float = vertical["up"]
		result["up"] = {
			"barrier": Rect2(ux - 80.0, -40.0, 160.0, 40.0),
			"trigger": Rect2(ux - 80.0, -60.0, 160.0, 60.0),
			"glow": Rect2(ux - 70.0, 2.0, 140.0, 26.0),
		}
	if exits.has("down"):
		var dx: float = vertical["down"]
		result["down"] = {
			"barrier": Rect2(dx - 80.0, 600.0, 160.0, 40.0),
			"trigger": Rect2(dx - 80.0, 600.0, 160.0, 60.0),
			"glow": Rect2(dx - 70.0, 606.0, 140.0, 26.0),
		}
	return result
