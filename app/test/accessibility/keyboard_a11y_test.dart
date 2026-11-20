import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/chart/chart_page.dart';

/// Keyboard traversal runs in its own file: the traversal must start
/// from a clean isolate or the focus stays parked on the previous
/// test's modal scope (the same cross-test poisoning documented in the
/// offline behaviour batch).
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
  testWidgets('the keyboard focuses and activates a chart cell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();

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

    // Tab moves the focus onto a focusable control. Fixed pumps (not
    // pumpAndSettle) — the shell's mastery timeout keeps a pending
    // timer that never settles.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Clear any focus left behind by an earlier test in this isolate
    // before walking the traversal from a clean start.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    // Tab traversal walks the focus order — keep tabbing until the
    // focus lands on the target chart cell (the traversal passes
    // through the shell chrome first).
    const cellKey = ValueKey('phoneme-p-alpha');
    var cellFocused = false;
    for (var i = 0; i < 80; i++) {
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx != null) {
        final onCell = find.ancestor(
          of: find.byElementPredicate((e) => identical(e, ctx)),
          matching: find.byKey(cellKey),
        );
        if (onCell.evaluate().isNotEmpty) {
          cellFocused = true;
          break;
        }
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 50));
      debugPrint(
        'tab#$i '
        '${FocusManager.instance.primaryFocus?.context?.widget}',
      );
    }
    expect(cellFocused, isTrue, reason: 'tab traversal reaches the chart cell');
    // Enter activates the focused chart cell — the selection state
    // (the non-color marker key) flips through the keyboard.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('phoneme-p-alpha-selected')),
      findsOneWidget,
      reason: 'enter activates the focused chart cell',
    );
    handle.dispose();
  });
}
