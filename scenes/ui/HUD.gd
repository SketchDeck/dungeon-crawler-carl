class_name HUD
extends CanvasLayer
## Health bar (with delayed "recent damage" ghost bar), HP text, potion count,
## combat mode and ability cooldowns, combat/regeneration status, boss health
## bar and controls hint.

const GHOST_DELAY := 0.4
const GHOST_SPEED := 60.0
const FILL := Color("#d83a3a")
const FILL_REGEN := Color("#d8583a")
const REGEN_GREEN := Color("#7dff8a")

var _player: Player
var _current := 100.0
var _maximum := 100.0
var _ghost_value := 100.0
var _ghost_wait := 0.0
var _potion_pulse := 0.0
var _fill_box: StyleBoxFlat
var _ghost_fill_box: StyleBoxFlat
var _t := 0.0

@onready var _bar: ProgressBar = %HealthBar
@onready var _ghost: ProgressBar = %GhostBar
@onready var _hp_label: Label = %HPLabel
@onready var _potion_label: Label = %PotionLabel
@onready var _potion_row: Control = %PotionRow
@onready var _status_label: Label = %StatusLabel
@onready var _lives: Control = %Lives
@onready var _room_label: Label = %RoomLabel
@onready var _banner: Control = %Banner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_subtitle: Label = %BannerSubtitle
@onready var _fade: ColorRect = %Fade
@onready var _mode_label: Label = %ModeLabel
@onready var _abilities: Control = %Abilities
@onready var _upgrades_label: Label = %UpgradesLabel
@onready var _controls: Label = %Controls
@onready var _boosts_label: Label = %BoostsLabel
@onready var achievement_panel: AchievementPanel = %Achievement

var _mode_pulse := 0.0

@onready var _boss_bar: Control = %BossBar
@onready var _boss_name: Label = %BossName
@onready var _boss_health: ProgressBar = %BossHealth
@onready var _boss_ghost: ProgressBar = %BossGhost

var _boss: BossBase
var _boss_fill: StyleBoxFlat
var _boss_ghost_value := 0.0
var _boss_ghost_wait := 0.0
var _boss_hide_t := 0.0

var _banner_tween: Tween


func _ready() -> void:
	_banner.modulate.a = 0.0
	_fade.color.a = 0.0
	GameManager.lives_changed.connect(_on_lives_changed)
	_on_lives_changed(GameManager.lives)
	Settings.changed.connect(_update_controls_hint)
	_update_controls_hint()
	_fill_box = _flat(FILL)
	_ghost_fill_box = _flat(Color("#f2d0a0"))
	_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0)))
	_bar.add_theme_stylebox_override("fill", _fill_box)
	_ghost.add_theme_stylebox_override("background", _flat(Color("#0d0f14"), Color("#53657c")))
	_ghost.add_theme_stylebox_override("fill", _ghost_fill_box)
	_boss_fill = _flat(Color("#c8302a"))
	_boss_health.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0)))
	_boss_health.add_theme_stylebox_override("fill", _boss_fill)
	_boss_ghost.add_theme_stylebox_override("background", _flat(Color("#0d0f14"), Color("#7c5353")))
	_boss_ghost.add_theme_stylebox_override("fill", _flat(Color("#f2d0a0")))


func bind_player(player: Player) -> void:
	_player = player
	player.health.health_changed.connect(_on_health_changed)
	player.potions.changed.connect(_on_potions_changed)
	_on_health_changed(player.health.current, player.health.max_health)
	_on_potions_changed(player.potions.count, player.potions.capacity)
	_ghost_value = _current
	_abilities.set("player", player)
	player.combat.mode_changed.connect(_on_mode_changed)
	player.upgrades.changed.connect(_on_upgrades_changed)
	_on_upgrades_changed(player.upgrades.active)
	player.upgrades.boosts_changed.connect(_on_boosts_changed)
	_on_boosts_changed()
	_on_mode_changed(player.combat.mode)
	_mode_pulse = 0.0


func _on_upgrades_changed(active: Array[Upgrade]) -> void:
	var names: Array[String] = []
	for upgrade in active:
		names.append(upgrade.title)
	_upgrades_label.text = "Upgrades: " + ", ".join(names) if not names.is_empty() else ""
	_upgrades_label.visible = not names.is_empty()


