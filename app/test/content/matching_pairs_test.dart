import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/matching_pairs.dart';
import 'package:galatea/content/phoneme_catalog.dart';

/// Synthetic catalog: glyphs are unique per entry, mirroring the bundled
/// catalog where all 48 `kk` values differ.
PhonemeCatalog _catalog(List<String> glyphs) => PhonemeCatalog(
  version: 'test',
  sourceLabel: 'test source',
  entries: [
    for (final glyph in glyphs)
      PhonemeCatalogEntry(
        id: 'p-$glyph',
        kind: PhonemeKind.vowel,
        group: 'front',
        printGlyph: glyph,
        tts: 'sound-$glyph',
      ),
  ],
);

/// Synthetic correspondence: one mapping per catalog entry, id-aligned.
CorrespondenceTable _correspondence(List<(String, String)> djByGlyph) =>
    CorrespondenceTable(
      version: 'test',
      sourceKind: 'test',
      sourceLabel: 'test source',
      sourceRefs: const <String>[],
      mappings: [
        for (final (glyph, dj) in djByGlyph)
          CorrespondenceMapping(id: 'p-$glyph', kk: glyph, dj: dj, ipa: dj),
      ],
    );

void main() {
  test('builds 3 pairs from the entry and the next entries in order', () {
    final catalog = _catalog(['a', 'b', 'c', 'd', 'e']);
    final correspondence = _correspondence([
      ('a', 'A'),
      ('b', 'B'),
      ('c', 'C'),
      ('d', 'D'),
      ('e', 'E'),
    ]);

    final options = buildMatchingOptions(
      catalog.entries[0],
      catalog,
      correspondence,
    );

    expect(options, isNotNull);
    expect(options!.pairs.map((p) => p.entry.id), ['p-a', 'p-b', 'p-c']);
    expect(options.pairs.map((p) => p.dj), ['A', 'B', 'C']);
  });

  test('wraps past the end of the catalog', () {
    final catalog = _catalog(['a', 'b', 'c']);
    final correspondence = _correspondence([
      ('a', 'A'),
      ('b', 'B'),
      ('c', 'C'),
    ]);

    final options = buildMatchingOptions(
      catalog.entries[2],
      catalog,
      correspondence,
    );

    expect(options, isNotNull);
    expect(options!.pairs.map((p) => p.entry.id), ['p-c', 'p-a', 'p-b']);
  });

  test('skips entries whose DJ glyph duplicates an earlier pair', () {
    // b duplicates a's DJ glyph: the pair set cannot offer two items the
    // same symbol, so b is skipped and the next distinct entry fills in.
    final catalog = _catalog(['a', 'b', 'c', 'd', 'e']);
    final correspondence = _correspondence([
      ('a', 'A'),
      ('b', 'A'),
      ('c', 'C'),
      ('d', 'D'),
      ('e', 'E'),
    ]);

    final options = buildMatchingOptions(
      catalog.entries[0],
      catalog,
      correspondence,
    );

    expect(options, isNotNull);
    expect(options!.pairs.map((p) => p.entry.id), ['p-a', 'p-c', 'p-d']);
    expect(options.pairs.map((p) => p.dj), ['A', 'C', 'D']);
  });

  test('shuffles the right column off the left order', () {
    final catalog = _catalog(['a', 'b', 'c']);
    final correspondence = _correspondence([
      ('a', 'A'),
      ('b', 'B'),
      ('c', 'C'),
    ]);

    final options = buildMatchingOptions(
      catalog.entries[0],
      catalog,
      correspondence,
    )!;

    // The DJ glyphs are pairwise distinct, so any rotation guarantees no
    // right item aligns with its own left item by position.
    expect(options.rightOrder, hasLength(3));
    expect(options.rightOrder.toSet(), {'A', 'B', 'C'});
    for (var i = 0; i < 3; i++) {
      expect(options.rightOrder[i], isNot(options.pairs[i].dj));
    }
  });

  test('returns null when the catalog cannot supply 3 distinct DJs', () {
    final catalog = _catalog(['a', 'b']);
    final correspondence = _correspondence([('a', 'A'), ('b', 'B')]);

    final options = buildMatchingOptions(
      catalog.entries[0],
      catalog,
      correspondence,
    );

    expect(options, isNull);
  });

  test('returns null when the correspondence lacks the entry', () {
    final catalog = _catalog(['a', 'b', 'c']);
    final correspondence = _correspondence([
      ('b', 'B'),
      ('c', 'C'),
      ('d', 'D'),
    ]);

    final options = buildMatchingOptions(
      catalog.entries[0],
      catalog,
      correspondence,
    );

    expect(options, isNull);
  });
}
