import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../content/phoneme_catalog.dart';
import '../../domain/mastery_controller.dart';
import '../../domain/mastery_prefs_store.dart';
import '../../domain/mastery_store.dart';
import '../chart/chart_page.dart';
import 'quiz_session.dart';

/// Practice range selection (`REQ-015`, `TC-QUIZ-001`, wireframe P1) with
/// the review mode of `B17` (`REQ-022`, wireframe P5): the mode switch at
/// the top swaps between new practice (the tag row + selection grid) and
/// the review pane (the due list + start control); the quiz session that
/// consumes a confirmed or due range stays the B12 shell.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key, this.catalogFuture, this.masteryController});

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<PhonemeCatalog>? catalogFuture;

  /// Injectable for widget tests; production builds a controller over the
  /// preferences store. When omitted the page initializes asynchronously
  /// and degrades to the in-memory store if the backend is unavailable.
  final MasteryController? masteryController;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  static const String _kAllTag = 'all';

  late final Future<PhonemeCatalog> _catalog =
      widget.catalogFuture ?? loadPhonemeCatalog();

  late final Future<MasteryController> _mastery = _loadMastery();

  String _activeTag = _kAllTag;
  final Set<String> _selected = <String>{};

  /// Whether the range is confirmed and the quiz session has taken over
  /// the tab (`B12`): the confirm control swaps the selection grid for
  /// the session view over the confirmed range.
  bool _confirmed = false;

  /// The active mode (wireframe P5): new practice or the review pane.
  String _mode = 'new';

  /// Whether the review session is running (the due range took over).
  bool _reviewing = false;

  /// The phonemes the running review session covers, in due order.
  List<PhonemeCatalogEntry> _reviewRange = const <PhonemeCatalogEntry>[];

  Future<MasteryController> _loadMastery() async {
    final injected = widget.masteryController;
    if (injected != null) {
      return injected;
    }
    try {
      // The backing store answers within milliseconds in production; in
      // an environment without the platform channel the future never
      // completes, so the timeout degrades to the in-memory store and
      // the mastery state stays session-local.
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
      await controller.load();
      return controller;
    }
  }

  void _selectTag(String tag) => setState(() => _activeTag = tag);

  void _toggle(String id) => setState(() {
    if (!_selected.add(id)) _selected.remove(id);
  });

  void _clearFilter() => setState(() => _activeTag = _kAllTag);

  void _confirm() => setState(() => _confirmed = true);

  /// Switching the mode leaves any running session (the confirmed new
  /// range or the review range) — the switch is the only way back.
  void _setMode(String mode) => setState(() {
    _mode = mode;
    _confirmed = false;
    _reviewing = false;
    _selected.clear();
  });

  /// Starts the review over the due-today phonemes in ascending due
  /// order (same-day entries in catalog order — the sort is stable over
  /// the catalog-ordered input with the due date as the only key). The
  /// queue's not-yet-due entries (the "N天后" rows) do not join.
  void _startReview(MasteryController controller, PhonemeCatalog catalog) {
    final now = controller.engine.now();
    final due = <PhonemeCatalogEntry>[];
    for (final entry in catalog.entries) {
      if (controller.engine.isDue(entry.id)) due.add(entry);
    }
    due.sort(
      (a, b) => (controller.engine.state.entries[a.id]?.due ?? now).compareTo(
        controller.engine.state.entries[b.id]?.due ?? now,
      ),
    );
    setState(() {
      _reviewRange = due;
      _reviewing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhonemeCatalog>(
      future: _catalog,
      builder: (context, catalogSnapshot) {
        if (!catalogSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = catalogSnapshot.data!;
        return FutureBuilder<MasteryController>(
          future: _mastery,
          builder: (context, masterySnapshot) {
            final controller = masterySnapshot.data;
            if (controller == null) {
              return const Center(child: CircularProgressIndicator());
            }
            // The controller notifies on every recorded answer and on a
            // store write failure (the R22 notice) — the body rebuilds
            // on those notifications.
            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                children: [
                  _modeSwitch,
                  Expanded(child: _body(controller, catalog)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The mode switch (wireframe P5: 新练 / 复习); switching leaves any
  /// running session.
  Widget get _modeSwitch {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ChoiceChip(
            key: const ValueKey('practice-mode-new'),
            label: const Text('新练'),
            selected: _mode == 'new',
            onSelected: (_) => _setMode('new'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const ValueKey('practice-mode-review'),
            label: const Text('复习'),
            selected: _mode == 'review',
            onSelected: (_) => _setMode('review'),
          ),
        ],
      ),
    );
  }

  Widget _body(MasteryController controller, PhonemeCatalog catalog) {
    if (_reviewing) {
      return QuizSession(
        key: const ValueKey('review-session'),
        range: _reviewRange,
        catalog: catalog,
        onRecord: (id, correct) => controller.record(id, correct),
      );
    }
    if (_mode == 'review') {
      return _reviewPane(controller, catalog);
    }
    if (_confirmed) {
      return QuizSession(
        range: catalog.entries
            .where((entry) => _selected.contains(entry.id))
            .toList(growable: false),
        catalog: catalog,
        onRecord: (id, correct) => controller.record(id, correct),
      );
    }
    final visible = catalog.entries
        .where((entry) => _activeTag == _kAllTag || entry.group == _activeTag)
        .toList(growable: false);
    return Column(
      children: [
        _tagRow(catalog.entries),
        Expanded(child: _gridOrEmpty(visible)),
        _confirmBar(),
      ],
    );
  }

  /// The review pane (wireframe P5, left): the queue listing with due
  /// labels ("今天" / "N天后" — the queue shows every queued phoneme, the
  /// not-yet-due ones included), the due-today count, the start control
  /// over the due-today subset, the fixed empty state and the R22
  /// failure notice.
  Widget _reviewPane(MasteryController controller, PhonemeCatalog catalog) {
    final now = controller.engine.now();
    final queued = <PhonemeCatalogEntry>[];
    final dueToday = <PhonemeCatalogEntry>[];
    for (final entry in catalog.entries) {
      final record = controller.engine.state.entries[entry.id];
      if (record?.due == null) continue;
      queued.add(entry);
      if (controller.engine.isDue(entry.id)) dueToday.add(entry);
    }
    int dueOf(PhonemeCatalogEntry e) =>
        (controller.engine.state.entries[e.id]?.due ?? now)
            .millisecondsSinceEpoch;
    queued.sort((a, b) => dueOf(a).compareTo(dueOf(b)));
    dueToday.sort((a, b) => dueOf(a).compareTo(dueOf(b)));
    return Column(
      key: const ValueKey('review-pane'),
      children: [
        if (controller.lastWriteFailed)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '复习队列暂未更新',
              key: ValueKey('review-store-failed'),
              style: TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '今日到期: ${dueToday.length}',
            key: const ValueKey('review-count'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: queued.isEmpty
              ? const Center(
                  child: Text('暂无待复习音位', key: ValueKey('review-empty')),
                )
              : ListView.builder(
                  key: const ValueKey('review-list'),
                  itemCount: queued.length,
                  itemBuilder: (context, index) {
                    final entry = queued[index];
                    final dueAt =
                        controller.engine.state.entries[entry.id]?.due;
                    return ListTile(
                      key: ValueKey('review-tile-${entry.id}'),
                      leading: Text(
                        entry.printGlyph,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      title: Text(
                        dueAt == null ? '' : controller.engine.dueLabel(dueAt),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('review-start'),
                  onPressed: dueToday.isEmpty
                      ? null
                      : () {
                          _startReview(controller, catalog);
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始复习'),
                ),
              ),
            ],
          ),
        ),
      ],
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
            onPressed: gated ? null : _confirm,
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
