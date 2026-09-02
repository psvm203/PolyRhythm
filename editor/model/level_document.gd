class_name LevelDocument
extends RefCounted

const LevelDataScript = preload("res://level/data/level_data.gd")

var current_file_path := ""
var saved_signature := ""
var _data: Dictionary = {}


func replace(data: Dictionary) -> void:
	_data = data.duplicate(true)


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func signature() -> String:
	return LevelDataScript.to_yaml(_data)


func has_unsaved_changes() -> bool:
	return signature() != saved_signature


func mark_saved(path: String) -> void:
	current_file_path = path
	saved_signature = signature()


func restore_saved_state(path: String, signature_value: String) -> void:
	current_file_path = path
	saved_signature = signature_value
