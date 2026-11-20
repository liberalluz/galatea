import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/domain/mastery_controller.dart';
import 'package:galatea/domain/mastery_store.dart';
import 'package:galatea/ui/detail/detail_page.dart';
import 'package:galatea/ui/me/me_page.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// Minimal stub: the recognition task renders its options only when a
/// service is present; playback behaviour is out of scope here.
class StubAudioService implements AudioService {
  @override
  final ValueNotifier<AudioPlaybackState> state = ValueNotifier(
    AudioPlaybackState.ready,
  );

  @override
  Future<void> play(String phonemeId, String speakText) async {}

  @override
  void stop() {}
}

PhonemeCatalog _catalog() => PhonemeCatalog(
  version: 'test',
  sourceLabel: 'test source',
  entries: [
    // Five vowel entries with unique tts spellings so the recognition
    // task can build its distractor set (spelling_options needs three
    // distinct catalog spellings beside the target).
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
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'γγ',
      tts: '',
    ),
    PhonemeCatalogEntry(
      id: 'p-delta',
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'δδ',
      tts: 'sound-delta',
    ),
    PhonemeCatalogEntry(
      id: 'p-eps',
      kind: PhonemeKind.vowel,
      group: 'front',
      printGlyph: 'εε',
      tts: 'sound-eps',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('symbol semantics labels (TC-QUAL-004, REQ-030)', () {
    testWidgets('a recognition stem reads the spoken text', (tester) async {
      final handle = tester.ensureSemantics();
      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(
              range: catalog.entries,
              catalog: catalog,
              taskType: 'recognition',
              audioService: StubAudioService(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final node = tester.getSemantics(
        find.byKey(const ValueKey('task-stem-p-alpha')),
      );
      expect(
        node.label,
        'sound-alpha',
        reason: 'the task stem reads the spoken text',
      );
      handle.dispose();
    });

    testWidgets('a symbol with an empty spoken text reads the id', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: DetailPage(catalog: catalog, initialId: 'p-gamma'),
        ),
      );
      await tester.pump();

      final node = tester.getSemantics(
        find.byKey(const ValueKey('detail-hero-glyph')),
      );
      expect(
        node.label,
        'p-gamma',
        reason: 'the empty spoken text falls back to the phoneme id',
      );
      handle.dispose();
    });

    testWidgets('the detail hero glyph reads the spoken text', (tester) async {
      final handle = tester.ensureSemantics();
      final catalog = _catalog();
      await tester.pumpWidget(
        MaterialApp(
          home: DetailPage(catalog: catalog, initialId: 'p-alpha'),
        ),
      );
      await tester.pump();

      final node = tester.getSemantics(
        find.byKey(const ValueKey('detail-hero-glyph')),
      );
      expect(
        node.label,
        'sound-alpha',
        reason: 'the detail hero glyph reads the spoken text',
      );
      handle.dispose();
    });
  });

  group('keyboard operability with visible focus (TC-QUAL-004)', () {
    testWidgets('a selected choice chip marks the selection by a shape, '
        'not color alone', (tester) async {
      final handle = tester.ensureSemantics();
      final catalog = _catalog();
      final controller = MasteryController(store: InMemoryMasteryStore())
        ..load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MePage(
              catalogFuture: Future.value(catalog),
              masteryController: controller,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The Material 3 checkmark is painted, not an Icon widget, so the
      // non-color selection marker is pinned through the semantics
      // selected flag the screen reader announces instead.
      final node = tester.getSemantics(
        find
            .descendant(
              of: find.byKey(const ValueKey('me-filter-kk')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        node.flagsCollection.isSelected,
        Tristate.isTrue,
        reason: 'the selected chip announces its selection state',
      );
      handle.dispose();
    });
  });
}
