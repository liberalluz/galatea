import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/detail/detail_page.dart';

/// B32 detail-page layout contracts (`REQ-036`, `TC-DETAIL-005`):
/// the member circles live in the top bar, one mapping row replaces the
/// duplicated hero glyph and the star row, the mouth slot shrinks beside
/// a larger writing card, the pronunciation control becomes an inline
/// line, and the example grid stretches to the bottom of the viewport.
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
          letters: glyph == 'c' ? 'ee' : glyph,
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

  Future<void> pumpDetail(
    WidgetTester tester, {
    required String initialId,
    ExamplesData? examples,
    Size size = const Size(1080, 12000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(
          catalog: fakeCatalog(),
          initialId: initialId,
          examples: examples ?? fakeExamples(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the member circles sit in the top bar, not in the page body', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    final circles = find.byKey(const ValueKey('switcher-circle-c'));
    expect(circles, findsOneWidget);

    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: circles),
      findsOneWidget,
      reason: 'the circles move into the top bar',
    );
  });

  testWidgets('the page no longer repeats the large hero glyph', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    expect(
      find.byKey(const ValueKey('detail-hero-glyph')),
      findsNothing,
      reason: 'the mapping row replaces the duplicated hero glyph',
    );
  });

  testWidgets('the mapping row shows the spelling fragment and the symbol', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    expect(find.byKey(const ValueKey('detail-mapping-row')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('detail-mapping-row')),
        matching: find.text('ee'),
      ),
      findsOneWidget,
      reason: 'the left chip carries the spelling fragment',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('detail-mapping-row')),
        matching: find.text('c'),
      ),
      findsOneWidget,
      reason: 'the right value carries the printed symbol',
    );
  });

  testWidgets('the detail page shows no star row and no unstarted label', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    expect(find.byKey(const ValueKey('detail-star')), findsNothing);
    expect(find.textContaining('未掌握'), findsNothing);
  });

  testWidgets('the mouth slot is a small card beside a larger writing card', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    final mouth = tester.getSize(
      find.byKey(const ValueKey('detail-mouth-card')),
    );
    final writing = tester.getSize(
      find.byKey(const ValueKey('detail-writing-card')),
    );

    expect(
      writing.width,
      greaterThan(mouth.width * 2),
      reason: 'the writing card is the dominant element',
    );
    expect(
      writing.height,
      greaterThan(mouth.height),
      reason: 'the mouth slot shrinks',
    );
  });

  testWidgets('the writing card carries the cross guides', (tester) async {
    await pumpDetail(tester, initialId: 'c');

    expect(find.byKey(const ValueKey('detail-writing-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-cross-guides')),
      findsOneWidget,
      reason: 'the writing card shows the cross guides',
    );
  });

  testWidgets('the pronunciation control renders as an inline line', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    expect(find.byKey(const ValueKey('detail-audio-line')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('detail-audio-button')),
      findsOneWidget,
      reason: 'the speaker button stays reachable',
    );
  });

  testWidgets('the example grid stretches to the bottom of the viewport', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c', size: const Size(390, 844));

    final grid = tester.getSize(find.byKey(const ValueKey('example-grid')));
    expect(
      grid.height,
      greaterThan(300),
      reason: 'the grid takes the remaining height instead of a fixed size',
    );
  });

  testWidgets('a word-form phoneme shows the word and never the sentence', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      initialId: 'a',
      examples: fakeExamples(displayForm: 'word'),
    );

    expect(find.text('a1'), findsOneWidget);
    expect(
      find.text('A a1 sentence.'),
      findsNothing,
      reason: 'the word and the sentence never render together',
    );
  });

  testWidgets('a sentence-form phoneme shows the sentence and never the word', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      initialId: 'a',
      examples: fakeExamples(displayForm: 'sentence'),
    );

    expect(find.text('A a1 sentence.'), findsOneWidget);
    expect(
      find.text('a1'),
      findsNothing,
      reason: 'the word and the sentence never render together',
    );
  });

  testWidgets('the handwriting control opens the overlay from the content', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    expect(find.byKey(const ValueKey('detail-pen')), findsNothing);
    expect(
      find.byKey(const ValueKey('detail-handwriting-button')),
      findsOneWidget,
      reason: 'the handwriting control moves off the top bar',
    );

    await tester.tap(find.byKey(const ValueKey('detail-handwriting-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('handwriting-overlay')), findsOneWidget);
  });
}
