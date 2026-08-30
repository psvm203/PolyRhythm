extends CanvasLayer

signal retry_requested
signal stage_select_requested

@onready var title_label: Label = %Title
@onready var rank_label: Label = %Rank
@onready var summary_label: Label = %Summary


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	%RetryButton.pressed.connect(retry_requested.emit)
	%StageSelectButton.pressed.connect(stage_select_requested.emit)


func show_result(stats: Dictionary, completed: bool, rank: String) -> void:
	title_label.text = "STAGE CLEAR" if completed else "RHYTHM LOST"
	rank_label.text = rank
	var counts: Dictionary = stats["judgments"]
	summary_label.text = (
		"SCORE  %07d\nACCURACY  %.1f%%\nMAX COMBO  %d\n\nPERFECT  %d    FAST  %d    SLOW  %d    MISS  %d"
		% [stats["score"], stats["accuracy"], stats["max_combo"], counts["Perfect"], counts["Fast"], counts["Slow"], counts["Too Slow"]]
	)
	show()
	%RetryButton.grab_focus()
