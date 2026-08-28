extends Control

const LEVEL_SCENE := "res://level/level.tscn"
const CYAN := Color("19e0db")
const MAGENTA := Color("ed1671")

@onready var menu: VBoxContainer = %Menu
@onready var main_content: Control = %Content
@onready var stage_screen: Control = %StageScreen
@onready var settings_screen: Control = %SettingsScreen
@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_body: Label = %OverlayBody
@onready var exit_buttons: HBoxContainer = %ExitButtons
@onready var close_button: Button = %CloseButton
@onready var warning_badge: Control = %WarningBadge
@onready var background_music: AudioStreamPlayer = %BackgroundMusic

var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _motion_time := 0.0
var _bass := 0.0
var _mid := 0.0
var _treble := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	%StartButton.pressed.connect(_show_stage_select)
	%BackButton.pressed.connect(_hide_stage_select)
	%StageOneButton.pressed.connect(_start_game)
	%SettingsButton.pressed.connect(_show_settings)
	%SettingsBackButton.pressed.connect(_hide_settings)
	%FullscreenToggle.toggled.connect(_set_fullscreen)
	%MasterSlider.value_changed.connect(_set_master_volume)
	%MusicSlider.value_changed.connect(_set_music_volume)
	%SfxSlider.value_changed.connect(_set_sfx_volume)
	%CreditsButton.pressed.connect(_show_credits)
	%ExitButton.pressed.connect(_show_exit)
	close_button.pressed.connect(_hide_overlay)
	%CancelExitButton.pressed.connect(_hide_overlay)
	%ConfirmExitButton.pressed.connect(get_tree().quit)
	background_music.finished.connect(background_music.play)
	_initialize_settings()
	queue_redraw()


func _process(delta: float) -> void:
	_motion_time += delta
	if background_music.playing:
		_motion_time = background_music.get_playback_position()
	_update_audio_response(delta)
	queue_redraw()


func _update_audio_response(delta: float) -> void:
	if _analyzer == null:
		var bus_index := AudioServer.get_bus_index(&"MenuMusic")
		if bus_index < 0:
			return
		_analyzer = AudioServer.get_bus_effect_instance(
			bus_index, 0
		) as AudioEffectSpectrumAnalyzerInstance
	if _analyzer == null:
		return
	var raw_bass := _frequency_energy(35.0, 180.0)
	var raw_mid := _frequency_energy(180.0, 2200.0)
	var raw_treble := _frequency_energy(2200.0, 9000.0)
	_bass = _smoothed_energy(_bass, raw_bass, delta, 9.0)
	_mid = _smoothed_energy(_mid, raw_mid, delta, 7.0)
	_treble = _smoothed_energy(_treble, raw_treble, delta, 11.0)


func _frequency_energy(from_hz: float, to_hz: float) -> float:
	var magnitude := _analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	var amplitude := maxf(magnitude.x, magnitude.y)
	if amplitude <= 0.000001:
		return 0.0
	var decibels := linear_to_db(amplitude)
	return clampf((decibels + 55.0) / 45.0, 0.0, 1.0)


func _smoothed_energy(current: float, target: float, delta: float, speed: float) -> float:
	return lerpf(current, target, 1.0 - exp(-speed * delta))


func _draw() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Color("071126"))
	_draw_background_gradient(view)
	_draw_grid(view)
	_draw_orbits(view)
	_draw_particles(view)
	_draw_music_notes(view)


func _draw_background_gradient(view: Vector2) -> void:
	var center := Vector2(view.x * 0.46, view.y * 0.36)
	var max_radius := view.length() * 0.68
	for ring in range(48, 0, -1):
		var ratio := float(ring) / 48.0
		var color := Color(0.08, 0.14, 0.38, 0.012)
		draw_circle(center, max_radius * ratio, color)
	# A restrained lower glow anchors the menu without competing with it.
	for ring in range(20, 0, -1):
		var ratio := float(ring) / 20.0
		draw_circle(Vector2(view.x * 0.5, view.y * 0.78), view.x * 0.24 * ratio, Color(0.15, 0.04, 0.28, 0.008))


func _draw_grid(view: Vector2) -> void:
	var spacing := maxf(80.0, view.x / 16.0)
	var grid_color := Color(0.24, 0.38, 0.66, 0.055)
	var x_offset := fmod(_motion_time * 12.0, spacing)
	var y_offset := fmod(_motion_time * 7.0, spacing)
	var x := x_offset - spacing
	while x <= view.x:
		draw_line(Vector2(x, 0), Vector2(x, view.y), grid_color, 1.0)
		x += spacing
	var y := y_offset - spacing
	while y <= view.y:
		draw_line(Vector2(0, y), Vector2(view.x, y), grid_color, 1.0)
		y += spacing


