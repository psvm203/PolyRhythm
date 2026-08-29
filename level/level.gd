extends Node2D

const PolygonChain = preload("res://level/geometry/polygon_chain.gd")

@export var level_data: Resource
@export var side_length: float = 100.0
@export var base_midpoint := Vector2(500, 600)
@export var outline_width: float = 2.0
@export var faded_alpha: float = 0.18
@export var fly_in_distance: float = 260.0
@export var transition_duration: float = 0.32
@export var spawn_fade_duration: float = 0.35

@onready var rotator: Node2D = $Rotator
@onready var conductor: Node = $Conductor
@onready var camera: Camera2D = $Camera
@onready var countdown: CanvasLayer = $CountdownOverlay
@onready var judgement: CanvasLayer = $JudgementOverlay

var _shapes: Array[PackedVector2Array] = []
var _polygon_centers: PackedVector2Array = PackedVector2Array()
var _sides_counts: PackedInt32Array = PackedInt32Array()
var _current_index: int = 0
var _current_started_at: float = 0.0


func _ready() -> void:
	var factory_result := ShapeFactory.new().build(level_data.sides_sequence, side_length, base_midpoint)
	_shapes = factory_result["shapes"]
	_polygon_centers = factory_result["polygon_centers"]
	_sides_counts = factory_result["sides_counts"]
	var chain_result := PolygonChain.new().build(
		_shapes,
		_polygon_centers,
		factory_result["exit_edges"],
		factory_result["exit_edge_local_indices"],
	)
	var start_offsets := _compute_start_offsets()
	rotator.setup(
		_shapes,
		_polygon_centers,
		_sides_counts,
		chain_result["entrance_edges_world"],
		chain_result["exit_angle_offsets"],
		level_data.bpm,
		start_offsets,
		transition_duration,
	)
	conductor.bpm = level_data.bpm
	conductor.setup(_compute_scheduled_judgment_times())
	camera.setup(rotator, _polygon_centers)
	rotator.polygon_advanced.connect(_on_polygon_advanced)
	if conductor != null:
		conductor.judged.connect(_on_judged)
	if countdown != null:
		countdown.countdown_finished.connect(_on_countdown_finished)
		countdown.play()
	queue_redraw()


func _on_judged(result: String, _polygon_index: int) -> void:
	if judgement != null:
		judgement.show_judgement(result)


func _on_countdown_finished() -> void:
	rotator.paused = false
	conductor.paused = false


func _process(_delta: float) -> void:
	queue_redraw()


func _on_polygon_advanced(_from_index: int, to_index: int) -> void:
	_current_index = to_index
	_current_started_at = Time.get_ticks_msec() / 1000.0


func _compute_start_offsets() -> PackedVector2Array:
	var offsets := PackedVector2Array()
	for index in _polygon_centers.size():
		var prev_center: Vector2
		if index == 0:
			prev_center = base_midpoint
		else:
			prev_center = _polygon_centers[index - 1]
		var current_center: Vector2 = _polygon_centers[index]
		var direction := current_center - prev_center
		if direction.length() < 0.0001:
			direction = Vector2(0.0, -1.0)
		else:
			direction = direction.normalized()
		offsets.append(direction * fly_in_distance)
	return offsets


func _compute_scheduled_judgment_times() -> PackedFloat32Array:
	var times := PackedFloat32Array()
	var cumulative: float = 0.0
	for sides in level_data.sides_sequence:
		var period: float = float(sides) * 120.0 / maxf(level_data.bpm, 0.0001)
		cumulative += period
		times.append(cumulative)
	return times


func _draw() -> void:
	if _shapes.is_empty():
		return
	for index in _current_index + 1:
		if index == _current_index:
			_draw_current_polygon(index)
		else:
			_draw_passive_polygon(index)


func _draw_current_polygon(index: int) -> void:
	var rotated: PackedVector2Array = rotator.get_rotated_polygon()
	if rotated.is_empty():
		return
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _current_started_at
	var spawn_alpha: float = clampf(elapsed / maxf(spawn_fade_duration, 0.0001), 0.0, 1.0)
	var landing_time: float = rotator.transition_duration
	# Visual cue centered around landing (±50ms). Player's tap anywhere in this window
	# registers as Perfect or Slow, never as Too Fast.
	var cue_start: float = maxf(0.0, landing_time - 0.050)
	var cue_end: float = landing_time + 0.050
	var pulse_scale: float = 1.0
	var pulse_flash: float = 0.0
	if elapsed >= cue_start and elapsed < cue_end:
		var cue_t: float = clampf((elapsed - cue_start) / (cue_end - cue_start), 0.0, 1.0)
		pulse_scale = 1.0 + sin(cue_t * PI) * 0.30
		pulse_flash = (1.0 - cue_t) * 0.6
	var fill := _color_for_index(index)
	fill.a *= spawn_alpha
	var flashed_fill := fill
	flashed_fill.r = clampf(fill.r + pulse_flash, 0.0, 1.0)
	flashed_fill.g = clampf(fill.g + pulse_flash, 0.0, 1.0)
	flashed_fill.b = clampf(fill.b + pulse_flash, 0.0, 1.0)
	if pulse_scale != 1.0 or pulse_flash > 0.0:
		var center: Vector2 = _polygon_centers[index] + rotator.get_current_offset()
		var scaled := PackedVector2Array()
		scaled.resize(rotated.size())
		for i in rotated.size():
			scaled[i] = center + (rotated[i] - center) * pulse_scale
		draw_colored_polygon(scaled, flashed_fill)
		var outline: PackedVector2Array = scaled.duplicate()
		outline.append(outline[0])
		var outline_color := Color.BLACK
		outline_color.a *= spawn_alpha
		draw_polyline(outline, outline_color, maxf(outline_width * spawn_alpha, 0.5), true)
	else:
		draw_colored_polygon(rotated, fill)
		var outline: PackedVector2Array = rotated.duplicate()
		outline.append(outline[0])
		var outline_color := Color.BLACK
		outline_color.a *= spawn_alpha
		draw_polyline(outline, outline_color, maxf(outline_width * spawn_alpha, 0.5), true)


func _draw_passive_polygon(index: int) -> void:
	var shape: PackedVector2Array = _shapes[index]
	var fill := _color_for_index(index)
	fill.a = faded_alpha
	draw_colored_polygon(shape, fill)
	var outline: PackedVector2Array = shape.duplicate()
	outline.append(outline[0])
	var outline_color := Color(0.0, 0.0, 0.0, faded_alpha)
	draw_polyline(outline, outline_color, outline_width, true)


func _color_for_index(index: int) -> Color:
	if level_data.sides_sequence.is_empty():
		return Color.WHITE
	return Color.from_hsv(float(index) / level_data.sides_sequence.size(), 0.6, 1.0)
