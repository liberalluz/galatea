#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify records/ structure, index, and frozen manifests.

Usage:
    python check_records.py <external-root> [--json] [--project <dev-root>]

Checks:
  1. records/README.md 7-column index, fixed header.
  2. Index rows <-> frozen batch files (live/ and README/manifest excluded).
  3. Each frozen batch has README.md and "未纳入本批的".
  4. If freeze-manifest.json exists, every file's sha256/bytes match.
  5. live/ is not indexed and does not need a manifest.
  6. Legacy batches without a manifest are reported as warnings, not failures.
  7. live/B<n>-exit.md records follow the batch-exit contract, including a
     Traceability section naming REQ/TC IDs, none with a reason, or a deferral,
     and a Delivery table that records the merge mode and any forced merge.
  8. <YYYY-MM>-release-* directories are release evidence, not frozen batches;
     they require release.json, release-notes.md, and README.md, and are not
     indexed.
  9. With --project <dev-root>, an exit record must repeat any budget override
     that the batch state recorded, otherwise the team cannot see why the
     batch exceeded its size budget.

Exit: 0 pass (warnings allowed) · 1 fail · 2 path error.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

INDEX_COLUMNS = ["批次", "冻结日期", "文件", "来源", "提交", "保留至", "处置"]
MANIFEST = "freeze-manifest.json"
LIVE = "live"
EXIT_SUFFIX = "-exit.md"
EXIT_NAME = re.compile(r"^B[0-9]+[a-z]?-exit\.md$")
EXIT_HEADINGS = (
    "Result",
    "Delivery",
    "Traceability",
    "Acceptance",
    "Skills",
    "Changelog",
    "Scope",
    "Deviations",
    "Follow-ups",
)
LEGACY_HEADINGS = ("Result", "Delivery")
LEGACY_MAX_BATCH = 7
ABORTED_HEADINGS = ("Result", "Delivery", "Deviations", "Follow-ups")
RESULT_VALUES = {"pass", "fail", "aborted"}
MERGE_MODES = {"squash", "merge", "rebase", "external"}
FORCED_VALUES = {"yes", "no"}
SKILL_STATUSES = {"applied", "partial", "skipped"}
SKILL_PLANS = {"required", "optional"}
BAD_EVIDENCE = ("should pass", "tested locally", "待验", "未验")
RELEASE_MARKER = "-release-v"
RELEASE_DIR = re.compile(
    r"^[0-9]{4}-[0-9]{2}-release-v"
    r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z.-]+)?$"
)
RELEASE_STATUSES = {"pending", "created", "failed", "local-only"}
HEX_RE = re.compile(r"^[0-9a-fA-F]{7,40}$")
REQ_ID = re.compile(r"\bREQ-[0-9]{2,}\b")
TC_ID = re.compile(r"\bTC-[A-Z0-9]+(?:-[A-Z0-9]+)*\b")
NONE_CLAIM = re.compile(r"\bnone\b", re.IGNORECASE)
DEFERRED_CLAIM = re.compile(r"\bdeferred\s+to\s+(B[0-9]+[a-z]?)\b", re.IGNORECASE)

LANG = "zh"


def _t(zh: str, en: str) -> str:
    """Pick the console message for the current language."""
    return zh if LANG == "zh" else en


class Result:
    def __init__(self) -> None:
        self.items: list[tuple[str, str, str]] = []

    def add(self, status: str, item: str, detail: str = "") -> None:
        self.items.append((status, item, detail))

    @property
    def failed(self) -> bool:
        return any(status == "fail" for status, _, _ in self.items)


