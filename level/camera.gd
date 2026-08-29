extends Camera2D

@export var smoothing_speed: float = 5.0

var _target: Node2D


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	make_current()


func setup(target: Node2D, _polygon_centers: PackedVector2Array) -> void:
	_target = target
	global_position = _tracking_position()
	reset_smoothing()


func _process(_delta: float) -> void:
	if _target == null:
		return
	if _target.is_completed():
		return
	global_position = _tracking_position()


func _tracking_position() -> Vector2:
	if _target == null:
		return global_position
	var center: Vector2 = _target.get_target_polygon_center()
	return _target.to_global(center - _target.position)
