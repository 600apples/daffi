"""
Custom build configuration for the dfcore Zig extension.

OpenSSL discovery order
-----------------------
1. ``OPENSSL_DIR`` environment variable
2. macOS: ``brew --prefix openssl@3``  (falls back to @1.1 then bare openssl)
3. System default paths

Cross-compilation
-----------------
cibuildwheel sets ``ARCHFLAGS`` (e.g. ``-arch x86_64``) when building a wheel
for an architecture other than the runner's native one (e.g. x86_64 wheel on
an Apple Silicon macos-14 runner).  ``ZigBuilder`` reads that variable and
passes the appropriate ``-target`` triple to ``zig build-lib`` so the emitted
shared library has the correct architecture.
"""
import os
import sys
import subprocess
from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext


def _find_openssl():
    """Return ``(include_dir, lib_dir)`` for OpenSSL, or ``(None, None)``."""
    openssl_dir = os.environ.get("OPENSSL_DIR")
    if openssl_dir:
        return (
            os.path.join(openssl_dir, "include"),
            os.path.join(openssl_dir, "lib"),
        )

    if sys.platform == "darwin":
        for pkg in ("openssl@3", "openssl@1.1", "openssl"):
            try:
                prefix = subprocess.check_output(
                    ["brew", "--prefix", pkg], stderr=subprocess.DEVNULL
                ).decode().strip()
                if prefix and os.path.isdir(prefix):
                    return (
                        os.path.join(prefix, "include"),
                        os.path.join(prefix, "lib"),
                    )
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue

    return None, None


def _zig_target():
    """Return a Zig target triple only when genuinely cross-compiling.

    Returns ``None`` for native builds so Zig can auto-detect the target and
    use its normal system-library search paths (no ``-L`` required).

    When ``ARCHFLAGS`` is explicitly set (cibuildwheel cross-compilation or
    a manual ``ARCHFLAGS=-arch x86_64 pip install``), returns the appropriate
    triple, e.g. ``x86_64-macos`` or ``aarch64-linux``.
    """
    archflags = os.environ.get("ARCHFLAGS", "").strip()
    if not archflags:
        return None  # Native build — let Zig pick the target automatically.

    if "-arch x86_64" in archflags:
        cpu = "x86_64"
    elif "-arch arm64" in archflags:
        cpu = "aarch64"
    else:
        return None  # Unrecognised ARCHFLAGS — fall back to native.

    if sys.platform == "darwin":
        return f"{cpu}-macos"
    if sys.platform.startswith("linux"):
        return f"{cpu}-linux"
    return None


class ZigBuilder(build_ext):
    def build_extension(self, ext):
        assert len(ext.sources) == 1, "ZigBuilder expects exactly one source file"

        out_dir = os.path.dirname(self.get_ext_fullpath(ext.name))
        os.makedirs(out_dir, exist_ok=True)

        mode = "Debug" if self.debug else "ReleaseFast"
        openssl_include, openssl_lib = _find_openssl()
        target = _zig_target()

        cmd = [
            "zig",
            "build-lib",
            "-O", mode,
            "-lc",
            "-lssl",
            "-lcrypto",
            f"-femit-bin={self.get_ext_fullpath(ext.name)}",
            "-fallow-shlib-undefined",
            "-dynamic",
            *[f"-I{d}" for d in self.include_dirs],
        ]

        if target:
            cmd += ["-target", target]
        if openssl_include:
            cmd.append(f"-I{openssl_include}")
        if openssl_lib:
            cmd.append(f"-L{openssl_lib}")

        cmd.append(ext.sources[0])
        self.spawn(cmd)


dfcore = Extension("daffi.dfcore", sources=["core/core.zig"])

setup(
    ext_modules=[dfcore],
    cmdclass={"build_ext": ZigBuilder},
)
