### Added
- Bundled KK/DJ/IPA correspondence table (`assets/content/correspondence.v1.json`, 48 mappings keyed by the catalog phoneme ids) compiled from public correspondence tables with a labelled source
- Content-layer loader `lib/content/correspondence.dart` with tests pinning the external-data contract: editing the data file changes the loaded mapping without a code change
