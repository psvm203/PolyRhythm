extends CanvasLayer

signal dialogue_finished

@export var characters_per_second: float = 42.0
@export var panel_height: float = 270.0
@export var panel_side_margin: float = 42.0
@export var panel_bottom_margin: float = 18.0

@onready var layout_root: Control = $Root
@onready var dialogue_panel: PanelContainer = $Root/DialoguePanel
@onready var speaker_label: Label = %Speaker
@onready var dialogue_label: Label = %Dialogue
@onready var progress_label: Label = %Progress
@onready var continue_label: Label = %Continue
@onready var skip_button: Button = %SkipButton

var _lines: Array[String] = []
var _line_index: int = 0
var _visible_characters_float: float = 0.0
var _typing: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_layout_to_viewport)
	_layout_to_viewport()
	hide()
	set_process(false)
	skip_button.pressed.connect(skip)
	var input_manager := _input_manager()
	if input_manager != null:
		input_manager.connect("active_device_changed", _update_input_prompts.unbind(1))
	_update_input_prompts()


func _layout_to_viewport() -> void:
	if layout_root == null:
		return
	layout_root.position = Vector2.ZERO
	var viewport_size := get_viewport().get_visible_rect().size
	layout_root.size = viewport_size
	dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var height := minf(panel_height, viewport_size.y / 3.0)
	dialogue_panel.position = Vector2(
		panel_side_margin,
		viewport_size.y - height - panel_bottom_margin,
	)
	dialogue_panel.size = Vector2(
		maxf(viewport_size.x - panel_side_margin * 2.0, 0.0),
		height,
	)


func play(lines: Array[String], speaker: String = "POLY") -> void:
	if lines.is_empty():
		dialogue_finished.emit()
		return
	_lines = lines.duplicate()
	_line_index = 0
	speaker_label.text = speaker
	show()
	set_process(true)
	_show_current_line()


func _process(delta: float) -> void:
	if not _typing:
		return
	_visible_characters_float += delta * characters_per_second
	dialogue_label.visible_characters = mini(
		int(_visible_characters_float),
		dialogue_label.text.length(),
	)
	if dialogue_label.visible_characters >= dialogue_label.text.length():
		_finish_typing()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event.is_action_pressed("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and skip_button.get_global_rect().has_point(event.position):
		return
	var input_manager := _input_manager()
	var gamepad_input := bool(input_manager.call("is_play_input", event)) if input_manager != null else false
	if event.is_action_pressed("tap") or event.is_action_pressed("ui_accept") or gamepad_input:
		advance()
		get_viewport().set_input_as_handled()


func advance() -> void:
	if _typing:
		dialogue_label.visible_characters = -1
		_finish_typing()
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_finish_dialogue()
	else:
		_show_current_line()


func skip() -> void:
	if visible:
		_finish_dialogue()


func _show_current_line() -> void:
	dialogue_label.text = _format_input_prompts(_lines[_line_index])
	dialogue_label.visible_characters = 0
	_visible_characters_float = 0.0
	_typing = true
	continue_label.modulate.a = 0.35
	progress_label.text = "%d / %d" % [_line_index + 1, _lines.size()]


func _update_input_prompts() -> void:
	var input_manager := _input_manager()
	var gamepad_active: bool = input_manager != null and input_manager.get("active_device_type") == "gamepad"
	continue_label.text = (
		"%s으로 계속" % input_manager.call("play_prompt")
		if gamepad_active
		else "클릭 또는 아무 키로 계속"
	)
	if visible and not _lines.is_empty():
		dialogue_label.text = _format_input_prompts(_lines[_line_index])


func _format_input_prompts(text: String) -> String:
	var input_manager := _input_manager()
	if input_manager == null or input_manager.get("active_device_type") != "gamepad":
		return text.replace("{play_input}", "아무 키").replace("{pause_input}", "ESC")
	return text.replace("{play_input}", input_manager.call("play_prompt")).replace("{pause_input}", input_manager.call("pause_prompt"))


func _input_manager() -> Node:
	return get_node_or_null("/root/InputDeviceManager")


func _finish_typing() -> void:
	_typing = false
	dialogue_label.visible_characters = -1
	continue_label.modulate.a = 1.0


func _finish_dialogue() -> void:
	set_process(false)
	hide()
	dialogue_finished.emit()
