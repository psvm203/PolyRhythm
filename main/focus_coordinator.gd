extends Node

var _mouse_focus_enabled := true
var _controls: Array[Control] = []
var _mouse_filters: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh.call_deferred()


func refresh() -> void:
	_controls.clear()
	_mouse_filters.clear()
	_collect_focusable_controls(get_parent())
	for control in _controls:
		_mouse_filters[control] = control.mouse_filter
		if not control.mouse_entered.is_connected(_focus_from_mouse.bind(control)):
			control.mouse_entered.connect(_focus_from_mouse.bind(control))
	_wire_focus_cycle()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_set_mouse_focus_enabled(true)
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_set_mouse_focus_enabled(false)


func _collect_focusable_controls(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			_controls.append(child)
		_collect_focusable_controls(child)


func _wire_focus_cycle() -> void:
	if _controls.size() < 2:
		return
	for index in _controls.size():
		var control := _controls[index]
		var previous := _controls[(index - 1 + _controls.size()) % _controls.size()]
		var next := _controls[(index + 1) % _controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)


func _focus_from_mouse(control: Control) -> void:
	if not _mouse_focus_enabled or not control.is_visible_in_tree():
		return
	if control is BaseButton and control.disabled:
		return
	control.grab_focus()


func _set_mouse_focus_enabled(enabled: bool) -> void:
	if _mouse_focus_enabled == enabled:
		return
	_mouse_focus_enabled = enabled
	for control in _controls:
		if not is_instance_valid(control):
			continue
		control.mouse_filter = int(_mouse_filters.get(control, Control.MOUSE_FILTER_STOP)) if enabled else Control.MOUSE_FILTER_IGNORE
