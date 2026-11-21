/// The mastery engine (`REQ-022`, `REQ-023` basis, `TC-REVIEW-001`): the
/// star ladder and the spaced-repetition queue of the PRD product rules.
///
/// Stars start at 0, +1 per correct answer capped at 3, −1 per wrong
/// answer floored at 0. A wrong answer queues the phoneme at interval 1
/// (due tomorrow); consecutive correct review answers advance the step
/// through the 1/2/4/7/15-day intervals and a wrong review answer resets
/// it to interval 1. Stars carry no per-notation dimension (ADR-0001) —
/// the state is keyed by phoneme id only, so the rating is shared across
/// KK/DJ/IPA by construction.
const List<int> kReviewIntervals = <int>[1, 2, 4, 7, 15];

/// One phoneme's mastery state: the star rating, the interval step (an
/// index into [kReviewIntervals]) and the due date (`null` while the
/// phoneme is not queued for review).
class MasteryEntry {
  MasteryEntry({this.star = 0, this.step = 0, this.due});

  int star;

  /// The index of the current interval in [kReviewIntervals]; 0 while
  /// unqueued.
  int step;

  /// When the phoneme becomes due for review; `null` while unqueued.
  DateTime? due;
}

/// The per-phoneme mastery state. Mutable by design: the engine mutates
/// entries in place and the controller persists the whole document.
class MasteryState {
  MasteryState([Map<String, MasteryEntry>? entries])
    : entries = entries ?? <String, MasteryEntry>{};

  final Map<String, MasteryEntry> entries;

  /// The entry for [id], created (star 0, unqueued) on first touch.
  MasteryEntry entryFor(String id) => entries.putIfAbsent(id, MasteryEntry.new);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'entries': <String, dynamic>{
      for (final MapEntry<String, MasteryEntry> e in entries.entries)
        e.key: <String, dynamic>{
          'star': e.value.star,
          'step': e.value.step,
          'due': e.value.due?.toIso8601String(),
        },
    },
  };

  factory MasteryState.fromJson(Map<String, dynamic> json) {
    final state = MasteryState();
    final entries = (json['entries'] as Map<String, dynamic>?) ?? const {};
    entries.forEach((String id, dynamic raw) {
      final map = raw as Map<String, dynamic>;
      state.entries[id] = MasteryEntry(
        star: (map['star'] as num?)?.toInt() ?? 0,
        step: (map['step'] as num?)?.toInt() ?? 0,
        due: map['due'] == null ? null : DateTime.parse(map['due'] as String),
      );
    });
    return state;
  }
}

/// The mastery engine: owns the state and applies the answer rules. The
/// clock is injectable so tests pin the day arithmetic.
class MasteryEngine {
  MasteryEngine({DateTime Function()? now}) : now = now ?? DateTime.now;

  final DateTime Function() now;

  final MasteryState state = MasteryState();

  DateTime _addDays(DateTime from, int days) => from.add(Duration(days: days));

  /// A correct answer: +1 star (cap 3); a queued phoneme advances to the
  /// next interval step and reschedules (the ladder tops out at 15 days).
  void recordCorrect(String id) {
    final entry = state.entryFor(id);
    entry.star = (entry.star + 1).clamp(0, 3);
    if (entry.due != null) {
      entry.step = (entry.step + 1).clamp(0, kReviewIntervals.length - 1);
      entry.due = _addDays(now(), kReviewIntervals[entry.step]);
    }
  }

  /// A wrong answer (any practice mode, ux-flows R22 entry): −1 star
  /// (floor 0) and queue — or, for an already queued phoneme, reset to
  /// interval 1.
  void recordWrong(String id) {
    final entry = state.entryFor(id);
    entry.star = (entry.star - 1).clamp(0, 3);
    entry.step = 0;
    entry.due = _addDays(now(), kReviewIntervals[0]);
  }

  /// Whether the phoneme is queued and its due day has arrived (the due
  /// day itself counts).
  bool isDue(String id) {
    final entry = state.entries[id];
    if (entry == null || entry.due == null) return false;
    return !now().isBefore(entry.due!);
  }

  /// The whole days between today and the due day (negative = overdue);
  /// the presentation layer renders the label from this through the copy
  /// table, so the engine carries no user-facing strings.
  int dueDays(DateTime due) {
    final today = now();
    final from = DateTime(today.year, today.month, today.day);
    final until = DateTime(due.year, due.month, due.day);
    return until.difference(from).inDays;
  }
}
