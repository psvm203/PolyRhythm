"""Tests for templating .tres rendering."""

from __future__ import annotations

from pathlib import Path

from level_generator.bucketing import PolygonSlot
from level_generator.templating import render, write


def _make_slots(sides: list[int]) -> list[PolygonSlot]:
    return [
        PolygonSlot(index=i, t_start=i, t_end=i + 1, energy=0.0, sides=s)
        for i, s in enumerate(sides)
    ]


def test_render_contains_sequence() -> None:
    text = render(_make_slots([3, 5, 4]), seconds_per_edge=0.5)
    assert "Array[int]([3, 5, 4])" in text
    assert "seconds_per_edge = 0.5" in text


def test_render_strips_trailing_zeros() -> None:
    text = render(_make_slots([3]), seconds_per_edge=0.123000)
    assert "seconds_per_edge = 0.123" in text


def test_write_creates_parent_dirs(tmp_path: Path) -> None:
    target = tmp_path / "nested" / "level_data.tres"
    write(_make_slots([3, 4]), seconds_per_edge=0.5, path=target)
    assert target.exists()
    assert "Array[int]([3, 4])" in target.read_text()
