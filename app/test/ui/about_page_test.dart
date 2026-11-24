import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/copy/app_copy.dart';
import 'package:galatea/settings/settings_controller.dart' show AppLanguage;
import 'package:galatea/ui/me/about_page.dart';

CorrespondenceTable fakeCorrespondence() => const CorrespondenceTable(
  version: 'test-v1',
  sourceKind: 'booklet-split',
  sourceLabel: '赖世雄《美语音标》',
  sourceTitle: '赖世雄《美语音标》',
  sourceRefs: [],
  isbn: '9787119061207',
  mappings: [],
);

Future<void> pumpAbout(
  WidgetTester tester, {
  CorrespondenceTable? correspondence,
  AppLanguage language = AppLanguage.zhCn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CopyScope(
        copy: AppCopy.ofLanguage(language),
        child: AboutPage(
          correspondenceFuture: Future<CorrespondenceTable>.value(
            correspondence ?? fakeCorrespondence(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the about page renders the two split source notes verbatim', (
    tester,
  ) async {
    await pumpAbout(tester);

    // The design spec's copy table hands both notes over verbatim; the page
    // composes nothing from the data at render time.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('about-source-note'))).data,
      'KK 来源：赖世雄《美语音标》ISBN 9787119061207',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('about-notation-note')))
          .data,
      'DJ / IPA 为国际通用音标符号，不来自该教材',
    );
  });

  testWidgets('the about page carries no public-table label or dev note', (
    tester,
  ) async {
    await pumpAbout(tester);

    for (final gone in ['公开对照表', '维基', 'Kenyon & Knott', '待授权数据后替换']) {
      expect(
        find.textContaining(gone),
        findsNothing,
        reason: '$gone must be gone',
      );
    }
    expect(find.byKey(const ValueKey('about-source')), findsNothing);
    expect(find.byKey(const ValueKey('about-isbn')), findsNothing);
    expect(
      find.byKey(const ValueKey('about-source-contingency')),
      findsNothing,
    );
  });

  testWidgets('the English copy table carries the two English notes', (
    tester,
  ) async {
    await pumpAbout(tester, language: AppLanguage.enUs);

    expect(
      find.text(
        'KK source: Lai Shih-hsiung, American Phonetics, ISBN 9787119061207',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'DJ / IPA are international standard notation, not from the book',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the rest of the about page keeps its order', (tester) async {
    await pumpAbout(tester);

    final version = tester
        .getTopLeft(find.byKey(const ValueKey('about-version')))
        .dy;
    final sourceNote = tester
        .getTopLeft(find.byKey(const ValueKey('about-source-note')))
        .dy;
    final notationNote = tester
        .getTopLeft(find.byKey(const ValueKey('about-notation-note')))
        .dy;
    final oss = tester.getTopLeft(find.byKey(const ValueKey('about-oss'))).dy;
    final feedback = tester
        .getTopLeft(find.byKey(const ValueKey('about-feedback')))
        .dy;
    final device = tester
        .getTopLeft(find.byKey(const ValueKey('about-device-disclosure')))
        .dy;

    expect(version, lessThan(sourceNote));
    expect(sourceNote, lessThan(notationNote));
    expect(notationNote, lessThan(oss));
    expect(oss, lessThan(feedback));
    expect(feedback, lessThan(device));
    expect(find.textContaining('0.2.0'), findsOneWidget);
  });
}
