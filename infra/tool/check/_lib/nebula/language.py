#!/usr/bin/env python3
"""Resolve the project language configuration without rewriting the scaffold.

The canonical block is `language`:

    {"primary": "zh-CN", "supported": ["zh-CN", "en-US"], "external": "en-US"}

`external` is optional and defaults to `primary`. Scaffolds written before this
block existed keep working: `repoLocale`/`docsLocale` are mapped to the new
shape, and `prLocale` is ignored. Resolution never writes the scaffold.

This file is the single implementation. The stage skills import it through
`nebula.language` (see each skill's `scripts/language.py` shim); they never
carry a copy of the resolution rules.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCAFFOLD_NAME = ".nebula-scaffold.json"
DEFAULT_PRIMARY = "zh-CN"
LOCALE_RE = re.compile(r"^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$")
FIELDS = ("primary", "supported", "external")


def valid_locale(value: object) -> bool:
    return isinstance(value, str) and bool(LOCALE_RE.fullmatch(value.strip()))


def _ordered(primary: str, supported: list[str]) -> list[str]:
    return [primary] + [locale for locale in supported if locale != primary]


def validate_language(raw: object) -> dict:
    """Validate a `language` block and return the normalized form.

    Raises ValueError on anything a checker should report: wrong shape, bad
    locale, unsupported primary, external outside `supported`, unknown keys.
    """
    if not isinstance(raw, dict):
        raise ValueError("language must be an object")
    unknown = sorted(set(raw) - set(FIELDS))
    if unknown:
        raise ValueError(f"unknown language fields: {', '.join(unknown)}")

    primary = raw.get("primary")
    if not valid_locale(primary):
        raise ValueError(f"invalid language.primary: {primary!r}")
    primary = primary.strip()

    raw_supported = raw.get("supported")
    if not isinstance(raw_supported, list) or not raw_supported:
        raise ValueError("language.supported must be a non-empty list")
    supported: list[str] = []
    for item in raw_supported:
        if not valid_locale(item):
            raise ValueError(f"invalid language.supported entry: {item!r}")
        if item.strip() not in supported:
            supported.append(item.strip())
    if primary not in supported:
        raise ValueError("language.primary must be listed in language.supported")

    external = raw.get("external")
    if external is None:
        external = primary
    elif not valid_locale(external):
        raise ValueError(f"invalid language.external: {external!r}")
    elif external.strip() not in supported:
        raise ValueError("language.external must be listed in language.supported")
    else:
        external = external.strip()

    return {"primary": primary, "supported": _ordered(primary, supported), "external": external}


def _read_scaffold(root: Path, warnings: list[str]) -> dict:
    path = root / SCAFFOLD_NAME
    if not path.is_file():
        warnings.append(f"missing {SCAFFOLD_NAME}; using defaults")
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        warnings.append(f"cannot read {SCAFFOLD_NAME}: {exc}; using defaults")
        return {}
    if not isinstance(data, dict):
        warnings.append(f"{SCAFFOLD_NAME} is not an object; using defaults")
        return {}
    return data


def _legacy_language(data: dict, warnings: list[str]) -> tuple[dict, list[str]]:
    """Map `repoLocale`/`docsLocale` to the `language` shape."""
    repo = data.get("repoLocale")
    repo = repo if isinstance(repo, dict) else {}
    docs = data.get("docsLocale")
    docs = docs if isinstance(docs, dict) else {}

    if not repo and not docs:
        return {"primary": DEFAULT_PRIMARY, "supported": [DEFAULT_PRIMARY], "external": DEFAULT_PRIMARY}, warnings

    warnings.append(
        "legacy locale blocks found; mapped to language (edit .nebula-scaffold.json "
        "by hand to add a language block; bootstrap does not rewrite existing files)"
    )

    primary = repo.get("primary") or docs.get("primary")
    if valid_locale(primary):
        primary = primary.strip()
    else:
        if primary is not None:
            warnings.append(f"invalid locale primary {primary!r}; using {DEFAULT_PRIMARY}")
        primary = DEFAULT_PRIMARY

    docs_primary = docs.get("primary")
    if valid_locale(docs_primary) and docs_primary.strip() != primary:
        warnings.append(f"docsLocale.primary {docs_primary.strip()!r} ignored; language primary is {primary!r}")

    supported: list[str] = []
    for block in (repo, docs):
        raw_supported = block.get("supported")
        if isinstance(raw_supported, list):
            for locale in raw_supported:
                if valid_locale(locale):
                    if locale.strip() not in supported:
                        supported.append(locale.strip())
                else:
                    warnings.append(f"ignoring invalid supported locale {locale!r}")
        elif raw_supported is not None:
            warnings.append("supported locales are not a list; ignoring the entry")
    if not supported:
        supported = [primary]
    if primary not in supported:
        warnings.append("primary is not in supported; adding it first")

    external = docs.get("external") or docs.get("primary")
    if not valid_locale(external) or external.strip() not in supported:
        if external is not None:
            warnings.append(f"invalid docsLocale.external {external!r}; using {primary}")
        external = primary
    else:
        external = external.strip()

    changelog = docs.get("changelog")
    if valid_locale(changelog) and changelog.strip() != external:
        warnings.append(f"docsLocale.changelog {changelog.strip()!r} ignored; release notes follow external {external!r}")

    if "prLocale" in data:
        warnings.append("prLocale is ignored; PR templates follow the primary language")

    return {"primary": primary, "supported": _ordered(primary, supported), "external": external}, warnings


def resolve_language(root: Path) -> tuple[dict, list[str]]:
    """Return the normalized language configuration plus fallback warnings."""
    warnings: list[str] = []
    data = _read_scaffold(root, warnings)
    raw = data.get("language")
    if raw is not None:
        try:
            language = validate_language(raw)
        except ValueError as exc:
            warnings.append(f"invalid language block: {exc}; falling back to legacy/defaults")
            return _legacy_language(data, warnings)
        if "prLocale" in data:
            warnings.append("prLocale is ignored; PR templates follow the primary language")
        if "repoLocale" in data or "docsLocale" in data:
            warnings.append("legacy locale fields present; language block takes precedence")
        return language, warnings
    return _legacy_language(data, warnings)


def translation_locales(language: dict) -> list[str]:
    """Supported locales that need a translated copy."""
    return [locale for locale in language["supported"] if locale != language["primary"]]


# A documents repository keeps one source file per document and one
# `<stem>.<locale>.md` per other supported language. The two rules below are the
# single definition of "this file is a translation" and "this directory is not a
# document" shared by `nebula doctor`, `nebula schema --apply` and
# `tools/check_docs_i18n.py`; when they disagree, one tool reports what the
# other refuses to fix.
MIRROR_RE = re.compile(r"\.(?P<locale>[a-z]{2}(?:-[A-Z]{2})?)\.md$")
SKIP_PARTS = {
    ".git",
    ".tmp",
    "__pycache__",
    "dist",
    "build",
    "node_modules",
    ".batch",
    ".agents",
    ".claude",
    ".codex",
    ".cursor",
    ".dsh",
    ".gemini",
    ".workbuddy",
    ".codebuddy",
    ".windsurf",
}


def mirror_locale(name: str) -> str | None:
    """Return the locale of a translated file name, or None for a source file."""
    match = MIRROR_RE.search(name)
    return match.group("locale") if match else None


def is_mirror(path: Path) -> bool:
    """True when `path` is a `<stem>.<locale>.md` translation, whatever the locale."""
    return mirror_locale(path.name) is not None


def is_skipped(path: Path) -> bool:
    """True when any directory above `path` is not part of the documented tree."""
    return bool(SKIP_PARTS & set(path.parts))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="resolve language from .nebula-scaffold.json")
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--field", choices=FIELDS)
    args = parser.parse_args(argv)

    language, warnings = resolve_language(args.root)
    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)

    if args.field:
        value = language[args.field]
        print(",".join(value) if isinstance(value, list) else value)
    else:
        print(json.dumps(language, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
