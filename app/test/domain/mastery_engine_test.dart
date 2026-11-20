import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/domain/mastery_engine.dart';

/// A mutable clock so tests pin the day arithmetic without sleeping.
class MutableClock {
  MutableClock(this.dateTime);
  DateTime dateTime;
  DateTime Function() get read =>
      () => dateTime;
  void advanceDays(int days) => dateTime = dateTime.add(Duration(days: days));
}

MasteryEngine _engine(MutableClock clock) => MasteryEngine(now: clock.read);

void main() {
  test('a wrong answer lowers the star by 1 and queues for tomorrow', () {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final engine = _engine(clock);

    engine.recordCorrect('p-a');
    expect(engine.state.entryFor('p-a').star, 1);
    expect(
      engine.state.entryFor('p-a').due,
      isNull,
      reason: 'a correct answer does not queue',
    );

    engine.recordWrong('p-a');
    final entry = engine.state.entryFor('p-a');
    expect(entry.star, 0);
    expect(entry.step, 0);
    expect(
      entry.due,
      DateTime(2026, 11, 21, 9),
      reason: 'the first queue entry sits at interval 1',
    );
  });

  test('the star floors at 0 on repeated wrong answers', () {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final engine = _engine(clock);

    engine.recordWrong('p-a');
    engine.recordWrong('p-a');
    expect(engine.state.entryFor('p-a').star, 0);
  });

  test('correct answers raise the star capped at 3 from the 0 start', () {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final engine = _engine(clock);

    for (var i = 0; i < 5; i++) {
      engine.recordCorrect('p-a');
    }
    expect(engine.state.entryFor('p-a').star, 3);
    expect(engine.state.entryFor('p-a').due, isNull);
  });

  test('consecutive correct review answers advance 1/2/4/7/15 days', () {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final engine = _engine(clock);

    engine.recordWrong('p-a'); // queued: due +1 day, step 0
    final expectedDays = [2, 4, 7, 15];
    for (var i = 0; i < expectedDays.length; i++) {
      // Jump to the due date so the review answer counts as consecutive.
      clock.advanceDays(kReviewIntervals[engine.state.entryFor('p-a').step]);
      engine.recordCorrect('p-a');
      final entry = engine.state.entryFor('p-a');
      expect(entry.step, i + 1);
      expect(
        entry.due,
        clock.dateTime.add(Duration(days: expectedDays[i])),
        reason: 'step ${i + 1} sits at the ${expectedDays[i]}-day interval',
      );
    }
  });

  test('the interval caps at 15 days after the fifth step', () {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final engine = _engine(clock);

    engine.recordWrong('p-a');
    final entry = engine.state.entryFor('p-a');
    entry.step = 4; // already at the 15-day step
    entry.due = clock.dateTime;
    engine.recordCorrect('p-a');
    expect(entry.step, 4, reason: 'the ladder tops out at 15 days');
    expect(entry.due, clock.dateTime.add(const Duration(days: 15)));
  });

  test('a wrong review answer resets to interval 1', () {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final engine = _engine(clock);

    engine.recordWrong('p-a');
    final entry = engine.state.entryFor('p-a');
    entry.step = 3; // mid-ladder (7-day step)
    clock.advanceDays(7);
    engine.recordCorrect('p-a');
    clock.advanceDays(7);
    engine.recordWrong('p-a'); // wrong during review
    expect(entry.step, 0);
    expect(entry.due, clock.dateTime.add(const Duration(days: 1)));
    expect(
      entry.star,
      0,
      reason: 'the wrong answer still lowers the star (1 → 0)',
    );
  });

  test('due means now at or past the due date', () {
    final clock = MutableClock(DateTime(2026, 11, 20, 9));
    final engine = _engine(clock);

    expect(
      engine.isDue('p-a'),
      isFalse,
      reason: 'an unqueued phoneme is never due',
    );

    engine.recordWrong('p-a');
    expect(engine.isDue('p-a'), isFalse, reason: 'due tomorrow is not due');
    clock.advanceDays(1);
    expect(engine.isDue('p-a'), isTrue, reason: 'the due day itself counts');
    clock.advanceDays(2);
    expect(engine.isDue('p-a'), isTrue, reason: 'overdue stays due');
  });
}
