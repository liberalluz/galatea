import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/detail/detail_page.dart';

/// Scripted fake: records the calls and lets tests drive the four fixed
/// states directly, so no real browser TTS runs inside the fake-async zone.
class FakeAudioService implements AudioService {
  FakeAudioService() : state = ValueNotifier(AudioPlaybackState.ready);

  final List<(String, String)> calls = <(String, String)>[];
  bool stopped = false;

  @override
  final ValueNotifier<AudioPlaybackState> state;

  @override
  Future<void> play(String phonemeId, String speakText) async {
    calls.add((phonemeId, speakText));
  }

  @override
  void stop() {
    stopped = true;
    state.value = AudioPlaybackState.ready;
  }
}

void main() {
  PhonemeCatalog fakeCatalog() => PhonemeCatalog(
    version: 'test-v1',
    sourceLabel: 'test source',
    entries: [
      for (final glyph in ['a', 'b', 'c', 'd', 'e'])
        PhonemeCatalogEntry(
          id: glyph,
          kind: PhonemeKind.vowel,
          group: 'front',
          printGlyph: glyph,
          tts: 'sound-$glyph',
        ),
    ],
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    FakeAudioService audio, {
    required String initialId,
  }) async {
    // Tall viewport so the lazy ListView builds every zone section.
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(
          catalog: fakeCatalog(),
          initialId: initialId,
          audioService: audio,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'the pronunciation button plays the current phoneme through the audio service',
    (tester) async {
      final audio = FakeAudioService();
      await pumpDetail(tester, audio, initialId: 'c');

      expect(
        find.byKey(const ValueKey('audio-play')),
        findsOneWidget,
        reason:
            'the audio zone hosts the pronunciation button in the ready state',
      );

      await tester.tap(find.byKey(const ValueKey('audio-play')));
      expect(
        audio.calls,
        [('c', 'sound-c')],
        reason: 'play goes through the injected service with the phoneme id and its speakable text',
      );
    },
  );

  testWidgets('the button shows the loading state while audio prepares', (
    tester,
  ) async {
    final audio = FakeAudioService();
    await pumpDetail(tester, audio, initialId: 'c');

    audio.state.value = AudioPlaybackState.loading;
    await tester.pump();

    expect(
      find.byKey(const ValueKey('audio-loading')),
      findsOneWidget,
      reason: 'loading is one of the four fixed states (SDD)',
    );
    expect(
      find.byKey(const ValueKey('audio-play')),
      findsNothing,
      reason: 'the ready button is replaced while loading',
    );
  });

  testWidgets('the button shows the playing state while audio plays', (
    tester,
  ) async {
    final audio = FakeAudioService();
    await pumpDetail(tester, audio, initialId: 'c');

    audio.state.value = AudioPlaybackState.playing;
    await tester.pump();

    expect(
      find.byKey(const ValueKey('audio-playing')),
      findsOneWidget,
      reason: 'playing is one of the four fixed states (SDD)',
    );

    audio.state.value = AudioPlaybackState.ready;
    await tester.pump();
    expect(
      find.byKey(const ValueKey('audio-play')),
      findsOneWidget,
      reason: 'the button returns to the ready state after playback ends',
    );
  });

  testWidgets(
    'failure shows the fixed retry copy and tapping it retries playback',
    (tester) async {
      final audio = FakeAudioService();
      await pumpDetail(tester, audio, initialId: 'c');

      audio.state.value = AudioPlaybackState.failed;
      await tester.pump();

      expect(
        find.text('播放失败，重试'),
        findsOneWidget,
        reason: 'the fixed audio-failed copy (SDD Copy)',
      );

      await tester.tap(find.byKey(const ValueKey('audio-retry')));
      expect(
        audio.calls,
        [('c', 'sound-c')],
        reason:
            'tapping the retry copy invokes play again with the same request',
      );
    },
  );

  testWidgets('an audio failure does not block the other detail sections', (
    tester,
  ) async {
    final audio = FakeAudioService();
    await pumpDetail(tester, audio, initialId: 'c');

    audio.state.value = AudioPlaybackState.failed;
    await tester.pump();

    for (final zone in ['zone-mouth', 'zone-writing', 'zone-words']) {
      expect(
        find.byKey(ValueKey(zone)),
        findsOneWidget,
        reason: '$zone still renders while audio failed',
      );
    }

    await tester.tap(find.byKey(const ValueKey('switcher-circle-d')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('switcher-circle-d-selected')),
      findsOneWidget,
      reason: 'switcher navigation still works while audio failed',
    );
  });

  testWidgets('switching phonemes stops playback and resets the audio state', (
    tester,
  ) async {
    final audio = FakeAudioService();
    await pumpDetail(tester, audio, initialId: 'c');

    audio.state.value = AudioPlaybackState.playing;
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('switcher-circle-d')));
    await tester.pump();

    expect(
      audio.stopped,
      isTrue,
      reason: 'playback stops when the phoneme changes',
    );
    expect(
      audio.state.value,
      AudioPlaybackState.ready,
      reason: 'the button resets to the ready state for the new phoneme',
    );
  });
}
