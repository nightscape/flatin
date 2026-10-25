// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

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
    testWidgets('User sees an explanation for a wrong answer', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iTapOn(widgetTester, 'home.nouns.button');
      await steps.iWaitForPracticeScreen(widgetTester);
      await steps.iEnterInInputFields(widgetTester, 'zzz');
      await steps.iTapOnCheck(widgetTester);
      await steps.iShouldSeeAnExplanation(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'practice_noun_explanation');
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
  group('Rewards', () {
    testWidgets('A right answer earns 10 coins', (
      WidgetTester widgetTester,
    ) async {
      await steps.iHaveCoins(widgetTester, 20);
      await steps.theAppIsRunning(widgetTester);
      await steps.iStartARound(widgetTester);
      await steps.iAnswerCorrectly(widgetTester);
      await steps.iLeaveTheRound(widgetTester);
      await steps.iShouldHaveCoins(widgetTester, 30);
    });
    testWidgets('A task answered right on the second try earns 5 coins', (
      WidgetTester widgetTester,
    ) async {
      await steps.iHaveCoins(widgetTester, 0);
      await steps.theAppIsRunning(widgetTester);
      await steps.iStartARound(widgetTester);
      await steps.iAnswerWrongly(widgetTester);
      await steps.iFinishTheRound(widgetTester);
      await steps.iLeaveTheRound(widgetTester);
      await steps.iShouldHaveCoins(widgetTester, 95);
    });
    testWidgets('Finishing a round adds no building', (
      WidgetTester widgetTester,
    ) async {
      await steps.iHaveBuilt(widgetTester, 2);
      await steps.theAppIsRunning(widgetTester);
      await steps.iStartARound(widgetTester);
      await steps.iFinishTheRound(widgetTester);
      await steps.iLeaveTheRound(widgetTester);
      await steps.myTownHasBuildings(widgetTester, 2);
    });
    testWidgets('A building bought with enough coins appears in the town', (
      WidgetTester widgetTester,
    ) async {
      await steps.iHaveCoins(widgetTester, 900);
      await steps.theAppIsRunning(widgetTester);
      await steps.iBuy(widgetTester, 'templum');
      await steps.iShouldHaveCoins(widgetTester, 300);
      await steps.theTownShows(widgetTester, 'templum');
    });
    testWidgets('A building that costs more than my coins cannot be bought', (
      WidgetTester widgetTester,
    ) async {
      await steps.iHaveCoins(widgetTester, 500);
      await steps.theAppIsRunning(widgetTester);
      await steps.iCannotBuy(widgetTester, 'templum');
    });
    testWidgets('A reward I switched off is not shown', (
      WidgetTester widgetTester,
    ) async {
      await steps.iSwitchedRewardOff(widgetTester, 'points');
      await steps.iHaveCoins(widgetTester, 20);
      await steps.theAppIsRunning(widgetTester);
      await steps.iShouldSeeNoCoins(widgetTester);
    });
    testWidgets('A town I switched off is not shown', (
      WidgetTester widgetTester,
    ) async {
      await steps.iSwitchedRewardOff(widgetTester, 'town');
      await steps.iHaveBuilt(widgetTester, 2);
      await steps.theAppIsRunning(widgetTester);
      await steps.iShouldSeeNoTown(widgetTester);
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
      await steps.iShouldSeeSection(widgetTester, 'settings.section.kursstand');
      await steps.iShouldSeeSection(widgetTester, 'settings.tile.words');
      await steps.iShouldSeeSection(widgetTester, 'settings.tile.nouns');
      await steps.iTakeScreenshot(widgetTester, 'settings_screen_full');
    });
    testWidgets('User toggles a form setting', (
      WidgetTester widgetTester,
    ) async {
      await steps.theAppIsRunning(widgetTester);
      await steps.iAmOnScreen(widgetTester, 'home');
      await steps.iOpenTheDrawer(widgetTester);
      await steps.iTapOn(widgetTester, 'drawer.settings');
      await steps.iTapOn(widgetTester, 'settings.tile.nouns');
      await steps.iWaitForToLoad(widgetTester, 'settings');
      await steps.iToggleCheckbox(widgetTester);
      await steps.checkboxStateShouldChange(widgetTester);
      await steps.iTakeScreenshot(widgetTester, 'settings_screen_toggled');
    });
  });
}
