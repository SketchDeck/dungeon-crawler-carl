class_name Hud
extends Control
## Heads-up display, drawn entirely in code so it matches the rest of the art.
## Shows health, lives, potions, the active combat mode, ability cooldowns, floor and room,
## automatic-healing status, boss health, and Dungeon AI announcements.

const PANEL_BG := Color(0.04, 0.03, 0.08, 0.78)
const GOLD := Color("#ffd166")
const WARM := Color("#ffb347")
const VIOLET := Color("#b57bff")
const HEART := Color("#ff5f6d")
const POTION := Color("#6dff9a")

var _player: Player = null
var _floor: int = 1
var _room_name: String = ""
var _room_state: String = "idle"
var _ghost_ratio: float = 1.0
var _time: float = 0.0
var _announce_queue: Array = []
var _announce: Dictionary = {}
var _announce_t: float = 0.0
var _boss: Node = null
var _boss_name: String = "BOSS"
var _boss_display: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(player: Player) -> void:
	_player = player


func set_floor(number: int) -> void:
	_floor = number


func set_room(room_name: String, state: String) -> void:
	_room_name = room_name
	_room_state = state


func show_boss(boss: Node) -> void:
	_boss = boss
	_boss_name = str(boss.call("display_name")).to_upper() if boss.has_method("display_name") else "BOSS"
	_boss_display = 1.0


func clear_boss() -> void:
	_boss = null


## Full announcement card (Dungeon AI achievements): kicker, headline, description, reward.
func announce(title: String, headline: String, description: String, reward: String) -> void:
	if headline == "" and description == "" and reward == "":
		return
	_announce_queue.append({"title": title, "headline": headline, "description": description, "reward": reward})
	Sfx.play("achievement")
	if _announce.is_empty():
		_next_announcement()


## Simple card for small notices (bonfire, upgrades).
func announce_simple(headline: String, description: String) -> void:
	announce("NOTICE", headline, description, "")


func hide_announcement() -> void:
	_announce_queue.clear()
	_announce.clear()


func _next_announcement() -> void:
	if _announce_queue.is_empty():
		_announce = {}
		return
	_announce = _announce_queue.pop_front()
	_announce_t = 0.0


func _process(delta: float) -> void:
	_time += delta
	_announce_t += delta
	if not _announce.is_empty() and _announce_t > 3.6:
		_next_announcement()
	if _player != null:
		var hp := float(_player.health.hp)
		if _ghost_ratio > hp / float(_player.health.max_hp):
			_ghost_ratio = move_toward(_ghost_ratio, hp / float(_player.health.max_hp), delta * 0.5)
		else:
			_ghost_ratio = hp / float(_player.health.max_hp)
	if _boss != null and is_instance_valid(_boss):
		var target := float(_boss.hp_state.hp) / float(_boss.max_hp)
		_boss_display = move_toward(_boss_display, target, delta * 0.6)
	elif _boss != null:
		_boss = null
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	_draw_status_panel()
	_draw_mode_and_abilities()
	_draw_boss_bar()
	_draw_announcement()
	_draw_footer()


func _panel(rect: Rect2, border: Color = Color(WARM, 0.45)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, rect)


func _text(pos: Vector2, s: String, size: int, color: Color = Color.WHITE, width: float = -1.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, align, width, size, color)


