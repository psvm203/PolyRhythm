extends CanvasLayer

var conductor: Node
var rotator: Node
var music: Node
var timeline

@onready var report: Label = %Report


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func set_sources(conductor_node: Node, rotator_node: Node, music_node: Node, note_timeline) -> void:
	conductor = conductor_node
	rotator = rotator_node
	music = music_node
	timeline = note_timeline


func toggle() -> void:
	visible = not visible


func _process(_delta: float) -> void:
	if not visible or conductor == null or rotator == null:
		return
	var index: int = rotator.current_index
	var next_contact := 0.0
	if timeline != null and index < timeline.size():
		next_contact = float(timeline.entry(index)["contact_sec"])
	var latest: Dictionary = conductor.timing_trace.latest()
	var audio_time: float = float(music.get_playback_position()) if music != null and music.has_method(&"get_playback_position") else 0.0
	report.text = (
		"TIMING DEBUG  [F3]\n"
		+ "game      %9.3f ms\n" % (conductor.game_time * 1000.0)
		+ "audio     %9.3f ms\n" % (audio_time * 1000.0)
		+ "drift     %+9.3f ms\n" % (conductor.audio_drift_sec * 1000.0)
		+ "next      %+9.3f ms\n" % ((next_contact - conductor.game_time) * 1000.0)
		+ "contact   %9.3f px\n" % float(rotator.get_entrance_edge_gap())
		+ "input     %+9.3f ms  %s\n" % [float(latest.get("timing_delta_ms", 0.0)), str(latest.get("result", "-"))]
		+ "device    %s\n" % str(latest.get("device", "-"))
		+ "offset    %+.1f ms\n" % (conductor.judgment_offset_sec * 1000.0)
		+ "fps       %d" % Engine.get_frames_per_second()
	)
