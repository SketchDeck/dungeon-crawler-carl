class_name FloorMaps
extends RefCounted
## The designer's floor maps: every room with its kind, and every link between rooms.
##
## Room kinds, from the colours on the maps: entrance (blue), combat (yellow), safe (green),
## challenge (purple), boss (red). A challenge room is the treasure room: clear its enemies and the
## upgrade chest opens. Room letters (A, B, C...) only label rooms for reference.
##
## A link joins two rooms. A horizontal link ["A", "right", "B"] means from A you go right into B.
## A vertical link also gives the shaft's x position so the rooms line up:
## ["E", "up", "F", 400.0] means E's ceiling opening leads up to F's floor hole at x = 400.
## Doors work both ways; the arrows on the maps set the layout, not one-way travel.

const OPPOSITE := {"left": "right", "right": "left", "up": "down", "down": "up"}

const FLOOR_1 := {
	"name": "The Warrens",
	"theme": "warrens",
	"tutorial": ["A", "B", "C", "D"],
	"rooms": {
		"A": "entrance", "B": "combat", "C": "safe", "D": "challenge", "E": "combat",
		"F": "challenge", "G": "combat", "H": "challenge", "I": "safe", "J": "safe",
		"K": "combat", "L": "challenge", "M": "combat", "N": "boss",
	},
	"links": [
		["A", "right", "B"], ["B", "right", "C"], ["C", "right", "D"], ["D", "right", "E"],
		["E", "up", "F", 400.0], ["E", "down", "J", 880.0],
		["F", "right", "G"], ["G", "right", "H"], ["H", "down", "I", 400.0],
		["J", "right", "K"], ["K", "right", "L"], ["L", "up", "I", 880.0],
		["I", "right", "M"], ["M", "right", "N"],
	],
}

const FLOOR_2 := {
	"name": "The Mutant Pool",
	"theme": "fungal",
	"tutorial": [],
	"rooms": {
		"P": "entrance", "Q": "challenge", "R": "combat", "S": "combat", "T": "safe",
		"U": "safe", "V": "combat", "W": "challenge", "X": "combat", "Y": "challenge",
		"Z": "combat", "AA": "challenge", "AB": "safe", "AC": "combat", "AD": "boss",
	},
	"links": [
		["P", "right", "Q"], ["Q", "up", "R", 400.0], ["Q", "down", "S", 880.0], ["Q", "right", "T"],
		["T", "right", "V"], ["R", "right", "U"], ["V", "up", "U", 400.0], ["V", "down", "W", 880.0],
		["S", "right", "W"], ["U", "right", "X"], ["X", "right", "Y"], ["Y", "down", "AB", 400.0],
		["W", "right", "Z"], ["Z", "right", "AA"], ["AA", "up", "AB", 880.0], ["AB", "right", "AC"],
		["AC", "right", "AD"],
	],
}


static func map_for(floor_number: int) -> Dictionary:
	return FLOOR_2 if floor_number == 2 else FLOOR_1


static func room_id(floor_number: int, letter: String) -> String:
	return "f%d_%s" % [floor_number, letter]


static func theme(floor_number: int) -> String:
	return str(map_for(floor_number)["theme"])


static func floor_name(floor_number: int) -> String:
	return str(map_for(floor_number)["name"])


static func tutorial_letters(floor_number: int) -> Array:
	return map_for(floor_number)["tutorial"]


static func entrance_letter(floor_number: int) -> String:
	return _letter_of_kind(floor_number, "entrance")


static func boss_letter(floor_number: int) -> String:
	return _letter_of_kind(floor_number, "boss")


static func _letter_of_kind(floor_number: int, kind: String) -> String:
	var rooms: Dictionary = map_for(floor_number)["rooms"]
	for letter in rooms.keys():
		if rooms[letter] == kind:
			return str(letter)
	return ""


## Every room on the floor, keyed by letter:
## {letter: {"kind": String, "exits": {side: neighbour letter}, "vertical": {side: shaft x}}}
static func rooms(floor_number: int) -> Dictionary:
	var map := map_for(floor_number)
	var result: Dictionary = {}
	for letter in map["rooms"].keys():
		result[letter] = {"kind": map["rooms"][letter], "exits": {}, "vertical": {}}
	for link in map["links"]:
		var a: String = link[0]
		var side: String = link[1]
		var b: String = link[2]
		result[a]["exits"][side] = b
		result[b]["exits"][OPPOSITE[side]] = a
		if side == "up" or side == "down":
			var x := float(link[3])
			result[a]["vertical"][side] = x
			result[b]["vertical"][OPPOSITE[side]] = x
	return result
