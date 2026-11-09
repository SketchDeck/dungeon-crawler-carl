class_name FloorData
extends RefCounted
## Floor definitions: which room scenes make up each floor and where it starts.
## Room connections live in each room scene's `exits` (see docs/floor-layouts.md).
## A room can list several scenes ("variants"): same id, type and exits, a
## different layout. Each floor run picks one variant per room at random.
## `enemies` is the pool that `?` spawn markers in layouts pick from.

## Floor 0 is the practice room (main menu "Practice"), not part of a run.
const PRACTICE_FLOOR := 0

const FLOORS := {
	0: {
		"name": "Training Room",
		"boss": "nobody",
		"start": "T-01",
		"rooms": {"T-01": "res://scenes/rooms/practice/T_01_Training.tscn"},
	},
	1: {
		"name": "Floor 1",
		"boss": "Goblin Brute",
		"start": "F1-01",
		"enemies": ["g", "g", "h", "v"],
		"rooms": {
			"F1-01": "res://scenes/rooms/floor1/F1_01_Entrance.tscn",
			"F1-02": "res://scenes/rooms/floor1/F1_02_Combat.tscn",
			"F1-03": "res://scenes/rooms/floor1/F1_03_Safe.tscn",
			"F1-04": "res://scenes/rooms/floor1/F1_04_Challenge.tscn",
			"F1-05": "res://scenes/rooms/floor1/F1_05_Combat.tscn",
			"F1-U1": "res://scenes/rooms/floor1/F1_U1_Challenge.tscn",
			"F1-U2": ["res://scenes/rooms/floor1/F1_U2_Combat.tscn", "res://scenes/rooms/floor1/F1_U2_Combat_B.tscn"],
			"F1-U3": "res://scenes/rooms/floor1/F1_U3_Challenge.tscn",
			"F1-D1": "res://scenes/rooms/floor1/F1_D1_Safe.tscn",
			"F1-D2": ["res://scenes/rooms/floor1/F1_D2_Combat.tscn", "res://scenes/rooms/floor1/F1_D2_Combat_B.tscn"],
			"F1-D3": "res://scenes/rooms/floor1/F1_D3_Challenge.tscn",
			"F1-06": "res://scenes/rooms/floor1/F1_06_Safe.tscn",
			"F1-07": ["res://scenes/rooms/floor1/F1_07_Combat.tscn", "res://scenes/rooms/floor1/F1_07_Combat_B.tscn"],
			"F1-08": "res://scenes/rooms/floor1/F1_08_Boss.tscn",
		},
	},
	2: {
		"name": "Floor 2",
		"boss": "Mutating Slime",
		"start": "F2-01",
		"enemies": ["s", "s", "a", "v", "g"],
		"rooms": {
			"F2-01": "res://scenes/rooms/floor2/F2_01_Entrance.tscn",
			"F2-02": "res://scenes/rooms/floor2/F2_02_Challenge.tscn",
			"F2-U1": ["res://scenes/rooms/floor2/F2_U1_Combat.tscn", "res://scenes/rooms/floor2/F2_U1_Combat_B.tscn"],
			"F2-M1": "res://scenes/rooms/floor2/F2_M1_Safe.tscn",
			"F2-D1": ["res://scenes/rooms/floor2/F2_D1_Combat.tscn", "res://scenes/rooms/floor2/F2_D1_Combat_B.tscn"],
			"F2-U2": "res://scenes/rooms/floor2/F2_U2_Safe.tscn",
			"F2-M2": ["res://scenes/rooms/floor2/F2_M2_Combat.tscn", "res://scenes/rooms/floor2/F2_M2_Combat_B.tscn"],
			"F2-D2": "res://scenes/rooms/floor2/F2_D2_Challenge.tscn",
			"F2-U3": ["res://scenes/rooms/floor2/F2_U3_Combat.tscn", "res://scenes/rooms/floor2/F2_U3_Combat_B.tscn"],
			"F2-U4": "res://scenes/rooms/floor2/F2_U4_Challenge.tscn",
			"F2-D3": ["res://scenes/rooms/floor2/F2_D3_Combat.tscn", "res://scenes/rooms/floor2/F2_D3_Combat_B.tscn"],
			"F2-D4": "res://scenes/rooms/floor2/F2_D4_Challenge.tscn",
			"F2-06": "res://scenes/rooms/floor2/F2_06_Safe.tscn",
			"F2-07": ["res://scenes/rooms/floor2/F2_07_Combat.tscn", "res://scenes/rooms/floor2/F2_07_Combat_B.tscn"],
			"F2-08": "res://scenes/rooms/floor2/F2_08_Boss.tscn",
		},
	},
	3: {
		"name": "Floor 3",
		"boss": "Sewer King",
		"start": "F3-01",
		"enemies": ["r", "r", "v", "h", "a"],
		"rooms": {
			"F3-01": "res://scenes/rooms/floor3/F3_01_Entrance.tscn",
			"F3-02": "res://scenes/rooms/floor3/F3_02_Combat.tscn",
			"F3-03": "res://scenes/rooms/floor3/F3_03_Safe.tscn",
			"F3-04": "res://scenes/rooms/floor3/F3_04_Challenge.tscn",
			"F3-05": "res://scenes/rooms/floor3/F3_05_Combat.tscn",
			"F3-U1": "res://scenes/rooms/floor3/F3_U1_Combat.tscn",
			"F3-U2": "res://scenes/rooms/floor3/F3_U2_Challenge.tscn",
			"F3-D1": "res://scenes/rooms/floor3/F3_D1_Combat.tscn",
			"F3-S1": "res://scenes/rooms/floor3/F3_S1_Secret.tscn",
			"F3-D2": "res://scenes/rooms/floor3/F3_D2_Challenge.tscn",
			"F3-06": "res://scenes/rooms/floor3/F3_06_Safe.tscn",
			"F3-07": "res://scenes/rooms/floor3/F3_07_Combat.tscn",
			"F3-08": "res://scenes/rooms/floor3/F3_08_Boss.tscn",
		},
	},
}


static func has_floor(floor_number: int) -> bool:
	return FLOORS.has(floor_number)


static func floor_name(floor_number: int) -> String:
	return FLOORS[floor_number]["name"]


static func boss_name(floor_number: int) -> String:
	return FLOORS[floor_number].get("boss", "boss")


static func start_room(floor_number: int) -> String:
	return FLOORS[floor_number]["start"]


static func room_ids(floor_number: int) -> Array:
	return FLOORS[floor_number]["rooms"].keys()


static func has_room(floor_number: int, room_id: String) -> bool:
	return FLOORS.has(floor_number) and FLOORS[floor_number]["rooms"].has(room_id)


## The room's first (default) scene.
static func room_scene_path(floor_number: int, room_id: String) -> String:
	return room_scene_paths(floor_number, room_id)[0]


## Every variant scene of a room.
static func room_scene_paths(floor_number: int, room_id: String) -> Array:
	var entry: Variant = FLOORS[floor_number]["rooms"][room_id]
	return entry if entry is Array else [entry]


## Room letters that `?` spawn markers choose from on this floor.
static func enemy_pool(floor_number: int) -> Array:
	return FLOORS[floor_number].get("enemies", ["g"]) if FLOORS.has(floor_number) else ["g"]
