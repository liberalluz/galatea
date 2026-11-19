#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Project-local batch execution skeleton.

The tool is deliberately stack-agnostic. It owns a small state machine:

    plan -> approve -> start -> check -> pr -> merge

Checks and PR provider commands come from ``infra/tool/batch/config.json``. The
defaults only do local work; a project can add its own commands without
changing this file.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import textwrap
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

ROOT = Path(__file__).resolve().parents[3]
STATE_DIR = ".batch"
CONFIG_REL = Path("infra") / "tool" / "batch" / "config.json"
SCAFFOLD_REL = Path(".nebula-scaffold.json")
DEFAULT_CONFIG: dict[str, Any] = {
    "base": "main",
    "branch_prefix": "batch/",
    "docs_root": "",
    "scope": {"ignore": [], "generated": []},
    "commit": {
        "types": [],
        "scopes": [],
        "body": [],
    },
    "checks": [],
    "release_checks": [],
    "pr_create": [],
    "pr_view": [],
    "translate": [],
    "merge": [],
}
ID_RE = re.compile(r"^(?:B[0-9]+[a-z]?|[0-9]{8}-[0-9a-f]{6})$")
GENERATED_LOCKFILES = (
    "*.lock",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "Cargo.lock",
    "poetry.lock",
    "composer.lock",
    "go.sum",
    "Gemfile.lock",
)
DATED_ID_RE = re.compile(r"^[0-9]{8}-[0-9a-f]{6}$")
CARD_ID_RE = re.compile(r"^B[0-9]+[a-z]?$")
CARD_MARKER_RE = re.compile(r"<!--\s*batch-card\s*:\s*v1\s*-->")
CARD_JSON_RE = re.compile(r"```json[ \t]*\r?\n(.*?)\r?\n```", re.DOTALL)
PLAN_MARKER_RE = re.compile(
    r"<!--\s*planned\s*:\s*(?P<id>[A-Za-z0-9-]+)\s+(?P<hash>[0-9a-f]{8,64})\s+(?P<day>\d{4}-\d{2}-\d{2})\s*-->"
)
CARD_TYPES = {"feat", "fix", "process", "docs"}
BUDGET_DEFAULTS = {"docs": 150, "fix": 200, "process": 200, "feat": 400}
DEFAULT_BUDGET = 400
COMMIT_TYPES = ("feat", "fix", "docs", "test", "refactor", "chore", "ci")
COMMIT_SUBJECT_RE = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?: (?P<subject>.+)$"
)
DOCS_PROCESS = "process"
DOCS_SDP = "sdp.md"
DOCS_BATCHES = "batches"
DOCS_RECORDS = "records"
RECORD_ID_RE = re.compile(r"(?<![A-Za-z0-9])B[0-9]+[a-z]?(?![A-Za-z0-9])")
ARCHIVE_DIR = "archive"
PAUSABLE_STATUSES = {"started", "checked", "check_failed"}
STAGE_SKILLS = {
    "nebula-project",
    "nebula-bootstrap",
    "nebula-requirements",
    "nebula-design",
    "nebula-verification",
    "nebula-planning",
    "nebula-delivery",
}
SKILL_ROOTS = (
    ".agents/skills",
    ".claude/skills",
    ".codex/skills",
    ".codebuddy/skills",
    ".workbuddy/skills",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_json(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def run_git(root: Path, args: Sequence[str]) -> tuple[int, str, str]:
    proc = subprocess.run(
        ["git", *args],
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def git_required(root: Path) -> None:
    code, _, err = run_git(root, ["rev-parse", "--show-toplevel"])
    if code != 0:
        raise SystemExit(f"not a git repository: {root} ({err})")


def resolve_commit(root: Path, ref: str) -> str:
    """Resolve a branch or tag to the commit it points at, or return ""."""
    code, out, _ = run_git(root, ["rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"])
    return out if code == 0 else ""


def budget_anchor(root: Path, base: str, base_ref: str | None) -> str:
    """Return the commit to diff against when counting scope and budget.

    ``base`` is the branch point recorded when the batch started. If main moved
    on afterwards and the branch was cut from the newer commit, diffing against
    the old base would count the other PR's lines again. Prefer the merge base
    with the current base branch, and fall back to the recorded commit.
    """
    head = resolve_commit(root, "HEAD")
    ref = resolve_commit(root, base_ref) if base_ref else ""
    if head and ref and ref != head:
        code, out, _ = run_git(root, ["merge-base", head, ref])
        if code == 0 and out:
            return out.splitlines()[0]
    if head:
        code, out, _ = run_git(root, ["merge-base", head, base])
        if code == 0 and out:
            return out.splitlines()[0]
    return base


def config_path(root: Path) -> Path:
    return root / CONFIG_REL


CHECK_ID_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
CHECK_SEVERITIES = ("error", "warn")


def normalize_checks(items: list[Any], tier: str) -> list[dict[str, Any]]:
    """Turn config.checks into ``{id, run, tier, severity, stage}`` entries.

    The older ``{name, command}`` shape is still accepted; ``run`` and ``id``
    take precedence when both spellings are present.
    """
    normalized: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise SystemExit(f"config.{tier}_checks[{index}] must be an object")
        check_id = str(item.get("id") or item.get("name") or "").strip()
        if not CHECK_ID_RE.fullmatch(check_id):
            raise SystemExit(
                f"config.{tier}_checks[{index}]: invalid check id {check_id!r}"
            )
        if check_id in seen:
            raise SystemExit(f"duplicate check id: {check_id}")
        seen.add(check_id)
        run = command_list(item.get("run") or item.get("command"))
        severity = str(item.get("severity", "error")).strip() or "error"
        if severity not in CHECK_SEVERITIES:
            raise SystemExit(f"check {check_id}: severity must be error or warn")
        entry = dict(item)
        entry["id"] = check_id
        entry["run"] = run
        entry["tier"] = tier
        entry["severity"] = severity
        entry["stage"] = int(item.get("stage", 5))
        normalized.append(entry)
    return normalized


def load_config(root: Path) -> dict[str, Any]:
    config = dict(DEFAULT_CONFIG)
    config["scope"] = dict(DEFAULT_CONFIG["scope"])
    config["commit"] = dict(DEFAULT_CONFIG["commit"])
    raw = load_json(config_path(root))
    if raw is not None:
        for key in DEFAULT_CONFIG:
            if key in raw:
                config[key] = raw[key]
    scope = config.get("scope")
    if not isinstance(scope, dict):
        raise SystemExit("config.scope must be an object")
    config["scope"] = dict(DEFAULT_CONFIG["scope"])
    for key in ("ignore", "generated"):
        value = scope.get(key, [])
        if not isinstance(value, list):
            raise SystemExit(f"config.scope.{key} must be a list")
        config["scope"][key] = [str(item) for item in value]
    if not isinstance(config.get("checks"), list):
        raise SystemExit("config.checks must be a list")
    if not isinstance(config.get("release_checks"), list):
        raise SystemExit("config.release_checks must be a list")
    config["checks"] = normalize_checks(config["checks"], "check")
    config["release_checks"] = normalize_checks(config["release_checks"], "release")
    commit = config.get("commit")
    if not isinstance(commit, dict):
        raise SystemExit("config.commit must be an object")
    for key in ("types", "scopes", "body"):
        value = commit.get(key, [])
        if not isinstance(value, list):
            raise SystemExit(f"config.commit.{key} must be a list")
    for key in ("pr_create", "pr_view", "translate", "merge"):
        value = config.get(key)
        if value and not isinstance(value, list):
            raise SystemExit(f"config.{key} must be a command array")
    return config


def scaffold_git(root: Path) -> dict[str, Any]:
    """Read the optional ``git`` preset written by bootstrap."""
    data = load_json(root / SCAFFOLD_REL) or {}
    block = data.get("git")
    return block if isinstance(block, dict) else {}


def scaffold_workflow(root: Path) -> str:
    """Read the level bootstrap fixed at install time (absent means full)."""
    data = load_json(root / SCAFFOLD_REL) or {}
    value = data.get("workflow") if isinstance(data, dict) else None
    return value if value in ("full", "light", "none") else "full"


def commit_rule(root: Path, config: dict[str, Any]) -> dict[str, Any]:
    """Merge ``config.commit`` over the scaffold preset.

    An empty rule means "not configured": nothing is checked.
    """
    preset = scaffold_git(root)
    own = config.get("commit") or {}
    types = [str(item) for item in (own.get("types") or preset.get("types") or [])]
    scopes = [str(item) for item in (own.get("scopes") or preset.get("scopes") or [])]
    body = [str(item) for item in (own.get("body") or preset.get("body") or [])]
    return {
        "types": types,
        "scopes": scopes,
        "body": body,
        "enabled": bool(types or scopes or body),
    }


def state_root(root: Path) -> Path:
    return root / STATE_DIR


def batch_dir(root: Path, batch_id: str) -> Path:
    return state_root(root) / batch_id


def active_id(root: Path) -> str | None:
    path = state_root(root) / "active"
    try:
        value = path.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return value or None


def clear_active(root: Path) -> None:
    path = state_root(root) / "active"
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def set_active(root: Path, batch_id: str) -> None:
    write_text(state_root(root) / "active", batch_id + "\n")


def current_branch(root: Path) -> str:
    code, out, _ = run_git(root, ["branch", "--show-current"])
    return out if code == 0 else ""


def branch_exists(root: Path, branch: str) -> bool:
    if not branch:
        return False
    code, _, _ = run_git(
        root, ["rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"]
    )
    return code == 0


def batch_branch_mismatch(root: Path, state: dict[str, Any], batch_id: str) -> str | None:
    """Explain why HEAD is not on the branch recorded when the batch started."""
    if state.get("branch_created") is not True:
        return None
    branch = str(state.get("branch") or "")
    if not branch:
        return None
    here = current_branch(root)
    if here == branch:
        return None
    return (
        f"batch {batch_id} is on branch {branch}, but HEAD is on "
        f"{here or 'a detached HEAD'}; run: git switch {branch}"
    )


def archive_aborted(root: Path, batch_id: str) -> bool:
    """Move an aborted batch aside so the same id can be planned again."""
    target = batch_dir(root, batch_id)
    state = load_json(target / "state.json") or {}
    if state.get("status") != "aborted":
        return False
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    archive = state_root(root) / ARCHIVE_DIR / f"{batch_id}-{stamp}"
    archive.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(target), str(archive))
    print(f"archived aborted batch {batch_id} to .batch/{ARCHIVE_DIR}/{archive.name}")
    return True


def resolve_id(root: Path, value: str | None) -> str:
    if value:
        if not ID_RE.fullmatch(value):
            raise SystemExit(f"invalid batch id: {value}")
        if not batch_dir(root, value).is_dir():
            raise SystemExit(f"batch not found: {value}")
        return value
    active = active_id(root)
    if active:
        return active
    if not state_root(root).is_dir():
        raise SystemExit("no batch found; run 'plan' first")
    candidates = sorted(
        (
            path.name
            for path in state_root(root).iterdir()
            if path.is_dir() and ID_RE.fullmatch(path.name)
        ),
        key=batch_sort_key,
    )
    if not candidates:
        raise SystemExit("no batch found; run 'plan' first")
    if len(candidates) > 1:
        raise SystemExit(
            f"multiple batches found ({', '.join(candidates)}); "
            "pass the batch id explicitly"
        )
    return candidates[0]


def batch_sort_key(value: str) -> tuple[int, int, str]:
    match = re.fullmatch(r"B([0-9]+)([a-z]?)", value)
    if match:
        return (0, int(match.group(1)), match.group(2))
    return (1, 0, value)


def branch_slug(value: str, limit: int = 40) -> str:
    """Turn a goal into a branch-name slug; empty when nothing ASCII is left."""
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:limit].strip("-")


def new_id(root: Path) -> str:
    prefix = datetime.now().strftime("%Y%m%d")
    for _ in range(50):
        candidate = f"{prefix}-{secrets.token_hex(3)}"
        if not batch_dir(root, candidate).exists():
            return candidate
    raise SystemExit("could not allocate a batch id")


def parse_list(values: list[str] | None, default: list[str]) -> list[str]:
    out: list[str] = []
    for value in values or []:
        for item in value.replace(";", ",").split(","):
            item = item.strip()
            if item and item not in out:
                out.append(item)
    return out or default


def card_hash(card: dict[str, Any]) -> str:
    canonical = json.dumps(card, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def read_card(root: Path, batch_id: str) -> dict[str, Any]:
    card = load_json(batch_dir(root, batch_id) / "card.json")
    if card is None:
        raise SystemExit(f"card not found: {batch_id}")
    return card


def source_relative(root: Path, path: Path) -> str:
    return Path(os.path.relpath(path, root)).as_posix()


def inside_project(root: Path, path: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_card_hash(path: Path) -> str:
    """Hash a card source, ignoring the ``planned`` marker line."""
    text = path.read_text(encoding="utf-8", errors="replace")
    clean = PLAN_MARKER_RE.sub("", text).rstrip()
    return hashlib.sha256(clean.encode("utf-8")).hexdigest()


def source_hashes(path: Path) -> set[str]:
    raw = path.read_bytes()
    text = path.read_text(encoding="utf-8", errors="replace")
    clean = PLAN_MARKER_RE.sub("", text).rstrip()
    return {
        hashlib.sha256(raw).hexdigest(),
        hashlib.sha256(clean.encode("utf-8")).hexdigest(),
    }


def plan_marker_hash(path: Path, batch_id: str) -> str | None:
    try:
        text = path.read_text(encoding="utf-8")
    except (FileNotFoundError, UnicodeDecodeError):
        return None
    for match in PLAN_MARKER_RE.finditer(text):
        if match.group("id") == batch_id:
            return match.group("hash")
    return None


def write_plan_marker(path: Path, batch_id: str, digest: str, day: str) -> None:
    text = path.read_text(encoding="utf-8")
    text = PLAN_MARKER_RE.sub("", text).rstrip() + "\n"
    text += f"<!-- planned: {batch_id} {digest[:8]} {day} -->\n"
    path.write_text(text, encoding="utf-8", newline="\n")


def card_source_path(root: Path, card: dict[str, Any]) -> Path | None:
    source = card.get("source")
    if not source:
        return None
    return (root / str(source)).resolve()


def source_is_current(root: Path, card: dict[str, Any]) -> tuple[bool, str]:
    if card.get("legacy"):
        return False, "legacy card is read-only"
    path = card_source_path(root, card)
    if path is None:
        return True, ""
    if not path.is_file():
        return False, f"card source is missing: {card.get('source')}"
    expected = str(card.get("source_sha256", ""))
    if expected not in source_hashes(path):
        return False, "card source changed; re-plan and re-approve"
    return True, ""


def card_issues(
    card: dict[str, Any], path: Path | None = None, types: set[str] | None = None
) -> list[str]:
    """Return every schema problem in a card, not just the first one."""
    issues: list[str] = []

    def fail(message: str) -> None:
        issues.append(message)

    if not isinstance(card, dict):
        return ["card must be a JSON object"]
    if card.get("legacy"):
        return ["legacy cards cannot be planned from a card source"]
    required = (
        "id",
        "goal",
        "type",
        "base",
        "allowed",
        "acceptance",
        "changelog",
        "skills",
    )
    missing = [key for key in required if key not in card]
    if missing:
        fail(f"missing field(s): {', '.join(missing)}")

    card_id = card.get("id")
    if not isinstance(card_id, str) or not CARD_ID_RE.fullmatch(card_id):
        fail("id must be B followed by digits")
    elif path is not None and path.stem != card_id:
        fail(f"card id {card_id} does not match file stem {path.stem}")

    if not isinstance(card.get("goal"), str) or not card["goal"].strip():
        fail("goal must be a non-empty string")
    if "pr_title" in card:
        pr_title = card.get("pr_title")
        if not isinstance(pr_title, str) or not pr_title.strip():
            fail("pr_title must be a non-empty string")
        elif "\n" in pr_title or "\r" in pr_title:
            fail("pr_title must be a single line")
    allowed_types = types or CARD_TYPES
    if card.get("type") not in allowed_types:
        fail(f"type must be one of: {', '.join(sorted(allowed_types))}")
    base = card.get("base")
    if not isinstance(base, str) or not base.strip() or any(ch.isspace() for ch in base):
        fail("base must be a non-empty branch name")

    if "size_budget" in card:
        budget = card.get("size_budget")
        if type(budget) is not int or budget < 1:
            fail("size_budget must be an integer greater than zero")
    if "release" in card and not isinstance(card["release"], bool):
        fail("release must be a boolean")

    for key, allow_empty in (("allowed", False), ("forbidden", True)):
        if key not in card and key == "forbidden":
            continue
        value = card.get(key)
        if not isinstance(value, list) or (not allow_empty and not value):
            fail(f"{key} must be a non-empty array")
        elif not all(isinstance(item, str) and item.strip() for item in value):
            fail(f"{key} must contain non-empty strings")

    for key in ("requirements", "depends_on"):
        if key not in card:
            continue
        value = card.get(key)
        if not isinstance(value, list):
            fail(f"{key} must be an array")
        if not all(isinstance(item, str) and item.strip() for item in value):
            fail(f"{key} must contain non-empty strings")
    for key in ("acceptance", "changelog"):
        value = card.get(key)
        if not isinstance(value, list) or (key == "acceptance" and not value):
            fail(f"{key} must be a non-empty array")
        elif not all(isinstance(item, str) and item.strip() for item in value):
            fail(f"{key} must contain non-empty strings")

    skills = card.get("skills")
    if not isinstance(skills, list) or len(skills) > 2:
        fail(
            "skills must be an array with at most two entries; "
            "pick the ones this batch will actually open"
        )
    else:
        for item in skills:
            if not isinstance(item, dict):
                fail("each skill must be an object")
                continue
            skill_id = item.get("id")
            if not isinstance(skill_id, str) or not re.fullmatch(
                r"[a-z0-9][a-z0-9-]*", skill_id
            ):
                fail("skill id must be lower-case kebab-case")
            elif skill_id == "using-agent-skills":
                fail("using-agent-skills is never installable")
            elif skill_id in STAGE_SKILLS:
                fail(f"stage skill {skill_id} is not declared in a batch card")
            if not isinstance(item.get("required"), bool):
                fail(f"skill {skill_id}: required must be a boolean")
            reason = item.get("reason")
            if not isinstance(reason, str) or not reason.strip():
                fail(f"skill {skill_id}: reason must say why this batch needs it")
    return issues


def validate_planned_card(
    card: dict[str, Any], path: Path | None = None, types: set[str] | None = None
) -> None:
    issues = card_issues(card, path, types)
    if issues:
        raise ValueError("\n".join(issues))
    if "size_budget" not in card:
        card["size_budget"] = BUDGET_DEFAULTS.get(str(card.get("type")), DEFAULT_BUDGET)
        card["size_budget_default"] = True


def read_planned_card(
    path: Path, types: set[str] | None = None
) -> tuple[dict[str, Any], bytes]:
    data = path.read_bytes()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(f"card is not UTF-8: {exc}") from exc
    marker = CARD_MARKER_RE.search(text)
    if marker is None:
        raise ValueError("missing <!-- batch-card: v1 --> marker")
    block = CARD_JSON_RE.search(text, marker.end())
    if block is None:
        raise ValueError("missing fenced json block after the card marker")
    try:
        card = json.loads(block.group(1))
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid card JSON: {exc}") from exc
    validate_planned_card(card, path, types)
    return card, data


def docs_root_from_card(source: Path) -> Path | None:
    """Return the docs root for a card at ``<docs>/process/batches/B<n>.md``."""
    parent = source.parent
    if parent.name == DOCS_BATCHES and parent.parent.name == DOCS_PROCESS:
        return parent.parent.parent
    return None


def configured_docs_root(root: Path, config: dict[str, Any]) -> Path | None:
    value = str(config.get("docs_root", "") or "").strip()
    if not value:
        return None
    path = Path(value)
    return path if path.is_absolute() else root / path


def sdp_batch_ids(sdp: Path) -> set[str]:
    """Read the ``| Batch |`` table and return the ids it lists."""
    lines = sdp.read_text(encoding="utf-8", errors="replace").splitlines()
    start = next(
        (
            index
            for index, line in enumerate(lines)
            if line.strip().startswith("| Batch |")
        ),
        None,
    )
    if start is None:
        return set()
    ids: set[str] = set()
    for line in lines[start + 1:]:
        stripped = line.strip()
        if not stripped.startswith("|"):
            break
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if not cells:
            continue
        ident = cells[0].strip("` ")
        if CARD_ID_RE.fullmatch(ident):
            ids.add(ident)
    return ids


def docs_batch_ids(docs_root: Path, exclude: Path | None = None) -> dict[str, Path]:
    """Map every id already used in the docs repo to the path that uses it."""
    taken: dict[str, Path] = {}
    batches = docs_root / DOCS_PROCESS / DOCS_BATCHES
    if batches.is_dir():
        for path in sorted(batches.glob("B*.md")):
            match = re.fullmatch(r"(B[0-9]+[a-z]?)\.md", path.name)
            if match is None:
                continue
            if exclude is not None and path.resolve() == exclude:
                continue
            taken.setdefault(match.group(1), path)
    records = docs_root / DOCS_RECORDS
    if records.is_dir():
        for path in sorted(records.rglob("*")):
            match = RECORD_ID_RE.search(path.name)
            if match:
                taken.setdefault(match.group(0), path)
    return taken


def next_batch_id(ids: set[str]) -> str:
    highest = 0
    for value in ids:
        match = re.fullmatch(r"B([0-9]+)[a-z]?", value)
        if match:
            highest = max(highest, int(match.group(1)))
    return f"B{highest + 1}"


def duplicate_id_error(
    root: Path, card: dict[str, Any], config: dict[str, Any], batch_id: str
) -> str:
    """Return an error when another card or record already claims this id."""
    source = card_source_path(root, card)
    docs_root = configured_docs_root(root, config)
    if docs_root is None and source is not None:
        docs_root = docs_root_from_card(source)
    if docs_root is None or not docs_root.is_dir():
        return ""
    taken = docs_batch_ids(docs_root, exclude=source)
    if batch_id in taken:
        return f"batch id {batch_id} is already used by {taken[batch_id]}"
    return ""


REQUIREMENT_ROW_RE = re.compile(r"^\|\s*([A-Z][0-9]+)\s*\|", re.M)
EXITED = ("exited", "frozen")


def requirement_ids(docs_root: Path) -> set[str]:
    """Every requirement id named in the controlled specifications."""
    ids: set[str] = set()
    specs = docs_root / "docs" / "specs" / "controlled"
    if not specs.is_dir():
        return ids
    for path in sorted(specs.rglob("*.md")):
        ids.update(REQUIREMENT_ROW_RE.findall(path.read_text(encoding="utf-8")))
    return ids



WORK_UNIT_RE = re.compile(r"^AWU-[0-9]+$")


def work_units_on(docs_root: Path) -> bool:
    """True when CONTRACT.md turns the work units on."""
    contract = docs_root / "CONTRACT.md"
    if not contract.is_file():
        return False
    text = contract.read_text(encoding="utf-8", errors="replace").replace("\r\n", "\n")
    match = re.search(r"^work_units:" + r"\s*(\S+)", text, re.M)
    return match is not None and match.group(1).strip().lower() == "on"


def work_unit_problems(card: dict[str, Any], docs_root: Path) -> list[str]:
    """Check the unit a card names, when the project runs units."""
    unit = str(card.get("work_unit", "") or "").strip()
    if not unit or not docs_root.is_dir() or not work_units_on(docs_root):
        return []
    if not WORK_UNIT_RE.fullmatch(unit):
        return [f"work_unit {unit!r} is not of the form AWU-<n>"]
    if not (docs_root / "process" / "awu" / f"{unit}.md").is_file():
        return [f"work_unit {unit} has no file at process/awu/{unit}.md"]
    return []

def card_link_problems(
    root: Path, card: dict[str, Any], config: dict[str, Any], source: Path | None
) -> list[str]:
    """Check that the card's requirements exist and its dependencies have exited."""
    problems: list[str] = []
    docs_root = configured_docs_root(root, config)
    if docs_root is None and source is not None:
        docs_root = docs_root_from_card(source)

    wanted = card.get("requirements") or []
    if wanted and docs_root is not None and docs_root.is_dir():
        known = requirement_ids(docs_root)
        if known:
            for rid in wanted:
                if rid not in known:
                    problems.append(f"requirement {rid} is not in the controlled specifications")

    for dep in card.get("depends_on") or []:
        directory = batch_dir(root, dep)
        if not directory.is_dir():
            problems.append(f"depends on {dep}, which has no batch directory")
        state = load_json(directory / "state.json") or {}
        status = str(state.get("status", "planned"))
        if status not in EXITED:
            problems.append(f"depends on {dep}, which is {status}, not exited")

    if docs_root is not None:
        problems.extend(work_unit_problems(card, docs_root))

    return problems


def read_state(root: Path, batch_id: str) -> dict[str, Any]:
    state = load_json(batch_dir(root, batch_id) / "state.json")
    if state is None:
        raise SystemExit(f"batch not started: {batch_id}")
    return state


def glob_regex(pattern: str) -> re.Pattern[str]:
    i = 0
    out = ""
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        elif pattern[i] == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile("^" + out + "$")


def matches(path: str, patterns: Sequence[str]) -> bool:
    normalized = path.replace("\\", "/")
    return any(glob_regex(pattern).fullmatch(normalized) for pattern in patterns)


def changed_paths(root: Path, anchor: str, config: dict[str, Any]) -> list[str]:
    paths: set[str] = set()
    for args in (
        ["diff", "--name-only", anchor],
        ["ls-files", "--others", "--exclude-standard"],
    ):
        code, out, _ = run_git(root, args)
        if code != 0:
            continue
        paths.update(line.strip() for line in out.splitlines() if line.strip())

    ignored = list(DEFAULT_CONFIG["scope"]["ignore"])
    ignored.extend(DEFAULT_CONFIG["scope"]["generated"])
    ignored.extend(GENERATED_LOCKFILES)
    scope = config.get("scope")
    if isinstance(scope, dict):
        ignored.extend(str(item) for item in scope.get("ignore", []))
        ignored.extend(str(item) for item in scope.get("generated", []))
    ignored.extend([".batch/**", ".batch"])
    return sorted(
        path
        for path in paths
        if not matches(path, ignored) and path != ".batch"
    )


def check_scope(
    root: Path, card: dict[str, Any], anchor: str, config: dict[str, Any]
) -> tuple[list[str], list[str]]:
    allowed = [str(item) for item in card.get("allowed", [])] or ["**"]
    forbidden = [str(item) for item in card.get("forbidden", [])]
    changed = changed_paths(root, anchor, config)
    violations: list[str] = []
    for path in changed:
        if matches(path, forbidden):
            violations.append(f"forbidden: {path}")
        elif not matches(path, allowed):
            violations.append(f"out of scope: {path}")
    return changed, violations


def installed_skills(root: Path) -> list[str]:
    """Return the ids of skills installed under any agent root."""
    found: set[str] = set()
    for relative in SKILL_ROOTS:
        base = root / relative
        if not base.is_dir():
            continue
        for entry in base.iterdir():
            if entry.is_dir() and (entry / "SKILL.md").is_file():
                found.add(entry.name)
    return sorted(found)


def print_skill_suggestions(root: Path, card: dict[str, Any]) -> None:
    """Print at most two suggestions, or say why there are none."""
    mapping = load_skill_map(root)
    total = mapped_skills(card, mapping)
    if not total:
        print("no skills suggested: skill-map.yaml has no match for this batch")
        return
    suggestions = suggest_skills(
        card,
        mapping,
        installed=installed_skills(root),
        history=skill_history(root),
    )
    if not suggestions:
        names = sorted(
            {
                item
                for section in mapping.values()
                for items in section.values()
                for item in items
            }
        )
        print(
            "no skills suggested: the map matched "
            f"{total} skill(s) but none are installed in this project "
            f"({', '.join(names[:6])})"
        )
        return
    for skill_id, why in suggestions:
        print(f"suggested skill: {skill_id} ({why})")


def installed_skill(root: Path, skill_id: str) -> Path | None:
    for relative in SKILL_ROOTS:
        path = root / relative / skill_id / "SKILL.md"
        if path.is_file():
            return path
    return None


SKILL_MAP_REL = Path("infra") / "tool" / "batch" / "skill-map.yaml"


def load_skill_map(root: Path) -> dict[str, dict[str, list[str]]]:
    path = root / SKILL_MAP_REL
    if not path.is_file():
        return {}
    mapping: dict[str, dict[str, list[str]]] = {}
    section = ""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return {}
    for raw in lines:
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if not line.startswith(" ") and line.rstrip().endswith(":"):
            section = line.rstrip()[:-1].strip()
            mapping.setdefault(section, {})
            continue
        if not section or ":" not in line:
            continue
        key, value = line.split(":", 1)
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            value = value[1:-1]
        items = [item.strip() for item in value.split(",") if item.strip()]
        if items:
            mapping[section][key.strip()] = items
    return mapping


def skill_history(root: Path) -> dict[str, dict[str, int]]:
    """Count how often each skill was planned, per batch type."""
    history: dict[str, dict[str, int]] = {}
    batch_dir = root / ".batch"
    if not batch_dir.is_dir():
        return history
    for card_path in sorted(batch_dir.glob("*/card.json")):
        try:
            card = json.loads(card_path.read_text(encoding="utf-8"))
        except (OSError, ValueError, UnicodeDecodeError):
            continue
        if not isinstance(card, dict):
            continue
        card_type = str(card.get("type", "")) or "unknown"
        for item in card.get("skills", []) or []:
            skill_id = str(item.get("id", "")) if isinstance(item, dict) else str(item)
            if not skill_id:
                continue
            counts = history.setdefault(card_type, {})
            counts[skill_id] = counts.get(skill_id, 0) + 1
    for state_path in sorted(batch_dir.glob("*/state.json")):
        if state_path.with_name("card.json").is_file():
            continue
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
        except (OSError, ValueError, UnicodeDecodeError):
            continue
        card = state.get("card") if isinstance(state.get("card"), dict) else {}
        card_type = str(card.get("type", "")) or "unknown"
        for item in card.get("skills", []) or []:
            skill_id = str(item.get("id", "")) if isinstance(item, dict) else str(item)
            if not skill_id:
                continue
            counts = history.setdefault(card_type, {})
            counts[skill_id] = counts.get(skill_id, 0) + 1
    return history


def suggest_skills(
    card: dict[str, Any],
    mapping: dict[str, dict[str, list[str]]],
    *,
    installed: list[str] | None = None,
    history: dict[str, dict[str, int]] | None = None,
) -> list[tuple[str, str]]:
    """Pick at most two skills, preferring ones this project already used."""
    candidates: list[tuple[str, str]] = []

    def add(items: list[str], why: str) -> None:
        for item in items:
            if all(item != existing for existing, _ in candidates):
                candidates.append((item, why))

    card_type = str(card.get("type", ""))
    add(mapping.get("by_type", {}).get(card_type, []), f"type {card_type}")
    allowed = [str(entry) for entry in card.get("allowed", [])]
    for pattern, items in mapping.get("by_path", {}).items():
        prefix = pattern.rstrip("*")
        if any(entry.startswith(prefix) or pattern.startswith(entry.rstrip("*")) for entry in allowed):
            add(items, f"paths {pattern}")
    stage = str(card.get("stage", "")) or "verification"
    add(mapping.get("by_stage", {}).get(stage, []), f"stage {stage}")

    if installed is not None:
        allowed_ids = set(installed)
        candidates = [item for item in candidates if item[0] in allowed_ids]

    counts = (history or {}).get(card_type, {})
    ranked = sorted(
        candidates,
        key=lambda item: (-counts.get(item[0], 0), candidates.index(item)),
    )
    picked: list[tuple[str, str]] = []
    for skill_id, why in ranked[:2]:
        used = counts.get(skill_id, 0)
        if used:
            picked.append((skill_id, f"{why}; used in {used} {card_type} batch(es)"))
        else:
            picked.append((skill_id, why))
    return picked


def mapped_skills(card: dict[str, Any], mapping: dict[str, dict[str, list[str]]]) -> int:
    """How many skills the map would suggest before the installed filter."""
    return len(suggest_skills(card, mapping))


def skill_anchor(root: Path, skill_id: str) -> str:
    path = installed_skill(root, skill_id)
    if path is None:
        return ""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + 4 :]
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("## "):
            return stripped[3:][:60]
    for line in text.splitlines():
        if line.strip():
            return line.strip()[:60]
    return ""


def rule_in_skill(path: Path, rule: str) -> bool:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    return " ".join(rule.split()).lower() in " ".join(text.split()).lower()


def check_skills(root: Path, card: dict[str, Any]) -> tuple[list[str], dict[str, str]]:
    violations: list[str] = []
    found: dict[str, str] = {}
    for item in card.get("skills", []):
        skill_id = str(item.get("id", ""))
        path = installed_skill(root, skill_id)
        if path is None:
            violations.append(f"skill {skill_id}: not installed in this project")
        else:
            found[skill_id] = source_relative(root, path)
    return violations, found


SKILL_EVIDENCE_DIR = Path("evidence") / "skills"
SKILL_EVIDENCE_STATUSES = {"applied", "partial", "skipped"}
VAGUE_CHANGE = {
    "applied",
    "used",
    "read",
    "loaded",
    "yes",
    "no",
    "n/a",
    "na",
    "none",
    "-",
    "skill applied",
    "used the skill",
    "read the skill",
    "loaded the skill",
}


def skill_evidence_path(root: Path, batch_id: str, skill_id: str) -> Path:
    return batch_dir(root, batch_id) / SKILL_EVIDENCE_DIR / f"{skill_id}.md"


def read_skill_evidence(path: Path) -> dict[str, str]:
    fields: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return fields
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip().lower()] = value.strip()
    return fields


def proof_looks_like_path(proof: str) -> bool:
    if proof.startswith(("http://", "https://")):
        return False
    if not re.fullmatch(r"[A-Za-z0-9_./-]+(?::[0-9]+)?", proof):
        return False
    return "/" in proof or "." in proof


def check_skill_evidence(
    root: Path, batch_id: str, card: dict[str, Any]
) -> tuple[list[str], list[str], dict[str, dict[str, Any]]]:
    errors: list[str] = []
    warnings: list[str] = []
    records: dict[str, dict[str, Any]] = {}
    for item in card.get("skills", []):
        skill_id = str(item.get("id", ""))
        required = bool(item.get("required"))
        path = skill_evidence_path(root, batch_id, skill_id)
        relative = source_relative(root, path)
        if not path.is_file():
            if required:
                errors.append(
                    f"skill {skill_id}: missing evidence file {relative} "
                    "(status, changed, proof)"
                )
            continue
        fields = read_skill_evidence(path)
        status = fields.get("status", "").lower()
        changed = fields.get("changed", "")
        proof = fields.get("proof", "")
        if status not in SKILL_EVIDENCE_STATUSES:
            errors.append(
                f"skill {skill_id}: evidence status must be applied, partial, or skipped"
            )
        if not changed or changed.strip().lower() in VAGUE_CHANGE:
            errors.append(
                f"skill {skill_id}: 'changed' must say what changed, "
                "not repeat the status"
            )
        elif len(changed) < 12:
            warnings.append(f"skill {skill_id}: 'changed' is very short")
        if not proof:
            errors.append(f"skill {skill_id}: 'proof' is empty")
        elif proof_looks_like_path(proof):
            target = proof.split(":", 1)[0]
            if not (root / target).exists():
                errors.append(f"skill {skill_id}: proof path does not exist: {proof}")
        if required and status == "skipped":
            errors.append(f"skill {skill_id}: a required skill cannot be skipped")
        rule = fields.get("rule", "").strip()
        if required and not rule:
            errors.append(
                f"skill {skill_id}: evidence needs a 'rule' line quoting the skill "
                "text you followed"
            )
        elif rule:
            if len(rule.split()) < 6:
                errors.append(f"skill {skill_id}: 'rule' must quote at least six words")
            elif not rule_in_skill(installed_skill(root, skill_id) or Path("/nonexistent"), rule):
                errors.append(
                    f"skill {skill_id}: 'rule' is not in the skill text; quote it verbatim"
                )
        records[skill_id] = {
            "status": status,
            "changed": changed,
            "proof": proof,
            "rule": rule,
            "required": required,
            "file": relative,
        }
    return errors, warnings, records


def diff_stats(
    root: Path, anchor: str, changed: Sequence[str]
) -> tuple[int, int, int]:
    code, out, err = run_git(root, ["diff", "--numstat", "--no-renames", anchor])
    if code != 0:
        raise SystemExit(f"could not count batch diff: {err}")
    allowed = set(changed)
    added = 0
    deleted = 0
    binary = 0
    seen: set[str] = set()
    for line in out.splitlines():
        parts = line.split("\t", 2)
        if len(parts) != 3:
            continue
        raw_added, raw_deleted, path = parts
        path = path.replace("\\", "/")
        if path not in allowed:
            continue
        seen.add(path)
        if raw_added == "-" or raw_deleted == "-":
            binary += 1
            continue
        added += int(raw_added)
        deleted += int(raw_deleted)

    for path in changed:
        if path in seen:
            continue
        target = root / path
        if not target.is_file():
            continue
        data = target.read_bytes()
        if b"\0" in data:
            binary += 1
            continue
        added += data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)
    return added, deleted, binary


