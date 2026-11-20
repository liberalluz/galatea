import 'package:flutter/foundation.dart';

import 'audio_service.dart';

/// Non-Web stub (ADR-0002): v0.1.0 ships Web-first; until the native batch
/// lands, play requests report failure through the shared contract instead
/// of crashing, and the rest of the page keeps working.
class UnsupportedAudioService implements AudioService {
  final _state = ValueNotifier(AudioPlaybackState.ready);

  @override
  ValueListenable<AudioPlaybackState> get state => _state;

  @override
  Future<void> play(String phonemeId, String speakText) async {
    _state.value = AudioPlaybackState.failed;
  }

  @override
  void stop() {
    _state.value = AudioPlaybackState.ready;
  }
}

AudioService createPlatformAudioService() => UnsupportedAudioService();
