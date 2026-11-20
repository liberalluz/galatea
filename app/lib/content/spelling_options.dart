import 'phoneme_catalog.dart';

/// Letter-spelling options for the recognition task (`REQ-016`,
/// `TC-QUIZ-002`): the correct spelling plus three deterministic
/// distractors, exactly 4 options with exactly 1 correct.
///
/// The bundled catalog carries 48 unique `tts` spellings, so the
/// exactly-one-correct invariant holds by data. Returns `null` when the
/// catalog cannot supply 4 distinct spellings — the task then renders the
/// fixed preparing state (ux-flows R16 failure branch).
class SpellingOptions {
  const SpellingOptions({required this.correct, required this.options});

  /// The phoneme's own spelling; exactly one option equals it.
  final String correct;

  /// Exactly 4 distinct spellings in deterministic order: the correct one
  /// first, then the next three distinct catalog spellings wrapping past
  /// the end.
  final List<String> options;
}

SpellingOptions? buildSpellingOptions(
  PhonemeCatalogEntry entry,
  PhonemeCatalog catalog,
) {
  final entries = catalog.entries;
  final distinct = entries.map((e) => e.tts).toSet();
  if (distinct.length < 4) return null;

  final options = <String>[entry.tts];
  final start = entries.indexOf(entry);
  for (var step = 1; options.length < 4; step++) {
    final candidate = entries[(start + step) % entries.length].tts;
    if (candidate != entry.tts && !options.contains(candidate)) {
      options.add(candidate);
    }
  }
  return SpellingOptions(correct: entry.tts, options: options);
}
