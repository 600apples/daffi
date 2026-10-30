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


#: The one logger every daffi application logs through.
LOGGER_NAME = "daffi"


def _logging_unconfigured(record: logging.LogRecord) -> bool:
    """True while the root logger has no handlers: the application has not
    set up logging, so daffi prints its own console lines."""
    return not logging.getLogger().handlers


class _ConsoleHandler(logging.StreamHandler):
    """Writes to ``sys.<name>`` as it is when the record is emitted, so a
    replaced ``sys.stdout`` / ``sys.stderr`` is followed."""

    def __init__(self, name: str) -> None:
        self._stream_name = name
        super().__init__()

    @property
    def stream(self):
        return getattr(sys, self._stream_name)

    @stream.setter
    def stream(self, _value) -> None:
        pass


def _console_handlers() -> list:
    formatter = ColoredFormatter("%(asctime)s %(app)s %(message)s", "%Y-%m-%d %H:%M:%S")
    out = _ConsoleHandler("stdout")
    out.addFilter(lambda record: record.levelno <= logging.INFO)
    err = _ConsoleHandler("stderr")
    err.setLevel(logging.WARNING)
    for handler in (out, err):
        handler.addFilter(_logging_unconfigured)
        handler.setFormatter(formatter)
    return [out, err]


def _daffi_logger() -> logging.Logger:
    logger = logging.getLogger(LOGGER_NAME)
    if not any(isinstance(h, _ConsoleHandler) for h in logger.handlers):
        for handler in _console_handlers():
            logger.addHandler(handler)
    return logger


def get_daffi_logger(name: str, color: Callable) -> DaffiLoggerAdapter:
    """Return a :class:`DaffiLoggerAdapter` that tags each record with *name*.

    Every application shares the ``daffi`` logger, so no logger or handler
    is created per name.  Records propagate as usual: once the application
    configures logging (the root logger has handlers), they go to its
    handlers only, carrying the name as ``record.daffi_app``.  Until then
    daffi prints them itself, with the name between coloured pipes, e.g.
    ``| my-service |``.  The level follows the ``daffi`` logger, or the root
    logger when that is unset.

    Args:
        name:  Identifier for every log line (e.g. ``"client[my-app]"``).
        color: A callable from :mod:`daffi.utils.colors` used to colour the
               pipe delimiters.
    """
    delim = color("|")
    return DaffiLoggerAdapter(
        _daffi_logger(), {"app": f"{delim} {name:^10} {delim}", "daffi_app": name}
    )
