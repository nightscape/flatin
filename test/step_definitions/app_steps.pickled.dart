// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// Generator: TestCodeBuilder
// **************************************************************************

import 'package:flutter_test/flutter_test.dart';

import 'app_steps.dart';

runFeatures() {
  final steps = AppSteps();
  group('Practice Screen', () {
    testWidgets('User practices a noun', (WidgetTester widgetTester) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iTapOn(widgetTester, 'home.nouns.button');
      await steps.iShouldSeePracticeScreen(widgetTester);
      await steps.iShouldSeeInputFields(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'practice_noun_initial');
    });
    testWidgets('User checks answers for a noun', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iTapOn(widgetTester, 'home.nouns.button');
      await steps.iWaitForPracticeScreen(widgetTester);
      await steps.iEnterAnswers(widgetTester);
      await steps.iTapOnCheck(widgetTester);
      await steps.iShouldSeeValidationResults(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'practice_noun_checked');
    });
    testWidgets('User rates a card after practice', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iTapOn(widgetTester, 'home.nouns.button');
      await steps.iWaitForPracticeScreen(widgetTester);
      await steps.iEnterAnswers(widgetTester);
      await steps.iTapOnCheck(widgetTester);
      await steps.iWaitForRatingButtons(widgetTester);
      await steps.iShouldSeeRatingButtons(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'practice_noun_rating');
    });
    testWidgets('User practices a verb', (WidgetTester widgetTester) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iTapOn(widgetTester, 'home.verbs.button');
      await steps.iShouldSeePracticeScreen(widgetTester);
      await steps.iShouldSeeInputFields(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'practice_verb_initial');
    });
  });
  group('Home Screen', () {
    testWidgets('User sees home screen with practice options', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iShouldSeeInAppBar(widgetTester, 'app.title');
      await steps.iShouldSeeButtonWithText(widgetTester, 'home.nouns.button');
      await steps.iShouldSeeButtonWithText(widgetTester, 'home.verbs.button');
      await steps.iShouldSeeButtonWithText(
        widgetTester,
        'home.wordClassification.button',
      );
      await steps.iTakeScreenshot(widgetTester, 'home_screen');
    });
    testWidgets('User opens drawer from home screen', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iOpenTheDrawer(widgetTester);
      await steps.iShouldSeeInDrawer(widgetTester, 'drawer.settings');
      await steps.iTakeScreenshot(widgetTester, 'home_screen_drawer');
    });
    testWidgets('User navigates to settings from drawer', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iOpenTheDrawer(widgetTester);
      await steps.iTapOn(widgetTester, 'drawer.settings');
      await steps.iShouldSeeInAppBar(widgetTester, 'settings.title');
      await steps.iTakeScreenshot(widgetTester, 'settings_screen');
    });
  });
  group('Word Classification', () {
    testWidgets('User opens word classification screen', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iTapOn(widgetTester, 'home.wordClassification.button');
      await steps.iShouldSeeInTitle(
        widgetTester,
        'wordClassification.declension',
        'wordClassification.conjugation',
      );
      await steps.iShouldSeeWordDisplayed(widgetTester);
      await steps.iShouldSeeClassificationDropdowns(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'word_classification_initial');
    });
    testWidgets('User classifies a word correctly', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iTapOn(widgetTester, 'home.wordClassification.button');
      await steps.iWaitForToLoad(widgetTester, 'the word');
      await steps.iSelectClassificationOptions(widgetTester);
      await steps.iTapOn(widgetTester, 'wordClassification.check.button');
      await steps.iShouldSeeValidationFeedback(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'word_classification_checked');
    });
  });
  group('Settings Screen', () {
    testWidgets('User views settings screen', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iOpenTheDrawer(widgetTester);
      await steps.iTapOn(widgetTester, 'drawer.settings');
      await steps.iShouldSeeSection(widgetTester, 'settings.section.nouns');
      await steps.iShouldSeeSection(widgetTester, 'settings.section.verbs');
      await steps.iShouldSeeCheckboxes(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'settings_screen_full');
    });
    testWidgets('User toggles a form setting', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iOpenTheDrawer(widgetTester);
      await steps.iTapOn(widgetTester, 'drawer.settings');
      await steps.iWaitForToLoad(widgetTester, 'settings');
      await steps.iToggleCheckbox(widgetTester);
      await steps.checkboxStateShouldChange(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'settings_screen_toggled');
    });
  });
}