def check_budget(
    root: Path, card: dict[str, Any], anchor: str, changed: Sequence[str]
) -> tuple[int, int, int, str | None]:
    budget = card.get("size_budget")
    if type(budget) is not int or budget < 1:
        return 0, 0, 0, None
    added, deleted, binary = diff_stats(root, anchor, changed)
    total = added + deleted
    if total > budget:
        message = f"budget: {total} changed lines exceeds {budget}"
        if binary:
            message += f" ({binary} binary file(s) not counted)"
        return added, deleted, binary, message
    return added, deleted, binary, None


def commit_subjects(root: Path, anchor: str) -> list[tuple[str, str, str]]:
    """Return (short sha, subject, body) for the commits this branch adds."""
    code, out, _ = run_git(
        root,
        ["log", "--no-merges", "--format=%h%x1f%B%x1e", f"{anchor}..HEAD"],
    )
    if code != 0:
        return []
    rows = []
    for record in out.split("\x1e"):
        line = record.strip("\n")
        if not line:
            continue
        sha, _, rest = line.partition("\x1f")
        subject, separator, remainder = rest.partition("\n")
        body = separator + remainder if separator else ""
        if sha:
            rows.append((sha, subject, body))
    return rows


def subject_problems(
    rule: dict[str, Any], sha: str, subject: str, body: str
) -> list[str]:
    """Return every complaint about one commit message."""
    problems: list[str] = []
    match = COMMIT_SUBJECT_RE.match(subject)
    if not match:
        return [f"{sha}: subject must read type(scope): subject: {subject}"]
    kind = match.group("type")
    scope = match.group("scope")
    if rule["types"] and kind not in rule["types"]:
        problems.append(
            f"{sha}: type '{kind}' is not one of: {', '.join(rule['types'])}"
        )
    if rule["scopes"] and not scope:
        problems.append(
            f"{sha}: missing scope; choose one of: {', '.join(rule['scopes'])}"
        )
    if scope and rule["scopes"] and scope not in rule["scopes"]:
        problems.append(
            f"{sha}: scope '{scope}' is not one of: {', '.join(rule['scopes'])}"
        )
    missing = [token for token in rule["body"] if token not in body]
    if missing:
        problems.append(
            f"{sha}: commit body must contain {', '.join(missing)} "
            f"(write 'Batch: none' when there is no batch)"
        )
    return problems


