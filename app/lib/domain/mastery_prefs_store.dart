import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'mastery_engine.dart';
import 'mastery_store.dart';

/// The production store (`REQ-022`): the mastery state as one JSON
/// document under a fixed key. `shared_preferences` covers Web, mobile
/// and desktop — the R22 intervals must survive a restart and the Web
/// build has no `dart:io`.
class PrefsMasteryStore implements MasteryStore {
  PrefsMasteryStore(this._prefs);

  static const String _kKey = 'mastery.v1';

  final SharedPreferences _prefs;

  @override
  Future<MasteryState> read() async {
    final raw = _prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return MasteryState();
    return MasteryState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(MasteryState state) async {
    final ok = await _prefs.setString(_kKey, jsonEncode(state.toJson()));
    if (!ok) {
      throw StoreWriteException('the backing store rejected the write');
    }
  }
}
