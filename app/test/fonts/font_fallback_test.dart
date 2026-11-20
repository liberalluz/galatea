import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/main.dart';

void main() {
  group('bundled font fallback chain (TC-QUAL-001, REQ-027)', () {
    test('pubspec registers Noto Sans with the bundled asset and licence', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('family: Noto Sans'),
        isTrue,
        reason: 'the Noto Sans family is registered',
      );
      expect(
        pubspec.contains('assets/fonts/NotoSans-Regular.ttf'),
        isTrue,
        reason: 'the font asset path is registered',
      );
      expect(
        File('assets/fonts/NotoSans-Regular.ttf').existsSync(),
        isTrue,
        reason: 'the font file ships in the repo',
      );
      expect(
        File('assets/fonts/OFL.txt').existsSync(),
        isTrue,
        reason: 'the OFL licence ships next to the font',
      );
    });

    test('the theme heads the fontFamilyFallback chain with Noto Sans', () {
      final fallback = buildTheme().textTheme.bodyMedium?.fontFamilyFallback;
      expect(
        fallback,
        isNotNull,
        reason: 'the theme declares a fallback chain',
      );
      expect(
        fallback!.first,
        'Noto Sans',
        reason: 'the bundled font heads the chain',
      );
    });
  });
}
