import 'package:flutter/material.dart';

import '../../content/correspondence.dart';
import '../../content/phoneme_catalog.dart';
import '../../domain/notation.dart';
import '../detail/detail_page.dart';

/// Chart page: 5-column print-glyph grid grouped by phonetic category
/// (`REQ-002`, wireframe P1). A notation switch (KK / DJ / IPA) sits above
/// the grid; KK is the default and switching re-renders the symbols while
/// the selected phoneme stays selected (`REQ-003`, `TC-CHART-003`).
/// Tapping a symbol opens the detail route in the default state
/// (`REQ-004`).

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

const Map<Notation, String> _kNotationLabels = {
  Notation.kk: 'KK',
  Notation.dj: 'DJ',
  Notation.ipa: 'IPA',
};

class ChartPage extends StatefulWidget {
  const ChartPage({super.key, this.catalogFuture, this.correspondenceFuture});

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<PhonemeCatalog>? catalogFuture;
  final Future<CorrespondenceTable>? correspondenceFuture;

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final Future<PhonemeCatalog> _catalog =
      widget.catalogFuture ?? loadPhonemeCatalog();
  late final Future<CorrespondenceTable?> _correspondence =
      widget.correspondenceFuture ?? loadCorrespondence();

  Notation _notation = Notation.kk;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object?>>(
      future: Future.wait<Object?>([_catalog, _correspondence]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data![0] as PhonemeCatalog;
        final correspondence = snapshot.data![1] as CorrespondenceTable?;
        final glyphs = <String, String>{
          for (final m
              in correspondence?.mappings ?? const <CorrespondenceMapping>[])
            m.id: resolveGlyph(
              kk: m.kk,
              dj: m.dj,
              ipa: m.ipa,
              notation: _notation,
            ),
        };
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<String>(
                key: const ValueKey('notation-switch'),
                segments: [
                  for (final n in Notation.values)
                    ButtonSegment<String>(
                      value: n.name,
                      label: Text(_kNotationLabels[n]!),
                    ),
                ],
                selected: {_notation.name},
                onSelectionChanged: (selection) {
                  setState(() {
                    _notation = Notation.values.byName(selection.first);
                  });
                },
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('chart-grid'),
                padding: const EdgeInsets.all(16),
                children: [
                  for (final group in _groupedEntries(catalog.entries))
                    ..._groupWidgets(context, group, glyphs, catalog),
                  const SizedBox(height: 16),
                  Text(
                    '来源：${catalog.sourceLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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

  List<Widget> _groupWidgets(
    BuildContext context,
    MapEntry<String, List<PhonemeCatalogEntry>> group,
    Map<String, String> glyphs,
    PhonemeCatalog catalog,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          _kGroupTitles[group.key] ?? group.key,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _groupTable(context, group.value, glyphs, catalog),
    ];
  }

  Table _groupTable(
    BuildContext context,
    List<PhonemeCatalogEntry> entries,
    Map<String, String> glyphs,
    PhonemeCatalog catalog,
  ) {
    const columns = 5;
    final rows = <TableRow>[];
    for (var i = 0; i < entries.length; i += columns) {
      final chunk = entries.sublist(
        i,
        i + columns > entries.length ? entries.length : i + columns,
      );
      final cells = <Widget>[
        for (final entry in chunk)
          _glyphCell(
            context,
            entry,
            glyphs[entry.id] ?? entry.printGlyph,
            catalog,
          ),
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

  Widget _glyphCell(
    BuildContext context,
    PhonemeCatalogEntry entry,
    String glyph,
    PhonemeCatalog catalog,
  ) {
    final selected = _selectedId == entry.id;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        key: ValueKey('phoneme-${entry.id}'),
        onTap: () {
          setState(() {
            _selectedId = entry.id;
          });
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DetailPage(catalog: catalog, initialId: entry.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          key: selected ? ValueKey('phoneme-${entry.id}-selected') : null,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(glyph, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }
}
