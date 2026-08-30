extends Node2D

const PolygonChain = preload("res://level/geometry/polygon_chain.gd")
const RunStateScript = preload("res://level/run_state.gd")
const ProgressStoreScript = preload("res://level/progress_store.gd")
const LevelDataScript = preload("res://level/data/level_data.gd")
const AudioStreamLoaderScript = preload("res://level/audio/audio_stream_loader.gd")
const STAGE_DATA := {
	1: "res://level/data/level_1.yaml",
	2: "res://level/data/level_2.yaml",
	3: "res://level/data/level_3.yaml",
}
const MAIN_SCENE := "res://main/main_screen.tscn"
const LEVEL_EDITOR_SCENE := "res://editor/level_editor.tscn"
const NEON_PALETTE := [
	Color("20e3df"),
	Color("348cff"),
	Color("7657ff"),
	Color("c14cff"),
	Color("f044a7"),
	Color("35d6a0"),
]

signal level_finished(stats: Dictionary, completed: bool, rank: String)

@export var side_length: float = 100.0
@export var base_midpoint := Vector2(500, 600)
@export var outline_width: float = 2.0
@export var faded_alpha: float = 0.18
@export_range(0.0, 1.0) var starter_triangle_alpha: float = 0.32
@export_range(0.0, 1.0) var current_fill_alpha: float = 0.86
@export_range(0.0, 1.0) var inner_highlight_alpha: float = 0.24
@export var polygon_glow_width: float = 11.0
@export_range(0.0, 0.2) var landing_pulse_scale: float = 0.06
@export var fly_in_distance: float = 260.0
@export var transition_duration: float = 0.32
@export var spawn_fade_duration: float = 0.35
@export var shared_edge_color := Color(0.15, 1.0, 0.95, 1.0)
@export var shared_edge_width: float = 5.0
@export var shared_edge_glow_width: float = 15.0

@onready var rotator: Node2D = $Rotator
@onready var conductor: Node = $Conductor
@onready var camera: Camera2D = $Camera
@onready var countdown: CanvasLayer = $CountdownOverlay
@onready var judgement: CanvasLayer = $JudgementOverlay
@onready var music: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var pause_overlay: CanvasLayer = $PauseOverlay
@onready var dialogue_overlay: CanvasLayer = $DialogueOverlay
@onready var gameplay_hud: CanvasLayer = $GameplayHUD
@onready var result_overlay: CanvasLayer = $ResultOverlay

var _shapes: Array[PackedVector2Array] = []
var _starter_triangle: PackedVector2Array = PackedVector2Array()
var _polygon_centers: PackedVector2Array = PackedVector2Array()
var _sides_counts: PackedInt32Array = PackedInt32Array()
var _current_index: int = 0
var _current_started_at: float = 0.0
var _tutorial_preview_active: bool = false
var _run_state: RunState = RunStateScript.new()
var _level_ended: bool = false
var _level_sequence: Array[int] = []
var _boss_health: int = 0
var level_data: LevelData
var _is_custom_level := false


func _ready() -> void:
	var data_path: String = ProgressStoreScript.custom_level_path
	_is_custom_level = not data_path.is_empty()
	if data_path.is_empty():
		data_path = STAGE_DATA.get(ProgressStoreScript.selected_stage, STAGE_DATA[1])
	level_data = LevelDataScript.from_yaml(data_path)
	_level_sequence = level_data.expanded_sequence()
	music.stream = AudioStreamLoaderScript.load_stream(level_data.music_path)
	if music.stream == null:
		push_error("Level music not found: %s" % level_data.music_path)
	var factory := ShapeFactory.new()
	var factory_result := factory.build(_level_sequence, side_length, base_midpoint)
	_shapes = factory_result["shapes"]
	var base_half_offset := Vector2(side_length / 2.0, 0.0)
	# Reverse the first polygon's base edge so the fixed triangle sits on the opposite side.
	_starter_triangle = factory.build_polygon_on_edge(
		3,
		base_midpoint + base_half_offset,
		base_midpoint - base_half_offset,
	)
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
		start_offsets,
		transition_duration,
	)
	conductor.setup(_compute_scheduled_judgment_times())
	camera.setup(rotator, _polygon_centers)
	rotator.polygon_advanced.connect(_on_polygon_advanced)
	if conductor != null:
		conductor.judged.connect(_on_judged)
	_run_state.changed.connect(_on_stats_changed)
	_run_state.failed.connect(_on_run_failed)
	_run_state.setup(_level_sequence.size())
	_boss_health = level_data.boss_health
	gameplay_hud.setup_boss(level_data.boss_name, _boss_health)
	if countdown != null:
		countdown.countdown_finished.connect(_on_countdown_finished)
	if pause_overlay != null:
		pause_overlay.resume_requested.connect(_set_game_paused.bind(false))
		pause_overlay.exit_requested.connect(_exit_test_play)
		pause_overlay.set_exit_visible(_is_custom_level)
	if dialogue_overlay != null:
		dialogue_overlay.dialogue_finished.connect(_start_countdown)
	if result_overlay != null:
		result_overlay.retry_requested.connect(_retry_level)
		result_overlay.stage_select_requested.connect(_return_to_stage_select)
	if not level_data.tutorial_lines.is_empty():
		_tutorial_preview_active = true
		rotator.snap_to_target()
		dialogue_overlay.play(level_data.tutorial_lines, level_data.tutorial_speaker)
	else:
		_start_countdown()
	queue_redraw()


