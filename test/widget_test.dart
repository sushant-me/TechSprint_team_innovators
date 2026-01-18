import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghost_signal/main.dart';

void main() {
  group('Counter App Widget Tests', () {
    testWidgets('Counter starts at 0', (WidgetTester tester) async {
      // Build the app.
      await tester.pumpWidget(const MyApp());

      // Verify initial counter value is 0.
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('Counter increments when "+" is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Tap the '+' button.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Verify counter incremented.
      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
