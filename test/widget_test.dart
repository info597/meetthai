import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Meet Thai Test OK'),
        ),
      ),
    );

    expect(find.text('Meet Thai Test OK'), findsOneWidget);
  });
}
