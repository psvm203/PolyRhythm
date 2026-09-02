extends SceneTree

const SCENE_CONTRACTS := {
	"res://main/main_screen.tscn": [
		"Content/Menu/StartButton",
		"StageScreen/StageLayout/CardsSlot/Cards/StageOne/StageOneButton",
		"SettingsScreen",
		"UnlockDialogue",
	],
	"res://level/level.tscn": [
		"Rotator",
		"Conductor",
		"CountdownOverlay",
		"ResultOverlay",
		"TimingDebugOverlay",
	],
	"res://editor/level_editor.tscn": [
		"Root/Header",
		"Root/CanvasPanel/CanvasRows/TimelineScroll/Timeline",
	],
}

var _failures := 0
var _assertions := 0


func _init() -> void:
	for scene_path in SCENE_CONTRACTS:
		var packed_scene := load(scene_path) as PackedScene
		_expect(packed_scene != null, "%s loads" % scene_path)
		if packed_scene == null:
			continue
		var instance := packed_scene.instantiate()
		_expect(instance != null, "%s instantiates" % scene_path)
		for node_path in SCENE_CONTRACTS[scene_path]:
			_expect(instance.has_node(node_path), "%s contains %s" % [scene_path, node_path])
		instance.free()
	if _failures == 0:
		print("Scene contract tests passed: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("Scene contract tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		return
	_failures += 1
	push_error(label)
