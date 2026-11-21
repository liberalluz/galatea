import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run hint pins (`REQ-033`, skeleton S1, `B26`): the light banner
/// explains the two non-obvious interactions once; dismissing it is
/// permanent across restarts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      GalateaApp(
        catalogFuture: Future.value(
          PhonemeCatalog(
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
            ],
          ),
        ),
        correspondenceFuture: Future<CorrespondenceTable>.value(
          CorrespondenceTable(
            version: 'test-v1',
            sourceKind: 'test',
            sourceLabel: 'test source',
            sourceRefs: const [],
            mappings: const [],
          ),
        ),
        examplesFuture: Future<ExamplesData>.value(
          ExamplesData(
            version: 'test-v1',
            sourceLabel: 'test source',
            entries: const {},
          ),
        ),
        glyphsFuture: Future<GlyphData>.value(
          GlyphData(
            version: 'test-v1',
            sourceLabel: 'test source',
            entries: const {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the first launch shows the non-blocking hint banner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('first-run-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('first-run-hint-text')), findsOneWidget);
  });

  testWidgets('dismissing hides the banner immediately', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('first-run-dismiss')));
    await tester.pump();

    expect(find.byKey(const ValueKey('first-run-hint')), findsNothing);
  });

  testWidgets('a dismissed flag never shows the hint again', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'first-run-hint-dismissed': true,
    });
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('first-run-hint')), findsNothing);
  });

  testWidgets('the dismissal persists across a restart', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('first-run-dismiss')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Read back what the dismissal persisted — the same mock store a
    // restarted process would load.
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('first-run-hint-dismissed'),
      isTrue,
      reason: 'dismissing the hint is permanent (REQ-033)',
    );
  });
}
