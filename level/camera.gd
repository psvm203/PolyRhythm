extends Camera2D

@export var smoothing_speed: float = 5.0

var _target: Node2D
var _shape_centers: PackedVector2Array = PackedVector2Array()
var _shape_start_indices: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	make_current()


func setup(
		target: Node2D,
		shape_centers: PackedVector2Array,
		shape_start_indices: PackedInt32Array,
) -> void:
	_target = target
	_shape_centers = shape_centers
	_shape_start_indices = shape_start_indices
	global_position = _tracking_position()
	reset_smoothing()


func _process(_delta: float) -> void:
	if _target == null:
		return
	global_position = _tracking_position()


func _tracking_position() -> Vector2:
	var shape := _current_shape()
	if shape < 0:
		return _target.global_position
	var center := _shape_centers[shape]
	return _target.to_global(center - _target.position)


func _current_shape() -> int:
	if _shape_centers.is_empty() or _target.seconds_per_edge <= 0.0:
		return -1
	var segment := int(_target.get_elapsed() / _target.seconds_per_edge)
	var current := 0
	for index in _shape_start_indices.size():
		if _shape_start_indices[index] > segment:
			break
		current = index
	return mini(current, _shape_centers.size() - 1)
