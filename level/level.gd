extends Node2D

@export var level_data: Resource
@export var side_length: float = 100.0
@export var base_midpoint := Vector2(500, 600)
@export var outline_width: float = 2.0
@export var faded_alpha: float = 0.3
@export var highlight_color := Color.WHITE
@export var highlight_width: float = 6.0
@export var highlight_glow_width: float = 14.0
@export_range(0.0, 1.0) var highlight_glow_alpha: float = 0.35

@onready var player: Node2D = $Player
@onready var conductor: Node = $Conductor
@onready var camera: Camera2D = $Camera

var _shapes: Array[PackedVector2Array] = []
var _exit_edges: Array[PackedVector2Array] = []
var _path: PackedVector2Array = PackedVector2Array()
var _shape_start_indices: PackedInt32Array = PackedInt32Array()
var _shape_alphas: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var result := ShapeFactory.new().build(level_data.sides_sequence, side_length, base_midpoint)
	_shapes = result["shapes"]
	_exit_edges = result["exit_edges"]
	var path_finder := PathFinder.new()
	var path_result := path_finder.build(_shapes, _exit_edges)
	_path = path_result["path"]
	_shape_start_indices = path_result["shape_start_indices"]
	conductor.seconds_per_edge = level_data.seconds_per_edge
	player.setup(_path)
	conductor.setup(path_result["note_indices"])
	camera.setup(player, _build_shape_centers(), _shape_start_indices)
	_shape_alphas.resize(_shapes.size())
	_shape_alphas.fill(1.0)
	queue_redraw()


func _build_shape_centers() -> PackedVector2Array:
	var centers := PackedVector2Array()
	for shape in _shapes:
		var center := Vector2.ZERO
		for point in shape:
			center += point
		if not shape.is_empty():
			center /= shape.size()
		centers.append(center)
	return centers


func _process(delta: float) -> void:
	var current := _current_shape()
	var step: float = delta / player.seconds_per_edge
	for index in _shape_alphas.size():
		var target := _alpha_for_shape(index, current)
		_shape_alphas[index] = move_toward(_shape_alphas[index], target, step)
	queue_redraw()


func _draw() -> void:
	for index in _shapes.size():
		var alpha := _shape_alphas[index]
		if alpha <= 0.001:
			continue
		var fill := _color_for_index(index)
		fill.a = alpha
		draw_colored_polygon(_shapes[index], fill)
		var outline := _shapes[index]
		outline.append(outline[0])
		draw_polyline(outline, Color(0.0, 0.0, 0.0, alpha), outline_width, true)
	_draw_active_edge()


func _draw_active_edge() -> void:
	var segment := _active_segment()
	if segment < 0:
		return
	var glow_color := highlight_color
	glow_color.a *= highlight_glow_alpha
	draw_line(_path[segment], _path[segment + 1], glow_color, highlight_glow_width, true)
	draw_line(_path[segment], _path[segment + 1], highlight_color, highlight_width, true)


func _active_segment() -> int:
	if _path.size() < 2 or player.seconds_per_edge <= 0.0:
		return -1
	var segment := int(player.get_elapsed() / player.seconds_per_edge)
	if segment >= _path.size() - 1:
		return -1
	return segment


func _alpha_for_shape(index: int, current: int) -> float:
	if index >= current:
		return 1.0
	return faded_alpha


func _current_shape() -> int:
	var segment := int(player.get_elapsed() / player.seconds_per_edge)
	var current := 0
	for index in _shape_start_indices.size():
		if _shape_start_indices[index] <= segment:
			current = index
	return current


func _color_for_index(index: int) -> Color:
	return Color.from_hsv(float(index) / level_data.sides_sequence.size(), 0.6, 1.0)
