## Added

- `infra/tool/check/check_doc_ids.py` — the bilingual delivery audit is a
  repeatable command: every controlled document in `docs/specs/controlled/`
  is paired with its `.zh-CN.md` translation and the id sets (`REQ-NNN`,
  `TC-NNN`, `ADR-NNNN`) are compared per pair; a differing set, a missing
  translation or a translation without a source exits non-zero. The checker
  is verified in both directions — a seeded mismatch fixture fails, the
  real tree passes (`TC-DOC-001`, `REQ-026`).
- The controlled-set declaration in `docs/README.md` now lists the four
  existing controlled documents; SCMP is ruled out of the v0.1.0
  controlled set (no frozen baseline, `governance: small` — ruling
  2026-11-21).
