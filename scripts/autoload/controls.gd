extends Node
## Configures the Godot InputMap at startup (keyboard + controller), following spec section 15.
## Code-driven so the bindings are readable in one place and easy to remap later.

const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const JUMP := "jump"
const DODGE := "dodge"
const ATTACK := "attack"
const CHARGE := "charge"
const SPECIAL := "special"
const SWITCH_MODE := "switch_mode"
const POTION := "potion"
const INTERACT := "interact"
const PAUSE := "pause"


func _ready() -> void:
	_bind(MOVE_LEFT, [_key(KEY_A), _key(KEY_LEFT), _button(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind(MOVE_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _button(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind(JUMP, [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_bind(DODGE, [_key(KEY_SHIFT), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_bind(ATTACK, [_key(KEY_J), _button(JOY_BUTTON_X)])
	_bind(CHARGE, [_key(KEY_K), _button(JOY_BUTTON_Y)])
	_bind(SPECIAL, [_key(KEY_L), _button(JOY_BUTTON_B)])
	_bind(SWITCH_MODE, [_key(KEY_TAB), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_bind(POTION, [_key(KEY_H), _button(JOY_BUTTON_DPAD_DOWN)])
	_bind(INTERACT, [_key(KEY_E), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_bind(PAUSE, [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])

	# Menus also accept W/S, so keyboard players are never stuck.
	_add_extra("ui_up", _key(KEY_W))
	_add_extra("ui_down", _key(KEY_S))
	_add_extra("ui_left", _key(KEY_A))
	_add_extra("ui_right", _key(KEY_D))
	_add_extra("ui_accept", _key(KEY_J))
	_add_extra("ui_cancel", _key(KEY_ESCAPE))


func is_interact_pressed() -> bool:
	return Input.is_action_just_pressed(INTERACT)


func _bind(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


func _add_extra(action: String, event: InputEvent) -> void:
	if InputMap.has_action(action):
		InputMap.action_add_event(action, event)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	return event


func _button(code: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	return event


func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event
