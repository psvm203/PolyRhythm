class_name JudgmentPipeline
extends RefCounted

var perfect_window_sec := 0.025
var early_window_sec := 0.050
var late_window_sec := 0.100


func configure(perfect: float, early: float, late: float) -> void:
	perfect_window_sec = maxf(perfect, 0.0)
	early_window_sec = maxf(early, perfect_window_sec)
	late_window_sec = maxf(late, perfect_window_sec)


func evaluate(input_time_sec: float, center_time_sec: float) -> Dictionary:
	var delta := input_time_sec - center_time_sec
	var result := classify_delta(delta)
	return {
		"input_time_sec": input_time_sec,
		"center_time_sec": center_time_sec,
		"delta_sec": delta,
		"delta_ms": delta * 1000.0,
		"result": result,
		"defer_until_contact": should_defer(delta, result),
		"advance_note": result != "Too Fast",
	}


func classify_delta(delta_sec: float) -> String:
	if delta_sec < -early_window_sec:
		return "Too Fast"
	if delta_sec < -perfect_window_sec:
		return "Fast"
	if delta_sec <= perfect_window_sec:
		return "Perfect"
	if delta_sec <= late_window_sec:
		return "Slow"
	return "Too Slow"


func is_miss_due(current_time_sec: float, center_time_sec: float) -> bool:
	return current_time_sec > center_time_sec + late_window_sec


func should_defer(delta_sec: float, result: String) -> bool:
	return delta_sec < 0.0 and result != "Too Fast" and result != "Too Slow"
