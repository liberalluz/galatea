import 'package:flutter/material.dart';

import '../../content/correspondence.dart';
import '../../content/phoneme_catalog.dart';
import '../chart/chart_page.dart';

/// Root shell: three fixed tabs (chart / practice / me), chart is the default
/// (`S3`, wireframe P0). Practice and me are placeholders for later batches.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key, this.catalogFuture, this.correspondenceFuture});

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<PhonemeCatalog>? catalogFuture;
  final Future<CorrespondenceTable>? correspondenceFuture;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  static const List<String> _titles = ['音标', '练习', '我'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          ChartPage(
            catalogFuture: widget.catalogFuture,
            correspondenceFuture: widget.correspondenceFuture,
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
