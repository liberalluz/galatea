import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/ui/detail/detail_page.dart';
import 'package:galatea/ui/practice/quiz_session.dart';

/// A service that reports failed from the first frame: the first-visit
/// offline shape (no synthesis available, no cache) per ux-flows R29.
class OfflineAudioService implements AudioService {
  @override
  final ValueNotifier<AudioPlaybackState> state = ValueNotifier(
    AudioPlaybackState.failed,
  );

  final List<String> plays = <String>[];

  @override
  Future<void> play(String phonemeId, String speakText) async {
    plays.add(phonemeId);
    state.value = AudioPlaybackState.failed;
  }

  @override
  void stop() {}
}

/// A listening-stem fake that fails every play request: the offline shape
/// with no cache and no synthesis (R29 failure branch).
class FailingStemService implements AudioService {
  FailingStemService() : state = ValueNotifier(AudioPlaybackState.ready);

  @override
  final ValueNotifier<AudioPlaybackState> state;

  @override
  Future<void> play(String phonemeId, String speakText) async {
    // Real providers move through `playing` before failing, so replay from
    // the failed state emits the transitions the ladder counts on.
    state.value = AudioPlaybackState.playing;
    state.value = AudioPlaybackState.failed;
  }

  @override
  void stop() {
    state.value = AudioPlaybackState.ready;
  }
}

void main() {
  group('zero network dependency (REQ-029, ux-flows R29)', () {
    test('the dependency set carries no network package', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final deps = pubspec.split('dev_dependencies:').first;
      final declared = RegExp(
        '^\\s+([a-z_]+):',
        multiLine: true,
      ).allMatches(deps).map((m) => m.group(1)!).toSet();
      const networkPackages = {
        'http',
        'dio',
        'connectivity_plus',
        'web_socket_channel',
        'grpc',
      };
      expect(
        declared.intersection(networkPackages),
        isEmpty,
        reason: 'network packages in pubspec dependencies',
      );
    });

    test('app/lib has no network client import', () {
      final offenders = <String>[];
      final patterns = [
        RegExp("import\\s+['\"]package:http/"),
        RegExp("import\\s+['\"]dart:io['\"]"),
        RegExp("import\\s+['\"]dart:html['\"]"),
        RegExp("import\\s+['\"]package:connectivity"),
        RegExp("import\\s+['\"]package:web_socket"),
      ];
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final text = file.readAsStringSync();
        for (final pattern in patterns) {
          if (pattern.hasMatch(text)) offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'network client imports in $offenders',
      );
    });
  });

  testWidgets(
    'a first-visit-offline detail page shows the retry state and the other sections keep working',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = await loadPhonemeCatalog();
      final entry = catalog.entries.first;
      await tester.pumpWidget(
        MaterialApp(
          home: DetailPage(
            catalog: catalog,
            initialId: entry.id,
            audioService: OfflineAudioService(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('audio-retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('audio-play')), findsNothing);
      // The rest of the page is unaffected (R29 failure branch: never
      // blocks the page).
      expect(find.byKey(const ValueKey('detail-page')), findsOneWidget);
      expect(find.text(entry.printGlyph), findsWidgets);
    },
  );

  testWidgets(
    'a first-visit-offline listening stem offers the ladder and the session advances',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final catalog = PhonemeCatalog(
        version: 'test',
        sourceLabel: 'test source',
        entries: [
          for (final glyph in ['a', 'b', 'c', 'd', 'e'])
            PhonemeCatalogEntry(
              id: 'p-$glyph',
              kind: PhonemeKind.vowel,
              group: 'front',
              printGlyph: glyph,
              tts: 'sound-$glyph',
            ),
        ],
      );
      final audio = FailingStemService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizSession(
              range: catalog.entries,
              catalog: catalog,
              taskType: 'listening',
              audioService: audio,
            ),
          ),
        ),
      );
      await tester.pump();

      // The stem starts in the ready state; the first play fails offline
      // and the R17 ladder takes over (replay, then skip).
      await tester.tap(find.byKey(const ValueKey('task-audio-play')));
      await tester.pump();
      expect(find.byKey(const ValueKey('task-audio-retry')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('task-audio-retry')));
      await tester.pump();
      expect(find.byKey(const ValueKey('task-preparing')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-skip')), findsOneWidget);

      // Skipping advances without counting the item as answered —
      // practice is never stuck offline (R29 failure branch).
      await tester.tap(find.byKey(const ValueKey('task-skip')));
      await tester.pump();
      final rate = tester
          .widget<Text>(find.byKey(const ValueKey('session-rate')))
          .data!;
      expect(rate, '0%', reason: 'a skipped item does not count as answered');
    },
  );
}
