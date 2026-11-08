class_name DungeonAIManager
extends Node
## The Dungeon AI: watches for showy plays, announces achievements and hands
## out rewards. Announcements never pause the game.
##
##   Enemy collision   - knock an enemy into another enemy
##                       -> +50% knockback for this room and the next three
##   Environmental kill - an enemy dies to spikes or an exploding barrel
##                       -> +25% damage (kicks and magic) for this room and the next three
##   Untouchable       - clear a combat room without taking any damage
##                       -> restores 25 HP immediately
##
## Each achievement can trigger at most once per room encounter (a room visit;
## dying and restarting the room starts a new encounter). Boosts refresh
## rather than stack, last through deaths, and end when the floor restarts or
## is completed.

signal achievement_unlocked(id: StringName, entry: Dictionary)

const COLLISION := &"enemy_collision"
const ENVIRONMENT_KILL := &"environment_kill"
const UNTOUCHABLE := &"untouchable"

@export var boost_rooms := 3
@export var knockback_boost := 0.5
@export var damage_boost := 0.25
@export var room_clear_heal := 25.0

var player: Player
var room_manager: RoomManager
var hud: HUD

## Achievement ids already awarded in the current encounter.
var _awarded_this_encounter: Array[StringName] = []
## Whether the player has taken damage since the current room's encounter began.
var _hurt_in_encounter := false
var _last_room_id := ""
## Every award this run, oldest first (for tests and a future stats screen).
var history: Array[StringName] = []


func setup(p_player: Player, p_room_manager: RoomManager, p_hud: HUD) -> void:
	player = p_player
	room_manager = p_room_manager
	hud = p_hud
	room_manager.room_entered.connect(_on_room_entered)
	player.health.damaged.connect(_on_player_damaged)
	GameManager.enemy_collided.connect(_on_enemy_collided)
	GameManager.enemy_died.connect(_on_enemy_died)


## Forget per-run state (floor restart / next floor). Boosts are cleared with
## the player's upgrades.
func reset() -> void:
	_awarded_this_encounter.clear()
	_hurt_in_encounter = false
	_last_room_id = ""


func _on_room_entered(room: RoomBase) -> void:
	# A fresh encounter every time a room is (re)loaded.
	_awarded_this_encounter.clear()
	_hurt_in_encounter = false
	# Boost durations count new rooms, not restarts of the same room.
	if room.room_id != _last_room_id and _last_room_id != "":
		player.upgrades.on_new_room()
	_last_room_id = room.room_id
	room.encounter_cleared.connect(_on_encounter_cleared.bind(room))


func _on_player_damaged(_amount: float) -> void:
	_hurt_in_encounter = true


func _on_enemy_collided(enemy: EnemyBase, other: EnemyBase) -> void:
	award(COLLISION, {
		"title": "YOU KICKED A %s INTO ANOTHER %s!" % [enemy.display_name.to_upper(), other.display_name.to_upper()],
		"description": "The Dungeon AI appreciates your commitment to solving every problem with your feet.",
		"reward": "Reward: +%d%% knockback for this room and the next %d." % [roundi(knockback_boost * 100.0), boost_rooms],
	})


func _on_enemy_died(enemy: EnemyBase) -> void:
	if enemy.last_hit == null or not enemy.last_hit.has_tag("hazard"):
		return
	var how := "the spikes" if enemy.last_hit.has_tag("spikes") else "a conveniently placed barrel"
	award(ENVIRONMENT_KILL, {
		"title": "LET THE DUNGEON DO THE WORK!",
		"description": "You killed a %s with %s. Why lift a foot when the architecture is so helpful?" % [
			enemy.display_name, how],
		"reward": "Reward: +%d%% damage for this room and the next %d." % [roundi(damage_boost * 100.0), boost_rooms],
	})


func _on_encounter_cleared(room: RoomBase) -> void:
	if room.room_type != RoomBase.RoomType.COMBAT or _hurt_in_encounter:
		return
	award(UNTOUCHABLE, {
		"title": "UNTOUCHABLE!",
		"description": "You cleared the room without taking a single hit. The viewers wanted more blood, frankly.",
		"reward": "Reward: +%d health, right now." % roundi(room_clear_heal),
	})


## Grants an achievement unless it was already awarded this encounter.
## Returns true if it was awarded.
func award(id: StringName, entry: Dictionary) -> bool:
	if player == null or player.health.is_dead or _awarded_this_encounter.has(id):
		return false
	_awarded_this_encounter.append(id)
	history.append(id)
	match id:
		COLLISION:
			player.upgrades.add_boost(PlayerUpgrades.BOOST_KNOCKBACK, knockback_boost, boost_rooms)
		ENVIRONMENT_KILL:
			player.upgrades.add_boost(PlayerUpgrades.BOOST_DAMAGE, damage_boost, boost_rooms)
		UNTOUCHABLE:
			player.health.heal(room_clear_heal)
	Audio.play("achievement", 0.0, 0.0)
	if hud:
		hud.announce(entry)
	achievement_unlocked.emit(id, entry)
	return true
