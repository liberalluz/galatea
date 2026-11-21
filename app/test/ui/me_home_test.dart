import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/me/me_page.dart';

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

MasteryController freshController() {
  final controller = MasteryController(store: InMemoryMasteryStore());
  controller.load();
  return controller;
}

Future<void> pumpMe(WidgetTester tester, MasteryController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MePage(
          catalogFuture: Future.value(fakeCatalog()),
          masteryController: controller,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'the home shows the statistics card and the three drill-down entries',
    (tester) async {
      await pumpMe(tester, freshController());

      expect(find.byKey(const ValueKey('me-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('entry-review')), findsOneWidget);
      expect(find.byKey(const ValueKey('entry-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('entry-about')), findsOneWidget);
      // The statistics card keeps its fixed rows and denominator.
      expect(find.byKey(const ValueKey('me-total')), findsOneWidget);
    },
  );

  testWidgets(
    'the review status strip shows the due count and hides when none is due',
    (tester) async {
      final controller = freshController();
      await pumpMe(tester, controller);

      // Nothing due: the strip is hidden (REQ-032).
      expect(find.byKey(const ValueKey('me-review-strip')), findsNothing);

      // Two entries due now: the strip shows with the due count.
      final now = DateTime.now();
      for (final id in ['a', 'b']) {
        controller.engine.state.entryFor(id).due = now.subtract(
          const Duration(minutes: 30),
        );
      }
      await pumpMe(tester, controller);
      expect(find.byKey(const ValueKey('me-review-strip')), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
    },
  );

  testWidgets('the review entry opens the review drill-down', (tester) async {
    await pumpMe(tester, freshController());

    await tester.tap(find.byKey(const ValueKey('entry-review')));
    await tester.pump();
    await tester.pump();

    // The empty queue page is the review drill-down landing.
    expect(find.byKey(const ValueKey('review-empty')), findsOneWidget);
  });
}
