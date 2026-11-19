# ADR-0003 · Handwritten glyphs and stroke order as authored vector data

## Context

No available font provides KK handwritten glyphs with stroke-order data. The
product needs tracing (`REQ-008`), stroke-order animation (`REQ-009`) and a
✓/× verdict on writing tasks (`REQ-018`). PRD §7 assigns production of
handwritten glyphs and stroke data to ED, with a documented fallback (generic
handwritten IPA font + simplified strokes).

## Decision

Each handwritten glyph is authored as ordered vector stroke data (one data
record per phoneme: an ordered list of strokes). The same record drives the
stroke-order animation and the tracing surface. Print glyphs come from a font
with a fallback chain (see SDD §3.9), keeping the two glyph systems separate
per `REQ-013`.

## Consequences

- Glyph quality and verdict granularity depend on authored data; the content
  pipeline must keep stroke records in version control next to the phoneme
  data.
- The fallback path (font + simplified strokes) degrades tracing fidelity, as
  accepted in the SRS contingencies.
- A ✓/× verdict can compare captured strokes against the authored stroke
  record; leniency is fixed at the design review, not in this ADR.

## Rejected alternatives

- **A handwriting font** — fonts carry no stroke order and no per-stroke
  control, so animation and stroke-level verdicts are impossible.
- **Raster images of handwritten glyphs** — they scale poorly on small
  screens, cannot animate stroke order, and cannot support a meaningful
  verdict.
