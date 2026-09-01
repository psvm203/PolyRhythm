class_name TimingSimulator
extends RefCounted


static func simulate(
	centers: PackedFloat32Array,
	inputs: Array[Dictionary],
	pipeline,
	frame_pattern_sec: PackedFloat32Array,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if centers.is_empty():
		return results
	var sorted_inputs := inputs.duplicate(true)
	sorted_inputs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time_sec"]) < float(b["time_sec"]))
	var note_index := 0
	var input_index := 0
	var frame_index := 0
	var frame_time := 0.0
	var final_time: float = float(centers[-1]) + float(pipeline.late_window_sec) + 1.0
	while note_index < centers.size() and frame_time <= final_time:
		var frame_delta := float(frame_pattern_sec[frame_index % frame_pattern_sec.size()]) if not frame_pattern_sec.is_empty() else 1.0 / 60.0
		var next_frame := frame_time + maxf(frame_delta, 0.0001)
		while input_index < sorted_inputs.size() and float(sorted_inputs[input_index]["time_sec"]) <= next_frame:
			var input: Dictionary = sorted_inputs[input_index]
			var input_time := float(input["time_sec"])
			while note_index < centers.size() and pipeline.is_miss_due(input_time, centers[note_index]):
				results.append({"note_index": note_index, "result": "Too Slow", "source": "deadline", "time_sec": input_time})
				note_index += 1
			if note_index >= centers.size():
				break
			var evaluation: Dictionary = pipeline.evaluate(input_time, centers[note_index])
			results.append({
				"note_index": note_index,
				"result": evaluation["result"],
				"delta_ms": evaluation["delta_ms"],
				"source": "input",
				"device": input.get("device", "unknown"),
				"time_sec": input_time,
			})
			if bool(evaluation["advance_note"]):
				note_index += 1
			input_index += 1
		while note_index < centers.size() and pipeline.is_miss_due(next_frame, centers[note_index]):
			results.append({"note_index": note_index, "result": "Too Slow", "source": "deadline", "time_sec": next_frame})
			note_index += 1
		frame_time = next_frame
		frame_index += 1
	return results
