extends CanvasLayer

@onready var label: Label = $Label
@export var display_duration: float = 0.55
@export var fade_duration: float = 0.35

var _tween: Tween = null


func _ready() -> void:
	label.modulate.a = 0.0


func show_judgement(result: String) -> void:
	label.text = result
	var color := _color_for(result)
	label.modulate = Color(color.r, color.g, color.b, 1.0)
	label.scale = Vector2.ONE
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(label, "scale", Vector2.ONE * 1.15, 0.08)
	_tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	_tween.tween_interval(display_duration)
	_tween.tween_property(label, "modulate:a", 0.0, fade_duration)


func _color_for(result: String) -> Color:
	match result:
		"Perfect":
			return Color(1.0, 0.92, 0.3, 1.0)
		"Fast":
			return Color(0.85, 1.0, 0.7, 1.0)
		"Slow":
			return Color(0.7, 0.85, 1.0, 1.0)
		"Good":
			return Color(0.7, 0.95, 1.0, 1.0)
		"Miss":
			return Color(0.95, 0.4, 0.45, 1.0)
		"Too Fast":
			return Color(0.6, 0.6, 0.85, 1.0)
		"Too Slow":
			return Color(0.85, 0.5, 0.5, 1.0)
		"BLOCKED":
			return Color(1.0, 0.18, 0.3, 1.0)
	return Color.WHITE
