# Project-local batch execution

> 中文：[简体中文](README.zh-CN.md)

Optional, project-local execution layer for the implementation stage. It is not
a core Nebula skill and is only installed when bootstrap is called with
`--with-execution`.

The tool is stack-agnostic. It owns the state machine:

```text
plan -> approve -> start -> check -> pr -> merge
```

A stage skill or the project itself provides the checks and provider commands
through `infra/tool/batch/config.json`; `batch.py` only runs commands, reads exit
codes, and writes evidence.

## Files

```text
infra/tool/batch/
  batch.py       state machine
  body.yaml      the shape of a PR body; lint and --prepare read it
  config.json    project-owned commands and defaults
  README.md      this file
.batch/          local state and evidence; never commit
```

The tool belongs to the `full` workflow. A project created with
`--workflow light` or `none` does not install it; running the copy from another
source exits 2 and points at `tools/gate.py`.

## Commands

```bash
python infra/tool/batch/batch.py plan --from ../<project>-docs/process/batches/B8.md
python infra/tool/batch/batch.py lint ../<project>-docs/process/batches/B8.md
python infra/tool/batch/batch.py approve B8 --confirm <hash8>
python infra/tool/batch/batch.py approve B8 --last
python infra/tool/batch/batch.py approve B8 --check
python infra/tool/batch/batch.py commit lint --base main
python infra/tool/batch/batch.py commit wrap --apply
python infra/tool/batch/batch.py main lint --ref origin/main
python infra/tool/batch/batch.py start B8
python infra/tool/batch/batch.py check B8
python infra/tool/batch/batch.py pr B8 --prepare
python infra/tool/batch/batch.py body B8
python infra/tool/batch/batch.py pr B8 --create --confirm <body-hash8>
python infra/tool/batch/batch.py plan --from ../<project>-docs/process/batches/B8.md
python infra/tool/batch/batch.py sdp add --card ../<project>-docs/process/batches/B8.md --apply
python infra/tool/batch/batch.py approve B8 --last
python infra/tool/batch/batch.py start B8
python infra/tool/batch/batch.py check B8
python infra/tool/batch/batch.py pr B8 --prepare
python infra/tool/batch/batch.py body B8
python infra/tool/batch/batch.py verify-body B8 --body remote.md
python infra/tool/batch/batch.py pr B8 --create --confirm <body-hash8>
python infra/tool/batch/batch.py merge B8 --pr 123 --yes
python infra/tool/batch/batch.py merge B8 --pr 123 --yes --external \
  --force --reason "budget accepted by the maintainer"
python infra/tool/batch/batch.py adopt B1 --from ../<project>-docs/process/batches/B1.md
python infra/tool/batch/batch.py pause B8
python infra/tool/batch/batch.py resume B8
python infra/tool/batch/batch.py abort B8
python infra/tool/batch/batch.py exit B8
python infra/tool/batch/batch.py exit B8 --lint records/live/B8-exit.md
python infra/tool/batch/batch.py exit B8 --mark
python infra/tool/batch/batch.py exit B8 --mark --frozen
python infra/tool/batch/batch.py export B8 --out b8.json
python infra/tool/batch/batch.py retro B8
python infra/tool/batch/batch.py doctor B8
python infra/tool/batch/python infra/tool/batch/batch.py checks list
python infra/tool/batch/batch.py import b8.json
python infra/tool/batch/batch.py status B8
```

`export` writes the whole batch (card, state, approval, evidence) as one JSON
bundle; `import` restores it on another machine, refuses to overwrite an
existing batch without `--force`, and reactivates the batch when its status is
still in flight. Use it to move `.batch/` state, not to share a batch between
two people at once.

After the merge, `verify-merge <id> --ref origin/main` (add `--fetch` to run
`git fetch` first) reads the tip of the base branch and compares its subject
with the recorded `pr_title`; a mismatch exits 1 and names both strings. The PR
numbers in `state.prs` are looked for in the subject and body and only warn
when absent, because merge tools format that line differently. A pass records
`state.verified_merge`.

When `config.merge` is empty, `merge` records an external merge: merge the PR
on the platform first, then rerun with `--pr <number>`. `--external` is still
accepted, but it is no longer required.

`exit` drafts `records/live/<id>-exit.md` in the docs repo from the card and
state: delivery fields, acceptance rows, check results, skill evidence,
changelog, and the measured budget are filled; `fill` marks what only a human
can answer. Pass `--out <path>` when the docs repo is unknown, and `--force` to
overwrite. `--lint <path>` checks an existing record instead: required sections,
`Result`, one `- <name>: PASS|FAIL|SKIP` line per check, the delivery rows,
numeric budget and changed lines, and no leftover `fill`.

`plan --from` reads the single external Markdown card and writes a snapshot to
`.batch/<id>/card.json`. The snapshot records the source path and a SHA-256 of
the Markdown with the `planned` marker line removed. Before writing, it checks
the docs repo: the id must appear in the SDP batch table (`process/sdp.md`), and
must not already be used by another card under `process/batches/` or by a record
under `records/`. The docs root is derived from the card path
(`<docs>/process/batches/B<n>.md`); `docs_root` in `config.json` overrides it.
`approve` binds both hashes; `start`, `check`, and `pr` re-read the source and
refuse a changed card. A card edit therefore requires a new approval.
`approve --last` accepts the current snapshot hash without retyping it, and
`approve --check` reports whether the recorded approval is still current
(`missing`, `stale`, or `current`) without writing anything.

`lint` runs the same checks as `plan --from` without writing anything: the card
marker, the JSON block, every schema problem at once (each reported on the line
that holds the field), the SDP row, and the duplicate id. It exits 1 and prints
`<card>:<line>: message` for each problem, so a card can be fixed before it is
planned.

