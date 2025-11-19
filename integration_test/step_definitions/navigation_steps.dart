import 'package:flutter_gherkin/flutter_gherkin.dart';
import 'package:gherkin/gherkin.dart';
import 'package:flutter/material.dart';

/// Step definitions for navigation
StepDefinitionGeneric givenAppIsRunning() {
  return given(
    RegExp(r'the app is running'),
    (context) async {
      // App is already running in integration test context
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenOnHomeScreen() {
  return when(
    RegExp(r'I am on the home screen'),
    (context) async {
      // Navigate to home if not already there
      // In integration tests, app starts at home screen
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenOpenDrawer() {
  return when(
    RegExp(r'I open the drawer'),
    (context) async {
      final finder = find.byIcon(Icons.menu);
      if (finder.evaluate().isNotEmpty) {
        await context.world.appDriver.tap(finder);
      } else {
        // Try to find drawer by scaffold
        final scaffoldFinder = find.byType(Scaffold);
        if (scaffoldFinder.evaluate().isNotEmpty) {
          // Open drawer using gesture
          await context.world.appDriver.tap(scaffoldFinder);
        }
      }
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenTapOnText() {
  return when(
    RegExp(r'I tap on {string}'),
    (context) async {
      final text = context.read<String>();
      // Convert whitespace to underscores and try to find by Key, then fall back to text
      final keyName = text.replaceAll(' ', '_');
      Finder finder = find.byKey(Key(keyName));

      // If Key not found, fall back to text
      if (finder.evaluate().isEmpty) {
        finder = find.text(text);
      }

      await context.world.appDriver.scrollUntilVisible(
        finder,
        500.0,
        scrollable: find.byType(Scrollable),
      );
      await context.world.appDriver.tap(finder);
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenTapOnButton() {
  return when(
    RegExp(r'I tap on the button with text {string}'),
    (context) async {
      final text = context.read<String>();
      // Convert whitespace to underscores and try to find by Key, then fall back to text
      final keyName = text.replaceAll(' ', '_');
      Finder finder = find.byKey(Key(keyName));

      // If Key not found, fall back to text
      if (finder.evaluate().isEmpty) {
        finder = find.text(text);
      }

      await context.world.appDriver.scrollUntilVisible(
        finder,
        500.0,
        scrollable: find.byType(Scrollable),
      );
      await context.world.appDriver.tap(finder);
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenTapOnCheck() {
  return when(
    RegExp(r'I tap on check'),
    (context) async {
      // Find check button by Key (language-agnostic)
      final checkButton = find.byKey(const Key('practice_check_button'));
      if (checkButton.evaluate().isNotEmpty) {
        await context.world.appDriver.tap(checkButton);
        await context.world.appDriver.waitForAppToSettle();
      }
    },
  );
}

StepDefinitionGeneric whenTapOnPruefen() {
  return when(
    RegExp(r'I tap on Prüfen'),
    (context) async {
      // Find check button by Key (language-agnostic)
      final checkButton = find.byKey(const Key('word_classification_check_button'));
      if (checkButton.evaluate().isNotEmpty) {
        await context.world.appDriver.tap(checkButton);
        await context.world.appDriver.waitForAppToSettle();
      }
    },
  );
}

