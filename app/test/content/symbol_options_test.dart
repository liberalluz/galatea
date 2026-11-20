import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/content/symbol_options.dart';

/// Synthetic catalogs for the listening task: glyphs are unique per entry,
/// mirroring the bundled catalog where all 48 `kk` values differ.
PhonemeCatalog _catalog({List<String>? glyphs}) {
  final values = glyphs ?? ['a', 'b', 'c', 'd', 'e'];
  return PhonemeCatalog(
    version: 'test',
    sourceLabel: 'test source',
    entries: [
      for (var i = 0; i < values.length; i++)
        PhonemeCatalogEntry(
          id: 'p$i',
          kind: PhonemeKind.vowel,
          group: 'front',
          printGlyph: values[i],
          tts: 'sound-${values[i]}',
        ),
    ],
  );
}

void main() {
  test('the symbol options are the phoneme glyph plus the next distinct catalog glyph, exactly 2 options with 1 correct', () {
    final catalog = _catalog();
    final options = buildSymbolOptions(catalog.entries[0], catalog);

    expect(options, isNotNull);
    expect(options!.options.length, 2);
    expect(options.options.toSet().length, 2);
    expect(options.correct, 'a');
    expect(
      options.options.where((option) => option == options.correct).length,
      1,
    );
    expect(options.options, ['a', 'b']);
  });

  test(
    'the symbol options wrap around the catalog order deterministically',
    () {
      final catalog = _catalog();
      final options = buildSymbolOptions(catalog.entries[3], catalog);

      expect(options, isNotNull);
      expect(options!.options, ['d', 'e']);
    },
  );

  test('the same phoneme yields the same option pair on every visit', () {
    final catalog = _catalog();
    final first = buildSymbolOptions(catalog.entries[1], catalog);
    final second = buildSymbolOptions(catalog.entries[1], catalog);

    expect(first!.options, second!.options);
    expect(first.correct, second.correct);
  });

  test('a catalog with fewer than 2 distinct glyphs yields no options', () {
    final catalog = _catalog(glyphs: ['a']);
    expect(buildSymbolOptions(catalog.entries[0], catalog), isNull);
  });
}
