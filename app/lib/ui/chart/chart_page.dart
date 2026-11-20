import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/correspondence.dart';
import '../../content/examples.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../../domain/mastery_controller.dart';
import '../../domain/notation.dart';
import '../detail/detail_page.dart';

/// Chart page: 5-column print-glyph grid grouped by phonetic category
/// (`REQ-002`, wireframe P1). A notation switch (KK / DJ / IPA) sits above
/// the grid; KK is the default and switching re-renders the symbols while
/// the selected phoneme stays selected (`REQ-003`, `TC-CHART-003`).
/// Tapping a symbol opens the detail route in the default state
/// (`REQ-004`); in reading mode (`REQ-005`, wireframe P2) the tap plays the
/// phoneme's audio through the audio service and stays on the chart, the
/// fixed hint line shows above the grid while the mode is on, and a failed
/// playback shows the short failure notice without ever navigating.

/// Chinese titles for the phonetic category groups, keyed by the catalog's
/// `group` field. Shared with the practice range selection (`REQ-015`), so
/// both screens label the same categories identically.
const Map<String, String> kGroupTitles = {
  'front': '元音·前',
  'central': '元音·中',
  'back': '元音·后',
  'bilabial': '辅音·双唇',
  'labiodental': '辅音·唇齿',
  'dental': '辅音·齿',
  'alveolar': '辅音·齿龈',
  'postalveolar': '辅音·齿龈后',
  'palatal': '辅音·硬腭',
  'velar': '辅音·软腭',
  'glottal': '辅音·声门',
};

const Map<Notation, String> _kNotationLabels = {
  Notation.kk: 'KK',
  Notation.dj: 'DJ',
  Notation.ipa: 'IPA',
};

class ChartPage extends StatefulWidget {
  const ChartPage({
    super.key,
    this.catalogFuture,
    this.correspondenceFuture,
    this.examplesFuture,
    this.glyphsFuture,
    this.audioService,
    this.readingMode = false,
    this.mastery,
  });

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<PhonemeCatalog>? catalogFuture;
  final Future<CorrespondenceTable>? correspondenceFuture;

  /// Injectable example data (`B9`); production loads the bundled asset.
  final Future<ExamplesData>? examplesFuture;

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<GlyphData>? glyphsFuture;

  /// Injectable audio service (ADR-0002 interface); defaults to the
  /// platform provider when omitted.
  final AudioService? audioService;

  /// Reading mode (`REQ-005`): owned by the shell's top-right switch; on,
  /// grid taps play audio and stay; off, they navigate to detail.
  final bool readingMode;

  /// The shell-owned mastery controller (`B18`); handed to the detail
  /// page for the star rating row. `null` keeps the row absent.
  final MasteryController? mastery;

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final Future<PhonemeCatalog> _catalog =
      widget.catalogFuture ?? loadPhonemeCatalog();
  late final Future<CorrespondenceTable?> _correspondence =
      widget.correspondenceFuture ?? loadCorrespondence();
  late final Future<ExamplesData?> _examples =
      widget.examplesFuture ?? loadExamples();
  late final Future<GlyphData?> _glyphData =
      widget.glyphsFuture ?? loadGlyphs();
  late final AudioService _audio =
      widget.audioService ?? createDefaultAudioService();

