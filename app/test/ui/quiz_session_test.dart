import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/practice/quiz_page.dart';
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
  String? sourceLabel,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuizSession(
          range: range ?? _range(),
          sourceLabel: sourceLabel ?? '元音',
          tasks: _stubTasks(),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A stub task registry pinning the session state machine: the fixed-verdict
/// answer action keeps the progress, rate and feedback tests independent of
/// the real task types (`B13` decision: the registry is injectable).
Map<String, QuizTaskBuilder> _stubTasks() => {
  'recognition': (context, task) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        task.entry.printGlyph,
        key: ValueKey('session-stub-prompt-${task.entry.id}'),
      ),
      const SizedBox(height: 24),
      FilledButton(
        key: const ValueKey('session-stub-answer'),
        onPressed: () => task.onAnswered(true),
        child: const Text('作答'),
      ),
    ],
  ),
};

void main() {
  testWidgets(
    'the shared quiz page hosts the session for a new-practice source and the label shows the row coarse group (REQ-034, REQ-020)',
    (tester) async {
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
          home: Scaffold(
            body: QuizPage(
              source: QuizSource.newRow(_range(), PhonemeKind.vowel),
              catalog: catalog,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('session-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('session-progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('session-range-label')), findsOneWidget);
      final label = tester
          .widget<Text>(find.byKey(const ValueKey('session-range-label')))
          .data!;
      expect(label, '元音');
    },
  );

  testWidgets(
    'the batch label follows the source: a consonant row shows 辅音 and a review source shows 复习 (REQ-034, TC-QUIZ-008)',
    (tester) async {
      await pumpSession(tester, sourceLabel: '辅音');
      expect(find.text('辅音'), findsOneWidget);

      await pumpSession(tester, sourceLabel: '复习');
      expect(find.text('复习'), findsOneWidget);
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
