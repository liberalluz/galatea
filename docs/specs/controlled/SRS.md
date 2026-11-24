# SRS — galatea v0.2.0

[简体中文](SRS.zh-CN.md) · English

## Scope

Source: `galatea-docs/product/definition/prd.md` — requirements `R1`–`R30`, the
countable product rules (PRD §5, B3) and the global experience constraints
(PRD §6, B10); `REQ-031`–`REQ-035` restate the interaction revamp confirmed by
the product owner on 2026-11-21 (PD spec decisions and skeleton, the
`galatea-docs` design set). This SRS restates each requirement as an observable
acceptance criterion; it does not restate the PRD.

- v0.1.0 shipped `REQ-001`–`REQ-024`, `REQ-026`–`REQ-030` in their v0.1 wording.
- The v0.2.0 interaction revamp (product ruling 2026-11-21) restates
  `REQ-001`, `REQ-002`, `REQ-007`, `REQ-010`–`REQ-012`, `REQ-015`,
  `REQ-020`–`REQ-022`, `REQ-029` and adds `REQ-031`–`REQ-035`; every other row
  keeps its v0.1.0 acceptance.
- The one-screen detail page (product ruling 2026-11-23) restates `REQ-010`,
  `REQ-011`, `REQ-013` and `REQ-035` and adds `REQ-036`; every other row keeps
  the wording above. `REQ-036` is an ED-side requirement and takes no PRD R id.
- The split source attribution (design handoff 2026-11-23, A19) restates
  `REQ-001` and `REQ-012`; every other row keeps the wording above.
- `REQ-025` (iOS functional confirmation, PRD R25) is re-scheduled to a v0.2.x
  patch (product ruling 2026-11-21, option B) and is listed only for
  traceability; it is not part of this slice.
- Mastery is counted per phoneme, shared across the KK / DJ / IPA notations
  (PRD C3): the metric denominator is 48 phonemes, never multiplied by 3.

## Requirements

