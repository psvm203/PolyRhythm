extends Control

const CYAN := Color("19e0db")
const MAGENTA := Color("ed1671")
const SHARED_EDGE_COLOR := Color(0.15, 1.0, 0.95, 1.0)
const SHARED_EDGE_WIDTH := 5.0
const SHARED_EDGE_GLOW_WIDTH := 15.0

var _scheduled_beats: Array[int] = []
var _interval_usec := 600_000
var _now_usec := 0
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func reset() -> void:
	_scheduled_beats.clear()
	_now_usec = 0
	_active = false
	queue_redraw()


func set_timeline(scheduled_beats: Array[int], interval_usec: int) -> void:
	_scheduled_beats = scheduled_beats.duplicate()
	_interval_usec = interval_usec
	_active = true
	queue_redraw()


func update_clock(now_usec: int) -> void:
	_now_usec = now_usec
	queue_redraw()


func finish() -> void:
	_active = false
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var target_center := center + Vector2(105.0, 0.0)
	var target_radius := 66.0
	# Match the triangle's vertical edge (sqrt(3) * radius) to the square's
	# vertical edge (sqrt(2) * radius) at the contact pose.
	var triangle_radius := target_radius * sqrt(2.0 / 3.0)
	var idle_center := Vector2(center.x - 155.0, center.y)
	_draw_glow(target_center, target_radius)
	_draw_polygon(target_center, target_radius, 4, PI / 4.0, Color(0.08, 0.24, 0.38, 0.9), CYAN, 3.0)
	if not _active or _scheduled_beats.is_empty():
		_draw_triangle(idle_center, triangle_radius, 0.0, Color(0.34, 0.16, 0.48, 0.9), MAGENTA)
		_draw_shared_edge(entrance_edge(idle_center, triangle_radius, 0.0), 0.82)
		return
	var beat_index := _current_beat_index(_now_usec)
	var contact_usec: int = _scheduled_beats[beat_index]
	var progress := approach_progress(_now_usec, contact_usec, _interval_usec)
	var target_edge_x := target_center.x - cos(PI / 4.0) * target_radius
	var contact_x := target_edge_x - triangle_radius * 0.5
	var triangle_center := transition_center(progress, idle_center, Vector2(contact_x, center.y))
	var triangle_rotation := rotation_angle(progress)
	var contact_strength := 1.0 - clampf(absf(float(_now_usec - contact_usec)) / 120_000.0, 0.0, 1.0)
	if contact_strength > 0.0:
		draw_circle(Vector2(target_edge_x, center.y), 20.0 + contact_strength * 22.0, Color(0.15, 1.0, 0.92, contact_strength * 0.22))
	_draw_triangle(triangle_center, triangle_radius, triangle_rotation, Color(0.34, 0.16, 0.48, 0.95), MAGENTA)
	_draw_shared_edge(entrance_edge(triangle_center, triangle_radius, triangle_rotation), 0.82 + contact_strength * 0.18)


func _current_beat_index(now_usec: int) -> int:
	for index in _scheduled_beats.size():
		if now_usec <= _scheduled_beats[index] + 120_000:
			return index
	return _scheduled_beats.size() - 1


static func approach_progress(now_usec: int, contact_usec: int, interval_usec: int) -> float:
	var duration := maxi(interval_usec, 1)
	return clampf(float(now_usec - (contact_usec - duration)) / duration, 0.0, 1.0)


static func rotation_angle(progress: float) -> float:
	return clampf(progress, 0.0, 1.0) * TAU


static func transition_offset(progress: float, start_offset: Vector2) -> Vector2:
	return start_offset.lerp(Vector2.ZERO, clampf(progress, 0.0, 1.0))


static func transition_center(progress: float, start_center: Vector2, contact_center: Vector2) -> Vector2:
	return start_center.lerp(contact_center, clampf(progress, 0.0, 1.0))


static func triangle_points(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for angle in [-PI / 3.0, PI / 3.0, PI]:
		points.append(center + Vector2.from_angle(angle + rotation) * radius)
	return points


static func entrance_edge(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := triangle_points(center, radius, rotation)
	return PackedVector2Array([points[0], points[1]])


func _draw_triangle(center: Vector2, radius: float, rotation: float, fill: Color, outline: Color) -> void:
	var points := triangle_points(center, radius, rotation)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, outline, 4.0, true)


func _draw_shared_edge(edge: PackedVector2Array, strength: float) -> void:
	if edge.size() < 2:
		return
	var glow := SHARED_EDGE_COLOR
	glow.a = 0.28 * clampf(strength, 0.0, 1.0)
	var core := SHARED_EDGE_COLOR
	core.a *= clampf(strength, 0.0, 1.0)
	draw_line(edge[0], edge[1], glow, SHARED_EDGE_GLOW_WIDTH, true)
	draw_line(edge[0], edge[1], core, SHARED_EDGE_WIDTH, true)


func _draw_polygon(center: Vector2, radius: float, sides: int, rotation: float, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in sides:
		points.append(center + Vector2.from_angle(rotation + TAU * float(index) / sides) * radius)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, outline, width, true)


func _draw_glow(center: Vector2, radius: float) -> void:
	for ring in range(6, 0, -1):
		draw_circle(center, radius + ring * 8.0, Color(0.05, 0.8, 0.9, 0.018))
