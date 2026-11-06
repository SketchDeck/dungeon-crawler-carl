extends Node
## Autoload: run-wide state that outlives individual rooms (lives, current
## floor, completed floors). Saving to disk is added in Milestone 8.

signal lives_changed(lives: int)
signal floor_completed(floor_number: int)

const MAX_LIVES := 3

var lives := MAX_LIVES
var floor_number := 1
var completed_floors: Array[int] = []
## Highest floor the player may start from (Floor 1 beaten unlocks Floor 2).
var highest_unlocked_floor := 1


## Removes exactly one life. Returns the lives remaining.
func lose_life() -> int:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	return lives


func reset_lives() -> void:
	lives = MAX_LIVES
	lives_changed.emit(lives)


func complete_floor(number: int) -> void:
	if not completed_floors.has(number):
		completed_floors.append(number)
	highest_unlocked_floor = maxi(highest_unlocked_floor, number + 1)
	floor_completed.emit(number)


func is_floor_completed(number: int) -> bool:
	return completed_floors.has(number)
