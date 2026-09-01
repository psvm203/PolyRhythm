extends CanvasLayer

const ProgressStoreScript = preload("res://level/progress_store.gd")

signal retry_requested
signal stage_select_requested

@onready var title_label: Label = %Title
@onready var rank_label: Label = %Rank
@onready var summary_label: Label = %Summary
@onready var rating_label: Label = %Rating


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	%RetryButton.pressed.connect(retry_requested.emit)
	%StageSelectButton.pressed.connect(stage_select_requested.emit)


func show_result(stats: Dictionary, completed: bool, rank: String) -> void:
	title_label.text = "스테이지 클리어" if completed else "도전 종료"
	rank_label.text = rank
	var rating := ProgressStoreScript.star_rating(stats["accuracy"], completed)
	rating_label.text = "★".repeat(rating["stars"]) if completed else ""
	rating_label.add_theme_color_override("font_color", _rating_color(rating["tier"]))
	var counts: Dictionary = stats["judgments"]
	summary_label.text = (
		"점수  %07d\n정확도  %.1f%%\n최대 콤보  %d\n\nPERFECT  %d    FAST  %d    SLOW  %d    MISS  %d"
		% [stats["score"], stats["accuracy"], stats["max_combo"], counts["Perfect"], counts["Fast"], counts["Slow"], counts["Too Slow"]]
	)
	show()
	%RetryButton.grab_focus()


func _rating_color(tier: String) -> Color:
	match tier:
		"diamond": return Color("76f7ff")
		"gold": return Color("ffd84d")
		"silver": return Color("c7d1dc")
		"bronze": return Color("c98252")
	return Color.TRANSPARENT
