## Added

- Confirming the practice range selection now enters the quiz session
  shell: the session view with the top bar and the task area replaces
  the range selection grid (`REQ-020`, `REQ-021`).
- The top bar shows the progress bar, the completion rate beside it
  (visible from 0% onward) and the range label top-right showing the
  selected phoneme count, matching the progress denominator
  (`TC-QUIZ-006`, `TC-QUIZ-007`).
- The progress advances per answered item and reaches 100% when every
  phoneme in the range has been answered at least once, regardless of
  verdicts (PRD 完成判定); feedback appears immediately after each
  answer.
- A zero denominator hides the progress bar and shows the fixed
  "范围暂不可用" hint instead of 0/0 (ux-flows failure branch).
- The item slot ships as a fixed-verdict placeholder task driving the
  session state machine; the four real task types replace it from
  `B13` on.
