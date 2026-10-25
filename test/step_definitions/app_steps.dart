import 'dart:convert';
import 'dart:io';

// IMPORTANT: ⚠️ only import annotations ⚠️
import 'package:pickled_cucumber/src/annotations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:latin_practice/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:latin_practice/data/rewards.dart';
import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/services/reward_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/round_driver.dart';
import '../support/word_classification_harness.dart' show letItLoad;

/// A widget that can be found again by key after a rebuild.
bool _isKeyed(Widget widget) => widget.key is ValueKey<String>;

bool _hasKeyPrefix(Widget widget, String prefix) =>
    _isKeyed(widget) &&
    (widget.key as ValueKey<String>).value.startsWith(prefix);

@StepDefinition()
class AppSteps {
  /// The checkbox `I toggle a form checkbox` tapped, and its value before the
  /// tap, so that `the checkbox state should change` can see the flip.
  Key? _toggledCheckbox;
  bool? _valueBeforeToggle;

  // Navigation steps
  @Given('the app is running')
  @And('the app is running')
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

    await _waitUntilEnabled(tester, finder);

    // Try to scroll if scrollable exists, otherwise just tap
    final scrollable = find.ancestor(
      of: finder,
      matching: find.byType(Scrollable),
    );
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        500.0,
        scrollable: scrollable.first,
      );
    }
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// A button whose data is still loading is on screen but disabled; tapping
  /// it does nothing, and the step after it then fails for the wrong reason.
  Future<void> _waitUntilEnabled(WidgetTester tester, Finder finder) async {
    bool disabled() {
      final widget = tester.widget(finder);
      return widget is ButtonStyleButton && widget.onPressed == null;
    }

    int attempts = 0;
    while (disabled() && attempts < 30) {
      await tester.pump(const Duration(milliseconds: 200));
      attempts++;
    }
    expect(disabled(), isFalse, reason: 'the button stayed disabled');
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
    final scrollable = find.ancestor(
      of: finder,
      matching: find.byType(Scrollable),
    );
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        finder,
        500.0,
        scrollable: scrollable.first,
      );
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
    // A checked row shows the correct form next to the answer, green or red.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.style?.color == Colors.green ||
                widget.style?.color == Colors.red),
        description: 'a form marked right or wrong',
      ),
      findsAtLeastNWidgets(1),
    );
  }

  @Then('I should see an explanation for a wrong answer')
  @And('I should see an explanation for a wrong answer')
  Future<void> iShouldSeeAnExplanation(WidgetTester tester) async {
    // Every row explanation carries Key('explanation.<formKey>').
    expect(
      find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> && key.value.startsWith('explanation.');
      }),
      findsAtLeastNWidgets(1),
    );
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
    expect(find.byKey(const Key('wordClassification.word')), findsOneWidget);
  }

  @Then('I should see classification dropdowns')
  @And('I should see classification dropdowns')
  Future<void> iShouldSeeClassificationDropdowns(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Wait for dropdowns to appear
    int attempts = 0;
    Finder dropdownFinder = find.byWidgetPredicate(
      (w) => w is DropdownButtonFormField,
    );
    while (dropdownFinder.evaluate().isEmpty && attempts < 30) {
      await tester.pump(const Duration(milliseconds: 200));
      dropdownFinder = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField,
      );
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

  @Then('the checkbox state should change')
  @And('the checkbox state should change')
  Future<void> checkboxStateShouldChange(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final tile = tester.widget<CheckboxListTile>(find.byKey(_toggledCheckbox!));
    expect(tile.value, isNot(_valueBeforeToggle));
  }

  @Then('I should see validation feedback')
  @And('I should see validation feedback')
  Future<void> iShouldSeeValidationFeedback(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Checking replaces the check button with the rating or next-word buttons.
    expect(
      find.byKey(const Key('wordClassification.check.button')),
      findsNothing,
    );
  }

  // Interaction steps
  @When('I enter {string} in the input fields')
  @And('I enter {string} in the input fields')
  Future<void> iEnterInInputFields(WidgetTester tester, String text) async {
    await _fillInputFields(tester, text);
  }

  @When('I enter answers in the input fields')
  @And('I enter answers in the input fields')
  Future<void> iEnterAnswers(WidgetTester tester) async {
    await _fillInputFields(tester, 'test');
  }

  /// Types [text] into the first three input fields and reads it back, so a
  /// screen that offers no field, or swallows the text, fails here.
  Future<void> _fillInputFields(WidgetTester tester, String text) async {
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(1));

    final found = textFields.evaluate().length;
    final count = found < 3 ? found : 3;
    for (int i = 0; i < count; i++) {
      await tester.enterText(textFields.at(i), text);
      await tester.pumpAndSettle();
    }
    for (int i = 0; i < count; i++) {
      expect(tester.widget<TextField>(textFields.at(i)).controller!.text, text);
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
    // The check button stays disabled until one row is answered in full, so
    // every section of the first row gets an option.
    final sections = find.byWidgetPredicate(
      (widget) => _hasKeyPrefix(widget, 'classification.0.'),
      description: 'a classification dropdown of the first row',
    );
    expect(sections, findsAtLeastNWidgets(1));

    for (int i = 0; i < sections.evaluate().length; i++) {
      await tester.ensureVisible(sections.at(i));
      await tester.pumpAndSettle();
      await tester.tap(sections.at(i));
      await tester.pumpAndSettle();

      // The open menu sits above the page in the overlay, so its items come
      // last; its last one is an option, the empty "--" being the first.
      final option = find.byType(DropdownMenuItem<String>).last;
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    final check = tester.widget<ElevatedButton>(
      find.byKey(const Key('wordClassification.check.button')),
    );
    expect(check.onPressed, isNotNull);
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
    final checkboxes = find.byWidgetPredicate(
      (widget) => widget is CheckboxListTile && _isKeyed(widget),
      description: 'a checkbox for a practice option',
    );
    expect(checkboxes, findsAtLeastNWidgets(1));

    final tile = tester.widget<CheckboxListTile>(checkboxes.first);
    _toggledCheckbox = tile.key;
    _valueBeforeToggle = tile.value;

    await tester.ensureVisible(checkboxes.first);
    await tester.pumpAndSettle();
    await tester.tap(checkboxes.first);
    await tester.pumpAndSettle();
  }

  @When('I tap on the {string} button')
  @And('I tap on the {string} button')
  Future<void> iTapOnButton(WidgetTester tester, String buttonText) async {
    final button = find.text(buttonText);
    expect(button, findsAtLeastNWidgets(1));
    await tester.tap(button.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  @When('I tap on check')
  @And('I tap on check')
  Future<void> iTapOnCheck(WidgetTester tester) async {
    // Find check button by Key (language-agnostic)
    final checkButton = find.byKey(const Key('practice.check.button'));
    expect(checkButton, findsOneWidget);
    await tester.tap(checkButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  @When('I tap on Prüfen')
  @And('I tap on Prüfen')
  Future<void> iTapOnPruefen(WidgetTester tester) async {
    // Find check button by Key (language-agnostic)
    final checkButton = find.byKey(
      const Key('wordClassification.check.button'),
    );
    expect(checkButton, findsOneWidget);
    await tester.tap(checkButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  // Reward steps: the state steps run before `the app is running`.
  @Given('I have {int} coins')
  @And('I have {int} coins')
  Future<void> iHaveCoins(WidgetTester tester, int coins) async {
    final ledger = await RewardStorage.load();
    await RewardStorage.save(
      RewardLedger(points: coins, buildings: ledger.buildings),
    );
  }

  @Given('I have built {int} buildings')
  @And('I have built {int} buildings')
  Future<void> iHaveBuilt(WidgetTester tester, int count) async {
    final ledger = await RewardStorage.load();
    await RewardStorage.save(
      RewardLedger(
        points: ledger.points,
        buildings: [for (final b in romanTown.take(count)) b.id],
      ),
    );
  }

  @Given('I switched the {string} reward off')
  @And('I switched the {string} reward off')
  Future<void> iSwitchedRewardOff(WidgetTester tester, String reward) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'practice_settings',
      jsonEncode(Settings(disabledRewards: {reward}).toJson()),
    );
  }

  @When('I start a round')
  @And('I start a round')
  Future<void> iStartARound(WidgetTester tester) async {
    // The round-end screen builds its buttons lazily; a tall view shows them.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tap(tester, 'home.grammar.button');
    await letItLoad(tester);
    await tap(tester, 'round.start.go');
    await letItLoad(tester);
  }

  @When('I answer the task correctly')
  @And('I answer the task correctly')
  Future<void> iAnswerCorrectly(WidgetTester tester) async {
    await answer(tester, shown(tester), right: true);
    await letItLoad(tester);
  }

  @When('I answer the task wrongly')
  @And('I answer the task wrongly')
  Future<void> iAnswerWrongly(WidgetTester tester) async {
    await answer(tester, shown(tester), right: false);
    await letItLoad(tester);
  }

  @When('I finish the round')
  @And('I finish the round')
  Future<void> iFinishTheRound(WidgetTester tester) async {
    // A task answered wrongly comes back later, so the count of tasks varies.
    for (var i = 0; i < 12; i++) {
      if (find.byKey(const Key('round.end.done')).evaluate().isNotEmpty) break;
      await iAnswerCorrectly(tester);
    }
    await tap(tester, 'round.end.done');
    await letItLoad(tester);
  }

  @When('I leave the round')
  @And('I leave the round')
  Future<void> iLeaveTheRound(WidgetTester tester) async {
    while (find.byKey(const Key('home.grammar.button')).evaluate().isEmpty) {
      await tester.pageBack();
      await letItLoad(tester);
    }
  }

  @Then('I should have {int} coins')
  @And('I should have {int} coins')
  Future<void> iShouldHaveCoins(WidgetTester tester, int coins) async {
    expect(
      find.descendant(
        of: find.byKey(const Key('home.coins')),
        matching: find.text('$coins'),
      ),
      findsOneWidget,
    );
  }

  @Then('I should see no coins')
  @And('I should see no coins')
  Future<void> iShouldSeeNoCoins(WidgetTester tester) async {
    expect(find.byKey(const Key('home.coins')), findsNothing);
  }

  @Then('I should see no town')
  @And('I should see no town')
  Future<void> iShouldSeeNoTown(WidgetTester tester) async {
    expect(find.byKey(const Key('home.town')), findsNothing);
  }

  @Then('my town should have {int} buildings')
  @And('my town should have {int} buildings')
  Future<void> myTownHasBuildings(WidgetTester tester, int count) async {
    // A building can show as several sprites, e.g. `aquaeductus-0`.
    final buildings = find
        .byWidgetPredicate((w) => _hasKeyPrefix(w, 'town.building.'))
        .evaluate()
        .map(
          (e) => (e.widget.key as ValueKey<String>).value
              .substring('town.building.'.length)
              .split('-')
              .first,
        )
        .toSet();
    expect(buildings, hasLength(count));
  }

  @Then('the next building should be {string}')
  @And('the next building should be {string}')
  Future<void> theNextBuildingIs(WidgetTester tester, String id) async {
    expect(find.byKey(Key('town.next.$id')), findsOneWidget);
  }

  // Screenshot steps
  @Then('I take a screenshot named {string}')
  @And('I take a screenshot named {string}')
  Future<void> iTakeScreenshot(WidgetTester tester, String name) async {
    // The integration_test screenshot channel exists only on Android and iOS.
    if (!Platform.isAndroid && !Platform.isIOS) return;
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
