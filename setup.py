"""
Custom build configuration for the dfcore Zig extension.

Zig auto-install
----------------
If ``zig`` is not found in PATH, the build script downloads the official
Zig 0.16.0 binary for the current platform into a temporary directory and
uses it transparently.  No manual installation is required for
``pip install -e .`` on a clean machine.

OpenSSL discovery order
-----------------------
1. ``OPENSSL_DIR`` environment variable
2. macOS: arch-native Homebrew prefix (``/opt/homebrew`` or ``/usr/local``)
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
import shutil
import subprocess
import platform
import tarfile
import tempfile
import urllib.request
from setuptools import setup, Extension, Command
from setuptools.command.build_ext import build_ext


_ZIG_VERSION = "0.16.0"


def _ensure_zig() -> str:
    """Return the path to a ``zig`` executable.

    Checks PATH first.  If not found, downloads the official Zig binary for
    the current platform into ``/tmp/zig-<arch>-<os>-<version>/`` and returns
    the path to the extracted binary.  Subsequent calls reuse the cached
    download.
    """
    zig = shutil.which("zig")
    if zig:
        return zig

    machine = platform.machine().lower()
    arch = "aarch64" if machine in ("aarch64", "arm64") else "x86_64"

    if sys.platform == "darwin":
        os_name = "macos"
    elif sys.platform.startswith("linux"):
        os_name = "linux"
    else:
        raise RuntimeError(
            f"Unsupported platform {sys.platform!r}. "
            "Install Zig manually from https://ziglang.org/download/"
        )

    dir_name = f"zig-{arch}-{os_name}-{_ZIG_VERSION}"
    zig_dir  = os.path.join(tempfile.gettempdir(), dir_name)
    zig_exe  = os.path.join(zig_dir, "zig")

    if os.path.isfile(zig_exe):
        print(f"setup.py: reusing cached Zig at {zig_exe!r}")
        return zig_exe

    tarball  = f"{dir_name}.tar.xz"
    url      = f"https://ziglang.org/download/{_ZIG_VERSION}/{tarball}"
    archive  = os.path.join(tempfile.gettempdir(), tarball)

    print(f"setup.py: zig not found in PATH — downloading {url!r} …")
    try:
        urllib.request.urlretrieve(url, archive)
    except Exception:
        # urllib may lack SSL on some minimal environments; fall back to curl.
        subprocess.check_call(["curl", "-fsSL", url, "-o", archive])

    print(f"setup.py: extracting {archive!r} …")
    with tarfile.open(archive, "r:xz") as tf:
        tf.extractall(tempfile.gettempdir())

    os.remove(archive)

    if not os.path.isfile(zig_exe):
        raise RuntimeError(
            f"Zig binary not found at {zig_exe!r} after extraction. "
            f"Check that {url!r} is correct."
        )

    os.chmod(zig_exe, 0o755)
    print(f"setup.py: Zig {_ZIG_VERSION} ready at {zig_exe!r}")
    return zig_exe


class EnsureZig(Command):
    """Setuptools command: download Zig if absent and (optionally) symlink it.

    Usage from a shell script::

        python setup.py ensure_zig
        python setup.py ensure_zig --symlink /usr/local/bin/zig

    cibuildwheel ``before-all`` example::

        before-all = "python setup.py ensure_zig --symlink /usr/local/bin/zig"

    The command calls :func:`_ensure_zig`, which checks PATH first and only
    downloads when Zig is genuinely absent.  The optional ``--symlink``
    argument creates a symlink so that subsequent shell commands can call
    ``zig`` without an absolute path.
    """

    description = "ensure Zig is available; download it if not in PATH"
    user_options = [
        ("symlink=", None, "create a symlink to the zig binary at this path"),
    ]

    def initialize_options(self):
        self.symlink = None

    def finalize_options(self):
        pass

    def run(self):
        zig_exe = _ensure_zig()
        print(f"ensure_zig: Zig ready at {zig_exe!r}")
        if self.symlink:
            link = self.symlink
            os.makedirs(os.path.dirname(link), exist_ok=True)
            if os.path.lexists(link):
                os.remove(link)
            os.symlink(zig_exe, link)
            print(f"ensure_zig: symlinked {zig_exe!r} → {link!r}")
        subprocess.check_call([zig_exe, "version"])


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
        # /opt/homebrew  → arm64 Homebrew (Apple Silicon)
        # /usr/local     → x86_64 Homebrew (Intel / Rosetta)
        machine = platform.machine()
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

        mode = "Debug" if self.debug else os.environ.get("ZIG_OPT", "ReleaseSafe")
        openssl_include, openssl_lib = _find_openssl()
        target = _zig_target()

        cmd = [
            _ensure_zig(),
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
    cmdclass={
        "build_ext": ZigBuilder,
        "ensure_zig": EnsureZig,
    },
)
