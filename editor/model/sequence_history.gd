class_name SequenceHistory
extends RefCounted

var _entries: Array[Variant] = []
var _cursor := -1


func reset(state: Variant) -> void:
	_entries = [state.duplicate(true)]
	_cursor = 0


func record(state: Variant) -> void:
	if _cursor >= 0 and _entries[_cursor] == state:
		return
	_entries.resize(_cursor + 1)
	_entries.append(state.duplicate(true))
	_cursor = _entries.size() - 1


func can_undo() -> bool:
	return _cursor > 0


func can_redo() -> bool:
	return _cursor < _entries.size() - 1


func undo() -> Variant:
	_cursor -= 1
	return _entries[_cursor].duplicate(true)


func redo() -> Variant:
	_cursor += 1
	return _entries[_cursor].duplicate(true)
