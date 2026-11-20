import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';
import '../../domain/mastery_controller.dart';

/// The Me tab's mastery statistics (`REQ-023`, `TC-REVIEW-002`, wireframe
/// P5 right half): the three summary rows over the catalog denominator
/// (never multiplied by notation — ux-flows R23 step 3), the KK/DJ/IPA
/// display filter whose switching leaves every count identical (the
/// stars are shared across the three notations, ADR-0001), and the
/// fixed empty notice (ux-flows R23 empty state).
class MePage extends StatefulWidget {
  const MePage({
    super.key,
    this.catalogFuture,
    required this.masteryController,
  });

  /// Injectable for widget tests; production loads the bundled asset.
  final Future<PhonemeCatalog>? catalogFuture;

  /// The shell-owned controller — the same instance the practice tab
  /// records into, so an answer reflects here without a reload.
  final MasteryController masteryController;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  /// The display notation of the filter chips; switching it is the R23
  /// display filter — the counts and stars are identical under all
  /// three (TC-REVIEW-002 exit).
  String _notation = 'kk';

  static const Map<String, String> _notationLabels = <String, String>{
    'kk': 'KK',
    'dj': 'DJ',
    'ipa': 'IPA',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhonemeCatalog>(
      future: widget.catalogFuture ?? loadPhonemeCatalog(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        return ListenableBuilder(
          listenable: widget.masteryController,
          builder: (context, _) => _statistics(context, catalog),
        );
      },
    );
  }

  Widget _statistics(BuildContext context, PhonemeCatalog catalog) {
    final entries = widget.masteryController.engine.state.entries;
    var mastered = 0;
    var learning = 0;
    var unstarted = 0;
    for (final entry in catalog.entries) {
      final star = entries[entry.id]?.star ?? 0;
      if (star >= 3) {
        mastered += 1;
      } else if (star >= 1) {
        learning += 1;
      } else {
        unstarted += 1;
      }
    }
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('me-page'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('掌握度', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        // The notation filter: three display-only chips (TC-REVIEW-002
        // step 2). Switching never changes the counts — the acceptance
        // itself pins the invariance.
        Wrap(
          spacing: 8,
          children: [
            for (final entry in _notationLabels.entries)
              ChoiceChip(
                key: ValueKey('me-filter-${entry.key}'),
                label: Text(entry.value),
                selected: _notation == entry.key,
                onSelected: (_) => setState(() => _notation = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '开始练习后显示掌握度',
              key: ValueKey('me-empty-notice'),
              style: TextStyle(color: Color(0xFF5F6368)),
            ),
          ),
        _statsRow(
          context,
          key: 'me-row-mastered',
          label: '已掌握 3★',
          count: mastered,
        ),
        _statsRow(
          context,
          key: 'me-row-learning',
          label: '学习中 1–2★',
          count: learning,
        ),
        _statsRow(
          context,
          key: 'me-row-unstarted',
          label: '未掌握 0★',
          count: unstarted,
        ),
        const SizedBox(height: 8),
        Text(
          '合计 ${catalog.entries.length}',
          key: const ValueKey('me-total'),
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _statsRow(
    BuildContext context, {
    required String key,
    required String label,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        key: ValueKey(key),
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          Text('$count 音位', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
