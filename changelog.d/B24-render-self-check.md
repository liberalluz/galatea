## Fixed

- `batch.py pr <id> --prepare` no longer self-rejects its own body: the
  project render hook now emits the fixed three-line Self-check shape
  (the `- Batch: <id>` line first, then the commit-trailer line and the
  no-secret line), so the prepared body names the batch and passes the
  body validator without hand-editing.
- The scope qualifier on the batch line comes from the batch-local
  pr-notes `## self-check` slot; without the slot the line falls back to
  the bare `- Batch: <id>`, which still names the batch.
