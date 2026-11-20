# SDD — galatea v0.1.0

[简体中文](SDD.zh-CN.md) · English

## 1. Scope and sources

- Requirements: `docs/specs/controlled/SRS.md` (`REQ-001`–`REQ-030`, P1 slice
  v0.1.0; `REQ-025` is v0.2.0 and listed for traceability).
- Behaviour and layout: `galatea-docs/design/design-spec.md` — cited, not
  copied. Items marked as fixed there are not re-invented here.
- Interaction paths: `galatea-docs/design/ux-flows.md` (one section per R id,
  including failure/empty states and the quality-constraints section).
- Wireframes: `galatea-docs/design/prototypes.md` (P0–P8).
- Decisions with long-term cost: `docs/decisions/ADR-0001`–`ADR-0004`.

## 2. Architecture overview

Single Flutter codebase, Web first (v0.1.0), iOS in v0.2.0. Three layers:

- **Content layer** — bundled versioned data files (phonemes, notation
  mappings, examples, glyphs/strokes) plus the audio cache; no backend
  (ADR-0004).
- **Domain layer** — phoneme catalogue (ADR-0001), practice session state,
  star/review engine implementing the PRD product rules, settings.
- **UI layer** — the three-tab shell with drill-down pages; all behaviour and
  fallback states follow design-spec Components and ux-flows failure branches.

Dependencies flow one way: `UI → domain → content`; the domain layer never
reads UI state and the content layer never imports domain types.

## 3. Design sections

### §3.1 App shell and navigation

- Persistent bottom tabs (`tab-chart` / `tab-practice` / `tab-me`), order and
  labels fixed (design-spec Components), default tab `tab-chart`; each tab
  keeps its scroll
  position. Detail, settings and about are drill-down pages with top back
  navigation; the bottom tab bar is not shown on drill-downs and back restores
  the previous scroll position.
- First-run overlay (`S1`, P6): shown once, dismiss by tap or the
  `first-run-dismiss` button, never blocks the underlying page.
- Review status bar (`S2`, P1/P5): on the chart page above the grid; N = 0 or
  unavailable hides the whole row; tapping deep-links to the practice tab in
  review mode.
- Web build targets the full slice (`REQ-024`); iOS (`REQ-025`, v0.2.0) reuses
  this design unchanged (design-spec scope).

### §3.2 Chart page

- 5-column print-glyph grid grouped by phonetic category, last row
  left-aligned, no cross-group rows; narrow screens scroll horizontally or
  scale, all 48 phonemes reachable (`REQ-001`, `REQ-002`, wireframe P1).
- Notation switch KK/DJ/IPA at the top, default KK, switching keeps the
  current phoneme, missing glyphs keep the previous notation (`REQ-003`,
  ADR-0001).
- Default state: tap opens the detail page (`REQ-004`); direct-read mode:
  top-right toggle, tap plays audio only, the fixed hint line
  (copy `reading-mode-hint`) sits between the switch row and the grid
  (`REQ-005`, wireframe P2).
- Review status bar per §3.1 (`S2`).

### §3.3 Detail page

Fixed zone order: horizontal phoneme switcher → pronunciation → mouth shape →
writing (model + stroke order) → 2×2 example cards (`REQ-006`–`REQ-011`,
wireframe P3).

- Pronunciation button with loading/ready/playing/failed states; failure
  retries once and never blocks other zones; audio pipeline per ADR-0002.
- Mouth-shape image per phoneme; missing image uses a placeholder of the same
  size, never another phoneme's image.
- Tracing area (touch, strokes follow immediately, interrupted strokes are
  kept) and stroke-order playback control (disabled with the fixed
  `stroke-pending` label when stroke data is missing) — glyph data per
  ADR-0003.
- 2×2 example cards: image + word/sentence, no translation; missing images use
  a placeholder, cards are never hidden (`REQ-010`, `REQ-014`).
- Horizontal switcher moves to adjacent phonemes, all zones refresh, edges do
  not wrap (`REQ-011`).

### §3.4 Practice

- Range selection: category tags + 5-column multi-select grid + confirm;
  confirm is disabled with no selection; empty filter result shows the fixed
  empty state (`REQ-015`, wireframe P4).
- Task types with fixed shapes: recognition (print stem, 4 options, 1 correct),
  listening (audio stem, 2 options, highlight then confirm, skippable on audio
  failure), writing (handwritten model, tracing area, ✓/× verdict, empty
  submit shows `trace-first`), matching (pronunciations to symbols in another
  notation, matched pairs grey out, mismatches snap back) — `REQ-016`–
  `REQ-019`. Verdict leniency for writing is fixed at design review (SRS TBD).
- Progress bar and range label are persistent at the top; the denominator is
  the selected range; denominator 0 hides the bar; each area with missing data
  degrades independently, never a whole-page failure (`REQ-020`).
- Feedback is immediate after every answer; completion counts a phoneme as
  done at ≥ 1 answer in range, independent of correctness (`REQ-021`, PRD
  product rules).

### §3.5 Review and mastery

