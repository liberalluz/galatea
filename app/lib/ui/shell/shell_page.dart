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
import '../practice/practice_page.dart';

/// Root shell: three fixed tabs (chart / practice / me), chart is the default
/// (`S3`, wireframe P0). The reading-mode switch sits at the top right of the
/// app bar on the chart tab (`REQ-005`); it is the only control of the
/// reading state — on, taps on the chart play audio; off, they open detail.
///
/// The shell owns one [MasteryController] (`B18`, single source of truth):
/// the practice tab records into it and the Me tab and the detail page read
/// it, so an answer reflects in the statistics without a reload.
class ShellPage extends StatefulWidget {
  const ShellPage({
    super.key,
    this.catalogFuture,
    this.correspondenceFuture,
    this.examplesFuture,
    this.glyphsFuture,
    this.audioService,
    this.masteryFuture,
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

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  bool _readingMode = false;

  late final Future<MasteryController> _mastery =
      widget.masteryFuture ?? _loadMastery();

  static const List<String> _titles = ['音标', '练习', '我'];

  Future<MasteryController> _loadMastery() async {
    try {
      // The backing store answers within milliseconds in production; in
      // an environment without the platform channel the future never
      // completes, so the timeout degrades to the in-memory store and
      // the mastery state stays session-local (ux-flows R23 failure
      // branch: the degraded state is marked, never presented as
      // trusted).
      final prefs = await SharedPreferences.getInstance().timeout(
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
          return IndexedStack(
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
              ),
              PracticePage(
                catalogFuture: widget.catalogFuture,
                masteryController: mastery,
              ),
              MePage(
                catalogFuture: widget.catalogFuture,
                masteryController: mastery,
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
            key: ValueKey('tab-practice'),
            icon: Icon(Icons.edit_note),
            label: '练习',
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
