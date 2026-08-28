from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
OUTPUT = Path(__file__).resolve().parents[1] / "main" / "audio"


def write_tone(name: str, duration: float, sample_fn) -> None:
    frames = bytearray()
    total = int(SAMPLE_RATE * duration)
    for index in range(total):
        time = index / SAMPLE_RATE
        sample = max(-1.0, min(1.0, sample_fn(time, duration)))
        packed = struct.pack("<h", int(sample * 32767))
        frames.extend(packed)
        frames.extend(packed)
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(frames)


def focus_tone(time: float, duration: float) -> float:
    progress = time / duration
    envelope = math.sin(math.pi * progress) ** 1.6 * math.exp(-progress * 1.6)
    phase = 2.0 * math.pi * (880.0 * time + 620.0 * time * time)
    shimmer = math.sin(phase) * 0.72 + math.sin(phase * 2.02) * 0.18
    return shimmer * envelope * 0.34


def click_tone(time: float, duration: float) -> float:
    progress = time / duration
    envelope = math.exp(-progress * 5.2) * min(1.0, progress * 32.0)
    frequency = 560.0 - 190.0 * progress
    phase = 2.0 * math.pi * frequency * time
    body = math.sin(phase) * 0.76 + math.sin(phase * 0.5) * 0.24
    transient = math.sin(2.0 * math.pi * 1800.0 * time) * math.exp(-progress * 24.0)
    return (body + transient * 0.35) * envelope * 0.5


OUTPUT.mkdir(parents=True, exist_ok=True)
write_tone("ui_focus.wav", 0.09, focus_tone)
write_tone("ui_click.wav", 0.13, click_tone)
