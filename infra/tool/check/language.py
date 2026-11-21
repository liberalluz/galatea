#!/usr/bin/env python3
"""Locate the language module in the base and re-export it.

`base/lib/nebula/language.py` is the single implementation. This file only
finds it, in this order:

1. `$NEBULA_BASE/lib` — a base directory named by the environment;
2. `_lib` beside this file — the copy `install.py` writes into an installed skill;
3. a `base/lib` directory above this file, which is the checkout layout.

When none of them is there the import fails with a sentence that names the path
it looked for, instead of silently falling back to stale rules.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

__all__ = [
    "DEFAULT_PRIMARY",
    "FIELDS",
    "LOCALE_RE",
    "SCAFFOLD_NAME",
    "main",
    "resolve_language",
    "translation_locales",
    "valid_locale",
    "validate_language",
]


def _candidates() -> list[Path]:
    here = Path(__file__).resolve()
    found: list[Path] = []
    base = os.environ.get("NEBULA_BASE")
    if base:
        found.append(Path(base) / "lib")
    found.append(here.parent / "_lib")
    for parent in here.parents:
        found.append(parent / "base" / "lib")
        found.append(parent / "nebula-lifecycle-dev" / "base" / "lib")
    return found


def _load():
    tried = []
    for candidate in _candidates():
        tried.append(candidate / "nebula" / "language.py")
        if (candidate / "nebula" / "language.py").is_file():
            if str(candidate) not in sys.path:
                sys.path.insert(0, str(candidate))
            from nebula import language as module

            return module
    raise ImportError(
        "the Nebula base was not found; looked for "
        + ", ".join(str(path) for path in tried)
        + " — set NEBULA_BASE or install the base beside this skill"
    )


_module = _load()

DEFAULT_PRIMARY = _module.DEFAULT_PRIMARY
FIELDS = _module.FIELDS
LOCALE_RE = _module.LOCALE_RE
SCAFFOLD_NAME = _module.SCAFFOLD_NAME
main = _module.main
resolve_language = _module.resolve_language
translation_locales = _module.translation_locales
valid_locale = _module.valid_locale
validate_language = _module.validate_language
