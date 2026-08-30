extends SceneTree

const LevelDataScript = preload("res://level/data/level_data.gd")

var _failures := 0


func _init() -> void:
	var data := LevelDataScript.new()
	var stage_two := LevelDataScript.from_yaml("res://level/data/level_2.yaml")
	var stage_three := LevelDataScript.from_yaml("res://level/data/level_3.yaml")
	var stage_one := LevelDataScript.from_yaml("res://level/data/level_1.yaml")
	var expanded: Array[int] = data.expand_layout({"sides_sequence": [3, 5, 4], "repeat_count": 3})
	_expect(expanded == [3, 5, 4, 3, 5, 4, 3, 5, 4], "pattern repeats in order")
	_expect(expanded.size() == 9, "expanded note count is correct")
	_expect(expanded[0] == 3 and expanded[-1] == 4, "source order is preserved")
	_expect(stage_two.expanded_sequence().size() == 160, "stage two has a full arrangement")
	_expect(stage_three.expanded_sequence().size() == 192, "stage three has a full arrangement")
	_expect(stage_three.bpm > stage_two.bpm, "final stage increases tempo")
	_expect(ResourceLoader.exists(stage_one.music_path, "AudioStream"), "YAML music path resolves to audio")
	var serialized := LevelDataScript.to_yaml(stage_two.dictionary())
	_expect("boss_health: 260" in serialized, "YAML export includes boss settings")
	_expect("tutorial_lines:" in serialized, "YAML export includes story")
	var decimal_bpm := stage_two.dictionary()
	decimal_bpm["bpm"] = 121.75
	_expect("bpm: 121.75" in LevelDataScript.to_yaml(decimal_bpm), "YAML export preserves decimal BPM")
	data.music_start_offset_sec = 12.5
	_expect(data.clamped_music_start_offset(60.0) == 12.5, "music offset is preserved")
	data.music_start_offset_sec = 80.0
	_expect(data.clamped_music_start_offset(60.0) == 60.0, "music offset is capped to stream length")
	data.music_start_offset_sec = -2.0
	_expect(data.clamped_music_start_offset(60.0) == 0.0, "negative music offset is clamped")
	_expect(stage_two.is_guard_note(7), "eighth boss note activates guard")
	_expect(not stage_two.is_guard_note(6), "ordinary boss note has no guard")
	_expect(stage_two.boss_damage("Perfect", true) == 8, "Perfect breaks guard")
	_expect(stage_two.boss_damage("Slow", true) == 0, "imprecise hit is blocked")
	_expect(stage_two.boss_damage("Perfect", false) == 2, "Perfect damages boss")
	if _failures == 0:
		print("Level data tests passed: 18 assertions")
		quit(0)
	else:
		push_error("Level data tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(label)
