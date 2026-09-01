extends SceneTree

const CalibrationScript = preload("res://main/timing_calibration_overlay.gd")
const CalibrationVisualScript = preload("res://main/timing_calibration_visual.gd")

var _failures := 0


func _init() -> void:
	_expect(is_equal_approx(CalibrationScript.calculate_median([10.0, 30.0, 20.0]), 20.0), "odd median is calculated")
	_expect(is_equal_approx(CalibrationScript.calculate_median([-20.0, 10.0, 20.0, 30.0]), 15.0), "even median is calculated")
	_expect(is_equal_approx(CalibrationScript.calculate_median([]), 0.0), "empty median is safe")
	_expect(is_equal_approx(CalibrationScript.calculate_mean_deviation([10.0, 20.0, 30.0], 20.0), 20.0 / 3.0), "measurement spread is calculated")
	_expect(is_equal_approx(CalibrationVisualScript.approach_progress(500_000, 1_000_000, 500_000), 0.0), "approach starts one interval before contact")
	_expect(is_equal_approx(CalibrationVisualScript.approach_progress(750_000, 1_000_000, 500_000), 0.5), "approach reaches its midpoint")
	_expect(is_equal_approx(CalibrationVisualScript.approach_progress(1_000_000, 1_000_000, 500_000), 1.0), "approach ends exactly at contact")
	_expect(is_equal_approx(CalibrationVisualScript.rotation_angle(0.5), PI), "triangle completes half a turn at midpoint")
	_expect(is_equal_approx(CalibrationVisualScript.rotation_angle(1.0), TAU), "triangle completes a full turn at contact")
	_expect(CalibrationVisualScript.transition_offset(0.5, Vector2(-200.0, 0.0)).is_equal_approx(Vector2(-100.0, 0.0)), "fly-in offset moves linearly like gameplay")
	_expect(CalibrationScript.BEAT_INTERVAL_USEC == 1_200_000, "calibration movement runs at half the previous speed")
	if _failures == 0:
		print("Timing calibration tests passed: 11 assertions")
		quit(0)
	else:
		push_error("Timing calibration tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
