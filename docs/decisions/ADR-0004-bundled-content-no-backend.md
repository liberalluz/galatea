# ADR-0004 · Bundled content data and on-device state, no backend

## Context

The correspondence data must be updatable independently of app code
(`REQ-012`), the app must work offline (`REQ-029`), the About page discloses
that mastery and review progress live only on the device (design-spec
`about-limitation`), and the project is a single-developer, non-commercial oss
product (PRD §1, §3).

## Decision

Phoneme data, notation mappings, example words/sentences and glyph/stroke
records ship as versioned data files bundled with the app, kept separate from
UI code; content updates ship with app releases. Mastery, review state and
settings are stored on-device only. v0.1.0 has no backend service.

## Consequences

- Content corrections are a data commit plus a release, never a code change
  (satisfies `REQ-012` independence).
- No server operations, costs or privacy surface in v0.1.0.
- Progress does not sync across devices or survive data clearing — already
  disclosed to users in the About page, so no hidden expectation.

## Rejected alternatives

- **A backend service for content or progress sync** — unjustified for a
  single-developer v0.1.0; the device-only limitation is disclosed instead of
  hidden.
- **Embedding the phoneme data in application code** — violates the
  independent-update requirement (`REQ-012`) and couples content fixes to
  binary releases.
