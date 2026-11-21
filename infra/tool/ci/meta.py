#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Run the gate this repository installed, with the base this event carries.

The workflow file does not know which gate a project uses: a full-workflow
project has `infra/tool/batch/batch.py`, a light or none project has
`tools/gate/gate.py`. This dispatcher reads `.nebula-scaffold.json`, picks the
gate, decides the base ref, and forwards the exit code.

Usage:
    python tools/ci/meta.py
    python tools/ci/meta.py --base origin/main
    python tools/ci/meta.py --print
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

BATCH_REL = Path("infra") / "tool" / "batch" / "batch.py"
GATE_REL = Path("tools") / "gate" / "gate.py"


def read_scaffold(root: Path) -> dict:
    path = root / ".nebula-scaffold.json"
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def git(root: Path, *args: str) -> str:
    try:
        proc = subprocess.run(
            ["git", *args], cwd=root, capture_output=True, text=True
        )
    except OSError:
        return ""
    return proc.stdout.strip() if proc.returncode == 0 else ""


def resolve_base(root: Path, explicit: str | None) -> tuple[str | None, str]:
    """Return (base, why). A push has no base ref, so fall back to HEAD~1."""
    if explicit:
        return explicit, "flag"
    event_base = os.environ.get("GITHUB_BASE_REF", "").strip()
    if event_base:
        return f"origin/{event_base}", "pull request"
    head = git(root, "rev-parse", "--verify", "HEAD")
    previous = git(root, "rev-parse", "--verify", "HEAD~1")
    if head and previous:
        return previous, "push (HEAD~1)"
    return None, "first commit"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Dispatch the repository gate.")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--base", default=None, help="base ref to diff against")
    parser.add_argument("--print", dest="show", action="store_true",
                        help="print the command instead of running it")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    if not root.is_dir():
        print(f"meta: not a directory: {root}", file=sys.stderr)
        return 2
    scaffold = read_scaffold(root)
    workflow = str(scaffold.get("workflow") or "full")
    base, why = resolve_base(root, args.base)

    if workflow == "full":
        script, command = root / BATCH_REL, None
        if script.is_file() and base:
            command = [sys.executable, "-B", str(script), "--root", str(root),
                       "commit", "lint", "--base", base]
        elif script.is_file():
            print("meta: no base to compare; commit lint skipped", file=sys.stderr)
            return 0
    else:
        script = root / GATE_REL
        if script.is_file():
            command = [sys.executable, "-B", str(script), "--root", str(root)]
            if base:
                command.extend(["--base", base])
        elif not (root / BATCH_REL).is_file():
            print(f"meta: no gate installed for workflow {workflow}", file=sys.stderr)
            return 0
        else:
            command = [sys.executable, "-B", str(root / BATCH_REL), "--root", str(root),
                       "commit", "lint"]
            if base:
                command.extend(["--base", base])

    if not command:
        print(f"meta: workflow {workflow} has no gate at {script.relative_to(root)}",
              file=sys.stderr)
        return 2
    print(f"meta: workflow={workflow} base={base or '-'} ({why})")
    print("meta: " + " ".join(command))
    if args.show:
        return 0
    proc = subprocess.run(command, cwd=root)
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