- Review mode is a mode switch inside the practice tab, not a tab; due
  phonemes enter by the star-drop rule and the 1/2/4/7/15-day intervals; a
  wrong answer resets to interval 1; an empty queue shows `review-empty`
  (`REQ-022`, wireframe P5).
- Every phoneme carries a 0–3 star rating shared across notations (ADR-0001);
  stars move strictly by the PRD product rules. Mastery statistics live in the
  Me tab, filterable by notation, denominator always 48 (`REQ-023`).

### §3.6 Content data model

- One phoneme entity with per-notation display fields, examples, glyph and
  stroke records (ADR-0001). Chart and stems render print glyphs; tracing and
  writing tasks render the handwritten glyph (`REQ-013`).
- Data files are bundled, versioned and independent of app code; the source
  label (`source-note` copy) marks the single source (`REQ-001`, `REQ-012`,
  ADR-0004). Contingency: if booklet data cannot be licensed, the set is built
  from public KK/DJ/IPA tables and labelled as such (SRS contingencies).

### §3.7 Audio pipeline

- TTS generation on first request, cached on device; later plays read the
  cache; offline without cache shows the fixed needs-network state and does
  not block practice (`REQ-006`, `REQ-029`, ADR-0002).

### §3.8 On-device persistence and settings

- Local store for stars, review schedule, completion counts and settings;
  device-only, disclosed in About (`about-limitation`) (`REQ-021`–`REQ-023`,
  ADR-0004).
- Settings live in Me → Settings: language (zh-CN / en-US, applies immediately to
  all copy) and audio toggle (affects the pronunciation button and listening
  tasks) (`S3`, wireframe P7).
- About page (`S4`, wireframe P8) carries version, source note, oss note,
  feedback entry and the device-only limitation disclosure.

### §3.9 Quality constraints (REQ-027–REQ-030)

- **Fonts (`REQ-027`)**: fallback font chain covering IPA-only glyphs
  (ʃ θ ŋ ɚ …); a missing glyph renders the fixed placeholder box plus the
  fixed missing-glyph copy per design-spec R27 (literal string, not yet a Copy
  key), never tofu.
- **Small screens (`REQ-028`)**: 5-column grid scrolls horizontally or scales,
  no clipping, no column wrap, all 48 phonemes reachable; every tappable area
  ≥ 44 pt.
- **Offline (`REQ-029`)**: phoneme data, notation mappings and word/sentence
  texts are local from install; audio follows ADR-0002; the practice flow has
  no hard network dependency.
- **Accessibility (`REQ-030`)**: aria-labels / spoken text on symbols (fallback
  to phoneme id), keyboard-operable buttons with visible focus, states never
  colour-only (WCAG AA contrast). Tab order per design-spec Accessibility.

### §3.10 Bilingual delivery

- Repository language en-US: SDD/ADR and other controlled docs follow the
  repository language rules; documents-repo product docs keep their
  translation pairs (`REQ-026`).
- In-app copy: zh-CN is the source set, en-US the translation, using the fixed
  Copy table in design-spec (30 keys; keys marked A15 pending product-owner
  confirmation are wired but may change wording). UI language switch applies
  immediately.

## 4. Requirement mapping

| REQ | Design |
|---|---|
| `REQ-001` | §3.2, §3.6 |
| `REQ-002` | §3.2 |
| `REQ-003` | §3.2, ADR-0001 |
| `REQ-004` | §3.2 |
| `REQ-005` | §3.2 |
| `REQ-006` | §3.3, §3.7, ADR-0002 |
| `REQ-007` | §3.3 |
| `REQ-008` | §3.3, ADR-0003 |
| `REQ-009` | §3.3, ADR-0003 |
| `REQ-010` | §3.3 |
| `REQ-011` | §3.3 |
| `REQ-012` | §3.6, ADR-0004 |
| `REQ-013` | §3.6, ADR-0003 |
| `REQ-014` | §3.3 |
| `REQ-015` | §3.4 |
| `REQ-016` | §3.4 |
| `REQ-017` | §3.4, ADR-0002 |
| `REQ-018` | §3.4, ADR-0003 |
| `REQ-019` | §3.4 |
| `REQ-020` | §3.4 |
| `REQ-021` | §3.4, §3.8 |
| `REQ-022` | §3.5, §3.8 |
| `REQ-023` | §3.5, §3.8, ADR-0001 |
| `REQ-024` | §3.1 |
| `REQ-025` | §3.1 (v0.2.0 slice, reuses this design) |
| `REQ-026` | §3.10 |
| `REQ-027` | §3.9 |
| `REQ-028` | §3.9 |
| `REQ-029` | §3.7, §3.9, ADR-0002, ADR-0004 |
| `REQ-030` | §3.9 |

## 5. Decisions

- `ADR-0001` — one phoneme entity, notations as display mappings.
- `ADR-0002` — audio via TTS with on-device caching.
- `ADR-0003` — handwritten glyphs and stroke order as authored vector data.
- `ADR-0004` — bundled content data and on-device state, no backend.
