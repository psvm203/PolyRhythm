class_name ContactSolver
extends RefCounted


static func segment_gap(first: PackedVector2Array, second: PackedVector2Array) -> float:
	if first.size() < 2 or second.size() < 2:
		return INF
	if Geometry2D.segment_intersects_segment(first[0], first[1], second[0], second[1]) != null:
		return 0.0
	var gaps := PackedFloat32Array([
		first[0].distance_to(Geometry2D.get_closest_point_to_segment(first[0], second[0], second[1])),
		first[1].distance_to(Geometry2D.get_closest_point_to_segment(first[1], second[0], second[1])),
		second[0].distance_to(Geometry2D.get_closest_point_to_segment(second[0], first[0], first[1])),
		second[1].distance_to(Geometry2D.get_closest_point_to_segment(second[1], first[0], first[1])),
	])
	var result := INF
	for gap in gaps:
		result = minf(result, gap)
	return result


static func interpolate_contact_time(
	previous_time: float,
	current_time: float,
	previous_gap: float,
	current_gap: float,
	threshold: float = 0.0,
) -> float:
	if current_time <= previous_time:
		return current_time
	if not is_finite(previous_gap) or previous_gap <= threshold:
		return previous_time
	if current_gap > threshold or current_gap >= previous_gap:
		return current_time
	var ratio := clampf((previous_gap - threshold) / (previous_gap - current_gap), 0.0, 1.0)
	return lerpf(previous_time, current_time, ratio)
