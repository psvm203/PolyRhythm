class_name AudioStreamLoader
extends RefCounted


static func load_stream(path: String) -> AudioStream:
	if path.begins_with("res://") and ResourceLoader.exists(path, "AudioStream"):
		return load(path) as AudioStream
	if path.get_extension().to_lower() == "wav" and FileAccess.file_exists(path):
		return AudioStreamWAV.load_from_file(path)
	return null
