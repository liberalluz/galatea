import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';
import 'package:galatea/ui/practice/practice_page.dart';

/// Synthetic catalog: 7 front vowels (two grid rows) and 3 bilabial
/// consonants, enough to pin the 5-column layout, the tag filter and the
/// selection state machine without touching the bundled assets.
PhonemeCatalog _catalog() => PhonemeCatalog(
  version: 'test',
  sourceLabel: 'test source',
  entries: [
    for (var i = 1; i <= 7; i++)
      PhonemeCatalogEntry(
        id: 'a$i',
        kind: PhonemeKind.vowel,
        group: 'front',
        printGlyph: 'a$i',
      ),
    for (var i = 1; i <= 3; i++)
      PhonemeCatalogEntry(
        id: 'b$i',
        kind: PhonemeKind.consonant,
        group: 'bilabial',
        printGlyph: 'b$i',
      ),
  ],
);

Future<void> pumpPractice(
  WidgetTester tester, {
  PhonemeCatalog? catalog,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PracticePage(catalogFuture: Future.value(catalog ?? _catalog())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets(
    'the range selection screen shows the tag row and the 5-column grid with every phoneme under the default all tag',
    (tester) async {
      await pumpPractice(tester);

      expect(find.byKey(const ValueKey('range-tags')), findsOneWidget);
      expect(find.byKey(const ValueKey('range-tag-all')), findsOneWidget);
      for (final id in ['a1', 'a5', 'a7', 'b1', 'b3']) {
        expect(find.byKey(ValueKey('range-cell-$id')), findsOneWidget);
      }

      // 5 columns: a1..a5 share the first row, a6 wraps to the next one.
      final a1 = tester.getRect(find.byKey(const ValueKey('range-cell-a1')));
      final a5 = tester.getRect(find.byKey(const ValueKey('range-cell-a5')));
      final a6 = tester.getRect(find.byKey(const ValueKey('range-cell-a6')));
      expect(a1.top, a5.top);
      expect(a1.top, isNot(a6.top));
    },
  );

  testWidgets('tapping a category tag filters the grid to that group', (
    tester,
  ) async {
    await pumpPractice(tester);

    await tester.tap(find.byKey(const ValueKey('range-tag-bilabial')));
    await tester.pump();

    expect(find.byKey(const ValueKey('range-cell-b1')), findsOneWidget);
    expect(find.byKey(const ValueKey('range-cell-b3')), findsOneWidget);
    expect(find.byKey(const ValueKey('range-cell-a1')), findsNothing);
  });

  testWidgets('tapping a cell selects it and tapping again deselects it', (
    tester,
  ) async {
    await pumpPractice(tester);

    await tester.tap(find.byKey(const ValueKey('range-cell-a1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('range-check-a1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('range-cell-a1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('range-check-a1')), findsNothing);
  });

  testWidgets('the selection survives tag switching', (tester) async {
    await pumpPractice(tester);

    await tester.tap(find.byKey(const ValueKey('range-cell-a1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('range-tag-bilabial')));
    await tester.pump();
    expect(find.byKey(const ValueKey('range-check-a1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('range-tag-all')));
    await tester.pump();
    expect(find.byKey(const ValueKey('range-check-a1')), findsOneWidget);
  });

  testWidgets(
    'the confirm control is gated on the selection and shows the fixed select-first hint while nothing is selected',
    (tester) async {
      await pumpPractice(tester);

      final confirm = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('range-confirm')),
      );
      expect(confirm.onPressed, isNull);
      expect(find.byKey(const ValueKey('range-select-first')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('range-cell-a1')));
      await tester.pump();

      final enabled = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('range-confirm')),
      );
      expect(enabled.onPressed, isNotNull);
      expect(find.byKey(const ValueKey('range-select-first')), findsNothing);
      expect(find.byKey(const ValueKey('range-count')), findsOneWidget);
    },
  );

  testWidgets(
    'an empty catalog shows the fixed empty state with a clear control',
    (tester) async {
      await pumpPractice(
        tester,
        catalog: PhonemeCatalog(
          version: 'test',
          sourceLabel: 'test source',
          entries: const [],
        ),
      );

      expect(find.byKey(const ValueKey('range-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('range-clear')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('range-clear')));
      await tester.pump();
      expect(find.byKey(const ValueKey('range-tag-all')), findsOneWidget);
    },
  );

  testWidgets(
    'the shell replaces the practice placeholder with the range selection screen',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        GalateaApp(catalogFuture: Future.value(_catalog())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('练习').last);
      await tester.pump();

      expect(find.byKey(const ValueKey('range-grid')), findsOneWidget);
      expect(find.byType(PracticePage), findsOneWidget);
    },
  );
}
