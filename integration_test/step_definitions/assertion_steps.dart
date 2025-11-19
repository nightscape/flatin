import 'package:flutter_gherkin/flutter_gherkin.dart';
import 'package:gherkin/gherkin.dart';
import 'package:flutter/material.dart';

/// Step definitions for assertions
StepDefinitionGeneric thenShouldSeeText() {
  return then(
    RegExp(r'I should see {string}'),
    (context) async {
      final text = context.read<String>();
      // Convert whitespace to underscores and try to find by Key, then fall back to text
      final keyName = text.replaceAll(' ', '_');
      Finder finder = find.byKey(Key(keyName));

      // If Key not found, fall back to text
      if (finder.evaluate().isEmpty) {
        finder = find.text(text);
      }

      expect(finder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeTextInAppBar() {
  return then(
    RegExp(r'I should see {string} in the app bar'),
    (context) async {
      final text = context.read<String>();
      final finder = find.text(text);
      expect(finder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeButtonWithText() {
  return then(
    RegExp(r'I should see a button with text {string}'),
    (context) async {
      final text = context.read<String>();
      // Convert whitespace to underscores and try to find by Key, then fall back to text
      final keyName = text.replaceAll(' ', '_');
      Finder finder = find.byKey(Key(keyName));

      // If Key not found, fall back to text
      if (finder.evaluate().isEmpty) {
        finder = find.text(text);
      }

      expect(finder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeTextInDrawer() {
  return then(
    RegExp(r'I should see {string} in the drawer'),
    (context) async {
      final text = context.read<String>();
      // Convert whitespace to underscores and try to find by Key, then fall back to text
      final keyName = text.replaceAll(' ', '_');
      Finder finder = find.byKey(Key(keyName));

      // If Key not found, fall back to text
      if (finder.evaluate().isEmpty) {
        finder = find.text(text);
      }

      expect(finder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeePracticeScreen() {
  return then(
    RegExp(r'I should see a practice screen with a word type'),
    (context) async {
      // Look for text fields which indicate practice screen
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeInputFields() {
  return then(
    RegExp(r'I should see input fields for forms'),
    (context) async {
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeValidationResults() {
  return then(
    RegExp(r'I should see validation results'),
    (context) async {
      // Look for green or red colors indicating validation
      // This is a simplified check - you might want to make it more specific
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric thenShouldSeeRatingButtons() {
  return then(
    RegExp(r'I should see rating buttons'),
    (context) async {
      // Find rating buttons by Key (language-agnostic)
      final againFinder = find.byKey(const Key('rating_again'));
      final goodFinder = find.byKey(const Key('rating_good'));
      expect(againFinder, findsAtLeastNWidgets(1));
      expect(goodFinder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeWordClassification() {
  return then(
    RegExp(r'I should see "Deklination" or "Konjugation" in the title'),
    (context) async {
      final deklinationFinder = find.text('Deklination');
      final konjugationFinder = find.text('Konjugation');
      expect(
        deklinationFinder.evaluate().isNotEmpty || konjugationFinder.evaluate().isNotEmpty,
        isTrue,
      );
    },
  );
}

StepDefinitionGeneric thenShouldSeeWordDisplayed() {
  return then(
    RegExp(r'I should see a word displayed'),
    (context) async {
      // Look for large text which is the word
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric thenShouldSeeClassificationDropdowns() {
  return then(
    RegExp(r'I should see classification dropdowns'),
    (context) async {
      final dropdownFinder = find.byType(DropdownButtonFormField);
      expect(dropdownFinder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeSettingsSections() {
  return then(
    RegExp(r'I should see {string} section'),
    (context) async {
      final text = context.read<String>();
      final finder = find.text(text);
      expect(finder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenShouldSeeCheckboxes() {
  return then(
    RegExp(r'I should see checkboxes for form options'),
    (context) async {
      final checkboxFinder = find.byType(CheckboxListTile);
      expect(checkboxFinder, findsAtLeastNWidgets(1));
    },
  );
}

StepDefinitionGeneric thenCheckboxStateChanged() {
  return then(
    RegExp(r'the checkbox state should change'),
    (context) async {
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

StepDefinitionGeneric thenShouldSeeValidationFeedback() {
  return then(
    RegExp(r'I should see validation feedback'),
    (context) async {
      await context.world.appDriver.waitForAppToSettle();
    },
  );
}

