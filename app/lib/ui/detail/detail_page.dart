import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/examples.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../../domain/mastery_controller.dart';
import '../chart/row_model.dart';
import '../writing/tracing_canvas.dart';

/// Detail page per the fixed wireframe P3 zone order (`SDD §3.3`,
/// decisions 11/13): same-row circle switcher, large glyph with the
/// reduced star row, mouth-shape slot beside the single writing grid,
/// pronunciation button, 2×2 example cards (`REQ-006`–`REQ-011`).
///
/// The switcher renders the current phoneme's row members from the shared
/// row model (`REQ-011`): five circles, the last row at its actual count,
/// defaulting to the tapped phoneme; adjacent means same-row member, so
/// navigation never crosses rows and the ends of a row do not wrap
/// (`TC-DETAIL-004`). The stroke order auto-plays once when a phoneme
/// appears and tapping the writing grid replays it with pronunciation;
/// missing stroke data keeps the fixed `stroke-pending` state with
/// playback disabled, independent of tracing (`REQ-009`, `TC-TRACE-002`).
/// The top-right pen control opens the handwriting overlay covering the
/// page — grey model, cross guides, clear-and-rewrite, done returns; it is
/// an overlay, not a route, and never produces a score or verdict
/// (`REQ-035`, `TC-TRACE-003`). The pronunciation button exposes the four
/// fixed states loading / ready / playing / failed (`TC-DETAIL-001`);
/// failures never disable the other sections. Missing media assets render
/// fixed same-size placeholders and cards are never hidden
/// (`TC-DETAIL-002`, `TC-CONTENT-003`).

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.catalog,
    required this.initialId,
    this.audioService,
    this.examples,
    this.glyphs,
    this.mastery,
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

  /// The shell-owned mastery controller (`B18`); when present the reduced
  /// star rating row shows under the phoneme id (ux-flows R23 entry,
  /// second surface). `null` keeps the row absent.
  final MasteryController? mastery;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with TickerProviderStateMixin {
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
    _audio.play(_entry.id, _entry.tts.isEmpty ? _entry.id : _entry.tts);
  }

  /// The stroke order auto-plays once when a phoneme appears
  /// (`TC-TRACE-002`, decision 13): page entry and every switch.
  void _scheduleAutoplay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final glyph = _glyph;
      if (glyph != null && glyph.strokes.isNotEmpty && !_playing) {
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
    final glyph = _glyph;
    if (glyph == null || glyph.strokes.isEmpty || _playing) {
      return;
    }
    setState(() {
      _playing = true;
      _playController.duration = Duration(
        milliseconds: 400 * glyph.strokes.length,
      );
    });
    _playController.forward(from: 0);
  }

  /// Tapping the writing grid replays the stroke order with pronunciation
  /// (`TC-TRACE-002`, decision 13); without stroke data it does nothing —
  /// playback stays disabled (`TC-TRACE-002`).
  void _replayFromGrid() {
    final glyph = _glyph;
    if (glyph == null || glyph.strokes.isEmpty || _playing) {
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

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          excludeSemantics: true,
          label: _spokenLabel,
          child: Text(entry.printGlyph),
        ),
        actions: [
          IconButton(
            key: const ValueKey('detail-pen'),
            tooltip: '手写练习',
            onPressed: () => setState(() => _overlayOpen = true),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            key: const ValueKey('detail-page'),
            padding: const EdgeInsets.all(16),
            children: [
              _switcher(context),
              const SizedBox(height: 16),
              Center(
                child: Semantics(
                  key: const ValueKey('detail-hero-glyph'),
                  excludeSemantics: true,
                  label: _spokenLabel,
                  child: Text(
                    entry.printGlyph,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  entry.id,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (widget.mastery != null) ...[
                const SizedBox(height: 8),
                _starRow(context, widget.mastery!),
              ],
              const SizedBox(height: 16),
              // Wireframe P3: the mouth-shape slot beside the single
              // writing grid (`SDD §3.3`).
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _zone(
                        context,
                        key: 'zone-mouth',
                        label: '口型区',
                        child: _mouthSlot(context, _examples),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _zone(
                        context,
                        key: 'zone-writing',
                        label: '书写区',
                        child: _writingZone(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _zone(
                context,
                key: 'zone-audio',
                label: '发音区',
                child: _audioControl(context),
              ),
              _zone(
                context,
                key: 'zone-words',
                label: '例词例句',
                child: _exampleGrid(context, _examples),
              ),
            ],
          ),
          if (_overlayOpen) _handwritingOverlay(context),
        ],
      ),
    );
  }

  /// The same-row circle switcher (`REQ-011`, `TC-DETAIL-004`): one circle
  /// per row member from the shared row model, the current member
  /// selected; no arrows, no crossing rows, no wrap.
  Widget _switcher(BuildContext context) {
    final members = _rowMembers;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final member in members)
          _circle(context, member, selected: member.id == _entry.id),
      ],
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
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? primary : outline,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          entry.printGlyph,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  /// The reduced star rating row (`B18`, ux-flows R23 entry surface 2):
  /// the phoneme's shared 0–3 stars with the mastery label; a degraded
  /// controller shows 0 stars plus the fixed 数据待同步 marker instead of
  /// presenting values that may not reflect persisted data (the R23
  /// failure branch — never inventing stars).
  Widget _starRow(BuildContext context, MasteryController mastery) {
    return ListenableBuilder(
      listenable: mastery,
      builder: (context, _) {
        final star = mastery.degraded
            ? 0
            : (mastery.engine.state.entries[_entry.id]?.star ?? 0);
        final label = switch (star) {
          >= 3 => '已掌握',
          >= 1 => '学习中',
          _ => '未掌握',
        };
        return Column(
          children: [
            Row(
              key: const ValueKey('detail-star'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(i < star ? Icons.star : Icons.star_border, size: 16),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (mastery.degraded)
              const Text(
                '数据待同步',
                key: ValueKey('star-degraded'),
                style: TextStyle(color: Color(0xFF5F6368), fontSize: 12),
              ),
          ],
        );
      },
    );
  }

  /// One zone of the fixed section order; each zone card carries its
  /// label and real content only — the duplicated glyph display of the
  /// old skeleton is gone with the wireframe layout (`SDD §3.3`).
  Widget _zone(
    BuildContext context, {
    required String key,
    required String label,
    required Widget child,
  }) {
    return Card(
      key: ValueKey<String>(key),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  /// The writing zone (`REQ-008`, `REQ-009`): the tracing area over the
  /// handwritten glyph; tapping the grid replays the stroke order with
  /// pronunciation (`TC-TRACE-002`). The area is the shared tracing
  /// canvas (`B15`): capture and rendering have one source; the zone adds
  /// the hint overlay and the playback.
  Widget _writingZone(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final glyph = _glyph;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _replayFromGrid,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _playController,
                builder: (context, _) => TracingCanvas(
                  key: _canvasKey,
                  areaKey: const ValueKey('tracing-area'),
                  model: glyph?.strokes ?? const <List<Offset>>[],
                  playedStroke: _playing ? _playedStroke() : -1,
                  playFraction: _playing ? _playController.value : 0,
                  onChanged: (strokes) =>
                      setState(() => _hasStrokes = strokes.isNotEmpty),
                ),
              ),
              if (!_hasStrokes)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        '在此描摹',
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
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              key: const ValueKey('writing-clear'),
              onPressed: !_hasStrokes
                  ? null
                  : () => _canvasKey.currentState?.clear(),
              icon: const Icon(Icons.restart_alt),
              label: const Text('清除'),
            ),
            const Spacer(),
            _strokeControl(context),
          ],
        ),
      ],
    );
  }

  /// The stroke-order playback state (`REQ-009`): playing indicator while
  /// the animation runs; phonemes without stroke data show the fixed
  /// preparing label — playback disabled, independent of the tracing area
  /// (`TC-TRACE-002`). Replay is the grid tap, not a separate control.
  Widget _strokeControl(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final glyph = _glyph;
    if (glyph == null || glyph.strokes.isEmpty) {
      return Text(
        '笔顺准备中',
        key: const ValueKey('stroke-pending'),
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
    final count = _glyph?.strokes.length ?? 0;
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
  Widget _mouthSlot(BuildContext context, PhonemeExamples? data) {
    final hasImage = data != null && data.mouth.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: hasImage
            ? Image.asset(
                data.mouth,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _mouthPending(context),
              )
            : _mouthPending(context),
      ),
    );
  }

  Widget _mouthPending(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      key: const ValueKey('mouth-pending'),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '口型图准备中',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
      ),
    );
  }

  /// The 2×2 example cards (`REQ-010`): image slot + word/sentence, no
  /// translation; a missing image keeps the word/sentence visible and shows
  /// the same-size placeholder — cards are never hidden (`TC-CONTENT-003`).
  Widget _exampleGrid(BuildContext context, PhonemeExamples? data) {
    final items = data?.examples ?? const <ExampleItem>[];
    return GridView.count(
      key: const ValueKey('example-grid'),
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.8,
      children: [
        for (var i = 0; i < 4; i++)
          _exampleCard(context, i, i < items.length ? items[i] : null),
      ],
    );
  }

  Widget _exampleCard(BuildContext context, int index, ExampleItem? item) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      key: ValueKey('example-card-$index'),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(child: _exampleImage(context, index, item)),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item?.word ?? '',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item?.sentence ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: outline),
            ),
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

  /// The fixed same-size image placeholder; the word/sentence stays visible
  /// beside it and the card is never hidden (`TC-CONTENT-003`).
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

  /// The pronunciation button in its four fixed states (SDD component table,
  /// `TC-DETAIL-001`); a failure stays inside the audio zone — the other
  /// sections never change with it.
  Widget _audioControl(BuildContext context) {
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
        child: const Text('播放失败，重试'),
      ),
    };
    return Center(child: child);
  }

  /// The handwriting overlay (`REQ-035`, decision 12): a page-level Stack
  /// overlay, not a Navigator route — the grey handwritten model with the
  /// cross guides behind the pointer strokes, clear-and-rewrite, done
  /// returns to the detail page. It never produces a score or verdict;
  /// scoring stays with the writing task (`REQ-018`).
  Widget _handwritingOverlay(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final glyph = _glyph;
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
                    Text('手写练习', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Semantics(
                      excludeSemantics: true,
                      label: _spokenLabel,
                      child: Text(
                        _entry.printGlyph,
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
                        model: glyph?.strokes ?? const <List<Offset>>[],
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
                      label: const Text('清除重写'),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('overlay-done'),
                      onPressed: () => setState(() => _overlayOpen = false),
                      child: const Text('完成'),
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

/// The cross guides of the handwriting overlay (`REQ-035`, decision 12):
/// a faint vertical and horizontal centre line behind the grey model.
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
