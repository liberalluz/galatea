# STD — galatea v0.2.0

[简体中文](STD.zh-CN.md) · English

## Cases

Case bodies for the mapping in `STP.md`. `REQ-025` has no case in this slice —
it is a recorded TBD row in the STP.

### `TC-CHART-001`

- Covers: `REQ-001`
- Preconditions: app served by the Flutter Web build; bundled phoneme data present.
- Steps:
  1. Open the chart page and count the rendered phoneme entries.
  2. Inspect the chart page for a source label or footer.
  3. Open the Me tab → About page and inspect its source entry.
- Exit: exactly 48 entries render; the chart shows no source label; the About
  page shows the book-title + ISBN source.

### `TC-CHART-002`

- Covers: `REQ-002`
- Preconditions: chart page open.
- Steps:
  1. Observe the grid layout and the group headers.
  2. Check each phoneme against its coarse group and row position.
- Exit: 5 columns render; only the vowel / consonant coarse headers are
  visible and no fine category label is displayed; rows follow the
  place-of-articulation order at 5 per row with the last row at its actual
  count, and each of the 48 phonemes appears exactly once.

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

### `TC-NAV-001`

- Covers: `REQ-031`
- Preconditions: app served by the Flutter Web build, first launch completed.
- Steps:
  1. Inspect the bottom navigation bar.
  2. Open the detail page, a quiz session, review, settings and about.
  3. Return from each drill-down with the top back control.
- Exit: the bottom bar shows exactly the chart tab and the Me tab; no
  drill-down adds a tab; back returns to the previous page with its scroll
  position.

### `TC-DETAIL-001`

- Covers: `REQ-006`
- Preconditions: detail page of any phoneme open.
- Steps:
  1. Tap the pronunciation button.
  2. Repeat on a second phoneme.
- Exit: audio starts on each tap; forcing a failure shows the fixed retry state without blocking other sections.

### `TC-DETAIL-002`

- Covers: `REQ-007`
- Preconditions: detail pages reachable for all 48 phonemes; at least one phoneme
  has no mouth-shape asset in the data.
- Steps: open every phoneme's detail page and inspect the mouth-shape slot;
  inspect the data record of the phoneme without artwork.
- Exit: each page shows a mouth-shape slot; the phoneme without artwork renders
  the fixed placeholder (never a blank area or another phoneme's image) and its
  data record reserves the image path.

### `TC-DETAIL-003`

- Covers: `REQ-010`
- Preconditions: detail page open for a phoneme with complete example data.
- Steps: inspect the 2×2 example card grid.
- Exit: 4 cards render, each with one image, one word and one sentence, no
  translation text.

### `TC-DETAIL-004`

- Covers: `REQ-011`
- Preconditions: detail page reached by tapping a chart cell (not the row head).
- Steps:
  1. Compare the circle switcher with the tapped phoneme's row members.
  2. Tap circles within the row until both ends.
- Exit: the switcher shows the tapped phoneme's row members (5 circles, the
  last row its actual count) and defaults to the tapped phoneme; each tap
  refreshes all sections with a same-row member; navigation never crosses rows
  and row ends do not wrap.

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
  1. Re-enter the first page and observe the writing grid.
  2. Tap the writing grid after the auto-play.
  3. Inspect the second page.
- Exit: the stroke order auto-plays once on entry; tapping the grid replays the
  stroke order with pronunciation; the second page shows the fixed preparing
  state with playback disabled, independent of tracing.

### `TC-TRACE-003`

- Covers: `REQ-035`
- Preconditions: detail page open; the writing task flow reachable for contrast.
- Steps:
  1. Tap the top-right ✎ control and observe the presentation.
  2. Draw strokes, clear and redraw, then close via done and via close.
- Exit: the ✎ control opens a board that covers the detail page as an overlay
  (no route change); strokes follow the pointer, clear rewrites cleanly, both
  exits return to the detail page; no score or verdict is ever produced — the
  writing task (`REQ-018`) remains the only scored surface.

### `TC-CONTENT-001`

- Covers: `REQ-012`
- Preconditions: repository checked out; app served in development mode.
- Steps:
  1. Locate the correspondence data file and its labelled source.
  2. Change one mapping value in the data file only (no code change).
  3. Reload the app and inspect the affected phoneme.
- Exit: the displayed mapping follows the edited data and the data file carries
  the book-title + ISBN source, rendered on the About page.

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

### `TC-ME-001`

- Covers: `REQ-032`
- Preconditions: app served by the Flutter Web build.
- Steps:
  1. Open the Me tab and inspect the home content.
  2. Open review, settings and about from the home entries.
