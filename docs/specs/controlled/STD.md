# STD — galatea v0.1.0

[简体中文](STD.zh-CN.md) · English

## Cases

Case bodies for the mapping in `STP.md`. `REQ-025` has no case in this slice —
it is a recorded TBD row in the STP.

### `TC-CHART-001`

- Covers: `REQ-001`
- Preconditions: app served by the Flutter Web build; bundled phoneme data present.
- Steps:
  1. Open the chart page.
  2. Count the rendered phoneme entries.
  3. Inspect the source label on the chart page.
- Exit: exactly 50 entries render and the source label is visible.

### `TC-CHART-002`

- Covers: `REQ-002`
- Preconditions: chart page open.
- Steps:
  1. Observe the grid layout.
  2. Check each phoneme against its category group header.
- Exit: 5 columns render and each of the 50 phonemes appears exactly once in its category group.

### `TC-CHART-003`

- Covers: `REQ-003`
- Preconditions: fresh state (first launch) or notation preference reset to KK.
- Steps:
  1. Confirm the default notation is KK.
  2. Select a phoneme, switch to DJ, then to IPA.
- Exit: symbols re-render per notation while the selected phoneme stays the same.

### `TC-CHART-004`

- Covers: `REQ-004`
- Preconditions: chart page open, reading mode off.
- Steps: tap any symbol.
- Exit: the detail page of that symbol opens.

### `TC-CHART-005`

- Covers: `REQ-005`
- Preconditions: chart page open, reading mode switched on top-right.
- Steps:
  1. Observe the status hint line.
  2. Tap a symbol.
- Exit: audio plays, navigation does not occur, and the hint line stays visible.

### `TC-DETAIL-001`

- Covers: `REQ-006`
- Preconditions: detail page of any phoneme open.
- Steps:
  1. Tap the pronunciation button.
  2. Repeat on a second phoneme.
- Exit: audio starts on each tap; forcing a failure shows the fixed retry state without blocking other sections.

### `TC-DETAIL-002`

- Covers: `REQ-007`
- Preconditions: detail pages reachable for all 50 phonemes.
- Steps: open every phoneme's detail page and inspect the mouth-shape slot.
- Exit: each page shows a mouth-shape image; a missing asset renders the fixed preparing placeholder, never a blank area.

### `TC-DETAIL-003`

- Covers: `REQ-010`
- Preconditions: detail page open for a phoneme with complete example data.
- Steps: inspect the 2×2 example card grid.
- Exit: 4 cards render, each with image + word/sentence and no translation text.

### `TC-DETAIL-004`

- Covers: `REQ-011`
- Preconditions: detail page open for a mid-list phoneme.
- Steps:
  1. Tap next repeatedly until the last phoneme.
  2. Tap previous repeatedly until the first phoneme.
- Exit: each tap refreshes all sections with the adjacent phoneme; at both ends the bar does not wrap.

### `TC-TRACE-001`

- Covers: `REQ-008`
- Preconditions: detail page open for a phoneme with handwritten glyph data.
- Steps:
  1. Draw several strokes over the tracing area.
  2. Interrupt input (pointer leave / second touch) and resume.
- Exit: strokes render over the handwritten glyph and strokes drawn so far are kept on interruption.

### `TC-TRACE-002`

- Covers: `REQ-009`
- Preconditions: detail pages open — one with stroke data, one without.
- Steps:
  1. Play the stroke-order animation on the first page.
  2. Inspect the control on the second page.
- Exit: the animation plays on the first; the second shows the fixed preparing state with the control disabled, independent of the tracing area.

### `TC-CONTENT-001`

- Covers: `REQ-012`
- Preconditions: repository checked out; app served in development mode.
- Steps:
  1. Locate the correspondence data file and its labelled source.
  2. Change one mapping value in the data file only (no code change).
  3. Reload the app and inspect the affected phoneme.
- Exit: the displayed mapping follows the edited data and the data file carries a labelled source.

### `TC-CONTENT-002`

- Covers: `REQ-013`
- Preconditions: chart, practice stems and detail tracing areas reachable.
- Steps: compare glyph rendering on the chart and question stems against the tracing/writing surfaces.
- Exit: chart and stems render print glyphs; tracing and writing tasks use the handwritten glyph with stroke data.

### `TC-CONTENT-003`

- Covers: `REQ-014`
- Preconditions: example data includes at least one phoneme with a missing image asset.
- Steps: open that phoneme's detail page.
- Exit: the affected card shows the fixed image placeholder; all other cards show their images.

### `TC-QUIZ-001`

- Covers: `REQ-015`
- Preconditions: practice range selection page open.
- Steps:
  1. Apply one category tag; observe the set.
  2. Multi-select and unselect phonemes on the 5-column grid.
  3. Deselect everything and observe confirm.
