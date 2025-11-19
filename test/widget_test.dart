// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:latin_practice/main.dart';

void main() {
  testWidgets('Latin declension screen displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LatinPracticeApp());

    // Verify that the declension type is displayed.
    expect(find.text('O-Deklination'), findsOneWidget);

    // Verify that the translation is displayed.
    expect(find.text('Der Hausherr/Herr'), findsOneWidget);

    // Verify that Latin forms are displayed.
    expect(find.text('dominus'), findsOneWidget);
  });
}
