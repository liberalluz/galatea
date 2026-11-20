import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/examples.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../../domain/mastery_controller.dart';
import '../writing/tracing_canvas.dart';

/// Detail page: the zone skeleton (audio -> mouth -> writing -> words) in the
/// fixed section order (`wireframe P3`, `SDD` layout) with the horizontal
/// phoneme switcher at the top. The switcher is a strip of phoneme chips with
/// the current chip highlighted plus prev/next arrows (`REQ-011`); prev/next
/// move to the adjacent phoneme in catalog order and refresh every section;
/// at the ends the respective arrow is disabled and does not wrap
/// (`TC-DETAIL-004`). The pronunciation button in the audio zone exposes the
/// four fixed states loading / ready / playing / failed (`TC-DETAIL-001`);
/// failures never disable the other sections. The mouth zone shows a
/// mouth-shape slot (`REQ-007`) and the words zone a 2×2 grid of example
/// cards (`REQ-010`); missing assets render fixed same-size placeholders and
/// cards are never hidden (`TC-DETAIL-002`, `TC-CONTENT-003`). The writing
/// zone hosts the tracing area over the handwritten glyph and the
/// stroke-order control (`REQ-008`, `REQ-009`, `ADR-0003`); strokes drawn by
/// the pointer are kept when input is interrupted, and phonemes without
/// stroke data show the fixed preparing state with the control disabled,
/// independent of the tracing area (`TC-TRACE-001`, `TC-TRACE-002`).

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

  /// The full catalog, so prev/next can walk the catalog order.
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

  /// The shell-owned mastery controller (`B18`); when present the star
  /// rating row shows under the phoneme id (ux-flows R23 entry, second
  /// surface). `null` keeps the row absent.
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

  /// Whether the canvas currently holds user strokes; drives the trace
  /// hint and the clear control.
  bool _hasStrokes = false;

  /// Whether the stroke-order animation is playing (`REQ-009`).
  bool _playing = false;

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

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.catalog.entries.length) {
      return;
    }
    _audio.stop();
    setState(() {
      _index = next;
      _resetWriting();
    });
  }

  void _select(String id) {
    _audio.stop();
    setState(() {
      _index = widget.catalog.entries.indexWhere((entry) => entry.id == id);
      _resetWriting();
    });
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

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(title: Text(entry.printGlyph)),
      body: ListView(
        key: const ValueKey('detail-page'),
        padding: const EdgeInsets.all(16),
        children: [
          _switcher(context),
          const SizedBox(height: 16),
          Center(
            child: Text(
              entry.printGlyph,
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(entry.id, style: Theme.of(context).textTheme.bodyLarge),
          ),
          if (widget.mastery != null) ...[
            const SizedBox(height: 8),
            _starRow(context, widget.mastery!),
          ],
          const SizedBox(height: 16),
          _zone(
            context,
            key: 'zone-audio',
            label: '发音区',
            glyph: entry.printGlyph,
            child: _audioControl(context),
          ),
          _zone(
            context,
            key: 'zone-mouth',
            label: '口型区',
            glyph: entry.printGlyph,
            child: _mouthSlot(context, _examples),
          ),
          _zone(
            context,
            key: 'zone-writing',
            label: '书写区',
            glyph: entry.printGlyph,
            child: _writingZone(context),
          ),
          _zone(
            context,
            key: 'zone-words',
            label: '例词例句',
            glyph: entry.printGlyph,
            child: _exampleGrid(context, _examples),
          ),
        ],
      ),
    );
  }

  Widget _switcher(BuildContext context) {
    final entries = widget.catalog.entries;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('switcher-prev'),
          onPressed: _index > 0 ? () => _go(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _chip(context, entries[i], selected: i == _index),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('switcher-next'),
          onPressed: _index < entries.length - 1 ? () => _go(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    PhonemeCatalogEntry entry, {
    required bool selected,
  }) {
    final outline = Theme.of(context).colorScheme.outline;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      key: ValueKey('switcher-chip-${entry.id}'),
      onTap: () => _select(entry.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: selected ? ValueKey('switcher-chip-${entry.id}-selected') : null,
        decoration: BoxDecoration(
          border: Border.all(color: selected ? primary : outline),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          entry.printGlyph,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  /// One zone of the fixed section order; zones with real content (audio,
  /// mouth, words) render their child, the rest keep the skeleton box.
  /// The star rating row (`B18`, ux-flows R23 entry surface 2): the
  /// phoneme's shared 0–3 stars with the mastery label; a degraded
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
                  Icon(i < star ? Icons.star : Icons.star_border, size: 20),
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

  Widget _zone(
    BuildContext context, {
    required String key,
    required String label,
    required String glyph,
    Widget? child,
  }) {
    return Card(
      key: ValueKey<String>(key),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: Text(
                glyph,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            if (child != null)
              child
            else
              Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// The writing zone (`REQ-008`, `REQ-009`): the tracing area over the
  /// handwritten glyph plus the stroke-order control. The control's
  /// preparing state is independent of the tracing area (`TC-TRACE-002`).
  /// The area is the shared tracing canvas (`B15`): capture and rendering
  /// have one source; the zone adds the hint overlay and the playback.
  Widget _writingZone(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final glyph = _glyph;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
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

  /// The stroke-order control (`REQ-009`): ready / playing; phonemes
  /// without stroke data show the fixed preparing label with the control
  /// disabled, independent of the tracing area (`TC-TRACE-002`).
  Widget _strokeControl(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final glyph = _glyph;
    if (glyph == null || glyph.strokes.isEmpty) {
      return Row(
        children: [
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.play_arrow),
            color: outline,
          ),
          Text(
            '笔顺准备中',
            key: const ValueKey('stroke-pending'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: outline),
          ),
        ],
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
    return IconButton(
      key: const ValueKey('stroke-play'),
      onPressed: _playStrokes,
      icon: const Icon(Icons.play_arrow),
    );
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
        height: 140,
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
}