func _start_countdown() -> void:
	if _tutorial_preview_active:
		_tutorial_preview_active = false
		rotator.restart_current_transition()
		_current_started_at = Time.get_ticks_msec() / 1000.0
	if countdown != null:
		countdown.play()


func _on_judged(result: String, polygon_index: int) -> void:
	var guard_note: bool = level_data.is_guard_note(polygon_index)
	var resolved_result := result
	if guard_note and result != "Perfect" and result != "Too Fast":
		resolved_result = "Too Slow"
	if judgement != null:
		judgement.show_judgement("BLOCKED" if guard_note and result != "Perfect" and result != "Too Fast" else result)
	if _boss_health > 0:
		_boss_health = maxi(0, _boss_health - level_data.boss_damage(resolved_result, guard_note))
		gameplay_hud.update_boss(_boss_health, level_data.is_guard_note(polygon_index + 1))
	_run_state.apply_judgment(resolved_result, polygon_index)
	if not _level_ended and _run_state.resolved_notes >= _run_state.total_notes:
		_finish_level(_boss_health <= 0)


func _on_stats_changed(stats: Dictionary) -> void:
	if gameplay_hud != null:
		gameplay_hud.update_stats(stats)


func _on_run_failed() -> void:
	_finish_level(false)


func _finish_level(completed: bool) -> void:
	if _level_ended:
		return
	_level_ended = true
	if completed and not _is_custom_level:
		ProgressStoreScript.unlock_next_stage(ProgressStoreScript.selected_stage)
	conductor.pause_clock()
	rotator.paused = true
	if music != null:
		music.stop()
	var stats := _run_state.snapshot()
	var final_rank := _run_state.rank(completed)
	if not _is_custom_level:
		ProgressStoreScript.record_run(ProgressStoreScript.selected_stage, stats, final_rank, completed)
	if result_overlay != null:
		result_overlay.show_result(stats, completed, final_rank)
	level_finished.emit(stats, completed, final_rank)


func _retry_level() -> void:
	get_tree().reload_current_scene()


func _return_to_stage_select() -> void:
	if _is_custom_level:
		get_tree().change_scene_to_file(LEVEL_EDITOR_SCENE)
		return
	ProgressStoreScript.show_stage_select_on_load = true
	get_tree().change_scene_to_file(MAIN_SCENE)


func _exit_test_play() -> void:
	if not _is_custom_level:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_EDITOR_SCENE)


func _on_countdown_finished() -> void:
	_current_started_at = Time.get_ticks_msec() / 1000.0
	rotator.paused = false
	conductor.start()
	if music != null:
		var stream_length := music.stream.get_length() if music.stream != null else 0.0
		music.play(level_data.clamped_music_start_offset(stream_length))


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _level_ended and not get_tree().paused:
		_set_game_paused(true)
		get_viewport().set_input_as_handled()


func _set_game_paused(value: bool) -> void:
	if value:
		conductor.pause_clock()
		music.stream_paused = true
		pause_overlay.open()
		get_tree().paused = true
	else:
		get_tree().paused = false
		pause_overlay.close()
		music.stream_paused = false
		conductor.resume_clock()


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
	for sides in _level_sequence:
		var period: float = float(sides) * 120.0 / maxf(level_data.bpm, 0.0001)
		cumulative += period
		times.append(cumulative)
	return times


func _draw() -> void:
	if _shapes.is_empty():
		return
	_draw_glass_polygon(_starter_triangle, 5, starter_triangle_alpha, false, 0.0)
	for index in _current_index + 1:
		if index == _current_index:
			_draw_current_polygon(index)
		else:
			_draw_passive_polygon(index)
	_draw_shared_entrance_edge(_current_index)


