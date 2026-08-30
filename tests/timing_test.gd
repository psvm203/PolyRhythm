extends SceneTree

const ConductorScript = preload("res://level/actors/conductor.gd")

var _failures: int = 0
var _assertions: int = 0


func _init() -> void:
	var conductor := ConductorScript.new()
	_test_judgment_boundaries(conductor)
	_test_custom_windows(conductor)
	_test_miss_deadline(conductor)
	_test_visual_landing_offset(conductor)
	_test_early_judgment_deferral(conductor)
	_test_clock_pause_and_resume(conductor)
	_test_classification_continuity(conductor)
	conductor.free()

	if _failures == 0:
		print("Timing tests passed: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("Timing tests failed: %d assertion(s)" % _failures)
		quit(1)


func _test_judgment_boundaries(conductor: Node) -> void:
	_expect_equal(conductor.classify_timing_delta(-0.051), "Too Fast", "before early window")
	_expect_equal(conductor.classify_timing_delta(-0.050), "Fast", "early edge is accepted")
	_expect_equal(conductor.classify_timing_delta(-0.026), "Fast", "inside Fast window")
	_expect_equal(conductor.classify_timing_delta(-0.025), "Perfect", "negative Perfect edge")
	_expect_equal(conductor.classify_timing_delta(0.000), "Perfect", "exact landing")
	_expect_equal(conductor.classify_timing_delta(0.025), "Perfect", "positive Perfect edge")
	_expect_equal(conductor.classify_timing_delta(0.026), "Slow", "inside Slow window")
	_expect_equal(conductor.classify_timing_delta(0.050), "Slow", "inside extended Slow window")
	_expect_equal(conductor.classify_timing_delta(0.100), "Slow", "late edge is accepted")
	_expect_equal(conductor.classify_timing_delta(0.101), "Too Slow", "after late window")


func _test_custom_windows(conductor: Node) -> void:
	conductor.perfect_window_sec = 0.040
	conductor.early_window_sec = 0.090
	conductor.late_window_sec = 0.120
	_expect_equal(conductor.classify_timing_delta(-0.091), "Too Fast", "custom early miss")
	_expect_equal(conductor.classify_timing_delta(-0.090), "Fast", "custom early edge")
	_expect_equal(conductor.classify_timing_delta(-0.040), "Perfect", "custom Perfect start")
	_expect_equal(conductor.classify_timing_delta(0.040), "Perfect", "custom Perfect end")
	_expect_equal(conductor.classify_timing_delta(0.120), "Slow", "custom late edge")
	_expect_equal(conductor.classify_timing_delta(0.121), "Too Slow", "custom late miss")


func _test_miss_deadline(conductor: Node) -> void:
	conductor.late_window_sec = 0.100
	_expect_equal(conductor.is_miss_due(10.099, 10.000), false, "before miss deadline")
	_expect_equal(conductor.is_miss_due(10.100, 10.000), false, "deadline remains playable")
	_expect_equal(conductor.is_miss_due(10.101, 10.000), true, "after deadline is a miss")


func _test_visual_landing_offset(conductor: Node) -> void:
	conductor.judgment_offset_sec = 0.050
	conductor.early_window_sec = 0.050
	_expect_equal(conductor.get_judgment_time(1.500), 1.550, "judgment follows visual landing")
	_expect_equal(
		conductor.get_judgment_time(1.500) - conductor.early_window_sec,
		1.500,
		"early window does not precede visual landing",
	)


func _test_early_judgment_deferral(conductor: Node) -> void:
	_expect_equal(conductor.should_defer_judgment(-0.050, "Fast"), true, "early Fast is deferred")
	_expect_equal(conductor.should_defer_judgment(-0.001, "Perfect"), true, "early Perfect is deferred")
	_expect_equal(conductor.should_defer_judgment(0.000, "Perfect"), false, "on-time Perfect is immediate")
	_expect_equal(conductor.should_defer_judgment(0.026, "Slow"), false, "Slow is immediate")
	_expect_equal(conductor.should_defer_judgment(-0.051, "Too Fast"), false, "Too Fast is immediate")


func _test_clock_pause_and_resume(conductor: Node) -> void:
	var now_usec := [1_000_000]
	conductor.time_source_usec = func() -> int: return now_usec[0]
	conductor.setup(PackedFloat32Array([1.0]))
	conductor.start()
	_expect_equal(conductor.paused, false, "start enables the clock")
	_expect_approx(conductor._get_game_time(), 0.0, "clock starts at zero")
	now_usec[0] += 250_000
	_expect_approx(conductor._get_game_time(), 0.25, "clock tracks elapsed time")
	conductor.pause_clock()
	_expect_equal(conductor.paused, true, "pause disables the clock")
	_expect_approx(conductor.game_time, 0.25, "pause captures elapsed time")
	now_usec[0] += 2_000_000
	_expect_approx(conductor._get_game_time(), 0.25, "clock remains frozen while paused")
	conductor.resume_clock()
	_expect_equal(conductor.paused, false, "resume enables the clock")
	_expect_approx(conductor._get_game_time(), 0.25, "paused duration is excluded")
	now_usec[0] += 150_000
	_expect_approx(conductor._get_game_time(), 0.40, "clock continues after resume")
	conductor.time_source_usec = Callable()


func _test_classification_continuity(conductor: Node) -> void:
	conductor.perfect_window_sec = 0.025
	conductor.early_window_sec = 0.050
	conductor.late_window_sec = 0.100
	var order := {"Too Fast": 0, "Fast": 1, "Perfect": 2, "Slow": 3, "Too Slow": 4}
	var seen := {}
	var previous_rank := -1
	for millisecond in range(-200, 201):
		var result: String = conductor.classify_timing_delta(float(millisecond) / 1000.0)
		_expect(order.has(result), "every timing value has a known result")
		var current_rank: int = order[result]
		_expect(current_rank >= previous_rank, "judgment regions never overlap or reverse")
		previous_rank = current_rank
		seen[result] = true
	for result in order:
		_expect(seen.has(result), "%s window is reachable" % result)


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


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual == expected:
		return
	_failures += 1
	push_error("%s: expected %s, got %s" % [label, expected, actual])
