"""
Custom build configuration for the dfcore Zig extension.

OpenSSL discovery order
-----------------------
1. ``OPENSSL_DIR`` environment variable
2. macOS: ``brew --prefix openssl@3``  (falls back to @1.1 then bare openssl)
3. System default paths

OpenSSL linking strategy
------------------------
On macOS the extension is linked against OpenSSL *statically* (using the
``.a`` archives from Homebrew).  Dynamic dylib references cause ``delocate``
to try to bundle ``libssl.dylib``/``libcrypto.dylib`` into the wheel; on
GitHub Actions the Homebrew dylibs may be universal2 fat binaries which
``delocate`` can't process cleanly.  Static linking embeds the OpenSSL code
directly and produces a wheel with no external dylib dependency.

On Linux dynamic linking is used instead — ``auditwheel repair`` handles
bundling ``libssl.so``/``libcrypto.so`` into the wheel correctly.

Cross-compilation
-----------------
cibuildwheel sets ``ARCHFLAGS`` (e.g. ``-arch x86_64``) when building a wheel
for an architecture other than the runner's native one.  ``ZigBuilder`` reads
that variable and passes the appropriate ``-target`` triple to ``zig
build-lib`` so the emitted shared library has the correct architecture.
"""
import os
import sys
import subprocess
from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext


def _find_openssl():
    """Return ``(include_dir, lib_dir)`` for OpenSSL, or ``(None, None)``.

    On macOS the arch-native Homebrew prefix is resolved directly via
    ``platform.machine()`` rather than via ``brew --prefix``.  cibuildwheel
    prepends ``/usr/local/bin`` to PATH during the Python build step, which
    causes ``brew`` to resolve to the *x86_64* Homebrew even on arm64 runners,
    returning the wrong-arch ``.a`` archives and producing a binary that fails
    ``delocate-wheel --require-archs arm64``.  Bypassing ``brew`` avoids this.
    """
    openssl_dir = os.environ.get("OPENSSL_DIR")
    if openssl_dir:
        return (
            os.path.join(openssl_dir, "include"),
            os.path.join(openssl_dir, "lib"),
        )

    if sys.platform == "darwin":
        import platform as _platform

        # /opt/homebrew  → arm64 Homebrew (Apple Silicon)
        # /usr/local     → x86_64 Homebrew (Intel / Rosetta)
        machine = _platform.machine()
        brew_prefix = "/opt/homebrew" if machine == "arm64" else "/usr/local"
        print(f"setup.py: macOS machine={machine!r}, using Homebrew prefix {brew_prefix!r}")

        for pkg in ("openssl@3", "openssl@1.1", "openssl"):
            candidate = os.path.join(brew_prefix, "opt", pkg)
            if os.path.isdir(candidate):
                print(f"setup.py: found OpenSSL at {candidate!r}")
                return (
                    os.path.join(candidate, "include"),
                    os.path.join(candidate, "lib"),
                )

        # Fallback: try the brew command (e.g. non-standard installations).
        for pkg in ("openssl@3", "openssl@1.1", "openssl"):
            try:
                prefix = subprocess.check_output(
                    ["brew", "--prefix", pkg], stderr=subprocess.DEVNULL
                ).decode().strip()
                if prefix and os.path.isdir(prefix):
                    print(f"setup.py: OpenSSL via brew at {prefix!r}")
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
            f"-femit-bin={self.get_ext_fullpath(ext.name)}",
            "-fallow-shlib-undefined",
            "-dynamic",
            *[f"-I{d}" for d in self.include_dirs],
        ]

        if target:
            cmd += ["-target", target]
        if openssl_include:
            cmd.append(f"-I{openssl_include}")

        # On macOS: link OpenSSL statically using the Homebrew .a archives so
        # the wheel contains no LC_LOAD_DYLIB references to libssl/libcrypto.
        # delocate then has nothing to bundle and the repair step is a no-op.
        #
        # On Linux: link dynamically; auditwheel bundles the .so files fine.
        if sys.platform == "darwin" and openssl_lib:
            ssl_a = os.path.join(openssl_lib, "libssl.a")
            crypto_a = os.path.join(openssl_lib, "libcrypto.a")
            if os.path.exists(ssl_a) and os.path.exists(crypto_a):
                cmd.extend([ssl_a, crypto_a])
            else:
                # Static archives missing — fall back to dynamic linking.
                cmd.extend([f"-L{openssl_lib}", "-lssl", "-lcrypto"])
        else:
            if openssl_lib:
                cmd.append(f"-L{openssl_lib}")
            cmd.extend(["-lssl", "-lcrypto"])

        cmd.append(ext.sources[0])
        self.spawn(cmd)


dfcore = Extension("daffi.dfcore", sources=["core/core.zig"])

setup(
    ext_modules=[dfcore],
    cmdclass={"build_ext": ZigBuilder},
)
