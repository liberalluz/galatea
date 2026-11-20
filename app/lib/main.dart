import 'package:flutter/material.dart';

void main() {
  runApp(const GalateaApp());
}

/// Root of the v0.1.0 shell: a placeholder page that later batches grow the
/// chart, detail, practice, and me tabs into.
class GalateaApp extends StatelessWidget {
  const GalateaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galatea',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const ShellPage(),
    );
  }
}

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Galatea')),
      body: const Center(child: Text('Galatea v0.1.0 shell')),
    );
  }
}
