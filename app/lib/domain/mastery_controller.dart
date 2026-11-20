import 'package:flutter/foundation.dart';

import 'mastery_engine.dart';
import 'mastery_store.dart';

/// The controller binding the engine to the store: answers mutate the
/// engine state in place (so the star change always survives — the R22
/// failure branch keeps it) and the whole document is persisted after
/// every record. `lastWriteFailed` drives the fixed notice
/// "复习队列暂未更新" (ux-flows R22 failure branch).
class MasteryController extends ChangeNotifier {
  MasteryController({required this.store, DateTime Function()? now})
    : engine = MasteryEngine(now: now);

  final MasteryStore store;
  final MasteryEngine engine;

  /// Whether the last persistence attempt failed; reset by the next
  /// successful write.
  bool lastWriteFailed = false;

  /// Whether the backing store degraded to memory (the platform backend
  /// was unavailable at load time), so the displayed state may not
  /// reflect persisted data — the detail page marks the star rating
  /// with the fixed 数据待同步 notice instead of presenting the values
  /// as trusted (ux-flows R23 failure branch).
  bool degraded = false;

  /// Loads the persisted state into the engine (stars start at 0 for a
  /// fresh install — the empty backing store reads as no entries).
  Future<void> load() async {
    final persisted = await store.read();
    for (final MapEntry<String, MasteryEntry> e in persisted.entries.entries) {
      engine.state.entries[e.key] = e.value;
    }
    notifyListeners();
  }

  /// Records one answer: the in-memory change always applies, then the
  /// document is persisted; a failed write only flips the notice flag.
  Future<void> record(String phonemeId, bool correct) async {
    if (correct) {
      engine.recordCorrect(phonemeId);
    } else {
      engine.recordWrong(phonemeId);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await store.write(engine.state);
      lastWriteFailed = false;
    } on StoreWriteException {
      lastWriteFailed = true;
    } catch (_) {
      lastWriteFailed = true;
    }
    notifyListeners();
  }
}
