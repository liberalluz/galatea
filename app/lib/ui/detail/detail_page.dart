import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/examples.dart';
import '../../content/phoneme_catalog.dart';

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
/// cards are never hidden (`TC-DETAIL-002`, `TC-CONTENT-003`).

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.catalog,
    required this.initialId,
    this.audioService,
    this.examples,
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

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late int _index = widget.catalog.entries.indexWhere(
    (entry) => entry.id == widget.initialId,
  );

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
    super.dispose();
  }

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
    });
  }

  void _select(String id) {
    _audio.stop();
    setState(() {
      _index = widget.catalog.entries.indexWhere((entry) => entry.id == id);
    });
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
