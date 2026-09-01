extends SceneTree

const AudioStreamLoaderScript = preload("res://level/audio/audio_stream_loader.gd")
const SequenceHistoryScript = preload("res://editor/model/sequence_history.gd")
const MUSIC_PATH := "res://level/data/BR-Freaky_feat_LezaLee_-fulllength-loopable-121_9BPM-Dm.WAV"

var _failures := 0


func _init() -> void:
	var history := SequenceHistoryScript.new()
	history.reset([3, 4])
	history.record([3, 4, 5])
	_expect(history.can_undo(), "recorded sequence can be undone")
	_expect(history.undo() == [3, 4], "undo restores previous sequence")
	_expect(history.can_redo(), "undone sequence can be redone")
	_expect(history.redo() == [3, 4, 5], "redo restores newer sequence")
	history.undo()
	history.record([3, 6])
	_expect(not history.can_redo(), "new edit discards redo branch")
	var state := {"sequence": [3], "events": [{"name": "cue", "at": [1]}]}
	history.reset(state)
	state["events"][0]["at"].append(2)
	_expect(not history.can_undo(), "reset creates a new history root")
	history.record({"sequence": [3, 4], "events": []})
	_expect(history.undo()["events"][0]["at"] == [1], "history deeply preserves event state")
	_expect(AudioStreamLoaderScript.load_stream(MUSIC_PATH) != null, "shared loader resolves project audio")
	_expect(AudioStreamLoaderScript.load_stream("res://missing.wav") == null, "shared loader rejects missing audio")
	if _failures == 0:
		print("Editor component tests passed: 9 assertions")
		quit(0)
	else:
		push_error("Editor component tests failed: %d assertion(s)" % _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
