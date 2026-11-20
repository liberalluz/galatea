import 'package:flutter/foundation.dart';

import 'default_provider.dart' as provider;

/// Audio layer contract (B7, ADR-0002): one internal interface so the TTS
/// provider can be replaced (human recordings in a later version) without
/// touching call sites. This layer never imports content or UI types.
///
/// The four fixed states are the SDD component table's `loading / ready /
/// playing / failed`; failures are captured here and mapped to [AudioPlaybackState.failed]
/// so a playback problem never blocks the other detail sections.
enum AudioPlaybackState { ready, loading, playing, failed }

abstract class AudioService {
  /// The playback state; UI listens and re-renders the pronunciation button.
  ValueListenable<AudioPlaybackState> get state;

  /// Starts playback for [phonemeId]; [speakText] is the speakable
  /// approximation carried by the catalog entry (bundled glyphs are phonetic
  /// symbols the engines cannot read). Failure reports through [state],
  /// never by throwing.
  Future<void> play(String phonemeId, String speakText);

  /// Stops any playback and returns to the ready state.
  void stop();
}

/// The default service for the running platform (Web Speech on the Web,
/// an unsupported stub elsewhere until its batch lands).
///
/// Offline behaviour (B19, `REQ-029`, ux-flows R29): the whole app ships
/// bundled data and makes no network request, and the Web provider
/// synthesizes on device — with the network off the flows keep working and
/// a synthesis failure degrades to the fixed failure links (the
/// pronunciation retry state, the listening-task ladder) instead of
/// blocking the page.
AudioService createDefaultAudioService() =>
    provider.createPlatformAudioService();
