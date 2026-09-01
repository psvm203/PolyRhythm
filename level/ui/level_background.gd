extends Control

const CYAN := Color("19e0db")
const MAGENTA := Color("ed1671")

var _motion_time: float = 0.0
var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _bass: float = 0.0
var _mid: float = 0.0
var _treble: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _process(delta: float) -> void:
	_motion_time += delta
	_update_audio_response(delta)
	queue_redraw()


func _update_audio_response(delta: float) -> void:
	if _analyzer == null:
		var bus_index := AudioServer.get_bus_index(&"MenuMusic")
		if bus_index < 0:
			return
		_analyzer = AudioServer.get_bus_effect_instance(
			bus_index,
			0,
		) as AudioEffectSpectrumAnalyzerInstance
	if _analyzer == null:
		return
	_bass = _smoothed_energy(_bass, _frequency_energy(35.0, 180.0), delta, 10.0)
	_mid = _smoothed_energy(_mid, _frequency_energy(180.0, 2200.0), delta, 8.0)
	_treble = _smoothed_energy(_treble, _frequency_energy(2200.0, 9000.0), delta, 12.0)


func _frequency_energy(from_hz: float, to_hz: float) -> float:
	var magnitude := _analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	var amplitude := maxf(magnitude.x, magnitude.y)
	if amplitude <= 0.000001:
		return 0.0
	return clampf((linear_to_db(amplitude) + 55.0) / 45.0, 0.0, 1.0)


func _smoothed_energy(current: float, target: float, delta: float, speed: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))


func _draw() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Color("071126"))
	_draw_glow(view)
	_draw_grid(view)
	_draw_orbits(view)
	_draw_particles(view)


func _draw_glow(view: Vector2) -> void:
	var upper_center := Vector2(view.x * 0.52, view.y * 0.34)
	upper_center += Vector2(sin(_motion_time * 0.7) * _mid * 12.0, cos(_motion_time * 0.55) * _bass * 8.0)
	for ring in range(40, 0, -1):
		var ratio := float(ring) / 40.0
		draw_circle(upper_center, view.length() * (0.62 + _bass * 0.012) * ratio, Color(0.08, 0.14, 0.38, 0.010 + _bass * 0.003))
	var lower_center := Vector2(view.x * 0.46, view.y * 0.88)
	for ring in range(18, 0, -1):
		var ratio := float(ring) / 18.0
		draw_circle(lower_center, view.x * 0.28 * ratio, Color(0.15, 0.04, 0.28, 0.008))


func _draw_grid(view: Vector2) -> void:
	var spacing := maxf(80.0, view.x / 16.0)
	var color := Color(0.24, 0.38, 0.66, 0.045 + _mid * 0.035)
	var flow_boost := 1.0 + _mid * 0.8
	var x := fmod(_motion_time * 7.0 * flow_boost, spacing) - spacing
	while x <= view.x:
		draw_line(Vector2(x, 0.0), Vector2(x, view.y), color, 1.0)
		x += spacing
	var y := fmod(_motion_time * 4.0 * flow_boost, spacing) - spacing
	while y <= view.y:
		draw_line(Vector2(0.0, y), Vector2(view.x, y), color, 1.0)
		y += spacing


func _draw_orbits(view: Vector2) -> void:
	var drift_scale := 1.0 + _mid * 0.55
	var drift := Vector2(sin(_motion_time * 0.13) * view.x * 0.01, cos(_motion_time * 0.1) * view.y * 0.008) * drift_scale
	var center := Vector2(view.x * 0.42, view.y * 0.92) + drift
	var turn := _motion_time * 0.012
	var bass_scale := 1.0 + _bass * 0.025
	var mid_scale := 1.0 + _mid * 0.018
	draw_arc(center, view.x * 0.54 * bass_scale, turn, turn + TAU, 160, Color(0.38, 0.22, 0.92, 0.22 + _bass * 0.16), 2.2 + _bass * 1.4, true)
	draw_arc(center, view.x * 0.72 * mid_scale, -turn * 0.7, -turn * 0.7 + TAU, 192, Color(0.92, 0.20, 0.75, 0.18 + _mid * 0.12), 2.0 + _mid * 0.8, true)
	draw_arc(center, view.x * 0.34 * bass_scale, turn * 1.3, turn * 1.3 + TAU, 128, Color(0.18, 0.48, 0.85, 0.11 + _treble * 0.10), 1.5 + _treble * 0.7, true)


func _draw_particles(view: Vector2) -> void:
	var particles := [
		[Vector2(0.06, 0.25), Color("b56dff"), 2.2],
		[Vector2(0.12, 0.72), Color("e8ff74"), 2.0],
		[Vector2(0.23, 0.52), CYAN, 3.0],
		[Vector2(0.64, 0.08), Color("29aaff"), 2.4],
		[Vector2(0.77, 0.18), MAGENTA, 2.5],
		[Vector2(0.91, 0.34), CYAN, 3.0],
		[Vector2(0.86, 0.68), Color("8957ff"), 2.4],
		[Vector2(0.72, 0.88), MAGENTA, 2.3],
		[Vector2(0.10, 0.91), Color("fff36a"), 2.0],
	]
	for index in particles.size():
		var item: Array = particles[index]
		var phase := float(index) * 1.73
		var response_radius := 1.0 + _mid * 0.65
		var drift := Vector2(
			cos(_motion_time * (0.18 + _treble * 0.05) + phase) * (7.0 + index % 3 * 2.0),
			sin(_motion_time * (0.14 + _treble * 0.04) + phase) * (5.0 + index % 2 * 2.0),
		) * response_radius
		var point: Vector2 = item[0] * view + drift
		var color: Color = item[1]
		var radius: float = item[2] * (1.0 + sin(_motion_time + phase) * 0.08 + _treble * 0.38)
		var glow := color
		glow.a = 0.07 + _treble * 0.10
		draw_circle(point, radius * 3.8, glow)
		draw_circle(point, radius, color)
