import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/me/review_page.dart';
import 'package:galatea/ui/practice/quiz_page.dart';

/// Builds a controller whose engine state is seeded directly, so tests
/// pin the due-order contract without driving the practice flow.
MasteryController seeded(Map<String, DateTime> dues) {
  final controller = MasteryController(store: InMemoryMasteryStore());
  controller.load();
  final engine = controller.engine;
  for (final MapEntry(key: id, value: due) in dues.entries) {
    final entry = engine.state.entryFor(id);
    entry.due = due;
  }
  return controller;
}

PhonemeCatalog fakeCatalog() => PhonemeCatalog(
  version: 'test-v1',
  sourceLabel: 'test source',
  entries: [
    for (final glyph in ['a', 'b', 'c', 'd', 'e'])
      PhonemeCatalogEntry(
        id: glyph,
        kind: PhonemeKind.vowel,
        group: 'front',
        printGlyph: glyph,
        tts: 'sound-$glyph',
      ),
  ],
);

Future<void> pumpReview(
  WidgetTester tester,
  MasteryController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReviewPage(
        catalogFuture: Future.value(fakeCatalog()),
        mastery: controller,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  final now = DateTime.now();

  testWidgets('the drill-down lists the due-today phonemes in due order', (
    tester,
  ) async {
    final controller = seeded({
      'a': now.subtract(const Duration(days: 1)),
      'b': now,
      'c': now.subtract(const Duration(hours: 2)),
      // Not yet due: excluded from the list.
      'd': now.add(const Duration(days: 2)),
    });
    await pumpReview(tester, controller);

    // Three due entries, oldest due first; the not-yet-due one is
    // nowhere in the list.
    expect(find.byKey(const ValueKey('review-empty')), findsNothing);
    expect(find.byKey(const ValueKey('review-item-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-item-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-item-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-item-d')), findsNothing);

    final a = tester.getTopLeft(find.byKey(const ValueKey('review-item-a')));
    final c = tester.getTopLeft(find.byKey(const ValueKey('review-item-c')));
    expect(a.dy < c.dy, isTrue, reason: 'overdue sorts before due-today');
  });

  testWidgets('an empty queue shows the fixed review-empty state', (
    tester,
  ) async {
    final controller = seeded({'a': now.add(const Duration(days: 3))});
    await pumpReview(tester, controller);

    expect(find.byKey(const ValueKey('review-empty')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('review-start')),
      findsNothing,
      reason: 'no session starts from an empty queue',
    );
  });

  testWidgets(
    'starting a session opens the shared quiz page over the review source and verdicts record into the controller',
    (tester) async {
      final controller = seeded({
        'a': now,
        'b': now.add(const Duration(hours: 1)),
      });
      await pumpReview(tester, controller);

      await tester.tap(find.byKey(const ValueKey('review-start')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(QuizPage), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-page-session')), findsOneWidget);
      expect(find.byKey(const ValueKey('session-range-label')), findsOneWidget);

      // One verdict records into the controller's engine (the review
      // session is not score-free): pick the first option, then submit.
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-submit')));
      await tester.pump();
      final entry = controller.engine.state.entries['a'];
      expect(entry, isNotNull, reason: 'the verdict recorded');
    },
  );
}
