extends SceneTree

const LevelScript = preload("res://level/level.gd")
const ShapeFactoryScript = preload("res://level/geometry/shape_factory.gd")

var _failures: int = 0
var _assertions: int = 0


func _init() -> void:
	var level := LevelScript.new()
	_test_polygon_center(level)
	_test_uniform_scaling(level)
	_test_landing_pulse(level)
	_test_starter_triangle_shared_edge()
	level.free()
	if _failures == 0:
		print("Polygon visual tests passed: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("Polygon visual tests failed: %d assertion(s)" % _failures)
		quit(1)


func _test_polygon_center(level: Node) -> void:
	var square := PackedVector2Array([
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
		Vector2(1.0, 1.0), Vector2(-1.0, 1.0),
	])
	_expect_vector(level._polygon_center(square), Vector2.ZERO, "regular polygon center")


func _test_uniform_scaling(level: Node) -> void:
	var edge := PackedVector2Array([Vector2(1.0, 0.0), Vector2(0.0, 1.0)])
	var scaled: PackedVector2Array = level._scaled_polygon(edge, Vector2.ZERO, 1.06)
	_expect_vector(scaled[0], Vector2(1.06, 0.0), "first scaled point")
	_expect_vector(scaled[1], Vector2(0.0, 1.06), "second scaled point")


func _test_landing_pulse(level: Node) -> void:
	_expect_approx(level._landing_pulse_strength(0.94, 1.0), 0.0, "before landing cue")
	_expect_approx(level._landing_pulse_strength(0.95, 1.0), 0.0, "landing cue start")
	_expect_approx(level._landing_pulse_strength(1.00, 1.0), 1.0, "landing cue peak")
	_expect_approx(level._landing_pulse_strength(1.05, 1.0), 0.0, "landing cue end")


func _test_starter_triangle_shared_edge() -> void:
	var factory := ShapeFactoryScript.new()
	var sequence: Array[int] = [3]
	var result := factory.build(sequence, 100.0, Vector2(500.0, 600.0))
	var first: PackedVector2Array = result["shapes"][0]
	var starter: PackedVector2Array = factory.build_polygon_on_edge(
		3,
		Vector2(550.0, 600.0),
		Vector2(450.0, 600.0),
	)
	_expect(_contains_approx(starter, first[first.size() - 1]), "starter shares first entrance endpoint")
	_expect(_contains_approx(starter, first[0]), "starter shares second entrance endpoint")


func _contains_approx(points: PackedVector2Array, expected: Vector2) -> bool:
	for point in points:
		if point.is_equal_approx(expected):
			return true
	return false


func _expect_vector(actual: Vector2, expected: Vector2, label: String) -> void:
	_assertions += 1
	if actual.is_equal_approx(expected):
		return
	_failures += 1
	push_error("%s: expected %s, got %s" % [label, expected, actual])


func _expect_approx(actual: float, expected: float, label: String) -> void:
	_assertions += 1
	if is_equal_approx(actual, expected):
		return
	_failures += 1
	push_error("%s: expected %s, got %s" % [label, expected, actual])


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	push_error(label)
