extends CanvasLayer

const SettingsStoreScript = preload("res://main/settings_store.gd")

signal resume_requested
signal exit_requested

@onready var fullscreen_toggle: Button = %FullscreenToggle
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var master_enabled: CheckButton = %MasterEnabled
@onready var music_enabled: CheckButton = %MusicEnabled
@onready var sfx_enabled: CheckButton = %SfxEnabled
@onready var resolution_option: OptionButton = %ResolutionOption


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	%ResumeButton.pressed.connect(resume_requested.emit)
	%ExitButton.pressed.connect(exit_requested.emit)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	resolution_option.item_selected.connect(SettingsStoreScript.save_resolution)
	master_slider.value_changed.connect(_set_volume.bind("master_volume", master_value))
	music_slider.value_changed.connect(_set_volume.bind("music_volume", music_value))
	sfx_slider.value_changed.connect(_set_volume.bind("sfx_volume", sfx_value))
	master_enabled.toggled.connect(_set_enabled.bind("master_enabled", master_enabled))
	music_enabled.toggled.connect(_set_enabled.bind("music_enabled", music_enabled))
	sfx_enabled.toggled.connect(_set_enabled.bind("sfx_enabled", sfx_enabled))
	_sync_settings()


func open() -> void:
	_sync_settings()
	show()
	%ResumeButton.grab_focus()


func close() -> void:
	hide()


func set_exit_visible(value: bool) -> void:
	%ExitButton.visible = value


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _sync_settings() -> void:
	var settings := SettingsStoreScript.load_settings()
	SettingsStoreScript.apply(settings)
	_setup_resolution(settings)
	fullscreen_toggle.set_pressed_no_signal(settings["fullscreen"])
	_update_fullscreen_text(fullscreen_toggle.button_pressed)
	_sync_slider(master_slider, master_value, settings["master_volume"])
	_sync_slider(music_slider, music_value, settings["music_volume"])
	_sync_slider(sfx_slider, sfx_value, settings["sfx_volume"])
	_sync_toggle(master_enabled, settings["master_enabled"])
	_sync_toggle(music_enabled, settings["music_enabled"])
	_sync_toggle(sfx_enabled, settings["sfx_enabled"])


func _sync_slider(slider: HSlider, value_label: Label, percent: float) -> void:
	slider.set_value_no_signal(percent)
	value_label.text = "%d%%" % roundi(percent)


func _set_fullscreen(enabled: bool) -> void:
	_update_fullscreen_text(enabled)
	SettingsStoreScript.save_setting("fullscreen", enabled)


func _update_fullscreen_text(enabled: bool) -> void:
	fullscreen_toggle.text = "켬" if enabled else "끔"
	resolution_option.disabled = enabled


func _set_volume(value: float, setting_key: String, value_label: Label) -> void:
	value_label.text = "%d%%" % roundi(value)
	SettingsStoreScript.save_setting(setting_key, value)


func _set_enabled(enabled: bool, setting_key: String, toggle: CheckButton) -> void:
	_sync_toggle(toggle, enabled)
	SettingsStoreScript.save_setting(setting_key, enabled)


func _sync_toggle(toggle: CheckButton, enabled: bool) -> void:
	toggle.set_pressed_no_signal(enabled)
	toggle.text = "켬" if enabled else "끔"


func _setup_resolution(settings: Dictionary) -> void:
	resolution_option.clear()
	for size in SettingsStoreScript.RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [size.x, size.y])
	resolution_option.select(SettingsStoreScript.resolution_index(settings))
