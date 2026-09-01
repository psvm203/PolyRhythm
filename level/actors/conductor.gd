extends Node

const PlayInputScript = preload("res://main/play_input.gd")

signal judged(result: String, polygon_index: int, timing_delta_ms: float)

# The judgment center matches the visual moment when the polygon edges meet.
@export var perfect_window_sec: float = 0.025
@export var early_window_sec: float = 0.050
@export var late_window_sec: float = 0.100
@export var judgment_offset_sec: float = 0.0
@export var detailed_timing_logs: bool = true
@export var contact_threshold_px: float = 0.5

@onready var rotator: Node = $"../Rotator"

var paused: bool = true
var scheduled_judgment_times: PackedFloat32Array = PackedFloat32Array()
var game_time: float = 0.0
var _judged: bool = false
var _started_at_usec: int = 0
var _paused_at_usec: int = 0
var _pending_result: String = ""
var _pending_timing_delta: float = 0.0
var _last_logged_contact_index: int = -1
var _observed_contact_times: Dictionary = {}
# Tests can provide a deterministic microsecond clock; gameplay uses the engine clock.
var time_source_usec: Callable


func setup(scheduled_times: PackedFloat32Array) -> void:
	scheduled_judgment_times = scheduled_times
	game_time = 0.0
	_judged = false
	_started_at_usec = 0
	_paused_at_usec = 0
	_pending_result = ""
	_pending_timing_delta = 0.0
	_last_logged_contact_index = -1
	_observed_contact_times.clear()
	if rotator != null and scheduled_judgment_times.size() > 0:
		var initial_duration: float = maxf(scheduled_judgment_times[0], 0.05)
		rotator.set_transition_duration(initial_duration)
	if detailed_timing_logs:
		print(
			"[TIMING_SETUP] notes=%d perfect_ms=%.1f early_ms=%.1f late_ms=%.1f judgment_offset_ms=%.1f contact_threshold_px=%.2f"
			% [scheduled_judgment_times.size(), perfect_window_sec * 1000.0, early_window_sec * 1000.0, late_window_sec * 1000.0, judgment_offset_sec * 1000.0, contact_threshold_px],
		)


func start() -> void:
	game_time = 0.0
	_started_at_usec = _now_usec()
	paused = false
	_paused_at_usec = 0
	if detailed_timing_logs:
		print("[TIMING_START] clock_usec=%d" % _started_at_usec)


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
	_log_contact_if_reached()
	var scheduled: float = _current_judgment_center()
	if not _pending_result.is_empty() and _observed_contact_times.has(rotator.current_index):
		var result := _pending_result
		var pending_delta := _pending_timing_delta
		_pending_result = ""
		_accept_judgment(result, pending_delta)
		return
	# Keep the late half of the judgment window open before declaring a miss.
	if not _judged and is_miss_due(game_time, scheduled):
		_emit_result("Too Slow", rotator.current_index, game_time - scheduled)
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
	if PlayInputScript.is_pressed(event):
		game_time = _get_game_time()
		if rotator.current_index >= scheduled_judgment_times.size():
			return
		_log_contact_if_reached()
		var visual_schedule: float = scheduled_judgment_times[rotator.current_index]
		var scheduled: float = _current_judgment_center()
		var timing_delta: float = game_time - scheduled
		var result := classify_timing_delta(timing_delta)
		_log_input_timing(visual_schedule, scheduled, timing_delta, result)
		if result == "Too Fast":
			_emit_result("Too Fast", rotator.current_index, timing_delta)
			return
		if result == "Too Slow":
			_emit_result("Too Slow", rotator.current_index, timing_delta)
			_advance_polygon()
		elif should_defer_judgment(timing_delta, result):
			# Preserve the early hit, but show it only when the polygon actually lands.
			_judged = true
			_pending_result = result
			_pending_timing_delta = timing_delta
		else:
			_accept_judgment(result, timing_delta)


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


func _accept_judgment(result: String, timing_delta: float) -> void:
	_judged = true
	_emit_result(result, rotator.current_index, timing_delta)
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
	_pending_timing_delta = 0.0
	rotator.advance_to_next()