def parse_index(text: str) -> tuple[list[str], list[list[str]]]:
    header: list[str] = []
    rows: list[list[str]] = []
    in_table = False
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            if in_table:
                break
            continue
        if set(stripped) <= {"|", "-", ":", " "}:
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if not header:
            header = cells
            in_table = True
            continue
        if in_table and cells:
            rows.append(cells)
    return header, rows


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_manifest(batch_dir: Path, result: Result) -> None:
    path = batch_dir / MANIFEST
    if not path.is_file():
        result.add(
            "warn",
            _t(f"{batch_dir.name}: 无 {MANIFEST}", f"{batch_dir.name}: no {MANIFEST}"),
            _t(
                "legacy 批次；冻结时未生成 hash 清单",
                "legacy batch; no hash manifest was generated at freeze time",
            ),
        )
        return
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        result.add(
            "fail",
            _t(f"{batch_dir.name}: manifest 不可读", f"{batch_dir.name}: manifest is unreadable"),
            str(exc),
        )
        return
    for key in ("batch", "frozen_at", "frozen_by", "source_commit", "files"):
        if key not in data:
            result.add(
                "fail",
                _t(f"{batch_dir.name}: manifest 缺字段", f"{batch_dir.name}: manifest is missing field"),
                key,
            )
    files = data.get("files")
    if not isinstance(files, dict):
        result.add(
            "fail",
            _t(
                f"{batch_dir.name}: manifest.files 非对象",
                f"{batch_dir.name}: manifest.files is not an object",
            ),
        )
        return
    actual = {
        item.name: item
        for item in batch_dir.iterdir()
        if item.is_file() and item.name not in ("README.md", MANIFEST)
    }
    for name, meta in files.items():
        item = actual.get(name)
        if item is None:
            result.add(
                "fail",
                _t(
                    f"{batch_dir.name}: manifest 列了但文件不存在",
                    f"{batch_dir.name}: listed in manifest but file is missing",
                ),
                name,
            )
            continue
        expected = meta.get("sha256") if isinstance(meta, dict) else None
        if not expected:
            result.add(
                "fail",
                _t(f"{batch_dir.name}: manifest 缺 sha256", f"{batch_dir.name}: manifest is missing sha256"),
                name,
            )
        elif sha256(item) != expected:
            result.add(
                "fail",
                _t(f"{batch_dir.name}: hash 不匹配", f"{batch_dir.name}: hash mismatch"),
                name,
            )
        size = meta.get("bytes") if isinstance(meta, dict) else None
        if isinstance(size, int) and item.stat().st_size != size:
            result.add(
                "fail",
                _t(f"{batch_dir.name}: 字节数不匹配", f"{batch_dir.name}: byte size mismatch"),
                name,
            )
    for name in sorted(set(actual) - set(files)):
        result.add(
            "fail",
            _t(
                f"{batch_dir.name}: 文件未登记进 manifest",
                f"{batch_dir.name}: file is not registered in manifest",
            ),
            name,
        )


def parse_sections(text: str) -> tuple[dict[str, str], list[str]]:
    sections: dict[str, str] = {}
    duplicates: list[str] = []
    current: str | None = None
    lines: list[str] = []
    for line in text.splitlines():
        match = re.match(r"^##\s+(.+?)\s*$", line)
        if match:
            if current is not None:
                if current in sections:
                    duplicates.append(current)
                sections[current] = "\n".join(lines).strip()
            current = match.group(1)
            lines = []
        elif current is not None:
            lines.append(line)
    if current is not None:
        if current in sections:
            duplicates.append(current)
        sections[current] = "\n".join(lines).strip()
    return sections, duplicates


def section_value(section: str) -> str:
    for line in section.splitlines():
        if line.strip():
            return line.strip()
    return ""


def clean_value(value: str) -> str:
    return value.strip().strip("`").strip()


def table_rows(section: str, expected: list[str], label: str, result: Result) -> list[list[str]]:
    header, rows = parse_index(section)
    if header[: len(expected)] != expected:
        result.add("fail", _t(f"{label}: 表头不符", f"{label}: header mismatch"), " | ".join(header))
        return []
    for row in rows:
        if len(row) < len(expected):
            result.add(
                "fail",
                _t(f"{label}: 表格列数不足", f"{label}: too few table columns"),
                " | ".join(row),
            )
    return [row for row in rows if len(row) >= len(expected)]


