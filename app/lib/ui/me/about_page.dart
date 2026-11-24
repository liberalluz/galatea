import 'package:flutter/material.dart';

import '../../content/correspondence.dart';
import '../../copy/app_copy.dart';
import '../../main.dart' show kAppVersion;

/// The About page (`REQ-001`, `REQ-012`, decision 7): the app version,
/// the split source attribution — the design spec's fixed `source-note`
/// (the KK booklet with its ISBN) and `about-notation-note` (DJ / IPA as
/// international standard notation, not from the book) — plus the oss
/// note, the feedback entry and the device-only limitation disclosure.
/// The chart carries no footer: this page is the only attribution
/// surface.
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
              if (snapshot.data == null) {
                return const SizedBox(
                  key: ValueKey('about-source-loading'),
                  height: 48,
                );
              }
              // The split attribution (`REQ-001`, `REQ-012`): the source
              // section renders the design spec's two fixed notes and
              // composes nothing from the data at render time — the KK
              // booklet with its ISBN, and DJ / IPA as international
              // notation that does not come from the book.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.sourceNote,
                    key: const ValueKey('about-source-note'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    copy.notationNote,
                    key: const ValueKey('about-notation-note'),
                    style: Theme.of(context).textTheme.bodyLarge,
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
