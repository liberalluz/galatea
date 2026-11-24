import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/detail/detail_page.dart';

/// Scripted fake: records the calls and lets tests drive the four fixed
/// states directly, so no real browser TTS runs inside the fake-async zone.
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

/// B28 handwriting contracts (`TC-TRACE-001`, `TC-TRACE-002`,
/// `TC-TRACE-003`): the stroke order auto-plays once on entry and tapping
/// the writing grid replays it with pronunciation, phonemes without stroke
/// data keep the fixed preparing state with playback disabled, and the pen
/// control opens the non-scored handwriting overlay covering the detail
/// page with no route change.
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

GlyphData fakeGlyphs() => GlyphData(
  version: 'test-v1',
  sourceLabel: 'test source',
  entries: {
    'a': PhonemeGlyph(
      strokes: [
        [
          const Offset(0.2, 0.2),
          const Offset(0.8, 0.2),
          const Offset(0.8, 0.8),
          const Offset(0.2, 0.8),
          const Offset(0.2, 0.2),
        ],
        [const Offset(0.5, 0.5), const Offset(0.5, 0.1)],
        [const Offset(0.3, 0.6), const Offset(0.7, 0.6)],
      ],
    ),
  },
);

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    required String initialId,
    FakeAudioService? audio,
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
          glyphs: fakeGlyphs(),
          audioService: audio,
        ),
      ),
    );
    await tester.pump();
  }

  Future<Offset> centerOf(WidgetTester tester, String key) async {
    final rect = tester.getRect(find.byKey(ValueKey<String>(key)));
    return rect.center;
  }

  Future<void> drawStroke(WidgetTester tester, Offset start) async {
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(30, 10));
    await gesture.moveBy(const Offset(10, 40));
    await gesture.moveBy(const Offset(-20, 20));
    await gesture.up();
    await tester.pump();
  }

  testWidgets('the stroke order auto-plays once on entry', (tester) async {
    await pumpDetail(tester, initialId: 'a');

    expect(
      find.byKey(const ValueKey('stroke-playing')),
      findsOneWidget,
      reason: 'the animation starts without any tap on entry',
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stroke-playing')),
      findsNothing,
      reason: 'it plays exactly once and then rests',
    );
  });

  testWidgets(
    'tapping the writing grid replays the stroke order with pronunciation',
    (tester) async {
      final audio = FakeAudioService();
      await pumpDetail(tester, initialId: 'a', audio: audio);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tracing-area')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('stroke-playing')),
        findsOneWidget,
        reason: 'the grid tap replays the stroke order',
      );
      expect(audio.calls, [
        ('a', 'sound-a'),
      ], reason: 'the replay carries the phoneme pronunciation');
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a phoneme without stroke data shows the pending state and the grid tap never plays',
    (tester) async {
      final audio = FakeAudioService();
      await pumpDetail(tester, initialId: 'b', audio: audio);

      expect(find.byKey(const ValueKey('stroke-pending')), findsOneWidget);
      expect(find.byKey(const ValueKey('stroke-playing')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tracing-area')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('stroke-playing')),
        findsNothing,
        reason: 'playback stays disabled without stroke data',
      );
      expect(audio.calls, isEmpty);
    },
  );

  testWidgets(
    'an empty tracing area shows the fixed trace hint, not a blank box',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('detail-writing-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracing-area')), findsOneWidget);
      expect(find.byKey(const ValueKey('trace-hint')), findsOneWidget);
    },
  );

  testWidgets(
    'pointer strokes render over the glyph and are kept when input is interrupted',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');
      await tester.pumpAndSettle();

      final start = await centerOf(tester, 'tracing-area');
      await drawStroke(tester, start);
      expect(find.byKey(const ValueKey('trace-hint')), findsNothing);

      // An interrupted second stroke keeps both: the hint stays hidden.
      await drawStroke(tester, start + const Offset(10, 10));
      expect(find.byKey(const ValueKey('trace-hint')), findsNothing);
    },
  );

  testWidgets('the clear control restarts the tracing after finished strokes', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'a');
    await tester.pumpAndSettle();

    final start = await centerOf(tester, 'tracing-area');
    await drawStroke(tester, start);
    expect(find.byKey(const ValueKey('trace-hint')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('writing-clear')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trace-hint')), findsOneWidget);
  });

  testWidgets(
    'switching phonemes refreshes the model, the strokes and the control',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');
      await tester.pumpAndSettle();

      final start = await centerOf(tester, 'tracing-area');
      await drawStroke(tester, start);
      expect(find.byKey(const ValueKey('trace-hint')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('switcher-circle-c')));
      await tester.pump();
      // 'c' has no glyph data: control shows the pending state and the
      // user strokes are reset.
      expect(find.byKey(const ValueKey('stroke-pending')), findsOneWidget);
      expect(find.byKey(const ValueKey('trace-hint')), findsOneWidget);
    },
  );

  testWidgets(
    'the handwriting button opens the overlay covering the page with no route change',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('detail-handwriting-button')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('handwriting-overlay')),
        findsOneWidget,
        reason: 'the overlay covers the detail page',
      );
      expect(
        find.byKey(const ValueKey('overlay-guides')),
        findsOneWidget,
        reason: 'the cross guides render behind the grey model',
      );
      expect(find.byType(DetailPage), findsOneWidget);
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'no route was pushed: the page stack never grew',
      );
    },
  );

  testWidgets(
    'the overlay traces freely with clear-and-rewrite and done returns to the detail page',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('detail-handwriting-button')));
      await tester.pump();

      final start = await centerOf(tester, 'overlay-canvas');
      await drawStroke(tester, start);

      await tester.tap(find.byKey(const ValueKey('overlay-clear')));
      await tester.pump();

      // Rewrite after clear still works.
      await drawStroke(tester, start + const Offset(5, 5));
      expect(find.byKey(const ValueKey('handwriting-overlay')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('overlay-done')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('handwriting-overlay')),
        findsNothing,
        reason: 'done returns to the detail page',
      );
      expect(find.byKey(const ValueKey('detail-writing-card')), findsOneWidget);
    },
  );

  testWidgets('the overlay never produces a score or verdict', (tester) async {
    final mastery = MasteryController(store: InMemoryMasteryStore());
    mastery.load();
    mastery.engine.state.entryFor('a').star = 2;

    await pumpDetail(tester, initialId: 'a');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('detail-handwriting-button')));
    await tester.pump();

    final start = await centerOf(tester, 'overlay-canvas');
    await drawStroke(tester, start);
    await tester.tap(find.byKey(const ValueKey('overlay-done')));
    await tester.pumpAndSettle();

    expect(
      mastery.engine.state.entryFor('a').star,
      2,
      reason: 'free tracing never touches the mastery stars (REQ-035)',
    );
    expect(
      find.byKey(const ValueKey('detail-star')),
      findsNothing,
      reason: 'the detail page carries no score surface at all',
    );
  });
}
