#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify a deployed release and record the production run."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import date, datetime, timezone
from pathlib import Path

TOOL_VERSION = "0.4.0"
SECTIONS = ("Scope", "Version", "Scenarios", "Sign-off")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def evidence_dir(docs_root: Path, version: str, day: str) -> Path:
    return docs_root / "records" / f"{day[:7]}-release-{version}"


def run_check(root: Path, command: str, timeout: int) -> dict:
    started = time.monotonic()
    try:
        proc = subprocess.run(
            command,
            shell=True,
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        code = proc.returncode
        output = (proc.stdout or proc.stderr).strip().splitlines()[-3:]
    except subprocess.TimeoutExpired:
        code = 124
        output = ["timed out"]
    return {
        "command": command,
        "exit": code,
        "seconds": round(time.monotonic() - started, 3),
        "output": " / ".join(line.strip() for line in output if line.strip()),
    }


def deploy_markdown(version: str, record: dict) -> str:
    lines = [
        "# Deploy verification",
        "",
        f"- Version: {version}",
        f"- Target: {record['target']}",
        f"- Checked: {record['checked_at']}",
        f"- Status: {record['status']}",
        "",
        "## Checks",
        "",
        "| check | exit | seconds | output |",
        "| --- | --- | --- | --- |",
    ]
    for item in record["checks"]:
        output = str(item.get("output") or "").replace("|", "\\|")
        lines.append(f"| {item['command']} | {item['exit']} | {item['seconds']} | {output} |")
    return "\n".join(lines) + "\n"


def production_markdown(version: str, deploy: Path | None) -> str:
    evidence = deploy.as_posix() if deploy is not None else "TBD"
    return f"""# Release {version} \u2014 Production run record

## Scope

<!-- what was exercised in production, and what was left out -->

## Version

- Version: {version}
- Deploy evidence: {evidence}

## Environment

<!-- target, region, data set, access mode -->

## Window

- Start: TBD
- End: TBD

## Scenarios

| # | Scenario | Requirement | Result | Evidence |
|---|---|---|---|---|
| 1 | TBD | REQ-1 | TBD | TBD |

## Incidents

<!-- none, or what happened and how it was handled -->

## Sign-off

- By: TBD
- Date: TBD
- Result: TBD
"""


def production_problems(text: str) -> list[str]:
    sections: dict[str, list[str]] = {}
    current = ""
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("## "):
            current = stripped[3:].strip()
            sections[current] = []
        elif current:
            sections[current].append(line)
    problems: list[str] = []
    for name in SECTIONS:
        if name not in sections:
            problems.append(f"missing section: ## {name}")
            continue
        body = "\n".join(sections[name]).strip()
        if not body or body.startswith("<!--"):
            problems.append(f"empty section: ## {name}")
    signoff = "\n".join(sections.get("Sign-off", []))
    for field in ("By:", "Date:", "Result:"):
        line = next(
            (row for row in signoff.splitlines() if row.strip().lstrip("-* ").startswith(field)),
            "",
        )
        value = line.split(":", 1)[-1].strip() if line else ""
        if not value or value == "TBD":
            problems.append(f"sign-off {field} is not filled")
    return problems


def cmd_verify(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    docs = args.docs_root.resolve()
    if not docs.is_dir():
        print(f"docs repo not found: {docs}", file=sys.stderr)
        return 2
    if not args.checks:
        print("no checks; pass --command (repeatable)", file=sys.stderr)
        return 2
    checks = [run_check(root, command, args.timeout) for command in args.checks]
    failed = [item for item in checks if item["exit"] != 0]
    record = {
        "version": args.version,
        "target": args.target,
        "checked_at": utc_now(),
        "status": "failed" if failed else "passed",
        "checks": checks,
    }
    directory = evidence_dir(docs, args.version, args.date)
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "deploy-verify.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    (directory / "deploy-verify.md").write_text(
        deploy_markdown(args.version, record), encoding="utf-8", newline="\n"
    )
    for item in failed:
        print(f"verify: check failed ({item['exit']}): {item['command']}", file=sys.stderr)
    print(
        f"verify: {args.version} at {args.target} "
        f"{'failed' if failed else 'passed'} {len(checks)} check(s); wrote {directory.as_posix()}"
    )
    return 1 if failed else 0


def cmd_prod_run(args: argparse.Namespace) -> int:
    docs = args.docs_root.resolve()
    if not docs.is_dir():
        print(f"docs repo not found: {docs}", file=sys.stderr)
        return 2
    directory = evidence_dir(docs, args.version, args.date)
    target = Path(args.out) if args.out else directory / "production-run.md"
    if args.mark:
        if not target.is_file():
            print(f"record not found: {target}", file=sys.stderr)
            return 2
        problems = production_problems(target.read_text(encoding="utf-8"))
        for problem in problems:
            print(problem, file=sys.stderr)
        if problems:
            print(f"production run lint: {len(problems)} problem(s)")
            return 1
        print(f"production run ok: {target.as_posix()}")
        return 0
    if target.exists() and not args.force:
        print(f"{target} exists; pass --force to overwrite", file=sys.stderr)
        return 1
    deploy = directory / "deploy-verify.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        production_markdown(args.version, deploy if deploy.is_file() else None),
        encoding="utf-8",
        newline="\n",
    )
    print(f"drafted {target.as_posix()}")
    print("fill the remaining fields, then run: deploy.py prod-run --mark")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="verify a deployed release")
    parser.add_argument("--tool-version", action="store_true", help="print the tool version and exit")
    sub = parser.add_subparsers(dest="action")
    verify = sub.add_parser("verify", help="run smoke checks and record the live result")
    verify.add_argument("--root", type=Path, default=Path("."))
    verify.add_argument("--docs-root", type=Path, required=True)
    verify.add_argument("--version", required=True)
    verify.add_argument("--target", required=True)
    verify.add_argument("--command", action="append", default=[], dest="checks")
    verify.add_argument("--timeout", type=int, default=120)
    verify.add_argument("--date", default=date.today().isoformat())
    verify.set_defaults(func=cmd_verify)
    run = sub.add_parser("prod-run", help="draft or mark the production run record")
    run.add_argument("--docs-root", type=Path, required=True)
    run.add_argument("--version", required=True)
    run.add_argument("--out", type=Path)
    run.add_argument("--mark", action="store_true")
    run.add_argument("--force", action="store_true")
    run.add_argument("--date", default=date.today().isoformat())
    run.set_defaults(func=cmd_prod_run)
    args = parser.parse_args(argv)
    if args.tool_version:
        print(TOOL_VERSION)
        return 0
    if not hasattr(args, "func"):
        parser.print_help()
        return 2
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
