"""Guarantee the process runs in Python's UTF-8 mode (PEP 540).

Without this, a stock Windows install falls back to the system code page
(`cp1252` on this project's dev machine) for every file opened with no
explicit encoding - including panphon's bundled IPA feature-table CSV, which
contains characters outside that code page and fails to load with a raw
`UnicodeDecodeError`.

`sys.flags.utf8_mode` is fixed at interpreter startup: nothing a running
process does to `os.environ` can change it retroactively, so monkeypatching
individual call sites (`io.open`, `pandas.read_csv`, ...) is a losing game -
there is always one more library that opens a file its own way. Re-running the
interpreter once, with `PYTHONUTF8=1` set, fixes the encoding for every file
the process ever opens, not just the one that happened to be noticed first.

`os.execv` looks like the obvious way to do that, and was the first thing
tried here - but on Windows it is emulated on top of `CreateProcess`, which
takes a single command-line *string*, not an argument array, and Python's
emulation does not reliably re-quote arguments containing spaces. This
project's own path - `C:\\Users\\User\\hear and speak\\backend` - has one, and
that broke `execv` outright: the space split the interpreter path into
separate arguments and the process failed to start. `subprocess.run`, which
already gets Windows quoting right (via `list2cmdline`), does not have this
problem, at the cost of one extra process start.

This is a no-op on Linux (including CI), where UTF-8 is already the practical
default, so the guard exits immediately without spawning anything.
"""

import os
import subprocess
import sys

_REEXEC_GUARD = "HEARSPEAK_UTF8_REEXEC"


def ensure_utf8_mode():
    if sys.flags.utf8_mode:
        return  # already running in UTF-8 mode; nothing to do

    if os.environ.get(_REEXEC_GUARD):
        # Already re-run once and it still is not set - do not loop forever.
        return

    env = dict(os.environ)
    env[_REEXEC_GUARD] = "1"
    env["PYTHONUTF8"] = "1"

    result = subprocess.run(
        [sys.executable, "-X", "utf8", *sys.argv], env=env
    )
    sys.exit(result.returncode)
