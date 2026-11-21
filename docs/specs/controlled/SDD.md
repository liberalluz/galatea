# SDD — galatea v0.2.0

[简体中文](SDD.zh-CN.md) · English

## 1. Scope and sources

- Requirements: `docs/specs/controlled/SRS.md` (`REQ-001`–`REQ-035`;
  `REQ-031`–`REQ-035` restate the v0.2.0 interaction revamp confirmed by the
  product owner on 2026-11-21; `REQ-025` is a v0.2.x patch and listed for
  traceability).
- Behaviour and layout: `galatea-docs/design/design-spec.md` — cited, not
  copied. Items marked as fixed there are not re-invented here.
- Interaction paths: `galatea-docs/design/ux-flows.md` (one section per R id,
  including failure/empty states and the quality-constraints section).
- Wireframes: `galatea-docs/design/prototypes.md` (P0–P8).
- Decisions with long-term cost: `docs/decisions/ADR-0001`–`ADR-0004`.

## 2. Architecture overview

Single Flutter codebase, Web first (v0.1.0), iOS in a v0.2.x patch. Three
layers:

- **Content layer** — bundled versioned data files (phonemes, notation
  mappings, examples, glyphs/strokes) plus the reserved media paths; no
  backend (ADR-0004).
- **Domain layer** — phoneme catalogue (ADR-0001), practice session state,
  star/review engine implementing the PRD product rules, settings.
- **UI layer** — the two-tab shell with drill-down pages; all behaviour and
  fallback states follow design-spec Components and ux-flows failure branches.

Dependencies flow one way: `UI → domain → content`; the domain layer never
reads UI state and the content layer never imports domain types.

## 3. Design sections

### §3.1 App shell and navigation

- Persistent bottom tabs (`tab-chart` / `tab-me`), order and labels fixed
  (design-spec Components), default tab `tab-chart`; each tab keeps its scroll
  position (`REQ-031`). Detail, quiz, review, settings and about are
  drill-down pages with top back navigation; the bottom tab bar is not shown
  on drill-downs and back restores the previous scroll position.
- First-run overlay (`REQ-033`, skeleton S1, P6): shown once, dismiss by tap
  or the `first-run-dismiss` button, never blocks the underlying page.
- Review status strip (`REQ-022`, decision 8, P1/P5): shown on the chart page
  above the grid and at the bottom of the Me tab mastery card; N = 0 or
  unavailable hides it; tapping deep-links to the Me tab review entry — the
  practice tab no longer exists.
- Web build targets the full slice (`REQ-024`); iOS (`REQ-025`, v0.2.x patch)
  reuses this design unchanged (design-spec scope).

### §3.2 Chart page

- **Shared row model** — one row definition serves the chart grid, the
  row-select practice mode and the detail circles: within each coarse group
  (vowel / consonant) rows follow the place-of-articulation order, 5 slots per
  row and the last row at its actual count; the data layer exposes the row
  partition so the three surfaces compose the same grouping instead of
  re-deriving it (`REQ-002`, `REQ-011`, `REQ-015`; PD row definition A).
- 5-column print-glyph grid, only the two coarse group headers rendered and
  fine category labels hidden, last row left-aligned, no cross-group rows;
  narrow screens scroll horizontally or scale, all 48 phonemes reachable
  (`REQ-002`, wireframe P1). No source footer on the chart; the source label
  lives on the About page (`REQ-001`, decision 7).
- Notation switch KK/DJ/IPA at the top, default KK, switching keeps the
  current phoneme, missing glyphs keep the previous notation (`REQ-003`,
  ADR-0001).
- Default state: tap opens the detail page (`REQ-004`); direct-read mode:
  top-right toggle, tap plays audio only, the fixed hint line
  (copy `reading-mode-hint`) sits between the switch row and the grid
  (`REQ-005`, wireframe P2).
- Practice entry (`REQ-015`, decision 3, P1): a right-bottom floating button
  (idle state dark) enters an in-page row-select state — the top bar becomes
  the fixed `请选择` bar with the selected-row count and a cancel control; the
  first row is selected by default (whole row highlighted) and tapping another
  row moves the single-row selection — one row at a time; confirm starts the
  quiz on the selected row. The
  floating button and the row-select state ignore the direct-read toggle.
  No standalone range screen exists.

