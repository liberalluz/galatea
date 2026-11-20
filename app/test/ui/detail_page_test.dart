import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/detail/detail_page.dart';

void main() {
  /// Five fake entries so prev/next adjacency and both edges are reachable
  /// without loading the bundled asset inside the fake-async test zone.
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
    'the detail page shows the phoneme switcher strip with the current chip highlighted',
    (tester) async {
      await pumpDetail(tester, initialId: 'c');

      expect(find.byKey(const ValueKey('switcher-prev')), findsOneWidget);
      expect(find.byKey(const ValueKey('switcher-next')), findsOneWidget);
      for (final glyph in ['a', 'b', 'c', 'd', 'e']) {
        expect(
          find.byKey(ValueKey('switcher-chip-$glyph')),
          findsOneWidget,
          reason: 'chip $glyph must be in the strip',
        );
      }
      expect(
        find.byKey(const ValueKey('switcher-chip-c-selected')),
        findsOneWidget,
        reason: 'the current phoneme chip is highlighted',
      );
      expect(
        find.byKey(const ValueKey('switcher-chip-b-selected')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the detail page hosts the zone skeleton in the fixed section order',
    (tester) async {
      await pumpDetail(tester, initialId: 'c');

      final zoneKeys = [
        'zone-audio',
        'zone-mouth',
        'zone-writing',
        'zone-words',
      ];
      final foundKeys = find
          .byType(Card)
          .evaluate()
          .map((element) => element.widget.key)
          .whereType<ValueKey<String>>()
          .map((key) => key.value)
          .toList();

      expect(foundKeys, zoneKeys, reason: 'zones appear in the fixed order');
    },
  );

  testWidgets(
    'tapping next moves to the adjacent phoneme and refreshes every section',
    (tester) async {
      await pumpDetail(tester, initialId: 'b');

      await tester.tap(find.byKey(const ValueKey('switcher-next')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('switcher-chip-c-selected')),
        findsOneWidget,
        reason: 'next moves to the adjacent phoneme in catalog order',
      );
      expect(
        find.byKey(const ValueKey('switcher-chip-b-selected')),
        findsNothing,
      );

      // Every zone shows the new phoneme's glyph: all sections refreshed.
      for (final zone in [
        'zone-audio',
        'zone-mouth',
        'zone-writing',
        'zone-words',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(zone)),
            matching: find.text('c'),
          ),
          findsOneWidget,
          reason: '$zone refreshed to the new phoneme',
        );
      }
    },
  );

  testWidgets('prev is disabled at the first phoneme and does not wrap', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'a');

    final prev = tester.widget<IconButton>(
      find.byKey(const ValueKey('switcher-prev')),
    );
    expect(prev.onPressed, isNull, reason: 'prev is disabled at the first');

    await tester.tap(find.byKey(const ValueKey('switcher-prev')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('switcher-chip-a-selected')),
      findsOneWidget,
      reason: 'tapping disabled prev does not wrap around',
    );
  });

  testWidgets('next is disabled at the last phoneme and does not wrap', (
    tester,
  ) async {
    await pumpDetail(tester, initialId: 'e');

    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('switcher-next')),
    );
    expect(next.onPressed, isNull, reason: 'next is disabled at the last');

    await tester.tap(find.byKey(const ValueKey('switcher-next')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('switcher-chip-e-selected')),
      findsOneWidget,
      reason: 'tapping disabled next does not wrap around',
    );
  });
}
