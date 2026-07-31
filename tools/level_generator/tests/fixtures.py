"""Synthetic audio builders for tests."""

from __future__ import annotations

import numpy as np

from level_generator.audio import Audio


def sine_burst(*, sr: int, freq: float, duration: float, amplitude: float = 0.9) -> Audio:
    """Generate a mono sine tone of the given frequency and duration."""
    n = int(sr * duration)
    t = np.arange(n) / sr
    y = (amplitude * np.sin(2 * np.pi * freq * t)).astype(np.float32)
    return Audio(y=y, sr=sr, duration=float(duration))


def kick_at(
    bpm: float,
    *,
    sr: int = 22050,
    measures: int = 4,
    amplitude: float = 0.9,
) -> Audio:
    """Synthesize a click track with a kick at every beat for ``measures`` bars.

    Useful for BPM detection round-trips.
    """
    beat_seconds = 60.0 / bpm
    total = beat_seconds * 4 * measures
    n = int(sr * total)
    y = np.zeros(n, dtype=np.float32)
    n_beats = measures * 4
    for i in range(n_beats):
        center = int(i * beat_seconds * sr)
        if center >= n:
            break
        # 50 ms exponentially decaying sinusoid at 60 Hz.
        decay_samples = int(0.05 * sr)
        idx = np.arange(decay_samples)
        env = np.exp(-idx / (0.01 * sr))
        click = amplitude * env * np.sin(2 * np.pi * 60.0 * idx / sr)
        end = min(center + decay_samples, n)
        y[center:end] += click[: end - center]
    return Audio(y=y, sr=sr, duration=total)
