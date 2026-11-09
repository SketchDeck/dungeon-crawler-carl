class_name DungeonAIManager
extends Node
## The Dungeon AI: watches for showy plays, announces achievements and hands
## out rewards. Announcements never pause the game. Achievement names, hints
## and loot box tiers live in Achievements.gd; this script decides when each
## one triggers.
##
## Every achievement pays out a loot box of its tier (opened at a safe-room
## fountain) and a burst of viewers. A few also give an instant reward:
##   Enemy collision   -> +50% knockback for this room and the next three
##   Environmental kill, Juggler -> +25% damage for this room and the next three
##   Untouchable       -> restores 25 HP immediately
##
## Most achievements trigger at most once per room encounter (a room visit;
## dying and restarting the room starts a new encounter). Those marked
## per_floor in Achievements.gd trigger once per floor run. Boosts refresh
## rather than stack, last through deaths, and end when the floor restarts or
## is completed. Every award is also recorded in the player's profile.

signal achievement_unlocked(id: StringName, entry: Dictionary)

const COLLISION := &"enemy_collision"
const ENVIRONMENT_KILL := &"environment_kill"
const UNTOUCHABLE := &"untouchable"
const JUGGLER := &"juggler"

## Time windows for multi-kills, in seconds.
const TRIPLE_KILL_WINDOW := 1.5
const CHAIN_WINDOW := 0.25
const CLOSE_CALL_FRACTION := 0.15
const BOSS_RUSH_TIME := 60.0
const PIT_DIVES := 3

@export var boost_rooms := 3
@export var knockback_boost := 0.5
@export var damage_boost := 0.25
@export var room_clear_heal := 25.0

var player: Player
var room_manager: RoomManager
var hud: HUD
var run_stats: RunStats

## Achievement ids already awarded in the current encounter.
var _awarded_this_encounter: Array[StringName] = []
## Per-floor achievements already awarded this floor run.
var _awarded_this_floor: Array[StringName] = []
## Whether the player has taken damage since the current room's encounter began.
var _hurt_in_encounter := false
var _last_room_id := ""
## Every award this run, oldest first (for tests and a future stats screen).
var history: Array[StringName] = []

## Seconds of game time (drives the multi-kill windows).
var _clock := 0.0
var _kill_times: Array[float] = []
var _explosion_kill_times: Array[float] = []
var _room_kill_kinds := {}
var _pit_falls := 0
var _boss_started_at := -1.0
var _floor_kills := 0


func setup(p_player: Player, p_room_manager: RoomManager, p_hud: HUD, p_run_stats: RunStats = null) -> void:
	player = p_player
	room_manager = p_room_manager
	hud = p_hud
	run_stats = p_run_stats
	room_manager.room_entered.connect(_on_room_entered)
	room_manager.player_fell.connect(_on_player_fell)
	player.health.damaged.connect(_on_player_damaged)
	player.potions.changed.connect(_on_potions_changed)
	GameManager.enemy_collided.connect(_on_enemy_collided)
	GameManager.enemy_died.connect(_on_enemy_died)
	GameManager.enemy_juggled.connect(_on_enemy_juggled)
	GameManager.enemy_damaged.connect(_on_enemy_damaged)
	GameManager.shell_cracked.connect(_on_shell_cracked)
	GameManager.wall_broken.connect(_on_wall_broken)


## Forget per-run state (floor restart / next floor). Boosts are cleared with
## the player's upgrades.
func reset() -> void:
	_awarded_this_encounter.clear()
	_awarded_this_floor.clear()
	_hurt_in_encounter = false
	_last_room_id = ""
	_kill_times.clear()
	_explosion_kill_times.clear()
	_room_kill_kinds.clear()
	_pit_falls = 0
	_boss_started_at = -1.0
	_floor_kills = 0


func _physics_process(delta: float) -> void:
	_clock += delta


func _on_room_entered(room: RoomBase) -> void:
	# A fresh encounter every time a room is (re)loaded.
	_awarded_this_encounter.clear()
	_hurt_in_encounter = false
	_room_kill_kinds.clear()
	# Boost durations count new rooms, not restarts of the same room.
	if room.room_id != _last_room_id and _last_room_id != "":
		player.upgrades.on_new_room()
	_last_room_id = room.room_id
	room.encounter_cleared.connect(_on_encounter_cleared.bind(room))
	room.boss_started.connect(func(_boss: BossBase) -> void: _boss_started_at = _clock)
	room.boss_defeated.connect(_on_boss_defeated)


