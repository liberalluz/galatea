## Added

- The quiz session item slot now renders the listening task
  (`REQ-017`, `TC-QUIZ-003`): the audio stem with exactly 2 symbol
  options, exactly 1 correct; the selected option highlights before
  confirm, and submitting shows the immediate verdict feedback through
  the session shell.
- The options come from the catalog's existing `kk` symbols: the
  phoneme's own symbol plus one deterministic distractor in catalog
  order (wrapping), so the same phoneme yields the same option pair on
  every visit and the exactly-one-correct invariant holds by data (all
  48 symbols are unique).
- The stem drives the `B7` audio layer (ADR-0002): the session hands its
  audio service to the task, and the play control plays the current
  phoneme with the same call shape the detail page uses.
- Playback failure follows the ux-flows R17 ladder: the first failure
  offers replay, a repeated failure offers the fixed "题目准备中" state
  with a skip control; a skipped item advances without entering the
  completion rate.
- The task registry now carries the recognition and listening tasks;
  the writing and matching tasks register into the same registry from
  `B15` on without changing the shell.
