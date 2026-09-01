extends Node

signal active_device_changed(device_type: String)
signal controller_connection_changed(device_id: int, connected: bool)

const SettingsStoreScript = preload("res://main/settings_store.gd")
const TRIGGER_THRESHOLD := 0.65
const STICK_ACTIVITY_THRESHOLD := 0.35

var active_device_type := "keyboard_mouse"
var active_joypad_id := -1
var _trigger_pressed: Dictionary = {}
var _trigger_pulses: Dictionary = {}


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_ensure_ui_actions()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_set_gamepad_active(event.device)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= STICK_ACTIVITY_THRESHOLD:
			_set_gamepad_active(motion.device)
		_track_trigger(motion)
	elif event is InputEventKey and event.pressed:
		_set_active_device("keyboard_mouse", -1)
	elif event is InputEventMouseButton and event.pressed:
		_set_active_device("keyboard_mouse", -1)
	elif event is InputEventMouseMotion and event.relative.length_squared() >= 4.0:
		_set_active_device("keyboard_mouse", -1)


func is_play_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return button.pressed and button.button_index != JOY_BUTTON_START
	if event is InputEventJoypadMotion:
		var event_id := event.get_instance_id()
		if _trigger_pulses.erase(event_id):
			return true
	return false


func is_pause_input(event: InputEvent) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START


func device_family(device_id: int = active_joypad_id) -> String:
	return classify_device_name(Input.get_joy_name(device_id) if device_id >= 0 else "")


static func classify_device_name(device_name: String) -> String:
	var name := device_name.to_lower()
	if "playstation" in name or "dualshock" in name or "dualsense" in name or "sony" in name:
		return "playstation"
	if "nintendo" in name or "switch" in name or "joy-con" in name:
		return "nintendo"
	if "xbox" in name or "xinput" in name:
		return "xbox"
	return "generic"


func confirm_prompt() -> String:
	match device_family():
		"playstation": return "×"
		"nintendo": return "B"
		"xbox": return "A"
	return "Button 0"


func cancel_prompt() -> String:
	match device_family():
		"playstation": return "○"
		"nintendo": return "A"
		"xbox": return "B"
	return "Button 1"


func pause_prompt() -> String:
	match device_family():
		"playstation": return "Options"
		"nintendo": return "+"
		"xbox": return "Menu"
	return "Start"


func play_prompt() -> String:
	return "아무 버튼" if active_device_type == "gamepad" else "아무 키"


func play_rumble(pattern_name: String) -> void:
	if active_joypad_id < 0:
		return
	var settings := SettingsStoreScript.load_settings()
	if not settings["controller_vibration_enabled"]:
		return
	var scale: float = settings["controller_vibration_strength"] / 100.0
	var pattern := rumble_pattern(pattern_name)
	Input.start_joy_vibration(active_joypad_id, pattern.x * scale, pattern.y * scale, pattern.z)


func stop_rumble() -> void:
	if active_joypad_id >= 0:
		Input.stop_joy_vibration(active_joypad_id)


static func rumble_pattern(pattern_name: String) -> Vector3:
	match pattern_name:
		"Perfect": return Vector3(0.18, 0.05, 0.06)
		"Fast", "Slow": return Vector3(0.08, 0.02, 0.04)
		"Too Fast", "Too Slow", "Miss", "BLOCKED", "TIME LOST": return Vector3(0.12, 0.35, 0.14)
		"TIME BREAK", "HEX SPLIT": return Vector3(0.25, 0.18, 0.10)
	return Vector3.ZERO


func _track_trigger(event: InputEventJoypadMotion) -> void:
	if event.axis != JOY_AXIS_TRIGGER_LEFT and event.axis != JOY_AXIS_TRIGGER_RIGHT:
		return
	var key := "%d:%d" % [event.device, event.axis]
	var was_pressed := bool(_trigger_pressed.get(key, false))
	var is_pressed_now := event.axis_value >= TRIGGER_THRESHOLD
	_trigger_pressed[key] = is_pressed_now
	if is_pressed_now and not was_pressed:
		_trigger_pulses[event.get_instance_id()] = true


func _set_gamepad_active(device_id: int) -> void:
	_set_active_device("gamepad", device_id)


func _set_active_device(device_type: String, device_id: int) -> void:
	if active_device_type == device_type and active_joypad_id == device_id:
		return
	active_device_type = device_type
	active_joypad_id = device_id
	active_device_changed.emit(device_type)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	controller_connection_changed.emit(device_id, connected)
	if not connected and device_id == active_joypad_id:
		stop_rumble()
		var remaining := Input.get_connected_joypads()
		remaining.erase(device_id)
		if remaining.is_empty():
			_set_active_device("keyboard_mouse", -1)
		else:
			_set_gamepad_active(int(remaining[0]))


func _ensure_ui_actions() -> void:
	_add_button_action(&"ui_accept", JOY_BUTTON_A)
	_add_button_action(&"ui_cancel", JOY_BUTTON_B)
	_add_button_action(&"ui_up", JOY_BUTTON_DPAD_UP)
	_add_button_action(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_button_action(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_button_action(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_axis_action(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis_action(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis_action(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis_action(&"ui_right", JOY_AXIS_LEFT_X, 1.0)


func _add_button_action(action: StringName, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _add_axis_action(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
