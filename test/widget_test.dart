// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_manager_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Just pump once to ensure the app builds
    await tester.pump();

    // Verify that the app built successfully (no crash)
    // Since Firebase initialization might take time, we just check the app doesn't crash
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
