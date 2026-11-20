## Added

- The quiz session item slot now renders the writing task
  (`REQ-018`, `TC-QUIZ-004`, ux-flows R18): the handwritten sample
  above and a blank tracing area below, the ✓/× verdict for a traced
  input, and the empty submit showing the trace-first hint without a
  verdict — an empty submit is never judged ×.
- The verdict is the recorded stroke-overlap threshold (the ED-stage
  leniency R18 allows): sampled user points within 0.09 of the model
  polylines must reach 0.7 coverage for ✓; the judgement is a pure
  function of (model strokes, user strokes) and deterministic.
- The tracing canvas and the handwriting painter moved to the shared
  `lib/ui/writing/` component: the detail handwriting zone delegates to
  it with unchanged behavior (`REQ-009`), so capture and rendering have
  one source.
- The task registry now carries the recognition, listening and writing
  tasks; the matching task registers into the same registry from `B16`
  on without changing the shell.
