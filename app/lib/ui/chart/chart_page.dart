import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';

/// Chart page: 5-column print-glyph grid grouped by phonetic category
/// (`REQ-002`, wireframe P1). Tapping a symbol opens the detail route in the
/// default state (`REQ-004`).

const Map<String, String> _kGroupTitles = {
  'front': '元音·前',
  'central': '元音·中',
  'back': '元音·后',
  'bilabial': '辅音·双唇',
  'labiodental': '辅音·唇齿',
  'dental': '辅音·齿',
  'alveolar': '辅音·齿龈',
  'postalveolar': '辅音·齿龈后',
  'palatal': '辅音·硬腭',
  'velar': '辅音·软腭',
  'glottal': '辅音·声门',
};

class ChartPage extends StatefulWidget {
  const ChartPage({super.key, this.catalogFuture});

  /// Injectable for widget tests; production loads the bundled asset.
  final Future<PhonemeCatalog>? catalogFuture;

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final Future<PhonemeCatalog> _catalog =
      widget.catalogFuture ?? loadPhonemeCatalog();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhonemeCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        return ListView(
          key: const ValueKey('chart-grid'),
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in _groupedEntries(catalog.entries))
              ..._groupWidgets(context, entry.key, entry.value),
            const SizedBox(height: 16),
            Text(
              '来源：${catalog.sourceLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }

  /// Groups entries preserving the catalog order; no row crosses a group.
  static List<MapEntry<String, List<PhonemeCatalogEntry>>> _groupedEntries(
    List<PhonemeCatalogEntry> entries,
  ) {
    final groups = <String, List<PhonemeCatalogEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.group, () => []).add(entry);
    }
    return groups.entries.toList();
  }

  static List<Widget> _groupWidgets(
    BuildContext context,
    String group,
    List<PhonemeCatalogEntry> entries,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          _kGroupTitles[group] ?? group,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _groupTable(context, entries),
    ];
  }

  static Table _groupTable(
    BuildContext context,
    List<PhonemeCatalogEntry> entries,
  ) {
    const columns = 5;
    final rows = <TableRow>[];
    for (var i = 0; i < entries.length; i += columns) {
      final chunk = entries.sublist(
        i,
        i + columns > entries.length ? entries.length : i + columns,
      );
      final cells = <Widget>[
        for (final entry in chunk) _glyphCell(context, entry),
        // Pad the last row so it stays left-aligned inside the 5-column grid.
        for (var pad = chunk.length; pad < columns; pad++) const SizedBox(),
      ];
      rows.add(TableRow(children: cells));
    }
    return Table(
      children: rows,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    );
  }

  static Widget _glyphCell(BuildContext context, PhonemeCatalogEntry entry) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        key: ValueKey('phoneme-${entry.id}'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => DetailPage(entry: entry)),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            entry.printGlyph,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}

/// Detail placeholder: later batches grow this into the detail shell (B6).
class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.entry});

  final PhonemeCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry.printGlyph)),
      body: Center(
        key: const ValueKey('detail-page'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.printGlyph,
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(entry.id, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
