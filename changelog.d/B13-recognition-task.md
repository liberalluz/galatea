## Added

- The quiz session item slot now renders the recognition task
  (`REQ-016`, `TC-QUIZ-002`): the print-glyph stem with exactly 4
  letter-spelling options, exactly 1 correct; selecting one and
  submitting shows the immediate verdict feedback through the session
  shell.
- The options come from the catalog's existing letter spellings: the
  phoneme's own spelling plus three deterministic distractors in
  catalog order (wrapping), so the same phoneme yields the same option
  set on every visit and the exactly-one-correct invariant holds by
  data (all 48 spellings are unique).
- The item slot is a task registry: this batch registers the
  recognition task only; the listening, writing and matching tasks
  register into the same registry from `B14` on without changing the
  shell.
- A phoneme with fewer than 4 distinct spellings renders the fixed
  "题目准备中" state with a skip control instead of an under-filled
  option row (ux-flows R16 failure branch); a skipped item advances
  without entering the completion rate.
