class_name RhythmClock
extends RefCounted

var time_source_usec: Callable
var start_usec: int = 0
var paused_at_usec: int = 0
var paused_total_usec: int = 0
var running: bool = false
var correction_usec: int = 0


func reset() -> void:
	start_usec = 0
	paused_at_usec = 0
	paused_total_usec = 0
	running = false
	correction_usec = 0


func start(at_usec: int = -1) -> void:
	start_usec = now_usec() if at_usec < 0 else at_usec
	paused_at_usec = 0
	paused_total_usec = 0
	correction_usec = 0
	running = true


func pause(at_usec: int = -1) -> void:
	if not running or paused_at_usec > 0:
		return
	paused_at_usec = now_usec() if at_usec < 0 else at_usec


func resume(at_usec: int = -1) -> void:
	if not running or paused_at_usec <= 0:
		return
	var resume_usec := now_usec() if at_usec < 0 else at_usec
	paused_total_usec += maxi(resume_usec - paused_at_usec, 0)
	paused_at_usec = 0


func elapsed_usec(at_usec: int = -1) -> int:
	if not running:
		return 0
	var sample_usec := paused_at_usec if paused_at_usec > 0 else (now_usec() if at_usec < 0 else at_usec)
	return maxi(sample_usec - start_usec - paused_total_usec + correction_usec, 0)


func elapsed_sec(at_usec: int = -1) -> float:
	return float(elapsed_usec(at_usec)) / 1_000_000.0


func is_paused() -> bool:
	return running and paused_at_usec > 0


func discipline_to(reference_sec: float, max_step_sec: float = 0.002, deadzone_sec: float = 0.004) -> float:
	if not running or is_paused():
		return 0.0
	var drift_sec := reference_sec - elapsed_sec()
	if absf(drift_sec) <= deadzone_sec:
		return drift_sec
	var adjustment_sec := clampf(drift_sec, -absf(max_step_sec), absf(max_step_sec))
	correction_usec += roundi(adjustment_sec * 1_000_000.0)
	return drift_sec


func now_usec() -> int:
	if time_source_usec.is_valid():
		return int(time_source_usec.call())
	return Time.get_ticks_usec()
