extends CanvasLayer

signal dialogue_finished

@export var characters_per_second: float = 42.0

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
	hide()
	set_process(false)
	skip_button.pressed.connect(skip)


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
	if event.is_action_pressed("tap") or event.is_action_pressed("ui_accept"):
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
	dialogue_label.text = _lines[_line_index]
	dialogue_label.visible_characters = 0
	_visible_characters_float = 0.0
	_typing = true
	continue_label.modulate.a = 0.35
	progress_label.text = "%d / %d" % [_line_index + 1, _lines.size()]


func _finish_typing() -> void:
	_typing = false
	dialogue_label.visible_characters = -1
	continue_label.modulate.a = 1.0


func _finish_dialogue() -> void:
	set_process(false)
	hide()
	dialogue_finished.emit()
