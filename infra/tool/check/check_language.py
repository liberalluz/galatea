#!/usr/bin/env python3
"""Check the language contract: config, root docs, and controlled docs (read-only).

This is the checker for the `language` block in `.nebula-scaffold.json` and for
the translation pairing of `README.md` / `CONTRIBUTING.md` (root docs) and
`docs/specs/controlled/`. Legacy `repoLocale`/`docsLocale` scaffolds are mapped
with warnings so the checker keeps working before migration.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from language import LOCALE_RE, resolve_language, validate_language

SOURCE_STEMS = ("SRS", "SDD", "STP", "STD", "SCMP")
ROOT_STEMS = ("README", "CONTRIBUTING")
# Generated companions with the `<stem>.<suffix>.md` shape that are not
# translations, e.g. `CONTRIBUTING.ai.md` written by `bootstrap --with-ai-policy`.
NON_LOCALE_SUFFIXES = frozenset({"ai"})
MARKER_RE = re.compile(r"<!--\s*translation-of\s*:\s*([^>]*?)\s*-->")
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s", re.MULTILINE)
TRANSLATION_RE = re.compile(r"^(?P<stem>[A-Z]+)\.(?P<locale>.+)\.md$")


def check_config(root: Path) -> tuple[dict | None, list[str], list[str]]:
    """Return the normalized language, errors, and warnings."""
    errors: list[str] = []
    warnings: list[str] = []
    path = root / ".nebula-scaffold.json"
    if not path.is_file():
        return None, [f"missing {path.name}"], warnings

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, [f"cannot read {path.name}: {exc}"], warnings
    if not isinstance(data, dict):
        return None, [f"{path.name} is not an object"], warnings

    raw = data.get("language")
    if raw is not None:
        try:
            language = validate_language(raw)
        except ValueError as exc:
            return None, [f"language: {exc}"], warnings
        raw_supported = raw.get("supported") if isinstance(raw, dict) else None
        if isinstance(raw_supported, list) and raw_supported != language["supported"]:
            warnings.append(
                "language.supported is not normalized (primary first, no duplicates)"
            )
        return language, errors, warnings

    if not any(key in data for key in ("repoLocale", "docsLocale")):
        return None, ["language is missing (no language, repoLocale, or docsLocale block)"], warnings

    language, legacy_warnings = resolve_language(root)
    warnings.extend(legacy_warnings)
    return language, errors, warnings


def check_marker(path: Path, source_name: str) -> list[str]:
    """Return marker/heading errors for one translation file."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [f"{path.name}: cannot read: {exc}"]

    markers = list(MARKER_RE.finditer(text))
    if len(markers) != 1:
        return [f"{path.name}: expected exactly one translation-of marker before the first heading"]
    heading = HEADING_RE.search(text)
    if heading is not None and markers[0].start() > heading.start():
        return [f"{path.name}: translation-of marker must precede the first heading"]
    marker_source = markers[0].group(1).strip()
    if marker_source != source_name:
        return [f"{path.name}: translation-of is {marker_source!r}, expected {source_name!r}"]
    return []


def repo_language(root: Path, language: dict, errors: list[str]) -> str:
    """The bare name in this repository: `repoLanguage`, else the documents' primary."""
    path = root / ".nebula-scaffold.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return language["primary"]
    raw = data.get("repoLanguage") if isinstance(data, dict) else None
    if not isinstance(raw, str) or not raw.strip():
        return language["primary"]
    value = raw.strip()
    if value not in language["supported"]:
        errors.append(f"repoLanguage {value!r} is not in language.supported")
        return language["primary"]
    return value


def check_pairing(
    directory: Path,
    source_stems: tuple[str, ...],
    language: dict,
    label: str,
    require_sources: bool = True,
    primary: str | None = None,
) -> tuple[list[str], list[str]]:
    """Check translations for `source_stems` that live next to their source.

    `require_sources=False` is for controlled docs: a stage may not have created
    a given document yet, and a missing source is not a finding. `primary` is the
    bare name for this directory; root docs and controlled docs use the repository
    language, documents use `language.primary`.
    """
    errors: list[str] = []
    warnings: list[str] = []
    if not directory.exists():
        warnings.append(f"{label} not found; nothing to check")
        return errors, warnings
    if not directory.is_dir():
        return [f"{label} is not a directory"], warnings

    bare = primary or language["primary"]
    supported = set(language["supported"])

    for stem in source_stems:
        source = directory / f"{stem}.md"
        if not source.is_file():
            if require_sources:
                warnings.append(f"missing language source: {source.name}")
            continue
        for locale in language["supported"]:
            if locale == bare:
                continue
            target = directory / f"{stem}.{locale}.md"
            if not target.is_file():
                errors.append(f"missing translation: {target.name}")

    for stem in source_stems:
        for path in sorted(directory.glob(f"{stem}.*.md")):
            if not path.is_file():
                continue
            locale = path.name[len(stem) + 1 : -len(".md")]
            if locale in NON_LOCALE_SUFFIXES:
                continue
            if not LOCALE_RE.fullmatch(locale):
                warnings.append(
                    f"{path.name}: skipped; suffix {locale!r} is not a language code"
                )
                continue
            source = directory / f"{stem}.md"
            if not source.is_file():
                errors.append(f"{path.name}: source {source.name} not found")
                continue
            if locale == bare:
                errors.append(
                    f"{path.name}: the repository's own locale must not have a translation file"
                )
                continue
            if locale not in supported:
                errors.append(f"{path.name}: locale {locale!r} is not in language.supported")
                continue
            errors.extend(check_marker(path, source.name))

    return errors, warnings


def check(root: Path) -> tuple[list[str], list[str]]:
    language, errors, warnings = check_config(root)
    if language is None:
        return errors, warnings

    bare = repo_language(root, language, errors)
    root_errors, root_warnings = check_pairing(
        root, ROOT_STEMS, language, "root docs", primary=bare
    )
    docs_errors, docs_warnings = check_pairing(
        root / "docs" / "specs" / "controlled",
        SOURCE_STEMS,
        language,
        "docs/specs/controlled",
        require_sources=False,
        primary=bare,
    )
    return (
        errors + root_errors + docs_errors,
        warnings + root_warnings + docs_warnings,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="check the language contract")
    parser.add_argument("--root", type=Path, default=Path("."))
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--warn", action="store_true", help="report all findings; exit 0")
    modes.add_argument(
        "--strict",
        action="store_true",
        help="treat every warning as a failure (finish the default-mode findings first)",
    )
    args = parser.parse_args(argv)

    if not args.root.is_dir():
        print(f"not a directory: {args.root}", file=sys.stderr)
        return 2

    errors, warnings = check(args.root)
    if args.warn:
        warnings = [*errors, *warnings]
        errors = []
    elif args.strict:
        errors = [*errors, *warnings]
        warnings = []

    for item in warnings:
        print(f"[warn] {item}")
    for item in errors:
        print(f"[fail] {item}")
    print(f"\n{len(errors)} errors · {len(warnings)} warnings")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
