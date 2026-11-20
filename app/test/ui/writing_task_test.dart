import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// B15 writing task contracts (`REQ-018`, `TC-QUIZ-004`, ux-flows R18):
/// the sample renders above and the tracing area stays blank below, an
/// empty submit shows the trace-first hint without a verdict, a close
/// trace produces ✓ and an off-shape trace produces × under the recorded
/// threshold, and any verdict enters the answered-at-least-once rule.
PhonemeCatalog fakeCatalog() => PhonemeCatalog(
  version: 'test-v1',
  sourceLabel: 'test source',
  entries: [
    PhonemeCatalogEntry(
      id: 'a',
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'a',
      tts: 'sound-a',
    ),
    PhonemeCatalogEntry(
      id: 'b',
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'b',
      tts: 'sound-b',
    ),
  ],
);

GlyphData fakeGlyphs() => GlyphData(
  version: 'test-v1',
  sourceLabel: 'test source',
  entries: {
    'a': PhonemeGlyph(
      strokes: [
        [const Offset(0.2, 0.5), const Offset(0.8, 0.5)],
      ],
    ),
  },
);

Future<void> pumpWriting(
  WidgetTester tester, {
  required String phonemeId,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final entry = fakeCatalog().entries.firstWhere((e) => e.id == phonemeId);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuizSession(
          range: [entry],
          catalog: fakeCatalog(),
          glyphs: fakeGlyphs(),
          taskType: 'writing',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Drags a horizontal stroke through the middle band of the tracing area
/// (along the model line at 0.5 of the glyph square).
Future<void> traceAlongModel(WidgetTester tester) async {
  final rect = tester.getRect(find.byKey(const ValueKey('task-tracing-area')));
  await tester.dragFrom(
    Offset(rect.left + rect.width * 0.25, rect.top + rect.height * 0.5),
    Offset(rect.width * 0.5, 0),
  );
  await tester.pump();
}

/// Drags a vertical stroke well off the model shape.
Future<void> traceOffShape(WidgetTester tester) async {
  final rect = tester.getRect(find.byKey(const ValueKey('task-tracing-area')));
  await tester.dragFrom(
    Offset(rect.left + rect.width * 0.2, rect.top + rect.height * 0.3),
    Offset(0, rect.height * 0.4),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the sample above and a blank tracing area', (
    tester,
  ) async {
    await pumpWriting(tester, phonemeId: 'a');
    expect(find.byKey(const ValueKey('writing-sample')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-tracing-area')), findsOneWidget);
    // The empty-state hint before any submit attempt is not the
    // trace-first guard; the area itself is blank (no faint model).
    expect(find.byKey(const ValueKey('trace-first')), findsNothing);
  });

  testWidgets('an empty submit shows the trace-first hint, no verdict', (
    tester,
  ) async {
    await pumpWriting(tester, phonemeId: 'a');
    await tester.tap(find.byKey(const ValueKey('task-submit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trace-first')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-feedback')), findsNothing);
    final rate = tester.widget<Text>(
      find.byKey(const ValueKey('session-rate')),
    );
    expect(rate.data, '0%');
  });

  testWidgets('a close trace produces ✓ and counts as answered', (
    tester,
  ) async {
    await pumpWriting(tester, phonemeId: 'a');
    await traceAlongModel(tester);
    await tester.tap(find.byKey(const ValueKey('task-submit')));
    await tester.pump();
    expect(find.text('回答正确'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('session-rate'))).data,
      '100%',
    );
  });

  testWidgets('an off-shape trace produces × and still counts as answered', (
    tester,
  ) async {
    await pumpWriting(tester, phonemeId: 'a');
    await traceOffShape(tester);
    await tester.tap(find.byKey(const ValueKey('task-submit')));
    await tester.pump();
    expect(find.text('回答错误'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('session-rate'))).data,
      '100%',
    );
  });

  testWidgets('a phoneme without stroke data renders the preparing state', (
    tester,
  ) async {
    await pumpWriting(tester, phonemeId: 'b');
    expect(find.byKey(const ValueKey('task-preparing')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-skip')), findsOneWidget);
  });
}