func _draw_status_panel() -> void:
	var panel := Rect2(14, 14, 316, 134)
	_panel(panel)
	_text(Vector2(28, 36), "FLOOR %d" % _floor, 14, GOLD)
	var room_color := Color("#c9b8d8")
	if _room_state == "combat":
		room_color = Color("#ff8a8a")
	elif _room_state == "cleared":
		room_color = Color("#8fffb0")
	_text(Vector2(96, 36), _room_name.to_upper(), 12, room_color, 224)

	var bar := Rect2(28, 46, 288, 22)
	draw_rect(Rect2(bar.position - Vector2(2, 2), bar.size + Vector2(4, 4)), Color(0, 0, 0, 0.7))
	draw_rect(bar, Color("#2a1d2e"))
	var hp := float(_player.health.hp)
	var max_hp := float(_player.health.max_hp)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_ghost_ratio, 0.0, 1.0), bar.size.y)), Color(1, 1, 1, 0.55))
	var fill_color := Color("#ff5f6d").lerp(Color("#ffb347"), clampf((ratio - 0.25) * 2.0, 0.0, 1.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill_color)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 6.0)), Color(1, 1, 1, 0.18))
	draw_rect(bar, Color(0, 0, 0, 0.8), false, 1.5)
	_text(Vector2(bar.position.x, bar.position.y + 16.0), "%d / %d HP" % [int(hp), int(max_hp)], 14,
		Color.WHITE, bar.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# Lives as hearts.
	for i in range(Config.LIVES):
		var center := Vector2(38.0 + i * 24.0, 88.0)
		var filled := i < Game.lives
		var c := HEART if filled else Color(0.25, 0.2, 0.28)
		draw_circle(center + Vector2(-4.0, -2.0), 5.0, c)
		draw_circle(center + Vector2(4.0, -2.0), 5.0, c)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-9.0, 0.0), center + Vector2(9.0, 0.0), center + Vector2(0.0, 10.0)]), c)
	_text(Vector2(112, 93), "LIVES", 11, Color("#9d8fae"))

	# Potions.
	var pot_x := 178.0
	var pot_count := Game.potions.count
	var pot_col := POTION if pot_count > 0 else Color(0.35, 0.4, 0.38)
	draw_circle(Vector2(pot_x + 8.0, 86.0), 7.0, pot_col.darkened(0.45))
	draw_circle(Vector2(pot_x + 8.0, 87.0), 5.2, pot_col)
	draw_rect(Rect2(pot_x + 6.0, 77.0, 4.0, 4.0), Color("#c9b28a"))
	_text(Vector2(pot_x + 22.0, 93.0), "x%d/%d" % [pot_count, Game.potions.capacity], 13, pot_col)

	# Automatic healing status.
	var status := ""
	var status_color := Color("#9d8fae")
	if CombatState.in_combat():
		status = "IN COMBAT - no regen"
		status_color = Color("#ff8a8a")
	elif CombatState.is_regen_active():
		var pulse := 0.6 + 0.4 * sin(_time * 6.0)
		status = "Regenerating..."
		status_color = Color(0.55, 1.0, 0.7, pulse)
	elif CombatState.is_regen_pending():
		status = "Healing soon..."
		status_color = Color(1.0, 0.85, 0.5, 0.7)
	elif _player.health.hp >= _player.health.max_hp:
		status = "Full health"
		status_color = Color("#8fffb0")
	_text(Vector2(28, 126), status, 12, status_color)


func _draw_mode_and_abilities() -> void:
	var vp := get_viewport_rect().size
	var donut := _player.mode == Player.Mode.DONUT
	var mode_color := VIOLET if donut else WARM
	var mode_rect := Rect2(14, vp.y - 66, 178, 52)
	_panel(mode_rect, Color(mode_color, 0.8))
	var label := "DONUT MODE" if donut else "CARL MODE"
	_text(Vector2(mode_rect.position.x + 14.0, mode_rect.position.y + 24.0), label, 17, mode_color)
	_text(Vector2(mode_rect.position.x + 14.0, mode_rect.position.y + 42.0),
		"Magic: ranged + burst" if donut else "Kicks: melee + knockback", 11, Color(1, 1, 1, 0.6))

	var slots := _ability_slots()
	var slot_w := 118.0
	var gap := 10.0
	var total := slots.size() * slot_w + (slots.size() - 1) * gap
	var x0 := (vp.x - total) * 0.5
	for i in range(slots.size()):
		var s: Dictionary = slots[i]
		var rect := Rect2(x0 + i * (slot_w + gap), vp.y - 70.0, slot_w, 56.0)
		_panel(rect, Color(mode_color, 0.55) if s.ready else Color(0.3, 0.3, 0.35, 0.6))
		var ratio := float(s.cooldown)
		if ratio > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, 4.0)), Color(0.1, 0.1, 0.12, 0.9))
		_text(Vector2(rect.position.x + 8.0, rect.position.y + 18.0), str(s.key), 12, GOLD)
		_text(Vector2(rect.position.x + 8.0, rect.position.y + 33.0), str(s.name), 13,
			Color.WHITE if s.ready else Color(0.6, 0.6, 0.65))
		var detail_color := Color(1, 1, 1, 0.5) if not s.locked else Color("#9aa4b2")
		_text(Vector2(rect.position.x + 8.0, rect.position.y + 48.0), str(s.detail), 10, detail_color)


