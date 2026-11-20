---
id: P-0005
step: pr
symptom: a bare `#N` inside a bullet list item unfurls into "title + state" and blows up the sentence
cause: GitHub autolinks bare `#N`; references inside a list unfurl to show title and state, while references in prose render as a short `#N` link
fix: in list items, reference another PR/issue with an explicit markdown link `[#N](<url>)`; in prose paragraphs a bare `#N` is fine; backticks only when no link is wanted at all
verify: the reference renders as a short clickable link and the sentence keeps its shape on the PR page
severity: warning
source: B2
---

# Bare `#N` unfurls to the full title inside a list

GitHub converts a bare `#N` into a cross-reference link. Where the reference
sits decides its shape: in a prose paragraph it stays a short `#N` link; inside
a bullet/numbered list item it unfurls into `full PR title #N`, which breaks
the sentence. Keep bare `#N` in prose, and use an explicit markdown link
`[#N](<url>)` when the reference has to live in a list item — just the number,
no "PR" prefix in the link text. Backticks
suppress the link entirely and render a dead code chip.
