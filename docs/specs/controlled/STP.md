# STP — galatea v0.1.0

[简体中文](STP.zh-CN.md) · English

## Scope

Verification of `docs/specs/controlled/SRS.md` (`REQ-001`–`REQ-030`) against the
design in `docs/specs/controlled/SDD.md`. Platform under test is the Flutter
Web build (`REQ-024`); `REQ-025` (iOS) is v0.2.0 and is recorded as TBD.

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
| `TC-CHART-001` | `REQ-001` | Chart data contains exactly 48 phoneme entries and the chart page shows the source label. |
| `TC-CHART-002` | `REQ-002` | Grid renders 5 columns; each of the 48 phonemes appears once inside its category group. |
| `TC-CHART-003` | `REQ-003` | First launch shows KK as default; switching to DJ and IPA re-renders the symbols while the current phoneme stays selected. |
| `TC-CHART-004` | `REQ-004` | With reading mode off, tapping a symbol navigates to its detail page. |
| `TC-CHART-005` | `REQ-005` | With reading mode on, tapping a symbol plays its audio, stays on the chart, and the status hint line is visible. |
| `TC-DETAIL-001` | `REQ-006` | Tapping the pronunciation button starts playback of the phoneme's audio; a failed playback offers the fixed retry state. |
| `TC-DETAIL-002` | `REQ-007` | Every phoneme's detail page shows a mouth-shape image; while an asset is missing the slot shows the fixed preparing placeholder, never a blank area. |
| `TC-DETAIL-003` | `REQ-010` | The detail page shows 4 example cards, each with an image and a word/sentence and no translation text. |
| `TC-DETAIL-004` | `REQ-011` | The top bar reaches the previous and next phoneme and refreshes all sections; at either end the bar does not wrap. |
| `TC-TRACE-001` | `REQ-008` | The tracing area accepts pointer strokes rendered over the handwritten glyph; strokes drawn so far are kept when input is interrupted. |
| `TC-TRACE-002` | `REQ-009` | The stroke-order control plays the animation; phonemes without stroke data show the fixed preparing state with the control disabled, independent of the tracing area. |
| `TC-CONTENT-001` | `REQ-012` | The correspondence data lives outside app code (editing the data file changes the displayed mapping without a code change) and carries a labelled source. |
| `TC-CONTENT-002` | `REQ-013` | Chart and question stems render print glyphs; tracing and writing tasks use the handwritten glyph with stroke data. |
| `TC-CONTENT-003` | `REQ-014` | Every example card image loads; a missing image renders the fixed image placeholder, not an empty card. |
| `TC-QUIZ-001` | `REQ-015` | Category tags filter the phoneme set; the 5-column grid multi-selects and unselects; confirm stays disabled until at least one phoneme is selected. |
| `TC-QUIZ-002` | `REQ-016` | A recognition task shows a print-glyph stem and exactly 4 spelling options of which exactly 1 is correct. |
| `TC-QUIZ-003` | `REQ-017` | A listening task plays the audio stem and shows exactly 2 symbol options; the selected option highlights before confirm. |
| `TC-QUIZ-004` | `REQ-018` | A writing task shows the handwritten model and tracing area and produces a ✓/× verdict for any traced input (leniency per the stroke-overlap threshold decided in the design review). |
| `TC-QUIZ-005` | `REQ-019` | A matching task connects one pronunciation to one symbol at a time; each matched pair greys out and cannot be re-paired. |
| `TC-QUIZ-006` | `REQ-020` | The progress bar advances with each answered item and the range label in the top-right matches the selected range. |
| `TC-QUIZ-007` | `REQ-021` | Feedback appears immediately after confirm; the reported completion rate equals in-range phonemes answered ≥ 1 time ÷ in-range phonemes. |
| `TC-REVIEW-001` | `REQ-022` | A wrong answer lowers the star by 1 and places the phoneme in the review queue at the interval given by the PRD product rules; a correct review answer advances the interval, a wrong one resets it. |
| `TC-REVIEW-002` | `REQ-023` | Every phoneme carries a 0–3 star rating that is identical across KK/DJ/IPA; the Me tab statistics filter by notation with denominator 48. |
| `TC-PLATFORM-001` | `REQ-024` | The Flutter Web build serves and runs the chart, detail, practice and review flows of this plan end-to-end in a browser. |
| `TBD` | `REQ-025` | iOS functional confirmation is verified with the v0.2.0 build; recorded gap for this slice. |
| `TC-DOC-001` | `REQ-026` | Every controlled document exists as bare source plus `.zh-CN.md` translation with identical ids, and `check_language.py --root .` reports 0 errors. |
| `TC-QUAL-001` | `REQ-027` | ʃ θ ŋ ɚ (and the remaining IPA-only symbols) render with the fallback font chain without tofu on the Web build (browser screenshot evidence). |
| `TC-QUAL-002` | `REQ-028` | On a narrow viewport (≤ 360 px) the 5-column grid scrolls or scales without clipping or column wrap; tappable practice options measure ≥ 44 pt. |
| `TC-QUAL-003` | `REQ-029` | With the network disabled after a first audio generation, the chart, correspondence data and word/sentence texts still work and already-generated audio plays from cache. |
| `TC-QUAL-004` | `REQ-030` | Symbols expose aria-labels / spoken text; every button is operable by keyboard with visible focus. |
