import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/phoneme_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the correspondence table covers exactly the catalog phoneme ids',
    () async {
      final catalog = await loadPhonemeCatalog();
      final table = await loadCorrespondence();

      expect(table.mappings.length, 48);
      expect(
        table.mappings.map((m) => m.id).toList(),
        catalog.entries.map((e) => e.id).toList(),
        reason: 'mappings must follow the catalog id set and order',
      );
    },
  );

  test('every mapping carries non-empty KK, DJ and IPA glyphs', () async {
    final table = await loadCorrespondence();

    for (final mapping in table.mappings) {
      expect(
        mapping.kk,
        isNotEmpty,
        reason: 'mapping ${mapping.id} must carry a KK glyph',
      );
      expect(
        mapping.dj,
        isNotEmpty,
        reason: 'mapping ${mapping.id} must carry a DJ glyph',
      );
      expect(
        mapping.ipa,
        isNotEmpty,
        reason: 'mapping ${mapping.id} must carry an IPA glyph',
      );
    }
  });

  test('the KK column agrees with the catalog print glyph per id', () async {
    final catalog = await loadPhonemeCatalog();
    final table = await loadCorrespondence();

    final catalogGlyphs = {for (final e in catalog.entries) e.id: e.printGlyph};

    for (final mapping in table.mappings) {
      expect(
        mapping.kk,
        catalogGlyphs[mapping.id],
        reason: 'KK glyphs must not drift between the two data files',
      );
    }
  });

  test('the table carries the split KK-booklet source', () async {
    final table = await loadCorrespondence();

    expect(table.sourceKind, 'booklet-split');
    expect(table.sourceTitle, '赖世雄《美语音标》');
    expect(table.isbn, '9787119061207');
    expect(
      table.sourceRefs,
      isEmpty,
      reason: 'the public-table reference list leaves the data file',
    );
  });

  test('the source label never renders an empty bracket pair', () async {
    final table = await loadCorrespondence();

    expect(table.sourceRefs, isEmpty);
    expect(table.sourceLabel, table.sourceTitle);
    expect(table.sourceLabel, isNot(contains('（）')));
    expect(table.sourceLabel, isNot(contains('(')));
  });

  test('the content layer never imports domain or UI types', () async {
    final loaderSource = File('lib/content/correspondence.dart')
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
