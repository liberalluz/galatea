import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'audio_service.dart';

/// Web Speech synthesis provider (B7, ADR-0002): the browser synthesizes the
/// phoneme audio on device, so there is no audio file to cache — the cache
/// seam from ADR-0002 stays behind the interface and a real cache arrives
/// with a future provider (see the B7 PR notes).
@JS('window.speechSynthesis')
external SpeechSynthesis? get _speechSynthesis;

@JS()
@staticInterop
class SpeechSynthesis {}

extension SpeechSynthesisExt on SpeechSynthesis {
  external void speak(SpeechSynthesisUtterance utterance);
  external void cancel();
}

@JS()
@staticInterop
class SpeechSynthesisUtterance {
  external factory SpeechSynthesisUtterance(JSString text);
}

extension SpeechSynthesisUtteranceExt on SpeechSynthesisUtterance {
  external set lang(JSString value);
  external set rate(JSNumber value);
  external set onstart(JSFunction value);
  external set onend(JSFunction value);
  external set onerror(JSFunction value);
}

class WebSpeechAudioService implements AudioService {
  final _state = ValueNotifier(AudioPlaybackState.ready);

  @override
  ValueListenable<AudioPlaybackState> get state => _state;

  @override
  Future<void> play(String phonemeId, String speakText) async {
    final synthesis = _speechSynthesis;
    if (synthesis == null) {
      _state.value = AudioPlaybackState.failed;
      return;
    }

    _state.value = AudioPlaybackState.loading;
    synthesis.cancel();

    final utterance = SpeechSynthesisUtterance(speakText.toJS);
    utterance.lang = 'en-US'.toJS;
    // Slower than natural speech so the phoneme stays intelligible.
    utterance.rate = 0.7.toJS;
    utterance.onstart = (() {
      _state.value = AudioPlaybackState.playing;
    }).toJS;
    utterance.onend = (() {
      _state.value = AudioPlaybackState.ready;
    }).toJS;
    utterance.onerror = ((JSAny? _) {
      _state.value = AudioPlaybackState.failed;
    }).toJS;

    synthesis.speak(utterance);
  }

  @override
  void stop() {
    _speechSynthesis?.cancel();
    _state.value = AudioPlaybackState.ready;
  }
}

AudioService createPlatformAudioService() => WebSpeechAudioService();
