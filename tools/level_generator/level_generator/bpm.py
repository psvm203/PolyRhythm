"""BPM detection wrapping librosa."""

from __future__ import annotations

import warnings

import librosa
import numpy as np

from .audio import Audio


def detect(audio: Audio, hint: float | None = None) -> float:
    """Return BPM for the given audio.

    Args:
        audio: Loaded audio.
        hint: If provided, return this value verbatim. Otherwise run
            ``librosa.beat.tempo`` and take the median tempo.
    """
    if hint is not None:
        if hint <= 0:
            raise ValueError("BPM hint must be positive")
        return float(hint)
    # librosa 0.10+ emits a misleading FutureWarning from `librosa.beat.tempo`;
    # the move to `librosa.feature.rhythm.tempo` is not yet shipped in 0.11.
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", FutureWarning)
        tempo = librosa.beat.tempo(y=audio.y, sr=audio.sr, aggregate=np.median)
    if tempo.size == 0:
        raise RuntimeError("BPM detection failed: no tempo returned")
    return float(tempo[0])


def beat_duration(bpm: float) -> float:
    """Seconds per beat at the given BPM."""
    if bpm <= 0:
        raise ValueError("BPM must be positive")
    return 60.0 / bpm
