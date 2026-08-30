extends Node

signal judged(result: String, polygon_index: int)

# Judgment timing is intentionally biased slightly after the visual landing.
@export var perfect_window_sec: float = 0.025
@export var early_window_sec: float = 0.050
@export var late_window_sec: float = 0.100
@export var judgment_offset_sec: float = 0.050

@onready var rotator: Node = $"../Rotator"

var paused: bool = true
var scheduled_judgment_times: PackedFloat32Array = PackedFloat32Array()
var game_time: float = 0.0
var _judged: bool = false
var _started_at_usec: int = 0
var _paused_at_usec: int = 0
var _pending_result: String = ""
# Tests can provide a deterministic microsecond clock; gameplay uses the engine clock.
var time_source_usec: Callable


func setup(scheduled_times: PackedFloat32Array) -> void:
	scheduled_judgment_times = scheduled_times
	game_time = 0.0
	_judged = false
	_started_at_usec = 0
	_paused_at_usec = 0
	_pending_result = ""
	if rotator != null and scheduled_judgment_times.size() > 0:
		var initial_duration: float = maxf(scheduled_judgment_times[0], 0.05)
		rotator.set_transition_duration(initial_duration)


func start() -> void:
	game_time = 0.0
	_started_at_usec = _now_usec()
	paused = false
	_paused_at_usec = 0


func pause_clock() -> void:
	if paused:
		return
	game_time = _get_game_time()
	_paused_at_usec = _now_usec()
	paused = true


func resume_clock() -> void:
	if _started_at_usec == 0:
		return
	if _paused_at_usec > 0:
		_started_at_usec += _now_usec() - _paused_at_usec
	_paused_at_usec = 0
	paused = false


func _process(_delta: float) -> void:
	if rotator == null:
		return
	if rotator.is_completed():
		return
	if paused:
		return
	game_time = _get_game_time()
	if rotator.current_index >= scheduled_judgment_times.size():
		return
	var scheduled: float = get_judgment_time(scheduled_judgment_times[rotator.current_index])
	if not _pending_result.is_empty() and game_time >= scheduled:
		var result := _pending_result
		_pending_result = ""
		_accept_judgment(result)
		return
	# Keep the late half of the judgment window open before declaring a miss.
	if not _judged and is_miss_due(game_time, scheduled):
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
		game_time = _get_game_time()
		if rotator.current_index >= scheduled_judgment_times.size():
			return
		var scheduled: float = get_judgment_time(scheduled_judgment_times[rotator.current_index])
		var timing_delta: float = game_time - scheduled
		var result := classify_timing_delta(timing_delta)
		if result == "Too Fast":
			_emit_result("Too Fast", rotator.current_index)
			return
		if result == "Too Slow":
			_emit_result("Too Slow", rotator.current_index)
			_advance_polygon()
		elif should_defer_judgment(timing_delta, result):
			# Preserve the early hit, but show it only when the polygon actually lands.
			_judged = true
			_pending_result = result
		else:
			_accept_judgment(result)


func classify_timing_delta(timing_delta: float) -> String:
	if timing_delta < -early_window_sec:
		return "Too Fast"
	if timing_delta < -perfect_window_sec:
		return "Fast"
	if timing_delta <= perfect_window_sec:
		return "Perfect"
	if timing_delta <= late_window_sec:
		return "Slow"
	return "Too Slow"


func is_miss_due(current_time: float, scheduled_time: float) -> bool:
	return current_time > scheduled_time + late_window_sec


func get_judgment_time(visual_landing_time: float) -> float:
	return visual_landing_time + judgment_offset_sec


func should_defer_judgment(timing_delta: float, result: String) -> bool:
	return timing_delta < 0.0 and result != "Too Fast" and result != "Too Slow"


func _accept_judgment(result: String) -> void:
	_judged = true
	_emit_result(result, rotator.current_index)
	rotator.snap_to_target()
	_advance_polygon()


func _get_game_time() -> float:
	if _started_at_usec == 0:
		return 0.0
	if paused and _paused_at_usec > 0:
		return game_time
	return float(_now_usec() - _started_at_usec) / 1_000_000.0


func _now_usec() -> int:
	if time_source_usec.is_valid():
		return int(time_source_usec.call())
	return Time.get_ticks_usec()


func _advance_polygon() -> void:
	if rotator.is_completed():
		return
	var next_index: int = rotator.current_index + 1
	if next_index < scheduled_judgment_times.size():
		var scheduled: float = scheduled_judgment_times[next_index]
		var duration: float = maxf(scheduled - game_time, 0.05)
		rotator.set_transition_duration(duration)
	_judged = false
	_pending_result = ""
	rotator.advance_to_next()


func _emit_result(result: String, polygon_index: int) -> void:
	print("Polygon %d: %s" % [polygon_index + 1, result])
	judged.emit(result, polygon_index)
