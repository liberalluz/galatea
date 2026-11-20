import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';

/// Detail page: the zone skeleton (audio -> mouth -> writing -> words) in the
/// fixed section order (`wireframe P3`, `SDD` layout) with the horizontal
/// phoneme switcher at the top. The switcher is a strip of phoneme chips with
/// the current chip highlighted plus prev/next arrows (`REQ-011`); prev/next
/// move to the adjacent phoneme in catalog order and refresh every section;
/// at the ends the respective arrow is disabled and does not wrap
/// (`TC-DETAIL-004`).

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.catalog, required this.initialId});

  /// The full catalog, so prev/next can walk the catalog order.
  final PhonemeCatalog catalog;

  /// The phoneme opened from the chart grid.
  final String initialId;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late int _index = widget.catalog.entries.indexWhere(
    (entry) => entry.id == widget.initialId,
  );

  PhonemeCatalogEntry get _entry => widget.catalog.entries[_index];

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.catalog.entries.length) {
      return;
    }
    setState(() {
      _index = next;
    });
  }

  void _select(String id) {
    setState(() {
      _index = widget.catalog.entries.indexWhere((entry) => entry.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(title: Text(entry.printGlyph)),
      body: ListView(
        key: const ValueKey('detail-page'),
        padding: const EdgeInsets.all(16),
        children: [
          _switcher(context),
          const SizedBox(height: 16),
          Center(
            child: Text(
              entry.printGlyph,
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(entry.id, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(height: 16),
          _zone(
            context,
            key: 'zone-audio',
            label: '发音区',
            glyph: entry.printGlyph,
          ),
          _zone(
            context,
            key: 'zone-mouth',
            label: '口型区',
            glyph: entry.printGlyph,
          ),
          _zone(
            context,
            key: 'zone-writing',
            label: '书写区',
            glyph: entry.printGlyph,
          ),
          _zone(
            context,
            key: 'zone-words',
            label: '例词例句',
            glyph: entry.printGlyph,
          ),
        ],
      ),
    );
  }

  Widget _switcher(BuildContext context) {
    final entries = widget.catalog.entries;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('switcher-prev'),
          onPressed: _index > 0 ? () => _go(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _chip(context, entries[i], selected: i == _index),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('switcher-next'),
          onPressed: _index < entries.length - 1 ? () => _go(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    PhonemeCatalogEntry entry, {
    required bool selected,
  }) {
    final outline = Theme.of(context).colorScheme.outline;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      key: ValueKey('switcher-chip-${entry.id}'),
      onTap: () => _select(entry.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: selected ? ValueKey('switcher-chip-${entry.id}-selected') : null,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? primary : outline),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          entry.printGlyph,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  /// One zone of the fixed section order; later batches fill the zones with
  /// the real features (B7+), the skeleton keeps the order stable.
  Widget _zone(
    BuildContext context, {
    required String key,
    required String label,
    required String glyph,
  }) {
    return Card(
      key: ValueKey<String>(key),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: Text(
                glyph,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
