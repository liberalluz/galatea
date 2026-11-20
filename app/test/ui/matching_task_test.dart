import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// Scripted fake: records the play calls; playback never fails here (the
/// R17 ladder belongs to the listening task, not the matching task).
class RecordingAudioService implements AudioService {
  final List<(String, String)> calls = <(String, String)>[];

  @override
  final ValueNotifier<AudioPlaybackState> state = ValueNotifier(
    AudioPlaybackState.ready,
  );

  @override
  Future<void> play(String phonemeId, String speakText) async {
    calls.add((phonemeId, speakText));
    state.value = AudioPlaybackState.playing;
    state.value = AudioPlaybackState.ready;
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

/// Synthetic correspondence: one mapping per catalog entry, id-aligned.
CorrespondenceTable _correspondence() => CorrespondenceTable(
  version: 'test',
  sourceKind: 'test',
  sourceLabel: 'test source',
  sourceRefs: const <String>[],
  mappings: [
    for (final (glyph, dj) in [
      ('a', 'A'),
      ('b', 'B'),
      ('c', 'C'),
      ('d', 'D'),
      ('e', 'E'),
    ])
      CorrespondenceMapping(id: 'p-$glyph', kk: glyph, dj: dj, ipa: dj),
  ],
);

Future<RecordingAudioService> _pumpMatching(
  WidgetTester tester, {
  bool withCorrespondence = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final catalog = _catalog();
  final audio = RecordingAudioService();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuizSession(
          range: catalog.entries,
          catalog: catalog,
          taskType: 'matching',
          audioService: audio,
          correspondence: withCorrespondence ? _correspondence() : null,
        ),
      ),
    ),
  );
  await tester.pump();
  return audio;
}

/// Pairs the left item [leftId] with the right item carrying [dj].
Future<void> _pair(WidgetTester tester, String leftId, String dj) async {
  await tester.tap(find.byKey(ValueKey('task-pair-left-$leftId')));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey('task-pair-right-$dj')));
  await tester.pump();
}

Finder _left(String id) => find.byKey(ValueKey('task-pair-left-$id'));

Finder _right(String dj) => find.byKey(ValueKey('task-pair-right-$dj'));

String _rate(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('session-rate'))).data!;

void main() {
  testWidgets(
    'the matching task renders three play controls and three symbols with no grey items',
    (tester) async {
      await _pumpMatching(tester);

      expect(_left('p-a'), findsOneWidget);
      expect(_left('p-b'), findsOneWidget);
      expect(_left('p-c'), findsOneWidget);
      expect(_right('A'), findsOneWidget);
      expect(_right('B'), findsOneWidget);
      expect(_right('C'), findsOneWidget);
      // ux-flows R19 empty state: no pre-connected pairs, nothing inert.
      for (final dj in ['A', 'B', 'C']) {
        final button = tester.widget<OutlinedButton>(_right(dj));
        expect(button.onPressed, isNotNull);
      }
    },
  );

  testWidgets(
    'playing a left item drives the audio service with the phoneme id and speakable text',
    (tester) async {
      final audio = await _pumpMatching(tester);

      await tester.tap(_left('p-a'));
      await tester.pump();

      expect(audio.calls, contains(('p-a', 'sound-a')));
    },
  );

  testWidgets('a correct pair greys out and cannot be re-paired', (
    tester,
  ) async {
    await _pumpMatching(tester);

    await _pair(tester, 'p-a', 'A');
    await tester.pump();

    final left = tester.widget<OutlinedButton>(_left('p-a'));
    final right = tester.widget<OutlinedButton>(_right('A'));
    expect(left.onPressed, isNull, reason: 'greyed items are inert');
    expect(right.onPressed, isNull, reason: 'greyed items are inert');
    // One paired item does not complete the task yet.
    expect(_rate(tester), '0%');
  });

  testWidgets(
    'a mispair snaps back without counting as completion (ux-flows R19 failure branch)',
    (tester) async {
      await _pumpMatching(tester);

      await _pair(tester, 'p-a', 'B');
      await tester.pump();

      // Both items return to the tappable state and the mispair neither
      // greys out nor advances the session.
      final left = tester.widget<OutlinedButton>(_left('p-a'));
      final right = tester.widget<OutlinedButton>(_right('B'));
      expect(left.onPressed, isNotNull);
      expect(right.onPressed, isNotNull);
      expect(_rate(tester), '0%');
      expect(find.byKey(const ValueKey('session-feedback')), findsNothing);
    },
  );

  testWidgets('pairing all 3 pairs reports completion and advances', (
    tester,
  ) async {
    await _pumpMatching(tester);

    await _pair(tester, 'p-a', 'A');
    await _pair(tester, 'p-b', 'B');
    await _pair(tester, 'p-c', 'C');
    await tester.pump();

    // The item counts as answered and the session moves to the next
    // phoneme, whose pair set re-renders (B12 answered-at-least-once).
    expect(_rate(tester), '20%');
    expect(find.byKey(const ValueKey('session-feedback')), findsOneWidget);
    expect(_left('p-b'), findsOneWidget);
    expect(_left('p-d'), findsOneWidget);
  });

  testWidgets('renders the preparing state without the correspondence table', (
    tester,
  ) async {
    await _pumpMatching(tester, withCorrespondence: false);

    expect(find.byKey(const ValueKey('task-preparing')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-skip')), findsOneWidget);
  });
}
