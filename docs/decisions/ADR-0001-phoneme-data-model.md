# ADR-0001 · One phoneme entity, notations as display mappings

## Context

The product shows the same 50 phonemes in three notation systems (KK default,
DJ, IPA). The product rules (PRD C3) require mastery to be counted per phoneme
and shared across notations, and notation switching must keep the current
phoneme selected. Modelling three parallel symbol sets would multiply the
mastery denominator by 3 and break the C3 counting rule.

## Decision

One phoneme entity per phoneme, identified by a stable phoneme id. Each
notation is a display mapping attached to that entity (a symbol field per
notation), not a separate object. Stars, review state and statistics are keyed
by phoneme id only; notation is a display filter.

## Consequences

- Notation switching is a view change with no state migration.
- Mastery statistics can filter by notation for display while the denominator
  stays 50.
- Adding or correcting a notation is a data edit on the mapping, not a
  re-modelling (supports `REQ-003`, `REQ-012`, `REQ-023`).

## Rejected alternatives

- **Per-notation phoneme entities with per-notation mastery** — breaks the C3
  shared-mastery rule and triples the metric denominator.
- **Converting symbols between notations at runtime without a stored mapping** —
  cannot satisfy the labelled single-source requirement (`REQ-012`); conversions
  would be unverifiable against the reference data.