def check_delivery(section: str, result: Result, strict: bool, body: str = "") -> None:
    rows = table_rows(section, ["Field", "Value"], "Delivery", result)
    values: dict[str, str] = {}
    for row in rows:
        key = clean_value(row[0])
        if key in values:
            result.add("fail", _t("Delivery: 字段重复", "Delivery: duplicate field"), key)
        values[key] = clean_value(row[1])
    for key in ("PR", "Commit", "Merged at", "By"):
        if not values.get(key):
            result.add("fail", _t("Delivery: 缺字段", "Delivery: missing field"), key)
    merge = values.get("Merge", "").lower()
    if merge and merge not in MERGE_MODES:
        result.add(
            "fail",
            _t("Delivery: Merge 非法", "Delivery: invalid Merge"),
            _t(f"{merge}（squash/merge/rebase/external）", f"{merge} (squash/merge/rebase/external)"),
        )
    merged_as = values.get("Merged as", "").lower()
    if not merge and merged_as and not any(mode in merged_as for mode in MERGE_MODES):
        result.add(
            "warn",
            _t(
                "Delivery: Merged as 未写明合并方式",
                "Delivery: Merged as does not state the merge mode",
            ),
            values.get("Merged as", ""),
        )
    forced = values.get("Forced", "").lower()
    if forced and forced not in FORCED_VALUES:
        result.add("fail", _t("Delivery: Forced 只能是 yes/no", "Delivery: Forced must be yes/no"), forced)
    if forced == "yes" and not values.get("Force reason"):
        result.add(
            "fail",
            _t("Delivery: Forced=yes 需要 Force reason", "Delivery: Forced=yes requires Force reason"),
        )
    if not forced and body and "--force" in body.lower():
        result.add(
            "warn",
            _t(
                "Delivery: 正文提到 --force 但没有 Forced 行",
                "Delivery: body mentions --force but has no Forced row",
            ),
            _t("补 | Forced | yes | 与 | Force reason |", "add | Forced | yes | and | Force reason |"),
        )
    if not strict:
        return
    pr = values.get("PR", "")
    if pr != "n/a" and not re.fullmatch(r"#[0-9]+", pr):
        result.add("fail", _t("Delivery: PR 必须是 #N 或 n/a", "Delivery: PR must be #N or n/a"), pr)
    commit = values.get("Commit", "")
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}", commit):
        result.add("fail", _t("Delivery: Commit 必须是真实 hash", "Delivery: Commit must be a real hash"), commit)
    merged = values.get("Merged at", "")
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", merged):
        result.add(
            "fail",
            _t("Delivery: Merged at 必须是 YYYY-MM-DD", "Delivery: Merged at must be YYYY-MM-DD"),
            merged,
        )
    by = values.get("By", "")
    if not by or by.lower() == "n/a":
        result.add("fail", _t("Delivery: By 不能为空或 n/a", "Delivery: By must not be empty or n/a"), by)


def check_traceability(section: str, result: Result) -> None:
    lines = [line.strip() for line in section.splitlines() if line.strip()]
    if not lines:
        result.add(
            "fail",
            _t("Traceability: 不能为空", "Traceability: must not be empty"),
            _t(
                "写 REQ/TC，或 none - 理由，或 deferred to B<n>",
                "write REQ/TC, or none - reason, or deferred to B<n>",
            ),
        )
        return
    none_lines = [line for line in lines if NONE_CLAIM.search(line)]
    deferred_lines = [line for line in lines if DEFERRED_CLAIM.search(line)]
    reqs = REQ_ID.findall(section)
    tests = TC_ID.findall(section)
    if none_lines and deferred_lines:
        result.add(
            "fail",
            _t("Traceability: none 与 deferred 不能同时使用", "Traceability: none and deferred cannot be used together"),
        )
        return
    if none_lines:
        if reqs or tests:
            result.add(
                "fail",
                _t(
                    "Traceability: none 不能与 REQ/TC 同时出现",
                    "Traceability: none cannot appear together with REQ/TC",
                ),
            )
            return
        for line in none_lines:
            after = line.split("none", 1)[1].strip(" |")
            after = after.lstrip("-—–: ").strip(" |")
            if not after:
                result.add("fail", _t("Traceability: none 必须写理由", "Traceability: none must state a reason"), line)
        return
    if deferred_lines:
        if reqs or tests:
            result.add(
                "fail",
                _t(
                    "Traceability: deferred 不能与 REQ/TC 同时出现",
                    "Traceability: deferred cannot appear together with REQ/TC",
                ),
            )
        return
    if not reqs:
        result.add(
            "fail",
            _t("Traceability: 缺 REQ 编号", "Traceability: missing REQ ID"),
            _t("写 REQ-xxx，或 none/deferred", "write REQ-xxx, or none/deferred"),
        )
    if not tests:
        result.add(
            "fail",
            _t("Traceability: 缺 TC 编号", "Traceability: missing TC ID"),
            _t("写 TC-xxx，或 none/deferred", "write TC-xxx, or none/deferred"),
        )


