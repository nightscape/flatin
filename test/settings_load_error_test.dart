import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latin_practice/providers/lesson_provider.dart';
import 'package:latin_practice/screens/settings_screen.dart';

import 'support/word_classification_harness.dart';

void main() {
  testWidgets('failing lesson data shows its error without waiting for retries',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(wrapInApp(
      const SettingsScreen(),
      overrides: [
        lessonDataProvider.overrideWith(
          (ref) async => throw const FormatException('broken lessons'),
        ),
      ],
    ));
    await letItLoad(tester);

    expect(find.textContaining('broken lessons'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('settings.title'), findsNothing);
  });
}
