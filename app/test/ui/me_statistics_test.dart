import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/me/me_page.dart';
import 'package:galatea/ui/shell/shell_page.dart';

/// A 48-entry catalog so the statistics denominator is pinned at 48
/// (`TC-REVIEW-002`).
PhonemeCatalog _catalog() => PhonemeCatalog(
  version: 'test',
  sourceLabel: 'test source',
  entries: [
    for (var i = 0; i < 48; i++)
      PhonemeCatalogEntry(
        id: 'p-$i',
        kind: PhonemeKind.vowel,
        group: 'front',
        printGlyph: 'g$i',
        tts: 'sound-$i',
      ),
  ],
);

MasteryController _controller() {
  final controller = MasteryController(store: InMemoryMasteryStore());
  controller.load();
  return controller;
}

/// Stars [id] at [star] in the fixture controller's engine state.
void _star(MasteryController controller, String id, int star) {
  controller.engine.state.entryFor(id).star = star;
}

Future<void> _pumpMe(
  WidgetTester tester, {
  required MasteryController controller,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MePage(
          catalogFuture: Future.value(_catalog()),
          masteryController: controller,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Finder _row(String key) => find.byKey(ValueKey(key));

/// The count text inside a summary row reads "N 音位".
int _countOf(WidgetTester tester, String rowKey) {
  final text = tester
      .widget<Text>(
        find.descendant(of: _row(rowKey), matching: find.textContaining('音位')),
      )
      .data!;
  return int.parse(text.split(' ').first);
}

void main() {
  testWidgets(
    'the statistics rows count over the 48 denominator per wireframe P5',
    (tester) async {
      final controller = _controller();
      _star(controller, 'p-0', 3);
      _star(controller, 'p-1', 1);
      await _pumpMe(tester, controller: controller);

      expect(_row('me-row-mastered'), findsOneWidget);
      expect(_row('me-row-learning'), findsOneWidget);
      expect(_row('me-row-unstarted'), findsOneWidget);
      expect(_countOf(tester, 'me-row-mastered'), 1);
      expect(_countOf(tester, 'me-row-learning'), 1);
      expect(_countOf(tester, 'me-row-unstarted'), 46);
      expect(
        find.byKey(const ValueKey('me-total')),
        findsOneWidget,
        reason: 'the total line pins the 48 denominator',
      );
      expect(
        find.textContaining('48'),
        findsWidgets,
        reason: 'the denominator reads 48, never multiplied by notation',
      );
    },
  );

  testWidgets('the KK/DJ/IPA filter chips switch the display notation without '
      'changing the counts', (tester) async {
    final controller = _controller();
    _star(controller, 'p-0', 3);
    _star(controller, 'p-1', 1);
    await _pumpMe(tester, controller: controller);

    expect(_countOf(tester, 'me-row-mastered'), 1);
    expect(_countOf(tester, 'me-row-learning'), 1);
    expect(_countOf(tester, 'me-row-unstarted'), 46);

    for (final notation in ['dj', 'ipa']) {
      await tester.tap(find.byKey(ValueKey('me-filter-$notation')));
      await tester.pump();
      expect(
        _countOf(tester, 'me-row-mastered'),
        1,
        reason: 'the filter is display-only: the counts stay identical',
      );
      expect(_countOf(tester, 'me-row-learning'), 1);
      expect(_countOf(tester, 'me-row-unstarted'), 46);
    }
  });

  testWidgets('with no practice records every row reads 0 and the fixed notice '
      'shows', (tester) async {
    final controller = _controller();
    await _pumpMe(tester, controller: controller);

    expect(_countOf(tester, 'me-row-mastered'), 0);
    expect(_countOf(tester, 'me-row-learning'), 0);
    expect(_countOf(tester, 'me-row-unstarted'), 48);
    expect(
      find.byKey(const ValueKey('me-empty-notice')),
      findsOneWidget,
      reason: 'the R23 empty state shows the fixed notice',
    );
  });

  testWidgets('a live record reflects in the statistics without a reload', (
    tester,
  ) async {
    final controller = _controller();
    await _pumpMe(tester, controller: controller);

    expect(find.byKey(const ValueKey('me-empty-notice')), findsOneWidget);

    await controller.record('p-3', true);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('me-empty-notice')),
      findsNothing,
      reason: 'the shared controller notifies the statistics in place',
    );
    expect(_countOf(tester, 'me-row-learning'), 1);
    expect(_countOf(tester, 'me-row-unstarted'), 47);
  });

  testWidgets('the shell Me tab renders the statistics page', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = _controller();
    _star(controller, 'p-0', 3);
    await tester.pumpWidget(
      MaterialApp(
        home: ShellPage(
          catalogFuture: Future.value(_catalog()),
          masteryFuture: Future.value(controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey('tab-me')));
    await tester.pump();

    expect(_row('me-row-mastered'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('me-filter-kk')),
      findsOneWidget,
      reason: 'the shell hands its controller to the Me tab',
    );
  });
}
