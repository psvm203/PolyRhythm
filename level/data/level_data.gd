class_name LevelData
extends RefCounted

var bpm: float = 120.0
var music_path: String = ""
var music_start_offset_sec: float = 0.0
var boss_name: String = ""
var boss_health: int = 0
var guard_interval: int = 0
var tutorial_speaker: String = "POLY"
var tutorial_lines: Array[String] = []
var _yaml: Dictionary = {}


static func from_yaml(path: String) -> LevelData:
	var result := LevelData.new()
	result._yaml = result._parse_yaml(path)
	result.bpm = float(result._yaml.get("bpm", result.bpm))
	result.music_path = str(result._yaml.get("music_path", ""))
	result.music_start_offset_sec = float(result._yaml.get("music_start_offset_sec", 0.0))
	result.boss_name = str(result._yaml.get("boss_name", ""))
	result.boss_health = int(result._yaml.get("boss_health", 0))
	result.guard_interval = int(result._yaml.get("guard_interval", 0))
	result.tutorial_speaker = str(result._yaml.get("tutorial_speaker", "POLY"))
	for line in result._yaml.get("tutorial_lines", []):
		result.tutorial_lines.append(str(line))
	return result


func expanded_sequence() -> Array[int]:
	return expand_layout(_yaml)


func _parse_yaml(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Level data not found: %s" % path)
		return {}
	var layout := {}
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var separator := line.find(":")
		if separator > 0:
			layout[line.left(separator).strip_edges()] = JSON.parse_string(line.substr(separator + 1).strip_edges())
	return layout


static func expand_layout(layout: Dictionary) -> Array[int]:
	var pattern: Array[int] = []
	for sides in layout.get("sides_sequence", []):
		pattern.append(int(sides))
	var result: Array[int] = []
	for _repeat in maxi(int(layout.get("repeat_count", 1)), 1):
		result.append_array(pattern)
	return result


static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var sequence: Array = data.get("sides_sequence", [])
	if sequence.is_empty():
		errors.append("도형 배열을 하나 이상 입력하세요.")
	for sides in sequence:
		if int(sides) < 3 or int(sides) > 12:
			errors.append("도형의 변 개수는 3~12여야 합니다.")
			break
	if float(data.get("bpm", 0.0)) <= 0.0:
		errors.append("BPM은 0보다 커야 합니다.")
	if int(data.get("repeat_count", 1)) < 1:
		errors.append("반복 횟수는 1 이상이어야 합니다.")
	var music := str(data.get("music_path", ""))
	if music.is_empty() or not FileAccess.file_exists(music):
		errors.append("재생할 음악 파일을 찾을 수 없습니다.")
	return errors


static func to_yaml(data: Dictionary) -> String:
	var keys := ["sides_sequence", "repeat_count", "bpm", "music_path", "music_start_offset_sec", "boss_name", "boss_health", "guard_interval", "tutorial_speaker", "tutorial_lines"]
	var lines := PackedStringArray(["# Polyrhythm custom level"])
	for key in keys:
		if data.has(key):
			lines.append("%s: %s" % [key, JSON.stringify(data[key])])
	return "\n".join(lines) + "\n"


func dictionary() -> Dictionary:
	return _yaml.duplicate(true)


func clamped_music_start_offset(stream_length_sec: float) -> float:
	if stream_length_sec <= 0.0:
		return maxf(music_start_offset_sec, 0.0)
	return clampf(music_start_offset_sec, 0.0, stream_length_sec)


func is_guard_note(index: int) -> bool:
	return boss_health > 0 and guard_interval > 0 and (index + 1) % guard_interval == 0


func boss_damage(result: String, guard_note: bool) -> int:
	if guard_note:
		return 8 if result == "Perfect" else 0
	return 2 if result == "Perfect" else 1 if result == "Fast" or result == "Slow" else 0
