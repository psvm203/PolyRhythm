extends RefCounted

func build(
		shapes: Array[PackedVector2Array],
		polygon_centers: PackedVector2Array,
		exit_edges: Array[PackedVector2Array],
		exit_edge_local_indices: PackedInt32Array,
) -> Dictionary:
	var sides_counts := PackedInt32Array()
	for shape in shapes:
		sides_counts.append(shape.size())
	var entrance_edges_world: Array[PackedVector2Array] = []
	var exit_angle_offsets := PackedFloat32Array()
	for index in shapes.size():
		var entrance: PackedVector2Array
		if index == 0:
			entrance = PackedVector2Array([shapes[0][shapes[0].size() - 1], shapes[0][0]])
		else:
			entrance = PackedVector2Array([exit_edges[index - 1][0], exit_edges[index - 1][1]])
		entrance_edges_world.append(entrance)
		exit_angle_offsets.append(
			_exit_angle_offset(shapes[index], polygon_centers[index], exit_edge_local_indices[index]),
		)
	return {
		"polygon_centers": polygon_centers,
		"sides_counts": sides_counts,
		"entrance_edges_world": entrance_edges_world,
		"exit_angle_offsets": exit_angle_offsets,
	}


func _exit_angle_offset(shape: PackedVector2Array, center: Vector2, exit_local_index: int) -> float:
	if shape.is_empty() or exit_local_index < 0 or exit_local_index + 1 >= shape.size():
		return 0.0
	var exit_a := shape[exit_local_index]
	var exit_b := shape[exit_local_index + 1]
	var midpoint := (exit_a + exit_b) * 0.5
	return (midpoint - center).angle()
