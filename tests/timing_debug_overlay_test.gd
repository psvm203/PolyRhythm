extends SceneTree

const DebugScene := preload("res://level/ui/timing_debug_overlay.tscn")

var _failures := 0


func _init() -> void:
	var overlay := DebugScene.instantiate()
	get_root().add_child(overlay)
	_expect(not overlay.visible, "debug overlay is hidden by default")
	overlay.toggle()
	_expect(overlay.visible, "debug overlay can be enabled")
	overlay.toggle()
	_expect(not overlay.visible, "debug overlay can be disabled")
	_expect(overlay.layer > 250, "debug overlay renders above gameplay UI")
	overlay.queue_free()
	if _failures > 0:
		push_error("Timing debug overlay tests failed: %d" % _failures)
		quit(1)
		return
	print("Timing debug overlay tests passed: 4 assertions")
	quit()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
