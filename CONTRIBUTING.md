# Contributing

[简体中文](CONTRIBUTING.zh-CN.md) · English

## Before you start

- Read `AGENTS.md`.
- One change = one batch = one PR.
- A branch carries one change; a PR carries one behaviour.

## What is enforced

| Rule | Checked by | Active when |
|---|---|---|
| The commit body names `Batch: B<n>` (or `Batch: none`) | `batch.py commit lint` | `process/sdp.md` has a batch table |
| The named batch exists in the SDP | `batch.py commit lint` | same |
| The PR body has `- Batch: B<n>`, or `- Batch: none — <reason>` | `batch.py pr --create`, `tools/gate/gate.py`, `tools/ci/pr_gate.py` | a batched PR always; every PR in CI |
| The PR body keeps its sections and carries no placeholder | `batch.py body`, `batch.py pr --prepare` | always |
| The commit subject follows the configured format | `batch.py commit lint` | a `commit` block is configured |
| A configured check passes | `batch.py check` | checks are configured |

Everything else on this page is an agreement between people. No script fails when
it is broken; a review may still ask for it.

## Branches

```text
main                 long-lived, protected
feat/<topic>         user-visible feature
fix/<topic>          bug fix
process/<topic>      process or tooling only
```

- One branch = one change.
- Delete the branch after merge.

## Commits

```text
<type>(<scope>): <subject>
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `ci`.
Scopes: the module or area.

- Subject is imperative and short.
- The body explains why, not what, and names the batch.
- No secrets, no generated build output.

## Pull requests

- One PR = one behaviour. A review may ask for a split; no script fails when a PR
  carries two changes.
- Fill the PR template; no placeholders.
- Link the issue or record if one exists.
- Required checks must be green.
- Do not rewrite history after review unless asked.

## Merge

- Squash merge by default.
- The author does not self-approve.
- No direct push to `main`.
- A failed check is fixed, not bypassed.
- A waiver is recorded, not agreed verbally.

## Release

- The version lives in the declared manifest.
- Tag `vX.Y.Z`.
- `CHANGELOG.md` carries the matching version before tagging.
- Content packs use `pack/<space>/vX.Y.Z` when tagged.
