"""
Unit tests for daffi.utils.logger and daffi.utils.colors.
"""

import logging
from contextlib import contextmanager
from logging import LoggerAdapter

import pytest
from daffi.utils import colors
from daffi.utils.logger import get_daffi_logger, ColoredFormatter


class MockLevelRecord:
    exc_info = None
    exc_text = None
    stack_info = None

    def __init__(self, levelno: int, levelname: str, msg=""):
        self.levelno = levelno
        self.levelname = levelname
        self.msg = msg

    def getMessage(self) -> str:
        return self.msg if isinstance(self.msg, str) else self.msg.decode()


class TestColoredFormatter:
    @pytest.mark.parametrize(
        "record, expected_result",
        [
            (MockLevelRecord(logging.ERROR, "error"), f"{colors.red('error')}:"),
            (
                MockLevelRecord(logging.WARNING, "warning"),
                f"{colors.yellow('warning')}:",
            ),
            (MockLevelRecord(logging.INFO, "info"), f"{colors.green('info')}:"),
        ],
    )
    def test_get_level_message(self, record, expected_result):
        formatter = ColoredFormatter()
        result = formatter.get_level_message(record)
        assert result.strip() == expected_result

    @pytest.mark.parametrize(
        "record, expected_result",
        [
            (
                MockLevelRecord(logging.ERROR, "error", "error"),
                f"{colors.red('error')}:   error",
            ),
            (
                MockLevelRecord(logging.WARNING, "warning", b"warning"),
                f"{colors.yellow('warning')}: warning",
            ),
        ],
    )
    def test_format(self, record, expected_result):
        formatter = ColoredFormatter()
        result = formatter.format(record)
        assert result == expected_result

    def test_patch_logging(self):
        logger = get_daffi_logger(__name__, color=colors.red)
        assert isinstance(logger, LoggerAdapter)


@contextmanager
def bare_root():
    """A root logger with no handlers, as in a script that never set up
    logging (pytest attaches its own while a test runs)."""
    root = logging.getLogger()
    saved, level = root.handlers[:], root.level
    root.handlers.clear()
    root.setLevel(logging.INFO)
    try:
        yield root
    finally:
        root.handlers[:] = saved
        root.setLevel(level)


def test_loggers_are_not_created_per_app_name():
    before = set(logging.Logger.manager.loggerDict)
    for i in range(50):
        get_daffi_logger(f"client[app-{i}]", colors.red)
    assert set(logging.Logger.manager.loggerDict) - before <= {"daffi"}
    assert len(logging.getLogger("daffi").handlers) == 2


def test_records_reach_the_applications_handlers(capsys):
    seen = []

    class Collect(logging.Handler):
        def emit(self, record):
            seen.append(record)

    with bare_root() as root:
        root.addHandler(Collect())
        get_daffi_logger("service[mine]", colors.yellow).warning("hello")
    assert [(r.getMessage(), r.daffi_app) for r in seen] == [("hello", "service[mine]")]
    assert capsys.readouterr() == ("", "")


def test_prints_to_the_console_until_logging_is_configured(capsys):
    logger = get_daffi_logger("router[edge]", colors.blue)
    with bare_root():
        logger.info("up")
        logger.warning("careful")
    out, err = capsys.readouterr()
    assert "router[edge]" in out and "up" in out and "careful" not in out
    assert "careful" in err
