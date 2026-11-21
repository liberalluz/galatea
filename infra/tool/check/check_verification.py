#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validate SRS -> STP test mapping."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REQ_RE = re.compile(r"\bREQ-\d{3}\b")
TC_RE = re.compile(r"^TC-[A-Z0-9-]+$")


def reqs(path: Path) -> list[str]:
    found = REQ_RE.findall(path.read_text(encoding="utf-8", errors="replace"))
    return list(dict.fromkeys(found))


def tests(path: Path) -> list[list[str]]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    start = next((i for i, line in enumerate(lines) if line.strip().startswith("| Test |")), None)
    if start is None:
        return []
    rows: list[list[str]] = []
    for line in lines[start + 1:]:
        stripped = line.strip()
        if not stripped.startswith("|"):
            break
        if set(stripped) <= {"|", "-", ":", " "}:
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) >= 3:
            rows.append(cells)
    return rows


def check(
    srs: Path,
    stp: Path,
    *,
    gate: bool = False,
    min_coverage: float = 100.0,
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    required = reqs(srs)
    if not required:
        errors.append("SRS has no REQ-NNN")
    covered: set[str] = set()
    seen: set[str] = set()
    for row in tests(stp):
        ident = row[0].strip("` ")
        if ident != "TBD" and not TC_RE.match(ident):
            errors.append(f"bad test id: {row[0]}")
            continue
        if ident != "TBD":
            if ident in seen:
                errors.append(f"duplicate test: {ident}")
            seen.add(ident)
        if not row[2].strip():
            errors.append(f"{ident}: empty exit")
        elif row[2].strip().upper() == "TBD":
            message = f"{ident}: exit TBD"
            (errors if gate else warnings).append(message)
        for req in REQ_RE.findall(row[1]):
            covered.add(req)
    for req in required:
        if req not in covered:
            errors.append(f"{req}: no test mapping")
    for req in sorted(covered - set(required)):
        warnings.append(f"{req}: mapped but not in SRS")
    coverage = 100.0 * len(covered & set(required)) / len(required) if required else 0.0
    if gate and coverage < min_coverage:
        errors.append(f"coverage {coverage:.1f}% is below {min_coverage:.1f}%")
    return errors, warnings


def coverage(srs: Path, stp: Path) -> tuple[float, int, int]:
    required = set(reqs(srs))
    covered = {req for row in tests(stp) for req in REQ_RE.findall(row[1])}
    hit = len(required & covered)
    return (100.0 * hit / len(required) if required else 0.0), hit, len(required)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="check SRS -> STP mapping")
    parser.add_argument("srs", type=Path)
    parser.add_argument("stp", type=Path)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--gate", action="store_true", help="fail when coverage is below the minimum")
    parser.add_argument("--min-coverage", type=float, default=100.0)
    args = parser.parse_args(argv)
    for path in (args.srs, args.stp):
        if not path.is_file():
            print(f"not a file: {path}", file=sys.stderr)
            return 2
    errors, warnings = check(
        args.srs, args.stp, gate=args.gate, min_coverage=args.min_coverage
    )
    percent, hit, total = coverage(args.srs, args.stp)
    if args.json:
        print(
            json.dumps(
                {
                    "errors": errors,
                    "warnings": warnings,
                    "coverage": {"percent": round(percent, 1), "covered": hit, "required": total},
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        for item in warnings:
            print(f"[warn] {item}")
        for item in errors:
            print(f"[fail] {item}")
        print(f"\ncoverage: {percent:.1f}% ({hit}/{total})")
        print(f"{len(errors)} errors · {len(warnings)} warnings")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
