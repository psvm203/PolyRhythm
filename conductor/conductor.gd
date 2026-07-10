extends Node

signal judged(result: String, beat_index: int)

@export var seconds_per_edge: float = 0.5
@export var perfect_window: float = 0.06
@export var good_window: float = 0.12

@onready var player: Node2D = get_parent().get_node("Player")

var _beat_count: int = 0
var _next_beat: int = 1


func setup(path: PackedVector2Array) -> void:
	player.seconds_per_edge = seconds_per_edge
	_beat_count = path.size() - 1
	_next_beat = 1


func _process(_delta: float) -> void:
	var elapsed: float = player.get_elapsed()
	while _next_beat <= _beat_count and elapsed > _beat_time(_next_beat) + good_window:
		_emit_result("Miss", _next_beat)
		_next_beat += 1


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("tap"):
		return
	if _next_beat > _beat_count:
		return
	var elapsed: float = player.get_elapsed()
	var delta := absf(elapsed - _beat_time(_next_beat))
	if delta <= perfect_window:
		_emit_result("Perfect", _next_beat)
	elif delta <= good_window:
		_emit_result("Good", _next_beat)
	else:
		return
	_next_beat += 1


func _beat_time(beat_index: int) -> float:
	return beat_index * seconds_per_edge


func _emit_result(result: String, beat_index: int) -> void:
	print("Beat %d: %s" % [beat_index, result])
	judged.emit(result, beat_index)
