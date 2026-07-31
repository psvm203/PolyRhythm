extends Node2D

@export var seconds_per_edge: float = 0.5
@export var radius: float = 10.0
@export var color := Color.WHITE

var _path: PackedVector2Array
var _elapsed: float = 0.0


func setup(path: PackedVector2Array) -> void:
	_path = path
	_elapsed = 0.0
	if _path.size() > 0:
		position = _path[0]


func get_elapsed() -> float:
	return _elapsed


func get_velocity() -> Vector2:
	if _path.size() < 2:
		return Vector2.ZERO
	var last_index := _path.size() - 1
	var progress := _elapsed / seconds_per_edge
	if progress >= last_index:
		return Vector2.ZERO
	var segment_index := int(progress)
	var start := _path[segment_index]
	var end := _path[segment_index + 1]
	return (end - start) / seconds_per_edge


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


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
