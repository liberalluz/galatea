# B30 — Web end-to-end re-run and Pages redeploy

## Verified

- The v0.2.0 flows complete end-to-end on the release Web build in a
  browser session (`TC-PLATFORM-001`): the chart flow with the
  notation switch re-rendering the grid, the detail flow with the
  same-row circles, the wireframe zone order and the handwriting
  overlay, the practice flow with the single-row select and the
  confirm feedback, and the review chain with the due strip, the queue
  page and the review-source hand-off.
- The four browser-level quality evidences were re-captured in the
  same session: IPA-only symbols render without tofu (`TC-QUAL-001`),
  a 360 px viewport keeps the 5-column grid intact with practice
  options above the 44 pt floor (`TC-QUAL-002`), data and texts keep
  working with the network disabled after first load and the audio
  behaviour stays a fixed non-blocking state (`TC-QUAL-003`), and
  semantic labels surface in the accessibility tree with Tab traversal
  and Enter activation operating the chart (`TC-QUAL-004`).
- The Pages site is redeployed to the v0.2.0 build (orphan `gh-pages`
  branch, `--base-href /galatea/`), pending the product owner's
  explicit go for the external push.
