# B28 — Detail page

## Changed

- The switcher becomes same-row member circles from the shared row
  model (`REQ-011`): five circles, the last row at its actual count,
  defaulting to the tapped phoneme; navigation never crosses rows and
  the ends of a row do not wrap (the chip strip and the catalog-order
  prev/next arrows are gone).
- The zone order follows wireframe P3 (`SDD §3.3`): mouth-shape slot
  beside the single writing grid, pronunciation button below, then the
  2×2 example cards; the per-zone duplicate glyph display is dropped
  and the star row is reduced.
- The stroke order auto-plays once when a phoneme appears and tapping
  the writing grid replays it with pronunciation (decision 13); the
  separate play control is gone, the stroke-pending state is unchanged.

## Added

- The handwriting overlay (`REQ-035`): the top-right pen control opens
  a free-tracing board covering the detail page — grey model, cross
  guides, clear-and-rewrite, done returns — with no route change and
  never a score or verdict.