def check_acceptance(section: str, result: Result, strict: bool) -> None:
    rows = table_rows(section, ["#", "Criterion", "Evidence", "Result"], "Acceptance", result)
    if strict and not rows:
        result.add("fail", _t("Acceptance: 至少一条验收", "Acceptance: at least one criterion is required"))
    for row in rows:
        criterion = clean_value(row[1])
        evidence = clean_value(row[2])
        status = clean_value(row[3]).lower()
        if not criterion:
            result.add("fail", _t("Acceptance: Criterion 为空", "Acceptance: Criterion is empty"))
        if status not in RESULT_VALUES:
            result.add("fail", _t("Acceptance: Result 非法", "Acceptance: invalid Result"), status)
        if strict:
            if status != "pass":
                result.add("fail", _t("Acceptance: 未通过", "Acceptance: not passed"), criterion)
            lowered = evidence.lower()
            if not evidence or any(phrase in lowered for phrase in BAD_EVIDENCE):
                result.add("fail", _t("Acceptance: 证据不足", "Acceptance: insufficient evidence"), criterion)


def check_skills(section: str, result: Result, strict: bool) -> None:
    rows = table_rows(section, ["Skill", "Plan", "Actual", "Evidence"], "Skills", result)
    for row in rows:
        skill = clean_value(row[0])
        plan = clean_value(row[1]).lower()
        actual = clean_value(row[2]).lower()
        evidence = clean_value(row[3])
        if not skill:
            result.add("fail", _t("Skills: Skill 为空", "Skills: Skill is empty"))
        if plan not in SKILL_PLANS:
            result.add("fail", _t("Skills: Plan 非法", "Skills: invalid Plan"), plan)
        if actual not in SKILL_STATUSES:
            result.add("fail", _t("Skills: Actual 非法", "Skills: invalid Actual"), actual)
        if strict:
            if plan == "required" and actual != "applied":
                result.add("fail", _t("Skills: required 未 applied", "Skills: required skill not applied"), skill)
            if actual in {"partial", "skipped"} and not evidence:
                result.add(
                    "fail",
                    _t(
                        "Skills: partial/skipped 缺证据或原因",
                        "Skills: partial/skipped is missing evidence or a reason",
                    ),
                    skill,
                )
            if actual == "applied" and not evidence:
                result.add("fail", _t("Skills: applied 缺证据", "Skills: applied is missing evidence"), skill)


def check_changelog(section: str, result: Result, strict: bool) -> None:
    items: list[str] = []
    for line in section.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            items.append(stripped[2:].strip())
    if strict and not items:
        result.add("fail", _t("Changelog: 至少一条，或写 `- none`", "Changelog: at least one entry, or write `- none`"))
    for item in items:
        lowered = item.lower()
        if lowered.startswith("none"):
            continue
        if "missing" in lowered:
            result.add("fail", _t("Changelog: 片段缺失", "Changelog: fragment missing"), item)
        elif "present" not in lowered:
            result.add("fail", _t("Changelog: 未标记 present", "Changelog: not marked present"), item)


def check_scope(section: str, result: Result, strict: bool) -> None:
    rows = table_rows(section, ["Field", "Value"], "Scope", result)
    values: dict[str, str] = {}
    for row in rows:
        values[clean_value(row[0])] = clean_value(row[1])
    budget_raw = values.get("Budget", "")
    changed_raw = values.get("Changed", "")
    outcome = values.get("Result", "").lower()
    if not budget_raw:
        result.add("fail", _t("Scope: 缺 Budget", "Scope: missing Budget"))
    if not changed_raw:
        result.add("fail", _t("Scope: 缺 Changed", "Scope: missing Changed"))
    if outcome not in RESULT_VALUES:
        result.add("fail", _t("Scope: Result 非法", "Scope: invalid Result"), outcome)
    if not strict:
        return
    try:
        budget = int(budget_raw.replace(",", ""))
        changed = int(changed_raw.replace(",", ""))
    except ValueError:
        result.add(
            "fail",
            _t("Scope: Budget/Changed 必须是整数", "Scope: Budget/Changed must be integers"),
            f"{budget_raw} / {changed_raw}",
        )
        return
    if outcome != "pass":
        result.add("fail", _t("Scope: Result 不是 pass", "Scope: Result is not pass"), outcome)
    if budget > 0 and changed > budget:
        result.add("fail", _t("Scope: 超出预算", "Scope: over budget"), f"{changed} > {budget}")


