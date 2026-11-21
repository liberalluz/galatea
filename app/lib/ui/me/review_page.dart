import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';
import '../../copy/app_copy.dart';
import '../../domain/mastery_controller.dart';
import '../practice/quiz_page.dart';

/// The review drill-down (`REQ-022`, `REQ-034`, wireframe P6): the due
/// queue in due order — due-today first, oldest due at the top — the
/// fixed `review-empty` state when nothing is due, and "start" opening
/// the shared quiz page over the review source. Every verdict of the
/// session records into the shell-owned mastery controller; the queue
/// shrinks as the engine reschedules, so the drill-down always shows
/// what the engine currently holds due (`TC-REVIEW-001`).
class ReviewPage extends StatelessWidget {
  const ReviewPage({
    super.key,
    required this.catalogFuture,
    required this.mastery,
  });

  /// The catalog backing the list glyphs and the quiz options.
  final Future<PhonemeCatalog> catalogFuture;

  /// The shell-owned controller — the session records into it and the
  /// due computation reads its engine.
  final MasteryController mastery;

  @override
  Widget build(BuildContext context) {
    final copy = CopyScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(copy.reviewTitle)),
      body: FutureBuilder<PhonemeCatalog>(
        future: catalogFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final catalog = snapshot.data!;
          final engine = mastery.engine;
          // Due order: the queued phonemes whose due day has arrived,
          // oldest due first (the engine's due computation, unit-pinned
          // in B27's review-source tests).
          final due =
              catalog.entries.where((entry) => engine.isDue(entry.id)).toList()
                ..sort(
                  (a, b) => (engine.state.entries[a.id]!.due!).compareTo(
                    engine.state.entries[b.id]!.due!,
                  ),
                );
          if (due.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    copy.reviewEmpty,
                    key: const ValueKey('review-empty'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  key: const ValueKey('review-list'),
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final entry in due)
                      ListTile(
                        key: ValueKey('review-item-${entry.id}'),
                        leading: Text(
                          entry.printGlyph,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        title: Text(entry.id),
                        trailing: Text(
                          copy.dueLabel(
                            engine.dueDays(
                              engine.state.entries[entry.id]!.due!,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  key: const ValueKey('review-start'),
                  onPressed: () => _start(context, catalog, due),
                  child: Text(copy.startReview),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Starts the shared quiz page over the due queue (`REQ-034`): the
  /// review source keeps the due order and the session records every
  /// verdict into the controller.
  void _start(
    BuildContext context,
    PhonemeCatalog catalog,
    List<PhonemeCatalogEntry> due,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(
          source: QuizSource.review(due),
          catalog: catalog,
          mastery: mastery,
        ),
      ),
    );
  }
}
