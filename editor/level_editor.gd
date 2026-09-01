extends Control

const LevelDataScript = preload("res://level/data/level_data.gd")
const ProgressStoreScript = preload("res://level/progress_store.gd")
const AudioStreamLoaderScript = preload("res://level/audio/audio_stream_loader.gd")
const PolygonPaletteButtonScript = preload("res://editor/components/polygon_palette_button.gd")
const SequenceHistoryScript = preload("res://editor/model/sequence_history.gd")
const LEVEL_SCENE := "res://level/level.tscn"
const MAIN_SCENE := "res://main/main_screen.tscn"
const PREVIEW_PATH := "user://custom_level_preview.yaml"
const AUTOSAVE_PATH := "user://custom_level_autosave.yaml"
const EVENT_TYPES := [
	{"label": "BOSS GUARD", "name": "boss_guard"},
	{"label": "SAMURAI SPLIT", "name": "samurai_split", "when_sides": 6, "replace_with": [3, 3]},
	{"label": "TIME STOP", "name": "time_stop", "duration_sec": 0.65},
]

var _boss_health := 0
var _events: Array[Dictionary] = []
var _history: SequenceHistory = SequenceHistoryScript.new()
var _applying_history := false
var _updating_seek := false
var _preview_music_path := ""


func _ready() -> void:
	%BackButton.pressed.connect(_exit_editor)
	%GuideButton.pressed.connect(%GuideOverlay.open)
	%ImportButton.pressed.connect(%ImportDialog.popup_centered_ratio.bind(0.75))
	%ExportButton.pressed.connect(%ExportDialog.popup_centered_ratio.bind(0.75))
	%MusicButton.pressed.connect(%MusicDialog.popup_centered_ratio.bind(0.75))
	%ValidateButton.pressed.connect(_validate)
	%PlayButton.pressed.connect(_test_play)
	%ImportDialog.file_selected.connect(_import_yaml)
	%ExportDialog.file_selected.connect(_export_yaml)
	%MusicDialog.file_selected.connect(func(path: String) -> void: %MusicPath.text = path)
	%MusicPreviewButton.pressed.connect(_toggle_music_preview)
	%MusicStopButton.pressed.connect(_stop_music_preview)
	%MusicSeek.value_changed.connect(_seek_music_preview)
	%MusicPreview.finished.connect(_stop_music_preview)
	%AutosaveTimer.timeout.connect(_save_autosave)
	%EventType.add_item("EVENT TYPE")
	for event_type in EVENT_TYPES:
		%EventType.add_item(event_type["label"])
	%EventApply.pressed.connect(_apply_selected_event)
	%EventRemove.pressed.connect(_remove_selected_events)
	for sides in range(3, 9):
		var button := PolygonPaletteButtonScript.new()
		button.setup(sides)
		button.pressed.connect(%Timeline.add_tile.bind(sides))
		%ShapePalette.add_child(button)
	%Timeline.sequence_changed.connect(_on_sequence_changed)
	%Timeline.selection_changed.connect(func(_index: int) -> void: _sync_event_controls())
	%Timeline.tile_inserted.connect(_shift_events_for_insert)
	%Timeline.tile_removed.connect(_shift_events_for_remove)
	%Timeline.tile_moved.connect(_move_event_target)
	%Bpm.value_changed.connect(func(_value: float) -> void: _queue_autosave())
	%MusicOffset.value_changed.connect(func(_value: float) -> void: _queue_autosave())
	%MusicPath.text_changed.connect(func(_value: String) -> void: _queue_autosave())
	%TimelineMode.pressed.connect(_set_map_mode.bind(false))
	%MapMode.pressed.connect(_set_map_mode.bind(true))
	%Timeline.set_sequence([3, 4, 5, 4, 6, 3])
	%MusicPath.text = "res://level/data/BR-Freaky_feat_LezaLee_-fulllength-loopable-121_9BPM-Dm.WAV"
	if not ProgressStoreScript.custom_level_path.is_empty() and FileAccess.file_exists(ProgressStoreScript.custom_level_path):
		_import_yaml(ProgressStoreScript.custom_level_path)
	elif FileAccess.file_exists(AUTOSAVE_PATH):
		_populate(LevelDataScript.from_yaml(AUTOSAVE_PATH).dictionary())
		%Status.text = "자동 저장된 레벨을 복구했습니다."
	%Timeline.grab_focus()
	_set_map_mode(false)
	_reset_history()
	_sync_event_controls()


