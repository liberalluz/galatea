import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/practice/practice_page.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// Synthetic range entries: three phonemes, enough to pin the progress
/// advance (1/3 → 3/3), the range label and the feedback without touching
/// the bundled assets.
List<PhonemeCatalogEntry> _range() => [
  for (var i = 1; i <= 3; i++)
    PhonemeCatalogEntry(
      id: 'a$i',
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'a$i',
    ),
];

Future<void> pumpSession(
  WidgetTester tester, {
  List<PhonemeCatalogEntry>? range,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: QuizSession(range: range ?? _range())),
    ),
  );
  await tester.pump();
}

Future<void> pumpPracticeAndConfirm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final catalog = PhonemeCatalog(
    version: 'test',
    sourceLabel: 'test source',
    entries: _range(),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PracticePage(catalogFuture: Future.value(catalog))),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));

  await tester.tap(find.byKey(const ValueKey('range-cell-a1')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('range-confirm')));
  await tester.pump();
}

void main() {
  testWidgets(
    'confirming the range selection enters the quiz session, replacing the range grid',
    (tester) async {
      await pumpPracticeAndConfirm(tester);

      expect(find.byKey(const ValueKey('session-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('session-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('range-grid')), findsNothing);
    },
  );

  testWidgets(
    'the range label shows the selected phoneme count matching the denominator',
    (tester) async {
      await pumpSession(tester);

      expect(find.byKey(const ValueKey('session-range-label')), findsOneWidget);
      expect(find.text('3 个音位'), findsOneWidget);
    },
  );

  testWidgets(
    'the progress advances per answered item and reaches 100% when every phoneme has been answered at least once',
    (tester) async {
      await pumpSession(tester);

      String rate() =>
          tester.widget<Text>(find.byKey(const ValueKey('session-rate'))).data!;

      expect(rate(), '0%');

      await tester.tap(find.byKey(const ValueKey('session-stub-answer')));
      await tester.pump();
      expect(rate(), '33%');

      await tester.tap(find.byKey(const ValueKey('session-stub-answer')));
      await tester.pump();
      expect(rate(), '67%');

      await tester.tap(find.byKey(const ValueKey('session-stub-answer')));
      await tester.pump();
      expect(rate(), '100%');
    },
  );

  testWidgets('feedback appears immediately after an answer is submitted', (
    tester,
  ) async {
    await pumpSession(tester);

    expect(find.byKey(const ValueKey('session-feedback')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('session-stub-answer')));
    await tester.pump();
    expect(find.byKey(const ValueKey('session-feedback')), findsOneWidget);
  });

  testWidgets(
    'a zero denominator hides the progress bar and shows the fixed range-unavailable hint',
    (tester) async {
      await pumpSession(tester, range: []);

      expect(find.byKey(const ValueKey('session-progress')), findsNothing);
      expect(find.byKey(const ValueKey('session-rate')), findsNothing);
      expect(find.byKey(const ValueKey('session-unavailable')), findsOneWidget);
      expect(find.text('范围暂不可用'), findsOneWidget);
    },
  );
}
