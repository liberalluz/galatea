import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Content layer: bundled KK/DJ/IPA correspondence table (ADR-0001, ADR-0004).
///
/// The mapping lives entirely in the data file: editing
/// `assets/content/correspondence.v1.json` changes the loaded mapping without
/// a code change (`REQ-012`, `TC-CONTENT-001`). This layer never imports
/// domain or UI types.

class CorrespondenceMapping {
  const CorrespondenceMapping({
    required this.id,
    required this.kk,
    required this.dj,
    required this.ipa,
  });

  final String id;
  final String kk;
  final String dj;
  final String ipa;
}

class CorrespondenceTable {
  const CorrespondenceTable({
    required this.version,
    required this.sourceKind,
    required this.sourceLabel,
    required this.sourceRefs,
    required this.mappings,
    this.sourceTitle = '',
    this.isbn,
  });

  final String version;
  final String sourceKind;
  final String sourceLabel;

  /// The data file's source title on its own (`REQ-001`): the About page
  /// renders it with its own copy-table labels.
  final String sourceTitle;
  final List<String> sourceRefs;

  /// The ISBN slot (`REQ-001`, decision 7): reserved in the data
  /// structure for the licensed booklet edition; `null` while the bundled
  /// data is the contingency public-tables labelling, and the About page
  /// renders the contingency notice instead of an ISBN row.
  final String? isbn;
  final List<CorrespondenceMapping> mappings;
}

const String _kCorrespondenceAssetPath =
    'assets/content/correspondence.v1.json';

Future<CorrespondenceTable> loadCorrespondence() async {
  final raw = await rootBundle.loadString(_kCorrespondenceAssetPath);
  final data = jsonDecode(raw) as Map<String, dynamic>;

  final source = data['source'] as Map<String, dynamic>;
  final refs = (source['refs'] as List<dynamic>).cast<String>();
  final sourceLabel = '${source['title']}（${refs.join('；')}）';

  final mappings = (data['mappings'] as List<dynamic>)
      .map((item) => _mappingFromJson(item as Map<String, dynamic>))
      .toList();

  return CorrespondenceTable(
    version: data['version'] as String,
    sourceKind: source['kind'] as String,
    sourceLabel: sourceLabel,
    sourceTitle: (source['title'] as String?) ?? '',
    sourceRefs: refs,
    // The slot reads the optional key; the bundled contingency file
    // carries none, so the About page shows the contingency notice.
    isbn: source['isbn'] as String?,
    mappings: mappings,
  );
}

CorrespondenceMapping _mappingFromJson(Map<String, dynamic> json) {
  return CorrespondenceMapping(
    id: json['id'] as String,
    kk: json['kk'] as String,
    dj: json['dj'] as String,
    ipa: json['ipa'] as String,
  );
}