## Bottom-line controls reminder, built from the current key bindings.
func _update_controls_hint() -> void:
	var k := func(action: String) -> String: return Settings.prompt_label(action)
	($TopLeft/PotionRow/PotionHint as Label).text = "[%s] drink" % k.call("use_potion")
	if _player:
		_on_mode_changed(_player.combat.mode)
		_mode_pulse = 0.0
	if Settings.using_controller:
		_controls.text = "Stick move · %s jump · %s dodge · %s Carl/Donut · %s kick/missile · hold %s power/blast · %s special · %s potion · %s use · %s pause" % [
			k.call("jump"), k.call("dodge"), k.call("switch_mode"), k.call("basic_attack"), k.call("charged_attack"),
			k.call("special_attack"), k.call("use_potion"), k.call("interact"), k.call("pause")]
		return
	_controls.text = "%s/%s move · %s jump · %s dodge · %s Carl/Donut · %s kick/missile · hold %s power/blast · %s special · %s potion · %s use · Esc pause" % [
		k.call("move_left"), k.call("move_right"), k.call("jump"), k.call("dodge"), k.call("switch_mode"),
		k.call("basic_attack"), k.call("charged_attack"), k.call("special_attack"), k.call("use_potion"), k.call("interact")]


## Dungeon AI achievement popup (queued, never pauses the game).
func announce(entry: Dictionary) -> void:
	achievement_panel.announce(entry)


func _on_boosts_changed() -> void:
	var parts: Array[String] = []
	var names := {PlayerUpgrades.BOOST_KNOCKBACK: "Knockback", PlayerUpgrades.BOOST_DAMAGE: "Damage"}
	for kind: StringName in _player.upgrades.boosts:
		var left := _player.upgrades.boost_rooms_left(kind)
		var when := "last room" if left == 0 else "%d more room%s" % [left, "" if left == 1 else "s"]
		parts.append("%s +%d%% (%s)" % [names.get(kind, String(kind)), roundi(_player.upgrades.boost(kind) * 100.0), when])
	_boosts_label.text = "AI boosts: " + ", ".join(parts) if not parts.is_empty() else ""
	_boosts_label.visible = not parts.is_empty()


func _on_mode_changed(mode: PlayerCombat.Mode) -> void:
	# Always name the mode, so it doesn't rely on color alone.
	var what := "kicks" if mode == PlayerCombat.Mode.CARL else "magic"
	_mode_label.text = "MODE: %s · %s   [%s] switch" % [PlayerCombat.mode_name(mode), what, Settings.prompt_label("switch_mode")]
	_mode_label.add_theme_color_override("font_color", PlayerCombat.mode_color(mode).lightened(0.15))
	_mode_pulse = 0.25


func bind_rooms(manager: RoomManager) -> void:
	manager.room_entered.connect(_on_room_entered.bind(manager))


func _on_lives_changed(lives: int) -> void:
	_lives.set("lives", lives)


func _on_room_entered(room: RoomBase, manager: RoomManager) -> void:
	hide_boss_bar()
	room.boss_started.connect(show_boss_bar)
	_room_label.text = "%s  ·  %s" % [FloorData.floor_name(manager.floor_number), room.display_name]
	var title := ""
	var subtitle := ""
	var color := Color.WHITE
	match room.room_type:
		RoomBase.RoomType.ENTRANCE:
			title = FloorData.floor_name(manager.floor_number).to_upper()
			subtitle = room.display_name
			color = Color("#8ec5ff")
		RoomBase.RoomType.COMBAT:
			title = "COMBAT"
			subtitle = "Room cleared" if room.is_cleared() else "Defeat every enemy to unlock the exits"
			color = Color("#ffcf6b")
		RoomBase.RoomType.SAFE:
			title = "SAFE ROOM"
			subtitle = "No enemies here. Catch your breath."
			color = Color("#8fe39a")
		RoomBase.RoomType.CHALLENGE:
			title = "CHALLENGE"
			subtitle = room.trial_hint
			color = Color("#c3a6ff")
		RoomBase.RoomType.BOSS:
			title = "BOSS"
			subtitle = room.display_name
			color = Color("#ff7a7a")
	show_banner(title, subtitle, color)


func show_banner(title: String, subtitle: String, color := Color.WHITE) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_subtitle.text = subtitle
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