def batch_is_legacy(batch: str) -> bool:
    match = re.match(r"^B([0-9]+)", batch)
    return bool(match and int(match.group(1)) <= LEGACY_MAX_BATCH)


def check_budget_override(batch: str, text: str, project: Path, result: Result) -> None:
    state_path = project / ".batch" / batch / "state.json"
    if not state_path.is_file():
        return
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        result.add(
            "warn",
            _t(f"{batch}: 无法读取 state.json", f"{batch}: cannot read state.json"),
            str(exc),
        )
        return
    override = state.get("budget_override") if isinstance(state, dict) else None
    if not isinstance(override, dict) or not override:
        return
    reason = str(override.get("reason", "")).strip()
    if reason and reason in text:
        result.add(
            "ok",
            _t(f"{batch}: 预算例外已抄录", f"{batch}: budget override recorded"),
            reason,
        )
        return
    result.add(
        "fail",
        _t(
            f"{batch}: 出口记录没有抄录预算例外",
            f"{batch}: exit record does not repeat the budget override",
        ),
        _t(
            f"state 记录 {override.get('lines')} > {override.get('budget')}: {reason}",
            f"state recorded {override.get('lines')} > {override.get('budget')}: {reason}",
        ),
    )


def check_exit_record(path: Path, result: Result, project: Path | None = None) -> None:
    name = path.name
    if not EXIT_NAME.fullmatch(name):
        result.add(
            "fail",
            _t(f"{name}: 出口记录命名不符", f"{name}: exit record name does not match"),
            _t("应为 B<n>[a-z]-exit.md", "expected B<n>[a-z]-exit.md"),
        )
        return
    batch = name[: -len(EXIT_SUFFIX)]
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        result.add("fail", _t(f"{name}: 不可读", f"{name}: unreadable"), str(exc))
        return
    sections, duplicates = parse_sections(text)
    for duplicate in duplicates:
        result.add("fail", _t(f"{name}: 标题重复", f"{name}: duplicate heading"), duplicate)
    first = section_value(text)
    expected_h1 = f"# {batch} — Exit record"
    if first != expected_h1:
        result.add(
            "fail",
            _t(f"{name}: 标题不符", f"{name}: title mismatch"),
            _t(f"应为 {expected_h1}", f"expected {expected_h1}"),
        )
    outcome = section_value(sections.get("Result", "")).lower()
    if outcome not in RESULT_VALUES:
        result.add("fail", _t(f"{name}: Result 非法", f"{name}: invalid Result"), outcome)
    legacy = batch_is_legacy(batch)
    if outcome == "aborted":
        required = ABORTED_HEADINGS
    elif legacy:
        required = LEGACY_HEADINGS
    else:
        required = EXIT_HEADINGS
    for heading in required:
        if heading not in sections:
            result.add("fail", _t(f"{name}: 缺章节", f"{name}: missing section"), heading)
    if legacy and not sections.get("Delivery", "").strip():
        result.add(
            "fail",
            _t(f"{name}: Delivery 为空", f"{name}: Delivery is empty"),
            "legacy record must state what shipped",
        )
    strict = outcome == "pass"
    if "Delivery" in sections and not legacy:
        check_delivery(sections["Delivery"], result, strict, text)
    if "Traceability" in sections and not legacy and outcome != "aborted":
        check_traceability(sections["Traceability"], result)
    if "Acceptance" in sections and not legacy:
        check_acceptance(sections["Acceptance"], result, strict)
    if not legacy and outcome != "aborted":
        if "Skills" in sections:
            check_skills(sections["Skills"], result, strict)
        if "Changelog" in sections:
            check_changelog(sections["Changelog"], result, strict)
        if "Scope" in sections:
            check_scope(sections["Scope"], result, strict)
    if project is not None:
        check_budget_override(batch, text, project, result)
    for heading in ("Deviations", "Follow-ups"):
        if heading in sections and not sections[heading]:
            result.add(
                "fail",
                _t(f"{name}: {heading} 为空", f"{name}: {heading} is empty"),
                _t("写 `- none`", "write `- none`"),
            )
    result.add("ok", _t(f"{name}: 出口记录", f"{name}: exit record"), f"Result={outcome or 'missing'}")


