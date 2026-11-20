import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/chart/chart_page.dart';

/// The shell-level accessibility pins run in their own file: the
/// GalateaApp harness must be the first widget tests of their isolate
/// or the shared shell state poisons the run (the same cross-test
/// poisoning documented in the offline behaviour batch).
PhonemeCatalog _catalog() => PhonemeCatalog(
  version: 'test',
  sourceLabel: 'test source',
  entries: [
    PhonemeCatalogEntry(
      id: 'p-alpha',
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'ɑα',
      tts: 'sound-alpha',
    ),
    PhonemeCatalogEntry(
      id: 'p-beta',
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'ββ',
      tts: 'sound-beta',
    ),
    PhonemeCatalogEntry(
      id: 'p-gamma',
      kind: PhonemeKind.consonant,
      group: 'plosive',
      printGlyph: 'γγ',
      tts: '',
    ),
  ],
);

void main() {
  group('shell accessibility (TC-QUAL-004, REQ-030)', () {
    testWidgets('a chart cell reads the phoneme spoken text', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();

      // ChartPage directly: the shell (GalateaApp) carries per-isolate
      // load timers, so this file pumps the grid page only — the shell
      // harness stays in the shell test file.
      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartPage(
              catalogFuture: Future.value(catalog),
              correspondenceFuture: null,
              examplesFuture: null,
              glyphsFuture: null,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));

      final node = tester.getSemantics(
        find.byKey(const ValueKey('phoneme-p-alpha')),
      );
      expect(
        node.label,
        'sound-alpha',
        reason: 'the chart cell reads the spoken text',
      );
      handle.dispose();
    });
  });
}
