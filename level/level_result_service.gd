class_name LevelResultService
extends RefCounted


static func build(
		run_state: RunState,
		completed: bool,
		stage_number: int,
		custom_level: bool,
		bpm: float,
		fallback_total_notes: int,
) -> Dictionary:
	var stats := run_state.snapshot()
	var rank := run_state.rank(completed)
	return {
		"stats": stats,
		"rank": rank,
		"trace_metadata": {
			"stage": stage_number,
			"custom_level": custom_level,
			"bpm": bpm,
			"completed": completed,
			"rank": rank,
			"resolved_notes": int(stats.get("resolved", 0)),
			"total_notes": int(stats.get("total", fallback_total_notes)),
		},
	}
