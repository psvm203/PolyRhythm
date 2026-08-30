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

var _boss_health := 0
var _guard_interval := 0
var _history: SequenceHistory = SequenceHistoryScript.new()
var _applying_history := false
var _updating_seek := false
var _preview_music_path := ""


func _ready() -> void:
	%BackButton.pressed.connect(_exit_editor)
	%GuideButton.pressed.connect(%GuideDialog.popup_centered_ratio.bind(0.62))
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
	for sides in range(3, 9):
		var button := PolygonPaletteButtonScript.new()
		button.setup(sides)
		button.pressed.connect(%Timeline.add_tile.bind(sides))
		%ShapePalette.add_child(button)
	%Timeline.sequence_changed.connect(_on_sequence_changed)
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
		"guard_interval": _guard_interval,
	}


func _populate(data: Dictionary) -> void:
	%Timeline.set_sequence(data.get("sides_sequence", []))
	%Bpm.value = float(data.get("bpm", 120.0))
	%MusicPath.text = str(data.get("music_path", ""))
	%MusicOffset.value = float(data.get("music_start_offset_sec", 0.0))
	_boss_health = int(data.get("boss_health", 0))
	_guard_interval = int(data.get("guard_interval", 0))


func _update_summary() -> void:
	%SequenceSummary.text = "%d TILES" % %Timeline.sequence.size()


func _on_sequence_changed(sequence: Array[int]) -> void:
	_update_summary()
	if not _applying_history:
		_history.record(sequence)
	_queue_autosave()


func _reset_history() -> void:
	_history.reset(%Timeline.sequence)


func _undo() -> void:
	if not _history.can_undo():
		return
	_apply_history(_history.undo())


func _redo() -> void:
	if not _history.can_redo():
		return
	_apply_history(_history.redo())


func _apply_history(sequence: Array) -> void:
	_applying_history = true
	%Timeline.set_sequence(sequence)
	_applying_history = false
	_update_summary()
	_queue_autosave()


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
		get_tree().change_scene_to_file(MAIN_SCENE)
