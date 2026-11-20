"""Per-section PR body renderer wired through body.yaml `render` hooks.

Mechanical facts come from .batch/<id>/card.json and .batch/<id>/state.json;
judgement prose comes from .batch/<id>/pr-notes.md, a local (never committed)
file with fixed `## <slot>` headings:

  ## environment      one line: OS + toolchain versions
  ## problem          paragraph: the problem before this batch
  ## change           paragraph: what this batch does about it
  ## user-impact      bullet list: the user-visible effect
  ## test-design      one paragraph: what the tests pin
  ## not-verified     bullet list: explicitly out of scope this batch
  ## risks            bullet list: judgement risks (tool-recorded risks are appended)
  ## self-check       the scope qualifier after the batch line; the three
                      Self-check lines themselves are fixed and not a slot

Missing slots fall back to the built-in mechanical rendering, so a batch can
ship a plain prepared body before its notes are written.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

SLOTS = (
    "environment",
    "problem",
    "change",
    "user-impact",
    "test-design",
    "not-verified",
    "risks",
    "self-check",
)


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_notes(path: Path) -> dict[str, list[str]]:
    """Split pr-notes.md into slots keyed by their `## <slot>` heading."""
    if not path.exists():
        return {}
    slots: dict[str, list[str]] = {}
    current: str | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if line.startswith("## "):
            name = line[3:].strip()
            current = name if name in SLOTS else None
            if current:
                slots.setdefault(current, [])
            continue
        if current is not None:
            slots[current].append(line)
    for name, lines in slots.items():
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
    return {k: v for k, v in slots.items() if v}


def changed_files(root: Path, base: str) -> list[str]:
    proc = subprocess.run(
        ["git", "diff", "--name-only", base, "HEAD"],
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proc.returncode != 0:
        return []
    return [line for line in proc.stdout.splitlines() if line.strip()]


def check_commands(root: Path) -> dict[str, list[str]]:
    """Map check id -> configured command from infra/tool/batch/config.json."""
    path = root / "infra/tool/batch/config.json"
    if not path.exists():
        return {}
    try:
        config = read_json(path)
    except (OSError, json.JSONDecodeError):
        return {}
    return {
        str(item.get("name")): _display_command(item.get("command", []))
        for item in config.get("checks", [])
    }


def _display_command(parts: list) -> list[str]:
    """Strip the Windows `cmd /c` wrapper so the PR shows the real command."""
    command = [str(part) for part in parts]
    if command[:2] == ["cmd", "/c"]:
        command = command[2:]
    return command


def bulletize(lines: list[str]) -> list[str]:
    return [f"- {line.lstrip('- ').strip()}" for line in lines if line.strip()]


def paragraph(lines: list[str]) -> list[str]:
    return [line for line in lines if line.strip()]


def render_summary(batch_id: str, card: dict, state: dict, notes: dict) -> list[str]:
    out: list[str] = []
    out.extend(paragraph(notes.get("problem", [])))
    out.extend(paragraph(notes.get("change", [])))
    if out:
        return out
    return [
        f"Batch `{batch_id}`: {card.get('goal', '')}",
        "",
        f"- Branch: `{state.get('branch', '')}`",
        f"- Base: `{state.get('base_ref') or state.get('base', '')}`",
    ]


def render_impact(card: dict, state: dict, notes: dict, root: Path) -> list[str]:
    out: list[str] = bulletize(notes.get("user-impact", []))
    base = str(state.get("scope_base") or state.get("base", ""))
    files = changed_files(root, base)
    if not files:
        files = [str(item) for item in card.get("allowed", [])]
    out.append("")
    out.append("Files:")
    out.extend(f"- `{item}`" for item in files)
    return out


def render_verification(card: dict, state: dict, notes: dict, root: Path) -> list[str]:
    out: list[str] = []
    env = paragraph(notes.get("environment", []))
    if env:
        out.extend(env)
        out.append("")
    out.append("```")
    commands = check_commands(root)
    for name, item in (state.get("checks") or {}).items():
        command = commands.get(name)
        label = " ".join(command) if command else name
        out.append(f"{label}  # {item.get('status', 'unknown')}")
    out.append("```")
    out.append("")
    design = paragraph(notes.get("test-design", []))
    if design:
        out.extend(design)
        out.append("")
    not_verified = bulletize(notes.get("not-verified", []))
    if not_verified:
        out.append("Not verified:")
        out.extend(not_verified)
    return out


def render_risks(state: dict, notes: dict) -> list[str]:
    out = bulletize(notes.get("risks", []))
    scope = state.get("scope") or {}
    added = int(scope.get("added") or 0)
    deleted = int(scope.get("deleted") or 0)
    budget = int(scope.get("budget") or 0)
    if budget and added + deleted > budget:
        override = state.get("budget_override") or {}
        reason = f" — override: {override.get('reason', '')}" if override else ""
        out.append(
            f"- budget: {added + deleted} changed lines exceeds {budget}{reason}"
        )
    if int(scope.get("binary") or 0):
        out.append(f"- binary files: {scope.get('binary')} (diff is not reviewable)")
    return out or ["- None recorded by the gate."]


def render_self_check(batch_id: str, notes: dict) -> list[str]:
    """The fixed three-line Self-check shape.

    The first line names the batch and, when the pr-notes `## self-check`
    slot exists, carries the scope qualifier after an em dash; further slot
    lines continue the batch line hard-wrapped. Without the slot the line
    falls back to the bare `- Batch: <id>`, which still names the batch.
    """
    scope = paragraph(notes.get("self-check", []))
    out = [f"- Batch: {batch_id} — {scope[0]}"] if scope else [
        f"- Batch: {batch_id}"
    ]
    out.extend(f"  {line}" for line in scope[1:])
    out.extend(
        [
            "- Commit bodies carry Why: and Batch:: yes, checked by batch.py",
            "- No secret or build output is committed: checked by batch.py",
        ]
    )
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", required=True)
    parser.add_argument("--section", required=True)
    args = parser.parse_args()

    root = Path.cwd()
    batch_dir = root / ".batch" / args.batch
    card = read_json(batch_dir / "card.json")
    state = read_json(batch_dir / "state.json")
    notes = parse_notes(batch_dir / "pr-notes.md")

    renderers = {
        "summary": lambda: render_summary(args.batch, card, state, notes),
        "impact": lambda: render_impact(card, state, notes, root),
        "verification": lambda: render_verification(card, state, notes, root),
        "risks": lambda: render_risks(state, notes),
        "self_check": lambda: render_self_check(args.batch, notes),
    }
    if args.section not in renderers:
        print(f"unknown section: {args.section}", file=sys.stderr)
        return 2
    print("\n".join(renderers[args.section]()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