func _ability_slots() -> Array:
	var combat := _player.combat
	if _player.mode == Player.Mode.CARL:
		var kick_stage := combat.kick.stage + 1 if combat.kick.window_left > 0.0 else 1
		var explosive_locked := not Save.has_ability("explosive_kick")
		return [
			{"key": "J", "name": "Kick", "detail": "Combo %d/3" % kick_stage, "cooldown": 0.0, "ready": true, "locked": false},
			{"key": "K", "name": "Power Kick", "detail": "Hold to charge", "cooldown": combat.charged_kick.cooldown_ratio(),
				"ready": combat.charged_kick.is_ready(), "locked": false},
			{"key": "L", "name": "Explosive", "detail": "Locked: beat Floor 1" if explosive_locked else "Blast on impact",
				"cooldown": combat.explosive_kick.cooldown_ratio(),
				"ready": combat.explosive_kick.is_ready() and not explosive_locked, "locked": explosive_locked},
		]
	var burst_locked := not Save.has_ability("area_burst")
	return [
		{"key": "J", "name": "Magic Bolt", "detail": "Fast, ranged", "cooldown": combat.bolt.cooldown_ratio(),
			"ready": combat.bolt.is_ready(), "locked": false},
		{"key": "K", "name": "Blast", "detail": "Hold to charge", "cooldown": combat.blast.cooldown_ratio(),
			"ready": combat.blast.is_ready(), "locked": false},
		{"key": "L", "name": "Area Burst", "detail": "Locked: beat Floor 2" if burst_locked else "Shockwave",
			"cooldown": combat.burst.cooldown_ratio(), "ready": combat.burst.is_ready() and not burst_locked,
			"locked": burst_locked},
	]


func _draw_boss_bar() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var vp := get_viewport_rect().size
	var w := 460.0
	var rect := Rect2((vp.x - w) * 0.5, 14.0, w, 46.0)
	_panel(rect, Color("#ff5f6d", 0.7))
	var phase := int(_boss.get("phase")) if _boss.get("phase") != null else 1
	_text(Vector2(rect.position.x + 12.0, rect.position.y + 18.0), _boss_name, 15, Color("#ffd1d6"))
	_text(Vector2(rect.end.x - 110.0, rect.position.y + 18.0), "PHASE %d" % phase, 13, Color("#ffb347"), 100,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var bar := Rect2(rect.position.x + 12.0, rect.position.y + 26.0, w - 24.0, 12.0)
	draw_rect(bar, Color("#24141c"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _boss_display, bar.size.y)), Color("#ff4d6d"))
	if phase >= 2:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _boss_display, 3.0)), Color(1, 0.8, 0.5, 0.5))
	var marker_x := bar.position.x + bar.size.x * 0.5
	draw_line(Vector2(marker_x, bar.position.y), Vector2(marker_x, bar.end.y), Color(1, 1, 1, 0.5), 1.5)
	draw_rect(bar, Color(0, 0, 0, 0.8), false, 1.5)


func _draw_announcement() -> void:
	if _announce.is_empty():
		return
	var vp := get_viewport_rect().size
	var t := _announce_t
	var slide := clampf(1.0 - t * 5.0, 0.0, 1.0) * 40.0
	var fade := clampf(3.6 - t, 0.0, 1.0)
	var w := 360.0
	var kicker := str(_announce.get("title", ""))
	var headline := str(_announce.get("headline", ""))
	var description := str(_announce.get("description", ""))
	var reward := str(_announce.get("reward", ""))
	var head_h := 38.0 if headline.length() > 28 else 20.0
	var h := 20.0 + 20.0 + head_h + (36.0 if description != "" else 0.0) + (24.0 if reward != "" else 0.0)
	# Below the boss bar while a boss fight is on, so the two never overlap.
	var top := 68.0 if (_boss != null and is_instance_valid(_boss)) else 14.0
	var rect := Rect2(vp.x - w - 16.0 + slide, top, w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.09, 0.92 * fade)
	sb.border_color = Color(GOLD, fade)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, rect)
	var x := rect.position.x + 14.0
	var y := rect.position.y + 20.0
	_text(Vector2(x, y), kicker, 11, Color(GOLD, fade), w - 28.0)
	y += 20.0
	draw_multiline_string(ThemeDB.fallback_font, Vector2(x, y), headline, HORIZONTAL_ALIGNMENT_LEFT,
		w - 28.0, 16, -1, Color(1, 0.96, 0.92, fade))
	y += head_h
	if description != "":
		draw_multiline_string(ThemeDB.fallback_font, Vector2(x, y), description, HORIZONTAL_ALIGNMENT_LEFT,
			w - 28.0, 12, -1, Color(0.85, 0.82, 0.9, fade * 0.95))
		y += 34.0
	if reward != "":
		draw_multiline_string(ThemeDB.fallback_font, Vector2(x, y), reward, HORIZONTAL_ALIGNMENT_LEFT,
			w - 28.0, 12, -1, Color("#8fffb0", fade))


func _draw_footer() -> void:
	var vp := get_viewport_rect().size
	_text(Vector2(vp.x - 210.0, vp.y - 12.0), "TAB switch  |  H potion  |  Esc pause", 11, Color(1, 1, 1, 0.45), 200,
		HORIZONTAL_ALIGNMENT_RIGHT)
