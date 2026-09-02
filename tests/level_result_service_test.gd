extends SceneTree

const RunStateScript = preload("res://level/run_state.gd")
const LevelResultServiceScript = preload("res://level/level_result_service.gd")

var _failures := 0


func _init() -> void:
	var run_state := RunStateScript.new()
	run_state.setup(2)
	run_state.apply_judgment("Perfect", 0, -4.0)
	run_state.apply_judgment("Slow", 1, 8.0)
	var result := LevelResultServiceScript.build(run_state, true, 3, false, 128.0, 99)
	var metadata: Dictionary = result["trace_metadata"]
	_expect(result["rank"] == "A", "rank is derived from the completed run")
	_expect(result["stats"]["score"] == 1700, "snapshot is preserved")
	_expect(metadata["stage"] == 3 and metadata["bpm"] == 128.0, "level identity is recorded")
	_expect(metadata["resolved_notes"] == 2 and metadata["total_notes"] == 2, "note counts come from the snapshot")
	var failed := LevelResultServiceScript.build(run_state, false, 1, true, 121.9, 2)
	_expect(failed["rank"] == "F", "incomplete runs receive an F rank")
	_expect(failed["trace_metadata"]["custom_level"], "custom level context is recorded")
	if _failures == 0:
		print("Level result service tests passed: 6 assertions")
		quit(0)
	else:
		push_error("Level result service tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(label)
