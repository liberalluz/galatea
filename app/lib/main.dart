import 'package:flutter/material.dart';

import 'audio/audio_service.dart';
import 'content/correspondence.dart';
import 'content/examples.dart';
import 'content/glyphs.dart';
import 'content/phoneme_catalog.dart';
import 'ui/shell/shell_page.dart';

void main() {
  runApp(const GalateaApp());
}

/// Root of the Galatea app: the shell hosts the three fixed tabs; the chart
/// page grows in from B4.
class GalateaApp extends StatelessWidget {
  const GalateaApp({
    super.key,
    this.catalogFuture,
    this.correspondenceFuture,
    this.examplesFuture,
    this.glyphsFuture,
    this.audioService,
  });

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<PhonemeCatalog>? catalogFuture;
  final Future<CorrespondenceTable>? correspondenceFuture;

  /// Injectable example data (`B9`); production loads the bundled asset.
  final Future<ExamplesData>? examplesFuture;

  /// Injectable for widget tests; production loads the bundled assets.
  final Future<GlyphData>? glyphsFuture;

  /// Injectable audio service (ADR-0002 interface); defaults to the
  /// platform provider when omitted.
  final AudioService? audioService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galatea',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ShellPage(
        catalogFuture: catalogFuture,
        correspondenceFuture: correspondenceFuture,
        examplesFuture: examplesFuture,
        glyphsFuture: glyphsFuture,
        audioService: audioService,
      ),
    );
  }
}