func _emit_result(result: String, polygon_index: int, timing_delta: float = 0.0) -> void:
	if detailed_timing_logs:
		var visual_time := scheduled_judgment_times[polygon_index] if polygon_index < scheduled_judgment_times.size() else 0.0
		var judgment_time := (
			float(_observed_contact_times[polygon_index]) + judgment_offset_sec
			if _observed_contact_times.has(polygon_index)
			else get_judgment_time(visual_time)
		)
		print(
			"[JUDGMENT] polygon=%d result=%s game_ms=%.3f visual_delta_ms=%+.3f judgment_delta_ms=%+.3f"
			% [polygon_index + 1, result, game_time * 1000.0, (game_time - visual_time) * 1000.0, (game_time - judgment_time) * 1000.0],
		)
	judged.emit(result, polygon_index, timing_delta * 1000.0)


func _log_input_timing(visual_time: float, judgment_time: float, timing_delta: float, result: String) -> void:
	if not detailed_timing_logs:
		return
	var gap := _rotator_float(&"get_entrance_edge_gap", INF)
	var transition_elapsed := _rotator_float(&"get_transition_elapsed", 0.0)
	var transition_progress := _rotator_float(&"get_transition_progress", 0.0)
	var offset: Vector2 = rotator.get_current_offset() if rotator.has_method(&"get_current_offset") else Vector2.ZERO
	var alignment_deg := rad_to_deg(rotator.get_alignment_delta()) if rotator.has_method(&"get_alignment_delta") else 0.0
	print(
		"[TIMING_INPUT] polygon=%d result=%s game_ms=%.3f visual_ms=%.3f judgment_ms=%.3f visual_delta_ms=%+.3f judgment_delta_ms=%+.3f edge_gap_px=%.3f offset_px=(%.3f,%.3f) offset_length_px=%.3f angle_deg=%.3f alignment_deg=%+.3f transition_ms=%.3f progress=%.4f"
		% [rotator.current_index + 1, result, game_time * 1000.0, visual_time * 1000.0, judgment_time * 1000.0, (game_time - visual_time) * 1000.0, timing_delta * 1000.0, gap, offset.x, offset.y, offset.length(), rad_to_deg(rotator.angle), alignment_deg, transition_elapsed * 1000.0, transition_progress],
	)


func _log_contact_if_reached() -> void:
	if not detailed_timing_logs or rotator.current_index == _last_logged_contact_index:
		return
	if not rotator.has_method(&"get_entrance_edge_gap"):
		return
	if rotator.has_method(&"is_fly_in_complete") and not rotator.is_fly_in_complete():
		return
	var gap: float = rotator.get_entrance_edge_gap()
	if gap > contact_threshold_px:
		return
	_last_logged_contact_index = rotator.current_index
	_observed_contact_times[rotator.current_index] = game_time
	var visual_time: float = scheduled_judgment_times[rotator.current_index]
	var transition_elapsed := _rotator_float(&"get_transition_elapsed", 0.0)
	var offset: Vector2 = rotator.get_current_offset()
	print(
		"[POLYGON_CONTACT] polygon=%d observed_game_ms=%.3f scheduled_visual_ms=%.3f contact_delta_ms=%+.3f edge_gap_px=%.3f offset_length_px=%.3f transition_ms=%.3f frame_usec=%d"
		% [rotator.current_index + 1, game_time * 1000.0, visual_time * 1000.0, (game_time - visual_time) * 1000.0, gap, offset.length(), transition_elapsed * 1000.0, _now_usec()],
	)


func _rotator_float(method: StringName, fallback: float) -> float:
	if rotator != null and rotator.has_method(method):
		return float(rotator.call(method))
	return fallback


func _current_judgment_center() -> float:
	var index: int = rotator.current_index
	if _observed_contact_times.has(index):
		return float(_observed_contact_times[index]) + judgment_offset_sec
	if rotator.has_method(&"get_transition_elapsed"):
		var elapsed: float = rotator.get_transition_elapsed()
		var duration: float = rotator.transition_duration
		return game_time + maxf(duration - elapsed, 0.0) + judgment_offset_sec
	return get_judgment_time(scheduled_judgment_times[index])