`commit lint` checks every commit the branch adds against the configured git
rule (title shape, allowed types and scopes, required body lines) and against
the message shape: a subject over 72 characters, a missing blank line after the
subject, or a body line over 72 characters each fail. Fenced code blocks, URLs,
and indented lines are exempt. `commit wrap` reflows the tip commit's prose to
72 columns; it prints the result unless `--apply` is given, and it never touches
bullets or code blocks.

`main lint` applies the same message rules to the commit at the top of a branch
(default `origin/main`), where the squash commit lives: the title shape and
types only when a git rule is configured, the 72-column limits always. It is the
check for what a reviewer reads on `main`, not for the branch history.

`plan --from` never writes into the card. Re-running it on a card that is only
`planned` or `approved` refreshes the snapshot in place: nothing changed prints
`unchanged <id>`; a changed card is updated and its approval is cleared. A
started batch is never refreshed (`abort` it or use a new id). The snapshot in
`.batch/<id>/card.json` is the only record that a card was planned; `check`
warns only when an older card still carries a `planned` marker whose hash no
longer matches. Every approval and every cleared approval is appended to
`state.json` under `approvals`, so the history survives a refresh or a recard.

`plan --goal` is only for a dated ad-hoc investigation; it is not a planning
card and cannot become one later. `adopt` records an old B1–B7 card as a
read-only legacy snapshot; it never invents approval or scope.

A started batch can be paused. `pause` clears the active marker and leaves the
worktree and branch untouched, so another batch can start from the base branch.
`resume` checks that the branch still exists and the card has not changed, then
switches back and restores the status the batch had before the pause. Work that
must survive a pause is committed or stashed on the branch; the tool never
commits or discards it. `abort` ends the batch, switches back to the base branch
when the worktree is clean, and keeps the branch. Planning the same id again
first archives the aborted state to `.batch/archive/<id>-<timestamp>`, so an id
is never silently reused while the old tree is still around. `start` refuses to
create a batch branch from another batch branch; switch to the base branch first.
`abort --reason <why>` keeps everything under `.batch/<id>/` (an `abort.md` note,
the evidence files, the branch), so nothing is thrown away. `recard <id> --from
<card>` replaces the card of a live batch: the old snapshot is archived as
`card.<timestamp>.json`, the approval is cleared, the evidence stays, and the
batch returns to `planned`, so the next step is `approve <id> --last`.

`exit <id> --mark` is the step after the merge: it lints
`records/live/<id>-exit.md`, and when the record is clean it sets the status to
`exited`, records the path in `state.exit_record`, and appends one row to the
`records/README.md` index (skipped when there is no table). `--mark --frozen`
additionally sets `frozen` and stamps `frozen_at`; use it once the release has
copied the record. A batch stays `merged` until `--mark`, so the state machine
has a visible end.

`pr --prepare` writes `.batch/<id>/pr-body.md` in the shape declared by
`infra/tool/batch/body.yaml`. Without that file the shape is the five sections of
the shipped PR template for the project language (`Summary`, `Impact`,
`Verification`, `Risks`, `Self-check`, or the localized headings). The spec
lists each section with `key`, `heading`, and optionally `required: false`,
`severity` (`error` or `warn`), and `require_command_block`. Add or drop
sections there and both the lint and the prepared body follow. A body that does
not match is refused: `--prepare` lints the bytes before writing, and
`body <id> [--file <path>]` lints one at any time. The rules are: every
required section present and in order, none empty, a section marked
`require_command_block` carries a fenced command block or a result line, and
issue references are links (`[#12](url)`), not bare `#12`. Pass
`--body-from <file>` to publish a hand-written body instead: the file is copied
verbatim and is not overwritten. `--body-out <file>` (old name: `--body-file`)
moves where the body is written; the path must stay inside the project.
`state.pr_body_sha256` always hashes the bytes that were written, so a checker
that hashes the file gets the same digest. When `config.translate` is set and the
scaffold supports more than one language, it also writes one translation per
supported language other than the body language (`pr-body.<locale>.md`) plus
`pr-body.manifest.json` (source hash, timestamp, and each translation). The
source body stays authoritative; translations are local, best effort, and never
block: an empty hook skips them, and a failing locale is a warning. The hook
writes to `pr-body.<locale>.part.md`, which replaces the previous translation
only when it holds text; a failed or empty run keeps the file made last time. `state.json`
records `pr_body_sha256` and `pr_translations`. `.batch/` is never committed, and
`pr --create --confirm <body-hash8>` still confirms the source body hash. When
the card declares skills, `pr --prepare` also writes `.batch/<id>/pr-skills.md`
(see below); it is not part of the PR body.

When the pull request is opened by hand instead of by the `pr_create` hook, say
so: `pr <id> --mark-created --pr <number>` moves `pr_ready` to `pr_created`,
appends the number to `state.prs`, and stamps `pr_created_at`. It demands a
prepared body first and is idempotent: marking the same number again changes
nothing, a second number is appended. `merge` accepts both `pr_ready` and
`pr_created`.

`pause <id>` parks a batch without losing it: the branch and `.batch/<id>/`
stay, `state.paused` records the time, the previous status, the current HEAD,
and the last check result. `resume <id>` prints that record and warns when HEAD
moved while the batch was parked, so a resumed batch does not silently continue
on a different tree.

