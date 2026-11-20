## Added

- The detail writing zone hosts a tracing area over the handwritten glyph;
  pointer strokes render in ink over the faint model, are kept when input
  is interrupted, stay after finishing, and clear with the restart control
  (`REQ-008`, `TC-TRACE-001`).
- The stroke-order control plays the handwritten glyph stroke by stroke and
  can replay, ending on the complete glyph; phonemes without stroke data
  show the fixed preparing label with the control disabled, independent of
  the tracing area (`REQ-009`, `TC-TRACE-002`).
- New bundled, versioned glyph data file `assets/content/glyphs.v1.json`
  (48 phonemes × ordered simplified strokes as normalized polylines, ED
  draft) with the handwritten model fed to the tracing area and the
  stroke-order animation (`REQ-013`, `ADR-0003`).
