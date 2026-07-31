"""Spectral energy envelope per frequency band."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import librosa
import numpy as np

from .audio import Audio

Band = Literal["low", "mid", "high", "combined"]

_BAND_RANGES: dict[str, tuple[float, float]] = {
    "low": (20.0, 250.0),
    "mid": (250.0, 2000.0),
    "high": (2000.0, 8000.0),
}

_DEFAULT_WEIGHTS: dict[str, float] = {
    "low": 0.4,
    "mid": 0.4,
    "high": 0.2,
}


@dataclass(frozen=True)
class Envelope:
    """Time-aligned energy envelope.

    Attributes:
        values: 1-D array of envelope magnitudes in [0, 1] (after normalization).
        times: Start time of each frame in seconds.
        hop_seconds: Frame hop size in seconds.
    """

    values: np.ndarray
    times: np.ndarray
    hop_seconds: float

    @property
    def n_frames(self) -> int:
        return int(self.values.shape[0])


def compute(
    audio: Audio,
    band: Band = "combined",
    hop_length: int = 512,
    smooth_ms: float = 50.0,
    n_fft: int = 2048,
) -> Envelope:
    """Compute the energy envelope for the requested band.

    Args:
        audio: Loaded audio.
        band: Frequency band to use. ``combined`` is a weighted mix of low/mid/high.
        hop_length: STFT hop size in samples.
        smooth_ms: Moving-average smoothing window in milliseconds.
        n_fft: STFT window size.
    """
    if band not in _BAND_RANGES and band != "combined":
        raise ValueError(f"Unknown band: {band!r}")

    stft = np.abs(librosa.stft(audio.y, n_fft=n_fft, hop_length=hop_length))
    freqs = librosa.fft_frequencies(sr=audio.sr, n_fft=n_fft)
    times = librosa.frames_to_time(np.arange(stft.shape[1]), sr=audio.sr, hop_length=hop_length)

    if band == "combined":
        weighted = np.zeros(stft.shape[1], dtype=np.float32)
        for name, weight in _DEFAULT_WEIGHTS.items():
            weighted += _band_curve(stft, freqs, _BAND_RANGES[name]) * weight
        raw = weighted
    else:
        raw = _band_curve(stft, freqs, _BAND_RANGES[band])

    raw = _to_db(raw)
    smoothed = _smooth(raw, hop_length=hop_length, sr=audio.sr, smooth_ms=smooth_ms)
    normalized = _normalize(smoothed)
    return Envelope(
        values=normalized,
        times=times.astype(np.float64),
        hop_seconds=float(hop_length / audio.sr),
    )


def _band_curve(stft: np.ndarray, freqs: np.ndarray, band: tuple[float, float]) -> np.ndarray:
    low, high = band
    mask = (freqs >= low) & (freqs < high)
    if not mask.any():
        return np.zeros(stft.shape[1], dtype=np.float32)
    return stft[mask].sum(axis=0).astype(np.float32)


def _to_db(curve: np.ndarray) -> np.ndarray:
    curve = np.maximum(curve, 1e-10)
    return librosa.amplitude_to_db(curve, ref=curve.max()).astype(np.float32)


def _normalize(curve: np.ndarray) -> np.ndarray:
    lo = float(curve.min())
    hi = float(curve.max())
    if hi - lo < 1e-9:
        return np.zeros_like(curve)
    return ((curve - lo) / (hi - lo)).astype(np.float32)


def _smooth(curve: np.ndarray, *, hop_length: int, sr: int, smooth_ms: float) -> np.ndarray:
    if smooth_ms <= 0:
        return curve
    hop_seconds = hop_length / sr
    window = max(1, int(round(smooth_ms / 1000.0 / hop_seconds)))
    if window <= 1:
        return curve
    kernel = np.ones(window, dtype=np.float32) / window
    return np.convolve(curve, kernel, mode="same").astype(np.float32)
