extends SceneTree

const ManagerScript = preload("res://main/input_device_manager.gd")

var _failures := 0


func _init() -> void:
	_expect(ManagerScript.classify_device_name("Xbox Wireless Controller") == "xbox", "Xbox devices are classified")
	_expect(ManagerScript.classify_device_name("DualSense Wireless Controller") == "playstation", "PlayStation devices are classified")
	_expect(ManagerScript.classify_device_name("Nintendo Switch Pro Controller") == "nintendo", "Nintendo devices are classified")
	_expect(ManagerScript.classify_device_name("USB Gamepad") == "generic", "unknown devices use generic prompts")
	var manager := ManagerScript.new()
	var face_button := InputEventJoypadButton.new()
	face_button.pressed = true
	face_button.button_index = JOY_BUTTON_A
	_expect(manager.is_play_input(face_button), "face buttons trigger gameplay")
	face_button.button_index = JOY_BUTTON_START
	_expect(not manager.is_play_input(face_button), "Start is reserved from gameplay")
	_expect(manager.is_pause_input(face_button), "Start opens pause")
	var trigger := InputEventJoypadMotion.new()
	trigger.device = 2
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 0.8
	manager._input(trigger)
	_expect(manager.is_play_input(trigger), "trigger threshold creates one gameplay input")
	_expect(not manager.is_play_input(trigger), "held trigger does not repeat")
	_expect(ManagerScript.rumble_pattern("Perfect") == Vector3(0.18, 0.05, 0.06), "Perfect uses its haptic pattern")
	_expect(ManagerScript.rumble_pattern("unknown") == Vector3.ZERO, "unknown haptic patterns are safe")
	manager.free()
	if _failures == 0:
		print("Input device manager tests passed: 11 assertions")
		quit(0)
	else:
		push_error("Input device manager tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
