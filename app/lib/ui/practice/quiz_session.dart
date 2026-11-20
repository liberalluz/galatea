import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/correspondence.dart';
import '../../content/glyphs.dart';
import '../../content/matching_pairs.dart';
import '../../content/phoneme_catalog.dart';
import '../../content/spelling_options.dart';
import '../../content/symbol_options.dart';
import '../writing/tracing_canvas.dart';
import '../writing/verdict.dart';

/// Task data handed to a registered task builder: the current phoneme, the
/// catalog (option sources), the audio service (listening stem) and the
/// session callbacks.
class QuizTaskContext {
  const QuizTaskContext({
    required this.entry,
    required this.catalog,
    required this.onAnswered,
    required this.onSkip,
    this.audioService,
    this.glyphs,
    this.correspondence,
  });

  final PhonemeCatalogEntry entry;

  /// The catalog backing the task options; a task that needs it renders
  /// the preparing state when it is absent.
  final PhonemeCatalog? catalog;

  /// The audio layer backing the stem (B7, ADR-0002); the listening task
  /// renders the preparing state when it is absent.
  final AudioService? audioService;

  /// The handwritten glyph data backing the writing stem (B10, ADR-0003);
  /// the writing task renders the preparing state when it is absent.
  final GlyphData? glyphs;

  /// The KK/DJ/IPA table backing the matching right column (B4,
  /// ADR-0001/ADR-0004); the matching task renders the preparing state
  /// when it is absent.
  final CorrespondenceTable? correspondence;

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

/// The default task registry: the recognition task (`B13`), the listening
/// task (`B14`), the writing task (`B15`) and the matching task (`B16`).
/// The registry now covers every fixed task type of SDD §3.4.
const Map<String, QuizTaskBuilder> kDefaultQuizTasks =
    <String, QuizTaskBuilder>{
      'recognition': _buildRecognitionTask,
      'listening': _buildListeningTask,
      'writing': _buildWritingTask,
      'matching': _buildMatchingTask,
    };

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
    this.audioService,
    this.glyphs,
    this.correspondence,
    this.onRecord,
  }) : tasks = tasks ?? kDefaultQuizTasks;

  /// The confirmed range, in catalog order. The progress denominator.
  final List<PhonemeCatalogEntry> range;

  /// The catalog backing the task options; required by the recognition task.
  final PhonemeCatalog? catalog;

  /// The task registry; injectable so tests can pin the state machine with
  /// a stub task independent of the real task types. Defaults to the
  /// registry with the recognition task.
  final Map<String, QuizTaskBuilder> tasks;

  /// The task type to render; B14 registers the listening task, B15–B16
  /// extend the registry beyond these two.
  final String taskType;

  /// The audio layer backing the listening stem (`B7`, ADR-0002); handed
  /// to the task through [QuizTaskContext]. Injectable so tests pin the
  /// state machine with a scripted fake; defaults to `null`, which the
  /// listening task renders as the preparing state.
  final AudioService? audioService;

  /// The handwritten glyph data backing the writing stem (`B10`,
  /// ADR-0003); handed to the task through [QuizTaskContext]. Defaults to
  /// `null`, which the writing task renders as the preparing state.
  final GlyphData? glyphs;

  /// The KK/DJ/IPA table backing the matching right column (`B4`,
  /// ADR-0001/ADR-0004); handed to the task through [QuizTaskContext].
  /// Defaults to `null`, which the matching task renders as the preparing
  /// state.
  final CorrespondenceTable? correspondence;

  /// Reports every verdict with the phoneme id (`B17`): the mastery
  /// engine records the answer regardless of the practice mode. Optional
  /// — the B12 state-machine tests omit it.
  final void Function(String phonemeId, bool correct)? onRecord;

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
    widget.onRecord?.call(entry.id, correct);
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
        audioService: widget.audioService,
        glyphs: widget.glyphs,
        correspondence: widget.correspondence,
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

