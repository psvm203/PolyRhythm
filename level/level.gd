extends Node2D

@export var side_length: float = 100.0
@export var base_midpoint := Vector2(500, 600)
@export var sides_sequence: Array[int] = [3, 4, 3, 5, 3, 3, 3, 6, 4]
@export var outline_width: float = 2.0

@onready var player: Node2D = $Player
@onready var conductor: Node = $Conductor

var _shapes: Array[PackedVector2Array] = []
var _exit_edges: Array[PackedVector2Array] = []


func _ready() -> void:
	_build_shapes()
	queue_redraw()
	var path := build_path()
	player.setup(path)
	conductor.setup(build_note_indices(path))


func _draw() -> void:
	for index in _shapes.size():
		draw_colored_polygon(_shapes[index], _color_for_index(index))
		var outline := _shapes[index]
		outline.append(outline[0])
		draw_polyline(outline, Color.BLACK, outline_width, true)


func build_path() -> PackedVector2Array:
	var path := PackedVector2Array()
	if _shapes.is_empty():
		return path
	var entry: Vector2 = _exit_edges[0][0]
	path.append(entry)
	for index in _shapes.size():
		var poly := _shapes[index]
		var entry_index := _index_of(poly, entry)
		var is_last_shape := index >= _exit_edges.size()
		if is_last_shape:
			_append_final_loop(path, poly, entry_index, entry, _exit_edges[index - 1])
			break
		var chosen := _walk_to_exit(poly, entry_index, _exit_edges[index])
		for vertex_index in chosen:
			path.append(poly[vertex_index])
		entry = poly[chosen[chosen.size() - 1]]
	return path


func build_note_indices(path: PackedVector2Array) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index in range(1, path.size()):
		if _is_shared_vertex(path[index]):
			indices.append(index)
	return indices


func _is_shared_vertex(point: Vector2) -> bool:
	for edge in _exit_edges:
		if point.is_equal_approx(edge[0]) or point.is_equal_approx(edge[1]):
			return true
	return false


func _append_final_loop(
		path: PackedVector2Array,
		poly: PackedVector2Array,
		entry_index: int,
		entry: Vector2,
		entry_edge: PackedVector2Array,
) -> void:
	var partner := entry_edge[1] if entry.is_equal_approx(entry_edge[0]) else entry_edge[0]
	var next_vertex := poly[(entry_index + 1) % poly.size()]
	var direction := 1 if next_vertex.is_equal_approx(partner) else -1
	for step in range(1, poly.size()):
		path.append(poly[(entry_index + direction * step + poly.size()) % poly.size()])


func _walk_to_exit(
		poly: PackedVector2Array,
		entry_index: int,
		exit_edge: PackedVector2Array,
) -> Array[int]:
	var exit_left := _index_of(poly, exit_edge[0])
	var exit_right := _index_of(poly, exit_edge[1])
	var forward := _walk(poly, entry_index, 1, exit_left, exit_right)
	var backward := _walk(poly, entry_index, -1, exit_left, exit_right)
	return forward if forward.size() >= backward.size() else backward


func _walk(
		poly: PackedVector2Array,
		from_index: int,
		direction: int,
		target_a: int,
		target_b: int,
) -> Array[int]:
	var steps: Array[int] = []
	var current := from_index
	for step in poly.size():
		current = (current + direction + poly.size()) % poly.size()
		steps.append(current)
		if current == target_a or current == target_b:
			break
	return steps


func _index_of(poly: PackedVector2Array, point: Vector2) -> int:
	for i in poly.size():
		if poly[i].is_equal_approx(point):
			return i
	return -1


func _build_shapes() -> void:
	_shapes.clear()
	_exit_edges.clear()
	var base_half_offset := Vector2(side_length / 2.0, 0.0)
	var shape := _build_polygon(
		sides_sequence[0],
		base_midpoint - base_half_offset,
		base_midpoint + base_half_offset,
	)
	_shapes.append(shape)
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
		_exit_edges.append(PackedVector2Array([next_base_left, next_base_right]))
		shape = _build_polygon(sides_sequence[index], next_base_left, next_base_right)
		_shapes.append(shape)


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
