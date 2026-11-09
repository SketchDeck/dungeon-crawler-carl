extends Node2D
## Game root: owns the persistent player, HUD and room manager, and runs the
## lives flow.
##
## Losing a life: death effect -> lose one life -> restart the current room
## (its encounter resets) -> respawn at full health, keeping potions.
## Losing the last life: Game Over -> restart the floor with 3 lives, full
## health, 3 potions and fresh room progress.
## Beating the boss and taking the stairs: Floor Complete screen -> continue
## to the next floor (full health, 3 lives, potions kept) or replay this one.
## Temporary upgrades come from treasure chests and are cleared whenever the
## floor restarts or is completed.

@export var respawn_delay := 1.5
const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

## Debug: N jumps through the current room's first exit, ignoring locks;
## U unlocks both special abilities.
@export var debug_keys := true

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var room_slot: Node2D = $Room
@onready var room_manager: RoomManager = $RoomManager
@onready var game_over: GameOverScreen = $GameOver
@onready var floor_complete: FloorCompleteScreen = $FloorComplete
@onready var upgrade_selection: UpgradeSelectionScreen = $UpgradeSelection
@onready var dungeon_ai: DungeonAIManager = $DungeonAI
@onready var pause_menu: PauseMenu = $PauseMenu

## Tests turn this off and read `requested_scene` instead of changing scenes.
var navigate := true
var requested_scene := ""

## Abilities unlocked since the floor started, shown on Floor Complete.
var _new_unlocks: Array[StringName] = []
## The floor run's record (viewers, kills, loot boxes...).
var run_stats: RunStats
var loot_screen: LootBoxScreen
var shop_screen: ShopScreen
## Shop prices in gold.
const SHOP_STOCK: Array[Dictionary] = [
	{"id": "potion", "name": "Health potion", "description": "Heals 30 HP when you drink it.", "price": 12},
	{"id": "bronze_box", "name": "Bronze loot box", "description": "Open it at the fountain.", "price": 20},
	{"id": "stat_upgrade", "name": "Stat upgrade", "description": "Choose one of three common upgrades.", "price": 40},
	{"id": "rare_upgrade", "name": "Rare upgrade", "description": "Choose one of three rare or epic upgrades.", "price": 85},
]
## Upgrade picks bought in the shop, offered when it closes: rarity floor per pick.
var _shop_picks: Array[int] = []
## Upgrade choices still owed from gold loot boxes.
var _pending_picks := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Playtest builds (make playtest) are for the team: no debug shortcuts.
	if OS.has_feature("playtest"):
		debug_keys = false
	_rng.randomize()
	run_stats = RunStats.new()
	run_stats.name = "RunStats"
	add_child(run_stats)
	loot_screen = LootBoxScreen.new()
	loot_screen.name = "LootBoxes"
	loot_screen.opener = open_loot_box
	add_child(loot_screen)
	loot_screen.closed.connect(_on_loot_closed)
	run_stats.loot_requested.connect(open_loot_boxes)
	shop_screen = ShopScreen.new()
	shop_screen.name = "Shop"
	shop_screen.buyer = buy_item
	shop_screen.gold_source = func() -> int: return run_stats.gold
	add_child(shop_screen)
	shop_screen.closed.connect(_offer_pending_pick)
	run_stats.shop_requested.connect(open_shop)
	hud.bind_player(player)
	hud.bind_rooms(room_manager)
	hud.bind_run(run_stats)
	room_manager.setup(player, room_slot, hud)
	run_stats.bind(player, room_manager)
	dungeon_ai.setup(player, room_manager, hud, run_stats)
	player.health.died.connect(_on_player_died)
	game_over.restart_requested.connect(restart_floor)
	room_manager.floor_exit_reached.connect(_on_floor_exit_reached)
	floor_complete.continue_requested.connect(continue_to_next_floor)
	floor_complete.replay_requested.connect(restart_floor)
	floor_complete.main_menu_requested.connect(go_to_main_menu)
	game_over.main_menu_requested.connect(go_to_main_menu)
	pause_menu.main_menu_requested.connect(go_to_main_menu)
	room_manager.treasure_opened.connect(_on_treasure_opened)
	upgrade_selection.chosen.connect(_on_upgrade_chosen)
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	room_manager.room_entered.connect(_on_room_entered_music)
	GameManager.enemy_died.connect(_on_enemy_died_modifiers)
	GameManager.reset_lives()
	_begin_floor(false)


