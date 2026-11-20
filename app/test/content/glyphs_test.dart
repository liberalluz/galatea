import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/glyphs.dart';
import 'package:galatea/content/phoneme_catalog.dart';

/// B10 glyph-data contracts (`ADR-0003`, `TC-CONTENT-002`): every catalog
/// phoneme carries handwritten stroke data in the bundled versioned file,
/// authored as normalized polylines, editable without a code change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the glyph data loads 48 phonemes with ordered stroke data', () async {
    final catalog = await loadPhonemeCatalog();
    final glyphs = await loadGlyphs();
    expect(glyphs.version, 'glyphs.v1');
    expect(glyphs.entries.length, 48);
    for (final entry in catalog.entries) {
      final strokes = glyphs.entries[entry.id]?.strokes;
      expect(
        strokes,
        isNotNull,
        reason: 'the handwritten glyph for ${entry.id} is missing',
      );
      expect(
        strokes!.length,
        greaterThanOrEqualTo(1),
        reason: '${entry.id} needs at least one ordered stroke',
      );
      for (final stroke in strokes) {
        expect(
          stroke.length,
          greaterThanOrEqualTo(2),
          reason: 'a stroke of ${entry.id} is too short to draw',
        );
        for (final point in stroke) {
          expect(point.dx, inInclusiveRange(0, 1));
          expect(point.dy, inInclusiveRange(0, 1));
        }
      }
    }
  });
}
