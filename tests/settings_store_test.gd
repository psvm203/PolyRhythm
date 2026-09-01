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
		"controller_vibration_enabled": false,
		"controller_vibration_strength": 140.0,
	})
	_expect(values["fullscreen"] == true, "fullscreen is preserved")
	_expect(values["master_volume"] == 0.0, "low volume is clamped")
	_expect(values["music_volume"] == 42.5, "valid volume is preserved")
	_expect(values["sfx_volume"] == 100.0, "high volume is clamped")
	_expect(values["music_enabled"] == false, "mute toggle is preserved")
	_expect(Vector2i(values["resolution_width"], values["resolution_height"]) == Vector2i(1280, 720), "unknown resolution falls back to a preset")
	_expect(values["timing_offset_ms"] == SettingsStoreScript.MAX_TIMING_OFFSET_MS, "timing offset is clamped")
	_expect(values["controller_vibration_enabled"] == false, "vibration toggle is preserved")
	_expect(values["controller_vibration_strength"] == 100.0, "vibration strength is clamped")
	_expect(SettingsStoreScript.resolution_index(SettingsStoreScript.DEFAULTS) == 0, "default resolution selects first preset")
	var defaults := SettingsStoreScript.normalized({})
	_expect(defaults == SettingsStoreScript.DEFAULTS, "missing values use defaults")
	if _failures == 0:
		print("Settings store tests passed: 11 assertions")
		quit(0)
	else:
		push_error("Settings store tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(label)