## Starts the current floor: picks this run's sponsor events (a replay of a
## beaten floor gets one; Hard mode adds one; the Daily Run gets two from the
## day's seed), applies them, and loads the entrance.
func _begin_floor(keep_boxes: bool) -> void:
	var number := GameManager.floor_number
	var mods: Array[StringName] = []
	var run_seed := -1
	if GameManager.daily_run:
		run_seed = GameManager.daily_seed(GameManager.today()) + number
		var daily_rng := RandomNumberGenerator.new()
		daily_rng.seed = run_seed
		mods = Modifiers.pick(daily_rng, 2)
	elif GameManager.hard_mode or GameManager.is_floor_completed(number):
		mods = Modifiers.pick(_rng, 1)
	set_modifiers(mods, GameManager.hard_mode)
	run_stats.reset(number, keep_boxes)
	room_manager.start_floor(number, run_seed)
	if not mods.is_empty() or GameManager.hard_mode:
		var lines: Array[String] = []
		for id in mods:
			lines.append("%s: %s" % [Modifiers.display_name(id), Modifiers.description(id)])
		hud.show_banner("SPONSOR EVENT" if not mods.is_empty() else "HARD MODE",
			"  ·  ".join(lines) if not lines.is_empty() else "Tougher enemies, harder hits, more viewers.", Color("#ff8af0"))


## Applies floor modifiers to the room manager, the player and the score.
func set_modifiers(mods: Array[StringName], hard: bool) -> void:
	room_manager.modifiers = mods
	room_manager.hard_mode = hard
	player.health.incoming_multiplier = Modifiers.damage_taken_multiplier(mods, hard)
	player.combat.modifier_damage_multiplier = Modifiers.damage_dealt_multiplier(mods)
	player.upgrades.refresh()
	run_stats.viewer_multiplier = Modifiers.viewer_multiplier(mods, hard)
	hud.set_modifiers(Modifiers.summary(mods, hard))


func _on_enemy_died_modifiers(enemy: EnemyBase) -> void:
	if room_manager.modifiers.has(Modifiers.EXPLOSIVE) and not enemy is BossBase:
		_modifier_blast.call_deferred(enemy.global_position)


func _modifier_blast(at: Vector2) -> void:
	if not is_inside_tree():
		return
	Explosion.detonate(room_slot, at, Modifiers.EXPLOSION_RADIUS, Modifiers.EXPLOSION_ENEMY_DAMAGE, 300.0,
		HitQuery.LAYER_ENEMIES | HitQuery.LAYER_PLAYER | HitQuery.LAYER_HITTABLE, null,
		PackedStringArray(["explosion", "hazard"]), Color("#ff5a3c"), Modifiers.EXPLOSION_PLAYER_DAMAGE)


## Floor music, switching to the boss theme while a boss fight is on.
func floor_music() -> String:
	return "floor%d" % GameManager.floor_number


func _on_room_entered_music(room: RoomBase) -> void:
	Audio.play_music(floor_music())
	room.boss_started.connect(func(_boss: BossBase) -> void: Audio.play_music("boss"))
	room.boss_defeated.connect(func() -> void:
		Audio.play("floor_complete", 0.0, 0.0)
		Audio.play_music(floor_music()))


func _on_player_died() -> void:
	var remaining := GameManager.lose_life()
	Audio.play("life_lost", 0.0, 0.0)
	Fx.shake(0.6)
	Fx.burst(player.global_position, Color("#ff5050"), 48.0, 0.5)
	Fx.text(player.global_position + Vector2(0, -60),
		"-1 LIFE" if remaining > 0 else "OUT OF LIVES", Color("#ff6060"), 22)
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	if remaining > 0:
		respawn_in_current_room()
	else:
		Audio.play_music("")
		Audio.play("game_over", 0.0, 0.0)
		game_over.show_screen()


func respawn_in_current_room() -> void:
	# Respawn first (clears combat state), then reload the room, which
	# re-activates its encounter and places the player at the entrance.
	player.respawn(player.global_position)
	room_manager.reload_current_room()


func restart_floor() -> void:
	GameManager.reset_lives()
	player.potions.reset()
	player.upgrades.clear()
	dungeon_ai.reset()
	_new_unlocks.clear()
	player.respawn(player.global_position)
	_begin_floor(false)


## Back to the title screen. Completed floors and unlocks are already saved.
func go_to_main_menu() -> void:
	get_tree().paused = false
	requested_scene = MENU_SCENE
	if navigate:
		get_tree().change_scene_to_file(MENU_SCENE)


func _on_floor_exit_reached(floor_number: int) -> void:
	Audio.play_music("menu")
	Audio.play("achievement", 0.0, 0.0)
	run_stats.timing = false
	var summary := run_stats.summary()
	summary["new_best"] = GameManager.record_run(summary)
	if GameManager.daily_run:
		summary["daily"] = true
		summary["daily_best"] = GameManager.record_daily(GameManager.today(), run_stats.viewers)
	floor_complete.show_screen(floor_number, GameManager.lives, player.potions.count, _new_unlocks, summary)


func _on_ability_unlocked(id: StringName) -> void:
	Audio.play("achievement", 0.0, 0.0)
	_new_unlocks.append(id)
	Fx.text(player.global_position + Vector2(0, -90), "NEW ABILITY: %s" % GameManager.ABILITY_NAMES.get(id, String(id)),
		Color("#ffd34d"), 18)


func _on_treasure_opened(_room: RoomBase) -> void:
	upgrade_selection.show_choices(player.upgrades.roll(3))


