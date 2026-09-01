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
			for polygon_number in definition.get("at", []):
				targets[int(polygon_number)] = true
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
			var configured: Array = _definitions[name].get("replace_with", [])
			var required_sides := int(_definitions[name].get("when_sides", 0))
			if not configured.is_empty() and (required_sides <= 0 or sequence[original_index] == required_sides):
				replacement = configured
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