def check_commit_titles(
    root: Path, anchor: str, config: dict[str, Any]
) -> list[str]:
    """Check every commit the branch adds against the configured rule."""
    rule = commit_rule(root, config)
    if not rule["enabled"]:
        return []
    problems: list[str] = []
    for sha, subject, body in commit_subjects(root, anchor):
        problems.extend(subject_problems(rule, sha, subject, body))
    return problems


def check_merged_commit(root: Path, config: dict[str, Any]) -> list[str]:
    """Check the squash commit that just landed on the base branch.

    This runs after the merge, so it can only report; it never blocks.
    """
    rule = commit_rule(root, config)
    if not rule["enabled"]:
        return []
    code, out, _ = run_git(
        root, ["log", "-1", "--format=%h%x1f%s%x1f%b"]
    )
    if code != 0 or not out.strip():
        return []
    sha, _, rest = out.partition("\x1f")
    subject, _, body = rest.partition("\x1f")
    return subject_problems(rule, sha, subject, body)


MAX_COMMIT_LINE = 72


def commit_body_problems(sha: str, subject: str, body: str) -> list[str]:
    """Return complaints about the shape of one commit message."""
    problems: list[str] = []
    if len(subject) > MAX_COMMIT_LINE:
        problems.append(
            f"{sha}: subject is {len(subject)} characters (max {MAX_COMMIT_LINE})"
        )
    if body.strip() and not body.startswith("\n\n"):
        problems.append(f"{sha}: body must start with a blank line after the subject")
    lines = body.lstrip("\n").splitlines()
    in_fence = False
    for number, line in enumerate(lines, 1):
        if line.strip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or line.startswith((" ", "\t")):
            continue
        if line.strip().startswith(("http://", "https://")):
            continue
        if len(line) > MAX_COMMIT_LINE:
            problems.append(
                f"{sha}: body line {number} is {len(line)} characters "
                f"(max {MAX_COMMIT_LINE})"
            )
    return problems


def lint_commits(root: Path, base: str, config: dict[str, Any]) -> list[str]:
    """Check the commits this branch adds, by rule and by shape."""
    anchor = budget_anchor(root, base, None)
    rule = commit_rule(root, config)
    problems: list[str] = []
    for sha, subject, body in commit_subjects(root, anchor):
        if rule["enabled"]:
            problems.extend(subject_problems(rule, sha, subject, body))
        problems.extend(commit_body_problems(sha, subject, body))
    return problems


def wrap_commit_body(body: str, width: int = MAX_COMMIT_LINE) -> str:
    """Reflow prose paragraphs to ``width``, leaving bullets and fences alone."""
    out: list[str] = []
    paragraph: list[str] = []
    in_fence = False

    def flush() -> None:
        if paragraph:
            out.extend(textwrap.wrap(" ".join(paragraph), width=width))
            paragraph.clear()

    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            flush()
            in_fence = not in_fence
            out.append(line.rstrip())
            continue
        if in_fence:
            out.append(line.rstrip())
            continue
        if not stripped:
            flush()
            out.append("")
            continue
        if line.startswith((" ", "\t")) or re.match(r"^([-*+]|\d+\.)\s", stripped):
            flush()
            out.append(line.rstrip())
            continue
        paragraph.append(stripped)
    flush()
    while out and not out[-1]:
        out.pop()
    return "\n".join(out)


def cmd_commit(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    git_required(root)
    config = load_config(root)
    base = str(args.base or config.get("base", "main"))
    if resolve_commit(root, base) is None:
        print(f"base does not resolve: {base}", file=sys.stderr)
        return 2
    if args.action == "lint":
        problems = lint_commits(root, base, config)
        for problem in problems:
            print(problem, file=sys.stderr)
        print(f"commit lint: {len(problems)} problem(s)")
        return 1 if problems else 0
    code, out, err = run_git(root, ["log", "-1", "--format=%h%x1f%s%x1f%b"])
    if code != 0 or not out:
        print(f"cannot read the tip commit: {err}", file=sys.stderr)
        return 2
    sha, _, rest = out.partition("\x1f")
    subject, _, body = rest.partition("\x1f")
    wrapped = wrap_commit_body(body)
    if wrapped.strip() == body.strip():
        print("nothing to wrap")
        return 0
    message = subject + ("\n\n" + wrapped if wrapped.strip() else "")
    if not args.apply:
        print(message)
        print("(pass --apply to rewrite the tip commit)")
        return 0
    proc = subprocess.run(
        ["git", "commit", "--amend", "--allow-empty", "-F", "-"],
        cwd=root,
        input=message,
        text=True,
        encoding="utf-8",
        capture_output=True,
    )
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        return 1
    print(f"wrapped {sha}")
    return 0


def check_changelog(
    root: Path, card: dict[str, Any], changed: Sequence[str]
) -> tuple[list[str], list[str]]:
    violations: list[str] = []
    warnings: list[str] = []
    card_type = str(card.get("type", ""))
    paths = [str(item) for item in card.get("changelog", [])]
    uses_changelog = (root / "changelog.d").is_dir()
    if card_type in {"feat", "fix"} and uses_changelog and not paths:
        violations.append("changelog: feat/fix must declare at least one fragment")
    if card_type in {"feat", "fix"} and not uses_changelog:
        warnings.append("changelog.d is absent; no fragment was required")

    changed_set = set(changed)
    for raw in paths:
        path = Path(raw)
        normalized = path.as_posix()
        if path.is_absolute() or ".." in path.parts:
            violations.append(f"changelog: path must stay inside the project: {raw}")
            continue
        if not normalized.startswith("changelog.d/"):
            violations.append(f"changelog: fragment must live under changelog.d/: {raw}")
            continue
        target = root / normalized
        if not target.is_file():
            violations.append(f"changelog: missing fragment: {raw}")
            continue
        if normalized not in changed_set:
            violations.append(f"changelog: fragment was not changed by this batch: {raw}")
            continue
        try:
            content = target.read_text(encoding="utf-8").strip()
        except UnicodeDecodeError:
            violations.append(f"changelog: fragment is not UTF-8: {raw}")
            continue
        if not content:
            violations.append(f"changelog: empty fragment: {raw}")
    return violations, warnings


def append_evidence(root: Path, batch_id: str, line: str) -> None:
    path = batch_dir(root, batch_id) / "evidence.log"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"[{utc_now()}] {line}\n")


def command_list(value: Any) -> list[str]:
    if isinstance(value, str):
        return shlex.split(value)
    if isinstance(value, list) and all(isinstance(item, str) for item in value):
        return list(value)
    raise SystemExit("command must be a string or an array of strings")


