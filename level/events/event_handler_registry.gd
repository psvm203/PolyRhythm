class_name EventHandlerRegistry
extends RefCounted

const HANDLERS := {
	"boss_guard": {
		"requires_perfect": true,
		"success_label": "Perfect",
		"failure_label": "BLOCKED",
	},
	"samurai_split": {
		"cue_label": "HEX SPLIT",
	},
	"time_stop": {
		"requires_perfect": true,
		"success_label": "TIME BREAK",
		"failure_label": "TIME LOST",
	},
}

const JUDGMENT_PRIORITY := ["time_stop", "boss_guard"]


static func resolve_judgment(event_system: RefCounted, polygon_index: int, result: String) -> Dictionary:
	for event_name in JUDGMENT_PRIORITY:
		if not event_system.occurs(event_name, polygon_index):
			continue
		var handler: Dictionary = HANDLERS[event_name]
		var successful := result == "Perfect"
		return {
			"event_name": event_name,
			"guarded": true,
			"result": result if successful or result == "Too Fast" else "Too Slow",
			"display_result": handler["success_label"] if successful else handler["failure_label"] if result != "Too Fast" else result,
		}
	return {
		"event_name": "",
		"guarded": false,
		"result": result,
		"display_result": result,
	}


static func cue(event_system: RefCounted, polygon_index: int) -> String:
	for event_name in HANDLERS:
		if event_system.occurs(event_name, polygon_index):
			return String(HANDLERS[event_name].get("cue_label", ""))
	return ""


static func unknown_event_names(definitions: Array) -> PackedStringArray:
	var unknown := PackedStringArray()
	for definition in definitions:
		if not definition is Dictionary:
			continue
		var event_name := str(definition.get("name", ""))
		if not event_name.is_empty() and not HANDLERS.has(event_name) and not unknown.has(event_name):
			unknown.append(event_name)
	return unknown
