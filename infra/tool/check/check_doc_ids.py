#!/usr/bin/env python3
"""Check the controlled docs' bilingual id equality (read-only).

Pairs every bare source in ``docs/specs/controlled/`` with its
``<stem>.zh-CN.md`` translation and compares the id sets (``REQ-NNN``,
``TC-NNN``, ``ADR-NNNN``) extracted from both sides. A missing translation,
a translation without a source, or a differing id set is a failure.
Exit 0 when every pair is id-identical, 1 otherwise.

``--root`` points the checker at any directory laid out the same way, which
is the negative-case harness: a seeded fixture with one extra id must fail
before the green run on the real tree is trusted.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

LOCALE = "zh-CN"
CONTROLLED_DIR = Path("docs") / "specs" / "controlled"
ID_RE = re.compile(r"\b(?:REQ|TC|ADR)-\d{3,4}\b")


def extract_ids(path: Path) -> set[str]:
    """Return the id set found in one document."""
    text = path.read_text(encoding="utf-8", errors="replace")
    return set(ID_RE.findall(text))


def report(ids: set[str], label: str) -> list[str]:
    """Render one side's id set for the failure report."""
    return [f"  {label}: {', '.join(sorted(ids)) or '(none)'}"]


def check_pair(source: Path, translation: Path) -> list[str]:
    """Return the failure lines for one source/translation pair."""
    source_ids = extract_ids(source)
    translation_ids = extract_ids(translation)
    if source_ids == translation_ids:
        return []
    lines = [f"{source.name} / {translation.name}: id sets differ"]
    only_source = source_ids - translation_ids
    only_translation = translation_ids - source_ids
    if only_source:
        lines.append(f"  missing in {translation.name}: {', '.join(sorted(only_source))}")
    if only_translation:
        lines.append(f"  missing in {source.name}: {', '.join(sorted(only_translation))}")
    return lines


def check_directory(controlled: Path) -> list[str]:
    """Return the failure lines for the whole controlled directory."""
    errors: list[str] = []
    if not controlled.is_dir():
        return [f"controlled directory not found: {controlled}"]

    bare = sorted(p for p in controlled.glob("*.md") if not p.name.endswith(f".{LOCALE}.md"))
    translations = {p.name for p in controlled.glob(f"*.{LOCALE}.md")}

    for source in bare:
        translation = source.with_suffix(f".{LOCALE}.md")
        if translation.name not in translations:
            errors.append(f"missing translation: {translation.name}")
            continue
        errors.extend(check_pair(source, translation))

    stems = {p.name[: -len(".md")] for p in bare}
    for name in sorted(translations):
        if name[: -len(f".{LOCALE}.md")] not in stems:
            errors.append(f"translation without source: {name}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="check the controlled docs' bilingual id equality")
    parser.add_argument("--root", type=Path, default=Path("."), help="repository root (default: .)")
    args = parser.parse_args(argv)

    errors = check_directory(args.root / CONTROLLED_DIR)
    for line in errors:
        print(line)
    if errors:
        print(f"{len(errors)} finding(s)")
        return 1
    print("bilingual id check: all controlled pairs carry identical ids")
    return 0


if __name__ == "__main__":
    sys.exit(main())
