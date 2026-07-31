"""WAV loading helpers."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import librosa
import numpy as np


@dataclass(frozen=True)
class Audio:
    y: np.ndarray
    sr: int
    duration: float

    @property
    def n_samples(self) -> int:
        return int(self.y.shape[0])


def load(path: Path | str, target_sr: int | None = None) -> Audio:
    """Load an audio file as mono float32.

    Args:
        path: Path to an audio file readable by librosa/soundfile.
        target_sr: If set, resample to this rate. Default keeps the original.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Audio file not found: {path}")
    y, sr = librosa.load(path.as_posix(), sr=target_sr, mono=True)
    duration = float(y.shape[0] / sr)
    return Audio(y=np.asarray(y, dtype=np.float32), sr=int(sr), duration=duration)
