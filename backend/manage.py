#!/usr/bin/env python
"""Django command-line utility for administrative tasks."""

import os
import sys


def main():
    # Must run before any third-party import: some bundled data files (e.g.
    # panphon's IPA feature table) are not readable under Windows' default
    # locale encoding, and nothing after interpreter startup can fix that.
    # See config/ensure_utf8.py for why re-exec is the only reliable option.
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from config.ensure_utf8 import ensure_utf8_mode

    ensure_utf8_mode()

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Could not import Django. Are you sure it is installed and "
            "available on your PYTHONPATH? Did you forget to activate a "
            "virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