func _on_upgrade_chosen(upgrade: Upgrade) -> void:
	player.upgrades.apply(upgrade)
	Fx.text(player.global_position + Vector2(0, -70), upgrade.title.to_upper() + "!", Color("#ffd34d"), 18)
	_offer_pending_pick.call_deferred()


# --- Loot boxes -------------------------------------------------------------------

func open_loot_boxes() -> void:
	if loot_screen.is_open() or shop_screen.is_open() or upgrade_selection.visible or not run_stats.has_boxes():
		return
	loot_screen.open_boxes(run_stats.take_boxes())


## Applies one box's reward and describes it.
##   Bronze: a potion (or viewers if you're full), sometimes a sponsor shout-out.
##   Silver: a random stat upgrade and a potion.
##   Gold: an upgrade choice (rare or better) and a hat for Carl.
func open_loot_box(tier: int) -> String:
	match tier:
		Achievements.Tier.BRONZE:
			if _rng.randf() < 0.3:
				run_stats.add_viewers(60)
				return "A sponsor shout-out! +60 viewers."
			if player.potions.add():
				return "A health potion!"
			run_stats.add_viewers(40)
			return "A health potion... which you sold to a viewer. +40 viewers."
		Achievements.Tier.SILVER:
			var commons: Array[Upgrade] = []
			for u in PlayerUpgrades.POOL:
				if u.rarity == Upgrade.Rarity.COMMON:
					commons.append(u)
			var pick := commons[_rng.randi_range(0, commons.size() - 1)]
			player.upgrades.apply(pick)
			var potion := player.potions.add()
			return "%s: %s%s" % [pick.title, pick.description(), "\nPlus a health potion." if potion else ""]
		_:
			_pending_picks += 1
			var hat := GameManager.unlock_random_hat(_rng)
			var lines := ["Choose a rare upgrade when you're done."]
			if hat != "":
				lines.append("New hat for Carl: %s! (Change hats under Extras.)" % GameManager.HATS[hat])
			else:
				run_stats.add_viewers(150)
				lines.append("You own every hat, so the viewers get a show instead. +150 viewers.")
			return "\n".join(lines)


# --- Shop -----------------------------------------------------------------------------

func open_shop() -> void:
	if shop_screen.is_open() or loot_screen.is_open() or upgrade_selection.visible:
		return
	shop_screen.open(SHOP_STOCK)


## Applies a purchase. Returns a message, or "" if it couldn't be bought.
func buy_item(item_id: String) -> String:
	var item: Dictionary = {}
	for entry in SHOP_STOCK:
		if entry["id"] == item_id:
			item = entry
	if item.is_empty() or run_stats.gold < int(item["price"]):
		return ""
	if item_id == "potion" and player.potions.is_full():
		return ""
	run_stats.spend_gold(int(item["price"]))
	dungeon_ai.award(&"shopper", {
		"title": "VALUED CUSTOMER!",
		"description": "You paid actual money in a dungeon. The shopkeeper is weeping with joy. Or laughing. Hard to tell.",
	})
	match item_id:
		"potion":
			player.potions.add()
			return "A potion! It fizzes ominously."
		"bronze_box":
			run_stats.add_box(Achievements.Tier.BRONZE)
			return "A bronze box. Open it at the fountain."
		"stat_upgrade":
			_shop_picks.append(Upgrade.Rarity.COMMON)
			return "Pick your upgrade when you leave the shop."
		"rare_upgrade":
			_shop_picks.append(Upgrade.Rarity.RARE)
			return "Pick your rare upgrade when you leave the shop."
	return ""


func _on_loot_closed() -> void:
	_offer_pending_pick()


func _offer_pending_pick() -> void:
	if upgrade_selection.visible or loot_screen.is_open() or shop_screen.is_open():
		return
	if not _shop_picks.is_empty():
		var min_rarity: int = _shop_picks.pop_front()
		var max_rarity := Upgrade.Rarity.COMMON if min_rarity == Upgrade.Rarity.COMMON else Upgrade.Rarity.EPIC
		upgrade_selection.show_choices(player.upgrades.roll(3, min_rarity, max_rarity))
		return
	if _pending_picks <= 0:
		return
	_pending_picks -= 1
	upgrade_selection.show_choices(player.upgrades.roll(3, Upgrade.Rarity.RARE))


## Next floor: full health, lives back to 3, unused potions carried over.
func continue_to_next_floor() -> void:
	if not FloorData.has_floor(GameManager.floor_number + 1):
		return
	GameManager.floor_number += 1
	GameManager.reset_lives()
	player.upgrades.clear()
	dungeon_ai.reset()
	_new_unlocks.clear()
	player.respawn(player.global_position)
	_begin_floor(true)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if debug_keys and key and key.pressed and not key.echo and key.physical_keycode == KEY_U:
		GameManager.debug_unlock_all()
		Fx.text(player.global_position + Vector2(0, -60), "DEBUG: specials unlocked", Color("#8ec5ff"), 14)
	if debug_keys and key and key.pressed and not key.echo and key.physical_keycode == KEY_N:
		var room := room_manager.current_room
		if room and not room.exits.is_empty():
			room_manager.request_exit(0)
