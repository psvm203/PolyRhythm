extends Camera2D

@export var look_ahead_distance: float = 80.0
@export var min_velocity_for_look_ahead: float = 1.0
@export var smoothing_speed: float = 5.0

var _target: Node2D


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	make_current()


func setup(target: Node2D) -> void:
	_target = target
	global_position = target.global_position
	reset_smoothing()


func _process(_delta: float) -> void:
	if _target == null:
		return
	var look_ahead := Vector2.ZERO
	if _target.has_method("get_velocity"):
		var velocity: Vector2 = _target.get_velocity()
		if velocity.length() > min_velocity_for_look_ahead:
			look_ahead = velocity.normalized() * look_ahead_distance
	global_position = _target.global_position + look_ahead
