extends SceneTree

const PipelineScript = preload("res://level/timing/judgment_pipeline.gd")
const SimulatorScript = preload("res://level/timing/timing_simulator.gd")

var _assertions := 0
var _failures := 0


func _init() -> void:
	var pipeline = PipelineScript.new()
	pipeline.configure(0.025, 0.050, 0.100)
	for fps in [30, 60, 120, 144]:
		var results := SimulatorScript.simulate(
			PackedFloat32Array([1.0, 2.0, 3.0]),
			[
				{"time_sec": 1.0, "device": "keyboard"},
				{"time_sec": 2.0, "device": "gamepad"},
				{"time_sec": 3.0, "device": "mouse"},
			],
			pipeline,
			PackedFloat32Array([1.0 / fps]),
		)
		_expect(results.size() == 3, "%d FPS resolves every note once" % fps)
		for result in results:
			_expect(result["result"] == "Perfect", "%d FPS preserves exact contact" % fps)
			_expect_approx(result["delta_ms"], 0.0, "%d FPS has zero exact-contact delta" % fps)

	var irregular := SimulatorScript.simulate(
		PackedFloat32Array([1.0, 2.0, 3.0]),
		[{
			"time_sec": 1.0,
		}, {"time_sec": 2.0}, {"time_sec": 3.0}],
		pipeline,
		PackedFloat32Array([0.016, 0.120, 0.008, 0.045, 0.250]),
	)
	_expect(irregular.size() == 3, "irregular frames resolve every note")
	for result in irregular:
		_expect(result["result"] == "Perfect", "irregular frame does not move input time")

	var boundaries := SimulatorScript.simulate(
		PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0]),
		[
			{"time_sec": 0.949, "device": "keyboard"},
			{"time_sec": 0.950, "device": "keyboard"},
			{"time_sec": 1.975, "device": "keyboard"},
			{"time_sec": 3.025, "device": "keyboard"},
			{"time_sec": 4.100, "device": "keyboard"},
			{"time_sec": 5.101, "device": "keyboard"},
		],
		pipeline,
		PackedFloat32Array([1.0 / 60.0]),
	)
	var expected := ["Too Fast", "Fast", "Perfect", "Perfect", "Slow", "Too Slow"]
	for index in expected.size():
		_expect(boundaries[index]["result"] == expected[index], "boundary %d is stable" % index)

	var offset_results := SimulatorScript.simulate(
		PackedFloat32Array([1.020, 2.020]),
		[{
			"time_sec": 1.020,
			"device": "keyboard",
		}, {"time_sec": 2.020, "device": "gamepad"}],
		pipeline,
		PackedFloat32Array([1.0 / 30.0]),
	)
	_expect(offset_results[0]["result"] == "Perfect", "positive offset center is respected")
	_expect(offset_results[1]["device"] == "gamepad", "device identity survives simulation")

	var multi_input := SimulatorScript.simulate(
		PackedFloat32Array([1.0, 1.01]),
		[{
			"time_sec": 1.0,
		}, {"time_sec": 1.01}],
		pipeline,
		PackedFloat32Array([0.5]),
	)
	_expect(multi_input.size() == 2, "one frame can process multiple inputs")
	_expect(multi_input[0]["note_index"] == 0 and multi_input[1]["note_index"] == 1, "multi-input order is preserved")

	var missed := SimulatorScript.simulate(
		PackedFloat32Array([1.0, 1.1, 1.2]),
		[],
		pipeline,
		PackedFloat32Array([0.5]),
	)
	_expect(missed.size() == 3, "long frame catches multiple misses")
	for result in missed:
		_expect(result["source"] == "deadline", "miss originates from deadline")
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
		push_error("Timing simulation tests failed: %d of %d" % [_failures, _assertions])
		quit(1)
		return
	print("Timing simulation tests passed: %d assertions" % _assertions)
	quit()