def run_hook(
    root: Path, command: Sequence[str], values: dict[str, str]
) -> tuple[int, str, str]:
    merged = {"pr": "", **values}
    resolved = [
        re.sub(
            r"\{([a-z]+)\}",
            lambda match: str(merged.get(match.group(1), match.group(0))),
            item,
        )
        for item in command
    ]
    proc = subprocess.run(
        resolved,
        cwd=root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def _run_check(
    root: Path, batch_id: str, item: dict[str, Any]
) -> tuple[str, dict[str, Any], str]:
    name = str(item["id"])
    command = item["run"]
    timeout = int(item.get("timeout", 600))
    raw_cwd = str(item.get("cwd", ".") or ".").strip() or "."
    check_cwd = (root / raw_cwd).resolve()
    try:
        check_cwd.relative_to(root.resolve())
    except ValueError:
        raise SystemExit(f"check {name}: cwd escapes project root: {raw_cwd}")
    try:
        proc = subprocess.run(
            command,
            cwd=check_cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        status = "pass" if proc.returncode == 0 else "fail"
        output = (proc.stdout + proc.stderr).strip()
        code = proc.returncode
    except subprocess.TimeoutExpired:
        status, output, code = "fail", f"timeout after {timeout}s", 124
    return name, {"status": status, "exit": code, "at": utc_now()}, output


def run_checks(
    root: Path, batch_id: str, checks: list[Any]
) -> dict[str, dict[str, Any]]:
    results: dict[str, dict[str, Any]] = {}
    if not checks:
        return results
    with ThreadPoolExecutor(max_workers=min(4, len(checks))) as pool:
        futures = [pool.submit(_run_check, root, batch_id, item) for item in checks]
        gathered = [future.result() for future in futures]
    for name, result, output in gathered:
        log = batch_dir(root, batch_id) / "evidence" / f"{name}.log"
        write_text(log, output + ("\n" if output else ""))
        results[name] = result
        append_evidence(
            root, batch_id, f"check {name}: {result['status'].upper()} (exit {result['exit']})"
        )
        print(f"[{result['status']}] check {name}")
        if result["status"] == "fail":
            print(output[-2000:], file=sys.stderr)
    return results


def print_status(root: Path, batch_id: str, as_json: bool) -> None:
    card = read_card(root, batch_id)
    state = load_json(batch_dir(root, batch_id) / "state.json") or {}
    status = state.get("status") or ("legacy" if card.get("legacy") else "planned")
    payload = {
        "id": batch_id,
        "goal": card.get("goal"),
        "card_hash": card_hash(card)[:8],
        "status": status,
        "base": state.get("base"),
        "branch": state.get("branch"),
        "checks": state.get("checks", {}),
        "active": active_id(root) == batch_id,
        "legacy": bool(card.get("legacy")),
        "source": card.get("source"),
    }
    if as_json:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
        return
    print(f"batch:  {batch_id}")
    print(f"goal:   {payload['goal'] or ''}")
    print(f"hash:   {payload['card_hash']}")
    print(f"status: {payload['status']}")
    if payload["base"]:
        print(f"base:   {payload['base']}")
    if payload["branch"]:
        print(f"branch: {payload['branch']}")
    if payload["source"]:
        print(f"source: {payload['source']}")
    if payload["checks"]:
        for name, result in payload["checks"].items():
            print(f"check:  {name} = {result.get('status')}")
    print(f"active: {'yes' if payload['active'] else 'no'}")


CARD_LINT_KEYS = (
    "id",
    "goal",
    "pr_title",
    "type",
    "base",
    "size_budget",
    "release",
    "allowed",
    "forbidden",
    "acceptance",
    "changelog",
    "skills",
)


def card_issue_line(text: str, message: str, fallback: int) -> int:
    """Best-effort line number for a schema message inside the card source."""
    for key in CARD_LINT_KEYS:
        if key in message:
            for index, line in enumerate(text.splitlines(), 1):
                if re.search(rf'"{re.escape(key)}"\s*:', line):
                    return index
    return fallback


def lint_card(root: Path, source: Path) -> list[str]:
    """Return one ``<path>:<line>: message`` string per card problem."""
    relative = source_relative(root, source)
    try:
        text = source.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [f"{relative}:1: cannot read card: {exc}"]
    issues: list[str] = []
    marker = CARD_MARKER_RE.search(text)
    if marker is None:
        issues.append(f"{relative}:1: missing <!-- batch-card: v1 --> marker")
    block = CARD_JSON_RE.search(text, marker.end() if marker else 0)
    if block is None:
        issues.append(
            f"{relative}:1: missing fenced json block after the card marker"
        )
        return issues
    block_line = text.count("\n", 0, block.start()) + 1
    try:
        card = json.loads(block.group(1))
    except json.JSONDecodeError as exc:
        issues.append(f"{relative}:{block_line}: invalid card JSON: {exc}")
        return issues
    config = load_config(root)
    rule = commit_rule(root, config)
    types = set(rule["types"]) if rule["types"] else None
    for message in card_issues(card, source, types):
        line = card_issue_line(text, message, block_line)
        issues.append(f"{relative}:{line}: {message}")
    batch_id = card.get("id") if isinstance(card, dict) else None
    if not isinstance(batch_id, str) or not CARD_ID_RE.fullmatch(batch_id):
        return issues
    docs_root = configured_docs_root(root, config) or docs_root_from_card(source)
    if docs_root is None:
        return issues
    sdp = docs_root / DOCS_PROCESS / DOCS_SDP
    if not sdp.is_file():
        issues.append(f"{relative}:{block_line}: SDP not found: {sdp}")
        return issues
    planned = sdp_batch_ids(sdp)
    if not planned:
        issues.append(f"{relative}:{block_line}: no '| Batch |' table in {sdp}")
        return issues
    if batch_id not in planned:
        issues.append(
            f"{relative}:{block_line}: card {batch_id} is not in the SDP batch table: {sdp}"
        )
    taken = docs_batch_ids(docs_root, exclude=source)
    if batch_id in taken:
        issues.append(
            f"{relative}:{block_line}: batch id {batch_id} is already used by {taken[batch_id]}"
        )
        issues.append(
            f"{relative}:{block_line}: next unused id: {next_batch_id(planned | set(taken))}"
        )
    return issues


PITFALL_ID_RE = re.compile(r"^(P|L)-[0-9]{4}$")
PITFALL_CORE = Path(__file__).resolve().parent / "pitfalls"


def read_pitfall(path: Path) -> dict[str, Any]:
    """Parse a pitfall entry: front matter plus the first H1 as its title."""
    text = path.read_text(encoding="utf-8")
    data: dict[str, str] = {}
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            for line in text[4:end].splitlines():
                if ":" in line:
                    key, value = line.split(":", 1)
                    data[key.strip()] = value.strip()
            body = text[end + 5 :]
    title = ""
    for line in body.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break
    data["title"] = title
    data["path"] = str(path)
    return data


def pitfall_layers(root: Path, config: dict[str, Any]) -> list[tuple[str, Path]]:
    layers: list[tuple[str, Path]] = [("core", PITFALL_CORE)]
    overlay_root = root / ".nebula" / "overlay"
    if overlay_root.is_dir():
        for directory in sorted(overlay_root.glob("*/pitfalls")):
            if directory.is_dir():
                layers.append((f"overlay:{directory.parent.name}", directory))
    docs = configured_docs_root(root, config)
    if docs and (docs / "process" / "pitfalls").is_dir():
        layers.append(("project", docs / "process" / "pitfalls"))
    return layers


def load_pitfalls(
    root: Path, config: dict[str, Any]
) -> tuple[dict[str, dict[str, Any]], list[str]]:
    """Merge pitfall packs from core, overlays, and the docs repo."""
    entries: dict[str, dict[str, Any]] = {}
    problems: list[str] = []
    for source, directory in pitfall_layers(root, config):
        seen: set[str] = set()
        for path in sorted(directory.rglob("*.md")):
            if path.name == "_template.md":
                continue
            data = read_pitfall(path)
            pitfall_id = str(data.get("id", "")).strip()
            if not PITFALL_ID_RE.fullmatch(pitfall_id):
                problems.append(f"{path}: bad pitfall id {pitfall_id!r}")
                continue
            if pitfall_id in seen:
                problems.append(f"{path}: duplicate pitfall id {pitfall_id} in {source}")
                continue
            seen.add(pitfall_id)
            data["source"] = source
            if pitfall_id in entries:
                data["overrides"] = entries[pitfall_id].get("source", "")
            entries[pitfall_id] = data
    return entries, problems


def retro_draft(root: Path, batch_id: str) -> str:
    state = read_state(root, batch_id)
    card = read_card(root, batch_id)
    lines = [
        f"# Retro {batch_id}",
        "",
        "## What happened",
        "",
        "| Event | When |",
        "|---|---|",
    ]
    for key, label in (
        ("planned_at", "planned"),
        ("approved_at", "approved"),
        ("started_at", "started"),
        ("checked_at", "checked"),
        ("pr_ready_at", "PR ready"),
        ("pr_created_at", "PR created"),
        ("review_at", "review"),
        ("merged_at", "merged"),
        ("exited_at", "exited"),
        ("frozen_at", "frozen"),
        ("paused_at", "paused"),
        ("aborted_at", "aborted"),
    ):
        if state.get(key):
            lines.append(f"| {label} | {state[key]} |")
    lines += ["", "## Where it hurt", ""]
    hurts: list[tuple[str, str, str]] = []
    checks = state.get("checks") or {}
    if isinstance(checks, dict):
        pairs = [
            (str(name), value) for name, value in checks.items()
        ]
    else:
        pairs = [
            (str(item.get("id") or item.get("name") or "check"), item)
            for item in checks
            if isinstance(item, dict)
        ]
    for name, value in pairs:
        if isinstance(value, dict) and str(value.get("status")) == "fail":
            hurts.append(
                (
                    name,
                    f"check {name} failed",
                    f"re-run the check after the fix: batch.py check {batch_id}",
                )
            )
    override = state.get("budget_override") or {}
    if override:
        hurts.append(
            (
                "budget",
                f"budget exceeded: {override.get('lines')} > {override.get('budget')}",
                "split the batch or raise the budget before starting",
            )
        )
    if state.get("check_override"):
        hurts.append(
            (
                "merge",
                "the gate was bypassed with --force",
                "fix the gate or ask for a smaller batch",
            )
        )
    for entry in state.get("recard") or []:
        hurts.append(
            (
                "plan",
                f"card changed after planning: {entry.get('changed')}",
                "lint the card and settle the scope before approving",
            )
        )
    if state.get("paused"):
        hurts.append(
            ("pause", "the batch was parked and resumed", "size the batch for one sitting")
        )
    if not hurts:
        lines.append("- none recorded")
    for step, symptom, fix in hurts:
        lines.append(f"- {step}: {symptom}")
    lines += ["", "## Candidate entries", ""]
    if not hurts:
        lines.append("_No candidates: this batch has nothing to promote._")
    for step, symptom, fix in hurts:
        lines += [
            "```yaml",
            "id: L-0000",
            f"step: {step}",
            f"symptom: {symptom}",
            "cause: fill this in",
            f"fix: {fix}",
            f"verify: batch.py check {batch_id}",
            "severity: error",
            f"source: {batch_id}",
            "```",
            "",
        ]
    return "\n".join(lines).rstrip() + "\n"


def cmd_retro(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    try:
        batch_id = resolve_id(root, args.id)
        text = retro_draft(root, batch_id)
    except SystemExit as exc:
        print(str(exc), file=sys.stderr)
        return 2
    out = Path(args.out) if args.out else batch_dir(root, batch_id) / "retro.md"
    out = out if out.is_absolute() else root / out
    write_text(out, text)
    print(f"wrote {source_relative(root, out)}")
    print("copy the candidates you trust into process/pitfalls/ by hand")
    return 0


def cmd_doctor(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    card = read_card(root, batch_id)
    status = str(state.get("status") or "")
    findings: list[tuple[str, str]] = []
    findings.append(("ok", f"{batch_id}: {status or 'unknown'}"))
    approval = batch_dir(root, batch_id) / "approval.json"
    if status in {"planned", "approved"} and not approval.is_file():
        findings.append(("warn", "no approval yet; run: batch.py approve " + batch_id + " --last"))
    if approval.is_file():
        recorded = load_json(approval) or {}
        if str(recorded.get("card_hash") or "") != card_hash(card):
            findings.append(("error", "approval is stale; run: batch.py approve " + batch_id + " --last"))
    mismatch = batch_branch_mismatch(root, state, batch_id)
    if mismatch:
        findings.append(("error", mismatch))
    body = state.get("pr_body")
    if body and not (root / str(body)).is_file():
        findings.append(("error", f"prepared body is missing: {body}"))
    if status in {"merged", "exited", "frozen"} and not state.get("verified_merge"):
        findings.append(("warn", "merge not verified; run: batch.py verify-merge " + batch_id))
    if status in {"merged", "exited", "frozen"} and not state.get("exit_record"):
        findings.append(("warn", "no exit record yet; run: batch.py exit " + batch_id + " --draft"))
    record = state.get("exit_record")
    if record and (root / str(record)).is_file():
        problems = exit_record_problems((root / str(record)).read_text(encoding="utf-8"))
        for problem in problems:
            findings.append(("error", "exit record: " + problem))
    for item in card.get("skills") or []:
        if not isinstance(item, dict) or not item.get("required"):
            continue
        skill_id = str(item.get("id", ""))
        evidence = batch_dir(root, batch_id) / "evidence" / "skills" / f"{skill_id}.md"
        if not evidence.is_file():
            findings.append(("warn", f"skill {skill_id} has no evidence yet"))
    errors = sum(1 for level, _ in findings if level == "error")
    warnings = sum(1 for level, _ in findings if level == "warn")
    for level, message in findings:
        print(f"[{level}] {message}")
    print(f"doctor: {errors} error(s), {warnings} warning(s)")
    return 1 if errors else 0


def load_check_packs(root: Path) -> dict[str, dict[str, Any]]:
    directory = root / "infra" / "tool" / "batch" / "checks"
    packs: dict[str, dict[str, Any]] = {}
    if not directory.is_dir():
        return packs
    for path in sorted(directory.glob("*.json")):
        data = load_json(path) or {}
        for item in data.get("checks", []):
            if isinstance(item, dict) and item.get("id"):
                entry = normalize_checks([item], "check")[0]
                entry["origin"] = path.stem
                packs[str(entry["id"])] = entry
    return packs


def check_stats(root: Path) -> dict[str, dict[str, Any]]:
    stats: dict[str, dict[str, Any]] = {}
    base = root / ".batch"
    if not base.is_dir():
        return stats
    for directory in sorted(base.iterdir()):
        if not directory.is_dir() or not ID_RE.match(directory.name):
            continue
        state_file = directory / "state.json"
        if not state_file.is_file():
            continue
        state = load_json(state_file) or {}
        for check_id, result in (state.get("checks") or {}).items():
            entry = stats.setdefault(
                str(check_id), {"runs": 0, "fails": 0, "last_failure": ""}
            )
            entry["runs"] += 1
            if isinstance(result, dict) and str(result.get("status")) == "fail":
                entry["fails"] += 1
                entry["last_failure"] = str(result.get("at") or "")
    return stats


def cmd_checks(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    config = load_config(root)
    packs = load_check_packs(root)
    if args.action == "report":
        stats = check_stats(root)
        rows = []
        for key, tier in (("checks", "check"), ("release_checks", "release")):
            for item in config[key]:
                rows.append({**item, "tier": tier, "origin": "config", "source": key})
        known = {str(row["id"]) for row in rows}
        for check_id in sorted(packs):
            if check_id not in known:
                rows.append({**packs[check_id], "source": "pack"})
        for check_id in sorted(stats):
            if check_id not in {str(row["id"]) for row in rows}:
                rows.append({"id": check_id, "run": [], "source": "history"})
        payload = []
        for row in rows:
            entry = stats.get(str(row["id"]), {"runs": 0, "fails": 0, "last_failure": ""})
            payload.append({**row, **entry})
        if args.upstream:
            out = root / ".batch" / "checks-upstream.json"
            write_json(
                out,
                {
                    "format": 1,
                    "generated_at": utc_now(),
                    "checks": [
                        {
                            "id": item["id"],
                            "run": item.get("run") or [],
                            "tier": item.get("tier", "check"),
                            "severity": item.get("severity", "error"),
                            "stage": item.get("stage", 5),
                            "runs": item["runs"],
                            "fails": item["fails"],
                            "last_failure": item["last_failure"],
                        }
                        for item in payload
                    ],
                },
            )
            print(f"wrote {source_relative(root, out)}")
            return 0
        if args.json:
            print(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True))
            return 0
        print(f"{'id':<20} {'runs':>5} {'fails':>6} last failure")
        for item in payload:
            print(
                f"{str(item['id']):<20} {item['runs']:>5} {item['fails']:>6} "
                f"{item['last_failure'] or '-'}"
            )
        return 0
    rows = []
    for key, tier in (("checks", "check"), ("release_checks", "release")):
        for item in config[key]:
            rows.append({**item, "tier": tier, "origin": "config", "source": key})
    configured = {str(row["id"]) for row in rows}
    for check_id in sorted(packs):
        if check_id not in configured:
            rows.append({**packs[check_id], "source": "pack"})
    if args.json:
        print(json.dumps(rows, indent=2, ensure_ascii=False, sort_keys=True))
        return 0
    if not rows:
        print("no checks configured")
        return 0
    for row in rows:
        command = " ".join(str(part) for part in row.get("run") or [])
        print(
            f"{row['id']:<20} {row.get('tier', 'check'):<8} "
            f"{row.get('severity', 'error'):<6} {row.get('stage', 5):<3} "
            f"{row.get('origin', 'config'):<10} {command}"
        )
    return 0


def cmd_pitfalls(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    config = load_config(root)
    entries, problems = load_pitfalls(root, config)
    action = args.action
    if action == "check":
        for problem in problems:
            print(problem, file=sys.stderr)
        print(
            f"pitfalls: {len(entries)} entr(ies), {len(problems)} problem(s)",
            file=sys.stderr if problems else sys.stdout,
        )
        return 1 if problems else 0
    if action == "index":
        lines = ["| id | step | severity | title | source |", "|---|---|---|---|---|"]
        for pitfall_id in sorted(entries):
            entry = entries[pitfall_id]
            lines.append(
                f"| {pitfall_id} | {entry.get('step','-')} | "
                f"{entry.get('severity','-')} | {entry.get('title','')} | "
                f"{entry.get('source','')} |"
            )
        text = "\n".join(lines) + "\n"
        if args.out:
            write_text(Path(args.out), text)
            print(f"wrote {args.out}")
        else:
            print(text, end="")
        return 0
    if action == "show":
        entry = entries.get(args.id or "")
        if entry is None:
            print(f"pitfall not found: {args.id}", file=sys.stderr)
            return 1
        print(entry["path"])
        return 0
    step = args.step
    shown = 0
    for pitfall_id in sorted(entries):
        entry = entries[pitfall_id]
        if step and entry.get("step") != step:
            continue
        print(
            f"{pitfall_id} [{entry.get('step','-')}/{entry.get('severity','-')}] "
            f"{entry.get('title','')} ({entry.get('source','')})"
        )
        shown += 1
    if not shown:
        print("no pitfalls for that step")
    return 0


def cmd_config(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    path = config_path(root)
    if not path.is_file():
        print(f"config not found: {source_relative(root, path)}", file=sys.stderr)
        return 2
    try:
        load_config(root)
    except SystemExit as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(f"config: {source_relative(root, path)} is valid")
    return 0


def cmd_skills_report(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    base = root / ".batch"
    batches: list[Path] = []
    if base.is_dir():
        batches = sorted(
            (p for p in base.iterdir() if p.is_dir() and ID_RE.match(p.name)),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )[: (args.last or 20)]
    stats: dict[str, dict[str, int]] = {}
    declared: dict[str, int] = {}
    for directory in batches:
        card_path = directory / "card.json"
        if card_path.is_file():
            try:
                card = json.loads(card_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                card = {}
            for item in card.get("skills", []):
                skill_id = str(item.get("id", ""))
                declared[skill_id] = declared.get(skill_id, 0) + 1
        evidence = directory / "evidence" / "skills"
        if not evidence.is_dir():
            continue
        for path in evidence.glob("*.md"):
            fields = read_skill_evidence(path)
            entry = stats.setdefault(path.stem, {"batches": 0, "cited": 0})
            entry["batches"] += 1
            if fields.get("rule", "").strip():
                entry["cited"] += 1
    if not stats and not declared:
        print("no skill evidence yet")
        return 0
    total = len(batches)
    for skill_id in sorted(set(stats) | set(declared)):
        entry = stats.get(skill_id, {"batches": 0, "cited": 0})
        share = (100 * entry["batches"]) // total if total else 0
        print(
            f"{skill_id}: {entry['batches']} batch(es), {entry['cited']} cited, "
            f"declared in {declared.get(skill_id, 0)} card(s), {share}% of {total}"
        )
    for skill_id in installed_skills(root):
        if skill_id in stats or skill_id in declared:
            continue
        print(
            f"removal candidate: {skill_id} (0 of {total} batches; review before removing)"
        )
    return 0


def cmd_main_lint(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    config = load_config(root)
    ref = args.ref or "origin/main"
    code, out, err = run_git(root, ["rev-parse", "--verify", ref])
    if code != 0:
        print(f"cannot resolve {ref}: {err.strip()}", file=sys.stderr)
        return 2
    commit = out.strip()
    _, subject_out, _ = run_git(root, ["show", "-s", "--format=%s", commit])
    _, body_out, _ = run_git(root, ["show", "-s", "--format=%b", commit])
    subject = subject_out.strip()
    body = ("\n\n" + body_out.strip()) if body_out.strip() else ""
    rule = commit_rule(root, config)
    problems = subject_problems(rule, commit[:12], subject, body) if rule["types"] else []
    problems += commit_body_problems(commit[:12], subject, body)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print(f"main lint: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    print(f"main lint: {ref} {commit[:12]} {subject}")
    return 0


def cmd_lint(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    source = Path(args.card)
    source = source if source.is_absolute() else root / source
    source = source.resolve()
    if not source.is_file():
        print(f"card source not found: {source}", file=sys.stderr)
        return 2
    issues = lint_card(root, source)
    if issues:
        for issue in issues:
            print(issue, file=sys.stderr)
        print(f"lint: {len(issues)} error(s)", file=sys.stderr)
        return 1
    print(f"lint: {source_relative(root, source)} is clean")
    try:
        card, _ = read_planned_card(source)
    except ValueError:
        card = {}
    print_skill_suggestions(root, card)
    entries, _ = load_pitfalls(root, load_config(root))
    hints = sorted(
        (entry.get("severity") != "error", pitfall_id, entry)
        for pitfall_id, entry in entries.items()
        if entry.get("step") == "plan"
    )[:3]
    for _, pitfall_id, entry in hints:
        print(f"hint: {pitfall_id} {entry.get('title', '')}")
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    git_required(root)

    if args.source:
        extra = args.goal or args.allowed or args.forbidden or args.exit_criterion
        if extra:
            print(
                "--from cannot be combined with --goal, --allowed, --forbidden, "
                "or --exit-criterion",
                file=sys.stderr,
            )
            return 2
        source = Path(args.source)
        source = source if source.is_absolute() else root / source
        source = source.resolve()
        if not source.is_file():
            print(f"card source not found: {source}", file=sys.stderr)
            return 2
        config = load_config(root)
        rule = commit_rule(root, config)
        try:
            card, raw = read_planned_card(
                source, set(rule["types"]) if rule["types"] else None
            )
        except ValueError as exc:
            print(f"invalid card: {exc}", file=sys.stderr)
            return 2
        batch_id = card["id"]
        if args.id and args.id != batch_id:
            print(f"--id {args.id} does not match card id {batch_id}", file=sys.stderr)
            return 2
        target = batch_dir(root, batch_id)
        refresh = target.exists() and not archive_aborted(root, batch_id)
        if refresh:
            previous = load_json(target / "card.json")
            if previous is not None and previous.get("legacy"):
                print(f"batch already exists: {batch_id}", file=sys.stderr)
                return 1
            state = load_json(target / "state.json")
            if state is not None and state.get("status") not in {"planned", "approved"}:
                print(
                    f"batch already started: {batch_id} "
                    f"({state.get('status')}); abort it or use a new id",
                    file=sys.stderr,
                )
                return 1
        docs_root = configured_docs_root(root, config) or docs_root_from_card(source)
        if docs_root is None:
            print(
                "warning: docs repo not found; skipped SDP and duplicate-id checks",
                file=sys.stderr,
            )
        else:
            sdp = docs_root / DOCS_PROCESS / DOCS_SDP
            if not sdp.is_file():
                print(f"SDP not found: {sdp}", file=sys.stderr)
                return 2
            planned = sdp_batch_ids(sdp)
            if not planned:
                print(f"no '| Batch |' table in {sdp}", file=sys.stderr)
                return 2
            if batch_id not in planned:
                print(
                    f"card {batch_id} is not in the SDP batch table: {sdp}",
                    file=sys.stderr,
                )
                return 1
            taken = docs_batch_ids(docs_root, exclude=source)
            if batch_id in taken:
                print(
                    f"batch id {batch_id} is already used by {taken[batch_id]}",
                    file=sys.stderr,
                )
                print(
                    f"next unused id: {next_batch_id(planned | set(taken))}",
                    file=sys.stderr,
                )
                return 1
        snapshot = dict(card)
        snapshot["source"] = source_relative(root, source)
        snapshot["source_sha256"] = source_card_hash(source)
        digest = card_hash(snapshot)
        if refresh:
            previous = load_json(target / "card.json") or {}
            changed = [
                key
                for key in sorted(set(previous) | set(snapshot))
                if key not in {"source", "source_sha256"}
                and previous.get(key) != snapshot.get(key)
            ]
            if not changed and previous.get("source_sha256") == snapshot["source_sha256"]:
                print(f"unchanged {batch_id}")
                print(f"hash: {digest[:8]}")
                return 0
            write_json(target / "card.json", snapshot)
            (target / "approval.json").unlink(missing_ok=True)
            if (target / "state.json").is_file():
                record_approval(root, batch_id, "cleared", reason="card changed")
            print(f"updated {batch_id}: {', '.join(changed) or 'card source only'}")
            print("approval cleared; run: batch.py approve " + batch_id)
            print(f"hash: {digest[:8]}")
            return 0
        write_json(target / "card.json", snapshot)
        print_skill_suggestions(root, snapshot)
        print(f"planned {batch_id} from {snapshot['source']}")
        print(f"hash: {digest[:8]}")
        return 0

    if not args.goal:
        print("plan needs --from or --goal", file=sys.stderr)
        return 2
    if args.id and CARD_ID_RE.fullmatch(args.id):
        print("planned B<n> cards require --from", file=sys.stderr)
        return 2
    batch_id = args.id or new_id(root)
    if not DATED_ID_RE.fullmatch(batch_id):
        print("ad-hoc id must be YYYYMMDD-<6 hex>", file=sys.stderr)
        return 2
    target = batch_dir(root, batch_id)
    if target.exists() and not archive_aborted(root, batch_id):
        print(f"batch already exists: {batch_id}", file=sys.stderr)
        return 1
    config = load_config(root)
    card = {
        "id": batch_id,
        "goal": args.goal,
        "type": args.type or "process",
        "base": str(config.get("base", "main")),
        "size_budget": 0,
        "allowed": parse_list(args.allowed, ["**"]),
        "forbidden": parse_list(args.forbidden, []),
        "acceptance": parse_list(args.exit_criterion, []),
        "changelog": [],
        "skills": [],
        "ad_hoc": True,
        "created_at": utc_now(),
    }
    write_json(target / "card.json", card)
    print_skill_suggestions(root, card)
    print(f"planned {batch_id}")
    print(f"hash: {card_hash(card)[:8]}")
    return 0


def record_approval(
    root: Path, batch_id: str, action: str, **fields: Any
) -> None:
    directory = batch_dir(root, batch_id)
    path = directory / "state.json"
    state = load_json(path) if path.is_file() else {"batch": batch_id, "status": "planned"}
    if not isinstance(state, dict):
        state = {"batch": batch_id}
    history = list(state.get("approvals", []))
    history.append({"at": utc_now(), "action": action, **fields})
    state["approvals"] = history[-20:]
    write_json(path, state)


def cmd_approve(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    card = read_card(root, batch_id)
    if card.get("legacy"):
        print("legacy cards are read-only and cannot be approved", file=sys.stderr)
        return 1
    current, message = source_is_current(root, card)
    if not current:
        print(message, file=sys.stderr)
        return 1
    digest = card_hash(card)
    approval_path = batch_dir(root, batch_id) / "approval.json"
    if args.check:
        approval = load_json(approval_path)
        if approval is None:
            print(f"approval: missing for {batch_id}", file=sys.stderr)
            return 1
        if approval.get("card_hash") != digest:
            print(
                f"approval: stale for {batch_id} "
                f"(card changed since {approval.get('approved_at', 'unknown')}); "
                f"run: batch.py approve {batch_id} --last",
                file=sys.stderr,
            )
            return 1
        print(f"approval: current for {batch_id} ({digest[:8]})")
        return 0
    if args.last:
        if args.confirm:
            print("--last and --confirm cannot be combined", file=sys.stderr)
            return 2
    else:
        if not args.confirm:
            print(
                f"pass --confirm {digest[:8]} or --last",
                file=sys.stderr,
            )
            return 2
        if args.confirm != digest[:8]:
            print(f"confirm mismatch: expected {digest[:8]}", file=sys.stderr)
            return 1
    approval = {
        "batch": batch_id,
        "card_hash": digest,
        "source_sha256": card.get("source_sha256"),
        "approved_by": args.by,
        "approved_at": utc_now(),
    }
    write_json(approval_path, approval)
    record_approval(root, batch_id, "approved", hash=digest[:8], by=args.by)
    print(f"approved {batch_id}")
    return 0


def cmd_start(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    git_required(root)
    batch_id = resolve_id(root, args.id)
    card = read_card(root, batch_id)
    if card.get("legacy"):
        print("legacy cards are read-only and cannot be started", file=sys.stderr)
        return 1
    approval = load_json(batch_dir(root, batch_id) / "approval.json")
    if approval is None or approval.get("card_hash") != card_hash(card):
        print("card is not approved (or approval is stale)", file=sys.stderr)
        return 1
    if approval.get("source_sha256") != card.get("source_sha256"):
        print("card source is not approved (or approval is stale)", file=sys.stderr)
        return 1
    current_source, message = source_is_current(root, card)
    if not current_source:
        print(message, file=sys.stderr)
        return 1
    current = active_id(root)
    if current:
        current_state = read_state(root, current)
        if current_state.get("status") in {"merged", "exited", "frozen", "aborted"}:
            clear_active(root)
            print(
                f"cleared stale active batch {current} "
                f"({current_state.get('status')})"
            )
        else:
            print(f"another batch is active: {current}", file=sys.stderr)
            return 1

    config = load_config(root)
    base_ref = args.base or str(card.get("base") or config.get("base", "main"))
    base = resolve_commit(root, base_ref)
    if not base:
        print(f"base does not resolve to a commit: {base_ref}", file=sys.stderr)
        return 1
    skill_errors, skill_found = check_skills(root, card)
    if skill_errors:
        for item in skill_errors:
            print(item, file=sys.stderr)
        return 1
    slug = branch_slug(str(card.get("goal", "")))
    default_branch = f"{config.get('branch_prefix', 'batch/')}{batch_id}"
    if slug:
        default_branch = f"{default_branch}-{slug}"
    branch = args.branch or default_branch
    here = current_branch(root)
    prefix = str(config.get("branch_prefix", "batch/"))
    if not args.no_branch and here.startswith(prefix):
        print(
            f"you are on batch branch {here}; "
            f"switch to {base_ref} before starting another batch",
            file=sys.stderr,
        )
        return 1
    if not args.no_branch:
        code, _, err = run_git(root, ["switch", "-c", branch])
        if code != 0:
            print(f"could not create branch {branch}: {err}", file=sys.stderr)
            return 1

    state = {
        "batch": batch_id,
        "status": "started",
        "base": base,
        "base_ref": base_ref,
        "branch": branch,
        "branch_created": not args.no_branch,
        "card_hash": card_hash(card),
        "source_sha256": card.get("source_sha256"),
        "started_at": utc_now(),
        "skills": skill_found,
        "checks": {},
    }
    write_json(batch_dir(root, batch_id) / "state.json", state)
    set_active(root, batch_id)
    print(f"started {batch_id} on {branch} (base {base})")
    if skill_found:
        print("skills to load before editing:")
        for item in card.get("skills", []):
            skill_id = str(item.get("id", ""))
            plan = "required" if item.get("required") else "optional"
            anchor = skill_anchor(root, skill_id)
            suffix = f"  [{anchor}]" if anchor else ""
            print(f"  - {skill_id} ({plan})  {skill_found.get(skill_id, '')}{suffix}")
        print(
            f"record each skill in .batch/{batch_id}/evidence/skills/<skill-id>.md "
            "and quote the rule you followed on a 'rule:' line"
        )
    return 0


def next_steps(
    batch_id: str,
    gate_errors: list[str],
    budget_error: str,
    hard: list[str],
    checks: list[dict[str, Any]],
) -> list[str]:
    """Return the shortest list of commands that would move a failed check on."""
    steps: list[str] = []
    if budget_error:
        steps.append(
            f'record it: batch.py check {batch_id} --allow-over-budget "<why>"'
        )
    if [error for error in gate_errors if error != budget_error]:
        steps.append(f"fix the [fail] lines, then run: batch.py check {batch_id}")
    for name in hard[:1]:
        run = next(
            (item.get("run") for item in checks if str(item.get("id")) == name),
            None,
        )
        command = (
            " ".join(str(part) for part in run)
            if isinstance(run, list)
            else str(run or "")
        )
        if command:
            steps.append(f"reproduce {name}: {command}")
    return steps


def cmd_check(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    git_required(root)
    batch_id = resolve_id(root, args.id)
    card = read_card(root, batch_id)
    state = read_state(root, batch_id)
    mismatch = batch_branch_mismatch(root, state, batch_id)
    if mismatch:
        print(mismatch, file=sys.stderr)
        return 1
    if card.get("legacy"):
        print("legacy cards are read-only and cannot be checked", file=sys.stderr)
        return 1
    approval = load_json(batch_dir(root, batch_id) / "approval.json")
    if approval is None or approval.get("card_hash") != card_hash(card):
        print("card is not approved (or approval is stale)", file=sys.stderr)
        return 1
    current, message = source_is_current(root, card)
    if not current:
        state["status"] = "check_failed"
        state["source_error"] = message
        state["checked_at"] = utc_now()
        write_json(batch_dir(root, batch_id) / "state.json", state)
        append_evidence(root, batch_id, f"source: FAIL ({message})")
        print(message, file=sys.stderr)
        return 1
    source_path = card_source_path(root, card)
    if source_path is not None and source_path.is_file():
        marker = plan_marker_hash(source_path, batch_id)
        if marker and not card_hash(card).startswith(marker):
            print(
                f"[warn] card marker {marker} does not match the planned hash "
                f"{card_hash(card)[:8]}; re-plan",
                file=sys.stderr,
            )
    config = load_config(root)
    links = card_link_problems(root, card, config, source_path)
    if links:
        state["status"] = "check_failed"
        state["link_error"] = "; ".join(links)
        state["checked_at"] = utc_now()
        write_json(batch_dir(root, batch_id) / "state.json", state)
        for problem in links:
            append_evidence(root, batch_id, f"link: FAIL ({problem})")
            print(f"[fail] {problem}", file=sys.stderr)
        return 1
    release = bool(card.get("release")) or bool(getattr(args, "release", False))
    checks = list(config.get("checks", []))
    if release:
        checks += list(config.get("release_checks", []))
    conflict = duplicate_id_error(root, card, config, batch_id)
    if conflict:
        state["status"] = "check_failed"
        state["id_error"] = conflict
        state["checked_at"] = utc_now()
        write_json(batch_dir(root, batch_id) / "state.json", state)
        append_evidence(root, batch_id, f"id: FAIL ({conflict})")
        print(conflict, file=sys.stderr)
        return 1
    base_ref = state.get("base") or str(config.get("base", "main"))
    base = resolve_commit(root, base_ref)
    if not base:
        state["status"] = "check_failed"
        state["base_error"] = f"base does not resolve to a commit: {base_ref}"
        state["checked_at"] = utc_now()
        write_json(batch_dir(root, batch_id) / "state.json", state)
        append_evidence(root, batch_id, f"base: FAIL ({state['base_error']})")
        print(state["base_error"], file=sys.stderr)
        return 1
    state["base"] = base
    state["base_ref"] = state.get("base_ref") or base_ref
    anchor = budget_anchor(root, base, state["base_ref"])
    state["scope_base"] = anchor
    changed, violations = check_scope(root, card, anchor, config)
    added, deleted, binary, budget_error = check_budget(root, card, anchor, changed)
    override_reason = str(getattr(args, "allow_over_budget", "") or "").strip()
    budget_override: dict[str, Any] | None = None
    if budget_error and override_reason:
        budget_override = {
            "budget": int(card.get("size_budget", 0)),
            "lines": added + deleted,
            "reason": override_reason,
        }
        budget_error = None
    elif budget_error:
        budget_error += '; rerun with --allow-over-budget "<why>" to record it'
    changelog_errors, changelog_warnings = check_changelog(root, card, changed)
    skill_errors, skill_found = check_skills(root, card)
    evidence_errors, evidence_warnings, skill_records = check_skill_evidence(
        root, batch_id, card
    )
    commit_errors = check_commit_titles(root, anchor, config)
    gate_errors = [
        *violations,
        *changelog_errors,
        *skill_errors,
        *evidence_errors,
        *commit_errors,
    ]
    if budget_error:
        gate_errors.append(budget_error)

    append_evidence(
        root,
        batch_id,
        f"scope: {'PASS' if not violations else 'FAIL'} ({len(changed)} changed paths)",
    )
    for path in changed:
        append_evidence(root, batch_id, f"changed: {path}")
    for violation in violations:
        append_evidence(root, batch_id, f"scope: {violation}")
    for violation in changelog_errors:
        append_evidence(root, batch_id, violation)
    for warning in changelog_warnings:
        append_evidence(root, batch_id, f"warn: {warning}")
    for violation in skill_errors:
        append_evidence(root, batch_id, violation)
    for violation in evidence_errors:
        append_evidence(root, batch_id, violation)
    for violation in commit_errors:
        append_evidence(root, batch_id, f"commit: {violation}")
    append_evidence(
        root,
        batch_id,
        "commit titles: "
        + ("PASS" if not commit_errors else f"FAIL ({len(commit_errors)})"),
    )
    append_evidence(
        root,
        batch_id,
        f"release: {'yes' if release else 'no'} ({len(checks)} checks)",
    )
    for warning in evidence_warnings:
        append_evidence(root, batch_id, f"warn: {warning}")
    if budget_error:
        append_evidence(root, batch_id, budget_error)
    if budget_override:
        append_evidence(
            root,
            batch_id,
            f"budget override: {budget_override['lines']} lines over "
            f"{budget_override['budget']} ({budget_override['reason']})",
        )
    for violation in gate_errors:
        print(f"[fail] {violation}", file=sys.stderr)
    for warning in [*changelog_warnings, *evidence_warnings]:
        print(f"[warn] {warning}", file=sys.stderr)

    results = run_checks(root, batch_id, checks) if not gate_errors else {}
    severities = {str(item["id"]): str(item.get("severity", "error")) for item in checks}
    hard = [
        name
        for name, result in results.items()
        if result.get("status") != "pass" and severities.get(name, "error") == "error"
    ]
    soft = [
        name
        for name, result in results.items()
        if result.get("status") != "pass" and severities.get(name) == "warn"
    ]
    for name in soft:
        append_evidence(root, batch_id, f"warn: check {name} failed with severity warn")
        print(f"[warn] check {name} failed with severity warn", file=sys.stderr)
    passed = not gate_errors and not hard
    if hard:
        entries, _ = load_pitfalls(root, config)
        for name in hard:
            for pitfall_id in sorted(entries):
                entry = entries[pitfall_id]
                if name in str(entry.get("checks", "")).split(","):
                    print(f"hint: {pitfall_id} {entry.get('title', '')}", file=sys.stderr)
                    break
    state["status"] = "checked" if passed else "check_failed"
    state["checks"] = results
    state["release"] = release
    state["scope"] = {
        "budget": int(card.get("size_budget", 0)),
        "changed": len(changed),
        "added": added,
        "deleted": deleted,
        "binary": binary,
        "measured_from": anchor,
        "result": "pass" if not budget_error and not violations else "fail",
        "violations": violations,
        "override": bool(budget_override),
    }
    state["budget_override"] = budget_override
    state["changelog"] = {
        "declared": [str(item) for item in card.get("changelog", [])],
        "warnings": changelog_warnings,
    }
    state["skills"] = skill_found
    state["skill_evidence"] = skill_records
    state["check_inputs"] = {
        "card": card_hash(card)[:12],
        "base": anchor[:12],
        "config": config_fingerprint(root),
    }
    state["checked_at"] = utc_now()
    write_json(batch_dir(root, batch_id) / "state.json", state)
    print(f"scope: {'PASS' if not violations else 'FAIL'} ({len(changed)} paths)")
    print(
        f"budget: {'SKIP' if not card.get('size_budget') else ('FAIL' if budget_error else 'PASS')}"
        f" ({added + deleted} lines from {anchor[:12]})"
        + (", override recorded" if budget_override else "")
    )
    print(f"changelog: {'FAIL' if changelog_errors else 'PASS'}")
    print(f"release: {'yes' if release else 'no'} ({len(checks)} checks)")
    print(
        f"skills: {'FAIL' if skill_errors or evidence_errors else 'PASS'}"
        + (
            " ("
            + ", ".join(
                f"{skill_id} {record['status']}"
                for skill_id, record in skill_records.items()
            )
            + ")"
            if skill_records
            else ""
        )
    )
    print(f"result: {'PASS' if passed else 'FAIL'}")
    if not passed:
        for step in next_steps(batch_id, gate_errors, budget_error, hard, checks):
            print(f"next: {step}")
    return 0 if passed else 1


def pr_body(root: Path, batch_id: str) -> str:
    """Render the prepared PR body in the shape of the repository PR template."""
    card = read_card(root, batch_id)
    state = read_state(root, batch_id)
    anchor = str(state.get("scope_base") or state.get("base", "main"))
    config = load_config(root)
    changed = changed_paths(root, anchor, config)
    scope = state.get("scope") or {}
    checks = state.get("checks") or {}
    base = state.get("base_ref") or state.get("base", "")
    spec = load_body_spec(root)
    for section in spec["sections"]:
        command = section.get("render")
        if not command:
            continue
        code, out, err = run_hook(
            root, command, {"batch": batch_id, "card": str(batch_dir(root, batch_id) / "card.json")}
        )
        if code != 0:
            raise SystemExit(
                f"pr: render for ## {section['heading']} failed (exit {code}): {err or out}"
            )
        content[str(section["key"])] = out.splitlines() or [out]

    content: dict[str, list[str]] = {}
    content["summary"] = [
        f"Batch `{batch_id}`: {card.get('goal', '')}",
        "",
        f"- Branch: `{state.get('branch', '')}`",
        f"- Base: `{base}`",
    ]
    content["impact"] = [
        "Allowed:",
        *[f"- `{item}`" for item in card.get("allowed", [])],
        "",
        f"Changed files: {len(changed)}",
        *[f"- `{item}`" for item in changed],
    ]
    verification: list[str] = []
    if checks:
        verification.extend(
            f"- `{name}`: {item.get('status', 'unknown')}"
            for name, item in checks.items()
        )
    else:
        verification.append("- checks: none configured")
    budget = int(scope.get("budget") or 0)
    added = int(scope.get("added") or 0)
    deleted = int(scope.get("deleted") or 0)
    verification.append(
        f"- scope: {str(scope.get('result', 'unknown')).upper()} "
        f"({scope.get('changed', len(changed))} files, {added + deleted} lines, "
        f"budget {budget or 'none'})"
    )
    verification.append(f"- evidence: `.batch/{batch_id}/evidence.log`")
    content["verification"] = verification

    risks = [str(item) for item in scope.get("violations", [])]
    override = state.get("budget_override") or None
    if budget and added + deleted > budget:
        if override:
            risks.append(
                f"budget: {added + deleted} changed lines exceeds {budget} — "
                f"override: {override.get('reason', '')}"
            )
        else:
            risks.append(f"budget: {added + deleted} changed lines exceeds {budget}")
    if int(scope.get("binary") or 0):
        risks.append(f"binary files: {scope.get('binary')} (diff is not reviewable)")
    for key, label in (("id_error", "id"), ("source_error", "source")):
        if state.get(key):
            risks.append(f"{label}: {state[key]}")
    warnings = (state.get("changelog") or {}).get("warnings") or []
    risks.extend(str(item) for item in warnings)
    content["risks"] = risks or ["None recorded by the gate."]

    criteria = card.get("acceptance", card.get("exit_criteria", []))
    content["self_check"] = [f"- {item}" for item in criteria] or ["- none recorded"]

    lines: list[str] = []
    for index, section in enumerate(spec["sections"]):
        if index:
            lines.append("")
        lines.append(f"## {section['heading']}")
        lines.append("")
        lines.extend(content.get(str(section["key"]), []))
    return "\n".join(lines)


def scaffold_language(root: Path) -> dict[str, Any]:
    """Resolve the language block used for PR body translations.

    Mirrors ``nebula-bootstrap/scripts/language.py``: a ``language`` block wins,
    legacy ``repoLocale``/``docsLocale`` blocks are mapped, and a missing or
    invalid block falls back to zh-CN. PR translations are best effort, so this
    only needs the primary, supported, and external values.
    """
    data = load_json(root / SCAFFOLD_REL) or {}
    block = data.get("language")
    if isinstance(block, dict) and isinstance(block.get("primary"), str):
        primary = block["primary"].strip()
        supported = [
            str(item).strip()
            for item in block.get("supported", [])
            if isinstance(item, str) and item.strip()
        ]
        if primary:
            supported = [primary, *[item for item in supported if item != primary]]
        external = str(block.get("external") or primary).strip()
        return {
            "primary": primary or "zh-CN",
            "supported": supported or ["zh-CN"],
            "external": external if external in supported else (primary or "zh-CN"),
        }
    repo = data.get("repoLocale") if isinstance(data.get("repoLocale"), dict) else {}
    docs = data.get("docsLocale") if isinstance(data.get("docsLocale"), dict) else {}
    primary = str(repo.get("primary") or docs.get("primary") or "zh-CN").strip() or "zh-CN"
    supported: list[str] = []
    for source in (repo.get("supported"), docs.get("supported")):
        for item in source or []:
            value = str(item).strip()
            if value and value not in supported:
                supported.append(value)
    if primary not in supported:
        supported.insert(0, primary)
    external = str(docs.get("external") or primary).strip()
    return {
        "primary": primary,
        "supported": supported,
        "external": external if external in supported else primary,
    }


def pr_translations(
    root: Path,
    batch_id: str,
    body_path: Path,
    digest: str,
    config: dict[str, Any],
    state: dict[str, Any],
) -> list[str]:
    """Write PR body translations through ``config.translate``; best effort."""
    language = scaffold_language(root)
    source_locale = language["external"]
    targets = [item for item in language["supported"] if item != source_locale]
    if not targets:
        return []
    command = config.get("translate")
    if not command:
        print(
            "config.translate is empty; skipped PR body translations",
            file=sys.stderr,
        )
        return []
    card = read_card(root, batch_id)
    directory = batch_dir(root, batch_id)
    translations: list[dict[str, Any]] = []
    for locale in targets:
        out = directory / f"pr-body.{locale}.md"
        part = directory / f"pr-body.{locale}.part.md"
        part.unlink(missing_ok=True)
        code, out_text, err_text = run_hook(
            root,
            command,
            {
                "id": batch_id,
                "title": str(card.get("goal", batch_id)),
                "body": str(body_path),
                "branch": str(state.get("branch", "")),
                "root": str(root),
                "locale": locale,
                "out": str(part),
            },
        )
        if out_text:
            print(out_text)
        kept = "; kept the previous file" if out.exists() else ""
        if code != 0:
            part.unlink(missing_ok=True)
            print(
                f"translation {locale} failed (exit {code}){kept}", file=sys.stderr
            )
            if err_text:
                print(err_text, file=sys.stderr)
            continue
        if not part.exists() or not part.read_text(encoding="utf-8").strip():
            part.unlink(missing_ok=True)
            print(
                f"translation {locale}: hook produced no output{kept}",
                file=sys.stderr,
            )
            continue
        part.replace(out)
        translations.append(
            {
                "locale": locale,
                "file": out.relative_to(root).as_posix(),
                "machine": True,
                "authoritative": False,
            }
        )
    if not translations:
        return []
    write_json(
        directory / "pr-body.manifest.json",
        {
            "source": source_relative(root, body_path),
            "source_sha256": digest,
            "source_locale": source_locale,
            "generated_at": utc_now(),
            "tool": "batch.py",
            "translations": translations,
        },
    )
    print(f"translations: {', '.join(item['locale'] for item in translations)}")
    return [item["locale"] for item in translations]


def pr_skills(root: Path, batch_id: str) -> str:
    """Render the skill usage report as a local review supplement."""
    card = read_card(root, batch_id)
    state = read_state(root, batch_id)
    records = state.get("skill_evidence", {})
    lines = [
        "# Skills",
        "",
        "Local review supplement. Not part of the PR body; never committed.",
        "",
        "| Skill | Plan | Actual | What changed | Proof |",
        "| --- | --- | --- | --- | --- |",
    ]
    for item in card.get("skills", []):
        skill_id = str(item.get("id", ""))
        record = records.get(skill_id, {})
        plan = "required" if item.get("required") else "optional"
        actual = str(record.get("status") or "missing")
        changed = str(record.get("changed") or "-").replace("|", "\\|")
        proof = str(record.get("proof") or "-").replace("|", "\\|")
        lines.append(f"| `{skill_id}` | {plan} | {actual} | {changed} | {proof} |")
    return "\n".join(lines) + "\n"


BODY_SPEC_REL = Path("infra/tool/batch/body.yaml")

DEFAULT_BODY_SECTIONS: dict[str, list[tuple[str, str]]] = {
    "en-US": [
        ("summary", "Summary"),
        ("impact", "Impact"),
        ("verification", "Verification"),
        ("risks", "Risks"),
        ("self_check", "Self-check"),
    ],
    "zh-CN": [
        ("summary", "变更摘要"),
        ("impact", "影响面"),
        ("verification", "验证"),
        ("risks", "风险"),
        ("self_check", "自检"),
    ],
    "ja-JP": [
        ("summary", "サマリー"),
        ("impact", "影響範囲"),
        ("verification", "検証"),
        ("risks", "リスク"),
        ("self_check", "セルフチェック"),
    ],
}


def default_body_spec(locale: str) -> dict[str, Any]:
    """Return the five sections the shipped PR templates use."""
    pairs = DEFAULT_BODY_SECTIONS.get(locale)
    if pairs is None:
        print(
            f"body: no default sections for {locale}; using en-US",
            file=sys.stderr,
        )
        pairs = DEFAULT_BODY_SECTIONS["en-US"]
    sections: list[dict[str, Any]] = []
    for key, heading in pairs:
        section: dict[str, Any] = {"key": key, "heading": heading}
        if key == "verification":
            section["require_command_block"] = True
        sections.append(section)
    return {"format": 1, "sections": sections}


def flow_list(value: str) -> list[str]:
    """Read `[a, b]` or a bare string as a command."""
    text = value.strip()
    if text.startswith("[") and text.endswith("]"):
        items = [item.strip().strip("\"'") for item in text[1:-1].split(",")]
        return [item for item in items if item]
    return [item for item in text.split() if item]


def parse_body_spec(text: str) -> dict[str, Any]:
    """Read the deliberately small YAML subset body.yaml uses."""
    data: dict[str, Any] = {"format": 0, "sections": []}
    current: dict[str, Any] | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("- "):
            current = {}
            data["sections"].append(current)
            line = line[2:].strip()
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip().strip("\"'")
        if current is None:
            if key == "format":
                data["format"] = int(value) if value.isdigit() else 0
            continue
        if key in {"required", "require_command_block"}:
            current[key] = value.lower() in {"true", "yes", "1"}
        elif key in {"key", "heading", "severity"}:
            current[key] = value
        elif key in {"render", "check"}:
            current[key] = flow_list(value)
    return data


def validate_body_spec(
    data: dict[str, Any], origin: str = "body.yaml"
) -> dict[str, Any]:
    if data.get("format") != 1:
        raise SystemExit(f"{origin}: format must be 1")
    sections = data.get("sections") or []
    if not sections:
        raise SystemExit(f"{origin}: no sections")
    seen: set[str] = set()
    for index, section in enumerate(sections, start=1):
        key = str(section.get("key") or "").strip()
        heading = str(section.get("heading") or "").strip()
        if not key or not heading:
            raise SystemExit(f"{origin}: section {index} needs key and heading")
        if heading.startswith("#"):
            raise SystemExit(f"{origin}: heading must not start with '#'")
        if key in seen:
            raise SystemExit(f"{origin}: duplicate key {key}")
        seen.add(key)
        severity = str(section.get("severity") or "error")
        if severity not in {"error", "warn"}:
            raise SystemExit(f"{origin}: severity must be error or warn")
        section["severity"] = severity
    return data


def load_body_spec(root: Path) -> dict[str, Any]:
    path = root / BODY_SPEC_REL
    if path.is_file():
        return validate_body_spec(
            parse_body_spec(path.read_text(encoding="utf-8")),
            path.as_posix(),
        )
    data = load_json(root / SCAFFOLD_REL) or {}
    block = data.get("language") if isinstance(data.get("language"), dict) else {}
    primary = str((block or {}).get("primary") or "en-US")
    return default_body_spec(primary)


def render_body_spec_yaml(spec: dict[str, Any]) -> str:
    lines = [
        "# The shape of a prepared PR body. Body lint and `pr --prepare` read it;",
        "# keep it in step with `.github/PULL_REQUEST_TEMPLATE.md`.",
        "format: 1",
        "sections:",
    ]
    for section in spec["sections"]:
        lines.append(f"  - key: {section['key']}")
        lines.append(f"    heading: {section['heading']}")
        if section.get("required") is False:
            lines.append("    required: false")
        if section.get("severity", "error") != "error":
            lines.append(f"    severity: {section['severity']}")
        if section.get("require_command_block"):
            lines.append("    require_command_block: true")
    return "\n".join(lines) + "\n"


def body_section(text: str, name: str) -> str:
    """Return the text under one ``## name`` heading, without the heading."""
    match = re.search(rf"^## {re.escape(name)}\s*$", text, re.M)
    if not match:
        return ""
    rest = text[match.end():]
    following = re.search(r"^## ", rest, re.M)
    return rest[: following.start()] if following else rest


def body_problems(
    text: str, spec: dict[str, Any] | None = None, *, root: Path | None = None
) -> tuple[list[str], list[str]]:
    """Check a PR body against the project body spec."""
    spec = spec or default_body_spec("en-US")
    errors: list[str] = []
    warnings: list[str] = []
    sections = spec["sections"]
    positions: list[int] = []
    for section in sections:
        heading = str(section["heading"])
        target = errors if str(section.get("severity") or "error") == "error" else warnings
        match = re.search(rf"^## {re.escape(heading)}\s*$", text, re.M)
        if match is None:
            if section.get("required", True):
                target.append(f"missing section: ## {heading}")
            continue
        positions.append(match.start())
        body = body_section(text, heading)
        if not body.strip():
            if section.get("required", True):
                target.append(f"section is empty: ## {heading}")
        command = section.get("check")
        if command and root is not None:
            code, out, err = run_hook(root, command, {"batch": "body"})
            if code != 0:
                errors.append(
                    f"## {heading} check failed (exit {code}): {err or out}"
                )
        if section.get("require_command_block") and "```" not in body and "- " not in body:
            target.append(
                f"## {heading} needs a fenced command block or a result line (- ...)"
            )
    headings = [str(section["heading"]) for section in sections]
    if len(positions) == len(headings) and positions != sorted(positions):
        errors.append(
            "sections are out of order; expected: "
            + ", ".join(f"## {heading}" for heading in headings)
        )
    without_fences = re.sub(r"```.*?```", "", text, flags=re.S)
    for match in re.finditer(r"(?<![\w(\[])#(\d+)\b", without_fences):
        number = match.group(1)
        errors.append(f"bare issue reference: #{number} (write [#{number}](url))")
    return errors, warnings


def cmd_body(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    path = Path(args.file) if args.file else batch_dir(root, batch_id) / "pr-body.md"
    path = path if path.is_absolute() else root / path
    if not path.is_file():
        print(f"body not found: {path}", file=sys.stderr)
        return 2
    errors, warnings = body_problems(
        path.read_text(encoding="utf-8"), load_body_spec(root), root=root
    )
    for problem in errors:
        print(problem, file=sys.stderr)
    for problem in warnings:
        print(f"[warn] {problem}", file=sys.stderr)
    print(f"body lint: {len(errors)} problem(s)")
    if warnings:
        print(f"body lint: {len(warnings)} warning(s)")
    return 1 if errors else 0


def normalize_body(text: str) -> str:
    lines = text.replace("\r\n", "\n").split("\n")
    return "\n".join(line.rstrip() for line in lines).strip("\n")


def config_fingerprint(root: Path) -> str:
    path = root / CONFIG_REL
    if not path.is_file():
        return "none"
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def cmd_verify_body(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    expected = state.get("pr_body_sha256_normalized")
    if not expected:
        print(
            f"no prepared body for {batch_id}; run: batch.py pr {batch_id} --prepare",
            file=sys.stderr,
        )
        return 2
    if args.body:
        path = Path(args.body)
        path = path if path.is_absolute() else root / path
        if not path.is_file():
            print(f"body not found: {path}", file=sys.stderr)
            return 2
        text = path.read_text(encoding="utf-8")
    else:
        config = load_config(root)
        command = config.get("pr_view") or []
        if not command:
            print("config.pr_view is empty; pass --body <file>", file=sys.stderr)
            return 2
        pr = args.pr or state.get("pr") or (state.get("prs") or [None])[-1]
        if not pr:
            print("no pull request recorded; pass --pr <number>", file=sys.stderr)
            return 2
        code, out, err = run_hook(root, command, {"pr": str(pr)})
        if code != 0:
            print(f"pr_view failed (exit {code})", file=sys.stderr)
            if err.strip():
                print(err.strip()[-500:], file=sys.stderr)
            return 1
        text = out
    digest = hashlib.sha256(normalize_body(text).encode("utf-8")).hexdigest()
    if digest == expected:
        print(f"verified {batch_id}: the remote body matches the prepared body")
        return 0
    print(
        f"the remote body differs from the prepared body; "
        f"re-run: batch.py pr {batch_id} --prepare",
        file=sys.stderr,
    )
    return 1


def cmd_pr(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    mismatch = batch_branch_mismatch(root, state, batch_id)
    if mismatch:
        print(mismatch, file=sys.stderr)
        return 1
    if args.mark_created:
        if args.prepare or args.create:
            print(
                "--mark-created cannot be combined with --prepare or --create",
                file=sys.stderr,
            )
            return 2
        if not args.pr:
            print("--mark-created needs --pr <number>", file=sys.stderr)
            return 2
        if state.get("status") not in {"pr_ready", "pr_created"}:
            print("prepare the body first: run 'pr <id> --prepare'", file=sys.stderr)
            return 1
        record_pr(state, str(args.pr))
        state["status"] = "pr_created"
        state["pr_created_at"] = state.get("pr_created_at") or utc_now()
        state["review_at"] = state.get("review_at") or utc_now()
        write_json(batch_dir(root, batch_id) / "state.json", state)
        print(f"marked {batch_id} created (PR {args.pr})")
        return 0
    if state.get("status") not in {"checked", "pr_ready"}:
        print("run 'check' successfully before preparing a PR", file=sys.stderr)
        return 1
    card = read_card(root, batch_id)
    if card.get("legacy"):
        print("legacy cards have no PR flow", file=sys.stderr)
        return 1
    config = load_config(root)
    recorded = state.get("check_inputs") or {}
    if recorded.get("card") and recorded["card"] != card_hash(card)[:12]:
        print(
            f"warning: card changed since the last check "
            f"({recorded['card']}); re-run: batch.py check {batch_id}",
            file=sys.stderr,
        )
    rule = commit_rule(root, config)
    subject = str(card.get("pr_title") or card.get("goal", batch_id)).strip()
    title = subject
    if rule["enabled"]:
        kind = str(card.get("type", ""))
        if rule["types"] and kind not in rule["types"]:
            print(
                f"card type '{kind}' is not a commit type; use one of: "
                f"{', '.join(rule['types'])}",
                file=sys.stderr,
            )
            return 1
        scope = str(card.get("git_scope") or "").strip()
        if rule["scopes"] and not scope:
            print(
                "card.git_scope is required when git scopes are configured; "
                f"choose one of: {', '.join(rule['scopes'])}",
                file=sys.stderr,
            )
            return 1
        if scope and rule["scopes"] and scope not in rule["scopes"]:
            print(
                f"card.git_scope '{scope}' is not one of: "
                f"{', '.join(rule['scopes'])}",
                file=sys.stderr,
            )
            return 1
        if scope:
            title = f"{kind}({scope}): {subject}"
        else:
            title = f"{kind}: {subject}"
    approval = load_json(batch_dir(root, batch_id) / "approval.json")
    if approval is None or approval.get("card_hash") != card_hash(card):
        print("card is not approved (or approval is stale)", file=sys.stderr)
        return 1
    current, message = source_is_current(root, card)
    if not current:
        print(message, file=sys.stderr)
        return 1
    source: Path | None = None
    if args.body_from:
        source = Path(args.body_from)
        source = source if source.is_absolute() else root / source
        if not source.is_file():
            print(f"body source not found: {source}", file=sys.stderr)
            return 2
        payload = source.read_text(encoding="utf-8")
    else:
        payload = pr_body(root, batch_id) + "\n"
    body_path = Path(args.body_file) if args.body_file else (batch_dir(root, batch_id) / "pr-body.md")
    body_path = body_path if body_path.is_absolute() else root / body_path
    if not inside_project(root, body_path):
        print(f"body output must stay inside the project: {body_path}", file=sys.stderr)
        return 2
    if source is not None and body_path.resolve() == source.resolve():
        print("--body-from and --body-out point at the same file", file=sys.stderr)
        return 2
    errors, warnings = body_problems(payload, load_body_spec(root), root=root)
    for problem in warnings:
        print(f"[warn] {problem}", file=sys.stderr)
    if errors:
        for problem in errors:
            print(problem, file=sys.stderr)
        print(
            "the body does not match the template; regenerate it with --prepare "
            "or fix the source",
            file=sys.stderr,
        )
        return 1
    write_text(body_path, payload)
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    shown = source_relative(root, body_path)
    print(f"prepared {shown}")
    print(f"body hash: {digest[:8]}")
    state["status"] = "pr_ready"
    state["pr_ready_at"] = state.get("pr_ready_at") or utc_now()
    state["pr_body"] = shown
    state["pr_body_sha256"] = digest
    state["pr_body_sha256_normalized"] = hashlib.sha256(
        normalize_body(payload).encode("utf-8")
    ).hexdigest()
    state["pr_title"] = title
    state["pr_translations"] = pr_translations(
        root, batch_id, body_path, digest, config, state
    )
    if card.get("skills"):
        skills_path = batch_dir(root, batch_id) / "pr-skills.md"
        write_text(skills_path, pr_skills(root, batch_id))
        state["pr_skills"] = skills_path.relative_to(root).as_posix()
        print(f"skills report: {state['pr_skills']}")
    write_json(batch_dir(root, batch_id) / "state.json", state)

    if not args.create:
        return 0
    if args.confirm != digest[:8]:
        print(f"confirm mismatch: expected {digest[:8]}", file=sys.stderr)
        return 1
    command = config.get("pr_create")
    if not command:
        print("config.pr_create is empty; use --prepare only", file=sys.stderr)
        return 2
    code, out, err = run_hook(
        root,
        command,
        {
            "id": batch_id,
            "title": title,
            "body": str(body_path),
            "branch": str(state.get("branch", "")),
            "root": str(root),
        },
    )
    if out:
        print(out)
    if err:
        print(err, file=sys.stderr)
    if code != 0:
        return 1
    state["status"] = "pr_created"
    state["pr_output"] = out
    state["pr_created_at"] = state.get("pr_created_at") or utc_now()
    state["review_at"] = state.get("review_at") or utc_now()
    write_json(batch_dir(root, batch_id) / "state.json", state)
    print(f"created PR for {batch_id}")
    return 0


def exit_record_draft(
    card: dict[str, Any], state: dict[str, Any], batch_id: str
) -> str:
    """Build an exit record skeleton from the card and the batch state."""
    scope = state.get("scope") or {}
    budget = int(scope.get("budget") or card.get("size_budget") or 0)
    changed = int(scope.get("changed") or 0)
    lines_changed = int(scope.get("added") or 0) + int(scope.get("deleted") or 0)
    forced = "yes" if state.get("check_override") else "no"
    pr_numbers = [str(item) for item in state.get("prs", [])]
    if state.get("pr") and str(state["pr"]) not in pr_numbers:
        pr_numbers.insert(0, str(state["pr"]))
    prs_cell = ", ".join(f"#{item}" for item in pr_numbers) if pr_numbers else "#fill"
    today = str(state.get("merged_at") or utc_now())[:10]
    rows = [
        f"# {batch_id} — Exit record",
        "",
        "## Result",
        "",
        "pass"
        if state.get("status") == "merged"
        and all(
            str(item.get("status", "fail")) == "pass"
            for item in (state.get("checks") or {}).values()
        )
        else "fail",
        "",
        "## Checks",
        "",
    ]
    check_results = state.get("checks") or {}
    if check_results:
        for name, item in check_results.items():
            rows.append(f"- {name}: {str(item.get('status', 'fail')).upper()}")
    else:
        rows.append("- fill")
    rows += [
        "",
        "## Delivery",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| PR | {prs_cell} |",
        "| Commit | `fill` |",
        f"| Merged at | {today} |",
        "| By | @fill |",
        f"| Merge | {state.get('merge_mode') or 'squash'} |",
        f"| Forced | {forced} |",
    ]
    if forced == "yes":
        reason = str((state.get("check_override") or {}).get("reason", ""))
        rows.append(f"| Force reason | {reason or 'fill'} |")
    rows += [
        "",
        "## Traceability",
        "",
        "- `REQ-fill`",
        "- `TC-fill`",
        "",
        "## Acceptance",
        "",
        "| # | Criterion | Evidence | Result |",
        "|---|---|---|---|",
    ]
    criteria = card.get("acceptance") or []
    for index, item in enumerate(criteria, 1):
        rows.append(f"| {index} | {item} | fill | fill |")
    if not criteria:
        rows.append("| 1 | fill | fill | fill |")
    rows += ["", "## Skills", "", "| Skill | Plan | Actual | Evidence |", "|---|---|---|---|"]
    records = state.get("skill_evidence") or {}
    for item in card.get("skills") or []:
        skill_id = str(item.get("id", ""))
        record = records.get(skill_id) or {}
        plan = "required" if item.get("required") else "optional"
        actual = record.get("status") or "fill"
        proof = record.get("proof") or "fill"
        rows.append(f"| {skill_id} | {plan} | {actual} | {proof} |")
    if not card.get("skills"):
        rows.append("| fill | fill | fill | fill |")
    rows += ["", "## Changelog", ""]
    fragments = card.get("changelog") or []
    rows += [f"- `{item}` — fill" for item in fragments] or ["- fill"]
    rows += [
        "",
        "## Scope",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Budget | {budget} |",
        f"| Changed | {lines_changed} |",
        f"| Result | {'pass' if scope.get('result') == 'pass' else 'fail'} |",
        "",
        "## Deviations",
        "",
    ]
    override = state.get("budget_override") or None
    if override:
        rows.append(
            f"- budget override: {override.get('lines')} lines over "
            f"{override.get('budget')} — {override.get('reason')}"
        )
    else:
        rows.append("- none")
    rows += ["", "## Follow-ups", "", "- none", ""]
    return "\n".join(rows)


EXIT_SECTIONS = (
    "Result",
    "Checks",
    "Delivery",
    "Traceability",
    "Acceptance",
    "Skills",
    "Changelog",
    "Scope",
    "Deviations",
    "Follow-ups",
)


def exit_record_problems(text: str) -> list[str]:
    """Check an exit record against the delivery contract."""
    problems: list[str] = []
    for name in EXIT_SECTIONS:
        if not re.search(rf"^## {re.escape(name)}\s*$", text, re.M):
            problems.append(f"missing section: ## {name}")
    result = body_section(text, "Result").strip().lower()
    if result not in {"pass", "fail"}:
        problems.append("Result must be 'pass' or 'fail'")
    checks = body_section(text, "Checks")
    if not re.search(r"^- \S.*: (PASS|FAIL|SKIP)\b", checks, re.M):
        problems.append("Checks needs at least one '- <name>: PASS|FAIL|SKIP' line")
    delivery = body_section(text, "Delivery")
    for field in ("PR", "Commit", "Merged at", "By", "Merge", "Forced"):
        if not re.search(rf"^\| {re.escape(field)} \| .+ \|$", delivery, re.M):
            problems.append(f"Delivery needs a '{field}' row")
    merge = re.search(r"^\| Merge \| (.+?) \|$", delivery, re.M)
    if merge and merge.group(1).strip().lower() not in {
        "squash",
        "merge",
        "rebase",
        "external",
    }:
        problems.append(
            f"Delivery Merge must be squash, merge, rebase, or external "
            f"(got {merge.group(1).strip()})"
        )
    forced = re.search(r"^\| Forced \| (.+?) \|$", delivery, re.M)
    if forced and forced.group(1).strip().lower() not in {"yes", "no"}:
        problems.append("Delivery Forced must be yes or no")
    if forced and forced.group(1).strip().lower() == "yes":
        if not re.search(r"^\| Force reason \| .+ \|$", delivery, re.M):
            problems.append("Forced=yes needs a Force reason row")
    scope = body_section(text, "Scope")
    for field in ("Budget", "Changed"):
        match = re.search(rf"^\| {field} \| (.+?) \|$", scope, re.M)
        if match is None:
            problems.append(f"Scope needs a '{field}' row")
        elif not match.group(1).strip().isdigit():
            problems.append(f"Scope {field} must be a number")
    unfilled = re.findall(r"\bfill\b", text)
    if unfilled:
        problems.append(
            f"{len(unfilled)} unfilled placeholder(s); replace every 'fill'"
        )
    return problems


def update_records_index(
    docs_root: Path, batch_id: str, record: Path, state: dict[str, Any]
) -> str:
    readme = docs_root / DOCS_RECORDS / "README.md"
    if not readme.is_file():
        return "index: records/README.md not found; skipped"
    lines = readme.read_text(encoding="utf-8").splitlines()
    header = next(
        (i for i, line in enumerate(lines) if line.strip().startswith("| 批次 |")),
        None,
    )
    if header is None:
        return "index: no '| 批次 |' table; skipped"
    name = record.name
    for line in lines[header + 1 :]:
        if line.strip().startswith("|") and name in line:
            return f"index: {name} already listed"
    cells = [
        f"`{batch_id}`",
        utc_now()[:10],
        source_relative(docs_root, record),
        "live",
        str(state.get("commit") or "-"),
        "-",
        "frozen" if state.get("status") == "frozen" else "live",
    ]
    insert_at = header + 1
    for index in range(header + 1, len(lines)):
        if lines[index].strip().startswith("|"):
            insert_at = index + 1
        else:
            break
    lines.insert(insert_at, "| " + " | ".join(cells) + " |")
    readme.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return f"index: added {name}"


def cmd_exit(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    if args.lint:
        path = Path(args.lint)
        path = path if path.is_absolute() else root / path
        if not path.is_file():
            print(f"record not found: {path}", file=sys.stderr)
            return 2
        problems = exit_record_problems(path.read_text(encoding="utf-8"))
        for problem in problems:
            print(problem, file=sys.stderr)
        print(f"exit lint: {len(problems)} problem(s)")
        return 1 if problems else 0
    batch_id = resolve_id(root, args.id)
    card = read_card(root, batch_id)
    state = read_state(root, batch_id)
    config = load_config(root)
    docs_root = configured_docs_root(root, config)
    if docs_root is None:
        source = card_source_path(root, card)
        docs_root = docs_root_from_card(source) if source else None
    target = Path(args.out) if args.out else None
    if target is None:
        if docs_root is None:
            print("docs repo not found; pass --out <path>", file=sys.stderr)
            return 2
        target = docs_root / DOCS_RECORDS / "live" / f"{batch_id}-exit.md"
    if args.mark:
        if not target.is_file():
            print(f"record not found: {target}", file=sys.stderr)
            return 2
        problems = exit_record_problems(target.read_text(encoding="utf-8"))
        for problem in problems:
            print(problem, file=sys.stderr)
        if problems:
            print(f"exit lint: {len(problems)} problem(s)")
            return 1
        status = str(state.get("status") or "")
        if status not in {"merged", "exited", "frozen"}:
            print(
                f"batch {batch_id} is {status or 'unknown'}; "
                "mark the exit after the merge",
                file=sys.stderr,
            )
            return 1
        state["exit_record"] = source_relative(root, target)
        state["exited_at"] = state.get("exited_at") or utc_now()
        state["status"] = "frozen" if args.frozen else "exited"
        if args.frozen:
            state["frozen_at"] = utc_now()
        write_json(batch_dir(root, batch_id) / "state.json", state)
        print(f"marked {batch_id} {state['status']}")
        if docs_root is not None:
            print(update_records_index(docs_root, batch_id, target, state))
        return 0
    if target.exists() and not args.force:
        print(f"{target} exists; pass --force to overwrite", file=sys.stderr)
        return 1
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(exit_record_draft(card, state, batch_id) + "\n", encoding="utf-8")
    print(f"drafted {target}")
    print("fill the remaining fields, then run check_records.py")
    return 0


def sdp_table(path: Path) -> tuple[int, list[str]] | None:
    """Return the line index and header cells of the SDP batch table."""
    lines = path.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip().strip("`") for cell in stripped.strip("|").split("|")]
        if cells and cells[0].lower() == "batch":
            return index, [cell.strip() for cell in stripped.strip("|").split("|")]
    return None


def sdp_row(batch_id: str, card: dict[str, Any], columns: int) -> str:
    scope = str(card.get("goal") or "").strip() or "fill"
    cells = [f"`{batch_id}`", scope]
    cells += ["—"] * max(0, columns - len(cells))
    return "| " + " | ".join(cells[:columns]) + " |"


def cmd_sdp(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    card_path = Path(args.card)
    card_path = card_path if card_path.is_absolute() else root / card_path
    if not card_path.is_file():
        print(f"card not found: {card_path}", file=sys.stderr)
        return 2
    match = CARD_JSON_RE.search(card_path.read_text(encoding="utf-8"))
    if match is None:
        print("card has no ```json block", file=sys.stderr)
        return 2
    try:
        card = json.loads(match.group(1))
    except json.JSONDecodeError as error:
        print(f"card json is invalid: {error}", file=sys.stderr)
        return 2
    batch_id = str(card.get("id", "")).strip()
    if not CARD_ID_RE.fullmatch(batch_id):
        print(f"card id is not a batch id: {batch_id!r}", file=sys.stderr)
        return 2
    docs_root = Path(args.docs) if args.docs else None
    if docs_root is None:
        docs_root = configured_docs_root(root, load_config(root))
    if docs_root is None:
        docs_root = docs_root_from_card(card_path)
    if docs_root is None:
        print("docs repo not found; pass --docs <path>", file=sys.stderr)
        return 2
    sdp = docs_root / DOCS_PROCESS / DOCS_SDP
    if not sdp.is_file():
        print(f"SDP not found: {sdp}", file=sys.stderr)
        return 2
    table = sdp_table(sdp)
    if table is None:
        print(f"no '| Batch |' table in {sdp}", file=sys.stderr)
        return 2
    header_index, header = table
    lines = sdp.read_text(encoding="utf-8").splitlines()
    for line in lines[header_index + 1 :]:
        if not line.strip().startswith("|"):
            break
        cells = [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]
        if cells and cells[0] == batch_id:
            print(f"{batch_id} is already in the SDP batch table", file=sys.stderr)
            return 1
    row = sdp_row(batch_id, card, len(header))
    last = header_index
    for index in range(header_index + 1, len(lines)):
        if not lines[index].strip().startswith("|"):
            break
        last = index
    if not args.apply:
        print(row)
        print("(pass --apply to insert it after the last batch row)")
        return 0
    lines.insert(last + 1, row)
    sdp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"added {batch_id} to {sdp}")
    print("run check_plan.py on the SDP")
    return 0


def record_pr(state: dict[str, Any], number: object) -> None:
    """Record one PR number; the first one is kept as the primary."""
    value = str(number or "").strip()
    if not value:
        return
    numbers = [str(item) for item in state.get("prs", [])]
    if value not in numbers:
        numbers.append(value)
    state["prs"] = numbers
    state.setdefault("pr", value)


def cmd_verify_merge(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    status = str(state.get("status") or "")
    if status not in {"merged", "exited", "frozen"}:
        print(
            f"batch {batch_id} is {status or 'unknown'}; verify after the merge",
            file=sys.stderr,
        )
        return 1
    if args.fetch:
        code, out, err = run_git(root, ["fetch", "--quiet", args.remote])
        if code != 0:
            print(err.strip() or out.strip() or "git fetch failed", file=sys.stderr)
            return 1
    code, out, _ = run_git(root, ["rev-parse", "--verify", args.ref])
    if code != 0:
        print(f"cannot resolve {args.ref}", file=sys.stderr)
        return 1
    commit = out.strip()
    _, subject, _ = run_git(root, ["log", "-1", "--format=%s", commit])
    _, body, _ = run_git(root, ["log", "-1", "--format=%B", commit])
    problems: list[str] = []
    warnings: list[str] = []
    expected = str(state.get("pr_title") or "").strip()
    if expected and subject.strip() != expected:
        problems.append(
            f"subject is {subject.strip()!r}, expected {expected!r}"
        )
    numbers = [str(item) for item in state.get("prs", [])]
    if state.get("pr") and str(state["pr"]) not in numbers:
        numbers.insert(0, str(state["pr"]))
    combined = f"{subject}\n{body}"
    for number in numbers:
        if f"#{number}" not in combined:
            warnings.append(f"PR #{number} is not mentioned in the merge commit")
    if problems:
        for item in problems:
            print(f"verify-merge: {item}", file=sys.stderr)
        print(
            f"verify-merge: {args.ref} tip {commit[:12]} does not match the batch",
            file=sys.stderr,
        )
        return 1
    state["verified_merge"] = {
        "ref": args.ref,
        "commit": commit,
        "subject": subject.strip(),
        "checked_at": utc_now(),
    }
    write_json(batch_dir(root, batch_id) / "state.json", state)
    for item in warnings:
        print(f"warning: {item}", file=sys.stderr)
    print(f"verified {batch_id}: {args.ref} tip {commit[:12]} {subject.strip()}")
    return 0


PRODUCTION_SECTIONS = ("Scope", "Version", "Scenarios", "Sign-off")



def cmd_merge(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    if not args.yes:
        print("merge requires --yes", file=sys.stderr)
        return 2
    config = load_config(root)
    command = config.get("merge")
    external = not command
    if command and args.external:
        print(
            "--external is only valid when config.merge is empty",
            file=sys.stderr,
        )
        return 2
    status = state.get("status")
    if args.force and not external:
        print("--force is only valid with --external", file=sys.stderr)
        return 2
    if status not in {"checked", "pr_ready", "pr_created"}:
        if not (external and status == "check_failed" and args.force):
            if external and status == "check_failed":
                print(
                    "batch check failed; an external merge needs "
                    "--force --reason <why the failure is accepted>",
                    file=sys.stderr,
                )
            else:
                print("batch is not checked or PR-ready", file=sys.stderr)
            return 1
        if not args.reason.strip():
            print("--force requires --reason", file=sys.stderr)
            return 2
    if external:
        if not args.pr:
            print(
                "no merge command is configured; pass --pr <number> to record "
                "an external merge",
                file=sys.stderr,
            )
            return 2
        override = None
        if status == "check_failed":
            override = {
                "from": status,
                "reason": args.reason.strip(),
                "at": utc_now(),
            }
        state["status"] = "merged"
        state["merged_at"] = utc_now()
        state["merge_mode"] = "external"
        record_pr(state, args.pr)
        for extra in getattr(args, "also_pr", None) or []:
            record_pr(state, extra)
        if override is not None:
            state["check_override"] = override
        write_json(batch_dir(root, batch_id) / "state.json", state)
        clear_active(root)
        suffix = " after a forced check failure" if override is not None else ""
        print(
            f"merged {batch_id} externally (PR {', '.join(state['prs'])}){suffix}"
        )
        return 0
    if status != "pr_created":
        print("batch has no created PR", file=sys.stderr)
        return 1
    code, out, err = run_hook(
        root,
        command,
        {
            "id": batch_id,
            "title": batch_id,
            "body": "",
            "branch": str(state.get("branch", "")),
            "root": str(root),
            "pr": args.pr,
        },
    )
    if out:
        print(out)
    if err:
        print(err, file=sys.stderr)
    if code != 0:
        return 1
    merged_problems = check_merged_commit(root, config)
    for item in merged_problems:
        print(f"warning: merged commit: {item}", file=sys.stderr)
    state["status"] = "merged"
    state["merged_at"] = utc_now()
    record_pr(state, args.pr)
    for extra in getattr(args, "also_pr", None) or []:
        record_pr(state, extra)
    write_json(batch_dir(root, batch_id) / "state.json", state)
    clear_active(root)
    print(f"merged {batch_id}")
    return 0


def cmd_abort(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    status_before = str(state.get("status") or "")
    if state.get("status") == "merged":
        print("cannot abort a merged batch", file=sys.stderr)
        return 1
    branch = str(state.get("branch") or "")
    base_ref = str(state.get("base_ref") or "")
    switched_to = ""
    if branch and state.get("branch_created") is True and current_branch(root) == branch:
        code, status_out, _ = run_git(
            root, ["status", "--porcelain", "--", ".", f":(exclude){STATE_DIR}"]
        )
        if code == 0 and not status_out:
            target = base_ref or str(state.get("base") or "")
            if target:
                switch_code, _, switch_err = run_git(root, ["switch", target])
                if switch_code == 0:
                    switched_to = target
                else:
                    print(
                        f"could not switch back to {target}: {switch_err} "
                        f"(the branch {branch} is kept)",
                        file=sys.stderr,
                    )
        else:
            print(
                f"working tree has changes; still on {branch}. "
                "Commit or stash them, then run: git switch "
                f"{base_ref or '<base>'}",
                file=sys.stderr,
            )
    state["status"] = "aborted"
    state["aborted_at"] = utc_now()
    state["status_before_abort"] = status_before
    if getattr(args, "reason", None):
        state["abort_reason"] = str(args.reason)
    write_json(batch_dir(root, batch_id) / "state.json", state)
    stamp = re.sub(r"[^0-9]", "", utc_now())[:14]
    abort_note = [
        f"# Aborted {batch_id}",
        "",
        f"- at: {utc_now()}",
        f"- status before abort: {status_before or 'unknown'}",
        f"- branch: {branch or '-'}",
        f"- base: {base_ref or state.get('base') or '-'}",
        f"- reason: {getattr(args, 'reason', None) or '-'}",
        f"- evidence kept under: .batch/{batch_id}/",
        "",
    ]
    (batch_dir(root, batch_id) / "abort.md").write_text(
        "\n".join(abort_note), encoding="utf-8", newline="\n"
    )
    if active_id(root) == batch_id:
        clear_active(root)
    print(f"aborted {batch_id}")
    print(f"evidence kept: .batch/{batch_id}/")
    if switched_to:
        print(f"switched back to {switched_to}")
    if branch:
        print(f"branch kept: {branch}")
    return 0


def cmd_recard(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    status = str(state.get("status") or "")
    if status == "merged":
        print("cannot recard a merged batch", file=sys.stderr)
        return 1
    source = Path(args.source)
    source = source if source.is_absolute() else root / source
    source = source.resolve()
    if not source.is_file():
        print(f"card source not found: {source}", file=sys.stderr)
        return 2
    config = load_config(root)
    rule = commit_rule(root, config)
    types = set(rule["types"]) if rule["enabled"] else None
    try:
        card, _ = read_planned_card(source, types=types)
    except ValueError as exc:
        print(f"invalid card: {exc}", file=sys.stderr)
        return 1
    issues = card_issues(card, path=source, types=types)
    if issues:
        for issue in issues:
            print(issue, file=sys.stderr)
        print(f"recard: {len(issues)} error(s)", file=sys.stderr)
        return 1
    if str(card.get("id", "")) != batch_id:
        print(
            f"card id {card.get('id')} does not match the batch {batch_id}",
            file=sys.stderr,
        )
        return 1
    directory = batch_dir(root, batch_id)
    previous = load_json(directory / "card.json") or {}
    changed = [
        key
        for key in sorted(set(previous) | set(card))
        if key not in {"source", "source_sha256"} and previous.get(key) != card.get(key)
    ]
    if not changed:
        print(f"recard {batch_id}: no field changed")
        return 0
    stamp = re.sub(r"[^0-9]", "", utc_now())[:14]
    if (directory / "card.json").is_file():
        shutil.copy2(directory / "card.json", directory / f"card.{stamp}.json")
    (directory / "approval.json").unlink(missing_ok=True)
    snapshot = dict(card)
    snapshot["source"] = source_relative(root, source)
    snapshot["source_sha256"] = source_card_hash(source)
    write_json(directory / "card.json", snapshot)
    state["recard"] = list(state.get("recard") or []) + [
        {
            "at": utc_now(),
            "from_status": status,
            "changed": changed,
            "reason": str(getattr(args, "reason", "") or ""),
        }
    ]
    state["status"] = "planned"
    write_json(directory / "state.json", state)
    record_approval(
        root, batch_id, "cleared", reason=str(getattr(args, "reason", "") or "recard")
    )
    print(f"recard {batch_id}: {', '.join(changed)}")
    print(f"evidence kept under .batch/{batch_id}/evidence")
    if previous.get("base") and previous.get("base") != card.get("base"):
        print(
            f"base changed from {previous.get('base')} to {card.get('base')}; "
            "the branch is still cut from the old base"
        )
    print(f"approval cleared; run: batch.py approve {batch_id} --last")
    return 0


def cmd_pause(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    status = str(state.get("status") or "")
    if status == "paused":
        print(f"{batch_id} is already paused")
        return 0
    if status not in PAUSABLE_STATUSES:
        print(f"cannot pause a {status} batch", file=sys.stderr)
        return 1
    state["paused_from"] = status
    state["status"] = "paused"
    state["paused_at"] = utc_now()
    head = ""
    code, out, _ = run_git(root, ["rev-parse", "HEAD"])
    if code == 0:
        head = out.strip()
    checks = state.get("checks") or []
    failed = 0
    for item in checks:
        if isinstance(item, dict):
            if str(item.get("status", "")).upper() != "PASS":
                failed += 1
        elif isinstance(item, str) and "PASS" not in item:
            failed += 1
    state["paused"] = {
        "at": state["paused_at"],
        "from": status,
        "head": head,
        "last_check": {
            "at": state.get("checked_at", ""),
            "status": status,
            "failed": failed,
        },
    }
    write_json(batch_dir(root, batch_id) / "state.json", state)
    if active_id(root) == batch_id:
        clear_active(root)
    branch = str(state.get("branch") or "")
    print(f"paused {batch_id} ({status})")
    if branch:
        print(f"branch: {branch}")
    print("work stays where it is; park it with 'git commit' or 'git stash'")
    print(f"resume with: batch.py resume {batch_id}")
    return 0


def cmd_resume(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    git_required(root)
    batch_id = resolve_id(root, args.id)
    state = read_state(root, batch_id)
    status = str(state.get("status") or "")
    if status != "paused":
        print(f"batch is not paused: {status}", file=sys.stderr)
        return 1
    branch = str(state.get("branch") or "")
    if not branch:
        print("state has no branch; cannot resume", file=sys.stderr)
        return 1
    if not branch_exists(root, branch):
        print(
            f"branch is gone: {branch}; abort the batch and plan it again",
            file=sys.stderr,
        )
        return 1
    other = active_id(root)
    if other and other != batch_id:
        print(f"another batch is active: {other}", file=sys.stderr)
        return 1
    card = read_card(root, batch_id)
    if card_hash(card) != state.get("card_hash"):
        print("card changed since start; re-approve it before resuming", file=sys.stderr)
        return 1
    current, message = source_is_current(root, card)
    if not current:
        print(message, file=sys.stderr)
        return 1
    code, _, err = run_git(root, ["switch", branch])
    if code != 0:
        print(f"could not switch to {branch}: {err}", file=sys.stderr)
        return 1
    state["status"] = str(state.get("paused_from") or "started")
    state["resumed_at"] = utc_now()
    write_json(batch_dir(root, batch_id) / "state.json", state)
    set_active(root, batch_id)
    paused = state.get("paused") or {}
    if paused:
        print(f"was paused at {paused.get('at', '?')} from {paused.get('from', '?')}")
        head = str(paused.get("head") or "")
        if head:
            code, out, _ = run_git(root, ["rev-parse", "HEAD"])
            now = out.strip() if code == 0 else ""
            if now and now != head:
                print(
                    f"warning: HEAD moved since pause: {head[:8]}..{now[:8]}",
                    file=sys.stderr,
                )
        last = paused.get("last_check") or {}
        if last.get("status"):
            failed = int(last.get("failed") or 0)
            print(
                f"last check: {last.get('status')} at {last.get('at', '?')}"
                + (f" ({failed} failed)" if failed else "")
            )
    print(f"resumed {batch_id} on {branch} ({state['status']})")
    return 0


def cmd_adopt(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    source = Path(args.source)
    source = source if source.is_absolute() else root / source
    source = source.resolve()
    if not source.is_file():
        print(f"card source not found: {source}", file=sys.stderr)
        return 2
    batch_id = args.id or source.stem
    if not CARD_ID_RE.fullmatch(batch_id):
        print("legacy id must be B followed by digits", file=sys.stderr)
        return 2
    target = batch_dir(root, batch_id)
    if target.exists() and not archive_aborted(root, batch_id):
        print(f"batch already exists: {batch_id}", file=sys.stderr)
        return 1
    snapshot = {
        "id": batch_id,
        "legacy": True,
        "source": source_relative(root, source),
        "source_sha256": file_sha256(source),
    }
    write_json(target / "card.json", snapshot)
    print(f"adopted {batch_id} as read-only legacy")
    print(f"source: {snapshot['source']}")
    return 0


EXPORT_FORMAT = 1


def cmd_export(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    batch_id = resolve_id(root, args.id)
    directory = batch_dir(root, batch_id)
    files: dict[str, str] = {}
    for path in sorted(directory.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(directory).as_posix()
        try:
            files[relative] = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            print(f"skipping binary file: {relative}", file=sys.stderr)
    payload = {
        "format": EXPORT_FORMAT,
        "batch": batch_id,
        "exported_at": utc_now(),
        "files": files,
    }
    if args.out:
        target = Path(args.out)
        if not target.is_absolute():
            target = root / target
    else:
        stamp = re.sub(r"[^0-9]", "", utc_now())[:14]
        target = state_root(root) / "exports" / f"{batch_id}-{stamp}.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"exported {batch_id}: {len(files)} file(s) -> {source_relative(root, target)}")
    return 0


def cmd_import(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    source = Path(args.file)
    if not source.is_absolute():
        source = root / source
    if not source.is_file():
        print(f"bundle not found: {source}", file=sys.stderr)
        return 2
    try:
        payload = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"cannot read the bundle: {exc}", file=sys.stderr)
        return 2
    if payload.get("format") != EXPORT_FORMAT:
        print("unsupported bundle format", file=sys.stderr)
        return 2
    batch_id = str(payload.get("batch") or "")
    if not ID_RE.match(batch_id):
        print(f"invalid batch id in the bundle: {batch_id!r}", file=sys.stderr)
        return 2
    files = payload.get("files")
    if not isinstance(files, dict) or not files:
        print("the bundle has no files", file=sys.stderr)
        return 2
    directory = batch_dir(root, batch_id)
    if directory.exists() and not args.force:
        print(
            f"batch {batch_id} already exists; pass --force to overwrite",
            file=sys.stderr,
        )
        return 1
    for relative, text in files.items():
        parts = Path(relative).parts
        if not parts or ".." in parts or Path(relative).is_absolute():
            print(f"refusing unsafe path: {relative}", file=sys.stderr)
            return 2
        target = directory / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(str(text), encoding="utf-8")
    print(f"imported {batch_id}: {len(files)} file(s)")
    state_path = directory / "state.json"
    if state_path.is_file():
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            state = {}
        if str(state.get("status")) in {"planned", "approved", "started", "checked", "pr_ready", "pr_created", "paused"}:
            set_active(root, batch_id)
            print(f"active: {batch_id}")
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    root_dir = state_root(root)
    if not root_dir.is_dir():
        print("no batches")
        return 0
    for path in sorted(root_dir.iterdir(), key=lambda item: batch_sort_key(item.name)):
        if not path.is_dir() or not ID_RE.fullmatch(path.name):
            continue
        state = load_json(path / "state.json") or {}
        card = load_json(path / "card.json") or {}
        status = state.get("status") or ("legacy" if card.get("legacy") else "planned")
        print(f"{path.name}\t{status}\t{card.get('goal', '')}")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    try:
        batch_id = resolve_id(root, args.id)
    except SystemExit as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print_status(root, batch_id, args.json)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="project-local batch execution skeleton")
    parser.add_argument("--root", type=Path, default=ROOT)
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan", help="create a batch card")
    plan.add_argument("id", nargs="?")
    plan.add_argument("--from", dest="source", help="plan from an external card")
    plan.add_argument("--goal")
    plan.add_argument("--type", help="batch type for an ad-hoc plan")
    plan.add_argument("--allowed", action="append")
    plan.add_argument("--forbidden", action="append")
    plan.add_argument("--exit-criterion", action="append")
    plan.set_defaults(func=cmd_plan)

    lint = sub.add_parser("lint", help="check a card source without planning it")
    lint.add_argument("card", help="path to the card markdown")
    lint.set_defaults(func=cmd_lint)

    skills = sub.add_parser("skills", help="report how often skills were used")
    skills.add_argument("action", choices=("report",))
    skills.add_argument("--last", type=int, default=20)
    skills.set_defaults(func=cmd_skills_report)

    config_cmd = sub.add_parser("config", help="check the batch configuration")
    config_cmd.add_argument("action", choices=("lint",))
    config_cmd.set_defaults(func=cmd_config)

    pitfalls = sub.add_parser("pitfalls", help="list or check pitfall entries")
    pitfalls.add_argument("action", choices=("list", "show", "check", "index"))
    pitfalls.add_argument("--step")
    pitfalls.add_argument("--id")
    pitfalls.add_argument("--out")
    pitfalls.set_defaults(func=cmd_pitfalls)

    retro = sub.add_parser(
        "retro", help="draft a retrospective and pitfall candidates for a batch"
    )
    retro.add_argument("id", nargs="?")
    retro.add_argument("--out", help="where to write the draft")
    retro.set_defaults(func=cmd_retro)

    doctor = sub.add_parser("doctor", help="list what is out of step for a batch")
    doctor.add_argument("id", nargs="?")
    doctor.set_defaults(func=cmd_doctor)

    checks = sub.add_parser("checks", help="list configured and discovered checks")
    checks.add_argument("action", choices=("list", "report"))
    checks.add_argument("--json", action="store_true")
    checks.add_argument(
        "--upstream",
        action="store_true",
        help="write .batch/checks-upstream.json instead of printing",
    )
    checks.set_defaults(func=cmd_checks)

    main_lint = sub.add_parser("main", help="lint the commit at the top of a branch")
    main_lint.add_argument("action", choices=("lint",))
    main_lint.add_argument("--ref", help="branch or ref (default: origin/main)")
    main_lint.set_defaults(func=cmd_main_lint)

    commit = sub.add_parser("commit", help="check or reflow commit messages")
    commit.add_argument("action", choices=("lint", "wrap"))
    commit.add_argument("--base", help="base ref (default: config.base)")
    commit.add_argument(
        "--apply",
        action="store_true",
        help="with wrap, rewrite the tip commit instead of printing it",
    )
    commit.set_defaults(func=cmd_commit)

    adopt = sub.add_parser("adopt", help="adopt a legacy card as read-only")
    adopt.add_argument("id", nargs="?")
    adopt.add_argument("--from", dest="source", required=True)
    adopt.set_defaults(func=cmd_adopt)

    approve = sub.add_parser("approve", help="approve a card by hash")
    approve.add_argument("id", nargs="?")
    choice = approve.add_mutually_exclusive_group()
    choice.add_argument("--confirm", help="the hash8 printed by plan")
    choice.add_argument(
        "--last",
        action="store_true",
        help="approve the current card hash without retyping it",
    )
    choice.add_argument(
        "--check",
        action="store_true",
        help="report whether the recorded approval is still current",
    )
    approve.add_argument("--by", default="")
    approve.set_defaults(func=cmd_approve)

    start = sub.add_parser("start", help="start an approved batch")
    start.add_argument("id", nargs="?")
    start.add_argument("--base")
    start.add_argument("--branch")
    start.add_argument("--no-branch", action="store_true")
    start.set_defaults(func=cmd_start)

    check = sub.add_parser("check", help="check scope and configured commands")
    check.add_argument("id", nargs="?")
    check.add_argument(
        "--release",
        action="store_true",
        help="also run config.release_checks",
    )
    check.add_argument(
        "--allow-over-budget",
        metavar="REASON",
        help="record why this batch exceeds its size budget",
    )
    check.set_defaults(func=cmd_check)

    pr = sub.add_parser("pr", help="prepare or create a PR body")
    pr.add_argument("id", nargs="?")
    pr.add_argument("--prepare", action="store_true")
    pr.add_argument("--create", action="store_true")
    pr.add_argument(
        "--mark-created",
        action="store_true",
        help="record that the pull request was opened by hand",
    )
    pr.add_argument("--pr", metavar="NUMBER", help="pull request number")
    pr.add_argument(
        "--body-out",
        "--body-file",
        dest="body_file",
        help="where to write the body (default .batch/<id>/pr-body.md)",
    )
    pr.add_argument(
        "--body-from",
        help="read the body from this file instead of generating it",
    )
    pr.add_argument("--confirm")
    pr.set_defaults(func=cmd_pr)

    verify_body = sub.add_parser(
        "verify-body", help="compare the remote PR body with the prepared body"
    )
    verify_body.add_argument("id", nargs="?")
    verify_body.add_argument("--body", help="read the remote body from this file")
    verify_body.add_argument("--pr", metavar="NUMBER", help="pull request number")
    verify_body.set_defaults(func=cmd_verify_body)

    body = sub.add_parser("body", help="lint a prepared PR body")
    body.add_argument("id", nargs="?")
    body.add_argument("--file", help="default .batch/<id>/pr-body.md")
    body.set_defaults(func=cmd_body)


    merge = sub.add_parser("merge", help="run the configured merge command")
    merge.add_argument("id", nargs="?")
    merge.add_argument(
        "--also-pr",
        action="append",
        metavar="NUMBER",
        help="record another PR that belongs to this batch (repeatable)",
    )

    verify = sub.add_parser(
        "verify-merge", help="check that the base branch tip is this batch"
    )
    verify.add_argument("id", nargs="?")
    verify.add_argument("--ref", default="origin/main", help="ref to inspect")
    verify.add_argument(
        "--fetch", action="store_true", help="run git fetch before resolving the ref"
    )
    verify.add_argument("--remote", default="origin")
    verify.set_defaults(func=cmd_verify_merge)

    sdp = sub.add_parser("sdp", help="edit the SDP batch table")
    sdp.add_argument("action", choices=("add",))
    sdp.add_argument("--card", required=True, help="card source with an id and goal")
    sdp.add_argument("--docs", help="docs repo root (default: from the config or card)")
    sdp.add_argument("--apply", action="store_true", help="write the row")
    sdp.set_defaults(func=cmd_sdp)
    merge.add_argument("--pr")
    merge.add_argument("--yes", action="store_true")
    merge.add_argument(
        "--external",
        action="store_true",
        help="record a manually merged PR; only when config.merge is empty",
    )
    merge.add_argument(
        "--force",
        action="store_true",
        help="with --external, accept a check_failed batch; requires --reason",
    )
    merge.add_argument(
        "--reason",
        default="",
        help="why a check_failed batch is accepted (recorded in state.json)",
    )
    merge.set_defaults(func=cmd_merge)

    exit_parser = sub.add_parser(
        "exit", help="draft the exit record from the card and state"
    )
    exit_parser.add_argument("id", nargs="?")
    exit_parser.add_argument(
        "--out",
        help="write here instead of <docs>/records/live/<id>-exit.md",
    )
    exit_parser.add_argument(
        "--force",
        action="store_true",
        help="overwrite an existing exit record",
    )
    exit_parser.add_argument(
        "--lint",
        metavar="PATH",
        help="lint an existing record instead of drafting",
    )
    exit_parser.add_argument(
        "--mark",
        action="store_true",
        help="after a clean lint, mark the batch exited and add its index row",
    )
    exit_parser.add_argument(
        "--frozen",
        action="store_true",
        help="with --mark, also mark the batch frozen",
    )
    exit_parser.set_defaults(func=cmd_exit)

    abort = sub.add_parser("abort", help="abort an unmerged batch")
    abort.add_argument("id", nargs="?")
    abort.add_argument("--reason", help="why the batch stopped")
    abort.set_defaults(func=cmd_abort)

    recard = sub.add_parser(
        "recard", help="replace the card of a live batch and keep its evidence"
    )
    recard.add_argument("id", nargs="?")
    recard.add_argument("--from", dest="source", required=True, help="new card path")
    recard.add_argument("--reason", help="why the card changed")
    recard.set_defaults(func=cmd_recard)

    pause = sub.add_parser("pause", help="park a batch and keep its branch")
    pause.add_argument("id", nargs="?")
    pause.set_defaults(func=cmd_pause)

    resume = sub.add_parser("resume", help="return to a paused batch")
    resume.add_argument("id", nargs="?")
    resume.set_defaults(func=cmd_resume)

    listing = sub.add_parser("list", help="list batches")
    listing.set_defaults(func=cmd_list)

    export = sub.add_parser("export", help="write a batch as one JSON bundle")
    export.add_argument("id", nargs="?")
    export.add_argument("--out", help="bundle path (default .batch/exports/<id>-<stamp>.json)")
    export.set_defaults(func=cmd_export)

    importer = sub.add_parser("import", help="restore a batch from its JSON bundle")
    importer.add_argument("file", help="bundle written by batch.py export")
    importer.add_argument("--force", action="store_true", help="overwrite an existing batch")
    importer.set_defaults(func=cmd_import)

    status = sub.add_parser("status", help="show one batch")
    status.add_argument("id", nargs="?")
    status.add_argument("--json", action="store_true")
    status.set_defaults(func=cmd_status)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    root = getattr(args, "root", None)
    if root is not None:
        workflow = scaffold_workflow(Path(root))
        if workflow != "full":
            print(
                f"error: workflow is {workflow}; the batch tool belongs to the "
                "full workflow; run: python -B tools/gate.py",
                file=sys.stderr,
            )
            return 2
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
