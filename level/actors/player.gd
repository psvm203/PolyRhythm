extends Node2D

@export var seconds_per_edge: float = 0.5

var _path: PackedVector2Array
var _elapsed: float = 0.0


func setup(path: PackedVector2Array) -> void:
	_path = path
	_elapsed = 0.0
	if _path.size() > 0:
		position = _path[0]


func get_elapsed() -> float:
	return _elapsed


func _process(delta: float) -> void:
	var last_index := _path.size() - 1
	if _path.size() < 2:
		return
	_elapsed += delta
	var progress := _elapsed / seconds_per_edge
	if progress >= last_index:
		position = _path[last_index]
		return
	var segment_index := int(progress)
	var segment_progress := progress - segment_index
	position = _path[segment_index].lerp(_path[segment_index + 1], segment_progress)
