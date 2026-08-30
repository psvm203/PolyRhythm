extends SceneTree

const DialogueScene = preload("res://level/ui/dialogue_overlay.tscn")

var _failures: int = 0
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := DialogueScene.instantiate()
	root.add_child(overlay)
	var finished := [false]
	overlay.dialogue_finished.connect(func() -> void: finished[0] = true)
	var lines: Array[String] = ["첫 문장", "두 번째 문장"]
	overlay.play(lines, "GUIDE")
	_expect(overlay.visible, "overlay opens")
	_expect(overlay.speaker_label.text == "GUIDE", "speaker is applied")
	_expect(overlay.dialogue_label.text == "첫 문장", "first line is shown")
	overlay.advance()
	_expect(overlay.dialogue_label.visible_characters == -1, "first input completes typing")
	overlay.advance()
	_expect(overlay.dialogue_label.text == "두 번째 문장", "second line is shown")
	overlay.advance()
	overlay.advance()
	_expect(finished[0] and not overlay.visible, "dialogue finishes and closes")
	finished[0] = false
	overlay.play(lines, "GUIDE")
	overlay.skip()
	_expect(finished[0] and not overlay.visible, "skip finishes the entire dialogue")
	overlay.queue_free()
	if _failures == 0:
		print("Dialogue tests passed: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("Dialogue tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	push_error(label)