/// The listening task (`REQ-017`, `TC-QUIZ-003`): the audio stem with
/// exactly 2 symbol options, exactly 1 correct; the selected option
/// highlights before confirm. Without the audio service or with fewer than
/// 2 distinct glyphs it renders the fixed preparing state.
Widget _buildListeningTask(BuildContext context, QuizTaskContext task) {
  final catalog = task.catalog;
  final audio = task.audioService;
  final options = catalog == null
      ? null
      : buildSymbolOptions(task.entry, catalog);
  if (audio == null || options == null) {
    return _buildPreparingState(context, task.onSkip);
  }
  return _ListeningTaskBody(task: task, audio: audio, options: options);
}

class _ListeningTaskBody extends StatefulWidget {
  const _ListeningTaskBody({
    required this.task,
    required this.audio,
    required this.options,
  });

  final QuizTaskContext task;
  final AudioService audio;
  final SymbolOptions options;

  @override
  State<_ListeningTaskBody> createState() => _ListeningTaskBodyState();
}

class _ListeningTaskBodyState extends State<_ListeningTaskBody> {
  String? _selected;

  /// The R17 failure ladder: the first playback failure offers replay,
  /// a repeated failure offers the skip control.
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    widget.audio.state.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(_ListeningTaskBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audio != widget.audio) {
      oldWidget.audio.state.removeListener(_onStateChanged);
      widget.audio.state.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.audio.state.removeListener(_onStateChanged);
    super.dispose();
  }

  /// `ValueNotifier` only notifies on changes, so each transition into the
  /// failed state counts exactly one ladder step.
  void _onStateChanged() {
    setState(() {
      if (widget.audio.state.value == AudioPlaybackState.failed) {
        _failures += 1;
      }
    });
  }

  void _play() {
    final entry = widget.task.entry;
    widget.audio.play(entry.id, entry.tts);
  }

