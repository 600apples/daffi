#!/usr/bin/env python3
"""Cross-compile a daffi Windows AMD64 wheel from Linux using Zig.

How it works
------------
Zig's built-in cross-compilation targets Windows natively from any host.
This script:

  1. Copies the running Python's C headers and swaps in the Windows
     ``pyconfig.h`` from CPython's GitHub (one file, ~20 KB).
  2. Downloads OpenSSL Windows dev files (headers + import libs + DLLs)
     from https://github.com/python/cpython-bin-deps — the exact build
     CPython itself ships with, ~15 MB download.
  3. Calls ``zig build-lib -target x86_64-windows-gnu`` to produce
     ``dfcore.cpNM-win_amd64.pyd``.
  4. Assembles a proper ``.whl`` archive: Python sources + .pyd + the two
     OpenSSL DLLs placed next to the extension so Windows finds them.

Usage
-----
    # build wheel for the running Python version (e.g. 3.12):
    python3 scripts/cross_win_wheel.py

    # build wheel for a specific Python version:
    python3 scripts/cross_win_wheel.py --py-version 3.13

    # use ReleaseFast instead of ReleaseSafe:
    ZIG_OPT=ReleaseFast python3 scripts/cross_win_wheel.py

Output
------
    wheelhouse/daffi-X.Y.Z-cpNM-cpNM-win_amd64.whl

Transfer that file to a Windows machine and install with:
    pip install daffi-X.Y.Z-cpNM-cpNM-win_amd64.whl
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import os
import shutil
import ssl
import subprocess
import sys
import sysconfig
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


# ── helpers ───────────────────────────────────────────────────────────────────

def _download(url: str, dest: Path) -> None:
    print(f"    {url}")
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(url, context=ctx) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)


def _sha256_record(data: bytes) -> str:
    digest = hashlib.sha256(data).digest()
    return "sha256=" + base64.urlsafe_b64encode(digest).decode().rstrip("=")


def _openssl_branch() -> str:
    """Return the best available cpython-bin-deps branch for the Windows OpenSSL libs.

    Queries the GitHub API for all ``openssl-bin-*`` branches and picks the
    highest-versioned one that is <= the host OpenSSL version, falling back to
    the plain highest available branch if nothing matches.
    """
    import json

    import re as _re
    _BRANCH_RE = _re.compile(r"^openssl-bin-(\d+)\.(\d+)$")

    api_url = (
        "https://api.github.com/repos/python/cpython-bin-deps/branches"
        "?per_page=100"
    )
    ctx = ssl.create_default_context()
    try:
        req = urllib.request.Request(api_url,
                                     headers={"Accept": "application/vnd.github+json"})
        with urllib.request.urlopen(req, context=ctx) as r:
            branches = json.loads(r.read())
        available = sorted(
            (b["name"] for b in branches if _BRANCH_RE.match(b["name"])),
            key=lambda n: [int(x) for x in _BRANCH_RE.match(n).groups()],
        )
    except Exception:
        return "openssl-bin-3.0"

    if not available:
        return "openssl-bin-3.0"

    # Try to find the highest branch <= the host OpenSSL version.
    try:
        import ssl as _ssl
        host_mm = tuple(int(x) for x in _ssl.OPENSSL_VERSION.split()[1].split(".")[:2])
        candidates = [
            b for b in available
            if tuple(int(x) for x in b.split("-")[-1].split(".")) <= host_mm
        ]
        return candidates[-1] if candidates else available[-1]
    except Exception:
        return available[-1]


def _find_zig() -> str:
    zig = shutil.which("zig")
    if zig:
        return zig
    # Ask setup.py to download it (same logic as wheel builds).
    subprocess.check_call(
        [sys.executable, str(ROOT / "setup.py"), "ensure_zig",
         "--symlink", "/usr/local/bin/zig"],
        cwd=ROOT,
    )
    zig = shutil.which("zig")
    if not zig:
        raise RuntimeError(
            "zig not found after ensure_zig. "
            "Install manually from https://ziglang.org/download/"
        )
    return zig


# ── main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument(
        "--py-version",
        default=f"{sys.version_info.major}.{sys.version_info.minor}",
        metavar="X.Y",
        help="Target CPython version (default: running interpreter)",
    )
    args = ap.parse_args()

    py_maj, py_min = (int(x) for x in args.py_version.split("."))
    py_tag    = f"cp{py_maj}{py_min}"
    pyd_name  = f"dfcore.{py_tag}-win_amd64.pyd"

    # Read version from __about__.py
    about: dict = {}
    exec((ROOT / "daffi" / "__about__.py").read_text(), about)
    version = about["__version__"]

    wheel_name = f"daffi-{version}-{py_tag}-{py_tag}-win_amd64.whl"
    out_dir    = ROOT / "wheelhouse"
    out_dir.mkdir(exist_ok=True)
    wheel_path = out_dir / wheel_name

    print(f"\nBuilding  {wheel_name}")
    print(f"Zig target: x86_64-windows-gnu")
    print(f"Optimization: {os.environ.get('ZIG_OPT', 'ReleaseSafe')}\n")

    with tempfile.TemporaryDirectory(prefix="daffi_cross_win_") as _tmp:
        tmp = Path(_tmp)

        # ── 1. Python C headers ───────────────────────────────────────────────
        print("[1/4] Python headers")
        linux_inc  = Path(sysconfig.get_path("include"))
        py_inc_dir = tmp / "py_include"
        shutil.copytree(linux_inc, py_inc_dir)

        # The only platform-specific header is pyconfig.h.  Swap it for the
        # Windows version so compiled code gets the right #defines (MS_WINDOWS,
        # MS_WIN64, Py_HAVE_PTHREAD_H absence, etc.).
        cpython_ver = (f"{sys.version_info.major}."
                       f"{sys.version_info.minor}."
                       f"{sys.version_info.micro}")
        pyconfig_url = (
            f"https://raw.githubusercontent.com/python/cpython"
            f"/v{cpython_ver}/PC/pyconfig.h"
        )
        print(f"  Downloading Windows pyconfig.h for CPython {cpython_ver} …")
        _download(pyconfig_url, py_inc_dir / "pyconfig.h")

        # ── 2. OpenSSL Windows dev files ──────────────────────────────────────
        print("\n[2/4] OpenSSL Windows dev files (cpython-bin-deps)")
        branch      = _openssl_branch()
        archive_url = (
            f"https://github.com/python/cpython-bin-deps"
            f"/archive/refs/heads/{branch}.tar.gz"
        )
        archive_path = tmp / "openssl_deps.tar.gz"
        print(f"  Branch: {branch}")
        _download(archive_url, archive_path)

        raw_dir = tmp / "openssl_raw"
        raw_dir.mkdir()
        with tarfile.open(archive_path, "r:gz") as tf:
            tf.extractall(raw_dir)

        # Archive extracts to a single top-level directory.
        top = next(raw_dir.iterdir())
        amd64 = top / "amd64"
        if not amd64.is_dir():
            raise RuntimeError(
                f"Expected amd64/ in cpython-bin-deps, found: {list(top.iterdir())}"
            )

        openssl_inc  = amd64 / "include"
        openssl_lib  = amd64           # contains libssl.lib / libcrypto.lib
        openssl_dlls = sorted(amd64.glob("*.dll"))

        # Zig (LLD in MinGW mode) searches for "ssl.lib" / "crypto.lib" when
        # given -lssl / -lcrypto, but cpython-bin-deps ships "libssl.lib" /
        # "libcrypto.lib".  Create name-compatible symlinks in the same dir.
        for lib_name in ("ssl", "crypto"):
            src = amd64 / f"lib{lib_name}.lib"
            dst = amd64 / f"{lib_name}.lib"
            if src.exists() and not dst.exists():
                dst.symlink_to(src)

        print(f"  Headers : {openssl_inc}")
        print(f"  Libs    : {openssl_lib}")
        print(f"  DLLs    : {[d.name for d in openssl_dlls]}")

        # ── 3. Cross-compile ──────────────────────────────────────────────────
        print("\n[3/4] Compiling dfcore for Windows AMD64")
        zig      = _find_zig()
        pyd_out  = tmp / pyd_name
        opt_mode = os.environ.get("ZIG_OPT", "ReleaseSafe")

        cmd = [
            zig, "build-lib",
            "-O", opt_mode,
            "-target", "x86_64-windows-gnu",
            "-lc",
            f"-femit-bin={pyd_out}",
            "-fallow-shlib-undefined",
            "-dynamic",
            f"-I{py_inc_dir}",
            f"-I{openssl_inc}",
            f"-L{openssl_lib}",
            "-lssl",
            "-lcrypto",
            str(ROOT / "core" / "core.zig"),
        ]

        print("  $ " + " ".join(str(c) for c in cmd))
        subprocess.check_call(cmd, cwd=tmp)

        if not pyd_out.exists():
            raise RuntimeError(f"Expected output {pyd_out} — Zig build failed")
        print(f"  OK  {pyd_out.name}  ({pyd_out.stat().st_size // 1024} KB)")

        # ── 4. Assemble wheel ─────────────────────────────────────────────────
        print(f"\n[4/4] Assembling wheel")
        dist_info   = f"daffi-{version}.dist-info"
        wheel_files: list[tuple[str, bytes]] = []

        def add(arc_path: str, data: bytes) -> None:
            wheel_files.append((arc_path, data))

        # Python sources from daffi/
        for src in sorted((ROOT / "daffi").rglob("*")):
            if not src.is_file():
                continue
            if src.suffix in (".so", ".pyd") or "__pycache__" in src.parts:
                continue
            arc = str(src.relative_to(ROOT)).replace(os.sep, "/")
            add(arc, src.read_bytes())

        # The compiled extension
        add(f"daffi/{pyd_name}", pyd_out.read_bytes())

        # OpenSSL DLLs placed next to the .pyd so Windows finds them on load.
        for dll in openssl_dlls:
            add(f"daffi/{dll.name}", dll.read_bytes())

        # .dist-info/WHEEL
        add(f"{dist_info}/WHEEL", (
            f"Wheel-Version: 1.0\n"
            f"Generator: daffi-cross-win\n"
            f"Root-Is-Purelib: false\n"
            f"Tag: {py_tag}-{py_tag}-win_amd64\n"
        ).encode())

        # .dist-info/METADATA (minimal — enough for pip install)
        add(f"{dist_info}/METADATA", (
            f"Metadata-Version: 2.3\n"
            f"Name: daffi\n"
            f"Version: {version}\n"
            f"Summary: Lightweight inter-process RPC framework\n"
            f"Requires-Python: >={py_maj}.{py_min}\n"
        ).encode())

        # .dist-info/RECORD
        record_lines = [
            f"{p},{_sha256_record(d)},{len(d)}" for p, d in wheel_files
        ]
        record_lines.append(f"{dist_info}/RECORD,,")
        record_data = "\n".join(record_lines).encode()

        with zipfile.ZipFile(wheel_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for arc_path, data in wheel_files:
                zf.writestr(arc_path, data)
            zf.writestr(f"{dist_info}/RECORD", record_data)

        size_kb = wheel_path.stat().st_size // 1024
        print(f"\n  {wheel_path.relative_to(ROOT)}  ({size_kb} KB)")
        print(f"\n  Transfer to Windows and run:")
        print(f"    pip install {wheel_name}\n")


if __name__ == "__main__":
    main()
