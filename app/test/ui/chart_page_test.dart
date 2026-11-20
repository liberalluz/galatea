import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Tall test viewport so the lazy ListView builds every category group.
  /// The catalog is loaded via [tester.runAsync] (real async IO) and injected,
  /// so the grid renders deterministically inside the fake-async test zone.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    PhonemeCatalog? catalog;
    await tester.runAsync(() async {
      catalog = await loadPhonemeCatalog();
    });

    await tester.pumpWidget(
      GalateaApp(catalogFuture: catalog != null ? Future.value(catalog) : null),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('the shell shows three fixed tabs with chart as the default', (
    tester,
  ) async {
    await pumpApp(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 3);
    expect(bar.selectedIndex, 0, reason: 'chart is the default tab');
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['音标', '练习', '我']);
  });

  testWidgets(
    'the chart grid renders 5 columns grouped by category, 48 phonemes once each',
    (tester) async {
      await pumpApp(tester);

      // Each category group renders its own table, so no row crosses a group
      // boundary (3 vowel groups + 8 consonant place groups).
      final renderTables = tester
          .renderObjectList<RenderTable>(find.byType(Table))
          .toList();
      expect(renderTables.length, 11);

      for (final table in renderTables) {
        expect(table.columns, 5, reason: 'the grid is 5 columns wide');
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

  testWidgets('the chart page shows the labelled data source line', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.textContaining('9787119061207'), findsOneWidget);
  });
}
