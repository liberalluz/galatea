## Added

- The detail page mouth zone shows a mouth-shape slot per phoneme; while
  the licensed artwork is missing it renders the fixed `口型图准备中`
  placeholder at the same size, never a blank area (`REQ-007`).
- The detail page words zone shows 4 example cards in a 2×2 grid, each with
  an image slot and a word/sentence and no translation text (`REQ-010`).
- A card whose image is missing keeps the word/sentence visible and renders
  the fixed same-size image placeholder; cards are never hidden (`REQ-014`).
- New bundled, versioned examples data file `assets/content/examples.v1.json`
  (48 phonemes × 4 word/sentence pairs, ED draft) with optional asset paths;
  missing or unloadable paths fall back to the placeholders.
