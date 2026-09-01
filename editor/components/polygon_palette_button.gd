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
	var label := str(sides)
	var font := ThemeDB.fallback_font
	var font_size := 16
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-label_size.x * 0.5, label_size.y * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("ecfffc"))
