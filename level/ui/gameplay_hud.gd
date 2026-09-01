extends CanvasLayer

@onready var score_label: Label = %Score
@onready var combo_label: Label = %Combo
@onready var accuracy_label: Label = %Accuracy
@onready var progress_label: Label = %Progress
@onready var gauge_bar: ProgressBar = %Gauge
@onready var stage_progress: ProgressBar = %StageProgress


func update_stats(stats: Dictionary) -> void:
	score_label.text = "점수  %07d" % stats["score"]
	combo_label.text = "%d 콤보" % stats["combo"] if stats["combo"] > 1 else ""
	accuracy_label.text = "정확도  %.1f%%" % stats["accuracy"]
	progress_label.text = "진행  %d / %d" % [stats["resolved"], stats["total"]]
	gauge_bar.value = stats["gauge"]
	stage_progress.max_value = maxi(stats["total"], 1)
	stage_progress.value = stats["resolved"]


func setup_boss(name: String, health: int, samurai: bool = false, time_mage: bool = false) -> void:
	%BossPanel.visible = health > 0
	%BossName.text = name
	%BossHealth.max_value = health
	%BossHealth.value = health
	%BossHint.text = "곧 시간 정지" if time_mage else "육각형 분할에 대비" if samurai else "곧 가드 비트"


func update_boss(health: int, guard_active: bool) -> void:
	%BossHealth.value = health
	%BossHint.text = "가드 비트: PERFECT 판정만 유효" if guard_active else "곧 가드 비트"


func update_samurai_attack(health: int, attack_active: bool) -> void:
	%BossHealth.value = health
	%BossHint.text = "육각형 분할: 삼각형에 맞춰 두 번 입력" if attack_active else "바뀌는 경로에 집중"


func update_time_spell(health: int, spell_active: bool, frozen: bool) -> void:
	%BossHealth.value = health
	%BossHint.text = "시간 정지" if frozen else "시간 해제: PERFECT 입력" if spell_active else "시간 흐름 복구"
