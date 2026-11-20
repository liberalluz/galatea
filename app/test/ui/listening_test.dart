import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// Scripted fake: records the calls and lets tests drive the playback
/// states directly, so no real browser TTS runs inside the fake-async zone.
class ScriptedAudioService implements AudioService {
  ScriptedAudioService({this.failEvery = false});

  /// When true every `play` ends in the failed state (the R17 ladder).
  final bool failEvery;

  final List<(String, String)> calls = <(String, String)>[];

  @override
  final ValueNotifier<AudioPlaybackState> state = ValueNotifier(
    AudioPlaybackState.ready,
  );

  @override
  Future<void> play(String phonemeId, String speakText) async {
    calls.add((phonemeId, speakText));
    // Real providers move through `playing` before failing (or settling
    // back), so replay from the failed state emits the state transitions
    // the ladder counts on.
    state.value = AudioPlaybackState.playing;
    if (failEvery) state.value = AudioPlaybackState.failed;
  }

  @override
  void stop() {
    state.value = AudioPlaybackState.ready;
  }
}

/// Synthetic catalog: glyphs are unique per entry, mirroring the bundled
/// catalog where all 48 `kk` values differ.
PhonemeCatalog _catalog() => PhonemeCatalog(
  version: 'test',
  sourceLabel: 'test source',
  entries: [
    for (final glyph in ['a', 'b', 'c', 'd', 'e'])
      PhonemeCatalogEntry(
        id: 'p-$glyph',
        kind: PhonemeKind.vowel,
        group: 'front',
        printGlyph: glyph,
        tts: 'sound-$glyph',
      ),
  ],
);

List<PhonemeCatalogEntry> _range(PhonemeCatalog catalog) => catalog.entries;

Future<void> _pumpListening(
  WidgetTester tester,
  ScriptedAudioService audio,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final catalog = _catalog();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuizSession(
          range: _range(catalog),
          catalog: catalog,
          taskType: 'listening',
          audioService: audio,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'the listening task renders the play control and exactly 2 symbol options',
    (tester) async {
      final audio = ScriptedAudioService();
      await _pumpListening(tester, audio);

      expect(find.byKey(const ValueKey('task-audio-play')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-option-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-option-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-option-c')), findsNothing);
    },
  );

  testWidgets(
    'the play control drives the audio service with the phoneme id and speakable text',
    (tester) async {
      final audio = ScriptedAudioService();
      await _pumpListening(tester, audio);

      await tester.tap(find.byKey(const ValueKey('task-audio-play')));
      await tester.pump();

      expect(audio.calls, [('p-a', 'sound-a')]);
    },
  );

  testWidgets(
    'confirm stays disabled before a selection and the selected option highlights before confirm',
    (tester) async {
      final audio = ScriptedAudioService();
      await _pumpListening(tester, audio);

      final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('task-submit')),
      );
      expect(submit.onPressed, isNull, reason: 'nothing selected yet');

      await tester.tap(find.byKey(const ValueKey('task-option-a')));
      await tester.pump();

      final selected = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('task-option-a')),
      );
      final unselected = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('task-option-b')),
      );
      expect(
        selected.style?.backgroundColor,
        isNotNull,
        reason: 'the selection highlights before confirm',
      );
      expect(unselected.style?.backgroundColor, isNull);

      final enabled = tester.widget<FilledButton>(
        find.byKey(const ValueKey('task-submit')),
      );
      expect(enabled.onPressed, isNotNull);
    },
  );

  testWidgets(
    'answering the listening task correctly advances the session and shows the feedback',
    (tester) async {
      final audio = ScriptedAudioService();
      await _pumpListening(tester, audio);

      await tester.tap(find.byKey(const ValueKey('task-option-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-submit')));
      await tester.pump();

      expect(find.byKey(const ValueKey('session-feedback')), findsOneWidget);
      final rate = tester
          .widget<Text>(find.byKey(const ValueKey('session-rate')))
          .data!;
      expect(rate, '20%');
    },
  );

  testWidgets(
    'answering the listening task wrongly still advances the session',
    (tester) async {
      final audio = ScriptedAudioService();
      await _pumpListening(tester, audio);

      await tester.tap(find.byKey(const ValueKey('task-option-b')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-submit')));
      await tester.pump();

      expect(find.byKey(const ValueKey('session-feedback')), findsOneWidget);
      final rate = tester
          .widget<Text>(find.byKey(const ValueKey('session-rate')))
          .data!;
      expect(rate, '20%');
    },
  );

  testWidgets('a playback failure offers replay (ux-flows R17 first failure)', (
    tester,
  ) async {
    final audio = ScriptedAudioService(failEvery: true);
    await _pumpListening(tester, audio);

    await tester.tap(find.byKey(const ValueKey('task-audio-play')));
    await tester.pump();

    expect(find.byKey(const ValueKey('task-audio-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-preparing')), findsNothing);
  });

  testWidgets(
    'a repeated playback failure offers the skip control and skipping does not mark the item answered',
    (tester) async {
      final audio = ScriptedAudioService(failEvery: true);
      await _pumpListening(tester, audio);

      await tester.tap(find.byKey(const ValueKey('task-audio-play')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-audio-retry')));
      await tester.pump();

      expect(find.byKey(const ValueKey('task-preparing')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-skip')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('task-skip')));
      await tester.pump();

      expect(find.byKey(const ValueKey('session-feedback')), findsNothing);
      final rate = tester
          .widget<Text>(find.byKey(const ValueKey('session-rate')))
          .data!;
      expect(rate, '0%', reason: 'a skipped item does not count as answered');
    },
  );

  testWidgets(
    'a listening task without an audio service shows the fixed preparing state',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(
              range: _range(catalog),
              catalog: catalog,
              taskType: 'listening',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('task-preparing')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-skip')), findsOneWidget);
    },
  );
}