| ID | Requirement | Acceptance | Source |
|---|---|---|---|
| `REQ-001` | The chart covers the reference booklet's KK phoneme set (ISBN 9787119061207), shown in print glyphs | The chart contains exactly 48 phonemes (24 vowels + 24 consonants); the source attribution is split — the KK set is credited to the booklet with its ISBN, DJ and IPA are credited as international standard notation that does not come from the book — and appears only on the About page, so the chart carries no source footer | R1 |
| `REQ-002` | The chart is a 5-column grid with only the vowel / consonant coarse group headers | Only the two coarse headers are visible; fine category labels are not displayed; within a coarse group rows follow the place-of-articulation order, 5 phonemes per row and the last row at its actual count | R2 |
| `REQ-003` | Three notation systems with switching | KK is the default; switching to DJ or IPA keeps the current phoneme selected | R3 |
| `REQ-004` | Chart default state: tap opens the detail page | Tapping a symbol in the default chart state opens its detail page | R4 |
| `REQ-005` | Chart direct-read state, toggled top-right | With the toggle on, tapping a symbol plays its audio without navigating, and the status hint line is visible | R5 |
| `REQ-006` | Detail page pronunciation button | Tapping it plays the phoneme's audio (on-device synthesis) | R6 |
| `REQ-007` | Detail page mouth-shape slot | Every phoneme's detail page has a mouth-shape slot; with licensed artwork missing the slot ships as a fixed placeholder and the data structure reserves the image path | R7 |
| `REQ-008` | Detail page handwritten tracing | The handwriting area accepts tracing of the handwritten glyph | R8 |
| `REQ-009` | Detail page stroke-order animation | The stroke-order animation can be played | R9 |
| `REQ-010` | Detail page 2×2 example cards: one image + one word or one sentence | 4 cards are shown, each with one image and either one word or one sentence as the phoneme-level display form decides; the word and the sentence never render together; no translation text | R10 (2026-11-23) |
| `REQ-011` | Detail page same-row member circles | The switcher shows the tapped phoneme's row members as circles in the top bar (5, the last row at its actual count), spread across the bar width, and defaults to the tapped phoneme; adjacent means same-row member and the row ends do not wrap | R11 (2026-11-23) |
| `REQ-012` | KK/DJ/IPA correspondence data with the split source attribution | The data credits the KK column to the booklet (title + ISBN 9787119061207) and the DJ / IPA columns as international standard notation; the About page renders both notes and the mapping can be updated independently of app code | R12 |
| `REQ-013` | Print and handwritten glyphs per phoneme, handwritten with stroke data | The chart and question stems render print glyphs; tracing and writing tasks use the handwritten glyph with stroke data; every handwritten skeleton is recognisable as its symbol and corresponds to the printed letterform, and the skeleton follows the notation in effect | R13 (2026-11-23) |
| `REQ-014` | Example cards carry images | Every example card shows an image | R14 |
| `REQ-015` | Practice entry: chart floating button + in-page row-select mode | The chart's right-bottom floating button enters a row-select state (default first row selected; tapping another row moves the single-row selection — one row at a time); confirm starts the quiz on the selected row; no standalone range screen exists | R15 |
| `REQ-016` | Recognition task: print stem, 4 spelling options | Exactly 4 options are shown and exactly 1 is correct | R16 |
| `REQ-017` | Listening task: audio stem, 2 symbol options | 2 options are shown; the selected option highlights before confirm | R17 |
| `REQ-018` | Writing task: handwritten model + tracing area + ✓/× verdict | A verdict is produced for the traced input | R18 |
| `REQ-019` | Matching task: pronunciations to symbols in another notation | Pairs connect one by one; a matched pair greys out | R19 |
| `REQ-020` | Progress bar across the session, batch label top-right | The progress bar advances with each item and the top-right batch label (vowel / consonant) matches the selected row's coarse group | R20 |
| `REQ-021` | Immediate feedback; completion rate over the selected rows | Feedback appears at once; completion rate = selected-row phonemes answered ≥ 1 time ÷ selected-row phonemes (PRD product rules) | R21 |
| `REQ-022` | Wrong answers enter spaced-repetition review, entered from the Me tab | A wrong answer lowers the star by 1 and puts the phoneme into the review queue (intervals follow PRD product rules, 1/2/4/7/15 days); the review entry lives in the Me tab under the mastery card and the review status strip deep-links there | R22 |
| `REQ-023` | 0–3 star mastery per phoneme, per-notation statistics | Every phoneme shows a star rating shared across all three notations; statistics are viewable per notation | R23 |
| `REQ-024` | Web is the primary v0.1.0 target (Flutter) | The Web build runs every requirement of this slice | R24 |
| `REQ-025` | iOS functional confirmation (Flutter) — v0.2.x, not in this slice | The iOS build runs the full feature set (verified in a v0.2.x patch) | R25 |
| `REQ-026` | Bilingual delivery per CONTRACT.md | Every controlled document exists in both supported languages (bare name in the repository language, `<stem>.zh-CN.md` translation); documents-repo product docs keep their translation pairs | R26 |
| `REQ-027` | Fallback fonts for IPA-only glyphs | Symbols such as ʃ θ ŋ ɚ render without tofu on Web and iOS | R27 |
| `REQ-028` | Small-screen adaptation | The 5-column grid scrolls horizontally or scales without clipping on narrow screens; tappable practice options are ≥ 44 pt | R28 |
| `REQ-029` | Offline availability of data; audio synthesized on device | Phoneme chart, correspondence data and word/sentence texts work locally offline; audio is synthesized on device in realtime with no cache | R29 |
| `REQ-030` | Accessibility labels and operability | Symbols carry aria-labels / spoken text; buttons operate by keyboard and screen reader | R30 |
| `REQ-031` | Two-tab bottom navigation: chart / Me | The bottom bar shows exactly the chart tab and the Me tab; detail, quiz, review, settings and about are drill-downs and never occupy a tab | PD spec 2026-11-21, decision 2 |
| `REQ-032` | The Me tab hosts four pages: home, review, settings, about | The Me tab home shows the mastery card and the review status strip; review, settings and about open from it as drill-downs | PD spec 2026-11-21, decision 8 + skeleton S2–S4 |
| `REQ-033` | One-time first-run hint | On first launch a light non-blocking hint explains the two non-obvious interactions; dismissing it is permanent, later launches show no hint | PD spec 2026-11-21, skeleton S1 |
| `REQ-034` | Shared quiz page for new and review sessions | A new-practice session (the selected row) and a review session (due queue) render the same quiz page; only the item source differs | PD spec 2026-11-21, decision 9 |
| `REQ-035` | Non-scored handwriting overlay on the detail page | A round handwriting control on the content layer's top-right corner opens a handwriting overlay (covering the detail page, not a route) for free tracing with clear/rewrite; it never produces a score or verdict — scoring stays with the writing task (`REQ-018`); the top bar carries no handwriting control | PD spec 2026-11-21, decision 12 (2026-11-23) |
| `REQ-036` | The detail page is one flat one-screen content flow | The page body is a single centred column limited to 420–480 px with no breakpoint branch and no zone card frames or zone headings; the top bar carries the printed symbol and the same-row member circles; one mapping row between the top bar and the writing area shows the phoneme's spelling fragment next to the printed symbol of the notation currently selected on the chart page; the page repeats no large hero glyph and shows no star row; the pronunciation control is an inline line under the writing card; the 2×2 example grid takes the height the fixed parts leave over and reaches the screen bottom | ED B32 ruling 2026-11-23 |

