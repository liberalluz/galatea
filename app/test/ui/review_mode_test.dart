import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/practice/practice_page.dart';

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

Future<void> _pumpPractice(
  WidgetTester tester, {
  MasteryController? controller,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PracticePage(
          catalogFuture: Future.value(_catalog()),
          masteryController: controller,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Queues [id] with its due date at [daysFromNow] (negative = overdue,
/// 0 = due today) so the review pane can render it.
void _queue(MasteryController controller, String id, int daysFromNow) {
  final entry = controller.engine.state.entryFor(id);
  entry.star = 1;
  entry.step = 0;
  entry.due = controller.engine.now().add(Duration(days: daysFromNow));
}

Future<void> _switchMode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(ValueKey('practice-mode-$mode')));
  await tester.pump();
}

Finder _dueTile(String id) => find.byKey(ValueKey('review-tile-$id'));

void main() {
  testWidgets(
    'the review mode shows the fixed empty state when nothing is due',
    (tester) async {
      final clock = MutableClock(DateTime(2026, 11, 20, 9));
      final controller = MasteryController(
        store: InMemoryMasteryStore(),
        now: clock.read,
      );
      await controller.load();
      await _pumpPractice(tester, controller: controller);

      await _switchMode(tester, 'review');

      expect(
        find.byKey(const ValueKey('review-empty')),
        findsOneWidget,
        reason: 'the R22 empty state replaces a blank list',
      );
    },
  );

  testWidgets(
    'due phonemes surface with their due labels in ascending due order',
    (tester) async {
      final clock = MutableClock(DateTime(2026, 11, 20, 9));
      final controller = MasteryController(
        store: InMemoryMasteryStore(),
        now: clock.read,
      );
      await controller.load();
      // p-a went overdue two days ago, p-b is due today and p-c sits at
      // the 1-day-out row of the queue (wireframe P5 shows future rows).
      _queue(controller, 'p-b', 0);
      _queue(controller, 'p-a', -2);
      _queue(controller, 'p-c', 1);
      await _pumpPractice(tester, controller: controller);

      await _switchMode(tester, 'review');

      expect(_dueTile('p-b'), findsOneWidget);
      expect(_dueTile('p-a'), findsOneWidget);
      expect(_dueTile('p-c'), findsOneWidget);
      expect(
        tester.getTopLeft(_dueTile('p-a')).dy,
        lessThan(tester.getTopLeft(_dueTile('p-b')).dy),
        reason: 'ascending due order: overdue before today',
      );
      expect(
        tester.getTopLeft(_dueTile('p-b')).dy,
        lessThan(tester.getTopLeft(_dueTile('p-c')).dy),
        reason: 'today before the 1天后 row',
      );
      expect(find.textContaining('今天'), findsNWidgets(2));
      expect(find.textContaining('1天后'), findsOneWidget);
      expect(
        find.text('今日到期: 2'),
        findsOneWidget,
        reason: 'the count covers only the due-today entries',
      );
      expect(
        find.byKey(const ValueKey('review-count')),
        findsOneWidget,
        reason: 'the pane shows the due count (wireframe P5)',
      );
    },
  );

  testWidgets(
    'a wrong answer in new practice lowers the star and queues the phoneme',
    (tester) async {
      final clock = MutableClock(DateTime(2026, 11, 20, 9));
      final controller = MasteryController(
        store: InMemoryMasteryStore(),
        now: clock.read,
      );
      await controller.load();
      await _pumpPractice(tester, controller: controller);

      // Run a new-practice session and answer p-a wrong: the correct
      // spelling option is sound-a, so tap sound-b.
      await tester.tap(find.byKey(const ValueKey('range-cell-p-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('range-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-option-sound-b')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-submit')));
      await tester.pump();

      expect(
        controller.engine.state.entryFor('p-a').star,
        0,
        reason: 'the wrong answer floors the star at 0',
      );
      expect(
        controller.engine.state.entryFor('p-a').due,
        isNotNull,
        reason: 'the wrong answer queues the phoneme (R22 entry)',
      );
    },
  );

  testWidgets('starting the review runs the due phonemes through the session', (
    tester,
  ) async {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final controller = MasteryController(
      store: InMemoryMasteryStore(),
      now: clock.read,
    );
    await controller.load();
    _queue(controller, 'p-b', 0);
    _queue(controller, 'p-c', 0);
    await _pumpPractice(tester, controller: controller);

    await _switchMode(tester, 'review');
    await tester.tap(find.byKey(const ValueKey('review-start')));
    await tester.pump();

    // The session view takes over with the due range (R22 exit: the
    // same task registry and task type as new practice).
    expect(find.byKey(const ValueKey('session-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-range-label')), findsOneWidget);
  });

  testWidgets(
    'a store write failure keeps the star change and shows the notice',
    (tester) async {
      final clock = MutableClock(DateTime(2026, 11, 20, 9));
      final controller = MasteryController(
        store: InMemoryMasteryStore()..failWrites = true,
        now: clock.read,
      );
      await controller.load();
      await _pumpPractice(tester, controller: controller);

      // Answer wrong in new practice (same flow as the queueing test).
      await tester.tap(find.byKey(const ValueKey('range-cell-p-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('range-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-option-sound-b')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-submit')));
      await tester.pump();
      // The notice lives in the review pane; switching leaves the session.
      await _switchMode(tester, 'review');
      await tester.pump();

      expect(
        find.byKey(const ValueKey('review-store-failed')),
        findsOneWidget,
        reason: 'the R22 failure branch shows the fixed notice',
      );
      expect(
        controller.engine.state.entryFor('p-a').due,
        isNotNull,
        reason: 'the in-memory change survives the failed write',
      );
    },
  );

  testWidgets('a correct review answer raises the star through the engine', (
    tester,
  ) async {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final controller = MasteryController(
      store: InMemoryMasteryStore(),
      now: clock.read,
    );
    await controller.load();
    _queue(controller, 'p-b', 0);
    await _pumpPractice(tester, controller: controller);

    await _switchMode(tester, 'review');
    await tester.tap(find.byKey(const ValueKey('review-start')));
    await tester.pump();
    // The recognition task's correct option for p-b is sound-b.
    await tester.tap(find.byKey(const ValueKey('task-option-sound-b')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('task-submit')));
    await tester.pump();

    expect(
      controller.engine.state.entryFor('p-b').star,
      2,
      reason: 'the review correct answer advances the star (1 → 2)',
    );
  });
}
