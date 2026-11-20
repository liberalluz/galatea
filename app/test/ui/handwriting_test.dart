import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/detail/detail_page.dart';

/// B10 handwriting contracts (`TC-TRACE-001`, `TC-TRACE-002`,
/// `TC-CONTENT-002`): the tracing area accepts pointer strokes over the
/// handwritten glyph and keeps them when input is interrupted, the empty
/// area shows the fixed hint, the stroke-order control plays and replays,
/// and phonemes without stroke data show the fixed preparing state with
/// the control disabled, independent of the tracing area.
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

  testWidgets(
    'an empty tracing area shows the fixed trace hint, not a blank box',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      expect(find.byKey(const ValueKey('zone-writing')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracing-area')), findsOneWidget);
      expect(find.byKey(const ValueKey('trace-hint')), findsOneWidget);
    },
  );

  testWidgets(
    'pointer strokes render over the glyph and are kept when input is interrupted',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

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

    final start = await centerOf(tester, 'tracing-area');
    await drawStroke(tester, start);
    expect(find.byKey(const ValueKey('trace-hint')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('writing-clear')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trace-hint')), findsOneWidget);
  });

  testWidgets(
    'the stroke-order control plays stroke by stroke and can replay',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      expect(find.byKey(const ValueKey('stroke-play')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stroke-play')));
      await tester.pump();
      expect(find.byKey(const ValueKey('stroke-playing')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stroke-play')), findsOneWidget);

      // Replay.
      await tester.tap(find.byKey(const ValueKey('stroke-play')));
      await tester.pump();
      expect(find.byKey(const ValueKey('stroke-playing')), findsOneWidget);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a phoneme without stroke data shows the pending state with the control disabled, independent of the tracing area',
    (tester) async {
      await pumpDetail(tester, initialId: 'b');

      expect(find.byKey(const ValueKey('stroke-pending')), findsOneWidget);
      expect(find.byKey(const ValueKey('stroke-play')), findsNothing);
      // The tracing area stays usable without stroke data.
      expect(find.byKey(const ValueKey('trace-hint')), findsOneWidget);
      final start = await centerOf(tester, 'tracing-area');
      await drawStroke(tester, start);
      expect(find.byKey(const ValueKey('trace-hint')), findsNothing);
    },
  );

  testWidgets(
    'switching phonemes refreshes the model, the strokes and the control',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      expect(find.byKey(const ValueKey('stroke-play')), findsOneWidget);
      final start = await centerOf(tester, 'tracing-area');
      await drawStroke(tester, start);
      expect(find.byKey(const ValueKey('trace-hint')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('switcher-chip-c')));
      await tester.pump();
      // 'c' has no glyph data: control shows the pending state and the
      // user strokes are reset.
      expect(find.byKey(const ValueKey('stroke-pending')), findsOneWidget);
      expect(find.byKey(const ValueKey('trace-hint')), findsOneWidget);
    },
  );
}