Every `check` records what it measured in `state.check_inputs` (card hash, base
commit, config hash), and `pr --prepare` records the normalized hash of the body
it wrote (`state.pr_body_sha256_normalized`). `verify-body <id> --body <file>`
hashes a body someone else pasted (or the remote copy) and compares it with that
record; without `--body` it runs `config.pr_view` with `{pr}` and compares the
hook's stdout. Line endings and trailing spaces are ignored, everything else is
not. If the card changed after the check, `pr --prepare` says so and refuses;
re-run `check` first.

## Skills

A card declares at most **two** skills, each with a `reason`. `start` prints the
declared skills with their `SKILL.md` paths and a section anchor, and refuses to
start when one is not installed. Before `check`, record what each skill changed
in `.batch/<id>/evidence/skills/<id>.md`:

```text
status: applied
changed: wrote the failing test first, then the implementation
proof: tests/test_login.py
rule: Write a failing test before the implementation.
```

`rule` must quote at least six words that appear verbatim in the installed
`SKILL.md`, compared after normalizing whitespace and case. This is what turns
"I read the skill" into "I followed this rule".

`status` is `applied`, `partial`, or `skipped`. `check` fails when a `required`
skill has no evidence file, when `changed` repeats the status instead of naming
a change, when `proof` is empty, when `proof` looks like a path that does not
exist, when `rule` is missing, shorter than six words, or not found in the skill
text, or when a required skill is skipped. `pr --prepare` renders the same
records as `.batch/<id>/pr-skills.md` — a local review supplement to send by
hand; it is never pushed and never committed.

`skills report --last N` prints, per skill, how many batches recorded evidence,
how many cited a rule, what share of the batches that is, and how many cards
declared it. An installed skill that no batch used is listed as a removal
candidate; the report only informs, it never edits.

`infra/tool/batch/skill-map.yaml` ships with a default map (derived from
`skills/nebula-project/references/capability-map.yaml`). `plan` prints up to two
suggestions with the reason (`--type` sets the type of an ad-hoc card), and only
suggests skills installed under an agent root: a mapped skill that is not
installed is reported, not recommended. A skill this project already used in a
batch of the same type is ranked first, with `used in N <type> batch(es)` as the
reason. It advises; it never edits the card.

## Gates

`check` runs six gates before the configured commands:

- **id**: the batch id must not be claimed by another card under
  `process/batches/` or by a record under `records/` in the docs repo; skipped
  when the docs root cannot be derived (ad-hoc batches).
- **scope**: every changed path must match `allowed` and none may match
  `forbidden`.
- **budget**: added plus deleted lines, measured against the merge base with the
  current base branch (falling back to the recorded card base), must not exceed
  `size_budget`. Lock files (`package-lock.json`, `pnpm-lock.yaml`, `Cargo.lock`,
  and similar) never count. Work merged into the base branch by other batches is not counted
  twice. Untracked files count by line; binary files are reported but not
  counted. A card may omit `size_budget`: `docs` defaults to 150, `fix` and
  `process` to 200, `feat` to 400, and anything else to 400. When over budget,
  `check` fails and prints the escape hatch; rerun with
  `--allow-over-budget "<why>"` to record the reason in
  `state.budget_override`, the evidence log, and the PR `Risks` section.
- **changelog**: every declared fragment must exist under `changelog.d/`, be
  changed by this batch, and be non-empty. `feat`/`fix` must declare one when
  the project has `changelog.d/`.
- **skills**: every declared non-stage skill must be installed under
  `.agents/skills`, `.claude/skills`, `.codex/skills`, `.codebuddy/skills`, or
  `.workbuddy/skills`. Stage skills are rejected when the card is registered.
  Every `required` skill must have an evidence file under
  `.batch/<id>/evidence/skills/` (see Skills above).
- **commit titles**: when a git rule is configured (the `git` preset in
  `.nebula-scaffold.json`, or `commit.types`/`scopes`/`body` in `config.json`),
  every commit the branch adds must read `type(scope): subject`, with `type`
  from `commit.types`; when `commit.scopes` is non-empty the scope is required
  and must come from that list; every token in `commit.body` (for example
  `Why:` and `Batch:`) must appear in the commit body. Write `Batch: none`
  when there is no batch. Merge commits are skipped. With no rule configured
  the gate is skipped.

A failing gate stops the configured commands and leaves the batch in
`check_failed`. The last lines of a failed run say what to do next: the override
flag for a budget stop, the command to reproduce a failed check, and the rerun
when the `[fail]` lines are fixed.

The exit record copies each skill's actual `applied`/`partial`/`skipped` status
and what changed from the evidence file.

## Release checks

`checks` run for every batch; `release_checks` run only for a release batch.
Mark a release batch in the card with `"release": true`, or pass `--release`
once to `check` without editing the card. Both lists run in order; the evidence
line reads `release: yes (N checks)` or `release: no (M checks)`. The card flag
is part of the snapshot, so the PR body and the exit record show which tier ran.
Use the release tier for suite-wide or packaging commands that would otherwise
make every small batch pay for them.

A check entry is `{id, run, tier, severity, stage}`; `tier` comes from which
list it sits in, and the older `{name, command}` spelling still works. `run`
takes a command array, `severity` is `error` (default) or `warn`: a failing
`warn` check is recorded in the evidence as `warn: check <id> failed` and does
not fail the gate. `stage` is informational. Checks run concurrently (up to
four at a time) but their results are printed and recorded in the configured
order, so a slow check does not reorder the log. `batch.py config lint` checks
the file without touching a batch: duplicate ids, a bad `severity`, a broken
command array, or an unknown key all fail it.

`start` resolves the card base to a commit and stores that SHA in
`state.base`; the original branch or tag is kept in `state.base_ref`. `check`
resolves old state files that still contain a branch name and writes the SHA
back, so later runs still measure the original base after the branch merges.

## Configuration

`config.json`:

