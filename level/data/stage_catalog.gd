class_name StageCatalog
extends RefCounted

const DEFAULT_STAGE := 1
const UNLOCK_SPEAKER := "루미 (리듬 안내자)"

const _STAGES := {
	1: {
		"name": "Rhythm Start",
		"data_path": "res://level/data/level_1.yaml",
		"unlock_dialogue": [],
	},
	2: {
		"name": "Beat Flow",
		"data_path": "res://level/data/level_2.yaml",
		"unlock_dialogue": [
			"첫 스테이지를 통과했네.",
			"STAGE 02: Beat Flow가 열렸어.",
			"이번에는 박자 변화가 더 잦아. 도형이 닿는 순간에 집중해.",
		],
	},
	3: {
		"name": "Shape Samurai",
		"data_path": "res://level/data/level_3.yaml",
		"unlock_dialogue": [
			"Beat Flow 클리어. 감이 잡힌 것 같네.",
			"STAGE 03: Shape Samurai가 열렸어.",
			"육각형이 둘로 갈라질 때 입력도 두 번 필요해. 경로를 잘 봐.",
		],
	},
	4: {
		"name": "Time Rift",
		"data_path": "res://level/data/level_4.yaml",
		"unlock_dialogue": [
			"Shape Samurai를 쓰러뜨렸어.",
			"마지막 스테이지, STAGE 04: Time Rift가 열렸어.",
			"시간 정지가 풀리는 순간을 놓치지 마.",
		],
	},
}


static func stage_numbers() -> Array[int]:
	var numbers: Array[int] = []
	for stage_number in _STAGES:
		numbers.append(stage_number)
	numbers.sort()
	return numbers


static func data_path(stage_number: int) -> String:
	return String(_stage(stage_number)["data_path"])


static func display_name(stage_number: int) -> String:
	return String(_stage(stage_number)["name"])


static func unlock_dialogue(stage_number: int) -> Array[String]:
	var lines: Array[String] = []
	for line in _stage(stage_number)["unlock_dialogue"]:
		lines.append(String(line))
	return lines


static func _stage(stage_number: int) -> Dictionary:
	return _STAGES.get(stage_number, _STAGES[DEFAULT_STAGE])
