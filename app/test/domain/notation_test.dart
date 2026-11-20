import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/domain/notation.dart';

void main() {
  group('resolveGlyph', () {
    test('returns the notation glyph when present', () {
      expect(
        resolveGlyph(kk: 'e', dj: 'eɪ', ipa: 'eɪ', notation: Notation.dj),
        'eɪ',
      );
    });

    test('falls back to KK when the DJ glyph is missing', () {
      expect(
        resolveGlyph(kk: 'e', dj: '', ipa: 'eɪ', notation: Notation.dj),
        'e',
      );
    });

    test('falls back to DJ when the IPA glyph is missing', () {
      expect(
        resolveGlyph(kk: 'aɪ', dj: 'aɪ', ipa: '', notation: Notation.ipa),
        'aɪ',
      );
    });

    test('falls back to KK when DJ and IPA are both missing', () {
      expect(
        resolveGlyph(kk: 'ŋ', dj: '', ipa: '', notation: Notation.ipa),
        'ŋ',
      );
    });
  });
}
