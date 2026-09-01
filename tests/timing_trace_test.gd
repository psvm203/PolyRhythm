extends SceneTree

const TimingTraceScript = preload("res://level/timing/timing_trace.gd")

var _assertions := 0
var _failures := 0


func _init() -> void:
	var trace = TimingTraceScript.new()
	trace.capacity = 3
	trace.record_input({"device": "keyboard", "timing_delta_ms": -10.0, "result": "Perfect"})
	trace.record_input({"device": "gamepad", "timing_delta_ms": 20.0, "result": "Perfect"})
	_expect(trace.size() == 2, "trace stores input records")
	_expect(trace.latest()["sequence"] == 2, "trace assigns monotonic sequence")
	var snapshot := trace.records()
	snapshot[0]["result"] = "changed"
	_expect(trace.records()[0]["result"] == "Perfect", "trace snapshots are immutable")
	var summary := trace.summary()
	_expect(summary["count"] == 2, "summary counts inputs")
	_expect_approx(summary["average_delta_ms"], 5.0, "summary averages signed delta")
	_expect_approx(summary["mean_error_ms"], 15.0, "summary averages absolute error")
	_expect_approx(summary["max_error_ms"], 20.0, "summary finds maximum error")
	_expect(summary["devices"] == {"keyboard": 1, "gamepad": 1}, "summary groups devices")
	trace.record_input({"device": "mouse", "timing_delta_ms": 30.0})
	trace.record_input({"device": "keyboard", "timing_delta_ms": 40.0})
	_expect(trace.size() == 3, "trace enforces capacity")
	_expect(trace.records()[0]["sequence"] == 2, "trace evicts oldest input")
	trace.clear()
	_expect(trace.size() == 0, "clear resets trace")
	_expect(trace.summary()["count"] == 0, "empty summary is safe")
	_finish()


func _expect_approx(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), message)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	push_error(message)


func _finish() -> void:
	if _failures > 0:
		push_error("Timing trace tests failed: %d of %d" % [_failures, _assertions])
		quit(1)
		return
	print("Timing trace tests passed: %d assertions" % _assertions)
	quit()
