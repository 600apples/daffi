"""
Custom build configuration for the dfcore Zig extension.

Zig auto-install
----------------
If ``zig`` in PATH is missing or is not the pinned version (``_ZIG_VERSION``),
the build script downloads the official Zig binary for the current platform
into a temporary directory and uses it transparently.  No manual installation
is required for ``pip install -e .`` on a clean machine.

C headers
---------
Zig has no ``@cImport``.  The headers in ``core/c/`` are translated with
``zig translate-c`` at build time and handed to the compiler as the modules
``python_c``, ``posix_c`` and ``openssl_c`` (see ``zig_c_module_args``).

OpenSSL discovery order
-----------------------
1. ``OPENSSL_DIR`` environment variable
2. macOS: arch-native Homebrew prefix (``/opt/homebrew`` or ``/usr/local``)
3. Windows: common installation paths (``C:\\Program Files\\OpenSSL-Win64``, etc.)
4. System OpenSSL usable by Zig (headers + unversioned ``libssl`` / ``libcrypto``)
5. Auto-download: Unix builds OpenSSL from source into ``/tmp`` (static libs);
   Windows fetches prebuilt libs from ``python/cpython-bin-deps``.
   Set ``DAFFI_NO_OPENSSL_DOWNLOAD=1`` to disable step 5.

OpenSSL linking strategy
------------------------
On macOS the extension is linked against OpenSSL *statically* (using the
``.a`` archives from Homebrew).  Dynamic dylib references cause ``delocate``
to try to bundle ``libssl.dylib``/``libcrypto.dylib`` into the wheel; on
GitHub Actions the Homebrew dylibs may be universal2 fat binaries which
``delocate`` can't process cleanly.  Static linking embeds the OpenSSL code
directly and produces a wheel with no external dylib dependency.

On Linux, static ``.a`` archives are preferred when present (Homebrew-style
prefixes and the auto-downloaded build).  Otherwise dynamic linking is used
and ``auditwheel`` bundles the shared libraries into the wheel.

On Windows dynamic linking is used — ``delvewheel`` bundles the DLLs into
the wheel; for local installs, DLLs are copied next to the extension.

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


_ZIG_VERSION = "0.17.0"
_OPENSSL_VERSION = os.environ.get("DAFFI_OPENSSL_VERSION", "3.4.1")

# SHA-256 of every archive this script downloads and then executes / links
# against.  Source: https://ziglang.org/download/index.json and the
# ``.tar.gz.sha256`` files published with each OpenSSL GitHub release.
# Bump these together with the versions above.
_ZIG_SHA256 = {
    ("aarch64", "macos"):   "b607e9b9234790a008116ae5bdb71c6243b84b9fb42a53a9e70fde41c06c536a",
    ("x86_64",  "macos"):   "4f9a1c5269aa17ebda5e6d3c2b89d6cbf36f7d2b22a0306e9ab98f25f95529c6",
    ("aarch64", "linux"):   "9e8d11661d4ae3bd57702a3832781e23ad151dde5798e16a5ccd503f65234ff8",
    ("x86_64",  "linux"):   "1cbe9df9f27e6b78d14ccbca43b6703a404ef79ef1c463de901d7f088d4e2026",
    ("x86_64",  "windows"): "b5663f69581dcf391293fbf16c06cb80d81d806545ce618b4d0bab7f0eb8c428",
}
_OPENSSL_SHA256 = {
    "3.4.1": "002a2d6b30b58bf4bea46c43bdd96365aaf8daa6c428782aa4feee06da197df3",
}


def _sha256_of(path: str) -> str:
    import hashlib

    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _verify_sha256(path: str, expected: "str | None", what: str) -> None:
    """Abort (and delete *path*) unless it matches the pinned SHA-256."""
    if not expected:
        raise RuntimeError(
            f"No pinned SHA-256 for {what}; refusing to use an unverified download. "
            "Install it yourself (and put it on PATH / set OPENSSL_DIR), or add "
            "its checksum to setup.py."
        )
    actual = _sha256_of(path)
    if actual.lower() != expected.lower():
        try:
            os.remove(path)
        except OSError:
            pass
        raise RuntimeError(
            f"SHA-256 mismatch for {what}: expected {expected}, got {actual}. "
            "The download was corrupted or tampered with and has been deleted."
        )


def _safe_extractall(tf, dest: str) -> None:
    """``extractall`` that refuses path traversal / special files when the
    running Python supports extraction filters (3.12+, backported to 3.9+)."""
    if isinstance(tf, tarfile.TarFile) and hasattr(tarfile, "data_filter"):
        tf.extractall(dest, filter="data")
    else:
        tf.extractall(dest)


def _ensure_zig() -> str:
    """Return the path to a ``zig`` executable of version ``_ZIG_VERSION``.

    Uses the ``zig`` in PATH when it is that version.  Otherwise downloads the
    official Zig binary for the current platform into
    ``/tmp/zig-<arch>-<os>-<version>/`` and returns the path to the extracted
    binary.  Subsequent calls reuse the cached download.
    """
    zig = shutil.which("zig")
    if zig:
        found = subprocess.run([zig, "version"], capture_output=True, text=True).stdout.strip()
        if found == _ZIG_VERSION:
            return zig
        print(f"setup.py: ignoring {zig!r} (Zig {found or 'unknown'}, need {_ZIG_VERSION})")

    machine = platform.machine().lower()
    arch = "aarch64" if machine in ("aarch64", "arm64") else "x86_64"

    if sys.platform == "darwin":
        os_name = "macos"
    elif sys.platform.startswith("linux"):
        os_name = "linux"
    elif sys.platform == "win32":
        os_name = "windows"
        arch = "x86_64"  # Windows builds are AMD64 only
    else:
        raise RuntimeError(
            f"Unsupported platform {sys.platform!r}. "
            "Install Zig manually from https://ziglang.org/download/"
        )

    dir_name = f"zig-{arch}-{os_name}-{_ZIG_VERSION}"
    zig_dir  = os.path.join(tempfile.gettempdir(), dir_name)
    zig_exe  = os.path.join(zig_dir, "zig.exe" if sys.platform == "win32" else "zig")

    if os.path.isfile(zig_exe):
        print(f"setup.py: reusing cached Zig at {zig_exe!r}")
        return zig_exe

    zig_sha = _ZIG_SHA256.get((arch, os_name))

    if sys.platform == "win32":
        archive_name = f"{dir_name}.zip"
        url     = f"https://ziglang.org/download/{_ZIG_VERSION}/{archive_name}"
        archive = os.path.join(tempfile.gettempdir(), archive_name)

        print(f"setup.py: downloading Zig {_ZIG_VERSION} from {url!r} …")
        try:
            urllib.request.urlretrieve(url, archive)
        except Exception:
            subprocess.check_call(["curl", "-fsSL", url, "-o", archive])

        _verify_sha256(archive, zig_sha, f"Zig {_ZIG_VERSION} ({arch}-{os_name})")
        print(f"setup.py: extracting {archive!r} …")
        import zipfile
        with zipfile.ZipFile(archive, "r") as zf:
            zf.extractall(tempfile.gettempdir())
    else:
        tarball  = f"{dir_name}.tar.xz"
        url      = f"https://ziglang.org/download/{_ZIG_VERSION}/{tarball}"
        archive  = os.path.join(tempfile.gettempdir(), tarball)

        print(f"setup.py: downloading Zig {_ZIG_VERSION} from {url!r} …")
        try:
            urllib.request.urlretrieve(url, archive)
        except Exception:
            subprocess.check_call(["curl", "-fsSL", url, "-o", archive])

        _verify_sha256(archive, zig_sha, f"Zig {_ZIG_VERSION} ({arch}-{os_name})")
        print(f"setup.py: extracting {archive!r} …")
        with tarfile.open(archive, "r:xz") as tf:
            _safe_extractall(tf, tempfile.gettempdir())

    os.remove(archive)

    if not os.path.isfile(zig_exe):
        raise RuntimeError(
            f"Zig binary not found at {zig_exe!r} after extraction. "
            f"Check that {url!r} is correct."
        )

    if sys.platform != "win32":
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


def _download_file(url: str, dest: str) -> None:
    """Download *url* to *dest*, falling back to ``curl`` if urllib fails."""
    print(f"setup.py: downloading {url!r} …")
    try:
        urllib.request.urlretrieve(url, dest)
    except Exception:
        subprocess.check_call(["curl", "-fsSL", url, "-o", dest])


def _openssl_host_arch() -> str:
    machine = platform.machine().lower()
    if machine in ("aarch64", "arm64"):
        return "aarch64"
    return "x86_64"


def _openssl_lib_names():
    """Return candidate filenames for libssl / libcrypto on this platform."""
    if sys.platform == "win32":
        return (
            ("libssl.lib", "ssl.lib"),
            ("libcrypto.lib", "crypto.lib"),
        )
    if sys.platform == "darwin":
        return (
            ("libssl.a", "libssl.dylib"),
            ("libcrypto.a", "libcrypto.dylib"),
        )
    return (
        ("libssl.a", "libssl.so"),
        ("libcrypto.a", "libcrypto.so"),
    )


def _dir_has_openssl_libs(lib_dir: str) -> bool:
    if not lib_dir or not os.path.isdir(lib_dir):
        return False
    ssl_names, crypto_names = _openssl_lib_names()
    has_ssl = any(os.path.isfile(os.path.join(lib_dir, n)) for n in ssl_names)
    has_crypto = any(os.path.isfile(os.path.join(lib_dir, n)) for n in crypto_names)
    return has_ssl and has_crypto


def _dir_has_openssl_headers(include_dir: str) -> bool:
    return bool(
        include_dir
        and os.path.isfile(os.path.join(include_dir, "openssl", "ssl.h"))
    )


def _system_openssl_ok() -> bool:
    """True when Zig can compile/link against the OS OpenSSL without help."""
    include_ok = any(
        _dir_has_openssl_headers(d)
        for d in ("/usr/include", "/usr/local/include")
    )
    if not include_ok:
        return False

    lib_dirs = [
        "/usr/local/lib",
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib/aarch64-linux-gnu",
        "/lib64",
        "/lib",
        "/usr/lib64",
        "/usr/lib",
        "/lib/x86_64-linux-gnu",
        "/lib/aarch64-linux-gnu",
        "/opt/homebrew/lib",
        "/usr/local/opt/openssl@3/lib",
        "/usr/local/opt/openssl/lib",
    ]
    return any(_dir_has_openssl_libs(d) for d in lib_dirs)


def _openssl_prefix_paths(prefix: str):
    """Return ``(include_dir, lib_dir)`` under *prefix*, or ``(None, None)``."""
    include_dir = os.path.join(prefix, "include")
    for lib_name in ("lib", "lib64"):
        lib_dir = os.path.join(prefix, lib_name)
        if _dir_has_openssl_headers(include_dir) and _dir_has_openssl_libs(lib_dir):
            return include_dir, lib_dir
    return None, None


def _ensure_openssl_unix():
    """Download and build a static OpenSSL into ``/tmp``, reusing the cache."""
    arch = _openssl_host_arch()
    prefix = os.path.join(
        tempfile.gettempdir(), f"openssl-{_OPENSSL_VERSION}-{arch}"
    )
    cached = _openssl_prefix_paths(prefix)
    if cached[0]:
        print(f"setup.py: reusing cached OpenSSL at {prefix!r}")
        return cached

    for tool in ("perl", "make", "cc"):
        if not shutil.which(tool):
            raise RuntimeError(
                f"Cannot auto-build OpenSSL: {tool!r} not found in PATH. "
                "Install a C toolchain, or install OpenSSL development headers "
                "(e.g. apt install libssl-dev), or set OPENSSL_DIR."
            )

    src_root = os.path.join(
        tempfile.gettempdir(), f"openssl-{_OPENSSL_VERSION}-src-{arch}"
    )
    src_dir = os.path.join(src_root, f"openssl-{_OPENSSL_VERSION}")
    tarball = os.path.join(
        tempfile.gettempdir(), f"openssl-{_OPENSSL_VERSION}.tar.gz"
    )
    url = (
        "https://github.com/openssl/openssl/releases/download/"
        f"openssl-{_OPENSSL_VERSION}/openssl-{_OPENSSL_VERSION}.tar.gz"
    )

    if not os.path.isdir(src_dir):
        if not os.path.isfile(tarball):
            _download_file(url, tarball)
        _verify_sha256(
            tarball,
            os.environ.get("DAFFI_OPENSSL_SHA256") or _OPENSSL_SHA256.get(_OPENSSL_VERSION),
            f"OpenSSL {_OPENSSL_VERSION} source tarball "
            "(set DAFFI_OPENSSL_SHA256 when overriding DAFFI_OPENSSL_VERSION)",
        )
        print(f"setup.py: extracting {tarball!r} …")
        os.makedirs(src_root, exist_ok=True)
        with tarfile.open(tarball, "r:gz") as tf:
            _safe_extractall(tf, src_root)

    if not os.path.isdir(src_dir):
        raise RuntimeError(
            f"OpenSSL sources not found at {src_dir!r} after extraction from {url!r}"
        )

    print(
        f"setup.py: building OpenSSL {_OPENSSL_VERSION} "
        f"(static, no-shared) → {prefix!r} …",
        flush=True,
    )
    jobs = str(os.cpu_count() or 2)
    configure = os.path.join(src_dir, "config")
    if not os.path.isfile(configure):
        configure = os.path.join(src_dir, "Configure")
    verbose = os.environ.get("DAFFI_VERBOSE", "").strip() in ("1", "true", "yes")
    build_out = None if verbose else subprocess.DEVNULL
    subprocess.check_call(
        [
            configure,
            "no-shared",
            "no-tests",
            "-fPIC",
            f"--prefix={prefix}",
            "--libdir=lib",
        ],
        cwd=src_dir,
        stdout=build_out,
    )
    subprocess.check_call(
        ["make", f"-j{jobs}"], cwd=src_dir, stdout=build_out
    )
    subprocess.check_call(
        ["make", "install_sw"], cwd=src_dir, stdout=build_out
    )

    result = _openssl_prefix_paths(prefix)
    if not result[0]:
        raise RuntimeError(
            f"OpenSSL build finished but libs/headers missing under {prefix!r}"
        )
    print(f"setup.py: OpenSSL {_OPENSSL_VERSION} ready at {prefix!r}")
    return result


def _ensure_openssl_windows():
    """Fetch prebuilt Windows OpenSSL from python/cpython-bin-deps."""
    branch = "openssl-bin-3.0"
    prefix = os.path.join(tempfile.gettempdir(), f"cpython-bin-deps-{branch}")
    amd64 = os.path.join(prefix, "amd64")
    include_dir = os.path.join(amd64, "include")
    if _dir_has_openssl_headers(include_dir) and _dir_has_openssl_libs(amd64):
        print(f"setup.py: reusing cached OpenSSL at {amd64!r}")
        return include_dir, amd64

    archive = os.path.join(tempfile.gettempdir(), f"{branch}.tar.gz")
    url = (
        "https://github.com/python/cpython-bin-deps"
        f"/archive/refs/heads/{branch}.tar.gz"
    )
    if not os.path.isfile(archive):
        _download_file(url, archive)

    extract_root = os.path.join(tempfile.gettempdir(), f"{branch}-extract")
    if os.path.isdir(extract_root):
        shutil.rmtree(extract_root)
    os.makedirs(extract_root, exist_ok=True)
    print(f"setup.py: extracting {archive!r} …")
    with tarfile.open(archive, "r:gz") as tf:
        _safe_extractall(tf, extract_root)

    top = next(
        os.path.join(extract_root, name)
        for name in os.listdir(extract_root)
        if os.path.isdir(os.path.join(extract_root, name))
    )
    src_amd64 = os.path.join(top, "amd64")
    if not os.path.isdir(src_amd64):
        raise RuntimeError(
            f"Expected amd64/ in cpython-bin-deps archive, found: {os.listdir(top)}"
        )

    if os.path.isdir(prefix):
        shutil.rmtree(prefix)
    shutil.copytree(top, prefix)

    # Zig/LLD looks for ssl.lib / crypto.lib; the archive ships libssl.lib.
    for lib_name in ("ssl", "crypto"):
        src = os.path.join(amd64, f"lib{lib_name}.lib")
        dst = os.path.join(amd64, f"{lib_name}.lib")
        if os.path.isfile(src) and not os.path.exists(dst):
            try:
                os.symlink(src, dst)
            except OSError:
                shutil.copy2(src, dst)

    if not (
        _dir_has_openssl_headers(include_dir) and _dir_has_openssl_libs(amd64)
    ):
        raise RuntimeError(f"Windows OpenSSL cache incomplete under {amd64!r}")

    print(f"setup.py: OpenSSL ({branch}) ready at {amd64!r}")
    return include_dir, amd64


def _ensure_openssl():
    """Return ``(include_dir, lib_dir)`` from a downloaded/built OpenSSL."""
    if os.environ.get("DAFFI_NO_OPENSSL_DOWNLOAD", "").strip() in (
        "1",
        "true",
        "yes",
    ):
        raise RuntimeError(
            "OpenSSL development files not found and "
            "DAFFI_NO_OPENSSL_DOWNLOAD is set. Install libssl-dev / openssl "
            "headers, or set OPENSSL_DIR."
        )
    if sys.platform == "win32":
        return _ensure_openssl_windows()
    if sys.platform.startswith("linux") or sys.platform == "darwin":
        return _ensure_openssl_unix()
    raise RuntimeError(
        f"No OpenSSL auto-download support for {sys.platform!r}. "
        "Install OpenSSL development files or set OPENSSL_DIR."
    )


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

    elif sys.platform == "win32":
        # GitHub Actions windows-2022/2025 runners and typical local installs.
        candidates = [
            r"C:\Program Files\OpenSSL-Win64",
            r"C:\Program Files\OpenSSL",
            r"C:\OpenSSL-Win64",
            r"C:\OpenSSL",
        ]
        for candidate in candidates:
            if os.path.isdir(candidate):
                print(f"setup.py: found OpenSSL at {candidate!r}")
                return (
                    os.path.join(candidate, "include"),
                    os.path.join(candidate, "lib"),
                )

    if _system_openssl_ok():
        print("setup.py: using system OpenSSL")
        return None, None

    print("setup.py: system OpenSSL not usable for linking — bootstrapping …")
    return _ensure_openssl()


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


def _require_python_headers(include_dirs) -> None:
    """Fail early with an actionable message if ``Python.h`` is missing."""
    for d in include_dirs:
        if d and os.path.isfile(os.path.join(d, "Python.h")):
            return
    ver = f"{sys.version_info.major}.{sys.version_info.minor}"
    searched = ", ".join(repr(d) for d in include_dirs if d) or "(none)"
    raise RuntimeError(
        f"Python.h not found (searched: {searched}). "
        f"Install the Python {ver} development headers, e.g.\n"
        f"  Debian/Ubuntu:  sudo apt install python{ver}-dev\n"
        f"  Fedora/RHEL:    sudo dnf install python{ver}-devel\n"
        f"  macOS:          install Python from python.org or brew\n"
        "These headers must match this interpreter and cannot be "
        "auto-downloaded like Zig/OpenSSL."
    )


_HERE = os.path.dirname(os.path.abspath(__file__))
_ZIG_ROOT = os.path.join(_HERE, "core", "core.zig")
_C_MODULES = {
    "python_c": os.path.join(_HERE, "core", "c", "python.h"),
    "posix_c": os.path.join(_HERE, "core", "c", "posix.h"),
    "openssl_c": os.path.join(_HERE, "core", "c", "openssl.h"),
}


def zig_c_module_args(zig, out_dir, include_dirs, target=None):
    """Translate the headers in ``core/c/`` into ``out_dir`` and return the
    ``zig build-lib`` / ``zig test`` arguments that compile ``core/core.zig``
    with them importable as ``@import("<name>")``.

    The returned arguments must come last on the command line: the ``-M``
    flags close the option list of the root module.
    """
    os.makedirs(out_dir, exist_ok=True)
    flags = ["-lc", *(f"-I{d}" for d in include_dirs if d)]
    if target:
        flags += ["-target", target]

    args = [arg for name in _C_MODULES for arg in ("--dep", name)]
    args.append(f"-Mroot={_ZIG_ROOT}")
    for name, header in _C_MODULES.items():
        out = os.path.join(out_dir, f"{name}.zig")
        with open(out, "wb") as f:
            subprocess.run([zig, "translate-c", *flags, header], stdout=f, check=True)
        args.append(f"-M{name}={out}")
    return args


def _openssl_link_args(openssl_lib):
    """Linker arguments for OpenSSL on POSIX.

    Prefers static archives when present (macOS Homebrew, auto-built Linux
    OpenSSL) and falls back to dynamic ``-lssl``/``-lcrypto``.
    """
    if openssl_lib:
        ssl_a = os.path.join(openssl_lib, "libssl.a")
        crypto_a = os.path.join(openssl_lib, "libcrypto.a")
        if os.path.exists(ssl_a) and os.path.exists(crypto_a):
            return [ssl_a, crypto_a]
        return [f"-L{openssl_lib}", "-lssl", "-lcrypto"]
    # System OpenSSL on default search paths (e.g. libssl-dev).
    return ["-lssl", "-lcrypto"]


class ZigTest(Command):
    """Setuptools command: run the Zig unit tests (``python setup.py zig_test``).

    Links against the running interpreter's shared libpython, so it needs a
    Python built with ``--enable-shared`` (Homebrew, python.org, most distros).
    """

    description = "run the Zig unit tests in core/"
    user_options = []

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        import sysconfig

        zig = _ensure_zig()
        include_dirs = [sysconfig.get_paths()["include"]]
        _require_python_headers(include_dirs)
        openssl_include, openssl_lib = _find_openssl()
        if openssl_include:
            include_dirs.append(openssl_include)

        libdir = sysconfig.get_config_var("LIBDIR")
        ldversion = sysconfig.get_config_var("LDVERSION")
        cmd = [
            zig, "test",
            "-lc",
            f"-L{libdir}", f"-lpython{ldversion}", "-rpath", libdir,
            *_openssl_link_args(openssl_lib),
            *zig_c_module_args(zig, os.path.join(_HERE, "build", "zig_test"), include_dirs),
        ]
        subprocess.check_call(cmd, cwd=_HERE)


class ZigBuilder(build_ext):
    def build_extension(self, ext):
        out_dir = os.path.dirname(self.get_ext_fullpath(ext.name))
        os.makedirs(out_dir, exist_ok=True)

        _require_python_headers(self.include_dirs)

        mode = "debug" if self.debug else os.environ.get("ZIG_OPT", "safe")
        openssl_include, openssl_lib = _find_openssl()
        target = _zig_target()
        zig = _ensure_zig()

        include_dirs = list(self.include_dirs)
        if openssl_include:
            include_dirs.append(openssl_include)

        cmd = [
            zig,
            "build-lib",
            "-O", mode,
            "-lc",
            f"-femit-bin={self.get_ext_fullpath(ext.name)}",
            "-fallow-shlib-undefined",
            "-dynamic",
        ]

        if target:
            cmd += ["-target", target]

        if sys.platform == "win32":
            # Windows: link Python import library explicitly (Zig doesn't
            # auto-discover it the way MSVC does), then OpenSSL dynamically.
            # delvewheel will bundle libssl/libcrypto DLLs into the wheel.
            python_ver = f"python{sys.version_info.major}{sys.version_info.minor}"
            python_libs_dir = os.path.join(sys.prefix, "libs")
            if os.path.isdir(python_libs_dir):
                cmd.append(f"-L{python_libs_dir}")
            cmd.append(f"-l{python_ver}")
            if openssl_lib:
                cmd.extend([f"-L{openssl_lib}", "-lssl", "-lcrypto"])
        else:
            cmd.extend(_openssl_link_args(openssl_lib))

        cmd += zig_c_module_args(zig, os.path.join(self.build_temp, "zig_c"), include_dirs, target)
        self.spawn(cmd)

        # Local Windows installs need OpenSSL DLLs next to the extension.
        if sys.platform == "win32" and openssl_lib and os.path.isdir(openssl_lib):
            for name in os.listdir(openssl_lib):
                lower = name.lower()
                if lower.endswith(".dll") and (
                    "ssl" in lower or "crypto" in lower
                ):
                    src = os.path.join(openssl_lib, name)
                    dst = os.path.join(out_dir, name)
                    if not os.path.isfile(dst):
                        shutil.copy2(src, dst)
                        print(f"setup.py: copied {name} → {out_dir!r}")


if __name__ == "__main__":
    setup(
        ext_modules=[Extension("daffi.dfcore", sources=["core/core.zig"])],
        cmdclass={
            "build_ext": ZigBuilder,
            "ensure_zig": EnsureZig,
            "zig_test": ZigTest,
        },
    )
