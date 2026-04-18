"""
Platform-agnostic ANSI color helpers for console output.

Usage::

    from daffi.utils import colors
    print(colors.red('error!'))
    print(colors.intense_blue('info'))

Available color functions: ``grey``, ``red``, ``green``, ``yellow``, ``blue``,
``magenta``, ``cyan``, ``white``, and their ``intense_*`` variants.
"""

import sys

NAMES = ["grey", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def get_pairs():
    """Yield ``(name, ansi_code)`` pairs for normal and intense color variants."""
    for i, name in enumerate(NAMES):
        yield (name, str(30 + i))
        yield "intense_" + name, str(30 + i) + ";1"


def ansi(code: str) -> str:
    """Return the ANSI escape sequence for *code*."""
    return f"\033[{code}m"


def ansi_color(code: str, s: str) -> str:
    """Wrap *s* in ANSI color *code* and reset afterward."""
    return f"{ansi(code)}{s}{ansi(0)}"


def make_color_fn(code: str):
    """Return a single-argument callable that colorises its input with *code*."""
    return lambda s: ansi_color(code, s)


if sys.platform == "win32":
    import colorama

    colorama.init(strip=False)
for name, code in get_pairs():
    globals()[name] = make_color_fn(code)
