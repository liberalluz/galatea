import 'package:flutter/material.dart';

import '../../audio/audio_service.dart';
import '../../content/correspondence.dart';
import '../../content/examples.dart';
import '../../content/glyphs.dart';
import '../../content/phoneme_catalog.dart';
import '../../domain/mastery_controller.dart';
import '../../domain/notation.dart';
import '../detail/detail_page.dart';
import 'row_model.dart';

/// Chart page: 5-column print-glyph grid under the two coarse group
/// headers 元音 / 辅音 (`REQ-002`, wireframe P1, decision 1) — the fine
/// place-of-articulation labels stay in the data but are never rendered,
/// and rows follow the shared row model (`row_model.dart`): 5 per row,
/// the last row at its actual count. A notation switch (KK / DJ / IPA)
/// sits above the grid; KK is the default and switching re-renders the
/// symbols while the selected phoneme stays selected (`REQ-003`,
/// `TC-CHART-003`). Tapping a symbol opens the detail route in the
/// default state (`REQ-004`); in reading mode (`REQ-005`, wireframe P2)
/// the tap plays the phoneme's audio through the audio service and stays
/// on the chart, the grey status hint strip is permanently part of the
/// scaffold and visible only while the mode is on (decision 2026-11-21,
/// A13), its tap deep-links to the Me tab (`REQ-022` landing, review
/// page follows in B29), and a failed playback shows the short failure
/// notice without ever navigating. The chart carries no source footer:
/// the attribution lives only on the About page (`REQ-001`, decision 7).

/// Chinese titles for the phonetic category groups, keyed by the catalog's
/// `group` field. No longer rendered by the chart (only the two coarse
/// headers show, `REQ-002`); kept as the practice range-selection label
/// source (`REQ-015` legacy screen) until B27 replaces that flow.
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
    this.onReviewDeepLink,
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

  /// The Me-tab deep link for the status hint strip (`REQ-022` landing,
  /// B26 scope): the strip tap switches to the Me tab; the review page
  /// itself lands in B29. `null` leaves the strip inert (unit harnesses).
  final VoidCallback? onReviewDeepLink;

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
            // The grey status hint strip (decision 2026-11-21, A13):
            // permanently part of the scaffold, visible only while the
            // reading mode is on, tap deep-links to the Me tab.
            Visibility(
              visible: widget.readingMode,
              maintainState: true,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  key: const ValueKey('reading-hint-strip'),
                  onTap: widget.onReviewDeepLink,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '直读模式：点按只发音',
                        key: const ValueKey('reading-hint'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
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
                  // Two coarse groups only (`REQ-002`, decision 1): the
                  // fine labels are data, never rendered.
                  ..._coarseGroupWidgets(
                    context,
                    PhonemeKind.vowel,
                    catalog,
                    glyphs,
                    examples,
                    glyphData,
                  ),
                  ..._coarseGroupWidgets(
                    context,
                    PhonemeKind.consonant,
                    catalog,
                    glyphs,
                    examples,
                    glyphData,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// One coarse group = its header plus the shared-row-model table.
  /// Rows follow `row_model.dart`: 5 per row across the fine groups, the
  /// last row at its actual count.
  List<Widget> _coarseGroupWidgets(
    BuildContext context,
    PhonemeKind kind,
    PhonemeCatalog catalog,
    Map<String, String> glyphs,
    ExamplesData? examples,
    GlyphData? glyphData,
  ) {
    final rows = rowsForKind(kind, catalog.entries);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          kind == PhonemeKind.vowel ? kVowelHeader : kConsonantHeader,
          key: ValueKey(
            'group-header-${kind == PhonemeKind.vowel ? 'vowel' : 'consonant'}',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _coarseGroupTable(
        context,
        kind,
        rows,
        glyphs,
        catalog,
        examples,
        glyphData,
      ),
    ];
  }

  Widget _coarseGroupTable(
    BuildContext context,
    PhonemeKind kind,
    List<List<PhonemeCatalogEntry>> rows,
    Map<String, String> glyphs,
    PhonemeCatalog catalog,
    ExamplesData? examples,
    GlyphData? glyphData,
  ) {
    final tableRows = <TableRow>[
      for (final row in rows)
        TableRow(
          children: [
            for (final entry in row)
              _glyphCell(
                context,
                entry,
                glyphs[entry.id] ?? entry.printGlyph,
                catalog,
                examples,
                glyphData,
              ),
            // Pad the last row so it stays left-aligned inside the grid;
            // the row itself holds only its actual phoneme count.
            for (var pad = row.length; pad < kColumns; pad++) const SizedBox(),
          ],
        ),
    ];
    return _narrowGuard(
      Table(
        key: ValueKey(
          'chart-table-${kind == PhonemeKind.vowel ? 'vowel' : 'consonant'}',
        ),
        children: tableRows,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      ),
    );
  }

  /// The floor width of one grid cell (`B20`, `TC-QUAL-002`): five
  /// columns never fold and every cell keeps at least this width, so the
  /// grid's minimum width is [kMinGridWidth].
  static const double kMinCellWidth = 72;

  /// The grid's minimum width; below it the grid scrolls horizontally.
  static const double kMinGridWidth = kMinCellWidth * 5;

  /// The narrow-screen guard (`B20`, `TC-QUAL-002`, ux-flows R28 failure
  /// branch): on a viewport too narrow for the five columns the grid
  /// scrolls horizontally instead of squeezing — no column folds, no
  /// phoneme clips, the glyph size stays readable. The cell width is
  /// floor-set rather than measured, so the first frame needs no
  /// re-layout pass (the R28 empty state).
  Widget _narrowGuard(Widget table) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kMinGridWidth) {
          return SingleChildScrollView(
            key: const ValueKey('grid-scroll'),
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: kMinGridWidth, child: table),
          );
        }
        return table;
      },
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
          // The symbol reads its spoken text to screen readers, falling
          // back to the phoneme id when the spoken text is empty
          // (TC-QUAL-004, REQ-030, ux-flows R30).
          child: Semantics(
            excludeSemantics: true,
            label: entry.tts.isNotEmpty ? entry.tts : entry.id,
            child: Text(glyph, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
      ),
    );
  }
}
