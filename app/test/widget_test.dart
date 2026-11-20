import 'package:flutter_test/flutter_test.dart';

import 'package:galatea/main.dart';

void main() {
  testWidgets('shell smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GalateaApp());

    expect(find.text('Galatea'), findsOneWidget);
    expect(find.text('Galatea v0.1.0 shell'), findsOneWidget);
  });
}
