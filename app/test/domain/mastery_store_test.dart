import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/domain/mastery_engine.dart';
import 'package:galatea/domain/mastery_prefs_store.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

MasteryState _state() {
  final state = MasteryState();
  final a = state.entryFor('p-a');
  a.star = 2;
  a.step = 1;
  a.due = DateTime(2026, 11, 25, 9);
  final b = state.entryFor('p-b');
  b.star = 0;
  return state;
}

void main() {
  test('the in-memory store round-trips the state', () async {
    final store = InMemoryMasteryStore();
    await store.write(_state());

    final read = await store.read();
    expect(read.entryFor('p-a').star, 2);
    expect(read.entryFor('p-a').step, 1);
    expect(read.entryFor('p-a').due, DateTime(2026, 11, 25, 9));
    expect(read.entryFor('p-b').star, 0);
  });

  test(
    'the in-memory store can fail writes for the R22 failure branch',
    () async {
      final store = InMemoryMasteryStore()..failWrites = true;

      expect(() => store.write(_state()), throwsA(isA<StoreWriteException>()));
    },
  );

  test('the state JSON round-trips star, step and due', () {
    final state = _state();
    final restored = MasteryState.fromJson(state.toJson());

    expect(restored.entryFor('p-a').star, 2);
    expect(restored.entryFor('p-a').step, 1);
    expect(restored.entryFor('p-a').due, DateTime(2026, 11, 25, 9));
    expect(restored.entryFor('p-b').star, 0);
    expect(restored.entryFor('p-b').due, isNull);
  });

  test('the preferences store round-trips through the backing store', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsMasteryStore(prefs);
    await store.write(_state());

    final read = await store.read();
    expect(read.entryFor('p-a').star, 2);
    expect(read.entryFor('p-a').due, DateTime(2026, 11, 25, 9));
  });

  test('the preferences store reads an empty backing store as fresh', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsMasteryStore(prefs);

    final read = await store.read();
    expect(read.entryFor('p-a').star, 0, reason: 'stars start at 0');
    expect(read.entryFor('p-a').due, isNull);
  });
}
