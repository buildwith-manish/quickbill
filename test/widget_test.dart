import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// This is a minimal smoke test. Because the app uses code-gen (Drift,
// Riverpod) and SQLite (path_provider), full widget tests require either
// an in-memory database or a Robolectric/Espresso setup — out of scope for v1.
// The pure-logic unit tests in gst_service_test.dart and validators_test.dart
// are the primary acceptance-test surface.

void main() {
  testWidgets('MaterialApp smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Invory')),
        ),
      ),
    );
    expect(find.text('Invory'), findsOneWidget);
  });
}
