## Added

- The practice tab's new-practice mode hosts the range selection screen:
  a category tag row (`all` plus the 11 category tags sharing the chart
  page's Chinese group titles) filters the phoneme set, and the 5-column
  grid multi-selects and deselects phonemes, with the selection kept
  across tag switches (`REQ-015`, `TC-QUIZ-001`).
- The confirm control is gated: it stays disabled with the fixed
  "请先选择音位" hint while nothing is selected, and shows the
  selection count once at least one phoneme is selected; the confirmed
  range is consumed by the quiz session shell in `B12`.
- A filter with no matching phonemes shows the fixed "该类别暂无音位"
  empty state with a clear-filter control (ux-flows empty branch).
