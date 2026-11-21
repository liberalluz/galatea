import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The in-app language (`SDD §3.8`): zh-CN is the default, en-US the only
/// alternative; both ship complete copy tables.
enum AppLanguage { zhCn, enUs }

/// The persisted representation of an [AppLanguage] in the settings store.
String languageCode(AppLanguage language) => switch (language) {
  AppLanguage.zhCn => 'zh-CN',
  AppLanguage.enUs => 'en-US',
};

AppLanguage languageFromCode(String code) => switch (code) {
  'en-US' => AppLanguage.enUs,
  _ => AppLanguage.zhCn,
};

/// The settings controller (user ruling A, 2026-11-21): the language and
/// the audio toggle over the same persistence channel as the mastery
/// prefs. A language change notifies immediately — the copy scope above
/// the navigator rebuilds the whole tree, so the switch applies to every
/// rendered surface without a restart.
///
/// A failed or timed-out store read keeps the defaults session-local and
/// marks the controller degraded: values that may not reflect the
/// persisted choice are never presented as trusted (the R23 discipline).
class SettingsController extends ChangeNotifier {
  SettingsController();

  AppLanguage _language = AppLanguage.zhCn;

  /// The audio toggle (`SDD §3.8`): on by default; off keeps the
  /// pronunciation button and the listening tasks visible with playback
  /// as a fixed-notice no-op (user ruling A, 2026-11-21).
  bool _audioOn = true;

  bool degraded = false;

  AppLanguage get language => _language;

  bool get audioOn => _audioOn;

  /// Reads the persisted choice; a missing key keeps the default. A
  /// store that does not answer within the degraded timeout marks the
  /// controller degraded and keeps the defaults session-local.
  Future<void> load([Future<SharedPreferences>? prefsFuture]) async {
    try {
      final prefs = await (prefsFuture ?? SharedPreferences.getInstance())
          .timeout(const Duration(milliseconds: 150));
      final raw = prefs.getString('settings.language');
      if (raw != null) {
        _language = languageFromCode(raw);
      }
      final audio = prefs.getBool('settings.audio');
      if (audio != null) {
        _audioOn = audio;
      }
    } catch (_) {
      degraded = true;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    notifyListeners();
    await _persist();
  }

  Future<void> setAudioOn(bool on) async {
    _audioOn = on;
    notifyListeners();
    await _persist();
  }

  /// Persists both keys; a failed write stays session-local and marks the
  /// controller degraded rather than presenting the choice as saved.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 150),
      );
      await prefs.setString('settings.language', languageCode(_language));
      await prefs.setBool('settings.audio', _audioOn);
    } catch (_) {
      degraded = true;
    }
  }
}

/// The settings scope: hands the shell-owned controller to every page
/// below the navigator — the drill-downs read the audio toggle for the
/// playback gate without the shell threading it through every widget.
class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SettingsController controller;

  /// The nearest scope's controller, or `null` when none is mounted —
  /// a unit harness that pumps a page directly has no shell above it,
  /// and the playback gate treats that as "no settings limit".
  static SettingsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.controller;

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    if (scope == null) {
      throw FlutterError('no SettingsScope above ${context.widget}');
    }
    return scope.controller;
  }

  @override
  bool updateShouldNotify(SettingsScope oldWidget) =>
      oldWidget.controller != controller;
}