```json
{
  "base": "main",
  "branch_prefix": "batch/",
  "scope": {"ignore": [], "generated": []},
  "commit": {"types": [], "scopes": [], "body": []},
  "checks": [
    {
      "id": "test",
      "run": ["python", "-m", "pytest"],
      "severity": "error",
      "cwd": ".",
      "timeout": 600
    }
  ],
  "release_checks": [],
  "pr_create": ["gh", "pr", "create", "--title", "{title}", "--body-file", "{body}"],
  "translate": ["python", "tool/translate.py", "--in", "{body}", "--locale", "{locale}", "--out", "{out}"],
  "merge": ["gh", "pr", "merge", "{pr}", "--merge"]
}
```

- `checks`: commands run by `check`; each writes `evidence/<id>.log`.
  `cwd` is relative to the project root.
- `release_checks`: extra commands run only when the card says `"release": true`
  or `check --release` is passed; same shape as `checks`.
- `docs_root`: docs repo root used by `plan --from` for the SDP and duplicate-id
  checks; empty derives it from the card path.
- `pr_create` / `merge`: optional provider hooks. Placeholders:
  `{id}`, `{title}`, `{body}`, `{branch}`, `{root}`, `{pr}`.
- `translate`: optional PR body translation hook. Placeholders: the same set plus
  `{locale}` and `{out}`. It runs once per supported language other than the
  body language; leave it empty to skip translations.
- `scope.ignore`: paths ignored by scope checks; `.batch/` is always ignored.
- `scope.generated`: generated paths ignored by scope checks, kept separate
  from hand-written ignores so a project can review the stack's output.
- `commit`: the optional git rule. `types` is the closed list of subject
  types; `scopes` is the closed list of scopes (empty means "do not require a
  scope"); `body` lists the tokens every commit body must contain, for example
  `["Why:", "Batch:"]`. All three empty means the rule is off. When the rule
  is on, `pr --prepare` also builds the PR title as `type(scope): goal` from
  the card's `type` and `git_scope` (and refuses cards without a scope when
  scopes are configured). The subject is the card's `pr_title` when present,
  otherwise `goal`; a long explanation can stay in `goal` while the title stays
  short. `merge` warns when the squash commit on the base branch does not match
  the rule. `bootstrap --git-convention team` writes the same rule to
  `.nebula-scaffold.json`; `config.commit` wins over it.
- Empty hooks mean the tool stops at `pr --prepare` or reports that merge must
  be done externally. After merging a PR manually, run
  `merge <id> --pr <number> --yes --external` to record the merge and release
  `.batch/active`. `--external` is rejected when `config.merge` is configured.
  A `check_failed` batch can only be recorded with `--external --force
  --reason <why>`; the override and reason are written to `state.json`.
