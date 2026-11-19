---
id: P-0004
step: commit
symptom: main lint rejects the squash commit after a clean branch
cause: the platform kept the PR title instead of the branch subject
fix: fix the title before merging, or rewrite the commit subject; never force-push a reviewed branch
verify: batch.py main lint --ref origin/main passes
severity: warning
source: B9
---

# The squash subject was rewritten by the platform

A squash merge uses the PR title by default. If the branch had a good
`type(scope): subject` but the PR title was a sentence, `main` ends up with the
sentence. Set the PR title from `state.pr_title` (the tool records it) before
merging, and run `main lint` after the merge to confirm.
