import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/correspondence.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../../copy/app_copy.dart';
import '../../domain/mastery_controller.dart';
import 'quiz_session.dart';

/// The item source of the shared quiz page (`REQ-034`, decision 9): a
/// new-practice session covers the selected row's phonemes and the
/// top-right batch label shows the row's coarse group (`REQ-020`); a
/// review session covers the due queue and shows the review label. Both
/// sources render the same page and only the item source differs —
/// per-source selection is a domain-layer concern, not a page variant.
class QuizSource {
  const QuizSource._(this.range, this.kind);

  /// A new-practice source over the selected row's phonemes, in row
  /// order; [kind] drives the batch label (vowel / consonant header).
  factory QuizSource.newRow(
    List<PhonemeCatalogEntry> range,
    PhonemeKind kind,
  ) => QuizSource._(range, kind);

  /// A review source over the due-today phonemes in due order; built by
  /// the review entry (B29) and unit-pinned here (REQ-034).
  factory QuizSource.review(List<PhonemeCatalogEntry> range) =>
      QuizSource._(range, null);

  /// The session's phonemes, in source order. The progress denominator.
  final List<PhonemeCatalogEntry> range;

  /// The coarse kind behind a new-practice source; `null` marks review.
  final PhonemeKind? kind;

  /// The top-right batch label resolved through the copy table
  /// (`REQ-020`, `SDD §3.8`): the coarse group of the selected row, or
  /// the review label for a review session.
  String label(BuildContext context) {
    final copy = CopyScope.of(context);
    return switch (kind) {
      PhonemeKind.vowel => copy.vowelHeader,
      PhonemeKind.consonant => copy.consonantHeader,
      null => copy.reviewLabel,
    };
  }
}

/// The shared quiz page (`REQ-034`, `TC-QUIZ-008`): one page hosting the
/// quiz session for both the new-practice and the review source — the
/// session keeps the persistent progress bar (`REQ-020`), the immediate
/// feedback and the completion rule over the source's phonemes
/// (`REQ-021`). The review entry page that opens it with the due queue
/// lands in B29; the source switch itself is pinned at the unit level
/// here.
class QuizPage extends StatelessWidget {
  const QuizPage({
    super.key,
    required this.source,
    required this.catalog,
    this.mastery,
    this.audioService,
    this.glyphs,
    this.correspondence,
    Map<String, QuizTaskBuilder>? tasks,
  }) : tasks = tasks ?? kDefaultQuizTasks;

  /// The item source: the selected row (new practice) or the due queue
  /// (review).
  final QuizSource source;

  /// The catalog backing the task options.
  final PhonemeCatalog catalog;

  /// The shell-owned mastery controller (`B18`); every verdict records
  /// into it regardless of the source. `null` keeps the session
  /// session-local (the B12 state-machine harnesses).
  final MasteryController? mastery;

  /// Injectable layers handed through to the session's tasks.
  final AudioService? audioService;
  final GlyphData? glyphs;
  final CorrespondenceTable? correspondence;

  /// The task registry; injectable so tests can pin the session with a
  /// stub task. Defaults to the full registry.
  final Map<String, QuizTaskBuilder> tasks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: QuizSession(
          key: const ValueKey('quiz-page-session'),
          range: source.range,
          catalog: catalog,
          sourceLabel: source.label(context),
          tasks: tasks,
          audioService: audioService,
          glyphs: glyphs,
          correspondence: correspondence,
          onRecord: mastery == null
              ? null
              : (id, correct) => mastery!.record(id, correct),
        ),
      ),
    );
  }
}
