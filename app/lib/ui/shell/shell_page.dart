import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../audio/audio_service.dart';
import '../../content/correspondence.dart';
import '../../content/examples.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../../domain/mastery_controller.dart';
import '../../domain/mastery_prefs_store.dart';
import '../../domain/mastery_store.dart';
import '../chart/chart_page.dart';
import '../me/me_page.dart';

/// Root shell: two fixed tabs (chart / me) after the v0.2.0 interaction
/// revamp (`REQ-031`, decision 2) — quiz, review, settings and about are
/// drill-downs and never occupy a tab; the practice entry returns with
/// B27 as the chart's row-select flow. Chart is the default (wireframe
/// P0). The reading-mode switch sits at the top right of the app bar on
/// the chart tab (`REQ-005`); it is the only control of the reading
/// state — on, taps on the chart play audio; off, they open detail.
///
/// The shell owns one [MasteryController] (`B18`, single source of
/// truth): the practice flow records into it and the Me tab and the
/// detail page read it, so an answer reflects in the statistics without
/// a reload.
///
/// The first-run hint (`REQ-033`, skeleton S1) shows once: a light,
/// non-blocking banner above the body that explains the two
/// non-obvious interactions (tap = detail, toggle = direct read);
/// dismissing it is permanent across restarts.
class ShellPage extends StatefulWidget {
  const ShellPage({
    super.key,
    this.catalogFuture,
    this.correspondenceFuture,
    this.examplesFuture,
    this.glyphsFuture,
    this.audioService,
    this.masteryFuture,
    this.prefsFuture,
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

  /// Injectable mastery controller future for widget tests; production
  /// builds a controller over the preferences store (see [_loadMastery]).
  final Future<MasteryController>? masteryFuture;

  /// Injectable preferences future for widget tests (the first-run hint
  /// flag and the mastery store both read it); production uses the
  /// platform instance.
  final Future<SharedPreferences>? prefsFuture;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  bool _readingMode = false;
  bool _showFirstRunHint = false;

  /// The preferences instance resolved once: the injected future in
  /// tests, the platform instance with the degraded-store timeout in
  /// production. `null` while unresolved (hint hidden, mastery pending).
  Future<SharedPreferences> get _prefs =>
      widget.prefsFuture ?? SharedPreferences.getInstance();

  /// The persisted flag key for the first-run hint (`REQ-033`): set to
  /// true on dismissal, never shown again afterwards.
  static const String _kFirstRunDismissed = 'first-run-hint-dismissed';

  late final Future<MasteryController> _mastery =
      widget.masteryFuture ?? _loadMastery();

  static const List<String> _titles = ['音标', '我'];

  @override
  void initState() {
    super.initState();
    _resolveFirstRunHint();
  }

  /// Reads the dismissal flag; the hint shows only when the flag has
  /// never been set (`REQ-033`). A failed read hides the hint — a
  /// missing flag never blocks the chart.
  Future<void> _resolveFirstRunHint() async {
    try {
      final prefs = await _prefs.timeout(const Duration(milliseconds: 150));
      if (!mounted) {
        return;
      }
      setState(() {
        _showFirstRunHint = !(prefs.getBool(_kFirstRunDismissed) ?? false);
      });
    } catch (_) {
      // No platform backend answered in time: keep the hint hidden.
    }
  }

  /// Dismisses the first-run hint and persists the dismissal so later
  /// launches never show it again (`REQ-033`).
  Future<void> _dismissFirstRunHint() async {
    setState(() {
      _showFirstRunHint = false;
    });
    try {
      final prefs = await _prefs.timeout(const Duration(milliseconds: 150));
      await prefs.setBool(_kFirstRunDismissed, true);
    } catch (_) {
      // Degraded store: the dismissal stays session-local, marked by the
      // missing persisted flag rather than presented as saved.
    }
  }

  Future<MasteryController> _loadMastery() async {
    try {
      // The backing store answers within milliseconds in production; in
      // an environment without the platform channel the future never
      // completes, so the timeout degrades to the in-memory store and
      // the mastery state stays session-local (ux-flows R23 failure
      // branch: the degraded state is marked, never presented as
      // trusted).
      final prefs =
          await (widget.prefsFuture ?? SharedPreferences.getInstance()).timeout(
            const Duration(milliseconds: 150),
          );
      final controller = MasteryController(store: PrefsMasteryStore(prefs));
      await controller.load();
      return controller;
    } catch (_) {
      // No platform backend (tests, or a degraded embedder): the mastery
      // state stays in memory for the session.
      final controller = MasteryController(store: InMemoryMasteryStore());
      controller.degraded = true;
      await controller.load();
      return controller;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0)
            Switch(
              key: const ValueKey('reading-switch'),
              value: _readingMode,
              onChanged: (value) => setState(() => _readingMode = value),
            ),
        ],
      ),
      body: FutureBuilder<MasteryController>(
        future: _mastery,
        builder: (context, snapshot) {
          final mastery = snapshot.data;
          if (mastery == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (_showFirstRunHint)
                Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      key: const ValueKey('first-run-hint'),
                      children: [
                        Expanded(
                          child: Text(
                            '轻提示：点音标看详情；打开右上角开关可直读发音',
                            key: const ValueKey('first-run-hint-text'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('first-run-dismiss'),
                          onPressed: _dismissFirstRunHint,
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    ChartPage(
                      catalogFuture: widget.catalogFuture,
                      correspondenceFuture: widget.correspondenceFuture,
                      examplesFuture: widget.examplesFuture,
                      glyphsFuture: widget.glyphsFuture,
                      audioService: widget.audioService,
                      readingMode: _readingMode,
                      mastery: mastery,
                      onReviewDeepLink: () => setState(() => _index = 1),
                    ),
                    MePage(
                      catalogFuture: widget.catalogFuture,
                      masteryController: mastery,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            key: ValueKey('tab-chart'),
            icon: Icon(Icons.abc),
            label: '音标',
          ),
          NavigationDestination(
            key: ValueKey('tab-me'),
            icon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }
}

/// Placeholder for tabs that later batches grow into real pages.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}
