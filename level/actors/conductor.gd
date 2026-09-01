extends Node

const PlayInputScript = preload("res://main/play_input.gd")
const RhythmClockScript = preload("res://level/timing/rhythm_clock.gd")
const ContactSolverScript = preload("res://level/timing/contact_solver.gd")
const TimingTraceScript = preload("res://level/timing/timing_trace.gd")
const JudgmentPipelineScript = preload("res://level/timing/judgment_pipeline.gd")

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
var _clock = RhythmClockScript.new()
var timing_trace = TimingTraceScript.new()
var _judgment_pipeline = JudgmentPipelineScript.new()
var _pending_result: String = ""
var _pending_timing_delta: float = 0.0
var _last_logged_contact_index: int = -1
var _observed_contact_times: Dictionary = {}
var _previous_gap: float = INF
var _previous_gap_time: float = 0.0
var _previous_gap_index: int = -1
var audio_player: Node
var audio_start_offset_sec := 0.0
var audio_drift_sec := 0.0
# Tests can provide a deterministic microsecond clock; gameplay uses the engine clock.
var time_source_usec: Callable


func setup(scheduled_times: PackedFloat32Array) -> void:
	scheduled_judgment_times = scheduled_times
	game_time = 0.0
	_judged = false
	_sync_clock_source()
	_clock.reset()
	timing_trace.clear()
	_sync_judgment_pipeline()
	_pending_result = ""
	_pending_timing_delta = 0.0
	_last_logged_contact_index = -1
	_observed_contact_times.clear()
	_previous_gap = INF
	_previous_gap_time = 0.0
	_previous_gap_index = -1
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
	_sync_clock_source()
	_clock.start()
	paused = false
	if detailed_timing_logs:
		print("[TIMING_START] clock_usec=%d" % _clock.start_usec)


func pause_clock() -> void:
	if paused:
		return
	game_time = _get_game_time()
	_clock.pause()
	paused = true


func resume_clock() -> void:
	if not _clock.running:
		return
	_clock.resume()
	paused = false


func _process(_delta: float) -> void:
	if rotator == null:
		return
	if rotator.is_completed():
		return
	if paused:
		return
	_discipline_clock_to_audio()
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
		_resolve_overdue_notes()


func _unhandled_input(event: InputEvent) -> void:
	if rotator == null:
		return
	if rotator.is_completed():
		return
	if paused:
		return
	if _judged:
		return
	var input_manager := get_node_or_null("/root/InputDeviceManager")
	var gamepad_input := bool(input_manager.call("is_play_input", event)) if input_manager != null else false
	if PlayInputScript.is_pressed(event) or gamepad_input:
		game_time = _get_game_time()
		if rotator.current_index >= scheduled_judgment_times.size():
			return
		_log_contact_if_reached()
		var visual_schedule: float = scheduled_judgment_times[rotator.current_index]
		var scheduled: float = _current_judgment_center()
		_sync_judgment_pipeline()
		var evaluation: Dictionary = _judgment_pipeline.evaluate(game_time, scheduled)
		var timing_delta: float = evaluation["delta_sec"]
		var result: String = evaluation["result"]
		_record_input_trace(event, visual_schedule, scheduled, timing_delta, result)
		_log_input_timing(visual_schedule, scheduled, timing_delta, result)
		if result == "Too Fast":
			_emit_result("Too Fast", rotator.current_index, timing_delta)
			return
		if result == "Too Slow":
			_emit_result("Too Slow", rotator.current_index, timing_delta)
			_advance_polygon()
		elif bool(evaluation["defer_until_contact"]):
			# Preserve the early hit, but show it only when the polygon actually lands.
			_judged = true
			_pending_result = result
			_pending_timing_delta = timing_delta
		else:
			_accept_judgment(result, timing_delta)


func classify_timing_delta(timing_delta: float) -> String:
	_sync_judgment_pipeline()
	return _judgment_pipeline.classify_delta(timing_delta)


func is_miss_due(current_time: float, scheduled_time: float) -> bool:
	_sync_judgment_pipeline()
	return _judgment_pipeline.is_miss_due(current_time, scheduled_time)


func get_judgment_time(visual_landing_time: float) -> float:
	return visual_landing_time + judgment_offset_sec


func should_defer_judgment(timing_delta: float, result: String) -> bool:
	_sync_judgment_pipeline()
	return _judgment_pipeline.should_defer(timing_delta, result)


func _sync_judgment_pipeline() -> void:
	_judgment_pipeline.configure(perfect_window_sec, early_window_sec, late_window_sec)


func _accept_judgment(result: String, timing_delta: float) -> void:
	_judged = true
	_emit_result(result, rotator.current_index, timing_delta)
	rotator.snap_to_target()
	_advance_polygon()


func _get_game_time() -> float:
	_sync_clock_source()
	return _clock.elapsed_sec()


func _now_usec() -> int:
	_sync_clock_source()
	return _clock.now_usec()