### §3.3 Detail page

Fixed zone order (decision 11/13, wireframe P3): same-row circle switcher →
large glyph + stars (reduced) → mouth-shape slot beside the single writing
grid → pronunciation button → 2×2 example cards (`REQ-006`–`REQ-011`).

- Same-row member circles (`REQ-011`, decision 5): the switcher renders the
  current phoneme's row members from the shared row model (5 circles, last
  row its actual count) and defaults to the tapped phoneme, not the row head;
  adjacent means same-row member, so navigation never crosses rows and the
  ends of a row do not wrap.
- Mouth-shape slot per phoneme (`REQ-007`): a fixed placeholder slot ships
  when licensed artwork is missing and the data structure reserves the image
  path; the placeholder is never another phoneme's image and never a blank
  area.
- Single writing grid (`REQ-008`, `REQ-009`, ADR-0003): the stroke-order
  animation auto-plays once on entry; tapping the grid replays the stroke
  order with pronunciation (decision 13); missing stroke data keeps the fixed
  `stroke-pending` state with playback disabled, independent of tracing.
- Handwriting overlay (`REQ-035`, decision 12): the top-right ✎ control opens
  a free-tracing board as an overlay covering the detail page — grey model,
  cross guides, strokes follow the pointer, clear-and-rewrite, done/close
  returns to the detail page. It is an overlay, not a route, and it never
  produces a score or verdict; scoring stays with the writing task
  (`REQ-018`).
- Pronunciation button with loading/ready/playing/failed states; failure
  retries once and never blocks other zones; the button remains the explicit
  accessible audio entry beside the writing-grid hotspot (audio pipeline per
  §3.7).
- 2×2 example cards (`REQ-010`, decision 10): one image + one word + one
  sentence per card, no translation; missing images use a placeholder, cards
  are never hidden (`REQ-014`).

### §3.4 Practice

- Entry and range (`REQ-015`, `REQ-034`): the quiz opens from the chart's
  row-select confirm (new practice over the selected row) or from the review
  entry (due queue) — both render the same shared quiz page and only the item
  source differs; per-source selection is a domain-layer concern, not a page
  variant.
- Progress bar and batch label are persistent at the top (`REQ-020`,
  decision 4): the top-right label shows vowel / consonant matching the
  selected row's coarse group; a review session shows its own source's label.
- Task types with fixed shapes: recognition (print stem, 4 options, 1 correct),
  listening (audio stem, 2 options, highlight then confirm, skippable on audio
  failure), writing (handwritten model, tracing area, ✓/× verdict, empty
  submit shows `trace-first`), matching (pronunciations to symbols in another
  notation, matched pairs grey out, mismatches snap back) — `REQ-016`–
  `REQ-019`. Verdict leniency for writing is fixed at design review (SRS TBD).
- Feedback is immediate after every answer; completion counts a phoneme as
  done at ≥ 1 answer, and the completion denominator is the selected-row
  phonemes (`REQ-021`, PRD product rules); denominator 0 hides the bar; each
  area with missing data degrades independently, never a whole-page failure.

### §3.5 Review and mastery

- The review entry lives in the Me tab under the mastery card (`REQ-022`,
  decision 8, P5); the review status strip deep-links there (§3.1). Due
  phonemes enter by the star-drop rule and the 1/2/4/7/15-day intervals; a
  wrong answer resets to interval 1; an empty queue shows `review-empty`; the
  review session uses the shared quiz page (`REQ-034`).
- Every phoneme carries a 0–3 star rating shared across notations (ADR-0001);
  stars move strictly by the PRD product rules. Mastery statistics live in the
  Me tab home, filterable by notation, denominator always 48 (`REQ-023`).

### §3.6 Content data model

- One phoneme entity with per-notation display fields, examples, glyph and
  stroke records (ADR-0001). Chart and stems render print glyphs; tracing and
  writing tasks render the handwritten glyph (`REQ-013`). Example records
  reserve the image field and mouth-shape records reserve the image path so
  placeholder delivery can be replaced without schema change (`REQ-007`,
  `REQ-014`).
