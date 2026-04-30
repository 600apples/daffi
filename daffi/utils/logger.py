"""
Colored logger factory for daffi components.

To enable native Zig log output call :func:`sync_native_log_level` (or
call ``dfcore.setLogLevel(n)`` directly) **before** constructing any
Application.  The native layer is silent by default (level 4 = off).
"""

import sys
import logging
from typing import Callable

from daffi.utils import colors


def _python_level_to_native(python_level: int) -> int:
    """Convert a Python logging level integer to the Zig native level.

    Python levels:   DEBUG=10  INFO=20  WARNING=30  ERROR=40
    Zig native:      0=debug   1=info   2=warning   3=error  4=off
    """
    if python_level <= logging.DEBUG:
        return 0
    elif python_level <= logging.INFO:
        return 1
    elif python_level <= logging.WARNING:
        return 2
    elif python_level <= logging.ERROR:
        return 3
    return 4  # off


def sync_native_log_level(python_level: int | None = None) -> None:
    """Push the current (or supplied) Python log level to the native layer.

    Safe to call at any time; silently does nothing if *dfcore* is not yet
    importable (e.g. during wheel build / docs generation).

    Args:
        python_level: explicit Python level integer.  When *None* (default)
                      the effective level of the root logger is used.
    """
    if python_level is None:
        python_level = logging.getLogger().getEffectiveLevel()
    try:
        from daffi import dfcore  # local import to avoid circular imports

        dfcore.setLogLevel(_python_level_to_native(python_level))
    except Exception:
        pass


class DaffiLoggerAdapter(logging.LoggerAdapter):
    """``LoggerAdapter`` that injects a coloured *app* field into every record.

    The ``extra={"app": ...}`` dict passed to the constructor is merged into
    each ``LogRecord`` by the base-class ``process()`` so the ``%(app)s``
    placeholder in the format string is always available.  No override is
    needed — the default ``LoggerAdapter.process`` already handles this.
    """


class ColoredFormatter(logging.Formatter):
    """``logging.Formatter`` that colorises WARNING and ERROR level prefixes."""

    def get_level_message(self, record: logging.LogRecord) -> str:
        """Return a fixed-width, coloured level label for *record*."""
        if record.levelno <= logging.INFO:
            levelname = f"{colors.green(record.levelname)}:"
        elif record.levelno <= logging.WARNING:
            levelname = f"{colors.yellow(record.levelname)}:"
        else:
            levelname = f"{colors.red(record.levelname)}:"
        return f"{levelname: <17}"

    def format(self, record: logging.LogRecord) -> str:
        """Format *record*, decoding bytes messages and prepending the level label."""
        if isinstance(record.msg, bytes):
            record.msg = record.msg.decode("utf-8")
        message = super().format(record)
        return f"{self.get_level_message(record)} {message}"


def get_daffi_logger(name: str, color: Callable) -> DaffiLoggerAdapter:
    """Create and return a configured :class:`DaffiLoggerAdapter` for *name*.

    The adapter injects a ``%(app)s`` extra that wraps the logger name in
    coloured pipe delimiters, e.g. ``| my-service |``.

    Args:
        name:  Identifier shown in every log line (e.g. ``"client[my-app]"``).
        color: A callable from :mod:`daffi.utils.colors` used to colour the
               pipe delimiters.
    """
    logger = logging.getLogger(name=name)
    root_level = logging.getLogger().getEffectiveLevel()

    cho = logging.StreamHandler(sys.stdout)
    che = logging.StreamHandler(sys.stderr)

    logger.propagate = False
    if logger.hasHandlers():
        logger.handlers.clear()

    cho.addFilter(lambda record: record.levelno <= logging.INFO)
    delim = color("|")
    logger = DaffiLoggerAdapter(logger, {"app": f"{delim} {logger.name:^10} {delim}"})

    logger.setLevel(root_level)
    cho.setLevel(root_level)
    che.setLevel(logging.WARNING)
    formatter = ColoredFormatter("%(asctime)s %(app)s %(message)s", "%Y-%m-%d %H:%M:%S")
    cho.setFormatter(formatter)
    che.setFormatter(formatter)

    logger.logger.addHandler(cho)
    logger.logger.addHandler(che)
    return logger