func _sync_clock_source() -> void:
	_clock.time_source_usec = time_source_usec


func set_audio_reference(player: Node, start_offset_sec: float = 0.0) -> void:
	audio_player = player
	audio_start_offset_sec = maxf(start_offset_sec, 0.0)


func save_timing_trace(path: String, metadata: Dictionary = {}) -> Error:
	return timing_trace.save_json(path, metadata)


func _discipline_clock_to_audio() -> void:
	if audio_player == null or not audio_player.has_method(&"get_playback_position"):
		return
	if not bool(audio_player.get("playing")) or bool(audio_player.get("stream_paused")):
		return
	var relative_audio_sec := maxf(float(audio_player.call("get_playback_position")) - audio_start_offset_sec, 0.0)
	audio_drift_sec = _clock.discipline_to(relative_audio_sec)


func _resolve_overdue_notes() -> void:
	var safety := 0
	while not rotator.is_completed() and rotator.current_index < scheduled_judgment_times.size() and safety < 32:
		var center := _current_judgment_center()
		if not is_miss_due(game_time, center):
			break
		_emit_result("Too Slow", rotator.current_index, game_time - center)
		_advance_polygon()
		safety += 1


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
	if rotator.current_index == _last_logged_contact_index:
		return
	if not rotator.has_method(&"get_entrance_edge_gap"):
		return
	if rotator.has_method(&"is_fly_in_complete") and not rotator.is_fly_in_complete():
		_sample_contact_gap()
		return
	var gap: float = rotator.get_entrance_edge_gap()
	if _previous_gap_index != rotator.current_index:
		_previous_gap = INF
		_previous_gap_time = game_time
		_previous_gap_index = rotator.current_index
	if gap > contact_threshold_px:
		_previous_gap = gap
		_previous_gap_time = game_time
		return
	_last_logged_contact_index = rotator.current_index
	var contact_time := ContactSolverScript.interpolate_contact_time(
		_previous_gap_time,
		game_time,
		_previous_gap,
		gap,
		contact_threshold_px,
	)
	_observed_contact_times[rotator.current_index] = contact_time
	if not detailed_timing_logs:
		return
	var visual_time: float = scheduled_judgment_times[rotator.current_index]
	var transition_elapsed := _rotator_float(&"get_transition_elapsed", 0.0)
	var offset: Vector2 = rotator.get_current_offset()
	print(
		"[POLYGON_CONTACT] polygon=%d observed_game_ms=%.3f scheduled_visual_ms=%.3f contact_delta_ms=%+.3f edge_gap_px=%.3f offset_length_px=%.3f transition_ms=%.3f frame_usec=%d"
		% [rotator.current_index + 1, contact_time * 1000.0, visual_time * 1000.0, (contact_time - visual_time) * 1000.0, gap, offset.length(), transition_elapsed * 1000.0, _now_usec()],
	)


func _sample_contact_gap() -> void:
	if not rotator.has_method(&"get_entrance_edge_gap"):
		return
	_previous_gap = float(rotator.get_entrance_edge_gap())
	_previous_gap_time = game_time
	_previous_gap_index = rotator.current_index


func _rotator_float(method: StringName, fallback: float) -> float:
	if rotator != null and rotator.has_method(method):
		return float(rotator.call(method))
	return fallback


func _record_input_trace(
	event: InputEvent,
	visual_time: float,
	judgment_time: float,
	timing_delta: float,
	result: String,
) -> void:
	var index: int = rotator.current_index
	var observed_contact := float(_observed_contact_times[index]) if _observed_contact_times.has(index) else visual_time
	timing_trace.record_input({
		"event_received_usec": _now_usec(),
		"device": _input_device_name(event),
		"polygon_index": index,
		"game_time_sec": game_time,
		"visual_contact_sec": visual_time,
		"observed_contact_sec": observed_contact,
		"judgment_center_sec": judgment_time,
		"judgment_offset_ms": judgment_offset_sec * 1000.0,
		"timing_delta_ms": timing_delta * 1000.0,
		"result": result,
		"perfect_window_ms": perfect_window_sec * 1000.0,
		"early_window_ms": early_window_sec * 1000.0,
		"late_window_ms": late_window_sec * 1000.0,
		"fps": Engine.get_frames_per_second(),
		"frame_time_ms": get_process_delta_time() * 1000.0,
	})


func _input_device_name(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "gamepad"
	if event is InputEventMouseButton:
		return "mouse"
	if event is InputEventKey:
		return "keyboard"
	return "unknown"


func _current_judgment_center() -> float:
	var index: int = rotator.current_index
	if _observed_contact_times.has(index):
		return float(_observed_contact_times[index]) + judgment_offset_sec
	if rotator.has_method(&"get_transition_elapsed"):
		var elapsed: float = rotator.get_transition_elapsed()
		var duration: float = rotator.transition_duration
		return game_time + maxf(duration - elapsed, 0.0) + judgment_offset_sec
	return get_judgment_time(scheduled_judgment_times[index])
