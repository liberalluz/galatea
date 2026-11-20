import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/examples.dart';

/// The bundled examples data (B9, `TC-DETAIL-003`, `TC-CONTENT-003`): every
/// phoneme carries exactly 4 example items with a word and a sentence, so the
/// detail page can always show 4 cards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the examples data loads 48 phonemes with 4 examples each', () async {
    final data = await loadExamples();

    expect(data.version, isNotEmpty);
    expect(data.sourceLabel, isNotEmpty);
    expect(data.entries.length, 48);

    for (final entry in data.entries.values) {
      expect(
        entry.examples.length,
        4,
        reason: 'phoneme ${entry.id} must carry exactly 4 examples',
      );
      for (final item in entry.examples) {
        expect(
          item.word,
          isNotEmpty,
          reason: 'phoneme ${entry.id} has an empty word',
        );
        expect(
          item.sentence,
          isNotEmpty,
          reason: 'phoneme ${entry.id} has an empty sentence',
        );
      }
    }
  });

  test('every catalog phoneme id has an examples entry', () async {
    final data = await loadExamples();
    const catalogIds = [
      'i',
      'ɪ',
      'e',
      'ɛ',
      'æ',
      'aɪ',
      'ɪr',
      'ɛr',
      'ɪə',
      'iə',
      'ʌ',
      'ə',
      'ɝ',
      'ɚ',
      'ɑ',
      'ɑr',
      'ɔ',
      'ɔr',
      'ɔɪ',
      'o',
      'u',
      'ʊ',
      'ʊr',
      'aʊ',
      'p',
      'b',
      'm',
      'w',
      'f',
      'v',
      'θ',
      'ð',
      't',
      'd',
      's',
      'z',
      'n',
      'l',
      'ʃ',
      'ʒ',
      'tʃ',
      'dʒ',
      'r',
      'j',
      'k',
      'g',
      'ŋ',
      'h',
    ];
    for (final id in catalogIds) {
      expect(
        data.entries.containsKey(id),
        isTrue,
        reason: 'examples data misses phoneme $id',
      );
    }
  });
}
