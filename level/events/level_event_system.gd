class_name LevelEventSystem
extends RefCounted

var _definitions: Dictionary = {}
var _targets: Dictionary = {}


func setup(definitions: Array) -> void:
	_definitions.clear()
	_targets.clear()
	for definition in definitions:
		if definition is Dictionary and not str(definition.get("name", "")).is_empty():
			var name := str(definition["name"])
			_definitions[name] = (definition as Dictionary).duplicate(true)
			var targets := {}
			var configured_targets: Variant = definition.get("at", [])
			if configured_targets is Array:
				for polygon_number in configured_targets:
					var target := _safe_side_or_index(polygon_number)
					if target > 0:
						targets[target] = true
			_targets[name] = targets


func has_event(name: String) -> bool:
	return not definition(name).is_empty()


func occurs(name: String, polygon_index: int) -> bool:
	return _targets.get(name, {}).has(polygon_index + 1)


func transform_sequence(sequence: Array[int]) -> Array[int]:
	var transformed: Array[int] = []
	var remapped_targets := {}
	for name in _definitions:
		remapped_targets[name] = {}
	for original_index in sequence.size():
		var polygon_number := original_index + 1
		var replacement: Array = []
		for name in _definitions:
			if not _targets[name].has(polygon_number):
				continue
			remapped_targets[name][transformed.size() + 1] = true
			var configured: Variant = _definitions[name].get("replace_with", [])
			var required_sides := _safe_side_or_index(_definitions[name].get("when_sides", 0))
			if configured is Array and not configured.is_empty() and (required_sides <= 0 or sequence[original_index] == required_sides):
				for sides in configured:
					var side_count := _safe_side_or_index(sides)
					if side_count >= 3 and side_count <= 12:
						replacement.append(side_count)
		if replacement.is_empty():
			transformed.append(sequence[original_index])
		else:
			for sides in replacement:
				transformed.append(int(sides))
	_targets = remapped_targets
	return transformed


func value(name: String, key: String, fallback: Variant) -> Variant:
	return definition(name).get(key, fallback)


func definition(name: String) -> Dictionary:
	return _definitions.get(name, {})


func _safe_side_or_index(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and (value as String).is_valid_int():
		return (value as String).to_int()
	return 0
