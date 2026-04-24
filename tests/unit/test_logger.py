"""
Unit tests for daffi.utils.logger and daffi.utils.colors.
"""
import logging
from logging import LoggerAdapter

import pytest
from daffi.utils import colors
from daffi.utils.logger import get_daffi_logger, ColoredFormatter


class MockLevelRecord:
    exc_info  = None
    exc_text  = None
    stack_info = None

    def __init__(self, levelno: int, levelname: str, msg=""):
        self.levelno   = levelno
        self.levelname = levelname
        self.msg       = msg

    def getMessage(self) -> str:
        return self.msg if isinstance(self.msg, str) else self.msg.decode()


class TestColoredFormatter:
    @pytest.mark.parametrize(
        "record, expected_result",
        [
            (MockLevelRecord(logging.ERROR,   "error"),   f"{colors.red('error')}:"),
            (MockLevelRecord(logging.WARNING, "warning"), f"{colors.yellow('warning')}:"),
            (MockLevelRecord(logging.INFO,    "info"),    f"{colors.green('info')}:"),
        ],
    )
    def test_get_level_message(self, record, expected_result):
        formatter = ColoredFormatter()
        result    = formatter.get_level_message(record)
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
        result    = formatter.format(record)
        assert result == expected_result

    def test_patch_logging(self):
        logger = get_daffi_logger(__name__, color=colors.red)
        assert isinstance(logger, LoggerAdapter)
