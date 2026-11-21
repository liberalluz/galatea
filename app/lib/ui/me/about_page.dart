import 'package:flutter/material.dart';

import '../../content/correspondence.dart';
import '../../copy/app_copy.dart';
import '../../main.dart' show kAppVersion;

/// The About page (`REQ-001`, `REQ-012`, decision 7): the app version,
/// the single content source — the data files' title and references, the
/// ISBN slot reserved in the data structure, and the contingency
/// public-tables labelling rendered until licensed data lands — plus the
/// oss note, the feedback entry and the device-only limitation
/// disclosure. The chart carries no footer: this page is the only
/// attribution surface.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.correspondenceFuture});

  /// Injectable for widget tests; production loads the bundled asset.
  final Future<CorrespondenceTable>? correspondenceFuture;

  @override
  Widget build(BuildContext context) {
    final copy = CopyScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(copy.aboutTitle)),
      body: ListView(
        key: const ValueKey('about-page'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${copy.versionLabel} $kAppVersion',
            key: const ValueKey('about-version'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FutureBuilder<CorrespondenceTable>(
            future: correspondenceFuture ?? loadCorrespondence(),
            builder: (context, snapshot) {
              final table = snapshot.data;
              if (table == null) {
                return const SizedBox(
                  key: ValueKey('about-source-loading'),
                  height: 48,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.sourceTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    table.sourceTitle.isNotEmpty
                        ? table.sourceTitle
                        : table.sourceLabel,
                    key: const ValueKey('about-source'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  for (final ref in table.sourceRefs)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        ref,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  // The ISBN slot (decision 7): a licensed data file
                  // carries the booklet ISBN and the row renders; the
                  // contingency public-tables data shows the fixed
                  // contingency notice instead.
                  if (table.isbn != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${copy.isbnLabel} ${table.isbn}',
                        key: const ValueKey('about-isbn'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        copy.sourceContingency,
                        key: const ValueKey('about-source-contingency'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            copy.ossNote,
            key: const ValueKey('about-oss'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            copy.feedbackNote,
            key: const ValueKey('about-feedback'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            copy.deviceDisclosure,
            key: const ValueKey('about-device-disclosure'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
