import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Tall test viewport so the lazy ListView builds every category group.
  /// The catalog and correspondence table are loaded via [tester.runAsync]
  /// (real async IO) and injected, so the grid renders deterministically
  /// inside the fake-async test zone.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    PhonemeCatalog? catalog;
    CorrespondenceTable? correspondence;
    ExamplesData? examples;
    GlyphData? glyphs;
    await tester.runAsync(() async {
      catalog = await loadPhonemeCatalog();
      correspondence = await loadCorrespondence();
      examples = await loadExamples();
      glyphs = await loadGlyphs();
    });

    await tester.pumpWidget(
      GalateaApp(
        catalogFuture: catalog != null ? Future.value(catalog) : null,
        correspondenceFuture: correspondence != null
            ? Future.value(correspondence)
            : null,
        examplesFuture: examples != null ? Future.value(examples) : null,
        glyphsFuture: glyphs != null ? Future.value(glyphs) : null,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // The shell's mastery load degrades to the in-memory store after the
    // 150 ms timeout in a test environment; one more pump rebuilds the
    // body once the future settles.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the shell shows two fixed tabs with chart as the default', (
    tester,
  ) async {
    await pumpApp(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 2, reason: 'REQ-031: exactly two tabs');
    expect(bar.selectedIndex, 0, reason: 'chart is the default tab');
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['音标', '我']);
    expect(find.byKey(const ValueKey('tab-practice')), findsNothing);
  });

  testWidgets(
    'the chart renders two coarse group tables: 24 vowels in five rows ending at four, 24 consonants in five rows ending at four',
    (tester) async {
      await pumpApp(tester);

      // Two coarse groups only (REQ-002, decision 1): one table per
      // coarse kind, rows of 5 across the fine groups.
      final renderTables = tester
          .renderObjectList<RenderTable>(find.byType(Table))
          .toList();
      expect(renderTables.length, 2);

      /// The phoneme ids of one grid row: the padded tail cell is null.
      List<String?> rowPhonemeIds(TableRow row) => [
        for (final cell in row.children)
          cell is Padding && cell.child is InkWell
              ? ((cell.child as InkWell).key! as ValueKey<String>).value
              : null,
      ];

      final vowelTable = tester.widget<Table>(
        find.byKey(const ValueKey('chart-table-vowel')),
      );
      final consonantTable = tester.widget<Table>(
        find.byKey(const ValueKey('chart-table-consonant')),
      );
      expect(vowelTable.children.length, 5, reason: '24 vowels -> 5 rows');
      expect(rowPhonemeIds(vowelTable.children.last), [
        'phoneme-u',
        'phoneme-ʊ',
        'phoneme-ʊr',
        'phoneme-aʊ',
        null,
      ], reason: 'the last vowel row holds its actual count of 4');
      expect(
        consonantTable.children.length,
        5,
        reason: '24 consonants -> 5 rows',
      );
      expect(rowPhonemeIds(consonantTable.children.last), [
        'phoneme-k',
        'phoneme-g',
        'phoneme-ŋ',
        'phoneme-h',
        null,
      ], reason: 'the last consonant row holds its actual count of 4');
      for (final table in [vowelTable, consonantTable]) {
        expect(
          table.children.every((row) => row.children.length == 5),
          isTrue,
          reason: 'the grid is 5 columns wide (the last row pads up)',
        );
      }

      expect(find.text('元音'), findsOneWidget);
      expect(find.text('辅音'), findsOneWidget);
      for (final fine in ['元音·前', '元音·中', '元音·后', '辅音·双唇', '辅音·声门']) {
        expect(
          find.text(fine),
          findsNothing,
          reason: 'fine category labels are never rendered (REQ-002)',
        );
      }

      for (final id in [
        'i',
        'ɪ',
        'e',
        'ɛ',
        'æ',
        'aɪ',
        'ɪr',
        'ɛr',
        'ɪə',
        'iə',
        'ʌ',
        'ə',
        'ɝ',
        'ɚ',
        'ɑ',
        'ɑr',
        'ɔ',
        'ɔr',
        'ɔɪ',
        'o',
        'u',
        'ʊ',
        'ʊr',
        'aʊ',
        'p',
        'b',
        'm',
        'w',
        'f',
        'v',
        'θ',
        'ð',
        't',
        'd',
        's',
        'z',
        'n',
        'l',
        'ʃ',
        'ʒ',
        'tʃ',
        'dʒ',
        'r',
        'j',
        'k',
        'g',
        'ŋ',
        'h',
      ]) {
        expect(
          find.byKey(ValueKey('phoneme-$id')),
          findsOneWidget,
          reason: 'phoneme $id must appear exactly once',
        );
      }
    },
  );

  testWidgets('tapping a symbol opens the detail route for that phoneme', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('phoneme-i')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('detail-page')), findsOneWidget);
    expect(find.text('i'), findsWidgets);
  });

  testWidgets('the chart carries no source footer (REQ-001, decision 7)', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.textContaining('9787119061207'), findsNothing);
    expect(find.textContaining('来源'), findsNothing);
  });
}
