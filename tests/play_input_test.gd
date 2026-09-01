extends SceneTree

const PlayInputScript = preload("res://main/play_input.gd")

var _failures := 0


func _init() -> void:
	_expect(PlayInputScript.is_pressed(_key(KEY_A)), "letter keys are accepted")
	_expect(PlayInputScript.is_pressed(_key(KEY_ENTER)), "Enter is accepted")
	_expect(PlayInputScript.is_pressed(_key(KEY_LEFT)), "navigation keys are accepted during play")
	_expect(not PlayInputScript.is_pressed(_key(KEY_ESCAPE)), "Escape is reserved for pause")
	var echo := _key(KEY_SPACE)
	echo.echo = true
	_expect(not PlayInputScript.is_pressed(echo), "key repeat is ignored")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	_expect(PlayInputScript.is_pressed(mouse), "left mouse input is preserved")
	if _failures == 0:
		print("Play input tests passed: 6 assertions")
		quit(0)
	else:
		push_error("Play input tests failed: %d assertion(s)" % _failures)
		quit(1)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	return event


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