- Exit: tags filter the set, the grid multi-selects/unselects, and confirm stays disabled with an empty selection.

### `TC-QUIZ-002`

- Covers: `REQ-016`
- Preconditions: a recognition task rendered for a selected range.
- Steps: count the options and identify the correct one from the data.
- Exit: a print-glyph stem with exactly 4 spelling options, exactly 1 correct.

### `TC-QUIZ-003`

- Covers: `REQ-017`
- Preconditions: a listening task rendered.
- Steps:
  1. Play the stem.
  2. Select an option and observe the highlight before confirming.
- Exit: audio plays, exactly 2 symbol options show, and the selection highlights before confirm.

### `TC-QUIZ-004`

- Covers: `REQ-018`
- Preconditions: a writing task rendered; stroke-overlap threshold per the design review is implemented.
- Steps:
  1. Trace the model closely and confirm.
  2. Trace deliberately off-shape and confirm.
- Exit: each attempt produces a ✓ or × verdict per the implemented threshold.

### `TC-QUIZ-005`

- Covers: `REQ-019`
- Preconditions: a matching task rendered.
- Steps: pair every pronunciation to a symbol one by one.
- Exit: pairs connect one at a time; each matched pair greys out and cannot be re-paired.

### `TC-QUIZ-006`

- Covers: `REQ-020`
- Preconditions: a practice session running over a known range.
- Steps: answer items and compare the progress bar and top-right range label against the selection.
- Exit: the bar advances per answered item and the label matches the selected range.

### `TC-QUIZ-007`

- Covers: `REQ-021`
- Preconditions: a practice session over a range of known size.
- Steps:
  1. Confirm an answer and observe feedback timing.
  2. Complete the session and read the completion rate.
- Exit: feedback appears immediately after confirm; the rate equals in-range phonemes answered ≥ 1 time ÷ in-range phonemes.

### `TC-REVIEW-001`

- Covers: `REQ-022`
- Preconditions: app state resettable; PRD review intervals (1/2/4/7/15 days) as reference.
- Steps:
  1. Answer a phoneme wrong; check star and queue.
  2. Answer correctly on consecutive review days per the intervals.
  3. Answer wrong during a review; observe the interval.
- Exit: star −1 and queue entry on wrong; interval advances 1/2/4/7/15 days on consecutive correct answers and resets on a wrong one.

### `TC-REVIEW-002`

- Covers: `REQ-023`
- Preconditions: a phoneme with a non-zero star rating.
- Steps:
  1. Switch notation KK → DJ → IPA on the phoneme.
  2. Open the Me tab statistics and filter by each notation.
- Exit: the star is identical across all three notations; statistics filter per notation with denominator 50.

### `TC-PLATFORM-001`

- Covers: `REQ-024`
- Preconditions: release-mode Flutter Web build served locally.
- Steps: run the chart, detail, practice and review flows of this plan in a browser.
- Exit: all flows complete end-to-end on the Web build without errors.

### `TC-DOC-001`

- Covers: `REQ-026`
- Preconditions: repository checked out; toolchain available.
- Steps:
  1. List `docs/specs/controlled/` and confirm each bare source has its `.zh-CN.md` pair with identical ids.
  2. Run `check_language.py --root .` and the stage checkers.
- Exit: pairs complete with identical ids and `check_language.py` reports 0 errors.

### `TC-QUAL-001`

- Covers: `REQ-027`
- Preconditions: Web build served; browser DevTools open.
- Steps: navigate the chart, question stems and detail pages; screenshot IPA-only symbols (ʃ θ ŋ ɚ …).
- Exit: all IPA-only symbols render via the fallback chain with no tofu (screenshot evidence).

### `TC-QUAL-002`

- Covers: `REQ-028`
- Preconditions: viewport set to ≤ 360 px width.
- Steps:
  1. Scroll and scale the 5-column grid; check for clipping or column wrap.
  2. Measure tappable practice option areas.
- Exit: no clipping or wrap; all 50 phonemes reachable; option areas ≥ 44 pt.

### `TC-QUAL-003`

- Covers: `REQ-029`
- Preconditions: audio for at least one phoneme generated once (cache warm).
- Steps: disable the network; open chart, correspondence data, word/sentence texts; play the cached audio.
- Exit: data and texts work offline and the cached audio plays.

### `TC-QUAL-004`

- Covers: `REQ-030`
- Preconditions: Web build served; screen reader / keyboard available.
- Steps:
  1. Inspect aria-labels / spoken text on symbols.
  2. Tab through every button and check focus visibility.
- Exit: symbols expose labels; all buttons keyboard-operable with visible focus.