def check_release_record(directory: Path, result: Result) -> None:
    name = directory.name
    if not RELEASE_DIR.fullmatch(name):
        result.add(
            "fail",
            _t(
                f"{name}: release 证据目录命名不符",
                f"{name}: release evidence directory name does not match",
            ),
            _t("应为 YYYY-MM-release-vX.Y.Z", "expected YYYY-MM-release-vX.Y.Z"),
        )
        return
    metadata_path = directory / "release.json"
    notes = directory / "release-notes.md"
    readme = directory / "README.md"
    for path in (metadata_path, notes, readme):
        if not path.is_file():
            result.add("fail", _t(f"{name}: 缺文件", f"{name}: missing file"), path.name)
    if not metadata_path.is_file():
        return
    try:
        data = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        result.add("fail", _t(f"{name}: release.json 不可读", f"{name}: release.json is unreadable"), str(exc))
        return
    if not isinstance(data, dict):
        result.add("fail", _t(f"{name}: release.json 不是对象", f"{name}: release.json is not an object"))
        return
    for key in ("version", "tag", "tagCommit", "headCommit", "provider", "repository", "date", "status"):
        if key not in data:
            result.add("fail", _t(f"{name}: release.json 缺字段", f"{name}: release.json is missing field"), key)
    version = data.get("version")
    if not isinstance(version, str) or not version.startswith("v"):
        result.add("fail", _t(f"{name}: version 非法", f"{name}: invalid version"), str(version))
    elif not name.endswith(f"-{version}"):
        result.add(
            "fail",
            _t(f"{name}: 目录名与 version 不符", f"{name}: directory name does not match version"),
            version,
        )
    for key in ("tagCommit", "headCommit"):
        value = data.get(key)
        if not isinstance(value, str) or not HEX_RE.fullmatch(value):
            result.add(
                "fail",
                _t(f"{name}: {key} 必须是真实 hash", f"{name}: {key} must be a real hash"),
                str(value),
            )
    status = data.get("status")
    if status not in RELEASE_STATUSES:
        result.add("fail", _t(f"{name}: status 非法", f"{name}: invalid status"), str(status))
    provider = data.get("provider")
    if provider not in {"github", "gitlab", "none"}:
        result.add("fail", _t(f"{name}: provider 非法", f"{name}: invalid provider"), str(provider))
    repository = data.get("repository")
    if provider in {"github", "gitlab"} and (not isinstance(repository, str) or not repository.strip()):
        result.add("fail", _t(f"{name}: repository 为空", f"{name}: repository is empty"), str(provider))
    day = data.get("date")
    if not isinstance(day, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", day):
        result.add(
            "fail",
            _t(f"{name}: date 必须是 YYYY-MM-DD", f"{name}: date must be YYYY-MM-DD"),
            str(day),
        )
    if notes.is_file() and not notes.read_text(encoding="utf-8", errors="replace").strip():
        result.add("fail", _t(f"{name}: release-notes.md 为空", f"{name}: release-notes.md is empty"))
    if readme.is_file():
        text = readme.read_text(encoding="utf-8", errors="replace")
        if isinstance(version, str) and f"# Release {version}" not in text:
            result.add(
                "fail",
                _t(f"{name}: README 缺版本标题", f"{name}: README is missing the version heading"),
                str(version),
            )
        if status not in {"pending", "failed"} and "status:" not in text:
            result.add("fail", _t(f"{name}: README 缺 status", f"{name}: README is missing status"), str(status))
    result.add("ok", f"{name}: release evidence", f"{provider or '?'} · {status or '?'}")


def audit(root: Path, project: Path | None = None) -> Result:
    result = Result()
    records = root / "records"
    if not records.is_dir():
        result.add("fail", _t("records/ 不存在", "records/ does not exist"))
        return result
    readme = records / "README.md"
    if not readme.is_file():
        result.add("fail", _t("records/README.md 不存在", "records/README.md does not exist"))
        return result
    header, rows = parse_index(readme.read_text(encoding="utf-8", errors="replace"))
    if header[: len(INDEX_COLUMNS)] != INDEX_COLUMNS:
        result.add(
            "fail",
            _t("7 列索引表头不符", "index header is not the expected 7 columns"),
            " | ".join(header),
        )
    else:
        result.add(
            "ok",
            _t("7 列索引", "7-column index"),
            _t(f"{len(rows)} 行", f"{len(rows)} rows"),
        )

    expected: set[tuple[str, str]] = set()
    release_dirs: list[Path] = []
    frozen_dirs: list[Path] = []
    for item in sorted(records.iterdir()):
        if not item.is_dir() or item.name == LIVE or item.name.startswith("."):
            continue
        if RELEASE_MARKER in item.name:
            release_dirs.append(item)
        else:
            frozen_dirs.append(item)
    for release in release_dirs:
        check_release_record(release, result)
    for batch in frozen_dirs:
        if not (batch / "README.md").is_file():
            result.add("warn", _t(f"{batch.name}: 缺批次 README.md", f"{batch.name}: missing batch README.md"))
        else:
            text = (batch / "README.md").read_text(encoding="utf-8", errors="replace")
            if "未纳入本批的" not in text:
                result.add(
                    "fail",
                    _t(
                        f"{batch.name}: README 缺「未纳入本批的」",
                        f'{batch.name}: README is missing "未纳入本批的"',
                    ),
                )
        for item in batch.iterdir():
            if item.is_file() and item.name not in ("README.md", MANIFEST):
                expected.add((batch.name, item.name))
        verify_manifest(batch, result)

    indexed = {(row[0], row[2]) for row in rows if len(row) >= 3}
    only_index = indexed - expected
    only_fs = expected - indexed
    if only_index:
        result.add(
            "fail",
            _t("索引有但目录无", "indexed but missing on disk"),
            _t("、".join(f"{b}/{f}" for b, f in sorted(only_index)), ", ".join(f"{b}/{f}" for b, f in sorted(only_index))),
        )
    if only_fs:
        result.add(
            "fail",
            _t("目录有但索引无", "on disk but not indexed"),
            _t("、".join(f"{b}/{f}" for b, f in sorted(only_fs)), ", ".join(f"{b}/{f}" for b, f in sorted(only_fs))),
        )
    if not only_index and not only_fs:
        result.add(
            "ok",
            _t("索引 <-> 批次文件", "index <-> batch files"),
            _t(f"{len(expected)} 份", f"{len(expected)} files"),
        )

    live = records / LIVE
    if live.is_dir():
        if not (live / "README.md").is_file():
            result.add("warn", _t("records/live/ 缺 README.md", "records/live/ is missing README.md"))
        else:
            result.add(
                "ok",
                "records/live/",
                _t("活记录区，不进入冻结索引", "live records area; excluded from the frozen index"),
            )
        for exit_record in sorted(live.glob(f"*{EXIT_SUFFIX}")):
            check_exit_record(exit_record, result, project)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="verify records manifests and index")
    parser.add_argument("root", type=Path)
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--project",
        type=Path,
        help="development repo root; repeat any budget override recorded in .batch/<id>/state.json",
    )
    parser.add_argument(
        "--lang",
        choices=("zh", "en"),
        default="zh",
        help="language of console messages (default: zh)",
    )
    args = parser.parse_args()
    global LANG
    LANG = args.lang
    if not args.root.is_dir():
        print(f"not a directory: {args.root}", file=sys.stderr)
        return 2
    if args.project is not None and not args.project.is_dir():
        print(f"not a directory: {args.project}", file=sys.stderr)
        return 2
    result = audit(args.root.resolve(), args.project.resolve() if args.project else None)
    if args.json:
        print(json.dumps([{"status": s, "item": i, "detail": d} for s, i, d in result.items], ensure_ascii=False, indent=2))
    else:
        for status, item, detail in result.items:
            suffix = f" — {detail}" if detail else ""
            print(f"[{status}] {item}{suffix}")
    print(
        _t(
            f"\n{len(result.items)} 项；失败 {sum(1 for s, _, _ in result.items if s == 'fail')}",
            f"\n{len(result.items)} items; {sum(1 for s, _, _ in result.items if s == 'fail')} failed",
        )
    )
    return 0 if not result.failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
