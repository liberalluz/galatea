import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../copy/app_copy.dart';
import '../../domain/notation.dart';
import '../../main.dart' show kAppVersion;
import '../theme/tokens.dart';

/// Opens [uri] outside the app. Injectable so widget tests assert the target
/// without starting a platform channel (`B35`); production uses
/// `url_launcher`.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// The fixed repository entry of the About page — the 2026-11-24 design
/// baseline fixes this URL; the email address does not exist yet, so that
/// entry stays disabled.
final Uri repositoryIssuesUri = Uri.parse(
  'https://github.com/liberalluz/galatea/issues',
);

Future<bool> _openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The About page (`REQ-001`, `REQ-012`, `S4`, wireframe P8, plan B): three
/// groups separated by a 1px rule — 应用信息 with the version, 数据来源 with
/// the `KK` and `DJ / IPA` rows, 使用与反馈 with the oss note, the dual
/// feedback entries and the limitation disclosure.
///
/// The notation name sits in the label column and the values carry only their
/// content, so the old "KK 来源："/"KK：" double wording is gone and nothing is
/// composed from the correspondence data at render time. Spacing, the 62px
/// label column and the type steps come from [AppTokens] rather than
/// per-screen numbers. The email entry is a disabled grey button because no
/// address exists (`operations/feedback.md` is still empty); the repository
/// entry is the only actionable one. The chart carries no footer: this page is
/// the only attribution surface.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.launcher});

  /// Injectable for widget tests; production opens the platform browser.
  final LinkLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final copy = CopyScope.of(context);
    final body = AppTokens.typeBody.copyWith(
      color: AppTokens.textPrimary(context),
    );
    final open = launcher ?? _openExternal;

    return Scaffold(
      appBar: AppBar(title: Text(copy.aboutTitle)),
      body: SingleChildScrollView(
        key: const ValueKey('about-page'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AboutGroup(
              titleKey: 'about-group-info',
              title: copy.aboutGroupInfo,
              rows: [
                _AboutRow(
                  id: 'version',
                  label: copy.aboutVersion,
                  value: Text(
                    'v$kAppVersion',
                    key: const ValueKey('about-value-version'),
                    style: body,
                  ),
                ),
              ],
            ),
            const _GroupDivider(),
            _AboutGroup(
              titleKey: 'about-group-source',
              title: copy.aboutGroupSource,
              rows: [
                _AboutRow(
                  id: 'kk',
                  label: notationLabels[Notation.kk]!,
                  value: Text(
                    copy.aboutSourceNote,
                    key: const ValueKey('about-value-kk'),
                    style: body,
                  ),
                ),
                _AboutRow(
                  id: 'dj-ipa',
                  label: djIpaLabel(),
                  value: Text(
                    copy.aboutNotationNote,
                    key: const ValueKey('about-value-dj-ipa'),
                    style: body,
                  ),
                ),
              ],
            ),
            const _GroupDivider(),
            _AboutGroup(
              titleKey: 'about-group-usage',
              title: copy.aboutGroupUsage,
              rows: [
                _AboutRow(
                  id: 'oss',
                  label: copy.aboutOssLabel,
                  value: Text(
                    copy.aboutOssNote,
                    key: const ValueKey('about-value-oss'),
                    style: body,
                  ),
                ),
                _AboutRow(
                  id: 'feedback',
                  label: copy.aboutFeedbackLabel,
                  value: Wrap(
                    key: const ValueKey('about-value-feedback'),
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Disabled grey until operations/feedback.md carries an
                      // address (`S4` Failure, 2026-11-24).
                      TextButton(
                        key: const ValueKey('about-feedback-email'),
                        onPressed: null,
                        child: Text(copy.aboutFeedbackEmail),
                      ),
                      TextButton(
                        key: const ValueKey('about-feedback-repo'),
                        onPressed: () => open(repositoryIssuesUri),
                        child: Text(copy.aboutFeedbackRepo),
                      ),
                    ],
                  ),
                ),
                _AboutRow(
                  id: 'limitation',
                  label: copy.aboutLimitationLabel,
                  value: Text(
                    copy.aboutLimitation,
                    key: const ValueKey('about-value-limitation'),
                    style: body,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One group of the page: its title (`type-group`) over its rows.
class _AboutGroup extends StatelessWidget {
  const _AboutGroup({
    required this.titleKey,
    required this.title,
    required this.rows,
  });

  final String titleKey;
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: ValueKey(titleKey),
          style: AppTokens.typeGroup.copyWith(
            color: AppTokens.textPrimary(context),
          ),
        ),
        ...rows,
      ],
    );
  }
}

/// The 1px rule between two groups, with `space-group` on each side.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceGroup),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppTokens.divider(context),
      ),
    );
  }
}

/// One label/value row: the label in the fixed `width-label` column, the value
/// in the column beside it, every value starting on the same left edge.
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.id, required this.label, required this.value});

  final String id;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.spaceItem),
      child: Row(
        key: ValueKey('about-row-$id'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: ValueKey('about-col-$id'),
            width: AppTokens.labelColumnWidth,
            child: Text(
              label,
              key: ValueKey('about-label-$id'),
              style: AppTokens.typeBody.copyWith(
                color: AppTokens.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.spaceLabel),
          Expanded(child: value),
        ],
      ),
    );
  }
}
