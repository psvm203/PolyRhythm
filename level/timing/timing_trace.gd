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
	var low_frame_inputs := 0
	for record in _records:
		var delta := float(record.get("timing_delta_ms", 0.0))
		signed_total += delta
		absolute_total += absf(delta)
		max_error = maxf(max_error, absf(delta))
		var device := str(record.get("device", "unknown"))
		devices[device] = int(devices.get(device, 0)) + 1
		if float(record.get("frame_time_ms", 0.0)) >= 33.333:
			low_frame_inputs += 1
	return {
		"count": _records.size(),
		"average_delta_ms": signed_total / _records.size(),
		"mean_error_ms": absolute_total / _records.size(),
		"max_error_ms": max_error,
		"devices": devices,
		"low_frame_inputs": low_frame_inputs,
	}


func save_json(path: String, metadata: Dictionary = {}) -> Error:
	var directory := path.get_base_dir()
	var absolute_directory := ProjectSettings.globalize_path(directory) if directory.contains("://") else directory
	if not absolute_directory.is_empty() and not DirAccess.dir_exists_absolute(absolute_directory):
		var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
		if directory_error != OK:
			return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": 1,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"metadata": metadata,
		"summary": summary(),
		"records": records(),
	}, "  "))
	return OK


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
