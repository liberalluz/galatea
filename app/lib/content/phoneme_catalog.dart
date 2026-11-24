import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Content layer: bundled phoneme catalog (ADR-0001, ADR-0004).
///
/// One entity per phoneme; notations beyond KK arrive as display mappings
/// in a later batch and key off the stable phoneme [PhonemeCatalogEntry.id].
/// This layer never imports domain or UI types.

enum PhonemeKind { vowel, consonant }

class PhonemeCatalogEntry {
  const PhonemeCatalogEntry({
    required this.id,
    required this.kind,
    required this.group,
    required this.printGlyph,
    this.tts = '',
    this.letters = '',
  });

  final String id;
  final PhonemeKind kind;
  final String group;
  final String printGlyph;

  /// Speakable text for TTS synthesis (B7, ADR-0002): the bundled glyphs are
  /// phonetic symbols the browser engines cannot read, so each entry carries
  /// an English approximation. Falls back to the id when absent.
  final String tts;

  /// The spelling fragment that carries this sound in English (`REQ-036`):
  /// the letters highlighted in the phoneme's first example word. The
  /// detail page's mapping row renders it beside the printed symbol, so the
  /// user sees how the sound is spelled next to the sound itself.
  final String letters;
}

class PhonemeCatalog {
  const PhonemeCatalog({
    required this.version,
    required this.sourceLabel,
    required this.entries,
  });

  final String version;
  final String sourceLabel;
  final List<PhonemeCatalogEntry> entries;
}

const String _kCatalogAssetPath = 'assets/content/phoneme_catalog.v1.json';

Future<PhonemeCatalog> loadPhonemeCatalog() async {
  final raw = await rootBundle.loadString(_kCatalogAssetPath);
  final data = jsonDecode(raw) as Map<String, dynamic>;

  final source = data['source'] as Map<String, dynamic>;
  final sourceLabel =
      '${source['author']}《${source['title']}》(ISBN ${source['isbn']})';

  final entries = (data['phonemes'] as List<dynamic>)
      .map((item) => _entryFromJson(item as Map<String, dynamic>))
      .toList();

  return PhonemeCatalog(
    version: data['version'] as String,
    sourceLabel: sourceLabel,
    entries: entries,
  );
}

PhonemeCatalogEntry _entryFromJson(Map<String, dynamic> json) {
  return PhonemeCatalogEntry(
    id: json['id'] as String,
    kind: json['kind'] == 'vowel' ? PhonemeKind.vowel : PhonemeKind.consonant,
    group: json['group'] as String,
    printGlyph: json['kk'] as String,
    tts: (json['tts'] as String?) ?? json['id'] as String,
    letters: (json['letters'] as String?) ?? '',
  );
}
