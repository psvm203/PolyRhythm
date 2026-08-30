extends Button

var sides: int


func setup(value: int) -> void:
	sides = value
	custom_minimum_size = Vector2(68, 58)
	tooltip_text = "%d각형 추가 · 숫자키 %d" % [sides, sides]
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.31
	var points := PackedVector2Array()
	for index in sides:
		var angle := -PI * 0.5 + TAU * index / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color("173d59"))
	for index in sides:
		draw_line(points[index], points[(index + 1) % sides], Color("48daca"), 2.5, true)
