import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

/// Handwritten glyph and stroke-order data for the writing zone
/// (`B10`, `ADR-0003`). Bundled, versioned and independent of app code
/// (`SDD` §3.6): every phoneme carries an ordered list of simplified
/// strokes as normalized polylines (coordinates in the 0–1 square), the
/// handwritten model drawn by the tracing area and played stroke by
/// stroke by the stroke-order control. Phonemes missing an entry show
/// the fixed preparing state (`TC-TRACE-002`).
class PhonemeGlyph {
  const PhonemeGlyph({required this.strokes});

  /// Ordered strokes; together they compose the handwritten glyph.
  final List<List<Offset>> strokes;
}

class GlyphData {
  const GlyphData({
    required this.version,
    required this.sourceLabel,
    required this.entries,
  });

  final String version;
  final String sourceLabel;
  final Map<String, PhonemeGlyph> entries;
}

const String _kGlyphsAssetPath = 'assets/content/glyphs.v1.json';

Future<GlyphData> loadGlyphs() async {
  final raw = await rootBundle.loadString(_kGlyphsAssetPath);
  final data = jsonDecode(raw) as Map<String, dynamic>;

  final source = data['source'] as Map<String, dynamic>;
  final sourceLabel = source['label'] as String? ?? '';

  Offset point(Object? row) {
    final pair = row as List<dynamic>;
    return Offset((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
  }

  final entries = <String, PhonemeGlyph>{};
  for (final row in (data['phonemes'] as List<dynamic>)) {
    final map = row as Map<String, dynamic>;
    final id = map['id'] as String;
    final strokes = [
      for (final stroke in (map['strokes'] as List<dynamic>))
        [for (final p in (stroke as List<dynamic>)) point(p)],
    ];
    entries[id] = PhonemeGlyph(strokes: strokes);
  }

  return GlyphData(
    version: data['version'] as String,
    sourceLabel: sourceLabel,
    entries: entries,
  );
}