func _set_map_mode(enabled: bool) -> void:
	%TimelineMode.set_pressed_no_signal(not enabled)
	%MapMode.set_pressed_no_signal(enabled)
	%Timeline.set_map_mode(enabled)
	%TimelineScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if enabled else ScrollContainer.SCROLL_MODE_DISABLED


func _collect() -> Dictionary:
	return {
		"sides_sequence": %Timeline.sequence.duplicate(),
		"repeat_count": 1,
		"bpm": %Bpm.value,
		"music_path": %MusicPath.text.strip_edges(),
		"music_start_offset_sec": %MusicOffset.value,
		"boss_name": "",
		"boss_health": _boss_health,
		"events": _events.duplicate(true),
	}


func _populate(data: Dictionary) -> void:
	%Timeline.set_sequence(data.get("sides_sequence", []))
	%Bpm.value = float(data.get("bpm", 120.0))
	%MusicPath.text = str(data.get("music_path", ""))
	%MusicOffset.value = float(data.get("music_start_offset_sec", 0.0))
	_boss_health = int(data.get("boss_health", 0))
	_events.clear()
	for event in data.get("events", []):
		if event is Dictionary:
			_events.append((event as Dictionary).duplicate(true))
	%Timeline.set_events(_events)


func _update_summary() -> void:
	%SequenceSummary.text = "%d TILES" % %Timeline.sequence.size()


func _on_sequence_changed(sequence: Array[int]) -> void:
	_update_summary()
	if not _applying_history:
		_history.record(_history_state())
	_queue_autosave()


func _reset_history() -> void:
	_history.reset(_history_state())


func _undo() -> void:
	if not _history.can_undo():
		return
	_apply_history(_history.undo())


func _redo() -> void:
	if not _history.can_redo():
		return
	_apply_history(_history.redo())


func _apply_history(state: Variant) -> void:
	if not state is Dictionary:
		return
	_applying_history = true
	_events.assign(state.get("events", []))
	%Timeline.set_sequence(state.get("sequence", []))
	%Timeline.set_events(_events)
	_applying_history = false
	_update_summary()
	_sync_event_controls()
	_queue_autosave()


func _history_state() -> Dictionary:
	return {"sequence": %Timeline.sequence.duplicate(), "events": _events.duplicate(true)}


func _apply_selected_event() -> void:
	var tile: int = %Timeline.selected_index
	var type_index: int = %EventType.selected - 1
	if tile < 0 or type_index < 0:
		return
	var template: Dictionary = EVENT_TYPES[type_index]
	if template.get("when_sides", 0) > 0 and %Timeline.sequence[tile] != template["when_sides"]:
		%Status.text = "⚠ 이 이벤트는 %d각형에만 적용할 수 있습니다." % template["when_sides"]
		return
	var event := _find_or_create_event(template)
	var targets: Array = event.get("at", [])
	if not targets.has(tile + 1):
		targets.append(tile + 1)
		targets.sort()
		event["at"] = targets
	_commit_event_change()


func _remove_selected_events() -> void:
	var polygon_number: int = %Timeline.selected_index + 1
	if polygon_number <= 0:
		return
	for index in range(_events.size() - 1, -1, -1):
		var targets: Array = _events[index].get("at", [])
		targets.erase(polygon_number)
		_events[index]["at"] = targets
		if targets.is_empty():
			_events.remove_at(index)
	_commit_event_change()


func _find_or_create_event(template: Dictionary) -> Dictionary:
	for event in _events:
		if event.get("name", "") == template["name"]:
			return event
	var created := template.duplicate(true)
	created.erase("label")
	created["at"] = []
	_events.append(created)
	return created


func _commit_event_change() -> void:
	%Timeline.set_events(_events)
	_history.record(_history_state())
	_sync_event_controls()
	_queue_autosave()


func _sync_event_controls() -> void:
	var polygon_number: int = %Timeline.selected_index + 1
	%EventApply.disabled = polygon_number <= 0
	%EventRemove.disabled = polygon_number <= 0 or not _has_event_at(polygon_number)
	%EventType.select(0)
	for type_index in EVENT_TYPES.size():
		for event in _events:
			if event.get("name", "") == EVENT_TYPES[type_index]["name"] and event.get("at", []).has(polygon_number):
				%EventType.select(type_index + 1)
				return


func _has_event_at(polygon_number: int) -> bool:
	for event in _events:
		if event.get("at", []).has(polygon_number):
			return true
	return false


