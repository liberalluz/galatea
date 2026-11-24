import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Example word/sentence data for the detail page (`B9`, `TC-DETAIL-003`).
/// Bundled, versioned and independent of app code (`SDD` §3.6); every entry
/// carries optional asset paths (`mouth`, per-example `image`) that are empty
/// while the licensed artwork is missing — the UI renders fixed placeholders
/// of the same size instead (`TC-DETAIL-002`, `TC-CONTENT-003`).
class ExampleItem {
  const ExampleItem({
    required this.word,
    required this.sentence,
    this.image = '',
  });

  final String word;
  final String sentence;

  /// Optional image asset path; empty while the artwork is missing.
  final String image;
}

class PhonemeExamples {
  const PhonemeExamples({
    required this.id,
    required this.examples,
    this.mouth = '',
    this.displayForm = 'word',
  });

  final String id;
  final List<ExampleItem> examples;

  /// Optional mouth-shape asset path; empty while the artwork is missing.
  final String mouth;

  /// Which text the detail page's example cards show for this phoneme
  /// (`REQ-010`): either the word or the sentence, never both. The marker
  /// sits on the phoneme, so the phoneme's four cards share one form. The
  /// bundled data marks every phoneme as a word, which matches the
  /// competitor's example cards.
  final String displayForm;

  /// Whether this phoneme's cards show the sentence rather than the word.
  bool get showsSentence => displayForm == 'sentence';
}

class ExamplesData {
  const ExamplesData({
    required this.version,
    required this.sourceLabel,
    required this.entries,
  });

  final String version;
  final String sourceLabel;
  final Map<String, PhonemeExamples> entries;
}

const String _kExamplesAssetPath = 'assets/content/examples.v1.json';

Future<ExamplesData> loadExamples() async {
  final raw = await rootBundle.loadString(_kExamplesAssetPath);
  final data = jsonDecode(raw) as Map<String, dynamic>;

  final source = data['source'] as Map<String, dynamic>;
  final sourceLabel = source['label'] as String? ?? '';

  final entries = <String, PhonemeExamples>{};
  for (final row in (data['phonemes'] as List<dynamic>)) {
    final map = row as Map<String, dynamic>;
    final id = map['id'] as String;
    final examples = [
      for (final item in (map['examples'] as List<dynamic>))
        ExampleItem(
          word: item['word'] as String,
          sentence: item['sentence'] as String,
          image: item['image'] as String? ?? '',
        ),
    ];
    entries[id] = PhonemeExamples(
      id: id,
      examples: examples,
      mouth: map['mouth'] as String? ?? '',
      displayForm: map['displayForm'] as String? ?? 'word',
    );
  }

  return ExamplesData(
    version: data['version'] as String,
    sourceLabel: sourceLabel,
    entries: entries,
  );
}
