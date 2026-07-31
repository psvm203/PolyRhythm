"""Map an energy envelope into per-polygon vertex counts."""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from .energy import Envelope


@dataclass(frozen=True)
class PolygonSlot:
    index: int
    t_start: float
    t_end: float
    energy: float
    sides: int


def assign(
    envelope: Envelope,
    bpm: float,
    *,
    beats_per_polygon: int = 1,
    min_sides: int = 3,
    max_sides: int = 8,
) -> list[PolygonSlot]:
    """Bucket the envelope into beat-aligned polygon slots.

    Args:
        envelope: Time-aligned energy envelope.
        bpm: Detected BPM.
        beats_per_polygon: Number of beats per polygon slot.
        min_sides: Minimum polygon vertex count (>= 3).
        max_sides: Maximum polygon vertex count.

    Returns:
        Polygon slots ordered by time. ``sides`` is in ``[min_sides, max_sides]``.
    """
    if min_sides < 3:
        raise ValueError("min_sides must be >= 3")
    if max_sides < min_sides:
        raise ValueError("max_sides must be >= min_sides")
    if beats_per_polygon <= 0:
        raise ValueError("beats_per_polygon must be positive")

    beat_seconds = 60.0 / bpm
    slot_seconds = beat_seconds * beats_per_polygon
    last_time = float(envelope.times[-1] + envelope.hop_seconds) if envelope.n_frames else 0.0
    n_slots = max(1, int(math.floor(last_time / slot_seconds)))

    raw = np.array(
        [
            _slot_mean(envelope, idx * slot_seconds, (idx + 1) * slot_seconds)
            for idx in range(n_slots)
        ],
        dtype=np.float32,
    )

    sides = _quantize(raw, min_sides=min_sides, max_sides=max_sides)
    return [
        PolygonSlot(
            index=idx,
            t_start=idx * slot_seconds,
            t_end=(idx + 1) * slot_seconds,
            energy=float(raw[idx]),
            sides=int(sides[idx]),
        )
        for idx in range(n_slots)
    ]


def _slot_mean(envelope: Envelope, t_start: float, t_end: float) -> float:
    if envelope.n_frames == 0:
        return 0.0
    frame_t = envelope.times
    frame_end = frame_t + envelope.hop_seconds
    mask = (frame_end > t_start) & (frame_t < t_end)
    if not mask.any():
        # Clamp to nearest frame at the end of the song.
        return float(envelope.values[-1])
    return float(envelope.values[mask].mean())


def _quantize(values: np.ndarray, *, min_sides: int, max_sides: int) -> np.ndarray:
    if values.size == 0:
        return np.zeros(0, dtype=np.int32)
    lo = float(values.min())
    hi = float(values.max())
    if hi - lo < 1e-9:
        # All silent/audio has uniform energy — default to triangle.
        return np.full(values.shape, min_sides, dtype=np.int32)
    norm = (values - lo) / (hi - lo)
    scaled = np.round(norm * (max_sides - min_sides) + min_sides).astype(np.int32)
    return np.clip(scaled, min_sides, max_sides)
