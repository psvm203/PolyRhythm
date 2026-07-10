extends Node2D

@export var seconds_per_edge: float = 0.5
@export var radius: float = 10.0
@export var color := Color.WHITE

var _path: PackedVector2Array
var _segment_index: int = 0
var _segment_progress: float = 0.0


func setup(path: PackedVector2Array) -> void:
	_path = path
	_segment_index = 0
	_segment_progress = 0.0
	if _path.size() > 0:
		position = _path[0]


func _process(delta: float) -> void:
	var last_index := _path.size() - 1
	if _path.size() < 2 or _segment_index >= last_index:
		return
	_segment_progress += delta / seconds_per_edge
	while _segment_progress >= 1.0 and _segment_index < last_index:
		_segment_progress -= 1.0
		_segment_index += 1
	if _segment_index >= last_index:
		position = _path[last_index]
		return
	position = _path[_segment_index].lerp(_path[_segment_index + 1], _segment_progress)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
