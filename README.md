# Galatea

[简体中文](README.zh-CN.md) · English

> Learn the phonetic symbols of American English: KK, with DJ and IPA views,
> pronunciation audio and handwriting practice. Flutter Web first.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Status

**v0.2.0 released.** The interaction revamp is live: two top-level tabs
(phonetics and Me), the chart's row-select practice entry, the shared quiz
page and the handwriting overlay; review, settings and about move into the
Me tab. The GitHub Pages deployment serves this release.

## What it is

- **One chart, three notations.** KK is the default; DJ and IPA are a switch
  away, not separate screens.
- **Every symbol has a sound and a stroke.** Pronunciation audio per symbol,
  and writing practice guided by stroke data.
- **Misses come back.** Items you get wrong re-enter a spaced-repetition review
  queue.

## Project structure

| Directory | Responsibility |
|---|---|
| `app/` | The Flutter application |
| `server/` | Reserved by the scaffold |
| `content/` | Reserved by the scaffold |
| `infra/` | Reserved by the scaffold |
| `docs/` | Specs, decisions, conventions, baselines |

## Documentation

| Looking for | Where |
|---|---|
| Requirements and design specs | [docs/specs/](docs/specs/) |
| Decisions | [docs/decisions/](docs/decisions/) |
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) |

## Contributing

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.
- Changing code with AI? Read [CONTRIBUTING.ai.md](CONTRIBUTING.ai.md) too: AI
  changes need a human reviewer plus tests or evidence, and the author cannot
  self-approve.

## Security

See [SECURITY.md](SECURITY.md).

## License

Licensed under the [Apache License 2.0](LICENSE).
