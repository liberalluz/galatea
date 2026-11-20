import 'package:flutter/material.dart';

import 'content/phoneme_catalog.dart';
import 'ui/shell/shell_page.dart';

void main() {
  runApp(const GalateaApp());
}

/// Root of the Galatea app: the shell hosts the three fixed tabs; the chart
/// page grows in from B4.
class GalateaApp extends StatelessWidget {
  const GalateaApp({super.key, this.catalogFuture});

  /// Injectable for widget tests; production loads the bundled asset.
  final Future<PhonemeCatalog>? catalogFuture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galatea',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ShellPage(catalogFuture: catalogFuture),
    );
  }
}
