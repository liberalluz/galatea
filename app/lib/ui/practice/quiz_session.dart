import 'package:flutter/material.dart';

import '../../content/phoneme_catalog.dart';

/// Quiz session shell (`REQ-020`, `REQ-021`, `TC-QUIZ-006`, `TC-QUIZ-007`,
/// wireframe P1 practice screenshots 2–8): the progress bar advances per
/// answered item and completes when every phoneme in the confirmed range has
/// been answered at least once regardless of verdicts (PRD 完成判定); the
/// range label sits top-right and matches the progress denominator; feedback
/// appears immediately after an answer; the completion rate shows beside the
/// progress bar from 0% onward.
///
/// The item slot is a pluggable stub for now (`B12` decision): it shows the
/// current phoneme with a fixed-verdict answer action driving the state
/// machine; the four real task types (`B13`–`B16`) replace the stub one by
/// one.
class QuizSession extends StatefulWidget {
  const QuizSession({super.key, required this.range});

  /// The confirmed range, in catalog order. The progress denominator.
  final List<PhonemeCatalogEntry> range;

  @override
  State<QuizSession> createState() => _QuizSessionState();
}

class _QuizSessionState extends State<QuizSession> {
  final Set<String> _answered = <String>{};

  int _index = 0;

  /// The verdict of the last answer, held until the next one replaces it.
  /// The stub's fixed verdict — real tasks produce their own in B13–B16.
  bool _lastCorrect = false;

  /// Completion per the PRD rule: a phoneme counts once it has been
  /// answered at least once, regardless of the verdict.
  double get _rate =>
      widget.range.isEmpty ? 0 : _answered.length / widget.range.length;

  void _answer() {
    final entry = widget.range[_index];
    setState(() {
      _answered.add(entry.id);
      _lastCorrect = true;
      _index = (_index + 1) % widget.range.length;
    });
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
          Expanded(child: _stubTask(context)),
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

  /// The stub task: the current phoneme with a fixed-verdict answer action.
  Widget _stubTask(BuildContext context) {
    final entry = widget.range[_index];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry.printGlyph,
            key: ValueKey('session-stub-prompt-${entry.id}'),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('session-stub-answer'),
            onPressed: _answer,
            child: const Text('作答'),
          ),
          const SizedBox(height: 16),
          if (_answered.isNotEmpty)
            Text(
              _lastCorrect ? '回答正确' : '回答错误',
              key: const ValueKey('session-feedback'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }
}
