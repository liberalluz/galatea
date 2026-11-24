# STP — galatea v0.2.0

[简体中文](STP.zh-CN.md) · English

## Scope

Verification of `docs/specs/controlled/SRS.md` (`REQ-001`–`REQ-036`) against the
design in `docs/specs/controlled/SDD.md`. Platform under test is the Flutter
Web build (`REQ-024`); `REQ-025` (iOS) is a v0.2.x patch and is recorded as
TBD.

Toolset:

- `flutter test` for widget and unit level cases;
- browser checks (DevTools evidence) for the quality constraints
  (`REQ-027`–`REQ-030`) and platform behaviour;
- `check_language.py` and `check_verification.py` for `REQ-026` and mapping
  integrity.

Pass/fail follows the observable exits below; "works" is never an exit.

## Test plan

| Test | Covers | Exit |
|---|---|---|
| `TC-CHART-001` | `REQ-001` | Chart data contains exactly 48 phoneme entries; the chart shows no source label and the About page renders the split source notes in its source group's `KK` and `DJ / IPA` rows — the KK booklet with its ISBN 9787119061207, DJ / IPA as international standard notation not from the book — laid out as three groups over a fixed 62px label column with the notation name in the label. |
| `TC-CHART-002` | `REQ-002` | Grid renders 5 columns; only the two coarse group headers are visible; rows follow the place-of-articulation order at 5 per row with the last row at its actual count, and each of the 48 phonemes appears once. |
| `TC-CHART-003` | `REQ-003` | First launch shows KK as default; switching to DJ and IPA re-renders the symbols while the current phoneme stays selected; opening a phoneme afterwards shows the selected notation's symbol in the mapping row, the top bar and the pronunciation line. |
| `TC-CHART-004` | `REQ-004` | With reading mode off, tapping a symbol navigates to its detail page. |
| `TC-CHART-005` | `REQ-005` | With reading mode on, tapping a symbol plays its audio, stays on the chart, and the status hint line is visible. |
| `TC-NAV-001` | `REQ-031` | The bottom bar shows exactly the chart and Me tabs; no drill-down (detail, quiz, review, settings, about) adds a tab; back restores the previous page. |
| `TC-DETAIL-001` | `REQ-006` | The pronunciation control renders as one inline line carrying the printed symbol and the speaker button right under the writing card; tapping it starts playback of the phoneme's audio; a failed playback offers the fixed retry state. |
| `TC-DETAIL-002` | `REQ-007` | Every phoneme's detail page has a mouth-shape slot rendering as a small card beside the larger writing card; a phoneme without artwork renders the fixed placeholder (never blank or another phoneme's image) and its data record reserves the image path. |
| `TC-DETAIL-003` | `REQ-010` | The detail page shows 4 example cards, each with one image and either one word or one sentence as the phoneme-level display form decides; the word and the sentence never render together; no translation text. |
| `TC-DETAIL-004` | `REQ-011` | The top bar shows the tapped phoneme's row members as circles spread across the bar width (5, last row its actual count), defaults to the tapped phoneme, navigates only within the row and does not wrap at row ends; the page body carries no second circle switcher. |
| `TC-DETAIL-005` | `REQ-036` | The detail page renders as a single centred column limited to 420–480 px on a wide window with no breakpoint branch and no zone card frames or section headings; one mapping row shows the spelling fragment next to the printed symbol of the notation selected on the chart page; the page repeats no large hero glyph and shows no star row; the pronunciation control is an inline line under the writing card; the 2×2 example grid takes the height the fixed parts leave over and reaches the screen bottom. |
| `TC-TRACE-001` | `REQ-008` | The tracing area accepts pointer strokes rendered over the handwritten glyph; strokes drawn so far are kept when input is interrupted; the handwritten model is drawn with an equal-ratio mapping centred in the writing card, so the letterform keeps its proportions in a wide card instead of stretching horizontally and the margins stay blank. |
| `TC-TRACE-002` | `REQ-009` | The stroke order auto-plays once on entry; tapping the writing grid replays it with pronunciation; phonemes without stroke data show the fixed preparing state with playback disabled. |
| `TC-TRACE-003` | `REQ-035` | The round handwriting control on the content layer's top-right corner opens a free-tracing board as an overlay covering the detail page (no route change) and the top bar carries no handwriting control; clear rewrites; done/close returns; no score or verdict is produced. |
| `TC-CONTENT-001` | `REQ-012` | The correspondence data lives outside app code (editing the data file changes the displayed mapping without a code change) and carries the split attribution — the KK booklet title + ISBN and no public-table reference list — rendered verbatim as the `KK` and `DJ / IPA` rows of the About page's source group, with no public-table label or contingency sentence anywhere in the app. |
| `TC-CONTENT-002` | `REQ-013` | Chart and question stems render print glyphs; tracing and writing tasks use the handwritten glyph with stroke data; every handwritten skeleton is recognisable as its symbol and corresponds to the printed letterform, and the skeleton follows the selected notation — the phonemes whose three notations share one letterform share one skeleton, the pure long vowels take the extra long-vowel stroke, and the phonemes whose letterform itself differs switch skeleton with the notation. |
| `TC-CONTENT-003` | `REQ-014` | Every example card image loads; a missing image renders the fixed image placeholder, not an empty card. |
| `TC-ME-001` | `REQ-032` | The Me tab home shows the mastery card and the review status strip; review, settings and about open from it as drill-downs; no Me sub-page is a bottom tab. |
| `TC-ME-002` | `REQ-033` | The first launch shows the one-time light hint without blocking the page; after dismissal later launches show no hint. |
| `TC-QUIZ-001` | `REQ-015` | The chart's floating button enters an in-page row-select state (default first row selected, single-row selection — tapping another row moves it, cancel exits); confirm starts the quiz on the selected row; no standalone range screen exists. |
| `TC-QUIZ-002` | `REQ-016` | A recognition task shows a print-glyph stem and exactly 4 spelling options of which exactly 1 is correct. |
| `TC-QUIZ-003` | `REQ-017` | A listening task plays the audio stem and shows exactly 2 symbol options; the selected option highlights before confirm. |
| `TC-QUIZ-004` | `REQ-018` | A writing task shows the handwritten model and tracing area and produces a ✓/× verdict for any traced input (leniency per the stroke-overlap threshold decided in the design review). |
| `TC-QUIZ-005` | `REQ-019` | A matching task connects one pronunciation to one symbol at a time; each matched pair greys out and cannot be re-paired. |
| `TC-QUIZ-006` | `REQ-020` | The progress bar advances with each answered item and the top-right batch label shows vowel / consonant matching the selected rows' coarse group. |
| `TC-QUIZ-007` | `REQ-021` | Feedback appears immediately after confirm; the reported completion rate equals selected-row phonemes answered ≥ 1 time ÷ selected-row phonemes. |
| `TC-QUIZ-008` | `REQ-034` | A new-practice session (selected rows) and a review session (due queue) render the same quiz page; only the item source differs. |
| `TC-REVIEW-001` | `REQ-022` | A wrong answer lowers the star by 1 and places the phoneme in the review queue per the PRD product rules; the entry is reachable from the Me tab mastery card and the status strip deep-links to it; intervals advance 1/2/4/7/15 days on consecutive correct answers and reset on a wrong one. |
| `TC-REVIEW-002` | `REQ-023` | Every phoneme carries a 0–3 star rating that is identical across KK/DJ/IPA; the Me tab statistics filter by notation with denominator 48. |
| `TC-PLATFORM-001` | `REQ-024` | The Flutter Web build serves and runs the chart, detail, practice and review flows of this plan end-to-end in a browser. |
| `TBD` | `REQ-025` | iOS functional confirmation is verified with the v0.2.x patch; recorded gap for this slice. |
| `TC-DOC-001` | `REQ-026` | Every controlled document exists as bare source plus `.zh-CN.md` translation with identical ids, and `check_language.py --root .` reports 0 errors. |
| `TC-QUAL-001` | `REQ-027` | ʃ θ ŋ ɚ (and the remaining IPA-only symbols) render with the fallback font chain without tofu on the Web build (browser screenshot evidence). |
| `TC-QUAL-002` | `REQ-028` | On a narrow viewport (≤ 360 px) the 5-column grid scrolls or scales without clipping or column wrap; tappable practice options measure ≥ 44 pt. |
| `TC-QUAL-003` | `REQ-029` | After playback with the network then disabled, data and texts work offline and audio is synthesized on device with no cache files on disk; synthesis failure shows the fixed state without blocking practice. |
| `TC-QUAL-004` | `REQ-030` | Symbols expose aria-labels / spoken text; every button is operable by keyboard with visible focus. |