- Exit: the Me tab home shows the mastery card and the review status strip;
  review, settings and about open as drill-downs from it; no Me sub-page is a
  bottom tab.

### `TC-ME-002`

- Covers: `REQ-033`
- Preconditions: a profile with no prior launch (first-run flag unset) and one
  with a prior launch.
- Steps:
  1. Launch the app with the first-run flag unset; dismiss the hint; relaunch.
  2. Launch the app with a prior launch recorded.
- Exit: the first launch shows the one-time light hint without blocking the
  chart page; after dismissal later launches show no hint.

### `TC-QUIZ-001`

- Covers: `REQ-015`
- Preconditions: chart page open, direct-read mode off.
- Steps:
  1. Tap the right-bottom floating button and observe the page state.
  2. Observe the default selection; tap another row and observe the selection
     moves to it.
  3. Cancel and re-enter; then confirm.
- Exit: the button enters an in-page row-select state with the `请选择` top bar
  and the selected-row count; the first row is selected by default (whole row
  highlighted); exactly one row is selected at a time — tapping another row
  moves the selection (single-row, not per-phoneme); cancel exits the state;
  confirm starts the quiz on the selected row; no standalone range screen
  exists in the app.

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
- Preconditions: a practice session running over a known selected row.
- Steps: answer items and compare the progress bar and the top-right label
  against the selected row.
- Exit: the bar advances per answered item and the top-right batch label shows
  vowel / consonant matching the selected row's coarse group.

### `TC-QUIZ-007`

- Covers: `REQ-021`
- Preconditions: a practice session over selected rows of known size.
- Steps:
  1. Confirm an answer and observe feedback timing.
  2. Complete the session and read the completion rate.
- Exit: feedback appears immediately after confirm; the rate equals
  selected-row phonemes answered ≥ 1 time ÷ selected-row phonemes.

### `TC-QUIZ-008`

- Covers: `REQ-034`
- Preconditions: at least one phoneme in the review queue and the chart page
  reachable.
- Steps:
  1. Start a new practice session from the chart's row-select confirm.
  2. Return and start a review session from the Me tab review entry.
  3. Compare the two session pages.
- Exit: both sessions render the same quiz page (same progress bar and
  top-right label placement, same task shapes); only the item source differs —
  new practice draws from the selected rows, review draws from the due queue.

### `TC-REVIEW-001`

- Covers: `REQ-022`
- Preconditions: app state resettable; PRD review intervals (1/2/4/7/15 days) as reference.
- Steps:
  1. Answer a phoneme wrong; check star and queue.
  2. Open the Me tab, locate the review entry under the mastery card and open
     the review session; also verify the review status strip deep-links there.
  3. Answer correctly on consecutive review days per the intervals.
  4. Answer wrong during a review; observe the interval.
- Exit: star −1 and queue entry on wrong; the entry is reachable from the Me
  tab mastery card and the status strip deep-links to it; interval advances
  1/2/4/7/15 days on consecutive correct answers and resets on a wrong one.

### `TC-REVIEW-002`

- Covers: `REQ-023`
- Preconditions: a phoneme with a non-zero star rating.
- Steps:
  1. Switch notation KK → DJ → IPA on the phoneme.
  2. Open the Me tab statistics and filter by each notation.
- Exit: the star is identical across all three notations; statistics filter per notation with denominator 48.

### `TC-PLATFORM-001`

- Covers: `REQ-024`
- Preconditions: release-mode Flutter Web build served locally.
- Steps: run the chart, detail, practice and review flows of this plan in a browser.
- Exit: all flows complete end-to-end on the Web build without errors.

### `TBD`

- Covers: `REQ-025`
- iOS functional confirmation is verified with the v0.2.x patch; recorded gap
  for this slice.

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
- Exit: no clipping or wrap; all 48 phonemes reachable; option areas ≥ 44 pt.

### `TC-QUAL-003`

- Covers: `REQ-029`
- Preconditions: network available for the initial synthesis, then disabled.
- Steps:
  1. Verify no audio cache files exist on disk after playback.
  2. Disable the network; open chart, correspondence data and word/sentence
     texts; trigger audio playback.
- Exit: data and texts work offline; audio is synthesized on device and plays
  with no cache files on disk; a synthesis failure shows the fixed state
  without blocking practice.

### `TC-QUAL-004`

- Covers: `REQ-030`
- Preconditions: Web build served; screen reader / keyboard available.
- Steps:
  1. Inspect aria-labels / spoken text on symbols.
  2. Tab through every button and check focus visibility.
- Exit: symbols expose labels; all buttons keyboard-operable with visible focus.
