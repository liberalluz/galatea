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
  });

  final String version;
  final String sourceKind;
  final String sourceLabel;
  final List<String> sourceRefs;
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
    sourceRefs: refs,
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
