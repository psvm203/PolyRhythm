# PolyRhythm timing architecture

## Existing flow audit

The level builds cumulative note times from polygon side counts and BPM. `Conductor`
starts a monotonic microsecond clock after the countdown, while `Rotator` advances its
visual transition from frame deltas. Music starts in the same callback, but its playback
position is not currently used as a clock source.

The judgment path is:

1. `Level` calculates cumulative visual landing times.
2. `Conductor` chooses the current center from observed contact, remaining transition
   duration, or the precomputed visual time.
3. An input event is compared to that center after applying `judgment_offset_sec`.
4. Early accepted inputs wait until visual contact before being emitted.
5. `RunState` receives the result and updates score, combo, accuracy, and timing data.

## Sources of drift

- `Conductor` uses `Time.get_ticks_usec()`, while `Rotator` integrates `_process(delta)`.
- Audio begins beside the game clock but does not continuously discipline it.
- The first observed contact is sampled at a frame boundary instead of interpolated.
- Calibration owns a separate microsecond schedule and separate statistics.
- Pause, boss time-stop, and scene pause each coordinate audio and visual clocks manually.

## Target invariants

- One `RhythmClock` owns elapsed game time and pause accounting.
- An immutable note timeline owns every contact and judgment boundary.
- Visual contact is interpolated between the previous and current edge gaps.
- Every accepted input passes through one judgment pipeline and produces one trace.
- Calibration reuses the same timeline and robust statistics.
- Debug overlays and persisted traces consume snapshots without changing game state.

## Units and sign convention

- Internal absolute time: integer microseconds.
- Public gameplay time: floating-point seconds.
- Timing delta: `input_time - judgment_center`; negative is early, positive is late.
- User offset is added to the visual contact to form the judgment center.
- Audio drift: `audio_time - game_time`; positive means audio is ahead.

## Pause and resume order

Pause captures the clock first, then pauses audio and visuals. Resume unpauses audio and
visuals first and resumes the clock last. Boss time-stop uses the same order. A paused
duration must never appear in elapsed game time or move a note boundary.

## Compatibility contract

Level YAML, score calculation, star ratings, progression data, and result labels remain
unchanged. New trace files are diagnostic only and must not be required to load a save.
