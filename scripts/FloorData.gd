class_name FloorData
extends RefCounted
## Floor definitions: which room scenes make up each floor and where it starts.
## Room connections live in each room scene's `exits` (see docs/floor-layouts.md).

const FLOORS := {
	1: {
		"name": "Floor 1",
		"start": "F1-01",
		"rooms": {
			"F1-01": "res://scenes/rooms/floor1/F1_01_Entrance.tscn",
			"F1-02": "res://scenes/rooms/floor1/F1_02_Combat.tscn",
			"F1-03": "res://scenes/rooms/floor1/F1_03_Safe.tscn",
			"F1-04": "res://scenes/rooms/floor1/F1_04_Challenge.tscn",
			"F1-05": "res://scenes/rooms/floor1/F1_05_Combat.tscn",
			"F1-U1": "res://scenes/rooms/floor1/F1_U1_Challenge.tscn",
			"F1-U2": "res://scenes/rooms/floor1/F1_U2_Combat.tscn",
			"F1-U3": "res://scenes/rooms/floor1/F1_U3_Challenge.tscn",
			"F1-D1": "res://scenes/rooms/floor1/F1_D1_Safe.tscn",
			"F1-D2": "res://scenes/rooms/floor1/F1_D2_Combat.tscn",
			"F1-D3": "res://scenes/rooms/floor1/F1_D3_Challenge.tscn",
			"F1-06": "res://scenes/rooms/floor1/F1_06_Safe.tscn",
			"F1-07": "res://scenes/rooms/floor1/F1_07_Combat.tscn",
			"F1-08": "res://scenes/rooms/floor1/F1_08_Boss.tscn",
		},
	},
}


static func has_floor(floor_number: int) -> bool:
	return FLOORS.has(floor_number)


static func floor_name(floor_number: int) -> String:
	return FLOORS[floor_number]["name"]


static func start_room(floor_number: int) -> String:
	return FLOORS[floor_number]["start"]


static func room_ids(floor_number: int) -> Array:
	return FLOORS[floor_number]["rooms"].keys()


static func has_room(floor_number: int, room_id: String) -> bool:
	return FLOORS.has(floor_number) and FLOORS[floor_number]["rooms"].has(room_id)


static func room_scene_path(floor_number: int, room_id: String) -> String:
	return FLOORS[floor_number]["rooms"][room_id]
