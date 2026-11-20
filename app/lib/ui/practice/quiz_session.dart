import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';
import '../../content/spelling_options.dart';

/// Task data handed to a registered task builder: the current phoneme, the
/// catalog (option sources) and the session callbacks.
class QuizTaskContext {
  const QuizTaskContext({
    required this.entry,
    required this.catalog,
    required this.onAnswered,
    required this.onSkip,
  });

  final PhonemeCatalogEntry entry;

  /// The catalog backing the task options; a task that needs it renders
  /// the preparing state when it is absent.
  final PhonemeCatalog? catalog;

  /// The item counts as answered regardless of the verdict (PRD completion
  /// rule); the verdict rides along for the B17 mastery engine.
  final void Function(bool correct) onAnswered;

  /// Advances without marking the item answered (ux-flows R16 failure
  /// branch: a skipped item does not enter the completion debate).
  final void Function() onSkip;
}

/// Builds one task widget for the session's item slot.
typedef QuizTaskBuilder = Widget Function(
  BuildContext context,
  QuizTaskContext task,
);

/// The default task registry: the recognition task (`B13`). B14–B16
/// register the remaining task types here without changing the shell.
const Map<String, QuizTaskBuilder> kDefaultQuizTasks =
    <String, QuizTaskBuilder>{'recognition': _buildRecognitionTask};

/// Quiz session shell (`REQ-020`, `REQ-021`, `TC-QUIZ-006`, `TC-QUIZ-007`):
/// the progress bar advances per answered item and completes when every
/// phoneme in the confirmed range has been answered at least once regardless
/// of verdicts (PRD 完成判定); the range label sits top-right and matches the
/// progress denominator; feedback appears immediately after an answer; the
/// completion rate shows beside the progress bar from 0% onward.
///
/// The item slot renders the task type from the registry (`B13` decision:
/// task registry; this batch registers the recognition task only).
class QuizSession extends StatefulWidget {
  const QuizSession({
    super.key,
    required this.range,
    this.catalog,
    Map<String, QuizTaskBuilder>? tasks,
    this.taskType = 'recognition',
  }) : tasks = tasks ?? kDefaultQuizTasks;

  /// The confirmed range, in catalog order. The progress denominator.
  final List<PhonemeCatalogEntry> range;

  /// The catalog backing the task options; required by the recognition task.
  final PhonemeCatalog? catalog;

  /// The task registry; injectable so tests can pin the state machine with
  /// a stub task independent of the real task types. Defaults to the
  /// registry with the recognition task.
  final Map<String, QuizTaskBuilder> tasks;

  /// The task type to render; B14–B16 extend the registry beyond the
  /// recognition task.
  final String taskType;

  @override
  State<QuizSession> createState() => _QuizSessionState();
}

class _QuizSessionState extends State<QuizSession> {
  final Set<String> _answered = <String>{};

  int _index = 0;

  /// The verdict of the last answer, held until the next one replaces it.
  bool _lastCorrect = false;

  /// Completion per the PRD rule: a phoneme counts once it has been
  /// answered at least once, regardless of the verdict.
  double get _rate =>
      widget.range.isEmpty ? 0 : _answered.length / widget.range.length;

  void _answer(bool correct) {
    final entry = widget.range[_index];
    setState(() {
      _answered.add(entry.id);
      _lastCorrect = correct;
      _index = (_index + 1) % widget.range.length;
    });
  }

  /// Skips the current item: advances without marking it answered. With a
  /// single-item range a skip cannot move, so the preparing state stays.
  void _skip() {
    if (widget.range.length <= 1) return;
    setState(() => _index = (_index + 1) % widget.range.length);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('session-view'),
      children: [
        if (widget.range.isEmpty)
          const Expanded(
            child: Center(
              child: Text('范围暂不可用', key: ValueKey('session-unavailable')),
            ),
          )
        else ...[
          _topBar(context),
          Expanded(child: _taskSlot(context)),
          if (_answered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _lastCorrect ? '回答正确' : '回答错误',
                key: const ValueKey('session-feedback'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
        ],
      ],
    );
  }

  /// Top bar: the progress bar with the completion rate beside it, and the
  /// range label top-right showing the denominator (`TC-QUIZ-006`).
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              key: const ValueKey('session-progress'),
              value: _rate,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(_rate * 100).round()}%',
            key: const ValueKey('session-rate'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 12),
          Text(
            '${widget.range.length} 个音位',
            key: const ValueKey('session-range-label'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// The item slot: renders the registered task type for the current
  /// phoneme, falling back to the fixed preparing state when the registry
  /// has no builder for the type. A task that cannot render itself (for
  /// example the recognition task without enough option data) renders the
  /// preparing state from its own builder.
  Widget _taskSlot(BuildContext context) {
    final entry = widget.range[_index];
    final builder = widget.tasks[widget.taskType];
    if (builder == null) return _preparingState(context);
    return builder(
      context,
      QuizTaskContext(
        entry: entry,
        catalog: widget.catalog,
        onAnswered: _answer,
        onSkip: _skip,
      ),
    );
  }

  /// The fixed preparing state (ux-flows R16 failure branch): the item
  /// cannot render, so it shows the fixed hint with a skip control instead
  /// of an under-filled option row.
  Widget _preparingState(BuildContext context) {
    return _buildPreparingState(context, _skip);
  }
}

/// The fixed preparing state shared by the session fallback and the tasks
/// that cannot render their content (`题目准备中` + a skip control).
Widget _buildPreparingState(BuildContext context, VoidCallback onSkip) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '题目准备中',
          key: const ValueKey('task-preparing'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const ValueKey('task-skip'),
          onPressed: onSkip,
          child: const Text('跳过'),
        ),
      ],
    ),
  );
}

/// The recognition task (`REQ-016`, `TC-QUIZ-002`): the print-glyph stem
/// with exactly 4 letter-spelling options, exactly 1 correct; selecting one
/// and submitting reports the verdict through the session. Without the
/// catalog or with fewer than 4 distinct spellings it renders the fixed
/// preparing state (ux-flows R16 failure branch).
Widget _buildRecognitionTask(BuildContext context, QuizTaskContext task) {
  final catalog = task.catalog;
  final options = catalog == null
      ? null
      : buildSpellingOptions(task.entry, catalog);
  if (options == null) {
    return _buildPreparingState(context, task.onSkip);
  }
  return _RecognitionTaskBody(task: task, options: options);
}

class _RecognitionTaskBody extends StatefulWidget {
  const _RecognitionTaskBody({required this.task, required this.options});

  final QuizTaskContext task;
  final SpellingOptions options;

  @override
  State<_RecognitionTaskBody> createState() => _RecognitionTaskBodyState();
}

class _RecognitionTaskBodyState extends State<_RecognitionTaskBody> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final entry = widget.task.entry;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry.printGlyph,
            key: ValueKey('task-stem-${entry.id}'),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 24),
          for (final option in widget.options.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: OutlinedButton(
                key: ValueKey('task-option-$option'),
                onPressed: () => setState(() => _selected = option),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _selected == option
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  minimumSize: const Size(200, 48),
                ),
                child: Text(option),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('task-submit'),
            onPressed: _selected == null
                ? null
                : () => widget.task.onAnswered(
                    _selected == widget.options.correct,
                  ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
