"""Post-processing of the vertex count sequence."""

from __future__ import annotations

import numpy as np
from scipy.ndimage import median_filter

from .bucketing import PolygonSlot


def smooth(
    slots: list[PolygonSlot],
    *,
    window: int = 3,
    force_triangle_ends: bool = True,
    ensure_adjacent_diff: bool = True,
) -> list[PolygonSlot]:
    """Smooth a polygon sequence and apply finishing constraints.

    Args:
        slots: Polygon slots from :func:`bucketing.assign`.
        window: Median filter window size (>= 1).
        force_triangle_ends: Force first and last entries to be triangles
            (vertex count = 3) for a clean visual intro/outro.
        ensure_adjacent_diff: Guarantee no two adjacent polygons share the same
            vertex count, by nudging one of them up or down.
    """
    if not slots:
        return slots
    if window < 1:
        raise ValueError("window must be >= 1")

    sides = np.array([s.sides for s in slots], dtype=np.int32)
    if window > 1 and sides.size >= window:
        smoothed = median_filter(sides, size=window, mode="nearest")
    else:
        smoothed = sides.copy()

    if force_triangle_ends:
        smoothed[0] = 3
        smoothed[-1] = 3

    if ensure_adjacent_diff and smoothed.size > 1:
        smoothed = _enforce_adjacent_diff(smoothed)

    return [
        PolygonSlot(
            index=i,
            t_start=slot.t_start,
            t_end=slot.t_end,
            energy=slot.energy,
            sides=int(smoothed[i]),
        )
        for i, slot in enumerate(slots)
    ]


def _enforce_adjacent_diff(sides: np.ndarray) -> np.ndarray:
    out = sides.copy()
    for i in range(1, out.size):
        if out[i] == out[i - 1]:
            # Prefer to nudge the later one up; if it would exceed bounds, nudge down.
            if out[i] < 8:
                out[i] += 1
            else:
                out[i] -= 1
    return out
