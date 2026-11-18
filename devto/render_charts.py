"""Render the DEV.to charts and cover from the published benchmark medians.

The numbers are the medians already reported in ``daffi.md``. They come from
``tests/perf/results/article_benchmark.json`` (3 runs, wall-clock).
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

OUT = Path(__file__).resolve().parent

DAFFI = "#1d4ed8"
ZMQ = "#0f766e"
NNG = "#6d28d9"
GRPC = "#c2410c"
GRPC_AIO = "#ea580c"
RPYC = "#475569"
PYRO = "#be123c"
ZERORPC = "#b45309"
INK = "#0f172a"
MUTED = "#64748b"
GRID = "#e2e8f0"
BG = "#ffffff"

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 12,
        "axes.unicode_minus": False,
        "figure.facecolor": BG,
        "savefig.facecolor": BG,
        "text.color": INK,
        "axes.labelcolor": "#334155",
        "xtick.color": "#334155",
        "ytick.color": "#334155",
    }
)


def _style(ax) -> None:
    ax.set_axisbelow(True)
    ax.grid(axis="x", color=GRID, linewidth=0.8, zorder=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.spines["bottom"].set_color("#cbd5e1")
    ax.tick_params(length=0)


def _hbar(ax, labels: list[str], values: list[float], colors: list[str], unit: str) -> None:
    y = range(len(labels))
    ax.barh(y, values, color=colors, height=0.66, zorder=3)
    ax.set_yticks(list(y), labels)
    ax.invert_yaxis()
    ax.set_xlabel(unit)
    ceiling = max(values) * 1.22
    ax.set_xlim(0, ceiling)
    for i, value in enumerate(values):
        ax.text(
            value + ceiling * 0.015,
            i,
            f"{value:,.0f}",
            va="center",
            ha="left",
            fontsize=11,
            color=INK,
        )
    _style(ax)


def _header(fig, title: str, subtitle: str, x: float = 0.125) -> None:
    fig.text(x, 0.975, title, fontsize=16, color=INK, ha="left", va="top")
    fig.text(x, 0.915, subtitle, fontsize=11, color=MUTED, ha="left", va="top")


def _finish(fig, path: Path) -> None:
    fig.savefig(path, dpi=160, bbox_inches="tight", pad_inches=0.28)
    plt.close(fig)


def raw_rpc() -> None:
    labels = [
        "ZeroMQ REQ/REP",
        "Daffi OPAQUE",
        "nng req/rep",
        "gRPC protobuf",
        "gRPC raw",
    ]
    values = [42560, 41397, 18114, 7095, 6838]
    colors = [ZMQ, DAFFI, NNG, GRPC, GRPC]
    fig, ax = plt.subplots(figsize=(10.2, 5.1))
    _hbar(ax, labels, values, colors, "Calls per second")
    _header(
        fig,
        "Raw bytes, one call in flight",
        "Same 2,019-byte buffer, echoed without parsing. 10,000 calls. Median of 3 runs.",
    )
    fig.subplots_adjust(top=0.80)
    _finish(fig, OUT / "raw-rpc.png")


def object_rpc() -> None:
    labels = [
        "Daffi PICKLE",
        "RPyC",
        "Daffi MSGPACK",
        "Daffi MSGPACK via Router",
        "Daffi JSON",
        "ZeroRPC",
        "Pyro5",
    ]
    values = [26008, 25519, 23083, 20912, 18496, 3607, 2390]
    colors = [DAFFI, RPYC, DAFFI, DAFFI, DAFFI, ZERORPC, PYRO]
    fig, ax = plt.subplots(figsize=(10.2, 6.0))
    _hbar(ax, labels, values, colors, "Calls per second")
    _header(
        fig,
        "Object RPC, one call in flight",
        "Same order dict (2,019 bytes of JSON). Each library uses its normal codec. Median of 3 runs.",
    )
    fig.subplots_adjust(top=0.82)
    _finish(fig, OUT / "object-rpc.png")


def _panel(ax, title: str, values: list[float], labels: list[str], colors: list[str], fmt: str) -> None:
    x = range(len(labels))
    ax.bar(x, values, color=colors, width=0.72, zorder=3)
    ax.set_xticks(list(x), labels, fontsize=10)
    ax.set_title(title, loc="left", fontsize=13, color=INK, pad=8)
    ax.set_ylim(0, max(values) * 1.28)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#cbd5e1")
    ax.spines["bottom"].set_color("#cbd5e1")
    ax.tick_params(length=0)
    ax.set_ylabel("MiB/s")
    for i, value in enumerate(values):
        ax.text(i, value + max(values) * 0.03, fmt.format(value), ha="center", va="bottom", fontsize=10, color=INK)


def payload() -> None:
    labels = ["OPAQUE", "MSGPACK", "ZeroMQ", "gRPC"]
    colors = [DAFFI, "#60a5fa", ZMQ, GRPC]
    fig = plt.figure(figsize=(11.2, 8.4))
    fig.suptitle(
        "Goodput by payload size",
        x=0.06,
        ha="left",
        fontsize=16,
        color=INK,
    )
    fig.text(
        0.06,
        0.935,
        "Request plus response. Each panel has its own scale. Median of 3 runs.",
        fontsize=11,
        color=MUTED,
    )
    grid = fig.add_gridspec(2, 3, height_ratios=[1, 1.15], hspace=0.38, wspace=0.32, top=0.86, bottom=0.08, left=0.07, right=0.98)
    small = [
        ("64 B", [6.4, 5.0, 4.2, 0.9], "{:.1f}"),
        ("1 KiB", [76, 103, 59, 14], "{:.0f}"),
        ("64 KiB", [2429, 1511, 1343, 495], "{:,.0f}"),
    ]
    for index, (title, values, fmt) in enumerate(small):
        ax = fig.add_subplot(grid[0, index])
        _panel(ax, title, values, labels, colors, fmt)
        if index:
            ax.set_ylabel("")
    ax = fig.add_subplot(grid[1, :])
    wide_labels = ["Daffi OPAQUE", "Daffi MSGPACK", "ZeroMQ REQ/REP", "gRPC protobuf"]
    values = [5181, 4187, 2827, 776]
    ax.barh(range(len(wide_labels)), values, color=colors, height=0.62, zorder=3)
    ax.set_yticks(range(len(wide_labels)), wide_labels)
    ax.invert_yaxis()
    ax.set_xlim(0, max(values) * 1.18)
    ax.set_xlabel("MiB/s  ·  1 MiB payload, both directions")
    ax.set_title("1 MiB", loc="left", fontsize=13, color=INK, pad=8)
    _style(ax)
    for i, value in enumerate(values):
        ax.text(value + 80, i, f"{value:,.0f}", va="center", fontsize=12, color=INK)
    _finish(fig, OUT / "payload-throughput.png")


def clients() -> None:
    x = [1, 8, 32]
    series = [
        ("ZeroMQ DEALER/ROUTER", [34546, 97179, 145046], ZMQ, "s"),
        ("Daffi OPAQUE", [28548, 66552, 56763], DAFFI, "o"),
        ("RPyC", [37665, 19462, 15367], RPYC, "D"),
        ("gRPC aio", [4697, 14695, 19196], GRPC_AIO, "^"),
        ("gRPC sync", [6553, 9634, 9521], GRPC, "v"),
    ]
    offsets = {
        "ZeroMQ DEALER/ROUTER": (10, 0),
        "Daffi OPAQUE": (10, -2),
        "gRPC aio": (10, 11),
        "RPyC": (10, -1),
        "gRPC sync": (10, -12),
    }
    fig, ax = plt.subplots(figsize=(10.2, 5.8))
    for name, values, color, marker in series:
        ax.plot(x, values, color=color, marker=marker, markersize=8, linewidth=2.2, label=name, zorder=3)
        ax.annotate(
            f"{values[-1] / 1000:.0f}k",
            (32, values[-1]),
            textcoords="offset points",
            xytext=offsets[name],
            va="center",
            fontsize=10,
            color=color,
        )
    ax.set_xticks(x, ["1 client", "8 clients", "32 clients"])
    ax.set_xlim(0.2, 40)
    ax.set_ylim(0, 170000)
    ax.set_ylabel("Calls per second")
    ax.yaxis.set_major_formatter(lambda v, _p: f"{v/1000:.0f}k" if v else "0")
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#cbd5e1")
    ax.spines["bottom"].set_color("#cbd5e1")
    ax.tick_params(length=0)
    ax.legend(frameon=False, ncol=3, loc="upper center", bbox_to_anchor=(0.48, -0.14))
    _header(
        fig,
        "Simultaneous clients, one call in flight each",
        "2,019-byte buffer. 1,000 calls per client. This chart has its own baseline. Median of 3 runs.",
    )
    fig.subplots_adjust(top=0.78, bottom=0.20)
    _finish(fig, OUT / "concurrent-clients.png")


def _box(ax, x, y, w, h, fill, edge, kicker, title, body) -> None:
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0.012,rounding_size=0.02",
        linewidth=2,
        facecolor=fill,
        edgecolor=edge,
        mutation_aspect=0.55,
    )
    ax.add_patch(patch)
    ax.text(x + w / 2, y + h * 0.74, kicker, ha="center", va="center", fontsize=10, color=edge)
    ax.text(x + w / 2, y + h * 0.48, title, ha="center", va="center", fontsize=18, color=INK)
    ax.text(x + w / 2, y + h * 0.24, body, ha="center", va="center", fontsize=10, color=MUTED)


def cover() -> None:
    fig = plt.figure(figsize=(20, 8.4), dpi=100)
    fig.patch.set_facecolor("#f4f7fb")
    ax = fig.add_axes((0, 0, 1, 1))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    ax.add_patch(plt.Rectangle((0, 0), 0.012, 1, color=DAFFI, transform=ax.transAxes, zorder=2))
    ax.text(0.055, 0.70, "Python   ·   Open source", fontsize=15, color=DAFFI)
    ax.text(0.055, 0.50, "Daffi", fontsize=64, color=INK)
    ax.text(
        0.055,
        0.32,
        "High-performance brokerless\nRPC for Python",
        fontsize=20,
        color="#334155",
        linespacing=1.35,
    )
    diagram = fig.add_axes((0.46, 0.16, 0.50, 0.68))
    diagram.set_xlim(0, 1)
    diagram.set_ylim(0, 1)
    diagram.axis("off")
    _box(diagram, 0.02, 0.28, 0.26, 0.44, "#eff6ff", "#2563eb", "CALLER", "Client", "Sends the call")
    _box(diagram, 0.37, 0.28, 0.26, 0.44, "#fff7ed", "#ea580c", "FORWARDER", "Router", "Forwards the call")
    _box(diagram, 0.72, 0.28, 0.26, 0.44, "#f0fdf4", "#15803d", "WORKERS", "Workers", "Run @callback")
    for start in (0.29, 0.64):
        diagram.annotate(
            "",
            xy=(start + 0.07, 0.50),
            xytext=(start, 0.50),
            arrowprops={"arrowstyle": "-|>", "color": "#334155", "lw": 1.6, "mutation_scale": 14},
        )
    fig.savefig(OUT / "cover.png", dpi=100)
    plt.close(fig)


def main() -> None:
    raw_rpc()
    object_rpc()
    payload()
    clients()
    cover()


if __name__ == "__main__":
    main()
