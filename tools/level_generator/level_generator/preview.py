"""matplotlib preview of the generated level."""

from __future__ import annotations

from pathlib import Path

import numpy as np

from .bucketing import PolygonSlot


def plot(
    slope: np.ndarray,
    envelope,  # energy.Envelope
    slots: list[PolygonSlot],
    *,
    output: Path | str | None = None,
    show: bool = False,
) -> Path | None:
    """Render a 2-panel preview: waveform+envelope on top, polygon vertex count below.

    Args:
        slope: 1-D downsampled waveform array.
        envelope: Energy envelope (energy.Envelope).
        slots: Polygon slots.
        output: Where to save the PNG. If None, the result is not saved.
        show: Pass True to also display the figure interactively.
    """
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, (ax_top, ax_bottom) = plt.subplots(
        2, 1, figsize=(12, 6), sharex=True, gridspec_kw={"height_ratios": [2, 1]}
    )

    slope_t = np.linspace(0.0, float(envelope.times[-1] + envelope.hop_seconds), slope.size)
    ax_top.plot(slope_t, slope, color="#888", linewidth=0.5, label="waveform")
    ax_top.plot(envelope.times, envelope.values, color="#1f77b4", linewidth=1.0, label="envelope")
    ax_top.set_ylabel("level")
    ax_top.legend(loc="upper right")
    ax_top.set_title("Energy envelope")

    if slots:
        ax_bottom.bar(
            [s.t_start for s in slots],
            [s.sides for s in slots],
            width=[s.t_end - s.t_start for s in slots],
            align="edge",
            color="#ff7f0e",
            edgecolor="black",
        )
    ax_bottom.set_xlabel("time (s)")
    ax_bottom.set_ylabel("vertex count")
    ax_bottom.set_ylim(0, 10)
    ax_bottom.set_title("Polygon layout")

    fig.tight_layout()

    out_path: Path | None = None
    if output is not None:
        out_path = Path(output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(out_path, dpi=120)
    if show:
        plt.show()
    plt.close(fig)
    return out_path
