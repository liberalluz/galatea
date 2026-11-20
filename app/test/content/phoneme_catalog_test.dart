import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalog contains exactly 48 phonemes (24 vowels + 24 consonants)',
    () async {
      final catalog = await loadPhonemeCatalog();

      expect(catalog.entries.length, 48);
      expect(
        catalog.entries.where((e) => e.kind == PhonemeKind.vowel).length,
        24,
      );
      expect(
        catalog.entries.where((e) => e.kind == PhonemeKind.consonant).length,
        24,
      );
    },
  );

  test(
    'every entry has a stable unique id, a category group and a print glyph',
    () async {
      final catalog = await loadPhonemeCatalog();

      final ids = catalog.entries.map((e) => e.id).toSet();
      expect(ids.length, 48, reason: 'phoneme ids must be unique');

      for (final entry in catalog.entries) {
        expect(
          entry.group,
          isNotEmpty,
          reason: 'entry ${entry.id} must carry a category group',
        );
        expect(
          entry.printGlyph,
          isNotEmpty,
          reason: 'entry ${entry.id} must carry a print glyph',
        );
      }
    },
  );

  test('catalog carries the booklet source label with the ISBN', () async {
    final catalog = await loadPhonemeCatalog();

    expect(catalog.sourceLabel, contains('9787119061207'));
    expect(catalog.sourceLabel, isNotEmpty);
  });

  test('the content layer never imports domain or UI types', () async {
    final loaderSource = File('lib/content/phoneme_catalog.dart')
        .readAsStringSync();

    expect(
      loaderSource,
      isNot(contains("package:galatea/domain")),
      reason: 'content layer must not import domain types',
    );
    expect(
      loaderSource,
      isNot(contains("package:galatea/ui")),
      reason: 'content layer must not import UI types',
    );
  });
}
