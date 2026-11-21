#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Run the commands a project recorded in its batch config.

`checks` are the fast layer: the same commands run locally and in CI.
`release_checks` are the slow layer: they run only before a release, which is
what a tag push in CI is. Both come from the stack's `execution.yaml` and are
copied into `infra/tool/batch/config.json` by bootstrap.

Usage:
    python tools/ci/checks.py                 # the fast layer
    python tools/ci/checks.py --release       # the slow layer
    python tools/ci/checks.py --list
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

CONFIG_REL = Path("infra") / "tool" / "batch" / "config.json"


def load(root: Path) -> dict:
    path = root / CONFIG_REL
    if not path.is_file():
        print(f"checks: no {CONFIG_REL.as_posix()}", file=sys.stderr)
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"checks: {CONFIG_REL.as_posix()}: {exc}", file=sys.stderr)
        return {}


def commands(config: dict, release: bool) -> list[dict]:
    key = "release_checks" if release else "checks"
    found = config.get(key) or []
    return [item for item in found if isinstance(item, dict)]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run the project's checks.")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--release", action="store_true", help="run release_checks")
    parser.add_argument("--list", dest="show", action="store_true")
    parser.add_argument("--keep-going", action="store_true")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    config = load(root)
    if not config:
        return 2
    selected = commands(config, args.release)
    tier = "release_checks" if args.release else "checks"
    if not selected:
        if args.release:
            print(
                "checks: release_checks is empty; declare one in the stack's "
                "execution.yaml or drop the release job",
                file=sys.stderr,
            )
            return 1
        print(f"checks: {tier} is empty")
        return 0
    failed = 0
    for item in selected:
        name = str(item.get("name") or "?")
        command = item.get("command") or []
        if not isinstance(command, list) or not command:
            print(f"checks: {name}: empty command", file=sys.stderr)
            return 2
        cwd = root / str(item.get("cwd") or ".")
        print(f"checks: {name}: {' '.join(str(part) for part in command)}")
        if args.show:
            continue
        proc = subprocess.run([str(part) for part in command], cwd=cwd)
        if proc.returncode != 0:
            failed += 1
            print(f"checks: {name}: exit {proc.returncode}", file=sys.stderr)
            if not args.keep_going:
                return proc.returncode or 1
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
