import 'package:flutter_gherkin/flutter_gherkin.dart';
import 'package:gherkin/gherkin.dart';
import 'package:flutter/material.dart';

/// Step definitions for user interactions
StepDefinitionGeneric whenEnterAnswers() {
  return when(
    RegExp(r'I enter answers in the input fields'),
    (context) async {
      final textFields = find.byType(TextField);
      final textFieldWidgets = textFields.evaluate();

      // Enter some test answers in the first few fields
      for (int i = 0; i < textFieldWidgets.length && i < 3; i++) {
        final field = textFields.at(i);
        await context.world.appDriver.enterText(field, 'test');
        await context.world.appDriver.waitForAppToSettle();
      }
    },
  );
}

StepDefinitionGeneric whenWaitForPracticeScreen() {
  return when(
    RegExp(r'I wait for the practice screen to load'),
    (context) async {
      // Wait for text fields to appear
      await context.world.appDriver.waitFor(
        find.byType(TextField),
        timeout: const Duration(seconds: 10),
      );
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenWaitForRatingButtons() {
  return when(
    RegExp(r'I wait for rating buttons to appear'),
    (context) async {
      // Wait for rating buttons (find by Key - language-agnostic)
      await context.world.appDriver.waitFor(
        find.byKey(const Key('rating_again')),
        timeout: const Duration(seconds: 5),
      );
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenWaitForWord() {
  return when(
    RegExp(r'I wait for the word to load'),
    (context) async {
      // Wait a bit for word to load
      await Future.delayed(const Duration(seconds: 2));
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenSelectClassificationOptions() {
  return when(
    RegExp(r'I select classification options'),
    (context) async {
      final dropdowns = find.byType(DropdownButtonFormField);
      final dropdownWidgets = dropdowns.evaluate();

      // Select first option in each dropdown
      for (int i = 0; i < dropdownWidgets.length && i < 3; i++) {
        final dropdown = dropdowns.at(i);
        await context.world.appDriver.tap(dropdown);
        await context.world.appDriver.waitForAppToSettle();

        // Tap first option (skip the null option)
        final options = find.byType(DropdownMenuItem);
        if (options.evaluate().length > 1) {
          await context.world.appDriver.tap(options.at(1));
          await context.world.appDriver.waitForAppToSettle();
        }
      }
    },
  );
}

StepDefinitionGeneric whenWaitForSettings() {
  return when(
    RegExp(r'I wait for settings to load'),
    (context) async {
      // Wait for checkboxes to appear
      await context.world.appDriver.waitFor(
        find.byType(CheckboxListTile),
        timeout: const Duration(seconds: 10),
      );
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric whenToggleCheckbox() {
  return when(
    RegExp(r'I toggle a form checkbox'),
    (context) async {
      final checkboxes = find.byType(CheckboxListTile);
      if (checkboxes.evaluate().isNotEmpty) {
        await context.world.appDriver.tap(checkboxes.first);
        await context.world.appDriver.waitForAppToSettle();
      }
    },
  );
}

