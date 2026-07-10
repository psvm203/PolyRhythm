extends Node2D

@export var side_length: float = 100.0
@export var base_midpoint := Vector2(500, 600)
@export var sides_sequence: Array[int] = [3, 4, 3, 5, 3, 3, 3, 6, 4]


func _draw() -> void:
	var base_half_offset := Vector2(side_length / 2.0, 0.0)
	var shape := _build_polygon(
		sides_sequence[0],
		base_midpoint - base_half_offset,
		base_midpoint + base_half_offset,
	)
	draw_colored_polygon(shape, _color_for_index(0))
	for index in range(1, sides_sequence.size()):
		var use_left_edge := index % 2 == 1
		var next_base_left: Vector2
		var next_base_right: Vector2
		if use_left_edge:
			next_base_left = shape[0]
			next_base_right = shape[1]
		else:
			next_base_left = shape[shape.size() - 2]
			next_base_right = shape[shape.size() - 1]
		shape = _build_polygon(sides_sequence[index], next_base_left, next_base_right)
		draw_colored_polygon(shape, _color_for_index(index))


func _color_for_index(index: int) -> Color:
	return Color.from_hsv(float(index) / sides_sequence.size(), 0.6, 1.0)


func _build_polygon(side_count: int, base_left: Vector2, base_right: Vector2) -> PackedVector2Array:
	var edge := base_right - base_left
	var radius := edge.length() / (2.0 * sin(TAU / (2.0 * side_count)))
	var apothem := radius * cos(TAU / (2.0 * side_count))
	var center := (base_left + base_right) * 0.5 + edge.rotated(-TAU / 4).normalized() * apothem
	var points := PackedVector2Array()
	for i in side_count:
		points.append(center + (base_left - center).rotated(i * TAU / side_count))
	return points
