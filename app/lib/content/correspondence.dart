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

  /// The KK booklet title the data file credits (`REQ-001`); the split
  /// attribution keeps it as the data-side source record, and the About
  /// page renders the design spec's fixed notes instead of composing one.
  final String sourceTitle;
  final List<String> sourceRefs;

  /// The ISBN slot (`REQ-001`, decision 7) of the KK booklet edition the
  /// bundled data credits; `null` when a data file carries no ISBN.
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
  final title = (source['title'] as String?) ?? '';
  // The split attribution carries no reference list, so the label is the
  // title alone — an empty list must never render an empty bracket pair.
  final sourceLabel = refs.isEmpty ? title : '$title（${refs.join('；')}）';

  final mappings = (data['mappings'] as List<dynamic>)
      .map((item) => _mappingFromJson(item as Map<String, dynamic>))
      .toList();

  return CorrespondenceTable(
    version: data['version'] as String,
    sourceKind: source['kind'] as String,
    sourceLabel: sourceLabel,
    sourceTitle: title,
    sourceRefs: refs,
    // The KK booklet's ISBN; the split attribution credits DJ and IPA as
    // international notation, so no second source record is carried.
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
