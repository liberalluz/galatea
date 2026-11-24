import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';
import '../../copy/app_copy.dart';
import '../../domain/mastery_controller.dart';
import '../../domain/notation.dart';
import 'about_page.dart';
import 'review_page.dart';
import 'settings_page.dart';

/// The Me tab home (`REQ-032`, wireframe P5): the mastery statistics
/// card over the catalog denominator (never multiplied by notation —
/// ux-flows R23 step 3) with the KK/DJ/IPA display filter whose
/// switching leaves every count identical (the stars are shared across
/// the three notations, ADR-0001) and the fixed empty notice; under it
/// the review status strip showing the due count and hidden when none
/// is due or the state is unavailable, and the three drill-down entries
/// to review / settings / about. The bottom bar stays chart / Me only
/// (`REQ-031`) — these pages are drill-downs, never tabs.
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
  late final Future<PhonemeCatalog> _catalog =
      widget.catalogFuture ?? loadPhonemeCatalog();

  /// The display notation of the filter chips; switching it is the R23
  /// display filter — the counts and stars are identical under all
  /// three (TC-REVIEW-002 exit).
  String _notation = 'kk';

  /// The due-today count from the engine; `null` while the catalog has
  /// not resolved (the strip stays hidden until it can be computed).
  int? _dueCount(PhonemeCatalog catalog) {
    if (widget.masteryController.degraded) {
      return null;
    }
    final engine = widget.masteryController.engine;
    return catalog.entries.where((entry) => engine.isDue(entry.id)).length;
  }

  void _openReview(PhonemeCatalog catalog) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewPage(
          catalogFuture: Future.value(catalog),
          mastery: widget.masteryController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhonemeCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data!;
        return ListenableBuilder(
          listenable: widget.masteryController,
          builder: (context, _) => _home(context, catalog),
        );
      },
    );
  }

  Widget _home(BuildContext context, PhonemeCatalog catalog) {
    final copy = CopyScope.of(context);
    final theme = Theme.of(context);
    final dueCount = _dueCount(catalog);
    return ListView(
      key: const ValueKey('me-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _statisticsCard(context, catalog),
        // The review status strip (`REQ-032`): due count with a drill
        // into the review queue; hidden when none is due or the count
        // cannot be computed (degraded state — never inventing data).
        if (dueCount != null && dueCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Card(
              child: InkWell(
                key: const ValueKey('me-review-strip'),
                onTap: () => _openReview(catalog),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${copy.reviewStrip} $dueCount',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ListTile(
          key: const ValueKey('entry-review'),
          leading: const Icon(Icons.replay),
          title: Text(copy.entryReview),
          onTap: () => _openReview(catalog),
        ),
        ListTile(
          key: const ValueKey('entry-settings'),
          leading: const Icon(Icons.settings_outlined),
          title: Text(copy.entrySettings),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
        ),
        ListTile(
          key: const ValueKey('entry-about'),
          leading: const Icon(Icons.info_outline),
          title: Text(copy.entryAbout),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const AboutPage())),
        ),
      ],
    );
  }

  /// The mastery statistics card (`REQ-023`, `TC-REVIEW-002`): the three
  /// summary rows over the catalog denominator with the notation filter.
  Widget _statisticsCard(BuildContext context, PhonemeCatalog catalog) {
    final copy = CopyScope.of(context);
    final theme = Theme.of(context);
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.masteryTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            // The notation filter: three display-only chips (TC-REVIEW-002
            // step 2). Switching never changes the counts — the acceptance
            // itself pins the invariance.
            Wrap(
              spacing: 8,
              children: [
                for (final notation in Notation.values)
                  ChoiceChip(
                    key: ValueKey('me-filter-${notation.name}'),
                    label: Text(notationLabels[notation]!),
                    selected: _notation == notation.name,
                    onSelected: (_) =>
                        setState(() => _notation = notation.name),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  copy.meEmptyNotice,
                  key: const ValueKey('me-empty-notice'),
                  style: const TextStyle(color: Color(0xFF5F6368)),
                ),
              ),
            _statsRow(
              context,
              key: 'me-row-mastered',
              label: copy.rowMastered,
              count: mastered,
            ),
            _statsRow(
              context,
              key: 'me-row-learning',
              label: copy.rowLearning,
              count: learning,
            ),
            _statsRow(
              context,
              key: 'me-row-unstarted',
              label: copy.rowUnstarted,
              count: unstarted,
            ),
            const SizedBox(height: 8),
            Text(
              '${catalog.entries.length} ${copy.phonemeUnit}',
              key: const ValueKey('me-total'),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
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
          Text(
            '$count ${CopyScope.of(context).phonemeUnit}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
