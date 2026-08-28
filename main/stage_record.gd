extends Control

@export var active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var disc_color := Color(0.035, 0.055, 0.12, 0.96) if active else Color(0.025, 0.04, 0.085, 0.88)
	draw_circle(center, radius, disc_color)
	for groove in range(7):
		var groove_radius := radius * (0.42 + groove * 0.075)
		var groove_color := Color(0.25, 0.32, 0.55, 0.16 if active else 0.09)
		draw_arc(center, groove_radius, 0.0, TAU, 80, groove_color, 1.0, true)
	if active:
		draw_arc(center, radius * 0.96, 0.15, 1.15, 48, Color(0.05, 0.92, 0.94, 0.9), 4.0, true)
		draw_arc(center, radius * 1.02, 0.0, TAU, 96, Color(0.05, 0.85, 0.92, 0.45), 2.0, true)
	var label_color := Color(0.04, 0.78, 0.88, 1.0) if active else Color(0.28, 0.32, 0.43, 1.0)
	draw_circle(center, radius * 0.30, label_color)
	draw_circle(center, radius * 0.055, Color("071126"))