  Notation _notation = Notation.kk;
  String? _selectedId;
  PhonemeCatalogEntry? _lastPlayed;

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
    if (!mounted) {
      return;
    }
    if (_audio.state.value == AudioPlaybackState.failed &&
        _lastPlayed != null) {
      final entry = _lastPlayed!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('播放失败，重试'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () => _playAudio(entry),
          ),
        ),
      );
    }
  }

  void _playAudio(PhonemeCatalogEntry entry) {
    _lastPlayed = entry;
    _audio.play(entry.id, entry.tts.isEmpty ? entry.id : entry.tts);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object?>>(
      future: Future.wait<Object?>([
        _catalog,
        _correspondence,
        _examples,
        _glyphData,
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final catalog = snapshot.data![0] as PhonemeCatalog;
        final correspondence = snapshot.data![1] as CorrespondenceTable?;
        final examples = snapshot.data![2] as ExamplesData?;
        final glyphData = snapshot.data![3] as GlyphData?;
        final glyphs = <String, String>{
          for (final m
              in correspondence?.mappings ?? const <CorrespondenceMapping>[])
            m.id: resolveGlyph(
              kk: m.kk,
              dj: m.dj,
              ipa: m.ipa,
              notation: _notation,
            ),
        };
        return Column(
          children: [
            if (widget.readingMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '直读模式：点按只发音',
                    key: const ValueKey('reading-hint'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<String>(
                key: const ValueKey('notation-switch'),
                segments: [
                  for (final n in Notation.values)
                    ButtonSegment<String>(
                      value: n.name,
                      label: Text(_kNotationLabels[n]!),
                    ),
                ],
                selected: {_notation.name},
                onSelectionChanged: (selection) {
                  setState(() {
                    _notation = Notation.values.byName(selection.first);
                  });
                },
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('chart-grid'),
                padding: const EdgeInsets.all(16),
                children: [
                  for (final group in _groupedEntries(catalog.entries))
                    ..._groupWidgets(
                      context,
                      group,
                      glyphs,
                      catalog,
                      examples,
                      glyphData,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    '来源：${catalog.sourceLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Groups entries preserving the catalog order; no row crosses a group.
  static List<MapEntry<String, List<PhonemeCatalogEntry>>> _groupedEntries(
    List<PhonemeCatalogEntry> entries,
  ) {
    final groups = <String, List<PhonemeCatalogEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.group, () => []).add(entry);
    }
    return groups.entries.toList();
  }

  List<Widget> _groupWidgets(
    BuildContext context,
    MapEntry<String, List<PhonemeCatalogEntry>> group,
    Map<String, String> glyphs,
    PhonemeCatalog catalog,
    ExamplesData? examples,
    GlyphData? glyphData,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          kGroupTitles[group.key] ?? group.key,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _groupTable(context, group.value, glyphs, catalog, examples, glyphData),
    ];
  }

  Table _groupTable(
    BuildContext context,
    List<PhonemeCatalogEntry> entries,
    Map<String, String> glyphs,
    PhonemeCatalog catalog,
    ExamplesData? examples,
    GlyphData? glyphData,
  ) {
    const columns = 5;
    final rows = <TableRow>[];
    for (var i = 0; i < entries.length; i += columns) {
      final chunk = entries.sublist(
        i,
        i + columns > entries.length ? entries.length : i + columns,
      );
      final cells = <Widget>[
        for (final entry in chunk)
          _glyphCell(
            context,
            entry,
            glyphs[entry.id] ?? entry.printGlyph,
            catalog,
            examples,
            glyphData,
          ),
        // Pad the last row so it stays left-aligned inside the 5-column grid.
        for (var pad = chunk.length; pad < columns; pad++) const SizedBox(),
      ];
      rows.add(TableRow(children: cells));
    }
    return Table(
      children: rows,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    );
  }

  Widget _glyphCell(
    BuildContext context,
    PhonemeCatalogEntry entry,
    String glyph,
    PhonemeCatalog catalog,
    ExamplesData? examples,
    GlyphData? glyphData,
  ) {
    final selected = _selectedId == entry.id;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        key: ValueKey('phoneme-${entry.id}'),
        onTap: () {
          setState(() {
            _selectedId = entry.id;
          });
          if (widget.readingMode) {
            // Reading mode (`REQ-005`): play audio, never navigate — even a
            // failed playback keeps the tap on the chart (wireframe P2).
            _playAudio(entry);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DetailPage(
                catalog: catalog,
                initialId: entry.id,
                examples: examples,
                glyphs: glyphData,
                mastery: widget.mastery,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          key: selected ? ValueKey('phoneme-${entry.id}-selected') : null,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(glyph, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }
}