## Product rules (countable criteria)

The star, review and completion rules fixed in PRD §5 (B3) are the acceptance
basis of `REQ-021`–`REQ-023`: stars start at 0, +1 per correct answer up to 3,
−1 per wrong answer down to 0; review intervals advance 1/2/4/7/15 days on
consecutive correct answers and reset on a wrong one; completion = every
phoneme in the selected row answered ≥ 1 time; mastery = 3 stars. Stars are
shared across the three notations.

## Dependencies and contingencies

Carried over from PRD §7; the fallback path changes the acceptance wording of
the affected requirement, not the requirement itself:

| Input | Primary path | Fallback | Affects |
|---|---|---|---|
| Phoneme set and KK/DJ/IPA correspondence data | Compile from the reference booklet | Build from public KK/DJ/IPA tables, labelled as such | `REQ-001`, `REQ-012` |
| Booklet licence | Confirmed by the product owner | Cite ISBN as the phoneme-set reference only | `REQ-001` label wording |
| Handwritten glyphs and stroke data | Produced by ED | Generic handwritten IPA font + simplified stroke order | `REQ-008`, `REQ-009`, `REQ-013`, `REQ-018` |
| Mouth-shape artwork | Owned / licensed artwork | Fixed placeholder slot delivered; the data structure reserves the image path | `REQ-007` |
| Example card images | Owned / licensed artwork | Fixed placeholder icon delivered per card; the data structure reserves the image field | `REQ-010`, `REQ-014` |
| Audio | On-device realtime synthesis, no cache | Pre-generated audio files shipped with the app | `REQ-006`, `REQ-029` |

## TBD

- Stroke-matching leniency for `REQ-018` — decided at the design stage
  (PRD §9); the acceptance stays "a verdict is produced" until then.
- Source-label wording of `REQ-001`/`REQ-012` if the booklet data cannot be
  licensed (fallback path above).

## Out of scope

Dictionary and lookup, translation, speech scoring, community features, and
the source book's letter rules, liaison, similar-sound discrimination and MP3
demonstrations (PRD §4).
