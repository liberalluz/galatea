import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/detail/detail_page.dart';

void main() {
  /// Nine fake vowel entries: the shared row model splits them 5 + 4, so
  /// the last row's actual count and the no-cross-row rule are both
  /// reachable without loading the bundled asset inside the fake-async
  /// test zone.
  PhonemeCatalog fakeCatalog() => PhonemeCatalog(
    version: 'test-v1',
    sourceLabel: 'test source',
    entries: [
      for (final glyph in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])
        PhonemeCatalogEntry(
          id: glyph,
          kind: PhonemeKind.vowel,
          group: 'front',
          printGlyph: glyph,
        ),
    ],
  );

  Future<void> pumpDetail(
    WidgetTester tester, {
    required String initialId,
  }) async {
    // Tall viewport so the lazy ListView builds every zone skeleton section.
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(catalog: fakeCatalog(), initialId: initialId),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'the circle switcher shows the tapped phoneme\'s row members and defaults to the tapped phoneme',
    (tester) async {
      await pumpDetail(tester, initialId: 'c');

      for (final glyph in ['a', 'b', 'c', 'd', 'e']) {
        expect(
          find.byKey(ValueKey('switcher-circle-$glyph')),
          findsOneWidget,
          reason: 'circle $glyph must be in the row switcher',
        );
      }
      expect(
        find.byKey(const ValueKey('switcher-circle-f')),
        findsNothing,
        reason: 'circles never cross into another row',
      );
      expect(
        find.byKey(const ValueKey('switcher-circle-c-selected')),
        findsOneWidget,
        reason: 'the switcher defaults to the tapped phoneme, not the row head',
      );
      expect(
        find.byKey(const ValueKey('switcher-circle-a-selected')),
        findsNothing,
      );
    },
  );

  testWidgets('the last row shows its actual count of circles (4, not 5)', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'g');

    for (final glyph in ['f', 'g', 'h', 'i']) {
      expect(find.byKey(ValueKey('switcher-circle-$glyph')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('switcher-circle-e')),
      findsNothing,
      reason: 'the last row carries four members, not a padded fifth',
    );
    expect(
      find.byKey(const ValueKey('switcher-circle-g-selected')),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping a circle moves the selection within the row and the ends do not wrap',
    (tester) async {
      await pumpDetail(tester, initialId: 'a');

      await tester.tap(find.byKey(const ValueKey('switcher-circle-e')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('switcher-circle-e-selected')),
        findsOneWidget,
        reason: 'tapping a member circle selects that member',
      );
      expect(
        find.byKey(const ValueKey('switcher-circle-f')),
        findsNothing,
        reason: 'the row end does not wrap into the next row',
      );
      for (final glyph in ['a', 'b', 'c', 'd']) {
        expect(find.byKey(ValueKey('switcher-circle-$glyph')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'the flat content flow keeps the fixed order: mapping row, writing card, pronunciation, examples',
    (tester) async {
      await pumpDetail(tester, initialId: 'c');

      double topOf(String key) =>
          tester.getTopLeft(find.byKey(ValueKey(key))).dy;
      expect(
        topOf('detail-mapping-row'),
        lessThan(topOf('detail-writing-card')),
        reason: 'the mapping row sits above the writing card',
      );
      expect(
        topOf('detail-writing-card'),
        lessThan(topOf('detail-audio-line')),
        reason: 'the pronunciation line sits right under the writing card',
      );
      expect(
        topOf('detail-audio-line'),
        lessThan(topOf('example-grid')),
        reason: 'the example grid closes the flow',
      );
      expect(
        find.byKey(const ValueKey('switcher-prev')),
        findsNothing,
        reason: 'the catalog-order arrows are gone',
      );
      expect(find.byKey(const ValueKey('switcher-next')), findsNothing);
    },
  );

  testWidgets('the flat flow drops the zone cards and the large glyph', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'c');

    expect(
      find.byKey(const ValueKey('detail-hero-glyph')),
      findsNothing,
      reason: 'the large glyph is replaced by the mapping row',
    );
    for (final zone in [
      'zone-mouth',
      'zone-writing',
      'zone-audio',
      'zone-words',
    ]) {
      expect(
        find.byKey(ValueKey(zone)),
        findsNothing,
        reason: '$zone loses its card shell',
      );
    }
    expect(
      find.byType(Card),
      findsNothing,
      reason: 'the flat content flow carries no card frames',
    );
  });
}
