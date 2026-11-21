import 'package:flutter/material.dart';

import '../copy/app_copy.dart';
import '../settings/settings_controller.dart';
import 'audio_service.dart';

/// The playback gate (user ruling A, 2026-11-21): with the audio toggle
/// on this is a plain play; off, the call is a real no-op and the fixed
/// off notice shows — the button and the listening tasks stay in place
/// and playback never blocks the page.
void gatedPlay(
  BuildContext context,
  AudioService audio,
  String phonemeId,
  String speakText,
) {
  // A harness without a mounted scope has no settings limit: play plain.
  final settings = SettingsScope.maybeOf(context);
  if (settings != null && !settings.audioOn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('audio-off-notice'),
        content: Text(CopyScope.of(context).audioOffNotice),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }
  audio.play(phonemeId, speakText);
}
