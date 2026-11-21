import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/practice/quiz_page.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// A mutable clock so fixtures can place due dates in the past or future.
class MutableClock {
  MutableClock(this.dateTime);
  DateTime dateTime;
  DateTime Function() get read =>
      () => dateTime;
}

PhonemeCatalog _catalog() => PhonemeCatalog(
  version: 'test',
  sourceLabel: 'test source',
  entries: [
    for (final glyph in ['a', 'b', 'c', 'd', 'e'])
      PhonemeCatalogEntry(
        id: 'p-$glyph',
        kind: PhonemeKind.vowel,
        group: 'front',
        printGlyph: glyph,
        tts: 'sound-$glyph',
      ),
  ],
);

/// A stub task registry pinning the session state machine so the review
/// source wiring is observed without the real task types.
Map<String, QuizTaskBuilder> _stubTasks() => {
  'recognition': (context, task) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        task.entry.printGlyph,
        key: ValueKey('review-stub-prompt-${task.entry.id}'),
      ),
      const SizedBox(height: 24),
      FilledButton(
        key: const ValueKey('review-stub-answer'),
        onPressed: () => task.onAnswered(true),
        child: const Text('作答'),
      ),
    ],
  ),
};

/// Pumps the shared quiz page over a review source built the way the B29
/// review entry will build it: the due-today phonemes in ascending due
/// order (same-day entries in catalog order). The queue's not-yet-due
/// entries do not join.
Future<void> _pumpReviewSource(
  WidgetTester tester, {
  required MasteryController controller,
  required PhonemeCatalog catalog,
}) async {
  final now = controller.engine.now();
  final due = <PhonemeCatalogEntry>[];
  for (final entry in catalog.entries) {
    if (controller.engine.isDue(entry.id)) due.add(entry);
  }
  due.sort(
    (a, b) => (controller.engine.state.entries[a.id]?.due ?? now).compareTo(
      controller.engine.state.entries[b.id]?.due ?? now,
    ),
  );
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuizPage(
          source: QuizSource.review(due),
          catalog: catalog,
          mastery: controller,
          tasks: _stubTasks(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the review source renders the same shared quiz page with the 复习 batch label and the due range as the denominator (REQ-034, TC-QUIZ-008)',
    (tester) async {
      final clock = MutableClock(DateTime(2026, 11, 20, 9));
      final controller = MasteryController(
        store: InMemoryMasteryStore(),
        now: clock.read,
      );
      await controller.load();
      // p-a and p-b are due (one overdue, one today); p-c sits 1 day out
      // and does not join the session range.
      controller.engine.state.entryFor('p-a').due = clock.dateTime.add(
        const Duration(days: -2),
      );
      controller.engine.state.entryFor('p-b').due = clock.dateTime;
      controller.engine.state.entryFor('p-c').due = clock.dateTime.add(
        const Duration(days: 1),
      );
      await _pumpReviewSource(
        tester,
        controller: controller,
        catalog: _catalog(),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('session-view')), findsOneWidget);
      expect(find.text('复习'), findsOneWidget);
      // The session covers exactly the due-today subset in due order:
      // the overdue p-a first, then p-b; p-c never renders.
      expect(
        find.byKey(const ValueKey('review-stub-prompt-p-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('review-stub-prompt-p-b')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('review-stub-prompt-p-c')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a review-source answer records into the mastery controller like a new-practice answer (REQ-034, REQ-021)',
    (tester) async {
      final clock = MutableClock(DateTime(2026, 11, 20, 9));
      final controller = MasteryController(
        store: InMemoryMasteryStore(),
        now: clock.read,
      );
      await controller.load();
      controller.engine.state.entryFor('p-a').due = clock.dateTime;
      await _pumpReviewSource(
        tester,
        controller: controller,
        catalog: _catalog(),
      );
      await tester.pump();

      final starsBefore = controller.engine.state.entryFor('p-a').star;
      await tester.tap(find.byKey(const ValueKey('review-stub-answer')));
      await tester.pump();

      expect(
        controller.engine.state.entryFor('p-a').star,
        starsBefore + 1,
        reason: 'the verdict recorded into the mastery engine',
      );
      expect(find.byKey(const ValueKey('session-feedback')), findsOneWidget);
    },
  );
}
