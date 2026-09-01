extends CanvasLayer

const PlayInputScript = preload("res://main/play_input.gd")
const CalibrationStatisticsScript = preload("res://level/timing/calibration_statistics.gd")

signal offset_selected(offset_ms: float)
signal closed

const BEAT_COUNT := 8
const BEAT_INTERVAL_USEC := 1_200_000
const START_DELAY_USEC := 1_500_000
const ACCEPT_WINDOW_USEC := 250_000

@onready var status_label: Label = %Status
@onready var visual: Control = %CalibrationVisual
@onready var start_button: Button = %StartButton
@onready var apply_button: Button = %ApplyButton
@onready var click_player: AudioStreamPlayer = %ClickPlayer

var _running := false
var _started_at_usec := 0
var _next_beat_index := 0
var _scheduled_beats: Array[int] = []
var _used_beats: Dictionary = {}
var _samples_ms: Array[float] = []
var _sample_devices: Array[String] = []
var _suggested_offset_ms := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	start_button.pressed.connect(_start_calibration)
	apply_button.pressed.connect(_apply_result)
	%CancelButton.pressed.connect(close)


func open() -> void:
	_reset()
	show()
	start_button.grab_focus()


func close() -> void:
	_running = false
	hide()
	closed.emit()


func _reset() -> void:
	_running = false
	_scheduled_beats.clear()
	_next_beat_index = 0
	_used_beats.clear()
	_samples_ms.clear()
	_sample_devices.clear()
	_suggested_offset_ms = 0.0
	status_label.text = "Start를 누른 뒤 삼각형의 변이 도형에 닿는 순간 입력하세요"
	%Progress.text = "0 / %d" % BEAT_COUNT
	apply_button.disabled = true
	start_button.disabled = false
	visual.call("reset")


func _start_calibration() -> void:
	_reset()
	_running = true
	start_button.disabled = true
	_started_at_usec = Time.get_ticks_usec() + START_DELAY_USEC
	for index in BEAT_COUNT:
		_scheduled_beats.append(_started_at_usec + index * BEAT_INTERVAL_USEC)
	visual.call("set_timeline", _scheduled_beats, BEAT_INTERVAL_USEC)
	status_label.text = "삼각형의 변이 도형에 닿는 순간 입력하세요"


func _process(_delta: float) -> void:
	if not _running:
		return
	var now := Time.get_ticks_usec()
	visual.call("update_clock", now)
	while _next_beat_index < BEAT_COUNT and now >= _scheduled_beats[_next_beat_index]:
		_play_beat()
		_next_beat_index += 1
	if _next_beat_index >= BEAT_COUNT and now > _scheduled_beats[-1] + ACCEPT_WINDOW_USEC:
		_finish_calibration()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var input_manager := get_node_or_null("/root/InputDeviceManager")
	var gamepad_input := bool(input_manager.call("is_play_input", event)) if input_manager != null else false
	if not _running or not (PlayInputScript.is_pressed(event) or gamepad_input):
		return
	_record_tap(Time.get_ticks_usec(), _input_device_name(event))
	get_viewport().set_input_as_handled()


func _record_tap(tap_usec: int, device: String = "unknown") -> void:
	var closest_index := -1
	var closest_distance := ACCEPT_WINDOW_USEC + 1
	for index in _scheduled_beats.size():
		if _used_beats.has(index):
			continue
		var distance: int = absi(tap_usec - _scheduled_beats[index])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	if closest_index < 0 or closest_distance > ACCEPT_WINDOW_USEC:
		return
	_used_beats[closest_index] = true
	_samples_ms.append(float(tap_usec - _scheduled_beats[closest_index]) / 1000.0)
	_sample_devices.append(device)
	%Progress.text = "%d / %d" % [_samples_ms.size(), BEAT_COUNT]


func _play_beat() -> void:
	click_player.play()


func _finish_calibration() -> void:
	_running = false
	visual.call("finish")
	start_button.disabled = false
	if _samples_ms.size() < 4:
		status_label.text = "입력이 부족합니다. 다시 측정해 주세요"
		return
	var report: Dictionary = CalibrationStatisticsScript.report(_samples_ms, _sample_devices)
	_suggested_offset_ms = clampf(float(report["center_ms"]), -150.0, 150.0)
	status_label.text = "권장 보정  %+.0f ms    입력 편차  %.1f ms    제외 %d" % [_suggested_offset_ms, report["spread_ms"], report["rejected_count"]]
	apply_button.disabled = false
	apply_button.grab_focus()


func _apply_result() -> void:
	offset_selected.emit(_suggested_offset_ms)
	close()


static func calculate_median(samples: Array[float]) -> float:
	return CalibrationStatisticsScript.median(samples)


static func calculate_mean_deviation(samples: Array[float], center: float) -> float:
	return CalibrationStatisticsScript.mean_deviation(samples, center)


func _input_device_name(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "gamepad"
	if event is InputEventMouseButton:
		return "mouse"
	if event is InputEventKey:
		return "keyboard"
	return "unknown"