- One batch can span several PRs (the docs repo's PR plus the code PR). Pass
  `--also-pr <number>` once per extra PR; every number lands in `state.prs`
  (the first stays `state.pr`), the exit draft's `PR` cell lists them all, and
  the merge message prints them.
- `start` clears an active marker whose batch is already `merged` or `aborted`;
  that is recovery for a stale `.batch/active`, not a way to run two batches.
- `branch_prefix`: `start` creates `<prefix><id>-<slug>`; the slug is the
  lowercased goal and is omitted when empty (for example a non-ASCII goal).
- Batch id resolution: an explicit id wins, then `.batch/active`, then the only
  local batch. With several batches and no active marker, commands error and
  list the candidates instead of guessing.
- `--with-execution` fills `checks`/`scope` from the selected stack's
  `execution.yaml`; it never overwrites an existing `config.json`.

## Pitfalls

`pitfalls list|show|check` reads a data pack, not code:

```text
infra/tool/batch/pitfalls/        core, shipped with this tool
.nebula/overlay/<name>/pitfalls/  company entries (installed from the overlay repo)
<project>-docs/process/pitfalls/  project entries
```

Each entry is one markdown file with front matter (`id`, `step`, `symptom`,
`cause`, `fix`, `verify`, `severity`, `source`) and an H1 title. Ids are
`P-####` in core and `L-####` in a local layer; a higher layer may reuse an id
to override a lower one. `pitfalls check` rejects a bad id and a duplicate id
inside one layer.

`pitfalls index [--out <file>]` prints (or writes) a table of every entry.
`lint` prints up to three `hint:` lines for the plan step, and `check` prints a
hint when a failing check id is named in an entry's `checks:` field.

`--with-execution` copies `pitfalls/` into `infra/tool/batch/` once; it never
overwrites an existing copy.

`retro <id>` writes `.batch/<id>/retro.md`: a timeline from `state.json`, the
things that hurt (failed checks, budget override, a forced merge, a mid-batch
recard, a pause), and one draft entry per item in the pitfall front matter,
marked `L-0000`. Nothing is added to `process/pitfalls/` automatically; copy the
candidates you trust by hand and give them real ids.

`doctor <id>` prints one line per thing that is out of step — a stale approval, a
branch mismatch, a missing prepared body, an unverified merge, a missing exit
record, an exit record that fails its lint, a required skill without evidence —
then `doctor: N error(s), M warning(s)`. Errors exit 1; warnings do not.

`checks list [--json]` prints the effective checks: `config.checks` and
`config.release_checks` (origin `config`), then any check defined in
`infra/tool/batch/checks/*.json` (origin is the file name). A pack check is only
listed, never run, until its id appears in `config.checks`.

`checks report [--upstream] [--json]` adds run counts and failures from every
batch state. `--upstream` writes `.batch/checks-upstream.json`; hand that file to
the owner of the tool repo, who runs `tools/promote_check.py --report <file>` to
draft a check pack. Promotion is a review step, never a sync.

## Boundaries

- It does not decide whether a change should be batched.
- It does not know Flutter, Swift, or any other stack.
- It does not replace review or human merge approval.
- It does not store records or release notes.
- The project owns `config.json`; bootstrap does not overwrite it on re-run.

 Project-local batch execution

> 中文：[简体中文](README.zh-CN.md)

Optional, project-local execution layer for the implementation stage. It is not
a core Nebula skill and is only installed when bootstrap is called with
`--with-execution`.

The tool is stack-agnostic. It owns the state machine:

```text
plan -> approve -> start -> check -> pr -> merge
```

A stage skill or the project itself provides the checks and provider commands
through `infra/tool/batch/config.json`; `batch.py` only runs commands, reads exit
codes, and writes evidence.

## Files

```text
infra/tool/batch/
  batch.py       state machine
  config.json    project-owned commands and defaults
  README.md      this file
.batch/          local state and evidence; never commit
```

The tool belongs to the `full` workflow. A project created with
`--workflow light` or `none` does not install it; running the copy from another
source exits 2 and points at `tools/gate.py`.

## Commands

```bash
python infra/tool/batch/batch.py plan --from ../<project>-docs/process/batches/B8.md
python infra/tool/batch/batch.py lint ../<project>-docs/process/batches/B8.md
python infra/tool/batch/batch.py approve B8 --confirm <hash8>
python infra/tool/batch/batch.py approve B8 --last
python infra/tool/batch/batch.py approve B8 --check
python infra/tool/batch/batch.py commit lint --base main
python infra/tool/batch/batch.py commit wrap --apply
python infra/tool/batch/batch.py main lint --ref origin/main
python infra/tool/batch/batch.py start B8
python infra/tool/batch/batch.py check B8
python infra/tool/batch/batch.py pr B8 --prepare
python infra/tool/batch/batch.py body B8
python infra/tool/batch/batch.py pr B8 --create --confirm <body-hash8>
python infra/tool/batch/batch.py plan --from ../<project>-docs/process/batches/B8.md
python infra/tool/batch/batch.py sdp add --card ../<project>-docs/process/batches/B8.md --apply
python infra/tool/batch/batch.py approve B8 --last
python infra/tool/batch/batch.py start B8
python infra/tool/batch/batch.py check B8
python infra/tool/batch/batch.py pr B8 --prepare
python infra/tool/batch/batch.py body B8
python infra/tool/batch/batch.py verify-body B8 --body remote.md
python infra/tool/batch/batch.py pr B8 --create --confirm <body-hash8>
python infra/tool/batch/batch.py merge B8 --pr 123 --yes
python infra/tool/batch/batch.py merge B8 --pr 123 --yes --external \
  --force --reason "budget accepted by the maintainer"
python infra/tool/batch/batch.py adopt B1 --from ../<project>-docs/process/batches/B1.md
python infra/tool/batch/batch.py pause B8
python infra/tool/batch/batch.py resume B8
python infra/tool/batch/batch.py abort B8
python infra/tool/batch/batch.py exit B8
python infra/tool/batch/batch.py exit B8 --lint records/live/B8-exit.md
python infra/tool/batch/batch.py exit B8 --mark
python infra/tool/batch/batch.py exit B8 --mark --frozen
python infra/tool/batch/batch.py export B8 --out b8.json
python infra/tool/batch/batch.py retro B8
python infra/tool/batch/batch.py doctor B8
python infra/tool/batch/python infra/tool/batch/batch.py checks list
python infra/tool/batch/batch.py import b8.json
python infra/tool/batch/batch.py status B8
```

`export` writes the whole batch (card, state, approval, evidence) as one JSON
bundle; `import` restores it on another machine, refuses to overwrite an
existing batch without `--force`, and reactivates the batch when its status is
still in flight. Use it to move `.batch/` state, not to share a batch between
two people at once.

After the merge, `verify-merge <id> --ref origin/main` (add `--fetch` to run
`git fetch` first) reads the tip of the base branch and compares its subject
with the recorded `pr_title`; a mismatch exits 1 and names both strings. The PR
numbers in `state.prs` are looked for in the subject and body and only warn
when absent, because merge tools format that line differently. A pass records
`state.verified_merge`.

When `config.merge` is empty, `merge` records an external merge: merge the PR
on the platform first, then rerun with `--pr <number>`. `--external` is still
accepted, but it is no longer required.

`exit` drafts `records/live/<id>-exit.md` in the docs repo from the card and
state: delivery fields, acceptance rows, check results, skill evidence,
changelog, and the measured budget are filled; `fill` marks what only a human
can answer. Pass `--out <path>` when the docs repo is unknown, and `--force` to
overwrite. `--lint <path>` checks an existing record instead: required sections,
`Result`, one `- <name>: PASS|FAIL|SKIP` line per check, the delivery rows,
numeric budget and changed lines, and no leftover `fill`.

`plan --from` reads the single external Markdown card and writes a snapshot to
`.batch/<id>/card.json`. The snapshot records the source path and a SHA-256 of
the Markdown with the `planned` marker line removed. Before writing, it checks
the docs repo: the id must appear in the SDP batch table (`process/sdp.md`), and
must not already be used by another card under `process/batches/` or by a record
under `records/`. The docs root is derived from the card path
(`<docs>/process/batches/B<n>.md`); `docs_root` in `config.json` overrides it.
`approve` binds both hashes; `start`, `check`, and `pr` re-read the source and
refuse a changed card. A card edit therefore requires a new approval.
`approve --last` accepts the current snapshot hash without retyping it, and
`approve --check` reports whether the recorded approval is still current
(`missing`, `stale`, or `current`) without writing anything.

`lint` runs the same checks as `plan --from` without writing anything: the card
marker, the JSON block, every schema problem at once (each reported on the line
that holds the field), the SDP row, and the duplicate id. It exits 1 and prints
`<card>:<line>: message` for each problem, so a card can be fixed before it is
planned.

`commit lint` checks every commit the branch adds against the configured git
rule (title shape, allowed types and scopes, required body lines) and against
the message shape: a subject over 72 characters, a missing blank line after the
subject, or a body line over 72 characters each fail. Fenced code blocks, URLs,
and indented lines are exempt. `commit wrap` reflows the tip commit's prose to
72 columns; it prints the result unless `--apply` is given, and it never touches
bullets or code blocks.

`main lint` applies the same message rules to the commit at the top of a branch
(default `origin/main`), where the squash commit lives: the title shape and
types only when a git rule is configured, the 72-column limits always. It is the
check for what a reviewer reads on `main`, not for the branch history.

`plan --from` never writes into the card. Re-running it on a card that is only
`planned` or `approved` refreshes the snapshot in place: nothing changed prints
`unchanged <id>`; a changed card is updated and its approval is cleared. A
started batch is never refreshed (`abort` it or use a new id). The snapshot in
`.batch/<id>/card.json` is the only record that a card was planned; `check`
warns only when an older card still carries a `planned` marker whose hash no
longer matches. Every approval and every cleared approval is appended to
`state.json` under `approvals`, so the history survives a refresh or a recard.

`plan --goal` is only for a dated ad-hoc investigation; it is not a planning
card and cannot become one later. `adopt` records an old B1–B7 card as a
read-only legacy snapshot; it never invents approval or scope.

A started batch can be paused. `pause` clears the active marker and leaves the
worktree and branch untouched, so another batch can start from the base branch.
`resume` checks that the branch still exists and the card has not changed, then
switches back and restores the status the batch had before the pause. Work that
must survive a pause is committed or stashed on the branch; the tool never
commits or discards it. `abort` ends the batch, switches back to the base branch
when the worktree is clean, and keeps the branch. Planning the same id again
first archives the aborted state to `.batch/archive/<id>-<timestamp>`, so an id
is never silently reused while the old tree is still around. `start` refuses to
create a batch branch from another batch branch; switch to the base branch first.
`abort --reason <why>` keeps everything under `.batch/<id>/` (an `abort.md` note,
the evidence files, the branch), so nothing is thrown away. `recard <id> --from
<card>` replaces the card of a live batch: the old snapshot is archived as
`card.<timestamp>.json`, the approval is cleared, the evidence stays, and the
batch returns to `planned`, so the next step is `approve <id> --last`.

`exit <id> --mark` is the step after the merge: it lints
`records/live/<id>-exit.md`, and when the record is clean it sets the status to
`exited`, records the path in `state.exit_record`, and appends one row to the
`records/README.md` index (skipped when there is no table). `--mark --frozen`
additionally sets `frozen` and stamps `frozen_at`; use it once the release has
copied the record. A batch stays `merged` until `--mark`, so the state machine
has a visible end.

`pr --prepare` writes `.batch/<id>/pr-body.md` in the shape of the repository PR
template (`Summary`, `Impact`, `Verification`, `Risks`, `Self-check`). A body
that does not match is refused: `--prepare` lints the bytes before writing, and
`body <id> [--file <path>]` lints one at any time. The rules are: all five
sections present and in order, none empty, `Verification` carries a fenced
command block or a result line, and issue references are links (`[#12](url)`),
not bare `#12`. Pass
`--body-from <file>` to publish a hand-written body instead: the file is copied
verbatim and is not overwritten. `--body-out <file>` (old name: `--body-file`)
moves where the body is written; the path must stay inside the project.
`state.pr_body_sha256` always hashes the bytes that were written, so a checker
that hashes the file gets the same digest. When `config.translate` is set and the
scaffold supports more than one language, it also writes one translation per
supported language other than the body language (`pr-body.<locale>.md`) plus
`pr-body.manifest.json` (source hash, timestamp, and each translation). The
source body stays authoritative; translations are local, best effort, and never
block: an empty hook skips them, and a failing locale is a warning. The hook
writes to `pr-body.<locale>.part.md`, which replaces the previous translation
only when it holds text; a failed or empty run keeps the file made last time. `state.json`
records `pr_body_sha256` and `pr_translations`. `.batch/` is never committed, and
`pr --create --confirm <body-hash8>` still confirms the source body hash. When
the card declares skills, `pr --prepare` also writes `.batch/<id>/pr-skills.md`
(see below); it is not part of the PR body.

When the pull request is opened by hand instead of by the `pr_create` hook, say
so: `pr <id> --mark-created --pr <number>` moves `pr_ready` to `pr_created`,
appends the number to `state.prs`, and stamps `pr_created_at`. It demands a
prepared body first and is idempotent: marking the same number again changes
nothing, a second number is appended. `merge` accepts both `pr_ready` and
`pr_created`.

`pause <id>` parks a batch without losing it: the branch and `.batch/<id>/`
stay, `state.paused` records the time, the previous status, the current HEAD,
and the last check result. `resume <id>` prints that record and warns when HEAD
moved while the batch was parked, so a resumed batch does not silently continue
on a different tree.

Every `check` records what it measured in `state.check_inputs` (card hash, base
commit, config hash), and `pr --prepare` records the normalized hash of the body
it wrote (`state.pr_body_sha256_normalized`). `verify-body <id> --body <file>`
hashes a body someone else pasted (or the remote copy) and compares it with that
record; without `--body` it runs `config.pr_view` with `{pr}` and compares the
hook's stdout. Line endings and trailing spaces are ignored, everything else is
not. If the card changed after the check, `pr --prepare` says so and refuses;
re-run `check` first.

## Skills

A card declares at most **two** skills, each with a `reason`. `start` prints the
declared skills with their `SKILL.md` paths and a section anchor, and refuses to
start when one is not installed. Before `check`, record what each skill changed
in `.batch/<id>/evidence/skills/<id>.md`:

```text
status: applied
changed: wrote the failing test first, then the implementation
proof: tests/test_login.py
rule: Write a failing test before the implementation.
```

`rule` must quote at least six words that appear verbatim in the installed
`SKILL.md`, compared after normalizing whitespace and case. This is what turns
"I read the skill" into "I followed this rule".

`status` is `applied`, `partial`, or `skipped`. `check` fails when a `required`
skill has no evidence file, when `changed` repeats the status instead of naming
a change, when `proof` is empty, when `proof` looks like a path that does not
exist, when `rule` is missing, shorter than six words, or not found in the skill
text, or when a required skill is skipped. `pr --prepare` renders the same
records as `.batch/<id>/pr-skills.md` — a local review supplement to send by
hand; it is never pushed and never committed.

`skills report --last N` prints, per skill, how many batches recorded evidence,
how many cited a rule, what share of the batches that is, and how many cards
declared it. An installed skill that no batch used is listed as a removal
candidate; the report only informs, it never edits.

`infra/tool/batch/skill-map.yaml` is optional: it maps `by_type`, `by_path`, and
`by_stage` to skill ids, and `plan` prints up to two suggestions with the reason
(`--type` sets the type of an ad-hoc card). It advises; it never edits the card.

## Gates

`check` runs six gates before the configured commands:

- **id**: the batch id must not be claimed by another card under
  `process/batches/` or by a record under `records/` in the docs repo; skipped
  when the docs root cannot be derived (ad-hoc batches).
- **scope**: every changed path must match `allowed` and none may match
  `forbidden`.
- **budget**: added plus deleted lines, measured against the merge base with the
  current base branch (falling back to the recorded card base), must not exceed
  `size_budget`. Lock files (`package-lock.json`, `pnpm-lock.yaml`, `Cargo.lock`,
  and similar) never count. Work merged into the base branch by other batches is not counted
  twice. Untracked files count by line; binary files are reported but not
  counted. A card may omit `size_budget`: `docs` defaults to 150, `fix` and
  `process` to 200, `feat` to 400, and anything else to 400. When over budget,
  `check` fails and prints the escape hatch; rerun with
  `--allow-over-budget "<why>"` to record the reason in
  `state.budget_override`, the evidence log, and the PR `Risks` section.
- **changelog**: every declared fragment must exist under `changelog.d/`, be
  changed by this batch, and be non-empty. `feat`/`fix` must declare one when
  the project has `changelog.d/`.
- **skills**: every declared non-stage skill must be installed under
  `.agents/skills`, `.claude/skills`, `.codex/skills`, `.codebuddy/skills`, or
  `.workbuddy/skills`. Stage skills are rejected when the card is registered.
  Every `required` skill must have an evidence file under
  `.batch/<id>/evidence/skills/` (see Skills above).
- **commit titles**: when a git rule is configured (the `git` preset in
  `.nebula-scaffold.json`, or `commit.types`/`scopes`/`body` in `config.json`),
  every commit the branch adds must read `type(scope): subject`, with `type`
  from `commit.types`; when `commit.scopes` is non-empty the scope is required
  and must come from that list; every token in `commit.body` (for example
  `Why:` and `Batch:`) must appear in the commit body. Write `Batch: none`
  when there is no batch. Merge commits are skipped. With no rule configured
  the gate is skipped.

A failing gate stops the configured commands and leaves the batch in
`check_failed`. The last lines of a failed run say what to do next: the override
flag for a budget stop, the command to reproduce a failed check, and the rerun
when the `[fail]` lines are fixed.

The exit record copies each skill's actual `applied`/`partial`/`skipped` status
and what changed from the evidence file.

## Release checks

`checks` run for every batch; `release_checks` run only for a release batch.
Mark a release batch in the card with `"release": true`, or pass `--release`
once to `check` without editing the card. Both lists run in order; the evidence
line reads `release: yes (N checks)` or `release: no (M checks)`. The card flag
is part of the snapshot, so the PR body and the exit record show which tier ran.
Use the release tier for suite-wide or packaging commands that would otherwise
make every small batch pay for them.

A check entry is `{id, run, tier, severity, stage}`; `tier` comes from which
list it sits in, and the older `{name, command}` spelling still works. `run`
takes a command array, `severity` is `error` (default) or `warn`: a failing
`warn` check is recorded in the evidence as `warn: check <id> failed` and does
not fail the gate. `stage` is informational. Checks run concurrently (up to
four at a time) but their results are printed and recorded in the configured
order, so a slow check does not reorder the log. `batch.py config lint` checks
the file without touching a batch: duplicate ids, a bad `severity`, a broken
command array, or an unknown key all fail it.

`start` resolves the card base to a commit and stores that SHA in
`state.base`; the original branch or tag is kept in `state.base_ref`. `check`
resolves old state files that still contain a branch name and writes the SHA
back, so later runs still measure the original base after the branch merges.

## Configuration

`config.json`:

```json
{
  "base": "main",
  "branch_prefix": "batch/",
  "scope": {"ignore": [], "generated": []},
  "commit": {"types": [], "scopes": [], "body": []},
  "checks": [
    {
      "id": "test",
      "run": ["python", "-m", "pytest"],
      "severity": "error",
      "cwd": ".",
      "timeout": 600
    }
  ],
  "release_checks": [],
  "pr_create": ["gh", "pr", "create", "--title", "{title}", "--body-file", "{body}"],
  "translate": ["python", "tool/translate.py", "--in", "{body}", "--locale", "{locale}", "--out", "{out}"],
  "merge": ["gh", "pr", "merge", "{pr}", "--merge"]
}
```

- `checks`: commands run by `check`; each writes `evidence/<id>.log`.
  `cwd` is relative to the project root.
- `release_checks`: extra commands run only when the card says `"release": true`
  or `check --release` is passed; same shape as `checks`.
- `docs_root`: docs repo root used by `plan --from` for the SDP and duplicate-id
  checks; empty derives it from the card path.
- `pr_create` / `merge`: optional provider hooks. Placeholders:
  `{id}`, `{title}`, `{body}`, `{branch}`, `{root}`, `{pr}`.
- `translate`: optional PR body translation hook. Placeholders: the same set plus
  `{locale}` and `{out}`. It runs once per supported language other than the
  body language; leave it empty to skip translations.
- `scope.ignore`: paths ignored by scope checks; `.batch/` is always ignored.
- `scope.generated`: generated paths ignored by scope checks, kept separate
  from hand-written ignores so a project can review the stack's output.
- `commit`: the optional git rule. `types` is the closed list of subject
  types; `scopes` is the closed list of scopes (empty means "do not require a
  scope"); `body` lists the tokens every commit body must contain, for example
  `["Why:", "Batch:"]`. All three empty means the rule is off. When the rule
  is on, `pr --prepare` also builds the PR title as `type(scope): goal` from
  the card's `type` and `git_scope` (and refuses cards without a scope when
  scopes are configured). The subject is the card's `pr_title` when present,
  otherwise `goal`; a long explanation can stay in `goal` while the title stays
  short. `merge` warns when the squash commit on the base branch does not match
  the rule. `bootstrap --git-convention team` writes the same rule to
  `.nebula-scaffold.json`; `config.commit` wins over it.
- Empty hooks mean the tool stops at `pr --prepare` or reports that merge must
  be done externally. After merging a PR manually, run
  `merge <id> --pr <number> --yes --external` to record the merge and release
  `.batch/active`. `--external` is rejected when `config.merge` is configured.
  A `check_failed` batch can only be recorded with `--external --force
  --reason <why>`; the override and reason are written to `state.json`.
- One batch can span several PRs (the docs repo's PR plus the code PR). Pass
  `--also-pr <number>` once per extra PR; every number lands in `state.prs`
  (the first stays `state.pr`), the exit draft's `PR` cell lists them all, and
  the merge message prints them.
- `start` clears an active marker whose batch is already `merged` or `aborted`;
  that is recovery for a stale `.batch/active`, not a way to run two batches.
- `branch_prefix`: `start` creates `<prefix><id>-<slug>`; the slug is the
  lowercased goal and is omitted when empty (for example a non-ASCII goal).
- Batch id resolution: an explicit id wins, then `.batch/active`, then the only
  local batch. With several batches and no active marker, commands error and
  list the candidates instead of guessing.
- `--with-execution` fills `checks`/`scope` from the selected stack's
  `execution.yaml`; it never overwrites an existing `config.json`.

## Pitfalls

`pitfalls list|show|check` reads a data pack, not code:

```text
infra/tool/batch/pitfalls/        core, shipped with this tool
.nebula/overlay/<name>/pitfalls/  company entries (installed from the overlay repo)
<project>-docs/process/pitfalls/  project entries
```

Each entry is one markdown file with front matter (`id`, `step`, `symptom`,
`cause`, `fix`, `verify`, `severity`, `source`) and an H1 title. Ids are
`P-####` in core and `L-####` in a local layer; a higher layer may reuse an id
to override a lower one. `pitfalls check` rejects a bad id and a duplicate id
inside one layer.

`pitfalls index [--out <file>]` prints (or writes) a table of every entry.
`lint` prints up to three `hint:` lines for the plan step, and `check` prints a
hint when a failing check id is named in an entry's `checks:` field.

`--with-execution` copies `pitfalls/` into `infra/tool/batch/` once; it never
overwrites an existing copy.

`retro <id>` writes `.batch/<id>/retro.md`: a timeline from `state.json`, the
things that hurt (failed checks, budget override, a forced merge, a mid-batch
recard, a pause), and one draft entry per item in the pitfall front matter,
marked `L-0000`. Nothing is added to `process/pitfalls/` automatically; copy the
candidates you trust by hand and give them real ids.

`doctor <id>` prints one line per thing that is out of step — a stale approval, a
branch mismatch, a missing prepared body, an unverified merge, a missing exit
record, an exit record that fails its lint, a required skill without evidence —
then `doctor: N error(s), M warning(s)`. Errors exit 1; warnings do not.

`checks list [--json]` prints the effective checks: `config.checks` and
`config.release_checks` (origin `config`), then any check defined in
`infra/tool/batch/checks/*.json` (origin is the file name). A pack check is only
listed, never run, until its id appears in `config.checks`.

`checks report [--upstream] [--json]` adds run counts and failures from every
batch state. `--upstream` writes `.batch/checks-upstream.json`; hand that file to
the owner of the tool repo, who runs `tools/promote_check.py --report <file>` to
draft a check pack. Promotion is a review step, never a sync.

## Boundaries

- It does not decide whether a change should be batched.
- It does not know Flutter, Swift, or any other stack.
- It does not replace review or human merge approval.
- It does not store records or release notes.
- The project owns `config.json`; bootstrap does not overwrite it on re-run.

