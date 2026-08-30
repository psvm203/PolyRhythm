class_name ProgressStore
extends RefCounted

const SAVE_PATH := "user://progress.cfg"
const SECTION := "progress"
const UNLOCKED_KEY := "highest_unlocked_stage"
const PENDING_DIALOGUE_KEY := "pending_unlock_dialogue"
const LAST_STAGE := 3

static var selected_stage := 1
static var show_stage_select_on_load := false
static var custom_level_path := ""


static func highest_unlocked_stage() -> int:
	var config := _load()
	return clampi(int(config.get_value(SECTION, UNLOCKED_KEY, 1)), 1, LAST_STAGE)


static func unlock_next_stage(cleared_stage: int) -> int:
	var highest := highest_unlocked_stage()
	var unlocked := next_unlocked_stage(cleared_stage, highest)
	if unlocked == highest:
		return highest
	var config := _load()
	config.set_value(SECTION, UNLOCKED_KEY, unlocked)
	config.set_value(SECTION, PENDING_DIALOGUE_KEY, unlocked)
	_save(config)
	return unlocked


static func next_unlocked_stage(cleared_stage: int, highest_unlocked: int) -> int:
	return clampi(maxi(highest_unlocked, cleared_stage + 1), 1, LAST_STAGE)


static func pending_unlock_dialogue() -> int:
	var config := _load()
	return clampi(int(config.get_value(SECTION, PENDING_DIALOGUE_KEY, 0)), 0, LAST_STAGE)


static func consume_unlock_dialogue() -> int:
	var config := _load()
	var stage := clampi(int(config.get_value(SECTION, PENDING_DIALOGUE_KEY, 0)), 0, LAST_STAGE)
	if stage == 0:
		return 0
	config.set_value(SECTION, PENDING_DIALOGUE_KEY, 0)
	_save(config)
	return stage


static func stage_record(stage: int) -> Dictionary:
	var config := _load()
	var section := "stage_%d" % clampi(stage, 1, LAST_STAGE)
	return {
		"score": int(config.get_value(section, "score", 0)),
		"rank": str(config.get_value(section, "rank", "-")),
		"accuracy": float(config.get_value(section, "accuracy", 0.0)),
		"max_combo": int(config.get_value(section, "max_combo", 0)),
		"cleared": bool(config.get_value(section, "cleared", false)),
	}


static func record_run(stage: int, stats: Dictionary, rank: String, completed: bool) -> void:
	var previous := stage_record(stage)
	if not is_better_record(int(stats["score"]), completed, previous["score"]):
		return
	var config := _load()
	var section := "stage_%d" % clampi(stage, 1, LAST_STAGE)
	for key in ["score", "accuracy", "max_combo"]:
		config.set_value(section, key, stats[key])
	config.set_value(section, "rank", rank)
	config.set_value(section, "cleared", true)
	_save(config)


static func is_better_record(score: int, completed: bool, previous_score: int) -> bool:
	return completed and score > previous_score


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	return config


static func _save(config: ConfigFile) -> void:
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("Failed to save progress: %s" % error_string(error))
