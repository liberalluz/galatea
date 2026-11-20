import 'correspondence.dart';
import 'phoneme_catalog.dart';

/// One pairing of the matching task (`REQ-019`, `TC-QUIZ-005`): the
/// catalog entry (its pronunciation plays through the audio layer) and
/// the DJ glyph the entry maps to in the correspondence table.
class MatchingPair {
  const MatchingPair({required this.entry, required this.dj});

  final PhonemeCatalogEntry entry;

  /// The entry's DJ glyph (the other-notation symbol to pair with).
  final String dj;
}

/// Pair set for the matching task: exactly 3 pairs in catalog order on
/// the left, plus the fixed shuffled right-column order.
class MatchingOptions {
  const MatchingOptions({required this.pairs, required this.rightOrder});

  /// Exactly 3 pairs; the left column renders them in this order.
  final List<MatchingPair> pairs;

  /// The DJ glyphs in the fixed shuffled right-column order: a rotation
  /// of the pair order, so no right item aligns with its own left item
  /// by position (ux-flows R19 empty state: no pre-connected pairs).
  final List<String> rightOrder;
}

/// Builds the matching pair set (`REQ-019`): the current phoneme plus the
/// next catalog entries with a distinct DJ glyph in catalog order
/// (wrapping past the end) — the deterministic algorithm mirrored from
/// B13/B14. The bundled correspondence table carries duplicate DJ glyphs
/// (ɪə ×3, ə/ɑː/ɔː ×2), so distinct-DJ selection keeps the right column
/// unambiguous: one tapped symbol matches exactly one armed item.
///
/// Returns `null` when the data cannot supply 3 pairs — the task then
/// renders the fixed preparing state (the R16 failure-branch shape).
MatchingOptions? buildMatchingOptions(
  PhonemeCatalogEntry entry,
  PhonemeCatalog catalog,
  CorrespondenceTable correspondence,
) {
  final entries = catalog.entries;
  if (entries.length < 3) return null;

  String? djOf(PhonemeCatalogEntry candidate) {
    for (final mapping in correspondence.mappings) {
      if (mapping.id == candidate.id) return mapping.dj;
    }
    return null;
  }

  final start = entries.indexOf(entry);
  if (start < 0 || djOf(entry) == null) return null;

  final pairs = <MatchingPair>[MatchingPair(entry: entry, dj: djOf(entry)!)];
  final djs = <String>{pairs.first.dj};
  for (var step = 1; pairs.length < 3; step++) {
    final candidate = entries[(start + step) % entries.length];
    final dj = djOf(candidate);
    if (dj == null || !djs.add(dj)) continue;
    pairs.add(MatchingPair(entry: candidate, dj: dj));
  }
  if (pairs.length < 3) return null;

  // The DJ glyphs are pairwise distinct, so rotating the pair order by
  // one guarantees no right item aligns with its own left item.
  final rightOrder = [
    for (var i = 1; i < pairs.length; i++) pairs[i].dj,
    pairs.first.dj,
  ];
  return MatchingOptions(pairs: pairs, rightOrder: rightOrder);
}
