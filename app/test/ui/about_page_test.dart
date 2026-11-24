import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galatea/copy/app_copy.dart';
import 'package:galatea/settings/settings_controller.dart' show AppLanguage;
import 'package:galatea/ui/me/about_page.dart';

Future<void> pumpAbout(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.zhCn,
  LinkLauncher? launcher,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: CopyScope(
        copy: AppCopy.ofLanguage(language),
        child: AboutPage(launcher: launcher),
      ),
    ),
  );
  await tester.pump();
}

Text labelOf(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(ValueKey('about-label-$id')));

double leftOf(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dx;

void main() {
  testWidgets('the page renders the three groups in the design order', (
    tester,
  ) async {
    await pumpAbout(tester);

    // design-spec.md Layout, About page: App info / Data source /
    // Usage and feedback, top to bottom (wireframe P8, plan B).
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('about-group-info'))).data,
      '应用信息',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('about-group-source')))
          .data,
      '数据来源',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('about-group-usage'))).data,
      '使用与反馈',
    );

    final info = tester
        .getTopLeft(find.byKey(const ValueKey('about-group-info')))
        .dy;
    final source = tester
        .getTopLeft(find.byKey(const ValueKey('about-group-source')))
        .dy;
    final usage = tester
        .getTopLeft(find.byKey(const ValueKey('about-group-usage')))
        .dy;
    expect(info, lessThan(source));
    expect(source, lessThan(usage));
  });

  testWidgets('the six rows keep the design order and the 62px label column', (
    tester,
  ) async {
    await pumpAbout(tester);

    const ids = ['version', 'kk', 'dj-ipa', 'oss', 'feedback', 'limitation'];
    final expected = ['版本', 'KK', 'DJ / IPA', '开源说明', '反馈', '已知限制'];

    for (var i = 0; i < ids.length; i++) {
      expect(labelOf(tester, ids[i]).data, expected[i]);
      expect(
        tester.getSize(find.byKey(ValueKey('about-col-${ids[i]}'))).width,
        62,
        reason: 'the label column is 62px wide (width-label)',
      );
      if (i > 0) {
        expect(
          tester.getTopLeft(find.byKey(ValueKey('about-row-${ids[i]}'))).dy,
          greaterThan(
            tester
                .getTopLeft(find.byKey(ValueKey('about-row-${ids[i - 1]}')))
                .dy,
          ),
        );
      }
    }

    // Every value starts on the same left edge (the label column plus the
    // label-to-value gap), so the six rows read as one column pair.
    final edges = {for (final id in ids) leftOf(tester, 'about-value-$id')};
    expect(edges, hasLength(1));
  });

  testWidgets('the groups are separated by two 1px dividers', (tester) async {
    await pumpAbout(tester);

    final dividers = find.descendant(
      of: find.byKey(const ValueKey('about-page')),
      matching: find.byType(Divider),
    );
    expect(dividers, findsNWidgets(2));
    for (final element in dividers.evaluate()) {
      final divider = element.widget as Divider;
      expect(divider.thickness ?? 1, 1);
      expect(divider.height ?? 1, 1);
    }
  });

  testWidgets('the source and limitation rows read the copy table verbatim', (
    tester,
  ) async {
    await pumpAbout(tester);

    // The notation name moved into the label column, so the values carry no
    // "KK 来源：" or "KK：" prefix any more (A19, plan B).
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('about-value-kk'))).data,
      '赖世雄《美语音标》ISBN 9787119061207',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('about-value-dj-ipa')))
          .data,
      '国际通用音标符号，不来自该教材',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('about-value-oss'))).data,
      '本项目以 oss 分发',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('about-value-limitation')))
          .data,
      '掌握度与复习进度仅存本设备，换机或清除数据后需重新学习；不提供导出/导入与云同步',
    );

    for (final prefix in ['KK 来源：', 'KK：']) {
      expect(
        find.textContaining(prefix),
        findsNothing,
        reason: '$prefix must not survive the label-column move',
      );
    }
  });

  testWidgets('the version row renders the build-time version with a v', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('about-value-version')))
          .data,
      'v0.2.1',
    );
    // The design baseline deleted the "版本未配置" empty state: the constant
    // always has a value, so no fallback string exists anywhere.
    expect(find.textContaining('版本未配置'), findsNothing);
  });

  testWidgets('the retired about-page sentences are gone', (tester) async {
    await pumpAbout(tester);

    for (final gone in [
      '开源说明：',
      '反馈：问题与建议',
      '数据仅保存在本设备',
      '公开对照表',
      '维基',
      'Kenyon & Knott',
      '待授权数据后替换',
    ]) {
      expect(find.textContaining(gone), findsNothing, reason: '$gone is gone');
    }
  });

  testWidgets(
    'the email entry is disabled and the repository entry opens the issue URL',
    (tester) async {
      final opened = <Uri>[];
      await pumpAbout(
        tester,
        launcher: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      // ux-flows S4 Failure: with no address configured the email entry is a
      // disabled grey button — not tappable, no prompt.
      final email = tester.widget<TextButton>(
        find.byKey(const ValueKey('about-feedback-email')),
      );
      expect(email.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('about-feedback-email')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(opened, isEmpty);

      await tester.tap(find.byKey(const ValueKey('about-feedback-repo')));
      await tester.pump();
      expect(opened, [
        Uri.parse('https://github.com/liberalluz/galatea/issues'),
      ]);
    },
  );

  testWidgets('the English copy table carries the three groups and six rows', (
    tester,
  ) async {
    await pumpAbout(tester, language: AppLanguage.enUs);

    expect(find.text('App info'), findsOneWidget);
    expect(find.text('Data source'), findsOneWidget);
    expect(find.text('Usage and feedback'), findsOneWidget);
    expect(
      find.text('Lai Shih-hsiung, American Phonetics, ISBN 9787119061207'),
      findsOneWidget,
    );
    expect(
      find.text('international standard notation, not from the book'),
      findsOneWidget,
    );
    expect(find.text('Distributed as oss'), findsOneWidget);
    expect(find.text('Known limits'), findsOneWidget);
  });
}
