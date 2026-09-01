extends SceneTree

const FocusCoordinatorScript = preload("res://main/focus_coordinator.gd")

var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	var first := Button.new()
	var slider := HSlider.new()
	var last := Button.new()
	first.name = "First"
	slider.name = "Slider"
	last.name = "Last"
	host.add_child(first)
	host.add_child(slider)
	host.add_child(last)
	var coordinator := FocusCoordinatorScript.new()
	host.add_child(coordinator)
	get_root().add_child(host)
	coordinator.refresh()

	_expect(first.focus_next == first.get_path_to(slider), "first control advances to slider")
	_expect(slider.focus_next == slider.get_path_to(last), "slider advances to last control")
	_expect(last.focus_next == last.get_path_to(first), "last control wraps to first")
	_expect(first.focus_previous == first.get_path_to(last), "first control wraps backward")

	coordinator.call("_set_mouse_focus_enabled", false)
	_expect(first.mouse_filter == Control.MOUSE_FILTER_IGNORE, "keyboard mode suppresses mouse focus")
	_expect(slider.mouse_filter == Control.MOUSE_FILTER_IGNORE, "keyboard mode suppresses slider hover")
	coordinator.call("_set_mouse_focus_enabled", true)
	_expect(first.mouse_filter == Control.MOUSE_FILTER_STOP, "mouse movement restores button input")
	_expect(slider.mouse_filter == Control.MOUSE_FILTER_STOP, "mouse movement restores slider input")

	host.queue_free()
	print("Focus coordinator tests passed: %d assertions" % _assertions)
	quit()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	push_error("Assertion failed: %s" % message)
	quit(1)