func _on_player_damaged(_amount: float) -> void:
	_hurt_in_encounter = true


func _on_enemy_collided(enemy: EnemyBase, other: EnemyBase) -> void:
	award(COLLISION, {
		"title": "YOU KICKED A %s INTO ANOTHER %s!" % [enemy.display_name.to_upper(), other.display_name.to_upper()],
		"description": "The Dungeon AI appreciates your commitment to solving every problem with your feet.",
		"reward": "Reward: +%d%% knockback for this room and the next %d." % [roundi(knockback_boost * 100.0), boost_rooms],
	})


func _is_player_hit(hit: Hit) -> bool:
	return hit != null and is_instance_valid(player) and hit.source == player


func _on_enemy_died(enemy: EnemyBase) -> void:
	var hit := enemy.last_hit
	_floor_kills += 1
	if _floor_kills == 1:
		award(&"first_blood", {
			"title": "FIRST BLOOD!",
			"description": "A %s has died so that you may be entertaining. The audience thanks it for its service." % enemy.display_name,
		})
	# Triple kill.
	_kill_times.append(_clock)
	while not _kill_times.is_empty() and _clock - _kill_times[0] > TRIPLE_KILL_WINDOW:
		_kill_times.pop_front()
	if _kill_times.size() >= 3:
		award(&"triple_kill", {
			"title": "TRIPLE KILL!",
			"description": "Three dead in a heartbeat. Somewhere, a goblin mother is filing a complaint.",
		})
	if hit == null:
		return
	if hit.has_tag("explosion"):
		_explosion_kill_times.append(_clock)
		while not _explosion_kill_times.is_empty() and _clock - _explosion_kill_times[0] > CHAIN_WINDOW:
			_explosion_kill_times.pop_front()
		if _explosion_kill_times.size() >= 2:
			award(&"chain_reaction", {
				"title": "CHAIN REACTION!",
				"description": "Multiple enemies, one fireball. The insurance adjusters weep.",
			})
	if hit.has_tag("hazard"):
		var how := "the spikes" if hit.has_tag("spikes") else "a conveniently placed barrel"
		award(ENVIRONMENT_KILL, {
			"title": "LET THE DUNGEON DO THE WORK!",
			"description": "You killed a %s with %s. Why lift a foot when the architecture is so helpful?" % [
				enemy.display_name, how],
			"reward": "Reward: +%d%% damage for this room and the next %d." % [roundi(damage_boost * 100.0), boost_rooms],
		})
	if hit.has_tag("fire") or hit.has_tag("volatile"):
		award(&"spicy", {
			"title": "SPICY!",
			"description": "That %s went out the way it lived: on fire and screaming." % enemy.display_name,
		})
	if enemy is Bat and hit.has_tag("kick"):
		award(&"bat_swatter", {
			"title": "BAT SWATTER!",
			"description": "You kicked a flying bat out of the air. With your foot. The physics team is confused.",
		})
	if _is_player_hit(hit):
		if hit.has_tag("kick"):
			_room_kill_kinds["kick"] = true
		if hit.has_tag("magic"):
			_room_kill_kinds["magic"] = true
		if _room_kill_kinds.has("kick") and _room_kill_kinds.has("magic"):
			award(&"dynamic_duo", {
				"title": "DYNAMIC DUO!",
				"description": "A man and his cat, killing in harmony. The merchandise practically sells itself.",
			})


func _on_enemy_juggled(enemy: EnemyBase) -> void:
	award(JUGGLER, {
		"title": "JUGGLER!",
		"description": "Carl punted a %s into the air and Donut zapped it before it landed. Teamwork! Disgusting, beautiful teamwork." % enemy.display_name,
		"reward": "Reward: +%d%% damage for this room and the next %d." % [roundi(damage_boost * 100.0), boost_rooms],
	})


func _on_enemy_damaged(enemy: EnemyBase, amount: float, hit: Hit) -> void:
	if not _is_player_hit(hit):
		return
	if amount >= 35.0:
		award(&"overkill", {
			"title": "OVERKILL!",
			"description": "%d damage in one hit. The %s's ancestors felt that." % [roundi(amount), enemy.display_name],
		})
	if enemy is ShieldGoblin and hit.has_tag("kick") and amount > 0.0:
		award(&"what_shield", {
			"title": "WHAT SHIELD?",
			"description": "It had one job: face you. It did not do its job.",
		})


