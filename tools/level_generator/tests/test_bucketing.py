"""Tests for bucketing and sequence modules."""

from __future__ import annotations

import numpy as np

from level_generator.bucketing import PolygonSlot, assign
from level_generator.energy import Envelope
from level_generator.sequence import smooth


def _make_envelope(values: list[float], hop_seconds: float = 0.1) -> Envelope:
    arr = np.array(values, dtype=np.float32)
    times = np.arange(arr.size) * hop_seconds
    return Envelope(values=arr, times=times, hop_seconds=hop_seconds)


def test_assign_quantizes_within_bounds() -> None:
    # 8 frames at 0.5s hop => 4s total. With 120 BPM and 1 beat per polygon,
    # slots are 0.5s wide, so 8 slots.
    env = _make_envelope([0.0, 0.0, 1.0, 0.0, 0.0, 6.0, 0.0, 0.0], hop_seconds=0.5)
    slots = assign(env, bpm=120.0, beats_per_polygon=1, min_sides=3, max_sides=8)
    assert len(slots) == 8
    for s in slots:
        assert 3 <= s.sides <= 8


def test_assign_uniform_returns_triangles() -> None:
    env = _make_envelope([0.5] * 8, hop_seconds=0.5)
    slots = assign(env, bpm=120.0, beats_per_polygon=1, min_sides=3, max_sides=8)
    assert all(s.sides == 3 for s in slots)


def test_assign_uses_peak_for_vertex_count() -> None:
    env = _make_envelope([0.0, 0.1, 0.0, 0.1, 0.0, 1.0, 0.0, 1.0], hop_seconds=0.5)
    slots = assign(env, bpm=120.0, beats_per_polygon=1, min_sides=3, max_sides=8)
    # Slot 5 has the highest peak (value 1.0).
    sides_by_slot = [s.sides for s in slots]
    assert max(sides_by_slot) == sides_by_slot[5]


def test_smooth_forces_triangle_ends() -> None:
    slots = [PolygonSlot(index=i, t_start=i, t_end=i + 1, energy=0.0, sides=6) for i in range(5)]
    out = smooth(slots, window=3, force_triangle_ends=True, ensure_adjacent_diff=False)
    assert out[0].sides == 3
    assert out[-1].sides == 3


def test_smooth_ensures_adjacent_diff() -> None:
    # All 5s but max sides is 8, so we should see nudges.
    slots = [PolygonSlot(index=i, t_start=i, t_end=i + 1, energy=0.0, sides=5) for i in range(4)]
    out = smooth(slots, window=1, force_triangle_ends=False, ensure_adjacent_diff=True)
    sides = [s.sides for s in out]
    for a, b in zip(sides, sides[1:]):
        assert a != b
