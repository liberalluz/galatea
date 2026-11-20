import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/content/spelling_options.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// Synthetic catalogs for the recognition task: spellings are unique per
/// entry, mirroring the bundled catalog where all 48 `tts` values differ.
PhonemeCatalog _catalog({List<String>? spellings}) {
  final values = spellings ?? ['ae', 'bee', 'cee', 'dee', 'eef'];
  return PhonemeCatalog(
    version: 'test',
    sourceLabel: 'test source',
    entries: [
      for (var i = 0; i < values.length; i++)
        PhonemeCatalogEntry(
          id: 'p$i',
          kind: PhonemeKind.vowel,
          group: 'front',
          printGlyph: '/${values[i]}/',
          tts: values[i],
        ),
    ],
  );
}

List<PhonemeCatalogEntry> _range(PhonemeCatalog catalog) => catalog.entries;

void main() {
  test('the spelling options are the phoneme spelling plus the next three distinct catalog spellings, exactly 1 correct', () {
    final catalog = _catalog();
    final options = buildSpellingOptions(catalog.entries[0], catalog);

    expect(options, isNotNull);
    expect(options!.options.length, 4);
    expect(options.options.toSet().length, 4);
    expect(options.correct, 'ae');
    expect(
      options.options.where((option) => option == options.correct).length,
      1,
    );
    expect(options.options, ['ae', 'bee', 'cee', 'dee']);
  });

  test(
    'the spelling options wrap around the catalog order deterministically',
    () {
      final catalog = _catalog();
      final options = buildSpellingOptions(catalog.entries[3], catalog);

      expect(options, isNotNull);
      expect(options!.options, ['dee', 'eef', 'ae', 'bee']);
    },
  );

  test('a catalog with fewer than 4 distinct spellings yields no options', () {
    final catalog = _catalog(spellings: ['ae', 'bee', 'cee']);
    expect(buildSpellingOptions(catalog.entries[0], catalog), isNull);
  });

  testWidgets(
    'the recognition task renders the print stem and exactly 4 options',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(range: _range(catalog), catalog: catalog),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('task-stem-p0')), findsOneWidget);
      expect(find.text('/ae/'), findsOneWidget);
      final optionKeys = <String>{
        'task-option-ae',
        'task-option-bee',
        'task-option-cee',
        'task-option-dee',
      };
      for (final key in optionKeys) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
    },
  );

  testWidgets(
    'answering the recognition task correctly advances the session and shows the feedback',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(range: _range(catalog), catalog: catalog),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('session-rate')).toString(),
        contains('0%'),
      );

      await tester.tap(find.byKey(const ValueKey('task-option-ae')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-submit')));
      await tester.pump();

      expect(find.byKey(const ValueKey('session-feedback')), findsOneWidget);
      final rate = tester
          .widget<Text>(find.byKey(const ValueKey('session-rate')))
          .data!;
      expect(rate, '20%');
    },
  );

  testWidgets(
    'answering the recognition task wrongly still advances the session',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(range: _range(catalog), catalog: catalog),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('task-option-bee')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('task-submit')));
      await tester.pump();

      expect(find.byKey(const ValueKey('session-feedback')), findsOneWidget);
      final rate = tester
          .widget<Text>(find.byKey(const ValueKey('session-rate')))
          .data!;
      expect(rate, '20%');
    },
  );

  testWidgets(
    'a phoneme without enough distinct spellings shows the fixed preparing state with a skip control',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = _catalog(spellings: ['ae', 'bee', 'cee']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(range: _range(catalog), catalog: catalog),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('task-preparing')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-skip')), findsOneWidget);
    },
  );
}
