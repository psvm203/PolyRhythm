extends SceneTree

const EventHandlerRegistryScript = preload("res://level/events/event_handler_registry.gd")
const LevelEventSystemScript = preload("res://level/events/level_event_system.gd")

var _failures := 0


func _init() -> void:
	var events := LevelEventSystemScript.new()
	events.setup([
		{"name": "boss_guard", "at": [1]},
		{"name": "samurai_split", "at": [2]},
		{"name": "time_stop", "at": [3]},
	])
	events.transform_sequence([3, 6, 4])
	var blocked := EventHandlerRegistryScript.resolve_judgment(events, 0, "Slow")
	_expect(blocked["result"] == "Too Slow" and blocked["display_result"] == "BLOCKED", "guard handler blocks imprecise hits")
	var broken := EventHandlerRegistryScript.resolve_judgment(events, 2, "Perfect")
	_expect(broken["result"] == "Perfect" and broken["display_result"] == "TIME BREAK", "time handler labels a perfect break")
	var early := EventHandlerRegistryScript.resolve_judgment(events, 2, "Too Fast")
	_expect(early["result"] == "Too Fast" and early["display_result"] == "Too Fast", "early input remains retryable")
	_expect(EventHandlerRegistryScript.cue(events, 1) == "HEX SPLIT", "samurai handler exposes its cue")
	var normal := EventHandlerRegistryScript.resolve_judgment(events, 1, "Fast")
	_expect(not normal["guarded"] and normal["display_result"] == "Fast", "events without judgment rules preserve input")
	var unknown := EventHandlerRegistryScript.unknown_event_names([{"name": "new_spell"}, {"name": "boss_guard"}])
	_expect(unknown == PackedStringArray(["new_spell"]), "unknown event names are diagnosed")
	if _failures == 0:
		print("Event handler registry tests passed: 6 assertions")
		quit(0)
	else:
		push_error("Event handler registry tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(label)
