import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/detail/detail_page.dart';

/// B9 media-section contracts (`TC-DETAIL-002`, `TC-DETAIL-003`,
/// `TC-CONTENT-003`): the mouth slot shows the fixed preparing placeholder
/// while the asset is missing, and the 2×2 example cards keep word/sentence
/// visible with a same-size image placeholder — cards are never hidden.
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

ExamplesData fakeExamples({String displayForm = 'word'}) {
  ExampleItem item(String word) =>
      ExampleItem(word: word, sentence: 'A $word sentence.', image: '');
  return ExamplesData(
    version: 'test-v1',
    sourceLabel: 'test source',
    entries: {
      for (final glyph in ['a', 'b', 'c', 'd', 'e'])
        glyph: PhonemeExamples(
          id: glyph,
          mouth: '',
          displayForm: displayForm,
          examples: [
            item('${glyph}1'),
            item('${glyph}2'),
            item('${glyph}3'),
            item('${glyph}4'),
          ],
        ),
    },
  );
}

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    required String initialId,
    String displayForm = 'word',
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
          examples: fakeExamples(displayForm: displayForm),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'the mouth zone shows the fixed preparing placeholder while the asset is missing',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      expect(find.byKey(const ValueKey('mouth-pending')), findsOneWidget);
      expect(find.text('口型图准备中'), findsOneWidget);
    },
  );

  testWidgets(
    'switching phonemes keeps the mouth placeholder and never shows another phoneme\'s image',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      await tester.tap(find.byKey(const ValueKey('switcher-circle-c')));
      await tester.pump();

      expect(find.byKey(const ValueKey('mouth-pending')), findsOneWidget);
    },
  );

  testWidgets(
    'the detail page shows exactly 4 example cards with the word only, never the sentence',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      expect(find.byKey(const ValueKey('example-grid')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('example-card-$i')), findsOneWidget);
      }
      for (var i = 1; i <= 4; i++) {
        expect(find.text('a$i'), findsOneWidget);
        expect(
          find.text('A a$i sentence.'),
          findsNothing,
          reason: 'the word form never shows the sentence as well (REQ-010)',
        );
      }
    },
  );

  testWidgets(
    'a phoneme in the sentence form shows the sentence only, never the word',
    (tester) async {
      await pumpDetail(tester, initialId: 'a', displayForm: 'sentence');

      for (var i = 1; i <= 4; i++) {
        expect(find.text('A a$i sentence.'), findsOneWidget);
        expect(
          find.text('a$i'),
          findsNothing,
          reason: 'the sentence form never shows the word as well (REQ-010)',
        );
      }
    },
  );

  testWidgets(
    'a card with a missing image keeps the word/sentence and shows the same-size placeholder',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      for (var i = 0; i < 4; i++) {
        expect(
          find.byKey(ValueKey('example-image-pending-$i')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('switching phonemes refreshes the four example cards', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'a');

    await tester.tap(find.byKey(const ValueKey('switcher-circle-b')));
    await tester.pump();

    expect(find.text('a1'), findsNothing);
    for (var i = 1; i <= 4; i++) {
      expect(find.text('b$i'), findsOneWidget);
    }
  });
}
