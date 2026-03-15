// Widget test cho Flashcard App
//
// Test kiểm tra: App khởi động đúng và hiển thị HomeScreen

import 'package:flashcard_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flashcard_app/main.dart';

void main() {
  testWidgets('App starts and displays HomeScreen', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify app title
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Flashcard App'), findsWidgets);

    // Verify HomeScreen is displayed
    expect(find.byType(HomeScreen), findsOneWidget);

    // Verify initial text
    expect(find.text('Bắt đầu xây dựng app!'), findsOneWidget);
  });
}
