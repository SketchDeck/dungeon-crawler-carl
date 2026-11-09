class_name RunStats
extends Node
## Per-floor run record: time, kills, damage taken, deaths, potions drunk, the
## viewer count (the run's score) and loot boxes waiting to be opened. Main
## owns one; it resets when a floor starts. Loot boxes carry over to the next
## floor; everything else starts again.
##
## Viewers come from kills (more for stylish ones), cleared rooms, beaten
## bosses and achievements. Floor modifiers multiply every gain.

const GROUP := "run_stats"

signal viewers_changed(viewers: int, gained: int)
signal boxes_changed(count: int)
## The player asked to open their loot boxes (at a safe-room fountain).
signal loot_requested

const KILL_VIEWERS := 10
## Extra viewers for juggles, hazards, collisions, explosions, fire.
const STYLE_VIEWERS := 15
const STYLE_TAGS := ["juggle", "hazard", "collision", "explosion", "fire", "wave"]
const ROOM_CLEAR_VIEWERS := 25
const BOSS_VIEWERS := 300
## A grade's viewers target ("par") per floor.
const PAR := {1: 1000, 2: 1200, 3: 1300}

var floor_number := 1
var time := 0.0
var kills := 0
var damage_taken := 0.0
var deaths := 0
var potions_used := 0
var viewers := 0
## Loot box tiers (Achievements.Tier) waiting to be opened.
var boxes: Array[int] = []
## Floor modifiers (Milestone 12) multiply viewer gains.
var viewer_multiplier := 1.0
var timing := true


func _ready() -> void:
	add_to_group(GROUP)
	GameManager.enemy_died.connect(_on_enemy_died)


func bind(player: Player, rooms: RoomManager) -> void:
	player.health.damaged.connect(func(amount: float) -> void: damage_taken += amount)
	player.health.died.connect(func() -> void: deaths += 1)
	player.potions.used.connect(func(_healed: float) -> void: potions_used += 1)
	rooms.room_entered.connect(func(room: RoomBase) -> void:
		room.encounter_cleared.connect(func() -> void: add_viewers(ROOM_CLEAR_VIEWERS)))


## Starts a new floor's record. Unopened loot boxes can be kept.
func reset(number: int, keep_boxes := false) -> void:
	floor_number = number
	time = 0.0
	kills = 0
	damage_taken = 0.0
	deaths = 0
	potions_used = 0
	viewers = 0
	timing = true
	if not keep_boxes:
		boxes.clear()
	viewers_changed.emit(viewers, 0)
	boxes_changed.emit(boxes.size())


func _process(delta: float) -> void:
	if timing:
		time += delta


func add_viewers(amount: int) -> int:
	var gained := roundi(amount * viewer_multiplier)
	if gained == 0:
		return 0
	viewers = maxi(viewers + gained, 0)
	viewers_changed.emit(viewers, gained)
	return gained


func add_box(tier: int) -> void:
	boxes.append(tier)
	boxes_changed.emit(boxes.size())


## Removes and returns every waiting box.
func take_boxes() -> Array[int]:
	var taken := boxes.duplicate()
	boxes.clear()
	boxes_changed.emit(0)
	return taken


func has_boxes() -> bool:
	return not boxes.is_empty()


func _on_enemy_died(enemy: EnemyBase) -> void:
	if not is_inside_tree():
		return
	kills += 1
	var gain := BOSS_VIEWERS if enemy is BossBase else KILL_VIEWERS
	if enemy.last_hit:
		for tag in STYLE_TAGS:
			if enemy.last_hit.has_tag(tag):
				gain += STYLE_VIEWERS
				break
	add_viewers(gain)


## Letter grade: viewers against the floor's par, minus a step per death.
func grade() -> String:
	var par: float = PAR.get(floor_number, 1300)
	var ratio := viewers / par - 0.15 * deaths
	if ratio >= 1.6 and deaths == 0:
		return "S"
	if ratio >= 1.2:
		return "A"
	if ratio >= 0.85:
		return "B"
	if ratio >= 0.5:
		return "C"
	return "D"


func summary() -> Dictionary:
	return {
		"floor": floor_number, "time": time, "kills": kills, "damage_taken": damage_taken,
		"deaths": deaths, "potions_used": potions_used, "viewers": viewers, "grade": grade(),
	}


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
