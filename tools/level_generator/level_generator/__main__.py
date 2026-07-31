"""CLI entry point: ``python -m level_generator <wav> ...``."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

from . import bpm, bucketing, energy, preview, sequence, templating
from .audio import Audio, load


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    wav_path = Path(args.wav)
    if not wav_path.exists():
        print(f"audio file not found: {wav_path}", file=sys.stderr)
        return 1

    audio = load(wav_path, target_sr=args.sr)
    detected_bpm = bpm.detect(audio, hint=args.bpm_hint)
    beat_seconds = bpm.beat_duration(detected_bpm)
    seconds_per_edge = beat_seconds / args.edges_per_beat

    envelope = energy.compute(audio, band=args.band, smooth_ms=args.smooth_ms)
    raw_slots = bucketing.assign(
        envelope,
        detected_bpm,
        beats_per_polygon=args.beats_per_polygon,
        min_sides=args.min_sides,
        max_sides=args.max_sides,
    )
    slots = sequence.smooth(
        raw_slots,
        window=args.sequence_smooth,
        force_triangle_ends=args.force_triangle_ends,
        ensure_adjacent_diff=args.enforce_adjacent_diff,
    )

    templating.write(slots, seconds_per_edge, args.output)
    print(f"wrote {args.output} (bpm={detected_bpm:.2f}, polygons={len(slots)})")

    if args.report:
        _write_report(args.report, detected_bpm, seconds_per_edge, envelope, slots)

    if args.preview:
        from .audio import Audio  # noqa: F401  (cycle avoidance)

        slope = _downsample_wave(audio, target=2000)
        saved = preview.plot(slope, envelope, slots, output=args.preview, show=False)
        print(f"preview saved: {saved}")

    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="level-generator",
        description="Generate a Godot polyrhythm level from an audio file.",
    )
    parser.add_argument("wav", help="Input audio file (WAV/MP3/FLAC).")
    parser.add_argument(
        "--output",
        default="level/data/level_data.tres",
        help="Path to write the generated level_data.tres.",
    )
    parser.add_argument(
        "--bpm-hint",
        type=float,
        default=None,
        help="Force a specific BPM instead of auto-detecting.",
    )
    parser.add_argument(
        "--sr",
        type=int,
        default=None,
        help="Resample audio to this rate before analysis.",
    )
    parser.add_argument(
        "--band",
        choices=["low", "mid", "high", "combined"],
        default="combined",
        help="Frequency band that drives the vertex count.",
    )
    parser.add_argument(
        "--edges-per-beat",
        type=int,
        default=4,
        help="Number of polygon edges per beat (default: 4 = sixteenth notes).",
    )
    parser.add_argument(
        "--beats-per-polygon",
        type=int,
        default=1,
        help="Number of beats each polygon spans.",
    )
    parser.add_argument(
        "--min-sides",
        type=int,
        default=3,
        help="Minimum polygon vertex count.",
    )
    parser.add_argument(
        "--max-sides",
        type=int,
        default=8,
        help="Maximum polygon vertex count.",
    )
    parser.add_argument(
        "--smooth-ms",
        type=float,
        default=50.0,
        help="Moving-average smoothing window for the envelope (ms).",
    )
    parser.add_argument(
        "--sequence-smooth",
        type=int,
        default=3,
        help="Median filter window applied to the polygon's vertex sequence.",
    )
    parser.add_argument(
        "--force-triangle-ends",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Force first and last polygons to be triangles.",
    )
    parser.add_argument(
        "--enforce-adjacent-diff",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Prevent two adjacent polygons from sharing the same vertex count.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Optional path to write a JSON build report.",
    )
    parser.add_argument(
        "--preview",
        type=Path,
        default=None,
        help="Optional path to write a PNG preview.",
    )
    return parser


def _downsample_wave(audio: Audio, *, target: int) -> np.ndarray:
    """Downsample the waveform to roughly ``target`` evenly spaced points.

    Uses peak (max absolute value) per block so the envelope preserves the
    amplitude shape rather than averaging oscillations to zero.
    """
    if audio.n_samples <= target:
        return audio.y
    factor = audio.n_samples // target
    blocks = audio.y[: factor * target].reshape(-1, factor)
    return np.max(np.abs(blocks), axis=1)


def _write_report(
    path: Path,
    bpm: float,
    seconds_per_edge: float,
    envelope,
    slots,
) -> None:
    report = {
        "bpm": bpm,
        "seconds_per_edge": seconds_per_edge,
        "envelope_hop_seconds": envelope.hop_seconds,
        "polygons": [
            {
                "index": s.index,
                "t_start": s.t_start,
                "t_end": s.t_end,
                "energy": s.energy,
                "sides": s.sides,
            }
            for s in slots
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"report saved: {path}")


if __name__ == "__main__":
    raise SystemExit(main())
