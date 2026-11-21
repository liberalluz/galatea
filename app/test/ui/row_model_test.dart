import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/chart/row_model.dart';

/// Unit pins for the shared row model (`SDD §3.2`, `B26`): the chart
/// grid, the B27 row-select mode and the B28 detail circles must all
/// split the catalog through these functions.
void main() {
  List<PhonemeCatalogEntry> entriesOf(
    String group,
    PhonemeKind kind,
    int count,
    String prefix,
  ) => [
    for (var i = 0; i < count; i++)
      PhonemeCatalogEntry(
        id: '$prefix-$i',
        kind: kind,
        group: group,
        printGlyph: prefix,
      ),
  ];

  test('coarseEntries concatenates the fine groups in place order', () {
    final entries = [
      ...entriesOf('back', PhonemeKind.vowel, 2, 'b'),
      ...entriesOf('front', PhonemeKind.vowel, 3, 'f'),
      ...entriesOf('central', PhonemeKind.vowel, 1, 'c'),
      ...entriesOf('glottal', PhonemeKind.consonant, 1, 'g'),
    ];

    final vowels = coarseEntries(PhonemeKind.vowel, entries);
    expect(
      [for (final e in vowels) e.id],
      ['f-0', 'f-1', 'f-2', 'c-0', 'b-0', 'b-1'],
      reason: 'front -> central -> back, catalog order inside a fine group',
    );

    final consonants = coarseEntries(PhonemeKind.consonant, entries);
    expect([for (final e in consonants) e.id], ['g-0']);
  });

  test('rowsFor splits at 5 with the last row at its actual count', () {
    final entries = entriesOf('front', PhonemeKind.vowel, 12, 'v');
    final rows = rowsFor(entries);
    expect(
      [for (final row in rows) row.length],
      [5, 5, 2],
      reason: 'the last row holds its actual count',
    );
  });

  test('the bundled catalog lands at 5 vowel rows ending 4 and 5 consonant rows ending 4', () {
    // Mirrors the bundled asset counts (48 = 24 vowels = 10+4+10,
    // 24 consonants = 4+2+2+6+5+1+3+1) without reading the asset:
    // synthetic entries with the same group distribution.
    final vowelCounts = {'front': 10, 'central': 4, 'back': 10};
    final consonantCounts = {
      'bilabial': 4,
      'labiodental': 2,
      'dental': 2,
      'alveolar': 6,
      'postalveolar': 5,
      'palatal': 1,
      'velar': 3,
      'glottal': 1,
    };
    final entries = [
      for (final e in vowelCounts.entries)
        ...entriesOf(e.key, PhonemeKind.vowel, e.value, e.key),
      for (final e in consonantCounts.entries)
        ...entriesOf(e.key, PhonemeKind.consonant, e.value, e.key),
    ];

    final vowelRows = rowsForKind(PhonemeKind.vowel, entries);
    expect(vowelRows.length, 5, reason: '24 vowels');
    expect(vowelRows.last.length, 4);
    expect(vowelRows.expand((r) => r).length, 24);

    final consonantRows = rowsForKind(PhonemeKind.consonant, entries);
    expect(consonantRows.length, 5, reason: '24 consonants');
    expect(consonantRows.last.length, 4);
    expect(consonantRows.expand((r) => r).length, 24);
  });
}
