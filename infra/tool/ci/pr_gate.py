#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Keep the dual path honest: every pull request names its batch or its reason.

A pull request says which batch it serves, in `## Self-check`:

    - Batch: B7

or that it is a direct pull request, with a reason:

    - Batch: none — hotfix for the login loop

A push to `main` has no body to read, so the body check is skipped there; the
commit message carries the same line and `batch.py commit lint` checks it.

Usage:
    python tools/ci/pr_gate.py --base origin/main --body pr-body.md
    python tools/ci/pr_gate.py --event push
"""

from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import json
import os
import re
import subprocess
import sys
from pathlib import Path

BATCH_LINE = re.compile(
    r"^[-*]\s*Batch:" + r"\s*(?P<value>B[0-9]+[a-z]?|none)\s*(?:[—-]\s*(?P<reason>.+?))?\s*$",
    re.IGNORECASE | re.MULTILINE,
)


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
    return proc.stdout if proc.returncode == 0 else ""


def changed_files(root: Path, base: str | None) -> list[str]:
    if base:
        for rev in (f"{base}...HEAD", base):
            out = git(root, "diff", "--name-only", rev)
            if out.strip():
                return [line.strip() for line in out.splitlines() if line.strip()]
        # A base that only exists locally still yields a diff against HEAD.
        out = git(root, "diff", "--name-only", base)
        if out.strip():
            return [line.strip() for line in out.splitlines() if line.strip()]
    out = git(root, "show", "--name-only", "--pretty=format:", "HEAD")
    return [line.strip() for line in out.splitlines() if line.strip()]


def runtime_hits(scaffold: dict, changed: list[str]) -> list[tuple[str, str]]:
    """Return (component, file) for every changed runtime file."""
    hits: list[tuple[str, str]] = []
    for component in scaffold.get("components", []) or []:
        name = str(component.get("name") or "")
        patterns = [str(item) for item in component.get("runtime_paths") or []]
        for pattern in patterns:
            for path in changed:
                if fnmatch.fnmatch(path, pattern):
                    hits.append((name, path))
    return hits


def read_body(path: str | None) -> str:
    if not path or path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def batch_line(body: str) -> tuple[str, str] | None:
    match = BATCH_LINE.search(body)
    if not match:
        return None
    return match.group("value"), (match.group("reason") or "").strip()


def docs_repo(root: Path, scaffold: dict) -> Path | None:
    name = str(scaffold.get("project") or root.name)
    sibling = root.parent / f"{name}-docs"
    return sibling if sibling.is_dir() else None


def record_direct_pr(docs: Path, title: str, reason: str, number: str) -> None:
    target = docs / "records" / "live" / "direct-prs.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    today = dt.date.today().isoformat()
    row = f"| {today} | #{number or '-'} | {title or '(untitled)'} | {reason} |\n"
    if not target.is_file():
        target.write_text(
            "# Direct pull requests\n\n"
            "A pull request that is not a batch and touches runtime files. "
            "The reason comes from its `Self-check` line.\n\n"
            "| Date | PR | Title | Reason |\n|---|---|---|---|\n" + row,
            encoding="utf-8",
        )
        return
    text = target.read_text(encoding="utf-8")
    if row in text:
        return
    target.write_text(text + row, encoding="utf-8")


def sdp_batch_ids(path: Path) -> set[str] | None:
    """Read the '| Batch |' table; None when the SDP or its table is absent."""
    if not path.is_file():
        return None
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    start = next(
        (
            index
            for index, line in enumerate(lines)
            if line.strip().startswith("| Batch |")
        ),
        None,
    )
    if start is None:
        return None
    ids: set[str] = set()
    for line in lines[start + 1 :]:
        if not line.strip().startswith("|"):
            break
        cells = [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]
        if cells and re.fullmatch(r"B[0-9]+[a-z]?", cells[0]):
            ids.add(cells[0])
    return ids


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check the batch line of a PR.")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--base", default=None, help="base ref to diff against")
    parser.add_argument("--body", default=None, help="PR body file, or - for stdin")
    parser.add_argument("--event", default=None, help="push or pull_request")
    parser.add_argument("--title", default="", help="PR title, for the record")
    parser.add_argument("--number", default="", help="PR number, for the record")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    scaffold = read_scaffold(root)
    event = (args.event or os.environ.get("GITHUB_EVENT_NAME") or "pull_request").strip()
    changed = changed_files(root, args.base)
    hits = runtime_hits(scaffold, changed)
    print(f"pr_gate: {len(hits)} runtime file(s) changed")
    if event == "push":
        print("pr_gate: push has no body; the body check does not apply")
        return 0
    body = read_body(args.body)
    found = batch_line(body)
    if found is None:
        print(
            "pr_gate: `## Self-check` has no `- Batch:` line; "
            "write `- Batch: B<n>` or `- Batch: none — <reason>`",
            file=sys.stderr,
        )
        return 1
    value, reason = found
    if value.lower() == "none":
        if not reason:
            print(
                "pr_gate: `- Batch: none` needs a reason after the dash",
                file=sys.stderr,
            )
            return 1
        docs = docs_repo(root, scaffold)
        if docs is not None:
            record_direct_pr(docs, args.title, reason, args.number)
        print(f"pr_gate: direct pull request — {reason}")
        return 0
    if not re.fullmatch(r"B[0-9]+[a-z]?", value):
        print(f"pr_gate: not a batch id: {value!r}", file=sys.stderr)
        return 1
    docs = docs_repo(root, scaffold)
    if docs is not None:
        ids = sdp_batch_ids(docs / "process" / "sdp.md")
        if ids is not None and value not in ids:
            print(f"pr_gate: batch {value} is not in process/sdp.md", file=sys.stderr)
            return 1
    print(f"pr_gate: batch {value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
