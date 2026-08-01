extends Node

signal judged(result: String, note_index: int)

@export var seconds_per_edge: float = 0.5
@export var perfect_window: float = 0.06
@export var good_window: float = 0.12
@onready var player: Node2D = $"../Player"

var _note_indices: PackedInt32Array = PackedInt32Array()
var _next_note: int = 0


func setup(note_indices: PackedInt32Array) -> void:
	player.seconds_per_edge = seconds_per_edge
	_note_indices = note_indices
	_next_note = 0


func _process(_delta: float) -> void:
	var elapsed: float = player.get_elapsed()
	while _next_note < _note_indices.size() and elapsed > _note_time(_next_note) + good_window:
		_emit_result("Miss", _note_indices[_next_note])
		_next_note += 1


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("tap"):
		return
	if _next_note >= _note_indices.size():
		return
	var elapsed: float = player.get_elapsed()
	var delta := absf(elapsed - _note_time(_next_note))
	if delta <= perfect_window:
		_emit_result("Perfect", _note_indices[_next_note])
	elif delta <= good_window:
		_emit_result("Good", _note_indices[_next_note])
	else:
		return
	_next_note += 1


func _note_time(note: int) -> float:
	return _note_indices[note] * seconds_per_edge


func _emit_result(result: String, note_index: int) -> void:
	print("Note %d: %s" % [_next_note + 1, result])
	judged.emit(result, note_index)
