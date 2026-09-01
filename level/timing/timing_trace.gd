class_name TimingTrace
extends RefCounted

var capacity: int = 100
var _records: Array[Dictionary] = []


func clear() -> void:
	_records.clear()


func record_input(data: Dictionary) -> Dictionary:
	var record := data.duplicate(true)
	record["sequence"] = int(_records[-1]["sequence"]) + 1 if not _records.is_empty() else 1
	_records.append(record)
	while _records.size() > maxi(capacity, 1):
		_records.pop_front()
	return record.duplicate(true)


func records() -> Array[Dictionary]:
	return _records.duplicate(true)


func latest() -> Dictionary:
	return _records[-1].duplicate(true) if not _records.is_empty() else {}


func size() -> int:
	return _records.size()


func summary() -> Dictionary:
	if _records.is_empty():
		return {"count": 0, "average_delta_ms": 0.0, "mean_error_ms": 0.0, "max_error_ms": 0.0, "devices": {}}
	var signed_total := 0.0
	var absolute_total := 0.0
	var max_error := 0.0
	var devices := {}
	for record in _records:
		var delta := float(record.get("timing_delta_ms", 0.0))
		signed_total += delta
		absolute_total += absf(delta)
		max_error = maxf(max_error, absf(delta))
		var device := str(record.get("device", "unknown"))
		devices[device] = int(devices.get(device, 0)) + 1
	return {
		"count": _records.size(),
		"average_delta_ms": signed_total / _records.size(),
		"mean_error_ms": absolute_total / _records.size(),
		"max_error_ms": max_error,
		"devices": devices,
	}
