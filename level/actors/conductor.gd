extends Node

signal judged(result: String, polygon_index: int)

@export var bpm: float = 120.0
# Judgment windows (seconds relative to landing moment).
# ±25ms = Perfect, ±50ms = Fast/Slow outer limit, beyond = Too Fast / Too Slow
@export var perfect_window_sec: float = 0.025
@export var edge_window_sec: float = 0.050

@onready var rotator: Node = $"../Rotator"

var beat_duration: float = 0.5
var paused: bool = true
var scheduled_judgment_times: PackedFloat32Array = PackedFloat32Array()
var game_time: float = 0.0
var _time_in_polygon: float = 0.0
var _judged: bool = false
var _tap_buffer: bool = false


func setup(scheduled_times: PackedFloat32Array) -> void:
	beat_duration = 60.0 / maxf(bpm, 0.0001)
	scheduled_judgment_times = scheduled_times
	game_time = 0.0
	_time_in_polygon = 0.0
	_judged = false
	_tap_buffer = false
	if rotator != null and scheduled_judgment_times.size() > 0:
		var initial_duration: float = maxf(scheduled_judgment_times[0], 0.05)
		rotator.set_transition_duration(initial_duration)


func _process(delta: float) -> void:
	if rotator == null:
		return
	if rotator.is_completed():
		return
	if paused:
		return
	game_time += delta
	if not rotator.is_fly_in_complete():
		return
	var polygon_period: float = maxf(rotator.transition_duration, 0.05)
	_time_in_polygon += delta
	# Process the pending tap exactly at the landing moment.
	if _tap_buffer:
		_tap_buffer = false
		var time_to_alignment: float = polygon_period - _time_in_polygon
		# positive = before landing, negative = after landing
		if time_to_alignment > edge_window_sec:
			# Tapped too early (>50ms before landing): no judgment, polygon continues.
			_emit_result("Too Fast", rotator.current_index)
			return
		elif time_to_alignment >= perfect_window_sec:
			# 25-50ms before landing: Fast (accepted)
			_emit_result("Fast", rotator.current_index)
			_judged = true
			rotator.snap_to_target()
			_advance_polygon()
			return
		elif time_to_alignment >= -perfect_window_sec:
			# Within ±25ms of landing: Perfect
			_emit_result("Perfect", rotator.current_index)
			_judged = true
			rotator.snap_to_target()
			_advance_polygon()
			return
		elif time_to_alignment >= -edge_window_sec:
			# 25-50ms after landing: Slow (accepted)
			_emit_result("Slow", rotator.current_index)
			_judged = true
			rotator.snap_to_target()
			_advance_polygon()
			return
		else:
			# Tapped too late (>50ms after landing): failure
			_emit_result("Too Slow", rotator.current_index)
			_judged = true
			_advance_polygon()
			return
	if _time_in_polygon >= polygon_period:
		if not _judged:
			_emit_result("Too Slow", rotator.current_index)
		_advance_polygon()


func _unhandled_input(event: InputEvent) -> void:
	if rotator == null:
		return
	if rotator.is_completed():
		return
	if paused:
		return
	if _judged:
		return
	if event.is_action_pressed("tap"):
		# Just buffer the tap; it will be judged at the landing moment in _process.
		_tap_buffer = true


func _advance_polygon() -> void:
	if rotator.is_completed():
		return
	_tap_buffer = false
	var next_index: int = rotator.current_index + 1
	if next_index < scheduled_judgment_times.size():
		var scheduled: float = scheduled_judgment_times[next_index]
		var duration: float = maxf(scheduled - game_time, 0.05)
		rotator.set_transition_duration(duration)
	_time_in_polygon = 0.0
	_judged = false
	rotator.advance_to_next()


func _emit_result(result: String, polygon_index: int) -> void:
	print("Polygon %d: %s" % [polygon_index + 1, result])
	judged.emit(result, polygon_index)
