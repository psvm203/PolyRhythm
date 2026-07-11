class_name ShapeFactory
extends RefCounted

func build(sides_sequence: Array[int], side_length: float, base_midpoint: Vector2) -> Dictionary:
	var shapes: Array[PackedVector2Array] = []
	var exit_edges: Array[PackedVector2Array] = []
	var base_half_offset := Vector2(side_length / 2.0, 0.0)
	var shape := _build_polygon(
		sides_sequence[0],
		base_midpoint - base_half_offset,
		base_midpoint + base_half_offset,
	)
	shapes.append(shape)
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
		exit_edges.append(PackedVector2Array([next_base_left, next_base_right]))
		shape = _build_polygon(sides_sequence[index], next_base_left, next_base_right)
		shapes.append(shape)
	return { "shapes": shapes, "exit_edges": exit_edges }


func _build_polygon(side_count: int, base_left: Vector2, base_right: Vector2) -> PackedVector2Array:
	var edge := base_right - base_left
	var radius := edge.length() / (2.0 * sin(TAU / (2.0 * side_count)))
	var apothem := radius * cos(TAU / (2.0 * side_count))
	var center := (base_left + base_right) * 0.5 + edge.rotated(-TAU / 4).normalized() * apothem
	var points := PackedVector2Array()
	for i in side_count:
		points.append(center + (base_left - center).rotated(i * TAU / side_count))
	return points