func _draw_shared_entrance_edge(index: int) -> void:
	# The fixed starter triangle acts as the previous polygon for index zero.
	if index < 0:
		return
	var edge: PackedVector2Array = rotator.get_rotated_entrance_edge_world()
	if edge.size() < 2:
		return
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _current_started_at
	var spawn_t := clampf(elapsed / maxf(spawn_fade_duration, 0.0001), 0.0, 1.0)
	var spawn_alpha := 1.0 - pow(1.0 - spawn_t, 3.0)
	var pulse_strength := _landing_pulse_strength(elapsed, rotator.transition_duration)
	if pulse_strength > 0.0:
		var center: Vector2 = _polygon_centers[index] + rotator.get_current_offset()
		edge = _scaled_polygon(edge, center, 1.0 + pulse_strength * landing_pulse_scale)
	var pulse := 0.82 + sin(elapsed * 7.0) * 0.18
	var glow_color := shared_edge_color
	glow_color.a = 0.28 * spawn_alpha * pulse
	var core_color := shared_edge_color
	core_color.a *= spawn_alpha
	draw_line(edge[0], edge[1], glow_color, shared_edge_glow_width, true)
	draw_line(edge[0], edge[1], core_color, shared_edge_width, true)


func _draw_current_polygon(index: int) -> void:
	var rotated: PackedVector2Array = rotator.get_rotated_polygon()
	if rotated.is_empty():
		return
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _current_started_at
	var spawn_t: float = clampf(elapsed / maxf(spawn_fade_duration, 0.0001), 0.0, 1.0)
	var spawn_alpha: float = 1.0 - pow(1.0 - spawn_t, 3.0)
	# A restrained sheen marks visual landing without obscuring the polygon shape.
	var pulse_strength := _landing_pulse_strength(elapsed, rotator.transition_duration)
	var pulse_scale: float = 1.0 + pulse_strength * landing_pulse_scale
	var displayed := rotated
	if pulse_scale != 1.0:
		var center: Vector2 = _polygon_centers[index] + rotator.get_current_offset()
		displayed = _scaled_polygon(rotated, center, pulse_scale)
	_draw_glass_polygon(displayed, index, spawn_alpha * current_fill_alpha, true, pulse_strength)


func _draw_passive_polygon(index: int) -> void:
	_draw_glass_polygon(_shapes[index], index, faded_alpha, false, 0.0)


func _draw_glass_polygon(
		points: PackedVector2Array,
		index: int,
		alpha: float,
		is_current: bool,
		pulse_strength: float,
) -> void:
	if points.size() < 3:
		return
	var center := _polygon_center(points)
	var base := _color_for_index(index)
	var center_color := base.lightened(0.22 + pulse_strength * 0.16)
	center_color.a = alpha
	var edge_color := base.lerp(Color("071126"), 0.48)
	edge_color.a = alpha * 0.78
	for vertex in points.size():
		var next := (vertex + 1) % points.size()
		draw_polygon(
			PackedVector2Array([center, points[vertex], points[next]]),
			PackedColorArray([center_color, edge_color, edge_color]),
		)

	var outline := points.duplicate()
	outline.append(points[0])
	if is_current:
		var glow := base.lightened(0.30)
		glow.a = alpha * (0.16 + pulse_strength * 0.14)
		draw_polyline(outline, glow, polygon_glow_width + pulse_strength * 4.0, true)
	var rim := base.lightened(0.48 if is_current else 0.12)
	rim.a = alpha * (0.95 if is_current else 0.48)
	draw_polyline(outline, rim, maxf(outline_width, 1.0), true)

	var inset := PackedVector2Array()
	for point in points:
		inset.append(center.lerp(point, 0.72))
	inset.append(inset[0])
	var inner_color := Color.WHITE
	inner_color.a = inner_highlight_alpha * alpha * (1.0 if is_current else 0.22)
	draw_polyline(inset, inner_color, 1.0, true)


func _polygon_center(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / points.size()


func _scaled_polygon(points: PackedVector2Array, center: Vector2, scale_value: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	scaled.resize(points.size())
	for index in points.size():
		scaled[index] = center + (points[index] - center) * scale_value
	return scaled


func _landing_pulse_strength(elapsed: float, landing_time: float) -> float:
	var cue_start: float = maxf(0.0, landing_time - 0.050)
	var cue_end: float = landing_time + 0.050
	if elapsed < cue_start or elapsed >= cue_end:
		return 0.0
	var cue_t := clampf((elapsed - cue_start) / (cue_end - cue_start), 0.0, 1.0)
	return sin(cue_t * PI)


func _color_for_index(index: int) -> Color:
	if level_data != null and level_data.is_guard_note(index):
		return Color("ff294f")
	if NEON_PALETTE.is_empty():
		return Color.WHITE
	return NEON_PALETTE[index % NEON_PALETTE.size()]
