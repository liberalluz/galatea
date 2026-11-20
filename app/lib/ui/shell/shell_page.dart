import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/correspondence.dart';
import '../../content/examples.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../chart/chart_page.dart';

/// Root shell: three fixed tabs (chart / practice / me), chart is the default
/// (`S3`, wireframe P0). The reading-mode switch sits at the top right of the
/// app bar on the chart tab (`REQ-005`); it is the only control of the
/// reading state — on, taps on the chart play audio; off, they open detail.
class ShellPage extends StatefulWidget {
  const ShellPage({
    super.key,
    this.catalogFuture,
    this.correspondenceFuture,
    this.examplesFuture,
    this.glyphsFuture,
    this.audioService,
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

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  bool _readingMode = false;

  static const List<String> _titles = ['音标', '练习', '我'];

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
      body: IndexedStack(
        index: _index,
        children: [
          ChartPage(
            catalogFuture: widget.catalogFuture,
            correspondenceFuture: widget.correspondenceFuture,
            examplesFuture: widget.examplesFuture,
            glyphsFuture: widget.glyphsFuture,
            audioService: widget.audioService,
            readingMode: _readingMode,
          ),
          const PlaceholderTab(label: '练习'),
          const PlaceholderTab(label: '我'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.abc), label: '音标'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: '练习'),
          NavigationDestination(icon: Icon(Icons.person), label: '我'),
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