## Fades the screen to black (alpha 1) or back (alpha 0).
func fade(alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	return tween


# --- Boss bar -------------------------------------------------------------------

func show_boss_bar(boss: BossBase) -> void:
	_boss = boss
	_boss_name.text = boss.boss_name
	_boss_health.max_value = boss.max_health
	_boss_ghost.max_value = boss.max_health
	_boss_ghost_value = boss.health
	_boss_fill.bg_color = Color("#c8302a")
	_boss_hide_t = 0.0
	_boss_bar.visible = true
	_boss_bar.modulate.a = 1.0
	boss.phase_changed.connect(_on_boss_phase)
	boss.died.connect(_on_boss_died)
	show_banner(boss.boss_name, boss.boss_hint, Color("#ff7a7a"))


func hide_boss_bar() -> void:
	_boss = null
	_boss_bar.visible = false


func is_boss_bar_visible() -> bool:
	return _boss_bar.visible


func _on_boss_phase(_phase: int) -> void:
	_boss_fill.bg_color = Color("#ff5a1f")
	var hint := "The Brute is enraged: faster attacks, longer shockwaves" if _boss is GoblinBoss \
		else "It's mutating: more globs, acid everywhere, and it splits off little slimes"
	show_banner("PHASE 2", hint, Color("#ff5a1f"))


func _on_boss_died(_enemy: EnemyBase) -> void:
	_boss_hide_t = 2.0
	show_banner("VICTORY", "The Goblin Brute is down. Take the stairs.", Color("#ffd34d"))


func _update_boss_bar(delta: float) -> void:
	# The boss node is freed shortly after it dies; the bar keeps fading out.
	if not _boss_bar.visible:
		return
	var hp := _boss.health if is_instance_valid(_boss) else 0.0
	if hp < _boss_health.value:
		_boss_ghost_wait = GHOST_DELAY
	_boss_health.value = hp
	if _boss_ghost_value > hp:
		if _boss_ghost_wait > 0.0:
			_boss_ghost_wait -= delta
		else:
			_boss_ghost_value = maxf(_boss_ghost_value - GHOST_SPEED * 3.0 * delta, hp)
	else:
		_boss_ghost_value = hp
	_boss_ghost.value = _boss_ghost_value
	if _boss_hide_t > 0.0:
		_boss_hide_t -= delta
		_boss_bar.modulate.a = clampf(_boss_hide_t, 0.0, 1.0)
		if _boss_hide_t <= 0.0:
			hide_boss_bar()


func _on_health_changed(current: float, maximum: float) -> void:
	if current < _current:
		_ghost_wait = GHOST_DELAY
	_current = current
	_maximum = maximum
	_bar.max_value = maximum
	_ghost.max_value = maximum
	_bar.value = current
	_hp_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _on_potions_changed(count: int, capacity: int) -> void:
	_potion_label.text = "%d / %d" % [count, capacity]
	_potion_pulse = 0.3


func _process(delta: float) -> void:
	_t += delta
	# Ghost bar trails behind damage; follows heals immediately.
	if _ghost_value > _current:
		if _ghost_wait > 0.0:
			_ghost_wait -= delta
		else:
			_ghost_value = maxf(_ghost_value - GHOST_SPEED * delta, _current)
	else:
		_ghost_value = _current
	_ghost.value = _ghost_value

	_potion_pulse = maxf(_potion_pulse - delta, 0.0)
	var pulse := 1.0 + _potion_pulse * 0.6
	_potion_row.scale = Vector2(pulse, pulse)

	_update_boss_bar(delta)
	_mode_pulse = maxf(_mode_pulse - delta, 0.0)
	var mode_scale := 1.0 + _mode_pulse * 0.6
	_mode_label.pivot_offset = Vector2(0, _mode_label.size.y * 0.5)
	_mode_label.scale = Vector2(mode_scale, mode_scale)

	if _player == null:
		return
	_update_status()


func _update_status() -> void:
	var regen := _player.regen
	var regenerating := regen.is_active()
	# Subtle health-bar tint + green border shimmer while regenerating.
	_fill_box.bg_color = FILL_REGEN.lerp(REGEN_GREEN, 0.15 + 0.1 * sin(_t * 4.0)) if regenerating else FILL
	if _player.health.is_dead:
		_set_status("", Color.WHITE)
	elif _player.combat_state.is_boss_active():
		_set_status("BOSS FIGHT · no auto-heal", Color("#ff6b6b"))
	elif _player.combat_state.in_combat:
		_set_status("IN COMBAT", Color("#ff9a7a"))
	elif regenerating:
		_set_status("+ Regenerating", REGEN_GREEN)
	elif regen.state == HealthRegen.State.PENDING:
		var left := maxf(regen.delay - regen.time_out_of_combat, 0.0)
		_set_status("Healing in %.0fs…" % ceilf(left), Color(1, 1, 1, 0.55))
	else:
		_set_status("", Color.WHITE)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _flat(color: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(2)
	return box
