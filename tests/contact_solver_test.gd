extends SceneTree

const ContactSolverScript = preload("res://level/timing/contact_solver.gd")

var _assertions := 0
var _failures := 0


func _init() -> void:
	var horizontal := PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])
	var touching := PackedVector2Array([Vector2(10, 0), Vector2(10, 8)])
	var parallel := PackedVector2Array([Vector2(0, 4), Vector2(10, 4)])
	_expect_approx(ContactSolverScript.segment_gap(horizontal, touching), 0.0, "touching edges have zero gap")
	_expect_approx(ContactSolverScript.segment_gap(horizontal, parallel), 4.0, "parallel edge distance is exact")
	_expect(is_inf(ContactSolverScript.segment_gap(PackedVector2Array(), parallel)), "invalid edge is infinite")
	_expect_approx(ContactSolverScript.interpolate_contact_time(1.0, 1.1, 2.0, 0.0, 0.5), 1.075, "contact is interpolated between frames")
	_expect_approx(ContactSolverScript.interpolate_contact_time(1.0, 1.1, 0.5, 0.0, 0.5), 1.0, "previous contact remains stable")
	_expect_approx(ContactSolverScript.interpolate_contact_time(1.0, 1.1, 2.0, 1.0, 0.5), 1.1, "no crossing returns current time")
	_expect_approx(ContactSolverScript.interpolate_contact_time(1.1, 1.0, 2.0, 0.0), 1.0, "non-forward interval is safe")
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
		push_error("Contact solver tests failed: %d of %d" % [_failures, _assertions])
		quit(1)
		return
	print("Contact solver tests passed: %d assertions" % _assertions)
	quit()
