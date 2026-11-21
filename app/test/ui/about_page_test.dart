import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/content/correspondence.dart';
import 'package:galatea/ui/me/about_page.dart';

CorrespondenceTable fakeCorrespondence() => CorrespondenceTable(
  version: 'test-v1',
  sourceKind: 'public-tables',
  sourceLabel: 'test source',
  sourceTitle: 'KK–DJ–IPA 公开对照表',
  sourceRefs: const [],
  mappings: const [],
);

Future<void> pumpAbout(
  WidgetTester tester, {
  CorrespondenceTable? correspondence,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AboutPage(
        correspondenceFuture: Future<CorrespondenceTable>.value(
          correspondence ?? fakeCorrespondence(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'the about page carries the version, source label, oss note, feedback and the device-only disclosure',
    (tester) async {
      await pumpAbout(tester);

      // Version line with the app metadata value.
      expect(find.byKey(const ValueKey('about-version')), findsOneWidget);
      expect(find.textContaining('0.2.0'), findsOneWidget);

      // The single-source label renders the data files' title plus the
      // contingency labelling (public tables until licensed); the ISBN
      // slot is reserved in the data structure, so no ISBN row here.
      expect(find.byKey(const ValueKey('about-source')), findsOneWidget);
      expect(find.textContaining('KK'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('about-source-contingency')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('about-isbn')), findsNothing);

      // The oss note, the feedback entry and the device-only limitation
      // disclosure all render.
      expect(find.byKey(const ValueKey('about-oss')), findsOneWidget);
      expect(find.byKey(const ValueKey('about-feedback')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('about-device-disclosure')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a licensed data file with an ISBN renders the ISBN row instead of the contingency label',
    (tester) async {
      await pumpAbout(
        tester,
        correspondence: CorrespondenceTable(
          version: 'test-v1',
          sourceKind: 'booklet',
          sourceLabel: 'test source',
          sourceRefs: const [],
          mappings: const [],
          isbn: '978-7-000-00000-0',
        ),
      );

      expect(find.byKey(const ValueKey('about-isbn')), findsOneWidget);
      expect(find.textContaining('978-7-000-00000-0'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('about-source-contingency')),
        findsNothing,
      );
    },
  );
}
