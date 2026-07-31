"""Render a Godot ``level_data.tres`` resource."""

from __future__ import annotations

from pathlib import Path

from .bucketing import PolygonSlot

_DEFAULT_HEADER = """[gd_resource type="Resource" script_class="LevelData" load_steps=2 format=3]

[ext_resource type="Script" path="res://level/data/level_data.gd" id="1_level_data"]

[resource]
script = ExtResource("1_level_data")
sides_sequence = Array[int]([{sequence}])
seconds_per_edge = {seconds_per_edge}
"""


def render(slots: list[PolygonSlot], seconds_per_edge: float) -> str:
    """Return the full text content of a ``level_data.tres`` file."""
    sequence = ", ".join(str(s.sides) for s in slots)
    return _DEFAULT_HEADER.format(sequence=sequence, seconds_per_edge=_fmt(seconds_per_edge))


def write(slots: list[PolygonSlot], seconds_per_edge: float, path: Path | str) -> None:
    """Render and write the resource to disk."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render(slots, seconds_per_edge), encoding="utf-8")


def _fmt(value: float) -> str:
    """Format a float matching Godot's terse style (e.g. ``0.5``)."""
    rounded = round(value, 6)
    text = f"{rounded:.6f}".rstrip("0").rstrip(".")
    return text if text else "0"
