extends SceneTree

const SettingsStoreScript = preload("res://main/settings_store.gd")

var _failures := 0


func _init() -> void:
	var values := SettingsStoreScript.normalized({
		"fullscreen": true,
		"master_volume": -20.0,
		"music_volume": 42.5,
		"sfx_volume": 140.0,
		"music_enabled": false,
		"resolution_width": 320,
		"resolution_height": 200,
		"timing_offset_ms": 240.0,
		"tap_keycode": KEY_ESCAPE,
		"reduced_motion": true,
	})
	_expect(values["fullscreen"] == true, "fullscreen is preserved")
	_expect(values["master_volume"] == 0.0, "low volume is clamped")
	_expect(values["music_volume"] == 42.5, "valid volume is preserved")
	_expect(values["sfx_volume"] == 100.0, "high volume is clamped")
	_expect(values["music_enabled"] == false, "mute toggle is preserved")
	_expect(Vector2i(values["resolution_width"], values["resolution_height"]) == Vector2i(1280, 720), "unknown resolution falls back to a preset")
	_expect(values["timing_offset_ms"] == SettingsStoreScript.MAX_TIMING_OFFSET_MS, "timing offset is clamped")
	_expect(values["tap_keycode"] == KEY_SPACE, "unsupported play key falls back to Space")
	_expect(values["reduced_motion"] == true, "reduced motion setting is preserved")
	_expect(SettingsStoreScript.resolution_index(SettingsStoreScript.DEFAULTS) == 0, "default resolution selects first preset")
	var defaults := SettingsStoreScript.normalized({})
	_expect(defaults == SettingsStoreScript.DEFAULTS, "missing values use defaults")
	var remapped := defaults.duplicate()
	remapped["tap_keycode"] = KEY_J
	SettingsStoreScript.apply(remapped)
	var has_j_key := false
	var keeps_mouse_input := false
	for event in InputMap.action_get_events("tap"):
		if event is InputEventKey and event.physical_keycode == KEY_J:
			has_j_key = true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			keeps_mouse_input = true
	_expect(has_j_key, "selected play key is applied to InputMap")
	_expect(keeps_mouse_input, "remapping keeps mouse input")
	if _failures == 0:
		print("Settings store tests passed: 13 assertions")
		quit(0)
	else:
		push_error("Settings store tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(label)
