import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';
import 'package:galatea/ui/detail/detail_page.dart';

/// Scripted fake: records the calls so tests assert the play contract without
/// any real browser TTS inside the fake-async zone.
class FakeAudioService implements AudioService {
  FakeAudioService() : state = ValueNotifier(AudioPlaybackState.ready);

  final List<(String, String)> calls = <(String, String)>[];

  @override
  final ValueNotifier<AudioPlaybackState> state;

  @override
  Future<void> play(String phonemeId, String speakText) async {
    calls.add((phonemeId, speakText));
  }

  @override
  void stop() {
    state.value = AudioPlaybackState.ready;
  }
}

/// A fake that reports failure on every play, for the wireframe P2 failure
/// branch.
class FailingAudioService implements AudioService {
  FailingAudioService() : state = ValueNotifier(AudioPlaybackState.ready);

  final List<(String, String)> calls = <(String, String)>[];

  @override
  final ValueNotifier<AudioPlaybackState> state;

  @override
  Future<void> play(String phonemeId, String speakText) async {
    calls.add((phonemeId, speakText));
    state.value = AudioPlaybackState.failed;
  }

  @override
  void stop() {
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

  Future<void> pumpApp(WidgetTester tester, AudioService audio) async {
    await tester.pumpWidget(
      GalateaApp(
        catalogFuture: Future.value(fakeCatalog()),
        correspondenceFuture: Future<CorrespondenceTable>.value(
          CorrespondenceTable(
            version: 'test-v1',
            sourceKind: 'test',
            sourceLabel: 'test source',
            sourceRefs: const [],
            mappings: const [],
          ),
        ),
        examplesFuture: Future<ExamplesData>.value(
          ExamplesData(
            version: 'test-v1',
            sourceLabel: 'test source',
            entries: const {},
          ),
        ),
        glyphsFuture: Future<GlyphData>.value(
          GlyphData(
            version: 'test-v1',
            sourceLabel: 'test source',
            entries: const {},
          ),
        ),
        audioService: audio,
      ),
    );
    await tester.pump();
    await tester.pump();
    // The practice tab's mastery initialization degrades to the
    // in-memory store after a short timeout when no platform backend
    // answers; pump past the timeout so no timer is left pending.
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> toggleReadingMode(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('reading-switch')));
    await tester.pump();
  }

  testWidgets(
    'the reading switch sits at the top right and the hint line stays hidden while off',
    (tester) async {
      await pumpApp(tester, FakeAudioService());

      expect(find.byKey(const ValueKey('reading-switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-hint')), findsNothing);
    },
  );

  testWidgets(
    'turning the switch on shows the fixed hint line and turning it off hides it',
    (tester) async {
      await pumpApp(tester, FakeAudioService());

      await toggleReadingMode(tester);
      expect(find.byKey(const ValueKey('reading-hint')), findsOneWidget);
      expect(find.text('直读模式：点按只发音'), findsOneWidget);

      await toggleReadingMode(tester);
      expect(find.byKey(const ValueKey('reading-hint')), findsNothing);
    },
  );

  testWidgets(
    'in reading mode tapping a phoneme plays its audio and stays on the chart',
    (tester) async {
      final audio = FakeAudioService();
      await pumpApp(tester, audio);

      await toggleReadingMode(tester);
      await tester.tap(find.byKey(const ValueKey('phoneme-a')));
      await tester.pump();

      expect(audio.calls, contains(('a', 'sound-a')));
      expect(find.byKey(const ValueKey('chart-grid')), findsOneWidget);
      expect(find.byType(DetailPage), findsNothing);
    },
  );

  testWidgets(
    'with the switch off tapping a phoneme opens the detail page as before',
    (tester) async {
      await pumpApp(tester, FakeAudioService());

      await tester.tap(find.byKey(const ValueKey('phoneme-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'a failed playback in reading mode shows the short failure notice and never opens the detail page',
    (tester) async {
      final audio = FailingAudioService();
      await pumpApp(tester, audio);

      await toggleReadingMode(tester);
      expect(find.byKey(const ValueKey('reading-hint')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('phoneme-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('播放失败，重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-hint')), findsOneWidget);
      expect(find.byType(DetailPage), findsNothing);
    },
  );
}
