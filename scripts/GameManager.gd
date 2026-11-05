extends Node
## Autoload: run-wide state that outlives individual rooms (lives, current floor).
## Save data and floor unlocks are added in Milestone 8.

signal lives_changed(lives: int)

const MAX_LIVES := 3

var lives := MAX_LIVES
var floor_number := 1


## Removes exactly one life. Returns the lives remaining.
func lose_life() -> int:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	return lives


func reset_lives() -> void:
	lives = MAX_LIVES
	lives_changed.emit(lives)
