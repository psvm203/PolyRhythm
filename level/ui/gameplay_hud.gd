extends CanvasLayer

@onready var score_label: Label = %Score
@onready var combo_label: Label = %Combo
@onready var accuracy_label: Label = %Accuracy
@onready var progress_label: Label = %Progress
@onready var gauge_bar: ProgressBar = %Gauge


func update_stats(stats: Dictionary) -> void:
	score_label.text = "%07d" % stats["score"]
	combo_label.text = "%d COMBO" % stats["combo"] if stats["combo"] > 1 else ""
	accuracy_label.text = "%.1f%%" % stats["accuracy"]
	progress_label.text = "%d / %d" % [stats["resolved"], stats["total"]]
	gauge_bar.value = stats["gauge"]


func setup_boss(name: String, health: int) -> void:
	%BossPanel.visible = health > 0
	%BossName.text = name
	%BossHealth.max_value = health
	%BossHealth.value = health


func update_boss(health: int, guard_active: bool) -> void:
	%BossHealth.value = health
	%BossHint.text = "⚠ GUARD BEAT · PERFECT ONLY" if guard_active else "NEXT GUARD APPROACHING"
