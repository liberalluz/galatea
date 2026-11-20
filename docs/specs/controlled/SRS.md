# SRS — galatea v0.1.0

[简体中文](SRS.zh-CN.md) · English

## Scope

Source: `galatea-docs/product/definition/prd.md` — requirements `R1`–`R30`, the
countable product rules (PRD §5, B3) and the global experience constraints
(PRD §6, B10). This SRS restates each requirement as an observable acceptance
criterion; it does not restate the PRD.

- P1 slice = v0.1.0: `REQ-001`–`REQ-024`, `REQ-026`–`REQ-030`.
- `REQ-025` (iOS functional confirmation, PRD R25) is scheduled for v0.2.0 and
  is listed only for traceability; it is not part of this slice.
- Mastery is counted per phoneme, shared across the KK / DJ / IPA notations
  (PRD C3): the metric denominator is 48 phonemes, never multiplied by 3.

## Requirements

| ID | Requirement | Acceptance | PRD |
|---|---|---|---|
| `REQ-001` | The chart covers the phoneme set of the reference booklet (ISBN 9787119061207), shown in print glyphs | The chart contains exactly 48 phonemes (24 vowels + 24 consonants) and carries a source label | R1 |
| `REQ-002` | The chart is a 5-column grid grouped by phonetic category | 5 columns are visible; vowel groups (front/central/back) and consonant groups (by place) are distinguishable | R2 |
| `REQ-003` | Three notation systems with switching | KK is the default; switching to DJ or IPA keeps the current phoneme selected | R3 |
| `REQ-004` | Chart default state: tap opens the detail page | Tapping a symbol in the default chart state opens its detail page | R4 |
| `REQ-005` | Chart direct-read state, toggled top-right | With the toggle on, tapping a symbol plays its audio without navigating, and the status hint line is visible | R5 |
| `REQ-006` | Detail page pronunciation button | Tapping it plays the phoneme's audio (TTS in v0.1.0) | R6 |
| `REQ-007` | Detail page mouth-shape diagram | Every phoneme's detail page shows a mouth-shape image | R7 |
| `REQ-008` | Detail page handwritten tracing | The handwriting area accepts tracing of the handwritten glyph | R8 |
| `REQ-009` | Detail page stroke-order animation | The stroke-order animation can be played | R9 |
| `REQ-010` | Detail page 2×2 example cards: image + word/sentence | 4 cards are shown, each with an image and a word/sentence and no translation text | R10 |
| `REQ-011` | Detail page horizontal phoneme switcher | The previous/next phoneme can be reached from the bar | R11 |
| `REQ-012` | KK/DJ/IPA correspondence data with one labelled source | The data source is labelled and the data can be updated independently of app code | R12 |
| `REQ-013` | Print and handwritten glyphs per phoneme, handwritten with stroke data | The chart and question stems render print glyphs; tracing and writing tasks use the handwritten glyph with stroke data | R13 |
| `REQ-014` | Example cards carry images | Every example card shows an image | R14 |
| `REQ-015` | Practice range selection: category tags + 5-column multi-select + confirm | Phonemes can be filtered by tag and multi-selected on the grid, then confirmed | R15 |
| `REQ-016` | Recognition task: print stem, 4 spelling options | Exactly 4 options are shown and exactly 1 is correct | R16 |
| `REQ-017` | Listening task: audio stem, 2 symbol options | 2 options are shown; the selected option highlights before confirm | R17 |
| `REQ-018` | Writing task: handwritten model + tracing area + ✓/× verdict | A verdict is produced for the traced input | R18 |
| `REQ-019` | Matching task: pronunciations to symbols in another notation | Pairs connect one by one; a matched pair greys out | R19 |
| `REQ-020` | Progress bar across the session, range label top-right | The progress bar advances with each item and the range label is visible | R20 |
| `REQ-021` | Immediate feedback; completion rate over the selected range | Feedback appears at once; completion rate = phonemes in range answered ≥ 1 time ÷ phonemes in range (PRD product rules) | R21 |
| `REQ-022` | Wrong answers enter spaced-repetition review | A wrong answer lowers the star by 1 and puts the phoneme into the review queue; intervals follow PRD product rules (1/2/4/7/15 days) | R22 |
| `REQ-023` | 0–3 star mastery per phoneme, per-notation statistics | Every phoneme shows a star rating shared across all three notations; statistics are viewable per notation | R23 |
| `REQ-024` | Web is the primary v0.1.0 target (Flutter) | The Web build runs every requirement of this slice | R24 |
| `REQ-025` | iOS functional confirmation (Flutter) — v0.2.0, not in this slice | The iOS build runs the full feature set (verified in v0.2.0) | R25 |
| `REQ-026` | Bilingual delivery per CONTRACT.md | Every controlled document exists in both supported languages (bare name in the repository language, `<stem>.zh-CN.md` translation); documents-repo product docs keep their translation pairs | R26 |
| `REQ-027` | Fallback fonts for IPA-only glyphs | Symbols such as ʃ θ ŋ ɚ render without tofu on Web and iOS | R27 |
| `REQ-028` | Small-screen adaptation | The 5-column grid scrolls horizontally or scales without clipping on narrow screens; tappable practice options are ≥ 44 pt | R28 |
| `REQ-029` | Offline availability of data; audio caching | Phoneme chart, correspondence data and word/sentence texts work locally offline; audio is cached after first generation | R29 |
| `REQ-030` | Accessibility labels and operability | Symbols carry aria-labels / spoken text; buttons operate by keyboard and screen reader | R30 |

## Product rules (countable criteria)

The star, review and completion rules fixed in PRD §5 (B3) are the acceptance
basis of `REQ-021`–`REQ-023`: stars start at 0, +1 per correct answer up to 3,
−1 per wrong answer down to 0; review intervals advance 1/2/4/7/15 days on
consecutive correct answers and reset on a wrong one; completion = every
phoneme in the selected range answered ≥ 1 time; mastery = 3 stars. Stars are
shared across the three notations.

## Dependencies and contingencies

Carried over from PRD §7; the fallback path changes the acceptance wording of
the affected requirement, not the requirement itself:

| Input | Primary path | Fallback | Affects |
|---|---|---|---|
| Phoneme set and KK/DJ/IPA correspondence data | Compile from the reference booklet | Build from public KK/DJ/IPA tables, labelled as such | `REQ-001`, `REQ-012` |
| Booklet licence | Confirmed by the product owner | Cite ISBN as the phoneme-set reference only | `REQ-001` label wording |
| Handwritten glyphs and stroke data | Produced by ED | Generic handwritten IPA font + simplified stroke order | `REQ-008`, `REQ-009`, `REQ-013`, `REQ-018` |
| Example card images | Licensed / owned artwork | Royalty-free stock placeholders, replaced later | `REQ-014` |
| Audio | TTS with caching | Pre-generated audio files shipped with the app | `REQ-006`, `REQ-029` |

## TBD

- Stroke-matching leniency for `REQ-018` — decided at the design stage
  (PRD §9); the acceptance stays "a verdict is produced" until then.
- Source-label wording of `REQ-001`/`REQ-012` if the booklet data cannot be
  licensed (fallback path above).

## Out of scope

Dictionary and lookup, translation, speech scoring, community features, and
the source book's letter rules, liaison, similar-sound discrimination and MP3
demonstrations (PRD §4).
