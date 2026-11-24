import 'package:flutter/material.dart';

import '../../audio/audio_gate.dart';
import '../../audio/audio_service.dart';
import '../../content/correspondence.dart';
import '../../content/examples.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../../copy/app_copy.dart';
import '../../domain/notation.dart';
import '../../domain/notation_controller.dart';
import '../chart/row_model.dart';
import '../writing/tracing_canvas.dart';

/// Detail page per the one-screen layout the product owner confirmed on
/// 2026-11-23 against the competitor reference (`SDD` §3.3, `REQ-036`):
/// the same-row member circles move into the top bar and spread across its
/// width, one spelling-to-symbol mapping row replaces the duplicated large
/// glyph and the star row, the mouth slot shrinks to a small card beside the
/// larger writing card, the pronunciation control becomes an inline line
/// under the writing card, and the 2×2 example cards stretch to the bottom
/// of the viewport.
///
/// The page is a flat content flow (`REQ-036`): the zone cards lose their
/// frames and their section headings, and the body is one centred column
/// limited to 480 px — the phone viewport and the wide desktop window share
/// the same layout with no breakpoint branch. The example grid takes the
/// height the fixed parts leave over.
///
/// The switcher renders the current phoneme's row members from the shared
/// row model (`REQ-011`): the circles sit in the top bar, the last row at
/// its actual count, defaulting to the tapped phoneme; adjacent means
/// same-row member, so navigation never crosses rows and the ends of a row
/// do not wrap (`TC-DETAIL-004`). The stroke order auto-plays once when a
/// phoneme appears and tapping the writing card replays it with
/// pronunciation; missing stroke data keeps the fixed `stroke-pending` state
/// with playback disabled, independent of tracing (`REQ-009`,
/// `TC-TRACE-002`). The handwriting control is a round button on the
/// content layer's top-right corner and opens the non-scored handwriting
/// overlay covering the page — grey model, cross guides, clear-and-rewrite,
/// done returns; it is an overlay, not a route, and never produces a score
/// or verdict (`REQ-035`, `TC-TRACE-003`). The pronunciation control
/// exposes the four fixed states loading / ready / playing / failed
/// (`TC-DETAIL-001`); failures never disable the other sections. Missing
/// media assets render fixed same-size placeholders and cards are never
/// hidden (`TC-DETAIL-002`, `TC-CONTENT-003`).
class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.catalog,
    required this.initialId,
    this.audioService,
    this.examples,
    this.glyphs,
    this.notation,
    this.correspondence,
  });

  /// The full catalog; the row model splits it into the same rows the
  /// chart and the row-select mode show.
  final PhonemeCatalog catalog;

  /// The phoneme opened from the chart grid.
  final String initialId;

  /// Injectable audio service (ADR-0002 interface); defaults to the
  /// platform provider when omitted.
  final AudioService? audioService;

  /// Example word/sentence data (`B9`); when absent the slots render the
  /// fixed placeholders.
  final ExamplesData? examples;

  /// Handwritten glyph and stroke-order data (`B10`, `ADR-0003`); when
  /// absent or missing an entry the writing zone shows the preparing state.
  final GlyphData? glyphs;

  /// The shell-owned notation selection (`REQ-036`): the printed symbol
  /// and the handwritten skeleton follow the notation the user picked on
  /// the chart page. `null` keeps the KK default.
  final NotationController? notation;

  /// The KK / DJ / IPA correspondence table (`REQ-012`): the source of
  /// the symbol in the notation currently selected. `null` falls back to
  /// the catalog's KK glyph.
  final CorrespondenceTable? correspondence;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with TickerProviderStateMixin {
  /// The page's content column is one centred band on every viewport
  /// (`REQ-036`); the phone and the desktop window share it.
  static const double _kContentWidth = 480;

  late int _index = widget.catalog.entries.indexWhere(
    (entry) => entry.id == widget.initialId,
  );

  /// The shared tracing canvas state; the user strokes live inside the
  /// component and are cleared from here on phoneme switches
  /// (`TC-TRACE-001`).
  final GlobalKey<TracingCanvasState> _canvasKey =
      GlobalKey<TracingCanvasState>();

  /// The overlay's own canvas state; overlay strokes are independent of
  /// the writing zone (`REQ-035`).
  final GlobalKey<TracingCanvasState> _overlayCanvasKey =
      GlobalKey<TracingCanvasState>();

  /// Whether the canvas currently holds user strokes; drives the trace
  /// hint and the clear control.
  bool _hasStrokes = false;

  /// Whether the stroke-order animation is playing (`REQ-009`).
  bool _playing = false;

  /// Whether the handwriting overlay covers the page (`REQ-035`).
  bool _overlayOpen = false;

  late final AnimationController _playController = AnimationController(
    vsync: this,
  )..addStatusListener(_onPlayStatus);

  late final AudioService _audio =
      widget.audioService ?? createDefaultAudioService();

  PhonemeCatalogEntry get _entry => widget.catalog.entries[_index];

  @override
  void initState() {
    super.initState();
    _audio.state.addListener(_onAudioStateChanged);
    _scheduleAutoplay();
  }

  @override
  void dispose() {
    _audio.state.removeListener(_onAudioStateChanged);
    _playController.dispose();
    super.dispose();
  }

  void _onPlayStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _playing = false;
      });
    }
  }

  PhonemeGlyph? get _glyph => widget.glyphs?.entries[_entry.id];

  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _play() {
    gatedPlay(
      context,
      _audio,
      _entry.id,
      _entry.tts.isEmpty ? _entry.id : _entry.tts,
    );
  }

  /// The stroke order auto-plays once when a phoneme appears
  /// (`TC-TRACE-002`, decision 13): page entry and every switch.
  void _scheduleAutoplay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_modelStrokes.isNotEmpty && !_playing) {
        _playStrokes();
      }
    });
  }

  void _select(String id) {
    _audio.stop();
    setState(() {
      _index = widget.catalog.entries.indexWhere((entry) => entry.id == id);
      _resetWriting();
    });
    _scheduleAutoplay();
  }

  /// A phoneme switch resets the writing zone: user strokes and the
  /// stroke-order playback never carry over (`TC-TRACE-002`).
  void _resetWriting() {
    _canvasKey.currentState?.clear();
    _hasStrokes = false;
    _playing = false;
    _playController.reset();
  }

  void _playStrokes() {
    if (_modelStrokes.isEmpty || _playing) {
      return;
    }
    setState(() {
      _playing = true;
      _playController.duration = Duration(
        milliseconds: 400 * _modelStrokes.length,
      );
    });
    _playController.forward(from: 0);
  }

  /// Tapping the writing grid replays the stroke order with pronunciation
  /// (`TC-TRACE-002`, decision 13); without stroke data it does nothing —
  /// playback stays disabled (`TC-TRACE-002`).
  void _replayFromGrid() {
    if (_modelStrokes.isEmpty || _playing) {
      return;
    }
    _playStrokes();
    _play();
  }

  /// The current phoneme's row members from the shared row model
  /// (`REQ-011`): the coarse group picks the row list, the current id
  /// picks the member row.
  List<PhonemeCatalogEntry> get _rowMembers {
    final rows = rowsForKind(_entry.kind, widget.catalog.entries);
    for (final row in rows) {
      if (row.any((entry) => entry.id == _entry.id)) {
        return row;
      }
    }
    return [_entry];
  }

  /// The screen-reader label for the phoneme: its spoken text, falling
  /// back to the phoneme id when the spoken text is empty (TC-QUAL-004,
  /// REQ-030, ux-flows R30).
  String get _spokenLabel => _entry.tts.isNotEmpty ? _entry.tts : _entry.id;

  /// The notation currently in effect (`REQ-036`): the shared controller's
  /// selection when the shell provides one, KK otherwise.
  Notation get _notation => widget.notation?.notation ?? Notation.kk;

  /// The printed symbol of [entry] in the notation currently selected
  /// (`REQ-036`): the correspondence table's column for that notation,
  /// resolved through the KK fallback; without the table the catalog's KK
  /// glyph.
  String _symbolOf(PhonemeCatalogEntry entry) {
    final mapping = widget.correspondence?.mappings
        .where((m) => m.id == entry.id)
        .firstOrNull;
    if (mapping == null) {
      return entry.printGlyph;
    }
    return resolveGlyph(
      kk: mapping.kk,
      dj: mapping.dj,
      ipa: mapping.ipa,
      notation: _notation,
    );
  }

  /// The printed symbol of the current phoneme (`REQ-036`).
  String get _printGlyph => _symbolOf(_entry);

  /// The handwritten strokes of the current phoneme in the notation
  /// currently selected (`REQ-013`): the notation-aware variant when the
  /// record carries one, the shared base strokes otherwise.
  List<List<Offset>> get _modelStrokes {
    final glyph = _glyph;
    if (glyph == null) {
      return const <List<Offset>>[];
    }
    return glyph.strokesFor(_notation.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The same-row member circles move into the top bar (`REQ-011`,
        // `REQ-036`): the switcher is a navigation control, not a page
        // section.
        title: _topBar(context),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kContentWidth),
              child: Stack(
                children: [
                  Column(
                    key: const ValueKey('detail-page'),
                    children: [
                      _mappingRow(context),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              Expanded(flex: 3, child: _writingRow(context)),
                              const SizedBox(height: 8),
                              _audioLine(context),
                              const SizedBox(height: 8),
                              Expanded(
                                flex: 4,
                                child: _exampleGrid(context, _examples),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // The handwriting control floats over the content
                  // (`REQ-035`): it opens the same non-scored overlay.
                  if (!_overlayOpen)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _handwritingButton(context),
                    ),
                ],
              ),
            ),
          ),
          if (_overlayOpen) _handwritingOverlay(context),
        ],
      ),
    );
  }

  /// The top bar content (`REQ-011`, `REQ-036`): the printed symbol of
  /// the current notation on the left, the same-row member circles spread
  /// across the rest of the bar width with the gaps widened.
  Widget _topBar(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kContentWidth),
        child: Row(
          children: [
            Semantics(
              excludeSemantics: true,
              label: _spokenLabel,
              child: Text(
                _printGlyph,
                key: const ValueKey('detail-topbar-symbol'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _topBarSwitcher(context)),
          ],
        ),
      ),
    );
  }

  /// The same-row member circles in the top bar (`REQ-011`,
  /// `TC-DETAIL-004`): one circle per row member from the shared row
  /// model, the current member selected; no arrows, no crossing rows, no
  /// wrap.
  Widget _topBarSwitcher(BuildContext context) {
    final members = _rowMembers;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final member in members)
          _circle(context, member, selected: member.id == _entry.id),
      ],
    );
  }

  /// The mapping row (`REQ-036`): the phoneme's spelling fragment on the
  /// left and the printed symbol of the selected notation on the right —
  /// how the sound is spelled next to the sound itself.
  Widget _mappingRow(BuildContext context) {
    final letters = _entry.letters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        key: const ValueKey('detail-mapping-row'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (letters.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                letters,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward,
              size: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 12),
          ],
          Semantics(
            excludeSemantics: true,
            label: _spokenLabel,
            child: Text(
              _printGlyph,
              key: const ValueKey('detail-print-symbol'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
    );
  }

  /// The mouth slot beside the writing card (`REQ-007`): the mouth slot is
  /// the small card on the left, the writing card is the dominant element.
  Widget _writingRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 72,
            height: 96,
            child: _mouthCard(context, _examples),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _writingCard(context)),
      ],
    );
  }

  /// The writing card (`REQ-008`, `REQ-009`): the tracing area over the
  /// handwritten glyph with the cross guides behind it; tapping the grid
  /// replays the stroke order with pronunciation (`TC-TRACE-002`). The
  /// area is the shared tracing canvas (`B15`): capture and rendering have
  /// one source; the card adds the hint overlay and the playback.
  Widget _writingCard(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      key: const ValueKey('detail-writing-card'),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _replayFromGrid,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      key: const ValueKey('detail-cross-guides'),
                      painter: _CrossGuidePainter(
                        color: outline.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _playController,
                      builder: (context, _) => TracingCanvas(
                        key: _canvasKey,
                        areaKey: const ValueKey('tracing-area'),
                        model: _modelStrokes,
                        height: double.infinity,
                        playedStroke: _playing ? _playedStroke() : -1,
                        playFraction: _playing ? _playController.value : 0,
                        onChanged: (strokes) =>
                            setState(() => _hasStrokes = strokes.isNotEmpty),
                      ),
                    ),
                  ),
                  if (!_hasStrokes)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            CopyScope.of(context).traceHint,
                            key: const ValueKey('trace-hint'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: outline),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Flexible(
                  child: TextButton.icon(
                    key: const ValueKey('writing-clear'),
                    onPressed: !_hasStrokes
                        ? null
                        : () => _canvasKey.currentState?.clear(),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(
                      CopyScope.of(context).clear,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(child: _strokeControl(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The handwriting control (`REQ-035`): a round button floating over the
  /// content that opens the non-scored handwriting overlay.
  Widget _handwritingButton(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        key: const ValueKey('detail-handwriting-button'),
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _overlayOpen = true),
        child: Semantics(
          excludeSemantics: true,
          label: CopyScope.of(context).penTooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.pan_tool_alt_outlined,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle(
    BuildContext context,
    PhonemeCatalogEntry entry, {
    required bool selected,
  }) {
    final outline = Theme.of(context).colorScheme.outline;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      key: ValueKey('switcher-circle-${entry.id}'),
      onTap: () => _select(entry.id),
      customBorder: const CircleBorder(),
      child: Container(
        key: selected ? ValueKey('switcher-circle-${entry.id}-selected') : null,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? primary : outline,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(_symbolOf(entry), style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  /// The stroke-order playback state (`REQ-009`): playing indicator while
  /// the animation runs; phonemes without stroke data show the fixed
  /// preparing label — playback disabled, independent of the tracing area
  /// (`TC-TRACE-002`). Replay is the grid tap, not a separate control.
  Widget _strokeControl(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    if (_modelStrokes.isEmpty) {
      return Text(
        CopyScope.of(context).strokePending,
        key: const ValueKey('stroke-pending'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
      );
    }
    if (_playing) {
      return const SizedBox(
        key: ValueKey('stroke-playing'),
        height: 32,
        width: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }
    return const SizedBox.shrink();
  }

  /// The index of the stroke the playback animation is currently drawing,
  /// derived from the controller progress across the stroke count.
  int _playedStroke() {
    final count = _modelStrokes.length;
    if (count == 0) {
      return -1;
    }
    return (_playController.value * count).floor().clamp(0, count - 1);
  }

  /// The current phoneme's example data; absent when the loader has not
  /// delivered the data or the phoneme has no entry.
  PhonemeExamples? get _examples => widget.examples?.entries[_entry.id];

  /// The mouth-shape slot (`REQ-007`): the image when the asset exists, the
  /// fixed `mouth-pending` placeholder at the same size otherwise — never a
  /// blank area, never another phoneme's image (`TC-DETAIL-002`).
  Widget _mouthCard(BuildContext context, PhonemeExamples? data) {
    final outline = Theme.of(context).colorScheme.outline;
    final hasImage = data != null && data.mouth.isNotEmpty;
    return Container(
      key: const ValueKey('detail-mouth-card'),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox.expand(
          child: hasImage
              ? Image.asset(
                  data.mouth,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _mouthPending(context),
                )
              : _mouthPending(context),
        ),
      ),
    );
  }

  Widget _mouthPending(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      key: const ValueKey('mouth-pending'),
      alignment: Alignment.center,
      child: Text(
        CopyScope.of(context).mouthPending,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
      ),
    );
  }

  /// The 2×2 example cards (`REQ-010`): the grid takes the height the
  /// fixed parts leave over and reaches the bottom edge; each card carries
  /// one image and either one word or one sentence as the phoneme-level
  /// display form decides — never both. A missing image keeps the text
  /// visible and shows the same-size placeholder; cards are never hidden
  /// (`TC-CONTENT-003`).
  Widget _exampleGrid(BuildContext context, PhonemeExamples? data) {
    final items = data?.examples ?? const <ExampleItem>[];
    final showsSentence = data?.showsSentence ?? false;
    Widget cell(int index) => Expanded(
      child: _exampleCard(
        context,
        index,
        index < items.length ? items[index] : null,
        showsSentence,
      ),
    );
    return Column(
      key: const ValueKey('example-grid'),
      children: [
        Expanded(
          child: Row(children: [cell(0), const SizedBox(width: 8), cell(1)]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(children: [cell(2), const SizedBox(width: 8), cell(3)]),
        ),
      ],
    );
  }

  Widget _exampleCard(
    BuildContext context,
    int index,
    ExampleItem? item,
    bool showsSentence,
  ) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      key: ValueKey('example-card-$index'),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _exampleImage(context, index, item)),
          const SizedBox(height: 6),
          Text(
            showsSentence ? (item?.sentence ?? '') : (item?.word ?? ''),
            key: ValueKey('example-text-$index'),
            maxLines: showsSentence ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: showsSentence
                ? Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: outline)
                : Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }

  /// The image slot of one card: the image when the asset exists, the fixed
  /// same-size placeholder otherwise (`TC-CONTENT-003`).
  Widget _exampleImage(BuildContext context, int index, ExampleItem? item) {
    final hasImage = item != null && item.image.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.expand(
        child: hasImage
            ? Image.asset(
                item.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imagePending(context, index),
              )
            : _imagePending(context, index),
      ),
    );
  }

  /// The fixed same-size image placeholder; the word or the sentence stays
  /// visible beside it and the card is never hidden (`TC-CONTENT-003`).
  Widget _imagePending(BuildContext context, int index) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      key: ValueKey('example-image-pending-$index'),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: outline),
    );
  }

  /// The pronunciation line (`REQ-006`): the printed symbol and the
  /// speaker button on one inline line right under the writing card, in
  /// the four fixed states loading / ready / playing / failed
  /// (`TC-DETAIL-001`); a failure stays inside the line — the other
  /// sections never change with it.
  Widget _audioLine(BuildContext context) {
    final child = switch (_audio.state.value) {
      AudioPlaybackState.ready => IconButton(
        key: const ValueKey('audio-play'),
        onPressed: _play,
        icon: const Icon(Icons.volume_up),
      ),
      AudioPlaybackState.loading => const SizedBox(
        key: ValueKey('audio-loading'),
        height: 32,
        width: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      AudioPlaybackState.playing => const Icon(
        Icons.graphic_eq,
        key: ValueKey('audio-playing'),
      ),
      AudioPlaybackState.failed => TextButton(
        key: const ValueKey('audio-retry'),
        onPressed: _play,
        child: Text(CopyScope.of(context).playbackFailed),
      ),
    };
    return Row(
      key: const ValueKey('detail-audio-line'),
      children: [
        Semantics(
          excludeSemantics: true,
          label: _spokenLabel,
          child: Text(
            _printGlyph,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Spacer(),
        KeyedSubtree(key: const ValueKey('detail-audio-button'), child: child),
      ],
    );
  }

  /// The handwriting overlay (`REQ-035`, decision 12): a page-level Stack
  /// overlay, not a Navigator route — the grey handwritten model with the
  /// cross guides behind the pointer strokes, clear-and-rewrite, done
  /// returns to the detail page. It never produces a score or verdict;
  /// scoring stays with the writing task (`REQ-018`).
  Widget _handwritingOverlay(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Positioned.fill(
      key: const ValueKey('handwriting-overlay'),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      CopyScope.of(context).overlayTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Semantics(
                      excludeSemantics: true,
                      label: _spokenLabel,
                      child: Text(
                        _printGlyph,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('overlay-guides'),
                          painter: _CrossGuidePainter(color: outline),
                        ),
                      ),
                      TracingCanvas(
                        key: _overlayCanvasKey,
                        areaKey: const ValueKey('overlay-canvas'),
                        model: _modelStrokes,
                        height: double.infinity,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TextButton.icon(
                      key: const ValueKey('overlay-clear'),
                      onPressed: () => _overlayCanvasKey.currentState?.clear(),
                      icon: const Icon(Icons.restart_alt),
                      label: Text(CopyScope.of(context).overlayClear),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('overlay-done'),
                      onPressed: () => setState(() => _overlayOpen = false),
                      child: Text(CopyScope.of(context).overlayDone),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cross guides of the writing card and the handwriting overlay
/// (`REQ-035`, decision 12): a faint vertical and horizontal centre line
/// behind the grey model.
class _CrossGuidePainter extends CustomPainter {
  _CrossGuidePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrossGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}
