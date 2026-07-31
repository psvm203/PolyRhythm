"""Tests for bpm.detect."""

from __future__ import annotations

from level_generator import bpm
from tests.fixtures import kick_at


def test_hint_returns_value() -> None:
    audio = kick_at(120.0)
    assert bpm.detect(audio, hint=140.0) == 140.0


def test_hint_must_be_positive() -> None:
    audio = kick_at(120.0)
    try:
        bpm.detect(audio, hint=0.0)
    except ValueError:
        return
    raise AssertionError("expected ValueError")


def test_detect_kick_track() -> None:
    audio = kick_at(120.0, sr=22050)
    detected = bpm.detect(audio)
    assert 100.0 <= detected <= 140.0, f"unexpected BPM: {detected}"


def test_beat_duration() -> None:
    assert abs(bpm.beat_duration(120.0) - 0.5) < 1e-9
