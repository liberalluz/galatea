import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/audio/audio_service.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/content/examples.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';
import 'package:galatea/main.dart';
import 'package:galatea/settings/settings_controller.dart';
import 'package:galatea/ui/detail/detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted fake: records the calls so tests assert the play contract.
class FakeAudioService implements AudioService {
  FakeAudioService() : state = ValueNotifier(AudioPlaybackState.ready);

  final List<(String, String)> calls = <(String, String)>[];

  @override
  final ValueNotifier<AudioPlaybackState> state;

  @override
  Future<void> play(String phonemeId, String speakText) async {
    calls.add((phonemeId, speakText));
  }

  @override
  void stop() {
    state.value = AudioPlaybackState.ready;
  }
}

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

Future<SharedPreferences> mockPrefs([Map<String, Object> initial = const {}]) {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

/// Pumps the full app with an injectable settings controller and prefs,
/// pumped past the mastery degradation timeout so no timer stays pending.
Future<void> pumpApp(
  WidgetTester tester, {
  required SettingsController settings,
  required Future<SharedPreferences> prefs,
  AudioService? audio,
}) async {
  await tester.pumpWidget(
    GalateaApp(
      catalogFuture: Future.value(fakeCatalog()),
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
      audioService: audio,
      settingsController: settings,
      settingsFuture: prefs,
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Opens the settings page: Me tab, then the settings entry.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-me')));
  await tester.pump();
  await tester.pump();
  expect(find.byKey(const ValueKey('entry-settings')), findsOneWidget);
  await tester.ensureVisible(find.byKey(const ValueKey('entry-settings')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('entry-settings')));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'switching to English applies to all copy immediately without a restart',
    (tester) async {
      final settings = SettingsController();
      await pumpApp(tester, settings: settings, prefs: mockPrefs());

      await openSettings(tester);
      expect(find.text('设置'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('language-option-en')));
      await tester.pump();

      // Immediate: the settings page itself re-renders in English on the
      // same frame the switch happens.
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('设置'), findsNothing);

      // And the routes below the drill-down re-render too: the bottom
      // navigation label and the tab title swap without a restart.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Me'), findsWidgets);
      expect(find.text('我'), findsNothing);
    },
  );

  testWidgets('the language choice persists across launches', (tester) async {
    final settings = SettingsController();
    final prefs = mockPrefs();
    await pumpApp(tester, settings: settings, prefs: prefs);

    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('language-option-en')));
    await tester.pump();

    // A fresh app instance over the same backing store starts in
    // English.
    final again = SettingsController();
    await pumpApp(tester, settings: again, prefs: prefs);
    // The navigator state survives the re-pump, so leave the carried
    // settings route before asserting the labels.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Phonemes'), findsWidgets, reason: 'en chart tab');
    expect(find.text('Me'), findsWidgets, reason: 'en applied');
    expect(find.text('我'), findsNothing, reason: 'zh gone');
  });

  testWidgets(
    'with the audio toggle off the pronunciation button stays visible, playback is a no-op and the fixed notice shows',
    (tester) async {
      final settings = SettingsController();
      final audio = FakeAudioService();
      await pumpApp(
        tester,
        settings: settings,
        prefs: mockPrefs(),
        audio: audio,
      );

      // Turn the toggle off in settings.
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('audio-toggle')));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // The pronunciation button stays reachable: open the detail page.
      await tester.tap(find.byKey(const ValueKey('tab-chart')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('phoneme-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DetailPage), findsOneWidget);
      // The detail page is a flat one-screen flow, so the pronunciation
      // control is on screen without scrolling.
      expect(find.byKey(const ValueKey('audio-play')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('audio-play')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(audio.calls, isEmpty, reason: 'off means a real no-op');
      expect(
        find.byKey(const ValueKey('audio-off-notice')),
        findsOneWidget,
        reason: 'the fixed off notice shows instead of silence',
      );

      // Back on: the same button plays again (the toggle's UI wiring is
      // proven in the off leg; this leg pins the gate itself).
      await tester.pageBack();
      await tester.pumpAndSettle();
      await settings.setAudioOn(true);
      await tester.pump();
      expect(settings.audioOn, isTrue, reason: 'diag: controller on');
      await tester.tap(find.byKey(const ValueKey('tab-chart')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('phoneme-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The detail page is a flat one-screen flow: the pronunciation
      // control is on screen without scrolling.
      expect(find.byKey(const ValueKey('audio-play')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('audio-play')));
      await tester.pump();
      expect(settings.audioOn, isTrue, reason: 'diag: still on at tap');
      // Whether the off notice shows again reveals which branch the
      // gate took on this tap.
      expect(audio.calls, isNotEmpty);
    },
  );

  testWidgets('the copy table covers the migrated surfaces in English', (
    tester,
  ) async {
    final settings = SettingsController();
    await pumpApp(tester, settings: settings, prefs: mockPrefs());

    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('language-option-en')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-chart')));
    await tester.pump();
    await tester.pump();

    // The chart's reading hint renders through the same mechanism.
    await tester.tap(find.byKey(const ValueKey('reading-switch')));
    await tester.pump();
    expect(find.text('Reading mode: taps only play audio'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reading-switch')));
    await tester.pump();

    // The detail page zones render through it too.
    await tester.tap(find.byKey(const ValueKey('phoneme-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DetailPage), findsOneWidget);
    // The flat flow dropped the zone headings, so the migrated surfaces
    // are the writing card's own copy and the mouth placeholder.
    expect(find.text('Trace here'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Mouth image pending'), findsOneWidget);
  });
}