func _draw_orbits(view: Vector2) -> void:
	var drift := Vector2(sin(_motion_time * 0.16) * view.x * 0.009, cos(_motion_time * 0.12) * view.y * 0.006)
	var center := Vector2(view.x * 0.39, view.y * 0.92) + drift
	var bass_pulse := 1.0 + _bass * 0.018
	var mid_pulse := 1.0 + _mid * 0.012
	var orbit_turn := _motion_time * 0.018
	_draw_arc_segments(center, view.x * 0.53 * bass_pulse, orbit_turn, orbit_turn + TAU, 160, Color(0.38, 0.22, 0.92, 0.32 + _bass * 0.16), 2.5 + _bass * 1.2)
	_draw_arc_segments(center, view.x * 0.71 * mid_pulse, -orbit_turn * 0.65, -orbit_turn * 0.65 + TAU, 192, Color(0.92, 0.20, 0.75, 0.27 + _mid * 0.12), 2.2)
	_draw_arc_segments(center, view.x * 0.33 * mid_pulse, orbit_turn * 1.2, orbit_turn * 1.2 + TAU, 128, Color(0.18, 0.38, 0.85, 0.10 + _bass * 0.08), 1.5 + _mid * 0.6)


func _draw_arc_segments(
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	segments: int,
	color: Color,
	width: float,
) -> void:
	var previous := center + Vector2.from_angle(start_angle) * radius
	for index in range(1, segments + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / segments)
		var point := center + Vector2.from_angle(angle) * radius
		draw_line(previous, point, color, width, true)
		previous = point


func _draw_particles(view: Vector2) -> void:
	var particles := [
		[Vector2(0.055, 0.36), Color("b56dff"), 2.3],
		[Vector2(0.105, 0.55), Color("e8ff74"), 2.8],
		[Vector2(0.225, 0.58), CYAN, 4.5],
		[Vector2(0.61, 0.045), Color("29aaff"), 2.8],
		[Vector2(0.67, 0.105), Color("15efff"), 2.1],
		[Vector2(0.75, 0.085), MAGENTA, 2.8],
		[Vector2(0.80, 0.24), CYAN, 4.0],
		[Vector2(0.86, 0.34), Color("8957ff"), 2.8],
		[Vector2(0.94, 0.21), MAGENTA, 2.2],
		[Vector2(0.84, 0.58), MAGENTA, 4.5],
		[Vector2(0.74, 0.82), Color("ff38c7"), 2.2],
		[Vector2(0.85, 0.87), Color("397dff"), 4.0],
		[Vector2(0.10, 0.89), Color("fff36a"), 2.2],
	]
	for index in particles.size():
		var item: Array = particles[index]
		var phase := float(index) * 1.73
		var orbit_speed := 0.20 + float(index % 4) * 0.035
		var orbit_radius := 6.0 + float(index % 3) * 3.0 + _mid * 10.0
		var drift := Vector2(
			cos(_motion_time * orbit_speed + phase) * orbit_radius,
			sin(_motion_time * orbit_speed * 0.78 + phase) * orbit_radius * 0.72,
		)
		drift += Vector2(sin(_motion_time * 0.09 + phase), cos(_motion_time * 0.07 + phase)) * 4.0
		var point: Vector2 = item[0] * view + drift
		var color: Color = item[1]
		var idle_pulse := (sin(_motion_time * 1.15 + phase) + 1.0) * 0.06
		var radius: float = item[2] * (1.0 + idle_pulse + _treble * 0.32)
		var glow := color
		glow.a = 0.08 + _treble * 0.08
		draw_circle(point, radius * 3.6, glow)
		draw_circle(point, radius, color)
		if index % 4 == 0:
			var ring_color := color
			ring_color.a = 0.12 + _treble * 0.12
			draw_arc(point, radius * (2.2 + _bass * 0.8), 0.0, TAU, 24, ring_color, 1.0, true)
	var turn := _motion_time * 0.035
	_draw_polygon_outline(Vector2(0.18, 0.35) * view + Vector2(sin(_motion_time * 0.25), cos(_motion_time * 0.21)) * 5.0, 25.0 + _treble * 2.0, 4, 0.18 + turn, Color(0.05, 0.65, 0.95, 0.45 + _treble * 0.2))
	_draw_polygon_outline(Vector2(0.88, 0.08) * view + Vector2(cos(_motion_time * 0.19), sin(_motion_time * 0.23)) * 6.0, 29.0 + _mid * 2.0, 4, 0.62 - turn * 0.7, Color(0.55, 0.17, 0.95, 0.44 + _treble * 0.18))
	_draw_polygon_outline(Vector2(0.95, 0.89) * view + Vector2(sin(_motion_time * 0.17), cos(_motion_time * 0.20)) * 5.0, 24.0, 5, 0.20 + turn * 0.6, Color(0.55, 0.17, 0.95, 0.38 + _treble * 0.16))


