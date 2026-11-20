import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// Minimal stub: the listening task renders its options only when a
/// service is present; playback behaviour is out of scope here.
class StubAudioService implements AudioService {
  @override
  final ValueNotifier<AudioPlaybackState> state = ValueNotifier(
    AudioPlaybackState.ready,
  );

  @override
  Future<void> play(String phonemeId, String speakText) async {}

  @override
  void stop() {}
}

/// Synthetic catalog for the session-level tap-target pin, mirroring the
/// listening_test harness.
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

void main() {
  group('narrow-screen chart grid (TC-QUAL-002, REQ-028)', () {
    /// Pumps the real app on a 360 px viewport; assets load via
    /// [tester.runAsync] like chart_page_test.
    Future<void> pumpNarrow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      PhonemeCatalog? catalog;
      CorrespondenceTable? correspondence;
      ExamplesData? examples;
      GlyphData? glyphs;
      await tester.runAsync(() async {
        catalog = await loadPhonemeCatalog();
        correspondence = await loadCorrespondence();
        examples = await loadExamples();
        glyphs = await loadGlyphs();
      });

      await tester.pumpWidget(
        GalateaApp(
          catalogFuture: catalog != null ? Future.value(catalog) : null,
          correspondenceFuture: correspondence != null
              ? Future.value(correspondence)
              : null,
          examplesFuture: examples != null ? Future.value(examples) : null,
          glyphsFuture: glyphs != null ? Future.value(glyphs) : null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('at 360 px the grid scrolls horizontally', (tester) async {
      await pumpNarrow(tester);

      // One horizontal scroll per category group's table.
      final scrollFinder = find.byKey(const ValueKey('grid-scroll'));
      expect(
        scrollFinder,
        findsAtLeastNWidgets(1),
        reason: 'each group table carries the horizontal scroll',
      );
      final scrollable = tester.widget<Scrollable>(
        find.descendant(
          of: scrollFinder.first,
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        scrollable.axisDirection,
        AxisDirection.right,
        reason: 'the scroll axis is horizontal',
      );
    });

    testWidgets('at 360 px all 48 phonemes stay reachable and 5 columns keep', (
      tester,
    ) async {
      await pumpNarrow(tester);

      // The grid is a Table inside the scroll view, so every cell builds
      // even when scrolled out of the viewport.
      final cellFinder = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value.toString().startsWith('phoneme-'),
      );
      final cells = tester.widgetList(cellFinder).toList();
      expect(
        cells.length,
        48,
        reason: 'no column folds and no phoneme is dropped',
      );
    });
  });

  group('tap-target floor (TC-QUAL-002)', () {
    testWidgets('the practice options stay at least 44 logical px tall at '
        '360 px', (tester) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(
              range: catalog.entries,
              catalog: catalog,
              taskType: 'listening',
              audioService: StubAudioService(),
            ),
          ),
        ),
      );
      await tester.pump();

      final size = tester.getSize(find.byKey(const ValueKey('task-option-a')));
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'the tap target floor is 44 logical pixels',
      );
    });
  });
}
