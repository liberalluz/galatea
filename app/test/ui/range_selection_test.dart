import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/practice/quiz_page.dart';
import 'package:galatea/ui/shell/shell_page.dart';

/// Synthetic catalog: 7 front vowels (two grid rows) and 3 bilabial
/// consonants (one grid row), enough to pin the single-row select state
/// machine without touching the bundled assets.
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

Future<void> pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // The mastery controller and the data layers are injected so every
  // FutureBuilder resolves deterministically on the first pumps; the
  // asset loaders run real IO and race the fake-async clock (same
  // preload pattern as the chart suite). The platform-backed
  // preferences path is the first-run suite's concern.
  final mastery = MasteryController(store: InMemoryMasteryStore());
  await mastery.load();
  CorrespondenceTable? correspondence;
  ExamplesData? examples;
  GlyphData? glyphs;
  await tester.runAsync(() async {
    correspondence = await loadCorrespondence();
    examples = await loadExamples();
    glyphs = await loadGlyphs();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: ShellPage(
        catalogFuture: Future.value(_catalog()),
        correspondenceFuture: Future.value(correspondence),
        examplesFuture: Future.value(examples),
        glyphsFuture: Future.value(glyphs),
        masteryFuture: Future.value(mastery),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Enters the row-select state through the floating practice button.
Future<void> enterSelectState(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('practice-entry')));
  await tester.pump();
}

void main() {
  testWidgets(
    'the floating practice button enters the in-page row-select state with the 请选择 bar and the first row selected by default',
    (tester) async {
      await pumpShell(tester);

      expect(find.byKey(const ValueKey('select-bar')), findsNothing);
      expect(find.byKey(const ValueKey('notation-switch')), findsOneWidget);

      await enterSelectState(tester);

      expect(find.byKey(const ValueKey('select-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('select-count')), findsOneWidget);
      expect(find.byKey(const ValueKey('select-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('notation-switch')), findsNothing);
      // The button turns into the confirm control.
      expect(find.byKey(const ValueKey('select-confirm')), findsOneWidget);
      expect(find.byKey(const ValueKey('practice-entry')), findsNothing);
      // The first row (a1..a5) is selected by default: its cells carry
      // the row-selected decoration.
      expect(
        find.byKey(const ValueKey('phoneme-a1-selected-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('phoneme-a5-selected-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('phoneme-b1-selected-row')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'tapping another row moves the single-row selection — exactly one row is ever selected (REQ-015, TC-QUIZ-001)',
    (tester) async {
      await pumpShell(tester);
      await enterSelectState(tester);

      // Tap a consonant-row cell: the selection moves off the default
      // first vowel row onto the consonant row.
      await tester.tap(find.byKey(const ValueKey('phoneme-b1')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('phoneme-a1-selected-row')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('phoneme-b1-selected-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('phoneme-b3-selected-row')),
        findsOneWidget,
      );
      // Still exactly one selected row after another tap.
      await tester.tap(find.byKey(const ValueKey('phoneme-a6')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('phoneme-b3-selected-row')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('phoneme-a6-selected-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('phoneme-a1-selected-row')),
        findsNothing,
      );
    },
  );

  testWidgets('cancel exits the select state back to the idle chart', (
    tester,
  ) async {
    await pumpShell(tester);
    await enterSelectState(tester);

    await tester.tap(find.byKey(const ValueKey('select-cancel')));
    await tester.pump();

    expect(find.byKey(const ValueKey('select-bar')), findsNothing);
    expect(find.byKey(const ValueKey('notation-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-entry')), findsOneWidget);
    expect(find.byKey(const ValueKey('phoneme-a1-selected-row')), findsNothing);
  });

  testWidgets(
    'confirm starts the shared quiz page over exactly the selected row phonemes with the row coarse-group batch label',
    (tester) async {
      await pumpShell(tester);
      await enterSelectState(tester);

      // Move the selection onto the consonant row, then confirm.
      await tester.tap(find.byKey(const ValueKey('phoneme-b1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('select-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(QuizPage), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-page-session')), findsOneWidget);
      // The batch label shows the selected row's coarse group (辅音),
      // not the old denominator text.
      expect(find.byKey(const ValueKey('session-range-label')), findsOneWidget);
      final label = tester
          .widget<Text>(find.byKey(const ValueKey('session-range-label')))
          .data!;
      expect(label, '辅音');
    },
  );

  testWidgets(
    'the standalone range screen is abolished: no range grid, tags or per-phoneme selection controls exist anywhere',
    (tester) async {
      await pumpShell(tester);
      await enterSelectState(tester);

      expect(find.byKey(const ValueKey('range-grid')), findsNothing);
      expect(find.byKey(const ValueKey('range-tags')), findsNothing);
      expect(find.byKey(const ValueKey('range-cell-a1')), findsNothing);
      expect(find.byKey(const ValueKey('range-confirm')), findsNothing);
    },
  );
}
