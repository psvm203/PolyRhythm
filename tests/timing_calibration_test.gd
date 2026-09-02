extends SceneTree

const CalibrationScript = preload("res://main/timing_calibration_overlay.gd")
const CalibrationVisualScript = preload("res://main/timing_calibration_visual.gd")
const CalibrationScene = preload("res://main/timing_calibration_overlay.tscn")

var _failures := 0


func _init() -> void:
	_expect(is_equal_approx(CalibrationScript.calculate_median([10.0, 30.0, 20.0]), 20.0), "odd median is calculated")
	_expect(is_equal_approx(CalibrationScript.calculate_median([-20.0, 10.0, 20.0, 30.0]), 15.0), "even median is calculated")
	_expect(is_equal_approx(CalibrationScript.calculate_median([]), 0.0), "empty median is safe")
	_expect(is_equal_approx(CalibrationScript.calculate_mean_deviation([10.0, 20.0, 30.0], 20.0), 20.0 / 3.0), "measurement spread is calculated")
	var calibration := CalibrationScene.instantiate()
	var buttons := calibration.get_node("Dim/Center/Panel/Margin/Rows/Buttons")
	_expect(not buttons.has_node("StartButton"), "calibration starts without a dedicated start button")
	_expect(buttons.get_node("ApplyButton").text == "적용", "apply action is localized")
	_expect(buttons.get_node("CancelButton").text == "취소", "cancel action is localized")
	_expect(calibration.get_node("Dim/Center/Panel/Margin/Rows/Status").text == "아무 키나 눌러 시작하세요", "idle tooltip explains keyboard start")
	calibration.free()
	var start_key := InputEventKey.new()
	start_key.pressed = true
	_expect(CalibrationScript.is_start_input(start_key), "pressed key starts calibration")
	var released_key := InputEventKey.new()
	_expect(not CalibrationScript.is_start_input(released_key), "released key does not start calibration")
	_expect(is_equal_approx(CalibrationVisualScript.approach_progress(500_000, 1_000_000, 500_000), 0.0), "approach starts one interval before contact")
	_expect(is_equal_approx(CalibrationVisualScript.approach_progress(750_000, 1_000_000, 500_000), 0.5), "approach reaches its midpoint")
	_expect(is_equal_approx(CalibrationVisualScript.approach_progress(1_000_000, 1_000_000, 500_000), 1.0), "approach ends exactly at contact")
	_expect(is_equal_approx(CalibrationVisualScript.rotation_angle(0.5), PI), "triangle completes half a turn at midpoint")
	_expect(is_equal_approx(CalibrationVisualScript.rotation_angle(1.0), TAU), "triangle completes a full turn at contact")
	_expect(CalibrationVisualScript.transition_offset(0.5, Vector2(-200.0, 0.0)).is_equal_approx(Vector2(-100.0, 0.0)), "fly-in offset moves linearly like gameplay")
	var idle_center := Vector2(-155.0, 0.0)
	var contact_center := Vector2(20.0, 0.0)
	_expect(CalibrationVisualScript.transition_center(0.0, idle_center, contact_center) == idle_center, "calibration starts at its idle position")
	_expect(CalibrationVisualScript.transition_center(1.0, idle_center, contact_center) == contact_center, "calibration ends at its contact position")
	var entrance_edge: PackedVector2Array = CalibrationVisualScript.entrance_edge(Vector2.ZERO, 60.0, 0.0)
	_expect(entrance_edge.size() == 2, "calibration highlights one entrance edge")
	_expect(is_equal_approx(entrance_edge[0].x, entrance_edge[1].x), "entrance edge is vertical at contact")
	_expect(entrance_edge[0].y < entrance_edge[1].y, "entrance edge follows the triangle vertex order")
	var rotated_edge: PackedVector2Array = CalibrationVisualScript.entrance_edge(Vector2.ZERO, 60.0, PI)
	_expect(rotated_edge[0].x < 0.0 and rotated_edge[1].x < 0.0, "highlight rotates with the moving triangle")
	_expect(CalibrationScript.BEAT_INTERVAL_USEC == 1_200_000, "calibration movement runs at half the previous speed")
	if _failures == 0:
		print("Timing calibration tests passed: 23 assertions")
		quit(0)
	else:
		push_error("Timing calibration tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
