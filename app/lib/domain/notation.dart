/// Domain layer: notation systems and the glyph resolution rule.
///
/// KK is the default (`REQ-003`). The resolver implements the SDD §3.2
/// fallback: a phoneme whose glyph is missing in the target notation keeps
/// the previous notation's glyph. This layer never imports UI or content
/// types.
library;

enum Notation { kk, dj, ipa }

/// The notation abbreviations are language-neutral identifiers (`ADR-0001`),
/// so they stay a fixed map rather than copy-table entries. One map feeds the
/// chart's switch, the Me tab's filter chips and the About page's row labels;
/// the notation name is a label, not a value the page composes.
const Map<Notation, String> notationLabels = {
  Notation.kk: 'KK',
  Notation.dj: 'DJ',
  Notation.ipa: 'IPA',
};

/// The label of a row that covers DJ and IPA together — the About page's
/// source row reads `KK` on one row and `DJ / IPA` on the next (`A19`), so the
/// pair is spelled from the same identifiers instead of a new literal.
String djIpaLabel() =>
    '${notationLabels[Notation.dj]} / '
    '${notationLabels[Notation.ipa]}';

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