func _shift_events_for_insert(index: int) -> void:
	_remap_event_targets(func(value: int) -> int: return value + 1 if value >= index + 1 else value)


func _shift_events_for_remove(index: int) -> void:
	var removed := index + 1
	_remap_event_targets(func(value: int) -> int: return -1 if value == removed else value - 1 if value > removed else value)


func _move_event_target(from_index: int, to_index: int) -> void:
	var source := from_index + 1
	var target := to_index + 1
	_remap_event_targets(func(value: int) -> int:
		if value == source:
			return target
		if source < target and value > source and value <= target:
			return value - 1
		if target < source and value >= target and value < source:
			return value + 1
		return value
	)


func _remap_event_targets(mapper: Callable) -> void:
	for event in _events:
		var remapped: Array[int] = []
		for value in event.get("at", []):
			var mapped := int(mapper.call(int(value)))
			if mapped > 0:
				remapped.append(mapped)
		remapped.sort()
		event["at"] = remapped
	%Timeline.set_events(_events)


func _queue_autosave() -> void:
	%AutosaveTimer.start()


func _save_autosave() -> void:
	_write_yaml(AUTOSAVE_PATH)


func _exit_editor() -> void:
	_save_autosave()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _toggle_music_preview() -> void:
	if %MusicPreview.playing:
		%MusicPreview.stream_paused = not %MusicPreview.stream_paused
		%MusicPreviewButton.text = "▶" if %MusicPreview.stream_paused else "⏸"
		return
	var path: String = %MusicPath.text.strip_edges()
	if path != _preview_music_path or %MusicPreview.stream == null:
		%MusicPreview.stream = _load_preview_music(path)
		_preview_music_path = path
	if %MusicPreview.stream == null:
		%Status.text = "⚠ 음악 파일을 재생할 수 없습니다."
		return
	%MusicSeek.max_value = %MusicPreview.stream.get_length()
	%MusicPreview.play(clampf(%MusicOffset.value, 0.0, %MusicSeek.max_value))
	%MusicPreviewButton.text = "⏸"


func _stop_music_preview() -> void:
	%MusicPreview.stop()
	%MusicPreviewButton.text = "▶"
	_updating_seek = true
	%MusicSeek.value = 0.0
	%MusicTime.text = "0:00 / %s" % _format_time(%MusicSeek.max_value)
	_updating_seek = false


func _seek_music_preview(value: float) -> void:
	if not _updating_seek and %MusicPreview.playing:
		%MusicPreview.seek(value)


func _load_preview_music(path: String) -> AudioStream:
	return AudioStreamLoaderScript.load_stream(path)


func _process(_delta: float) -> void:
	if not %MusicPreview.playing or %MusicPreview.stream_paused:
		return
	_updating_seek = true
	%MusicSeek.value = %MusicPreview.get_playback_position()
	%MusicTime.text = "%s / %s" % [_format_time(%MusicSeek.value), _format_time(%MusicSeek.max_value)]
	_updating_seek = false


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _validate() -> bool:
	var errors := LevelDataScript.validate(_collect())
	%Status.text = "✓ 플레이 가능한 레벨입니다." if errors.is_empty() else "⚠ " + "\n⚠ ".join(errors)
	%Status.modulate = Color("55efb0") if errors.is_empty() else Color("ff6680")
	return errors.is_empty()


func _import_yaml(path: String) -> void:
	var data := LevelDataScript.from_yaml(path).dictionary()
	_populate(data)
	_reset_history()
	_sync_event_controls()
	%Status.text = "불러옴: %s" % path
	_validate()


func _export_yaml(path: String) -> void:
	if not _validate():
		return
	if path.get_extension().to_lower() != "yaml":
		path += ".yaml"
	_write_yaml(path)
	%Status.text = "저장됨: %s" % path


func _write_yaml(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		%Status.text = "⚠ 파일을 저장할 수 없습니다: %s" % path
		return
	file.store_string(LevelDataScript.to_yaml(_collect()))


func _test_play() -> void:
	if not _validate():
		return
	_write_yaml(PREVIEW_PATH)
	ProgressStoreScript.custom_level_path = PREVIEW_PATH
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_Z:
		_redo() if event.shift_pressed else _undo()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_music_preview()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.unicode >= 51 and event.unicode <= 56:
		%Timeline.add_tile(event.unicode - 48)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if %GuideOverlay.visible:
			%GuideOverlay.close()
		else:
			get_tree().change_scene_to_file(MAIN_SCENE)
