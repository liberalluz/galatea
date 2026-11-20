/// Domain layer: notation systems and the glyph resolution rule.
///
/// KK is the default (`REQ-003`). The resolver implements the SDD §3.2
/// fallback: a phoneme whose glyph is missing in the target notation keeps
/// the previous notation's glyph. This layer never imports UI or content
/// types.
library;

enum Notation { kk, dj, ipa }

/// Returns the print glyph for [notation]; when that glyph is missing
/// (empty), falls back through the previous notations down to KK.
String resolveGlyph({
  required String kk,
  required String dj,
  required String ipa,
  required Notation notation,
}) {
  final glyphs = <String>[kk, dj, ipa];
  const order = [Notation.kk, Notation.dj, Notation.ipa];
  for (var i = order.indexOf(notation); i >= 0; i--) {
    final glyph = glyphs[i];
    if (glyph.isNotEmpty) {
      return glyph;
    }
  }
  return kk;
}
