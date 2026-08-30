extends Control

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5 + Vector2(0.0, sin(_time * 2.0) * 3.0)
	var pulse := 1.0 + sin(_time * 2.8) * 0.025
	var glow := Color(0.12, 0.95, 0.92, 0.10)
	draw_circle(center, 58.0 * pulse, glow)
	draw_circle(center, 45.0 * pulse, Color(0.035, 0.12, 0.22, 0.98))
	draw_arc(center, 45.0 * pulse, 0.0, TAU, 64, Color(0.16, 1.0, 0.94, 0.9), 3.0, true)

	var left_fin := PackedVector2Array([
		center + Vector2(-36.0, -25.0),
		center + Vector2(-59.0, -43.0),
		center + Vector2(-47.0, -9.0),
	])
	var right_fin := PackedVector2Array([
		center + Vector2(36.0, -25.0),
		center + Vector2(59.0, -43.0),
		center + Vector2(47.0, -9.0),
	])
	draw_colored_polygon(left_fin, Color(0.48, 0.30, 1.0, 0.9))
	draw_colored_polygon(right_fin, Color(0.48, 0.30, 1.0, 0.9))

	var blink := absf(sin(_time * 0.72)) > 0.985
	if blink:
		draw_line(center + Vector2(-20.0, -4.0), center + Vector2(-8.0, -4.0), Color(0.85, 1.0, 1.0), 3.0, true)
		draw_line(center + Vector2(8.0, -4.0), center + Vector2(20.0, -4.0), Color(0.85, 1.0, 1.0), 3.0, true)
	else:
		draw_circle(center + Vector2(-14.0, -4.0), 4.0, Color(0.85, 1.0, 1.0))
		draw_circle(center + Vector2(14.0, -4.0), 4.0, Color(0.85, 1.0, 1.0))
	draw_arc(center + Vector2(0.0, 5.0), 13.0, 0.28, PI - 0.28, 18, Color(0.95, 0.45, 0.85), 2.5, true)

	for bar in 5:
		var height := 5.0 + (sin(_time * 4.0 + bar * 0.9) + 1.0) * 4.0
		var x := center.x - 20.0 + bar * 10.0
		draw_line(Vector2(x, center.y + 29.0), Vector2(x, center.y + 29.0 - height), Color(0.95, 0.30, 0.72, 0.85), 3.0, true)
