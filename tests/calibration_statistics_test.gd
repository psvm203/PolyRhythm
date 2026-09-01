extends SceneTree

const StatisticsScript = preload("res://level/timing/calibration_statistics.gd")

var _assertions := 0
var _failures := 0


func _init() -> void:
	_expect_approx(StatisticsScript.median([1.0, 3.0, 2.0]), 2.0, "odd median")
	_expect_approx(StatisticsScript.median([1.0, 2.0, 3.0, 4.0]), 2.5, "even median")
	var filtered: Array[float] = StatisticsScript.reject_outliers([9.0, 10.0, 11.0, 120.0])
	_expect(filtered == [9.0, 10.0, 11.0], "MAD filter removes extreme input")
	var report: Dictionary = StatisticsScript.report(
		[9.0, 10.0, 11.0, 120.0, -5.0, -4.0, -6.0, -5.0],
		["keyboard", "keyboard", "keyboard", "keyboard", "gamepad", "gamepad", "gamepad", "gamepad"],
	)
	_expect(report["sample_count"] == 8, "report counts raw samples")
	_expect(report["rejected_count"] >= 1, "report counts rejected samples")
	_expect((report["device_centers_ms"] as Dictionary).has("keyboard"), "report includes keyboard recommendation")
	_expect((report["device_centers_ms"] as Dictionary).has("gamepad"), "report includes gamepad recommendation")
	_expect_approx(report["device_centers_ms"]["keyboard"], 10.0, "keyboard center ignores outlier")
	_expect_approx(report["device_centers_ms"]["gamepad"], -5.0, "gamepad center is independent")
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
		push_error("Calibration statistics tests failed: %d of %d" % [_failures, _assertions])
		quit(1)
		return
	print("Calibration statistics tests passed: %d assertions" % _assertions)
	quit()
