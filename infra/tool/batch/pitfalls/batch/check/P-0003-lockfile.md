---
id: P-0003
step: check
symptom: a batch fails its budget after a dependency install
cause: lockfiles count as changed lines unless they are excluded
fix: lockfiles are excluded by default; check config.scope.ignore if a custom one is counted
verify: budget line reports the source lines, not the lockfile
severity: warning
source: B1
checks: unit
---

# The budget counted a lockfile

A single `npm install` can add two thousand lines. The tool already ignores
`*.lock`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`, and
the other common lockfiles; if a project-specific lockfile is still counted,
add it to `config.scope.ignore`.
