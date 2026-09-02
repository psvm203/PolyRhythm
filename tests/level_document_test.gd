extends SceneTree

const LevelDocumentScript = preload("res://editor/model/level_document.gd")

var _failures := 0


func _init() -> void:
	var document := LevelDocumentScript.new()
	var source := {"sides_sequence": [3, 4], "bpm": 120.0, "events": []}
	document.replace(source)
	document.mark_saved("res://level.yaml")
	_expect(not document.has_unsaved_changes(), "saved document starts clean")
	_expect(document.current_file_path == "res://level.yaml", "saved path is retained")
	source["sides_sequence"].append(5)
	_expect(document.snapshot()["sides_sequence"] == [3, 4], "source mutations cannot alter the document")
	var changed := document.snapshot()
	changed["bpm"] = 140.0
	document.replace(changed)
	_expect(document.has_unsaved_changes(), "content changes mark the document dirty")
	var exported := document.snapshot()
	exported["events"].append({"name": "boss_guard", "at": [1]})
	_expect(document.snapshot()["events"].is_empty(), "snapshots cannot mutate document state")
	document.restore_saved_state("user://preview.yaml", document.signature())
	_expect(not document.has_unsaved_changes(), "preview state can restore its saved baseline")
	if _failures == 0:
		print("Level document tests passed: 6 assertions")
		quit(0)
	else:
		push_error("Level document tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(label)
