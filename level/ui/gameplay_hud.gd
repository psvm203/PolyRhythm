extends CanvasLayer

@onready var score_label: Label = %Score
@onready var combo_label: Label = %Combo
@onready var accuracy_label: Label = %Accuracy
@onready var progress_label: Label = %Progress
@onready var gauge_bar: ProgressBar = %Gauge
@onready var stage_progress: ProgressBar = %StageProgress


func update_stats(stats: Dictionary) -> void:
	score_label.text = "%07d" % stats["score"]
	combo_label.text = "%d COMBO" % stats["combo"] if stats["combo"] > 1 else ""
	accuracy_label.text = "%.1f%%" % stats["accuracy"]
	progress_label.text = "%d / %d" % [stats["resolved"], stats["total"]]
	gauge_bar.value = stats["gauge"]
	stage_progress.max_value = maxi(stats["total"], 1)
	stage_progress.value = stats["resolved"]


func setup_boss(name: String, health: int, samurai: bool = false, time_mage: bool = false) -> void:
	%BossPanel.visible = health > 0
	%BossName.text = name
	%BossHealth.max_value = health
	%BossHealth.value = health
	%BossHint.text = "⏳ TIME STOP APPROACHING" if time_mage else "⚔ HEXAGONS WILL SPLIT" if samurai else "NEXT GUARD APPROACHING"


func update_boss(health: int, guard_active: bool) -> void:
	%BossHealth.value = health
	%BossHint.text = "⚠ GUARD BEAT · PERFECT ONLY" if guard_active else "NEXT GUARD APPROACHING"


func update_samurai_attack(health: int, attack_active: bool) -> void:
	%BossHealth.value = health
	%BossHint.text = "⚔ HEXAGON SPLIT · TWO TRIANGLE BEATS" if attack_active else "WATCH THE PATH CHANGE"


func update_time_spell(health: int, spell_active: bool, frozen: bool) -> void:
	%BossHealth.value = health
	%BossHint.text = "⏳ TIME STOP" if frozen else "◆ BREAK THE TIME SPELL · PERFECT" if spell_active else "TIME FLOW RESTORED"
