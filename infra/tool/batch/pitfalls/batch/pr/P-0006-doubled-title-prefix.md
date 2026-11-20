---
id: P-0006
step: pr
symptom: `state.json` records a doubled commit prefix (`feat(app): feat(app): ...`) and `verify-merge` false-fails comparing the remote squash subject
cause: `pr --prepare` derives `type(scope): ` from the card's `type` + `git_scope` and prefixes it onto `pr_title` unconditionally; a card whose `pr_title` already carries the prefix gets doubled
fix: write the card's `pr_title` bare, without the `type(scope): ` prefix; let `--prepare` derive the prefix from `type` and `git_scope`; an already-recorded double prefix is fixed by editing `state.json` to the remote subject and recarding with the bare title
verify: `state.json` shows exactly one prefix; `verify-merge` compares the remote squash subject `(<bare title> (#N))` without a mismatch
severity: warning
source: B5-B7
---

# Doubled commit prefix on `pr_title`

The execution tool treats the card's `pr_title` as the subject and adds the
`type(scope): ` prefix itself when the commit rule is enabled. A prefix typed
into the card is therefore doubled in `state.json`, and `verify-merge` —
which compares the remote squash subject against the recorded title — fails
even though the PR on GitHub is correct. Keep the card title bare
(`add the audio service with ...`, not `feat(app): add the audio service
with ...`); the prefix comes from `type` + `git_scope` at prepare time.
