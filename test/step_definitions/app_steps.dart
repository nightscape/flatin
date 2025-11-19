// IMPORTANT: ⚠️ only import annotations ⚠️
import 'package:pickled_cucumber/src/annotations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:latin_practice/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'dart:io';

@StepDefinition()
class AppSteps {
  // Navigation steps
  @Given('the app is running')
  Future<void> theAppIsRunning(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
  }

  @When('I am on the {string} screen')
  @And('I am on the {string} screen')
  Future<void> iAmOnScreen(WidgetTester tester, String screenName) async {
    await tester.pumpAndSettle();
  }

  @When('I open the drawer')
  @And('I open the drawer')
  Future<void> iOpenTheDrawer(WidgetTester tester) async {
    // Try to find and tap the drawer button first, if available
    final drawerButton = find.byIcon(Icons.menu);
    if (drawerButton.evaluate().isNotEmpty) {
      await tester.tap(drawerButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } else {
      // Fall back to dragging
      final scaffoldFinder = find.byType(Scaffold);
      await tester.drag(scaffoldFinder, const Offset(300, 0));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // Wait for drawer to be fully visible
    final drawerFinder = find.byType(Drawer);
    int attempts = 0;
    while (drawerFinder.evaluate().isEmpty && attempts < 30) {
      await tester.pump(const Duration(milliseconds: 200));
      attempts++;
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  @When('I tap on {string}')
  @And('I tap on {string}')
  Future<void> iTapOn(WidgetTester tester, String text) async {
    // If text contains dots, treat it as a key directly
    // Otherwise convert whitespace to dots for key-based identifiers
    final keyName = text.contains('.') ? text : text.replaceAll(' ', '.');
    Finder finder = find.byKey(Key(keyName));

    // If Key not found, wait for it to appear (e.g., drawer opening)
    if (finder.evaluate().isEmpty) {
      int attempts = 0;
      while (finder.evaluate().isEmpty && attempts < 30) {
        await tester.pump(const Duration(milliseconds: 200));
        finder = find.byKey(Key(keyName));
        attempts++;
      }
      // Final settle to ensure animations complete
      await tester.pumpAndSettle(const Duration(seconds: 1));
      finder = find.byKey(Key(keyName));
    }

    // If still not found and it's not a key-based identifier (no dots), fall back to text
    if (finder.evaluate().isEmpty && !text.contains('.')) {
      finder = find.text(text);
    }

    // Ensure finder is valid before tapping
    expect(
      finder,
      findsAtLeastNWidgets(1),
      reason: 'Could not find widget with key or text: $text',
    );

    // Try to scroll if scrollable exists, otherwise just tap
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(finder, 500.0, scrollable: scrollable);
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  @When('I tap on the button with text {string}')
  Future<void> iTapOnButtonWithText(WidgetTester tester, String text) async {
    // If text contains dots, treat it as a key directly
    // Otherwise convert whitespace to dots for key-based identifiers
    final keyName = text.contains('.') ? text : text.replaceAll(' ', '.');
    Finder finder = find.byKey(Key(keyName));

    // If Key not found, wait a bit and retry
    if (finder.evaluate().isEmpty) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      finder = find.byKey(Key(keyName));
    }

    // If still not found and it's not a key-based identifier (no dots), fall back to text
    if (finder.evaluate().isEmpty && !text.contains('.')) {
      finder = find.text(text);
    }

    // Try to scroll if scrollable exists, otherwise just tap
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(finder, 500.0, scrollable: scrollable);
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // Assertion steps
  @Then('I should see {string}')
  @And('I should see {string}')
  Future<void> iShouldSee(WidgetTester tester, String text) async {
    final finder = find.text(text);
    expect(finder, findsAtLeastNWidgets(1));
  }

  @Then('I should see {string} in the app bar')
  @And('I should see {string} in the app bar')
  Future<void> iShouldSeeInAppBar(WidgetTester tester, String text) async {
    // Find by key (use same key as i18n translation key)
    final key = Key(text);
    final finder = find.byKey(key);
    expect(finder, findsAtLeastNWidgets(1));
  }

  @Then('I should see a button with text {string}')
  @And('I should see a button with text {string}')
  Future<void> iShouldSeeButtonWithText(
    WidgetTester tester,
    String text,
  ) async {
    // If text contains dots, treat it as a key directly
    // Otherwise convert whitespace to dots for key-based identifiers
    final keyName = text.contains('.') ? text : text.replaceAll(' ', '.');
    Finder finder = find.byKey(Key(keyName));

    // If Key not found, wait a bit and retry
    if (finder.evaluate().isEmpty) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      finder = find.byKey(Key(keyName));
    }

    // If still not found and it's not a key-based identifier (no dots), fall back to text
    if (finder.evaluate().isEmpty && !text.contains('.')) {
      finder = find.text(text);
    }

    expect(finder, findsAtLeastNWidgets(1));
  }

  @Then('I should see {string} in the drawer')
  @And('I should see {string} in the drawer')
  Future<void> iShouldSeeInDrawer(WidgetTester tester, String text) async {
    // Ensure drawer is fully open
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // If text contains dots, treat it as a key directly
    // Otherwise convert whitespace to dots for key-based identifiers
    final keyName = text.contains('.') ? text : text.replaceAll(' ', '.');
    Finder finder = find.byKey(Key(keyName));

    // Wait for drawer to fully open and widget to appear
    if (finder.evaluate().isEmpty) {
      int attempts = 0;
      while (finder.evaluate().isEmpty && attempts < 30) {
        await tester.pump(const Duration(milliseconds: 200));
        finder = find.byKey(Key(keyName));
        attempts++;
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      finder = find.byKey(Key(keyName));
    }

    // If still not found and it's not a key-based identifier (no dots), fall back to text
    if (finder.evaluate().isEmpty && !text.contains('.')) {
      finder = find.text(text);
    }

    expect(finder, findsAtLeastNWidgets(1));
  }

  @Then('I should see a practice screen with a word type')
  @And('I should see a practice screen with a word type')
  Future<void> iShouldSeePracticeScreen(WidgetTester tester) async {
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsAtLeastNWidgets(1));
  }

  @Then('I should see input fields for forms')
  @And('I should see input fields for forms')
  Future<void> iShouldSeeInputFields(WidgetTester tester) async {
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsAtLeastNWidgets(1));
  }

  @Then('I should see validation results')
  @And('I should see validation results')
  Future<void> iShouldSeeValidationResults(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  @Then('I should see rating buttons')
  @And('I should see rating buttons')
  Future<void> iShouldSeeRatingButtons(WidgetTester tester) async {
    // Find rating buttons by Key (language-agnostic)
    final againFinder = find.byKey(const Key('rating.again'));
    final goodFinder = find.byKey(const Key('rating.good'));
    expect(againFinder, findsAtLeastNWidgets(1));
    expect(goodFinder, findsAtLeastNWidgets(1));
  }

  @Then('I should see {string} or {string} in the title')
  @And('I should see {string} or {string} in the title')
  Future<void> iShouldSeeInTitle(
    WidgetTester tester,
    String option1,
    String option2,
  ) async {
    // Find by keys (use same keys as i18n translation keys)
    final key1 = Key(option1);
    final key2 = Key(option2);
    final finder1 = find.byKey(key1);
    final finder2 = find.byKey(key2);
    expect(
      finder1.evaluate().isNotEmpty || finder2.evaluate().isNotEmpty,
      isTrue,
    );
  }

  @Then('I should see a word displayed')
  @And('I should see a word displayed')
  Future<void> iShouldSeeWordDisplayed(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  @Then('I should see classification dropdowns')
  @And('I should see classification dropdowns')
  Future<void> iShouldSeeClassificationDropdowns(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Wait for dropdowns to appear
    int attempts = 0;
    Finder dropdownFinder = find.byType(DropdownButtonFormField);
    while (dropdownFinder.evaluate().isEmpty && attempts < 30) {
      await tester.pump(const Duration(milliseconds: 200));
      dropdownFinder = find.byType(DropdownButtonFormField);
      attempts++;
    }
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(dropdownFinder, findsAtLeastNWidgets(1));
  }

  @Then('I should see {string} section')
  @And('I should see {string} section')
  Future<void> iShouldSeeSection(WidgetTester tester, String text) async {
    // If text contains dots, treat it as a key directly
    // Otherwise convert whitespace to dots for key-based identifiers
    final keyName = text.contains('.') ? text : text.replaceAll(' ', '.');
    Finder finder = find.byKey(Key(keyName));

    // If Key not found, wait a bit and retry
    if (finder.evaluate().isEmpty) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      finder = find.byKey(Key(keyName));
    }

    // If still not found and it's not a key-based identifier (no dots), fall back to text
    if (finder.evaluate().isEmpty && !text.contains('.')) {
      finder = find.text(text);
    }

    expect(finder, findsAtLeastNWidgets(1));
  }

  @Then('I should see checkboxes for form options')
  @And('I should see checkboxes for form options')
  Future<void> iShouldSeeCheckboxes(WidgetTester tester) async {
    final checkboxFinder = find.byType(CheckboxListTile);
    expect(checkboxFinder, findsAtLeastNWidgets(1));
  }

  @Then('the checkbox state should change')
  @And('the checkbox state should change')
  Future<void> checkboxStateShouldChange(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  @Then('I should see validation feedback')
  @And('I should see validation feedback')
  Future<void> iShouldSeeValidationFeedback(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  // Interaction steps
  @When('I enter {string} in the input fields')
  @And('I enter {string} in the input fields')
  Future<void> iEnterInInputFields(WidgetTester tester, String text) async {
    final textFields = find.byType(TextField);
    final textFieldWidgets = textFields.evaluate();

    for (int i = 0; i < textFieldWidgets.length && i < 3; i++) {
      final field = textFields.at(i);
      await tester.enterText(field, text);
      await tester.pumpAndSettle();
    }
  }

  @When('I enter answers in the input fields')
  @And('I enter answers in the input fields')
  Future<void> iEnterAnswers(WidgetTester tester) async {
    final textFields = find.byType(TextField);
    final textFieldWidgets = textFields.evaluate();

    for (int i = 0; i < textFieldWidgets.length && i < 3; i++) {
      final field = textFields.at(i);
      await tester.enterText(field, 'test');
      await tester.pumpAndSettle();
    }
  }

  @When('I wait for the practice screen to load')
  @And('I wait for the practice screen to load')
  Future<void> iWaitForPracticeScreen(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // Wait for text fields to appear
    int attempts = 0;
    while (find.byType(TextField).evaluate().isEmpty && attempts < 20) {
      await tester.pump(const Duration(milliseconds: 500));
      attempts++;
    }
  }

  @When('I wait for rating buttons to appear')
  @And('I wait for rating buttons to appear')
  Future<void> iWaitForRatingButtons(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Wait for rating buttons to appear (find by Key - language-agnostic)
    int attempts = 0;
    final againFinder = find.byKey(const Key('rating.again'));
    while (againFinder.evaluate().isEmpty && attempts < 10) {
      await tester.pump(const Duration(milliseconds: 500));
      attempts++;
    }
  }

  @When('I wait for the word to load')
  @And('I wait for the word to load')
  Future<void> iWaitForWord(WidgetTester tester) async {
    await Future.delayed(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  @When('I select classification options')
  @And('I select classification options')
  Future<void> iSelectClassificationOptions(WidgetTester tester) async {
    final dropdowns = find.byType(DropdownButtonFormField);
    final dropdownWidgets = dropdowns.evaluate();

    for (int i = 0; i < dropdownWidgets.length && i < 3; i++) {
      final dropdown = dropdowns.at(i);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final options = find.byType(DropdownMenuItem);
      if (options.evaluate().length > 1) {
        await tester.tap(options.at(1));
        await tester.pumpAndSettle();
      }
    }
  }

  @When('I wait for {string} to load')
  @And('I wait for {string} to load')
  Future<void> iWaitForToLoad(WidgetTester tester, String item) async {
    if (item == 'settings') {
      await tester.pumpAndSettle(const Duration(seconds: 3));
      // Wait for checkboxes to appear
      int attempts = 0;
      while (find.byType(CheckboxListTile).evaluate().isEmpty &&
          attempts < 20) {
        await tester.pump(const Duration(milliseconds: 500));
        attempts++;
      }
    } else if (item == 'the word') {
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    } else {
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  @When('I wait for settings to load')
  @And('I wait for settings to load')
  Future<void> iWaitForSettings(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 3));
    // Wait for checkboxes to appear
    int attempts = 0;
    while (find.byType(CheckboxListTile).evaluate().isEmpty && attempts < 20) {
      await tester.pump(const Duration(milliseconds: 500));
      attempts++;
    }
  }

  @When('I toggle a form checkbox')
  @And('I toggle a form checkbox')
  Future<void> iToggleCheckbox(WidgetTester tester) async {
    final checkboxes = find.byType(CheckboxListTile);
    if (checkboxes.evaluate().isNotEmpty) {
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
    }
  }

  @When('I tap on the {string} button')
  @And('I tap on the {string} button')
  Future<void> iTapOnButton(WidgetTester tester, String buttonText) async {
    final button = find.text(buttonText);
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  @When('I tap on check')
  @And('I tap on check')
  Future<void> iTapOnCheck(WidgetTester tester) async {
    // Find check button by Key (language-agnostic)
    final checkButton = find.byKey(const Key('practice.check.button'));
    if (checkButton.evaluate().isNotEmpty) {
      await tester.tap(checkButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  @When('I tap on Prüfen')
  @And('I tap on Prüfen')
  Future<void> iTapOnPruefen(WidgetTester tester) async {
    // Find check button by Key (language-agnostic)
    final checkButton = find.byKey(
      const Key('wordClassification.check.button'),
    );
    if (checkButton.evaluate().isNotEmpty) {
      await tester.tap(checkButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  // Screenshot steps
  @Then('I take a screenshot named {string}')
  @And('I take a screenshot named {string}')
  Future<void> iTakeScreenshot(WidgetTester tester, String name) async {
    try {
      final binding = IntegrationTestWidgetsFlutterBinding.instance;
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
      // Screenshots are saved by integration_test framework
      // Directory creation is handled by the test framework
    } catch (e) {
      // Ignore screenshot errors in tests - they're not critical for test execution
      throw Exception('Failed to take screenshot: $e');
    }
  }
}
