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
  const PhonemeGlyph({required this.strokes, this.variants = const {}});

  /// Ordered strokes; together they compose the handwritten glyph.
  final List<List<Offset>> strokes;

  /// The notation-aware skeletons (`REQ-013`, B32): the strokes of the
  /// notations whose letterform differs from the base one — the long
  /// vowels take the extra length stroke, the phonemes whose printed
  /// letterform itself differs carry the other skeleton. A notation
  /// without an entry reuses [strokes].
  final Map<String, List<List<Offset>>> variants;

  /// The strokes of [notation]: its own skeleton when the record carries
  /// one, the shared base strokes otherwise.
  List<List<Offset>> strokesFor(String notation) =>
      variants[notation] ?? strokes;
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
    // The notation-aware skeletons (`REQ-013`): the per-notation stroke
    // lists sit next to the base strokes; a notation without an entry
    // keeps the base strokes.
    final rawVariants = map['variants'] as Map<String, dynamic>?;
    final variants = <String, List<List<Offset>>>{};
    if (rawVariants != null) {
      for (final variant in rawVariants.entries) {
        variants[variant.key] = [
          for (final stroke in (variant.value as List<dynamic>))
            [for (final p in (stroke as List<dynamic>)) point(p)],
        ];
      }
    }
    entries[id] = PhonemeGlyph(strokes: strokes, variants: variants);
  }

  return GlyphData(
    version: data['version'] as String,
    sourceLabel: sourceLabel,
    entries: entries,
  );
}
