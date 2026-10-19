// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/main.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('Latin declension screen displays correctly', (
    WidgetTester tester,
  ) async {
    // Build our app with i18n support and trigger a frame.
    await tester.pumpWidget(wrapInApp(const LatinPracticeApp()));

    // Wait for i18n to load
    await tester.pumpAndSettle();

    // Verify that the home screen buttons are displayed.
    expect(find.text('Nomen (Deklination)'), findsOneWidget);
    expect(find.text('Verben (Konjugation)'), findsOneWidget);
  });
}
