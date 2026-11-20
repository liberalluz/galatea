import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Tall test viewport so the lazy ListView builds every category group.
  /// The catalog and correspondence table are loaded via [tester.runAsync]
  /// (real async IO) and injected, so the grid renders deterministically
  /// inside the fake-async test zone.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
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
    // The shell's mastery load degrades to the in-memory store after the
    // 150 ms timeout in a test environment; one more pump rebuilds the
    // body once the future settles.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('first launch shows KK as the default notation', (tester) async {
    await pumpApp(tester);

    final segmented = tester.widget<SegmentedButton<String>>(
      find.byKey(const ValueKey('notation-switch')),
    );
    expect(segmented.selected, [
      'kk',
    ], reason: 'KK is the default notation (REQ-003)');

    // KK glyphs: the KK 'e' prints as 'e' (DJ spells it 'eɪ').
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('phoneme-e')),
        matching: find.text('e'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'switching to DJ re-renders the symbols and keeps the selected phoneme',
    (tester) async {
      await pumpApp(tester);

      // Select a phoneme first (tap opens the detail route and marks it).
      await tester.tap(find.byKey(const ValueKey('phoneme-e')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('detail-page')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // The selection highlight survives the route round-trip.
      expect(find.byKey(const ValueKey('phoneme-e-selected')), findsOneWidget);

      // Switch to DJ: glyphs re-render, identities and selection stay.
      await tester.tap(find.text('DJ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('phoneme-e')),
          matching: find.text('eɪ'),
        ),
        findsOneWidget,
        reason: 'KK e prints as DJ eɪ',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('phoneme-i')),
          matching: find.text('iː'),
        ),
        findsOneWidget,
        reason: 'KK i prints as DJ iː',
      );
      expect(
        find.byKey(const ValueKey('phoneme-e-selected')),
        findsOneWidget,
        reason: 'the selected phoneme survives the notation switch',
      );
    },
  );

  testWidgets('switching to IPA re-renders IPA-only glyphs', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('IPA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // The shell's mastery load degrades to the in-memory store after the
    // 150 ms timeout in a test environment; one more pump rebuilds the
    // body once the future settles.
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('phoneme-g')),
        matching: find.text('ɡ'),
      ),
      findsOneWidget,
      reason: 'the IPA glyph uses the script letter ɡ, not the KK g',
    );
  });
}
