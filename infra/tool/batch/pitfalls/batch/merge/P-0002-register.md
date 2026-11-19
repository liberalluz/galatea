---
id: P-0002
step: merge
symptom: a batch stays merged and never appears in records/README.md
cause: the merge happened, but nobody ran exit --mark
fix: run batch.py exit <id> --mark after writing the exit record
verify: state.status is exited and the index row names the batch
severity: warning
source: B107
---

# Merged but never registered

`merge` writes `status=merged`. The index row is added by `exit --mark`, which
also requires the exit record to pass its lint. If the batch is closed on the
platform but the record is not written, the next batch cannot see it and the
delivery gate stays pending.
