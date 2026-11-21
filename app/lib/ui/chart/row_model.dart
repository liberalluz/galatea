import '../../content/phoneme_catalog.dart';

/// The shared row model (`SDD §3.2`, `B25`/`B26`): one row definition
/// serves the chart grid, the B27 row-select mode and the B28 detail
/// circles, so all three surfaces split the catalog identically.
///
/// The chart displays only the two coarse group headers (`REQ-002`):
/// the fine place-of-articulation labels stay in the data but are never
/// rendered. Within a coarse group the catalog order (which is already
/// the place-of-articulation order) is preserved across fine groups,
/// rows carry 5 phonemes and the last row holds its actual count.

/// The grid column count (`REQ-002`, wireframe P1).
const int kColumns = 5;

/// The two coarse group headers as displayed (`REQ-002`, decision 1).
const String kVowelHeader = '元音';
const String kConsonantHeader = '辅音';

/// The fine group order inside each coarse group; the chart never shows
/// these labels, but the order defines how rows fall across the group
/// boundaries.
const List<String> kVowelGroupOrder = ['front', 'central', 'back'];
const List<String> kConsonantGroupOrder = [
  'bilabial',
  'labiodental',
  'dental',
  'alveolar',
  'postalveolar',
  'palatal',
  'velar',
  'glottal',
];

/// All entries of one coarse group in display order: the fine groups are
/// concatenated in [kVowelGroupOrder] / [kConsonantGroupOrder] sequence,
/// entries inside a fine group keep their catalog order.
List<PhonemeCatalogEntry> coarseEntries(
  PhonemeKind kind,
  List<PhonemeCatalogEntry> entries,
) {
  final order = kind == PhonemeKind.vowel
      ? kVowelGroupOrder
      : kConsonantGroupOrder;
  final byGroup = <String, List<PhonemeCatalogEntry>>{};
  for (final entry in entries) {
    if (entry.kind == kind) {
      byGroup.putIfAbsent(entry.group, () => []).add(entry);
    }
  }
  return [
    for (final group in order)
      ...byGroup[group] ?? const <PhonemeCatalogEntry>[],
  ];
}

/// Splits one coarse group's entries into rows of [kColumns]; the last
/// row holds its actual count (`REQ-002`, decision 1).
List<List<PhonemeCatalogEntry>> rowsFor(List<PhonemeCatalogEntry> entries) {
  final rows = <List<PhonemeCatalogEntry>>[];
  for (var i = 0; i < entries.length; i += kColumns) {
    rows.add(
      entries.sublist(
        i,
        i + kColumns > entries.length ? entries.length : i + kColumns,
      ),
    );
  }
  return rows;
}

/// Rows for one coarse group kind, in one call.
List<List<PhonemeCatalogEntry>> rowsForKind(
  PhonemeKind kind,
  List<PhonemeCatalogEntry> entries,
) => rowsFor(coarseEntries(kind, entries));
