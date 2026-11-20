import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/detail/detail_page.dart';

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
        ),
    ],
  );

  MasteryController controller({bool degraded = false}) {
    final controller = MasteryController(store: InMemoryMasteryStore());
    controller.degraded = degraded;
    controller.load();
    return controller;
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required String initialId,
    MasteryController? mastery,
  }) async {
    // Tall viewport so the lazy ListView builds every zone skeleton section.
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: DetailPage(
          catalog: fakeCatalog(),
          initialId: initialId,
          mastery: mastery,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the detail page shows the phoneme star rating from the shared '
      'controller', (tester) async {
    final mastery = controller();
    mastery.engine.state.entryFor('c').star = 2;
    await pumpDetail(tester, initialId: 'c', mastery: mastery);

    expect(
      find.byKey(const ValueKey('detail-star')),
      findsOneWidget,
      reason: 'the R23 entry surface 2 shows the 0–3 star rating',
    );
    final row = tester.widget<Row>(find.byKey(const ValueKey('detail-star')));
    final filled = row.children
        .whereType<Icon>()
        .where((icon) => icon.icon == Icons.star)
        .length;
    final hollow = row.children
        .whereType<Icon>()
        .where((icon) => icon.icon == Icons.star_border)
        .length;
    expect(filled, 2, reason: 'two of the three star positions fill');
    expect(hollow, 1);
    expect(find.textContaining('学习中'), findsOneWidget);
  });

  testWidgets('a never-practiced phoneme reads 0 stars', (tester) async {
    await pumpDetail(tester, initialId: 'c', mastery: controller());

    final row = tester.widget<Row>(find.byKey(const ValueKey('detail-star')));
    final filled = row.children
        .whereType<Icon>()
        .where((icon) => icon.icon == Icons.star)
        .length;
    expect(filled, 0);
    expect(find.textContaining('未掌握'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('star-degraded')),
      findsNothing,
      reason: 'a healthy in-memory controller is not a degraded state',
    );
  });

  testWidgets('a degraded mastery state shows the fixed marker instead of '
      'inventing stars', (tester) async {
    final mastery = controller(degraded: true);
    mastery.engine.state.entryFor('c').star = 2;
    await pumpDetail(tester, initialId: 'c', mastery: mastery);

    final row = tester.widget<Row>(find.byKey(const ValueKey('detail-star')));
    final filled = row.children
        .whereType<Icon>()
        .where((icon) => icon.icon == Icons.star)
        .length;
    expect(
      filled,
      0,
      reason: 'the R23 failure branch: 0 stars, never inventing them',
    );
    expect(
      find.byKey(const ValueKey('star-degraded')),
      findsOneWidget,
      reason: 'the fixed 数据待同步 marker shows on the degraded state',
    );
  });

  testWidgets('without a controller the star row stays absent', (tester) async {
    await pumpDetail(tester, initialId: 'c');

    expect(find.byKey(const ValueKey('detail-star')), findsNothing);
  });
}
