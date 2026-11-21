#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Write or verify one baseline hash manifest for controlled docs."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

from language import SCAFFOLD_NAME, resolve_language

SOURCE_STEMS = ("SRS", "SDD", "STP", "STD", "SCMP")
BASELINE_RE = re.compile(r"^BL-[0-9]+[a-z]?$")
MANIFEST_DIR = Path("docs") / "baselines"


def manifest_path(root: Path, baseline: str) -> Path:
    return root / MANIFEST_DIR / f"{baseline}.files.json"


def relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect(root: Path) -> tuple[dict[str, str], list[str], list[str]]:
    """Return controlled-file hashes, errors, and coverage warnings."""
    errors: list[str] = []
    warnings: list[str] = []
    controlled = root / "docs" / "specs" / "controlled"
    if not controlled.is_dir():
        return {}, [f"missing directory: {relative(controlled, root)}"], warnings

    files: dict[str, str] = {}
    for path in sorted(controlled.glob("*.md")):
        if path.is_file():
            files[relative(path, root)] = sha256(path)
    if not files:
        errors.append(f"no controlled docs in {relative(controlled, root)}")

    for name in expected_translations(root, files):
        warnings.append(f"missing translation: {name}")
    return files, errors, warnings


def expected_translations(root: Path, files: dict[str, str]) -> list[str]:
    """Return supported translations that do not exist yet."""
    path = root / SCAFFOLD_NAME
    if not path.is_file():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    if not isinstance(data, dict) or not any(
        key in data for key in ("language", "repoLocale", "docsLocale")
    ):
        return []
    language, _warnings = resolve_language(root)
    primary = language["primary"]
    supported = language["supported"]

    names: list[str] = []
    for stem in SOURCE_STEMS:
        source = f"docs/specs/controlled/{stem}.md"
        if source not in files:
            continue
        for target in supported:
            if target == primary:
                continue
            candidate = f"docs/specs/controlled/{stem}.{target}.md"
            if candidate not in files:
                names.append(candidate.rsplit("/", 1)[-1])
    return names


def read_manifest(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("manifest is not an object")
    if not isinstance(data.get("files"), dict):
        raise ValueError("manifest has no files object")
    return data


def check_manifest(root: Path, baseline: str, files: dict[str, str]) -> list[str]:
    path = manifest_path(root, baseline)
    if not path.is_file():
        return [f"missing baseline manifest: {relative(path, root)}"]
    try:
        data = read_manifest(path)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        return [f"cannot read {relative(path, root)}: {exc}"]

    errors: list[str] = []
    if data.get("baseline") != baseline:
        errors.append(
            f"manifest baseline is {data.get('baseline')!r}, expected {baseline!r}"
        )
    if data.get("algorithm") != "sha256":
        errors.append("manifest algorithm must be sha256")

    recorded = data["files"]
    for name in sorted(set(recorded) - set(files)):
        errors.append(f"file missing: {name}")
    for name in sorted(set(files) - set(recorded)):
        errors.append(f"file not in baseline: {name}")
    for name in sorted(set(files) & set(recorded)):
        if recorded[name] != files[name]:
            errors.append(f"hash changed: {name}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="write or check baseline hashes")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--baseline", required=True, help="e.g. BL-1")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--strict", action="store_true", help="treat gaps as failures")
    args = parser.parse_args(argv)

    if not args.root.is_dir():
        print(f"not a directory: {args.root}", file=sys.stderr)
        return 2
    if not BASELINE_RE.fullmatch(args.baseline):
        print(f"bad baseline id: {args.baseline}", file=sys.stderr)
        return 2

    files, errors, warnings = collect(args.root)
    if args.strict:
        errors = [*errors, *warnings]
        warnings = []

    if args.check:
        errors = [*errors, *check_manifest(args.root, args.baseline, files)]
    else:
        path = manifest_path(args.root, args.baseline)
        if path.exists():
            errors.append(f"refusing to overwrite frozen manifest: {relative(path, args.root)}")
        if not errors:
            payload = {
                "version": 1,
                "baseline": args.baseline,
                "algorithm": "sha256",
                "files": files,
            }
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            print(f"wrote {relative(path, args.root)}")

    for item in warnings:
        print(f"[warn] {item}")
    for item in errors:
        print(f"[fail] {item}")
    if args.write and not errors:
        print("next: add the manifest reference to docs/baselines.md")
    print(f"\n{len(errors)} errors · {len(warnings)} warnings")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
