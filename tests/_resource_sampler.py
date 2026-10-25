"""
Background RSS / CPU sampler for local daffi processes.

Mirrors the idea of vast-csi ``tests/lib/k8s/resource_sampler.py`` (periodic
samples, live window reports, baseline Δ, growth summary) but reads
``/proc`` (or ``ps`` on macOS) instead of cAdvisor — daffi soak tests run
processes on the host, not in Kubernetes.
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from dataclasses import dataclass, field
from typing import Callable, Optional

from tests._resource_metrics import _CLK_TCK, _cpu_jiffies, rss_kb, thread_count


@dataclass(frozen=True)
class ProcSample:
    ts: float          # monotonic seconds
    name: str
    pid: int
    rss_kb: int
    threads: int
    cpu_pct: Optional[float]  # % of one core since previous sample for this pid


@dataclass
class ProcessResourceSampler:
    """Sample named PIDs on a background thread until ``stop()``."""

    targets: dict[str, int]  # name → pid
    interval_sec: float = 30.0
    line_writer: Callable[[str], None] | None = None

    _samples: list[ProcSample] = field(default_factory=list, init=False, repr=False)
    _stop: threading.Event = field(default_factory=threading.Event, init=False, repr=False)
    _thread: threading.Thread | None = field(default=None, init=False, repr=False)
    _live_thread: threading.Thread | None = field(default=None, init=False, repr=False)
    _live_interval_sec: float | None = field(default=None, init=False, repr=False)
    _lock: threading.RLock = field(default_factory=threading.RLock, init=False, repr=False)
    _prev_cpu: dict[int, tuple[float, int]] = field(default_factory=dict, init=False, repr=False)
    _baseline_rss: dict[str, int] = field(default_factory=dict, init=False, repr=False)
    _t0: float = field(default=0.0, init=False, repr=False)

    def start(self) -> None:
        self._stop.clear()
        with self._lock:
            self._samples.clear()
            self._prev_cpu.clear()
            self._baseline_rss.clear()
        self._t0 = time.monotonic()
        self._thread = threading.Thread(
            target=self._run, daemon=True, name="daffi-resource-sampler"
        )
        self._thread.start()
        # Prime baselines immediately so Δ is meaningful from the first live row.
        self._sample_once()

    def start_live_reporting(self, interval_sec: float = 60.0) -> None:
        """Print a compact RSS/CPU row every *interval_sec* while the soak runs."""
        self._live_interval_sec = interval_sec
        writer = self.line_writer or print
        writer(
            f"ProcessResourceSampler: live RSS/CPU every {interval_sec:.0f}s "
            f"(sample interval {self.interval_sec:.0f}s)  targets={list(self.targets)}"
        )
        if self._thread is not None and self._live_thread is None:
            self._live_thread = threading.Thread(
                target=self._live_report_loop,
                daemon=True,
                name="daffi-resource-sampler-live",
            )
            self._live_thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._live_thread:
            self._live_thread.join(timeout=(self._live_interval_sec or 5) + 2)
            self._live_thread = None
        if self._thread:
            self._thread.join(timeout=self.interval_sec + 5)
            self._thread = None

    def samples_for(self, name: str) -> list[ProcSample]:
        with self._lock:
            return [s for s in self._samples if s.name == name]

    def all_samples(self) -> list[ProcSample]:
        with self._lock:
            return list(self._samples)

    def report(self, title: str = "mem leak check") -> dict[str, dict]:
        """Print per-target start/end/peak RSS and MB/min trend; return summary dict."""
        writer = self.line_writer or print
        summary: dict[str, dict] = {}
        writer(f"\n── {title}")
        for name in self.targets:
            pts = self.samples_for(name)
            if len(pts) < 2:
                writer(f"  {name:<10}: not enough samples ({len(pts)})")
                summary[name] = {"ok": False, "n": len(pts)}
                continue
            first = pts[0]
            last = pts[-1]
            peak_kb = max(p.rss_kb for p in pts)
            # Skip first ~2 samples for trend (warmup).
            skip = 2 if len(pts) > 4 else 0
            trend = pts[skip:]
            rate = _mb_per_min(trend)
            warn = "  ⚠ possible leak" if rate > 1.0 else ""
            writer(
                f"  {name:<10}: start={first.rss_kb/1024:7.1f} MB  "
                f"end={last.rss_kb/1024:7.1f} MB  "
                f"peak={peak_kb/1024:7.1f} MB  "
                f"trend={rate:+.3f} MB/min  "
                f"threads={last.threads}{warn}"
            )
            summary[name] = {
                "ok": rate <= 1.0,
                "n": len(pts),
                "start_mb": first.rss_kb / 1024,
                "end_mb": last.rss_kb / 1024,
                "peak_mb": peak_kb / 1024,
                "trend_mb_per_min": rate,
                "threads_end": last.threads,
            }
        return summary

    # ── internals ─────────────────────────────────────────────────────────────

    def _run(self) -> None:
        while not self._stop.is_set():
            try:
                self._sample_once()
            except Exception as exc:
                writer = self.line_writer or print
                writer(f"ProcessResourceSampler: sample failed: {type(exc).__name__}: {exc}")
            self._stop.wait(self.interval_sec)

    def _sample_once(self) -> None:
        now = time.monotonic()
        with self._lock:
            targets = dict(self.targets)
        for name, pid in targets.items():
            rss = rss_kb(pid)
            if rss is None:
                continue
            thr = thread_count(pid)
            cpu_pct = self._cpu_pct(pid, now)
            sample = ProcSample(
                ts=now, name=name, pid=pid,
                rss_kb=rss, threads=thr, cpu_pct=cpu_pct,
            )
            with self._lock:
                if name not in self._baseline_rss:
                    self._baseline_rss[name] = rss
                self._samples.append(sample)

    def _cpu_pct(self, pid: int, now: float) -> Optional[float]:
        j = _cpu_jiffies(pid)
        if j is None:
            return None
        prev = self._prev_cpu.get(pid)
        self._prev_cpu[pid] = (now, j)
        if prev is None:
            return 0.0
        elapsed = now - prev[0]
        if elapsed <= 0:
            return 0.0
        return 100.0 * (j - prev[1]) / (_CLK_TCK * elapsed)

    def _live_report_loop(self) -> None:
        writer = self.line_writer or print
        assert self._live_interval_sec is not None
        while not self._stop.wait(self._live_interval_sec):
            cutoff = time.monotonic() - self._live_interval_sec
            with self._lock:
                recent = [s for s in self._samples if s.ts >= cutoff]
                baselines = dict(self._baseline_rss)
                # Latest sample per name in the window (or overall if empty window).
                latest: dict[str, ProcSample] = {}
                for s in self._samples:
                    latest[s.name] = s
            if not latest:
                writer(
                    f"  [{_fmt_elapsed(time.monotonic() - self._t0)}] "
                    f"no samples yet"
                )
                continue
            elapsed = time.monotonic() - self._t0
            parts = [f"[{_fmt_elapsed(elapsed)}]"]
            for name in self.targets:
                s = latest.get(name)
                if s is None:
                    parts.append(f"{name}=dead")
                    continue
                base = baselines.get(name, s.rss_kb)
                delta_mb = (s.rss_kb - base) / 1024
                cpu = "n/a" if s.cpu_pct is None else f"{s.cpu_pct:.0f}%"
                parts.append(
                    f"{name}={s.rss_kb/1024:.1f}M(Δ{delta_mb:+.1f}) "
                    f"cpu={cpu} thr={s.threads}"
                )
            # Mention how many samples fell in the live window (sampler may be slower).
            parts.append(f"n_recent={len(recent)}")
            writer("  " + "  ".join(parts))


def _mb_per_min(pts: list[ProcSample]) -> float:
    if len(pts) < 2:
        return 0.0
    xs = [(p.ts - pts[0].ts) / 60.0 for p in pts]  # minutes from first
    ys = [p.rss_kb / 1024.0 for p in pts]
    n = len(xs)
    xm = sum(xs) / n
    ym = sum(ys) / n
    num = sum((x - xm) * (y - ym) for x, y in zip(xs, ys))
    den = sum((x - xm) ** 2 for x in xs)
    return num / den if den > 0 else 0.0


def _fmt_elapsed(seconds: float) -> str:
    s = int(seconds)
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    if h:
        return f"{h:d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"