  @override
  Widget build(BuildContext context) {
    if (_failures >= 2) {
      // ux-flows R17 repeated failure: do not stall practice; the item is
      // not marked answered.
      return _buildPreparingState(context, widget.task.onSkip);
    }
    final failed = _failures >= 1;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            key: ValueKey(failed ? 'task-audio-retry' : 'task-audio-play'),
            onPressed: _play,
            child: Text(failed ? '重试' : '播放'),
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

/// The writing task (`REQ-018`, `TC-QUIZ-004`): the handwritten sample
/// above and a blank tracing area below; submitting with strokes judges
/// the trace under the recorded stroke-overlap threshold, submitting
/// empty shows the trace-first hint without a verdict (ux-flows R18).
/// Without the glyph data it renders the fixed preparing state.
Widget _buildWritingTask(BuildContext context, QuizTaskContext task) {
  final glyph = task.glyphs?.entries[task.entry.id];
  if (glyph == null || glyph.strokes.isEmpty) {
    return _buildPreparingState(context, task.onSkip);
  }
  return _WritingTaskBody(task: task, glyph: glyph);
}

class _WritingTaskBody extends StatefulWidget {
  const _WritingTaskBody({required this.task, required this.glyph});

  final QuizTaskContext task;
  final PhonemeGlyph glyph;

  @override
  State<_WritingTaskBody> createState() => _WritingTaskBodyState();
}

class _WritingTaskBodyState extends State<_WritingTaskBody> {
  final GlobalKey<TracingCanvasState> _canvasKey =
      GlobalKey<TracingCanvasState>();

  bool _hasStrokes = false;

  /// The R18 trace-first guard: shown after an empty submit, cleared by
  /// the first captured stroke.
  bool _showTraceFirst = false;

  void _onStrokesChanged(List<List<Offset>> strokes) {
    setState(() {
      _hasStrokes = strokes.isNotEmpty;
      if (_hasStrokes) {
        _showTraceFirst = false;
      }
    });
  }

  void _submit() {
    if (!_hasStrokes) {
      // ux-flows R18 failure branch: an empty submit is never judged ×;
      // it shows the trace-first hint and stays unanswered.
      setState(() => _showTraceFirst = true);
      return;
    }
    final strokes = _canvasKey.currentState?.captured ?? const <List<Offset>>[];
    widget.task.onAnswered(writingVerdict(widget.glyph.strokes, strokes));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The handwritten sample (ux-flows R18 step 1): the model
          // rendered clearly above the area.
          Container(
            key: const ValueKey('writing-sample'),
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: HandwritingPainter(
                model: widget.glyph.strokes,
                user: const <List<Offset>>[],
                inkColor: Theme.of(context).colorScheme.onSurface,
                modelColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // The blank tracing area (R18 step 2): the model is not drawn
          // faintly inside — the empty state is "only sample and blank
          // area".
          TracingCanvas(
            key: _canvasKey,
            areaKey: const ValueKey('task-tracing-area'),
            model: widget.glyph.strokes,
            height: 220,
            showModel: false,
            onChanged: _onStrokesChanged,
          ),
          if (_showTraceFirst)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '请先在区域内描摹',
                key: const ValueKey('trace-first'),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('task-submit'),
            onPressed: _submit,
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// The matching task (`REQ-019`, `TC-QUIZ-005`): three pronunciation play
/// controls on the left and three DJ symbols on the right; pairing
/// connects one pair at a time, a correct pair greys out inert and a
/// mispair snaps back without counting as completion (ux-flows R19).
/// Without the correspondence table it renders the fixed preparing state.
Widget _buildMatchingTask(BuildContext context, QuizTaskContext task) {
  final correspondence = task.correspondence;
  final options = correspondence == null
      ? null
      : buildMatchingOptions(task.entry, task.catalog!, correspondence);
  if (options == null) {
    return _buildPreparingState(context, task.onSkip);
  }
  return _MatchingTaskBody(task: task, options: options);
}

class _MatchingTaskBody extends StatefulWidget {
  const _MatchingTaskBody({required this.task, required this.options});

  final QuizTaskContext task;
  final MatchingOptions options;

  @override
  State<_MatchingTaskBody> createState() => _MatchingTaskBodyState();
}

class _MatchingTaskBodyState extends State<_MatchingTaskBody> {
  /// The left item armed by the last tap; one pair connects at a time.
  int? _armed;

  /// The pair indexes already matched; their items grey out inert
  /// (ux-flows R19 exit branch) and cannot be re-paired.
  final Set<int> _matched = <int>{};

  void _tapLeft(int index) {
    if (_matched.contains(index)) return;
    final pair = widget.options.pairs[index];
    widget.task.audioService?.play(pair.entry.id, pair.entry.tts);
    setState(() => _armed = index);
  }

  void _tapRight(String dj) {
    final armed = _armed;
    if (armed == null || _matched.contains(armed)) return;
    if (widget.options.pairs[armed].dj == dj) {
      setState(() {
        _matched.add(armed);
        _armed = null;
      });
      // R19 has no failing terminal state: completing every pair counts
      // the item answered correct; mispairs never reach this callback.
      if (_matched.length == widget.options.pairs.length) {
        widget.task.onAnswered(true);
      }
      return;
    }
    // ux-flows R19 failure branch: the mispair snaps back — both items
    // return to the tappable state and the mispair does not count as
    // completion.
    setState(() => _armed = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item({
      required Key key,
      required String label,
      required bool greyed,
      required bool highlighted,
      required VoidCallback? onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: OutlinedButton(
          key: key,
          onPressed: greyed ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: greyed
                ? scheme.surfaceContainerHighest
                : highlighted
                ? scheme.primaryContainer
                : null,
            foregroundColor: greyed
                ? scheme.onSurface.withValues(alpha: 0.4)
                : null,
            minimumSize: const Size(200, 48),
          ),
          child: Text(label),
        ),
      );
    }

    final pairs = widget.options.pairs;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Left column: the pronunciation play controls (R19 step 1);
          // tapping arms the item and speaks the phoneme.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pairs.length; i++)
                  item(
                    key: ValueKey('task-pair-left-${pairs[i].entry.id}'),
                    label: pairs[i].entry.printGlyph,
                    greyed: _matched.contains(i),
                    highlighted: _armed == i,
                    onPressed: () => _tapLeft(i),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right column: the DJ symbols in the fixed shuffled order
          // (no pre-connected pairs); tapping pairs with the armed item.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final dj in widget.options.rightOrder)
                  item(
                    key: ValueKey('task-pair-right-$dj'),
                    label: dj,
                    greyed: _matched.any((i) => pairs[i].dj == dj),
                    highlighted: false,
                    onPressed: () => _tapRight(dj),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
