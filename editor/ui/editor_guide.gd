extends Control


func _ready() -> void:
	hide()
	%CloseButton.pressed.connect(close)


func open() -> void:
	show()
	%CloseButton.grab_focus()


func close() -> void:
	hide()
