import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';
import '../chart/chart_page.dart';

/// Practice range selection (`REQ-015`, `TC-QUIZ-001`, wireframe P1 practice
/// screenshot): a category tag row filters the phoneme set, the 5-column
/// grid multi-selects and deselects phonemes, and the confirm control is
/// gated until at least one phoneme is selected. The quiz session that
/// consumes the confirmed range lands in `B12`.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key, this.catalogFuture});

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<PhonemeCatalog>? catalogFuture;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  static const String _kAllTag = 'all';

  late final Future<PhonemeCatalog> _catalog =
      widget.catalogFuture ?? loadPhonemeCatalog();

  String _activeTag = _kAllTag;
  final Set<String> _selected = <String>{};

  void _selectTag(String tag) => setState(() => _activeTag = tag);

  void _toggle(String id) => setState(() {
    if (!_selected.add(id)) _selected.remove(id);
  });

  void _clearFilter() => setState(() => _activeTag = _kAllTag);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhonemeCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        final visible = catalog.entries
            .where(
              (entry) => _activeTag == _kAllTag || entry.group == _activeTag,
            )
            .toList(growable: false);
        return Column(
          children: [
            _tagRow(catalog.entries),
            Expanded(child: _gridOrEmpty(visible)),
            _confirmBar(),
          ],
        );
      },
    );
  }

  /// The category tag row: the fixed `all` tag first, then one tag per
  /// group in first-appearance (catalog) order, reusing the chart page's
  /// Chinese titles.
  Widget _tagRow(List<PhonemeCatalogEntry> entries) {
    final groups = <String>[];
    for (final entry in entries) {
      if (!groups.contains(entry.group)) groups.add(entry.group);
    }
    return SingleChildScrollView(
      key: const ValueKey('range-tags'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _tag(_kAllTag, '全部'),
          ),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _tag(group, kGroupTitles[group] ?? group),
            ),
        ],
      ),
    );
  }

  Widget _tag(String tag, String label) {
    final selected = _activeTag == tag;
    return ChoiceChip(
      key: ValueKey('range-tag-$tag'),
      label: Text(label),
      selected: selected,
      onSelected: (_) => _selectTag(tag),
    );
  }

  Widget _gridOrEmpty(List<PhonemeCatalogEntry> visible) {
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('该类别暂无音位', key: ValueKey('range-empty')),
            TextButton(
              key: const ValueKey('range-clear'),
              onPressed: _clearFilter,
              child: const Text('清空筛选'),
            ),
          ],
        ),
      );
    }
    return GridView.count(
      key: const ValueKey('range-grid'),
      crossAxisCount: 5,
      padding: const EdgeInsets.all(16),
      childAspectRatio: 1.4,
      children: [for (final entry in visible) _cell(entry)],
    );
  }

  Widget _cell(PhonemeCatalogEntry entry) {
    final selected = _selected.contains(entry.id);
    return InkWell(
      key: ValueKey('range-cell-${entry.id}'),
      onTap: () => _toggle(entry.id),
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              entry.printGlyph,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (selected)
              Align(
                alignment: Alignment.topRight,
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  key: ValueKey('range-check-${entry.id}'),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The gated confirm bar: disabled with the fixed select-first hint while
  /// nothing is selected (`TC-QUIZ-001`, ux-flows failure branch); enabled
  /// with the selection count once at least one phoneme is selected. The
  /// confirmed range is consumed by the B12 quiz session shell.
  Widget _confirmBar() {
    final gated = _selected.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          if (gated)
            const Expanded(
              child: Text('请先选择音位', key: ValueKey('range-select-first')),
            )
          else
            Expanded(
              child: Text(
                '已选 ${_selected.length} 个',
                key: const ValueKey('range-count'),
              ),
            ),
          FilledButton(
            key: const ValueKey('range-confirm'),
            onPressed: gated ? null : () {},
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