func _on_shell_cracked(_enemy: EnemyBase) -> void:
	award(&"shell_shocked", {
		"title": "SHELL SHOCKED!",
		"description": "You cracked open a slime like a tin of beans. Gourmet.",
	})


func _on_wall_broken() -> void:
	award(&"wall_breaker", {
		"title": "RENOVATIONS!",
		"description": "The dungeon's architects would like a word. They have a lot of words.",
	})


func _on_player_fell() -> void:
	_pit_falls += 1
	if _pit_falls >= PIT_DIVES:
		award(&"pit_diver", {
			"title": "PIT DIVER!",
			"description": "Three falls into the same kind of hole. The viewers have started a drinking game.",
			"reward": "Reward: a pity box. Don't spend it all at once.",
		})


func _on_potions_changed(count: int, capacity: int) -> void:
	if count >= capacity:
		award(&"hoarder", {
			"title": "HOARDER!",
			"description": "Ten potions and a cat. You are one cardigan away from a reality show.",
		})


func _on_encounter_cleared(room: RoomBase) -> void:
	if room.room_type != RoomBase.RoomType.COMBAT:
		return
	if player.health.current <= player.health.max_health * CLOSE_CALL_FRACTION:
		award(&"close_call", {
			"title": "CLOSE CALL!",
			"description": "You won with a sliver of health left. The viewers' heart rates are being monitored.",
		})
	if _hurt_in_encounter:
		return
	award(UNTOUCHABLE, {
		"title": "UNTOUCHABLE!",
		"description": "You cleared the room without taking a single hit. The viewers wanted more blood, frankly.",
		"reward": "Reward: +%d health, right now." % roundi(room_clear_heal),
	})


func _on_boss_defeated() -> void:
	if _boss_started_at >= 0.0 and _clock - _boss_started_at <= BOSS_RUSH_TIME:
		award(&"speed_boss", {
			"title": "BOSS RUSH!",
			"description": "The boss had a whole speech prepared. You didn't let it finish.",
		})
	_boss_started_at = -1.0
	if run_stats == null:
		return
	if run_stats.potions_used == 0:
		award(&"sober", {
			"title": "STONE COLD SOBER!",
			"description": "A whole floor without a single potion. Your liver salutes you.",
		})
	if run_stats.deaths == 0:
		award(&"deathless", {
			"title": "DEATHLESS!",
			"description": "A whole floor and you never died once. Statistically suspicious.",
		})


## Grants an achievement unless it was already awarded this encounter (or
## this floor, for per-floor ones). Returns true if it was awarded.
func award(id: StringName, entry: Dictionary) -> bool:
	if player == null or player.health.is_dead or _awarded_this_encounter.has(id) or _awarded_this_floor.has(id):
		return false
	_awarded_this_encounter.append(id)
	if Achievements.per_floor(id):
		_awarded_this_floor.append(id)
	history.append(id)
	match id:
		COLLISION:
			player.upgrades.add_boost(PlayerUpgrades.BOOST_KNOCKBACK, knockback_boost, boost_rooms)
		ENVIRONMENT_KILL, JUGGLER:
			player.upgrades.add_boost(PlayerUpgrades.BOOST_DAMAGE, damage_boost, boost_rooms)
		UNTOUCHABLE:
			player.health.heal(room_clear_heal)
	var tier := Achievements.tier(id)
	var first := GameManager.record_achievement(id)
	var shown := entry.duplicate()
	var box_line := "+ %s loot box (open it at a safe-room fountain)" % Achievements.tier_name(tier)
	shown["reward"] = "%s\n%s" % [entry["reward"], box_line] if entry.has("reward") else "Reward: " + box_line.substr(2)
	shown["tier"] = tier
	shown["first"] = first
	if run_stats:
		run_stats.add_box(tier)
		run_stats.add_viewers(Achievements.TIER_VIEWERS[tier])
	Audio.play("achievement", 0.0, 0.0)
	if hud:
		hud.announce(shown)
	achievement_unlocked.emit(id, shown)
	return true
