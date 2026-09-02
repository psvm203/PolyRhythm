class_name ScreenTransitionController
extends Node

var _main_content: Control
var _main_logo: Control
var _transition_logo: Control
var _default_focus: Control
var _transitioning := false


func setup(main_content: Control, main_logo: Control, transition_logo: Control, default_focus: Control) -> void:
	_main_content = main_content
	_main_logo = main_logo
	_transition_logo = transition_logo
	_default_focus = default_focus


func is_transitioning() -> bool:
	return _transitioning


func transition_to(
		target_screen: Control,
		target_logo: Control,
		target_title: Control,
		target_body: Control,
		back_button: Control,
		focus_target: Control = null,
		animate_logo: bool = true,
) -> void:
	if _transitioning:
		return
	_transitioning = true
	_clear_focus()
	target_screen.modulate.a = 0.0
	_transition_logo.modulate.a = 0.0
	_transition_logo.visible = animate_logo
	target_screen.show()
	await _wait_for_layout()

	var content_home := _main_content.position
	var title_home := target_title.position
	var body_home := target_body.position
	_transition_logo.position = _main_logo.global_position
	_transition_logo.scale = _logo_scale_for(_main_logo)
	_transition_logo.modulate = Color.WHITE
	_main_logo.modulate.a = 0.0 if animate_logo else 1.0
	target_logo.modulate.a = 0.0
	target_title.modulate.a = 0.0
	target_title.position = title_home + Vector2(0, 42)
	target_body.modulate.a = 0.0
	target_body.position = body_home + Vector2(0, 110)
	back_button.modulate.a = 0.0
	target_screen.modulate.a = 1.0

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_transition_logo, "position", target_logo.global_position, 0.52)
	tween.tween_property(_transition_logo, "scale", _logo_scale_for(target_logo), 0.52)
	tween.tween_property(_main_content, "position", content_home + Vector2(0, 74), 0.32)
	tween.tween_property(_main_content, "modulate:a", 0.0, 0.25)
	tween.tween_property(target_title, "position", title_home, 0.42).set_delay(0.18)
	tween.tween_property(target_title, "modulate:a", 1.0, 0.32).set_delay(0.18)
	tween.tween_property(target_body, "position", body_home, 0.48).set_delay(0.22)
	tween.tween_property(target_body, "modulate:a", 1.0, 0.36).set_delay(0.22)
	tween.tween_property(back_button, "modulate:a", 1.0, 0.28).set_delay(0.25)
	await tween.finished

	_main_content.hide()
	_main_content.position = content_home
	_main_content.modulate.a = 1.0
	_main_logo.modulate.a = 1.0
	target_logo.modulate.a = 1.0
	_transition_logo.hide()
	_transitioning = false
	(focus_target if focus_target != null else back_button).grab_focus()


func transition_to_main(
		current_screen: Control,
		current_logo: Control,
		current_title: Control,
		current_body: Control,
		back_button: Control,
		animate_logo: bool = true,
) -> void:
	if _transitioning:
		return
	_transitioning = true
	_clear_focus()
	_main_content.modulate.a = 0.0
	_transition_logo.modulate.a = 0.0
	_transition_logo.visible = animate_logo
	_main_content.show()
	await _wait_for_layout()

	var content_home := _main_content.position
	var title_home := current_title.position
	var body_home := current_body.position
	var main_logo_home_global := _main_logo.global_position
	_main_logo.modulate.a = 0.0 if animate_logo else 1.0
	_main_content.position = content_home + Vector2(0, 74)
	_transition_logo.position = current_logo.global_position
	_transition_logo.scale = _logo_scale_for(current_logo)
	_transition_logo.modulate = Color.WHITE
	current_logo.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(current_title, "position", title_home + Vector2(0, 42), 0.32)
	tween.tween_property(current_title, "modulate:a", 0.0, 0.24)
	tween.tween_property(current_body, "position", body_home + Vector2(0, 110), 0.38)
	tween.tween_property(current_body, "modulate:a", 0.0, 0.28)
	tween.tween_property(back_button, "modulate:a", 0.0, 0.2)
	tween.tween_property(_transition_logo, "position", main_logo_home_global, 0.52)
	tween.tween_property(_transition_logo, "scale", _logo_scale_for(_main_logo), 0.52)
	var content_duration := 0.42 if animate_logo else 0.28
	var content_delay := 0.18 if animate_logo else 0.04
	var fade_duration := 0.3 if animate_logo else 0.22
	tween.tween_property(_main_content, "position", content_home, content_duration).set_delay(content_delay)
	tween.tween_property(_main_content, "modulate:a", 1.0, fade_duration).set_delay(content_delay)
	await tween.finished

	current_screen.hide()
	current_logo.modulate.a = 1.0
	current_title.position = title_home
	current_title.modulate.a = 1.0
	current_body.position = body_home
	current_body.modulate.a = 1.0
	back_button.modulate.a = 1.0
	_main_logo.modulate.a = 1.0
	_transition_logo.hide()
	_transitioning = false
	_default_focus.grab_focus()


func _wait_for_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_transition_logo.reset_size()
	await get_tree().process_frame


func _logo_scale_for(logo: Control) -> Vector2:
	return Vector2(
		logo.size.x / maxf(_transition_logo.size.x, 1.0),
		logo.size.y / maxf(_transition_logo.size.y, 1.0),
	)


func _clear_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
