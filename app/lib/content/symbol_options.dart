import 'phoneme_catalog.dart';

/// Symbol options for the listening task (`REQ-017`, `TC-QUIZ-003`): the
/// correct symbol plus one deterministic distractor, exactly 2 options with
/// exactly 1 correct.
///
/// The bundled catalog carries 48 unique `kk` glyphs, so the
/// exactly-one-correct invariant holds by data. Returns `null` when the
/// catalog cannot supply 2 distinct glyphs — the task then renders the
/// fixed preparing state (the R17/R16 failure-branch shape).
class SymbolOptions {
  const SymbolOptions({required this.correct, required this.options});

  /// The phoneme's own symbol; exactly one option equals it.
  final String correct;

  /// Exactly 2 distinct symbols in deterministic order: the correct one
  /// first, then the next distinct catalog symbol wrapping past the end.
  final List<String> options;
}

SymbolOptions? buildSymbolOptions(
  PhonemeCatalogEntry entry,
  PhonemeCatalog catalog,
) {
  final entries = catalog.entries;
  final distinct = entries.map((e) => e.printGlyph).toSet();
  if (distinct.length < 2) return null;

  final options = <String>[entry.printGlyph];
  final start = entries.indexOf(entry);
  for (var step = 1; options.length < 2; step++) {
    final candidate = entries[(start + step) % entries.length].printGlyph;
    if (candidate != entry.printGlyph && !options.contains(candidate)) {
      options.add(candidate);
    }
  }
  return SymbolOptions(correct: entry.printGlyph, options: options);
}
