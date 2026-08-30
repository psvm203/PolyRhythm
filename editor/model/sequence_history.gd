class_name SequenceHistory
extends RefCounted

var _entries: Array[Array] = []
var _cursor := -1


func reset(sequence: Array[int]) -> void:
	_entries = [sequence.duplicate()]
	_cursor = 0


func record(sequence: Array[int]) -> void:
	_entries.resize(_cursor + 1)
	_entries.append(sequence.duplicate())
	_cursor = _entries.size() - 1


func can_undo() -> bool:
	return _cursor > 0


func can_redo() -> bool:
	return _cursor < _entries.size() - 1


func undo() -> Array:
	_cursor -= 1
	return _entries[_cursor].duplicate()


func redo() -> Array:
	_cursor += 1
	return _entries[_cursor].duplicate()
