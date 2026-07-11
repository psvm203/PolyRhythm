class_name PathFinder
extends RefCounted

func build(shapes: Array[PackedVector2Array], exit_edges: Array[PackedVector2Array]) -> Dictionary:
	var path := PackedVector2Array()
	var shape_start_indices := PackedInt32Array()
	if shapes.is_empty():
		return { "path": path, "shape_start_indices": shape_start_indices }
	var entry: Vector2 = exit_edges[0][0]
	path.append(entry)
	for index in shapes.size():
		shape_start_indices.append(path.size() - 1)
		var poly := shapes[index]
		var entry_index := _index_of(poly, entry)
		var is_last_shape := index >= exit_edges.size()
		if is_last_shape:
			_append_final_loop(path, poly, entry_index, entry, exit_edges[index - 1])
			break
		var chosen := _walk_to_exit(poly, entry_index, exit_edges[index])
		for vertex_index in chosen:
			path.append(poly[vertex_index])
		entry = poly[chosen[chosen.size() - 1]]
	return { "path": path, "shape_start_indices": shape_start_indices }


func build_note_indices(
		path: PackedVector2Array,
		exit_edges: Array[PackedVector2Array],
) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index in range(1, path.size()):
		if _is_shared_vertex(path[index], exit_edges):
			indices.append(index)
	return indices


func _is_shared_vertex(point: Vector2, exit_edges: Array[PackedVector2Array]) -> bool:
	for edge in exit_edges:
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
