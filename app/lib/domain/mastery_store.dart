import 'mastery_engine.dart';

/// The persistence contract for the mastery state (`REQ-022`): the R22
/// intervals must survive a restart, so the controller syncs the whole
/// state document through this interface. Implementations cover the
/// platform backends and the in-memory fake the tests inject.
abstract class MasteryStore {
  Future<MasteryState> read();

  Future<void> write(MasteryState state);
}

/// Raised when the backing store rejects a write; the controller turns
/// it into the fixed review-queue notice (ux-flows R22 failure branch).
class StoreWriteException implements Exception {
  StoreWriteException(this.cause);

  final Object cause;

  @override
  String toString() => 'StoreWriteException: $cause';
}

/// The in-memory store: the test fake, with an injectable write failure
/// for pinning the R22 failure branch.
class InMemoryMasteryStore implements MasteryStore {
  MasteryState? _state;

  /// When true every write throws — the R22 failure branch fixture.
  bool failWrites = false;

  @override
  Future<MasteryState> read() async =>
      _state == null ? MasteryState() : MasteryState.fromJson(_state!.toJson());

  @override
  Future<void> write(MasteryState state) async {
    if (failWrites) {
      throw StoreWriteException(StateError('injected write failure'));
    }
    _state = MasteryState.fromJson(state.toJson());
  }
}
