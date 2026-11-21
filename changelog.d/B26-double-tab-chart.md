# Added

- The bottom bar shows exactly two tabs — 音标 / 我 (`REQ-031`); the
  practice tab is removed and quiz, review, settings and about become
  drill-downs (the practice entry returns with B27 as the chart's
  row-select flow).

# Changed

- The chart renders only the 元音 / 辅音 coarse group headers
  (`REQ-002`): the fine place-of-articulation labels are data-only, and
  the shared row model (`row_model.dart`) splits each coarse group into
  rows of 5 — 24 vowels in five rows ending at 4, 24 consonants in five
  rows ending at 4, 48 phonemes in total.
- The direct-read hint strip is permanently part of the chart scaffold,
  grey-on-grey, visible only while the toggle is on, and its tap
  switches to the Me tab (`REQ-005`, `REQ-022` landing).
- The chart carries no source footer (`REQ-001`, decision 7): the book
  title + ISBN attribution moves to the About page with B29.
