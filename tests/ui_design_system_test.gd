extends SceneTree

const MAIN_SCENE := preload("res://main/main_screen.tscn")
const PAUSE_SCENE := preload("res://level/ui/pause_overlay.tscn")
const RESULT_SCENE := preload("res://level/ui/result_overlay.tscn")
const CALIBRATION_SCENE := preload("res://main/timing_calibration_overlay.tscn")
const THEME := preload("res://main/poly_theme.tres")

var _assertions := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_theme_tokens()
	_test_main_settings_layout()
	_test_pause_layout()
	_test_overlay_theme_inheritance()
	if _failures > 0:
		push_error("UI design system tests failed: %d of %d assertions" % [_failures, _assertions])
		quit(1)
		return
	print("UI design system tests passed: %d assertions" % _assertions)
	quit()


func _test_theme_tokens() -> void:
	for state in [&"normal", &"hover", &"focus", &"pressed", &"disabled"]:
		_expect(THEME.has_stylebox(state, &"Button"), "button %s style exists" % state)
	_expect(THEME.get_font_size(&"font_size", &"Button") >= 20, "button text remains readable")
	var normal := THEME.get_stylebox(&"normal", &"Button")
	_expect(normal.content_margin_left >= 18.0, "button has horizontal breathing room")
	_expect(normal.content_margin_top >= 10.0, "button has vertical breathing room")


func _test_main_settings_layout() -> void:
	var scene := MAIN_SCENE.instantiate()
	var settings_layout: Control = scene.get_node("SettingsScreen/SettingsLayout")
	var logo: Control = settings_layout.get_node("SmallLogo")
	var panel: Control = settings_layout.get_node("SettingsPanelSlot/SettingsPanel")
	var rows: VBoxContainer = panel.get_node("Margin/Rows")
	_expect(not logo.visible, "settings title logo is hidden to reserve vertical space")
	_expect(settings_layout.offset_bottom - settings_layout.offset_top >= 860.0, "settings layout uses available vertical space")
	_expect(panel.custom_minimum_size.y >= 840.0, "settings panel shows all options")
	_expect(rows.get_theme_constant("separation") >= 8, "settings rows have clear separation")
	for row_name in ["Master", "Music", "Sfx", "Vibration", "Timing"]:
		var row: HBoxContainer = rows.get_node(row_name)
		_expect(row.get_theme_constant("separation") >= 14, "%s controls are separated" % row_name)
		var slider: HSlider = row.get_node(row_name + "Slider")
		_expect(slider.custom_minimum_size.x >= 340.0, "%s slider remains easy to target" % row_name)
	var cards: HBoxContainer = scene.get_node("StageScreen/StageLayout/CardsSlot/Cards")
	var stage_names := ["One", "Two", "Three", "Four"]
	for index in stage_names.size():
		var stage: PanelContainer = cards.get_child(index)
		var button: Button = stage.get_node("Stage%sButton" % stage_names[index])
		_expect(button.get_theme_stylebox("focus") is StyleBoxEmpty, "stage %d focus keeps card content visible" % (index + 1))
	scene.free()


func _test_pause_layout() -> void:
	var scene := PAUSE_SCENE.instantiate()
	var panel: Control = scene.get_node("Dimmer/Center/Panel")
	var rows: VBoxContainer = panel.get_node("Margin/Rows")
	_expect(panel.custom_minimum_size.y >= 700.0, "pause settings panel fits every row")
	_expect(rows.get_theme_constant("separation") >= 8, "pause rows have clear separation")
	for row_name in ["Master", "Music", "Sfx", "Vibration", "Timing"]:
		var row: HBoxContainer = rows.get_node(row_name)
		_expect(row.get_theme_constant("separation") >= 12, "pause %s controls are separated" % row_name)
	scene.free()


func _test_overlay_theme_inheritance() -> void:
	var result := RESULT_SCENE.instantiate()
	var calibration := CALIBRATION_SCENE.instantiate()
	_expect(result.get_node("Dim").theme == THEME, "result screen uses shared theme")
	_expect(calibration.get_node("Dim").theme == THEME, "calibration screen uses shared theme")
	_expect(result.has_node("FocusCoordinator"), "result screen coordinates input focus")
	_expect(calibration.has_node("FocusCoordinator"), "calibration screen coordinates input focus")
	result.free()
	calibration.free()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		return
	push_error("Assertion failed: %s" % message)
	_failures += 1
