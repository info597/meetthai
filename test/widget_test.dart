import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meet_thai/main.dart';

void main() {
  testWidgets('App startet ohne Supabase Config und zeigt Setup-Seite',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(hasSupabaseConfig: false),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Supabase'), findsWidgets);
    expect(find.textContaining('Setup'), findsWidgets);
  });

  testWidgets('Setup-Seite enthält dart-define Hinweis',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(hasSupabaseConfig: false),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('--dart-define'), findsWidgets);
    expect(find.textContaining('SUPABASE_URL'), findsWidgets);
    expect(find.textContaining('SUPABASE_ANON_KEY'), findsWidgets);
  });
}