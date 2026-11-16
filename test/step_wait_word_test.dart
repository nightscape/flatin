import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/settings_screen.dart';

import 'step_definitions/app_steps.dart';
import 'support/word_classification_harness.dart';

/// Screens the word wait can start on when the classification screen did not
/// open; the wait must still fail with its own message.
Map<String, Widget> screensWithoutClassification() => {
  'home': const HomeScreen(),
  'settings': const SettingsScreen(),
};

void main() {
  for (final MapEntry(key: name, value: screen)
      in screensWithoutClassification().entries) {
    testWidgets(
      'the word wait on the $name screen names what is missing',
      (tester) async {
        await seedEverythingDue(const {});
        await tester.pumpWidget(wrapInApp(screen));
        await tester.pumpAndSettle();

        Object? error;
        try {
          await AppSteps().iWaitForWord(tester);
        } catch (e) {
          error = e;
        }
        expect(
          error,
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            contains('No classification.0.* dropdown'),
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
    testWidgets(
      'the word wait on the $name screen says the classification screen is not open',
      (tester) async {
        await seedEverythingDue(const {});
        await tester.pumpWidget(wrapInApp(screen));
        await tester.pumpAndSettle();

        Object? error;
        try {
          await AppSteps().iWaitForWord(tester);
        } catch (e) {
          error = e;
        }
        expect(
          error,
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('classification screen is not open'),
              contains('${screen.runtimeType}'),
            ),
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
