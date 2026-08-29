extends CanvasLayer

signal countdown_finished

@onready var label: Label = $Label
@export var step_duration: float = 0.5
@export var start_hold_duration: float = 0.5
@export var fade_out_duration: float = 0.35


func _ready() -> void:
	label.modulate.a = 0.0
	set_process(false)


func play() -> void:
	label.modulate.a = 1.0
	label.text = ""
	var tween := create_tween()
	tween.tween_callback(_set_step.bind("3"))
	tween.tween_interval(step_duration)
	tween.tween_callback(_set_step.bind("2"))
	tween.tween_interval(step_duration)
	tween.tween_callback(_set_step.bind("1"))
	tween.tween_interval(step_duration)
	tween.tween_callback(_set_step.bind("START!"))
	tween.tween_interval(start_hold_duration)
	tween.tween_property(label, "modulate:a", 0.0, fade_out_duration)
	tween.tween_callback(_on_finished)


func _set_step(text: String) -> void:
	label.text = text
	label.modulate.a = 1.0


func _on_finished() -> void:
	countdown_finished.emit()
