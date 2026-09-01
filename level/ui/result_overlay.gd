extends CanvasLayer

const ProgressStoreScript = preload("res://level/progress_store.gd")

signal retry_requested
signal stage_select_requested

@onready var rank_label: Label = %Rank
@onready var summary_label: Label = %Summary
@onready var rating_label: Label = %Rating
@onready var timing_report: Label = %TimingReport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	%RetryButton.pressed.connect(retry_requested.emit)
	%StageSelectButton.pressed.connect(stage_select_requested.emit)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	stage_select_requested.emit()
	get_viewport().set_input_as_handled()


func show_result(stats: Dictionary, completed: bool, rank: String) -> void:
	rank_label.text = rank
	var rating := ProgressStoreScript.star_rating(stats["accuracy"], completed)
	rating_label.text = "★".repeat(rating["stars"]) if completed else ""
	rating_label.add_theme_color_override("font_color", _rating_color(rating["tier"]))
	var counts: Dictionary = stats["judgments"]
	summary_label.text = (
		"점수  %07d        정확도  %.1f%%\n\nPERFECT  %d    FAST  %d    SLOW  %d    MISS  %d"
		% [stats["score"], stats["accuracy"], counts["Perfect"], counts["Fast"], counts["Slow"], counts["Too Slow"]]
	)
	var average_offset := float(stats.get("average_offset_ms", 0.0))
	var mean_error := float(stats.get("mean_absolute_error_ms", 0.0))
	var tendency := _timing_tendency(average_offset)
	timing_report.text = (
		"평균 편차  %+.1f ms        평균 오차  %.1f ms\n입력 경향  %s        이른 추가 입력  %d"
		% [average_offset, mean_error, tendency, int(stats.get("early_inputs", 0))]
	)
	show()
	%RetryButton.grab_focus()


func _timing_tendency(average_offset_ms: float) -> String:
	if average_offset_ms < -3.0:
		return "빠른 편"
	if average_offset_ms > 3.0:
		return "느린 편"
	return "안정적"


func _rating_color(tier: String) -> Color:
	match tier:
		"diamond": return Color("76f7ff")
		"gold": return Color("ffd84d")
		"silver": return Color("c7d1dc")
		"bronze": return Color("c98252")
	return Color.TRANSPARENT