func _draw_polygon_outline(center: Vector2, radius: float, sides: int, rotation_angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(sides + 1):
		var angle := rotation_angle + TAU * float(index) / sides
		points.append(center + Vector2.from_angle(angle) * radius)
	draw_polyline(points, color, 2.0, true)


func _draw_music_notes(view: Vector2) -> void:
	var notes := [
		[Vector2(0.105, 0.22), MAGENTA, 1.0],
		[Vector2(0.10, 0.71), Color("16d7f0"), 1.25],
		[Vector2(0.91, 0.32), CYAN, 1.3],
		[Vector2(0.92, 0.68), Color("b568ff"), 1.0],
	]
	for index in notes.size():
		var item: Array = notes[index]
		var phase := float(index) * 1.9
		var float_offset := Vector2(
			sin(_motion_time * (0.24 + index * 0.025) + phase) * (9.0 + _mid * 5.0),
			cos(_motion_time * (0.30 + index * 0.02) + phase) * (8.0 + _mid * 7.0),
		)
		var origin: Vector2 = item[0] * view + float_offset
		var color: Color = item[1]
		var scale_value: float = item[2] * (1.0 + _treble * 0.10)
		var sway := sin(_motion_time * 0.65 + phase) * 0.10
		var glow := color
		glow.a = 0.10
		draw_circle(origin, 15.0 * scale_value, glow)
		draw_circle(origin, 7.5 * scale_value, color)
		var stem_bottom := origin + (Vector2(6.5, 0) * scale_value).rotated(sway)
		var stem_top := origin + (Vector2(6.5, -31) * scale_value).rotated(sway)
		draw_line(stem_bottom, stem_top, color, 4.0 * scale_value, true)
		var flag := PackedVector2Array([
			origin + (Vector2(6.5, -31) * scale_value).rotated(sway),
			origin + (Vector2(22, -25) * scale_value).rotated(sway),
			origin + (Vector2(7, -19) * scale_value).rotated(sway),
		])
		draw_colored_polygon(flag, color)


func _start_game() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _show_settings() -> void:
	_clear_focus()
	main_content.hide()
	settings_screen.show()


func _hide_settings() -> void:
	_clear_focus()
	settings_screen.hide()
	main_content.show()


func _initialize_settings() -> void:
	%FullscreenToggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_update_fullscreen_toggle(%FullscreenToggle.button_pressed)
	_update_volume_label(%MasterValue, %MasterSlider.value)
	_update_volume_label(%MusicValue, %MusicSlider.value)
	_update_volume_label(%SfxValue, %SfxSlider.value)
	_set_master_volume(%MasterSlider.value)
	_set_music_volume(%MusicSlider.value)
	_set_sfx_volume(%SfxSlider.value)


func _set_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	_update_fullscreen_toggle(enabled)


func _update_fullscreen_toggle(enabled: bool) -> void:
	%FullscreenToggle.text = "ON" if enabled else "OFF"
	var color := Color(0.08, 1.0, 0.92, 1.0) if enabled else Color(0.58, 0.63, 0.74, 1.0)
	%FullscreenToggle.add_theme_color_override("font_color", color)
	%FullscreenToggle.add_theme_color_override("font_pressed_color", color)


func _set_master_volume(value: float) -> void:
	_set_bus_volume(&"Master", value)
	_update_volume_label(%MasterValue, value)


func _set_music_volume(value: float) -> void:
	_set_bus_volume(&"MenuMusic", value)
	_update_volume_label(%MusicValue, value)


func _set_sfx_volume(value: float) -> void:
	_set_bus_volume(&"SFX", value)
	_update_volume_label(%SfxValue, value)


func _set_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(percent / 100.0, 0.0001)))
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)


func _update_volume_label(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value)


func _show_credits() -> void:
	_show_overlay("CREDITS", "POLYRHYTHM\nCreated with Godot Engine")


func _show_exit() -> void:
	_show_overlay("", "게임을 나가시겠습니까?")
	warning_badge.show()
	overlay_title.hide()
	exit_buttons.show()
	close_button.hide()
	_clear_focus()


func _show_overlay(title: String, body: String) -> void:
	warning_badge.hide()
	overlay_title.show()
	overlay_title.text = title
	overlay_body.text = body
	exit_buttons.hide()
	close_button.show()
	overlay.show()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_focus()


func _hide_overlay() -> void:
	_clear_focus()
	overlay.hide()
	menu.mouse_filter = Control.MOUSE_FILTER_PASS


func _show_stage_select() -> void:
	_clear_focus()
	main_content.hide()
	stage_screen.show()


func _hide_stage_select() -> void:
	_clear_focus()
	stage_screen.hide()
	main_content.show()


func _clear_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and overlay.visible:
		_hide_overlay()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and stage_screen.visible:
		_hide_stage_select()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and settings_screen.visible:
		_hide_settings()
		get_viewport().set_input_as_handled()