- Data files are bundled, versioned and independent of app code; the source
  label (`source-note` copy, book title + ISBN) marks the single source and is
  rendered on the About page only (`REQ-001`, `REQ-012`, decision 7,
  ADR-0004). Contingency: if booklet data cannot be licensed, the set is built
  from public KK/DJ/IPA tables and labelled as such (SRS contingencies).

### §3.7 Audio pipeline

- Audio is synthesized on device in realtime (Web Speech) with no cache
  (`REQ-006`, `REQ-029`); the 2026-11-21 product ruling supersedes the
  ADR-0002 cache design, which remains the historical record. Synthesis
  failure shows the fixed needs-network state and does not block practice.

### §3.8 Me tab and settings

- The Me tab hosts four pages (`REQ-032`, decision 8): home (mastery
  statistics card, review status strip, entries to review / settings / about),
  the review drill-down (§3.5), settings and about.
- Settings live in Me → Settings: language (zh-CN / en-US, applies immediately to
  all copy) and audio toggle (affects the pronunciation button and listening
  tasks) (`S3`, wireframe P7).
- About page (`S4`, wireframe P8) carries version, the single source label
  (`REQ-001`, `REQ-012`), oss note, feedback entry and the device-only
  limitation disclosure.

### §3.9 Quality constraints (REQ-027–REQ-030)

- **Fonts (`REQ-027`)**: fallback font chain covering IPA-only glyphs
  (ʃ θ ŋ ɚ …); a missing glyph renders the fixed placeholder box plus the
  fixed missing-glyph copy per design-spec R27 (literal string, not yet a Copy
  key), never tofu.
- **Small screens (`REQ-028`)**: 5-column grid scrolls horizontally or scales,
  no clipping, no column wrap, all 48 phonemes reachable; every tappable area
  ≥ 44 pt.
- **Offline (`REQ-029`)**: phoneme data, notation mappings and word/sentence
  texts are local from install; audio is synthesized on device with no cache
  files (§3.7); the practice flow has no hard network dependency.
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
| `REQ-001` | §3.2, §3.6, §3.8 |
| `REQ-002` | §3.2 |
| `REQ-003` | §3.2, ADR-0001 |
| `REQ-004` | §3.2 |
| `REQ-005` | §3.2 |
| `REQ-006` | §3.3, §3.7 |
| `REQ-007` | §3.3, §3.6 |
| `REQ-008` | §3.3, ADR-0003 |
| `REQ-009` | §3.3, ADR-0003 |
| `REQ-010` | §3.3 |
| `REQ-011` | §3.2, §3.3 |
| `REQ-012` | §3.6, §3.8, ADR-0004 |
| `REQ-013` | §3.6, ADR-0003 |
| `REQ-014` | §3.3, §3.6 |
| `REQ-015` | §3.2, §3.4 |
| `REQ-016` | §3.4 |
| `REQ-017` | §3.4 |
| `REQ-018` | §3.4, ADR-0003 |
| `REQ-019` | §3.4 |
| `REQ-020` | §3.4 |
| `REQ-021` | §3.4, §3.8 |
| `REQ-022` | §3.1, §3.5, §3.8 |
| `REQ-023` | §3.5, §3.8, ADR-0001 |
| `REQ-024` | §3.1 |
| `REQ-025` | §3.1 (v0.2.x patch, reuses this design) |
| `REQ-026` | §3.10 |
| `REQ-027` | §3.9 |
| `REQ-028` | §3.9 |
| `REQ-029` | §3.7, §3.9, ADR-0004 |
| `REQ-030` | §3.9 |
| `REQ-031` | §3.1 |
| `REQ-032` | §3.5, §3.8 |
| `REQ-033` | §3.1 |
| `REQ-034` | §3.4 |
| `REQ-035` | §3.3 |

## 5. Decisions

- `ADR-0001` — one phoneme entity, notations as display mappings.
- `ADR-0002` — audio via TTS with on-device caching; its cache aspect is
  superseded by the 2026-11-21 product ruling (§3.7, `REQ-029`).
- `ADR-0003` — handwritten glyphs and stroke order as authored vector data.
- `ADR-0004` — bundled content data and on-device state, no backend.
