import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/audio_service.dart';
import 'content/correspondence.dart';
import 'content/examples.dart';
import 'content/glyphs.dart';
import 'content/phoneme_catalog.dart';
import 'copy/app_copy.dart';
import 'settings/settings_controller.dart';
import 'ui/shell/shell_page.dart';

/// The app version shown on the About page (REQ-001); the release flow
/// updates it together with the pubspec version.
const String kAppVersion = '0.2.1';

void main() {
  runApp(const GalateaApp());
}

/// Root of the Galatea app: the shell hosts the two fixed tabs; the
/// settings controller (language + audio toggle) sits above the
/// navigator so a language switch applies to every route immediately
/// (`SDD §3.8`).
/// The app theme (B20, `TC-QUAL-001`): the bundled IPA-capable font
/// heads the fontFamilyFallback chain, so the phonetic symbols (ʃ θ ŋ ɚ)
/// render from the bundled Noto Sans on Web and iOS; the system defaults
/// stay behind it and nothing blocks the first frame (ux-flows R27 empty
/// state).
ThemeData buildTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    useMaterial3: true,
    fontFamilyFallback: const ['Noto Sans'],
  );
}

class GalateaApp extends StatefulWidget {
  const GalateaApp({
    super.key,
    this.catalogFuture,
    this.correspondenceFuture,
    this.examplesFuture,
    this.glyphsFuture,
    this.audioService,
    this.settingsController,
    this.settingsFuture,
  });

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<PhonemeCatalog>? catalogFuture;
  final Future<CorrespondenceTable>? correspondenceFuture;

  /// Injectable example data (`B9`); production loads the bundled asset.
  final Future<ExamplesData>? examplesFuture;

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<GlyphData>? glyphsFuture;

  /// Injectable audio service (ADR-0002 interface); defaults to the
  /// platform provider when omitted.
  final AudioService? audioService;

  /// Injectable settings controller for widget tests; production builds
  /// one over the preferences store (see [_GalateaAppState.initState]).
  final SettingsController? settingsController;

  /// Injectable preferences future for the settings store; production
  /// uses the platform instance (degraded to defaults session-local on
  /// a timeout, the R23 discipline).
  final Future<SharedPreferences>? settingsFuture;

  @override
  State<GalateaApp> createState() => _GalateaAppState();
}

class _GalateaAppState extends State<GalateaApp> {
  SettingsController _settings = SettingsController();

  @override
  void initState() {
    super.initState();
    _bindSettings();
  }

  @override
  void didUpdateWidget(GalateaApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A replaced settings controller (test harnesses re-pump the root
    // with a fresh instance) rebinds and reloads: the State object is
    // reused, so initState does not run again.
    if (widget.settingsController != oldWidget.settingsController ||
        widget.settingsFuture != oldWidget.settingsFuture) {
      _bindSettings();
    }
  }

  void _bindSettings() {
    _settings.removeListener(_onSettingsChanged);
    _settings = widget.settingsController ?? _settings;
    _settings.addListener(_onSettingsChanged);
    _settings.load(widget.settingsFuture);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// Rebuilds the root on every settings change: the copy scope below
  /// swaps its table and the whole navigator re-renders in the new
  /// language on the same frame.
  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.ofLanguage(_settings.language);
    return CopyScope(
      copy: copy,
      child: SettingsScope(
        controller: _settings,
        child: MaterialApp(
          title: 'Galatea',
          theme: buildTheme(),
          home: ShellPage(
            catalogFuture: widget.catalogFuture,
            correspondenceFuture: widget.correspondenceFuture,
            examplesFuture: widget.examplesFuture,
            glyphsFuture: widget.glyphsFuture,
            audioService: widget.audioService,
          ),
        ),
      ),
    );
  }
}
